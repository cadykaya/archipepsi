extends StudyDir
## THE HYBRID — ORIGINAL STATION HARDWARE, KEPT ALIVE BY EPSILON (Track A2,
## the fourth ruling of 2026-09-27). One machine, three kinds of parts:
##
## * ORIGINAL STATION HARDWARE (from C): the enamel enclosure on every wall;
##   Equipment's cabinet -- its inspection window, its key selector, its
##   brass bus; the Map's port. Formal, square, riveted, evenly spaced.
## * THE HARNESS (from B): one laced trunk round the whole box and every
##   corner. The walls' titles are flag labels on it; the Journal's and the
##   Map's warm tags hang from it; the Journal's ivory link runs along it,
##   round the corner, and drops into the Map over the place it means.
## * SALVAGED ELECTRONICS (from D): Equipment's item rack, rebuilt on a
##   salvaged backplane bolted into the cabinet's old bay through an adapter
##   plate, and wired back to the cabinet's bus through an adapter board;
##   its ribbon runs on round the corner into Settings, the maintenance
##   side, which is nearly all replacement boards.
##
## The subsystems are not averaged: each keeps its own materials. They share
## the harness, the type, the sizes, the interaction states (SIGNAL for what
## is focused and what acts; a backlit window for what IS -- "ON RMB", a
## value) and the mounting details (rivets on original parts, brass
## standoffs on salvaged ones, saddle clamps on the harness). A few joins
## say how they meet.
##
## Every state shown is interface data. Nothing here is a chore: a
## selection is a selection, and ENTER is the preview (labelled, local, not
## sent).

# ---- the original enclosure (C)
const CAB := Color("#2b2e31")
const CAB_HI := Color("#373b3f")
const RECESS := Color("#0c0e0f")
const ENAMEL := Color("#bdb7a5")
const ENAMEL_INK := Color("#1d1e20")
const RIVET := Color("#8c9094")
const BRASS := Color("#b08f52")
const BAKELITE := Color("#1a1512")
const CARD_FACE := Color("#3d4441")
const LIT := Color("#f1ebdb")
const LIT_DIM := Color("#aaa495")
const LIT_FAINT := Color("#7b766b")
const INK := Color("#e0e3e4")
const DIM := Color("#9da3a8")
const FAINT := Color("#6f757a")
# ---- the harness (B)
const LOOM := Color("#141619")
const LACE := Color("#b09863")
const WIRE := Color("#666d74")
const IVORY := Color("#eadcb8")
const FLAG := Color("#b0aa96")
const FLAG_INK := Color("#1b1c1e")
const TAG_DIM := Color("#555148")
const TAG_FAINT := Color("#7a7467")
const METAL := Color("#a3a8ab")
# ---- the salvage (D). No green board: the Style Lock keeps green for
# Epsilon alone (ART_BIBLE §1a, rule 3), so salvaged boards are paper
# phenolic, black mask and bare FR4.
const PHENOLIC := Color("#6b5232")
const BLACK_MASK := Color("#1b1d1d")
const FR4 := Color("#968c68")
const MODULE := Color("#171919")
const EDGE := Color("#8f8665")
const GOLD := Color("#c8a24c")
const TIN := Color("#b9bec2")
const HEADER := Color("#121314")
const TERMINAL := Color("#2c3034")      # screw terminals: grey, never green
const SILK := Color("#ebebe7")
const SILK_DIM := Color("#b2b2ad")
const SILK_FAINT := Color("#7f7f7a")
const RIBBON := Color("#8d9196")
const PLATE := Color("#7f8488")         # the adapter plate: bare aluminium
const TAPE := Color("#d6d2c6")          # embossed label tape
const TAPE_INK := Color("#161616")
const LCD := Color("#a9aaa5")
const LCD_INK := Color("#1d1e1c")
# ---- Epsilon (the Style Lock: identity green, only from inside)
const IDENTITY := Color("#57ff1f")
const IDENTITY_SEAM := Color("#339612")
const HOST := Color("#5b6065")          # ordinary bolted grey plate
const PLATING := Color("#101211")       # his near-black plating

const TRUNK_Y := 40.0
const TRUNK_Z := 0.022
const TRUNK_R := 10.0
const LINK_Y := 16.0                    # the Journal's link, laced above the trunk
const LINK_Z := 0.02
const WIRE_Z := 0.016
const BOARD_Z := 0.014
const RIBBON_Y := 650.0                 # the rack's ribbon round into Settings
const RIBBON_Z := 0.02
# Equipment
const WIN := Rect2(40, 112, 1200, 256)
const BUS_Y := 390.0
const BUS_END := 540.0                  # the original bus ends at its terminal
const KNOB := Vector2(116, 556)
const ARC_R := 150.0
const KEY_PITCH := 58.0
const BAY := Rect2(596, 404, 656, 302)  # where the rebuilt rack stands
const OLD_BAY_END := 1004.0             # where the cabinet's own bay ended
const ROW_Y0 := 436.0
const ROW_PITCH := 30.0
const SHOWN := 9


func title() -> String:
	return "HYBRID -- ORIGINAL STATION HARDWARE, KEPT ALIVE BY EPSILON"


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
	var grey := G.mat(RIBBON, 0.1, 0.6)
	for k in 6:
		corner("equipment", RIBBON_Y + (float(k) - 2.5) * 3.4, 1.7, grey, RIBBON_Z)


func _wall() -> Material:
	var m: StandardMaterial3D = kit.wall_material().duplicate()
	m.albedo_color = CAB
	return m


