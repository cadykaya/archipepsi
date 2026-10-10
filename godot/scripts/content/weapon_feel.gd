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
const KEYS := {KEY_1: "baseline", KEY_2: "a", KEY_3: "b", KEY_4: "c",
		KEY_5: "h"}
## The material test pieces, left of the line of fire (H's impacts read
## them; the references ignore them). The miss lane to the back wall's
## right-hand side stays clear.
const STEEL_AT := Vector3(-3.6, 0, -9)
const CRATE_AT := Vector3(-3.4, 0, -14)
const GEL_AT := Vector3(-2.2, 0, -6.5)

## The treatment a RESTART comes back to.
static var _remembered := ""
## Five-weapon mode: the weapon (or "heavy" / "pulse") a RESTART keeps.
static var _remembered_five := ""
## The five-weapon range's extra pieces (`RangeTargets`).
const MANNEQUIN_AT := Vector3(2.2, 0, -8)
const MOVER_AT := Vector3(0, 0.8, -20.0)
## The loose bodies sit in their own lanes along the east wall.
const LOOSE_CRATE_AT := Vector3(3.8, 0.4, -11.5)
const LOOSE_WEIGHT_AT := Vector3(4.7, 0.3, -16.5)
const PILLAR_AT := Vector3(-1.4, 0, -15.5)
const FIVE_KEYS := {KEY_1: "foundry", KEY_2: "sightline", KEY_3: "switchback",
		KEY_4: "bulkhead", KEY_5: "driver", KEY_6: "heavy", KEY_0: "pulse"}

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
var gel: HandCannon.GelBlock
var five := false
var weapons: RangeWeapons
var mannequin: RangeTargets.Mannequin
var mover: RangeTargets.Mover
var loose_crate: ManipulableBody
var loose_weight: ManipulableBody
var _hint: Label


static func requested() -> bool:
	return ReviewIsolation.weapon()


## The hand-cannon build (the export's `hand_cannon` feature) starts in H.
const CANNON_FEATURE := "hand_cannon"


static func requested_treatment() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feel="):
			return arg.substr(7).to_lower()
	return "h" if OS.has_feature(CANNON_FEATURE) else "baseline"


## The mode the five-weapon range starts in (`--weapon=<id>`).
static func requested_weapon() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			return arg.substr(9).to_lower()
	return "foundry"


func _ready() -> void:
	name = "WeaponFeel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	five = ReviewIsolation.five()
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
	if five:
		_ready_five()
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	var title := _label(Vector2(24, 18), 20)
	title.text = "WEAPON FEEL — Static Pulse range (no enemies)"
	_which = _label(Vector2(24, 50), 26)
	_readout = _label(Vector2(24, 88), 16)
	var keys := _label(Vector2(24, 560), 15)
	keys.text = ("1 Baseline · 2 A Heavy report · 3 B Crisp snap · "
			+ "4 C Echo resonance · 5 H Hand-cannon (C: cadence)\n"
			+ "LMB fire (hold to repeat) · WASD move · "
			+ "E on the dummy resets its count · R back to the mark · Esc menu")
	feel.changed.connect(_on_changed)
	var first := _remembered if _remembered != "" else requested_treatment()
	if not first in WeaponFeelTreatments.ALL_IDS:
		first = "baseline"
	if bound:
		feel.select(first)
	else:
		_which.text = "(the player's shot feedback was not found: baseline only)"
	printerr("weapon-feel: range, no enemies, treatment %s; isolated "
			% feel.current + "(no bridge, no save)")


