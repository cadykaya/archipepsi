extends StudyDir
## DIRECTION C — RELAY CABINET / BREAKER LOGIC.
##
## The organizing idea: a device whose REAL states read at a glance. Each wall
## is the front of one steel cabinet: a big inspection window across the top,
## the mechanism below it, a brass bus between them. Every physical state
## shown is interface data, and nothing else:
##
## * the key selector's pointer is the focused key;
## * each key's flag window is what that key holds (or EMPTY), and charges;
## * the rack holds what fits the key. The card ON the key is SEATED and
##   strapped to the bus the selector is on; the card being looked at is
##   PULLED, and the window above reads it -- assigned versus inspected is
##   seated versus pulled;
## * no power, faults, locks or progress are shown that the menu does not
##   have. ALWAYS ON is a plate with no switch, because there is none.
##
## Nothing here is a chore: moving the selection pulls the next card, and
## ENTER is the preview (labelled, local, not sent).

const CAB := Color("#2b2e31")
const CAB_HI := Color("#373b3f")
const RECESS := Color("#0c0e0f")
const ENAMEL := Color("#bdb7a5")
const ENAMEL_INK := Color("#1d1e20")
const BRASS := Color("#b08f52")
const BAKELITE := Color("#1a1512")
const CARD_FACE := Color("#3d4441")
const PCB := Color("#2c4a3a")
const LIT := Color("#f1ebdb")
const LIT_DIM := Color("#aaa495")
const LIT_FAINT := Color("#7b766b")
const INK := Color("#e0e3e4")
const DIM := Color("#9da3a8")
const FAINT := Color("#6f757a")

const WIN := Rect2(40, 66, 1200, 272)
const BUS_Y := 356.0
const KNOB := Vector2(122, 538)
const ARC_R := 152.0
const KEY_PITCH := 64.0
const RACK := Rect2(600, 372, 640, 326)
const CARD_PITCH := 33.0
const SHOWN := 9
const LINK_Y := 70.0            # the Journal's rod, round the corner


func title() -> String:
	return "RELAY CABINET / BREAKER LOGIC"


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
	corner("journal", LINK_Y, 5.0, G.mat(BRASS, 0.7, 0.35), 0.024)


func _wall() -> Material:
	var m: StandardMaterial3D = kit.wall_material().duplicate()
	m.albedo_color = CAB
	return m


# ------------------------------------------------------------ the pieces

## An enamel name plate, riveted at its ends: the wall's title.
func nameplate(f: Node3D, x: float, words: String, number: String) -> Rect2:
	var w := kit.measure(words, 4) + kit.measure(number, 4) + 70.0
	var r := Rect2(x, 12, w, 46)
	G.slab(f, G.rrect(r, 4), 0.0, 0.006, G.mat(toned(ENAMEL, f), 0.1, 0.6))
	kit.label(f, words, Vector2(x + 24, 19), 4, ENAMEL_INK, 0.0072)
	kit.label(f, number, Vector2(r.end.x - 20 - kit.measure(number, 4), 19), 4,
			Color("#6d6a62"), 0.0072)
	for rx: float in [x + 10, r.end.x - 10]:
		rivet(f, Vector2(rx, 35), 0.006)
	return r


func rivet(f: Node3D, at: Vector2, z: float) -> void:
	G.disc(f, at, 3.4, z, z + 0.003, G.mat(Color("#8c9094"), 0.6, 0.4), 12)


## A window cut into the cabinet: a raised frame round a dark recess. The
## frame's inner edges cast their shadows in, so it reads as cut, not drawn.
func window(f: Node3D, r: Rect2, frame := 12.0, depth := 0.014) -> void:
	var m := G.mat(CAB_HI, 0.35, 0.5)
	for b: Rect2 in [Rect2(r.position.x - frame, r.position.y - frame, r.size.x + frame * 2,
				frame), Rect2(r.position.x - frame, r.end.y, r.size.x + frame * 2, frame),
			Rect2(r.position.x - frame, r.position.y, frame, r.size.y),
			Rect2(r.end.x, r.position.y, frame, r.size.y)]:
		G.block(f, b, 0.0, depth, m)
	G.block(f, r, 0.0, 0.0008, G.mat(RECESS, 0.0, 0.95), false)
	for p: Vector2 in [r.position + Vector2(-frame * 0.5, -frame * 0.5),
			Vector2(r.end.x + frame * 0.5, r.position.y - frame * 0.5),
			Vector2(r.position.x - frame * 0.5, r.end.y + frame * 0.5), r.end + Vector2(frame,
				frame) * 0.5]:
		rivet(f, p, depth)


