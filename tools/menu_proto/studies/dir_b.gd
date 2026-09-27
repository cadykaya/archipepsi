extends StudyDir
## DIRECTION B — ROUTED HARNESS / CABLE LOOM.
##
## The organizing idea: ONE signal run -- the trunk -- laced round the whole
## box, branching only where something needs it. There are no panels: the
## walls are the formboard the harness is laid on, and the harness's own
## route decides where things stand and where the open space is.
##
## * The trunk runs round all four walls at one height and rounds every
##   corner post. Each wall's title is a flag label on it; headings are
##   flags and markers on the runs they head.
## * Equipment: the key loom drops from the trunk, a connector for each
##   key. The focused key's BRANCH leaves the loom at that key, runs over
##   and down: the modules that fit the key are laid along it. The
##   inspected module's breakout runs on into the readout -- a tag hung
##   from the trunk, where what it does and what changes are read first.
## * Journal -> Map: the link is its own ivory wire. It leaves the entry,
##   is laced along the trunk round the corner, and drops into the Map's
##   window over the place it means.
## * Settings: the controls sit along the same device: a slider is a
##   sleeve on a taut wire, at its real default.
##
## Nothing here is a wiring task: moving the selection moves along the
## branch, and ENTER is the preview (labelled, local, not sent).

const BOARD := Color("#1d2228")
const LOOM := Color("#141619")
const LACE := Color("#b09863")
const WIRE := Color("#666d74")
const BRANCH := Color("#cfd3d4")
const IVORY := Color("#eadcb8")
const FLAG := Color("#b0aa96")
const FLAG_INK := Color("#1b1c1e")
const TAG_DIM := Color("#555148")
const TAG_FAINT := Color("#7a7467")
const TAG_NEW := Color("#07645c")
const INK := Color("#e2e6e5")
const DIM := Color("#9ba5a5")
const FAINT := Color("#6d7777")
const METAL := Color("#a3a8ab")
const HOUSING := Color("#2b2e32")
const RUBBER := Color("#202225")
const TINNED := Color("#8e9396")

const TRUNK_Y := 64.0
const TRUNK_Z := 0.022
const TRUNK_R := 10.0
const LINK_Y := 36.0            # the Journal's link, laced above the trunk
const LINK_Z := 0.02
const WIRE_Z := 0.016
const LOOM_X := 300.0
const KEY_Y0 := 136.0
const KEY_PITCH := 72.0
const SPINE_X := 690.0
const ROW_Y0 := 192.0
const ROW_PITCH := 38.0
const TAG := Rect2(730, 108, 510, 586)
const TAG_Z := 0.03


func title() -> String:
	return "ROUTED HARNESS / CABLE LOOM"


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
	for page: String in Kit.PAGES:
		corner(page, TRUNK_Y, TRUNK_R, _loom(), TRUNK_Z)
	corner("journal", LINK_Y, 4.0, G.mat(IVORY, 0.05, 0.55), LINK_Z)


func _wall() -> Material:
	var m: StandardMaterial3D = kit.wall_material().duplicate()
	m.albedo_color = BOARD
	return m


func _loom() -> Material:
	return G.mat(LOOM, 0.1, 0.45)


# ------------------------------------------------------------ the pieces

## The trunk's run across a wall, laced every so often where nothing else
## holds it, and clamped to the board at `clamps`. `clear` keeps the lacing
## off page-x spans (flags, splits).
func trunk(f: Node3D, clamps: Array, clear: Array) -> void:
	G.tube(f, [G.P(Vector2(RUN_START, TRUNK_Y), TRUNK_Z),
			G.P(Vector2(RUN_END, TRUNK_Y), TRUNK_Z)], TRUNK_R, _loom(), 16)
	var spans := clear.duplicate()
	for cx: float in clamps:
		spans.append(Vector2(cx - 14.0, cx + 14.0))
	var x := RUN_START + 24.0
	while x < RUN_END - 12.0:
		var free := true
		for span: Vector2 in spans:
			if x > span.x - 10.0 and x < span.y + 10.0:
				free = false
		if free:
			tie(f, Vector2(x, TRUNK_Y), false, TRUNK_R, TRUNK_Z)
		x += 44.0
	for cx: float in clamps:
		saddle(f, cx)


