class_name EquipmentFace
extends Control
## H-INVENTORY (CP3): THE EQUIPMENT WALL of the pause interface
## (`04_3D_MENU_MAP_AND_GLYPH.md` §5).
##
## Three regions, the packet's starting layout, fitted to the data that
## exists rather than to a fantasy slot count:
##
##   EQUIPPED   the five keys the game has (`Constants.SLOT_NAMES`), what
##              is on each, and the consumable key's state in words.
##   OWNED      a grid of the items the campaign owns -- one tile per item,
##              never one per Echo -- with search and sort.
##   DETAIL     the selected item: what it does, how it is used, what it
##              costs, how it differs from what is on its key, why an
##              equip would be refused, then its history.
##
## **Everything is read from the bridge's own projection.**
## `CampaignSnapshot.inventory` (Dess's H-UI-DATA) is the list of items and
## the keys each goes on; `mechanics.owned` gives each its name, Mk and
## history by component id; `EquipmentQuery` answers every question with a
## right answer and this file only builds widgets from those answers.
##
## **An equip is a request, not a result.** Pressing EQUIP sends a
## `slot_action` and shows it PENDING; the key changes when a snapshot
## says it did (`EquipRequests`).
##
## **Mouse, keyboard and controller.** Every control is an ordinary
## focusable button, so arrows / d-pad move and accept presses. The non-drag
## equip is the detail's EQUIP button; drag and drop is not offered, so
## there is no drag to dangle across a page turn or a close.
##
## **PROVISIONAL ART.** Icons are a tinted square with a word; fonts and
## panels are Godot's defaults. Arty's Glyph kit (H-GLYPH-KIT) replaces
## them, and the footer says so on the wall itself.

## The page this sits on is `MenuShell.PAGE_PIXELS` (1280 x 720), under
## the shell's title.
const ORIGIN := Vector2(40, 92)
const AREA := Vector2(1200, 612)
const BUILD_WIDTH := 320.0
const OWNED_WIDTH := 440.0
const DETAIL_WIDTH := 408.0
const TILE := Vector2(140, 96)
const GRID_COLUMNS := 3

const _GOLD := Color(0.98, 0.86, 0.45)
const _NEW := Color(0.45, 0.95, 1.0)
const _DIM := Color(0.62, 0.66, 0.72)
const _WARN := Color(1.0, 0.62, 0.35)
const _OK := Color(0.5, 1.0, 0.72)

var requests := EquipRequests.new()

## The joined items of the snapshot on screen (`EquipmentQuery.items`).
var _rows: Array = []
var _selected := ""
var _slot_filter := ""
var _history_open := false
var _campaign := ""
## The last refusal that named nothing this face asked for, shown as the
## bridge's and not attributed to any key.
var _unattributed := ""
var _repaint_queued := false

var _slot_box: VBoxContainer
var _link_line: Label
var _bridge_line: Label
var _search: LineEdit
var _sort: OptionButton
var _filter_bar: HBoxContainer
var _filter_label: Label
var _owned_title: Label
var _scroll: ScrollContainer
var _grid_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
## THE DECISION STAYS IN VIEW. The equip controls and their answer sit
## under the scrolled detail, not at the end of it: a long comparison
## pushed EQUIP out of sight, and a button the player has to scroll to
## find is one a click through the box could not reach at all.
var _actions_box: VBoxContainer
var _footer: Label


