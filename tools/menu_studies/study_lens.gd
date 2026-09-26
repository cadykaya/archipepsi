extends RefCounted
## STUDY 2 -- LENS: THE WALL IS A WINDOW, AND FOCUS MOVES, NOT THE ROOMS.
## (the MAP face)
##
## **The idea.** The map is not a picture on the wall and not a viewport
## boxed in by panels: the wall opens, and the Zone's miniature stands in
## the space behind it, filling the face. Picking a place moves the LENS --
## the miniature glides and closes in as one rigid thing, so no room ever
## moves relative to another -- while everything the pick is not about
## drops back in value. What is known about the place unfolds on a card
## TETHERED to it, not in a column at the side. Picking a neighbour carries
## the lens across, and the passage between them is lit along its real
## path, with its gate and its reason if it is shut.
##
## **Truthful by construction.** Rooms are their committed rectangles at
## their standing heights and connectors their built chains
## (`ZoneController.room_bounds` / `room_joins`, through `MapFace`'s own
## rows); the card's words are `MapFace`'s detail text; gate colours are
## Production's provisional circuit colours; the pulse is its 1.2 Hz. A
## presentation transform here is only ever the whole miniature at once.
##
## In this capture the MOUSE picks first -- the pointer travels, the click
## picks -- then the PAD takes over: D-pad right steps to the next place
## (MapFace.step_place), LB / RB turn, and the prompts follow the device.

const Kit := preload("res://_harness/study_kit.gd")
const Overlay := preload("res://_harness/study_overlay.gd")
const Journal := preload("res://_harness/study_journal.gd")

const WINDOW := Rect2(Vector2(24, 24), Vector2(1232, 672))
const TILT := 55.0                 # degrees the miniature is seen from
const WALL_H := 2.4                # a room's cutaway wall (MapFace)
const PULSE_HZ := 1.2              # MapFace.PULSE_HZ
const FOCUS := Vector3(-0.42, -0.05, -1.75)   # where a picked room is held
const ZOOM := 2.1
const ICON := {"K": "blocked", "P": "circuit", "M": "control"}

var kit: Kit
var overlay: Overlay
var face: Node3D
var map: Node3D
var data: Dictionary
var rooms := {}          # id -> {row, centre (map-local), floor mat, wall mat}
var edges := {}          # edge id -> {row, mat, width}
var blockers := {}       # edge id -> Sprite3D
var picked := ""
var card: Node3D
var card_body: Node3D
var tether: MeshInstance3D
var _rest_pos := Vector3.ZERO
var _rest_scale := 1.0
var _cards := {}         # room id -> Node3D (built on first pick)
var _emph := ""          # the shut passage the lens last crossed


func _init(k: Kit, o: Overlay, content: Dictionary, _layout: Dictionary) -> void:
	kit = k
	overlay = o
	data = content["map"]["all_rooms"]
	for page: String in Kit.PAGES:
		if page != "map":
			kit.face_title(page)
	face = kit.face_of("map")
	kit.face("map")
	_window()
	_build_map()
	Journal.new(kit, kit.face_of("journal"), content["journal"]["walked"])
	tether = MeshInstance3D.new()
	var stick := BoxMesh.new()
	stick.size = Vector3(0.006, 0.006, 1.0)
	tether.mesh = stick
	tether.material_override = kit.own(Kit.INK)
	tether.visible = false
	face.add_child(tether)
	kit.tickers.append(_tick)
	overlay.prompts([["CLICK", "pick a place"], ["C", "back to you"],
		["Q", "turn left"], ["E", "turn right"], ["ESC", "close"]])
	overlay.show_pointer(Vector2(1500, 860))


func title() -> String:
	return "STUDY 2 -- LENS: THE WALL IS A WINDOW, FOCUS MOVES (MAP)"


# ------------------------------------------------------------ building

## The map wall is a frame round an opening, and the room behind it is
## dark, so the miniature is what the eye finds.
func _window() -> void:
	(kit.walls[Kit.PAGES.find("map")] as MeshInstance3D).visible = false
	var w := Kit.PAGE
	for r: Rect2 in [Rect2(Vector2.ZERO, Vector2(w.x, WINDOW.position.y)),
			Rect2(Vector2(0, WINDOW.end.y), Vector2(w.x, w.y - WINDOW.end.y)),
			Rect2(Vector2(0, WINDOW.position.y), Vector2(WINDOW.position.x,
				WINDOW.size.y)),
			Rect2(Vector2(WINDOW.end.x, WINDOW.position.y),
				Vector2(w.x - WINDOW.end.x, WINDOW.size.y))]:
		kit.card(face, r.position, r.size, 0.0, Kit.WALL)
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(12, 8)
	back.mesh = quad
	back.material_override = kit.flat(Color("#0a0c0f"))
	back.position = Vector3(0, 0, -5.5)
	face.add_child(back)
	kit.label(face, "MAP", Vector2(48, 44), 3, Kit.INK_FAINT, 0.004)