## A lacing tie round a cable: a band of waxed cord and its knot.
func tie(f: Node3D, at: Vector2, vertical: bool, r: float, z: float) -> void:
	G.sleeve(f, at, vertical, r + 1.1, 4.0, z, G.mat(LACE, 0.0, 0.8), 14)
	G.disc(f, at, 2.4, z + r * Kit.px(), z + r * Kit.px() + 0.0025,
			G.mat(LACE.darkened(0.15), 0.0, 0.8), 10)


## A saddle clamp holding the trunk to the board: its plate, its strap and
## two screws.
func saddle(f: Node3D, x: float) -> void:
	var m := G.mat(METAL, 0.6, 0.35)
	G.block(f, Rect2(x - 8, TRUNK_Y - TRUNK_R - 12, 16, 2 * TRUNK_R + 24), 0.0, 0.003, m)
	G.sleeve(f, Vector2(x, TRUNK_Y), false, TRUNK_R + 1.8, 12.0, TRUNK_Z, m)
	for s: float in [-1.0, 1.0]:
		G.disc(f, Vector2(x, TRUNK_Y + s * (TRUNK_R + 7.0)), 3.2, 0.003, 0.0065,
				G.mat(Color("#70767a"), 0.6, 0.4), 12)


## A flag label on the trunk: its band round the cable, the flag hanging
## from it, the words in dark ink. `faint` follows the words, fainter.
func flag(f: Node3D, x: float, words: String, k: int, faint := "") -> Rect2:
	var pad := 12.0
	var w := kit.measure(words, k) + pad * 2.0
	if faint != "":
		w += kit.measure(faint, k) + 18.0
	var card := G.mat(toned(FLAG, f), 0.0, 1.0)
	G.sleeve(f, Vector2(x + w * 0.5, TRUNK_Y), false, TRUNK_R + 1.6, w, TRUNK_Z, card, 18)
	var r := Rect2(x, TRUNK_Y + TRUNK_R - 4.0, w, 8.0 * k + 18.0)
	G.slab(f, G.rrect(r, 3.0), TRUNK_Z - 0.0015, TRUNK_Z + 0.0015, card)
	kit.label(f, words, Vector2(x + pad, r.position.y + 10.0), k, FLAG_INK, TRUNK_Z + 0.0027)
	if faint != "":
		kit.label(f, faint, Vector2(x + pad + kit.measure(words, k) + 18.0,
				r.position.y + 10.0), k, TAG_FAINT, TRUNK_Z + 0.0027)
	return r


## A flag label on a vertical run at `x`, sticking out to its right.
func vflag(f: Node3D, x: float, y: float, words: String, r := 4.0, z := WIRE_Z) -> Rect2:
	var w := kit.measure(words, 2) + 22.0
	var h := 30.0
	var card := G.mat(toned(FLAG, f), 0.0, 1.0)
	G.sleeve(f, Vector2(x, y + h * 0.5), true, r + 1.6, h, z, card, 14)
	var rect := Rect2(x + r - 2.0, y, w + 2.0, h)
	G.slab(f, G.rrect(rect, 3.0), z - 0.0012, z + 0.0012, card)
	kit.label(f, words, Vector2(x + r + 9.0, y + 7.0), 2, FLAG_INK, z + 0.0024)
	return rect


