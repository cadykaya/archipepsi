class_name Player
extends CharacterBody3D
## First-person controller. Every number comes from Constants (generated
## from schemas/constants.py) — do not invent movement values here.
##
## LMB is ALWAYS Static Pulse, never rebound. The four Echo slots take
## RMB / MMB+F / Shift / C (ECHOES §9), one runtime each.

signal hp_changed(hp: float, shield: float)
signal died
signal interact_prompt_changed(text: String)
signal fired_pulse
## One of the player's own attacks connected. `killed` marks the shot that
## finished the target: the crosshair and the mixer each say something
## different about that one.
signal hit_confirmed(killed: bool)
## Emitted with the world position damage came from, so the HUD can show
## which way to turn. `Vector3.INF` means "no direction" (falls, etc).
signal damaged_from(source_position: Vector3)
## `kind` is "step_a" / "step_b" / "land"; main routes it to the mixer.
signal footstep(kind: String)
## The frame a deliberate jump actually launched (buffered input resolving
## against coyote time) — the rule engine's `jump` event, not the input.
signal jumped

#: ECHOES §9's control grammar, one binding per slot. LMB is the Static
#: Pulse and appears nowhere here: its identity is untouchable, so it is
#: not a slot and cannot be rebound to one.
const SLOT_ACTIONS := {
	"echo_a": "fire_echo",
	"echo_b": "fire_echo_b",
	"mobility": "fire_mobility",
	"utility": "fire_utility",
}

const MOUSE_SENSITIVITY := 0.0022
#: Metres between footfalls. Paced by distance so it tracks speed Echoes.
const STEP_DISTANCE := 2.2
#: A landing needs real airtime AND real downward speed, so stair seams
#: and the first frame after a spawn do not thump.
const LAND_MIN_AIRTIME := 0.18
const LAND_MIN_SPEED := 3.0

## Head bob, paced by distance travelled like the footsteps are, so the
## dip and the footfall stay in phase at any speed multiplier — a bob on a
## wall-clock timer drifts away from the sound it is supposed to be part
## of. Small on purpose: this is a walk, not a boat.
const BOB_RISE := 0.032
const BOB_SWAY := 0.020
#: Deepest a hard landing may drop the view, in metres.
const LAND_DIP_MAX := 0.15

var hp: float = Constants.PLAYER_MAX_HP
var input_frozen := false
var gravity_mult := 1.0
var speed_mult := 1.0
## The rest of the S5 derived stat stack, refreshed every physics frame
## from `stat_stack`. Base is 1.0 for each; the stack owns floors/clamps.
var jump_mult := 1.0
var air_control_mult := 1.0
var friction_mult := 1.0
var damage_dealt_mult := 1.0
var damage_taken_mult := 1.0
var knockback_resist_mult := 1.0
var regen_mult := 1.0

var stat_stack := StatStack.new()
var statuses := StatusEffects.new()

## Set by EchoRuntime while a `glide` is held. 0 means not gliding. The
## runtime owns the decision; the player owns the physics, so a glide
## survives here as two numbers rather than as a reference to an ability.
var glide_fall_speed := 0.0
var glide_forward_speed := 0.0
## Set by EchoRuntime while a `hover` is held; 1.0 otherwise. Applied on
## top of the trait stack's gravity, same ownership split as the glide.
var hover_gravity_scale := 1.0

## Set by EchoRuntime when a `slam_ground` is committed to, and paid out on
## landing. It has to resolve HERE because only the body knows the frame it
## touched down on, and a slam that detonates on the way down is just a
## fast fall.
var pending_slam: Dictionary = {}

## `grapple_swing` tether: anchor, pull strength and the time it has left.
var _swing_anchor := Vector3.ZERO
var _swing_force := 0.0
var _swing_time := 0.0

var _pulse_cooldown := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _dead := false
var _spawn_transform: Transform3D
var _interact_target: Node = null
var _step_accumulator := 0.0
var _step_toggle := false
var _airborne_time := 0.0
var _bob_phase := 0.0
var _bob_weight := 0.0
var _land_dip := 0.0

