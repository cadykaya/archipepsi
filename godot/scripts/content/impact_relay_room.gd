class_name ImpactRelayRoom
extends Node3D
## THE IMPACT RELAY (G1): Dess's approved D-18 v2 (`21cc00a4`), one
## isolated, enemy-free room built on the G0 lab's own pieces --
## `ImpactLabParts.ObjectPlate`, `Flight` and `ImpactShutter`, as measured
## in G0 and unchanged -- in the G0 hall, with the gallery, the vault, the
## loop and the ledge around it.
##
## You arrive on a glass-fronted gallery 4.5 m above the hall's south end.
## Ahead, 18 m off, the north wall's doorway is sealed by an orange-banded
## shutter; beside it a window shows the lit stand-in Check on a low dais.
## Halfway down the hall a blue-trimmed plate faces the shutter with a
## light crate on it; a dark green line runs from it to a lever at the
## stair's foot. To the right, a squat steel weight on its stand.
##
## Axes: x east, z south, y up; the hall floor is y = 0 (D-18 v2 §2.2).
##
## **The route** (walk, carry, interact; no Echo, no ranged hit): down the
## stair; the lever; the crate is thrown and refused; the weight carried
## to the plate and thrown; through the broken doorway to the dais. The
## onward door is in the vault's north wall; a latch inside the vault
## opens the loop -- a corridor outside the east wall, back up to the
## gallery.
##
## **The kit:** the base kit plus the swing tether everywhere. The roof
## closes the hall, the vault and the corridor; the ledge in the
## north-west corner is a local stand-in only a swing (or an Echo) reaches.

const P := preload("res://scripts/content/crossing_d_parts.gd")
const L := preload("res://scripts/content/impact_lab_parts.gd")
const R := preload("res://scripts/content/impact_relay_parts.gd")
const THEME := "concrete_facility"
const WALL := 0.5
const HALL := Rect2(-10.0, -12.0, 20.0, 22.0)
const HALL_HEIGHT := 8.0
const DOOR_X := Vector2(-1.5, 1.5)
const DOOR_TOP := 3.0
const WINDOW_X := Vector2(3.0, 7.0)
const WINDOW_Y := Vector2(1.0, 3.4)
const VAULT := Rect2(-6.0, -18.0, 14.0, 5.5)
const VAULT_HEIGHT := 4.0
const DAIS := Rect2(4.0, -16.0, 2.0, 2.0)
const DAIS_TOP := 1.0
const ONWARD_X := Vector2(-5.0, -3.0)
const ANTE := Rect2(-5.5, -21.5, 3.0, 3.0)
const GALLERY_Z := 6.0
const GALLERY_Y := 4.5
const STAIR_X := Vector2(-10.0, -8.0)
const STAIR_FOOT_Z := -2.0
const ARRIVAL := Rect2(-2.0, 10.5, 4.0, 4.0)
const SPAWN := Vector3(0.0, GALLERY_Y, 13.0)
const LOOP := Rect2(8.5, -17.0, 5.0, 27.5)
const LOOP_INNER_X := 10.5
const LOOP_STEPS_Z := Vector2(-6.0, 6.0)
const LOOP_DOOR_Z := Vector2(-16.0, -14.0)
const GALLERY_DOOR_Z := Vector2(7.0, 9.0)
const LATCH_AT := Vector3(6.6, 1.0, -13.4)
const PLATE_AT := Vector3(0.0, 0.0, -1.0)
const LEVER_AT := Vector3(-7.0, 1.0, 0.0)
const STAND := Rect2(5.5, 1.5, 1.0, 1.0)
const STAND_TOP := 0.15
const WEIGHT_KG := 36.0
const WEIGHT_SIZE := Vector3(0.45, 0.6, 0.45)
const WEIGHT_HOME := Vector3(6.0, STAND_TOP + 0.31, 2.0)
const CRATE_KG := 4.0
const CRATE_SIZE := Vector3(0.5, 0.36, 0.5)
const LEDGE := Rect2(-10.0, -10.0, 2.0, 2.0)
const LEDGE_TOP := 5.0
const TRUSS_Y := 7.0
const FLIGHT_SECONDS := 1.0

