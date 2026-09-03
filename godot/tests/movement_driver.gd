extends Node
## P3.0: the large-room movement foundation, on ugly engineering fixtures.
##
## NOT AUTHORED ROOMS. Every shape here is bare boxes and bare paths,
## built to make one physical claim each. Art authors the first LARGE
## shell after this contract is true, not from these.

var failures := 0
## Vacuity guards: a suite that never rides and never refuses proves
## nothing about either.
var rides := 0
var refusals := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	await _run()

func _run() -> void:
	await get_tree().process_frame
	_test_a_rail_curves_in_plan_without_the_path_drifting()
	_test_a_rail_climbs_and_the_climb_costs_speed()
	_test_a_rail_descends_and_the_drop_pays_it_back()
	_test_a_rail_wraps_an_obstacle_through_several_levels()
	_test_a_rail_is_smooth_and_not_a_chain_of_corners()
	_test_a_smoothed_curve_may_not_leave_the_room()
	await _test_a_grapple_point_must_be_somewhere_you_could_hang()
	_test_a_walk_is_proven_by_geometry_not_by_rectangles()
	_test_a_room_may_descend_from_entry_to_exit()
	_test_a_rider_enters_only_on_terms_and_leaves_when_it_asks()
	_test_a_launch_crosses_horizontal_and_vertical_distance()
	await _test_a_launch_refuses_an_obstructed_arc()
	await _test_a_launch_refuses_a_landing_it_cannot_land_on()
	await _test_a_package_may_decline_every_offer()
	await _test_the_offer_binding_measures_real_geometry()
	await _test_a_launch_target_is_a_floor_point_not_a_body_point()
	await _test_a_placed_room_offers_exactly_what_it_offered_at_the_origin()
	await _test_a_placed_launch_lands_where_it_was_aimed()
	await _test_a_placed_rail_is_the_same_rail()
	await _test_a_launch_source_is_one_origin_not_a_disc()
	await _test_a_blocked_launch_origin_is_refused()
	await _test_a_placed_launch_captures_and_lands()
	await _test_the_corridor_rail_is_the_shape_it_always_was()
	_test_the_base_kit_alone_can_use_both()

	_check(rides >= 5,
			"only %d rides were driven; the ride loop is not being "
			% rides + "exercised")
	_check(refusals >= 5,
			"only %d refusals were seen; a suite that never watches "
			% refusals + "something be refused cannot be trusted")
	if failures == 0:
		print("GODOT MOVEMENT TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT MOVEMENT TESTS: %d failures" % failures)
		get_tree().quit(1)

# --- 1. a rail curves in plan ---------------------------------------------

func _test_a_rail_curves_in_plan_without_the_path_drifting() -> void:
	"""A right-angle turn, ridden around rather than cut across.

	The old rail could not do this and never claimed to: two points on
	one axis. What is being proved is not that a curve can be STORED --
	an array can do that -- but that the shape the rider follows is the
	shape the mesh is swept along, at every step of the way round."""
	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 1, 10), Vector3(10, 1, 10)]))
	_check(rail.violations().is_empty(),
			"a right-angle rail was refused: %s"
			% "; ".join(rail.violations()))
	# LONGER THAN THE CHORDS, and it must be: rounding a corner is a
	# longer path than turning on a point. Bounded above so "smooth"
	# can never quietly become "wanders".
	_check(rail.length() > 20.0 and rail.length() < 22.0,
			"a 10 + 10 m rail rounded to %.2f m; a smooth corner is a "
			% rail.length() + "little longer than 20 m, not much")
	# Ridden, and every step checked against the PATH rather than against
	# the chord: a rider that cut the corner would leave the polyline.
	var rider := _ride_from(rail, Vector3(0, 2, 0), Vector3(0, 0, 9.0))
	var wandered := 0.0
	for i in 400:
		var step := rider.advance(1.0 / 60.0)
		var body: Vector3 = step["position"]
		var foot := body - Vector3.UP * RailRider.STAND_OFFSET
		wandered = maxf(wandered, _off_polyline(foot, rail.polyline()))
		if not bool(step["riding"]):
			break
	_check(wandered < AffordanceFeatures.RAIL_BEAM_THICKNESS / 2.0,
			"the ride drifted %.3f m off the BAKED curve the beam is "
			% wandered + "swept along, past its %.3f m half-thickness"
			% (AffordanceFeatures.RAIL_BEAM_THICKNESS / 2.0))
	# AND IT IS A CURVE. A right angle taken smoothly has to leave the
	# chord; zero here would mean two straight legs and a corner, which
	# is the thing P3.5 was asked to fix.
	var bowed := 0.0
	for point: Vector3 in rail.polyline():
		bowed = maxf(bowed, _off_polyline(point, rail.segments()))
	_check(bowed > 0.2,
			"the rail bows only %.3f m off its control polyline; a "
			% bowed + "right-angle turn taken smoothly cannot hug the "
			+ "corner that closely")

	rides += 1

# --- 2 and 3. climbing and descending -------------------------------------

func _test_a_rail_climbs_and_the_climb_costs_speed() -> void:
	"""Significant height, and the climb is paid for.

	A rail that carried the player up at a constant speed would be a
	lift, and a lift is the cutscene this slice is told not to build. So
	the claim is BOTH: the height is really gained, and the speed really
	falls on the way."""
	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 13, 24)]))
	_check(rail.violations().is_empty(),
			"a climbing rail was refused: %s"
			% "; ".join(rail.violations()))
	var rider := _ride_from(rail, Vector3(0, 2, 0), Vector3(0, 0, 20.0))
	var entered := rider.speed
	var top := -INF
	var reason := ""
	for i in 900:
		var step := rider.advance(1.0 / 60.0)
		top = maxf(top, (step["position"] as Vector3).y)
		if not bool(step["riding"]):
			reason = str(step["reason"])
			break
	_check(top > 12.0,
			"a rail 12 m tall carried the player only to y=%.2f" % top)
	_check(reason == "end",
			"the climb ended as '%s' rather than reaching the top"
			% reason)
	_check(rider.speed < entered,
			"climbing 12 m cost nothing: entered at %.2f, arrived at %.2f"
			% [entered, rider.speed])
	rides += 1

	# THE FLOOR OF THE DRIVE, on the steepest rail the contract allows.
	# This is the assertion that makes "every legal rail is completable"
	# true by construction rather than by hoping about numbers -- and it
	# is what the base-kit progression proof rests on.
	var run := 8.0
	var steep := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 1 + run * tan(deg_to_rad(
			RailPath.MAX_PITCH_DEGREES - 0.5)), run)]))
	_check(steep.violations().is_empty(),
			"a rail just inside the pitch limit was refused: %s"
			% "; ".join(steep.violations()))
	var crawler := _ride_from(steep, Vector3(0, 2, 0),
			Vector3(0, 0, 2.0))
	var lowest := INF
	var got := ""
	for i in 3000:
		var step := crawler.advance(1.0 / 60.0)
		lowest = minf(lowest, crawler.speed)
		if not bool(step["riding"]):
			got = str(step["reason"])
			break
	_check(got == "end",
			"the steepest legal rail ended as '%s'; a rail the contract "
			% got + "accepts must be one the drive can finish")
	_check(lowest >= RailRider.MIN_SPEED - 0.001,
			"the steepest legal climb fell to %.2f m/s, under the %.2f "
			% [lowest, RailRider.MIN_SPEED] + "floor the drive claims")
	rides += 1

func _test_a_rail_descends_and_the_drop_pays_it_back() -> void:
	"""The same rail the other way: a descent should return speed."""
	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(0, 13, 0), Vector3(0, 1, 24)]))
	var rider := _ride_from(rail, Vector3(0, 14, 0), Vector3(0, 0, 7.0))
	var entered := rider.speed
	var bottom := INF
	for i in 600:
		var step := rider.advance(1.0 / 60.0)
		bottom = minf(bottom, (step["position"] as Vector3).y)
		if not bool(step["riding"]):
			break
	_check(rider.speed > entered,
			"a 12 m descent returned nothing: entered at %.2f, left at "
			% entered + "%.2f" % rider.speed)
	_check(rider.speed <= RailRider.MAX_SPEED + 0.001,
			"a descent ran away to %.2f m/s, past the %.2f cap"
			% [rider.speed, RailRider.MAX_SPEED])
	_check(bottom < 3.0,
			"the descent bottomed out at y=%.2f" % bottom)
	rides += 1

	# MOMENTUM STILL MATTERS. The drive is a floor, not a governor: two
	# riders on one rail, one arriving at a sprint, and the fast one has
	# to get there first or the rail is a conveyor belt.
	var flat := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 1, 40)]))
	_check(_seconds_to_ride(flat, 20.0) < _seconds_to_ride(flat, 2.0)
			- 0.05,
			"arriving at a sprint (%.2f s) was no faster than strolling "
			% _seconds_to_ride(flat, 20.0) + "on (%.2f s)"
			% _seconds_to_ride(flat, 2.0))

# --- 4. wrapping an obstacle ----------------------------------------------

