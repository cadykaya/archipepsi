extends SceneTree
## The deck tread, before and after, on real geometry at standing height.
##
##   godot --path godot -s _harness/fc.gd -- <trial> <beforePNG> <out>
##
## A texture preview is not the test. The floor is a Y-thin face whose UVs
## put U along +X and V along +Z at 32 texels/m each, so the pattern arrives
## unrotated and undistorted -- but what a player sees is that pattern at a
## grazing angle from 1.7 m, mipmapped, under the study's own light. This
## renders exactly that, twice, changing ONE texture between them.
##
## Everything else is held: the corrected wall rotation, the trim rescale,
## the lighting rig and the decals are all as they were.

const SHELL := "res://content/shells/shell_corner_left.tscn"
const PREFIX := "cl"
const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]

var _trial: String
var _before: String
var _out: String
var _cache := {}

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_trial = a[0]; _before = a[1]; _out = a[2]
	_run.call_deferred()

func _role_of(name: String) -> String:
	var stem := name
	var dot := stem.rfind(".")
	if dot > 0 and stem.substr(dot + 1).is_valid_int():
		stem = stem.substr(0, dot)
	if not stem.begins_with(PREFIX + "_"):
		return ""
	var tail := stem.substr(PREFIX.length() + 1)
	return tail if tail in ROLES else ""

func _path_for(role: String, old_floor: bool) -> String:
	if role == "floor":
		return _before if old_floor else "%s/derelict_floor.png" % _trial
	match role:
		"wall", "ceiling": return "%s/derelict_wall.png" % _trial
		"trim": return "%s/derelict_trim.png" % _trial
		"accent": return "%s/derelict_accent.png" % _trial
	return ""

func _material(role: String, rotate: bool, old_floor: bool) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [role, str(rotate), str(old_floor)]
	if _cache.has(key):
		return _cache[key]
	var img := Image.load_from_file(_path_for(role, old_floor))
	if rotate:
		img.rotate_90(CLOCKWISE)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	if role == "trim":
		mat.uv1_scale = Vector3(1.0, 4.0, 1.0)
	mat.resource_name = "deep_space_derelict/%s" % role
	_cache[key] = mat
	return mat

func _thin_axis(mesh: Mesh, surface: int) -> int:
	var verts: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return -1
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var ext := hi - lo
	if ext.x <= ext.y and ext.x <= ext.z:
		return 0
	return 1 if ext.y <= ext.z else 2

func _bind(root: Node, old_floor: bool) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var role := _role_of("" if src == null else src.resource_name)
			if role == "":
				continue
			var rotate := (role == "wall" or role == "ceiling") \
					and _thin_axis(mi.mesh, i) == 0
			mi.set_surface_override_material(i,
					_material(role, rotate, old_floor))

const FIXTURES := [
	[Vector3(0.0, 3.35, 2.6), Color(0.78, 0.86, 0.90), 1.7, 7.0],
	[Vector3(-0.4, 3.35, 5.1), Color(0.62, 0.72, 0.80), 0.65, 4.2],
	[Vector3(-2.5, 1.15, 3.4), Color(0.80, 0.85, 0.86), 0.55, 2.8],
	[Vector3(1.2, 2.45, 5.85), Color(0.33, 0.67, 0.76), 0.40, 1.8],
]

func _lights(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "PREVIEW_LIGHTING_NOT_SHIPPED"
	root.add_child(holder)
	for raw: Variant in FIXTURES:
		var f: Array = raw
		var lamp := OmniLight3D.new()
		lamp.light_color = f[1]
		lamp.light_energy = f[2]
		lamp.omni_range = f[3]
		lamp.shadow_enabled = true
		holder.add_child(lamp)
		lamp.global_position = root.global_position + f[0] + Vector3(0, -0.12, 0)

func _run() -> void:
	var packed := load(SHELL) as PackedScene
	var world := Node3D.new()
	get_root().add_child(world)
	var a := packed.instantiate(); a.name = "BEFORE"
	var b := packed.instantiate(); b.name = "AFTER"
	a.position = Vector3(-40, 0, 0)
	world.add_child(a); world.add_child(b)
	_bind(a, true)
	_bind(b, false)
	_lights(a)
	_lights(b)
	var shots := [
		{"n": "stand", "at": Vector3(1.5, 1.7, 5.2), "to": Vector3(-1.2, 0.15, 1.0)},
		{"n": "feet", "at": Vector3(0.4, 1.7, 3.6), "to": Vector3(-0.4, 0.0, 2.2)},
	]
	for raw: Variant in shots:
		var s: Dictionary = raw
		var at: Vector3 = s["at"]
		var to: Vector3 = s["to"]
		await _shot(world, at + Vector3(-40, 0, 0), to + Vector3(-40, 0, 0),
				"FLOOR_%s_before" % s["n"])
		await _shot(world, at, to, "FLOOR_%s_after" % s["n"])
	quit(0)

func _shot(world: Node3D, at: Vector3, look: Vector3, name: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var holder := Node3D.new()
	vp.add_child(holder)
	var cam := Camera3D.new()
	cam.fov = 70.0
	holder.add_child(cam)
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.012, 0.016, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.66, 0.75, 0.80)
	e.ambient_light_energy = 0.13
	env.environment = e
	holder.add_child(env)
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[floor] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()
