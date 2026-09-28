class_name MapFace
extends Node
## H-3D-MAP, AS THE APPROVED HYBRID (MENU-INT): THE MAP WALL IS A WINDOW,
## AND ONLY THE VIEW MOVES -- the LENS in the enclosure's riveted port
## (`tools/menu_proto/face_map.gd`, `5b03f6d`, the reference; `04` §6-§7).
##
## **One projection, two views.** It asks `MinimapModel` exactly what the
## minimap asks, of the same two sources: shape from the built level
## (`ZoneController.room_bounds`, `room_places`, `room_joins`,
## `plug_positions`), state from the bridge's map (`BridgeClient.zone_map()`).
## The two maps cannot disagree about a room, a name or a gate, because
## neither of them decides one.
##
## **A live, truthful miniature.** The Zone stands behind the wall's
## opening in the box's own world: each room its built envelope at its
## arrival height, a floor and a low wall and never a roof; each connector
## along its built chain; each gate where the bridge's map puts it, its
## circuit's symbol in the circuit's colour; each way back where its device
## stands; and you, where you are. It is ONE object under ONE lens (yaw,
## pitch, target, zoom): every move -- a pick, an orbit, a pan, a zoom, the
## overview -- moves all of it at once, so no room ever moves relative to
## another.
##
## **Render-only.** Meshes, sprites and words in the box's world: no
## scripts, no collision, no areas, no sounds, no timers, and nothing copied
## out of the Zone. Building it sends nothing and simulates nothing (§7).
##
## * **Short answers first.** Picking a place names it and tags each of its
##   ways out, at the way: open, shut, or "a way on, not yet walked".
## * **The long answer is asked for.** ENTER / A (or clicking the name)
##   docks this map's own detail on a warm tag at the window's edge.
## * **Overview is the reset** (C / Home / Y): the whole known Zone in the
##   window, you in it, nothing picked.
## * **Floors** (PgUp / PgDn, d-pad up / down): every floor, yours at full
##   tone; then one floor with the others dimmed; then that floor alone.
## * **Four marks, four shapes.** Focus is a frame round the room (signal).
##   A circuit is its own symbol on its gate (the circuit's colour). You are
##   the figure standing where you are (ink). The Journal's link is a ring.
## * **Ordinary travel never moves the view.** Shown a Journal entry, it
##   frames what the entry names and keeps the view it had: BACK TO YOUR
##   VIEW (Backspace / B, or the words on the glass) puts it back.
## * **Nothing unknown is ever shown**: not a room, a name, an edge mark or
##   a framing. Reduced motion: every lens move is a cut; gates hold still.

const WINDOW := Rect2(Vector2(40, 90), Vector2(1200, 604))
const PANEL_W := 340.0
const TILT := 55.0
## How high a room's cutaway wall stands above its floor.
const WALL_HEIGHT := 2.4
const YAW_STEP := 15.0
const PITCH_STEP := 7.5
const ZOOM_STEP := 1.25
const MIN_PITCH := 20.0
const MAX_PITCH := 85.0
## The lens's zoom, relative to the overview's (`fit`).
const MIN_ZOOM := 0.6
const MAX_ZOOM := 8.0
const PICK_ZOOM := 2.1
const DEPTH := -2.25                 # the miniature's centre, behind the wall
const PULSE_HZ := 1.2
const PULSE_SWING := 0.3
const STICK_DEADZONE := 0.25
## Provisional circuit symbols (Glyph handoff §4): K a key, P power or a
## setting, M a mechanism. An Echo to equip (E) and a gate only its room
## can tell (?) keep their letters.
const SYMBOL_ICON := {"K": "blocked", "P": "circuit", "M": "control"}
const MINI_LAYER := 2                # the miniature's own light lights this
## The rooms' tones, as the approved captures show them. The prototype's
## #4a525f floor and #2c3139 wall were reviewed as GL Compatibility drew
## its box meshes; the lens's own room mesh, under the game's renderer
## (and under Compatibility too), drew them far darker: a floor at
## (67, 75, 87) against the approved (106, 117, 136), a wall at (29, 32,
## 38) against (40, 46, 54). Calibrated in linear light so the game draws
## the approved tones (MENU-INT M5; the measurements are in the ledger).
const FLOOR_TONE := Color("#747f94")
const WALL_TONE := Color("#3b444f")

## The lens: what `go` animates. Every field moves the miniature as a whole.
class Lens:
	var yaw := 0.0
	var pitch := 55.0
	var target := Vector3.ZERO       # miniature-space point at the window's centre
	var zoom := 1.0
	var shift := 0.0                 # page px the centre slides (detail open)


## The Zone this map is of, or `null` (the Hub has no map).
var zone: ZoneController = null
var kit: MenuKit
var shell: MenuShell
var face: Node3D
var lens := Lens.new()
var fit := 1.0
var mid := Vector3.ZERO
## The place picked for inspection (a room id), or "".
var picked := ""
var hovered := ""
var expanded := false
## -1 shows every floor; otherwise the index of the one floor stepped to.
var floor_filter := -1
## With a floor stepped to: the others hidden (true), or dimmed (false).
var floor_alone := false
var link := {}                       # the Journal's link, when one is active
var followed := {}                   # the link the Map was last shown, if any
## THIS ZONE'S CIRCUIT COLOURS, the minimap's (`MinimapModel.circuit_colours`).
var colours := {}
## The last build's cost in microseconds, and how many builds there have
## been: the cache is measured, not assumed.
var build_usec := 0
var builds := 0

var yaw: float:
	get:
		return lens.yaw
var pitch: float:
	get:
		return lens.pitch
var zoom: float:
	get:
		return lens.zoom
## The place picked (the old wall's name for it).
var selected: String:
	get:
		return picked

var _rooms: Array = []               # MinimapModel.rooms
var _connectors: Array = []          # MinimapModel.connectors
var _floors: Array = []
var _room_band := {}
var _signature := 0
var _dirty := true
var _open := false
var _front := false
var _map: Node3D                     # the lens's frame
var _space: Node3D                   # map coordinates, inside the lens
var _mini := {}                      # room id -> {row, centre, w, d, node, floor, wall, ...}
var _edges := {}                     # edge -> {row, mat, colour, mark}
var _gates := {}                     # edge -> Node3D (a sprite, or a letter)
var _plugs := {}                     # edge -> Sprite3D (a way back)
var _labels: Node3D                  # the glass: tags, placed every frame
var _tags: Array = []                # {node, size, kind, ref, text, rect}
var _panel: Node3D
var _frame_focus: Node3D
var _frame_hover: Node3D
var _ring: Node3D
var _you: Sprite3D
var _you_room := ""
var _hub_note: Label3D
var _floor_note: Node3D
var _t := 0.0
var _drag_moved := 0.0
var _bounds: Array = [Vector3.ZERO, Vector3.ZERO]
var _home := Vector3.ZERO
var _framed := false
var _pulse := 1.0
var _return := {}                    # the view before it was shown an entry
var _glass_back: Node3D              # BACK TO YOUR VIEW, on the glass
var _back_rect := Rect2()
var _press_used := false             # a press the glass took: its release picks nothing
var _edge_marks := {}                # "you" / "picked" -> {node, arrow, label, ref}
var _goal := {}                      # where the lens is gliding to


func _ready() -> void:
	name = "MapFace"
	BridgeClient.snapshot_received.connect(_on_snapshot)


func setup(k: MenuKit, s: MenuShell) -> void:
	kit = k
	shell = s
	face = shell.face_node("map")
	shell.wall("map").visible = false
	_window()
	_map = Node3D.new()
	_map.name = "Miniature"
	face.add_child(_map)
	_labels = Node3D.new()
	_labels.name = "Glass"
	face.add_child(_labels)
	_hub_note = kit.label(face, "THE HUB HAS NO MAP. EVERY ZONE HAS ONE.",
			WINDOW.position + Vector2(40, 40), 3, MenuKit.INK_DIM, 0.012)
	_hub_note.name = "HubNote"
	_floor_note = Node3D.new()
	_floor_note.name = "Floors"
	face.add_child(_floor_note)
	_rebuild()


