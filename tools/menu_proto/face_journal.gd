class_name FaceJournal
extends RefCounted
## JOURNAL (Objectives / Lore), with THREAD.
##
## Every line is JournalQuery's own, under Production's own headings. The
## face is recomposed in one way: the three sections that NAME PLACES --
## STILL SHUT, WHAT YOU DID HERE, PLACES FOUND -- stand in the right-hand
## column, against the corner that leads to the Map, and the rest
## (OBJECTIVES, NOTES) on the left. What points at the map sits nearest it,
## so a thread never crosses other words.
##
## * **The answer is on the entry.** A focused entry unfolds in place what
##   the save says about the thing it names: which two places a passage
##   joins, what holds it and in what state, what a setting opened, what a
##   place's ways are. Following the thread is optional.
## * **The link is the THING, not the line.** An entry is bound to a
##   connector's edge id or a room's id (matched exactly at extraction;
##   JournalQuery itself returns only strings -- see the handoff). When the
##   save changes, the focus follows the same passage to wherever the
##   journal now mentions it, and says what changed ("NOW OPEN").
## * **Unknown stays unknown.** A way to an unfound room is "a way not yet
##   walked" -- JournalQuery's and MapFace's words -- and the thread lands
##   on the passage, never beyond it.

## THE HYBRID (the owner's rulings of 2026-09-27, B's harness): each column
## hangs from a run dropped off the trunk; its headings are flag labels on
## the run; the focused entry is a warm tag clipped to it, with SIGNAL at
## its edge, unfolded in place. A linked entry carries its connector's
## symbol, and the focused one's ivory link leaves the tag's end, rises to
## the trunk and runs round the corner into the Map (Thread3D).
const LEFT_RUN := 46.0
const LEFT_X := 74.0
const LEFT_W := 470.0
const LEFT_TAG_W := 500.0
const RIGHT_RUN := 600.0
const RIGHT_X := 634.0
const RIGHT_W := 490.0
const RIGHT_TAG_W := 578.0
const BEAD_X := 1160.0               # a linked entry's symbol
const TOP := 112.0
const BOTTOM := 690.0
const LINE := 20.0
const HEAD_H := 30.0
const SHADE := 0.86                  # the miniature's light, glancing: pale surfaces
const TAG_Z := 0.026
## Lifted for 1280 x 720 (the fifth ruling): quieter entries a step up from
## the old DIM; the objectives stay the brightest.
const ENTRY := Color("#b9bec2")
const NOTE_INK := Color("#aeb3b8")

var kit: Kit
var shell: Shell
var face: Node3D
var map_face: FaceMap
var journal: Dictionary
var map_rows: Dictionary
var save := ""
var column := 1                      # 0 left, 1 right
var focus := {0: 0, 1: 0}            # column -> entry index
var scroll := {0: 0.0, 1: 0.0}
var hover := -1
var note := ""                       # what changed, after a save change
var thread: Thread3D

var _entries := {0: [], 1: []}       # column -> [{section, text, link, y, h, node...}]
var _root: Node3D
var _cols := {}


func setup(k: Kit, s: Shell) -> void:
	kit = k
	shell = s
	face = shell.face_of("journal")
	thread = Thread3D.new()
	shell.add_child(thread)
	thread.setup(kit, shell)
	# the fixed parts: the two runs off the trunk, and the enclosure's seam
	var f := Node3D.new()
	face.add_child(f)
	Parts.seam(f, 574, 104, 700)
	for x: float in [LEFT_RUN, RIGHT_RUN]:
		Parts.wire(f, [Vector2(x, Parts.TRUNK_Y), Vector2(x, 692)], Parts.WIRE)


func bind(m: FaceMap) -> void:
	map_face = m


func load_data(j: Dictionary, m: Dictionary, save_name: String) -> void:
	var was: Dictionary = current_link()
	var was_state := _edge_state(was) if not was.is_empty() else ""
	journal = j
	map_rows = m
	save = save_name
	_build()
	note = ""
	if not was.is_empty():
		# Follow the SAME thing to wherever this save's journal names it.
		var found := _find(was)
		if found.is_empty():
			note = "THE PASSAGE YOU FOLLOWED IS NOT IN THE JOURNAL NOW."
		else:
			column = int(found["column"])
			focus[column] = int(found["index"])
			var now := _edge_state(was)
			if was_state != "" and now != "" and now != was_state:
				note = "NOW %s." % now.to_upper()
	_layout(true)
	_update_link()


