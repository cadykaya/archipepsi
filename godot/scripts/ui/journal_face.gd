class_name JournalFace
extends Node
## H-JOURNAL, AS THE APPROVED HYBRID (MENU-INT): THE JOURNAL WALL, with its
## LINK into the Map (`tools/menu_proto/face_journal.gd`, `5b03f6d`, the
## reference; `04` §8).
##
## Every line is JournalQuery's own, under the game's own headings, from
## the snapshot alone: the objectives, the notes (each Echo's read, earned
## by a Check), what is still shut, what you did here, the places found.
## Nothing is invented and nothing unfound is named: a room the bridge's
## map does not name stays "a way not yet walked".
##
## The wall is recomposed in one way: the three sections that NAME PLACES
## -- STILL SHUT, WHAT YOU DID HERE, PLACES FOUND -- stand in the right-hand
## column, against the corner that leads to the Map; OBJECTIVES and NOTES
## on the left. Each column hangs from a run dropped off the harness; its
## headings are flag labels on the run.
##
## * **The answer is on the entry.** A focused entry is a warm tag clipped
##   to its run, and unfolds in place what the save says about the thing it
##   names. Following the link is optional.
## * **The link is the THING, not the line.** An entry is bound to a
##   connector's edge id or a room's id (`JournalQuery`'s identity rows),
##   never to its words. When the save changes, the focus follows the same
##   passage to wherever the journal now mentions it, and says what
##   changed ("NOW OPEN"); if it is gone, it says so, and the link goes.
## * **SHOW ON THE MAP** (ENTER / A): the Map, one turn right, frames what
##   the entry names and keeps its own view to come back to. Ordinary
##   travel (E, the edge arrows) turns to the Map as it was left.

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
const TAG_Z := 0.026
## Lifted for 1280 x 720 (the fifth ruling): quieter entries a step up from
## the old DIM; the objectives stay the brightest. One step more after the
## owner's review of the delivery (2026-09-28, "a modest brightness
## increase for the quieter entries"): the notes had read 3.8-4.5:1 on the
## graphite. Same hue, same order -- objectives, entries, notes.
const ENTRY := Color("#cdd1d4")                # was #b9bec2
const NOTE_INK := Color("#c2c6ca")             # was #aeb3b8

var kit: MenuKit
var shell: MenuShell
var face: Node3D
var map_face: MapFace
var column := 1                      # 0 left, 1 right
var focus := {0: 0, 1: 0}            # column -> entry index
var scroll := {0: 0.0, 1: 0.0}
var hovered := -1
var note := ""                       # what changed, after a save change
var link_wire: MenuLink
## How many times the wall has been filled: a snapshot refills it.
var fills := 0
## The state of the focused passage as this wall last showed it: what a
## change is said against ("NOW OPEN.").
var _shown_state := ""

var _entries := {0: [], 1: []}       # column -> [{head, section, text, link, ...}]
var _root: Node3D
var _cols := {}
var _open := false
var _dirty := true


func _ready() -> void:
	name = "JournalFace"
	BridgeClient.snapshot_received.connect(func(_s: Dictionary) -> void:
		_dirty = true
		if _open:
			fill())
	BridgeClient.bridge_state_changed.connect(func(_o: bool) -> void:
		_dirty = true
		if _open:
			fill())


func setup(k: MenuKit, s: MenuShell) -> void:
	kit = k
	shell = s
	face = shell.face_node("journal")
	link_wire = MenuLink.new()
	link_wire.name = "Link"
	shell.box().add_child(link_wire)
	link_wire.setup(kit, shell)
	# the fixed parts: the two runs off the trunk, and the enclosure's seam
	var f := Node3D.new()
	f.name = "Runs"
	face.add_child(f)
	MenuParts.seam(f, 574, 104, 700)
	for x: float in [LEFT_RUN, RIGHT_RUN]:
		MenuParts.wire(f, [Vector2(x, MenuParts.TRUNK_Y), Vector2(x, 692)],
				MenuParts.WIRE)
	# each column answers to the wheel
	kit.pick_rect("journal", f, Rect2(LEFT_RUN - 10, TOP - 10, RIGHT_RUN - LEFT_RUN,
			BOTTOM - TOP + 20), 0.0, 0.0008, "col:0")
	kit.pick_rect("journal", f, Rect2(RIGHT_RUN - 10, TOP - 10, BEAD_X + 40 - RIGHT_RUN,
			BOTTOM - TOP + 20), 0.0, 0.0008, "col:1")
	fill()


