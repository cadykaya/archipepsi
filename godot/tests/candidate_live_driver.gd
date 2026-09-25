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
##   minor    (O05-06) both minors the profile added, each behind its
##            own dead end, played by hand. EX50-033: the drive pulled,
##            the crate on the plate and the crossing SHUT (the panel in
##            it, the player on the crate stopped), the applicator SHOT,
##            through, the bolt pulled (ACCEPTED as `minor_<room>/bolt`),
##            the Check claimed. EX50-021: the Zone's own gunner baited
##            from the stance, the shot dodged into the alcove, the
##            receiver tripped by the enemy's projectile, the shutter run
##            inside its interval, the release pulled (ACCEPTED as
##            `minor_<room>/release`), the Check claimed.
##   minor_restore  both processes new, each minor as it was left before
##            anyone acts: EX50-033's bolt holds against the plate;
##            EX50-021's release holds the shutter open past its
##            interval; every Check still claimed.
##   next     (O05-06.2) the campaign's SECOND Zone, by the ordinary
##            lifecycle: zone_001 re-entered and abandoned from the pause
##            menu, the portal designs zone_002, whose offer order hosts
##            EX50-011. Its §9 death rule (a death before completion
##            sends the carriers home, by motion), then the patient
##            route's first half: H called and STOPPED at the
##            rendezvous, its held rest ACCEPTED, the Zone left.
##   next_restore  both processes new: the shuttle HELD exactly where it
##            was saved before the player arrives, and it does not move;
##            then the route finished from it -- the lift launched, the
##            step across during its dwell, H restarted from its own
##            deck, G reached, the stair ACCEPTED, the Check claimed.
##   next_final  both processes new: the stair stands, each carrier at
##            its last rest, the Check claimed, and the stair walked from
##            A up to G with both carriers elsewhere.
##
## **HARNESS STEPS, declared:** the same as the suites this reuses -- a
## shielded Bulwark removed through the damage path from behind when the
## base-kit flank does not land (P5-7, printed as a NOTE). And in the two
## minor phases only, the player is PLACED at the arrival of the dead end
## the minor stands behind: the walk there crosses P14's plate and two
## locked doors, which their own suites play. From that arrival on,
## everything is the player's own input. In `next`, the player is killed
## once through the damage path, to exercise EX50-011 §9's death rule.

const PHASE_FLAG := "--candidate-live="
const SAVE_DIR_FLAG := "--candidate-save-dir="
## Development only: play just the minor built from this shell id.
const ONLY_FLAG := "--candidate-minor="
const ZONE_ID := "zone_001"
## The campaign's second Zone, reached by abandoning the first: its offer
## order turns once (`minor_hosting.offer_order`) and hosts EX50-011.
const NEXT_ZONE_ID := "zone_002"
const CANDIDATE_FIXTURE := "res://tests/fixtures/candidate_zone.json"
const PROFILE := ["zone_state", "transport", "latched_route", "minors"]

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
			"minor":
				await _minor()
			"minor_restore":
				await _minor_restore()
			"next":
				await _next()
			"next_restore":
				await _next_restore()
			"next_final":
				await _next_final()
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
	await _leave_zone(ZONE_ID)


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


## Route actuators the Zone declares: the shutters its room graphs drive.
func _declared_route_actuators(zone: Dictionary) -> int:
	var count := 0
	for raw: Variant in zone.get("room_graphs", []) as Array:
		count += ((raw as Dictionary).get("actuators", []) as Array).size()
	return count


## Route sensors the Zone declares, and how many of them are levers
## (`PULSE_BUTTON`, D13 1c).
func _declared_route_sensors(zone: Dictionary, kind := "") -> int:
	var count := 0
	for raw: Variant in zone.get("room_graphs", []) as Array:
		for sensor: Variant in (raw as Dictionary).get("sensors", []) as Array:
			if kind == "" or str((sensor as Dictionary).get("kind", "")) == kind:
				count += 1
	return count


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


## The route graphs' sensors: since D13 1c, the lever route's bolt.
func _route_controls(controller: ZoneController) -> Array:
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
	# AS MANY AS THE ZONE DECLARES: the lever, the cell and, since D13 1c,
	# the lever route in c009 again (Dess's D-1, D-7).
	var declared := (zone.get("zone_state", []) as Array).size() \
			+ _declared_route_actuators(zone)
	_check(gated.size() == declared and declared >= 2,
			"one doorway per declared relationship: %d declared, gated %s"
			% [declared, gated])
	# AND WHAT EACH STEP DID, as the bridge recorded it.
	var record_path := _arg(SAVE_DIR_FLAG).path_join("candidate") \
			.path_join("%s.json" % ZONE_ID)
	var record: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(record_path))
	var steps: Array = (record as Dictionary).get("steps", []) \
			if typeof(record) == TYPE_DICTIONARY else []
	# EVERY STEP EMITTED. The latch step's D-07 policy decline ended with
	# the lever (D13 1c, Dess's D-7), so a decline of any step is now a
	# partial profile and fails here.
	_check(typeof(record) == TYPE_DICTIONARY
			and (record as Dictionary).get("profile") == PROFILE
			and steps.size() == PROFILE.size()
			and steps.all(func(s: Variant) -> bool:
				return bool((s as Dictionary).get("emitted", false))),
			"the bridge recorded all %d steps, " % PROFILE.size()
			+ "each EMITTED: %s in %s"
			% [steps.map(func(x: Variant) -> String:
				return "%s=%s" % [(x as Dictionary).get("step", "?"),
					"EMITTED" if bool((x as Dictionary).get("emitted", false))
					else "declined"]), record_path])
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
	var routes := _declared_route_actuators(_zone_data)
	_check(span_gate != null and cell_gate != null and lever != null
			and socket != null and controller.objects.body_of(CELL) != null
			and shutters.size() == routes,
			"built: the lever, its gate, the cell, its socket and gate, and "
			+ "every route shutter the Zone declares (%d built, %d declared)"
			% [shutters.size(), routes])
	if span_gate == null or cell_gate == null or lever == null \
			or socket == null or shutters.size() != routes:
		return
	_check(span_gate.shutter.is_shut() and cell_gate.shutter.is_shut()
			and shutters.all(func(sh: Variant) -> bool:
				return (sh as ServiceShutter).is_shut()),
			"every gated doorway starts shut (%d)" % (2 + routes))
	var nearest := INF
	for control: Variant in _route_controls(controller):
		nearest = minf(nearest, (control as Node3D).global_position
				.distance_to(lever.global_position))
	_check(nearest > 1.5,
			"the span lever does not stand on the route's own control "
			+ "(%.1f m apart)" % nearest)
	# D-07 in the owner's candidate: the route is pulled, never stepped on.
	var controls := _route_controls(controller)
	var levers := controls.filter(func(c: Variant) -> bool:
		return c is CallLever)
	_check(controls.size() == _declared_route_sensors(_zone_data)
			and levers.size() == _declared_route_sensors(_zone_data,
				"PULSE_BUTTON") and not levers.is_empty(),
			"every declared route lever is built as a lever you pull "
			+ "(%d of %d route controls; %d declared)"
			% [levers.size(), controls.size(),
				_declared_route_sensors(_zone_data)])

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
	_check(shutters.all(func(sh: Variant) -> bool:
				return (sh as ServiceShutter).is_shut()),
			"and any route branch is still shut: nothing here latched it "
			+ "(%d)" % shutters.size())
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
	_check(shutters.size() == _declared_route_actuators(_zone_data)
			and shutters.all(func(sh: Variant) -> bool:
				return (sh as ServiceShutter).is_shut()),
			"every route branch is still shut: restored as it was left (%d)"
			% shutters.size())
	await _settle(30)
	_check(_intents("zone_state_selected").is_empty()
			and _intents("object_consumed").is_empty()
			and _intents("object_transported").is_empty(),
			"and nothing was announced: the restore reported nothing back")


