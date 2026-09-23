class_name PassingPlatformsRoom
extends Node3D
## EX50-011's ROOM, whoever owns it (O05-06.2).
##
## Everything `--passing-platforms` built between its sky and its player,
## moved here whole: the arrival floor and the lift's pit, the recovery
## floor and its stair, the upper shelf, the goal gallery and its plate,
## the lift `V`, the shuttle `H`, every call control, and the permanent
## service stair the plate releases. The development scenario owns one at
## the origin; a composed Zone hosts one through `PassingPlatformsHosted`.
## One implementation, two owners.
##
## **IN ITS OWN FRAME.** Every part is placed with `position`, never
## `global_position`: the scenario put its room at the world origin, where
## the two agree, and a Zone does not. The lift places itself in its
## parent's frame (`ShuttleDeck._place`), and the shuttle takes its frame
## from this room when it enters the tree (`RailCarrier.frame_from_parent`).
##
## **What persists, and when (EX50-011 §9).** The service stair is the
## room's one latch: released the first time somebody stands on `G`, and
## never withdrawn. The carriers' poses, destinations and hold states are
## package-local, and a carrier is reported only AT REST -- arrived at a
## stop, held by a STOP, or pausing in a declared dwell -- because Amalgam
## §5.3 refuses to save a machine that is moving. `restore_carrier` puts a
## rest back before anyone sees the room, and a dwell comes back HELD: §9,
## "a carrier in a dwell state can remain safely held until the player
## resumes".

signal said(text: String)
## The service stair was released by a player standing on `G` -- never on
## restore.
signal stair_engaged
## A carrier came to rest: `t` its own offset, `destination` the stop it
## stands at or is bound for ("" when a hold cleared its errand), `held`
## whether a STOP or a dwell holds it.
signal carrier_rested(carrier_id: String, t: float, destination: String,
		held: bool)

## The room, per §2: 28 by 22 m and 12 m high.
const ROOM_HALF := Vector2(14.0, 11.0)
const ROOM_HEIGHT := 12.0

## Deck tops. The transfer plane is where both decks' TOP faces sit, so
## the step across is level.
const TRANSFER_Y := 4.0
const SHELF_Y := 8.0
## §2: "A fixed recovery floor lies 3 m below the transfer level".
const RECOVERY_Y := TRANSFER_Y - 3.0
const DECK := Vector3(4.0, 0.4, 4.0)
const SLAB := 0.6
## Where `A` stops and the recovery floor starts, a metre above it.
## They share the plane and never the height, so the two slabs meet
## without a slot between them for a body to drop into.
const A_NORTH := 0.3

## `V`'s column. Its deck spans `V_X` +/- 2 and `V_Z` +/- 2.
const V_X := -3.0
const V_Z := -2.0
## `H`'s track. Its deck's SOUTH edge is `GAP` north of `V`'s NORTH edge,
## which is the whole of the separation between the two machines: they
## never share a `z`, at any offset, so a mistimed meeting cannot be a
## collision (§4).
const GAP := 0.2
const H_Z := V_Z + DECK.z * 0.5 + GAP + DECK.z * 0.5
## Where the rail sits so the deck's top lands on the transfer plane.
const H_RAIL_Y := TRANSFER_Y - DECK.y
## §2: the west waiting berth is about 9 m from the rendezvous centre.
const H_WEST_X := V_X - 9.0
const H_EAST_X := 9.0

## The counterexample's shift: far enough that no step, and no jump the
## base kit has, crosses it.
const PARTED_SHIFT := 6.0

## The goal gallery, east of `H`'s east berth.
const G_WEST := H_EAST_X + DECK.x * 0.5 + 0.05
## The upper shelf, west of `V`'s column at `SHELF_Y`.
const SHELF_EAST := V_X - DECK.x * 0.5 - 0.1
const SHELF_WEST := -12.0
const SHELF_Z := Vector2(-5.0, 1.0)

const RAIL_HEIGHT := 1.1
const RAIL_THICK := 0.15
const STEP_RISE := 0.25

