class_name StationAreaTwo
extends Node3D
## STATION AREA 2 (D-22 slice, `docs/D22_SLICE_BRIEF.md` §2 step 7).
##
## Graybox, built beside the Hub through a doorway in its right wall:
##
##   Hub ── DOOR (lamp) ── corridor ── room: LEVER → SHUTTER ── the Forge
##
## * THE DOOR opens when `completed_zone_count >= 1`. It is read from the
##   snapshot every refresh and never saved: an abandon cannot move it, a
##   relaunch finds it where the count puts it.
## * THE MACHINERY is base kit: a CallLever commands a ServiceShutter, both
##   the campaign line's own parts. No Checks, no Echo, no enemies.
## * THE FORGE beyond it is the same console screen as area 1's.
##
## Only built in a slice run (`D22Slice.active()`).

signal forge_used

const THEME := "concrete_facility"
## Where the doorway is cut in the Hub's right wall: clear of the Echo
## Archive (z 6..8.4) and the controls board (z 7.9..11.9).
const DOOR_Z := 3.6
const DOOR_W := ChamberBuilders.DOOR_WIDTH
const DOOR_H := ChamberBuilders.DOOR_HEIGHT
const HUB_WALL_X := HubAnchors.W / 2.0
const CORRIDOR_RUN := 6.0
const ROOM_W := 12.0
const ROOM_D := 12.0
const ROOM_H := 4.5
const PARTITION_AT := 6.0      # metres into the room, from its west wall
const LAMP_RED := Color(1.0, 0.18, 0.12)
const LAMP_GREEN := Color(0.25, 1.0, 0.45)

## In-memory only, per process: whether this run has watched the count it
## is now showing, so the lamp's red -> green plays when the count RISES
## (on arrival, if it rose while the player was away) and not on a
## relaunch, which simply finds the door open. And the shutter, once
## levered open this run, is not shut again by a trip into a Crossing.
static var _seen_count := -1
static var _shutter_open := false

var door: StaticBody3D
var lamp: MeshInstance3D
var lever: CallLever
var shutter: ServiceShutter
var forge: Node3D
var _door_label: Label3D
var _door_open := false
var _door_anim := -1.0


func _ready() -> void:
	name = "StationAreaTwo"
	_build()
	var count := D22Slice.untethered_count()
	# Settled to what the count says, with no moment, unless this run
	# already saw a lower count -- then the moment plays.
	var play := _seen_count >= 0 and count > _seen_count and count >= 1
	_set_door(count >= 1 and not play, false)
	if play:
		_open_with_moment.call_deferred()
	_seen_count = count
	_refresh_label()


## Every snapshot. The door follows the derived count; when it rises while
## the player is standing in the station, the moment plays there and then.
func refresh() -> void:
	var count := D22Slice.untethered_count()
	if count >= 1 and not _door_open and _door_anim < 0.0:
		_open_with_moment()
	elif count < 1 and _door_open:
		_set_door(false, false)
	_seen_count = count
	_refresh_label()


func door_open() -> bool:
	return _door_open


func lamp_is_green() -> bool:
	return _door_open


## Where a player stands to use each thing, for drivers walking the route.
func door_point() -> Vector3:
	return Vector3(HUB_WALL_X, 0, DOOR_Z)


func lever_point() -> Vector3:
	return lever.global_position


func forge_point() -> Vector3:
	return forge.global_position


func _process(delta: float) -> void:
	if _door_anim < 0.0:
		return
	# Red holds a beat, flips green, then the slab sinks.
	_door_anim += delta
	if _door_anim > 0.6 and not _door_open:
		_door_open = true
		_paint_lamp()
		_refresh_label()
	if _door_anim > 0.6:
		var k := clampf((_door_anim - 0.6) / 0.9, 0.0, 1.0)
		door.position.y = DOOR_H / 2.0 - k * (DOOR_H + 0.2)
		if k >= 1.0:
			_door_anim = -1.0
			door.get_node("Shape").disabled = true


