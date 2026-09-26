class_name EnemyFooting
extends RefCounted
## WHERE AN ENEMY MAY STAND, AND HOW FAR IT MAY WALK WITHOUT FIGHTING.
##
## Two defects put enemies out of the world with nobody fighting them.
## Every such fall is reported as a defeat (D-06), and a `kill_all`
## counts it:
## - **ML-F1:** a spawn placed inside a solid (a warp station, a crate, a
##   cover box) is pushed out by the physics on its first step, and
##   through a thin floor when down is the nearest way out;
## - **ML-F2:** a patrol beat picked at random within
##   `ENEMY_PATROL_RADIUS` of a post that stands near a drop, then walked
##   to.
##
## Both are answered here, from the physics the room actually built. A
## chase is not: an enemy lured off a ledge by the player is the player's
## doing (PPT-02), and nothing here changes it.

## The box is raised off the feet by this much: a floor the feet rest on,
## or sink a few centimetres into, is not a solid they are inside.
const FOOT_MARGIN := 0.15
## And trimmed this much at the sides and the head: a head that grazes a
## balcony (a sample Zone's ranged enemy had 1.42 m under one, at 1.40 m
## tall), or a shoulder that brushes a wall, is not inside it.
const SIDE_MARGIN := 0.05
const HEAD_MARGIN := 0.05
## A ground enemy is standing when there is floor this far under its feet
## or nearer: a spawn a little above a floor lands, one over a void does
## not.
const FLOOR_WITHIN := 3.0
## Feet set this far above the floor they stand on.
const FOOT_CLEARANCE := 0.02
## The search for a spot that stands: rings round the placed one.
const SEARCH_STEP := 0.5
const SEARCH_RADIUS := 6.0
const SEARCH_ANGLES := 16
## A walk goes on while each sample has floor within this of the last
## (a stair tread; not a crate top, not a drop).
const STEP_HEIGHT := 0.6
const WALK_SAMPLE := 0.5
const KNEE := 0.4


## Every physics body `node` is or holds: what a query about it excludes.
static func bodies_of(node: Node) -> Array[RID]:
	var out: Array[RID] = []
	_collect(node, out)
	return out


static func _collect(node: Node, into: Array[RID]) -> void:
	if node is CollisionObject3D:
		into.append((node as CollisionObject3D).get_rid())
	for child: Node in node.get_children():
		_collect(child, into)


## "" when a body of `envelope` can stand with its feet at `at`, or why
## it cannot: inside a solid, or over no floor.
static func standing_fault(space: PhysicsDirectSpaceState3D,
		envelope: Dictionary, at: Vector3, exclude: Array[RID]) -> String:
	var size: Vector3 = envelope.get("size", Vector3.ONE)
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(size.x - 2.0 * SIDE_MARGIN, 0.05),
			maxf(size.y - FOOT_MARGIN - HEAD_MARGIN, 0.05),
			maxf(size.z - 2.0 * SIDE_MARGIN, 0.05))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(), at + Vector3.UP
			* (float(envelope.get("centre_y", size.y / 2.0))
				+ (FOOT_MARGIN - HEAD_MARGIN) / 2.0))
	query.exclude = exclude
	for hit: Dictionary in space.intersect_shape(query, 8):
		var who: Object = hit["collider"]
		if who is StaticBody3D or who is RigidBody3D:
			return "inside %s" % (who as Node).name
	if bool(envelope.get("flying", false)):
		return ""
	if is_nan(floor_under(space, at, exclude)):
		return "no floor within %.0f m" % FLOOR_WITHIN
	return ""


