class_name WeaponFeel
extends Node
## THE WEAPON-FEEL RANGE: the Static Pulse fired at one fixed target, under
## four selectable firing-feedback treatments (`WeaponFeelTreatments`):
## the baseline the game ships and three candidates. `--weapon-feel`, or
## the export's `weapon_feel` feature. Isolated through `ReviewIsolation`,
## as the Impact Relay is: no bridge connection, none of the player's
## files written. No enemies.
##
## **WHAT IS COMPARED:** only how a shot feels -- recoil and recovery, the
## muzzle, the report, the impact and the hit confirmation. The weapon is
## the game's own `Player`, firing through `_fire_static_pulse` at
## `Constants`' damage and cooldown, and the target is the Echo Lab's own
## dummy (`LabFixtures.LabDummy`, unchanged: it absorbs and reports damage
## and never dies). The check proves the shots, hits and damage are the
## same under all four.
##
## `--feel=baseline|a|b|c` picks the starting treatment (one launcher per
## treatment); keys 1-4 switch in play.

const FLAG := ReviewIsolation.WEAPON_FLAG
const MENU_HOLD := "weapon_feel_menu"
const THEME := "concrete_facility"
## The firing mark, facing north down the range.
const SPAWN := Vector3(0, 0.05, 0)
## The target, 10 m down range. The back wall is 22 m away, for misses.
const TARGET_AT := Vector3(0, 0, -10)
const RANGE := Rect2(-6, -22, 12, 26)
const HEIGHT := 5.0
const WALL := 0.5
const KEYS := {KEY_1: "baseline", KEY_2: "a", KEY_3: "b", KEY_4: "c"}

## The treatment a RESTART comes back to.
static var _remembered := ""

var player: Player
var hud: Hud
var tones: Tones
var dummy: LabFixtures.LabDummy
var feel: WeaponFeelTreatments
var bound := false
var _overlay: CanvasLayer
var _which: Label
var _readout: Label
var _menu: Control = null
var _range: Node3D


static func requested() -> bool:
	return ReviewIsolation.weapon()


static func requested_treatment() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feel="):
			return arg.substr(7).to_lower()
	return "baseline"


func _ready() -> void:
	name = "WeaponFeel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(THEME)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	holder.environment = env
	add_child(holder)
	_range = Node3D.new()
	_range.name = "Range"
	_range.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_range)
	_build_range()
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
	_sound()
	feel = WeaponFeelTreatments.new()
	feel.name = "Treatments"
	feel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(feel)
	bound = feel.bind(player, tones, dummy)
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	var title := _label(Vector2(24, 18), 20)
	title.text = "WEAPON FEEL — Static Pulse range (no enemies)"
	_which = _label(Vector2(24, 50), 26)
	_readout = _label(Vector2(24, 88), 16)
	var keys := _label(Vector2(24, 560), 15)
	keys.text = ("1 Baseline · 2 A Heavy report · 3 B Crisp snap · "
			+ "4 C Echo resonance\nLMB fire (hold to repeat) · WASD move · "
			+ "E on the dummy resets its count · R back to the mark · Esc menu")
	feel.changed.connect(_on_changed)
	var first := _remembered if _remembered != "" else requested_treatment()
	if not first in WeaponFeelTreatments.IDS:
		first = "baseline"
	if bound:
		feel.select(first)
	else:
		_which.text = "(the player's shot feedback was not found: baseline only)"
	printerr("weapon-feel: range, no enemies, treatment %s; isolated "
			% feel.current + "(no bridge, no save)")


func spawn() -> Transform3D:
	return Transform3D(Basis(), SPAWN)