## A printed heat-shrink marker on a horizontal wire: the heading of the
## run it is on.
func marker(f: Node3D, cx: float, y: float, words: String, z := WIRE_Z) -> void:
	var w := kit.measure(words, 2) + 18.0
	var rr := 11.5
	G.sleeve(f, Vector2(cx, y), false, rr, w, z, G.mat(toned(FLAG, f), 0.0, 1.0), 20)
	kit.label(f, words, Vector2(cx - w * 0.5 + 9.0, y - 8.0), 2, FLAG_INK,
			z + rr * Kit.px() + 0.0008)


## A hang tag: card, chamfered at the top, hung by two strings from the
## trunk through reinforced eyelets.
func tag(f: Node3D, r: Rect2, z := TAG_Z, eyelets := true) -> void:
	var ch := 16.0
	var poly := PackedVector2Array([r.position + Vector2(ch, 0),
		Vector2(r.end.x - ch, r.position.y), Vector2(r.end.x, r.position.y + ch), r.end,
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, ch)])
	G.slab(f, poly, z - 0.004, z, G.mat(toned(FLAG, f), 0.0, 1.0))
	if not eyelets:
		return
	for ex: float in [r.position.x + 38.0, r.end.x - 38.0]:
		var e := Vector2(ex, r.position.y + 15.0)
		G.ring(f, e, 4.0, 7.5, z + 0.0004, G.mat(METAL, 0.6, 0.35))
		G.disc(f, e, 4.0, z - 0.0042, z + 0.0002, G.unlit(Color("#0b0d0f")), 16, false)
		G.tube(f, [G.P(Vector2(ex, TRUNK_Y + TRUNK_R - 2.0), TRUNK_Z + 0.004),
			G.P(Vector2(ex, (TRUNK_Y + e.y) * 0.5), (TRUNK_Z + z) * 0.5 + 0.004),
			G.P(e + Vector2(0, -2), z + 0.002)], 1.6, G.mat(LACE, 0.0, 0.8), 8)


## Words on a tag (just off its face).
func on_tag(f: Node3D, s: String, at: Vector2, k: int, colour: Color, z := TAG_Z) -> void:
	kit.label(f, s, at, k, colour, z + 0.0012)


func wire(f: Node3D, page: Array, colour: Color, r := 4.0, z := WIRE_Z, bend := 18.0,
		lit := true) -> void:
	G.tube(f, G.routed(page, bend, z), r, G.mat(colour, 0.05, 0.55) if lit
			else G.unlit(colour), 12)


## A connector housing on the key loom: mated (the key holds something) or
## an open face (EMPTY) -- the key's real state, nothing else.
func housing(f: Node3D, r: Rect2, mated: bool) -> void:
	G.slab(f, G.rrect(r, 4.0), 0.0, 0.02, G.mat(HOUSING, 0.1, 0.55))
	G.block(f, Rect2(r.position.x + 7, r.position.y - 4, r.size.x - 14, 6), 0.004, 0.015,
			G.mat(HOUSING.lightened(0.12), 0.1, 0.55))
	if mated:
		G.slab(f, G.rrect(r.grow(-5.0), 3.0), 0.02, 0.031, G.mat(Color("#8c9298"), 0.2, 0.5))
		G.block(f, Rect2(r.position.x - 10, r.get_center().y - 3, 12, 6), 0.012, 0.02,
				G.mat(WIRE, 0.05, 0.55))
	else:
		for i in 3:
			G.disc(f, Vector2(r.get_center().x, r.position.y + 13.0 + 10.0 * i), 2.4,
					0.0195, 0.0205, G.unlit(Color("#060708")), 10, false)


# ------------------------------------------------------------ equipment

