class_name JournalFace
extends Control
## H-JOURNAL (CP4, `04` §8): THE JOURNAL WALL.
##
## Two columns, from the snapshot alone (`JournalQuery` holds every rule):
## - left: the objectives (the Hub's words; in a Zone, its Checks), what
##   you did here (the Zone's record, and what each thing opened), and
##   what is still shut (the bridge's map, with its reasons);
## - right: the places found, by the bridge's names, and the notes: each
##   Echo's read, newest first, earned by a Check.
##
## Nothing is invented and nothing unfound is named: a room the bridge's
## map does not name stays "a way not yet walked".
##
## **Keys:** Up and Down, PgUp and PgDn, and the d-pad's up and down
## scroll it; the wheel does too. The page turns are the shell's.
##
## PROVISIONAL ART: Godot's default font and plain panels, until Glyph's
## kit (H-GLYPH-KIT).

const ORIGIN := Vector2(40, 92)
const AREA := Vector2(1170, 612)
const COLUMN := 560.0
const SCROLL_STEP := 60.0

var _scroll: ScrollContainer
var _left: VBoxContainer
var _right: VBoxContainer
## How many times the wall has been filled: a snapshot refills it.
var fills := 0


func _ready() -> void:
	name = "JournalFace"
	position = ORIGIN
	size = AREA
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size = AREA
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var row := HBoxContainer.new()
	row.name = "Columns"
	row.add_theme_constant_override("separation", 40)
	_scroll.add_child(row)
	_left = _column(row, "Left")
	_right = _column(row, "Right")
	BridgeClient.snapshot_received.connect(_on_snapshot)
	BridgeClient.bridge_state_changed.connect(_on_link)
	fill()


func _column(parent: Control, node_name: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.custom_minimum_size = Vector2(COLUMN, 0)
	column.add_theme_constant_override("separation", 6)
	parent.add_child(column)
	return column


## Fill both columns from what the client holds now.
func fill() -> void:
	if _left == null:
		return
	var snapshot: Dictionary = BridgeClient.snapshot
	for column: VBoxContainer in [_left, _right]:
		for child: Node in column.get_children():
			column.remove_child(child)
			child.queue_free()
	_section(_left, "OBJECTIVES", JournalQuery.objectives(snapshot),
			"No campaign yet.")
	var in_zone := not JournalQuery.active_zone(snapshot).is_empty()
	_section(_left, "WHAT YOU DID HERE", JournalQuery.done_here(snapshot),
			"Nothing yet." if in_zone else "You are not in a Zone.")
	if in_zone:
		_section(_left, "STILL SHUT", JournalQuery.still_shut(snapshot),
				"Nothing you have found is shut.")
	_section(_right, "PLACES FOUND", JournalQuery.places(snapshot),
			"Places are listed inside a Zone." if not in_zone
				else "None yet.")
	_notes(JournalQuery.notes(BridgeClient.interpretations()))
	fills += 1


## Every line on the wall, in order: for the suite, and for anything that
## has to ask what the journal says.
func lines() -> Array:
	var out: Array = []
	for column: VBoxContainer in [_left, _right]:
		for node: Node in column.find_children("*", "Label", true, false):
			out.append((node as Label).text)
	return out


## The lines of one section, by its heading.
func section(heading: String) -> Array:
	for column: VBoxContainer in [_left, _right]:
		var box := column.get_node_or_null(heading.replace(" ", "_"))
		if box != null:
			var out: Array = []
			for node: Node in box.get_children():
				if node is Label and str(node.name) != "Heading":
					out.append((node as Label).text)
			return out
	return []


func scroll() -> ScrollContainer:
	return _scroll


func _section(column: VBoxContainer, heading: String, rows: Array,
		empty: String) -> void:
	var box := VBoxContainer.new()
	box.name = heading.replace(" ", "_")
	box.add_theme_constant_override("separation", 4)
	column.add_child(box)
	var title := _label(box, "Heading", heading, 18)
	title.modulate = Color(0.8, 0.85, 0.9)
	if rows.is_empty():
		_label(box, "Empty", empty, 16).modulate = Color(0.7, 0.7, 0.7)
		return
	for i in rows.size():
		_label(box, "Line%d" % i, str(rows[i]), 16)


func _notes(rows: Array) -> void:
	var box := VBoxContainer.new()
	box.name = "NOTES"
	box.add_theme_constant_override("separation", 4)
	_right.add_child(box)
	var title := _label(box, "Heading", "NOTES", 18)
	title.modulate = Color(0.8, 0.85, 0.9)
	if rows.is_empty():
		_label(box, "Empty", "None yet: every Check you claim brings one.",
				16).modulate = Color(0.7, 0.7, 0.7)
		return
	for i in rows.size():
		var row: Dictionary = rows[i]
		_label(box, "Title%d" % i, str(row["title"]), 17)
		_label(box, "Line%d" % i, str(row["text"]), 16)
		if str(row["source"]) != "":
			_label(box, "Source%d" % i, str(row["source"]), 14) \
					.modulate = Color(0.7, 0.72, 0.75)


func _label(parent: Control, node_name: String, text: String,
		font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(COLUMN, 0)
	parent.add_child(label)
	return label


## Up/Down and PgUp/PgDn scroll, as do the d-pad's up and down. Events
## reach this only while the journal is the page facing the camera.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var step := 0.0
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_UP:
				step = -SCROLL_STEP
			KEY_DOWN:
				step = SCROLL_STEP
			KEY_PAGEUP:
				step = -AREA.y * 0.8
			KEY_PAGEDOWN:
				step = AREA.y * 0.8
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP:
				step = -SCROLL_STEP
			JOY_BUTTON_DPAD_DOWN:
				step = SCROLL_STEP
	if step != 0.0:
		_scroll.scroll_vertical = int(_scroll.scroll_vertical + step)
		get_viewport().set_input_as_handled()


func _on_snapshot(_snapshot: Dictionary) -> void:
	fill()


func _on_link(_online: bool) -> void:
	fill()
