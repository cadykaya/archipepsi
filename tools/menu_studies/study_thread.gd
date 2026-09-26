extends RefCounted
## STUDY 3 -- THREAD: A LINE RUNS ROUND THE CORNER.   (JOURNAL -> MAP)
##
## **The idea.** The four walls are one room, so a thing on one wall can
## point at a thing on the next. Pick a journal line that names a passage
## and a thread leaves the line, runs along the wall, turns the corner and
## lands on that passage on the map. The symbol threaded on it near the
## corner is the mark to look for; the turn (E) is how you follow it; on
## the map the line's own words wait by the ring; turn back (Q) and the
## thread leads home to the line. Picking another line rewinds and recasts
## it. The turn stops being a page change and becomes part of reading.
##
## **Only real links.** A still-shut line and the connector it names are
## the same record: `JournalQuery.still_shut` walks the save's `zone_map`
## connectors and writes one line for each that is not open, in that
## order, so line n IS the n-th shut connector. The map it lands on is
## drawn from the journal's OWN save (the same `zone_map`), not another
## fixture's, so the thread cannot point at a state the journal does not
## describe.
##
## **Not a route.** Where the thread crosses the plan it is a straight
## leader in INK, lifted over it: no connector is drawn straight, in ink or
## above the rooms. (Signal is the focus colour, and it would not do here:
## Production's provisional `state:span_alignment` circuit colour, #4de6f2,
## sits on top of it -- see the report.)
##
## Mouse in this capture: the pointer travels, the click picks, E / Q turn.

const Kit := preload("res://_harness/study_kit.gd")
const Overlay := preload("res://_harness/study_overlay.gd")
const Journal := preload("res://_harness/study_journal.gd")
const Plan := preload("res://_harness/study_plan.gd")

const COLUMN := 700.0
const WIDTH := 2.0 * 0.00137935    # the thread: 2 page px, world units
const ON_WALL := 0.010             # along the empty wall
const OVER_PLAN := 0.012           # over the plan's layers (all <= 0.008)
const CARD_AT := 0.014
const RING_R := 26.0
const BEAD_X := 1196.0             # page px: where the symbol rides


## What `go` animates: how much of the thread is drawn, 0..1.
class Progress:
	var p := 0.0


var kit: Kit
var overlay: Overlay
var journal: Journal
var plan: Plan
var jface: Node3D
var mface: Node3D
var links := {}                    # "shut:n" -> {edge, text}
var rows := {}                     # edge id -> MapFace connector row
var colours := {}
var picked := ""
var thread: MeshInstance3D
var casing: MeshInstance3D
var drawn := Progress.new()
var _path: Array = []              # world points of the current thread
var _bead_s := 0.0                 # arc length at which the bead rides
var bead: Node3D
var ring: Node3D
var caption: Node3D


func _init(k: Kit, o: Overlay, content: Dictionary, _layout: Dictionary) -> void:
	kit = k
	overlay = o
	var j: Dictionary = content["journal"]["walked"]
	var m: Dictionary = content["map"]["journal_walked"]
	for page: String in Kit.PAGES:
		kit.face_title(page)
	jface = kit.face_of("journal")
	mface = kit.face_of("map")
	kit.face("journal")
	journal = Journal.new(kit, jface, j, 48.0, COLUMN)
	plan = Plan.new(kit, mface, m, Rect2(Vector2(260, 110), Vector2(900, 560)))
	colours = m.get("colours", {})
	for c: Dictionary in m["connectors"]:
		rows[str(c["edge_id"])] = c
	_link(j, m)
	# The thread, and under it a casing in the wall's own colour: over the
	# plan it cuts a clean gap through whatever it crosses, so it reads as
	# lying ON the map, never as joining it.
	casing = MeshInstance3D.new()
	casing.material_override = kit.flat(Kit.WALL)
	kit.root.add_child(casing)
	thread = MeshInstance3D.new()
	thread.material_override = kit.own(Kit.INK, 0.92)
	kit.root.add_child(thread)
	# At rest, every line that can be followed shows a loose end.
	for i in (j["still_shut"] as Array).size():
		var y := (journal.find("shut", i)["rect"] as Rect2).get_center().y
		var x := 48.0 + COLUMN + 8.0
		# (Behind the casing, which hides it once the thread is drawn.)
		kit.card(jface, Vector2(x, y - 1.0), Vector2(22, 2), 0.006,
				Kit.INK_FAINT)
		kit.card(jface, Vector2(x + 24.0, y - 3.0), Vector2(6, 6), 0.006,
				Kit.INK_FAINT)
	ring = Node3D.new()
	mface.add_child(ring)
	for i in 16:
		var a := TAU * float(i) / 16.0
		kit.card(ring, Vector2(cos(a), sin(a)) * RING_R - Vector2(3, 3),
				Vector2(6, 6), 0.0, Kit.INK, 1.0, false, true)
	ring.visible = false
	kit.tickers.append(_tick)
	overlay.prompts([["CLICK", "follow a line"], ["Q", "turn left"],
		["E", "turn right"], ["ESC", "close"]])
	overlay.show_pointer(Vector2(1320, 900))


