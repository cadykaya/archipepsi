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
## empty for everything it understands.
##
## THE EVIDENCE IS A PHYSICS SPACE, NOT TWO CALLABLES (owner ruling,
## 2026-09-03). This took `clear` and `supported` from its caller, and
## every one of the eight callers in this repository passed a constant or
## a half-space predicate over a bare box. The rules and the geometry
## they judge had never met. A space cannot be faked by a lambda that
## says `true`, which is the whole reason the signature changed rather
## than the callers being asked to behave.
##
## A REFUSAL IS NOT A CLEAN PASS. A detached root or a null space answers
## every probe with "nothing there", so it is refused by name here and
## `refused` is set -- the same guard `RoomAudit.findings` carries, for
## the same reason.
static func consume(root: Node3D, room: Dictionary,
		space: PhysicsDirectSpaceState3D, only: Array = []) -> Dictionary:
	var built: Array = []
	var declined: Array = []
	var why := SpaceProbe.refusal(root, space, "offers")
	if why != "":
		return {"built": built, "refused": true,
				"declined": [{"name": "*", "kind": "*", "why": why}]}
	# THE ONE ROOM-LOCAL -> WORLD TRANSFORM, derived from the live root
	# and derived ONCE.
	#
	# THE SEAM THIS CLOSES. Authored offers are room-local, `ZoneBuilder`
	# places each chamber at a nonzero translation and yaw, and
	# `PhysicsDirectSpaceState3D` queries are WORLD space. So the first
	# version of this binding handed local coordinates straight to the
	# probe and measured a point somewhere else entirely -- and every
	# authored-shell test placed its root at identity, where the two
	# frames coincide, so nothing caught it. A test whose fixture sits at
	# the origin cannot see an origin bug.
	#
	# Authored dictionaries and the nodes parented into the room STAY
	# LOCAL: the content contract is local by definition and turning it
	# into world coordinates would make a room mean something different
	# depending on where it was placed. Only the QUERIES move.
	var to_world := root.global_transform
	if _wants("rail_route", only):
		_rails(root, room, space, to_world, built, declined)
	if _wants("launch_source", only):
		_launches(root, room, space, to_world, built, declined)
	if _wants("grapple_point", only):
		_grapples(room, space, to_world, built, declined)
	return {"built": built, "declined": declined, "refused": false}

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
## CONTINUOUS, WITH NO STRIDE (owner ruling, 2026-09-03).
##
## What was here walked down in 2 m steps asking a window at each one,
## and was wrong in BOTH directions from two different causes. A window
## narrower than the stride leaves a blind band per step: three real
## anchors over a basin floor at y=0 were refused because the floor fell
## between the samples at 1.4 and -0.6. And a window reaches past the
## thing it asks about at both ends, so the same loop accepted hang space
## shallower than `SWING_ROOM` and ground deeper than `GRAPPLE_DROP`.
## Widening the window fixes the first and worsens the second. No width
## is right, because it was never a window question.
##
## So: ONE measured distance, compared against BOTH bounds, and a SWEPT
## hang column instead of two endpoint samples. The stride is deleted
## rather than tuned.
##
## The reach looks `SWING_ROOM` further than the limit on purpose -- a
## floor at 34 m has to be FOUND to be reported as too deep, and a probe
## that stops at 30 m cannot tell "past the limit" from "a void".
static func _grapples(room: Dictionary, space: PhysicsDirectSpaceState3D,
		to_world: Transform3D, built: Array, declined: Array) -> void:
	for offer: Variant in RoomContract.offers_of(room, "grapple_point"):
		var entry: Dictionary = offer
		var named := str(entry.get("name", "grapple"))
		# `at` stays the AUTHORED point, because that is what a message
		# has to name for anyone to find it. `world` is what the physics
		# is asked about. The two are the same only at identity.
		var at: Vector3 = entry["position"]
		var world := to_world * at
		var why := ""
		var blocker := SpaceProbe.obstruction(space, world)
		var ground := SpaceProbe.ground_below(space, world,
				GRAPPLE_DROP + SWING_ROOM)
		if blocker != null and ground != SpaceProbe.NO_GROUND \
				and world.y - ground < SWING_ROOM:
			# THE RIGHT DIAGNOSIS OF THE SAME GEOMETRY. An anchor sitting
			# less than a body's clearance above its own floor is blocked
			# BY that floor, and calling it "inside solid geometry" sends
			# whoever has to fix it looking for a wall. The plenum's
			# `grapple_1` is 0.762 m over a tread: too close, not buried.
			why = ("there is no room to hang or swing under the anchor "
					+ "at %v: the ground (%s) is %.2f m down and %.1f m "
					% [at, blocker.name, world.y - ground, SWING_ROOM]
					+ "is the minimum")
		elif blocker != null:
			why = ("the anchor at %v is inside solid geometry (%s)"
					% [at, blocker.name])
		elif ground == SpaceProbe.NO_GROUND:
			why = ("nothing within %.0f m under the anchor at %v is "
					% [GRAPPLE_DROP, at] + "ground to leave from or "
					+ "arrive at")
		elif world.y - ground < SWING_ROOM:
			# NAMING THE FLOOR THAT IS TOO CLOSE. Same ray as the height,
			# so the number and the thing that produced it cannot come
			# from two different queries.
			var under := SpaceProbe.ground_collider(space, world,
					GRAPPLE_DROP + SWING_ROOM)
			why = ("there is no room to hang or swing under the anchor "
					+ "at %v: the ground (%s) is %.2f m down and %.1f m "
					% [at, ("?" if under == null else under.name),
						world.y - ground, SWING_ROOM] + "is the minimum")
		elif world.y - ground > GRAPPLE_DROP:
			why = ("the ground under the anchor at %v is %.2f m down, "
					% [at, world.y - ground] + "past the %.0f m that is "
					% GRAPPLE_DROP + "still something to leave from")
		else:
			# THE WHOLE COLUMN, swept. Two endpoint samples say nothing
			# about the middle, and the middle is where a beam crosses.
			var hit: Variant = SpaceProbe.first_block_point(space,
					world, world - Vector3.UP * SWING_ROOM)
			if hit != null:
				var named_by := SpaceProbe.blocker_name(space,
						hit as Vector3)
				# Reported back in the room's own frame: an artist who
				# reads a world coordinate has to undo the placement to
				# find the metre it names.
				var local_hit: Vector3 = to_world.affine_inverse() \
						* (hit as Vector3)
				why = ("there is no room to hang or swing under the "
						+ "anchor at %v: blocked at %v" % [at, local_hit]
						+ ("" if named_by == "" else " by %s" % named_by))
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

