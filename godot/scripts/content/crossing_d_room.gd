class_name CrossingDRoom
extends Node3D
## CROSSING D, THE FOUR ROOMS (review build).
##
## Built to Dess's room brief D-17 (`docs/D17_CROSSING_D_ROOM_BRIEF.md`,
## a266d5da): four rooms around one landmark, each budgeted around one
## activity, joined by short connectors, every wing returning to the
## Central Hall by its own shortcut.
##
## - **Central Hall** (arrive, orient, return): the lift tower, dark,
##   with the exit's beacon at its head and a green line from its base
##   into the Machine Hall; a wide opening onto the Courtyard; a closed
##   glass door into the Machine Hall; the Upper Yard's gated stair.
##   Nothing to do here.
## - **Courtyard** (movement): launch pads and a spring up the walls to a
##   balcony and its Check; swing plates for the faster line; an overlook
##   only the swing reaches; the rail back down into the hall.
## - **Machine Hall** (puzzle): a cell in a low hatch; a plate that holds
##   a lift-bridge down; a far lever that locks it; a socket that powers
##   the glass door and the tower lift.
## - **Upper Yard** (the one fight): at most three roster enemies at
##   baseline numbers; cover at two heights and orange crates that break;
##   the exit across it; a gate to the stair down, opened from the yard.
##
## Every piece is an existing one -- `LaunchPad`, `BouncePad`, the rail
## sweep, `ClassPlate`, `ManipulableBody` and the hand, `Actuator`,
## `ServiceShutter`, `CallLever`, `ObjectSocket`, `DestructibleCover`,
## `Enemy` -- placed and wired; nothing here is a new mechanic. Checks are
## stand-ins that send nothing (`CrossingDParts.StandIn`).
##
## World coordinates: x east, z south, y up; the hall's floor is y = 0.

signal said(text: String)
signal power_restored
signal yard_cleared
signal exit_used
signal stand_in_found(id: String)

const P := preload("res://scripts/content/crossing_d_parts.gd")
const THEME := "concrete_facility"
const WALL := 0.5

# ---------------------------------------------------------------- the hall
const HALL := Rect2(-12.0, -12.0, 24.0, 24.0)       # x, z, width, depth
const HALL_CEILING := 16.0
const ARRIVAL := Rect2(-9.5, 12.0, 5.0, 8.0)
const ARRIVAL_CEILING := 3.5
const SPAWN := Vector3(-7.0, 1.1, 18.5)
## The lift shaft and its cage. The cage is a 0.3 m slab, a step up from
## the hall's floor and a step down to the yard's.
const SHAFT := Rect2(-9.0, -12.0, 4.0, 4.0)
const CAGE_BOTTOM := Vector3(-7.0, 0.15, -10.0)
const CAGE_TOP := Vector3(-7.0, 9.15, -10.0)
const LIFT_SECONDS := 6.0
## How long a rider stands in the cage, or a caller at a landing, before
## the lift answers: long enough not to fire on a player walking past.
const RIDE_BEAT := 1.0
const CALL_BEAT := 0.6
const TOWER_HEAD := 14.0
## The glass door from the Machine Hall's far side, in the hall's west
## wall, and the open way in from the hall to its near side.
const GLASS_DOOR_Z := Vector2(-8.5, -4.5)
const MACHINE_WAY_Z := Vector2(5.0, 9.0)
## The wide opening onto the Courtyard, in the hall's east wall.
const COURTYARD_WAY_Z := Vector2(-6.0, 8.0)
const COURTYARD_WAY_TOP := 12.0
## The Upper Yard's stair: its gate in the hall's north wall at the yard's
## height, two flights' worth of treads down to the hall's floor.
const STAIR_TOP_X := 9.5
const STAIR_FOOT_X := -2.4
const STAIR_Z := Vector2(-12.0, -9.5)
const STAIR_RISE := 0.25

# ----------------------------------------------------------- the courtyard
const COURT := Rect2(12.0, -16.0, 32.0, 28.0)
const COURT_CEILING := 18.0
const LEDGE_1 := AABB(Vector3(22.0, 0.0, 6.0), Vector3(14.0, 3.5, 6.0))
const LEDGE_2 := AABB(Vector3(37.0, 0.0, 2.0), Vector3(7.0, 6.5, 10.0))
const BALCONY := AABB(Vector3(37.0, 8.9, -12.0), Vector3(7.0, 0.6, 11.0))
## The overlook: a solid block in the north-west corner, 14 m high. The
## swing reaches its top by riding up its face; nothing else does.
const OVERLOOK := AABB(Vector3(12.5, 0.0, -16.0), Vector3(6.5, 14.0, 5.0))
const PAD_1 := Vector3(17.0, 0.0, 9.0)
const PAD_1_TARGET := Vector3(26.0, 3.5, 9.0)
const SPRING_1 := Vector3(34.0, 3.5, 9.0)
const PAD_2 := Vector3(40.5, 6.5, 4.5)
const PAD_2_TARGET := Vector3(40.5, 9.5, -5.5)
## Two for the faster line across the middle; the third hangs over the
## overlook, which nothing else reaches.
const SWING_PLATES := [Vector3(25.0, 15.0, -1.0), Vector3(33.5, 15.0, -5.0),
		Vector3(15.75, 17.2, -13.5)]
const RAIL_POINTS := [Vector3(38.0, 10.6, -2.2), Vector3(33.0, 9.7, 1.8),
		Vector3(25.0, 7.6, 3.2), Vector3(17.5, 5.3, 2.2),
		Vector3(12.0, 3.9, 1.0), Vector3(6.0, 2.6, -0.2),
		Vector3(1.5, 2.1, -1.0)]
const COURT_CHECK := Vector3(42.0, 9.5, -9.5)
const OVERLOOK_REWARD := Vector3(14.5, 14.0, -14.0)
const YARD_WINDOW_Z := Vector2(-15.5, -12.5)
const YARD_WINDOW_Y := Vector2(14.6, 17.4)

# -------------------------------------------------------- the machine hall
const MACHINE := Rect2(-34.0, -18.0, 22.0, 32.0)
const MACHINE_CEILING := 9.0
const GAP_Z := Vector2(-4.0, 4.0)
const PIT_FLOOR := -4.5
const BRIDGE_X := Vector2(-24.0, -20.0)
const BRIDGE_RAISE := 3.5
const BRIDGE_SECONDS := 2.5
const HATCH_X := Vector2(-30.0, -26.5)
const HATCH_TOP := 1.4
const HATCH_DEPTH := 2.4
const CELL_SIZE := Vector3(0.45, 0.6, 0.45)
const CELL_KG := 18.0
const CELL_AT := Vector3(-28.25, 0.3, 14.85)
const PLATE_AT := Vector3(-17.0, 0.06, 6.5)
const LOCK_LEVER_AT := Vector3(-17.5, 1.0, -6.5)
const SOCKET_AT := Vector3(-15.0, 0.0, -10.5)
const MACHINE_CHECK := Vector3(-27.0, 0.0, -11.0)

