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
##          So the walk is proven by FLOODING PHYSICAL EVIDENCE: a
##          bounded search over player-sized samples, where a node exists
##          only where the evidence says there is support at a walkable
##          height AND the player\'s body fits, and two nodes are joined
##          only when they are a player-step apart in both senses --
##          adjacent on the ground and within `MAX_VERTICAL_STEP` of each
##          other. A route that curves, switches back or rings a shaft
##          floods; a chasm does not, because no node exists over it.
##
##          DECLARED SURFACES BOUND THE SEARCH; THEY DO NOT PROVE IT.
##          That distinction is the whole of P3.5A and it is forced by
##          owner ruling C(ii): a `stand` Surface promises that a valid
##          placement can be FOUND inside it, never that its whole rect
##          is ground. So a single valid Surface may legitimately span a
##          six-metre chasm -- and the version of this file that passed a
##          walk the moment both ends landed in the same Surface called
##          that chasm walkable. Rectangles that overlap in the manifest
##          were likewise taken as an edge, whatever the geometry between
##          them did. Both are unsound, and both are gone: the rects are
##          now only the region the flood is allowed to search.
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
		ground: Callable, who := "traversal", surfaces: Array = [],
		fits := Callable()) -> Array[String]:
	var out: Array[String] = []
	if not KINDS.has(kind):
		out.append("%s: kind '%s' is not one a segment may claim (%s)"
				% [who, kind, ", ".join(KINDS)])
		return out
	var rise := end.y - start.y
	var span := Vector2(end.x - start.x, end.z - start.z).length()

	if kind == "walk":
		return _walk_is_evidenced(start, end, surfaces, ground, fits, who)

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

## How far apart the witness samples sit: the player's RADIUS, not their
## width.
##
## Measured, not chosen. At one player width the lattice is anchored on
## the start and lands wherever that puts it -- and on
## `shell_tower_spiral` it put every sample in the riser column of a
## legal 1.0 m step, finding no floor there and declaring a walkable
## route disconnected. Sampling at the radius means no feature narrower
## than the player's own body can fall between two samples, which is the
## resolution the question is actually asked at.
const WALK_GRID := Constants.PLAYER_RADIUS

## How far outside the declared surfaces the flood may look. A walk's
## endpoints sit at the lip of a surface by nature, and a route may pass
## along a ledge the manifest describes a little tightly.
const DOMAIN_MARGIN := 1.5

## How far around the straight line the flood may search when the room
## declares no surfaces at all. Wide enough to route around an obstacle,
## bounded so a search cannot become a survey.
const OPEN_DOMAIN := 8.0

## The most samples the witness may visit. A cap, and it FAILS CLOSED: a
## route that cannot be proven inside it is reported unproven rather than
## quietly accepted, because "we ran out of budget" is not evidence.
const MAX_WITNESS_NODES := 8000

