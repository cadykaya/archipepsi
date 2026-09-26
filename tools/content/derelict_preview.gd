extends SceneTree
## deep_space_derelict on real geometry, beside concrete_facility.
##
##   godot --path godot -s _harness/derelict.gd -- <assets> <trial> <out>
##
## THREE INSTANCES of the SAME approved scene, 40 m apart:
##   A  concrete_facility, clean      -- the baseline
##   B  deep_space_derelict, clean    -- the theme alone
##   C  deep_space_derelict, dressed  -- plus a restrained decal placement
##
## Per-surface overrides only. Nothing is rebuilt, nothing exported, no
## manifest or review state touched, and the theme is bound to no runtime.
##
## WHAT IS PROVED HERE RATHER THAN ASSERTED. The imported mesh's own
## materials are fingerprinted before any binding and again after all of it,
## and the collision structure is digested the same way -- transforms taken
## relative to each instance root, because the three stand 40 m apart and a
## world-space digest would differ for a reason that has nothing to do with
## theming.
##
## NO GEOMETRY IS ADDED TO CARRY A ROLE. The structural trim binds to the
## `trim` role on the kick rail the shell already has; Batch 041 established
## that laying a card over it is two skirtings. Cards carry only decals,
## which have no geometry of their own.

const SHELL := "res://content/shells/shell_corner_left.tscn"
const PREFIX := "cl"
const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]
const LIFT := 0.006

var _assets: String
var _trial: String
var _out: String
var _cache := {}
var _log := {}

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_assets = a[0]; _trial = a[1]; _out = a[2]
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

func _texture_for(theme: String, role: String) -> String:
	if theme == "concrete_facility":
		return "%s/textures/theme/concrete_facility_%s.png" % [_assets, role]
	# deep_space_derelict. `ceiling` has no authored field in this batch and
	# falls back to `wall`, which is the authority draft's own 8.2 rule --
	# recorded here rather than quietly resolved.
	match role:
		"wall", "ceiling": return "%s/derelict_wall.png" % _trial
		"floor": return "%s/derelict_floor.png" % _trial
		"trim": return "%s/derelict_trim.png" % _trial
		"accent": return "%s/derelict_accent.png" % _trial
	return ""

func _material(theme: String, role: String) -> StandardMaterial3D:
	var key := "%s|%s" % [theme, role]
	if _cache.has(key):
		return _cache[key]
	var path := _texture_for(theme, role)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(
			Image.load_from_file(path))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.resource_name = "%s/%s" % [theme, role]
	_cache[key] = mat
	return mat

func _bind(root: Node, theme: String) -> Array:
	var unresolved: Array = []
	var fell_back: Array = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var name := "" if src == null else src.resource_name
			var role := _role_of(name)
			if role == "":
				unresolved.append({"surface": i, "material": name,
						"path": String(mi.get_path())})
				continue
			if theme != "concrete_facility" and role == "ceiling":
				fell_back.append(name)
			mi.set_surface_override_material(i, _material(theme, role))
	return [unresolved, fell_back]

func _fingerprint(root: Node) -> Array:
	## The SHARED mesh's own materials -- what per-surface overrides must
	## never touch.
	var out: Array = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			out.append({"name": "" if m == null else m.resource_name,
					"id": "" if m == null else str(m),
					"albedo": "" if m == null else str(
							(m as BaseMaterial3D).albedo_texture)})
	return out

func _structure(root: Node3D) -> Dictionary:
	var inv := root.global_transform.affine_inverse()
	var shapes: Array = []
	var bodies := 0
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
			"shapes": shapes,
			"mesh_instances": root.find_children("*", "MeshInstance3D",
					true, false).size(),
			"nodes": root.find_children("*", "", true, false).size()}

# -- one card helper; every placement goes through it ----------------------
func _card(parent: Node3D, texture: String, at: Vector3, normal: Vector3,
		metres: Vector2, spin_deg: float) -> void:
	var mesh := QuadMesh.new()
	mesh.size = metres
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(
			Image.load_from_file(texture))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	var n := normal.normalized()
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var x := up.cross(n).normalized()
	var y := n.cross(x).normalized()
	mi.global_transform = Transform3D(Basis(x, y, n), at + n * LIFT)
	if not is_zero_approx(spin_deg):
		mi.rotate_object_local(Vector3.BACK, deg_to_rad(spin_deg))