func _test_a_rail_wraps_an_obstacle_through_several_levels() -> void:
	"""A helix around a column, climbing two storeys.

	The shape the owner asked for and the one the old rail was furthest
	from. The drift check is the real assertion: a helical path sampled
	one way for the mesh and another for the ride would show up here as
	the rider leaving the beam on the corners."""
	var points := PackedVector3Array()
	var turns := 2
	var per_turn := 8
	for i in turns * per_turn + 1:
		var t := float(i) / float(per_turn)
		points.append(Vector3(cos(t * TAU) * 6.0, 1.0 + t * 5.0,
				sin(t * TAU) * 6.0))
	var rail := RailPath.from_points(points)
	_check(rail.violations().is_empty(),
			"a helical rail was refused: %s" % "; ".join(rail.violations()))
	_check(rail.length() > 60.0,
			"a two-turn helix measured only %.1f m" % rail.length())
	var rider := _ride_from(rail, points[0] + Vector3.UP,
			(points[1] - points[0]).normalized() * 14.0)
	var wandered := 0.0
	var climbed := points[0].y
	for i in 900:
		var step := rider.advance(1.0 / 60.0)
		var foot := (step["position"] as Vector3) \
				- Vector3.UP * RailRider.STAND_OFFSET
		wandered = maxf(wandered, _off_polyline(foot, rail.polyline()))
		climbed = maxf(climbed, foot.y)
		if not bool(step["riding"]):
			break
	# The rider is never off the beam the player can see, which is the
	# only version of this a player could ever notice.
	_check(wandered < AffordanceFeatures.RAIL_BEAM_THICKNESS / 2.0,
			"the helix ride drifted %.3f m off the baked curve, past "
			% wandered + "the %.3f m half-thickness of its beam"
			% (AffordanceFeatures.RAIL_BEAM_THICKNESS / 2.0))
	_check(climbed > 4.0,
			"wrapping the column reached only y=%.2f" % climbed)
	rides += 1

# --- 5. entry and exit ----------------------------------------------------


## --- the rail is a curve, measured rather than eyeballed (P3.5) --------

## The most a smooth rail may turn between two baked samples. A polyline
## turns its whole corner in one step and goes perfectly straight in
## between; a curve spreads the same turning over every sample.
const A_SMOOTH_STEP := 6.0

func _test_a_rail_is_smooth_and_not_a_chain_of_corners() -> void:
	"""SMOOTH, proven by WHERE the turning is rather than by how it looks.

	The distinction that matters is not "does the route bend" -- a
	polyline bends -- but "does it bend all at once". So the measurement
	is the angle between consecutive baked tangents: on a chain of
	straight segments that is a few huge spikes among zeros, and on a
	spline it is small and everywhere. A rail faked smooth by dense
	hand-authoring would still show the spikes.

	Run on `rail_helix`\'s own control points, read out of the shipped
	manifest, so what is proven is the route Art actually authored rather
	than a fixture chosen to flatter the implementation."""
	var points := _helix_control_points()
	# LOUD, not a silent return: an early exit here is how this test
	# spent its first run proving nothing at all.
	_check(points.size() >= 3,
			"the hall's rail_route gave %d control points; there is "
			% points.size() + "nothing to measure")
	if points.size() < 3:
		return
	var rail := RailPath.from_points(points)
	_check(rail.violations().is_empty(),
			"the authored helix route was refused: %s"
			% "; ".join(rail.violations()))

	var walked := rail.polyline()
	var worst := 0.0
	var total := 0.0
	var spikes := 0
	for i in walked.size() - 2:
		var a := (walked[i + 1] - walked[i]).normalized()
		var b := (walked[i + 2] - walked[i + 1]).normalized()
		var turn := rad_to_deg(a.angle_to(b))
		worst = maxf(worst, turn)
		total += turn
		if turn > A_SMOOTH_STEP:
			spikes += 1
	# THE BEFORE PICTURE: the same points as straight segments, which is
	# what this rail used to be. It has to fail the test the curve
	# passes, or the test is measuring nothing.
	var chord_worst := 0.0
	for i in points.size() - 2:
		var a := (points[i + 1] - points[i]).normalized()
		var b := (points[i + 2] - points[i + 1]).normalized()
		chord_worst = maxf(chord_worst, rad_to_deg(a.angle_to(b)))
	print("   rail_helix: worst baked turn %.2f deg over %d samples; the "
			% [worst, walked.size()]
			+ "same points as segments turn %.1f deg per corner"
			% chord_worst)
	_check(worst <= A_SMOOTH_STEP,
			"the sharpest turn between two baked samples is %.1f deg; a "
			% worst + "curve spreads its turning (%d sample(s) over %.0f)"
			% [spikes, A_SMOOTH_STEP])
	_check(total > 200.0,
			"the route turns only %.0f deg in total, so this fixture is "
			% total + "not exercising a helix")
	_check(chord_worst > A_SMOOTH_STEP * 3.0,
			"the control polyline turns at most %.1f deg per corner, so "
			% chord_worst + "it was already smooth and this proves "
			+ "nothing")

	# The curve leaves the chord -- that IS the smoothing -- but never by
	# more than the contract allows, which keeps a smoothed rail inside
	# the corridor its author cleared for it.
	var bowed := 0.0
	for point: Vector3 in walked:
		bowed = maxf(bowed, _off_polyline(point, points))
	_check(bowed > 0.05,
			"the helix sits %.3f m from its control polyline; it has "
			% bowed + "not been smoothed at all")
	print('   rail_helix bows %.2f m off its control polyline' % bowed)

	# DETERMINISTIC: the same points bake the same curve, every time.
	var again := RailPath.from_points(points).polyline()
	_check(walked.size() == again.size(),
			"the same route baked %d samples once and %d the next time"
			% [walked.size(), again.size()])
	var moved := 0.0
	for i in mini(walked.size(), again.size()):
		moved = maxf(moved, walked[i].distance_to(again[i]))
	_check(moved == 0.0,
			"the same route baked to a different curve, by %.6f m" % moved)

## `rail_helix` as `shell_hall_transit` declares it.
func _helix_control_points() -> PackedVector3Array:
	var registry := ContentRegistry.new()
	registry.load_all()
	var entry := registry.get_entry("shell_hall_transit")
	for raw: Variant in entry.get("offers", []):
		var offer: Dictionary = raw
		if str(offer.get("kind", "")) != "rail_route":
			continue
		# THE MANIFEST IS JSON: a route's points arrive as arrays of
		# numbers, and casting one to Vector3 fails silently enough that
		# this whole test returned an empty list and passed on nothing
		# until it was caught.
		var out := PackedVector3Array()
		for point: Variant in offer.get("points", []):
			var xyz: Array = point
			out.append(Vector3(float(xyz[0]), float(xyz[1]),
					float(xyz[2])))
		return out
	_check(false, "the hall declares no rail_route to measure")
	return PackedVector3Array()


func _test_a_smoothed_curve_may_not_leave_the_room() -> void:
	"""Smoothing is not a licence to bow through a wall.

	Catmull-Rom overshoots on a sharp turn, so a route whose control
	points all sit safely inside the room can produce a CURVE that does
	not. That is the failure interpolation introduces and the reason
	containment is measured on the baked samples rather than on the
	points -- validating the points while letting the curve go anywhere
	is exactly the hole this closes."""
	# Control points just inside the envelope, and a zig-zag sharp enough
	# that the smoothing overshoots past it.
	var hugging := PackedVector3Array([
		Vector3(-5.4, 2, -5.4), Vector3(5.4, 2, -5.4),
		Vector3(-5.4, 2, 5.4), Vector3(5.4, 2, 5.4)])
	var rail := RailPath.from_points(hugging)
	var room := AABB(Vector3(-5.5, 0, -5.5), Vector3(11, 8, 11))
	_check(rail.violations("shape").is_empty(),
			"the zig-zag is a legal SHAPE and was refused on shape: %s"
			% "; ".join(rail.violations("shape")))
	var caged := rail.violations("caged", room)
	_check(not caged.is_empty(),
			"a curve that bows %.2f m off a route hugging the wall "
			% rail.bow() + "stayed inside a %v room" % room.size)
	_check("; ".join(caged).contains("envelope"),
			"the refusal must name the envelope: %s" % "; ".join(caged))
	refusals += 1
	# THE CONTROL POINTS ARE ALL INSIDE, which is the whole point: the
	# old shape-only check would have passed this.
	for point: Vector3 in hugging:
		_check(RoomContract.envelope(room).has_point(point),
				"the fixture's own control point %v is outside the room, "
				% point + "so this proves nothing about smoothing")
	# A gentler route through the same room is not refused.
	var inside := RailPath.from_points(PackedVector3Array([
		Vector3(-2, 2, -2), Vector3(0, 2, 0), Vector3(2, 2, 2)]))
	_check(inside.violations("inside", room).is_empty(),
			"a curve well inside the room was refused: %s"
			% "; ".join(inside.violations("inside", room)))

## A room of real colliders, validated through the PRODUCTION caller.
##
## `boxes` is `[[centre, size], ...]`. The root goes into the tree and a
## physics frame is awaited before anything is asked, because a body the
## physics server has not registered yet answers every probe with
## "nothing there" -- the vacuous pass this whole binding exists to
## remove. `OfferBinding.validate` is the same entry point
## `ZoneController` uses, so what these tests exercise is production
## code rather than a harness that resembles it.
func _offer_verdict(room: Dictionary, boxes: Array,
		only: Array = ["grapple_point"],
		place := Transform3D.IDENTITY) -> Dictionary:
	var root := Node3D.new()
	root.transform = place
	for b: Array in boxes:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		shape.shape = box
		body.add_child(shape)
		body.position = b[0]
		if b.size() > 2:
			body.name = str(b[2])
		root.add_child(body)
	add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var verdict := OfferBinding.validate(root, room, "probe", only)
	root.queue_free()
	await get_tree().process_frame
	return verdict

# --- the real-geometry offer binding (owner ruling, 2026-09-03) ------------

# --- the room-local / world seam (owner ruling, 2026-09-03) ----------------

## THE PLACEMENTS a room actually gets. `ZoneBuilder` translates every
## chamber and yaws many of them, so identity is the ONE case that cannot
## detect a frame error -- and it was the only case the first binding was
## ever tested at.
func _placements() -> Array:
	return [
		["identity", Transform3D.IDENTITY],
		["translated X/Z", Transform3D(Basis(),
			Vector3(137.0, 0.0, -84.0))],
		["translated Y", Transform3D(Basis(), Vector3(0.0, 61.0, 0.0))],
		["yaw 90", Transform3D(Basis(Vector3.UP, PI / 2.0),
			Vector3(12.0, 3.0, -40.0))],
		["yaw 180", Transform3D(Basis(Vector3.UP, PI),
			Vector3(-55.0, -7.0, 18.0))],
		["yaw 270", Transform3D(Basis(Vector3.UP, 3.0 * PI / 2.0),
			Vector3(9.0, 22.0, 71.0))],
	]

