extends Node
## The S5/S7 loadout suite (`make godot-stats`): invariant **I3**
## plus the pieces it depends on — `scaled_by`, `scales` links,
## `requires_equipped`, `trait_pulse`, status factors, and the
## StatusEffects container's own rules.
##
## I3's sweep builds hundreds of RANDOM legal trait stacks (seeded, so the
## sweep is deterministic) and holds the floors: no combination of traits,
## links, statuses and pulses may leave a traversal stat under base or any
## stat outside its envelope. `max_safe_gap` itself is a Python constant
## pinned by the schema suite; what the client owes is that nothing here
## ever needs it recomputed.

const DT := 1.0 / 60.0

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	_i3_sweep()
	_scaled_by_interpolates()
	_scales_link_interpolates()
	_requires_equipped_gates_the_trait()
	_pulses_decay_and_respect_floors()
	_status_container_rules()
	_status_stat_factors()
	_a_magnitude_never_outlives_the_duration_it_came_with()
	_cleanse_is_aimed_at_what_this_side_suffers()
	_an_unknown_status_kind_is_refused()
	_link_semantics()
	_slots_are_independent()
	_favourites_narrow_the_wheel()
	if failures == 0:
		print("GODOT STATS TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT STATS TESTS: %d failures" % failures)
		get_tree().quit(1)

func _trait(stat: String, multiplier: float, scaled_by: Variant = null,
		requires: Variant = null, cid := "trait_x") -> Dictionary:
	return {"component": {"kind": "trait", "component_id": cid,
			"display_name": "T", "description": "t", "stat": stat,
			"multiplier": multiplier, "scaled_by": scaled_by,
			"requires_equipped": requires}}

func _snapshot(traits: Array, links: Array = [],
		slots: Dictionary = {}) -> void:
	var owned: Array = [{"component": {
		"kind": "resource", "component_id": "res_fuel",
		"display_name": "FUEL", "description": "f", "max_value": 100.0,
		"initial_fraction": 0.5, "regen_per_second": 0.0,
		"regen_delay": 0.0, "presentation": "bar",
		"palette_color": "tide", "pip_count": null}}]
	owned.append_array(traits)
	BridgeClient.snapshot = {
		"mechanics": {"owned": owned, "aliases": [], "links": links,
				"channel_order": ["res_fuel"]},
		"slots": {"echo_a": slots.get("echo_a"), "echo_b": null,
				"mobility": null, "utility": null},
	}

func _stack(with_pool := true) -> StatStack:
	var stack := StatStack.new()
	if with_pool:
		var pool := ResourcePool.new()
		pool.reset_for_zone()
		stack.pool = pool
	return stack

## Legal per the schema's own validators: traversal non-gravity in
## [1, 4], gravity in [0.1, 1], everything else in [0.1, 4].
func _random_legal_trait(rng: RandomNumberGenerator, index: int) -> Dictionary:
	var stat: String = StatStack.STATS[rng.randi_range(0,
			StatStack.STATS.size() - 1)]
	var multiplier: float
	if stat == "gravity":
		multiplier = rng.randf_range(0.1, 1.0)
	elif stat in StatStack.TRAVERSAL:
		multiplier = rng.randf_range(1.0, 4.0)
	else:
		multiplier = rng.randf_range(0.1, 4.0)
	var scaled: Variant = [null, "hp_fraction", "hp_inverse",
			"res_fuel"][rng.randi_range(0, 3)]
	var requires: Variant = null if rng.randf() < 0.7 else \
			(["act_slotted", "act_missing"][rng.randi_range(0, 1)])
	return _trait(stat, multiplier, scaled, requires,
			"trait_%d" % index)

