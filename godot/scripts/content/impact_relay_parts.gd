class_name ImpactRelayParts
extends RefCounted
## THE IMPACT RELAY'S ONE NEW PIECE (G1, D-18 v2). Everything else in the
## room is the G0 lab's (`ImpactLabParts`: the plate, the flight and the
## shutter, unchanged) or the Crossing kit's (`CrossingDParts`: the lever,
## the raceway, the stand-ins).

const L := preload("res://scripts/content/impact_lab_parts.gd")


## A PLAIN DOOR that slides up into its head when told to, and stays open.
class SlideDoor extends StaticBody3D:
	signal opened

	var size := Vector3(2.0, 3.0, 0.3)
	var is_open := false
	var _rise := 0.0
	var _home := Vector3.ZERO

	func build(material: Material, trim: Material) -> void:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		add_child(shape)
		L.box(self, "Leaf", Vector3.ZERO, size, material)
		for y in [-size.y * 0.3, size.y * 0.3]:
			L.box(self, "Rib", Vector3(0, y, 0), Vector3(size.x - 0.2, 0.12,
					size.z + 0.04), trim)
		_home = position

	func open() -> void:
		if is_open:
			return
		is_open = true
		_home = position
		opened.emit()

	func _physics_process(delta: float) -> void:
		if not is_open or _rise >= size.y - 0.05:
			return
		_rise = minf(_rise + delta * 2.5, size.y - 0.05)
		position = _home + Vector3.UP * _rise
