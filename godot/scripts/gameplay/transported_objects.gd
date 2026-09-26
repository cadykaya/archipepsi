class_name TransportedObjects
extends Node
## OBJECTS THE PLAYER CARRIES BETWEEN ROOMS — P16's engine half.
##
## D-8 lifetime 5. The bridge lane declares `Zone.transported_objects`;
## this builds each one ONCE, notices when it has crossed a boundary,
## reports where it now is and where it came to rest, and recovers it
## under §10.4's rules when it is lost.
##
## **THE AUTHORITY RULE.** D-8 §11.1: a transported object is
## **room-layer state whose owning room is its current room**, and
## crossing a boundary is a TRANSFER rather than a write to the machine
## layer. §19.7 rule 2 stays intact, no room addresses another, and the
## player carrying it is "the player is the bridge" in its most literal
## form. The bridge is authoritative for identity, room, pose and
## consumption; this class proves and performs the world half and holds
## no copy of its own that could outlive a snapshot.
##
## **WHAT PERSISTS: the room, a settled pose, and consumption** (O05-03,
## Amalgam §5.6 step 10 and §30.6.1). A pose is reported only once the
## object has come to rest -- never mid-carry or mid-fall, §5.3's rule
## against saving a moving body.
##
## **STATUSES ARE NOT SAVED, AND A DOORWAY DOES NOT CLEANSE THEM.**
## (CORRECTED 2026-09-22, owner; this header used to say a burning cell
## "arrives not still burning", which conflated a save with a doorway.)
## §5.1 puts every `ActiveStatus` in `EPHEMERAL`, so nothing here writes
## one anywhere. But carrying an object through a door during play is
## not a reload: the SAME body crosses, with its `StatusEffects`, and the
## Status runs out on its own clock.
##
## **A ROOM IS DECIDED BY GEOMETRY**, not by who last touched it: the
## committed room bounds containing the object. An object between rooms
## keeps the room it had, because a doorway is not a third place -- and
## that is also why being outside every room box for a moment, in a
## connector, never sends it home.
##
## **§10.4 RECOVERY, with its delays:**
## - it LEAVES its allowed volume (inside a room it may not be in):
##   home after 1.0 s there, and not before -- carried back in time, it
##   stays with the player;
## - it is OUT OF BOUNDS -- below the kill plane, or outside the Zone's
##   whole extent (every room merged, grown by a margin) -- home at once.
##   A connector is NOT out of bounds, however far its middle lies from
##   the nearest room box: measuring from room boxes sent a cell home
##   from the middle of a long connector in the played acceptance;
## - it is DESTROYED (the body is gone): the same identity reappears at
##   home after 2.0 s.
## Semantic identity survives every one of these. §10.4's fourth trigger,
## "at rest 5 s where the player cannot reach it", needs a reachability
## answer the engine does not have for an arbitrary resting point; it is
## not implemented, and it is named here rather than approximated.

## The object moved to a room it was not in.
signal transported(object_id: String, room_id: String)
## The object was put back home: left its volume, fell out of the Zone,
## or was destroyed.
signal recovered(object_id: String, room_id: String)
## The object came to rest somewhere new (O05-03's settled pose).
signal settled(object_id: String, room_id: String, position: Vector3,
		yaw: float)

## §10.4's delays.
const LEAVE_VOLUME_S := 1.0
const DESTROYED_S := 2.0
## Outside the Zone's merged extent grown by this much is out of bounds.
const OUT_OF_BOUNDS_M := 6.0
## At rest: slower than this for this long.
const REST_SPEED := 0.08
const REST_S := 0.5
## A new pose is worth reporting when it moved at least this far.
const POSE_EPSILON_M := 0.05
## THE ART LANE'S POWER_CELL INTERFACE, runtime X · Y-up · Z
## (`docs/art/BATCH_043_INTEGRATION.md` §4). The dimensions only: the
## model itself is PROPOSAL-status and is not bound here (O05-14.1
## binds approved assets only), so the body is procedural.
const CELL_SIZE := Vector3(0.34, 0.60, 0.34)
## A declaration that names no kilograms is the pre-P16 fixture's crate.
const LEGACY_MASS_KG := 18.0
const LEGACY_SIZE := Vector3(0.7, 0.7, 0.7)
## Where a fresh object stands, relative to its room's arrival and TURNED
## WITH THE ROOM: a couple of metres in from the way in, a step to one
## side, then kept clear of the room's own walls. (The first cut offset
## 1.6 m along world x and put the cell on the edge of a 6.8 m corridor's
## box, which the played acceptance caught.)
const SPAWN_OFFSET := Vector3(1.2, 0.0, 2.2)
const SPAWN_WALL_MARGIN := 1.0

