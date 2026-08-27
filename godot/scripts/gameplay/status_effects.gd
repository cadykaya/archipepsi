class_name StatusEffects
extends RefCounted
## One target's active statuses (ECHOES §8): bounded named conditions with
## a remaining duration and a magnitude. §22/I9: never saved — statuses
## reset with Zone entry exactly like resource values.
##
## Owned `StatusComponent`s are FLOORS for their kind: the campaign's tuned
## "burning" cannot be applied weaker than its definition says (target must
## match). That is what stops an owned status definition from being the
## inert-component failure the staged gates exist to prevent: owning one
## upgrades every later application of its kind.

signal status_applied(kind: String)

#: Which side this container belongs to, for matching StatusComponent
#: definitions ("self" for the player, "enemy" for an enemy).
var side := "self"

var _active: Dictionary = {}

func apply(kind: String, duration: float, magnitude: float) -> void:
	for entry: Dictionary in BridgeClient.owned_components("status"):
		var component: Dictionary = entry.get("component", {})
		if str(component.get("status", "")) == kind \
				and str(component.get("target", "")) == side:
			duration = maxf(duration, float(component.get("duration", 0.0)))
			magnitude = maxf(magnitude,
					float(component.get("magnitude", 0.0)))
	# Re-application refreshes rather than stacks: max of durations, max of
	# magnitudes. Two burnings that added up would breach the schema's own
	# magnitude bound from outside it.
	var current: Dictionary = _active.get(kind, {})
	_active[kind] = {
		"remaining": maxf(duration, float(current.get("remaining", 0.0))),
		"magnitude": maxf(magnitude, float(current.get("magnitude", 0.0))),
	}
	status_applied.emit(kind)

func tick(delta: float) -> void:
	var expired: Array[String] = []
	for kind: String in _active:
		var entry: Dictionary = _active[kind]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			expired.append(kind)
	for kind in expired:
		_active.erase(kind)

func has(kind: String) -> bool:
	return _active.has(kind)

func magnitude_of(kind: String) -> float:
	return float(_active.get(kind, {}).get("magnitude", 0.0))

func active_kinds() -> Array:
	return _active.keys()

## Damage per second this target takes from its own conditions.
func dot_per_second() -> float:
	return 4.0 * magnitude_of("burning") + 2.0 * magnitude_of("poisoned")

## Healing per second (the `regenerating` status).
func regen_per_second() -> float:
	return 3.0 * magnitude_of("regenerating")

## `cleanse`: remove up to `count` statuses, worst first. Worst = the one
## hurting most right now, ranked by a fixed severity order rather than a
## guess — DoTs first, then control, then soft debuffs; helpful statuses
## are never cleansed away.
const _CLEANSE_ORDER := ["burning", "poisoned", "frozen", "stunned",
		"shocked", "slowed", "vulnerable", "marked", "low_profile"]

func cleanse(count: int) -> int:
	var removed := 0
	for kind: String in _CLEANSE_ORDER:
		if removed >= count:
			break
		if _active.has(kind):
			_active.erase(kind)
			removed += 1
	return removed

func clear() -> void:
	_active.clear()
