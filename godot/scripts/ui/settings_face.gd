class_name SettingsFace
extends Node
## H-JOURNAL'S SETTINGS WALL, AS THE APPROVED HYBRID (MENU-INT): the box's
## MAINTENANCE SIDE -- D's salvaged boards (the owner's rulings of
## 2026-09-27; `tools/menu_proto/face_settings.gd`, `5b03f6d`, the
## reference) -- on the game's own settings and pause actions (`04` §8:
## "Settings includes resume, current campaign/profile information and
## supported options").
##
## * PAUSED -- bare FR4: the pause actions (`PauseMenu`) as push switches,
##   the game's own words. Outside a Zone, RESUME and QUIT GAME only. In a
##   Zone, ABANDON ZONE… arms a confirmation on the same board: the game's
##   warning, CANCEL and CONFIRM ABANDON.
## * CAMPAIGN -- paper phenolic, the rack's own stock, where the rack's
##   ribbon lands from round the corner: `JournalQuery.campaign`, on a
##   salvaged character display.
## * OPTIONS -- black mask: the options the game applies, on slide pots
##   and a bat switch, at `PlayerSettings`' ranges, the old wall's steps
##   and its words; each saved at once. Field of view reaches the camera
##   in use now; sensitivity and invert are read by the player on every
##   move; MOTION reaches the menu at once (a turn, a slide, a pulse);
##   MASTER VOLUME sets the Master bus, cues included. "Captions" is
##   stored but nothing reads it, so it is not offered.
##
## **A held direction speeds a pot up; a press stays one step.** Repeats
## of a held key (or d-pad) double the step after `ACCEL_AFTER` of them, up
## to `ACCEL_MAX` steps a repeat; a release, the other direction or
## another row starts over at one step.
##
## EPSILON comes through the old plate above the OPTIONS board -- his one
## point in the machine: not a slot, a setting, a meter, a status light,
## or anything the focus stops on. The harness's drop runs through him,
## and his feed goes down the board's margin into a terminal in the
## board's foot: it touches no value and no control.

# ---- the boards
const PAUSED_TOP := 116.0
const PAUSED_RIGHT := 406.0
const PAUSED_FULL := 378.0                 # the board's foot, in a Zone
const PAUSED_HUB := 300.0                  # ... and outside one
const CAMPAIGN := [Vector2(40, 402), Vector2(406, 402), Vector2(406, 692),
	Vector2(66, 692), Vector2(40, 666)]
## The options board, its foot straight now that the review plate is gone.
const OPTIONS := [Vector2(440, 116), Vector2(1108, 116), Vector2(1132, 168),
	Vector2(1244, 168), Vector2(1244, 560), Vector2(1204, 600), Vector2(480, 600),
	Vector2(440, 560)]
const BZ := 0.014
# ---- the options
const POT_X := 470.0
const POT_END := 1200.0
const POT_Y0 := 172.0
const POT_PITCH := 76.0
const VALUE_X := 1088.0
const VALUE_W := 112.0
# ---- Epsilon, and where his feed goes
const EPSILON := Vector2(1190, 104)
const FEED_X := 1232.0
const TERMINAL := Rect2(1150, 556, 46, 22)
## The options offered: key, words, step. Ranges are PlayerSettings'.
const SLIDERS := [
	["mouse_sensitivity", "MOUSE SENSITIVITY", 0.0001],
	["field_of_view", "FIELD OF VIEW", 1.0],
	["motion_intensity", "MOTION (VIEW BOB, MENU TURNS)", 0.05],
	["master_volume", "MASTER VOLUME", 0.05],
]
const TOGGLE := ["invert_look_y", "INVERT LOOK UP AND DOWN"]
## Held-direction acceleration, tunable: the repeats at one step before it
## starts doubling, the doublings at most, and the most steps a repeat.
const ACCEL_AFTER := 3
const ACCEL_DOUBLINGS := 5
const ACCEL_MAX := 20

