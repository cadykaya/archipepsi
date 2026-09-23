class_name VerbTether
extends Node
## §14.3 `TETHER` -- RUNTIME ONLY (O05-08.2).
##
## "Creates a `ROPE` constraint between the first and second surfaces
## struck by two successive activations. `length` is the distance between
## the two points at the moment the second is placed, `x1.05`.
## `breakable_at` is the profile's `breaking_force`. A tether is
## `EPHEMERAL` and is destroyed by save, death, room unload, or Zone exit.
## Placing a tether beyond `max_length` fails at the second activation,
## refunds nothing (the first activation already committed)."
##
## **TWO ACTIVATIONS.** `first` commits one end and returns a pending
## tether. `second` either ties the rope or refuses. Either way the
## pending tether is spent: a refused second activation refunds nothing.
##
## **WHERE THE ROPE IS TIED -- a reading, stated.** A surface struck (the
## world, a static body, a FIXED object) is an anchor at the struck
## point. A manipulable body struck is tied at its origin, because that
## is where `Constraints` ties a rope to a body. The length is measured
## between those two points, so the rope is exactly as slack as the
## contract says the moment it is tied, not already stretched by the
## body's half-width.
##
## The rope is `Constraints.tether` (§14.8: "No constraint may be created
## at runtime except TETHER"), in the solver the caller names. A tether
## is one of the caster's relations (`VerbRelations`). `concurrent` is
## the profile's cap on tethers at once, and one past it releases that
## profile's oldest.

signal released(reason: String)

const PROFILES := {
	"ab_tether_light": {"range_m": 22.0, "max_length": 14.0,
			"breaking_force": 2500.0, "concurrent": 2},
	"ab_tether_strong": {"range_m": 18.0, "max_length": 10.0,
			"breaking_force": 6000.0, "concurrent": 3},
}
const SLACK := 1.05

## Why an activation was refused.
const TOO_LONG := "too_long"
const SPENT := "spent"
const SAME_END := "same_end"
const NOTHING_TO_HOLD := "nothing_to_hold"
## Why a tether ended.
const SAVE := "save"
const DEATH := "death"
const CASTER_GONE := "caster_gone"
const TARGET_GONE := "target_gone"
const CONCURRENT := "concurrent"
const BROKE := "broke"

var solver: Constraints = null
var rope_id := ""
var profile := ""
var caster: CollisionObject3D = null
var ends: Array = []
## "" while tied; afterwards, why it ended.
var release_reason := ""
var _watching: Array = []

static var _minted := 0


## One end of a tether not yet tied: what the first activation struck.
class Pending extends RefCounted:
	var profile := ""
	var caster: CollisionObject3D = null
	var body: ManipulableBody = null
	var anchor := Vector3.ZERO
	var spent := false

	## Where the rope would be tied at this end.
	func point() -> Vector3:
		return body.global_position if is_instance_valid(body) else anchor

	## The second activation: tie the rope in `solver`, or refuse. Either
	## way this pending tether is spent.
	func second(eye: Vector3, struck: Node, at: Vector3,
			space: PhysicsDirectSpaceState3D, solver: Constraints
			) -> Dictionary:
		if spent:
			return {"applied": false, "refused": VerbTether.SPENT}
		spent = true
		var numbers: Dictionary = VerbTether.PROFILES[profile]
		var end := VerbTether._end(eye, struck, at, numbers, space, caster)
		if end.has("refused"):
			return {"applied": false, "refused": end["refused"]}
		var far: ManipulableBody = end["body"]
		if far != null and far == body:
			return {"applied": false, "refused": VerbTether.SAME_END}
		var there: Vector3 = far.global_position if far != null \
				else end["anchor"]
		var span := point().distance_to(there)
		if span > float(numbers["max_length"]):
			return {"applied": false, "refused": VerbTether.TOO_LONG, "span_m": span}
		return VerbTether._tie(self, far, there, span, solver)


## The first activation: commit one end, or say why not.
static func first(eye: Vector3, struck: Node, at: Vector3,
		profile_name: String, space: PhysicsDirectSpaceState3D,
		caster_body: CollisionObject3D = null) -> Dictionary:
	if not PROFILES.has(profile_name):
		return {"applied": false, "refused": Manipulation.UNKNOWN_PROFILE}
	var end := _end(eye, struck, at, PROFILES[profile_name], space,
			caster_body)
	if end.has("refused"):
		return {"applied": false, "refused": end["refused"]}
	var pending := Pending.new()
	pending.profile = profile_name
	pending.caster = caster_body
	pending.body = end["body"]
	pending.anchor = end["anchor"]
	return {"applied": true, "refused": "", "pending": pending}


