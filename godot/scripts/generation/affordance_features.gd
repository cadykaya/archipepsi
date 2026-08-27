class_name AffordanceFeatures
extends RefCounted
## The seven world affordances (ECHOES §13), as geometry.
##
## Epsilon names a tag and a fraction of the chamber; this file owns the
## metres, exactly as `ZoneBuilder` does for layout. That division is what
## makes §13.2 structural: a generator that could name a coordinate could
## name one in the exit lane, so it never gets to name one.
##
## Two guarantees are enforced here rather than trusted:
##
## 1. **Never on the mandatory path.** Every feature is pushed clear of the
##    central walking lane (`LANE_HALF_WIDTH`), whatever fraction was
##    requested. The Zone validator already refuses features in reward
##    chambers and gating objectives; this is the same rule at the metre
##    level, where the lane actually exists.
## 2. **Never an AP reward.** What a feature holds is a
##    `LocalRewardPickup` — §14.2 — and there is no code path from here to
##    a `RewardObject`, a location id or a Check.
##
## A feature only reaches this file if the campaign owns the capability
## that makes it interactable: `validate_zone` refuses the Zone otherwise
## (I12). So nothing here has to ask whether the player can use it.

## Half-width of the walking lane a feature may never intrude on. The door
## is 2.4 m and the player is not a point; this leaves better than a body's
## clearance either side of the widest thing that has to get through.
const LANE_HALF_WIDTH := 2.0
const GROUP := "affordance_feature"

## Note text per tag, so a feature that yields a note says something about
## the capability that opened it rather than a generic congratulation.
const _NOTES := {
	"grapple_anchor": "Somebody else's grapple. Same ceiling.",
	"breakable_wall": "It was load-bearing. It is not any more.",
	"water_volume": "I filled it before I checked you could swim.",
	"rail": "Built for grinding. Grind responsibly.",
	"wind_volume": "The updraft is free. The landing is yours.",
	"bounce_pad": "No item required. Just enthusiasm.",
	"moving_platform": "It goes there, then it comes back. Forever.",
}

## Whether a room is wide enough to hold a feature at all.
##
## A corridor barely wider than its door is entirely walking lane: there is
## no "beside the path" in it, and pushing a feature out of the lane would
## push it into the wall. So such a chamber gets no features. That is not a
## failure — features are optional by definition, and a Zone missing one is
## strictly better than a Zone with a bounce pad inside the masonry or
## across the doorway.
static func fits(width: float) -> bool:
	return width / 2.0 >= LANE_HALF_WIDTH + MIN_CLEARANCE

## How far past the lane a feature has to start, and how far from the wall
## it has to stop. Half a player's width plus a hand's breadth.
const MIN_CLEARANCE := 0.6

## Where a feature actually lands, given what Epsilon asked for.
##
## `at` is a fraction of the chamber; the lateral half is pushed out of the
## walking lane, toward whichever side it already leaned. A feature asked
## for dead centre goes left rather than nowhere: refusing to place it
## would make a validated Zone quietly poorer than it read.
##
## Only meaningful where `fits(width)`; callers check that first.
static func resolve_position(at: Array, width: float, depth: float) -> Vector3:
	var u := clampf(float(at[0]) if at.size() > 0 else 0.5, 0.0, 1.0)
	var v := clampf(float(at[1]) if at.size() > 1 else 0.5, 0.0, 1.0)
	var x := (u - 0.5) * width
	var side := 1.0 if x >= 0.0 else -1.0
	# Out of the lane, and inside the wall: a feature clipped into masonry
	# is as useless as one in the doorway.
	var outer := maxf(LANE_HALF_WIDTH + MIN_CLEARANCE,
			width / 2.0 - MIN_CLEARANCE)
	x = side * clampf(absf(x), LANE_HALF_WIDTH + MIN_CLEARANCE, outer)
	# Keep clear of both thresholds; the entrance and exit doors are the
	# two places the mandatory path is narrowest.
	var z := clampf(v * depth, 2.5, maxf(2.6, depth - 2.5))
	return Vector3(x, 0.0, z)

