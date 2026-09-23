class_name VerbAttach
extends RefCounted
## §14.3 `ATTACH` / `DETACH` -- RUNTIME ONLY (O05-08.3).
##
## "`ATTACH` joins two objects at compatible attach points: the currently
## held object and a focused attach point within `4.0 m`, where the
## point's `accepts_materials` includes the held object's `material` and
## `occupied_by` is null. The join is a fixed weld, not a hinge. `DETACH`
## separates an attachment, or breaks a `ConstraintSpec` whose
## `breakable_at` is non-null, at the focused point. [...] An attachment
## chain is capped at `4` objects."
##
## **A WELD IS ONE BODY.** Item 14 asks for "two `GIRDER`s into one body
## of `190 kg`, class `HEAVY`", so the weld is not a joint between two
## bodies: the held part's own collision shapes and visuals move into the
## target's assembly root, which takes on its mass, and the part itself
## waits out of the world, frozen, with no layers and hidden, to be given
## them back. The part is placed with its origin on the attach point.
##
## **DETACH GIVES BACK EXACTLY THAT.** Item 16: "`DETACH` restores both
## bodies at their world transforms with zero velocity". The part is put
## where its shapes are in the assembly now, with its own nodes back under
## their own names, and both bodies are at rest.
##
## **THE BASE KIT'S UNDO.** A player without a DETACH Echo must not be
## able to softlock their own construction, so `interact` on an assembly
## undoes its newest weld a PLAYER made (`undo_latest`). An authored weld
## is never undone that way.
##
## Not here: §14.3's "Attachment is `PUZZLE_LOCAL` and survives save,
## reload, and reset within its group". That is a save record, and nothing
## delivers the verb yet.

const REACH := 4.0
const CHAIN_CAP := 4
const MATERIALS: Array[String] = ["METAL", "STONE", "WOOD", "COMPOSITE",
		"GLASS"]

## Why an ATTACH or a DETACH was refused.
const NOT_HELD := "not_held"
const SAME_ASSEMBLY := "same_assembly"
const NO_POINT := "no_point"
const POINT_OUT_OF_REACH := "point_out_of_reach"
const NO_MATERIAL := "no_material"
const WRONG_MATERIAL := "wrong_material"
const OCCUPIED := "occupied"
const CHAIN_FULL := "chain_full"
const NOTHING_ATTACHED := "nothing_attached"
const UNBREAKABLE := "unbreakable"
## Why the HOLD on the attached part ended.
const ATTACHED := "attached"


## ATTACH: weld what `hold` is holding onto `target` at its attach point
## `point`, or say why not. `eye` is where "within 4.0 m" is measured from.
static func attach(hold: VerbHold, target: ManipulableBody, point: int,
		eye: Vector3, by_player := true) -> Dictionary:
	if hold == null or not is_instance_valid(hold) or not hold.holding():
		return {"applied": false, "refused": NOT_HELD}
	var held := hold.body
	var root := root_of(target)
	if root == root_of(held):
		return {"applied": false, "refused": SAME_ASSEMBLY}
	if point < 0 or point >= target.attach_points.size():
		return {"applied": false, "refused": NO_POINT}
	var socket: AttachPoint = target.attach_points[point]
	var at := world_transform_of(target) * socket.local_transform
	if eye.distance_to(at.origin) > REACH:
		return {"applied": false, "refused": POINT_OUT_OF_REACH}
	if not held.material in MATERIALS:
		return {"applied": false, "refused": NO_MATERIAL}
	if not socket.accepts_materials.has(held.material):
		return {"applied": false, "refused": WRONG_MATERIAL}
	if socket.occupied_by != null:
		return {"applied": false, "refused": OCCUPIED}
	var chain := count(root) + count(held)
	if chain > CHAIN_CAP:
		return {"applied": false, "refused": CHAIN_FULL, "chain": chain}
	hold.release(ATTACHED)
	_weld(root, held, at, socket, by_player)
	return {"applied": true, "refused": "", "root": root,
			"mass_kg": root.mass, "chain": count(root)}


## DETACH at a focused point: give `part` back from the assembly it is
## welded into.
static func detach(part: ManipulableBody) -> Dictionary:
	var root := part.welded_into
	if root == null or not is_instance_valid(root):
		return {"applied": false, "refused": NOTHING_ATTACHED}
	var weld := _weld_of(root, part)
	if weld.is_empty():
		return {"applied": false, "refused": NOTHING_ATTACHED}
	part.global_transform = root.global_transform * (weld["rel"] as Transform3D)
	var nodes: Array = weld["nodes"]
	var names: Array = weld["names"]
	for i in nodes.size():
		var node: Node3D = nodes[i]
		if is_instance_valid(node):
			node.reparent(part, true)
			node.name = names[i]
	part.collision_layer = weld["layer"]
	part.collision_mask = weld["mask"]
	part.visible = weld["visible"]
	part.freeze_mode = weld["freeze_mode"]
	part.freeze = weld["freeze"]
	part.mass = weld["mass"]
	root.mass -= float(weld["mass"])
	for body: ManipulableBody in [part, root]:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
	(weld["point"] as AttachPoint).occupied_by = null
	part.welded_into = null
	root.welds.erase(weld)
	return {"applied": true, "refused": "", "part": part, "root": root}


