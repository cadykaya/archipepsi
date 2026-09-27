class_name MenuLink
extends Node3D
## THE LINK (the approved hybrid's, from `tools/menu_proto/thread.gd`,
## `5b03f6d`): a journal entry, joined to the passage (or place) it names on
## the Map -- along the HARNESS, round the PHYSICAL corner of the box (the
## hybrid's Journal -> Map treatment, the owner's rulings of 2026-09-27).
##
## It is an ivory wire. It leaves the focused entry's tag, rises in front of
## the trunk, is laced above it along the journal wall, rounds the corner
## post with the trunk, runs along above the Map's own run to over the
## place it names, and drops forward over the trunk into the Map's port.
## There the menu's own guide stroke carries it on: straight down to the
## passage, stopping just short of it so its mark stays in sight, with a
## terminus bar. The drop follows the lens every frame: pan, zoom or orbit
## the map and the link stays over its passage.
##
## * **Not a traversable route.** It is straight between its bends and
##   never follows a corridor's turns.
## * **Off the view**, the guide stops at the view's edge with an arrow
##   toward the place (overview -- C / Y -- brings it into the window).
## * Casting is an even pace (the wire is paid out from the tag, a
##   readable cast, not a two-frame ease); a new link rewinds the old one
##   first. Reduced motion: it is simply there.

const STROKE_PX := 6.0               # the menu's one stroke language
const CORNER_PX := 12.0
const END_GAP_PX := 22.0             # the guide stops this short of what it names
const UP_X := 1210.0                 # where the wire rises on the journal wall
const WIRE_R := 4.0
const TIE_EVERY := 88.0

var kit: MenuKit
var shell: MenuShell
var map_face: MapFace
var anchor := Vector2.INF            # the journal-wall end, page px (the tag)
var link := {}
var bead_spec := {}
var drawn := 0.0                     # 0..1, animated
var _wire: MeshInstance3D
var _ties: Node3D
var _line: MeshInstance3D
var _arrow: Sprite3D
var _path: Array = []                # the guide's points (world), as drawn
var _sig := ""
var _serial := 0
var _tube_len := 0.0
var _guide_len := 0.0
var _drop_x := -1.0


func setup(k: MenuKit, s: MenuShell) -> void:
	kit = k
	shell = s
	_wire = MeshInstance3D.new()
	_wire.material_override = MenuParts.mat(MenuParts.IVORY, 0.05, 0.55)
	add_child(_wire)
	_ties = Node3D.new()
	add_child(_ties)
	_line = MeshInstance3D.new()
	_line.material_override = _mat(MenuParts.IVORY, 4)
	add_child(_line)
	_arrow = Sprite3D.new()
	_arrow.pixel_size = MenuKit.px() * 3.0
	_arrow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_arrow.shaded = false
	_arrow.no_depth_test = true
	_arrow.render_priority = 5
	_arrow.modulate = MenuParts.IVORY
	_arrow.visible = false
	add_child(_arrow)