## Build every feature a chamber declares. Called from `ChamberBuilders`
## after the room exists, so the extent is known and the lane is real.
static func place_all(root: Node3D, chamber: Dictionary, theme: String,
		width: float, depth: float, height: float) -> Array:
	var built: Array = []
	var features: Array = chamber.get("features", [])
	if not features.is_empty() and not fits(width):
		# Too narrow to hold anything beside the path. Optional content is
		# dropped rather than crammed in: see `fits`.
		return built
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|features" % [chamber.get("id", "c"), theme])
	for index in features.size():
		var feature: Dictionary = features[index]
		var tag := str(feature.get("tag", ""))
		var at: Array = feature.get("at", [0.5, 0.5])
		var origin := resolve_position(at, width, depth)
		var reward_id := "%s_%s_%d" % [
				str(chamber.get("id", "c")), tag, index]
		var node := _build(root, tag, theme, origin, width, depth, height,
				reward_id, str(feature.get("note", "")), rng)
		if node != null:
			node.add_to_group(GROUP)
			node.set_meta("affordance_tag", tag)
			built.append(node)
	return built

static func _build(root: Node3D, tag: String, theme: String,
		origin: Vector3, width: float, depth: float, height: float,
		reward_id: String, note: String,
		rng: RandomNumberGenerator) -> Node3D:
	match tag:
		"grapple_anchor":
			return _grapple_anchor(root, theme, origin, height, reward_id, note)
		"breakable_wall":
			return _breakable_wall(root, theme, origin, width, reward_id, note)
		"water_volume":
			return _water_volume(root, theme, origin, reward_id, note)
		"rail":
			return _rail(root, theme, origin, depth, reward_id, note)
		"wind_volume":
			return _wind_volume(root, theme, origin, height, reward_id, note)
		"bounce_pad":
			return _bounce_pad(root, theme, origin, reward_id, note)
		"moving_platform":
			return _moving_platform(root, theme, origin, height, reward_id, note)
	# An unknown tag is drift between the schema and this file, not a Zone
	# to silently degrade: the schema's Literal is closed, so reaching here
	# means a tag was added without geometry.
	push_error("affordance tag '%s' has no geometry" % tag)
	return null

## The reward a feature yields, hung at `where`. Always local (§14.2).
static func _reward(root: Node3D, tag: String, at: Vector3,
		reward_id: String, note: String) -> LocalRewardPickup:
	var text := note if note != "" else str(_NOTES.get(tag, "A fragment."))
	var pickup := LocalRewardPickup.create(
			"epsilon_note", reward_id, "Note: %s" % tag.replace("_", " "),
			text)
	pickup.position = at
	root.add_child(pickup)
	return pickup


# --- The seven ------------------------------------------------------------

## A ceiling hook with a ledge above it. The grapple family reaches it;
## nothing else does, and nothing required is up there.
static func _grapple_anchor(root: Node3D, theme: String, origin: Vector3,
		height: float, reward_id: String, note: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.position = origin
	root.add_child(anchor)
	var lip := clampf(height - 1.8, 3.2, 5.4)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.position = Vector3(0, lip + 1.4, 0)
	ring.rotation.x = PI / 2.0
	ring.material_override = ThemeMaterials.glow_material(
			Color(0.95, 0.8, 0.4), 1.8)
	anchor.add_child(ring)
	# The hook needs something solid to bite: a grapple raycast that passed
	# through a decorative ring would be a feature that visibly does nothing.
	var plate := StaticBody3D.new()
	var plate_shape := CollisionShape3D.new()
	var plate_box := BoxShape3D.new()
	plate_box.size = Vector3(1.0, 0.25, 1.0)
	plate_shape.shape = plate_box
	plate.add_child(plate_shape)
	var plate_mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.0, 0.25, 1.0)
	plate_mesh.mesh = box_mesh
	plate_mesh.material_override = ThemeMaterials.trim_mat(theme)
	plate.add_child(plate_mesh)
	plate.position = Vector3(0, lip + 1.85, 0)
	anchor.add_child(plate)

	var ledge := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var ledge_box := BoxShape3D.new()
	ledge_box.size = Vector3(2.2, 0.3, 2.2)
	shape.shape = ledge_box
	ledge.add_child(shape)
	var ledge_mesh := MeshInstance3D.new()
	var ledge_box_mesh := BoxMesh.new()
	ledge_box_mesh.size = Vector3(2.2, 0.3, 2.2)
	ledge_mesh.mesh = ledge_box_mesh
	ledge_mesh.material_override = ThemeMaterials.accent_mat(theme)
	ledge.add_child(ledge_mesh)
	ledge.position = Vector3(0, lip, 0)
	anchor.add_child(ledge)

	_reward(anchor, "grapple_anchor", Vector3(0, lip + 0.8, 0), reward_id, note)
	return anchor

