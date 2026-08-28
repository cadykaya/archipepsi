class_name RuleRuntime
extends Node
## The ECHOES §5 rule interpreter: EVENT → CONDITIONS → COST → EFFECTS.
##
## A rule is data on a closed allowlist, evaluated here; nothing generated
## is compiled or resolved to a symbol (TECHNICAL_ARCHITECTURE §14). The
## termination properties of §5.1 are structural in this file:
##
##   1. Effects write state only — nothing in `_apply_effect` calls
##      `notify` or touches the queues.
##   2. Threshold events (`resource_full`, `resource_empty`, `low_health`)
##      are DERIVED at end of tick by comparing watched values against the
##      previous tick's, on the crossing edge only. A crossing ARMS each
##      rule listening for that kind — one latched firing, consumed when
##      the rule fires, disarmed if the value leaves the threshold first.
##      The latch is what lets a crossing survive a rule's cooldown (I5
##      says the fill/drain pair oscillates at the cooldown rate, which is
##      impossible if a cooling rule loses the edge) while a value merely
##      SITTING at a threshold still fires nothing: sitting never re-arms.
##   3. Derived events dispatch no earlier than the NEXT tick — arming
##      happens at end of tick, and arms are read by the next dispatch.
##   4. One dispatch, one pass: every rule considered at most once, its
##      conditions read from a state snapshot taken when the dispatch
##      began. Costs pay from the LIVE pool — `spend` refuses partial
##      payment, so two rules cannot overdraw one bar by both reading the
##      opening balance.
##   5. Every rule carries a schema-floored 0.1 s cooldown, and firings per
##      tick are capped at `Constants.RULE_FIRINGS_PER_TICK_CAP`; rules the
##      cap skips are SKIPPED, not queued — queueing them would be the
##      backlog cascade the cap exists to prevent.
##
## World references are duck-typed and optional: the rules suite drives the
## decision core with a real ResourcePool and no player, and every effect
## is appended to `effect_log` whether or not something real applied it.

#: Engine-emitted push events `notify()` accepts. Derived events arrive
#: only via `_derive_edges`, so an effect (or a bug in a caller) cannot
#: inject one directly.
const PUSH_EVENTS := ["zone_enter", "chamber_enter", "jump", "land",
		"dash_end", "kill", "damage_dealt", "damage_taken", "action_used",
		"action_ready", "parry_success", "check_claimed"]

const _EFFECT_LOG_CAP := 256

var pool: ResourcePool = null
var player = null          # hp / max_hp / velocity / is_on_floor() / heal()
var echo_runtime = null    # grant_shield() / reset_cooldown() / rule projectiles
var zone_root: Node = null # where damage_around looks for the enemies group

signal rule_fired(rule_id: String)

var _rules: Array[Dictionary] = []
var _aliases: Dictionary = {}
var _cooldowns: Dictionary = {}
var _pending: Array[String] = []
#: rule_id -> true. The per-rule edge latch described above.
var _armed: Dictionary = {}
var _watched_fractions: Dictionary = {}
var _watched_hp := 1.0
var _watched_status_kinds: Dictionary = {}
var _one_hz := 0.0

#: Every effect that fired, `{rule_id, effect}`, capped. The suite reads
#: it; production ignores it.
var effect_log: Array[Dictionary] = []

## Pull the folded rule set. Call on zone entry and on snapshot changes —
## the fold owns which rules exist; this never edits them.
func refresh_rules() -> void:
	_rules.clear()
	_aliases = {}
	for pair in BridgeClient.mechanics().get("aliases", []):
		if pair is Array and pair.size() == 2:
			_aliases[str(pair[0])] = str(pair[1])
	for entry: Dictionary in BridgeClient.owned_components("rule"):
		_rules.append(entry.get("component", {}))

## An absorbed resource id keeps resolving to its survivor forever
## (TECHNICAL_ARCHITECTURE: aliases are permanent). The fold guarantees no
## chains, so one hop is the whole walk.
func _resolve(component_id: String) -> String:
	return str(_aliases.get(component_id, component_id))

## The suites drive `tick()` by hand, off-tree. In the game this node sits
## in main's tree and ticks itself while a player is bound.
func _physics_process(delta: float) -> void:
	if player != null:
		tick(delta)

