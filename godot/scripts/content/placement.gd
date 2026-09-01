class_name Placement
extends RefCounted
## The ONE search for a spot inside a `stand` Surface (P2, owner ruling
## C(ii)).
##
## WHAT A SURFACE PROMISES, in the owner's words:
##
##     this bounded region is OFFERED to a placement consumer, and
##     Production can find a physically valid placement somewhere within
##     it.
##
## It is the same shape as "a socket is an offer, not an order". A
## Surface does NOT promise that every point of its rect is clear, that
## its centre is clear, or that the producer tessellated around the
## stairs and daises standing on it. The room contract is an API for
## usable space, not a decomposition of every mesh top face into
## maximally clear rectangles.
##
## A Surface with ZERO valid placements is invalid, and stays invalid.
##
## WHY THE SEARCH LIVES IN ONE PLACE. Two consumers ask about the same
## region and they must not answer differently:
##
##   * `RoomAudit` asks "CAN this Surface keep its promise?"
##   * `Activities` asks "WHERE is the valid point?"
##
## If those two disagree, the contract is broken -- the audit passes a
## surface and the composer puts a puzzle element under the staircase on
## it, which is the console-under-the-stairs shape of every placement
## defect this project has paid for. So the candidate set, the order it
## is walked, the footprint rule and the verdict all live here, once.
##
## WHAT DOES NOT LIVE HERE: the EVIDENCE. The two callers cannot see the
## same things and pretending otherwise would be the lie:
##
##   * the audit runs on a room that is IN THE TREE, so it measures with
##     rays and shape queries -- the authority.
##   * `Activities` runs inside `build_chamber`, on a root that is still
##     DETACHED, so there is no physics space to query and it must use
##     the box derivation (`ChamberBuilders.solid_boxes` plus the
##     builder's `reserved` regions).
##
## So each caller passes a `clear` Callable and this file decides
## nothing about how they see -- only what counts as a placement, where
## to look for one, and in what order. The suite pins the two verdicts
## against each other on every producer, which is the only way to know
## the split has not become a disagreement.
##
## NO PERCENTAGE IS LAW. The 15x15 usable-area sweep that diagnosed the
## eight authored shells is evidence and reporting, and `usable` below
## still reports it. Validity is geometric and nothing else: there
## exists a footprint that fits.

## Candidates per axis. Nine, because that is what `Activities` has
## always swept and this search replaces that sweep rather than adding a
## second one beside it -- a different number would move every element
## in every existing room.
const GRID := 9

## How far above the surface the clearance volume starts, so a footprint
## resting ON the floor is not reported as being INSIDE it.
const LIFT := 0.02

## Every footprint centre that lies wholly inside the region, in the one
## order both callers walk.
##
## Row major over a fixed grid, no randomness, no reroll: the same room
## yields the same list on every machine and every run, which is what
## lets a Zone be a digest.
##
## The whole FOOTPRINT stays inside the region, not merely its origin.
## Checking the origin is what once put a row of switches 0.7 m through
## a wall.
static func candidates(at: Vector3, extent: Vector3, foot: Vector3,
		height := 0.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var span_x := maxf(extent.x - foot.x, 0.0)
	var span_z := maxf(extent.z - foot.z, 0.0)
	for xi in GRID:
		for zi in GRID:
			var u := 0.5 if GRID < 2 else float(xi) / float(GRID - 1)
			var v := 0.5 if GRID < 2 else float(zi) / float(GRID - 1)
			out.append(Vector3(
					at.x - span_x / 2.0 + span_x * u,
					at.y + height,
					at.z - span_z / 2.0 + span_z * v))
	return out

## Can this region hold this footprint at all?
##
## Returns the region's own dimensions verdict, before any evidence: a
## rect narrower than the thing that must sit on it has no candidates,
## and `candidates` would hand back nine identical clamped points rather
## than saying so.
static func holds(extent: Vector3, foot: Vector3) -> bool:
	return extent.x >= foot.x and extent.z >= foot.z

## The volume a consumer needs ABOVE the surface it stands on.
##
## Above, and that is the point. A footprint resting on a floor slab
## overlaps that slab, so a clearance test that started at the surface
## would refuse every placement in the game. What matters is what is
## over the spot -- a deck, a staircase, the next rubble stone -- which
## is exactly the geometry that made half the authored findings.
static func clearance(at: Vector3, foot: Vector3, tall: float) -> AABB:
	return AABB(Vector3(at.x - foot.x / 2.0, at.y + LIFT,
			at.z - foot.z / 2.0),
			Vector3(foot.x, maxf(tall - LIFT, 0.01), foot.z))

## THE VERDICT. The first candidate this caller's evidence calls clear,
## or {} if the region cannot keep its promise.
##
## `clear` is called with each candidate in order and answers for that
## caller's own consumer: the audit measures a player standing there,
## `Activities` measures the element it is about to place. Whatever the
## consumer, the answer to "is there one" and the answer to "which one"
## come from this loop.
##
## `usable` is diagnostic and is NOT a threshold. It is counted only
## when `census` is asked for, because counting every candidate costs a
## physics query per point and the runtime wants the first hit.
static func find(at: Vector3, extent: Vector3, foot: Vector3,
		height: float, clear: Callable, census := false) -> Dictionary:
	if not holds(extent, foot):
		return {"fits": false, "reason": "too_small", "usable": 0,
				"checked": 0}
	var spots := candidates(at, extent, foot, height)
	var found := Vector3.ZERO
	var have := false
	var usable := 0
	for spot: Vector3 in spots:
		if not bool(clear.call(spot)):
			continue
		usable += 1
		if not have:
			found = spot
			have = true
		if not census:
			break
	if not have:
		return {"fits": false, "reason": "occluded", "usable": 0,
				"checked": spots.size()}
	return {"fits": true, "position": found, "usable": usable,
			"checked": spots.size()}
