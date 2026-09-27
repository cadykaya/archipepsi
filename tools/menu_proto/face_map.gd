class_name FaceMap
extends RefCounted
## MAP, LENS refined: THE WALL IS A WINDOW, AND ONLY THE VIEW MOVES.
##
## The wall opens, and the Zone's miniature stands behind it: MapFace's own
## rows -- rooms at their committed rectangles and standing heights,
## connectors along their built chains, gates where MapFace puts them. The
## miniature is ONE object under ONE lens (yaw, pitch, target, zoom): every
## move -- a pick, an orbit, a pan, a zoom, the overview -- moves all of it
## at once, so no room ever moves relative to another.
##
## * **Short labels answer first.** Picking a place names it and tags each
##   of its ways out, at the way: open, shut, or MapFace's "a way on, not
##   yet walked". Nothing covers the room being asked about.
## * **The long answer is asked for.** ENTER / A (or clicking the name)
##   docks MapFace's own detail at the window's edge, and the lens slides
##   the place clear of it. The same again closes it.
## * **Overview is the reset** (MapFace.recentre's keys: C / Home / Y):
##   the whole known Zone in the window, you in it, nothing picked.
## * **Three marks, three shapes.** Focus is a frame round the room (signal).
##   A circuit is its own symbol on its gate (Production's colour). You are
##   the figure standing in your room (ink). None is told by hue alone.
## * Leaving the wall keeps the lens and the pick exactly as they were.
## * Reduced motion: every lens move is a cut, and the gates hold still.

const WINDOW := Rect2(Vector2(40, 90), Vector2(1200, 604))
const PANEL_W := 340.0
const TILT := 55.0
const WALL_H := 2.4                  # MapFace.WALL_HEIGHT
const YAW_STEP := 15.0               # MapFace
const PITCH_STEP := 7.5
const ZOOM_STEP := 1.25
const MIN_PITCH := 20.0
const MAX_PITCH := 85.0
const PICK_ZOOM := 2.1
const DEPTH := -2.25                 # the miniature's centre, behind the wall
const SYMBOL_ICON := {"K": "blocked", "P": "circuit", "M": "control"}

## The lens: what `go` animates. Every field moves the miniature as a whole.
class Lens:
	var yaw := 0.0
	var pitch := 55.0
	var target := Vector3.ZERO       # map-space point at the window's centre
	var zoom := 1.0
	var shift := 0.0                 # page px the centre slides (detail open)


var kit: Kit
var shell: Shell
var face: Node3D
var data: Dictionary
var sample: Dictionary
var lens := Lens.new()
var fit := 1.0
var mid := Vector3.ZERO
var picked := ""
var hovered := ""
var expanded := false
var floor_filter := -1
var link := {}                       # the journal's link, when one is active

var _map: Node3D
var _rooms := {}                     # id -> {row, centre, lo, hi, floor mat}
var _edges := {}                     # edge -> {row, mat, colour, mark}
var _gates := {}                     # edge -> Sprite3D
var _labels: Node3D                  # the glass: tags, placed every frame
var _tags: Array = []                # {node, size, kind, ref, text, rect}
var _panel: Node3D
var _frame_focus: Node3D
var _frame_hover: Node3D
var _ring: Node3D
var _you: Node3D
var _t := 0.0
var _drag_moved := 0.0
var _bounds: Array = [Vector3.ZERO, Vector3.ZERO]
var _home := Vector3.ZERO
var _framed := false
var _pulse := 1.0


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	face = shell.face_of("map")
	(shell.walls["map"] as MeshInstance3D).visible = false
	_window()


## The wall is a frame round an opening, with a reveal: the opening has a
## depth, so it reads as cut into the wall and not painted on it.
func _window() -> void:
	var w := Kit.PAGE
	for r: Rect2 in [Rect2(Vector2.ZERO, Vector2(w.x, WINDOW.position.y)),
			Rect2(Vector2(0, WINDOW.end.y), Vector2(w.x, w.y - WINDOW.end.y)),
			Rect2(Vector2(0, WINDOW.position.y), Vector2(WINDOW.position.x,
				WINDOW.size.y)),
			Rect2(Vector2(WINDOW.end.x, WINDOW.position.y),
				Vector2(w.x - WINDOW.end.x, WINDOW.size.y))]:
		var frame := kit.card(face, r.position, r.size, 0.0, kit.wall_material())
		# The frame's grain must line up with the other walls' page.
		var q := frame.mesh as QuadMesh
		q.size = r.size * Kit.px()
	var depth := 0.05
	var s := Kit.px()
	for side: Array in [
			[Vector3(WINDOW.size.x * s, 0.002, depth), WINDOW.position + Vector2(WINDOW.size.x * 0.5, 0)],
			[Vector3(WINDOW.size.x * s, 0.002, depth), WINDOW.position + Vector2(WINDOW.size.x * 0.5, WINDOW.size.y)],
			[Vector3(0.002, WINDOW.size.y * s, depth), WINDOW.position + Vector2(0, WINDOW.size.y * 0.5)],
			[Vector3(0.002, WINDOW.size.y * s, depth), WINDOW.position + Vector2(WINDOW.size.x, WINDOW.size.y * 0.5)]]:
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = side[0]
		node.mesh = box
		node.material_override = kit.lit(Kit.POST)
		node.position = Kit.at(side[1], -depth * 0.5)
		face.add_child(node)
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(14, 9)
	back.mesh = quad
	back.material_override = kit.flat(Color("#07090b"))
	back.position = Vector3(0, 0, -6.0)
	face.add_child(back)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-62), deg_to_rad(28), 0)
	light.light_energy = 0.9
	light.light_cull_mask = 2
	face.add_child(light)


