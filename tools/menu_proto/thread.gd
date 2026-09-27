class_name Thread3D
extends Node3D
## THE THREAD: a journal entry, joined to the passage (or place) it names on
## the Map -- round the PHYSICAL corner of the box.
##
## It leaves the entry's loose end, runs along the journal wall to the
## corner post, wraps the post's two inner faces, runs the short way along
## the map wall to the window's edge, and goes in through the window to
## land on the thing itself in the miniature. The last point follows the
## lens every frame: pan, zoom or orbit the map and the thread stays on
## its passage.
##
## * **One deliberate guide.** The menu's own stroke -- the inventory's
##   route: one solid line of ink, 6 px as seen from the eye wherever it
##   runs, every turn cut at 45 degrees, mitred, and a terminus bar where it
##   stops, just short of what it names so that mark stays in sight. No
##   casing, no second line.
## * **Not a traversable route.** It is straight between its corners and
##   never follows a corridor's turns. A route in the model is a coloured
##   band; this is a line in the room.
## * **Off the view**, it stops at the window's edge with an arrow toward
##   the place (overview -- C / Y -- brings it into the window).
## * Casting is an even pace (the visible run is a readable cast, not a
##   two-frame ease); a new link rewinds the old one first. Reduced motion:
##   it is simply there.

const LIFT := 0.010
const STROKE_PX := 6.0               # FaceEquipment.STROKE: one stroke language
const CORNER_PX := 12.0              # the 45-degree corners, as seen
const END_GAP_PX := 16.0             # it stops this short of what it names
const POST := 0.8727                 # the post's inner faces (world)
const MARGIN := 0.006

var kit: Kit
var shell: Shell
var map_face: FaceMap
var anchor := Vector2.INF            # the journal-wall end, page px
var link := {}
var bead_spec := {}
var drawn := 0.0                     # 0..1, animated
var _line: MeshInstance3D
var _bead: Node3D
var _arrow: Sprite3D
var _path: Array = []
var _last := {}


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	_line = MeshInstance3D.new()
	_line.material_override = _mat(Kit.INK, 4)
	add_child(_line)
	_arrow = Sprite3D.new()
	_arrow.pixel_size = Kit.px() * 2.0
	_arrow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_arrow.shaded = false
	_arrow.no_depth_test = true
	_arrow.render_priority = 5
	_arrow.modulate = Kit.INK
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
## nothing is recast. A different link: the old thread rewinds, then the
## new one is cast -- and only the newest request is ever cast.
func bind_ends(at: Vector2, l: Dictionary, bead: Dictionary, m: FaceMap) -> void:
	map_face = m
	if l == link and bead == bead_spec:
		# Back to the link already drawn (or being rewound): cancel any
		# recast queued for a link since left, and finish this one.
		_serial += 1
		if at != anchor:
			anchor = at
			_build_bead()
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


var _serial := 0


func _take(at: Vector2, l: Dictionary, bead: Dictionary) -> void:
	anchor = at
	link = l
	bead_spec = bead
	_build_bead()
	if link.is_empty() or anchor == Vector2.INF:
		drawn = 0.0
		return
	drawn = 0.0
	kit.go(self, "drawn", 1.0, 0.42, "linear")


func _build_bead() -> void:
	if _bead != null:
		_bead.queue_free()
		_bead = null
	if bead_spec.is_empty() or anchor == Vector2.INF:
		return
	var jf: Node3D = shell.face_of("journal")
	_bead = Node3D.new()
	jf.add_child(_bead)
	var at := Vector2(1242, anchor.y)
	kit.card(_bead, at - Vector2(15, 15), Vector2(30, 30), LIFT + 0.002,
			kit.flat(Kit.WALL))
	kit.sprite(_bead, str(bead_spec["icon"]), at, 2, bead_spec["colour"],
			LIFT + 0.003)


