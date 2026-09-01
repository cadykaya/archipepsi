class_name RoomAudit
extends RefCounted
## Does the room's geometry agree with what the room CLAIMS? (P1)
##
##     AUTHOR-DECLARED METADATA IS A CLAIM.
##     GODOT MEASUREMENT IS AUTHORITY.
##
## `room_contract.gd` checks that a room output is well FORMED. This
## checks that it is TRUE, and the two are unrelated failures: a `stand`
## socket with a perfectly valid position and extent can be a rectangle
## of empty air, and every structural check in the project would pass it.
##
## WHY IT HAS TO BE PROBES. This repository has now paid three times for
## trusting a description over the world:
##
##   * a pit whose recess was dug under an intact floor slab -- the
##     bounds dropped, the sockets sat below zero, a ray from INSIDE the
##     recess found its deck, and the pit was a sealed basement. Nothing
##     asked what a ray from ABOVE hits first.
##   * a band's access ramp 6.8 m long, which occupancy classified as
##     architecture and therefore could not see, so the way up was the
##     one invisible obstacle in the room.
##   * `platform_path` activities laid out against a nominal floor that
##     does not exist, over a kill pit.
##
## Every one of those was a self-consistent description. So this file
## never reads a claim to confirm another claim; it puts a ray, a shape
## or a capsule into the instantiated scene and reports what came back.
##
## PRODUCER-AGNOSTIC BY CONSTRUCTION. It takes a room OUTPUT and a
## physics space. It cannot tell, and must never be able to tell, whether
## a builder or an artist produced what it is measuring.
##
## THE ROOM MUST BE IN THE TREE. A detached node has no colliders
## registered, and a probe against one comes back clean because there is
## nothing there to hit -- which is the most dangerous possible false
## pass. `measure` refuses rather than reporting a clean sheet.

## How far a measured surface may sit from its declared height. Generous
## enough for float error and a 0.1 m lip; far tighter than the
## difference between standing on a floor and falling past it.
const HEIGHT_TOLERANCE := 0.15

## How far below a declared point support may be and still count as
## "under it" -- the same number the Zone audit uses for the same
## question, so the two cannot drift.
const GROUND_REACH := 1.2

## How far back from a declared jump endpoint to probe for support.
##
## The endpoints of a gap ARE the edges it is measured between -- moving
## them inward would inflate the span and refuse legal jumps -- so the
## probe steps back onto the surface instead. A ray at exactly the
## boundary of a collider is a coin toss.
const EDGE_INSET := 0.15

## How far outside its declared bounds a room's own geometry may reach
## before it is somebody else's room. Rooms are chained by butting their
## bounds together, so a mesh past this is a mesh inside the neighbour.
const BOUNDS_TOLERANCE := 0.35

## Probe sizes, from the player's real capsule so they cannot drift from
## the thing they protect.
const HEADROOM := Constants.PLAYER_HEIGHT + 0.6

## Every way the room's geometry contradicts the room's claims.
##
## `space` must belong to a world the room is actually inside.
static func findings(result: Variant, space: PhysicsDirectSpaceState3D,
		who := "room") -> Array[String]:
	var out: Array[String] = []
	if typeof(result) != TYPE_DICTIONARY:
		return ["%s: no room to measure" % who]
	var room: Dictionary = result
	var root := room.get("root") as Node3D
	if root == null:
		return ["%s: no root to measure" % who]
	if space == null:
		return ["%s: no physics space; a probe with nowhere to go comes "
				% who + "back clean, which is the wrong kind of pass"]
	if not root.is_inside_tree():
		return ["%s: the room is not in the scene tree, so nothing it "
				% who + "contains has a collider to hit"]

	var to_world := root.global_transform
	var surfaces := RoomContract.sockets_of(room, "stand")
	out.append_array(_surfaces_hold_weight(surfaces, to_world, space, who))
	out.append_array(_points_have_ground(room, surfaces, to_world, space,
			who))
	out.append_array(_arrivals_are_standable(room, to_world, space, who))
	out.append_array(_openings_are_holes(room, to_world, space, who))
	out.append_array(_traversal_is_true(room, to_world, space, who))
	out.append_array(_geometry_stays_inside_its_bounds(room, root, who))
	return out

# --- 1. a declared walkable surface holds weight ---------------------------

