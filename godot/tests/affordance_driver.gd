extends Node
## The S9 suite (`make godot-affordance`): world affordances, local
## rewards and the Info readouts.
##
## Three things are being defended, and each has a way of failing quietly:
##
## * **I4** — a feature never sits on the mandatory path. Quiet failure: a
##   generator asks for the middle of the corridor and a bounce pad
##   appears in the doorway. Swept over the whole fraction space rather
##   than spot-checked, because the bad case is a corner of it.
## * **I12/§13.1** — a feature the campaign cannot use is worse than
##   nothing. Quiet failure: the panel breaks to a Static Pulse, so the
##   capability that was supposed to pay for it never mattered.
## * **§14.1/§14.2** — a readout only ever tells you about the world, and
##   a payoff is never Archipelago's. Quiet failures: a readout that
##   nudges the thing it reports on, or a pickup that sends an intent with
##   a location id in it.
##
## Boots the real project like the other contract suites — the volumes
## write into the player's physics step, so a `--script` run with no
## autoloads and no physics would prove nothing.

const DT := 1.0 / 60.0

var failures := 0
## Vacuity guards. A suite that built nothing would otherwise sail through
## every "nothing bad happened" assertion below.
var features_built := 0
var volume_frames := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	BridgeClient.snapshot = _snapshot()
	BridgeClient.sent_intents.clear()

	_features_stay_out_of_the_lane()
	await _the_seven_are_built()
	await _a_bounce_pad_beats_a_jump()
	await _water_slows_you_but_cannot_trap_you()
	await _wind_only_lifts()
	await _a_volume_freed_under_you_lets_go()
	await _the_panel_needs_a_real_hit()
	await _a_moving_platform_comes_back()
	await _a_local_reward_reports_itself_once()
	await _pull_pickup_cannot_reach_an_ap_reward()
	await _readouts_only_show_what_is_owned()
	await _readouts_change_nothing()
	_the_suite_actually_exercised_something()

	if failures == 0:
		print("GODOT AFFORDANCE TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT AFFORDANCE TESTS: %d failures" % failures)
		get_tree().quit(1)

# --- I4: the walking lane --------------------------------------------------

## The whole fraction space, at several room widths. `resolve_position` is
## the only thing standing between "Epsilon picked 0.5, 0.5" and a feature
## in the doorway, so it is swept rather than sampled.
func _features_stay_out_of_the_lane() -> void:
	var lane := AffordanceFeatures.LANE_HALF_WIDTH
	var checked := 0
	var narrowest := INF
	# A room narrower than lane + clearance either side has no "beside the
	# path" at all, and `place_all` drops its features rather than burying
	# them. Asserted separately below; the sweep covers rooms that fit.
	for width in [4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 16.0, 22.0]:
		if not AffordanceFeatures.fits(width):
			continue
		for depth in [8.0, 12.0, 20.0, 28.0]:
			for ui in range(0, 11):
				for vi in range(0, 11):
					var at := [float(ui) / 10.0, float(vi) / 10.0]
					var p := AffordanceFeatures.resolve_position(
							at, width, depth)
					checked += 1
					narrowest = minf(narrowest, absf(p.x))
					_check_once(absf(p.x) >= lane,
							"a feature at %s in a %.0fm room landed %.2fm "
							% [at, width, p.x] + "from centre, inside the lane")
					# ...and still inside the room, or it is buried in a wall
					# and the lane rule bought nothing.
					_check_once(absf(p.x) <= width / 2.0,
							"a feature at %s escaped a %.0fm room" % [at, width])
					# Clear of both doorways.
					_check_once(p.z >= 2.0 and p.z <= depth - 2.0
							or depth < 6.0,
							"a feature at %s sat in a threshold" % [at])
	_check(checked > 2000, "the lane sweep covered the fraction space")
	# The sweep must actually PRESS on the bound, or a rule that pushed
	# every feature to the far wall would pass it without protecting
	# anything the lane is for.
	_check(narrowest < lane + 1.0,
			"the sweep never approached the lane edge (nearest %.2f)"
			% narrowest)
	# ...and the narrow rooms the sweep skipped get nothing, rather than a
	# feature squeezed into the doorway or the wall.
	_check(not AffordanceFeatures.fits(4.0),
			"a 4m corridor is all walking lane")
	var cramped := ChamberBuilders.build(
			{"id": "narrow", "type": "corridor", "length": 12.0, "width": 4.0,
			"features": [{"tag": "bounce_pad", "at": [0.5, 0.5]}]},
			"concrete_facility")
	_check((cramped["features"] as Array).is_empty(),
			"a room too narrow for a feature is given none")
	cramped["root"].free()

