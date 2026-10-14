extends SceneTree
## THE FIVE WEAPONS, READY FOR INTEGRATION, IN PROD'S OWN RANGE.
## (Arty, 2026-10-14.) Run against a READ-ONLY checkout of Prod's
## `review/five-weapons-v3`; nothing of his is edited. Everything below
## happens in this process's memory.
##
##   xvfb-run ... godot --rendering-driver opengl3 --path <checkout>/godot \
##       --resolution 1600x900 --fixed-fps 60 \
##       [or --fixed-fps 30 --write-movie <f.png> for a clip] \
##       -s res://tests/_arty_five_integration.gd -- --five-weapons \
##       --weapon=<id> [--variant=breacher|sweeper] \
##       [--glb=<geometry.glb> --lean=<lean dir>] [--fx=<fx.json>] \
##       --mode=stills|impacts|clip --out=<dir> --tag=<name>
##
## Without --glb it photographs Prod's placeholder (and without --fx, his
## own effects): the "before" of every comparison. With them, the art:
## the geometry GLB wearing its lean maps (`lean_maps.py`), Prod's parts
## pointed at the model's nodes by the names his rig uses, the Foundry's
## carousel through the study's adapter, and the Glyph effects through
## `glyph_fx_layer.gd` (copied beside this script as
## `_arty_glyph_fx_layer.gd`).
##
## Modes:
##   stills   rest, ADS (where the weapon has it), the shot's flash; the
##            cost (draw calls, primitives, texture memory, shown minus
##            hidden); first-person clearance (the model's nearest point
##            to the eye against the camera's near plane, the screen share
##            it covers, and whether it covers the crosshair)
##   impacts  one shot at each material target (metal, stone, wood, gel):
##            the impact two frames after it lands, then the mark it
##            leaves, from close
##   clip     a burst through `fire_pulse`, every physics frame logged:
##            the moving parts, the cooldown, Prod's clocks, clearance

const AIM := Vector3(0, 1.2, -10)
const ADS_ALT := "range_ads_alt"
const RIG_OWNED := ["Muzzle", "ChargeOrb", "ChargeLight"]
const PARTS := {
	"foundry": {"hammer": "Hammer", "cylinder": "Carousel"},
	"sightline": {"handle": "Handle"},
	"switchback": {"bolt": "Bolt"},
	"bulkhead": {"pump": "Pump", "feed": "Feed"},
	"driver": {"coils": "Coils", "core": "Core"},
}
## the range's tagged surfaces (their own `impact_material` meta)
const TARGETS := {
	"metal": Vector3(-3.6, 1.3, -9.0),       # SteelPlate
	"stone": Vector3(-1.4, 1.3, -15.5),      # ConcretePillar
	"wood": Vector3(-3.4, 0.55, -14.0),      # TimberCrate
	"gel": Vector3(-2.2, 0.6, -6.5),         # GelBlock
}

var _out := ""
var _glb := ""
var _lean := ""
var _fx := ""
var _weapon := ""
var _variant := ""
var _tag := ""
var _mode := "stills"
var _host: Node = null
var _body: Node3D = null
var _weapons: Node = null
var _rig: Node3D = null
var _layer: Node = null
var _tex_before := 0
var _record := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		for key in ["out", "glb", "lean", "fx", "weapon", "variant", "tag",
				"mode"]:
			if arg.begins_with("--%s=" % key):
				set("_" + key, arg.trim_prefix("--%s=" % key))
	if _tag == "":
		_tag = _weapon
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file(str(ProjectSettings.get_setting(
			"application/run/main_scene")))
	_run.call_deferred()


func _run() -> void:
	for _i in 600:
		await physics_frame
		if current_scene != null:
			_host = current_scene.get_node_or_null("WeaponFeel")
		if _host != null and bool(_host.get("five")):
			break
	if _host == null:
		push_error("[int] the five-weapon range never came up")
		quit(1)
		return
	_body = _host.get("player")
	_weapons = _host.get("weapons")
	_rig = _weapons.get("rig")
	_host.call("select_five", _weapon)
	for node in root.find_children("*", "CanvasLayer", true, false):
		if (node as CanvasLayer).layer == 5:
			(node as CanvasLayer).visible = false
	await _settle(10)
	_tex_before = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	if _glb != "":
		_swap()
	if _variant != "":
		_weapons.call("set_variant", _weapon, _variant)
	else:
		_weapons.call("select", _weapon)
	if _fx != "":
		_layer = load("res://tests/_arty_glyph_fx_layer.gd").new()
		_layer.name = "GlyphFx"
		root.add_child(_layer)
		_layer.call("setup", _fx, _weapons)
	_record = {"weapon": _weapon, "variant": _variant, "tag": _tag,
			"art": _glb != "", "glyph_fx": _fx != ""}
	_aim(AIM)
	await _settle(45)
	match _mode:
		"stills":
			await _stills()
		"impacts":
			await _impacts()
		"clip":
			await _clip()
	if _layer != null:
		_record["fx_events"] = _layer.get("events")
	_write(_tag + "_" + _mode + ".json", _record)
	quit(0)