const WEST := -3.0
const NORTH := 6.0

func _dress(root: Node3D, neutral: String) -> int:
	## RESTRAINED, and placed where the structure says. The wall's welds are
	## at 2.0 m, so a coolant trail starts at one; a corroded seam lies ALONG
	## one. Nothing is placed over the doorway, over the floor boundary, or
	## anywhere a player needs to read an edge.
	# WEST WALL -- a bay whose cover is gone, its inspection mark beside it,
	# and coolant off the weld above.
	_card(root, "%s/decals/decal_panel_removed.png" % _trial,
			Vector3(WEST, 1.75, 2.2), Vector3.RIGHT, Vector2(0.75, 0.75), 0.0)
	_card(root, "%s/decals/decal_inspection.png" % _trial,
			Vector3(WEST, 1.75, 2.9), Vector3.RIGHT, Vector2(0.5, 0.25), 0.0)
	_card(root, "%s/decals/decal_coolant.png" % _trial,
			Vector3(WEST, 1.35, 4.4), Vector3.RIGHT, Vector2(0.5, 1.25), 0.0)
	# NORTH WALL -- corrosion along the 2.0 m weld, and reused grime low.
	_card(root, "%s/decals/decal_corroded_seam.png" % _trial,
			Vector3(-0.6, 2.0, NORTH), Vector3.FORWARD, Vector2(1.0, 0.25), 0.0)
	_card(root, "%s/decals/decal_grime.png" % neutral,
			Vector3(1.5, 0.75, NORTH), Vector3.FORWARD, Vector2(1.0, 1.0), 0.0)
	# FLOOR -- one reused scorch, clear of the doorway and the plate seams
	# a player uses to judge distance.
	_card(root, "%s/decals/decal_scorch.png" % neutral,
			Vector3(-1.1, 0.0, 3.9), Vector3.UP, Vector2(1.0, 1.0), 41.0)
	return 6