## `object_id -> {body, volume, home, home_at, required, room, consumed,
## mass, carriable, size, away, gone, rest, pose_at, pose_yaw}`.
var _held: Dictionary = {}
var _bounds: Dictionary = {}
## Every room merged: the Zone's own extent, connectors included between.
var _extent := AABB()
var _places: Dictionary = {}
var _root: Node3D = null


## Take the Zone's declaration, the committed room bounds and places, and
## whatever the snapshot said about these objects.
##
## `carried` is `ZoneProgress.object_rooms` as `{object_id: room}`;
## `poses` is `object_poses` as `{object_id: [room, Vector3, yaw]}`;
## `consumed` is `consumed_objects` as `{object_id: mechanism_id}`.
func declare(objects: Array, bounds: Dictionary, carried: Dictionary,
		places: Dictionary, root: Node3D, poses: Dictionary = {},
		consumed: Dictionary = {}) -> Array[String]:
	var refused: Array[String] = []
	_bounds = bounds
	_places = places
	_root = root
	_extent = AABB()
	var first := true
	for room: Variant in bounds:
		var box: AABB = bounds[room]
		if box.size == Vector3.ZERO:
			continue
		_extent = box if first else _extent.merge(box)
		first = false
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
		var declared_mass: Variant = one.get("mass_kg")
		var legacy := declared_mass == null
		var entry := {
			"volume": volume, "home": home,
			"required": bool(one.get("required", false)),
			"mass": LEGACY_MASS_KG if legacy else float(declared_mass),
			"carriable": false if legacy else bool(one.get("carriable",
					false)),
			"size": LEGACY_SIZE if legacy else CELL_SIZE,
			"consumed": str(consumed.get(id, "")),
			"body": null, "away": 0.0, "gone": 0.0, "rest": 0.0,
		}
		entry["home_at"] = _spawn_point(home, entry["size"] as Vector3)
		# WHERE IT IS NOW: the snapshot's room if it named one INSIDE the
		# volume, else home. A saved room outside the volume is not
		# trusted -- that is exactly the invalid-object case recovery
		# exists for.
		var room_now := str(carried.get(id, home))
		if not room_now in volume:
			room_now = home
		entry["room"] = room_now
		_held[id] = entry
		# AN INSTALLED OBJECT IS NOT REBUILT LOOSE. Its consumer shows it
		# installed; building it here as well would be the second copy
		# O05-02.4 forbids, in the room the player carried it from.
		if str(entry["consumed"]) != "":
			continue
		# AT ITS SETTLED POSE when the save has one in the room it is in,
		# else at that room's spawn point. Never in a socket.
		var at: Vector3 = _spawn_point(room_now, entry["size"] as Vector3)
		var yaw := 0.0
		var pose: Variant = poses.get(id)
		if typeof(pose) == TYPE_ARRAY and (pose as Array).size() == 3 \
				and str((pose as Array)[0]) == room_now:
			at = (pose as Array)[1]
			yaw = float((pose as Array)[2])
		_spawn(id, entry, at, yaw)
	return refused


