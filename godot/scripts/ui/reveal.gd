class_name RevealLayer
extends CanvasLayer
## The payoff moment (DESIGN §16): freeze input, show the card, play the
## sound, hold ~2 seconds. One card per notification; queued, never stacked.

signal reveal_started
signal reveal_finished

const HOLD_SECONDS := 2.2

var _queue: Array[Dictionary] = []
var _showing := false
var _panel: PanelContainer
var _title: Label
var _body: Label
var tones: Tones

func _ready() -> void:
	layer = 10
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 300)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.modulate = Color(1.0, 0.85, 0.4)
	box.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 20)
	box.add_child(_body)

func enqueue(note: Dictionary) -> void:
	_queue.append(note)
	if not _showing:
		_show_next()

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
	var lines: Array[String] = []
	for line in note.get("lines", []):
		lines.append(str(line))
	# For a reveal carrying an echo, append the shared effect summary so the
	# card and the inventory describe it identically.
	var echo_id: Variant = note.get("echo_id")
	if echo_id != null:
		for echo: Dictionary in BridgeClient.snapshot.get("echoes", []):
			if echo.get("echo_id") == echo_id:
				lines.append("")
				lines.append_array(EffectSummary.lines(echo))
				break
	_body.text = "\n".join(lines)

	# Tint the card by the game that received the item, using the same
	# per-game colour the Hub's campaign board uses — so the reveal, the
	# board and the multiworld all agree about who this went to.
	var accent := Color(1.0, 0.85, 0.4)
	var location: Variant = note.get("location_id")
	if location != null:
		var scout := BridgeClient.scout_for(int(location))
		var game := str(scout.get("recipient_game", "")) if scout else ""
		if game != "":
			accent = ThemeMaterials.color_for_game(game).lightened(0.35)
	_title.modulate = accent
	visible = true
	if tones != null:
		tones.play("goal" if note.get("kind") == "goal_reached" else "echo")
	var timer := get_tree().create_timer(hold)
	timer.timeout.connect(_show_next)
