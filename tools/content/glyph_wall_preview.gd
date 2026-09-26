extends SceneTree
## The Glyph-authored wall on real room geometry, beside the shipped one.
##
##   godot --path godot -s _harness/glyph.gd -- <assets> <glyphPNG> <out>
##
## BATCH 041'S PATH, UNCHANGED. Two instances of `shell_corner_left`, themed
## `concrete_facility` by `set_surface_override_material` per surface. The
## only difference between them is which PNG the `wall` role resolves to:
## instance A takes the shipped `assets/textures/theme/`, instance B takes
## the Glyph trial texture. Nothing is rebuilt, nothing is exported, and the
## imported mesh is not touched.
##
## A texture judged on a flat sheet has not been judged. This is a corridor
## seen from standing height, which is where a wall is actually read.

const SHELL := "res://content/shells/shell_corner_left.tscn"
const THEME := "concrete_facility"
const PREFIX := "cl"

var _assets: String
var _glyph: String
var _out: String

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_assets = args[0]
	_glyph = args[1]
	_out = args[2]
	_run.call_deferred()

func _role_of(name: String) -> String:
	## `cl_wall.003` -> `wall`. Legacy names only; never a guess.
	var stem := name
	var dot := stem.rfind(".")
	if dot > 0 and stem.substr(dot + 1).is_valid_int():
		stem = stem.substr(0, dot)
	if not stem.begins_with(PREFIX + "_"):
		return ""
	var tail := stem.substr(PREFIX.length() + 1)
	if tail in ["floor", "wall", "ceiling", "trim", "accent", "hazard"]:
		return tail
	return ""

func _material(role: String, glyph_wall: bool,
		cache: Dictionary) -> StandardMaterial3D:
	var key := "%s|%s" % [role, str(glyph_wall)]
	if cache.has(key):
		return cache[key]
	var path := "%s/textures/theme/%s_%s.png" % [_assets, THEME, role]
	if glyph_wall and role == "wall":
		path = _glyph
	var img := Image.load_from_file(path)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.resource_name = "%s/%s%s" % [THEME, role, "@glyph" if glyph_wall
			and role == "wall" else ""]
	cache[key] = mat
	return mat

func _bind(root: Node, glyph_wall: bool, cache: Dictionary) -> int:
	var unresolved := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var role := _role_of("" if mat == null else mat.resource_name)
			if role == "":
				unresolved += 1
				continue
			mi.set_surface_override_material(i,
					_material(role, glyph_wall, cache))
	return unresolved

func _run() -> void:
	var packed := load(SHELL) as PackedScene
	var world := Node3D.new()
	get_root().add_child(world)
	var a := packed.instantiate()   # shipped wall
	var b := packed.instantiate()   # Glyph wall
	a.name = "A_shipped"
	b.name = "B_glyph"
	a.position = Vector3(-9.0, 0.0, 0.0)
	b.position = Vector3(9.0, 0.0, 0.0)
	world.add_child(a)
	world.add_child(b)

	var cache := {}
	var ua := _bind(a, false, cache)
	var ub := _bind(b, true, cache)
	print("[glyph] unresolved surfaces  shipped=%d  glyph=%d" % [ua, ub])

	# Eye height inside the corridor mouth: the shell's interior is
	# 6 x 3.6 x 6 with its floor at y = 0 and z running 0..6, so 1.7 m at
	# z 5.2 stands in the doorway looking at the turn.
	await _shot(world, Vector3(-9.0, 1.7, 5.2), Vector3(-9.6, 1.5, 0.6),
			Vector2i(960, 720), "GODOT_wall_shipped")
	await _shot(world, Vector3(9.0, 1.7, 5.2), Vector3(8.4, 1.5, 0.6),
			Vector2i(960, 720), "GODOT_wall_glyph")
	quit(0)

func _shot(world: Node3D, at: Vector3, look: Vector3, size: Vector2i,
		name: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
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
	e.background_color = Color(0.06, 0.07, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The theme's own light colour, so the wall is judged under the light
	# the room actually has rather than under a neutral studio lamp.
	e.ambient_light_color = Color(0.918, 0.949, 1.0)
	e.ambient_light_energy = 0.55
	env.environment = e
	holder.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	holder.add_child(sun)
	sun.global_position = at + Vector3(0, 8, 0)
	sun.look_at(look, Vector3.UP)
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[glyph] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()