# ------------------------------------------------------------ the entries

func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Node3D.new()
	face.add_child(_root)
	_entries = {0: [], 1: []}
	var links: Dictionary = journal.get("links", {})
	_section(0, "OBJECTIVES", journal["objectives"], [])
	var notes := []
	for n: Dictionary in journal["notes"]:
		notes.append("%s -- %s" % [str(n["title"]), str(n["text"])])
	_section(0, "NOTES", notes, [])
	_section(1, "STILL SHUT", journal["still_shut"], links.get("still_shut", []),
			"edge_id")
	_section(1, "WHAT YOU DID HERE", journal["done_here"],
			links.get("done_here", []), "edges")
	_section(1, "PLACES FOUND", journal["places"], links.get("places", []),
			"room_id")


func _section(col: int, head: String, lines: Array, links: Array,
		key := "") -> void:
	var list: Array = _entries[col]
	list.append({"head": true, "text": head, "empty": lines.is_empty()})
	for i in lines.size():
		var link := {}
		for l: Dictionary in links:
			if int(l["index"]) == i:
				if key == "edge_id":
					link = {"edge": str(l["edge_id"]), "kind": "shut"}
				elif key == "edges" and not (l["edges"] as Array).is_empty():
					link = {"edge": str((l["edges"] as Array)[0]), "kind": "done",
						"edges": l["edges"], "circuits": l["circuits"]}
				elif key == "room_id":
					link = {"room": str(l["room_id"]), "kind": "place"}
		list.append({"head": false, "section": head, "text": str(lines[i]),
			"link": link})


## Place every entry of both columns; the focused one unfolds, and each
## column scrolls to keep its focus in view.
func _layout(at_once := false, by_hand := -1) -> void:
	for n: Node in _root.get_children():
		n.queue_free()
	_cols.clear()
	for col: int in [0, 1]:
		var holder := Node3D.new()
		_root.add_child(holder)
		_cols[col] = holder
		var x := LEFT_X if col == 0 else RIGHT_X
		var w := LEFT_W if col == 0 else RIGHT_W
		var y := 0.0
		var list: Array = _entries[col]
		for i in list.size():
			var e: Dictionary = list[i]
			e["y"] = y
			if e["head"]:
				e["h"] = HEAD_H + (22.0 if bool(e["empty"]) else 0.0)
				y += e["h"] + 14.0
				continue
			var lines := kit.wrap(str(e["text"]), 2, w)
			e["lines"] = lines
			var h := lines.size() * LINE
			if col == column and i == _focused_index(col):
				e["explain"] = _explanation(e)
				h += e["explain"].size() * LINE + (8.0 if not e["explain"].is_empty() else 0.0)
				if note != "":
					h += LINE + 6.0
				h += 24.0                  # the tag's margins
			else:
				e["explain"] = []
				h += 4.0
			e["h"] = h
			y += h + 8.0
		var total := y
		var view := BOTTOM - TOP
		var f := _focused_index(col)
		var sc: float = scroll[col]
		if f >= 0 and f < list.size() and col != by_hand:
			var e: Dictionary = list[f]
			if float(e["y"]) < sc:
				sc = float(e["y"])
			elif float(e["y"]) + float(e["h"]) > sc + view:
				sc = float(e["y"]) + float(e["h"]) - view
		sc = clampf(sc, 0.0, maxf(0.0, total - view))
		scroll[col] = sc
		for i in list.size():
			var e: Dictionary = list[i]
			var top := TOP + float(e["y"]) - sc
			e.erase("seen")
			if top < TOP - 1.0 or top + float(e["h"]) > BOTTOM + 1.0:
				continue
			e["seen"] = Rect2(x - 12, top, w + 24, float(e["h"]))
			_draw(holder, col, i, e, x, top, w)
		var run := LEFT_RUN if col == 0 else RIGHT_RUN
		if sc > 0.5:
			Parts.sprite(kit, holder, "arrow_up", Vector2(run + 22, TOP - 6), 2, ENTRY, 0.004)
		if total - sc > view + 0.5:
			Parts.sprite(kit, holder, "arrow_down", Vector2(run + 22, BOTTOM + 12), 2, ENTRY,
					0.004)
	_update_link()