func _equipment() -> void:
	var f := face("equipment")
	var title_flag := flag(f, 40, "EQUIPMENT", 4, "02")
	trunk(f, [640.0, 1116.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(LOOM_X - 14, LOOM_X + 14), Vector2(TAG.position.x + 24, TAG.position.x + 52),
			Vector2(TAG.end.x - 52, TAG.end.x - 24)])
	var slot0: String = ctx["slot"]
	var cap := cap_of(slot0)
	# ---- the key loom: down from the trunk, a connector for each key
	var loom_end := 596.0
	var boot := G.mat(RUBBER, 0.05, 0.7)
	wire(f, [Vector2(LOOM_X, TRUNK_Y), Vector2(LOOM_X, loom_end)], LOOM, 7.0, WIRE_Z)
	G.sleeve(f, Vector2(LOOM_X, TRUNK_Y + 20), true, 9.5, 22, WIRE_Z + 0.002, boot)
	G.sleeve(f, Vector2(LOOM_X, loom_end), true, 8.6, 10, WIRE_Z, boot)
	var keys: Array = ctx["keys"]
	var rows_y := {}
	for i in keys.size():
		var k: Dictionary = keys[i]
		var slot := str(k["slot"])
		var y := KEY_Y0 + KEY_PITCH * i
		rows_y[slot] = y
		var on := seated(slot)
		var here := slot == slot0
		if here:
			# the key the branch leaves from: its row lit
			G.block(f, Rect2(28, y - 4, 4, 58), 0.0, 0.004, G.unlit(BRANCH))
		var w := keycap(f, str(k["keycap"]), Vector2(40, y), 0.002)
		text(f, str(k["title"]), Vector2(40 + w + 10, y + 6), 2, INK if here else DIM)
		var line := "EMPTY" if on == "" else kit.fit(name_of(on), 2, 196)
		text(f, line, Vector2(40, y + 34), 2, FAINT if on == "" else (INK if here else DIM))
		if on != "" and charges(on) != "":
			text(f, charges(on), Vector2(246 - kit.measure(charges(on), 2), y + 6), 2, DIM)
		housing(f, Rect2(LOOM_X - 38, y + 4, 28, 46), on != "")
	# ALWAYS ON: hardwired to the loom's end -- no connector, no key.
	var ay := 500.0
	text(f, "ALWAYS ON", Vector2(40, ay), 2, DIM)
	text(f, "NO KEY", Vector2(40 + kit.measure("ALWAYS ON", 2) + 14, ay), 2, FAINT)
	var py := ay + 30.0
	for id: String in ctx["passives"]:
		text(f, kit.fit(name_of(id), 2, 200), Vector2(40, py), 2, INK)
		wire(f, [Vector2(LOOM_X, py + 8), Vector2(252, py + 8)], TINNED, 1.8, 0.006, 4.0)
		G.disc(f, Vector2(252, py + 8), 4.2, 0.002, 0.011, G.mat(Color("#c9ccce"), 0.7, 0.3))
		py += 24.0
	# ---- the branch: leaves the loom at the focused key, over and down;
	# the modules that fit the key are laid along it
	var by: float = rows_y[slot0] + 27.0
	wire(f, [Vector2(LOOM_X, by), Vector2(SPINE_X, by), Vector2(SPINE_X, 690)], BRANCH,
			5.0, WIRE_Z, 24.0)
	G.sleeve(f, Vector2(LOOM_X + 14, by), false, 7.4, 18, WIRE_Z, boot)
	var count := str((ctx["candidates"] as Array).size())
	marker(f, 330 + (kit.measure("FITS %s · %s" % [cap, count], 2) + 18.0) * 0.5, by,
			"FITS %s · %s" % [cap, count])
	var ids: Array = ctx["candidates"]
	var taps := {}
	for i in ids.size():
		var id: String = ids[i]
		var y := ROW_Y0 + ROW_PITCH * i
		var looked: bool = id == ctx["inspected"]
		var on_key: bool = id == ctx["equipped"]
		if looked:
			G.block(f, Rect2(318, y - 2, 4, 36), 0.0, 0.004, G.unlit(Kit.SIGNAL))
		text(f, kit.fit(name_of(id), 2, 330), Vector2(334, y), 2,
				INK if looked or on_key else DIM)
		var tags := [mk(id)]
		if on_key:
			tags.append("ON " + cap)
		if authored(id):
			tags.append("AUTHORED")
		text(f, " · ".join(tags), Vector2(334, y + 17), 2, DIM if on_key else FAINT)
		var tap := Vector2(SPINE_X, y + 16)
		taps[id] = tap
		var band := G.mat(METAL, 0.5, 0.4)
		if on_key:
			band = G.mat(FLAG, 0.0, 1.0)
		if looked:
			band = G.unlit(Kit.SIGNAL)
		G.sleeve(f, tap, true, 7.0, 14.0 if on_key and not looked else 8.0, WIRE_Z, band, 14)
	# ---- the inspected module's breakout, on into the readout tag
	var t: Vector2 = taps[ctx["inspected"]]
	var ty := clampf(t.y, TAG.position.y + 40.0, TAG.end.y - 30.0)
	G.tube(f, G.smooth([t, t + Vector2(16, 0), Vector2(TAG.position.x - 14, ty),
			Vector2(TAG.position.x + 2, ty)], WIRE_Z + 0.006, 8), 3.4,
			G.unlit(Kit.SIGNAL), 10)
	G.block(f, Rect2(TAG.position.x - 4, ty - 6, 14, 12), TAG_Z - 0.004, TAG_Z + 0.004,
			G.mat(METAL, 0.6, 0.35))
	_readout(f)


