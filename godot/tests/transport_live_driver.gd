class_name TransportLiveDriver
extends "res://tests/transport_driver.gd"
## O05-03 — THE TRANSPORT JOURNEY THROUGH THE REAL BRIDGE, ACROSS TWO REAL
## RESTARTS (`--transport-live=<phase>`).
##
##     make godot-transport-live
##
## Four runs of this driver against one disposable save, each a new
## client process beside a new bridge process; only the save crosses:
##
##   seed     the real path makes the campaign and generates zone_001,
##            with the bridge's opt-in CANDIDATE profile adding the journey
##            before the Zone is accepted (`--candidate=transport`; nothing
##            edits a save). The served Zone is checked to BE
##            `transport_zone.json`, field for field.
##   place    the portal; the bridge's own layout verdict; the rooms
##            cleared with the base kit; the cell picked up at home and
##            carried through the connector into the run's second room
##            (on today's two-room run, the socket's own room), and PUT
##            DOWN there, not installed. The transfer and the settled pose are accepted
##            and read back off the snapshot and off the save file.
##            Forged object intents are refused. Out the way the game
##            leaves.
##   install  RESTART POINT 1. The cell is where it was put down -- one
##            copy, at its pose, not at home and not in the socket. It is
##            picked up again, carried on through any further connector
##            and installed with the interact ray; `object_consumed` is accepted, the variable
##            is powered in the snapshot and on disk, the doorway opens.
##            The forgeries that would duplicate or move an installed
##            object are refused. Out again.
##   restore  RESTART POINT 2. Installed at load: one cell, seated; no
##            loose copy anywhere; the doorway open before anyone acts;
##            nothing announced; and the player walks through it.
##
## **BESIDE `Main`**, like the P14 live driver, because `Main._to_zone` is
## what hands the saved object state to the Zone before it is built.

const PHASE_FLAG := "--transport-live="
const SAVE_DIR_FLAG := "--transport-save-dir="
const ZONE_ID := "zone_001"

var main: Node
var _errors: Array[String] = []


static func phase_from_cmdline() -> String:
	return _arg(PHASE_FLAG)


static func _arg(flag: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag):
			return arg.substr(flag.length())
	return ""


func _run() -> void:
	await get_tree().process_frame
	BridgeClient.error_received.connect(func(err: Dictionary) -> void:
		_errors.append(str(err.get("message", ""))))
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		match phase_from_cmdline():
			"seed":
				await _seed()
			"place":
				await _place()
			"install":
				await _install()
			"restore":
				await _restore()
			_:
				_check(false, "no --transport-live phase was named")
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	var phase := phase_from_cmdline().to_upper()
	if failures == 0:
		print("GODOT TRANSPORT LIVE %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT TRANSPORT LIVE %s: %d failures in %d checks"
				% [phase, failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _await_live(what: String, predicate: Callable,
		seconds := 30.0) -> bool:
	var waited := 0.0
	while waited < seconds:
		if predicate.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(false, "timed out waiting for %s" % what)
	return false


func _campaign() -> bool:
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	return await _await_live("a campaign",
			func() -> bool: return BridgeClient.hub_mode() != "NO_CAMPAIGN",
			30.0)


func _through_the_portal() -> ZoneController:
	var offered := func() -> bool:
		var standing := main.hub as HubController
		return standing != null and standing.portal() != null \
				and standing.portal().interact_prompt() != ""
	if not await _await_live("the Hub's portal", offered, 30.0):
		return null
	_zone_data = BridgeClient.active_zone().get("zone", {})
	(main.hub as HubController).portal().interact(main)
	if not await _await_live("ZONE_ACTIVE",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_ACTIVE",
			30.0):
		return null
	# READ AGAIN ONCE ENTERED. A RESUMED Zone is offered by the Hub before
	# the bridge serves it as the active one, so the copy taken above can
	# be empty after a restart -- and every spine walk reads this one.
	if (_zone_data.get("chambers", []) as Array).is_empty():
		_zone_data = BridgeClient.active_zone().get("zone", {})
	if not await _await_live("Main builds the Zone",
			func() -> bool:
				return main.zone != null and main.zone.player != null,
			40.0):
		return null
	var controller := main.zone as ZoneController
	if not await _await_live("the bridge accepts the layout",
			func() -> bool: return controller.layout_verdict == "ACCEPTED",
			60.0):
		return null
	var player := controller.player
	_last_hp = player.hp
	_feedback.clear()
	player.died.connect(func() -> void: _deaths += 1)
	player.carry_feedback.connect(
			func(text: String, _ok: bool) -> void: _feedback.append(text))
	return controller


## The Zone's progress as the bridge serves it.
func _served() -> Dictionary:
	var progress: Variant = BridgeClient.active_zone().get("progress", {})
	return progress if typeof(progress) == TYPE_DICTIONARY else {}


## THE SAVE FILE ITSELF, read off the disk the bridge writes to.
func _saved() -> Dictionary:
	var dir := _arg(SAVE_DIR_FLAG)
	var names: Array[String] = []
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".json"):
			names.append(name)
	if names.size() != 1:
		return {"error": "%d saves in '%s'" % [names.size(), dir]}
	var save: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(dir.path_join(names[0])))
	if typeof(save) != TYPE_DICTIONARY:
		return {"error": "unreadable save"}
	for raw: Variant in (save as Dictionary).get("zones", []) as Array:
		var record: Dictionary = raw
		if str(record.get("zone_id", "")) == ZONE_ID:
			return record.get("progress", {}) as Dictionary
	return {"error": "no %s in the save" % ZONE_ID}


