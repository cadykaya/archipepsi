extends StudyDir
## DIRECTION A — PATCHBAY / SIGNAL BENCH.
##
## The organizing idea: making a connection between a control and an Echo
## module. The wall is a bench with three instruments on it, and the
## CONNECTION decides where they stand:
##
## * the CONTROL PANEL (left): one jack per key, the key's own cap and
##   title beside it; a patched key holds a plug, and its cord runs off to
##   the module it feeds;
## * the MODULE BAY (right): the modules that fit the focused key, one jack
##   each; the module on the key has that key's cord in its jack;
## * the READOUT (centre) stands ON the connection -- between the key and
##   its modules. It reads the module under the test lead: what it does,
##   and what changes if it is patched to the key in place of what is
##   there. Cords only ever run in the gaps between the instruments, or
##   behind them; never over a word.
##
## Nothing here is a wiring task: moving the selection moves the test lead,
## and ENTER is the patch (a labelled local preview, not sent).

const WALL := Color("#231f1c")
const PANEL := Color("#2c2e31")
const PANEL_HI := Color("#373a3e")
const READOUT := Color("#303337")
const CREAM := Color("#e6ddc7")
const DIM := Color("#aaa18e")
const FAINT := Color("#877f6f")
const NICKEL := Color("#bfc2c4")
const HOLE := Color("#070708")
const CORD := Color("#d8cdb2")
const SLATE := Color("#59616b")
const WINDOW_INK := Color("#0c0e0f")
const AMBER := Color("#f0b64a")
const AMBER_DIM := Color("#b48a3c")

const KEYS := Rect2(36, 64, 244, 628)
const BENCH := Rect2(308, 168, 540, 524)
const BAY := Rect2(874, 64, 370, 628)
const LINK_Y := 176.0             # where the Journal's cord rounds the corner


func title() -> String:
	return "PATCHBAY / SIGNAL BENCH"


func map_shift() -> float:
	return -170.0


func build(c: Dictionary) -> void:
	setup(c)
	for page: String in Kit.PAGES:
		(ctx["shell"].walls[page] as MeshInstance3D).material_override = _wall()
	_equipment()
	_map()
	_journal()
	_settings()
	corner_link(LINK_Y, CORD, 5.0)


func _wall() -> Material:
	var m: StandardMaterial3D = kit.wall_material().duplicate()
	m.albedo_color = Color("#2a2521")
	return m


# ------------------------------------------------------------ the pieces

func panel(f: Node3D, r: Rect2, z0: float, z1: float, colour: Color,
		rad := 10.0) -> void:
	G.slab(f, G.rrect(r, rad), z0, z1, G.mat(colour, 0.15, 0.7))


## A jack: a dark nut, a nickel collar, a dark hole -- set in a panel at `z`.
func jack(f: Node3D, c: Vector2, r: float, z: float) -> void:
	G.disc(f, c, r * 1.3, z, z + 0.002, G.mat(Color("#141416"), 0.4, 0.5), 6)
	G.disc(f, c, r, z + 0.002, z + 0.006, G.mat(NICKEL, 0.55, 0.35))
	G.disc(f, c, r * 0.55, z + 0.006, z + 0.0065, G.unlit(HOLE), 20, false)


## A plug in a jack: its body, in its cord's colour, standing off the panel.
func plug(f: Node3D, c: Vector2, r: float, z: float, colour: Color) -> void:
	G.disc(f, c, r, z + 0.006, z + 0.03, G.mat(colour, 0.1, 0.55))
	G.disc(f, c, r * 0.72, z + 0.03, z + 0.042, G.mat(colour.darkened(0.25), 0.1, 0.6))


func cord(f: Node3D, pts: Array, colour: Color, r := 5.0) -> void:
	G.tube(f, pts, r, G.mat(colour, 0.05, 0.6), 12)


## A recessed display window: dark, flush, its words in readout ink.
func window(f: Node3D, r: Rect2, z: float) -> void:
	G.block(f, r, z - 0.002, z + 0.0005, G.mat(WINDOW_INK, 0.0, 0.9))


func engrave(f: Node3D, s: String, at: Vector2, k: int, colour: Color, z: float) -> Label3D:
	return kit.label(f, s, at, k, colour, z + 0.0012)


# ------------------------------------------------------------ equipment

