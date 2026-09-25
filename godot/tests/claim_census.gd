class_name ClaimCensus
extends RefCounted
## V-09, MEASURED: CAN THIS CHECK BE CLAIMED WITHOUT SOLVING THE ROOM?
##
## PT-05: "The owner [...] did not understand the goal, and walked to the
## Check." The delivery plan: "A pickup placed behind an enclosure must
## agree with the actual claim interaction. Test pickup radius, line of
## interaction, teleport target legality, gaps in glass, projectile reach,
## elevation and collision -- not only walking reachability."
##
## So this asks the room's real geometry, with the player's real numbers,
## the question the claim itself asks. Three steps, all physics queries
## against the built Zone:
##
## 1. **Where a body can stand.** Every surface under a 0.3 m grid over
##    the room, several floors deep, where the player's own capsule fits.
## 2. **Where the base kit gets to from the arrival**, the room as built
##    and nothing operated: walking (a step up no higher than the body
##    climbs), jumping onto what the jump apex clears, dropping off
##    anything, and jumping gaps no wider than the run-up carries. Moving
##    machinery stands where it was built, as geometry -- riding it is
##    operating it, which is solving.
## 3. **Where the claim reaches from there.** The Check is claimed by
##    `Player.camera_ray(3.0)` from the eye: so from every reached cell,
##    at eye height standing and at the jump's apex, a ray of that length
##    in any direction at the Check's own collider. A hit that reaches the
##    Check first is a claim.
##
## Generous where generosity finds bypasses (a straight-line jump model,
## every look direction, the apex), exact where exactness matters (the
## capsule, the claim ray's length, the collision mask the player
## actually has). A census that reported nothing because its player was
## too timid would be the same false comfort as a walk-only test.

const STEP := 0.3
const SKIN := 0.05
## The claim ray: `Player._update_interact_target`'s `camera_ray(3.0)`.
const CLAIM_REACH := 3.0
## How high the body climbs without jumping: a stair riser's worth.
const STEP_UP := 0.3
## How many floors under one column the census looks through.
const LAYERS := 5


## `{cells, reached, claims, from_cells}` for `reward` in `box`, from
## the standable cell nearest `arrival`. `claims` lists the first few
## `{at, eye, height}` a claim reached from; `from_cells` how many
## reached cells claim it at all.
static func take(player: Player, box: AABB, arrival: Vector3,
		reward: CollisionObject3D, exclude: Array = []) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var mask := player.collision_mask
	var skip: Array[RID] = [player.get_rid()]
	for raw: Variant in exclude:
		if raw is CollisionObject3D and is_instance_valid(raw):
			skip.append((raw as CollisionObject3D).get_rid())
	var cells := _standable(space, box, mask, skip)
	var reached := _reach(space, cells, arrival, mask, skip)
	var claims: Array = []
	var from_cells := 0
	var target := _target_points(reward)
	var reward_rid := reward.get_rid()
	for key: Variant in reached.keys():
		var cell: Vector3 = cells[key]
		for rise: float in [0.0, apex() * 0.5, apex()]:
			var eye := cell + Vector3(0.0, Constants.PLAYER_EYE_HEIGHT
					+ rise, 0.0)
			if _claims(space, eye, target, reward_rid, skip):
				from_cells += 1
				if claims.size() < 6:
					claims.append({"at": cell, "eye": eye, "rise": rise})
				break
	return {"cells": cells.size(), "reached": reached.size(),
			"from_cells": from_cells, "claims": claims}


## WHERE THE BASE KIT GETS TO FROM `from`, the room as it stands now:
## `{cells, reached}` -- grid key to surface point, and the keys reached.
## The same walk, jump and drop model the claim census uses.
static func reach(player: Player, box: AABB, from: Vector3,
		exclude: Array = []) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var mask := player.collision_mask
	var skip: Array[RID] = [player.get_rid()]
	for raw: Variant in exclude:
		if raw is CollisionObject3D and is_instance_valid(raw):
			skip.append((raw as CollisionObject3D).get_rid())
	var cells := _standable(space, box, mask, skip)
	return {"cells": cells, "reached": _reach(space, cells, from, mask, skip)}


## Does a reach from `reach()` stand anywhere within `within` of `point`?
static func reaches_near(result: Dictionary, point: Vector3,
		within := 1.5) -> bool:
	var cells: Dictionary = result["cells"]
	for key: Variant in (result["reached"] as Dictionary).keys():
		if (cells[key] as Vector3).distance_to(point) <= within:
			return true
	return false


