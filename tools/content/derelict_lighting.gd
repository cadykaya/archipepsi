extends SceneTree
## Batch 042 follow-up: the lighting study, and a per-surface UV correction.
##
##   godot --path godot -s _harness/lit.gd -- <assets> <trial> <out>
##
## WHAT WAS WRONG WITH THE FIRST PREVIEW, and it was mine.
##
## `derelict_preview.gd` lit the room with a `DirectionalLight3D` and never
## set `shadow_enabled`, which defaults to FALSE. An unshadowed directional
## light illuminates every surface whose normal faces it and is not stopped
## by walls -- so an enclosed room was being lit by a sun shining straight
## through its own hull. That is why it read as broadly illuminated, and
## darkening the textures to compensate was treating a rendering artifact as
## an art problem.
##
## WORSE, THE GAME HAS NO SUN. `ZoneBuilder` sets an ambient of 0.35 and fog;
## `ChamberBuilders` adds one `OmniLight3D` per fixture at
## `ThemeMaterials.light_energy(theme)` with `omni_range` 12.0. There is no
## DirectionalLight3D anywhere in a built Zone. The sun was preview
## scaffolding I introduced, and it is now gone.
##
## SO THE STUDY IS BUILT ON THE SHIPPED MODEL: low ambient, plus omni
## fixtures with real falloff. Pools of light and dark recesses come from
## placement and range, which is what the game can actually do.
##
## PREVIEW-ONLY, AND LABELLED. Every added node hangs under a child named
## `PREVIEW_LIGHTING_NOT_SHIPPED`. No collision, no gameplay meaning, no
## runtime integration, and no approved asset is touched.

const SHELL := "res://content/shells/shell_corner_left.tscn"
const PREFIX := "cl"
const ROLES := ["floor", "wall", "ceiling", "trim", "accent", "hazard"]

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

func _path_for(role: String) -> String:
	match role:
		"wall", "ceiling": return "%s/derelict_wall.png" % _trial
		"floor": return "%s/derelict_floor.png" % _trial
		"trim": return "%s/derelict_trim.png" % _trial
		"accent": return "%s/derelict_accent.png" % _trial
	return ""

