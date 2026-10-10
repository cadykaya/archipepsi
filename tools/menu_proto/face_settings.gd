class_name FaceSettings
extends RefCounted
## SETTINGS / PAUSE, as the hybrid's MAINTENANCE SIDE (the owner's rulings
## of 2026-09-27: D's salvaged boards). Three replacement boards of three
## stocks over the old enclosure, joined where they meet:
##
## * PAUSED -- bare FR4: PauseMenu's actions as push switches. RESUME closes
##   the menu; RETURN TO HUB, ABANDON ZONE... and QUIT GAME are the game's,
##   and are not wired here (the switch says so when pressed).
## * CAMPAIGN -- paper phenolic, the rack's own stock, where the rack's
##   ribbon lands from round the corner: JournalQuery.campaign over the
##   same save, on a salvaged character display.
## * OPTIONS -- black mask: SettingsFace's options on repurposed slide pots
##   and a bat switch, at Production's own ranges, steps and words
##   (PlayerSettings.RANGES; SettingsFace._describe), each value in a
##   backlit window. MOTION at OFF is what MenuShell reads as reduced
##   motion; MASTER VOLUME sets the bus the menu's cues play on.
##
## EPSILON comes through the old plate above the OPTIONS board -- his one
## point in the machine: not a slot, a setting, a meter or a status light.
## The harness's drop runs through him, and his feed goes down the board's
## margin into a terminal in the board's empty foot: it touches no value
## and no control (the fifth ruling's refinement).
##
## REVIEW CONTROLS, the prototype's and not the game's, sit apart on a plate
## of their own: the sample save, the equipment sample, symbols or text in
## the prompts, and clearing the equip previews.

# ---- the boards
const PAUSED := [Vector2(40, 116), Vector2(390, 116), Vector2(406, 132), Vector2(406, 378),
	Vector2(40, 378)]
const CAMPAIGN := [Vector2(40, 402), Vector2(406, 402), Vector2(406, 692), Vector2(66, 692),
	Vector2(40, 666)]
const OPTIONS := [Vector2(440, 116), Vector2(1108, 116), Vector2(1132, 168),
	Vector2(1244, 168), Vector2(1244, 628), Vector2(1204, 668), Vector2(1116, 668),
	Vector2(1116, 548), Vector2(440, 548)]
const REVIEW := Rect2(440, 562, 660, 146)
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
const TERMINAL := Rect2(1150, 612, 46, 22)
## Production's options (SettingsFace.SLIDERS, PlayerSettings.RANGES):
## key, words, step, [default, min, max].
const SLIDERS := [
	["mouse_sensitivity", "MOUSE SENSITIVITY", 0.0001, [0.0022, 0.0002, 0.02]],
	["field_of_view", "FIELD OF VIEW", 1.0, [90.0, 60.0, 120.0]],
	["motion_intensity", "MOTION (VIEW BOB, MENU TURNS)", 0.05, [1.0, 0.0, 1.0]],
	["master_volume", "MASTER VOLUME", 0.05, [1.0, 0.0, 1.0]],
]
const TOGGLE := ["invert_look_y", "INVERT LOOK UP AND DOWN"]
const SWITCHES := ["RESUME", "RETURN TO HUB", "ABANDON ZONE…", "QUIT GAME"]

var kit: Kit
var shell: Shell
var face: Node3D
var proto: Node
var focus := 0
var values := {}                      # Production's amounts, by key
var flags := {"invert_look_y": false}
var note := ""                        # the pressed switch's own words
var _rows: Array = []                 # every row: {kind, key, words, hit, ...}
var _dyn: Node3D                      # what changes: focus, windows, notes
var _knobs := {}                      # key -> Node3D (slides)
var _bat: Node3D
var _review: Array = []               # the review rows' own get/set
var _drag := ""                       # the pot a held button is setting
var _streak := 0
var _streak_dir := 0
var _streak_t := 0.0
var _clock := 0.0
var _info := {}


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	face = shell.face_of("settings")
	for row: Array in SLIDERS:
		values[str(row[0])] = float((row[3] as Array)[0])
	if kit.reduced:
		values["motion_intensity"] = 0.0