## The jump's apex, the law's own number.
static func apex() -> float:
	return Constants.JUMP_VELOCITY * Constants.JUMP_VELOCITY \
			/ (2.0 * Constants.GRAVITY)


## Would a claim ray from `eye` reach the Check? Directly at its collider,
## the way `camera_ray` meets it: the first thing the ray hits.
static func claims_from(player: Player, eye: Vector3,
		reward: CollisionObject3D, exclude: Array = []) -> bool:
	var skip: Array[RID] = [player.get_rid()]
	for raw: Variant in exclude:
		if raw is CollisionObject3D and is_instance_valid(raw):
			skip.append((raw as CollisionObject3D).get_rid())
	return _claims(player.get_world_3d().direct_space_state, eye,
			_target_points(reward), reward.get_rid(), skip)


# ------------------------------------------------------------ internals

static func _claims(space: PhysicsDirectSpaceState3D, eye: Vector3,
		target: Array, reward_rid: RID, skip: Array[RID]) -> bool:
	for raw: Variant in target:
		var point: Vector3 = raw
		var to := point - eye
		if to.length() > CLAIM_REACH + 1.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye,
				eye + to.normalized() * CLAIM_REACH)
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit["rid"] == reward_rid:
			return true
	return false


## Points on and in the Check's collider to aim at: its centre, its face
## centres and its corners pulled a little inside.
static func _target_points(reward: CollisionObject3D) -> Array:
	var out: Array = []
	for found: Node in reward.get_children():
		var shape := found as CollisionShape3D
		if shape == null or shape.shape == null:
			continue
		var local := shape.shape.get_debug_mesh().get_aabb().grow(-0.05)
		var xform := shape.global_transform
		var c := local.get_center()
		var h := local.size * 0.5
		out.append(xform * c)
		for axis in 3:
			for sign: float in [-1.0, 1.0]:
				var offset := Vector3.ZERO
				offset[axis] = h[axis] * sign
				out.append(xform * (c + offset))
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					out.append(xform * (c + Vector3(h.x * sx, h.y * sy,
							h.z * sz)))
	return out


## Grid key -> surface point, for every surface a body stands on.
static func _standable(space: PhysicsDirectSpaceState3D, box: AABB,
		mask: int, skip: Array[RID]) -> Dictionary:
	var capsule := CapsuleShape3D.new()
	capsule.radius = Constants.PLAYER_RADIUS
	capsule.height = Constants.PLAYER_HEIGHT
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = capsule
	fit.collision_mask = mask
	fit.exclude = skip
	var out := {}
	var nx := int(box.size.x / STEP)
	var nz := int(box.size.z / STEP)
	for ix in nx + 1:
		for iz in nz + 1:
			var x := box.position.x + STEP * 0.5 + ix * STEP
			var z := box.position.z + STEP * 0.5 + iz * STEP
			var top := box.end.y + 1.0
			for layer in LAYERS:
				var query := PhysicsRayQueryParameters3D.create(
						Vector3(x, top, z),
						Vector3(x, box.position.y - 1.0, z), mask)
				query.exclude = skip
				var hit := space.intersect_ray(query)
				if hit.is_empty():
					break
				var at: Vector3 = hit["position"]
				top = at.y - 0.02
				if (hit["normal"] as Vector3).y < 0.7:
					continue
				fit.transform = Transform3D(Basis.IDENTITY, at
						+ Vector3(0.0, Constants.PLAYER_HEIGHT * 0.5 + SKIN,
							0.0))
				if space.intersect_shape(fit, 1).is_empty():
					out[Vector3i(ix, iz, layer)] = at
	return out


