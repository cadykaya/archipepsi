extends SceneTree
## Track A -- do the interface symbols arrive in Godot 4.5.1 as drawn?
##
## `author_icons.py` writes eight 12 px symbols and `icons.json`, the
## contract naming each file, its size, what it means and the tint the
## interface is meant to give it by state. This reads the contract and
## checks the IMPORTED textures against rules it states itself:
##
##   * the texture is the declared size and the import is lossless;
##   * one ink colour on transparency -- a symbol is a shape, and the
##     colour that says "usable" or "locked" is a runtime STATE;
##   * a clear 1 px outer ring, so two symbols side by side, or a symbol
##     on a keycap, never touch;
##   * the arrows are one arrow: left is right mirrored, up is right
##     turned a quarter anticlockwise, down is up flipped -- re-derived
##     here from the imported pixels with Godot's own Image operations,
##     not from the authoring script's strings;
##   * the ink is PURE WHITE (RULED 2026-09-26), and every tint the
##     contract names resolves, in `_tints`, to the exact colour of its
##     source -- the palette step it names, or the text face's own ink
##     for "chrome ink";
##   * the point of both: each symbol, drawn with `modulate` set to each
##     tint its states name, renders EXACTLY that colour.
##
## Then it proves the margin, ink and tint checks can fail, on doctored
## copies.

const CONTRACT := "res://_harness/icons.json"
const PALETTE := "res://_harness/art_palette.json"
## The text face's page: "chrome ink" must be ITS ink, read off the page.
const TEXT_PAGE := "res://_harness/ui_text.png"
const CHROME_INK := "chrome ink"
const WHITE := Color(1, 1, 1, 1)

var _faults: Array[String] = []
var _notes := {}


func _bad(what: String) -> void:
	_faults.append(what)
	print("[icons] FAULT: %s" % what)


func _init() -> void:
	var spec: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CONTRACT))
	var palette: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(PALETTE))
	if typeof(spec) != TYPE_DICTIONARY or spec.is_empty():
		_bad("no icon contract at %s" % CONTRACT)
		_finish()
		return
	if typeof(palette) != TYPE_DICTIONARY:
		_bad("no palette at %s" % PALETTE)
		_finish()
		return
	await _run(spec, palette)
	_finish()


func _run(spec: Dictionary, palette: Dictionary) -> void:
	if not spec.has("_tints"):
		_bad("icons.json has no _tints table: a tint name with no colour "
			 + "cannot be applied exactly")
		return
	var tints: Dictionary = spec["_tints"]
	_tint_table(tints, palette)
	var images := {}
	var textures := {}
	var names: Array = spec.keys().filter(
			func(k: String) -> bool: return not k.begins_with("_"))
	names.sort()
	for name in names:
		var entry: Dictionary = spec[name]
		var path := "res://_harness/%s" % entry["file"]
		var texture: Variant = load(path)
		if texture == null or not (texture is Texture2D):
			_bad("%s: load(%s) gave %s" % [name, path, texture])
			continue
		var image: Image = texture.get_image()
		image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var want := Vector2i(int(entry["size"][0]), int(entry["size"][1]))
		if image.get_size() != want:
			_bad("%s: imported at %s, the contract declares %s"
				 % [name, image.get_size(), want])
			continue
		var on_disk := Image.new()
		if on_disk.load(path) != OK:
			_bad("%s: could not read the source png back" % name)
			continue
		on_disk.convert(Image.FORMAT_RGBA8)
		# Fully transparent on both sides counts as the same pixel: the
		# importer rewrites the RGB under zero alpha on purpose (fix alpha
		# border) and nothing ever draws it.
		var moved := 0
		for y in want.y:
			for x in want.x:
				var a := on_disk.get_pixel(x, y)
				var b := image.get_pixel(x, y)
				if not ((a.a == 0.0 and b.a == 0.0) or a == b):
					moved += 1
		if moved > 0:
			_bad("%s: the importer changed %d pixel(s)" % [name, moved])
		var shape := _shape_faults(image)
		if shape != "":
			_bad("%s: %s" % [name, shape])
		elif _ink_of(image) != WHITE:
			_bad("%s: the ink is #%s; a tintable symbol inks in pure white "
				 % [name, _ink_of(image).to_html(false)] + "so a modulate "
				 + "lands on the palette colour exactly (RULED 2026-09-26)")
		for state in entry["tint_by_state"]:
			var tint: String = entry["tint_by_state"][state]
			if not tints.has(tint):
				_bad("%s: tint '%s' for state '%s' has no colour in _tints"
					 % [name, tint, state])
		images[name] = image
		textures[name] = texture
		_notes[name] = {"size": [want.x, want.y], "lossless": moved == 0,
			"shape": "ok" if shape == "" else shape}
		print("[icons] %s: %dx%d, lossless, %s" % [name, want.x, want.y,
			  "one ink, 1 px margin" if shape == "" else shape])

	_arrows(images)
	await _modulated(spec, names, textures, images, tints)
	await _sabotage(images, tints)


