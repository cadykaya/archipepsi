class_name RailPath
extends RefCounted
## THE authoritative 3D path of a rail (P3.0).
##
## ONE TRUTH, and the word is load bearing. The visual beam, the ride
## geometry, the runtime traversal and the validation all read this
## object; none of them holds a second version of the shape. The owner
## ruling this implements is explicit -- *"do not independently author
## pretty curve, collision curve, ride curve"* -- and the failure it
## prevents is the one this project already paid for twice: a builder
## that knows a physical fact its consumer does not.
##
## WHAT THE OLD RAIL WAS, so the difference is on record rather than
## implied. `AffordanceFeatures.rail_ride_path` returned TWO points on a
## straight line along one axis, and the "ride" was an `Area3D` box whose
## influence dictionary lowered friction and scaled speed while the
## player fell through it under normal gravity. That is a slippery
## corridor, and calling it a spline grinder would have been a lie. It
## could not curve, could not climb, and the player was never attached
## to anything.
##
## CURVE3D, because a rail is a curve and Godot has one. What this class
## adds around it is the part a raw `Curve3D` will not do: a single
## explicit bake interval so sampling is DETERMINISTIC across machines
## and runs, refusal of degenerate and illegal shapes, and the small
## number of queries the rider and the validators actually need.
##
## NO UPSIDE-DOWN LOOPS IN THIS SLICE. A rail may climb, descend, curve
## in plan, wrap around an obstacle and spiral through several levels.
## What it may not do is pitch past vertical, because the rider's up
## vector is world up and a path that goes over the top would need a
## frame that rolls with it -- a different, larger slice.

## How finely the curve is baked, in metres. EXPLICIT because Godot's
## default is a property that can be edited, and a sampling interval that
## can drift is a path that measures differently on two machines.
const BAKE_INTERVAL := 0.2

## How far a control point may sit from the previous one before the path
## is describing two rails rather than one, and how close before it is
## describing nothing.
const MIN_SEGMENT := 0.5
const MAX_SEGMENT := 60.0

## How hard the curve pulls toward its control tangents. One is the
## textbook Catmull-Rom; lower is slacker and straighter. One, because a
## number chosen for looks is a number nobody can validate against.
const TENSION := 1.0

## The steepest a rail may pitch, in degrees. Short of vertical on
## purpose: at exactly 90 the tangent's horizontal component vanishes and
## every "which way along it am I going" question loses its answer.
const MAX_PITCH_DEGREES := 75.0

var _curve: Curve3D = null
var _points: PackedVector3Array = PackedVector3Array()

## A rail through these control points, in the space the caller is using.
##
## Straight segments between the points: a `Curve3D` with no handles is a
## polyline, which is exactly what the existing `build_rail_along` sweeps,
## so an authored rail of two points builds the identical geometry it
## built before. Handles are how a later slice adds smoothing without
## moving anything.
static func from_points(points: PackedVector3Array) -> RailPath:
	var made := RailPath.new()
	made._points = points
	var curve := Curve3D.new()
	curve.bake_interval = BAKE_INTERVAL
	for point: Vector3 in points:
		curve.add_point(point)
	# SMOOTH, from the authored points alone (P3.5). Each control point
	# gets Bezier handles derived from its neighbours -- the standard
	# Catmull-Rom construction, where the tangent at P[i] is
	# (P[i+1] - P[i-1]) / 2 and the handles are a third of it either
	# side. The curve passes exactly THROUGH every authored point, so the
	# route an artist drew is the route, and the interpolation only fills
	# in what happens between them.
	#
	# WHY NOT ASK ART FOR MORE POINTS. A polyline can be made to look
	# curved by hand-authoring dozens of points, and that is a worse
	# answer twice over: it makes the manifest describe rendering rather
	# than intent, and it puts the smoothness in a place no validator can
	# tell from a genuinely angular route. Eleven points describe the
	# helix; the curve is the engine's job.
	for i in points.size():
		var before: Vector3 = points[maxi(i - 1, 0)]
		var after: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent := (after - before) * 0.5 * TENSION
		curve.set_point_in(i, -tangent / 3.0)
		curve.set_point_out(i, tangent / 3.0)
	made._curve = curve
	return made

func curve() -> Curve3D:
	return _curve

func control_points() -> PackedVector3Array:
	return _points

func length() -> float:
	return _curve.get_baked_length()