func _run() -> void:
	var packed := load(SHELL) as PackedScene
	var world := Node3D.new()
	get_root().add_child(world)
	var neutral := "%s/../glyph_layers_2026-09-10" % _trial

	var a := packed.instantiate(); a.name = "A_concrete"
	var b := packed.instantiate(); b.name = "B_derelict"
	var c := packed.instantiate(); c.name = "C_derelict_dressed"
	a.position = Vector3(-80.0, 0.0, 0.0)
	b.position = Vector3(-40.0, 0.0, 0.0)
	world.add_child(a); world.add_child(b); world.add_child(c)

	_log["shared_mesh_before"] = _fingerprint(b)
	_log["structure_before"] = _structure(b)

	var ra := _bind(a, "concrete_facility")
	var rb := _bind(b, "deep_space_derelict")
	var rc := _bind(c, "deep_space_derelict")
	var cards := _dress(c, neutral)

	_log["shared_mesh_after"] = _fingerprint(b)
	_log["structure_after"] = _structure(b)
	_log["structure_dressed"] = _structure(c)
	_log["unresolved"] = {"concrete": ra[0], "derelict": rb[0],
			"derelict_dressed": rc[0]}
	_log["ceiling_fell_back_to_wall"] = rb[1].size()
	_log["cards"] = cards
	_log["shared_mesh_unchanged"] = (_log["shared_mesh_before"]
			== _log["shared_mesh_after"])
	_log["collision_unchanged"] = (_log["structure_before"]
			== _log["structure_after"])
	# Dressing adds card MeshInstance3Ds and nothing else: same bodies, same
	# shapes, same transforms. That is what "cards carry no collision" means.
	_log["dressing_added_no_collision"] = (
			_log["structure_dressed"]["collision_shapes"]
			== _log["structure_after"]["collision_shapes"]
			and _log["structure_dressed"]["static_bodies"]
			== _log["structure_after"]["static_bodies"]
			and _log["structure_dressed"]["shapes"]
			== _log["structure_after"]["shapes"])
	_log["dressing_added_mesh_instances"] = (
			_log["structure_dressed"]["mesh_instances"]
			- _log["structure_after"]["mesh_instances"])
	print("[derelict] unresolved c=%d d=%d dd=%d | ceiling->wall %d | cards %d"
			% [ra[0].size(), rb[0].size(), rc[0].size(), rb[1].size(), cards])
	print("[derelict] shared mesh unchanged: %s | collision unchanged: %s | dressing added collision: %s"
			% [_log["shared_mesh_unchanged"], _log["collision_unchanged"],
			   not _log["dressing_added_no_collision"]])

	var shots := [
		{"n": "wide", "at": Vector3(0.9, 1.7, 5.4), "to": Vector3(-1.4, 1.3, 1.2)},
		{"n": "hierarchy", "at": Vector3(-0.2, 1.55, 4.6), "to": Vector3(-2.9, 1.0, 3.2)},
		{"n": "doorway", "at": Vector3(1.2, 1.7, 4.8), "to": Vector3(-0.2, 1.4, 0.4)},
	]
	for raw: Variant in shots:
		var s: Dictionary = raw
		var at: Vector3 = s["at"]
		var to: Vector3 = s["to"]
		# UNDER THE SHARED LIGHT. All three instances get concrete_facility's
		# own lamp, so any difference between them is the ART and not the
		# lighting -- which is the only way to answer "is this a darkened
		# concrete" honestly.
		await _shot(world, at + Vector3(-80, 0, 0), to + Vector3(-80, 0, 0),
				"GODOT_%s_concrete" % s["n"], SHARED_LIGHT)
		await _shot(world, at + Vector3(-40, 0, 0), to + Vector3(-40, 0, 0),
				"GODOT_%s_derelict" % s["n"], SHARED_LIGHT)
		await _shot(world, at, to, "GODOT_%s_dressed" % s["n"], SHARED_LIGHT)
	# AND UNDER THE THEME'S OWN PROPOSED LAMP, which is the second half of
	# the honest answer: the shared light proves the art differs, this one
	# shows what the theme is FOR. The value is a proposal in
	# derelict_palette.json and is bound into no runtime.
	for raw: Variant in shots:
		var s: Dictionary = raw
		await _shot(world, s["at"], s["to"],
				"GODOT_%s_dressed_themelight" % s["n"], THEME_LIGHT)
	var fh := FileAccess.open("%s/derelict_binding.json" % _out, FileAccess.WRITE)
	fh.store_string(JSON.stringify(_log, "  ", true))
	fh.close()
	print("[derelict] wrote derelict_binding.json")
	quit(0)

## The two lighting conditions, as {colour, energy, sun}.
const SHARED_LIGHT := {"colour": Color(0.918, 0.949, 1.0),
		"ambient": 0.55, "sun": 1.5, "bg": Color(0.06, 0.07, 0.09)}
## derelict_palette.json's `light_colour` proposal: #b9cfd6 at 2.2 against
## concrete_facility's #eaf2ff at 3.0. Cooler and dimmer, and the theme's
## readability does not depend on it -- which the shared-light shots show.
## FIRST TRY WAS NOT DARK ENOUGH. Cooling the lamp and taking a third off
## it still lit the room like a corridor somebody maintains. A station whose
## lighting is failing is mostly UNLIT -- the ambient does almost nothing and
## a single hard source picks out what it reaches, which is also what makes
## the accent indicators worth having.
const THEME_LIGHT := {"colour": Color(0.725, 0.812, 0.839),
		"ambient": 0.17, "sun": 0.55, "bg": Color(0.015, 0.02, 0.024)}

func _shot(world: Node3D, at: Vector3, look: Vector3, name: String,
		light: Dictionary) -> void:
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
	e.background_color = light["bg"]
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = light["colour"]
	e.ambient_light_energy = light["ambient"]
	env.environment = e
	holder.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = light["sun"]
	holder.add_child(sun)
	sun.global_position = at + Vector3(0, 8, 0)
	sun.look_at(look, Vector3.UP)
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[derelict] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()
