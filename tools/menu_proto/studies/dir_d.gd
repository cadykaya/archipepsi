extends StudyDir
## DIRECTION D — SALVAGED ECHO WORKBENCH / PROTOTYPE BOARD.
##
## The organizing idea: an evolving device Epsilon built from compatible
## pieces and kept improving. Each wall is an ASSEMBLY of boards -- joined
## sections, a later add-on bridged onto the main board, modules that plug
## in -- mounted on standoffs, overlapping. The character is in the large
## shapes: irregular outlines and layers, not a wallpaper of parts.
##
## * Equipment: the main board carries a header for each key, with the
##   module on it seated there. The inspected module is LIFTED over the
##   board -- out of the spares tray, its connector edge towards the key it
##   would go on, and the place it would take outlined: you inspect a module
##   and see where it belongs. What it does and what changes are printed on
##   it. The tray keeps a slot for every module that fits the key; the two
##   that are out (on the key, and in your hand) leave their slots empty.
## * Journal -> Map: a ribbon cable, board to board, round the corner.
## * Map and Journal stay instruments of the same assembly -- boards, not
##   paper; Settings is the board's trim: slide pots and a DIP switch, at
##   their real values.
##
## Nothing here is a chore: moving the selection lifts the next module, and
## ENTER is the preview (labelled, local, not sent).

const BENCH := Color("#1c1d1a")
const MASK := Color("#243d2e")          # the main board's solder mask
const MASK_ADD := Color("#6f5433")      # the add-on: bare phenolic
const MASK_TRAY := Color("#2a3432")
const MODULE := Color("#171a19")        # a module's black mask
const EDGE := Color("#8f8a63")          # FR4 at a board's cut edge
const GOLD := Color("#c8a24c")
const TIN := Color("#b9bec2")
const HEADER := Color("#121314")
const SILK := Color("#e8ebe4")
const SILK_DIM := Color("#a7b4a9")
const SILK_FAINT := Color("#74857a")
const ADD_INK := Color("#efe6d2")
const BRASS := Color("#b39150")
const RIBBON := Color("#8d9196")

const BOARD_Z := 0.014                  # a board's face, off the wall
const LIFT_Z := 0.07                    # the inspected module's face
const KEY_Y0 := 100.0
const KEY_PITCH := 84.0
const DB := Rect2(344, 82, 552, 560)    # the lifted module
const TRAY := Rect2(924, 60, 330, 640)
const LINK_Y := 42.0                    # the ribbon's middle, round the corner


func title() -> String:
	return "SALVAGED ECHO WORKBENCH / PROTOTYPE BOARD"


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
	var grey := G.mat(RIBBON, 0.1, 0.6)
	for k in 6:
		corner("journal", LINK_Y + (float(k) - 2.5) * 3.4, 1.7, grey, 0.02)


func _wall() -> Material:
	var m: StandardMaterial3D = kit.wall_material().duplicate()
	m.albedo_color = BENCH
	return m


# ------------------------------------------------------------ the pieces

## A board: its mask, its cut edge showing FR4 round the rim, on brass
## standoffs at `posts`.
func board(f: Node3D, poly: PackedVector2Array, colour: Color, z := BOARD_Z,
		posts: Array = []) -> void:
	G.slab(f, poly, z - 0.004, z - 0.0008, G.mat(toned(EDGE, f), 0.1, 0.7))
	G.slab(f, _inset(poly, 2.5), z - 0.0008, z, G.mat(toned(colour, f), 0.15, 0.6))
	for p: Vector2 in posts:
		G.disc(f, p, 7.0, 0.0, z - 0.004, G.mat(BRASS, 0.6, 0.35), 6)
		G.disc(f, p, 5.2, z, z + 0.004, G.mat(TIN, 0.6, 0.35), 16)
		G.disc(f, p, 2.2, z + 0.004, z + 0.0046, G.unlit(Color("#0b0c0c")), 10, false)


## A polygon pulled in a little towards its centre (the mask inside the
## board's cut edge).
func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(poly, -d)
	return grown[0] if not grown.is_empty() else poly


func silk(f: Node3D, s: String, at: Vector2, k: int, colour: Color, z := BOARD_Z) -> void:
	kit.label(f, s, at, k, colour, z + 0.0008)