signal said(text: String)
signal stand_in_found(id: String)

var lever: P.Lever
var latch: P.Lever
var plate: L.ObjectPlate
var shutter: L.ImpactShutter
var weight: ManipulableBody
var crate: ManipulableBody
var check: P.StandIn
var ledge_reward: P.StandIn
var vault_door: R.SlideDoor
var gallery_door: R.SlideDoor
var powered := false
var shutter_broken := false
var loop_open := false
var respawns := 0
## Blows the shutter accepted (12 or more), across rebuilds of a trial.
var blows := 0
## The last blow the shutter took (kept here: a broken shutter is freed).
var last_impact := {}
var homes := {}
var _lines := {}
var _flood: SpotLight3D
var _power_sign: Label3D


func build() -> void:
	_hall()
	_gallery()
	_arrival()
	_vault()
	_loop()
	_fixtures()
	_devices()
	_lights()


func _mat(kind: String) -> Material:
	match kind:
		"wall":
			return ThemeMaterials.wall_mat(THEME)
		"trim":
			return ThemeMaterials.trim_mat(THEME)
		"glass":
			return ThemeMaterials.glass_material(Color(0.62, 0.8, 0.9, 0.28))
	return ThemeMaterials.floor_mat(THEME)


func _block(label: String, lo: Vector3, hi: Vector3, kind := "wall") -> Node3D:
	var made := ChamberBuilders._box(self, hi - lo, (lo + hi) * 0.5,
			_mat(kind))
	made.name = label
	return made


## THE HALL: G0's lab hall, 20 x 22 x 8 m, closed roof, trusses at 7 m;
## the north wall's doorway and window as G0 measured them; doorways for
## the arrival (south, at gallery height) and the loop (east, ditto).
func _hall() -> void:
	var x0 := HALL.position.x
	var z0 := HALL.position.y
	var x1 := HALL.end.x
	var z1 := HALL.end.y
	var h := HALL_HEIGHT
	var y := GALLERY_Y
	_block("Floor", Vector3(x0 - WALL, -0.5, z0 - WALL),
			Vector3(x1 + WALL, 0.0, z1 + WALL), "floor")
	_block("Roof", Vector3(x0 - WALL, h, z0 - WALL),
			Vector3(x1 + WALL, h + 0.5, z1 + WALL), "trim")
	_block("WestWall", Vector3(x0 - WALL, 0, z0), Vector3(x0, h, z1))
	# South: the arrival's doorway at gallery height.
	var a0 := ARRIVAL.position.x + 0.5
	var a1 := ARRIVAL.end.x - 0.5
	_block("South_W", Vector3(x0 - WALL, 0, z1), Vector3(a0, h, z1 + WALL))
	_block("South_E", Vector3(a1, 0, z1), Vector3(x1 + WALL, h, z1 + WALL))
	_block("South_Sill", Vector3(a0, 0, z1), Vector3(a1, y, z1 + WALL))
	_block("South_Head", Vector3(a0, y + 3.0, z1), Vector3(a1, h, z1 + WALL))
	# East: the loop's gallery door at gallery height.
	var g0 := GALLERY_DOOR_Z.x
	var g1 := GALLERY_DOOR_Z.y
	_block("East_N", Vector3(x1, 0, z0 - WALL), Vector3(x1 + WALL, h, g0))
	_block("East_S", Vector3(x1, 0, g1), Vector3(x1 + WALL, h, z1))
	_block("East_Sill", Vector3(x1, 0, g0), Vector3(x1 + WALL, y, g1))
	_block("East_Head", Vector3(x1, y + 3.0, g0), Vector3(x1 + WALL, h, g1))
	# North: G0's doorway and window.
	var n0 := z0 - WALL
	_block("North_W", Vector3(x0 - WALL, 0, n0), Vector3(DOOR_X.x, h, z0))
	_block("North_DoorHead", Vector3(DOOR_X.x, DOOR_TOP, n0), Vector3(DOOR_X.y, h, z0))
	_block("North_Mid", Vector3(DOOR_X.y, 0, n0), Vector3(WINDOW_X.x, h, z0))
	_block("North_Sill", Vector3(WINDOW_X.x, 0, n0), Vector3(WINDOW_X.y, WINDOW_Y.x, z0))
	_block("North_Head", Vector3(WINDOW_X.x, WINDOW_Y.y, n0), Vector3(WINDOW_X.y, h, z0))
	_block("North_E", Vector3(WINDOW_X.y, 0, n0), Vector3(x1 + WALL, h, z0))
	_block("Window", Vector3(WINDOW_X.x, WINDOW_Y.x, n0 + 0.2),
			Vector3(WINDOW_X.y, WINDOW_Y.y, z0 - 0.2), "glass")
	for z in [-8.0, -2.0, 4.0]:
		_block("Truss", Vector3(x0, TRUSS_Y - 0.15, z - 0.15),
				Vector3(x1, TRUSS_Y + 0.15, z + 0.15), "trim")
		for x in [-5.0, 0.0, 5.0]:
			_block("TrussHanger", Vector3(x - 0.08, TRUSS_Y + 0.15, z - 0.08),
					Vector3(x + 0.08, h, z + 0.08), "trim")
	P.plain_sign(self, "IMPACT SHUTTER", Vector3(0, DOOR_TOP + 0.4, z0 + 0.02),
			30, P.DESTRUCTIBLE)


