class_name MovementPackage
extends RefCounted
## What a room OFFERS, and what a package chooses to build (P3.0).
##
## THE SEAM, and the minimum harness that proves it is real. A large
## authored shell declares `offers` -- a rail route, a launch source, a
## landing region -- and this consumes the ones it understands. It is
## deliberately NOT a gameplay system: no scoring, no progression, no
## content. It exists so the offer vocabulary has a consumer, because a
## kind with no consumer is a kind nobody can be held to.
##
## AN OFFER IS NOT AN ORDER. Three things follow, and each is tested:
##
##   * a package may DECLINE. `only` restricts what it will look at, and
##     a package that consumes nothing must leave a working room -- the
##     same shell has to play as ordinary combat space with no traversal
##     mechanic in it at all.
##   * a package must VALIDATE what it builds. A declared rail route
##     that is not a shape a rider can hold is refused here, not
##     discovered under a player. A launch whose arc is blocked, whose
##     landing has no floor, or whose landing is a pinpoint is refused
##     the same way.
##   * a refusal is REPORTED, never silent. `declined` carries the
##     offer's name and the reason, because a large room whose traversal
##     quietly did not appear is the worst version of this failure.
##
## NOT BAKED IN. The shell says a rail COULD run here; it does not
## contain a rail. The identical shell handed to a launch package builds
## launch pads and no rail, and handed to nothing builds neither.

## Consume this room's offers into `root`.
##
## `only` is the package's own appetite -- an array of offer kinds, or
## empty for everything it understands. `clear` and `supported` are the
## caller's physical evidence, exactly as `Placement.find` takes them:
## the audit has a physics space, a composer building a detached chamber
## does not, and pretending otherwise is how a validator comes to bless
## geometry it cannot see.
static func consume(root: Node3D, room: Dictionary, clear: Callable,
		supported: Callable, only: Array = []) -> Dictionary:
	var built: Array = []
	var declined: Array = []
	if _wants("rail_route", only):
		_rails(root, room, built, declined, clear)
	if _wants("launch_source", only):
		_launches(root, room, clear, supported, built, declined)
	if _wants("grapple_point", only):
		_grapples(room, clear, supported, built, declined)
	return {"built": built, "declined": declined}

## How much clear air a grapple point needs under it. A player's own
## height plus their reach: whatever the verb turns out to be, something
## has to hang, swing or be pulled through the space below the anchor,
## and an anchor with a slab 0.5 m beneath it offers none of that.
const SWING_ROOM := 4.0

## How far below an anchor the ground may be and still be the thing you
## leave from or arrive at. Past this the anchor is over a void and the
## opportunity is a fall.
const GRAPPLE_DROP := 30.0

## A grapple point is VALIDATED and never BUILT.
##
## There is no grapple mechanic in this engine to construct, and
## inventing one here would be exactly the "bake a mechanic into the
## shell" the contract forbids. What a package can do -- and what makes
## `grapple_point` a kind with a real consumer rather than a word in a
## list -- is decide whether the opportunity is geometrically true, so
## that what reaches Epsilon is an offer somebody could actually take.
static func _grapples(room: Dictionary, clear: Callable,
		supported: Callable, built: Array, declined: Array) -> void:
	for offer: Variant in RoomContract.offers_of(room, "grapple_point"):
		var entry: Dictionary = offer
		var named := str(entry.get("name", "grapple"))
		var at: Vector3 = entry["position"]
		var why := ""
		if not bool(clear.call(at)):
			why = "the anchor at %v is inside solid geometry" % at
		elif not bool(clear.call(at - Vector3.UP * SWING_ROOM)):
			why = ("there is no room to hang or swing under the anchor "
					+ "at %v" % at)
		else:
			var floor_found := false
			var drop := SWING_ROOM
			while drop <= GRAPPLE_DROP:
				if bool(supported.call(at - Vector3.UP * drop)):
					floor_found = true
					break
				drop += 2.0
			if not floor_found:
				why = ("nothing within %.0f m under the anchor at %v is "
						% [GRAPPLE_DROP, at] + "ground to leave from or "
						+ "arrive at")
		if why != "":
			declined.append({"name": named, "kind": "grapple_point",
					"why": why})
			continue
		# AVAILABLE, not built. The verb is Epsilon's to choose.
		built.append({"name": named, "kind": "grapple_point",
				"position": at,
				"radius": float(entry.get("radius", 0.0))})

static func _wants(kind: String, only: Array) -> bool:
	return only.is_empty() or only.has(kind)

static func _rails(root: Node3D, room: Dictionary, built: Array,
		declined: Array, clear := Callable()) -> void:
	for offer: Variant in RoomContract.offers_of(room, "rail_route"):
		var entry: Dictionary = offer
		var named := str(entry.get("name", "rail"))
		var points := PackedVector3Array()
		for raw: Variant in entry.get("points", []) as Array:
			points.append(raw as Vector3)
		var rail := RailPath.from_points(points)
		var refusals := rail.violations(named,
				room.get("bounds", AABB()) as AABB)
		# THE SMOOTHED ROUTE, against the room it runs through. Control
		# points can each sit in clear air while the curve between them
		# bows into a pillar, so what is checked is what is built.
		if refusals.is_empty() and clear.is_valid():
			for point: Vector3 in rail.polyline():
				if bool(clear.call(point)):
					continue
				refusals.append("%s: the smoothed curve passes through "
						% named + "geometry at %v" % point)
				break
		if not refusals.is_empty():
			declined.append({"name": named, "kind": "rail_route",
					"why": "; ".join(refusals)})
			continue
		var made := AffordanceFeatures.build_rail(root, rail)
		built.append({"name": named, "kind": "rail_route", "rail": rail,
				"lanes": made["lanes"], "beams": made["beams"]})

## A launch pad is a PAIR: a source to fire from and a target to land in.
## An unpaired half of either is an offer nobody can act on, and saying so
## is more use than building half a traversal.
static func _launches(root: Node3D, room: Dictionary, clear: Callable,
		supported: Callable, built: Array, declined: Array) -> void:
	var targets := RoomContract.offers_of(room, "launch_target")
	for offer: Variant in RoomContract.offers_of(room, "launch_source"):
		var entry: Dictionary = offer
		var named := str(entry.get("name", "launch"))
		var wanted := str(entry.get("target", ""))
		var landing := {}
		for candidate: Variant in targets:
			if str((candidate as Dictionary).get("name", "")) == wanted:
				landing = candidate
		if landing.is_empty():
			declined.append({"name": named, "kind": "launch_source",
					"why": "names no landing region that exists ('%s')"
						% wanted})
			continue
		var source: Vector3 = entry["position"]
		var target: Vector3 = landing["position"]
		var refusals := LaunchSolver.violations(source, target,
				float(landing.get("radius", 0.0)), clear, supported, named)
		if not refusals.is_empty():
			declined.append({"name": named, "kind": "launch_source",
					"why": "; ".join(refusals)})
			continue
		var pad := AffordanceNodes.LaunchPad.new()
		pad.position = source
		pad.target = target
		root.add_child(pad)
		built.append({"name": named, "kind": "launch_source", "pad": pad,
				"target": target})