func _build_map() -> void:
	map = Node3D.new()
	map.name = "Miniature"
	face.add_child(map)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-60), deg_to_rad(25), 0)
	light.light_energy = 1.1
	face.add_child(light)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for r: Dictionary in data["rooms"]:
		var p: Array = r["rect"]["position"]
		var s: Array = r["rect"]["size"]
		var y := float(r["floor_y"])
		lo = lo.min(Vector3(p[0], y, p[1]))
		hi = hi.max(Vector3(float(p[0]) + float(s[0]), y + WALL_H,
				float(p[1]) + float(s[1])))
	var mid := (lo + hi) * 0.5
	for r: Dictionary in data["rooms"]:
		_room(r, mid)
	for c: Dictionary in data["connectors"]:
		_connector(c, mid)
	for b: Dictionary in data["blockers"]:
		var at: Array = b["at"]
		var sprite := Sprite3D.new()
		sprite.texture = kit.icons[ICON.get(str(b["symbol"]), "blocked")]
		sprite.pixel_size = 0.35
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		# Depth-tested: the wall's frame must hide a gate as it hides a room.
		sprite.render_priority = 2
		sprite.modulate = Color(str(b["colour"]))
		sprite.position = Vector3(float(at[0]) - mid.x, float(at[1]) + 3.0
				- mid.y, -(float(at[2]) - mid.z))
		map.add_child(sprite)
		blockers[str(b["edge_id"])] = sprite
	# At rest the whole Zone fits the window.
	var span := maxf((hi.x - lo.x) / 1.9, (hi.z - lo.z) / 2.6)
	_rest_scale = 0.76 / span
	map.rotation.x = deg_to_rad(TILT)
	map.scale = Vector3.ONE * _rest_scale
	_rest_pos = Vector3(0.0, 0.19, -2.25)
	map.position = _rest_pos


func _room(r: Dictionary, mid: Vector3) -> void:
	var p: Array = r["rect"]["position"]
	var s: Array = r["rect"]["size"]
	var y := float(r["floor_y"]) - mid.y
	var w := float(s[0])
	var d := float(s[1])
	var cx := float(p[0]) + w * 0.5 - mid.x
	var cz := -(float(p[1]) + d * 0.5 - mid.z)
	var floor_mat := _shaded(Color("#48505c") if float(r["floor_y"]) < 10.0
			else Color("#3c434e"))
	var wall_mat := _shaded(Color("#2b3038"))
	_box(Vector3(w, 0.4, d), Vector3(cx, y - 0.2, cz), floor_mat)
	for side: Array in [[Vector3(w, WALL_H, 0.35), Vector3(cx, y + WALL_H * 0.5,
				cz - d * 0.5)],
			[Vector3(w, WALL_H, 0.35), Vector3(cx, y + WALL_H * 0.5, cz + d * 0.5)],
			[Vector3(0.35, WALL_H, d), Vector3(cx - w * 0.5, y + WALL_H * 0.5, cz)],
			[Vector3(0.35, WALL_H, d), Vector3(cx + w * 0.5, y + WALL_H * 0.5, cz)]]:
		_box(side[0], side[1], wall_mat)
	if bool(r.get("here", false)):
		_box(Vector3(0.6, 5.0, 0.6), Vector3(cx, y + 2.5, cz), kit.own(Kit.SIGNAL))
		_box(Vector3(2.6, 0.15, 2.6), Vector3(cx, y + 0.1, cz), kit.own(Kit.SIGNAL))
	rooms[str(r["id"])] = {"row": r, "centre": Vector3(cx, y, cz),
		"floor": floor_mat, "wall": wall_mat,
		"floor_c": floor_mat.albedo_color, "wall_c": wall_mat.albedo_color}


func _connector(c: Dictionary, mid: Vector3) -> void:
	var pts: Array = []
	var path: Array = c["path"]
	var ys: Array = c.get("ys", [])
	for i in path.size():
		var q: Array = path[i]
		var y := float(ys[i]) if i < ys.size() else 0.0
		pts.append(Vector3(float(q[0]) - mid.x, y + 0.25 - mid.y,
				-(float(q[1]) - mid.z)))
	var colour := Color("#8a93a3")
	var circuits: Array = c.get("circuits", [])
	if str(c["state"]) != "open" and not circuits.is_empty():
		colour = Color(str(data["colours"].get(str(circuits[0]), "#9ba5b6")))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		if (b - a).length() < 0.001:
			continue
		var side := (b - a).cross(Vector3.UP).normalized() * 0.9
		st.add_vertex(a - side); st.add_vertex(a + side); st.add_vertex(b + side)
		st.add_vertex(a - side); st.add_vertex(b + side); st.add_vertex(b - side)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var mat := kit.own(colour)
	node.material_override = mat
	map.add_child(node)
	edges[str(c["edge_id"])] = {"row": c, "mat": mat, "colour": colour}