## A panel that impact damage removes, with a nook behind it. Set against
## the side wall, so what it opens is a cupboard rather than a shortcut.
static func _breakable_wall(root: Node3D, theme: String, origin: Vector3,
		width: float, reward_id: String, note: String) -> Node3D:
	var nook := Node3D.new()
	var side := 1.0 if origin.x >= 0.0 else -1.0
	nook.position = Vector3(side * (width / 2.0 - 0.25), 0.0, origin.z)
	root.add_child(nook)

	# The recess first, so breaking the panel reveals somewhere to stand.
	var back := StaticBody3D.new()
	var back_shape := CollisionShape3D.new()
	var back_box := BoxShape3D.new()
	back_box.size = Vector3(0.3, 2.6, 2.4)
	back_shape.shape = back_box
	back.add_child(back_shape)
	var back_mesh := MeshInstance3D.new()
	var back_box_mesh := BoxMesh.new()
	back_box_mesh.size = Vector3(0.3, 2.6, 2.4)
	back_mesh.mesh = back_box_mesh
	back_mesh.material_override = ThemeMaterials.wall_mat(theme)
	back.add_child(back_mesh)
	back.position = Vector3(side * 1.6, 1.3, 0)
	nook.add_child(back)

	var panel := AffordanceNodes.BreakablePanel.new()
	panel.position = Vector3(0, 1.3, 0)
	panel.tint = ThemeMaterials.hazard_mat(theme).albedo_color
	nook.add_child(panel)

	_reward(nook, "breakable_wall", Vector3(side * 1.1, 0.9, 0), reward_id, note)
	return nook

## A shallow pool. Buoyant and draggy: you sink slowly, you swim slowly,
## and you can always get out — `Player.MIN_VOLUME_SPEED_SCALE` is the
## floor that makes "always" structural.
static func _water_volume(root: Node3D, theme: String, origin: Vector3,
		reward_id: String, note: String) -> Node3D:
	var pool := AffordanceNodes.Volume.new()
	pool.influence = {
		"gravity_scale": 0.22, "speed_scale": 0.62,
		"drag": 2.4, "terminal_fall": 3.5,
	}
	pool.extents = Vector3(3.2, 2.2, 3.2)
	pool.tint = Color(0.35, 0.75, 0.95)
	pool.position = origin + Vector3(0, 1.1, 0)
	root.add_child(pool)
	# Sunk, so it reads as something to go INTO rather than a blue box.
	var basin := MeshInstance3D.new()
	var basin_mesh := BoxMesh.new()
	basin_mesh.size = Vector3(3.4, 0.1, 3.4)
	basin.mesh = basin_mesh
	basin.position = origin + Vector3(0, 2.15, 0)
	basin.material_override = ThemeMaterials.glow_material(
			Color(0.4, 0.8, 1.0), 0.5)
	root.add_child(basin)
	_reward(root, "water_volume", origin + Vector3(0, 0.6, 0), reward_id, note)
	return pool