@onready var camera: Camera3D = $Camera3D
## slot -> EchoRuntime, one per `SLOT_NAMES`. Filled by `create()`, which
## is where the nodes are made — an `@onready` collection read the tree
## back and came up empty, and a dictionary that is sometimes empty is a
## loadout that sometimes silently has no buttons.
var runtimes: Dictionary = {}
## The slot the wheel cycles and the viewmodel shows. Every slot fires on
## its own key regardless; this is only "which one are you looking at".
var highlighted_slot := "echo_a"

## The highlighted slot's runtime. The HUD's cooldown bar, the viewmodel
## and the favourites wheel all mean this one; anything that must reach
## every slot iterates `runtimes` instead.
var echo_runtime: EchoRuntime:
	get:
		return runtimes.get(highlighted_slot, runtimes.get("echo_a"))

func set_highlighted_slot(slot: String) -> void:
	if slot in runtimes and slot != highlighted_slot:
		highlighted_slot = slot
		for runtime: EchoRuntime in runtimes.values():
			runtime.refresh_viewmodel()

## Total shield across every slot: two Echoes granting one each should
## read as two, and a hit should eat both before it reaches hp.
func total_shield() -> float:
	var total := 0.0
	for runtime: EchoRuntime in runtimes.values():
		total += runtime.shield_hp
	return total

# --- Affordance volumes (ECHOES §13) --------------------------------------
#
# Water, wind and rails influence movement while you are inside them. They
# are kept apart from the stat stack on purpose: `_refresh_derived_stats`
# rewrites every multiplier from the fold each frame, so a volume that
# wrote into those fields would be either erased or permanent depending on
# frame order. This layer is applied AFTER the stack and lasts exactly as
# long as the overlap.
#
# A volume may never strand you. Nothing here can pin you in place: lift is
# upward-only, drag is bounded, and speed is floored — see
# `MIN_VOLUME_SPEED_SCALE`. Combined with §13.2 (no feature on the mandatory
# path), that keeps the base kit sufficient no matter what a Zone offers.

## The hard floor on how slow any volume may make you. A volume is optional
## content; one that could stop you moving would be a trap, and the fact
## that features are off the mandatory path would stop being enough.
const MIN_VOLUME_SPEED_SCALE := 0.4
const MAX_VOLUME_DRAG := 6.0
## The slipperiest a volume may make the ground. A rail is meant to carry
## you further, not to be a surface you can never stop on.
const MIN_VOLUME_FRICTION_SCALE := 0.05

var _volumes: Dictionary = {}

## Called by an affordance volume's own Area3D on overlap. Keyed by the
## node so overlapping volumes cannot leave a stale influence behind when
## one of them is freed mid-overlap.
func enter_volume(volume: Node, influence: Dictionary) -> void:
	_volumes[volume] = influence

func exit_volume(volume: Node) -> void:
	_volumes.erase(volume)

## Merge every overlapping volume into one influence. Scales multiply so
## two volumes compose, lift sums, drag and terminal fall take the
## strongest claim, and the result is clamped to what cannot trap.
func environment_influence() -> Dictionary:
	var out := {"gravity_scale": 1.0, "speed_scale": 1.0, "lift": 0.0,
			"drag": 0.0, "terminal_fall": INF, "friction_scale": 1.0}
	for volume: Variant in _volumes.keys():
		if not is_instance_valid(volume):
			continue
		var influence: Dictionary = _volumes[volume]
		out["gravity_scale"] = float(out["gravity_scale"]) \
				* float(influence.get("gravity_scale", 1.0))
		out["speed_scale"] = float(out["speed_scale"]) \
				* float(influence.get("speed_scale", 1.0))
		out["lift"] = float(out["lift"]) + float(influence.get("lift", 0.0))
		out["drag"] = maxf(float(out["drag"]),
				float(influence.get("drag", 0.0)))
		out["terminal_fall"] = minf(float(out["terminal_fall"]),
				float(influence.get("terminal_fall", INF)))
		out["friction_scale"] = minf(
				float(out["friction_scale"]),
				float(influence.get("friction_scale", 1.0)))
	out["speed_scale"] = maxf(float(out["speed_scale"]),
			MIN_VOLUME_SPEED_SCALE)
	out["drag"] = minf(float(out["drag"]), MAX_VOLUME_DRAG)
	out["lift"] = maxf(float(out["lift"]), 0.0)
	# Floored, for the same reason speed is: a surface with no friction at
	# all is one you can never stop on, which is a trap wearing a rail's
	# clothes.
	out["friction_scale"] = clampf(
			float(out["friction_scale"]), MIN_VOLUME_FRICTION_SCALE, 1.0)
	return out
