class_name RevealLayer
extends CanvasLayer
## The payoff moment (DESIGN §16): freeze input, show the card, play the
## sound, hold ~2 seconds. One card per notification; queued, never stacked.
##
## The packet calls this "the only genuinely novel moment in the loop", so
## the card is built to make one thing unmistakable: the other player got
## the real item, and you got Epsilon's local reinterpretation of it. Those
## are two different facts, so they are two visually distinct blocks in the
## recipient's colour and Epsilon's respectively.

signal reveal_started
signal reveal_finished

const HOLD_SECONDS := 2.2
#: Epsilon's colour everywhere it speaks in its own voice.
const EPSILON_TINT := Color(0.55, 1.0, 0.9)

var _queue: Array[Dictionary] = []
var _showing := false
var _backdrop: ColorRect
var _flash: ColorRect
var _panel: PanelContainer
var _frame: StyleBoxFlat
var _title: Label
var _body: Label
var _divider: ColorRect
var _echo_body: Label
var tones: Tones

func _ready() -> void:
	layer = 10
	visible = false

	# Dims the world behind the card. Without it the card competes with a
	# lit corridor for the one moment that is supposed to stop everything.
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.04, 0.0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 300)
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(0.05, 0.06, 0.08, 0.97)
	_frame.set_border_width_all(3)
	_frame.set_content_margin_all(26)
	_panel.add_theme_stylebox_override("panel", _frame)
	UILayout.centred(self, _panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	box.add_child(_title)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 22)
	box.add_child(_body)

	_divider = ColorRect.new()
	_divider.custom_minimum_size = Vector2(0, 2)
	box.add_child(_divider)

	_echo_body = Label.new()
	_echo_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_echo_body.add_theme_font_size_override("font_size", 19)
	_echo_body.modulate = EPSILON_TINT
	box.add_child(_echo_body)

	# The slam. Drawn last so it covers the card for its first few frames.
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func enqueue(note: Dictionary) -> void:
	_queue.append(note)
	if not _showing:
		_show_next()

## Splits the bridge's card text into the two halves the packet describes.
## The bridge composes that text and marks the boundary with a blank line;
## if it ever stops doing so, everything renders as the first half rather
## than being misattributed to Epsilon.
static func split_halves(lines: Array) -> Array:
	var sent: Array[String] = []
	var echo: Array[String] = []
	var past_break := false
	for line in lines:
		var text := str(line)
		if text == "" and not past_break:
			past_break = true
			continue
		if past_break:
			echo.append(text)
		else:
			sent.append(text)
	return [sent, echo]

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		reveal_finished.emit()
		return
	if not _showing:
		_showing = true
		reveal_started.emit()
	var note: Dictionary = _queue.pop_front()
	var hold := HOLD_SECONDS
	if note.get("kind") == "goal_reached":
		hold = 4.5                     # the victory moment earns a beat
	_title.text = str(note.get("title", ""))

	var halves := split_halves(note.get("lines", []))
	var sent_lines: Array = halves[0]
	var echo_lines: Array = halves[1]
	# For a reveal carrying an echo, append the shared effect summary so the
	# card and the inventory describe it identically.
	var echo_id: Variant = note.get("echo_id")
	if echo_id != null:
		var echo := BridgeClient.echo_by_id(str(echo_id))
		if not echo.is_empty():
			echo_lines.append("")
			echo_lines.append_array(EffectSummary.lines(echo))
	_body.text = "\n".join(sent_lines)
	_echo_body.text = "\n".join(echo_lines)
	# No Echo half means no rule to divide: a self-recipient check gets one
	# block, not one block and an empty gap where the payoff should be.
	var has_echo := not echo_lines.is_empty()
	_divider.visible = has_echo
	_echo_body.visible = has_echo

	# Tint the card by the game that received the item, using the same
	# per-game colour the Hub's campaign board and the reward pedestals use
	# — so the reveal, the board and the multiworld all agree about who
	# this went to.
	var accent := Color(1.0, 0.85, 0.4)
	var location: Variant = note.get("location_id")
	if location != null:
		var scout := BridgeClient.scout_for(int(location))
		var game := str(scout.get("recipient_game", "")) if scout else ""
		if game != "":
			accent = ThemeMaterials.color_for_game(game).lightened(0.35)
	_title.modulate = accent
	_frame.border_color = accent
	_divider.color = Color(accent, 0.5)

	visible = true
	if tones != null:
		tones.play("goal" if note.get("kind") == "goal_reached" else "echo")
	_play_slam()
	var timer := get_tree().create_timer(hold)
	timer.timeout.connect(_show_next)

## Animates opacity rather than scale: a scale punch needs a pivot from the
## laid-out size, which is not known on the frame the card first appears.
func _play_slam() -> void:
	_backdrop.color.a = 0.0
	_panel.modulate.a = 0.0
	_flash.color.a = 0.32
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "color:a", 0.66, 0.12)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.10)
	tween.tween_property(_flash, "color:a", 0.0, 0.24)
