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

const LEFT_X := 48.0
const LEFT_W := 560.0
const RIGHT_X := 660.0
const RIGHT_W := 540.0
const TOP := 104.0
const BOTTOM := 690.0
const LINE := 20.0
const LOOSE_END := 1206.0           # page x where a linked entry's loose end stops

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
				e["h"] = 30.0 if not bool(e["empty"]) else 50.0
				y += e["h"] + 6.0
				continue
			var lines := kit.wrap(str(e["text"]), 2, w - 40)
			e["lines"] = lines
			var h := lines.size() * LINE + 10.0
			if col == column and i == _focused_index(col):
				e["explain"] = _explanation(e)
				h += e["explain"].size() * LINE + (16.0 if not e["explain"].is_empty() else 0.0)
				if note != "":
					h += LINE + 6.0
			else:
				e["explain"] = []
			e["h"] = h
			y += h + 4.0
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
			if top < TOP - 1.0 or top + float(e["h"]) > BOTTOM + 1.0:
				continue
			_draw(holder, col, i, e, x, top, w)
		if sc > 0.5:
			kit.sprite(holder, "arrow_up", Vector2(x + w - 20, TOP - 14), 2,
					Kit.INK_DIM)
		if total - sc > view + 0.5:
			kit.sprite(holder, "arrow_down", Vector2(x + w - 20, BOTTOM + 10), 2,
					Kit.INK_DIM)
	_update_link()


func _draw(holder: Node3D, col: int, i: int, e: Dictionary, x: float,
		top: float, w: float) -> void:
	if e["head"]:
		var head := str(e["text"]) + ("  -- NONE" if bool(e["empty"]) else "")
		kit.label(holder, head, Vector2(x, top + 8), 2, Kit.INK_FAINT)
		return
	var focused := col == column and i == _focused_index(col)
	var link: Dictionary = e["link"]
	if focused:
		kit.shadow(holder, Vector2(x - 10, top - 4), Vector2(w + 20, float(e["h"])),
				0.6)
		var plate := kit.plate(holder, Vector2(x - 10, top - 4),
				Vector2(w + 20, float(e["h"])), 0.004, kit.lit(Kit.PLATE_HI))
		plate.name = "focus_plate"
		kit.card(holder, Vector2(x - 16, top - 4), Vector2(4, float(e["h"])),
				0.012, kit.flat(Kit.SIGNAL))
	elif hover == col * 1000 + i:
		kit.card(holder, Vector2(x - 10, top - 4), Vector2(w + 20, float(e["h"])),
				0.002, kit.flat(Kit.PLATE, 0.6))
	var z := 0.013 if focused else 0.003
	var colour := Kit.INK
	if str(e["section"]) == "NOTES":
		colour = Kit.INK_DIM
	kit.label(holder, "\n".join(e["lines"]), Vector2(x + 8, top), 2, colour, z)
	var y := top + (e["lines"] as PackedStringArray).size() * LINE + 4.0
	# The answer, on the entry itself.
	for line: String in e["explain"]:
		kit.label(holder, line, Vector2(x + 30, y + 4), 2, Kit.INK_DIM, z)
		y += LINE
	if focused and note != "":
		kit.label(holder, note, Vector2(x + 30, y + 10), 2, Kit.INK, z)
	# A loose end: this entry can be followed onto the Map.
	if not link.is_empty() and col == 1:
		var ly := top + LINE * 0.5 + 1.0
		var end_x := LOOSE_END
		kit.card(holder, Vector2(x + w + 12, ly - 1), Vector2(end_x - x - w - 12, 2),
				0.003, kit.flat(Kit.INK_FAINT if not focused else Kit.INK_DIM))
		kit.card(holder, Vector2(end_x, ly - 3), Vector2(6, 6), 0.003,
				kit.flat(Kit.INK_FAINT if not focused else Kit.INK_DIM))
		e["anchor"] = Vector2(end_x + 6, ly)
		e["anchor_top"] = top


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
		if link.has("edge"):
			var c := _connector(str(link["edge"]))
			var circuits: Array = c.get("circuits", [])
			if str(c.get("state", "")) != "open" and not circuits.is_empty():
				bead = {"icon": FaceMap.SYMBOL_ICON.get(str(c.get("symbol", "")),
						"blocked"), "colour": Color(str((map_rows["colours"]
						as Dictionary).get(str(circuits[0]), "#9ba5b6")))}
			else:
				bead = {"icon": "exit", "colour": Kit.INK}
	thread.bind_ends(anchor, link, bead, map_face)


# ------------------------------------------------------------ input

func nav(dir: Vector2i) -> void:
	note = ""
	if dir.x != 0:
		column = clampi(column + dir.x, 0, 1)
	elif dir.y != 0:
		var list: Array = _entries[column]
		var i := _focused_index(column)
		var j := i + dir.y
		while j >= 0 and j < list.size() and list[j]["head"]:
			j += dir.y
		if j >= 0 and j < list.size():
			focus[column] = j
	_layout()


func accept() -> void:
	# Follow the thread: the Map is one turn right.
	if not current_link().is_empty():
		shell.turn(-1)


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
	_layout()
	var after := TOP + float(_entries[col][i]["y"]) - float(scroll[col])
	if absf(after - before) > 0.5:
		scroll[col] = float(scroll[col]) + (after - before)
		_layout()
	return true


## Scrolling by hand moves the column and does not snap back to the focus.
func wheel(p: Vector2, dir: int) -> bool:
	var col := 0 if p.x < RIGHT_X - 20 else 1
	scroll[col] = maxf(0.0, float(scroll[col]) + 60.0 * dir)
	_layout(false, col)
	return true


func _hit(p: Vector2) -> int:
	for col: int in [0, 1]:
		var x := LEFT_X if col == 0 else RIGHT_X
		var w := LEFT_W if col == 0 else RIGHT_W
		if p.x < x - 16 or p.x > x + w + 16:
			continue
		var list: Array = _entries[col]
		for i in list.size():
			var e: Dictionary = list[i]
			if e["head"]:
				continue
			var top := TOP + float(e["y"]) - float(scroll[col])
			if p.y >= top - 4 and p.y < top - 4 + float(e["h"]) and \
					top >= TOP - 1 and top + float(e["h"]) <= BOTTOM + 1:
				return col * 1000 + i
	return -1


func prompts() -> Array:
	var out := [["move", "entries"], ["move_h", "columns"], ["click", "pick"]]
	if not current_link().is_empty():
		out.append(["follow", "follow to the map"])
	out += [["turn_left", "turn left"], ["close", "close"]]
	return out


func state() -> Dictionary:
	var list: Array = _entries.get(column, [])
	var i := _focused_index(column) if not list.is_empty() else -1
	var text := ""
	if i >= 0 and i < list.size():
		text = str(list[i]["text"])
	return {"column": column, "index": i, "text": text, "link": current_link(),
		"note": note, "scroll": [scroll[0], scroll[1]], "save": save,
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