func bind(p: Node) -> void:
	proto = p
	_review = [
		{"words": "SAMPLE SAVE", "values": ["WALKED", "PROGRESSED", "LATCHED"],
			"get": func() -> int: return ["walked", "progressed", "latched"].find(
					str(proto.get("save"))),
			"set": func(i: int) -> void: proto.call("set_save",
					["walked", "progressed", "latched"][i])},
		{"words": "EQUIPMENT SAMPLE", "values": ["FIXTURE", "FIXTURE + STRESS"],
			"get": func() -> int: return 1 if str(proto.get("equipment_variant")) \
					== "stress" else 0,
			"set": func(i: int) -> void: proto.call("set_equipment",
					"stress" if i == 1 else "base")},
		{"words": "PROMPTS", "values": ["SYMBOLS", "TEXT"],
			"get": func() -> int: return 1 if (proto.get("overlay") as Overlay).text_prompts \
					else 0,
			"set": func(i: int) -> void:
				(proto.get("overlay") as Overlay).text_prompts = i == 1
				proto.call("_refresh")},
		{"words": "CLEAR EQUIP PREVIEWS", "values": ["DO IT"],
			"get": func() -> int: return 0,
			"set": func(_i: int) -> void:
				var eq: FaceEquipment = proto.get("faces")["equipment"]
				eq.preview.clear()
				eq.load_data(eq.data)},
	]
	_build_static()


