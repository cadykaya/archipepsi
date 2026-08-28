class_name ShopUI
extends CanvasLayer
## The Hub shop: QUESTIONABLE GOODS. Stock is real unchecked Archipelago
## locations; buying completes the location and sends the real item to its
## real recipient. Everything shown comes from the snapshot; the bridge
## verifies every purchase.

signal closed

var _list: VBoxContainer
var _title: Label
var _balance: Label

func _ready() -> void:
	layer = 8
	visible = false
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 420)
	UILayout.centred(self, panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.text = "QUESTIONABLE GOODS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.modulate = Color(0.95, 0.8, 0.35)
	box.add_child(_title)
	_balance = Label.new()
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_balance)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	var hint := Label.new()
	hint.text = "Buying completes the real Archipelago location.\n"
	hint.text += "The recipient gets their item; you get the Echo. [Esc] close"
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
	var snapshot := BridgeClient.snapshot
	var coins := int(snapshot.get("coins_available", 0))
	_balance.text = "BALANCE: %d EPSILON COIN%s" % [coins,
			"" if coins == 1 else "S"]
	var stock: Array = snapshot.get("shop", {}).get("stock", [])
	var pending_purchases := _pending_shop_locations()

	if stock.is_empty() and pending_purchases.is_empty():
		var empty := Label.new()
		var mode := BridgeClient.hub_mode()
		if mode == "WAITING_FOR_AP":
			empty.text = "NOTHING LEFT TO SELL YOU"
		elif int(snapshot.get("completed_zone_count", 0)) < 2:
			empty.text = ("OUT OF QUESTIONABLE GOODS\n"
					+ "(stock appears after 2 completed Zones)")
		else:
			empty.text = "OUT OF QUESTIONABLE GOODS"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
		return

	for item: Dictionary in stock:
		_list.add_child(_row(item, coins))
	for location in pending_purchases:
		_list.add_child(_pending_row(location))

func _pending_shop_locations() -> Array:
	var out: Array = []
	for pending: Dictionary in BridgeClient.snapshot.get("pending_checks", []):
		if pending.get("source") == "shop":
			out.append(int(pending.get("location_id", 0)))
	return out

func _row(item: Dictionary, coins: int) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var location := int(item.get("location_id", 0))
	var name_label := Label.new()
	name_label.text = str(item.get("item_name", "?"))
	name_label.add_theme_font_size_override("font_size", 20)
	text_box.add_child(name_label)
	var detail := Label.new()
	detail.text = "Check %03d — for %s (%s)" % [location % 1000,
			item.get("recipient_name", "?"), item.get("recipient_game", "?")]
	detail.modulate = Color(0.65, 0.75, 0.8)
	detail.add_theme_font_size_override("font_size", 15)
	text_box.add_child(detail)

	var cost := int(item.get("cost", 0))
	var button := Button.new()
	button.text = "%d COINS" % cost
	button.custom_minimum_size = Vector2(120, 0)
	if coins < cost:
		button.disabled = true
		button.tooltip_text = "Not enough Epsilon Coins"
	button.pressed.connect(func() -> void:
		button.disabled = true
		BridgeClient.send_intent({"type": "buy_shop_stock",
				"location_id": location}))
	row.add_child(button)
	return panel

func _pending_row(location: int) -> Control:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = "Check %03d — SENDING…" % (location % 1000)
	label.modulate = Color(1.0, 0.9, 0.4)
	panel.add_child(label)
	return panel
