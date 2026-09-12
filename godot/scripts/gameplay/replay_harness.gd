class_name ReplayHarness
extends RefCounted

## THREE RUNS, FIXED SOLVER SETTINGS, A PROVIDER AT EXACTLY THE ENVELOPE.
##
## `docs/AMALGAM_BRIDGE.md` §6.3 item 3, and the deliverable the bridge
## has been waiting on: `ReplayEvidence` in `schemas/physics.py` is
## already written and validated and nothing could produce one.
##
## **At exactly the envelope, never above it.** Replaying with a strong
## provider proves a strong provider can solve it, which is not the claim
## §23.5 check 20 makes. `ReplayEvidence.at_the_envelope` refuses
## anything else, so the numbers are read from `Constants` and not
## offered as a parameter.
##
## **Per run, never a union.** A record saying "all three latched, and
## here is what latched somewhere" cannot tell three good runs from three
## runs that each latched a different third of the requirement. Each run
## gets its own tuple, in run order.
##
## **A LATCH LATCHES.** It is evaluated every physics frame and once true
## it stays true for that run: a crate that crosses the region and rolls
## back out still solved the puzzle. The run's answer is what was true at
## any point in it.
##
## **REFUSED IS NOT UNLATCHED.** A package this engine cannot replay --
## a latch kind with no runtime, a step it does not know, a body the
## stage does not build -- comes back as a refusal naming what it was.
## Reporting it as "did not latch" would read as "the puzzle is not
## solvable", which is a verdict about the content instead of about the
## harness.

## §23.5 check 20 replays three times. Not a parameter: two runs is not
## the check and four is a different one.
const RUNS := 3

## Latch kinds this engine can observe. The other two in the contract's
## `Literal` -- `CONSTRAINT_STATE` and `ATTACH_SENSOR` -- need joints and
## attachment sensors, and neither exists. Named here rather than
## silently unhandled, because a kind that falls through a match and
## reports "not latched" is a harness claiming a puzzle is unsolvable.
const OBSERVABLE_KINDS := ["POSITION_REGION", "WEIGHT_THRESHOLD"]

## The stage one run is performed in. The harness builds a FRESH one per
## run: three runs that share a stage are one run with its answer read
## three times.
class Stage extends RefCounted:
	var root: Node3D = null
	## `body_id -> ManipulableBody`.
	var bodies := {}
	## `region_id -> AABB`, in world space, for `POSITION_REGION`.
	var regions := {}
	## `plate_id -> AABB`, in world space, for `WEIGHT_THRESHOLD`.
	var plates := {}

## Replays `package` and returns a `ReplayEvidence` payload, or a
## refusal. `build` is called once per run and must return a `Stage`
## already added to the tree.
static func replay(tree: SceneTree, package: Dictionary,
		build: Callable) -> Dictionary:
	var refusal := _unreplayable(package)
	if refusal != "":
		return {"refused": refusal}
	var errors: Array[String] = []
	var built := PhysicsPackage.from_dict(package, errors)
	if built == null:
		return {"refused": "the package would not build: %s" % str(errors)}
	var per_run: Array = []
	for _run in RUNS:
		var stage: Stage = build.call()
		var latched: Variant = await _one_run(tree, built, stage)
		if typeof(latched) != TYPE_ARRAY:
			return {"refused": str(latched)}
		per_run.append(latched)
		if stage.root != null:
			stage.root.queue_free()
		await tree.process_frame
	return {
		"package_id": built.package_id,
		"content_digest": built.digest(),
		"provider_force_n": Constants.ENVELOPE_FORCE_N,
		"provider_range_m": Constants.ENVELOPE_RANGE_M,
		"provider_mass_kg": Constants.ENVELOPE_MASS_KG,
		"per_run_latched": per_run,
	}

## Why this package cannot be replayed here, or "".
static func _unreplayable(package: Dictionary) -> String:
	var setup: Variant = package.get("setup")
	if typeof(setup) != TYPE_DICTIONARY:
		return "the package has no setup, so there is nothing to replay"
	var solution: Variant = package.get("reference_solution")
	if typeof(solution) != TYPE_DICTIONARY \
			or (solution as Dictionary).get("steps", []).is_empty():
		return "the package has no reference solution, so there is no "\
				+ "run to make"
	for raw: Variant in package.get("latch_conditions", []):
		var latch: Dictionary = raw
		var kind := str(latch.get("kind", ""))
		if not kind in OBSERVABLE_KINDS:
			return ("latch '%s' is a %s, and this engine observes only %s"
					% [str(latch.get("latch_id", "?")), kind,
						str(OBSERVABLE_KINDS)])
	return ""