static func _row(rows: Variant, key: String) -> Array:
	if typeof(rows) != TYPE_ARRAY:
		return []
	for row: Variant in rows as Array:
		if typeof(row) == TYPE_ARRAY and not (row as Array).is_empty() \
				and str((row as Array)[0]) == key:
			return row
	return []


## One forged intent, and the refusal it must draw.
func _refused(intent: Dictionary, because: String, what: String) -> void:
	_errors.clear()
	BridgeClient.send_intent(intent)
	var answered := await _await_live("the refusal of %s" % what,
			func() -> bool: return not _errors.is_empty(), 10.0)
	_check(answered and because in _errors[0],
			"REFUSED, %s -> \"%s\"" % [what,
				_errors[0] if answered else "no answer"])


func _leave() -> void:
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": ZONE_ID})
	await _await_live("the Zone goes dormant",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			20.0)


# ---------------------------------------------------------------------------
# seed
# ---------------------------------------------------------------------------

func _seed() -> void:
	if not await _campaign():
		return
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	if not await _await_live("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			90.0):
		return
	var record := BridgeClient.active_zone()
	_check(str(record.get("zone_id", "")) == ZONE_ID,
			"the campaign generated %s" % str(record.get("zone_id", "")))
	var zone: Dictionary = record.get("zone", {})
	var fixture: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(FIXTURE))
	for key: String in ["transported_objects", "object_consumers",
			"zone_state", "edges", "chambers"]:
		_check(JSON.stringify(zone.get(key)) == JSON.stringify(
				fixture.get(key)),
				"the served Zone's %s are the fixture's, field for field"
				% key)
	print("seeded: %s generated with the candidate transport step, not "
			% ZONE_ID + "entered")


# ---------------------------------------------------------------------------
# place: carry it partway and put it down
# ---------------------------------------------------------------------------

