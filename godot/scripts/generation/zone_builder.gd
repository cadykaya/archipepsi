class_name ZoneBuilder
extends RefCounted
## Chains chamber builds from the origin, inserts connectors and 90° corner
## pieces, and appends the exit portal after the final chamber. Epsilon
## never chooses world coordinates; this file owns them.
##
## Layouts may bend. Safety is layered: turns alternate direction (no
## U-shapes by construction), every placement is checked against all prior
## world-space bounds, and a chamber that would clip an earlier arm is
## pushed forward with extra connectors until clear. The mandatory path is
## still one walkable chain — only its shape varies.

const CONNECTOR_LENGTH := 5.0
const CONNECTOR_WIDTH := 4.0
const TURN_CHANCE := 0.45

static func _rot(yaw: float, v: Vector3) -> Vector3:
	return Basis(Vector3.UP, yaw) * v

static func _world_aabb(local: AABB, position: Vector3, yaw: float) -> AABB:
	var out: AABB
	for i in 8:
		var corner := position + _rot(yaw, local.get_endpoint(i))
		out = AABB(corner, Vector3.ZERO) if i == 0 else out.expand(corner)
	return out

static func _overlaps(placed: Array, candidate: AABB) -> bool:
	for existing: AABB in placed:
		if existing.intersection(candidate).get_volume() > 0.5:
			return true
	return false

## Places one connector at (cursor, yaw) and returns the advanced cursor.
## A helper rather than a lambda: GDScript lambdas capture Vector3 locals
## by value, which silently pinned every connector to the origin.
static func _emit_connector(root: Node3D, theme: String, cursor: Vector3,
		yaw: float, placed: Array, bounds_list: Array) -> Vector3:
	# A distinct id per connector: greebles and theme props seed from it,
	# and every connector sharing one id made them visibly copy-pasted.
	var connector := ChamberBuilders.corridor(
			{"id": "conn_%d" % bounds_list.size(),
			"length": CONNECTOR_LENGTH, "width": CONNECTOR_WIDTH}, theme)
	var node: Node3D = connector["root"]
	node.name = "Connector"
	node.position = cursor
	node.rotation.y = yaw
	root.add_child(node)
	var world: AABB = _world_aabb(connector["bounds"], cursor, yaw)
	placed.append(world)
	bounds_list.append(world)
	return cursor + _rot(yaw, connector["exit_offset"])

## Returns { root, spawn_transform, chambers: [{chamber, node, build,
##           xform}], exit_portal, bounds_list }
static func build(zone: Dictionary, theme_override := "") -> Dictionary:
	var theme: String = theme_override if theme_override != "" \
			else zone.get("theme", "void_glitch")
	var root := Node3D.new()
	root.name = "Zone_%s" % zone.get("zone_id", "unknown")

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(theme)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(theme)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = ThemeMaterials.void_color(theme).lightened(0.1)
	env.fog_density = 0.012
	environment.environment = env
	root.add_child(environment)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|layout" % [zone.get("zone_id", ""), theme])

	var cursor := Vector3.ZERO
	var yaw := 0.0
	var next_turn := 1 if rng.randf() < 0.5 else -1
	var placed: Array = []
	var built_chambers: Array = []
	var bounds_list: Array = []
	var first := true

	for chamber: Dictionary in zone.get("chambers", []):
		var result := ChamberBuilders.build(chamber, theme)

		# Maybe take a corner first. Turns alternate direction, and both the
		# corner and the chamber beyond it must clear every prior arm.
		if not first and rng.randf() < TURN_CHANCE:
			var corner := ChamberBuilders.corner(next_turn, theme)
			var corner_world: AABB = _world_aabb(corner["bounds"], cursor, yaw)
			var yaw_after := yaw + float(next_turn) * PI / 2.0
			var cursor_after: Vector3 = cursor \
					+ _rot(yaw, corner["exit_offset"])
			var chamber_world: AABB = _world_aabb(result["bounds"],
					cursor_after, yaw_after)
			if not _overlaps(placed, corner_world) \
					and not _overlaps(placed, chamber_world):
				var corner_node: Node3D = corner["root"]
				corner_node.name = "Corner"
				corner_node.position = cursor
				corner_node.rotation.y = yaw
				root.add_child(corner_node)
				placed.append(corner_world)
				bounds_list.append(corner_world)
				cursor = cursor_after
				yaw = yaw_after
				next_turn = -next_turn
			else:
				corner["root"].free()

		# Straight clearance: a wide chamber after a bend can reach back
		# toward an earlier arm; push forward until it clears.
		var attempts := 0
		while _overlaps(placed, _world_aabb(result["bounds"], cursor, yaw)) \
				and attempts < 6:
			cursor = _emit_connector(root, theme, cursor, yaw, placed,
					bounds_list)
			attempts += 1

		var node: Node3D = result["root"]
		node.name = "Chamber_%s" % chamber.get("id", "c")
		node.position = cursor
		node.rotation.y = yaw
		root.add_child(node)
		var world_bounds: AABB = _world_aabb(result["bounds"], cursor, yaw)
		placed.append(world_bounds)
		bounds_list.append(world_bounds)
		built_chambers.append({
			"chamber": chamber, "node": node, "build": result,
			"xform": Transform3D(Basis(Vector3.UP, yaw), cursor),
		})
		cursor += _rot(yaw, result["exit_offset"])
		cursor = _emit_connector(root, theme, cursor, yaw, placed,
				bounds_list)
		first = false

	# Exit room with the appended portal — checked like every other
	# placement, not trusted to clear by arithmetic coincidence.
	var exit_room := ChamberBuilders.treasure_room({"id": "exit"}, theme)
	var exit_attempts := 0
	while _overlaps(placed, _world_aabb(exit_room["bounds"], cursor, yaw)) \
			and exit_attempts < 6:
		cursor = _emit_connector(root, theme, cursor, yaw, placed,
				bounds_list)
		exit_attempts += 1
	var exit_node: Node3D = exit_room["root"]
	exit_node.name = "ExitRoom"
	exit_node.position = cursor
	exit_node.rotation.y = yaw
	root.add_child(exit_node)
	var exit_world: AABB = _world_aabb(exit_room["bounds"], cursor, yaw)
	placed.append(exit_world)
	bounds_list.append(exit_world)
	var portal := ExitPortal.create(theme)
	portal.position = cursor + _rot(yaw, Vector3(0, 0, 6.5))
	portal.rotation.y = yaw
	root.add_child(portal)

	# Face +Z, where the level actually is (identity looks down -Z).
	var spawn := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.8, 1.2))
	return {"root": root, "spawn_transform": spawn,
			"chambers": built_chambers, "exit_portal": portal,
			"bounds_list": bounds_list}
