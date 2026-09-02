class_name TraversalLaw
extends RefCounted
## What a traversal segment CLAIMS, and how each claim is checked (P3.5).
##
## THE DEFECT THIS CLOSES. `ShellValidator._check_segment` applied the
## base-kit JUMP bounds to every mandatory segment whatever its `kind`,
## so a continuous walk across connected ground was read as a jump
## between its endpoints. `shell_hall_transit` is where that surfaced: a
## 3.20 m collar walk failed `max_safe_gap(0)`, and so would its 18 m
## ramp and its 14 m stair, none of which is a jump at all.
##
## A KIND IS A CLAIM, NOT AN EXEMPTION. The fix is emphatically not "skip
## the law when the label says walk" -- that would let a 6 m jump relabel
## itself and walk straight past the movement law, which is the whole
## thing the law exists to stop. Each kind is held to what it claims:
##
##   gap    the player leaves the ground and lands. Bounded by
##          `max_safe_gap(rise)` -- unchanged, and still the law.
##   rise   the player steps up. Bounded by `MAX_VERTICAL_STEP` -- also
##          unchanged.
##   walk   the player never leaves the ground. So the SPAN is not the
##          question and CONNECTEDNESS is: are the two endpoints joined
##          by walkable surface?
##
##          NOT A STRAIGHT-LINE GROUND SAMPLE, and the first draft of
##          this file was exactly that, which is wrong in a way worth
##          recording. A ring collar and a chasm crossing are
##          geometrically IDENTICAL along the chord between their
##          endpoints -- both have solid ground at each end and open air
##          in between -- so a chord test cannot tell a legitimate curved
##          walk from a jump wearing a walk's label, and no tuning makes
##          it able to. It refused `shell_hall_transit`\'s ramp and the
##          collapsed tower\'s deck walk, both of which are real floors.
##
##          So the walk is checked against the room\'s own declared
##          `surfaces`: each endpoint must land on one, and the two must
##          be joined by a chain of surfaces that touch within a player\'s
##          width and step by no more than `MAX_VERTICAL_STEP`. A route
##          that curves, switches back or rings a shaft is connected; a
##          chasm is not, because nothing bridges it. Where a producer
##          declares no surfaces at all there is nothing to walk on, and
##          the straight-line ground sample is kept as the only evidence
##          available.
##   drop   the player falls to a lower surface. Bounded by nothing here;
##          falling is always possible, and how far is a damage question.
##
## ONE RULE, TWO EVIDENCES. `ShellValidator` runs at import on a detached
## scene and can only read mesh boxes; `RoomAudit` runs on a room in the
## tree and casts rays. Both call THIS, passing a `ground` Callable that
## answers "how high is the floor under this point, or -INF". The law is
## stated once; only the way of seeing differs. That is the same split
## `Placement.find` already uses, for the same reason.

## How finely a walk is sampled, in metres. Fine enough that a hole a
## player could fall through cannot hide between two samples: the
## narrowest gap worth catching is about a player's width.
const WALK_STEP := 0.6

## Slack on a measurement, matching `RoomAudit.AS_BUILT_SLACK`: vertex
## data is quantised and a step modelled at exactly the limit must not
## fail for its own rounding.
const AS_BUILT_SLACK := 0.01

## The kinds a segment may claim.
const KINDS := ["gap", "rise", "drop", "walk"]