func load_data(d: Dictionary, s: Dictionary) -> void:
	var keep := picked
	data = d
	sample = s
	if _map != null:
		_map.queue_free()
	_rooms.clear()
	_edges.clear()
	_gates.clear()
	_map = Node3D.new()
	_map.name = "Miniature"
	face.add_child(_map)
	# The overview frames what is KNOWN: the rooms. A way into the unknown
	# runs out of the frame, as far as MapFace draws it and no further.
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for r: Dictionary in data["rooms"]:
		var p: Array = r["rect"]["position"]
		var sz: Array = r["rect"]["size"]
		var y := float(r["floor_y"])
		lo = lo.min(Vector3(p[0], y, p[1]))
		hi = hi.max(Vector3(float(p[0]) + float(sz[0]), y + WALL_H,
				float(p[1]) + float(sz[1])))
	mid = (lo + hi) * 0.5
	_bounds = [m(lo), m(hi)]
	for r: Dictionary in data["rooms"]:
		_room(r)
	for c: Dictionary in data["connectors"]:
		_connector(c)
	for b: Dictionary in data["blockers"]:
		_gate(b)
	_you = _you_mark()
	if _labels != null:
		_labels.queue_free()
	_labels = Node3D.new()
	_labels.name = "Glass"
	face.add_child(_labels)
	_tags.clear()
	_frame_focus = Node3D.new()
	_frame_hover = Node3D.new()
	_ring = Node3D.new()
	for n: Node3D in [_frame_focus, _frame_hover, _ring]:
		_map.add_child(n)
	_fit_overview()
	picked = keep if _rooms.has(keep) else ""
	if not _framed:
		_framed = true
		_overview(true)
	_apply()
	_refresh_marks()


# ------------------------------------------------------------ building

## Map space (x, y, z) -> the miniature's local space: +z runs away from
## the entrance, which is UP the window (MapFace's own convention).
func m(v: Vector3) -> Vector3:
	return Vector3(v.x - mid.x, v.y - mid.y, -(v.z - mid.z))


func _room(r: Dictionary) -> void:
	var p: Array = r["rect"]["position"]
	var sz: Array = r["rect"]["size"]
	var y := float(r["floor_y"])
	var w := float(sz[0])
	var d := float(sz[1])
	var c := m(Vector3(float(p[0]) + w * 0.5, y, float(p[1]) + d * 0.5))
	var floor_mat := kit.lit(Color("#4a525f"), true)
	var wall_mat := kit.lit(Color("#2c3139"), true)
	_box(Vector3(w, 0.4, d), c + Vector3(0, -0.2, 0), floor_mat)
	for side: Array in [[Vector3(w, WALL_H, 0.35), Vector3(0, WALL_H * 0.5, -d * 0.5)],
			[Vector3(w, WALL_H, 0.35), Vector3(0, WALL_H * 0.5, d * 0.5)],
			[Vector3(0.35, WALL_H, d), Vector3(-w * 0.5, WALL_H * 0.5, 0)],
			[Vector3(0.35, WALL_H, d), Vector3(w * 0.5, WALL_H * 0.5, 0)]]:
		_box(side[0], c + side[1], wall_mat)
	_rooms[str(r["id"])] = {"row": r, "centre": c, "w": w, "d": d,
		"floor": floor_mat, "wall": wall_mat, "floor_y": y,
		"floor_c": floor_mat.albedo_color, "wall_c": wall_mat.albedo_color}


func _connector(c: Dictionary) -> void:
	var pts: Array = []
	for q: Array in data["points"].get(str(c["edge_id"]), []):
		pts.append(m(Vector3(q[0], float(q[1]) + 0.3, q[2])))
	var colour := Color("#8a93a3")
	var circuits: Array = c.get("circuits", [])
	if str(c["state"]) != "open" and not circuits.is_empty():
		colour = Color(str(data["colours"].get(str(circuits[0]), "#9ba5b6")))
	var mat := kit.lit(colour, true)
	var node := MeshInstance3D.new()
	node.mesh = Kit.strip(pts, 1.6, Vector3.UP)
	node.material_override = mat
	node.layers = 2
	_map.add_child(node)
	var mark: Array = c.get("mark_at", [])
	var at := Vector3.ZERO
	if mark.size() == 2:
		var y := 0.0
		var ys: Array = c.get("ys", [])
		if not ys.is_empty():
			y = float(ys[ys.size() / 2])
		at = m(Vector3(mark[0], y, mark[1]))
	_edges[str(c["edge_id"])] = {"row": c, "mat": mat, "colour": colour,
		"mark": at}