func _equipment() -> void:
	var f := face("equipment")
	engrave(f, "EQUIPMENT", Vector2(36, 20), 4, CREAM, 0.0)
	engrave(f, "02", Vector2(1244 - kit.measure("02", 4), 20), 4, FAINT, 0.0)
	panel(f, KEYS, 0.0, 0.012, PANEL)
	panel(f, BAY, 0.0, 0.012, PANEL)
	# The readout hangs under the connection it reads.
	panel(f, BENCH, 0.0, 0.024, READOUT, 14.0)
	var z := 0.012
	var jacks := {}
	var keys: Array = ctx["keys"]
	for i in keys.size():
		var k: Dictionary = keys[i]
		var slot := str(k["slot"])
		var y := 88.0 + 96.0 * i
		var zt := z
		if i == 0:
			# the focused key: its row lit, and a signal ring round its jack
			G.slab(f, G.rrect(Rect2(44, y - 10, 228, 86), 8), z, z + 0.002,
					G.mat(PANEL_HI, 0.1, 0.7))
			zt = z + 0.003
		var w := keycap(f, str(k["keycap"]), Vector2(56, y), zt)
		engrave(f, str(k["title"]), Vector2(56 + w + 10, y + 6), 2, DIM, zt)
		var on := seated(slot)
		var line := "EMPTY" if on == "" else kit.fit(name_of(on), 2, 150)
		engrave(f, line, Vector2(56, y + 38), 2, FAINT if on == "" else CREAM, zt)
		if on != "" and charges(on) != "":
			engrave(f, charges(on), Vector2(56, y + 58), 2, DIM, zt)
		var jc := Vector2(246, y + 30)
		jack(f, jc, 18, z)
		jacks[slot] = jc
		if i == 0:
			G.ring(f, jc, 25, 29, z + 0.006, G.unlit(Kit.SIGNAL), false)
		if on != "":
			plug(f, jc, 12, z, CORD if i == 0 else SLATE)
	# ALWAYS ON: hardwired, not patched -- no jacks, no cords.
	var ay := 578.0
	engrave(f, "ALWAYS ON", Vector2(56, ay), 2, DIM, z)
	engrave(f, "NOT A SWITCH", Vector2(56, ay + 20), 2, FAINT, z)
	var py := ay + 46.0
	var copper := G.mat(Color("#b87333"), 0.5, 0.45)
	G.block(f, Rect2(236, py - 4, 6, 3 * 22.0), z, z + 0.004, copper)
	for id: String in ctx["passives"]:
		engrave(f, kit.fit(name_of(id), 2, 180), Vector2(56, py), 2, CREAM, z)
		G.block(f, Rect2(222, py + 6, 16, 2), z, z + 0.003, copper)
		py += 22.0
	# ---- the bay: what patches to the focused key
	var slot0: String = ctx["slot"]
	var cap := cap_of(slot0)
	engrave(f, "FITS " + cap, Vector2(894, 80), 2, DIM, z)
	var count := str((ctx["candidates"] as Array).size())
	engrave(f, count, Vector2(1224 - kit.measure(count, 2), 80), 2, DIM, z)
	var rows := {}
	var ids: Array = ctx["candidates"]
	for i in ids.size():
		var id: String = ids[i]
		var y := 110.0 + 44.0 * i
		var zt := z
		if id == ctx["inspected"]:
			G.slab(f, G.rrect(Rect2(882, y - 6, 354, 42), 6), z, z + 0.002,
					G.mat(PANEL_HI, 0.1, 0.7))
			zt = z + 0.003
		var jc := Vector2(894, y + 15)
		jack(f, jc, 9, z)
		rows[id] = jc
		engrave(f, kit.fit(name_of(id), 2, 316), Vector2(914, y), 2,
				CREAM if id == ctx["inspected"] else DIM, zt)
		var tags := [mk(id)]
		if id == ctx["equipped"]:
			tags.append("PATCHED TO " + cap)
		if authored(id):
			tags.append("AUTHORED")
		engrave(f, " · ".join(tags), Vector2(914, y + 19), 2,
				CREAM if id == ctx["equipped"] else FAINT, zt)
		if id == ctx["equipped"]:
			plug(f, jc, 7, z, CORD)
	# ---- the connection: the key's own cord, hung across the top of the
	# bench from its jack to the module in it. The readout hangs under it.
	var from: Vector2 = jacks[slot0]
	var to: Vector2 = rows[ctx["equipped"]]
	cord(f, [G.P(from, 0.054)] + G.smooth([from + Vector2(24, 0), from + Vector2(80, 16),
			Vector2(578, 146), to + Vector2(-80, 16), to + Vector2(-20, 1)], 0.045, 10)
			+ [G.P(to, 0.05)], CORD, 5.5)
	# the other patched keys' cords: dressed down the gap, to modules not
	# on this bay
	var drop := 0
	for slot: String in jacks:
		if slot == slot0 or seated(slot) == "":
			continue
		var j: Vector2 = jacks[slot]
		drop += 1
		cord(f, [G.P(j, 0.054)] + G.smooth([j + Vector2(18, 2), Vector2(288 + 5 * drop,
				j.y + 30), Vector2(290 + 5 * drop, 700)], 0.028, 8), SLATE, 4.0)
	# the test lead: the inspected module, read by the readout
	var tj: Vector2 = rows[ctx["inspected"]]
	var ry := clampf(tj.y, BENCH.position.y + 20.0, BENCH.end.y - 20.0)
	jack(f, Vector2(BENCH.end.x - 8, ry), 8, 0.024)
	plug(f, tj, 7, z, Kit.SIGNAL)
	cord(f, [G.P(tj, 0.046)] + G.smooth([tj + Vector2(-10, 4), Vector2(862, (tj.y + ry) * 0.5
			+ 20), Vector2(BENCH.end.x, ry + 4)], 0.05, 8) + [G.P(Vector2(BENCH.end.x - 8, ry),
			0.066)], Kit.SIGNAL, 4.0)
	_readout(f)