## DETACH on a constraint: "breaks a `ConstraintSpec` whose `breakable_at`
## is non-null". An unbreakable one is refused, not broken.
static func sever(solver: Constraints, constraint_id: String) -> Dictionary:
	if solver == null or not solver.sever(constraint_id):
		return {"applied": false, "refused": UNBREAKABLE}
	return {"applied": true, "refused": ""}


## The base kit's undo: detach the newest weld a player made on the
## assembly `body` is part of. False when there is none -- an authored
## weld is never undone this way.
static func undo_latest(body: ManipulableBody) -> bool:
	var weld := latest_player_weld(body)
	if weld.is_empty():
		return false
	return bool(detach(weld["part"])["applied"])


static func latest_player_weld(body: ManipulableBody) -> Dictionary:
	var root := root_of(body)
	for i in range(root.welds.size() - 1, -1, -1):
		var weld: Dictionary = root.welds[i]
		if bool(weld["by_player"]):
			return weld
	return {}


## Where `body` is in the world now. A welded part's own node waits,
## frozen, where it was welded; its place in the world is its root's,
## carried by the weld.
static func world_transform_of(body: ManipulableBody) -> Transform3D:
	var root := root_of(body)
	if root == body:
		return body.global_transform
	var weld := _weld_of(root, body)
	if weld.is_empty():
		return body.global_transform
	return root.global_transform * (weld["rel"] as Transform3D)


## The body an assembly's welds hang from: itself, unless it was welded.
static func root_of(body: ManipulableBody) -> ManipulableBody:
	var at := body
	while at.welded_into != null and is_instance_valid(at.welded_into):
		at = at.welded_into
	return at


## How many objects an assembly is: its root and every part on it.
static func count(body: ManipulableBody) -> int:
	return 1 + root_of(body).welds.size()


static func _weld_of(root: ManipulableBody, part: ManipulableBody
		) -> Dictionary:
	for weld: Dictionary in root.welds:
		if weld["part"] == part:
			return weld
	return {}


## The weld itself. If the held body is an assembly of its own, its parts
## come with it and are flattened onto the new root, so the chain count
## and every part's mass stay exact.
static func _weld(root: ManipulableBody, held: ManipulableBody,
		at: Transform3D, socket: AttachPoint, by_player: bool) -> void:
	var carried: Array = held.welds.duplicate()
	held.welds.clear()
	var carried_mass := 0.0
	for weld: Dictionary in carried:
		carried_mass += float(weld["mass"])
	held.linear_velocity = Vector3.ZERO
	held.angular_velocity = Vector3.ZERO
	# Where every carried part sits relative to the held body, before the
	# held body moves onto the point.
	var carried_rel: Array = []
	for weld: Dictionary in carried:
		carried_rel.append(weld["rel"])
	held.global_transform = at
	var own: Array = []
	var carried_nodes: Array = []
	for weld: Dictionary in carried:
		carried_nodes.append_array(weld["nodes"])
	for child: Node in held.get_children():
		if child is Node3D and not carried_nodes.has(child):
			own.append(child)
	var record := {
		"part": held, "point": socket, "by_player": by_player,
		"rel": root.global_transform.affine_inverse() * held.global_transform,
		"mass": held.mass - carried_mass,
		"layer": held.collision_layer, "mask": held.collision_mask,
		"visible": held.visible, "freeze": held.freeze,
		"freeze_mode": held.freeze_mode,
	}
	record["nodes"] = own
	record["names"] = own.map(func(node: Node) -> String: return node.name)
	root.welds.append(record)
	for i in carried.size():
		var weld: Dictionary = carried[i]
		weld["rel"] = root.global_transform.affine_inverse() \
				* held.global_transform * (carried_rel[i] as Transform3D)
		root.welds.append(weld)
		(weld["part"] as ManipulableBody).welded_into = root
	var moving: Array = own.duplicate()
	moving.append_array(carried_nodes)
	for node: Node3D in moving:
		node.name = "weld_%d_%s" % [node.get_instance_id(), node.name]
		node.reparent(root, true)
	root.mass += held.mass
	held.mass = maxf(held.mass - carried_mass, 0.001)
	held.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	held.freeze = true
	held.collision_layer = 0
	held.collision_mask = 0
	held.visible = false
	held.welded_into = root
	socket.occupied_by = held
	root.sleeping = false