func _gate(b: Dictionary) -> void:
	var at: Array = b["at"]
	var s := Sprite3D.new()
	s.texture = kit.icons[SYMBOL_ICON.get(str(b["symbol"]), "blocked")]
	s.pixel_size = 0.34
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.render_priority = 2
	s.modulate = Color(str(b["colour"]))
	s.position = m(Vector3(float(at[0]), float(at[1]) + 3.0, float(at[2])))
	_map.add_child(s)
	_gates[str(b["edge_id"])] = s


## You: the figure, standing in your room, and the word. Ink, not signal.
func _you_mark() -> Node3D:
	var node := Node3D.new()
	_map.add_child(node)
	for id: String in _rooms:
		var r: Dictionary = _rooms[id]
		if not bool((r["row"] as Dictionary).get("here", false)):
			continue
		var s := Sprite3D.new()
		s.texture = kit.icons["you"]
		s.pixel_size = 0.42
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.modulate = Kit.INK
		s.position = (r["centre"] as Vector3) + Vector3(0, 2.6, 0)
		node.add_child(s)
		node.set_meta("room", id)
	return node


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.layers = 2
	_map.add_child(node)


## A short label standing in the miniature, always facing you and always
## the same size (the wall's 2x), with a dark edge so it reads over any
## floor: four offset copies behind it -- a bitmap face has no outline.
func _tag(text: String, colour: Color, k: int, kind: String, ref: String) -> void:
	var node := Node3D.new()
	_labels.add_child(node)
	# Bitmap text has no outline: a dark copy one glyph-pixel out on every
	# side keeps the word legible over a lit floor or a coloured band.
	for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1),
			Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1),
			Vector2(1, -1)]:
		kit.label(node, text, off * float(k), k, Color("#07090b"), 0.0, false, true)
	kit.label(node, text, Vector2.ZERO, k, colour, 0.0006, false, true)
	_tags.append({"node": node, "size": Vector2(kit.measure(text, k),
			8.0 * k), "kind": kind, "ref": ref, "text": kit.display(text),
			"rect": Rect2()})


## Where each tag goes this frame. YOU beside the figure; each exit tag
## beside its gate or doorway, on whichever side is free, never over another
## exit; then the head block (name + summary) just outside the picked room --
## above it if there is room, else below or beside. A tag whose subject is
## outside the window is not shown.
func _layout_tags() -> void:
	if _tags.is_empty() or _map == null:
		return
	var usable := Rect2(WINDOW.position + Vector2(10, 10), WINDOW.size - Vector2(20, 20))
	if expanded and picked != "":
		usable.size.x -= PANEL_W
	var taken: Array = []
	var head: Dictionary = {}
	var summary: Dictionary = {}
	var exits: Array = []
	for t: Dictionary in _tags:
		match str(t["kind"]):
			"head": head = t
			"summary": summary = t
			"exit": exits.append(t)
			"you": _place_you(t, usable, taken)
	var room := Rect2()
	if picked != "" and _rooms.has(picked):
		room = _room_rect(picked)
		taken.append(room.grow(6))
	var anchors := {}
	for t: Dictionary in exits:
		var a := Rect2(_page_of(_edges[str(t["ref"])]["mark"]), Vector2.ZERO).grow(10)
		anchors[t] = a
		if usable.has_point(a.get_center()):
			taken.append(a)
	for t: Dictionary in exits:
		var a: Rect2 = anchors[t]
		if not usable.has_point(a.get_center()):
			_hide(t)
			continue
		var size: Vector2 = t["size"]
		var places: Array = []
		for gap: float in [4.0, 28.0, 56.0]:
			places.append_array(_around(a, size, gap))
		var at := _choose(places, size, usable, taken)
		_put(t, at)
		taken.append(Rect2(at, size).grow(4))
	if head.is_empty():
		return
	var hs: Vector2 = head["size"]
	var ss: Vector2 = summary["size"]
	var block := Vector2(maxf(hs.x, ss.x), hs.y + 6.0 + ss.y)
	var places: Array = []
	for gap: float in [12.0, 40.0, 80.0]:
		places.append_array([
			Vector2(room.position.x, room.position.y - gap - block.y),
			Vector2(room.position.x, room.end.y + gap),
			Vector2(room.end.x + gap, room.get_center().y - block.y * 0.5),
			Vector2(room.position.x - gap - block.x,
				room.get_center().y - block.y * 0.5)])
	var at := _choose(places, block, usable, taken)
	_put(head, at)
	_put(summary, at + Vector2(0, hs.y + 6.0))


## YOU goes beside the figure, and only has to keep off the figure itself.
func _place_you(t: Dictionary, usable: Rect2, taken: Array) -> void:
	var id := str(t["ref"])
	if not _rooms.has(id):
		_hide(t)
		return
	var c: Vector3 = _rooms[id]["centre"]
	var fig := _projected(c + Vector3(-2.2, 0.0, -2.2), c + Vector3(2.2, 6.0, 2.2))
	if not usable.has_point(fig.get_center()):
		_hide(t)
		return
	var size: Vector2 = t["size"]
	var at := _choose(_around(fig, size, 4.0), size, usable, [fig])
	_put(t, at)
	taken.append(fig)
	taken.append(Rect2(at, size).grow(4))