## A flag window: a small backlit slot whose word IS the state.
func flag_window(f: Node3D, r: Rect2, words: String, colour: Color, z := 0.004) -> void:
	G.block(f, r.grow(3.0), 0.0, z, G.mat(CAB_HI, 0.35, 0.5))
	G.block(f, r, z, z + 0.0006, G.mat(RECESS, 0.0, 0.95), false)
	kit.label(f, words, Vector2(r.position.x + 8, r.position.y + (r.size.y - 16) * 0.5), 2,
			colour, z + 0.0018)


## A pointer wedge from `c` at angle `a` (radians, 0 = right, down is +).
func pointer(f: Node3D, c: Vector2, a: float, r0: float, r1: float, w: float, z0: float,
		z1: float, m: Material) -> void:
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	G.slab(f, PackedVector2Array([c + d * r0 + n * w, c + d * r1 + n * w * 0.45,
			c + d * r1 - n * w * 0.45, c + d * r0 - n * w]), z0, z1, m)


## The brass bus: a flat bar on standoffs across the cabinet.
func bus(f: Node3D, y: float, x0 := 40.0, x1 := 1240.0) -> void:
	var brass := G.mat(BRASS, 0.7, 0.35)
	G.block(f, Rect2(x0, y - 5, x1 - x0, 10), 0.014, 0.022, brass)
	var x := x0 + 22.0
	while x < x1:
		G.disc(f, Vector2(x, y), 6.0, 0.0, 0.014, G.mat(Color("#1b1d1f"), 0.2, 0.6), 14)
		x += 236.0


# ------------------------------------------------------------ equipment

func _equipment() -> void:
	var f := face("equipment")
	var np := nameplate(f, 40, "EQUIPMENT", "02")
	var slot0: String = ctx["slot"]
	var cap := cap_of(slot0)
	var id: String = ctx["inspected"]
	window(f, WIN)
	# the window's roller shutter, run up into its housing: open, because
	# something is being looked at
	G.sleeve(f, Vector2(WIN.get_center().x, WIN.position.y + 9), false, 9.0, WIN.size.x,
			0.012, G.mat(CAB_HI.darkened(0.2), 0.4, 0.45), 18)
	_readout(f, id)
	bus(f, BUS_Y)
	# ---- ALWAYS ON: a riveted strip with no switch on it -- there is none
	var names := []
	for p: String in ctx["passives"]:
		names.append(name_of(p))
	var ap := Rect2(np.end.x + 28, 16, 1240 - np.end.x - 28, 38)
	G.slab(f, G.rrect(ap, 3), 0.0, 0.004, G.mat(CAB_HI, 0.3, 0.55))
	rivet(f, Vector2(ap.position.x + 9, ap.get_center().y), 0.004)
	rivet(f, Vector2(ap.end.x - 9, ap.get_center().y), 0.004)
	text(f, "ALWAYS ON · NO KEY", Vector2(ap.position.x + 24, 27), 2, DIM, 0.0052)
	text(f, kit.fit(" · ".join(names), 2, ap.size.x - 330), Vector2(ap.position.x + 300, 27),
			2, INK, 0.0052)
	# ---- the key selector: its pointer is the focused key; the keys stand
	# round its dial, evenly down the wall
	var keys: Array = ctx["keys"]
	var n := keys.size()
	G.disc(f, KNOB, 86, 0.0, 0.005, G.mat(CAB_HI, 0.3, 0.55), 40)
	G.ring(f, KNOB, 82, 87, 0.005, G.mat(BRASS, 0.7, 0.35))
	var angles := []
	var anchors := []
	for i in n:
		var dy := KEY_PITCH * (float(i) - float(n - 1) * 0.5)
		var dx := sqrt(maxf(ARC_R * ARC_R - dy * dy, 0.0))
		anchors.append(KNOB + Vector2(dx, dy))
		angles.append(atan2(dy, dx))
	for i in n:
		pointer(f, KNOB, angles[i], 66, 80, 2.2, 0.005, 0.007,
				G.unlit(INK if i == ctx["key_index"] else FAINT))
	G.disc(f, KNOB, 56, 0.005, 0.02, G.mat(BAKELITE.lightened(0.08), 0.1, 0.45), 36)
	G.disc(f, KNOB, 42, 0.02, 0.05, G.mat(BAKELITE, 0.1, 0.4), 32)
	pointer(f, KNOB, angles[ctx["key_index"]], 8, 58, 7.0, 0.05, 0.056,
			G.mat(Color("#e9e4d6"), 0.1, 0.5))
	for i in n:
		var k: Dictionary = keys[i]
		var slot := str(k["slot"])
		var at: Vector2 = anchors[i] + Vector2(8, -25)
		var here: bool = i == ctx["key_index"]
		var w := keycap(f, str(k["keycap"]), at, 0.002)
		text(f, str(k["title"]), at + Vector2(w + 10, 6), 2, INK if here else DIM)
		var on := seated(slot)
		var words := "EMPTY" if on == "" else kit.fit(name_of(on), 2, 170)
		var fw := Rect2(at + Vector2(0, 29), Vector2(236, 22))
		flag_window(f, fw, words, LIT_FAINT if on == "" else (LIT if here else LIT_DIM))
		if on != "" and charges(on) != "":
			kit.label(f, charges(on), Vector2(fw.end.x - 8 - kit.measure(charges(on), 2),
					fw.position.y + 3), 2, LIT_DIM, 0.0058)
	# the selector's own tap on the bus: a brass strap down to the dial
	G.block(f, Rect2(KNOB.x - 5, BUS_Y, 10, KNOB.y - 86 - BUS_Y + 4), 0.006, 0.012,
			G.mat(BRASS, 0.7, 0.35))
	_rack(f, cap)