## The readout: the inspected module, and what changes if it is patched.
## What it does and what changes come first; where it came from is last,
## and quiet.
func _readout(f: Node3D) -> void:
	var id: String = ctx["inspected"]
	var slot: String = ctx["slot"]
	var cap := cap_of(slot)
	var z := 0.024
	var x := BENCH.position.x + 22.0
	var w := BENCH.size.x - 44.0
	var y := BENCH.position.y + 16.0
	var kind := "FITS %s · %s · %s" % [cap, str(item(id).get("family", "")), mk(id)]
	engrave(f, kind, Vector2(x, y), 2, DIM, z)
	y += 26.0
	var fit := name_fit(name_of(id), w, 5, 4, 3)
	for line: String in fit[1]:
		engrave(f, line, Vector2(x, y), fit[0], CREAM, z)
		y += 8.0 * int(fit[0]) + 6.0
	y += 4.0
	engrave(f, "DOES", Vector2(x, y + 6), 2, FAINT, z)
	for line: String in does(id):
		y = para(f, line.to_upper(), Vector2(x + 62, y), w - 62, 3, CREAM, z + 0.0012, 30.0)
	y = para(f, desc(id).to_upper(), Vector2(x, y + 2), w, 2, DIM, z + 0.0012, 20.0)
	# What changes if patched: the readout's window, in readout ink.
	y += 8.0
	var lines: Array = ctx["comparison"]
	var head := "IF PATCHED TO %s, IN PLACE OF %s" % [cap, name_of(ctx["equipped"])]
	var head_lines := kit.wrap(head, 2, w - 8)
	var box := Rect2(x - 8, y, w + 16, 16.0 + 20.0 * head_lines.size() + 6.0
			+ table_height(lines, w - 16) + 8.0)
	window(f, box, z)
	var hy := y + 10.0
	for line: String in head_lines:
		engrave(f, line, Vector2(x + 4, hy), 2, AMBER_DIM, z)
		hy += 20.0
	table(f, lines, x + 4, hy + 6.0, w - 16, z + 0.0012, AMBER_DIM, AMBER, AMBER_DIM)
	y = box.end.y + 10.0
	# The patch itself: one press. Local, labelled, never sent.
	var act := action(id)
	if act != "":
		var bw := kit.measure(act, 2) + 110.0
		G.slab(f, G.rrect(Rect2(x - 4, y, bw, 38), 8), z, z + 0.008,
				G.mat(Color("#1d3a37"), 0.1, 0.6))
		keycap(f, "ENTER", Vector2(x + 6, y + 6), z + 0.008)
		engrave(f, act, Vector2(x + 94, y + 11), 2, Kit.SIGNAL, z + 0.008)
		if authored(id):
			engrave(f, "AUTHORED", Vector2(x + w - kit.measure("AUTHORED", 2), y + 11), 2,
					FAINT, z)
		y += 48.0
	# Where it came from: available, and quiet.
	for h: Array in history(id):
		engrave(f, kit.fit("%s  %s" % [h[0], h[1]], 2, w), Vector2(x, y), 2, FAINT, z)
		y += 20.0


# ------------------------------------------------------------ map

