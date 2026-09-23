class_name UnweightedSwitchHosted
extends Node3D
## EX50-033 AS A ROOM OF A COMPOSED ZONE (O05-06.4).
##
## The room shell `minor_unweighted_switch` (registry pack `minor_rooms`)
## instantiates this. It is `UnweightedSwitchRoom` -- the scenario's own
## room, not a copy -- with the two things a room in a Zone needs and a
## development scenario never had: a way IN through A's wall, and a way
## ON out of G at the gallery's height. Nothing about the puzzle changes:
## the same 16 by 14 m chamber, the same 1.9 m sill, the same crate,
## plate, NOT, shutter, applicator, bolt and return stair. The one thing
## taken out is the scenario's stand-in goal plate: here the goal is the
## Zone's own Check, standing at the shell's objective on the gallery.
##
## **THE SHELL'S FRAME.** Registry convention: the entry socket at the
## origin, the room in +z. The scenario's room stands with A's wall at
## z = -7, so the room is moved by that plus half the wall: the south
## wall's outer face is z = 0, and G's north face is z = 18.5.
##
## **BUILT AT INSTANTIATION.** `_init` builds it whole, so the shell
## validator measures the real room -- its meshes against the declared
## envelope, its socket markers against the declared sockets -- before
## anyone stands in it.
##
## **The Zone owns persistence, not this.** `room.bolt_engaged` is the
## persistent fact; `ZoneController` reports it as a latch and, on load,
## calls `room.restore_bolt()` from the campaign's record.

const SHELL_ID := "minor_unweighted_switch"
const OFFSET := Vector3(0.0, 0.0, UnweightedSwitchRoom.ROOM_HALF.y + 0.25)
## Where the way on leaves G: its east half, clear of the bolt, the goal
## plate and the return gap.
const EXIT_X := 4.5
const DOOR_HALF := 1.2
const DOOR_HEIGHT := 3.2

var room: UnweightedSwitchRoom = null


func _init() -> void:
	name = "UnweightedSwitchHosted"
	room = HostedRoom.new()
	room.name = "Room"
	room.development_signs = false
	room.position = OFFSET
	room.build()
	add_child(room)
	_marker("entry", Vector3.ZERO, 180.0)
	_marker("exit", Vector3(EXIT_X, UnweightedSwitchRoom.SILL_Y,
			OFFSET.z + UnweightedSwitchRoom.G_NORTH + 0.25), 0.0)


## The guide track runs on the host's clock, as it does in the scenario.
func _physics_process(delta: float) -> void:
	room.step(delta)


func _marker(marker_name: String, at: Vector3, yaw: float) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = at
	marker.rotation.y = deg_to_rad(yaw)
	add_child(marker)


## The scenario's room, with a doorway in A's wall and G walled in.
class HostedRoom extends UnweightedSwitchRoom:

	func build() -> void:
		super.build()
		_enclose_g()
		# THE GOAL IS THE ZONE'S CHECK (O05-06.5). The scenario's goal
		# plate stood in for a Check it did not have. Hosted, the room's
		# Check stands at its objective on this gallery, and a second
		# "goal" beside it would be a completion that awards nothing.
		remove_child(goal_plate)
		goal_plate.free()
		goal_plate = null


	## A's wall in three pieces round a doorway on the room's centre line,
	## where the arrival already was.
	func _south_wall(wall: Material) -> void:
		var z := -ROOM_HALF.y
		var span := ROOM_HALF.x - UnweightedSwitchHosted.DOOR_HALF
		_slab(Vector3(span, ROOM_HEIGHT, 0.5),
				Vector3(-(UnweightedSwitchHosted.DOOR_HALF + span * 0.5),
					ROOM_HEIGHT * 0.5, z), wall)
		_slab(Vector3(span, ROOM_HEIGHT, 0.5),
				Vector3(UnweightedSwitchHosted.DOOR_HALF + span * 0.5,
					ROOM_HEIGHT * 0.5, z), wall)
		var lintel := ROOM_HEIGHT - UnweightedSwitchHosted.DOOR_HEIGHT
		_slab(Vector3(UnweightedSwitchHosted.DOOR_HALF * 2.0, lintel, 0.5),
				Vector3(0.0, UnweightedSwitchHosted.DOOR_HEIGHT + lintel * 0.5,
					z), wall)


	## G, walled: west and east at full height from the ground (the space
	## under the gallery floor is closed, not a pit), and north with the
	## way on cut at the gallery's own height.
	func _enclose_g() -> void:
		var wall := ThemeMaterials.wall_mat(theme)
		var mid := ROOM_HEIGHT * 0.5
		var depth := G_NORTH + 0.25 - NORTH_Z
		var along := NORTH_Z + depth * 0.5
		_slab(Vector3(0.5, ROOM_HEIGHT, depth),
				Vector3(G_WEST - 0.25, mid, along), wall)
		_slab(Vector3(0.5, ROOM_HEIGHT, depth),
				Vector3(ROOM_HALF.x, mid, along), wall)
		var x0 := UnweightedSwitchHosted.EXIT_X - UnweightedSwitchHosted.DOOR_HALF
		var x1 := UnweightedSwitchHosted.EXIT_X + UnweightedSwitchHosted.DOOR_HALF
		var west := x0 - G_WEST
		_slab(Vector3(west, ROOM_HEIGHT, 0.5),
				Vector3(G_WEST + west * 0.5, mid, G_NORTH), wall)
		var east := (ROOM_HALF.x - 0.25) - x1
		_slab(Vector3(east, ROOM_HEIGHT, 0.5),
				Vector3(x1 + east * 0.5, mid, G_NORTH), wall)
		# Under the doorway down to the ground, and over it.
		_slab(Vector3(x1 - x0, SILL_Y, 0.5),
				Vector3((x0 + x1) * 0.5, SILL_Y * 0.5, G_NORTH), wall)
		var top := SILL_Y + UnweightedSwitchHosted.DOOR_HEIGHT
		_slab(Vector3(x1 - x0, ROOM_HEIGHT - top, 0.5),
				Vector3((x0 + x1) * 0.5, top + (ROOM_HEIGHT - top) * 0.5,
					G_NORTH), wall)
