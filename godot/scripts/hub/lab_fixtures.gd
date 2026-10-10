class_name LabFixtures
extends RefCounted
## The Echo Lab's fixtures (ECHOES §17). Each is a thin adapter onto a
## production interface — none of them reimplements damage, statuses or
## the action runner. If one needed to, that would be evidence the
## production interface was missing a seam, and the fix would belong
## there rather than here.


## The target dummy. Takes real Action damage through `Enemy`'s own
## interface and wears real statuses, so what you learn about your build
## from hitting it is true of hitting an enemy.
##
## It cannot die, and that is a mechanical decision rather than a
## convenience: since S4 a rule may read `kill`, and `kill -> resource_add`
## is a shape the shipped fallback produces. A dummy that died would let
## the player farm kill events in the Hub, which would make the Lab alter
## the economy it exists to inspect. So it clamps at 1 hp and reports the
## damage instead.
class LabDummy extends StaticBody3D:
	signal damage_taken(amount: float)

	const MAX_HP := 500.0

	var hp := MAX_HP
	## Every point of damage this fixture has absorbed since the last
	## reset. The readout, and the suite's vacuity guard.
	var absorbed := 0.0
	## Real `StatusEffects`, on the enemy side, so an owned StatusComponent
	## floors an application here exactly as it would on an enemy.
	var statuses := StatusEffects.new()

	var _label: Label3D
	var _core: MeshInstance3D
	var _flash := 0.0

	func _ready() -> void:
		statuses.side = "enemy"
		add_to_group("lab_fixtures")
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.9
		capsule.radius = 0.45
		shape.shape = capsule
		shape.position = Vector3(0, 0.95, 0)
		add_child(shape)
		_core = MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.height = 1.9
		mesh.radius = 0.45
		_core.mesh = mesh
		_core.position = Vector3(0, 0.95, 0)
		_core.material_override = ThemeMaterials.glow_material(
				Color(0.75, 0.7, 0.6), 0.5)
		add_child(_core)
		_label = Label3D.new()
		_label.font_size = 26
		_label.pixel_size = 0.006
		_label.position = Vector3(0, 2.4, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(_label)
		_refresh()

	## `Enemy`'s signature, so the same call sites reach it: Static Pulse,
	## hitscans, projectiles, melee and rule effects all already speak it.
	## Returns whether this hit was fatal — always false, by design.
	func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO,
			_knockback: float = 0.0) -> bool:
		amount *= 1.0 + 0.25 * clampf(
				statuses.magnitude_of("marked"), 0.0, 2.0)
		amount *= 1.0 + 0.5 * clampf(
				statuses.magnitude_of("vulnerable"), 0.0, 2.0)
		absorbed += amount
		hp = maxf(1.0, hp - amount)
		_flash = 1.0
		damage_taken.emit(amount)
		_refresh()
		return false

	## Enemies expose this for knockback modifiers; the dummy accepts and
	## ignores it rather than making callers special-case a fixture.
	func apply_knockback(_impulse: Vector3) -> void:
		pass

	func _physics_process(delta: float) -> void:
		statuses.tick(delta)
		var dot := statuses.dot_per_second()
		if dot > 0.0:
			absorbed += dot * delta
			hp = maxf(1.0, hp - dot * delta)
			_refresh()
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 3.0)
			_core.material_override = ThemeMaterials.glow_material(
					Color(0.75, 0.7, 0.6).lerp(Color(1.0, 0.5, 0.4), _flash),
					0.5 + _flash)

	func _refresh() -> void:
		if _label == null:
			return
		var marks: PackedStringArray = []
		for kind in statuses.active_kinds():
			marks.append(str(kind))
		_label.text = "DUMMY  %d dmg" % int(absorbed)
		if not marks.is_empty():
			_label.text += "\n" + " ".join(marks)

	func reset_fixture() -> void:
		hp = MAX_HP
		absorbed = 0.0
		statuses.clear()
		_flash = 0.0
		_refresh()

	func interact_prompt() -> String:
		return "[E] reset dummy"

	func interact(_player: Node) -> void:
		reset_fixture()