func _i3_sweep() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 89100001
	var worst_speed := INF
	for round in 300:
		var traits: Array = []
		for i in rng.randi_range(1, 8):
			traits.append(_random_legal_trait(rng, i))
		_snapshot(traits, [], {"echo_a": "act_slotted"})
		var stack := _stack()
		stack.hp_fraction = rng.randf()
		if rng.randf() < 0.4:
			stack.statuses = StatusEffects.new()
			stack.statuses.apply(["haste", "slowed", "frozen", "empowered",
					"vulnerable"][rng.randi_range(0, 4)], 5.0,
					rng.randf_range(0.05, 3.0))
		if rng.randf() < 0.3:
			stack.add_pulse(StatStack.STATS[rng.randi_range(0, 8)],
					rng.randf_range(0.1, 4.0), 5.0)
		var stats := stack.evaluate()
		for stat: String in ["move_speed", "jump_height", "air_control"]:
			_check(float(stats[stat]) >= 1.0,
					"round %d: %s fell under base (%f)"
					% [round, stat, stats[stat]])
		_check(float(stats["gravity"]) <= 1.0
				and float(stats["gravity"])
				>= float(Constants.GRAVITY_MULT_MIN),
				"round %d: gravity outside [min, 1]" % round)
		_check(float(stats["move_speed"])
				<= float(Constants.SPEED_MULT_MAX),
				"round %d: speed over the derivation cap" % round)
		for stat: String in ["ground_friction", "damage_dealt",
				"damage_taken", "knockback_resist", "regen"]:
			_check(float(stats[stat]) >= float(Constants.STAT_STACK_MIN)
					and float(stats[stat])
					<= float(Constants.STAT_STACK_MAX),
					"round %d: %s outside the envelope (%f)"
					% [round, stat, stats[stat]])
		worst_speed = minf(worst_speed, float(stats["move_speed"]))
	# Vacuity guard: the sweep must have genuinely pressed the floor.
	_check(is_equal_approx(worst_speed, 1.0),
			"the sweep reached the floor at least once (worst %f)"
			% worst_speed)

func _scaled_by_interpolates() -> void:
	_snapshot([_trait("move_speed", 2.0, "res_fuel")])
	var stack := _stack()
	var stats := stack.evaluate()
	_check(is_equal_approx(float(stats["move_speed"]), 1.5),
			"a trait scaled by a half-full resource lands halfway (%f)"
			% stats["move_speed"])
	_snapshot([_trait("damage_dealt", 2.0, "hp_inverse")])
	stack = _stack(false)
	stack.hp_fraction = 0.25
	stats = stack.evaluate()
	_check(is_equal_approx(float(stats["damage_dealt"]), 1.75),
			"hp_inverse is how Berserker works (%f)" % stats["damage_dealt"])

func _scales_link_interpolates() -> void:
	_snapshot([_trait("damage_dealt", 3.0, null, null, "trait_momentum")],
			[{"link": "scales", "source": "res_fuel",
			"target": "trait_momentum", "strength": 1.0}])
	var stack := _stack()
	_check(is_equal_approx(float(stack.evaluate()["damage_dealt"]), 2.0),
			"a scales link interpolates the trait with the fraction")
	_snapshot([_trait("damage_dealt", 3.0, null, null, "trait_momentum")],
			[{"link": "scales", "source": "res_fuel",
			"target": "trait_momentum", "strength": 2.0}])
	stack = _stack()
	_check(is_equal_approx(float(stack.evaluate()["damage_dealt"]), 3.0),
			"strength scales the fraction, clamped at full effect")

func _requires_equipped_gates_the_trait() -> void:
	var iron := _trait("ground_friction", 0.3, null, "act_boots")
	_snapshot([iron])
	var stack := _stack(false)
	_check(is_equal_approx(float(stack.evaluate()["ground_friction"]), 1.0),
			"a requires_equipped trait sleeps while its Action is unslotted")
	_snapshot([iron], [], {"echo_a": "act_boots"})
	_check(is_equal_approx(float(stack.evaluate()["ground_friction"]), 0.3),
			"...and bites while it is slotted — severe means removable")

func _pulses_decay_and_respect_floors() -> void:
	_snapshot([])
	var stack := _stack(false)
	stack.add_pulse("damage_dealt", 2.0, 1.0)
	_check(is_equal_approx(float(stack.evaluate()["damage_dealt"]), 2.0),
			"a live pulse multiplies its stat")
	for i in 72:
		stack.tick(DT)
	_check(is_equal_approx(float(stack.evaluate()["damage_dealt"]), 1.0),
			"an expired pulse is gone")
	stack.add_pulse("move_speed", 0.5, 1.0)
	_check(float(stack.evaluate()["move_speed"]) >= 1.0,
			"a pulse cannot take a traversal stat under base")