## The rack: what fits the key, one relay card each. The card on the key is
## seated and strapped to the bus; the card being looked at is pulled.
func _rack(f: Node3D, cap: String) -> void:
	var ids: Array = ctx["candidates"]
	var plate := Rect2(RACK.position.x, RACK.position.y, 300, 24)
	text(f, "FITS %s · %d" % [cap, ids.size()], plate.position + Vector2(0, 4), 2, DIM)
	var shown := mini(SHOWN, ids.size())
	var more := "%d MORE BELOW" % (ids.size() - shown) if ids.size() > shown else ""
	if more != "":
		text(f, more, Vector2(RACK.end.x - 52 - kit.measure(more, 2), RACK.position.y + 4), 2,
				FAINT)
	# the cage: two slotted side rails
	var rail := G.mat(CAB_HI, 0.4, 0.45)
	var top := RACK.position.y + 32.0
	var bottom := top + CARD_PITCH * shown
	for x: float in [RACK.position.x, RACK.end.x - 14]:
		G.block(f, Rect2(x, top - 6, 14, bottom - top + 8), 0.0, 0.03, rail)
	# the scroll: a slot with a shoe showing which part of the rack is out
	var slot_r := Rect2(RACK.end.x + 6, top, 6, bottom - top)
	G.block(f, slot_r, 0.0, 0.002, G.mat(RECESS, 0.0, 0.9))
	G.block(f, Rect2(slot_r.position.x - 1, top, 8, (bottom - top) * float(shown)
			/ float(ids.size())), 0.002, 0.008, G.mat(Color("#8c9094"), 0.5, 0.4))
	for i in shown:
		var id: String = ids[i]
		var y := top + CARD_PITCH * i
		var pulled: bool = id == ctx["inspected"]
		var on_key: bool = id == ctx["equipped"]
		var dx := -30.0 if pulled else 0.0
		var z0 := 0.036 if pulled else 0.0
		var r := Rect2(RACK.position.x + 18 + dx, y, RACK.size.x - 36, CARD_PITCH - 5)
		if pulled:
			# the card's own board, drawn out of the cage behind its front
			G.block(f, Rect2(r.position.x + 14, y + 7, r.size.x - 20, CARD_PITCH - 19), 0.004,
					z0, G.mat(PCB, 0.1, 0.6))
		G.slab(f, G.rrect(r, 2), z0, z0 + 0.012, G.mat(CARD_FACE.lightened(0.12 if pulled
				else 0.0), 0.3, 0.5))
		# its pull
		G.block(f, Rect2(r.position.x + 6, y + 4, 12, CARD_PITCH - 13), z0 + 0.012, z0 + 0.03,
				G.unlit(Kit.SIGNAL) if pulled else G.mat(BAKELITE, 0.1, 0.45))
		var zt := z0 + 0.0132
		kit.label(f, kit.fit(name_of(id), 2, 330), Vector2(r.position.x + 30, y + 6), 2,
				INK if pulled or on_key else DIM, zt)
		var tags := [mk(id)]
		if authored(id):
			tags.append("AUTHORED")
		var t := " · ".join(tags)
		var tx := r.end.x - 12 - kit.measure(t, 2)
		if on_key:
			# the seated card's flag window says so; its strap goes up to the bus
			var fw := Rect2(r.end.x - 108, y + 3, 96, CARD_PITCH - 11)
			G.block(f, fw, zt - 0.001, zt - 0.0004, G.mat(RECESS, 0.0, 0.95), false)
			kit.label(f, "ON " + cap, fw.position + Vector2(8, 3), 2, LIT, zt)
			tx = fw.position.x - 12 - kit.measure(t, 2)
			G.block(f, Rect2(RACK.end.x - 34, BUS_Y, 10, y - BUS_Y + 4), 0.004, 0.012,
					G.mat(BRASS, 0.7, 0.35))
		kit.label(f, t, Vector2(tx, y + 6), 2, FAINT if not pulled else DIM, zt)


