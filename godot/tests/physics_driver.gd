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
	await _the_player_shoves_a_crate_with_their_own_body()
	await _a_player_opens_a_powered_door_by_shoving_a_crate()
	await _a_player_walks_up_a_step_and_back_down_it()
	await _a_player_walks_down_a_staircase_without_falling()
	await _a_real_ledge_is_still_a_fall()
	await _a_jump_from_a_tread_still_rises()
	await _a_slope_is_walked_down_without_the_step_rule()
	await _a_step_refuses_cover_and_a_low_ceiling()
	await _a_solvable_package_latches_in_every_run()
	await _a_solution_that_misses_latches_in_none()
	await _a_weight_threshold_needs_the_weight()
	await _a_latch_this_engine_cannot_observe_is_refused()
	_the_envelope_friction_keeps_the_contract_s_promise()
	_the_controller_digest_covers_the_code_and_not_only_the_numbers()
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

# --- the base character, shoving --------------------------------------

## Far enough from the origin that geometry other controls leave in the
## scene cannot stand in the way of a walk this file is timing, and with
## its own ground, because `_room()`'s floor does not reach out here.
const FAR := 500.0

func _ground_at(room: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	slab.add_child(shape)
	room.add_child(slab)
	slab.global_position = at
	return slab

## THE STEP THE MOVEMENT LAW PROMISED, WALKED IN BOTH DIRECTIONS.
##
## `MAX_VERTICAL_STEP` decided geometry was walkable while `player.gd`
## implemented no step-up at all, so the real height was zero and the
## owner had to jump the pedestal in a treasure room.
##
## 0.8 m is not arbitrary. `treasure_room` stacks two 0.4 m steps, so
## its upper tread sits at exactly this height -- and it is above
## `PLAYER_RADIUS`, which matters: a 0.4 m rise is inside the capsule's
## own rounded bottom and can be mounted without any step-up at all, so
## a control built on one would pass whether or not the feature exists.
func _a_player_walks_up_a_step_and_back_down_it() -> void:
	var room := _room()
	_ground_at(room, Vector3(FAR, -0.5, 4.0), Vector3(24.0, 1.0, 40.0))
	var ledge := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.8, 8.0)
	shape.shape = box
	ledge.add_child(shape)
	room.add_child(ledge)
	# CLEAR OF THE OTHER CONTROLS. `_room()` adds a fresh root but earlier
	# rooms in this file are still in the scene, and the first version of
	# this control was blocked by a `PoweredDoor` left at the origin by
	# the control above it.
	ledge.global_position = Vector3(FAR, 0.4, 4.5)
	await _step(30)
	var body := Player.create()
	room.add_child(body)
	body.global_position = Vector3(FAR, 1.2, -1.0)
	await _step(25)
	body.rotation.y = PI
	Input.action_press("move_forward", 1.0)
	for _i in 25:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _step(15)
	var climbed := body.global_position.y
	_check(climbed > 0.7,
			"a walking player climbs a 0.8 m step without jumping "
			+ "(ended at y %.2f, on a tread the capsule's own radius "
			% climbed + "cannot mount)")
	_check(body.global_position.z > 0.5,
			"and is standing on it rather than stopped at its face "
			+ "(z %.2f)" % body.global_position.z)
	# BACK DOWN, and off it again.
	body.rotation.y = 0.0
	Input.action_press("move_forward", 1.0)
	for _i in 40:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _step(15)
	_check(body.global_position.y < 0.7,
			"and walks back down off it (y %.2f)"
			% body.global_position.y)
	room.queue_free()
	await get_tree().process_frame

