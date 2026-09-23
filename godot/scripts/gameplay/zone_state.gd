class_name ZoneState
extends Node
## THE ZONE'S REVERSIBLE CONFIGURATION — D-8's engine half.
##
## `Zone.zone_state` (bridge lane, D-8) declares the variables
## `physics.state_vector_product` had budgeted since before anything
## could name one. This holds their current values for one loaded Zone.
##
## **This is the machine layer of Amalgam §19.7**, and the rules that
## layer carries are the reason this class is as small as it is:
##
##   NO LOGIC NODES. A variable holds a state name and nothing else.
##   There is no predicate here, no combination, no derivation -- a
##   reader's room graph does that, locally, in its own room.
##   ROOMS NEVER ADDRESS EACH OTHER. A setter names a VARIABLE and a
##   reader names a VARIABLE. Neither can name the other, which is why
##   the forbidden global signal bus is not ruled out by a check in this
##   file: it is unrepresentable.
##   THE PLAYER IS THE BRIDGE. §19.7: "a puzzle that should change the
##   Zone drives a setter package's interaction, which the player then
##   performs". Nothing in the engine may call `select` except a setter
##   a player operated, and the only caller is `ZoneStateSetter`.
##
## **REVERSIBLE, WHICH IS THE WHOLE POINT.** Every other piece of
## Zone-scope state in this engine is monotone -- latches, keys, station
## reached-ness -- and that was P-0/F-23: a cross-room puzzle built on
## what existed could only have been a latch, which is the shortcut the
## owner and §19.7 both forbid. A variable set here can be set back, and
## whether it CAN is a fact the bridge proves from the declaration
## (§4.0) rather than a label anybody attached.
##
## **A refusal leaves nothing behind.** Same discipline as
## `StatusEffects`: an unknown variable, an unknown state, or a state
## this variable's setter cannot select changes no value and emits no
## `changed`. A success signal for something that did not happen is how
## a consumer comes to believe a state it never reached.

## A variable's value changed. Carries the new state so a reader never
## has to ask, and the id so a reader can ignore variables that are not
## its own.
signal changed(variable_id: String, state: String)

## `variable_id -> {states, initial, lifetime, selects}`. Declared once
## from the Zone and never added to at runtime.
var _declared: Dictionary = {}
var _value: Dictionary = {}


## Take the Zone's declaration. Idempotent and total: a Zone with no
## `zone_state` declares nothing and this object stays empty, which is
## every Zone composed before D-8.
func declare(variables: Array) -> void:
	for raw: Variant in variables:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = raw
		var id := str(one.get("variable_id", ""))
		if id == "":
			continue
		var states: Array = one.get("states", []) as Array
		var initial := str(one.get("initial", ""))
		if states.is_empty() or not initial in states:
			push_error(("zone_state '%s' declares initial '%s' outside "
					% [id, initial]) + "its states %s" % [states])
			continue
		var setter: Dictionary = one.get("setter", {}) as Dictionary
		_declared[id] = {
			"states": states,
			"initial": initial,
			"lifetime": str(one.get("lifetime", "reversible")),
			"selects": setter.get("selects", []) as Array,
			"setter_room": str(setter.get("room_id", "")),
		}
		_value[id] = initial


## Put the variables where a snapshot says they were.
##
## **NOT A REPLAY OF HOW THEY GOT THERE.** `ZoneProgress.macro_state`
## is overwritten rather than accumulated, so what comes back is the
## value and never the history, and a variable absent from the snapshot
## is simply at its initial -- which is what a Zone entered for the
## first time looks like and is the same code path.
##
## Silent on a variable this Zone does not declare: a snapshot taken
## against a different composition is the campaign's problem to notice,
## and dropping it here is better than storing a value nothing reads.
func restore(macro_state: Variant) -> void:
	if typeof(macro_state) != TYPE_DICTIONARY:
		return
	for key: Variant in macro_state as Dictionary:
		var id := str(key)
		if not _declared.has(id):
			continue
		var state := str((macro_state as Dictionary)[key])
		if state in (_declared[id] as Dictionary)["states"]:
			_value[id] = state


## Every variable this Zone declared.
func variables() -> Array:
	var out: Array = _declared.keys()
	out.sort()
	return out


func declares(variable_id: String) -> bool:
	return _declared.has(variable_id)


## What that variable holds right now, or "" if it is not declared.
func value_of(variable_id: String) -> String:
	return str(_value.get(variable_id, ""))


## The states this variable's setter may choose.
func selectable(variable_id: String) -> Array:
	if not _declared.has(variable_id):
		return []
	return ((_declared[variable_id] as Dictionary)["selects"] as Array)


func initial_of(variable_id: String) -> String:
	if not _declared.has(variable_id):
		return ""
	return str((_declared[variable_id] as Dictionary)["initial"])


## THE BRIDGE'S ANSWER, applied (O05-04). A selection the bridge refused
## is put back to what the campaign holds. This is the one caller that
## moves a value without its setter, and only to a declared state: the
## engine shows the player's operation at once, and the campaign decides
## whether it stands.
func revert(variable_id: String, state: String) -> bool:
	if not _declared.has(variable_id):
		return false
	if not state in ((_declared[variable_id] as Dictionary)["states"]
			as Array):
		return false
	if str(_value.get(variable_id, "")) == state:
		return true
	_value[variable_id] = state
	changed.emit(variable_id, state)
	return true


func lifetime_of(variable_id: String) -> String:
	if not _declared.has(variable_id):
		return ""
	return str((_declared[variable_id] as Dictionary)["lifetime"])


## SET A VARIABLE, and say whether anything happened.
##
## Called by a setter a player operated, and by nothing else. Returns
## `false` for every refusal, and a refusal changes no value and emits
## no signal.
##
## Re-selecting the state a variable already holds is NOT a refusal and
## also not an event: §19.7 rule 5 says macro effects are idempotent, so
## asking for what is already true succeeds quietly and the machine
## graph is not re-evaluated.
func select(variable_id: String, state: String) -> bool:
	if not _declared.has(variable_id):
		push_error("zone_state has no variable '%s'" % variable_id)
		return false
	var one: Dictionary = _declared[variable_id]
	if not state in (one["states"] as Array):
		push_error("zone_state '%s' has no state '%s'; it has %s"
				% [variable_id, state, one["states"]])
		return false
	# THE SETTER'S OWN LIMIT. `selects` is a subset of `states` and it is
	# what §4.0's lifetime rule is proven against, so honouring `states`
	# but not `selects` here would let the engine reach a state the
	# declaration says no control can choose -- and a `permanent`
	# variable would become reversible in the runtime while reading
	# monotone to the verifier.
	if not state in (one["selects"] as Array):
		push_error(("zone_state '%s' cannot be set to '%s': its setter "
				% [variable_id, state]) + "selects %s" % [one["selects"]])
		return false
	if str(_value.get(variable_id, "")) == state:
		return true
	_value[variable_id] = state
	changed.emit(variable_id, state)
	return true


## The values, as the save would carry them.
##
## **The reporting path is the bridge lane's and is not built yet.**
## `ZoneProgress.with_macro` and `ZoneProgress.macro` exist -- the
## storage and the read-back -- and there is no intent for the client to
## send a change: `protocol.py` has `latch_fired`, `lock_opened` and
## their siblings, and nothing for a Zone-state selection. So this
## returns what the engine WOULD report, the suite asserts it, and
## `ZoneController` sends nothing rather than inventing the other lane's
## message. Named here so the gap is a row and not a silence.
func as_reported() -> Dictionary:
	var out := {}
	for id: Variant in _value:
		out[str(id)] = str(_value[id])
	return out
