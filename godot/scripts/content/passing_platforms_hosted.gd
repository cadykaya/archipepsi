class_name PassingPlatformsHosted
extends HostedMinor
## EX50-011 AS A ROOM OF A COMPOSED ZONE (O05-06.2).
##
## The room shell `minor_passing_platforms` (registry pack `minor_rooms`)
## instantiates this. It is `PassingPlatformsRoom` -- the scenario's own
## room, not a copy -- with what a room in a Zone needs and a development
## scenario never had: a way IN through the arrival wall, and a way on
## behind the goal gallery that the Zone seals, because in a Zone there is
## something on the far side of an open wall. Nothing about the
## relationship changes: the same lift and its dwell, the same shuttle,
## the same calls, STOP and RESET, the same recovery floor and shelf, and
## the same service stair the gallery releases.
##
## **THE SHELL'S FRAME.** Registry convention: the entry socket at the
## origin, the room in +z, the envelope centred on x = 0. The room's
## walls already centre on x = 0, so it only moves north by its half
## depth and the doorway is cut in the arrival wall at x = 0, on `A`.
##
## **What the Zone keeps (EX50-011 §9).** The service stair is the
## minor's latch, `minor_<room>/stair`. Each carrier's rest -- pose,
## destination and hold -- is `minor_<room>/<carrier>`, reported only at
## rest and put back before the player arrives. Before completion, a
## death sends both carriers home by ordinary motion; after it, they stay
## where the player left them.
##
## **The goal is the Zone's Check**, at the shell's objective on `G`,
## behind the glass the shuttle's gate opens (H-PASSING). An arrival
## anywhere on `G` releases the stair -- §4's "arriving at G", not a
## reward; the plate on `G` stays as it was.

const SHELL_ID := "minor_passing_platforms"
const OFFSET := Vector3(0.0, 0.0, PassingPlatformsRoom.ROOM_HALF.y + 0.25)
const DOOR_HALF := 1.2
const DOOR_HEIGHT := 3.2
## The way on, in the wall behind `G` and at `G`'s height. The Zone seals
## it (`contract.sealed_sockets`).
const EXIT_Z := 2.5

var room: PassingPlatformsRoom = null


func _init() -> void:
	name = "PassingPlatformsHosted"
	room = HostedRoom.new()
	room.name = "Room"
	room.development_signs = false
	room.position = OFFSET
	room.build()
	add_child(room)
	room.stair_engaged.connect(func() -> void: latched.emit("stair"))
	room.said.connect(func(text: String) -> void: said.emit(text))
	room.carrier_rested.connect(func(carrier_id: String, t: float,
			destination: String, held: bool) -> void:
		carrier_rested.emit(carrier_id, t, destination, held))
	_marker("entry", Vector3.ZERO, 180.0)
	_marker("exit", Vector3(PassingPlatformsRoom.ROOM_HALF.x + 0.25,
			PassingPlatformsRoom.TRANSFER_Y, EXIT_Z + OFFSET.z), 90.0)


func restore(latch_ids: Array) -> void:
	if latch_ids.has("stair"):
		room.restore_stair()


func restore_carriers(states: Dictionary) -> void:
	for carrier_id: Variant in states:
		var rest: Array = states[carrier_id]
		room.restore_carrier(str(carrier_id), float(rest[0]), str(rest[1]),
				bool(rest[2]))


## §9: "Before completion, death/reset restores the safe initial transport
## configuration" -- by the ordinary commands (§8: never an instant
## relocation into a dock). The Zone respawns the player elsewhere, so
## the decks are empty when they move. After completion the stair makes
## the carriers unnecessary, and they stay where they were left.
func player_died() -> void:
	if not room.stair_released:
		room.reset_carriers()


## The scenario's room, entered through its arrival wall, its way on cut
## behind the gallery for the Zone to seal.
class HostedRoom extends PassingPlatformsRoom:

	## The arrival wall in pieces round a doorway at x = 0 on `A`, which is
	## where the shell's entry socket is. The wall stands from a metre
	## below the floor, so the doorway keeps a sill piece under it.
	func _south_wall(wall: Material) -> void:
		var z := -ROOM_HALF.y
		var half := PassingPlatformsHosted.DOOR_HALF
		var top := PassingPlatformsHosted.DOOR_HEIGHT
		var bottom := -1.0
		var height := ROOM_HEIGHT
		var side := ROOM_HALF.x - half
		_slab(Vector3(side, height, 0.5),
				Vector3(-ROOM_HALF.x + side * 0.5, bottom + height * 0.5, z),
				wall)
		_slab(Vector3(side, height, 0.5),
				Vector3(ROOM_HALF.x - side * 0.5, bottom + height * 0.5, z),
				wall)
		var lintel := bottom + height - top
		_slab(Vector3(half * 2.0, lintel, 0.5),
				Vector3(0.0, top + lintel * 0.5, z), wall)
		_slab(Vector3(half * 2.0, -bottom, 0.5),
				Vector3(0.0, bottom * 0.5, z), wall)


	## The wall behind `G`, in pieces round the way on at `G`'s height.
	func _east_wall(wall: Material) -> void:
		var x := ROOM_HALF.x
		var half := PassingPlatformsHosted.DOOR_HALF
		var door := PassingPlatformsHosted.EXIT_Z
		var sill := TRANSFER_Y
		var top := sill + PassingPlatformsHosted.DOOR_HEIGHT
		var bottom := -1.0
		var ceiling := bottom + ROOM_HEIGHT
		var south := (door - half) - (-ROOM_HALF.y)
		var north := ROOM_HALF.y - (door + half)
		_slab(Vector3(0.5, ROOM_HEIGHT, south),
				Vector3(x, bottom + ROOM_HEIGHT * 0.5,
					-ROOM_HALF.y + south * 0.5), wall)
		_slab(Vector3(0.5, ROOM_HEIGHT, north),
				Vector3(x, bottom + ROOM_HEIGHT * 0.5,
					ROOM_HALF.y - north * 0.5), wall)
		_slab(Vector3(0.5, sill - bottom, half * 2.0),
				Vector3(x, (bottom + sill) * 0.5, door), wall)
		_slab(Vector3(0.5, ceiling - top, half * 2.0),
				Vector3(x, (top + ceiling) * 0.5, door), wall)
