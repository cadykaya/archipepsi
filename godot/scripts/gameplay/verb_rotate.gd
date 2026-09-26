class_name VerbRotate
extends Node
## §14.3 `ROTATE` -- RUNTIME ONLY (O05-08.2).
##
## "Applies `angular_velocity` about the view axis while held, up to
## `2.5 rad/s`. On a constrained object it drives the constraint within
## `limit_lower`/`limit_upper`. On a free object it spins it. On a `FIXED`
## object it does nothing unless that object has a `HINGE` or `SEESAW`
## constraint, in which case it drives that." -- and §14.2 lets FIXED
## respond to "`ROTATE` about a constrained axis".
##
## **ON A HINGE** it turns the hinge's own motor the way the view axis
## turns it, at up to 2.5 rad/s, and "within `limit_lower`/`limit_upper`"
## is the verb's to keep, not the joint's: the rate is slowed to land on
## the limit, and at the limit it is zero -- held there, not pushed on.
## Two versions that left it to the joint were measured and were wrong.
## Aimed TOWARD the limit value (a DRIVER's `drive`), the motor reversed
## on the soft limit's small overshoot and chattered there (0.04 rad in a
## second). Told only which way to turn, it drove through Godot's soft
## limit to 2.4 rad on a 1.2 rad hinge. What the view axis cannot turn it
## does not turn: a hinge whose axis is square to the view gets nothing,
## which is what "about the view axis" means for it.
##
## **ON A FREE BODY** it holds the body's angular velocity at 2.5 rad/s
## about the view axis while held.
##
## **THE STRENGTH -- a reading, stated.** ROTATE has no profile of its
## own. It is a PHYSICS_VERB, and it reads the `ab_physics_*` row: range
## and mass limit for eligibility, and `force` (§12.1's `magnitude`,
## "force in newtons") as the most the hinge motor may push per step. That
## is the family's only strength number.
##
## Not a relation: §14.4 counts held, pinned and tethered. `direction` is
## +1 or -1, the way the input would turn it; no input reaches the verb.

signal released(reason: String)

const RATE := 2.5
## A hinge axis within this of square to the view is turned by nothing.
const SQUARE := 0.05

const INPUT := "input"
const TARGET_GONE := "target_gone"
const CASTER_GONE := "caster_gone"

var body: ManipulableBody = null
var eye: Node3D = null
var solver: Constraints = null
var hinge_id := ""
var force := 0.0
var direction := 1.0
var release_reason := ""


## Start turning `target`, or say why not.
static func begin(eye_node: Node3D, target: Node, profile: String,
		caster: CollisionObject3D = null, turn := 1.0) -> Dictionary:
	if not Manipulation.PHYSICS_PROFILES.has(profile):
		return {"applied": false, "refused": Manipulation.UNKNOWN_PROFILE}
	var numbers: Dictionary = Manipulation.PHYSICS_PROFILES[profile]
	var on: Constraints = null
	var hinge := ""
	if target is ManipulableBody:
		for raw: Node in eye_node.get_tree().get_nodes_in_group(
				Constraints.GROUP):
			hinge = (raw as Constraints).hinge_of(target as ManipulableBody)
			if hinge != "":
				on = raw as Constraints
				break
	var exclude: Array[RID] = []
	if caster != null:
		exclude.append(caster.get_rid())
	var why := Manipulation.target_refusal("ROTATE", target,
			eye_node.global_position, numbers,
			eye_node.get_world_3d().direct_space_state, exclude, hinge != "")
	if why != "":
		return {"applied": false, "refused": why}
	var rotate := VerbRotate.new()
	rotate.name = "VerbRotate"
	rotate.body = target as ManipulableBody
	rotate.eye = eye_node
	rotate.solver = on
	rotate.hinge_id = hinge
	rotate.force = float(numbers["force_n"])
	rotate.direction = signf(turn) if turn != 0.0 else 1.0
	(target as Node).add_child(rotate)
	return {"applied": true, "refused": "", "rotate": rotate,
			"on_hinge": hinge != ""}


func turning() -> bool:
	return release_reason == ""


func release(reason: String) -> void:
	if release_reason != "":
		return
	release_reason = reason
	if hinge_id != "" and is_instance_valid(solver):
		solver.release(hinge_id)
	released.emit(reason)
	queue_free()


func _physics_process(delta: float) -> void:
	if release_reason != "":
		return
	if not is_instance_valid(eye) or not eye.is_inside_tree():
		release(CASTER_GONE)
		return
	var view := (-eye.global_transform.basis.z).normalized()
	if hinge_id == "":
		body.angular_velocity = view * RATE * direction
		return
	var along := solver.hinge_axis(hinge_id).dot(view) * direction
	if absf(along) < SQUARE:
		solver.release(hinge_id)
		return
	var limits := solver.limits_of(hinge_id)
	var value := solver.value_of(hinge_id)
	var room := (limits.y - value) if along > 0.0 else (value - limits.x)
	var rate := clampf(maxf(room, 0.0) / maxf(delta, 0.0001), 0.0, RATE)
	solver.turn(hinge_id, rate * signf(along), force, false)


func _exit_tree() -> void:
	if release_reason == "":
		release_reason = TARGET_GONE
		if hinge_id != "" and is_instance_valid(solver):
			solver.release(hinge_id)
		released.emit(TARGET_GONE)