## The permanent service stair (§4): down the east side from `G`'s south
## edge to `A`.
const STAIR_X := 12.5
const STAIR_WIDTH := 1.8
const STAIR_FOOT_Z := -9.0
const STAIR_HEAD_Z := -1.05

## Stop indices on `V`. Named because "go_to(1)" is not a destination.
const V_ARRIVAL := 0
const V_TRANSFER := 1
const V_SHELF := 2
## §2: "an authored pause at y=4 of roughly 2.5 seconds".
const V_DWELL := 2.5

## Dock indices on `H`.
const H_WEST := 0
const H_EAST := 1

## The ids the bridge's contract declares for the two machines
## (`schemas/minors.py`), and the ids their rests are saved under.
const LIFT := "lift"
const SHUTTLE := "shuttle"

var theme := "concrete_facility"
## The counterexample (`--parted`).
var parted := false
## The "development scenario, not a Zone" plaque. A hosted room is not
## one.
var development_signs := true

var v: ShuttleDeck = null
var h: RailCarrier = null
var rail: RailPath = null
## Every call control in the room, by the label on its prompt. The suite
## pulls them by name because a test that indexes into an array is a test
## that breaks when a lever is added.
var levers: Dictionary = {}
## The plate on `G`. §3: a sensor may remember the route was visited, and
## it stands ON the gallery, so it cannot replace walking onto it.
var goal_plate: ActivityElement = null
## Released the first time somebody stands on `G`, and never withdrawn --
## §8, "No reset undoes G's released service stair".
var stair_released := false
var reached_g := false
## The service stair's steps, once released.
var service_stair: Node3D = null
## `G`'s south railing, whole until the stair is released through it.
var g_south_rail: StaticBody3D = null

var _rails: Array[StaticBody3D] = []
var _recovery: StaticBody3D = null
var _readout: Label3D = null
var _refusal: Label3D = null
var _refusal_left := 0.0


func build() -> void:
	_floors()
	_shelf()
	_gallery()
	_lift()
	_shuttle()
	_controls()
	_signs()


func _process(delta: float) -> void:
	if _refusal_left > 0.0:
		_refusal_left -= delta
		if _refusal_left <= 0.0 and _refusal != null:
			_refusal.text = ""


# ------------------------------------------------------------ persistence

## §9: G's service stair is room-persistent, restored through its accepted
## state rather than by replaying the arrival. Nothing is announced.
func restore_stair() -> void:
	if stair_released:
		return
	_release_stair(false)


## §9: "A stable save restores each at its saved pose before the player."
## The rest the bridge accepted, put back without motion and without a
## report -- a restored rest announces nothing, so nothing is sent back
## that the bridge has just sent.
##
## A dwell comes back HELD, and a destination the machine does not have
## is ignored rather than guessed at.
func restore_carrier(carrier_id: String, t: float, destination: String,
		held: bool) -> void:
	match carrier_id:
		LIFT:
			if v == null or v.stops.is_empty():
				return
			v.offset = clampf(t, v.stops[0], v.stops[v.stops.size() - 1])
			v.speed = 0.0
			var goal := v.stop_ids.find(destination)
			if goal >= 0:
				v.destination = goal
			elif v.at_stop() >= 0:
				v.destination = v.at_stop()
			v.held = held
			if v.is_inside_tree():
				v._place()
		SHUTTLE:
			if h == null or rail == null:
				return
			h.offset = clampf(t, 0.0, rail.length())
			h.speed = 0.0
			h.heading = RailCarrier.HOLD
			h.target_dock = -1
			if held:
				h.hold(true)
			else:
				h.held = false
			if h.is_inside_tree():
				h._place()


## The lift's rest, if it is at rest: `[t, destination, held]`, else [].
func lift_rest() -> Array:
	if v == null or not is_zero_approx(v.speed):
		return []
	var dwelling := v.dwelling_at() >= 0
	if not (v.held or dwelling or v.at_stop() == v.destination):
		return []
	return [v.offset, v.stop_id(v.destination), v.held or dwelling]


