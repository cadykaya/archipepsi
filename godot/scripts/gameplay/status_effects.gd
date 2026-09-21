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

#: WHICH TARGET KIND this container belongs to -- Amalgam §15.1's five:
#: `self`, `enemy`, `object`, `surface`, `volume`. `self`/`enemy` are the
#: ECHOES.md spelling and still match `StatusComponent.target`; `object`
#: is what a crate carries. It is the same field because it answers the
#: same question the schema's `target` asks, and a second one would be a
#: second vocabulary.
var side := "self"

var _active: Dictionary = {}

func apply(kind: String, duration: float, magnitude: float) -> void:
	# The vocabulary is closed and generated from the schema. `StatStack`
	# guards its own stat names and pushes an error; this did not, and an
	# unknown kind was the worst of both worlds -- inert, because nothing
	# reads it, yet still satisfying `status_active` conditions and
	# `status_applied` edges, and permanently uncleansable because it is
	# not in the cleanse order. A typo produced a status that did nothing
	# and could never be removed.
	# ...AND SUPPORT IS NOT MEMBERSHIP. The vocabulary grew from twelve to
	# twenty-four when the destination's kinds were admitted ahead of
	# their runtimes, and for that window this guard read the wrong list:
	# `lightened` was in `ECHO_STATUS_KINDS`, so it applied, stored, and
	# satisfied `status_active` while nothing implemented it and no
	# cleanse order could remove it -- the permanent inert status above,
	# arrived at by the front door. The bridge refuses to EMIT an
	# unsupported kind; this is the engine asserting it can HONOUR what
	# it is handed, which is the half that lives here.
	if not kind in Constants.ECHO_STATUS_KINDS:
		push_error("apply_status names unknown status '%s'" % kind)
		return
	# ...AND SUPPORT IS PER TARGET, not per kind. `lightened` is
	# implemented on an OBJECT and on nothing else; a kind that works on
	# one target kind is not thereby working on another, and the bridge
	# refuses to emit at an unsupported target for the same reason. The
	# engine asks the same question at its own application boundary, so a
	# room cannot start a Status the campaign would have been refused.
	#
	# A REFUSAL LEAVES NOTHING BEHIND: no entry, and no `status_applied`,
	# so nothing downstream sees a success that did not happen.
	var targets: Array = Constants.ECHO_STATUS_TARGETS.get(kind, [])
	if targets.is_empty():
		push_error(("apply_status names '%s', which the design names " % kind)
				+ "but no runtime effect implements, so it may not be "
				+ "applied. NO STATUS BEFORE ITS EFFECT.")
		return
	if not side in targets:
		push_error("apply_status names '%s' on target '%s'; the runtime "
				% [kind, side] + "implements it on %s" % [targets])
		return
	for entry: Dictionary in BridgeClient.owned_components("status"):
		var component: Dictionary = entry.get("component", {})
		if str(component.get("status", "")) == kind \
				and str(component.get("target", "")) == side:
			duration = maxf(duration, float(component.get("duration", 0.0)))
			magnitude = maxf(magnitude,
					float(component.get("magnitude", 0.0)))
	# Re-application refreshes rather than stacks: two burnings that added
	# up would breach the schema's own magnitude bound from outside it.
	#
	# The two dimensions are taken TOGETHER, not maxed independently.
	# Maxing them apart let a feeble long application inherit a brutal
	# short one's magnitude and carry it for its whole life: 0.5 s at
	# magnitude 3 followed by 30 s at magnitude 0.05 gave thirty seconds
	# at 12 damage a second, eight times the total either application
	# asked for, from two individually schema-legal rule effects. The
	# stronger application wins outright and keeps its own duration; a
	# longer weaker one only extends what is already there once the
	# stronger has been outlived.
	var current: Dictionary = _active.get(kind, {})
	var held := float(current.get("magnitude", 0.0))
	var left := float(current.get("remaining", 0.0))
	if magnitude >= held:
		# Stronger (or equal): it replaces, and never shortens.
		_active[kind] = {"remaining": maxf(duration, left),
				"magnitude": magnitude}
	elif duration > left:
		# Weaker but longer: the strong one plays out first and the weak
		# one holds the tail. Storing only the tail is the honest reading
		# and the one this container can express.
		_active[kind] = {"remaining": left, "magnitude": held,
				"then": {"remaining": duration - left,
						"magnitude": magnitude}}
	# Weaker and shorter: entirely contained by what is already running.
	status_applied.emit(kind)

func tick(delta: float) -> void:
	var expired: Array[String] = []
	for kind: String in _active:
		var entry: Dictionary = _active[kind]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) > 0.0:
			continue
		if entry.has("then"):
			# A weaker application was queued behind this one. It inherits
			# the overshoot so the pair lasts exactly as long as it should.
			var tail: Dictionary = entry["then"]
			_active[kind] = {
				"remaining": float(tail["remaining"])
						+ float(entry["remaining"]),
				"magnitude": float(tail["magnitude"]),
			}
			if float(_active[kind]["remaining"]) <= 0.0:
				expired.append(kind)
		else:
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
## guess -- DoTs first, then control, then soft debuffs; helpful statuses
## are never cleansed away.
##
## The order is what this target actually SUFFERS from, and that is not
## the same list for both sides. `cleanse` is only ever aimed at the
## player (`echo_runtime.gd`), and the old order was written as if it were
## aimed at an enemy: `stunned` and `marked` are read by `enemy.gd` and by
## nothing on the player, so cleansing them spent a charge on nothing --
## and they outranked `vulnerable`, which the player genuinely suffers. Far
## worse, `low_profile` was in the list at all: `enemy.gd` reads it as the
## player's stealth, up to half the aggro radius, so a cleanse could strip
## the player's own buff.
const _CLEANSE_ORDER := {
	"self": ["burning", "poisoned", "frozen", "shocked", "slowed",
			"vulnerable"],
	"enemy": ["burning", "poisoned", "frozen", "stunned", "shocked",
			"slowed", "vulnerable", "marked"],
}

func cleanse(count: int) -> int:
	var removed := 0
	for kind: String in _CLEANSE_ORDER.get(side, _CLEANSE_ORDER["self"]):
		if removed >= count:
			break
		if _active.has(kind):
			_active.erase(kind)
			removed += 1
	return removed

func clear() -> void:
	_active.clear()
