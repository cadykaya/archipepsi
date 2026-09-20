class_name Enemy
extends CharacterBody3D
## Stat-driven from Constants.ENEMY_STATS, sized from
## Constants.ENEMY_ENVELOPES.
## melee: walks at the player, short-range hits.
## ranged: holds position, fires slow visible projectiles.
## brute: large, slow, high-health — the POC boss.
##
## Those three are the roles that can be PLACED. The approved art family is
## ten (`Constants.ENEMY_ROLES`), and every one of them has an agreed
## physical envelope so models can be built against it — but a role with an
## envelope and no stat block still has no behaviour, and `create()` refuses
## it rather than inventing one. Physical integration first (art req 7).
##
## Direct steering plus collision recovery; no navmesh (EPSILON_SPEC §5).
## An enemy below ENEMY_FALL_KILL_Y counts as dead, so a steered-off enemy
## can never leave kill_all unsatisfiable.

signal enemy_died(enemy: Enemy)

## An attack's windup began (art requirement 14). `kind` names the attack,
## `duration` is how long the promise lasts in seconds.
##
## A TELEGRAPH IS A PROMISE. This pair is the seam an authored telegraph
## attaches to: it fires from the real attack state, so a presentation
## that listens cannot drift from the attack it is announcing, and it
## never needs a clock of its own. Read `telegraph_progress()` for 0..1.
signal telegraph_started(kind: String, duration: float)
## The windup ended. `completed` is true when the attack actually landed
## and false when the enemy died or was removed part-way through — so a
## presentation can end differently for a promise kept and one broken,
## and either way it is TOLD rather than left to time out.
signal telegraph_finished(kind: String, completed: bool)

var archetype := "melee"
## This role's physical envelope, from `Constants.ENEMY_ENVELOPES`. Read by
## anything that needs to know how much room this enemy takes without
## measuring its collider back out of the tree.
var envelope: Dictionary = {}
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
## Presentation-only container. EVERY mesh hangs off this and nothing
## else does, so a hit flinch or a windup swell scales the LOOK and can
## never move the collider -- which is what `scale` on the body did, and
## it grew the brute's hitbox 12% for the half second it was winding up.
var visual: Node3D = null
## Where an authored telegraph attaches. A `Marker3D` at the collider's
## centre (`Constants.ENEMY_ENVELOPES[role].centre_y`), outside `visual`
## so a flinch does not drag the telegraph around with it.
var telegraph_origin: Marker3D = null
## The attack currently being telegraphed, "" when none.
var telegraph_kind := ""
var telegraph_duration := 0.0

static func create(kind: String, theme: String) -> Enemy:
	var enemy := CharacterBody3D.new()
	enemy.set_script(load("res://scripts/enemies/enemy.gd"))
	enemy.archetype = kind
	enemy.name = "Enemy_%s" % kind
	assert(Constants.ENEMY_STATS.has(kind),
			"'%s' has a physical envelope but no behaviour; " % kind
			+ "an approved art role is not yet a placeable enemy")
	var block: Dictionary = Constants.ENEMY_STATS[kind]
	enemy.stats = block
	enemy.hp = float(block["hp"])
	enemy.max_hp = float(block["hp"])

	# The envelope is CONTRACT, not a literal (art requirement 7). It used
	# to be three magic vectors in this match, while the art lane built
	# models to boxes it declared in a manifest -- two numbers for one
	# thing, and a model that clips through a door frame is the first time
	# anyone finds out. Both sides now read Constants.ENEMY_ENVELOPES.
	var envelope: Dictionary = Constants.ENEMY_ENVELOPES[kind]
	var size: Vector3 = envelope["size"]
	enemy.envelope = envelope
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	# Half-height for a walker, hover height for a flyer. Asking the
	# contract rather than assuming size.y / 2.0, which is only true of
	# something standing on the floor.
	shape.position = Vector3(0, float(envelope["centre_y"]), 0)
	enemy.add_child(shape)

	# Presentation hangs off `Visual`; the collider does not. Scaling the
	# BODY for a flinch or a windup swell scaled its collision shape too,
	# so the brute's hitbox grew 12% for the half second it telegraphed
	# and shrank to 88% every time it was hit. Presentation is never
	# mechanics truth (art requirement 14), and now it structurally cannot
	# be: there is nothing solid under `Visual` to scale.
	var body_visual := Node3D.new()
	body_visual.name = "Visual"
	enemy.add_child(body_visual)
	enemy.visual = body_visual

	# The attachment contract. A telegraph is authored against a stable
	# origin, and "the collider's centre" is the one point every role
	# already agrees on -- it comes from the same envelope the collider
	# does. Outside `Visual`, so a flinch does not drag it around.
	var origin := Marker3D.new()
	origin.name = "TelegraphOrigin"
	origin.position = Vector3(0, float(envelope["centre_y"]), 0)
	enemy.add_child(origin)
	enemy.telegraph_origin = origin

	# Each archetype gets its own silhouette, because telling a sniper
	# from a charger across a dark room is gameplay information, not
	# decoration. Theme only supplies the palette.
	match kind:
		"ranged": _build_ranged(body_visual, size, theme)
		"brute": _build_brute(body_visual, size, theme)
		_: _build_melee(body_visual, size, theme)
	return enemy