@onready var viewmodel: Node3D = $Camera3D/Viewmodel

static func create() -> Player:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/gameplay/player.gd"))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = Constants.PLAYER_HEIGHT
	capsule.radius = Constants.PLAYER_RADIUS
	shape.shape = capsule
	shape.position = Vector3(0, Constants.PLAYER_HEIGHT / 2.0, 0)
	player.add_child(shape)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, Constants.PLAYER_EYE_HEIGHT, 0)
	camera.fov = 90.0
	player.add_child(camera)

	# The viewmodel: a crude handheld transmitter, very 1998. The Static
	# Pulse emitter is always there; the Echo attachment appears when a
	# primary Echo is equipped.
	var viewmodel := Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.position = Vector3(0.34, -0.3, -0.62)
	viewmodel.rotation_degrees = Vector3(0, 8, -4)
	var device := MeshInstance3D.new()
	device.name = "Device"
	var device_mesh := PrismMesh.new()
	device_mesh.size = Vector3(0.14, 0.16, 0.4)
	device.mesh = device_mesh
	device.rotation_degrees = Vector3(-90, 0, 0)
	device.material_override = ThemeMaterials.glow_material(
			Color(0.35, 0.42, 0.5), 0.25)
	viewmodel.add_child(device)
	var tip := MeshInstance3D.new()
	tip.name = "Tip"
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.05, 0.05, 0.08)
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.02, -0.24)
	tip.material_override = ThemeMaterials.glow_material(
			Color(0.75, 0.85, 1.0), 1.6)
	viewmodel.add_child(tip)
	var echo_part := MeshInstance3D.new()
	echo_part.name = "EchoPart"
	var echo_mesh := BoxMesh.new()
	echo_mesh.size = Vector3(0.10, 0.08, 0.26)
	echo_part.mesh = echo_mesh
	echo_part.position = Vector3(-0.11, 0.0, -0.05)
	echo_part.visible = false
	# The attachment's emitter tip. EchoRuntime paints the body with the
	# source world's colour and this with the archetype's.
	var echo_tip := MeshInstance3D.new()
	echo_tip.name = "EchoTip"
	var echo_tip_mesh := BoxMesh.new()
	echo_tip_mesh.size = Vector3(0.05, 0.04, 0.05)
	echo_tip.mesh = echo_tip_mesh
	echo_tip.position = Vector3(0, 0, -0.15)
	echo_part.add_child(echo_tip)
	viewmodel.add_child(echo_part)
	camera.add_child(viewmodel)

	# Muzzle flash: a one-frame light at the barrel. Without it a shot in
	# an unlit corridor lights nothing, which reads flat and cheap.
	var flash := OmniLight3D.new()
	flash.name = "MuzzleFlash"
	flash.position = Vector3(0, 0.02, -0.3)
	flash.omni_range = 9.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	viewmodel.add_child(flash)

	# S7: one runtime per slot (ECHOES §9). Cooldowns, held state and
	# airtime budgets belong to the Action, so four buttons need four of
	# them — sharing one would let a dash and a grapple contend for a
	# single cooldown, which is the bug the four-slot loadout exists to
	# make impossible.
	for slot: String in Constants.SLOT_NAMES:
		var runtime := Node.new()
		runtime.name = "EchoRuntime_" + slot
		runtime.set_script(load("res://scripts/gameplay/echo_runtime.gd"))
		player.add_child(runtime)
		runtime.slot = slot
		runtime.player_ref = player
		player.runtimes[slot] = runtime
	return player

