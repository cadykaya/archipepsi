extends SceneTree
## Track A -- does a Glyph-authored nine-slice survive Godot 4.5.1?
##
## The font half of this risk is answered by `font_import.gd`. This is
## the other half, and it is the one the whole interface rests on: a
## panel, a grid cell, a frame and a selection treatment are all one
## rectangle with a border that must NOT distort when the rectangle
## changes size.
##
## What a nine-slice promises is narrow and easy to check: the corners
## are drawn at their authored size whatever the panel's size, the edges
## stretch along one axis only, and the centre takes the rest. So the
## test is to draw one at four times its authored width and read the
## pixels back.

## The committed contract: sizes, insets and the colour of every ring.
## Read rather than restated, because a harness carrying its own copy of
## the numbers tests the copy. It also gives this file something to
## compare the ART against -- without it, every check here compares the
## render to the same imported image and would pass a panel whose pixels
## had been changed to anything at all, as a sabotage run proved.
const CONTRACT := "res://_harness/panels.json"

var _names: Array = []
var _spec := {}
var MARGIN := 0
var SRC := Vector2i.ZERO
## Deliberately not a multiple of the source, and not square: a bug that
## happens to work at an exact 2x or on a square would survive a nicer
## number.
const DRAW := Vector2i(40, 24)

var _faults: Array[String] = []
var _notes := {}


func _bad(what: String) -> void:
	_faults.append(what)
	print("[nineslice] FAULT: %s" % what)


func _init() -> void:
	var text := FileAccess.get_file_as_string(CONTRACT)
	if text == "":
		_bad("no contract at %s -- the runner must stage panels.json"
			 % CONTRACT)
		_finish()
		return
	_spec = JSON.parse_string(text)
	if typeof(_spec) != TYPE_DICTIONARY or _spec.is_empty():
		_bad("%s did not parse as a panel contract" % CONTRACT)
		_finish()
		return
	_names = _spec.keys()
	_names.sort()
	await _run()


func _render(texture: Texture2D, margin: int) -> Image:
	var view := SubViewport.new()
	view.size = DRAW
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var patch := NinePatchRect.new()
	patch.texture = texture
	# Pixel art. Nothing here is magnified with interpolation -- and the
	# flat centre would survive it anyway, which is exactly why the
	# filter is set explicitly rather than inferred from a passing test.
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.patch_margin_left = margin
	patch.patch_margin_top = margin
	patch.patch_margin_right = margin
	patch.patch_margin_bottom = margin
	patch.position = Vector2.ZERO
	patch.size = DRAW
	view.add_child(patch)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	view.queue_free()
	return image


## The four corners, at their authored size, in the four corners of the
## rendered rectangle. Returns "" when they all match.
func _corner_faults(got: Image, want: Image) -> String:
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
			Vector2i(1, 1)]:
		for dy in MARGIN:
			for dx in MARGIN:
				var sx: int = dx if corner.x == 0 else SRC.x - MARGIN + dx
				var sy: int = dy if corner.y == 0 else SRC.y - MARGIN + dy
				var gx: int = dx if corner.x == 0 else DRAW.x - MARGIN + dx
				var gy: int = dy if corner.y == 0 else DRAW.y - MARGIN + dy
				var a := want.get_pixel(sx, sy)
				var b := got.get_pixel(gx, gy)
				if not a.is_equal_approx(b):
					return ("corner %s: rendered (%d,%d) is %s, authored "
						% [corner, gx, gy, b] + "(%d,%d) is %s"
						% [sx, sy, a])
	return ""


