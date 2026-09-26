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
## left, top, right, bottom -- the treatment under test's patch margins.
var M := {"left": 0, "top": 0, "right": 0, "bottom": 0}
var SRC := Vector2i.ZERO

## WHERE each ring role is, per treatment -- this file's own knowledge of
## the geometry, NOT read from the contract. The contract says what
## colour a role is; if it also said where to look, a treatment drawn in
## the wrong place with a contract written from the same mistake would
## grade itself. Positions are from the top-left; a negative coordinate
## counts from the far edge (-1 is the last pixel). `clear` is a pixel
## that must be fully transparent: the keycap's cut corners.
const BEVEL := {"outline": [[0, 0], [-1, -1]], "light": [[1, 1]],
	"dark": [[-2, -2]], "face": [["mid", "mid"]]}
const GEOMETRY := {
	"panel": BEVEL, "well": BEVEL, "selected": BEVEL,
	"keycap": {"outline": [[1, 0], [0, 1], [-2, -1], [-1, -2]],
		"light": [[1, 1], [1, -4], [-2, 1]], "face": [["mid", "mid"]],
		"lip": [["mid", -2], ["mid", -3]],
		"clear": [[0, 0], [-1, 0], [0, -1], [-1, -1]]},
}
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


func _render(texture: Texture2D, margins: Dictionary) -> Image:
	var view := SubViewport.new()
	view.size = DRAW
	# Transparent, so a keycap's cut corners come back as the holes they
	# are rather than as whatever colour the viewport clears to.
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var patch := NinePatchRect.new()
	patch.texture = texture
	# Pixel art. Nothing here is magnified with interpolation -- and the
	# flat centre would survive it anyway, which is exactly why the
	# filter is set explicitly rather than inferred from a passing test.
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.patch_margin_left = int(margins["left"])
	patch.patch_margin_top = int(margins["top"])
	patch.patch_margin_right = int(margins["right"])
	patch.patch_margin_bottom = int(margins["bottom"])
	patch.position = Vector2.ZERO
	patch.size = DRAW
	view.add_child(patch)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	view.queue_free()
	return image


## Two pixels are the same if they are the same colour -- or both fully
## transparent, whatever RGB sits under the zero alpha. That RGB is not
## art: Godot's importer rewrites it on purpose ("fix alpha border") so
## filtering never bleeds a black fringe, and nothing draws it.
func _same_px(a: Color, b: Color) -> bool:
	return (a.a == 0.0 and b.a == 0.0) or a.is_equal_approx(b)


## The four corners, at their authored size, in the four corners of the
## rendered rectangle. Returns "" when they all match. Each corner is as
## wide as its side's margin and as tall as its end's, so a keycap's
## deep bottom lip is checked as the 3-row corner it is.
func _corner_faults(got: Image, want: Image) -> String:
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
			Vector2i(1, 1)]:
		var cw: int = M["left"] if corner.x == 0 else M["right"]
		var ch: int = M["top"] if corner.y == 0 else M["bottom"]
		for dy in ch:
			for dx in cw:
				var sx: int = dx if corner.x == 0 else SRC.x - cw + dx
				var sy: int = dy if corner.y == 0 else SRC.y - ch + dy
				var gx: int = dx if corner.x == 0 else DRAW.x - cw + dx
				var gy: int = dy if corner.y == 0 else DRAW.y - ch + dy
				var a := want.get_pixel(sx, sy)
				var b := got.get_pixel(gx, gy)
				if not _same_px(a, b):
					return ("corner %s: rendered (%d,%d) is %s, authored "
						% [corner, gx, gy, b] + "(%d,%d) is %s"
						% [sx, sy, a])
	return ""