func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	statuses.side = "self"
	stat_stack.statuses = statuses
	fired_pulse.connect(func() -> void:
		kick_viewmodel(0.05)
		muzzle_flash(1.6, Color(0.75, 0.85, 1.0)))

## Evaluate the stack and let statuses breathe. Runs at the top of every
## physics frame so `scaled_by` traits track live fractions.
func _refresh_derived_stats(delta: float) -> void:
	statuses.tick(delta)
	stat_stack.tick(delta)
	stat_stack.hp_fraction = hp / Constants.PLAYER_MAX_HP
	var stats := stat_stack.evaluate()
	speed_mult = float(stats["move_speed"])
	gravity_mult = float(stats["gravity"])
	jump_mult = float(stats["jump_height"])
	air_control_mult = float(stats["air_control"])
	friction_mult = float(stats["ground_friction"])
	damage_dealt_mult = float(stats["damage_dealt"])
	damage_taken_mult = float(stats["damage_taken"])
	knockback_resist_mult = float(stats["knockback_resist"])
	regen_mult = float(stats["regen"])
	var dot := statuses.dot_per_second()
	if dot > 0.0 and not _dead:
		take_damage(dot * delta)
	var regen := statuses.regen_per_second()
	if regen > 0.0 and not _dead and hp < Constants.PLAYER_MAX_HP:
		heal(regen * delta)

## A brief light at the barrel, sized to the shot.
func muzzle_flash(energy: float, color: Color) -> void:
	if viewmodel == null:
		return
	var flash: OmniLight3D = viewmodel.get_node_or_null("MuzzleFlash")
	if flash == null:
		return
	flash.light_color = color
	flash.light_energy = energy
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.09)