## The shuttle's rest, if it is at rest: `[t, destination, held]`, else [].
## A shuttle held between docks has no errand (`RailCarrier.hold` clears
## it); one standing at a dock unheld has that dock.
func shuttle_rest() -> Array:
	if h == null or h.heading != RailCarrier.HOLD:
		return []
	var dock := h.at_dock()
	if h.held:
		return [h.offset, h.dock_id(dock) if dock >= 0 else "", true]
	if dock < 0:
		return []
	return [h.offset, h.dock_id(dock), false]


func _report_lift() -> void:
	var rest := lift_rest()
	if not rest.is_empty():
		carrier_rested.emit(LIFT, float(rest[0]), str(rest[1]),
				bool(rest[2]))


func _report_shuttle() -> void:
	var rest := shuttle_rest()
	if not rest.is_empty():
		carrier_rested.emit(SHUTTLE, float(rest[0]), str(rest[1]),
				bool(rest[2]))


# ---------------------------------------------------------------- build

## The two floors, and the pit the lift rests in.
##
## `A` IS BUILT AROUND `V`'s DECK rather than under it. A deck whose
## lower half is inside the floor slab is a deck standing in a wall, and
## the alternative -- resting the deck ON the floor -- makes boarding a
## 0.4 m step up rather than the level walk §5 describes. A lift pit is
## what a lift actually has.
func _floors() -> void:
	var floor_mat := ThemeMaterials.floor_mat(theme)
	var half := DECK.x * 0.5 + 0.2
	var x0 := V_X - half
	var x1 := V_X + half
	var z0 := V_Z - half
	# `A` ends where the recovery floor begins, one metre below it.
	var z1 := A_NORTH
	_ground(-ROOM_HALF.x, ROOM_HALF.x, -ROOM_HALF.y, z0, 0.0, floor_mat)
	_ground(-ROOM_HALF.x, x0, z0, z1, 0.0, floor_mat)
	_ground(x1, ROOM_HALF.x, z0, z1, 0.0, floor_mat)
	# The pit, 0.2 m under the parked deck.
	_ground(x0, x1, z0, z1, -DECK.y - 0.2, floor_mat)
	# THE RECOVERY FLOOR (§2). It begins where `A` ends, one metre above
	# it, and reaches past `H`'s northern-most parted position so the
	# counterexample lands a body on a floor rather than proving the
	# room has a hole in it.
	# THE FULL WIDTH OF THE ROOM, and it was not that at first. The first
	# cut stopped it at x=-11 and x=12, which left two strips between it
	# and the walls with nothing under them at all -- a body that went
	# over there fell past `FALL_KILL_Y` and died, in a room whose §2
	# says a missed transfer is "a short fall and repositioning, not
	# automatic death into a bottomless void". The coverage census found
	# it; no walked route ever went near it.
	_recovery = _ground(-ROOM_HALF.x + 0.3, ROOM_HALF.x - 0.3, A_NORTH,
			ROOM_HALF.y - 0.3, RECOVERY_Y, ThemeMaterials.trim_mat(theme))
	# Stairs back to `A`, per §2.
	_stair(Vector3(-9.0, 0.0, -2.2), Vector3(-9.0, RECOVERY_Y, A_NORTH + 0.05),
			2.0)
	_walls()


## `x0..x1` by `z0..z1`, its TOP face at `top`.
func _ground(x0: float, x1: float, z0: float, z1: float,
		top: float, material: Material) -> StaticBody3D:
	if x1 - x0 <= 0.01 or z1 - z0 <= 0.01:
		return null
	return _slab(Vector3(x1 - x0, SLAB, z1 - z0),
			Vector3((x0 + x1) * 0.5, top - SLAB * 0.5, (z0 + z1) * 0.5),
			material)


## Four walls, 12 m high from a metre below the floor. The south one is
## where a hosted room is entered and the east one is where its way on
## (sealed) stands, so each is its own method.
func _walls() -> void:
	var mat := ThemeMaterials.wall_mat(theme)
	var h_mid := ROOM_HEIGHT * 0.5 - 1.0
	_slab(Vector3(0.5, ROOM_HEIGHT, ROOM_HALF.y * 2.0),
			Vector3(-ROOM_HALF.x, h_mid, 0.0), mat)
	_slab(Vector3(ROOM_HALF.x * 2.0, ROOM_HEIGHT, 0.5),
			Vector3(0.0, h_mid, ROOM_HALF.y), mat)
	_south_wall(mat)
	_east_wall(mat)


