extends SceneTree
## The SAME shipped shell, twice, in two themes. A compatibility proof.
##
##   godot --path godot -s _harness/two_themes.gd -- <assets> <out> 
##
## WHAT THIS IS. `shell_corner_left.tscn` is instantiated TWICE from the
## one shipped `.glb`. Each instance is bound to a different theme using
## PER-SURFACE OVERRIDES (`MeshInstance3D.set_surface_override_material`),
## which is what the authority draft's 8.5 requires and the only way two
## rooms of different themes can exist at once. No second `.glb` is built
## or exported; nothing on disk is written except the captures.
##
## WHAT THIS IS NOT. It is not a runtime binder and not Theme Pack
## infrastructure. It is a preview scene that demonstrates the mechanism
## is available on today's shipped assets.
##
## MATERIAL ASSIGNMENT FOLLOWS THE SEMANTIC ROLE, never the source image.
## The role is recovered from the imported material's `resource_name`
## through the same legacy mapping the Python inspector uses, and one
## material is reused for every surface of the same (theme, role) -- so
## two surfaces sharing a role share a material, and two surfaces sharing
## an IMAGE but not a role do not.
##
## THE ISOLATION EVIDENCE is collected before, between and after binding:
## the shared Mesh's own surface materials, their albedo textures and
## their resource ids are recorded each time, so a mutation of the shared
## resource would show as a changed id rather than as a subjective
## judgement about a picture.

const SHELL := "res://content/shells/shell_corner_left.tscn"
const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]
const PREFIX := "cl"

var _assets: String
var _out: String
var _log: Dictionary = {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_assets = args[0]
	_out = args[1]
	_run.call_deferred()

func _role_of(name: String) -> String:
	## `cl_floor.003` -> `floor`. Legacy names only; never a guess.
	var stem := name
	var dot := stem.rfind(".")
	if dot > 0 and stem.substr(dot + 1).is_valid_int():
		stem = stem.substr(0, dot)
	if not stem.begins_with(PREFIX + "_"):
		return ""
	var tail := stem.substr(PREFIX.length() + 1)
	return tail if ROLES.has(tail) else ""

func _theme_material(theme: String, role: String,
		cache: Dictionary) -> StandardMaterial3D:
	## One material per (theme, role). Reuse inside a theme is deliberate.
	var key := "%s|%s" % [theme, role]
	if cache.has(key):
		return cache[key]
	var path := "%s/textures/theme/%s_%s.png" % [_assets, theme, role]
	if not FileAccess.file_exists(path):
		path = "%s/textures/theme/%s_wall.png" % [_assets, theme]
	var img := Image.load_from_file(path)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.resource_name = "%s/%s" % [theme, role]
	cache[key] = mat
	return mat

func _mesh_of(root: Node) -> MeshInstance3D:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		return node
	return null

func _fingerprint(mi: MeshInstance3D) -> Array:
	## The SHARED mesh's own materials -- what must never change.
	var out: Array = []
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i)
		var tex := "" if mat == null else str(
			(mat as BaseMaterial3D).albedo_texture)
		out.append({"name": "" if mat == null else mat.resource_name,
					"material_id": "" if mat == null else str(mat),
					"albedo": tex})
	return out

func _bind(mi: MeshInstance3D, theme: String, cache: Dictionary) -> Array:
	var unresolved: Array = []
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i)
		var name := "" if mat == null else mat.resource_name
		var role := _role_of(name)
		if role == "":
			unresolved.append({"surface": i, "material": name,
							   "path": String(mi.get_path())})
			continue
		mi.set_surface_override_material(i, _theme_material(theme, role,
				cache))
	return unresolved

func _overrides(mi: MeshInstance3D) -> Array:
	var out: Array = []
	for i in mi.mesh.get_surface_count():
		var mat := mi.get_surface_override_material(i)
		out.append("" if mat == null else mat.resource_name)
	return out

func _structure(root: Node3D) -> Dictionary:
	## Collision, transforms and node shape -- must be identical.
	##
	## Transforms are taken RELATIVE TO THE INSTANCE ROOT, not in world
	## space. The two instances stand 18 m apart on purpose, so a global
	## transform would differ between them for a reason that has nothing
	## to do with theming, and a digest that always differs proves
	## nothing. Instance-local is the quantity 8.6 is actually about.
	var inv := root.global_transform.affine_inverse()
	var bodies := 0
	var shapes: Array = []
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		shapes.append({"path": String(root.get_path_to(cs)),
					   "xform": str(inv * cs.global_transform),
					   "shape": cs.shape.get_class(),
					   "points": (cs.shape as ConvexPolygonShape3D).points.size()
							if cs.shape is ConvexPolygonShape3D else -1})
	for _b in root.find_children("*", "StaticBody3D", true, false):
		bodies += 1
	return {"static_bodies": bodies, "collision_shapes": shapes.size(),
			"shapes": shapes, "nodes": root.find_children("*", "", true,
					false).size()}