func _run() -> void:
	for name in _names:
		var faults_before := _faults.size()
		var declared: Dictionary = _spec[name]
		var insets: Dictionary = declared["insets"]
		# NinePatchRect takes four margins, and a keycap's are unequal
		# (its front lip is deeper than its top edge), so all four are
		# carried through rather than one border width assumed.
		for edge in ["left", "top", "right", "bottom"]:
			M[edge] = int(insets[edge])
		if not GEOMETRY.has(name):
			_bad("%s: this harness does not know where %s's rings are, "
				 % [name, name] + "so it cannot check them -- add it to "
				 + "GEOMETRY rather than skipping it")
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
		var where: Dictionary = GEOMETRY[name]
		for role in where:
			for p in where[role]:
				var at := _at(p)
				var have := authored.get_pixel(at.x, at.y)
				if role == "clear":
					if have.a != 0.0:
						_bad("%s: %s must be transparent (a cut corner) "
							 % [name, at] + "and is #%s"
							 % have.to_html(true))
					continue
				if not colours.has(role):
					_bad("%s: the contract has no %s colour" % [name, role])
					continue
				var want := Color(colours[role])
				if not have.is_equal_approx(want):
					_bad("%s: the %s ring at %s is #%s, and the contract "
						 % [name, role, at, have.to_html(false)]
						 + "declares %s" % colours[role])

		# The import must not repaint the art. A UI texture that came
		# back lossy would still look right at a glance and would be
		# wrong in every corner, forever.
		var on_disk := Image.new()
		if on_disk.load(path) != OK:
			_bad("%s: could not read the source png back" % name)
		else:
			var moved := 0
			var under_alpha := 0
			for y in SRC.y:
				for x in SRC.x:
					var a := on_disk.get_pixel(x, y)
					var b := authored.get_pixel(x, y)
					if not _same_px(a, b):
						moved += 1
					elif not a.is_equal_approx(b):
						under_alpha += 1
			if moved > 0:
				_bad("%s: the importer changed %d of %d pixels -- this "
					 % [name, moved, SRC.x * SRC.y]
					 + "texture is not arriving lossless")
			if under_alpha > 0:
				print("[nineslice] %s: the importer rewrote the RGB under "
					  % name + "%d fully transparent pixel(s) (fix alpha "
					  % under_alpha + "border) -- invisible, recorded")
				_notes["%s_rgb_under_alpha_rewritten" % name] = under_alpha

		var got: Image = await _render(texture, M)
		var bad := _corner_faults(got, authored)
		if bad != "":
			_bad("%s stretched its corners. %s" % [name, bad])

		# The edges stretch along one axis only. Each authored edge band
		# is uniform along the stretched axis, so every pixel of the
		# rendered band must equal the authored band's first column/row:
		# anything else is the edge being resampled.
		# All four bands: the far ones matter as much, and on a keycap
		# the bottom band is the lip.
		for x in range(M["left"], DRAW.x - M["right"]):
			for y in M["top"]:
				if not got.get_pixel(x, y).is_equal_approx(
						authored.get_pixel(M["left"], y)):
					_bad("%s: top edge pixel (%d,%d) is %s, the authored "
						 % [name, x, y, got.get_pixel(x, y)]
						 + "band is %s" % authored.get_pixel(M["left"], y))
					break
			for dy in M["bottom"]:
				var gy: int = DRAW.y - M["bottom"] + dy
				var sy: int = SRC.y - M["bottom"] + dy
				if not got.get_pixel(x, gy).is_equal_approx(
						authored.get_pixel(M["left"], sy)):
					_bad("%s: bottom edge pixel (%d,%d) is %s, the "
						 % [name, x, gy, got.get_pixel(x, gy)]
						 + "authored band is %s"
						 % authored.get_pixel(M["left"], sy))
					break
		for y in range(M["top"], DRAW.y - M["bottom"]):
			for x in M["left"]:
				if not got.get_pixel(x, y).is_equal_approx(
						authored.get_pixel(x, M["top"])):
					_bad("%s: left edge pixel (%d,%d) is %s, the authored "
						 % [name, x, y, got.get_pixel(x, y)]
						 + "band is %s" % authored.get_pixel(x, M["top"]))
					break
			for dx in M["right"]:
				var gx: int = DRAW.x - M["right"] + dx
				var sx: int = SRC.x - M["right"] + dx
				if not got.get_pixel(gx, y).is_equal_approx(
						authored.get_pixel(sx, M["top"])):
					_bad("%s: right edge pixel (%d,%d) is %s, the "
						 % [name, gx, y, got.get_pixel(gx, y)]
						 + "authored band is %s"
						 % authored.get_pixel(sx, M["top"]))
					break

		# And the centre is the face colour, all of it.
		var face := authored.get_pixel(SRC.x / 2, SRC.y / 2)
		var strays := 0
		for y in range(M["top"], DRAW.y - M["bottom"]):
			for x in range(M["left"], DRAW.x - M["right"]):
				if not got.get_pixel(x, y).is_equal_approx(face):
					strays += 1
		if strays > 0:
			_bad("%s: %d pixel(s) in the stretched centre are not the "
				 % [name, strays] + "face colour %s" % face)

		# The frame is unbroken: along every stretched span the outline
		# is the first and last row and column of the whole rectangle.
		# (The corners were checked pixel for pixel above -- which is
		# what lets a keycap's cut corners be transparent here.)
		var outline := Color(colours["outline"])
		var broken := 0
		for x in range(M["left"], DRAW.x - M["right"]):
			if not got.get_pixel(x, 0).is_equal_approx(outline):
				broken += 1
			if not got.get_pixel(x, DRAW.y - 1).is_equal_approx(outline):
				broken += 1
		for y in range(M["top"], DRAW.y - M["bottom"]):
			if not got.get_pixel(0, y).is_equal_approx(outline):
				broken += 1
			if not got.get_pixel(DRAW.x - 1, y).is_equal_approx(outline):
				broken += 1
		if broken > 0:
			_bad("%s: the outline is broken in %d place(s) around a %s "
				 % [name, broken, DRAW] + "panel")
		if _faults.size() > faults_before:
			print("[nineslice] %s: %d fault(s) above"
				  % [name, _faults.size() - faults_before])
			continue
		_notes[name] = {"drawn": [DRAW.x, DRAW.y], "corners": "exact",
			"outline": "unbroken", "centre_face": face.to_html(false),
			"margins": M.duplicate()}
		print("[nineslice] %s: %dx%d authored, drawn %dx%d, margins "
			  % [name, SRC.x, SRC.y, DRAW.x, DRAW.y]
			  + "%s -- corners exact, edges one-axis, centre flat, "
			  % [[M["left"], M["top"], M["right"], M["bottom"]]]
			  + "outline unbroken")

	await _sabotage()
	if _spec.has("keycap"):
		await _sabotage_unequal()
	_finish()