## The Map the link goes into.
func bind_map(m: MapFace) -> void:
	map_face = m


## Fill both columns from what the client holds now, keeping the focus on
## the same thing -- the same passage or place, by its identity.
func fill() -> void:
	_dirty = false
	fills += 1
	if kit == null:
		return
	var was := current_link()
	var was_state := _shown_state
	# The Map's rows next: every link and explanation here is read from
	# them, and a snapshot may have reached this wall before that one.
	if map_face != null:
		map_face.fresh()
	_build()
	note = ""
	if not was.is_empty():
		var found := _find(was)
		if found.is_empty():
			note = "THE PASSAGE YOU FOLLOWED IS NOT IN THE JOURNAL NOW." \
					if was.has("edge") else "THE PLACE YOU FOLLOWED IS NOT IN THE " \
					+ "JOURNAL NOW."
		else:
			column = int(found["column"])
			focus[column] = int(found["index"])
			var now := _edge_state(was)
			if was_state != "" and now != "" and now != was_state:
				note = "NOW %s." % now.to_upper()
	_layout(true)
	_update_link()


## Every line on the wall, in order: for the suite, and for anything that
## has to ask what the journal says.
func lines() -> Array:
	if _dirty:
		fill()
	var out: Array = []
	for col: int in [0, 1]:
		for e: Dictionary in _entries[col]:
			out.append(str(e["text"]))
	return out


## The lines of one section, by its heading (its empty-section words when
## it has none).
func section(heading: String) -> Array:
	if _dirty:
		fill()
	var out: Array = []
	for col: int in [0, 1]:
		for e: Dictionary in _entries[col]:
			if bool(e["head"]) and str(e["section"]) == heading and bool(e["empty"]):
				return [str(e["empty_words"])]
			if not bool(e["head"]) and str(e["section"]) == heading:
				out.append(str(e["text"]))
	return out


# ------------------------------------------------------------ the entries

func _build() -> void:
	var snapshot: Dictionary = BridgeClient.snapshot
	_entries = {0: [], 1: []}
	var in_zone := not JournalQuery.active_zone(snapshot).is_empty()
	var objectives: Array = []
	for line: Variant in JournalQuery.objectives(snapshot):
		objectives.append({"text": str(line)})
	_section(0, "OBJECTIVES", objectives, "No campaign yet.")
	var notes: Array = []
	for n: Dictionary in JournalQuery.notes(BridgeClient.interpretations()):
		notes.append({"text": "%s -- %s" % [str(n["title"]), str(n["text"])],
			"source": str(n["source"])})
	_section(0, "NOTES", notes, "None yet: every Check you claim brings one.")
	if in_zone:
		var shut: Array = []
		for row: Dictionary in JournalQuery.still_shut_rows(snapshot):
			shut.append({"text": str(row["text"]), "link": {"edge": str(row["edge_id"]),
				"kind": "shut"}})
		_section(1, "STILL SHUT", shut, "Nothing you have found is shut.")
	var done: Array = []
	for row: Dictionary in JournalQuery.done_here_rows(snapshot):
		var edges: Array = row["edges"]
		done.append({"text": str(row["text"]), "link": {"edge": str(edges[0]),
			"kind": "done", "edges": edges, "circuits": row["circuits"]}
			if not edges.is_empty() else {}})
	_section(1, "WHAT YOU DID HERE", done, "Nothing yet." if in_zone
			else "You are not in a Zone.")
	var places: Array = []
	for row: Dictionary in JournalQuery.places_rows(snapshot):
		places.append({"text": str(row["text"]), "link": {"room": str(row["room_id"]),
			"kind": "place"}})
	_section(1, "PLACES FOUND", places, "None yet." if in_zone
			else "Places are listed inside a Zone.")