# ================================================================ stills

func _stills() -> void:
	await _shoot(_tag + "_rest")
	_record["rest"] = await _clearance()
	_record["cost"] = await _cost()
	if (_weapons.get("_profile") as Dictionary).has("ads"):
		Input.action_press(ADS_ALT)
		await _settle(40)
		await _shoot(_tag + "_ads")
		_record["ads"] = await _clearance()
		Input.action_release(ADS_ALT)
		await _settle(40)
	if _weapon == "driver":
		Input.action_press("fire_pulse")
		await _settle(60)
		await _shoot(_tag + "_charge")
		Input.action_release("fire_pulse")
		await _settle(2)
	else:
		Input.action_press("fire_pulse")
		await _settle(1)
		Input.action_release("fire_pulse")
	# one frame after the shot: the flash's first frames (run with
	# --fixed-fps 60, so a slow software renderer cannot skip them)
	await _shoot(_tag + "_fire")
	_record["fire_peak"] = await _clearance(false)


# =============================================================== impacts

func _impacts() -> void:
	var impacts: Node = _weapons.get("impacts")
	# a second eye on the target, rendered in the same frame as the player's
	# (a SubViewport sharing the world): the hit is small at 6-16 m
	var near := SubViewport.new()
	near.size = Vector2i(800, 450)
	near.world_3d = root.world_3d
	near.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(near)
	var cam := Camera3D.new()
	cam.near = 0.01
	cam.fov = 40.0
	near.add_child(cam)
	cam.make_current()
	var results := {}
	for mat in TARGETS:
		_aim(TARGETS[mat])
		await _settle(30)
		await _ready_to_fire()
		# the close eye: 1.8 m out from the target, up and to the side, on
		# the shooter's side of it
		var eye: Vector3 = (_body.get("camera") as Node3D).global_position
		var to_eye: Vector3 = (eye - TARGETS[mat]) * Vector3(1, 0, 1)
		var side: Vector3 = to_eye.normalized().cross(Vector3.UP)
		cam.global_position = TARGETS[mat] + to_eye.normalized() * 1.8 \
				+ side * 0.5 + Vector3(0.0, 0.35, 0.0)
		cam.look_at(TARGETS[mat], Vector3.UP)
		var marks_before := int(impacts.call("live_marks"))
		if _weapon == "driver":
			Input.action_press("fire_pulse")
			await _settle(70)
			Input.action_release("fire_pulse")
		else:
			Input.action_press("fire_pulse")
			await _settle(2)
			Input.action_release("fire_pulse")
		# the hit lands when its mark appears (the Driver's slug flies; the
		# others resolve at once)
		var waited := 0
		while waited < 90 and int(impacts.call("live_marks")) <= marks_before:
			await physics_frame
			waited += 1
		var last: Dictionary = impacts.get("last")
		var at: Vector3 = last.get("at", TARGETS[mat])
		cam.look_at(at, Vector3.UP)
		await _settle(2)
		await _shoot("%s_impact_%s" % [_tag, mat], near)
		# the mark as it stays: after the metal's hot rim has cooled (1.5 s)
		await _settle(100)
		var marks: Array = impacts.get("marks")
		var row := {"frames_to_hit": waited, "material": last.get("material"),
				"marks_added": int(impacts.call("live_marks")) - marks_before}
		if not marks.is_empty() and is_instance_valid(marks[-1]):
			var decal: Decal = marks[-1]
			var n: Vector3 = last.get("normal", Vector3.BACK)
			cam.global_position = at + n * 0.55 + Vector3(0.0, 0.08, 0.0)
			cam.look_at(at, Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD)
			await _settle(3)
			await _shoot("%s_mark_%s" % [_tag, mat], near, true)
			row["mark_size_m"] = decal.size.x
			row["mark_texture"] = decal.texture_albedo.resource_name \
					if decal.texture_albedo != null else ""
		results[mat] = row
	near.queue_free()
	_record["impacts"] = results