func _ready() -> void:
	name = "EquipmentFace"
	position = ORIGIN
	size = AREA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 16)
	columns.size = Vector2(AREA.x, AREA.y - 36)
	add_child(columns)

	# --- EQUIPPED -------------------------------------------------------
	var build := VBoxContainer.new()
	build.name = "Equipped"
	build.custom_minimum_size = Vector2(BUILD_WIDTH, 0)
	build.add_theme_constant_override("separation", 6)
	columns.add_child(build)
	build.add_child(_heading("EQUIPPED"))
	_link_line = _small("", _WARN)
	_link_line.name = "LinkLine"
	build.add_child(_link_line)
	_slot_box = VBoxContainer.new()
	_slot_box.name = "Slots"
	_slot_box.add_theme_constant_override("separation", 6)
	build.add_child(_slot_box)
	_bridge_line = _small("", _WARN)
	_bridge_line.name = "BridgeLine"
	build.add_child(_bridge_line)

	# --- OWNED ----------------------------------------------------------
	var owned := VBoxContainer.new()
	owned.name = "Owned"
	owned.custom_minimum_size = Vector2(OWNED_WIDTH, 0)
	owned.add_theme_constant_override("separation", 6)
	columns.add_child(owned)
	_owned_title = _heading("OWNED")
	owned.add_child(_owned_title)
	# THE SEARCH BOX IS NOT IN ANYTHING A REPAINT EMPTIES. A snapshot
	# mid-word repaints the grid and the detail; the box, its text, its
	# caret and its focus are untouched because nothing frees them.
	var tools := HBoxContainer.new()
	tools.name = "Tools"
	tools.add_theme_constant_override("separation", 6)
	owned.add_child(tools)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "search name, game, item, concept…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.set_meta("focus_key", "search")
	_search.text_changed.connect(func(_t: String) -> void: _queue_repaint())
	tools.add_child(_search)
	_sort = OptionButton.new()
	_sort.name = "Sort"
	for label: String in EquipmentQuery.SORT_LABELS:
		_sort.add_item(label)
	_sort.set_meta("focus_key", "sort")
	_sort.item_selected.connect(func(_i: int) -> void: _queue_repaint())
	tools.add_child(_sort)
	_filter_bar = HBoxContainer.new()
	_filter_bar.name = "FilterBar"
	_filter_bar.add_theme_constant_override("separation", 8)
	owned.add_child(_filter_bar)
	_filter_label = _small("", _GOLD)
	_filter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_bar.add_child(_filter_label)
	var show_all := Button.new()
	show_all.name = "ShowAll"
	show_all.text = "SHOW ALL"
	show_all.set_meta("focus_key", "show_all")
	show_all.pressed.connect(func() -> void: set_slot_filter(""))
	_filter_bar.add_child(show_all)
	_scroll = ScrollContainer.new()
	_scroll.name = "GridScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A keyboard or controller moving onto a tile below the fold brings it
	# into view.
	_scroll.follow_focus = true
	owned.add_child(_scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.name = "Grid"
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("separation", 6)
	_scroll.add_child(_grid_box)

	# --- DETAIL ---------------------------------------------------------
	var detail_column := VBoxContainer.new()
	detail_column.name = "DetailColumn"
	detail_column.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	columns.add_child(detail_column)
	detail_column.add_child(_heading("DETAIL"))
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = \
			ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.follow_focus = true
	detail_column.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 5)
	_detail_scroll.add_child(_detail)
	_actions_box = VBoxContainer.new()
	_actions_box.name = "ActionsBox"
	_actions_box.add_theme_constant_override("separation", 4)
	detail_column.add_child(_actions_box)

	_footer = _small("", _DIM)
	_footer.name = "Footer"
	_footer.position = Vector2(0, AREA.y - 30)
	_footer.size = Vector2(AREA.x, 28)
	add_child(_footer)

	BridgeClient.snapshot_received.connect(_on_snapshot)
	BridgeClient.error_received.connect(_on_bridge_error)
	BridgeClient.bridge_state_changed.connect(_on_link)


# ------------------------------------------------------------ the API

func open() -> void:
	requests.forget_answers()
	_unattributed = ""
	visible = true
	rebuild()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