## THE GALLERY: the hall's south end, 4.5 m up, solid beneath (nothing
## rolls under it), a glass front, and the stair down the west wall --
## open on its east side, so dropping off it to the floor is legal.
func _gallery() -> void:
	var x0 := HALL.position.x
	var x1 := HALL.end.x
	var z1 := HALL.end.y
	var y := GALLERY_Y
	_block("GalleryDeck", Vector3(x0, 0, GALLERY_Z), Vector3(x1, y, z1), "floor")
	_block("GalleryGlass", Vector3(STAIR_X.y, y, GALLERY_Z - 0.05),
			Vector3(x1, y + 1.1, GALLERY_Z + 0.05), "glass")
	_block("GalleryRail", Vector3(STAIR_X.y, y + 1.1, GALLERY_Z - 0.07),
			Vector3(x1, y + 1.18, GALLERY_Z + 0.07), "trim")
	var steps := 15
	var run := (GALLERY_Z - STAIR_FOOT_Z) / float(steps)
	for i in steps - 1:
		var top := y - 0.3 * float(i + 1)
		var zb := GALLERY_Z - run * float(i + 1)
		_block("Stair", Vector3(STAIR_X.x, 0, zb), Vector3(STAIR_X.y, top, zb + run),
				"floor")


## THE CONNECTOR you arrive from, at gallery height behind the south wall.
func _arrival() -> void:
	var x0 := ARRIVAL.position.x
	var x1 := ARRIVAL.end.x
	var z0 := ARRIVAL.position.y
	var z1 := ARRIVAL.end.y
	var y := GALLERY_Y
	_block("ArrivalFloor", Vector3(x0 - WALL, 0, z0), Vector3(x1 + WALL, y, z1 + WALL), "floor")
	_block("ArrivalRoof", Vector3(x0 - WALL, y + 3.0, z0), Vector3(x1 + WALL, y + 3.5,
			z1 + WALL), "trim")
	_block("ArrivalWest", Vector3(x0 - WALL, y, z0), Vector3(x0, y + 3.0, z1))
	_block("ArrivalEast", Vector3(x1, y, z0), Vector3(x1 + WALL, y + 3.0, z1))
	_block("ArrivalSouth", Vector3(x0 - WALL, y, z1), Vector3(x1 + WALL, y + 3.0, z1 + WALL))