func _test_a_placed_room_offers_exactly_what_it_offered_at_the_origin(
		) -> void:
	"""AUTHORED LOCAL, PHYSICS WORLD, AND THE TWO ARE NOT THE SAME PLACE.

	`ZoneBuilder` keeps offer coordinates room-local and then places each
	chamber at a nonzero translation and yaw; `PhysicsDirectSpaceState3D`
	is world space. The first binding handed local points straight to the
	probe, and every authored-shell test placed its root at identity --
	the one transform where the two frames coincide. A fixture at the
	origin cannot see an origin bug.

	Translating or rotating a room may not change what it offers."""
	var floor_box := [Vector3(0, -0.5, 0), Vector3(60, 1, 60), "basin"]
	var ledge := [Vector3(0, 15.5, 0), Vector3(6, 1, 6), "shelf"]
	var real := {"offers": [{"kind": "grapple_point", "name": "good",
			"position": Vector3(4, 9, -6), "radius": 1.5}]}
	# The same anchor with a ledge in its swing column: a DECLINE has to
	# survive placement too, or a frame error could hide a real defect
	# instead of inventing one.
	var bad := {"offers": [{"kind": "grapple_point", "name": "cramped",
			"position": Vector3(0, 18, 0), "radius": 1.5}]}

	for entry: Array in _placements():
		var named: String = entry[0]
		var place: Transform3D = entry[1]
		var yes: Dictionary = await _offer_verdict(real, [floor_box],
				["grapple_point"], place)
		_check((yes["built"] as Array).size() == 1,
				"at %s a real anchor was declined: %s"
				% [named, str(yes["declined"])])
		var no: Dictionary = await _offer_verdict(bad,
				[floor_box, ledge], ["grapple_point"], place)
		_check((no["built"] as Array).is_empty(),
				"at %s an anchor with a ledge in its swing column was "
				% named + "accepted")
		# THE DIAGNOSTIC STILL NAMES THE ROOM'S OWN COLLIDER. A reason
		# that cannot name what blocked it sends whoever fixes it
		# looking, and a world coordinate in a local room is worse than
		# no coordinate at all.
		_check(str(no["declined"]).contains("shelf"),
				"at %s the refusal stopped naming the blocking collider: "
				% named + "%s" % str(no["declined"]))
	refusals += 1

	# A NESTED TRANSFORMED PARENT: `global_transform` is the whole chain,
	# not this node's own `transform`, and reading the wrong one is the
	# same bug one level up.
	var outer := Node3D.new()
	outer.transform = Transform3D(Basis(Vector3.UP, PI / 3.0),
			Vector3(-22.0, 14.0, 33.0))
	add_child(outer)
	var inner := Node3D.new()
	inner.transform = Transform3D(Basis(Vector3.UP, PI / 6.0),
			Vector3(5.0, -2.0, 8.0))
	outer.add_child(inner)
	for b: Array in [floor_box]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		shape.shape = box
		body.add_child(shape)
		body.position = b[0]
		body.name = str(b[2])
		inner.add_child(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nested := OfferBinding.validate(inner, real, "nested",
			["grapple_point"])
	_check((nested["built"] as Array).size() == 1,
			"under a nested transformed parent a real anchor was "
			+ "declined: %s" % str(nested["declined"]))
	outer.queue_free()
	await get_tree().process_frame

func _test_a_placed_launch_lands_where_it_was_aimed() -> void:
	"""The pad solved from a GLOBAL source to a ROOM-LOCAL target, so
	every pad in a placed Zone aimed at a point its room does not
	contain. Both ends are authored local; the trajectory is world."""
	var place := Transform3D(Basis(Vector3.UP, PI / 2.0),
			Vector3(40.0, 6.0, -18.0))
	var room := Node3D.new()
	room.transform = place
	add_child(room)
	var deck := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 12)
	shape.shape = box
	deck.add_child(shape)
	deck.position = Vector3(10, -0.5, 0)
	deck.name = "deck"
	room.add_child(deck)
	var pad := AffordanceNodes.LaunchPad.new()
	pad.position = Vector3(0, 0, 0)
	pad.target = Vector3(20, 0, 0)
	room.add_child(pad)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var shot := pad.solve()
	_check(bool(shot.get("ok", false)),
			"a placed pad could not solve its own launch")
	# THE WORLD VELOCITY MUST REACH THE WORLD TARGET. Integrated through
	# the same arc the pips draw, so the picture and the physics cannot
	# disagree either.
	var flight := LaunchSolver.arc(SpaceProbe.stand_pose(
			pad.global_position), shot["velocity"] as Vector3,
			float(shot["time"]))
	var landed: Vector3 = flight[flight.size() - 1]
	# COMPUTED HERE, NOT ASKED OF THE PAD. If the assertion read
	# `pad.world_target()` it would agree with a pad that transforms
	# nothing, because both sides would be wrong together.
	var wanted := SpaceProbe.stand_pose(place * pad.target)
	_check(landed.distance_to(wanted) < 0.05,
			"a placed launch ends at %v, not the %v its target "
			% [landed, wanted] + "transforms to (out by %.2f m)"
			% landed.distance_to(wanted))
	_check(pad.world_target().distance_to(wanted) < 0.001,
			"the pad's own world target is %v, not the %v its room "
			% [pad.world_target(), wanted] + "places it at")
	# ... and the target really did move, or this proves nothing.
	_check(wanted.distance_to(SpaceProbe.stand_pose(pad.target)) > 1.0,
			"the fixture's placement does not move the target, so this "
			+ "case cannot detect an untransformed one")
	# The pips are parented to the pad, so they must be pad-local.
	var pips := 0
	for child in pad.get_children():
		if child is MeshInstance3D and child.name.begins_with("@"):
			pips += 1
	_check(pips > 0, "a solvable placed pad drew no arc pips")
	room.queue_free()
	await get_tree().process_frame

func _test_a_placed_rail_is_the_same_rail() -> void:
	"""The rider compared the player's WORLD position against a
	room-local path and then handed local path positions back as world
	player positions -- so a placed rail was catchable from across the
	map and teleported whoever caught it.

	One authored path. A derived transform. Same semantic rail."""
	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(0, 2, 0), Vector3(0, 2, 6), Vector3(0, 2, 12)]))
	_check(rail.violations().is_empty(),
			"the rail fixture is not a valid path: %s"
			% "; ".join(rail.violations()))
	for entry: Array in _placements():
		var named: String = entry[0]
		var place: Transform3D = entry[1]
		# The player arrives in WORLD, on the placed curve, moving along
		# the placed tangent.
		var local_at := Vector3(0, 2, 4)
		var world_at := place * local_at
		var world_go := place.basis * Vector3(0, 0, 8)
		var caught := RailRider.catch(rail, world_at, world_go, place)
		_check(not caught.is_empty(),
				"at %s a rider on the placed curve could not catch it"
				% named)
		if caught.is_empty():
			continue
		var rider: RailRider = caught["rider"]
		# WORLD OUT. The body sits over the placed curve, not over the
		# authored one.
		var body := rider.body_position()
		var expect := place * (rail.at(rider.offset)
				+ Vector3.UP * RailRider.STAND_OFFSET)
		_check(body.distance_to(expect) < 0.001,
				"at %s the rider's body came back at %v, not the %v "
				% [named, body, expect] + "the placed curve puts it at")
		# And the ride advances along the PLACED direction.
		var step := rider.advance(0.1)
		var went: Vector3 = step["velocity"]
		var want_dir := (place.basis * Vector3(0, 0, 1)).normalized()
		_check(went.normalized().dot(want_dir) > 0.99,
				"at %s the ride pushed %v, which is not along the "
				% [named, went.normalized()] + "placed rail %v"
				% want_dir)
		# A rider standing where the AUTHORED curve is, rather than where
		# the placed one is, must NOT catch it -- otherwise the frame is
		# still being ignored.
		if named != "identity":
			var wrong := RailRider.catch(rail, local_at,
					Vector3(0, 0, 8), place)
			_check(wrong.is_empty(),
					"at %s a rider at the AUTHORED coordinates caught a "
					% named + "rail that is no longer there")
	refusals += 1

# --- the launch-source contract (owner ruling, 2026-09-03) -----------------

## A live pad over real floor, with a real Player, in a placed room.
func _launch_rig(place := Transform3D.IDENTITY,
		source := Vector3.ZERO, aim := Vector3(20, 0, 0),
		extra: Array = []) -> Dictionary:
	var room := Node3D.new()
	room.transform = place
	add_child(room)
	for b: Array in ([[Vector3(10, -0.5, 0), Vector3(60, 1, 12), "deck"]]
			+ extra):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		shape.shape = box
		body.add_child(shape)
		body.position = b[0]
		body.name = str(b[2])
		room.add_child(body)
	var pad := AffordanceNodes.LaunchPad.new()
	pad.position = source
	pad.target = aim
	room.add_child(pad)
	var player := Player.create()
	player.input_frozen = true
	add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return {"room": room, "pad": pad, "player": player}

## Where a ballistic launch from `pad` actually ends up.
func _flight_end(pad: AffordanceNodes.LaunchPad, from: Vector3,
		shot: Dictionary) -> Vector3:
	var points := LaunchSolver.arc(from, shot["velocity"] as Vector3,
			float(shot["time"]))
	return points[points.size() - 1]

