extends Node

## THE PHYSICS SUBSTRATE, measured.
##
## `docs/AMALGAM_BRIDGE.md` §6.3: a rigid body that rests and can be
## pushed, then one verb resolving to force, range and mass. This is
## those two, and the determinism property the replay harness will need
## on the day it exists.
##
## Deliberately its own target. It is the only suite that steps physics
## for hundreds of frames with nothing else in the scene, and folding it
## into `godot-content` would make a fast contract suite slow for
## everybody.

var failures := 0
var checks := 0

## The room every case is built in: a floor wide enough that nothing
## falls off it while being pushed.
const FLOOR := Vector3(60.0, 1.0, 60.0)

## How long a push is held, in physics frames. Two seconds at 60 Hz.
const PUSH_FRAMES := 120

## How long the body is then left alone to come to rest.
const SETTLE_FRAMES := 300

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  ok: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
	print("FAIL: %s" % message)

func _ready() -> void:
	_run()

func _run() -> void:
	await _a_body_falls_and_comes_to_rest()
	await _a_host_at_the_envelope_moves_a_body_at_the_limit()
	await _a_body_over_the_mass_limit_is_refused_and_does_not_move()
	await _a_body_out_of_reach_is_refused()
	await _a_bolted_body_is_refused_and_does_not_move()
	await _the_same_push_twice_ends_in_the_same_place()
	await _a_solvable_package_latches_in_every_run()
	await _a_solution_that_misses_latches_in_none()
	await _a_weight_threshold_needs_the_weight()
	await _a_latch_this_engine_cannot_observe_is_refused()
	_the_envelope_friction_keeps_the_contract_s_promise()
	_the_verb_set_decides_the_capability()
	_the_envelope_says_which_minimum_a_host_misses()
	if failures == 0:
		print("GODOT PHYSICS TESTS OK (%d checks)" % checks)
		get_tree().quit(0)
	else:
		print("GODOT PHYSICS TESTS: %d failures" % failures)
		get_tree().quit(1)

# --- the substrate -------------------------------------------------------

## IT RESTS. A body that never sleeps has no resting place, and
## `scene_digest` reads `sleeping` precisely because a setup still
## settling is a setup nobody can reproduce.
func _a_body_falls_and_comes_to_rest() -> void:
	var room := _room()
	var body := ManipulableBody.create("crate_a", 80.0,
			Vector3(1.0, 1.0, 1.0))
	room.add_child(body)
	body.global_position = Vector3(0.0, 3.0, 0.0)
	await _step(SETTLE_FRAMES)
	_check(body.at_rest(),
			"a dropped body came to rest within %d frames (it is at %s, "
			% [SETTLE_FRAMES, str(body.global_position.snapped(
				Vector3.ONE * 0.001))] + "moving at %.4f m/s)"
			% body.linear_velocity.length())
	# ON the floor, not through it. A body at rest six metres down has
	# also stopped moving.
	_check(absf(body.global_position.y - 0.5) < 0.05,
			"it rests on the floor at y %.3f, and the floor's top is 0.0"
			% body.global_position.y)
	room.queue_free()
	await get_tree().process_frame

## AND IT CAN BE PUSHED, by a host authored at exactly the minimum, over
## a body at exactly the mass the envelope promises.
func _a_host_at_the_envelope_moves_a_body_at_the_limit() -> void:
	var room := _room()
	var body := ManipulableBody.create("crate_a",
			Constants.ENVELOPE_MASS_KG, Vector3(1.2, 1.2, 1.2))
	room.add_child(body)
	body.global_position = Vector3(0.0, 0.61, 0.0)
	await _step(60)
	var was := body.global_position
	var envelope := Manipulation.Envelope.at_the_envelope()
	_check(envelope.qualifies(),
			"a host built at the envelope qualifies as a provider")
	var moved := await _push(body, envelope,
			Vector3(0.0, 1.0, -3.0), Vector3(0.0, 0.0, 30.0))
	_check(str(moved["refused"]) == "",
			"the push resolved rather than refusing: '%s'"
			% str(moved["refused"]))
	var travelled := was.distance_to(body.global_position)
	_check(travelled > 1.0,
			"%.0f N moved %.0f kg by %.2f m, which is the envelope doing "
			% [envelope.force_n, body.mass, travelled]
			+ "what it promises")
	_check(body.at_rest(),
			"and the body came back to rest afterwards")
	room.queue_free()
	await get_tree().process_frame

