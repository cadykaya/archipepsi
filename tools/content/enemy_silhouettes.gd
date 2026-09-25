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
## Two passes per role. A LIT pass under the room's own light -- one
## lamp at the theme's own colour and energy, no rig -- which is the
## evidence. And a SILHOUETTE pass, flat black on transparent, which is
## the measurement: the outline alone, with hue and material taken away
## so they cannot do the work that shape is supposed to do.

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
var _min_value := 0.10
var _min_interactable := 0.18
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
	_min_value = float(budgets["min_value_separation"])
	_min_interactable = float(budgets["min_interactable_separation"])
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
	model.rotation = Vector3(0.0, deg_to_rad(float(yaw)), 0.0)
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
	await _lineup()
	_finish()


func _lineup() -> void:
	## The evidence frame: all ten at the review distance, under the
	## ROOM'S light -- one lamp at the theme's own colour and energy, no
	## rig. `02` PT-10 asks for the lineup judged without studio
	## lighting, and a three-point rig is exactly the thing that makes a
	## silhouette look resolved when it is not.
	var view := _viewport(false)
	_camera(view)
	var holder := Node3D.new()
	view.add_child(holder)
	_room(holder)
	var x := 0.0
	var placed := 0
	var widths := []
	for role in ROLES:
		var model: Node3D = _bench.call("load_glb",
				"%s/enemy_role_%s.glb" % [_models, role])
		if model == null:
			continue
		holder.add_child(model)
		var box: AABB = _bench.call("aabb_of", model)
		widths.append(box.size.x)
		x += box.size.x * 0.5
		model.position = Vector3(x - box.get_center().x,
				-box.position.y - 1.0, -_distance)
		x += box.size.x * 0.5 + 0.55
		placed += 1
	if placed == 0:
		_bad("the lineup placed nothing")
		return
	# Centre the row on the camera.
	holder.position = Vector3(-x * 0.5, 0.0, 0.0)

	var env := (view.get_node_or_null("WorldEnvironment") as WorldEnvironment)
	if env != null:
		env.environment.ambient_light_color = Color("eaf2ff")
		env.environment.ambient_light_energy = 0.75
	var lamp := OmniLight3D.new()
	# concrete_facility's own light, from the palette's engine anchors.
	lamp.light_color = Color("eaf2ff")
	lamp.light_energy = 3.0
	lamp.omni_range = 70.0
	lamp.position = Vector3(0.0, 5.5, -_distance + 5.0)
	view.add_child(lamp)

	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	# FREE IT BEFORE BUILDING THE NEXT ONE. Two SubViewports alive at
	# once, both UPDATE_ALWAYS, and `get_texture()` on the second came
	# back with the FIRST one's picture -- the region masks were the lit
	# room, so every role measured the same 1.56 million pixels and
	# reported an identical L* to three decimals. Ten different models
	# cannot do that, which is the only reason it was caught.
	view.queue_free()
	await process_frame

	# --- how far does the family sit from the wall behind it? ---------
	#
	# The silhouette pass is the BEST case a shape will ever get: black
	# on nothing. This is the real one -- bodies against the wall they
	# stand in front of -- and "they look dark" is not a finding until
	# it is a number. The palette's own thresholds are the yardstick:
	# min_value_separation 0.10, min_interactable_separation 0.18, in
	# CIE L*.
	var regions := await _lineup_regions()
	var body := 0.0
	var body_n := 0
	var wall := 0.0
	var wall_n := 0
	# Per role, so the owner's prioritisation has something to sort by.
	# A family mean says the set is dim; it does not say which of them
	# to fix first.
	var per_role := {}
	for role in regions:
		var sum := 0.0
		var n := 0
		var region: Image = regions[role]
		for py in image.get_height():
			for px in image.get_width():
				if region.get_pixel(px, py).a > 0.5:
					sum += _lstar(image.get_pixel(px, py))
					n += 1
		# A GUARD FOR THE BUG THAT GOT THROUGH ONCE. An enemy 18 m away
		# occupies a few thousand pixels of a 1920x1080 frame. When the
		# region masks were silently the lit room instead, every role
		# "covered" 1,565,136 px -- three quarters of the screen -- and
		# every role reported an identical L* to three decimals. Ten
		# different models cannot do that, and nothing failed.
		var share := float(n) / float(image.get_width() * image.get_height())
		if share > 0.10:
			_bad("%s's region covers %.0f%% of the frame. That is not an "
				 % [role, share * 100.0]
				 + "enemy at %.0f m -- the mask is picking up the room, "
				 % _distance + "and every contrast number here is wrong")
		if n > 0:
			per_role[role] = {"lstar": snappedf(sum / float(n), 0.001),
				"px": n}
	for py in image.get_height():
		for px in image.get_width():
			var lit := image.get_pixel(px, py)
			var covered := false
			for role in regions:
				if regions[role].get_pixel(px, py).a > 0.5:
					covered = true
					break
			if covered:
				body += _lstar(lit)
				body_n += 1
			elif py > image.get_height() * 0.30 \
					and py < image.get_height() * 0.52:
				# A band of wall at the row's own height, so the
				# comparison is against what is actually behind them
				# rather than against the whole frame.
				wall += _lstar(lit)
				wall_n += 1
	if body_n > 0 and wall_n > 0:
		var bl := body / float(body_n)
		var wl := wall / float(wall_n)
		_rows["_contrast"] = {
			"body_lstar": snappedf(bl, 0.001),
			"wall_lstar": snappedf(wl, 0.001),
			"separation_lstar": snappedf(absf(bl - wl), 0.001),
			"body_px": body_n,
		}
		var sep := absf(bl - wl)
		_rows["_contrast"]["min_value_separation"] = _min_value
		_rows["_contrast"]["min_interactable_separation"] = _min_interactable
		_rows["_contrast"]["clears_value_rule"] = sep >= _min_value
		_rows["_contrast"]["clears_interactable_rule"] = \
				sep >= _min_interactable
		print("[enemysil] the family reads at L* %.3f against a wall at "
			  % bl + "%.3f -- %.3f apart" % [wl, sep])
		# REPORTED, not refused. This measures art that is already in the
		# tree, against a threshold the palette sets for a different
		# question; turning it into a gate here would be this lane
		# quietly imposing a rule nobody agreed to. The owner decides
		# what to do with the number.
		print("[enemysil]   min_value_separation %.2f: %s"
			  % [_min_value, "clears" if sep >= _min_value else "SHORT"])
		print("[enemysil]   min_interactable_separation %.2f: %s -- and an "
			  % [_min_interactable,
				 "clears" if sep >= _min_interactable else "SHORT"]
			  + "enemy is the most interactable thing in the room")
		# Worst first: that is the order the fixes want to be made in.
		var ranked := per_role.keys()
		ranked.sort_custom(func(a, b):
				return absf(float(per_role[a]["lstar"]) - wl) \
						< absf(float(per_role[b]["lstar"]) - wl))
		for role in ranked:
			var rl: float = float(per_role[role]["lstar"])
			var rsep := absf(rl - wl)
			per_role[role]["separation_lstar"] = snappedf(rsep, 0.001)
			per_role[role]["clears_interactable_rule"] = \
					rsep >= _min_interactable
			print("[enemysil]   %-10s L* %.3f, %.3f from the wall%s"
				  % [role, rl, rsep,
					 "" if rsep >= _min_interactable else "   SHORT"])
		_rows["_contrast"]["per_role"] = per_role

	_bench.call("label", image, "PROPOSAL -- NOT OWNER-APPROVED",
			Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, "TEN ROLES AT %.0f M -- THE AGGRO RADIUS. "
			% _distance + "ONE ROOM LAMP, NO RIG.", Vector2i(16, 36),
			Color(0.84, 0.86, 0.90))
	_bench.call("label", image, "NO AUDIO, NO CAPTIONS, NO COLLIDER "
			+ "OVERLAY. LEFT TO RIGHT: " + ", ".join(ROLES).to_upper(),
			Vector2i(16, 54), Color(0.66, 0.70, 0.76))
	if image.save_png("%s/LINEUP_at_%.0fm.png" % [_out, _distance]) != OK:
		_bad("could not write the lineup frame")
	print("[enemysil] lineup: %d role(s) at %.0f m under one room lamp"
		  % [placed, _distance])