# ---------------------------------------------------------------------------
# O05-06.4 -- EX50-033, the minor the profile added, played by hand
# ---------------------------------------------------------------------------

## The minors this Zone hosts, as the controller found them in their
## rooms: one per contracted minor the profile built.
func _the_minors(controller: ZoneController) -> Array:
	var ids: Array = controller.minors.map(
			func(m: Dictionary) -> String: return str(m["room_id"]))
	var kinds: Array = controller.minors.map(
			func(m: Dictionary) -> String: return str((m["hosted"] as Node).name))
	_check(ids.size() == 2, "the Zone hosts both minors, each found in its "
			+ "own room by the controller: %s %s" % [ids, kinds])
	return controller.minors


## The dead end a minor was built behind: the far room of its way in.
func _parent_of(room_id: String) -> String:
	var arrive := str(_chamber(room_id).get("arrive_edge", ""))
	for raw: Variant in _zone_data.get("edges", []) as Array:
		var edge: Dictionary = raw
		if str(edge.get("edge_id", "")) == arrive:
			return str(edge["room_a"]) if str(edge["room_b"]) == room_id \
					else str(edge["room_b"])
	return ""


## The Check pedestal standing in a room, found by where it stands.
func _reward_in(controller: ZoneController, room_id: String) -> RewardObject:
	var box: AABB = controller.room_bounds.get(room_id, AABB())
	for node: Node in controller.find_children("*", "", true, false):
		var reward := node as RewardObject
		if reward != null and box.has_point(reward.global_position):
			return reward
	return null


## HARNESS STEP, declared at the top: the player stands at a room's
## arrival. Everything after it is the player's own input.
func _place_at(controller: ZoneController, room_id: String) -> void:
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			room_id).get("arrival", Vector3.INF)
	controller.player.global_position = arrival + Vector3(0.0, 0.2, 0.0)
	controller.player.velocity = Vector3.ZERO
	await _settle(20)
	_note("HARNESS STEP: placed at %s's arrival %v" % [room_id, arrival])


## A lever worked by hand: walked up to, looked at, [E].
func _operate(controller: ZoneController, lever: CallLever) -> bool:
	var top := lever.global_position + Vector3(0.0, CallLever.BASE.y, 0.0)
	var before := lever.pulls
	if not await _approach(controller, lever, 1.3, top):
		return false
	await _press("interact")
	await _settle(4)
	return lever.pulls > before


## The Static Pulse, aimed and fired at `target`; how often it triggered.
func _shoot_at(controller: ZoneController, target: ActivityElement) -> int:
	var hits: Array[int] = [0]
	var count := func(_w: ActivityElement) -> void: hits[0] += 1
	target.triggered.connect(count)
	var player := controller.player
	for _attempt in 3:
		for _i in 20:
			_look_at(player, target.global_position)
			await get_tree().physics_frame
		await _press("fire_pulse")
		await _settle(30)
		if hits[0] > 0:
			break
	target.triggered.disconnect(count)
	return hits[0]


## Straight at `goal`, hopping when the body stalls against a lip -- the
## walker `godot-unweighted` climbs this same crate with.
func _hop_walk(player: Player, goal: Vector3, within: float,
		frames := 480) -> bool:
	var arrived := false
	var still := 0
	var last := player.global_position
	player.camera.rotation.x = 0.0
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		var here := player.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		player.rotation.y = atan2(-flat.x, -flat.y)
		if (here - last).length() < 0.012:
			still += 1
			if still == 14 and player.is_on_floor():
				Input.action_press("jump", 1.0)
				await get_tree().physics_frame
				Input.action_release("jump")
				still = 0
		else:
			still = 0
		last = here
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	return arrived


## Into the minor from the dead end it stands behind: placed at that
## room's arrival (declared), then walked into the minor through the
## doorway the profile added.
##
## `clear` fights the parent room first with the base kit. EX50-033's
## parent is cleared; EX50-021's is walked past, because its two ranged
## enemies stand on an elevation band the scripted fighter cannot reach
## (measured: three deaths, none of them landing a hit) -- that fight is
## the parent's, not the minor's. A DEATH IS NOT THE END OF IT: the player
## respawns at the Zone's start, is placed again and carries on, as
## `_advance_to` does. Asserted once, on the outcome.
func _into_the_minor(controller: ZoneController, rid: String,
		clear := true) -> bool:
	var player := controller.player
	var parent := _parent_of(rid)
	_check(parent != "", "the minor %s stands behind %s" % [rid, parent])
	if parent == "":
		return false
	var deaths_before := _deaths
	var inside := false
	var walked := 0.0
	for attempt in 3:
		await _place_at(controller, parent)
		if clear:
			await _clear_shielded(controller, parent)
			await _clear_room(controller, parent)
			if not player._dead:
				await _climb_out(controller, parent)
		if not player._dead:
			var into := await _walk_into(controller, rid)
			inside = bool(into["inside"])
			walked = float(into["walked"])
		if inside or not player._dead:
			break
		_note("the player died on the way into %s (attempt %d); respawned "
				% [rid, attempt + 1] + "and placed again")
		await _wait_for(func() -> bool: return not player._dead,
				int((Constants.RESPAWN_DELAY + 1.0) / DT))
		await _settle(10)
	if clear:
		var left := _living_in(controller, parent).size()
		_check(left == 0, "%s cleared with the base kit (%d left)"
				% [parent, left])
	_check(inside, "walked from %s into the minor %s through the doorway "
			% [parent, rid] + "the profile added (%.1f m, %d death(s))"
			% [walked, _deaths - deaths_before])
	return inside


func _minor() -> void:
	if not await _campaign():
		return
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var only := _arg(ONLY_FLAG)
	var played := 0
	for raw: Variant in _the_minors(controller):
		var minor: Dictionary = raw
		if only != "" and str(_chamber(str(minor["room_id"])).get(
				"shell_id", "")) != only:
			continue
		played += 1
		if minor["hosted"] is UnweightedSwitchHosted:
			await _play_unweighted(controller, minor)
		elif minor["hosted"] is CounterfireArcadeHosted:
			await _play_counterfire(controller, minor)
	await _settle(30)
	_check(_intents("claim_check").size() == played,
			"each Check claimed exactly once (%d claim intent(s) for %d "
			% [_intents("claim_check").size(), played] + "minor(s))")
	await _leave()


