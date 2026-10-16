class_name ForgeScreen
extends CanvasLayer
## THE FORGE (D-22 slice): where a Crossing is constructed with Epsilon.
##
## `docs/D22_SLICE_BRIEF.md` §2 steps 2, 3, 5 and 6. One screen, reused by
## both station areas' consoles. It renders `snapshot.forge` and the offered
## Zone, and it decides nothing the bridge has not already decided:
##
## * the signals are the bridge's list of tracks that still have eligible
##   Checks, with the cursor's own pick pre-selected;
## * the draft card is read from the offered Zone itself -- its name and
##   note as Epsilon's words, then counts and names out of its chambers.
##   Nothing is hidden and nothing is invented that the Zone does not
##   contain;
## * REDRAW is offered only while the bridge says redraws are left, and the
##   bridge refuses one anyway after the first entry;
## * RESUME and the Untethered list are the bridge's `resume` and
##   `untethered`, which are DORMANT and COMPLETE records.
##
## Only exists in a slice run: `D22Slice.active()` is the bridge's own
## `forge` view being present in the snapshot.

signal accept_requested
signal closed

const SIGNAL_COLOUR := Color(0.55, 0.9, 1.0)
const EPSILON_COLOUR := Color(0.95, 0.75, 1.0)
const FACT_COLOUR := Color(0.8, 0.84, 0.88)
const QUIET := Color(0.58, 0.62, 0.68)
## Seconds between the card's rows as Epsilon lays them down. Short: the
## point is to watch the rooms arrive, not to wait for them.
const REVEAL_STEP := 0.32

const _DRAFTING_LINES := [
	"Pinning the Checks to the frame…",
	"Laying out rooms around them…",
	"Proving every Check can be reached…",
]

var area := 1
var _title: Label
var _body: VBoxContainer
var _actions: HBoxContainer
var _footer: Label
var _picked := ""
## The draft on the card, as `zone_id#redraw`, so a redraw (same id) still
## reads as a new draft and replays the reveal.
var _shown_draft := ""
var _reveal_rows: Array[Control] = []
var _reveal_clock := 0.0
var _drafting_clock := 0.0
var _drafting_label: Label = null
## Latched by a press, cleared by the next snapshot: a double click must
## not send two requests or two redraws.
var _sent := false


func _ready() -> void:
	layer = 8
	visible = false
	var panel := UILayout.reading_panel(Vector2(760, 560))
	UILayout.centred(self, panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.modulate = Color(1.0, 0.78, 0.4)
	box.add_child(_title)
	var scroll := UILayout.reading_scroll(Vector2(720, 380))
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)
	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 18)
	box.add_child(_actions)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.modulate = QUIET
	box.add_child(_footer)


func open(at_area: int) -> void:
	area = at_area
	_sent = false
	_picked = ""
	visible = true
	rebuild()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


## The signal the screen will send, for a driver standing where a player
## would. Empty until the bridge has offered one.
func picked_signal() -> String:
	return _picked


## Called on every snapshot while open. Rebuilding is cheap and keeps the
## screen from ever showing a state the bridge has left.
func rebuild() -> void:
	if not visible:
		return
	_sent = false
	for child in _body.get_children():
		child.queue_free()
	for child in _actions.get_children():
		child.queue_free()
	_reveal_rows.clear()
	_drafting_label = null
	_title.text = "THE FORGE — STATION AREA %d" % area
	var forge := D22Slice.forge()
	if forge.is_empty():
		_line("The bridge is not running the slice; nothing to forge.",
				QUIET)
		_footer.text = "[Esc] step away"
		return
	var mode := BridgeClient.hub_mode()
	match mode:
		"ZONE_AVAILABLE":
			_build_signals(forge)
		"GENERATING":
			_build_drafting()
		"ZONE_READY":
			_build_card(forge)
		"ZONE_DORMANT", "ZONE_ACTIVE":
			_build_resume(forge)
		"ZONE_FAILED":
			_line("This draft cannot be built. Discard it at the console "
					+ "beside the Forge.", Color(1.0, 0.6, 0.45))
		_:
			_line("The Forge has nothing to offer right now (%s)."
					% mode.to_lower().replace("_", " "), QUIET)
	_build_untethered(forge)
	_footer.text = _footer_for(mode)


func _process(delta: float) -> void:
	if not visible:
		return
	if not _reveal_rows.is_empty():
		_reveal_clock += delta
		var shown := int(_reveal_clock / REVEAL_STEP) + 1
		for i in _reveal_rows.size():
			if is_instance_valid(_reveal_rows[i]):
				_reveal_rows[i].visible = i < shown
		if shown >= _reveal_rows.size():
			_reveal_rows.clear()
			_set_actions_enabled(true)
	if _drafting_label != null and is_instance_valid(_drafting_label):
		_drafting_clock += delta
		var line := int(_drafting_clock / 1.4) % _DRAFTING_LINES.size()
		_drafting_label.text = "EPSILON:  " + str(_DRAFTING_LINES[line])


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