# ---------------------------------------------------------- the upper yard
## 24 x 30 m: deep enough that the roster's own patrol beats (4.5 m round
## each post) keep the walkers past their 18 m notice from the alcove.
const YARD := Rect2(-12.0, -42.0, 24.0, 30.0)
const YARD_FLOOR := 9.0
const YARD_CEILING := 19.0
const ALCOVE := Rect2(-9.6, -16.4, 5.2, 3.9)
const ALCOVE_TOP := 12.6
const ALCOVE_WAY_Z := Vector2(-16.0, -13.2)
const SILL := 0.4
## Taller than the ranged role's muzzle on the post (12 m + 1.29 m).
const HIGH_COVER := 4.5
const POST := AABB(Vector3(-12.0, 9.0, -42.0), Vector3(7.0, 3.0, 7.0))
const RAMP_Z := Vector2(-21.0, -35.0)
const GATE_X := Vector2(9.5, 12.0)
const GATE_LEVER_AT := Vector3(8.4, 10.0, -13.6)
const EXIT_WAY_X := Vector2(6.0, 10.0)
const EXIT_AT := Vector3(8.0, 9.0, -46.0)
const YARD_CHECK := Vector3(0.0, 9.0, -40.0)
## At most three, from roles verified in this yard (`CrossingDCheck`):
## one ranged on the raised post, one melee and one charger on the floor.
## Baseline HP and damage: nothing here touches `ENEMY_STATS`.
const ENCOUNTER := [
	{"kind": "ranged", "at": Vector3(-5.8, 12.0, -35.8)},
	{"kind": "melee", "at": Vector3(4.0, 9.0, -37.5)},
	{"kind": "charger", "at": Vector3(0.0, 9.0, -39.0)},
]

var theme := THEME
## False for the empty yard (`--empty-yard`): the same rooms, no enemies.
var populated := true

var lift: Actuator
var cage: AnimatableBody3D
## Presence, not levers (D-17: nothing to do in the hall): the cage, and
## each landing in front of its door.
var cage_sensor: Area3D
var landing_sensors: Array[Area3D] = []
var lift_door_bottom: ServiceShutter
var lift_door_top: ServiceShutter
var glass_door: ServiceShutter
var bridge: Actuator
var bridge_body: AnimatableBody3D
var plate: ClassPlate
var cell: ManipulableBody
var socket: P.CellSocket
var lock_lever: P.Lever
var gate: ServiceShutter
var gate_lever: P.Lever
var exit_door: P.ExitDoor
var yard_case: Node3D
var pads: Array = []
var springs: Array = []
var rail := {}
var swing_plates: Array[Node3D] = []
var stand_ins := {}
var enemies: Array[Enemy] = []
var covers: Array = []
## Every footprint in the yard a player can stand behind: the high and
## low cover, the crates, the case, the alcove and the post.
var cover_boxes: Array[AABB] = []

var powered := false
var bridge_locked := false
var cleared := false
var _lift_goal := 0
var _ride_armed := true
var _ride_wait := 0.0
var _call_wait := [0.0, 0.0]
var _told_unpowered := false
var _hall_lights: Array[OmniLight3D] = []
var _beacon: OmniLight3D
var _badges := {}
var _lines := {}
var _signs := {}


func build() -> void:
	name = "CrossingD"
	_hall()
	_tower()
	_yard_stair()
	_courtyard()
	_machine_hall()
	_upper_yard()
	_wire()


# ================================================================ builders

func _mat(kind: String) -> Material:
	match kind:
		"wall":
			return ThemeMaterials.wall_mat(theme)
		"trim":
			return ThemeMaterials.trim_mat(theme)
		"accent":
			return ThemeMaterials.accent_mat(theme)
		"glass":
			return ThemeMaterials.glass_material(Color(0.62, 0.8, 0.9, 0.28))
	return ThemeMaterials.floor_mat(theme)


## A solid box between two corners.
func _block(label: String, lo: Vector3, hi: Vector3, kind := "floor",
		collide := true) -> MeshInstance3D:
	var made := ChamberBuilders._box(self, hi - lo, (lo + hi) * 0.5,
			_mat(kind), collide)
	made.name = label
	return made


## A wall along x (constant z) from x0 to x1, y0 to y1, centred on `z`.
func _wall_x(label: String, z: float, x0: float, x1: float, y0: float,
		y1: float, kind := "wall") -> void:
	_block(label, Vector3(x0, y0, z - WALL * 0.5),
			Vector3(x1, y1, z + WALL * 0.5), kind)


## A wall along z (constant x).
func _wall_z(label: String, x: float, z0: float, z1: float, y0: float,
		y1: float, kind := "wall") -> void:
	_block(label, Vector3(x - WALL * 0.5, y0, z0),
			Vector3(x + WALL * 0.5, y1, z1), kind)


func _light(at: Vector3, energy := 1.0, reach := 14.0,
		tint := Color(0.86, 0.9, 0.95)) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	add_child(light)
	return light


func _sign(key: String, text: String, at: Vector3, size := 26,
		tint := P.NEUTRAL) -> Label3D:
	var made := P.plain_sign(self, text, at, size, tint)
	made.name = "Sign_" + key
	_signs[key] = made
	return made


func sign_text(key: String) -> String:
	return (_signs[key] as Label3D).text if _signs.has(key) else ""


## Treads from `foot` up to `head`, each a solid block to the floor below
## it (the scenario rooms' stair, `CounterfireArcadeRoom._stair`).
func _stair(label: String, foot: Vector3, head: Vector3, width: float,
		kind := "trim") -> void:
	var rise := head.y - foot.y
	var run := Vector3(head.x - foot.x, 0.0, head.z - foot.z)
	var steps := maxi(int(ceil(rise / STAIR_RISE)), 1)
	var out := run.normalized()
	var tread := run.length() / float(steps)
	for i in steps:
		var height := float(i + 1) * rise / float(steps)
		var here := foot + out * (tread * (float(i) + 0.5)) \
				+ Vector3(0.0, height * 0.5, 0.0)
		var step := ChamberBuilders._box(self,
				Vector3(width, height, tread + 0.01), here, _mat(kind))
		step.name = label
		step.basis = Basis.looking_at(-out, Vector3.UP)


## A slab whose top runs straight from `low` to `high`, `width` across.
func _ramp(label: String, low: Vector3, high: Vector3, width: float) -> void:
	var along := high - low
	var basis := Basis.looking_at(along.normalized(), Vector3.UP)
	var thickness := 0.5
	var up := basis.y
	var made := ChamberBuilders._box(self,
			Vector3(width, thickness, along.length()),
			(low + high) * 0.5 - up * thickness * 0.5, _mat("trim"))
	made.name = label
	made.basis = basis


# ================================================================ the hall