## The arrival wall. Whole in the scenario, which spawns its player
## inside; a hosted room cuts its way in here.
func _south_wall(wall: Material) -> void:
	_slab(Vector3(ROOM_HALF.x * 2.0, ROOM_HEIGHT, 0.5),
			Vector3(0.0, ROOM_HEIGHT * 0.5 - 1.0, -ROOM_HALF.y), wall)


## The wall behind `G`. Whole in the scenario; a hosted room has an
## opening here that the Zone seals.
func _east_wall(wall: Material) -> void:
	_slab(Vector3(0.5, ROOM_HEIGHT, ROOM_HALF.y * 2.0),
			Vector3(ROOM_HALF.x, ROOM_HEIGHT * 0.5 - 1.0, 0.0), wall)


## The upper shelf: §2's "safe observation and recall".
func _shelf() -> void:
	_ground(SHELF_WEST, SHELF_EAST, SHELF_Z.x, SHELF_Z.y, SHELF_Y,
			ThemeMaterials.trim_mat(theme))
	# Railings on every side but the one `V` docks against, and on the
	# parts of that side `V` never covers. §2: railings protect
	# nonboarding sides but do not block the intended stepping direction.
	_railing(Vector3(SHELF_WEST, SHELF_Y, SHELF_Z.x),
			Vector3(SHELF_WEST, SHELF_Y, SHELF_Z.y))
	_railing(Vector3(SHELF_WEST, SHELF_Y, SHELF_Z.x),
			Vector3(SHELF_EAST, SHELF_Y, SHELF_Z.x))
	_railing(Vector3(SHELF_WEST, SHELF_Y, SHELF_Z.y),
			Vector3(SHELF_EAST, SHELF_Y, SHELF_Z.y))
	_railing(Vector3(SHELF_EAST, SHELF_Y, SHELF_Z.x),
			Vector3(SHELF_EAST, SHELF_Y, V_Z - DECK.z * 0.5))
	_railing(Vector3(SHELF_EAST, SHELF_Y, V_Z + DECK.z * 0.5),
			Vector3(SHELF_EAST, SHELF_Y, SHELF_Z.y))


## `G`, and the stair arriving there releases.
func _gallery() -> void:
	_ground(G_WEST, ROOM_HALF.x, -1.0, 6.0, TRANSFER_Y,
			ThemeMaterials.trim_mat(theme))
	g_south_rail = _railing(Vector3(G_WEST, TRANSFER_Y, -1.0),
			Vector3(ROOM_HALF.x, TRANSFER_Y, -1.0))
	_railing(Vector3(G_WEST, TRANSFER_Y, 6.0),
			Vector3(ROOM_HALF.x, TRANSFER_Y, 6.0))
	goal_plate = ActivityElement.create(ActivityElement.STAND, 0,
			ActivityElement.PLATE_SIZE, Color(0.55, 1.0, 0.7))
	add_child(goal_plate)
	goal_plate.position = Vector3(G_WEST + 1.6, TRANSFER_Y, 2.2)
	goal_plate.triggered.connect(_on_goal)


func _on_goal(_which: ActivityElement) -> void:
	reached_g = true
	if stair_released:
		return
	_release_stair(true)