func _play_unweighted(controller: ZoneController, minor: Dictionary) -> void:
	var player := controller.player
	var rid := str(minor["room_id"])
	var room: UnweightedSwitchRoom = \
			(minor["hosted"] as UnweightedSwitchHosted).room
	_check(str(_chamber(rid).get("shell_id", "")) == \
			UnweightedSwitchHosted.SHELL_ID,
			"%s is built from the minor's own shell" % rid)
	_check(not room.bolted and not room.crate_is_placed()
			and room.return_stair_steps() == 0 and room.goal_plate == null,
			"as built: bolt free, crate parked, no return stair, and no "
			+ "stand-in goal -- the goal is the Zone's Check")
	var reward := _reward_in(controller, rid)
	var floor_y := room.global_position.y
	_check(reward != null and reward.global_position.y
			> floor_y + UnweightedSwitchRoom.SILL_Y - 0.3,
			"its Check stands on the gallery, %.2f m above the floor"
			% ((reward.global_position.y - floor_y) if reward != null
				else -1.0))
	if reward == null or not await _into_the_minor(controller, rid):
		return

	# ---- the drive, by hand: the step placed, the crossing shut ---------
	var drove := await _operate(controller, room.drive)
	var placed := await _wait_for(func() -> bool:
		return room.crate_is_placed(), 900)
	var shut := await _wait_for(func() -> bool:
		return room.shutter.is_shut(), 400)
	_check(drove and placed and shut,
			"the SERVICE DRIVE pulled by hand; the crate is on the HEAVY "
			+ "plate and the crossing has SHUT")
	# SHUT IS A PLACE, NOT A NUMBER (P5-15). The state read shut while the
	# panel stood near the world origin; this asks where the panel is.
	var crossing := room.to_global(room.shutter.shut_at)
	_check(room.shutter.global_position.distance_to(crossing) < 0.05,
			"the shut panel stands IN the crossing (%.2f m off it)"
			% room.shutter.global_position.distance_to(crossing))

	# ---- the step is placed, and the route it was for is closed ---------
	await _hop_walk(player, room.to_global(Vector3(0.0, 0.0,
			UnweightedSwitchRoom.RECESS_Z)), 1.4)
	# LANDED, not sampled mid-hop: the walker's stall-hop can leave the
	# body in the air at the moment the walk ends.
	await _settle(24)
	await _wait_for(func() -> bool: return player.is_on_floor(), 120)
	await _settle(6)
	_check(player.is_on_floor() and absf(player.global_position.y - floor_y
			- UnweightedSwitchRoom.CRATE.y) < 0.25,
			"STANDING on the crate top, feet %.2f m above the floor"
			% (player.global_position.y - floor_y))
	await _hop_walk(player, room.to_global(Vector3(0.0, 0.0,
			UnweightedSwitchRoom.NORTH_Z + 1.6)), 1.6, 150)
	_check(room.to_local(player.global_position).z
			< UnweightedSwitchRoom.NORTH_Z,
			"...and walking at the doorway from the crate gets nowhere: "
			+ "%.2f m short of the crossing" % (UnweightedSwitchRoom.NORTH_Z
				- room.to_local(player.global_position).z))

	# ---- the applicator, SHOT from the crate: the class moves -----------
	var hits := await _shoot_at(controller, room.applicator)
	_check(hits > 0 and room.crate.statuses != null
			and room.crate.statuses.has("lightened"),
			"the applicator was shot with the Static Pulse (%d trigger(s)) "
			% hits + "and the crate carries LIGHTENED")
	var opened := await _wait_for(func() -> bool:
		return room.shutter.is_open(), 400)
	_check(opened and room.crate_is_placed(),
			"the crossing OPENED with the crate still on the plate")

	# ---- through, then the bolt ---------------------------------------
	await _hop_walk(player, room.to_global(Vector3(0.0, 0.0,
			UnweightedSwitchRoom.NORTH_Z + 1.6)), 1.6)
	_check(room.to_local(player.global_position).z
			> UnweightedSwitchRoom.NORTH_Z
			and player.global_position.y - floor_y
				> UnweightedSwitchRoom.SILL_Y - 0.3,
			"through the doorway onto the gallery")
	var bolted := await _operate(controller, room.bolt)
	var ref := "%s/bolt" % MinorRooms.package_of(rid)
	var recorded := await _await_live("the bridge to record the bolt",
			func() -> bool: return _served().get("latched", []).has(ref),
			10.0)
	_check(bolted and room.bolted and recorded,
			"the HOLD-OPEN BOLT pulled and ACCEPTED: '%s' is in the save"
			% ref)

	# ---- the Check, claimed once -----------------------------------------
	var seen := await _approach(controller, reward, 1.2)
	_check(seen and reward.interact_prompt().begins_with("[E] CLAIM"),
			"at the Check: \"%s\"" % reward.interact_prompt())
	await _press("interact")
	var claimed := await _await_live("the Check to be confirmed",
			func() -> bool: return BridgeClient.is_checked(
					reward.location_id), 15.0)
	_check(claimed, "the minor's Check %d is CONFIRMED" % reward.location_id)
	print("played: EX50-033 in %s -- bolt %s, Check %d claimed"
			% [rid, ref, reward.location_id])


func _minor_restore() -> void:
	if not await _campaign():
		return
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) == ZONE_ID,
			"RESTART: the new bridge loaded the save; the Hub offers '%s'"
			% str(BridgeClient.hub().get("resume_zone_id", "")))
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	for raw: Variant in _the_minors(controller):
		var minor: Dictionary = raw
		if minor["hosted"] is UnweightedSwitchHosted:
			await _restored_unweighted(controller, minor)
		elif minor["hosted"] is CounterfireArcadeHosted:
			await _restored_counterfire(controller, minor)
	await _settle(30)
	_check(_intents("latch_fired").is_empty()
			and _intents("claim_check").is_empty(),
			"and nothing was announced: no latch and no claim sent back")