func _hall() -> void:
	var x0 := HALL.position.x
	var z0 := HALL.position.y
	var x1 := HALL.end.x
	var z1 := HALL.end.y
	_block("HallFloor", Vector3(x0, -0.6, z0), Vector3(x1, 0.0, z1))
	_block("HallCeiling", Vector3(x0 - WALL, HALL_CEILING, z0 - WALL),
			Vector3(x1 + WALL, HALL_CEILING + 0.5, z1 + WALL), "trim")
	# South: the arrival's mouth.
	var ax0 := ARRIVAL.position.x
	var ax1 := ARRIVAL.end.x
	_wall_x("HallSouth", z1 + WALL * 0.5, x0 - WALL, ax0, 0.0, HALL_CEILING)
	_wall_x("HallSouth", z1 + WALL * 0.5, ax1, x1 + WALL, 0.0, HALL_CEILING)
	_wall_x("HallSouthLintel", z1 + WALL * 0.5, ax0, ax1, ARRIVAL_CEILING,
			HALL_CEILING)
	# West: the Machine Hall's open way, and the glass door.
	var wx := x0 - WALL * 0.5
	_wall_z("HallWest", wx, z0 - WALL, GLASS_DOOR_Z.x, 0.0, HALL_CEILING)
	_wall_z("HallWest", wx, GLASS_DOOR_Z.y, MACHINE_WAY_Z.x, 0.0, HALL_CEILING)
	_wall_z("HallWest", wx, MACHINE_WAY_Z.y, z1 + WALL, 0.0, HALL_CEILING)
	_wall_z("GlassDoorLintel", wx, GLASS_DOOR_Z.x, GLASS_DOOR_Z.y, 3.6,
			HALL_CEILING)
	_wall_z("MachineWayLintel", wx, MACHINE_WAY_Z.x, MACHINE_WAY_Z.y, 4.0,
			HALL_CEILING)
	# East: the wide opening onto the Courtyard.
	var ex := x1 + WALL * 0.5
	_wall_z("HallEast", ex, z0 - WALL, COURTYARD_WAY_Z.x, 0.0, HALL_CEILING)
	_wall_z("HallEast", ex, COURTYARD_WAY_Z.y, z1 + WALL, 0.0, HALL_CEILING)
	_wall_z("CourtyardWayLintel", ex, COURTYARD_WAY_Z.x, COURTYARD_WAY_Z.y,
			COURTYARD_WAY_TOP, HALL_CEILING)
	# North: the lift's head opening onto the yard's alcove, and the gate.
	var nz := z0 - WALL * 0.5
	_wall_x("HallNorth", nz, x0 - WALL, SHAFT.position.x, 0.0, HALL_CEILING)
	_wall_x("HallNorth", nz, SHAFT.end.x, GATE_X.x, 0.0, HALL_CEILING)
	_wall_x("LiftHeadBelow", nz, SHAFT.position.x, SHAFT.end.x, 0.0,
			YARD_FLOOR + 0.3)
	_wall_x("LiftHeadAbove", nz, SHAFT.position.x, SHAFT.end.x,
			ALCOVE_TOP - 0.1, HALL_CEILING)
	_wall_x("GateBelow", nz, GATE_X.x, GATE_X.y, 0.0, YARD_FLOOR)
	_wall_x("GateAbove", nz, GATE_X.x, GATE_X.y, YARD_FLOOR + SILL + 3.6,
			HALL_CEILING)
	# The sill under the gate keeps the yard's walkers in the yard; a
	# player walks over it (`MAX_VERTICAL_STEP`).
	_block("GateSill", Vector3(GATE_X.x, YARD_FLOOR, z0 - WALL),
			Vector3(GATE_X.y, YARD_FLOOR + SILL, z0), "trim")
	# The arrival: a low corridor, so the hall opens up on entry.
	var az1 := ARRIVAL.end.y
	_block("ArrivalFloor", Vector3(ax0, -0.6, z1), Vector3(ax1, 0.0, az1))
	_block("ArrivalCeiling", Vector3(ax0 - WALL, ARRIVAL_CEILING, z1),
			Vector3(ax1 + WALL, ARRIVAL_CEILING + 0.4, az1 + WALL), "trim")
	_wall_z("ArrivalWest", ax0 - WALL * 0.5, z1, az1 + WALL, 0.0,
			ARRIVAL_CEILING)
	_wall_z("ArrivalEast", ax1 + WALL * 0.5, z1, az1 + WALL, 0.0,
			ARRIVAL_CEILING)
	_wall_x("ArrivalBack", az1 + WALL * 0.5, ax0, ax1, 0.0, ARRIVAL_CEILING)
	_light(Vector3(-7.0, 3.0, 16.0), 0.6, 7.0)
	# Restrained until the power comes back: the payoff is the hall
	# lighting up as you return.
	for at in [Vector3(-6.0, 11.0, 6.0), Vector3(6.0, 11.0, 6.0),
			Vector3(6.0, 11.0, -6.0), Vector3(-2.0, 7.0, -4.0)]:
		_hall_lights.append(_light(at, 0.55, 15.0))
	_sign("to_machine", "MACHINE HALL", Vector3(-11.4, 4.8, 7.0), 30)
	_sign("to_courtyard", "COURTYARD", Vector3(11.4, 6.5, 1.0), 30)


# =============================================================== the tower

func _tower() -> void:
	var sx0 := SHAFT.position.x
	var sx1 := SHAFT.end.x
	var sz1 := SHAFT.end.y
	var front := sz1 + 0.2
	var head := TOWER_HEAD
	# Two solid sides, a glass front above the door so the cage is seen
	# going up, and the head the beacon stands on.
	_block("ShaftWest", Vector3(sx0 - 0.4, 0.0, HALL.position.y),
			Vector3(sx0, head, front + 0.2), "trim")
	_block("ShaftEast", Vector3(sx1, 0.0, HALL.position.y),
			Vector3(sx1 + 0.4, head, front + 0.2), "trim")
	_block("ShaftFrontGlass", Vector3(sx0, 3.4, front - 0.1),
			Vector3(sx1, head - 0.6, front + 0.1), "glass")
	_block("ShaftFrontLintel", Vector3(sx0, 3.2, front - 0.2),
			Vector3(sx1, 3.4, front + 0.2), "trim")
	_block("TowerHead", Vector3(sx0 - 0.6, head - 0.6, HALL.position.y),
			Vector3(sx1 + 0.6, head, front + 0.6), "trim")
	_block("ShaftPit", Vector3(sx0, -0.6, SHAFT.position.y),
			Vector3(sx1, 0.0, sz1), "floor")
	# THE CAGE: a slab and a frame, carried by a LIFT actuator.
	cage = AnimatableBody3D.new()
	cage.name = "LiftCage"
	cage.sync_to_physics = true
	var hull := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(SHAFT.size.x - 0.1, 0.3, SHAFT.size.y - 0.1)
	hull.shape = slab
	cage.add_child(hull)
	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = slab.size
	deck.mesh = deck_mesh
	deck.material_override = _mat("accent")
	cage.add_child(deck)
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.12, 2.6, 0.12)
			post.mesh = post_mesh
			post.position = Vector3(x, 1.45, z)
			post.material_override = _mat("trim")
			cage.add_child(post)
	var lamp_bar := P.strip(cage, "CageLamp", Vector3(0, 2.7, 0),
			Vector3(3.7, 0.08, 3.7), P.POWER_IDLE, 0.05)
	lamp_bar.set_meta("cage_lamp", true)
	add_child(cage)
	cage.position = CAGE_BOTTOM
	var path: Array[Transform3D] = [Transform3D(Basis.IDENTITY, CAGE_BOTTOM),
			Transform3D(Basis.IDENTITY, CAGE_TOP)]
	lift = Actuator.create("LIFT", path, LIFT_SECONDS)
	lift.driven = cage
	lift.powered = false
	add_child(lift)
	# NO LEVERS IN THE HALL (D-17 keeps them out of it): the lift answers
	# to presence. Step into the powered cage and it rides after a beat;
	# wait at a landing and it comes for you.
	cage_sensor = _sensor(cage, Vector3(0, 1.3, 0), Vector3(3.4, 2.2, 3.4))
	# Doors: each landing's opens only while the cage stands at it.
	lift_door_bottom = ServiceShutter.create(
			Vector3((sx0 + sx1) * 0.5, 1.6, front),
			Vector3(SHAFT.size.x, 3.2, 0.3), 3.1, theme)
	lift_door_bottom.name = "LiftDoorBottom"
	lift_door_bottom.panel_material = _mat("trim")
	add_child(lift_door_bottom)
	lift_door_bottom.settle(true)
	lift_door_top = ServiceShutter.create(
			Vector3((sx0 + sx1) * 0.5, YARD_FLOOR + 0.3 + 1.6,
				HALL.position.y - WALL * 0.5),
			Vector3(SHAFT.size.x, 3.2, 0.3), 3.1, theme)
	lift_door_top.name = "LiftDoorTop"
	lift_door_top.panel_material = _mat("trim")
	add_child(lift_door_top)
	landing_sensors.append(_sensor(self, Vector3((sx0 + sx1) * 0.5, 1.2,
			front + 1.3), Vector3(SHAFT.size.x, 2.4, 2.0)))
	landing_sensors.append(_sensor(self, Vector3((sx0 + sx1) * 0.5,
			YARD_FLOOR + 1.2, HALL.position.y - WALL - 1.2),
			Vector3(SHAFT.size.x, 2.4, 2.0)))
	_badges["lift"] = P.power_badge(self,
			Vector3((sx0 + sx1) * 0.5, 3.75, front + 0.35), false, "LIFT")
	_sign("lift", "LIFT — NO POWER", Vector3((sx0 + sx1) * 0.5, 5.0,
			front + 0.4), 30)
	_sign("exit_up", "EXIT",
			Vector3((sx0 + sx1) * 0.5, head + 1.3, front + 0.4), 30,
			Color(0.6, 1.0, 0.7))
	_beacon = _light(Vector3((sx0 + sx1) * 0.5, head + 0.8, front + 0.8),
			1.2, 9.0, Color(0.6, 1.0, 0.7))