## `rotate_ceiling` is the per-surface UV CORRECTION, and it is a material
## change rather than a mesh one.
##
## Measured, not assumed: `tools/content/inspect_uvs.py` shows every piece of
## this shell is a box with a per-face unwrap. On the four vertical faces
## (+-X, +-Z) the texture's V axis runs along world up, so an authored
## vertical stringer reads vertical -- 32 of 48 wall faces. On the two
## horizontal faces (+-Y) V runs along +Z instead, so the same texture is
## laid flat and its stringers run horizontally. That is correct behaviour
## for a box unwrap and it is invisible on the top of a wall slab -- but the
## CEILING is exactly such a face, and it takes the `wall` field through the
## resolved `ceiling -> wall` fallback. A directional pattern on a surface
## with no up is where the fallback shows.
##
## Rotating the IMAGE for that one material puts the stringers back along
## the room's long axis. Nothing about the mesh, its UVs or the shared
## texture changes.
func _material(role: String, rotate_ceiling: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [role, str(rotate_ceiling)]
	if _cache.has(key):
		return _cache[key]
	var img := Image.load_from_file(_path_for(role))
	if rotate_ceiling and role == "ceiling":
		img.rotate_90(CLOCKWISE)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.resource_name = "deep_space_derelict/%s%s" % [
			role, "@rot90" if (rotate_ceiling and role == "ceiling") else ""]
	_cache[key] = mat
	return mat

func _bind(root: Node, rotate_ceiling: bool) -> int:
	var unresolved := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var role := _role_of("" if src == null else src.resource_name)
			if role == "":
				unresolved += 1
				continue
			mi.set_surface_override_material(i, _material(role, rotate_ceiling))
	return unresolved

# =========================================================================
# THE LIGHTING STUDY
# =========================================================================
## Four sources, each with something visible that could plausibly emit it.
## The room's interior is 6 x 3.6 x 6 with the floor at y = 0 and z 0..6.
const FIXTURES := [
	# A working ceiling panel over the middle of the room: the one source
	# that actually lets a player read the floor.
	{"id": "ceiling_panel", "at": Vector3(0.0, 3.35, 2.6),
	 "colour": Color(0.78, 0.86, 0.90), "energy": 1.7, "range": 7.0,
	 "size": Vector3(1.1, 0.08, 0.5), "emissive": 0.40,
	 "why": "the one panel still lit; it is what makes the deck readable"},
	# A failing one nearer the mouth, dimmer and cooler, so the room has a
	# far end that is worse than its near end.
	{"id": "mouth_panel", "at": Vector3(-0.4, 3.35, 5.1),
	 "colour": Color(0.62, 0.72, 0.80), "energy": 0.65, "range": 4.2,
	 "size": Vector3(0.9, 0.08, 0.4), "emissive": 0.20,
	 "why": "failing: a quarter of the output, so the mouth stays gloomy"},
	# A low service lamp on the west wall, throwing light UP the plating so
	# the stringers catch it. This is the one that makes the wall read.
	# FIRST PASS BLEW THIS OUT. At 1.5 over a 3.4 m range, 25 cm off the
	# plating, it washed a metre of bulkhead to white and read as a blob
	# rather than as a lamp. Pulled off the wall and down to a third.
	{"id": "west_service", "at": Vector3(-2.5, 1.15, 3.4),
	 "colour": Color(0.80, 0.85, 0.86), "energy": 0.55, "range": 2.8,
	 "size": Vector3(0.10, 0.22, 0.34), "emissive": 0.22,
	 "why": "a service lamp raking the bulkhead, so its ribs read as ribs"},
	# The conduit indicators: cold, tiny, and NOT a gameplay signal -- they
	# are the accent field's own colour and mark nothing.
	{"id": "conduit_glow", "at": Vector3(1.2, 2.45, 5.85),
	 "colour": Color(0.33, 0.67, 0.76), "energy": 0.40, "range": 1.8,
	 "size": Vector3(0.30, 0.06, 0.06), "emissive": 0.38,
	 "why": "the accent conduit's own indicator colour, decorative only"},
]

func _build_fixtures(root: Node3D, shadows: bool) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "PREVIEW_LIGHTING_NOT_SHIPPED"
	root.add_child(holder)
	var recorded: Array = []
	for raw: Variant in FIXTURES:
		var f: Dictionary = raw
		# The visible housing. A box, no collision, obviously preview.
		var box := BoxMesh.new()
		box.size = f["size"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.10, 0.12, 0.14)
		# The housing keeps its own dark surface; only the emission term
		# lifts it. A housing driven to pure white stops reading as a fitting
		# and starts reading as a hole in the wall.
		# EMISSION, RECORDED RATHER THAN PAINTED. Nothing is baked into any
		# albedo: this is an emission term on a preview-only housing, and its
		# value is written into the study record below.
		mat.emission_enabled = true
		mat.emission = f["colour"]
		mat.emission_energy_multiplier = f["emissive"]
		var mi := MeshInstance3D.new()
		mi.name = "PREVIEW_fixture_%s" % f["id"]
		mi.mesh = box
		mi.material_override = mat
		holder.add_child(mi)
		mi.global_position = root.global_position + f["at"]

		var lamp := OmniLight3D.new()
		lamp.name = "PREVIEW_light_%s" % f["id"]
		lamp.light_color = f["colour"]
		lamp.light_energy = f["energy"]
		lamp.omni_range = f["range"]
		# The shipped fixture builder sets shadow_enabled = false. Turning it
		# on here is a PREVIEW choice and is recorded as one -- it is what
		# gives a recess an actual dark side rather than a dimmer one.
		lamp.shadow_enabled = shadows
		holder.add_child(lamp)
		lamp.global_position = root.global_position + f["at"] + Vector3(0, -0.12, 0)
		recorded.append({"id": f["id"], "at": [f["at"].x, f["at"].y, f["at"].z],
			"colour": [f["colour"].r, f["colour"].g, f["colour"].b],
			"energy": f["energy"], "omni_range": f["range"],
			"emission_energy": f["emissive"], "shadow_enabled": shadows,
			"why": f["why"]})
	return {"holder": holder, "fixtures": recorded}

## The three lighting conditions, matched so the shots compare.
const SHARED := {"ambient": 0.55, "colour": Color(0.918, 0.949, 1.0),
		"sun": 1.5, "bg": Color(0.06, 0.07, 0.09), "fixtures": false}
const THEME := {"ambient": 0.17, "colour": Color(0.725, 0.812, 0.839),
		"sun": 0.55, "bg": Color(0.015, 0.02, 0.024), "fixtures": false}
## No sun at all, because a built Zone has none. Ambient near the shipped
## 0.35 in character but lower, since this theme is a failing station.
const STUDY := {"ambient": 0.13, "colour": Color(0.66, 0.75, 0.80),
		"sun": 0.0, "bg": Color(0.012, 0.016, 0.02), "fixtures": true}

func _run() -> void:
	var packed := load(SHELL) as PackedScene
	var world := Node3D.new()
	get_root().add_child(world)

	# One instance per condition, so a single camera pass captures all three
	# without rebuilding anything.
	var a := packed.instantiate(); a.name = "SHARED"
	var b := packed.instantiate(); b.name = "THEME"
	var c := packed.instantiate(); c.name = "STUDY"
	var d := packed.instantiate(); d.name = "STUDY_UVFIX"
	a.position = Vector3(-120, 0, 0)
	b.position = Vector3(-80, 0, 0)
	c.position = Vector3(-40, 0, 0)
	for n in [a, b, c, d]:
		world.add_child(n)

	_log["unresolved"] = [_bind(a, false), _bind(b, false), _bind(c, false),
			_bind(d, true)]
	var fc := _build_fixtures(c, true)
	var fd := _build_fixtures(d, true)
	_log["fixtures"] = fc["fixtures"]
	_log["fixture_count"] = FIXTURES.size()
	_log["sun_removed"] = true
	_log["why_sun_removed"] = ("DirectionalLight3D with shadow_enabled false "
			+ "lit the interior through the walls; a built Zone has no "
			+ "DirectionalLight3D at all")
	_log["shipped_reference"] = {"ambient": 0.35, "omni_range": 12.0,
			"fixture_shadow_enabled": false,
			"source": "ZoneBuilder + ChamberBuilders at Production 2f727a7"}
	_log["preview_shadow_enabled"] = true
	_log["collision_added_by_preview"] = 0
	_log["preview_nodes_under"] = "PREVIEW_LIGHTING_NOT_SHIPPED"

	var shots := [
		{"n": "wide", "at": Vector3(0.9, 1.7, 5.4), "to": Vector3(-1.4, 1.3, 1.2)},
		{"n": "floor", "at": Vector3(1.4, 1.6, 4.9), "to": Vector3(-1.0, 0.2, 1.6)},
	]
	for raw: Variant in shots:
		var s: Dictionary = raw
		var at: Vector3 = s["at"]
		var to: Vector3 = s["to"]
		await _shot(world, at + Vector3(-120, 0, 0), to + Vector3(-120, 0, 0),
				"LIT_%s_1shared" % s["n"], SHARED)
		await _shot(world, at + Vector3(-80, 0, 0), to + Vector3(-80, 0, 0),
				"LIT_%s_2theme" % s["n"], THEME)
		await _shot(world, at + Vector3(-40, 0, 0), to + Vector3(-40, 0, 0),
				"LIT_%s_3study" % s["n"], STUDY)
	# The UV correction, under the study light, against the same view.
	await _shot(world, Vector3(-40, 2.2, 4.6) + Vector3(0, 0, 0),
			Vector3(-40.6, 3.5, 1.4), "UV_ceiling_before", STUDY)
	await _shot(world, Vector3(0, 2.2, 4.6), Vector3(-0.6, 3.5, 1.4),
			"UV_ceiling_after", STUDY)

	var fh := FileAccess.open("%s/lighting_study.json" % _out, FileAccess.WRITE)
	fh.store_string(JSON.stringify(_log, "  ", true))
	fh.close()
	print("[lit] unresolved %s | fixtures %d | sun removed" %
			[str(_log["unresolved"]), FIXTURES.size()])
	print("[lit] wrote lighting_study.json")
	quit(0)

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
	if light["sun"] > 0.0:
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
	print("[lit] %s.png" % name)
	vp.remove_child(world)
	parent.add_child(world)
	vp.queue_free()
