class_name AffordanceNodes
extends RefCounted
## The interactive parts of the §13 affordances.
##
## Grouped here for the same reason `LabFixtures` groups the Lab's: each is
## a few dozen lines of one idea, and a file apiece would scatter the
## family. None of them reimplements movement, damage or rewards — the
## volume writes into the player's own environment layer, the panel takes
## damage through the same `take_damage` signature enemies expose, and what
## any of them yields is a `LocalRewardPickup`.


## A region that influences movement while you are inside it: water, wind,
## a rail's low-friction lane. It owns no movement code — it hands the
## player an influence dictionary and the player's own physics step merges
## it (`Player.environment_influence`).
class Volume extends Area3D:
	var influence: Dictionary = {}
	var extents := Vector3(3.0, 2.0, 3.0)
	var tint := Color(0.5, 0.8, 1.0)
	## Water and wind should be visible; a rail's lane is implied by the
	## rail, and a second translucent box over it just reads as fog.
	var visible_shell := true

	var _inside: Array[Node] = []

	func _ready() -> void:
		monitoring = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = extents
		shape.shape = box
		add_child(shape)
		if visible_shell:
			var mesh_node := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = extents
			mesh_node.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(tint.r, tint.g, tint.b, 0.28)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.emission_enabled = true
			material.emission = tint
			material.emission_energy_multiplier = 0.35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_node.material_override = material
			add_child(mesh_node)
		body_entered.connect(_on_entered)
		body_exited.connect(_on_exited)
		# A volume freed while the player is standing in it would otherwise
		# leave its influence applied forever, with nothing left to exit.
		tree_exiting.connect(_release_all)

	func _on_entered(body: Node3D) -> void:
		if body is Player:
			_inside.append(body)
			(body as Player).enter_volume(self, influence)

	func _on_exited(body: Node3D) -> void:
		if body is Player:
			_inside.erase(body)
			(body as Player).exit_volume(self)

	func _release_all() -> void:
		for body: Node in _inside:
			if is_instance_valid(body) and body is Player:
				(body as Player).exit_volume(self)
		_inside.clear()


## A wall panel that impact damage removes.
##
## The threshold is the point: §13.1 pays for this affordance with "an
## owned action that can deal impact damage at or above a threshold", and
## an affordance the base kit could open would make that requirement a
## fiction. The Static Pulse does `STATIC_PULSE_DAMAGE` a shot, so the
## threshold sits above it — a pulse chips nothing, and the panel reports
## why rather than absorbing hits in silence.
class BreakablePanel extends StaticBody3D:
	signal broken

	const HP := 40.0
	## Per-hit, not cumulative: the gate is "can you hit hard", not "can you
	## hit often". Otherwise a long enough pulse burst opens it and the
	## capability requirement means nothing.
	const MIN_IMPACT := Constants.STATIC_PULSE_DAMAGE * 2.0

	var hp := HP
	var tint := Color(0.8, 0.45, 0.3)
	var refused := 0

	var _mesh: MeshInstance3D
	var _label: Label3D

	func _ready() -> void:
		add_to_group("breakable")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 2.6, 2.4)
		shape.shape = box
		add_child(shape)
		_mesh = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.4, 2.6, 2.4)
		_mesh.mesh = mesh
		_mesh.material_override = ThemeMaterials.glow_material(tint, 0.5)
		add_child(_mesh)
		# Cracks, so it reads as breakable before you have tried.
		for i in 3:
			var crack := MeshInstance3D.new()
			var crack_mesh := BoxMesh.new()
			crack_mesh.size = Vector3(0.44, 0.06, 1.6 - 0.3 * i)
			crack.mesh = crack_mesh
			crack.position = Vector3(0, 0.6 + 0.7 * i, 0.1 * i)
			crack.rotation.x = 0.2 * (i - 1)
			crack.material_override = ThemeMaterials.glow_material(
					tint.darkened(0.4), 0.2)
			add_child(crack)
		_label = Label3D.new()
		_label.font_size = 20
		_label.pixel_size = 0.004
		_label.position = Vector3(0, 2.9, 0)
		_label.modulate = tint
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.visible = false
		add_child(_label)

	## `Enemy`'s signature, so every existing damage call site reaches it
	## without knowing what it hit.
	func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO,
			_knockback: float = 0.0) -> bool:
		if amount < MIN_IMPACT:
			refused += 1
			if _label != null:
				_label.text = "NEEDS A HEAVIER HIT"
				_label.visible = true
			return false
		hp -= amount
		if hp <= 0.0:
			broken.emit()
			queue_free()
			return true
		if _mesh != null:
			_mesh.material_override = ThemeMaterials.glow_material(
					tint, 0.5 + 1.5 * (1.0 - hp / HP))
		return false

	func apply_knockback(_impulse: Vector3) -> void:
		pass


## Launches whoever stands on it. Base-kit usable by design (§13.1): no
## owned capability is required, so it is the one affordance that can
## appear in a campaign that has interpreted nothing yet.
class BouncePad extends Area3D:
	## Chosen against `JUMP_VELOCITY` (8.0) so the pad is unmistakably more
	## than a jump without being a launch you cannot read.
	const LAUNCH := 16.0

	var tint := Color(0.95, 0.85, 0.4)
	var launched := 0

	func _ready() -> void:
		monitoring = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 0.5, 2.0)
		shape.shape = box
		shape.position = Vector3(0, 0.25, 0)
		add_child(shape)
		var mesh_node := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.1
		mesh.height = 0.4
		mesh_node.mesh = mesh
		mesh_node.position = Vector3(0, 0.2, 0)
		mesh_node.material_override = ThemeMaterials.glow_material(tint, 1.6)
		add_child(mesh_node)
		body_entered.connect(_on_entered)

	func _on_entered(body: Node3D) -> void:
		if body is Player:
			launch(body as Player)

	## Public so the suite can fire it without staging an overlap.
	func launch(player: Player) -> void:
		launched += 1
		# Set rather than add: a pad you hit while already rising should
		# send you the same height as one you step onto, or "how high does
		# it go" has no answer.
		player.velocity.y = LAUNCH


## A platform on a fixed loop. An `AnimatableBody3D` moved in
## `_physics_process`, which is how Godot carries a `CharacterBody3D`
## standing on it — a bespoke ride would desync from `move_and_slide`.
class MovingPlatform extends AnimatableBody3D:
	const PERIOD := 5.0

	var travel := Vector3(0, 3.0, 0)
	var tint := Color(0.6, 0.65, 0.7)
	var elapsed := 0.0
	## Where along `travel` the platform intends to be, 0..1. Reported
	## separately because `sync_to_physics` makes `position` a read of the
	## physics server rather than of what was last assigned — so this is
	## what a test can check without waiting on a physics frame.
	var phase := 0.0

	var _origin := Vector3.ZERO

	func _ready() -> void:
		sync_to_physics = true
		_origin = position
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.4, 0.4, 2.4)
		shape.shape = box
		add_child(shape)
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 0.4, 2.4)
		mesh_node.mesh = mesh
		mesh_node.material_override = ThemeMaterials.glow_material(tint, 0.6)
		add_child(mesh_node)

	func _physics_process(delta: float) -> void:
		advance(delta)

	## Split out so the suite can step it by hand; a motion test that waited
	## on wall-clock frames would prove nothing about where it goes.
	func advance(delta: float) -> void:
		elapsed += delta
		# 0..1..0, so it starts at its origin and returns there: a platform
		# whose loop began mid-travel would spawn inside the floor.
		phase = 0.5 - 0.5 * cos(TAU * elapsed / PERIOD)
		position = _origin + travel * phase
