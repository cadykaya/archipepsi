class_name ImpactLabRoom
extends Node3D
## THE IMPACT LAB: an intentionally plain technical fixture for the G0
## question "can power, a movement device and a breakable meet in one real
## physical interaction?" (post-D playtest plan, Prod P0.2). It is NOT the
## designed room -- that is Dess's brief and Arty's kit -- and it carries
## no enemies.
##
## One hall. A kit lever powers, through the kit's raceway, an object plate
## (`ImpactLabParts.ObjectPlate`) whose arc ends in a rated impact shutter
## (`ImpactLabParts.ImpactShutter`) sealing a doorway in the north wall. A
## glass window beside the doorway shows what is behind it: a stand-in
## reward that sends nothing. A carryable weight starts on the floor.
##
## Recovery is part of the fixture: a weight that leaves the hall or falls
## under the floor comes back to where it started, so no throw can strand
## the only weight.

const P := preload("res://scripts/content/crossing_d_parts.gd")
const L := preload("res://scripts/content/impact_lab_parts.gd")
const THEME := "concrete_facility"
const WALL := 0.5
const HALL := Rect2(-10.0, -12.0, 20.0, 22.0)
const HALL_HEIGHT := 8.0
const DOOR_X := Vector2(-1.5, 1.5)
const DOOR_TOP := 3.0
const BACK := Rect2(-6.0, -18.0, 14.0, 5.5)
const BACK_HEIGHT := 4.0
const WINDOW_X := Vector2(3.0, 7.0)
const WINDOW_Y := Vector2(1.0, 3.4)
const PLATE_AT := Vector3(0.0, 0.0, -1.0)
const LEVER_AT := Vector3(-4.0, 1.0, 3.0)
const WEIGHT_HOME := Vector3(6.0, 0.3, 4.0)
const WEIGHT_KG := 36.0
const WEIGHT_SIZE := Vector3(0.45, 0.6, 0.45)
const REWARD_AT := Vector3(0.0, 0.0, -16.0)
const FLIGHT_SECONDS := 1.0

signal said(text: String)
signal stand_in_found(id: String)

var lever: P.Lever
var plate: L.ObjectPlate
var shutter: L.ImpactShutter
var weight: ManipulableBody
var reward: P.StandIn
var powered := false
var shutter_broken := false
var respawns := 0
## The last blow the shutter took (kept here: a broken shutter is freed).
var last_impact := {}
var _lines := {}


