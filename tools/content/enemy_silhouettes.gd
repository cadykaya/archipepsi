extends SceneTree
## Track B -- the ten-role family at the distance it is actually read.
##
## `02` PT-10 asks for the lineup judged **without audio, captions,
## collider overlays or studio lighting**, distinguishing shape, not
## width or hue. The named failure is that artillery is a wider version
## of another robot, and a different width is not a different
## silhouette.
##
## Every number here is the project's own:
##
##   enemy_review_distance_m  18.0  -- the aggro radius. The distance at
##                                     which an enemy notices you is the
##                                     distance at which you must be
##                                     able to name it.
##   camera_fov_deg           90.0  -- the game camera.
##   enemy_aggro_px_1080p     48.0  -- what that works out to on screen.
##
## Forty-eight pixels tall. That is the whole budget, and it is why this
## harness renders at native size and measures there rather than
## rendering large and trusting that it would have survived shrinking.
##
## One pass per role: a SILHOUETTE pass, flat black on transparent,
## which is the measurement -- the outline alone, with hue and material
## taken away so they cannot do the work that shape is supposed to do.
## The lit lineup that used to sit beside it, and every VALUE number, now
## live in `enemy_contrast.gd` (see the note at the end of `_run`).

const ROLES := ["artillery", "beacon", "brute", "bulwark", "charger",
	"diver", "drifter", "melee", "ranged", "scuttler"]
## An enemy is not seen from the front. Three yaws, because a pair that
## is distinct head-on and identical in profile is still a pair the
## player cannot tell apart -- and the first version of this harness
## rendered one view and would have called that family distinct.
const YAWS := [0, 45, 90]

const SHOT := Vector2i(1920, 1080)

var _bench: GDScript
var _out := ""
var _models := ""
var _distance := 18.0
var _fov := 90.0
var _budget_px := 48.0

var _faults: Array[String] = []
var _rows := {}
var _envelope := {}


func _bad(what: String) -> void:
	_faults.append(what)
	print("[enemysil] FAULT: %s" % what)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		push_error("[enemysil] need <out> <models dir> <budgets.json> "
				+ "<enemy manifest.json>")
		quit(1)
		return
	_out = a[0]
	_models = a[1]
	var budgets: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(a[2]))
	if typeof(budgets) != TYPE_DICTIONARY:
		push_error("[enemysil] could not read the budgets")
		quit(1)
		return
	# Read, never restated. If the aggro radius moves, this harness moves
	# with it and the sheets say the new number.
	_distance = float(budgets["enemy_review_distance_m"])
	_fov = float(budgets["dimensions"]["camera_fov_deg"])
	_budget_px = float(budgets["enemy_aggro_px_1080p"])

	var manifest: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(a[3]))
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("[enemysil] could not read the enemy manifest")
		quit(1)
		return
	_envelope = manifest
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		push_error("[enemysil] artbench is not staged")
		quit(1)
		return
	await _run()


func _place(view: SubViewport, role: String, yaw: int) -> Node3D:
	var model: Node3D = _bench.call("load_glb",
			"%s/enemy_role_%s.glb" % [_models, role])
	if model == null:
		_bad("could not load enemy_role_%s.glb" % role)
		return null
	view.add_child(model)
	# Yaw 0 is the enemy FACING the camera: the models face -Z, as the
	# game's enemies do, and the camera looks down -Z, so a model turned
	# half round faces it -- the view the player gets.
	model.rotation = Vector3(0.0, PI + deg_to_rad(float(yaw)), 0.0)
	var box: AABB = _bench.call("aabb_of", model)
	# Centred on screen and stood at the review distance. The model's own
	# floor stays on the floor -- an enemy read from above is not the
	# read this is testing.
	model.position = Vector3(-box.get_center().x,
			-box.position.y - box.size.y * 0.5, -_distance)
	return model


func _camera(view: SubViewport) -> void:
	var cam := Camera3D.new()
	cam.fov = _fov
	cam.position = Vector3.ZERO
	cam.look_at_from_position(Vector3.ZERO, Vector3(0, 0, -1), Vector3.UP)
	view.add_child(cam)


func _viewport(transparent: bool) -> SubViewport:
	var view := SubViewport.new()
	view.size = SHOT
	view.transparent_bg = transparent
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view


