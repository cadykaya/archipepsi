extends Node
## A DECLARED GANTRY, BUILT INTO A REAL ZONE (`make godot-rail-gantry`).
##
## D-6 step 3, Dess's note D-9. `RailSpan.control_placement` (`9bed879`)
## lets a Zone put a span's control on a gantry: `CONTROL_PLACEMENT_
## CAPABILITY["gantry"]` is `grapple`, so the AP logic declares that the
## control needs the proven anchor grapple. This certifies that the room
## holds exactly that gate -- no more, which would be a gate the logic
## does not declare, and no less, which would be a loop a player skips.
##
## **What a certification has to check, and why each one.**
##
##   THE DECLARATION BECOMES A GANTRY. Until D-9 `RailNetworks` never
##   read the field: a gantry span got the ground lever, reachable on
##   foot, and the grapple the logic demands bought nothing.
##   IT IS THE MEASURED ONE. The development scenario measured the only
##   arrangement known to work (`railway_scenario.gd`): from the floor
##   the player grapples from, the deck's top 2.9 m up, the plate 6.2 m
##   up over its near lip, the player 1.5 m short of that lip. Those are
##   this suite's own numbers, stated here rather than read back from
##   the build, so a build that drifts from them fails.
##   IT IS OFF THE TRACK. A control room is a dock room and the track
##   runs through it; a deck across it is a carrier that cannot pass.
##   THE BASE KIT CANNOT REACH IT -- played: the jumps a player would
##   try and the lever from the floor, and none of them works.
##   THE GRAPPLE DOES -- played through the input path, onto the deck,
##   and the lever there starts the span.
##   A GROUND SPAN IS UNCHANGED, the control that makes every check
##   above about the field rather than about rail networks in general.
##   AND A ROOM THE GANTRY DOES NOT FIT IS REFUSED BY NAME -- too low,
##   too small, two to a room, or a surface the base kit could jump to
##   the deck from -- building nothing for that network, while the Zone
##   still builds.
##
## **SYNTHETIC ZONES,** as in `godot-rail-zone`: each case composes a
## small Zone and builds it through the real `ZoneController`, and the
## player is the real `Player` driven through `Input`.

## The scenario's measurement, relative to the floor grappled from.
const DECK_TOP := 2.9
const PLATE_UP := 6.2
const APPROACH := 1.5
## Where the ground lever stands, relative to the arrival.
const GROUND_OFFSET := Vector3(2.2, 0.0, 0.0)
const RN_PATH := "res://scripts/generation/rail_networks.gd"
## The control room's span. Arenas run 10 to 28 m
## (`PROCEDURAL_ARENA_MIN_SPAN`, `_MAX_SPAN`); see `_a_crowded_arena`
## for why this one is 24.
const ARENA := 24.0

var _failures := 0
var _checks := 0
var _notes := 0
var _rn: GDScript = null


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
	_rn = load(RN_PATH)
	_run()


func _run() -> void:
	await get_tree().process_frame
	await _the_declared_gantry_is_built()
	await _the_base_kit_cannot_reach_it()
	await _the_grapple_does_and_the_lever_starts_the_span()
	await _a_ground_span_keeps_its_ground_lever()
	await _a_room_the_gantry_does_not_fit_is_refused()
	await _a_step_to_the_deck_is_measured()
	print("")
	if _failures == 0:
		print("GODOT RAIL GANTRY OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT RAIL GANTRY: %d failures in %d checks"
			% [_failures, _checks])
	get_tree().quit(1)


func _settle(frames := 8) -> void:
	for _i in frames:
		await get_tree().physics_frame


## Three rooms, one railway: c001 and c003 corridors, c002 the control
## room -- an arena, `ARENA` square and `height` tall unless `arena` says
## otherwise. `spans` is the caller's, so each case declares exactly the
## shape it is about.
func _zone(spans: Array, height := 8.0, arena := {}) -> Dictionary:
	var chambers: Array = []
	var docks: Array = []
	for i in 3:
		var rid := "c%03d" % (i + 1)
		var chamber := {
			"id": rid, "type": "corridor", "theme": "concrete_facility",
			"activities": [], "features": [], "enemies": [],
			"rewards": [], "interactables": [],
		}
		if rid == "c002":
			chamber["type"] = "arena"
			chamber["width"] = ARENA
			chamber["depth"] = ARENA
			chamber["wall_height"] = height
			chamber.merge(arena, true)
		chambers.append(chamber)
		docks.append({"dock_id": "d%d" % i, "room_id": rid})
	return {
		"schema_version": 7, "zone_id": "zone_gantry", "seed": 7,
		"theme": "concrete_facility", "chambers": chambers,
		"rail_networks": [{
			"network_id": "yard", "docks": docks, "spans": spans,
		}],
	}