## Support at the declared height, and clear air above it.
##
## THE SEALED PIT IS THE HEADROOM CHECK. The first draft of this had a
## separate "is it reachable from above" probe, on the reasoning that the
## pit lesson was about lids. It is not: the pit's deck sat 1.66 m under
## an intact floor slab, and what makes that unwalkable is that a 1.8 m
## player does not fit in 1.66 m. A ray fired down from the ceiling adds
## nothing the headroom ray does not already say, and it refuses a
## perfectly good mezzanine -- so it was dropped rather than kept as a
## second opinion that disagrees.
##
## HEADROOM is the number `ElevationBand` already validates at parse, so
## the schema and the probe cannot hold different views of what standing
## up requires.
static func _surfaces_hold_weight(surfaces: Array,
		to_world: Transform3D, space: PhysicsDirectSpaceState3D,
		who: String) -> Array[String]:
	var out: Array[String] = []
	for socket: Variant in surfaces:
		var patch: Dictionary = socket
		var at: Vector3 = patch["position"]
		var extent: Vector3 = patch.get("extent", Vector3.ONE)
		# Sampled across the rect rather than at its centre. A surface is
		# a claim about an AREA, and the centre-only probe is how a wall
		# check once passed a room with a hole in the corner.
		for u: float in [0.2, 0.5, 0.8]:
			for v: float in [0.2, 0.5, 0.8]:
				var local := at + Vector3(
						(u - 0.5) * extent.x, 0.0, (v - 0.5) * extent.z)
				var world := to_world * local
				var down := _ray(space, world + Vector3.UP * 0.4,
						world + Vector3.DOWN * GROUND_REACH)
				if down.is_empty():
					out.append("%s: a declared walkable surface at %v "
							% [who, local] + "has no geometry under it")
					continue
				var drop: float = world.y - (down["position"] as Vector3).y
				if absf(drop) > HEIGHT_TOLERANCE:
					out.append("%s: a walkable surface declared at "
							% who + "y=%.2f measures %.2f"
							% [local.y, local.y - drop])
					continue
				var up := _ray(space, world + Vector3.UP * 0.1,
						world + Vector3.UP * HEADROOM)
				if not up.is_empty():
					out.append("%s: a walkable surface at %v has %.2f m "
							% [who, local,
								(up["position"] as Vector3).y - world.y]
							+ "of headroom; a player needs %.2f"
							% HEADROOM)
	return out

# --- 2. a placement point has something to place onto ----------------------

## Cover, barrels and elevated stances are single points, and each is an
## OFFER the composer may take. An offer standing in mid-air or buried in
## a wall is the builder telling the composer something untrue.
static func _points_have_ground(room: Dictionary, surfaces: Array,
		to_world: Transform3D, space: PhysicsDirectSpaceState3D,
		who: String) -> Array[String]:
	var out: Array[String] = []
	for kind: String in RoomContract.POINT_KINDS:
		for socket: Variant in RoomContract.sockets_of(room, kind):
			var patch: Dictionary = socket
			var local: Vector3 = patch["position"]
			var world := to_world * local
			var down := _ray(space, world + Vector3.UP * 0.3,
					world + Vector3.DOWN * GROUND_REACH)
			if down.is_empty():
				out.append("%s: a '%s' socket at %v has nothing under it"
						% [who, kind, local])
				continue
			if _buried(space, world + Vector3.UP * 0.45, 0.5):
				out.append("%s: a '%s' socket at %v is inside solid "
						% [who, kind, local] + "geometry")
				continue
			var named := str(patch.get("surface_id", ""))
			if named == "":
				continue
			var wanted := INF
			for other: Variant in surfaces:
				if str((other as Dictionary).get("name", "")) == named:
					wanted = ((other as Dictionary)["position"] as Vector3).y
			if wanted == INF:
				out.append("%s: a '%s' socket names surface '%s', which "
						% [who, kind, named] + "the room does not declare")
			elif absf(local.y - wanted) > GROUND_REACH:
				out.append("%s: a '%s' socket says it is on surface '%s' "
						% [who, kind, named] + "at y=%.2f and sits at "
						% wanted + "y=%.2f" % local.y)
	return out

# --- 3. the places the game PUTS things are standable ----------------------

## Every enemy spawn and the reward pedestal. These are not offers -- the
## game puts something there whatever the room thinks -- so a spawn point
## inside a wall is an enemy inside a wall, and a reward pocket in a void
## is a Check the player cannot reach.
static func _arrivals_are_standable(room: Dictionary,
		to_world: Transform3D, space: PhysicsDirectSpaceState3D,
		who: String) -> Array[String]:
	var out: Array[String] = []
	var places: Array = [["the reward position",
			room.get("reward_position", Vector3.ZERO)]]
	for spawn: Variant in room.get("enemy_spawns", []) as Array:
		if typeof(spawn) == TYPE_DICTIONARY:
			places.append(["an enemy spawn",
					(spawn as Dictionary).get("position", Vector3.ZERO)])
	for place: Array in places:
		var local: Vector3 = place[1]
		var world := to_world * local
		if _buried(space, world + Vector3.UP * (Constants.PLAYER_HEIGHT
				/ 2.0), Constants.PLAYER_RADIUS * 2.0):
			out.append("%s: %s at %v is inside solid geometry"
					% [who, str(place[0]), local])
			continue
		# Deliberately a long reach: a spawn is allowed to be dropped
		# from a little height, and the failure being caught is a void,
		# not a step.
		var down := _ray(space, world + Vector3.UP * 0.6,
				world + Vector3.DOWN * 4.0)
		if down.is_empty():
			out.append("%s: %s at %v has no floor beneath it"
					% [who, str(place[0]), local])
	return out