## AND DOWN A STAIRCASE WITHOUT IT BECOMING A SERIES OF DROPS.
##
## The descent half of the same defect, and the geometry is the one the
## owner met: `treasure_room` stacks two 0.4 m treads under its Check.
## Godot's default `floor_snap_length` is 0.1 m, so each tread threw the
## body off the floor and a staircase walked like a set of small falls.
## A single tall ledge is NOT this case -- walking off one is a fall and
## should be -- so this is measured on treads.
func _a_player_walks_down_a_staircase_without_falling() -> void:
	var room := _room()
	_ground_at(room, Vector3(FAR, -0.5, 4.0), Vector3(24.0, 1.0, 40.0))
	_ground_at(room, Vector3(FAR, 0.2, 6.0), Vector3(10.0, 0.4, 10.0))
	_ground_at(room, Vector3(FAR, 0.6, 9.0), Vector3(10.0, 0.4, 6.0))
	await _step(30)
	var body := Player.create()
	room.add_child(body)
	body.global_position = Vector3(FAR, 1.2, 9.0)
	await _step(25)
	_check(body.global_position.y > 0.7,
			"the walker starts on the top tread (y %.2f)"
			% body.global_position.y)
	var falling := 0
	Input.action_press("move_forward", 1.0)
	for _i in 40:
		await get_tree().physics_frame
		if not body.is_on_floor():
			falling += 1
	Input.action_release("move_forward")
	await _step(15)
	_check(body.global_position.y < 0.7,
			"and descends the treads (y %.2f)" % body.global_position.y)
	# NOW ASSERTED. This was a reported count for a batch, because
	# `floor_snap_length` at 1.0 did not keep the body down and the
	# reason was not known. It is known now -- the snap cast hits the
	# lip of the tread being left, 0.109 m down, and rejects its own
	# staircase as a wall -- and `Player._follow_the_step_down` walks
	# the drop instead. Two treads at 0.4 m each cost the body a handful
	# of frames riding each edge, against 20 of the 40 spent falling
	# before the repair.
	_check(falling <= 6,
			"and stays with the treads while it does: %d airborne "
			% falling + "frames of 40, where a free fall down two "
			+ "0.4 m treads spends 20")
	room.queue_free()
	await get_tree().process_frame

## AND A REAL LEDGE IS STILL A FALL.
##
## The boundary of the descent rule, from the other side. The step law
## is `MAX_VERTICAL_STEP` in BOTH directions, so a drop deeper than one
## step is not a stair and nothing may follow the body down it. Without
## this control the descent repair has no evidence it is a step rather
## than adhesion, and "the player never falls again" would pass every
## test in this file.
func _a_real_ledge_is_still_a_fall() -> void:
	var room := _room()
	_ground_at(room, Vector3(FAR, -0.5, 4.0), Vector3(24.0, 1.0, 40.0))
	# 2.5 m, comfortably past the 1.0 m step and past the 1.33 m jump.
	_ground_at(room, Vector3(FAR, 1.25, 9.0), Vector3(10.0, 2.5, 8.0))
	await _step(30)
	var body := Player.create()
	room.add_child(body)
	# TWO METRES BACK FROM THE LIP, not four. The first version of this
	# started at z 9.0 and reported two airborne frames -- not because
	# the body was caught, but because 4 m at 7 m/s used 34 of the 40
	# frames getting to the edge. A 2.5 m fall takes 0.46 s; the window
	# has to contain it or the control measures the walk.
	body.global_position = Vector3(FAR, 2.9, 7.0)
	await _step(25)
	_check(body.global_position.y > 2.4,
			"the walker starts on the ledge (y %.2f)"
			% body.global_position.y)
	var falling := 0
	var fastest := 0.0
	Input.action_press("move_forward", 1.0)
	for _i in 45:
		await get_tree().physics_frame
		if not body.is_on_floor():
			falling += 1
			fastest = maxf(fastest, -body.velocity.y)
	Input.action_release("move_forward")
	await _step(20)
	_check(falling >= 10,
			"and walking off a 2.5 m ledge is a FALL, not a step down "
			+ "(%d airborne frames of 45)" % falling)
	_check(fastest > 4.0,
			"with real speed in it (%.1f m/s), so the descent rule "
			% fastest + "did not quietly become adhesion")
	_check(body.global_position.y < 0.5,
			"and it ends on the floor below (y %.2f)"
			% body.global_position.y)
	room.queue_free()
	await get_tree().process_frame

