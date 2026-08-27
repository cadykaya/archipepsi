class_name EchoRuntime
extends Node
## Executes the slotted Echo's validated Action. Data in, physics out —
## nothing here interprets free text, only the schema fields.
##
## Force fields are instantaneous velocity change in m/s (EPSILON_SPEC §8).
##
## S2 opened the catalog from six verbs to 21. Three shapes of Action exist
## now, and the difference is entirely in when they resolve:
##
##   press      resolves inside `activate()` — most of the catalog
##   held       `activate()` starts it, `_physics_process` sustains it, and
##              `release()` or a budget ends it (glide, charge_shot)
##   scheduled  `activate()` starts it and `_physics_process` pays it out
##              over time (burst_fire)
##
## Cooldown is charged on the press for every shape, including the held
## ones, so a hold cannot be used to dodge the cost of the press.

signal cooldown_changed(remaining: float, total: float)
signal shield_changed(shield: float)
## Emitted when a `parry` window catches a hit. The rule engine (S4) is what
## turns this into the `parry_success` event; until then it is feedback.
signal parried
## Rule-engine events (ECHOES §5): a press that genuinely resolved, the
## cooldown's ready edge, and the end of a dash's movement window.
signal action_used
signal action_ready
signal dash_ended

#: Which of the four slots this runtime IS (S7). Set by the player when
#: it collects them; every runtime is otherwise identical, which is the
#: point — a slot is a binding, not a kind of ability.
var slot := "echo_a"
#: Set alongside `slot`. `@onready var player` resolves the same node, but
#: not until the tree is ready, and `_collect_runtimes` runs first.
var player_ref: Player = null

#: The Action component in this runtime's slot, straight from the folded
#: mechanics. Empty is legal and playable — the Static Pulse is never here.
var equipped: Dictionary = {}
var cooldown_remaining := 0.0
var shield_hp := 0.0
var _shield_timer := 0.0

# -- held / scheduled state -------------------------------------------------
var _held := false
var _charge := 0.0
var _gliding := false
var _parry_window := 0.0
var _dash_window := 0.0
var _hover_left := 0.0
#: Wired by main; null in suites that never activate powered verbs.
var pool: ResourcePool = null

#: The held verbs that pay per second through their `powers` link rather
#: than per press. The fold guarantees each HAS that link (S1's
#: `_require_power_links`), so an empty lookup here is drift, not data.
const DRAIN_VERBS := ["beam_sustained", "hover", "block"]
var _burst_left := 0
var _burst_timer := 0.0

# -- per-airtime budgets ----------------------------------------------------
# Spent while airborne, restored on touching the floor. Kept here rather
# than on the player because they belong to the Action, not to the body:
# swapping the slot has to reset them, and landing has to refill them.
var _air_dashes_left := 0
var _extra_jumps_left := 0
var _was_grounded := true

@onready var player: Player = get_parent()

func set_equipped(action: Dictionary) -> void:
	# Traits used to be re-applied here; S5 moved them to the player's
	# StatStack, evaluated every physics frame, because `scaled_by` and
	# statuses change continuously rather than on snapshots.
	if action.get("component_id") == equipped.get("component_id"):
		equipped = action
		return
	equipped = action
	cooldown_remaining = 0.0
	_cancel_held_state()
	_refill_air_budget()
	_refresh_viewmodel_attachment()

## Everything a held or scheduled Action was in the middle of. Called on a
## slot change and on death: a charge still winding up for an Echo you no
## longer have would fire the wrong verb at the wrong strength.
func _cancel_held_state() -> void:
	_held = false
	_charge = 0.0
	_burst_left = 0
	_burst_timer = 0.0
	_parry_window = 0.0
	if _gliding:
		_gliding = false
		player.glide_fall_speed = 0.0
		player.glide_forward_speed = 0.0

func refresh_viewmodel() -> void:
	_refresh_viewmodel_attachment()

func _refresh_viewmodel_attachment() -> void:
	# One viewmodel, four slots: only the highlighted one paints it, or
	# four runtimes would fight over the same mesh every time any of them
	# changed. Which slot you are looking at is the player's business.
	var body: Player = player_ref if player_ref != null else player
	if body == null or body.highlighted_slot != slot:
		return
	var part: MeshInstance3D = null
	if body.viewmodel != null:
		part = body.viewmodel.get_node_or_null("EchoPart") as MeshInstance3D
	if part == null:
		return
	if equipped.is_empty():
		part.visible = false
		return
	part.visible = true
	# The body carries the world this Echo was reinterpreted FROM, in the
	# same colour the campaign board, the reward pedestals and the reveal
	# card use for that game — so an Echo is visibly a piece of somebody
	# else's world that you are holding. The tip keeps the slot, so "which
	# button is this" and "where did it come from" stay separate.
	part.material_override = ThemeMaterials.glow_material(source_color(), 1.2)
	var tip: MeshInstance3D = part.get_node_or_null("EchoTip")
	if tip != null:
		tip.material_override = ThemeMaterials.glow_material(
				SLOT_COLORS.get(equipped.get("slot", "echo_a"),
						Color(0.9, 0.9, 0.9)), 1.8)