## A deterministic back-and-forth target: leading a projectile, tracking a
## beam, timing a burst. Motion is a fixed function of elapsed time, so
## two runs of the same length put it in the same place — which is what
## makes comparing two Echoes against it mean anything.
class LabMovingTarget extends StaticBody3D:
	const SPAN := 6.0
	const PERIOD := 4.0

	var elapsed := 0.0
	var hits := 0
	var _origin := Vector3.ZERO
	var _core: MeshInstance3D

	func _ready() -> void:
		add_to_group("lab_fixtures")
		_origin = position
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 1.6, 0.9)
		shape.shape = box
		add_child(shape)
		_core = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.9, 1.6, 0.9)
		_core.mesh = mesh
		_core.material_override = ThemeMaterials.glow_material(
				Color(0.5, 0.8, 1.0), 0.8)
		add_child(_core)

	func take_damage(_amount: float, _direction: Vector3 = Vector3.ZERO,
			_knockback: float = 0.0) -> bool:
		hits += 1
		return false

	func apply_knockback(_impulse: Vector3) -> void:
		pass

	func _physics_process(delta: float) -> void:
		advance(delta)

	## Split out so the suite can step it by hand: a motion test that
	## depended on wall-clock frames would prove nothing about determinism.
	func advance(delta: float) -> void:
		elapsed += delta
		position = _origin + Vector3(
				SPAN * sin(TAU * elapsed / PERIOD), 0, 0)

	func reset_fixture() -> void:
		elapsed = 0.0
		hits = 0
		position = _origin


## The damage source: armed by the player, never ambient. A Lab that hurt
## you for standing in it would become intolerable the moment passive
## rules existed.
##
## It calls `player.take_damage`, the same entry point enemies use, so
## `damage_taken` traits, shields, a held block, statuses and every
## low-health rule are genuinely exercised rather than simulated.
class LabHazard extends StaticBody3D:
	const INTERVAL := 1.0
	const DAMAGE := 8.0
	const RADIUS := 4.0

	var armed := false
	var fired := 0
	var _timer := 0.0
	var _core: MeshInstance3D
	var _label: Label3D

	func _ready() -> void:
		add_to_group("lab_fixtures")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 1.6, 1.4)
		shape.shape = box
		shape.position = Vector3(0, 0.8, 0)
		add_child(shape)
		_core = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.4, 1.6, 1.4)
		_core.mesh = mesh
		_core.position = Vector3(0, 0.8, 0)
		add_child(_core)
		_label = Label3D.new()
		_label.font_size = 24
		_label.pixel_size = 0.006
		_label.position = Vector3(0, 2.2, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(_label)
		_refresh()

	func _physics_process(delta: float) -> void:
		if not armed:
			return
		_timer -= delta
		if _timer <= 0.0:
			_timer = INTERVAL
			strike()

	## Public so the suite can fire it deterministically instead of waiting
	## on a timer.
	func strike() -> void:
		for node in get_tree().get_nodes_in_group("player"):
			if node is Player and node.global_position.distance_to(
					global_position) <= RADIUS:
				fired += 1
				(node as Player).take_damage(DAMAGE, global_position)

	func _refresh() -> void:
		_core.material_override = ThemeMaterials.glow_material(
				Color(1.0, 0.35, 0.3) if armed else Color(0.3, 0.3, 0.35),
				1.6 if armed else 0.4)
		_label.text = "HAZARD  %s" % ("ARMED" if armed else "SAFE")

	func interact_prompt() -> String:
		return "[E] disarm hazard" if armed else "[E] arm hazard"

	func interact(_player: Node) -> void:
		armed = not armed
		_timer = 0.0
		_refresh()

	func reset_fixture() -> void:
		armed = false
		fired = 0
		_timer = 0.0
		_refresh()


## The reset pad. One obvious control that returns the workbench to
## baseline and touches nothing the player earned.
class LabResetPad extends StaticBody3D:
	signal reset_requested(player: Player)

	func _ready() -> void:
		add_to_group("lab_fixtures")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 0.6, 1.6)
		shape.shape = box
		shape.position = Vector3(0, 0.3, 0)
		add_child(shape)
		var core := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.6, 0.6, 1.6)
		core.mesh = mesh
		core.position = Vector3(0, 0.3, 0)
		core.material_override = ThemeMaterials.glow_material(
				Color(0.5, 0.95, 0.7), 1.0)
		add_child(core)
		var label := Label3D.new()
		label.text = "RESET LAB"
		label.font_size = 28
		label.pixel_size = 0.006
		label.position = Vector3(0, 1.2, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

	func interact_prompt() -> String:
		return "[E] reset the lab"

	func interact(player: Node) -> void:
		reset_requested.emit(player if player is Player else null)