## The body for `object_id`, built the one way every copy is built.
static func make_body(object_id: String, mass_kg: float, size: Vector3,
		carriable: bool, required: bool) -> ManipulableBody:
	var body := ManipulableBody.create("carry_%s" % object_id, mass_kg,
			size)
	body.name = "Transported_%s" % object_id
	body.carriable = carriable
	body.set_meta("object_id", object_id)
	var look := MeshInstance3D.new()
	look.name = "look"
	var mesh := BoxMesh.new()
	mesh.size = size
	look.mesh = mesh
	look.material_override = ThemeMaterials.glow_material(
			Color(0.95, 0.75, 0.25), 0.9)
	body.add_child(look)
	if required:
		# §21.2 PROTECTS THIS OBJECT THE WAY IT PROTECTS THE PLAYER. A
		# door's interlock refuses to close on "the player or any
		# `required = true` object", and asks that of whatever body is in
		# the doorway -- so `required` is readable off the body itself.
		body.add_to_group(Constants.REQUIRED_OBJECT_GROUP)
	return body


func _spawn(object_id: String, entry: Dictionary, at: Vector3,
		yaw: float) -> ManipulableBody:
	var body := make_body(object_id, float(entry["mass"]),
			entry["size"] as Vector3, bool(entry["carriable"]),
			bool(entry["required"]))
	_root.add_child(body)
	body.global_position = at
	body.rotation.y = yaw
	entry["body"] = body
	entry["pose_at"] = at
	entry["pose_yaw"] = yaw
	entry["rest"] = 0.0
	entry["away"] = 0.0
	entry["gone"] = 0.0
	return body


## A floor point in `room`, lifted by half the object so it stands on it.
func _spawn_point(room: String, size: Vector3) -> Vector3:
	var place: Dictionary = _places.get(room, {}) as Dictionary
	var arrival: Vector3 = place.get("arrival", Vector3.ZERO)
	var at := arrival + Basis(Vector3.UP, float(place.get("yaw", 0.0))) \
			* SPAWN_OFFSET
	var box: AABB = _bounds.get(room, AABB())
	if box.size != Vector3.ZERO:
		var lo := box.position + Vector3(SPAWN_WALL_MARGIN, 0.0,
				SPAWN_WALL_MARGIN)
		var hi := box.end - Vector3(SPAWN_WALL_MARGIN, 0.0,
				SPAWN_WALL_MARGIN)
		at.x = clampf(at.x, minf(lo.x, hi.x), maxf(lo.x, hi.x))
		at.z = clampf(at.z, minf(lo.z, hi.z), maxf(lo.z, hi.z))
	return Vector3(at.x, arrival.y + size.y * 0.5 + 0.02, at.z)


func ids() -> Array:
	var out: Array = _held.keys()
	out.sort()
	return out


## The loose body, or null when there is none (installed, or destroyed
## and not yet back).
func body_of(object_id: String) -> ManipulableBody:
	if not _held.has(object_id):
		return null
	var body: Variant = (_held[object_id] as Dictionary)["body"]
	if body == null or not is_instance_valid(body):
		return null
	return body


## Which object a body is, or "".
func id_of(body: Node) -> String:
	if body == null or not is_instance_valid(body):
		return ""
	return str(body.get_meta("object_id", "")) \
			if body.has_meta("object_id") else ""


## Which room this object is currently the responsibility of.
func room_of(object_id: String) -> String:
	if not _held.has(object_id):
		return ""
	return str((_held[object_id] as Dictionary)["room"])


func is_required(object_id: String) -> bool:
	if not _held.has(object_id):
		return false
	return bool((_held[object_id] as Dictionary)["required"])


## The consumer holding this object, or "".
func consumed_by(object_id: String) -> String:
	if not _held.has(object_id):
		return ""
	return str((_held[object_id] as Dictionary)["consumed"])


## What the object weighs and how it is built, for a consumer that shows
## it installed.
func spec_of(object_id: String) -> Dictionary:
	if not _held.has(object_id):
		return {}
	var entry: Dictionary = _held[object_id]
	return {"mass": entry["mass"], "size": entry["size"],
			"carriable": entry["carriable"], "required": entry["required"]}


## A consumer TAKES the object: from here on it is installed, tracked by
## nobody, and never rebuilt loose. Returns the body it took.
func take(object_id: String, mechanism_id: String) -> ManipulableBody:
	if not _held.has(object_id):
		return null
	var entry: Dictionary = _held[object_id]
	var body := body_of(object_id)
	entry["consumed"] = mechanism_id
	entry["body"] = null
	return body


