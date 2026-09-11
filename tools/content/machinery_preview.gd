extends SceneTree
## The five conduit states and a switch/receiver pair, on real room geometry.
##
##   godot --path godot -s _harness/mach.gd -- <kit> <models> <out>
##
## PRESENTATION SCAFFOLDING. There is no signal graph here. Nothing evaluates,
## nothing propagates, no node type exists, and the "states" below are five
## textures named in a list. What is demonstrated is whether a player could
## TELL THEM APART, which is Design 1 §19.5's actual requirement and the only
## part of it art owns.
##
## THE LIGHT IS THE SHIPPED MODEL: ambient plus omnis, no directional. See
## tools/content/status_preview.gd for why that matters.
##
## AUDIO IS ABSENT AND SILENCE PROVES NOTHING. §19.5 gives `active` a low
## hum, `pulse_travelling` a click on arrival and `delayed` a rising pitch.
## None exists. `delayed` is the state that suffers most for it: its pitch is
## what tells the player HOW LONG, and no still or loop here supplies that.

const STATES := ["inactive", "active", "pulse_travelling", "blocked",
		"delayed"]
const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]
const PREFIX := "cl"

var _kit: String
var _models: String
var _out: String
var _bench: GDScript
var _log := {}

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_kit = a[0]
	_models = a[1]
	_out = a[2]
	_bench = load("res://_harness/artbench.gd") as GDScript
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

func _bind(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var role := _role_of("" if src == null else src.resource_name)
			if role == "":
				continue
			var mat := StandardMaterial3D.new()
			var tex := load("res://content/shells/shell_corner_left_room_concrete_facility_%s.png" % role) as Texture2D
			if tex != null:
				mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			mat.roughness = 0.9
			mi.set_surface_override_material(i, mat)

## The band material. Alpha-blended, unshaded and NEAREST: a conduit band is
## an emissive channel, not a painted surface, and a lit-and-filtered one
## would dim under the room's own falloff exactly where it matters most.
func _band_material(state: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(
			Image.load_from_file("%s/png/band_%s.png" % [_kit, state]))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## THE WHOLE POINT OF THE EXPORT CHANGE, EXERCISED.
##
## `state_band` arrives as its own node, so this fetches it by name and then
## drives it two ways a material slot on a merged mesh cannot: it sets the
## band's OWN material, and for `delayed` it SCALES the node from one end so
## the fill grows. Batch 028's kit could have done the first and not the
## second.
func _drive(asset: Node3D, state: String, phase: float) -> void:
	var band := asset.find_child("state_band", true, false) as MeshInstance3D
	if band == null:
		return
	var mat := _band_material(state)
	if state == "active":
		mat.uv1_offset = Vector3(-phase, 0.0, 0.0)
	elif state == "pulse_travelling":
		mat.uv1_offset = Vector3(-phase * 4.0, 0.0, 0.0)
	band.set_surface_override_material(0, mat)
	if state == "delayed":
		# Grow from the -X end. The texture holds still; the node changes
		# length -- which is exactly how a delay differs from a pulse.
		var frac := clampf(0.12 + phase, 0.12, 1.0)
		band.scale = Vector3(frac, 1.0, 1.0)
		band.position.x = -(1.0 - frac)
	else:
		band.scale = Vector3.ONE
		band.position.x = 0.0

func _load(rel: String) -> Node3D:
	return _bench.call("load_glb", "%s/%s" % [_models, rel])

func _scene() -> Node3D:
	var world := Node3D.new()
	get_root().add_child(world)
	var shell := (load("res://content/shells/shell_corner_left.tscn")
			as PackedScene).instantiate()
	world.add_child(shell)
	_bind(shell)
	for spot: Variant in [[Vector3(-1.8, 2.7, 1.8), 1.4],
			[Vector3(1.8, 2.7, 4.2), 1.4]]:
		var s: Array = spot
		var lamp := OmniLight3D.new()
		world.add_child(lamp)
		lamp.global_position = s[0]
		lamp.light_energy = s[1]
		lamp.omni_range = 12.0
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.918, 0.949, 1.0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.918, 0.949, 1.0)
	e.ambient_light_energy = 0.35
	e.fog_enabled = true
	e.fog_density = 0.012
	env.environment = e
	world.add_child(env)
	return world

func _label(vp: SubViewport, size: Vector2i, lines: Array) -> void:
	var layer := Control.new()
	layer.size = Vector2(size)
	vp.add_child(layer)
	for raw: Variant in lines:
		var l: Array = raw
		var plate := ColorRect.new()
		plate.color = Color(0.06, 0.07, 0.09, 0.72)
		plate.position = l[1]
		plate.size = Vector2(8.6 * str(l[0]).length() + 16, 24)
		layer.add_child(plate)
		var lab := Label.new()
		lab.text = l[0]
		lab.position = Vector2(l[1]) + Vector2(8, -1)
		lab.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
		lab.add_theme_font_size_override("font_size", 15)
		layer.add_child(lab)

func _shot(world: Node3D, at: Vector3, look: Vector3, name: String,
		lines: Array = []) -> void:
	var size := Vector2i(1180, 600)
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var holder := Node3D.new()
	vp.add_child(holder)
	var cam := Camera3D.new()
	cam.fov = 62.0
	holder.add_child(cam)
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	var parent := world.get_parent()
	parent.remove_child(world)
	vp.add_child(world)
	_label(vp, size, lines)
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[mach] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()

func _run() -> void:
	await _comparison()
	await _motion()
	await _switch()
	var f := FileAccess.open("%s/machinery_log.json" % _out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_log, "  "))
	f.close()
	quit(0)

