extends Node
## A CROSS-ROOM RELATIONSHIP, THROUGH THE REAL ZONE PATH
## (`make godot-zone-state`).
##
## D-8's engine half. The bridge lane declares `Zone.zone_state`; this
## certifies that a declaration becomes a control the player can walk to
## and operate, and a machine in ANOTHER room that follows it.
##
## **What the owner asked to be proven, 2026-09-22**, and each is its own
## case because each is a different way of being wrong:
##
##   source interaction -> accepted Zone state -> remote physical
##   consequence across distinct rooms; then partial and completed
##   reload, and local reset without losing unrelated progress.
##
## **AND THE CORRECTION THAT SHAPES ALL OF IT.** *"Test the real setter
## access and return route, not just room membership or a directly
## assigned flag."* `setter.selects` containing the initial state proves
## an OPERATION exists; it does not prove the player can reach and use
## the control. Blindside's gantry is out of reach without the grapple,
## so "the player entered the room" is not "the player can operate it".
## Every case below that touches the setter walks to it and presses the
## key. Nothing here calls `ZoneState.select`, and nothing assigns a
## value.
##
## **THE REMOTE CONSEQUENCE IS MEASURED PHYSICALLY.** A barrier's
## collider is asked where it is, and a body is walked at the opening.
## `driven` is a field and a field is not a route.
##
## **SYNTHETIC ZONES, REAL PATH.** Each case composes a Zone dictionary
## and builds it through `ZoneController.setup`, which is the production
## path from a declaration to a machine. No composer emits one of these
## yet -- that is the bridge lane's half of the next checkpoint -- so
## these dictionaries stand in for its output and are labelled as
## standing in for it, not as being it.

