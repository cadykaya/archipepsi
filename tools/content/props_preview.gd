extends SceneTree
## The physics-prop family, in a room, against the props already in the
## catalogue.
##
##   godot --path godot -s _harness/props.gd -- <models> <out>
##
## PROPOSAL EVIDENCE. Four candidates, imported through GLTFDocument at
## runtime and photographed under the shipped light model. No collider is
## loaded, none exists, and nothing here is traversal or physics evidence.

const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]
const PREFIX := "cl"

var _models: String
var _derelict: String
var _out: String
var _bench: GDScript
var _ground := "bright"
var _labels := true

## How far below its body a handling fitting must measure IN THE RENDER,
## on the darkest ground it is shown on. §33.7 asks for a treatment a player
## can read; a number in the palette is not that, and the first pass had two
## of three objects with the fitting BRIGHTER than the body.
const MIN_HANDLING_GAP := 12.0

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_models = a[0]
	_derelict = a[1]
	_out = a[2]
	# Labels off for the material comparison. A caption tells the eye where
	# to look, which is the opposite of what a readability check wants.
	_labels = a.size() < 4 or a[3] != "nolabels"
	_bench = load("res://_harness/artbench.gd") as GDScript
	_run.call_deferred()

func _bind(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var nm := "" if src == null else str(src.resource_name)
			var stem := nm
			var dot := stem.rfind(".")
			if dot > 0 and stem.substr(dot + 1).is_valid_int():
				stem = stem.substr(0, dot)
			if not stem.begins_with(PREFIX + "_"):
				continue
			var role := stem.substr(PREFIX.length() + 1)
			if role not in ROLES:
				continue
			mi.set_surface_override_material(i, _surface(role))

func _surface(role: String) -> StandardMaterial3D:
	## The same two grounds the status kit is judged against: bright
	## concrete, and Batch 042's dark derelict. A handling fitting is a
	## VALUE statement -- dark steel against a painted body -- so it has to
	## be checked on a ground where the body itself is already dark.
	var mat := StandardMaterial3D.new()
	var img: Image = null
	if _ground == "dark":
		var d := {"floor": "derelict_floor", "wall": "derelict_wall",
				"ceiling": "derelict_wall", "trim": "derelict_trim",
				"accent": "derelict_accent", "hazard": "derelict_accent"}
		var f := "%s/%s.png" % [_derelict, d.get(role, "derelict_wall")]
		if FileAccess.file_exists(f):
			img = Image.load_from_file(f)
	if img == null:
		var tex := load("res://content/shells/shell_corner_left_room_concrete_facility_%s.png" % role) as Texture2D
		if tex != null:
			img = tex.get_image()
	if img != null:
		mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	return mat


func _scene() -> Node3D:
	var world := Node3D.new()
	get_root().add_child(world)
	var shell := (load("res://content/shells/shell_corner_left.tscn")
			as PackedScene).instantiate()
	world.add_child(shell)
	_bind(shell)
	for s: Variant in [[Vector3(-1.6, 2.7, 1.8), 1.6],
			[Vector3(1.6, 2.7, 4.2), 1.6]]:
		var f: Array = s
		var lamp := OmniLight3D.new()
		world.add_child(lamp)
		lamp.global_position = f[0]
		lamp.light_energy = f[1] if _ground == "bright" else f[1] * 0.9
		lamp.omni_range = 12.0
		lamp.shadow_enabled = false
		lamp.light_color = (Color(0.725, 0.812, 0.839) if _ground == "dark"
				else Color(0.918, 0.949, 1.0))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = (Color(0.66, 0.75, 0.80) if _ground == "dark"
			else Color(0.918, 0.949, 1.0))
	e.ambient_light_energy = 0.17 if _ground == "dark" else 0.36
	env.environment = e
	world.add_child(env)
	return world

func _put(w: Node3D, rel: String, at: Vector3, yaw: float) -> Node3D:
	var n: Node3D = _bench.call("load_glb", "%s/%s" % [_models, rel])
	if n == null:
		return null
	w.add_child(n)
	n.global_position = at
	n.rotate_y(deg_to_rad(yaw))
	return n

func _width_of(n: Node3D) -> float:
	var lo := 1e9
	var hi := -1e9
	for child in n.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.mesh.get_aabb()
		for i in 8:
			var p: Vector3 = mi.global_transform * box.get_endpoint(i)
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	return 0.0 if hi < lo else hi - lo


func _shot(w: Node3D, at: Vector3, look: Vector3, name: String,
		lines: Array, size := Vector2i(1240, 620),
		world_labels: Array = []) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var holder := Node3D.new()
	vp.add_child(holder)
	var cam := Camera3D.new()
	cam.fov = 58.0
	holder.add_child(cam)
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	var parent := w.get_parent()
	parent.remove_child(w)
	vp.add_child(w)
	# Labels anchored to a WORLD point are projected here rather than typed
	# as pixels. Hand-placed captions drift the moment anything moves, and a
	# caption beside the wrong object is worse than no caption -- this lane
	# has already shipped one of those.
	if _labels:
		for raw: Variant in world_labels:
			var wl: Array = raw
			var at_px := cam.unproject_position(wl[1])
			lines.append([wl[0], at_px + Vector2(-8, 0)])
	else:
		lines = []
	var layer := Control.new()
	layer.size = Vector2(size)
	vp.add_child(layer)
	for raw: Variant in lines:
		var l: Array = raw
		var plate := ColorRect.new()
		plate.color = Color(0.06, 0.07, 0.09, 0.76)
		plate.position = l[1]
		plate.size = Vector2(8.4 * str(l[0]).length() + 16, 24)
		layer.add_child(plate)
		var lab := Label.new()
		lab.text = l[0]
		lab.position = Vector2(l[1]) + Vector2(8, -1)
		lab.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
		lab.add_theme_font_size_override("font_size", 15)
		layer.add_child(lab)
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[props] %s.png" % name)
	vp.remove_child(w)
	parent.add_child(w)
	vp.queue_free()

func _clear(w: Node3D) -> void:
	w.get_parent().remove_child(w)
	w.queue_free()

func _run() -> void:
	if not _labels:
		# The material pass: three objects, both grounds, nothing written
		# over them.
		for ground: String in ["bright", "dark"]:
			_ground = ground
			await _skin_trio()
		quit(0)
		return
	for ground: String in ["bright", "dark"]:
		_ground = ground
		await _lineup()
		await _family()
		await _fixed()
	_ground = "bright"
	await _closeups()
	quit(0)


## Three rows, split at §10.3's 60 kg carry line and then by footprint.
## Eleven objects side by side is 8.5 m of row and the room is 6 m wide, so
## one row was never going to hold them -- and the version that tried put
## half the family inside the walls.
const ROWS := [
	{"z": 4.25, "band": "CARRIABLE -- 60 kg and under",
	 "ids": [["phys_key_component", "8"], ["phys_generic", "15"],
			 ["phys_power_cell", "40"], ["phys_mechanical_part", "55"]]},
	{"z": 2.85, "band": "MANIPULATE ONLY",
	 "ids": [["phys_plate", "60"], ["phys_drum", "70"],
			 ["phys_weighted", "140"]]},
	{"z": 1.45, "band": "",
	 "ids": [["phys_cart", "180"], ["phys_movable_cover", "220"],
			 ["phys_ballast", "320"], ["phys_anchor_block", "500 FIXED"]]},
]

## sRGB -> CIE L*, the perceptual value axis the palette's ramps are solved
## against. A channel average would flatter blues and punish yellows, which
## is the confound a value measurement exists to remove.
func _lstar(c: Color) -> float:
	var lin := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var y: float = (0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g)
			+ 0.0722 * lin.call(c.b))
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