func notify(event: String) -> void:
	if event not in PUSH_EVENTS:
		push_error("rule event '%s' is not engine-emittable" % event)
		return
	_pending.append(event)

func tick(delta: float) -> void:
	for rule_id in _cooldowns:
		_cooldowns[rule_id] = maxf(0.0, float(_cooldowns[rule_id]) - delta)
	_one_hz += delta
	if _one_hz >= 1.0:
		_one_hz = fmod(_one_hz, 1.0)
		_pending.append("tick_1hz")

	var dispatch: Array[String] = []
	dispatch.append_array(_pending)
	_pending = []

	if (not dispatch.is_empty() or not _armed.is_empty()) \
			and not _rules.is_empty():
		_dispatch(dispatch)

	_derive_edges()

func _dispatch(events: Array[String]) -> void:
	var snapshot := _snapshot_state()
	var fired := 0
	var considered: Dictionary = {}
	for rule: Dictionary in _rules:
		var rule_id := str(rule.get("component_id", ""))
		if considered.has(rule_id):
			continue
		var via_arm: bool = _armed.has(rule_id)
		if not via_arm and str(rule.get("event", "")) not in events:
			continue
		considered[rule_id] = true
		if fired >= Constants.RULE_FIRINGS_PER_TICK_CAP:
			# The cap SKIPS. A push event skipped is gone (a jump nothing
			# answered); an armed edge stays armed and retries next tick —
			# bounded, because an arm is state, not a growing queue.
			continue
		if float(_cooldowns.get(rule_id, 0.0)) > 0.0:
			continue
		if not _conditions_hold(rule, snapshot):
			continue
		if not _pay_costs(rule):
			continue
		_cooldowns[rule_id] = float(rule.get("cooldown", 0.1))
		_armed.erase(rule_id)
		fired += 1
		for effect: Dictionary in rule.get("effects", []):
			_apply_effect(rule_id, effect)
		rule_fired.emit(rule_id)

## The values conditions may read, frozen at dispatch start (§5.1 rule 4).
func _snapshot_state() -> Dictionary:
	var fractions: Dictionary = {}
	if pool != null:
		for entry: Dictionary in BridgeClient.owned_components("resource"):
			var id := str(entry.get("component", {}).get("component_id", ""))
			fractions[id] = pool.fraction_of(id)
	var snapshot := {
		"fractions": fractions,
		"hp_fraction": 1.0, "airborne": false, "speed": 0.0,
		"moving_backward": false, "enemy_within": INF,
	}
	if player != null:
		var max_hp := float(player.get("max_hp") if player.get("max_hp") != null
				else Constants.PLAYER_MAX_HP)
		snapshot["hp_fraction"] = clampf(float(player.hp) / max_hp, 0.0, 1.0)
		snapshot["airborne"] = not player.is_on_floor()
		var velocity: Vector3 = player.velocity
		snapshot["speed"] = Vector2(velocity.x, velocity.z).length()
		var forward: Vector3 = -player.global_transform.basis.z
		snapshot["moving_backward"] = snapshot["speed"] > 0.5 \
				and Vector2(velocity.x, velocity.z).normalized().dot(
						Vector2(forward.x, forward.z).normalized()) < -0.2
		snapshot["enemy_within"] = _nearest_enemy_distance()
	return snapshot

func _nearest_enemy_distance() -> float:
	if zone_root == null or player == null:
		return INF
	var nearest := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node3D and not node.is_queued_for_deletion():
			nearest = minf(nearest, (node as Node3D).global_position
					.distance_to(player.global_position))
	return nearest

