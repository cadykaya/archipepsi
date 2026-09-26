extends SceneTree
## Track A2 -- runs ONE study's timeline in virtual time and captures every
## frame at 1920 x 1080, 30 frames a second.
##
##   -s _harness/menu_studies.gd -- <out dir> <study> <motion|reduced>
##
## A study is `study_<name>.gd`: it builds its faces from the sample data,
## and returns a timeline of `[t, Callable, label?]` events -- the SAME
## events in both modes. In `reduced` the kit sets every state at once, so
## the reduced-motion capture is the same interaction with the travel cut
## out, frame for frame beside the motion one.
##
## `manifest.json` records the frames and each labelled moment, so the
## sheets are cut from the capture rather than staged separately.

const FPS := 30.0
const SHOT := Vector2i(1920, 1080)
const H := "res://_harness"

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run.call_deferred()
	return false


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("[studies] need <out dir> <study> <motion|reduced>")
		quit(1)
		return
	var out: String = args[0]
	var name: String = args[1]
	var mode: String = args[2]
	DirAccess.make_dir_recursive_absolute(out)

	var view := SubViewport.new()
	view.size = SHOT
	view.own_world_3d = true
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	world.name = "Box"
	view.add_child(world)
	var env := WorldEnvironment.new()
	var look := Environment.new()
	look.background_mode = Environment.BG_COLOR
	look.background_color = Color("#0d0f12")
	look.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	look.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.environment = look
	world.add_child(env)

	var Kit: GDScript = load(H + "/study_kit.gd")
	var Overlay: GDScript = load(H + "/study_overlay.gd")
	var Study: GDScript = load("%s/study_%s.gd" % [H, name])
	# A script that does not compile must END the run: a SceneTree left
	# ticking after a fault never quits, and a capture that hangs says
	# nothing (the lesson godot_run.sh records).
	for script: GDScript in [Kit, Overlay, Study]:
		if script == null or not script.can_instantiate():
			push_error("[studies] a study script did not compile")
			quit(1)
			return
	var kit: RefCounted = Kit.new(world, H)
	kit.set("reduced", mode == "reduced")
	var overlay: RefCounted = Overlay.new(view, kit, H)
	var content: Dictionary = _json(H + "/content.json")
	var layout: Dictionary = _json(H + "/layout.json")
	var source: Dictionary = _json(H + "/SOURCE.json")
	var study: RefCounted = Study.new(kit, overlay, content, layout)
	overlay.call("caption", [study.call("title"),
		"SAMPLE DATA -- PRODUCTION'S OWN FIXTURES AT %s. A STUDY, NOT THE MENU." \
			% str(source.get("production_rev", "?")),
		"MOTION" if mode == "motion" else "REDUCED MOTION -- THE SAME STEPS, CUT"])

	var events: Array = study.call("timeline")
	var end_t: float = study.call("duration")
	# MENU_STUDY_ONLY_STILLS: step every frame (so every animation runs
	# exactly as in the full capture) but draw and keep only the stills --
	# for looking at a layout without waiting for 270 frames.
	var only := {}
	if OS.get_environment("MENU_STUDY_ONLY_STILLS") != "":
		for still: Array in study.call("stills"):
			only[int(round(float(still[0]) * FPS))] = true
	var marks: Array = []
	var frame := 0
	var ei := 0
	while float(frame) / FPS <= end_t + 0.0001:
		var now := float(frame) / FPS
		# An event starts its animations at ITS time: the frame it lands on
		# shows the change just begun, not already a frame in.
		kit.set("t", now)
		while ei < events.size() and float(events[ei][0]) <= now + 0.0001:
			var ev: Array = events[ei]
			(ev[1] as Callable).call()
			if ev.size() > 2:
				marks.append({"label": str(ev[2]), "t": float(ev[0]),
					"frame": frame})
			ei += 1
		kit.call("step", now)
		if not only.is_empty() and not only.has(frame):
			frame += 1
			continue
		await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		if image.save_png("%s/frame_%04d.png" % [out, frame]) != OK:
			push_error("[studies] could not write frame %d" % frame)
			quit(1)
			return
		frame += 1
	var stills: Array = study.call("stills")
	var manifest := {"study": name, "mode": mode, "fps": FPS,
		"frames": frame, "size": [SHOT.x, SHOT.y], "marks": marks,
		"stills": stills, "title": study.call("title"),
		"source": source}
	var f := FileAccess.open(out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, " ", true))
	f.close()
	print("[studies] %s/%s: %d frames -> %s" % [name, mode, frame, out])
	quit(0)