func _span(placement := "gantry", span_id := "s0", from := "d0",
		to := "d1", room := "c002") -> Dictionary:
	var span := {"span_id": span_id, "from_dock": from, "to_dock": to,
			"control_room_id": room, "latch_id": "%s_latch" % span_id,
			"mandatory": true}
	if placement != "":
		span["control_placement"] = placement
	return span


func _built(zone: Dictionary) -> ZoneController:
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(zone)
	return controller


func _drop(node: Node) -> void:
	node.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _floor(controller: ZoneController) -> float:
	return ((controller.room_places.get("c002", {}) as Dictionary)
			.get("arrival", Vector3.ZERO) as Vector3).y


func _gantry(controller: ZoneController, span_id := "s0") -> Node3D:
	return controller.find_child("Gantry_%s" % span_id, true, false) \
			as Node3D


func _part(gantry: Node3D, part: String) -> Node3D:
	return null if gantry == null \
			else gantry.find_child(part, false, false) as Node3D


## Where the scenario's player stood to fire: `APPROACH` short of the
## point under the plate, on the side away from the deck.
func _approach(gantry: Node3D, floor_y: float) -> Vector3:
	var plate := _part(gantry, "Plate").global_position
	var deck := _part(gantry, "Deck").global_position
	var away := Vector3(deck.x - plate.x, 0.0, deck.z - plate.z).normalized()
	return Vector3(plate.x, floor_y, plate.z) - away * APPROACH


func _player_at(at: Vector3) -> Player:
	var body := Player.create()
	add_child(body)
	body.global_position = at
	body.velocity = Vector3.ZERO
	return body


func _aim(body: Player, at: Vector3) -> void:
	var d: Vector3 = at - body.camera.global_position
	body.rotation.y = atan2(-d.x, -d.z)
	body.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## The jump as the physics steps it: explicit integration peaks half a
## step above v^2/2g.
func _stepped_apex() -> float:
	return Constants.JUMP_APEX_HEIGHT + Constants.JUMP_VELOCITY \
			/ (2.0 * float(Engine.physics_ticks_per_second))


func _rn_has(method: String) -> bool:
	for entry: Dictionary in _rn.get_script_method_list():
		if str(entry.get("name", "")) == method:
			return true
	return false


# ------------------------------------------------------ the declaration

