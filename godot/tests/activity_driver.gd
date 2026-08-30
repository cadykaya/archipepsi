extends Node
## The activity-conversion suite (`make godot-activity`).
##
## WHAT THIS SUITE IS FOR, stated plainly because the previous guard is
## the reason it is needed. `test_runner_coverage.py` reads
## `activities.gd` as TEXT and asserts every schema kind appears in it. It
## proves a `match` branch EXISTS. It cannot see that the branch built a
## `StaticBody3D` and returned — which is what it did, for four kinds, in
## a Zone where 57.7% of the content value was activities.
##
## So nothing here greps, and nothing here asserts that geometry was
## instantiated. Every test DRIVES an activity the way a player would and
## asserts what happened:
##
##   * an untouched activity never completes
##   * N-1 of N is not N
##   * an ordered activity refuses the wrong order
##   * a timed activity can run out of time
##   * a reset returns it to exactly its starting state, repeatably
##   * every kind the engine scores can actually be finished
##   * finishing one sends the local-reward intent and NOTHING else
##   * finishing one twice is one reward, not two
##   * a missing capability reads as NOT YET rather than as a broken switch
##
## Boots the real project: elements are `Area3D`s that a real player body
## has to enter, and shot elements are reached through the same
## `Damageable` path Static Pulse uses. A `--script` run has no physics
## and no autoloads, so it could only ever test the internals.

const DT := 1.0 / 60.0

var failures := 0
## Vacuity guards. Every "nothing bad happened" assertion below is
## worthless if the suite built nothing or never actually drove anything.
var activities_built := 0
var completions_seen := 0
var real_shots_landed := 0
var touches_by_physics := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	await _run()

func _run() -> void:
	await get_tree().process_frame
	BridgeClient.snapshot = _snapshot()
	BridgeClient.sent_intents.clear()

	await _test_every_kind_can_actually_be_finished()
	await _test_an_untouched_activity_never_completes()
	await _test_n_minus_one_is_not_n()
	await _test_an_ordered_activity_refuses_the_wrong_order()
	await _test_a_timed_activity_can_run_out_of_time()
	await _test_a_reset_is_deterministic()
	await _test_a_plate_that_releases_breaks_the_circuit()
	await _test_a_plate_holds_long_enough_to_reach_the_next()
	await _test_completion_sends_one_local_reward_and_nothing_else()
	await _test_solving_it_twice_is_one_reward()
	await _test_a_missing_capability_reads_as_not_yet()
	await _test_not_yet_never_fakes_an_interaction()
	await _test_a_capability_you_have_equipped_is_playable()
	await _test_a_touch_element_is_reached_by_a_real_player_body()
	await _test_a_shot_element_is_reached_by_a_real_weapon()

	_check(activities_built >= 10,
			"the suite built %d activities; it is not exercising the "
			% activities_built + "vocabulary")
	_check(completions_seen >= 6,
			"only %d completions were observed; the success paths are "
			% completions_seen + "not being driven")
	_check(real_shots_landed > 0,
			"no shot reached a target through a real weapon: the damage "
			+ "PATH to an activity element is untested")
	_check(touches_by_physics > 0,
			"no element was triggered by a real player body entering it: "
			+ "the physics path is untested")

	if failures == 0:
		print("GODOT ACTIVITY TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT ACTIVITY TESTS: %d failures" % failures)
		get_tree().quit(1)

# --- building ------------------------------------------------------------

func _make(kind: String, count := 3, time_limit := 0.0, ordered := false,
		requires: Array = []) -> ActivityRuntime:
	var root := Node3D.new()
	add_child(root)
	var built := Activities.build(root, {
		"kind": kind, "element_count": count, "time_limit": time_limit,
		"ordered": ordered, "requires": requires,
	}, "concrete_facility", 20.0, 18.0, "room_test", "%s_probe" % kind)
	activities_built += 1
	var runtime := built["runtime"] as ActivityRuntime
	_check(runtime != null, "no runtime for '%s'" % kind)
	return runtime