## A GEOMETRY coordinate to a pixel: negatives count from the far edge,
## "mid" is the centre.
func _at(p: Array) -> Vector2i:
	var out := Vector2i.ZERO
	for axis in 2:
		var size: int = SRC.x if axis == 0 else SRC.y
		var v: Variant = p[axis]
		var n: int = size / 2 if typeof(v) == TYPE_STRING \
				else (int(v) if int(v) >= 0 else size + int(v))
		if axis == 0:
			out.x = n
		else:
			out.y = n
	return out


func _sabotage_unequal() -> void:
	## The keycap is the first treatment whose four margins differ. A
	## harness that quietly drew it with one margin all round would still
	## pass most of the checks above, so: the keycap drawn with its
	## BOTTOM margin set to its top one. The lip's third row is then
	## stretched as edge, and the bottom corners MUST come out wrong.
	var texture: Variant = load("res://_harness/panel_keycap.png")
	if texture == null:
		_bad("the unequal-margin sabotage could not load the keycap")
		return
	var declared: Dictionary = _spec["keycap"]["insets"]
	var wrong := declared.duplicate()
	wrong["bottom"] = declared["top"]
	SRC = Vector2i(int(_spec["keycap"]["size"][0]),
			int(_spec["keycap"]["size"][1]))
	var got: Image = await _render(texture, wrong)
	for edge in declared:
		M[edge] = int(declared[edge])
	# Nearest-neighbour stretching can hand the corner check back the
	# very lip row it expects, so the centre is read too: with the lip
	# treated as stretchable, lip-coloured rows land inside what the
	# DECLARED margins say is flat face.
	var authored: Image = texture.get_image()
	var bad := _corner_faults(got, authored)
	if bad == "":
		var face := authored.get_pixel(SRC.x / 2, SRC.y / 2)
		for y in range(M["top"], DRAW.y - M["bottom"]):
			for x in range(M["left"], DRAW.x - M["right"]):
				if bad == "" and not got.get_pixel(x, y).is_equal_approx(face):
					bad = "centre pixel (%d,%d) is %s, not the face %s" \
							% [x, y, got.get_pixel(x, y), face]
	if bad == "":
		_bad("unequal-margin sabotage NOT detected: the keycap drawn with "
			 + "its bottom margin equal to its top still matched, so the "
			 + "corner check cannot see a lip")
		_notes["unequal_sabotage_detected"] = false
		return
	print("[nineslice] sabotage: keycap bottom margin %d -> %s"
		  % [wrong["bottom"], bad])
	_notes["unequal_sabotage_detected"] = true


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
	var declared: Dictionary = _spec["panel"]["insets"]
	SRC = Vector2i(int(_spec["panel"]["size"][0]),
			int(_spec["panel"]["size"][1]))
	for edge in declared:
		M[edge] = int(declared[edge])
	var got: Image = await _render(texture, {"left": 0, "top": 0,
			"right": 0, "bottom": 0})
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
		print("[nineslice] PASS -- %d treatments nine-slice correctly in "
			  % _names.size() + "Godot %s" % _notes["engine"])
	else:
		push_error("[nineslice] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
