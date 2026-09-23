class_name Manipulation
extends RefCounted

## ONE VERB RESOLVING TO FORCE, RANGE AND MASS.
##
## `docs/AMALGAM_BRIDGE.md` §6.3 item 2, and the engine half of
## `schemas/physics.py`'s §29.3.1 and §29.3.2.
##
## **Identity is Boolean; qualification is numeric.** §30.6 sees one
## Boolean -- does this host grant `capability:core:manipulate` -- whose
## value is fixed for the Zone. The newtons never reach the verifier: the
## moment `grants_manipulate` returned a number, the reachability search
## would have a newton in it. The numbers are resolved HERE, at the entry
## check, and are never stored (§4.2), so a player cannot qualify by
## equipping Gear they then remove.
##
## The envelope constants come from `Constants`, which is generated from
## `schemas/physics.py`. Retyping 700 N here is how the two lanes come to
## disagree about whether a mandatory route is passable.

## §29.3.1: granted by a `PUSH`, `PULL` or `HOLD` verb and never by the
## other nine, and never for any other reason.
static func grants_manipulate(verbs: Array) -> bool:
	for verb: Variant in verbs:
		if str(verb).to_upper() in Constants.MANIPULATE_VERBS:
			return true
	return false

## A resolved host's manipulation numbers. Not stored anywhere: a pure
## function of host composition, equipped Gear and active Mods.
class Envelope extends RefCounted:
	var force_n := 0.0
	var range_m := 0.0
	var mass_limit_kg := 0.0

	static func of(force: float, reach: float, mass: float) -> Envelope:
		var out := Envelope.new()
		out.force_n = force
		out.range_m = reach
		out.mass_limit_kg = mass
		return out

	## Exactly `ENVELOPE_*`, for a host authored at the minimum.
	static func at_the_envelope() -> Envelope:
		return Envelope.of(Constants.ENVELOPE_FORCE_N,
				Constants.ENVELOPE_RANGE_M, Constants.ENVELOPE_MASS_KG)

	## ALL THREE, not two of three: a puzzle authored at the envelope can
	## need the reach and the force and the mass in one motion.
	func qualifies() -> bool:
		return force_n >= Constants.ENVELOPE_FORCE_N \
				and range_m >= Constants.ENVELOPE_RANGE_M \
				and mass_limit_kg >= Constants.ENVELOPE_MASS_KG

	## Which minima this host misses. A player refused entry is owed the
	## reason, and "your PUSH is too weak" is not one.
	func shortfall() -> Array[String]:
		var out: Array[String] = []
		if force_n < Constants.ENVELOPE_FORCE_N:
			out.append("force %.0f N, needs %.0f N"
					% [force_n, Constants.ENVELOPE_FORCE_N])
		if range_m < Constants.ENVELOPE_RANGE_M:
			out.append("range %.1f m, needs %.1f m"
					% [range_m, Constants.ENVELOPE_RANGE_M])
		if mass_limit_kg < Constants.ENVELOPE_MASS_KG:
			out.append("mass limit %.0f kg, needs %.0f kg"
					% [mass_limit_kg, Constants.ENVELOPE_MASS_KG])
		return out

## Reasons a push resolves to nothing. Named, because "nothing moved" is
## not a report: out of reach, too heavy and bolted down are three
## different answers and each sends the player somewhere different.
const OUT_OF_REACH := "out_of_reach"
const TOO_HEAVY := "too_heavy"
const CONSTRAINED := "constrained"
## Pushing a body toward the point it already occupies. Its own reason,
## because folding it into `out_of_reach` sends whoever reads the
## evidence looking for a range problem that is not there -- which is
## what it did to the first version of this suite's own test.
const NO_DIRECTION := "no_direction"

## Applies one physics frame of push, and says what happened.
##
## `from` is where the host is; `toward` is where they are pushing. The
## force is applied at the body's centre: torque from an off-centre push
## is a later question and a replay that depended on it would depend on
## exactly where a player stood, which is not something a reference
## solution can state.
## Was this body too heavy a CLASS a moment ago, and is it not now?
##
## Exactly Design 5 §15.2's clause and nothing wider: the body's own
## kilograms still read `HEAVY`, and what it is carrying has brought its
## effective class below that. A body that was never `HEAVY` gains
## nothing here, and neither does one carrying nothing.
static func _lightened_into_reach(body: ManipulableBody) -> bool:
	var raw := MassClass.of_mass(body.mass, not body.constrained)
	if raw != MassClass.HEAVY:
		return false
	return not MassClass.at_least(body.mass_class(), MassClass.HEAVY)