## The readout: a tag hung from the trunk at the end of the branch. What it
## does and what changes come first; where it came from is last, quiet.
func _readout(f: Node3D) -> void:
	var id: String = ctx["inspected"]
	tag(f, TAG)
	var x := TAG.position.x + 26.0
	var w := TAG.size.x - 52.0
	var y := TAG.position.y + 36.0
	on_tag(f, kicker(id), Vector2(x, y), 2, TAG_DIM)
	y += 28.0
	var fit := name_fit(name_of(id), w, 5, 3, 3)
	for line: String in fit[1]:
		on_tag(f, line, Vector2(x, y), fit[0], FLAG_INK)
		y += 8.0 * int(fit[0]) + 6.0
	y += 6.0
	on_tag(f, "DOES", Vector2(x, y + 6), 2, TAG_FAINT)
	for line: String in does(id):
		for l in kit.wrap(line.to_upper(), 3, w - 64):
			on_tag(f, l, Vector2(x + 64, y), 3, FLAG_INK)
			y += 30.0
	for l in kit.wrap(desc(id).to_upper(), 2, w):
		on_tag(f, l, Vector2(x, y + 2), 2, TAG_DIM)
		y += 20.0
	# what changes on the key: a rule, the head, the table
	y += 14.0
	G.block(f, Rect2(x, y, w, 2), TAG_Z, TAG_Z + 0.0006, G.mat(TAG_FAINT, 0.0, 0.9), false)
	y += 12.0
	for line: String in kit.wrap(against_head(), 2, w):
		on_tag(f, line, Vector2(x, y), 2, TAG_DIM)
		y += 20.0
	y = table(f, ctx["comparison"], x, y + 6.0, w, TAG_Z + 0.0012, TAG_DIM, TAG_NEW,
			TAG_FAINT)
	y += 12.0
	for h: Array in history(id):
		on_tag(f, kit.fit("%s  %s" % [h[0], h[1]], 2, w), Vector2(x, y), 2, TAG_FAINT)
		y += 20.0
	# the action: always at the tag's foot
	var act := action(id)
	var ay := TAG.end.y - 58.0
	if act != "":
		var bw := kit.measure(act, 2) + 112.0
		G.slab(f, G.rrect(Rect2(x - 6, ay, bw, 38), 7), TAG_Z, TAG_Z + 0.006,
				G.mat(Color("#1d3a37"), 0.1, 0.6))
		keycap(f, "ENTER", Vector2(x + 4, ay + 6), TAG_Z + 0.006)
		kit.label(f, act, Vector2(x + 92, ay + 11), 2, Kit.SIGNAL, TAG_Z + 0.0072)
	if authored(id):
		on_tag(f, "AUTHORED", Vector2(TAG.end.x - 26 - kit.measure("AUTHORED", 2), ay + 11),
				2, TAG_FAINT)