# -- the four states ---------------------------------------------------------

func _build_signals(forge: Dictionary) -> void:
	var signals: Array = forge.get("signals", [])
	if signals.is_empty():
		_line("No signal has an eligible Check left.", QUIET)
		return
	if _picked == "" or not _has_signal(signals, _picked):
		_picked = str(forge.get("default_track", ""))
	_line("EPSILON:  Pick a signal and I will draft a Crossing around it.",
			EPSILON_COLOUR)
	_line("SIGNALS WITH CHECKS STILL OPEN", QUIET)
	var group := ButtonGroup.new()
	for raw: Variant in signals:
		var entry: Dictionary = raw
		var track := str(entry.get("track", ""))
		var eligible := int(entry.get("eligible", 0))
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "  %s   ·   %d Check%s open%s" % [track, eligible,
				"" if eligible == 1 else "s",
				"   (cursor)" if track == str(forge.get("default_track", ""))
				else ""]
		button.button_pressed = track == _picked
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_picked = track)
		_body.add_child(button)
	var draft := Button.new()
	draft.text = "  DRAFT WITH EPSILON  "
	draft.pressed.connect(request_draft)
	_actions.add_child(draft)


func _build_drafting() -> void:
	var record := BridgeClient.active_zone()
	var ids: Array = record.get("allocated_location_ids", [])
	var target := str(record.get("target_game", ""))
	var redraw := int(record.get("redraw_count", 0))
	if redraw > 0:
		_line("EPSILON:  Fine. Tearing it up. Same Checks, new rooms.",
				EPSILON_COLOUR)
	_line("SIGNAL  %s" % target, SIGNAL_COLOUR)
	_line("%d Check%s bound to this frame" % [ids.size(),
			"" if ids.size() == 1 else "s"], FACT_COLOUR)
	_drafting_label = _line("", EPSILON_COLOUR)
	_drafting_clock = 0.0


func _build_card(forge: Dictionary) -> void:
	var record := BridgeClient.active_zone()
	var zone: Dictionary = record.get("zone", {}) \
			if typeof(record.get("zone")) == TYPE_DICTIONARY else {}
	if zone.is_empty():
		_line("The draft has not arrived yet.", QUIET)
		return
	var key := "%s#%d" % [str(record.get("zone_id", "")),
			int(record.get("redraw_count", 0))]
	var fresh := key != _shown_draft
	_shown_draft = key
	var rows := draft_card_rows(record)
	for row: Dictionary in rows:
		var label := _line(str(row["text"]), row["colour"])
		if fresh:
			label.visible = false
			_reveal_rows.append(label)
	_reveal_clock = 0.0
	var accept := Button.new()
	accept.text = "  ACCEPT — ENTER THE CROSSING  "
	accept.pressed.connect(accept_draft)
	_actions.add_child(accept)
	var left := int(forge.get("redraws_left", 0))
	if left > 0:
		var redraw := Button.new()
		redraw.text = "  REDRAW (%d left)  " % left
		redraw.pressed.connect(request_redraw)
		_actions.add_child(redraw)
	_set_actions_enabled(not fresh)


func _build_resume(forge: Dictionary) -> void:
	var resume: Variant = forge.get("resume")
	if typeof(resume) != TYPE_DICTIONARY:
		_line("A Crossing is open but the bridge names none to resume.",
				QUIET)
		return
	var name := str((resume as Dictionary).get("display_name", ""))
	var remaining := int((resume as Dictionary).get("remaining", 0))
	_line("EPSILON:  It is still where you left it. Tethered, and waiting.",
			EPSILON_COLOUR)
	_line("%s  —  %d transfer%s remain%s" % [name, remaining,
			"" if remaining == 1 else "s", "s" if remaining == 1 else ""],
			FACT_COLOUR)
	var button := Button.new()
	button.text = "  RESUME %s — %d remaining  " % [name.to_upper(), remaining]
	button.pressed.connect(accept_draft)
	_actions.add_child(button)


func _build_untethered(forge: Dictionary) -> void:
	var done: Array = forge.get("untethered", [])
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_body.add_child(spacer)
	if done.is_empty():
		_line("UNTETHERED  —  none yet", QUIET)
		return
	_line("UNTETHERED", Color(0.5, 1.0, 0.6))
	for raw: Variant in done:
		var entry: Dictionary = raw
		_line("   ✓  %s   (%s)" % [str(entry.get("display_name", "")),
				str(entry.get("target_game", ""))], Color(0.6, 0.95, 0.7))


# -- what the card says --------------------------------------------------------

