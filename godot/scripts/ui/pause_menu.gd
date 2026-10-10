class_name PauseMenu
extends CanvasLayer
## Esc menu. Return to Hub always offered in a Zone; Abandon behind a
## confirmation naming what is lost.

signal resumed
signal return_to_hub_requested
signal abandon_confirmed

var in_zone := false
var _abandon_arming := false
var _box: VBoxContainer

func _ready() -> void:
	layer = 9
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 100)
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)

func open(zone_active: bool) -> void:
	in_zone = zone_active
	_abandon_arming = false
	_rebuild()
	visible = true

func close() -> void:
	visible = false
	resumed.emit()

func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	_box.add_child(title)

	_add_button("RESUME", close)
	if in_zone:
		_add_button("RETURN TO HUB",
				func() -> void: return_to_hub_requested.emit())
		if _abandon_arming:
			var warning := Label.new()
			warning.text = ("Abandoning returns unclaimed Checks to the pool.\n"
					+ "Confirmed Checks stay confirmed. This Zone is gone.")
			warning.modulate = Color(1.0, 0.6, 0.5)
			warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_box.add_child(warning)
			_add_button("CONFIRM ABANDON",
					func() -> void: abandon_confirmed.emit())
			_add_button("CANCEL", func() -> void:
				_abandon_arming = false
				_rebuild())
		else:
			_add_button("ABANDON ZONE…", func() -> void:
				_abandon_arming = true
				_rebuild())
	_add_button("QUIT GAME", func() -> void: get_tree().quit())

func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	_box.add_child(button)
