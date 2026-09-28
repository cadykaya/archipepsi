extends SceneTree
## "PLATFORM ε" in `ui_text` alone, through Godot's own importer.
##
##   godot --path godot -s _harness/platform_proof.gd -- <out-dir>
##
## Production's sign (`chamber_builders.gd:1137` at c12a72f) is the one
## line this proves. The face is the IMPORTED resource: the runner has
## already run the editor's import pass, as Production's project does.
##
## No fallback of any kind. The font's `fallbacks` are emptied and
## system fallback is off, so a character the face lacked could only
## draw as the engine's hex box, never as another font. The proof then
## checks the drawn epsilon, pixel for pixel, against the rows authored in
## `author_text.py`: at 1x, and at 2x through the importer's integer
## scaling. The labels on the proof are drawn in the same face.

const LINE := "PLATFORM ε"
const SIZE := 8
const INK := Color(1, 1, 1)
const PAPER := Color(0.09, 0.1, 0.12)
const SCALES := [1, 2, 4, 8]

var _faults: Array[String] = []
var _font: FontFile
var _spec: Dictionary


func _init() -> void:
	_run.call_deferred()


func _bad(what: String) -> void:
	_faults.append(what)
	print("[proof] FAULT: %s" % what)


class Canvas extends Control:
	var font: FontFile
	var lines: Array = []   # [text, Vector2 baseline-left, size]

	func _draw() -> void:
		for l: Array in lines:
			draw_string(font, l[1], l[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
					l[2], Color(1, 1, 1))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("[proof] usage: -- <out-dir>")
		quit(1)
		return
	var out := args[0]
	_font = load("res://_harness/ui_text.fnt") as FontFile
	_spec = JSON.parse_string(
			FileAccess.get_file_as_string("res://_harness/epsilon.json"))
	if _font == null or _spec == null:
		push_error("[proof] the face or the authored rows did not load")
		quit(1)
		return
	_font.fallbacks = []
	_font.allow_system_fallback = false
	print("[proof] ui_text: %d fallback(s), system fallback %s"
			% [_font.fallbacks.size(), _font.allow_system_fallback])
	for i in LINE.length():
		if not _font.has_char(LINE.unicode_at(i)):
			_bad("the face has no %s (U+%04X)"
					% [LINE[i], LINE.unicode_at(i)])
	var eps := "ε"
	var adv := _font.get_string_size(eps, HORIZONTAL_ALIGNMENT_LEFT, -1,
			SIZE).x
	if not is_equal_approx(adv, float(_spec["advance"])):
		_bad("the epsilon advances %s; authored %s" % [adv, _spec["advance"]])

	var view := SubViewport.new()
	view.size = Vector2i(480, 190)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Pixel text at an integer scale is drawn NEAREST. A viewport's canvas
	# defaults to linear filtering, which blurs every glyph at 2x.
	view.canvas_item_default_texture_filter = \
			Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(view)
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.size = Vector2(view.size)
	view.add_child(paper)
	var canvas := Canvas.new()
	canvas.font = _font
	canvas.size = Vector2(view.size)
	view.add_child(canvas)
	var y := 16
	var at := {}
	for s: int in SCALES:
		var base := Vector2(64, y + 6 * s)
		canvas.lines.append(["%dX" % s, Vector2(12, y + 6 * s), SIZE * min(s, 2)])
		canvas.lines.append([LINE, base, SIZE * s])
		at[s] = base
		y += 8 * s + 12
	canvas.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)

	# The epsilon's cell starts where "PLATFORM " ends; its ink starts one
	# column in, and its rows end on the baseline (base=6).
	for s: int in [1, 2]:
		var pen := _font.get_string_size("PLATFORM ",
				HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE * s).x
		var origin := Vector2i(int(at[s].x + pen), int(at[s].y) - 6 * s)
		var rows: Array = _spec["rows"]
		var top := int(_spec["baseline"]) - rows.size()
		var wrong := 0
		for cy in 8:
			for cx in 7:
				var want := false
				var ry := cy - top
				if ry >= 0 and ry < rows.size():
					var row: String = rows[ry]
					want = cx >= 1 and cx - 1 < row.length() \
							and row[cx - 1] == "#"
				for sy in s:
					for sx in s:
						var p := image.get_pixel(origin.x + cx * s + sx,
								origin.y + cy * s + sy)
						var inked := p.get_luminance() > 0.5
						if inked != want:
							wrong += 1
		if wrong:
			_bad("at %dx the drawn epsilon differs from the authored rows "
					% s + "in %d pixel(s)" % wrong)
		else:
			print("[proof] at %dx the drawn epsilon is the authored one, "
					% s + "pixel for pixel (%dx%d cell)" % [7 * s, 8 * s])

	if image.save_png(out.path_join("platform_epsilon_proof.png")) != OK:
		_bad("could not write the proof")
	else:
		print("[proof] platform_epsilon_proof.png")
	if _faults.is_empty():
		print("[proof] PASS -- \"%s\" is drawn by ui_text alone" % LINE)
		quit(0)
	else:
		quit(1)