## A dashed outline in silkscreen: a footprint -- where a module seats.
func footprint(f: Node3D, r: Rect2, colour: Color, z := BOARD_Z) -> void:
	var m := G.unlit(colour)
	var dash := 10.0
	var x := r.position.x
	while x < r.end.x - 2.0:
		var w := minf(dash, r.end.x - x)
		G.block(f, Rect2(x, r.position.y, w, 2), z, z + 0.0006, m, false)
		G.block(f, Rect2(x, r.end.y - 2, w, 2), z, z + 0.0006, m, false)
		x += dash * 1.7
	var y := r.position.y
	while y < r.end.y - 2.0:
		var h := minf(dash, r.end.y - y)
		G.block(f, Rect2(r.position.x, y, 2, h), z, z + 0.0006, m, false)
		G.block(f, Rect2(r.end.x - 2, y, 2, h), z, z + 0.0006, m, false)
		y += dash * 1.7


## A wire bridge across a seam: tinned wire, a solder joint at each end.
func bridge(f: Node3D, a: Vector2, b: Vector2, z := BOARD_Z) -> void:
	var mid := (a + b) * 0.5
	G.tube(f, [G.P(a, z + 0.001), G.P(mid, z + 0.006), G.P(b, z + 0.001)], 1.6,
			G.mat(TIN, 0.6, 0.35), 8)
	for p: Vector2 in [a, b]:
		G.disc(f, p, 4.0, z, z + 0.0028, G.mat(TIN, 0.6, 0.35), 12)


## A header socket strip: black plastic, a row of holes.
func header(f: Node3D, r: Rect2, z := BOARD_Z) -> void:
	G.block(f, r, z, z + 0.01, G.mat(HEADER, 0.1, 0.5))
	var x := r.position.x + 7.0
	while x < r.end.x - 4.0:
		G.block(f, Rect2(x - 1.5, r.get_center().y - 1.5, 3, 3), z + 0.01, z + 0.0104,
				G.unlit(Color("#050505")), false)
		x += 9.0


# ------------------------------------------------------------ equipment

func _equipment() -> void:
	var f := face("equipment")
	var slot0: String = ctx["slot"]
	var cap := cap_of(slot0)
	var id: String = ctx["inspected"]
	# ---- the main board: an L of two joined sections, and the add-on
	var main := PackedVector2Array([Vector2(24, 52), Vector2(612, 52), Vector2(648, 88),
		Vector2(648, 330), Vector2(706, 330), Vector2(706, 548), Vector2(660, 580),
		Vector2(24, 580)])
	board(f, main, MASK, BOARD_Z, [Vector2(40, 68), Vector2(596, 68), Vector2(690, 530),
			Vector2(40, 564)])
	silk(f, "EQUIPMENT", Vector2(60, 60), 4, SILK)
	silk(f, "02", Vector2(60 + kit.measure("EQUIPMENT", 4) + 18, 60), 4, SILK_FAINT)
	var add := PackedVector2Array([Vector2(30, 596), Vector2(446, 596), Vector2(472, 622),
		Vector2(472, 700), Vector2(30, 700)])
	board(f, add, MASK_ADD, BOARD_Z, [Vector2(46, 684), Vector2(456, 684)])
	for x: float in [120.0, 250.0, 380.0]:
		bridge(f, Vector2(x, 570), Vector2(x, 608))
	# ---- the keys: a header each; the module on it seated there
	var keys: Array = ctx["keys"]
	var seat := {}
	for i in keys.size():
		var k: Dictionary = keys[i]
		var slot := str(k["slot"])
		var y := KEY_Y0 + KEY_PITCH * i
		var here := slot == slot0
		var w := keycap(f, str(k["keycap"]), Vector2(52, y), BOARD_Z)
		silk(f, str(k["title"]), Vector2(52 + w + 10, y + 6), 2, SILK if here else SILK_DIM)
		var hr := Rect2(52, y + 36, 250, 14)
		header(f, hr)
		var on := seated(slot)
		var mr := Rect2(52, y + 32, 250, 40)
		seat[slot] = mr
		if on == "":
			silk(f, "EMPTY", Vector2(60, y + 56), 2, SILK_FAINT, BOARD_Z + 0.01)
			continue
		# the module seated on it: a small black board on the header
		var mz := BOARD_Z + 0.024
		G.slab(f, G.rrect(mr, 3), mz - 0.003, mz, G.mat(MODULE, 0.15, 0.55))
		kit.label(f, kit.fit(name_of(on), 2, 196), mr.position + Vector2(10, 12), 2,
				SILK if here else SILK_DIM, mz + 0.0008)
		if charges(on) != "":
			kit.label(f, charges(on), Vector2(mr.end.x - 10 - kit.measure(charges(on), 2),
					mr.position.y + 12), 2, SILK_DIM, mz + 0.0008)
		if here:
			G.block(f, Rect2(36, y - 4, 4, 78), BOARD_Z, BOARD_Z + 0.001, G.unlit(SILK), false)
	# where the lifted module would seat: the key's place, outlined
	var place: Rect2 = seat[slot0]
	footprint(f, place.grow(7), Kit.SIGNAL, BOARD_Z + 0.027)
	# ---- ALWAYS ON: soldered into the add-on; no header, no key
	silk(f, "ALWAYS ON · NO KEY", Vector2(52, 614), 2, ADD_INK)
	var py := 640.0
	var px := 52.0
	for p: String in ctx["passives"]:
		var nm := name_of(p)
		G.disc(f, Vector2(px + 5, py + 8), 4.0, BOARD_Z, BOARD_Z + 0.003, G.mat(TIN, 0.6, 0.35),
				12)
		silk(f, nm, Vector2(px + 16, py), 2, ADD_INK)
		px += kit.measure(nm, 2) + 40.0
		var next: int = (ctx["passives"] as Array).find(p) + 1
		if next < (ctx["passives"] as Array).size() and px + 16.0 + kit.measure(name_of(
				ctx["passives"][next]), 2) > 330.0:
			px = 52.0
			py += 24.0
	# ---- the spares tray, and the lifted module
	_tray(f, cap)
	_module(f, id, place)