## AND A JUMP FROM THE EDGE OF A TREAD STILL RISES.
##
## The descent rule runs every frame a walking body is on the floor. If
## it read a rising body as one walking off a step it would pull the
## jump back down, and the player would lose the jump nearest every
## staircase in the game -- which is exactly where they need it.
func _a_jump_from_a_tread_still_rises() -> void:
	var room := _room()
	_ground_at(room, Vector3(FAR, -0.5, 4.0), Vector3(24.0, 1.0, 40.0))
	_ground_at(room, Vector3(FAR, 0.2, 8.0), Vector3(10.0, 0.4, 6.0))
	await _step(30)
	var body := Player.create()
	room.add_child(body)
	# Just behind the lip at z = 5.0, walking off it.
	body.global_position = Vector3(FAR, 0.8, 5.6)
	await _step(25)
	var highest := body.global_position.y
	Input.action_press("move_forward", 1.0)
	await _step(4)
	Input.action_press("jump", 1.0)
	await get_tree().physics_frame
	Input.action_release("jump")
	for _i in 25:
		await get_tree().physics_frame
		highest = maxf(highest, body.global_position.y)
	Input.action_release("move_forward")
	await _step(25)
	# Apex is JUMP_VELOCITY^2 / 2*GRAVITY = 1.33 m. Anything over a
	# metre proves the arc was not stolen.
	_check(highest > 1.4,
			"a jump taken at the lip of a tread still rises (peak y "
			+ "%.2f, from 0.40)" % highest)
	room.queue_free()
	await get_tree().process_frame

## AND A SLOPE IS WALKED, NOT STEPPED.
##
## The third comparison the descent rule owes: a ramp's ground is
## continuous, so the body never leaves it and the new code never runs.
## Measured rather than assumed, because a descent rule that fired on
## every downhill frame would be a very quiet way to change how every
## ramp in the game feels.
func _a_slope_is_walked_down_without_the_step_rule() -> void:
	var room := _room()
	_ground_at(room, Vector3(FAR, -0.5, -6.0), Vector3(24.0, 1.0, 20.0))
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.5, 14.0)
	shape.shape = box
	ramp.add_child(shape)
	room.add_child(ramp)
	ramp.global_position = Vector3(FAR, 1.0, 6.0)
	ramp.rotation.x = deg_to_rad(-20.0)
	await _step(30)
	var body := Player.create()
	room.add_child(body)
	body.global_position = Vector3(FAR, 3.6, 9.0)
	await _step(40)
	var started := body.global_position.y
	_check(started > 1.5,
			"the walker starts up the ramp (y %.2f)" % started)
	var falling := 0
	Input.action_press("move_forward", 1.0)
	for _i in 45:
		await get_tree().physics_frame
		if not body.is_on_floor():
			falling += 1
	Input.action_release("move_forward")
	await _step(15)
	_check(body.global_position.y < started - 0.8,
			"and walks down it (y %.2f from %.2f)"
			% [body.global_position.y, started])
	_check(falling <= 3,
			"with its feet on it the whole way (%d airborne frames "
			% falling + "of 45)")
	room.queue_free()
	await get_tree().process_frame

## AND THE THINGS THAT MUST STAY OBSTACLES.
##
## A step-up that climbs anything deletes cover. `DestructibleCover` is
## 1.4 m and `ReactiveBarrel` 1.1 m, both above `MAX_VERTICAL_STEP` on
## purpose, and the crate control above covers the other half: a body
## the player is meant to SHOVE is not a stair either.
func _a_step_refuses_cover_and_a_low_ceiling() -> void:
	var room := _room()
	_ground_at(room, Vector3(FAR, -0.5, 4.0), Vector3(24.0, 1.0, 40.0))
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(8.0, 1.4, 8.0)
	ws.shape = wb
	wall.add_child(ws)
	room.add_child(wall)
	wall.global_position = Vector3(FAR, 0.7, 4.5)
	await _step(30)
	var body := Player.create()
	room.add_child(body)
	body.global_position = Vector3(FAR, 1.2, -1.0)
	await _step(25)
	body.rotation.y = PI
	Input.action_press("move_forward", 1.0)
	for _i in 40:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _step(15)
	_check(body.global_position.y < 0.6,
			"a 1.4 m cover slab is not climbed by the step (y %.2f); "
			% body.global_position.y + "cover that can be walked over "
			+ "is not cover")
	room.queue_free()
	await get_tree().process_frame

