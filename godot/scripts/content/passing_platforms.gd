class_name PassingPlatforms
extends Node3D
## EX50-011 PASSING PLATFORMS, PLAYABLE (`--passing-platforms`).
## **Development scaffolding, and a minor situation, not a Zone.**
##
## **What the room asks.** Two carriers, two journeys, one meeting. A
## lift `V` rises from the arrival floor `A` to an upper shelf and pauses
## on the way at the transfer height. A shuttle `H` crosses the room at
## that height and ends at the goal gallery `G`. Neither reaches `G`
## alone: `V` goes up past it and `H` starts across the room. The player
## decides when to start each so that one is beside the other, steps
## across, and is carried on.
##
## **The specification is `docs/design-library/EX50_entries/EX50-011.md`
## and it is paper.** It is recorded byte-for-byte and it is a proposal:
## the numbers below (speeds, the 2.5 s dwell, the 9 m run-up) are its
## numbers, and everything this file claims about how they FEEL is
## unverified. What `godot-passing-platforms` measures is narrower and
## stated there.
##
## **THE ROOM ITSELF IS `PassingPlatformsRoom`** (O05-06.2). This
## scenario owns one at the origin and adds what only a development
## launcher has: a sky, a spawned player and a HUD. A composed Zone hosts
## the same room through `PassingPlatformsHosted`.
##
## **What this is NOT.** Not composed, no Checks, no exit, no Archipelago
## logic, no campaign, no save. It runs before `boot()` and opens no
## bridge connection, exactly as `RailwayScenario` does, and for the same
## reason: an operator asks for it by name or it does not exist.
##
## **`--parted` is the counterexample, not a variant.** EX50-011 §11
## requires that a room whose tracks do not pass be unable to report the
## same commanded timing successful. `--parted` shifts `H`'s track north
## by `PARTED_SHIFT` and changes nothing else, so a positive run that
## also passes there was measuring its own commands rather than the
## world.

const THEME := "concrete_facility"
## The room's numbers, where the scenario's callers have always read them.
const ROOM_HALF := PassingPlatformsRoom.ROOM_HALF
const ROOM_HEIGHT := PassingPlatformsRoom.ROOM_HEIGHT
const TRANSFER_Y := PassingPlatformsRoom.TRANSFER_Y
const SHELF_Y := PassingPlatformsRoom.SHELF_Y
const RECOVERY_Y := PassingPlatformsRoom.RECOVERY_Y
const DECK := PassingPlatformsRoom.DECK
const SLAB := PassingPlatformsRoom.SLAB
const A_NORTH := PassingPlatformsRoom.A_NORTH
const V_X := PassingPlatformsRoom.V_X
const V_Z := PassingPlatformsRoom.V_Z
const GAP := PassingPlatformsRoom.GAP
const H_Z := PassingPlatformsRoom.H_Z
const H_RAIL_Y := PassingPlatformsRoom.H_RAIL_Y
const H_WEST_X := PassingPlatformsRoom.H_WEST_X
const H_EAST_X := PassingPlatformsRoom.H_EAST_X
const PARTED_SHIFT := PassingPlatformsRoom.PARTED_SHIFT
const G_WEST := PassingPlatformsRoom.G_WEST
const SHELF_EAST := PassingPlatformsRoom.SHELF_EAST
const SHELF_WEST := PassingPlatformsRoom.SHELF_WEST
const SHELF_Z := PassingPlatformsRoom.SHELF_Z
const RAIL_HEIGHT := PassingPlatformsRoom.RAIL_HEIGHT
const RAIL_THICK := PassingPlatformsRoom.RAIL_THICK
const STEP_RISE := PassingPlatformsRoom.STEP_RISE
const V_ARRIVAL := PassingPlatformsRoom.V_ARRIVAL
const V_TRANSFER := PassingPlatformsRoom.V_TRANSFER
const V_SHELF := PassingPlatformsRoom.V_SHELF
const V_DWELL := PassingPlatformsRoom.V_DWELL
const H_WEST := PassingPlatformsRoom.H_WEST
const H_EAST := PassingPlatformsRoom.H_EAST

var room: PassingPlatformsRoom = null
var player: Player = null
var hud: Hud = null
## The counterexample. Set before the scenario enters the tree.
var parted := false

var v: ShuttleDeck:
	get:
		return room.v if room != null else null
var h: RailCarrier:
	get:
		return room.h if room != null else null
var rail: RailPath:
	get:
		return room.rail if room != null else null
var levers: Dictionary:
	get:
		return room.levers if room != null else {}
var goal_plate: ActivityElement:
	get:
		return room.goal_plate if room != null else null
## Settable, because a suite marks the stair released to prove a reset
## leaves it alone (§8).
var stair_released: bool:
	get:
		return room != null and room.stair_released
	set(value):
		if room != null:
			room.stair_released = value
var reached_g: bool:
	get:
		return room != null and room.reached_g


func _ready() -> void:
	name = "PassingPlatforms"
	_environment()
	room = PassingPlatformsRoom.new()
	room.name = "Chamber"
	room.theme = THEME
	room.parted = parted
	room.build()
	add_child(room)
	_spawn_player()
	_hud()


func _environment() -> void:
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(THEME)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = ThemeMaterials.void_color(THEME).lightened(0.1)
	env.fog_density = 0.004
	holder.environment = env
	add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(24.0), 0.0)
	sun.light_energy = 0.9
	add_child(sun)


## §8's local reset, as the room issues it.
func reset_carriers() -> void:
	room.reset_carriers()


func rendezvous_offset() -> float:
	return room.rendezvous_offset()


func transfer_gap() -> float:
	return room.transfer_gap()


func v_top() -> float:
	return room.v_top()


func h_top() -> float:
	return room.h_top()


func h_span() -> Vector2:
	return room.h_span()


func _spawn_player() -> void:
	player = Player.create()
	add_child(player)
	# Standing on `A`, south of `V`, facing the lift and the room beyond.
	player.set_spawn(Transform3D(Basis(Vector3.UP, 0.0),
			Vector3(V_X, 1.2, V_Z - 6.0)))
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
