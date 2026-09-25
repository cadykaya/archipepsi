class_name EquipRequests
extends RefCounted
## WHAT HAPPENED TO AN EQUIP, as the authority said it (`04` §5: "keep
## pending/refused/accepted equipment changes correlated to the real
## authority rather than optimistically painting a success that never
## arrived").
##
## The same answers `zone_state_selected` gets in `ZoneController`, for the
## same reason -- a control that shows its own wish as the outcome is lying
## whenever the bridge says no:
##
##   PENDING   sent; the key still shows what the bridge last confirmed.
##   ACCEPTED  a snapshot carries the key holding what was asked for.
##   REFUSED   a `BridgeError` whose `about` is exactly this request's key.
##   NOT SENT  there was no link to send it down.
##   LOST      the link dropped with it unanswered; the next snapshot is
##             the truth, and the key shows it.
##
## **One request per key, and the newest wins.** Two quick picks for one
## key are one decision; the first pick landing is not the second's answer,
## so it resolves nothing.
##
## **The key is domain-derived** -- `slot_action:<slot>:<component id>`,
## empty after the last colon for "clear it" -- the house rule for echoed
## identity. The bridge does not attach it to a `slot_action` refusal yet:
## `_about` in `server.py` is Dess's, and the ask is recorded (N-11). Until
## it does, a refused equip has no answer that names it. An `error` with an
## empty `about` means UNCHECKED, never "yours" (the `proposal_id` rule),
## so it resolves nothing here; the face shows it as the bridge's latest
## refusal, unattributed, beside the request still waiting.

const PENDING := "PENDING"
const ACCEPTED := "ACCEPTED"
const REFUSED := "REFUSED"
const NOT_SENT := "NOT SENT"
const LOST := "LOST"

## slot -> {"component_id": String or null, "key": String}
var _open := {}
## slot -> {"state", "component_id", "message"}
var _answers := {}


static func key(slot: String, component_id: Variant) -> String:
	return "slot_action:%s:%s" % [slot,
			"" if component_id == null else str(component_id)]


## Send it. `sender` is `BridgeClient.send_intent`, or a driver's stand-in;
## its answer is whether the intent left this process.
func send(slot: String, component_id: Variant, sender: Callable) -> String:
	var sent: bool = sender.call({"type": "slot_action", "slot": slot,
			"component_id": component_id})
	if not sent:
		_open.erase(slot)
		_answers[slot] = {"state": NOT_SENT, "component_id": component_id,
				"message": "no link to the bridge"}
		return NOT_SENT
	_open[slot] = {"component_id": component_id,
			"key": key(slot, component_id)}
	_answers.erase(slot)
	return PENDING


## ACCEPTED: the key holds what was asked for. Returns the keys resolved.
func on_snapshot(slots: Dictionary) -> Array:
	var resolved: Array = []
	for slot: Variant in _open.keys():
		var want: Variant = _open[slot]["component_id"]
		var holds: Variant = slots.get(slot)
		var landed := (want == null and holds == null) \
				or (want != null and holds != null
					and str(holds) == str(want))
		if landed:
			_answers[slot] = {"state": ACCEPTED, "component_id": want,
					"message": ""}
			_open.erase(slot)
			resolved.append(str(slot))
	return resolved


## REFUSED: on an exact `about` match, and on nothing else. Returns the
## key resolved, or "".
func on_error(err: Dictionary) -> String:
	var about := str(err.get("about", ""))
	if about == "":
		return ""
	for slot: Variant in _open.keys():
		if str(_open[slot]["key"]) == about:
			_answers[slot] = {"state": REFUSED,
					"component_id": _open[slot]["component_id"],
					"message": str(err.get("message", ""))}
			_open.erase(slot)
			return str(slot)
	return ""


## The link dropped. Nothing outstanding can be answered on this
## connection, so each becomes LOST rather than waiting forever; the
## snapshot after a reconnect says what actually happened.
func on_link_lost() -> void:
	for slot: Variant in _open.keys():
		_answers[slot] = {"state": LOST,
				"component_id": _open[slot]["component_id"],
				"message": "the link dropped before the bridge answered"}
	_open.clear()


func pending(slot: String) -> Dictionary:
	return _open.get(slot, {})


func is_pending(slot: String) -> bool:
	return _open.has(slot)


func answer(slot: String) -> Dictionary:
	return _answers.get(slot, {})


## Answers are for the visit in which they were given. What is still
## outstanding stays: closing the menu does not answer a request.
func forget_answers() -> void:
	_answers.clear()
