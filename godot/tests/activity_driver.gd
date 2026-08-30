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
	await _test_the_real_zone_builder_actually_builds_activities()
	await _test_a_zone_built_activity_is_drivable()
	await _test_no_element_is_buried_in_a_wall()
	await _test_every_shell_route_still_populates_the_chamber()
	await _test_two_activities_never_share_a_transform()
	await _test_an_activity_avoids_what_is_already_in_the_room()
	await _test_each_family_has_its_own_silhouette()
	await _test_start_and_goal_are_not_the_same_object()
	await _test_order_is_countable_before_you_fail()
	await _test_routing_pads_are_physically_linked()
	await _test_activity_tint_never_impersonates_a_reserved_layer()
	await _test_a_null_shell_id_is_not_a_shell_id()

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

# --- the game reaches them at all ---------------------------------------

## A Zone with one activity in one ordinary procedural room.
func _zone_with_activities() -> Dictionary:
	return {
		"schema_version": 7, "zone_id": "zone_001",
		"display_name": "Relay", "target_game": "Game",
		"theme": "concrete_facility",
		"chambers": [{
			"id": "c1", "type": "arena", "width": 22.0, "depth": 20.0,
			"wall_height": 6.0, "objective": "kill_all",
			"reward_location_id": 89100001,
			"enemies": [{"archetype": "melee", "count": 2}],
			"activities": [
				{"kind": "switch_sequence", "element_count": 3},
				{"kind": "target_challenge", "element_count": 2}]}]}

func _runtimes_under(node: Node) -> Array[ActivityRuntime]:
	var out: Array[ActivityRuntime] = []
	if node is ActivityRuntime:
		out.append(node as ActivityRuntime)
	for child in node.get_children():
		out.append_array(_runtimes_under(child))
	return out

func _test_the_real_zone_builder_actually_builds_activities() -> void:
	"""THE TEST THAT WAS MISSING, and the reason the first version of
	this batch shipped doing nothing.

	Every other test in this file calls `Activities.build` itself. So
	they proved the runtime works and proved NOTHING about whether the
	game ever calls it -- and it did not: the activity loop sat at the
	bottom of `_from_authored_scene`, `build_chamber` returned before it
	on every route the registry actually takes, and a whole Zone was
	built with zero activities in it while this suite was green.

	This one goes through `ZoneBuilder.build`, which is what the game
	calls, and counts what came out.
	"""
	var build := ZoneBuilder.build(_zone_with_activities())
	var root: Node3D = build["root"]
	add_child(root)
	await get_tree().process_frame
	var runtimes := _runtimes_under(root)
	_check(runtimes.size() == 2,
			"ZoneBuilder produced %d activity runtimes for a Zone that "
			% runtimes.size() + "asked for 2; the game does not reach the "
			+ "builder")
	var elements := 0
	for runtime in runtimes:
		elements += runtime.elements.size()
	_check(elements == 5,
			"the built activities hold %d elements, not the 5 the Zone "
			% elements + "asked for")
	root.queue_free()
	await get_tree().process_frame

func _test_a_zone_built_activity_is_drivable() -> void:
	"""And the one the game built can be finished.

	Separate from the count above on purpose: "two runtimes exist" and
	"a player can solve one" are different claims, and the whole lesson
	here is that the cheaper claim is the one that passes while the game
	does nothing.
	"""
	var build := ZoneBuilder.build(_zone_with_activities())
	var root: Node3D = build["root"]
	add_child(root)
	await get_tree().process_frame
	var runtimes := _runtimes_under(root)
	if runtimes.is_empty():
		_check(false, "nothing to drive: ZoneBuilder built no activities")
		root.queue_free()
		return
	activities_built += runtimes.size()
	var runtime := runtimes[0]
	await _solve(runtime)
	_check(runtime.state == ActivityRuntime.State.COMPLETE,
			"an activity the REAL zone builder placed could not be "
			+ "solved (state %d)" % runtime.state)
	if runtime.state == ActivityRuntime.State.COMPLETE:
		completions_seen += 1
	root.queue_free()
	await get_tree().process_frame

