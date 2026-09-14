class_name LockedDoor
extends StaticBody3D
## What makes a `LOCKED` door locked: a slab across a real opening.
##
## **The aperture is carved.** A locked door is not an uncut wall -- the
## hole is there, the audit sweeps the capsule through it and requires it
## to be a hole, and this body is what stands in it until the key is
## held. That ordering is deliberate: a lock modelled as "do not carve"
## would be indistinguishable from a `SEALED` door in every measurement,
## and the two are different promises.

signal opened(room_id: String, socket_id: String)

var key_id := ""
## THE CAPABILITY THIS DOOR ASKS FOR, or "" for a plain key lock.
##
## SOLUTIONS_CATALOGUE §0-bis: a local key, a required Check or the Zone
## exit itself may sit behind a hard Echo capability gate, and "NOT YET
## is good gameplay". The owner's example is the shape this serves --
## Epsilon knows a Missile-like capability arrives in Zone 2, so it puts
## that door on a dead-end branch in Zone 1 and fills the branch with
## Checks.
##
## A door may declare a key, a capability, or both; EVERY requirement it
## declares must be satisfied. One field would have forced a choice the
## design does not make.
var requires_capability := ""
var room_id := ""
var socket_id := ""
var colour := "gold"
var is_open := false

static func create(room: String, socket: String, key: String,
		colour_name: String, width: float, height: float,
		capability := "") -> LockedDoor:
	var door := LockedDoor.new()
	door.name = "LockedDoor_%s_%s" % [room, socket]
	door.room_id = room
	door.socket_id = socket
	door.key_id = key
	door.requires_capability = capability
	door.colour = colour_name
	door._build(width, height)
	return door

func _build(width: float, height: float) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.3)
	shape.shape = box
	shape.position = Vector3(0, height / 2.0, 0)
	add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "Slab"
	var slab := BoxMesh.new()
	slab.size = Vector3(width, height, 0.3)
	mesh.mesh = slab
	mesh.position = Vector3(0, height / 2.0, 0)
	mesh.material_override = ThemeMaterials.glow_material(
			ZoneKey.tint(colour), 0.8)
	add_child(mesh)

	var label := Label3D.new()
	# The gate says what it wants. A capability gate labelled by colour
	# would send the player hunting for a key that does not exist.
	label.text = ("%s GATE" % requires_capability.to_upper()) \
			if requires_capability != "" else ("%s LOCK" % colour.to_upper())
	label.position = Vector3(0, height + 0.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.005
	label.modulate = ZoneKey.tint(colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

## Opening is monotone and one-way within a Zone's life.
##
## `ZoneProgress.opened_locks` is a growing set, which is what makes a
## resume safe: a reload can never put the player back behind a door they
## have already opened. So this never re-closes.
func open() -> void:
	if is_open:
		return
	is_open = true
	opened.emit(room_id, socket_id)
	queue_free()

## EVERY declared requirement, not the first one that happens to match.
##
## `capabilities` is what the player currently has, in the vocabulary
## `ACTIVITY_CAPABILITIES` already defines and `available_capabilities`
## already carries -- the one the activity NOT_YET state reads. A second
## source for "what can this player do" would be a second answer to a
## question that already has one.
func try_open(keys_held: Dictionary, capabilities := {}) -> bool:
	if is_open:
		return true
	if key_id != "" and not keys_held.has(key_id):
		return false
	if requires_capability != "" \
			and not capabilities.has(requires_capability):
		return false
	# A door that declares NEITHER is not a lock; refusing to open it
	# would leave an unopenable slab in a carved hole.
	open()
	return true

## What this door is waiting for, for a prompt or a report.
func unmet(keys_held: Dictionary, capabilities := {}) -> PackedStringArray:
	var missing := PackedStringArray()
	if key_id != "" and not keys_held.has(key_id):
		missing.append("key:%s" % key_id)
	if requires_capability != "" \
			and not capabilities.has(requires_capability):
		missing.append("capability:%s" % requires_capability)
	return missing
