class_name ResourcePool
extends Node
## Current values for the campaign's Resources.
##
## These are the one part of a Resource that is NOT campaign state. §22
## settled it: definitions, maxima and upgrades persist; current values
## reset on Zone entry. So they live here, in the running game, and are
## never written to a save — which also means no reconnect path has to
## reconcile them, and a crash mid-Zone cannot leave a half-spent meter
## behind.
##
## The definitions come from the fold and are never edited here. This owns
## how full each channel is; the bridge owns what each channel IS.

signal channel_changed(component_id: String)

var _current: Dictionary = {}
#: Seconds until regen resumes, per channel. A resource with a regen_delay
#: that kept ticking through the moment it was spent would make the delay
#: decorative.
var _delay: Dictionary = {}

func _ready() -> void:
	BridgeClient.snapshot_received.connect(_on_snapshot)
	reset_for_zone()

## Every channel back to its declared starting fraction. Called on entering
## a Zone, which is the only place values reset.
func reset_for_zone() -> void:
	_current.clear()
	_delay.clear()
	for entry: Dictionary in BridgeClient.owned_components("resource"):
		var component: Dictionary = entry.get("component", {})
		var id := str(component.get("component_id", ""))
		_current[id] = float(component.get("max_value", 0.0)) \
				* float(component.get("initial_fraction", 1.0))
		_delay[id] = 0.0
		channel_changed.emit(id)

## A newly granted Resource starts at its initial fraction mid-Zone rather
## than waiting for the next one. A channel that existed but read as empty
## until you next walked through a door would look broken.
func _on_snapshot(_snapshot: Dictionary) -> void:
	for entry: Dictionary in BridgeClient.owned_components("resource"):
		var component: Dictionary = entry.get("component", {})
		var id := str(component.get("component_id", ""))
		if _current.has(id):
			continue
		_current[id] = float(component.get("max_value", 0.0)) \
				* float(component.get("initial_fraction", 1.0))
		_delay[id] = 0.0
		channel_changed.emit(id)

func value_of(component_id: String) -> float:
	return float(_current.get(component_id, 0.0))

func fraction_of(component_id: String) -> float:
	var component := _definition(component_id)
	var maximum := float(component.get("max_value", 0.0))
	if maximum <= 0.0:
		return 0.0
	return clampf(value_of(component_id) / maximum, 0.0, 1.0)

func is_full(component_id: String) -> bool:
	return fraction_of(component_id) >= 0.999

## Spend, refusing partial payment. Returns whether it went through.
##
## All-or-nothing on purpose: a cost that half-succeeds leaves the player
## poorer with nothing to show, which is the worst of both outcomes. Unused
## in S3 — rules (S4) and `powers`/`fills` links (S5) are what will call it
## — and here now because the pool is meaningless without the half that
## takes things out of it.
func spend(component_id: String, amount: float) -> bool:
	if amount <= 0.0:
		return true
	if value_of(component_id) < amount:
		return false
	_current[component_id] = value_of(component_id) - amount
	var component := _definition(component_id)
	_delay[component_id] = float(component.get("regen_delay", 0.0))
	channel_changed.emit(component_id)
	return true

## Spend across several channels, or spend nothing at all.
##
## `spend` is all-or-nothing per channel; this is all-or-nothing across a
## whole cost list, which is what a rule with two costs needs. Doing it by
## paying the first and refunding it on the second's refusal looked
## equivalent and was not: `spend` also arms `regen_delay`, and `refill`
## does not disarm it. A rule that could pay its first cost but not its
## second re-armed the delay on every attempt, and since an armed edge
## event dispatches every physics frame, that was 60 re-arms a second --
## regeneration stopped dead, permanently, on a rule that never fired.
##
## Checking first means no channel is ever touched by a payment that will
## not complete, so there is nothing to give back.
func spend_all(costs: Array) -> bool:
	var wanted: Dictionary = {}
	for cost: Dictionary in costs:
		var id := str(cost.get("id", ""))
		wanted[id] = float(wanted.get(id, 0.0)) + float(cost.get("amount", 0.0))
	for id: String in wanted:
		if float(wanted[id]) > 0.0 and value_of(id) < float(wanted[id]):
			return false
	for id: String in wanted:
		spend(id, float(wanted[id]))
	return true

## Take what is there, down to empty, and arm the regen delay if anything
## was taken. Distinct from `spend`: a cost is a transaction the player is
## paying and half of it is worse than none, but a rule effect draining a
## bar is damage to the bar, and draining 20 of a demanded 50 is the honest
## reading. Both arm the delay -- a drain that left regen running would put
## the value straight back and make the effect decorative.
func drain(component_id: String, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var taken := minf(amount, value_of(component_id))
	if taken <= 0.0:
		return 0.0
	_current[component_id] = value_of(component_id) - taken
	var component := _definition(component_id)
	_delay[component_id] = float(component.get("regen_delay", 0.0))
	channel_changed.emit(component_id)
	return taken

## Undo a spend, delay and all.
##
## `refill` is the wrong tool for this and was used for it: it restores the
## value but leaves the `regen_delay` the spend armed, so a refunded
## payment still cost the player several seconds of regeneration. A refund
## has to put back everything the spend took, and the delay is part of what
## it took.
func refund(component_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	refill(component_id, amount)
	_delay[component_id] = 0.0

func refill(component_id: String, amount: float) -> void:
	var component := _definition(component_id)
	var maximum := float(component.get("max_value", 0.0))
	_current[component_id] = clampf(value_of(component_id) + amount,
			0.0, maximum)
	channel_changed.emit(component_id)

func _definition(component_id: String) -> Dictionary:
	return BridgeClient.owned_component(component_id).get("component", {})

func _process(delta: float) -> void:
	for entry: Dictionary in BridgeClient.owned_components("resource"):
		var component: Dictionary = entry.get("component", {})
		var id := str(component.get("component_id", ""))
		var regen := float(component.get("regen_per_second", 0.0))
		if regen == 0.0 or not _current.has(id):
			continue
		if _delay.get(id, 0.0) > 0.0:
			_delay[id] = maxf(0.0, float(_delay[id]) - delta)
			continue
		var maximum := float(component.get("max_value", 0.0))
		var before := value_of(id)
		# A negative regen is decay -- momentum is a resource that drains.
		var after := clampf(before + regen * delta, 0.0, maximum)
		if not is_equal_approx(before, after):
			_current[id] = after
			channel_changed.emit(id)