## The wall is a frame round an opening, with a reveal: the opening has a
## depth, so it reads as cut into the wall and not painted on it.
func _window() -> void:
	var w := MenuKit.PAGE
	for r: Rect2 in [Rect2(Vector2.ZERO, Vector2(w.x, WINDOW.position.y)),
			Rect2(Vector2(0, WINDOW.end.y), Vector2(w.x, w.y - WINDOW.end.y)),
			Rect2(Vector2(0, WINDOW.position.y), Vector2(WINDOW.position.x,
				WINDOW.size.y)),
			Rect2(Vector2(WINDOW.end.x, WINDOW.position.y),
				Vector2(w.x - WINDOW.end.x, WINDOW.size.y))]:
		var frame := kit.card(face, r.position, r.size, 0.0, kit.wall_patch(r))
		frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The wall's top and bottom edges stop a centimetre short of the slabs.
	# Shut that gap here too, or a zoomed miniature shows through above the
	# wall.
	for r: Rect2 in [Rect2(Vector2(0, -60), Vector2(w.x, 60)),
			Rect2(Vector2(0, w.y), Vector2(w.x, 60))]:
		kit.card(face, r.position, r.size, 0.0, kit.lit(MenuKit.POST))
	var depth := 0.05
	var s := MenuKit.px()
	for side: Array in [
			[Vector3(WINDOW.size.x * s, 0.002, depth), WINDOW.position
				+ Vector2(WINDOW.size.x * 0.5, 0)],
			[Vector3(WINDOW.size.x * s, 0.002, depth), WINDOW.position
				+ Vector2(WINDOW.size.x * 0.5, WINDOW.size.y)],
			[Vector3(0.002, WINDOW.size.y * s, depth), WINDOW.position
				+ Vector2(0, WINDOW.size.y * 0.5)],
			[Vector3(0.002, WINDOW.size.y * s, depth), WINDOW.position
				+ Vector2(WINDOW.size.x, WINDOW.size.y * 0.5)]]:
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = side[0]
		node.mesh = box
		node.material_override = kit.lit(MenuKit.POST)
		node.position = MenuKit.at(side[1], -depth * 0.5)
		face.add_child(node)
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(14, 9)
	back.mesh = quad
	back.material_override = kit.flat(Color("#07090b"))
	back.position = Vector3(0, 0, -6.0)
	face.add_child(back)
	# THE PORT: original station hardware, the enclosure's heaviest frame,
	# riveted, round the opening
	var m := MenuParts.mat(MenuParts.CAB_HI, 0.35, 0.5)
	for b: Rect2 in [Rect2(WINDOW.position.x - 14, WINDOW.position.y - 14,
				WINDOW.size.x + 28, 14),
			Rect2(WINDOW.position.x - 14, WINDOW.end.y, WINDOW.size.x + 28, 14),
			Rect2(WINDOW.position.x - 14, WINDOW.position.y, 14, WINDOW.size.y),
			Rect2(WINDOW.end.x, WINDOW.position.y, 14, WINDOW.size.y)]:
		MenuParts.block(face, b, 0.0, 0.016, m)
	for p: Vector2 in [Vector2(WINDOW.end.x + 7, WINDOW.position.y - 7),
			Vector2(WINDOW.position.x - 7, WINDOW.end.y + 7),
			WINDOW.end + Vector2(7, 7)]:
		MenuParts.rivet(face, p, 0.016)
	# The window's glass: what the pointer meets on its way into the port.
	kit.pick_rect("map", face, WINDOW, 0.0, 0.0006, "window")
	# The miniature's own light: it lights the miniature only (the box's
	# lamp lights the box only).
	var light := DirectionalLight3D.new()
	light.name = "MiniatureLight"
	light.rotation = Vector3(deg_to_rad(-62), deg_to_rad(28), 0)
	light.light_energy = 0.9
	light.light_cull_mask = MINI_LAYER
	face.add_child(light)


# ============================================================ the API

## Follow a Zone, or nothing (`null`, in the Hub). Another Zone resets
## the view; the same Zone keeps it.
func bind(controller: ZoneController) -> void:
	var same := controller != null and zone != null \
			and is_instance_valid(zone) and controller == zone
	zone = controller
	if zone != null and not zone.chamber_entered.is_connected(_on_entered):
		zone.chamber_entered.connect(_on_entered)
	if not same:
		floor_filter = -1
		floor_alone = false
		picked = ""
		expanded = false
		link = {}
		followed = {}
		_return = {}
		_framed = false
		_signature = 0
	_dirty = true
	if _open:
		refresh()


## Rebuild the miniature if what it shows has changed; otherwise nothing.
func refresh() -> void:
	_dirty = false
	if zone == null or not is_instance_valid(zone):
		if not _rooms.is_empty() or builds == 0 or _signature != 0:
			_rooms = []
			_connectors = []
			_floors = []
			_signature = 0
			_rebuild()
		return
	var zone_map := BridgeClient.zone_map()
	if str(zone_map.get("zone_id", "")) != zone.zone_id:
		zone_map = {"rooms": [], "connectors": []}
	var floors := {}
	for rid: Variant in zone.room_places:
		floors[rid] = ((zone.room_places[rid] as Dictionary).get("arrival",
				Vector3.ZERO) as Vector3).y
	var rooms := MinimapModel.rooms(zone_map, zone.room_bounds,
			zone.rooms_entered(), zone.current_room(), floors)
	var connectors := MinimapModel.connectors(zone_map, zone.room_joins,
			zone.plug_positions)
	var signature := hash(str([zone.zone_id, rooms, connectors]))
	if signature == _signature:
		return
	_signature = signature
	_rooms = rooms
	_connectors = connectors
	colours = MinimapModel.circuit_colours(zone.zone)
	var started := Time.get_ticks_usec()
	_rebuild()
	build_usec = Time.get_ticks_usec() - started
	builds += 1


## Rebuilt now if a snapshot or a step has changed what it shows -- for a
## wall that reads this one's rows (the Journal) before its next frame.
func fresh() -> void:
	if _dirty:
		refresh()


## The overview (the old wall's "back to you"): nothing picked, the whole
## known Zone in the window, you in it.
func recentre() -> void:
	overview()


func rooms_shown() -> Array:
	return _rooms


func connectors_shown() -> Array:
	return _connectors


## The standing heights of the floors this map knows, lowest first.
func floors() -> Array:
	return _floors


## Which floor the player stands on (an index into `floors()`), or -1.
func player_floor() -> int:
	for row: Dictionary in _rooms:
		if bool(row.get("here", false)):
			return band_of_room(str(row["id"]))
	return _band_of(_player_floor_y())


## The blockers the miniature shows: `{edge_id, state, symbol, colour,
## at (Vector3), visible}`, one per blocked or unknown connector drawn.
func blockers_shown() -> Array:
	var out: Array = []
	for eid: String in _gates:
		var node: Node3D = _gates[eid]
		out.append({"edge_id": eid, "state": node.get_meta("state"),
				"symbol": node.get_meta("symbol"),
				"colour": node.get_meta("colour"),
				"at": node.get_meta("at"), "visible": node.visible})
	return out


## The 3D points a connector was built along (the built chain's).
func connector_points(edge_id: String) -> Array:
	var e: Dictionary = _edges.get(edge_id, {})
	return e.get("points", [])


## The miniature's root, for the suite to take a census of.
func world_root() -> Node3D:
	return _map


func room_node(id: String) -> MeshInstance3D:
	return (_mini.get(id, {}) as Dictionary).get("node")


func plug_node(edge_id: String) -> Node3D:
	return _plugs.get(edge_id)


func blocker_node(edge_id: String) -> Node3D:
	return _gates.get(edge_id)


func hub_note() -> Label3D:
	return _hub_note


## This map's own detail for the picked place (what the warm tag says).
func detail_text() -> String:
	return _describe(picked) if picked != "" else ""


## The places this map knows, in the order [ and ] step through them.
func known() -> Array:
	var out: Array = []
	for row: Dictionary in _rooms:
		out.append(str(row["id"]))
	out.sort()
	return out


## Every floor; then, a step at a time, one floor with the others dimmed,
## then that floor alone; from every floor the first step is yours, and
## stepping past the top or the bottom shows every floor again.
func step_floor(step: int) -> void:
	if _floors.size() < 2:
		floor_filter = -1
		floor_alone = false
		kit.cue("edge")
		_refresh_marks()
		return
	if floor_filter == -1:
		floor_filter = maxi(player_floor(), 0)
		floor_alone = false
	elif not floor_alone:
		floor_alone = true
	else:
		floor_filter += step
		floor_alone = false
		if floor_filter < 0 or floor_filter >= _floors.size():
			floor_filter = -1
	kit.cue("tick", 1.0 if step > 0 else 0.9)
	_refresh_marks()


## The next (+1) or previous (-1) place you know, picked for inspection.
func step_place(step: int) -> void:
	var ids := known()
	if ids.is_empty():
		kit.cue("edge")
		return
	var at := ids.find(picked)
	at = (0 if step > 0 else ids.size() - 1) if at == -1 \
			else posmod(at + step, ids.size())
	pick(ids[at])


## Inspect a known place: the lens closes on it and its short answers are
## tagged on the glass.
func pick(id: String, keep_screen := false) -> void:
	if not _mini.has(id):
		return
	kit.cue("tick")
	picked = id
	var c: Vector3 = _mini[id]["centre"]
	var z := maxf(lens.zoom, fit * PICK_ZOOM)
	if keep_screen:
		_set_lens(lens.yaw, lens.pitch, _target_keeping(c, z), z)
	else:
		_set_lens(lens.yaw, lens.pitch, c, z)
	_refresh_marks()