## THE VAULT: G0's back room behind the north wall, 4 m high; the dais
## with the Check off the throw's axis; the onward door north; the loop
## door east, shut until the latch beside it is lifted.
func _vault() -> void:
	var x0 := VAULT.position.x
	var z0 := VAULT.position.y
	var x1 := VAULT.end.x
	var z1 := HALL.position.y - WALL
	var h := VAULT_HEIGHT
	_block("VaultFloor", Vector3(x0 - WALL, -0.5, z0 - WALL), Vector3(x1 + WALL, 0, z1), "floor")
	_block("VaultRoof", Vector3(x0 - WALL, h, z0 - WALL), Vector3(x1, h + 0.5, z1), "trim")
	_block("VaultWest", Vector3(x0 - WALL, 0, z0), Vector3(x0, h, z1))
	# North, with the onward door.
	_block("VaultNorth_W", Vector3(x0 - WALL, 0, z0 - WALL), Vector3(ONWARD_X.x, h, z0))
	_block("VaultNorth_E", Vector3(ONWARD_X.y, 0, z0 - WALL), Vector3(x1 + WALL, h, z0))
	_block("VaultNorth_Head", Vector3(ONWARD_X.x, 2.8, z0 - WALL), Vector3(ONWARD_X.y, h, z0))
	# East, with the loop door; full height, so the corridor's roof closes
	# against it.
	var l0 := LOOP_DOOR_Z.x
	var l1 := LOOP_DOOR_Z.y
	_block("VaultEast_N", Vector3(x1, 0, z0 - WALL), Vector3(x1 + WALL, HALL_HEIGHT, l0))
	_block("VaultEast_S", Vector3(x1, 0, l1), Vector3(x1 + WALL, HALL_HEIGHT, z1))
	_block("VaultEast_Head", Vector3(x1, 3.0, l0), Vector3(x1 + WALL, HALL_HEIGHT, l1))
	vault_door = _door("VaultDoor", Vector3(x1 + WALL * 0.5, 1.5, (l0 + l1) * 0.5),
			Vector3(0.3, 3.0, l1 - l0))
	# The dais (one 0.5 m step up its west side) and the Check on it.
	_block("Dais", Vector3(DAIS.position.x, 0, DAIS.position.y),
			Vector3(DAIS.end.x, DAIS_TOP, DAIS.end.y), "trim")
	_block("DaisStep", Vector3(DAIS.position.x - 0.6, 0, DAIS.position.y),
			Vector3(DAIS.position.x, DAIS_TOP * 0.5, DAIS.end.y), "floor")
	check = P.StandIn.make("relay_vault", "check", THEME)
	check.position = Vector3(DAIS.get_center().x, DAIS_TOP, DAIS.get_center().y)
	add_child(check)
	check.found.connect(func(id: String) -> void: stand_in_found.emit(id))
	latch = P.Lever.mounted("LIFT THE LATCH", P.NEUTRAL, THEME)
	latch.position = LATCH_AT
	add_child(latch)
	P.cap_emission(latch)
	latch.pulled.connect(_on_latch)
	# Beyond the onward door: the way on, out of this review.
	var e0 := ANTE.position.x
	var e1 := ANTE.end.x
	var f0 := ANTE.position.y
	_block("AnteFloor", Vector3(e0 - WALL, -0.5, f0 - WALL), Vector3(e1 + WALL, 0, z0 - WALL),
			"floor")
	_block("AnteRoof", Vector3(e0 - WALL, 3.0, f0 - WALL), Vector3(e1 + WALL, 3.5, z0 - WALL),
			"trim")
	_block("AnteWest", Vector3(e0 - WALL, 0, f0), Vector3(e0, 3.0, z0 - WALL))
	_block("AnteEast", Vector3(e1, 0, f0), Vector3(e1 + WALL, 3.0, z0 - WALL))
	_block("AnteNorth", Vector3(e0 - WALL, 0, f0 - WALL), Vector3(e1 + WALL, 3.0, f0))
	P.plain_sign(self, "THE WAY ON\n(end of this review room)",
			Vector3(ANTE.get_center().x, 1.8, f0 + 0.06), 24)


