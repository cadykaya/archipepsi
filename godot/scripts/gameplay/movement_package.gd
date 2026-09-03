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
## TWO ENTRY POINTS, AND THEY DO DIFFERENT THINGS (owner ruling,
## 2026-09-03).
##
##   * `judge` MEASURES. It reports `accepted` / `declined` / `refused`
##     and constructs nothing, mutates nothing and is safe to call as
##     often as anyone likes. Every gate, audit and Zone-time check uses
##     this one.
##   * `consume` BUILDS. It judges first, then constructs what was
##     accepted, and reports `built` for the things a node now exists
##     for. Calling it is a decision, not a side effect of looking.
##
## The distinction is not decoration. `OfferBinding.validate` used to
## return `consume`, so the act of checking a Zone put pads and rails
## into every room in it -- validation that constructs gameplay, and a
## second look that judged the offers against the first look's output.
## Nothing is called "built" here unless a node was made.
##
## NOT BAKED IN. The shell says a rail COULD run here; it does not
## contain a rail. The identical shell handed to a launch package builds
## launch pads and no rail, and handed to nothing builds neither.

## JUDGE this room's offers. Nothing is constructed and nothing is
## touched (owner ruling, 2026-09-03).
##
## Returns `{accepted, declined, refused}`. `accepted` is every offer
## that measured true against the live room -- a judgement, not a thing
## that exists. Building any of them is `consume`'s job and is a separate
## decision somebody has to make on purpose.
##
## `only` is the caller's own appetite -- an array of offer kinds, or
## empty for everything this understands.
##
## OBSERVATION ONLY, AND SAFE TO REPEAT. This adds no node, mutates no
## dictionary and leaves the room exactly as it found it, so calling it
## twice gives the same answer for the same reason: both calls looked at
## the same room. That is the whole point of the split -- what used to be
## called `validate` returned `MovementPackage.consume`, so the second
## look judged the offers against pads and rails the first look had put
## there.
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
static func judge(root: Node3D, room: Dictionary,
		space: PhysicsDirectSpaceState3D, only: Array = [],
		who := "offers") -> Dictionary:
	var accepted: Array = []
	var declined: Array = []
	var why := SpaceProbe.refusal(root, space, who)
	if why != "":
		return {"accepted": accepted, "refused": true,
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
	# EVERY OFFER IS A CLAIM ABOUT THE ROOM AS AUTHORED.
	#
	# These used to validate and construct in one pass, so a rail built
	# early became geometry the launch validated after it collided with
	# -- and the hall's arc grazes its own rail beam by 0.35 m. The
	# verdict then depended on which kind was visited first: run launches
	# before rails and the launch passes and the rail might fail instead.
	# An answer that changes with iteration order is not an answer.
	#
	# What another package chose to build in the room is not part of the
	# claim, which is why judging is now a whole pass of its own and no
	# offer geometry exists while it runs.
	if _wants("rail_route", only):
		_rails(room, space, to_world, accepted, declined)
	if _wants("launch_source", only):
		_launches(room, space, to_world, accepted, declined)
	if _wants("grapple_point", only):
		_grapples(room, space, to_world, accepted, declined)
	return {"accepted": accepted, "declined": declined, "refused": false}

## The mark a root carries once offers have been constructed into it.
##
## Set by `consume` and read by `consume`. Judging never looks at it,
## because judging never earns it.
const BUILT_MARK := "movement_offers_constructed"

## CONSTRUCT the offers this room offers, into `root`.
##
## Returns `{built, accepted, declined, refused}`, and the two arrays say
## different things on purpose: `accepted` is every offer that measured
## true, `built` is every offer that a NODE now exists for. They differ
## by design -- a `grapple_point` is validated and never built, because
## there is no grapple mechanic in this engine to construct and inventing
## one here would be exactly the "bake a mechanic into the shell" the
## contract forbids. Reporting a grapple as `built` would be a claim that
## something was made, and nothing was.
##
## AN OFFER IS NOT AN ORDER. Three things follow, and each is tested:
##
##   * a package may DECLINE. `only` restricts what it will look at, and
##     a package that consumes nothing must leave a working room -- the
##     same shell has to play as ordinary combat space with no traversal
##     mechanic in it at all.
##   * a package must VALIDATE what it builds. Everything here is judged
##     by `judge` first, against the room BEFORE any of it exists.
##   * a refusal is REPORTED, never silent. `declined` carries the
##     offer's name and the reason, because a large room whose traversal
##     quietly did not appear is the worst version of this failure.
##
## ONCE PER ROOM, AND IT SAYS SO. A second construction into the same
## root would duplicate every pad and beam and judge nothing, so it is
## refused by name rather than quietly doubling the room. Judging stays
## available and stays free.
static func consume(root: Node3D, room: Dictionary,
		space: PhysicsDirectSpaceState3D, only: Array = [],
		who := "offers") -> Dictionary:
	var verdict := judge(root, room, space, only, who)
	if bool(verdict["refused"]):
		return {"built": [], "accepted": [], "refused": true,
				"declined": verdict["declined"]}
	if root.has_meta(BUILT_MARK):
		return {"built": [], "accepted": verdict["accepted"],
				"refused": true, "declined": [{"name": "*", "kind": "*",
					"why": "offers were already constructed into %s; a "
						% root.name + "second construction would duplicate "
						+ "every pad and beam and judge the new ones "
						+ "against the old"}]}
	root.set_meta(BUILT_MARK, true)
	var built: Array = []
	for item: Variant in verdict["accepted"] as Array:
		_construct(root, item as Dictionary, built)
	return {"built": built, "accepted": verdict["accepted"],
			"declined": verdict["declined"], "refused": false}

## Build one accepted offer, when there is something to build.
##
## Separated from judging so that no offer is ever measured against
## something another offer put there. A `grapple_point` matches nothing
## and appends nothing: it was accepted, and accepting is all this engine
## can honestly do with it.
static func _construct(root: Node3D, item: Dictionary,
		built: Array) -> void:
	match str(item["kind"]):
		"rail_route":
			var rail: RailPath = item["rail"]
			var made := AffordanceFeatures.build_rail(root, rail)
			built.append({"name": item["name"], "kind": "rail_route",
					"rail": rail, "lanes": made["lanes"],
					"beams": made["beams"]})
		"launch_source":
			var pad := AffordanceNodes.LaunchPad.new()
			pad.position = item["source"]
			pad.target = item["target"]
			root.add_child(pad)
			built.append({"name": item["name"],
					"kind": "launch_source", "pad": pad,
					"target": item["target"]})

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
		to_world: Transform3D, accepted: Array, declined: Array) -> void:
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
		# AVAILABLE, not built. The verb is Epsilon's to choose, and
		# nothing is constructed for it in either path.
		accepted.append({"name": named, "kind": "grapple_point",
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
static func _rails(room: Dictionary,
		space: PhysicsDirectSpaceState3D, to_world: Transform3D,
		accepted: Array, declined: Array) -> void:
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
		accepted.append({"kind": "rail_route", "name": named,
				"rail": rail})

## A launch pad is a PAIR: a source to fire from and a target to land in.
## An unpaired half of either is an offer nobody can act on, and saying so
## is more use than building half a traversal.
static func _launches(room: Dictionary,
		space: PhysicsDirectSpaceState3D, to_world: Transform3D,
		accepted: Array, declined: Array) -> void:
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
				named, float(entry.get("radius", 0.0)))
		if not refusals.is_empty():
			declined.append({"name": named, "kind": "launch_source",
					"why": "; ".join(refusals)})
			continue
		accepted.append({"kind": "launch_source", "name": named,
				"source": source, "target": target})
