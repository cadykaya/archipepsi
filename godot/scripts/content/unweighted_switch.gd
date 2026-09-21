class_name UnweightedSwitch
extends Node3D
## EX50-033 UNWEIGHTED SWITCH, PLAYABLE (`--unweighted`).
## **Development scaffolding, and a minor situation, not a Zone.**
##
## **The contradiction the room is.** The upper doorway's sill is above a
## baseline jump from the floor and within one from the crate's top. So
## you drive the crate into the recess to stand on it — and the recess
## floor is a HEAVY-class plate, which closes the shutter through a NOT.
## Placing the step you need closes the route you want.
##
## **`lightened` resolves it without moving the crate.** The Status drops
## the crate's mass class one step. The plate stops reading a qualifying
## occupant and releases; the shutter opens; and the crate is still
## exactly as solid and exactly as tall, because the Status changed its
## CLASS and never its kilograms. That distinction is the room.
##
## **The Status is real.** `ManipulableBody.apply_status` into a
## `StatusEffects` whose target kind is `object`, refused at the engine's
## own boundary if the runtime does not implement it there, and declared
## `lightened: ("object",)` in `SUPPORTED_STATUS_TARGETS`. There is no
## stand-in and no room-local vocabulary.
##
## **What this is NOT.** Not composed, no Checks, no exit, no campaign,
## no save, no bridge connection. `--disconnected` is §11's control: the
## plate's signal is not wired to the shutter, and the expected response
## must then fail.

const ROOM_HALF := Vector2(8.0, 7.0)
const ROOM_HEIGHT := 6.0
const THEME := "concrete_facility"
const SLAB := 0.6

## §2: the sill is above a comfortable baseline jump from the floor and
## reachable with margin from the crate top. Both are measured.
const SILL_Y := 1.9
const DOOR_HALF := 1.2
const NORTH_Z := 6.8

## The recess: §2's 2.4 by 2.4, bounded by real side walls, its floor
## entirely plate. Sunk by the plate's own thickness so the crate stands
## at the same height parked or placed -- a guide track with a step in it
## is a guide track that catches.
const PLATE := Vector3(2.4, 0.12, 2.4)
const RECESS_Z := 5.6
const CRATE := Vector3(2.0, 1.0, 2.0)
const CRATE_KG := 200.0
const PARK_Z := 1.0

## §3: LIGHTENED's own numbers, from Design 5 §15.2.
const LIGHTENED_SECONDS := 8.0
const LIGHTENED_MAGNITUDE := 0.40

const DRIVE_SPEED := 1.1
const STEP_RISE := 0.25
## The gap in the north wall the released stair leads back through. High
## only: from the floor there is nothing to reach it by.
const RETURN_X := Vector2(3.0, 6.0)

var plate: ClassPlate = null
var shutter: ServiceShutter = null
var crate: ManipulableBody = null
var applicator: ActivityElement = null
var bolt: CallLever = null
var drive: CallLever = null
var goal_plate: ActivityElement = null
var player: Player = null
var hud: Hud = null

## Pulled once and never withdrawn (§9): the crossing is held open and a
## fixed return stair exists from then on.
var bolted := false
var reached_goal := false
## §11's control: the plate's output is not wired to the shutter.
var disconnected := false

var _world: Node3D = null
## Built by the bolt and never removed. Held by name because "is the
## return stair there" is a question the suite has to be able to ask.
var _return_stair: Node3D = null
var _drive_goal := PARK_Z
var _readout: Label3D = null


func _ready() -> void:
	name = "UnweightedSwitch"
	_environment()
	_world = Node3D.new()
	_world.name = "Chamber"
	add_child(_world)
	_shell()
	_the_recess()
	_the_crate()
	_the_shutter()
	_the_applicator()
	_beyond()
	_controls()
	_signs()
	_spawn_player()
	_hud()


func _environment() -> void:
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(THEME)
	env.ambient_light_energy = 0.6
	holder.environment = env
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(15.0), 0.0)
	sun.light_energy = 0.9
	add_child(sun)