## THE LOOP: a corridor outside the hall's east wall, from the vault's
## loop door south, climbing by steps to the gallery's east-end door.
## Roofed and walled all round; its only openings are its two doors.
func _loop() -> void:
	var x0 := LOOP.position.x
	var z0 := LOOP.position.y
	var x1 := LOOP.end.x
	var z1 := LOOP.end.y
	var xi := LOOP_INNER_X
	var h := HALL_HEIGHT
	_block("LoopFloor", Vector3(x0, -0.5, z0 - WALL), Vector3(x1 + WALL, 0, z1 + WALL), "floor")
	_block("LoopRoof", Vector3(x0, h, z0 - WALL), Vector3(x1 + WALL, h + 0.5, z1 + WALL), "trim")
	_block("LoopEast", Vector3(x1, 0, z0 - WALL), Vector3(x1 + WALL, h, z1 + WALL))
	_block("LoopNorth", Vector3(x0, 0, z0 - WALL), Vector3(x1, h, z0))
	_block("LoopSouth", Vector3(xi, 0, z1), Vector3(x1, h, z1 + WALL))
	var steps := 15
	var run := (LOOP_STEPS_Z.y - LOOP_STEPS_Z.x) / float(steps)
	for i in steps:
		var top := 0.3 * float(i + 1)
		var za := LOOP_STEPS_Z.x + run * float(i)
		_block("LoopStep", Vector3(xi, 0, za), Vector3(x1, top, za + run), "floor")
	_block("LoopLanding", Vector3(xi, 0, LOOP_STEPS_Z.y), Vector3(x1, GALLERY_Y, z1), "floor")
	gallery_door = _door("GalleryDoor", Vector3(HALL.end.x + WALL * 0.5, GALLERY_Y + 1.5,
			(GALLERY_DOOR_Z.x + GALLERY_DOOR_Z.y) * 0.5),
			Vector3(0.3, 3.0, GALLERY_DOOR_Z.y - GALLERY_DOOR_Z.x))
	P.plain_sign(self, "OPENS FROM\nTHE OTHER SIDE", Vector3(HALL.end.x - 0.12,
			GALLERY_Y + 2.2, (GALLERY_DOOR_Z.x + GALLERY_DOOR_Z.y) * 0.5), 20) \
			.rotation.y = -PI * 0.5


func _door(label: String, at: Vector3, size: Vector3) -> R.SlideDoor:
	var door := R.SlideDoor.new()
	door.name = label
	door.size = size
	door.position = at
	add_child(door)
	door.build(_mat("trim"), ThemeMaterials.glow_material(P.NEUTRAL, 0.1))
	return door


## THE WEIGHT'S STAND and the north-west ledge.
func _fixtures() -> void:
	_block("Stand", Vector3(STAND.position.x, 0, STAND.position.y),
			Vector3(STAND.end.x, STAND_TOP, STAND.end.y), "trim")
	_block("Ledge", Vector3(LEDGE.position.x, LEDGE_TOP - 0.4, LEDGE.position.y),
			Vector3(LEDGE.end.x, LEDGE_TOP, LEDGE.end.y), "trim")
	ledge_reward = P.StandIn.make("relay_ledge", "reward", THEME)
	ledge_reward.position = Vector3(LEDGE.position.x + 0.6, LEDGE_TOP,
			LEDGE.position.y + 0.6)
	add_child(ledge_reward)
	ledge_reward.found.connect(func(id: String) -> void: stand_in_found.emit(id))