func _loom() -> Material:
	return G.mat(LOOM, 0.1, 0.45)


# ============================================================ the harness (B)

## The trunk's run across a wall, laced where nothing else holds it, and
## held to the enclosure by saddle clamps at `clamps`.
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


func tie(f: Node3D, at: Vector2, vertical: bool, r: float, z: float) -> void:
	G.sleeve(f, at, vertical, r + 1.1, 4.0, z, G.mat(LACE, 0.0, 0.8), 14)
	G.disc(f, at, 2.4, z + r * Kit.px(), z + r * Kit.px() + 0.0025,
			G.mat(LACE.darkened(0.15), 0.0, 0.8), 10)


## A saddle clamp: the harness's own mounting, the same on every wall.
func saddle(f: Node3D, x: float, y := TRUNK_Y, r := TRUNK_R, z := TRUNK_Z) -> void:
	var m := G.mat(METAL, 0.6, 0.35)
	G.block(f, Rect2(x - 8, y - r - 12, 16, 2 * r + 24), 0.0, 0.003, m)
	G.sleeve(f, Vector2(x, y), false, r + 1.8, 12.0, z, m)
	for s: float in [-1.0, 1.0]:
		G.disc(f, Vector2(x, y + s * (r + 7.0)), 3.2, 0.003, 0.0065,
				G.mat(Color("#70767a"), 0.6, 0.4), 12)


## A flag label on the trunk: every wall's title is one.
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
func vflag(f: Node3D, x: float, y: float, words: String, r := 3.5, z := WIRE_Z) -> Rect2:
	var w := kit.measure(words, 2) + 22.0
	var h := 30.0
	var card := G.mat(toned(FLAG, f), 0.0, 1.0)
	G.sleeve(f, Vector2(x, y + h * 0.5), true, r + 1.6, h, z, card, 14)
	var rect := Rect2(x + r - 2.0, y, w + 2.0, h)
	G.slab(f, G.rrect(rect, 3.0), z - 0.0012, z + 0.0012, card)
	kit.label(f, words, Vector2(x + r + 9.0, y + 7.0), 2, FLAG_INK, z + 0.0024)
	return rect


## A warm hang tag, chamfered at the top; hung from the trunk by two
## strings, or (`eyelets` false) clipped to a run.
func tag(f: Node3D, r: Rect2, z := 0.03, eyelets := true) -> void:
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


func wire(f: Node3D, page: Array, colour: Color, r := 3.5, z := WIRE_Z, bend := 18.0) -> void:
	G.tube(f, G.routed(page, bend, z), r, G.mat(colour, 0.05, 0.55), 12)


## A flat ribbon: six conductors side by side along a routed page path,
## kept parallel through its bends.
func ribbon(f: Node3D, page: Array, z := RIBBON_Z, bend := 14.0) -> void:
	var grey := G.mat(RIBBON, 0.1, 0.6)
	var n := page.size()
	for k in 6:
		var o := (float(k) - 2.5) * 3.4
		var pts := []
		for i in n:
			var p: Vector2 = page[i]
			var dp := Vector2.ZERO
			var dn := Vector2.ZERO
			if i > 0:
				dp = (p - (page[i - 1] as Vector2)).normalized()
			if i < n - 1:
				dn = ((page[i + 1] as Vector2) - p).normalized()
			var np := Vector2(-dp.y, dp.x)
			var nn := Vector2(-dn.y, dn.x)
			var off: Vector2
			if i == 0:
				off = nn
			elif i == n - 1:
				off = np
			else:
				var m := (np + nn).normalized()
				off = m / maxf(0.5, m.dot(np))
			pts.append(p + off * o)
		G.tube(f, G.routed(pts, bend, z), 1.7, grey, 8)


# ============================================================ original hardware (C)

func rivet(f: Node3D, at: Vector2, z: float) -> void:
	G.disc(f, at, 3.4, z, z + 0.003, G.mat(RIVET, 0.6, 0.4), 12)


## A window cut into the enclosure: a raised, riveted frame round a dark
## recess.
func window(f: Node3D, r: Rect2, frame := 12.0, depth := 0.014, rivets := true) -> void:
	var m := G.mat(CAB_HI, 0.35, 0.5)
	for b: Rect2 in [Rect2(r.position.x - frame, r.position.y - frame, r.size.x + frame * 2,
				frame), Rect2(r.position.x - frame, r.end.y, r.size.x + frame * 2, frame),
			Rect2(r.position.x - frame, r.position.y, frame, r.size.y),
			Rect2(r.end.x, r.position.y, frame, r.size.y)]:
		G.block(f, b, 0.0, depth, m)
	G.block(f, r, 0.0, 0.0008, G.mat(RECESS, 0.0, 0.95), false)
	if rivets:
		for p: Vector2 in [r.position + Vector2(-frame * 0.5, -frame * 0.5),
				Vector2(r.end.x + frame * 0.5, r.position.y - frame * 0.5),
				Vector2(r.position.x - frame * 0.5, r.end.y + frame * 0.5),
				r.end + Vector2(frame, frame) * 0.5]:
			rivet(f, p, depth)


## A backlit flag window: its word IS the state. The same on original and
## salvaged parts -- what something is, is always read in one of these.
func flag_window(f: Node3D, r: Rect2, words: String, colour: Color, z := 0.004) -> void:
	G.block(f, r.grow(3.0), 0.0, z, G.mat(CAB_HI, 0.35, 0.5))
	G.block(f, r, z, z + 0.0006, G.mat(RECESS, 0.0, 0.95), false)
	kit.label(f, words, Vector2(r.position.x + 8, r.position.y + (r.size.y - 16) * 0.5), 2,
			colour, z + 0.0018)