func _mat(colour: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.no_depth_test = true
	m.render_priority = priority
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A new pair of ends. The same link, moved (a scroll): the ends follow,
## nothing is recast. A different link: the old one rewinds, then the new
## one is cast -- and only the newest request is ever cast.
func bind_ends(at: Vector2, l: Dictionary, bead: Dictionary, m: MapFace) -> void:
	map_face = m
	if l == link and bead == bead_spec:
		_serial += 1
		anchor = at
		if drawn < 1.0 and not link.is_empty() and anchor != Vector2.INF:
			kit.go(self, "drawn", 1.0, 0.42 * (1.0 - drawn), "linear")
		return
	_serial += 1
	var mine := _serial
	if drawn > 0.001 and not link.is_empty():
		kit.go(self, "drawn", 0.0, 0.14, "in")
		kit.later(0.15, func() -> void:
			if mine == _serial:
				_take(at, l, bead))
		return
	_take(at, l, bead)


func _take(at: Vector2, l: Dictionary, bead: Dictionary) -> void:
	anchor = at
	link = l
	bead_spec = bead
	drawn = 0.0
	if link.is_empty() or anchor == Vector2.INF:
		return
	kit.go(self, "drawn", 1.0, 0.42, "linear")


## The wire's path (world), and the guide's (world), as the lens has the
## place now.
func _route() -> Dictionary:
	var jf: Node3D = shell.face_node("journal")
	var mf: Node3D = shell.face_node("map")
	var jt := jf.global_transform
	var mt := mf.global_transform
	var tz := 0.026
	var a := anchor
	var up := UP_X
	# ---- the journal wall: out of the tag, up in front of the trunk, and
	# laced above it to the corner
	var j: Array = MenuParts.smooth3([jt * MenuParts.P(a, tz), jt * MenuParts.P(a + Vector2(14, 0), tz),
		jt * MenuParts.P(Vector2(up, a.y - 8.0), 0.03),
		jt * MenuParts.P(Vector2(up, MenuParts.TRUNK_Y + 24), 0.036),
		jt * MenuParts.P(Vector2(up, MenuParts.TRUNK_Y), 0.044),
		jt * MenuParts.P(Vector2(up, MenuParts.LINK_Y + 14), 0.04),
		jt * MenuParts.P(Vector2(up + 10, MenuParts.LINK_Y + 1), MenuParts.LINK_Z + 0.004)], 6)
	j.append(jt * MenuParts.P(Vector2(MenuParts.RUN_END, MenuParts.LINK_Y), MenuParts.LINK_Z))
	# ---- round the corner post, with the trunk
	var c: Array = MenuParts.corner_points(jf, mf, MenuParts.LINK_Y, MenuParts.LINK_Z)
	# ---- the map wall: along above the run to over the place, then forward
	# over the trunk and down into the port
	var view: Rect2 = map_face.view_rect() if map_face != null else MapFace.WINDOW
	var t := map_face.target_world(link) if map_face != null else {}
	var p: Vector2 = t.get("page", view.get_center())
	var inside := bool(t.get("inside", false))
	var inner := view.grow(-14.0)
	var end := Vector2(p.x, p.y - END_GAP_PX) if inside else Vector2(clampf(p.x,
			inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
	var win := MapFace.WINDOW
	var tx := clampf(end.x, win.position.x + 40.0, win.end.x - 30.0)
	_drop_x = tx
	var mp: Array = [mt * MenuParts.P(Vector2(MenuParts.RUN_START, MenuParts.LINK_Y), MenuParts.LINK_Z)]
	if tx - 20.0 > MenuParts.RUN_START + 1.0:
		mp.append(mt * MenuParts.P(Vector2(tx - 20.0, MenuParts.LINK_Y), MenuParts.LINK_Z))
	mp += MenuParts.smooth3([mt * MenuParts.P(Vector2(tx - 6.0, MenuParts.LINK_Y + 2), MenuParts.LINK_Z
			+ 0.004), mt * MenuParts.P(Vector2(tx, MenuParts.LINK_Y + 14), 0.04),
		mt * MenuParts.P(Vector2(tx, MenuParts.TRUNK_Y), 0.044),
		mt * MenuParts.P(Vector2(tx, MenuParts.TRUNK_Y + 22), 0.036),
		mt * MenuParts.P(Vector2(tx, win.position.y - 4.0), 0.022)], 6)
	var wire: Array = j + c.slice(1) + mp.slice(1)
	# ---- in the port: the guide, straight down to just short of the place
	var start := Vector2(tx, win.position.y + 8.0)
	var guide: Array = [mt * MenuKit.at(start, 0.01)]
	if absf(end.x - tx) > 0.5:
		guide.append(mt * MenuKit.at(Vector2(tx, end.y), 0.01))
	guide.append(mt * MenuKit.at(end, 0.01))
	return {"wire": wire, "guide": guide, "inside": inside, "p": p, "end": end,
		"tx": tx}


func tick(_delta: float) -> void:
	if link.is_empty() or anchor == Vector2.INF or drawn <= 0.001 or map_face == null:
		_wire.visible = false
		_line.visible = false
		_arrow.visible = false
		_ties.visible = false
		_path = []
		return
	var r := _route()
	var sig := "%.2f/%.2f/%.1f/%.1f/%.1f/%.1f/%.4f" % [anchor.x, anchor.y, float(r["tx"]),
		(r["end"] as Vector2).x, (r["end"] as Vector2).y, 1.0 if r["inside"] else 0.0,
		drawn]
	if sig == _sig:
		return
	_sig = sig
	var wire: Array = r["wire"]
	var guide: Array = _corners(r["guide"], CORNER_PX * MenuKit.px())
	_tube_len = _length(wire)
	_guide_len = _length(guide)
	var left := (_tube_len + _guide_len) * drawn
	var wire_pts := _cut(wire, left)
	_wire.visible = wire_pts.size() >= 2
	if _wire.visible:
		_wire.mesh = MenuParts.tube_mesh(wire_pts, WIRE_R, 12, MenuParts.LINK_Z)
	var guide_pts := _cut(guide, left - _tube_len) if left > _tube_len else []
	_line.visible = guide_pts.size() >= 2
	if _line.visible:
		_line.mesh = _stroke(guide_pts, STROKE_PX, drawn >= 0.999 and bool(r["inside"]))
	_path = guide_pts
	_lace(float(r["tx"]), drawn >= 0.999)
	# Off the view: the guide stops inside the view's edge, pointing on.
	_arrow.visible = false
	if not bool(r["inside"]) and drawn >= 0.999:
		var d: Vector2 = (r["p"] as Vector2) - (r["end"] as Vector2)
		var icon := "arrow_right"
		if absf(d.y) > absf(d.x):
			icon = "arrow_down" if d.y > 0 else "arrow_up"
		elif d.x < 0:
			icon = "arrow_left"
		_arrow.texture = kit.icons[icon]
		var mt := shell.face_node("map").global_transform
		_arrow.global_transform = Transform3D(mt.basis, mt * MenuKit.at(r["end"], 0.012))
		_arrow.visible = true


## Lacing ties along the wire's run above the Map's trunk, once it is laid.
var _laced := -1.0


func _lace(tx: float, laid: bool) -> void:
	_ties.visible = laid
	if not laid or absf(tx - _laced) < 0.5:
		return
	_laced = tx
	for n: Node in _ties.get_children():
		n.queue_free()
	var mf: Node3D = shell.face_node("map")
	var holder := Node3D.new()
	_ties.add_child(holder)
	holder.transform = mf.global_transform
	var x := MenuParts.RUN_START + 30.0
	while x < tx - 40.0:
		MenuParts.tie(holder, Vector2(x, MenuParts.LINK_Y), false, WIRE_R, MenuParts.LINK_Z)
		x += TIE_EVERY
	# where it goes into the port: a metal grommet on the port's frame
	MenuParts.block(holder, Rect2(tx - 7, MapFace.WINDOW.position.y - 14, 14, 16), 0.016, 0.03,
			MenuParts.mat(MenuParts.METAL, 0.6, 0.35))


static func _length(pts: Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector3).distance_to(pts[i + 1])
	return total


## The path as far as `left` (world units) along it.
static func _cut(pts: Array, left: float) -> Array:
	if pts.is_empty() or left <= 0.0:
		return []
	var out: Array = [pts[0]]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := a.distance_to(b)
		if left >= seg:
			out.append(b)
			left -= seg
		else:
			out.append(a.lerp(b, left / maxf(seg, 0.00001)))
			break
	return out


## Every turn cut at 45 degrees: `c` back along both runs (world units).
static func _corners(path: Array, c: float) -> Array:
	var pts: Array = []
	for p: Vector3 in path:
		if pts.is_empty() or (pts[-1] as Vector3).distance_to(p) > 0.00001:
			pts.append(p)
	if pts.size() < 3:
		return pts
	var out: Array = [pts[0]]
	for i in range(1, pts.size() - 1):
		var a: Vector3 = pts[i - 1]
		var p: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d1 := (p - a).normalized()
		var d2 := (b - p).normalized()
		if d1.dot(d2) > 0.9999:
			continue
		var cut := minf(c * p.length(), minf(a.distance_to(p), p.distance_to(b)) * 0.5)
		out.append(p - d1 * cut)
		out.append(p + d2 * cut)
	out.append(pts[-1])
	return out


## The stroke: a strip facing the eye (at the origin), mitred at every join
## and scaled by distance, so it is `px` page px wide AS SEEN wherever it
## runs. `cap`: the terminus bar across its end.
static func _stroke(pts: Array, px: float, cap: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var n := pts.size()
	if n < 2:
		return mesh
	var half := px * MenuKit.px() * 0.5 / MenuKit.DISTANCE
	var sides: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var view := -p.normalized()
		var s_in := Vector3.ZERO
		var s_out := Vector3.ZERO
		if i > 0:
			s_in = (p - (pts[i - 1] as Vector3)).cross(view).normalized()
		if i < n - 1:
			s_out = ((pts[i + 1] as Vector3) - p).cross(view).normalized()
		var m := s_in + s_out
		if m.length() < 0.001:
			m = s_in if s_in != Vector3.ZERO else s_out
		m = m.normalized()
		var ref := s_in if s_in != Vector3.ZERO else s_out
		var k := 1.0 / maxf(0.3, m.dot(ref))
		var off := m * half * p.length() * k
		sides.append([p - off, p + off])
	var verts := PackedVector3Array()
	for i in n - 1:
		var l0: Vector3 = sides[i][0]
		var r0: Vector3 = sides[i][1]
		var l1: Vector3 = sides[i + 1][0]
		var r1: Vector3 = sides[i + 1][1]
		for v: Vector3 in [l0, r0, r1, l0, r1, l1]:
			verts.append(v)
	if cap:
		var e: Vector3 = pts[-1]
		var d := (e - (pts[-2] as Vector3)).normalized()
		var across := d.cross(-e.normalized()).normalized() * half * e.length() * 3.0
		var along := d * half * e.length()
		var q := [e - across - along, e + across - along, e + across + along,
			e - across + along]
		for v: Vector3 in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			verts.append(v)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func state() -> Dictionary:
	var t := map_face.target_world(link) if map_face != null and not link.is_empty() \
			else {}
	return {"link": link.duplicate(), "drawn": snappedf(drawn, 0.001),
		"arrow": _arrow.visible,
		# the flat guide drawn for it in the port: one stroke, no casing
		"strokes": 1 if _line.visible else 0,
		"wire": _wire.visible, "drop_x": snappedf(_drop_x, 0.1),
		"inside": bool(t.get("inside", false)) if not t.is_empty() else false,
		"end": [snappedf((_path[-1] as Vector3).x, 0.0001),
			snappedf((_path[-1] as Vector3).y, 0.0001),
			snappedf((_path[-1] as Vector3).z, 0.0001)] if not _path.is_empty() else []}
