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
## The band node's authored X, captured before anything scales it.
var _band_base_x := 0.0

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
	if not band.has_meta("base_x"):
		band.set_meta("base_x", band.position.x)
	_band_base_x = band.get_meta("base_x")
	var mat := _band_material(state)
	if state == "active":
		mat.uv1_offset = Vector3(-phase, 0.0, 0.0)
	elif state == "pulse_travelling":
		mat.uv1_offset = Vector3(-phase * 4.0, 0.0, 0.0)
	band.set_surface_override_material(0, mat)
	# `fill_band` is the ONLY thing that grows. `state_band` carries the
	# track and both end stops and is never scaled, so the span the fill is
	# a fraction of holds still in every frame.
	var fill := asset.find_child("fill_band", true, false) as MeshInstance3D
	if fill != null:
		if not fill.has_meta("base_x"):
			fill.set_meta("base_x", fill.position.x)
		fill.visible = state == "delayed"
		if state == "delayed":
			var fbox := fill.mesh.get_aabb()
			var fx0 := fbox.position.x
			var ffrac := clampf(phase, 0.0, 1.0)
			fill.scale = Vector3(maxf(ffrac, 0.001), 1.0, 1.0)
			fill.position.x = (fill.get_meta("base_x")
					+ fx0 * (1.0 - maxf(ffrac, 0.001)))
	if false:
		# The band itself is never scaled any more. Kept as a named branch
		# so the contract is visible where the driving happens.
		#
		# The first version hard-coded `position.x = -(1 - frac)`, which is
		# only right if the band runs exactly -1..+1. It did not: an
		# asymmetric clamp had moved the asset's centre and the band
		# exported spanning -1.14..+0.86, so every frame of the delay was
		# drawn in the wrong place. The clamp is fixed and the band is
		# symmetric again -- and this no longer cares either way.
		#
		# A point at local x maps to `position.x + scale.x * x`. Holding the
		# -X end at its unscaled place means position.x = base + x0*(1 - s).
		pass
	band.scale = Vector3.ONE
	band.position.x = _band_base_x

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
		lines: Array = [], size := Vector2i(1180, 600)) -> void:
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
	await _delay_demo()
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
	w.get_parent().remove_child(w)
	w.queue_free()
	await _pair()


func _pair() -> void:
	## `inactive` against `blocked`, ALONE, at reading distance.
	##
	## The first version of this shot framed two rows of a five-row stack and
	## put the two labels beside `active`'s chevrons and the travelling
	## pulse. The labels were right about the states and wrong about the
	## conduits under them, which is the worst kind of caption. This scene
	## contains two conduits and nothing else.
	var w := _scene()
	var ids := ["inactive", "blocked"]
	for i in ids.size():
		var run := _load("batch043/machinery/mach_conduit_run.glb")
		if run == null:
			continue
		w.add_child(run)
		run.global_position = Vector3(-2.97, 1.85 - i * 0.80, 3.0)
		run.rotate_y(deg_to_rad(90.0))
		_drive(run, ids[i], 0.0)
	await _shot(w, Vector3(-1.15, 1.50, 3.02), Vector3(-3.0, 1.50, 3.02),
			"MACH_close_inactive_vs_blocked",
			[["inactive -- dimmest in the kit, unbroken, still",
			  Vector2(560, 120)],
			 ["blocked -- brighter, broken, bright cut ends, still",
			  Vector2(500, 400)],
			 ["two channels: brightness AND pattern. No hue, no hazard.",
			  Vector2(60, 540)]])
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
		var hinge := sw.find_child("hinge_lever", true, false) as Node3D
		var arm := sw.find_child("lever_arm", true, false) as MeshInstance3D
		if hinge != null:
			hinge.rotate_x(deg_to_rad(s[1]))
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
	await _hinge_proof()