func _map() -> void:
	var f := face("map")
	var win := FaceMap.WINDOW
	# The bench wall round the instrument, and the instrument's bezel.
	var bw := G.mat(Color("#2a2521"), 0.0, 1.0)
	for r: Rect2 in [Rect2(0, 0, 1280, win.position.y - 18), Rect2(0, win.end.y + 18,
			1280, 720 - win.end.y - 18), Rect2(0, 0, win.position.x - 18, 720),
			Rect2(win.end.x + 18, 0, 1280 - win.end.x - 18, 720)]:
		G.block(f, r, -0.001, 0.0, bw, false)
	var bez := G.mat(PANEL, 0.15, 0.7)
	for r: Rect2 in [Rect2(win.position.x - 18, win.position.y - 18, win.size.x + 36, 18),
			Rect2(win.position.x - 18, win.end.y, win.size.x + 36, 18),
			Rect2(win.position.x - 18, win.position.y, 18, win.size.y),
			Rect2(win.end.x, win.position.y, 18, win.size.y)]:
		G.block(f, r, 0.0, 0.014, bez)
	engrave(f, "MAP", Vector2(36, 20), 4, CREAM, 0.0)
	engrave(f, "03", Vector2(1244 - kit.measure("03", 4), 20), 4, FAINT, 0.0)
	# The detail: a readout patched in at the window's right, MapFace's own
	# words in readout ink.
	var r := Rect2(win.end.x - 332, win.position.y + 16, 316, 360)
	panel(f, r, 0.016, 0.034, READOUT, 12.0)
	var lines := (ctx["detail"] as String).split("\n")
	var y := r.position.y + 18.0
	engrave(f, lines[0], Vector2(r.position.x + 18, y), 3, CREAM, 0.034)
	y += 34.0
	var box := Rect2(r.position.x + 12, y, r.size.x - 24, r.end.y - y - 14)
	window(f, box, 0.034)
	y += 12.0
	for i in range(1, lines.size()):
		y = para(f, lines[i].to_upper(), Vector2(box.position.x + 10, y), box.size.x - 20,
				2, AMBER if i > 1 else AMBER_DIM, 0.0352, 20.0) + 6.0
	engrave(f, "MAPFACE'S OWN DETAIL", Vector2(r.position.x + 18, r.end.y + 10), 2, FAINT,
			0.0)
	# The Journal's cord comes round the corner and plugs in at the bezel;
	# from there the menu's guide stroke goes in along its height, and down
	# onto the passage.
	var j := Vector2(win.position.x - 9, LINK_Y)
	cord(f, G.smooth([Vector2(18, LINK_Y), Vector2(26, LINK_Y + 4), j + Vector2(-2, 0)],
			0.03, 6) + [G.P(j, 0.05)], CORD, 5.0)
	jack(f, j, 8, 0.014)
	plug(f, j, 6, 0.014, CORD)
	guide(f, Vector2(win.position.x + 4, LINK_Y), ctx["link_page"], CREAM)


# ------------------------------------------------------------ journal

func _journal() -> void:
	var f := face("journal")
	var j: Dictionary = ctx["journal"]
	engrave(f, "JOURNAL", Vector2(36, 20), 4, CREAM, 0.0)
	engrave(f, "04", Vector2(1244 - kit.measure("04", 4), 20), 4, FAINT, 0.0)
	var z := 0.012
	panel(f, Rect2(36, 64, 520, 628), 0.0, z, PANEL)
	panel(f, Rect2(596, 64, 604, 628), 0.0, z, PANEL)
	var y := 82.0
	engrave(f, "OBJECTIVES", Vector2(56, y), 2, FAINT, z)
	y += 26.0
	for s: String in j["objectives"]:
		y = para(f, s.to_upper(), Vector2(56, y), 480, 2, CREAM, z + 0.0012, 20.0) + 6.0
	y += 14.0
	engrave(f, "NOTES", Vector2(56, y), 2, FAINT, z)
	y += 26.0
	for n: Dictionary in j["notes"]:
		if y > 660.0:
			break
		y = para(f, ("%s -- %s" % [n["title"], n["text"]]).to_upper(), Vector2(56, y), 480,
				2, DIM, z + 0.0012, 20.0) + 4.0
	# The findings: each with somewhere on the Map has an output jack.
	var x := 616.0
	y = 82.0
	engrave(f, "STILL SHUT", Vector2(x, y), 2, FAINT, z)
	y += 28.0
	var shut: Array = j["still_shut"]
	for i in shut.size():
		var focused := i == 0
		var h := 20.0 * kit.wrap(str(shut[i]).to_upper(), 2, 500).size()
		if focused:
			h += 8.0 + 20.0 * (ctx["explanation"] as Array).size()
			G.slab(f, G.rrect(Rect2(x - 12, y - 8, 578, h + 16), 8), z, z + 0.002,
					G.mat(PANEL_HI, 0.1, 0.7))
		var yy := para(f, str(shut[i]).to_upper(), Vector2(x, y), 500, 2,
				CREAM if focused else DIM, z + 0.003, 20.0)
		if focused:
			for line: String in ctx["explanation"]:
				yy = para(f, line, Vector2(x + 16, yy + 2), 480, 2, DIM, z + 0.003, 20.0)
		var jc := Vector2(1170, y + 9)
		jack(f, jc, 8, z)
		var bead: Dictionary = ctx["beads"][i]
		kit.sprite(f, bead["icon"], Vector2(1140, y + 9), 2, bead["colour"], z + 0.004)
		if focused:
			plug(f, jc, 6, z, CORD)
			cord(f, [G.P(jc, 0.046)] + G.smooth([jc + Vector2(12, 4), Vector2(1224,
					LINK_Y), Vector2(1262, LINK_Y)], 0.03, 10), CORD, 5.0)
		y += h + 18.0
	y += 8.0
	engrave(f, "WHAT YOU DID HERE", Vector2(x, y), 2, FAINT, z)
	y += 26.0
	for s: String in j["done_here"]:
		y = para(f, s.to_upper(), Vector2(x, y), 540, 2, DIM, z + 0.003, 20.0) + 4.0
	y += 14.0
	engrave(f, "PLACES FOUND", Vector2(x, y), 2, FAINT, z)
	y += 26.0
	for s: String in j["places"]:
		engrave(f, s.to_upper(), Vector2(x, y), 2, DIM, z)
		jack(f, Vector2(1170, y + 8), 7, z)
		y += 24.0