func load_data(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_draw()


# ============================================================ the boards

func _poly(pts: Array) -> PackedVector2Array:
	return PackedVector2Array(pts)


func _build_static() -> void:
	var f := Node3D.new()
	f.name = "Boards"
	face.add_child(f)
	_rows.clear()
	Parts.seam(f, 423, 112, 704)
	# ---- PAUSED: push switches on a small bare FR4 board
	Parts.board(f, _poly(PAUSED), Parts.FR4, BZ, [Vector2(54, 130), Vector2(392, 364)])
	Parts.tape(kit, f, Vector2(58, 128), "PAUSED", BZ)
	var y := 170.0
	for i in SWITCHES.size():
		var sz := 40.0 if i == 0 else 28.0
		var c := Vector2(62 + sz * 0.5, y + sz * 0.5)
		Parts.block(f, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), BZ, BZ + 0.008,
				Parts.mat(Color("#2e3032"), 0.5, 0.4))
		var ink := Color("#0f3b36") if i == 0 else Color("#1b1a17")
		Parts.text(kit, f, SWITCHES[i], Vector2(62 + sz + 16, c.y - (12.0 if i == 0 else 8.0)),
				3 if i == 0 else 2, ink, BZ + 0.0008)
		_rows.append({"kind": "switch", "words": SWITCHES[i], "c": c, "size": sz,
			"hit": Rect2(52, c.y - sz * 0.5 - 7, 346, sz + 14),
			"bar": Rect2(44, c.y - sz * 0.5, 4, sz)})
		y += sz + 22.0
	# ---- CAMPAIGN: a salvaged character display on paper phenolic -- the
	# rack's own stock -- where the rack's ribbon lands from round the corner
	Parts.board(f, _poly(CAMPAIGN), Parts.PHENOLIC, BZ, [Vector2(54, 416), Vector2(392, 678)])
	var lcd := Rect2(64, 424, 318, 176)
	Parts.block(f, lcd.grow(8), BZ, BZ + 0.01, Parts.mat(Color("#1d2021"), 0.2, 0.5))
	Parts.block(f, lcd, BZ + 0.01, BZ + 0.0106, Parts.mat(Parts.LCD, 0.0, 0.8))
	Parts.tape(kit, f, Vector2(104, 614), "CAMPAIGN", BZ)
	Parts.ribbon(f, [Vector2(Parts.RUN_START, Parts.RIBBON_Y), Vector2(74, Parts.RIBBON_Y)],
			Parts.RIBBON_Z)
	Parts.header(f, Rect2(74, Parts.RIBBON_Y - 12, 12, 24), BZ)
	# ---- OPTIONS: black mask, the biggest board, notched where the old
	# plate is left bare for Epsilon, its foot cut round the review plate
	Parts.board(f, _poly(OPTIONS), Parts.BLACK_MASK, BZ, [Vector2(454, 130),
			Vector2(1094, 130), Vector2(1216, 182), Vector2(1216, 646), Vector2(454, 534),
			Vector2(1130, 654)])
	# the joins: tinned bridges from PAUSED, and a short ribbon from CAMPAIGN
	Parts.bridge(f, Vector2(398, 200), Vector2(448, 200))
	Parts.bridge(f, Vector2(398, 330), Vector2(448, 330))
	Parts.header(f, Rect2(380, 508, 12, 24), BZ)
	Parts.header(f, Rect2(452, 508, 12, 24), BZ)
	Parts.ribbon(f, [Vector2(386, 520), Vector2(458, 520)], BZ + 0.014, 6.0)
	Parts.tape(kit, f, Vector2(POT_X, 126), "OPTIONS", BZ)
	# the pots' tracks and slots; their knobs slide
	for i in SLIDERS.size():
		var row: Array = SLIDERS[i]
		var py := POT_Y0 + POT_PITCH * i
		Parts.tape(kit, f, Vector2(POT_X, py), str(row[1]), BZ)
		var pot := Rect2(POT_X, py + 32, POT_END - POT_X, 16)
		Parts.block(f, pot, BZ, BZ + 0.008, Parts.mat(Parts.PLATE, 0.55, 0.45))
		Parts.block(f, Rect2(pot.position.x + 10, pot.get_center().y - 2, pot.size.x - 20, 4),
				BZ + 0.008, BZ + 0.0084, Parts.unlit(Color("#060606")), false)
		var knob := Node3D.new()
		f.add_child(knob)
		# built at the track's left end; slid to its value
		var kc := Vector2(pot.position.x + 16, py + 40)
		Parts.block(knob, Rect2(kc - Vector2(12, 12), Vector2(24, 24)), BZ + 0.008, BZ + 0.026,
				Parts.mat(Color("#dadcd8"), 0.2, 0.5))
		var line := StandardMaterial3D.new()
		line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.albedo_color = Color("#3a3d3f")
		Parts.block(knob, Rect2(kc.x - 1.5, kc.y - 10, 3, 20), BZ + 0.026, BZ + 0.0266, line,
				false)
		knob.set_meta("line", line)
		knob.set_meta("z", BZ + 0.026)
		_knobs[str(row[0])] = knob
		_rows.append({"kind": "pot", "key": str(row[0]), "words": str(row[1]),
			"step": float(row[2]), "range": row[3],
			"hit": Rect2(POT_X - 8, py - 6, POT_END - POT_X + 16, 62),
			"track": Rect2(pot.position.x + 16, pot.position.y - 8, pot.size.x - 32, 32),
			"window": Rect2(VALUE_X, py, VALUE_W, 24), "bar": Rect2(452, py - 2, 4, 54)})
	# the bat switch
	var ty := POT_Y0 + POT_PITCH * SLIDERS.size()
	Parts.tape(kit, f, Vector2(POT_X, ty), str(TOGGLE[1]), BZ)
	var bc := Vector2(VALUE_X - 38, ty + 12)
	Parts.block(f, Rect2(bc - Vector2(16, 20), Vector2(32, 40)), BZ, BZ + 0.004,
			Parts.mat(Parts.PLATE, 0.55, 0.45))
	Parts.disc(f, bc, 9, BZ + 0.004, BZ + 0.01, Parts.mat(Color("#8c9094"), 0.6, 0.35), 6)
	_bat = Node3D.new()
	f.add_child(_bat)
	_rows.append({"kind": "toggle", "key": str(TOGGLE[0]), "words": str(TOGGLE[1]),
		"hit": Rect2(POT_X - 8, ty - 6, POT_END - POT_X + 16, 40), "bat": bc,
		"window": Rect2(VALUE_X, ty, VALUE_W, 24), "bar": Rect2(452, ty - 2, 4, 28)})
	# ---- REVIEW: the prototype's controls, apart, on a plate of their own
	Parts.block(f, REVIEW, 0.0, 0.006, Parts.mat(Color("#a9adb0"), 0.4, 0.5))
	for p: Vector2 in [REVIEW.position + Vector2(8, 8), Vector2(REVIEW.end.x - 8,
			REVIEW.position.y + 8), Vector2(REVIEW.position.x + 8, REVIEW.end.y - 8),
			REVIEW.end - Vector2(8, 8)]:
		Parts.disc(f, p, 4.0, 0.006, 0.009, Parts.mat(Parts.TIN, 0.6, 0.35), 14)
	Parts.tape(kit, f, REVIEW.position + Vector2(22, 8), "REVIEW -- THE PROTOTYPE'S, NOT "
			+ "THE GAME'S", 0.006)
	for i in _review.size():
		var ry := REVIEW.position.y + 44.0 + 25.0 * i
		Parts.text(kit, f, str(_review[i]["words"]), Vector2(REVIEW.position.x + 26, ry), 2,
				Parts.TAPE_INK, 0.0068)
		_rows.append({"kind": "review", "index": i, "words": str(_review[i]["words"]),
			"hit": Rect2(REVIEW.position.x + 14, ry - 4, REVIEW.size.x - 28, 24),
			"bar": Rect2(REVIEW.position.x + 16, ry - 2, 4, 20), "y": ry})
	# ---- EPSILON, through the old plate; the harness's drop runs through
	# him, and his feed goes down the board's margin, clear of every value
	# and every control, into a terminal in the board's empty foot
	Parts.epsilon(f, EPSILON)
	Parts.wire(f, [Vector2(EPSILON.x, Parts.TRUNK_Y), Vector2(EPSILON.x, EPSILON.y - 30)],
			Parts.WIRE, 3.5)
	var feed := [Vector2(EPSILON.x + 24, EPSILON.y + 24), Vector2(FEED_X, EPSILON.y + 24),
		Vector2(FEED_X, TERMINAL.get_center().y), Vector2(TERMINAL.end.x,
		TERMINAL.get_center().y)]
	Parts.wire(f, feed, Parts.WIRE, 3.0, 0.022, 14.0)
	for cy: float in [260.0, 420.0, 560.0]:
		Parts.block(f, Rect2(FEED_X - 6, cy - 3, 12, 6), 0.022, 0.028,
				Parts.mat(Parts.LOOM, 0.1, 0.5))
	Parts.block(f, TERMINAL, BZ, BZ + 0.012, Parts.mat(Parts.TERMINAL, 0.1, 0.5))
	for i in 2:
		Parts.disc(f, Vector2(TERMINAL.position.x + 12 + 22 * i, TERMINAL.get_center().y),
				4.0, BZ + 0.012, BZ + 0.017, Parts.mat(Parts.BRASS, 0.7, 0.35), 12)
	_info["feed"] = feed
	_info["terminal"] = TERMINAL
	_info["epsilon"] = Rect2(EPSILON - Vector2(50, 40), Vector2(100, 80))


