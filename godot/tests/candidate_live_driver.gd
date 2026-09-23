class_name CandidateLiveDriver
extends "res://tests/reversible_driver.gd"
## O05-13 / O05-15 — THE WHOLE CANDIDATE PROFILE, IN ONE ZONE, THROUGH A
## REAL BRIDGE, AND BACK AFTER A RESTART (`--candidate-live=<phase>`).
##
##     make godot-candidate-live
##
## The candidate launcher (`archipepsi_bridge.diagnostic --candidate`)
## composes every new Zone with ALL THREE steps at once, and each step's
## own suite plays it alone on its own fixture. This is the combination
## the owner actually gets: the reversible lever, P14's latched route and
## the power cell, composed by the real generation path into one Zone.
## Three runs against one disposable save, each a new client beside a new
## bridge running `--candidate=all`; only the save crosses:
##
##   seed     the real path generates zone_001 with the whole profile. The
##            served Zone is `candidate_zone.json` field for field, three
##            relationships on three different doorways, and the bridge
##            wrote what each step did under `candidate/zone_001.json`.
##   play     through the portal to the bridge's verdict. Everything the
##            three declare is BUILT and nothing is refused; the lever
##            does not stand on the plate. Then, in the order the Zone
##            asks: the lever pulled with the interact ray (ACCEPTED off
##            the snapshot) opens the spine doorway; the cell is carried
##            from its home across the connector and installed (ACCEPTED)
##            and its doorway opens; the player walks through. P14's
##            branch stays shut -- its latch is its own suite's to play.
##   restore  both processes new. The lever still lowered and its doorway
##            open, the cell seated and its doorway open, P14's shutter
##            still shut, before anyone acts; nothing announced.
##
## **HARNESS STEPS, declared:** the same as the suites this reuses -- a
## shielded Bulwark removed through the damage path from behind when the
## base-kit flank does not land (P5-7, printed as a NOTE).

const PHASE_FLAG := "--candidate-live="
const SAVE_DIR_FLAG := "--candidate-save-dir="
const ZONE_ID := "zone_001"
const CANDIDATE_FIXTURE := "res://tests/fixtures/candidate_zone.json"
const PROFILE := ["zone_state", "transport", "latched_route"]

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
			"play":
				await _play()
			"restore":
				await _restore()
			_:
				_check(false, "no --candidate-live phase was named")
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"move_back", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	var phase := phase_from_cmdline().to_upper()
	if failures == 0:
		print("GODOT CANDIDATE LIVE %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT CANDIDATE LIVE %s: %d failures in %d checks"
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


func _served() -> Dictionary:
	var progress: Variant = BridgeClient.active_zone().get("progress", {})
	return progress if typeof(progress) == TYPE_DICTIONARY else {}


static func _row(rows: Variant, key: String) -> Array:
	if typeof(rows) != TYPE_ARRAY:
		return []
	for row: Variant in rows as Array:
		if typeof(row) == TYPE_ARRAY and not (row as Array).is_empty() \
				and str((row as Array)[0]) == key:
			return row
	return []


func _leave() -> void:
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": ZONE_ID})
	await _await_live("the Zone goes dormant",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			20.0)


## The declared edge a variable gates, off the served Zone.
func _edge_for(variable: String) -> Dictionary:
	for raw: Variant in _zone_data.get("edges", []) as Array:
		for cond: Variant in (raw as Dictionary).get("requires_state", []) \
				as Array:
			if str((cond as Dictionary).get("variable_id", "")) == variable:
				return raw
	return {}


func _gate_on(controller: ZoneController, edge_id: String) \
		-> StateGates.StateGate:
	for raw: Variant in controller.state_gates:
		var gate: StateGates.StateGate = raw
		if gate.edge_id == edge_id:
			return gate
	return null


## P14's route shutters: every ServiceShutter a room graph drives.
func _route_shutters(controller: ZoneController) -> Array:
	var out: Array = []
	for raw: Variant in controller.signal_graphs:
		var graph: SignalGraph = raw
		for binding: Variant in graph.actuators.values():
			var node: Variant = (binding as Dictionary).get("node") \
					if typeof(binding) == TYPE_DICTIONARY else binding
			if node is ServiceShutter:
				out.append(node)
	return out


func _plates(controller: ZoneController) -> Array:
	var out: Array = []
	for raw: Variant in controller.signal_graphs:
		var graph: SignalGraph = raw
		for sensor: Variant in graph.sensors.values():
			var node: Variant = (sensor as Dictionary).get("node") \
					if typeof(sensor) == TYPE_DICTIONARY else sensor
			if node is Node3D:
				out.append(node)
	return out


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
			FileAccess.get_file_as_string(CANDIDATE_FIXTURE))
	for key: String in ["zone_state", "room_graphs", "transported_objects",
			"object_consumers", "edges", "chambers"]:
		_check(JSON.stringify(zone.get(key)) == JSON.stringify(
				fixture.get(key)),
				"the served Zone's %s are the fixture's, field for field"
				% key)
	# ONE GATE PER DOORWAY (P5-1), across all three composers.
	var gated: Array = []
	for raw: Variant in zone.get("edges", []) as Array:
		var edge: Dictionary = raw
		var state := not (edge.get("requires_state", []) as Array).is_empty()
		var latch := edge.get("opened_by") != null
		_check(not (state and latch),
				"%s is not gated twice" % str(edge.get("edge_id", "")))
		if state or latch:
			gated.append(str(edge.get("edge_id", "")))
	_check(gated.size() == 3,
			"three relationships on three doorways: %s" % [gated])
	# AND WHAT EACH STEP DID, as the bridge recorded it.
	var record_path := _arg(SAVE_DIR_FLAG).path_join("candidate") \
			.path_join("%s.json" % ZONE_ID)
	var record: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(record_path))
	var steps: Array = (record as Dictionary).get("steps", []) \
			if typeof(record) == TYPE_DICTIONARY else []
	_check(typeof(record) == TYPE_DICTIONARY
			and (record as Dictionary).get("profile") == PROFILE
			and steps.size() == 3
			and steps.all(func(s: Variant) -> bool:
				return bool((s as Dictionary).get("emitted", false))),
			"the bridge recorded all three steps EMITTED in %s"
			% record_path)
	print("seeded: %s generated with the whole candidate profile" % ZONE_ID)