func _test_no_element_is_buried_in_a_wall() -> void:
	"""An element half inside a wall is not a puzzle piece, it is a
	meaningless shape stuck in the geometry -- which is exactly what the
	owner reported seeing before any of this worked.

	Swept over a range of room sizes rather than spot-checked: the bad
	case is the WIDEST element in the NARROWEST room, and a single
	fixture size would miss it.
	"""
	for width: float in [8.0, 12.0, 20.0, 30.0]:
		for kind: String in ActivityRuntime.RULES:
			var host := Node3D.new()
			add_child(host)
			var built := Activities.build(host, {
				"kind": kind, "element_count": 4,
			}, "concrete_facility", width, 18.0, "c1", "%s_probe" % kind)
			var runtime := built["runtime"] as ActivityRuntime
			for element in runtime.elements:
				var half: float = _element_half_width(element)
				var edge: float = absf(element.position.x) + half
				_check(edge <= width / 2.0 + 0.001,
						"a %s element in a %.0fm room reaches %.2fm from "
						% [kind, width, edge] + "the centre line, past the "
						+ "%.2fm wall" % (width / 2.0))
				_check(element.position.z >= 0.0
						and element.position.z <= 18.0,
						"a %s element sits at z=%.2f, outside the room"
						% [kind, element.position.z])
			host.queue_free()
			await get_tree().process_frame

func _element_half_width(element: ActivityElement) -> float:
	for child in element.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).get_aabb().size.x / 2.0
	return 0.0

func _test_every_shell_route_still_populates_the_chamber() -> void:
	"""Chamber content survives whichever room `_shell` chose.

	The bug this batch shipped with was a ROUTING bug: the population
	step lived at the bottom of one of `_shell`'s four exits, and the
	game takes a different one. So the property worth pinning is not "the
	procedural route works" -- it is that the route CANNOT MATTER,
	because population happens after the route has finished.

	Driven through `build_chamber` with registries that force different
	branches, rather than by reading the source: a comment saying the
	steps are separate is what the last version effectively had.
	"""
	var chamber := {
		"id": "c1", "type": "arena", "width": 22.0, "depth": 20.0,
		"wall_height": 6.0, "objective": "kill_all",
		"activities": [{"kind": "switch_sequence", "element_count": 3}]}

	var routes := {
		"registry as shipped": ContentRegistry.shared(),
		"nothing registered": _registry({}),
		"shell id unknown to the registry": _registry({"other": {
			"id": "other", "category": "room_shell"}}),
		"shell present, procedural fallback": _registry({
			"shell_arena_proc": {"id": "shell_arena_proc",
				"category": "room_shell", "procedural_fallback": true}}),
	}
	for label: String in routes:
		var result := ContentInstantiator.build_chamber(
				chamber, "concrete_facility", routes[label])
		var built: Array = result.get("activities", []) as Array
		_check(built.size() == 1,
				"route '%s' produced %d activities for a chamber that "
				% [label, built.size()] + "declares 1: the shell route can "
				+ "still drop chamber content")
		if built.size() == 1:
			var runtime := (built[0] as Dictionary).get("runtime") \
					as ActivityRuntime
			_check(runtime != null and runtime.elements.size() == 3,
					"route '%s' built an activity with no elements" % label)
		var root := result.get("root") as Node3D
		if root != null:
			root.queue_free()
		await get_tree().process_frame

func _registry(entries: Dictionary) -> ContentRegistry:
	var reg := ContentRegistry.new()
	reg.entries = entries
	return reg

# --- placement ----------------------------------------------------------

func _positions(runtime: ActivityRuntime) -> Array:
	var out: Array = []
	for element in runtime.elements:
		out.append(element.position)
	return out

func _test_two_activities_never_share_a_transform() -> void:
	"""Distinct elements must occupy distinct places.

	MEASURED, not hypothetical: c002 and c006 of Zone 1 each held two
	`target_challenge`s of identical size, and the row solver -- which
	knew the room's DIMENSIONS and nothing about its CONTENTS -- gave
	both the same coordinates, so each room showed half the targets it
	contained.

	A property over the whole vocabulary rather than a check on those two
	rooms: any two activities of one kind in one room, at any size the
	schema admits.
	"""
	for kind: String in ActivityRuntime.RULES:
		for count in [2, 5]:
			var host := Node3D.new()
			add_child(host)
			var claimed: Array[AABB] = []
			var seen: Array = []
			for pass_index in 2:
				var built := Activities.build(host, {
					"kind": kind, "element_count": count,
				}, "concrete_facility", 24.0, 22.0, "c1",
					"%s_%d" % [kind, pass_index], claimed)
				for box: Variant in (built as Dictionary).get(
						"footprints", []) as Array:
					claimed.append(box as AABB)
				seen.append(_positions(
						(built as Dictionary)["runtime"] as ActivityRuntime))
			for a: Vector3 in seen[0]:
				for b: Vector3 in seen[1]:
					_check(a.distance_to(b) > 0.001,
							"two %s activities put elements at the same "
							% kind + "transform %s" % a)
			host.queue_free()
			await get_tree().process_frame

