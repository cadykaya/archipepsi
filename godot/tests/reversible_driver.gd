extends "res://tests/transport_driver.gd"
## O05-04 — A REVERSIBLE BRANCH ACTION CHANGES ACCESS ELSEWHERE
## (`--reversible`).
##
##     make godot-reversible
##
## The Zone is `tests/fixtures/reversible_zone.json`, which `make
## reversible-fixture` writes from the played Zone through the CANDIDATE
## profile's `zone_state` step: D-8's `compose_zone_state` with a lamp
## reader in the first room past the gate (`reader_order="nearest"`). A
## lever in c002 selects `span_alignment`, the doorway e:c002:c003 is
## open only while it reads `lowered`, and c003's lamp shows it.
##
## **WHAT IS PLAYED.** The real player, on real input, from the Zone's
## arrival:
## - c002 is cleared with the base kit;
## - the shut doorway holds against a straight press;
## - the lever is operated with the interact ray, and it says PENDING,
##   because no bridge has answered;
## - the doorway opens and the lamp past it lights;
## - the player walks through, comes back, reverses the lever, and the
##   doorway shuts and holds again.
##
## Then OCCUPANCY (O05-04.4). A required crate sits in the opening and the
## lever is reversed. The closure is QUEUED -- §21.2's interlock holds the
## panel open while anything it protects is in the opening -- and it is
## APPLIED by itself once the player picks the crate up and carries it
## clear along the wall. Then EGRESS: with the doorway shut, the way the
## player came in is still open.
##
## **HARNESS STEPS, declared where they happen:**
## - the verdict-wait release (as every played suite here does it);
## - a spare crate put down in the opening for the occupancy case (carried
##   there by hand, it was squeezed out of the player's grip by c002's
##   Check pedestal, which stands in front of this exit);
## - rebuilding from a snapshot's values for the restore case;
## - feeding the controller the refusal the bridge would send, in the
##   SYNTHETIC authority case. `godot-reversible-live` does that case
##   through a real bridge.

const REVERSIBLE_FIXTURE := "res://tests/fixtures/reversible_zone.json"
const SPAN := "span_alignment"


func _run() -> void:
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(REVERSIBLE_FIXTURE))
	await _built_as_declared(zone_data)
	await _operated_reversed_and_queued(zone_data)
	await _restored_in_either_configuration(zone_data)
	await _a_refused_selection_is_put_back(zone_data)
	_finish()