## A grind rail: a beam with a low-friction lane over it, so a dash along
## it carries much further than a dash on the floor.
static func _rail(root: Node3D, theme: String, origin: Vector3,
		depth: float, reward_id: String, note: String) -> Node3D:
	var length := clampf(depth * 0.45, 5.0, 14.0)
	var beam := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.35, 0.35, length)
	shape.shape = box
	beam.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.35, length)
	mesh_node.mesh = mesh
	mesh_node.material_override = ThemeMaterials.glow_material(
			Color(0.9, 0.7, 0.95), 1.2)
	beam.add_child(mesh_node)
	beam.position = origin + Vector3(0, 1.1, 0)
	root.add_child(beam)
	# Posts, so the rail is a thing in the room rather than a floating bar.
	for end in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.25, 1.1, 0.25)
		post.mesh = post_mesh
		post.position = origin + Vector3(0, 0.55, end * length / 2.0)
		post.material_override = ThemeMaterials.trim_mat(theme)
		root.add_child(post)

	var lane := AffordanceNodes.Volume.new()
	lane.influence = {"drag": 0.0, "speed_scale": 1.0, "gravity_scale": 0.85}
	lane.extents = Vector3(1.1, 1.4, length)
	lane.tint = Color(0.9, 0.7, 0.95)
	lane.visible_shell = false
	lane.position = origin + Vector3(0, 2.0, 0)
	root.add_child(lane)

	_reward(root, "rail", origin + Vector3(0, 1.9, length / 2.0 + 1.4),
			reward_id, note)
	return beam

## An updraft. Lift only — it can carry you up, never hold you down.
static func _wind_volume(root: Node3D, theme: String, origin: Vector3,
		height: float, reward_id: String, note: String) -> Node3D:
	var column := AffordanceNodes.Volume.new()
	# Lift has to BEAT gravity, not merely soften it: at gravity_scale 0.75
	# the column still pulls 18 m/s^2, so a 16 m/s^2 updraft is a slightly
	# slower fall dressed up as an updraft. The suite catches exactly that.
	column.influence = {"lift": 30.0, "gravity_scale": 0.75,
			"terminal_fall": 6.0}
	column.extents = Vector3(2.6, maxf(3.0, height - 0.6), 2.6)
	column.tint = Color(0.7, 0.95, 0.9)
	column.position = origin + Vector3(0, maxf(1.5, height / 2.0 - 0.3), 0)
	root.add_child(column)
	for ring in range(1, 4):
		var mark := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.0
		torus.outer_radius = 1.15
		mark.mesh = torus
		mark.position = origin + Vector3(0, float(ring) * 1.5, 0)
		mark.material_override = ThemeMaterials.glow_material(
				Color(0.7, 0.95, 0.9), 0.7)
		root.add_child(mark)
	var perch := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var lip := clampf(height - 1.6, 3.0, 5.2)
	box.size = Vector3(2.0, 0.3, 2.0)
	shape.shape = box
	perch.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.3, 2.0)
	mesh_node.mesh = mesh
	mesh_node.material_override = ThemeMaterials.accent_mat(theme)
	perch.add_child(mesh_node)
	perch.position = origin + Vector3(2.4, lip, 0)
	root.add_child(perch)
	_reward(root, "wind_volume", origin + Vector3(2.4, lip + 0.8, 0),
			reward_id, note)
	return column

## Base-kit usable: it launches whoever stands on it, item or no item.
static func _bounce_pad(root: Node3D, theme: String, origin: Vector3,
		reward_id: String, note: String) -> Node3D:
	var pad := AffordanceNodes.BouncePad.new()
	pad.position = origin
	pad.tint = ThemeMaterials.accent_mat(theme).albedo_color
	root.add_child(pad)
	_reward(root, "bounce_pad", origin + Vector3(0, 4.6, 0), reward_id, note)
	return pad

## Base-kit usable: it carries whoever stands on it. An `AnimatableBody3D`,
## so Godot's own mover carries the player rather than a bespoke ride.
static func _moving_platform(root: Node3D, theme: String, origin: Vector3,
		height: float, reward_id: String, note: String) -> Node3D:
	var platform := AffordanceNodes.MovingPlatform.new()
	platform.travel = Vector3(0, clampf(height - 2.2, 1.6, 3.6), 0)
	platform.position = origin + Vector3(0, 0.4, 0)
	platform.tint = ThemeMaterials.trim_mat(theme).albedo_color
	root.add_child(platform)
	_reward(root, "moving_platform",
			origin + Vector3(0, clampf(height - 1.4, 2.4, 4.4), 0),
			reward_id, note)
	return platform