var _failures := 0
var _checks := 0
var _notes := 0


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _note(message: String) -> void:
	_notes += 1
	print("  NOTE: %s" % message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	await _a_declaration_becomes_a_control_and_a_machine()
	await _the_player_operates_it_and_a_room_away_a_route_opens()
	await _the_reversal_is_reachable_not_merely_declared()
	await _a_partial_reload_keeps_the_configuration()
	await _a_completed_reload_keeps_it_too()
	await _a_local_reset_loses_nothing_unrelated()
	await _a_reader_never_holds_the_setters_node()
	await _a_mechanism_the_engine_cannot_build_is_refused()
	print("")
	if _failures == 0:
		print("GODOT ZONE STATE OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT ZONE STATE: %d failures in %d checks"
			% [_failures, _checks])
	get_tree().quit(1)


## Every intent of one type the client has sent this run.
##
## Read off `BridgeClient.sent_intents` rather than a hook of this
## suite's, so what is asserted is what a live bridge would receive.
func _intents_of(kind: String) -> Array:
	var out: Array = []
	for raw: Variant in BridgeClient.sent_intents:
		var one: Dictionary = raw
		if str(one.get("type", "")) == kind:
			out.append(one)
	return out


func _settle(frames := 8) -> void:
	for _i in frames:
		await get_tree().physics_frame


## Three rooms, a variable set in the first and read in the third.
##
## DISTINCT ROOM IDS, and the consequence is two rooms away from the
## control -- not next door, so "cross-room" is not satisfied by a
## doorway.
func _zone(extra_readers: Array = [],
		mechanism := ZoneStateBuild.BARRIER) -> Dictionary:
	var chambers: Array = []
	for i in 3:
		chambers.append({
			"id": "c%03d" % (i + 1), "type": "corridor",
			"theme": "concrete_facility", "activities": [],
			"features": [], "enemies": [], "rewards": [],
			"interactables": [],
		})
	var readers: Array = [{
		"room_id": "c003", "mechanism": mechanism, "when": ["open"],
	}]
	for one: Variant in extra_readers:
		readers.append(one)
	return {
		"schema_version": 7, "zone_id": "zone_state", "seed": 11,
		"theme": "concrete_facility", "chambers": chambers,
		"zone_state": [{
			"variable_id": "span_gate",
			"states": ["shut", "open"],
			"initial": "shut",
			"lifetime": "reversible",
			"setter": {"room_id": "c001", "selects": ["shut", "open"]},
			"readers": readers,
			"mandatory": false,
		}],
	}


func _built(zone: Dictionary, carried := {}) -> ZoneController:
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.macro_carried = carried
	controller.setup(zone)
	return controller


func _drop(controller: ZoneController) -> void:
	controller.queue_free()
	await get_tree().process_frame


func _the_barrier(controller: ZoneController) -> Node3D:
	for one: Variant in controller.zone_state_readers():
		var node: Node3D = one
		if str(node.get("mechanism")) == ZoneStateBuild.BARRIER:
			return node
	return null


# ------------------------------------------------- the declaration

func _a_declaration_becomes_a_control_and_a_machine() -> void:
	print("  -- A DECLARATION BECOMES A CONTROL AND A MACHINE")
	var controller := _built(_zone())
	await _settle()
	_check(controller.layout_failed == "",
			"the Zone built: %s" % [controller.layout_failed])
	_check(controller.zone_state != null
			and controller.zone_state.declares("span_gate"),
			"the variable is declared in the runtime")
	_check(controller.zone_state.value_of("span_gate") == "shut",
			"...at its declared initial, '%s'"
			% controller.zone_state.value_of("span_gate"))
	_check(controller.zone_state_setters().size() == 1,
			"one setter was built (%d)"
			% controller.zone_state_setters().size())
	_check(controller.zone_state_readers().size() == 1,
			"one reader was built (%d)"
			% controller.zone_state_readers().size())

	# THE CONTROL IS IN ITS DECLARED ROOM AND THE MACHINE IS NOT.
	var setter: Node3D = controller.zone_state_setters()[0]
	var barrier := _the_barrier(controller)
	var in_c001: AABB = controller.room_bounds.get("c001", AABB())
	var in_c003: AABB = controller.room_bounds.get("c003", AABB())
	_check(in_c001.grow(1.5).has_point(setter.global_position),
			"the control stands in c001, the room that declared it")
	_check(barrier != null
			and in_c003.grow(2.0).has_point(barrier.global_position),
			"the machine stands in c003 -- TWO rooms away, so nothing "
			+ "here is satisfied by a shared doorway")
	_check(not in_c001.grow(1.5).has_point(barrier.global_position),
			"...and not in the control's room")
	await _drop(controller)


## THE HEADLINE. Walked to, pressed, and a route opens a room away.
func _the_player_operates_it_and_a_room_away_a_route_opens() -> void:
	print("  -- SOURCE INTERACTION -> ZONE STATE -> REMOTE CONSEQUENCE")
	var controller := _built(_zone())
	await _settle(12)
	var barrier := _the_barrier(controller)
	_check(barrier != null, "the remote machine exists")
	if barrier == null:
		await _drop(controller)
		return
	_check(not barrier.opening_is_clear(),
			"BEFORE: the way through c003 is blocked, measured at the "
			+ "collider")
	var body := _player_at(controller, "c001")
	var setter: CallLever = controller.zone_state_setters()[0]

	# THE REAL INTERACTION. Walked to and operated; `ZoneState.select`
	# is never called by this suite.
	var pulled := await _pull(body, setter)
	_check(pulled, "the player REACHED the control and operated it")
	await _settle(8)
	_check(controller.zone_state.value_of("span_gate") == "open",
			"the Zone accepted the state: '%s'"
			% controller.zone_state.value_of("span_gate"))
	_check(controller.zone_state_changes.size() == 1,
			"...once (%d change(s))"
			% controller.zone_state_changes.size())
	_check(barrier.opening_is_clear(),
			"AFTER: the way through c003 is CLEAR -- a physical "
			+ "consequence in a room the player is not standing in")
	# AND IT IS REPORTED. P-3 named the gap -- storage existed, no
	# message could reach it -- and the bridge lane's
	# `zone_state_selected` closed it. The intent is asserted on the
	# wire rather than inferred from the value, because a Zone that
	# changed state and told nobody is the defect this replaces.
	var sent := _intents_of("zone_state_selected")
	_check(sent.size() == 1,
			"the selection was reported once (%d intent(s))" % sent.size())
	if sent.size() == 1:
		var one: Dictionary = sent[0]
		_check(str(one.get("variable_id", "")) == "span_gate"
				and str(one.get("state", "")) == "open",
				"...naming the variable and the state: %s" % [one])
	_note("reported as %s" % [controller.zone_state.as_reported()])
	body.queue_free()
	await _drop(controller)


## THE OWNER'S CORRECTION, AS A CASE.
##
## `selects` containing `shut` proves a reversal is DECLARED. This walks
## back and performs it, which is the only thing that proves the player
## can still reach and use the control -- and the two are reported
## separately on purpose.
func _the_reversal_is_reachable_not_merely_declared() -> void:
	print("  -- REVERSIBLE OPERATION IS NOT REACHABLE REVERSAL")
	var controller := _built(_zone())
	await _settle(12)
	var declared: Array = controller.zone_state.selectable("span_gate")
	_check(declared.has("shut"),
			"DECLARED: the setter selects the initial state, so a "
			+ "reversal exists on paper %s" % [declared])
	var body := _player_at(controller, "c001")
	var setter: CallLever = controller.zone_state_setters()[0]
	var barrier := _the_barrier(controller)
	_check(await _pull(body, setter)
			and controller.zone_state.value_of("span_gate") == "open",
			"the player opened it")
	await _settle(8)
	# AND BACK. A second operation of the same control, walked to again
	# rather than assumed to be within arm's reach.
	_check(await _pull(body, setter),
			"REACHABLE: the player got back to the control and operated "
			+ "it again")
	await _settle(8)
	_check(controller.zone_state.value_of("span_gate") == "shut",
			"...and the variable is back at '%s'"
			% controller.zone_state.value_of("span_gate"))
	_check(barrier != null and not barrier.opening_is_clear(),
			"...and the route closed again, measured at the collider")
	_note("room membership is not operability: this case would pass on "
			+ "a control nobody could reach if it asked where the "
			+ "player was instead of pressing the key")
	body.queue_free()
	await _drop(controller)


## PARTIAL PROGRESS: the variable was set, the Zone is re-entered.
func _a_partial_reload_keeps_the_configuration() -> void:
	print("  -- PARTIAL RELOAD KEEPS THE CONFIGURATION")
	var first := _built(_zone())
	await _settle(12)
	var body := _player_at(first, "c001")
	var _opened := await _pull(body, first.zone_state_setters()[0])
	await _settle(8)
	var carried: Dictionary = first.zone_state.as_reported()
	_check(str(carried.get("span_gate", "")) == "open",
			"the Zone would carry %s out" % [carried])
	body.queue_free()
	await _drop(first)

	var second := _built(_zone(), carried)
	await _settle(12)
	_check(second.zone_state.value_of("span_gate") == "open",
			"the rebuilt Zone comes up at '%s'"
			% second.zone_state.value_of("span_gate"))
	var barrier := _the_barrier(second)
	_check(barrier != null and barrier.opening_is_clear(),
			"...AND THE BARRIER IS ALREADY CLEAR -- a mechanism that "
			+ "waited for a `changed` signal would have come up shut "
			+ "with the save saying open")
	_check(second.zone_state_changes.is_empty(),
			"...without anything having been operated (%d change(s))"
			% second.zone_state_changes.size())
	await _drop(second)


## COMPLETED PROGRESS: a reversible variable set BACK still reloads as
## what it is, and the permanent half of the Zone stays permanent.
func _a_completed_reload_keeps_it_too() -> void:
	print("  -- COMPLETED RELOAD KEEPS THE REVERSIBLE HALF REVERSIBLE")
	var carried := {"span_gate": "shut"}
	var controller := _built(_zone(), carried)
	await _settle(12)
	_check(controller.zone_state.value_of("span_gate") == "shut",
			"a Zone reloaded at '%s' comes up there"
			% controller.zone_state.value_of("span_gate"))
	var barrier := _the_barrier(controller)
	_check(barrier != null and not barrier.opening_is_clear(),
			"...with the route shut, which is the state and not the "
			+ "absence of one")
	# AND IT IS STILL REVERSIBLE. A reload that quietly converted the
	# variable into a fired latch would look identical until somebody
	# tried to set it back.
	var body := _player_at(controller, "c001")
	_check(await _pull(body, controller.zone_state_setters()[0]),
			"the control still works after a reload")
	await _settle(8)
	_check(controller.zone_state.value_of("span_gate") == "open",
			"...and the variable moved: it came back REVERSIBLE, not as "
			+ "a latch wearing its name")
	body.queue_free()
	await _drop(controller)


## LOCAL RESET: the consequence's room is rebuilt, and nothing else in
## the Zone forgets anything.
func _a_local_reset_loses_nothing_unrelated() -> void:
	print("  -- A LOCAL RESET LOSES NOTHING UNRELATED")
	var controller := _built(_zone())
	await _settle(12)
	var body := _player_at(controller, "c001")
	var _set := await _pull(body, controller.zone_state_setters()[0])
	await _settle(8)
	# Unrelated progress, of the kind a Zone actually carries.
	controller.report_latch("yard", "unrelated")
	var latches_before: Dictionary = controller.latches_fired()
	_check(controller.zone_state.value_of("span_gate") == "open"
			and not latches_before.is_empty(),
			"the Zone holds a configuration AND an unrelated latch")

	# THE RESET: the reader's machine is freed and rebuilt from the
	# variable, which is what a room coming back looks like.
	var barrier := _the_barrier(controller)
	var when: Array = barrier.when.duplicate()
	var at := barrier.global_position
	barrier.queue_free()
	await get_tree().process_frame
	var rebuilt := ZoneStateBuild.ZoneStateMechanism.create(
			"span_gate", ZoneStateBuild.BARRIER, when)
	controller.add_child(rebuilt)
	rebuilt.global_position = at
	rebuilt.bind(controller.zone_state)
	await _settle(4)

	_check(rebuilt.opening_is_clear(),
			"the REBUILT machine comes up matching the variable, not at "
			+ "its resting position")
	_check(controller.zone_state.value_of("span_gate") == "open",
			"...the configuration is untouched by the reset")
	_check(controller.latches_fired() == latches_before,
			"...and the unrelated latch survived it: %s"
			% [controller.latches_fired()])
	body.queue_free()
	await _drop(controller)


## THE STALE REFERENCE, which the contract makes unwritable and this
## keeps unwritable at runtime.
func _a_reader_never_holds_the_setters_node() -> void:
	print("  -- A REBUILT DESTINATION HOLDS NO STALE SOURCE REFERENCE")
	var controller := _built(_zone())
	await _settle(12)
	var barrier := _the_barrier(controller)
	var setter: Node3D = controller.zone_state_setters()[0]
	# FREE THE SOURCE ENTIRELY. If the reader held it, what follows
	# would be a call into a freed object.
	setter.queue_free()
	await get_tree().process_frame
	_check(is_instance_valid(barrier),
			"the machine survives its control being freed")
	# And the variable still drives it, because the binding was never
	# to the node.
	controller.zone_state.select("span_gate", "open")
	await _settle(4)
	_check(barrier.opening_is_clear(),
			"...and still follows the VARIABLE with the control gone")
	_note("this is the only case that calls `select` directly, and it "
			+ "does it because the control has deliberately been "
			+ "destroyed")
	await _drop(controller)


## A mechanism the engine does not implement builds nothing and says so.
func _a_mechanism_the_engine_cannot_build_is_refused() -> void:
	print("  -- AN UNIMPLEMENTED MECHANISM IS REFUSED BY NAME")
	var controller := _built(_zone([], "conveyor"))
	await _settle(8)
	_check(controller.zone_state_setters().is_empty()
			and controller.zone_state_readers().is_empty(),
			"nothing was built for a mechanism the engine cannot honour")
	_check(controller.zone_state_refusals.size() == 1,
			"...and it said so once (%d)"
			% controller.zone_state_refusals.size())
	if not controller.zone_state_refusals.is_empty():
		_check(str(controller.zone_state_refusals[0]).contains("conveyor"),
				"...naming it: %s" % controller.zone_state_refusals[0])
	_check(controller.layout_failed == "",
			"the Zone still built: a relationship the engine will not "
			+ "guess at is a finding, not a crash")
	await _drop(controller)


# ------------------------------------------------- the player's hands

func _player_at(controller: ZoneController, room_id: String) -> Player:
	var body := Player.create()
	controller.add_child(body)
	var place: Dictionary = controller.room_places.get(room_id, {})
	body.global_position = (place.get("arrival", Vector3.ZERO)
			as Vector3) + Vector3(0.0, 0.6, 0.0)
	body.velocity = Vector3.ZERO
	return body


func _aim(body: Player, at: Vector3) -> void:
	var d := at - (body.global_position + Vector3(0.0, 1.5, 0.0))
	body.rotation.y = atan2(-d.x, -d.z)
	if body.camera != null:
		body.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## Walk to a lever and press `interact`. Returns whether it actually
## went off -- which is the only evidence that the control was reachable.
func _pull(body: Player, lever: CallLever) -> bool:
	var walked := await _walk_to(body, lever.global_position, 1.7)
	if not walked:
		_note("PULL did not reach %s: stopped %.2f m away"
				% [lever.name,
					body.global_position.distance_to(
						lever.global_position)])
		return false
	var before := lever.pulls
	_aim(body, lever.global_position + Vector3(0.0, 0.1, 0.0))
	await get_tree().physics_frame
	# WHAT THE PLAYER IS ACTUALLY LOOKING AT. Reported only when the
	# pull fails, because that is the one time it is not obvious: a
	# control placed through a wall looks identical to one that ignores
	# the key, and the first cut of this builder placed one 2.6 m
	# sideways into a corridor's plaster.
	var ray: Dictionary = body.camera_ray(3.0)
	if ray.is_empty() or (ray["collider"] as Node) != lever:
		_note("PULL aimed at %s and the ray found %s"
				% [lever.name, "nothing" if ray.is_empty()
					else str((ray["collider"] as Node).name)])
	Input.action_press("interact", 1.0)
	for _i in 16:
		await get_tree().physics_frame
		if lever.pulls > before:
			break
	Input.action_release("interact")
	await get_tree().physics_frame
	return lever.pulls > before


func _walk_to(body: Player, goal: Vector3, within := 1.5,
		frames := 600) -> bool:
	var arrived := false
	var still := 0
	var last := body.global_position
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		if body.camera != null:
			body.camera.rotation.x = 0.0
		if (here - last).length() < 0.012:
			still += 1
			if still == 14 and body.is_on_floor():
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