func turn_view(yaw_step: float, pitch_step: float) -> void:
	_set_lens(_heading("yaw") + yaw_step, _heading("pitch") + pitch_step,
			_heading("target"), _heading("zoom"))


## `factor` < 1 zooms in (the old wall's distance factor, inverted: the
## lens's zoom is a magnification).
func zoom_view(factor: float) -> void:
	_set_lens(_heading("yaw"), _heading("pitch"), _heading("target"),
			_heading("zoom") / factor)


## Pan in the ground plane, as seen through the lens: +x right, +y ahead.
func pan_view(right: float, ahead: float) -> void:
	var y := deg_to_rad(_heading("yaw"))
	var side := Vector3(cos(y), 0, -sin(y))
	var fwd := Vector3(-sin(y), 0, -cos(y))
	var step := 18.0 / float(_heading("zoom")) * 0.02
	_set_lens(_heading("yaw"), _heading("pitch"), _heading("target")
			+ (side * right + fwd * ahead) * step * 40.0, _heading("zoom"))


## Where the lens is headed -- or is, when still. A step is taken from
## there, so presses in quick succession (a held key's repeats) add up
## instead of each starting again from wherever the glide had got to.
func _heading(prop: String) -> Variant:
	if kit.moving(lens, prop) and _goal.has(prop):
		return _goal[prop]
	return lens.get(prop)


## The lens's zoom limits, as magnifications.
func zoom_limits() -> Vector2:
	return Vector2(fit * MIN_ZOOM, fit * MAX_ZOOM)


# ============================================================ building

## Map space (x, y, z) -> the lens's space: centred on the known rooms, and
## +z runs away from the entrance, which is UP the window.
func m(v: Vector3) -> Vector3:
	return Vector3(v.x - mid.x, v.y - mid.y, -(v.z - mid.z))


func _rebuild() -> void:
	if _map == null:
		return
	for n: Node in _map.get_children():
		_map.remove_child(n)
		n.queue_free()
	_mini.clear()
	_edges.clear()
	_gates.clear()
	_plugs.clear()
	_you = null
	_floors = _floor_bands()
	var has_zone := zone != null and is_instance_valid(zone)
	_hub_note.visible = not has_zone
	# The overview frames what is KNOWN: the rooms. A way into the unknown
	# runs out of the frame, as far as the map draws it and no further.
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for r: Dictionary in _rooms:
		var rect: Rect2 = r["rect"]
		var y := float(r["floor_y"])
		lo = lo.min(Vector3(rect.position.x, y, rect.position.y))
		hi = hi.max(Vector3(rect.end.x, y + WALL_HEIGHT, rect.end.y))
	if _rooms.is_empty():
		lo = Vector3.ZERO
		hi = Vector3.ZERO
	mid = (lo + hi) * 0.5
	_bounds = [m(lo), m(hi)]
	_space = Node3D.new()
	_space.name = "Zone"
	if has_zone:
		_map.add_child(_space)
		for r: Dictionary in _rooms:
			_room(r)
		for c: Dictionary in _connectors:
			_connector(c)
		_you = _you_mark()
	_frame_focus = Node3D.new()
	_frame_hover = Node3D.new()
	_ring = Node3D.new()
	if has_zone:
		for n: Node3D in [_frame_focus, _frame_hover, _ring]:
			_map.add_child(n)
	for n: Node in _labels.get_children():
		n.queue_free()
	_tags.clear()
	_edge_marks.clear()
	if picked != "" and not _mini.has(picked):
		picked = ""
		expanded = false
	_fit_overview()
	if not _framed and has_zone and not _rooms.is_empty():
		_framed = true
		_overview(true)
	_apply()
	_refresh_marks()


## A room: its floor and a low wall, no roof, its built envelope at its
## arrival height -- every vertex the Zone's own, carried into the lens's
## space by `m` (a mirror, so each triangle is wound afresh to face its
## own normal: the light falls on a floor's top, not its underside).
func _room(r: Dictionary) -> void:
	var id := str(r["id"])
	var rect: Rect2 = r["rect"]
	var y := float(r["floor_y"])
	var floor_mat := kit.lit(FLOOR_TONE, true)
	var wall_mat := kit.lit(WALL_TONE, true)
	var node := MeshInstance3D.new()
	node.name = "Room_%s" % id
	node.mesh = _room_mesh(rect, y, floor_mat, wall_mat)
	node.layers = MINI_LAYER
	node.set_meta("floor_y", y)
	node.set_meta("here", bool(r.get("here", false)))
	node.set_meta("envelope", AABB(Vector3(rect.position.x, y, rect.position.y),
			Vector3(rect.size.x, WALL_HEIGHT, rect.size.y)))
	_space.add_child(node)
	# The floor's own thickness, under it: a solid read from a low angle.
	var base := MeshInstance3D.new()
	base.name = "Base"
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x, 0.4, rect.size.y)
	base.mesh = box
	base.material_override = floor_mat
	base.layers = MINI_LAYER
	base.position = m(Vector3(rect.get_center().x, y - 0.2, rect.get_center().y))
	node.add_child(base)
	_mini[id] = {"row": r, "centre": m(Vector3(rect.get_center().x, y,
		rect.get_center().y)), "w": rect.size.x, "d": rect.size.y, "node": node,
		"floor": floor_mat, "wall": wall_mat, "floor_y": y,
		"floor_c": floor_mat.albedo_color, "wall_c": wall_mat.albedo_color}


## The floor, and four walls WALL_HEIGHT high and 0.35 thick, inside the
## envelope and open at the top: no triangle lies in its top plane.
func _room_mesh(rect: Rect2, floor_y: float, floor_mat: Material,
		wall_mat: Material) -> ArrayMesh:
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var y0 := floor_y
	var y1 := floor_y + WALL_HEIGHT
	var t := minf(0.35, minf(rect.size.x, rect.size.y) * 0.25)
	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	_face4(fv, fn, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1),
			Vector3(x0, y0, z1)], Vector3.UP)
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	# Each wall: its outer face on the envelope, its inner face `t` in.
	for side: Array in [
			[Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(0, 0, 1)],
			[Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3(0, 0, -1)],
			[Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3(1, 0, 0)],
			[Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(-1, 0, 0)]]:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var inward: Vector3 = side[2]
		var ai := a + inward * t
		var bi := b + inward * t
		_face4(wv, wn, [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z),
				Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)], -inward)
		_face4(wv, wn, [Vector3(ai.x, y0, ai.z), Vector3(bi.x, y0, bi.z),
				Vector3(bi.x, y1, bi.z), Vector3(ai.x, y1, ai.z)], inward)
	var mesh := ArrayMesh.new()
	for part: Array in [[fv, fn, floor_mat], [wv, wn, wall_mat]]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part[0]
		arrays[Mesh.ARRAY_NORMAL] = part[1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, part[2])
	return mesh


## A quad of the Zone's own points, carried into the lens's space, facing
## the Zone's own normal `n` (carried too).
func _face4(verts: PackedVector3Array, norms: PackedVector3Array, q: Array,
		n: Vector3) -> void:
	var a := m(q[0])
	var b := m(q[1])
	var c := m(q[2])
	var d := m(q[3])
	var nn := Vector3(n.x, n.y, -n.z)
	MenuParts._tri(verts, norms, a, b, c, nn)
	MenuParts._tri(verts, norms, a, c, d, nn)


## A point of the Zone, in the lens's space: what a suite compares the
## miniature's shapes with.
func to_lens(v: Vector3) -> Vector3:
	return m(v)


