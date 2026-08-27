class_name Favourites
extends RefCounted
## Which owned Actions the player marked to cycle between (ECHOES §9's
## "favourites within the highlighted slot").
##
## **Client-side, and deliberately.** `schemas/` is the binding contract
## and has no field for this — a favourite changes nothing mechanical, is
## never read by a rule, and losing the list costs the player a preference
## rather than a capability. That makes it the same kind of thing as a
## keybind or a mouse sensitivity, so it lives where those live and never
## touches the campaign save, the interpretation log or the bridge.
##
## Keyed by component id, which the fold keeps stable for the life of a
## campaign: an upgraded Action is the same id at Mk III, so a favourite
## survives its own evolution. A merged-away id would not resolve, and it
## does not need to — only Actions are favouritable and only resources
## merge.

const _PATH := "user://loadout.cfg"
const _SECTION := "favourites"

static var _marked: Dictionary = {}
static var _loaded := false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(_PATH) != OK:
		return
	for key in config.get_section_keys(_SECTION) \
			if config.has_section(_SECTION) else []:
		if bool(config.get_value(_SECTION, key, false)):
			_marked[str(key)] = true

static func _save() -> void:
	var config := ConfigFile.new()
	for component_id: String in _marked:
		config.set_value(_SECTION, component_id, true)
	# A preference failing to persist is not worth interrupting play for.
	config.save(_PATH)

static func is_favourite(component_id: String) -> bool:
	_load()
	return _marked.has(component_id)

static func toggle(component_id: String) -> bool:
	_load()
	if _marked.has(component_id):
		_marked.erase(component_id)
	else:
		_marked[component_id] = true
	_save()
	return _marked.has(component_id)

## The ids the wheel should cycle for one slot: the favourites among them
## if any are marked, and otherwise everything, because a wheel that
## cycles nothing until you have configured it is a wheel that reads as
## broken.
static func cycle_set(slot_action_ids: Array) -> Array:
	_load()
	var starred: Array = []
	for id in slot_action_ids:
		if _marked.has(str(id)):
			starred.append(id)
	return starred if starred.size() >= 2 else slot_action_ids

## Test seam: the suites drive this without touching the user's real file.
static func _reset_for_test() -> void:
	_marked.clear()
	_loaded = true