## Right, above, below, left of `a`, `gap` page px out.
static func _around(a: Rect2, size: Vector2, gap: float) -> Array:
	var c := a.get_center()
	return [Vector2(a.end.x + gap, c.y - size.y * 0.5),
		Vector2(c.x - size.x * 0.5, a.position.y - gap - size.y),
		Vector2(c.x - size.x * 0.5, a.end.y + gap),
		Vector2(a.position.x - gap - size.x, c.y - size.y * 0.5)]


func _hide(t: Dictionary) -> void:
	(t["node"] as Node3D).visible = false
	t["rect"] = Rect2()


## The first place that is inside the window and covers nothing already
## placed; failing that, the one that covers least.
func _choose(places: Array, size: Vector2, usable: Rect2, taken: Array) -> Vector2:
	var best := Vector2.ZERO
	var least := INF
	for raw: Vector2 in places:
		var p := Vector2(clampf(raw.x, usable.position.x, usable.end.x - size.x),
				clampf(raw.y, usable.position.y, usable.end.y - size.y))
		var r := Rect2(p, size)
		var cover := 0.0
		for other: Rect2 in taken:
			cover += r.intersection(other).get_area() if r.intersects(other) else 0.0
		if cover <= 0.0:
			return p
		if cover < least:
			least = cover
			best = p
	return best


func _put(t: Dictionary, at: Vector2) -> void:
	var node: Node3D = t["node"]
	node.visible = true
	node.position = Kit.at(at.round(), 0.012)
	t["rect"] = Rect2(at.round(), t["size"])


## A room's outline on the page, as the lens has it now.
func _room_rect(id: String) -> Rect2:
	var r: Dictionary = _rooms[id]
	var c: Vector3 = r["centre"]
	var hw := float(r["w"]) * 0.5
	var hd := float(r["d"]) * 0.5
	return _projected(c + Vector3(-hw, 0, -hd), c + Vector3(hw, WALL_H, hd))


## A point in the miniature, on the page (projected from the eye).
func _page_of(local: Vector3) -> Vector2:
	var p := _map.transform * local
	var w := p * (Kit.DISTANCE / maxf(-p.z, 0.001))
	return Vector2(w.x / Kit.px() + Kit.PAGE.x * 0.5, Kit.PAGE.y * 0.5 - w.y / Kit.px())


# ------------------------------------------------------------ the lens

func _overview(at_once := false) -> void:
	_set_lens(0.0, TILT, _home, fit, at_once)


## The overview's zoom and centre, found by PROJECTING the known rooms'
## box through the real lens onto the wall -- so the whole known Zone
## fills the window at any shape, not by a guessed span.
func _fit_overview() -> void:
	var saved := [lens.yaw, lens.pitch, lens.target, lens.zoom, lens.shift]
	lens.yaw = 0.0
	lens.pitch = TILT
	lens.shift = 0.0
	lens.zoom = 0.02
	lens.target = Vector3.ZERO
	for i in 3:
		_apply()
		var r := _projected(_bounds[0], _bounds[1])
		var area := WINDOW.grow(-50)
		var k := minf(area.size.x / maxf(r.size.x, 1.0),
				area.size.y / maxf(r.size.y, 1.0))
		lens.zoom *= k
		_apply()
		r = _projected(_bounds[0], _bounds[1])
		# Nudge the target so the projected centre sits on the window's.
		var off := WINDOW.get_center() - r.get_center()
		var s := Kit.px() * absf(DEPTH) / lens.zoom
		lens.target -= Basis.from_euler(Vector3(deg_to_rad(lens.pitch),
				deg_to_rad(lens.yaw), 0), EULER_ORDER_YXZ).inverse() * Vector3(
				off.x * s, -off.y * s, 0.0)
	fit = lens.zoom
	_home = lens.target
	lens.yaw = saved[0]
	lens.pitch = saved[1]
	lens.target = saved[2]
	lens.zoom = saved[3]
	lens.shift = saved[4]


## Page-px rectangle a box covers, seen from the eye.
func _projected(lo: Vector3, hi: Vector3) -> Rect2:
	var r := Rect2()
	var first := true
	for i in 8:
		var corner := Vector3(lo.x if i & 1 == 0 else hi.x,
				lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z)
		var p := _map.transform * corner
		var w := p * (Kit.DISTANCE / maxf(-p.z, 0.001))
		var page := Vector2(w.x / Kit.px() + Kit.PAGE.x * 0.5,
				Kit.PAGE.y * 0.5 - w.y / Kit.px())
		if first:
			r = Rect2(page, Vector2.ZERO)
			first = false
		else:
			r = r.expand(page)
	return r


func _set_lens(yaw: float, pitch: float, target: Vector3, zoom: float,
		at_once := false) -> void:
	var t := 0.0 if at_once else 0.38
	kit.go(lens, "yaw", yaw, t)
	kit.go(lens, "pitch", clampf(pitch, MIN_PITCH, MAX_PITCH), t)
	kit.go(lens, "target", target, t)
	kit.go(lens, "zoom", clampf(zoom, fit * 0.6, fit * 8.0), t)


## The one transform: the miniature, turned and tilted about the lens's
## target, scaled, and set behind the window's centre.
func _apply() -> void:
	if _map == null:
		return
	var basis := Basis.from_euler(Vector3(deg_to_rad(lens.pitch),
			deg_to_rad(lens.yaw), 0), EULER_ORDER_YXZ).scaled(
			Vector3.ONE * lens.zoom)
	var centre := Kit.at(WINDOW.get_center() + Vector2(lens.shift, 0), 0.0)
	centre.z = DEPTH
	_map.transform = Transform3D(basis, centre - basis * lens.target)
	_layout_tags()