## A connector along its built chain, in 3D: a flat band 1.6 m wide, its
## gate where the bridge's map puts it, or its way back where the device
## stands.
func _connector(c: Dictionary) -> void:
	var eid := str(c["edge_id"])
	var path: PackedVector2Array = c["path"]
	var ys: PackedFloat32Array = c["ys"]
	var points: Array = []
	for i in path.size():
		points.append(Vector3(path[i].x, ys[i] if i < ys.size() else 0.0, path[i].y))
	var state := str(c["state"])
	var circuits: Array = c.get("circuits", [])
	var colour := Color("#8a93a3")
	if state != "open":
		colour = colours.get(str(circuits[0]) if not circuits.is_empty() else "",
				Color(0.85, 0.85, 0.85))
	var mat := kit.lit(colour, true)
	if points.size() >= 2:
		var lifted: Array = []
		for p: Vector3 in points:
			lifted.append(m(p + Vector3(0, 0.3, 0)))
		var node := MeshInstance3D.new()
		node.name = "Connector_%s" % _node_name(eid)
		node.mesh = MenuKit.strip(lifted, 1.6, Vector3.UP)
		node.material_override = mat
		node.layers = MINI_LAYER
		node.set_meta("edge_id", eid)
		node.set_meta("points", points)
		node.set_meta("rooms", [str(c["room_a"]), str(c["room_b"])])
		_space.add_child(node)
	var mark := _mark3(c, points)
	_edges[eid] = {"row": c, "mat": mat, "colour": colour, "points": points,
		"mark": m(mark) if mark != Vector3.INF else Vector3.INF}
	if mark == Vector3.INF:
		return
	if state != "open":
		_gate(eid, c, mark, colour)
	elif points.size() < 2:
		# A way back: the device, not a corridor -- the way-out symbol where
		# it stands.
		var s := _billboard_sprite("exit", MenuKit.INK)
		s.name = "WayBack_%s" % _node_name(eid)
		s.position = m(mark + Vector3(0, 2.2, 0))
		s.set_meta("edge_id", eid)
		s.set_meta("rooms", [str(c["room_a"])])
		_map.add_child(s)
		_plugs[eid] = s


## Where a connector's mark stands in 3D: halfway along its path by
## length, or where its device is.
func _mark3(c: Dictionary, points: Array) -> Vector3:
	if points.size() >= 2:
		var total := 0.0
		for i in range(1, points.size()):
			total += (points[i - 1] as Vector3).distance_to(points[i])
		var half := total * 0.5
		var walked := 0.0
		for i in range(1, points.size()):
			var a: Vector3 = points[i - 1]
			var b: Vector3 = points[i]
			var step := a.distance_to(b)
			if walked + step >= half and step > 0.0:
				return a.lerp(b, (half - walked) / step)
			walked += step
		return points[points.size() - 1]
	var at: Vector2 = c["mark_at"]
	if at == Vector2.INF:
		return Vector3.INF
	var ys: PackedFloat32Array = c["ys"]
	return Vector3(at.x, ys[0] if not ys.is_empty() else 0.0, at.y)


## A gate: its circuit's symbol, in the circuit's colour, standing over
## the passage it holds. A gate whose state only the room can tell is a
## "?"; one an Echo opens, an "E".
func _gate(eid: String, c: Dictionary, at: Vector3, colour: Color) -> void:
	var state := str(c["state"])
	var letter := "?" if state == "unknown" else str(c.get("symbol", ""))
	var node: Node3D
	if SYMBOL_ICON.has(letter):
		node = _billboard_sprite(str(SYMBOL_ICON[letter]), colour)
	else:
		var l := Label3D.new()
		l.font = kit.text_font
		l.font_size = 8
		l.pixel_size = 0.34 / 8.0 * 12.0 / 8.0
		l.text = letter if letter != "" else "?"
		l.modulate = colour
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.shaded = false
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		l.render_priority = 2
		l.outline_size = 0
		node = l
	node.name = "Blocker_%s" % _node_name(eid)
	node.position = m(at + Vector3(0, 3.0, 0))
	node.set_meta("edge_id", eid)
	node.set_meta("state", state)
	node.set_meta("symbol", letter)
	node.set_meta("colour", colour)
	node.set_meta("at", at)
	node.set_meta("rooms", [str(c["room_a"]), str(c["room_b"])])
	_map.add_child(node)
	_gates[eid] = node


func _billboard_sprite(icon: String, colour: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = kit.icons.get(icon)
	s.pixel_size = 0.34
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.render_priority = 2
	s.modulate = colour
	return s


## An edge id as a node name: Godot does not allow ':' in one, so the
## id itself travels as the node's `edge_id` meta.
static func _node_name(edge_id: String) -> String:
	return edge_id.replace(":", "_")


## You: the figure, standing where you are, and the word. Ink, not signal.
func _you_mark() -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "You"
	s.texture = kit.icons.get("you")
	s.pixel_size = 0.42
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.modulate = MenuKit.INK
	_map.add_child(s)
	_you_room = ""
	for row: Dictionary in _rooms:
		if bool(row.get("here", false)):
			_you_room = str(row["id"])
	_place_player()
	return s


## The figure follows the player, live: where they stand, on the floor
## they stand on.
func _place_player() -> void:
	if _you == null:
		return
	var at := Vector3.INF
	if zone != null and is_instance_valid(zone) and zone.player != null:
		at = zone.player.global_position
	elif _mini.has(_you_room):
		var r: Dictionary = _mini[_you_room]
		var rect: Rect2 = (r["row"] as Dictionary)["rect"]
		at = Vector3(rect.get_center().x, float(r["floor_y"]), rect.get_center().y)
	if at == Vector3.INF:
		_you.visible = false
		return
	_you.visible = true
	_you.position = m(at + Vector3(0, 2.6, 0))
	_you.set_meta("at", at)


# ------------------------------------------------------------ the floors

## The floors of the rooms found, lowest first: a room whose standing
## height is within `MinimapModel.FLOOR_STEP` of a floor's is on it.
func _floor_bands() -> Array:
	var rows := _rooms.duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["floor_y"]) < float(b["floor_y"]))
	var out: Array = []
	_room_band.clear()
	for row: Dictionary in rows:
		var y := float(row["floor_y"])
		if out.is_empty() or y - float(out[out.size() - 1]) \
				>= MinimapModel.FLOOR_STEP:
			out.append(y)
		_room_band[str(row["id"])] = out.size() - 1
	return out


## The floor a room found is on.
func band_of_room(room_id: String) -> int:
	return int(_room_band.get(room_id, -1))


## The floor a height is on: the highest whose floor it stands at or
## above (a body a little below its floor still counts).
func _band_of(y: float) -> int:
	var at := -1
	for i in _floors.size():
		if y >= float(_floors[i]) - 0.5:
			at = i
	return at


func _player_floor_y() -> float:
	for row: Dictionary in _rooms:
		if bool(row.get("here", false)):
			return float(row.get("floor_y", 0.0))
	if zone != null and is_instance_valid(zone) and zone.player != null:
		return zone.player.global_position.y
	return 0.0


## A room's floor, as the view is showing floors: "shown" at full tone,
## "dimmed", or "hidden".
func _floor_view(id: String) -> String:
	var band := band_of_room(id)
	if floor_filter == -1:
		return "shown" if band == player_floor() or _floors.size() < 2 else "dimmed"
	if band == floor_filter:
		return "shown"
	return "hidden" if floor_alone else "dimmed"


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
	if _rooms.is_empty():
		fit = 0.02
		_home = Vector3.ZERO
	else:
		for i in 3:
			_apply(false)
			var r := _projected(_bounds[0], _bounds[1])
			var area := WINDOW.grow(-50)
			var k := minf(area.size.x / maxf(r.size.x, 1.0),
					area.size.y / maxf(r.size.y, 1.0))
			lens.zoom *= k
			_apply(false)
			r = _projected(_bounds[0], _bounds[1])
			# Nudge the target so the projected centre sits on the window's.
			var off := WINDOW.get_center() - r.get_center()
			var s := MenuKit.px() * absf(DEPTH) / lens.zoom
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
	if not _framed:
		lens.zoom = fit
		lens.target = _home


## Page-px rectangle a box covers, seen from the eye.
func _projected(lo: Vector3, hi: Vector3) -> Rect2:
	var r := Rect2()
	var first := true
	for i in 8:
		var corner := Vector3(lo.x if i & 1 == 0 else hi.x,
				lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z)
		var page := _page_of(corner)
		if first:
			r = Rect2(page, Vector2.ZERO)
			first = false
		else:
			r = r.expand(page)
	return r


## A point in the miniature, on the page (projected from the eye).
func _page_of(local: Vector3) -> Vector2:
	var p := _map.transform * local
	var w := p * (MenuKit.DISTANCE / maxf(-p.z, 0.001))
	return Vector2(w.x / MenuKit.px() + MenuKit.PAGE.x * 0.5,
			MenuKit.PAGE.y * 0.5 - w.y / MenuKit.px())


func _set_lens(to_yaw: float, to_pitch: float, to_target: Vector3, to_zoom: float,
		at_once := false) -> void:
	var t := 0.0 if at_once else 0.38
	var limits := zoom_limits()
	_goal = {"yaw": to_yaw, "pitch": clampf(to_pitch, MIN_PITCH, MAX_PITCH),
		"target": to_target, "zoom": clampf(to_zoom, limits.x, limits.y)}
	for prop: String in _goal:
		kit.go(lens, prop, _goal[prop], t)


