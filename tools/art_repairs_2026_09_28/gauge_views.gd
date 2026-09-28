extends SceneTree
## Repair 2026-09-28, follow-up: the gauge read straight on, at every
## declared reading, before and after its bezel was opened.
##
##   godot --path godot -s _harness/gaugeview.gd -- <old.glb> <new.glb>
##       <manifest.json> <out-dir>
##
## Both files are turned by the SAME hinge to the manifest's own
## positions, in their real materials (no tint): the only difference in
## the frames is the bezel. Two views per reading and file: straight on,
## the way a reading is taken, and from 35 degrees to the side, to show
## the face sits back in the window with the needle in front of it.

var _problems: Array[String] = []
var _bench: GDScript
var _made := 0


func _init() -> void:
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
		quit(1)
		return
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[gaugeview] FAIL: %s" % what)


func _slab(root: Node3D, size: Vector3, at: Vector3) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.38, 0.41)
	mat.roughness = 1.0
	node.set_surface_override_material(0, mat)
	root.add_child(node)
	node.position = at


func _frame(path: String, degrees: float, eye: Vector3, out: String) -> void:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(560, 560), 0.42)
	var root := Node3D.new()
	view.add_child(root)
	_bench.call("add_lights", root, 1.5)
	var model: Node3D = _bench.call("load_glb", path)
	if model == null:
		_fail("could not load %s" % path)
		view.queue_free()
		return
	root.add_child(model)
	_bench.call("force_nearest", model)
	# The wall it is mounted on, flush with the case's back (runtime -Z).
	_slab(root, Vector3(3, 3, 0.1), Vector3(0, 0.6, -0.14 - 0.05))
	var hinge := model.find_child("hinge_gauge", true, false) as Node3D
	if hinge == null:
		_fail("%s: the importer produced no hinge_gauge" % path)
	else:
		hinge.rotate_object_local(Vector3.BACK, deg_to_rad(degrees))
	var cam := Camera3D.new()
	cam.fov = 30.0
	view.add_child(cam)
	cam.global_position = eye
	cam.look_at(Vector3(0, 0.15, 0.0), Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	if image.save_png(out) != OK:
		_fail("could not write %s" % out)
	else:
		_made += 1
		print("[gaugeview] %s" % out.get_file())
	view.queue_free()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		_fail("usage: -- <old.glb> <new.glb> <manifest.json> <out-dir>")
		quit(1)
		return
	var manifest: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(a[2]))
	if not manifest is Dictionary:
		_fail("could not read %s" % a[2])
		quit(1)
		return
	var positions: Dictionary = manifest["conn_gauge"]["hinge"]["positions_degrees"]
	var views := {"front": Vector3(0, 0.15, 1.05),
			"side": Vector3(0.6, 0.3, 0.86)}
	for pose: String in ["empty", "half", "full"]:
		if not positions.has(pose):
			_fail("the manifest declares no '%s'" % pose)
			continue
		for which: String in ["old", "new"]:
			for view: String in views:
				await _frame(a[0] if which == "old" else a[1],
						float(positions[pose]), views[view],
						"%s/gauge_%s_%s_%s.png" % [a[3], pose, which, view])
	if _problems.is_empty():
		print("[gaugeview] %d frame(s)" % _made)
		quit(0)
	else:
		quit(1)