func _paint(node: Node3D, body: Color, fitting: Color) -> void:
	## Key the two material roles into flat colours so a mask can be read
	## back. Which surface is which is not guessed: the fittings are the
	## named part nodes, and the body is the node the asset is named after.
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = (body if str(mi.name).begins_with("phys_")
				else fitting)
		mi.material_override = m


func _probe(w: Node3D, at: Vector3, look: Vector3, node: Node3D) -> Dictionary:
	## THE FAMILY RULE, MEASURED IN THE RENDER RATHER THAN IN THE PALETTE.
	##
	## "Unpainted dark steel, far below any painted body in value" is a claim
	## about what reaches the screen, and a material's albedo is not that: a
	## low-roughness fitting catches the room's own specular and can arrive
	## BRIGHTER than the body it is supposed to sit under. That is exactly
	## what happened at roughness 0.30 -- the pads read pale blue.
	##
	## So: render once normally, render again with the two material roles
	## keyed to flat colours, and use the second as a mask over the first.
	## No pixel coordinates are guessed and no surface is assumed.
	var size := Vector2i(900, 560)
	var shot := func(keyed: bool) -> Image:
		var vp := SubViewport.new()
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(vp)
		var holder := Node3D.new()
		vp.add_child(holder)
		var cam := Camera3D.new()
		cam.fov = 58.0
		holder.add_child(cam)
		cam.global_position = at
		cam.look_at(look, Vector3.UP)
		var parent := w.get_parent()
		parent.remove_child(w)
		vp.add_child(w)
		if keyed:
			_paint(node, Color(0, 1, 0), Color(1, 0, 1))
		await process_frame
		await process_frame
		await process_frame
		var img := vp.get_texture().get_image()
		vp.remove_child(w)
		parent.add_child(w)
		vp.queue_free()
		return img
	var lit: Image = await shot.call(false)
	var key: Image = await shot.call(true)
	var body_sum := 0.0
	var body_n := 0
	var fit_sum := 0.0
	var fit_n := 0
	for y in size.y:
		for x in size.x:
			var k := key.get_pixel(x, y)
			var v := _lstar(lit.get_pixel(x, y))
			if k.g > 0.85 and k.r < 0.2 and k.b < 0.2:
				body_sum += v
				body_n += 1
			elif k.r > 0.85 and k.b > 0.85 and k.g < 0.2:
				fit_sum += v
				fit_n += 1
	return {
		"body_px": body_n, "fitting_px": fit_n,
		"body_L": body_sum / maxf(body_n, 1.0),
		"fitting_L": fit_sum / maxf(fit_n, 1.0),
		"gap_L": (body_sum / maxf(body_n, 1.0)) - (fit_sum / maxf(fit_n, 1.0)),
	}