func _the_declared_gantry_is_built() -> void:
	print("  -- THE DECLARATION BECOMES THE MEASURED GANTRY")
	var controller := _built(_zone([_span()]))
	await _settle()
	_check(controller.layout_failed == "",
			"the Zone built: %s" % [controller.layout_failed])
	_check(controller.rail_refusals.is_empty(),
			"the network was not refused: %s" % [controller.rail_refusals])
	var junctions: Array = controller.rail_junctions()
	_check(junctions.size() == 1, "one junction (%d)" % junctions.size())
	if junctions.is_empty():
		await _drop(controller)
		return
	var junction: RailJunction = junctions[0]
	var control: AlignmentControl = junction.controls()[0] \
			if not junction.controls().is_empty() else null
	var floor_y := _floor(controller)
	var arrival: Vector3 = (controller.room_places["c002"] as Dictionary)[
			"arrival"]
	_check(control != null
			and control.global_position.distance_to(arrival + GROUND_OFFSET)
				> 1.0,
		"the control is not the ground lever at the arrival (%v; the "
			% [control.global_position if control != null else Vector3.INF]
			+ "ground spot is %v)" % (arrival + GROUND_OFFSET))
	var gantry := _gantry(controller)
	_check(gantry != null, "a gantry was built for span s0")
	if gantry == null or control == null:
		await _drop(controller)
		return
	var deck := _part(gantry, "Deck")
	var plate := _part(gantry, "Plate")
	_check(deck != null and plate != null
			and _part(gantry, "Post") != null
			and _part(gantry, "Ring") != null,
		"with its deck, post, plate and ring")
	if deck == null or plate == null:
		await _drop(controller)
		return
	var deck_box := ((deck.find_child("*", false, false) as CollisionShape3D)
			.shape as BoxShape3D).size
	var deck_top := deck.global_position.y + deck_box.y * 0.5 - floor_y
	_check(absf(deck_top - DECK_TOP) < 0.05,
		"the deck's top stands %.2f m above the floor (measured: %.1f)"
			% [deck_top, DECK_TOP])
	_check(absf(plate.global_position.y - floor_y - PLATE_UP) < 0.05,
		"the plate is %.2f m up (measured: %.1f)"
			% [plate.global_position.y - floor_y, PLATE_UP])
	# OVER THE NEAR LIP: the plate's point on the floor is the deck's
	# edge nearest the approach.
	var away := Vector3(deck.global_position.x - plate.global_position.x,
			0.0, deck.global_position.z - plate.global_position.z)
	_check(absf(away.length() - deck_box.z * 0.5) < 0.05,
		"the plate hangs over the deck's near lip (%.2f m from its "
			% away.length() + "centre, half the deck is %.2f)"
			% (deck_box.z * 0.5))
	# THE LEVER ON THE DECK.
	var on_deck := deck.global_transform.affine_inverse() \
			* control.global_position
	_check(absf(on_deck.x) < deck_box.x * 0.5
			and absf(on_deck.z) < deck_box.z * 0.5
			and control.global_position.y > deck.global_position.y,
		"the control stands on the deck (%v in the deck's frame)"
			% on_deck)
	var home: AABB = controller.room_bounds["c002"]
	_check(home.has_point(deck.global_position)
			and home.has_point(plate.global_position),
		"and all of it is in c002, the room that declared it")
	# OFF THE TRACK. The carrier's deck passes the whole route; the
	# gantry's footprint keeps clear of every point of it by the
	# carrier's half-width.
	var carrier: RailCarrier = controller.rail_carriers()[0]
	var nearest := INF
	var inv := deck.global_transform.affine_inverse()
	for point: Vector3 in carrier.path.polyline(0.25):
		if point.y < home.position.y or point.y > home.end.y:
			continue
		var local := inv * point
		nearest = minf(nearest, Vector2(
				maxf(absf(local.x) - deck_box.x * 0.5, 0.0),
				maxf(absf(local.z) - deck_box.z * 0.5, 0.0)).length())
	_check(nearest > carrier.deck.x * 0.5,
		"the track passes %.2f m from the deck; the carrier is %.2f m "
			% [nearest, carrier.deck.x] + "wide")
	# AND THE CARRIER IS NO STEP TO IT: from its deck a jump tops out
	# below the gantry's.
	var ride_top := carrier.global_position.y + carrier.deck.y * 0.5 \
			- floor_y
	_check(ride_top + _stepped_apex() < DECK_TOP,
		"a jump from the carrier tops out at %.2f m, under the deck"
			% (ride_top + _stepped_apex()))
	await _drop(controller)


# ------------------------------------------------------ the base kit