#: By slot rather than by v0.7's archetype. The slot is what the player
#: chose and what the key does, which is the more useful thing for a tip to
#: be telling you mid-fight.
const SLOT_COLORS := {"echo_a": Color(1.0, 0.55, 0.3),
		"echo_b": Color(1.0, 0.75, 0.35), "utility": Color(0.5, 0.9, 0.6),
		"mobility": Color(0.5, 0.7, 1.0)}

## The equipped Echo's source world, as a colour. Falls back to a neutral
## white for an Echo with no source game rather than picking a confident
## wrong world out of the hash.
func source_game() -> String:
	return BridgeClient.component_source_game(
			str(equipped.get("component_id", "")))

func source_color() -> Color:
	var game := source_game()
	if game.is_empty():
		return Color(0.85, 0.88, 0.92)
	return ThemeMaterials.color_for_game(game)

## ECHOES §12: the identity package of the world that CREATED this Action.
## After S6 an Action can be the work of several worlds; the package stays
## the creator's, so a thing keeps sounding like where it came from while
## its provenance chain records everyone who touched it.
func source_pitch() -> float:
	return SourceIdentity.sound_pitch(source_game())

func source_particles() -> String:
	return SourceIdentity.particle_style(source_game())

func _primitive() -> Dictionary:
	return equipped.get("primitive", {})

func _primitive_type() -> String:
	return str(_primitive().get("type", ""))

func _refill_air_budget() -> void:
	var p := _primitive()
	_air_dashes_left = int(p.get("uses_per_airtime", 0))
	_extra_jumps_left = int(p.get("extra_jumps", 0))

## Called by the player every physics frame. The grounded EDGE is what
## refills the airtime budgets — polling `is_on_floor()` and refilling every
## frame would work too, but the edge keeps "how many are left" readable
## while standing still, which the HUD wants in S3.
func set_grounded(grounded: bool) -> void:
	if grounded and not _was_grounded:
		_refill_air_budget()
		if _gliding:
			_end_glide()
		if _dash_window > 0.0:
			_dash_window = 0.0
			dash_ended.emit()
	_was_grounded = grounded

func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		cooldown_changed.emit(cooldown_remaining,
				float(equipped.get("cooldown", 1.0)))
		if cooldown_remaining == 0.0:
			action_ready.emit()
	if shield_hp > 0.0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_hp = 0.0
			shield_changed.emit(0.0)

func _physics_process(delta: float) -> void:
	if _parry_window > 0.0:
		_parry_window = maxf(0.0, _parry_window - delta)

	if _dash_window > 0.0:
		_dash_window = maxf(0.0, _dash_window - delta)
		if _dash_window == 0.0:
			dash_ended.emit()

	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			var p := _primitive()
			_burst_timer = float(p.get("interval", 0.1))
			_burst_left -= 1
			_hitscan({
				"damage": p.get("damage", 1.0),
				"pellets": 1,
				"spread_degrees": p.get("spread_degrees", 0.0),
				"range": p.get("range", 30.0),
			})
			player.kick_viewmodel(0.06)

	if _held and _primitive_type() == "charge_shot":
		_charge = minf(_charge + delta,
				float(_primitive().get("charge_time", 1.0)))

	if _held:
		match _primitive_type():
			"beam_sustained":
				_beam_tick(delta)
			"hover":
				_hover_tick(delta)
			"block":
				if not _drain(delta):
					_held = false

	if _gliding:
		# A glide that outlives the ground is just flight. Landing ends it
		# through set_grounded; this ends it when the key comes up.
		if not _held:
			_end_glide()