## The one transform: the miniature, turned and tilted about the lens's
## target, scaled, and set behind the window's centre.
func _apply(tags := true) -> void:
	if _map == null:
		return
	var basis := Basis.from_euler(Vector3(deg_to_rad(lens.pitch),
			deg_to_rad(lens.yaw), 0), EULER_ORDER_YXZ).scaled(
			Vector3.ONE * lens.zoom)
	var centre := MenuKit.at(WINDOW.get_center() + Vector2(lens.shift, 0), 0.0)
	centre.z = DEPTH
	_map.transform = Transform3D(basis, centre - basis * lens.target)
	if tags:
		_layout_tags()


## Where the lens must sit to hold `local` still on screen while the zoom
## goes from its current value to `to_zoom` -- the pick that closes AROUND
## the pointer.
func _target_keeping(local: Vector3, to_zoom: float) -> Vector3:
	return local - (local - lens.target) * (lens.zoom / to_zoom)


func overview() -> void:
	kit.cue("tick", 0.8)
	picked = ""
	expanded = false
	floor_filter = -1
	floor_alone = false
	kit.go(lens, "shift", 0.0, 0.3)
	_overview()
	_refresh_marks()


func toggle_detail() -> void:
	if picked == "":
		return
	expanded = not expanded
	kit.cue("tick", 1.1 if expanded else 0.9)
	# The lens slides the place clear of the tag; nothing is covered.
	kit.go(lens, "shift", -PANEL_W * 0.5 if expanded else 0.0, 0.3)
	_refresh_marks()
	if can_return():
		_build_glass_back()       # the pad's B means "less" while this is open


# ------------------------------------------------------------ picking

## The known room a ray through the window meets first, or "".
func _ray_pick(hit: Dictionary) -> String:
	if hit.is_empty() or not hit.has("origin"):
		return ""
	var p: Vector2 = hit.get("at", Vector2.INF)
	if p == Vector2.INF or not WINDOW.has_point(p) \
			or (expanded and p.x > WINDOW.end.x - PANEL_W):
		return ""
	var inv := (face.global_transform * _map.transform).affine_inverse()
	var o: Vector3 = inv * (hit["origin"] as Vector3)
	var d: Vector3 = (inv.basis * (hit["along"] as Vector3)).normalized()
	var best := ""
	var nearest := INF
	for id: String in _mini:
		var r: Dictionary = _mini[id]
		if _floor_view(id) == "hidden":
			continue
		var c: Vector3 = r["centre"]
		var lo := c + Vector3(-float(r["w"]) * 0.5, -0.4, -float(r["d"]) * 0.5)
		var hi := c + Vector3(float(r["w"]) * 0.5, WALL_HEIGHT, float(r["d"]) * 0.5)
		var t := MenuKit.ray_box(o, d, lo, hi)
		if t >= 0.0 and t < nearest:
			nearest = t
			best = id
	return best


# ------------------------------------------------------------ marks

## Re-tone the rooms and ways, show or hide them by floor, and rebuild the
## short labels and frames for what is picked / hovered / linked.
func _refresh_marks() -> void:
	var neighbours := {}
	if picked != "":
		for eid: String in _edges:
			var row: Dictionary = _edges[eid]["row"]
			if str(row["room_a"]) == picked or str(row["room_b"]) == picked:
				neighbours[str(row["room_a"])] = true
				neighbours[str(row["room_b"])] = true
	var shown := {}
	for id: String in _mini:
		var r: Dictionary = _mini[id]
		var view := _floor_view(id)
		var node: MeshInstance3D = r["node"]
		node.visible = view != "hidden"
		node.set_meta("solid", view == "shown")
		node.set_meta("floor_view", view)
		shown[id] = view != "hidden"
		var k := 0.0
		if view == "dimmed":
			k = 0.8 if floor_filter != -1 else 0.35
		elif picked != "" and id != picked and not neighbours.has(id):
			k = 0.45
		var lift: Color = r["floor_c"]
		if id == picked:
			lift = (r["floor_c"] as Color).lightened(0.35)
		kit.go(r["floor"], "albedo_color", lift.darkened(k), 0.2)
		kit.go(r["wall"], "albedo_color", (r["wall_c"] as Color).darkened(k), 0.2)
	for group: Dictionary in [_gates, _plugs]:
		for eid: String in group:
			var node: Node3D = group[eid]
			var rooms: Array = node.get_meta("rooms", [])
			var any := false
			for rid: Variant in rooms:
				any = any or bool(shown.get(str(rid), false))
			node.visible = floor_filter == -1 or not floor_alone or any
	if _space != null:
		for child: Node in _space.get_children():
			if child.has_meta("rooms") and child is Node3D:
				var any := false
				for rid: Variant in child.get_meta("rooms"):
					any = any or bool(shown.get(str(rid), false))
				(child as Node3D).visible = floor_filter == -1 or not floor_alone or any
	_frame(_frame_focus, picked, MenuKit.SIGNAL, 0.9)
	_frame(_frame_hover, hovered if hovered != picked else "", MenuKit.INK_DIM, 0.45)
	_place_labels()
	_build_panel()
	_link_ring()
	_build_floor_note()


## The frame round a room: focus is this SHAPE, in signal -- not a tint.
func _frame(holder: Node3D, id: String, colour: Color, width: float) -> void:
	if holder == null:
		return
	for n: Node in holder.get_children():
		n.queue_free()
	if id == "" or not _mini.has(id):
		return
	var r: Dictionary = _mini[id]
	var c: Vector3 = r["centre"]
	var hw := float(r["w"]) * 0.5 + 0.9
	var hd := float(r["d"]) * 0.5 + 0.9
	var y := c.y + 0.12
	var pts := [Vector3(c.x - hw, y, c.z - hd), Vector3(c.x + hw, y, c.z - hd),
		Vector3(c.x + hw, y, c.z + hd), Vector3(c.x - hw, y, c.z + hd),
		Vector3(c.x - hw, y, c.z - hd)]
	var node := MeshInstance3D.new()
	node.mesh = MenuKit.strip(pts, width, Vector3.UP)
	node.material_override = kit.flat(colour)
	holder.add_child(node)


## Which floor is showing, and how, on the glass at the window's foot --
## only where there is more than one floor.
func _build_floor_note() -> void:
	for n: Node in _floor_note.get_children():
		n.queue_free()
	if _floors.size() < 2 or zone == null:
		return
	var mine := player_floor()
	var words := "EVERY FLOOR (%d) · YOURS AT FULL TONE" % _floors.size()
	if floor_filter != -1:
		words = "FLOOR %d OF %d%s · %s" % [floor_filter + 1, _floors.size(),
				" (YOURS)" if floor_filter == mine else "",
				"ALONE" if floor_alone else "THE OTHERS DIMMED"]
	var at := Vector2(WINDOW.position.x + 16, WINDOW.end.y - 34)
	var w := kit.measure(words, 2)
	kit.card(_floor_note, at - Vector2(8, 6), Vector2(w + 16, 28), 0.011,
			kit.flat(Color("#0e1115"), 0.9))
	kit.label(_floor_note, words, at, 2, MenuKit.INK_DIM, 0.0165)
	_floor_note.set_meta("words", kit.display(words))


## The short answers, as words on the window's glass -- not things in the
## miniature. Built when the pick changes; PLACED every frame from where the
## lens has put what they name (_layout_tags), so they never cover each
## other, the picked room, or you.
func _place_labels() -> void:
	for n: Node in _labels.get_children():
		n.queue_free()
	_tags.clear()
	_edge_marks.clear()
	if _you != null and _you_room != "":
		_tag("YOU", MenuKit.INK, 2, "you", _you_room)
	if picked == "" or not _mini.has(picked):
		_layout_tags()
		return
	var row: Dictionary = _mini[picked]["row"]
	var open_n := 0
	var shut_n := 0
	var exits: Array = []
	for eid: String in _edges:
		var e: Dictionary = _edges[eid]
		var c: Dictionary = e["row"]
		if str(c["room_a"]) != picked and str(c["room_b"]) != picked:
			continue
		if (e["mark"] as Vector3) == Vector3.INF:
			continue
		var other := str(c["room_b"]) if str(c["room_a"]) == picked \
				else str(c["room_a"])
		var name := _room_name(other)
		var words := ""
		var colour := MenuKit.INK_DIM
		if _plugs.has(eid) and str(c["room_a"]) != picked:
			continue                    # another room's way back, landing here
		if _plugs.has(eid):
			words = "A WAY BACK"
			open_n += 1
		elif str(c["state"]) == "open":
			open_n += 1
			words = ("TO " + name) if name != "" else "A WAY ON, NOT YET WALKED"
		else:
			shut_n += 1
			words = "SHUT" + (" -- TO " + name if name != "" else "")
			colour = e["colour"]
		exits.append([words, colour, eid])
	var more := "   %s: MORE" % ("A" if kit.device == "pad" else "ENTER")
	_tag(str(row.get("name", "")), MenuKit.INK, 3, "head", picked)
	_tag("%d OPEN   %d SHUT" % [open_n, shut_n] + (more if not expanded else ""),
			MenuKit.INK_DIM, 2, "summary", picked)
	for x: Array in exits:
		_tag(str(x[0]), x[1], 2, "exit", str(x[2]))
	_layout_tags()


