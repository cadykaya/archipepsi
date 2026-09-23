class_name ObjectSocket
extends StaticBody3D
## P16'S CONSUMER, BUILT: the physical receiving site an `ObjectConsumer`
## declares (O05-02.3).
##
## **Same-room presence is a precondition, not the operation.** Nothing
## here fires because an object entered a room. The player carries the
## object up to this socket, looks at it and presses `interact`, and
## `HandCarry.on_interact` asks `install_refusal` first -- the right
## object, a socket not already full. Only then does `install` take the
## body, seat it, and drive the declared consequence.
##
## **The consequence goes through D-8's handle.** Installing sets the
## consumer's declared variable on the Zone's `ZoneState`, which every
## reader -- lamps, the doorway gate -- already binds to by id. There is
## no second channel, and this node addresses no other room.
##
## **Authority stays with the bridge.** The controller reports the
## installation as `object_consumed`, after the object's transfer into
## this room; the bridge refuses a consumption with no delivery, and a
## second consumption of one object. A raw `zone_state_selected` for
## this variable is refused there as well, so no message alone can stand
## in for the physical operation.

signal installed(mechanism_id: String, object_id: String)

const BASE := Vector3(0.8, 0.9, 0.8)
## Where an installed object's foot stands, on top of the base.
const SEAT := Vector3(0.0, 0.9, 0.0)

var mechanism_id := ""
var room_id := ""
var accepts := ""
var sets_variable := ""
var sets_state := ""
## The object this socket holds, or "".
var installed_object := ""
## The body seated in the socket, when there is one.
var seated: ManipulableBody = null

var _state: ZoneState = null
var _objects: TransportedObjects = null
var _ring: MeshInstance3D = null
var _theme := "concrete_facility"


static func create(consumer: Dictionary, theme := "concrete_facility") \
		-> ObjectSocket:
	var made := ObjectSocket.new()
	made.mechanism_id = str(consumer.get("mechanism_id", ""))
	made.room_id = str(consumer.get("room_id", ""))
	made.accepts = str(consumer.get("accepts", ""))
	made.sets_variable = str(consumer.get("sets_variable", "")) \
			if consumer.get("sets_variable") != null else ""
	made.sets_state = str(consumer.get("sets_state", "")) \
			if consumer.get("sets_state") != null else ""
	made.name = "ObjectSocket_%s" % made.mechanism_id
	made._theme = theme
	made._build()
	return made


func _build() -> void:
	# THE BASE IS THE COLLIDER, and what the interact ray finds.
	var shape := CollisionShape3D.new()
	shape.name = "base"
	var box := BoxShape3D.new()
	box.size = BASE
	shape.shape = box
	shape.position = Vector3(0.0, BASE.y * 0.5, 0.0)
	add_child(shape)
	var plinth := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = BASE
	plinth.mesh = mesh
	plinth.position = shape.position
	plinth.material_override = ThemeMaterials.trim_mat(_theme)
	add_child(plinth)
	_ring = MeshInstance3D.new()
	_ring.name = "ring"
	var ring_mesh := BoxMesh.new()
	ring_mesh.size = Vector3(BASE.x + 0.06, 0.08, BASE.z + 0.06)
	_ring.mesh = ring_mesh
	_ring.position = Vector3(0.0, BASE.y - 0.04, 0.0)
	add_child(_ring)
	_show()


## Bind to the Zone's state and objects. An object the save already
## records as installed HERE is seated now, as the installed
## representation, and the consequence is already in the restored state.
func bind(state: ZoneState, objects: TransportedObjects) -> void:
	_state = state
	_objects = objects
	if objects != null and objects.consumed_by(accepts) == mechanism_id:
		var spec := objects.spec_of(accepts)
		var body := TransportedObjects.make_body(accepts,
				float(spec.get("mass", 40.0)),
				spec.get("size", TransportedObjects.CELL_SIZE) as Vector3,
				bool(spec.get("carriable", true)),
				bool(spec.get("required", false)))
		add_child(body)
		_seat(body)
		installed_object = accepts
	_show()


## Why `body` cannot go in, or "" if it can.
func install_refusal(body: ManipulableBody) -> String:
	if installed_object != "":
		return "SOCKET FULL"
	if body == null or not is_instance_valid(body):
		return "NOTHING TO INSTALL"
	var what := _objects.id_of(body) if _objects != null else ""
	if what != accepts:
		return "WRONG PART · THIS SOCKET TAKES %s" % _label(accepts)
	return ""


## Take the object, seat it, and drive the declared consequence.
func install(body: ManipulableBody) -> void:
	if install_refusal(body) != "":
		return
	var taken := _objects.take(accepts, mechanism_id) \
			if _objects != null else body
	if taken == null:
		taken = body
	var at := taken.global_transform
	taken.get_parent().remove_child(taken)
	add_child(taken)
	taken.global_transform = at
	_seat(taken)
	installed_object = accepts
	_show()
	if sets_variable != "" and _state != null:
		_state.select(sets_variable, sets_state)
	installed.emit(mechanism_id, accepts)


func _seat(body: ManipulableBody) -> void:
	seated = body
	body.installed_in = self
	body.carried_by = null
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.collision_layer = 1
	body.collision_mask = 0
	var half := 0.3
	var hull := body.get_node_or_null("hull") as CollisionShape3D
	if hull != null and hull.shape is BoxShape3D:
		half = (hull.shape as BoxShape3D).size.y * 0.5
	body.position = SEAT + Vector3(0.0, half, 0.0)
	body.rotation = Vector3.ZERO


func _show() -> void:
	if _ring == null:
		return
	_ring.material_override = ThemeMaterials.glow_material(
			Color(0.55, 1.0, 0.7) if installed_object != ""
			else Color(1.0, 0.55, 0.2), 2.2 if installed_object != ""
			else 0.8)


func _label(object_id: String) -> String:
	return object_id.replace("_", " ").to_upper()


func interact_prompt() -> String:
	if installed_object != "":
		return "%s · INSTALLED" % _label(installed_object)
	return "SOCKET · BRING THE %s" % _label(accepts)


## `interact` with empty hands: say what the socket wants.
func interact(who: Node) -> void:
	var player := who as Player
	if player == null:
		return
	player.carry_feedback.emit(interact_prompt(), installed_object != "")