## A PERMANENT SERVICE STAIR (§4). Down to `A`, not to the recovery
## floor: the point is that later traversal does not need the carriers
## at all.
##
## THROUGH `G`'s SOUTH RAILING (P5-18). The stair's head is on `G`'s
## south edge, and that edge carries a 1.1 m railing, so the stair as
## first built ended against it: a body walked up it stopped on the top
## step, and the shortcut was one only for somebody willing to jump a
## guard rail. The railing is cut where the stair lands -- and only
## then, because until the stair is there that edge is a 4 m drop.
func _release_stair(announce: bool) -> void:
	stair_released = true
	service_stair = Node3D.new()
	service_stair.name = "ServiceStair"
	add_child(service_stair)
	_stair(Vector3(STAIR_X, 0.0, STAIR_FOOT_Z),
			Vector3(STAIR_X, TRANSFER_Y, STAIR_HEAD_Z), STAIR_WIDTH,
			service_stair)
	if g_south_rail != null:
		g_south_rail.get_parent().remove_child(g_south_rail)
		g_south_rail.free()
		g_south_rail = null
	var gap := Vector2(STAIR_X - STAIR_WIDTH * 0.5 - 0.1,
			STAIR_X + STAIR_WIDTH * 0.5 + 0.1)
	_railing(Vector3(G_WEST, TRANSFER_Y, -1.0),
			Vector3(gap.x, TRANSFER_Y, -1.0), service_stair)
	_railing(Vector3(gap.y, TRANSFER_Y, -1.0),
			Vector3(ROOM_HALF.x, TRANSFER_Y, -1.0), service_stair)
	if _readout != null:
		_readout.text = "G REACHED -- service stair open"
	if announce:
		said.emit("G reached: the service stair down to arrival is open")
		stair_engaged.emit()


## `V`: the lift, with the authored pause at the transfer plane.
func _lift() -> void:
	v = ShuttleDeck.create(Vector3.UP, Vector3(V_X, 0.0, V_Z),
			PackedFloat32Array([0.0, TRANSFER_Y, SHELF_Y]),
			PackedStringArray(["A", "TRANSFER", "SHELF"]),
			PackedFloat32Array([0.0, V_DWELL, 0.0]), DECK, theme)
	add_child(v)
	v.refused.connect(_on_refused)
	v.dwelling.connect(_on_dwelling)
	v.arrived.connect(func(_stop: int) -> void: _report_lift())
	# The only railed side: `A` boards from the south, `H` is north and
	# the shelf is west.
	_ride(v, _railing_mesh("East", DECK.x,
			Vector3(DECK.x * 0.5, 0.0, 0.0), true))
	# Guide columns, so the shaft reads as a shaft from the floor.
	for z: float in [V_Z - DECK.z * 0.5 + 0.2, V_Z + DECK.z * 0.5 - 0.2]:
		_slab(Vector3(0.25, SHELF_Y + 2.0, 0.25),
				Vector3(V_X + DECK.x * 0.5 + 0.25, (SHELF_Y + 2.0) * 0.5, z),
				ThemeMaterials.wall_mat(theme))


## `H`: the shuttle, on a straight rail at the transfer height.
##
## A `RailCarrier` and not a second class. What EX50-011 calls a finite
## shuttle schedule -- WEST HOLD, TRAVEL EAST, EAST HOLD, TRAVEL WEST --
## is a two-dock railway with a fail-safe stop, which is what that class
## already is; the only thing the situation authors is the speed.
func _shuttle() -> void:
	var z := H_Z + (PARTED_SHIFT if parted else 0.0)
	rail = RailPath.from_points(PackedVector3Array([
		Vector3(H_WEST_X, H_RAIL_Y, z),
		Vector3((H_WEST_X + H_EAST_X) * 0.5, H_RAIL_Y, z),
		Vector3(H_EAST_X, H_RAIL_Y, z),
	]))
	var links: Array[bool] = [true]
	h = RailCarrier.create(rail,
			PackedFloat32Array([0.0, rail.length()]),
			PackedStringArray(["WEST", "EAST"]), links, DECK, theme)
	# THE ROOM'S FRAME, not the world's: the rail is laid in this room's
	# coordinates, and the room is wherever its owner put it.
	h.frame_from_parent = true
	# SERVICE SPEED, from §2 and not from the skiff.
	h.top_speed = ShuttleDeck.SPEED
	h.accel = ShuttleDeck.ACCEL
	add_child(h)
	h.refused.connect(_on_refused)
	h.arrived.connect(_on_h_arrived)
	# `pose()` puts local +z along the track (east) and local +x on the
	# world's -z side (north). So the railed sides are local -x, which is
	# the north edge, and local -z, the west end. South stays open for
	# the transfer and east for stepping off at `G`.
	_ride(h, _railing_mesh("North", DECK.z,
			Vector3(-DECK.x * 0.5, 0.0, 0.0), true))
	_ride(h, _railing_mesh("West", DECK.x,
			Vector3(0.0, 0.0, -DECK.z * 0.5), false))
	# The beam, so both destinations are legible from the floor (§7).
	_slab(Vector3(ROOM_HALF.x * 2.0 - 1.0, 0.3, 0.5),
			Vector3(0.0, H_RAIL_Y - 0.35, z), ThemeMaterials.wall_mat(theme))