func _build_range() -> void:
	var x0 := RANGE.position.x
	var z0 := RANGE.position.y
	var x1 := RANGE.end.x
	var z1 := RANGE.end.y
	_block("Floor", Vector3(x0 - WALL, -0.5, z0 - WALL),
			Vector3(x1 + WALL, 0.0, z1 + WALL), ThemeMaterials.floor_mat(THEME))
	_block("Roof", Vector3(x0 - WALL, HEIGHT, z0 - WALL),
			Vector3(x1 + WALL, HEIGHT + 0.5, z1 + WALL),
			ThemeMaterials.trim_mat(THEME))
	var wall := ThemeMaterials.wall_mat(THEME)
	_block("WestWall", Vector3(x0 - WALL, 0, z0), Vector3(x0, HEIGHT, z1), wall)
	_block("EastWall", Vector3(x1, 0, z0), Vector3(x1 + WALL, HEIGHT, z1), wall)
	_block("BackWall", Vector3(x0 - WALL, 0, z0 - WALL),
			Vector3(x1 + WALL, HEIGHT, z0), wall)
	_block("SouthWall", Vector3(x0 - WALL, 0, z1),
			Vector3(x1 + WALL, HEIGHT, z1 + WALL), wall)
	# The firing mark: a painted strip on the floor.
	ChamberBuilders._box(_range, Vector3(2.0, 0.02, 0.12),
			Vector3(0, 0.01, SPAWN.z - 0.6), ThemeMaterials.hazard_mat(THEME),
			false)
	# Dim overhead light, so the muzzle and the impact have something to
	# light up.
	for at in [Vector3(0, 4.2, -2), Vector3(0, 4.2, -12)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_energy = 0.7
		light.omni_range = 12.0
		light.light_color = Color(0.86, 0.9, 0.95)
		_range.add_child(light)
	CrossingDParts.plain_sign(_range, "WEAPON FEEL · FIRING RANGE",
			Vector3(0, 3.6, z0 + 0.05), 26)
	dummy = LabFixtures.LabDummy.new()
	dummy.name = "Target"
	dummy.position = TARGET_AT
	# The Lab's dummy is hit by Echo actions through `Enemy`'s interface;
	# the Pulse asks `Damageable`, so the range enrols it there.
	dummy.add_to_group(Damageable.GROUP)
	_range.add_child(dummy)


func _block(label: String, lo: Vector3, hi: Vector3, material: Material) -> void:
	var made := ChamberBuilders._box(_range, hi - lo, (lo + hi) * 0.5, material)
	made.name = label


## THE SAME CONNECTIONS `Main._to_zone` MAKES, except the shot's and the
## hit's: those belong to the treatment (the baseline makes exactly these).
func _sound() -> void:
	tones = Tones.new()
	tones.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tones)
	player.footstep.connect(func(kind: String) -> void: tones.play(kind))
	tones.play_ambience(0.85)


func _on_changed(id: String) -> void:
	_remembered = id
	_which.text = WeaponFeelTreatments.NAMES[id]


func _process(_delta: float) -> void:
	if _readout == null or dummy == null:
		return
	_readout.text = "Target: %d damage taken · %d shots · %d hits" % [
			int(round(dummy.absorbed)), feel.shots, feel.hits]


func _label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_overlay.add_child(label)
	return label


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
	if not (event is InputEventKey) or not event.pressed or event.echo \
			or _menu != null:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_R:
		recover()
		get_viewport().set_input_as_handled()
	elif KEYS.has(key) and bound:
		feel.select(KEYS[key])
		get_viewport().set_input_as_handled()


func _open_menu() -> void:
	PauseClaims.claim(get_tree(), MENU_HOLD)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := Panel.new()
	panel.name = "FeelMenu"
	panel.position = Vector2(300, 160)
	panel.size = Vector2(680, 360)
	_overlay.add_child(panel)
	_menu = panel
	var title := Label.new()
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 26)
	title.text = "WEAPON FEEL — firing range\nPaused"
	panel.add_child(title)
	var legend := Label.new()
	legend.position = Vector2(28, 112)
	legend.add_theme_font_size_override("font_size", 17)
	legend.text = ("Offline: no bridge, no campaign, nothing saved. Same "
			+ "damage, same rate of fire\nin every treatment; only the "
			+ "feedback changes.")
	panel.add_child(legend)
	var row := 0
	for entry in [["RESUME", _close_menu], ["RESTART THE RANGE", restart],
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