func _conditions_hold(rule: Dictionary, snapshot: Dictionary) -> bool:
	for condition: Dictionary in rule.get("conditions", []):
		var subject := _resolve(str(condition.get("subject", "")))
		var value := float(condition.get("value", 0.0))
		var fractions: Dictionary = snapshot["fractions"]
		match str(condition.get("type", "")):
			"resource_at_least":
				if float(fractions.get(subject, 0.0)) < value:
					return false
			"resource_at_most":
				if float(fractions.get(subject, 0.0)) > value:
					return false
			"hp_below":
				if float(snapshot["hp_fraction"]) >= value:
					return false
			"hp_above":
				if float(snapshot["hp_fraction"]) <= value:
					return false
			"airborne":
				if not bool(snapshot["airborne"]):
					return false
			"grounded":
				if bool(snapshot["airborne"]):
					return false
			"moving_backward":
				if not bool(snapshot["moving_backward"]):
					return false
			"speed_above":
				if float(snapshot["speed"]) <= value:
					return false
			"enemy_within":
				if float(snapshot["enemy_within"]) > value:
					return false
			"slot_is":
				# "Names a slot": true while the named slot holds an
				# Action. Revisit the reading at S7 if favourites need a
				# component-identity form; recorded in
				# IMPLEMENTATION_DECISIONS.
				if BridgeClient.slots().get(
						str(condition.get("subject", ""))) == null:
					return false
			"zone_is_finale":
				if not bool(BridgeClient.active_zone().get(
						"is_finale", false)):
					return false
			"status_active":
				if player == null or player.get("statuses") == null \
						or not player.statuses.has(
								str(condition.get("subject", ""))):
					return false
			_:
				# A condition the runtime does not implement cannot be
				# allowed to silently pass as true.
				push_error("rule condition '%s' has no interpreter arm"
						% condition.get("type", ""))
				return false
	return true

## All-or-nothing across the rule's costs too: a two-cost rule that could
## pay only the first must not fire poorer.
##
## This used to pay the first and refund it if the second refused, which
## looked equivalent and was not. `spend` arms the channel's `regen_delay`
## and `refill` does not disarm it, so every failed attempt cost the player
## a regeneration window -- and a rule whose event stays armed is
## dispatched every physics frame, so the window was re-armed 60 times a
## second and regeneration stopped dead on a rule that never fired once.
##
## `spend_all` checks the whole list before touching anything, so a
## refusal leaves no trace to undo.
func _pay_costs(rule: Dictionary) -> bool:
	if pool == null:
		return rule.get("costs", []).is_empty()
	var costs: Array = []
	for cost: Dictionary in rule.get("costs", []):
		costs.append({"id": _resolve(str(cost.get("resource_id", ""))),
				"amount": float(cost.get("amount", 0.0))})
	return pool.spend_all(costs)

func _apply_effect(rule_id: String, effect: Dictionary) -> void:
	effect_log.append({"rule_id": rule_id, "effect": effect})
	if effect_log.size() > _EFFECT_LOG_CAP:
		effect_log.pop_front()
	var subject := _resolve(str(effect.get("subject", "")))
	var amount := float(effect.get("amount", 0.0))
	match str(effect.get("type", "")):
		"resource_add":
			# `Effect.amount` allows a negative, and a negative
			# `resource_add` is a drain by any reading. Sending it through
			# `refill` took the value out through the one door that does
			# not arm `regen_delay`, which made the delay decorative for
			# exactly the effect most likely to be spammed.
			if pool != null:
				if amount < 0.0:
					pool.drain(subject, -amount)
				else:
					pool.refill(subject, amount)
		"refill_resource":
			if pool != null:
				var definition: Dictionary = BridgeClient.owned_component(
						subject).get("component", {})
				pool.refill(subject, float(definition.get("max_value", 0.0)))
		"heal":
			if player != null:
				player.heal(amount)
		"grant_shield":
			if echo_runtime != null:
				echo_runtime.grant_shield(amount,
						float(effect.get("duration", 0.0)))
		"impulse_self":
			if player != null:
				player.velocity += _impulse_vector(
						str(effect.get("direction", "forward")), amount)
		"damage_around":
			_damage_around(float(effect.get("radius", 0.0)), amount)
		"fire_projectile":
			if echo_runtime != null:
				echo_runtime.fire_rule_projectile(amount,
						str(effect.get("direction", "aim")))
		"reset_action_cooldown":
			if echo_runtime != null:
				echo_runtime.reset_cooldown()
		"apply_status":
			# A rule's status lands on the PLAYER: rules are the player's
			# machinery, and the enemy-facing paths are the hit modifier
			# and scan_mark. `amount` is the magnitude.
			if player != null and player.get("statuses") != null:
				player.statuses.apply(str(effect.get("subject", "")),
						float(effect.get("duration", 1.0)), amount)
		"trait_pulse":
			if player != null and player.get("stat_stack") != null:
				player.stat_stack.add_pulse(str(effect.get("subject", "")),
						amount, float(effect.get("duration", 1.0)))
		"grant_local_reward":
			# Local rewards are earned save state (§14.2), so the client
			# asks the bridge to record one instead of inventing it. The
			# catalog is enforced schema-side; nothing here can name an AP
			# item, location or Check because the intent has no field for
			# one.
			BridgeClient.send_intent({
				"type": "grant_local_reward",
				"kind": str(effect.get("subject", "flavor_log")),
				"reward_id": "rule_%s" % rule_id,
				"display_name": str(effect.get("subject", "flavor_log")),
			})
		_:
			# Every effect kind has an arm since S9; reaching here is
			# drift between the gates and this interpreter.
			push_error("rule effect '%s' has no interpreter arm"
					% effect.get("type", ""))