func _section(col: int, head: String, rows: Array, empty: String) -> void:
	var list: Array = _entries[col]
	list.append({"head": true, "text": head, "empty": rows.is_empty(),
		"empty_words": empty, "section": head})
	for row: Dictionary in rows:
		var link: Dictionary = row.get("link", {})
		list.append({"head": false, "section": head, "text": str(row["text"]),
			"link": link, "source": str(row.get("source", ""))})


## Place every entry of both columns; the focused one unfolds, and each
## column scrolls to keep its focus in view.
func _layout(_at_once := false, by_hand := -1) -> void:
	if _root != null:
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Entries"
	face.add_child(_root)
	_cols.clear()
	var shade := float(shell.shade.get("journal", 1.0))
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
				var empty := kit.wrap(str(e["empty_words"]), 2, w) if bool(e["empty"]) \
						else PackedStringArray()
				e["empty_lines"] = empty
				e["h"] = HEAD_H + (LINE * empty.size() + 6.0 if bool(e["empty"]) else 0.0)
				y += float(e["h"]) + 14.0
				continue
			var lines := kit.wrap(str(e["text"]), 2, w)
			e["lines"] = lines
			var h := lines.size() * LINE
			if col == column and i == _focused_index(col):
				e["explain"] = _explanation(e)
				h += (e["explain"] as Array).size() * LINE \
						+ (8.0 if not (e["explain"] as Array).is_empty() else 0.0)
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
			_draw(holder, col, i, e, x, top, w, shade)
		var run := LEFT_RUN if col == 0 else RIGHT_RUN
		if sc > 0.5:
			MenuParts.sprite(kit, holder, "arrow_up", Vector2(run + 22, TOP - 6), 2, ENTRY,
					0.004)
		if total - sc > view + 0.5:
			MenuParts.sprite(kit, holder, "arrow_down", Vector2(run + 22, BOTTOM + 12), 2,
					ENTRY, 0.004)
	_update_link()


func _draw(holder: Node3D, col: int, i: int, e: Dictionary, x: float,
		top: float, w: float, shade: float) -> void:
	var run := LEFT_RUN if col == 0 else RIGHT_RUN
	if e["head"]:
		MenuParts.vflag(kit, holder, run, top, str(e["text"]), shade)
		var ey := top + HEAD_H + 6.0
		for line: String in e.get("empty_lines", []):
			MenuParts.text(kit, holder, line, Vector2(x, ey), 2, NOTE_INK, 0.003)
			ey += LINE
		return
	var focused := col == column and i == _focused_index(col)
	var link: Dictionary = e["link"]
	var h: float = e["h"]
	var ty := top + (12.0 if focused else 0.0)       # where its words start
	if focused:
		var tw := LEFT_TAG_W if col == 0 else RIGHT_TAG_W
		var r := Rect2(run + 16, top, tw, h)
		MenuParts.tag(holder, r, TAG_Z, false, shade)
		# clipped to the run
		MenuParts.block(holder, Rect2(run - 2, top + 8, 20, 8), 0.012, 0.024,
				MenuParts.mat(MenuParts.METAL, 0.6, 0.35))
		MenuParts.block(holder, Rect2(run + 20, top + 8, 4, h - 16), TAG_Z,
				TAG_Z + 0.0006, MenuParts.unlit(MenuKit.SIGNAL), false)
		e["tag"] = r
		kit.pick_rect("journal", holder, r, TAG_Z - 0.004, TAG_Z,
				"entry:%d:%d" % [col, i])
	else:
		if hovered == col * 1000 + i:
			var ground := MenuParts.own(MenuParts.CAB_HI.lightened(0.12))
			ground.albedo_color.a = 0.9
			MenuParts.block(holder, Rect2(x - 12, top - 4, w + 24, h), 0.0, 0.0012,
					ground, false)
		kit.pick_rect("journal", holder, Rect2(x - 12, top - 4, (BEAD_X + 24 - x + 12)
				if col == 1 else w + 24, h), 0.0, 0.0014, "entry:%d:%d" % [col, i])
	var z := TAG_Z + 0.0012 if focused else 0.003
	var colour := MenuParts.FLAG_INK if focused else ENTRY
	if not focused and str(e["section"]) == "OBJECTIVES":
		colour = MenuParts.INK
	elif not focused and str(e["section"]) == "NOTES":
		colour = NOTE_INK
	var y := ty
	for line: String in e["lines"]:
		MenuParts.text(kit, holder, line, Vector2(x, y), 2, colour, z)
		y += LINE
	if not (e["explain"] as Array).is_empty():
		y += 8.0
	# The answer, on the entry itself.
	for line: String in e["explain"]:
		MenuParts.text(kit, holder, line, Vector2(x + 16, y), 2, MenuParts.TAG_DIM, z)
		y += LINE
	if focused and note != "":
		MenuParts.text(kit, holder, note, Vector2(x + 16, y + 6), 2, MenuParts.FLAG_INK, z)
	# A linked entry carries its connector's symbol; the focused one's link
	# leaves the tag's end.
	if not link.is_empty() and col == 1:
		var bead := _bead_of(link)
		MenuParts.sprite(kit, holder, str(bead["icon"]), Vector2(BEAD_X, ty + 9), 2,
				bead["colour"], TAG_Z + 0.0025 if focused else 0.004)
		if focused:
			e["anchor"] = Vector2(RIGHT_RUN + 16 + RIGHT_TAG_W, ty + 9)
			e["anchor_top"] = top