## Every way this path is not a rail. Empty is the contract.
##
## REFUSAL IS THE POINT. A path is authored data, and a degenerate one
## does not announce itself: a rail whose two points coincide has zero
## length, no tangent and no direction, and the ride loop would divide by
## it. So the shape is refused where it is built, not discovered where it
## is ridden.
## `bounds` is the room's declared box, when the caller has one: a
## smoothed curve that bows outside the room is the failure mode the
## interpolation introduces, and the room's own envelope is the line it
## may not cross. Omitted, the shape is checked and containment is not.
func violations(who := "rail", bounds := AABB()) -> Array[String]:
	var out: Array[String] = []
	# DEFENCE IN DEPTH, and recorded as such rather than dressed up.
	# Sabotaging this branch alone does not let a one-point path through:
	# a curve with fewer than two points bakes to zero length and the
	# length rule below refuses it anyway. What this buys is the MESSAGE
	# -- "a rail needs two points" sends an artist somewhere useful and
	# "the path has no length" does not -- and an early return before the
	# per-segment loop.
	if _points.size() < 2:
		out.append("%s: a rail needs at least two control points, got %d"
				% [who, _points.size()])
		return out
	for i in _points.size():
		var p: Vector3 = _points[i]
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			out.append("%s: control point %d is not a finite position"
					% [who, i])
			return out
	for i in _points.size() - 1:
		var a: Vector3 = _points[i]
		var b: Vector3 = _points[i + 1]
		var run := a.distance_to(b)
		if run < MIN_SEGMENT:
			out.append("%s: control points %d and %d are %.3f m apart; "
					% [who, i, i + 1, run] + "under %.2f m they give the "
					% MIN_SEGMENT + "curve no direction")
			continue
		if run > MAX_SEGMENT:
			out.append("%s: control points %d and %d are %.1f m apart, "
					% [who, i, i + 1, run] + "past the %.0f m a single "
					% MAX_SEGMENT + "span may cover")

	# THE ACTUAL ROUTE, not the control points. Pitch is measured along
	# the BAKED curve, because the interpolation is what the player
	# rides: a pair of control points can sit at a legal angle while the
	# curve between them rears past vertical, and validating the points
	# while allowing the curve to do anything is exactly the hole this
	# closes.
	var walked := polyline()
	for i in walked.size() - 1:
		var a: Vector3 = walked[i]
		var b: Vector3 = walked[i + 1]
		var flat := Vector2(b.x - a.x, b.z - a.z).length()
		var pitch := rad_to_deg(atan2(absf(b.y - a.y), flat)) \
				if flat > 0.0001 else 90.0
		if pitch > MAX_PITCH_DEGREES:
			out.append("%s: the curve pitches %.1f degrees %.0f%% along, "
					% [who, pitch, 100.0 * float(i) / float(
						maxi(walked.size() - 1, 1))]
					+ "past the %.0f a rider can hold"
					% MAX_PITCH_DEGREES)
			break

	# IT MUST STILL BE INSIDE THE ROOM. Catmull-Rom overshoots on a
	# sharp turn, and an overshoot is not cosmetic: it is rail geometry
	# outside the corridor the author cleared, which is how a smoothed
	# rail comes to pass through a wall its control points carefully
	# avoided. Measured on the BAKED curve against the same envelope
	# every other piece of room geometry is held to, rather than against
	# a deviation number chosen by hand.
	if bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0:
		var room := RoomContract.envelope(bounds)
		for point: Vector3 in polyline():
			if room.has_point(point):
				continue
			out.append("%s: the smoothed curve reaches %v, outside the "
					% [who, point] + "room's own envelope %v to %v"
					% [room.position, room.end])
			break

	if length() <= 0.0:
		out.append("%s: the path has no length" % who)
	return out

## How far the smoothed curve bows away from the straight route its
## control points draw. Diagnostic: it is the number that says how much
## interpolation is happening, and the thing that must not happen is
## leaving the room, which `violations` measures directly.
func bow() -> float:
	var worst := 0.0
	for point: Vector3 in polyline():
		worst = maxf(worst, _off_control_polyline(point))
	return worst

## Where the path is, this far along it.
func at(offset: float) -> Vector3:
	return _curve.sample_baked(clampf(offset, 0.0, length()), true)

## Which way it points, this far along it. Always unit, always defined:
## at the very end the baked sample repeats, so the tangent is taken
## from a step BACK rather than a step forward.
func tangent(offset: float) -> Vector3:
	var span := maxf(length(), 0.0001)
	var here := clampf(offset, 0.0, span)
	var step := minf(BAKE_INTERVAL, span * 0.5)
	var ahead := minf(here + step, span)
	var behind := maxf(ahead - step, 0.0)
	var dir := at(ahead) - at(behind)
	return dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD

## How far along the path the point nearest `world` sits.
##
## Sampled rather than solved. `Curve3D.get_closest_offset` exists and
## uses the same baked cache, but it is documented against the baked
## POINTS rather than the baked length and has bitten enough projects
## that walking our own explicit interval is worth the handful of
## iterations -- and it is the same interval everything else here uses.
func nearest_offset(world: Vector3) -> float:
	var span := length()
	var best := 0.0
	var best_d := INF
	var steps := int(ceil(span / BAKE_INTERVAL)) + 1
	for i in steps:
		var offset := minf(float(i) * BAKE_INTERVAL, span)
		var d := at(offset).distance_squared_to(world)
		if d < best_d:
			best_d = d
			best = offset
	return best

## The path as a polyline, for a mesh, a volume or a probe.
##
## The SAME sampling everything else uses, so the beam the player sees,
## the volume they enter and the path they ride are one shape rather than
## three that agree today.
func polyline(step := BAKE_INTERVAL) -> PackedVector3Array:
	var out := PackedVector3Array()
	var span := length()
	var walk := maxf(step, 0.01)
	var n := int(ceil(span / walk))
	for i in n + 1:
		out.append(at(minf(float(i) * walk, span)))
	return out

## How far a point is from the straight route the control points draw.
func _off_control_polyline(at: Vector3) -> float:
	var best := INF
	for i in _points.size() - 1:
		best = minf(best, at.distance_to(
				Geometry3D.get_closest_point_to_segment(
					at, _points[i], _points[i + 1])))
	return best

## The control polyline: one point per authored control point.
##
## `build_rail_along` sweeps a box per segment, and sweeping one per
## BAKED sample would put two hundred boxes on a twelve-metre rail. A
## straight-segment curve is exactly its control points, so for the paths
## this slice builds these two agree by construction -- and the test says
## so rather than the comment.
func segments() -> PackedVector3Array:
	return _points