## Everything a player without the grapple would try. On the ground
## lever a gantry span used to get, the last of these operated it.
func _the_base_kit_cannot_reach_it() -> void:
	print("  -- THE BASE KIT CANNOT REACH IT (played)")
	var controller := _built(_zone([_span()]))
	await _settle()
	var gantry := _gantry(controller)
	var junctions: Array = controller.rail_junctions()
	var control: AlignmentControl = null
	if not junctions.is_empty() \
			and not (junctions[0] as RailJunction).controls().is_empty():
		control = (junctions[0] as RailJunction).controls()[0]
	var floor_y := _floor(controller)
	if control == null:
		_check(false, "there is a control to try for")
		await _drop(controller)
		return
	var on_deck := 0
	var peak := 0.0
	var standing := 0.0
	var tried := 0
	if gantry != null:
		var start := _approach(gantry, floor_y)
		var plate_at := _part(gantry, "Plate").global_position
		var deck := _part(gantry, "Deck").global_position
		var away := Vector3(deck.x - plate_at.x, 0.0, deck.z - plate_at.z) \
				.normalized()
		var lip := Vector3(plate_at.x, floor_y, plate_at.z)
		# THE JUMP ITSELF, standing, in the open at the approach: what the
		# reach field's apex has to be.
		var still := _player_at(start)
		await _settle(20)
		Input.action_press("jump")
		for frame in 60:
			if frame == 3:
				Input.action_release("jump")
			await get_tree().physics_frame
			standing = maxf(standing, still.global_position.y - floor_y)
		Input.action_release("jump")
		await _drop(still)
		# AT THE LIP, as a player tries it: walking at the deck from the
		# approach and from a run-up, jumping as the body reaches its edge
		# and far enough back that the apex falls on it, held forward.
		# THE RUN-UP STAYS ON THIS ROOM'S FLOOR: back from the approach as
		# far as 4 m goes without leaving the room.
		var inside: AABB = (controller.room_bounds["c002"] as AABB).grow(-1.0)
		var back := 0.0
		while back < 4.0 and inside.has_point(start - away * (back + 0.5)
				+ Vector3.UP * 0.5):
			back += 0.5
		for attempt: Array in [[0.0, 0.7], [back, 0.7], [back, 2.7]]:
			var lead: float = attempt[1]
			var body := _player_at(start - away * float(attempt[0]))
			await _settle(20)
			_aim(body, Vector3(deck.x, floor_y + 1.6, deck.z))
			Input.action_press("move_forward")
			var jumped := -1
			var high := 0.0
			var took_off := INF
			for frame in 150:
				var to_lip := (lip - body.global_position).dot(away)
				if jumped < 0 and to_lip <= lead:
					Input.action_press("jump")
					jumped = frame
				elif jumped >= 0 and frame == jumped + 3:
					Input.action_release("jump")
				await get_tree().physics_frame
				if not body.is_on_floor() and took_off == INF:
					took_off = to_lip
				high = maxf(high, body.global_position.y - floor_y)
				if body.is_on_floor() \
						and body.global_position.y - floor_y > DECK_TOP - 0.5:
					on_deck += 1
			Input.action_release("move_forward")
			Input.action_release("jump")
			_note("from %.1f m back, jumping %.1f m short of the lip: left "
					% [float(attempt[0]), lead] + "the floor %.2f m short, "
					% took_off + "peaked %.2f m" % high)
			# AN ATTEMPT THAT NEVER JUMPED TESTS NOTHING: it left the floor
			# where it meant to, and rose.
			if absf(took_off - lead) < 0.6 and high > 0.5:
				tried += 1
			peak = maxf(peak, high)
			await _drop(body)
	_check(gantry != null and tried == 3 and on_deck == 0,
		"no jump at the lip puts the base kit on the deck (%d of 3 "
			% tried + "attempts jumped where they meant to; peak %.2f m; "
			% peak + "the deck is at %.1f)" % DECK_TOP)
	# THE FIELD'S APEX IS THE PLAYED ONE, or its "out of reach" is about
	# some other body.
	_check(gantry == null or absf(standing - _stepped_apex()) < 0.03,
		"a standing jump peaks at %.2f m, the apex the reach field uses "
			% standing + "(%.2f)" % _stepped_apex())
	# THE LEVER AT THE TOP OF A JUMP, beside the deck's near lip. The eye
	# at the apex is 2.93 m, over a 2.9 m lip, and the lever stands two
	# metres in -- inside the 3 m interact probe. Pressed on every other
	# frame aloft, so whichever frame the probe clears the lip on is
	# tried; and the probe must have found the lever, or this proves
	# nothing.
	var found := 0
	var peak_eye := 0.0
	var prompt := ""
	if gantry != null:
		var plate_at := _part(gantry, "Plate").global_position
		var deck_at := _part(gantry, "Deck").global_position
		var away := Vector3(deck_at.x - plate_at.x, 0.0,
				deck_at.z - plate_at.z).normalized()
		var body := _player_at(Vector3(plate_at.x, floor_y, plate_at.z)
				- away * (Constants.PLAYER_RADIUS + 0.05))
		await _settle(20)
		_aim(body, control.global_position)
		Input.action_press("jump")
		for frame in 50:
			if frame == 3:
				Input.action_release("jump")
			_aim(body, control.global_position)
			if frame % 2 == 0:
				Input.action_press("interact")
			else:
				Input.action_release("interact")
			await get_tree().physics_frame
			peak_eye = maxf(peak_eye,
					body.camera.global_position.y - floor_y)
			if body.camera_ray(3.0).get("collider") == control:
				found += 1
				prompt = control.interact_prompt()
		Input.action_release("interact")
		Input.action_release("jump")
		await _drop(body)
	_check(gantry != null and found > 0 and not control.done,
		"at the top of a jump beside the lip (eye %.2f m) the probe finds "
			% peak_eye + "the lever on %d frame(s), and it does not move"
			% found)
	_check(found == 0 or prompt == "REACHED FROM THE GANTRY",
		"and what it says there is why: '%s'" % prompt)
	# THE LEVER FROM THE FLOOR: at the ground spot the old build used and
	# at the approach, aimed at the control.
	var arrival: Vector3 = (controller.room_places["c002"] as Dictionary)[
			"arrival"]
	var spots: Array[Vector3] = [arrival + GROUND_OFFSET.normalized()
			* (GROUND_OFFSET.length() - 1.5)]
	if gantry != null:
		spots.append(_approach(gantry, floor_y))
	var operated := false
	for spot: Vector3 in spots:
		var body := _player_at(spot)
		await _settle(20)
		_aim(body, control.global_position)
		await get_tree().physics_frame
		Input.action_press("interact")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("interact")
		await get_tree().physics_frame
		operated = operated or control.done
		await _drop(body)
	_check(not operated,
		"the base kit cannot operate the control from the floor")
	await _drop(controller)