static func push(body: ManipulableBody, from: Vector3, toward: Vector3,
		envelope: Envelope) -> Dictionary:
	if body.constrained:
		return {"applied": 0.0, "refused": CONSTRAINED}
	var reach := from.distance_to(body.global_position)
	if reach > envelope.range_m:
		return {"applied": 0.0, "refused": OUT_OF_REACH,
				"reach_m": reach}
	# KILOGRAMS FIRST, AND THE CLASS CAN ONLY OPEN THE DOOR.
	#
	# Design 5 §15.2 gives `lightened` "becomes Physics-eligible if it
	# was `HEAVY`" -- a PERMISSIVE effect. So the kilogram test stays
	# exactly as it was and nothing that can be pushed today stops being
	# pushable; the class test only ever admits something the kilograms
	# refused. That matters at one number in particular:
	# `ENVELOPE_MASS_KG` is 120.0 and `MassClass.MEDIUM_BELOW` is 120.0,
	# read with different comparators, so a body at exactly 120.0 kg is
	# pushable today and is `HEAVY` class-wise. Reading class as the
	# authority would have silently refused it.
	if body.mass > envelope.mass_limit_kg \
			and not _lightened_into_reach(body):
		return {"applied": 0.0, "refused": TOO_HEAVY,
				"mass_kg": body.mass}
	var direction := Vector3(toward.x - body.global_position.x, 0.0,
			toward.z - body.global_position.z)
	if direction.length() < 0.001:
		return {"applied": 0.0, "refused": NO_DIRECTION}
	# A CONTINUOUS FORCE, and it stays one. `lightened` doubles an
	# incoming IMPULSE; a force is not an impulse, and this body's
	# kilograms are unchanged, so the same newtons produce the same
	# acceleration whatever its class. Doubling both would be inventing
	# an effect the contract does not describe.
	body.receive_force(direction.normalized() * envelope.force_n)
	return {"applied": envelope.force_n, "refused": ""}


# ---------------------------------------------------------------------------
# §14.2 FOR EVERY TARGETED VERB, AND §14.3's IMPULSE VERBS, PUSH AND PULL
# -- RUNTIME ONLY (O05-08)
# ---------------------------------------------------------------------------

## Design 2 §14.3's three `ab_physics_*` profiles, exactly: `range`,
## `force` and `verb_mass_limit`. PUSH and PULL read all three. HOLD and
## ALIGN have no profile table of their own: they are verbs of the same
## family (§12.1 `PHYSICS_VERB`) and read this row's `range` and
## `verb_mass_limit`, the only numbers the family has.
const PHYSICS_PROFILES := {
	"ab_physics_light": {"range_m": 20.0, "force_n": 700.0,
			"mass_limit_kg": 120.0},
	"ab_physics_standard": {"range_m": 24.0, "force_n": 1400.0,
			"mass_limit_kg": 260.0},
	"ab_physics_strong": {"range_m": 28.0, "force_n": 2600.0,
			"mass_limit_kg": 400.0},
}
## §14.4: the impulse velocity ceiling, and the vertical ceiling on any
## player-caused impulse -- the defence against the infinite staircase.
const IMPULSE_VELOCITY_MAX := 30.0
const VERTICAL_VELOCITY_MAX := 14.0

## §14.2's refusals, each its own answer, beside `push`'s above.
const NO_TARGET := "no_target"
const NOT_AN_IMPULSE_VERB := "not_an_impulse_verb"
const UNKNOWN_PROFILE := "unknown_profile"
const NEVER_THE_PLAYER := "never_the_player"
const ACTOR_MASS_UNMODELLED := "actor_mass_unmodelled"
const NOT_MANIPULABLE := "not_manipulable"
const FIXED := "fixed"
const NOT_PERMITTED := "not_permitted"
const NO_LINE_OF_SIGHT := "no_line_of_sight"
## §14.2's actor rule, for a verb it never admits on an enemy (HOLD,
## ALIGN, SETTLE, ...), as distinct from `actor_mass_unmodelled`: that
## one is a verb the rule admits and this runtime cannot yet compute.
const ACTOR_RULE := "actor_rule"
## The targeted verbs §14.2 admits on an enemy (the fields are the rest).
const ACTOR_VERBS := ["PUSH", "PULL", "PIN"]