## The five-weapon range: the same hall, more targets, five weapons.
func _ready_five() -> void:
	_five_range()
	weapons = RangeWeapons.new()
	weapons.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(weapons)
	weapons.bind(self)
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	var title := _label(Vector2(24, 18), 20)
	title.text = "FIVE WEAPONS — isolated range (no enemies, nothing saved)"
	_which = _label(Vector2(24, 50), 26)
	_hint = _label(Vector2(24, 86), 17)
	_readout = _label(Vector2(24, 112), 15)
	var keys := _label(Vector2(24, 540), 15)
	keys.text = ("1 Foundry · 2 Sightline · 3 Switchback · 4 Bulkhead · "
			+ "5 Mass Driver   |   6 Heavy Report (as played) · 0 Static Pulse\n"
			+ "LMB fire (hold: Switchback fires, Mass Driver charges) · "
			+ "M reduced camera motion · N placeholder sounds on/off\n"
			+ "WASD move · R back to the mark · Esc menu (RESTART resets "
			+ "targets and marks)")
	var first := _remembered_five if _remembered_five != "" \
			else requested_weapon()
	if not bound:
		_which.text = "(the player's shot feedback was not found)"
		return
	select_five(first if first in FIVE_KEYS.values() else "foundry")
	printerr("five-weapons: range, no enemies, weapon %s; isolated "
			% _remembered_five + "(no bridge, no save)")


## One of the five weapons, "heavy" (Heavy Report on the Pulse, as the
## owner played it) or "pulse" (the Static Pulse as it ships).
func select_five(mode: String) -> void:
	_remembered_five = mode
	match mode:
		"heavy":
			weapons.select("")
			feel.select("a")
			_which.text = "6 · HEAVY REPORT — as you played it (Static Pulse)"
			_hint.text = "Reference: mode 2 of the weapon-feel range, unchanged."
		"pulse":
			weapons.select("")
			feel.select("baseline")
			_which.text = "0 · STATIC PULSE — as it ships"
			_hint.text = "Reference: the game's own Pulse, 6 a hit, one per 0.35 s."
		_:
			weapons.select(mode)
			_which.text = String(RangeWeapons.PROFILES[mode]["name"])
			_hint.text = String(RangeWeapons.PROFILES[mode]["hint"])


func _five_range() -> void:
	mannequin = RangeTargets.Mannequin.new()
	mannequin.name = "Mannequin"
	mannequin.position = MANNEQUIN_AT
	_range.add_child(mannequin)
	mover = RangeTargets.Mover.new()
	mover.name = "Mover"
	mover.position = MOVER_AT
	_range.add_child(mover)
	loose_crate = RangeTargets.loose("range_crate", 12.0,
			Vector3(0.8, 0.8, 0.8), "wood", Color(0.55, 0.38, 0.2))
	loose_crate.position = LOOSE_CRATE_AT
	_range.add_child(loose_crate)
	loose_weight = RangeTargets.loose("range_weight", 36.0,
			Vector3(0.5, 0.6, 0.5), "metal", Color(0.35, 0.36, 0.38))
	loose_weight.position = LOOSE_WEIGHT_AT
	_range.add_child(loose_weight)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.58, 0.57, 0.55)
	concrete.roughness = 0.95
	var pillar := ChamberBuilders._box(_range, Vector3(0.9, 2.6, 0.6),
			PILLAR_AT + Vector3(0, 1.3, 0), concrete)
	pillar.name = "ConcretePillar"
	pillar.set_meta("impact_material", "stone")


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
	# What H's impacts read it as: the sparks the owner liked on it.
	dummy.set_meta("impact_material", "metal")
	_range.add_child(dummy)
	_material_pieces()


## A steel plate on a post, a timber crate and a gel block: one surface
## of each material H tells apart (the walls and floor are the stone).
func _material_pieces() -> void:
	var steel := _metal_piece()
	var plate := ChamberBuilders._box(_range, Vector3(1.0, 1.0, 0.05),
			STEEL_AT + Vector3(0, 1.3, 0), steel)
	plate.name = "SteelPlate"
	plate.set_meta("impact_material", "metal")
	var post := ChamberBuilders._box(_range, Vector3(0.08, 0.8, 0.08),
			STEEL_AT + Vector3(0, 0.4, 0), steel)
	post.name = "SteelPost"
	post.set_meta("impact_material", "metal")
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.5, 0.34, 0.18)
	timber.roughness = 0.85
	var crate := ChamberBuilders._box(_range, Vector3(1.0, 1.0, 1.0),
			CRATE_AT + Vector3(0, 0.5, 0), timber)
	crate.name = "TimberCrate"
	crate.set_meta("impact_material", "wood")
	gel = HandCannon.GelBlock.new()
	gel.name = "GelBlock"
	gel.position = GEL_AT
	_range.add_child(gel)