func _shaded(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 1.0
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	map.add_child(node)


# ------------------------------------------------------------ the lens

## Where a room's centre is, in the face's space, given the miniature's
## current transform.
func _room_face_pos(id: String) -> Vector3:
	return map.transform * (rooms[id]["centre"] as Vector3)


func _screen_of(id: String) -> Vector2:
	return kit.camera.unproject_position(
			face.global_transform * _room_face_pos(id))


## The miniature's position that holds room `id` at FOCUS at scale `s`.
func _pos_for(id: String, s: float) -> Vector3:
	var basis := Basis.from_euler(Vector3(deg_to_rad(TILT), 0, 0)).scaled(
			Vector3.ONE * s)
	return FOCUS - basis * (rooms[id]["centre"] as Vector3)


## MOUSE: the lens closes AROUND the room under the pointer -- it stays
## where you clicked it, and the rest of the Zone opens out from it. Nothing
## you clicked drifts away from the hand.
func pick_at_pointer(id: String) -> void:
	var s := _rest_scale * ZOOM
	var basis := Basis.from_euler(Vector3(deg_to_rad(TILT), 0, 0)).scaled(
			Vector3.ONE * s)
	_pick(id, s, _room_face_pos(id) - basis * (rooms[id]["centre"] as Vector3))


## KEYS / PAD (`[` `]`, MapFace's next place you know): the lens CARRIES the
## next place to the focus, and the passage between is lit on the way.
## The pointer is put away, as it is whenever the pad takes over.
func pick_next(id: String) -> void:
	overlay.pointer.visible = false
	var s := _rest_scale * ZOOM
	_pick(id, s, _pos_for(id, s))


func _pick(id: String, s: float, to: Vector3) -> void:
	if picked == id:
		return
	var before := picked
	if card != null:
		var old := card
		kit.go(old, "scale:y", 0.001, 0.12, "in")
		kit.later(0.13, func() -> void: old.visible = false)
	picked = id
	kit.go(map, "scale", Vector3.ONE * s, 0.38)
	kit.go(map, "position", to, 0.38)
	_tone(id, before)
	card = _card_for(id)
	card.visible = true
	card.scale = Vector3(1, 0.001, 1)
	kit.go(card, "scale:y", 1.0, 0.2, "out", 0.3)
	tether.visible = true


## Everything the pick is not about drops back; the picked room and the
## rooms one passage away keep their value.
func _tone(id: String, before: String) -> void:
	var near := {id: true}
	for eid: String in edges:
		var row: Dictionary = edges[eid]["row"]
		var a := str(row["room_a"])
		var b := str(row["room_b"])
		if a == id or b == id:
			near[a] = true
			near[b] = true
			# The passage the lens was just carried across is LIT along its
			# real path: ink if it is open, its own circuit colour raised
			# if it is shut -- and a shut one's gate pulses harder.
			var lit: bool = before != "" and (a == before or b == before)
			var own: Color = edges[eid]["colour"]
			var open := str(row["state"]) == "open"
			kit.go(edges[eid]["mat"], "albedo_color",
					(Kit.INK if open else own.lightened(0.35)) if lit else own, 0.2)
			if lit and not open:
				_emph = eid
		else:
			kit.go(edges[eid]["mat"], "albedo_color",
					(edges[eid]["colour"] as Color).darkened(0.55), 0.25)
	for rid: String in rooms:
		var r: Dictionary = rooms[rid]
		var k := 0.0 if rid == id else 0.25 if near.has(rid) else 0.62
		var lift: Color = Color("#6c7686") if rid == id else r["floor_c"]
		kit.go(r["floor"], "albedo_color", (lift as Color).darkened(k), 0.25)
		kit.go(r["wall"], "albedo_color", Kit.INK_DIM if rid == id
				else (r["wall_c"] as Color).darkened(k), 0.25)


func _card_for(id: String) -> Node3D:
	if _cards.has(id):
		return _cards[id]
	var text: String = data["details"].get(id, id)
	var lines := text.split("\n")
	var node := Node3D.new()
	face.add_child(node)
	var width := 0.0
	for l in lines:
		width = maxf(width, kit.measure(l, 2))
	width = minf(width + 40.0, 560.0)
	var height := 20.0 * float(lines.size()) + 34.0
	for i in lines.size():
		height += 20.0 * float(_extra_rows(lines[i], width - 32.0))
	kit.card(node, Vector2.ZERO, Vector2(width, height), 0.0, Kit.SHEET, 0.96,
			false, true)
	kit.card(node, Vector2.ZERO, Vector2(width, 3), 0.0005, Kit.INK_DIM, 1.0,
			false, true)
	var y := 14.0
	for i in lines.size():
		var colour := Kit.INK if i == 0 else Kit.INK_DIM
		if "blocked" in lines[i]:
			colour = Color("#ffb38a")
		kit.label(node, lines[i], Vector2(16, y), 2, colour, 0.001,
				width - 32.0, false, true)
		y += 20.0 * float(1 + _extra_rows(lines[i], width - 32.0)) \
				+ (6.0 if i == 1 else 0.0)
	node.set_meta("size", Vector2(width, height))
	_cards[id] = node
	return node


func _extra_rows(line: String, width: float) -> int:
	var rows := 1
	var cur := ""
	for word in Kit.sanitize(line).split(" "):
		var trial := word if cur == "" else cur + " " + word
		if kit.measure(trial, 2) > width and cur != "":
			rows += 1
			cur = word
		else:
			cur = trial
	return rows - 1


## Every frame: the card stands beside its room wherever the lens has the
## room this instant, and the tether runs from the card to the floor.
func _tick(t: float) -> void:
	for eid: String in blockers:
		var b: Sprite3D = blockers[eid]
		# Reduced motion holds the pulse still: a shut gate keeps its size
		# (and the emphasised one its 1.7x), it only stops breathing.
		# (Production's own MapFace._pulse does not ask -- see the report.)
		var swing := 1.0 if kit.reduced \
				else 1.0 + 0.3 * sin(t * TAU * PULSE_HZ)
		b.scale = Vector3.ONE * swing * (1.7 if eid == _emph else 1.0)
	if picked == "" or card == null:
		return
	var room := _room_face_pos(picked)
	var eye := Vector3.ZERO
	var dir := (room - eye).normalized()
	var on_wall := eye + dir * ((-Kit.DISTANCE + 0.02) / dir.z)
	var size: Vector2 = card.get_meta("size")
	var s := Kit.px()
	var anchor := on_wall + Vector3(70.0 * s, 150.0 * s, 0.0)
	# Kept inside the window.
	anchor.x = clampf(anchor.x, (WINDOW.position.x - 640.0) * s,
			(WINDOW.end.x - 640.0 - size.x) * s)
	anchor.y = clampf(anchor.y, (360.0 - WINDOW.end.y + size.y) * s,
			(360.0 - WINDOW.position.y - 40.0) * s)
	card.position = Vector3(anchor.x, anchor.y, -Kit.DISTANCE + 0.02)
	var from := card.position + Vector3(0, -size.y * s * card.scale.y, 0)
	var mid := (from + room) * 0.5
	tether.position = mid
	tether.look_at_from_position(mid, room, Vector3.UP)
	tether.scale = Vector3(1, 1, (room - from).length())


# ------------------------------------------------------------ the capture

func timeline() -> Array:
	return [
		[0.0, func() -> void: pass, "rest"],
		[1.2, func() -> void: overlay.point_at(_screen_of("c002"))],
		[1.6, func() -> void:
			overlay.click()
			pick_at_pointer("c002"), "select"],
		# The pad now: MapFace.step_place is DPAD right on a pad (] on the
		# keyboard -- a glyph ui_text lacks), recentre is Y, and the turn
		# keys at the edges become the shoulders.
		[3.6, func() -> void:
			overlay.device(true)
			overlay.prompts([["DPAD", "next place"], ["Y", "back to you"],
				["LB", "turn left"], ["RB", "turn right"], ["START", "close"]])
			pick_next("c003"), "change"],
		[6.0, func() -> void: kit.turn(1), "adjacent"],
		[7.5, func() -> void: kit.turn(-1), "return"],
	]


func duration() -> float:
	return 8.6


func stills() -> Array:
	return [[0.9, "rest -- the wall opens onto the whole Zone; you are the signal pin"],
		[2.5, "select (mouse) -- the lens closes AROUND Arena 1, which stays under the pointer"],
		[4.9, "change (pad, D-pad right) -- carried to Platform Path 1 across the shut span, lit along its path"],
		[6.8, "adjacent -- a turn left: the journal, at rest"],
		[8.3, "return -- the lens is where you left it"]]