func _test_a_launch_source_is_one_origin_not_a_disc() -> void:
	"""`launch_source.position` IS the launch origin; `radius` is the
	floor RESERVED for the mechanism.

	The runtime derived its velocity from the pad centre and applied it
	to whoever was overlapping the trigger, so a player clipping the edge
	of a 2.4 m pad flew a trajectory beginning up to 1.2 m from the one
	Production validated -- and landed somewhere nobody checked. The
	runtime launch has to BE the validated launch."""
	var rig: Dictionary = await _launch_rig()
	var pad: AffordanceNodes.LaunchPad = rig["pad"]
	var player: Player = rig["player"]
	var shot := pad.solve()
	_check(bool(shot.get("ok", false)), "the rig's pad cannot solve")

	# 1 + 4 -- THE CANONICAL ORIGIN, and the centre case flying it.
	var canonical := SpaceProbe.stand_pose(pad.global_position)
	# COUNTED AS A DELTA. The player is created at the origin, which is
	# inside the pad's own trigger, so `body_entered` has already fired
	# one launch before the test does anything -- and an assertion that
	# assumes a count of zero is measuring the fixture, not the pad.
	player.global_position = canonical
	var fired := pad.launched
	pad.launch(player)
	_check(pad.launched == fired + 1, "a centred player was not launched")
	var centred := _flight_end(pad, canonical, shot)
	_check(centred.distance_to(pad.world_target()) < 0.05,
			"a centred launch ended at %v, not its target %v"
			% [centred, pad.world_target()])

	# 5 -- EVERY EDGE AND CORNER OF THE PAD, captured to the same origin.
	var half: float = AffordanceNodes.LaunchPad.PAD_SIZE.x / 2.0 - 0.05
	var offsets: Array = []
	for dx: float in [-half, 0.0, half]:
		for dz: float in [-half, 0.0, half]:
			offsets.append(Vector3(dx, 0.0, dz))
	for off: Vector3 in offsets:
		player.global_position = canonical + off
		var before := pad.launched
		pad.launch(player)
		_check(pad.launched == before + 1,
				"a player entering at %v was not launched" % off)
		# CAPTURED: the body is at the canonical origin, whatever edge it
		# came in from.
		_check(player.global_position.distance_to(canonical) < 0.001,
				"a player entering at %v launched from %v, not the "
				% [off, player.global_position]
				+ "canonical origin %v" % canonical)
		# ... and therefore flies the validated arc and lands on target.
		var landed := _flight_end(pad, player.global_position,
				{"velocity": player.velocity, "time": shot["time"]})
		_check(landed.distance_to(pad.world_target()) < 0.05,
				"entering at %v landed at %v, not the target %v"
				% [off, landed, pad.world_target()])

	# 2 -- THE RADIUS IS NOT A FAMILY OF ORIGINS. Exactly one trajectory
	# is validated, and it is the one from `position`.
	var probe := OfferBinding.space_of(rig["room"] as Node3D)
	var one := LaunchSolver.violations(Vector3.ZERO, Vector3(20, 0, 0),
			3.0, probe, (rig["room"] as Node3D).global_transform,
			"reservation", 3.0)
	_check(one.is_empty(),
			"the canonical pair was refused: %s" % "; ".join(one))
	# 3 -- and the reservation must hold what gets built in it.
	var cramped := LaunchSolver.violations(Vector3.ZERO,
			Vector3(20, 0, 0), 3.0, probe,
			(rig["room"] as Node3D).global_transform, "cramped", 1.0)
	_check("; ".join(cramped).contains("cannot hold the launch pad"),
			"a reservation too small for its own pad was accepted: %s"
			% "; ".join(cramped))
	refusals += 1
	(rig["room"] as Node3D).queue_free()
	player.queue_free()
	await get_tree().process_frame

func _test_a_blocked_launch_origin_is_refused() -> void:
	"""7 -- capture is a teleport, and a teleport into geometry is worse
	than the offset it replaces. A canonical origin that cannot hold a
	body refuses to fire rather than burying the player in a wall."""
	# A block filling the pad's own standing pose.
	var rig: Dictionary = await _launch_rig(Transform3D.IDENTITY,
			Vector3.ZERO, Vector3(20, 0, 0),
			[[Vector3(0, 1.2, 0), Vector3(3, 2, 3), "lid"]])
	var pad: AffordanceNodes.LaunchPad = rig["pad"]
	var player: Player = rig["player"]
	_check(not pad.origin_is_clear(player),
			"a canonical origin filled with solid geometry reported "
			+ "itself clear")
	player.global_position = Vector3(0, 6, 0)
	var fired := pad.launched
	pad.launch(player)
	_check(pad.launched == fired,
			"a pad whose origin cannot hold a body still fired")
	# And the validator refuses the same pair, for the same reason.
	var says := LaunchSolver.violations(Vector3.ZERO, Vector3(20, 0, 0),
			3.0, OfferBinding.space_of(rig["room"] as Node3D),
			Transform3D.IDENTITY, "blocked", 3.0)
	_check("; ".join(says).contains("launch source"),
			"the validator accepted a source nobody can stand on: %s"
			% "; ".join(says))
	refusals += 1
	(rig["room"] as Node3D).queue_free()
	player.queue_free()
	await get_tree().process_frame

func _test_a_placed_launch_captures_and_lands() -> void:
	"""8 -- source and target stay correct under translation, vertical
	translation, yaw, and a nested transform. The runtime capture uses
	the same world poses the validator did."""
	var places: Array = _placements() + [["nested", Transform3D(
		Basis(Vector3.UP, PI / 3.0), Vector3(-30.0, 11.0, 44.0))]]
	for entry: Array in places:
		var named: String = entry[0]
		var place: Transform3D = entry[1]
		var rig: Dictionary = await _launch_rig(place)
		var pad: AffordanceNodes.LaunchPad = rig["pad"]
		var player: Player = rig["player"]
		var shot := pad.solve()
		_check(bool(shot.get("ok", false)),
				"at %s a placed pad could not solve" % named)
		# The player arrives off-centre, in world.
		player.global_position = SpaceProbe.stand_pose(pad.global_position) \
				+ place.basis * Vector3(1.1, 0.0, 1.1)
		var fired := pad.launched
		pad.launch(player)
		_check(pad.launched == fired + 1,
				"at %s a placed pad did not fire" % named)
		var canonical := SpaceProbe.stand_pose(pad.global_position)
		_check(player.global_position.distance_to(canonical) < 0.001,
				"at %s the player launched from %v, not the canonical "
				% [named, player.global_position] + "%v" % canonical)
		var wanted := SpaceProbe.stand_pose(place * pad.target)
		var landed := _flight_end(pad, player.global_position,
				{"velocity": player.velocity, "time": shot["time"]})
		_check(landed.distance_to(wanted) < 0.05,
				"at %s the flight ended at %v, not the %v its target "
				% [named, landed, wanted] + "transforms to")
		(rig["room"] as Node3D).queue_free()
		player.queue_free()
		await get_tree().process_frame

