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
	await _test_a_counted_hit_and_a_failure_reach_a_consumer()
	await _test_a_completion_reaches_its_presentation_consumer()
	await _test_a_key_says_what_it_opened()
	await _test_a_key_that_opened_nothing_says_which_nothing()
	await _test_a_resumed_zone_re_announces_no_old_unlock()
	await _test_two_activities_in_a_room_share_one_station()
	await _test_a_plate_holds_long_enough_to_reach_the_next()
	await _test_completion_sends_one_local_reward_and_nothing_else()
	await _test_solving_it_twice_is_one_reward()
	await _test_a_missing_capability_reads_as_not_yet()
	await _test_not_yet_never_fakes_an_interaction()
	await _test_a_capability_you_have_equipped_is_playable()
	await _test_a_touch_element_is_reached_by_a_real_player_body()
	await _test_a_shot_element_is_reached_by_a_real_weapon()
	await _test_targets_are_mounted_on_real_walls()
	await _test_a_mounted_target_is_shootable_from_the_lane()
	await _test_a_blocked_shot_is_a_blocked_shot()
	await _test_a_wall_with_no_room_declines_the_mount()
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
	await _test_every_activity_says_what_it_is_before_you_touch_it()
	await _test_the_labels_can_be_turned_off()

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

## A BANK THAT REMEMBERS WHAT IT WAS ASKED FOR.
##
## `Tones.play` looks its argument up and returns silently when the name
## is absent, so a test that asserts "play() was called" proves nothing
## about whether a sound happened. This records the NAMES, and the
## companion Python check (`test_tone_references.py`) proves each one
## exists in the real bank -- the two together are the claim.
class RecordingBank extends Tones:
	var heard: Array[String] = []
	func play(kind: String, pitch := 1.0) -> void:
		heard.append(kind)
		super.play(kind, pitch)

class RecordingHud extends Hud:
	var toasts: Array[String] = []
	func toast(text: String, color := Color.WHITE,
			seconds := 3.5) -> void:
		toasts.append(text)
		super.toast(text, color, seconds)

## COUNTED ACTIONS AND FAILURES, DRIVEN THROUGH REAL TRIGGERS.
##
## The playtest shot seven targets and could not tell whether anything
## had happened. `_on_set` updated a world label and played nothing, and
## `failed` had no listener anywhere in the project.
func _test_a_counted_hit_and_a_failure_reach_a_consumer() -> void:
	var bank := RecordingBank.new()
	add_child(bank)
	var runtime := _make("target_challenge", 3)
	runtime.tones = bank
	# One real hit, through the trigger a weapon uses.
	await _drive(runtime.elements[0])
	_check(bank.heard.has("confirm"),
			"a counted hit is audible at the moment it counts (heard %s)"
			% str(bank.heard))
	# AND A FAILURE SAYS SO. A timed activity that runs out clears every
	# element; before this the only report was the geometry going dark.
	var timed := _make("switch_sequence", 3, 0.35)
	var told: Array[String] = []
	timed.failed.connect(func(_id: String, reason: String) -> void:
		told.append(reason))
	await _drive(timed.elements[0])
	await _physics(40)
	_check(told.size() >= 1,
			"and a timed activity that runs out emits `failed` for a "
			+ "consumer to report (%s)" % str(told))
	bank.queue_free()

## AND THE CONSUMER ITSELF, exercised rather than assumed.
##
## `ZoneController._on_activity_completed` is the presentation consumer:
## it toasts, it asks the bank for a chime, and it repairs the room's
## station. It asked for `"secret_found"`, which the bank does not
## define, so the chime was silent from the day it was written. This
## drives the handler and reads what it asked for.
func _test_a_completion_reaches_its_presentation_consumer() -> void:
	var bank := RecordingBank.new()
	var hud := RecordingHud.new()
	var zone := ZoneController.new()
	add_child(zone)
	zone.tones = bank
	zone.hud = hud
	zone.add_child(bank)
	zone.add_child(hud)
	zone._on_activity_completed("probe_activity", 4.25, 1)
	_check(hud.toasts.size() == 1
			and hud.toasts[0].contains("COMPLETE"),
			"a completed activity reaches the screen (%s)"
			% str(hud.toasts))
	_check(bank.heard.size() == 1,
			"and asks the bank for exactly one chime (%s)"
			% str(bank.heard))
	_check(bank.heard.size() == 1 and bank.heard[0] == "secret",
			"and asks for a name the bank actually defines -- "
			+ "`secret_found` is an `epsilon_voice` line id and was "
			+ "silent here (%s)" % str(bank.heard))
	zone.queue_free()
	await get_tree().process_frame


