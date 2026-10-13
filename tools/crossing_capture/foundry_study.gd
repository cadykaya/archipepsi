extends SceneTree
## THE FOUNDRY FIDELITY STUDY, IN THE REAL GAME (Arty, 2026-10-13).
## NON-PRODUCTION. Run against a READ-ONLY checkout of Prod's
## `review/five-weapons-v2`; it edits none of Prod's files.
##
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --rendering-driver opengl3 \
##       --path <checkout>/godot --resolution 1600x900 [--fixed-fps 60 \
##       --write-movie <out>/clip.avi] -s res://tests/_arty_foundry_study.gd \
##       -- --five-weapons --glb=<foundry_study.glb> --out=<dir> \
##       --mode=stills|clip|move|placeholder
##
## It loads the game's own main scene with `--five-weapons`, so the range,
## the player, `RangeWeapons`, `RangeRig`, Condi's sounds and the engine's
## hits are all Prod's, running as they run for the owner. Then, IN THIS
## PROCESS'S MEMORY ONLY, it swaps the Foundry's primitive placeholder for
## the study model and points Prod's two moving parts at the study's:
##
##   foundry/hammer    -> the study's `Hammer` (Prod rotates x: 0 fallen,
##                        -38 cocked -- the same node, Prod's own numbers)
##   foundry/cylinder  -> a `CarouselDrive` node holding the study's
##                        `Carousel`. Prod's `_index_drum` writes
##                        Basis(RIGHT, PI/2) * Basis(UP, a) to its drum (its
##                        placeholder is a Y-up cylinder turned onto Z); the
##                        drive carries that, and the carousel inside it is
##                        turned back by -PI/2, so the runtime's own index
##                        turns the carousel about the bore. (A fit question
##                        for Prod: see the study's handoff.)
##
## Modes:
##   placeholder  Prod's Foundry as it is, at rest (the comparison frame).
##   stills       the study at rest from the eye, then close looks at it
##                from cameras placed in the gun's own frame, in the
##                range's own light.
##   clip         three shots fired through the real input action, one as
##                soon as the weapon is ready; every frame records the
##                hammer, the carousel and Prod's clocks to clip.json. Run
##                with --write-movie: the movie maker writes real time at
##                the fixed rate, sound included.
##   move         (added 2026-10-13, for v3) strafing left then right while
##                firing twice; every frame records the hammer, the
##                player's x and the cooldown to move.json.
##
## Also run unchanged against `review/five-weapons-v3` (ef157061).

const AIM := Vector3(0, 1.2, -10)          # Prod's check aims here too
const SHOTS := 3

var _out := ""
var _glb := ""
var _mode := "stills"
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
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
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
		push_error("[study] the five-weapon range never came up")
		quit(1)
		return
	_body = _host.get("player")
	_weapons = _host.get("weapons")
	_rig = _weapons.get("rig")
	_host.call("select_five", "foundry")
	# the range's own instruction text (its layer-5 overlay) is hidden for
	# clean frames; the game's HUD stays
	for node in root.find_children("*", "CanvasLayer", true, false):
		if (node as CanvasLayer).layer == 5:
			(node as CanvasLayer).visible = false
	if _mode != "placeholder":
		_swap()
	_aim(AIM)
	await _settle(45)
	match _mode:
		"placeholder":
			await _shoot("placeholder_fp")
		"stills":
			await _stills()
		"clip":
			await _clip()
		"move":
			await _move()
	quit(0)


# ============================================================== the swap

func _swap() -> void:
	var models: Dictionary = _rig.get("models")
	var model: Node3D = models["foundry"]
	for child in model.get_children():
		if child.name != "Muzzle":
			child.queue_free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_glb, state)
	if err != OK:
		push_error("[study] could not read %s (%d)" % [_glb, err])
		quit(1)
		return
	var scene := doc.generate_scene(state) as Node3D
	scene.name = "FoundryStudy"
	model.add_child(scene)
	_nearest(scene)
	var hammer := scene.find_child("Hammer", true, false) as Node3D
	var carousel := scene.find_child("Carousel", true, false) as Node3D
	var drive := Node3D.new()
	drive.name = "CarouselDrive"
	carousel.get_parent().add_child(drive)
	drive.position = carousel.position
	drive.basis = Basis(Vector3.RIGHT, PI / 2.0)        # _index_drum(0)
	carousel.get_parent().remove_child(carousel)
	drive.add_child(carousel)
	carousel.position = Vector3.ZERO
	carousel.basis = Basis(Vector3.RIGHT, -PI / 2.0)
	var parts: Dictionary = _rig.get("_parts")
	parts["foundry/hammer"] = hammer
	parts["foundry/cylinder"] = drive
	hammer.rotation_degrees.x = -38.0                    # ready: cocked
	print("[study] swapped: hammer %s, carousel %s" % [hammer.get_path(),
			carousel.get_path()])


