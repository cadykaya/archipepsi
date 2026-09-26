class_name VerbPin
extends Node
## §14.3 `PIN` -- RUNTIME ONLY (O05-08.2).
##
## "Sets the target to `FIXED` in world space for `duration`, ignoring
## gravity and all forces. Ends on duration, on `DETACH`, or on the player
## pinning something else beyond `max_relations`. A pinned object still
## collides. A pinned object supporting weight holds it. This is the verb
## that makes improvised structures possible, and it is why `PIN`
## duration is short."
##
## **FIXED IN WORLD SPACE is the solver's static freeze.** The body keeps
## its shape where it is, so it collides and bears weight, and nothing
## moves it -- gravity, a push, a load. A reading, stated: this is where
## the body IS, not what it weighs. Its mass class is untouched, so a
## class plate under a pinned 40 kg crate still reads MEDIUM. On release
## it is unfrozen, at rest.
##
## A pin is one of the caster's relations (`VerbRelations`). `max_pinned`
## is the profile's own cap on pins at once, and a pin past it releases
## that profile's oldest. DETACH (O05-08.3) is not built; `release`
## takes its reason.

signal released(reason: String)

const PROFILES := {
	"ab_pin_brief": {"range_m": 20.0, "duration": 6.0,
			"mass_limit_kg": 260.0, "max_pinned": 2},
	"ab_pin_long": {"range_m": 16.0, "duration": 14.0,
			"mass_limit_kg": 400.0, "max_pinned": 1},
}

## Why a pin ended.
const EXPIRED := "expired"
const DETACHED := "detached"
const MAX_PINNED := "max_pinned"
const TARGET_GONE := "target_gone"

var body: ManipulableBody = null
var profile := ""
var duration := 0.0
## Seconds of the pin still to run.
var left := 0.0
## "" while pinned; afterwards, why it ended.
var release_reason := ""
var _saved_freeze := false
var _saved_mode := RigidBody3D.FREEZE_MODE_STATIC


## Pin `target`, or say why not: §14.2 through `Manipulation`, with the
## profile's own range and mass limit.
static func begin(eye: Vector3, target: Node, profile_name: String,
		space: PhysicsDirectSpaceState3D,
		caster: CollisionObject3D = null) -> Dictionary:
	if not PROFILES.has(profile_name):
		return {"applied": false, "refused": Manipulation.UNKNOWN_PROFILE}
	var numbers: Dictionary = PROFILES[profile_name]
	var exclude: Array[RID] = []
	if caster != null:
		exclude.append(caster.get_rid())
	var why := Manipulation.target_refusal("PIN", target, eye, numbers,
			space, exclude)
	if why != "":
		return {"applied": false, "refused": why}
	var pinned: ManipulableBody = target
	var pin := VerbPin.new()
	pin.name = "VerbPin"
	pin.body = pinned
	pin.profile = profile_name
	pin.duration = float(numbers["duration"])
	pin.left = pin.duration
	var ledger := VerbRelations.of(caster)
	var same_profile := ledger.relations().filter(func(held: Variant) -> bool:
		return held is VerbPin and (held as VerbPin).profile == profile_name)
	while same_profile.size() >= int(numbers["max_pinned"]):
		(same_profile.pop_front() as VerbPin).release(MAX_PINNED)
	ledger.admit(pin)
	pinned.add_child(pin)
	pin._start()
	return {"applied": true, "refused": "", "pin": pin}


func active() -> bool:
	return release_reason == ""


func bodies() -> Array:
	return [body] if is_instance_valid(body) else []


func release(reason: String) -> void:
	if release_reason != "":
		return
	release_reason = reason
	if is_instance_valid(body):
		body.freeze = _saved_freeze
		body.freeze_mode = _saved_mode
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
	released.emit(reason)
	queue_free()


func _start() -> void:
	_saved_freeze = body.freeze
	_saved_mode = body.freeze_mode
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true


func _physics_process(delta: float) -> void:
	if release_reason != "":
		return
	left -= delta
	# A hair under zero-ish, because 360 ticks of 1/60 s sum to a float a
	# hair under 6.0: the pin ends on the 360th.
	if left <= 0.0001:
		release(EXPIRED)


## THE BODY LEFT THE TREE -- its room unloaded, or it was destroyed --
## taking the pin with it.
func _exit_tree() -> void:
	if release_reason == "":
		release_reason = TARGET_GONE
		released.emit(TARGET_GONE)