func _room_name(id: String) -> String:
	if not _mini.has(id):
		return ""                       # an unknown room is never named
	return str((_mini[id]["row"] as Dictionary).get("name", ""))


## A short label standing on the glass, always facing you and always the
## same size, with a dark edge so it reads over any floor: eight offset
## copies behind it -- a bitmap face has no outline.
func _tag(text: String, colour: Color, k: int, kind: String, ref: String) -> void:
	var node := Node3D.new()
	_labels.add_child(node)
	for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1),
			Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1),
			Vector2(1, -1)]:
		kit.label(node, text, off * float(k), k, Color("#07090b"), 0.0, false, true)
	kit.label(node, text, Vector2.ZERO, k, colour, 0.0006, false, true)
	var hit := kit.pick_rect("map", node, Rect2(Vector2.ZERO, Vector2(kit.measure(text,
			k), 8.0 * k)), 0.0, 0.0008, "tag:" + kind)
	hit.position = MenuKit.rel(Vector2(kit.measure(text, k), 8.0 * k) * 0.5, 0.0004)
	_tags.append({"node": node, "size": Vector2(kit.measure(text, k), 8.0 * k),
		"kind": kind, "ref": ref, "text": kit.display(text), "rect": Rect2()})


## Where each tag goes this frame. YOU beside the figure; each exit tag
## beside its gate or doorway, on whichever side is free, never over another
## exit; then the head block (name + summary) just outside the picked room --
## above it if there is room, else below or beside. A tag whose subject is
## outside the window is not shown.
func _layout_tags() -> void:
	_place_edge_marks()
	if _tags.is_empty() or _map == null:
		return
	var usable := Rect2(WINDOW.position + Vector2(10, 10), WINDOW.size - Vector2(20, 20))
	if expanded and picked != "":
		usable.size.x -= PANEL_W
	var taken: Array = []
	if _back_rect.size != Vector2.ZERO:
		taken.append(_back_rect.grow(6))
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
	if picked != "" and _mini.has(picked):
		room = _room_rect(picked)
		taken.append(room.grow(6))
	var anchors := {}
	for t: Dictionary in exits:
		var a := _exit_rect(str(t["ref"]))
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
	if not usable.grow(-6).has_point(room.get_center()):
		# The picked place is off the window: its edge mark names it there.
		_hide(head)
		_hide(summary)
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


## What an exit tag keeps clear of: the exit's mark, its gate symbol at its
## largest (linked x1.4, pulse +30%), and the Journal's ring when the ring
## is on it -- so no word ever sits on the symbol it names.
func _exit_rect(eid: String) -> Rect2:
	var mark: Vector3 = _edges[eid]["mark"]
	var r := Rect2(_page_of(mark), Vector2.ZERO).grow(10)
	var gate: Node3D = _gates.get(eid, _plugs.get(eid))
	if gate != null:
		var half := 12.0 * 0.34 * 0.5 * 1.4 * 1.3
		var c := _page_of(gate.position)
		var rad := 0.0
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			rad = maxf(rad, _page_of(gate.position + axis * half).distance_to(c))
		r = r.merge(Rect2(c, Vector2.ZERO).grow(rad + 4.0))
	if str(link.get("edge", "")) == eid:
		for k in 8:
			var a := TAU * float(k) / 8.0
			r = r.expand(_page_of(mark + Vector3(cos(a) * 4.9, 0.3, sin(a) * 4.9)))
	return r


## YOU goes beside the figure, and only has to keep off the figure itself.
func _place_you(t: Dictionary, usable: Rect2, taken: Array) -> void:
	if _you == null or not _you.visible:
		_hide(t)
		return
	var c := _you.position - Vector3(0, 2.6, 0)
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
	node.position = MenuKit.at(at.round(), 0.012)
	t["rect"] = Rect2(at.round(), t["size"])


## A room's outline on the page, as the lens has it now.
func _room_rect(id: String) -> Rect2:
	var r: Dictionary = _mini[id]
	var c: Vector3 = r["centre"]
	var hw := float(r["w"]) * 0.5
	var hd := float(r["d"]) * 0.5
	return _projected(c + Vector3(-hw, 0, -hd), c + Vector3(hw, WALL_HEIGHT, hd))


## The long answer, docked at the window's edge: this map's own detail, on
## a warm tag hung from the harness over the port's side the lens keeps
## clear. Its words hold still; the tag is as tall as they need.
func _build_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if not expanded or picked == "":
		return
	_panel = Node3D.new()
	_panel.name = "Detail"
	face.add_child(_panel)
	var shade := float(shell.shade.get("map", 1.0))
	var x := WINDOW.end.x - PANEL_W + 8.0
	var w := PANEL_W - 22.0
	var z := 0.03
	var lines := detail_text().split("\n")
	var rows: Array = []
	var h := 34.0
	for i in lines.size():
		var k := 3 if i == 0 else 2
		var wrapped := kit.wrap(lines[i], k, w - 44)
		rows.append([k, wrapped, i])
		h += (30.0 if k == 3 else 20.0) * wrapped.size() + (10.0 if i == 0 else 6.0)
	h += 20.0
	var r := Rect2(x, WINDOW.position.y + 22.0, w, minf(h, WINDOW.size.y - 40.0))
	MenuParts.tag(_panel, r, z, true, shade)
	MenuParts.block(_panel, Rect2(r.position.x + 8, r.position.y + 30, 4,
			r.size.y - 44), z, z + 0.0006, MenuParts.unlit(MenuKit.SIGNAL), false)
	kit.pick_rect("map", _panel, r, z - 0.004, z, "detail")
	var yy := r.position.y + 34.0
	for row: Array in rows:
		var k: int = row[0]
		for line: String in row[1]:
			if yy > r.end.y - 20.0:
				break
			MenuParts.text(kit, _panel, line, Vector2(r.position.x + 22, yy), k,
					MenuParts.FLAG_INK if int(row[2]) != 1 else MenuParts.TAG_DIM,
					z + 0.0012)
			yy += 30.0 if k == 3 else 20.0
		yy += 10.0 if k == 3 else 6.0
	_panel.set_meta("rect", r)


## What is known about a place: its name, its floor, and each way on with
## its state and the bridge's reason. Nothing the bridge withholds.
func _describe(room_id: String) -> String:
	var lines: Array = []
	for row: Dictionary in _rooms:
		if str(row["id"]) != room_id:
			continue
		lines.append(str(row["name"]).to_upper())
		lines.append(_floor_words(band_of_room(room_id) - player_floor()))
	for row: Dictionary in _connectors:
		var a := str(row["room_a"])
		var b := str(row["room_b"])
		if a != room_id and b != room_id:
			continue
		var other := b if a == room_id else a
		var other_name := _room_name(other)
		var where := ("to " + other_name) if other_name != "" \
				else "a way on, not yet walked"
		if _plugs.has(str(row["edge_id"])):
			# A WAY BACK IS A DEVICE WHERE IT STANDS (room_a), taking you to
			# room_b. It is a way out of the room it stands in; where it
			# lands, it is not one, and a room not walked is not named.
			if a != room_id:
				if other_name != "":
					lines.append("- the way back from %s lands here" % other_name)
				continue
			where = ("a way back to " + other_name) if other_name != "" \
					else "a way back"
		var state := str(row["state"])
		var reason := str(row["reason"])
		var said := state if reason == "" else "%s: %s" % [state, reason]
		lines.append("- %s: %s" % [where, said])
	return "\n".join(lines)


## A floor relative to yours, in words.
static func _floor_words(rel: int) -> String:
	if rel == 0:
		return "Your floor"
	var n := absi(rel)
	return "%d floor%s %s" % [n, "" if n == 1 else "s",
			"up" if rel > 0 else "down"]


# ------------------------------------------------------------ shown an entry

## "Show this on the map": bring what a Journal entry names into view -- a
## place is picked; a passage is put at the window's centre -- at a zoom
## that shows it with what is round it, every floor shown, the detail
## closed. The view the Map had is kept (once, however many entries are
## shown after it) for BACK TO YOUR VIEW. Ordinary travel never calls this.
func follow(l: Dictionary) -> void:
	var local := target_local(l)
	if local == Vector3.INF:
		return
	if _return.is_empty():
		_return = {"yaw": lens.yaw, "pitch": lens.pitch, "target": lens.target,
			"zoom": lens.zoom, "shift": lens.shift, "picked": picked,
			"expanded": expanded, "floor": floor_filter, "alone": floor_alone}
	followed = l.duplicate()
	expanded = false
	floor_filter = -1
	floor_alone = false
	kit.go(lens, "shift", 0.0, 0.3)
	if l.has("room") and not l.has("edge") and _mini.has(str(l["room"])):
		picked = str(l["room"])
	_set_lens(lens.yaw, lens.pitch, local, maxf(lens.zoom, fit * PICK_ZOOM))
	_refresh_marks()
	_build_glass_back()