var kit: MenuKit
var shell: MenuShell
var face: Node3D
var pause_menu: PauseMenu
var focus := 0
var note := ""
var _rows: Array = []                 # every row: {kind, key|words, ...}
var _paused: Node3D                   # the PAUSED board: rebuilt with its switches
var _dyn: Node3D                      # what changes: focus, windows, the display
var _knobs := {}                      # key -> Node3D (slides)
var _bat: Node3D
var _drag := ""                       # the pot a held button is setting
var _streak := 0
var _streak_dir := 0
var _streak_key := ""
var _info := {}
var _switch_set: Array = []


func _ready() -> void:
	name = "SettingsFace"
	BridgeClient.snapshot_received.connect(func(_s: Dictionary) -> void: refresh())
	BridgeClient.bridge_state_changed.connect(func(_o: bool) -> void: refresh())


## The PAUSED board's switches are PauseMenu's.
func bind_pause(menu: PauseMenu) -> void:
	pause_menu = menu
	if not pause_menu.changed.is_connected(_on_pause_changed):
		pause_menu.changed.connect(_on_pause_changed)
	if kit != null:
		_on_pause_changed()


func setup(k: MenuKit, s: MenuShell) -> void:
	kit = k
	shell = s
	face = shell.face_node("settings")
	_build_static()
	_build_paused()
	focus = 0                          # RESUME: the direct way back
	_draw()


## The Master bus at the saved volume. Called at boot and on every change.
static func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(
				PlayerSettings.shared().value("master_volume"), 0.0001)))


## The campaign lines and the values, from what the client holds now.
func refresh() -> void:
	if kit != null:
		_draw()


## What the campaign display says, line by line.
func campaign_lines() -> Array:
	return JournalQuery.campaign(BridgeClient.snapshot, BridgeClient.online)


# ============================================================ the boards