## CAN THE CURRENTLY PLAYABLE CHARACTER MOVE A CRATE?
##
## Everything else in this file applies force through `Manipulation`,
## which is the qualification question -- does a HOST meet §29.3.2's
## envelope. That says nothing about whether a player with no Echo at
## all can move anything, and the environmental-agency chain rests
## entirely on their being able to: a crate only the harness can shove
## is a crate no player can use.
##
## `CharacterBody3D` does not push a `RigidBody3D` on its own.
## `move_and_slide` resolves the contact by sliding the character, so
## `Player._shove_what_i_walked_into` is what makes this true, and this
## is where it is measured -- on a flat floor, with nothing else in the
## room, so a failure is about the shove and not about a Zone.
func _the_player_shoves_a_crate_with_their_own_body() -> void:
	var room := _room()
	var crate := ManipulableBody.create("crate_a", 60.0,
			Vector3(0.7, 0.7, 0.7))
	room.add_child(crate)
	crate.global_position = Vector3(0.0, 0.4, 0.0)
	await _step(60)
	var was := crate.global_position
	var body := Player.create()
	room.add_child(body)
	body.global_position = Vector3(0.0, 0.9, -2.0)
	await _step(10)
	# Facing +Z, which is how `move_forward` is spent: the player walks
	# along -Z of its own basis.
	body.rotation.y = PI
	Input.action_press("move_forward", 1.0)
	for _i in 180:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _step(60)
	var moved := Vector2(crate.global_position.x - was.x,
			crate.global_position.z - was.z).length()
	_check(moved >= 1.0,
			"a player walking into a 60 kg crate for three seconds moved "
			+ "it %.2f m (from %s to %s); the chain rests on this and "
			% [moved, str(was.snapped(Vector3.ONE * 0.01)),
				str(crate.global_position.snapped(Vector3.ONE * 0.01))]
			+ "nothing else in the build can do it")
	# AND IT WENT THE WAY THEY WERE WALKING, not sideways off a corner.
	_check(crate.global_position.z - was.z >= moved * 0.8,
			"and it went forward rather than skidding aside (%.2f m of "
			% (crate.global_position.z - was.z) + "%.2f m)" % moved)
	# AND A HEAVY ONE RESISTS, which is what makes the light one a
	# statement about mass rather than about the code always working.
	var anvil := ManipulableBody.create("anvil", 900.0,
			Vector3(0.7, 0.7, 0.7))
	room.add_child(anvil)
	anvil.global_position = Vector3(6.0, 0.4, 0.0)
	await _step(60)
	var anvil_was := anvil.global_position
	body.global_position = Vector3(6.0, 0.9, -2.0)
	body.velocity = Vector3.ZERO
	await _step(10)
	Input.action_press("move_forward", 1.0)
	for _i in 180:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _step(60)
	_check(anvil.global_position.distance_to(anvil_was) < 0.5,
			"a 900 kg one barely moves (%.2f m), so the shove is a "
			% anvil.global_position.distance_to(anvil_was)
			+ "momentum transfer and not a teleport")
	room.queue_free()
	await get_tree().process_frame