# ------------------------------------------------------ the grapple

func _the_grapple_does_and_the_lever_starts_the_span() -> void:
	print("  -- THE PROVEN GRAPPLE REACHES IT, AND THE LEVER WORKS (played)")
	var controller := _built(_zone([_span()]))
	await _settle()
	var gantry := _gantry(controller)
	var junctions: Array = controller.rail_junctions()
	if gantry == null or junctions.is_empty():
		_check(false, "a gantry to grapple to (built: %s)"
				% (gantry != null))
		await _drop(controller)
		return
	var junction: RailJunction = junctions[0]
	var control: AlignmentControl = junction.controls()[0]
	var span: RailSpan = junction.spans()[0]
	var floor_y := _floor(controller)
	var plate := _part(gantry, "Plate") as StaticBody3D
	var body := _player_at(_approach(gantry, floor_y))
	await _settle(30)
	# THE SAME COMPONENT THE SCENARIO HANDS OVER, through `set_equipped`
	# -- the call a snapshot makes.
	var pull: EchoRuntime = body.runtimes["mobility"]
	pull.set_equipped(RailwayScenario.EchoGrant.COMPONENT)
	_aim(body, plate.global_position)
	await get_tree().physics_frame
	_check(body.camera_ray(25.0).get("collider") == plate,
		"the hookshot is aimed at the gantry's plate")
	var before := body.global_position.y
	Input.action_press("fire_mobility")
	var fired := false
	for _i in 4:
		await get_tree().physics_frame
		if pull.cooldown_remaining > 0.0:
			fired = true
			break
	Input.action_release("fire_mobility")
	_check(fired, "the mobility key fires the hookshot")
	Input.action_press("move_forward")
	var high := before
	for _i in 180:
		await get_tree().physics_frame
		high = maxf(high, body.global_position.y)
		if body.is_on_floor() and body.global_position.y > before + 2.0:
			break
	Input.action_release("move_forward")
	print("    pulled from %.2f m to %.2f m (peak %.2f), floor %.2f"
			% [before, body.global_position.y, high, floor_y])
	_check(body.is_on_floor()
			and body.global_position.y - floor_y > DECK_TOP - 0.5,
		"the pull puts the player on the deck (%.2f m up)"
			% (body.global_position.y - floor_y))
	_aim(body, control.global_position)
	for _i in 3:
		await get_tree().physics_frame
	_check(body.camera_ray(3.0).get("collider") == control,
		"the lever is in reach from the deck")
	_check(control.interact_prompt() == "[E] ALIGN S0",
		"and offered there: '%s'" % control.interact_prompt())
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().physics_frame
	_check(control.done and span.travelling,
		"and pulling it starts the span (done %s, travelling %s)"
			% [control.done, span.travelling])
	var fired_latch := []
	junction.latch_fired.connect(func(pkg: String, latch: String) -> void:
		fired_latch.append("%s/%s" % [pkg, latch]))
	for _i in int(RailSpan.TRAVEL_SECONDS * 60.0) + 30:
		await get_tree().physics_frame
		if not fired_latch.is_empty():
			break
	_check(fired_latch == ["yard/s0_latch"],
		"the span commissions under its declared latch %s" % [fired_latch])
	await _drop(body)
	await _drop(controller)