## AND A BODY OVER THE HOST'S LIMIT IS REFUSED BY NAME, not merely
## unmoved. "Nothing happened" is the same report as a bug.
func _a_body_over_the_mass_limit_is_refused_and_does_not_move() -> void:
	var room := _room()
	var body := ManipulableBody.create("anvil",
			Constants.ENVELOPE_MASS_KG * 4.0, Vector3(1.2, 1.2, 1.2))
	room.add_child(body)
	body.global_position = Vector3(0.0, 0.61, 0.0)
	await _step(60)
	var was := body.global_position
	var weak := Manipulation.Envelope.of(Constants.ENVELOPE_FORCE_N,
			Constants.ENVELOPE_RANGE_M, Constants.ENVELOPE_MASS_KG)
	var moved := await _push(body, weak,
			Vector3(0.0, 1.0, -3.0), Vector3(0.0, 0.0, 30.0))
	_check(str(moved["refused"]) == Manipulation.TOO_HEAVY,
			"a %.0f kg body under a %.0f kg limit is refused as '%s'"
			% [body.mass, weak.mass_limit_kg, str(moved["refused"])])
	_check(was.distance_to(body.global_position) < 0.05,
			"and it did not move (%.3f m)"
			% was.distance_to(body.global_position))
	room.queue_free()
	await get_tree().process_frame

func _a_body_out_of_reach_is_refused() -> void:
	var room := _room()
	var body := ManipulableBody.create("crate_a", 80.0,
			Vector3(1.0, 1.0, 1.0))
	room.add_child(body)
	body.global_position = Vector3(0.0, 0.51, 0.0)
	await _step(60)
	var envelope := Manipulation.Envelope.at_the_envelope()
	var far := Vector3(0.0, 1.0, -(Constants.ENVELOPE_RANGE_M + 1.0))
	var refused := Manipulation.push(body, far, Vector3(0.0, 0.0, 30.0),
			envelope)
	_check(str(refused["refused"]) == Manipulation.OUT_OF_REACH,
			"a body %.1f m away under a %.1f m reach is refused as '%s'"
			% [far.distance_to(body.global_position), envelope.range_m,
				str(refused["refused"])])
	# AND THE BOUNDARY IS INCLUSIVE, which is where an off-by-one lives.
	# EXACTLY the reach, measured from where the body actually settled:
	# an edge point typed as (0, y, -20) is 20.000001 m from a body that
	# drifted a micron off the axis, and the boundary case then tests
	# float error rather than the rule.
	var edge := body.global_position \
			+ Vector3.FORWARD * Constants.ENVELOPE_RANGE_M
	_check(str(Manipulation.push(body, edge, Vector3(0.0, 0.0, 30.0),
				envelope)["refused"]) == "",
			"a body at exactly %.1f m is within reach"
			% Constants.ENVELOPE_RANGE_M)
	# AND PUSHING A BODY AT ITSELF IS ITS OWN REFUSAL, not a range one.
	_check(str(Manipulation.push(body, Vector3(0.0, 1.0, -2.0),
				body.global_position, envelope)["refused"])
				== Manipulation.NO_DIRECTION,
			"pushing a body toward where it already is refuses as "
			+ "'%s'" % Manipulation.NO_DIRECTION)
	room.queue_free()
	await get_tree().process_frame

## BOLTED IS NOT HEAVY. The contract's `constrained` is a different fact
## from a mass limit and has to read differently in the evidence.
func _a_bolted_body_is_refused_and_does_not_move() -> void:
	var room := _room()
	var body := ManipulableBody.create("pillar", 40.0,
			Vector3(1.0, 2.0, 1.0), true)
	room.add_child(body)
	body.global_position = Vector3(0.0, 1.01, 0.0)
	await _step(60)
	var was := body.global_position
	var moved := await _push(body, Manipulation.Envelope.at_the_envelope(),
			Vector3(0.0, 1.0, -3.0), Vector3(0.0, 0.0, 30.0))
	_check(str(moved["refused"]) == Manipulation.CONSTRAINED,
			"a bolted body is refused as '%s', not as too heavy"
			% str(moved["refused"]))
	_check(was.distance_to(body.global_position) < 0.001,
			"and it did not move at all (%.4f m)"
			% was.distance_to(body.global_position))
	_check(body.at_rest(), "a bolted body reads as at rest")
	room.queue_free()
	await get_tree().process_frame

