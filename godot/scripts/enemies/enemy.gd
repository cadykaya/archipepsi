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
## Starting HP, kept so an ability can ask how heavy this is.
## `grapple_pull_target` refuses a brute by asking this rather
## than by naming archetypes, so a future heavy enemy is
## covered without touching the primitive.
var max_hp := 24.0
var stats: Dictionary = {}
var _attack_cooldown := 0.0
var _dead := false
var _knockback := Vector3.ZERO
# Collision recovery (EPSILON_SPEC §5): sidestep briefly when walled.
var _sidestep_timer := 0.0
var _sidestep_dir := Vector3.ZERO
var _sidestep_flip := false
# Per-instance materials for the damage tint, unshared once on first hit.
var _tint_parts: Array[StandardMaterial3D] = []
var _tint_base_energy: Array[float] = []
var _tint_base_albedo: Array[Color] = []
var _voice: AudioStreamPlayer3D = null
var _has_noticed := false
# Brute slam windup.
var _windup := 0.0

static func create(kind: String, theme: String) -> Enemy:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/enemies/enemy.gd"))
	enemy.archetype = kind
	enemy.name = "Enemy_%s" % kind
	var stats: Dictionary = Constants.ENEMY_STATS[kind]
	enemy.stats = stats
	enemy.hp = float(stats["hp"])
	enemy.max_hp = float(stats["hp"])

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

	# Each archetype gets its own silhouette, because telling a sniper
	# from a charger across a dark room is gameplay information, not
	# decoration. Theme only supplies the palette.
	match kind:
		"ranged": _build_ranged(enemy, size, theme)
		"brute": _build_brute(enemy, size, theme)
		_: _build_melee(enemy, size, theme)
	return enemy