func _devices() -> void:
	# THE PLATE, G0's, throwing north into the shutter's centre.
	plate = L.ObjectPlate.new()
	plate.name = "ObjectPlate"
	plate.position = PLATE_AT
	add_child(plate)
	var shutter_at := Vector3(0, DOOR_TOP * 0.5, HALL.position.y - WALL * 0.5)
	plate.flight_seconds = FLIGHT_SECONDS
	plate.target = shutter_at + Vector3(0, 0, WALL * 0.5)
	plate.build(plate.target - plate.global_position)
	plate.dud.connect(func(_b: ManipulableBody) -> void:
		said.emit("The plate clicks. Nothing happens."))
	_build_shutter()
	# THE LEVER AND ITS LINE: the kit lever by the stair's foot, its
	# raceway out of the rear gland and across the floor into the plate's
	# west face, lit only once it is thrown.
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
	_power_sign = P.plain_sign(self, "POWER OFF", LEVER_AT + Vector3(0, 0.95, 0.3), 18)
	# THE WEIGHT: dense steel, a squat block with a carry handle.
	weight = ManipulableBody.create("relay_weight", WEIGHT_KG, WEIGHT_SIZE)
	weight.carriable = true
	var steel := ThemeMaterials.trim_mat(THEME)
	L.box(weight, "Look", Vector3.ZERO, WEIGHT_SIZE, steel)
	P.strip(weight, "Band", Vector3(0, -0.12, 0), Vector3(WEIGHT_SIZE.x + 0.02, 0.1,
			WEIGHT_SIZE.z + 0.02), P.NEUTRAL, 0.15)
	for x in [-0.13, 0.13]:
		L.box(weight, "HandlePost", Vector3(x, WEIGHT_SIZE.y * 0.5 + 0.05, 0),
				Vector3(0.04, 0.1, 0.04), steel)
	L.box(weight, "Handle", Vector3(0, WEIGHT_SIZE.y * 0.5 + 0.1, 0),
			Vector3(0.3, 0.04, 0.05), steel)
	add_child(weight)
	weight.global_position = WEIGHT_HOME
	homes[weight] = WEIGHT_HOME
	# THE CRATE: a flimsy open-topped plastic tote, resting on the plate.
	crate = ManipulableBody.create("relay_crate", CRATE_KG, CRATE_SIZE)
	crate.carriable = true
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.72, 0.74, 0.7)
	plastic.roughness = 0.55
	var t := 0.025
	L.box(crate, "Base", Vector3(0, -CRATE_SIZE.y * 0.5 + t * 0.5, 0),
			Vector3(CRATE_SIZE.x, t, CRATE_SIZE.z), plastic)
	for side in [-1.0, 1.0]:
		L.box(crate, "Side", Vector3(side * (CRATE_SIZE.x - t) * 0.5, 0, 0),
				Vector3(t, CRATE_SIZE.y, CRATE_SIZE.z), plastic)
		L.box(crate, "End", Vector3(0, 0, side * (CRATE_SIZE.z - t) * 0.5),
				Vector3(CRATE_SIZE.x, CRATE_SIZE.y, t), plastic)
	add_child(crate)
	var crate_home := PLATE_AT + Vector3(0, L.ObjectPlate.SIZE.y + CRATE_SIZE.y * 0.5
			+ 0.02, 0)
	crate.global_position = crate_home
	homes[crate] = crate_home


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
		if _flood != null:
			_flood.visible = true
		said.emit("The shutter gives way."))
	shutter.struck.connect(func(_amount: float, accepted: bool,
			source: Node3D) -> void:
		if accepted:
			blows += 1
		if source != null:
			last_impact = shutter.last_impact.duplicate()
		if not accepted:
			said.emit("NEEDS A HEAVIER HIT"))