func _on_h_arrived(dock: String) -> void:
	if _readout != null:
		_readout.text = "H at %s" % dock
	_report_shuttle()


func _on_dwelling(stop: int, seconds: float) -> void:
	if _readout != null:
		_readout.text = "V holding at %s for %.1f s" \
				% [v.stop_id(stop), seconds]
	_report_lift()


## A railing, as a child that rides with a deck.
## NAMED, and each one differently. `add_child` does not rename a
## colliding sibling to something readable -- it throws the name away
## and assigns `@StaticBody3D@93`. The shuttle's two railings were both
## called "Railing", so the second one lost its name, and a census that
## looked for railings by name found two of the three and said so.
func _railing_mesh(named: String, length: float, at: Vector3,
		along_z: bool) -> StaticBody3D:
	var size := Vector3(RAIL_THICK, RAIL_HEIGHT, length) if along_z \
			else Vector3(length, RAIL_HEIGHT, RAIL_THICK)
	var body := StaticBody3D.new()
	body.name = "Railing%s" % named
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = ThemeMaterials.glow_material(
			Color(0.75, 0.72, 0.6), 0.0)
	body.add_child(mesh_node)
	body.position = at + Vector3(0.0, DECK.y * 0.5 + RAIL_HEIGHT * 0.5, 0.0)
	return body


func _ride(deck: Node3D, part: Node3D) -> void:
	deck.add_child(part)


## A fixed railing between two room points, at the height of the floor
## they stand on.
func _railing(from: Vector3, to: Vector3,
		parent: Node3D = null) -> StaticBody3D:
	var span := to - from
	var length := span.length()
	if length < 0.05:
		return null
	var along_z := absf(span.z) > absf(span.x)
	var size := Vector3(RAIL_THICK, RAIL_HEIGHT, length) if along_z \
			else Vector3(length, RAIL_HEIGHT, RAIL_THICK)
	return _slab(size, (from + to) * 0.5
			+ Vector3(0.0, RAIL_HEIGHT * 0.5, 0.0),
			ThemeMaterials.glow_material(Color(0.75, 0.72, 0.6), 0.0),
			parent)


