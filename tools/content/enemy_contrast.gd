extends SceneTree
## Tier 1 -- how far an enemy's body sits from what is behind it, in all
## six rooms, each under ITS OWN light.
##
## Owner ruling, 2026-09-25: use the smallest set of theme-dependent
## VALUE BANDS, and before landing them validate *"not only against the
## six wall lineups but also against representative floor backgrounds
## and deliberately dim room lighting. We should not solve wall contrast
## by making enemy bodies disappear into floors or shadows."*
##
## So four cases per theme:
##
##   wall   level camera at the review distance, the room's own light.
##          What an enemy looks like at the moment it notices you.
##   floor  the same distance from 45 degrees above, with no back wall,
##          so every enemy is seen against FLOOR -- a gantry looking down
##          into a pit, which this game builds on purpose.
##   dim    the wall view with the room's light and ambient cut to DIM
##          of themselves. A dark corner.
##   opening  the wall view with NO wall: the row seen against what an
##          exit, a drop or a window shows -- the room's fogged void. The
##          one backdrop that can be darker than a dark enemy, so the one
##          place a value band could make a body vanish rather than stand
##          out. Added for exactly the owner's "disappear into shadows".
##
## ## Why this is a new file
##
## The contrast measurement used to live in `enemy_silhouettes.gd`, and
## it lit all six themes with concrete_facility's lamp while its own
## docstring said "one lamp at the theme's own colour and energy". The
## energies run 2.0 to 4.0 and the colours from amber to cyan, and the
## band ceilings the owner ruled on were derived from those numbers. It
## also never created a WorldEnvironment, so its ambient settings were
## no-ops. One harness now owns every value number the bands stand on.

const ROLES := ["artillery", "beacon", "brute", "bulwark", "charger",
	"diver", "drifter", "melee", "ranged", "scuttler"]
const ALL_THEMES := ["concrete_facility", "rusted_industrial",
	"neon_transit", "gothic_stone", "temple_ruin", "void_glitch"]
## DIAGNOSTIC knobs, off by default and never used for a band decision:
##   ENEMY_CONTRAST_THEMES  comma list, to measure a subset quickly
##   ENEMY_CONTRAST_MATTE   1 = every enemy surface roughness 1, metallic
##                          0, specular 0 -- to find out how much of the
##                          body's rendered light is REFLECTION rather
##                          than paint, which decides whether a value-only
##                          band can work at all.
var THEMES: Array = ALL_THEMES
var _matte := false
## More DIAGNOSTIC knobs, to find what lights a body independently of
## its paint: ENEMY_CONTRAST_BLACK=1 forces albedo to black (whatever
## still renders is not paint), NOFOG=1 and NOAMBIENT=1 remove the
## room's fog and ambient term.
var _black := false
var _nofog := false
var _noambient := false
const CASES := ["wall", "floor", "dim", "opening"]
## "Deliberately dim": the room's lamp and ambient at this fraction. A
## judgement, printed with the results so it can be argued with.
const DIM := 0.35
## THE GAME'S OWN ENVIRONMENT, from `zone_builder.gd` at the 0.4 ref:
## ambient 0.35 in the theme's light colour, fog at 0.012, background
## and fog from the theme's `void_color`, and the tonemapper left at
## Godot's default, which is LINEAR.
##
## The first version of this harness used the review bench's viewport,
## which forces a FILMIC tonemapper and has no fog -- and at 18 m fog at
## 0.012 replaces about a fifth of an enemy's colour with fog colour.
## Band ceilings measured through a different lens are ceilings for a
## different game. `run_enemy_contrast.sh` refuses to run if these three
## values have moved in Production's file.
const AMBIENT := 0.35
const FOG_DENSITY := 0.012
const SHOT := Vector2i(1920, 1080)
## The wall behind the row, above the floor line, at the level camera.
const WALL_BAND := Vector2(0.30, 0.52)
## How far around the row the FLOOR case samples its background, in px.
const HALO := 24
## How much room either side of the row the saved frame keeps, in px.
const CROP_SIDE := 240

