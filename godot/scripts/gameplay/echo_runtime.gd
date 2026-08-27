class_name EchoRuntime
extends Node
## Executes the equipped Echo's validated effects. Data in, physics out —
## nothing here interprets free text, only the schema fields.
##
## Force fields are instantaneous velocity change in m/s (EPSILON_SPEC §8).

signal cooldown_changed(remaining: float, total: float)
signal shield_changed(shield: float)

#: The Action component in this runtime's slot, straight from the folded
#: mechanics. Empty is legal and playable — the Static Pulse is never here.
var equipped: Dictionary = {}
var cooldown_remaining := 0.0
var shield_hp := 0.0
var _shield_timer := 0.0

@onready var player: Player = get_parent()

func set_equipped(action: Dictionary) -> void:
	# Traits refresh on EVERY snapshot, not only when the slot changes: a
	# newly granted trait is owned the moment its Check confirms, and
	# gating that on a slot change would leave it inert until the player
	# happened to switch Echoes.
	apply_owned_traits()
	if action.get("component_id") == equipped.get("component_id"):
		equipped = action
		return
	equipped = action
	cooldown_remaining = 0.0
	_refresh_viewmodel_attachment()

func _refresh_viewmodel_attachment() -> void:
	var part: MeshInstance3D = null
	if player != null and player.viewmodel != null:
		part = player.viewmodel.get_node_or_null("EchoPart") as MeshInstance3D
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
func source_color() -> Color:
	var game := BridgeClient.component_source_game(
			str(equipped.get("component_id", "")))
	if game.is_empty():
		return Color(0.85, 0.88, 0.92)
	return ThemeMaterials.color_for_game(game)

## Owned traits, folded onto the player.
##
## v0.7 applied one passive, the equipped one. A trait is not equipment: it
## is true once owned, which is the whole reason a Check can matter without
## occupying a slot. So this reads what the campaign OWNS, not what is in a
## slot, and stacks it.
##
## Stacking is why the clamp is here and not only in the schema. Each trait
## is individually floored at base — a gravity trait may only lighten, a
## speed trait may only quicken — but three of them multiply, and
## `max_safe_gap` was derived from these two constants, not from an
## unbounded product. Clamping to them is what keeps every generated jump
## valid without recomputing a single one.
func apply_owned_traits() -> void:
	var gravity := 1.0
	var speed := 1.0
	for entry: Dictionary in BridgeClient.owned_components("trait"):
		var trait_component: Dictionary = entry.get("component", {})
		var multiplier := float(trait_component.get("multiplier", 1.0))
		match str(trait_component.get("stat", "")):
			"gravity":
				gravity *= multiplier
			"move_speed":
				speed *= multiplier
	player.gravity_mult = clampf(gravity,
			float(Constants.GRAVITY_MULT_MIN), float(Constants.GRAVITY_MULT_MAX))
	player.speed_mult = clampf(speed,
			float(Constants.SPEED_MULT_MIN), float(Constants.SPEED_MULT_MAX))

func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		cooldown_changed.emit(cooldown_remaining,
				float(equipped.get("cooldown", 1.0)))
	if shield_hp > 0.0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_hp = 0.0
			shield_changed.emit(0.0)

## The slot's key. An empty slot does nothing, by design: the Static Pulse
## is on its own button and is never what is missing here.
func activate() -> void:
	if equipped.is_empty():
		return
	if cooldown_remaining > 0.0:
		return
	cooldown_remaining = float(equipped.get("cooldown", 1.0))
	cooldown_changed.emit(cooldown_remaining, cooldown_remaining)
	player.kick_viewmodel(0.12)
	# Brighter than Static Pulse — the Echo is the loud option. Brightness
	# still says what kind of thing just fired; the hue says which world it
	# came out of.
	var initiator_type := str(equipped.get("primitive", {}).get("type", ""))
	var flash := source_color().lightened(0.25)
	if initiator_type in ["hitscan_damage", "projectile_damage"]:
		player.muzzle_flash(3.2, flash)
	elif initiator_type in ["dash", "grapple_to_surface"]:
		player.muzzle_flash(2.0, flash)
	elif initiator_type in ["heal_self", "shield"]:
		player.muzzle_flash(2.4, flash)

	var initiator: Dictionary = equipped.get("primitive", {})
	var modifiers: Array = equipped.get("modifiers", [])
	var damaged: Array[Node] = []
	match initiator.get("type", ""):
		"hitscan_damage": damaged = _hitscan(initiator)
		"projectile_damage": _projectile(initiator, modifiers)
		"dash": _dash(initiator)
		"grapple_to_surface": _grapple(initiator)
		"heal_self": player.heal(float(initiator["amount"]))
		"shield": _shield(initiator)

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

func _hitscan(initiator: Dictionary) -> Array[Node]:
	var damaged: Array[Node] = []
	var pellets := int(initiator.get("pellets", 1))
	var spread := deg_to_rad(float(initiator.get("spread_degrees", 0.0)))
	var damage := float(initiator["damage"])
	var reach := float(initiator["range"])
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
				to, source_color(), 0.08)
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

func _projectile(initiator: Dictionary, modifiers: Array) -> void:
	var projectile := EchoProjectile.new()
	projectile.damage = float(initiator["damage"])
	projectile.speed = float(initiator["speed"])
	projectile.lifetime = float(initiator["lifetime"])
	for modifier: Dictionary in modifiers:
		if modifier.get("type") == "knockback_target":
			projectile.knockback = float(modifier["force"])
	# The projectile outlives this call, so it confirms its own hit.
	projectile.shooter = player
	# Before add_child: _ready builds the visual, and a tint assigned after
	# it has run paints nothing.
	projectile.tint = source_color()
	get_tree().current_scene.add_child(projectile)
	var camera := player.camera
	projectile.global_position = camera.global_position \
			- camera.global_transform.basis.z * 0.6
	projectile.direction = -camera.global_transform.basis.z

func _dash(initiator: Dictionary) -> void:
	var dir := -player.camera.global_transform.basis.z
	player.velocity += dir * float(initiator["force"])

func _grapple(initiator: Dictionary) -> void:
	var hit := player.camera_ray(float(initiator["range"]))
	if hit.is_empty():
		return
	var target: Variant = hit["collider"]
	if is_instance_valid(target) and target is StaticBody3D:
		var pull: Vector3 = (hit["position"]
				- player.global_position).normalized()
		player.velocity = pull * float(initiator["pull_force"])
		Tracer.spawn(get_tree().current_scene,
				player.global_position + Vector3.UP * 1.2, hit["position"],
				source_color(), 0.15)

func _shield(initiator: Dictionary) -> void:
	shield_hp = float(initiator["amount"])
	_shield_timer = float(initiator["duration"])
	shield_changed.emit(shield_hp)

func absorb_with_shield(damage: float) -> float:
	if shield_hp <= 0.0:
		return damage
	var absorbed := minf(shield_hp, damage)
	shield_hp -= absorbed
	shield_changed.emit(shield_hp)
	return damage - absorbed