func _run() -> void:
	var packed := load(SHELL) as PackedScene
	var world := Node3D.new()
	get_root().add_child(world)

	var a := packed.instantiate()
	var b := packed.instantiate()
	a.name = "A_concrete_facility"
	b.name = "B_rusted_industrial"
	a.position = Vector3(-9.0, 0.0, 0.0)
	b.position = Vector3(9.0, 0.0, 0.0)
	world.add_child(a)
	world.add_child(b)

	var ma := _mesh_of(a)
	var mb := _mesh_of(b)
	_log["shared_mesh_is_one_resource"] = ma.mesh == mb.mesh
	_log["mesh_resource_path"] = ma.mesh.resource_path
	_log["surfaces"] = ma.mesh.get_surface_count()
	_log["structure_A_before"] = _structure(a)
	_log["structure_B_before"] = _structure(b)
	var before := _fingerprint(ma)
	_log["shared_before"] = before

	var cache := {}
	_log["unresolved_A"] = _bind(ma, "concrete_facility", cache)
	_log["shared_after_A"] = _fingerprint(ma)
	_log["overrides_A_after_A"] = _overrides(ma)
	_log["overrides_B_after_A"] = _overrides(mb)

	_log["unresolved_B"] = _bind(mb, "rusted_industrial", cache)
	_log["shared_after_B"] = _fingerprint(ma)
	_log["overrides_A_after_B"] = _overrides(ma)
	_log["overrides_B_after_B"] = _overrides(mb)

	# Rebind A to a THIRD theme and prove B still does not move.
	_log["unresolved_A2"] = _bind(ma, "temple_ruin", cache)
	_log["overrides_A_after_rebind"] = _overrides(ma)
	_log["overrides_B_after_rebind"] = _overrides(mb)
	_log["shared_after_rebind"] = _fingerprint(ma)
	# ... then put A back, so the captures show the two themes asked for.
	_bind(ma, "concrete_facility", cache)

	# 8.6: a before/after structural digest, per instance, taken after
	# every bind and rebind above. Material application may not add,
	# delete, move or scale a collider, and this is where that is checked
	# rather than asserted.
	_log["structure_A_after"] = _structure(a)
	_log["structure_B_after"] = _structure(b)
	_log["structure_A_unchanged"] = (_log["structure_A_before"]
			== _log["structure_A_after"])
	_log["structure_B_unchanged"] = (_log["structure_B_before"]
			== _log["structure_B_after"])
	# And the two instances agree with each other once placement is out
	# of it, which is what makes them the same room in two themes.
	_log["structure_A_equals_B"] = (_log["structure_A_after"]
			== _log["structure_B_after"])
	_log["distinct_materials_built"] = cache.size()
	await _capture(world, a, b)
	var fh := FileAccess.open("%s/instance_isolation.json" % _out,
			FileAccess.WRITE)
	fh.store_string(JSON.stringify(_log, "  ", true))
	fh.close()
	print("[two] wrote %s/instance_isolation.json" % _out)
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
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = 0.55
	env.environment = e
	holder.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	holder.add_child(sun)
	sun.global_position = at + Vector3(0, 8, 0)
	sun.look_at(look, Vector3.UP)
	# The world lives under the tree root; re-parent for the capture only.
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[two] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()

func _capture(world: Node3D, a: Node, b: Node) -> void:
	# The two instances together: the evidence that they COEXIST.
	await _shot(world, Vector3(0, 6.0, 15.0), Vector3(0, 1.4, 3.0),
			Vector2i(1280, 720), "TWO_THEMES_pair")
	# And one interior each, from inside the corridor looking at the turn.
	# The shell's interior is 6 x 3.6 x 6 with its floor at y = 0 and z
	# running 0..6, so eye height 1.7 at z 5.2 stands in the mouth of it.
	await _shot(world, Vector3(-9.0, 1.7, 5.2), Vector3(-9.6, 1.5, 0.6),
			Vector2i(960, 720), "TWO_THEMES_A_concrete_facility")
	await _shot(world, Vector3(9.0, 1.7, 5.2), Vector3(8.4, 1.5, 0.6),
			Vector2i(960, 720), "TWO_THEMES_B_rusted_industrial")
