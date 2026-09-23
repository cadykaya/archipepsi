class_name VerbHold
extends Node
## §14.3 `HOLD` -- RUNTIME ONLY (O05-08.1). Not hand carry.
##
## "Moves the target to `hold_distance` ahead of the eye at up to
## `8.0 m/s`, then maintains it there. The held object collides with
## world geometry and stops against it; it passes through actors."
##
## Hand carry (`HandCarry`, O05-01) is the base kit's own interaction --
## 60 kg, a kinematic pose 1.2 m out, no verb -- and nothing here touches
## it. HOLD is the Echo verb §29.3.1 counts toward `manipulate`, and which
## Echo delivers it is the open question in `PROD_OV05.md` (O05-08). So
## nothing does: every hold is started by direct invocation.
##
## **MOTION, NOT PLACEMENT.** The body stays dynamic. Each tick the
## step toward the hold point -- never more than 8 m/s of it -- is swept
## with the body's own shape and its own collision exceptions, and its
## velocity is set to what the sweep allows: it stops against what it
## meets and slides along it, where a placed transform would have put it
## inside. That is `HandCarry`'s rule for what a carried object meets,
## here for a dynamic body. Gravity is suspended while it is held (the
## verb, not gravity, decides where it is) and restored on release, with
## the body keeping the velocity it had. Its rotation is left to the
## solver.
##
## **ACTORS.** A collision exception both ways with every enemy and the
## player, kept after release until the two no longer overlap, so a
## release inside an actor is not resolved as a violent depenetration.
##
## **RELEASE**, §14.3's list. Watched here: the target beyond `range x
## 1.5`; line of sight blocked for 0.5 s; a constraint it is one end of
## breaking; the caster's death; the target or the caster leaving the
## tree (a room unloading, the target destroyed). The caller's to call,
## because only the caller knows them: input release and save. Nothing
## delivers the verb, so nothing calls those two yet.
##
## A HOLD is one of the caster's relations (`VerbRelations`): it counts
## toward §14.4's `max_relations` with PIN and TETHER, and §31.2 releases
## it when another relation takes its body.

signal released(reason: String)

const SPEED_MAX := 8.0
const DISTANCE_DEFAULT := 3.5
const DISTANCE_MIN := 1.5
const DISTANCE_MAX := 6.0
const RANGE_RELEASE := 1.5
const OCCLUDED_RELEASE_S := 0.5
## How close a held body's sweep lets it come to what it meets.
const SAFE_MARGIN := 0.001

## Why a hold ended.
const INPUT := "input"
const SAVE := "save"
const OUT_OF_RANGE := "out_of_range"
const OCCLUDED := "occluded"
const CONSTRAINT_BROKE := "constraint_broke"
const DEATH := "death"
const TARGET_GONE := "target_gone"
const CASTER_GONE := "caster_gone"
const SUPERSEDED := "superseded"

var body: ManipulableBody = null
## Its global position is the eye; its -Z is where it looks.
var eye: Node3D = null
## Who is holding: excluded from the line of sight, watched for death.
var caster: CollisionObject3D = null
var range_m := 0.0
var hold_distance := DISTANCE_DEFAULT
## How long the line of sight has been blocked, without a break.
var occluded_for := 0.0
## "" while holding; afterwards, why it ended.
var release_reason := ""
var _saved_gravity := 1.0
## Actors given a collision exception with the body. Untyped: one may be
## freed while it is listed.
var _excepted: Array = []
## [signal, callable] pairs this hold connected, to disconnect on release.
var _watching: Array = []


## Start a hold, or say why not: §14.2 through `Manipulation`, whose
## actor rule refuses any enemy for HOLD.
static func begin(eye_node: Node3D, target: Node, profile: String,
		caster_body: CollisionObject3D = null) -> Dictionary:
	if not Manipulation.PHYSICS_PROFILES.has(profile):
		return {"applied": false, "refused": Manipulation.UNKNOWN_PROFILE}
	var numbers: Dictionary = Manipulation.PHYSICS_PROFILES[profile]
	var exclude: Array[RID] = []
	if caster_body != null:
		exclude.append(caster_body.get_rid())
	var why := Manipulation.target_refusal("HOLD", target,
			eye_node.global_position, numbers,
			eye_node.get_world_3d().direct_space_state, exclude)
	if why != "":
		return {"applied": false, "refused": why}
	var held: ManipulableBody = target
	var hold := VerbHold.new()
	hold.name = "VerbHold"
	hold.body = held
	hold.eye = eye_node
	hold.caster = caster_body
	hold.range_m = float(numbers["range_m"])
	VerbRelations.of(caster_body).admit(hold)
	held.add_child(hold)
	hold._start()
	return {"applied": true, "refused": "", "hold": hold}


func holding() -> bool:
	return release_reason == ""


## As a relation (`VerbRelations`).
func active() -> bool:
	return holding()


func bodies() -> Array:
	return [body] if is_instance_valid(body) else []


## §14.3: "adjustable by the player between 1.5 m and 6.0 m". How far one
## wheel notch moves it is the input's to choose, and no input reaches
## this yet; the clamp is the contract's.
func set_hold_distance(metres: float) -> float:
	hold_distance = clampf(metres, DISTANCE_MIN, DISTANCE_MAX)
	return hold_distance


## Where the body is being held toward, now.
func hold_point() -> Vector3:
	return eye.global_position \
			+ (-eye.global_transform.basis.z).normalized() * hold_distance


func release(reason: String) -> void:
	if release_reason != "":
		return
	release_reason = reason
	_disconnect()
	if is_instance_valid(body):
		body.gravity_scale = _saved_gravity
		body.sleeping = false
	released.emit(reason)
	_separate()


