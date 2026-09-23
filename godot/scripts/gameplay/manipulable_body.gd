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

## §10.1's flag: may a hand pick this up at all? False unless the content
## that made the body says so, so every existing crate stays something
## that is pushed and not picked up. Kilograms decide the rest
## (`HandCarry.refusal`).
@export var carriable := false

## Design 2 §4.8's `physics_permitted`, and its default. §14.2: an object
## with `required = true` responds to a verb only while this is true, and
## Design 2 makes true the default. Nothing sets it false today; the rule
## is here so the verb runtime asks the question the contract asks.
@export var physics_permitted := true

## Design 2 §4.8's `material`: one of METAL, STONE, WOOD, COMPOSITE or
## GLASS. "" for a body nothing has said the material of, which cannot be
## attached by anything (`VerbAttach`, O05-08.3).
@export var material := ""
## §4.8's `attach_points` (`AttachPoint`). Empty for every body today.
var attach_points: Array = []
## As an assembly's root: the welds hanging from it, oldest first
## (`VerbAttach`). Empty for a body nothing is welded to.
var welds: Array = []
## As a welded part: the root it is welded into, or null.
var welded_into: ManipulableBody = null

## The player holding this, or null. Set only by `HandCarry`.
var carried_by: Node = null
## The consumer this was installed in, or null. Set only by the consumer.
var installed_in: Node = null

## Put down by the hand carrying it, and why ("drop", "death",
## "occluded", ...). A transported object's owner listens to this.
signal dropped_by_carry(reason: String)

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

## THE PLAYER'S `interact`, aimed at this body: pick it up if a hand may.
##
## First, the base kit's undo of a player's own weld (O05-08.3): a player
## with no DETACH Echo must not be able to softlock their construction.
## Only a weld a player made; an authored one stays.
func interact(player: Node) -> void:
	if VerbAttach.undo_latest(self):
		return
	var who := player as Player
	if who != null and who.carry != null:
		who.carry.try_pick_up(self)

func interact_prompt() -> String:
	if not VerbAttach.latest_player_weld(self).is_empty():
		return "DETACH"
	return HandCarry.prompt_for(self)

func _ready() -> void:
	can_sleep = true
	sleeping = false
	custom_integrator = false
	# NOTHING TO TICK UNTIL SOMETHING IS APPLIED. A body nobody has
	# touched costs exactly what it used to, which matters because the
	# replay harness measures this class for determinism.
	set_physics_process(false)

# ----------------------------------------------- semantic mass class

## THE STATUSES THIS BODY IS CARRYING, as an `object` target.
##
## Null until something applies one, so a body nobody has touched costs
## exactly what it used to -- this class is measured by the replay
## harness for determinism and must not grow a per-frame cost it does
## not need.
##
## `side` is `object`: Amalgam §15.1's target kind, the same field the
## schema's `StatusComponent.target` matches against. `StatusEffects`
## refuses a kind the runtime does not implement FOR THAT TARGET, so a
## room cannot start on a crate what the bridge would refuse to emit at
## one.
var statuses: StatusEffects = null

## How much more an incoming IMPULSE moves this body. Design 5 §15.2
## gives `lightened` "incoming impulse x2.0".
const LIGHTENED_IMPULSE := 2.0

## Apply a Status to this body. The real path -- there is no second,
## room-local vocabulary and no stand-in.
func apply_status(kind: String, duration: float, magnitude: float) -> void:
	if statuses == null:
		statuses = StatusEffects.new()
		statuses.side = "object"
	var before := statuses.active_kinds().size()
	statuses.apply(kind, duration, magnitude)
	if statuses.active_kinds().size() == before and not statuses.has(kind):
		# Refused. Nothing started, so nothing needs ticking.
		return
	set_physics_process(true)

## The class this body reads as RIGHT NOW.
##
## `constrained` and not `freeze`: a crate parked on its guide track is
## physically held still and is still a manipulable HEAVY crate, while a
## bolted one is `FIXED` by contract. Reading the physical flag would
## make a machine's parking brake change what a sensor sees.
func mass_class() -> String:
	return MassClass.read(mass, not constrained, statuses)

## AN INSTANTANEOUS IMPULSE, scaled by what the body is carrying.
##
## The contract says IMPULSE, and the distinction is kept rather than
## flattened: `lightened` doubles what a single impulse does, and leaves
## a continuous force alone. That is not a technicality -- a constant
## force already produces the same acceleration on this body whatever
## its class, because `lightened` changes the CLASS and never the
## kilograms. Doubling both would have been inventing an effect the
## contract does not describe.
func receive_impulse(impulse: Vector3) -> void:
	sleeping = false
	apply_central_impulse(impulse * impulse_scale())

## A CONTINUOUS FORCE, in newtons. Deliberately unscaled; see above.
func receive_force(force: Vector3) -> void:
	sleeping = false
	apply_central_force(force)

func impulse_scale() -> float:
	if statuses != null and statuses.has("lightened"):
		return LIGHTENED_IMPULSE
	return 1.0

func _physics_process(delta: float) -> void:
	if statuses == null:
		set_physics_process(false)
		return
	statuses.tick(delta)
	if statuses.active_kinds().is_empty():
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
