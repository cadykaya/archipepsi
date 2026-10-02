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
## **THE ROOM ITSELF IS `UnweightedSwitchRoom`** (O05-06.1). This scenario
## owns one at the origin and adds what only a development launcher has:
## a sky, a spawned player, a HUD and a readout. A composed Zone hosts the
## same room through `UnweightedSwitchHosted`, so there is one
## implementation of the room and two owners of it.
##
## **What this is NOT.** Not composed, no Checks, no exit, no campaign,
## no save, no bridge connection. `--disconnected` is §11's control: the
## plate's signal is not wired to the shutter, and the expected response
## must then fail.

const THEME := "concrete_facility"
## The room's numbers, where the scenario's callers have always read them.
const ROOM_HALF := UnweightedSwitchRoom.ROOM_HALF
const ROOM_HEIGHT := UnweightedSwitchRoom.ROOM_HEIGHT
const SLAB := UnweightedSwitchRoom.SLAB
const SILL_Y := UnweightedSwitchRoom.SILL_Y
const DOOR_HALF := UnweightedSwitchRoom.DOOR_HALF
const NORTH_Z := UnweightedSwitchRoom.NORTH_Z
const PLATE := UnweightedSwitchRoom.PLATE
const RECESS_Z := UnweightedSwitchRoom.RECESS_Z
const CRATE := UnweightedSwitchRoom.CRATE
const CRATE_KG := UnweightedSwitchRoom.CRATE_KG
const PARK_Z := UnweightedSwitchRoom.PARK_Z
const LIGHTENED_SECONDS := UnweightedSwitchRoom.LIGHTENED_SECONDS
const LIGHTENED_MAGNITUDE := UnweightedSwitchRoom.LIGHTENED_MAGNITUDE
const DRIVE_SPEED := UnweightedSwitchRoom.DRIVE_SPEED
const STEP_RISE := UnweightedSwitchRoom.STEP_RISE
const RETURN_X := UnweightedSwitchRoom.RETURN_X

var room: UnweightedSwitchRoom = null
var plate: ClassPlate = null
var shutter: ServiceShutter = null
var crate: ManipulableBody = null
var applicator: ActivityElement = null
var bolt: CallLever = null
var drive: CallLever = null
var goal_plate: ActivityElement = null
var player: Player = null
var hud: Hud = null

var disconnected := false
var bolted: bool:
	get:
		return room != null and room.bolted
var reached_goal: bool:
	get:
		return room != null and room.reached_goal

var _readout: Label3D = null


func _ready() -> void:
	name = "UnweightedSwitch"
	_environment()
	room = UnweightedSwitchRoom.new()
	room.name = "Chamber"
	room.theme = THEME
	room.disconnected = disconnected
	room.build()
	add_child(room)
	plate = room.plate
	shutter = room.shutter
	crate = room.crate
	applicator = room.applicator
	bolt = room.bolt
	drive = room.drive
	goal_plate = room.goal_plate
	room.said.connect(_say)
	_readout = _sign("", Vector3(0.0, 3.1, -ROOM_HALF.y + 1.0),
			Color(0.7, 1.0, 0.8), 32)
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


## THE GUIDE TRACK RUNS ON THE SCENARIO'S CLOCK, as it always has: a
## caller that stops this node's physics processing stops the drive.
func _physics_process(delta: float) -> void:
	if room != null:
		room.step(delta)


func drive_goal_z() -> float:
	return room.drive_goal_z()


func return_stair_steps() -> int:
	return room.return_stair_steps()


## The top face of the crate right now -- the surface a player stands on.
func crate_top() -> float:
	return crate.global_position.y + CRATE.y * 0.5


## Is the crate in the recess, on the plate?
func crate_is_placed() -> bool:
	return room.crate_is_placed()


func _say(text: String) -> void:
	if _readout != null:
		_readout.text = text


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


func _sign(text: String, where: Vector3, tint: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	add_child(label)
	label.position = where
	return label