func _status_container_rules() -> void:
	_snapshot([])
	var statuses := StatusEffects.new()
	statuses.side = "self"
	statuses.apply("burning", 2.0, 1.0)
	_check(is_equal_approx(statuses.dot_per_second(), 4.0),
			"burning burns")
	statuses.apply("burning", 1.0, 0.5)
	_check(is_equal_approx(statuses.magnitude_of("burning"), 1.0),
			"re-application max-merges, never stacks")
	statuses.apply("poisoned", 5.0, 1.0)
	statuses.apply("slowed", 5.0, 1.0)
	var removed := statuses.cleanse(2)
	_check(removed == 2 and not statuses.has("burning")
			and not statuses.has("poisoned") and statuses.has("slowed"),
			"cleanse removes worst-first")
	statuses.apply("marked", 0.5, 1.0)
	for i in 40:
		statuses.tick(DT)
	_check(not statuses.has("marked"), "statuses expire")

	# An owned StatusComponent is a floor for its kind on its side.
	BridgeClient.snapshot = {"mechanics": {"owned": [{"component": {
			"kind": "status", "component_id": "status_hotter",
			"display_name": "Hotter", "description": "h",
			"status": "burning", "target": "enemy", "duration": 6.0,
			"magnitude": 2.0}}], "aliases": [], "links": [],
			"channel_order": []}, "slots": {}}
	var enemy_side := StatusEffects.new()
	enemy_side.side = "enemy"
	enemy_side.apply("burning", 1.0, 0.5)
	_check(is_equal_approx(enemy_side.magnitude_of("burning"), 2.0),
			"an owned status definition floors applications of its kind")
	var self_side := StatusEffects.new()
	self_side.side = "self"
	self_side.apply("burning", 1.0, 0.5)
	_check(is_equal_approx(self_side.magnitude_of("burning"), 0.5),
			"...on its own side only")

func _status_stat_factors() -> void:
	_snapshot([])
	var stack := _stack(false)
	stack.statuses = StatusEffects.new()
	stack.statuses.apply("haste", 5.0, 0.5)
	_check(is_equal_approx(float(stack.evaluate()["move_speed"]), 1.5),
			"haste quickens")
	stack.statuses = StatusEffects.new()
	stack.statuses.apply("slowed", 5.0, 1.0)
	var stats := stack.evaluate()
	_check(float(stats["move_speed"]) >= 1.0,
			"a self-slow may not touch move_speed (§10)")
	_check(float(stats["ground_friction"]) < 1.0,
			"...it expresses as slippery control instead")
	stack.statuses = StatusEffects.new()
	stack.statuses.apply("vulnerable", 5.0, 1.0)
	_check(is_equal_approx(float(stack.evaluate()["damage_taken"]), 1.5),
			"vulnerable raises damage taken")


# --- §4: the four link kinds, at the runner's own helpers -----------------

func _linked_snapshot(links: Array) -> ResourcePool:
	BridgeClient.snapshot = {
		"mechanics": {"owned": [{"component": {
			"kind": "resource", "component_id": "res_fuel",
			"display_name": "FUEL", "description": "f", "max_value": 100.0,
			"initial_fraction": 0.5, "regen_per_second": 0.0,
			"regen_delay": 0.0, "presentation": "bar",
			"palette_color": "tide", "pip_count": null}}],
			"aliases": [], "links": links, "channel_order": ["res_fuel"]},
		"slots": {"echo_a": "act_x", "echo_b": null, "mobility": null,
				"utility": null},
	}
	var pool := ResourcePool.new()
	pool.reset_for_zone()
	return pool

func _runner(pool: ResourcePool, primitive: Dictionary) -> EchoRuntime:
	var runtime := EchoRuntime.new()
	runtime.pool = pool
	runtime.equipped = {"component_id": "act_x", "display_name": "X",
			"cooldown": 1.0, "primitive": primitive, "modifiers": []}
	return runtime

