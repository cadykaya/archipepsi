class_name StatStack
extends RefCounted
## The S5 derived stat stack (ECHOES §8, §10).
##
## Every owned trait contributes a multiplier to one of nine stats; the
## stack is their product, times status contributions and any live
## `trait_pulse`s, re-evaluated every physics frame because `scaled_by`
## reads live fractions. Three hard rules, in order:
##
##   1. A trait's own multiplier interpolates from 1.0 to its value across
##      its `scaled_by` fraction (a resource id, `hp_fraction` or
##      `hp_inverse`), and a `scales` link does the same with the linked
##      resource — strength scaling the fraction.
##   2. `requires_equipped` traits count only while their Action is
##      slotted. This is I7's escape hatch: severe downsides are removable.
##   3. The four traversal stats are FLOORED AT BASE after everything —
##      §10: nothing, statuses included, may make the player worse at
##      clearing a gap than the base kit — then the whole stat is clamped
##      to the shared envelope. `max_safe_gap` never needs recomputing.
##
## The player owns the outputs; enemies never read this (their statuses
## are their own, on `Enemy`).

const STATS := ["move_speed", "jump_height", "gravity", "air_control",
		"ground_friction", "damage_dealt", "damage_taken",
		"knockback_resist", "regen"]
const TRAVERSAL := ["move_speed", "jump_height", "gravity", "air_control"]

var pool: ResourcePool = null
var statuses: StatusEffects = null
## hp fraction supplied by the owner each evaluation; the stack never
## reaches into the player.
var hp_fraction := 1.0

var _pulses: Array[Dictionary] = []

func tick(delta: float) -> void:
	for pulse in _pulses:
		pulse["remaining"] = float(pulse["remaining"]) - delta
	_pulses = _pulses.filter(func(p: Dictionary) -> bool:
		return float(p["remaining"]) > 0.0)

## The rule effect (§5): a temporary extra factor on one stat. Floors and
## clamps still apply — a pulse cannot do what a trait cannot.
func add_pulse(stat: String, multiplier: float, duration: float) -> void:
	if stat not in STATS:
		push_error("trait_pulse names unknown stat '%s'" % stat)
		return
	_pulses.append({"stat": stat, "multiplier": multiplier,
			"remaining": duration})

## One trait's live factor: interpolated across its scaled_by fraction,
## then across any `scales` link pointed at it.
func _trait_factor(entry: Dictionary, slotted: Array,
		scales_by_target: Dictionary) -> float:
	var component: Dictionary = entry.get("component", {})
	var required: Variant = component.get("requires_equipped")
	if required != null and str(required) not in slotted:
		return 1.0
	var factor := float(component.get("multiplier", 1.0))
	var scaled_by: Variant = component.get("scaled_by")
	if scaled_by != null:
		factor = lerpf(1.0, factor, _fraction_of(str(scaled_by)))
	var link: Variant = scales_by_target.get(
			str(component.get("component_id", "")))
	if link != null:
		var strength := float(link.get("strength", 1.0))
		factor = lerpf(1.0, factor,
				clampf(_fraction_of(str(link.get("source", ""))) * strength,
						0.0, 1.0))
	return factor

func _fraction_of(source: String) -> float:
	match source:
		"hp_fraction":
			return clampf(hp_fraction, 0.0, 1.0)
		"hp_inverse":
			return clampf(1.0 - hp_fraction, 0.0, 1.0)
		_:
			return pool.fraction_of(source) if pool != null else 0.0

## Statuses that express as stat factors. Self-slows land on friction, not
## speed — §10: downside expresses in channels that bite without blocking.
func _status_factor(stat: String) -> float:
	if statuses == null:
		return 1.0
	var factor := 1.0
	match stat:
		"move_speed":
			factor *= 1.0 + statuses.magnitude_of("haste")
		"damage_dealt":
			factor *= 1.0 + 0.5 * statuses.magnitude_of("empowered")
		"damage_taken":
			factor *= 1.0 + 0.5 * statuses.magnitude_of("vulnerable")
			factor *= 1.0 + 0.1 * statuses.magnitude_of("shocked")
		"ground_friction":
			factor *= 1.0 - clampf(0.4 * statuses.magnitude_of("slowed")
					+ 0.6 * statuses.magnitude_of("frozen"), 0.0, 0.9)
	return factor

func evaluate() -> Dictionary:
	var slotted: Array = []
	for value in BridgeClient.slots().values():
		if value != null:
			slotted.append(str(value))
	var scales_by_target: Dictionary = {}
	for link: Dictionary in BridgeClient.mechanics().get("links", []):
		if str(link.get("link", "")) == "scales":
			scales_by_target[str(link.get("target", ""))] = link
	var out: Dictionary = {}
	for stat: String in STATS:
		out[stat] = 1.0
	for entry: Dictionary in BridgeClient.owned_components("trait"):
		var stat := str(entry.get("component", {}).get("stat", ""))
		if not out.has(stat):
			continue
		out[stat] = float(out[stat]) * _trait_factor(entry, slotted,
				scales_by_target)
	for pulse: Dictionary in _pulses:
		var stat := str(pulse["stat"])
		out[stat] = float(out[stat]) * float(pulse["multiplier"])
	for stat: String in STATS:
		out[stat] = float(out[stat]) * _status_factor(stat)
		out[stat] = clamp_stat(stat, float(out[stat]))
	return out

## The floor and the envelope, in that order. Static so the I3 sweep can
## hold the arithmetic itself, not just one evaluation of it.
static func clamp_stat(stat: String, product: float) -> float:
	if stat == "gravity":
		# Lighter-only, and never lighter than the derivation allowed.
		return clampf(product, float(Constants.GRAVITY_MULT_MIN), 1.0)
	if stat in TRAVERSAL:
		product = maxf(product, 1.0)
		if stat == "move_speed":
			return minf(product, float(Constants.SPEED_MULT_MAX))
		return minf(product, float(Constants.STAT_STACK_MAX))
	return clampf(product, float(Constants.STAT_STACK_MIN),
			float(Constants.STAT_STACK_MAX))