# --- 4. an opening is a hole ----------------------------------------------

## Mesh IS collider in this project, so a doorway that was modelled and
## not cut is a wall the chain believes is a door -- and the player finds
## out standing in front of it. Swept with the player's own capsule
## through the entry plane and the exit plane, which is where the two
## rooms actually meet.
static func _openings_are_holes(room: Dictionary, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D, who: String) -> Array[String]:
	var out: Array[String] = []
	var bounds: AABB = room["bounds"]
	var exit_at: Vector3 = room["exit_offset"]
	# THE DOOR IS ON THE WALL, AND `exit_offset` IS NOT ALWAYS THE WALL.
	# It is where the NEXT ROOM'S ORIGIN goes, which for most builders is
	# the same point and for a tower is deliberately 2.2 m past the back
	# face -- a summit landing needs the next room pushed clear. Probing
	# `exit_offset` therefore measured a point in mid-air outside the
	# tower and called its perfectly good summit door sealed. The
	# producer-agnostic statement is the room's own +Z boundary at the
	# height the exit leaves from.
	#
	# The walking plane at a room's entry is local y=0 for every producer
	# here: procedural builders put their floor top there, and an
	# authored shell's bounds start `FLOOR_ALLOWANCE` below it.
	for door: Array in [
			["the entry", Vector3(0.0, 0.0, bounds.position.z),
				Vector3.FORWARD],
			["the exit", Vector3(exit_at.x, exit_at.y, bounds.end.z),
				Vector3.BACK]]:
		var at: Vector3 = door[1]
		var into: Vector3 = door[2]
		# From just outside the plane to just inside it. Short on
		# purpose: this asks whether the OPENING is open, not whether the
		# room is walkable end to end -- a `platform_path` is not, by
		# design, and a walkability prover is a different tool.
		# STAND WHERE THE FLOOR IS, measured. The declared exit height is
		# not always a walking plane: a tower's landing slab is 0.5 m
		# thick and CENTRED on the height its `exit_offset` names, so a
		# capsule placed at that height starts 0.25 m inside the deck and
		# every summit door in the game measured as sealed. Finding the
		# floor first is the same move the Zone audit's floor probe makes,
		# for the same reason.
		var ground := _ray(space, to_world * (at + Vector3.UP * 1.0),
				to_world * (at + Vector3.DOWN * 1.0))
		var base := at.y
		if not ground.is_empty():
			base = (to_world.affine_inverse()
					* (ground["position"] as Vector3)).y
		var stance := Vector3.UP * (base - at.y
				+ Constants.PLAYER_HEIGHT / 2.0 + 0.05)
		# ON the plane and just inside it. Two stances rather than a
		# swept motion: `cast_motion` reports the fraction of a path a
		# shape can travel and quietly returns "all of it" for a shape
		# that starts clear and ends clear, which a 0.4 m door jamb
		# between two open points is. Asking "does the player FIT here"
		# is the question, and it has one answer.
		for step: float in [0.0, 0.45]:
			if _blocked(space, to_world * (at + into * step + stance)):
				out.append("%s: %s at %v is sealed; the player's own "
						% [who, str(door[0]), at]
						+ "capsule does not fit through it")
				break
	return out

# --- 5. a declared movement is the movement the geometry makes -------------

