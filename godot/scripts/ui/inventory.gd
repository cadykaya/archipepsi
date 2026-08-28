class_name InventoryLayer
extends CanvasLayer
## Echo inventory (Tab): name, source game, recipient, SOURCE LOCATION,
## description, activation, and the shared effect summary. Two Hookshots
## must read as Check 002's and Check 026's, not as duplicates.
##
## v0.8 additions (DESIGN §15.4): the concepts Epsilon read, and provenance
## chains — a component upgraded three times shows every AP item
## responsible, in order (ECHOES §11), each row accented by its source
## game (§12). The chains read from the FOLD, so they grow on their own as
## later stages land UPGRADE / MODIFY / LINK / MERGE.

signal closed

#: Same table the HUD's loadout uses: what the keycap says.
const SLOT_KEYCAPS := {"echo_a": "RMB", "echo_b": "MMB", "mobility": "SHIFT",
		"utility": "C"}

#: The four §15 modes, warming as the reading travels further from the
#: item. Purely a tint — the word itself is always shown, because a colour
#: nobody has been taught is not information.
const _MODE_TINT := {
	"literal": Color(0.62, 0.70, 0.82),
	"mechanical": Color(0.70, 0.72, 0.92),
	"conceptual": Color(0.80, 0.66, 0.92),
	"systemic": Color(0.95, 0.72, 0.55),
}

var _list: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	layer = 8
	visible = false
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 520)
	UILayout.centred(self, panel)
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
	hint.text = "[Tab] close   [wheel] cycle the highlighted slot   " \
			+ "[★] mark a favourite"
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

	# §15.4: the concepts Epsilon read are half the charm, and they are
	# stored on the interpretation for exactly this line.
	var concepts: Array = echo.get("concepts", [])
	if not concepts.is_empty():
		var read := Label.new()
		var words: PackedStringArray = []
		for concept in concepts:
			words.append(str(concept))
		# The mode rides on the same line. It was worth nothing before
		# S10 — every interpretation said "literal" because the fallback
		# hardcoded it — and is now derived from what the operations
		# actually did, so it tells the player how far Epsilon travelled
		# from the item to get here.
		var mode := str(echo.get("mode", "literal"))
		read.text = "read %s: %s" % [mode, " / ".join(words)]
		read.modulate = _MODE_TINT.get(mode, Color(0.75, 0.65, 0.9))
		read.add_theme_font_size_override("font_size", 13)
		text_box.add_child(read)

	var effects := Label.new()
	effects.text = " · ".join(EffectSummary.lines(echo))
	effects.modulate = Color(0.6, 0.95, 0.85)
	effects.add_theme_font_size_override("font_size", 15)
	text_box.add_child(effects)

	_add_provenance_rows(text_box, echo)

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
		var slot := str(action.get("slot", "echo_a"))
		var button := Button.new()
		# S7: the button names the KEY it would land on. Four slots make
		# "SLOT" ambiguous — the useful question is which button this
		# becomes, and whether something is already there.
		var occupant: Variant = BridgeClient.slots().get(slot)
		if component_id in slotted:
			button.text = "ON %s" % SLOT_KEYCAPS.get(slot, "?")
			button.disabled = true
		elif occupant != null:
			button.text = "REPLACE %s" % SLOT_KEYCAPS.get(slot, "?")
		else:
			button.text = "TO %s" % SLOT_KEYCAPS.get(slot, "?")
		button.custom_minimum_size = Vector2(120, 0)
		button.pressed.connect(func() -> void:
			BridgeClient.send_intent({"type": "slot_action",
					"slot": slot, "component_id": component_id}))
		row.add_child(button)

		# Favouriting (§9): marking which Actions the wheel cycles. A
		# client preference, not campaign state — the schema has no field
		# for it because a favourite changes nothing mechanical.
		var star := Button.new()
		star.toggle_mode = true
		star.button_pressed = Favourites.is_favourite(component_id)
		star.text = "★" if star.button_pressed else "☆"
		star.tooltip_text = "cycle this one with the wheel"
		star.custom_minimum_size = Vector2(38, 0)
		star.toggled.connect(func(on: bool) -> void:
			Favourites.toggle(component_id)
			star.text = "★" if on else "☆")
		row.add_child(star)

		# Comparison (§9): what you would be giving up, right where the
		# decision is made, rather than remembered from another screen.
		if occupant != null and component_id not in slotted:
			var against: Dictionary = BridgeClient.owned_component(
					str(occupant)).get("component", {})
			var versus := Label.new()
			versus.text = "replaces %s\n%s" % [
					against.get("display_name", "?"),
					" · ".join(EffectSummary.component_lines(against))]
			versus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			versus.custom_minimum_size = Vector2(150, 0)
			versus.add_theme_font_size_override("font_size", 12)
			versus.modulate = Color(0.95, 0.75, 0.55)
			row.add_child(versus)
	return panel

## ECHOES §11: every owned component this interpretation touched shows its
## whole chain — every AP item responsible, in order, never rewritten:
##
##     GRAPPLE  Mk III
##       Mk I    pull to surface  ← Hookshot  (Ocarina of Time)
##       Mk II   +12 range        ← Longshot  (Ocarina of Time)
##
## Chains of one stay silent: the source line above already credits the
## creator, and repeating it under every young Echo would bury the rows
## that genuinely have history. The chain appears on every interpretation
## that touched the component — the upgrader's row and the creator's both —
## because "what did this Check do for me" is the question the archive
## answers, and for an upgrade the answer lives in someone else's Echo.
func _add_provenance_rows(text_box: VBoxContainer, echo: Dictionary) -> void:
	var seq := int(echo.get("interpretation_seq", -1))
	for entry: Dictionary in BridgeClient.mechanics().get("owned", []):
		var chain: Array = entry.get("provenance", [])
		if chain.size() < 2 or not _touched(chain, seq):
			continue
		var component: Dictionary = entry.get("component", {})
		var header := Label.new()
		header.text = "%s  Mk %s" % [
				str(component.get("display_name", "?")).to_upper(),
				_mk_roman(int(entry.get("mk", 1)))]
		header.add_theme_font_size_override("font_size", 13)
		header.modulate = Color(0.85, 0.85, 0.9)
		text_box.add_child(header)
		var mk := 0
		for link: Dictionary in chain:
			var op := str(link.get("operation", ""))
			var mark: String
			if op in ["create", "upgrade", "modify"]:
				mk += 1
				mark = "Mk " + _mk_roman(mk)
			else:
				mark = "linked" if op == "link" else "merged"
			var row := Label.new()
			row.text = "    %s  %s ← %s  (%s)" % [mark,
					str(link.get("note", "")),
					str(link.get("source_item_name", "?")),
					str(link.get("source_game", "?"))]
			row.add_theme_font_size_override("font_size", 13)
			# §12: the accent on a provenance row marks contribution.
			# Lifted toward white so a dark theme accent stays readable.
			row.modulate = ThemeMaterials.color_for_game(
					str(link.get("source_game", ""))).lerp(Color.WHITE, 0.35)
			text_box.add_child(row)

func _touched(chain: Array, seq: int) -> bool:
	for link: Dictionary in chain:
		if int(link.get("interpretation_seq", -1)) == seq:
			return true
	return false

func _mk_roman(n: int) -> String:
	const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII",
			"IX", "X", "XI", "XII"]
	return NUMERALS[n - 1] if n >= 1 and n <= NUMERALS.size() else str(n)