func _skin_trio() -> void:
	## The three the brief named, side by side, unlabelled, both grounds.
	var w := _scene()
	# The three the brief named lead the frame; the measurement below covers
	# all twelve, because a rule that holds on three objects and fails on
	# the ninth is not a rule.
	var ids := ["phys_power_cell", "phys_ballast", "phys_anchor_block"]
	var all_ids := ["phys_key_component", "phys_generic", "phys_power_cell",
			"phys_mechanical_part", "phys_plate", "phys_drum", "phys_girder",
			"phys_weighted", "phys_cart", "phys_movable_cover",
			"phys_ballast", "phys_anchor_block"]
	for i in ids.size():
		_put(w, "batch043/physics/%s.glb" % ids[i],
				Vector3(-1.35 + 1.35 * i, 0, 2.9), 18.0 + 26.0 * i)
	await _shot(w, Vector3(0.0, 1.30, 5.35), Vector3(0.0, 0.42, 2.9),
			"SKIN_trio_%s" % _ground, [], Vector2i(1120, 560))
	_clear(w)
	# And the measurement, one prop at a time so the masks cannot mix.
	var report := {}
	for id: String in all_ids:
		var w2 := _scene()
		var n := _put(w2, "batch043/physics/%s.glb" % id,
				Vector3(0, 0, 2.6), 24.0)
		if n == null:
			continue
		# Frame each object from its own size, so a 0.25 m component and a
		# 1.72 m cover are both read at the distance they fill the frame.
		var span: float = maxf(_width_of(n), 0.3)
		var back: float = clampf(1.05 + span * 1.6, 1.4, 3.4)
		var r: Dictionary = await _probe(w2,
				Vector3(0.0, 0.55 + span * 0.45, 2.6 + back),
				Vector3(0.0, span * 0.35, 2.6), n)
		report[id] = r
		print("[props] %-20s %s body L* %.1f  fitting L* %.1f  gap %.1f%s"
				% [id, _ground, r["body_L"], r["fitting_L"], r["gap_L"],
				   "" if r["gap_L"] >= MIN_HANDLING_GAP else "   << UNDER"])
		_clear(w2)
	var worst := 999.0
	for id: String in report:
		worst = minf(worst, report[id]["gap_L"])
	report["floor_L"] = MIN_HANDLING_GAP
	report["worst_gap_L"] = worst
	var f := FileAccess.open("%s/skin_contrast_%s.json" % [_out, _ground],
			FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	if worst < MIN_HANDLING_GAP:
		push_error("[props] handling contrast %.1f L* on %s, under the %.1f "
				% [worst, _ground, MIN_HANDLING_GAP]
				+ "floor. The family rule does not hold in the render.")


func _lineup() -> void:
	## All twelve classes. Eleven stand in three rows -- carriable nearest,
	## then manipulate by footprint -- and `GIRDER` lies across the front,
	## because it is 3.2 m long and standing it would say nothing about its
	## mass. Each object is placed by its MEASURED width and each label is
	## projected from the object's own position, so neither can drift.
	var w := _scene()
	var tags := []
	for raw: Variant in ROWS:
		var row: Dictionary = raw
		var loaded := []
		var total := 0.0
		var gap := 0.26
		for e: Variant in row["ids"]:
			var item: Array = e
			var n := _put(w, "batch043/physics/%s.glb" % item[0],
					Vector3(0, 0, row["z"]), 12.0)
			if n == null:
				continue
			var wide := _width_of(n)
			loaded.append({"node": n, "w": wide, "kg": item[1]})
			total += wide + gap
		var x := -(total - gap) / 2.0
		for raw2: Variant in loaded:
			var e: Dictionary = raw2
			var node: Node3D = e["node"]
			var half: float = e["w"] * 0.5
			node.global_position = Vector3(x + half, 0.0, row["z"])
			tags.append([e["kg"], Vector3(x + half, 0.03, row["z"] - 0.42)])
			x += e["w"] + gap
	_put(w, "batch043/physics/phys_girder.glb", Vector3(-0.10, 0, 5.05), 3.0)
	await _shot(w, Vector3(0.0, 2.55, 6.35), Vector3(-0.05, 0.35, 2.9),
			"PROPS_lineup_%s" % _ground,
			[["CARRIABLE -- under §10.3's 60 kg line", Vector2(40, 470)],
			 ["MANIPULATE ONLY -- no hand grip on any of them",
			  Vector2(40, 300)],
			 ["GIRDER 95 kg, 3.20 m", Vector2(470, 560)]],
			Vector2i(1240, 640), tags)
	_clear(w)


func _family() -> void:
	## THE CONTRADICTION THIS FRAME EXISTS TO SETTLE.
	##
	## The class map called `GENERIC` and `DRUM` manipulable candidates while
	## the comparison frame showed `prop_crate` and `prop_oil_drum` -- which
	## are decoration, painted end to end, with no fittings. Two different
	## promises about the same two classes.
	##
	## They are now separate candidates. `prop_crate` and `prop_oil_drum` are
	## unchanged and stay decoration; `phys_generic` and `phys_drum` are
	## their manipulable siblings. This frame puts each pair side by side so
	## the difference is the thing you look at rather than a claim.
	var w := _scene()
	var pairs := [
		["batch001/props/prop_crate.glb", "batch043/physics/phys_generic.glb"],
		["batch010/dressing/prop_oil_drum.glb", "batch043/physics/phys_drum.glb"],
	]
	for i in pairs.size():
		var p: Array = pairs[i]
		_put(w, p[0], Vector3(-1.95 + 2.9 * i, 0, 2.9), 16.0)
		_put(w, p[1], Vector3(-0.95 + 2.9 * i, 0, 2.9), -12.0)
	await _shot(w, Vector3(-0.05, 1.45, 5.6), Vector3(-0.05, 0.50, 2.9),
			"PROPS_candidate_vs_decorative_%s" % _ground,
			[["prop_crate", Vector2(150, 62)],
			 ["phys_generic", Vector2(420, 62)],
			 ["prop_oil_drum", Vector2(700, 62)],
			 ["phys_drum", Vector2(960, 62)],
			 ["DECORATION -- painted end to end, unchanged, still approved",
			  Vector2(62, 520)],
			 ["CANDIDATE -- the same class, carrying the handling language",
			  Vector2(62, 556)]])
	_clear(w)


func _fixed() -> void:
	## `ANCHOR_BLOCK` has to read as FIXED (§33.7: a `FIXED` object visibly
	## does not share the manipulable treatment). It has no grip and no push
	## pad -- nothing a device could take hold of to shift it -- one bare
	## tether eye on top, a spreading cast skirt, and a taper that is wider
	## at the floor than at the crown. Beside a 320 kg `BALLAST`, which has
	## four attach pads and is meant to move, the difference is the fittings.
	var w := _scene()
	_put(w, "batch043/physics/phys_anchor_block.glb", Vector3(-0.85, 0, 2.8), 18.0)
	_put(w, "batch043/physics/phys_ballast.glb", Vector3(0.95, 0, 2.8), -14.0)
	await _shot(w, Vector3(0.0, 1.30, 5.0), Vector3(0.0, 0.45, 2.8),
			"PROPS_fixed_vs_movable_%s" % _ground,
			[["ANCHOR_BLOCK 500 kg -- FIXED", Vector2(150, 62)],
			 ["BALLAST 320 kg -- manipulate", Vector2(760, 62)],
			 ["no grip, no push pad, one tether eye, cast into a skirt",
			  Vector2(62, 520)],
			 ["four attach pads, skids, and it is meant to move",
			  Vector2(640, 556)]])
	_clear(w)


func _closeups() -> void:
	## One frame each, at the distance a player decides whether to pick
	## something up. The handling feature is what has to read here.
	var jobs := [
		["phys_key_component", Vector3(0, 0, 2.4), 28.0, 0.78,
		 "KEY_COMPONENT 8 kg -- hand scale, and an asymmetric keyed bit"],
		["phys_generic", Vector3(0, 0, 2.4), 22.0, 0.92,
		 "GENERIC 15 kg -- recessed hand grips on two opposite faces"],
		["phys_plate", Vector3(0, 0, 2.4), 12.0, 0.85,
		 "PLATE 60 kg -- lifting slots, no grip: exactly on the carry line"],
		["phys_drum", Vector3(0, 0, 2.4), 18.0, 0.95,
		 "DRUM 70 kg -- end hubs on the rolling axis"],
		["phys_cart", Vector3(0, 0, 2.4), 24.0, 1.05,
		 "CART 180 kg -- fixed forks, a rail shoe, a push bar at one end"],
		["phys_movable_cover", Vector3(0, 0, 2.9), 16.0, 1.35,
		 "MOVABLE_COVER 220 kg -- taller than eye level, push faces both sides"],
		["phys_anchor_block", Vector3(0, 0, 2.4), 20.0, 0.95,
		 "ANCHOR_BLOCK 500 kg FIXED -- one tether eye and nothing to grab"],
		["phys_weighted", Vector3(0, 0, 2.4), -16.0, 1.05,
		 "WEIGHTED 140 kg -- two opposite push faces, NO hand grip"],
		["phys_power_cell", Vector3(0, 0, 2.4), 26.0, 1.05,
		 "POWER_CELL -- one hand grip on top, socket lugs underneath"],
		["phys_mechanical_part", Vector3(0, 0, 2.4), -32.0, 0.95,
		 "MECHANICAL_PART -- one hand grip, keyed face on the flange"],
		["phys_girder", Vector3(0, 0, 2.4), 74.0, 1.05,
		 "GIRDER -- end plates at both ends, NO hand grip"],
		["phys_ballast", Vector3(0, 0, 2.4), 18.0, 1.00,
		 "BALLAST -- four attach pads, skids, NO hand grip"],
	]
	for raw: Variant in jobs:
		var j: Array = raw
		var w := _scene()
		_put(w, "batch043/physics/%s.glb" % j[0], j[1], j[2])
		await _shot(w, Vector3(0.0, j[3], 3.55), Vector3(0.0, 0.40, 2.4),
				"PROPS_close_%s" % j[0], [[j[4], Vector2(60, 40)]],
				Vector2i(900, 620))
		_clear(w)