## Is there a physically evidenced route from one end to the other?
##
## FLOOD, NOT CHORD, AND NOT DECLARATION. Sampled on a player-sized grid:
## a node exists only where the evidence finds support at a walkable
## height and the player's body fits standing on it, and an edge exists
## only between neighbouring nodes within one `MAX_VERTICAL_STEP`. That
## makes a ring, a switchback and a spiral ramp all provable without ever
## assuming the player walks in a straight line, and makes a chasm
## unprovable however the manifest describes it.
static func _walk_is_evidenced(start: Vector3, end: Vector3,
		surfaces: Array, ground: Callable, fits: Callable,
		who: String) -> Array[String]:
	var domain := _search_domain(start, end, surfaces)
	# THE MARKER IS WHERE THE MOVEMENT IS MEASURED, not where the player
	# must stand. A walk's endpoints sit at the lip of a surface by
	# nature, and a capsule placed exactly on a seam clips the step
	# beside it -- so the flood is SEEDED from the standable ground in
	# the endpoint's own neighbourhood. What it may never do is invent a
	# seed where none of that neighbourhood is standable.
	var begin := _seed(start, ground, fits)
	if begin.is_empty():
		return ["%s: is declared a walk and there is nowhere within a "
				% who + "step of its start at %v a player can stand"
				% start]
	# The far end gets the same neighbourhood tolerance as the start, and
	# for the same reason: a marker on the seam between a step and the
	# landing it meets has no ground in its own column, and that is a
	# fact about where the marker was put rather than about the floor.
	var landing := _seed(end, ground, Callable())
	if landing.is_empty():
		return ["%s: is declared a walk and there is no ground within a "
				% who + "step of its end at %v" % end]
	var finish: float = landing[2]

	var seen := {}
	var queue: Array = [begin]
	seen[_cell(float(begin[0]), float(begin[1]), start)] = true
	var visited := 0
	while not queue.is_empty():
		var here: Array = queue.pop_front()
		var hx: float = here[0]
		var hz: float = here[1]
		var hy: float = here[2]
		if Vector2(hx - end.x, hz - end.z).length() <= WALK_GRID \
				and absf(hy - finish) <= Constants.MAX_VERTICAL_STEP:
			return []
		visited += 1
		if visited > MAX_WITNESS_NODES:
			return ["%s: is declared a walk and no route could be proven "
					% who + "within %d samples; it is too sprawling to "
					% MAX_WITNESS_NODES + "verify, not thereby safe"]
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nx: float = hx + float(dx) * WALK_GRID
				var nz: float = hz + float(dz) * WALK_GRID
				var key := _cell(nx, nz, start)
				if seen.has(key):
					continue
				if not _inside(nx, nz, domain):
					continue
				seen[key] = true
				# The probe looks from the height we are STANDING at, so
				# a step is measured from where the player is rather
				# than from a nominal plane.
				var ny := _stand_at(Vector3(nx, hy, nz), hy, ground, fits)
				if ny == -INF:
					continue
				if absf(ny - hy) > Constants.MAX_VERTICAL_STEP \
						+ AS_BUILT_SLACK:
					continue
				queue.append([nx, nz, ny])
	return ["%s: is declared a walk, and no continuous supported route "
			% who + "joins %v to %v -- the ground the declarations "
			% [start, end] + "describe does not connect them"]

## Standable ground within one step of `at`, as [x, z, y], or empty.
##
## The point itself first, then its eight neighbours: a seed one cell to
## the side is the same walkway, and refusing to look there refuses every
## route whose endpoint an artist put on the edge of the surface it
## leaves -- which is where endpoints go.
static func _seed(at: Vector3, ground: Callable,
		fits: Callable) -> Array:
	var here := _stand_at(at, at.y, ground, fits)
	if here != -INF:
		return [at.x, at.z, here]
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var nx: float = at.x + float(dx) * WALK_GRID
			var nz: float = at.z + float(dz) * WALK_GRID
			var ny := _stand_at(Vector3(nx, at.y, nz), at.y, ground, fits)
			if ny != -INF:
				return [nx, nz, ny]
	return []

## The floor a player could stand on at this column, or -INF.
##
## TWO QUESTIONS, and the second is why the evidence interface grew. A
## floor ray says there is something underfoot; it says nothing about
## whether a body fits above it, so a route pinched to half a player's
## height would flood straight through. `fits` answers the second, and a
## caller that supplies none gets support-only evidence and a rule that
## is honestly weaker rather than one that pretends.
static func _stand_at(at: Vector3, reference: float, ground: Callable,
		fits: Callable) -> float:
	var probe := Vector3(at.x, reference, at.z)
	var floor_y: float = ground.call(probe)
	if floor_y == -INF or not is_finite(floor_y):
		return -INF
	if absf(floor_y - reference) > Constants.MAX_VERTICAL_STEP \
			+ AS_BUILT_SLACK:
		return -INF
	if fits.is_valid() \
			and not bool(fits.call(Vector3(at.x, floor_y, at.z))):
		return -INF
	return floor_y