var _lane_failures := 0

## The sweep is 3000 cases; one bad rule would print 3000 identical lines
## and bury everything after it.
func _check_once(condition: bool, message: String) -> void:
	if condition:
		return
	_lane_failures += 1
	if _lane_failures == 1:
		_check(false, message)

# --- the geometry ----------------------------------------------------------

func _chamber_with(tags: Array) -> Dictionary:
	var features: Array = []
	for i in tags.size():
		features.append({"tag": tags[i],
				"at": [0.2 if i % 2 == 0 else 0.8, 0.4 + 0.1 * i]})
	return {"id": "c1", "type": "arena", "width": 18.0, "depth": 20.0,
			"wall_height": 6.0, "objective": "reach_reward",
			"features": features}

func _build_chamber(tags: Array) -> Dictionary:
	var result := ChamberBuilders.build(_chamber_with(tags), "concrete_facility")
	add_child(result["root"])
	await get_tree().process_frame
	features_built += (result["features"] as Array).size()
	return result

## Every tag in the schema builds something, and every built feature holds
## a LOCAL reward. A tag that silently built nothing would be a validated
## Zone that plays as an empty room.
func _the_seven_are_built() -> void:
	var tags := ["grapple_anchor", "breakable_wall", "water_volume", "rail",
			"wind_volume", "bounce_pad", "moving_platform"]
	for tag: String in tags:
		var result: Dictionary = await _build_chamber([tag])
		var built: Array = result["features"]
		_check(built.size() == 1, "'%s' built exactly one feature" % tag)
		if built.size() == 1:
			_check(str(built[0].get_meta("affordance_tag", "")) == tag,
					"'%s' tagged its node" % tag)
		var rewards := _descendants_in_group(result["root"],
				LocalRewardPickup.GROUP)
		_check(rewards.size() >= 1, "'%s' offers a local reward" % tag)
		# I13, structurally: what a feature holds is never an AP reward.
		_check(_descendants_of_type(result["root"], "RewardObject").is_empty(),
				"'%s' hung no AP reward" % tag)
		result["root"].queue_free()
		await get_tree().process_frame

func _a_bounce_pad_beats_a_jump() -> void:
	var pad := AffordanceNodes.BouncePad.new()
	add_child(pad)
	var player := Player.create()
	add_child(player)
	await get_tree().process_frame
	pad.launch(player)
	_check(player.velocity.y > Constants.JUMP_VELOCITY,
			"a bounce pad sends you higher than a jump (%.1f vs %.1f)"
			% [player.velocity.y, Constants.JUMP_VELOCITY])
	_check(pad.launched == 1, "the pad counted its launch")
	pad.queue_free()
	player.queue_free()
	await get_tree().process_frame

## Water slows and sinks you slowly. What it must never do is hold you: the
## speed floor is the structural half of "the base kit is always enough",
## and a volume able to pin you would make §13.2 alone insufficient.
func _water_slows_you_but_cannot_trap_you() -> void:
	var player := Player.create()
	add_child(player)
	await get_tree().process_frame
	player.enter_volume(self, {
		"gravity_scale": 0.22, "speed_scale": 0.62, "drag": 2.4,
		"terminal_fall": 3.5})
	var wet := player.environment_influence()
	volume_frames += 1
	_check(float(wet["speed_scale"]) < 1.0, "water slows you")
	_check(float(wet["gravity_scale"]) < 1.0, "water floats you")

	# The floor, pressed from below: a volume asking for zero still leaves
	# you able to walk out.
	player.exit_volume(self)
	player.enter_volume(self, {"speed_scale": 0.0, "drag": 999.0})
	var crushing := player.environment_influence()
	_check(float(crushing["speed_scale"]) >= Player.MIN_VOLUME_SPEED_SCALE,
			"a volume cannot slow you below the floor (got %.2f)"
			% crushing["speed_scale"])
	_check(float(crushing["drag"]) <= Player.MAX_VOLUME_DRAG,
			"a volume cannot damp you past the cap")
	# And a volume can never pull you DOWN: lift is upward-only, so no
	# feature can hold a player under.
	player.exit_volume(self)
	player.enter_volume(self, {"lift": -50.0})
	_check(float(player.environment_influence()["lift"]) >= 0.0,
			"lift is upward-only")
	player.exit_volume(self)
	_check(player.environment_influence()["speed_scale"] == 1.0,
			"leaving a volume restores you exactly")
	player.queue_free()
	await get_tree().process_frame