func pointer(f: Node3D, c: Vector2, a: float, r0: float, r1: float, w: float, z0: float,
		z1: float, m: Material) -> void:
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	G.slab(f, PackedVector2Array([c + d * r0 + n * w, c + d * r1 + n * w * 0.45,
			c + d * r1 - n * w * 0.45, c + d * r0 - n * w]), z0, z1, m)


## A vertical seam between two of the enclosure's panels, riveted at its
## ends: the box was built, not moulded.
func seam(f: Node3D, x: float, y0: float, y1: float) -> void:
	G.block(f, Rect2(x - 1, y0, 2, y1 - y0), 0.0, 0.0006, G.unlit(Color("#161819")), false)
	for y: float in [y0 + 10.0, y1 - 10.0]:
		rivet(f, Vector2(x - 8, y), 0.0)
		rivet(f, Vector2(x + 8, y), 0.0)


# ============================================================ salvage (D)

## A salvaged board: its mask inside its cut FR4 edge, on brass standoffs.
func board(f: Node3D, poly: PackedVector2Array, colour: Color, z := BOARD_Z,
		posts: Array = []) -> void:
	G.slab(f, poly, z - 0.004, z - 0.0008, G.mat(toned(EDGE, f), 0.1, 0.7))
	G.slab(f, _inset(poly, 2.5), z - 0.0008, z, G.mat(toned(colour, f), 0.15, 0.6))
	for p: Vector2 in posts:
		standoff(f, p, z)


## A brass hex standoff and its screw: how every salvaged part is mounted.
func standoff(f: Node3D, p: Vector2, z: float) -> void:
	G.disc(f, p, 7.0, 0.0, z - 0.004, G.mat(BRASS, 0.6, 0.35), 6)
	G.disc(f, p, 5.2, z, z + 0.004, G.mat(TIN, 0.6, 0.35), 16)
	G.disc(f, p, 2.2, z + 0.004, z + 0.0046, G.unlit(Color("#0b0c0c")), 10, false)


func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(poly, -d)
	return grown[0] if not grown.is_empty() else poly


func silk(f: Node3D, s: String, at: Vector2, k: int, colour: Color, z := BOARD_Z) -> void:
	kit.label(f, s, at, k, colour, z + 0.0008)


func bridge(f: Node3D, a: Vector2, b: Vector2, z := BOARD_Z) -> void:
	var mid := (a + b) * 0.5
	G.tube(f, [G.P(a, z + 0.001), G.P(mid, z + 0.006), G.P(b, z + 0.001)], 1.6,
			G.mat(TIN, 0.6, 0.35), 8)
	for p: Vector2 in [a, b]:
		G.disc(f, p, 4.0, z, z + 0.0028, G.mat(TIN, 0.6, 0.35), 12)


func header(f: Node3D, r: Rect2, z := BOARD_Z) -> void:
	G.block(f, r, z, z + 0.01, G.mat(HEADER, 0.1, 0.5))
	var vertical := r.size.y > r.size.x
	var t := r.position.y + 7.0 if vertical else r.position.x + 7.0
	var end := r.end.y - 4.0 if vertical else r.end.x - 4.0
	while t < end:
		var c := Vector2(r.get_center().x, t) if vertical else Vector2(t, r.get_center().y)
		G.block(f, Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3)), z + 0.01, z + 0.0104,
				G.unlit(Color("#050505")), false)
		t += 9.0


## Embossed label tape: raised words, stuck on by hand.
func tape(f: Node3D, at: Vector2, words: String, z: float) -> Rect2:
	var r := Rect2(at, Vector2(kit.measure(words, 2) + 16.0, 24))
	G.block(f, r, z, z + 0.0012, G.mat(TAPE, 0.1, 0.45))
	kit.label(f, words, at + Vector2(8, 4), 2, TAPE_INK, z + 0.0024)
	return r


# ============================================================ Epsilon

## EPSILON, once in the whole machine: the Style Lock's own terms. Near-black
## plating bursts through an ordinary bolted grey plate of the old enclosure
## (embedded, never placed); asymmetric; identity green only from INSIDE --
## through the seams between the shards -- and one narrow aperture. Nothing
## is written on him: he is not a slot, a setting or a status light.
func _epsilon(f: Node3D, c: Vector2) -> void:
	var host := Rect2(c - Vector2(50, 40), Vector2(100, 80))
	G.slab(f, G.rrect(host, 3), 0.0, 0.006, G.mat(HOST, 0.4, 0.55))
	for p: Vector2 in [host.position + Vector2(8, 8), Vector2(host.end.x - 8,
			host.position.y + 8), Vector2(host.position.x + 8, host.end.y - 8),
			host.end - Vector2(8, 8)]:
		rivet(f, p, 0.006)
	# the plate torn open where he came through; the light is inside it
	var hole := PackedVector2Array([c + Vector2(-32, -6), c + Vector2(-18, -26),
		c + Vector2(4, -28), c + Vector2(30, -16), c + Vector2(36, 8), c + Vector2(18, 28),
		c + Vector2(-8, 26), c + Vector2(-26, 16)])
	G.slab(f, hole, 0.006, 0.0066, G.unlit(IDENTITY_SEAM))
	# three shards of his plating, at different depths, never symmetric
	var plating := G.mat(PLATING, 0.35, 0.4)
	for shard: Array in [
			[[[-36, -8], [-18, -31], [2, -16], [-6, 6], [-30, 16]], 0.03],
			[[[5, -33], [35, -18], [41, 10], [16, 5], [8, -14]], 0.042],
			[[[-9, 11], [12, 9], [23, 33], [-8, 31], [-29, 21]], 0.024]]:
		var pts := PackedVector2Array()
		for q: Array in shard[0]:
			pts.append(c + Vector2(float(q[0]), float(q[1])))
		G.slab(f, pts, 0.0066, float(shard[1]), plating)
	# the one aperture: a narrow bore, and it points
	G.disc(f, c + Vector2(20, -6), 5.0, 0.042, 0.046, G.mat(PLATING.lightened(0.1), 0.4,
			0.4), 16)
	G.disc(f, c + Vector2(20, -6), 3.0, 0.046, 0.0466, G.unlit(IDENTITY), 16, false)