func _shell() -> void:
	var floor_mat := ThemeMaterials.floor_mat(THEME)
	var wall := ThemeMaterials.wall_mat(THEME)
	# The floor, with the recess cut out of it.
	_ground(-ROOM_HALF.x, ROOM_HALF.x, -ROOM_HALF.y, RECESS_Z - 1.2,
			0.0, floor_mat)
	_ground(-ROOM_HALF.x, -DOOR_HALF, RECESS_Z - 1.2, NORTH_Z, 0.0,
			floor_mat)
	_ground(DOOR_HALF, ROOM_HALF.x, RECESS_Z - 1.2, NORTH_Z, 0.0,
			floor_mat)
	var mid := ROOM_HEIGHT * 0.5
	_slab(Vector3(0.5, ROOM_HEIGHT, ROOM_HALF.y * 2.0),
			Vector3(-ROOM_HALF.x, mid, 0.0), wall)
	_slab(Vector3(0.5, ROOM_HEIGHT, ROOM_HALF.y * 2.0),
			Vector3(ROOM_HALF.x, mid, 0.0), wall)
	_slab(Vector3(ROOM_HALF.x * 2.0, ROOM_HEIGHT, 0.5),
			Vector3(0.0, mid, -ROOM_HALF.y), wall)
	# THE NORTH WALL IN FOUR PIECES: the doorway, the high return gap,
	# and the solid runs between. The return gap starts at the sill, so
	# from the floor there is no second way up.
	_slab(Vector3(ROOM_HALF.x - DOOR_HALF, ROOM_HEIGHT, 0.5),
			Vector3(-(ROOM_HALF.x + DOOR_HALF) * 0.5, mid, NORTH_Z), wall)
	_slab(Vector3(RETURN_X.x - DOOR_HALF, ROOM_HEIGHT, 0.5),
			Vector3((DOOR_HALF + RETURN_X.x) * 0.5, mid, NORTH_Z), wall)
	_slab(Vector3(RETURN_X.y - RETURN_X.x, SILL_Y, 0.5),
			Vector3((RETURN_X.x + RETURN_X.y) * 0.5, SILL_Y * 0.5,
				NORTH_Z), wall)
	_slab(Vector3(ROOM_HALF.x - RETURN_X.y, ROOM_HEIGHT, 0.5),
			Vector3((RETURN_X.y + ROOM_HALF.x) * 0.5, mid, NORTH_Z), wall)
	# Above the doorway.
	_slab(Vector3(DOOR_HALF * 2.0, ROOM_HEIGHT - (SILL_Y + 2.0), 0.5),
			Vector3(0.0, SILL_Y + 2.0
				+ (ROOM_HEIGHT - SILL_Y - 2.0) * 0.5, NORTH_Z), wall)
	# And under it: the sill is a real lip, not a line in the air.
	_slab(Vector3(DOOR_HALF * 2.0, SILL_Y, 0.5),
			Vector3(0.0, SILL_Y * 0.5, NORTH_Z), wall)


## §2: "bounded by real side walls", and its floor is entirely plate --
## "Moving the crate slightly sideways cannot leave it as a valid step
## while evading the sensor by an arbitrary millimetre."
func _the_recess() -> void:
	var wall := ThemeMaterials.wall_mat(THEME)
	_ground(-DOOR_HALF, DOOR_HALF, RECESS_Z - 1.2, NORTH_Z, -PLATE.y,
			ThemeMaterials.trim_mat(THEME))
	plate = ClassPlate.create(PLATE, MassClass.HEAVY, THEME)
	_world.add_child(plate)
	plate.global_position = Vector3(0.0, -PLATE.y * 0.5, RECESS_Z)
	if not disconnected:
		plate.occupancy_changed.connect(_on_plate)
	# THE GUIDE TRACK. §8: the crate is constrained enough that an
	# ordinary landing does not roll it out of the recess, which is the
	# authored alternative the paper allows to LIGHTENED's real impulse
	# response. The channel runs from the parking place to the recess.
	for side: float in [-1.0, 1.0]:
		_slab(Vector3(0.4, 1.4, NORTH_Z - (PARK_Z - 1.4)),
				Vector3((DOOR_HALF + 0.2) * side, 0.7,
					(PARK_Z - 1.4 + NORTH_Z) * 0.5), wall)


func _the_crate() -> void:
	crate = ManipulableBody.create("service_crate", CRATE_KG, CRATE)
	_world.add_child(crate)
	crate.global_position = Vector3(0.0, CRATE.y * 0.5, PARK_Z)
	crate.freeze = true
	crate.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var skin := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = CRATE
	skin.mesh = box
	skin.material_override = ThemeMaterials.accent_mat(THEME)
	crate.add_child(skin)