## Read the snapshot again and repaint, keeping what the player was doing:
## the selection, the key filter, the search text and caret, the scroll
## and the focus all survive.
func rebuild() -> void:
	var snapshot: Dictionary = BridgeClient.snapshot
	_campaign = EquipmentSeen.campaign_key(snapshot)
	_rows = EquipmentQuery.items(snapshot)
	var ids: Array = []
	for row: Dictionary in _rows:
		ids.append(str(row.get("component_id", "")))
	EquipmentSeen.baseline(_campaign, ids)
	if _selected == "" or EquipmentQuery.item_by_id(_rows, _selected).is_empty():
		_selected = _first_shown()
		if _selected != "" and visible:
			EquipmentSeen.mark_seen(_campaign, _selected)
	_repaint()


## When the wall turns to face the player: something must hold focus, or
## a keyboard or controller has nothing to move from.
func take_focus() -> void:
	if _grab("tile:" + _selected):
		return
	if _grab("slot:" + str(Constants.SLOT_NAMES[0])):
		return
	_search.grab_focus()


func select(component_id: String) -> void:
	if EquipmentQuery.item_by_id(_rows, component_id).is_empty():
		return
	_selected = component_id
	EquipmentSeen.mark_seen(_campaign, component_id)
	_queue_repaint()


func selected() -> String:
	return _selected


## Show only what goes on one key ("" for everything). Selecting a key
## also shows what is on it, so its candidates are compared against it.
func set_slot_filter(slot: String) -> void:
	_slot_filter = slot
	if slot != "":
		var holds: Variant = BridgeClient.slots().get(slot)
		if holds != null:
			_selected = str(holds)
			EquipmentSeen.mark_seen(_campaign, _selected)
	_queue_repaint()


func slot_filter() -> String:
	return _slot_filter


## THE NON-DRAG EQUIP: put the selected item on its key.
func equip_selected() -> String:
	var row := EquipmentQuery.item_by_id(_rows, _selected)
	var slot := EquipmentQuery.home_slot(row)
	if row.is_empty() or slot == "" or _equip_blocker(row) != "":
		return ""
	var state := requests.send(slot, _selected, BridgeClient.send_intent)
	_queue_repaint()
	return state


## Take the selected item off its key.
func unequip_selected() -> String:
	var row := EquipmentQuery.item_by_id(_rows, _selected)
	var slot := EquipmentQuery.equipped_in(row)
	if slot == "" or requests.is_pending(slot) or not BridgeClient.can_send():
		return ""
	var state := requests.send(slot, null, BridgeClient.send_intent)
	_queue_repaint()
	return state


func clear_slot(slot: String) -> String:
	if requests.is_pending(slot) or not BridgeClient.can_send():
		return ""
	var state := requests.send(slot, null, BridgeClient.send_intent)
	_queue_repaint()
	return state


func search_box() -> LineEdit:
	return _search


## Every tile on the grid right now, by component id.
func tiles() -> Dictionary:
	var out := {}
	for node: Node in _grid_box.find_children("Tile_*", "Button", true,
			false):
		out[str(node.get_meta("component_id", ""))] = node
	return out


## The whole DETAIL column: the scrolled summary and the fixed controls.
func detail_root() -> Control:
	return _detail.get_parent().get_parent() as Control


## Everything a repaint empties and fills again.
func repainted() -> Array:
	return [_slot_box, _grid_box, _detail, _actions_box]


func slot_rows() -> VBoxContainer:
	return _slot_box


# ------------------------------------------------------------ signals

func _on_snapshot(snapshot: Dictionary) -> void:
	# The requests are answered whether or not the wall is showing: an
	# equip made just before closing lands after it.
	var slots: Variant = snapshot.get("slots")
	requests.on_snapshot(slots if typeof(slots) == TYPE_DICTIONARY else {})
	if visible:
		rebuild()


func _on_bridge_error(err: Dictionary) -> void:
	if requests.on_error(err) == "":
		# NOT ATTRIBUTED. Empty `about` means unchecked; it is shown as the
		# bridge's own latest refusal and resolves nothing here.
		_unattributed = str(err.get("message", ""))
	if visible:
		_queue_repaint()


func _on_link(online: bool) -> void:
	if not online:
		requests.on_link_lost()
	if visible:
		_queue_repaint()


