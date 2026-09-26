class_name VerbAlign
extends Node
## §14.3 `ALIGN` -- RUNTIME ONLY (O05-08.1).
##
## "Rotates to the nearest axis-aligned orientation over `0.3 s`, then
## holds orientation for `2.5 s` while translation continues normally."
##
## **MOTION, NOT PLACEMENT.** The turn is an angular velocity the solver
## integrates, recomputed each tick from what is left of the turn and of
## the 0.3 s, so a knock on the way is corrected rather than ignored and
## the body arrives when the contract says. The hold is the solver's own
## angular axis lock: no rotation at all for 2.5 s, while gravity,
## contacts and any push move the body as they would anyway. Linear
## velocity is never touched.
##
## Nothing delivers the verb; every ALIGN is by direct invocation.

signal finished

const TURN_S := 0.3
const HOLD_S := 2.5

var body: ManipulableBody = null
## The orientation it is turning to.
var goal := Basis.IDENTITY
## Seconds since the verb began, counted at the start of each tick.
var elapsed := 0.0
var locked := false
var locked_at := 0.0
var _saved_locks: Array[bool] = [false, false, false]
var _ended := false


## Start an ALIGN, or say why not: §14.2 through `Manipulation`, whose
## actor rule refuses any enemy for ALIGN.
static func begin(eye: Vector3, target: Node, profile: String,
		space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []
		) -> Dictionary:
	if not Manipulation.PHYSICS_PROFILES.has(profile):
		return {"applied": false, "refused": Manipulation.UNKNOWN_PROFILE}
	var why := Manipulation.target_refusal("ALIGN", target, eye,
			Manipulation.PHYSICS_PROFILES[profile], space, exclude)
	if why != "":
		return {"applied": false, "refused": why}
	var aligned: ManipulableBody = target
	for child: Node in aligned.get_children():
		if child is VerbAlign:
			(child as VerbAlign).end()
	var align := VerbAlign.new()
	align.name = "VerbAlign"
	align.body = aligned
	align.goal = nearest_axis_aligned(aligned.global_transform.basis)
	aligned.add_child(align)
	return {"applied": true, "refused": "", "align": align,
			"turn_rad": angle_between(aligned.global_transform.basis,
					align.goal)}


## The nearest of the 24 axis-aligned orientations to `basis`: every way
## of laying the body's own axes along the world's, handedness kept.
static func nearest_axis_aligned(basis: Basis) -> Basis:
	var current := basis.orthonormalized()
	var world: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var best := Basis.IDENTITY
	var best_angle := INF
	for i in 3:
		for j in 3:
			if i == j:
				continue
			for si: float in [1.0, -1.0]:
				for sj: float in [1.0, -1.0]:
					var x: Vector3 = world[i] * si
					var y: Vector3 = world[j] * sj
					var candidate := Basis(x, y, x.cross(y))
					var angle := angle_between(current, candidate)
					if angle < best_angle:
						best_angle = angle
						best = candidate
	return best


## The angle, in radians, of the rotation that takes `from` to `to`.
static func angle_between(from: Basis, to: Basis) -> float:
	var turn := (to.orthonormalized() * from.orthonormalized().inverse()) \
			.get_rotation_quaternion()
	var angle := turn.get_angle()
	return minf(angle, TAU - angle)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(body):
		queue_free()
		return
	var now := elapsed
	elapsed += delta
	if not locked:
		# The time left for the turn, at the start of this tick. A hair
		# under zero-ish, because eighteen ticks of 1/60 s sum to a float
		# a hair under 0.3.
		var left := TURN_S - now
		if left <= 0.0001:
			_lock(now)
			return
		var current := body.global_transform.basis.orthonormalized()
		var turn := (goal * current.inverse()).get_rotation_quaternion()
		if turn.w < 0.0:
			turn = -turn
		var angle := turn.get_angle()
		if angle < 0.000001:
			body.angular_velocity = Vector3.ZERO
			return
		body.angular_velocity = turn.get_axis().normalized() * angle \
				/ maxf(left, delta)
		return
	if now - locked_at >= HOLD_S - 0.0001:
		end()


func _lock(now: float) -> void:
	locked = true
	locked_at = now
	_saved_locks = [body.axis_lock_angular_x, body.axis_lock_angular_y,
			body.axis_lock_angular_z]
	body.angular_velocity = Vector3.ZERO
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.axis_lock_angular_z = true


## The hold is over, or another ALIGN replaced this one: give the body
## its own axis locks back.
func end() -> void:
	if _ended:
		return
	_ended = true
	if locked and is_instance_valid(body):
		body.axis_lock_angular_x = _saved_locks[0]
		body.axis_lock_angular_y = _saved_locks[1]
		body.axis_lock_angular_z = _saved_locks[2]
	locked = false
	finished.emit()
	queue_free()
