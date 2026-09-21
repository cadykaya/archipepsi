class_name ManipulableBody
extends RigidBody3D

## A BODY THE PLAYER CAN MOVE. The substrate, and nothing more than that.
##
## `docs/AMALGAM_BRIDGE.md` §6.3 item 1: "a rigid body that rests and can
## be pushed -- until this exists nothing else can be measured." Until
## today the engine had no `RigidBody3D` anywhere in it, so the physics
## contract in `schemas/physics.py` described a system with no runtime
## and `ReplayEvidence` had nothing that could produce one.
##
## **What it is NOT.** It is not a puzzle, not an activity, not a Check
## and not a verb. `Manipulation` is the verb half; a package that
## authors a puzzle out of these is level 3 and is not built. Keeping
## them apart is why `SceneDigest` can name the setup a replay ran
## against before any replay exists.
##
## **IT RESTS.** A body that never sleeps is a body whose resting place
## is whatever the solver happened to be doing when somebody looked, and
## `scene_digest` reads `sleeping` for exactly that reason. The damping
## and sleep threshold here are the difference between "came to rest" and
## "is still settling by an amount below the digest's quantum".

## `body_id` in `PhysicsSetup`. Lower snake, because that is what the
## bridge's `BodySpec` pattern admits, and a body whose id the bridge
## refuses is a body no evidence can name.
@export var body_id := "crate"

## `constrained` in `PhysicsSetup`: a body bolted to something, which the
## contract reasons about and a push may not move.
@export var constrained := false

## Damping, chosen so a pushed crate coasts to a stop rather than sliding
## for twenty metres. Not a tuning knob anybody should reach for without
## re-running the replay evidence: it is inside `scene_digest`, so
## changing it invalidates every record written under the old value.
const LINEAR_DAMP := 1.2
const ANGULAR_DAMP := 2.0

## HOW LONG BEFORE A BODY SLEEPS IS NOT A KNOB HERE. Godot's sleep
## threshold and delay are project settings, not per-body properties, so
## a constant on this class claiming to set one would be a number that
## looks load-bearing and is not. `scene_digest` records `sleeping`
## because the setting is part of the experiment; `at_rest` asks the
## solver rather than re-deriving it.

## FRICTION, DERIVED FROM THE ENVELOPE RATHER THAN CHOSEN.
##
## §29.3.2 promises that a host at exactly `ENVELOPE_FORCE_N` can move a
## body at exactly `ENVELOPE_MASS_KG`. Godot's default friction is 1.0,
## and 1.0 x 120 kg x 9.8 m/s^2 is 1176 N against 700 N of push -- so
## under the default the contract promises something the substrate
## refuses, and a mandatory route authored at the envelope would be
## unsolvable by the host the verifier says qualifies. The engine found
## that by measuring it: the first run of `godot-physics` reported
## "700 N moved 120 kg by 0.00 m".
##
## The bound is mu < F / (m g). This takes two thirds of it, so a body at
## the limit ACCELERATES rather than barely creeping and a host with any
## headroom moves it decisively. Derived, not typed, because the numbers
## it derives from are the bridge's and may change.
const FRICTION_HEADROOM := 2.0 / 3.0

static func envelope_friction() -> float:
	return FRICTION_HEADROOM * Constants.ENVELOPE_FORCE_N \
			/ (Constants.ENVELOPE_MASS_KG * gravity())

## The gravity a body actually falls under, read rather than assumed:
## `scene_digest` records it for the same reason.
static func gravity() -> float:
	return float(ProjectSettings.get_setting(
			"physics/3d/default_gravity", 9.8))