## One run. Returns the latched ids, or a String naming the refusal.
static func _one_run(tree: SceneTree, package: PhysicsPackage,
		stage: Stage) -> Variant:
	for spec: PhysicsPackage.BodySpec in package.setup.bodies:
		if not stage.bodies.has(spec.body_id):
			return ("the stage builds no body '%s', which the setup "
					% spec.body_id + "declares")
	var latched := {}
	var envelope := Manipulation.Envelope.at_the_envelope()
	## Each `settle` gets the package's whole timeout rather than a
	## share of it: §23.5's `settle_timeout_s` is how long a body may
	## take to come to rest, and a solution with two settles is not one
	## whose bodies rest twice as fast.
	var settle_budget := package.setup.solver.settle_timeout_s
	for step: String in package.reference_solution:
		var parts := step.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"push":
				if parts.size() < 5:
					return "malformed step '%s'" % step
				var body: ManipulableBody = stage.bodies.get(parts[1])
				if body == null:
					return "step '%s' pushes a body the stage has not "\
							% step + "built"
				var toward := body.global_position + Vector3(
						float(parts[2]), 0.0, float(parts[3])) * 10.0
				var frames := _frames(float(parts[4]), package)
				for _i in frames:
					# THE HOST FOLLOWS THE CRATE, two metres behind it
					# and a little above, recomputed each frame -- which
					# is what a player pushing something does. A host
					# pinned where the crate started would drift out of
					# reach of its own push.
					var host := body.global_position - Vector3(
							float(parts[2]), -0.6, float(parts[3])) * 2.0
					# A REFUSED PUSH IS NOT AN ERROR HERE. A solution
					# that asks the envelope to move a body it cannot is
					# a solution that latches nothing, and "latched
					# nothing in all three runs" is precisely the verdict
					# check 20 exists to reach. Refusing the RUN would
					# turn an unsolvable puzzle into an unreplayable one.
					Manipulation.push(body, host, toward, envelope)
					await tree.physics_frame
					_observe(package, stage, latched)
			"wait":
				if parts.size() < 2:
					return "malformed step '%s'" % step
				for _i in _frames(float(parts[1]), package):
					await tree.physics_frame
					_observe(package, stage, latched)
			"settle":
				# BOUNDED BY THE PACKAGE'S OWN TIMEOUT. A `settle` that
				# waited forever would turn a body that never rests into
				# a hung run rather than a failed one.
				var budget := _frames(settle_budget, package)
				for _i in budget:
					await tree.physics_frame
					_observe(package, stage, latched)
					if _all_at_rest(stage):
						break
			_:
				return ("step '%s' is not a step this engine knows"
						% str(parts[0]))
	return latched.keys()

## Every latch condition, this frame. Once true it stays true: a latch
## latches, and a crate that crossed the region and rolled back out still
## solved the puzzle.
static func _observe(package: PhysicsPackage, stage: Stage,
		latched: Dictionary) -> void:
	for latch: PhysicsPackage.LatchCondition in package.latch_conditions:
		if latched.has(latch.latch_id):
			continue
		if _holds(latch, stage):
			latched[latch.latch_id] = true

static func _holds(latch: PhysicsPackage.LatchCondition,
		stage: Stage) -> bool:
	var parts := latch.detail.split(" ", false)
	match latch.kind:
		"POSITION_REGION":
			# `<body_id> in <region_id>`
			if parts.size() != 3 or parts[1] != "in":
				return false
			var body: ManipulableBody = stage.bodies.get(parts[0])
			var region: Variant = stage.regions.get(parts[2])
			if body == null or typeof(region) != TYPE_AABB:
				return false
			return (region as AABB).has_point(body.global_position)
		"WEIGHT_THRESHOLD":
			# `<plate_id> >= <kg>`
			if parts.size() != 3 or parts[1] != ">=":
				return false
			var plate: Variant = stage.plates.get(parts[0])
			if typeof(plate) != TYPE_AABB:
				return false
			var carried := 0.0
			for id: String in stage.bodies:
				var body: ManipulableBody = stage.bodies[id]
				if (plate as AABB).has_point(body.global_position):
					carried += body.mass
			return carried >= float(parts[2])
	return false

static func _all_at_rest(stage: Stage) -> bool:
	for id: String in stage.bodies:
		if not (stage.bodies[id] as ManipulableBody).at_rest():
			return false
	return true

## Seconds to physics frames, at the package's OWN fixed step. A replay
## that used the project's tick rate would be a different experiment from
## the one the evidence claims.
static func _frames(seconds: float, package: PhysicsPackage) -> int:
	return maxi(1, int(round(seconds * package.setup.solver.fixed_step_hz)))