func _controls() -> void:
	# AT `A` (§2: "A local call at A can start H"). Four, because §6's
	# lower-pressure solution needs a STOP a player standing on the floor
	# can reach, and §8 needs a local reset.
	_lever("H EAST", Vector3(V_X - 3.2, 0.0, V_Z - 3.4),
			Color(1.0, 0.72, 0.35), func() -> void: _send_h(RailCarrier.FORWARD))
	_lever("H WEST", Vector3(V_X - 1.8, 0.0, V_Z - 3.4),
			Color(1.0, 0.72, 0.35), func() -> void: _send_h(RailCarrier.BACK))
	_lever("STOP H", Vector3(V_X + 1.8, 0.0, V_Z - 3.4),
			Color(1.0, 0.45, 0.4), stop_h)
	_lever("RESET", Vector3(V_X + 3.2, 0.0, V_Z - 3.4),
			Color(0.6, 0.7, 0.85), reset_carriers)
	# ONBOARD `V` (§2: "V's launch lever is on its own deck"; §8: a
	# player who stops it between floors has an onboard return command).
	_onboard(v, "LAUNCH", Vector3(DECK.x * 0.5 - 0.55, DECK.y * 0.5, -1.2),
			Color(0.55, 0.9, 1.0), func() -> void: _send_v(V_SHELF))
	_onboard(v, "STOP V", Vector3(DECK.x * 0.5 - 0.55, DECK.y * 0.5, 0.0),
			Color(1.0, 0.45, 0.4), stop_v)
	_onboard(v, "V DOWN", Vector3(DECK.x * 0.5 - 0.55, DECK.y * 0.5, 1.2),
			Color(0.55, 0.9, 1.0), func() -> void: _send_v(V_ARRIVAL))
	# ONBOARD `H` (§6: "then restart it from its onboard control"). On
	# the railed north edge, so they are never between the player and
	# either the transfer or the step off at `G`.
	_onboard(h, "H ON EAST", Vector3(-DECK.x * 0.5 + 0.55, DECK.y * 0.5, -1.2),
			Color(1.0, 0.72, 0.35), func() -> void: _send_h(RailCarrier.FORWARD))
	_onboard(h, "H ON WEST", Vector3(-DECK.x * 0.5 + 0.55, DECK.y * 0.5, 1.2),
			Color(1.0, 0.72, 0.35), func() -> void: _send_h(RailCarrier.BACK))
	# ON THE SHELF (§3).
	_lever("H WEST (SHELF)", Vector3(SHELF_EAST - 1.2, SHELF_Y, V_Z - 2.6),
			Color(1.0, 0.72, 0.35), func() -> void: _send_h(RailCarrier.BACK))
	_lever("V DOWN (SHELF)", Vector3(SHELF_EAST - 2.6, SHELF_Y, V_Z - 2.6),
			Color(0.55, 0.9, 1.0), func() -> void: _send_v(V_ARRIVAL))
	_lever("RESET (SHELF)", Vector3(SHELF_EAST - 4.0, SHELF_Y, V_Z - 2.6),
			Color(0.6, 0.7, 0.85), reset_carriers)
	# AT `G` (§3).
	_lever("H WEST (G)", Vector3(G_WEST + 1.0, TRANSFER_Y, -0.2),
			Color(1.0, 0.72, 0.35), func() -> void: _send_h(RailCarrier.BACK))


## A call is RELEASE-AND-GO, and that is the visible command §4 asks for.
##
## `hold(true)` is a fail-safe, and a fail-safe a player cannot clear is
## the trap `RailCarrier` already had to grow `_segment()` to avoid. So
## the lever clears the hold and issues the command in one pull, which is
## one player action; what it is NOT is the carrier resuming because
## somebody stood on it.
##
## A command that leaves the carrier where it is -- refused at the end of
## its track, say -- still changes its rest (the hold is gone), so the
## rest is reported; one that starts it moving reports nothing until it
## stops again.
func _send_h(direction: int) -> void:
	h.hold(false)
	h.request(direction)
	_report_shuttle()


func _send_v(stop: int) -> void:
	v.resume()
	v.go_to(stop)
	_report_lift()


## STOP: §4, "STOP holds the selected carrier. Resume follows its saved
## destination." A held carrier is at rest, so it is reported.
func stop_h() -> void:
	h.hold(true)
	_report_shuttle()


func stop_v() -> void:
	v.stop_here()
	_report_lift()


## §8's local reset, and it never teleports.
##
## "Reset while occupied uses the normal safe motion/checkpoint
## treatment, not instant relocation into a dock" -- so this issues the
## ordinary commands and there is no second path for an empty carrier to
## take. Nothing here touches `stair_released`.
func reset_carriers() -> void:
	_send_v(V_ARRIVAL)
	_send_h(RailCarrier.BACK)


func _lever(label: String, at: Vector3, tint: Color,
		action: Callable) -> CallLever:
	var made := CallLever.make(label, tint, theme)
	add_child(made)
	made.position = at + Vector3(0.0, CallLever.BASE.y * 0.5, 0.0)
	made.pulled.connect(func(_who: CallLever) -> void: action.call())
	levers[label] = made
	return made


func _onboard(deck: Node3D, label: String, at: Vector3, tint: Color,
		action: Callable) -> CallLever:
	var made := CallLever.make(label, tint, theme)
	deck.add_child(made)
	made.position = at + Vector3(0.0, CallLever.BASE.y * 0.5, 0.0)
	made.pulled.connect(func(_who: CallLever) -> void: action.call())
	levers[label] = made
	return made


func _on_refused(reason: String, detail: String) -> void:
	if _refusal == null:
		return
	_refusal.text = "%s: %s" % [reason.to_upper(), detail]
	_refusal_left = 3.0