## The slot's key, pressed. An empty slot does nothing, by design: the
## Static Pulse is on its own button and is never what is missing here.
func activate() -> void:
	if equipped.is_empty():
		return
	if cooldown_remaining > 0.0:
		return
	# Conditional verbs check their condition BEFORE the cooldown is
	# charged. Spending a dash's cooldown on a press that could never have
	# resolved — an air dash on the ground, a slam with the floor under you
	# — reads as the ability being broken.
	if not _conditions_met():
		return
	# Links, in the same pre-cooldown position: a `gates` threshold not
	# met, or a `powers` press cost the bar cannot pay, is a press that
	# could never have resolved.
	if not _gates_open():
		return
	if not _pay_powers_cost():
		return

	cooldown_remaining = float(equipped.get("cooldown", 1.0))
	cooldown_changed.emit(cooldown_remaining, cooldown_remaining)
	player.kick_viewmodel(0.12)
	_flash_for(_primitive_type())

	var primitive := _primitive()
	var modifiers: Array = equipped.get("modifiers", [])
	var damaged: Array[Node] = []
	_held = true
	match _primitive_type():
		# -- close combat
		"melee_swing": damaged = _melee_arc(primitive)
		"melee_thrust": damaged = _melee_thrust(primitive)
		"slam_ground": _slam_ground(primitive)
		# -- ranged
		"hitscan_damage": damaged = _hitscan(primitive)
		"projectile_damage": _projectile(primitive, modifiers)
		"arc_lob": _arc_lob(primitive, modifiers)
		"burst_fire": _begin_burst(primitive)
		"charge_shot": _charge = 0.0        # resolves on release
		# -- movement
		"dash": _dash(primitive)
		"air_dash": _air_dash(primitive)
		"double_jump": _double_jump(primitive)
		"wall_kick": _wall_kick(primitive)
		"glide": _begin_glide(primitive)
		"blink": _blink(primitive)
		"grapple_to_surface": _grapple(primitive)
		"grapple_pull_target": damaged = _grapple_pull_target(primitive)
		"grapple_swing": _grapple_swing(primitive)
		# -- defensive
		"shield": _shield(primitive)
		"parry": _begin_parry(primitive)
		"heal_self": player.heal(float(primitive["amount"]))
		"block": pass               # held: the absorb path reads the hold
		"cleanse": player.statuses.cleanse(int(primitive.get("count", 1)))
		# -- powered / linked (S5)
		"beam_sustained": pass      # resolves per frame while held
		"hover": _begin_hover(primitive)
		"restore_resource": _restore_resource(primitive)
		# -- utility
		"place_marker": _place_marker(primitive)
		"scan_mark": _scan_mark(primitive)

	_apply_modifiers(modifiers, damaged)
	if _primitive_type() in ["dash", "air_dash"]:
		# The impulse decays over roughly this window under ground
		# friction; landing ends it early via set_grounded.
		_dash_window = 0.35
	_apply_fills()
	action_used.emit()

## The slot's key, released. Only the held verbs care.
func release() -> void:
	_held = false
	if equipped.is_empty():
		return
	match _primitive_type():
		"charge_shot": _fire_charge_shot(_primitive())
		"glide": _end_glide()
		"hover": _end_hover()

# --- S5: links, and the verbs they power ----------------------------------

func _link_edges(kind: String) -> Array:
	var out: Array = []
	for link: Dictionary in BridgeClient.mechanics().get("links", []):
		if str(link.get("link", "")) == kind:
			out.append(link)
	return out

## The `powers` link whose target is the equipped Action. The fold already
## resolved merge aliases, so ids here are canonical.
func _powers_link() -> Dictionary:
	var my_id := str(equipped.get("component_id", ""))
	for link: Dictionary in _link_edges("powers"):
		if str(link.get("target", "")) == my_id:
			return link
	return {}

## `gates(resource → action)`: unavailable below the threshold. Strength
## up to 1 reads as a fraction; above 1 as absolute units, so "needs 20
## charge" and "needs a third of the bar" both say what they mean.
func _gates_open() -> bool:
	if pool == null:
		return true
	var my_id := str(equipped.get("component_id", ""))
	for link: Dictionary in _link_edges("gates"):
		if str(link.get("target", "")) != my_id:
			continue
		var source := str(link.get("source", ""))
		var strength := float(link.get("strength", 1.0))
		if strength <= 1.0:
			if pool.fraction_of(source) < strength:
				return false
		elif pool.value_of(source) < strength:
			return false
	return true

## `powers` on a press verb: pay strength units on the press, all or
## nothing. Drain verbs pay per second instead — their press is free and
## their empty bar ends the hold.
func _pay_powers_cost() -> bool:
	var link := _powers_link()
	if link.is_empty() or pool == null:
		return true
	var source := str(link.get("source", ""))
	if _primitive_type() in DRAIN_VERBS:
		return pool.value_of(source) > 0.0
	return pool.spend(source, float(link.get("strength", 1.0)))

## `fills(action → resource)`: a successful use adds strength. The
## restore_resource verb fills by its OWN amount through the same link —
## the link says where, the primitive says how much — so it is skipped
## here rather than counted twice.
func _apply_fills() -> void:
	if pool == null or _primitive_type() == "restore_resource":
		return
	var my_id := str(equipped.get("component_id", ""))
	for link: Dictionary in _link_edges("fills"):
		if str(link.get("source", "")) == my_id:
			pool.refill(str(link.get("target", "")),
					float(link.get("strength", 1.0)))

func _restore_resource(primitive: Dictionary) -> void:
	if pool == null:
		return
	var my_id := str(equipped.get("component_id", ""))
	for link: Dictionary in _link_edges("fills"):
		if str(link.get("source", "")) == my_id:
			pool.refill(str(link.get("target", "")),
					float(primitive.get("amount", 0.0)))

## Drain the powering resource; false means the bar ran dry and the hold
## must end. The spend path keeps regen_delay honest per tick.
func _drain(delta: float) -> bool:
	var link := _powers_link()
	if link.is_empty() or pool == null:
		return false
	var rate := float(_primitive().get("drain_per_second", 0.0))
	return pool.spend(str(link.get("source", "")), rate * delta)