## The bible's filter: NEAREST, with mipmaps (made here, as a runtime-read
## glTF image carries none).
func _nearest(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			for param in [BaseMaterial3D.TEXTURE_ALBEDO,
					BaseMaterial3D.TEXTURE_NORMAL,
					BaseMaterial3D.TEXTURE_ROUGHNESS,
					BaseMaterial3D.TEXTURE_METALLIC,
					BaseMaterial3D.TEXTURE_EMISSION]:
				var tex := mat.get_texture(param)
				if tex == null:
					continue
				var img := tex.get_image()
				if img == null or img.has_mipmaps():
					continue
				img.generate_mipmaps()
				mat.set_texture(param, ImageTexture.create_from_image(img))


# ================================================================ stills

func _stills() -> void:
	await _shoot("study_fp")
	# close looks: cameras in the gun model's own frame (Godot viewmodel
	# space), so they find it wherever the rig holds it
	var model: Node3D = (_rig.get("models") as Dictionary)["foundry"]
	var cams := {
		"close_left": [Vector3(-0.17, 0.06, 0.07), Vector3(-0.01, 0.01, -0.03), 34.0],
		"close_top": [Vector3(-0.05, 0.19, 0.14), Vector3(0.0, 0.045, -0.05), 32.0],
		"close_collar": [Vector3(-0.14, 0.09, -0.04), Vector3(-0.02, 0.025, -0.13), 30.0],
		"close_muzzle": [Vector3(-0.12, 0.07, -0.56), Vector3(0.0, 0.02, -0.40), 34.0],
		"close_rear": [Vector3(-0.05, 0.10, 0.22), Vector3(0.0, 0.03, -0.02), 30.0],
		"whole_left": [Vector3(-0.62, 0.10, -0.16), Vector3(0.0, -0.01, -0.17), 34.0],
	}
	var cam := Camera3D.new()
	cam.near = 0.005
	root.add_child(cam)
	var player_cam: Camera3D = _body.get("camera")
	for name in cams:
		var spec: Array = cams[name]
		var xf := model.global_transform
		cam.global_position = xf * (spec[0] as Vector3)
		cam.look_at(xf * (spec[1] as Vector3), xf.basis.y)
		cam.fov = float(spec[2])
		cam.make_current()
		await _settle(3)
		await _shoot(name)
	player_cam.make_current()
	cam.queue_free()


# ================================================================== clip

func _clip() -> void:
	var hammer: Node3D = _rig.call("part", "hammer")
	var drive: Node3D = _rig.call("part", "cylinder")
	var frames: Array = []
	var shots: Array = []
	var frame := 0
	var fired := 0
	var next_at := 30                     # frames of rest before the first
	var release_at := -1
	var log_until := -1
	var last_cd := 0.0
	var waiting_fire := false
	const NEVER := 1 << 30
	while true:
		if fired < SHOTS and frame >= next_at:
			Input.action_press("fire_pulse")
			shots.append({"frame": frame, "drawn": Engine.get_frames_drawn()})
			fired += 1
			release_at = frame + 2
			next_at = NEVER
			waiting_fire = true
		if frame == release_at:
			Input.action_release("fire_pulse")
		await physics_frame
		var rt: Object = _weapons.get("runtime")
		var cd := float(rt.get("cooldown_remaining"))
		frames.append({"f": frame, "drawn": Engine.get_frames_drawn(),
				"hammer_deg": snappedf(hammer.rotation_degrees.x, 0.01),
				# Rx(90)*Ry(a) carries X to (cos a, sin a, 0): the angle
				# about the bore
				"carousel_deg": snappedf(rad_to_deg(atan2(drive.basis.x.y,
						drive.basis.x.x)), 0.01),
				"cooldown": snappedf(cd, 0.001),
				"back": snappedf(float(_rig.call("displacement", "back")), 0.0001),
				"view_pitch_deg": snappedf(rad_to_deg((_body.get("camera")
						as Node3D).rotation.x), 0.001),
				"pitch": snappedf(float(_rig.call("displacement", "pitch")), 0.01)})
		# the next press 0.1 s before the weapon is ready: inside Prod's
		# 0.15 s buffer, so it fires the instant it is ready -- a player
		# clicking in rhythm, the owner's 0.72 s
		# a shot has fired when the cooldown jumps back up
		if cd > last_cd + 0.3:
			waiting_fire = false
		last_cd = cd
		if fired < SHOTS and next_at == NEVER and not waiting_fire \
				and frame > release_at and cd <= 0.10:
			next_at = frame + 1
		if fired == SHOTS and not waiting_fire and log_until < 0:
			log_until = frame + 75
		if log_until > 0 and frame >= log_until:
			break
		frame += 1
	var clocks: Dictionary = _weapons.get("clocks")
	var f := FileAccess.open(_out.path_join("clip.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": Engine.physics_ticks_per_second,
			"shots": shots, "last_clocks": clocks, "frames": frames}, " "))
	f.close()
	print("[study] clip: %d shots, %d frames logged" % [shots.size(),
			frames.size()])


# ============================================================ moving

## Walking with it: strafe left, fire on the move, strafe right, fire
## again -- the gun's bob and sway are Prod's, the hammer and carousel
## his runtime's. Logged like the clip, to move.json.
func _move() -> void:
	var hammer: Node3D = _rig.call("part", "hammer")
	var frames: Array = []
	var plan := {0: ["move_left", true], 50: ["move_left", false],
			56: ["move_right", true], 110: ["move_right", false]}
	var fire_at := [25, 85]
	for frame in 170:
		if plan.has(frame):
			var step: Array = plan[frame]
			if step[1]:
				Input.action_press(step[0])
			else:
				Input.action_release(step[0])
		if frame in fire_at:
			Input.action_press("fire_pulse")
		if frame - 2 in fire_at:
			Input.action_release("fire_pulse")
		await physics_frame
		frames.append({"f": frame, "drawn": Engine.get_frames_drawn(),
				"hammer_deg": snappedf(hammer.rotation_degrees.x, 0.01),
				"x": snappedf(_body.global_position.x, 0.001),
				"cooldown": snappedf(float((_weapons.get("runtime") as Object)
						.get("cooldown_remaining")), 0.001)})
	var f := FileAccess.open(_out.path_join("move.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames": frames}, " "))
	f.close()
	print("[study] move: %d frames logged" % frames.size())


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
	print("[study] shot ", name)
