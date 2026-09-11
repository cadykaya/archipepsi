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
var _out: String
var _bench: GDScript

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_models = a[0]
	_out = a[1]
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
			var mat := StandardMaterial3D.new()
			var tex := load("res://content/shells/shell_corner_left_room_concrete_facility_%s.png" % role) as Texture2D
			if tex != null:
				mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			mat.roughness = 0.9
			mi.set_surface_override_material(i, mat)

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
		lamp.light_energy = f[1]
		lamp.omni_range = 12.0
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.918, 0.949, 1.0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.918, 0.949, 1.0)
	e.ambient_light_energy = 0.36
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

func _shot(w: Node3D, at: Vector3, look: Vector3, name: String,
		lines: Array, size := Vector2i(1240, 620)) -> void:
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
	await _lineup()
	await _family()
	await _closeups()
	quit(0)

func _lineup() -> void:
	## The four candidates together, at one scale, on one floor. A class
	## family has to be readable as a family before any one of it is judged.
	var w := _scene()
	_put(w, "batch043/physics/phys_power_cell.glb", Vector3(-1.95, 0, 2.6), 18.0)
	_put(w, "batch043/physics/phys_mechanical_part.glb", Vector3(-0.95, 0, 2.6), -24.0)
	_put(w, "batch043/physics/phys_ballast.glb", Vector3(0.65, 0, 2.6), 12.0)
	_put(w, "batch043/physics/phys_girder.glb", Vector3(-0.10, 0, 4.15), 6.0)
	await _shot(w, Vector3(0.0, 1.42, 5.8), Vector3(-0.2, 0.50, 2.7),
			"PROPS_lineup",
			[["POWER_CELL 40 kg carriable", Vector2(60, 470)],
			 ["MECHANICAL_PART 55 kg carriable", Vector2(370, 470)],
			 ["BALLAST 320 kg manipulate", Vector2(770, 470)],
			 ["GIRDER 95 kg manipulate -- 3.20 m", Vector2(400, 520)]])
	_clear(w)

func _family() -> void:
	## The rule, tested. Left: four candidates, every one of which carries
	## bare machined metal where a device grips it. Right: three props
	## already in the catalogue, none of which does, and none of which is
	## manipulable. The claim is that a player can tell those two groups
	## apart at a glance, and this is the frame that has to carry it.
	var w := _scene()
	_put(w, "batch043/physics/phys_power_cell.glb", Vector3(-2.15, 0, 3.2), 22.0)
	_put(w, "batch043/physics/phys_mechanical_part.glb", Vector3(-1.25, 0, 3.2), -18.0)
	_put(w, "batch043/physics/phys_ballast.glb", Vector3(-0.1, 0, 3.2), 10.0)
	_put(w, "batch001/props/prop_crate.glb", Vector3(1.15, 0, 3.2), 14.0)
	_put(w, "batch010/dressing/prop_oil_drum.glb", Vector3(1.95, 0, 3.2), 0.0)
	_put(w, "batch001/props/prop_debris.glb", Vector3(2.65, 0, 3.2), -30.0)
	await _shot(w, Vector3(-0.05, 1.30, 5.75), Vector3(-0.05, 0.50, 3.2),
			"PROPS_manipulable_vs_decorative",
			[["MANIPULABLE -- bare metal where the device grips",
			  Vector2(60, 46)],
			 ["DECORATIVE -- painted end to end", Vector2(760, 46)]])
	_clear(w)

func _closeups() -> void:
	## One frame each, at the distance a player decides whether to pick
	## something up. The handling feature is what has to read here.
	var jobs := [
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