## The SHIPPED updraft, not a plausible one written here: lift has to beat
## the gravity the same volume applies, and a test with its own numbers
## would happily pass while the real column let you sink.
func _wind_only_lifts() -> void:
	var result: Dictionary = await _build_chamber(["wind_volume"])
	var column: AffordanceNodes.Volume = (result["features"] as Array)[0]
	var player := Player.create()
	add_child(player)
	await get_tree().process_frame
	player.global_position = Vector3(0, 40, 0)
	var before := player.global_position.y
	player.enter_volume(self, column.influence)
	for i in 40:
		player._physics_process(DT)
		volume_frames += 1
	_check(player.global_position.y > before,
			"an updraft carries you up (%.2f -> %.2f)"
			% [before, player.global_position.y])
	player.exit_volume(self)
	player.queue_free()
	result["root"].queue_free()
	await get_tree().process_frame

## A volume freed while you are standing in it must let go. Without the
## release, the influence would outlive the geometry — a Zone teardown
## would leave the player permanently swimming.
func _a_volume_freed_under_you_lets_go() -> void:
	var player := Player.create()
	add_child(player)
	var volume := AffordanceNodes.Volume.new()
	volume.influence = {"speed_scale": 0.5}
	volume.extents = Vector3(6, 6, 6)
	add_child(volume)
	await get_tree().process_frame
	player.global_position = volume.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var inside := float(player.environment_influence()["speed_scale"]) < 1.0
	_check(inside, "the volume noticed the player standing in it")
	volume.queue_free()
	await get_tree().process_frame
	_check(float(player.environment_influence()["speed_scale"]) == 1.0,
			"a freed volume releases its influence")
	player.queue_free()
	await get_tree().process_frame

## §13.1 pays for `breakable_wall` with "an owned action that can deal
## impact damage at or above a threshold". If the base kit opened it, that
## requirement would be a fiction and the affordance would be free.
func _the_panel_needs_a_real_hit() -> void:
	var panel := AffordanceNodes.BreakablePanel.new()
	add_child(panel)
	await get_tree().process_frame
	for i in 20:
		panel.take_damage(Constants.STATIC_PULSE_DAMAGE)
	_check(is_instance_valid(panel) and not panel.is_queued_for_deletion(),
			"twenty Static Pulses do not open a breakable wall")
	_check(panel.hp == AffordanceNodes.BreakablePanel.HP,
			"a refused hit chips nothing")
	_check(panel.refused == 20, "the panel reported every refusal")
	var heavy := AffordanceNodes.BreakablePanel.MIN_IMPACT + 1.0
	var opened := false
	for i in 20:
		if not is_instance_valid(panel) or panel.is_queued_for_deletion():
			opened = true
			break
		opened = panel.take_damage(heavy) or opened
	_check(opened, "a heavy enough hit opens it")
	await get_tree().process_frame

## Deterministic and closed: two runs of the same length put it in the same
## place, and a full period returns it to where it started. A platform
## whose loop drifted would eventually be inside the floor.
func _a_moving_platform_comes_back() -> void:
	var platform := AffordanceNodes.MovingPlatform.new()
	platform.travel = Vector3(0, 3.0, 0)
	add_child(platform)
	await get_tree().process_frame
	# `phase` rather than `position`: `sync_to_physics` makes the latter a
	# read of the physics server, so a hand-stepped loop would sample a
	# transform the server has not been asked to update yet.
	var highest := platform.phase
	var steps := int(AffordanceNodes.MovingPlatform.PERIOD / DT)
	for i in steps:
		platform.advance(DT)
		highest = maxf(highest, platform.phase)
	_check(absf(platform.phase) < 0.01,
			"a full period returns the platform to its origin (%.3f)"
			% platform.phase)
	_check(highest > 0.95, "it reached the far end (%.2f)" % highest)
	# And the body genuinely moves, over real physics frames — `phase`
	# alone would pass on a platform whose transform was never written.
	platform.elapsed = 0.0
	var started := platform.global_position.y
	for i in 12:
		await get_tree().physics_frame
	_check(platform.global_position.y > started,
			"the body itself moves (%.2f -> %.2f)"
			% [started, platform.global_position.y])
	platform.queue_free()
	await get_tree().process_frame

