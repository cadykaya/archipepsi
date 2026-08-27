class_name InventoryLayer
extends CanvasLayer
## Echo inventory (Tab): name, source game, recipient, SOURCE LOCATION,
## description, activation, and the shared effect summary. Two Hookshots
## must read as Check 002's and Check 026's, not as duplicates.

signal closed

var _list: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	layer = 8
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(680, 520)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "ECHO ARCHIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(660, 420)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)
	var hint := Label.new()
	hint.text = "[Tab] close   [Q] cycle equipped in play"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.6, 0.65, 0.7)
	box.add_child(hint)

func open() -> void:
	rebuild()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var echoes: Array = BridgeClient.snapshot.get("echoes", [])
	var equipped: Variant = BridgeClient.snapshot.get("equipped_echo_id")
	if echoes.is_empty():
		var empty := Label.new()
		empty.text = "No Echoes yet. Send another player their item first."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
		return
	for echo: Dictionary in echoes:
		_list.add_child(_row(echo, echo.get("echo_id") == equipped))
	var unequip := Button.new()
	unequip.text = "UNEQUIP ALL"
	unequip.pressed.connect(func() -> void:
		BridgeClient.send_intent({"type": "equip_echo", "echo_id": null}))
	_list.add_child(unequip)

func _row(echo: Dictionary, is_equipped: bool) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var name_label := Label.new()
	var location := int(echo.get("source_location_id", 0))
	name_label.text = "%s   [%s]" % [echo.get("display_name", "?"),
			str(echo.get("activation", "")).to_upper()]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.modulate = Color(0.95, 0.9, 0.5) if is_equipped \
			else Color.WHITE
	text_box.add_child(name_label)

	var source := Label.new()
	source.text = "Check %03d — %s sent to %s (%s)" % [
			location % 1000, echo.get("source_item_name", "?"),
			echo.get("source_recipient_name", "?"),
			echo.get("source_game", "?")]
	source.modulate = Color(0.65, 0.75, 0.8)
	source.add_theme_font_size_override("font_size", 15)
	text_box.add_child(source)

	var description := Label.new()
	description.text = str(echo.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 15)
	text_box.add_child(description)

	var effects := Label.new()
	effects.text = " · ".join(EffectSummary.lines(echo))
	effects.modulate = Color(0.6, 0.95, 0.85)
	effects.add_theme_font_size_override("font_size", 15)
	text_box.add_child(effects)

	var button := Button.new()
	button.text = "EQUIPPED" if is_equipped else "EQUIP"
	button.disabled = is_equipped
	button.custom_minimum_size = Vector2(110, 0)
	button.pressed.connect(func() -> void:
		BridgeClient.send_intent({"type": "equip_echo",
				"echo_id": echo.get("echo_id")}))
	row.add_child(button)
	return panel