## Every way this MEASURED movement is outside what its kind claims.
##
## `start` and `end` are the measured endpoints, in whatever space
## `ground` answers in. Empty is a segment that means what it says.
static func violations(kind: String, start: Vector3, end: Vector3,
		ground: Callable, who := "traversal",
		surfaces: Array = []) -> Array[String]:
	var out: Array[String] = []
	if not KINDS.has(kind):
		out.append("%s: kind '%s' is not one a segment may claim (%s)"
				% [who, kind, ", ".join(KINDS)])
		return out
	var rise := end.y - start.y
	var span := Vector2(end.x - start.x, end.z - start.z).length()

	if kind == "walk":
		return _walk_is_connected(start, end, surfaces, ground, who)

	# A drop is a fall. There is no reach to exceed and no step to be too
	# tall -- gravity does it whatever anyone declares -- so the only
	# thing that would be wrong here is claiming a drop that goes UP.
	if kind == "drop":
		if rise > AS_BUILT_SLACK:
			out.append("%s: is declared a drop and rises %.2f m"
					% [who, rise])
		return out

	if kind == "rise" and rise > Constants.MAX_VERTICAL_STEP + AS_BUILT_SLACK:
		out.append("%s: rises %.2f m as built; the base kit tops out at "
				% [who, rise] + "%.2f m" % Constants.MAX_VERTICAL_STEP)
	var allowed := Constants.max_safe_gap(maxf(rise, 0.0))
	if span > allowed + AS_BUILT_SLACK:
		out.append("%s: spans %.2f m at a %.2f m rise as built; the base "
				% [who, span, rise] + "kit's safe reach there is %.2f m"
				% allowed)
	return out

## Are these two ends joined by walkable surface?
##
## THE ANTI-LOOPHOLE. A jump relabelled `walk` fails here because nothing
## connects its ends: the surface under one and the surface under the
## other never touch, and there is no chain between them. What it does
## NOT do is assume the player walks in a straight line, which is what
## makes a ring, a switchback and a spiral ramp legal.
static func _walk_is_connected(start: Vector3, end: Vector3,
		surfaces: Array, ground: Callable, who: String) -> Array[String]:
	var out: Array[String] = []
	var from := _surface_under(start, surfaces)
	var to := _surface_under(end, surfaces)
	if from < 0 or to < 0:
		# The room declares no surface under one of the ends, so there is
		# no graph to walk. Fall back to the only evidence there is --
		# and SAY which end was undeclared, because "no ground" and "no
		# declaration over ground that is there" send whoever fixes it to
		# two different files.
		var which := "start" if from < 0 else "end"
		var loose: Vector3 = start if from < 0 else end
		var underfoot: float = ground.call(loose)
		var note := ("%s: its %s at %v is on no declared walkable "
				% [who, which, loose] + "surface")
		if underfoot == -INF or not is_finite(underfoot):
			return [note + ", and there is no geometry under it either"]
		var report := _the_ground_is_continuous(start, end, ground, who)
		if report.is_empty():
			return [note + ", though geometry is there at y=%.2f -- the "
					% underfoot + "surfaces do not describe the floor "
					+ "this walk uses"]
		return report
	if from == to:
		return out
	var seen := {from: true}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var here: int = queue.pop_front()
		if here == to:
			return out
		for other in surfaces.size():
			if seen.has(other):
				continue
			if not _surfaces_touch(surfaces[here], surfaces[other]):
				continue
			seen[other] = true
			queue.append(other)
	out.append("%s: is declared a walk, and '%s' and '%s' are not joined "
			% [who, _named(surfaces[from]), _named(surfaces[to])]
			+ "by any chain of walkable surface")
	return out

static func _named(surface: Variant) -> String:
	return str((surface as Dictionary).get("name", "?"))

## The declared surface an endpoint stands on: nearest in height, with
## the point inside its rect allowing for the player's own width.
static func _surface_under(at: Vector3, surfaces: Array) -> int:
	var best := -1
	var best_drop := INF
	var grip := Constants.PLAYER_RADIUS
	for i in surfaces.size():
		var patch: Dictionary = surfaces[i]
		var here: Vector3 = patch.get("position", Vector3.ZERO)
		var extent: Vector3 = patch.get("extent", Vector3.ZERO)
		if absf(at.x - here.x) > extent.x / 2.0 + grip:
			continue
		if absf(at.z - here.z) > extent.z / 2.0 + grip:
			continue
		var drop: float = absf(at.y - here.y)
		if drop > Constants.MAX_VERTICAL_STEP + AS_BUILT_SLACK:
			continue
		if drop < best_drop:
			best_drop = drop
			best = i
	return best