func _beam_tick(delta: float) -> void:
	if not _drain(delta):
		_held = false
		return
	var primitive := _primitive()
	var hit := player.camera_ray(float(primitive.get("range", 20.0)))
	if not hit.is_empty():
		var target: Variant = hit["collider"]
		if is_instance_valid(target) and target.is_in_group("enemies"):
			player.report_hit(target.take_damage(
					float(primitive.get("damage_per_second", 0.0)) * delta
					* player.damage_dealt_mult,
					-player.camera.global_transform.basis.z, 0.0))
	player.muzzle_flash(1.1, source_color())

func _begin_hover(primitive: Dictionary) -> void:
	_hover_left = float(primitive.get("max_duration", 1.0))
	player.hover_gravity_scale = float(
			primitive.get("gravity_multiplier", 0.5))

func _end_hover() -> void:
	_hover_left = 0.0
	player.hover_gravity_scale = 1.0

func _hover_tick(delta: float) -> void:
	_hover_left -= delta
	if _hover_left <= 0.0 or not _drain(delta):
		_end_hover()
		_held = false

## Incoming damage removed while a `block` is genuinely held. The drain
## tick already ended the hold if the bar ran dry, so held is the truth.
func block_reduction() -> float:
	if _held and _primitive_type() == "block":
		return clampf(float(_primitive().get("reduction", 0.0)), 0.0, 0.9)
	return 0.0

func _scan_mark(primitive: Dictionary) -> void:
	var reach := float(primitive.get("range", 20.0))
	var duration := float(primitive.get("duration", 5.0))
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node3D and not node.is_queued_for_deletion() \
				and (node as Node3D).global_position.distance_to(
						player.global_position) <= reach:
			node.statuses.apply("marked", duration, 1.0)

## Whether a conditional verb could resolve right now. Kept in one place so
## `activate()` reads as a list of verbs rather than a thicket of guards.
func _conditions_met() -> bool:
	match _primitive_type():
		"slam_ground", "air_dash", "double_jump":
			if player.is_on_floor():
				return false
			if _primitive_type() == "air_dash":
				return _air_dashes_left > 0
			if _primitive_type() == "double_jump":
				return _extra_jumps_left > 0
			return true
		"wall_kick":
			return not player.is_on_floor() and _wall_normal() != Vector3.ZERO
		"glide":
			return not player.is_on_floor()
	return true

func _flash_for(primitive_type: String) -> void:
	# Brighter than Static Pulse — the Echo is the loud option. Brightness
	# still says what kind of thing just fired; the hue says which world it
	# came out of.
	var flash := source_color().lightened(0.25)
	if primitive_type in ["hitscan_damage", "projectile_damage", "arc_lob",
			"burst_fire", "charge_shot"]:
		player.muzzle_flash(3.2, flash)
	elif primitive_type in ["melee_swing", "melee_thrust", "slam_ground"]:
		player.muzzle_flash(2.6, flash)
	elif primitive_type in ["dash", "air_dash", "double_jump", "wall_kick",
			"glide", "blink", "grapple_to_surface", "grapple_pull_target",
			"grapple_swing"]:
		player.muzzle_flash(2.0, flash)
	elif primitive_type in ["heal_self", "shield", "parry"]:
		player.muzzle_flash(2.4, flash)
	else:
		player.muzzle_flash(1.6, flash)

func _apply_modifiers(modifiers: Array, damaged: Array[Node]) -> void:
	for modifier: Dictionary in modifiers:
		match modifier.get("type", ""):
			"recoil_self":
				# Opposite aim, same activation: the Conference Call moment.
				var aim := -player.camera.global_transform.basis.z
				player.velocity += -aim * float(modifier["force"])
			"knockback_target":
				for enemy in damaged:
					if is_instance_valid(enemy) \
							and enemy.has_method("apply_knockback"):
						var away: Vector3 = (enemy.global_position
								- player.global_position).normalized()
						enemy.apply_knockback(away * float(modifier["force"]))
			"apply_status_on_hit":
				for enemy in damaged:
					if is_instance_valid(enemy) and "statuses" in enemy:
						enemy.statuses.apply(
								str(modifier.get("status", "")),
								float(modifier.get("duration", 1.0)),
								float(modifier.get("magnitude", 0.5)))

# ---------------------------------------------------------------------------
# Close combat
# ---------------------------------------------------------------------------

## Everything inside `reach` and within `arc_degrees` of where you are
## looking. Angle is measured on the flat: a swing should connect with the
## enemy in front of you whether or not you happen to be looking at its feet.
func _melee_arc(primitive: Dictionary) -> Array[Node]:
	var damaged: Array[Node] = []
	var reach := float(primitive["reach"])
	var damage := float(primitive["damage"])
	var half_arc := deg_to_rad(float(primitive["arc_degrees"])) / 2.0
	var forward := -player.camera.global_transform.basis.z
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var killed := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy := enemy.global_position - player.global_position
		if to_enemy.length() > reach:
			continue
		var flat := Vector3(to_enemy.x, 0.0, to_enemy.z)
		if flat.length() < 0.001:
			flat = flat_forward
		if flat_forward.angle_to(flat.normalized()) > half_arc:
			continue
		if enemy.take_damage(damage, to_enemy.normalized(), 0.0):
			killed = true
		damaged.append(enemy)
	_swing_arc_effect(reach, half_arc)
	if not damaged.is_empty():
		player.report_hit(killed)
	return damaged

