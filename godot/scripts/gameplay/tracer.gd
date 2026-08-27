class_name Tracer
extends MeshInstance3D
## A brief glowing beam between two points. 1998 hitscan feedback.

static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color,
		lifetime: float = 0.06) -> void:
	if parent == null:
		return
	var tracer := Tracer.new()
	var mesh := BoxMesh.new()
	var length := maxf(0.01, from.distance_to(to))
	mesh.size = Vector3(0.03, 0.03, length)
	tracer.mesh = mesh
	tracer.material_override = ThemeMaterials.glow_material(color, 2.2)
	parent.add_child(tracer)
	tracer.global_position = (from + to) / 2.0
	if not from.is_equal_approx(to):
		tracer.look_at_from_position(tracer.global_position, to, Vector3.UP)
	var timer := tracer.get_tree().create_timer(lifetime)
	timer.timeout.connect(tracer.queue_free)