## THE BAKED CURVE AND THE BEAM ON IT (owner ruling, 2026-09-03).
##
## Two things were wrong with checking the centreline against a player
## capsule. The route that gets built is the SMOOTHED curve, not the
## control polyline -- a Catmull-Rom cuts its corners, and a rail whose
## twelve control points all sit 3.8 cm outside a ring dips 45 cm inside
## it between them. And what has to fit is the BEAM, which is 0.35 m
## thick: asking the player's own capsule refuses routes a beam threads
## and passes routes it does not.
static func _rails(root: Node3D, room: Dictionary,
		space: PhysicsDirectSpaceState3D, to_world: Transform3D,
		built: Array, declined: Array) -> void:
	for offer: Variant in RoomContract.offers_of(room, "rail_route"):
		var entry: Dictionary = offer
		var named := str(entry.get("name", "rail"))
		var points := PackedVector3Array()
		for raw: Variant in entry.get("points", []) as Array:
			points.append(raw as Vector3)
		var rail := RailPath.from_points(points)
		var refusals := rail.violations(named,
				room.get("bounds", AABB()) as AABB)
		# THE SMOOTHED ROUTE, against the room it runs through, at the
		# beam's own half-thickness. Control points can each sit in clear
		# air while the curve between them bows into a pillar, so what is
		# checked is what is built.
		if refusals.is_empty():
			var half := AffordanceFeatures.RAIL_BEAM_THICKNESS / 2.0
			for point: Vector3 in rail.polyline():
				# THE BAKED POINT IS LOCAL; THE PROBE IS WORLD. The rail
				# object stays in the room's frame -- it is what gets
				# parented into the room and ridden -- and only the query
				# crosses over.
				var blocker := SpaceProbe.sphere_obstruction(space,
						to_world * point, half)
				if blocker == null:
					continue
				refusals.append("%s: the smoothed curve puts the beam "
						% named + "through geometry at %v (%s)"
						% [point, blocker.name])
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
static func _launches(root: Node3D, room: Dictionary,
		space: PhysicsDirectSpaceState3D, to_world: Transform3D,
		built: Array, declined: Array) -> void:
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
				float(landing.get("radius", 0.0)), space, to_world,
				named)
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