## Narrow and long: a ray, not an arc. One target, more damage.
func _melee_thrust(primitive: Dictionary) -> Array[Node]:
	var damaged: Array[Node] = []
	var reach := float(primitive["reach"])
	var hit := player.camera_ray(reach)
	var forward := -player.camera.global_transform.basis.z
	Tracer.spawn(get_tree().current_scene,
			player.camera.global_position + forward * 0.4,
			player.camera.global_position + forward * reach,
			source_color(), 0.09, source_particles())
	if hit.is_empty():
		return damaged
	var target: Variant = hit["collider"]
	if is_instance_valid(target) and target is Node \
			and (target as Node).is_in_group("enemies"):
		var enemy := target as Enemy
		var killed := enemy.take_damage(float(primitive["damage"]), forward, 0.0)
		damaged.append(enemy)
		player.report_hit(killed)
	return damaged

## Drives you down, then detonates on contact. Airborne-only, so it is a
## commitment: you give up the rest of your jump to land it.
func _slam_ground(primitive: Dictionary) -> void:
	player.velocity.y = -float(primitive["descent_force"])
	player.pending_slam = {
		"damage": float(primitive["damage"]),
		"radius": float(primitive["radius"]),
		"tint": source_color(),
	}

func _swing_arc_effect(reach: float, half_arc: float) -> void:
	# Three spokes rather than a mesh: the sweep is legible, and it costs
	# nothing that has to be cleaned up on zone change.
	var basis := player.camera.global_transform.basis
	var origin := player.camera.global_position - basis.z * 0.2
	for step: float in [-half_arc, 0.0, half_arc]:
		var dir := (basis * Basis.from_euler(Vector3(0, step, 0)).z) * -1.0
		Tracer.spawn(get_tree().current_scene, origin,
				origin + dir * reach, source_color(), 0.08, source_particles())

# ---------------------------------------------------------------------------
# Ranged
# ---------------------------------------------------------------------------

func _hitscan(primitive: Dictionary) -> Array[Node]:
	var damaged: Array[Node] = []
	var pellets := int(primitive.get("pellets", 1))
	var spread := deg_to_rad(float(primitive.get("spread_degrees", 0.0)))
	var damage := float(primitive["damage"])
	var reach := float(primitive["range"])
	var basis := player.camera.global_transform.basis
	var rng := RandomNumberGenerator.new()
	var killed := false
	for i in pellets:
		var dir := -basis.z
		if spread > 0.0:
			var yaw := rng.randf_range(-spread / 2.0, spread / 2.0)
			var pitch := rng.randf_range(-spread / 2.0, spread / 2.0)
			dir = (basis * Basis.from_euler(Vector3(pitch, yaw, 0)).z * -1.0)
		var hit := player.camera_ray(reach, dir)
		var to: Vector3 = hit.get("position",
				player.camera.global_position + dir * reach)
		Tracer.spawn(get_tree().current_scene,
				player.camera.global_position
				+ basis * Vector3(0.18, -0.14, -0.3),
				to, source_color(), 0.08, source_particles())
		if not hit.is_empty():
			var target: Variant = hit["collider"]
			if is_instance_valid(target) and target.is_in_group("enemies"):
				var enemy := target as Enemy
				if enemy.take_damage(damage, dir, 0.0):
					killed = true
				if target not in damaged:
					damaged.append(target)
	# One confirmation per trigger pull, not one per pellet: a spread Echo
	# would otherwise stack three kill tones on a single shot.
	if not damaged.is_empty():
		player.report_hit(killed)
	return damaged

func _projectile(primitive: Dictionary, modifiers: Array) -> void:
	var projectile := EchoProjectile.new()
	projectile.damage = float(primitive["damage"])
	projectile.speed = float(primitive["speed"])
	projectile.lifetime = float(primitive["lifetime"])
	projectile.gravity_scale = float(primitive.get("gravity_scale", 0.0))
	projectile.bounces = int(primitive.get("bounces", 0))
	_launch(projectile, modifiers, -player.camera.global_transform.basis.z)

## A lob is a projectile with a fuse, a blast radius and full gravity. It
## aims UP the launch axis rather than straight down the crosshair, so a
## flat press still arcs instead of falling at your feet.
func _arc_lob(primitive: Dictionary, modifiers: Array) -> void:
	var projectile := EchoProjectile.new()
	projectile.damage = float(primitive["damage"])
	projectile.speed = float(primitive["launch_force"])
	projectile.blast_radius = float(primitive["radius"])
	projectile.fuse = float(primitive["fuse"])
	projectile.lifetime = float(primitive["fuse"]) + 2.0
	projectile.gravity_scale = 1.0
	var aim := -player.camera.global_transform.basis.z
	_launch(projectile, modifiers, (aim + Vector3.UP * 0.35).normalized())