## §14.2 FOR ONE TARGETED VERB: "" when `target` is eligible, otherwise
## the refusal's name. PUSH, PULL, HOLD and ALIGN all ask here, so the
## table is read in one place. `numbers` is the verb's profile row;
## `exclude` is what the line of sight may pass through (the caster).
##
## `turns_on_a_hinge`: §14.2's one exception, "ROTATE about a constrained
## axis" -- a FIXED body with a hinge is ROTATE's to drive, and nothing so
## heavy is weighed against a verb mass limit it was never meant to meet.
static func target_refusal(verb: String, target: Node, eye: Vector3,
		numbers: Dictionary, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID] = [], turns_on_a_hinge := false) -> String:
	if target == null or not is_instance_valid(target):
		# §12.3: "A verb aimed at nothing spends nothing."
		return NO_TARGET
	# §14.2's player and actor rules, before anything is measured.
	if target.is_in_group("player"):
		return NEVER_THE_PLAYER
	if target is Enemy:
		# The rule admits PUSH, PULL and PIN on an enemy, and each of them
		# reads the target's `mass_kg` (§14.3). No enemy has one in this
		# runtime, so its answer would be a guess -- refused by name
		# rather than invented. Every other verb the rule refuses outright.
		# Bosses (§14.2) take no verb either way.
		return ACTOR_MASS_UNMODELLED if verb in ACTOR_VERBS else ACTOR_RULE
	if not (target is ManipulableBody):
		return NOT_MANIPULABLE
	var body: ManipulableBody = target
	# §14.2: FIXED responds to no verb but DETACH and ROTATE -- bolted,
	# 400 kg and over, or anchored.
	var fixed := body.mass_class() == MassClass.FIXED
	if fixed and not turns_on_a_hinge:
		return FIXED
	# KILOGRAMS, with Design 5 §15.2's one permissive door, exactly as
	# `push` reads it: a lightened HEAVY body becomes eligible. Not for a
	# FIXED body on a hinge: §14.2 admits it by its axis, not its weight.
	if not fixed and body.mass > float(numbers["mass_limit_kg"]) \
			and not _lightened_into_reach(body):
		return TOO_HEAVY
	if eye.distance_to(body.global_position) > float(numbers["range_m"]):
		return OUT_OF_REACH
	# §14.2's progression rule, with Design 2 §4.8's default.
	if body.is_in_group(Constants.REQUIRED_OBJECT_GROUP) \
			and not body.physics_permitted:
		return NOT_PERMITTED
	if not in_sight(space, eye, body, exclude):
		return NO_LINE_OF_SIGHT
	return ""


## ONE IMPULSE, ON COMMIT: §14.3's PUSH, away from the player along the
## aim ray, and PULL, toward the player along it.
##
## **RUNTIME ONLY, AND SAID SO.** No Echo Action reaches this. The
## accepted delivery is the Amalgam's atom grammar (§11.7: a costed
## `effect_physics_basic` atom carrying a `physics_verb` discriminator),
## which the running Echo model does not implement for any verb; a
## primitive here would be a second, unreconciled path. So the verb is
## built to §14.2/§14.3, verified by direct invocation, and offered to
## nothing (`PROD_OV05.md`, O05-08). Nor is it `push` above: that is a
## HELD force at the envelope, the replay harness's question; this is
## the verb's.
##
## `eye` is where the aim ray starts and `aim` its direction; `target` is
## what the caller's ray found; `exclude` is what the line of sight may
## pass through (the caster's own body).
static func impulse_verb(verb: String, target: Node, eye: Vector3,
		aim: Vector3, profile: String, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID] = []) -> Dictionary:
	if verb != "PUSH" and verb != "PULL":
		return {"applied": false, "refused": NOT_AN_IMPULSE_VERB}
	if not PHYSICS_PROFILES.has(profile):
		return {"applied": false, "refused": UNKNOWN_PROFILE}
	var numbers: Dictionary = PHYSICS_PROFILES[profile]
	var why := target_refusal(verb, target, eye, numbers, space, exclude)
	if why != "":
		return {"applied": false, "refused": why}
	var body: ManipulableBody = target
	var direction := aim.normalized() if verb == "PUSH" \
			else -aim.normalized()
	# §14.3: `impulse_velocity = clamp(force / mass_kg, 0.0, 30.0)`, one
	# impulse, on commit. `lightened` doubles an incoming impulse (Design
	# 5 §15.2); §14.4's ceilings bound what results, whatever doubled it.
	var speed := clampf(float(numbers["force_n"]) / maxf(body.mass, 0.001),
			0.0, IMPULSE_VELOCITY_MAX)
	var scale := body.impulse_scale()
	var velocity := _within_ceilings(direction * speed * scale)
	body.receive_impulse(velocity * body.mass / scale)
	return {"applied": true, "refused": "", "velocity": velocity}


## §14.4, in one place: 30 m/s overall and 14 m/s vertically.
static func _within_ceilings(velocity: Vector3) -> Vector3:
	var out := velocity
	if out.length() > IMPULSE_VELOCITY_MAX:
		out = out.normalized() * IMPULSE_VELOCITY_MAX
	out.y = clampf(out.y, -VERTICAL_VELOCITY_MAX, VERTICAL_VELOCITY_MAX)
	return out