func _build_static() -> void:
	var f := Node3D.new()
	f.name = "Boards"
	face.add_child(f)
	MenuParts.seam(f, 423, 112, 704)
	var shade := float(shell.shade.get("settings", 1.0))
	# ---- CAMPAIGN: a salvaged character display on paper phenolic -- the
	# rack's own stock -- where the rack's ribbon lands from round the corner
	MenuParts.board(f, PackedVector2Array(CAMPAIGN), MenuParts.PHENOLIC, BZ,
			[Vector2(54, 416), Vector2(392, 678)], shade)
	var lcd := Rect2(64, 424, 318, 176)
	MenuParts.block(f, lcd.grow(8), BZ, BZ + 0.01, MenuParts.mat(Color("#1d2021"), 0.2,
			0.5))
	MenuParts.block(f, lcd, BZ + 0.01, BZ + 0.0106, MenuParts.mat(MenuParts.LCD, 0.0,
			0.8))
	MenuParts.tape(kit, f, Vector2(104, 614), "CAMPAIGN", BZ)
	MenuParts.ribbon(f, [Vector2(MenuParts.RUN_START, MenuParts.RIBBON_Y),
			Vector2(74, MenuParts.RIBBON_Y)], MenuParts.RIBBON_Z)
	MenuParts.header(f, Rect2(74, MenuParts.RIBBON_Y - 12, 12, 24), BZ)
	# ---- OPTIONS: black mask, the biggest board, notched where the old
	# plate is left bare for Epsilon
	MenuParts.board(f, PackedVector2Array(OPTIONS), MenuParts.BLACK_MASK, BZ,
			[Vector2(454, 130), Vector2(1094, 130), Vector2(1216, 182),
			Vector2(1216, 582), Vector2(454, 546)], shade)
	# a short ribbon from CAMPAIGN into it
	MenuParts.header(f, Rect2(380, 508, 12, 24), BZ)
	MenuParts.header(f, Rect2(452, 508, 12, 24), BZ)
	MenuParts.ribbon(f, [Vector2(386, 520), Vector2(458, 520)], BZ + 0.014, 6.0)
	MenuParts.tape(kit, f, Vector2(POT_X, 126), "OPTIONS", BZ)
	# the pots' tracks and slots; their knobs slide
	var settings := PlayerSettings.shared()
	for i in SLIDERS.size():
		var row: Array = SLIDERS[i]
		var key := str(row[0])
		var py := POT_Y0 + POT_PITCH * i
		MenuParts.tape(kit, f, Vector2(POT_X, py), str(row[1]), BZ)
		var pot := Rect2(POT_X, py + 32, POT_END - POT_X, 16)
		var body := MenuParts.block(f, pot, BZ, BZ + 0.008,
				MenuParts.mat(MenuParts.PLATE, 0.55, 0.45))
		kit.pickable("settings", body, "pot:" + key)
		MenuParts.block(f, Rect2(pot.position.x + 10, pot.get_center().y - 2,
				pot.size.x - 20, 4), BZ + 0.008, BZ + 0.0084,
				MenuParts.unlit(Color("#060606")), false)
		var knob := Node3D.new()
		f.add_child(knob)
		# built at the track's left end; slid to its value
		var kc := Vector2(pot.position.x + 16, py + 40)
		var cap := MenuParts.block(knob, Rect2(kc - Vector2(12, 12), Vector2(24, 24)),
				BZ + 0.008, BZ + 0.026, MenuParts.mat(Color("#dadcd8"), 0.2, 0.5))
		kit.pickable("settings", cap, "pot:" + key)
		var line := StandardMaterial3D.new()
		line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.albedo_color = Color("#3a3d3f")
		MenuParts.block(knob, Rect2(kc.x - 1.5, kc.y - 10, 3, 20), BZ + 0.026,
				BZ + 0.0266, line, false)
		knob.set_meta("line", line)
		knob.set_meta("z", BZ + 0.026)
		_knobs[key] = knob
		kit.pick_rect("settings", f, Rect2(POT_X - 8, py - 6, POT_END - POT_X + 16, 30),
				BZ, BZ + 0.004, "row:" + key)
		var spec: Array = PlayerSettings.RANGES[key]
		_rows.append({"kind": "pot", "key": key, "words": str(row[1]),
			"step": float(row[2]), "range": [float(spec[0]), float(spec[1]),
				float(spec[2])],
			"track": Rect2(pot.position.x + 16, pot.position.y - 8, pot.size.x - 32, 32),
			"window": Rect2(VALUE_X, py, VALUE_W, 24), "bar": Rect2(452, py - 2, 4, 54),
			"hit": Rect2(POT_X - 8, py - 6, POT_END - POT_X + 16, 62)})
	# the bat switch
	var ty := POT_Y0 + POT_PITCH * SLIDERS.size()
	MenuParts.tape(kit, f, Vector2(POT_X, ty), str(TOGGLE[1]), BZ)
	var bc := Vector2(VALUE_X - 38, ty + 12)
	var base := MenuParts.block(f, Rect2(bc - Vector2(16, 20), Vector2(32, 40)), BZ,
			BZ + 0.004, MenuParts.mat(MenuParts.PLATE, 0.55, 0.45))
	kit.pickable("settings", base, "toggle:" + str(TOGGLE[0]))
	kit.pick_rect("settings", f, Rect2(POT_X - 8, ty - 6, POT_END - POT_X + 16, 40), BZ,
			BZ + 0.004, "toggle:" + str(TOGGLE[0]))
	MenuParts.disc(f, bc, 9, BZ + 0.004, BZ + 0.01, MenuParts.mat(Color("#8c9094"), 0.6,
			0.35), 6)
	_bat = Node3D.new()
	f.add_child(_bat)
	_rows.append({"kind": "toggle", "key": str(TOGGLE[0]), "words": str(TOGGLE[1]),
		"bat": bc, "window": Rect2(VALUE_X, ty, VALUE_W, 24),
		"bar": Rect2(452, ty - 2, 4, 28),
		"hit": Rect2(POT_X - 8, ty - 6, POT_END - POT_X + 16, 40)})
	# ---- EPSILON, through the old plate; the harness's drop runs through
	# him, and his feed goes down the board's margin, clear of every value
	# and every control, into a terminal in the board's foot. Nothing of
	# his answers to the pointer or the focus.
	MenuParts.epsilon(f, EPSILON)
	MenuParts.wire(f, [Vector2(EPSILON.x, MenuParts.TRUNK_Y), Vector2(EPSILON.x,
			EPSILON.y - 30)], MenuParts.WIRE, 3.5)
	var feed := [Vector2(EPSILON.x + 24, EPSILON.y + 24), Vector2(FEED_X,
		EPSILON.y + 24), Vector2(FEED_X, TERMINAL.get_center().y),
		Vector2(TERMINAL.end.x, TERMINAL.get_center().y)]
	MenuParts.wire(f, feed, MenuParts.WIRE, 3.0, 0.022, 14.0)
	for cy: float in [260.0, 420.0, 520.0]:
		MenuParts.block(f, Rect2(FEED_X - 6, cy - 3, 12, 6), 0.022, 0.028,
				MenuParts.mat(MenuParts.LOOM, 0.1, 0.5))
	MenuParts.block(f, TERMINAL, BZ, BZ + 0.012, MenuParts.mat(MenuParts.TERMINAL, 0.1,
			0.5))
	for i in 2:
		MenuParts.disc(f, Vector2(TERMINAL.position.x + 12 + 22 * i,
				TERMINAL.get_center().y), 4.0, BZ + 0.012, BZ + 0.017,
				MenuParts.mat(MenuParts.BRASS, 0.7, 0.35), 12)
	_info["feed"] = feed
	_info["terminal"] = TERMINAL
	_info["epsilon"] = Rect2(EPSILON - Vector2(50, 40), Vector2(100, 80))