func _flatten(model: Node3D) -> void:
	## Every surface unlit black. Hue and material are exactly what this
	## pass exists to remove: they are allowed to help a player, and they
	## are not allowed to stand in for a shape that does not read.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, mat)


func _mask_box(image: Image) -> Rect2i:
	var lo := Vector2i(image.get_width(), image.get_height())
	var hi := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				lo.x = mini(lo.x, x)
				lo.y = mini(lo.y, y)
				hi.x = maxi(hi.x, x)
				hi.y = maxi(hi.y, y)
	if hi.x < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _run() -> void:
	for role in ROLES:
		var best := {}
		for yaw in YAWS:
			# --- the measurement pass ---------------------------------
			var view := _viewport(true)
			_camera(view)
			var model := _place(view, role, yaw)
			if model == null:
				continue
			_flatten(model)
			await process_frame
			await process_frame
			var shot := view.get_texture().get_image()
			# The anchors are points to FETCH, embedded in the body; the
			# same view with them hidden must be the same silhouette to
			# the pixel, or one of them stands proud of the surface.
			var anchors := model.find_children("anchor_*", "MeshInstance3D",
					true, false)
			for a in anchors:
				(a as MeshInstance3D).visible = false
			await process_frame
			await process_frame
			var bare := view.get_texture().get_image()
			var proud := 0
			for y in shot.get_height():
				for x in shot.get_width():
					if (shot.get_pixel(x, y).a > 0.5) \
							!= (bare.get_pixel(x, y).a > 0.5):
						proud += 1
			if anchors.is_empty():
				_bad("%s has no anchor_* nodes to hide" % role)
			elif proud > 0:
				_bad("%s yaw %d: %d pixel(s) of anchor stand proud of the "
					 % [role, yaw, proud] + "body -- a marker meant to be "
					 + "fetched, not seen")
			var box := _mask_box(shot)
			if box.size.y <= 0:
				_bad("%s rendered nothing at %.1f m, yaw %d"
					 % [role, _distance, yaw])
				view.queue_free()
				continue
			# The silhouette at NATIVE SIZE. No upscale: this file is
			# the measurement's input, and resampling it would measure
			# the resampler.
			var mask := shot.get_region(box)
			mask.convert(Image.FORMAT_RGBA8)
			if mask.save_png("%s/MASK_%s_y%03d.png" % [_out, role, yaw]) != OK:
				_bad("could not write MASK_%s_y%03d.png" % [role, yaw])
			var covered := 0
			for y in mask.get_height():
				for x in mask.get_width():
					if mask.get_pixel(x, y).a > 0.5:
						covered += 1
			var row := {
				"px_h": box.size.y, "px_w": box.size.x,
				"fill": snappedf(float(covered)
						/ float(maxi(1, box.size.x * box.size.y)), 0.001),
				"aspect": snappedf(float(box.size.x)
						/ float(maxi(1, box.size.y)), 0.001),
			}
			print("[enemysil] %-10s yaw %3d  %3d x %3d px, %.0f%% filled"
				  % [role, yaw, box.size.x, box.size.y,
					 float(row["fill"]) * 100.0])
			row["yaw"] = yaw
			row["anchors_visible_px"] = proud
			best["y%03d" % yaw] = row
			view.queue_free()
		if not best.is_empty():
			_rows[role] = best

	if _rows.is_empty():
		_bad("no role rendered; there is nothing to measure")
		_finish()
		return

	# --- the camera, and every model's scale, against the declaration --
	#
	# Vertical half-height at distance d is d * tan(fov/2), so a metre is
	# `SHOT.y / (2 * d * tan(fov/2))` pixels.
	#
	# `enemy_aggro_px_1080p` is derived from the MELEE role's height --
	# not the tallest one, which is what this check first compared and
	# was duly told off for. So melee is what validates the camera, and
	# every other role is then measured against ITS OWN declared
	# envelope.
	var per_metre := float(SHOT.y) / (2.0 * _distance
			* tan(deg_to_rad(_fov) * 0.5))
	print("[enemysil] %.1f px per metre at %.0f m" % [per_metre, _distance])
	# Height is the same at every yaw, so the head-on row is the
	# reference -- and `_rows[role]` is keyed by yaw now, which this
	# line forgot once and hung the harness rather than failing it.
	if _rows.has("melee") and _rows["melee"].has("y000"):
		var got: float = float(_rows["melee"]["y000"]["px_h"])
		if absf(got - _budget_px) > 3.0:
			_bad("melee measures %.0f px and the budget derives %.1f px "
				 % [got, _budget_px]
				 + "from its height at this distance. The camera here is "
				 + "not the one the budget was derived for")

	# --- the visible body against the volume it is declared to fill ----
	#
	# The envelope is `Constants.ENEMY_ENVELOPES` -- Production's, read
	# and never redefined by art. A visible body SHORTER or NARROWER
	# than its envelope is ordinary: the collider is a box and a robot
	# is not. A visible body that OVERFLOWS it is the PT-12 seam -- a
	# part you can see, outside the volume that can be hit. Reported in
	# metres, never fixed here: the damage volume is Production's.
	#
	# THE BOUND IS PER YAW, and getting that wrong made this check
	# report six overflows that were nothing but arithmetic. An
	# axis-aligned box w x d seen at 45 degrees presents its DIAGONAL,
	# and sqrt(w^2 + d^2) is wider than w for every body that is not a
	# cylinder. Comparing a diagonal against a side finds an "overflow"
	# in any object with corners.
	for role in ROLES:
		if not _rows.has(role):
			continue
		var key := "enemy_role_%s" % role
		if not _envelope.has(key):
			_bad("%s has no manifest entry, so its visible body cannot be "
				 % role + "compared with the volume it declares")
			continue
		var env: Array = _envelope[key]["envelope_w_h_d_m"]
		var ew := float(env[0])
		var eh := float(env[1])
		var ed := float(env[2])
		var worst_w := -99.0
		var worst_h := -99.0
		var worst_at := 0
		for yaw in YAWS:
			var tag := "y%03d" % yaw
			if not _rows[role].has(tag):
				continue
			var row: Dictionary = _rows[role][tag]
			var bound := ew
			if yaw == 90:
				bound = ed
			elif yaw != 0:
				bound = sqrt(ew * ew + ed * ed)
			var over_w := float(row["px_w"]) / per_metre - bound
			var over_h := float(row["px_h"]) / per_metre - eh
			row["bound_w_m"] = snappedf(bound, 0.001)
			row["overflow_w_m"] = snappedf(over_w, 0.001)
			row["overflow_h_m"] = snappedf(over_h, 0.001)
			if over_w > worst_w:
				worst_w = over_w
				worst_at = yaw
			worst_h = maxf(worst_h, over_h)
		_rows[role]["envelope_w_h_d_m"] = env
		_rows[role]["worst_overflow_w_m"] = snappedf(worst_w, 0.001)
		_rows[role]["worst_overflow_w_yaw"] = worst_at
		_rows[role]["worst_overflow_h_m"] = snappedf(worst_h, 0.001)
		# One pixel of slack: the mask is whole pixels and the envelope
		# is a real number, so an exact fit lands within a pixel either
		# way.
		var slack := 1.0 / per_metre
		if worst_w > slack or worst_h > slack:
			print("[enemysil] OVERFLOW %-10s %.3f m wide at yaw %d, "
				  % [role, worst_w, worst_at]
				  + "%.3f m tall -- outside the volume that can be hit"
				  % worst_h)
	# The lineup frames and every VALUE measurement moved to
	# `enemy_contrast.gd` on 2026-09-25. This file measured contrast for
	# a while, and it did it wrong twice over: under the wrong light (the
	# docstring said "one lamp at the theme's own colour and energy" and
	# the code lit all six themes with concrete_facility's), and with an
	# L* that summed the viewport's sRGB-ENCODED channels as if they were
	# linear light -- which read #777777 as 0.740 instead of 0.500. Every
	# value this file ever reported, Track B's "0.067 L*" included, is on
	# that wrong scale. The new harness calibrates itself against known
	# greys before it measures anything.
	_finish()


func _finish() -> void:
	_rows["_meta"] = {"distance_m": _distance, "fov_deg": _fov,
		"budget_px": _budget_px, "shot": [SHOT.x, SHOT.y],
		"engine": Engine.get_version_info()["string"]}
	_rows["_faults"] = _faults
	var fh := FileAccess.open("%s/silhouettes.json" % _out, FileAccess.WRITE)
	fh.store_string(JSON.stringify(_rows, "\t", true, true))
	fh.close()
	if _faults.is_empty():
		print("[enemysil] %d role(s) measured at %.0f m"
			  % [ROLES.size(), _distance])
	else:
		push_error("[enemysil] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