# ============================================================ equipment

func _equipment() -> void:
	var f := face("equipment")
	var title_flag := flag(f, 40, "EQUIPMENT", 4, "02")
	trunk(f, [520.0, 1110.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(1186, 1214)])
	var slot0: String = ctx["slot"]
	var cap := cap_of(slot0)
	var id: String = ctx["inspected"]
	# ---- ALWAYS ON: a riveted strip of the original cabinet, and no switch
	# on it, because there is none
	var names := []
	for p: String in ctx["passives"]:
		names.append(name_of(p))
	var ap := Rect2(title_flag.end.x + 30, 60, 1160 - title_flag.end.x - 30, 30)
	G.slab(f, G.rrect(ap, 3), 0.0, 0.004, G.mat(CAB_HI, 0.3, 0.55))
	rivet(f, Vector2(ap.position.x + 9, ap.get_center().y), 0.004)
	rivet(f, Vector2(ap.end.x - 9, ap.get_center().y), 0.004)
	text(f, "ALWAYS ON · NO KEY", Vector2(ap.position.x + 24, ap.position.y + 7), 2, DIM,
			0.0052)
	text(f, kit.fit(" · ".join(names), 2, ap.size.x - 320), Vector2(ap.position.x + 290,
			ap.position.y + 7), 2, INK, 0.0052)
	# ---- the harness feeds the cabinet: a branch off the trunk into an
	# original cable gland on the cabinet's top
	var gx := 1200.0
	wire(f, [Vector2(gx, TRUNK_Y), Vector2(gx, 88)], WIRE, 3.5)
	G.sleeve(f, Vector2(gx, 78), true, 6.0, 14, WIRE_Z, G.mat(Color("#202225"), 0.05, 0.7))
	G.disc(f, Vector2(gx, 92), 11.0, 0.0, 0.012, G.mat(RIVET, 0.6, 0.4), 6)
	G.disc(f, Vector2(gx, 92), 6.5, 0.012, 0.018, G.mat(CAB_HI, 0.4, 0.5), 16)
	# ---- the inspection window: the original cabinet's readout
	window(f, WIN)
	_readout(f, id)
	# ---- the original bus, to its terminal block
	var brass := G.mat(BRASS, 0.7, 0.35)
	G.block(f, Rect2(40, BUS_Y - 5, BUS_END - 40, 10), 0.014, 0.022, brass)
	for x: float in [62.0, 300.0]:
		G.disc(f, Vector2(x, BUS_Y), 6.0, 0.0, 0.014, G.mat(Color("#1b1d1f"), 0.2, 0.6), 14)
	var term := Rect2(BUS_END - 4, BUS_Y - 14, 44, 28)
	G.slab(f, G.rrect(term, 3), 0.0, 0.02, G.mat(BAKELITE.lightened(0.05), 0.1, 0.45))
	for i in 2:
		G.disc(f, Vector2(term.position.x + 12 + 20 * i, BUS_Y), 5.0, 0.02, 0.026, brass, 12)
	_selector(f)
	_rack(f, cap, term)


## The key selector: the cabinet's oldest, most formal part. Its pointer is
## the focused key; each key's flag window says what that key holds.
func _selector(f: Node3D) -> void:
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
	# the selector's own strap up to the bus
	G.block(f, Rect2(KNOB.x - 5, BUS_Y, 10, KNOB.y - 86 - BUS_Y + 4), 0.006, 0.012,
			G.mat(BRASS, 0.7, 0.35))