## BACK TO YOUR VIEW: the view, the pick, the detail and the floor the Map
## had before it was shown an entry.
func return_view() -> bool:
	if _return.is_empty():
		return false
	kit.cue("return")
	var v := _return
	_return = {}
	followed = {}
	picked = str(v["picked"]) if _mini.has(str(v["picked"])) else ""
	expanded = bool(v["expanded"]) and picked != ""
	floor_filter = int(v["floor"])
	floor_alone = bool(v.get("alone", false))
	if floor_filter >= _floors.size():
		floor_filter = -1
	kit.go(lens, "shift", float(v["shift"]), 0.3)
	_set_lens(float(v["yaw"]), float(v["pitch"]), v["target"], float(v["zoom"]))
	_refresh_marks()
	_build_glass_back()
	return true


func can_return() -> bool:
	return not _return.is_empty()


## The way back, where the eye is: words on the glass at the window's top
## left, with their key -- clickable too.
func _build_glass_back() -> void:
	if _glass_back != null:
		_glass_back.queue_free()
		_glass_back = null
	_back_rect = Rect2()
	if _return.is_empty():
		return
	_glass_back = Node3D.new()
	_glass_back.name = "BackToYourView"
	face.add_child(_glass_back)
	var at := WINDOW.position + Vector2(16, 14)
	var words := "BACK TO YOUR VIEW"
	var x := at.x
	if kit.device == "pad":
		# B is Back: it names this only while Back does it (not while a
		# place's detail is open, when B closes that first).
		if not expanded:
			kit.sprite(_glass_back, "pad_face_east", at + Vector2(13, 13), 2,
					MenuKit.INK, 0.014)
			x += 34.0
	else:
		var w := kit.measure("BACKSPACE", 2) + 16.0
		kit.plate(_glass_back, at, Vector2(w, 26), 0.012, kit.lit(Color("#c9d0db")),
				0.004)
		kit.label(_glass_back, "BACKSPACE", at + Vector2(8, 5), 2, MenuKit.SHADE, 0.0165)
		x += w + 12.0
	var ground := Rect2(at - Vector2(10, 8), Vector2(x - at.x + kit.measure(words, 2)
			+ 22.0, 42))
	kit.card(_glass_back, ground.position, ground.size, 0.011, kit.flat(
			Color("#0e1115"), 0.9))
	kit.label(_glass_back, words, Vector2(x, at.y + 5), 2, MenuKit.INK, 0.0165)
	kit.pick_rect("map", _glass_back, ground, 0.011, 0.017, "back_view")
	_back_rect = ground


## What you look away from stays findable: YOU, and the place you picked.
## Each is something the save already knows; off the window it stands at
## the window's edge, an arrow toward it and its name beside the arrow.
func _place_edge_marks() -> void:
	if _map == null or _labels == null:
		return
	var subjects := {}
	if _you != null and _you.visible:
		subjects["you"] = _you.position - Vector3(0, 2.6, 0)
	if picked != "" and _mini.has(picked):
		subjects["picked"] = _mini[picked]["centre"]
	var usable := Rect2(WINDOW.position + Vector2(10, 10), WINDOW.size - Vector2(20, 20))
	if expanded and picked != "":
		usable.size.x -= PANEL_W
	var placed: Array = []
	if not link.is_empty():
		# The link's arrow stands where its target clamps to the window
		# (MenuLink): keep clear of it.
		var t := target_local(link)
		if t != Vector3.INF:
			var tp := _page_of(t)
			if not WINDOW.grow(-6).has_point(tp):
				var win := WINDOW.grow(-14)
				placed.append(Vector2(clampf(tp.x, win.position.x, win.end.x),
						clampf(tp.y, win.position.y, win.end.y)))
	for kind: String in ["you", "picked"]:
		var mark: Dictionary = _edge_marks.get(kind, {})
		var ref := picked if kind == "picked" else "you"
		if not subjects.has(kind) or (kind == "picked" and _you_room == picked):
			if not mark.is_empty():
				(mark["node"] as Node3D).visible = false
			continue
		if mark.is_empty() or str(mark["ref"]) != ref:
			if not mark.is_empty():
				(mark["node"] as Node3D).queue_free()
			mark = _edge_mark(kind, ref)
			_edge_marks[kind] = mark
		var p := _page_of(subjects[kind])
		var node: Node3D = mark["node"]
		if usable.grow(-6).has_point(p):
			node.visible = false
			continue
		var edge := usable.grow(-16)
		var at := Vector2(clampf(p.x, edge.position.x, edge.end.x),
				clampf(p.y, edge.position.y, edge.end.y))
		if _back_rect.size != Vector2.ZERO and _back_rect.grow(24).has_point(at):
			# Not under the way back: past it, along the edge it is on.
			if absf(at.y - edge.position.y) < 1.0:
				at.x = _back_rect.end.x + 30.0
			else:
				at.y = _back_rect.end.y + 30.0
		for other: Vector2 in placed:
			if other.distance_to(at) < 40.0:
				# Step along the edge, not off it.
				var along := Vector2(0, 1) if absf(at.x - edge.position.x) < 1.0 \
						or absf(at.x - edge.end.x) < 1.0 else Vector2(1, 0)
				if (edge.get_center() - at).dot(along) < 0.0:
					along = -along
				at += along * 40.0
		placed.append(at)
		var d := p - at
		var icon := "arrow_right"
		if absf(d.y) > absf(d.x):
			icon = "arrow_down" if d.y > 0 else "arrow_up"
		elif d.x < 0:
			icon = "arrow_left"
		var arrow: Sprite3D = mark["arrow"]
		arrow.texture = kit.icons[icon]
		arrow.position = MenuKit.at(at, 0.013)
		# The name stands inward of the arrow, never past the window.
		var size: Vector2 = mark["size"]
		var into := (edge.get_center() - at).normalized()
		var lp := at + Vector2(signf(into.x) * 16.0, -size.y * 0.5)
		if into.x < 0:
			lp.x -= size.x
		if absf(d.y) > absf(d.x):
			lp = at + Vector2(-size.x * 0.5, signf(into.y) * 16.0
					- (size.y if into.y < 0 else 0.0))
		lp.x = clampf(lp.x, usable.position.x, usable.end.x - size.x)
		lp.y = clampf(lp.y, usable.position.y, usable.end.y - size.y)
		(mark["label"] as Node3D).position = MenuKit.at(lp.round(), 0.012)
		mark["at"] = at
		node.visible = true


func _edge_mark(kind: String, ref: String) -> Dictionary:
	var node := Node3D.new()
	_labels.add_child(node)
	var colour := MenuKit.INK if kind == "you" else MenuKit.SIGNAL
	var arrow := kit.sprite(node, "arrow_right", Vector2.ZERO, 2, colour, 0.013)
	var text := "YOU" if kind == "you" else kit.fit(_room_name(ref), 2, 220)
	var label := Node3D.new()
	node.add_child(label)
	for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1),
			Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1),
			Vector2(1, -1)]:
		kit.label(label, text, off * 2.0, 2, Color("#07090b"), 0.0, false, true)
	kit.label(label, text, Vector2.ZERO, 2, colour, 0.0006, false, true)
	node.visible = false
	return {"node": node, "arrow": arrow, "label": label, "ref": ref, "kind": kind,
		"size": Vector2(kit.measure(text, 2), 16.0)}


## The Journal's link, if one is active: a ring of dots round what it names.
func set_link(l: Dictionary) -> void:
	link = l
	_link_ring()


func _link_ring() -> void:
	if _ring == null:
		return
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
		dot.material_override = kit.flat(MenuKit.INK)
		dot.position = at + Vector3(cos(a) * 4.2, 0.3, sin(a) * 4.2)
		_ring.add_child(dot)


## Where a link lands, in the miniature: a passage's own mark, or a room's
## floor centre. INF when this map has no such thing -- a link into the
## unknown lands on nothing.
func target_local(l: Dictionary) -> Vector3:
	if l.has("edge") and _edges.has(str(l["edge"])):
		return _edges[str(l["edge"])]["mark"]
	if l.has("room") and _mini.has(str(l["room"])):
		return _mini[str(l["room"])]["centre"]
	return Vector3.INF


