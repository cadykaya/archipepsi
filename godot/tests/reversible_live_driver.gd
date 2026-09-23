class_name ReversibleLiveDriver
extends "res://tests/reversible_driver.gd"
## O05-04.5 — THE REVERSIBLE LEVER THROUGH A REAL BRIDGE, AND BACK AFTER A
## RESTART (`--reversible-live=<phase>`).
##
##     make godot-reversible-live
##
## Three runs of this driver against one disposable save, each a new client
## beside a new bridge running the CANDIDATE profile's `zone_state` step
## (`--candidate=zone_state`). Only the save crosses between runs:
##
##   seed     the real path generates zone_001, and the profile adds the
##            lever before the Zone is accepted. The served Zone is checked
##            to be `reversible_zone.json`, field for field.
##   select   through the portal to the bridge's own verdict. c002 is
##            cleared with the base kit. The lever is pulled with the
##            interact ray and says PENDING; the snapshot carries `lowered`,
##            and the lever says ACCEPTED. The save file on disk holds it.
##            A forged selection of a state the Zone does not declare is
##            refused, and the refusal carries the selection's own `about`
##            key. Nothing moves. The player walks through and leaves the
##            Zone with the lever still LOWERED -- the non-default
##            configuration.
##   restore  both processes are new. The doorway is open the moment the
##            Zone exists; nothing is announced; and the player walks
##            through it without touching the lever.
##
## **BESIDE `Main`**, like the P14 and transport live drivers, because
## `Main._to_zone` is what hands the saved value to the Zone before it is
## built.

const PHASE_FLAG := "--reversible-live="
const SAVE_DIR_FLAG := "--reversible-save-dir="
const ZONE_ID := "zone_001"

var main: Node
var _errors: Array = []


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
		_errors.append(err))
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		match phase_from_cmdline():
			"seed":
				await _seed()
			"select":
				await _select()
			"restore":
				await _restore()
			_:
				_check(false, "no --reversible-live phase was named")
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"move_back", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	var phase := phase_from_cmdline().to_upper()
	if failures == 0:
		print("GODOT REVERSIBLE LIVE %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT REVERSIBLE LIVE %s: %d failures in %d checks"
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
	player.died.connect(func() -> void: _deaths += 1)
	return controller


func _served_value() -> String:
	var progress: Variant = BridgeClient.active_zone().get("progress", {})
	if typeof(progress) != TYPE_DICTIONARY:
		return ""
	for row: Variant in (progress as Dictionary).get("macro_state", []) \
			as Array:
		if typeof(row) == TYPE_ARRAY and str((row as Array)[0]) == SPAN:
			return str((row as Array)[1])
	return ""


func _saved_value() -> String:
	var dir := _arg(SAVE_DIR_FLAG)
	var names: Array[String] = []
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".json"):
			names.append(name)
	if names.size() != 1:
		return "<%d saves>" % names.size()
	var save: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(dir.path_join(names[0])))
	if typeof(save) != TYPE_DICTIONARY:
		return "<unreadable>"
	for raw: Variant in (save as Dictionary).get("zones", []) as Array:
		var record: Dictionary = raw
		if str(record.get("zone_id", "")) != ZONE_ID:
			continue
		for row: Variant in (record.get("progress", {}) as Dictionary).get(
				"macro_state", []) as Array:
			if typeof(row) == TYPE_ARRAY and str((row as Array)[0]) == SPAN:
				return str((row as Array)[1])
		return ""
	return "<no %s>" % ZONE_ID


# ---------------------------------------------------------------------------

func _seed() -> void:
	if not await _campaign():
		return
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	if not await _await_live("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			90.0):
		return
	var zone: Dictionary = BridgeClient.active_zone().get("zone", {})
	var fixture: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(REVERSIBLE_FIXTURE))
	for key: String in ["zone_state", "edges", "chambers"]:
		_check(JSON.stringify(zone.get(key)) == JSON.stringify(
				fixture.get(key)),
				"the served Zone's %s are the fixture's, field for field"
				% key)
	print("seeded: %s generated with the candidate zone_state step"
			% ZONE_ID)


