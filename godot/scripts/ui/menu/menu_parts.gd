class_name MenuParts
extends RefCounted
## THE MENU'S PARTS (the approved hybrid, carried over from the art lane's
## prototype `tools/menu_proto/parts.gd` at `5b03f6d`): the one machine the box is, built from three kinds of
## hardware (the owner's rulings of 2026-09-27, the fourth and fifth):
##
## * ORIGINAL STATION HARDWARE -- the enamel enclosure, Equipment's cabinet
##   (its inspection window, its key selector, its brass bus), the Map's
##   port. Formal, square, riveted.
## * THE HARNESS -- one laced trunk round every wall and corner: the walls'
##   titles are flag labels on it, the warm tags hang from it, the
##   Journal's ivory link runs along it into the Map.
## * SALVAGED ELECTRONICS -- Equipment's rebuilt item rack and Settings'
##   boards: paper phenolic, black mask, bare FR4, brass standoffs. Never
##   green: the Style Lock keeps green for Epsilon alone (ART_BIBLE §1a).
##
## Everything here is placed SEEN AT PAGE: a thing `z` off the wall is drawn
## at MenuKit.lifted(page, z) and scaled by MenuKit.lift_scale(z), so its FRONT is
## seen exactly where its page coordinates say. That is what keeps a click
## on what the eye sees -- the wall's hit test is in page px -- while the
## parts keep their real depth: their sides, their shadows, and the
## parallax of a turn.
##
## Godot takes CLOCKWISE triangles as front faces; `_tri` winds every
## triangle to face its own normal, so the light is right whichever way a
## shape was traced.

# ---- the original enclosure
const CAB := Color("#2b2e31")
const CAB_HI := Color("#373b3f")
const RECESS := Color("#0c0e0f")
const RIVET := Color("#8c9094")
const BRASS := Color("#b08f52")
const BAKELITE := Color("#1a1512")
const LIT := Color("#f1ebdb")            # backlit words: what something IS
const LIT_DIM := Color("#c4bdad")        # (lifted at the fifth ruling)
const LIT_FAINT := Color("#978f80")
const INK := Color("#e0e3e4")            # words on the enamel
const DIM := Color("#b3b8bd")            # (lifted at the fifth ruling)
const FAINT := Color("#80868c")
# ---- the harness
const LOOM := Color("#141619")
const LACE := Color("#b09863")
const WIRE := Color("#666d74")
const IVORY := Color("#eadcb8")
const FLAG := Color("#b0aa96")
const FLAG_INK := Color("#1b1c1e")
const TAG_DIM := Color("#4f4b43")
const TAG_FAINT := Color("#6f695d")
const METAL := Color("#a3a8ab")
# ---- the salvage
const PHENOLIC := Color("#6b5232")
const BLACK_MASK := Color("#1b1d1d")
const FR4 := Color("#968c68")
const MODULE := Color("#171919")
const EDGE := Color("#8f8665")
const GOLD := Color("#c8a24c")
const TIN := Color("#b9bec2")
const HEADER := Color("#121314")
const TERMINAL := Color("#2c3034")
const SILK := Color("#ebebe7")
const SILK_DIM := Color("#c2c2bd")
const SILK_FAINT := Color("#8e8e89")
const RIBBON := Color("#8d9196")
const PLATE := Color("#7f8488")
const TAPE := Color("#d6d2c6")
const TAPE_INK := Color("#161616")
const LCD := Color("#a9aaa5")
const LCD_INK := Color("#1d1e1c")
const ACT := Color("#1d3a37")            # a control that acts: its body
# ---- Epsilon
const IDENTITY := Color("#57ff1f")
const IDENTITY_SEAM := Color("#339612")
const HOST := Color("#5b6065")
const PLATING := Color("#101211")

# ---- the harness's own numbers, the same on every wall
const TRUNK_Y := 40.0
const TRUNK_Z := 0.022
const TRUNK_R := 10.0
const LINK_Y := 16.0                     # the Journal's link, laced above it
const LINK_Z := 0.02
const WIRE_Z := 0.016
const RUN_START := 40.0                  # a wall's run meets its corners here
const RUN_END := 1240.0
const POST := 0.8727                     # the corner posts' inner faces (world)
const RIBBON_Y := 650.0                  # the rack's ribbon, Equipment -> Settings
const RIBBON_Z := 0.02

