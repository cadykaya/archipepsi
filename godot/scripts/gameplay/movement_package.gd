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
		_rails(root, room, built, declined)
	if _wants("launch_source", only):
		_launches(root, room, clear, supported, built, declined)
	return {"built": built, "declined": declined}

static func _wants(kind: String, only: Array) -> bool:
	return only.is_empty() or only.has(kind)

static func _rails(root: Node3D, room: Dictionary, built: Array,
		declined: Array) -> void:
	for offer: Variant in RoomContract.offers_of(room, "rail_route"):
		var entry: Dictionary = offer
		var named := str(entry.get("name", "rail"))
		var points := PackedVector3Array()
		for raw: Variant in entry.get("points", []) as Array:
			points.append(raw as Vector3)
		var rail := RailPath.from_points(points)
		var refusals := rail.violations(named)
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
