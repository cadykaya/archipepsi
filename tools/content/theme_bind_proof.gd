extends SceneTree
## DOES THE EXPORTED PACK BIND, THROUGH PRODUCTION'S OWN CONSUMER?
##
##   godot --path godot -s _harness/bindproof.gd -- <out.json> <mode>
##
## ## What this is NOT, any more
##
## ~~An art-lane reference binder.~~ **THE RUNTIME BINDER IS NOT
## MISSING.** `ThemeMaterials._material` at current Production asks
## `ThemePack.texture_for(theme, role)` FIRST and falls back to
## `ProcTextures` only when the pack answers null -- and it ships
## `is_authored()` and `reset_cache()` for exactly the question this file
## was built to ask. An art-side binder would be a second source of
## material behaviour, so there is not one: this drives Production's,
## fetched read-only, by the two mechanical moves this lane already
## documents (`class_name` stripped, cross-references bound to preloads).
##
## ## What is still Art's to check, and why it is worth keeping
##
## `ThemePack` verifies `sha256_16` over the PNG's FILE BYTES. Nothing
## anywhere checks that the texture the GPU finally samples is those
## pixels -- between the last byte on disk and a wall in a room sit an
## importer, a sidecar, a resource loader and a `.godot/imported` cache,
## and every one of them can turn a correct file into a wrong wall while
## every digest still matches. That comparison is this file's reason to
## exist and it is made against the material PRODUCTION built.
##
## MIPMAPS ARE WHY IT IS NOT A ONE-LINE COMPARE. The sidecars ask for
## them, so the imported image carries its whole chain and `get_data()`
## comes back about a third longer than the authored PNG's -- same width,
## same height, different bytes. The first version of this check reported
## all 37 textures as corrupted by the import, which is the check having
## been seen to fail.
##
## ## The control
##
## `ThemePack._descriptor_override` is Production's own test seam, and
## using it rather than moving real files is the point: the control
## exercises the consumer's documented fallback instead of a second
## mechanism that might disagree with it.

const REQUIRED := ["floor", "wall", "trim", "accent"]

var _out: String
var _mode: String
var _models := ""
var _shell := ""
var _png := ""
var _theme := "concrete_facility"
var _pack: GDScript
var _mats: GDScript
var _problems: Array[String] = []
var _log := {}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <out.json> <mode>")
	else:
		_out = a[0]
		_mode = a[1]
		if a.size() >= 5:
			_models = a[2]
			_shell = a[3]
			_png = a[4]
	_pack = load("res://_harness/prod_theme_pack.gd") as GDScript
	_mats = load("res://_harness/prod_theme_materials.gd") as GDScript
	if _pack == null or _mats == null:
		_fail("Production's theme scripts did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[bind] FAIL: %s" % what)


func _material(theme: String, role: String) -> StandardMaterial3D:
	match role:
		"floor": return _mats.call("floor_mat", theme)
		"wall": return _mats.call("wall_mat", theme)
		"accent": return _mats.call("accent_mat", theme)
		"trim": return _mats.call("trim_mat", theme)
		"hazard": return _mats.call("hazard_mat", theme)
	return null


## The authored PNG, decoded from its own bytes -- never through the
## importer, because the importer is the thing under test.
func _from_bytes(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	return image if image.load_png_from_buffer(bytes) == OK else null


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
		return {"same": false, "why": "authored %dx%d, bound %dx%d"
				% [left.get_width(), left.get_height(),
						right.get_width(), right.get_height()]}
	if left.get_data() == right.get_data():
		return {"same": true, "why": ""}
	var differing := 0
	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y):
				differing += 1
	return {"same": false, "why": "%d of %d pixels differ"
			% [differing, left.get_width() * left.get_height()]}