## The spares tray: a slot for each module that fits the key, shingled; the
## ones that are out leave their slot empty, and say where they are.
func _tray(f: Node3D, cap: String) -> void:
	var outline := PackedVector2Array([TRAY.position, Vector2(TRAY.end.x - 30,
			TRAY.position.y), Vector2(TRAY.end.x, TRAY.position.y + 30), TRAY.end,
			Vector2(TRAY.position.x + 20, TRAY.end.y), Vector2(TRAY.position.x, TRAY.end.y - 20)])
	board(f, outline, MASK_TRAY, 0.01, [Vector2(TRAY.position.x + 14, TRAY.position.y + 14),
			Vector2(TRAY.end.x - 14, TRAY.end.y - 14)])
	var ids: Array = ctx["candidates"]
	silk(f, "FITS %s · %d" % [cap, ids.size()], Vector2(TRAY.position.x + 34, TRAY.position.y
			+ 12), 2, SILK_DIM, 0.01)
	var pitch := 44.0
	for i in ids.size():
		var mid: String = ids[i]
		var y := TRAY.position.y + 40.0 + pitch * i
		var r := Rect2(TRAY.position.x + 14, y, TRAY.size.x - 28, pitch + 8)
		var z := 0.012 + 0.0012 * i
		var out_key: bool = mid == ctx["equipped"]
		var out_hand: bool = mid == ctx["inspected"]
		if out_key or out_hand:
			# its slot: empty, the place still labelled
			footprint(f, Rect2(r.position.x, r.position.y, r.size.x, pitch - 4),
					Kit.SIGNAL if out_hand else SILK_FAINT, 0.012)
			silk(f, kit.fit(name_of(mid), 2, r.size.x - 28), r.position + Vector2(14, 11), 2,
					SILK if out_hand else SILK_DIM, 0.012)
			var tags := [mk(mid), "ON " + cap if out_key else "LIFTED, BEING READ"]
			silk(f, " · ".join(tags), r.position + Vector2(14, 28), 2,
					Kit.SIGNAL if out_hand else SILK_DIM, 0.012)
			continue
		G.slab(f, G.rrect(r, 3), z - 0.0024, z, G.mat(MODULE.lightened(0.04 * (i % 2)), 0.15,
				0.55))
		kit.label(f, kit.fit(name_of(mid), 2, r.size.x - 28), r.position + Vector2(14, 5), 2,
				SILK_DIM, z + 0.0008)
		var tags := [mk(mid)]
		if authored(mid):
			tags.append("AUTHORED")
		kit.label(f, " · ".join(tags), r.position + Vector2(14, 23), 2, SILK_FAINT, z + 0.0008)


