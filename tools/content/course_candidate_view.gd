extends SceneTree
## The course candidate, IN ENGINE, beside the shipped set at the same scale.
##
##   godot --path godot -s _harness/coursecand.gd -- <assets> <out>
##
## ## What this answers
##
## A 128 px tile covering 4 m breaks its course rhythm once per repeat when
## the pitch does not divide the tile. On a texture sheet that is an
## arithmetic claim about a number. On a wall it is either visible or it is
## not, and that is the only question the owner actually has to answer.
##
## So: one long wall per theme, 24 m of it, six repeats of the tile. The
## SHIPPED set on the upper strip, the CANDIDATE set on the lower strip,
## one camera, one light, one frame. Whatever the difference is, it is the
## textures -- nothing else differs between the two strips.
##
## And then the shipped `shell_corner_left` twice, same theme both times,
## shipped textures on one and candidate on the other, each shot from the
## same position relative to its own instance. That is the realistic case:
## a 6 m room where the tile repeats one and a half times.
##
## ## What this is NOT
##
## Not a runtime binder, not Theme Pack infrastructure, not a selection.
## `ThemeMaterials` is Production's consumer and stays Production's; this
## is an ISOLATED REVIEW SCENE, which is exactly what the owner said art
## may build while the pack-identity integration is pending. Nothing is
## written but the captures, and the candidate textures are read from
## `assets/textures/theme_candidate/` -- never imported, never bound at
## runtime, never approved.

const SHELL := "res://content/shells/shell_corner_left.tscn"
const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]
const PREFIX := "cl"
## 24 m of wall is six repeats of a 4 m tile: enough that a rhythm which
## stumbles once per tile stumbles six times in one frame.
const STRIP_M := 24.0
const TILE_M := 4.0
## The themes whose courses the snap actually moves, and what it moves.
const STRIPS := [
	{"theme": "concrete_facility", "role": "wall",
	 "note": "panel courses 1.2 m -> 1.0 m, seam grime 1.2 -> 1.0"},
	{"theme": "gothic_stone", "role": "accent",
	 "note": "masonry course 0.55 -> 0.5 m, block 1.1 -> 1.0 m"},
	{"theme": "rusted_industrial", "role": "wall",
	 "note": "corrugation 0.22 m -> 0.25 m"},
	{"theme": "neon_transit", "role": "wall",
	 "note": "station tile 0.30 m -> 0.25 m"},
]

var _assets: String
var _out: String

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_assets = args[0]
	_out = args[1]
	_run.call_deferred()

func _material(set_dir: String, theme: String, role: String,
		uv_scale: Vector3) -> StandardMaterial3D:
	## `set_dir` is "theme" or "theme_candidate". Nothing else resolves,
	## and a missing file is an error rather than a silent fallback: a
	## before/after where one side quietly fell back to the other side's
	## pixels would be a comparison of a thing with itself.
	var path := "%s/textures/%s/%s_%s.png" % [_assets, set_dir, theme, role]
	if not FileAccess.file_exists(path):
		push_error("no texture at %s" % path)
		return null
	var img := Image.load_from_file(path)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	# NEAREST, and no mipmaps on the strip: a mipmap is a blur and the
	# question is about where the courses land, not about filtering.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = true
	mat.uv1_scale = uv_scale
	mat.roughness = 0.9
	mat.resource_name = "%s/%s/%s" % [set_dir, theme, role]
	return mat

