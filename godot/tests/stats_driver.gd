extends Node
## The S5 stat-stack and status suite (`make godot-stats`): invariant **I3**
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
	_link_semantics()
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