static func _metal_piece() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.44, 0.46)
	material.metallic = 0.8
	material.roughness = 0.35
	return material


func _block(label: String, lo: Vector3, hi: Vector3, material: Material) -> void:
	var made := ChamberBuilders._box(_range, hi - lo, (lo + hi) * 0.5, material)
	made.name = label
	# The hall is concrete: tagged, so no impact has to guess.
	made.set_meta("impact_material", "stone")


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
	if five:
		_readout_five()
		return
	_readout.text = "Target: %d damage taken · %d shots · %d hits" % [
			int(round(dummy.absorbed)), feel.shots, feel.hits]
	if bound and feel.current == WeaponFeelTreatments.HAND:
		var hand := feel.hand
		_readout.text += ("\nH: one shot per %.2f s (C to change) · %d a hit · "
				% [hand.cadence, int(Constants.STATIC_PULSE_DAMAGE)]
				+ "%.1f damage a second · gel %d" % [
				Constants.STATIC_PULSE_DAMAGE / hand.cadence,
				int(round(gel.absorbed))]
				+ "\nSound: %s" % ("SigmAudio, %d of %d cues" % [
				hand.sigmaudio_cues(), HandCannon.CUES.size()]
				if hand.sigmaudio_cues() > 0 else
				"PLACEHOLDER (Heavy Report's) until SigmAudio's cues arrive"))


func _readout_five() -> void:
	var text := ""
	if weapons.current != "":
		var p: Dictionary = RangeWeapons.PROFILES[weapons.current]
		var prim: Dictionary = p["action"]["primitive"]
		var cooldown := float(p["action"]["cooldown"])
		if weapons.current == "driver":
			text = ("%.0f–%.0f damage by charge (%.1f s to full) · then %.1f s "
					% [prim["min_damage"], prim["max_damage"],
					prim["charge_time"], cooldown] + "to recover")
			if weapons.charging:
				var ratio := weapons.runtime.charge_ratio()
				text += "\nCHARGE  " + "█".repeat(roundi(ratio * 20)) \
						+ "·".repeat(20 - roundi(ratio * 20))
		else:
			var pellets := int(prim.get("pellets", 1))
			text = ("%s damage%s · one shot per %.2f s · reach %.0f m"
					% [("%d × %.1f" % [pellets, prim["damage"]]) if pellets > 1
					else "%.1f" % prim["damage"], " a pellet" if pellets > 1
					else " a hit", cooldown, prim["range"]])
		var sound := weapons.audio.filled()
		text += ("\nArt: placeholder shapes (Arty's pending) · Sound: %s"
				% ("SigmAudio %d of %d" % [sound.x, sound.y] if sound.x > 0
				else "PLACEHOLDER — not SigmAudio" + (" (muted)"
				if not weapons.audio.placeholders_on else "")))
	text += ("\nDummy %d · 40 HP target %s · gel %d · marks %d%s"
			% [int(round(dummy.absorbed)), "%d" % int(ceil(mannequin.hp))
			if not mannequin.down else "down", int(round(gel.absorbed)),
			weapons.impacts.live_marks(), " · REDUCED MOTION"
			if weapons.reduced_motion else ""])
	_readout.text = text


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
	elif five:
		if FIVE_KEYS.has(key) and bound:
			select_five(FIVE_KEYS[key])
		elif key == KEY_M:
			weapons.set_reduced_motion(not weapons.reduced_motion)
		elif key == KEY_N:
			weapons.audio.placeholders_on = not weapons.audio.placeholders_on
		else:
			return
		get_viewport().set_input_as_handled()
	elif KEYS.has(key) and bound:
		feel.select(KEYS[key])
		get_viewport().set_input_as_handled()
	elif key == KEY_C and bound and feel.current == WeaponFeelTreatments.HAND:
		feel.hand.next_cadence()
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