## CIE L*, 0..1 -- the same measure `palette.py` uses, so a separation
## here means what a separation means everywhere else in this lane.
func _lstar(c: Color) -> float:
	var y := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var l := (116.0 * pow(y, 1.0 / 3.0) - 16.0) if y > 0.008856 \
			else (903.3 * y)
	return clampf(l / 100.0, 0.0, 1.0)


## The same ten bodies in the same places with no room and no light, one
## render per role with the others hidden, so every pixel is attributed
## to exactly one enemy. Rebuilt rather than taken from the lit frame by
## thresholding: that would be a guess at which dark pixels are a robot,
## and the darkness is the finding.
##
## Per role rather than colour-coded in one pass, because a colour read
## back through a viewport has been through sRGB and tone mapping, and
## decoding an index out of it is a guess wearing a number.
func _lineup_regions() -> Dictionary:
	var view := _viewport(true)
	_camera(view)
	var holder := Node3D.new()
	view.add_child(holder)
	var models := {}
	var x := 0.0
	for role in ROLES:
		var model: Node3D = _bench.call("load_glb",
				"%s/enemy_role_%s.glb" % [_models, role])
		if model == null:
			continue
		holder.add_child(model)
		var box: AABB = _bench.call("aabb_of", model)
		x += box.size.x * 0.5
		model.position = Vector3(x - box.get_center().x,
				-box.position.y - 1.0, -_distance)
		x += box.size.x * 0.5 + 0.55
		_flatten(model)
		models[role] = model
	holder.position = Vector3(-x * 0.5, 0.0, 0.0)

	var out := {}
	for role in models:
		for other in models:
			models[other].visible = other == role
		await process_frame
		await process_frame
		var got := view.get_texture().get_image()
		if OS.get_environment("ENEMYSIL_DEBUG") != "":
			got.save_png("%s/DEBUG_region_%s.png" % [_out, role])
		out[role] = got
	view.queue_free()
	return out


