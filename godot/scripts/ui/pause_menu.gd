class_name PauseMenu
extends Node
## THE PAUSE ACTIONS: Resume; in a Zone, Return to Hub, and Abandon behind
## a confirmation naming what is lost; Quit. What each does is the game's
## (`Main` connects these signals); this holds which are offered and the
## confirmation's state. The Settings wall draws them as the PAUSED
## board's push switches (`SettingsFace`), and presses them.
##
## **Only what applies is offered.** Outside a Zone there is no Zone to
## return from or abandon: RESUME and QUIT GAME, nothing else.
##
## **Abandon is armed, then confirmed -- never both by one press.** Arming
## shows Production's own warning, CANCEL (where the press landed, and
## where the focus goes) and CONFIRM ABANDON. A press that was already
## down when it armed -- a key held, a double click -- cannot confirm it:
## CONFIRM ABANDON takes a fresh press, `ARM_GUARD` seconds after arming
## at the soonest.

signal resumed
signal return_to_hub_requested
signal abandon_confirmed
## The switches on offer changed (opened, armed, disarmed).
signal changed

## Production's words, unchanged.
const RESUME := "RESUME"
const RETURN_TO_HUB := "RETURN TO HUB"
const ABANDON := "ABANDON ZONE…"
const CONFIRM := "CONFIRM ABANDON"
const CANCEL := "CANCEL"
const QUIT := "QUIT GAME"
const WARNING := ("Abandoning returns unclaimed Checks to the pool.\n"
		+ "Confirmed Checks stay confirmed. This Zone is gone.")
## How soon after arming CONFIRM ABANDON can be pressed.
const ARM_GUARD := 0.35

var in_zone := false
## Open: the pause interface is showing these actions.
var visible := false
var _abandon_arming := false
var _armed_at := -1000.0
var _quit := Callable()


func _ready() -> void:
	name = "PauseMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(zone_active: bool) -> void:
	in_zone = zone_active
	_abandon_arming = false
	visible = true
	changed.emit()


func close() -> void:
	visible = false
	_abandon_arming = false
	resumed.emit()


func is_arming() -> bool:
	return _abandon_arming


## The switches on offer now, in order: [words].
func switches() -> Array:
	if not in_zone:
		return [RESUME, QUIT]
	if _abandon_arming:
		return [RESUME, CANCEL, CONFIRM]
	return [RESUME, RETURN_TO_HUB, ABANDON, QUIT]


## Press a switch by its words. `fresh`: a press of its own -- not a key's
## echo, not the second click of a double click. A press that is not
## fresh presses nothing. Returns whether it did anything.
func press(words: String, fresh := true) -> bool:
	if not switches().has(words) or not fresh:
		return false
	match words:
		RESUME:
			close()
		RETURN_TO_HUB:
			return_to_hub_requested.emit()
		ABANDON:
			_abandon_arming = true
			_armed_at = _now()
			changed.emit()
		CANCEL:
			_abandon_arming = false
			changed.emit()
		CONFIRM:
			if _now() - _armed_at < ARM_GUARD:
				return false
			abandon_confirmed.emit()
		QUIT:
			if _quit.is_valid():
				_quit.call()
			else:
				get_tree().quit()
	return true


## Back out of the confirmation. Whether there was one.
func disarm() -> bool:
	if not _abandon_arming:
		return false
	_abandon_arming = false
	changed.emit()
	return true


## A suite stands in for QUIT GAME's `get_tree().quit()`.
func set_quit_for_test(call: Callable) -> void:
	_quit = call


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