func _strip(world: Node3D, set_dir: String, theme: String, role: String,
		y: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(STRIP_M, TILE_M)
	plane.orientation = PlaneMesh.FACE_Z
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.name = "%s_%s_%s" % [set_dir, theme, role]
	world.add_child(mi)
	mi.position = Vector3(0.0, y, 0.0)
	mi.material_override = _material(set_dir, theme, role,
			Vector3(STRIP_M / TILE_M, 1.0, 1.0))

func _label(world: Node3D, text: String, at: Vector3, size: float,
		tint: Color) -> void:
	## A caption inside the frame. A before/after whose halves are not
	## named is a picture of two walls.
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 64
	lab.pixel_size = size / 64.0
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lab.modulate = tint
	lab.outline_size = 12
	lab.outline_modulate = Color(0.05, 0.06, 0.08)
	lab.no_depth_test = true
	world.add_child(lab)
	lab.position = at


func _role_of(name: String) -> String:
	var stem := name
	var dot := stem.rfind(".")
	if dot > 0 and stem.substr(dot + 1).is_valid_int():
		stem = stem.substr(0, dot)
	if not stem.begins_with(PREFIX + "_"):
		return ""
	var tail := stem.substr(PREFIX.length() + 1)
	return tail if ROLES.has(tail) else ""

func _bind(root: Node, set_dir: String, theme: String) -> int:
	## Per-surface overrides, as 8.5 requires. The shared mesh is never
	## touched, so the two instances can wear different sets at once.
	var bound := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var role := _role_of("" if mat == null else mat.resource_name)
			if role == "":
				continue
			# The shell's own UVs already carry the world density; only
			# the strips above set a scale.
			mi.set_surface_override_material(i,
					_material(set_dir, theme, role, Vector3.ONE))
			bound += 1
	return bound

func _run() -> void:
	# --- the long strips, one frame per theme --------------------------
	for entry in STRIPS:
		var world := Node3D.new()
		get_root().add_child(world)
		# SHIPPED above, CANDIDATE below, one metre apart, so the eye
		# compares two rhythms in one saccade instead of across two
		# images -- and so each strip's caption sits beside it rather
		# than on top of the pixels being judged.
		_strip(world, "theme", entry["theme"], entry["role"], 5.0)
		_strip(world, "theme_candidate", entry["theme"], entry["role"], 0.0)
		_label(world, "SHIPPED   assets/textures/theme",
				Vector3(-11.9, 7.45, 0.05), 0.42, Color(1, 0.86, 0.55))
		_label(world, "CANDIDATE   SNAP_COURSES on   %s" % entry["note"],
				Vector3(-11.9, 2.45, 0.05), 0.42, Color(0.62, 0.93, 1.0))
		_label(world, "%s / %s   24 m of wall, six repeats of a 4 m tile"
				% [entry["theme"], entry["role"]],
				Vector3(-11.9, -2.35, 0.05), 0.36, Color(0.75, 0.78, 0.84))
		# Framed to the content: 24 m across in a 2.5:1 frame needs 9.6 m
		# of vertical view, and the strips plus their captions are 9.8 m
		# tall from -2.35 to 7.45.
		await _shot(world, Vector3(0.0, 2.6, 9.4),
				Vector3(0.0, 2.6, 0.0), Vector2i(1600, 640),
				"STRIP_%s_%s" % [entry["theme"], entry["role"]], false)
		world.queue_free()
		await process_frame

	# --- the shipped shell, same theme, two sets -----------------------
	var packed := load(SHELL) as PackedScene
	var room := Node3D.new()
	get_root().add_child(room)
	var a := packed.instantiate()
	var b := packed.instantiate()
	a.name = "A_shipped"
	b.name = "B_candidate"
	a.position = Vector3(-9.0, 0.0, 0.0)
	b.position = Vector3(9.0, 0.0, 0.0)
	room.add_child(a)
	room.add_child(b)
	var n_a := _bind(a, "theme", "concrete_facility")
	var n_b := _bind(b, "theme_candidate", "concrete_facility")
	if n_a != n_b or n_a == 0:
		push_error("the two instances did not bind the same surfaces: %d vs %d"
				% [n_a, n_b])
	print("[cand] bound %d surfaces per instance" % n_a)
	# The SAME camera offset relative to each instance, so the framing is
	# the comparison and not a variable in it.
	var eye := Vector3(0.0, 1.7, 5.2)
	var look := Vector3(-0.6, 1.5, 0.6)
	await _shot(room, a.position + eye, a.position + look,
			Vector2i(960, 720), "ROOM_A_shipped", true)
	await _shot(room, b.position + eye, b.position + look,
			Vector2i(960, 720), "ROOM_B_candidate", true)
	print("[cand] wrote %s" % _out)
	quit(0)

func _shot(world: Node3D, at: Vector3, look: Vector3, size: Vector2i,
		name: String, sun: bool) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var holder := Node3D.new()
	vp.add_child(holder)
	var cam := Camera3D.new()
	cam.fov = 60.0
	holder.add_child(cam)
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 1.0, 1.0)
	# The strips are lit FLAT on purpose. A raking light is how you sell a
	# surface and it is also how you hide where the courses land, and this
	# picture exists to answer exactly that.
	e.ambient_light_energy = 1.0 if not sun else 0.55
	env.environment = e
	holder.add_child(env)
	if sun:
		var light := DirectionalLight3D.new()
		light.light_energy = 1.5
		holder.add_child(light)
		light.global_position = at + Vector3(0, 8, 0)
		light.look_at(look, Vector3.UP)
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[cand] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()