## BFS over `cells` from the one nearest `arrival`: which cells the base
## kit reaches with nothing in the room operated.
static func _reach(space: PhysicsDirectSpaceState3D, cells: Dictionary,
		arrival: Vector3, mask: int, skip: Array[RID]) -> Dictionary:
	var capsule := CapsuleShape3D.new()
	capsule.radius = Constants.PLAYER_RADIUS
	capsule.height = Constants.PLAYER_HEIGHT
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = capsule
	fit.collision_mask = mask
	fit.exclude = skip
	# Columns -> the layers standing in them, for neighbour lookup.
	var columns := {}
	for key: Vector3i in cells.keys():
		var column := Vector2i(key.x, key.y)
		if not columns.has(column):
			columns[column] = []
		(columns[column] as Array).append(key)
	var start := Vector3i(-1, -1, -1)
	var best := INF
	for key: Vector3i in cells.keys():
		var d: float = (cells[key] as Vector3).distance_to(arrival)
		if d < best:
			best = d
			start = key
	var reached := {}
	if start.x < 0 or best > 2.0:
		return reached
	reached[start] = true
	var queue: Array = [start]
	var ring := _jump_ring()
	var up := apex() - 0.1
	while not queue.is_empty():
		var key: Vector3i = queue.pop_front()
		var here: Vector3 = cells[key]
		var edge := false
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var column := Vector2i(key.x + dx, key.y + dz)
				var found := false
				for other: Vector3i in columns.get(column, []):
					var there: Vector3 = cells[other]
					var rise := there.y - here.y
					if rise > up:
						continue
					found = true
					if reached.has(other):
						continue
					if not _passable(space, fit, here, there, rise):
						continue
					reached[other] = true
					queue.append(other)
				if not found:
					edge = true
		if not edge:
			continue
		# AT A REGION'S EDGE, THE JUMP: a gap crossed on a run-up. Only
		# from edges -- everywhere else a walk already got there.
		for offset: Vector2 in ring:
			var column := Vector2i(key.x + int(round(offset.x / STEP)),
					key.y + int(round(offset.y / STEP)))
			for other: Vector3i in columns.get(column, []):
				if reached.has(other):
					continue
				var there: Vector3 = cells[other]
				var rise := there.y - here.y
				if rise > up or offset.length() > _jump_reach(rise):
					continue
				if not _clear_arc(space, here, there, mask, skip):
					continue
				reached[other] = true
				queue.append(other)
	return reached


## A walk or a jump from `here` to the neighbouring `there`: the body
## fits at the higher of the two, and a jump has the headroom to rise.
static func _passable(space: PhysicsDirectSpaceState3D,
		fit: PhysicsShapeQueryParameters3D, here: Vector3, there: Vector3,
		rise: float) -> bool:
	var high := maxf(here.y, there.y)
	var mid := (here + there) * 0.5
	fit.transform = Transform3D(Basis.IDENTITY, Vector3(mid.x, high
			+ Constants.PLAYER_HEIGHT * 0.5 + SKIN, mid.z))
	if not space.intersect_shape(fit, 1).is_empty():
		return false
	if rise > STEP_UP:
		fit.transform = Transform3D(Basis.IDENTITY, here + Vector3(0.0,
				rise + Constants.PLAYER_HEIGHT * 0.5 + SKIN, 0.0))
		if not space.intersect_shape(fit, 1).is_empty():
			return false
	return true


## Horizontal reach of a running jump that lands `rise` higher (negative
## for lower): walk speed times the time the arc takes to come back down
## to that height. The whole descending branch, which is generous.
static func _jump_reach(rise: float) -> float:
	var v := Constants.JUMP_VELOCITY
	var g := Constants.GRAVITY
	var disc := v * v - 2.0 * g * rise
	if disc < 0.0:
		return 0.0
	return Constants.WALK_SPEED * (v + sqrt(disc)) / g


## Offsets to try a jump to, out to the longest flat-ish jump.
static func _jump_ring() -> Array:
	var out: Array = []
	var far := _jump_reach(-2.0)
	var r := STEP * 2.0
	while r <= far:
		var count := maxi(8, int(TAU * r / (STEP * 2.0)))
		for i in count:
			var a := TAU * float(i) / float(count)
			out.append(Vector2(cos(a), sin(a)) * r)
		r += STEP * 2.0
	return out


## A straight line at head and at chest height, from take-off to landing,
## raised by the arc's rise: nothing solid across the jump.
static func _clear_arc(space: PhysicsDirectSpaceState3D, here: Vector3,
		there: Vector3, mask: int, skip: Array[RID]) -> bool:
	var lift := maxf(there.y - here.y, 0.0)
	for height: float in [0.9, Constants.PLAYER_HEIGHT - 0.1]:
		var from := here + Vector3(0.0, height + lift, 0.0)
		var to := there + Vector3(0.0, height, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, to, mask)
		query.exclude = skip
		if not space.intersect_ray(query).is_empty():
			return false
	return true