## Set one element the way its trigger mode says it is set, WITHOUT
## reaching into the runtime. A test that called `_apply_set` would prove
## the state machine works on inputs no player can produce.
func _drive(element: ActivityElement) -> void:
	if element.trigger == ActivityElement.SHOT:
		# Through the collider a weapon reaches, not through the element:
		# hitting the element directly would prove the state machine
		# works on an input no shot can produce.
		Damageable.hit(element.get_node("TargetBody"), 1.0,
				Vector3.FORWARD, 0.0)
		return
	var body := _body()
	element.add_child(body)
	body.global_position = element.global_position
	await _physics(3)
	touches_by_physics += 1
	body.queue_free()
	await get_tree().process_frame

func _body() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.add_to_group("player")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.6, 0.6)
	shape.shape = box
	body.add_child(shape)
	return body

func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

## Drive every element in order and return the runtime.
func _solve(runtime: ActivityRuntime) -> void:
	for element in runtime.elements:
		await _drive(element)

# --- the success path, per family ----------------------------------------

func _test_every_kind_can_actually_be_finished() -> void:
	"""Scored implies playable.

	`content_value.py` pays for all four families. A family the engine
	scores and cannot finish is budget spent on scenery, which is the
	exact defect this batch exists to remove — so this is the test that
	would have failed on the old builder for every kind at once.
	"""
	for kind: String in ActivityRuntime.RULES:
		var runtime := _make(kind, 3)
		await _solve(runtime)
		var done := runtime.state == ActivityRuntime.State.COMPLETE
		_check(done, "a '%s' driven to the end did not complete (state %d)"
				% [kind, runtime.state])
		if done:
			completions_seen += 1
		runtime.get_parent().queue_free()
		await get_tree().process_frame

# --- the negative controls ----------------------------------------------

func _test_an_untouched_activity_never_completes() -> void:
	for kind: String in ActivityRuntime.RULES:
		var runtime := _make(kind, 3)
		await _physics(20)
		_check(runtime.state == ActivityRuntime.State.IDLE,
				"an untouched '%s' left IDLE on its own (state %d)"
				% [kind, runtime.state])
		_check(runtime.attempts == 0,
				"an untouched '%s' counted an attempt" % kind)
		runtime.get_parent().queue_free()
		await get_tree().process_frame

func _test_n_minus_one_is_not_n() -> void:
	"""Partial completion is not completion.

	Run for every family, because "close enough" is the failure mode a
	success-only test cannot see: an `_all_set` that returned true on the
	first element would pass every test above.
	"""
	for kind: String in ActivityRuntime.RULES:
		var runtime := _make(kind, 4)
		var all := runtime.elements
		for i in all.size() - 1:
			await _drive(all[i])
		_check(runtime.state != ActivityRuntime.State.COMPLETE,
				"a '%s' completed with one element left" % kind)
		runtime.get_parent().queue_free()
		await get_tree().process_frame

