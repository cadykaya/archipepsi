extends SceneTree
## THE FOUR-WEAPON FORM PASS, IN THE REAL GAME (Arty, 2026-10-13).
## NON-PRODUCTION. Run against a READ-ONLY checkout of Prod's
## `review/five-weapons-v3`; it edits none of Prod's files.
##
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --rendering-driver opengl3 \
##       --path <checkout>/godot --resolution 1600x900 \
##       -s res://tests/_arty_weapon_forms.gd -- --five-weapons \
##       --weapon=<id> [--variant=<v>] --glb=<form.glb> --out=<dir> --tag=<name>
##
## It loads the game's own main scene with `--five-weapons`, so the range,
## the player, `RangeWeapons` and `RangeRig` are Prod's, running as they run
## for the owner. Then, IN THIS PROCESS'S MEMORY ONLY, it swaps the chosen
## weapon's primitive placeholder for a clay form proposal and points Prod's
## moving parts at the proposal's nodes, by the names his rig already uses:
##
##   sightline/handle  -> `Handle`     switchback/bolt -> `Bolt`
##   bulkhead/pump     -> `Pump`       bulkhead/feed   -> `Feed`
##   driver/coils      -> `Coils`      driver/core     -> `Core`
##
## One adapter, a fit question for Prod: his driver writes the charge glow
## through `core.material_override` (a StandardMaterial3D his placeholder
## builds). A GLB mesh arrives with its material on the mesh, so the capture
## hands `Core` an override of the same kind, coloured as the clay core.
##
## Stills, each from the player's own eye:
##   <tag>_rest   the weapon at rest, hip
##   <tag>_ads    aimed down the sights (the weapons Prod gives ADS)
##   <tag>_fire   two frames after a shot through the real input action
##                (charged for the Mass Driver: held, then released)
##   <tag>_charge the Mass Driver mid-charge: coils spinning, core lit

const AIM := Vector3(0, 1.2, -10)          # Prod's check aims here too
const ADS_ALT := "range_ads_alt"
const RIG_OWNED := ["Muzzle", "ChargeOrb", "ChargeLight"]
const PARTS := {
	"sightline": {"handle": "Handle"},
	"switchback": {"bolt": "Bolt"},
	"bulkhead": {"pump": "Pump", "feed": "Feed"},
	"driver": {"coils": "Coils", "core": "Core"},
}

var _out := ""
var _glb := ""
var _weapon := ""
var _variant := ""
var _tag := ""
var _host: Node = null
var _body: Node3D = null
var _weapons: Node = null
var _rig: Node3D = null


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--glb="):
			_glb = arg.trim_prefix("--glb=")
		elif arg.begins_with("--weapon="):
			_weapon = arg.trim_prefix("--weapon=")
		elif arg.begins_with("--variant="):
			_variant = arg.trim_prefix("--variant=")
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
	if _tag == "":
		_tag = _weapon
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file(str(ProjectSettings.get_setting(
			"application/run/main_scene")))
	_run.call_deferred()


func _run() -> void:
	for _i in 600:
		await physics_frame
		var scene := current_scene
		if scene != null:
			_host = scene.get_node_or_null("WeaponFeel")
		if _host != null and bool(_host.get("five")):
			break
	if _host == null:
		push_error("[forms] the five-weapon range never came up")
		quit(1)
		return
	_body = _host.get("player")
	_weapons = _host.get("weapons")
	_rig = _weapons.get("rig")
	_host.call("select_five", _weapon)
	for node in root.find_children("*", "CanvasLayer", true, false):
		if (node as CanvasLayer).layer == 5:
			(node as CanvasLayer).visible = false
	if _glb != "":
		_swap()
	# re-select through Prod's own path, so his `select` sets the variant's
	# feed visibility on the swapped node
	if _variant != "":
		_weapons.call("set_variant", _weapon, _variant)
	else:
		_weapons.call("select", _weapon)
	_aim(AIM)
	await _settle(45)
	await _shoot(_tag + "_rest")
	if (_weapons.get("_profile") as Dictionary).has("ads"):
		Input.action_press(ADS_ALT)
		await _settle(40)
		await _shoot(_tag + "_ads")
		Input.action_release(ADS_ALT)
		await _settle(40)
	if _weapon == "driver":
		Input.action_press("fire_pulse")
		await _settle(42)
		await _shoot(_tag + "_charge")
		await _settle(30)
		Input.action_release("fire_pulse")
		await _settle(2)
		await _shoot(_tag + "_fire")
	else:
		Input.action_press("fire_pulse")
		await _settle(2)
		Input.action_release("fire_pulse")
		await _shoot(_tag + "_fire")
	await _settle(90)
	quit(0)


# ============================================================== the swap

func _swap() -> void:
	var models: Dictionary = _rig.get("models")
	var model: Node3D = models[_weapon]
	# the placeholder's geometry goes; the children the rig itself owns and
	# holds by reference (the muzzle marker, the driver's charge orb and
	# light) stay where Prod put them
	for child in model.get_children():
		if not String(child.name) in RIG_OWNED:
			child.queue_free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_glb, state)
	if err != OK:
		push_error("[forms] could not read %s (%d)" % [_glb, err])
		quit(1)
		return
	var scene := doc.generate_scene(state) as Node3D
	scene.name = "WeaponForm"
	model.add_child(scene)
	var parts: Dictionary = _rig.get("_parts")
	var names: Dictionary = PARTS.get(_weapon, {})
	for key in names:
		var node := scene.find_child(String(names[key]), true, false) as Node3D
		if node == null:
			push_error("[forms] %s has no %s" % [_glb, names[key]])
			continue
		parts[_weapon + "/" + key] = node
		print("[forms] %s/%s -> %s" % [_weapon, key, node.get_path()])
	var core := parts.get("driver/core") as MeshInstance3D
	if _weapon == "driver" and core != null:
		var clay := core.mesh.surface_get_material(0) as BaseMaterial3D
		var glow := StandardMaterial3D.new()
		glow.albedo_color = clay.albedo_color if clay else Color(0.15, 0.16, 0.2)
		glow.roughness = 0.3
		glow.emission_enabled = true
		glow.emission = Color(0.85, 0.85, 1.0)        # Prod's own glow colour
		glow.emission_energy_multiplier = 0.0
		core.material_override = glow


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


func _shoot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	print("[forms] shot ", name)