# ------------------------------------------------------ the control

func _a_ground_span_keeps_its_ground_lever() -> void:
	print("  -- A GROUND SPAN IS UNCHANGED")
	for placement: String in ["ground", ""]:
		var controller := _built(_zone([_span(placement)]))
		await _settle()
		var junctions: Array = controller.rail_junctions()
		var control: AlignmentControl = null
		if not junctions.is_empty() \
				and not (junctions[0] as RailJunction).controls().is_empty():
			control = (junctions[0] as RailJunction).controls()[0]
		var arrival: Vector3 = (controller.room_places["c002"]
				as Dictionary)["arrival"]
		_check(control != null and control.global_position.distance_to(
				arrival + GROUND_OFFSET) < 0.01
				and _gantry(controller) == null,
			"%s: the lever stands at the arrival, and no gantry"
				% ("'ground'" if placement != "" else "undeclared"))
		await _drop(controller)


# ------------------------------------------------------ the refusals

func _a_room_the_gantry_does_not_fit_is_refused() -> void:
	print("  -- A ROOM THE GANTRY DOES NOT FIT IS REFUSED BY NAME")
	var cases := [
		["a 5 m arena", _zone([_span()], 5.0), "the plate needs"],
		["an 8 x 8 arena", _zone([_span()], 8.0,
				{"width": 8.0, "depth": 8.0}), "outside the room"],
		["two gantries in c002", _zone([_span(),
				_span("gantry", "s1", "d1", "d2")]), "already holds"],
	]
	for case: Array in cases:
		var controller := _built(case[1])
		await _settle()
		var why := " / ".join(controller.rail_refusals)
		_check(controller.layout_failed == ""
				and controller.rail_refusals.size() == 1
				and why.contains(str(case[2]))
				and controller.rail_junctions().is_empty()
				and controller.rail_carriers().is_empty()
				and _gantry(controller) == null,
			"%s: refused by name, nothing built, the Zone still up -- %s"
				% [case[0], why if why != "" else "(not refused)"])
		await _drop(controller)