## Where the flood is allowed to look: the declared surfaces, grown a
## little, or a bounded corridor when the room declares none.
##
## THE RECTS BOUND THE SEARCH AND PROVE NOTHING. A surface may be huge,
## may span a chasm, and may be mostly unusable -- C(ii) promises only
## that a valid placement exists somewhere in it. All it does here is
## keep the flood from wandering off into the rest of the room.
static func _search_domain(start: Vector3, end: Vector3,
		surfaces: Array) -> Array:
	var out: Array = []
	for raw: Variant in surfaces:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var patch: Dictionary = raw
		var at: Vector3 = patch.get("position", Vector3.ZERO)
		var extent: Vector3 = patch.get("extent", Vector3.ZERO)
		out.append(Rect2(at.x - extent.x / 2.0 - DOMAIN_MARGIN,
				at.z - extent.z / 2.0 - DOMAIN_MARGIN,
				extent.x + DOMAIN_MARGIN * 2.0,
				extent.z + DOMAIN_MARGIN * 2.0))
	var lo := Vector2(minf(start.x, end.x), minf(start.z, end.z))
	var hi := Vector2(maxf(start.x, end.x), maxf(start.z, end.z))
	var near := Rect2(lo.x - OPEN_DOMAIN, lo.y - OPEN_DOMAIN,
			hi.x - lo.x + OPEN_DOMAIN * 2.0,
			hi.y - lo.y + OPEN_DOMAIN * 2.0)
	if out.is_empty():
		return [near]
	# BOUNDED TWICE, and both are bounds rather than proofs: the flood
	# stays inside the surfaces the room declares AND within reach of the
	# walk it is proving. Without the second, a 60 m hall makes every
	# short walk search the whole floor and run out of budget.
	var clipped: Array = []
	for rect: Rect2 in out:
		var overlap := rect.intersection(near)
		if overlap.size.x > 0.0 and overlap.size.y > 0.0:
			clipped.append(overlap)
	return clipped if not clipped.is_empty() else [near]

static func _inside(x: float, z: float, domain: Array) -> bool:
	for rect: Rect2 in domain:
		if rect.has_point(Vector2(x, z)):
			return true
	return false

## A grid key, anchored on the start so the lattice is the same whichever
## direction the flood runs.
static func _cell(x: float, z: float, anchor: Vector3) -> Vector2i:
	return Vector2i(int(round((x - anchor.x) / WALK_GRID)),
			int(round((z - anchor.z) / WALK_GRID)))

## Does a player's body fit standing on this floor point, judged from
## boxes? The detached half of the evidence interface.
##
## ONLY THE PART OF THE BODY ABOVE STEP HEIGHT. Anything shorter than
## `MAX_VERTICAL_STEP` is something the player steps ONTO, not something
## that blocks them, and a test that refused it would forbid standing
## anywhere within a radius of any ledge -- which is to say it would
## forbid crossing a step at all, since the lattice needs a node either
## side of the riser. What remains is exactly the question worth asking:
## is there room for the player where a step cannot help them.
##
## Conservative on purpose: a convex hull's AABB is bigger than the hull,
## so this refuses a little more than physics would. Refusing a real
## route is a finding somebody reads; accepting an impossible one is a
## player stuck in a wall.
static func boxes_fit(boxes: Array[AABB], at_floor: Vector3) -> bool:
	var body := AABB(
			Vector3(at_floor.x - Constants.PLAYER_RADIUS,
				at_floor.y + Constants.MAX_VERTICAL_STEP + 0.05,
				at_floor.z - Constants.PLAYER_RADIUS),
			Vector3(Constants.PLAYER_RADIUS * 2.0,
				Constants.PLAYER_HEIGHT - Constants.MAX_VERTICAL_STEP,
				Constants.PLAYER_RADIUS * 2.0))
	for box: AABB in boxes:
		if box.intersects(body):
			return false
	return true

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
