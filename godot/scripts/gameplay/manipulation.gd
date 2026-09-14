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
static func push(body: ManipulableBody, from: Vector3, toward: Vector3,
		envelope: Envelope) -> Dictionary:
	if body.constrained:
		return {"applied": 0.0, "refused": CONSTRAINED}
	var reach := from.distance_to(body.global_position)
	if reach > envelope.range_m:
		return {"applied": 0.0, "refused": OUT_OF_REACH,
				"reach_m": reach}
	if body.mass > envelope.mass_limit_kg:
		return {"applied": 0.0, "refused": TOO_HEAVY,
				"mass_kg": body.mass}
	var direction := Vector3(toward.x - body.global_position.x, 0.0,
			toward.z - body.global_position.z)
	if direction.length() < 0.001:
		return {"applied": 0.0, "refused": NO_DIRECTION}
	body.sleeping = false
	body.apply_central_force(direction.normalized() * envelope.force_n)
	return {"applied": envelope.force_n, "refused": ""}
