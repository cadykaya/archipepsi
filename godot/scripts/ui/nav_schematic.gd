class_name NavSchematic
extends CanvasLayer
## A REVIEW-ONLY NAVIGATION SCHEMATIC (F5). Not a map feature.
##
## "I'm lost. I realize we have made a 3d metroidvania with no map."
##
## The owner is right and the answer is a design decision they have not
## made yet, so this is deliberately the smallest thing that can be
## LOOKED AT rather than the first half of a map system. It sits on the
## debug route beside the F3 readout and the F4 labels, it is off by
## default, and nothing in the game reads it.
##
## WHAT IT DRAWS, and every one of these is a fact something else
## already owns:
##
##   rooms      the ones `ZoneController._track_chamber` has seen the
##              body in this session -- the same set the unlock message
##              names places from. NOT a stored exploration record.
##   links      the Zone's OWN declared `edges`, and only where BOTH
##              ends have been entered. A link to somewhere you have
##              not been is a route this hands you, and that is the
##              whole game.
##   locks      `gates_not_yet_open()`, on rooms already discovered.
##   stations   `stations_reached()`.
##   here       the chamber the body is in.
##
## WHAT IT IS NOT. It is a SCHEMATIC: the dots are room centres in the
## Zone's own plan and the lines are declared adjacency, so a line is
## not a corridor you can see and its length is not a distance. There
## is no bearing arrow and no path guidance -- "which way now" is the
## question the owner wants answered and answering it badly is worse
## than not answering it. Nothing here persists, so a reload starts it
## empty and it says so rather than showing a Zone nobody has walked.

const PAD := 36.0
const DOT := 7.0

var _view: _Plan

## THE ONE RULE, SEPARATED SO IT CAN BE ASKED. A room is on the
## schematic when the body has been in it and the layout knows where it
## is -- nothing else. Kept out of `_draw` because "does this ever show
## a room the player has not walked" is the question this prototype has
## to be able to answer, and a question you can only answer by looking
## at a picture is one that gets answered wrong.
static func visible_rooms(entered: Dictionary,
		bounds: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for rid: Variant in entered:
		if bounds.has(rid):
			out.append(str(rid))
	out.sort()
	return out

## And a link is drawn only when BOTH its ends are already walked. A
## line to somewhere you have not been is a route this hands you.
static func visible_links(edges: Array, rooms: Array) -> Array:
	var out: Array = []
	for raw: Variant in edges:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = raw
		if str(edge.get("realization", "JOINED")) != "JOINED":
			continue
		var a := str(edge.get("room_a", ""))
		var b := str(edge.get("room_b", ""))
		if rooms.has(a) and rooms.has(b):
			out.append([a, b])
	return out

func _ready() -> void:
	layer = 11
	visible = false
	_view = _Plan.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

## Hand it the facts. It keeps no copy between frames beyond what it
## draws, and it never asks the world for anything itself.
func show_zone(entered: Dictionary, bounds: Dictionary, edges: Array,
		gates: Dictionary, stations: Dictionary, here: String) -> void:
	_view.entered = entered
	_view.bounds = bounds
	_view.edges = edges
	_view.gates = gates
	_view.stations = stations
	_view.here = here
	_view.queue_redraw()

func toggle() -> void:
	visible = not visible
	_view.queue_redraw()

class _Plan extends Control:
	var entered := {}
	var bounds := {}
	var edges: Array = []
	var gates := {}
	var stations := {}
	var here := ""

	const INK := Color(0.72, 0.80, 0.86)
	const LINK := Color(0.38, 0.52, 0.60)
	const HERE := Color(0.45, 1.0, 0.8)
	const LOCKED := Color(0.95, 0.72, 0.35)
	const STATION := Color(0.55, 0.95, 0.75)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2(12, 12), Vector2(430, 348)),
				Color(0.04, 0.05, 0.07, 0.93))
		draw_string(font, Vector2(24, 34),
				"NAVIGATION SCHEMATIC  -  PROTOTYPE, F5",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		var seen := NavSchematic.visible_rooms(entered, bounds)
		if seen.is_empty():
			draw_string(font, Vector2(24, 60),
					"Nothing walked yet. This shows rooms you have been",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
			draw_string(font, Vector2(24, 78),
					"in, and only those. It does not survive a reload.",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
			return
		# The plan of what has been seen, fitted to the panel. Room
		# CENTRES: a schematic of adjacency, not a floor plan.
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var at := {}
		for rid: String in seen:
			var box: AABB = bounds[rid]
			var p := Vector2(box.get_center().x, box.get_center().z)
			at[rid] = p
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var span := hi - lo
		# The plan stops well above the legend: the first version let the
		# dots reach y 290 with the legend starting at 279, so a room in
		# the bottom row sat on the words describing it.
		var frame := Rect2(Vector2(30, 70), Vector2(394, 196))
		var scale := 1.0
		if span.x > 0.1 or span.y > 0.1:
			scale = minf(frame.size.x / maxf(span.x, 0.1),
					frame.size.y / maxf(span.y, 0.1))
		var screen := {}
		for rid: String in seen:
			var p: Vector2 = at[rid]
			screen[rid] = frame.position + Vector2(
					(p.x - lo.x) * scale
							+ (frame.size.x - span.x * scale) * 0.5,
					(p.y - lo.y) * scale
							+ (frame.size.y - span.y * scale) * 0.5)

		# DECLARED ADJACENCY, and only between two rooms already walked.
		for pair: Variant in NavSchematic.visible_links(edges, seen):
			var link: Array = pair
			draw_line(screen[link[0]], screen[link[1]], LINK, 2.0)

		var locked_rooms := {}
		for ref: Variant in gates:
			locked_rooms[str(ref).split("/")[0]] = true
		var station_rooms := {}
		for sid: Variant in stations:
			station_rooms[str(sid)] = true

		for rid: String in seen:
			var p: Vector2 = screen[rid]
			var tint := INK
			if rid == here:
				tint = HERE
			elif locked_rooms.has(rid):
				tint = LOCKED
			draw_circle(p, DOT if rid != here else DOT + 3.0, tint)
			draw_string(font, p + Vector2(10, 4), rid,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)

		var legend := ("%d room(s) walked   |   green = you are here   "
				+ "|   amber = a gate not yet open") % seen.size()
		draw_string(font, Vector2(24, 316), legend,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		if not station_rooms.is_empty():
			draw_string(font, Vector2(24, 298),
					"stations reached: " + ", ".join(
						PackedStringArray(station_rooms.keys())),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, STATION)
		draw_string(font, Vector2(24, 280),
				"schematic: lines are declared adjacency, not routes",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, LINK)
