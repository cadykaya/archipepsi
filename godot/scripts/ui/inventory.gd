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
	var echoes: Array = BridgeClient.snapshot.get("interpretations", [])
	if echoes.is_empty():
		var empty := Label.new()
		empty.text = "No Echoes yet. Send another player their item first."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
		return
	var slots: Dictionary = BridgeClient.slots()
	var slotted: Array = []
	for value in slots.values():
		if value != null:
			slotted.append(str(value))
	for echo: Dictionary in echoes:
		_list.add_child(_row(echo, slotted))
	var unequip := Button.new()
	unequip.text = "CLEAR ALL SLOTS"
	unequip.pressed.connect(func() -> void:
		for slot: String in ["echo_a", "echo_b", "mobility", "utility"]:
			BridgeClient.send_intent({"type": "slot_action", "slot": slot,
					"component_id": null}))
	_list.add_child(unequip)

## One interpretation. It may have contributed several components, and only
## the Actions among them are slottable — a trait row with an EQUIP button
## would be a button that cannot do anything.
func _row(echo: Dictionary, slotted: Array) -> Control:
	var actions: Array = []
	for operation: Dictionary in echo.get("operations", []):
		if operation.get("op", "") != "create":
			continue
		var component: Dictionary = operation.get("component", {})
		if component.get("kind", "") == "action":
			actions.append(component)
	var is_equipped := false
	for action: Dictionary in actions:
		if str(action.get("component_id", "")) in slotted:
			is_equipped = true
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var name_label := Label.new()
	var location := int(echo.get("source_location_id", 0))
	var kinds: Array = []
	for operation: Dictionary in echo.get("operations", []):
		if operation.get("op", "") == "create":
			var kind := str(operation.get("component", {}).get("kind", ""))
			if kind != "" and kind not in kinds:
				kinds.append(kind)
		elif not kinds.has(str(operation.get("op", ""))):
			kinds.append(str(operation.get("op", "")))
	name_label.text = "%s   [%s]" % [echo.get("display_name", "?"),
			" + ".join(kinds).to_upper()]
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

	# An interpretation that contributed no Action has nothing to slot, and
	# says so rather than offering a dead control. That is not a lesser
	# Echo: traits, resources and rules are on the moment they are owned.
	if actions.is_empty():
		var always := Label.new()
		always.text = "ALWAYS ON"
		always.modulate = Color(0.6, 0.95, 0.85)
		always.custom_minimum_size = Vector2(110, 0)
		always.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(always)
		return panel
	for action: Dictionary in actions:
		var component_id := str(action.get("component_id", ""))
		var here := component_id in slotted
		var button := Button.new()
		button.text = "SLOTTED" if here else "SLOT"
		button.disabled = here
		button.custom_minimum_size = Vector2(110, 0)
		button.pressed.connect(func() -> void:
			BridgeClient.send_intent({"type": "slot_action",
					"slot": action.get("slot", "echo_a"),
					"component_id": component_id}))
		row.add_child(button)
	return panel