func _launch(projectile: EchoProjectile, modifiers: Array,
		direction: Vector3) -> void:
	for modifier: Dictionary in modifiers:
		if modifier.get("type") == "knockback_target":
			projectile.knockback = float(modifier["force"])
	# The projectile outlives this call, so it confirms its own hit.
	projectile.shooter = player
	# Before add_child: _ready builds the visual, and a tint assigned after
	# it has run paints nothing.
	projectile.tint = source_color()
	projectile.direction = direction
	get_tree().current_scene.add_child(projectile)
	var camera := player.camera
	projectile.global_position = camera.global_position + direction * 0.6

func _begin_burst(primitive: Dictionary) -> void:
	# The first shot goes out on the press; the rest are scheduled. A burst
	# whose first round waits for the interval feels like input lag.
	_burst_left = int(primitive["shots"]) - 1
	_burst_timer = float(primitive["interval"])
	_hitscan({
		"damage": primitive["damage"],
		"pellets": 1,
		"spread_degrees": primitive.get("spread_degrees", 0.0),
		"range": primitive["range"],
	})

## Released before the charge completes, it fires weaker — it never fizzles.
## A charge weapon that punishes an early release with nothing at all reads
## as a dropped input.
func _fire_charge_shot(primitive: Dictionary) -> void:
	var charge_time := float(primitive["charge_time"])
	var ratio := clampf(_charge / maxf(charge_time, 0.001), 0.0, 1.0)
	var min_damage := float(primitive["min_damage"])
	var damage := min_damage + (float(primitive["max_damage"]) - min_damage) * ratio
	_charge = 0.0
	var projectile := EchoProjectile.new()
	projectile.damage = damage
	projectile.speed = float(primitive["speed"]) * (0.6 + 0.4 * ratio)
	projectile.lifetime = 4.0
	_launch(projectile, equipped.get("modifiers", []),
			-player.camera.global_transform.basis.z)
	player.muzzle_flash(2.0 + 2.0 * ratio, source_color().lightened(0.25))

## How far along the current charge is, 0-1. The HUD draws this; a charge
## you cannot see the state of is a charge you cannot time.
func charge_ratio() -> float:
	if not _held or _primitive_type() != "charge_shot":
		return 0.0
	return clampf(_charge / maxf(float(_primitive().get("charge_time", 1.0)),
			0.001), 0.0, 1.0)

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _dash(primitive: Dictionary) -> void:
	var dir := -player.camera.global_transform.basis.z
	player.velocity += dir * float(primitive["force"])

func _air_dash(primitive: Dictionary) -> void:
	_air_dashes_left -= 1
	var dir := -player.camera.global_transform.basis.z
	# Replaces horizontal velocity instead of adding to it, so repeated air
	# dashes cannot compound into a speed no chamber was measured against.
	# The vertical component is zeroed for the same reason a dash is not a
	# flight: it buys you distance, not altitude.
	var force := float(primitive["force"])
	player.velocity = Vector3(dir.x, 0.0, dir.z).normalized() * force
	player.velocity.y = maxf(0.0, player.velocity.y)

func _double_jump(primitive: Dictionary) -> void:
	_extra_jumps_left -= 1
	player.velocity.y = float(primitive["force"])

## Off the wall you are touching, mostly outward, partly up. Uses the
## surface normal so it works on the rotated corridors as well as the
## axis-aligned ones.
func _wall_kick(primitive: Dictionary) -> void:
	var normal := _wall_normal()
	if normal == Vector3.ZERO:
		return
	var force := float(primitive["force"])
	var outward := float(primitive["outward_fraction"])
	player.velocity = normal * force * outward
	player.velocity.y = force * (1.0 - outward)

## The normal of a wall within arm's reach, or ZERO. Probes the four
## horizontal directions rather than only where the camera points, because
## a wall kick is about what you are touching, not what you are looking at.
func _wall_normal() -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3.UP * 0.9
	for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT,
			Vector3.RIGHT]:
		var rotated := player.global_transform.basis * dir
		var query := PhysicsRayQueryParameters3D.create(
				origin, origin + rotated * (float(Constants.PLAYER_RADIUS) + 0.35))
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Variant = hit["collider"]
		if not (is_instance_valid(collider) and collider is StaticBody3D):
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		# Floors and ceilings are not walls; a "wall kick" off the ground
		# would just be a second jump with extra steps.
		if absf(normal.y) > 0.6:
			continue
		return normal.normalized()
	return Vector3.ZERO

func _begin_glide(primitive: Dictionary) -> void:
	_gliding = true
	player.glide_fall_speed = float(primitive["fall_speed"])
	player.glide_forward_speed = float(primitive["forward_speed"])