## `powers` and `fills` are opposite directions on purpose (§4), and the
## fold serializes the kind under `link`, not `kind`. Both were wrong in
## the S3 HUD code and unreachable until now.
func _link_semantics() -> void:
	# gates: below the threshold the press is refused, above it opens.
	var pool := _linked_snapshot([{"link": "gates", "source": "res_fuel",
			"target": "act_x", "strength": 0.8}])
	var runtime := _runner(pool, {"type": "dash", "force": 12.0})
	_check(not runtime._gates_open(),
			"a gates link withholds the action below its threshold")
	pool.refill("res_fuel", 40.0)
	_check(runtime._gates_open(), "...and opens it at or above")
	runtime.free()

	# gates above 1.0 reads as absolute units rather than a fraction.
	pool = _linked_snapshot([{"link": "gates", "source": "res_fuel",
			"target": "act_x", "strength": 70.0}])
	runtime = _runner(pool, {"type": "dash", "force": 12.0})
	_check(not runtime._gates_open(), "a strength over 1 is absolute units")
	runtime.free()

	# powers: a press verb pays strength, all or nothing.
	pool = _linked_snapshot([{"link": "powers", "source": "res_fuel",
			"target": "act_x", "strength": 20.0}])
	runtime = _runner(pool, {"type": "dash", "force": 12.0})
	_check(runtime._pay_powers_cost(), "an affordable press pays")
	_check(is_equal_approx(pool.value_of("res_fuel"), 30.0),
			"...exactly its strength")
	pool.spend("res_fuel", 25.0)
	_check(not runtime._pay_powers_cost(), "an unaffordable press refuses")
	_check(is_equal_approx(pool.value_of("res_fuel"), 5.0),
			"...and takes nothing")
	runtime.free()

	# powers on a DRAIN verb: the press is free, the hold pays per second.
	pool = _linked_snapshot([{"link": "powers", "source": "res_fuel",
			"target": "act_x", "strength": 20.0}])
	runtime = _runner(pool, {"type": "hover", "gravity_multiplier": 0.2,
			"drain_per_second": 30.0, "max_duration": 5.0})
	_check(runtime._pay_powers_cost() and is_equal_approx(
			pool.value_of("res_fuel"), 50.0),
			"a drain verb's press costs nothing up front")
	_check(runtime._drain(1.0) and is_equal_approx(
			pool.value_of("res_fuel"), 20.0),
			"...it pays per second while held")
	_check(not runtime._drain(1.0),
			"...and an empty bar refuses, which ends the hold")
	runtime.free()

	# fills: action → resource, so the SOURCE is the action.
	pool = _linked_snapshot([{"link": "fills", "source": "act_x",
			"target": "res_fuel", "strength": 12.0}])
	runtime = _runner(pool, {"type": "dash", "force": 12.0})
	runtime._apply_fills()
	_check(is_equal_approx(pool.value_of("res_fuel"), 62.0),
			"a fills link refills on use")
	runtime.free()

	# restore_resource names no resource; the link says where, the
	# primitive says how much, and _apply_fills must not double-count it.
	pool = _linked_snapshot([{"link": "fills", "source": "act_x",
			"target": "res_fuel", "strength": 12.0}])
	runtime = _runner(pool, {"type": "restore_resource", "amount": 30.0})
	runtime._restore_resource(runtime._primitive())
	runtime._apply_fills()
	_check(is_equal_approx(pool.value_of("res_fuel"), 80.0),
			"restore_resource fills by its own amount, once (got %f)"
			% pool.value_of("res_fuel"))
	runtime.free()

	# A link pointed at someone else leaves this action alone.
	pool = _linked_snapshot([{"link": "powers", "source": "res_fuel",
			"target": "act_other", "strength": 20.0}])
	runtime = _runner(pool, {"type": "dash", "force": 12.0})
	_check(runtime._pay_powers_cost() and is_equal_approx(
			pool.value_of("res_fuel"), 50.0),
			"another action's powers link costs this one nothing")
	runtime.free()
	pool.free()

# --- S7: four slots, four runtimes, one wheel ------------------------------

func _slot_snapshot() -> void:
	var owned: Array = []
	var slots := {"echo_a": "act_gun", "echo_b": null,
			"mobility": "act_dash", "utility": null}
	for entry in [["act_gun", "echo_a", {"type": "hitscan_damage",
					"damage": 8.0, "pellets": 1, "spread_degrees": 1.0,
					"range": 30.0}],
			["act_dash", "mobility", {"type": "dash", "force": 12.0}],
			["act_blink", "mobility", {"type": "blink", "range": 14.0,
					"clearance": 0.4}],
			["act_heal", "utility", {"type": "heal_self", "amount": 20.0}]]:
		owned.append({"component": {
			"kind": "action", "component_id": entry[0],
			"display_name": str(entry[0]).to_upper(), "description": "d",
			"slot": entry[1], "cooldown": 2.0, "primitive": entry[2],
			"modifiers": []}, "mk": 1, "provenance": []})
	BridgeClient.snapshot = {
		"mechanics": {"owned": owned, "aliases": [], "links": [],
				"channel_order": []},
		"slots": slots, "interpretations": []}

