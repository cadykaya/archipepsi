class_name ArtBench
extends RefCounted
## Shared rig for every art review render.
##
## ## What this bench measures, stated before anything believes it
##
## It loads a .glb from an ABSOLUTE filesystem path with GLTFDocument at
## runtime, puts it in a SubViewport under a fixed light rig, and reads
## pixels back. That is not the same code path as Godot's editor import, so:
##
##   * It DOES prove the mesh, its scale, its UV layout, its materials and
##     what the thing looks like under the game's own camera.
##   * It does NOT prove that the editor's .glb importer will preserve
##     NEAREST filtering when engineering wires these into the real project.
##     `report_filters()` states what the runtime path produced; the editor
##     path is an open question and ART_FRONTIER.md says so.
##
## ## And what it cannot do
##
## This sandbox only initialises the Compatibility renderer, so every
## capture is a LOWER BOUND on the owner's Forward+ build. When something
## looks flatter than the art bible promises, that is a candidate
## explanation and never the first one to reach for.

const BG := Color(0.055, 0.055, 0.065)

## Load a .glb from an absolute path. Returns null and prints on failure --
## a silent null here would make every downstream shot black and readable as
## an art problem.
static func load_glb(absolute_path: String) -> Node3D:
	if not FileAccess.file_exists(absolute_path):
		push_error("[bench] no such model: %s" % absolute_path)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.base_path = absolute_path.get_base_dir()
	var err := doc.append_from_file(absolute_path, state)
	if err != OK:
		push_error("[bench] GLTF load failed (%d): %s" % [err, absolute_path])
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		push_error("[bench] GLTF produced no scene: %s" % absolute_path)
		return null
	return scene

## Every StandardMaterial3D in the tree, so filtering can be reported and
## enforced rather than hoped for.
static func materials(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh: Mesh = child.mesh
			if mesh:
				for i in mesh.get_surface_count():
					var mat := mesh.surface_get_material(i)
					if mat:
						found.append(mat)
			if child.material_override:
				found.append(child.material_override)
		found.append_array(materials(child))
	return found

static func force_nearest(node: Node) -> Dictionary:
	## Returns {before: {filter_name: count}, forced: n}.
	var before: Dictionary = {}
	var forced := 0
	for mat in materials(node):
		if mat is BaseMaterial3D:
			var key := str(mat.texture_filter)
			before[key] = int(before.get(key, 0)) + 1
			if mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				forced += 1
	return {"before": before, "forced": forced}

static func aabb_of(node: Node) -> AABB:
	var box := AABB()
	var seen := false
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_box: AABB = child.get_aabb()
			mesh_box = child.transform * mesh_box
			box = mesh_box if not seen else box.merge(mesh_box)
			seen = true
		var sub := aabb_of(child)
		if sub.size != Vector3.ZERO:
			box = sub if not seen else box.merge(sub)
			seen = true
	return box

static func make_viewport(tree: SceneTree, size: Vector2i,
		ambient: float = 0.42) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	tree.root.add_child(vp)

	var env := WorldEnvironment.new()
	# Named explicitly: a code-created node gets an "@WorldEnvironment@2"
	# style name, so looking it up by class name silently fails.
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.74)
	e.ambient_light_energy = ambient
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 2.0
	# SSAO off, glow off. Contact darkening and bloom are the physical cues a
	# 1998 look does not have, and a review that adds them is reviewing a
	# different game.
	e.ssao_enabled = false
	e.glow_enabled = false
	env.environment = e
	vp.add_child(env)
	return vp

## The standard three-light rig. Deliberately harsh and simple: DESIGN 3.4
## asks for "harsh simple lighting", so the bench does not soften anything.
## Key well above fill so facets read; the rim is what carries silhouette.
static func add_lights(parent: Node, key_energy: float = 1.5) -> void:
	var key := DirectionalLight3D.new()
	key.light_energy = key_energy
	key.light_color = Color(1.0, 0.97, 0.92)
	key.rotation_degrees = Vector3(-38, -42, 0)
	key.shadow_enabled = true
	parent.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_energy = key_energy * 0.30
	fill.light_color = Color(0.72, 0.80, 0.95)
	fill.rotation_degrees = Vector3(-18, 128, 0)
	parent.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.light_energy = key_energy * 0.42
	rim.light_color = Color(0.86, 0.92, 1.0)
	rim.rotation_degrees = Vector3(-6, 196, 0)
	parent.add_child(rim)

static func flat_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

static func clay_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.60, 0.58)
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat

static func apply_override(node: Node, mat: Material) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = mat
		apply_override(child, mat)