## The inspected module, lifted out over the main board: black, its gold
## connector edge towards the key's place. What it does and what changes
## are printed on it; where it came from, small, at its foot.
func _module(f: Node3D, id: String, place: Rect2) -> void:
	var z := LIFT_Z
	var fy := place.get_center().y
	var poly := PackedVector2Array([Vector2(DB.position.x, fy - 34),
		Vector2(DB.position.x + 18, fy - 34), Vector2(DB.position.x + 18, DB.position.y),
		Vector2(DB.end.x - 60, DB.position.y), Vector2(DB.end.x, DB.position.y + 60),
		Vector2(DB.end.x, DB.end.y), Vector2(DB.position.x + 40, DB.end.y),
		Vector2(DB.position.x + 18, DB.end.y - 22), Vector2(DB.position.x + 18, fy + 34),
		Vector2(DB.position.x, fy + 34)])
	board(f, poly, MODULE, z)
	# its connector edge: gold fingers, facing the key's place
	for k in 6:
		G.block(f, Rect2(DB.position.x + 2, fy - 29 + 10.0 * k, 14, 6), z, z + 0.0006,
				G.mat(GOLD, 0.8, 0.3), false)
	# its standoffs' holes and two test points, as a module has
	for p: Vector2 in [Vector2(DB.end.x - 20, DB.position.y + 84), Vector2(DB.end.x - 20,
			DB.position.y + 104)]:
		G.ring(f, p, 4.0, 7.0, z + 0.0004, G.mat(TIN, 0.6, 0.35))
	var x := DB.position.x + 40.0
	var w := DB.size.x - 70.0
	var y := DB.position.y + 22.0
	silk(f, kicker(id), Vector2(x, y), 2, SILK_DIM, z)
	y += 30.0
	var fit := name_fit(name_of(id), w, 5, 3, 3)
	for line: String in fit[1]:
		silk(f, line, Vector2(x, y), fit[0], SILK, z)
		y += 8.0 * int(fit[0]) + 6.0
	y += 6.0
	silk(f, "DOES", Vector2(x, y + 6), 2, SILK_FAINT, z)
	for line: String in does(id):
		for l in kit.wrap(line.to_upper(), 3, w - 64):
			silk(f, l, Vector2(x + 64, y), 3, SILK, z)
			y += 30.0
	for l in kit.wrap(desc(id).to_upper(), 2, w):
		silk(f, l, Vector2(x, y + 2), 2, SILK_DIM, z)
		y += 20.0
	# what changes on the key: a silkscreened box
	y += 14.0
	var lines: Array = ctx["comparison"]
	var head := kit.wrap(against_head(), 2, w - 24)
	var bh := 14.0 + 20.0 * head.size() + 8.0 + table_height(lines, w - 24) + 10.0
	var box := Rect2(x - 10, y, w + 20, bh)
	for b: Rect2 in [Rect2(box.position.x, box.position.y, box.size.x, 2),
			Rect2(box.position.x, box.end.y - 2, box.size.x, 2),
			Rect2(box.position.x, box.position.y, 2, box.size.y),
			Rect2(box.end.x - 2, box.position.y, 2, box.size.y)]:
		G.block(f, b, z, z + 0.0005, G.unlit(SILK_FAINT), false)
	var hy := y + 12.0
	for line: String in head:
		silk(f, line, Vector2(x + 2, hy), 2, SILK_DIM, z)
		hy += 20.0
	table(f, lines, x + 2, hy + 6.0, w - 24, z + 0.0008, SILK_DIM, SILK, SILK_FAINT)
	y = box.end.y + 12.0
	for h: Array in history(id):
		silk(f, kit.fit("%s  %s" % [h[0], h[1]], 2, w), Vector2(x, y), 2, SILK_FAINT, z)
		y += 20.0
	# the preview: a tact switch and its words, at the module's foot
	var act := action(id)
	var ay := DB.end.y - 56.0
	if act != "":
		var bw := kit.measure(act, 2) + 110.0
		G.slab(f, G.rrect(Rect2(x - 6, ay, bw, 38), 6), z, z + 0.008,
				G.mat(Color("#1d3a37"), 0.1, 0.6))
		keycap(f, "ENTER", Vector2(x + 4, ay + 6), z + 0.008)
		kit.label(f, act, Vector2(x + 92, ay + 11), 2, Kit.SIGNAL, z + 0.0092)
	if authored(id):
		silk(f, "AUTHORED", Vector2(DB.end.x - 30 - kit.measure("AUTHORED", 2), ay + 11), 2,
				SILK_FAINT, z)


