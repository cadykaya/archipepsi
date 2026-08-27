class_name Enemy
extends CharacterBody3D
## All three archetypes in one script, stat-driven from Constants.ENEMY_STATS.
## melee: walks at the player, short-range hits.
## ranged: holds position, fires slow visible projectiles.
## brute: large, slow, high-health — the POC boss.
##
## Direct steering plus collision recovery; no navmesh (EPSILON_SPEC §5).
## An enemy below ENEMY_FALL_KILL_Y counts as dead, so a steered-off enemy
## can never leave kill_all unsatisfiable.

signal enemy_died(enemy: Enemy)

var archetype := "melee"
var hp := 24.0
var stats: Dictionary = {}
var _attack_cooldown := 0.0
var _dead := false
var _knockback := Vector3.ZERO

static func create(kind: String, theme: String) -> Enemy:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/enemies/enemy.gd"))
	enemy.archetype = kind
	enemy.name = "Enemy_%s" % kind
	var stats: Dictionary = Constants.ENEMY_STATS[kind]
	enemy.stats = stats
	enemy.hp = float(stats["hp"])

	var size := Vector3(0.8, 1.6, 0.8)
	match kind:
		"ranged": size = Vector3(0.7, 1.4, 0.7)
		"brute": size = Vector3(1.8, 2.6, 1.8)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y / 2.0, 0)
	enemy.add_child(shape)

	# Deliberately crude low-poly body: a prism head on a box torso.
	var accent := ThemeMaterials.accent_mat(theme)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(size.x, size.y * 0.62, size.z)
	body.mesh = body_mesh
	body.position = Vector3(0, size.y * 0.31, 0)
	body.material_override = accent
	enemy.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(size.x * 0.8, size.y * 0.3, size.z * 0.8)
	head.mesh = head_mesh
	head.position = Vector3(0, size.y * 0.78, 0)
	head.material_override = ThemeMaterials.trim_mat(theme)
	enemy.add_child(head)
	var eye := MeshInstance3D.new()
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(size.x * 0.5, 0.08, 0.06)
	eye.mesh = eye_mesh
	eye.position = Vector3(0, size.y * 0.72, -size.z * 0.42)
	eye.material_override = ThemeMaterials.glow_material(
			Color(1.0, 0.25, 0.2), 2.0)
	enemy.add_child(eye)
	return enemy

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if global_position.y < Constants.ENEMY_FALL_KILL_Y:
		die()                      # counts as dead: kill_all stays satisfiable
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	velocity += _knockback
	_knockback = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= Constants.GRAVITY * delta

	var player := _find_player()
	if player != null:
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		if distance <= Constants.ENEMY_AGGRO_RADIUS:
			var flat := Vector3(to_player.x, 0, to_player.z)
			if flat.length() > 0.05:
				look_at(global_position + flat, Vector3.UP)
			var speed := float(stats["speed"])
			if speed > 0.0 and distance > float(stats["reach"]) * 0.8:
				var dir := flat.normalized()
				velocity.x = lerpf(velocity.x, dir.x * speed, 0.2)
				velocity.z = lerpf(velocity.z, dir.z * speed, 0.2)
			else:
				velocity.x = lerpf(velocity.x, 0.0, 0.3)
				velocity.z = lerpf(velocity.z, 0.0, 0.3)
			_try_attack(player, distance)
	move_and_slide()

func _find_player() -> Player:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null

func _try_attack(player: Player, distance: float) -> void:
	if _attack_cooldown > 0.0:
		return
	var reach := float(stats["reach"])
	if archetype == "ranged":
		if distance <= reach and _has_line_of_sight(player):
			_attack_cooldown = float(stats["cooldown"])
			_fire_projectile(player)
	elif distance <= reach:
		_attack_cooldown = float(stats["cooldown"])
		player.take_damage(float(stats["damage"]))

func _has_line_of_sight(player: Player) -> bool:
	var from := global_position + Vector3.UP * 1.2
	var to := player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == player

func _fire_projectile(player: Player) -> void:
	var projectile := EnemyProjectile.new()
	projectile.damage = float(stats["damage"])
	projectile.speed = Constants.RANGED_PROJECTILE_SPEED
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * 1.2
	projectile.direction = (player.global_position + Vector3.UP
			- projectile.global_position).normalized()

func take_damage(amount: float, direction: Vector3, knockback: float) -> void:
	if _dead:
		return
	hp -= amount
	if knockback > 0.0:
		_knockback += direction * knockback
	# Crude hit feedback: a scale punch. 1998 did not have hit shaders.
	var tween := create_tween()
	scale = Vector3.ONE * 0.88
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)
	if hp <= 0.0:
		die()

func apply_knockback(impulse: Vector3) -> void:
	_knockback += impulse

func die() -> void:
	if _dead:
		return
	_dead = true
	enemy_died.emit(self)
	# Crude death: tip over and sink. 1998 did not have ragdolls either.
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", PI / 2.0, 0.25)
	tween.tween_property(self, "position:y", position.y - 1.5, 0.6)
	tween.tween_callback(queue_free)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)


class EnemyProjectile extends Area3D:
	var damage := 8.0
	var speed := 14.0
	var direction := Vector3.FORWARD
	var _life := 6.0

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.2
		shape.shape = sphere
		add_child(shape)
		var visual := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.18
		mesh.height = 0.36
		visual.mesh = mesh
		visual.material_override = ThemeMaterials.glow_material(
				Color(0.9, 0.2, 0.9), 2.0)
		add_child(visual)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		global_position += direction * speed * delta
		_life -= delta
		if _life <= 0.0:
			queue_free()

	func _on_body_entered(body: Node3D) -> void:
		if body is Enemy:
			return
		if body.is_in_group("player"):
			body.take_damage(damage)
		queue_free()