## THE PROPERTY THE REPLAY HARNESS IS MADE OF.
##
## §23.5 check 20 replays at FIXED solver settings, three times, and
## reports which latches fired per run. That is only meaningful if the
## same setup pushed the same way lands in the same place -- a harness
## over a non-deterministic substrate reports three different answers and
## calls the puzzle flaky.
##
## Compared at `SceneDigest.QUANTUM`, because that is the resolution the
## rest of this contract already reasons at.
func _the_same_push_twice_ends_in_the_same_place() -> void:
	var first := await _one_run()
	var second := await _one_run()
	var apart := first.distance_to(second)
	_check(apart <= SceneDigest.QUANTUM,
			"the same push twice ended %.6f m apart, and the digest's "
			% apart + "quantum is %.4f m; a replay harness over this "
			% SceneDigest.QUANTUM + "would call a solved puzzle flaky"
			+ " (%s vs %s)" % [str(first), str(second)])

func _one_run() -> Vector3:
	var room := _room()
	var body := ManipulableBody.create("crate_a", 100.0,
			Vector3(1.0, 1.0, 1.0))
	room.add_child(body)
	body.global_position = Vector3(0.0, 0.51, 0.0)
	await _step(60)
	await _push(body, Manipulation.Envelope.at_the_envelope(),
			Vector3(0.0, 1.0, -3.0), Vector3(0.0, 0.0, 30.0))
	var at := body.global_position
	room.queue_free()
	await get_tree().process_frame
	return at

# --- the verb half, which needs no physics -------------------------------

func _the_verb_set_decides_the_capability() -> void:
	_check(Manipulation.grants_manipulate(["PUSH"]),
			"a PUSH grants manipulate")
	_check(Manipulation.grants_manipulate(["dash", "hold"]),
			"a HOLD grants it, whatever case it is written in")
	_check(not Manipulation.grants_manipulate(
				["DASH", "VAULT", "GRAPPLE", "SLIDE"]),
			"and the other verbs never do, however many there are")
	_check(not Manipulation.grants_manipulate([]),
			"a host with no verbs grants nothing")

func _the_envelope_says_which_minimum_a_host_misses() -> void:
	var weak := Manipulation.Envelope.of(
			Constants.ENVELOPE_FORCE_N - 1.0,
			Constants.ENVELOPE_RANGE_M,
			Constants.ENVELOPE_MASS_KG - 1.0)
	_check(not weak.qualifies(),
			"a host one newton short does not qualify")
	var missing := weak.shortfall()
	_check(missing.size() == 2,
			"it is told both minima it misses, and it was told %d: %s"
			% [missing.size(), str(missing)])
	_check(Manipulation.Envelope.at_the_envelope().shortfall().is_empty(),
			"a host at exactly the envelope misses nothing")

# --- harness -------------------------------------------------------------