func _test_an_ordered_activity_refuses_the_wrong_order() -> void:
	var runtime := _make("switch_sequence", 3, 0.0, true)
	await _drive(runtime.elements[1])          # second, not first
	_check(runtime.state != ActivityRuntime.State.COMPLETE,
			"an ordered activity completed from the wrong element")
	_check(runtime.elements[1].is_set == false,
			"a wrong-order attempt left the element latched, so the "
			+ "geometry disagrees with the state")
	# And it is still winnable afterwards: a reset that soft-locked the
	# puzzle would pass the assertion above and ruin the room.
	await get_tree().create_timer(
			Constants.ACTIVITY_RESULT_SECONDS + 0.2).timeout
	await _solve(runtime)
	_check(runtime.state == ActivityRuntime.State.COMPLETE,
			"an ordered activity could not be solved after one mistake")
	if runtime.state == ActivityRuntime.State.COMPLETE:
		completions_seen += 1
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_a_timed_activity_can_run_out_of_time() -> void:
	"""A clock that cannot lapse is decoration.

	The played Zone had seven `timed_run`s with `time_limit = 0`, so the
	one dial that can make a family fail was never once exercised.
	"""
	var runtime := _make("timed_run", 2, 0.4)
	await _drive(runtime.elements[0])
	_check(runtime.state == ActivityRuntime.State.ACTIVE,
			"touching the start did not start the run")
	await get_tree().create_timer(0.7).timeout
	_check(runtime.state != ActivityRuntime.State.COMPLETE,
			"a run completed after its clock lapsed")
	_check(runtime.attempts == 1, "the lapsed attempt was not counted")
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_a_reset_is_deterministic() -> void:
	"""Twice through the same failure leaves exactly the same state."""
	var runtime := _make("switch_sequence", 3, 0.0, true)
	var states: Array[String] = []
	for attempt in 2:
		await _drive(runtime.elements[2])       # wrong every time
		await get_tree().create_timer(
				Constants.ACTIVITY_RESULT_SECONDS + 0.2).timeout
		var latched := 0
		for element in runtime.elements:
			if element.is_set:
				latched += 1
		states.append("%d/%d" % [runtime.state, latched])
	_check(states[0] == states[1],
			"two identical failures left different states: %s" % [states])
	_check(states[0] == "%d/0" % ActivityRuntime.State.IDLE,
			"a reset did not return to a clean IDLE: %s" % states[0])
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_a_plate_that_releases_breaks_the_circuit() -> void:
	"""`pressure_routing` is the only family whose elements can un-set,
	and that is the whole family: a circuit is not routed if part of it
	dropped out on the way."""
	var runtime := _make("pressure_routing", 3)
	var body := _body()
	runtime.elements[0].add_child(body)
	body.global_position = runtime.elements[0].global_position
	await _physics(3)
	_check(runtime.state == ActivityRuntime.State.ACTIVE,
			"standing on a plate did not start the routing")
	body.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(Constants.PLATE_HOLD_SECONDS + 0.3).timeout
	_check(runtime.state != ActivityRuntime.State.COMPLETE,
			"a routing puzzle completed with a plate released")
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_a_plate_holds_long_enough_to_reach_the_next() -> void:
	"""The other half, and the one that makes the family possible at all:
	one player cannot stand on three plates, so the hold window has to be
	long enough to run the circuit."""
	var runtime := _make("pressure_routing", 3)
	await _solve(runtime)
	_check(runtime.state == ActivityRuntime.State.COMPLETE,
			"three plates could not be routed inside the hold window")
	if runtime.state == ActivityRuntime.State.COMPLETE:
		completions_seen += 1
	runtime.get_parent().queue_free()
	await get_tree().process_frame

# --- the reward is local, singular and unfarmable ------------------------

func _test_completion_sends_one_local_reward_and_nothing_else() -> void:
	BridgeClient.sent_intents.clear()
	var runtime := _make("switch_sequence", 2)
	await _solve(runtime)
	_check(runtime.state == ActivityRuntime.State.COMPLETE, "did not solve")
	if runtime.state == ActivityRuntime.State.COMPLETE:
		completions_seen += 1
	var sent: Array = BridgeClient.sent_intents.duplicate()
	_check(sent.size() == 1,
			"completion sent %d intents; exactly one local reward is the "
			% sent.size() + "whole contract")
	for intent: Variant in sent:
		var record := intent as Dictionary
		_check(str(record.get("type", "")) == "grant_local_reward",
				"completion sent a '%s' intent" % record.get("type", ""))
		_check(str(record.get("kind", "")) == "flavor_log",
				"completion used the '%s' local-reward kind; "
				% record.get("kind", "")
				+ "challenge_marker is deliberately deferred")
		# §14.2, structurally: there is no shape here that names AP truth.
		for field: String in ["location_id", "location", "item", "check",
				"coins", "signal_keys"]:
			_check(not record.has(field),
					"a completion intent carried '%s'" % field)
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_solving_it_twice_is_one_reward() -> void:
	"""An activity is not a farm.

	The client's half: the `reward_id` is derived from the activity's
	identity, so a second solve is the same note. The bridge's half —
	`transitions.grant_local_reward` being idempotent by `reward_id` — is
	tested in Python; this asserts the client gives it something it can
	be idempotent ABOUT.
	"""
	BridgeClient.sent_intents.clear()
	var first := _make("target_challenge", 2)
	await _solve(first)
	var second := _make("target_challenge", 2)
	await _solve(second)
	var ids := {}
	for intent: Variant in BridgeClient.sent_intents:
		ids[str((intent as Dictionary).get("reward_id", ""))] = true
	_check(ids.size() == 1,
			"two solves of the same activity produced %d reward ids"
			% ids.size())
	first.get_parent().queue_free()
	second.get_parent().queue_free()
	await get_tree().process_frame

# --- NOT YET -------------------------------------------------------------