# ------------------------------------------------------------ map

func _map() -> void:
	var f := face("map")
	var win := FaceMap.WINDOW
	# the display board: a frame of board round the window, joined at a seam
	# that is bridged
	var m := G.mat(toned(MASK, f), 0.15, 0.6)
	var edge := G.mat(toned(EDGE, f), 0.1, 0.7)
	for b: Rect2 in [Rect2(win.position.x - 16, win.position.y - 40, win.size.x + 32, 40),
			Rect2(win.position.x - 16, win.end.y, win.size.x + 32, 16),
			Rect2(win.position.x - 16, win.position.y, 16, win.size.y),
			Rect2(win.end.x, win.position.y, 16, win.size.y)]:
		G.block(f, b, BOARD_Z - 0.004, BOARD_Z - 0.0008, edge)
		G.block(f, b.grow(-1.5), BOARD_Z - 0.0008, BOARD_Z, m)
	silk(f, "MAP", Vector2(60, 58), 4, SILK)
	silk(f, "03", Vector2(60 + kit.measure("MAP", 4) + 18, 58), 4, SILK_FAINT)
	for x: float in [700.0, 712.0]:
		bridge(f, Vector2(x, 56), Vector2(x, 76))
	# the detail: a module lifted over the window, MapFace's own words
	var d := Rect2(win.end.x - 344, win.position.y + 20, 324, 344)
	var dz := 0.05
	board(f, PackedVector2Array([d.position, Vector2(d.end.x - 40, d.position.y),
			Vector2(d.end.x, d.position.y + 40), d.end, Vector2(d.position.x, d.end.y)]), MODULE,
			dz)
	var lines := (ctx["detail"] as String).split("\n")
	var y := d.position.y + 24.0
	silk(f, lines[0], Vector2(d.position.x + 20, y), 3, SILK, dz)
	y += 40.0
	for i in range(1, lines.size()):
		for l in kit.wrap(lines[i].to_upper(), 2, d.size.x - 40):
			silk(f, l, Vector2(d.position.x + 20, y), 2, SILK_DIM if i == 1 else SILK, dz)
			y += 20.0
		y += 6.0
	silk(f, "MAPFACE'S OWN DETAIL", Vector2(d.position.x + 20, d.end.y - 30), 2, SILK_FAINT,
			dz)
	# the Journal's ribbon: round the corner along the board's top, down to
	# a connector over its place; the menu's guide stroke carries on
	var tx: float = ctx["link_page"].x
	var grey := G.mat(RIBBON, 0.1, 0.6)
	for k in 6:
		var o := (float(k) - 2.5) * 3.4
		G.tube(f, G.routed([Vector2(RUN_START, LINK_Y + o), Vector2(tx + o, LINK_Y + o),
				Vector2(tx + o, win.position.y - 12)], 14, 0.02), 1.7, grey, 8)
	G.block(f, Rect2(tx - 16, win.position.y - 18, 32, 14), BOARD_Z, BOARD_Z + 0.014,
			G.mat(HEADER, 0.1, 0.5))
	guide(f, Vector2(tx, win.position.y + 6), ctx["link_page"], SILK)


# ------------------------------------------------------------ journal

