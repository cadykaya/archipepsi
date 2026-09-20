class_name PoweredLink
extends Node3D

## A PRESSURE PLATE, A SIGNAL, AND A DOOR THAT OPENS WHEN IT IS HELD.
##
## The environmental-agency chain, end to end and no longer than that:
## a physical crate the player shoves onto a plate, a signal the plate
## raises, and a door the signal powers. Nothing in it is a key, an
## activity or a station.
##
## **THE SIGNAL IS LIVE AND IS NEVER SAVED.** `06_THE_AMALGAM.md` §5.4a:
## an accepted consequence persists, and raw live signal values do not.
## `powered` is recomputed from what is standing on the plate every
## physics frame, so a reload comes back with the crate at the position
## the manifest replays it to and the door in whatever state that
## implies. Nothing here writes to a save, and there is deliberately no
## field it could write to.
##
## What DOES persist is the consequence the player took through the open
## door -- a `LocalRewardPickup`, on the same validated path every other
## local reward uses. The Zone remembers what was done to it, not what
## was attempted: a crate nudged halfway and abandoned leaves no record.
##
## **No joints and no attachment sensors.** The plate is an `Area3D` that
## adds up the mass standing in it; the door is a `StaticBody3D` that
## moves. Both are supported mechanisms and neither needs the machinery
## system.

## Emitted when the signal changes, for whatever wants to react to it.
## Carries the new value so a listener never has to ask.
signal powered_changed(now: bool)

## How much mass the plate needs. One crate, with room to spare, so a
## player standing on it themselves does NOT hold it -- the chain has to
## be a crate on a plate rather than a player on a plate, or the crate
## is decoration.
@export var threshold_kg := 60.0

## The plate's own region, in this node's space.
@export var plate_extent := Vector3(1.0, 1.0, 1.0)

## How far the door slides out of the way when powered.
const DOOR_TRAVEL := 3.2

var powered := false

var _plate: Area3D
var _door: StaticBody3D
var _door_shut := Vector3.ZERO
var _lamp: MeshInstance3D

## The whole link, positioned by the caller. `door_at` is where the door
## stands relative to this node.
static func create(theme: String, door_at: Vector3,
		threshold := 60.0) -> PoweredLink:
	var link := PoweredLink.new()
	link.name = "PoweredLink"
	link.threshold_kg = threshold
	link._door_shut = door_at
	link._build(theme)
	return link

func _build(theme: String) -> void:
	_plate = Area3D.new()
	_plate.name = "Plate"
	# MONITORING BODIES, not areas: the thing that holds a plate down is
	# a body with mass.
	_plate.monitorable = false
	var region := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = plate_extent
	region.shape = box
	region.position = Vector3(0, plate_extent.y / 2.0, 0)
	_plate.add_child(region)
	add_child(_plate)

	# The visible pad, so a player can see where the crate goes.
	var pad := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(plate_extent.x, 0.12, plate_extent.z)
	pad.mesh = slab
	pad.position = Vector3(0, 0.06, 0)
	pad.material_override = ThemeMaterials.glow_material(
			Constants.AFFORDANCE_SIGNAL, 0.6)
	_plate.add_child(pad)

	_door = StaticBody3D.new()
	_door.name = "PoweredDoor"
	_door.position = _door_shut
	var leaf := CollisionShape3D.new()
	var slabshape := BoxShape3D.new()
	slabshape.size = Vector3(1.3, 3.0, 0.3)
	leaf.shape = slabshape
	leaf.position = Vector3(0, 1.5, 0)
	_door.add_child(leaf)
	var face := MeshInstance3D.new()
	var facemesh := BoxMesh.new()
	facemesh.size = slabshape.size
	face.mesh = facemesh
	face.position = leaf.position
	face.material_override = ThemeMaterials.trim_mat(theme)
	_door.add_child(face)
	add_child(_door)

	# The lamp is the only presentation channel here and it reads the
	# same live value the door does -- a second source would be a second
	# truth about whether the thing is powered.
	_lamp = MeshInstance3D.new()
	var bulb := BoxMesh.new()
	bulb.size = Vector3(0.3, 0.3, 0.3)
	_lamp.mesh = bulb
	_lamp.position = _door_shut + Vector3(0.0, 2.4, -0.4)
	add_child(_lamp)
	_paint()

func _physics_process(_delta: float) -> void:
	var now := mass_on_plate() >= threshold_kg
	if now == powered:
		return
	powered = now
	# THE DOOR IS THE SIGNAL, not a copy of it. It moves here and
	# nowhere else, so there is no state that can disagree with the
	# plate.
	_door.position = _door_shut + (Vector3.DOWN * DOOR_TRAVEL
			if powered else Vector3.ZERO)
	_paint()
	powered_changed.emit(powered)

## What is standing on the plate right now, in kilograms.
##
## Only `ManipulableBody`: a player standing on it is a player, and an
## enemy wandering over it is content. Reading every overlapping body
## would make the chain solvable by standing there, and then the crate
## would be scenery.
func mass_on_plate() -> float:
	var carried := 0.0
	for node: Node3D in _plate.get_overlapping_bodies():
		var body := node as ManipulableBody
		if body != null:
			carried += body.mass
	return carried

## Where a body has to end up. Handed out so a test aims at the same
## point the geometry uses rather than at a number typed twice.
func plate_position() -> Vector3:
	return _plate.global_position

func door_position() -> Vector3:
	return _door.global_position

## Is the doorway clear? Asked of the physics server, because "the node
## moved" and "a body can get through" are different claims and only the
## second one is the outcome.
func doorway_is_clear(space: PhysicsDirectSpaceState3D) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = Constants.PLAYER_RADIUS
	capsule.height = Constants.PLAYER_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collide_with_areas = false
	query.transform = Transform3D(Basis(), global_transform
			* (_door_shut + Vector3.UP * (Constants.PLAYER_HEIGHT / 2.0
				+ 0.05)))
	return space.intersect_shape(query, 1).is_empty()

func _paint() -> void:
	_lamp.material_override = ThemeMaterials.glow_material(
			Constants.AFFORDANCE_SIGNAL if powered else Color(0.2, 0.2, 0.24),
			2.4 if powered else 0.2)