static func _part(parent: Node3D, size: Vector3, at: Vector3,
		material: Material, tilt := 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	part.rotation.x = tilt
	part.material_override = material
	parent.add_child(part)
	return part

static func _eye(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> void:
	_part(parent, size, at, ThemeMaterials.glow_material(color, 2.4))

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

## S5 statuses: this enemy's own conditions. Reset with the enemy, which
## dies or despawns with the Zone — nothing here is ever saved (I9).
var statuses := StatusEffects.new()

func _ready() -> void:
	add_to_group("enemies")
	# ...and the wider group every damage path tests. "enemies" still
	# means enemies, for the paths that mean enemies.
	add_to_group(Damageable.GROUP)
	statuses.side = "enemy"
	statuses.status_applied.connect(func(_kind: String) -> void:
		_refresh_damage_tint())
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
	# Shocked nerves recover slower; the cooldown itself is the stagger.
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta
			* (1.0 - 0.5 * clampf(statuses.magnitude_of("shocked"), 0.0, 1.0)))
	statuses.tick(delta)
	var dot := statuses.dot_per_second()
	if dot > 0.0:
		_take_dot(dot * delta)
		if _dead:
			return

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
		# The swell is the ENGINE's fallback telegraph, and it scales
		# `visual` rather than the body -- on the body it grew the
		# collider with it. An authored telegraph listening to
		# `telegraph_started` replaces the look and never the timing.
		_set_visual_scale(1.0 + 0.12 * sin(
				(telegraph_duration - _windup) * TAU))
		if _windup <= 0.0:
			_set_visual_scale(1.0)
			_say("slam")
			if player != null:
				_slam(player)
			_end_telegraph(true)

	if player != null:
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		# `low_profile` on the player shrinks how far this enemy notices —
		# §10's "visibility" channel, a downside's counterpart.
		var aggro := Constants.ENEMY_AGGRO_RADIUS \
				* (1.0 - 0.5 * clampf(
						player.statuses.magnitude_of("low_profile"), 0.0, 1.0))
		if distance <= aggro:
			if not _has_noticed:
				_has_noticed = true
				_say("aggro")
			var flat := Vector3(to_player.x, 0, to_player.z)
			if flat.length() > 0.05:
				look_at(global_position + flat, Vector3.UP)
			var speed := float(stats["speed"]) \
					* (1.0 - 0.5 * clampf(
							statuses.magnitude_of("slowed"), 0.0, 1.0))
			if statuses.has("frozen") or statuses.has("stunned"):
				# Held in place, attacks withheld. The two differ in how
				# they were earned and how they read, not in physics.
				velocity.x = lerpf(velocity.x, 0.0, 0.5)
				velocity.z = lerpf(velocity.z, 0.0, 0.5)
			elif _windup > 0.0:
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
			if _windup <= 0.0 and not statuses.has("frozen") \
					and not statuses.has("stunned"):
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
			_begin_telegraph("slam", 0.5)
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
		player.receive_knockback(away * 7.0 + Vector3.UP * 3.0)

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
	# Marked and vulnerable targets take more — the mark is a promise, not
	# just a glow.
	amount *= 1.0 + 0.25 * clampf(statuses.magnitude_of("marked"), 0.0, 2.0)
	amount *= 1.0 + 0.5 * clampf(statuses.magnitude_of("vulnerable"), 0.0, 2.0)
	hp -= amount
	if knockback > 0.0:
		_knockback += direction * knockback
	# Crude hit feedback: a scale punch. 1998 did not have hit shaders.
	# Skipped mid-windup so it cannot cancel the brute's telegraph.
	# On `visual`, so being hit no longer shrinks the hitbox to 88%.
	if _windup <= 0.0 and visual != null:
		var tween := create_tween()
		visual.scale = Vector3.ONE * 0.88
		tween.tween_property(visual, "scale", Vector3.ONE, 0.1)
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
func _ensure_tint_parts() -> void:
	if not _tint_parts.is_empty():
		return
	# RECURSIVE, because the meshes moved under `Visual`. A non-recursive
	# walk kept compiling and silently found nothing, which is a damage
	# tint that never appears -- there is a test for exactly that.
	_collect_tint_parts(self)

func _collect_tint_parts(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var shared: Material = child.material_override
			if shared is StandardMaterial3D:
				var mine: StandardMaterial3D = shared.duplicate()
				child.material_override = mine
				_tint_parts.append(mine)
				# Capture the base energy BEFORE overwriting it, or the
				# first chip of damage makes the eye dimmer than undamaged.
				_tint_base_energy.append(mine.emission_energy_multiplier)
				_tint_base_albedo.append(mine.albedo_color)
		_collect_tint_parts(child)

func _refresh_damage_tint() -> void:
	var hurt := 1.0 - clampf(hp / maxf(1.0, float(stats["hp"])), 0.0, 1.0)
	var marked := statuses.has("marked")
	if hurt <= 0.0 and not marked:
		return
	_ensure_tint_parts()
	for i in _tint_parts.size():
		var material: StandardMaterial3D = _tint_parts[i]
		if material.emission_enabled:
			# A marked target glows over and above its wounds — scan_mark
			# is only worth a slot if the mark is visible across a room.
			material.emission_energy_multiplier = \
					_tint_base_energy[i] * (1.0 + 1.6 * hurt) \
					* (2.2 if marked else 1.0)
		else:
			var albedo := _tint_base_albedo[i].lerp(
					Color(1.0, 0.4, 0.3), hurt * 0.7)
			if marked:
				albedo = albedo.lerp(Color(1.0, 0.85, 0.3), 0.45)
			material.albedo_color = albedo

func apply_knockback(impulse: Vector3) -> void:
	_knockback += impulse

## Burning and poison chip without the scale-punch flinch: a tween per
## physics frame is a strobe, and a DoT is ambient harm rather than a hit.
func _take_dot(amount: float) -> void:
	hp -= amount
	_refresh_damage_tint()
	if hp <= 0.0:
		die()

# ---------------------------------------------------------------------
# Telegraph seam (art requirement 14)
# ---------------------------------------------------------------------
# Engineering owns the event, the state and the attachment point. Art owns
# what a telegraph LOOKS like. The two meet at `telegraph_started`,
# `telegraph_origin` and `telegraph_progress()`, and nowhere else.

## How far through the current windup, 0.0 to 1.0. Returns 0.0 when
## nothing is being telegraphed.
##
## The reason this exists rather than a presentation timing itself: a
## second clock drifts, and a drifting telegraph is a promise broken by a
## rounding error. There is exactly one countdown and it is the one the
## attack uses.
func telegraph_progress() -> float:
	if telegraph_kind.is_empty() or telegraph_duration <= 0.0:
		return 0.0
	return clampf(1.0 - _windup / telegraph_duration, 0.0, 1.0)

## Whether an attack is being announced right now.
func is_telegraphing() -> bool:
	return not telegraph_kind.is_empty()

func _begin_telegraph(kind: String, duration: float) -> void:
	# A windup that started must always resolve (see `_physics_process`),
	# so a second one cannot open on top of the first.
	if not telegraph_kind.is_empty():
		return
	telegraph_kind = kind
	telegraph_duration = duration
	_windup = duration
	telegraph_started.emit(kind, duration)

func _end_telegraph(completed: bool) -> void:
	if telegraph_kind.is_empty():
		return
	var kind := telegraph_kind
	telegraph_kind = ""
	telegraph_duration = 0.0
	_windup = 0.0
	_set_visual_scale(1.0)
	telegraph_finished.emit(kind, completed)

## Presentation scale, applied to `visual` and never to the body. The
## collider is a direct child of the body, so scaling the body scaled the
## hitbox -- the thing this whole seam exists to make impossible.
func _set_visual_scale(factor: float) -> void:
	if visual != null:
		visual.scale = Vector3.ONE * factor

func _exit_tree() -> void:
	# Despawned mid-windup. The listener is told rather than left holding
	# a telegraph for an enemy that no longer exists.
	_end_telegraph(false)

func die() -> void:
	if _dead:
		return
	_dead = true
	# A promise this enemy will not keep. Told, not left to time out: a
	# telegraph running its own clock would finish announcing a slam that
	# is never coming.
	_end_telegraph(false)
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