## TWO PUZZLES IN A ROOM ARE TWO WAYS INTO ONE CONSEQUENCE.
##
## A station's repair is attached to a ROOM, so the first activity
## solved in that room repairs it and every later one finds it already
## repaired. Both said "<ID> COMPLETE" and nothing else, so the
## difference was invisible: a player who solved the second puzzle had
## no way to learn whether it had done anything, and kept looking for a
## payoff that was not there.
##
## This is the truthful-feedback half only. Nothing here grants a
## reward, marks an activity complete, makes one compulsory or changes
## when a station repairs. Turning these into declared alternative
## solutions is a design proposal and stays one.
func _test_two_activities_in_a_room_share_one_station() -> void:
	var hud := RecordingHud.new()
	var zone := ZoneController.new()
	add_child(zone)
	zone.hud = hud
	zone.add_child(hud)
	var station := WarpStation.create("st:hall", "HALL", "signal", "c007")
	zone.add_child(station)
	zone.set("_stations", [station])
	zone.set("_activity_room", {"c007_0": "c007", "c007_1": "c007",
			"c009_0": "c009"})
	_check(station.is_broken(),
			"the probe station did not start broken, so there is nothing "
			+ "to repair")

	zone._on_activity_completed("c007_0", 4.0, 1)
	var first: String = hud.toasts[hud.toasts.size() - 1]
	_check(first.contains("ONLINE"),
			"the first activity in a room did not report bringing its "
			+ "station online (%s)" % first)
	_check(not station.is_broken(),
			"the first activity did not actually repair the station")
	var after_first := hud.toasts.size()

	zone._on_activity_completed("c007_1", 6.0, 1)
	var second: String = hud.toasts[hud.toasts.size() - 1]
	_check(second.contains("already online"),
			"the second activity in the same room said '%s', which is "
			% second + "what the first said: a player cannot tell that "
			+ "it was an alternative route into a consequence they "
			+ "already have")
	_check(hud.toasts.size() == after_first + 1,
			"one completion produced %d cards"
			% (hud.toasts.size() - after_first))

	# A ROOM WITH NO STATION SAYS NOTHING EXTRA, so the line above is a
	# fact about this room rather than a decoration on every completion.
	zone._on_activity_completed("c009_0", 3.0, 1)
	var elsewhere: String = hud.toasts[hud.toasts.size() - 1]
	_check(not elsewhere.contains("ONLINE")
			and not elsewhere.contains("already online"),
			"an activity in a room with no station reported a station "
			+ "consequence: %s" % elsewhere)
	zone.queue_free()
	await get_tree().process_frame

## WHAT A KEY ACTUALLY DID, IN ONE LINE.
##
## The playtest ended with the owner holding three keys and reporting
## they had "found no door that uses them". Both halves of the reason
## were in this code: the pickup toast said `RED KEY` and nothing else,
## and every lock that opened sent its OWN `UNLOCKED` card with no room
## on it -- so one key opening three doors was four cards, none of which
## named a place.
##
## `zone_controller` no longer toasts per lock. One message is assembled
## from what opened, and this is what says so.
func _key_zone(rooms: Array) -> ZoneController:
	var hud := RecordingHud.new()
	var zone := ZoneController.new()
	add_child(zone)
	zone.hud = hud
	zone.add_child(hud)
	# The chamber records the labeller reads. Built here rather than by
	# a whole Zone because the question is what the message SAYS, and a
	# generated Zone would decide the room names for us.
	var chambers: Array = []
	for entry: Variant in rooms:
		var room: Dictionary = entry
		chambers.append({"chamber": {"id": room["id"],
				"type": room["type"]}})
	zone.set("_chambers", chambers)
	return zone

func _lock_in(zone: ZoneController, room: String, key: String) -> void:
	var lock := LockedDoor.create(room, "entry", key, "gold", 3.0, 3.0)
	zone.add_child(lock)
	lock.opened.connect(Callable(zone, "_on_lock_opened"))
	var locks: Array = zone.get("_zone_locks")
	locks.append(lock)
	zone.set("_zone_locks", locks)