func _the_shutter() -> void:
	shutter = ServiceShutter.create(
			Vector3(0.0, SILL_Y + 1.0, NORTH_Z),
			Vector3(DOOR_HALF * 2.0, 2.0, 0.35), 2.0, INF, THEME)
	_world.add_child(shutter)
	# §4: "Initially the crate is parked, the plate is OFF and the
	# shutter is open." ALREADY OPEN, not opening: a panel that spent its
	# first second and a half travelling would make the room's opening
	# state a question of when you looked at it, and a suite that settled
	# a few frames would read the wrong answer -- which is exactly what
	# the first run of `godot-unweighted` did.
	shutter.command(true)
	shutter.offset = shutter.travel
	shutter.position = shutter.shut_at + Vector3(0.0, shutter.travel, 0.0)


## §3: "a guaranteed local applicator with an explicit source/Status/
## target binding for this crate. Required progression cannot depend on
## a random proc succeeding eventually."
##
## Shootable rather than a bound emplacement, so §8's "If the player
## misses the applicator shot, the crate remains heavy and nothing
## changes" is a real outcome. Once HIT it always applies: the binding
## is explicit and there is no roll.
func _the_applicator() -> void:
	applicator = ActivityElement.create(ActivityElement.SHOT, 0,
			ActivityElement.TARGET_SIZE, Color(0.55, 0.9, 1.0))
	_world.add_child(applicator)
	applicator.global_position = Vector3(-ROOM_HALF.x + 0.5, 1.5, 3.0)
	applicator.rotation.y = -PI / 2.0
	applicator.triggered.connect(_on_applicator)
	_slab(Vector3(0.5, 0.25, 2.4), Vector3(-ROOM_HALF.x + 1.3, 0.12, 3.0),
			ThemeMaterials.trim_mat(THEME))


func _on_applicator(_which: ActivityElement) -> void:
	# GUARANTEED, and through the real path. A refusal here would be the
	# engine's boundary check, not a proc.
	crate.apply_status("lightened", LIGHTENED_SECONDS, LIGHTENED_MAGNITUDE)
	_say("LIGHTENED -- crate reads %s" % crate.mass_class().to_upper())
	# Reusable: §8 says the source is not consumed.
	applicator.reset()


## G, the bolt, the goal and the stair the bolt releases.
func _beyond() -> void:
	var trim := ThemeMaterials.trim_mat(THEME)
	_ground(-3.0, ROOM_HALF.x, NORTH_Z, ROOM_HALF.y + 4.0, SILL_Y, trim)
	bolt = CallLever.make("HOLD-OPEN BOLT", Color(0.55, 1.0, 0.7), THEME)
	_world.add_child(bolt)
	bolt.global_position = Vector3(0.0, SILL_Y + CallLever.BASE.y * 0.5,
			NORTH_Z + 1.4)
	bolt.pulled.connect(_on_bolt)
	goal_plate = ActivityElement.create(ActivityElement.STAND, 0,
			ActivityElement.PLATE_SIZE, Color(0.55, 1.0, 0.7))
	_world.add_child(goal_plate)
	goal_plate.global_position = Vector3(0.0, SILL_Y, NORTH_Z + 3.4)
	goal_plate.triggered.connect(func(_w: ActivityElement) -> void:
		reached_goal = true
		_say("GOAL REACHED"))


## §3: "Reaching and operating it makes the useful crossing persistent
## without requiring the temporary Status to remain active forever."
func _on_bolt(_who: CallLever) -> void:
	if bolted:
		return
	bolted = true
	shutter.command(true)
	_return_stair = Node3D.new()
	_return_stair.name = "ReturnStair"
	_world.add_child(_return_stair)
	_stair(Vector3(4.5, 0.0, 2.2), Vector3(4.5, SILL_Y, NORTH_Z - 0.4), 1.8,
			_return_stair)
	_say("BOLT ENGAGED -- crossing held, return stair open")


func _controls() -> void:
	drive = CallLever.make("SERVICE DRIVE", Color(1.0, 0.72, 0.35), THEME)
	_world.add_child(drive)
	drive.global_position = Vector3(-3.0,
			CallLever.BASE.y * 0.5, 0.0)
	drive.pulled.connect(_on_drive)


## §3: "a short service drive moves the crate between parking and
## recess. The track is physical and bounded; it does not teleport the
## crate to a puzzle socket."
## Where the guide track is taking the crate. A suite that read only the
## crate's position could not tell "not there yet" from "not going", and
## commanding the lever to find out would toggle it back.
func drive_goal_z() -> float:
	return _drive_goal