var _bench: GDScript
var _out := ""
var _distance := 18.0
var _fov := 90.0
var _min_value := 0.10
var _min_inter := 0.18
var _anchors := {}
var _models := {}
var _rows := {}
var _faults: Array[String] = []


func _bad(what: String) -> void:
	_faults.append(what)
	print("[contrast] FAULT: %s" % what)


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		push_error("[contrast] need <out> <palette.json> <budgets.json> "
				+ "<models.json>")
		quit(1)
		return
	_out = a[0]
	var palette: Variant = _json(a[1])
	var budgets: Variant = _json(a[2])
	var models: Variant = _json(a[3])
	if typeof(palette) != TYPE_DICTIONARY or typeof(budgets) != TYPE_DICTIONARY \
			or typeof(models) != TYPE_DICTIONARY:
		push_error("[contrast] could not read palette, budgets or models")
		quit(1)
		return
	_anchors = palette["engine_anchors"]
	_distance = float(budgets["enemy_review_distance_m"])
	_fov = float(budgets["dimensions"]["camera_fov_deg"])
	_min_value = float(budgets["min_value_separation"])
	_min_inter = float(budgets["min_interactable_separation"])
	_models = models
	for theme in ALL_THEMES:
		if not _models.has(theme):
			push_error("[contrast] no model set named for %s" % theme)
			quit(1)
			return
	var only := OS.get_environment("ENEMY_CONTRAST_THEMES")
	if only != "":
		THEMES = Array(only.split(","))
	_matte = OS.get_environment("ENEMY_CONTRAST_MATTE") == "1"
	_black = OS.get_environment("ENEMY_CONTRAST_BLACK") == "1"
	_nofog = OS.get_environment("ENEMY_CONTRAST_NOFOG") == "1"
	_noambient = OS.get_environment("ENEMY_CONTRAST_NOAMBIENT") == "1"
	if _black or _nofog or _noambient:
		print("[contrast] DIAGNOSTIC: black=%s nofog=%s noambient=%s"
			  % [_black, _nofog, _noambient])
	if _matte:
		print("[contrast] DIAGNOSTIC: every enemy surface forced matte")
	_bench = load("res://_harness/artbench.gd") as GDScript
	await _run()


func _run() -> void:
	if not await _calibrate():
		push_error("[contrast] calibration failed: this harness's L* does "
				+ "not match CIE L* on known greys; nothing it measures "
				+ "can be trusted")
		quit(1)
		return
	var cache := {}
	for theme in THEMES:
		var dir: String = _models[theme]
		# Regions depend on geometry and camera, not on the room -- so they
		# are cached per model set, and a band that changes only the skin
		# reuses them.
		for mode in ["level", "elevated"]:
			var key := "%s|%s" % [dir, mode]
			if not cache.has(key):
				cache[key] = await _regions(dir, mode)
		# WHICH models, not just where: the sha256 of every file measured,
		# so `check_enemy_bands.py` can refuse evidence that no longer
		# describes the committed models.
		var shas := {}
		for role in ROLES:
			shas[role] = FileAccess.get_sha256(
					"%s/enemy_role_%s.glb" % [dir, role])
		_rows[theme] = {"models": dir, "models_sha256": shas}
		for case in CASES:
			var mode := "elevated" if case == "floor" else "level"
			await _measure(theme, dir, case, cache["%s|%s" % [dir, mode]])
	_finish()


func _camera(view: SubViewport, mode: String) -> void:
	var cam := Camera3D.new()
	cam.fov = _fov
	view.add_child(cam)
	if mode == "elevated":
		# 45 degrees down, still the review distance from the row.
		var target := Vector3(0.0, -0.2, -_distance)
		var eye := target + Vector3(0.0, 1.0, 1.0).normalized() * _distance
		cam.look_at_from_position(eye, target, Vector3.UP)
	else:
		cam.look_at_from_position(Vector3.ZERO, Vector3(0, 0, -1), Vector3.UP)