static var _mats := {}


# ============================================================ placing

## A page point `z` off the wall, placed so it is SEEN at `page`.
static func P(page: Vector2, z: float) -> Vector3:
	return MenuKit.at(MenuKit.lifted(page, z), z)


static func k(z: float) -> float:
	return MenuKit.lift_scale(z)


# ============================================================ materials

static func mat(colour: Color, metal := 0.0, rough := 1.0) -> StandardMaterial3D:
	var key := "m%s/%.2f/%.2f" % [colour.to_html(), metal, rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.metallic = metal
		m.roughness = rough
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func unlit(colour: Color) -> StandardMaterial3D:
	var key := "u%s" % colour.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = colour
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## A material of its own, for a part whose colour is animated.
static func own(colour: Color, lit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not lit:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# ============================================================ primitives

static func _node(parent: Node3D, mesh: Mesh, material: Material,
		shadow := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


## A box over a page rect, from depth z0 to z1, its front seen at `rect`.
static func block(parent: Node3D, rect: Rect2, z0: float, z1: float,
		material: Material, shadow := true) -> MeshInstance3D:
	var s := k(z1)
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x * MenuKit.px() * s, rect.size.y * MenuKit.px() * s,
			maxf(z1 - z0, 0.0005))
	var n := _node(parent, box, material, shadow)
	var c := MenuKit.lifted(rect.get_center(), z1)
	n.position = MenuKit.at(c, (z0 + z1) * 0.5)
	return n


## A cylinder whose axis points at the eye: a knob, a stud, a lamp.
static func disc(parent: Node3D, centre: Vector2, r_px: float, z0: float, z1: float,
		material: Material, sides := 28, shadow := true) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_px * MenuKit.px() * k(z1)
	c.bottom_radius = c.top_radius
	c.height = maxf(z1 - z0, 0.0005)
	c.radial_segments = sides
	c.rings = 1
	var n := _node(parent, c, material, shadow)
	n.rotation = Vector3(PI * 0.5, 0, 0)
	n.position = MenuKit.at(MenuKit.lifted(centre, z1), (z0 + z1) * 0.5)
	return n


## A ring facing the eye (a bezel, a grommet).
static func ring(parent: Node3D, centre: Vector2, r_in: float, r_out: float,
		z: float, material: Material, shadow := true) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in * MenuKit.px() * k(z)
	t.outer_radius = r_out * MenuKit.px() * k(z)
	t.rings = 32
	t.ring_segments = 10
	var n := _node(parent, t, material, shadow)
	n.rotation = Vector3(PI * 0.5, 0, 0)
	n.position = P(centre, z)
	return n


## A short cylinder round a cable: a band, a sleeve, a lacing tie.
static func sleeve(parent: Node3D, centre: Vector2, vertical: bool, r_px: float,
		len_px: float, z: float, material: Material, sides := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_px * MenuKit.px() * k(z)
	c.bottom_radius = c.top_radius
	c.height = len_px * MenuKit.px() * k(z)
	c.radial_segments = sides
	c.rings = 1
	var n := _node(parent, c, material)
	if not vertical:
		n.rotation = Vector3(0, 0, PI * 0.5)
	n.position = P(centre, z)
	return n


## A flat page polygon extruded from z0 to z1 (a board, a tab, a plate),
## its front face seen at `poly`.
static func slab(parent: Node3D, poly: PackedVector2Array, z0: float, z1: float,
		material: Material, shadow := true) -> MeshInstance3D:
	var s := MenuKit.px()
	var front := PackedVector2Array()
	for p in poly:
		front.append(MenuKit.lifted(p, z1))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := Geometry2D.triangulate_polygon(front)
	var fz := -MenuKit.DISTANCE + z1
	for i in range(0, idx.size(), 3):
		var tri := [front[idx[i]], front[idx[i + 1]], front[idx[i + 2]]]
		var v := []
		for p: Vector2 in tri:
			v.append(Vector3((p.x - MenuKit.PAGE.x * 0.5) * s, (MenuKit.PAGE.y * 0.5 - p.y) * s, fz))
		_tri(verts, norms, v[0], v[1], v[2], Vector3(0, 0, 1))
	var bz := -MenuKit.DISTANCE + z0
	var area := _area(front)
	for i in front.size():
		var a := front[i]
		var b := front[(i + 1) % front.size()]
		var a3 := Vector3((a.x - MenuKit.PAGE.x * 0.5) * s, (MenuKit.PAGE.y * 0.5 - a.y) * s, fz)
		var b3 := Vector3((b.x - MenuKit.PAGE.x * 0.5) * s, (MenuKit.PAGE.y * 0.5 - b.y) * s, fz)
		var a0 := Vector3(a3.x, a3.y, bz)
		var b0 := Vector3(b3.x, b3.y, bz)
		var e := (b3 - a3).normalized()
		var nrm := Vector3(e.y, -e.x, 0.0) if area > 0.0 else Vector3(-e.y, e.x, 0.0)
		_tri(verts, norms, a3, b3, b0, nrm)
		_tri(verts, norms, a3, b0, a0, nrm)
	return _node(parent, _mesh(verts, norms), material, shadow)


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## A tube through face-local points (already placed, e.g. by `run`),
## `r_px` page px thick at depth `z_ref`: a cable. Frames are carried along
## the path (parallel transport), so it never twists.
static func tube(parent: Node3D, pts: Array, r_px: float, material: Material,
		sides := 10, shadow := true, z_ref := 0.02) -> MeshInstance3D:
	return _node(parent, tube_mesh(pts, r_px, sides, z_ref), material, shadow)


## The tube's mesh alone, for a cable that is re-laid as it moves.
static func tube_mesh(pts: Array, r_px: float, sides := 10, z_ref := 0.02) -> ArrayMesh:
	var r := r_px * MenuKit.px() * k(z_ref)
	var path: Array = []
	for p: Vector3 in pts:
		if path.is_empty() or (path[-1] as Vector3).distance_to(p) > 0.00005:
			path.append(p)
	if path.size() < 2:
		return ArrayMesh.new()
	var rings: Array = []
	var t0 := ((path[1] as Vector3) - (path[0] as Vector3)).normalized()
	var ref := Vector3(0, 0, 1) if absf(t0.z) < 0.9 else Vector3(0, 1, 0)
	var nrm := t0.cross(ref).normalized()
	for i in path.size():
		var t: Vector3
		if i == 0:
			t = t0
		elif i == path.size() - 1:
			t = ((path[i] as Vector3) - (path[i - 1] as Vector3)).normalized()
		else:
			t = ((path[i + 1] as Vector3) - (path[i - 1] as Vector3)).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm).normalized()
		var ringv: Array = []
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ringv.append(nrm * cos(a) + bin * sin(a))
		rings.append(ringv)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in path.size() - 1:
		var p0: Vector3 = path[i]
		var p1: Vector3 = path[i + 1]
		for s in sides:
			var s2 := (s + 1) % sides
			var n00: Vector3 = rings[i][s]
			var n01: Vector3 = rings[i][s2]
			var n10: Vector3 = rings[i + 1][s]
			var n11: Vector3 = rings[i + 1][s2]
			_tri_n(verts, norms, [p0 + n00 * r, p1 + n10 * r, p1 + n11 * r],
					[n00, n10, n11])
			_tri_n(verts, norms, [p0 + n00 * r, p1 + n11 * r, p0 + n01 * r],
					[n00, n11, n01])
	return _mesh(verts, norms)


## An orthogonal run through page points at depth `z`, with a round bend of
## `radius` px at every corner -- how a harness is laid, never a kink.
static func run(page: Array, radius: float, z: float, per := 7) -> Array:
	var out: Array = [P(page[0], z)]
	for i in range(1, page.size() - 1):
		var a: Vector2 = page[i - 1]
		var p: Vector2 = page[i]
		var b: Vector2 = page[i + 1]
		var d1 := (p - a).normalized()
		var d2 := (b - p).normalized()
		var r := minf(radius, minf(a.distance_to(p), p.distance_to(b)) * 0.5)
		var s := p - d1 * r
		var e := p + d2 * r
		for kk in per + 1:
			var t := float(kk) / float(per)
			out.append(P(s.lerp(p, t).lerp(p.lerp(e, t), t), z))
	out.append(P(page[-1], z))
	return out


## A smooth path through face-local (or world) points (Catmull-Rom).
static func smooth3(pts: Array, per := 8) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for kk in per:
			var t := float(kk) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[-1])
	return out


## `run` for face-local or world points: every corner a round bend.
static func bends(pts: Array, radius: float, per := 6) -> Array:
	var out: Array = [pts[0]]
	for i in range(1, pts.size() - 1):
		var a: Vector3 = pts[i - 1]
		var p: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var r := minf(radius, minf(a.distance_to(p), p.distance_to(b)) * 0.5)
		var s := p - (p - a).normalized() * r
		var e := p + (b - p).normalized() * r
		for kk in per + 1:
			var t := float(kk) / float(per)
			out.append(s.lerp(p, t).lerp(p.lerp(e, t), t))
	out.append(pts[-1])
	return out


static func rrect(r: Rect2, rad: float, seg := 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad,
			r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad),
			Vector2(r.position.x + rad, r.position.y + rad)]
	var a0 := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for i in seg + 1:
			var a: float = a0[c] + PI * 0.5 * float(i) / float(seg)
			out.append(cs[c] + Vector2(cos(a), sin(a)) * rad)
	return out