## Where a body with `envelope`, placed at `at` in `room`, may stand.
##
## `{"at", "moved", "fault", "found"}`:
## - A ground body is judged where it will stand once it lands: its feet
##   on the floor under `at`. A spawn a hand above its floor falls that
##   far on its first step anyway, and judged in the air, a 1.6 m melee
##   under a 1.68 m balcony has its head in the slab (a sample Zone's
##   c014), which the landing undoes.
## - That spot, when it stands (`moved` 0: nothing but the landing).
## - Otherwise the nearest one that does, on rings round it, on the same
##   floor to a stair's height, and inside the room; `moved` is how far
##   across.
## - Otherwise the placed spot, and `found` false.
static func clear_spot(space: PhysicsDirectSpaceState3D, envelope: Dictionary,
		at: Vector3, room: AABB, exclude: Array[RID]) -> Dictionary:
	var flying := bool(envelope.get("flying", false))
	var level := floor_under(space, at, exclude)
	var stand := at
	if not flying and not is_nan(level):
		stand = Vector3(at.x, level + FOOT_CLEARANCE, at.z)
	var fault := standing_fault(space, envelope, stand, exclude)
	if fault == "":
		return {"at": stand, "moved": 0.0, "fault": "", "found": true}
	if is_nan(level):
		level = at.y
	var radius := SEARCH_STEP
	while radius <= SEARCH_RADIUS + 0.001:
		for k in SEARCH_ANGLES:
			var angle := TAU * float(k) / float(SEARCH_ANGLES)
			var probe := at + Vector3(cos(angle), 0.0, sin(angle)) * radius
			if probe.x < room.position.x or probe.x > room.end.x \
					or probe.z < room.position.z or probe.z > room.end.z:
				continue
			var spot := probe
			if not flying:
				var ground := floor_near(space, probe, level, STEP_HEIGHT, exclude)
				if is_nan(ground):
					continue
				spot = Vector3(probe.x, ground + FOOT_CLEARANCE, probe.z)
			if standing_fault(space, envelope, spot, exclude) == "":
				return {"at": spot, "moved": radius, "fault": fault, "found": true}
		radius += SEARCH_STEP
	return {"at": at, "moved": 0.0, "fault": fault, "found": false}


## How far a ground walker can go from `from` along `dir` (flat), up to
## `limit`: floor under every sample within a stair's height of the last,
## and no wall at knee height between them.
static func walkable(space: PhysicsDirectSpaceState3D, from: Vector3,
		dir: Vector3, limit: float, exclude: Array[RID]) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var level := floor_under(space, from, exclude)
	if is_nan(level):
		return 0.0
	var last := from
	var gone := 0.0
	while gone + WALK_SAMPLE <= limit + 0.001:
		var next := from + flat * (gone + WALK_SAMPLE)
		var wall := world_ray(space, Vector3(last.x, level + KNEE, last.z),
				Vector3(next.x, level + KNEE, next.z), exclude)
		if not wall.is_empty():
			break
		var ground := floor_near(space, next, level, STEP_HEIGHT, exclude)
		if is_nan(ground):
			break
		level = ground
		last = next
		gone += WALK_SAMPLE
	return gone


## The next `ahead` metres along `dir` from `at` keep a floor within a
## stair's height (walls ignored: a wall is not a ledge, and the walker's
## own recovery handles one).
static func floor_ahead(space: PhysicsDirectSpaceState3D, at: Vector3,
		dir: Vector3, ahead: float, exclude: Array[RID]) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var level := floor_under(space, at, exclude)
	if is_nan(level):
		return true   # already off a floor: not this guard's to judge
	var gone := WALK_SAMPLE
	while gone <= ahead + 0.001:
		var ground := floor_near(space, at + flat * gone, level, STEP_HEIGHT,
				exclude)
		if is_nan(ground):
			return false
		level = ground
		gone += WALK_SAMPLE
	return true


## The height of the floor under `at`, within `FLOOR_WITHIN`, or NAN.
static func floor_under(space: PhysicsDirectSpaceState3D, at: Vector3,
		exclude: Array[RID]) -> float:
	var hit := world_ray(space, at + Vector3.UP * 0.5,
			at + Vector3.DOWN * FLOOR_WITHIN, exclude)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y


## The height of a floor under `at` within `tolerance` of `level`, or NAN.
static func floor_near(space: PhysicsDirectSpaceState3D, at: Vector3,
		level: float, tolerance: float, exclude: Array[RID]) -> float:
	var hit := world_ray(space, Vector3(at.x, level + tolerance, at.z),
			Vector3(at.x, level - tolerance, at.z), exclude)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y


## A ray that sees the built world only: another enemy, or the player,
## standing on a floor is not the floor's end, nor a wall. Everything is on
## one collision layer, so a character hit is stepped past rather than
## masked out.
static func world_ray(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3, exclude: Array[RID]) -> Dictionary:
	var skip: Array[RID] = exclude.duplicate()
	for _tries in 6:
		var ray := PhysicsRayQueryParameters3D.create(from, to)
		ray.exclude = skip
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not (hit["collider"] is CharacterBody3D):
			return hit
		skip.append(hit["rid"])
	return {}