## The rack, rebuilt: the cabinet's old bay keeps its riveted top and left
## frame; a salvaged backplane stands in it on an adapter plate and runs out
## past where the bay's right side was cut away. Its modules are one clean
## list: the one on the key is SEATED (its window says so); the one being
## read is PULLED. The backplane is wired back to the cabinet's bus through
## an adapter board, and its ribbon runs on round the corner into Settings.
func _rack(f: Node3D, cap: String, term: Rect2) -> void:
	var ids: Array = ctx["candidates"]
	# the cabinet's own bay: a recess only as wide as its old card cage was,
	# its riveted frame kept on the top and the left -- and the top bar cut
	# off where the rebuilt rack outgrew it: a bright cut face, and past it
	# the empty holes of the rivets that went with the rest of the bar
	var m := G.mat(CAB_HI, 0.35, 0.5)
	var old := Rect2(BAY.position.x, BAY.position.y, OLD_BAY_END - BAY.position.x, BAY.size.y)
	G.block(f, old, 0.0, 0.0008, G.mat(RECESS, 0.0, 0.95), false)
	G.block(f, Rect2(old.position.x - 12, old.position.y - 12, old.size.x + 12, 12), 0.0,
			0.014, m)
	G.block(f, Rect2(old.end.x, old.position.y - 12, 3, 12), 0.0, 0.014,
			G.mat(Color("#c7cbce"), 0.7, 0.3))
	G.block(f, Rect2(old.position.x - 12, old.position.y, 12, old.size.y), 0.0, 0.014, m)
	for p: Vector2 in [Vector2(old.position.x - 6, old.position.y - 6),
			Vector2(old.position.x + 200, old.position.y - 6),
			Vector2(old.position.x - 6, old.end.y - 10)]:
		rivet(f, p, 0.014)
	for x: float in [old.end.x + 60.0, old.end.x + 164.0]:
		G.disc(f, Vector2(x, old.position.y - 6), 3.0, 0.0, 0.0006, G.unlit(Color("#08090a")),
				10, false)
	# the adapter plate: bare aluminium, bolted into the old bay
	var plate := Rect2(old.position.x + 4, old.position.y + 2, old.size.x - 2, old.size.y - 4)
	G.block(f, plate, 0.0008, 0.003, G.mat(PLATE, 0.55, 0.45))
	for p: Vector2 in [plate.position + Vector2(9, 9), Vector2(plate.position.x + 9,
			plate.end.y - 9)]:
		G.disc(f, p, 4.2, 0.003, 0.006, G.mat(TIN, 0.6, 0.35), 14)
		G.block(f, Rect2(p.x - 3, p.y - 0.6, 6, 1.2), 0.006, 0.0064, G.unlit(Color("#111")),
				false)
	# the backplane: salvaged, past the bay to the wall's edge
	var bp := PackedVector2Array([Vector2(BAY.position.x + 16, BAY.position.y + 8),
		Vector2(1228, BAY.position.y + 8), Vector2(1228, 690), Vector2(1204, 714),
		Vector2(BAY.position.x + 40, 714), Vector2(BAY.position.x + 16, 690)])
	var bz := BOARD_Z + 0.004
	board(f, bp, PHENOLIC, bz, [Vector2(BAY.position.x + 30, BAY.position.y + 22),
			Vector2(1214, BAY.position.y + 22), Vector2(BAY.position.x + 30, 698),
			Vector2(1190, 700)])
	silk(f, "FITS %s · %d" % [cap, ids.size()], Vector2(BAY.position.x + 46,
			BAY.position.y + 14), 2, SILK, bz)
	var shown := mini(SHOWN, ids.size())
	var more := "%d MORE BELOW" % (ids.size() - shown) if ids.size() > shown else ""
	if more != "":
		silk(f, more, Vector2(1190 - kit.measure(more, 2), BAY.position.y + 14), 2, SILK_FAINT,
				bz)
	# the edge connector each module plugs into
	header(f, Rect2(BAY.position.x + 30, ROW_Y0 - 2, 12, ROW_PITCH * shown - 2), bz)
	# the scroll: a repurposed slide pot, its knob over the part of the list shown
	var track := Rect2(1206, ROW_Y0, 8, ROW_PITCH * shown - 4)
	G.block(f, track, bz, bz + 0.004, G.mat(Color("#0b0b0b"), 0.1, 0.8))
	G.block(f, Rect2(track.position.x - 3, track.position.y, 14, track.size.y * float(shown)
			/ float(ids.size())), bz + 0.004, bz + 0.012, G.mat(Color("#cfd2cf"), 0.2, 0.5))
	for i in shown:
		var mid: String = ids[i]
		var y := ROW_Y0 + ROW_PITCH * i
		var pulled: bool = mid == ctx["inspected"]
		var on_key: bool = mid == ctx["equipped"]
		var dx := -26.0 if pulled else 0.0
		var z0 := bz + (0.034 if pulled else 0.006)
		var r := Rect2(BAY.position.x + 44 + dx, y, 1196 - (BAY.position.x + 44), ROW_PITCH - 4)
		if pulled:
			# its board, drawn out of the connector behind its face
			G.block(f, Rect2(r.position.x + 10, y + 5, 60, ROW_PITCH - 14), bz, z0,
					G.mat(BLACK_MASK.lightened(0.08), 0.15, 0.6))
		G.slab(f, G.rrect(r, 2), z0 - 0.003, z0, G.mat(MODULE.lightened(0.07 if pulled
				else 0.0), 0.15, 0.55))
		# its gold contacts at the connector, and its pull
		G.block(f, Rect2(r.position.x - 6, y + 6, 8, ROW_PITCH - 16), z0 - 0.002, z0 - 0.0006,
				G.mat(GOLD, 0.8, 0.3), false)
		G.block(f, Rect2(r.position.x + 6, y + 5, 10, ROW_PITCH - 14), z0, z0 + 0.016,
				G.unlit(Kit.SIGNAL) if pulled else G.mat(BAKELITE, 0.1, 0.45))
		var zt := z0 + 0.0008
		kit.label(f, kit.fit(name_of(mid), 2, 330), Vector2(r.position.x + 26, y + 5), 2,
				SILK if pulled or on_key else SILK_DIM, zt)
		var tags := [mk(mid)]
		if authored(mid):
			tags.append("AUTHORED")
		var t := " · ".join(tags)
		var tx := r.end.x - 10 - kit.measure(t, 2)
		if on_key:
			# seated: its window says what it is -- the same window as the keys'
			var fw := Rect2(r.end.x - 102, y + 3, 94, ROW_PITCH - 10)
			G.block(f, fw, z0, z0 + 0.0006, G.mat(RECESS, 0.0, 0.95), false)
			kit.label(f, "ON " + cap, fw.position + Vector2(8, 2), 2, LIT, z0 + 0.0018)
			tx = fw.position.x - 10 - kit.measure(t, 2)
		kit.label(f, t, Vector2(tx, y + 5), 2, SILK_DIM if pulled else SILK_FAINT, zt)
	# ---- the join back into the cabinet: the bus's terminal, a short lead,
	# an adapter board, and a ribbon to the backplane's own header
	var ad := Rect2(term.position.x - 2, term.end.y + 14, 50, 44)
	board(f, G.rrect(ad, 3), BLACK_MASK, BOARD_Z + 0.004, [ad.position + Vector2(8, 8)])
	G.block(f, Rect2(ad.position.x + 20, ad.position.y + 6, 24, 10), BOARD_Z + 0.004,
			BOARD_Z + 0.014, G.mat(TERMINAL, 0.1, 0.5))
	wire(f, [Vector2(term.position.x + 32, BUS_Y + 4), Vector2(term.position.x + 32,
			ad.position.y + 11)], IVORY.darkened(0.25), 1.8, 0.022, 4.0)
	header(f, Rect2(ad.position.x + 8, ad.end.y - 16, 34, 10), BOARD_Z + 0.004)
	ribbon(f, [Vector2(ad.get_center().x, ad.end.y - 10), Vector2(ad.get_center().x,
			ad.end.y + 8), Vector2(BAY.position.x + 36, ad.end.y + 8), Vector2(BAY.position.x
			+ 36, ROW_Y0 - 6)], 0.034)
	# ---- and on round the corner into Settings: the backplane's ribbon
	header(f, Rect2(1188, RIBBON_Y - 12, 12, 24), bz)
	ribbon(f, [Vector2(1196, RIBBON_Y), Vector2(RUN_END, RIBBON_Y)], RIBBON_Z)