## Two surfaces a player can step between: their footprints meet within a
## player's width, and the step between them is one the base kit climbs.
static func _surfaces_touch(a: Variant, b: Variant) -> bool:
	var pa: Dictionary = a
	var pb: Dictionary = b
	var at: Vector3 = pa.get("position", Vector3.ZERO)
	var bt: Vector3 = pb.get("position", Vector3.ZERO)
	if absf(at.y - bt.y) > Constants.MAX_VERTICAL_STEP + AS_BUILT_SLACK:
		return false
	var ea: Vector3 = pa.get("extent", Vector3.ZERO)
	var eb: Vector3 = pb.get("extent", Vector3.ZERO)
	var grip := Constants.PLAYER_RADIUS * 2.0
	if absf(at.x - bt.x) > (ea.x + eb.x) / 2.0 + grip:
		return false
	if absf(at.z - bt.z) > (ea.z + eb.z) / 2.0 + grip:
		return false
	return true

## A walk is a claim about the GROUND, so the ground is what is measured.
##
## THIS IS WHAT STOPS THE LABEL BEING A LOOPHOLE. Sampled end to end: a
## missing sample is a hole, and a step between samples bigger than
## `MAX_VERTICAL_STEP` is a cliff or a wall. A six-metre jump relabelled
## `walk` fails on the first sample over the void, which is both a
## refusal and an accurate description of what is wrong with it.
static func _the_ground_is_continuous(start: Vector3, end: Vector3,
		ground: Callable, who: String) -> Array[String]:
	var out: Array[String] = []
	var run := start.distance_to(end)
	var steps := maxi(2, int(ceil(run / WALK_STEP)) + 1)
	var previous := INF
	for i in steps:
		var t := float(i) / float(steps - 1)
		var here := start.lerp(end, t)
		var floor_y: float = ground.call(here)
		if floor_y == -INF or not is_finite(floor_y):
			out.append("%s: is declared a walk and has no ground under it "
					% who + "%.0f%% of the way along" % (t * 100.0))
			return out
		if previous != INF:
			var step: float = absf(floor_y - previous)
			if step > Constants.MAX_VERTICAL_STEP + AS_BUILT_SLACK:
				out.append("%s: is declared a walk and the ground steps "
						% who + "%.2f m at %.0f%% along; the base kit "
						% [step, t * 100.0] + "climbs %.2f m"
						% Constants.MAX_VERTICAL_STEP)
				return out
		previous = floor_y
	return out

## The highest mesh box under `at`, or -INF. The evidence a DETACHED
## scene can give: no physics space exists at import time.
##
## `reach` bounds how far below the sample a surface may be and still be
## the thing being walked on -- past that it is the floor of the room,
## not the walkway, and reporting it as support would be how a bridge
## over a chasm passes.
## A PLAYER HAS WIDTH, so ground within their own radius is ground under
## them. Without this a walk whose endpoint sits exactly on the seam
## between two surfaces -- which is where a walk's endpoints naturally
## sit -- finds nothing directly beneath the declared point and reports a
## hole in a floor that is continuous. Bounded by `PLAYER_RADIUS` rather
## than a chosen epsilon: a real hole a player falls through is wider
## than the player, and the ones this bridges are ones they would bridge.
static func mesh_ground(boxes: Array[AABB], at: Vector3,
		reach := 2.0) -> float:
	var best := -INF
	var grip := Constants.PLAYER_RADIUS
	for box: AABB in boxes:
		if at.x < box.position.x - grip or at.x > box.end.x + grip:
			continue
		if at.z < box.position.z - grip or at.z > box.end.z + grip:
			continue
		var top := box.end.y
		if top > at.y + Constants.MAX_VERTICAL_STEP:
			continue
		if top < at.y - reach:
			continue
		best = maxf(best, top)
	return best