func _test_a_missing_capability_reads_as_not_yet() -> void:
	var snapshot := _snapshot()
	snapshot["available_capabilities"] = ["ranged_hit"]
	BridgeClient.snapshot = snapshot
	var runtime := _make("switch_sequence", 2, 0.0, false, ["grapple"])
	_check(runtime.state == ActivityRuntime.State.NOT_YET,
			"an activity needing an unequipped capability was playable "
			+ "(state %d)" % runtime.state)
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_not_yet_never_fakes_an_interaction() -> void:
	"""A hard NOT YET is deliberate. It is not a broken switch, and the
	activity is never silently downgraded to a base-kit substitute."""
	var snapshot := _snapshot()
	snapshot["available_capabilities"] = ["ranged_hit"]
	BridgeClient.snapshot = snapshot
	BridgeClient.sent_intents.clear()
	var runtime := _make("switch_sequence", 2, 0.0, false, ["blink"])
	await _solve(runtime)
	_check(runtime.state == ActivityRuntime.State.NOT_YET,
			"a NOT YET activity was solved anyway")
	_check(runtime.attempts == 0, "a NOT YET activity counted an attempt")
	for element in runtime.elements:
		_check(not element.is_set,
				"a NOT YET element latched, which reads as a broken switch")
	_check(BridgeClient.sent_intents.is_empty(),
			"a NOT YET activity sent %d intents"
			% BridgeClient.sent_intents.size())
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_a_capability_you_have_equipped_is_playable() -> void:
	"""The positive control. Without it, "NOT YET" could be produced by a
	gate that refuses everything."""
	var snapshot := _snapshot()
	snapshot["available_capabilities"] = ["ranged_hit", "grapple"]
	BridgeClient.snapshot = snapshot
	var runtime := _make("switch_sequence", 2, 0.0, false, ["grapple"])
	_check(runtime.state == ActivityRuntime.State.IDLE,
			"an activity whose capability IS equipped was refused")
	await _solve(runtime)
	_check(runtime.state == ActivityRuntime.State.COMPLETE,
			"a capability-gated activity could not be solved with the "
			+ "capability equipped")
	if runtime.state == ActivityRuntime.State.COMPLETE:
		completions_seen += 1
	runtime.get_parent().queue_free()
	BridgeClient.snapshot = _snapshot()
	await get_tree().process_frame

# --- the paths, not the internals ---------------------------------------

func _test_a_touch_element_is_reached_by_a_real_player_body() -> void:
	var runtime := _make("switch_sequence", 1)
	var player := Player.create()
	add_child(player)
	player.global_position = runtime.elements[0].global_position
	await _physics(4)
	_check(runtime.elements[0].is_set,
			"the real Player body did not trigger a touch element")
	player.queue_free()
	runtime.get_parent().queue_free()
	await get_tree().process_frame

func _test_a_shot_element_is_reached_by_a_real_weapon() -> void:
	"""Not `Damageable.hit` in a test, but a Player firing.

	The affordance suite learned this the hard way: `BreakablePanel`
	implemented `take_damage` and no weapon in the game could reach it,
	so the capability meant to pay for the affordance never mattered.
	"""
	var runtime := _make("target_challenge", 1)
	var target := runtime.elements[0]
	var player := Player.create()
	add_child(player)
	await _physics(2)
	# Stand off and aim at it, so the shot goes through the camera ray.
	player.global_position = target.global_position + Vector3(0, 0, -4.0)
	player.camera.look_at(target.global_position, Vector3.UP)
	await _physics(2)
	player._fire_static_pulse()
	await _physics(2)
	if target.is_set:
		real_shots_landed += 1
	_check(target.is_set,
			"Static Pulse did not register on a target_challenge element")
	player.queue_free()
	runtime.get_parent().queue_free()
	await get_tree().process_frame

# --- fixture -------------------------------------------------------------

func _snapshot() -> Dictionary:
	return {
		"type": "campaign_snapshot",
		"mechanics": {"owned": [], "aliases": [], "links": [],
				"statuses": [], "resources": []},
		"slots": {}, "local_rewards": [],
		"available_capabilities": ["ranged_hit"],
		"coins_received": 0, "coins_spent": 0,
		"hub": {"state": "IDLE"},
	}