func _end_glide() -> void:
	if not _gliding:
		return
	_gliding = false
	player.glide_fall_speed = 0.0
	player.glide_forward_speed = 0.0

## Instant translation along a validated ray to a surface hit — never free
## space. This is invariant I14, and it is the one verb in the catalog that
## can put the player outside the world if it is written casually.
##
## Four things must hold, and each is checked here rather than assumed:
##   1. the ray must HIT something (no hit, no blink — the press is refunded)
##   2. the landing point steps back along the ray by the clearance radius,
##      so you arrive beside the surface rather than inside it
##   3. the landing point is clearance-tested with a real shape query
##   4. the landing point is inside the Zone's bounds
func _blink(primitive: Dictionary) -> void:
	var distance := float(primitive["range"])
	var clearance := float(primitive.get("clearance", Constants.PLAYER_RADIUS))
	var from := player.camera.global_position
	var dir := -player.camera.global_transform.basis.z
	var hit := player.camera_ray(distance, dir)
	if hit.is_empty():
		_refund_press()
		return
	var surface: Vector3 = hit["position"]
	# Step back off the surface, and never past where you started.
	var travelled := minf(from.distance_to(surface) - clearance, distance)
	if travelled <= clearance:
		_refund_press()
		return
	var landing := from + dir * travelled
	# The camera sits above the body's origin, so aim the body at the feet.
	landing.y -= player.camera.position.y

	# ...but dropping a full eye-height straight down is how you end up
	# UNDER the floor you were aiming at. Looking down at the ground three
	# metres below, the ray stops on the floor, the step-back leaves the
	# candidate just above it, and subtracting the eye height then buries
	# the body a body-length beneath the slab -- through the level and into
	# the void, which is exactly what I14 exists to forbid. The blink sweep
	# caught this on 350 attempts across every builder.
	#
	# So when the surface is one you could stand on, stand on it: the feet
	# never go below the point the ray actually hit. A wall or a ceiling
	# keeps the ray-derived point and you fall from it, which is a jump,
	# not a hole in the world.
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if normal.y > 0.5:
		landing.y = maxf(landing.y, surface.y + 0.02)

	if not _landing_is_clear(landing, clearance):
		_refund_press()
		return
	if not _inside_zone_bounds(landing):
		_refund_press()
		return
	var before := player.global_position
	player.global_position = landing
	# Blink is a translation, not a launch: carrying the old velocity into
	# the destination would fling you off the ledge you just arrived on.
	player.velocity = Vector3.ZERO
	Tracer.spawn(get_tree().current_scene, before + Vector3.UP * 0.9,
			landing + Vector3.UP * 0.9, source_color(), 0.16, source_particles())

## A press that could not resolve gives the cooldown back. Charging for a
## blink that refused to happen is indistinguishable from a broken ability.
func _refund_press() -> void:
	cooldown_remaining = 0.0
	cooldown_changed.emit(0.0, float(equipped.get("cooldown", 1.0)))

## Is there room for the PLAYER here? Asked with the player's own capsule,
## because that is the actual question.
##
## This started as a small sphere near the feet, which is a different and
## much weaker question: it cleared a landing whose ankles were in open air
## while the rest of the body was inside a wall or a ceiling. The blink
## sweep failed on 100 attempts that way after the floor bug was fixed.
## Probing with a ray would be weaker still -- a ray threads gaps the body
## does not fit through.
##
## Shrunk slightly so that standing ON a surface is not read as standing IN
## it: a capsule at exactly body height has its cap in the floor plane it
## is resting on, and every legal landing would report a collision.
func _landing_is_clear(landing: Vector3, clearance: float) -> bool:
	var space := player.get_world_3d().direct_space_state
	var height := float(Constants.PLAYER_HEIGHT)
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(clearance, float(Constants.PLAYER_RADIUS)) * 0.92
	shape.height = height * 0.92
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY,
			landing + Vector3.UP * (height / 2.0))
	return space.intersect_shape(query, 1).is_empty()

## Inside the Zone the bridge generated, with a margin. Every builder places
## its geometry inside these bounds, so a landing outside them is outside
## the level whether or not a wall happens to be there.
func _inside_zone_bounds(landing: Vector3) -> bool:
	# Walk up from the player rather than asking `current_scene`: the Zone
	# controller is a child of Main, so the current scene is Main and would
	# never answer. The player is built by whichever controller owns the
	# space, so its ancestors are the right thing to ask.
	var bounds: Variant = null
	var node: Node = player
	while node != null:
		if node.has_method("world_bounds"):
			bounds = node.world_bounds()
			break
		node = node.get_parent()
	if bounds == null or not (bounds is AABB):
		# No Zone to ask (the Hub, a test scene). The floor-kill plane is
		# still a real bound, and it is the one that matters.
		return landing.y > float(Constants.FALL_KILL_Y)
	var box: AABB = bounds
	return box.grow(0.5).has_point(landing)