## The inspection window, read: what it does and what changes if it goes on
## the key, side by side; where it came from, quiet. It swaps whole and at
## once -- no shutter, no wait.
func _readout(f: Node3D, id: String) -> void:
	var z := 0.0022
	var x := WIN.position.x + 24.0
	var y := WIN.position.y + 22.0
	kit.label(f, kicker(id), Vector2(x, y), 2, LIT_DIM, z)
	y += 26.0
	var lw := 540.0
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
	var mx := WIN.position.x + 600.0
	G.block(f, Rect2(mx, WIN.position.y, 8, WIN.size.y), 0.0, 0.012, G.mat(CAB_HI, 0.35, 0.5))
	var rx := mx + 30.0
	var rw := WIN.end.x - rx - 24.0
	var ry := WIN.position.y + 22.0
	for line: String in kit.wrap(against_head(), 2, rw):
		kit.label(f, line, Vector2(rx, ry), 2, LIT_DIM, z)
		ry += 20.0
	ry = table(f, ctx["comparison"], rx, ry + 8.0, rw, z, LIT_DIM, LIT, LIT_FAINT)
	ry += 10.0
	for h: Array in history(id):
		kit.label(f, kit.fit("%s  %s" % [h[0], h[1]], 2, rw), Vector2(rx, ry), 2, LIT_FAINT, z)
		ry += 20.0
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


# ============================================================ map

func _map() -> void:
	var f := face("map")
	var win := FaceMap.WINDOW
	# the port: original hardware, the enclosure's heaviest frame
	var m := G.mat(CAB_HI, 0.35, 0.5)
	for b: Rect2 in [Rect2(win.position.x - 14, win.position.y - 14, win.size.x + 28, 14),
			Rect2(win.position.x - 14, win.end.y, win.size.x + 28, 14),
			Rect2(win.position.x - 14, win.position.y, 14, win.size.y),
			Rect2(win.end.x, win.position.y, 14, win.size.y)]:
		G.block(f, b, 0.0, 0.016, m)
	for p: Vector2 in [Vector2(win.end.x + 7, win.position.y - 7), Vector2(win.position.x - 7,
			win.end.y + 7), win.end + Vector2(7, 7)]:
		rivet(f, p, 0.016)
	var tx: float = ctx["link_page"].x
	var title_flag := flag(f, 40, "MAP", 4, "03")
	var d := Rect2(win.end.x - 352, 112, 330, 350)
	trunk(f, [640.0, 800.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(tx - 24, tx + 24), Vector2(d.position.x + 24, d.position.x + 52),
			Vector2(d.end.x - 52, d.end.x - 24)])
	# the detail: a warm tag hung from the harness over the port -- MapFace's
	# own words
	tag(f, d)
	var lines := (ctx["detail"] as String).split("\n")
	var y := d.position.y + 34.0
	kit.label(f, lines[0], Vector2(d.position.x + 22, y), 3, FLAG_INK, 0.0312)
	y += 40.0
	for i in range(1, lines.size()):
		for l in kit.wrap(lines[i].to_upper(), 2, d.size.x - 44):
			kit.label(f, l, Vector2(d.position.x + 22, y), 2, TAG_DIM if i == 1 else FLAG_INK,
					0.0312)
			y += 20.0
		y += 6.0
	kit.label(f, "MAPFACE'S OWN DETAIL", Vector2(d.position.x + 22, d.end.y - 30), 2,
			TAG_FAINT, 0.0312)
	# the Journal's link: laced above the trunk from the corner to over its
	# place, then forward over the trunk and down into the port, where the
	# menu's guide stroke carries on to the passage
	var ivory := G.mat(IVORY, 0.05, 0.55)
	G.tube(f, G.routed([Vector2(RUN_START, LINK_Y), Vector2(tx - 20, LINK_Y)], 10, LINK_Z)
			+ G.smooth3([G.P(Vector2(tx - 6, LINK_Y + 2), LINK_Z + 0.004),
				G.P(Vector2(tx, LINK_Y + 14), 0.04), G.P(Vector2(tx, TRUNK_Y), 0.044),
				G.P(Vector2(tx, TRUNK_Y + 22), 0.036),
				G.P(Vector2(tx, win.position.y - 4), 0.022)], 6), 4.0, ivory, 12)
	var x := RUN_START + 30.0
	while x < tx - 40.0:
		tie(f, Vector2(x, LINK_Y), false, 4.0, LINK_Z)
		x += 88.0
	G.block(f, Rect2(tx - 7, win.position.y - 14, 14, 16), 0.016, 0.03,
			G.mat(METAL, 0.6, 0.35))
	guide(f, Vector2(tx, win.position.y + 8), ctx["link_page"], IVORY)