## The inspection window: the pulled card, read. What it does and what
## changes if it goes on the key, side by side; where it came from, quiet.
func _readout(f: Node3D, id: String) -> void:
	var z := 0.0022
	var x := WIN.position.x + 24.0
	var y := WIN.position.y + 28.0
	kit.label(f, kicker(id), Vector2(x, y), 2, LIT_DIM, z)
	y += 26.0
	var lw := 540.0
	# the name as large as it goes while everything under it still fits
	var fit := name_fit(name_of(id), lw, 5, 3, 3)
	var below := 34.0 + 30.0 * does(id).size() + 20.0 * kit.wrap(desc(id).to_upper(), 2,
			lw).size()
	while int(fit[0]) > 3 and y + (8.0 * int(fit[0]) + 6.0) * (fit[1] as Array).size() \
			+ below > WIN.end.y - 8.0:
		fit = name_fit(name_of(id), lw, int(fit[0]) - 1, 3, 3)
	for line: String in fit[1]:
		kit.label(f, line, Vector2(x, y), fit[0], LIT, z)
		y += 8.0 * int(fit[0]) + 6.0
	y += 4.0
	kit.label(f, "DOES", Vector2(x, y + 6), 2, LIT_FAINT, z)
	for line: String in does(id):
		for l in kit.wrap(line.to_upper(), 3, lw - 64):
			kit.label(f, l, Vector2(x + 64, y), 3, LIT, z)
			y += 30.0
	for l in kit.wrap(desc(id).to_upper(), 2, lw):
		kit.label(f, l, Vector2(x, y + 2), 2, LIT_DIM, z)
		y += 20.0
	# the mullion, and the change on the key
	var mx := WIN.position.x + 600.0
	G.block(f, Rect2(mx, WIN.position.y + 22, 8, WIN.size.y - 22), 0.0, 0.012,
			G.mat(CAB_HI, 0.35, 0.5))
	var rx := mx + 30.0
	var rw := WIN.end.x - rx - 24.0
	var ry := WIN.position.y + 28.0
	for line: String in kit.wrap(against_head(), 2, rw):
		kit.label(f, line, Vector2(rx, ry), 2, LIT_DIM, z)
		ry += 20.0
	ry = table(f, ctx["comparison"], rx, ry + 8.0, rw, z, LIT_DIM, LIT, LIT_FAINT)
	ry += 10.0
	for h: Array in history(id):
		kit.label(f, kit.fit("%s  %s" % [h[0], h[1]], 2, rw), Vector2(rx, ry), 2, LIT_FAINT, z)
		ry += 20.0
	# the preview: a push button, the one lit thing that acts
	var act := action(id)
	var ay := WIN.end.y - 50.0
	if act != "":
		var bw := kit.measure(act, 2) + 110.0
		G.slab(f, G.rrect(Rect2(rx - 4, ay, bw, 38), 6), 0.0, 0.01,
				G.mat(Color("#1d3a37"), 0.1, 0.6))
		keycap(f, "ENTER", Vector2(rx + 6, ay + 6), 0.01)
		kit.label(f, act, Vector2(rx + 94, ay + 11), 2, Kit.SIGNAL, 0.0112)
	if authored(id):
		kit.label(f, "AUTHORED", Vector2(WIN.end.x - 24 - kit.measure("AUTHORED", 2), ay + 11),
				2, LIT_FAINT, z)