# ============================================================ what changes

func _pot_t(key: String) -> float:
	for r: Dictionary in _rows:
		if str(r.get("key", "")) == key:
			var rg: Array = r["range"]
			return clampf((float(values[key]) - float(rg[1])) / (float(rg[2]) - float(rg[1])),
					0.0, 1.0)
	return 0.0


## Production's words for a value (SettingsFace._describe), in capitals.
func shown(key: String) -> String:
	var amount := float(values.get(key, 0.0))
	match key:
		"mouse_sensitivity":
			return "X%.2f" % (amount / 0.0022)
		"field_of_view":
			return "%d DEGREES" % roundi(amount)
		"motion_intensity":
			return "OFF" if amount <= 0.0 else "%d%%" % roundi(amount * 100.0)
		"master_volume":
			return "%d%%" % roundi(amount * 100.0)
		"invert_look_y":
			return "ON" if bool(flags["invert_look_y"]) else "OFF"
	return ""


## Redraw what changes: the focus, the values' windows, the pots' knobs,
## the bat, the switches' caps, the review plate's values, the note.
func _draw(at_once := true) -> void:
	if proto == null:
		return
	if _dyn != null:
		_dyn.queue_free()
	_dyn = Node3D.new()
	face.add_child(_dyn)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var here := i == focus
		if here:
			var bar: Rect2 = r["bar"]
			Parts.block(_dyn, bar, BZ, BZ + 0.004 if str(r["kind"]) != "review" else 0.01,
					Parts.unlit(Kit.SIGNAL), false)
		match str(r["kind"]):
			"switch":
				var c: Vector2 = r["c"]
				var sz: float = r["size"]
				Parts.disc(_dyn, c, sz * 0.32, BZ + 0.008, BZ + 0.018, Parts.unlit(Kit.SIGNAL)
						if here else Parts.mat(Parts.HEADER, 0.1, 0.5), 20)
			"pot":
				var key: String = r["key"]
				Parts.flag_window(kit, _dyn, r["window"], shown(key), Parts.LIT, BZ + 0.004)
				var knob: Node3D = _knobs[key]
				var track: Rect2 = r["track"]
				var z: float = knob.get_meta("z")
				var to := Parts.P(Vector2(track.position.x + track.size.x * _pot_t(key), 0), z) \
						- Parts.P(Vector2(track.position.x, 0), z)
				to.y = 0.0
				if at_once:
					knob.position = to
				else:
					kit.go(knob, "position", to, 0.06, "out")
				(knob.get_meta("line") as StandardMaterial3D).albedo_color = Kit.SIGNAL \
						if here else Color("#3a3d3f")
			"toggle":
				var on := bool(flags[str(r["key"])])
				Parts.flag_window(kit, _dyn, r["window"], shown(str(r["key"])), Parts.LIT,
						BZ + 0.004)
				var bc: Vector2 = r["bat"]
				for n: Node in _bat.get_children():
					n.queue_free()
				Parts.slab(_bat, Parts.rrect(Rect2(bc.x - 3.5, bc.y + (-22.0 if on else 2.0), 7,
						20), 3), BZ + 0.01, BZ + 0.03, Parts.unlit(Kit.SIGNAL) if here
						else Parts.mat(Color("#c9ccce"), 0.7, 0.3))
			"review":
				var rv: Dictionary = _review[int(r["index"])]
				var current: int = (rv["get"] as Callable).call()
				var x := REVIEW.position.x + 250.0
				var opts: Array = rv["values"]
				for j in opts.size():
					var v := str(opts[j])
					var w := kit.measure(v, 2) + 16.0
					var rr := Rect2(x, float(r["y"]) - 3.0, w, 22)
					if j == current and opts.size() > 1:
						Parts.block(_dyn, rr, 0.006, 0.0066, Parts.mat(Parts.RECESS, 0.0, 0.95),
								false)
						Parts.text(kit, _dyn, v, rr.position + Vector2(8, 3), 2, Parts.LIT,
								0.0078)
					else:
						Parts.text(kit, _dyn, v, rr.position + Vector2(8, 3), 2, Parts.TAPE_INK
								if opts.size() == 1 else Color("#2f3336"), 0.0068)
					x += w + 10.0
	# the campaign display: JournalQuery.campaign over the save in hand
	var journal: Dictionary = (proto.get("sample")["saves"] as Dictionary)[
			str(proto.get("save"))]["journal"]
	var ly := 435.0
	for line: Variant in journal.get("campaign", []):
		Parts.text(kit, _dyn, kit.fit(str(line), 2, 298), Vector2(74, ly), 2, Parts.LCD_INK,
				BZ + 0.012)
		ly += 22.0
	if note != "" and focus < SWITCHES.size():
		var r: Dictionary = _rows[focus]
		var c: Vector2 = r["c"]
		Parts.tape(kit, _dyn, Vector2(236, c.y - 12), note, BZ + 0.002)
	_info["values_shown"] = {}
	for key: String in values:
		_info["values_shown"][key] = shown(key)
	_info["values_shown"]["invert_look_y"] = shown("invert_look_y")