func _row(holder: Node3D, dir: String, flatten: bool) -> Dictionary:
	var models := {}
	var x := 0.0
	for role in ROLES:
		var model: Node3D = _bench.call("load_glb",
				"%s/enemy_role_%s.glb" % [dir, role])
		if model == null:
			_bad("could not load %s/enemy_role_%s.glb" % [dir, role])
			continue
		holder.add_child(model)
		# Facing the camera, as an enemy that has noticed you does: the
		# models face -Z and the camera looks down -Z.
		model.rotation.y = PI
		var box: AABB = _bench.call("aabb_of", model)
		x += box.size.x * 0.5
		model.position = Vector3(x - box.get_center().x,
				-box.position.y - 1.0, -_distance)
		x += box.size.x * 0.5 + 0.55
		if (_matte or _black) and not flatten:
			for child in model.find_children("*", "MeshInstance3D", true,
					false):
				var mi := child as MeshInstance3D
				if mi.mesh == null:
					continue
				for i in mi.mesh.get_surface_count():
					var had := mi.mesh.surface_get_material(i) \
							as StandardMaterial3D
					if had == null:
						continue
					var m := had.duplicate() as StandardMaterial3D
					if _matte:
						m.roughness = 1.0
						m.metallic = 0.0
						m.metallic_specular = 0.0
					if _black:
						m.albedo_texture = null
						m.albedo_color = Color(0, 0, 0, 1)
					mi.set_surface_override_material(i, m)
		if flatten:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0, 0, 0, 1)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			for child in model.find_children("*", "MeshInstance3D", true,
					false):
				var mi := child as MeshInstance3D
				if mi.mesh != null:
					for i in mi.mesh.get_surface_count():
						mi.set_surface_override_material(i, mat)
		models[role] = model
	holder.position = Vector3(-x * 0.5, 0.0, 0.0)
	return models


## One mask per role, from a transparent render with only that role
## visible. The guard below exists because this once silently returned
## the LIT room instead -- two SubViewports alive at once -- and ten
## different models reported one identical L*.
func _regions(dir: String, mode: String) -> Dictionary:
	var view := SubViewport.new()
	view.size = SHOT
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	_camera(view, mode)
	var holder := Node3D.new()
	view.add_child(holder)
	var models := _row(holder, dir, true)
	var out := {}
	for role in models:
		for other in models:
			models[other].visible = other == role
		await process_frame
		await process_frame
		var got := view.get_texture().get_image()
		var n := 0
		for py in got.get_height():
			for px in got.get_width():
				if got.get_pixel(px, py).a > 0.5:
					n += 1
		var share := float(n) / float(SHOT.x * SHOT.y)
		if n == 0:
			_bad("%s rendered nothing in the %s view" % [role, mode])
		elif share > 0.10:
			_bad("%s's %s region covers %.0f%% of the frame -- that is the "
				 % [role, mode, share * 100.0] + "room, not an enemy")
		out[role] = got
	view.queue_free()
	await process_frame
	return out


func _surface(path: String, size: Vector2, at: Vector3,
		rot: Vector3) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	var tex: Variant = load(path)
	if tex == null:
		_bad("no texture at %s" % path)
	else:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.texture_repeat = true
		# `covers_m` is 4.0 for every shipped tile.
		mat.uv1_scale = Vector3(size.x / 4.0, size.y / 4.0, 1.0)
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	return mi


## CIE L* (0..1) of a pixel read back from a viewport. The image is
## sRGB-ENCODED, so each channel is linearised before the luminance sum.
## Summing the encoded channels -- which this function (and its parent in
## enemy_silhouettes.gd) did until 2026-09-25 -- reads #777777 as 0.740
## instead of 0.500, lifts near-black to ~0.29, and compresses every
## separation in the range the enemy family lives in. `_calibrate` holds
## it to reference values it did not compute.
func _lstar(c: Color) -> float:
	var lin := c.srgb_to_linear()
	var y := 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	var l := (116.0 * pow(y, 1.0 / 3.0) - 16.0) if y > 0.008856 \
			else (903.3 * y)
	return clampf(l / 100.0, 0.0, 1.0)


## The instrument, checked before anything is measured with it: three
## unshaded grey cards go through the same kind of viewport as `_measure`
## (default tonemapper, no fog) and are read back through `_lstar`. Each
## must land on its CIE L*. The references are computed offline from the
## sRGB definition, NOT by `_lstar`, so a wrong conversion or a viewport
## that stops returning what it was given both fail here.
const CALIBRATION := {"#3b3b3b": 0.2487, "#777777": 0.5003, "#b9b9b9": 0.7515}
const CALIBRATION_TOLERANCE := 0.01