# ------------------------------------------------------------ map

func _map() -> void:
	var f := face("map")
	var win := FaceMap.WINDOW
	nameplate(f, 40, "MAP", "03")
	# the port: the cabinet's heaviest frame, riveted
	var m := G.mat(CAB_HI, 0.35, 0.5)
	for b: Rect2 in [Rect2(win.position.x - 14, win.position.y - 14, win.size.x + 28, 14),
			Rect2(win.position.x - 14, win.end.y, win.size.x + 28, 14),
			Rect2(win.position.x - 14, win.position.y, 14, win.size.y),
			Rect2(win.end.x, win.position.y, 14, win.size.y)]:
		G.block(f, b, 0.0, 0.016, m)
	for p: Vector2 in [win.position + Vector2(-7, -7), Vector2(win.end.x + 7,
			win.position.y - 7), Vector2(win.position.x - 7, win.end.y + 7), win.end + Vector2(7,
			7)]:
		rivet(f, p, 0.016)
	# the detail: a status window set into the port, MapFace's own words
	var d := Rect2(win.end.x - 336, win.position.y + 20, 318, 330)
	window(f, d, 10.0, 0.03)
	G.block(f, d, 0.0, 0.029, G.mat(RECESS, 0.0, 0.95), false)
	G.sleeve(f, Vector2(d.get_center().x, d.position.y + 8), false, 7.0, d.size.x, 0.034,
			G.mat(CAB_HI.darkened(0.2), 0.4, 0.45), 16)
	var lines := (ctx["detail"] as String).split("\n")
	var y := d.position.y + 26.0
	kit.label(f, lines[0], Vector2(d.position.x + 18, y), 3, LIT, 0.0302)
	y += 38.0
	for i in range(1, lines.size()):
		for l in kit.wrap(lines[i].to_upper(), 2, d.size.x - 36):
			kit.label(f, l, Vector2(d.position.x + 18, y), 2, LIT_DIM if i == 1 else LIT, 0.0302)
			y += 20.0
		y += 6.0
	kit.label(f, "MAPFACE'S OWN DETAIL", Vector2(d.position.x, d.end.y + 16), 2, FAINT,
			0.0302)
	# the Journal's rod: brass, round the corner above the port, then a
	# pointer arm down into the window over its place; the menu's guide
	# stroke carries on to the passage
	var tx: float = ctx["link_page"].x
	var brass := G.mat(BRASS, 0.7, 0.35)
	G.tube(f, G.routed([Vector2(RUN_START, LINK_Y), Vector2(tx, LINK_Y),
			Vector2(tx, win.position.y + 6)], 10, 0.024), 5.0, brass, 12)
	for x: float in [RUN_START + 70, (RUN_START + tx) * 0.5]:
		G.block(f, Rect2(x - 5, LINK_Y - 8, 10, 16), 0.0, 0.022, G.mat(Color("#1b1d1f"), 0.2,
				0.6))
	G.disc(f, Vector2(tx, win.position.y + 6), 7.0, 0.018, 0.03, brass, 16)
	guide(f, Vector2(tx, win.position.y + 14), ctx["link_page"], LIT)


# ------------------------------------------------------------ journal