# ============================================================ journal

func _journal() -> void:
	var f := face("journal")
	var j: Dictionary = ctx["journal"]
	seam(f, 574, 104, 700)
	var title_flag := flag(f, 40, "JOURNAL", 4, "04")
	var lx := 46.0
	var rx := 600.0
	var up_x := 1210.0
	trunk(f, [880.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(lx - 14, lx + 14), Vector2(rx - 14, rx + 14), Vector2(up_x - 20, up_x + 20)])
	wire(f, [Vector2(lx, TRUNK_Y), Vector2(lx, 690)], WIRE)
	var y := 112.0
	vflag(f, lx, y, "OBJECTIVES")
	y += 44.0
	for s: String in j["objectives"]:
		y = para(f, s.to_upper(), Vector2(74, y), 470, 2, INK, 0.003, 20.0) + 6.0
	y += 16.0
	vflag(f, lx, y, "NOTES")
	y += 44.0
	for n: Dictionary in j["notes"]:
		if y > 660.0:
			break
		y = para(f, ("%s -- %s" % [n["title"], n["text"]]).to_upper(), Vector2(74, y), 470,
				2, DIM, 0.003, 20.0) + 4.0
	wire(f, [Vector2(rx, TRUNK_Y), Vector2(rx, 690)], WIRE)
	y = 112.0
	vflag(f, rx, y, "STILL SHUT")
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
			G.block(f, Rect2(rx + 20, y - 4, 4, h + 8), 0.026, 0.0266, G.unlit(Kit.SIGNAL),
					false)
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
			var s0 := Vector2(rx + 594, y + 9)
			G.tube(f, G.smooth3([G.P(s0, 0.024), G.P(s0 + Vector2(16, 0), 0.026),
					G.P(Vector2(up_x, y + 2), 0.03), G.P(Vector2(up_x, TRUNK_Y + 24), 0.036),
					G.P(Vector2(up_x, TRUNK_Y), 0.044), G.P(Vector2(up_x, LINK_Y + 14), 0.04),
					G.P(Vector2(up_x + 10, LINK_Y + 1), LINK_Z + 0.004)], 6)
					+ [G.P(Vector2(RUN_END, LINK_Y), LINK_Z)], 4.0,
					G.mat(IVORY, 0.05, 0.55), 12)
		y += h + 20.0
	y += 6.0
	vflag(f, rx, y, "WHAT YOU DID HERE")
	y += 44.0
	for s: String in j["done_here"]:
		y = para(f, s.to_upper(), Vector2(rx + 34, y), 540, 2, DIM, 0.003, 20.0) + 4.0
	y += 12.0
	vflag(f, rx, y, "PLACES FOUND")
	y += 44.0
	for s: String in j["places"]:
		text(f, s.to_upper(), Vector2(rx + 34, y), 2, DIM)
		y += 22.0


# ============================================================ settings