func _open_with_moment() -> void:
	_door_anim = 0.0


func _set_door(open: bool, _animate: bool) -> void:
	_door_open = open
	_door_anim = -1.0
	door.position.y = -DOOR_H / 2.0 - 0.2 if open else DOOR_H / 2.0
	door.get_node("Shape").disabled = open
	_paint_lamp()


func _paint_lamp() -> void:
	lamp.material_override = ThemeMaterials.glow_material(
			LAMP_GREEN if _door_open else LAMP_RED, 1.2)


func _refresh_label() -> void:
	var count := D22Slice.untethered_count()
	_door_label.text = "STATION AREA 2\n%s" % ("OPEN" if _door_open
			else "UNTETHER 1 CROSSING TO OPEN — %d/1" % mini(count, 1))
	_door_label.modulate = LAMP_GREEN if _door_open else Color(1.0, 0.6, 0.5)


# -- geometry --------------------------------------------------------------------

func _build() -> void:
	var b := ChamberBuilders
	var floor_mat := ThemeMaterials.floor_mat(THEME)
	var wall_mat := ThemeMaterials.wall_mat(THEME)
	var trim_mat := ThemeMaterials.trim_mat(THEME)
	var t := ChamberBuilders.WALL_THICKNESS

	# THE DOOR, in the Hub wall's own gap, with its lamp on the Hub side.
	door = StaticBody3D.new()
	door.name = "Area2Door"
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, DOOR_H, DOOR_W)
	shape.shape = box
	door.add_child(shape)
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = box.size
	slab.mesh = slab_mesh
	slab.material_override = ThemeMaterials.accent_mat(THEME)
	door.add_child(slab)
	add_child(door)
	door.position = Vector3(HUB_WALL_X, DOOR_H / 2.0, DOOR_Z)
	lamp = MeshInstance3D.new()
	lamp.name = "Area2Lamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.2, 0.35, 0.6)
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(HUB_WALL_X - 0.3, DOOR_H + 0.4, DOOR_Z)
	add_child(lamp)
	_door_label = Label3D.new()
	_door_label.font_size = 32
	_door_label.pixel_size = 0.006
	_door_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door_label.position = Vector3(HUB_WALL_X - 0.3, DOOR_H + 1.05, DOOR_Z)
	_door_label.rotation_degrees = Vector3(0, -90, 0)
	add_child(_door_label)

	# THE CORRIDOR, butted against the Hub wall's outer face.
	var x0 := HUB_WALL_X + t / 2.0
	var mid := x0 + CORRIDOR_RUN / 2.0
	b._box(self, Vector3(CORRIDOR_RUN, 0.5, DOOR_W),
			Vector3(mid, -0.25, DOOR_Z), floor_mat)
	b._box(self, Vector3(CORRIDOR_RUN, 0.4, DOOR_W),
			Vector3(mid, DOOR_H + 0.2, DOOR_Z), trim_mat)
	for side: float in [-1.0, 1.0]:
		b._box(self, Vector3(CORRIDOR_RUN, DOOR_H, t),
				Vector3(mid, DOOR_H / 2.0, DOOR_Z + side * (DOOR_W / 2.0 + t / 2.0)),
				wall_mat)
	b._light(self, Vector3(mid, DOOR_H - 0.3, DOOR_Z), THEME, 7.0)

	# THE ROOM: west wall with the corridor's opening, a partition with the
	# shutter's opening, and the Forge at the far end.
	var rx0 := x0 + CORRIDOR_RUN
	var rz0 := DOOR_Z - ROOM_D / 2.0
	var cx := rx0 + ROOM_W / 2.0
	b._box(self, Vector3(ROOM_W, 0.5, ROOM_D),
			Vector3(cx, -0.25, DOOR_Z), floor_mat)
	b._box(self, Vector3(ROOM_W, t, ROOM_D),
			Vector3(cx, ROOM_H, DOOR_Z), trim_mat)
	for side: float in [-1.0, 1.0]:
		b._box(self, Vector3(ROOM_W, ROOM_H, t),
				Vector3(cx, ROOM_H / 2.0, DOOR_Z + side * ROOM_D / 2.0), wall_mat)
	b._box(self, Vector3(t, ROOM_H, ROOM_D),
			Vector3(rx0 + ROOM_W, ROOM_H / 2.0, DOOR_Z), wall_mat)
	_wall_with_opening(rx0, rz0, wall_mat)
	var px := rx0 + PARTITION_AT
	_wall_with_opening(px, rz0, wall_mat)
	b._light(self, Vector3(rx0 + PARTITION_AT / 2.0, ROOM_H - 0.4, DOOR_Z),
			THEME, 10.0)
	b._light(self, Vector3(px + (ROOM_W - PARTITION_AT) / 2.0, ROOM_H - 0.4,
			DOOR_Z), THEME, 10.0)

	# THE MACHINERY: pull the lever, the shutter in the partition rises.
	shutter = ServiceShutter.create(Vector3(px, DOOR_H / 2.0, DOOR_Z),
			Vector3(DOOR_W, DOOR_H, 0.3), DOOR_H + 0.1, THEME)
	shutter.rotation.y = PI / 2.0
	add_child(shutter)
	shutter.settle(_shutter_open)
	lever = CallLever.make("OPEN THE SHUTTER", Color(1.0, 0.75, 0.3), THEME)
	add_child(lever)
	lever.position = Vector3(px - 1.6, CallLever.BASE.y / 2.0, DOOR_Z + 2.6)
	if _shutter_open:
		lever.lock("SHUTTER OPEN")
	lever.pulled.connect(_on_lever)
	var hint := Label3D.new()
	hint.text = "SHUTTER CONTROL"
	hint.font_size = 28
	hint.pixel_size = 0.006
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.position = lever.position + Vector3(0, 1.6, 0)
	hint.modulate = Color(1.0, 0.8, 0.5)
	add_child(hint)

	# THE SECOND FORGE, the same console as area 1's portal opens.
	var station := HubController.SimpleStation.new()
	station.label_text = "THE FORGE — AREA 2"
	station.prompt = "[E] USE THE FORGE"
	station.station_color = Color(1.0, 0.7, 0.3)
	add_child(station)
	station.position = Vector3(rx0 + ROOM_W - 1.4, 0, DOOR_Z)
	station.rotation.y = PI / 2.0
	station.used.connect(func() -> void: forge_used.emit())
	forge = station


## A north-south wall across the room at `x`, with a door-sized opening at
## the doorway's z: two side pieces and a lintel, as `_side_wall_with_gap`
## does for the Hub, because `_box` is collider and mesh both.
func _wall_with_opening(x: float, rz0: float, mat: Material) -> void:
	var b := ChamberBuilders
	var t := ChamberBuilders.WALL_THICKNESS
	var low := (DOOR_Z - DOOR_W / 2.0) - rz0
	var high := (rz0 + ROOM_D) - (DOOR_Z + DOOR_W / 2.0)
	b._box(self, Vector3(t, ROOM_H, low),
			Vector3(x, ROOM_H / 2.0, rz0 + low / 2.0), mat)
	b._box(self, Vector3(t, ROOM_H, high),
			Vector3(x, ROOM_H / 2.0, rz0 + ROOM_D - high / 2.0), mat)
	b._box(self, Vector3(t, ROOM_H - DOOR_H, DOOR_W),
			Vector3(x, DOOR_H + (ROOM_H - DOOR_H) / 2.0, DOOR_Z), mat)


func _on_lever(_pulled: CallLever) -> void:
	if _shutter_open:
		return
	_shutter_open = true
	shutter.command(true)
	lever.lock("SHUTTER OPEN")