## THE PAUSED BOARD, for the actions on offer: built again when they change
## (a Zone entered or left, Abandon armed or disarmed). The rows it adds
## lead the focus order.
func _build_paused() -> void:
	if _paused != null:
		_paused.queue_free()
	_paused = Node3D.new()
	_paused.name = "Paused"
	face.add_child(_paused)
	var words: Array = pause_menu.switches() if pause_menu != null \
			else [PauseMenu.RESUME, PauseMenu.QUIT]
	var arming := pause_menu != null and pause_menu.is_arming()
	_switch_set = words
	var foot := PAUSED_FULL if (pause_menu != null and pause_menu.in_zone) \
			else PAUSED_HUB
	var poly := PackedVector2Array([Vector2(40, PAUSED_TOP), Vector2(PAUSED_RIGHT - 16,
		PAUSED_TOP), Vector2(PAUSED_RIGHT, PAUSED_TOP + 16), Vector2(PAUSED_RIGHT, foot),
		Vector2(40, foot)])
	var shade := float(shell.shade.get("settings", 1.0))
	MenuParts.board(_paused, poly, MenuParts.FR4, BZ, [Vector2(54, 130),
			Vector2(392, foot - 14)], shade)
	MenuParts.tape(kit, _paused, Vector2(58, 128), "PAUSED", BZ)
	# the joins into OPTIONS: tinned bridges
	MenuParts.bridge(_paused, Vector2(398, 200), Vector2(448, 200))
	MenuParts.bridge(_paused, Vector2(398, foot - 48), Vector2(448, foot - 48))
	# keep the pots and the toggle; the switches lead
	var kept: Array = []
	for r: Dictionary in _rows:
		if str(r["kind"]) != "switch":
			kept.append(r)
	var switches: Array = []
	var y := 170.0 if not arming else 164.0
	for i in words.size():
		var w := str(words[i])
		var big := w == PauseMenu.RESUME and not arming
		var sz := 40.0 if big else 28.0
		if arming and w == PauseMenu.CANCEL:
			# the game's own warning, between RESUME and the choice
			for line in kit.wrap(PauseMenu.WARNING, 2, PAUSED_RIGHT - 96.0):
				MenuParts.text(kit, _paused, line, Vector2(62, y - 4), 2,
						Color("#5a2412"), BZ + 0.0008)
				y += 20.0
			y += 8.0
		var c := Vector2(62 + sz * 0.5, y + sz * 0.5)
		var cap := MenuParts.block(_paused, Rect2(c - Vector2(sz, sz) * 0.5,
				Vector2(sz, sz)), BZ, BZ + 0.008, MenuParts.mat(Color("#2e3032"), 0.5, 0.4))
		kit.pickable("settings", cap, "switch:" + w)
		var ink := Color("#0f3b36") if big else Color("#1b1a17")
		if w == PauseMenu.CONFIRM:
			ink = Color("#5a2412")
		MenuParts.text(kit, _paused, w, Vector2(62 + sz + 16, c.y - (12.0 if big
				else 8.0)), 3 if big else 2, ink, BZ + 0.0008)
		kit.pick_rect("settings", _paused, Rect2(52, c.y - sz * 0.5 - 7,
				PAUSED_RIGHT - 60.0, sz + 14), BZ, BZ + 0.004, "switch:" + w)
		switches.append({"kind": "switch", "words": w, "c": c, "size": sz,
			"bar": Rect2(44, c.y - sz * 0.5, 4, sz),
			"hit": Rect2(52, c.y - sz * 0.5 - 7, PAUSED_RIGHT - 60.0, sz + 14)})
		y += sz + (22.0 if not arming else 10.0)
	var was := str(_rows[focus]["words"]) if focus < _rows.size() else ""
	_rows = switches + kept
	# Focus stays on the same row by its words; arming moves it to CANCEL,
	# the safe choice, where the press that armed it landed.
	focus = 0
	for i in _rows.size():
		if str(_rows[i]["words"]) == was:
			focus = i
	if arming:
		for i in _rows.size():
			if str(_rows[i]["words"]) == PauseMenu.CANCEL:
				focus = i