func face_pos(local: Vector3) -> Vector3:
	return _map.transform * local


## Where the lens must sit to hold `local` still on screen while the zoom
## goes from its current value to `zoom` -- the pick that closes AROUND
## the pointer.
func _target_keeping(local: Vector3, zoom: float) -> Vector3:
	return local - (local - lens.target) * (lens.zoom / zoom)


# ------------------------------------------------------------ picking

func pick(id: String, keep_screen := false) -> void:
	if not _rooms.has(id):
		return
	picked = id
	var c: Vector3 = _rooms[id]["centre"]
	var zoom := maxf(lens.zoom, fit * PICK_ZOOM)
	if keep_screen:
		_set_lens(lens.yaw, lens.pitch, _target_keeping(c, zoom), zoom)
	else:
		_set_lens(lens.yaw, lens.pitch, c, zoom)
	_refresh_marks()


func step_place(step: int) -> void:
	var ids := known()
	if ids.is_empty():
		return
	var at := ids.find(picked)
	at = (0 if step > 0 else ids.size() - 1) if at == -1 \
			else posmod(at + step, ids.size())
	pick(ids[at])


func known() -> Array:
	var out := []
	for r: Dictionary in data["rooms"]:
		out.append(str(r["id"]))
	return out


## MapFace.recentre: nothing picked, and (in LENS) the whole known Zone.
func overview() -> void:
	picked = ""
	expanded = false
	floor_filter = -1
	kit.go(lens, "shift", 0.0, 0.3)
	_overview()
	_refresh_marks()


func toggle_detail() -> void:
	if picked == "":
		return
	expanded = not expanded
	# The lens slides the place clear of the panel; nothing is covered.
	kit.go(lens, "shift", -PANEL_W * 0.5 if expanded else 0.0, 0.3)
	_refresh_marks()


func step_floor(step: int) -> void:
	var floors: Array = data["floors"]
	if floors.size() < 2:
		return
	if floor_filter == -1:
		floor_filter = 0
	else:
		floor_filter += step
		if floor_filter < 0 or floor_filter >= floors.size():
			floor_filter = -1
	_refresh_marks()


func turn_view(yaw: float, pitch: float) -> void:
	_set_lens(lens.yaw + yaw, lens.pitch + pitch, lens.target, lens.zoom)


func zoom_view(factor: float) -> void:
	_set_lens(lens.yaw, lens.pitch, lens.target, lens.zoom / factor)


## Pan in the ground plane, as the lens sees it (MapFace.pan_view).
func pan_view(right: float, ahead: float) -> void:
	var y := deg_to_rad(lens.yaw)
	var side := Vector3(cos(y), 0, -sin(y))
	var fwd := Vector3(-sin(y), 0, -cos(y))
	var step := 18.0 / lens.zoom * 0.02
	_set_lens(lens.yaw, lens.pitch, lens.target + (side * right + fwd * ahead)
			* step * 40.0, lens.zoom)


func _ray_pick(hit: Dictionary) -> String:
	if hit.is_empty():
		return ""
	var p: Vector2 = hit["at"]
	if not WINDOW.has_point(p) or (expanded and p.x > WINDOW.end.x - PANEL_W):
		return ""
	var inv := (face.global_transform * _map.transform).affine_inverse()
	var o: Vector3 = inv * (hit["origin"] as Vector3)
	var d: Vector3 = (inv.basis * (hit["along"] as Vector3)).normalized()
	var best := ""
	var nearest := INF
	for id: String in _rooms:
		var r: Dictionary = _rooms[id]
		if floor_filter != -1 and not _on_floor(r):
			continue
		var c: Vector3 = r["centre"]
		var lo := c + Vector3(-float(r["w"]) * 0.5, -0.4, -float(r["d"]) * 0.5)
		var hi := c + Vector3(float(r["w"]) * 0.5, WALL_H, float(r["d"]) * 0.5)
		var t := _ray_box(o, d, lo, hi)
		if t >= 0.0 and t < nearest:
			nearest = t
			best = id
	return best


static func _ray_box(o: Vector3, d: Vector3, lo: Vector3, hi: Vector3) -> float:
	var t0 := -INF
	var t1 := INF
	for i in 3:
		if absf(d[i]) < 0.000001:
			if o[i] < lo[i] or o[i] > hi[i]:
				return -1.0
			continue
		var a := (lo[i] - o[i]) / d[i]
		var b := (hi[i] - o[i]) / d[i]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	return t0 if t1 >= maxf(t0, 0.0) else -1.0


func _on_floor(r: Dictionary) -> bool:
	var floors: Array = data["floors"]
	if floor_filter < 0 or floor_filter >= floors.size():
		return true
	return absf(float(r["floor_y"]) - float(floors[floor_filter])) < 0.5


# ------------------------------------------------------------ marks