# ============================================================ input

func nav(dir: Vector2i) -> void:
	if dir.y != 0:
		var to := clampi(focus + dir.y, 0, _rows.size() - 1)
		note = ""
		if to == focus:
			kit.cue("edge")
		else:
			focus = to
			kit.cue("tick")
		_draw()
		return
	if dir.x != 0:
		_change(dir.x)


## LEFT / RIGHT on a row: a pot moves one of Production's steps -- more at
## a time while it is held (the steps grow as a held key repeats); the
## switch flips; a review row cycles.
func _change(step: int) -> void:
	var r: Dictionary = _rows[focus]
	match str(r["kind"]):
		"pot":
			if step == _streak_dir and _clock - _streak_t < 0.35:
				_streak += 1
			else:
				_streak = 0
			_streak_dir = step
			_streak_t = _clock
			var n := 1 if _streak < 3 else mini(1 << mini(_streak - 2, 5), 20)
			_set_value(str(r["key"]), float(values[str(r["key"])]) + float(r["step"])
					* float(step * n), false)
		"toggle":
			_flip(str(r["key"]))
		"review":
			var rv: Dictionary = _review[int(r["index"])]
			var n: int = (rv["values"] as Array).size()
			var current: int = (rv["get"] as Callable).call()
			(rv["set"] as Callable).call(posmod(current + step, n))
			kit.cue("value")
			_draw()
		_:
			kit.cue("edge")