func _lineup_mask(_widths: Array) -> Image:
	var view := _viewport(true)
	_camera(view)
	var holder := Node3D.new()
	view.add_child(holder)
	var x := 0.0
	for role in ROLES:
		var model: Node3D = _bench.call("load_glb",
				"%s/enemy_role_%s.glb" % [_models, role])
		if model == null:
			continue
		holder.add_child(model)
		var box: AABB = _bench.call("aabb_of", model)
		x += box.size.x * 0.5
		model.position = Vector3(x - box.get_center().x,
				-box.position.y - 1.0, -_distance)
		x += box.size.x * 0.5 + 0.55
		_flatten(model)
	holder.position = Vector3(-x * 0.5, 0.0, 0.0)
	await process_frame
	await process_frame
	var out := view.get_texture().get_image()
	view.queue_free()
	return out


func _surface(path: String, size: Vector2, at: Vector3,
		rot: Vector3) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	var tex: Variant = load(path)
	if tex != null:
		mat.albedo_texture = tex
		# The binding contract: nearest, repeating. A room judged
		# through a filter the game does not use is a different room.
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.texture_repeat = true
		mat.uv1_scale = Vector3(size.x / 4.0, size.y / 4.0, 1.0)
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	return mi


func _room(holder: Node3D) -> void:
	## A floor and a back wall in the shipped theme, because a lineup
	## against a flat void is the EASIEST case a silhouette will ever
	## face and no player is ever shown one. `covers_m` is 4.0, so the
	## UV scale is metres over four.
	holder.add_child(_surface("res://content/theme/concrete_facility_floor.png",
			Vector2(80.0, 60.0), Vector3(0.0, -1.0, -_distance),
			Vector3.ZERO))
	holder.add_child(_surface("res://content/theme/concrete_facility_wall.png",
			Vector2(80.0, 16.0), Vector3(0.0, 7.0, -_distance - 7.0),
			Vector3(deg_to_rad(90.0), 0.0, 0.0)))


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