# ========================================================= the yard stair

func _yard_stair() -> void:
	var zs := STAIR_Z
	var width := zs.y - zs.x
	# The landing behind the gate, at the yard's height.
	_block("StairLanding", Vector3(STAIR_TOP_X, 0.0, zs.x),
			Vector3(HALL.end.x, YARD_FLOOR, zs.y), "trim")
	_stair("YardStair", Vector3(STAIR_FOOT_X, 0.0, (zs.x + zs.y) * 0.5),
			Vector3(STAIR_TOP_X, YARD_FLOOR, (zs.x + zs.y) * 0.5), width)
	gate = ServiceShutter.create(
			Vector3((GATE_X.x + GATE_X.y) * 0.5, YARD_FLOOR + SILL + 1.8,
				HALL.position.y - WALL * 0.5),
			Vector3(GATE_X.y - GATE_X.x, 3.6, 0.36), 3.5, theme)
	gate.name = "YardGate"
	gate.panel_material = _mat("trim")
	add_child(gate)
	# Its state on both faces of the wall it is set in.
	_badges["gate"] = P.power_badge(self, Vector3(GATE_X.x - 0.5,
			YARD_FLOOR + 3.4, HALL.position.y - WALL - 0.2), false, "GATE")
	_badges["gate_hall"] = P.power_badge(self, Vector3(GATE_X.x - 0.5,
			YARD_FLOOR + 3.4, HALL.position.y + 0.25), false, "GATE")


# =========================================================== the courtyard

func _courtyard() -> void:
	var x0 := COURT.position.x
	var z0 := COURT.position.y
	var x1 := COURT.end.x
	var z1 := COURT.end.y
	var top := COURT_CEILING
	_block("CourtFloor", Vector3(x0, -0.6, z0), Vector3(x1, 0.0, z1))
	_block("CourtCeiling", Vector3(x0, top, z0 - WALL),
			Vector3(x1 + WALL, top + 0.5, z1 + WALL), "trim")
	_wall_z("CourtEast", x1 + WALL * 0.5, z0 - WALL, z1 + WALL, 0.0, top)
	_wall_x("CourtSouth", z1 + WALL * 0.5, HALL.end.x + WALL, x1 + WALL,
			0.0, top)
	_wall_x("CourtNorth", z0 - WALL * 0.5, HALL.end.x, x1 + WALL, 0.0,
			YARD_CEILING)
	# The hall's east wall stops at its own ceiling; the courtyard's is
	# higher, and its north-west bay shares a wall with the yard.
	_wall_z("CourtWestHigh", HALL.end.x + WALL * 0.5, HALL.position.y,
			z1, HALL_CEILING, top)
	var wx := HALL.end.x + WALL * 0.5
	var wz := YARD_WINDOW_Z
	var wy := YARD_WINDOW_Y
	_wall_z("YardShared", wx, z0, wz.x, 0.0, YARD_CEILING)
	_wall_z("YardShared", wx, wz.y, HALL.position.y, 0.0, YARD_CEILING)
	_wall_z("YardSharedBelow", wx, wz.x, wz.y, 0.0, wy.x)
	_wall_z("YardSharedAbove", wx, wz.x, wz.y, wy.y, YARD_CEILING)
	_block("YardWindow", Vector3(wx - 0.08, wy.x, wz.x),
			Vector3(wx + 0.08, wy.y, wz.y), "glass")
	# The climb: two ledges, a balcony, the overlook.
	_block("Ledge1", LEDGE_1.position, LEDGE_1.end, "trim")
	_block("Ledge2", LEDGE_2.position, LEDGE_2.end, "trim")
	_block("Balcony", BALCONY.position, BALCONY.end, "trim")
	for z in [-11.0, -6.5, -2.0]:
		_block("BalconyPost", Vector3(BALCONY.position.x + 0.3, 0.0, z - 0.3),
				Vector3(BALCONY.position.x + 0.9, BALCONY.position.y, z + 0.3),
				"trim")
	_block("Overlook", OVERLOOK.position, OVERLOOK.end, "wall")
	# BLUE: everything that moves you. Pads, the spring, the swing plates
	# and the rail -- and nothing else in the Crossing.
	_pad(PAD_1, PAD_1_TARGET)
	_pad(PAD_2, PAD_2_TARGET)
	var spring := AffordanceNodes.BouncePad.new()
	spring.name = "Spring"
	spring.position = SPRING_1
	spring.tint = P.MOVEMENT
	add_child(spring)
	P.retint(spring, P.MOVEMENT, 0.7)
	springs.append(spring)
	for i in SWING_PLATES.size():
		swing_plates.append(_swing_plate("SwingPlate%d" % (i + 1),
				SWING_PLATES[i]))
	var points := PackedVector3Array()
	for at: Vector3 in RAIL_POINTS:
		points.append(at)
	rail = AffordanceFeatures.build_rail(self, RailPath.from_points(points))
	for beam: Node in rail.get("beams", []):
		P.retint(beam, P.MOVEMENT, 0.8)
	var court_check := P.StandIn.make("courtyard_balcony", "check", theme)
	court_check.position = COURT_CHECK
	add_child(court_check)
	stand_ins[court_check.id] = court_check
	var reward := P.StandIn.make("courtyard_overlook", "local", theme)
	reward.position = OVERLOOK_REWARD
	add_child(reward)
	stand_ins[reward.id] = reward
	_sign("pad", "LAUNCH PAD — STEP ON", PAD_1 + Vector3(0, 2.4, 0), 22,
			P.MOVEMENT.lightened(0.35))
	_sign("spring", "SPRING — STEP ON", SPRING_1 + Vector3(0, 2.4, 0), 22,
			P.MOVEMENT.lightened(0.35))
	_sign("rail", "RAIL — WALK ONTO IT, DOWN TO THE HALL",
			Vector3(37.5, 12.4, -2.4), 22, P.MOVEMENT.lightened(0.35))
	_sign("swing", "SWING PLATES — JUMP, THEN HOLD RMB",
			Vector3(24.0, 12.0, -1.0), 22, P.MOVEMENT.lightened(0.35))
	_sign("overlook", "VIEW OF THE UPPER YARD",
			Vector3(15.5, 16.4, -12.0), 20)
	for at in [Vector3(20.0, 14.0, 6.0), Vector3(34.0, 14.0, 4.0),
			Vector3(40.0, 14.0, -8.0), Vector3(22.0, 14.0, -10.0)]:
		_light(at, 0.9, 18.0)


