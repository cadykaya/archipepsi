class_name PlayerSettings
extends RefCounted
## Player preferences and input bindings (v0.9 S21).
##
## Two rules, both load-bearing, both tested:
##
## 1. **Preferences are NEVER campaign truth.** They live in
##    `user://settings.cfg` and never touch the save, the interpretation
##    log, or anything sent to Archipelago. A player's mouse sensitivity
##    is not a fact about their multiworld; putting it in the save would
##    make two players' saves differ for a reason no rule cares about,
##    and would make a preference change a state transition.
##
## 2. **Rebinding cannot break a mandatory action.** The base kit is what
##    invariants I3/I4 guarantee the mandatory path to be walkable with.
##    A player who unbinds `jump` has, with no warning, made their own
##    seed unfinishable -- and they did it in a menu, three rooms away
##    from the gap they can no longer cross. `MANDATORY_ACTIONS` may
##    never be left unbound.
##
## `favourites.gd` set the precedent for (1) and this follows it.

const PATH := "user://settings.cfg"

## The base kit's own inputs. Without any one of these there is a seed
## the player cannot finish:
##
##   - the four moves and `jump`: invariant I3's movement floor;
##   - `interact`: claiming a Check, using a portal;
##   - `fire_pulse`: the Static Pulse, always available and never
##     replaced by an Echo, so it is the only guaranteed way to deal
##     damage. A `kill_all` objective with no bound attack is a locked
##     room.
##
## Echo slots and the cycle keys are deliberately absent: a slot may
## legitimately be empty, so unbinding one costs the player nothing they
## were guaranteed.
const MANDATORY_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "interact", "fire_pulse",
]

## name -> [default, minimum, maximum]. Floats only; the bounds are the
## contract, so a hand-edited config cannot produce a sensitivity of zero
## (the mouse stops working) or a FOV of 5 (a tunnel).
const RANGES := {
	"mouse_sensitivity": [0.0022, 0.0002, 0.02],
	"field_of_view": [90.0, 60.0, 120.0],
	## 0 disables view bob and landing dip entirely. Motion sickness is
	## the reason this exists, so 0 has to be reachable -- an
	## accessibility option with a floor above off is not one.
	"motion_intensity": [1.0, 0.0, 1.0],
	"master_volume": [1.0, 0.0, 1.0],
}

const FLAGS := {
	"invert_look_y": false,
	## Epsilon speaks in the Hub and on reveals. Captions are the only
	## way to read what was said.
	"captions": true,
}

var values: Dictionary = {}
var flags: Dictionary = {}
## action -> Array[InputEvent]. Empty means "the project default".
var bindings: Dictionary = {}

static var _shared: PlayerSettings = null

static func shared() -> PlayerSettings:
	if _shared == null:
		_shared = PlayerSettings.new()
		_shared.load_from_disk()
	return _shared

static func reset_shared() -> void:
	_shared = null

func _init() -> void:
	restore_defaults()

func restore_defaults() -> void:
	values.clear()
	flags.clear()
	bindings.clear()
	for name: String in RANGES:
		values[name] = float((RANGES[name] as Array)[0])
	for name: String in FLAGS:
		flags[name] = bool(FLAGS[name])

# --- values ----------------------------------------------------------------

## Clamped on the way in, not on the way out. A value read a hundred
## times a frame should not have to be defended a hundred times a frame,
## and a stored value outside its range would survive every read.
func set_value(name: String, value: float) -> void:
	if not RANGES.has(name):
		push_warning("settings: unknown value '%s'" % name)
		return
	var range_spec: Array = RANGES[name]
	values[name] = clampf(value, float(range_spec[1]), float(range_spec[2]))

func value(name: String) -> float:
	if not RANGES.has(name):
		return 0.0
	return float(values.get(name, (RANGES[name] as Array)[0]))

func set_flag(name: String, on: bool) -> void:
	if FLAGS.has(name):
		flags[name] = on

func flag(name: String) -> bool:
	return bool(flags.get(name, FLAGS.get(name, false)))

# --- bindings --------------------------------------------------------------

## Rebinds one action. Returns "" on success, or why it was refused.
##
## Refusing is the whole feature. A menu that lets a player unbind `jump`
## has let them break a seed they cannot get back, and it will look like
## the game's fault when they meet the gap.
func rebind(action: String, events: Array) -> String:
	if not InputMap.has_action(action):
		return "no such action '%s'" % action
	if events.is_empty() and action in MANDATORY_ACTIONS:
		return ("'%s' is part of the base kit and must stay bound; "
				% action + "without it there are seeds you could not "
				+ "finish, and you would not find out until you met one")
	bindings[action] = events.duplicate()
	_apply_action(action)
	return ""

## Mandatory actions with nothing bound to them. Empty is the contract;
## anything else is a player who cannot finish.
func unbound_mandatory() -> Array[String]:
	var out: Array[String] = []
	for action: String in MANDATORY_ACTIONS:
		if not InputMap.has_action(action):
			out.append(action)
			continue
		if InputMap.action_get_events(action).is_empty():
			out.append(action)
	return out

func _apply_action(action: String) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in bindings.get(action, []):
		InputMap.action_add_event(action, event)

## Pushes every stored binding into the live InputMap.
func apply_bindings() -> void:
	for action: String in bindings:
		_apply_action(action)

# --- persistence -----------------------------------------------------------
#
# `user://`, never the campaign save. See the class comment: a preference
# is not a fact about a multiworld.

func save_to_disk() -> void:
	var config := ConfigFile.new()
	for name: String in values:
		config.set_value("values", name, values[name])
	for name: String in flags:
		config.set_value("flags", name, flags[name])
	for action: String in bindings:
		var encoded: Array = []
		for event: InputEvent in bindings[action]:
			if event is InputEventKey:
				encoded.append({"type": "key",
						"keycode": (event as InputEventKey).physical_keycode})
			elif event is InputEventMouseButton:
				encoded.append({"type": "mouse",
						"button": (event as InputEventMouseButton).button_index})
		config.set_value("bindings", action, encoded)
	config.save(PATH)

func load_from_disk() -> void:
	restore_defaults()
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for name: String in config.get_section_keys("values") \
			if config.has_section("values") else []:
		# Through `set_value`, so a hand-edited config is clamped rather
		# than trusted. A file on the player's disk is not a contract.
		set_value(name, float(config.get_value("values", name, 0.0)))
	for name: String in config.get_section_keys("flags") \
			if config.has_section("flags") else []:
		set_flag(name, bool(config.get_value("flags", name, false)))
	if config.has_section("bindings"):
		for action: String in config.get_section_keys("bindings"):
			var decoded: Array = []
			for entry: Variant in config.get_value("bindings", action, []):
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var e: Dictionary = entry
				if str(e.get("type", "")) == "key":
					var key := InputEventKey.new()
					key.physical_keycode = int(e.get("keycode", 0))
					decoded.append(key)
				elif str(e.get("type", "")) == "mouse":
					var mouse := InputEventMouseButton.new()
					mouse.button_index = int(e.get("button", 0))
					decoded.append(mouse)
			# A config that unbinds a mandatory action is repaired, not
			# obeyed. The file may have been edited, or written by an
			# older build with a different mandatory set.
			if decoded.is_empty() and action in MANDATORY_ACTIONS:
				continue
			bindings[action] = decoded
	apply_bindings()
