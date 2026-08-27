class_name ZoneBuilder
extends RefCounted
## Chains chamber builds along +Z from the origin, inserts connectors, and
## appends the exit portal after the final chamber. Epsilon never chooses
## world coordinates; this file owns them.

const CONNECTOR_LENGTH := 5.0
const CONNECTOR_WIDTH := 4.0

## Returns { root, spawn_transform, chambers: [{dict, node, controller}],
##           exit_portal, bounds_list }
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

	var cursor := Vector3.ZERO
	var built_chambers: Array = []
	var bounds_list: Array = []

	for chamber: Dictionary in zone.get("chambers", []):
		var result := ChamberBuilders.build(chamber, theme)
		var node: Node3D = result["root"]
		node.name = "Chamber_%s" % chamber.get("id", "c")
		node.position = cursor
		root.add_child(node)
		var bounds: AABB = result["bounds"]
		bounds.position += cursor
		bounds_list.append(bounds)
		built_chambers.append({
			"chamber": chamber, "node": node, "build": result,
			"origin": cursor,
		})
		cursor += result["exit_offset"]
		# Connector to the next thing (chamber or exit room).
		var connector := ChamberBuilders.corridor(
				{"length": CONNECTOR_LENGTH, "width": CONNECTOR_WIDTH}, theme)
		var connector_node: Node3D = connector["root"]
		connector_node.name = "Connector"
		connector_node.position = cursor
		root.add_child(connector_node)
		var connector_bounds: AABB = connector["bounds"]
		connector_bounds.position += cursor
		bounds_list.append(connector_bounds)
		cursor += connector["exit_offset"]

	# Exit room with the appended portal.
	var exit_room := ChamberBuilders.treasure_room({}, theme)
	var exit_node: Node3D = exit_room["root"]
	exit_node.name = "ExitRoom"
	exit_node.position = cursor
	root.add_child(exit_node)
	var portal := ExitPortal.create(theme)
	portal.position = cursor + Vector3(0, 0, 6.5)
	root.add_child(portal)

	var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 1.2))
	return {"root": root, "spawn_transform": spawn,
			"chambers": built_chambers, "exit_portal": portal,
			"bounds_list": bounds_list}