func _play() -> void:
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
	var player := controller.player

	# ---- all three BUILT, nothing refused ------------------------------
	_check(controller.zone_state_refusals.is_empty()
			and controller.state_gate_refusals.is_empty()
			and controller.object_socket_refusals.is_empty()
			and controller.signal_graph_refusals.is_empty(),
			"nothing refused: zone-state %s, gates %s, sockets %s, graphs %s"
			% [controller.zone_state_refusals,
				controller.state_gate_refusals,
				controller.object_socket_refusals,
				controller.signal_graph_refusals])
	var span_edge := _edge_for(SPAN)
	var cell_edge := _edge_for(VARIABLE)
	var span_gate := _gate_on(controller, str(span_edge.get("edge_id", "")))
	var cell_gate := _gate_on(controller, str(cell_edge.get("edge_id", "")))
	var lever := _lever(controller)
	var socket := _socket(controller)
	var shutters := _route_shutters(controller)
	_check(span_gate != null and cell_gate != null and lever != null
			and socket != null and controller.objects.body_of(CELL) != null
			and shutters.size() == 1,
			"built: the lever, its gate, the cell, its socket and gate, and "
			+ "P14's shutter (%d)" % shutters.size())
	if span_gate == null or cell_gate == null or lever == null \
			or socket == null or shutters.is_empty():
		return
	_check(span_gate.shutter.is_shut() and cell_gate.shutter.is_shut()
			and (shutters[0] as ServiceShutter).is_shut(),
			"all three doorways start shut")
	var nearest := INF
	for plate: Variant in _plates(controller):
		nearest = minf(nearest, (plate as Node3D).global_position
				.distance_to(lever.global_position))
	_check(nearest > 1.5,
			"the lever does not stand on P14's plate (%.1f m apart)"
			% nearest)

	# ---- the lever opens the spine -------------------------------------
	var declared: Dictionary = {}
	for raw: Variant in _zone_data.get("zone_state", []) as Array:
		if str((raw as Dictionary).get("variable_id", "")) == SPAN:
			declared = raw
	var setter_room := str((declared.get("setter", {}) as Dictionary)
			.get("room_id", ""))
	var beyond := str(span_edge["room_b"]) \
			if str(span_edge["room_a"]) == setter_room \
			else str(span_edge["room_a"])
	if not await _advance_to(controller, setter_room):
		return
	var pulled := await _pull(controller)
	var accepted := await _await_live("the lever's verdict",
			func() -> bool: return lever.status == "ACCEPTED", 10.0)
	_check(pulled and accepted
			and _row(_served().get("macro_state"), SPAN) == [SPAN, "lowered"],
			"PULLED and ACCEPTED: the snapshot holds %s"
			% [_row(_served().get("macro_state"), SPAN)])
	var spine_open := await _wait_for(func() -> bool:
		return span_gate.shutter.is_open(), 600)
	_check(spine_open, "the lever's doorway %s opened"
			% str(span_edge.get("edge_id", "")))

	# ---- the cell, carried and installed -------------------------------
	var objects: Array = _zone_data.get("transported_objects", []) as Array
	var volume: Array = (objects[0] as Dictionary)["allowed_volume"]
	var home := str(volume[0])
	var consumer_room := str(volume[volume.size() - 1])
	if not await _advance_to(controller, consumer_room):
		return
	await _retreat_to(controller, home)
	var cell := controller.objects.body_of(CELL)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	_check(player.carry.holding() and player.carry.body == cell,
			"the cell is picked up at home in %s" % home)
	var into := await _walk_into(controller, consumer_room)
	_check(bool(into["inside"]) and player.carry.holding(),
			"carried across the connector into %s" % consumer_room)
	await _approach(controller, socket, 1.4, socket.global_position
			+ Vector3(0.0, ObjectSocket.BASE.y * 0.6, 0.0))
	_check(player._last_prompt == "[E] INSTALL",
			"at the socket: \"%s\"" % player._last_prompt)
	await _press("interact")
	var installed := await _await_live("the bridge to record the install",
			func() -> bool:
				return not _row(_served().get("consumed_objects"),
					CELL).is_empty(), 10.0)
	_check(installed
			and _row(_served().get("macro_state"), VARIABLE)
				== [VARIABLE, "powered"],
			"INSTALLED and ACCEPTED: %s powered in the snapshot" % VARIABLE)
	var cell_open := await _wait_for(func() -> bool:
		return cell_gate.shutter.is_open(), 600)
	var cell_beyond := str(cell_edge["room_b"]) \
			if str(cell_edge["room_a"]) == consumer_room \
			else str(cell_edge["room_a"])
	var through := await _walk_into(controller, cell_beyond)
	_check(cell_open and bool(through["inside"]),
			"the cell's doorway opened and the player walked into %s"
			% cell_beyond)
	_check((shutters[0] as ServiceShutter).is_shut(),
			"and P14's branch is still shut: nothing here latched it")
	_check(beyond != "", "the lever's consequence was in %s" % beyond)
	await _leave()
	print("played: lever lowered, cell installed; leaving for the restart")


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
	var span_gate := _gate_on(controller, str(_edge_for(SPAN)
			.get("edge_id", "")))
	var cell_gate := _gate_on(controller, str(_edge_for(VARIABLE)
			.get("edge_id", "")))
	var socket := _socket(controller)
	var shutters := _route_shutters(controller)
	_check(span_gate != null and span_gate.shutter.is_open()
			and _lever(controller).status != "PENDING",
			"the lever's doorway is open the moment the Zone exists")
	_check(cell_gate != null and cell_gate.shutter.is_open()
			and socket != null and socket.installed_object == CELL
			and _copies(CELL) == 1,
			"the cell is seated, one copy, and its doorway open at load")
	_check(shutters.size() == 1 and (shutters[0] as ServiceShutter).is_shut(),
			"P14's branch is still shut: restored as it was left")
	await _settle(30)
	_check(_intents("zone_state_selected").is_empty()
			and _intents("object_consumed").is_empty()
			and _intents("object_transported").is_empty(),
			"and nothing was announced: the restore reported nothing back")