## An installed object's room is its socket's room: it is seated there.
## Called only for an object a consumer has taken.
func seat_in(object_id: String, room_id: String) -> void:
	if _held.has(object_id) and consumed_by(object_id) != "":
		(_held[object_id] as Dictionary)["room"] = room_id


## What the save would carry: the room, per object.
func as_reported() -> Dictionary:
	var out := {}
	for id: Variant in _held:
		out[str(id)] = str((_held[id] as Dictionary)["room"])
	return out


## Watch for crossings, losses and rest. Cheap on purpose: a handful of
## objects against a handful of room boxes, and only a CHANGE reports.
func _physics_process(delta: float) -> void:
	for id: Variant in _held:
		var entry: Dictionary = _held[id]
		if str(entry["consumed"]) != "":
			continue
		var body := body_of(str(id))
		if body == null:
			# DESTROYED. The same identity comes back home after 2.0 s.
			entry["gone"] = float(entry["gone"]) + delta
			if float(entry["gone"]) >= DESTROYED_S:
				_recover(str(id), entry)
			continue
		var at := body.global_position
		var found := _room_containing(at)
		if found == "" and not _near_the_zone(at):
			_recover(str(id), entry)
			continue
		if found != "" and not found in (entry["volume"] as Array):
			# OUTSIDE ITS VOLUME. Not yet a loss: carried back within
			# the second, it never happened.
			entry["away"] = float(entry["away"]) + delta
			if float(entry["away"]) >= LEAVE_VOLUME_S:
				_recover(str(id), entry)
			continue
		entry["away"] = 0.0
		if found != "" and found != str(entry["room"]):
			entry["room"] = found
			transported.emit(str(id), found)
		_watch_rest(str(id), entry, body, delta)


## Report a new resting pose once the object has been still for REST_S.
func _watch_rest(object_id: String, entry: Dictionary,
		body: ManipulableBody, delta: float) -> void:
	if body.carried_by != null or body.installed_in != null:
		entry["rest"] = 0.0
		return
	if body.linear_velocity.length() > REST_SPEED \
			or body.angular_velocity.length() > REST_SPEED * 4.0:
		entry["rest"] = 0.0
		return
	entry["rest"] = float(entry["rest"]) + delta
	if float(entry["rest"]) < REST_S:
		return
	var at := body.global_position
	var yaw := body.rotation.y
	if at.distance_to(entry["pose_at"] as Vector3) < POSE_EPSILON_M \
			and absf(yaw - float(entry["pose_yaw"])) < 0.05:
		return
	entry["pose_at"] = at
	entry["pose_yaw"] = yaw
	settled.emit(object_id, str(entry["room"]), at, yaw)


## Put an object back where it comes home to, as the same object.
func _recover(object_id: String, entry: Dictionary) -> void:
	var home := str(entry["home"])
	var body := body_of(object_id)
	if body != null and body.carried_by != null:
		var who := body.carried_by as Player
		if who != null and who.carry != null:
			who.carry.release("recovered")
	if body == null:
		body = _spawn(object_id, entry, entry["home_at"] as Vector3, 0.0)
	else:
		body.global_position = entry["home_at"] as Vector3
		body.rotation = Vector3.ZERO
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		entry["pose_at"] = entry["home_at"]
		entry["pose_yaw"] = 0.0
	entry["room"] = home
	entry["away"] = 0.0
	entry["gone"] = 0.0
	entry["rest"] = 0.0
	recovered.emit(object_id, home)


## Which committed room contains this point, or "" for none.
func _room_containing(at: Vector3) -> String:
	for room: Variant in _bounds:
		var box: AABB = _bounds[room]
		if box.size == Vector3.ZERO:
			continue
		if box.has_point(at):
			return str(room)
	return ""


## Is this point inside the Zone -- a room, a connector, a doorway, a gap
## between two boxes -- rather than out of it altogether?
func _near_the_zone(at: Vector3) -> bool:
	if at.y < Constants.FALL_KILL_Y:
		return false
	if _extent.size == Vector3.ZERO:
		return true
	return _extent.grow(OUT_OF_BOUNDS_M).has_point(at)