# ------------------------------------------------------------ settings

func _settings() -> void:
	var f := face("settings")
	var s: Dictionary = ctx["settings"]
	engrave(f, "SETTINGS", Vector2(36, 20), 4, CREAM, 0.0)
	engrave(f, "01", Vector2(1244 - kit.measure("01", 4), 20), 4, FAINT, 0.0)
	var z := 0.012
	# PAUSED: the device's front buttons. RESUME is the big one.
	panel(f, Rect2(36, 64, 330, 330), 0.0, z, PANEL)
	engrave(f, "PAUSED", Vector2(56, 82), 2, FAINT, z)
	var y := 112.0
	for i in (s["paused"] as Array).size():
		var label: String = s["paused"][i]
		var h := 58.0 if i == 0 else 42.0
		G.slab(f, G.rrect(Rect2(56, y, 290, h), 10), z, z + (0.012 if i == 0 else 0.008),
				G.mat(Color("#1d3a37") if i == 0 else PANEL_HI, 0.1, 0.6))
		engrave(f, label, Vector2(76, y + (h - 16) * 0.5), 3 if i == 0 else 2,
				Kit.SIGNAL if i == 0 else CREAM, z + (0.012 if i == 0 else 0.008))
		y += h + 12.0
	# OPTIONS: the calibration surface -- faders at their real defaults.
	panel(f, Rect2(406, 64, 838, 420), 0.0, z, PANEL)
	engrave(f, "CALIBRATION -- OPTIONS", Vector2(426, 82), 2, FAINT, z)
	y = 124.0
	for sl: Array in s["sliders"]:
		engrave(f, str(sl[0]), Vector2(426, y), 2, CREAM, z)
		engrave(f, str(sl[2]), Vector2(1224 - kit.measure(str(sl[2]), 2), y), 2, DIM, z)
		var track := Rect2(426, y + 30, 798, 6)
		G.block(f, track, z, z + 0.002, G.mat(HOLE, 0.0, 0.9))
		var kx := track.position.x + track.size.x * float(sl[1])
		G.slab(f, G.rrect(Rect2(kx - 12, y + 20, 24, 26), 5), z, z + 0.02,
				G.mat(NICKEL, 0.5, 0.35))
		y += 72.0
	for t: Array in s["toggles"]:
		engrave(f, str(t[0]), Vector2(426, y), 2, CREAM, z)
		engrave(f, "OFF" if not bool(t[1]) else "ON", Vector2(1224 - 36, y), 2, DIM, z)
		G.slab(f, G.rrect(Rect2(1110, y - 4, 60, 26), 12), z, z + 0.006, G.mat(HOLE, 0.0, 0.9))
		G.disc(f, Vector2(1123, y + 9), 10, z + 0.006, z + 0.02, G.mat(NICKEL, 0.5, 0.35))
	# CAMPAIGN: a plate of plain facts.
	panel(f, Rect2(36, 414, 330, 278), 0.0, z, PANEL)
	engrave(f, "CAMPAIGN", Vector2(56, 432), 2, FAINT, z)
	y = 458.0
	for line: String in s["campaign"]:
		engrave(f, kit.fit(line.to_upper(), 2, 290), Vector2(56, y), 2, DIM, z)
		y += 22.0
