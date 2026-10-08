class_name ImpactRelay
extends Node
## THE IMPACT RELAY, PLAYABLE: G1's host (`--impact-relay`, or the export's
## `impact_relay` feature), building Dess's approved D-18 v2. Isolated through `ReviewIsolation`, as Crossing
## D and the Impact Lab are: no bridge connection, none of the player's
## files written. No enemies.
##
## **THE KIT:** the base kit plus the swing tether, equipped from the start
## and everywhere (D-18 §4.8). Nothing is limited to protect the puzzle:
## the roof closes every space, and the checks prove the swing reaches
## nothing it should not.
##
## **THE HEAVY-HIT MODE** (`--heavy-hit`; D-18 v2 §7.5, "only if an
## existing Echo action deals 12 or more per hit"): the same room with the
## Braided Lash added on the second Echo slot -- the fixture campaign's own
## `act_lash`, a `projectile_damage` action at 14 per hit, copied as it is
## (`godot/tests/fixtures/equipment_snapshot.json`), not invented. Three
## hits wear the shutter open: the skip the rated rule allows.
##
## **SOUND:** the shot, footsteps and hit tick wired as `Main` wires them
## (G0's correction to Crossing D, kept), plus D-18 v2 §6 from the same
## procedural bank: the lever's clunk; the powered plate's hum (positional,
## from the plate); the arming's rising ticks; the throw's thump; a dull
## knock for a refused blow; a heavier clang for wear; the break.

const FLAG := ReviewIsolation.RELAY_FLAG
const HEAVY_FLAG := "--heavy-hit"
const MENU_HOLD := "impact_relay_menu"
const SPAWN := ImpactRelayRoom.SPAWN
## Facing north, through the doorway onto the gallery and across to the vault.
const SPAWN_YAW := 0.0
const TETHER := {"kind": "action", "component_id": "relay_swing",
		"display_name": "Swing tether", "slot": "echo_a",
		"description": "Jump, then hold RMB; release to let go.",
		"cooldown": 0.35, "primitive": {"type": "grapple_swing",
			"range": 28.0, "tether_force": 28.0, "max_duration": 4.0},
		"modifiers": []}
## `act_lash`, verbatim from the fixture campaign, placed on the second slot.
const LASH := {"charges": null, "component_id": "act_lash", "cooldown": 1.2,
		"description": "Throws a weighted cord that bites what it hits.",
		"display_name": "Braided Lash", "kind": "action", "modifiers": [],
		"primitive": {"bounces": 0, "damage": 14.0, "gravity_scale": 0.0,
			"lifetime": 1.5, "speed": 30.0, "type": "projectile_damage"},
		"slot": "echo_b"}

var heavy := false
var room: ImpactRelayRoom
var player: Player
var hud: Hud
var tones: Tones
var found := {}
var _overlay: CanvasLayer
var _note: Label
var _note_left := 0.0
var _menu: Control = null
var _hum: AudioStreamPlayer3D


static func requested() -> bool:
	return ReviewIsolation.relay()


static func heavy_requested() -> bool:
	return HEAVY_FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "ImpactRelay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(ImpactRelayRoom.THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(ImpactRelayRoom.THEME)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	holder.environment = env
	add_child(holder)
	room = ImpactRelayRoom.new()
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	room.build()
	room.said.connect(_say)
	room.stand_in_found.connect(func(id: String) -> void:
		found[id] = true
		_say("Stand-in found (%s): nothing is sent, nothing is saved." % id))
	player = Player.create()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.set_spawn(spawn())
	player.velocity = Vector3.ZERO
	if player.camera != null:
		player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.bind_player(player)
	(player.runtimes["echo_a"] as EchoRuntime).set_equipped(TETHER)
	heavy = heavy_requested()
	if heavy:
		(player.runtimes["echo_b"] as EchoRuntime).set_equipped(LASH)
	_sound()
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	var title := _label(Vector2(24, 18), 20)
	title.text = "IMPACT RELAY — review room (no enemies)" + (
			" · HEAVY-HIT MODE" if heavy else "")
	_note = _label(Vector2(24, 48), 18)
	var keys := _label(Vector2(24, 624), 15)
	keys.text = ("WASD move · Space jump · Mouse look · LMB pulse · "
			+ "E use / carry / put down\nRMB swing tether (jump, then hold) · "
			+ ("F Braided Lash (14 per hit) · " if heavy else "")
			+ "R back to the start · Esc menu")
	printerr("impact-relay: review room, no enemies%s; isolated "
			% (", heavy-hit mode" if heavy else "") + "(no bridge, no save)")


