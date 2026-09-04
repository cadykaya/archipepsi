class_name Tracer
extends MeshInstance3D
## A brief glowing beam between two points. 1998 hitscan feedback.

## `style` is the source world's particle signature (ECHOES §12): the same
## shot from two different worlds reads differently without either one
## needing an asset. Thickness and dash are all a 1998 tracer can carry,
## and that turns out to be enough to tell them apart.
const STYLE_WIDTH := {"spark": 0.03, "drift": 0.05, "shard": 0.02,
		"ring": 0.06, "mote": 0.04, "streak": 0.025}
const STYLE_LIFETIME := {"spark": 1.0, "drift": 1.6, "shard": 0.8,
		"ring": 1.3, "mote": 1.5, "streak": 0.7}

static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color,
		lifetime: float = 0.06, style: String = "spark") -> void:
	if parent == null:
		return
	var tracer := Tracer.new()
	var beam := BoxMesh.new()
	var length := maxf(0.01, from.distance_to(to))
	var width: float = STYLE_WIDTH.get(style, 0.03)
	lifetime *= float(STYLE_LIFETIME.get(style, 1.0))
	beam.size = Vector3(width, width, length)
	tracer.mesh = beam
	tracer.material_override = ThemeMaterials.glow_material(color, 2.2)
	parent.add_child(tracer)
	tracer.global_position = (from + to) / 2.0
	if not from.is_equal_approx(to):
		# A vertical beam is collinear with UP (pitch clamps at exactly
		# ±90°) — pick a perpendicular up vector for that case.
		var dir := (to - from).normalized()
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 \
				else Vector3.RIGHT
		tracer.look_at_from_position(tracer.global_position, to, up)
	var timer := tracer.get_tree().create_timer(lifetime)
	timer.timeout.connect(tracer.queue_free)