## Settings: the maintenance and calibration side -- three salvaged boards
## of three different stocks over the old enclosure, joined where they
## meet; the old enclosure shows between them. Repurposed controls at their
## real values, each labelled by hand. The rack's ribbon arrives from round
## the corner into a board of the rack's own stock. Epsilon comes through
## the old plate at the top right, and the harness's drop to these boards
## runs through him. Salvaged, not broken: nothing here is a fault or a
## chore.
func _settings() -> void:
	var f := face("settings")
	var s: Dictionary = ctx["settings"]
	var title_flag := flag(f, 40, "SETTINGS", 4, "01")
	var ep := Vector2(1190, 104)
	trunk(f, [560.0, 1000.0], [Vector2(title_flag.position.x, title_flag.end.x),
			Vector2(ep.x - 20, ep.x + 20)])
	seam(f, 423, 112, 704)
	var z := BOARD_Z
	# ---- PAUSED: push switches on a small bare FR4 board; RESUME the big one
	var pb := PackedVector2Array([Vector2(40, 116), Vector2(390, 116), Vector2(406, 132),
		Vector2(406, 378), Vector2(40, 378)])
	board(f, pb, FR4, z, [Vector2(54, 130), Vector2(392, 364)])
	tape(f, Vector2(58, 128), "PAUSED", z)
	var y := 170.0
	for i in (s["paused"] as Array).size():
		var label: String = s["paused"][i]
		var sz := 40.0 if i == 0 else 28.0
		var c := Vector2(62 + sz * 0.5, y + sz * 0.5)
		G.block(f, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), z, z + 0.008,
				G.mat(Color("#2e3032"), 0.5, 0.4))
		G.disc(f, c, sz * 0.32, z + 0.008, z + 0.018, G.unlit(Kit.SIGNAL) if i == 0
				else G.mat(HEADER, 0.1, 0.5), 20)
		if i == 0:
			kit.label(f, label, Vector2(62 + sz + 16, c.y - 12), 3, Color("#0f3b36"), z + 0.0008)
		else:
			kit.label(f, label, Vector2(62 + sz + 16, c.y - 8), 2, Color("#1b1a17"),
					z + 0.0008)
		y += sz + 22.0
	# ---- CAMPAIGN: a salvaged character display on paper phenolic -- the
	# rack's own stock -- where the rack's ribbon lands from round the corner
	var cb := PackedVector2Array([Vector2(40, 402), Vector2(406, 402), Vector2(406, 692),
		Vector2(66, 692), Vector2(40, 666)])
	board(f, cb, PHENOLIC, z, [Vector2(54, 416), Vector2(392, 678)])
	var camp: Array = s["campaign"]
	var lcd := Rect2(64, 424, 318, 22.0 * camp.size() + 22.0)
	G.block(f, lcd.grow(8), z, z + 0.01, G.mat(Color("#1d2021"), 0.2, 0.5))
	G.block(f, lcd, z + 0.01, z + 0.0106, G.mat(LCD, 0.0, 0.8))
	var ly := lcd.position.y + 11.0
	for line: String in camp:
		kit.label(f, kit.fit(line.to_upper(), 2, lcd.size.x - 20), Vector2(lcd.position.x + 10,
				ly), 2, LCD_INK, z + 0.012)
		ly += 22.0
	tape(f, Vector2(64, lcd.end.y + 16), "CAMPAIGN", z)
	ribbon(f, [Vector2(RUN_START, RIBBON_Y), Vector2(74, RIBBON_Y)], RIBBON_Z)
	header(f, Rect2(74, RIBBON_Y - 12, 12, 24))
	# ---- OPTIONS: black mask, the biggest board, notched where the old plate
	# is left bare for Epsilon
	var ob := PackedVector2Array([Vector2(440, 116), Vector2(1108, 116), Vector2(1132, 168),
		Vector2(1244, 168), Vector2(1244, 628), Vector2(1204, 668), Vector2(440, 668)])
	board(f, ob, BLACK_MASK, z, [Vector2(454, 130), Vector2(1094, 130), Vector2(1230, 182),
			Vector2(1190, 654), Vector2(454, 654)])
	# the joins: tinned bridges from PAUSED, and a short ribbon from CAMPAIGN
	bridge(f, Vector2(398, 200), Vector2(448, 200))
	bridge(f, Vector2(398, 330), Vector2(448, 330))
	header(f, Rect2(380, 616, 12, 24))
	header(f, Rect2(452, 616, 12, 24))
	ribbon(f, [Vector2(386, 628), Vector2(458, 628)], z + 0.014, 6.0)
	# ---- EPSILON: the harness's drop to this board runs through him
	_epsilon(f, ep)
	wire(f, [Vector2(ep.x, TRUNK_Y), Vector2(ep.x, ep.y - 30)], WIRE, 3.5)
	wire(f, [Vector2(ep.x - 6, ep.y + 30), Vector2(ep.x - 6, 176)], WIRE, 3.0)
	G.block(f, Rect2(ep.x - 26, 172, 40, 16), z, z + 0.012, G.mat(TERMINAL, 0.1, 0.5))
	# ---- the options: repurposed slide pots at their real defaults, each
	# value in a backlit window, each labelled on tape; the toggle a real
	# switch at its real state
	var x0 := 470.0
	var x1 := 1214.0
	y = 132.0
	tape(f, Vector2(x0, y), "OPTIONS", z)
	y += 46.0
	for sl: Array in s["sliders"]:
		tape(f, Vector2(x0, y), str(sl[0]), z)
		flag_window(f, Rect2(x1 - 96, y, 96, 24), str(sl[2]), LIT, z + 0.004)
		var pot := Rect2(x0, y + 34, x1 - x0, 16)
		G.block(f, pot, z, z + 0.008, G.mat(PLATE, 0.55, 0.45))
		G.block(f, Rect2(pot.position.x + 10, pot.get_center().y - 2, pot.size.x - 20, 4),
				z + 0.008, z + 0.0084, G.unlit(Color("#060606")), false)
		var kx := lerpf(pot.position.x + 16, pot.end.x - 16, float(sl[1]))
		G.block(f, Rect2(kx - 12, y + 30, 24, 24), z + 0.008, z + 0.026,
				G.mat(Color("#dadcd8"), 0.2, 0.5))
		y += 84.0
	for t: Array in s["toggles"]:
		tape(f, Vector2(x0, y), str(t[0]), z)
		var on := bool(t[1])
		flag_window(f, Rect2(x1 - 96, y, 96, 24), "ON" if on else "OFF", LIT, z + 0.004)
		var c := Vector2(x1 - 150, y + 12)
		G.block(f, Rect2(c - Vector2(16, 20), Vector2(32, 40)), z, z + 0.004,
				G.mat(PLATE, 0.55, 0.45))
		G.disc(f, c, 9, z + 0.004, z + 0.01, G.mat(Color("#8c9094"), 0.6, 0.35), 6)
		G.slab(f, G.rrect(Rect2(c.x - 3.5, c.y + (-22.0 if on else 2.0), 7, 20), 3),
				z + 0.01, z + 0.03, G.mat(Color("#c9ccce"), 0.7, 0.3))
		y += 60.0