func _set_value(key: String, amount: float, at_once: bool) -> void:
	var r: Dictionary = {}
	for row: Dictionary in _rows:
		if str(row.get("key", "")) == key:
			r = row
	var rg: Array = r["range"]
	var step: float = r["step"]
	var v := clampf(snappedf(amount, step), float(rg[1]), float(rg[2]))
	if is_equal_approx(v, float(values[key])):
		kit.cue("edge")
		return
	values[key] = v
	kit.cue("value", 0.8 + 0.5 * _pot_t(key))
	_apply(key)
	_draw(at_once)


## What the prototype does with a value: MOTION at OFF is reduced motion;
## MASTER VOLUME sets the bus the cues play on (SettingsFace.apply_volume).
## The rest are the game's, shown at their real values and applied there.
func _apply(key: String) -> void:
	match key:
		"motion_intensity":
			var off := float(values[key]) <= 0.0
			if off != kit.reduced:
				proto.call("set_reduced", off)
		"master_volume":
			var bus := AudioServer.get_bus_index("Master")
			if bus >= 0:
				AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(values[key]),
						0.0001)))


func _flip(key: String) -> void:
	flags[key] = not bool(flags[key])
	kit.cue("toggle", 1.0 if bool(flags[key]) else 0.85)
	_draw()


## The reduced-motion flag changed elsewhere (--reduced, a tape): MOTION
## follows it.
func sync_reduced() -> void:
	if kit.reduced and float(values["motion_intensity"]) > 0.0:
		values["motion_intensity"] = 0.0
	elif not kit.reduced and float(values["motion_intensity"]) <= 0.0:
		values["motion_intensity"] = 1.0
	_draw()


func accept() -> void:
	var r: Dictionary = _rows[focus]
	match str(r["kind"]):
		"switch":
			_press(focus)
		"toggle":
			_flip(str(r["key"]))
		"review":
			_change(1)
		_:
			kit.cue("edge")


## A PauseMenu switch: RESUME closes the menu; the others are the game's.
func _press(i: int) -> void:
	if i == 0:
		note = ""
		_draw()
		proto.call("_close")
		return
	note = "NOT WIRED HERE"
	kit.cue("refuse")
	_draw()


func back() -> bool:
	return false


func hover_at(p: Vector2) -> void:
	if _drag != "":
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_pot_at(_drag, p)
			return
		_drag = ""


func _pot_at(key: String, p: Vector2) -> void:
	for r: Dictionary in _rows:
		if str(r.get("key", "")) == key and str(r["kind"]) == "pot":
			var track: Rect2 = r["track"]
			var rg: Array = r["range"]
			var t := clampf((p.x - track.position.x) / track.size.x, 0.0, 1.0)
			_set_value(key, lerpf(float(rg[1]), float(rg[2]), t), true)


func click(p: Vector2) -> bool:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if not (r["hit"] as Rect2).has_point(p):
			continue
		var was := focus
		focus = i
		note = ""
		match str(r["kind"]):
			"switch":
				_press(i)
			"pot":
				var track: Rect2 = r["track"]
				if track.grow(10).has_point(p):
					_drag = str(r["key"])
					_pot_at(_drag, p)
				else:
					if was != i:
						kit.cue("tick")
					_draw()
			"toggle":
				_flip(str(r["key"]))
			"review":
				var rv: Dictionary = _review[int(r["index"])]
				var hit := _review_hit(r, rv, p)
				if hit >= 0:
					(rv["set"] as Callable).call(hit)
					kit.cue("value")
				elif was != i:
					kit.cue("tick")
				_draw()
		return true
	return false