func title() -> String:
	return "STUDY 3 -- THREAD: A LINE RUNS ROUND THE CORNER (JOURNAL -> MAP)"


## Line n of STILL SHUT is the n-th connector of the save's own map that
## is not open -- JournalQuery.still_shut's own walk, in its order.
## (PLACES would link to rooms the same way; the capture follows only the
## shut ways.)
func _link(j: Dictionary, m: Dictionary) -> void:
	var shut: Array = []
	for c: Dictionary in (m["zone_map"] as Dictionary)["connectors"]:
		if str(c.get("state", "open")) != "open":
			shut.append(str(c["edge_id"]))
	var lines: Array = j["still_shut"]
	assert(lines.size() == shut.size(), "journal and map disagree")
	for i in lines.size():
		links["shut:%d" % i] = {"edge": shut[i], "text": lines[i]}


# ------------------------------------------------------------ the thread

func _world(face: Node3D, page: Vector2, depth: float) -> Vector3:
	return face.transform * Kit.at(page, depth)


## The line -> along the empty half of its wall -> in front of the corner
## post -> along the map's margin at the same height -> straight to the
## ring's edge, over the plan.
func _route(entry: Dictionary, target: Vector2) -> Array:
	var r: Rect2 = entry["rect"]
	var y := r.get_center().y
	var start := _world(jface, Vector2(r.end.x + 8.0, y), ON_WALL)
	var edge := _world(jface, Vector2(1266.0, y), ON_WALL)
	var inset := Kit.DISTANCE - 0.15
	var margin := Vector2(236.0, y)
	var land := target - (target - margin).normalized() * (RING_R - 4.0)
	_bead_s = start.distance_to(_world(jface, Vector2(BEAD_X, y), ON_WALL))
	return [start, edge, Vector3(inset, edge.y, inset),
		_world(mface, Vector2(14.0, y), ON_WALL),
		_world(mface, margin, ON_WALL),
		_world(mface, land, OVER_PLAN)]


func pick(key: String) -> void:
	if picked == key:
		return
	var entry := journal.find("shut", int(key.split(":")[1]))
	var link: Dictionary = links[key]
	if picked != "":
		_mark(journal.find("shut", int(picked.split(":")[1])), false)
		# The old thread rewinds before the new one is cast.
		kit.go(drawn, "p", 0.0, 0.16, "in")
		kit.later(0.17, func() -> void: _cast(entry, link))
	else:
		_cast(entry, link)
	picked = key
	_mark(entry, true)
	overlay.prompts([["E", "follow the thread"], ["CLICK", "another line"],
		["Q", "turn left"], ["ESC", "close"]])


func _cast(entry: Dictionary, link: Dictionary) -> void:
	var edge := str(link["edge"])
	var target: Vector2 = plan.edge_px[edge]
	_path = _route(entry, target)
	drawn.p = 0.0
	# At an even pace, so the run you can see -- to the corner -- is a
	# visible cast (about 0.17 s), not two frames of an ease-out.
	kit.go(drawn, "p", 1.0, 0.42, "linear")
	ring.position = Kit.at(target, CARD_AT + 0.002)
	for node: Node3D in [bead, caption]:
		if node != null:
			node.visible = false
			node.queue_free()
	# The bead: the passage's own mark, in its own colour, on the thread.
	var row: Dictionary = rows[edge]
	var circuits: Array = row.get("circuits", [])
	var tint := Color(str(colours.get(str(circuits[0]), "#9ba5b6"))) \
			if not circuits.is_empty() else Kit.INK_DIM
	var y := (entry["rect"] as Rect2).get_center().y
	bead = Node3D.new()
	jface.add_child(bead)
	kit.card(bead, Vector2(BEAD_X - 20.0, y - 20.0), Vector2(40, 40),
			ON_WALL + 0.001, Kit.WALL)
	kit.sprite(bead, str(Plan.SYMBOL_ICON.get(str(row.get("symbol", "")),
			"blocked")), Vector2(BEAD_X, y), 2, tint, ON_WALL + 0.002)
	# The words wait by the ring: the journal's line, on the map.
	caption = Node3D.new()
	mface.add_child(caption)
	var text := str(link["text"])
	var n := Journal._rows(kit, text, 420.0)
	var size := Vector2(minf(kit.measure(text, 2), 420.0) + 30.0,
			16.0 + 20.0 * float(n))
	var at_px := target + Vector2(RING_R + 14.0, RING_R)
	if at_px.x + size.x > 1250.0:
		at_px.x = target.x - RING_R - 14.0 - size.x
	if at_px.y + size.y > 700.0:
		at_px.y = target.y - RING_R - size.y
	kit.card(caption, at_px, size, CARD_AT, Kit.SHEET, 0.96)
	kit.card(caption, at_px, Vector2(4, size.y), CARD_AT + 0.0005, Kit.SIGNAL)
	kit.label(caption, text, at_px + Vector2(16, 8), 2, Kit.INK,
			CARD_AT + 0.001, 420.0)
	_tick(kit.t)


