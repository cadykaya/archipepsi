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
func violations(who := "rail") -> Array[String]:
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
			out.append("%s: segment %d is %.3f m long; under %.2f m it "
					% [who, i, run, MIN_SEGMENT] + "has no direction")
			continue
		if run > MAX_SEGMENT:
			out.append("%s: segment %d is %.1f m long, past the %.0f m a "
					% [who, i, run, MAX_SEGMENT] + "single span may cover")
		var flat := Vector2(b.x - a.x, b.z - a.z).length()
		var pitch := rad_to_deg(atan2(absf(b.y - a.y), flat)) \
				if flat > 0.001 else 90.0
		if pitch > MAX_PITCH_DEGREES:
			out.append("%s: segment %d pitches %.1f degrees, past the "
					% [who, i, pitch] + "%.0f a rider can hold"
					% MAX_PITCH_DEGREES)
	if length() <= 0.0:
		out.append("%s: the path has no length" % who)
	return out

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

## The control polyline: one point per authored control point.
##
## `build_rail_along` sweeps a box per segment, and sweeping one per
## BAKED sample would put two hundred boxes on a twelve-metre rail. A
## straight-segment curve is exactly its control points, so for the paths
## this slice builds these two agree by construction -- and the test says
## so rather than the comment.
func segments() -> PackedVector3Array:
	return _points
