class_name SettingsFace
extends Control
## H-JOURNAL (CP4, `04` §8): THE SETTINGS WALL'S OWN HALF.
##
## "Settings includes resume, current campaign/profile information and
## supported options." The pause menu (`PauseMenu`) already sits in the
## middle of this wall with its actions -- RESUME, RETURN TO HUB, ABANDON
## ZONE behind its confirmation, QUIT GAME -- and this face leaves them
## exactly as they are: one button each, the same words, the same
## confirmation. Beside them:
## - **CAMPAIGN** (left): what this campaign is and how far along it is,
##   read from the snapshot (`JournalQuery.campaign`);
## - **OPTIONS** (right): the preferences the game applies
##   (`PlayerSettings`), each written to `user://settings.cfg` at once.
##
## **Only options that do something are offered.** Mouse sensitivity and
## invert look are read by the player on every move; motion is read every
## frame (and by the menu's turn); field of view is applied to the camera
## now and to every camera made after; master volume sets the Master bus
## (`apply_volume`, also called at boot). `PlayerSettings` also stores
## "captions", which nothing reads: offering a switch that changes nothing
## would be a lie, so it is not offered.
##
## PROVISIONAL ART: Godot's default controls and font (H-GLYPH-KIT).

const LEFT := Rect2(40, 92, 360, 580)
const RIGHT := Rect2(880, 92, 330, 580)
## The sensitivity the player is told about is relative to the default:
## a raw radians-per-pixel figure means nothing to anyone.
const SLIDERS := [
	["mouse_sensitivity", "Mouse sensitivity", 0.0001],
	["field_of_view", "Field of view", 1.0],
	["motion_intensity", "Motion (view bob, menu turns)", 0.05],
	["master_volume", "Master volume", 0.05],
]
const TOGGLES := [["invert_look_y", "Invert look up and down"]]

var _campaign: VBoxContainer
var _values := {}


func _ready() -> void:
	name = "SettingsFace"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_campaign = _panel("Campaign", LEFT, "CAMPAIGN")
	var options := _panel("Options", RIGHT, "OPTIONS")
	var settings := PlayerSettings.shared()
	for row: Array in SLIDERS:
		var key := str(row[0])
		var spec: Array = PlayerSettings.RANGES[key]
		var label := _line(options, "%sLabel" % key, "", 15)
		var slider := HSlider.new()
		slider.name = key
		slider.min_value = float(spec[1])
		slider.max_value = float(spec[2])
		slider.step = float(row[2])
		slider.custom_minimum_size = Vector2(RIGHT.size.x, 24)
		slider.value = settings.value(key)
		slider.set_meta("title", str(row[1]))
		_values[key] = label
		slider.value_changed.connect(_on_value.bind(key))
		options.add_child(slider)
		_describe(key, slider.value)
	for row: Array in TOGGLES:
		var key := str(row[0])
		var toggle := CheckButton.new()
		toggle.name = key
		toggle.text = str(row[1])
		toggle.button_pressed = settings.flag(key)
		toggle.toggled.connect(_on_flag.bind(key))
		options.add_child(toggle)
	BridgeClient.snapshot_received.connect(_on_snapshot)
	BridgeClient.bridge_state_changed.connect(_on_link)
	refresh()


## The Master bus at the saved volume. Called at boot and on every change.
static func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(
				PlayerSettings.shared().value("master_volume"), 0.0001)))


## The campaign lines, from what the client holds now.
func refresh() -> void:
	if _campaign == null:
		return
	for child: Node in _campaign.get_children():
		if str(child.name) != "Heading":
			_campaign.remove_child(child)
			child.queue_free()
	var rows := JournalQuery.campaign(BridgeClient.snapshot,
			BridgeClient.online)
	for i in rows.size():
		_line(_campaign, "Line%d" % i, str(rows[i]), 16)


func campaign_lines() -> Array:
	var out: Array = []
	for child: Node in _campaign.get_children():
		if child is Label and str(child.name) != "Heading":
			out.append((child as Label).text)
	return out


func slider(key: String) -> HSlider:
	return find_child(key, true, false) as HSlider


func toggle(key: String) -> CheckButton:
	return find_child(key, true, false) as CheckButton


func _panel(node_name: String, rect: Rect2, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.position = rect.position
	box.size = rect.size
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := _line(box, "Heading", heading, 20)
	title.modulate = Color(0.8, 0.85, 0.9)
	return box


func _line(parent: Control, node_name: String, text: String,
		font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2((parent as Control).size.x
			if parent is Control and (parent as Control).size.x > 0.0
			else 320.0, 0)
	parent.add_child(label)
	return label


func _describe(key: String, amount: float) -> void:
	var label: Label = _values.get(key)
	if label == null:
		return
	var title := ""
	for row: Array in SLIDERS:
		if str(row[0]) == key:
			title = str(row[1])
	var shown := ""
	match key:
		"mouse_sensitivity":
			shown = "x%.2f" % (amount / float(
					PlayerSettings.RANGES[key][0]))
		"field_of_view":
			shown = "%d degrees" % roundi(amount)
		"motion_intensity":
			shown = "off" if amount <= 0.0 else "%d%%" % roundi(amount * 100.0)
		"master_volume":
			shown = "%d%%" % roundi(amount * 100.0)
	label.text = "%s: %s" % [title, shown]


func _on_value(amount: float, key: String) -> void:
	var settings := PlayerSettings.shared()
	settings.set_value(key, amount)
	settings.save_to_disk()
	_describe(key, settings.value(key))
	match key:
		"field_of_view":
			# Now, not only for the next camera: the one in use is the
			# player's (the menu's own camera is in a world of its own).
			var camera := get_tree().root.get_camera_3d()
			if camera != null and camera.get_parent() is Player:
				camera.fov = settings.value(key)
		"master_volume":
			apply_volume()


func _on_flag(on: bool, key: String) -> void:
	var settings := PlayerSettings.shared()
	settings.set_flag(key, on)
	settings.save_to_disk()


func _on_snapshot(_snapshot: Dictionary) -> void:
	refresh()


func _on_link(_online: bool) -> void:
	refresh()
