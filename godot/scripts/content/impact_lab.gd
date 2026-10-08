class_name ImpactLab
extends Node
## THE IMPACT LAB, PLAYABLE: the G0 fixture's host (`--impact-lab`, or the
## export's `impact_lab` feature). Isolated through `ReviewIsolation`, the
## same guard as Crossing D: no bridge connection, none of the player's
## files written. No enemies.
##
## **SOUND IS WIRED HERE, as `Main` wires it** (post-D plan, P0.3). The
## Crossing D host never built a `Tones` bank, so its shots were silent;
## this host builds one and connects the same events `Main` connects in a
## Zone -- the shot, footsteps, the hit tick -- plus the lab's machine.

const FLAG := ReviewIsolation.LAB_FLAG
const MENU_HOLD := "impact_lab_menu"
const SPAWN := Vector3(0.0, 0.0, 7.5)

var room: ImpactLabRoom
var player: Player
var hud: Hud
var tones: Tones
var found := {}
var _overlay: CanvasLayer
var _note: Label
var _note_left := 0.0
var _menu: Control = null


static func requested() -> bool:
	return ReviewIsolation.lab()


func _ready() -> void:
	name = "ImpactLab"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(ImpactLabRoom.THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(ImpactLabRoom.THEME)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	holder.environment = env
	add_child(holder)
	room = ImpactLabRoom.new()
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	room.build()
	room.said.connect(_say)
	room.stand_in_found.connect(func(id: String) -> void:
		found[id] = true
		_say("Local reward found: a stand-in. Nothing is sent, nothing is saved."))
	player = Player.create()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.set_spawn(Transform3D(Basis.IDENTITY, SPAWN))
	player.velocity = Vector3.ZERO
	if player.camera != null:
		player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.bind_player(player)
	_sound()
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	var title := _label(Vector2(24, 18), 20)
	title.text = "IMPACT LAB — technical fixture (no enemies)"
	_note = _label(Vector2(24, 48), 18)
	var keys := _label(Vector2(24, 642), 15)
	keys.text = ("WASD move · Space jump · Mouse look · LMB pulse · "
			+ "E use / carry / put down\nR back to the start · Esc menu")
	printerr("impact-lab: technical fixture, no enemies; isolated "
			+ "(no bridge, no save)")


## THE SAME CONNECTIONS `Main._to_zone` MAKES, and the lab's own machine
## sounds from the same procedural bank (no new audio assets).
func _sound() -> void:
	tones = Tones.new()
	tones.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tones)
	player.fired_pulse.connect(func() -> void: tones.play("pulse"))
	player.footstep.connect(func(kind: String) -> void: tones.play(kind))
	player.hit_confirmed.connect(func(killed: bool) -> void:
		if not killed:
			tones.play("confirm"))
	room.plate.armed.connect(func(_b: ManipulableBody) -> void:
		tones.play("purchase", 0.7))
	room.plate.fired.connect(func(_b: ManipulableBody, _v: Vector3) -> void:
		tones.play("land", 1.4))
	room.plate.dud.connect(func(_b: ManipulableBody) -> void:
		tones.play("denied"))
	room.lever.pulled.connect(func(_l: CallLever) -> void:
		tones.play("echo", 0.8))
	_bind_shutter()
	tones.play_ambience(0.9)


func _bind_shutter() -> void:
	room.shutter.struck.connect(func(_amount: float, accepted: bool,
			_source: Node3D) -> void:
		tones.play("hit" if accepted else "denied"))
	room.shutter.broken.connect(func(_at: Vector3) -> void:
		tones.play("land", 0.5)
		tones.play("secret"))


func _label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_overlay.add_child(label)
	return label


func _say(text: String) -> void:
	if text == "":
		return
	_note.text = text
	_note_left = 5.0


func _physics_process(delta: float) -> void:
	if _note_left > 0.0 and not get_tree().paused:
		_note_left -= delta
		if _note_left <= 0.0:
			_note.text = ""


func recover() -> void:
	player.cancel_transient_effects()
	player.velocity = Vector3.ZERO
	player.set_spawn(Transform3D(Basis.IDENTITY, SPAWN))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _menu != null:
			_close_menu()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_R and _menu == null:
		recover()
		get_viewport().set_input_as_handled()


## Paused in place through the game's pause claims, as Crossing D does: a
## weight in the air stays where it is until the menu closes.
func _open_menu() -> void:
	PauseClaims.claim(get_tree(), MENU_HOLD)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := Panel.new()
	panel.name = "LabMenu"
	panel.position = Vector2(300, 160)
	panel.size = Vector2(680, 360)
	_overlay.add_child(panel)
	_menu = panel
	var title := Label.new()
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 26)
	title.text = "IMPACT LAB — technical fixture\nPaused"
	panel.add_child(title)
	var legend := Label.new()
	legend.position = Vector2(28, 112)
	legend.add_theme_font_size_override("font_size", 17)
	legend.text = ("Offline: no bridge, no campaign, nothing saved. "
			+ "The reward is a stand-in.\nPlaceholder looks: this tests a "
			+ "mechanism, not the room's art.")
	panel.add_child(legend)
	var row := 0
	for entry in [["RESUME", _close_menu], ["RESTART THE LAB", restart],
			["QUIT", func() -> void: get_tree().quit()]]:
		var button := Button.new()
		button.text = entry[0]
		button.position = Vector2(28, 180 + row * 56)
		button.size = Vector2(624, 46)
		button.pressed.connect(entry[1])
		panel.add_child(button)
		row += 1


func _close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	PauseClaims.release(get_tree(), MENU_HOLD)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func menu_open() -> bool:
	return _menu != null


func restart() -> void:
	PauseClaims.release(get_tree(), MENU_HOLD)
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	PauseClaims.release(get_tree(), MENU_HOLD)