## The draft card as rows of `{text, colour}`, read from the offered Zone
## record and nothing else. Static so a suite can hold the card against the
## Zone's data without opening a screen (§6.A item 2).
static func draft_card_rows(record: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var zone: Dictionary = record.get("zone", {})
	var chambers: Array = zone.get("chambers", [])
	var ids: Array = record.get("allocated_location_ids", [])
	var redraw := int(record.get("redraw_count", 0))
	rows.append({"text": "EPSILON:  “%s”" % str(zone.get("display_name", "")),
			"colour": EPSILON_COLOUR})
	var note := str(zone.get("designer_note", ""))
	if note != "":
		rows.append({"text": "EPSILON:  “%s”" % note, "colour": EPSILON_COLOUR})
	if bool(record.get("used_fallback", false)):
		rows.append({"text": "(drafted offline — Epsilon's fallback wrote this)",
				"colour": QUIET})
	var theme := str(zone.get("theme_pack", "")) \
			if zone.get("theme_pack") != null else ""
	if theme == "":
		theme = str(zone.get("theme", ""))
	rows.append({"text": "SIGNAL  %s     THEME  %s" % [
			str(zone.get("target_game", "")), theme.replace("_", " ")],
			"colour": SIGNAL_COLOUR})
	rows.append({"text": "%d room%s  ·  %d Check%s  ·  draft %d of %d" % [
			chambers.size(), "" if chambers.size() == 1 else "s",
			ids.size(), "" if ids.size() == 1 else "s",
			redraw + 1, D22Slice.MAX_REDRAWS + 1], "colour": FACT_COLOUR})
	var n := 0
	for raw: Variant in chambers:
		n += 1
		rows.append({"text": "  %d. %s" % [n, room_line(raw as Dictionary)],
				"colour": FACT_COLOUR})
	return rows


## One room: its kind, its enemies counted by archetype, its activities
## and features by name, and whether it holds a Check.
static func room_line(chamber: Dictionary) -> String:
	var parts: Array[String] = []
	var kind := str(chamber.get("type", "room")).replace("_", " ")
	var shell := str(chamber.get("shell_id", "")) \
			if chamber.get("shell_id") != null else ""
	var head := kind.capitalize()
	if shell != "":
		head += " (%s)" % shell.trim_prefix("shell_").replace("_", " ")
	var foes: Array[String] = []
	for raw: Variant in chamber.get("enemies", []):
		var e: Dictionary = raw
		foes.append("%d %s" % [int(e.get("count", 0)),
				str(e.get("archetype", "?"))])
	if not foes.is_empty():
		parts.append(", ".join(foes))
	var acts := _counted(chamber.get("activities", []), "kind")
	if acts != "":
		parts.append(acts)
	var feats := _counted(chamber.get("features", []), "tag")
	if feats != "":
		parts.append(feats)
	var checks := 0
	if chamber.get("reward_location_id") != null:
		checks += 1
	checks += (chamber.get("additional_reward_location_ids", []) as Array).size() \
			if typeof(chamber.get("additional_reward_location_ids")) == TYPE_ARRAY \
			else 0
	if checks > 0:
		parts.append("holds %d Check%s" % [checks, "" if checks == 1 else "s"])
	if parts.is_empty():
		return head
	return head + "  —  " + "  ·  ".join(parts)


static func _counted(items: Variant, field: String) -> String:
	if typeof(items) != TYPE_ARRAY:
		return ""
	var counts := {}
	var order: Array[String] = []
	for raw: Variant in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var name := str((raw as Dictionary).get(field, "")).replace("_", " ")
		if not counts.has(name):
			counts[name] = 0
			order.append(name)
		counts[name] += 1
	var out: Array[String] = []
	for name in order:
		out.append(name if counts[name] == 1 else "%s ×%d" % [name, counts[name]])
	return ", ".join(out)


# -- actions -------------------------------------------------------------------

## The same intents a player's buttons send; public so a driver presses the
## Forge exactly as a player does.
func request_draft() -> void:
	if _sent or BridgeClient.hub_mode() != "ZONE_AVAILABLE":
		return
	_sent = true
	var intent := {"type": "request_next_zone", "finale": false}
	if _picked != "":
		intent["track"] = _picked
	BridgeClient.send_intent(intent)


func request_redraw() -> void:
	if _sent or BridgeClient.hub_mode() != "ZONE_READY":
		return
	var zid := str(BridgeClient.active_zone().get("zone_id", ""))
	if zid == "":
		return
	_sent = true
	BridgeClient.send_intent({"type": "redraw_zone", "zone_id": zid})


func accept_draft() -> void:
	if _sent:
		return
	_sent = true
	visible = false
	closed.emit()
	accept_requested.emit()


func pick_signal(track: String) -> void:
	_picked = track


# -- helpers -------------------------------------------------------------------

func _line(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = colour
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(700, 0)
	_body.add_child(label)
	return label


func _set_actions_enabled(on: bool) -> void:
	for child in _actions.get_children():
		if child is Button:
			(child as Button).disabled = not on


static func _has_signal(signals: Array, track: String) -> bool:
	for raw: Variant in signals:
		if str((raw as Dictionary).get("track", "")) == track:
			return true
	return false


func _footer_for(mode: String) -> String:
	match mode:
		"ZONE_READY":
			return ("Accepting builds it for good on first entry. Walking "
					+ "away keeps this same draft.   [Esc] step away")
		"GENERATING":
			return "[Esc] step away — the draft keeps going"
		_:
			return "[Esc] step away"