func _test_a_key_says_what_it_opened() -> void:
	var zone := _key_zone([{"id": "c004", "type": "arena"},
			{"id": "c009", "type": "treasure_room"}])
	var hud: RecordingHud = zone.hud
	_lock_in(zone, "c004", "red")
	_lock_in(zone, "c009", "red")
	# The player has BEEN to c004 and not to c009.
	zone.set("_rooms_entered", {"c004": true})
	zone._on_key_collected("red")
	_check(hud.toasts.size() == 1,
			"one key that opens two doors is ONE message, not three "
			+ "(%d: %s)" % [hud.toasts.size(), str(hud.toasts)])
	var said: String = hud.toasts[0] if not hud.toasts.is_empty() else ""
	_check(said.contains("the arena (c004)"),
			"and it names the room the player has been in, by what the "
			+ "room IS and not only by its id (%s)" % said)
	_check(not said.contains("c009")
			and not said.contains("treasure"),
			"and never names the room they have NOT been in -- an "
			+ "unlock message is not a map (%s)" % said)
	_check(said.contains("1 elsewhere"),
			"but does say there is one, so the count is still true (%s)"
			% said)
	zone.queue_free()
	await get_tree().process_frame

func _test_a_key_that_opened_nothing_says_which_nothing() -> void:
	# NOTHING IN THIS ZONE ANSWERS TO IT.
	var bare := _key_zone([{"id": "c001", "type": "corridor"}])
	var bare_hud: RecordingHud = bare.hud
	bare._on_key_collected("gold")
	_check(not bare_hud.toasts.is_empty()
			and bare_hud.toasts[0].contains("nothing in this Zone"),
			"a key no lock here wants says so (%s)" % str(bare_hud.toasts))
	bare.queue_free()
	# AND ITS DOOR IS ALREADY OPEN, which sends a player somewhere else
	# entirely and so may not share a message with the case above.
	var done := _key_zone([{"id": "c002", "type": "arena"}])
	var done_hud: RecordingHud = done.hud
	_lock_in(done, "c002", "gold")
	var locks: Array = done.get("_zone_locks")
	(locks[0] as LockedDoor).open()
	done.set("_opened_since", [])
	done._on_key_collected("gold")
	_check(not done_hud.toasts.is_empty()
			and done_hud.toasts[0].contains("already open"),
			"and a key whose door is already open says THAT instead "
			+ "(%s)" % str(done_hud.toasts))
	done.queue_free()
	await get_tree().process_frame

func _test_a_resumed_zone_re_announces_no_old_unlock() -> void:
	## A LOAD IS NOT AN EVENT. Restoring a campaign opens every lock the
	## carried keys allow, and each of those would have sent a card --
	## greeting a returning player with a list of doors they opened last
	## night. `setup` clears the batch after the restore for this reason.
	var zone := _key_zone([{"id": "c004", "type": "arena"}])
	var hud: RecordingHud = zone.hud
	_lock_in(zone, "c004", "red")
	var locks: Array = zone.get("_zone_locks")
	(locks[0] as LockedDoor).open()          # as a restore would
	_check(hud.toasts.is_empty(),
			"a lock opening on its own reaches no screen: the message "
			+ "belongs to the pickup (%s)" % str(hud.toasts))
	var pending: Array = zone.get("_opened_since")
	_check(pending.size() == 1,
			"but it IS recorded, so a pickup can report it (%s)"
			% str(pending))
	zone.queue_free()
	await get_tree().process_frame


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

# --- targets belong on walls --------------------------------------------

## "THEY HAVE PEGS AND THEY SHOULD BE STICKING OUT OF THE WALLS."
##
## The owner's note, looking at a `target_challenge` in the first
## juncture. `ActivityElement._build_target` hangs a 0.5 m stalk off the
## back of every target so it reads as MOUNTED equipment -- and `_row`
## placed them by the same floor-plan solve it uses for switches and
## plates, so the stalk held them off nothing in the middle of the room.
##
## `_wall_spot` offers a side wall. These are the four things that offer
## has to be: on the wall, facing the room, clear of the doorway, and
## still shootable from where a player stands.
## CLEAR OF EVERY OTHER ROOM IN THIS FILE, and that is load bearing
## rather than tidy. Every other probe here builds at the origin and the
## roots outlive their own test by a frame, so the first version of the
## shooting control fired at a target from an earlier activity standing
## in the same place -- the shot landed, on somebody else's element, and
## the control reported the room unshootable.
const MOUNT_PROBE_AT := Vector3(600.0, 0.0, 0.0)