func _signs() -> void:
	_sign("ARRIVAL  A", Vector3(V_X, 2.6, V_Z - 5.4),
			Color(0.8, 0.85, 0.95), 52)
	_sign("V  LIFT\nA / TRANSFER / SHELF", Vector3(V_X + 2.8, 2.2, V_Z),
			Color(0.55, 0.9, 1.0), 40)
	_sign("H  SHUTTLE\nWEST <-> EAST (G)",
			Vector3(0.0, TRANSFER_Y + 2.4, H_Z + (PARTED_SHIFT if parted \
			else 0.0)), Color(1.0, 0.72, 0.35), 40)
	_sign("UPPER SHELF", Vector3((SHELF_WEST + SHELF_EAST) * 0.5,
			SHELF_Y + 2.0, SHELF_Z.x + 0.4), Color(0.8, 0.85, 0.95), 46)
	_sign("GOAL GALLERY  G", Vector3(G_WEST + 1.5, TRANSFER_Y + 2.2, 2.2),
			Color(0.55, 1.0, 0.7), 46)
	if development_signs:
		_sign("EX50-011 -- development scenario, not a Zone",
				Vector3(0.0, 1.4, -ROOM_HALF.y + 1.2),
				Color(0.75, 0.7, 0.55), 30)
	_readout = _sign("", Vector3(V_X, 3.4, V_Z - 5.4),
			Color(0.7, 1.0, 0.8), 34)
	_refusal = _sign("", Vector3(V_X, 3.0, V_Z - 5.4),
			Color(1.0, 0.6, 0.5), 34)


# ---------------------------------------------------------------- parts

func _slab(size: Vector3, centre: Vector3, material: Material,
		parent: Node3D = null) -> StaticBody3D:
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
	(parent if parent != null else self as Node3D).add_child(body)
	body.position = centre
	return body


## Both ends given, count and tread solved from them -- the idiom
## `RailwayScenario._stair` settled after a stair that climbed to four
## metres short of what it served. `parent` is where the steps go; the
## service stair keeps its own so a restore and a release build the same
## thing in the same place.
func _stair(foot: Vector3, head: Vector3, width: float,
		parent: Node3D = null) -> void:
	var rise := head.y - foot.y
	var run := Vector3(head.x - foot.x, 0.0, head.z - foot.z)
	if rise <= 0.01 or run.length() < 0.01:
		return
	var steps := maxi(int(ceil(rise / STEP_RISE)), 1)
	var out := run.normalized()
	var tread := run.length() / float(steps)
	var material := ThemeMaterials.trim_mat(theme)
	for i in steps:
		var height := float(i + 1) * rise / float(steps)
		var here := foot + out * (tread * (float(i) + 0.5)) \
				+ Vector3(0.0, height * 0.5, 0.0)
		var step := _slab(Vector3(width, height, tread), here, material,
				parent)
		step.basis = Basis.looking_at(-out, Vector3.UP)


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


# ------------------------------------------------------- what it knows

## `H`'s offset when its deck is centred on `V`'s column.
func rendezvous_offset() -> float:
	return rail.nearest_offset(Vector3(V_X, H_RAIL_Y, H_Z \
			+ (PARTED_SHIFT if parted else 0.0)))


## Where `H` is in this room's frame. `pose()` is what the carrier knows,
## in the frame it was placed in, which is the world once it has taken
## this room's.
func _h_here() -> Vector3:
	var at := h.pose().origin
	return to_local(at) if is_inside_tree() else at


## The straight-line gap a transferring player crosses, deck edge to deck
## edge, measured from what the two machines KNOW rather than from what
## the physics server last published.
func transfer_gap() -> float:
	var v_north := V_Z + DECK.z * 0.5
	var h_south := _h_here().z - DECK.z * 0.5
	return h_south - v_north


## The top face of `V`'s deck right now.
func v_top() -> float:
	return v.offset


## The top face of `H`'s deck right now.
func h_top() -> float:
	return _h_here().y + DECK.y * 0.5


## Room-frame span of `H`'s deck along the track.
func h_span() -> Vector2:
	var x := _h_here().x
	return Vector2(x - DECK.x * 0.5, x + DECK.x * 0.5)
