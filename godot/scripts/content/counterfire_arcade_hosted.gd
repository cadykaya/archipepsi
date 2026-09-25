class_name CounterfireArcadeHosted
extends HostedMinor
## EX50-021 AS A ROOM OF A COMPOSED ZONE (O05-06.3).
##
## The room shell `minor_counterfire_arcade` (registry pack `minor_rooms`)
## instantiates this. It is `CounterfireArcadeRoom` -- the scenario's own
## room, not a copy -- with what a room in a Zone needs and a development
## scenario never had: a way IN through the arrival arcade's wall, and an
## annex that is closed, because in a Zone there is something on the far
## side of an open edge. Nothing about the relationship changes: the same
## lane, stance, alcove, hooded receiver, eight-second shutter, flank,
## permanent release and west stair.
##
## **THE GUNNER IS THE ZONE'S.** EX50-021 §9: "Enemy position and health
## follow the source encounter persistence rather than a new
## puzzle-owned copy." The chamber declares one `ranged` enemy and the
## shell's `enemy_spawn` volume is the gallery post, so the Zone spawns,
## tracks and persists it like any other; this room builds none.
##
## **A WAY ON, AS EVERY SHELL HAS.** An exit is cut in the annex's far
## wall at the flank's height, beyond the goal, as EX50-033's hosted room
## has one out of its gallery. The candidate step builds a minor as a
## dead end, so it is always `SEALED` there and the Zone closes it.
##
## **THE SHELL'S FRAME.** Registry convention: the entry socket at the
## origin, the room in +z, the envelope centred on x = 0. The room runs
## from the arcade's west wall to the annex's east wall, so it is moved
## west by the middle of that span and north by the arcade's half depth.
##
## **The goal is the Zone's Check**, at the shell's objective on the
## flank; the scenario's stand-in goal plate is taken out.

const SHELL_ID := "minor_counterfire_arcade"
const WEST := -(CounterfireArcadeRoom.ROOM_HALF.x + 0.25)
const EAST := CounterfireArcadeRoom.ANNEX_X.y + 0.25
const CENTRE_X := (WEST + EAST) * 0.5
const OFFSET := Vector3(-CENTRE_X, 0.0, CounterfireArcadeRoom.ROOM_HALF.y
		+ 0.25)
const DOOR_HALF := 1.2
const DOOR_HEIGHT := 3.2
## Where the way on leaves the flank, in the room's frame: its north end,
## clear of the release and the goal.
const EXIT_Z := 6.0

var room: CounterfireArcadeRoom = null


func _init() -> void:
	name = "CounterfireArcadeHosted"
	room = HostedRoom.new()
	room.name = "Room"
	room.with_gunner = false
	room.development_signs = false
	room.position = OFFSET
	room.build()
	add_child(room)
	room.release_engaged.connect(func() -> void: latched.emit("release"))
	room.said.connect(func(text: String) -> void: said.emit(text))
	_marker("entry", Vector3.ZERO, 180.0)
	_marker("exit", Vector3(EAST - CENTRE_X, CounterfireArcadeRoom.FLANK_Y,
			EXIT_Z + OFFSET.z), 90.0)


func restore(latch_ids: Array) -> void:
	if latch_ids.has("release"):
		room.restore_release()


## The scenario's room, entered through its arrival wall, annex closed.
class HostedRoom extends CounterfireArcadeRoom:

	func build() -> void:
		super.build()
		_enclose_annex()
		# THE GOAL IS THE ZONE'S CHECK (O05-06.5).
		remove_child(goal_plate)
		goal_plate.free()
		goal_plate = null


	## The arrival wall in three pieces round a doorway at the envelope's
	## middle, which is where the shell's entry socket is.
	func _south_wall(wall: Material) -> void:
		var z := -ROOM_HALF.y
		var door := CounterfireArcadeHosted.CENTRE_X
		var half := CounterfireArcadeHosted.DOOR_HALF
		var west := (door - half) - (-ROOM_HALF.x)
		var east := ROOM_HALF.x - (door + half)
		_slab(Vector3(west, ROOM_HEIGHT, 0.5),
				Vector3(-ROOM_HALF.x + west * 0.5, ROOM_HEIGHT * 0.5, z),
				wall)
		_slab(Vector3(east, ROOM_HEIGHT, 0.5),
				Vector3(ROOM_HALF.x - east * 0.5, ROOM_HEIGHT * 0.5, z),
				wall)
		var lintel := ROOM_HEIGHT - CounterfireArcadeHosted.DOOR_HEIGHT
		_slab(Vector3(half * 2.0, lintel, 0.5),
				Vector3(door, CounterfireArcadeHosted.DOOR_HEIGHT
					+ lintel * 0.5, z), wall)


	## The annex's far wall in pieces round the way on, at the flank.
	func _annex_east_wall(wall: Material) -> void:
		var x := ANNEX_X.y
		var z0 := -4.5
		var z1 := ROOM_HALF.y - 1.0
		var half := CounterfireArcadeHosted.DOOR_HALF
		var door := CounterfireArcadeHosted.EXIT_Z
		var south := (door - half) - z0
		var north := z1 - (door + half)
		_slab(Vector3(0.4, ROOM_HEIGHT, south),
				Vector3(x, ROOM_HEIGHT * 0.5, z0 + south * 0.5), wall)
		_slab(Vector3(0.4, ROOM_HEIGHT, north),
				Vector3(x, ROOM_HEIGHT * 0.5, z1 - north * 0.5), wall)
		# Under the doorway down to the ground, and over it.
		_slab(Vector3(0.4, FLANK_Y, half * 2.0),
				Vector3(x, FLANK_Y * 0.5, door), wall)
		var top := FLANK_Y + CounterfireArcadeHosted.DOOR_HEIGHT
		_slab(Vector3(0.4, ROOM_HEIGHT - top, half * 2.0),
				Vector3(x, top + (ROOM_HEIGHT - top) * 0.5, door), wall)


	## The annex, closed. The scenario stood in a void, so the annex's
	## open south edge and the unfloored pocket under the flank's west
	## side led nowhere; in a Zone they would lead out of the room. A
	## floor under the pocket, the south wall the annex floor stops at,
	## and the north wall carried back to the arcade.
	func _enclose_annex() -> void:
		var wall := ThemeMaterials.wall_mat(theme)
		var trim := ThemeMaterials.trim_mat(theme)
		var mid := ROOM_HEIGHT * 0.5
		# (No pocket to floor: north of the annex is the room's own solid
		# mass under its upper deck now, PPT-05.)
		_slab(Vector3(15.6 - ROOM_HALF.x, ROOM_HEIGHT, 0.4),
				Vector3((ROOM_HALF.x + 15.6) * 0.5, mid, -4.5), wall)
		# NO NORTH WALL HERE (PPT-06). It stood at z 7.8-8.2 and pinched
		# the only way from the flank over the low wall -- to the gallery,
		# and to the stair the release lowers -- down to 0.8 m, which is
		# the player's own width: the release's return could not be
		# walked. The room's solid north-east corner (PPT-05) closes the
		# pocket instead, and the way over is 1.2 m.