func _journal() -> void:
	var f := face("journal")
	var j: Dictionary = ctx["journal"]
	nameplate(f, 40, "JOURNAL", "04")
	# the log: printed cards held in a riveted frame
	var card := G.mat(toned(Color("#a9a393"), f), 0.0, 1.0)
	var holder := Rect2(40, 84, 520, 606)
	window(f, holder, 10.0, 0.012)
	var y := 104.0
	for sect: Array in [["OBJECTIVES", j["objectives"], ENAMEL_INK],
			["NOTES", j["notes"], Color("#3d3c38")]]:
		var lines := []
		for e: Variant in sect[1]:
			var s := str(e) if e is String else "%s -- %s" % [(e as Dictionary)["title"],
					(e as Dictionary)["text"]]
			lines.append_array(kit.wrap(s.to_upper(), 2, 450))
		var h := 40.0 + 20.0 * lines.size()
		h = minf(h, holder.end.y - 14.0 - y)
		G.slab(f, G.rrect(Rect2(58, y, 484, h), 2), 0.001, 0.004, card)
		kit.label(f, sect[0], Vector2(74, y + 10), 2, Color("#6d6a62"), 0.0052)
		var ly := y + 34.0
		for l: String in lines:
			if ly > y + h - 22.0:
				break
			kit.label(f, l, Vector2(74, ly), 2, sect[2], 0.0052)
			ly += 20.0
		y += h + 14.0
	# the conditions: each shut way in its own flag window -- its state is the
	# connector's own -- and the focused one lit and read out
	var x := 600.0
	y = 84.0
	text(f, "STILL SHUT", Vector2(x, y), 2, DIM)
	y += 30.0
	var shut: Array = j["still_shut"]
	var conns := {}
	for c: Dictionary in ctx["map_data"]["connectors"]:
		conns[str(c["edge_id"])] = c
	var links: Array = j["links"].get("still_shut", [])
	for i in shut.size():
		var focused := i == 0
		var state := str((conns.get(str((links[i] as Dictionary).get("edge_id", "")), {})
				as Dictionary).get("state", "")).to_upper()
		var words := kit.wrap(str(shut[i]).to_upper(), 2, 440)
		var h := 20.0 * words.size()
		if focused:
			h += 8.0 + 20.0 * (ctx["explanation"] as Array).size()
		var r := Rect2(x + 112, y - 6, 520, h + 12)
		if focused:
			window(f, r, 6.0, 0.01)
		flag_window(f, Rect2(x, y - 3, 96, 24), state, LIT if focused else LIT_DIM)
		var yy := y
		for l in words:
			kit.label(f, l, Vector2(x + 124, yy), 2, LIT if focused else DIM, 0.003)
			yy += 20.0
		if focused:
			yy += 8.0
			for l: String in ctx["explanation"]:
				kit.label(f, l, Vector2(x + 140, yy), 2, LIT_DIM, 0.003)
				yy += 20.0
		var bead: Dictionary = ctx["beads"][i]
		kit.sprite(f, bead["icon"], Vector2(x + 600, y + 9), 2, bead["colour"], 0.004)
		if focused:
			# the rod leaves the lit window's end for the corner
			var s0 := Vector2(r.end.x + 6, y + 9)
			G.tube(f, G.routed([s0, Vector2(1200, s0.y), Vector2(1200, LINK_Y),
					Vector2(RUN_END, LINK_Y)], 10, 0.024), 5.0, G.mat(BRASS, 0.7, 0.35), 12)
			G.disc(f, s0, 7.0, 0.012, 0.03, G.mat(BRASS, 0.7, 0.35), 16)
		y += h + 22.0
	# what you did here: the record, printed on tape out of its slot
	y += 6.0
	text(f, "WHAT YOU DID HERE", Vector2(x, y), 2, DIM)
	y += 28.0
	G.block(f, Rect2(x, y - 8, 300, 8), 0.0, 0.016, G.mat(CAB_HI, 0.35, 0.5))
	var done: Array = j["done_here"]
	var tape := Rect2(x + 16, y, 268, 16.0 + 20.0 * done.size())
	G.block(f, tape, 0.002, 0.004, card)
	var ty := y + 10.0
	for s: String in done:
		kit.label(f, kit.fit(s.to_upper(), 2, 250), Vector2(x + 26, ty), 2, ENAMEL_INK, 0.0052)
		ty += 20.0
	y = tape.end.y + 22.0
	text(f, "PLACES FOUND", Vector2(x, y), 2, DIM)
	y += 26.0
	for s: String in j["places"]:
		text(f, s.to_upper(), Vector2(x, y), 2, DIM)
		y += 22.0