func _pad(at: Vector3, target: Vector3) -> void:
	var pad := AffordanceNodes.LaunchPad.new()
	pad.name = "LaunchPad"
	pad.position = at
	pad.target = target
	pad.tint = P.MOVEMENT
	add_child(pad)
	P.cap_emission(pad, 0.7)
	pads.append(pad)


## A SWING PLATE: a blue-faced plate hung from the ceiling on a rod --
## where the faster line means you to swing from. (The tether itself
## catches any solid surface; the plates are the authored line.)
func _swing_plate(label: String, at: Vector3) -> Node3D:
	var plate_node := _block(label, at - Vector3(1.2, 0.25, 1.2),
			at + Vector3(1.2, 0.25, 1.2), "trim")
	P.strip(self, label + "Face", at - Vector3(0, 0.27, 0),
			Vector3(2.0, 0.05, 2.0), P.MOVEMENT, 0.6)
	_block(label + "Rod", Vector3(at.x - 0.12, at.y + 0.25, at.z - 0.12),
			Vector3(at.x + 0.12, COURT_CEILING, at.z + 0.12), "trim", false)
	return plate_node


# ======================================================== the machine hall

func _machine_hall() -> void:
	var x0 := MACHINE.position.x
	var z0 := MACHINE.position.y
	var x1 := MACHINE.end.x
	var z1 := MACHINE.end.y
	var hx := HALL.position.x - WALL
	var top := MACHINE_CEILING
	# Near side (south), the gap, far side (north). The floors are solid
	# down to the pit so the gap has walls.
	_block("MachineNear", Vector3(x0, PIT_FLOOR, GAP_Z.y),
			Vector3(hx, 0.0, z1))
	_block("MachineFar", Vector3(x0, PIT_FLOOR, z0), Vector3(hx, 0.0, GAP_Z.x))
	_block("PitFloor", Vector3(x0, PIT_FLOOR - 0.6, GAP_Z.x),
			Vector3(hx, PIT_FLOOR, GAP_Z.y))
	_block("PitEast", Vector3(hx, PIT_FLOOR - 0.6, GAP_Z.x),
			Vector3(HALL.position.x, 0.0, GAP_Z.y), "wall")
	# A missed step is a climb back, not a dead end: the pit's stair
	# returns to the NEAR side only.
	_stair("PitStair", Vector3(x0 + 1.5, PIT_FLOOR, GAP_Z.x + 0.4),
			Vector3(x0 + 1.5, 0.0, GAP_Z.y), 3.0)
	_block("MachineCeiling", Vector3(x0 - WALL, top, z0 - WALL),
			Vector3(hx, top + 0.5, z1 + WALL), "trim")
	_wall_z("MachineWest", x0 - WALL * 0.5, z0 - WALL, z1 + WALL,
			PIT_FLOOR - 0.6, top)
	_wall_x("MachineNorth", z0 - WALL * 0.5, x0 - WALL, hx, 0.0, top)
	# The hall's west wall is this room's east wall; past the hall's ends
	# it continues on its own.
	_wall_z("MachineEast", HALL.position.x - WALL * 0.5, z0 - WALL,
			HALL.position.y - WALL, 0.0, top)
	_wall_z("MachineEast", HALL.position.x - WALL * 0.5, HALL.end.y + WALL,
			z1 + WALL, 0.0, top)
	# South: the low hatch the cell sits in -- too low to enter, near
	# enough for the hand.
	var hz := z1 + WALL * 0.5
	_wall_x("MachineSouth", hz, x0 - WALL, HATCH_X.x, 0.0, top)
	_wall_x("MachineSouth", hz, HATCH_X.y, hx, 0.0, top)
	_wall_x("HatchLintel", hz, HATCH_X.x, HATCH_X.y, HATCH_TOP, top)
	_block("HatchFloor", Vector3(HATCH_X.x - 0.4, -0.6, z1),
			Vector3(HATCH_X.y + 0.4, 0.0, z1 + HATCH_DEPTH + 0.4))
	_block("HatchRoof", Vector3(HATCH_X.x - 0.4, HATCH_TOP, z1),
			Vector3(HATCH_X.y + 0.4, HATCH_TOP + 0.4, z1 + HATCH_DEPTH + 0.4),
			"trim")
	_block("HatchWest", Vector3(HATCH_X.x - 0.4, 0.0, z1),
			Vector3(HATCH_X.x, HATCH_TOP, z1 + HATCH_DEPTH), "trim")
	_block("HatchEast", Vector3(HATCH_X.y, 0.0, z1),
			Vector3(HATCH_X.y + 0.4, HATCH_TOP, z1 + HATCH_DEPTH), "trim")
	_block("HatchBack", Vector3(HATCH_X.x - 0.4, 0.0, z1 + HATCH_DEPTH),
			Vector3(HATCH_X.y + 0.4, HATCH_TOP, z1 + HATCH_DEPTH + 0.4),
			"trim")
	# THE CELL: a mass input, so neutral (Wisp's ruling, Dess's brief).
	cell = ManipulableBody.create("power_cell", CELL_KG, CELL_SIZE)
	cell.carriable = true
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = CELL_SIZE
	body.mesh = body_mesh
	body.material_override = _mat("trim")
	cell.add_child(body)
	P.strip(cell, "Band", Vector3.ZERO, Vector3(CELL_SIZE.x + 0.02, 0.1,
			CELL_SIZE.z + 0.02), P.NEUTRAL, 0.15)
	add_child(cell)
	cell.position = CELL_AT
	# THE PLATE: it needs an object, not you.
	plate = ClassPlate.create(Vector3(2.4, 0.12, 2.4), MassClass.LIGHT,
			theme, false)
	plate.position = PLATE_AT
	add_child(plate)
	_badges["plate"] = P.power_badge(plate, Vector3(-0.7, 0.2, -0.85), false,
			"PLATE")
	_paint_plate(false)
	# THE LIFT-BRIDGE: down while the plate holds or the lock keeps it,
	# up otherwise. Up means 3.5 m over the gap -- out of a jump's reach.
	bridge_body = AnimatableBody3D.new()
	bridge_body.name = "LiftBridge"
	bridge_body.sync_to_physics = true
	var bridge_size := Vector3(BRIDGE_X.y - BRIDGE_X.x, 0.5, GAP_Z.y - GAP_Z.x)
	var bridge_hull := CollisionShape3D.new()
	var bridge_box := BoxShape3D.new()
	bridge_box.size = bridge_size
	bridge_hull.shape = bridge_box
	bridge_body.add_child(bridge_hull)
	var bridge_mesh := MeshInstance3D.new()
	var bridge_block := BoxMesh.new()
	bridge_block.size = bridge_size
	bridge_mesh.mesh = bridge_block
	bridge_mesh.material_override = _mat("accent")
	bridge_body.add_child(bridge_mesh)
	add_child(bridge_body)
	var bx := (BRIDGE_X.x + BRIDGE_X.y) * 0.5
	var lowered := Vector3(bx, -0.25, (GAP_Z.x + GAP_Z.y) * 0.5)
	var raised := lowered + Vector3(0, BRIDGE_RAISE, 0)
	bridge_body.position = raised
	var bridge_path: Array[Transform3D] = [
			Transform3D(Basis.IDENTITY, raised),
			Transform3D(Basis.IDENTITY, lowered)]
	bridge = Actuator.create("BRIDGE", bridge_path, BRIDGE_SECONDS)
	bridge.driven = bridge_body
	add_child(bridge)
	_badges["bridge"] = P.power_badge(bridge_body,
			Vector3(0, 0.55, bridge_size.z * 0.5 - 0.4), false, "BRIDGE")
	# The bridge's two housings: the plate's line ends at the near one,
	# the lock lever's at the far one.
	_block("BridgeHousingNear", Vector3(BRIDGE_X.y + 0.2, 0.0, GAP_Z.y + 0.2),
			Vector3(BRIDGE_X.y + 1.0, 0.7, GAP_Z.y + 1.0), "trim")
	_block("BridgeHousingFar", Vector3(BRIDGE_X.y + 0.2, 0.0, GAP_Z.x - 1.0),
			Vector3(BRIDGE_X.y + 1.0, 0.7, GAP_Z.x - 0.2), "trim")
	# THE LOCK: on the far side, wired to the far housing.
	lock_lever = P.Lever.mounted("LOCK THE BRIDGE DOWN", P.POWER, theme)
	lock_lever.position = LOCK_LEVER_AT
	add_child(lock_lever)
	P.cap_emission(lock_lever)
	# THE SOCKET: powers the glass door and the tower lift.
	socket = P.CellSocket.made("lift_power", cell, theme)
	socket.position = SOCKET_AT
	add_child(socket)
	# The glass door: the far side's way straight back into the hall.
	glass_door = ServiceShutter.create(
			Vector3(HALL.position.x - WALL * 0.5, 1.8,
				(GLASS_DOOR_Z.x + GLASS_DOOR_Z.y) * 0.5),
			Vector3(GLASS_DOOR_Z.y - GLASS_DOOR_Z.x, 3.6, 0.3), 3.6, theme)
	glass_door.name = "GlassDoor"
	glass_door.rotation.y = PI * 0.5
	glass_door.panel_material = _mat("glass")
	add_child(glass_door)
	_badges["glass_door"] = P.power_badge(self, Vector3(HALL.position.x
			- WALL - 0.25, 4.3, GLASS_DOOR_Z.x - 0.9), false, "DOOR")
	_badges["glass_door_hall"] = P.power_badge(self, Vector3(
			HALL.position.x + 0.25, 4.3, GLASS_DOOR_Z.y + 0.5), false, "DOOR")
	var machine_check := P.StandIn.make("machine_far_ledge", "check", theme)
	machine_check.position = MACHINE_CHECK
	add_child(machine_check)
	stand_ins[machine_check.id] = machine_check
	# THE LINES, every one wired to what drives it.
	_lines["plate"] = P.conduit(self, "plate", [
			PLATE_AT + Vector3(-1.25, 0.06, 0.0), Vector3(-19.6, 0.12, 6.5),
			Vector3(-19.6, 0.12, GAP_Z.y + 0.6)],
			[Vector3.UP, Vector3.UP])
	_lines["lock"] = P.conduit(self, "lock", [
			LOCK_LEVER_AT + Vector3(0.0, -0.88, 0.4), Vector3(-17.5, 0.12, -4.6),
			Vector3(-19.6, 0.12, -4.6)],
			[Vector3.UP, Vector3.UP])
	var door_x := HALL.position.x - WALL - 0.12
	_lines["power"] = P.conduit(self, "power", [
			SOCKET_AT + Vector3(0.45, 0.12, 0.0),
			Vector3(door_x, 0.12, SOCKET_AT.z),
			Vector3(door_x, 0.12, GLASS_DOOR_Z.x - 0.4),
			Vector3(door_x, 4.0, GLASS_DOOR_Z.x - 0.4)],
			[Vector3.UP, Vector3.UP, Vector3.LEFT])
	# ...through the wall, and across the hall's floor to the lift's base.
	var hall_x := HALL.position.x + 0.12
	_lines["power_hall"] = P.conduit(self, "power_hall", [
			Vector3(hall_x, 4.0, GLASS_DOOR_Z.x - 0.4),
			Vector3(hall_x, 0.12, GLASS_DOOR_Z.x - 0.4),
			Vector3(hall_x, 0.12, SHAFT.end.y + 0.6),
			Vector3(SHAFT.position.x - 0.5, 0.12, SHAFT.end.y + 0.6)],
			[Vector3.RIGHT, Vector3.UP, Vector3.UP])
	_sign("hatch", "TOO LOW TO ENTER — REACH IN WITH E",
			Vector3((HATCH_X.x + HATCH_X.y) * 0.5, 2.3, z1 - 0.6), 22)
	_sign("plate", "A WEIGHT ON THE PLATE HOLDS THE BRIDGE DOWN",
			PLATE_AT + Vector3(0, 2.6, 0), 22, P.POWER.lightened(0.3))
	_sign("lock", "THIS LEVER LOCKS THE BRIDGE DOWN",
			LOCK_LEVER_AT + Vector3(0, 1.7, 0), 22, P.POWER.lightened(0.3))
	_sign("socket", "SOCKET — POWERS THE GLASS DOOR AND THE LIFT",
			SOCKET_AT + Vector3(0, 2.4, 0), 22, P.POWER.lightened(0.3))
	for at in [Vector3(-23.0, 7.5, 9.0), Vector3(-23.0, 7.5, -1.0),
			Vector3(-23.0, 7.5, -11.0), Vector3(-15.0, 6.0, -9.0)]:
		_light(at, 0.85, 14.0)