## THE SEVEN SABOTAGES the independent audit required, each of which must
## fail if the guard it names is removed.
##
## Vera's finding in one sentence: `MovementPackage` had eight call sites
## and every one passed a constant, so no offer verdict on record had
## ever seen a collider. Two consequences followed from the 2 m stride,
## and they had different causes -- 186 false refusals from blind bands
## between samples, and 49 to 81 false acceptances from windows reaching
## past both bounds. These pin the fix in both directions.
func _test_the_offer_binding_measures_real_geometry() -> void:
	"""Every case here is a collider, not a predicate."""
	var floor_box := [Vector3(0, -0.5, 0), Vector3(200, 1, 200), "basin"]

	# V1 -- THE OLD STRIDE FALSELY REFUSED REAL ANCHORS. The span's three
	# anchors sit at y=11.4 over a basin floor at y=0. The stride sampled
	# at drop 4, 6, 8, 10, 12 -- query heights 7.4, 5.4, 3.4, 1.4, -0.6 --
	# and a 1.5 m window at 1.4 sees [0.20, 1.70] while the next sees
	# [-1.80, -0.30]. The floor at 0.000 fell in the gap. Replayed here
	# against real geometry: the stride refuses, the continuous
	# measurement accepts.
	var span_room := {"offers": [
		{"kind": "grapple_point", "name": "a", "position":
			Vector3(-9, 11.4, 22), "radius": 1.5},
		{"kind": "grapple_point", "name": "b", "position":
			Vector3(8, 11.4, 44), "radius": 1.5},
		{"kind": "grapple_point", "name": "c", "position":
			Vector3(-7, 11.4, 66), "radius": 1.5},
	]}
	var span: Dictionary = await _offer_verdict(span_room, [floor_box])
	_check((span["built"] as Array).size() == 3,
			"V1: three real anchors 11.4 m over a floor were not all "
			+ "accepted: %s" % str(span["declined"]))
	_check(_stride_would_refuse(11.4, 0.0),
			"V1: the fixture no longer reproduces the blind band, so "
			+ "this case has stopped testing anything")

	# V2 -- A ONE-CENTIMETRE LIFT MUST NOT MATTER. The Hall's anchors sat
	# at y = 1.2 (mod 2) over a floor at 0, so the decisive sample landed
	# exactly on the window's lower limit: clearance 0.000 m, three
	# times, and +0.01 m flipped all three to declined. A continuous
	# measurement has no such boundary.
	for lift: float in [0.0, 0.01, 0.05, -0.01]:
		var lifted := {"offers": [
			{"kind": "grapple_point", "name": "g0", "position":
				Vector3(0, 9.2 + lift, 28.8), "radius": 1.5},
			{"kind": "grapple_point", "name": "g1", "position":
				Vector3(5.2, 19.2 + lift, 34.0), "radius": 1.5},
			{"kind": "grapple_point", "name": "g2", "position":
				Vector3(0, 27.2 + lift, 39.2), "radius": 1.5},
		]}
		var moved: Dictionary = await _offer_verdict(lifted, [floor_box])
		_check((moved["built"] as Array).size() == 3,
				"V2: lifting the anchors by %+.2f m declined %d of 3"
				% [lift, (moved["declined"] as Array).size()])

	# V3 -- CHECKING ONLY THE COLUMN'S ENDPOINTS FALSELY ACCEPTS. A ledge
	# halfway down the swing column is invisible to two endpoint samples
	# and caught by a sweep.
	var mid := {"offers": [{"kind": "grapple_point", "name": "mid",
			"position": Vector3(0, 18, 0), "radius": 1.5}]}
	# OFFSET so the anchor's own downward ray misses it entirely: the
	# slab spans x 0.1 to 1.1, and a ray at x=0 passes beside it while
	# the player's 0.38 m body does not. So the drop measurement reports
	# the basin floor and only a SWEEP of the column can see this.
	var shelf := [Vector3(0.6, 15.5, 0), Vector3(1.0, 1.0, 6), "shelf"]
	var swept: Dictionary = await _offer_verdict(mid, [floor_box, shelf])
	_check((swept["built"] as Array).is_empty(),
			"V3: a ledge inside the swing column was not seen, so the "
			+ "column is being sampled at its ends rather than swept")
	_check(str(swept["declined"]).contains("shelf"),
			"V3: the refusal must name the blocking collider: %s"
			% str(swept["declined"]))
	refusals += 1
	# ... and the two endpoints alone really are clear, which is what
	# makes this a sweep test rather than a restatement of V1.
	var probe := _space_of_boxes([floor_box, shelf])
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(SpaceProbe.body_fits(probe["space"], Vector3(0, 18, 0))
			and SpaceProbe.body_fits(probe["space"], Vector3(0, 14, 0)),
			"V3: the fixture must be clear at BOTH ends of the swing "
			+ "column, or it is not testing the middle")
	(probe["root"] as Node3D).queue_free()

	# V4 -- INSUFFICIENT HANG SPACE IS ITS OWN REASON. The plenum's
	# `grapple_1` sits 0.762 m above a tread: the anchor itself is clear,
	# so a refusal that says "buried" would be the wrong diagnosis.
	var shallow := {"offers": [{"kind": "grapple_point", "name": "g1",
			"position": Vector3(0, 18, 0), "radius": 1.5}]}
	var tread := [Vector3(0, 16.5, 0), Vector3(6, 1, 6), "tread"]
	var cramped: Dictionary = await _offer_verdict(shallow,
			[floor_box, tread])
	_check((cramped["built"] as Array).is_empty(),
			"V4: an anchor with 0.762 m of hang space was accepted")
	_check(str(cramped["declined"]).contains("hang or swing")
			and not str(cramped["declined"]).contains("inside solid"),
			"V4: it must be refused for hang space, not for a buried "
			+ "anchor: %s" % str(cramped["declined"]))
	refusals += 1

	# V5 -- GROUND PAST `GRAPPLE_DROP` IS REFUSED. The old 4.0 m window
	# at drop 30 could see ground as deep as 34 m and call it an
	# opportunity. 31 m is past the limit and must be refused as such.
	var deep := {"offers": [{"kind": "grapple_point", "name": "deep",
			"position": Vector3(0, 31, 0), "radius": 1.5}]}
	var far_floor: Dictionary = await _offer_verdict(deep, [floor_box])
	_check((far_floor["built"] as Array).is_empty(),
			"V5: an anchor whose first ground is 31 m down was accepted")
	_check(str(far_floor["declined"]).contains("past the 30 m"),
			"V5: the refusal must name the limit it exceeded: %s"
			% str(far_floor["declined"]))
	refusals += 1
	# 30 m exactly is inside the limit, so the bound is a bound and not
	# an off-by-one.
	var edge := {"offers": [{"kind": "grapple_point", "name": "edge",
			"position": Vector3(0, 30, 0), "radius": 1.5}]}
	var at_limit: Dictionary = await _offer_verdict(edge, [floor_box])
	_check((at_limit["built"] as Array).size() == 1,
			"V5: an anchor exactly %.0f m up was refused: %s"
			% [MovementPackage.GRAPPLE_DROP, str(at_limit["declined"])])

	# V6 -- NO PHYSICS SPACE MUST REFUSE, NOT PASS. A probe with nowhere
	# to go comes back clean, and that is the most dangerous answer a
	# validator can give.
	var detached := Node3D.new()
	var nowhere := MovementPackage.consume(detached, mid, null)
	_check(bool(nowhere.get("refused", false))
			and (nowhere["built"] as Array).is_empty(),
			"V6: a null physics space was answered instead of refused")
	_check(str(nowhere["declined"]).contains("no physics space"),
			"V6: the refusal must say why: %s" % str(nowhere["declined"]))
	# A REAL space handed a DETACHED root. Passing the detached node's
	# own space would be null and answered by the branch above, so this
	# borrows a live one -- which is exactly the mistake a caller makes.
	var live := _space_of_boxes([floor_box])
	await get_tree().physics_frame
	var loose := MovementPackage.consume(detached, mid,
			live["space"] as PhysicsDirectSpaceState3D)
	(live["root"] as Node3D).queue_free()
	_check(bool(loose.get("refused", false)),
			"V6: a room outside the scene tree was answered instead of "
			+ "refused")
	_check(str(loose["declined"]).contains("scene tree"),
			"V6: the refusal must say the room is detached: %s"
			% str(loose["declined"]))
	detached.free()
	refusals += 2

	# V7 -- VACUITY GUARD. A binding that silently stopped measuring
	# would read as green, so the suite must have both outcomes on real
	# geometry.
	_check((span["built"] as Array).size() > 0,
			"V7: no real-geometry offer was BUILT, so a binding that "
			+ "stopped measuring would read as green")
	_check((cramped["declined"] as Array).size() > 0,
			"V7: no real-geometry offer was DECLINED, so a binding that "
			+ "accepted everything would read as green")

## The old stride's verdict, kept only so V1 can prove its own fixture
## still reproduces the blind band. Never used to decide anything.
func _stride_would_refuse(anchor_y: float, floor_y: float) -> bool:
	var drop := MovementPackage.SWING_ROOM
	while drop <= MovementPackage.GRAPPLE_DROP:
		var query := anchor_y - drop
		# `_points_have_ground`'s window: 0.3 up, 1.2 down.
		if floor_y <= query + 0.3 and floor_y >= query - 1.2:
			return false
		drop += 2.0
	return true

## A live root of boxes plus its space, for a probe that needs the space
## itself rather than a verdict.
func _space_of_boxes(boxes: Array) -> Dictionary:
	var root := Node3D.new()
	for b: Array in boxes:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		shape.shape = box
		body.add_child(shape)
		body.position = b[0]
		if b.size() > 2:
			body.name = str(b[2])
		root.add_child(body)
	add_child(root)
	return {"root": root, "space": OfferBinding.space_of(root)}

## A LAUNCH TARGET NAMES THE FLOOR. The convention the audit warned would
## otherwise manufacture three false findings on its first run.
func _test_a_launch_target_is_a_floor_point_not_a_body_point() -> void:
	"""Three of the four LARGE shells author their landing exactly on a
	top face, at penetration depth 0.0000 m. A body centred there never
	fits, so reading the point as a body pose would refuse all three
	correct rooms and accept nothing extra."""
	var deck := [[Vector3(10, -0.5, 0), Vector3(60, 1, 12), "deck"]]
	# ON the face: the authored convention, and it must be accepted.
	var on_face: Array = await _launch_verdict(Vector3(0, 0, 0),
			Vector3(20, 0, 0), 3.0, deck)
	_check(on_face.is_empty(),
			"a landing point exactly on a floor face was refused: %s"
			% "; ".join(on_face))
	# ONE METRE INSIDE a slab: the case that must stay refused, and the
	# one the old convention could not tell from the case above.
	var inside: Array = await _launch_verdict(Vector3(0, 0, 0),
			Vector3(20, 0, 0), 3.0,
			deck + [[Vector3(20, -0.5, 0), Vector3(6, 6, 6), "slab"]])
	_check(not inside.is_empty()
			and "; ".join(inside).contains("does not fit"),
			"a landing buried inside a slab was accepted: %s"
			% "; ".join(inside))
	refusals += 1
	# And the derived pose is the canonical one, not a local guess.
	_check(SpaceProbe.stand_pose(Vector3(0, 21, 0))
			.is_equal_approx(Vector3(0, 21, 0)
				+ Vector3.UP * SpaceProbe.SUPPORT_LIFT),
			"the launch convention is not using the canonical support "
			+ "offset")

func _test_a_grapple_point_must_be_somewhere_you_could_hang() -> void:
	"""An anchor inside a slab is not an opportunity.

	Three separate ways a grapple point is not real, each proven alone so
	that no one of them can be removed and hide behind another: the
	anchor is inside geometry, there is no room to swing beneath it, or
	there is no ground under it to leave from or arrive at."""
	var anchor := Vector3(0, 18, 0)
	var offer := {"kind": "grapple_point", "name": "hook",
			"position": anchor, "radius": 2.5}
	var room := {"offers": [offer]}

	# REAL GEOMETRY, NOT A PREDICATE (owner ruling, 2026-09-03). Every
	# case below used to be a lambda: `yes` accepted, `no` refused, and a
	# half-space stood in for a slab. None of them was ever a collider,
	# which is exactly how the rules and the geometry came to disagree.
	var good: Dictionary = await _offer_verdict(room, [
			[Vector3(0, -0.5, 0), Vector3(20, 1, 20)]])
	_check((good["built"] as Array).size() == 1,
			"a clear anchor over solid ground was not accepted: %s"
			% str(good["declined"]))

	# The anchor itself inside a block, with the hang column open below.
	var buried: Dictionary = await _offer_verdict(room, [
			[Vector3(0, -0.5, 0), Vector3(20, 1, 20)],
			[Vector3(0, 18, 0), Vector3(2, 2, 2)]])
	_check((buried["built"] as Array).is_empty(),
			"an anchor inside solid geometry was offered as a grapple "
			+ "opportunity")
	_check(str(buried["declined"]).contains("inside solid"),
			"the refusal must say the anchor is buried: %s"
			% str(buried["declined"]))
	refusals += 1

	# A ledge in the swing column, clear of the anchor itself.
	var cramped: Dictionary = await _offer_verdict(room, [
			[Vector3(0, -0.5, 0), Vector3(20, 1, 20)],
			[Vector3(0, 15.5, 0), Vector3(6, 1, 6)]])
	_check((cramped["built"] as Array).is_empty(),
			"an anchor with no room to swing under it was offered")
	_check(str(cramped["declined"]).contains("hang or swing"),
			"the refusal must say there is no room: %s"
			% str(cramped["declined"]))
	refusals += 1

	# Clear all the way down, and nothing to land on.
	var over_a_void: Dictionary = await _offer_verdict(room, [])
	_check((over_a_void["built"] as Array).is_empty(),
			"an anchor over a bottomless void was offered")
	_check(str(over_a_void["declined"]).contains("ground to leave from"),
			"the refusal must say there is no ground: %s"
			% str(over_a_void["declined"]))
	refusals += 1