static func create(id: String, mass_kg: float, size: Vector3,
		bolted := false) -> ManipulableBody:
	var body := ManipulableBody.new()
	body.name = "Body_%s" % id
	body.body_id = id
	body.mass = mass_kg
	body.constrained = bolted
	body.linear_damp = LINEAR_DAMP
	body.angular_damp = ANGULAR_DAMP
	# ITS OWN MATERIAL, never the project default. A shared or inherited
	# material is the case `scene_digest` refuses to resolve, and a body
	# whose friction came from somewhere else is a body whose
	# manipulability depends on a setting nobody looked at.
	var material := PhysicsMaterial.new()
	material.friction = envelope_friction()
	material.bounce = 0.0
	body.physics_material_override = material
	var shape := CollisionShape3D.new()
	shape.name = "hull"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	# A BOLTED BODY IS BOLTED, not merely heavy. `freeze` is what the
	# contract's `constrained` means physically: a push resolves against
	# it and it does not move, which is a different outcome from a push
	# that is too weak and has to read differently in the evidence.
	body.freeze = bolted
	if bolted:
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	return body

func _ready() -> void:
	can_sleep = true
	sleeping = false
	custom_integrator = false
	# NOTHING TO TICK UNTIL SOMETHING IS APPLIED. A body nobody has
	# touched costs exactly what it used to, which matters because the
	# replay harness measures this class for determinism.
	set_physics_process(false)

# ----------------------------------------------- semantic mass class

## Where the real Status would live.
##
## Design 2 §10.2 derives an object's mass CLASS from its kilograms, and
## Design 5 §15.2 gives `lightened` the effect "`mass_class` drops one
## step". `MassClass.read` already honours both that and `anchored`, so
## the day a Status can be applied to a body this member starts being
## consulted and nothing else changes.
var statuses: StatusEffects = null

## A PROVISIONAL, ROOM-LOCAL class shift, with the exact shape the
## Status would have and a name that cannot be mistaken for it.
##
## **`lightened` is not in the engine.** `StatusEffects.apply` refuses
## any kind outside `Constants.ECHO_STATUS_KINDS`, which is GENERATED
## from the bridge schema's closed `StatusKind`, and `lightened` is not
## among its twelve. Widening that enum is not a one-line change: a kind
## the schema admits and no system implements is precisely the "inert
## component" failure `StatusEffects.apply`'s own comment says the
## staged gates exist to prevent, and `lightened`'s specified effect
## spans impulse, wind, conveyors and Physics eligibility as well as
## class. That is `B3`, it is a shared-schema change, and it is raised
## as D-7 rather than taken here.
var provisional_class_shift := 0

var _shift_left := 0.0

## Lower this body's semantic class by `steps` for `seconds`.
##
## PROVISIONAL -- see `provisional_class_shift`. Every claim measured
## through it says so.
func shift_class_provisionally(steps: int, seconds: float) -> void:
	provisional_class_shift = maxi(provisional_class_shift, steps)
	_shift_left = maxf(_shift_left, seconds)
	set_physics_process(true)

## Seconds left on the provisional shift.
func shift_left() -> float:
	return _shift_left

## The class this body reads as RIGHT NOW.
##
## `constrained` and not `freeze`: a crate parked on its guide track is
## physically held still and is still a manipulable HEAVY crate, while a
## bolted one is `FIXED` by contract. Reading the physical flag would
## make a machine's parking brake change what a sensor sees.
func mass_class() -> String:
	var base := MassClass.read(mass, not constrained, statuses)
	if provisional_class_shift <= 0:
		return base
	return MassClass.step_down(base, provisional_class_shift)

func _physics_process(delta: float) -> void:
	if statuses != null:
		statuses.tick(delta)
	if _shift_left > 0.0:
		_shift_left = maxf(_shift_left - delta, 0.0)
		if _shift_left <= 0.0:
			provisional_class_shift = 0
	if _shift_left <= 0.0 and (statuses == null
			or statuses.active_kinds().is_empty()):
		set_physics_process(false)

## The contract's view of this body: exactly `BodySpec`, no more.
func spec() -> Dictionary:
	return {"body_id": body_id, "mass_kg": mass,
			"constrained": constrained}

## HAS IT COME TO REST? Asked of the solver, not of a velocity threshold
## somebody picked here -- two thresholds for one question is how a
## "settled" report and the physics disagree.
func at_rest() -> bool:
	return sleeping or freeze