## Re-tone the rooms and ways, and rebuild the short labels and frames for
## what is picked / hovered / linked.
func _refresh_marks() -> void:
	var neighbours := {}
	if picked != "":
		for eid: String in _edges:
			var row: Dictionary = _edges[eid]["row"]
			if str(row["room_a"]) == picked or str(row["room_b"]) == picked:
				neighbours[str(row["room_a"])] = true
				neighbours[str(row["room_b"])] = true
	for id: String in _rooms:
		var r: Dictionary = _rooms[id]
		var k := 0.0
		if floor_filter != -1 and not _on_floor(r):
			k = 0.8
		elif picked != "" and id != picked and not neighbours.has(id):
			k = 0.45
		var lift: Color = r["floor_c"]
		if id == picked:
			lift = (r["floor_c"] as Color).lightened(0.35)
		kit.go(r["floor"], "albedo_color", lift.darkened(k), 0.2)
		kit.go(r["wall"], "albedo_color", (r["wall_c"] as Color).darkened(k), 0.2)
	_frame(_frame_focus, picked, Kit.SIGNAL, 0.9)
	_frame(_frame_hover, hovered if hovered != picked else "", Kit.INK_DIM, 0.45)
	_place_labels()
	_build_panel()
	_link_ring()


## The frame round a room: focus is this SHAPE, in signal -- not a tint.
func _frame(holder: Node3D, id: String, colour: Color, width: float) -> void:
	for n: Node in holder.get_children():
		n.queue_free()
	if id == "" or not _rooms.has(id):
		return
	var r: Dictionary = _rooms[id]
	var c: Vector3 = r["centre"]
	var hw := float(r["w"]) * 0.5 + 0.9
	var hd := float(r["d"]) * 0.5 + 0.9
	var y := c.y + 0.12
	var pts := [Vector3(c.x - hw, y, c.z - hd), Vector3(c.x + hw, y, c.z - hd),
		Vector3(c.x + hw, y, c.z + hd), Vector3(c.x - hw, y, c.z + hd),
		Vector3(c.x - hw, y, c.z - hd)]
	var node := MeshInstance3D.new()
	node.mesh = Kit.strip(pts, width, Vector3.UP)
	node.material_override = kit.flat(colour)
	holder.add_child(node)


## The short answers, as words on the window's glass -- not things in the
## miniature. Built when the pick changes; PLACED every frame from where the
## lens has put what they name (_layout_tags), so they never cover each
## other, the picked room, or you.
func _place_labels() -> void:
	for n: Node in _labels.get_children():
		n.queue_free()
	_tags.clear()
	if _you != null and _you.has_meta("room"):
		_tag("YOU", Kit.INK, 2, "you", str(_you.get_meta("room")))
	if picked == "":
		_layout_tags()
		return
	var r: Dictionary = _rooms[picked]
	var row: Dictionary = r["row"]
	var open_n := 0
	var shut_n := 0
	var exits: Array = []
	for eid: String in _edges:
		var e: Dictionary = _edges[eid]
		var c: Dictionary = e["row"]
		if str(c["room_a"]) != picked and str(c["room_b"]) != picked:
			continue
		var other := str(c["room_b"]) if str(c["room_a"]) == picked \
				else str(c["room_a"])
		var name := _room_name(other)
		var words := ""
		var colour := Kit.INK_DIM
		if str(c["state"]) == "open":
			open_n += 1
			words = ("TO " + name) if name != "" else "A WAY ON, NOT YET WALKED"
		else:
			shut_n += 1
			words = "SHUT" + (" -- TO " + name if name != "" else "")
			colour = e["colour"]
		exits.append([words, colour, eid])
	var more := "   %s: MORE" % ("A" if kit.device == "pad" else "ENTER")
	_tag(str(row.get("name", "")), Kit.INK, 3, "head", picked)
	_tag("%d OPEN   %d SHUT" % [open_n, shut_n] + (more if not expanded else ""),
			Kit.INK_DIM, 2, "summary", picked)
	for x: Array in exits:
		_tag(str(x[0]), x[1], 2, "exit", str(x[2]))
	_layout_tags()


func _room_name(id: String) -> String:
	if not _rooms.has(id):
		return ""                       # an unknown room is never named
	return str((_rooms[id]["row"] as Dictionary).get("name", ""))


## The long answer, docked at the window's edge: MapFace's own detail.
func _build_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if not expanded or picked == "":
		return
	_panel = Node3D.new()
	face.add_child(_panel)
	var x := WINDOW.end.x - PANEL_W
	var y := WINDOW.position.y
	kit.card(_panel, Vector2(x, y), Vector2(PANEL_W, WINDOW.size.y), 0.004,
			kit.flat(Color("#0e1115"), 0.94))
	kit.card(_panel, Vector2(x, y), Vector2(3, WINDOW.size.y), 0.005,
			kit.flat(Kit.SIGNAL))
	var text: String = data["details"].get(picked, "")
	var yy := y + 18.0
	var lines := text.split("\n")
	for i in lines.size():
		var k := 3 if i == 0 else 2
		var wrapped := kit.wrap(lines[i], k, PANEL_W - 40)
		kit.label(_panel, "\n".join(wrapped), Vector2(x + 22, yy), k,
				Kit.INK if i == 0 else Kit.INK_DIM, 0.006)
		yy += (30.0 if k == 3 else 20.0) * wrapped.size() + (10.0 if i == 0 else 4.0)
	var floors: Array = data["floors"]
	if floors.size() > 1:
		var f := int((_rooms[picked] as Dictionary)["floor_y"] > float(floors[0]) + 0.5)
		kit.label(_panel, "FLOOR %d OF %d" % [f + 1, floors.size()],
				Vector2(x + 22, yy + 12), 2, Kit.INK_FAINT, 0.006)
	kit.label(_panel, "MAPFACE'S OWN DETAIL", Vector2(x + 22, WINDOW.end.y - 34),
			2, Kit.INK_FAINT, 0.006)