func _run() -> void:
	for name in _names:
		var declared: Dictionary = _spec[name]
		var insets: Dictionary = declared["insets"]
		# NinePatchRect takes four margins and this art declares one
		# border width. A panel with unequal insets is legal and would
		# need a different call, so it is refused here rather than
		# silently tested with the left one on all four sides.
		MARGIN = int(insets["left"])
		for edge in ["top", "right", "bottom"]:
			if int(insets[edge]) != MARGIN:
				_bad("%s declares unequal insets %s; this harness draws "
					 % [name, insets] + "one margin on all four sides")
				continue
		SRC = Vector2i(int(declared["size"][0]), int(declared["size"][1]))
		var path := "res://_harness/panel_%s.png" % name
		var texture: Variant = load(path)
		if texture == null or not (texture is Texture2D):
			_bad("%s: load(%s) gave %s, not a Texture2D"
				 % [name, path, texture])
			continue
		var authored: Image = texture.get_image()
		if authored.get_size() != SRC:
			_bad("%s: imported at %s, the contract declares %s"
				 % [name, authored.get_size(), SRC])
			continue

		# The art is the chrome the contract says it is. This is the one
		# check here that does not compare the panel to itself: a ring
		# painted some other colour fails, however well it stretches.
		var colours: Dictionary = declared["colours"]
		for role in [["outline", Vector2i(0, 0)],
				["light", Vector2i(1, 1)],
				["dark", Vector2i(SRC.x - 2, SRC.y - 2)],
				["face", Vector2i(SRC.x / 2, SRC.y / 2)]]:
			var at: Vector2i = role[1]
			var want := Color(colours[role[0]])
			var have := authored.get_pixel(at.x, at.y)
			if not have.is_equal_approx(want):
				_bad("%s: the %s ring at %s is #%s, and the contract "
					 % [name, role[0], at, have.to_html(false)]
					 + "declares %s" % colours[role[0]])

		# The import must not repaint the art. A UI texture that came
		# back lossy would still look right at a glance and would be
		# wrong in every corner, forever.
		var on_disk := Image.new()
		if on_disk.load(path) != OK:
			_bad("%s: could not read the source png back" % name)
		else:
			var moved := 0
			for y in SRC.y:
				for x in SRC.x:
					if not on_disk.get_pixel(x, y).is_equal_approx(
							authored.get_pixel(x, y)):
						moved += 1
			if moved > 0:
				_bad("%s: the importer changed %d of %d pixels -- this "
					 % [name, moved, SRC.x * SRC.y]
					 + "texture is not arriving lossless")

		var got: Image = await _render(texture, MARGIN)
		var bad := _corner_faults(got, authored)
		if bad != "":
			_bad("%s stretched its corners. %s" % [name, bad])

		# The edges stretch along one axis only. Each authored edge band
		# is uniform along the stretched axis, so every pixel of the
		# rendered band must equal the authored band's first column/row:
		# anything else is the edge being resampled.
		for x in range(MARGIN, DRAW.x - MARGIN):
			for y in MARGIN:
				if not got.get_pixel(x, y).is_equal_approx(
						authored.get_pixel(MARGIN, y)):
					_bad("%s: top edge pixel (%d,%d) is %s, the authored "
						 % [name, x, y, got.get_pixel(x, y)]
						 + "band is %s" % authored.get_pixel(MARGIN, y))
					break
		for y in range(MARGIN, DRAW.y - MARGIN):
			for x in MARGIN:
				if not got.get_pixel(x, y).is_equal_approx(
						authored.get_pixel(x, MARGIN)):
					_bad("%s: left edge pixel (%d,%d) is %s, the authored "
						 % [name, x, y, got.get_pixel(x, y)]
						 + "band is %s" % authored.get_pixel(x, MARGIN))
					break

		# And the centre is the face colour, all of it.
		var face := authored.get_pixel(SRC.x / 2, SRC.y / 2)
		var strays := 0
		for y in range(MARGIN, DRAW.y - MARGIN):
			for x in range(MARGIN, DRAW.x - MARGIN):
				if not got.get_pixel(x, y).is_equal_approx(face):
					strays += 1
		if strays > 0:
			_bad("%s: %d pixel(s) in the stretched centre are not the "
				 % [name, strays] + "face colour %s" % face)

		# The frame is unbroken: at this size the outline is the first
		# and last row and column of the whole rectangle.
		var outline := authored.get_pixel(0, 0)
		var broken := 0
		for x in DRAW.x:
			if not got.get_pixel(x, 0).is_equal_approx(outline):
				broken += 1
			if not got.get_pixel(x, DRAW.y - 1).is_equal_approx(outline):
				broken += 1
		for y in DRAW.y:
			if not got.get_pixel(0, y).is_equal_approx(outline):
				broken += 1
			if not got.get_pixel(DRAW.x - 1, y).is_equal_approx(outline):
				broken += 1
		if broken > 0:
			_bad("%s: the outline is broken in %d place(s) around a %s "
				 % [name, broken, DRAW] + "panel")
		_notes[name] = {"drawn": [DRAW.x, DRAW.y], "corners": "exact",
			"outline": "unbroken", "centre_face": face.to_html(false)}
		print("[nineslice] %s: %dx%d authored, drawn %dx%d -- corners "
			  % [name, SRC.x, SRC.y, DRAW.x, DRAW.y]
			  + "exact, edges one-axis, centre flat, outline unbroken")

	await _sabotage()
	_finish()


func _sabotage() -> void:
	## Every check above would also pass if NinePatchRect quietly ignored
	## the margins and the panel happened to look right -- most of this
	## art is flat colour, and flat colour survives being stretched. So:
	## the same texture drawn with the margins set to ZERO, which makes
	## the whole texture one stretchable centre. The corner check MUST
	## now fail. If it does not, it is not looking at the corners.
	var texture: Variant = load("res://_harness/panel_panel.png")
	if texture == null:
		_bad("the sabotage pass could not load a texture")
		return
	var got: Image = await _render(texture, 0)
	var bad := _corner_faults(got, texture.get_image())
	if bad == "":
		_bad("sabotage NOT detected: with every patch margin set to 0 the "
			 + "corners still matched the authored art, so this harness "
			 + "is not measuring nine-slice behaviour and its passes "
			 + "prove nothing")
		_notes["sabotage_detected"] = false
		return
	print("[nineslice] sabotage: margins 0 -> %s" % bad)
	_notes["sabotage_detected"] = true


func _finish() -> void:
	_notes["engine"] = Engine.get_version_info()["string"]
	_notes["faults"] = _faults
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var fh := FileAccess.open(args[0], FileAccess.WRITE)
		fh.store_string(JSON.stringify(_notes, "\t", true, true))
		fh.close()
	if _faults.is_empty():
		print("[nineslice] PASS -- three panels nine-slice correctly in "
			  + "Godot %s" % _notes["engine"])
	else:
		push_error("[nineslice] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