## `_tints` against its sources: the palette step each names, and for the
## chrome ink the text face's own page. A table that drifted from the
## palette would tint every symbol a colour nobody chose.
func _tint_table(tints: Dictionary, palette: Dictionary) -> void:
	for name in tints:
		var entry: Dictionary = tints[name]
		var want := Color(str(entry["hex"]))
		if name == CHROME_INK:
			var page := Image.new()
			if page.load(TEXT_PAGE) != OK:
				_bad("could not read the text face's page to confirm the "
					 + "chrome ink")
				continue
			page.convert(Image.FORMAT_RGBA8)
			var ink := _ink_of(page)
			if not ink.is_equal_approx(want):
				_bad("_tints says chrome ink is #%s; the text face inks in #%s"
					 % [want.to_html(false), ink.to_html(false)])
			continue
		var ramp: Array = palette["universal"][str(entry["family"])]["ramp"]
		var source := Color(str(ramp[int(entry["step"])]))
		if not source.is_equal_approx(want):
			_bad("_tints says %s is #%s; the palette's %s[%d] is #%s"
				 % [name, want.to_html(false), entry["family"],
					int(entry["step"]), source.to_html(false)])
	_notes["tints"] = tints


## The single ink colour of an image (its first opaque pixel; the shape
## check has already refused two).
func _ink_of(image: Image) -> Color:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				return c
	return Color(0, 0, 0, 0)


## Every symbol, in every tint its states name, drawn the ordinary way --
## a TextureRect with `modulate` -- and read back. The ink must come out
## as the tint itself, to the 8-bit step.
func _modulated(spec: Dictionary, names: Array, textures: Dictionary,
		images: Dictionary, tints: Dictionary) -> void:
	var pairs: Array = []
	for name in names:
		if not textures.has(name):
			continue
		var used := {}
		for state in spec[name]["tint_by_state"]:
			used[spec[name]["tint_by_state"][state]] = true
		for tint in used:
			if tints.has(tint):
				pairs.append([name, tint, str(tints[tint]["hex"])])
	var got := await _render(pairs, textures)
	var exact := 0
	for i in pairs.size():
		var name: String = pairs[i][0]
		var want := Color(str(tints[pairs[i][1]]["hex"]))
		var bad := _tint_faults(got, i, images[name], want)
		if bad != "":
			_bad("%s modulated by %s: %s" % [name, pairs[i][1], bad])
		else:
			exact += 1
	_notes["modulate_exact"] = "%d of %d" % [exact, pairs.size()]
	print("[icons] modulate: %d of %d symbol/tint pairs render the palette "
		  % [exact, pairs.size()] + "colour exactly")


func _render(pairs: Array, textures: Dictionary) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(12 * maxi(1, pairs.size()), 12)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for i in pairs.size():
		var rect := TextureRect.new()
		rect.texture = textures[pairs[i][0]] if pairs[i][0] is String \
				else pairs[i][0]
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.modulate = Color(str(pairs[i][2]))
		rect.position = Vector2(12 * i, 0)
		view.add_child(rect)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	view.queue_free()
	await process_frame
	image.convert(Image.FORMAT_RGBA8)
	return image


## Every ink pixel of cell `i` must be `want` to the 8-bit step, and the
## rest must stay transparent.
func _tint_faults(got: Image, i: int, src: Image, want: Color) -> String:
	for y in 12:
		for x in 12:
			var c := got.get_pixel(12 * i + x, y)
			if src.get_pixel(x, y).a == 0.0:
				if c.a != 0.0:
					return "(%d,%d) should be clear and is #%s" \
							% [x, y, c.to_html(true)]
				continue
			for ch in 3:
				if absi(roundi(c[ch] * 255.0) - roundi(want[ch] * 255.0)) > 1:
					return "(%d,%d) renders #%s, the palette says #%s" \
							% [x, y, c.to_html(false), want.to_html(false)]
	return ""