## --- a walk is proven by geometry, never by rectangles (P3.5A) ---------

## A room built from boxes, so the evidence is exact and the fixture says
## what it means. Ground is the top of whichever slab covers the column;
## a player fits wherever nothing is in the way above step height.
class Slabs:
	var boxes: Array[AABB] = []

	func add(centre: Vector3, size: Vector3) -> void:
		boxes.append(AABB(centre - size / 2.0, size))

	func ground() -> Callable:
		var mine := boxes
		return func(at: Vector3) -> float:
			return TraversalLaw.mesh_ground(mine, at)

	func fits() -> Callable:
		var mine := boxes
		return func(at_floor: Vector3) -> bool:
			return TraversalLaw.boxes_fit(mine, at_floor)

func _walk(start: Vector3, end: Vector3, slabs: Slabs,
		surfaces: Array) -> Array[String]:
	return TraversalLaw.violations("walk", start, end, slabs.ground(),
			"probe", surfaces, slabs.fits())

func _test_a_walk_is_proven_by_geometry_not_by_rectangles() -> void:
	"""DECLARED SURFACES BOUND THE SEARCH; THEY DO NOT PROVE IT.

	Owner ruling C(ii) says a `stand` Surface promises a valid placement
	can be FOUND inside it -- never that its whole rect is ground. So a
	single perfectly valid Surface may span a chasm, and the version of
	this law that passed a walk the moment both ends landed in the same
	Surface called that chasm walkable. These are the cases that catches."""

	# S1 -- SAME-SURFACE CHASM. One C(ii)-valid Surface over two slabs
	# with six metres of nothing between them.
	var chasm := Slabs.new()
	chasm.add(Vector3(-4, 0, 0), Vector3(4, 1, 6))
	chasm.add(Vector3(5, 0, 0), Vector3(4, 1, 6))
	var one_big := [{"name": "hall", "position": Vector3(0.5, 0.5, 0),
			"extent": Vector3(13, 0, 6)}]
	var s1 := _walk(Vector3(-4, 0.5, 0), Vector3(5, 0.5, 0), chasm,
			one_big)
	_check(not s1.is_empty(),
			"S1: a walk across a 6 m chasm passed because both ends were "
			+ "inside one declared Surface")
	refusals += 1

	# S2 -- DECLARED RECTS THAT TOUCH OVER A VOID. Two Surfaces whose
	# metadata overlaps; the geometry under them does not meet.
	var split := [
		{"name": "west", "position": Vector3(-4, 0.5, 0),
			"extent": Vector3(11, 0, 6)},
		{"name": "east", "position": Vector3(5, 0.5, 0),
			"extent": Vector3(11, 0, 6)}]
	_check(split[0]["position"].x + (split[0]["extent"] as Vector3).x / 2.0
				> split[1]["position"].x
					- (split[1]["extent"] as Vector3).x / 2.0,
			"S2: the fixture's two rects must OVERLAP in declaration "
			+ "space or it is not testing the defect")
	var s2 := _walk(Vector3(-4, 0.5, 0), Vector3(5, 0.5, 0), chasm, split)
	_check(not s2.is_empty(),
			"S2: two rects that overlap in the manifest were taken as "
			+ "proof of a route over a void")
	refusals += 1

	# S3 -- A RING. No straight chord across the middle, a continuous
	# route around it. This is the case a chord test can never pass.
	var ring := Slabs.new()
	ring.add(Vector3(0, 0, 6), Vector3(14, 1, 3))
	ring.add(Vector3(0, 0, -6), Vector3(14, 1, 3))
	ring.add(Vector3(-6, 0, 0), Vector3(3, 1, 14))
	ring.add(Vector3(6, 0, 0), Vector3(3, 1, 14))
	var collar := [{"name": "collar", "position": Vector3(0, 0.5, 0),
			"extent": Vector3(16, 0, 16)}]
	var s3 := _walk(Vector3(0, 0.5, 6), Vector3(0, 0.5, -6), ring, collar)
	_check(s3.is_empty(),
			"S3: a continuous ring walk was refused: %s" % "; ".join(s3))
	# And the chord across the middle really is empty, so S3 is the case
	# it claims to be.
	_check(ring.ground().call(Vector3(0, 0.5, 0)) == -INF,
			"S3: the middle of the ring has floor, so this is not a ring")

	# S4 -- A LONG RAMP whose endpoint span is far past any jump.
	var ramp := Slabs.new()
	for i in 30:
		ramp.add(Vector3(0, float(i) * 0.4, -12.0 + float(i) * 0.8),
				Vector3(4, 0.5, 1.0))
	var slope := [{"name": "ramp", "position": Vector3(0, 6, -0.4),
			"extent": Vector3(4, 0, 26)}]
	var s4 := _walk(Vector3(0, 0.25, -12.0), Vector3(0, 11.85, 11.2),
			ramp, slope)
	_check(s4.is_empty(),
			"S4: a continuous 23 m ramp was refused as a walk: %s"
			% "; ".join(s4))
	var reach := Constants.max_safe_gap(11.6)
	_check(23.2 > reach,
			"S4: the ramp's span %.1f m must exceed the %.1f m jump "
			% [23.2, reach] + "reach or it proves nothing")

	# S5 -- A JUMP RELABELLED. The same chasm, no surfaces declared at
	# all, so nothing bounds it but the corridor -- and it still fails.
	var s5 := _walk(Vector3(-4, 0.5, 0), Vector3(5, 0.5, 0), chasm, [])
	_check(not s5.is_empty(),
			"S5: a 9 m jump relabelled `walk` was accepted")
	refusals += 1

	# S6 -- A PINCH. Continuous floor, and the only way through is a
	# slot too low for a player. Support alone would flood it.
	var pinch := Slabs.new()
	pinch.add(Vector3(0, 0, 0), Vector3(4, 1, 20))
	pinch.add(Vector3(0, 1.4, 0), Vector3(4, 1, 3))
	var tube := [{"name": "tube", "position": Vector3(0, 0.5, 0),
			"extent": Vector3(4, 0, 20)}]
	_check(pinch.ground().call(Vector3(0, 0.5, 0)) > -INF,
			"S6: the pinch must have continuous FLOOR, or it is testing "
			+ "a hole instead of a ceiling")
	var s6 := _walk(Vector3(0, 0.5, -9), Vector3(0, 0.5, 9), pinch, tube)
	_check(not s6.is_empty(),
			"S6: a route whose only link is too low for a player was "
			+ "accepted")
	refusals += 1


func _test_a_room_may_descend_from_entry_to_exit() -> void:
	"""NET DESCENT IS DECLARABLE. Adjudicated, then pinned.

	Two LARGE-room producers read the contract differently on this, so
	the answer is measured against the real law rather than argued: a
	mandatory route whose exit is below its entry is legal, and these are
	the declarations that make it so."""
	var far := Constants.max_safe_gap(0.0)

	# `drop` is the kind that EXISTS for descent. It is bounded only by
	# having to go down -- gravity does the rest whatever anyone
	# declares, and how far is a damage question, not a legality one.
	var deep := TraversalLaw.violations("drop", Vector3(0, 40, 0),
			Vector3(0, 4, 3), Callable(), "deep")
	_check(deep.is_empty(),
			"a 36 m drop was refused: %s" % "; ".join(deep))
	var upward := TraversalLaw.violations("drop", Vector3(0, 4, 0),
			Vector3(0, 40, 3), Callable(), "upward")
	_check(not upward.is_empty(),
			"a `drop` that RISES was accepted, so the kind means nothing")
	refusals += 1

	# A descending WALK -- a ramp or a stair -- is bounded by ground
	# continuity, not by the drop between its ends. Sampled on a real
	# descending ramp, and the endpoints are 12 m apart vertically.
	var ramp := Slabs.new()
	for i in 30:
		ramp.add(Vector3(0, 11.6 - float(i) * 0.4,
				-12.0 + float(i) * 0.8), Vector3(4, 0.5, 1.0))
	var down := [{"name": "ramp", "position": Vector3(0, 6, -0.4),
			"extent": Vector3(4, 0, 26)}]
	var walked := _walk(Vector3(0, 11.85, -12.0), Vector3(0, 0.25, 11.2),
			ramp, down)
	_check(walked.is_empty(),
			"a continuous DESCENDING ramp was refused as a walk: %s"
			% "; ".join(walked))

	# A descending GAP gets the FLAT reach, never a bonus for falling:
	# `max_safe_gap` is fed `maxf(rise, 0)`, so jumping down is held to
	# the same span as jumping level.
	var hop := TraversalLaw.violations("gap", Vector3(0, 20, 0),
			Vector3(0, 14, far - 0.2), Callable(), "hop")
	_check(hop.is_empty(),
			"a downward hop inside the flat reach was refused: %s"
			% "; ".join(hop))
	var lunge := TraversalLaw.violations("gap", Vector3(0, 20, 0),
			Vector3(0, 14, far + 2.0), Callable(), "lunge")
	_check(not lunge.is_empty(),
			"a downward gap %.1f m past the flat reach was accepted; "
			% 2.0 + "falling is not extra range")
	refusals += 1

	# AND THE CHAIN CARRIES IT: a room whose exit sits below its entry
	# moves the next room down with it. ASSERTED ON THE SEAM, not on the text of the line that computes
	# it. This used to grep `zone_builder.gd` for
	# `cursor += _rot(yaw, result["exit_offset"])`, which was true until
	# the entry contract landed and then pinned the SPELLING rather than
	# the ruling. Both connectors are room-local vectors turned by the
	# room's own yaw, so the Y a room descends is still carried whole --
	# and now that is measured instead of read.
	var seam_origin := ZoneBuilder.origin_for(Vector3(0.0, 30.0, 0.0),
			0.0, Vector3(0.0, 8.0, 0.0))
	var seam_next := ZoneBuilder.exit_cursor(seam_origin, 0.0,
			Vector3(0.0, 2.0, 12.0))
	_check(seam_next.is_equal_approx(Vector3(0.0, 24.0, 12.0)),
			"a room whose exit sits 6 m below its entry must move the "
			+ "chain down with it; the next seam landed at %v" % seam_next)

