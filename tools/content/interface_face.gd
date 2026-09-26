extends SceneTree
## Track A -- the interface family doing its job, in the engine.
##
## The font harness proves metrics survive and the nine-slice harness
## proves borders do not distort. Neither shows whether the pieces make
## an INTERFACE. This composes the real font and the real panels into a
## face -- a window, a header, a grid of cells, one of them selected,
## counts in the cells -- renders it at authored size, and presents it
## magnified with nearest so the owner is looking at the actual pixels.
##
## There is no item art in it, and that is deliberate. The equipment-slot
## vocabulary is Production's to define and the ruling was explicit:
## proceed with the shell, the grids, the frames and the selection
## treatment, and defer anything that needs a slot's meaning. So the
## cells are empty and the counts are real.

const SCALE := 3
const CELL := Vector2i(40, 24)
const COLS := 4
const ROWS := 3
const PAD := 4
const FONT_SIZE := 8

var _bench: GDScript
var _out := ""
var _font: FontFile
var _text: FontFile
var _panels := {}
var _spec := {}
var _icons := {}
var _palette := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "."
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		push_error("[face] no artbench.gd staged")
		quit(1)
		return
	_spec = JSON.parse_string(
		FileAccess.get_file_as_string("res://_harness/panels.json"))
	for name in ["panel", "well", "selected", "keycap"]:
		_panels[name] = load("res://_harness/panel_%s.png" % name)
	_font = load("res://_harness/ui_numerals.fnt") as FontFile
	_text = load("res://_harness/ui_text.fnt") as FontFile
	if _font == null or _text == null:
		push_error("[face] a bitmap font did not load")
		quit(1)
		return
	_icons = JSON.parse_string(
		FileAccess.get_file_as_string("res://_harness/icons.json"))
	_palette = JSON.parse_string(
		FileAccess.get_file_as_string("res://_harness/art_palette.json"))
	await _face()
	await _sizes()
	await _prompts()
	print("[face] wrote 3 sheet(s) to %s" % _out)
	quit(0)


func _patch(parent: Node, name: String, at: Vector2i,
		size: Vector2i) -> NinePatchRect:
	# All four margins from the contract: the keycap's are unequal (its
	# front lip is deeper than its top edge), and this used to apply the
	# left one everywhere.
	var insets: Dictionary = _spec[name]["insets"]
	var patch := NinePatchRect.new()
	patch.texture = _panels[name]
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.patch_margin_left = int(insets["left"])
	patch.patch_margin_top = int(insets["top"])
	patch.patch_margin_right = int(insets["right"])
	patch.patch_margin_bottom = int(insets["bottom"])
	patch.position = Vector2(at)
	patch.size = Vector2(size)
	parent.add_child(patch)
	return patch


func _count(parent: Node, text: String, at: Vector2i, size: Vector2i,
		align: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96))
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(at)
	label.size = Vector2(size)
	parent.add_child(label)


## artbench.label draws 8 px per character and CLIPS at the image edge
## without saying so -- the first pass of these sheets lost the end of
## its own banner that way. So the caption is measured against the sheet
## and a line that will not fit is a failure, not a trim.
const MARGIN := 12
## Room above the art for the caption block, in authored pixels: four
## lines at 18 px on a sheet shown at SCALE.
const TOP := 34


func _shoot(view: SubViewport, name: String, lines: Array,
		banner := "PROPOSAL -- NOT OWNER-APPROVED") -> void:
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	# Magnified with NEAREST, after the render. Rendering large and
	# letting the engine scale would show a different picture from the
	# one the game draws; this shows the authored pixels, bigger.
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE,
			Image.INTERPOLATE_NEAREST)
	var room := int((image.get_width() - MARGIN * 2) / 8.0)
	var all: Array = [banner] + lines
	for line in all:
		if String(line).length() > room:
			push_error("[face] %s: a caption is %d characters and %d fit "
					% [name, String(line).length(), room]
					+ "across a %d px sheet: %s"
					% [image.get_width(), line])
			return
	for i in all.size():
		_bench.call("label", image, all[i], Vector2i(MARGIN, MARGIN + i * 18),
				Color(1, 0.86, 0.3) if i == 0 else Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		push_error("[face] could not write %s" % name)
	print("[face] %s: %dx%d authored, shown at %dx"
			% [name, view.size.x, view.size.y, SCALE])


func _face() -> void:
	var size := Vector2i(
		PAD * 3 + COLS * (CELL.x + PAD) + PAD,
		TOP + PAD * 2 + 16 + ROWS * (CELL.y + PAD) + PAD * 2)
	var view := SubViewport.new()
	view.size = size
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)

	# The window, then a header well with a total in it.
	_patch(view, "panel", Vector2i.ZERO, size)
	var head := Vector2i(PAD * 2, TOP + PAD)
	var head_size := Vector2i(size.x - PAD * 4, 16)
	_patch(view, "well", head, head_size)
	_count(view, "12/48", head + Vector2i(0, 1), head_size,
			HORIZONTAL_ALIGNMENT_CENTER)

	# The grid. One cell is `selected` -- the one you would act on.
	var counts := ["3", "12", "1", "99", "4", "7", "21", "2",
			"x5", "8", "16", "1"]
	var top := head.y + head_size.y + PAD * 2
	for r in ROWS:
		for c in COLS:
			var at := Vector2i(PAD * 2 + c * (CELL.x + PAD),
					top + r * (CELL.y + PAD))
			var which := "selected" if (r == 1 and c == 2) else "well"
			_patch(view, which, at, CELL)
			# Bottom-right, the way a quantity has been written on a
			# stack since before any of this was 3D.
			_count(view, counts[r * COLS + c],
					at + Vector2i(0, CELL.y - 11),
					Vector2i(CELL.x - 4, 8), HORIZONTAL_ALIGNMENT_RIGHT)
	await _shoot(view, "FACE_grid_and_selection", [
			"AUTHORED ART, IMPORTED INTO GODOT 4.5.1",
			"panel window; well header and cells; one selected cell",
			"counts in ui_numerals at 8 px. No item art -- slot",
			"vocabulary is Production's and is deferred."])
	view.queue_free()


