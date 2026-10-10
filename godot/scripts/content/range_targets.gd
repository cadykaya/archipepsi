class_name RangeTargets
extends RefCounted
## THE FIVE-WEAPON RANGE'S EXTRA TARGETS (03_TEST_AND_DELIVERY's layout):
## an ordinary 40 HP target that falls and stands again, a moving dummy
## for tracking, two loose bodies for the Mass Driver, a concrete pillar.
## No enemy AI: targets, not enemies.


## A padded mannequin with 40 HP (the ordinary-enemy comparison). It
## flinches away from each hit, falls when its HP runs out (the kill
## confirmation fires), lies for 2.5 s, then stands up whole, its marks
## cleared with it.
class Mannequin extends StaticBody3D:
	const HP := 40.0
	const DOWN_SECONDS := 2.5

	var hp := HP
	var down := false
	var kills := 0
	var _figure: Node3D
	var _label: Label3D
	var _tween: Tween

	func _ready() -> void:
		set_meta("impact_material", "organic")
		add_to_group(Damageable.GROUP)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.75
		shape.shape = capsule
		shape.position = Vector3(0, 0.9, 0)
		add_child(shape)
		_figure = Node3D.new()
		_figure.name = "Figure"
		add_child(_figure)
		var padding := StandardMaterial3D.new()
		padding.albedo_color = Color(0.72, 0.64, 0.52)
		padding.roughness = 0.95
		var torso := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.3
		body_mesh.height = 1.45
		torso.mesh = body_mesh
		torso.material_override = padding
		torso.position = Vector3(0, 0.78, 0)
		_figure.add_child(torso)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.16
		head_mesh.height = 0.32
		head.mesh = head_mesh
		head.material_override = padding
		head.position = Vector3(0, 1.62, 0)
		_figure.add_child(head)
		_label = Label3D.new()
		_label.font_size = 26
		_label.pixel_size = 0.006
		_label.position = Vector3(0, 2.05, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(_label)
		_refresh()

	func take_damage(amount: float, direction: Vector3 = Vector3.ZERO,
			_knockback: float = 0.0) -> bool:
		if down:
			return false
		hp = maxf(0.0, hp - amount)
		_refresh()
		if hp <= 0.0:
			down = true
			kills += 1
			_fall(direction)
			return true
		_flinch(direction, amount)
		return false

	func apply_knockback(_impulse: Vector3) -> void:
		pass

	## Leans away from the shot, harder for a heavier hit, and rocks home.
	func _flinch(direction: Vector3, amount: float) -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		var away := direction
		away.y = 0.0
		var lean := deg_to_rad(clampf(amount * 0.9, 2.0, 22.0))
		var axis := Vector3.UP.cross(away.normalized()) \
				if away.length() > 0.01 else Vector3.RIGHT
		_figure.basis = Basis(axis.normalized(), lean)
		_tween = create_tween()
		_tween.tween_property(_figure, "basis", Basis(), 0.45) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _fall(direction: Vector3) -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		var away := direction
		away.y = 0.0
		var axis := Vector3.UP.cross(away.normalized()) \
				if away.length() > 0.01 else Vector3.RIGHT
		# The whole target falls, collider and all, then stands again.
		_tween = create_tween()
		_tween.tween_property(self, "basis", Basis(axis.normalized(),
				deg_to_rad(80.0)), 0.35).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_IN)
		_tween.tween_interval(DOWN_SECONDS)
		_tween.tween_callback(_stand)

	func _stand() -> void:
		basis = Basis()
		_figure.basis = Basis()
		hp = HP
		down = false
		for child in get_children():
			if child is Decal:
				child.queue_free()
		_refresh()

	func _refresh() -> void:
		if _label != null:
			_label.text = "40 HP TARGET\n%d" % int(ceil(hp)) if not down \
					else "DOWN"


## The Lab's deterministic back-and-forth target, narrowed to the range's
## width and given a neutral steel finish (blue means movement here).
class Mover extends LabFixtures.LabMovingTarget:
	const RANGE_SPAN := 3.6

	func _ready() -> void:
		super._ready()
		set_meta("impact_material", "metal")
		add_to_group(Damageable.GROUP)
		_core.material_override = WeaponFeel._metal_piece()

	func advance(delta: float) -> void:
		elapsed += delta
		position = _origin + Vector3(
				RANGE_SPAN * sin(TAU * elapsed / PERIOD), 0, 0)


## A loose body for the Mass Driver: the game's own `ManipulableBody`,
## with a visible box and a material.
static func loose(id: String, mass_kg: float, size: Vector3, kind: String,
		color: Color) -> ManipulableBody:
	var body := ManipulableBody.create(id, mass_kg, size)
	body.set_meta("impact_material", kind)
	var mesh := MeshInstance3D.new()
	mesh.name = "Look"
	mesh.mesh = HandCannon._box(size)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.8 if kind == "metal" else 0.0
	material.roughness = 0.4 if kind == "metal" else 0.85
	mesh.material_override = material
	body.add_child(mesh)
	return body
