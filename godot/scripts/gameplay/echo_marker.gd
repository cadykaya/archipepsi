class_name EchoMarker
extends Node3D
## A waypoint the player put down. Cosmetic, and that is a rule rather than
## a limitation: §13.2 forbids a mandatory Check behind any affordance, and
## the cheapest way to keep a marker honest is for it to affect nothing.
##
## It is still useful — it is the only mark in the world the *player* chose,
## as opposed to the objective waypoint the Zone chose for them.

static func spawn(parent: Node, at: Vector3, color: Color,
		duration: float) -> void:
	if parent == null:
		return
	var marker := EchoMarker.new()
	parent.add_child(marker)
	marker.global_position = at

	var post := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.03
	mesh.height = 1.4
	post.mesh = mesh
	post.position = Vector3(0, 0.7, 0)
	post.material_override = ThemeMaterials.glow_material(color, 2.0)
	marker.add_child(post)

	var head := MeshInstance3D.new()
	var diamond := SphereMesh.new()
	diamond.radius = 0.16
	diamond.height = 0.42
	diamond.radial_segments = 4
	diamond.rings = 2
	head.mesh = diamond
	head.position = Vector3(0, 1.5, 0)
	head.material_override = ThemeMaterials.glow_material(
			color.lightened(0.3), 3.0)
	marker.add_child(head)

	# Spins so it reads as a placed object rather than as level geometry.
	var spin := marker.create_tween().set_loops()
	spin.tween_property(head, "rotation:y", TAU, 2.4).from(0.0)

	var timer := marker.get_tree().create_timer(duration)
	timer.timeout.connect(marker.queue_free)
