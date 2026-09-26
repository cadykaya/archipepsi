extends RefCounted

const Kit := preload("res://_harness/study_kit.gd")
## A FLAT, RESTING PLAN of the Zone on a wall: the map as another study
## shows it when it is not the study's subject (Leaf's neighbour, Thread's
## destination).
##
## Drawn from Production's own rows -- `MapFace.rooms_shown`,
## `connectors_shown` and `blockers_shown`, over the committed layout they
## came from -- so a room is its real rectangle and a connector its real
## path, turning where it turns (04 §6). Nothing is placed for looks.
##
## +Z (away from the entrance) is up the page. Colours are Production's
## provisional circuit colours (`MinimapModel`), and the symbol is its own
## letter mapped onto the approved Glyph symbols: K a lock -> `blocked`,
## P power -> `circuit`, M a machine -> `control` (provisional until the
## circuit family is drawn).

const SYMBOL_ICON := {"K": "blocked", "P": "circuit", "M": "control"}

var room_px := {}     # room id -> Vector2, page px, the rectangle's centre
var rect_px := {}     # room id -> Rect2, page px
var edge_px := {}     # edge id -> Vector2, page px, where its mark stands
var floors := {}      # room id -> MeshInstance3D
var marks := {}       # edge id -> Sprite3D
var lines := {}       # edge id -> MeshInstance3D
var names := {}       # room id -> Label3D

var _lo := Vector2.ZERO
var _hi := Vector2.ZERO
var _sc := 1.0
var _off := Vector2.ZERO


func _init(kit: Kit, face: Node3D, data: Dictionary, area: Rect2,
		depth := 0.004, with_names := true) -> void:
	var rooms: Array = data["rooms"]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r: Dictionary in rooms:
		var p: Array = r["rect"]["position"]
		var s: Array = r["rect"]["size"]
		lo = lo.min(Vector2(p[0], p[1]))
		hi = hi.max(Vector2(float(p[0]) + float(s[0]), float(p[1]) + float(s[1])))
	for c: Dictionary in data["connectors"]:
		for q: Array in c["path"]:
			lo = lo.min(Vector2(q[0], q[1]))
			hi = hi.max(Vector2(q[0], q[1]))
	_lo = lo
	_hi = hi
	var span := hi - lo
	_sc = minf(area.size.x / span.x, area.size.y / span.y)
	_off = area.position + (area.size - span * _sc) * 0.5

	var colours: Dictionary = data.get("colours", {})
	for c: Dictionary in data["connectors"]:
		var pts: Array = []
		for q: Array in c["path"]:
			pts.append(kit.at(to_px(float(q[0]), float(q[1])), depth))
		var state := str(c["state"])
		var tint: Color = Kit.INK_FAINT
		var circuits: Array = c.get("circuits", [])
		if state != "open" and not circuits.is_empty():
			tint = Color(str(colours.get(str(circuits[0]), "#9ba5b6")))
		elif state != "open":
			tint = Kit.INK_DIM
		lines[str(c["edge_id"])] = kit.ribbon(face, pts,
				3.0 * kit.px(), tint, 1.0 if state != "open" else 0.8)
		var mark: Array = c.get("mark_at", [])
		if mark.size() == 2:
			edge_px[str(c["edge_id"])] = to_px(float(mark[0]), float(mark[1]))
		if state != "open":
			var sym := str(c.get("symbol", ""))
			var icon := str(SYMBOL_ICON.get(sym, "blocked"))
			marks[str(c["edge_id"])] = kit.sprite(face, icon,
					edge_px.get(str(c["edge_id"]), Vector2.ZERO), 3, tint,
					depth + 0.003)

	for r: Dictionary in rooms:
		var p: Array = r["rect"]["position"]
		var s: Array = r["rect"]["size"]
		var a := to_px(float(p[0]), float(p[1]) + float(s[1]))
		var b := to_px(float(p[0]) + float(s[0]), float(p[1]))
		var rect := Rect2(a, b - a)
		rect_px[str(r["id"])] = rect
		room_px[str(r["id"])] = rect.get_center()
		floors[str(r["id"])] = kit.card(face, rect.position,
				rect.size, depth + 0.001, Kit.SHEET, 1.0, true)
		_outline(kit, face, rect, depth + 0.0015, Kit.INK_FAINT)
		if bool(r.get("here", false)):
			kit.card(face, rect.get_center() - Vector2(6, 6),
					Vector2(12, 12), depth + 0.004, Kit.SIGNAL)
		if with_names:
			var name := str(r.get("name", ""))
			var w: float = kit.measure(name, 2)
			if w + 12.0 <= rect.size.x and rect.size.y >= 26.0:
				names[str(r["id"])] = kit.label(face, name,
						rect.position + Vector2(6, 6), 2, Kit.INK_DIM,
						depth + 0.003)


func to_px(x: float, z: float) -> Vector2:
	return Vector2(_off.x + (x - _lo.x) * _sc, _off.y + (_hi.y - z) * _sc)


func _outline(kit: Kit, face: Node3D, r: Rect2, depth: float,
		colour: Color) -> void:
	var w := 2.0
	kit.card(face, r.position, Vector2(r.size.x, w), depth, colour)
	kit.card(face, r.position + Vector2(0, r.size.y - w),
			Vector2(r.size.x, w), depth, colour)
	kit.card(face, r.position, Vector2(w, r.size.y), depth, colour)
	kit.card(face, r.position + Vector2(r.size.x - w, 0),
			Vector2(w, r.size.y), depth, colour)