func _comparison() -> void:
	## All five, side by side on one wall, one frame. The still is where
	## `inactive` versus `blocked` has to win, because neither of them moves:
	## if pattern alone cannot separate them here, motion will not save them.
	var w := _scene()
	var runs := []
	for i in STATES.size():
		var run := _load("batch043/machinery/mach_conduit_run.glb")
		if run == null:
			continue
		w.add_child(run)
		run.global_position = Vector3(-2.97, 2.44 - i * 0.56, 3.0)
		# +90, not -90. The band face is Blender's -Y, which glTF's Y-up
		# conversion turns into +Z; a -90 yaw pointed it INTO the wall and
		# the first five-state render was five conduits seen from behind.
		run.rotate_y(deg_to_rad(90.0))
		# `delayed` at phase 0 is a 12% stub and says nothing about the
		# state; shown at 55% it says what it is.
		_drive(run, STATES[i], 0.43 if STATES[i] == "delayed" else 0.0)
		runs.append(run)
	_log["runs"] = runs.size()
	var lines := []
	for i in STATES.size():
		lines.append([STATES[i], Vector2(760, 62 + i * 103)])
	await _shot(w, Vector3(0.30, 1.35, 3.02), Vector3(-3.0, 1.35, 3.0),
			"MACH_five_states", lines)
	# And close, at the distance a player reads a conduit from. The pair
	# this shot has to settle is `inactive` against `blocked`: both dim,
	# both still, separated by pattern alone.
	await _shot(w, Vector3(-1.35, 1.95, 3.02), Vector3(-3.0, 1.95, 3.02),
			"MACH_close_inactive_vs_blocked",
			[["inactive -- dim, unbroken, still", Vector2(60, 150)],
			 ["blocked -- dim, SEVERED, still", Vector2(60, 430)]])
	w.get_parent().remove_child(w)
	w.queue_free()

func _motion() -> void:
	## Ten frames. `active` scrolls, `pulse_travelling` scrolls four times
	## faster with a block of CONSTANT length, `delayed` does not scroll at
	## all -- its band grows. Three motions, three meanings.
	var w := _scene()
	var moving := ["active", "pulse_travelling", "delayed"]
	var runs := []
	for i in moving.size():
		var run := _load("batch043/machinery/mach_conduit_run.glb")
		w.add_child(run)
		run.global_position = Vector3(-2.97, 2.16 - i * 0.62, 3.0)
		run.rotate_y(deg_to_rad(90.0))
		runs.append(run)
	for f in 10:
		var phase := float(f) / 10.0
		for i in moving.size():
			_drive(runs[i], moving[i], phase)
		await _shot(w, Vector3(0.10, 1.30, 3.02), Vector3(-3.0, 1.30, 3.0),
				"MACHSEQ_%02d" % f,
				[["active", Vector2(720, 96)],
				 ["pulse_travelling", Vector2(720, 258)],
				 ["delayed  (no audio: the rising pitch is missing)",
				  Vector2(620, 420)]])
	w.get_parent().remove_child(w)
	w.queue_free()

func _switch() -> void:
	## A setter and the thing it controls, each reporting its own state
	## through an addressable node. The lever is TURNED, not recoloured --
	## §33.8 asks for the physical position of the lever, and a merged mesh
	## could not have given it one.
	var w := _scene()
	for shot: Variant in [["off", 0.0, Color(0.29, 0.31, 0.35),
					Color(0.29, 0.31, 0.35)],
			["on", -52.0, Color(0.22, 0.84, 0.78), Color(0.22, 0.84, 0.78)],
			["disagreeing", -52.0, Color(0.22, 0.84, 0.78),
					Color(0.91, 0.33, 0.12)]]:
		var s: Array = shot
		var sw := _load("batch043/machinery/mach_wall_switch.glb")
		var rx := _load("batch043/machinery/mach_receiver_lamp.glb")
		w.add_child(sw)
		w.add_child(rx)
		# Free-standing and square to the camera. Mounted on the west wall
		# the pair kept turning a shoulder to whatever angle framed the room,
		# and this is an ISOLATED demonstration of two state regions, not a
		# room composition -- so the geometry faces the reader.
		sw.global_position = Vector3(-0.72, 1.15, 3.0)
		# No rotation. The authored front (Blender -Y) becomes glTF +Z, so
		# the switch already faces a camera on the +Z side. A half turn was
		# added here while the real fault was elsewhere -- the lens was
		# displaced INSIDE the housing by an origin shift the part never
		# received -- and it made the only visible part, the lever, point
		# backwards. The fix belonged in `set_origin_group`, not here.
		rx.global_position = Vector3(0.72, 0.0, 3.0)
		var arm := sw.find_child("lever_arm", true, false) as Node3D
		if arm != null:
			arm.rotate_x(deg_to_rad(s[1]))
		var lens := sw.find_child("state_lens", true, false) as MeshInstance3D
		if lens != null:
			lens.set_surface_override_material(0, _lit(s[2]))
		for n in ["state_lens_0", "state_lens_1"]:
			var l := rx.find_child(n, true, false) as MeshInstance3D
			if l != null:
				l.set_surface_override_material(0,
						_lit(s[3] if n == "state_lens_1" else s[2]))
		await _shot(w, Vector3(0.0, 1.18, 4.85),
				Vector3(0.0, 1.05, 3.0), "MACH_switch_%s" % s[0],
				[["setter and receiver: %s" % s[0], Vector2(52, 40)],
				 ["lever position is geometry, not colour", Vector2(52, 74)]])
		sw.queue_free()
		rx.queue_free()
		await process_frame
	w.get_parent().remove_child(w)
	w.queue_free()

func _lit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.1
	return m