# =========================================================== the upper yard

func _upper_yard() -> void:
	var x0 := YARD.position.x
	var z0 := YARD.position.y
	var x1 := YARD.end.x
	var z1 := YARD.end.y
	var hall_north := HALL.position.y - WALL
	var floor_y := YARD_FLOOR
	var top := YARD_CEILING
	_block("YardFloor", Vector3(x0, floor_y - 0.6, z0), Vector3(x1, floor_y,
			hall_north))
	_block("YardCeiling", Vector3(x0 - WALL, top, z0 - WALL),
			Vector3(x1 + WALL, top + 0.5, HALL.position.y), "trim")
	_wall_z("YardWest", x0 - WALL * 0.5, z0 - WALL, HALL.position.y,
			floor_y - 0.6, top)
	_wall_z("YardEast", x1 + WALL * 0.5, z0 - WALL, COURT.position.y,
			floor_y - 0.6, top)
	# North: the exit's way, with a sill.
	_wall_x("YardNorth", z0 - WALL * 0.5, x0 - WALL, EXIT_WAY_X.x,
			floor_y, top)
	_wall_x("YardNorth", z0 - WALL * 0.5, EXIT_WAY_X.y, x1 + WALL,
			floor_y, top)
	_wall_x("ExitLintel", z0 - WALL * 0.5, EXIT_WAY_X.x, EXIT_WAY_X.y,
			floor_y + 3.8, top)
	_block("ExitSill", Vector3(EXIT_WAY_X.x, floor_y, z0 - WALL),
			Vector3(EXIT_WAY_X.y, floor_y + SILL, z0), "trim")
	# The hall's north wall stops at its ceiling; the yard's south wall
	# goes on up.
	_wall_x("YardSouthHigh", HALL.position.y - WALL * 0.5, x0 - WALL,
			x1 + WALL, HALL_CEILING, top)
	# The exit room, past the sill.
	var ez0 := z0 - WALL - 5.0
	_block("ExitRoomFloor", Vector3(EXIT_WAY_X.x - 0.5, floor_y - 0.6, ez0),
			Vector3(EXIT_WAY_X.y + 0.5, floor_y, z0 - WALL))
	_block("ExitRoomRoof", Vector3(EXIT_WAY_X.x - 1.0, floor_y + 4.6, ez0 - 0.5),
			Vector3(EXIT_WAY_X.y + 1.0, floor_y + 5.0, z0 - WALL), "trim")
	_wall_z("ExitRoomWest", EXIT_WAY_X.x - 0.75, ez0 - 0.5, z0 - WALL,
			floor_y, floor_y + 4.6)
	_wall_z("ExitRoomEast", EXIT_WAY_X.y + 0.75, ez0 - 0.5, z0 - WALL,
			floor_y, floor_y + 4.6)
	_wall_x("ExitRoomBack", ez0 - 0.25, EXIT_WAY_X.x - 1.0,
			EXIT_WAY_X.y + 1.0, floor_y, floor_y + 4.6)
	exit_door = P.ExitDoor.make(theme)
	exit_door.position = EXIT_AT
	add_child(exit_door)
	# THE ALCOVE: where the lift opens. Roofed, glazed to the north so the
	# fight can be read before it starts, its way out to the east over a
	# sill the yard's walkers cannot climb.
	var ax0 := ALCOVE.position.x
	var ax1 := ALCOVE.end.x
	var az0 := ALCOVE.position.y
	var az1 := hall_north
	# Solid from the yard's own west wall: no dead-end slot beside the
	# alcove for a shot to graze into.
	_block("AlcoveWest", Vector3(x0, floor_y, az0 - 0.4),
			Vector3(ax0, ALCOVE_TOP, az1), "wall")
	_block("AlcoveEastNorth", Vector3(ax1, floor_y, az0 - 0.4),
			Vector3(ax1 + 0.4, ALCOVE_TOP, ALCOVE_WAY_Z.x), "wall")
	_block("AlcoveEastSouth", Vector3(ax1, floor_y, ALCOVE_WAY_Z.y),
			Vector3(ax1 + 0.4, ALCOVE_TOP, az1), "wall")
	_block("AlcoveSill", Vector3(ax1, floor_y, ALCOVE_WAY_Z.x),
			Vector3(ax1 + 0.4, floor_y + SILL, ALCOVE_WAY_Z.y), "trim")
	_block("AlcoveKerb", Vector3(ax0, floor_y, az0 - 0.4),
			Vector3(ax1, floor_y + 0.9, az0), "wall")
	_block("AlcoveWindow", Vector3(ax0, floor_y + 0.9, az0 - 0.3),
			Vector3(ax1, ALCOVE_TOP, az0 - 0.1), "glass")
	_block("AlcoveRoof", Vector3(ax0 - 0.4, ALCOVE_TOP, az0 - 0.4),
			Vector3(ax1 + 0.4, ALCOVE_TOP + 0.4, az1), "trim")
	# THE RAISED POST, and the ramp up to it: a ramp, not a stair, because
	# the fight depends on that height (the brief; no stair-climbing melee
	# has been verified).
	_block("Post", POST.position, POST.end, "trim")
	_ramp("PostRamp", Vector3(x0 + 1.5, floor_y, RAMP_Z.x),
			Vector3(x0 + 1.5, POST.end.y, RAMP_Z.y), 3.0)
	# COVER AT TWO HEIGHTS, and orange crates that break. The high cover
	# stands taller than the ranged role's muzzle on the post, so no shot
	# skims its top: the role either has a clear line past it or none.
	for spec in [[Vector3(-7.0, 0, -23.5), Vector3(3.2, HIGH_COVER, 0.6)],
			[Vector3(-2.5, 0, -30.0), Vector3(0.6, HIGH_COVER, 3.2)]]:
		var at: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		var high := AABB(Vector3(at.x - size.x * 0.5, floor_y,
				at.z - size.z * 0.5), size)
		_block("HighCover", high.position, high.end, "wall")
		cover_boxes.append(high)
	for spec in [[Vector3(5.0, 0, -21.0), Vector3(3.2, 1.1, 0.6)],
			[Vector3(8.5, 0, -29.0), Vector3(3.2, 1.1, 0.6)]]:
		var at: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		var low := AABB(Vector3(at.x - size.x * 0.5, floor_y,
				at.z - size.z * 0.5), size)
		_block("LowCover", low.position, low.end, "wall")
		cover_boxes.append(low)
	for at in [Vector3(1.5, floor_y + 0.7, -24.5),
			Vector3(6.0, floor_y + 0.7, -34.0),
			Vector3(-0.5, floor_y + 0.7, -32.5)]:
		var crate := DestructibleCover.create(theme)
		crate.position = at
		add_child(crate)
		_paint_breakable(crate)
		covers.append(crate)
		cover_boxes.append(AABB(at - DestructibleCover.SIZE * 0.5,
				DestructibleCover.SIZE))
	# THE CHECK, in a glass case that opens once the yard is clear.
	var yard_check := P.StandIn.make("upper_yard", "check", theme)
	yard_check.position = YARD_CHECK
	add_child(yard_check)
	stand_ins[yard_check.id] = yard_check
	yard_case = Node3D.new()
	yard_case.name = "YardCase"
	add_child(yard_case)
	var case_glass := ChamberBuilders._box(yard_case, Vector3(1.6, 2.6, 1.6),
			YARD_CHECK + Vector3(0, 1.3, 0), _mat("glass"))
	case_glass.name = "CaseGlass"
	cover_boxes.append(AABB(YARD_CHECK - Vector3(0.8, 0, 0.8),
			Vector3(1.6, 2.6, 1.6)))
	# The alcove and the post are cover too, for anyone beside them.
	cover_boxes.append(AABB(Vector3(x0, floor_y, az0 - 0.4),
			Vector3(ax1 + 0.4 - x0, ALCOVE_TOP - floor_y, az1 - az0 + 0.4)))
	cover_boxes.append(POST)
	# The gate lever, on the yard side, wired to the gate.
	gate_lever = P.Lever.mounted("OPEN THE GATE TO THE STAIR", P.POWER, theme)
	gate_lever.position = GATE_LEVER_AT
	add_child(gate_lever)
	P.cap_emission(gate_lever)
	_lines["gate"] = P.conduit(self, "gate", [
			GATE_LEVER_AT + Vector3(0.4, -0.88, 0.0),
			Vector3(9.6, floor_y + 0.12, GATE_LEVER_AT.z),
			Vector3(9.6, floor_y + 0.12, hall_north - 0.12),
			Vector3(9.6, floor_y + 3.0, hall_north - 0.12)],
			[Vector3.UP, Vector3.UP, Vector3.FORWARD])
	_sign("alcove", "UPPER YARD — THE EXIT IS ACROSS IT",
			Vector3((ax0 + ax1) * 0.5, ALCOVE_TOP - 0.7, az0 + 0.6), 22)
	_sign("gate_yard", "GATE LEVER — OPENS THE STAIR TO THE CENTRAL HALL",
			GATE_LEVER_AT + Vector3(0, 1.7, 0), 20, P.POWER.lightened(0.3))
	_sign("yard_check", "OPENS WHEN THE YARD IS CLEAR",
			YARD_CHECK + Vector3(0, 3.2, 0), 20)
	_sign("exit", "EXIT", Vector3((EXIT_WAY_X.x + EXIT_WAY_X.y) * 0.5,
			floor_y + 4.4, z0 + 0.2), 30, Color(0.6, 1.0, 0.7))
	for at in [Vector3(-6.0, 16.0, -21.0), Vector3(6.0, 16.0, -21.0),
			Vector3(-6.0, 16.0, -35.0), Vector3(6.0, 16.0, -35.0)]:
		_light(at, 0.75, 16.0)
	_light(Vector3((ax0 + ax1) * 0.5, ALCOVE_TOP - 0.5, az0 + 1.5), 0.4, 5.0)
	_light(EXIT_AT + Vector3(0, 3.0, 1.5), 0.6, 6.0, Color(0.6, 1.0, 0.7))
	if populated:
		_encounter()


