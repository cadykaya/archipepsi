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
## Emitted with the world position damage came from, so the HUD can show
## which way to turn. `Vector3.INF` means "no direction" (falls, etc).
signal damaged_from(source_position: Vector3)

const MOUSE_SENSITIVITY := 0.0022

var hp: float = Constants.PLAYER_MAX_HP
var input_frozen := false
var gravity_mult := 1.0
var speed_mult := 1.0

var _pulse_cooldown := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _dead := false
var _spawn_transform: Transform3D
var _interact_target: Node = null

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
	viewmodel.add_child(echo_part)
	camera.add_child(viewmodel)

	var runtime := Node.new()
	runtime.name = "EchoRuntime"
	runtime.set_script(load("res://scripts/gameplay/echo_runtime.gd"))
	player.add_child(runtime)
	return player

func _ready() -> void:
	add_to_group("player")
	_spawn_transform = global_transform
	fired_pulse.connect(func() -> void: kick_viewmodel(0.05))

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

	if not input_frozen:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = Constants.JUMP_BUFFER
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = Constants.JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0

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
		if Input.is_action_just_pressed("interact") \
				and _interact_target != null:
			_interact_target.interact(self)
	else:
		velocity.x = lerpf(velocity.x, 0.0, 0.2)
		velocity.z = lerpf(velocity.z, 0.0, 0.2)

	move_and_slide()
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
			target.take_damage(Constants.STATIC_PULSE_DAMAGE,
					-camera.global_transform.basis.z, 0.0)
	_spawn_tracer(hit)

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