func _place() -> void:
	if not await _campaign():
		return
	if not await _await_live("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return
	var zone_data: Dictionary = BridgeClient.active_zone().get("zone", {})
	var objects := zone_data.get("transported_objects", []) as Array
	_check(objects.size() == 1,
			"the bridge serves the composed journey (%d object)"
			% objects.size())
	if objects.is_empty():
		return
	var volume: Array = (objects[0] as Dictionary)["allowed_volume"]
	var home := str(volume[0])
	var mid := str(volume[1])
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var player := controller.player

	# ---- a transfer before the layout is committed is refused, earlier
	# than this; here the layout is ACCEPTED, so the forgeries below are
	# refused for what they claim, not for when.
	await _refused({"type": "object_transported", "zone_id": ZONE_ID,
			"object_id": CELL, "room_id": "c001"}, "may not be in room",
			"a transfer outside the volume")
	await _refused({"type": "object_settled", "zone_id": ZONE_ID,
			"object_id": "ghost", "room_id": home,
			"position": [0.0, 0.0, 0.0], "yaw": 0.0},
			"declares no transported object", "a pose for an undeclared object")
	await _refused({"type": "zone_state_selected", "zone_id": ZONE_ID,
			"variable_id": VARIABLE, "state": "powered"},
			"deliver the object", "the consumer's variable set by message")
	# UNDELIVERED, whichever way the bridge words where the cell is: "not
	# anywhere yet" before it has reported anything, or "in '<home>'"
	# once it has settled there after the Zone was built.
	await _refused({"type": "object_consumed", "zone_id": ZONE_ID,
			"mechanism_id": SOCKET},
			"has to be delivered before it is consumed",
			"an installation with no delivery")

	if not await _advance_to(controller, mid):
		return
	await _retreat_to(controller, home)
	var cell := controller.objects.body_of(CELL)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	_check(player.carry.holding(), "the cell is picked up at home")
	var into := await _walk_into(controller, mid)
	_check(bool(into["inside"]) and player.carry.holding(),
			"carried through the connector into %s" % mid)
	player.camera.rotation.x = 0.0
	await _settle(2)
	await _press("interact")
	await _settle(90)
	_check(not player.carry.holding(), "and put down there")
	var at := cell.global_position
	var accepted := await _await_live("the bridge to carry the pose",
			func() -> bool:
				return not _row(_served().get("object_poses"), CELL).is_empty(),
			10.0)
	var pose := _row(_served().get("object_poses"), CELL)
	_check(accepted and str(pose[1]) == mid
			and Vector3(float(pose[2]), float(pose[3]), float(pose[4]))
				.distance_to(at) < 0.01,
			"ACCEPTED: the snapshot carries the cell in %s at its pose %s"
			% [mid, pose])
	var saved := _saved()
	var on_disk := _row(saved.get("object_poses"), CELL)
	_check(_row(saved.get("object_rooms"), CELL) == [CELL, mid]
			and on_disk == pose,
			"SAVED: the file on disk holds the same room and pose (%s)"
			% [on_disk])
	await _leave()
	print("placed: %s put down in %s; leaving for restart 1" % [CELL, mid])


# ---------------------------------------------------------------------------
# install: after restart 1
# ---------------------------------------------------------------------------

func _install() -> void:
	if not await _campaign():
		return
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) == ZONE_ID,
			"RESTART 1: the new bridge loaded the save; the Hub offers '%s'"
			% str(BridgeClient.hub().get("resume_zone_id", "")))
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var player := controller.player
	var zone_data: Dictionary = BridgeClient.active_zone().get("zone", {})
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var mid := str(volume[1])
	var consumer_room := str(volume[volume.size() - 1])
	var pose := _row(_served().get("object_poses"), CELL)
	var cell := controller.objects.body_of(CELL)
	var saved_at := Vector3(float(pose[2]), float(pose[3]), float(pose[4])) \
			if pose.size() == 6 else Vector3.INF
	_check(cell != null and _copies(CELL) == 1
			and cell.global_position.distance_to(saved_at) < 0.1,
			"the cell is back where it was put down in %s, one copy "
			% mid + "(%.3f m off)" % (cell.global_position.distance_to(
				saved_at) if cell != null else INF))
	_check(controller.objects.room_of(CELL) == mid
			and _socket(controller).installed_object == ""
			and _gate(controller).shutter.is_shut(),
			"owned by %s; socket empty; the doorway still shut" % mid)

	# ---- clear ahead, then carry on --------------------------------------
	if not await _advance_to(controller, consumer_room):
		return
	await _retreat_to(controller, mid)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	_check(player.carry.holding() and player.carry.body == cell,
			"the same body is picked up again in %s" % mid)
	if mid != consumer_room:
		var into := await _walk_into(controller, consumer_room)
		_check(bool(into["inside"]) and player.carry.holding(),
				"carried through the next connector into %s" % consumer_room)
	else:
		# A TWO-ROOM RUN (P5-8): the cell was put down in the consumer's
		# own room, after crossing the one connector in `place`. There is
		# no further doorway to claim here.
		_note("the run is %s; the cell was put down in the socket's room"
				% [volume])
	var socket := _socket(controller)
	await _approach(controller, socket, 1.4, socket.global_position
			+ Vector3(0.0, ObjectSocket.BASE.y * 0.6, 0.0))
	_check(player._last_prompt == "[E] INSTALL",
			"at the socket: \"%s\"" % player._last_prompt)
	await _press("interact")
	var accepted := await _await_live("the bridge to record the install",
			func() -> bool:
				return not _row(_served().get("consumed_objects"),
					CELL).is_empty(), 10.0)
	_check(accepted and _row(_served().get("consumed_objects"), CELL)
			== [CELL, SOCKET]
			and _row(_served().get("macro_state"), VARIABLE)
				== [VARIABLE, "powered"],
			"ACCEPTED: installed in %s, %s = powered, in the snapshot"
			% [SOCKET, VARIABLE])
	var saved := _saved()
	_check(_row(saved.get("consumed_objects"), CELL) == [CELL, SOCKET]
			and _row(saved.get("macro_state"), VARIABLE)
				== [VARIABLE, "powered"]
			and _row(saved.get("object_poses"), CELL).is_empty(),
			"SAVED: consumed, powered, and no loose pose left on disk")
	var gate := _gate(controller)
	var opened := await _wait_for(func() -> bool: return gate.shutter.is_open(),
			600)
	_check(opened, "the doorway opened")

	# ---- forgeries that would duplicate or move it -----------------------
	await _refused({"type": "object_recovered", "zone_id": ZONE_ID,
			"object_id": CELL}, "installed", "recovering an installed cell")
	# INTO ANOTHER ROOM OF ITS VOLUME: home, which is never the socket's
	# room. (On a two-room run the "middle" room IS the socket's, and a
	# report of the room it is already in is not a move at all.)
	await _refused({"type": "object_transported", "zone_id": ZONE_ID,
			"object_id": CELL, "room_id": str(volume[0])}, "does not move",
			"moving an installed cell")
	await _refused({"type": "object_settled", "zone_id": ZONE_ID,
			"object_id": CELL, "room_id": consumer_room,
			"position": [0.0, 0.0, 0.0], "yaw": 0.0}, "installed",
			"a loose pose for an installed cell")
	_check(_row(_served().get("consumed_objects"), CELL) == [CELL, SOCKET]
			and _row(_saved().get("consumed_objects"), CELL)
				== [CELL, SOCKET],
			"and the record is unchanged, in the snapshot and on disk")
	await _leave()
	print("installed: %s in %s; leaving for restart 2" % [CELL, SOCKET])