func build() -> void:
	_hall()
	_back_room()
	_devices()
	for at in [Vector3(-5, 7, 4), Vector3(5, 7, 4), Vector3(0, 7, -6),
			Vector3(0, 3.5, -15)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_energy = 1.0
		light.omni_range = 16.0
		light.light_color = Color(0.86, 0.9, 0.95)
		add_child(light)
	P.plain_sign(self, "IMPACT LAB · TECHNICAL FIXTURE",
			Vector3(0, 4.6, HALL.end.y - 0.6), 26)


func _mat(kind: String) -> Material:
	match kind:
		"wall":
			return ThemeMaterials.wall_mat(THEME)
		"trim":
			return ThemeMaterials.trim_mat(THEME)
		"glass":
			return ThemeMaterials.glass_material(Color(0.62, 0.8, 0.9, 0.28))
	return ThemeMaterials.floor_mat(THEME)


func _block(label: String, lo: Vector3, hi: Vector3, kind := "wall") -> void:
	var made := ChamberBuilders._box(self, hi - lo, (lo + hi) * 0.5,
			_mat(kind))
	made.name = label


func _hall() -> void:
	var x0 := HALL.position.x
	var z0 := HALL.position.y
	var x1 := HALL.end.x
	var z1 := HALL.end.y
	_block("Floor", Vector3(x0 - WALL, -0.5, z0 - WALL),
			Vector3(x1 + WALL, 0.0, z1 + WALL), "floor")
	_block("Roof", Vector3(x0 - WALL, HALL_HEIGHT, z0 - WALL),
			Vector3(x1 + WALL, HALL_HEIGHT + 0.5, z1 + WALL), "trim")
	_block("WestWall", Vector3(x0 - WALL, 0, z0), Vector3(x0, HALL_HEIGHT, z1))
	_block("EastWall", Vector3(x1, 0, z0), Vector3(x1 + WALL, HALL_HEIGHT, z1))
	_block("SouthWall", Vector3(x0 - WALL, 0, z1),
			Vector3(x1 + WALL, HALL_HEIGHT, z1 + WALL))
	# The north wall, with the doorway and the window cut out of it.
	var n0 := z0 - WALL
	_block("North_W", Vector3(x0 - WALL, 0, n0), Vector3(DOOR_X.x, HALL_HEIGHT, z0))
	_block("North_DoorHead", Vector3(DOOR_X.x, DOOR_TOP, n0),
			Vector3(DOOR_X.y, HALL_HEIGHT, z0))
	_block("North_Mid", Vector3(DOOR_X.y, 0, n0), Vector3(WINDOW_X.x, HALL_HEIGHT, z0))
	_block("North_Sill", Vector3(WINDOW_X.x, 0, n0), Vector3(WINDOW_X.y, WINDOW_Y.x, z0))
	_block("North_Head", Vector3(WINDOW_X.x, WINDOW_Y.y, n0),
			Vector3(WINDOW_X.y, HALL_HEIGHT, z0))
	_block("North_E", Vector3(WINDOW_X.y, 0, n0), Vector3(x1 + WALL, HALL_HEIGHT, z0))
	_block("Window", Vector3(WINDOW_X.x, WINDOW_Y.x, n0 + 0.2),
			Vector3(WINDOW_X.y, WINDOW_Y.y, z0 - 0.2), "glass")


func _back_room() -> void:
	var x0 := BACK.position.x
	var z0 := BACK.position.y
	var x1 := BACK.end.x
	var z1 := HALL.position.y - WALL
	_block("BackFloor", Vector3(x0 - WALL, -0.5, z0 - WALL), Vector3(x1 + WALL, 0, z1))
	_block("BackRoof", Vector3(x0 - WALL, BACK_HEIGHT, z0 - WALL),
			Vector3(x1 + WALL, BACK_HEIGHT + 0.5, z1))
	_block("BackWest", Vector3(x0 - WALL, 0, z0), Vector3(x0, BACK_HEIGHT, z1))
	_block("BackEast", Vector3(x1, 0, z0), Vector3(x1 + WALL, BACK_HEIGHT, z1))
	_block("BackNorth", Vector3(x0 - WALL, 0, z0 - WALL), Vector3(x1 + WALL, BACK_HEIGHT, z0))
	reward = P.StandIn.make("impact_lab_reward", "reward", THEME)
	reward.position = REWARD_AT
	add_child(reward)
	reward.found.connect(func(id: String) -> void: stand_in_found.emit(id))


func _devices() -> void:
	# THE PLATE, throwing north, its arc ending in the shutter's face.
	plate = L.ObjectPlate.new()
	plate.name = "ObjectPlate"
	plate.position = PLATE_AT
	add_child(plate)
	var shutter_at := Vector3(0, DOOR_TOP * 0.5, HALL.position.y - WALL * 0.5)
	plate.flight_seconds = FLIGHT_SECONDS
	plate.target = shutter_at + Vector3(0, 0, WALL * 0.5)
	plate.build(plate.target - plate.global_position)
	plate.fired.connect(func(_b: ManipulableBody, _v: Vector3) -> void:
		said.emit(""))
	plate.dud.connect(func(_b: ManipulableBody) -> void:
		said.emit("The plate clicks. Nothing happens."))
	_build_shutter()
	# THE LEVER AND ITS LINE: the kit lever, its raceway out of the rear
	# gland and into the plate's west face, lit only once it is thrown.
	lever = P.Lever.mounted("POWER THE PLATE", P.POWER, THEME)
	lever.position = LEVER_AT
	add_child(lever)
	P.cap_emission(lever)
	lever.pulled.connect(_on_lever)
	var gland := lever.gland()
	_lines["plate"] = P.raceway(self, "plate", [gland,
			Vector3(gland.x, 0.0, PLATE_AT.z),
			Vector3(PLATE_AT.x - L.ObjectPlate.SIZE.x * 0.5, 0.0, PLATE_AT.z)],
			[Vector3.UP, Vector3.UP], "gland", "face")
	weight = ManipulableBody.create("lab_weight", WEIGHT_KG, WEIGHT_SIZE)
	weight.carriable = true
	ImpactLabParts.box(weight, "Look", Vector3.ZERO, WEIGHT_SIZE,
			ThemeMaterials.trim_mat(THEME))
	P.strip(weight, "Band", Vector3.ZERO, Vector3(WEIGHT_SIZE.x + 0.02, 0.1,
			WEIGHT_SIZE.z + 0.02), P.NEUTRAL, 0.15)
	add_child(weight)
	weight.global_position = WEIGHT_HOME


func _build_shutter() -> void:
	shutter = L.ImpactShutter.new()
	shutter.name = "ImpactShutter"
	shutter.size = Vector3(DOOR_X.y - DOOR_X.x, DOOR_TOP, 0.4)
	shutter.normal = Vector3.BACK
	shutter.position = Vector3(0, DOOR_TOP * 0.5, HALL.position.y - WALL * 0.5)
	add_child(shutter)
	shutter.build()
	shutter_broken = false
	shutter.broken.connect(func(_at: Vector3) -> void:
		shutter_broken = true
		said.emit("The shutter gives way."))
	shutter.struck.connect(func(_amount: float, accepted: bool,
			source: Node3D) -> void:
		if source != null:
			last_impact = shutter.last_impact.duplicate()
		if not accepted:
			said.emit("NEEDS A HEAVIER HIT"))


func _on_lever(_l: CallLever) -> void:
	if powered:
		return
	powered = true
	lever.lock("PLATE POWERED")
	plate.set_powered(true)
	P.conduit_power(_lines["plate"], true)


func line_live() -> bool:
	return bool((_lines["plate"] as Node).get_meta("live", false))


## RECOVERY: a weight out of the hall, or under its floor, comes home.
func _physics_process(_delta: float) -> void:
	if weight == null or not is_instance_valid(weight) \
			or weight.carried_by != null:
		return
	var at := weight.global_position
	var inside := at.y > -2.0 and at.x > HALL.position.x - 1.0 \
			and at.x < HALL.end.x + 1.0 and at.z < HALL.end.y + 1.0 \
			and at.z > BACK.position.y - 1.0
	if not inside:
		respawn_weight()


func respawn_weight() -> void:
	respawns += 1
	weight.linear_velocity = Vector3.ZERO
	weight.angular_velocity = Vector3.ZERO
	weight.global_transform = Transform3D(Basis.IDENTITY, WEIGHT_HOME)
	weight.sleeping = false
	said.emit("The weight is back where it started.")


## FOR THE MEASUREMENT ONLY: a fresh shutter, and the weight set down at
## rest on the plate at `offset` from its centre, turned by `yaw`.
func reset_trial(offset: Vector3, yaw: float) -> void:
	last_impact = {}
	if shutter != null and is_instance_valid(shutter):
		shutter.queue_free()
	_build_shutter()
	var top := plate.global_position.y + L.ObjectPlate.SIZE.y \
			+ WEIGHT_SIZE.y * 0.5 + 0.01
	weight.linear_velocity = Vector3.ZERO
	weight.angular_velocity = Vector3.ZERO
	weight.continuous_cd = false
	weight.global_transform = Transform3D(Basis(Vector3.UP, yaw),
			plate.global_position + Vector3(offset.x, top, offset.z))
	weight.sleeping = false
