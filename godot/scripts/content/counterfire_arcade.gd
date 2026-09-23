class_name CounterfireArcade
extends Node3D
## EX50-021 COUNTERFIRE ARCADE, PLAYABLE (`--counterfire`).
## **Development scaffolding, and a minor situation, not a Zone.**
##
## **What the room asks.** An emergency impact trip stands at the south
## end of a long firing lane, hooded against the side you arrive from.
## A gunner covers the lane from the north gallery. Stand in the lane,
## let it commit a shot, and step aside: the projectile carries on down
## the lane you vacated and trips the receiver, which opens a service
## shutter for eight seconds.
##
## **Nothing here recognises "baited".** There is no enemy state, no
## scripted miss and no quick-time prompt. The gunner aims at a visible
## player with its ordinary attack; the projectile's direction is fixed
## at the muzzle; the receiver is operated by a real impact on a real
## plate. The player's contribution is entirely where they were standing
## and where they went.
##
## **And the ordinary route is not a consolation prize.** The west stair
## reaches the gallery through open ground, and from the gunner's side
## the receiver's face is addressable by an ordinary Static Pulse. §6
## requires that: killing the gunner must never remove the only way to
## finish the room. What the bait buys is not access, it is not having to
## stand in the firing line with your back to the gunner.
##
## **The specification is `docs/design-library/EX50_entries/EX50-021.md`
## and it is paper.** Its projectile speed, its eight seconds and its
## encounter layout are proposals. §11's "actual fairness of the bait
## remains unverified" is still true after this file: what
## `godot-counterfire` measures is that the relationship works, not that
## it is fun.
##
## **THE ROOM ITSELF IS `CounterfireArcadeRoom`** (O05-06.3). This
## scenario owns one at the origin, with its own gunner, and adds what
## only a development launcher has: a sky, a spawned player, a HUD and a
## readout. A composed Zone hosts the same room through
## `CounterfireArcadeHosted`, whose gunner is the Zone's own enemy.
##
## **What this is NOT.** Not composed, no Checks, no exit, no campaign,
## no save, no bridge connection. An operator asks for it by name or it
## does not exist.

const THEME := "concrete_facility"
## The room's numbers, where the scenario's callers have always read them.
const ROOM_HALF := CounterfireArcadeRoom.ROOM_HALF
const ROOM_HEIGHT := CounterfireArcadeRoom.ROOM_HEIGHT
const SLAB := CounterfireArcadeRoom.SLAB
const LANE_HALF := CounterfireArcadeRoom.LANE_HALF
const GALLERY_Y := CounterfireArcadeRoom.GALLERY_Y
const GUNNER := CounterfireArcadeRoom.GUNNER
const GALLERY_SOUTH := CounterfireArcadeRoom.GALLERY_SOUTH
const STANCE := CounterfireArcadeRoom.STANCE
const RECEIVER_Z := CounterfireArcadeRoom.RECEIVER_Z
const RECEIVER_Y := CounterfireArcadeRoom.RECEIVER_Y
const ALCOVE := CounterfireArcadeRoom.ALCOVE
const ALCOVE_X := CounterfireArcadeRoom.ALCOVE_X
const ALCOVE_Z := CounterfireArcadeRoom.ALCOVE_Z
const SHUTTER_X := CounterfireArcadeRoom.SHUTTER_X
const SHUTTER_Z := CounterfireArcadeRoom.SHUTTER_Z
const SHUTTER := CounterfireArcadeRoom.SHUTTER
const OPEN_SECONDS := CounterfireArcadeRoom.OPEN_SECONDS
const FLANK_Y := CounterfireArcadeRoom.FLANK_Y
const ANNEX_X := CounterfireArcadeRoom.ANNEX_X
const STEP_RISE := CounterfireArcadeRoom.STEP_RISE

var room: CounterfireArcadeRoom = null
var player: Player = null
var hud: Hud = null

## `--blocked` is §11's counterpart: a real blocker between the muzzle
## and the receiver. Everything else about the room is identical.
var blocked := false

var receiver: ImpactReceiver:
	get:
		return room.receiver if room != null else null
var shutter: ServiceShutter:
	get:
		return room.shutter if room != null else null
## Settable, because a suite removes the gunner to prove the room does
## not need it (§6).
var gunner: Enemy:
	get:
		return room.gunner if room != null else null
	set(value):
		if room != null:
			room.gunner = value
var release: CallLever:
	get:
		return room.release if room != null else null
var goal_plate: ActivityElement:
	get:
		return room.goal_plate if room != null else null
var released: bool:
	get:
		return room != null and room.released
var reached_goal: bool:
	get:
		return room != null and room.reached_goal

var _readout: Label3D = null


func _ready() -> void:
	name = "CounterfireArcade"
	_environment()
	room = CounterfireArcadeRoom.new()
	room.name = "Arcade"
	room.theme = THEME
	room.blocked = blocked
	room.build()
	add_child(room)
	room.said.connect(_say)
	_readout = _sign("", Vector3(0.0, 2.8, -ROOM_HALF.y + 1.0),
			Color(0.7, 1.0, 0.8), 34)
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


## The release, as the room receives it -- for a suite that pulls it
## without a hand on the lever.
func _on_release(who: CallLever) -> void:
	room._on_release(who)


func muzzle() -> Vector3:
	return room.muzzle()


func shot_height_at_receiver(at: Vector3) -> float:
	return room.shot_height_at_receiver(at)


func _say(text: String) -> void:
	if _readout != null:
		_readout.text = text


func _spawn_player() -> void:
	player = Player.create()
	add_child(player)
	player.set_spawn(Transform3D(Basis(Vector3.UP, 0.0),
			Vector3(3.0, 1.2, -ROOM_HALF.y + 1.4)))
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