func spawn() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, SPAWN_YAW), SPAWN)


## THE SAME CONNECTIONS `Main._to_zone` MAKES, then the machine's.
func _sound() -> void:
	tones = Tones.new()
	tones.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tones)
	player.fired_pulse.connect(func() -> void: tones.play("pulse"))
	player.footstep.connect(func(kind: String) -> void: tones.play(kind))
	player.hit_confirmed.connect(func(killed: bool) -> void:
		if not killed:
			tones.play("confirm"))
	var plate := room.plate
	# The powered plate hums where it stands.
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "PlateHum"
	_hum.stream = Tones._hum_loop()
	_hum.pitch_scale = 1.8
	_hum.volume_db = -8.0
	_hum.unit_size = 5.0
	plate.add_child(_hum)
	# Lever on: a clunk, then the line lights and the plate hums.
	room.lever.pulled.connect(func(_l: CallLever) -> void:
		tones.play("land", 0.8)
		tones.play("echo", 0.8)
		_hum.play())
	# Arming: four ticks rising across the 0.6 s ramp.
	plate.armed.connect(func(_b: ManipulableBody) -> void:
		for i in 4:
			var at := ImpactLabParts.ObjectPlate.SETTLE_SECONDS * i / 4.0
			get_tree().create_timer(at, false).timeout.connect(func() -> void:
				tones.menu_cue("tick", 0.8 + 0.25 * i)))
	plate.fired.connect(func(_b: ManipulableBody, _v: Vector3) -> void:
		tones.play("land", 1.4)
		tones.play("pulse", 0.45))
	plate.dud.connect(func(b: ManipulableBody) -> void:
		if room.announces_dud(b):
			tones.play("denied"))
	room.latch.pulled.connect(func(_l: CallLever) -> void:
		tones.play("purchase", 0.6))
	_bind_shutter()
	tones.play_ambience(0.85)


## The shutter's voice: a dull knock for a refused blow, a heavier clang
## for an accepted one (wear), and the break. Bound again whenever the
## shutter is rebuilt (a measurement's trial).
func _bind_shutter() -> void:
	var shutter := room.shutter
	shutter.struck.connect(func(_amount: float, accepted: bool,
			_source: Node3D) -> void:
		if accepted:
			tones.play("hit", 0.55)
			tones.play("land", 0.7)
		else:
			tones.play("land", 1.15))
	shutter.broken.connect(func(_at: Vector3) -> void:
		tones.play("land", 0.45)
		tones.play("hit", 0.35)
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
	player.set_spawn(spawn())


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


## Paused in place through the game's pause claims: a canister in the air
## stays where it is until the menu closes.
func _open_menu() -> void:
	PauseClaims.claim(get_tree(), MENU_HOLD)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := Panel.new()
	panel.name = "RelayMenu"
	panel.position = Vector2(300, 160)
	panel.size = Vector2(680, 360)
	_overlay.add_child(panel)
	_menu = panel
	var title := Label.new()
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 26)
	title.text = "IMPACT RELAY — review room\nPaused"
	panel.add_child(title)
	var legend := Label.new()
	legend.position = Vector2(28, 112)
	legend.add_theme_font_size_override("font_size", 17)
	legend.text = ("Offline: no bridge, no campaign, nothing saved. The Check "
			+ "and the ledge\nreward are stand-ins. Placeholder looks on the "
			+ "plate and the shutter.")
	panel.add_child(legend)
	var row := 0
	for entry in [["RESUME", _close_menu], ["RESTART THE ROOM", restart],
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