## What one activation struck, as a rope end. A manipulable body §14.2
## admits is a body end; anything else solid is the world, anchored at
## the point struck. §14.2's player and actor rules apply to both.
static func _end(eye: Vector3, struck: Node, at: Vector3,
		numbers: Dictionary, space: PhysicsDirectSpaceState3D,
		caster_body: CollisionObject3D) -> Dictionary:
	if struck == null or not is_instance_valid(struck):
		return {"refused": Manipulation.NO_TARGET}
	if eye.distance_to(at) > float(numbers["range_m"]):
		return {"refused": Manipulation.OUT_OF_REACH}
	var exclude: Array[RID] = []
	if caster_body != null:
		exclude.append(caster_body.get_rid())
	if struck is ManipulableBody \
			and (struck as ManipulableBody).mass_class() != MassClass.FIXED:
		var why := Manipulation.target_refusal("TETHER", struck, eye,
				{"range_m": float(numbers["range_m"]),
					"mass_limit_kg": INF}, space, exclude)
		if why != "":
			return {"refused": why}
		return {"body": struck, "anchor": Vector3.ZERO}
	if struck.is_in_group("player"):
		return {"refused": Manipulation.NEVER_THE_PLAYER}
	if struck is Enemy:
		return {"refused": Manipulation.ACTOR_RULE}
	if not Manipulation._clear(space, eye, at, exclude):
		return {"refused": Manipulation.NO_LINE_OF_SIGHT}
	return {"body": null, "anchor": at}


static func _tie(pending: Pending, far: ManipulableBody, there: Vector3,
		span: float, solver: Constraints) -> Dictionary:
	_minted += 1
	var tether := VerbTether.new()
	tether.name = "VerbTether_%d" % _minted
	tether.rope_id = "tether_%d" % _minted
	tether.solver = solver
	tether.profile = pending.profile
	tether.caster = pending.caster
	var near := pending.body if is_instance_valid(pending.body) else null
	var numbers: Dictionary = PROFILES[pending.profile]
	var refusal := solver.tether(tether.rope_id, near, far, span * SLACK,
			float(numbers["breaking_force"]), pending.anchor, there)
	if refusal != "":
		tether.free()
		return {"applied": false, "refused": NOTHING_TO_HOLD,
				"why": refusal}
	for end: Variant in [near, far]:
		if end != null:
			tether.ends.append(end)
	var ledger := VerbRelations.of(pending.caster)
	var same_profile := ledger.relations().filter(
			func(held: Variant) -> bool:
				return held is VerbTether \
						and (held as VerbTether).profile == pending.profile)
	while same_profile.size() >= int(numbers["concurrent"]):
		(same_profile.pop_front() as VerbTether).release(CONCURRENT)
	ledger.admit(tether)
	solver.add_child(tether)
	tether._watch_the_world()
	return {"applied": true, "refused": "", "tether": tether,
			"length_m": span * SLACK}


func active() -> bool:
	return release_reason == ""


func bodies() -> Array:
	return ends.filter(func(end: Variant) -> bool:
		return is_instance_valid(end))


func release(reason: String) -> void:
	if release_reason != "":
		return
	release_reason = reason
	_disconnect()
	if is_instance_valid(solver):
		solver.untether(rope_id)
	released.emit(reason)
	queue_free()


func _watch_the_world() -> void:
	if caster != null and caster.has_signal("died"):
		_watch(Signal(caster, "died"), release.bind(DEATH))
	_watch(solver.broke, _on_broke)
	for end: Variant in ends:
		_watch((end as Node).tree_exiting, release.bind(TARGET_GONE))


func _physics_process(_delta: float) -> void:
	if release_reason != "":
		return
	if caster != null and (not is_instance_valid(caster)
			or not caster.is_inside_tree()):
		release(CASTER_GONE)


func _on_broke(constraint_id: String, _at_force: float) -> void:
	if constraint_id == rope_id:
		release(BROKE)


## The solver left the tree -- the room unloaded -- taking the rope with it.
func _exit_tree() -> void:
	if release_reason == "":
		release_reason = TARGET_GONE
		_disconnect()
		released.emit(TARGET_GONE)


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
