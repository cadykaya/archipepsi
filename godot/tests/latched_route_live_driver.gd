class_name LatchedRouteLiveDriver
extends "res://tests/latched_route_driver.gd"
## P14 — THE LATCHED ROUTE THROUGH THE REAL BRIDGE, AND BACK AFTER A
## RESTART (`--latched-live=<phase>`).
##
##     make godot-latched-route-live
##
## Three runs of this driver against one disposable save, at the default
## scale Dess's fixture was composed at:
##
##   seed     the real path makes the campaign and generates zone_001, and
##            stops before anyone enters it. `tools/compose_latched_route.py`
##            then takes D-10's explicit step -- `compose_latched_route`, on
##            that Zone -- and checks the result IS `latched_route_zone.json`
##            (same digest: nothing re-keyed).
##   play     a new bridge and the real `Main`. The portal; the bridge's own
##            layout verdict; the arena cleared with the base kit; the plate
##            stepped on, and the real `latch_fired` accepted, carried back
##            in the snapshot and read off the save file on disk. Forged
##            latches refused -- one sent before the layout is committed, an
##            unknown latch, a room with no graph and a room that was never
##            placed. Then off the plate, through the doorway, and out of
##            the Zone the way the game leaves one.
##   restore  both processes new again, and only the save crossed. The
##            portal leads back; the route is open when the Zone is built,
##            before anyone reaches the plate; nothing is announced; and
##            the doorway is walked into c003 without the plate being
##            touched at all.
##
## **BESIDE `Main`, like `ReloadDriver`**, because `Main` is what is under
## test: `_to_zone` is what hands the saved latch to the Zone before its
## graph is first evaluated, and a driver that built its own
## `ZoneController` would be testing a copy of that.

const PHASE_FLAG := "--latched-live="
const SAVE_DIR_FLAG := "--latched-save-dir="
const ZONE_ID := "zone_001"