## For the link: its point in WORLD space, and whether the window shows it.
func target_world(l: Dictionary) -> Dictionary:
	var local := target_local(l)
	if local == Vector3.INF or _map == null:
		return {}
	var world := face.global_transform * (_map.transform * local)
	var on_wall := face.global_transform.affine_inverse() * world
	var eye := Vector3.ZERO
	var local_eye := face.global_transform.affine_inverse() * eye
	var dir := (on_wall - local_eye)
	var t := (-MenuKit.DISTANCE - local_eye.z) / dir.z
	var hit := local_eye + dir * t
	var s := MenuKit.px()
	var page := Vector2(hit.x / s + MenuKit.PAGE.x * 0.5,
			MenuKit.PAGE.y * 0.5 - hit.y / s)
	return {"world": world, "page": page,
		"inside": view_rect().grow(-6).has_point(page)}


## The part of the window the miniature is seen through: all of it, or --
## with the detail open -- all but the tag's side.
func view_rect() -> Rect2:
	if expanded and picked != "":
		return Rect2(WINDOW.position, WINDOW.size - Vector2(PANEL_W, 0))
	return WINDOW


# ============================================================ input

func nav(dir: Vector2i, _repeat := false) -> void:
	if dir.x != 0:
		step_place(dir.x)
	elif dir.y != 0:
		step_floor(-dir.y)


func accept() -> void:
	if picked == "":
		step_place(1)
	else:
		toggle_detail()


## Back one level: the open detail; the kept view; the pick. Whether there
## was one.
func back() -> bool:
	if expanded:
		toggle_detail()
		return true
	if return_view():
		return true
	if picked != "":
		overview()
		return true
	return false


## What the next Escape (or B, or Backspace) does here.
func back_words() -> String:
	if expanded:
		return "less"
	if not _return.is_empty():
		return "your view"
	if picked != "":
		return "overview"
	return "close"


## The map's own keys (the old wall's, and the LENS's): the arrows turn and
## tilt, + and - zoom, WASD pans, C or Home is the overview, PgUp and PgDn
## step floors, [ and ] step places, Backspace backs out; on the pad, Y is
## the overview and the d-pad steps floors and places.
func raw_input(event: InputEvent) -> bool:
	if zone == null:
		return false
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
			KEY_BACKSPACE:
				# BACK TO YOUR VIEW is a direct action (§8), as its tag on the
				# window says: straight back, whatever is open. With no view
				# kept, Backspace is Back.
				if not (return_view() if can_return() else back()):
					kit.cue("edge")
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
			_:
				return false
		return true
	return false


## The sticks: the right stick orbits, the left pans, the triggers zoom.
## Only while the map faces the eye (the shell hands them over then).
func sticks(stick: Dictionary, delta: float) -> void:
	var rx := _axis(stick, JOY_AXIS_RIGHT_X)
	var ry := _axis(stick, JOY_AXIS_RIGHT_Y)
	var lx := _axis(stick, JOY_AXIS_LEFT_X)
	var ly := _axis(stick, JOY_AXIS_LEFT_Y)
	var z := _axis(stick, JOY_AXIS_TRIGGER_LEFT) - _axis(stick, JOY_AXIS_TRIGGER_RIGHT)
	var limits := zoom_limits()
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
				limits.x, limits.y)


static func _axis(stick: Dictionary, axis: int) -> float:
	var v := float(stick.get(axis, 0.0))
	return 0.0 if absf(v) < STICK_DEADZONE else v


func hover(hit: Dictionary) -> void:
	var id := _ray_pick(hit)
	if id != hovered:
		hovered = id
		_frame(_frame_hover, hovered if hovered != picked else "", MenuKit.INK_DIM,
				0.45)


func click(hit: Dictionary, _button := MOUSE_BUTTON_LEFT) -> bool:
	_drag_moved = 0.0
	_press_used = false
	var target := str(hit.get("target", ""))
	if target == "back_view":
		return_view()
		_press_used = true
		return true
	if target == "detail" or target in ["tag:head", "tag:summary"]:
		toggle_detail()
		_press_used = true
		return true
	if target != "window" and not target.begins_with("tag:"):
		return true                   # off the window: nothing to turn or pick
	return false                      # a press on the map may be a drag


func drag(rel: Vector2, button: int, _hit := {}) -> void:
	_drag_moved += rel.length()
	if button == MOUSE_BUTTON_LEFT:
		lens.yaw += rel.x * 0.4
		lens.pitch = clampf(lens.pitch + rel.y * 0.3, MIN_PITCH, MAX_PITCH)
	elif button == MOUSE_BUTTON_RIGHT:
		pan_view(-rel.x * 0.01 * 5.0, rel.y * 0.01 * 5.0)


## A press that did not drag is a pick, and the lens closes AROUND the
## pointer so the room clicked stays under it.
func release(hit: Dictionary, button: int) -> void:
	if _press_used:
		_press_used = false
		return
	if button != MOUSE_BUTTON_LEFT or _drag_moved > 6.0:
		return
	var id := _ray_pick(hit)
	if id == "":
		return
	if id == picked:
		toggle_detail()
		return
	pick(id, true)


func wheel(_hit: Dictionary, dir: int) -> bool:
	zoom_view(ZOOM_STEP if dir > 0 else 1.0 / ZOOM_STEP)
	return true


func prompts() -> Array:
	if zone == null:
		return []
	# Grouped so the line fits the window: [ ] and a click both pick a
	# place; the lens's zoom and turn are one kind of thing.
	# BACK TO YOUR VIEW's own key is on its tag in the window, where the
	# action is; the line keeps the back press, which says what it does.
	var out := [[["place", "click"], "places"]]
	if picked != "":
		out.append(["accept", "less" if expanded else "more"])
	out += [["overview", "overview"], [["zoom", "orbit"], "zoom, turn"]]
	if _floors.size() > 1:
		out.append(["floors", "floors"])
	return out


# ============================================================ the shell's calls

func on_open(is_front: bool) -> void:
	_open = true
	_front = is_front
	if _dirty:
		refresh()


func on_close() -> void:
	_open = false


func on_front(is_front: bool) -> void:
	_front = is_front


func on_device() -> void:
	if picked != "":
		_refresh_marks()
	_build_glass_back()


func focus_lost() -> void:
	_drag_moved = 0.0


## Every frame the menu is open: a changed map is built; the lens's
## transform; the figure follows you; the gates' pulse (1.2 Hz, held
## still when motion is reduced); the linked gate pulses larger.
func tick(delta: float) -> void:
	_t += delta
	if _dirty:
		refresh()
	_place_player()
	_apply()
	var big_edge := str(link.get("edge", ""))
	for eid: String in _gates:
		var s: Node3D = _gates[eid]
		var big := 1.4 if big_edge == eid else 1.0
		var p := 1.0 if kit.still() else 1.0 + PULSE_SWING * sin(_t * TAU * PULSE_HZ)
		_pulse = p
		s.scale = Vector3.ONE * p * big


func _on_snapshot(_snapshot: Dictionary) -> void:
	_dirty = true


func _on_entered(_index: int) -> void:
	_dirty = true


# ============================================================ state

func state() -> Dictionary:
	return {"picked": picked, "expanded": expanded, "floor": floor_filter,
		"alone": floor_alone, "hovered": hovered, "yaw": snappedf(lens.yaw, 0.01),
		"pitch": snappedf(lens.pitch, 0.01), "zoom": snappedf(lens.zoom, 0.0001),
		"target": [snappedf(lens.target.x, 0.01), snappedf(lens.target.y, 0.01),
			snappedf(lens.target.z, 0.01)], "fit": snappedf(fit, 0.0001),
		"link": link.duplicate(), "shift": lens.shift, "pulse": snappedf(_pulse, 0.0001),
		"tags": _tag_state(), "tag_clashes": _tag_clashes(),
		"followed": followed.duplicate(), "can_return": not _return.is_empty(),
		"edge_marks": _edge_mark_state(), "edge_marks_unknown": _edge_marks_unknown(),
		"floor_words": str(_floor_note.get_meta("words", "")) if _floor_note != null
			and _floor_note.get_child_count() > 0 else "",
		"back": back_words()}


## The edge marks shown now: kind -> what it points at.
func _edge_mark_state() -> Dictionary:
	var out := {}
	for kind: String in _edge_marks:
		var mark: Dictionary = _edge_marks[kind]
		if (mark["node"] as Node3D).visible:
			out[kind] = str(mark["ref"])
	return out


## How many shown edge marks point at anything the save does not know: the
## marks must never reveal a room not found.
func _edge_marks_unknown() -> int:
	var n := 0
	var known_ids := known()
	for kind: String in _edge_marks:
		var mark: Dictionary = _edge_marks[kind]
		if (mark["node"] as Node3D).visible and kind == "picked" \
				and not known_ids.has(str(mark["ref"])):
			n += 1
	return n


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
	var room := _room_rect(picked) if picked != "" and _mini.has(picked) else Rect2()
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