# ------------------------------------------------------------ map

func _map() -> void:
	var f := face("map")
	var win := FaceMap.WINDOW
	# the board's cut-out round the instrument: a plain lip
	var lip := G.mat(Color("#101316"), 0.1, 0.8)
	for r: Rect2 in [Rect2(win.position.x - 6, win.position.y - 6, win.size.x + 12, 6),
			Rect2(win.position.x - 6, win.end.y, win.size.x + 12, 6),
			Rect2(win.position.x - 6, win.position.y, 6, win.size.y),
			Rect2(win.end.x, win.position.y, 6, win.size.y)]:
		G.block(f, r, 0.0, 0.005, lip)
	var tx: float = ctx["link_page"].x
	var title_flag := flag(f, 40, "MAP", 4, "03")
	var d := Rect2(win.end.x - 352, 124, 330, 350)
	trunk(f, [560.0, 760.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(tx - 24, tx + 24), Vector2(d.position.x + 24, d.position.x + 52),
			Vector2(d.end.x - 52, d.end.x - 24)])
	# The detail: a tag hung from the trunk over the window, MapFace's own
	# words in tag ink.
	tag(f, d)
	var lines := (ctx["detail"] as String).split("\n")
	var y := d.position.y + 34.0
	on_tag(f, lines[0], Vector2(d.position.x + 22, y), 3, FLAG_INK)
	y += 40.0
	for i in range(1, lines.size()):
		for l in kit.wrap(lines[i].to_upper(), 2, d.size.x - 44):
			on_tag(f, l, Vector2(d.position.x + 22, y), 2, TAG_DIM if i == 1 else FLAG_INK)
			y += 20.0
		y += 6.0
	on_tag(f, "MAPFACE'S OWN DETAIL", Vector2(d.position.x + 22, d.end.y - 30), 2, TAG_FAINT)
	# The Journal's link: laced above the trunk from the corner to over its
	# place, then forward over the trunk and down into the window, where the
	# menu's guide stroke carries on to the passage.
	var ivory := G.mat(IVORY, 0.05, 0.55)
	G.tube(f, G.routed([Vector2(RUN_START, LINK_Y), Vector2(tx - 20, LINK_Y)], 10, LINK_Z)
			+ G.smooth3([G.P(Vector2(tx - 6, LINK_Y + 2), LINK_Z + 0.004),
				G.P(Vector2(tx, LINK_Y + 18), 0.04), G.P(Vector2(tx, TRUNK_Y), 0.044),
				G.P(Vector2(tx, TRUNK_Y + 24), 0.036),
				G.P(Vector2(tx, win.position.y + 4), 0.018)], 6), 4.0, ivory, 12)
	var x := RUN_START + 30.0
	while x < tx - 40.0:
		tie(f, Vector2(x, LINK_Y), false, 4.0, LINK_Z)
		x += 88.0
	G.block(f, Rect2(tx - 6, win.position.y - 2, 12, 12), 0.006, 0.022,
			G.mat(METAL, 0.6, 0.35))
	guide(f, Vector2(tx, win.position.y + 10), ctx["link_page"], IVORY)


# ------------------------------------------------------------ journal