## One ink colour, nothing on the outer ring, and some ink at all.
func _shape_faults(image: Image) -> String:
	var ink := {}
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				return "ink on the outer ring at (%d,%d)" % [x, y]
			ink[c.to_html(true)] = true
	if ink.is_empty():
		return "no ink"
	if ink.size() > 1:
		return "%d ink colours %s" % [ink.size(), ink.keys()]
	return ""


func _same(a: Image, b: Image) -> int:
	var differ := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				differ += 1
	return differ


func _arrows(images: Dictionary) -> void:
	for need in ["arrow_right", "arrow_left", "arrow_up", "arrow_down"]:
		if not images.has(need):
			_bad("no %s to check the arrows against" % need)
			return
	var right: Image = images["arrow_right"]
	var left := right.duplicate() as Image
	left.flip_x()
	var up := right.duplicate() as Image
	up.rotate_90(COUNTERCLOCKWISE)
	var down := up.duplicate() as Image
	down.flip_y()
	var result := {}
	for pair in [["arrow_left", left, "right mirrored"],
			["arrow_up", up, "right turned anticlockwise"],
			["arrow_down", down, "up flipped"]]:
		var n := _same(images[pair[0]], pair[1])
		result[pair[0]] = n
		if n > 0:
			_bad("%s is not %s: %d pixel(s) differ"
				 % [pair[0], pair[2], n])
	_notes["arrows_agree"] = result
	print("[icons] arrows: left/up/down are right mirrored/turned/flipped "
		  + "to the pixel" if result.values().max() == 0
		  else "[icons] arrows DISAGREE %s" % result)


func _sabotage(images: Dictionary, tints: Dictionary) -> void:
	## The shape check must be able to fail. Two doctored copies of a
	## real symbol: one with ink moved onto the outer ring, one with a
	## second ink colour. Both must be refused.
	if not images.has("circuit"):
		_bad("no circuit symbol to sabotage")
		return
	## And the white-ink rule and the modulate check: the same symbol in
	## the text face's off-white, which is what these first inked in. It
	## must fail the ink rule, and its signal tint must NOT come out as
	## the palette's signal -- or the render check is not reading ink.
	var off := (images["control"] as Image).duplicate() as Image
	for y in off.get_height():
		for x in off.get_width():
			if off.get_pixel(x, y).a > 0.0:
				off.set_pixel(x, y, Color8(232, 238, 246))
	var off_tex := ImageTexture.create_from_image(off)
	var sig_colour := Color(str(tints["signal"]["hex"]))
	var got := await _render([[off_tex, "signal", str(tints["signal"]["hex"])]],
			{})
	var render_caught := _tint_faults(got, 0, off, sig_colour) != ""
	var ink_caught := _ink_of(off) != WHITE
	var edge := (images["circuit"] as Image).duplicate() as Image
	edge.set_pixel(0, 5, Color(0.91, 0.93, 0.96, 1.0))
	var two := (images["circuit"] as Image).duplicate() as Image
	for y in two.get_height():
		for x in two.get_width():
			if two.get_pixel(x, y).a > 0.0:
				two.set_pixel(x, y, Color(1, 0, 0, 1))
				break
	var caught := {"edge": _shape_faults(edge) != "",
		"two_inks": _shape_faults(two) != "",
		"off_white_ink": ink_caught, "off_white_render": render_caught}
	_notes["sabotage_detected"] = caught
	for k in caught:
		if not caught[k]:
			_bad("sabotage NOT detected: a symbol with %s passed the "
				 % k + "shape check")
	print("[icons] sabotage: edge ink -> %s; two inks -> %s; off-white ink "
		  % [_shape_faults(edge), _shape_faults(two)]
		  + "-> ink rule %s, signal render %s"
		  % ["refused" if ink_caught else "PASSED",
			 _tint_faults(got, 0, off, sig_colour)])


func _finish() -> void:
	_notes["engine"] = Engine.get_version_info()["string"]
	_notes["faults"] = _faults
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var fh := FileAccess.open(args[0], FileAccess.WRITE)
		fh.store_string(JSON.stringify(_notes, "\t", true, true))
		fh.close()
	if _faults.is_empty():
		print("[icons] PASS -- the symbols import as drawn in Godot %s"
			  % _notes["engine"])
	else:
		push_error("[icons] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