## Cooldowns, held state and airtime budgets belong to the Action, so four
## buttons need four runtimes. One shared runtime would let a dash and a
## shot contend for a single cooldown — the exact bug four slots exist to
## make impossible.
func _slots_are_independent() -> void:
	_slot_snapshot()
	var player := Player.create()
	get_tree().root.add_child(player)
	_check(player.runtimes.size() == Constants.SLOT_NAMES.size(),
			"one runtime per slot (%d)" % player.runtimes.size())
	var seen: Array = []
	for slot: String in Constants.SLOT_NAMES:
		_check(player.runtimes.has(slot), "slot %s has a runtime" % slot)
		var runtime: EchoRuntime = player.runtimes[slot]
		_check(runtime.slot == slot, "%s knows its own slot" % slot)
		_check(not (runtime in seen), "%s's runtime is its own" % slot)
		seen.append(runtime)

	player.runtimes["echo_a"].set_equipped(BridgeClient.slotted_action("echo_a"))
	player.runtimes["mobility"].set_equipped(
			BridgeClient.slotted_action("mobility"))
	_check(str(player.runtimes["echo_a"].equipped.get("component_id", ""))
			== "act_gun", "echo_a holds the Action the fold put there")
	_check(str(player.runtimes["mobility"].equipped.get("component_id", ""))
			== "act_dash", "mobility holds its own, not echo_a's")

	player.runtimes["echo_a"].cooldown_remaining = 2.0
	_check(is_equal_approx(player.runtimes["mobility"].cooldown_remaining, 0.0),
			"a cooldown on one slot leaves the others ready")

	# Shields add up across slots rather than the last one winning.
	player.runtimes["echo_a"].shield_hp = 10.0
	player.runtimes["mobility"].shield_hp = 5.0
	_check(is_equal_approx(player.total_shield(), 15.0),
			"shields from two slots both count (%f)" % player.total_shield())

	# The highlight follows what you fired, and only one slot paints the
	# viewmodel.
	player.set_highlighted_slot("mobility")
	_check(player.echo_runtime == player.runtimes["mobility"],
			"the highlighted slot is the one `echo_runtime` means")
	player.set_highlighted_slot("echo_a")
	_check(player.echo_runtime == player.runtimes["echo_a"],
			"...and it follows the highlight back")

	# Every slot has its own binding, and none of them is the Pulse's.
	var bound: Array = []
	for slot: String in Constants.SLOT_NAMES:
		var action: String = Player.SLOT_ACTIONS.get(slot, "")
		_check(InputMap.has_action(action),
				"%s is bound to a real input action (%s)" % [slot, action])
		_check(not (action in bound), "%s does not share a binding" % slot)
		bound.append(action)
	_check(not ("fire_pulse" in bound),
			"the Static Pulse is not one of the slots")
	player.queue_free()

## The wheel narrows to favourites when at least two are marked, and stays
## whole otherwise — a wheel that cycles nothing until configured reads as
## broken rather than as unconfigured.
func _favourites_narrow_the_wheel() -> void:
	Favourites._reset_for_test()
	var all := ["act_dash", "act_blink", "act_hover"]
	_check(Favourites.cycle_set(all).size() == 3,
			"with nothing marked the wheel cycles everything")
	Favourites.toggle("act_dash")
	_check(Favourites.cycle_set(all).size() == 3,
			"one favourite would cycle to itself, so the full list stays")
	Favourites.toggle("act_blink")
	var starred := Favourites.cycle_set(all)
	_check(starred.size() == 2 and "act_hover" not in starred,
			"two favourites narrow the wheel to them")
	_check(Favourites.is_favourite("act_dash"), "a mark reads back")
	Favourites.toggle("act_dash")
	_check(not Favourites.is_favourite("act_dash"), "and toggles off")
	Favourites._reset_for_test()