# ------------------------------------------------------------ settings

func _settings() -> void:
	var f := face("settings")
	var s: Dictionary = ctx["settings"]
	nameplate(f, 40, "SETTINGS", "01")
	# PAUSED: the front push buttons; RESUME is the big one
	var y := 90.0
	text(f, "PAUSED", Vector2(40, y), 2, DIM)
	y += 30.0
	for i in (s["paused"] as Array).size():
		var label: String = s["paused"][i]
		var h := 58.0 if i == 0 else 42.0
		var r := Rect2(40, y, 330, h)
		G.slab(f, G.rrect(r, 6), 0.0, 0.008, G.mat(CAB_HI, 0.35, 0.5))
		G.disc(f, Vector2(r.position.x + 30, r.get_center().y), 14.0 if i == 0 else 10.0,
				0.008, 0.024, G.unlit(Kit.SIGNAL) if i == 0 else G.mat(BAKELITE, 0.1, 0.45), 24)
		kit.label(f, label, Vector2(r.position.x + 58, r.get_center().y - (12 if i == 0 else 8)),
				3 if i == 0 else 2, Kit.SIGNAL if i == 0 else INK, 0.0092)
		y += h + 10.0
	# CAMPAIGN: a status window of plain facts
	y += 16.0
	text(f, "CAMPAIGN", Vector2(40, y), 2, DIM)
	y += 28.0
	var camp: Array = s["campaign"]
	var cw := Rect2(52, y, 306, 16.0 + 22.0 * camp.size())
	window(f, cw, 8.0, 0.01)
	var cy := y + 10.0
	for line: String in camp:
		kit.label(f, kit.fit(line.to_upper(), 2, 286), Vector2(64, cy), 2, LIT_DIM, 0.0022)
		cy += 22.0
	# OPTIONS: the service face -- a calibration knob for each, its pointer
	# at the real default on its own scale; the toggle a real bat switch
	var x0 := 440.0
	y = 90.0
	text(f, "SERVICE -- OPTIONS", Vector2(x0, y), 2, DIM)
	y += 40.0
	var rows: Array = s["sliders"]
	for sl: Array in rows:
		var c := Vector2(x0 + 44, y + 30)
		G.disc(f, c, 40, 0.0, 0.004, G.mat(CAB_HI, 0.3, 0.55), 32)
		for t in 11:
			var a := deg_to_rad(135.0 + 27.0 * t)
			pointer(f, c, a, 32, 38, 0.9, 0.004, 0.005, G.unlit(FAINT))
		var a0 := deg_to_rad(135.0 + 270.0 * float(sl[1]))
		G.disc(f, c, 25, 0.004, 0.034, G.mat(BAKELITE, 0.1, 0.4), 28)
		pointer(f, c, a0, 4, 27, 3.4, 0.034, 0.038, G.mat(Color("#e9e4d6"), 0.1, 0.5))
		text(f, str(sl[0]), Vector2(x0 + 110, y + 10), 2, INK)
		flag_window(f, Rect2(1120, y + 6, 100, 26), str(sl[2]), LIT)
		y += 96.0
	for t: Array in s["toggles"]:
		var c := Vector2(x0 + 44, y + 22)
		G.slab(f, G.rrect(Rect2(c.x - 18, c.y - 26, 36, 52), 4), 0.0, 0.006,
				G.mat(CAB_HI, 0.35, 0.5))
		var on := bool(t[1])
		G.disc(f, c, 8, 0.006, 0.014, G.mat(Color("#8c9094"), 0.6, 0.35), 16)
		G.slab(f, G.rrect(Rect2(c.x - 4, c.y + (-22.0 if on else 2.0), 8, 20), 3), 0.014,
				0.036, G.mat(Color("#c9ccce"), 0.7, 0.3))
		text(f, str(t[0]), Vector2(x0 + 110, y + 12), 2, INK)
		flag_window(f, Rect2(1120, y + 8, 100, 26), "ON" if on else "OFF", LIT)