func _draw(holder: Node3D, col: int, i: int, e: Dictionary, x: float,
		top: float, w: float) -> void:
	var run := LEFT_RUN if col == 0 else RIGHT_RUN
	if e["head"]:
		Parts.vflag(kit, holder, run, top, str(e["text"]), SHADE)
		if bool(e["empty"]):
			Parts.text(kit, holder, "NONE", Vector2(x, top + HEAD_H + 6), 2, NOTE_INK, 0.003)
		return
	var focused := col == column and i == _focused_index(col)
	var link: Dictionary = e["link"]
	var h: float = e["h"]
	var ty := top + (12.0 if focused else 0.0)       # where its words start
	if focused:
		var tw := LEFT_TAG_W if col == 0 else RIGHT_TAG_W
		var r := Rect2(run + 16, top, tw, h)
		Parts.tag(holder, r, TAG_Z, false, SHADE)
		# clipped to the run
		Parts.block(holder, Rect2(run - 2, top + 8, 20, 8), 0.012, 0.024,
				Parts.mat(Parts.METAL, 0.6, 0.35))
		Parts.block(holder, Rect2(run + 20, top + 8, 4, h - 16), TAG_Z, TAG_Z + 0.0006,
				Parts.unlit(Kit.SIGNAL), false)
		var node := holder.get_child(holder.get_child_count() - 1)
		node.name = "focus_plate"
		e["tag"] = r
	elif hover == col * 1000 + i:
		var ground := Parts.own(Parts.CAB_HI.lightened(0.12))
		ground.albedo_color.a = 0.9
		Parts.block(holder, Rect2(x - 12, top - 4, w + 24, h), 0.0, 0.0012, ground, false)
	var z := TAG_Z + 0.0012 if focused else 0.003
	var colour := Parts.FLAG_INK if focused else ENTRY
	if not focused and str(e["section"]) == "OBJECTIVES":
		colour = Parts.INK
	elif not focused and str(e["section"]) == "NOTES":
		colour = NOTE_INK
	var y := ty
	for line: String in e["lines"]:
		Parts.text(kit, holder, line, Vector2(x, y), 2, colour, z)
		y += LINE
	if not (e["explain"] as Array).is_empty():
		y += 8.0
	# The answer, on the entry itself.
	for line: String in e["explain"]:
		Parts.text(kit, holder, line, Vector2(x + 16, y), 2, Parts.TAG_DIM, z)
		y += LINE
	if focused and note != "":
		Parts.text(kit, holder, note, Vector2(x + 16, y + 6), 2, Parts.FLAG_INK, z)
	# A linked entry carries its connector's symbol; the focused one's link
	# leaves the tag's end.
	if not link.is_empty() and col == 1:
		var bead := _bead_of(link)
		Parts.sprite(kit, holder, str(bead["icon"]), Vector2(BEAD_X, ty + 9), 2,
				bead["colour"], TAG_Z + 0.0025 if focused else 0.004)
		if focused:
			e["anchor"] = Vector2(RIGHT_RUN + 16 + RIGHT_TAG_W, ty + 9)
			e["anchor_top"] = top


## A linked entry's symbol: its gate's (Production's colour), or a way out.
func _bead_of(link: Dictionary) -> Dictionary:
	if link.has("edge"):
		var c := _connector(str(link["edge"]))
		var circuits: Array = c.get("circuits", [])
		if str(c.get("state", "")) != "open" and not circuits.is_empty():
			return {"icon": FaceMap.SYMBOL_ICON.get(str(c.get("symbol", "")), "blocked"),
				"colour": Color(str((map_rows["colours"] as Dictionary).get(
					str(circuits[0]), "#9ba5b6")))}
	return {"icon": "exit", "colour": Parts.INK}


## What the save says about the thing an entry names -- the useful answer,
## so the map is context and never required reading.
func _explanation(e: Dictionary) -> Array:
	var link: Dictionary = e["link"]
	var out := []
	if link.has("edge"):
		var c := _connector(str(link["edge"]))
		if c.is_empty():
			return ["NOT ON THIS SAVE'S MAP."]
		var a := _room_name(str(c["room_a"]))
		var b := _room_name(str(c["room_b"]))
		out.append("BETWEEN %s AND %s" % [a if a != "" else "A WAY NOT YET WALKED",
				b if b != "" else "A WAY NOT YET WALKED"])
		var circuits: Array = c.get("circuits", [])
		if not circuits.is_empty():
			out.append("HELD BY: %s" % _circuit_words(str(circuits[0])))
		out.append("NOW: %s" % str(c["state"]).to_upper())
		out.append("ON THE MAP, ROUND THE CORNER (%s)" % _turn_key())
	elif link.has("room"):
		var detail := str((map_rows["details"] as Dictionary).get(str(link["room"]), ""))
		var lines := detail.split("\n")
		for i in range(1, lines.size()):
			out.append(lines[i])
		out.append("ON THE MAP, ROUND THE CORNER (%s)" % _turn_key())
	return out