## Re-application max-merges, but the two dimensions must merge TOGETHER.
##
## Maxed independently, a feeble long application inherited a brutal short
## one's magnitude and carried it for its whole life: 0.5 s at magnitude 3
## followed by 30 s at magnitude 0.05 gave thirty seconds at 12 damage a
## second, eight times what either application asked for -- from two rule
## effects that are individually schema-legal.
func _a_magnitude_never_outlives_the_duration_it_came_with() -> void:
	_snapshot([])
	var statuses := StatusEffects.new()
	statuses.side = "self"
	statuses.apply("burning", 0.5, 3.0)
	_check(is_equal_approx(statuses.dot_per_second(), 12.0),
			"the fierce one burns fiercely")
	# A feeble thirty-second application arrives before it expires.
	for i in range(int(0.4 / DT)):
		statuses.tick(DT)
	statuses.apply("burning", 30.0, 0.05)
	_check(is_equal_approx(statuses.magnitude_of("burning"), 3.0),
			"the fierce one still runs while it has time left: %f"
			% statuses.magnitude_of("burning"))
	# Five seconds later the fierce one is long gone.
	for i in range(int(5.0 / DT)):
		statuses.tick(DT)
	_check(statuses.has("burning"), "the long one is still running")
	_check(is_equal_approx(statuses.magnitude_of("burning"), 0.05),
			"...at its OWN magnitude, not the one it inherited: %f"
			% statuses.magnitude_of("burning"))
	# And it ends when it should: 0.5 + 30 from the first application.
	for i in range(int(26.0 / DT)):
		statuses.tick(DT)
	_check(not statuses.has("burning"), "the pair ends on time")

	# A weaker, shorter application is entirely contained and changes
	# nothing.
	statuses.apply("slowed", 10.0, 2.0)
	statuses.apply("slowed", 1.0, 0.1)
	_check(is_equal_approx(statuses.magnitude_of("slowed"), 2.0),
			"a weaker shorter application is swallowed whole")

## `cleanse` is only ever aimed at the player, and the old order was
## written as if it were aimed at an enemy: `stunned` and `marked` are read
## by `enemy.gd` and by nothing on the player, so they spent charges on
## nothing while outranking `vulnerable`, which the player does suffer. And
## `low_profile` was in the list at all -- `enemy.gd` reads it as the
## player's stealth, so a cleanse could strip the player's own buff.
func _cleanse_is_aimed_at_what_this_side_suffers() -> void:
	_snapshot([])
	var mine := StatusEffects.new()
	mine.side = "self"
	mine.apply("stunned", 5.0, 1.0)
	mine.apply("vulnerable", 5.0, 1.0)
	var removed := mine.cleanse(1)
	_check(removed == 1 and not mine.has("vulnerable"),
			"one charge removes what the player actually suffers")

	mine.clear()
	mine.apply("low_profile", 5.0, 1.0)
	mine.apply("haste", 5.0, 1.0)
	mine.apply("regenerating", 5.0, 1.0)
	_check(mine.cleanse(3) == 0,
			"a cleanse never strips the player's own buffs")
	_check(mine.has("low_profile"),
			"...low_profile above all, which is stealth, not a debuff")

	# The enemy side keeps the ranks that only enemies read.
	var theirs := StatusEffects.new()
	theirs.side = "enemy"
	theirs.apply("stunned", 5.0, 1.0)
	_check(theirs.cleanse(1) == 1,
			"an enemy can be cleansed of what an enemy suffers")

## The vocabulary is closed and generated from the schema. An unknown kind
## was inert -- nothing reads it -- yet still satisfied `status_active`
## conditions and `status_applied` edges, and could never be cleansed,
## because it is not in any cleanse order.
func _an_unknown_status_kind_is_refused() -> void:
	_snapshot([])
	var statuses := StatusEffects.new()
	statuses.side = "self"
	statuses.apply("on_fire", 5.0, 1.0)
	_check(not statuses.has("on_fire"),
			"a status the schema does not admit is refused, not stored")
	_check(statuses.active_kinds().is_empty(),
			"...and leaves nothing behind: %s" % [statuses.active_kinds()])
	for kind: String in Constants.ECHO_STATUS_KINDS:
		statuses.apply(kind, 1.0, 1.0)
	_check(statuses.active_kinds().size()
			== Constants.ECHO_STATUS_KINDS.size(),
			"every kind the schema DOES admit is accepted")