## A linked entry's symbol: its gate's (in its circuit's colour), or a way
## out.
func _bead_of(link: Dictionary) -> Dictionary:
	if link.has("edge"):
		var c := _connector(str(link["edge"]))
		var circuits: Array = c.get("circuits", [])
		var symbol := str(c.get("symbol", ""))
		if str(c.get("state", "")) != "open" and not circuits.is_empty() \
				and MapFace.SYMBOL_ICON.has(symbol):
			var colours: Dictionary = map_face.colours if map_face != null else {}
			return {"icon": MapFace.SYMBOL_ICON[symbol],
				"colour": colours.get(str(circuits[0]), MenuKit.INK_DIM)}
	return {"icon": "exit", "colour": MenuParts.INK}


## What the save says about the thing an entry names -- the useful answer,
## so the map is context and never required reading.
func _explanation(e: Dictionary) -> Array:
	var link: Dictionary = e["link"]
	var out := []
	if str(e.get("source", "")) != "":
		for line in kit.wrap(str(e["source"]), 2, LEFT_W - 16.0):
			out.append(line)
	if link.has("edge"):
		var c := _connector(str(link["edge"]))
		if c.is_empty():
			return out + ["NOT ON THIS ZONE'S MAP."]
		var names := JournalQuery.room_names(JournalQuery.zone_map(BridgeClient.snapshot))
		var a := str(names.get(str(c["room_a"]), "")).to_upper()
		var b := str(names.get(str(c["room_b"]), "")).to_upper()
		for line in kit.wrap("BETWEEN %s AND %s" % [a if a != ""
				else JournalQuery.UNWALKED.to_upper(), b if b != ""
				else JournalQuery.UNWALKED.to_upper()], 2, RIGHT_W - 16.0):
			out.append(line)
		var circuits: Array = c.get("circuits", [])
		if not circuits.is_empty():
			out.append("HELD BY: %s" % _circuit_words(str(circuits[0])))
		out.append("NOW: %s" % str(c["state"]).to_upper())
		out.append("ON THE MAP, ROUND THE CORNER (%s)" % _turn_key())
	elif link.has("room"):
		var detail := map_face._describe(str(link["room"])) if map_face != null else ""
		var lines := detail.split("\n")
		for i in range(1, lines.size()):
			for line in kit.wrap(lines[i], 2, RIGHT_W - 16.0):
				out.append(line)
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


## The connector the Map shows for an edge (the same rows the minimap
## draws), or {} when this save's map has no such passage.
func _connector(edge: String) -> Dictionary:
	if map_face == null:
		return {}
	for c: Dictionary in map_face.connectors_shown():
		if str(c["edge_id"]) == edge:
			return c
	return {}


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