func _ready_to_fire() -> void:
	var runtime: Object = _weapons.get("runtime")
	for _i in 120:
		if float(runtime.get("cooldown_remaining")) <= 0.0 \
				and _rig.call("gun_at_rest"):
			return
		await physics_frame


# ================================================================== clip

## A burst through the real input action, every physics frame logged.
func _clip() -> void:
	var plan: Array
	match _weapon:
		"sightline", "foundry":
			plan = [[10, true], [14, false], [80, true], [84, false]]
		"switchback":
			plan = [[10, true], [130, false]]
		"bulkhead":
			plan = [[10, true], [14, false], [90, true], [94, false]]
		"driver":
			plan = [[10, true], [110, false]]
	var frames: Array = []
	var runtime: Object = _weapons.get("runtime")
	var t := 0
	var step := 0
	while t < 220:
		while step < plan.size() and int(plan[step][0]) == t:
			if bool(plan[step][1]):
				Input.action_press("fire_pulse")
			else:
				Input.action_release("fire_pulse")
			step += 1
		await physics_frame
		t += 1
		var row := {"t": t, "shots": int(_weapons.get("shots")),
				"cooldown": snappedf(float(runtime.get("cooldown_remaining")),
					0.001),
				"gun_at_rest": bool(_rig.call("gun_at_rest")),
				"clocks": (_weapons.get("clocks") as Dictionary).duplicate()}
		for key in PARTS.get(_weapon, {}):
			var p: Node3D = _rig.call("part", key)
			if p == null:
				continue
			var r := p.rotation_degrees
			row[key] = [snappedf(p.position.z, 0.0001), snappedf(r.x, 0.01),
					snappedf(r.y, 0.01), snappedf(r.z, 0.01), p.visible]
			if key == "core" and p is GeometryInstance3D:
				var glow := (p as GeometryInstance3D).material_override \
						as StandardMaterial3D
				if glow != null:
					row["core_energy"] = snappedf(
							glow.emission_energy_multiplier, 0.01)
		row["clearance"] = _near_point()
		frames.append(row)
	_record["frames"] = frames


# ============================================================ clearance

## The model's nearest point to the eye (metres along the view), against
## the camera's near plane, from its meshes' corners.
func _near_point() -> float:
	var cam: Camera3D = _body.get("camera")
	var model: Node3D = (_rig.get("models") as Dictionary)[_weapon]
	var nearest := 99.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree():
			continue
		var box := m.get_aabb()
		for i in 8:
			var p := m.global_transform * box.get_endpoint(i)
			var local := cam.global_transform.affine_inverse() * p
			nearest = minf(nearest, -local.z)
	return snappedf(nearest, 0.001)


## Near point, plus what the model covers on screen: the share of pixels
## that change when it is hidden, and whether any of them is within 2% of
## the screen's height of the crosshair.
func _clearance(screen := true) -> Dictionary:
	var cam: Camera3D = _body.get("camera")
	var out := {"nearest_m": _near_point(), "near_plane_m": cam.near}
	if not screen:
		return out
	var model: Node3D = (_rig.get("models") as Dictionary)[_weapon]
	await process_frame
	await RenderingServer.frame_post_draw
	var shown := root.get_texture().get_image()
	model.visible = false
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	model.visible = true
	var w := shown.get_width()
	var h := shown.get_height()
	var covered := 0
	var centre := 0
	var r := 0.02 * h
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var a := shown.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.06:
				covered += 1
				if Vector2(x - w / 2.0, y - h / 2.0).length() < r:
					centre += 1
	out["screen_share"] = snappedf(float(covered) / (w * h / 4.0), 0.0001)
	out["covers_crosshair"] = centre > 0
	return out


# ================================================================== cost

## Draw calls, primitives and objects, weapon shown minus hidden (median of
## a dozen frames each way), and the texture memory its maps added.
func _cost() -> Dictionary:
	var model: Node3D = (_rig.get("models") as Dictionary)[_weapon]
	var shown := await _frame_info()
	model.visible = false
	var hidden := await _frame_info()
	model.visible = true
	await _settle(2)
	var tris := 0
	var surfaces := 0
	var materials := {}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.visible:
			continue
		var mesh := m.mesh
		for s in mesh.get_surface_count():
			surfaces += 1
			var mat: Material = m.get_active_material(s)
			if mat != null:
				materials[mat.get_rid().get_id()] = true
			var arr := mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
				tris += (idx as PackedInt32Array).size() / 3
			else:
				tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var tex_after := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	return {
		"draw_calls": shown["draw"] - hidden["draw"],
		"primitives": shown["prims"] - hidden["prims"],
		"triangles": tris, "surfaces": surfaces,
		"materials": materials.size(),
		"texture_mem_added_bytes": tex_after - _tex_before,
	}