func _mark(entry: Dictionary, on: bool) -> void:
	if entry.is_empty():
		return
	var ground: StandardMaterial3D = (entry["ground"] as MeshInstance3D).material_override
	var bar: StandardMaterial3D = (entry["bar"] as MeshInstance3D).material_override
	kit.go(ground, "albedo_color", Color(Kit.SHEET_HI, 1.0 if on else 0.0), 0.12)
	kit.go(bar, "albedo_color", Color(Kit.SIGNAL, 1.0 if on else 0.0), 0.12)


## Every frame: the thread drawn up to its current length, facing the
## eye. The bead shows once the thread has reached it; the ring and the
## words once it has landed.
func _tick(_t: float) -> void:
	var total := 0.0
	for i in _path.size() - 1:
		total += (_path[i] as Vector3).distance_to(_path[i + 1])
	var left := total * drawn.p
	var reach := left
	thread.visible = _path.size() >= 2 and left > 0.0005
	var pts: Array = [_path[0]] if not _path.is_empty() else []
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
	casing.visible = thread.visible
	if thread.visible:
		thread.mesh = _strip(pts, WIDTH, 1.0)
		# 8 page px: wider than a loose end's 6 px dot, so none of it
		# peeks out from under a drawn thread.
		casing.mesh = _strip(pts, WIDTH * 4.0, 1.003)
	if bead != null:
		bead.visible = thread.visible and reach >= _bead_s
	var landed := thread.visible and drawn.p >= 0.999
	ring.visible = landed
	if caption != null:
		caption.visible = landed


## A strip through `pts`, `width` wide, turned to face the eye (at the
## origin). `push` > 1 slides it straight away from the eye: the same
## outline on screen, just behind -- how the casing sits under the thread.
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


# ------------------------------------------------------------ the capture

func _screen_of_line(index: int) -> Vector2:
	var r: Rect2 = journal.find("shut", index)["rect"]
	return kit.camera.unproject_position(jface.global_transform
			* Kit.at(r.position + Vector2(220.0, r.size.y * 0.5), 0.004))


func timeline() -> Array:
	return [
		[0.0, func() -> void: pass, "rest"],
		[1.2, func() -> void: overlay.point_at(_screen_of_line(0))],
		[1.6, func() -> void:
			overlay.click()
			pick("shut:0"), "select"],
		[3.2, func() -> void: overlay.point_at(_screen_of_line(2))],
		[3.6, func() -> void:
			overlay.click()
			pick("shut:2"), "change"],
		[5.2, func() -> void:
			kit.turn(-1)
			overlay.prompts([["Q", "back to the line"], ["E", "turn right"],
				["ESC", "close"]]), "adjacent"],
		[6.9, func() -> void:
			kit.turn(1)
			overlay.prompts([["E", "follow the thread"],
				["CLICK", "another line"], ["Q", "turn left"],
				["ESC", "close"]]), "return"],
	]


func duration() -> float:
	return 8.2


func stills() -> Array:
	return [[0.9, "rest -- the journal: what is shut, what was done, where you have been"],
		[2.4, "select -- a shut way: its thread runs to the corner, carrying the mark to look for"],
		[4.5, "change -- another line: the thread rewinds and recasts, with that passage's mark"],
		[5.9, "adjacent -- E, a turn right: the thread lands on the passage, its words beside it"],
		[7.9, "return -- Q: the thread leads home to the line, still picked"]]