func _hinge_proof() -> void:
	## THE CLAIM: the lever's attachment point does not move when the lever
	## does. Measured across a full sweep, and rendered.
	##
	## `hinge_lever` is an Empty at the pintle with `lever_arm` as its child
	## at identity, so the attachment point IS the hinge's own origin -- and
	## rotating a transform never moves its own origin. The number that
	## matters is therefore not "is it small", it is "is it zero".
	##
	## The contrast is what makes it worth measuring. In the previous export
	## the arm was a node with identity transform whose vertices ran from
	## Y 0.27 to Y 0.53, so rotating it turned the lever about the ASSET
	## origin. This reports how far the pintle would have swung under that
	## arrangement, from the same geometry.
	var w := _scene()
	var sw := _load("batch043/machinery/mach_wall_switch.glb")
	w.add_child(sw)
	sw.global_position = Vector3(0.0, 1.15, 3.0)
	var hinge := sw.find_child("hinge_lever", true, false) as Node3D
	var arm := sw.find_child("lever_arm", true, false) as MeshInstance3D
	if hinge == null or arm == null:
		push_error("[mach] no hinge_lever / lever_arm in the export")
		quit(4)
	var local := arm.mesh.get_aabb()
	var inside := (local.position.x <= 0.0 and local.end.x >= 0.0
			and local.position.y <= 0.0 and local.end.y >= 0.0
			and local.position.z <= 0.0 and local.end.z >= 0.0)
	var offset := hinge.position          # pintle, relative to the asset root
	var rows := []
	var base := hinge.global_position
	var worst := 0.0
	var worst_old := 0.0
	for a in [0.0, -15.0, -30.0, -45.0, -60.0, -75.0]:
		hinge.rotation = Vector3.ZERO
		hinge.rotate_x(deg_to_rad(a))
		var moved := hinge.global_position.distance_to(base)
		# What the OLD arrangement did: the same point, rotated about the
		# asset origin instead of about itself.
		var swung: Vector3 = Basis(Vector3.RIGHT, deg_to_rad(a)) * offset
		var old_moved := swung.distance_to(offset)
		worst = maxf(worst, moved)
		worst_old = maxf(worst_old, old_moved)
		rows.append({"deg": a, "pivot_moved_m": moved,
				"would_have_moved_m": old_moved})
	hinge.rotation = Vector3.ZERO
	_log["hinge"] = {
		"pivot_local_to_arm": [local.position.x, local.position.y,
				local.position.z, local.end.x, local.end.y, local.end.z],
		"pivot_inside_arm_geometry": inside,
		"max_pivot_movement_m": worst,
		"max_movement_without_the_hinge_m": worst_old,
		"samples": rows,
	}
	print("[mach] pivot inside arm geometry: %s" % inside)
	print("[mach] pivot movement across a 75 deg sweep: %.9f m" % worst)
	print("[mach] the same point without a hinge node: %.4f m" % worst_old)
	if not inside or worst > 1e-6:
		push_error("[mach] the hinge does not hold its own attachment point")
		quit(5)
	# And the picture: six angles, composited, with the pintle marked.
	for i in 6:
		var a := -15.0 * i
		hinge.rotation = Vector3.ZERO
		hinge.rotate_x(deg_to_rad(a))
		var pip := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.012
		ball.height = 0.024
		ball.radial_segments = 8
		ball.rings = 4
		pip.mesh = ball
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.96, 0.97)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		pip.material_override = m
		w.add_child(pip)
		pip.global_position = hinge.global_position
		# Three-quarter view: the arm swings out of the plate toward the
		# camera, so the motion is in the silhouette rather than hidden
		# against the housing it is mounted on.
		await _shot(w, Vector3(0.80, 1.34, 3.72), Vector3(0.0, 1.26, 3.02),
				"MACH_hinge_%02d" % i,
				[["lever at %d deg" % int(a), Vector2(30, 26)],
				 ["white pip = the pintle. Movement across the sweep: "
				  + "%.9f m" % worst, Vector2(30, 58)],
				 ["without a hinge node the same point swings %.3f m"
				  % worst_old, Vector2(30, 90)]],
				Vector2i(820, 520))
		pip.queue_free()
		await process_frame
	w.get_parent().remove_child(w)
	w.queue_free()


func _delay_demo() -> void:
	## A LABELLED, KNOWN-DURATION DELAY, WITH BOTH ENDPOINTS.
	##
	## §19.5's row for `delayed` is "filling-band animation showing remaining
	## time, rising pitch". The filling band is the FIRST timing channel and
	## the section requires it; the pitch is the second. An earlier revision
	## of this kit said the pitch was the only way to show remaining time,
	## which is not what §19.5 says and sold the visual half short.
	##
	## So: one conduit, a stated four-second delay, sampled at five known
	## fractions, with the source stop and the arrival stop both marked. A
	## reader should be able to say "about three quarters" from any single
	## frame without hearing anything.
	var w := _scene()
	var run := _load("batch043/machinery/mach_conduit_run.glb")
	if run == null:
		return
	w.add_child(run)
	run.global_position = Vector3(-2.97, 1.30, 3.0)
	run.rotate_y(deg_to_rad(90.0))
	const DURATION := 4.0
	for i in 5:
		var frac := float(i) / 4.0
		_drive(run, "delayed", frac)
		await _shot(w, Vector3(-0.55, 1.30, 3.02), Vector3(-3.0, 1.30, 3.02),
				"MACH_delay_%d" % int(frac * 100.0),
				[["a %.1f s delay, %d%% elapsed -- %.1f s remaining"
				  % [DURATION, int(frac * 100.0), DURATION * (1.0 - frac)],
				  Vector2(40, 34)],
				 ["left stop = the source. right stop = arrival.",
				  Vector2(40, 66)],
				 ["the fill between them IS the timing display (§19.5);"
				  + " no audio is used or needed to read it", Vector2(40, 98)]],
				Vector2i(1180, 440))
	w.get_parent().remove_child(w)
	w.queue_free()


func _lit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.1
	return m