func _on_pause_changed() -> void:
	if kit == null:
		return
	_build_paused()
	_draw()


# ============================================================ what changes

func _row_of(key: String) -> Dictionary:
	for r: Dictionary in _rows:
		if str(r.get("key", "")) == key:
			return r
	return {}


func _pot_t(key: String) -> float:
	var r := _row_of(key)
	if r.is_empty():
		return 0.0
	var rg: Array = r["range"]
	return clampf((value(key) - float(rg[1])) / (float(rg[2]) - float(rg[1])), 0.0, 1.0)


func value(key: String) -> float:
	return PlayerSettings.shared().value(key)


func flag(key: String) -> bool:
	return PlayerSettings.shared().flag(key)


## Production's words for a value (the old wall's `_describe`), in capitals.
func shown(key: String) -> String:
	var amount := value(key) if key != str(TOGGLE[0]) else 0.0
	match key:
		"mouse_sensitivity":
			return "X%.2f" % (amount / float(PlayerSettings.RANGES[key][0]))
		"field_of_view":
			return "%d DEGREES" % roundi(amount)
		"motion_intensity":
			return "OFF" if amount <= 0.0 else "%d%%" % roundi(amount * 100.0)
		"master_volume":
			return "%d%%" % roundi(amount * 100.0)
		"invert_look_y":
			return "ON" if flag("invert_look_y") else "OFF"
	return ""