func _frame_info() -> Dictionary:
	await _settle(3)
	var keys := {
		"draw": RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME,
		"prims": RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME,
	}
	var seen := {"draw": [], "prims": []}
	for _i in 12:
		await RenderingServer.frame_post_draw
		for k in keys:
			(seen[k] as Array).append(RenderingServer.get_rendering_info(keys[k]))
	var out := {}
	for k in keys:
		var a: Array = seen[k]
		a.sort()
		out[k] = a[a.size() / 2]
	return out


# ============================================================== the swap

func _swap() -> void:
	var models: Dictionary = _rig.get("models")
	var model: Node3D = models[_weapon]
	for child in model.get_children():
		if not String(child.name) in RIG_OWNED:
			child.queue_free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(_glb, state) != OK:
		push_error("[int] could not read " + _glb)
		quit(1)
		return
	var scene := doc.generate_scene(state) as Node3D
	scene.name = "WeaponArt"
	model.add_child(scene)
	if _lean != "":
		_apply_lean(scene)
	var parts: Dictionary = _rig.get("_parts")
	var names: Dictionary = PARTS.get(_weapon, {})
	for key in names:
		var node := scene.find_child(String(names[key]), true, false) as Node3D
		if node == null:
			push_error("[int] %s has no %s" % [_glb, names[key]])
			continue
		parts[_weapon + "/" + key] = node
	if _weapon == "foundry":
		# the study's adapter: Prod's _index_drum writes Basis(RIGHT, PI/2)
		# * Basis(UP, a) for his Y-up drum; the art's carousel turns on Z
		var carousel := parts["foundry/cylinder"] as Node3D
		var drive := Node3D.new()
		drive.name = "CarouselDrive"
		carousel.get_parent().add_child(drive)
		drive.position = carousel.position
		drive.basis = Basis(Vector3.RIGHT, PI / 2.0)
		carousel.get_parent().remove_child(carousel)
		drive.add_child(carousel)
		carousel.position = Vector3.ZERO
		carousel.basis = Basis(Vector3.RIGHT, -PI / 2.0)
		parts["foundry/cylinder"] = drive
	var core := parts.get("driver/core") as MeshInstance3D
	if _weapon == "driver" and core != null:
		var own := core.mesh.surface_get_material(0) as StandardMaterial3D
		var glow := own.duplicate() as StandardMaterial3D if own != null \
				else StandardMaterial3D.new()
		glow.emission_enabled = true
		glow.emission_texture = null
		glow.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
		glow.emission = Color(0.85, 0.85, 1.0)        # Prod's own glow colour
		glow.emission_energy_multiplier = 0.0
		core.material_override = glow


func _apply_lean(scene: Node) -> void:
	var rec = JSON.parse_string(FileAccess.get_file_as_string(
			_lean.path_join("lean.json")))
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.albedo_texture = _tex("albedo.png")
	m.normal_enabled = true
	m.normal_texture = _tex("normal.png")
	m.roughness = 1.0
	m.roughness_texture = _tex("roughness.png")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.metallic = 1.0
	m.metallic_texture = _tex("metallic.png")
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.emission_enabled = true
	m.emission_texture = _tex("emission.png")
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	var c: Array = rec["emission_colour_srgb"]
	m.emission = Color(c[0], c[1], c[2])
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, m)


func _tex(file: String) -> ImageTexture:
	var img := Image.load_from_file(_lean.path_join(file))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ================================================================ helpers

func _aim(at: Vector3) -> void:
	var cam: Node3D = _body.get("camera")
	var eye := cam.global_position
	var flat := Vector2(at.x - eye.x, at.z - eye.z)
	_body.rotation.y = atan2(-flat.x, -flat.y)
	cam.rotation.x = atan2(at.y - eye.y, flat.length())


func _settle(frames: int) -> void:
	for _i in frames:
		await physics_frame


## The player's view; with a second viewport, it too, side by side under
## `<name>_near.png` (or only it, for a close-up).
func _shoot(name: String, near: SubViewport = null, only_near := false) \
		-> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if not only_near:
		root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	if near != null:
		near.get_texture().get_image().save_png(
				_out.path_join(name + ("" if only_near else "_near") + ".png"))
	print("[int] shot ", name)


func _write(name: String, data: Dictionary) -> void:
	var f := FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " ", true))
	f.close()
