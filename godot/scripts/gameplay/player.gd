class_name Player
extends CharacterBody3D
## First-person controller. Every number comes from Constants (generated
## from schemas/constants.py) — do not invent movement values here.
##
## LMB is ALWAYS Static Pulse. RMB is the equipped Echo. Never rebound.

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

## Set by EchoRuntime while a `glide` is held. 0 means not gliding. The
## runtime owns the decision; the player owns the physics, so a glide
## survives here as two numbers rather than as a reference to an ability.
var glide_fall_speed := 0.0
var glide_forward_speed := 0.0

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
@onready var echo_runtime: EchoRuntime = $EchoRuntime
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

	var runtime := Node.new()
	runtime.name = "EchoRuntime"
	runtime.set_script(load("res://scripts/gameplay/echo_runtime.gd"))
	player.add_child(runtime)
	return player

func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	fired_pulse.connect(func() -> void:
		kick_viewmodel(0.05)
		muzzle_flash(1.6, Color(0.75, 0.85, 1.0)))

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

	var gravity := Constants.GRAVITY * gravity_mult
	if not is_on_floor():
		velocity.y -= gravity * delta
		_coyote -= delta
	else:
		_coyote = Constants.COYOTE_TIME
	_jump_buffer -= delta

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
	echo_runtime.set_grounded(is_on_floor())

	if not input_frozen:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = Constants.JUMP_BUFFER
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = Constants.JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			jumped.emit()

		var input_dir := Input.get_vector(
				"move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis
				* Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var speed := Constants.WALK_SPEED * speed_mult
		var control := 1.0 if is_on_floor() else Constants.AIR_CONTROL
		velocity.x = lerpf(velocity.x, direction.x * speed, control * 0.4)
		velocity.z = lerpf(velocity.z, direction.z * speed, control * 0.4)

		if Input.is_action_pressed("fire_pulse"):
			_fire_static_pulse()
		if Input.is_action_just_pressed("fire_echo"):
			echo_runtime.activate()
		if Input.is_action_just_released("fire_echo"):
			echo_runtime.release()
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
		if is_instance_valid(target) and target.is_in_group("enemies"):
			var enemy := target as Enemy
			report_hit(enemy.take_damage(Constants.STATIC_PULSE_DAMAGE,
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
	amount = echo_runtime.absorb_with_shield(amount)
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, echo_runtime.shield_hp)
	damaged_from.emit(source_position)
	if hp <= 0.0:
		_die()

func heal(amount: float) -> void:
	hp = minf(Constants.PLAYER_MAX_HP, hp + amount)
	hp_changed.emit(hp, echo_runtime.shield_hp)

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
	hp_changed.emit(hp, echo_runtime.shield_hp)

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
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - global_position
		var distance := offset.length()
		if distance > radius:
			continue
		var falloff := 1.0 - clampf(distance / maxf(radius, 0.001), 0.0, 1.0) * 0.6
		var away := offset.normalized() if distance > 0.001 else Vector3.UP
		if enemy.take_damage(damage * falloff, away, 0.0):
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