## The journal's link, if one is active: a ring of dots round what it names.
func set_link(l: Dictionary) -> void:
	link = l
	_link_ring()


func _link_ring() -> void:
	for n: Node in _ring.get_children():
		n.queue_free()
	if link.is_empty():
		return
	var at := target_local(link)
	if at == Vector3.INF:
		return
	for i in 18:
		var a := TAU * float(i) / 18.0
		var dot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.2, 0.7)
		dot.mesh = box
		dot.material_override = kit.flat(Kit.INK)
		dot.position = at + Vector3(cos(a) * 4.2, 0.3, sin(a) * 4.2)
		_ring.add_child(dot)


## Where a link lands, in the miniature: a passage's own mark, or a room's
## floor centre. INF when this save's map has no such thing.
func target_local(l: Dictionary) -> Vector3:
	if l.has("edge") and _edges.has(str(l["edge"])):
		return _edges[str(l["edge"])]["mark"]
	if l.has("room") and _rooms.has(str(l["room"])):
		return _rooms[str(l["room"])]["centre"]
	return Vector3.INF


## For the thread: the link's point in WORLD space, and whether the window
## shows it.
func target_world(l: Dictionary) -> Dictionary:
	var local := target_local(l)
	if local == Vector3.INF:
		return {}
	var world := face.global_transform * (_map.transform * local)
	var on_wall := face.global_transform.affine_inverse() * world
	# Project onto the wall plane from the eye to see if it is in the window.
	var eye := Vector3.ZERO
	var local_eye := face.global_transform.affine_inverse() * eye
	var dir := (on_wall - local_eye)
	var t := (-Kit.DISTANCE - local_eye.z) / dir.z
	var hit := local_eye + dir * t
	var s := Kit.px()
	var page := Vector2(hit.x / s + Kit.PAGE.x * 0.5, Kit.PAGE.y * 0.5 - hit.y / s)
	return {"world": world, "page": page,
		"inside": WINDOW.grow(-6).has_point(page)}


# ------------------------------------------------------------ input

func nav(dir: Vector2i) -> void:
	if dir.x != 0:
		step_place(dir.x)


func accept() -> void:
	if picked == "":
		step_place(1)
	else:
		toggle_detail()


func back() -> bool:
	if expanded:
		toggle_detail()
		return true
	if picked != "":
		overview()
		return true
	return false