# ------------------------------------------------------------ painting

func _queue_repaint() -> void:
	if _repaint_queued:
		return
	_repaint_queued = true
	_repaint_deferred.call_deferred()


func _repaint_deferred() -> void:
	_repaint_queued = false
	if is_inside_tree():
		_repaint()


func _repaint() -> void:
	var focus_key := _focus_key()
	var scroll := _scroll.scroll_vertical
	_paint_slots()
	_paint_grid()
	_paint_detail()
	_paint_lines()
	_scroll.scroll_vertical = scroll
	if focus_key != "" and focus_key != "search" and focus_key != "sort":
		_grab(focus_key)


func _paint_slots() -> void:
	_empty(_slot_box)
	var online := BridgeClient.can_send()
	for slot: String in Constants.SLOT_NAMES:
		_slot_box.add_child(_slot_row(slot, online))


func _slot_row(slot: String, online: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Slot_%s" % slot
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	box.add_child(line)

	var key := Button.new()
	key.name = "Key"
	key.text = SlotKeycaps.of(slot)
	key.custom_minimum_size = Vector2(72, 40)
	key.toggle_mode = true
	key.button_pressed = _slot_filter == slot
	key.tooltip_text = "show what goes on this key"
	key.set_meta("focus_key", "slot:" + slot)
	key.set_meta("slot", slot)
	key.pressed.connect(func() -> void:
		set_slot_filter("" if _slot_filter == slot else slot))
	line.add_child(key)

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	words.add_child(_small(EquipmentQuery.slot_title(slot), _DIM))
	var holds: Variant = BridgeClient.slots().get(slot)
	var row := EquipmentQuery.item_by_id(_rows,
			"" if holds == null else str(holds))
	var what := Label.new()
	what.name = "Holds"
	what.add_theme_font_size_override("font_size", 18)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if row.is_empty():
		what.text = "—"
		what.modulate = _DIM
	else:
		var mk := int(row.get("mk", 1))
		what.text = EquipmentQuery.name_of(row) \
				+ ("  Mk %s" % EquipmentQuery.mk_roman(mk) if mk > 1 else "")
	words.add_child(what)

	if not row.is_empty():
		var drop := Button.new()
		drop.name = "Clear"
		drop.text = "✕"
		drop.custom_minimum_size = Vector2(36, 40)
		drop.tooltip_text = "take it off this key"
		drop.disabled = not online or requests.is_pending(slot)
		drop.set_meta("focus_key", "clear:" + slot)
		drop.pressed.connect(func() -> void: clear_slot(slot))
		line.add_child(drop)

	# THE CONSUMABLE KEY SAYS WHICH OF ITS STATES IT IS IN, in words and
	# with its count, on the key itself.
	if slot == "consumable":
		var cid := "" if holds == null else str(holds)
		var state := EquipmentQuery.consumable_state(_rows, holds,
				BridgeClient.charges_left(cid) if cid != "" else 0,
				BridgeClient.awaiting_authorization(cid) if cid != "" else 0,
				online)
		panel.set_meta("consumable_state", state["state"])
		if str(state["count"]) != "":
			what.text += "     " + str(state["count"])
			if state["state"] == "equipped_empty":
				what.modulate = _WARN
		if str(state["text"]) != "":
			var said := _small(str(state["text"]),
					_WARN if state["state"] in ["equipped_empty",
						"disconnected"] else _DIM)
			said.name = "ConsumableState"
			box.add_child(said)

	var status := _request_line(slot)
	if status != null:
		box.add_child(status)
	return panel


## What happened to the latest request for a key, if anything.
func _request_line(slot: String) -> Label:
	var pending := requests.pending(slot)
	if not pending.is_empty():
		var label := _small("→ %s: sent, waiting for the bridge" % _request_what(
				pending.get("component_id")), _GOLD)
		label.name = "Request"
		label.set_meta("request_state", EquipRequests.PENDING)
		return label
	var answer := requests.answer(slot)
	if answer.is_empty():
		return null
	var what := _request_what(answer.get("component_id"))
	var text := ""
	var tint := _DIM
	match str(answer["state"]):
		EquipRequests.ACCEPTED:
			text = "✓ %s: the bridge confirmed it" % what
			tint = _OK
		EquipRequests.REFUSED:
			text = "✗ %s: refused — %s" % [what, answer["message"]]
			tint = _WARN
		EquipRequests.NOT_SENT:
			text = "✗ %s: not sent — no link to the bridge" % what
			tint = _WARN
		EquipRequests.LOST:
			text = "? %s: the link dropped before the bridge answered. " \
					% what + "This shows what it last confirmed."
			tint = _WARN
	var label := _small(text, tint)
	label.name = "Request"
	label.set_meta("request_state", str(answer["state"]))
	return label


func _request_what(component_id: Variant) -> String:
	if component_id == null:
		return "clear the key"
	var row := EquipmentQuery.item_by_id(_rows, str(component_id))
	return EquipmentQuery.name_of(row) if not row.is_empty() \
			else str(component_id)


func _paint_grid() -> void:
	_empty(_grid_box)
	var found := EquipmentQuery.grid(_rows, _search.text, _sort.selected,
			_slot_filter)
	var slotted: Array = found["slotted"]
	var always: Array = found["always_on"]
	var fresh := 0
	for row: Dictionary in _rows:
		if EquipmentSeen.is_new(_campaign, str(row.get("component_id", ""))):
			fresh += 1
	_owned_title.text = "OWNED" + ("   %d NEW" % fresh if fresh > 0 else "")

	_filter_bar.visible = _slot_filter != ""
	if _slot_filter != "":
		_filter_label.text = "Showing what goes on %s (%s). Always-on " % [
				SlotKeycaps.of(_slot_filter),
				EquipmentQuery.slot_title(_slot_filter)] \
				+ "items are hidden."

	if _rows.is_empty():
		_grid_box.add_child(_small("Nothing owned yet. Echoes arrive when "
				+ "other players find your items.", _DIM))
		return
	_grid_box.add_child(_section("ON A KEY", slotted.size(),
			int(found["total_slotted"])))
	if slotted.is_empty():
		_grid_box.add_child(_small(_nothing_here(), _DIM))
	else:
		_grid_box.add_child(_tile_grid(slotted))
	# ONE RULE, IN ONE PLACE. `EquipmentQuery.grid` decides that a key
	# filter hides the always-on half; this draws what it returns. A
	# second guard here masked a broken query (EI-6).
	if _slot_filter == "" or not always.is_empty():
		_grid_box.add_child(_section("ALWAYS ON", always.size(),
				int(found["total_always_on"])))
		if not always.is_empty():
			_grid_box.add_child(_tile_grid(always))


func _nothing_here() -> String:
	if _slot_filter != "":
		return "Nothing you own goes on %s." % SlotKeycaps.of(_slot_filter)
	return "Nothing matches “%s”." % _search.text.strip_edges()


func _section(text: String, shown: int, total: int) -> Label:
	# "3 of 19", not "3": a count of what survived the filter, alone,
	# looks exactly like owning three.
	var label := _small(("%s (%d)" % [text, total]) if shown == total
			else ("%s (%d of %d)" % [text, shown, total]), _DIM)
	label.name = "Section"
	label.set_meta("role", "section")
	label.add_theme_font_size_override("font_size", 15)
	return label


func _tile_grid(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for row: Dictionary in rows:
		grid.add_child(_tile(row))
	return grid


func _tile(row: Dictionary) -> Button:
	var cid := str(row.get("component_id", ""))
	var tile := Button.new()
	tile.name = "Tile_%s" % cid
	tile.custom_minimum_size = TILE
	tile.toggle_mode = true
	tile.button_pressed = cid == _selected
	tile.set_meta("component_id", cid)
	tile.set_meta("focus_key", "tile:" + cid)
	tile.tooltip_text = EquipmentQuery.name_of(row)
	tile.pressed.connect(func() -> void: select(cid))

	var icon := ItemIcon.new(EquipmentQuery.family(row),
			ThemeMaterials.color_for_game(EquipmentQuery.source_game(row)))
	icon.position = Vector2(8, 8)
	icon.size = Vector2(40, 40)
	tile.add_child(icon)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = EquipmentQuery.name_of(row)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.position = Vector2(54, 4)
	name_label.size = Vector2(TILE.x - 58, 46)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_label)

	var marks: PackedStringArray = []
	var mk := int(row.get("mk", 1))
	if mk > 1:
		marks.append("Mk " + EquipmentQuery.mk_roman(mk))
	if EquipmentQuery.is_consumable(row):
		marks.append("%d/%d" % [int(row.get("charges_left", 0)),
				int(row.get("charges_max", 0))])
	var on := EquipmentQuery.equipped_in(row)
	if on != "":
		marks.append("ON " + SlotKeycaps.of(on))
	var is_new := EquipmentSeen.is_new(_campaign, cid)
	if is_new:
		marks.append("NEW")
	var badges := Label.new()
	badges.name = "Badges"
	badges.text = " · ".join(marks)
	badges.position = Vector2(8, 54)
	badges.size = Vector2(TILE.x - 12, 38)
	badges.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badges.add_theme_font_size_override("font_size", 13)
	badges.modulate = _NEW if is_new else (_GOLD if on != "" else _DIM)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(badges)
	return tile


func _paint_detail() -> void:
	_empty(_detail)
	_empty(_actions_box)
	var row := EquipmentQuery.item_by_id(_rows, _selected)
	if row.is_empty():
		_detail.add_child(_body("Select an item to see what it does.", _DIM))
		return
	var cid := _selected
	var component: Dictionary = row.get("component", {})

	var title := Label.new()
	title.name = "ItemName"
	title.text = EquipmentQuery.name_of(row)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	_detail.add_child(title)
	var marks: PackedStringArray = [EquipmentQuery.kind_of(row).to_upper()
			+ " · " + EquipmentQuery.family(row)]
	var mk := int(row.get("mk", 1))
	if mk > 1:
		marks.append("Mk " + EquipmentQuery.mk_roman(mk))
	var on := EquipmentQuery.equipped_in(row)
	if on != "":
		marks.append("ON " + SlotKeycaps.of(on))
	if EquipmentSeen.is_new(_campaign, cid):
		marks.append("NEW")
	_detail.add_child(_small("  ·  ".join(marks), _GOLD if on != "" else _DIM))
	_detail.add_child(_body(str(component.get("description", "")),
			Color.WHITE))

	_block("WHAT IT DOES", EquipmentQuery.does(row), Color(0.6, 0.95, 0.85))
	_block("HOW IT IS USED", EquipmentQuery.use_lines(row, _rows),
			Color.WHITE)
	var costs := EquipmentQuery.cost_lines(row)
	if EquipmentQuery.is_consumable(row):
		costs.push_front("%d of %d uses left." % [
				int(row.get("charges_left", 0)),
				int(row.get("charges_max", 0))])
	_block("WHAT IT COSTS", costs, Color.WHITE)

	# DIFFERENCES FROM WHAT IS ON ITS KEY, where the decision is made.
	var home := EquipmentQuery.home_slot(row)
	if home != "" and on == "":
		var holds: Variant = BridgeClient.slots().get(home)
		var occupant := EquipmentQuery.item_by_id(_rows,
				"" if holds == null else str(holds))
		if not occupant.is_empty():
			_block("AGAINST %s ON %s" % [
					EquipmentQuery.name_of(occupant).to_upper(),
					SlotKeycaps.of(home)],
					EquipmentQuery.comparison(row, occupant), _GOLD)

	_paint_actions(row)

	var siblings: Array = row.get("siblings", [])
	if not siblings.is_empty():
		var names: PackedStringArray = []
		for sibling: Variant in siblings:
			var other := EquipmentQuery.item_by_id(_rows, str(sibling))
			if not other.is_empty():
				names.append("%s (%s)" % [EquipmentQuery.name_of(other),
						"always on" if not EquipmentQuery.is_slotted(other)
						else "on " + SlotKeycaps.of(
							EquipmentQuery.home_slot(other))])
		if not names.is_empty():
			_block("ALSO FROM THE SAME ECHO", Array(names), _DIM)

	var history := EquipmentQuery.history(row)
	var toggle := Button.new()
	toggle.name = "History"
	toggle.text = ("HISTORY ▾" if _history_open else "HISTORY ▸") \
			+ "  (%d)" % history.size()
	toggle.set_meta("focus_key", "history")
	toggle.pressed.connect(func() -> void:
		_history_open = not _history_open
		_queue_repaint())
	_detail.add_child(toggle)
	if _history_open:
		for link: Dictionary in history:
			var line := _small("%s  %s ← %s  (%s)" % [link["mark"],
					link["note"], link["item"], link["game"]],
					ThemeMaterials.color_for_game(str(link["game"])).lerp(
						Color.WHITE, 0.35))
			line.name = "HistoryRow"
			line.set_meta("role", "history")
			_detail.add_child(line)
		for read: String in EquipmentQuery.read_lines(row):
			var said := _small(read, Color(0.78, 0.7, 0.95))
			said.name = "ReadRow"
			said.set_meta("role", "read")
			_detail.add_child(said)


## The equip controls and why any of them is not offered.
func _paint_actions(row: Dictionary) -> void:
	var cid := str(row.get("component_id", ""))
	var home := EquipmentQuery.home_slot(row)
	var on := EquipmentQuery.equipped_in(row)
	if not EquipmentQuery.is_slotted(row):
		# Passive is not toggleable (04 §5): no control, and the reason.
		var why := _body(EquipmentQuery.refusal(row, ""), _DIM)
		why.name = "WhyNot"
		_actions_box.add_child(why)
		return
	var bar := HBoxContainer.new()
	bar.name = "Actions"
	bar.add_theme_constant_override("separation", 8)
	_actions_box.add_child(bar)
	if on != "":
		var off := Button.new()
		off.name = "Unequip"
		off.text = "TAKE OFF %s" % SlotKeycaps.of(on)
		off.disabled = requests.is_pending(on) or not BridgeClient.can_send()
		off.set_meta("focus_key", "unequip")
		off.pressed.connect(func() -> void: unequip_selected())
		bar.add_child(off)
	else:
		var holds: Variant = BridgeClient.slots().get(home)
		var occupant := EquipmentQuery.item_by_id(_rows,
				"" if holds == null else str(holds))
		var put := Button.new()
		put.name = "Equip"
		put.text = ("REPLACE %s ON %s" % [
				EquipmentQuery.name_of(occupant).to_upper(),
				SlotKeycaps.of(home)]) if not occupant.is_empty() \
				else "EQUIP ON %s" % SlotKeycaps.of(home)
		var blocker := _equip_blocker(row)
		put.disabled = blocker != ""
		put.set_meta("focus_key", "equip")
		put.pressed.connect(func() -> void: equip_selected())
		bar.add_child(put)
		if blocker != "":
			var why := _body(blocker, _WARN)
			why.name = "WhyNot"
			_actions_box.add_child(why)
	# Favourites (§9): which Actions the wheel cycles. A client preference.
	var star := Button.new()
	star.name = "Favourite"
	star.toggle_mode = true
	star.button_pressed = Favourites.is_favourite(cid)
	star.text = ("★" if star.button_pressed else "☆") + " WHEEL"
	star.tooltip_text = "cycle this one with the wheel"
	star.set_meta("focus_key", "favourite")
	star.toggled.connect(func(_on: bool) -> void:
		Favourites.toggle(cid)
		_queue_repaint())
	bar.add_child(star)
	var status := _request_line(on if on != "" else home)
	if status != null:
		_actions_box.add_child(status)


## Why EQUIP is not offered right now, or "".
func _equip_blocker(row: Dictionary) -> String:
	var home := EquipmentQuery.home_slot(row)
	var refused := EquipmentQuery.refusal(row, home)
	if refused != "":
		return refused
	var held := EquipmentQuery.held_back(row)
	if held != "":
		return held
	if not BridgeClient.can_send():
		return "Offline: a change of equipment needs the bridge's answer."
	if requests.is_pending(home):
		return "Waiting for the bridge's answer about %s." \
				% SlotKeycaps.of(home)
	return ""


func _paint_lines() -> void:
	var online := BridgeClient.can_send()
	_link_line.text = "" if online else "OFFLINE — the keys show what the " \
			+ "bridge last confirmed. Changes wait for the link."
	_link_line.visible = not online
	_bridge_line.text = "" if _unattributed == "" \
			else "The bridge refused a request: %s" % _unattributed
	_bridge_line.visible = _unattributed != ""
	_footer.text = "[%s] / [%s] turn the box   [%s] close   arrows or " % [
			SlotKeycaps.of_action("menu_page_left"),
			SlotKeycaps.of_action("menu_page_right"),
			SlotKeycaps.of_action("pause")] \
			+ "d-pad move, [%s] choose   ·   PROVISIONAL ART: the Glyph " \
			% SlotKeycaps.of_action("ui_accept") \
			+ "kit (H-GLYPH-KIT) replaces these icons, fonts and panels."


func _block(title: String, lines: Array, tint: Color) -> void:
	if lines.is_empty():
		return
	var heading := _small(title, _DIM)
	heading.name = "Heading"
	_detail.add_child(heading)
	for line: Variant in lines:
		_detail.add_child(_body(str(line), tint))


# ------------------------------------------------------------ helpers

func _first_shown() -> String:
	var found := EquipmentQuery.grid(_rows, "", _sort.selected
			if _sort != null else 0, "")
	for key: String in ["slotted", "always_on"]:
		var rows: Array = found[key]
		if not rows.is_empty():
			return str((rows[0] as Dictionary).get("component_id", ""))
	return ""


func _focus_key() -> String:
	if not is_inside_tree():
		return ""
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not is_ancestor_of(owner):
		return ""
	return str(owner.get_meta("focus_key", ""))


func _grab(focus_key: String) -> bool:
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control.get_meta("focus_key", "") == focus_key \
				and control.is_visible_in_tree() \
				and control.focus_mode != Control.FOCUS_NONE:
			control.grab_focus()
			return true
	return false


## Out of the tree now (so nothing reads a stale child this frame), freed
## at the end of it (so a button can be repainted from its own press).
func _empty(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color(0.85, 0.88, 0.95)
	return label


## A number keeps its unit on its line: "1.5 s" wrapped as "1.5" and a
## lone "s" below it. The data keeps its ordinary spaces; only what is
## drawn gets the no-break one.
static var _units: RegEx = null

static func _keep_units(text: String) -> String:
	if _units == null:
		_units = RegEx.create_from_string(
				"(\\d) (s|m|m/s|HP|°)(?=[\\s.,)]|$)")
	return _units.sub(text, "$1\u00a0$2", true)


func _small(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.text = _keep_units(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = tint
	return label


func _body(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.text = _keep_units(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = tint
	return label


## PROVISIONAL: a tinted square and a word, until Glyph's icon set.
class ItemIcon extends Control:
	var word := ""
	var tint := Color.GRAY

	func _init(label: String, colour: Color) -> void:
		word = label
		tint = colour
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(40, 40)

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, tint.darkened(0.6))
		draw_rect(box, tint, false, 2.0)
		var font := get_theme_default_font()
		var font_size := 10
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size).x
		draw_string(font, Vector2((size.x - width) * 0.5,
				size.y * 0.5 + font_size * 0.35), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