## The claim an artist is most likely to get wrong and least likely to
## notice, because a jump that is 20% too far still looks fine in the
## viewport. Measured ends, measured span, measured rise, against the
## same `max_safe_gap` a `platform_path` has always been held to.
static func _traversal_is_true(room: Dictionary, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D, who: String) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in room.get("traversal", []) as Array:
		var seg: Dictionary = entry
		var name := str(seg.get("name", "?"))
		var kind := str(seg.get("kind", "walk"))
		var start: Vector3 = seg.get("start", Vector3.ZERO)
		var end: Vector3 = seg.get("end", Vector3.ZERO)
		# Stepped back onto each surface, away from the other end.
		var away := Vector3(end.x - start.x, 0.0, end.z - start.z)
		away = away.normalized() * EDGE_INSET if away.length() > 0.001 \
				else Vector3.ZERO
		var ends := {"start": start - away, "end": end + away}
		var landed := {}
		for label: String in ends:
			var world: Vector3 = to_world * (ends[label] as Vector3)
			var down := _ray(space, world + Vector3.UP * 0.4,
					world + Vector3.DOWN * GROUND_REACH)
			if down.is_empty():
				out.append("%s: traversal '%s' %ss where there is "
						% [who, name, label] + "nothing to stand on")
			else:
				landed[label] = (down["position"] as Vector3).y
		if kind == "gap" and landed.size() == 2:
			# A gap you can walk across is not a gap, and a room that
			# declares one is describing a jump the player never makes.
			var mid := to_world * ((start + end) * 0.5)
			var bridged := _ray(space, mid + Vector3.UP * 0.4,
					mid + Vector3.DOWN * GROUND_REACH)
			if not bridged.is_empty():
				out.append("%s: traversal '%s' is declared a gap and "
						% [who, name] + "has floor across it")
		if not bool(seg.get("mandatory", true)) or landed.size() < 2:
			continue
		var span := Vector2(end.x - start.x, end.z - start.z).length()
		var rise: float = float(landed["end"]) - float(landed["start"])
		if kind == "rise" and rise > Constants.MAX_VERTICAL_STEP:
			out.append("%s: traversal '%s' rises %.2f m as built on the "
					% [who, name, rise] + "mandatory route; the base kit "
					+ "tops out at %.2f" % Constants.MAX_VERTICAL_STEP)
		if not ["gap", "rise"].has(kind):
			continue
		var allowed := Constants.max_safe_gap(maxf(rise, 0.0))
		if span > allowed + 0.01:
			out.append("%s: traversal '%s' spans %.2f m as built at a "
					% [who, name, span] + "%.2f m rise; the safe reach "
					% rise + "there is %.2f" % allowed)
	return out

# --- 6. the room fits in the box it reserved ------------------------------

## Rooms are chained by butting their bounds together, so geometry
## outside them is geometry inside the neighbour. `solid_boxes` is the
## project's one derivation of what counts as furniture-scale solid; this
## reuses it rather than deriving a second answer.
static func _geometry_stays_inside_its_bounds(room: Dictionary,
		root: Node3D, who: String) -> Array[String]:
	var out: Array[String] = []
	var bounds: AABB = room["bounds"]
	var roomy := bounds.grow(BOUNDS_TOLERANCE)
	var worst := 0.0
	var count := 0
	for box in ChamberBuilders.solid_boxes(root):
		if roomy.encloses(box):
			continue
		count += 1
		for axis in 3:
			worst = maxf(worst, maxf(
					roomy.position[axis] - box.position[axis],
					box.end[axis] - roomy.end[axis]))
	if count > 0:
		out.append("%s: %d piece(s) of geometry reach up to %.2f m "
				% [who, count, worst] + "outside the room's own bounds")
	return out

# --- probes ---------------------------------------------------------------

static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)

## Is anything solid sharing this space? A box rather than a ray: a
## socket fully inside a wall is something no ray from outside reaches,
## and "can I see it" is the wrong question.
##
## PLACED CONTENT DOES NOT COUNT. The audit runs on a finished room, so
## by the time it looks, the crate the `cover` socket offered is standing
## on that socket. Reporting it would be the audit reporting the socket's
## own success as a defect. The question is only ever about the LEVEL.
static func _buried(space: PhysicsDirectSpaceState3D, at: Vector3,
		size: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size
	query.shape = shape
	query.transform = Transform3D(Basis(), at)
	query.collide_with_areas = false
	for hit: Dictionary in space.intersect_shape(query, 8):
		if not _is_placed_content(hit.get("collider")):
			return true
	return false

## Something the composer PUT in the room, rather than the room itself.
static func _is_placed_content(collider: Variant) -> bool:
	var node := collider as Node
	while node != null:
		if node is ActivityElement:
			return true
		if node.is_in_group(DestructibleCover.GROUP):
			return true
		node = node.get_parent()
	return false

## Does the player's own capsule get from `from` to `to`? Returns true
## when it is BLOCKED, which is the finding.
## Does the player's own capsule fail to fit here? Returns true when it
## is BLOCKED, which is the finding.
static func _blocked(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	# Very slightly slimmer than the player, so an opening built exactly
	# to the minimum is not refused by float error.
	capsule.radius = Constants.PLAYER_RADIUS - 0.02
	capsule.height = Constants.PLAYER_HEIGHT - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), at)
	query.collide_with_areas = false
	for hit: Dictionary in space.intersect_shape(query, 8):
		if not _is_placed_content(hit.get("collider")):
			return true
	return false