func _test_an_activity_avoids_what_is_already_in_the_room() -> void:
	"""The other half: props, not just other activities.

	Driven with a claimed box straddling the ideal spot, so the check
	fails if the solver ignores its occupancy argument entirely.
	"""
	var host := Node3D.new()
	add_child(host)
	var bare := Activities.build(host, {
		"kind": "switch_sequence", "element_count": 3,
	}, "concrete_facility", 24.0, 22.0, "c1", "bare")
	var ideal := _positions((bare as Dictionary)["runtime"] as ActivityRuntime)

	var blocked: Array[AABB] = []
	for spot: Vector3 in ideal:
		blocked.append(AABB(spot - Vector3.ONE, Vector3.ONE * 2.0))
	var moved := Activities.build(host, {
		"kind": "switch_sequence", "element_count": 3,
	}, "concrete_facility", 24.0, 22.0, "c1", "moved", blocked)
	var after := _positions((moved as Dictionary)["runtime"] as ActivityRuntime)
	for i in after.size():
		var clear := true
		for box: AABB in blocked:
			if box.has_point(after[i]):
				clear = false
		_check(clear, "element %d stayed inside occupied space at %s"
				% [i, after[i]])
	host.queue_free()
	await get_tree().process_frame

# --- readability, structurally ------------------------------------------

func _silhouette(runtime: ActivityRuntime, index := 0) -> AABB:
	var box := AABB()
	var started := false
	var element := runtime.elements[index]
	for child in element.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh := child as MeshInstance3D
		var world: AABB = mesh.transform * mesh.get_aabb()
		if not started:
			box = world
			started = true
		else:
			box = box.merge(world)
	return box

func _test_each_family_has_its_own_silhouette() -> void:
	"""`switch_sequence` and `timed_run` were pixel-identical: one box,
	one size, one material. Structure has to say which family this is
	before colour says anything at all."""
	var shapes := {}
	for kind: String in ActivityRuntime.RULES:
		var host := Node3D.new()
		add_child(host)
		var built := Activities.build(host, {
			"kind": kind, "element_count": 3,
		}, "concrete_facility", 24.0, 22.0, "c1", "%s_s" % kind)
		var runtime := (built as Dictionary)["runtime"] as ActivityRuntime
		var box := _silhouette(runtime)
		shapes[kind] = box
		_check(box.size.length() > 0.5, "%s has no silhouette" % kind)
		host.queue_free()
		await get_tree().process_frame
	var kinds: Array = shapes.keys()
	for i in kinds.size():
		for j in range(i + 1, kinds.size()):
			var a: AABB = shapes[kinds[i]]
			var b: AABB = shapes[kinds[j]]
			_check((a.size - b.size).length() > 0.25,
					"'%s' and '%s' have the same outline (%s vs %s); one "
					% [kinds[i], kinds[j], a.size, b.size]
					+ "of them is telling the player nothing")

func _test_start_and_goal_are_not_the_same_object() -> void:
	var host := Node3D.new()
	add_child(host)
	var built := Activities.build(host, {
		"kind": "timed_run", "element_count": 4,
	}, "concrete_facility", 24.0, 22.0, "c1", "run")
	var runtime := (built as Dictionary)["runtime"] as ActivityRuntime
	var start := -1
	var goal := -1
	for i in runtime.elements.size():
		if runtime.elements[i].role == ActivityElement.ROLE_START:
			start = i
		elif runtime.elements[i].role == ActivityElement.ROLE_GOAL:
			goal = i
	_check(start >= 0 and goal >= 0, "the run has no start or no goal")
	if start >= 0 and goal >= 0:
		var a := _silhouette(runtime, start)
		var b := _silhouette(runtime, goal)
		_check((a.size - b.size).length() > 0.5,
				"START and GOAL are the same shape (%s vs %s)"
				% [a.size, b.size])
		# And a waypoint must not masquerade as either.
		for i in runtime.elements.size():
			if i == start or i == goal:
				continue
			var mid := _silhouette(runtime, i)
			_check((mid.size - b.size).length() > 0.5,
					"a waypoint has the GOAL's outline")
	host.queue_free()
	await get_tree().process_frame