var main: Node
var _errors: Array[String] = []
var _touched_plate := false
## Forged `latch_fired` intents this driver sent itself. They go through
## the same `send_intent` and land in the same `sent_intents` as the
## Zone's own report -- the pre-commit probe is byte-identical to it --
## so the Zone's reports are the total less these.
var _forged := 0


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
			"play":
				await _play()
			"restore":
				await _restore()
			_:
				_check(false, "no --latched-live phase was named")
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"jump", "fire_pulse"]:
		Input.action_release(action)
	var phase := phase_from_cmdline().to_upper()
	if failures == 0:
		print("GODOT LATCHED LIVE %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT LATCHED LIVE %s: %d failures in %d checks"
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


## The campaign the bridge loaded, or made on the first run.
func _campaign() -> bool:
	if BridgeClient.hub_mode() == "NO_CAMPAIGN":
		BridgeClient.send_intent({"type": "start_mock_campaign"})
	return await _await_live("a campaign",
			func() -> bool: return BridgeClient.hub_mode() != "NO_CAMPAIGN",
			30.0)


## THE REAL ENTRY PATH: the Hub's portal, pressed, and everything after it
## -- which id, which intent, which handler -- belonging to `Main`.
func _through_the_portal() -> ZoneController:
	var offered := func() -> bool:
		var standing := main.hub as HubController
		return standing != null and standing.portal() != null \
				and standing.portal().interact_prompt() != ""
	if not await _await_live("the Hub's portal", offered, 30.0):
		return null
	(main.hub as HubController).portal().interact(main)
	if not await _await_live("ZONE_ACTIVE",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_ACTIVE",
			30.0):
		return null
	if not await _await_live("Main builds the Zone",
			func() -> bool:
				return main.zone != null and main.zone.player != null,
			40.0):
		return null
	return main.zone as ZoneController


## What this Zone's route is made of, read off the built Zone and the
## declaration it was built from.
func _route(controller: ZoneController, zone_data: Dictionary) -> Dictionary:
	if controller.signal_graphs.is_empty():
		_check(false, "the served Zone built its graph: %s"
				% [controller.signal_graph_refusals])
		return {}
	var graph: SignalGraph = controller.signal_graphs[0]
	var edge := _route_edge(zone_data)
	var room := graph.room_id
	var frame := RoomGraphs.doorway_frame(room, edge,
			zone_data.get("chambers", []) as Array, controller.door_frames)
	if frame.is_empty():
		_check(false, "the route's doorway was built")
		return {}
	var far_room := str(edge.get("room_b", "")) \
			if str(edge.get("room_a", "")) == room \
			else str(edge.get("room_a", ""))
	var box: AABB = controller.room_bounds[room]
	var plate: ClassPlate = graph.sensors.values()[0]
	return {"graph": graph, "room": room, "far_room": far_room,
			"frame": frame, "box": box,
			"far_box": controller.room_bounds[far_room],
			"inward": _inward_of(frame, box),
			"plate": plate,
			"shutter": (graph.actuators.values()[0] as Dictionary)["node"],
			"ref": "%s/%s" % [graph.package_id(),
				_latch_id(zone_data, room)]}


func _latch_id(zone_data: Dictionary, room: String) -> String:
	for raw: Variant in zone_data.get("room_graphs", []) as Array:
		var declared: Dictionary = raw
		if str(declared.get("room_id", "")) != room:
			continue
		for node: Variant in declared.get("nodes", []) as Array:
			if str((node as Dictionary).get("kind", "")) == "LATCH":
				return str((node as Dictionary).get("node_id", ""))
	return ""


func _zone_reports() -> int:
	return _latch_reports().size() - _forged


func _served_latches() -> Array:
	var progress: Variant = BridgeClient.active_zone().get("progress", {})
	return (progress as Dictionary).get("latched", []) as Array \
			if typeof(progress) == TYPE_DICTIONARY else []


## THE SAVE FILE ITSELF, read off the disk the bridge writes to. `_apply`
## persists before it assigns, so a latch the snapshot carries is already
## there -- and reading the file rather than the snapshot is what makes
## "saved" a fact and not an inference.
func _saved_latches() -> Array:
	var dir := _arg(SAVE_DIR_FLAG)
	var names: Array[String] = []
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".json"):
			names.append(name)
	if names.size() != 1:
		return ["<%d saves in '%s'>" % [names.size(), dir]]
	var save: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(dir.path_join(names[0])))
	if typeof(save) != TYPE_DICTIONARY:
		return ["<unreadable save>"]
	for raw: Variant in (save as Dictionary).get("zones", []) as Array:
		var record: Dictionary = raw
		if str(record.get("zone_id", "")) == ZONE_ID:
			return (record.get("progress", {}) as Dictionary).get(
					"latched", []) as Array
	return ["<no %s in the save>" % ZONE_ID]


## One forged `latch_fired`, and the refusal it must draw.
func _refused(package_id: String, latch_id: String, because: String,
		what: String) -> void:
	_errors.clear()
	_forged += 1
	BridgeClient.send_intent({"type": "latch_fired", "zone_id": ZONE_ID,
			"package_id": package_id, "latch_id": latch_id})
	var answered := await _await_live("the refusal of %s/%s"
			% [package_id, latch_id],
			func() -> bool: return not _errors.is_empty(), 10.0)
	_check(answered and because in _errors[0],
			"REFUSED, %s: %s/%s -> \"%s\"" % [what, package_id, latch_id,
				_errors[0] if answered else "no answer"])


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
	_check((zone.get("room_graphs", []) as Array).is_empty(),
			"and composed it WITHOUT a room graph: the latch route is an "
			+ "explicit step, never a default")
	print("seeded: %s generated, not entered" % ZONE_ID)


# ---------------------------------------------------------------------------
# play
# ---------------------------------------------------------------------------

