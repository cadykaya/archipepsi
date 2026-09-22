class_name SlotKeycaps
extends RefCounted
## WHAT THE KEY FOR A SLOT IS ACTUALLY CALLED, for the player reading it.
##
## `Constants.SLOT_KEYCAPS` is the DEFAULT, exported from the bridge so
## both screens agree. It is not the authority: S21 lets the player
## rebind, and a label that still says SHIFT after they moved mobility to
## Space is a second authority disagreeing with the first — which is
## worse than no label, because it is confidently wrong.
##
## So the real binding wins where there is one to read, and the constant
## is what answers when there is not (an action with no events, or a
## binding this cannot name).

#: The mouse buttons players call something shorter than Godot does.
const _MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "LMB",
	MOUSE_BUTTON_RIGHT: "RMB",
	MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_WHEEL_UP: "WHEEL↑",
	MOUSE_BUTTON_WHEEL_DOWN: "WHEEL↓",
}


## The label for a slot's key. Never empty: the exported default is the
## floor.
static func of(slot: String) -> String:
	var fallback := str(Constants.SLOT_KEYCAPS.get(slot, "?"))
	var action := str(Player.SLOT_ACTIONS.get(slot, ""))
	if action == "" or not InputMap.has_action(action):
		return fallback
	for event: InputEvent in InputMap.action_get_events(action):
		var named := _name_of(event)
		if named != "":
			return named
	return fallback


static func _name_of(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return str(_MOUSE_NAMES.get(
				(event as InputEventMouseButton).button_index, ""))
	if event is InputEventKey:
		var key := event as InputEventKey
		# The PHYSICAL code, resolved through the current layout, so a
		# player on AZERTY reads the letter actually under their finger.
		var code := key.physical_keycode
		if code != 0:
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		if code == 0:
			code = key.keycode
		if code == 0:
			return ""
		return OS.get_keycode_string(code)
	return ""