# --- §14.2: local rewards --------------------------------------------------

func _a_local_reward_reports_itself_once() -> void:
	BridgeClient.sent_intents.clear()
	var pickup := LocalRewardPickup.create(
			"epsilon_note", "c1_rail_0", "Note", "text")
	add_child(pickup)
	await get_tree().process_frame
	pickup.collect()
	pickup.collect()                       # a pull and a walk-over, same frame
	var grants := _intents_of_type("grant_local_reward")
	_check(grants.size() == 1,
			"collecting twice reports once (got %d)" % grants.size())
	if grants.size() >= 1:
		var intent: Dictionary = grants[0]
		_check(str(intent.get("kind", "")) in LocalRewardPickup.KINDS,
				"the reward kind is in the §14.2 catalog")
		# I13: there is no field here that could name AP truth. Asserted on
		# the wire rather than trusted from the schema, because the client
		# is what builds this dictionary.
		for forbidden: String in ["location_id", "item_name", "check",
				"echo_id", "coin", "signal_key"]:
			_check(not intent.has(forbidden),
					"a local reward intent carries no '%s'" % forbidden)
	await get_tree().process_frame

## `pull_pickup` reaches local rewards and nothing else. An AP reward is
## claimed by walking up and interacting; a verb that could yank one across
## a room would be an Action moving Check truth.
func _pull_pickup_cannot_reach_an_ap_reward() -> void:
	var player := Player.create()
	add_child(player)
	await get_tree().process_frame
	player.global_position = Vector3.ZERO

	var pickup := LocalRewardPickup.create("flavor_log", "c1_note", "Note")
	add_child(pickup)
	var ap_reward := RewardObject.create(
			89100001, "zone_001", "concrete_facility")
	add_child(ap_reward)
	await get_tree().process_frame
	pickup.global_position = Vector3(4, 0.5, 0)
	ap_reward.global_position = Vector3(4, 0.5, 2)
	var reward_before := ap_reward.global_position

	var runtime: EchoRuntime = player.runtimes["echo_a"]
	runtime._pull_pickup({"type": "pull_pickup", "radius": 8.0})
	_check(pickup.global_position.distance_to(player.global_position) < 4.0,
			"pull_pickup drew the local reward in")
	_check(ap_reward.global_position == reward_before,
			"pull_pickup did not move the AP reward")
	pickup.queue_free()
	ap_reward.queue_free()
	player.queue_free()
	await get_tree().process_frame

# --- §14.1: readouts -------------------------------------------------------

func _readouts_only_show_what_is_owned() -> void:
	var readouts := Readouts.new()
	add_child(readouts)
	await get_tree().process_frame
	# The snapshot owns two of the ten.
	readouts.refresh()
	_check(readouts.has("speedometer"), "an owned readout is on")
	_check(readouts.has("damage_numbers"), "an owned readout is on")
	for readout: String in Readouts.READOUTS:
		if readout in ["speedometer", "damage_numbers"]:
			continue
		_check(not readouts.has(readout),
				"'%s' is off until it is owned" % readout)
	readouts.queue_free()
	await get_tree().process_frame