## ORANGE IS FOR WHAT BREAKS: a crate that breaks says so. Through the
## crate's own tint, so its damage shading (darker with each hit) still
## reads -- in orange.
func _paint_breakable(crate: DestructibleCover) -> void:
	crate._tint = P.DESTRUCTIBLE.darkened(0.1)
	crate._mesh.material_override = crate._material(0.0)
	P.strip(crate, "BreakBand", Vector3(0, 0.3, 0),
			Vector3(1.52, 0.14, 0.92), P.DESTRUCTIBLE, 0.35)


func _encounter() -> void:
	for spec: Dictionary in ENCOUNTER:
		var enemy := Enemy.create(str(spec["kind"]), theme)
		add_child(enemy)
		enemy.position = spec["at"]
		enemy.post = spec["at"]
		enemy.job = "watch"
		# Facing the alcove, the way a guard faces the door.
		enemy.rotation.y = atan2(-(-7.0 - (spec["at"] as Vector3).x),
				-(-14.0 - (spec["at"] as Vector3).z))
		enemy.enemy_died.connect(_on_enemy_died)
		enemies.append(enemy)


# ================================================================== wiring

func _wire() -> void:
	plate.occupancy_changed.connect(_on_plate)
	lock_lever.pulled.connect(_on_lock)
	socket.installed.connect(_on_installed)
	gate_lever.pulled.connect(_on_gate)
	lift.stop_reached.connect(_on_lift_stop)
	exit_door.used.connect(func() -> void: exit_used.emit())
	for stand_in: P.StandIn in stand_ins.values():
		stand_in.found.connect(func(id: String) -> void:
				stand_in_found.emit(id))
	(stand_ins["upper_yard"] as P.StandIn).set_available(not populated)
	if not populated:
		yard_case.visible = false
		_drop_case()
	_refresh_bridge()
	_refresh_lift_labels()