func _journal() -> void:
	var f := face("journal")
	var j: Dictionary = ctx["journal"]
	var title_flag := flag(f, 40, "JOURNAL", 4, "04")
	var lx := 46.0
	var rx := 600.0
	var up_x := 1210.0
	trunk(f, [880.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(lx - 14, lx + 14), Vector2(rx - 14, rx + 14), Vector2(up_x - 20, up_x + 20)])
	# the left run: what you are doing, and what you have found
	wire(f, [Vector2(lx, TRUNK_Y), Vector2(lx, 690)], WIRE, 3.5)
	var y := 126.0
	vflag(f, lx, y, "OBJECTIVES", 3.5)
	y += 44.0
	for s: String in j["objectives"]:
		y = para(f, s.to_upper(), Vector2(74, y), 470, 2, INK, 0.003, 20.0) + 6.0
	y += 16.0
	vflag(f, lx, y, "NOTES", 3.5)
	y += 44.0
	for n: Dictionary in j["notes"]:
		if y > 660.0:
			break
		y = para(f, ("%s -- %s" % [n["title"], n["text"]]).to_upper(), Vector2(74, y), 470,
				2, DIM, 0.003, 20.0) + 4.0
	# the right run: the findings; the focused one is tagged, and its link
	# leaves the tag for the trunk
	wire(f, [Vector2(rx, TRUNK_Y), Vector2(rx, 690)], WIRE, 3.5)
	y = 126.0
	vflag(f, rx, y, "STILL SHUT", 3.5)
	y += 46.0
	var shut: Array = j["still_shut"]
	for i in shut.size():
		var focused := i == 0
		var words := kit.wrap(str(shut[i]).to_upper(), 2, 490)
		var h := 20.0 * words.size()
		if focused:
			h += 8.0 + 20.0 * (ctx["explanation"] as Array).size()
			var r := Rect2(rx + 16, y - 12, 578, h + 24)
			tag(f, r, 0.026, false)
			G.block(f, Rect2(rx - 2, y - 4, 20, 8), 0.012, 0.024, G.mat(METAL, 0.6, 0.35))
			var yy := y
			for l in words:
				kit.label(f, l, Vector2(rx + 34, yy), 2, FLAG_INK, 0.0272)
				yy += 20.0
			yy += 8.0
			for l: String in ctx["explanation"]:
				kit.label(f, l, Vector2(rx + 50, yy), 2, TAG_DIM, 0.0272)
				yy += 20.0
		else:
			var yy := y
			for l in words:
				text(f, l, Vector2(rx + 34, yy), 2, DIM)
				yy += 20.0
		var bead: Dictionary = ctx["beads"][i]
		kit.sprite(f, bead["icon"], Vector2(rx + 560, y + 9), 2, bead["colour"],
				0.0285 if focused else 0.004)
		if focused:
			# the link: ivory, off the tag's end, up the wall and over the
			# trunk, then laced above it to the corner
			var s0 := Vector2(rx + 594, y + 9)
			G.tube(f, G.smooth3([G.P(s0, 0.024), G.P(s0 + Vector2(16, 0), 0.026),
					G.P(Vector2(up_x, y + 2), 0.03), G.P(Vector2(up_x, TRUNK_Y + 26), 0.036),
					G.P(Vector2(up_x, TRUNK_Y), 0.044), G.P(Vector2(up_x, LINK_Y + 18), 0.04),
					G.P(Vector2(up_x + 10, LINK_Y + 1), LINK_Z + 0.004)], 6)
					+ [G.P(Vector2(RUN_END, LINK_Y), LINK_Z)], 4.0,
					G.mat(IVORY, 0.05, 0.55), 12)
		y += h + 20.0
	y += 6.0
	vflag(f, rx, y, "WHAT YOU DID HERE", 3.5)
	y += 44.0
	for s: String in j["done_here"]:
		y = para(f, s.to_upper(), Vector2(rx + 34, y), 540, 2, DIM, 0.003, 20.0) + 4.0
	y += 12.0
	vflag(f, rx, y, "PLACES FOUND", 3.5)
	y += 44.0
	for s: String in j["places"]:
		text(f, s.to_upper(), Vector2(rx + 34, y), 2, DIM)
		y += 22.0


# ------------------------------------------------------------ settings