func _play() -> void:
	if not await _campaign():
		return
	if not await _await_live("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return
	var zone_data: Dictionary = BridgeClient.active_zone().get("zone", {})
	var declared := zone_data.get("room_graphs", []) as Array
	var edge := _route_edge(zone_data)
	_check(declared.size() == 1 and not edge.is_empty(),
			"the bridge serves the composed route: a graph in '%s', the "
			% (str((declared[0] as Dictionary).get("room_id", ""))
				if not declared.is_empty() else "-")
			+ "shutter across '%s'" % str(edge.get("edge_id", "-")))
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var player: Player = controller.player
	var route := _route(controller, zone_data)
	if route.is_empty():
		return
	var ref := str(route["ref"])
	var room := str(route["room"])

	# ---- UNCOMMITTED: a real latch id, before the layout is accepted ----
	_check(controller.layout_verdict == ""
			and str(BridgeClient.active_zone().get("layout_state", ""))
				!= "ACCEPTED",
			"the layout is not committed yet (verdict '%s', bridge '%s')"
			% [controller.layout_verdict,
				str(BridgeClient.active_zone().get("layout_state", ""))])
	var parts := ref.split("/")
	await _refused(parts[0], parts[1], "has no committed layout",
			"before the layout is committed")
	_check(_served_latches().is_empty(),
			"and nothing was recorded: %s" % [_served_latches()])

	# ---- THE BRIDGE'S OWN VERDICT --------------------------------------
	if not await _await_live("the bridge accepts the layout",
			func() -> bool: return controller.layout_verdict == "ACCEPTED",
			40.0):
		return
	_check(player.holds().is_empty() and player.hp == Constants.PLAYER_MAX_HP,
			"ACCEPTED by the bridge, the player released untouched "
			+ "(holds %s, %.0f hp)" % [player.holds(), player.hp])
	_last_hp = player.hp
	player.died.connect(func() -> void: _deaths += 1)
	var shutter: ServiceShutter = route["shutter"]
	var plate: ClassPlate = route["plate"]
	_check(not shutter.is_open() and not plate.satisfied()
			and _served_latches().is_empty(),
			"the route starts shut and unlatched")

	# ---- TO THE PLATE, with the body -----------------------------------
	await _walk_into(controller, room)
	var fight := await _clear_room(controller, room)
	_check(int(fight["left"]) == 0 and _deaths == 0,
			"the arena is cleared with the base kit: %s" % _account(fight))
	for _i in 60:
		await get_tree().physics_frame
	await _walk_to(player, plate.global_position, AABB(), 900, false, 0.3)
	var on := await _wait_for(func() -> bool: return plate.satisfied(), 60)
	_check(on and _player_on(plate, player),
			"STEP ON: the player's own body satisfies the plate (%s)"
			% [plate.reading()])
	var reported := await _wait_for(
			func() -> bool: return _zone_reports() == 1, 60)
	_check(reported and _latch_reports().back() == {"type": "latch_fired",
				"zone_id": ZONE_ID, "package_id": parts[0],
				"latch_id": parts[1]},
			"the Zone's own `latch_fired` went out once: %s"
			% [_latch_reports().back()])

	# ---- ACCEPTED, AND SAVED -------------------------------------------
	var accepted := await _await_live("the bridge to carry %s" % ref,
			func() -> bool: return ref in _served_latches(), 10.0)
	_check(accepted and _served_latches() == [ref],
			"ACCEPTED: the snapshot carries exactly %s" % [_served_latches()])
	_check(_saved_latches() == [ref],
			"SAVED: the save file on disk holds exactly %s"
			% [_saved_latches()])

	# ---- FORGED LATCHES, REFUSED: a `graph_` name authorizes nothing ---
	await _refused(parts[0], "forged", "declares no LATCH 'forged'",
			"an unknown latch in the right room")
	await _refused("graph_c001", parts[1], "declares no signal graph",
			"the right latch id in a room with no graph")
	await _refused("graph_c099", parts[1], "placed no room 'c099'",
			"the prefix alone, for a room the layout never placed")
	_check(_served_latches() == [ref] and _saved_latches() == [ref],
			"and the record is still exactly %s, in the snapshot and on "
			% ref + "disk (%s / %s)" % [_served_latches(), _saved_latches()])

	# ---- OFF, AND THROUGH ----------------------------------------------
	var door: Vector3 = (route["frame"] as Dictionary)["position"]
	var inward: Vector3 = route["inward"]
	await _walk_to(player, door + inward * 1.4, AABB(), 600, false, 0.5)
	await _wait_for(func() -> bool: return not plate.satisfied(), 60)
	var opened := await _wait_for(func() -> bool: return shutter.is_open(),
			300)
	_check(not _player_on(plate, player) and opened,
			"STEP OFF: nobody on the plate and the way is open (%.2f)"
			% shutter.openness())
	var far_room := str(route["far_room"])
	var far_box: AABB = route["far_box"]
	await _walk_into(controller, far_room)
	_check(far_box.has_point(player.global_position) and _deaths == 0,
			"THROUGH: walked the doorway into %s (ended %v)"
			% [far_room, player.global_position])
	_check(_zone_reports() == 1,
			"one `latch_fired` from the Zone in the whole visit (%d, and "
			% _zone_reports() + "%d forged by this driver)" % _forged)

	# ---- OUT, THE WAY THE GAME LEAVES ----------------------------------
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": ZONE_ID})
	await _await_live("the Zone goes dormant",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			20.0)
	print("played: %s latched and saved; leaving for the restart" % ref)


# ---------------------------------------------------------------------------
# restore
# ---------------------------------------------------------------------------

func _restore() -> void:
	if not await _campaign():
		return
	# THE SAVED CAMPAIGN, not a new one under the same name: the Hub names
	# the dormant Zone the portal leads back to.
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) == ZONE_ID,
			"the restarted bridge loaded the save; the Hub offers '%s'"
			% str(BridgeClient.hub().get("resume_zone_id", "")))
	_check(main._zone_latches.is_empty(),
			"this process remembers no latch of its own")
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var zone_data: Dictionary = BridgeClient.active_zone().get("zone", {})
	var route := _route(controller, zone_data)
	if route.is_empty():
		return
	var ref := str(route["ref"])
	var graph: SignalGraph = route["graph"]
	var shutter: ServiceShutter = route["shutter"]
	var plate: ClassPlate = route["plate"]
	var player: Player = controller.player
	# Every contact from here on, however brief, not a sample.
	(plate.get_node("Sensor") as Area3D).body_entered.connect(
			func(body: Node3D) -> void:
				if body == player:
					_touched_plate = true)

	# ---- RESTORED BEFORE THE FIRST EVALUATION --------------------------
	_check(ref in _served_latches(),
			"the bridge hands back %s from the save" % ref)
	_check(controller.latches_carried.has(ref),
			"and `Main` gave it to the Zone before setup (%s)"
			% [controller.latches_carried.keys()])
	_check(graph.restored == 1 and graph.latched.size() == 1,
			"the graph restored the latch before it first evaluated "
			+ "(restored %d)" % graph.restored)
	_check(shutter.is_open() and shutter.openness() >= 0.999,
			"the route is OPEN the moment the Zone exists, settled rather "
			+ "than opening (%.2f)" % shutter.openness())
	_check(controller.latches_fired().is_empty() and _latch_reports().is_empty(),
			"and nothing was announced: no new decision, no `latch_fired`")

	if not await _await_live("the bridge accepts the replayed layout",
			func() -> bool: return controller.layout_verdict == "ACCEPTED",
			40.0):
		return
	_last_hp = player.hp
	player.died.connect(func() -> void: _deaths += 1)

	# ---- THROUGH, WITHOUT THE PLATE ------------------------------------
	var room := str(route["room"])
	await _walk_into(controller, room)
	var fight := await _clear_room(controller, room)
	_check(int(fight["left"]) == 0 and _deaths == 0,
			"the arena is dealt with the same way: %s" % _account(fight))
	var far_room := str(route["far_room"])
	var far_box: AABB = route["far_box"]
	await _walk_into(controller, far_room)
	var door: Vector3 = (route["frame"] as Dictionary)["position"]
	_check(far_box.has_point(player.global_position),
			"THROUGH: walked the doorway into %s (ended %v)"
			% [far_room, player.global_position])
	_check(_side_of(route["frame"], route["inward"], player.global_position)
			< 0.0, "on the far side of the door plane (%.1f m past it)"
			% -_side_of(route["frame"], route["inward"],
				player.global_position))
	_check(not _touched_plate and not plate.satisfied(),
			"WITHOUT THE PLATE: the body never entered its sensing volume")
	_check(_latch_reports().is_empty() and controller.latches_fired().is_empty()
			and _served_latches() == [ref],
			"and nothing was announced on the way: the record is still "
			+ "exactly %s" % [_served_latches()])
	_note("restored route walked: portal -> %s -> doorway -> %s, %.1f m "
			% [room, far_room, door.distance_to(player.global_position)]
			+ "past the door, plate untouched, %d death(s)" % _deaths)