func _sizes() -> void:
	## The same three treatments at four sizes. A nine-slice's whole
	## promise is that the corner in the first box is the corner in the
	## last one, so they are shown together at the magnification that
	## makes a one-pixel difference visible.
	var boxes := [Vector2i(10, 10), Vector2i(24, 16), Vector2i(60, 28),
			Vector2i(118, 40)]
	# The sheet is as wide as the row it has to hold. The first version
	# sized it from the LAST box alone and cropped three of them.
	var wide := PAD
	for box in boxes:
		wide += int(box.x) + PAD
	var view := SubViewport.new()
	view.size = Vector2i(wide, TOP + 3 * (40 + PAD))
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var back := ColorRect.new()
	back.color = Color(0.09, 0.10, 0.11)
	back.size = Vector2(view.size)
	view.add_child(back)
	var y := TOP
	for name in ["panel", "well", "selected"]:
		var x := PAD
		for box in boxes:
			_patch(view, name, Vector2i(x, y + (40 - box.y) / 2), box)
			x += box.x + PAD
		y += 40 + PAD
	await _shoot(view, "PANELS_at_four_sizes", [
			"panel, well, selected -- rows top to bottom",
			"each at 10x10 authored, then 24x16, 60x28, 118x40",
			"the corners are the same pixels at every size"])
	view.queue_free()


## A line of ui_text at its authored size.
func _say(parent: Node, text: String, at: Vector2i) -> int:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _text)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.91, 0.93, 0.96))
	label.position = Vector2(at)
	parent.add_child(label)
	return int(_text.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE).x)


## A keycap sized to its key's name: the name sits on the face, which is
## everything inside the insets minus the lip.
func _key(parent: Node, text: String, at: Vector2i) -> int:
	var insets: Dictionary = _spec["keycap"]["insets"]
	var w := int(_text.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE).x) + int(insets["left"]) + int(insets["right"]) + 2
	_patch(parent, "keycap", at, Vector2i(w, 12))
	_say(parent, text, at + Vector2i(int(insets["left"]) + 1,
			int(insets["top"])))
	return w


func _symbol(parent: Node, name: String, at: Vector2i, tint: Color) -> void:
	var rect := TextureRect.new()
	rect.texture = load("res://_harness/%s" % _icons[name]["file"])
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.modulate = tint
	rect.position = Vector2(at)
	parent.add_child(rect)


func _tint(family: String) -> Color:
	## The exact colour icons.json's `_tints` resolves the name to. The
	## symbols ink in pure white, so `modulate` by this IS this colour --
	## `run_ui_icons.sh` reads every pair back to prove it.
	return Color(str(_icons["_tints"][family]["hex"]))


func _prompts() -> void:
	## Keycaps, page arrows and the shared symbols, composed on the same
	## chrome as the grid. The symbols are shown in the tint icons.json
	## RECORDS for each state -- intent, not state art: the interface
	## applies it at runtime, and Production's vocabulary decides states.
	var view := SubViewport.new()
	view.size = Vector2i(236, TOP + PAD + 3 * 20 + PAD)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	_patch(view, "panel", Vector2i.ZERO, view.size)

	var y := TOP + PAD
	var x := PAD * 2
	for pair in [["E", "OPEN"], ["Q", "BACK"], ["TAB", "MAP"]]:
		x += _key(view, pair[0], Vector2i(x, y)) + 3
		x += _say(view, pair[1], Vector2i(x, y + 2)) + 10

	y += 20
	_patch(view, "well", Vector2i(PAD * 2, y - 2), Vector2i(view.size.x
			- PAD * 4, 16))
	x = PAD * 2 + 3
	_symbol(view, "arrow_left", Vector2i(x, y), _tint("chrome ink"))
	x += 14
	x += _say(view, "PAGE 2/5", Vector2i(x, y + 2)) + 2
	_symbol(view, "arrow_right", Vector2i(x, y), _tint("chrome ink"))
	x += 26
	_symbol(view, "arrow_up", Vector2i(x, y), _tint("chrome ink"))
	x += 14
	_symbol(view, "arrow_down", Vector2i(x, y), _tint("chrome ink"))

	y += 20
	_patch(view, "well", Vector2i(PAD * 2, y - 2), Vector2i(view.size.x
			- PAD * 4, 16))
	x = PAD * 2 + 3
	for pair in [["circuit", "powered"], ["circuit", "unpowered"],
			["control", "operable"], ["control", "not operable"],
			["exit", "open"], ["blocked", "blocked"]]:
		var family: String = _icons[pair[0]]["tint_by_state"][pair[1]]
		_symbol(view, pair[0], Vector2i(x, y), _tint(family))
		x += 16 if pair[1] in ["powered", "operable", "open"] else 26
	await _shoot(view, "PROMPTS_keycaps_and_symbols", [
			"keycaps: ui_text on the keycap nine-slice, 12 px tall",
			"page arrows round a page count; scroll up and down",
			"circuit on/off, control usable/not, exit open, blocked:",
			"white ink x the exact tint icons.json records"],
			"OWNER-APPROVED 2026-09-26 -- KEYCAP SYMBOLS PAGE ARROWS")
	view.queue_free()