## THE MEASUREMENT, on its own. A surface the base kit reaches from
## which a jump lands on the deck is a stair by another name; the same
## surface with its step taken away is not.
func _a_step_to_the_deck_is_measured() -> void:
	print("  -- A STEP TO THE DECK IS MEASURED")
	if not _rn_has("gantry_frame") or not _rn_has("base_kit_bypass"):
		_check(false, "RailNetworks measures a gantry room (no "
				+ "gantry_frame / base_kit_bypass)")
		return
	var controller := _built(_zone([_span("ground")]))
	await _settle()
	var place: Dictionary = controller.room_places["c002"]
	var box: AABB = controller.room_bounds["c002"]
	var track: PackedVector3Array = (controller.rail_carriers()[0]
			as RailCarrier).path.polyline(0.5)
	var floor_y := _floor(controller)
	var frame: Dictionary = _rn.call("gantry_frame", controller, place,
			box, track)
	_check(not frame.has("refused"),
		"the bare arena takes a gantry: %s" % [frame.get("refused", "")])
	if frame.has("refused"):
		await _drop(controller)
		return
	var space := controller.get_world_3d().direct_space_state
	_check(str(_rn.call("base_kit_bypass", space, box, floor_y, frame))
			== "", "and the base kit cannot reach its deck")
	# A GALLERY 2 m UP, a metre past the deck's far edge, with a 1.38 m
	# step up to it from the floor: one the played jump (1.40 m) makes and
	# v^2/2g (1.33 m) says it cannot.
	var away: Vector3 = frame["away"]
	var deck: Vector3 = frame["deck_centre"]
	var far := Vector3(deck.x, floor_y, deck.z) + away * 2.0
	var gallery := _block(Vector3(3.0, 2.0, 2.0),
			far + away * 2.0 + Vector3.UP * 1.0, away)
	var step := _block(Vector3(3.0, 1.38, 1.4),
			far + away * 3.7 + Vector3.UP * 0.69, away)
	await _settle(3)
	var why := str(_rn.call("base_kit_bypass", space, box, floor_y, frame))
	_check(why.contains("a jump from a surface"),
		"a gallery the base kit climbs to, a metre from the deck, is "
			+ "refused: %s" % [why if why != "" else "(passed)"])
	var moved: Dictionary = _rn.call("gantry_frame", controller, place,
			box, track)
	_check(moved.has("refused") or (moved["deck_centre"] as Vector3)
			.distance_to(deck) > 1.0,
		"and the room does not put its gantry there: %s"
			% [moved.get("refused", "moved to %v" % moved.get(
				"deck_centre", Vector3.ZERO))])
	# THE CONTROL: the same block where it was, 1.3 m up -- still reached,
	# and a jump from it tops out under the deck.
	gallery.queue_free()
	var ledge := _block(Vector3(3.0, 1.3, 2.0),
			far + away * 2.0 + Vector3.UP * 0.65, away)
	await _settle(3)
	why = str(_rn.call("base_kit_bypass", space, box, floor_y, frame))
	_check(why == "",
		"the same block 1.3 m up is not -- a jump from it tops out at "
			+ "%.2f m (the control): %s" % [1.3 + _stepped_apex(),
				why if why != "" else "passed"])
	ledge.queue_free()
	step.queue_free()
	await _settle(3)
	# A CRATE IN THE COLUMN THE PULL CLIMBS: the gantry goes elsewhere.
	var crate := _block(Vector3(1.0, 1.0, 1.0),
			(frame["approach"] as Vector3) + away * 0.75 + Vector3.UP * 0.5,
			away)
	await _settle(3)
	moved = _rn.call("gantry_frame", controller, place, box, track)
	_check(moved.has("refused") or (moved["approach"] as Vector3)
			.distance_to(frame["approach"]) > 0.5,
		"a crate in the column the pull climbs moves the gantry: %s"
			% [moved.get("refused", "to %v" % moved.get("approach",
				Vector3.ZERO))])
	crate.queue_free()
	await _drop(controller)
	await _the_rules_on_a_bare_floor()


