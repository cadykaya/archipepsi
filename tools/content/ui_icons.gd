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
##   * every tint the contract names is a palette family that exists, or
##     the chrome ink.
##
## Then it proves the margin and ink checks can fail, on doctored copies.

const CONTRACT := "res://_harness/icons.json"
const PALETTE := "res://_harness/art_palette.json"
const CHROME_INK := "chrome ink"

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
	var families: Array = palette["universal"].keys()
	var images := {}
	var names: Array = spec.keys()
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
		for state in entry["tint_by_state"]:
			var tint: String = entry["tint_by_state"][state]
			if tint != CHROME_INK and not families.has(tint):
				_bad("%s: tint '%s' for state '%s' is not a palette family"
					 % [name, tint, state])
		images[name] = image
		_notes[name] = {"size": [want.x, want.y], "lossless": moved == 0,
			"shape": "ok" if shape == "" else shape}
		print("[icons] %s: %dx%d, lossless, %s" % [name, want.x, want.y,
			  "one ink, 1 px margin" if shape == "" else shape])

	_arrows(images)
	_sabotage(images)
	_finish()


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


func _sabotage(images: Dictionary) -> void:
	## The shape check must be able to fail. Two doctored copies of a
	## real symbol: one with ink moved onto the outer ring, one with a
	## second ink colour. Both must be refused.
	if not images.has("circuit"):
		_bad("no circuit symbol to sabotage")
		return
	var edge := (images["circuit"] as Image).duplicate() as Image
	edge.set_pixel(0, 5, Color(0.91, 0.93, 0.96, 1.0))
	var two := (images["circuit"] as Image).duplicate() as Image
	for y in two.get_height():
		for x in two.get_width():
			if two.get_pixel(x, y).a > 0.0:
				two.set_pixel(x, y, Color(1, 0, 0, 1))
				break
	var caught := {"edge": _shape_faults(edge) != "",
		"two_inks": _shape_faults(two) != ""}
	_notes["sabotage_detected"] = caught
	for k in caught:
		if not caught[k]:
			_bad("sabotage NOT detected: a symbol with %s passed the "
				 % k + "shape check")
	print("[icons] sabotage: edge ink -> %s; two inks -> %s"
		  % [_shape_faults(edge), _shape_faults(two)])


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