static func _tri(verts: PackedVector3Array, norms: PackedVector3Array, a: Vector3,
		b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts.append_array([a, c, b])
	else:
		verts.append_array([a, b, c])
	norms.append_array([n, n, n])


static func _tri_n(verts: PackedVector3Array, norms: PackedVector3Array,
		v: Array, n: Array) -> void:
	var avg: Vector3 = (n[0] as Vector3) + (n[1] as Vector3) + (n[2] as Vector3)
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	if (b - a).cross(c - a).dot(avg) > 0.0:
		verts.append_array([a, c, b])
		norms.append_array([n[0], n[2], n[1]])
	else:
		verts.append_array([a, b, c])
		norms.append_array([n[0], n[1], n[2]])


static func _mesh(verts: PackedVector3Array, norms: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ============================================================ words

## Words SEEN at `page`, `z` off the wall -- the size they say, wherever
## they stand. Their own scale is recorded, so a squash test tells a word
## drawn small on purpose from one squashed.
static func text(kit: MenuKit, parent: Node3D, s: String, page: Vector2, kk: int,
		colour: Color, z := 0.003, numerals := false) -> Label3D:
	var l := kit.label(parent, s, MenuKit.lifted(page, z), kk, colour, z, numerals)
	l.scale = Vector3.ONE * k(z)
	l.set_meta("own_scale", k(z))
	return l


static func sprite(kit: MenuKit, parent: Node3D, icon: String, page: Vector2, kk: int,
		colour: Color, z := 0.004) -> Sprite3D:
	var s := kit.sprite(parent, icon, MenuKit.lifted(page, z), kk, colour, z)
	s.scale = Vector3.ONE * k(z)
	s.set_meta("own_scale", k(z))
	return s


## The Glyph keycap, as the prototype draws one, SEEN at `at`; for a mouse
## button its device symbol too. Returns its width.
const MOUSE_SYMBOL := {"RMB": "mouse_right", "MMB": "mouse_middle", "LMB": "mouse_left"}


static func keycap(kit: MenuKit, parent: Node3D, cap: String, at: Vector2, z := 0.002) -> float:
	var up := cap.to_upper()
	var w := maxf(40.0, kit.measure(up, 2) + 16.0)
	if MOUSE_SYMBOL.has(up):
		w = 66.0
	block(parent, Rect2(at, Vector2(w, 26)), z, z + 0.004, mat(Color("#c9d0db"), 0.0, 0.8))
	if MOUSE_SYMBOL.has(up):
		sprite(kit, parent, MOUSE_SYMBOL[up], at + Vector2(14, 13), 2, MenuKit.SHADE, z + 0.0055)
		text(kit, parent, up, at + Vector2(28, 5), 2, MenuKit.SHADE, z + 0.0055)
	else:
		text(kit, parent, up, at + Vector2(8, 5), 2, MenuKit.SHADE, z + 0.0055)
	return w


# ============================================================ the harness

static func tie(parent: Node3D, at: Vector2, vertical: bool, r: float, z: float) -> void:
	sleeve(parent, at, vertical, r + 1.1, 4.0, z, mat(LACE, 0.0, 0.8), 14)
	disc(parent, at, 2.4, z + r * MenuKit.px(), z + r * MenuKit.px() + 0.0025,
			mat(LACE.darkened(0.15), 0.0, 0.8), 10)


## A saddle clamp: the harness's own mounting, the same on every wall.
static func saddle(parent: Node3D, x: float, y := TRUNK_Y, r := TRUNK_R,
		z := TRUNK_Z) -> void:
	var m := mat(METAL, 0.6, 0.35)
	block(parent, Rect2(x - 8, y - r - 12, 16, 2 * r + 24), 0.0, 0.003, m)
	sleeve(parent, Vector2(x, y), false, r + 1.8, 12.0, z, m)
	for s: float in [-1.0, 1.0]:
		disc(parent, Vector2(x, y + s * (r + 7.0)), 3.2, 0.003, 0.0065,
				mat(Color("#70767a"), 0.6, 0.4), 12)


## The trunk's run across one wall, laced where nothing else holds it, held
## by saddle clamps at `clamps`; `clear` keeps the lacing off page-x spans.
static func trunk(parent: Node3D, clamps: Array, clear: Array) -> void:
	tube(parent, [P(Vector2(RUN_START, TRUNK_Y), TRUNK_Z),
			P(Vector2(RUN_END, TRUNK_Y), TRUNK_Z)], TRUNK_R, mat(LOOM, 0.1, 0.45), 16,
			true, TRUNK_Z)
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
			tie(parent, Vector2(x, TRUNK_Y), false, TRUNK_R, TRUNK_Z)
		x += 44.0
	for cx: float in clamps:
		saddle(parent, cx)


## A run round the corner post between wall `left` and the wall a right
## turn faces from it, at page height `y`, `lift` off the walls (up to
## 0.03): from page x RUN_END on the one to RUN_START on the other, round
## the post's two inner faces. Parented to `root` (the box, in world space).
static func corner(root: Node3D, left_face: Node3D, right_face: Node3D, y: float,
		r_px: float, material: Material, lift := 0.03) -> MeshInstance3D:
	return tube(root, corner_points(left_face, right_face, y, lift), r_px, material, 12,
			true, lift)


## The corner run's points (world), bends included.
static func corner_points(left_face: Node3D, right_face: Node3D, y: float,
		lift := 0.03) -> Array:
	var tl: Transform3D = left_face.global_transform
	var wy := P(Vector2(0, y), lift).y
	var pts := [tl * P(Vector2(RUN_END, y), lift),
		tl * Vector3(POST - lift, wy, -1.0 + lift),
		tl * Vector3(POST - lift, wy, -POST + lift),
		tl * Vector3(1.0 - lift, wy, -POST + lift),
		right_face.global_transform * P(Vector2(RUN_START, y), lift)]
	return bends(pts, 0.011, 6)


## A flag label on the trunk: every wall's title is one. Returns its rect.
static func flag(kit: MenuKit, parent: Node3D, x: float, words: String, kk: int,
		faint := "", shade := 1.0) -> Rect2:
	var pad := 12.0
	var w := kit.measure(words, kk) + pad * 2.0
	if faint != "":
		w += kit.measure(faint, kk) + 18.0
	var card := mat(tone(FLAG, shade), 0.0, 1.0)
	sleeve(parent, Vector2(x + w * 0.5, TRUNK_Y), false, TRUNK_R + 1.6, w, TRUNK_Z, card, 18)
	var r := Rect2(x, TRUNK_Y + TRUNK_R - 4.0, w, 8.0 * kk + 18.0)
	slab(parent, rrect(r, 3.0), TRUNK_Z - 0.0015, TRUNK_Z + 0.0015, card)
	text(kit, parent, words, Vector2(x + pad, r.position.y + 10.0), kk, FLAG_INK,
			TRUNK_Z + 0.0027)
	if faint != "":
		text(kit, parent, faint, Vector2(x + pad + kit.measure(words, kk) + 18.0,
				r.position.y + 10.0), kk, TAG_FAINT, TRUNK_Z + 0.0027)
	return r


## A flag label on a vertical run at `x`, sticking out to its right.
static func vflag(kit: MenuKit, parent: Node3D, x: float, y: float, words: String,
		shade := 1.0, r := 3.5, z := WIRE_Z) -> Rect2:
	var w := kit.measure(words, 2) + 22.0
	var h := 30.0
	var card := mat(tone(FLAG, shade), 0.0, 1.0)
	sleeve(parent, Vector2(x, y + h * 0.5), true, r + 1.6, h, z, card, 14)
	var rect := Rect2(x + r - 2.0, y, w + 2.0, h)
	slab(parent, rrect(rect, 3.0), z - 0.0012, z + 0.0012, card)
	text(kit, parent, words, Vector2(x + r + 9.0, y + 7.0), 2, FLAG_INK, z + 0.0024)
	return rect


## A warm hang tag, chamfered at the top; hung from the trunk by two
## strings, or (`eyelets` false) clipped to a run.
static func tag(parent: Node3D, r: Rect2, z := 0.03, eyelets := true, shade := 1.0) -> void:
	var ch := 16.0
	var poly := PackedVector2Array([r.position + Vector2(ch, 0),
		Vector2(r.end.x - ch, r.position.y), Vector2(r.end.x, r.position.y + ch), r.end,
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, ch)])
	slab(parent, poly, z - 0.004, z, mat(tone(FLAG, shade), 0.0, 1.0))
	if not eyelets:
		return
	for ex: float in [r.position.x + 38.0, r.end.x - 38.0]:
		var e := Vector2(ex, r.position.y + 15.0)
		ring(parent, e, 4.0, 7.5, z + 0.0004, mat(METAL, 0.6, 0.35))
		disc(parent, e, 4.0, z - 0.0042, z + 0.0002, unlit(Color("#0b0d0f")), 16, false)
		tube(parent, [P(Vector2(ex, TRUNK_Y + TRUNK_R - 2.0), TRUNK_Z + 0.004),
			P(Vector2(ex, (TRUNK_Y + e.y) * 0.5), (TRUNK_Z + z) * 0.5 + 0.004),
			P(e + Vector2(0, -2), z + 0.002)], 1.6, mat(LACE, 0.0, 0.8), 8)


static func wire(parent: Node3D, page: Array, colour: Color, r := 3.5, z := WIRE_Z,
		bend := 18.0) -> MeshInstance3D:
	return tube(parent, run(page, bend, z), r, mat(colour, 0.05, 0.55), 12, true, z)


## A flat ribbon: six conductors side by side along a routed page path,
## kept parallel through its bends.
static func ribbon(parent: Node3D, page: Array, z := RIBBON_Z, bend := 14.0) -> void:
	var grey := mat(RIBBON, 0.1, 0.6)
	var n := page.size()
	for kk in 6:
		var o := (float(kk) - 2.5) * 3.4
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
				var mid := (np + nn).normalized()
				off = mid / maxf(0.5, mid.dot(np))
			pts.append(p + off * o)
		tube(parent, run(pts, bend, z), 1.7, grey, 8, true, z)


# ============================================================ original hardware

static func rivet(parent: Node3D, at: Vector2, z: float) -> void:
	disc(parent, at, 3.4, z, z + 0.003, mat(RIVET, 0.6, 0.4), 12)


## A window cut into the enclosure: a raised, riveted frame round a dark
## recess.
static func window(parent: Node3D, r: Rect2, frame := 12.0, depth := 0.014,
		rivets := true) -> void:
	var m := mat(CAB_HI, 0.35, 0.5)
	for b: Rect2 in [Rect2(r.position.x - frame, r.position.y - frame, r.size.x + frame * 2,
				frame), Rect2(r.position.x - frame, r.end.y, r.size.x + frame * 2, frame),
			Rect2(r.position.x - frame, r.position.y, frame, r.size.y),
			Rect2(r.end.x, r.position.y, frame, r.size.y)]:
		block(parent, b, 0.0, depth, m)
	block(parent, r, 0.0, 0.0008, mat(RECESS, 0.0, 0.95), false)
	if rivets:
		for p: Vector2 in [r.position + Vector2(-frame * 0.5, -frame * 0.5),
				Vector2(r.end.x + frame * 0.5, r.position.y - frame * 0.5),
				Vector2(r.position.x - frame * 0.5, r.end.y + frame * 0.5),
				r.end + Vector2(frame, frame) * 0.5]:
			rivet(parent, p, depth)


## A backlit flag window: its word IS the state -- the same on original and
## salvaged parts.
static func flag_window(kit: MenuKit, parent: Node3D, r: Rect2, words: String,
		colour: Color, z := 0.004) -> Label3D:
	block(parent, r.grow(3.0), 0.0, z, mat(CAB_HI, 0.35, 0.5))
	block(parent, r, z, z + 0.0006, mat(RECESS, 0.0, 0.95), false)
	return text(kit, parent, kit.fit(words, 2, r.size.x - 14), Vector2(r.position.x + 8,
			r.position.y + (r.size.y - 16) * 0.5), 2, colour, z + 0.0018)


## A pointer wedge from `c` at angle `a` (radians, 0 = right, down is +),
## in a node of its own at `c` so it can turn.
static func pointer(parent: Node3D, c: Vector2, a: float, r0: float, r1: float,
		w: float, z0: float, z1: float, material: Material) -> MeshInstance3D:
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	return slab(parent, PackedVector2Array([c + d * r0 + n * w, c + d * r1 + n * w * 0.45,
			c + d * r1 - n * w * 0.45, c + d * r0 - n * w]), z0, z1, material)


## A seam between two of the enclosure's panels, riveted at its ends.
static func seam(parent: Node3D, x: float, y0: float, y1: float) -> void:
	block(parent, Rect2(x - 1, y0, 2, y1 - y0), 0.0, 0.0006, unlit(Color("#161819")), false)
	for y: float in [y0 + 10.0, y1 - 10.0]:
		rivet(parent, Vector2(x - 8, y), 0.0)
		rivet(parent, Vector2(x + 8, y), 0.0)


# ============================================================ the salvage

## A salvaged board: its mask inside its cut FR4 edge, on brass standoffs.
static func board(parent: Node3D, poly: PackedVector2Array, colour: Color,
		z := 0.014, posts: Array = [], shade := 1.0) -> void:
	slab(parent, poly, z - 0.004, z - 0.0008, mat(tone(EDGE, shade), 0.1, 0.7))
	slab(parent, _inset(poly, 2.5), z - 0.0008, z, mat(tone(colour, shade), 0.15, 0.6))
	for p: Vector2 in posts:
		standoff(parent, p, z)


## A brass hex standoff and its screw: how every salvaged part is mounted.
static func standoff(parent: Node3D, p: Vector2, z: float) -> void:
	disc(parent, p, 7.0, 0.0, z - 0.004, mat(BRASS, 0.6, 0.35), 6)
	disc(parent, p, 5.2, z, z + 0.004, mat(TIN, 0.6, 0.35), 16)
	disc(parent, p, 2.2, z + 0.004, z + 0.0046, unlit(Color("#0b0c0c")), 10, false)


static func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var grown := Geometry2D.offset_polygon(poly, -d)
	return grown[0] if not grown.is_empty() else poly


static func bridge(parent: Node3D, a: Vector2, b: Vector2, z := 0.014) -> void:
	var mid := (a + b) * 0.5
	tube(parent, [P(a, z + 0.001), P(mid, z + 0.006), P(b, z + 0.001)], 1.6,
			mat(TIN, 0.6, 0.35), 8, true, z)
	for p: Vector2 in [a, b]:
		disc(parent, p, 4.0, z, z + 0.0028, mat(TIN, 0.6, 0.35), 12)


static func header(parent: Node3D, r: Rect2, z := 0.014) -> void:
	block(parent, r, z, z + 0.01, mat(HEADER, 0.1, 0.5))
	var vertical := r.size.y > r.size.x
	var t := r.position.y + 7.0 if vertical else r.position.x + 7.0
	var end := r.end.y - 4.0 if vertical else r.end.x - 4.0
	while t < end:
		var c := Vector2(r.get_center().x, t) if vertical else Vector2(t, r.get_center().y)
		block(parent, Rect2(c - Vector2(1.5, 1.5), Vector2(3, 3)), z + 0.01, z + 0.0104,
				unlit(Color("#050505")), false)
		t += 9.0


## Embossed label tape, stuck on by hand. Returns its rect.
static func tape(kit: MenuKit, parent: Node3D, at: Vector2, words: String, z: float) -> Rect2:
	var r := Rect2(at, Vector2(kit.measure(words, 2) + 16.0, 24))
	block(parent, r, z, z + 0.0012, mat(TAPE, 0.1, 0.45))
	text(kit, parent, words, at + Vector2(8, 4), 2, TAPE_INK, z + 0.0024)
	return r


## A pale surface on the walls the miniature's light leaks onto (the
## renderer ignores a light's cull mask): toned so one card reads the same
## on every wall. `shade` is the wall's factor; 1.0 elsewhere.
static func tone(colour: Color, shade: float) -> Color:
	return Color(colour.r * shade, colour.g * shade, colour.b * shade)


# ============================================================ Epsilon

## EPSILON, once in the whole machine, in the Style Lock's own terms:
## near-black plating bursting through an ordinary bolted grey plate of the
## old enclosure (embedded, never placed); asymmetric; identity green only
## from INSIDE -- through the seams between the shards -- and one narrow
## aperture. Nothing is written on him: he is not a slot, a setting, a meter
## or a status light.
static func epsilon(parent: Node3D, c: Vector2) -> void:
	var host := Rect2(c - Vector2(50, 40), Vector2(100, 80))
	slab(parent, rrect(host, 3), 0.0, 0.006, mat(HOST, 0.4, 0.55))
	for p: Vector2 in [host.position + Vector2(8, 8), Vector2(host.end.x - 8,
			host.position.y + 8), Vector2(host.position.x + 8, host.end.y - 8),
			host.end - Vector2(8, 8)]:
		rivet(parent, p, 0.006)
	var hole := PackedVector2Array([c + Vector2(-32, -6), c + Vector2(-18, -26),
		c + Vector2(4, -28), c + Vector2(30, -16), c + Vector2(36, 8), c + Vector2(18, 28),
		c + Vector2(-8, 26), c + Vector2(-26, 16)])
	slab(parent, hole, 0.006, 0.0066, unlit(IDENTITY_SEAM), false)
	var plating := mat(PLATING, 0.35, 0.4)
	for shard: Array in [
			[[[-36, -8], [-18, -31], [2, -16], [-6, 6], [-30, 16]], 0.03],
			[[[5, -33], [35, -18], [41, 10], [16, 5], [8, -14]], 0.042],
			[[[-9, 11], [12, 9], [23, 33], [-8, 31], [-29, 21]], 0.024]]:
		var pts := PackedVector2Array()
		for q: Array in shard[0]:
			pts.append(c + Vector2(float(q[0]), float(q[1])))
		slab(parent, pts, 0.0066, float(shard[1]), plating)
	disc(parent, c + Vector2(20, -6), 5.0, 0.042, 0.046, mat(PLATING.lightened(0.1), 0.4,
			0.4), 16)
	disc(parent, c + Vector2(20, -6), 3.0, 0.046, 0.0466, unlit(IDENTITY), 16, false)