func _journal() -> void:
	var f := face("journal")
	var j: Dictionary = ctx["journal"]
	# two boards, joined: the log, and the findings
	var left := PackedVector2Array([Vector2(24, 52), Vector2(560, 52), Vector2(560, 640),
		Vector2(520, 680), Vector2(24, 680)])
	board(f, left, MASK, BOARD_Z, [Vector2(40, 68), Vector2(40, 664)])
	var right := PackedVector2Array([Vector2(590, 90), Vector2(1256, 90), Vector2(1256, 700),
		Vector2(640, 700), Vector2(590, 650)])
	board(f, right, MASK, BOARD_Z, [Vector2(1240, 106), Vector2(1240, 684)])
	for y0: float in [200.0, 420.0]:
		bridge(f, Vector2(548, y0), Vector2(604, y0))
	silk(f, "JOURNAL", Vector2(60, 60), 4, SILK)
	silk(f, "04", Vector2(60 + kit.measure("JOURNAL", 4) + 18, 60), 4, SILK_FAINT)
	var y := 120.0
	silk(f, "OBJECTIVES", Vector2(56, y), 2, SILK_FAINT)
	y += 26.0
	for s: String in j["objectives"]:
		for l in kit.wrap(s.to_upper(), 2, 470):
			silk(f, l, Vector2(56, y), 2, SILK)
			y += 20.0
		y += 4.0
	y += 16.0
	silk(f, "NOTES", Vector2(56, y), 2, SILK_FAINT)
	y += 26.0
	for n: Dictionary in j["notes"]:
		if y > 650.0:
			break
		for l in kit.wrap(("%s -- %s" % [n["title"], n["text"]]).to_upper(), 2, 470):
			silk(f, l, Vector2(56, y), 2, SILK_DIM)
			y += 20.0
		y += 2.0
	# the findings: each shut way a module; the focused one lifted, the
	# ribbon plugged into it
	var x := 620.0
	y = 110.0
	silk(f, "STILL SHUT", Vector2(x, y), 2, SILK_FAINT)
	y += 44.0
	var shut: Array = j["still_shut"]
	for i in shut.size():
		var focused := i == 0
		var words := kit.wrap(str(shut[i]).to_upper(), 2, 500)
		var h := 20.0 * words.size()
		if focused:
			h += 8.0 + 20.0 * (ctx["explanation"] as Array).size()
		var z := 0.04 if focused else BOARD_Z + 0.012
		var r := Rect2(x - 8, y - 10, 606, h + 20)
		G.slab(f, G.rrect(r, 3), z - 0.003, z, G.mat(MODULE, 0.15, 0.55))
		var yy := y
		for l in words:
			kit.label(f, l, Vector2(x + 8, yy), 2, SILK if focused else SILK_DIM, z + 0.0008)
			yy += 20.0
		if focused:
			yy += 8.0
			for l: String in ctx["explanation"]:
				kit.label(f, l, Vector2(x + 24, yy), 2, SILK_DIM, z + 0.0008)
				yy += 20.0
		var bead: Dictionary = ctx["beads"][i]
		kit.sprite(f, bead["icon"], Vector2(x + 574, y + 9), 2, bead["colour"], z + 0.0015)
		if focused:
			# the ribbon's connector on the lifted module, and the ribbon up
			# over the board's top to the corner
			var cx := 1200.0
			G.block(f, Rect2(cx - 16, r.position.y - 12, 32, 14), z, z + 0.012,
					G.mat(HEADER, 0.1, 0.5))
			var grey := G.mat(RIBBON, 0.1, 0.6)
			for k in 6:
				var o := (float(k) - 2.5) * 3.4
				G.tube(f, [G.P(Vector2(cx + o, r.position.y - 8), z + 0.006)] + G.routed([
						Vector2(cx + o, r.position.y - 30), Vector2(cx + o, LINK_Y + 20 + o),
						Vector2(cx + o + 12, LINK_Y + o), Vector2(RUN_END, LINK_Y + o)], 10,
						0.02), 1.7, grey, 8)
		y += h + 26.0
	y += 4.0
	silk(f, "WHAT YOU DID HERE", Vector2(x, y), 2, SILK_FAINT)
	y += 26.0
	for s: String in j["done_here"]:
		silk(f, s.to_upper(), Vector2(x, y), 2, SILK_DIM)
		y += 20.0
	y += 16.0
	silk(f, "PLACES FOUND", Vector2(x, y), 2, SILK_FAINT)
	y += 26.0
	for s: String in j["places"]:
		silk(f, s.to_upper(), Vector2(x, y), 2, SILK_DIM)
		y += 22.0


