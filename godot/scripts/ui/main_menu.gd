class_name MainMenu
extends CanvasLayer
## DESIGN §22. The Epsilon line is a read-only status display sourced from
## the snapshot — the provider is chosen by the bridge's launch flag.

signal connect_pressed(server: String, slot: String, password: String)
signal mock_pressed

var _server: LineEdit
var _slot: LineEdit
var _password: LineEdit
var _status: Label
var _epsilon: Label

func _ready() -> void:
	layer = 4
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 200)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ARCHIPEPSI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "an Archipelago game, designed while you play"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.6, 0.7, 0.75)
	box.add_child(subtitle)

	_server = _field(box, "Server", "localhost:38281")
	_slot = _field(box, "Slot", "Skyiah")
	_password = _field(box, "Password", "")
	_password.secret = true

	_epsilon = Label.new()
	_epsilon.modulate = Color(0.7, 0.8, 0.85)
	box.add_child(_epsilon)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	var connect_button := Button.new()
	connect_button.text = "CONNECT"
	connect_button.pressed.connect(func() -> void:
		connect_pressed.emit(_server.text, _slot.text, _password.text))
	box.add_child(connect_button)
	var mock_button := Button.new()
	mock_button.text = "MOCK CAMPAIGN"
	mock_button.pressed.connect(func() -> void: mock_pressed.emit())
	box.add_child(mock_button)
	var quit_button := Button.new()
	quit_button.text = "QUIT"
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_button)
	refresh()

func _field(box: VBoxContainer, label_text: String,
		default_value: String) -> LineEdit:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = default_value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit

func refresh() -> void:
	var s := BridgeClient.snapshot
	_epsilon.text = "Epsilon: %s" % s.get("epsilon_provider", "…")
	var status := "Bridge connected" if BridgeClient.online \
			else "BRIDGE OFFLINE — start it with `make bridge`"
	if s.get("race_mode", false):
		status = ("Race-mode room: Archipepsi cannot scout its own "
				+ "placements here. Unsupported.")
	_status.text = "Status: %s" % status

func show_error(message: String) -> void:
	_status.text = "Status: %s" % message