func _on_plate(on: bool) -> void:
	_paint_plate(on)
	_refresh_bridge()


## The plate's own lamp says what its line says: green, lit while held.
func _paint_plate(on: bool) -> void:
	if plate._lamp != null:
		plate._lamp.material_override = ThemeMaterials.glow_material(
				P.POWER if on else P.POWER_IDLE, 0.8 if on else 0.15)


func _on_lock(_lever: CallLever) -> void:
	if bridge_locked:
		return
	bridge_locked = true
	lock_lever.lock("BRIDGE LOCKED DOWN")
	_refresh_bridge()
	said.emit("The bridge is locked down.")


func _refresh_bridge() -> void:
	var held := plate.satisfied()
	bridge.set_input(held or bridge_locked)
	P.conduit_power(_lines["plate"], held)
	P.conduit_power(_lines["lock"], bridge_locked)
	P.set_power(_badges["plate"], held)
	P.set_power(_badges["bridge"], held or bridge_locked,
			"BRIDGE LOCKED" if bridge_locked else "BRIDGE")


func _on_installed(_mechanism: String, _object: String) -> void:
	if powered:
		return
	powered = true
	lift.powered = true
	glass_door.command(true)
	for key in ["power", "power_hall"]:
		P.conduit_power(_lines[key], true)
	P.set_power(_badges["glass_door"], true)
	P.set_power(_badges["glass_door_hall"], true)
	P.set_power(_badges["lift"], true)
	for child in cage.get_children():
		if child is MeshInstance3D and child.has_meta("cage_lamp"):
			(child as MeshInstance3D).material_override = \
					ThemeMaterials.glow_material(P.POWER, 0.5)
	for light in _hall_lights:
		light.light_energy = 1.15
	_beacon.light_energy = 2.2
	_refresh_lift_labels()
	said.emit("Power restored: the glass door is open and the lift runs.")
	power_restored.emit()


func _on_gate(_lever: CallLever) -> void:
	if gate_lever.locked:
		return
	gate_lever.lock("GATE OPEN")
	gate.command(true)
	P.conduit_power(_lines["gate"], true)
	P.set_power(_badges["gate"], true)
	P.set_power(_badges["gate_hall"], true)
	said.emit("The gate to the stair is open.")


## LIFT CONTROL, by presence. Without power the cage says so to whoever
## stands in it and nothing moves. With it: a rider who stands a beat in
## the cage is taken to the other landing; a player who waits a beat at a
## landing has the cage brought to them. Both doors shut first, and only
## then does the cage move, so nobody is ever under it or in a doorway it
## leaves; and a rider must step out before it takes them anywhere again.
func _drive_lift(delta: float) -> void:
	var in_cage := _player_in(cage_sensor)
	if not powered:
		if in_cage and not _told_unpowered:
			_told_unpowered = true
			said.emit("The lift has no power. Its line runs to the Machine Hall.")
		elif not in_cage:
			_told_unpowered = false
		return
	var here := lift.at_stop()
	if here >= 0 and _lift_goal != here:
		if lift_door_bottom.is_shut() and lift_door_top.is_shut():
			lift.select(_lift_goal)
		return
	if here < 0:
		return
	if not in_cage:
		_ride_armed = true
		_ride_wait = 0.0
	elif _ride_armed:
		_ride_wait += delta
		if _ride_wait >= RIDE_BEAT:
			_send(1 - here)
			return
	for i in 2:
		if i != here and _player_in(landing_sensors[i]):
			_call_wait[i] += delta
			if _call_wait[i] >= CALL_BEAT:
				_send(i)
				return
		else:
			_call_wait[i] = 0.0


func _send(goal: int) -> void:
	_lift_goal = goal
	_ride_armed = false
	_ride_wait = 0.0
	_call_wait = [0.0, 0.0]
	lift_door_bottom.command(false)
	lift_door_top.command(false)


func _player_in(area: Area3D) -> bool:
	for body in area.get_overlapping_bodies():
		if body is Player:
			return true
	return false


func _sensor(parent: Node3D, at: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = "Presence"
	area.monitoring = true
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
	area.position = at
	return area


func _on_lift_stop(index: int) -> void:
	_open_landing(index)
	_refresh_lift_labels()


func _open_landing(index: int) -> void:
	lift_door_bottom.command(index == 0)
	lift_door_top.command(index == 1)


func _refresh_lift_labels() -> void:
	(_signs["lift"] as Label3D).text = "LIFT — STEP IN TO RIDE" if powered \
			else "LIFT — NO POWER"


func _on_enemy_died(_enemy: Enemy) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() \
				and enemy.hp > 0.0:
			return
	if cleared:
		return
	cleared = true
	_drop_case()
	(stand_ins["upper_yard"] as P.StandIn).set_available(true)
	(_signs["yard_check"] as Label3D).text = "THE YARD IS CLEAR"
	said.emit("The yard is clear. Its Check is open.")
	yard_cleared.emit()


func _drop_case() -> void:
	for child in yard_case.get_children():
		child.queue_free()


func _physics_process(delta: float) -> void:
	_drive_lift(delta)


# ============================================================ for suites

func courtyard_box() -> AABB:
	return AABB(Vector3(COURT.position.x, -1.0, COURT.position.y),
			Vector3(COURT.size.x, COURT_CEILING + 1.0, COURT.size.y))


func yard_box() -> AABB:
	return AABB(Vector3(YARD.position.x, YARD_FLOOR - 0.5, YARD.position.y),
			Vector3(YARD.size.x, YARD_CEILING - YARD_FLOOR + 0.5,
				YARD.size.y))


func line_live(key: String) -> bool:
	return _lines.has(key) and bool((_lines[key] as Node).get_meta("live",
			false))


func badge_on(key: String) -> bool:
	return _badges.has(key) and bool((_badges[key] as Node).get_meta(
			"powered", false))