func _restored_unweighted(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room: UnweightedSwitchRoom = \
			(minor["hosted"] as UnweightedSwitchHosted).room
	_check(room.bolted and room.shutter.is_open()
			and room.return_stair_steps() > 0,
			"RESTORED before anyone acts: the bolt holds, the crossing is "
			+ "open and the return stair stands (%d steps)"
			% room.return_stair_steps())
	_check(not room.crate_is_placed() and not (room.crate.statuses != null
			and room.crate.statuses.has("lightened")),
			"the crate is parked and LIGHTENED is gone: package-local and "
			+ "ephemeral, never saved")
	var raised := room.to_global(room.shutter.shut_at
			+ Vector3(0.0, room.shutter.travel, 0.0))
	_check(room.shutter.global_position.distance_to(raised) < 0.05,
			"and the panel is physically raised clear of the crossing "
			+ "(%.2f m off)" % room.shutter.global_position.distance_to(raised))
	var reward := _reward_in(controller, rid)
	_check(reward != null and BridgeClient.is_checked(reward.location_id)
			and reward.interact_prompt() == "",
			"the Check stays claimed: nothing to claim twice")
	if not await _into_the_minor(controller, rid):
		return
	var drove := await _operate(controller, room.drive)
	var placed := await _wait_for(func() -> bool:
		return room.crate_is_placed(), 900)
	await _settle(60)
	_check(drove and placed and room.shutter.is_open(),
			"the crate driven back onto the HEAVY plate, and the crossing "
			+ "STAYS OPEN: the restored bolt holds it")
	print("played: the restored bolt holds %s's crossing" % rid)




# ---------------------------------------------------------------------------
# O05-06.3 -- EX50-021 Counterfire Arcade, played by hand in the Zone
# ---------------------------------------------------------------------------

## The gunner's own shot, or null: an enemy projectile inside the room
## and heading south down its lane. `EnemyProjectile` adds itself to the
## current scene, so this looks there -- and it has to choose, because in
## a Zone the room next door has ranged enemies too, and the first run
## picked up one of theirs coming the other way through the doorway.
func _shot_in_flight(room: CounterfireArcadeRoom) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for child: Node in scene.get_children():
		var area := child as Area3D
		if area == null or area.get("speed") == null \
				or area.get("direction") == null:
			continue
		var at := room.to_local(area.global_position)
		var heading: Vector3 = room.global_transform.basis.inverse() \
				* (area.get("direction") as Vector3)
		if absf(at.x) <= CounterfireArcadeRoom.ROOM_HALF.x \
				and absf(at.z) <= CounterfireArcadeRoom.ROOM_HALF.y \
				and heading.z < 0.0:
			return area
	return null


func _play_counterfire(controller: ZoneController,
		minor: Dictionary) -> void:
	var player := controller.player
	var rid := str(minor["room_id"])
	var room: CounterfireArcadeRoom = \
			(minor["hosted"] as CounterfireArcadeHosted).room
	var floor_y := room.global_position.y
	_check(str(_chamber(rid).get("shell_id", "")) == \
			CounterfireArcadeHosted.SHELL_ID,
			"%s is built from EX50-021's own shell" % rid)
	_check(not room.released and room.shutter.is_shut()
			and room.release_stair_steps() == 0 and room.goal_plate == null
			and room.gunner == null,
			"as built: shutter shut, nothing released, no stair, no "
			+ "stand-in goal, and no gunner of the room's own")
	# THE GUNNER IS THE ZONE'S (EX50-021 §9): the chamber's declared
	# enemy, spawned on the gallery post and tracked with the room.
	var gunners := _living_in(controller, rid)
	var post := room.to_global(CounterfireArcadeRoom.GUNNER)
	_check(gunners.size() == 1
			and (gunners[0] as Enemy).archetype == "ranged"
			and (gunners[0] as Node3D).global_position.distance_to(post)
				< 0.5,
			"the gunner is the Zone's own ranged enemy, on the gallery "
			+ "post (%d in the room)" % gunners.size())
	var reward := _reward_in(controller, rid)
	_check(reward != null and absf(reward.global_position.y - floor_y
			- CounterfireArcadeRoom.FLANK_Y) < 0.5,
			"its Check stands on the flank, %.2f m above the floor"
			% ((reward.global_position.y - floor_y) if reward != null
				else -1.0))
	if reward == null or gunners.size() != 1:
		return
	# Placed at the parent's arrival (declared); the parent is cleared,
	# and the minor is walked into. Its gunner is NOT cleared: it is the
	# thing this room is played against.
	if not await _into_the_minor(controller, rid, false):
		return

	# ---- the bait: into the lane at the stance, facing the gunner -------
	var stance := room.to_global(CounterfireArcadeRoom.STANCE)
	await _hop_walk(player, room.to_global(Vector3(3.6, 0.0,
			CounterfireArcadeRoom.STANCE.z)), 0.8)
	await _hop_walk(player, stance, 0.5)
	var gunner := gunners[0] as Enemy
	var shot: Node3D = null
	for _i in 900:
		_look_at(player, gunner.global_position + Vector3.UP * 1.2)
		await get_tree().physics_frame
		shot = _shot_in_flight(room)
		if shot != null:
			break
	_check(shot != null, "standing in the lane, the Zone's gunner "
			+ "COMMITTED a shot at the player (nothing was pressed)")
	if shot == null:
		return
	# ---- the dodge: into the alcove, started on seeing the shot ---------
	await _hop_walk(player, room.to_global(CounterfireArcadeRoom.ALCOVE),
			0.4, 120)
	for _i in 240:
		await get_tree().physics_frame
		if room.receiver.hits > 0:
			break
	_check(room.receiver.hits > 0,
			"the enemy's own projectile carried on down the lane and "
			+ "TRIPPED the receiver (%d hit(s))" % room.receiver.hits)
	var opening := await _wait_for(func() -> bool:
		return not room.shutter.is_shut(), 120)
	_check(opening, "and the service shutter is opening")

	# ---- the timed passage: through, up, the release --------------------
	var through := await _hop_walk(player, room.to_global(Vector3(
			CounterfireArcadeRoom.ROOM_HALF.x + 1.4, 0.0,
			CounterfireArcadeRoom.SHUTTER_Z)), 1.0, 400)
	_check(through and room.to_local(player.global_position).x
			> CounterfireArcadeRoom.ROOM_HALF.x,
			"through the shutter inside its interval (%.1f s left)"
			% room.window_left())
	await _hop_walk(player, room.to_global(Vector3(16.2,
			CounterfireArcadeRoom.FLANK_Y, -2.0)), 1.1, 500)
	await _settle(10)
	_check(absf(player.global_position.y - floor_y
			- CounterfireArcadeRoom.FLANK_Y) < 1.0,
			"up the supported route onto the flank, %.2f m above the floor"
			% (player.global_position.y - floor_y))
	var pulled := await _operate(controller, room.release)
	var ref := "%s/release" % MinorRooms.package_of(rid)
	var recorded := await _await_live("the bridge to record the release",
			func() -> bool: return _served().get("latched", []).has(ref),
			10.0)
	_check(pulled and room.released and recorded,
			"the SERVICE RELEASE pulled and ACCEPTED: '%s' is in the save"
			% ref)

	# ---- the Check -------------------------------------------------------
	var seen := await _approach(controller, reward, 1.2)
	_check(seen and reward.interact_prompt().begins_with("[E] CLAIM"),
			"at the Check: \"%s\"" % reward.interact_prompt())
	await _press("interact")
	var claimed := await _await_live("the Check to be confirmed",
			func() -> bool: return BridgeClient.is_checked(
					reward.location_id), 15.0)
	_check(claimed, "the minor's Check %d is CONFIRMED" % reward.location_id)
	print("played: EX50-021 in %s -- the Zone's gunner baited, release %s, "
			% [rid, ref] + "Check %d claimed" % reward.location_id)


func _restored_counterfire(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room: CounterfireArcadeRoom = \
			(minor["hosted"] as CounterfireArcadeHosted).room
	_check(room.released and room.shutter.is_open()
			and room.release_stair_steps() > 0,
			"RESTORED before anyone acts: released, the shutter open and "
			+ "its fixed stair standing (%d steps)"
			% room.release_stair_steps())
	var raised := room.to_global(room.shutter.shut_at
			+ Vector3(0.0, room.shutter.travel, 0.0))
	_check(room.shutter.global_position.distance_to(raised) < 0.05,
			"and the panel is physically raised clear of its doorway "
			+ "(%.2f m off)" % room.shutter.global_position.distance_to(
				raised))
	# D-07's permanence across a real restart: the release comes back
	# thrown and saying so, not waiting to be pulled again (H-COUNTERFIRE).
	_check(room.release.locked
			and not room.release.interact_prompt().begins_with("[E]"),
			"and the release is restored THROWN: '%s'"
			% room.release.interact_prompt())
	var reward := _reward_in(controller, rid)
	_check(reward != null and BridgeClient.is_checked(reward.location_id)
			and reward.interact_prompt() == "",
			"the Check stays claimed: nothing to claim twice")
	# NOT A TIMER: past two of its intervals, nothing shot, still open.
	await _settle(int(CounterfireArcadeRoom.OPEN_SECONDS * 2.5 / DT))
	_check(room.shutter.is_open(), "and %.0f s later -- two and a half "
			% (CounterfireArcadeRoom.OPEN_SECONDS * 2.5)
			+ "intervals -- the restored release still holds it open")
	print("played: the restored release holds %s's shutter" % rid)


# ---------------------------------------------------------------------------
# O05-06.2 -- EX50-011 Passing Platforms, in the campaign's second Zone
# ---------------------------------------------------------------------------

## The Passing Platforms minor a Zone hosts, or {}.
func _platforms_in(controller: ZoneController) -> Dictionary:
	for raw: Variant in controller.minors:
		if (raw as Dictionary)["hosted"] is PassingPlatformsHosted:
			return raw
	return {}


## The yaw that faces the room's +z: from the lift toward the shuttle.
static func _north_yaw(room: PassingPlatformsRoom) -> float:
	var north := room.global_transform.basis.z
	return atan2(-north.x, -north.z)


## Where the shuttle's deck is centred, in the room's frame.
static func _shuttle_x(room: PassingPlatformsRoom) -> float:
	var span := room.h_span()
	return (span.x + span.y) * 0.5


## The last rest this controller reported for a carrier: `[package,
## carrier, t, destination, held]`, or [].
static func _last_rest(controller: ZoneController, carrier_id: String) -> Array:
	for i in range(controller.carrier_reports.size() - 1, -1, -1):
		var row: Array = controller.carrier_reports[i]
		if str(row[1]) == carrier_id:
			return row
	return []


## The rest the bridge accepted for `ref`, off the served progress:
## `[t, destination, held]`, or [].
func _saved_rest(ref: String) -> Array:
	var row := _row(_served().get("carrier_states", []), ref)
	return [float(row[1]), str(row[2]), bool(row[3])] if row.size() == 4 \
			else []


## Look at a lever within reach and hold [E] until it counts the pull --
## the scenario suite's `_pull`, for a lever the player is already
## standing at (on a deck, where walking to a stand-off could walk off).
func _pull_here(player: Player, lever: CallLever) -> bool:
	var before := lever.pulls
	var top := lever.global_position + Vector3(0.0, CallLever.BASE.y, 0.0)
	for _i in 20:
		_look_at(player, top)
		await get_tree().physics_frame
		if player._interact_target == lever:
			break
	Input.action_press("interact", 1.0)
	for _i in 12:
		_look_at(player, top)
		await get_tree().physics_frame
		if lever.pulls > before:
			break
	Input.action_release("interact")
	await get_tree().physics_frame
	return lever.pulls > before


## Face `yaw` and hold forward for `frames`: the step across.
func _step_toward(player: Player, yaw: float, frames: int) -> void:
	player.rotation.y = yaw
	player.camera.rotation.x = 0.0
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame


## Is the body's feet on `machine`? Read from what is under the feet --
## `godot-passing-platforms`' test, unchanged.
func _standing_on(body: Player, machine: Node3D) -> bool:
	if not body.is_on_floor():
		return false
	for i in body.get_slide_collision_count():
		var hit := body.get_slide_collision(i).get_collider()
		if hit == machine or (hit is Node and (hit as Node).get_parent() \
				== machine):
			return true
	var space := body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(body.global_position,
			body.global_position - Vector3(0.0, 2.0, 0.0))
	query.exclude = [body.get_rid()]
	var ray := space.intersect_ray(query)
	if ray.is_empty():
		return false
	var under: Variant = ray["collider"]
	return under == machine or (under is Node
			and (under as Node).get_parent() == machine)


## The in-Zone pause menu, as a player works it: Escape opens the pause
## interface (H-3D-SHELL) on its Settings wall, which is the pause menu;
## Tab turns it to Equipment, where the inventory is, and E back; then
## ABANDON ZONE..., then CONFIRM ABANDON -- each the menu's own button,
## pressed -- and the interface closes behind the abandon.
func _abandon_from_the_pause_menu(zone_id: String) -> bool:
	var shell: MenuShell = main.menu_shell
	var menu: PauseMenu = main.pause_menu
	var player: Player = main.zone.player if main.zone != null else null
	await _action_event("pause")
	_check(shell.is_open() and shell.front() == "settings" and menu.visible
			and menu.get_viewport() == shell.page_viewport("settings")
			and player != null and player.held_by("modal"),
			"Escape opens the pause interface on its Settings wall, the "
			+ "pause menu drawn there, and the player is held")
	_check(get_tree().paused and PauseClaims.owners() == ["menu"]
			and BridgeClient.online,
			"and the world is paused behind it, by the menu's claim alone, "
			+ "with the bridge still connected (H-PAUSE)")
	await _action_event("inventory")
	await _shell_at_rest(shell)
	_check(shell.front() == "equipment" and main.inventory.visible
			and main.inventory.get_viewport()
				== shell.page_viewport("equipment"),
			"Tab turns it to the Equipment wall, the inventory drawn there")
	await _equip_while_paused()
	await _action_event("menu_page_right")
	await _shell_at_rest(shell)
	var armed := shell.front() == "settings" \
			and _press_button(menu, "ABANDON ZONE")
	await get_tree().process_frame
	var confirmed := armed and _press_button(menu, "CONFIRM ABANDON")
	_check(armed and confirmed, "the pause menu's ABANDON ZONE, then "
			+ "CONFIRM ABANDON, pressed")
	if not confirmed:
		return false
	await get_tree().process_frame
	_check(not shell.is_open() and not get_tree().paused
			and (player == null or not is_instance_valid(player)
				or not player.held_by("modal")),
			"and the pause interface closes behind the abandon: the world "
			+ "runs again and the player is released")
	var offering := func() -> bool:
		return BridgeClient.hub_mode() == "ZONE_AVAILABLE" and main.hub != null
	return await _await_live("%s abandoned, the Hub offering a new Zone"
			% zone_id, offering, 30.0)


## ONE REAL EQUIP, WITH THE WORLD PAUSED (CP3: "one real equip/refusal";
## H-PAUSE: the AP world is not paused). The Equipment wall's own button is
## pressed; the bridge's answer arrives while the world stands still, and
## the wall is repainted from it. HARNESS STEP, declared: the loadout is
## then put back as it was, by the same intent, so the phases after this
## one play the loadout they always did.
func _equip_while_paused() -> void:
	var before: Dictionary = BridgeClient.slots().duplicate()
	var equip := _first_button(main.inventory, ["REPLACE ", "TO "])
	if equip == null:
		_note("no Echo on the Equipment wall to equip; the paused equip is "
				+ "not exercised in this campaign")
		return
	var label := equip.text
	equip.pressed.emit()
	var changed := func() -> bool: return BridgeClient.slots() != before
	var answered := await _await_live("the equip's answer, the world paused",
			changed, 10.0)
	var diff: Array = []
	for slot: Variant in BridgeClient.slots().keys():
		if BridgeClient.slots().get(slot) != before.get(slot):
			diff.append("%s: %s -> %s" % [slot, before.get(slot),
					BridgeClient.slots().get(slot)])
	await get_tree().process_frame
	_check(answered and get_tree().paused
			and (not is_instance_valid(equip) or equip.is_queued_for_deletion()),
			"'%s' pressed on the Equipment wall with the world paused: the "
			% label + "bridge answered (%s), the world is still paused, and "
			% [diff] + "the wall was repainted from the answer")
	for slot: Variant in before.keys():
		if BridgeClient.slots().get(slot) != before.get(slot):
			BridgeClient.send_intent({"type": "slot_action", "slot": slot,
					"component_id": before.get(slot)})
	await _await_live("the loadout put back",
			func() -> bool: return BridgeClient.slots() == before, 10.0)


func _first_button(root: Node, prefixes: Array) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.disabled \
				or button.is_queued_for_deletion():
			continue
		for prefix: String in prefixes:
			if button.text.begins_with(prefix):
				return button
	return null


## An action as a device delivers it: an event through the engine's input
## pipeline, so `_input` and `_unhandled_input` see it. (`Input.action_press`
## only sets what polling reads.)
func _action_event(action: String) -> void:
	for down: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func _shell_at_rest(shell: MenuShell) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while shell.is_turning() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame


func _press_button(root: Node, prefix: String) -> bool:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and not button.is_queued_for_deletion() \
				and button.text.begins_with(prefix):
			button.pressed.emit()
			return true
	return false


## The portal, worked in ZONE_AVAILABLE: it designs the next Zone.
func _request_next_zone() -> bool:
	var offered := func() -> bool:
		var standing := main.hub as HubController
		return standing != null and standing.portal() != null \
				and standing.portal().interact_prompt() != ""
	if not await _await_live("the Hub's portal", offered, 30.0):
		return false
	(main.hub as HubController).portal().interact(main)
	var designed := func() -> bool:
		return BridgeClient.hub_mode() == "ZONE_READY"
	return await _await_live("the next Zone designed", designed, 150.0)


func _leave_zone(zone_id: String) -> void:
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": zone_id})
	await _await_live("the Zone goes dormant",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			20.0)


func _next() -> void:
	if not await _campaign():
		return
	BridgeClient.sent_intents.clear()
	var first := await _through_the_portal()
	if first == null:
		return
	_check(str(_zone_data.get("zone_id", "")) == ZONE_ID,
			"back in %s, the Zone the campaign holds" % ZONE_ID)
	if not await _abandon_from_the_pause_menu(ZONE_ID):
		return
	_check(_intents("abandon_zone").size() == 1,
			"abandoned by the ordinary lifecycle: one 'abandon_zone', and "
			+ "the Hub offers a new Zone")
	if not await _request_next_zone():
		return
	var controller := await _through_the_portal()
	if controller == null:
		return
	_check(str(_zone_data.get("zone_id", "")) == NEXT_ZONE_ID,
			"the portal designed and opened %s" % NEXT_ZONE_ID)
	# OPT-IN CAPTURE (`--candidate-dump-zone=<path>`): the Zone exactly as
	# the bridge served it, for developing against locally while no
	# fixture carries EX50-011 (note N-10). Never a fixture itself.
	var dump := _arg("--candidate-dump-zone=")
	if dump != "":
		var out := FileAccess.open(dump, FileAccess.WRITE)
		if out != null:
			out.store_string(JSON.stringify(_zone_data, " "))
			out.close()
			_note("captured %s as served to %s" % [NEXT_ZONE_ID, dump])
	# WHAT THE STEP DID, as the bridge recorded it.
	var record_path := _arg(SAVE_DIR_FLAG).path_join("candidate") \
			.path_join("%s.json" % NEXT_ZONE_ID)
	var record: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(record_path))
	var note := ""
	if typeof(record) == TYPE_DICTIONARY:
		for raw: Variant in (record as Dictionary).get("steps", []):
			if str((raw as Dictionary).get("step", "")) == "minors":
				note = str((raw as Dictionary).get("note", ""))
	_check(note.contains("EX50-011 Passing Platforms built as"),
			"the bridge recorded the minors step hosting EX50-011 in %s: %s"
			% [NEXT_ZONE_ID, note.left(160)])
	var minor := _platforms_in(controller)
	_check(not minor.is_empty(), "the controller found it in its room")
	if minor.is_empty():
		return
	await _set_up_platforms(controller, minor)
	await _leave_zone(NEXT_ZONE_ID)


## zone_002, first visit: EX50-011 as built; §9's death rule before
## completion; then the patient route's first half -- the shuttle called
## and STOPPED at the rendezvous -- left there for a restart.
func _set_up_platforms(controller: ZoneController, minor: Dictionary) -> void:
	var player := controller.player
	var rid := str(minor["room_id"])
	var room: PassingPlatformsRoom = \
			(minor["hosted"] as PassingPlatformsHosted).room
	var package := MinorRooms.package_of(rid)
	_check(str(_chamber(rid).get("shell_id", "")) == \
			PassingPlatformsHosted.SHELL_ID,
			"%s is built from the minor's own shell" % rid)
	_check(room.v.at_stop() == PassingPlatformsRoom.V_ARRIVAL
			and room.h.at_dock() == PassingPlatformsRoom.H_WEST
			and not room.stair_released,
			"as built: the lift at A, the shuttle at WEST, no service stair")
	var reward := _reward_in(controller, rid)
	var floor_y := room.global_position.y
	_check(reward != null and absf(reward.global_position.y - floor_y
			- PassingPlatformsRoom.TRANSFER_Y) < 0.6
			and room.to_local(reward.global_position).x
				> PassingPlatformsRoom.G_WEST,
			"its Check stands on the goal gallery G, %.2f m up"
			% ((reward.global_position.y - floor_y) if reward != null
				else -1.0))
	if reward == null or not await _into_the_minor(controller, rid, false):
		return

	# ---- §9: before completion, a death sends the carriers home ---------
	var call: CallLever = room.levers["H EAST"]
	var called := await _operate(controller, call)
	var going := func() -> bool:
		return room.h.heading == RailCarrier.FORWARD and room.h.offset > 1.5
	var under_way := await _wait_for(going, 600)
	_check(called and under_way, "H EAST pulled at A by hand; the shuttle "
			+ "under way (%.2f m along)" % room.h.offset)
	var left_at := room.h.offset
	_note("HARNESS STEP: the player is killed through the damage path, "
			+ "to exercise EX50-011 §9's death rule")
	player.take_damage(1.0e6, Vector3.INF, false)
	var worst := 0.0
	var last := room.h.offset
	var home := false
	for _i in 1200:
		await get_tree().physics_frame
		worst = maxf(worst, absf(room.h.offset - last))
		last = room.h.offset
		if room.h.at_dock() == PassingPlatformsRoom.H_WEST \
				and room.h.heading == RailCarrier.HOLD:
			home = true
			break
	var ceiling := ShuttleDeck.SPEED * DT * 1.5 + RailCarrier.DOCK_EPSILON
	_check(home and worst <= ceiling,
			("the player died before completing it, and the shuttle went "
			+ "home from %.2f m by ordinary motion: largest single step "
			+ "%.3f m against %.3f") % [left_at, worst, ceiling])
	var went := _last_rest(controller, PassingPlatformsRoom.SHUTTLE)
	_check(went.size() == 5 and str(went[3]) == "WEST" and not bool(went[4]),
			"its rest at WEST was reported: %s" % [went])
	var alive := func() -> bool: return not player._dead
	await _wait_for(alive, int((Constants.RESPAWN_DELAY + 1.0) / DT))
	await _settle(10)

	# ---- the patient route's first half: call H, and STOP it ------------
	if not await _into_the_minor(controller, rid, false):
		return
	called = await _operate(controller, call)
	var stop_lever: CallLever = room.levers["STOP H"]
	var watching := await _approach(controller, stop_lever, 1.3,
			stop_lever.global_position + Vector3(0.0, CallLever.BASE.y, 0.0))
	var centred := func() -> bool:
		return absf(_shuttle_x(room) - PassingPlatformsRoom.V_X) < 1.0
	var near := await _wait_for(centred, 1200)
	var stopped := near and await _pull_here(player, stop_lever)
	await _settle(30)
	_check(called and watching and stopped and room.h.held
			and room.h.speed == 0.0 and room.h.at_dock() < 0,
			"H EAST, then STOP H at A as the shuttle crossed the "
			+ "rendezvous: HELD between its berths, %.2f m along" % room.h.offset)
	var rest := _last_rest(controller, PassingPlatformsRoom.SHUTTLE)
	_check(rest.size() == 5 and bool(rest[4]) and str(rest[3]) == ""
			and absf(float(rest[2]) - room.h.offset) < 0.001,
			"the held rest was reported with no errand: %s" % [rest])
	var ref := "%s/%s" % [package, PassingPlatformsRoom.SHUTTLE]
	var recorded_rest := func() -> bool:
		var saved := _saved_rest(ref)
		return saved.size() == 3 and bool(saved[2]) \
				and absf(float(saved[0]) - room.h.offset) < 0.002
	var accepted := await _await_live("the bridge to record the rest",
			recorded_rest, 10.0)
	_check(accepted, "ACCEPTED: '%s' rests at %s in the save"
			% [ref, _saved_rest(ref)])
	# The death's reset commanded the lift home too, and a command that
	# leaves a carrier standing is a rest: at A, unheld.
	var lift := _saved_rest("%s/%s" % [package, PassingPlatformsRoom.LIFT])
	_check(lift.size() == 3 and is_zero_approx(float(lift[0]))
			and str(lift[1]) == "A" and not bool(lift[2]),
			"and the lift's saved rest is its berth at A, unheld: %s" % [lift])
	_check(not BridgeClient.is_checked(reward.location_id)
			and not room.stair_released,
			"left unfinished: the Check unclaimed, no service stair")
	print("played: EX50-011 in %s set up -- %s held at %.3f m" %
			[rid, ref, room.h.offset])


func _next_restore() -> void:
	if not await _campaign():
		return
	_check(str(BridgeClient.hub().get("resume_zone_id", "")) \
			== NEXT_ZONE_ID, "RESTART: the new bridge loaded the save; the "
			+ "Hub offers '%s'" % str(BridgeClient.hub().get(
				"resume_zone_id", "")))
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var minor := _platforms_in(controller)
	_check(not minor.is_empty(), "%s still hosts EX50-011" % NEXT_ZONE_ID)
	if minor.is_empty():
		return
	var player := controller.player
	var rid := str(minor["room_id"])
	var room: PassingPlatformsRoom = \
			(minor["hosted"] as PassingPlatformsHosted).room
	var package := MinorRooms.package_of(rid)
	var ref := "%s/%s" % [package, PassingPlatformsRoom.SHUTTLE]
	var saved := _saved_rest(ref)

	# ---- restored before anyone acts, and it stays put -------------------
	_check(saved.size() == 3 and absf(room.h.offset - float(saved[0]))
			< 0.002 and room.h.held and room.h.heading == RailCarrier.HOLD,
			"RESTORED before the player: the shuttle HELD at %.3f m, where "
			% room.h.offset + "the save says %s" % [saved])
	_check(room.v.at_stop() == PassingPlatformsRoom.V_ARRIVAL
			and not room.v.held, "the lift at A, which is where it was")
	var at := room.h.global_position
	var drift := 0.0
	for _i in 60:
		await get_tree().physics_frame
		drift = maxf(drift, room.h.global_position.distance_to(at))
	_check(drift < 0.001, "and it stays put -- no correction impulse, no "
			+ "replayed motion: %.4f m over a second" % drift)
	_check(controller.carrier_reports.is_empty(),
			"a restored rest reports nothing back")

	# ---- the patient route, finished from the restored shuttle -----------
	if not await _into_the_minor(controller, rid, false):
		return
	await _hop_walk(player, room.to_global(Vector3(
			PassingPlatformsRoom.V_X + 1.0, 0.0,
			PassingPlatformsRoom.V_Z - 1.0)), 0.7)
	await _settle(10)
	_check(_standing_on(player, room.v), "standing on the lift at A")
	var launched := await _pull_here(player, room.levers["LAUNCH"])
	# To the deck's middle while it rises: the step across is then taken
	# where the held shuttle's deck certainly is, not at its edge.
	await _hop_walk(player, room.to_global(Vector3(
			PassingPlatformsRoom.V_X, PassingPlatformsRoom.TRANSFER_Y,
			PassingPlatformsRoom.V_Z - 1.0)), 0.5, 120)
	var at_transfer := func() -> bool:
		return room.v.dwelling_at() == PassingPlatformsRoom.V_TRANSFER
	var dwelling := await _wait_for(at_transfer, 900)
	_check(launched and dwelling, "LAUNCH pulled on the lift's deck; it "
			+ "pauses at the transfer plane beside the held shuttle")
	var dwell := _last_rest(controller, PassingPlatformsRoom.LIFT)
	_check(dwell.size() == 5 and str(dwell[3]) == "SHELF" and bool(dwell[4])
			and absf(float(dwell[2]) - PassingPlatformsRoom.TRANSFER_Y)
				< 0.05,
			"its dwell reported as a HELD rest bound for SHELF: %s" % [dwell])
	await _step_toward(player, _north_yaw(room), 34)
	await _settle(10)
	_check(_standing_on(player, room.h),
			"stepped across onto the restored shuttle")
	var onboard: CallLever = room.levers["H ON EAST"]
	await _hop_walk(player, onboard.global_position, 1.2, 200)
	var restarted := await _pull_here(player, onboard)
	var at_east := func() -> bool:
		return room.h.at_dock() == PassingPlatformsRoom.H_EAST
	var berthed := await _wait_for(at_east, 1500)
	_check(restarted and berthed and _standing_on(player, room.h),
			"H ON EAST pulled on its deck, and it carried the player to "
			+ "the east berth")
	var east := _last_rest(controller, PassingPlatformsRoom.SHUTTLE)
	_check(east.size() == 5 and str(east[3]) == "EAST" and not bool(east[4]),
			"its rest at EAST reported: %s" % [east])
	await _hop_walk(player, room.to_global(Vector3(
			PassingPlatformsRoom.G_WEST + 1.8,
			PassingPlatformsRoom.TRANSFER_Y, 2.2)), 0.8, 300)
	await _settle(20)
	var stair := "%s/stair" % package
	var stair_saved := func() -> bool:
		return _served().get("latched", []).has(stair)
	var recorded := await _await_live("the bridge to record the stair",
			stair_saved, 10.0)
	_check(room.reached_g and room.stair_released and recorded,
			"walked off onto G: the service stair released and ACCEPTED as "
			+ "'%s'" % stair)
	var reward := _reward_in(controller, rid)
	var seen := reward != null and await _approach(controller, reward, 1.2)
	_check(seen and reward.interact_prompt().begins_with("[E] CLAIM"),
			"at the Check on G")
	await _press("interact")
	var confirmed := func() -> bool:
		return reward != null and BridgeClient.is_checked(reward.location_id)
	var claimed := reward != null and await _await_live(
			"the Check to be confirmed", confirmed, 15.0)
	_check(claimed, "the minor's Check %d is CONFIRMED"
			% (reward.location_id if reward != null else -1))
	var at_shelf := func() -> bool:
		var r := _last_rest(controller, PassingPlatformsRoom.LIFT)
		return r.size() == 5 and str(r[3]) == "SHELF" and not bool(r[4])
	var shelf := await _wait_for(at_shelf, 900)
	_check(shelf, "and the lift, left to its schedule, came to rest at "
			+ "SHELF: %s" % [_last_rest(controller, PassingPlatformsRoom.LIFT)])
	print("played: EX50-011 in %s finished from the restored shuttle -- "
			% rid + "%s, Check %d" % [stair, reward.location_id
				if reward != null else -1])
	await _leave_zone(NEXT_ZONE_ID)


func _next_final() -> void:
	if not await _campaign():
		return
	BridgeClient.sent_intents.clear()
	var controller := await _through_the_portal()
	if controller == null:
		return
	var minor := _platforms_in(controller)
	if minor.is_empty():
		_check(false, "%s still hosts EX50-011" % NEXT_ZONE_ID)
		return
	var player := controller.player
	var rid := str(minor["room_id"])
	var room: PassingPlatformsRoom = \
			(minor["hosted"] as PassingPlatformsHosted).room
	var package := MinorRooms.package_of(rid)
	var steps := room.service_stair.get_child_count() \
			if room.service_stair != null else 0
	_check(room.stair_released and steps > 2 and room.g_south_rail == null,
			"RESTORED before anyone acts: the service stair stands, and G's "
			+ "railing is open where it lands (%d pieces)" % steps)
	var h_saved := _saved_rest("%s/%s" % [package,
			PassingPlatformsRoom.SHUTTLE])
	var v_saved := _saved_rest("%s/%s" % [package,
			PassingPlatformsRoom.LIFT])
	_check(h_saved.size() == 3 and str(h_saved[1]) == "EAST"
			and room.h.at_dock() == PassingPlatformsRoom.H_EAST
			and not room.h.held
			and v_saved.size() == 3 and str(v_saved[1]) == "SHELF"
			and room.v.at_stop() == PassingPlatformsRoom.V_SHELF
			and not room.v.held,
			"each carrier where it last came to rest: the shuttle at EAST, "
			+ "the lift at SHELF (%s, %s)" % [h_saved, v_saved])
	var gate := room.gallery_gate
	_check(gate != null and gate.is_open(),
			"and G's glass gate stands open, its shuttle docked there (%.2f "
			% (gate.openness() if gate != null else -1.0) + "open)")
	var reward := _reward_in(controller, rid)
	_check(reward != null and BridgeClient.is_checked(reward.location_id)
			and reward.interact_prompt() == "",
			"the Check stays claimed: nothing to claim twice")
	# THE SHORTCUT IS THE POINT (§4): up from A to G with both carriers
	# elsewhere, on foot.
	if await _into_the_minor(controller, rid, false):
		var foot := room.to_global(Vector3(12.5, 0.0, -9.8))
		var head := room.to_global(Vector3(12.5,
				PassingPlatformsRoom.TRANSFER_Y, 0.6))
		await _hop_walk(player, foot, 0.6, 600)
		await _hop_walk(player, head, 0.6, 600)
		await _settle(20)
		var here := room.to_local(player.global_position)
		_check(player.is_on_floor() and here.x > PassingPlatformsRoom.G_WEST
				and here.y > PassingPlatformsRoom.TRANSFER_Y - 0.2,
				"walked up the service stair from A onto G, the lift at "
				+ "SHELF and the shuttle at EAST: feet at (%.2f, %.2f, %.2f)"
				% [here.x, here.y, here.z])
	await _settle(30)
	_check(_intents("latch_fired").is_empty()
			and _intents("claim_check").is_empty()
			and _intents("carrier_rested").is_empty(),
			"and nothing was announced: no latch, claim or rest sent back")