func _target_room(count := 3, width := 20.0,
		depth := 18.0) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	# A FLOOR, because "shootable from a supported position" is the
	# claim. Without one the probe player free-falls while it aims, and
	# a shot taken from 1 m below where a player would stand is not
	# evidence about anything a player can do.
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(width + 8.0, 1.0, depth + 16.0)
	gshape.shape = gbox
	ground.add_child(gshape)
	root.add_child(ground)
	ground.position = Vector3(0.0, -0.5, depth / 2.0)
	# AND REAL SIDE WALLS. This probe used to be a floor and an
	# activity, which was enough while mounting trusted the room's
	# declared envelope for where a wall would be. It does not any more
	# -- `_wall_behind` asks the geometry -- so a probe room with no
	# walls correctly gets no mounts, and the fixture has to be a room
	# rather than a plane.
	for wall_side: float in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		var wshape := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = Vector3(0.5, 6.0, depth + 4.0)
		wshape.shape = wbox
		wall.add_child(wshape)
		root.add_child(wall)
		wall.position = Vector3(wall_side * (width / 2.0 + 0.25), 3.0,
				depth / 2.0)
	var built := Activities.build(root, {
		"kind": "target_challenge", "element_count": count,
		"time_limit": 0.0, "ordered": false, "requires": [],
	}, "concrete_facility", width, depth, "room_mount", "mount_probe")
	activities_built += 1
	# MOVED AFTER COMPOSING, and that ordering is load bearing.
	#
	# `Activities.build` gathers the room's solids off the root it is
	# handed and solves in ROOM space -- which is the same space, because
	# production composes a chamber while its root is still at the origin
	# and detached, and `ZoneBuilder` places it afterwards. This probe
	# moved the root out to 600 m FIRST, so every gathered box was at
	# x ~ 600 while every candidate spot was at x ~ 9: `can_place` could
	# never find anything in the way and `_wall_behind` could never find
	# a wall. Composing at the origin and moving after is what production
	# does, and it is what makes this probe's answers mean anything.
	root.global_position = MOUNT_PROBE_AT
	return {"root": root, "built": built, "width": width, "depth": depth}

