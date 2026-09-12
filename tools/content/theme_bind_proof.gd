extends SceneTree
## PROVE THAT A REAL EXPORTED THEME BINDS AUTHORED PIXELS.
##
##   godot --path godot -s _harness/bindproof.gd -- <content-dir> <out.json>
##
## ## Why the validators were not enough
##
## `verify_theme_set.py` proves the set is complete and self-describing.
## `verify_theme_export.py` proves the exported copy is byte-identical and
## its digests match its own pixels. NEITHER TOUCHES A MATERIAL. Between the
## last byte on disk and a wall in a room there is an importer, a resource
## loader, a sampler and a UV scale, and every one of them can turn a
## correct file into a room with no texture on it -- silently, because the
## shipped `ThemeMaterials` builds procedural materials and a Zone renders
## perfectly well having bound nothing at all. "The Zone still builds" is
## not evidence; it is the symptom being invisible.
##
## So this runs the reference binder over the REAL exported pack and asks
## the material itself what it is carrying.
##
## ## The claim, and how each part is checked
##
## 1. Every theme binds, and every role the contract requires authored
##    pixels for reports `authored = true`.
## 2. The bound material's `albedo_texture` is NOT the procedural texture
##    the engine would otherwise have used. (`ProcTextures` is asked for
##    the same role and the two are compared -- if a binder silently fell
##    through, this is what catches it.)
## 3. THE PIXELS SURVIVED THE IMPORT. The texture the material carries is
##    read back and compared, pixel for pixel, against the authored PNG
##    decoded straight from its file bytes. A lossy import, a wrong
##    sidecar, a stale `.godot/imported` entry -- all of them land here.
##    This is the part no Python validator can reach.
## 4. The sampler state the binder owns is on the material: NEAREST filter,
##    repeat enabled, and `uv1_scale` matching the pack's declared
##    `texels_per_metre` and the texture's own size.
##
## ## The controls
##
## A check that has only ever seen the good case has not been tested; it has
## been agreed with. Two files are moved aside by the runner and the same
## binder is asked again:
##
## * **A REQUIRED role gone** (`concrete_facility/floor`). The documented
##   behaviour is `disqualifies_theme_if_missing: true`, so the demand is:
##   that theme binds NOTHING, says why, its roles come back as the
##   engine's own procedural materials, and THE OTHER FIVE THEMES ARE
##   UNAFFECTED. A binder that bound five roles out of six, or borrowed
##   another theme's floor, fails here.
## * **A file that is THERE and is the wrong pixels**
##   (`concrete_facility/wall`, replaced with another theme's wall). It
##   exists, it decodes, it loads -- and clause 4 says a texture whose
##   digest does not match its row is not bound. The demand is that the
##   digest catches it and the theme is disqualified for a required role,
##   not that a room quietly comes out in the wrong theme's stone.
## * **An OPTIONAL role gone** (`concrete_facility/ceiling`). The documented
##   behaviour is `optional_role_fallbacks: {"ceiling": "wall"}`, so the
##   demand is the opposite: the theme still binds, `ceiling` reports the
##   fallback, and the texture it ends up carrying is the WALL texture --
##   checked by pixels, not by trusting the label.

var _content: String
var _out: String
var _mode: String
var _binder: GDScript
var _problems: Array[String] = []
var _log := {}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		_fail("usage: -- <content-dir> <out.json> <mode>")
	else:
		_content = a[0]
		_out = a[1]
		_mode = a[2]
	_binder = load("res://_harness/themebinder.gd") as GDScript
	if _binder == null:
		_fail("the binder script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[bind] FAIL: %s" % what)


