extends RefCounted

const Kit := preload("res://_harness/study_kit.gd")
## THE JOURNAL AS STRIPS: Thread's subject, and Lens's neighbour at rest.
##
## Every line is `JournalQuery`'s own, in its own order: the objectives,
## what is still shut, what was done here, the places found, and each
## Echo's read. A strip is a line of text on the wall with a quiet ground
## that only appears when it is picked -- no panel grid, no boxes round
## every sentence.

const PITCH := 24.0
const HEAD_GAP := 16.0

var entries: Array = []      # {kind, index, text, rect, ground, bar, label}


func _init(kit: Kit, face: Node3D, j: Dictionary, x0 := 48.0,
		width := 700.0, top := 86.0, notes := 3) -> void:
	var y := top
	y = _section(kit, face, "OBJECTIVES", j["objectives"], "objective",
			x0, width, y)
	y = _section(kit, face, "STILL SHUT", j["still_shut"], "shut", x0,
			width, y)
	y = _section(kit, face, "DONE HERE", j["done_here"], "done", x0,
			width, y)
	y = _places(kit, face, j["places"], x0, width, y)
	var lines: Array = []
	for n: Dictionary in (j["notes"] as Array).slice(0, notes):
		lines.append("%s -- %s" % [str(n["title"]), str(n["text"])])
	_section(kit, face, "NOTES", lines, "note", x0, width, y)


func _section(kit: Kit, face: Node3D, head: String, lines: Array,
		kind: String, x0: float, width: float, y: float) -> float:
	if lines.is_empty():
		kit.label(face, head + "  -- NONE", Vector2(x0, y), 2,
				Kit.INK_FAINT)
		return y + PITCH + HEAD_GAP
	kit.label(face, head, Vector2(x0, y), 2, Kit.INK_FAINT)
	y += PITCH
	for i in lines.size():
		var text := str(lines[i])
		var rows := _rows(kit, text, width - 24.0)
		var h := rows * 20.0 + 4.0
		var rect := Rect2(Vector2(x0, y - 3.0), Vector2(width, h))
		var ground: MeshInstance3D = kit.card(face, rect.position,
				rect.size, 0.002, Kit.SHEET_HI, 0.0, true)
		var bar: MeshInstance3D = kit.card(face, rect.position,
				Vector2(4, rect.size.y), 0.0025, Kit.SIGNAL, 0.0, true)
		var l: Label3D = kit.label(face, text, Vector2(x0 + 14.0, y),
				2, Kit.INK if kind != "note" else Kit.INK_DIM,
				0.003, width - 24.0)
		entries.append({"kind": kind, "index": i, "text": text, "rect": rect,
			"ground": ground, "bar": bar, "label": l})
		y += h + 4.0
	return y + HEAD_GAP


func _places(kit: Kit, face: Node3D, places: Array, x0: float,
		width: float, y: float) -> float:
	kit.label(face, "PLACES", Vector2(x0, y), 2, Kit.INK_FAINT)
	y += PITCH
	var x := x0
	for i in places.size():
		var name := str(places[i])
		var w: float = kit.measure(name, 2) + 20.0
		if x + w > x0 + width:
			x = x0
			y += PITCH
		var rect := Rect2(Vector2(x, y - 3.0), Vector2(w, 22))
		var ground: MeshInstance3D = kit.card(face, rect.position,
				rect.size, 0.002, Kit.SHEET_HI, 0.0, true)
		var bar: MeshInstance3D = kit.card(face, rect.position,
				Vector2(4, rect.size.y), 0.0025, Kit.SIGNAL, 0.0, true)
		var l: Label3D = kit.label(face, name, Vector2(x + 10.0, y),
				2, Kit.INK)
		entries.append({"kind": "place", "index": i, "text": name,
			"rect": rect, "ground": ground, "bar": bar, "label": l})
		x += w + 10.0
	return y + PITCH + HEAD_GAP


## How many wrapped rows `text` takes at 2x in `width` page px -- the same
## greedy rule Label3D's word wrap uses, near enough to size the ground.
static func _rows(kit: Kit, text: String, width: float) -> int:
	var rows := 1
	var line := ""
	for word in (kit.sanitize(text) as String).split(" "):
		var trial := word if line == "" else line + " " + word
		if float(kit.measure(trial, 2)) > width and line != "":
			rows += 1
			line = word
		else:
			line = trial
	return rows


func find(kind: String, index: int) -> Dictionary:
	for e: Dictionary in entries:
		if str(e["kind"]) == kind and int(e["index"]) == index:
			return e
	return {}