func _calibrate() -> bool:
	var view := SubViewport.new()
	view.size = Vector2i(96, 32)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	world.environment = e
	view.add_child(world)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	view.add_child(cam)
	cam.look_at_from_position(Vector3.ZERO, Vector3(0, 0, -1), Vector3.UP)
	var greys: Array = CALIBRATION.keys()
	for i in greys.size():
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.0, 1.0)
		quad.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(str(greys[i]))
		quad.material_override = mat
		quad.position = Vector3(float(i) - 1.0, 0.0, -1.0)
		view.add_child(quad)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	view.queue_free()
	await process_frame
	var ok := true
	for i in greys.size():
		var got := _lstar(image.get_pixel(16 + 32 * i, 16))
		var want := float(CALIBRATION[greys[i]])
		var fine := absf(got - want) <= CALIBRATION_TOLERANCE
		print("[contrast] calibration %s  L* %.4f  want %.4f  %s"
				% [greys[i], got, want, "ok" if fine else "WRONG"])
		ok = ok and fine
	return ok


func _measure(theme: String, dir: String, case: String,
		regions: Dictionary) -> void:
	var factor := DIM if case == "dim" else 1.0
	var anchor: Dictionary = _anchors[theme]
	var light := Color(str(anchor["light_color"]))
	var energy := float(anchor["light_energy"]) * factor

	var view := SubViewport.new()
	view.size = SHOT
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var trim := Color(str(anchor["trim_color"]))
	var void_colour := trim.darkened(0.6)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = void_colour
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = light
	e.ambient_light_energy = 0.0 if _noambient else AMBIENT * factor
	e.fog_enabled = not _nofog
	e.fog_light_color = void_colour.lightened(0.1)
	e.fog_density = FOG_DENSITY
	# Tonemapper deliberately NOT set: zone_builder leaves Godot's
	# default, and so must this.
	world.environment = e
	view.add_child(world)
	_camera(view, "elevated" if case == "floor" else "level")
	var holder := Node3D.new()
	view.add_child(holder)
	holder.add_child(_surface("res://content/theme/%s_floor.png" % theme,
			Vector2(80.0, 60.0), Vector3(0.0, -1.0, -_distance),
			Vector3.ZERO))
	if case == "wall" or case == "dim":
		holder.add_child(_surface("res://content/theme/%s_wall.png" % theme,
				Vector2(80.0, 16.0), Vector3(0.0, 7.0, -_distance - 7.0),
				Vector3(deg_to_rad(90.0), 0.0, 0.0)))
	var row := Node3D.new()
	view.add_child(row)
	_row(row, dir, false)
	var lamp := OmniLight3D.new()
	lamp.light_color = light
	lamp.light_energy = energy
	lamp.omni_range = 70.0
	lamp.position = Vector3(0.0, 4.5, -_distance + 4.0)
	view.add_child(lamp)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	view.queue_free()
	await process_frame

	# --- body, per role and together --------------------------------
	var covered := {}
	var per_role := {}
	var body := 0.0
	var body_n := 0
	var lo := Vector2i(SHOT.x, SHOT.y)
	var hi := Vector2i(-1, -1)
	for role in regions:
		var region: Image = regions[role]
		var s := 0.0
		var n := 0
		for py in SHOT.y:
			for px in SHOT.x:
				if region.get_pixel(px, py).a > 0.5:
					var l := _lstar(image.get_pixel(px, py))
					s += l
					n += 1
					covered[py * SHOT.x + px] = true
					lo = Vector2i(mini(lo.x, px), mini(lo.y, py))
					hi = Vector2i(maxi(hi.x, px), maxi(hi.y, py))
		if n > 0:
			per_role[role] = {"lstar": snappedf(s / float(n), 0.001)}
			body += s
			body_n += n

	# --- what is behind them ------------------------------------------
	var back := 0.0
	var back_n := 0
	if case == "floor":
		for py in range(maxi(0, lo.y - HALO), mini(SHOT.y, hi.y + HALO + 1)):
			for px in range(maxi(0, lo.x - HALO), mini(SHOT.x, hi.x + HALO + 1)):
				if not covered.has(py * SHOT.x + px):
					back += _lstar(image.get_pixel(px, py))
					back_n += 1
	else:
		for py in range(int(SHOT.y * WALL_BAND.x), int(SHOT.y * WALL_BAND.y)):
			for px in SHOT.x:
				if not covered.has(py * SHOT.x + px):
					back += _lstar(image.get_pixel(px, py))
					back_n += 1
	if body_n == 0 or back_n == 0:
		_bad("%s/%s: nothing to compare (%d body px, %d background px)"
			 % [theme, case, body_n, back_n])
		return

	var bl := body / float(body_n)
	var gl := back / float(back_n)
	for role in per_role:
		per_role[role]["separation"] = snappedf(
				absf(float(per_role[role]["lstar"]) - gl), 0.001)
	var sep := absf(bl - gl)
	_rows[theme][case] = {
		"body_lstar": snappedf(bl, 0.001),
		"background_lstar": snappedf(gl, 0.001),
		"separation": snappedf(sep, 0.001),
		"body_above_background": bl > gl,
		"clears_value": sep >= _min_value,
		"clears_interactable": sep >= _min_inter,
		"light": {"color": str(anchor["light_color"]), "energy": energy},
		"per_role": per_role,
	}
	print("[contrast] %-18s %-5s body %.3f  back %.3f  apart %.3f  %s"
		  % [theme, case, bl, gl, sep,
			 "clears 0.18" if sep >= _min_inter
			 else "clears 0.10" if sep >= _min_value else "SHORT"])

	# The saved frame is the row and what was measured around it, not the
	# whole 1920 x 1080: four cases x six rooms of mostly-empty wall is
	# 12 MB of evidence nobody can read on a phone. The crop keeps the
	# background band (or the floor halo) the numbers came from.
	var top := lo.y - HALO - 60 if case == "floor" \
			else mini(lo.y, int(SHOT.y * WALL_BAND.x)) - 24
	var crop := Rect2i(Vector2i(maxi(0, lo.x - CROP_SIDE), maxi(0, top)),
			Vector2i.ZERO)
	crop.end = Vector2i(mini(SHOT.x, hi.x + CROP_SIDE),
			mini(SHOT.y, hi.y + HALO + 60))
	var shot := image.get_region(crop)
	_bench.call("label", shot, "PROPOSAL -- MEASUREMENT, NOT APPROVED",
			Vector2i(8, 8), Color(1, 0.86, 0.3))
	_bench.call("label", shot, "%s -- %s -- %.1f m -- LIGHT %s AT %.2f"
			% [theme, case, _distance, anchor["light_color"], energy],
			Vector2i(8, 26), Color(0.84, 0.86, 0.90))
	_bench.call("label", shot, "BODY %.3f  BACK %.3f  APART %.3f"
			% [bl, gl, sep], Vector2i(8, 44), Color(0.84, 0.86, 0.90))
	shot.save_png("%s/CONTRAST_%s_%s.png" % [_out, theme, case])


func _finish() -> void:
	_rows["_meta"] = {"distance_m": _distance, "fov_deg": _fov,
		"dim_factor": DIM, "ambient_energy": AMBIENT,
		"fog_density": FOG_DENSITY, "tonemapper": "default (linear)",
		"environment_source": "zone_builder.gd, claude/archipepsi-0-4-blindside",
		"min_value_separation": _min_value,
		"min_interactable_separation": _min_inter,
		"engine": Engine.get_version_info()["string"]}
	_rows["_faults"] = _faults
	var fh := FileAccess.open("%s/contrast.json" % _out, FileAccess.WRITE)
	fh.store_string(JSON.stringify(_rows, "\t", true, true))
	fh.close()
	if _faults.is_empty():
		print("[contrast] %d theme(s) x %d case(s) measured"
			  % [THEMES.size(), CASES.size()])
	else:
		push_error("[contrast] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
