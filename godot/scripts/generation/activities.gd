class_name Activities
## The graybox activity vocabulary (CAMPAIGN_SCALE.md 9).
##
## Four composable families, built from primitives the base kit can
## already beat: a switch is touched, a target is shot with Static Pulse,
## a plate is stood on, a timed run is run. Nothing here needs an Echo,
## and nothing may be added that does.
##
## This file is the reason a "puzzle" can score. `test_activity_coverage`
## reads it and refuses any kind in the schema that has no branch here,
## so a vocabulary Epsilon can name but the engine cannot build is a
## failing test rather than a Zone that reads richer than it plays.

const SWITCH_SIZE := Vector3(0.6, 1.2, 0.3)
const TARGET_SIZE := Vector3(0.9, 0.9, 0.2)
const PLATE_SIZE := Vector3(1.4, 0.15, 1.4)

## Build one activity into `root`, returning what it made.
static func build(root: Node3D, activity: Dictionary, theme: String,
		width: float, depth: float) -> Dictionary:
	var kind := str(activity.get("kind", ""))
	var count := int(activity.get("element_count", 1))
	match kind:
		"switch_sequence":
			return _row(root, kind, count, SWITCH_SIZE, theme, width, depth,
					1.0)
		"target_challenge":
			return _row(root, kind, count, TARGET_SIZE, theme, width, depth,
					2.2)
		"pressure_routing":
			return _row(root, kind, count, PLATE_SIZE, theme, width, depth,
					0.08)
		"timed_run":
			# One start element and one goal, however many waypoints the
			# count asks for between them.
			return _row(root, kind, maxi(2, count), SWITCH_SIZE, theme,
					width, depth, 1.0)
		_:
			push_error("no builder for activity kind '%s'" % kind)
			return {"kind": kind, "elements": []}

## Elements spread across the room's width, clear of the walking lane at
## both ends -- the same lane an affordance is kept out of, for the same
## reason: an activity element standing in the doorway is an activity
## element the player walks into on the way past.
static func _row(root: Node3D, kind: String, count: int, size: Vector3,
		theme: String, width: float, depth: float,
		height: float) -> Dictionary:
	var elements: Array = []
	var usable := maxf(1.0, width - 2.0 * AffordanceFeatures.LANE_HALF_WIDTH
			- size.x)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (AffordanceFeatures.LANE_HALF_WIDTH + size.x / 2.0
				+ usable * 0.5 * t)
		var z := depth * (0.25 + 0.5 * t)
		var body := StaticBody3D.new()
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = ThemeMaterials.glow_material(
				ThemeMaterials.light_color(theme), 1.6)
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = size
		shape.shape = collider
		body.add_child(shape)
		body.name = "%s_%d" % [kind, i]
		root.add_child(body)
		body.position = Vector3(x, height, z)
		elements.append(body)
	return {"kind": kind, "elements": elements}