## The authored PNG, decoded from its own bytes -- never through the
## importer, because the importer is the thing under test.
func _from_bytes(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return image


## Byte for byte, after normalising the format -- not `get_pixel` in a
## double loop, which is 2.9 million script calls per mode and answers a
## weaker question anyway (`is_equal_approx` would forgive a channel that
## drifted by a bit, which is exactly what a lossy import does).
## MIPMAPS ARE WHY THIS IS NOT A ONE-LINE COMPARE. The sidecars ask for
## `mipmaps/generate=true`, so the imported image carries its whole chain
## and `get_data()` comes back about a third longer than the authored PNG's
## -- same width, same height, different bytes, and the first version of
## this check reported all 37 textures as corrupted by the import. Clearing
## the chain compares the base level, which is the authored pixels.
func _same_pixels(a: Image, b: Image) -> Dictionary:
	if a == null or b == null:
		return {"same": false, "why": "one of the images did not decode"}
	var left := a.duplicate() as Image
	var right := b.duplicate() as Image
	left.clear_mipmaps()
	right.clear_mipmaps()
	left.convert(Image.FORMAT_RGBA8)
	right.convert(Image.FORMAT_RGBA8)
	if left.get_width() != right.get_width() \
			or left.get_height() != right.get_height():
		return {"same": false,
				"why": "authored %dx%d, bound %dx%d"
						% [left.get_width(), left.get_height(),
								right.get_width(), right.get_height()]}
	if left.get_data() == right.get_data():
		return {"same": true, "why": ""}
	var differing := 0
	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y):
				differing += 1
	return {"same": false,
			"why": "%d of %d pixels differ"
					% [differing, left.get_width() * left.get_height()]}


func _check_theme(pack: Dictionary, theme: String) -> Dictionary:
	var result: Dictionary = _binder.call("bind", pack, _content, theme)
	var contract: Dictionary = pack.get("role_contract", {})
	var texels := float(pack.get("texels_per_metre", 32))
	var rows: Dictionary = pack.get("textures", {})
	var note := {"disqualified": result["disqualified"],
			"why": result["why"], "fell_back": result["fell_back"],
			"authored": {}, "pixels_match": {}, "uv1_scale": {}}

	for role: String in contract:
		var rule: Dictionary = contract[role]
		var authored := bool(result["authored"].get(role, false))
		note["authored"][role] = authored
		var material: StandardMaterial3D = result["bound"][role]

		if str(rule.get("pack_pixels", "")) == "never":
			# Claim 1, the other way round: a role the pack must not paint
			# has to come back UNAUTHORED, whatever is lying in the folder.
			if authored:
				_fail("%s/%s is bound from pack pixels, and the contract "
						% [theme, role]
						+ "says the pack never paints it")
			continue

		if not authored:
			continue

		# Claim 2: not the procedural texture.
		var procedural: StandardMaterial3D = _binder.call(
				"_accessor", theme, role)
		if material.albedo_texture == procedural.albedo_texture:
			_fail("%s/%s says authored but carries the procedural texture"
					% [theme, role])
			continue

		# Claim 3: the pixels survived the import.
		var source := role
		if result["fell_back"].has(role):
			source = str(result["fell_back"][role])
		var row: Dictionary = rows["%s/%s" % [theme, source]]
		var want := _from_bytes("%s/%s" % [_content, row["texture"]])
		var got: Image = material.albedo_texture.get_image()
		var verdict := _same_pixels(want, got)
		note["pixels_match"][role] = bool(verdict["same"])
		if not bool(verdict["same"]):
			_fail("%s/%s: the material's texture is not the authored PNG "
					% [theme, role]
					+ "-- the import changed the pixels between the file "
					+ "the descriptor hashed and the one the GPU samples "
					+ "(%s)" % verdict["why"])

		# Claim 4: the sampler state the binder owns. The values are named
		# HERE rather than read off the binder -- asking it what it set and
		# then checking it set that is a check that cannot fail.
		if material.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
			_fail("%s/%s is not NEAREST-filtered" % [theme, role])
		if not material.texture_repeat:
			_fail("%s/%s does not repeat" % [theme, role])
		var covers := float(row["size_px"]) / texels
		var want_scale := 1.0 / covers
		note["uv1_scale"][role] = material.uv1_scale.x
		if absf(material.uv1_scale.x - want_scale) > 0.0001:
			_fail("%s/%s tiles at %f per metre, the pack says %f"
					% [theme, role, material.uv1_scale.x, want_scale])
	return note