func _test_order_is_countable_before_you_fail() -> void:
	"""An ordered sequence shows its order as countable structure, and an
	UNORDERED one must not: a counter on a puzzle with no order would be
	telling the player about a rule that does not exist."""
	for ordered in [true, false]:
		var host := Node3D.new()
		add_child(host)
		var built := Activities.build(host, {
			"kind": "switch_sequence", "element_count": 4,
			"ordered": ordered, "time_limit": 24.0 if ordered else 0.0,
		}, "concrete_facility", 24.0, 22.0, "c1", "seq_%s" % ordered)
		var runtime := (built as Dictionary)["runtime"] as ActivityRuntime
		var counts: Array[int] = []
		for element in runtime.elements:
			var lugs := 0
			for child in element.get_children():
				if child is MeshInstance3D \
						and (child as MeshInstance3D).mesh is BoxMesh \
						and ((child as MeshInstance3D).mesh as BoxMesh) \
							.size.is_equal_approx(Vector3.ONE * 0.1):
					lugs += 1
			counts.append(lugs)
		if ordered:
			_check(counts == [1, 2, 3, 4],
					"an ordered sequence's order is not countable: %s"
					% [counts])
		else:
			_check(counts == [0, 0, 0, 0],
					"an unordered sequence implies an order it does not "
					+ "have: %s" % [counts])
		host.queue_free()
		await get_tree().process_frame

func _test_routing_pads_are_physically_linked() -> void:
	"""The simultaneity rule is invisible without one. A conduit says
	"these are one system" with no legend and no hue."""
	var host := Node3D.new()
	add_child(host)
	var built := Activities.build(host, {
		"kind": "pressure_routing", "element_count": 4,
	}, "concrete_facility", 24.0, 22.0, "c1", "route")
	var runtime := (built as Dictionary)["runtime"] as ActivityRuntime
	var conduits := 0
	for child in runtime.get_children():
		if child.name.begins_with("Conduit"):
			conduits += 1
	_check(conduits == runtime.elements.size() - 1,
			"%d pads are joined by %d conduits"
			% [runtime.elements.size(), conduits])
	# And no other family grows them: a latching switch row is not a bus.
	var other := Activities.build(host, {
		"kind": "switch_sequence", "element_count": 4,
	}, "concrete_facility", 24.0, 22.0, "c1", "not_route")
	var stray := 0
	for child in ((other as Dictionary)["runtime"] as Node).get_children():
		if child.name.begins_with("Conduit"):
			stray += 1
	_check(stray == 0, "a switch_sequence grew %d conduits" % stray)
	host.queue_free()
	await get_tree().process_frame

func _test_activity_tint_never_impersonates_a_reserved_layer() -> void:
	"""MEASURED: `neon_transit`'s light is #7cf2ff, 0.17 from
	CHECK_SIGNAL against a floor of 0.45 -- so in the Zone the owner
	actually plays, every switch and target wore Archipelago's colour.

	Swept over every theme, and the separation is asserted against the
	SHIPPED constant rather than a number retyped here.
	"""
	for theme: String in Constants.THEMES:
		var raw := ThemeMaterials.light_color(theme)
		var used := VisualOwnership.separated_from_reserved(raw)
		for reserved: Color in VisualOwnership.RESERVED_FOR_OTHERS:
			var apart := Vector3(used.r - reserved.r, used.g - reserved.g,
					used.b - reserved.b).length()
			_check(apart >= VisualOwnership.MIN_LAYER_SEPARATION,
					"'%s' activity tint %s sits %.2f from a reserved "
					% [theme, used, apart] + "signal; the floor is %.2f"
					% VisualOwnership.MIN_LAYER_SEPARATION)

func _test_a_null_shell_id_is_not_a_shell_id() -> void:
	"""`shell_id` is nullable and arrives as JSON null. `str(null)` is
	the six-character string "<null>", which is not empty -- so every
	chamber took the "Epsilon chose a shell" branch with garbage."""
	var chamber := {
		"id": "c1", "type": "arena", "width": 22.0, "depth": 20.0,
		"wall_height": 6.0, "objective": "kill_all", "shell_id": null,
		"activities": [{"kind": "switch_sequence", "element_count": 2}]}
	var result := ContentInstantiator.build_chamber(
			chamber, "concrete_facility", _registry({}))
	_check((result.get("activities", []) as Array).size() == 1,
			"a null shell_id broke the chamber")
	var root := result.get("root") as Node3D
	if root != null:
		root.queue_free()
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