func _check_theme(theme: String) -> Dictionary:
	var rows: Dictionary = _pack.call("descriptor").get("textures", {})
	var note := {"authored": {}, "pixels_match": {}, "uv1_scale": {},
			"disqualified": _pack.call("disqualified", theme),
			"refusals": _pack.call("refusals", theme)}

	# Rule 4, the other way round: the pack must never paint hazard, and
	# `ThemeMaterials.hazard_mat` must come back procedural in EVERY theme.
	var hazard := _material(theme, "hazard")
	note["authored"]["hazard"] = bool(_mats.call("is_authored", hazard))
	if bool(note["authored"]["hazard"]):
		_fail("%s: hazard_mat is bound from the pack. It is the shared "
				% theme + "universal signal and six tinted ones is the "
				+ "defect the contract exists to prevent.")

	for role: String in REQUIRED:
		var material := _material(theme, role)
		var authored := bool(_mats.call("is_authored", material))
		note["authored"][role] = authored
		if not authored:
			continue
		var row: Dictionary = rows.get("%s/%s" % [theme, role], {})
		if row.is_empty():
			_fail("%s/%s bound, and the descriptor has no row for it"
					% [theme, role])
			continue
		# THE PIXELS THE GPU SAMPLES, against the authored file's own.
		var want := _from_bytes("res://content/%s" % row["texture"])
		var got: Image = material.albedo_texture.get_image()
		var verdict := _same_pixels(want, got)
		note["pixels_match"][role] = bool(verdict["same"])
		if not bool(verdict["same"]):
			_fail("%s/%s: the material Production built is not carrying "
					% [theme, role]
					+ "the authored PNG -- the import changed the pixels "
					+ "between the file the descriptor hashed and the one "
					+ "the GPU samples (%s)" % verdict["why"])
		# Clause 5: covers_m drives the scale, and the harness names the
		# expected value itself rather than asking the binder for it.
		var covers: float = _pack.call("covers_m", theme, role)
		note["uv1_scale"][role] = snappedf(material.uv1_scale.x, 0.0001)
		if absf(material.uv1_scale.x - 1.0 / covers) > 0.0001:
			_fail("%s/%s tiles at %f, and %.2f m per tile wants %f"
					% [theme, role, material.uv1_scale.x, covers,
							1.0 / covers])
		if material.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
			_fail("%s/%s is not NEAREST-filtered" % [theme, role])
	return note


func _sweep(label: String) -> void:
	_mats.call("reset_cache")
	var themes: Array = _pack.call("descriptor").get("themes", [])
	var out := {}
	for raw: Variant in themes:
		out[str(raw)] = _check_theme(str(raw))
	_log[label] = out


func _run() -> void:
	_log["mode"] = _mode
	if not bool(_pack.call("bound")):
		_fail("ThemePack reports the pack is not bound at all, so nothing "
				+ "below would be measuring a binding")
		_finish()
		return

	match _mode:
		"whole":
			_sweep("themes")
			var all: Dictionary = _log["themes"]
			for theme: String in all:
				var note: Dictionary = all[theme]
				if not (note["disqualified"] as Array).is_empty():
					_fail("%s is disqualified: %s"
							% [theme, note["disqualified"]])
				for role: String in REQUIRED:
					if not bool(note["authored"].get(role, false)):
						_fail("%s/%s fell back to ProcTextures and the pack "
								% [theme, role] + "ships a row for it")
		"missing_required":
			_control_missing("concrete_facility", "floor")
		"render":
			await _render_signs()
		_:
			_fail("unknown mode %s" % _mode)
	_finish()


## THE LETTERING, ON THE PATH THE ENGINE ACTUALLY RUNS.
##
## **An authored shell keeps the materials Blender baked.**
## `ContentInstantiator._from_authored_scene` calls `scene.instantiate()`
## and the file contains the string "material" ZERO times;
## `chamber_builders.gd` names `ThemeMaterials` 46 times. The split is
## total: themed materials are the PROCEDURAL half and the gameplay
## objects, and a `.glb` room is never re-materialled.
##
## An earlier version of this function swapped every surface to
## `ThemeMaterials` and photographed the result, which produced a true
## picture of a path these rooms do not take. Both frames are kept and
## both are labelled, because the pair is still the evidence for the
## PROCEDURAL defect -- it is just not evidence about this shell.
##
## So the repair is proved where it lands: the authored materials, both
## faces of a two-sided sign, and the room rotated, with ordinary wall
## and floor tiling in the same frame.
func _render_signs() -> void:
	var bench := load("res://_harness/artbench.gd") as GDScript
	if bench == null:
		_fail("the bench script did not load")
		return
	# (camera, target, yaw, name)
	var shots := [
		[Vector3(2.1, 2.05, 8.0), Vector3(2.1, 2.05, 13.4), 0.0,
			"A1_authored_south_board"],
		[Vector3(2.5, 2.05, 27.0), Vector3(2.5, 2.05, 21.6), 0.0,
			"A2_authored_north_placard"],
		[Vector3(2.1, 2.05, 8.0), Vector3(2.1, 2.05, 13.4), 37.0,
			"A3_authored_south_board_room_yawed_37"],
		[Vector3(2.5, 2.05, 27.0), Vector3(2.5, 2.05, 21.6), 37.0,
			"A4_authored_north_placard_room_yawed_37"],
	]
	for raw: Variant in shots:
		var shot: Array = raw
		await _frame(bench, shot[0], shot[1], float(shot[2]),
				"%s_%s.png" % [_png.get_basename(), shot[3]], false)
	# Kept, and relabelled: the procedural path's defect, not this
	# shell's. Same camera as A1 so the pair still compares.
	await _frame(bench, Vector3(2.1, 2.05, 8.0), Vector3(2.1, 2.05, 13.4),
			0.0, "%s_B_thememateri_procedural_path.png" % _png.get_basename(),
			true)
	print("[bind] wrote 5 lettering frames")