## Redraw what changes: the focus, the values' windows, the pots' knobs,
## the bat, the switches' caps, the campaign display, the note.
func _draw(at_once := true) -> void:
	if _dyn != null:
		_dyn.queue_free()
	_dyn = Node3D.new()
	_dyn.name = "Values"
	face.add_child(_dyn)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var here := i == focus
		if here:
			MenuParts.block(_dyn, r["bar"], BZ, BZ + 0.004, MenuParts.unlit(MenuKit.SIGNAL),
					false)
		match str(r["kind"]):
			"switch":
				var c: Vector2 = r["c"]
				var sz: float = r["size"]
				MenuParts.disc(_dyn, c, sz * 0.32, BZ + 0.008, BZ + 0.018,
						MenuParts.unlit(MenuKit.SIGNAL) if here
						else MenuParts.mat(MenuParts.HEADER, 0.1, 0.5), 20)
			"pot":
				var key: String = r["key"]
				MenuParts.flag_window(kit, _dyn, r["window"], shown(key), MenuParts.LIT,
						BZ + 0.004)
				var knob: Node3D = _knobs[key]
				var track: Rect2 = r["track"]
				var z: float = knob.get_meta("z")
				var to := MenuParts.P(Vector2(track.position.x + track.size.x * _pot_t(key),
						0), z) - MenuParts.P(Vector2(track.position.x, 0), z)
				to.y = 0.0
				if at_once:
					knob.position = to
				else:
					kit.go(knob, "position", to, 0.06, "out")
				(knob.get_meta("line") as StandardMaterial3D).albedo_color = \
						MenuKit.SIGNAL if here else Color("#3a3d3f")
			"toggle":
				var on := flag(str(r["key"]))
				MenuParts.flag_window(kit, _dyn, r["window"], shown(str(r["key"])),
						MenuParts.LIT, BZ + 0.004)
				var bc: Vector2 = r["bat"]
				for n: Node in _bat.get_children():
					n.queue_free()
				var bat := MenuParts.slab(_bat, MenuParts.rrect(Rect2(bc.x - 3.5, bc.y
						+ (-22.0 if on else 2.0), 7, 20), 3), BZ + 0.01, BZ + 0.03,
						MenuParts.unlit(MenuKit.SIGNAL) if here
						else MenuParts.mat(Color("#c9ccce"), 0.7, 0.3))
				kit.pickable("settings", bat, "toggle:" + str(r["key"]))
	# the campaign display: JournalQuery.campaign, the client's own
	var ly := 435.0
	var lines := campaign_lines()
	for line: Variant in lines:
		if ly > 590.0:
			break
		MenuParts.text(kit, _dyn, kit.fit(str(line), 2, 298), Vector2(74, ly), 2,
				MenuParts.LCD_INK, BZ + 0.012)
		ly += 22.0
	if note != "" and focus < _rows.size() and str(_rows[focus]["kind"]) == "switch":
		var c: Vector2 = _rows[focus]["c"]
		MenuParts.tape(kit, _dyn, Vector2(236, c.y - 12), note, BZ + 0.002)
	var values := {}
	for row: Array in SLIDERS:
		values[str(row[0])] = shown(str(row[0]))
	values[str(TOGGLE[0])] = shown(str(TOGGLE[0]))
	_info["values_shown"] = values
	_info["campaign"] = lines


# ============================================================ input

func nav(dir: Vector2i, repeat := false) -> void:
	if dir.y != 0:
		var to := clampi(focus + dir.y, 0, _rows.size() - 1)
		note = ""
		_streak = 0
		if to == focus:
			kit.cue("edge")
		else:
			focus = to
			kit.cue("tick")
		_draw()
		return
	if dir.x != 0:
		_change(dir.x, repeat)


## LEFT / RIGHT on a row: a pot moves one of its steps -- more at a time
## while a direction is HELD (its repeats); the bat switch flips; a push
## switch has no sideways.
func _change(step: int, repeat := false) -> void:
	var r: Dictionary = _rows[focus]
	match str(r["kind"]):
		"pot":
			var key := str(r["key"])
			if repeat and step == _streak_dir and key == _streak_key:
				_streak += 1
			else:
				_streak = 0
			_streak_dir = step
			_streak_key = key
			_set_value(key, value(key) + float(r["step"]) * float(step * steps_for(
					_streak)))
		"toggle":
			flip(str(r["key"]))
		_:
			kit.cue("edge")


## How many steps a repeat moves after `streak` repeats of one held
## direction: one, until ACCEL_AFTER; then doubling, to ACCEL_MAX.
static func steps_for(streak: int) -> int:
	if streak < ACCEL_AFTER:
		return 1
	return mini(1 << mini(streak - ACCEL_AFTER + 1, ACCEL_DOUBLINGS), ACCEL_MAX)