static func _part(parent: Node3D, size: Vector3, position: Vector3,
		material: Material, tilt := 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.rotation.x = tilt
	part.material_override = material
	parent.add_child(part)
	return part

static func _eye(parent: Node3D, size: Vector3, position: Vector3,
		color: Color) -> void:
	_part(parent, size, position, ThemeMaterials.glow_material(color, 2.4))

## Melee: hunched and forward-leaning, with stubby arms — it reads as
## something that wants to be where you are.
static func _build_melee(enemy: Node3D, size: Vector3, theme: String) -> void:
	var accent := ThemeMaterials.accent_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	_part(enemy, Vector3(size.x, size.y * 0.5, size.z * 0.8),
			Vector3(0, size.y * 0.34, -0.06), accent, -0.22)
	# Low, jutting head.
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(size.x * 0.7, size.y * 0.22, size.z * 0.9)
	head.mesh = head_mesh
	head.position = Vector3(0, size.y * 0.66, -size.z * 0.2)
	head.rotation.x = PI / 2.0          # snout forward, not spire upward
	head.material_override = trim
	enemy.add_child(head)
	# Arms stay inside the collider half-width (size.x * 0.5): geometry
	# that reaches past it clips through walls and door frames, and the
	# corridor lane budgets are sized to the collider.
	for side in [-1.0, 1.0]:
		_part(enemy, Vector3(size.x * 0.24, size.y * 0.36, size.z * 0.24),
				Vector3(side * size.x * 0.38, size.y * 0.34, -0.1), trim, -0.4)
	_part(enemy, Vector3(size.x * 0.7, size.y * 0.2, size.z * 0.6),
			Vector3(0, size.y * 0.1, 0), trim)
	_eye(enemy, Vector3(size.x * 0.42, 0.07, 0.05),
			Vector3(0, size.y * 0.66, -size.z * 0.56), Color(1.0, 0.3, 0.2))

## Ranged: a tall tripod that never moves — narrow stalk, big single lens.
static func _build_ranged(enemy: Node3D, size: Vector3, theme: String) -> void:
	var accent := ThemeMaterials.accent_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	for leg in 3:
		var angle := TAU * float(leg) / 3.0
		_part(enemy, Vector3(0.12, size.y * 0.5, 0.12),
				Vector3(sin(angle) * size.x * 0.4, size.y * 0.25,
					cos(angle) * size.z * 0.4), trim)
	_part(enemy, Vector3(0.16, size.y * 0.35, 0.16),
			Vector3(0, size.y * 0.62, 0), trim)
	# The head is the whole point of it: a wide sensor block, kept just
	# inside the collider so it cannot poke through walls.
	_part(enemy, Vector3(size.x * 0.95, size.y * 0.3, size.z * 0.7),
			Vector3(0, size.y * 0.88, 0), accent)
	_eye(enemy, Vector3(size.x * 0.8, 0.14, 0.05),
			Vector3(0, size.y * 0.88, -size.z * 0.38), Color(1.0, 0.6, 0.15))

## Brute: wide and low-slung, with shoulder blocks and a tiny head, so it
## reads as heavy before it reads as anything else.
static func _build_brute(enemy: Node3D, size: Vector3, theme: String) -> void:
	var accent := ThemeMaterials.accent_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	_part(enemy, Vector3(size.x, size.y * 0.46, size.z * 0.75),
			Vector3(0, size.y * 0.44, 0), accent)
	# Shoulders and arms are held inside the collider half-width
	# (size.x * 0.5). The brute's 1.8 m body already nearly fills a 2.4 m
	# doorway; geometry wider than the collider clips straight through it.
	for side in [-1.0, 1.0]:
		_part(enemy, Vector3(size.x * 0.28, size.y * 0.26, size.z * 0.9),
				Vector3(side * size.x * 0.36, size.y * 0.62, 0), trim)
		# Heavy arms hanging past the waist.
		_part(enemy, Vector3(size.x * 0.24, size.y * 0.42, size.z * 0.28),
				Vector3(side * size.x * 0.37, size.y * 0.26, -0.1), accent)
		# Legs.
		_part(enemy, Vector3(size.x * 0.3, size.y * 0.24, size.z * 0.35),
				Vector3(side * size.x * 0.24, size.y * 0.11, 0), trim)
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(size.x * 0.34, size.y * 0.16, size.z * 0.34)
	head.mesh = head_mesh
	head.position = Vector3(0, size.y * 0.74, -size.z * 0.1)
	head.material_override = trim
	enemy.add_child(head)
	_eye(enemy, Vector3(size.x * 0.22, 0.09, 0.05),
			Vector3(0, size.y * 0.74, -size.z * 0.3), Color(1.0, 0.2, 0.15))

func _ready() -> void:
	add_to_group("enemies")
	# Positional audio: a shot from off-screen should tell you where to
	# look, which the damage indicator can only do after you are already hit.
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 6.0
	_voice.max_distance = 45.0
	_voice.volume_db = -6.0
	add_child(_voice)

func _say(kind: String) -> void:
	if _voice == null:
		return
	_voice.stream = Tones.enemy_stream(kind)
	_voice.play()

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

	_sidestep_timer = maxf(0.0, _sidestep_timer - delta)
	var intended := Vector3.ZERO
	var position_before := global_position
	var player := _find_player()

	# The slam countdown runs unconditionally: a windup that started must
	# always resolve, even if the player dies or runs out of aggro range
	# during it. Otherwise the brute freezes mid-swell and fires a stale,
	# untelegraphed slam whenever the player next wanders close.
	if _windup > 0.0:
		_windup -= delta
		scale = Vector3.ONE * (1.0 + 0.12 * sin((0.5 - _windup) * TAU))
		if _windup <= 0.0:
			scale = Vector3.ONE
			_say("slam")
			if player != null:
				_slam(player)

	if player != null:
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		if distance <= Constants.ENEMY_AGGRO_RADIUS:
			if not _has_noticed:
				_has_noticed = true
				_say("aggro")
			var flat := Vector3(to_player.x, 0, to_player.z)
			if flat.length() > 0.05:
				look_at(global_position + flat, Vector3.UP)
			var speed := float(stats["speed"])
			if _windup > 0.0:
				# Committed to the slam: plant and telegraph. The countdown
				# itself runs below, outside this branch, so losing aggro
				# mid-swing cannot freeze the brute mid-telegraph.
				velocity.x = lerpf(velocity.x, 0.0, 0.4)
				velocity.z = lerpf(velocity.z, 0.0, 0.4)
			elif speed > 0.0 and distance > float(stats["reach"]) * 0.8:
				var dir := flat.normalized()
				if _sidestep_timer > 0.0:
					dir = _sidestep_dir
				intended = dir * speed
				velocity.x = lerpf(velocity.x, dir.x * speed, 0.2)
				velocity.z = lerpf(velocity.z, dir.z * speed, 0.2)
			else:
				velocity.x = lerpf(velocity.x, 0.0, 0.3)
				velocity.z = lerpf(velocity.z, 0.0, 0.3)
			if _windup <= 0.0:
				_try_attack(player, distance)
	move_and_slide()
	# Collision recovery: wanted to move but barely did -> slide sideways
	# for a beat instead of grinding into the geometry forever.
	#
	# The test is ACTUAL displacement, not post-slide velocity:
	# move_and_slide() rewrites velocity to the slid value, so a head-on
	# wall hit leaves ~0 horizontal velocity and a velocity-based test
	# never fires — precisely the stuck case this exists for.
	if player != null and _sidestep_timer <= 0.0 and intended != Vector3.ZERO:
		var moved := global_position - position_before
		var wanted := intended.length() * delta
		if Vector2(moved.x, moved.z).length() < wanted * 0.35:
			var toward := player.global_position - global_position
			var side := Vector3(toward.z, 0, -toward.x).normalized()
			# Alternate on each attempt: a side that stayed blocked is not
			# retried forever in a concave corner.
			_sidestep_flip = not _sidestep_flip
			_sidestep_dir = -side if _sidestep_flip else side
			_sidestep_timer = 0.55

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
	elif archetype == "brute":
		if distance <= reach:
			# The boss telegraphs: half a second of swelling, then the slam.
			# The growl matters more than the swell — you can hear it while
			# looking somewhere else.
			_attack_cooldown = float(stats["cooldown"])
			_windup = 0.5
			_say("windup")
	elif distance <= reach:
		_attack_cooldown = float(stats["cooldown"])
		_say("melee_hit")
		player.take_damage(float(stats["damage"]), global_position)

## The brute's payoff: damage plus a shove if the player lingered.
func _slam(player: Player) -> void:
	var to_player := player.global_position - global_position
	if to_player.length() <= float(stats["reach"]) * 1.4:
		player.take_damage(float(stats["damage"]), global_position)
		var away := Vector3(to_player.x, 0, to_player.z).normalized()
		player.velocity += away * 7.0 + Vector3.UP * 3.0

func _has_line_of_sight(player: Player) -> bool:
	var from := global_position + Vector3.UP * 1.2
	var to := player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == player

func _fire_projectile(player: Player) -> void:
	_say("shot")
	var projectile := EnemyProjectile.new()
	projectile.damage = float(stats["damage"])
	projectile.speed = Constants.RANGED_PROJECTILE_SPEED
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * 1.2
	projectile.direction = (player.global_position + Vector3.UP
			- projectile.global_position).normalized()

## Returns true when THIS hit was the one that killed it, so the shooter
## can confirm a kill without inspecting hp and racing the death tween.
func take_damage(amount: float, direction: Vector3, knockback: float) -> bool:
	if _dead:
		return false
	hp -= amount
	if knockback > 0.0:
		_knockback += direction * knockback
	# Crude hit feedback: a scale punch. 1998 did not have hit shaders.
	# Skipped mid-windup so it cannot cancel the brute's telegraph.
	if _windup <= 0.0:
		var tween := create_tween()
		scale = Vector3.ONE * 0.88
		tween.tween_property(self, "scale", Vector3.ONE, 0.1)
	_refresh_damage_tint()
	if hp <= 0.0:
		die()
		return true
	return false

## Wounded enemies visibly cook: the eye brightens and the body reddens as
## health drops, so "nearly dead" is readable without a health bar.
##
## The per-instance materials are unshared ONCE, on first damage, and then
## mutated in place. Duplicating them on every hit re-uploaded a dozen
## materials per Static Pulse tick and permanently broke batching with the
## cached theme materials.
func _refresh_damage_tint() -> void:
	var hurt := 1.0 - clampf(hp / maxf(1.0, float(stats["hp"])), 0.0, 1.0)
	if hurt <= 0.0:
		return
	if _tint_parts.is_empty():
		for child in get_children():
			if not (child is MeshInstance3D):
				continue
			var shared: Material = child.material_override
			if not (shared is StandardMaterial3D):
				continue
			var mine: StandardMaterial3D = shared.duplicate()
			child.material_override = mine
			_tint_parts.append(mine)
			# Capture the base energy BEFORE overwriting it, or the first
			# chip of damage makes the eye dimmer than undamaged.
			_tint_base_energy.append(mine.emission_energy_multiplier)
			_tint_base_albedo.append(mine.albedo_color)
	for i in _tint_parts.size():
		var material: StandardMaterial3D = _tint_parts[i]
		if material.emission_enabled:
			material.emission_energy_multiplier = \
					_tint_base_energy[i] * (1.0 + 1.6 * hurt)
		else:
			material.albedo_color = _tint_base_albedo[i].lerp(
					Color(1.0, 0.4, 0.3), hurt * 0.7)

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
			# The projectile's own position: the shot came from where it
			# is, which is what the player needs to turn toward.
			body.take_damage(damage, global_position)
		queue_free()
