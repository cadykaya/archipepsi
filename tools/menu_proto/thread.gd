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
## * **Not a route.** Ink, straight, 2 px, on a casing of the wall's own
##   colour that cuts a gap through whatever it crosses; it never follows a
##   corridor's turns. A route is a coloured band in the model; this is a
##   line in the room.
## * **Off the view**, it stops at the window's edge with an arrow toward
##   the place (overview -- C / Y -- brings it into the window).
## * Casting is an even pace (the visible run is a readable cast, not a
##   two-frame ease); a new link rewinds the old one first. Reduced motion:
##   it is simply there.

const LIFT := 0.010
const WIDTH := 2.0 * 0.00137935
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
var _casing: MeshInstance3D
var _bead: Node3D
var _arrow: Sprite3D
var _path: Array = []
var _last := {}


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	_casing = MeshInstance3D.new()
	_casing.material_override = _mat(Kit.WALL, 3)
	add_child(_casing)
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
		if at != anchor:
			anchor = at
			_build_bead()
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
	var edge := Vector2(win.position.x, clampf(page_y, win.position.y + 8,
			win.end.y - 8))
	pts.append(mf.global_transform * Kit.at(Vector2(win.position.x, page_y), LIFT))
	pts.append(mf.global_transform * Kit.at(edge, LIFT))
	var t := map_face.target_world(link) if map_face != null else {}
	_arrow.visible = false
	if t.is_empty():
		return pts
	if bool(t["inside"]):
		pts.append(t["world"])
	else:
		# Off the view: stop at the window's edge, pointing at it.
		var p: Vector2 = t["page"]
		var clamped := Vector2(clampf(p.x, win.position.x + 14, win.end.x - 14),
				clampf(p.y, win.position.y + 14, win.end.y - 14))
		pts.append(mf.global_transform * Kit.at(clamped, LIFT))
		var d := p - clamped
		var icon := "arrow_right"
		if absf(d.y) > absf(d.x):
			icon = "arrow_down" if d.y > 0 else "arrow_up"
		elif d.x < 0:
			icon = "arrow_left"
		_arrow.texture = kit.icons[icon]
		_arrow.global_transform = Transform3D(mf.global_transform.basis,
				mf.global_transform * Kit.at(clamped + d.normalized() * 14.0,
				LIFT + 0.002))
		_arrow.visible = drawn >= 0.999
	return pts


func tick(_delta: float) -> void:
	if link.is_empty() or anchor == Vector2.INF or drawn <= 0.001:
		_line.visible = false
		_casing.visible = false
		_arrow.visible = false
		if _bead != null:
			_bead.visible = false
		return
	_path = _route()
	var total := 0.0
	for i in _path.size() - 1:
		total += (_path[i] as Vector3).distance_to(_path[i + 1])
	var left := total * drawn
	var pts: Array = [_path[0]]
	for i in _path.size() - 1:
		var a: Vector3 = _path[i]
		var b: Vector3 = _path[i + 1]
		var seg := a.distance_to(b)
		if left >= seg:
			pts.append(b)
			left -= seg
		else:
			pts.append(a.lerp(b, left / maxf(seg, 0.00001)))
			break
	_line.visible = true
	_casing.visible = true
	_line.mesh = _strip(pts, WIDTH, 1.0)
	_casing.mesh = _strip(pts, WIDTH * 4.0, 1.003)
	if _bead != null:
		_bead.visible = true
	_last = {"points": pts.size(), "drawn": drawn}


## A strip facing the eye (at the origin); `push` > 1 slides it straight
## away from the eye -- the same outline on screen, just behind.
static func _strip(pts: Array, width: float, push: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a: Vector3 = (pts[i] as Vector3) * push
		var b: Vector3 = (pts[i + 1] as Vector3) * push
		if a.distance_to(b) < 0.00001:
			continue
		var side := (b - a).cross(-(a + b) * 0.5).normalized() * width * 0.5
		st.add_vertex(a - side); st.add_vertex(a + side); st.add_vertex(b + side)
		st.add_vertex(a - side); st.add_vertex(b + side); st.add_vertex(b - side)
	return st.commit()


func state() -> Dictionary:
	var t := map_face.target_world(link) if map_face != null and not link.is_empty() \
			else {}
	return {"link": link.duplicate(), "drawn": snappedf(drawn, 0.001),
		"inside": bool(t.get("inside", false)) if not t.is_empty() else false,
		"end": [snappedf((_path[-1] as Vector3).x, 0.0001),
			snappedf((_path[-1] as Vector3).y, 0.0001),
			snappedf((_path[-1] as Vector3).z, 0.0001)] if not _path.is_empty() else []}