## The §14.1 promise, asserted rather than remembered: a readout tells you
## about the world and never touches it. Run over a live frame with an
## enemy, a pickup and a player, then compare everything either side.
func _readouts_change_nothing() -> void:
	var player := Player.create()
	add_child(player)
	var enemy := Enemy.create("melee", "concrete_facility")
	add_child(enemy)
	var pickup := LocalRewardPickup.create("flavor_log", "c1_watch", "Note")
	add_child(pickup)
	var readouts := Readouts.new()
	add_child(readouts)
	await get_tree().process_frame
	readouts.bind(player)
	readouts.refresh()
	# Everything except the readouts is stopped. Otherwise the enemy walks
	# toward the player and the player falls under gravity, and "readouts
	# changed nothing" would fail on things the readouts never touched —
	# or worse, pass by coincidence once the numbers happened to line up.
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	pickup.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = Vector3(0, 0, 6)
	pickup.global_position = Vector3(2, 0.5, 3)
	player.global_position = Vector3.ZERO
	BridgeClient.sent_intents.clear()

	var before := {
		"enemy_hp": enemy.hp,
		"enemy_at": enemy.global_position,
		"pickup_at": pickup.global_position,
		"player_hp": player.hp,
		"player_at": player.global_position,
		"player_velocity": player.velocity,
	}
	for i in 20:
		readouts._process(DT)
	# The drawing half too: `_draw` is where every readout reads the world,
	# so a readout that nudged something would most likely do it there.
	readouts.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame

	_check(enemy.hp == before["enemy_hp"], "readouts left enemy hp alone")
	_check(enemy.global_position == before["enemy_at"],
			"readouts left the enemy where it was")
	_check(pickup.global_position == before["pickup_at"],
			"readouts did not pull a pickup")
	_check(player.hp == before["player_hp"], "readouts left player hp alone")
	_check(player.global_position == before["player_at"],
			"readouts did not move the player")
	_check(player.velocity == before["player_velocity"],
			"readouts did not push the player")
	_check(BridgeClient.sent_intents.is_empty(),
			"readouts sent no intents (got %d)"
			% BridgeClient.sent_intents.size())

	# ...and it was actually watching: hurt the enemy and the damage
	# readout must notice, or every assertion above passed on a dead
	# overlay.
	enemy.take_damage(7.0, Vector3.FORWARD, 0.0)
	readouts._process(DT)
	_check(readouts._damage_numbers.size() > 0,
			"the damage readout noticed a hit it never asked for")

	readouts.queue_free()
	enemy.queue_free()
	pickup.queue_free()
	player.queue_free()
	await get_tree().process_frame

# --- helpers ---------------------------------------------------------------

func _the_suite_actually_exercised_something() -> void:
	_check(features_built >= 7, "the suite built every affordance (%d)"
			% features_built)
	_check(volume_frames > 30, "the suite ran volumes over live frames (%d)"
			% volume_frames)

func _intents_of_type(type: String) -> Array:
	var out: Array = []
	for intent: Dictionary in BridgeClient.sent_intents:
		if str(intent.get("type", "")) == type:
			out.append(intent)
	return out

func _descendants_in_group(root: Node, group: String) -> Array:
	var out: Array = []
	if root.is_in_group(group):
		out.append(root)
	for child in root.get_children():
		out.append_array(_descendants_in_group(child, group))
	return out

func _descendants_of_type(root: Node, type_name: String) -> Array:
	var out: Array = []
	if root.get_script() != null \
			and str(root.get_script().get_global_name()) == type_name:
		out.append(root)
	for child in root.get_children():
		out.append_array(_descendants_of_type(child, type_name))
	return out

func _snapshot() -> Dictionary:
	var owned: Array = []
	var provenance := [{"interpretation_seq": 0,
			"source_location_id": 89100001, "source_item_name": "Item",
			"source_game": "Some Game", "source_recipient_name": "P",
			"operation": "create", "note": "n"}]
	owned.append({"component": {
		"kind": "action", "component_id": "act_gun", "display_name": "GUN",
		"description": "d", "slot": "echo_a", "cooldown": 1.0,
		"primitive": {"type": "hitscan_damage", "damage": 9.0, "pellets": 1,
				"spread_degrees": 1.0, "range": 30.0},
		"modifiers": []}, "mk": 1, "provenance": provenance})
	# Two of the ten readouts, so "only what is owned" has both halves.
	for readout: String in ["speedometer", "damage_numbers"]:
		owned.append({"component": {
			"kind": "info", "component_id": "info_%s" % readout,
			"display_name": readout.to_upper(), "description": "d",
			"readout": readout}, "mk": 1, "provenance": provenance})
	return {
		"type": "campaign_snapshot",
		"mechanics": {"owned": owned, "aliases": [], "links": [],
				"channel_order": []},
		"slots": {"echo_a": "act_gun", "echo_b": null, "mobility": null,
				"utility": null},
		"interpretations": [],
		"checked_location_ids": [],
	}