func _test_targets_are_mounted_on_real_walls() -> void:
	var probe := _target_room()
	var width: float = probe["width"]
	var depth: float = probe["depth"]
	var elements: Array = (probe["built"] as Dictionary)["elements"]
	var plane := width / 2.0 - AffordanceFeatures.WALL_MARGIN
	var mounted := 0
	var sides := {}
	var in_door := 0
	for raw: Variant in elements:
		var element: ActivityElement = raw
		if not bool(element.get_meta("mounted", false)):
			continue
		mounted += 1
		sides[signf(element.position.x)] = true
		# ON THE WALL: the origin sits exactly the stalk's reach off the
		# wall plane, so the hardware lands on the plaster.
		_check(absf(absf(element.position.x)
				- (plane - Activities.MOUNT_STALK)) < 0.01,
				"a mounted target sits %.2f m from the room's centre "
				% absf(element.position.x) + "and the wall plane is at "
				+ "%.2f m: it is not against anything" % plane)
		# FACING THE ROOM: local +Z is the target face, so the face
		# normal has to point back toward the centre line.
		var facing := element.global_transform.basis.z.normalized()
		_check(facing.x * signf(element.position.x) < -0.9,
				"a mounted target faces %s from x %.1f, which is into "
				% [str(facing), element.position.x] + "the wall")
		# NOT ACROSS A DOORWAY. A side socket sits at the middle of a
		# side wall; a shooting gallery across it is worse than one in
		# the air.
		if absf(element.position.z - depth / 2.0) \
				< ChamberBuilders.DOOR_WIDTH / 2.0:
			in_door += 1
	_check(mounted == elements.size(),
			"%d of %d targets in an ordinary arena found a wall"
			% [mounted, elements.size()])
	_check(in_door == 0,
			"%d mounted target(s) sit across the side doorway" % in_door)
	# DIFFERENT ORIENTATIONS, not one wall used three times: the row
	# alternates sides, and a mount that only ever solved the left wall
	# would pass every check above.
	_check(sides.size() >= 2,
			"every mounted target went on the same wall (%s): the rule "
			% str(sides.keys()) + "is not solving both")
	# AND THE SPACE IT CLAIMS IS THE SPACE IT TAKES. `footprints` becomes
	# `occupied` for the next activity in the same room, so a turned
	# target reported at its UNROTATED extents understates its
	# along-wall span by 0.7 m -- which is a second activity placed
	# into the first one.
	var claimed: Array = (probe["built"] as Dictionary)["footprints"]
	_check(claimed.size() == elements.size(),
			"%d footprints for %d elements"
			% [claimed.size(), elements.size()])
	for i in elements.size():
		var element: ActivityElement = elements[i]
		if not bool(element.get_meta("mounted", false)):
			continue
		var box: AABB = claimed[i]
		_check(box.size.z > box.size.x,
				"a mounted target claims %s: it is turned, so its long "
				% str(box.size) + "axis runs ALONG the wall")
		# ROOM SPACE, like the solver: `_footprint` is built from the
		# element's LOCAL position, and this probe's room sits 600 m out.
		_check(box.has_point(element.position),
				"a mounted target's claimed box %s does not contain it "
				% str(box) + "at %s" % str(element.position))
	(probe["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_a_mounted_target_is_shootable_from_the_lane() -> void:
	"""MOUNTED IS ONLY HALF OF IT. A target flush against a wall that
	no standing player can hit is a worse puzzle than one in the air,
	so this fires the real weapon from the walking lane -- the space
	every builder keeps clear -- rather than from beside the target."""
	var probe := _target_room(2)
	var elements: Array = (probe["built"] as Dictionary)["elements"]
	var player := Player.create()
	add_child(player)
	await _physics(2)
	# COUNTED AT THE MOMENT THE SHOT LANDS, not by reading `is_set`
	# afterwards. The last target of a `target_challenge` COMPLETES the
	# activity, which resets every element -- so the shot that finished
	# the puzzle read as the one shot that missed.
	var landed := {}
	for raw_e: Variant in elements:
		var e: ActivityElement = raw_e
		e.triggered.connect(func(who: ActivityElement) -> void:
			landed[who.get_instance_id()] = true)
	var hit := 0
	for raw: Variant in elements:
		var element: ActivityElement = raw
		if not bool(element.get_meta("mounted", false)):
			continue
		# ON THE CENTRE LINE, at the target's own depth: a place the
		# room guarantees is walkable and where a player would stand.
		player.global_position = MOUNT_PROBE_AT \
				+ Vector3(0.0, 0.1, element.position.z)
		await _physics(12)                       # settle onto the floor
		_check(player.is_on_floor(),
				"the firing position for %s is not on the floor: a shot "
				% element.name + "taken while falling proves nothing")
		player.camera.look_at(element.global_position, Vector3.UP)
		player._fire_static_pulse()
		# LONG ENOUGH FOR THE WEAPON. `STATIC_PULSE_COOLDOWN` is a third
		# of a second; four frames between shots meant the second target
		# was never fired at, and the control read that as a target that
		# could not be hit.
		await _physics(30)
		if landed.has(element.get_instance_id()):
			hit += 1
			real_shots_landed += 1
	_check(hit == elements.size(),
			"%d of %d wall-mounted targets could be shot from the "
			% [hit, elements.size()] + "walking lane with the Static "
			+ "Pulse")
	player.queue_free()
	(probe["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_a_blocked_shot_is_a_blocked_shot() -> void:
	"""THE COUNTERPART, so the check above can fail for the right
	reason. Put a slab between the lane and the wall and the same shot
	must NOT register -- otherwise 'shootable from the lane' is a
	property of the test rather than of the room."""
	var probe := _target_room(1)
	var elements: Array = (probe["built"] as Dictionary)["elements"]
	var element: ActivityElement = elements[0]
	var root: Node3D = probe["root"]
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 4.0, 6.0)
	shape.shape = box
	slab.add_child(shape)
	root.add_child(slab)
	slab.global_position = MOUNT_PROBE_AT + Vector3(
			element.position.x * 0.5, element.position.y,
			element.position.z)
	var player := Player.create()
	add_child(player)
	await _physics(2)
	player.global_position = MOUNT_PROBE_AT \
			+ Vector3(0.0, 0.1, element.position.z)
	await _physics(12)
	player.camera.look_at(element.global_position, Vector3.UP)
	player._fire_static_pulse()
	await _physics(2)
	_check(not element.is_set,
			"a shot through a 4 m slab reached the target, so the "
			+ "shootability check above proves nothing")
	player.queue_free()
	root.queue_free()
	await get_tree().process_frame

func _test_a_wall_with_no_room_declines_the_mount() -> void:
	"""NO LEGAL MOUNTING POSITION IS A PLACEMENT OUTCOME.

	A room whose side walls are entirely doorway and threshold has no
	span to hang anything on. The offer is declined, the flat solve
	stands, and -- the part that matters -- every element asked for is
	still built. An activity that silently lost a required element
	would be a Zone that cannot be finished."""
	# Shallow enough that `THRESHOLD_CLEARANCE` at both ends and the
	# doorway bar in the middle leave nothing between them.
	var probe := _target_room(3, 20.0, 5.0)
	var elements: Array = (probe["built"] as Dictionary)["elements"]
	_check(elements.size() == 3,
			"a room with no mountable wall built %d of 3 elements"
			% elements.size())
	var mounted := 0
	for raw: Variant in elements:
		if bool((raw as ActivityElement).get_meta("mounted", false)):
			mounted += 1
	_check(mounted == 0,
			"%d target(s) were mounted on a wall that is all doorway"
			% mounted)
	(probe["root"] as Node3D).queue_free()
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
	if build.has("failed"):
		_check(false, "the activity Zone could not be laid out: %s"
				% str(build["failed"]))
		return
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
	if build.has("failed"):
		_check(false, "the activity Zone could not be laid out: %s"
				% str(build["failed"]))
		return
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

# --- playtest labelling -------------------------------------------------

func _labels_of(runtime: ActivityRuntime) -> Array[Label3D]:
	var out: Array[Label3D] = []
	for child in runtime.get_children():
		if child is Label3D:
			out.append(child as Label3D)
	return out

func _test_every_activity_says_what_it_is_before_you_touch_it() -> void:
	"""The label is a playtest crutch and it has to be there when it is
	needed: BEFORE the first attempt, when the player is deciding whether
	this object is gameplay at all. It used to appear only once an
	attempt had started, which is after the question."""
	for kind: String in ActivityRuntime.RULES:
		var host := Node3D.new()
		add_child(host)
		var built := Activities.build(host, {
			"kind": kind, "element_count": 3,
		}, "concrete_facility", 24.0, 22.0, "c1", "%s_lab" % kind)
		var runtime := (built as Dictionary)["runtime"] as ActivityRuntime
		var shown := ""
		for label in _labels_of(runtime):
			if label.visible:
				shown += label.text
		_check(shown != "", "a '%s' says nothing at rest" % kind)
		_check(shown.to_upper().contains(
				kind.replace("_", " ").to_upper()),
				"a '%s' does not name its family: '%s'" % [kind, shown])
		if kind == "timed_run":
			_check(shown.contains("START") and shown.contains("GOAL"),
					"a timed_run does not tag its start and goal: '%s'"
					% shown)
		host.queue_free()
		await get_tree().process_frame

func _test_the_labels_can_be_turned_off() -> void:
	"""And they must come off. The graybox silhouettes are supposed to
	carry family identity on their own, so a label nobody can hide makes
	"can you tell these apart" permanently unanswerable."""
	var host := Node3D.new()
	add_child(host)
	var built := Activities.build(host, {
		"kind": "timed_run", "element_count": 3,
	}, "concrete_facility", 24.0, 22.0, "c1", "toggle")
	var runtime := (built as Dictionary)["runtime"] as ActivityRuntime
	runtime.set_labels_visible(false)
	for label in _labels_of(runtime):
		_check(not label.visible, "a label survived being switched off")
	runtime.set_labels_visible(true)
	var back := 0
	for label in _labels_of(runtime):
		if label.visible:
			back += 1
	_check(back > 0, "labels did not come back on")
	host.queue_free()
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