## A key or button came up: a held run is over.
func released(_event: InputEvent) -> void:
	_streak = 0


func focus_lost() -> void:
	_streak = 0
	_drag = ""


## Set an option, saved at once and applied where the game applies it.
func set_value(key: String, amount: float) -> void:
	_set_value(key, amount)


func _set_value(key: String, amount: float, at_once := false) -> void:
	var r := _row_of(key)
	if r.is_empty():
		return
	var rg: Array = r["range"]
	var step: float = r["step"]
	var v := clampf(snappedf(amount, step), float(rg[1]), float(rg[2]))
	if is_equal_approx(v, value(key)):
		kit.cue("edge")
		return
	var settings := PlayerSettings.shared()
	settings.set_value(key, v)
	settings.save_to_disk()
	kit.cue("value", 0.8 + 0.5 * _pot_t(key))
	_apply(key)
	_draw(at_once)


## Where the game applies each value, now.
func _apply(key: String) -> void:
	var settings := PlayerSettings.shared()
	match key:
		"field_of_view":
			# Now, not only for the next camera: the one in use is the
			# player's (the menu's own camera is in a world of its own).
			var camera := get_tree().root.get_camera_3d()
			if camera != null and camera.get_parent() is Player:
				camera.fov = settings.value(key)
		"master_volume":
			apply_volume()
		"motion_intensity":
			# MOTION reaches the menu at once: a turn in flight, a slide, a
			# pulse -- the sounds stay.
			if shell != null:
				shell.sync_motion()


func flip(key: String) -> void:
	var settings := PlayerSettings.shared()
	settings.set_flag(key, not settings.flag(key))
	settings.save_to_disk()
	kit.cue("toggle", 1.0 if settings.flag(key) else 0.85)
	_draw()


func accept() -> void:
	var r: Dictionary = _rows[focus]
	match str(r["kind"]):
		"switch":
			_press(str(r["words"]), true)
		"toggle":
			flip(str(r["key"]))
		_:
			kit.cue("edge")


## A push switch: the pause action it names. `fresh`: the press began
## after the board last changed.
func _press(words: String, fresh: bool) -> void:
	note = ""
	if pause_menu == null:
		kit.cue("refuse")
		return
	var did := pause_menu.press(words, fresh)
	if not did:
		kit.cue("refuse")
		return
	kit.cue("toggle")
	if words != PauseMenu.RESUME:
		_draw()


## Back out: an armed Abandon is cancelled. Whether it was.
func back() -> bool:
	if pause_menu != null and pause_menu.disarm():
		kit.cue("tick", 0.75)
		return true
	return false


func back_words() -> String:
	if pause_menu != null and pause_menu.is_arming():
		return "cancel abandon"
	return "close"


func hover(_hit: Dictionary) -> void:
	pass


func click(hit: Dictionary, button := MOUSE_BUTTON_LEFT) -> bool:
	if button != MOUSE_BUTTON_LEFT:
		return false
	var target := str(hit.get("target", ""))
	if target == "":
		return false
	var i := _index_of(target)
	if i < 0:
		return false
	var was := focus
	focus = i
	note = ""
	_streak = 0
	var r: Dictionary = _rows[i]
	match str(r["kind"]):
		"switch":
			# The second click of a double click is not a press of its own:
			# it never confirms what the first one armed.
			_press(str(r["words"]), not bool(hit.get("double", false)))
		"pot":
			if target.begins_with("pot:"):
				_drag = str(r["key"])
				_pot_at(_drag, hit)
				return false                  # held: the shell hands us the drag
			if was != i:
				kit.cue("tick")
			_draw()
		"toggle":
			flip(str(r["key"]))
	return true


func _index_of(target: String) -> int:
	var parts := target.split(":", true, 1)
	if parts.size() < 2:
		return -1
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		match parts[0]:
			"switch":
				if str(r["kind"]) == "switch" and str(r["words"]) == parts[1]:
					return i
			"pot", "row", "toggle":
				if str(r.get("key", "")) == parts[1]:
					return i
	return -1