func _frame(bench: GDScript, eye: Vector3, look: Vector3, yaw: float,
		path: String, themed: bool) -> void:
	var view: SubViewport = bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.35)
	var root := Node3D.new()
	view.add_child(root)
	var shell: Node3D = bench.call("load_glb", "%s/%s.glb" % [_models, _shell])
	if shell == null:
		_fail("could not load %s" % _shell)
		return
	root.add_child(shell)
	# ROTATING THE ROOM, not the camera round it: triplanar reads world
	# position, so a yawed room is the case that tells the two mappings
	# apart. The camera rides the same rotation, so the framing is
	# identical and only the world axes have moved.
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	shell.transform = Transform3D(basis, Vector3.ZERO)

	var swapped := 0
	if themed:
		for child in shell.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var had: Material = mi.mesh.surface_get_material(i)
				var role := "wall" if had == null else str(had.resource_name)
				var built := _material(_theme, role)
				if built != null:
					mi.set_surface_override_material(i, built)
					swapped += 1
		if swapped == 0:
			_fail("the themed frame re-materialled nothing, so it is the "
					+ ".glb's own materials wearing the wrong caption")

	var env := (view.get_node_or_null("WorldEnvironment") as WorldEnvironment)
	if env != null:
		env.environment.ambient_light_color = Color(0.72, 0.77, 0.82)
		env.environment.ambient_light_energy = 0.9
	var lamp := OmniLight3D.new()
	lamp.omni_range = 20.0
	lamp.light_energy = 3.0
	lamp.shadow_enabled = false
	root.add_child(lamp)
	lamp.global_position = basis * (eye + Vector3(0, 2.0, 0))

	var cam := Camera3D.new()
	cam.fov = 50.0
	view.add_child(cam)
	cam.global_position = basis * eye
	cam.look_at(basis * look, Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	var caption := "PRODUCTION ThemeMaterials -- the PROCEDURAL path. An " \
			+ "authored .glb never receives these." if themed \
			else "THE AUTHORED MATERIALS -- what ContentInstantiator " \
			+ "instantiates, unchanged"
	bench.call("label", image, caption, Vector2i(16, 16), Color(1, 0.86, 0.3))
	if yaw != 0.0:
		bench.call("label", image, "room yawed %d degrees" % int(yaw),
				Vector2i(16, 34), Color(0.82, 0.84, 0.88))
	if image.save_png(path) != OK:
		_fail("could not write %s" % path)
	view.queue_free()


## THE CONTROL, THROUGH PRODUCTION'S OWN SEAM. A descriptor with one
## required row removed, installed by `use_descriptor`, and the documented
## fallback observed: that theme's role is procedural, the theme says
## which role disqualified it, and NO OTHER THEME IS AFFECTED.
func _control_missing(theme: String, role: String) -> void:
	var descriptor: Dictionary = (_pack.call("descriptor") as Dictionary
			).duplicate(true)
	var rows: Dictionary = descriptor["textures"]
	if not rows.erase("%s/%s" % [theme, role]):
		_fail("the control could not remove %s/%s -- the descriptor has no "
				% [theme, role] + "such row, so it was testing nothing")
		return
	_pack.call("use_descriptor", descriptor)
	_sweep("themes")
	_pack.call("clear_descriptor")

	var all: Dictionary = _log["themes"]
	var note: Dictionary = all.get(theme, {})
	if not (note.get("disqualified", []) as Array).has(role):
		_fail("%s lost its required %s and ThemePack does not call it "
				% [theme, role] + "disqualified")
	if bool(note.get("authored", {}).get(role, false)):
		_fail("%s/%s is bound from a descriptor that no longer lists it"
				% [theme, role])
	for other: String in all:
		if other == theme:
			continue
		var n: Dictionary = all[other]
		for each: String in REQUIRED:
			if not bool(n["authored"].get(each, false)):
				_fail("%s/%s stopped binding when %s lost a row"
						% [other, each, theme])
	print("[bind] control: %s without %s -> disqualified for that role, "
			% [theme, role] + "%d other theme(s) unaffected" % (all.size() - 1))


func _finish() -> void:
	_log["problems"] = _problems
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[bind] %s: PASS" % _mode)
		quit(0)
	else:
		printerr("[bind] %s: %d problem(s)" % [_mode, _problems.size()])
		quit(1)