## §14.2: "Unobstructed from eye to target origin." Anything the ray
## meets on the way, other than the target and what the caller excluded,
## is in the way.
static func in_sight(space: PhysicsDirectSpaceState3D, eye: Vector3,
		body: Node3D, exclude: Array[RID] = []) -> bool:
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye,
			body.global_position)
	var skip: Array[RID] = exclude.duplicate()
	if body is CollisionObject3D:
		skip.append((body as CollisionObject3D).get_rid())
	query.exclude = skip
	return space.intersect_ray(query).is_empty()


# ---------------------------------------------------------------------------
# §14.3's SETTLE -- RUNTIME ONLY (O05-08.1)
# ---------------------------------------------------------------------------

## §14.3's one SETTLE profile, exactly.
const SETTLE_PROFILES := {
	"ab_settle_standard": {"range_m": 25.0, "radius_m": 8.0},
}
## A body in the volume left alone because machinery is driving it.
const DRIVEN := "driven_by_machinery"
## How many bodies one volume query may return. A room holds far fewer.
const SETTLE_MAX_BODIES := 256

## "Sets linear and angular velocity to zero on every eligible object
## within `radius` of the aim point, and forces `sleeping = true` on the
## next tick. Does not affect constrained objects currently driven by
## machinery, and does not affect actors." (§14.3)
##
## A VOLUME VERB: §14.2 asks line of sight to the volume's centre only,
## and a body is in the volume when its ORIGIN is within `radius`. Only
## a `ManipulableBody` can be eligible, so an actor never is. Of the
## rest, three are left alone and named: a `FIXED` body (§14.2: no verb
## but DETACH and ROTATE), a required object whose package withholds
## physics (§4.8), and a body in a constraint that machinery is driving
## (`Constraints.driven`). The profile has no `verb_mass_limit`, so
## nothing lighter than `FIXED` is refused by its kilograms.
##
## **RUNTIME ONLY**, as the impulse verbs above: nothing delivers it.
static func settle(eye: Vector3, aim_point: Vector3, profile: String,
		space: PhysicsDirectSpaceState3D, tree: SceneTree,
		exclude: Array[RID] = []) -> Dictionary:
	if not SETTLE_PROFILES.has(profile):
		return {"applied": false, "refused": UNKNOWN_PROFILE}
	var numbers: Dictionary = SETTLE_PROFILES[profile]
	if eye.distance_to(aim_point) > float(numbers["range_m"]):
		return {"applied": false, "refused": OUT_OF_REACH}
	if not _clear(space, eye, aim_point, exclude):
		return {"applied": false, "refused": NO_LINE_OF_SIGHT}
	var radius := float(numbers["radius_m"])
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, aim_point)
	query.collide_with_areas = false
	var solvers := tree.get_nodes_in_group(Constraints.GROUP)
	var settled: Array[ManipulableBody] = []
	var left := {}
	for hit: Dictionary in space.intersect_shape(query, SETTLE_MAX_BODIES):
		var body := hit.get("collider") as ManipulableBody
		if body == null or settled.has(body) or left.has(body) \
				or body.global_position.distance_to(aim_point) > radius:
			continue
		var why := ""
		if body.mass_class() == MassClass.FIXED:
			why = FIXED
		elif body.is_in_group(Constants.REQUIRED_OBJECT_GROUP) \
				and not body.physics_permitted:
			why = NOT_PERMITTED
		else:
			for solver: Node in solvers:
				if (solver as Constraints).driven(body):
					why = DRIVEN
					break
		if why != "":
			left[body] = why
			continue
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		settled.append(body)
	if not settled.is_empty():
		# "On the next tick": the solver steps once with the velocities
		# zeroed, and the next physics frame puts every one to sleep.
		tree.physics_frame.connect(func() -> void:
			for body: ManipulableBody in settled:
				if is_instance_valid(body):
					body.sleeping = true,
				CONNECT_ONE_SHOT)
	return {"applied": true, "refused": "", "settled": settled,
			"left": left}


## Nothing between `from` and `to` but what the caller excluded. A
## volume's centre is usually a point on a surface -- where the aim ray
## landed -- so the test stops 5 cm short rather than meet that surface.
static func _clear(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3, exclude: Array[RID]) -> bool:
	if space == null:
		return false
	var reach := from.distance_to(to)
	if reach < 0.05:
		return true
	var query := PhysicsRayQueryParameters3D.create(from,
			from + (to - from) * ((reach - 0.05) / reach))
	query.exclude = exclude
	return space.intersect_ray(query).is_empty()