## MapFace's own keys and pad buttons (MapFace._on_key / _on_pad_button).
func raw_input(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_LEFT:
				turn_view(-YAW_STEP, 0.0)
			KEY_RIGHT:
				turn_view(YAW_STEP, 0.0)
			KEY_UP:
				turn_view(0.0, PITCH_STEP)
			KEY_DOWN:
				turn_view(0.0, -PITCH_STEP)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				zoom_view(1.0 / ZOOM_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_view(ZOOM_STEP)
			KEY_W:
				pan_view(0.0, 1.0)
			KEY_S:
				pan_view(0.0, -1.0)
			KEY_A:
				pan_view(-1.0, 0.0)
			KEY_D:
				pan_view(1.0, 0.0)
			KEY_C, KEY_HOME:
				overview()
			KEY_PAGEUP:
				step_floor(1)
			KEY_PAGEDOWN:
				step_floor(-1)
			KEY_BRACKETRIGHT:
				step_place(1)
			KEY_BRACKETLEFT:
				step_place(-1)
			KEY_ENTER, KEY_KP_ENTER:
				accept()
			_:
				return false
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_Y:
				overview()
			JOY_BUTTON_DPAD_UP:
				step_floor(1)
			JOY_BUTTON_DPAD_DOWN:
				step_floor(-1)
			JOY_BUTTON_DPAD_RIGHT:
				step_place(1)
			JOY_BUTTON_DPAD_LEFT:
				step_place(-1)
			JOY_BUTTON_A:
				accept()
			JOY_BUTTON_B:
				back()
			_:
				return false
		return true
	return false


## MapFace._apply_sticks: right stick orbits, left pans, triggers zoom.
func sticks(stick: Dictionary, delta: float) -> void:
	var rx := _axis(stick, JOY_AXIS_RIGHT_X)
	var ry := _axis(stick, JOY_AXIS_RIGHT_Y)
	var lx := _axis(stick, JOY_AXIS_LEFT_X)
	var ly := _axis(stick, JOY_AXIS_LEFT_Y)
	var z := _axis(stick, JOY_AXIS_TRIGGER_LEFT) - _axis(stick, JOY_AXIS_TRIGGER_RIGHT)
	if rx != 0.0 or ry != 0.0:
		lens.yaw += rx * 120.0 * delta
		lens.pitch = clampf(lens.pitch - ry * 60.0 * delta, MIN_PITCH, MAX_PITCH)
	if lx != 0.0 or ly != 0.0:
		var y := deg_to_rad(lens.yaw)
		var side := Vector3(cos(y), 0, -sin(y))
		var fwd := Vector3(-sin(y), 0, -cos(y))
		lens.target += (side * lx - fwd * ly) * 30.0 / lens.zoom * delta * 0.02
	if z != 0.0:
		lens.zoom = clampf(lens.zoom / pow(ZOOM_STEP, z * 4.0 * delta),
				fit * 0.6, fit * 8.0)


static func _axis(stick: Dictionary, axis: int) -> float:
	var v := float(stick.get(axis, 0.0))
	return 0.0 if absf(v) < 0.25 else v


func hover_at(_p: Vector2) -> void:
	pass


func pointer_ray(hit: Dictionary) -> void:
	var id := _ray_pick(hit)
	if id != hovered:
		hovered = id
		_frame(_frame_hover, hovered if hovered != picked else "", Kit.INK_DIM, 0.45)


func click(p: Vector2) -> bool:
	_drag_moved = 0.0
	if expanded and p.x > WINDOW.end.x - PANEL_W and WINDOW.has_point(p):
		toggle_detail()
		return true
	return false                      # a press on the map may be a drag


func drag(rel: Vector2, button: int) -> void:
	_drag_moved += rel.length()
	if button == MOUSE_BUTTON_LEFT:
		lens.yaw += rel.x * 0.4
		lens.pitch = clampf(lens.pitch + rel.y * 0.3, MIN_PITCH, MAX_PITCH)
	elif button == MOUSE_BUTTON_RIGHT:
		pan_view(-rel.x * 0.01 * 5.0, rel.y * 0.01 * 5.0)


## A press that did not drag is a pick, and the lens closes AROUND the
## pointer so the room clicked stays under it.
func release(hit: Dictionary, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT or _drag_moved > 6.0:
		return
	var id := _ray_pick(hit)
	if id == "":
		return
	if id == picked:
		toggle_detail()
		return
	pick(id, true)


func wheel(_p: Vector2, dir: int) -> bool:
	zoom_view(ZOOM_STEP if dir > 0 else 1.0 / ZOOM_STEP)
	return true


func prompts() -> Array:
	var out := [["place", "places"], ["click", "pick"]]
	if picked != "":
		out.append(["detail", "less" if expanded else "more"])
	out += [["overview", "overview"], ["zoom", "zoom"], ["orbit", "turn"],
		["turn_left", "turn left"], ["turn_right", "turn right"],
		["close", "close"]]
	return out


func state() -> Dictionary:
	return {"picked": picked, "expanded": expanded, "floor": floor_filter,
		"hovered": hovered, "yaw": snappedf(lens.yaw, 0.01),
		"pitch": snappedf(lens.pitch, 0.01), "zoom": snappedf(lens.zoom, 0.0001),
		"target": [snappedf(lens.target.x, 0.01), snappedf(lens.target.y, 0.01),
			snappedf(lens.target.z, 0.01)], "fit": snappedf(fit, 0.0001),
		"link": link.duplicate(), "shift": lens.shift,
		"gate_scale": _gate_scale(), "pulse": snappedf(_pulse, 0.0001),
		"tags": _tag_state(), "tag_clashes": _tag_clashes()}


func _tag_state() -> Array:
	var out := []
	for t: Dictionary in _tags:
		if (t["node"] as Node3D).visible and (t["rect"] as Rect2).size != Vector2.ZERO:
			out.append(str(t["text"]))
	return out


## Tags that cover another tag, the picked room, or leave the window.
func _tag_clashes() -> int:
	var shown: Array = []
	for t: Dictionary in _tags:
		if (t["node"] as Node3D).visible and (t["rect"] as Rect2).size != Vector2.ZERO:
			shown.append(t)
	var n := 0
	var room := _room_rect(picked) if picked != "" and _rooms.has(picked) else Rect2()
	for i in shown.size():
		var a: Rect2 = shown[i]["rect"]
		if not WINDOW.encloses(a):
			n += 1
		if room.size != Vector2.ZERO and a.intersects(room) \
				and str(shown[i]["kind"]) != "you":
			n += 1
		for j in range(i + 1, shown.size()):
			if a.intersects(shown[j]["rect"] as Rect2):
				n += 1
	return n


func on_device() -> void:
	if picked != "":
		_refresh_marks()


func _gate_scale() -> float:
	for eid: String in _gates:
		return snappedf((_gates[eid] as Sprite3D).scale.x, 0.001)
	return 0.0


## Every frame: the lens's transform; the gates' pulse (MapFace's 1.2 Hz,
## held still when motion is reduced); the linked gate pulses harder.
func tick(delta: float) -> void:
	_t += delta
	_apply()
	var hz := float(data.get("pulse_hz", 1.2))
	var swing := float(data.get("pulse_swing", 0.3))
	for eid: String in _gates:
		var s: Sprite3D = _gates[eid]
		var big := 1.4 if (link.get("edge", "") == eid) else 1.0
		var p := 1.0 if kit.still() else 1.0 + swing * sin(_t * TAU * hz)
		_pulse = p
		s.scale = Vector3.ONE * p * big
