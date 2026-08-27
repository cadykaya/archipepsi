class_name Blast
extends MeshInstance3D
## An expanding shell that marks where a lob went off and how far it reached.
##
## The radius is the real one from the primitive, not a decorative flourish:
## a blast you can see the edge of is a blast you can learn to stand outside
## of, and `arc_lob` damage falls off toward that rim.

static func spawn(parent: Node, at: Vector3, radius: float,
		color: Color) -> void:
	if parent == null:
		return
	var blast := Blast.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	blast.mesh = mesh
	blast.material_override = ThemeMaterials.glow_material(
			color.lightened(0.2), 3.0)
	parent.add_child(blast)
	blast.global_position = at
	# Starts small and bright, ends full-size and gone: the shell reads as
	# the shockwave arriving rather than as a ball fading where it sat.
	blast.scale = Vector3.ONE * 0.25
	var tween := blast.create_tween().set_parallel(true)
	tween.tween_property(blast, "scale", Vector3.ONE, 0.22)
	tween.tween_property(blast, "transparency", 1.0, 0.30)
	tween.chain().tween_callback(blast.queue_free)