## The path, rebuilt every frame: the map end moves with the lens.
func _route() -> Array:
	var jf: Node3D = shell.face_of("journal")
	var mf: Node3D = shell.face_of("map")
	var a: Vector3 = jf.global_transform * Kit.at(anchor, LIFT)
	var y := a.y
	var pts: Array = [a,
		Vector3(1.0 - LIFT, y, POST - MARGIN),
		Vector3(POST - MARGIN, y, POST - MARGIN),
		Vector3(POST - MARGIN, y, 1.0 - LIFT)]
	var page_y := Kit.PAGE.y * 0.5 - y / Kit.px()
	var win := FaceMap.WINDOW
	# Round the post and onto the map wall, then down (or up) the margin
	# beside the window, and in at the height of what it names -- straight
	# runs and 45-degree corners, like every route in the menu.
	var margin_x := win.position.x - 14.0
	pts.append(mf.global_transform * Kit.at(Vector2(margin_x, page_y), LIFT))
	var t := map_face.target_world(link) if map_face != null else {}
	_arrow.visible = false
	if t.is_empty():
		return pts
	var p: Vector2 = t["page"]
	var inside := bool(t["inside"])
	var end := p if inside else Vector2(
			clampf(p.x, win.position.x + 14, win.end.x - 14),
			clampf(p.y, win.position.y + 14, win.end.y - 14))
	pts.append(mf.global_transform * Kit.at(Vector2(margin_x, end.y), LIFT))
	pts.append(mf.global_transform * Kit.at(end, LIFT))
	if not inside:
		# Off the view: it stops inside the window's edge, pointing at it.
		var d := p - end
		var icon := "arrow_right"
		if absf(d.y) > absf(d.x):
			icon = "arrow_down" if d.y > 0 else "arrow_up"
		elif d.x < 0:
			icon = "arrow_left"
		_arrow.texture = kit.icons[icon]
		# At the thread's end, a size up from the wall's symbols: the arrow is
		# the end of the line, pointing the rest of the way.
		_arrow.pixel_size = Kit.px() * 3.0
		_arrow.global_transform = Transform3D(mf.global_transform.basis,
				mf.global_transform * Kit.at(end, LIFT + 0.002))
		_arrow.visible = drawn >= 0.999
	return pts


func tick(_delta: float) -> void:
	if link.is_empty() or anchor == Vector2.INF or drawn <= 0.001:
		_line.visible = false
		_arrow.visible = false
		if _bead != null:
			_bead.visible = false
		return
	_path = _route()
	# The stroke's corners are cut first, then it stops short of its end,
	# then it is drawn as far as it has been cast.
	var full := _corners(_path, CORNER_PX * Kit.px())
	var reaches := map_face != null and bool(map_face.target_world(link).get(
			"inside", false))
	# It stops just short of what it names, so that mark stays in sight; off
	# the view it stops short of its arrow, at the window's edge.
	full = _trim_end(full, (END_GAP_PX if reaches else 20.0) * Kit.px()
			* (full[-1] as Vector3).length())
	var total := 0.0
	for i in full.size() - 1:
		total += (full[i] as Vector3).distance_to(full[i + 1])
	var left := total * drawn
	var pts: Array = [full[0]]
	for i in full.size() - 1:
		var a: Vector3 = full[i]
		var b: Vector3 = full[i + 1]
		var seg := a.distance_to(b)
		if left >= seg:
			pts.append(b)
			left -= seg
		else:
			pts.append(a.lerp(b, left / maxf(seg, 0.00001)))
			break
	_line.visible = true
	_line.mesh = _stroke(pts, STROKE_PX, drawn >= 0.999 and reaches)
	if _bead != null:
		_bead.visible = true
	_last = {"points": pts.size(), "drawn": drawn}


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


## The path, less its last `gap` (world units): the stroke stops short.
static func _trim_end(pts: Array, gap: float) -> Array:
	var out := pts.duplicate()
	while out.size() >= 2 and gap > 0.0:
		var a: Vector3 = out[-2]
		var b: Vector3 = out[-1]
		var seg := a.distance_to(b)
		if seg > gap:
			out[-1] = b.lerp(a, gap / seg)
			return out
		gap -= seg
		out.pop_back()
	return out


## The stroke: a strip facing the eye (at the origin), mitred at every join
## and scaled by distance, so it is `px` page px wide AS SEEN wherever it
## runs -- on a wall, round the post, or into the miniature. `cap`: the
## terminus bar across its end.
static func _stroke(pts: Array, px: float, cap: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var n := pts.size()
	if n < 2:
		return mesh
	var half := px * Kit.px() * 0.5 / Kit.DISTANCE
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
		# The terminus: a bar across the end, three strokes long.
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
	var strokes := 0
	for c: Node in get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			strokes += 1
	return {"link": link.duplicate(), "drawn": snappedf(drawn, 0.001),
		"arrow": _arrow.visible,
		# how many lines are drawn for it: one stroke, no casing
		"strokes": strokes,
		"inside": bool(t.get("inside", false)) if not t.is_empty() else false,
		"end": [snappedf((_path[-1] as Vector3).x, 0.0001),
			snappedf((_path[-1] as Vector3).y, 0.0001),
			snappedf((_path[-1] as Vector3).z, 0.0001)] if not _path.is_empty() else []}