func _impulse_vector(direction: String, amount: float) -> Vector3:
	var basis: Basis = player.global_transform.basis
	match direction:
		"up":
			return Vector3.UP * amount
		"backward":
			return basis.z * amount
		"velocity":
			var velocity: Vector3 = player.velocity
			return velocity.normalized() * amount \
					if velocity.length() > 0.1 else Vector3.ZERO
		"aim":
			var aim: Vector3 = -basis.z
			if player.get("camera") != null:
				aim = -(player.camera.global_transform.basis.z)
			return aim * amount
		_:
			return -basis.z * amount

func _damage_around(radius: float, amount: float) -> void:
	if zone_root == null or player == null:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node3D and not node.is_queued_for_deletion() \
				and (node as Node3D).global_position.distance_to(
						player.global_position) <= radius \
				and node.has_method("take_damage"):
			node.take_damage(amount, (node as Node3D).global_position
					- player.global_position)

## End of tick: compare watched values against last tick's, and on each
## crossing ARM the rules listening for that kind — read by the NEXT
## dispatch, never this one. A value that left its threshold takes unfired
## arms with it: a heal that outran a cooling low_health rule means no
## firing, because "low" stopped being true before the rule ever ran.
func _derive_edges() -> void:
	var crossed := {"resource_full": false, "resource_empty": false,
			"low_health": false, "status_applied": false}
	var holding := {"resource_full": false, "resource_empty": false,
			"low_health": false, "status_applied": false}
	if player != null and player.get("statuses") != null:
		# status_applied's edge is a KIND appearing that was absent last
		# tick; holding is any status being active at all.
		for kind in player.statuses.active_kinds():
			holding["status_applied"] = true
			if not _watched_status_kinds.has(kind):
				crossed["status_applied"] = true
		_watched_status_kinds.clear()
		for kind in player.statuses.active_kinds():
			_watched_status_kinds[kind] = true
	if pool != null:
		for entry: Dictionary in BridgeClient.owned_components("resource"):
			var id := str(entry.get("component", {}).get("component_id", ""))
			var fraction := pool.fraction_of(id)
			var previous := float(_watched_fractions.get(id, fraction))
			if fraction >= 0.999:
				holding["resource_full"] = true
				if previous < 0.999:
					crossed["resource_full"] = true
			if fraction <= 0.001:
				holding["resource_empty"] = true
				if previous > 0.001:
					crossed["resource_empty"] = true
			_watched_fractions[id] = fraction
	if player != null:
		var max_hp := float(player.get("max_hp") if player.get("max_hp") != null
				else Constants.PLAYER_MAX_HP)
		var hp_fraction := clampf(float(player.hp) / max_hp, 0.0, 1.0)
		if hp_fraction < Constants.LOW_HEALTH_FRACTION:
			holding["low_health"] = true
			if _watched_hp >= Constants.LOW_HEALTH_FRACTION:
				crossed["low_health"] = true
		_watched_hp = hp_fraction

	for rule: Dictionary in _rules:
		var event := str(rule.get("event", ""))
		if not crossed.has(event):
			continue
		var rule_id := str(rule.get("component_id", ""))
		if crossed[event]:
			_armed[rule_id] = true
		elif not holding[event]:
			_armed.erase(rule_id)