## The pot being dragged follows the pointer along its track: where the
## pointer is SEEN on the wall (a pot's front is placed seen at its page
## pixels, so the ray's page point is the pot's).
func drag(_rel: Vector2, _button: int, hit := {}) -> void:
	if _drag != "" and not hit.is_empty():
		_pot_at(_drag, hit)


func release(_hit: Dictionary, _button: int) -> void:
	_drag = ""


func _pot_at(key: String, hit: Dictionary) -> void:
	var p: Vector2 = hit.get("at", Vector2.INF)
	if p == Vector2.INF:
		return
	var r := _row_of(key)
	var track: Rect2 = r["track"]
	var rg: Array = r["range"]
	var t := clampf((p.x - track.position.x) / track.size.x, 0.0, 1.0)
	_set_value(key, lerpf(float(rg[1]), float(rg[2]), t), true)


## The wheel over a pot moves it a step a notch -- the ordinary way.
func wheel(hit: Dictionary, dir: int) -> bool:
	var target := str(hit.get("target", ""))
	var i := _index_of(target)
	if i < 0 or str(_rows[i]["kind"]) != "pot":
		return false
	focus = i
	var r: Dictionary = _rows[i]
	_set_value(str(r["key"]), value(str(r["key"])) - float(r["step"]) * float(dir))
	return true


func prompts() -> Array:
	var r: Dictionary = _rows[focus]
	match str(r["kind"]):
		"switch":
			return [["move", "rows"], ["accept", "press"], ["click", "press"]]
		"pot":
			return [["move", "rows"], ["change", "set"], ["click", "set"]]
	return [["move", "rows"], ["change", "flip"], ["accept", "flip"]]


func on_device() -> void:
	pass


## Opened: the board shows the actions on offer, and the focus is on
## RESUME -- ENTER straight back into the game.
func on_open(_is_front: bool) -> void:
	note = ""
	_streak = 0
	_drag = ""
	if kit != null:
		_build_paused()
		focus = 0
		_draw()


func on_close() -> void:
	_drag = ""
	_streak = 0


func on_front(_is_front: bool) -> void:
	_streak = 0


func tick(_delta: float) -> void:
	pass


## A held d-pad repeats here (and speeds a pot up), as a held key does.
func repeats() -> bool:
	return true


# ============================================================ state

func state() -> Dictionary:
	var knobs := {}
	for key: String in _knobs:
		knobs[key] = snappedf((_knobs[key] as Node3D).position.x, 0.0001)
	var rows := []
	for r: Dictionary in _rows:
		rows.append(str(r["words"]))
	return {"focus": focus, "row": str(_rows[focus]["words"]) if focus < _rows.size()
			else "", "kind": str(_rows[focus]["kind"]) if focus < _rows.size() else "",
		"rows": rows, "switches": _switch_set.duplicate(),
		"arming": pause_menu != null and pause_menu.is_arming(),
		"shown": _info.get("values_shown", {}), "campaign": _info.get("campaign", []),
		"note": note, "knobs": knobs, "streak": _streak,
		"feed_clear": _feed_clear(),
		"bus_db": snappedf(AudioServer.get_bus_volume_db(0), 0.01)}


## Epsilon's feed and its terminal cross no value's window and no
## control, with a margin -- checked on the layout itself.
func _feed_clear() -> bool:
	var keep: Array = []
	for r: Dictionary in _rows:
		keep.append((r["hit"] as Rect2))
		if r.has("window"):
			keep.append((r["window"] as Rect2).grow(12))
	var feed: Array = _info.get("feed", [])
	var bits: Array = [(_info["terminal"] as Rect2).grow(6)]
	for i in range(1, feed.size() - 1):
		var a: Vector2 = feed[i]
		var b: Vector2 = feed[i + 1]
		bits.append(Rect2(a, Vector2.ZERO).expand(b).grow(4))
	for bit: Rect2 in bits:
		for k: Rect2 in keep:
			if bit.intersects(k):
				return false
	return true
