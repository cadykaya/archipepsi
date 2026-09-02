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
	_test_a_grapple_point_must_be_somewhere_you_could_hang()
	_test_a_rider_enters_only_on_terms_and_leaves_when_it_asks()
	_test_a_launch_crosses_horizontal_and_vertical_distance()
	_test_a_launch_refuses_an_obstructed_arc()
	_test_a_launch_refuses_a_landing_it_cannot_land_on()
	_test_a_package_may_decline_every_offer()
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

func _test_a_grapple_point_must_be_somewhere_you_could_hang() -> void:
	"""An anchor inside a slab is not an opportunity.

	Three separate ways a grapple point is not real, each proven alone so
	that no one of them can be removed and hide behind another: the
	anchor is inside geometry, there is no room to swing beneath it, or
	there is no ground under it to leave from or arrive at."""
	var anchor := Vector3(0, 18, 0)
	var yes := func(_at: Vector3) -> bool: return true
	var root := Node3D.new()
	add_child(root)
	var offer := {"kind": "grapple_point", "name": "hook",
			"position": anchor, "radius": 2.5}
	var room := {"offers": [offer]}

	var good := MovementPackage.consume(root, room, yes, yes,
			["grapple_point"])
	_check((good["built"] as Array).size() == 1,
			"a clear anchor over solid ground was not accepted: %s"
			% str(good["declined"]))

	# ONLY the anchor is solid: the space below is open, so this can only
	# be caught by the anchor test itself.
	var anchor_is_solid := func(at: Vector3) -> bool:
		return absf(at.y - anchor.y) > 0.5
	var buried := MovementPackage.consume(root, room, anchor_is_solid, yes,
			["grapple_point"])
	_check((buried["built"] as Array).is_empty(),
			"an anchor inside solid geometry was offered as a grapple "
			+ "opportunity")
	_check(str(buried["declined"]).contains("inside solid"),
			"the refusal must say the anchor is buried: %s"
			% str(buried["declined"]))
	refusals += 1

	# ONLY the swing space is solid.
	var no_swing := func(at: Vector3) -> bool:
		return absf(at.y - (anchor.y - MovementPackage.SWING_ROOM)) > 0.5
	var cramped := MovementPackage.consume(root, room, no_swing, yes,
			["grapple_point"])
	_check((cramped["built"] as Array).is_empty(),
			"an anchor with no room to swing under it was offered")
	_check(str(cramped["declined"]).contains("hang or swing"),
			"the refusal must say there is no room: %s"
			% str(cramped["declined"]))
	refusals += 1

	# Clear all the way down, and nothing to land on.
	var no := func(_at: Vector3) -> bool: return false
	var over_a_void := MovementPackage.consume(root, room, yes, no,
			["grapple_point"])
	_check((over_a_void["built"] as Array).is_empty(),
			"an anchor over a bottomless void was offered")
	refusals += 1
	root.queue_free()

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

func _test_a_launch_refuses_an_obstructed_arc() -> void:
	"""A wall through the middle of the flight is a pad that must not be
	built. Refused at build time, not discovered by a player's face."""
	var source := Vector3(0, 0, 0)
	var target := Vector3(24, 0, 0)
	var wall := func(at: Vector3) -> bool:
		return absf(at.x - 12.0) > 1.5 or at.y > 14.0
	var clean := LaunchSolver.violations(source, target, 3.0,
			func(_at: Vector3) -> bool: return true,
			func(_at: Vector3) -> bool: return true)
	_check(clean.is_empty(),
			"an unobstructed launch was refused: %s" % "; ".join(clean))
	var blocked := LaunchSolver.violations(source, target, 3.0, wall,
			func(_at: Vector3) -> bool: return true)
	_check(not blocked.is_empty(),
			"an arc straight through a wall was accepted")
	_check("; ".join(blocked).contains("obstructed"),
			"the refusal must say the arc was obstructed: %s"
			% "; ".join(blocked))
	refusals += 1

func _test_a_launch_refuses_a_landing_it_cannot_land_on() -> void:
	"""Three ways a destination is not a destination."""
	var source := Vector3(0, 0, 0)
	var yes := func(_at: Vector3) -> bool: return true
	var no := func(_at: Vector3) -> bool: return false
	var void_landing := LaunchSolver.violations(source, Vector3(20, 0, 0),
			3.0, yes, no)
	_check("; ".join(void_landing).contains("nothing under it"),
			"a landing over a void was accepted: %s"
			% "; ".join(void_landing))
	refusals += 1
	var solid_landing := LaunchSolver.violations(source,
			Vector3(20, 0, 0), 3.0, no, yes)
	_check(not solid_landing.is_empty(),
			"a landing with no room for the player was accepted")
	refusals += 1
	var pinpoint := LaunchSolver.violations(source, Vector3(20, 0, 0),
			0.4, yes, yes)
	_check("; ".join(pinpoint).contains("trusted to hit"),
			"a landing smaller than a player can aim at was accepted: %s"
			% "; ".join(pinpoint))
	refusals += 1
	var nowhere := LaunchSolver.violations(source, Vector3(200, 0, 0),
			3.0, yes, yes)
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
		{"kind": "launch_source", "name": "up", "position": Vector3.ZERO,
			"radius": 1.0, "target": "ledge"},
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
	var yes := func(_at: Vector3) -> bool: return true
	var root := Node3D.new()
	add_child(root)
	# `hook_buried` sits where nothing is clear, so it is declined; every
	# other offer here is usable.
	var solid_at_60 := func(at: Vector3) -> bool: return at.x < 50.0
	var all := MovementPackage.consume(root, room, solid_at_60, yes)
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
	var hooks_only := MovementPackage.consume(root, room, solid_at_60, yes,
			["grapple_point"])
	_check((hooks_only["built"] as Array).size() == 1,
			"a grapple-only package took %d offers"
			% (hooks_only["built"] as Array).size())
	var rails_only := MovementPackage.consume(root, room, yes, yes,
			["rail_route"])
	_check((rails_only["built"] as Array).size() == 1,
			"a rail-only package built %d things"
			% (rails_only["built"] as Array).size())

	# NOBODY: the room still stands, with no traversal mechanic in it.
	var none := MovementPackage.consume(root, room, yes, yes, ["wind"])
	_check((none["built"] as Array).is_empty()
			and (none["declined"] as Array).is_empty(),
			"a package that wants nothing still touched the room")
	root.queue_free()

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