func _lights() -> void:
	for at in [Vector3(-5, 6.6, 2), Vector3(5, 6.6, 2), Vector3(-5, 6.6, -7),
			Vector3(5, 6.6, -7), Vector3(0, GALLERY_Y + 2.6, 12.5),
			Vector3(12, 6.0, -6), Vector3(12, 6.5, 6), Vector3(10.5, 3.0, -15),
			Vector3(-4, 2.4, -20)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_energy = 0.9
		light.omni_range = 14.0
		light.light_color = Color(0.84, 0.88, 0.94)
		add_child(light)
	# The vault lit warm: the Check reads through the window from the
	# gallery.
	var vault := OmniLight3D.new()
	vault.position = Vector3(4.0, 3.4, -15.0)
	vault.light_energy = 2.0
	vault.omni_range = 9.0
	vault.light_color = Color(1.0, 0.9, 0.72)
	add_child(vault)
	# Through the broken doorway, the vault's light floods the hall floor.
	_flood = SpotLight3D.new()
	_flood.name = "Flood"
	_flood.position = Vector3(0, 3.2, -16.5)
	_flood.rotation = Vector3(-0.12, 0, 0)
	_flood.light_energy = 5.0
	_flood.spot_range = 22.0
	_flood.spot_angle = 26.0
	_flood.light_color = Color(1.0, 0.88, 0.7)
	_flood.visible = false
	add_child(_flood)


func _on_lever(_l: CallLever) -> void:
	if powered:
		return
	powered = true
	lever.lock("PLATE POWERED")
	plate.set_powered(true)
	P.conduit_power(_lines["plate"], true)
	_power_sign.text = "POWER ON"


func _on_latch(_l: CallLever) -> void:
	if loop_open:
		return
	loop_open = true
	latch.lock("LATCH LIFTED")
	vault_door.open()
	gallery_door.open()
	said.emit("Somewhere above, a door unlatches.")


func line_live() -> bool:
	return bool((_lines["plate"] as Node).get_meta("live", false))


## D-18 v2 §4: an object's allowed volume is the hall plus the vault.
func allowed(at: Vector3) -> bool:
	if at.y < -2.0 or at.y > HALL_HEIGHT + 1.0:
		return false
	var flat := Vector2(at.x, at.z)
	return HALL.grow(0.5).has_point(flat) or VAULT.grow(0.5).has_point(flat)


## Inside any of the room's closed spaces: the hall, the vault, the
## corridor, the arrival and the antechamber.
func inside(at: Vector3) -> bool:
	if at.y < -2.0 or at.y > HALL_HEIGHT + 1.0:
		return false
	var flat := Vector2(at.x, at.z)
	for area in [HALL, VAULT, LOOP, ARRIVAL, ANTE]:
		if (area as Rect2).grow(0.8).has_point(flat):
			return true
	return false


## RECOVERY (D-18 v2 §4): the weight or the crate that leaves the hall and
## the vault, or falls under the floor, comes home -- the weight to its
## stand, the crate to the plate. In the hands, nothing comes home.
func _physics_process(_delta: float) -> void:
	for body: ManipulableBody in homes.keys():
		if not is_instance_valid(body) or body.carried_by != null:
			continue
		if not allowed(body.global_position):
			send_home(body)


func send_home(body: ManipulableBody) -> void:
	respawns += 1
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.global_transform = Transform3D(Basis.IDENTITY, homes[body])
	body.sleeping = false
	said.emit("The weight is back on its stand." if body == weight
			else "The crate is back on the plate.")


## FOR THE MEASUREMENT ONLY: a fresh shutter; `body` set down at rest on
## the plate at `offset` from its centre, turned by `yaw`.
func reset_trial(body: ManipulableBody, offset: Vector3, yaw: float) -> void:
	last_impact = {}
	blows = 0
	if shutter != null and is_instance_valid(shutter):
		shutter.queue_free()
	_build_shutter()
	if _flood != null:
		_flood.visible = false
	var half := 0.3
	var hull := body.get_node_or_null("hull") as CollisionShape3D
	if hull != null and hull.shape is BoxShape3D:
		half = (hull.shape as BoxShape3D).size.y * 0.5
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.continuous_cd = false
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw),
			plate.global_position + Vector3(offset.x, L.ObjectPlate.SIZE.y + half
				+ 0.01, offset.z))
	body.sleeping = false