## Which of a review row's values a point is on, or -1.
func _review_hit(r: Dictionary, rv: Dictionary, p: Vector2) -> int:
	var x := REVIEW.position.x + 250.0
	var opts: Array = rv["values"]
	for j in opts.size():
		var w := kit.measure(str(opts[j]), 2) + 16.0
		if Rect2(x, float(r["y"]) - 4.0, w, 24).has_point(p):
			return j
		x += w + 10.0
	return -1


## The wheel over a pot moves it a step a notch -- the ordinary way.
func wheel(p: Vector2, dir: int) -> bool:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if str(r["kind"]) == "pot" and (r["hit"] as Rect2).has_point(p):
			focus = i
			_set_value(str(r["key"]), float(values[str(r["key"])]) - float(r["step"])
					* float(dir), false)
			return true
	return false


## Where a named thing is on this wall now, page px (for a tape):
## "row:<i>", "pot:<key>:<t>" (a point along its track), "knob:<key>",
## "review:<i>:<j>" (a review row's value), "value:<key>" (its window).
func target_of(name: String) -> Vector2:
	var p := name.split(":")
	match p[0]:
		"row":
			var i := int(p[1])
			if i >= 0 and i < _rows.size():
				var h: Rect2 = _rows[i]["hit"]
				return Vector2(h.position.x + 60.0, h.get_center().y)
		"pot", "knob":
			for r: Dictionary in _rows:
				if str(r.get("key", "")) == p[1] and str(r["kind"]) == "pot":
					var track: Rect2 = r["track"]
					var t := float(p[2]) if p[0] == "pot" else _pot_t(p[1])
					return Vector2(track.position.x + track.size.x * t, track.get_center().y)
		"review":
			for r: Dictionary in _rows:
				if str(r["kind"]) == "review" and int(r["index"]) == int(p[1]):
					var rv: Dictionary = _review[int(p[1])]
					var x := REVIEW.position.x + 250.0
					var opts: Array = rv["values"]
					for j in opts.size():
						var w := kit.measure(str(opts[j]), 2) + 16.0
						if j == int(p[2]):
							return Vector2(x + w * 0.5, float(r["y"]) + 8.0)
						x += w + 10.0
		"value":
			for r: Dictionary in _rows:
				if str(r.get("key", "")) == p[1] and r.has("window"):
					return (r["window"] as Rect2).get_center()
	return Vector2.INF


func prompts() -> Array:
	var r: Dictionary = _rows[focus]
	match str(r["kind"]):
		"switch":
			return [["move", "rows"], ["accept", "press"], ["click", "press"],
				["turn_left", "turn left"], ["turn_right", "turn right"], ["close", "close"]]
		"pot":
			return [["move", "rows"], ["change", "set"], ["click", "set"],
				["turn_left", "turn left"], ["turn_right", "turn right"], ["close", "close"]]
	return [["move", "rows"], ["change", "change"], ["accept", "change"],
		["turn_left", "turn left"], ["turn_right", "turn right"], ["close", "close"]]


func state() -> Dictionary:
	var hits := []
	var windows := []
	for r: Dictionary in _rows:
		var h: Rect2 = r["hit"]
		hits.append([h.position.x, h.position.y, h.size.x, h.size.y])
		if r.has("window"):
			var w: Rect2 = r["window"]
			windows.append([w.position.x, w.position.y, w.size.x, w.size.y])
	var knobs := {}
	for key: String in _knobs:
		knobs[key] = snappedf((_knobs[key] as Node3D).position.x, 0.0001)
	return {"focus": focus, "row": str(_rows[focus]["words"]), "kind": str(
		_rows[focus]["kind"]), "rows": _rows.size(), "values": values.duplicate(),
		"flags": flags.duplicate(), "shown": _info.get("values_shown", {}),
		"note": note, "hits": hits, "windows": windows, "knobs": knobs,
		"feed_clear": _feed_clear(), "terminal": [TERMINAL.position.x,
			TERMINAL.position.y, TERMINAL.size.x, TERMINAL.size.y],
		"bus_db": snappedf(AudioServer.get_bus_volume_db(0), 0.01)}


## Refinement 1, checked: Epsilon's feed and its terminal cross no value's
## window and no control, with a margin.
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


func on_device() -> void:
	pass


func tick(delta: float) -> void:
	_clock += delta