# ---------------------------------------------------------------------------
# restore: after restart 2
# ---------------------------------------------------------------------------

func _restore() -> void:
	if not await _campaign():
		return
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) == ZONE_ID,
			"RESTART 2: the new bridge loaded the save; the Hub offers '%s'"
			% str(BridgeClient.hub().get("resume_zone_id", "")))
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var player := controller.player
	var zone_data: Dictionary = BridgeClient.active_zone().get("zone", {})
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var consumer_room := str(volume[volume.size() - 1])
	var socket := _socket(controller)
	var gate := _gate(controller)
	_check(controller.objects.body_of(CELL) == null and _copies(CELL) == 1
			and socket.installed_object == CELL and socket.seated != null,
			"INSTALLED AT LOAD: one cell, seated in the socket, no loose copy")
	_check(gate.shutter.is_open() and gate.shutter.openness() >= 0.999,
			"the doorway is open the moment the Zone exists (%.2f)"
			% gate.shutter.openness())
	_check(_lamps(controller).all(
			func(l: ZoneStateBuild.ZoneStateMechanism) -> bool:
				return l.driven), "the lamps are lit")
	var edge := _gated_edge(zone_data)
	var beyond := str(edge["room_b"]) if str(edge["room_a"]) \
			== consumer_room else str(edge["room_a"])
	if not await _advance_to(controller, consumer_room):
		return
	var through := await _walk_into(controller, beyond)
	_check(bool(through["inside"]) and _deaths == 0,
			"THROUGH: the player walks the doorway into %s" % beyond)
	_check(_intents("object_consumed").is_empty()
			and _intents("object_transported").is_empty()
			and _intents("zone_state_selected").is_empty(),
			"and nothing was announced: the installation is remembered, "
			+ "not repeated")