func _select() -> void:
	if not await _campaign():
		return
	if not await _await_live("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var zone_data := _zone_data
	var declared: Dictionary = (zone_data["zone_state"] as Array)[0]
	var setter_room := str((declared["setter"] as Dictionary)["room_id"])
	var edge := _gated_edge(zone_data)
	var beyond := str(edge["room_b"]) if str(edge["room_a"]) == setter_room \
			else str(edge["room_a"])
	var gate := _gate(controller)
	var lever := _lever(controller)
	_check(gate.shutter.is_shut() and _served_value() in ["", "stowed"],
			"the route starts shut; the campaign holds '%s'" % _served_value())

	# ---- a forged selection: refused, with its own key ------------------
	_errors.clear()
	BridgeClient.send_intent({"type": "zone_state_selected",
			"zone_id": ZONE_ID, "variable_id": SPAN, "state": "sideways"})
	var answered := await _await_live("the refusal",
			func() -> bool: return not _errors.is_empty(), 10.0)
	var err: Dictionary = _errors[0] if answered else {}
	_check(answered and str(err.get("about", "")) == \
			"zone_state_selected:%s:%s:sideways" % [ZONE_ID, SPAN],
			"REFUSED, a state the Zone does not declare -> \"%s\" (about "
			% str(err.get("message", "")) + "'%s')" % str(err.get("about")))
	_check(controller.zone_state.value_of(SPAN) == "stowed"
			and gate.shutter.is_shut(),
			"and nothing moved: the lever was not pending on it")

	# ---- operated, accepted --------------------------------------------
	if not await _advance_to(controller, setter_room):
		return
	# THE STATUS, FRAME BY FRAME. A real bridge can answer inside the
	# frames the pull itself takes, so one look afterwards may find the
	# lever already ACCEPTED; what has to be true is that PENDING was
	# shown first, and then the verdict.
	var shown: Array[String] = []
	var sampling := {"on": true}
	var sampler := func() -> void:
		while sampling["on"]:
			if shown.is_empty() or shown.back() != lever.status:
				shown.append(lever.status)
			await get_tree().process_frame
	sampler.call()
	var pulled := await _pull(controller)
	var accepted := await _await_live("the snapshot to carry it",
			func() -> bool: return lever.status == "ACCEPTED", 10.0)
	sampling["on"] = false
	_check(pulled and shown.has("PENDING") and shown.has("ACCEPTED")
			and shown.find("PENDING") < shown.find("ACCEPTED"),
			"PULLED with the interact ray; the lever showed %s, in order"
			% [shown])
	_check(accepted and _served_value() == "lowered"
			and lever.interact_prompt().contains("ACCEPTED"),
			"ACCEPTED: the snapshot carries '%s' and the lever says so: "
			% _served_value() + "\"%s\"" % lever.interact_prompt())
	_check(_saved_value() == "lowered",
			"SAVED: the file on disk holds '%s'" % _saved_value())
	var opened := await _wait_for(func() -> bool:
		return gate.shutter.is_open(), 600)
	var through := await _walk_into(controller, beyond)
	_check(opened and bool(through["inside"]),
			"THROUGH into %s" % beyond)
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": ZONE_ID})
	await _await_live("the Zone goes dormant",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			20.0)
	print("selected: %s lowered and saved; leaving for the restart" % SPAN)


func _restore() -> void:
	if not await _campaign():
		return
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) == ZONE_ID,
			"RESTART: the new bridge loaded the save; the Hub offers '%s'"
			% str(BridgeClient.hub().get("resume_zone_id", "")))
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var gate := _gate(controller)
	_check(controller.macro_carried.get(SPAN) == "lowered",
			"`Main` handed the saved value to the Zone before it was built")
	_check(gate.shutter.is_open() and gate.shutter.openness() >= 0.999
			and _lit(controller),
			"the doorway is open the moment the Zone exists (%.2f), the "
			% gate.shutter.openness() + "lamp lit")
	var declared: Dictionary = (_zone_data["zone_state"] as Array)[0]
	var setter_room := str((declared["setter"] as Dictionary)["room_id"])
	var edge := _gated_edge(_zone_data)
	var beyond := str(edge["room_b"]) if str(edge["room_a"]) == setter_room \
			else str(edge["room_a"])
	if not await _advance_to(controller, setter_room):
		return
	var through := await _walk_into(controller, beyond)
	_check(bool(through["inside"]) and _selections("lowered") == 0
			and _selections("stowed") == 0,
			"THROUGH into %s without touching the lever; nothing announced"
			% beyond)