func _grapple(primitive: Dictionary) -> void:
	var hit := player.camera_ray(float(primitive["range"]))
	if hit.is_empty():
		return
	var target: Variant = hit["collider"]
	if is_instance_valid(target) and target is StaticBody3D:
		var pull: Vector3 = (hit["position"]
				- player.global_position).normalized()
		player.velocity = pull * float(primitive["pull_force"])
		Tracer.spawn(get_tree().current_scene,
				player.global_position + Vector3.UP * 1.2, hit["position"],
				source_color(), 0.15, source_particles())

## Reels a LIGHT enemy in. `max_target_hp` is what stops it being a way to
## drag a brute off its perch and into a corner.
func _grapple_pull_target(primitive: Dictionary) -> Array[Node]:
	var damaged: Array[Node] = []
	var hit := player.camera_ray(float(primitive["range"]))
	if hit.is_empty():
		return damaged
	var target: Variant = hit["collider"]
	if not (is_instance_valid(target) and target is Node
			and (target as Node).is_in_group("enemies")):
		return damaged
	var enemy := target as Enemy
	if enemy.max_hp > float(primitive["max_target_hp"]):
		return damaged
	var toward := (player.global_position - enemy.global_position)
	if toward.length() < 0.001:
		return damaged
	enemy.apply_knockback(toward.normalized() * float(primitive["pull_force"]))
	damaged.append(enemy)
	Tracer.spawn(get_tree().current_scene,
			player.global_position + Vector3.UP * 1.2,
			enemy.global_position, source_color(), 0.15, source_particles())
	return damaged

## A tether you arc from. Held: while the key is down and the anchor holds,
## you are pulled toward it and keep your tangential speed, which is what
## makes it a swing rather than a second grapple.
func _grapple_swing(primitive: Dictionary) -> void:
	var hit := player.camera_ray(float(primitive["range"]))
	if hit.is_empty():
		_refund_press()
		return
	var target: Variant = hit["collider"]
	if not (is_instance_valid(target) and target is StaticBody3D):
		_refund_press()
		return
	player.begin_swing(hit["position"], float(primitive["tether_force"]),
			float(primitive["max_duration"]))
	Tracer.spawn(get_tree().current_scene,
			player.global_position + Vector3.UP * 1.2, hit["position"],
			source_color(), 0.2, source_particles())

# ---------------------------------------------------------------------------
# Defensive
# ---------------------------------------------------------------------------

func _shield(primitive: Dictionary) -> void:
	shield_hp = float(primitive["amount"])
	_shield_timer = float(primitive["duration"])
	shield_changed.emit(shield_hp)

## Rule-effect entry points (ECHOES §5, applied by RuleRuntime). Shields
## from rules follow the same don't-stack reading as the shield verb: the
## stronger value wins, timers never add.
func grant_shield(amount: float, duration: float) -> void:
	shield_hp = maxf(shield_hp, amount)
	_shield_timer = maxf(_shield_timer, duration)
	shield_changed.emit(shield_hp)

func reset_cooldown() -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = 0.0
		cooldown_changed.emit(0.0, float(equipped.get("cooldown", 1.0)))
		action_ready.emit()

## A rule's projectile: no modifiers, no slot involvement — a plain bolt
## along the given rule direction, damage from the effect's amount.
func fire_rule_projectile(damage: float, direction_kind: String) -> void:
	if player == null or player.camera == null:
		return
	var projectile := EchoProjectile.new()
	projectile.damage = maxf(1.0, damage)
	projectile.speed = 28.0
	var direction: Vector3 = -player.camera.global_transform.basis.z
	match direction_kind:
		"up":
			direction = Vector3.UP
		"forward", "aim", "":
			pass
		"backward":
			direction = -direction
		"velocity":
			var velocity: Vector3 = player.velocity
			if velocity.length() > 0.5:
				direction = velocity.normalized()
	_launch(projectile, [], direction)

func _begin_parry(primitive: Dictionary) -> void:
	_parry_window = float(primitive["window"])

func absorb_with_shield(damage: float) -> float:
	# Parry first: it is the timed, skilful one, and letting a shield soak a
	# hit the player actually parried would waste the read.
	if _parry_window > 0.0:
		_parry_window = 0.0
		parried.emit()
		player.muzzle_flash(3.0, source_color().lightened(0.4))
		return 0.0
	# A held block shaves its fraction next: cheaper than a shield point
	# for point, and it costs drain rather than a timed read.
	damage *= 1.0 - block_reduction()
	if shield_hp <= 0.0:
		return damage
	var absorbed := minf(shield_hp, damage)
	shield_hp -= absorbed
	shield_changed.emit(shield_hp)
	return damage - absorbed

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Cosmetic only, and deliberately so: it marks a spot you chose, and marking
## a spot can never be what a mandatory Check is behind.
func _place_marker(primitive: Dictionary) -> void:
	var hit := player.camera_ray(40.0)
	var at: Vector3 = hit.get("position",
			player.global_position + Vector3.UP * 0.2)
	EchoMarker.spawn(get_tree().current_scene, at, source_color(),
			float(primitive["duration"]))