## The link is drawn only to what this save's map has: a passage or place
## it does not know links to nothing.
func _update_link() -> void:
	var link := current_link()
	_shown_state = _edge_state(link)
	if map_face != null and not link.is_empty() \
			and map_face.target_local(link) == Vector3.INF:
		link = {}
	if map_face != null:
		map_face.set_link(link)
	var list: Array = _entries.get(column, [])
	var i := _focused_index(column) if not list.is_empty() else -1
	var anchor := Vector2.INF
	var bead := {}
	if i >= 0 and i < list.size() and not link.is_empty():
		var e: Dictionary = list[i]
		anchor = e.get("anchor", Vector2.INF)
		bead = _bead_of(link)
	if link_wire != null:
		link_wire.bind_ends(anchor, link, bead, map_face)


# ------------------------------------------------------------ input

func nav(dir: Vector2i, _repeat := false) -> void:
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
	var link := current_link()
	if not link.is_empty() and map_face != null \
			and map_face.target_local(link) != Vector3.INF:
		kit.cue("follow")
		map_face.follow(link)
		shell.turn(-1)
	else:
		kit.cue("edge")


func back() -> bool:
	return false


func back_words() -> String:
	return "close"


func hover(hit: Dictionary) -> void:
	var was := hovered
	hovered = _entry_of(str(hit.get("target", "")))
	if hovered != was:
		_layout(false, column)


func _entry_of(target: String) -> int:
	if not target.begins_with("entry:"):
		return -1
	var p := target.split(":")
	return int(p[1]) * 1000 + int(p[2])


func click(hit: Dictionary, button := MOUSE_BUTTON_LEFT) -> bool:
	if button != MOUSE_BUTTON_LEFT:
		return false
	var h := _entry_of(str(hit.get("target", "")))
	if h < 0:
		return false
	var col := h / 1000
	var i := h % 1000
	if col == column and i == _focused_index(col):
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
		_layout(false, col)
	return true


## Scrolling by hand moves the column and does not snap back to the focus.
func wheel(hit: Dictionary, dir: int) -> bool:
	var target := str(hit.get("target", ""))
	var col := column
	if target.begins_with("col:"):
		col = int(target.trim_prefix("col:"))
	elif target.begins_with("entry:"):
		col = int(target.split(":")[1])
	var was: float = scroll[col]
	scroll[col] = maxf(0.0, float(scroll[col]) + 60.0 * dir)
	_layout(false, col)
	if is_equal_approx(float(scroll[col]), was):
		kit.cue("edge")
	else:
		kit.cue("scroll")
	return true


## The right stick scrolls the focused column by hand.
func scroll_by(px: float) -> void:
	scroll[column] = maxf(0.0, float(scroll[column]) + px)
	_layout(false, column)


## Up and Down, PgUp and PgDn: the old wall's keys, as entry moves and
## pages of them.
func raw_input(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_PAGEUP:
				scroll[column] = maxf(0.0, float(scroll[column]) - (BOTTOM - TOP) * 0.8)
				_layout(false, column)
				return true
			KEY_PAGEDOWN:
				scroll[column] = float(scroll[column]) + (BOTTOM - TOP) * 0.8
				_layout(false, column)
				return true
	return false


func prompts() -> Array:
	var out := [["move", "entries"], ["move_h", "columns"], ["click", "pick"]]
	var link := current_link()
	if not link.is_empty() and map_face != null \
			and map_face.target_local(link) != Vector3.INF:
		out.append(["accept", "show on the map"])
	return out


func repeats() -> bool:
	return true


# ------------------------------------------------------------ the shell's calls

func on_open(_is_front: bool) -> void:
	_open = true
	if _dirty:
		fill()


func on_close() -> void:
	_open = false


func on_front(_is_front: bool) -> void:
	pass


## The device changed: the keys the words name are its.
func on_device() -> void:
	if kit != null:
		_layout(true)


func focus_lost() -> void:
	pass


func tick(delta: float) -> void:
	if link_wire != null:
		link_wire.tick(delta)


## The key that turns toward the Map (right): E, or RB on the pad.
func _turn_key() -> String:
	return "RB" if kit.device == "pad" else SlotKeycaps.of_action("menu_page_right",
			"E").to_upper()


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
		"note": note, "scroll": [scroll[0], scroll[1]], "last_index": last,
		"fills": fills,
		# the focused entry is wholly on the wall
		"focused_seen": i >= 0 and i < list.size() and (list[i] as Dictionary).has("seen"),
		"link_wire": link_wire.state() if link_wire != null else {}}