## THE RULES ON A BARE FLOOR. Rooms of their own with nothing in them
## the case did not put there, so the rule under test is the only thing
## that can decide it -- in the arena, a crate beside the stair or a
## position already off the track decided these instead.
func _the_rules_on_a_bare_floor() -> void:
	print("  -- THE RULES ON A BARE FLOOR")
	# THE FLOOR IT STANDS ON: two slabs with a 5 m gap between them, and
	# the arrival over the gap, so the nearest positions put the approach
	# or the post over nothing. The measured pull is from floor at the
	# arrival's height.
	var gap := Node3D.new()
	add_child(gap)
	for z: float in [-7.5, 7.5]:
		_floor_slab(gap, Vector3(24.0, 0.4, 10.0), Vector3(0.0, -0.2, z))
	await _settle(3)
	var gap_box := AABB(Vector3(-12.0, -1.0, -12.5), Vector3(24.0, 9.0, 25.0))
	# TO THE FIELD'S RESOLUTION: floor is known per 0.5 m cell, so a
	# point up to a quarter-metre past an edge counts -- and a body there
	# still stands on it (a capsule 0.25 m past an edge meets it at 37
	# degrees, inside the 45 of a floor).
	var over_gap := func(at: Vector3) -> bool: return absf(at.z) < 2.25
	var framed: Dictionary = _rn.call("gantry_frame", gap,
			{"arrival": Vector3.ZERO, "yaw": 0.0}, gap_box,
			PackedVector3Array())
	_check(not framed.has("refused")
			and not over_gap.call(framed["approach"])
			and not over_gap.call(framed["deck_centre"]),
		"across a gap in the floor, neither the approach nor the post "
			+ "stands over it: %s" % [framed.get("refused",
				"approach %v, deck %v" % [framed.get("approach"),
					framed.get("deck_centre")])])
	gap.queue_free()
	await _settle(2)
	# ONE FLOOR, NOTHING ON IT.
	var room := Node3D.new()
	add_child(room)
	_floor_slab(room, Vector3(24.0, 0.4, 24.0), Vector3(0.0, -0.2, 0.0))
	await _settle(3)
	var box := AABB(Vector3(-12.0, -1.0, -12.0), Vector3(24.0, 9.0, 24.0))
	var place := {"arrival": Vector3(0.0, 0.0, -9.0), "yaw": 0.0}
	var frame: Dictionary = _rn.call("gantry_frame", room, place, box,
			PackedVector3Array())
	_check(not frame.has("refused"),
		"a bare floor takes a gantry: %s" % [frame.get("refused", "")])
	if frame.has("refused"):
		room.queue_free()
		await _settle(2)
		return
	var away: Vector3 = frame["away"]
	var across := Vector3(-away.z, 0.0, away.x)
	var deck: Vector3 = frame["deck_centre"]
	# THE TRACK: a line straight through that deck, wall to wall. The
	# carrier's half-width and a rider's radius must clear the deck.
	var track := PackedVector3Array()
	for i in range(-48, 49):
		track.append(Vector3(deck.x, 0.6, deck.z) + across * (i * 0.25))
	var moved: Dictionary = _rn.call("gantry_frame", room, place, box, track)
	var clear := 1.7 + Constants.PLAYER_RADIUS
	var nearest := INF
	if not moved.has("refused"):
		var moved_away: Vector3 = moved["away"]
		var moved_across := Vector3(-moved_away.z, 0.0, moved_away.x)
		var moved_deck: Vector3 = moved["deck_centre"]
		for point: Vector3 in track:
			var rel := Vector3(point.x - moved_deck.x, 0.0,
					point.z - moved_deck.z)
			nearest = minf(nearest, Vector2(
					maxf(absf(rel.dot(moved_away)) - 2.0, 0.0),
					maxf(absf(rel.dot(moved_across)) - 2.0, 0.0)).length())
	_check(not moved.has("refused") and nearest >= clear,
		"a track through the chosen deck moves it off: the new deck is "
			+ "%.2f m from the track, the carrier needs %.2f" % [nearest,
				clear])
	# THE APEX: a gallery 2.0 m up a metre past the deck's far edge, and a
	# 1.38 m step up to it -- one the played jump (1.40 m) makes and
	# v^2/2g (1.33 m) says it cannot. Nothing else in the room to climb.
	var far := Vector3(deck.x, 0.0, deck.z) + away * 2.0
	var gallery := _block(Vector3(3.0, 2.0, 2.0),
			far + away * 2.0 + Vector3.UP * 1.0, away)
	var step := _block(Vector3(3.0, 1.38, 1.4),
			far + away * 3.7 + Vector3.UP * 0.69, away)
	await _settle(3)
	var space := room.get_world_3d().direct_space_state
	var why := str(_rn.call("base_kit_bypass", space, box, 0.0, frame))
	_check(why.contains("a jump from a surface"),
		"on a bare floor, a gallery up a 1.38 m step, a metre from the "
			+ "deck, is within the base kit's reach: %s"
			% [why if why != "" else "(passed)"])
	# THE CONTROL: the same gallery 1.3 m up; the step still reaches it
	# and a jump from it tops out under the deck.
	gallery.queue_free()
	var ledge := _block(Vector3(3.0, 1.3, 2.0),
			far + away * 2.0 + Vector3.UP * 0.65, away)
	await _settle(3)
	why = str(_rn.call("base_kit_bypass", space, box, 0.0, frame))
	_check(why == "",
		"and at 1.3 m it is not (the control): %s"
			% [why if why != "" else "passed"])
	ledge.queue_free()
	step.queue_free()
	room.queue_free()
	await _settle(2)


func _floor_slab(parent: Node3D, size: Vector3, centre: Vector3) -> void:
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	slab.add_child(shape)
	parent.add_child(slab)
	slab.global_position = centre


func _block(size: Vector3, centre: Vector3, away: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.transform = Transform3D(Basis.looking_at(away, Vector3.UP), centre)
	add_child(body)
	return body