func _run() -> void:
	var pack: Dictionary = _binder.call("load_pack", _content)
	if pack.is_empty():
		_fail("no THEME_PACK.json at %s" % _content)
		_finish()
		return
	var themes: Array = pack.get("themes", [])
	_log["mode"] = _mode
	_log["themes"] = {}
	for raw: Variant in themes:
		var theme := str(raw)
		_log["themes"][theme] = _check_theme(pack, theme)

	match _mode:
		"whole":
			for theme: String in _log["themes"]:
				var note: Dictionary = _log["themes"][theme]
				if note["disqualified"]:
					_fail("%s is disqualified against the whole pack: %s"
							% [theme, note["why"]])
				for role: String in ["floor", "wall", "accent", "trim"]:
					if not bool(note["authored"].get(role, false)):
						_fail("%s/%s did not bind authored pixels"
								% [theme, role])
		"missing_required":
			_expect_disqualified("concrete_facility", "floor")
		"missing_optional":
			_expect_fallback("concrete_facility", "ceiling", "wall")
		"mismatched_digest":
			_expect_refused("concrete_facility", "wall", "digests")
		_:
			_fail("unknown mode %s" % _mode)
	_finish()


## The control the owner asked to be RETAINED: a genuinely required
## authored texture is gone, and the documented behaviour is observed.
func _expect_disqualified(theme: String, role: String) -> void:
	var note: Dictionary = _log["themes"].get(theme, {})
	if not bool(note.get("disqualified", false)):
		_fail("%s is missing its required %s and bound anyway. "
				% [theme, role]
				+ "`disqualifies_theme_if_missing` is not being honoured, "
				+ "which means the descriptor's contract is decoration.")
		return
	for other: String in _log["themes"]:
		var n: Dictionary = _log["themes"][other]
		if other == theme:
			# Nothing bound, not five roles out of six.
			for each: String in n["authored"]:
				if bool(n["authored"][each]):
					_fail("%s is disqualified but still bound %s"
							% [theme, each])
		elif bool(n["disqualified"]):
			_fail("%s took %s down with it" % [theme, other])
		elif not bool(n["authored"].get("floor", false)):
			_fail("%s stopped binding its floor when %s lost one"
					% [other, theme])
	print("[bind] control: %s without %s -> disqualified, %d theme(s) "
			% [theme, role, _log["themes"].size() - 1]
			+ "unaffected, its roles served by ThemeMaterials")


## Clause 4 is live: a texture that loads perfectly well but is not the one
## the descriptor hashed does not get bound.
func _expect_refused(theme: String, role: String, tell: String) -> void:
	var note: Dictionary = _log["themes"].get(theme, {})
	if not bool(note.get("disqualified", false)):
		_fail("%s's %s is the wrong file and it bound anyway. Clause 4 is "
				% [theme, role]
				+ "not being enforced, so the descriptor's digests are "
				+ "decoration and a room can come out in another theme's "
				+ "pixels with nothing said.")
		return
	var said := false
	for why: String in note.get("why", []):
		if why.contains(tell):
			said = true
	if not said:
		_fail("%s was disqualified but not for the digest: %s"
				% [theme, note.get("why", [])])
		return
	for other: String in _log["themes"]:
		if other != theme and bool(_log["themes"][other]["disqualified"]):
			_fail("%s took %s down with it" % [theme, other])
	print("[bind] control: %s/%s replaced with another theme's file -> "
			% [theme, role] + "refused on its digest, theme disqualified")


func _expect_fallback(theme: String, role: String, to: String) -> void:
	var note: Dictionary = _log["themes"].get(theme, {})
	if bool(note.get("disqualified", false)):
		_fail("%s lost an OPTIONAL %s and was disqualified for it"
				% [theme, role])
		return
	if str(note.get("fell_back", {}).get(role, "")) != to:
		_fail("%s lost its %s and did not fall back to %s as the "
				% [theme, role, to]
				+ "descriptor says; it reports %s"
				% [note.get("fell_back", {})])
		return
	if not bool(note["pixels_match"].get(role, false)):
		_fail("%s/%s claims the %s fallback but is not carrying the %s "
				% [theme, role, to, to] + "pixels")
		return
	print("[bind] control: %s without %s -> bound, %s served by its %s "
			% [theme, role, role, to] + "pixels")


func _finish() -> void:
	_log["problems"] = _problems
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[bind] %s: PASS -- %d theme(s)"
				% [_mode, _log.get("themes", {}).size()])
		quit(0)
	else:
		printerr("[bind] %s: %d problem(s)" % [_mode, _problems.size()])
		quit(1)