## A floor and nothing else. Built here rather than taken from a Zone,
## because this measures the SUBSTRATE: a failure in a real room would
## be ambiguous between the body and the room.
func _room() -> Node3D:
	var root := Node3D.new()
	root.name = "physics_room"
	var floor_body := StaticBody3D.new()
	floor_body.name = "floor"
	floor_body.position = Vector3(0.0, -FLOOR.y / 2.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = FLOOR
	shape.shape = box
	floor_body.add_child(shape)
	root.add_child(floor_body)
	add_child(root)
	return root

## Holds the push for `PUSH_FRAMES`, then waits for rest. Returns the
## FIRST frame's resolution, which is the one that says whether the verb
## resolved at all.
func _push(body: ManipulableBody, envelope: Manipulation.Envelope,
		from: Vector3, toward: Vector3) -> Dictionary:
	var first := {}
	for i in PUSH_FRAMES:
		var step := Manipulation.push(body, from, toward, envelope)
		if i == 0:
			first = step
		if str(step["refused"]) != "":
			break
		await get_tree().physics_frame
	await _step(SETTLE_FRAMES)
	return first

func _step(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame

## THE SUBSTRATE KEEPS THE CONTRACT'S PROMISE, arithmetically.
##
## The measurement above says a push at the envelope moves a body at the
## limit; this says WHY, so a future change to either number is caught
## before somebody wonders why a mandatory route stopped being solvable.
## Godot's default friction of 1.0 fails this by a factor of 1.7.
func _the_envelope_friction_keeps_the_contract_s_promise() -> void:
	var resist := ManipulableBody.envelope_friction() \
			* Constants.ENVELOPE_MASS_KG * ManipulableBody.gravity()
	_check(resist < Constants.ENVELOPE_FORCE_N,
			"a body at the mass limit resists with %.0f N and the "
			% resist + "envelope pushes with %.0f N, so §29.3.2's "
			% Constants.ENVELOPE_FORCE_N + "promise is one the "
			+ "substrate keeps")
	# AND WITH ROOM TO SPARE, because "moves at 0.01 m/s" is a promise
	# kept in name only.
	_check(Constants.ENVELOPE_FORCE_N - resist
				>= Constants.ENVELOPE_FORCE_N * 0.25,
			"and kept with room to spare: %.0f N of %.0f is left over, "
			% [Constants.ENVELOPE_FORCE_N - resist,
				Constants.ENVELOPE_FORCE_N]
			+ "so the body accelerates rather than creeping")
	# AND GODOT'S DEFAULT WOULD NOT. The falsification: this is the
	# number the substrate has if nobody sets one.
	_check(1.0 * Constants.ENVELOPE_MASS_KG * ManipulableBody.gravity()
				> Constants.ENVELOPE_FORCE_N,
			"and the project default of 1.0 would NOT have kept it "
			+ "(%.0f N of resistance), which is what makes deriving one "
			% (Constants.ENVELOPE_MASS_KG * ManipulableBody.gravity())
			+ "here worth doing")

# --- the replay harness --------------------------------------------------

## THE DELIVERABLE THE BRIDGE HAS BEEN WAITING ON.
##
## `ReplayEvidence` was written, validated and impossible to produce:
## §23.5 check 20 replays three times at fixed solver settings against a
## provider at exactly the envelope, and there was no engine that could
## replay anything. This is a package being solved, three times, by a
## host built at the minimum.
func _a_solvable_package_latches_in_every_run() -> void:
	var package := _crate_to_region_package()
	var evidence := await ReplayHarness.replay(get_tree(), package,
			func() -> ReplayHarness.Stage: return _crate_stage())
	_check(not evidence.has("refused"),
			"a package this engine can replay was replayed: %s"
			% str(evidence.get("refused", "")))
	if evidence.has("refused"):
		return
	var runs: Array = evidence["per_run_latched"]
	_check(runs.size() == ReplayHarness.RUNS,
			"%d runs, and check 20 replays %d"
			% [runs.size(), ReplayHarness.RUNS])
	var every := true
	for run: Variant in runs:
		if not "crate_home" in (run as Array):
			every = false
	_check(every,
			"the required latch fired in every run, and the runs were %s"
			% str(runs))
	# AT EXACTLY THE ENVELOPE. Replaying above it proves a strong
	# provider can solve the puzzle, which is not the claim.
	_check(float(evidence["provider_force_n"])
				== Constants.ENVELOPE_FORCE_N
				and float(evidence["provider_range_m"])
					== Constants.ENVELOPE_RANGE_M
				and float(evidence["provider_mass_kg"])
					== Constants.ENVELOPE_MASS_KG,
			"the provider is at exactly the envelope (%.0f N / %.1f m / "
			% [evidence["provider_force_n"], evidence["provider_range_m"]]
			+ "%.0f kg)" % evidence["provider_mass_kg"])
	# AND BOUND TO WHAT IT REPLAYED. Evidence that does not carry the
	# package's own digest is evidence somebody can move to another
	# package.
	var errors: Array[String] = []
	var built := PhysicsPackage.from_dict(package, errors)
	_check(str(evidence["content_digest"]) == built.digest(),
			"the evidence carries the package's own digest %s, and it "
			% built.digest() + "carries %s" % str(evidence["content_digest"]))

## THE FALSIFICATION. Same harness, same stage, a solution that pushes
## the crate the wrong way: the harness reports what happened rather than
## what was hoped, and three empty runs is the answer.
func _a_solution_that_misses_latches_in_none() -> void:
	var package := _crate_to_region_package()
	(package["reference_solution"] as Dictionary)["steps"] = [
		"push crate_a 0 -1 2.0", "settle"]
	var evidence := await ReplayHarness.replay(get_tree(), package,
			func() -> ReplayHarness.Stage: return _crate_stage())
	_check(not evidence.has("refused"),
			"a solution that misses is still replayable")
	if evidence.has("refused"):
		return
	var any := false
	for run: Variant in evidence["per_run_latched"] as Array:
		if not (run as Array).is_empty():
			any = true
	_check(not any,
			"pushing the crate away from the region latched nothing, "
			+ "and the runs were %s" % str(evidence["per_run_latched"]))

## `WEIGHT_THRESHOLD`, which is the other kind this engine observes, and
## the one that needs more than one body to mean anything.
##
## A heavier SINGLE crate would not do: a host at the envelope refuses a
## body over 120 kg, so "one 180 kg crate" tests the mass limit and not
## the threshold. Two crates is the shape the condition is for.
func _a_weight_threshold_needs_the_weight() -> void:
	var package := _crate_to_region_package()
	(package["latch_conditions"] as Array)[0] = {
		"latch_id": "plate_down", "kind": "WEIGHT_THRESHOLD",
		"detail": "goal_plate >= 150.0"}
	(package["required_latches"] as Array)[0] = "plate_down"
	var light := await ReplayHarness.replay(get_tree(), package,
			func() -> ReplayHarness.Stage: return _crate_stage())
	_check(not light.has("refused") and (light["per_run_latched"]
				as Array)[0].is_empty(),
			"one 100 kg crate does not hold a 150 kg plate down: %s"
			% str(light.get("per_run_latched", light.get("refused"))))
	var both: Dictionary = package.duplicate(true)
	((both["setup"] as Dictionary)["bodies"] as Array).append(
			{"body_id": "crate_b", "mass_kg": 100.0,
				"constrained": false})
	(both["reference_solution"] as Dictionary)["steps"] = [
		"push crate_a 0 1 2.0", "push crate_b 0 1 2.0", "settle"]
	var heavy := await ReplayHarness.replay(get_tree(), both,
			func() -> ReplayHarness.Stage: return _crate_stage(true))
	_check(not heavy.has("refused") and not (heavy["per_run_latched"]
				as Array)[0].is_empty(),
			"a second crate beside it does: %s"
			% str(heavy.get("per_run_latched", heavy.get("refused"))))

## REFUSED IS NOT UNLATCHED. A latch kind with no runtime reported as
## "did not latch" is a harness saying the puzzle is unsolvable.
func _a_latch_this_engine_cannot_observe_is_refused() -> void:
	var package := _crate_to_region_package()
	(package["latch_conditions"] as Array)[0] = {
		"latch_id": "hinge_down", "kind": "CONSTRAINT_STATE",
		"detail": "hinge at rest below 5 degrees"}
	(package["required_latches"] as Array)[0] = "hinge_down"
	var evidence := await ReplayHarness.replay(get_tree(), package,
			func() -> ReplayHarness.Stage: return _crate_stage())
	_check(evidence.has("refused")
				and "CONSTRAINT_STATE" in str(evidence["refused"]),
			"a CONSTRAINT_STATE latch is refused by name: '%s'"
			% str(evidence.get("refused", "it was not refused at all")))
	# AND SO IS A STEP NOBODY WROTE A RUNTIME FOR.
	var unknown := _crate_to_region_package()
	(unknown["reference_solution"] as Dictionary)["steps"] = ["levitate"]
	var second := await ReplayHarness.replay(get_tree(), unknown,
			func() -> ReplayHarness.Stage: return _crate_stage())
	_check(second.has("refused") and "levitate" in str(second["refused"]),
			"an unknown step is refused by name: '%s'"
			% str(second.get("refused", "it was not refused at all")))

## One crate, one region three metres along +Z, one plate over it.
func _crate_stage(second := false) -> ReplayHarness.Stage:
	var stage := ReplayHarness.Stage.new()
	stage.root = _room()
	var crate := ManipulableBody.create("crate_a", 100.0,
			Vector3(1.0, 1.0, 1.0))
	stage.root.add_child(crate)
	crate.global_position = Vector3(0.0, 0.51, 0.0)
	stage.bodies["crate_a"] = crate
	if second:
		var other := ManipulableBody.create("crate_b", 100.0,
				Vector3(1.0, 1.0, 1.0))
		stage.root.add_child(other)
		other.global_position = Vector3(1.6, 0.51, 0.0)
		stage.bodies["crate_b"] = other
	# Deliberately short of where an unpushed crate sits, and well
	# inside where a pushed one stops.
	stage.regions["goal"] = AABB(Vector3(-2.0, -1.0, 1.5),
			Vector3(4.0, 4.0, 6.0))
	stage.plates["goal_plate"] = stage.regions["goal"]
	return stage

func _crate_to_region_package() -> Dictionary:
	return {
		"package_id": "crate_home",
		"latch_conditions": [{"latch_id": "crate_home",
				"kind": "POSITION_REGION", "detail": "crate_a in goal"}],
		"vector_latches": [0],
		"required_latches": ["crate_home"],
		"on_mandatory_route": true,
		"setup": {
			"bodies": [{"body_id": "crate_a", "mass_kg": 100.0,
					"constrained": false}],
			"solver": {"iterations": 8, "fixed_step_hz": 60.0,
					"settle_timeout_s": 8.0},
			"scene_digest": "0123456789abcdef",
		},
		"reference_solution": {"steps": ["push crate_a 0 1 2.0",
				"settle"]},
	}