# ------------------------------------------------------------ settings

func _settings() -> void:
	var f := face("settings")
	var s: Dictionary = ctx["settings"]
	var main := PackedVector2Array([Vector2(24, 52), Vector2(1256, 52), Vector2(1256, 520),
		Vector2(1216, 560), Vector2(400, 560), Vector2(400, 700), Vector2(24, 700)])
	board(f, main, MASK, BOARD_Z, [Vector2(40, 68), Vector2(1240, 68), Vector2(40, 684),
			Vector2(1200, 544)])
	silk(f, "SETTINGS", Vector2(60, 60), 4, SILK)
	silk(f, "01", Vector2(60 + kit.measure("SETTINGS", 4) + 18, 60), 4, SILK_FAINT)
	# PAUSED: tact switches; RESUME the big one
	var y := 120.0
	silk(f, "PAUSED", Vector2(56, y), 2, SILK_FAINT)
	y += 30.0
	for i in (s["paused"] as Array).size():
		var label: String = s["paused"][i]
		var sz := 40.0 if i == 0 else 28.0
		var c := Vector2(56 + sz * 0.5, y + sz * 0.5)
		G.block(f, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), BOARD_Z, BOARD_Z + 0.008,
				G.mat(Color("#2e3032"), 0.5, 0.4))
		G.disc(f, c, sz * 0.32, BOARD_Z + 0.008, BOARD_Z + 0.018, G.unlit(Kit.SIGNAL) if i == 0
				else G.mat(HEADER, 0.1, 0.5), 20)
		silk(f, label, Vector2(56 + sz + 16, c.y - (12 if i == 0 else 8)), 3 if i == 0 else 2,
				Kit.SIGNAL if i == 0 else SILK)
		y += sz + 18.0
	# CAMPAIGN: printed on the board
	y += 20.0
	silk(f, "CAMPAIGN", Vector2(56, y), 2, SILK_FAINT)
	y += 26.0
	for line: String in s["campaign"]:
		silk(f, kit.fit(line.to_upper(), 2, 320), Vector2(56, y), 2, SILK_DIM)
		y += 22.0
	# OPTIONS: slide pots at their real positions; a DIP switch at its real
	# state
	var x0 := 440.0
	var x1 := 1216.0
	y = 120.0
	silk(f, "OPTIONS", Vector2(x0, y), 2, SILK_FAINT)
	y += 40.0
	for sl: Array in s["sliders"]:
		silk(f, str(sl[0]), Vector2(x0, y), 2, SILK)
		silk(f, str(sl[2]), Vector2(x1 - kit.measure(str(sl[2]), 2), y), 2, SILK_DIM)
		var track := Rect2(x0, y + 30, x1 - x0, 12)
		G.block(f, track, BOARD_Z, BOARD_Z + 0.008, G.mat(Color("#2e3032"), 0.5, 0.4))
		G.block(f, Rect2(track.position.x + 8, track.get_center().y - 1.5, track.size.x - 16, 3),
				BOARD_Z + 0.008, BOARD_Z + 0.0084, G.unlit(Color("#060606")), false)
		var kx := lerpf(track.position.x + 14, track.end.x - 14, float(sl[1]))
		G.block(f, Rect2(kx - 12, y + 24, 24, 24), BOARD_Z + 0.008, BOARD_Z + 0.026,
				G.mat(Color("#d9dcd8"), 0.2, 0.5))
		y += 78.0
	for t: Array in s["toggles"]:
		silk(f, str(t[0]), Vector2(x0, y), 2, SILK)
		var on := bool(t[1])
		silk(f, "ON" if on else "OFF", Vector2(x1 - kit.measure("OFF", 2), y), 2, SILK_DIM)
		var dip := Rect2(x1 - 140, y - 6, 60, 30)
		G.block(f, dip, BOARD_Z, BOARD_Z + 0.008, G.mat(Color("#2e3032"), 0.1, 0.5))
		G.block(f, Rect2(dip.position.x + 8, dip.position.y + (18.0 if not on else 4.0), 44, 8),
				BOARD_Z + 0.008, BOARD_Z + 0.014, G.mat(Color("#e6e6e2"), 0.1, 0.5))
		y += 60.0