func _test_a_rider_enters_only_on_terms_and_leaves_when_it_asks() -> void:
	"""Catching is conditional, and letting go is always available."""
	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 1, 12)]))
	_check(not RailRider.catch(rail, Vector3(0, 2, 4),
			Vector3(0, 0, 8)).is_empty(),
			"a player running along a rail beside them did not catch it")
	_check(RailRider.catch(rail, Vector3(9, 2, 4),
			Vector3(0, 0, 8)).is_empty(),
			"a rail was caught from %.1f m away" % 9.0)
	refusals += 1
	_check(RailRider.catch(rail, Vector3(0, 2, 4),
			Vector3(8, 0, 0)).is_empty(),
			"walking sideways into a rail launched the player down it")
	refusals += 1
	_check(RailRider.catch(rail, Vector3(0, 2, 12),
			Vector3(0, 0, 8)).is_empty(),
			"a rail was caught at its far end, already heading off it")
	refusals += 1
	_check(RailRider.catch(rail, Vector3(0, 12, 4),
			Vector3(0, 0, 8)).is_empty(),
			"a rail was caught from 10 m below it")
	refusals += 1

	# BACKWARDS is a direction, not a refusal.
	var back := RailRider.catch(rail, Vector3(0, 2, 8), Vector3(0, 0, -8))
	_check(not back.is_empty() and int(back["heading"]) == -1,
			"entering against the rail's own direction did not ride back")

	# JUMPING OFF keeps the grind's momentum and adds a jump.
	var rider := _ride_from(rail, Vector3(0, 2, 1), Vector3(0, 0, 9))
	for i in 20:
		rider.advance(1.0 / 60.0)
	var off := rider.advance(1.0 / 60.0, true)
	_check(not bool(off["riding"]) and str(off["reason"]) == "jumped",
			"jump did not leave the rail")
	var away: Vector3 = off["velocity"]
	_check(away.y > Constants.JUMP_VELOCITY * 0.9,
			"a dismount rose at only %.2f m/s" % away.y)
	_check(away.z > 5.0,
			"a dismount kept only %.2f m/s of the grind" % away.z)
	rides += 1

	# A DEGENERATE PATH IS NOT A RAIL, and is refused before anyone is on
	# it rather than divided by underneath them.
	var stub := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 1, 0.05)]))
	_check(not stub.violations().is_empty(),
			"a 5 cm rail was accepted as a path")
	_check(RailRider.catch(stub, Vector3(0, 2, 0),
			Vector3(0, 0, 8)).is_empty(),
			"a degenerate rail was caught")
	refusals += 1
	var vertical := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 20, 1)]))
	_check(not vertical.violations().is_empty(),
			"a rail pitched past vertical-ish was accepted")
	refusals += 1

	# A PATH THAT IS NOT A PATH. One point is a place, and none is
	# nothing; neither has a direction, a length or a tangent, and the
	# ride loop would divide by all three. Refused where they are built.
	for thin: PackedVector3Array in [PackedVector3Array(),
			PackedVector3Array([Vector3(0, 1, 0)])]:
		var nothing := RailPath.from_points(thin)
		_check(not nothing.violations().is_empty(),
				"a %d-point path was accepted as a rail" % thin.size())
		_check(RailRider.catch(nothing, Vector3(0, 2, 0),
				Vector3(0, 0, 8)).is_empty(),
				"a %d-point path was caught and ridden" % thin.size())
		refusals += 1

# --- 6, 7, 8. the launch pad ----------------------------------------------

func _test_a_launch_crosses_horizontal_and_vertical_distance() -> void:
	"""A traversal edge: a long way across AND a long way up."""
	var source := Vector3(0, 0, 0)
	var target := Vector3(26, 11, 8)
	var shot := LaunchSolver.solve(source, target)
	_check(bool(shot["ok"]),
			"a 26 x 11 m launch could not be solved: %s"
			% str(shot.get("reason", "")))
	var points := LaunchSolver.arc(source, shot["velocity"] as Vector3,
			float(shot["time"]))
	var landed: Vector3 = points[points.size() - 1]
	_check(landed.distance_to(target) < 0.05,
			"the solved arc landed at %v, not %v" % [landed, target])
	var apex := -INF
	for p: Vector3 in points:
		apex = maxf(apex, p.y)
	_check(apex > target.y + 1.0,
			"the arc peaked at %.2f, barely over its %.2f m target"
			% [apex, target.y])
	_check(float(shot["time"]) > 1.2,
			"a %.2f s flight is a shot, not a readable arc"
			% float(shot["time"]))
	# DERIVED, NOT AUTHORED: move the target and the velocity follows.
	var moved := LaunchSolver.solve(source, target + Vector3(6, 0, 0))
	_check((moved["velocity"] as Vector3).distance_to(
			shot["velocity"] as Vector3) > 0.5,
			"moving the destination did not change the launch")
	# DETERMINISTIC: the same pair solves the same way, every time.
	_check((LaunchSolver.solve(source, target)["velocity"] as Vector3)
			.is_equal_approx(shot["velocity"] as Vector3),
			"the same launch solved differently twice")

## A launch pair judged against real colliders through the real solver.
##
## `boxes` is `[[centre, size], ...]`. The lambdas this replaces could
## not tell a landing ON a deck from one four metres inside a machine,
## which is the distinction the owner's floor-contact ruling turns on.
func _launch_verdict(source_foot: Vector3, target_foot: Vector3,
		radius: float, boxes: Array,
		place := Transform3D.IDENTITY) -> Array:
	var root := Node3D.new()
	# THE ROOM MAY BE ANYWHERE. `boxes` are room-local like the feet, so
	# placing the root moves the geometry and the offer together -- which
	# is the whole point: a correct binding gives the same verdict, and
	# the version that handed local points to a world probe did not.
	root.transform = place
	for b: Array in boxes:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		shape.shape = box
		body.add_child(shape)
		body.position = b[0]
		if b.size() > 2:
			body.name = str(b[2])
		root.add_child(body)
	add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var out := LaunchSolver.violations(source_foot, target_foot, radius,
			OfferBinding.space_of(root), root.global_transform, "probe")
	root.queue_free()
	await get_tree().process_frame
	return out

func _test_a_launch_refuses_an_obstructed_arc() -> void:
	"""A wall through the middle of the flight is a pad that must not be
	built. Refused at build time, not discovered by a player's face."""
	var source := Vector3(0, 0, 0)
	var target := Vector3(24, 0, 0)
	var deck := [[Vector3(10, -0.5, 0), Vector3(60, 1, 12)]]
	var clean: Array = await _launch_verdict(source, target, 3.0, deck)
	_check(clean.is_empty(),
			"an unobstructed launch was refused: %s" % "; ".join(clean))
	var blocked: Array = await _launch_verdict(source, target, 3.0,
			deck + [[Vector3(12, 6.0, 0), Vector3(3, 12, 12)]])
	_check(not blocked.is_empty(),
			"an arc straight through a wall was accepted")
	_check("; ".join(blocked).contains("obstructed"),
			"the refusal must say the arc was obstructed: %s"
			% "; ".join(blocked))
	refusals += 1

func _test_a_launch_refuses_a_landing_it_cannot_land_on() -> void:
	"""Three ways a destination is not a destination."""
	var source := Vector3(0, 0, 0)
	var target := Vector3(20, 0, 0)
	# A pad to leave from, and nothing where the landing is declared.
	var pad_only := [[Vector3(0, -0.5, 0), Vector3(8, 1, 8)]]
	var full := [[Vector3(10, -0.5, 0), Vector3(60, 1, 12)]]

	var void_landing: Array = await _launch_verdict(source, target, 3.0,
			pad_only)
	_check("; ".join(void_landing).contains("not on a surface"),
			"a landing over a void was accepted: %s"
			% "; ".join(void_landing))
	refusals += 1
	# THE LANDING POINT IS FLOOR, SO WHAT REFUSES IT IS THE BODY. A slab
	# filling the space a player would stand in is the case the old
	# lambda pair could not tell from a good deck.
	var solid_landing: Array = await _launch_verdict(source, target, 3.0,
			full + [[Vector3(20, 1.0, 0), Vector3(4, 3, 4)]])
	_check(not solid_landing.is_empty(),
			"a landing with no room for the player was accepted")
	_check("; ".join(solid_landing).contains("does not fit"),
			"the refusal must say the body does not fit: %s"
			% "; ".join(solid_landing))
	refusals += 1
	var pinpoint: Array = await _launch_verdict(source, target, 0.4, full)
	_check("; ".join(pinpoint).contains("trusted to hit"),
			"a landing smaller than a player can aim at was accepted: %s"
			% "; ".join(pinpoint))
	refusals += 1
	var nowhere: Array = await _launch_verdict(source, Vector3(200, 0, 0),
			3.0, full)
	_check("; ".join(nowhere).contains("cannot be solved"),
			"a 200 m launch was accepted: %s" % "; ".join(nowhere))
	refusals += 1