## Place a camera to frame `box` at `yaw` degrees, with `margin` headroom.
static func frame_camera(cam: Camera3D, box: AABB, yaw: float,
		elevation: float, margin: float, fov: float) -> void:
	cam.fov = fov
	var centre := box.get_center()
	var radius: float = maxf(0.25, box.size.length() * 0.5)
	var distance: float = radius * margin / tan(deg_to_rad(fov) * 0.5)
	var yr := deg_to_rad(yaw)
	var er := deg_to_rad(elevation)
	var offset := Vector3(
		sin(yr) * cos(er), sin(er), cos(yr) * cos(er)) * distance
	cam.position = centre + offset
	cam.look_at_from_position(centre + offset, centre, Vector3.UP)

## Vertical screen pixels the subject occupies, measured off the RENDER
## rather than projected from an AABB. mario-3 spent a whole session
## believing a projected bounding box; it reported an identical number for
## five different poses because it was measuring the one thing that cannot
## move.
static func measured_height_px(image: Image) -> int:
	var top := -1
	var bottom := -1
	for y in image.get_height():
		var hit := false
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - BG.r) > 0.02 or absf(pixel.g - BG.g) > 0.02 \
					or absf(pixel.b - BG.b) > 0.02:
				hit = true
				break
		if hit:
			if top < 0:
				top = y
			bottom = y
	if top < 0:
		return 0
	return bottom - top + 1

static func label(image: Image, text: String, at: Vector2i,
		colour: Color) -> void:
	## 3x5 stencil, drawn 2x, matching tools/blender/paintkit.py's alphabet so
	## a sheet and a texture speak in the same letters.
	var glyphs := _glyphs()
	var cursor := at.x
	for i in text.length():
		var ch := text.substr(i, 1).to_upper()
		if not glyphs.has(ch):
			cursor += 8
			continue
		var rows: Array = glyphs[ch]
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row.substr(c, 1) == "#":
					for dy in 2:
						for dx in 2:
							var px := cursor + c * 2 + dx
							var py := at.y + r * 2 + dy
							if px >= 0 and py >= 0 and px < image.get_width() \
									and py < image.get_height():
								image.set_pixel(px, py, colour)
		cursor += 8

static func _glyphs() -> Dictionary:
	return {
		"A": ["###", "# #", "###", "# #", "# #"],
		"B": ["## ", "# #", "## ", "# #", "## "],
		"C": ["###", "#  ", "#  ", "#  ", "###"],
		"D": ["## ", "# #", "# #", "# #", "## "],
		"E": ["###", "#  ", "## ", "#  ", "###"],
		"F": ["###", "#  ", "## ", "#  ", "#  "],
		"G": ["###", "#  ", "# #", "# #", "###"],
		"H": ["# #", "# #", "###", "# #", "# #"],
		"I": ["###", " # ", " # ", " # ", "###"],
		"J": ["  #", "  #", "  #", "# #", "###"],
		"K": ["# #", "# #", "## ", "# #", "# #"],
		"L": ["#  ", "#  ", "#  ", "#  ", "###"],
		"M": ["# #", "###", "###", "# #", "# #"],
		"N": ["# #", "###", "###", "###", "# #"],
		"O": ["###", "# #", "# #", "# #", "###"],
		"P": ["###", "# #", "###", "#  ", "#  "],
		"Q": ["###", "# #", "# #", "###", "  #"],
		"R": ["###", "# #", "###", "## ", "# #"],
		"S": ["###", "#  ", "###", "  #", "###"],
		"T": ["###", " # ", " # ", " # ", " # "],
		"U": ["# #", "# #", "# #", "# #", "###"],
		"V": ["# #", "# #", "# #", "# #", " # "],
		"W": ["# #", "# #", "###", "###", "# #"],
		"X": ["# #", "# #", " # ", "# #", "# #"],
		"Y": ["# #", "# #", "###", " # ", " # "],
		"Z": ["###", "  #", " # ", "#  ", "###"],
		"0": ["###", "# #", "# #", "# #", "###"],
		"1": [" # ", "## ", " # ", " # ", "###"],
		"2": ["###", "  #", "###", "#  ", "###"],
		"3": ["###", "  #", "###", "  #", "###"],
		"4": ["# #", "# #", "###", "  #", "  #"],
		"5": ["###", "#  ", "###", "  #", "###"],
		"6": ["###", "#  ", "###", "# #", "###"],
		"7": ["###", "  #", "  #", "  #", "  #"],
		"8": ["###", "# #", "###", "# #", "###"],
		"9": ["###", "# #", "###", "  #", "###"],
		".": ["   ", "   ", "   ", "   ", "#  "],
		"-": ["   ", "   ", "###", "   ", "   "],
		"/": ["  #", "  #", " # ", "#  ", "#  "],
		" ": ["   ", "   ", "   ", "   ", "   "],
	}