func _on_drive(_who: CallLever) -> void:
	_drive_goal = RECESS_Z if is_equal_approx(_drive_goal, PARK_Z) \
			else PARK_Z
	crate.freeze = false
	_say("DRIVE -> %s" % ("RECESS" if _drive_goal == RECESS_Z else "PARK"))


func _physics_process(delta: float) -> void:
	if crate == null or crate.freeze:
		return
	var here := crate.global_position.z
	var step := DRIVE_SPEED * delta
	if absf(_drive_goal - here) <= step:
		crate.global_position.z = _drive_goal
		crate.linear_velocity = Vector3.ZERO
		crate.angular_velocity = Vector3.ZERO
		crate.freeze = true
		return
	crate.global_position.z = here + step * signf(_drive_goal - here)


func _on_plate(satisfied: bool) -> void:
	# THE NOT. A qualifying HEAVY occupant closes the shutter; releasing
	# the plate opens it. The bolt outranks both once engaged.
	if bolted:
		return
	shutter.command(not satisfied)
	_say("PLATE %s -- shutter %s"
			% ["ON" if satisfied else "OFF",
				"closing" if satisfied else "opening"])


func _say(text: String) -> void:
	if _readout != null:
		_readout.text = text


func _signs() -> void:
	_sign("ARRIVAL  A", Vector3(0.0, 2.4, -ROOM_HALF.y + 1.0),
			Color(0.8, 0.85, 0.95), 46)
	_sign("SERVICE LOCKOUT\nHEAVY CLASS", Vector3(0.0, 2.6, RECESS_Z - 2.0),
			Color(1.0, 0.55, 0.3), 32)
	_sign("EX50-033 -- development scenario, not a Zone",
			Vector3(0.0, 1.2, -ROOM_HALF.y + 1.0),
			Color(0.75, 0.7, 0.55), 26)
	_readout = _sign("", Vector3(0.0, 3.1, -ROOM_HALF.y + 1.0),
			Color(0.7, 1.0, 0.8), 32)


func _spawn_player() -> void:
	player = Player.create()
	add_child(player)
	player.set_spawn(Transform3D(Basis(Vector3.UP, 0.0),
			Vector3(0.0, 1.2, -ROOM_HALF.y + 1.6)))
	player.velocity = Vector3.ZERO
	if player.camera != null:
		player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.bind_player(player)
	hud.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


# ---------------------------------------------------------------- parts

func _ground(x0: float, x1: float, z0: float, z1: float,
		top: float, material: Material) -> StaticBody3D:
	if x1 - x0 <= 0.01 or z1 - z0 <= 0.01:
		return null
	return _slab(Vector3(x1 - x0, SLAB, z1 - z0),
			Vector3((x0 + x1) * 0.5, top - SLAB * 0.5, (z0 + z1) * 0.5),
			material)


func _slab(size: Vector3, centre: Vector3,
		material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	body.add_child(mesh_node)
	_world.add_child(body)
	body.global_position = centre
	return body


## Is the fixed return stair built? §9: once the bolt is pulled this is
## true for the rest of the run, whatever the Status is doing.
func return_stair_steps() -> int:
	if _return_stair == null:
		return 0
	return _return_stair.get_child_count()


func _stair(foot: Vector3, head: Vector3, width: float,
		under: Node3D = null) -> void:
	var rise := head.y - foot.y
	var run := Vector3(head.x - foot.x, 0.0, head.z - foot.z)
	if rise <= 0.01 or run.length() < 0.01:
		return
	var steps := maxi(int(ceil(rise / STEP_RISE)), 1)
	var out := run.normalized()
	var tread := run.length() / float(steps)
	var material := ThemeMaterials.trim_mat(THEME)
	for i in steps:
		var height := float(i + 1) * rise / float(steps)
		var here := foot + out * (tread * (float(i) + 0.5)) \
				+ Vector3(0.0, height * 0.5, 0.0)
		var step := _slab(Vector3(width, height, tread), here, material)
		step.basis = Basis.looking_at(-out, Vector3.UP)
		if under != null:
			step.reparent(under, true)


func _sign(text: String, where: Vector3, tint: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	_world.add_child(label)
	label.global_position = where
	return label


# ------------------------------------------------------- what it knows

## The top face of the crate right now -- the surface a player stands on.
func crate_top() -> float:
	return crate.global_position.y + CRATE.y * 0.5


## Is the crate in the recess, on the plate?
func crate_is_placed() -> bool:
	return absf(crate.global_position.z - RECESS_Z) < 0.05