func kick_viewmodel(strength: float) -> void:
	if viewmodel == null:
		return
	var rest := Vector3(0.34, -0.3, -0.62)
	viewmodel.position = rest + Vector3(0, strength * 0.4, strength * 2.0)
	var tween := create_tween()
	tween.tween_property(viewmodel, "position", rest, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_spawn(xform: Transform3D) -> void:
	_spawn_transform = xform
	global_transform = xform

func _unhandled_input(event: InputEvent) -> void:
	if input_frozen or _dead:
		return
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

func _physics_process(delta: float) -> void:
	_pulse_cooldown = maxf(0.0, _pulse_cooldown - delta)
	if _dead:
		return
	_refresh_derived_stats(delta)

	var env := environment_influence()
	var gravity := Constants.GRAVITY * gravity_mult * hover_gravity_scale \
			* float(env["gravity_scale"])
	if not is_on_floor():
		velocity.y -= gravity * delta
		_coyote -= delta
	else:
		_coyote = Constants.COYOTE_TIME
	_jump_buffer -= delta

	# Upward-only, and applied whether or not you are grounded: an updraft
	# you have to jump into first is an updraft nobody finds.
	if float(env["lift"]) > 0.0:
		velocity.y += float(env["lift"]) * delta
	velocity.y = maxf(velocity.y, -float(env["terminal_fall"]))
	if float(env["drag"]) > 0.0:
		var damping := 1.0 - minf(0.9, float(env["drag"]) * delta)
		velocity.x *= damping
		velocity.z *= damping

	# A glide caps the fall and adds a push along the look direction. Only
	# ever a CAP: it cannot make you rise, so it stays a descent you steer
	# rather than flight, and no gap becomes trivially crossable.
	if glide_fall_speed > 0.0 and not is_on_floor():
		velocity.y = maxf(velocity.y, -glide_fall_speed)
		var glide_dir := -camera.global_transform.basis.z
		var flat := Vector3(glide_dir.x, 0.0, glide_dir.z).normalized()
		velocity.x = lerpf(velocity.x, flat.x * glide_forward_speed, 0.08)
		velocity.z = lerpf(velocity.z, flat.z * glide_forward_speed, 0.08)

	_update_swing(delta)
	for runtime: EchoRuntime in runtimes.values():
		runtime.set_grounded(is_on_floor())

	if not input_frozen:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = Constants.JUMP_BUFFER
		if _jump_buffer > 0.0 and _coyote > 0.0:
			# Height scales with the square of launch speed, so a
			# jump_height multiplier rides in as its square root.
			velocity.y = Constants.JUMP_VELOCITY * sqrt(jump_mult)
			_jump_buffer = 0.0
			_coyote = 0.0
			jumped.emit()

		var input_dir := Input.get_vector(
				"move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis
				* Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var speed := Constants.WALK_SPEED * speed_mult \
				* float(env["speed_scale"])
		# Friction below base is how a downside is allowed to express
		# (§10): slippier control, never a shorter jump.
		# A grind rail's lane multiplies ground friction down, so a dash
		# along it keeps its speed instead of being lerped back to walking
		# pace. The rail's first influence was `{drag: 0.0, speed_scale:
		# 1.0}` — both the identity element of how these merge, so the
		# whole feature did nothing at all.
		var control := friction_mult * float(env["friction_scale"]) \
				if is_on_floor() \
				else Constants.AIR_CONTROL * air_control_mult
		control = minf(control, 1.0)
		velocity.x = lerpf(velocity.x, direction.x * speed, control * 0.4)
		velocity.z = lerpf(velocity.z, direction.z * speed, control * 0.4)

		if Input.is_action_pressed("fire_pulse"):
			_fire_static_pulse()
		# The Static Pulse keeps LMB and is never any of these. Each slot
		# owns exactly one binding, so "which button was that" and "which
		# Echo fired" are the same question.
		for slot: String in SLOT_ACTIONS:
			var action: String = SLOT_ACTIONS[slot]
			if Input.is_action_just_pressed(action):
				set_highlighted_slot(slot)
				runtimes[slot].activate()
			if Input.is_action_just_released(action):
				runtimes[slot].release()
		if Input.is_action_just_pressed("interact") \
				and _interact_target != null:
			_interact_target.interact(self)
	else:
		velocity.x = lerpf(velocity.x, 0.0, 0.2)
		velocity.z = lerpf(velocity.z, 0.0, 0.2)

	var falling_speed := -velocity.y
	var was_airborne := not is_on_floor()
	move_and_slide()
	if was_airborne and is_on_floor():
		_resolve_pending_slam()
	_update_footsteps(delta, falling_speed)
	_update_camera_feel(delta)
	_update_interact_target()

	if global_position.y < Constants.FALL_KILL_Y:
		take_damage(Constants.PLAYER_MAX_HP * 10.0)

## Static Pulse: hitscan, low damage, short cooldown, unlimited, reliable.
func _fire_static_pulse() -> void:
	if _pulse_cooldown > 0.0:
		return
	_pulse_cooldown = Constants.STATIC_PULSE_COOLDOWN
	fired_pulse.emit()
	var hit := camera_ray(Constants.STATIC_PULSE_RANGE)
	if not hit.is_empty():
		var target: Variant = hit["collider"]
		# Anything damageable, not just enemies: the Pulse is how a player
		# discovers that a breakable panel needs a heavier hit, and a
		# panel nothing could shoot was a wall with no feedback at all.
		if Damageable.of(target) != null:
			# §9: the Pulse's identity is untouchable, but a global
			# damage_dealt trait still multiplies it.
			report_hit(Damageable.hit(target,
					Constants.STATIC_PULSE_DAMAGE * damage_dealt_mult,
					-camera.global_transform.basis.z, 0.0))
	_spawn_tracer(hit)

## Attacks that do not originate here — Echo hitscans, Echo projectiles
## still in flight — confirm through this, so "my shot connected" is one
## signal no matter what fired it.
func report_hit(killed: bool) -> void:
	hit_confirmed.emit(killed)

## Footfalls paced by distance travelled, not by a timer, so they stay in
## step with the player at any speed multiplier.
func _update_footsteps(delta: float, falling_speed: float) -> void:
	if not is_on_floor():
		_airborne_time += delta
		return
	# Only a real fall lands. A single-frame loss of floor contact on a
	# stair seam or ramp is not a landing, and treating it as one both
	# replayed the loudest tone and reset the step cadence to silence.
	if _airborne_time > LAND_MIN_AIRTIME and falling_speed > LAND_MIN_SPEED:
		footstep.emit("land")
		# The view drops with the thump, in proportion to the drop.
		_land_dip = clampf(falling_speed / 90.0, 0.04, LAND_DIP_MAX)
		_step_accumulator = 0.0
	_airborne_time = 0.0

	var travelled := Vector2(velocity.x, velocity.z).length() * delta
	if travelled < 0.01:
		return
	_step_accumulator += travelled
	if _step_accumulator >= STEP_DISTANCE:
		_step_accumulator = 0.0
		_step_toggle = not _step_toggle
		footstep.emit("step_a" if _step_toggle else "step_b")

## Head bob and the landing dip. Only the camera's POSITION moves, never
## its rotation: the crosshair is where you aim, and a view that rolled
## with your gait would put shots somewhere other than the cross.
func _update_camera_feel(delta: float) -> void:
	if camera == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var walking := is_on_floor() and speed > 0.6 and not _dead
	if walking:
		_bob_phase += speed * delta / STEP_DISTANCE * PI
	# Weight, not phase, is what fades: cutting the phase would snap the
	# view to wherever the sine happened to be when you stopped.
	_bob_weight = lerpf(_bob_weight, 1.0 if walking else 0.0,
			minf(1.0, delta * 9.0))
	_land_dip = lerpf(_land_dip, 0.0, minf(1.0, delta * 9.0))
	if _bob_weight < 0.001 and _land_dip < 0.001:
		_bob_weight = 0.0
		_land_dip = 0.0
	camera.position = Vector3(0, Constants.PLAYER_EYE_HEIGHT, 0) \
			+ camera_feel_offset(_bob_phase, _bob_weight, _land_dip)

## Pure, so the bounds below can be tested rather than trusted: whatever
## the gait is doing, the view stays within a few centimetres of the eye
## height every other number in the game is derived from.
static func camera_feel_offset(phase: float, weight: float,
		dip: float) -> Vector3:
	return Vector3(sin(phase) * BOB_SWAY * weight,
			sin(phase * 2.0) * BOB_RISE * weight - dip, 0.0)

func camera_ray(distance: float, spread_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	if spread_dir != Vector3.ZERO:
		dir = spread_dir
	var to := from + dir * distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _spawn_tracer(hit: Dictionary) -> void:
	var from := camera.global_position \
			+ camera.global_transform.basis * Vector3(0.15, -0.12, -0.3)
	var to: Vector3 = hit["position"] if not hit.is_empty() \
			else camera.global_position \
			- camera.global_transform.basis.z * Constants.STATIC_PULSE_RANGE
	# Static Pulse is made of the garbage Epsilon leaves behind: the more
	# Static the multiworld has delivered, the more it discolors.
	var units := int(BridgeClient.snapshot.get("static_glitch_units", 0))
	var corruption := minf(1.0, float(units)
			/ float(Constants.STATIC_GLITCH_VISUAL_CAP))
	var color := Color(0.75, 0.85, 1.0).lerp(
			Color(1.0, 0.35, 0.9), corruption * 0.7)
	Tracer.spawn(get_tree().current_scene, from, to, color, 0.06)

func take_damage(amount: float,
		source_position: Vector3 = Vector3.INF) -> void:
	if _dead:
		return
	amount *= damage_taken_mult
	# Parry first wherever it is, then shields in slot order — the same
	# precedence one runtime used, spread across four.
	for runtime: EchoRuntime in runtimes.values():
		amount = runtime.absorb_with_shield(amount)
		if amount <= 0.0:
			break
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, total_shield())
	damaged_from.emit(source_position)
	if hp <= 0.0:
		_die()

## External shoves come through here so `knockback_resist` has one place
## to push back. Self-chosen recoil (the shotgun's travel plan) does not —
## resisting your own movement tech would be a downside wearing a buff.
func receive_knockback(impulse: Vector3) -> void:
	velocity += impulse / maxf(knockback_resist_mult, 0.25)

func heal(amount: float) -> void:
	# `regen` is a multiplier on recovery received — the game has no base
	# trickle for it to scale, and healing-in is the recovery that exists.
	hp = minf(Constants.PLAYER_MAX_HP, hp + amount * regen_mult)
	hp_changed.emit(hp, total_shield())

func _die() -> void:
	_dead = true
	died.emit()
	var timer := get_tree().create_timer(Constants.RESPAWN_DELAY)
	timer.timeout.connect(_respawn)

func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	hp = Constants.PLAYER_MAX_HP
	_dead = false
	hp_changed.emit(hp, total_shield())

func _update_interact_target() -> void:
	var hit := camera_ray(3.0)
	var target: Node = null
	if not hit.is_empty():
		var collider: Variant = hit["collider"]
		if is_instance_valid(collider) and collider.has_method("interact"):
			target = collider
	if target != _interact_target:
		_interact_target = target
		var prompt := ""
		if target != null and target.has_method("interact_prompt"):
			prompt = target.interact_prompt()
		elif target != null:
			prompt = "[E] INTERACT"
		interact_prompt_changed.emit(prompt)

## Pays out a committed `slam_ground` on the frame the body touches down.
## Radial, falling off toward the rim, exactly like `arc_lob` — the two are
## the same shape of hit and should read the same way.
func _resolve_pending_slam() -> void:
	if pending_slam.is_empty():
		return
	var damage := float(pending_slam.get("damage", 0.0))
	var radius := float(pending_slam.get("radius", 0.0))
	var tint: Color = pending_slam.get("tint", Color(1.0, 0.6, 0.3))
	pending_slam = {}
	var hit_any := false
	var killed_any := false
	for node in get_tree().get_nodes_in_group(Damageable.GROUP):
		var struck := node as Node3D
		if struck == null or not is_instance_valid(struck):
			continue
		var offset := struck.global_position - global_position
		var distance := offset.length()
		if distance > radius:
			continue
		var falloff := 1.0 - clampf(distance / maxf(radius, 0.001), 0.0, 1.0) * 0.6
		var away := offset.normalized() if distance > 0.001 else Vector3.UP
		if Damageable.hit(struck, damage * falloff, away, 0.0):
			killed_any = true
		hit_any = true
	if hit_any:
		report_hit(killed_any)
	Blast.spawn(get_tree().current_scene, global_position, radius, tint)
	_land_dip = LAND_DIP_MAX

## Starts a `grapple_swing` tether. The anchor is a point, not a node: the
## geometry it was cast at is static, and holding a reference would keep a
## freed chamber alive across a zone change.
func begin_swing(anchor: Vector3, force: float, duration: float) -> void:
	_swing_anchor = anchor
	_swing_force = force
	_swing_time = duration

## A tether pulls you toward the anchor along the rope and leaves the
## tangential component alone — that difference is the whole reason this is
## a swing and not a second grapple. It ends on the timer, on landing, or
## when the key comes up.
func _update_swing(delta: float) -> void:
	if _swing_time <= 0.0:
		return
	_swing_time -= delta
	if _swing_time <= 0.0 or is_on_floor() \
			or not Input.is_action_pressed("fire_echo"):
		_swing_time = 0.0
		return
	var to_anchor := _swing_anchor - global_position
	var distance := to_anchor.length()
	if distance < 0.6:
		_swing_time = 0.0
		return
	var rope := to_anchor / distance
	# Only the part of the pull that is not already along the rope does
	# anything, so the arc accelerates instead of snapping taut.
	velocity += rope * _swing_force * delta
	var along := velocity.dot(rope)
	if along < 0.0:
		velocity -= rope * along * 0.5