## A circuit's own words: the last part of its id, as JournalQuery._words
## writes an id ("state:span_alignment" -> "span alignment").
static func _circuit_words(id: String) -> String:
	var parts := id.split(":")
	var last := parts[parts.size() - 1].replace("_", " ")
	if parts[0] == "key":
		return "%s KEY" % last.to_upper()
	return last.to_upper()


func _connector(edge: String) -> Dictionary:
	for c: Dictionary in map_rows["connectors"]:
		if str(c["edge_id"]) == edge:
			return c
	return {}


func _room_name(id: String) -> String:
	for r: Dictionary in map_rows["rooms"]:
		if str(r["id"]) == id:
			return str(r.get("name", "")).to_upper()
	return ""


func _edge_state(link: Dictionary) -> String:
	if not link.has("edge"):
		return ""
	var c := _connector(str(link["edge"]))
	return str(c.get("state", "")) if not c.is_empty() else ""


func _find(link: Dictionary) -> Dictionary:
	for col: int in [1, 0]:
		var list: Array = _entries[col]
		for i in list.size():
			var e: Dictionary = list[i]
			if e["head"] or (e["link"] as Dictionary).is_empty():
				continue
			var l: Dictionary = e["link"]
			if link.has("edge") and (str(l.get("edge", "")) == str(link["edge"])
					or (l.get("edges", []) as Array).has(str(link["edge"]))):
				return {"column": col, "index": i}
			if link.has("room") and str(l.get("room", "")) == str(link["room"]):
				return {"column": col, "index": i}
	return {}


func _focused_index(col: int) -> int:
	var list: Array = _entries[col]
	var i := int(focus.get(col, -1))
	if i >= 0 and i < list.size() and not list[i]["head"]:
		return i
	for j in list.size():
		if not list[j]["head"]:
			focus[col] = j
			return j
	return -1


func current_link() -> Dictionary:
	var list: Array = _entries.get(column, [])
	var i := _focused_index(column) if not list.is_empty() else -1
	if i < 0 or i >= list.size():
		return {}
	var e: Dictionary = list[i]
	if e["head"]:
		return {}
	var l: Dictionary = e["link"]
	if l.has("edge"):
		return {"edge": l["edge"]}
	if l.has("room"):
		return {"room": l["room"]}
	return {}


func _update_link() -> void:
	var link := current_link()
	map_face.set_link(link)
	var list: Array = _entries.get(column, [])
	var i := _focused_index(column) if not list.is_empty() else -1
	var anchor := Vector2.INF
	var bead := {}
	if i >= 0 and i < list.size() and not link.is_empty():
		var e: Dictionary = list[i]
		anchor = e.get("anchor", Vector2.INF)
		bead = _bead_of(link)
	thread.bind_ends(anchor, link, bead, map_face)


# ------------------------------------------------------------ input

func nav(dir: Vector2i) -> void:
	note = ""
	var moved := false
	if dir.x != 0:
		var to := clampi(column + dir.x, 0, 1)
		moved = to != column
		column = to
	elif dir.y != 0:
		var list: Array = _entries[column]
		var i := _focused_index(column)
		var j := i + dir.y
		while j >= 0 and j < list.size() and list[j]["head"]:
			j += dir.y
		if j >= 0 and j < list.size():
			focus[column] = j
			moved = true
	kit.cue("tick" if moved else "edge")
	_layout()


## "Show this on the map": the Map is one turn right, and it brings what
## the entry names into view, keeping its own view for BACK TO YOUR VIEW.
## Ordinary travel (E, the edge arrows) turns to the Map as it was left.
func accept() -> void:
	if not current_link().is_empty():
		kit.cue("follow")
		if map_face != null:
			map_face.follow(current_link())
		shell.turn(-1)
	else:
		kit.cue("edge")


func back() -> bool:
	return false


