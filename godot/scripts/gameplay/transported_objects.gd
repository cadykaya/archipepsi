class_name TransportedObjects
extends Node
## OBJECTS THE PLAYER CARRIES BETWEEN ROOMS — P16's engine half.
##
## D-8 lifetime 5, the row that was explicitly unfinished (M7) and that
## the owner named twice as an open 0.4 item. The bridge lane declares
## `Zone.transported_objects`; this is what builds one, notices when it
## has crossed a boundary, and reports where it now is.
##
## **THE AUTHORITY RULE, which is the whole of why this class exists
## rather than a field on the crate.** D-8 §11.1, narrowed from this
## lane's own proposal: a transported object is **room-layer state whose
## owning room is its current room**, and crossing a boundary is a
## TRANSFER rather than a write to the machine layer. So §19.7 rule 2
## stays intact, no room addresses another, and the player carrying it is
## "the player is the bridge" in its most literal form.
##
## **WHAT PERSISTS IS THE ROOM AND NOTHING ELSE ABOUT IT.** §5.1 puts
## every `ActiveStatus` in `EPHEMERAL`, so a burning cell carried three
## rooms arrives having been carried three rooms and **not still
## burning**. Persisting the Status would turn a temporary effect into a
## permanent fact, which is the one place that rule is easiest to break
## by accident -- so this class has no field it could put one in, and
## `ManipulableBody.statuses` is deliberately not consulted here.
##
## **A ROOM IS DECIDED BY GEOMETRY, not by who last touched it.** The
## owning room is whichever committed room bounds contain the object,
## asked of `ZoneController.room_bounds`. An object between rooms keeps
## the room it had, because a doorway is not a third place.

## The object moved to a room it was not in. Carries the id and the room
## so a consumer never has to ask.
signal transported(object_id: String, room_id: String)
## The object left its allowed volume and was put back home.
signal recovered(object_id: String, room_id: String)

## `object_id -> {body, volume, home, required, room}`.
var _held: Dictionary = {}
var _bounds: Dictionary = {}


## Take the Zone's declaration, the committed room bounds, and whatever
## the snapshot said about where these objects were left.
##
## `carried` is `ZoneProgress.object_rooms` as a Dictionary: the room and
## nothing else, overwritten rather than accumulated, exactly as the
## contract stores it.
func declare(objects: Array, bounds: Dictionary, carried: Dictionary,
		places: Dictionary, root: Node3D) -> Array[String]:
	var refused: Array[String] = []
	_bounds = bounds
	for raw: Variant in objects:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = raw
		var id := str(one.get("object_id", ""))
		var volume: Array = one.get("allowed_volume", []) as Array
		var home := str(one.get("home_room_id", ""))
		if volume.size() < 2:
			refused.append("object '%s' declares a volume of %d room(s)"
					% [id, volume.size()])
			continue
		var unbuilt: Array[String] = []
		for room: Variant in volume:
			if not places.has(str(room)):
				unbuilt.append(str(room))
		if not unbuilt.is_empty():
			refused.append("object '%s' may be in %s, which this Zone did "
					% [id, unbuilt] + "not build")
			continue
		# WHERE IT IS NOW: the snapshot's room if it named one INSIDE the
		# volume, else home. A saved room outside the volume is not
		# trusted -- that is exactly the invalid-object case recovery
		# exists for, and honouring it would place the object somewhere
		# it may not be.
		var room_now := str(carried.get(id, home))
		if not room_now in volume:
			room_now = home
		var body := ManipulableBody.create("carry_%s" % id, 18.0,
				Vector3(0.7, 0.7, 0.7))
		body.name = "Transported_%s" % id
		root.add_child(body)
		body.global_position = (places[room_now] as Dictionary).get(
				"arrival", Vector3.ZERO) as Vector3 + Vector3(1.6, 0.6, 0.0)
		_held[id] = {
			"body": body, "volume": volume, "home": home,
			"required": bool(one.get("required", false)),
			"room": room_now,
		}
	return refused


func ids() -> Array:
	var out: Array = _held.keys()
	out.sort()
	return out


func body_of(object_id: String) -> ManipulableBody:
	if not _held.has(object_id):
		return null
	return (_held[object_id] as Dictionary)["body"]


## Which room this object is currently the responsibility of.
func room_of(object_id: String) -> String:
	if not _held.has(object_id):
		return ""
	return str((_held[object_id] as Dictionary)["room"])


func is_required(object_id: String) -> bool:
	if not _held.has(object_id):
		return false
	return bool((_held[object_id] as Dictionary)["required"])


## What the save would carry: the room, per object, and nothing else.
func as_reported() -> Dictionary:
	var out := {}
	for id: Variant in _held:
		out[str(id)] = str((_held[id] as Dictionary)["room"])
	return out


## Watch for crossings. Cheap on purpose: a handful of objects against a
## handful of room boxes, and only a CHANGE does anything.
func _physics_process(_delta: float) -> void:
	for id: Variant in _held:
		var entry: Dictionary = _held[id]
		var body: ManipulableBody = entry["body"]
		if body == null or not is_instance_valid(body):
			continue
		var found := _room_containing(body.global_position)
		if found == "":
			# BETWEEN ROOMS IS NOT A PLACE. A doorway, a connector or a
			# metre of air over a gap keeps whatever room it had, so a
			# carry across a threshold reports once rather than
			# flickering.
			continue
		if found == str(entry["room"]):
			continue
		if not found in (entry["volume"] as Array):
			# OUT OF BOUNDS: this is the invalid-object case, and the
			# contract's answer is recovery rather than refusal. Putting
			# it back is what keeps a `required` object from being lost
			# somewhere a puzzle can never reach it.
			_recover(str(id), entry)
			continue
		entry["room"] = found
		transported.emit(str(id), found)


## Put an object back where it comes home to.
func _recover(object_id: String, entry: Dictionary) -> void:
	var home := str(entry["home"])
	entry["room"] = home
	var body: ManipulableBody = entry["body"]
	var box: AABB = _bounds.get(home, AABB())
	if box.size != Vector3.ZERO:
		body.global_position = box.position + box.size * 0.5 \
				+ Vector3(0.0, 1.0, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	recovered.emit(object_id, home)
	transported.emit(object_id, home)


## Which committed room contains this point, or "" for none.
func _room_containing(at: Vector3) -> String:
	for room: Variant in _bounds:
		var box: AABB = _bounds[room]
		if box.size == Vector3.ZERO:
			continue
		if box.has_point(at):
			return str(room)
	return ""