func _settings() -> void:
	var f := face("settings")
	var s: Dictionary = ctx["settings"]
	var title_flag := flag(f, 40, "SETTINGS", 4, "01")
	var lx := 46.0
	var ox := 440.0
	trunk(f, [980.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(lx - 14, lx + 14), Vector2(ox - 14, ox + 14)])
	# PAUSED: the device's front buttons, on their own run. RESUME is the
	# big one.
	wire(f, [Vector2(lx, TRUNK_Y), Vector2(lx, 690)], WIRE, 3.5)
	var y := 126.0
	vflag(f, lx, y, "PAUSED", 3.5)
	y += 46.0
	for i in (s["paused"] as Array).size():
		var label: String = s["paused"][i]
		var h := 56.0 if i == 0 else 40.0
		var r := Rect2(74, y, 300, h)
		if i == 0:
			G.slab(f, G.rrect(r, 8), 0.0, 0.014, G.mat(Color("#1d3a37"), 0.1, 0.6))
			kit.label(f, label, Vector2(94, y + 16), 3, Kit.SIGNAL, 0.0152)
		else:
			tag(f, r, 0.012, false)
			kit.label(f, label, Vector2(94, y + 12), 2, FLAG_INK, 0.0132)
		wire(f, [Vector2(lx, y + h * 0.5), Vector2(74, y + h * 0.5)], WIRE, 2.4, 0.008, 4.0)
		y += h + 12.0
	y += 18.0
	vflag(f, lx, y, "CAMPAIGN", 3.5)
	y += 44.0
	for line: String in s["campaign"]:
		text(f, kit.fit(line.to_upper(), 2, 320), Vector2(74, y), 2, DIM)
		y += 22.0
	# OPTIONS: along their own run; a slider is a sleeve on a taut wire, at
	# its real default; the toggle a slide switch, at its real state.
	wire(f, [Vector2(ox, TRUNK_Y), Vector2(ox, 560)], WIRE, 3.5)
	y = 126.0
	vflag(f, ox, y, "OPTIONS", 3.5)
	y += 54.0
	var x0 := 470.0
	var x1 := 1226.0
	for sl: Array in s["sliders"]:
		text(f, str(sl[0]), Vector2(x0, y), 2, INK)
		text(f, str(sl[2]), Vector2(x1 - kit.measure(str(sl[2]), 2), y), 2, DIM)
		var wy := y + 36.0
		var kx := lerpf(x0 + 12.0, x1 - 12.0, float(sl[1]))
		for e: float in [x0, x1]:
			G.disc(f, Vector2(e, wy), 5.0, 0.0, 0.012, G.mat(METAL, 0.6, 0.35), 14)
		wire(f, [Vector2(x0, wy), Vector2(kx, wy)], BRANCH, 2.2, 0.008, 4.0)
		if kx < x1 - 1.0:
			wire(f, [Vector2(kx, wy), Vector2(x1, wy)], WIRE, 2.2, 0.008, 4.0)
		G.sleeve(f, Vector2(kx, wy), false, 9.0, 24.0, 0.008, G.mat(METAL, 0.55, 0.35), 18)
		wire(f, [Vector2(ox, y + 8), Vector2(x0 - 14, y + 8)], WIRE, 2.0, 0.008, 4.0)
		y += 76.0
	for t: Array in s["toggles"]:
		text(f, str(t[0]), Vector2(x0, y), 2, INK)
		var on := bool(t[1])
		text(f, "ON" if on else "OFF", Vector2(x1 - kit.measure("OFF", 2), y), 2, DIM)
		var slot := Rect2(x1 - 130, y - 4, 60, 24)
		G.slab(f, G.rrect(slot, 11), 0.0, 0.006, G.mat(Color("#0c0e10"), 0.0, 0.9))
		G.slab(f, G.rrect(Rect2(slot.position.x + (32.0 if on else 3.0), y - 1, 25, 18), 7),
				0.006, 0.018, G.mat(METAL, 0.55, 0.35))
		wire(f, [Vector2(ox, y + 8), Vector2(x0 - 14, y + 8)], WIRE, 2.0, 0.008, 4.0)
		y += 60.0
