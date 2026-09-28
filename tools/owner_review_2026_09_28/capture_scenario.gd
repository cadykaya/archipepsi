extends SceneTree
## Owner review 2026-09-28: photograph one of Production's own minor-room
## scenarios as it stands at the pinned revision, for a fair "today"
## frame beside the candidate kit.
##
##   godot --path <scratch copy of Production>/godot --rendering-driver opengl3 \
##       -s res://_review/capture_scenario.gd -- --counterfire --out=<dir>
##
## Runs ONLY on a scratch `git archive` of Production, never on its
## worktree. It loads Production's main scene unchanged; main.gd reads the
## scenario flag and builds the room exactly as a launcher would. Then:
##   * `<name>_player.png`: what the player's own camera sees at spawn;
##   * `<name>_wide.png`: a second camera, framed on the room's visible
##     bounds from a high oblique (a review view, and labelled so).
## Asserts nothing. Diagnostic frames only.

var _out := ""
var _name := ""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--") and _name == "":
			_name = a.substr(2)
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 90:
		await process_frame
	var cam := root.get_viewport().get_camera_3d()
	if cam != null:
		# The player's own camera, turned in place through four headings:
		# the spawn heading can face a wall. Height and position are the
		# player's; only the yaw turns.
		for q in 4:
			await _save("%s_player_%03d" % [_name, q * 90])
			cam.rotate_y(deg_to_rad(90.0))
			for i in 4:
				await process_frame
	# The wide view: frame every visible mesh the scenario built.
	var box := AABB()
	var first := true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		if b.size.length() > 400.0:
			continue
		box = b if first else box.merge(b)
		first = false
	if not first:
		var wide := Camera3D.new()
		root.add_child(wide)
		wide.fov = 60.0
		var c := box.get_center()
		var r := box.size.length() * 0.62
		wide.look_at_from_position(c + Vector3(r * 0.55, r * 0.62, r * 0.8), c)
		wide.make_current()
		for i in 6:
			await process_frame
		await _save("%s_wide" % _name)
	print("[capture] %s done" % _name)
	quit()


func _save(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out)
	img.save_png("%s/%s.png" % [_out, stem])
	print("[capture] %s/%s.png" % [_out, stem])