## THE WHOLE CHAIN, OPENED BY THE PLAYER.
##
## `06_THE_AMALGAM.md` §5.4a's requirement, performed rather than
## simulated: physical crate -> plate -> signal -> powered door. The only
## input is `move_forward`. Nothing here calls `apply_central_force`,
## `apply_central_impulse` or `Manipulation.push`; every newton comes
## from `Player._shove_what_i_walked_into`, which needs no verb, no
## capability and no Echo.
##
## On a flat floor with nothing else in the room, because that is what
## makes a failure a statement about the chain. Whether ORDINARY
## GENERATION emits one is `godot-room-contract`'s question and is
## measured there, on the Zone the fallback actually composes.
##
## Three properties: the door is shut and impassable; the player's own
## walking opens it; and removing the crate leaves the same walk with
## the door shut.
func _a_player_opens_a_powered_door_by_shoving_a_crate() -> void:
	var room := _room()
	var link := PoweredLink.create("concrete_facility",
			Vector3(0.0, 0.0, 4.0), 36.0)
	link.position = Vector3(0.0, 0.0, 0.0)
	room.add_child(link)
	var crate := ManipulableBody.create("crate_a", 60.0,
			Vector3(0.7, 0.7, 0.7))
	room.add_child(crate)
	crate.global_position = Vector3(0.0, 0.4, -3.0)
	await _step(60)

	_check(not link.powered, "the door starts unpowered")
	_check(not link.doorway_is_clear(_world_space()),
			"and a capsule does not fit through it")

	var body := await _walk_into_the_crate(room, link)
	_check(link.mass_on_plate() >= link.threshold_kg,
			"walking into the crate put %.0f kg on the plate, which asks "
			% link.mass_on_plate() + "for %.0f" % link.threshold_kg)
	_check(link.powered, "so the signal went high")
	_check(link.doorway_is_clear(_world_space()),
			"and the doorway a capsule could not fit through is open")
	body.queue_free()
	await get_tree().process_frame

	# SABOTAGE. Same room, same walk, no crate.
	crate.queue_free()
	await get_tree().process_frame
	await _step(16)
	_check(not link.powered and not link.doorway_is_clear(_world_space()),
			"with the crate removed the same walk leaves the door shut "
			+ "(%.0f kg on the plate), so the crate is the cause"
			% link.mass_on_plate())
	var again := await _walk_into_the_crate(room, link)
	_check(not link.powered,
			"and walking the same line changes nothing without it")
	again.queue_free()
	room.queue_free()
	await get_tree().process_frame

## A body that walks forward from where the crate starts, along the same
## line, and stops pushing when the door opens or after four seconds.
##
## **The INPUT is the control, not the duration.** Both walks start in
## the same place, face the same way and hold the same key; what differs
## is that one of them has a crate in front of it. A player stops
## shoving when the door opens, and a walk that carried on would push
## the crate straight off the far side of the plate — which the first
## version did, in 200 frames, and reported an empty plate.
func _walk_into_the_crate(room: Node3D, link: PoweredLink) -> Player:
	var body := Player.create()
	room.add_child(body)
	body.global_position = Vector3(0.0, 0.9, -4.4)
	await _step(10)
	body.rotation.y = PI
	Input.action_press("move_forward", 1.0)
	for _i in 240:
		await get_tree().physics_frame
		if link.mass_on_plate() >= link.threshold_kg:
			break
	Input.action_release("move_forward")
	await _step(40)
	return body

func _world_space() -> PhysicsDirectSpaceState3D:
	return get_viewport().world_3d.direct_space_state

## WHICH BUILD'S CONTROLLER, and the half a constants list would miss.
##
## `AP_CAPABILITY_LOGIC.md` §8b-ANSWERED promised the bridge a
## `controller_digest` and said what it covers. A promise is not a
## digest; this is where the claim is measured.
##
## **The source of the movement scripts is the half that matters.**
## Change `EchoRuntime._dash` from adding to velocity to replacing it and
## every crossing in a movement table moves while every constant stays
## where it was -- and while the physics package's `scene_digest`, which
## describes the platform and not the controller, stays byte-identical.
## So this asserts the script bodies are actually in it, against the
## files themselves, rather than trusting that a line naming them runs.
func _the_controller_digest_covers_the_code_and_not_only_the_numbers() \
		-> void:
	var text := ControllerDigest.text()
	var digest := ControllerDigest.digest()
	_check(digest.length() == 16 and digest == digest.to_lower(),
			"the controller digest is sixteen lowercase hex characters "
			+ "(%s)" % digest)
	_check(digest == ControllerDigest.digest(),
			"and it is the same twice in one build, which is what 'one "
			+ "per build' means")
	for path: String in ControllerDigest.MOVEMENT_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		_check(source != "",
				"'%s' is named as a movement script and could not be "
				% path + "read; a digest over a missing file is a "
				+ "constant")
		_check(text.contains(source.sha256_text().substr(0, 16)),
				"the digest carries the CONTENT of '%s', so changing "
				% path + "what it does invalidates a measurement even "
				+ "when no constant moves")
	# AND IT IS NOT THE SCENE DIGEST. Different question, different
	# answer; §8b says so and this is the assertion behind it.
	_check(text.contains("WALK_SPEED") and text.contains("floor_max_angle"),
			"it covers the controller's own numbers: %s" % text)