func _finish() -> void:
	if failures == 0:
		print("GODOT REVERSIBLE TESTS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT REVERSIBLE TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _lever(controller: ZoneController) \
		-> ZoneStateBuild.ZoneStateSetterControl:
	for raw: Variant in controller.zone_state_setters():
		var control: ZoneStateBuild.ZoneStateSetterControl = raw
		if control.variable_id == SPAN:
			return control
	return null


func _span_lamps(controller: ZoneController) -> Array:
	var out: Array = []
	for raw: Variant in controller.zone_state_readers():
		var node: ZoneStateBuild.ZoneStateMechanism = raw
		if node.variable_id == SPAN:
			out.append(node)
	return out


func _lit(controller: ZoneController) -> bool:
	var lamps := _span_lamps(controller)
	return not lamps.is_empty() and lamps.all(
			func(l: ZoneStateBuild.ZoneStateMechanism) -> bool:
				return l.driven)


func _dark(controller: ZoneController) -> bool:
	var lamps := _span_lamps(controller)
	return not lamps.is_empty() and lamps.all(
			func(l: ZoneStateBuild.ZoneStateMechanism) -> bool:
				return not l.driven)


func _selections(state: String) -> int:
	var n := 0
	for intent: Dictionary in _intents("zone_state_selected"):
		if str(intent.get("variable_id", "")) == SPAN \
				and str(intent.get("state", "")) == state:
			n += 1
	return n


## Walk to the lever and pull it with the interact ray.
func _pull(controller: ZoneController) -> bool:
	var lever := _lever(controller)
	var top := lever.global_position + Vector3(0.0, CallLever.BASE.y, 0.0)
	var seen := await _approach(controller, lever, 1.3, top)
	if not seen:
		return false
	var player := controller.player
	var before := lever.pulls
	var aimed := player._interact_target
	await _press("interact")
	await _settle(4)
	if lever.pulls == before:
		_note("the press did not reach the lever: target at press %s, "
				% [aimed] + "holds %s, frozen %s, carrying %s"
				% [player.holds(), player.input_frozen,
					player.carry.holding()])
	return lever.pulls > before


# ---------------------------------------------------------------------------
# 1. What the declaration builds
# ---------------------------------------------------------------------------

func _built_as_declared(zone_data: Dictionary) -> void:
	print("  -- the composed relationship becomes a lever, a gate, a lamp")
	var controller := await _enter(zone_data)
	var declared: Dictionary = (zone_data["zone_state"] as Array)[0]
	var setter_room := str((declared["setter"] as Dictionary)["room_id"])
	var lever := _lever(controller)
	_check(controller.zone_state_refusals.is_empty()
			and controller.state_gate_refusals.is_empty(),
			"nothing refused: state %s, gates %s"
			% [controller.zone_state_refusals,
				controller.state_gate_refusals])
	_check(lever != null and (controller.room_bounds[setter_room] as AABB)
			.grow(0.2).has_point(lever.global_position),
			"the lever stands in %s" % setter_room)
	var edge := _gated_edge(zone_data)
	var gate := _gate(controller)
	_check(gate != null and gate.edge_id == str(edge.get("edge_id", ""))
			and gate.shutter.is_shut(),
			"'%s' is shut by its declared gate" % str(edge.get("edge_id")))
	_check(_dark(controller), "the lamp past it is dark")
	var frame := RoomGraphs.doorway_frame(setter_room, edge,
			zone_data.get("chambers", []) as Array, controller.door_frames)
	var ref := "%s/%s" % [setter_room, str(frame.get("socket_id", ""))]
	_check(controller.measured_apertures.has(ref)
			and bool(controller.measured_apertures[ref]),
			"the layout evidence reads %s as an opening, gate and all" % ref)
	await _drop(controller)


# ---------------------------------------------------------------------------
# 2. Operated, reversed, queued -- with the body
# ---------------------------------------------------------------------------

func _operated_reversed_and_queued(zone_data: Dictionary) -> void:
	print("  -- operate, walk through, reverse; then a closure held by the "
			+ "interlock")
	var controller := await _enter(zone_data)
	var player := controller.player
	var declared: Dictionary = (zone_data["zone_state"] as Array)[0]
	var setter_room := str((declared["setter"] as Dictionary)["room_id"])
	var edge := _gated_edge(zone_data)
	var beyond := str(edge["room_b"]) if str(edge["room_a"]) == setter_room \
			else str(edge["room_a"])
	var spine: Array = (zone_data["chambers"] as Array).map(
			func(c: Dictionary) -> String: return str(c["id"]))
	var entrance := str(spine[spine.find(setter_room) - 1])
	var gate := _gate(controller)
	var lever := _lever(controller)
	if not await _advance_to(controller, setter_room):
		await _drop(controller)
		return
	var frame := RoomGraphs.doorway_frame(setter_room, edge,
			zone_data.get("chambers", []) as Array, controller.door_frames)
	var door: Vector3 = frame["position"]
	var box: AABB = controller.room_bounds[setter_room]
	var inward := _inward_of(frame, box)

	# ---- shut ----------------------------------------------------------
	await _walk_to(player, door + inward * 2.5, AABB(), 600, false, 0.4)
	var pressed := await _press_toward(player, door - inward * 3.0, 150)
	_check(_side_of(frame, inward, pressed["at"]) > 0.0
			and gate.shutter.is_shut(),
			"SHUT: pressed at the doorway for 2.5 s, the player stays on "
			+ "this side (%.2f m in)" % _side_of(frame, inward, pressed["at"]))

	# ---- operate ---------------------------------------------------------
	var pulled := await _pull(controller)
	_check(pulled, "the interact ray finds the lever")
	_check(controller.zone_state.value_of(SPAN) == "lowered"
			and _selections("lowered") == 1,
			"OPERATED with `interact`: %s = %s, reported once"
			% [SPAN, controller.zone_state.value_of(SPAN)])
	_check(lever.status == "PENDING"
			and lever.interact_prompt().contains("PENDING"),
			"SOURCE FEEDBACK: the lever says what it is waiting for: \"%s\""
			% lever.interact_prompt())
	var opened := await _wait_for(func() -> bool:
		return gate.shutter.is_open(), 600)
	_check(opened and _lit(controller),
			"DESTINATION: the doorway opened and %s's lamp lit" % beyond)
	var through := await _walk_into(controller, beyond)
	_check(bool(through["inside"]),
			"THROUGH: the player walks into %s" % beyond)

	# ---- return and reverse --------------------------------------------
	var back := await _walk_back(controller, beyond, setter_room)
	_check(bool(back["inside"]), "back in %s, at the control" % setter_room)
	_check(await _pull(controller)
			and controller.zone_state.value_of(SPAN) == "stowed"
			and _selections("stowed") == 1,
			"REVERSED at the same lever: %s = %s"
			% [SPAN, controller.zone_state.value_of(SPAN)])
	var shut := await _wait_for(func() -> bool:
		return gate.shutter.is_shut(), 600)
	await _walk_to(player, door + inward * 2.5, AABB(), 600, false, 0.4)
	pressed = await _press_toward(player, door - inward * 3.0, 150)
	_check(shut and _side_of(frame, inward, pressed["at"]) > 0.0
			and _dark(controller),
			"and the route closes again: the doorway holds, the lamp is "
			+ "dark")

	# ---- occupancy: queued versus applied ------------------------------
	_check(await _pull(controller) and controller.zone_state.value_of(SPAN)
			== "lowered", "lowered once more")
	await _wait_for(func() -> bool: return gate.shutter.is_open(), 600)
	# HARNESS STEP: a spare crate put down IN THE OPENING. It is `required`,
	# so §21.2's interlock protects it as it protects a body. (Carried
	# there by hand, it was squeezed out of the player's grip by c002's
	# Check pedestal, which stands in front of this exit.)
	var crate := ManipulableBody.create("wedge", 20.0, Vector3(0.5, 0.5, 0.5))
	crate.carriable = true
	crate.add_to_group(Constants.REQUIRED_OBJECT_GROUP)
	controller.add_child(crate)
	crate.global_position = door + Vector3(0.0, 0.3, 0.0)
	await _settle(30)
	_check(absf(_side_of(frame, inward, crate.global_position)) < 0.8,
			"the crate rests in the opening (%.2f m from the door plane)"
			% _side_of(frame, inward, crate.global_position))
	_check(await _pull(controller)
			and controller.zone_state.value_of(SPAN) == "stowed",
			"reversed with the crate in the opening")
	await _settle(150)
	_check(gate.closing_is_queued() and gate.shutter.refusals() >= 1
			and gate.describe().contains("QUEUED"),
			"QUEUED, NOT APPLIED: commanded shut, held open by the "
			+ "interlock (%s, %d refusal(s))"
			% [gate.describe(), gate.shutter.refusals()])
	# THE SAFE WAY OFF: pick it up out of the opening and carry it along
	# the wall, clear of the doorway.
	var along := inward.cross(Vector3.UP).normalized()
	await _walk_to(player, door + inward * 1.8, AABB(), 600, false, 0.3)
	var took := await _approach(controller, crate, 1.2)
	await _press("interact")
	_check(took and player.carry.holding() and player.carry.body == crate,
			"the player picks the crate up out of the opening")
	await _walk_to(player, door + inward * 1.6 + along * 3.0, AABB(), 300,
			false, 0.4)
	player.camera.rotation.x = 0.0
	await _press("interact")
	var applied := await _wait_for(func() -> bool:
		return gate.shutter.is_shut(), 600)
	_check(applied and not gate.shutter.doorway_occupied(),
			"APPLIED BY ITSELF once the opening was clear: %s (crate %.2f m "
			% [gate.describe(), absf(_side_of(frame, inward,
				crate.global_position))] + "from the plane)")

	# ---- egress ----------------------------------------------------------
	var out := await _walk_back(controller, setter_room, entrance)
	_check(bool(out["inside"]),
			"EGRESS: with the doorway shut, the way in is still open -- "
			+ "back in %s" % entrance)
	await _drop(controller)


# ---------------------------------------------------------------------------
# 3. Restored in either configuration
# ---------------------------------------------------------------------------

func _restored_in_either_configuration(zone_data: Dictionary) -> void:
	print("  -- restored lowered and restored stowed")
	# HARNESS STEP: the snapshot's values, as `Main._to_zone` passes them.
	var lowered := await _enter(zone_data, {"macro": {SPAN: "lowered"}})
	var gate := _gate(lowered)
	_check(gate.shutter.is_open() and gate.shutter.openness() >= 0.999
			and _lit(lowered),
			"LOWERED at load: the doorway is open the moment the Zone "
			+ "exists (%.2f), the lamp lit" % gate.shutter.openness())
	_check(_lever(lowered).interact_prompt().contains("now LOWERED")
			and _intents("zone_state_selected").is_empty(),
			"the lever reads the restored value and nothing is announced")
	await _drop(lowered)
	var stowed := await _enter(zone_data, {"macro": {SPAN: "stowed"}})
	_check(_gate(stowed).shutter.is_shut() and _dark(stowed),
			"STOWED at load: shut, dark")
	await _drop(stowed)


# ---------------------------------------------------------------------------
# 4. Authority (synthetic)
# ---------------------------------------------------------------------------

func _a_refused_selection_is_put_back(zone_data: Dictionary) -> void:
	print("  -- SYNTHETIC: a refusal naming the selection puts it back")
	var controller := await _enter(zone_data)
	var lever := _lever(controller)
	var gate := _gate(controller)
	# The lever's own `interact`, as the ray would call it.
	lever.interact(controller.player)
	await _settle(4)
	_check(controller.zone_state.value_of(SPAN) == "lowered"
			and controller.zone_state_pending.get(SPAN) == "lowered",
			"pulled: lowered, pending")
	# An unrelated snapshot does not resolve it.
	BridgeClient.snapshot_received.emit({})
	_check(controller.zone_state_pending.has(SPAN),
			"an unrelated snapshot leaves it pending")
	# A refusal about a DIFFERENT selection does not either.
	BridgeClient.error_received.emit({"message": "no",
			"about": "zone_state_selected:%s:%s:stowed"
				% [controller.zone_id, SPAN]})
	_check(controller.zone_state_pending.has(SPAN)
			and controller.zone_state.value_of(SPAN) == "lowered",
			"a refusal naming another state leaves it alone")
	# THE refusal: exactly this selection.
	BridgeClient.error_received.emit({"message": "has no committed layout",
			"about": "zone_state_selected:%s:%s:lowered"
				% [controller.zone_id, SPAN]})
	await _settle(4)
	_check(not controller.zone_state_pending.has(SPAN)
			and controller.zone_state.value_of(SPAN) == "stowed"
			and lever.status == "REFUSED",
			"REFUSED: put back to the campaign's value (%s), the lever "
			% controller.zone_state.value_of(SPAN) + "says so: \"%s\""
			% lever.interact_prompt())
	var reshut := await _wait_for(func() -> bool:
		return gate.shutter.is_shut(), 600)
	_check(reshut and _dark(controller),
			"and the doorway and the lamp follow it back")
	_check(_selections("stowed") == 0,
			"putting it back is not a new selection: nothing was sent")
	await _drop(controller)