# --- 9. offers may be declined --------------------------------------------

func _test_a_package_may_decline_every_offer() -> void:
	"""AN OFFER IS NOT AN ORDER, proven three ways on one room.

	The same offers: consumed, partly consumed, and consumed by nobody.
	The room is a room in all three cases, which is the property that
	lets one authored shell serve rails, launches and neither."""
	var room := {"offers": [
		{"kind": "rail_route", "name": "spine", "points": [
			Vector3(0, 4, 0), Vector3(0, 6, 14), Vector3(10, 8, 20)]},
		{"kind": "rail_route", "name": "stub", "points": [
			Vector3(0, 1, 0), Vector3(0, 1, 0.1)]},
		# A reservation big enough for the pad that gets built in it --
		# `radius` is the floor set aside for the mechanism, and 1.0 m
		# cannot hold a pad reaching 1.70 m from its centre.
		{"kind": "launch_source", "name": "up", "position": Vector3.ZERO,
			"radius": 3.0, "target": "ledge"},
		{"kind": "launch_source", "name": "orphan",
			"position": Vector3(4, 0, 0), "radius": 1.0,
			"target": "nowhere"},
		{"kind": "launch_target", "name": "ledge",
			"position": Vector3(20, 6, 0), "radius": 4.0},
		{"kind": "grapple_point", "name": "hook_open",
			"position": Vector3(0, 14, 0), "radius": 2.5},
		{"kind": "grapple_point", "name": "hook_buried",
			"position": Vector3(60, 14, 0), "radius": 2.5},
	]}
	_check(RoomContract.violations(_as_room(room)).is_empty(),
			"the offer fixture is not a structurally valid room: %s"
			% "; ".join(RoomContract.violations(_as_room(room))))
	# REAL COLLIDERS. A floor under everything, plus a block around
	# `hook_buried` at x=60 so it is declined for a reason a collider
	# gives rather than a predicate. The floor is wide enough to be the
	# ground every other offer needs.
	var world := [
		[Vector3(0, -0.5, 0), Vector3(200, 1, 200), "floor"],
		# The ledge the launch names, so its target is a real top face --
		# under the owner's floor-contact ruling a landing point must BE
		# a surface, and this fixture used to declare one in mid-air.
		[Vector3(20, 5.5, 0), Vector3(10, 1, 10), "ledge"],
		[Vector3(60, 14, 0), Vector3(4, 4, 4), "buried_block"],
	]
	var all: Dictionary = await _offer_verdict(room, world, [])
	_check((all["built"] as Array).size() == 3,
			"a package that wants everything took %d of the 4 usable "
			% (all["built"] as Array).size() + "offers")
	var grappled := 0
	for entry: Variant in all["built"] as Array:
		if str((entry as Dictionary)["kind"]) == "grapple_point":
			grappled += 1
	_check(grappled == 1,
			"%d grapple opportunities were validated, not the 1 that is "
			% grappled + "geometrically real")
	_check((all["declined"] as Array).size() == 3,
			"the malformed rail, the orphan launch and the buried "
			+ "grapple were not all declined: %s" % str(all["declined"]))
	var why := ""
	for entry: Variant in all["declined"] as Array:
		why += str((entry as Dictionary)["why"]) + " "
	_check(why.contains("no direction") and why.contains("nowhere"),
			"a decline must say WHY: %s" % why)
	refusals += 1

	# ONE KIND ONLY: a rail package ignores launches entirely.
	# A GRAPPLE-ONLY PACKAGE: a Zelda-like reads the anchors and ignores
	# the rail and the launch entirely, which is the whole point of the
	# seam -- one shell, whichever verbs the generated game has.
	var hooks_only: Dictionary = await _offer_verdict(room, world,
			["grapple_point"])
	_check((hooks_only["built"] as Array).size() == 1,
			"a grapple-only package took %d offers"
			% (hooks_only["built"] as Array).size())
	var rails_only: Dictionary = await _offer_verdict(room, world,
			["rail_route"])
	_check((rails_only["built"] as Array).size() == 1,
			"a rail-only package built %d things"
			% (rails_only["built"] as Array).size())

	# NOBODY: the room still stands, with no traversal mechanic in it.
	var none: Dictionary = await _offer_verdict(room, world, ["wind"])
	_check((none["built"] as Array).is_empty()
			and (none["declined"] as Array).is_empty(),
			"a package that wants nothing still touched the room")

# --- 10. the corridor rail did not move -----------------------------------

func _test_the_corridor_rail_is_the_shape_it_always_was() -> void:
	"""The production rail goes through the new path object, and comes
	out at the same two points it has always had. The foundation is
	underneath the old feature, not instead of it."""
	var origin := Vector3(1.5, 0.0, -2.0)
	var path := AffordanceFeatures.rail_ride_path(origin)
	_check(path.size() == 2,
			"the corridor rail is %d points, not the 2 it was"
			% path.size())
	_check(path[0].is_equal_approx(origin
			+ Vector3(0, AffordanceFeatures.RAIL_BEAM_Y, -3.0))
			and path[1].is_equal_approx(origin
				+ Vector3(0, AffordanceFeatures.RAIL_BEAM_Y, 3.0)),
			"the corridor rail moved: %v to %v" % [path[0], path[1]])
	var root := Node3D.new()
	add_child(root)
	var built := AffordanceFeatures.build_rail(root,
			AffordanceFeatures.rail_path(origin))
	_check((built["beams"] as Array).size() == 1
			and (built["lanes"] as Array).size() == 1,
			"one straight segment built %d beams and %d lanes"
			% [(built["beams"] as Array).size(),
				(built["lanes"] as Array).size()])
	await get_tree().process_frame
	var lane: AffordanceNodes.Volume = (built["lanes"] as Array)[0]
	_check(lane.rail != null,
			"the lane does not carry the path it was swept along")
	root.queue_free()
	await get_tree().process_frame

# --- progression safety ---------------------------------------------------

func _test_the_base_kit_alone_can_use_both() -> void:
	"""NO REQUIREMENT BEFORE GUARANTEE, at the movement layer.

	The map provides rails and launch pads, so a route through either may
	be MANDATORY -- which is only true if the base player can use them.
	Neither reads an Echo, a capability or a loadout, and this is what
	says so: the ride and the solve are driven with nothing owned and
	nothing equipped."""
	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(0, 1, 0), Vector3(0, 7, 18)]))
	# WALK_SPEED is what a player has with no movement Echo at all.
	var caught := RailRider.catch(rail, Vector3(0, 2, 0),
			Vector3(0, 0, Constants.WALK_SPEED))
	_check(not caught.is_empty(),
			"a rail could not be caught at plain walking speed")
	var rider: RailRider = caught["rider"]
	var reason := ""
	for i in 900:
		var step := rider.advance(1.0 / 60.0)
		if not bool(step["riding"]):
			reason = str(step["reason"])
			break
	_check(reason == "end",
			"at walking speed a 6 m climb ended as '%s'; a map-provided "
			% reason + "route the base kit cannot finish cannot be "
			+ "mandatory")
	rides += 1
	var shot := LaunchSolver.solve(Vector3.ZERO, Vector3(22, 9, 0))
	_check(bool(shot["ok"]),
			"the launch solve consulted something the base kit lacks")

# --- helpers --------------------------------------------------------------

## A rider mounted on this rail, or a loud failure. Never a null nobody
## checked: every ride test would otherwise pass vacuously.
func _ride_from(rail: RailPath, at: Vector3,
		velocity: Vector3) -> RailRider:
	var caught := RailRider.catch(rail, at, velocity)
	_check(not caught.is_empty(),
			"the fixture could not mount its own rail at %v" % at)
	if caught.is_empty():
		var stub := RailRider.new()
		stub.path = rail
		return stub
	return caught["rider"]

## How far this point is off the polyline the beam is swept along.
##
## Against the AUTHORED control points, not against a baked sample: a
## baked-sample comparison measures `BAKE_INTERVAL`, so it would report
## 0.1 m of "drift" on a ride that never left the curve, and the number
## it reports would be the tolerance rather than the truth.
func _off_polyline(point: Vector3, points: PackedVector3Array) -> float:
	var best := INF
	for i in points.size() - 1:
		best = minf(best, point.distance_to(
				Geometry3D.get_closest_point_to_segment(
					point, points[i], points[i + 1])))
	return best

## How long a rider entering at this pace takes to run the whole rail.
func _seconds_to_ride(rail: RailPath, pace: float) -> float:
	var caught := RailRider.catch(rail, rail.at(0.0) + Vector3.UP,
			rail.tangent(0.0) * pace)
	if caught.is_empty():
		return INF
	var rider: RailRider = caught["rider"]
	for i in 3000:
		if not bool(rider.advance(1.0 / 60.0)["riding"]):
			return float(i) / 60.0
	return INF

## The offer fixture as a structurally complete room output.
func _as_room(offers: Dictionary) -> Dictionary:
	var room := offers.duplicate()
	room["root"] = Node3D.new()
	room["bounds"] = AABB(Vector3(-30, -2, -30), Vector3(60, 40, 60))
	room["exit_offset"] = Vector3(0, 0, 30)
	room["room_height"] = 20.0
	room["enemy_spawns"] = []
	room["reward_position"] = Vector3(0, 0, 5)
	return room