func hover_at(p: Vector2) -> void:
	var was := hover
	hover = _hit(p)
	if hover != was:
		_layout()


func click(p: Vector2) -> bool:
	var h := _hit(p)
	if h < 0:
		return false
	var col := h / 1000
	var i := h % 1000
	if col == column and i == _focused_index(col) and not current_link().is_empty():
		return true
	note = ""
	# Hold the clicked entry under the pointer while the column unfolds.
	var e: Dictionary = _entries[col][i]
	var before := TOP + float(e["y"]) - float(scroll[col])
	column = col
	focus[col] = i
	kit.cue("tick")
	_layout()
	var after := TOP + float(_entries[col][i]["y"]) - float(scroll[col])
	if absf(after - before) > 0.5:
		scroll[col] = float(scroll[col]) + (after - before)
		_layout()
	return true


## Scrolling by hand moves the column and does not snap back to the focus.
func wheel(p: Vector2, dir: int) -> bool:
	var col := 0 if p.x < RIGHT_RUN - 12 else 1
	scroll[col] = maxf(0.0, float(scroll[col]) + 60.0 * dir)
	_layout(false, col)
	return true


## The right stick scrolls the focused column by hand.
func scroll_by(px: float) -> void:
	scroll[column] = maxf(0.0, float(scroll[column]) + px)
	_layout(false, column)


func _hit(p: Vector2) -> int:
	for col: int in [0, 1]:
		var x := LEFT_X if col == 0 else RIGHT_X
		var w := LEFT_W if col == 0 else RIGHT_W
		if p.x < x - 16 or p.x > (x + w + 16 if col == 0 else BEAD_X + 24):
			continue
		var list: Array = _entries[col]
		for i in list.size():
			var e: Dictionary = list[i]
			if e["head"]:
				continue
			var top := TOP + float(e["y"]) - float(scroll[col])
			if p.y >= top - 4 and p.y < top + float(e["h"]) + 4 and \
					top >= TOP - 1 and top + float(e["h"]) <= BOTTOM + 1:
				return col * 1000 + i
	return -1


## Where a named thing is on this wall now, page px (for a tape):
## "entry:<col>:<i>", "text:<words>" (the first shown entry that says
## them), "col:<c>" (a point in a column). INF when not shown.
func target_of(name: String) -> Vector2:
	var p := name.split(":", true, 1)
	match p[0]:
		"entry":
			var q := p[1].split(":")
			var list: Array = _entries.get(int(q[0]), [])
			var i := int(q[1])
			if i >= 0 and i < list.size() and (list[i] as Dictionary).has("seen"):
				var r: Rect2 = list[i]["seen"]
				return Vector2(r.position.x + 60.0, r.position.y + 10.0)
		"text":
			for col: int in [1, 0]:
				for e: Dictionary in _entries[col]:
					if not e["head"] and e.has("seen") and str(e["text"]).to_upper().contains(
							p[1].to_upper()):
						var r: Rect2 = e["seen"]
						return Vector2(r.position.x + 60.0, r.position.y + 10.0)
		"col":
			return Vector2(LEFT_X + 200.0 if p[1] == "0" else RIGHT_X + 200.0, 400.0)
	return Vector2.INF


func prompts() -> Array:
	var out := [["move", "entries"], ["move_h", "columns"], ["click", "pick"]]
	if not current_link().is_empty():
		out.append(["accept", "show on the map"])
	out += [["turn_left", "turn left"], ["turn_right", "turn right"],
		["close", "close"]]
	return out


func state() -> Dictionary:
	var list: Array = _entries.get(column, [])
	var i := _focused_index(column) if not list.is_empty() else -1
	var text := ""
	if i >= 0 and i < list.size():
		text = str(list[i]["text"])
	var last := -1
	for j in list.size():
		if not list[j]["head"]:
			last = j
	return {"column": column, "index": i, "text": text, "link": current_link(),
		"note": note, "scroll": [scroll[0], scroll[1]], "save": save,
		"last_index": last,
		# the focused entry is wholly on the wall
		"focused_seen": i >= 0 and i < list.size() and (list[i] as Dictionary).has("seen"),
		"thread": thread.state()}


func on_device() -> void:
	_build()
	_layout(true)
	_update_link()


## The key that turns toward the Map (right): E, or RB on the pad.
func _turn_key() -> String:
	return "RB" if kit.device == "pad" else "E"


func tick(delta: float) -> void:
	thread.tick(delta)