func _start() -> void:
	_saved_gravity = body.gravity_scale
	body.gravity_scale = 0.0
	body.sleeping = false
	_except_actors()
	for raw: Node in get_tree().get_nodes_in_group(Constraints.GROUP):
		var solver := raw as Constraints
		_watch(solver.broke, _on_broke.bind(solver))
	if caster != null and caster.has_signal("died"):
		_watch(Signal(caster, "died"), release.bind(DEATH))


func _physics_process(delta: float) -> void:
	if release_reason != "":
		_separate()
		return
	if not is_instance_valid(eye) or not eye.is_inside_tree():
		release(CASTER_GONE)
		return
	var from := eye.global_position
	if from.distance_to(body.global_position) > range_m * RANGE_RELEASE:
		release(OUT_OF_RANGE)
		return
	var exclude: Array[RID] = []
	if is_instance_valid(caster):
		exclude.append(caster.get_rid())
	if Manipulation.in_sight(body.get_world_3d().direct_space_state, from,
			body, exclude):
		occluded_for = 0.0
	else:
		occluded_for += delta
		# A hair under 0.5 s, so thirty ticks of 1/60 s -- which sum to
		# a float a hair under 0.5 -- release on the thirtieth.
		if occluded_for >= OCCLUDED_RELEASE_S - 0.0001:
			release(OCCLUDED)
			return
	_except_actors()
	var step := hold_point() - body.global_position
	if step.length() > SPEED_MAX * delta:
		step = step.normalized() * SPEED_MAX * delta
	var velocity := _swept(step) / maxf(delta, 0.0001)
	if velocity.length() > SPEED_MAX:
		velocity = velocity.normalized() * SPEED_MAX
	body.linear_velocity = velocity


## ONE TICK OF HELD MOTION, as far as the world lets it go and no
## further: swept with the body's own shape and its own collision
## exceptions -- so an actor is passed through -- then slid once along
## the surface it met. Driving the velocity straight at the hold point
## instead left a crate held against a floor resting 7 cm inside it: the
## solver cancels the approach, but only slowly undoes a penetration it
## is driven back into every tick.
func _swept(motion: Vector3) -> Vector3:
	var hit := body.move_and_collide(motion, true, SAFE_MARGIN)
	if hit == null:
		return motion
	var travel := hit.get_travel()
	var rest := hit.get_remainder()
	var normal := hit.get_normal()
	var slide := rest - normal * rest.dot(normal)
	if slide.length() < 0.0001:
		return travel
	var second := KinematicCollision3D.new()
	if body.test_move(body.global_transform.translated(travel), slide,
			second, SAFE_MARGIN):
		return travel + second.get_travel()
	return travel + slide


## THE TARGET LEFT THE TREE -- its room unloaded, or it was destroyed --
## taking this hold with it. Also the ordinary end of a hold that has
## finished separating, which has nothing left to do.
func _exit_tree() -> void:
	if release_reason == "":
		release_reason = TARGET_GONE
		_disconnect()
		if is_instance_valid(body):
			body.gravity_scale = _saved_gravity
		released.emit(TARGET_GONE)
	for raw: Variant in _excepted:
		if is_instance_valid(raw) and is_instance_valid(body):
			var actor := raw as PhysicsBody3D
			actor.remove_collision_exception_with(body)
			body.remove_collision_exception_with(actor)
	_excepted.clear()


func _on_broke(constraint_id: String, _at_force: float,
		solver: Constraints) -> void:
	if is_instance_valid(body) and solver.involves(constraint_id, body):
		release(CONSTRAINT_BROKE)


func _watch(emitter: Signal, callable: Callable) -> void:
	emitter.connect(callable)
	_watching.append([emitter, callable])


func _disconnect() -> void:
	for pair: Array in _watching:
		var emitter: Signal = pair[0]
		var callable: Callable = pair[1]
		if is_instance_valid(emitter.get_object()) \
				and emitter.is_connected(callable):
			emitter.disconnect(callable)
	_watching.clear()


## Every actor present, excepted both ways. Run each tick while holding,
## so one that arrives mid-hold is passed through as well.
func _except_actors() -> void:
	for group: String in ["enemies", "player"]:
		for raw: Node in get_tree().get_nodes_in_group(group):
			var actor := raw as PhysicsBody3D
			if actor == null or actor == body or _excepted.has(actor):
				continue
			body.add_collision_exception_with(actor)
			actor.add_collision_exception_with(body)
			_excepted.append(actor)


## After release: drop each exception once its actor no longer overlaps
## the body, and go when none is left.
func _separate() -> void:
	for raw: Variant in _excepted.duplicate():
		var gone := not is_instance_valid(raw) \
				or not is_instance_valid(body) or not body.is_inside_tree()
		if not gone and _overlaps(raw as PhysicsBody3D):
			continue
		if not gone:
			var actor := raw as PhysicsBody3D
			body.remove_collision_exception_with(actor)
			actor.remove_collision_exception_with(body)
		_excepted.erase(raw)
	if _excepted.is_empty():
		queue_free()


func _overlaps(actor: PhysicsBody3D) -> bool:
	var hull := body.get_node_or_null("hull") as CollisionShape3D
	if hull == null or hull.shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull.shape
	query.transform = hull.global_transform
	query.collide_with_areas = false
	for hit: Dictionary in body.get_world_3d().direct_space_state \
			.intersect_shape(query, 32):
		if hit.get("rid") == actor.get_rid():
			return true
	return false
