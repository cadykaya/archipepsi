extends SceneTree
## Repair 2026-09-28, family 049 -- the before/after frames for the hinges.
##
##   godot --path godot -s _harness/poseview.gd -- <old-models> <new-models> <out>
##
## Three frames per hinged control, one rig, one camera:
##   <id>_0_rest.png    the repaired model as built (the old one is identical
##                      at rest -- verify_049_hinges.py proves it)
##   <id>_1_old.png     the reviewed model (a1584c8), its moving part's OWN
##                      node turned to the declared angle: what a runtime
##                      could do before, about the asset origin
##   <id>_2_new.png     the repaired model, its hinge turned to the same
##                      angle, with whatever that position hides hidden
##
## The moving parts carry a flat magenta REVIEW TINT so the eye finds them;
## it is this harness talking, not a colour proposal. Loading the new file
## through GLTFDocument and turning the hinge by name is also the check that
## the runtime's importer sees the hinge the manifest declares.

const SHOTS := [
	# id, old moving nodes, hinge, axis, degrees, position, look, eye, wall
	["conn_hold_paddle", ["paddle_arm", "paddle_grip"], "hinge_paddle",
		Vector3.RIGHT, 22.0, "held", Vector3(0, 0.6, 0.05),
		Vector3(1.25, 0.95, 0.75), true, []],
	["conn_repair_seal", ["seal_lever"], "hinge_seal_lever", Vector3.RIGHT,
		90.0, "thrown", Vector3(0, 0.17, 0.08), Vector3(0.9, 0.55, 0.85),
		true, ["seal_tab_left", "seal_tab_right"]],
	["conn_breaker", ["breaker_handle"], "hinge_breaker", Vector3.RIGHT,
		30.0, "thrown", Vector3(0, 0.33, 0.05), Vector3(0.95, 0.6, 0.75),
		true, []],
	["conn_flag_ack", ["flag_blade"], "hinge_flag", Vector3.RIGHT, 90.0,
		"up", Vector3(0, 0.62, -0.1), Vector3(1.6, 1.05, 0.55), false, []],
	["conn_set_dial", ["dial_knob", "dial_pointer"], "hinge_dial",
		Vector3.BACK, 45.0, "detent_3", Vector3(0, 0.15, 0.0),
		Vector3(0.28, 0.42, 0.78), true, []],
	["conn_gauge", ["gauge_needle"], "hinge_gauge", Vector3.BACK, -90.0,
		"full", Vector3(0, 0.13, 0.0), Vector3(0.22, 0.34, 0.66), true, []],
]

var _old: String
var _new: String
var _out: String
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		_fail("usage: -- <old-models> <new-models> <out-dir>")
	else:
		_old = a[0]
		_new = a[1]
		_out = a[2]
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[poseview] FAIL: %s" % what)


func _stage() -> Array:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(720, 540), 0.42)
	var root := Node3D.new()
	view.add_child(root)
	_bench.call("add_lights", root, 1.5)
	return [view, root]


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


func _tint(node: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.36, 0.78)
	mat.roughness = 0.9
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = mat
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat


func _frame(path: String, shot: Array, mode: int, name: String) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	var model: Node3D = _bench.call("load_glb", path)
	if model == null:
		_fail("could not load %s" % path)
		view.queue_free()
		return
	root.add_child(model)
	_bench.call("force_nearest", model)
	var box: AABB = _bench.call("aabb_of", model)
	_slab(root, Vector3(4, 0.1, 4), Vector3(0, -0.05, 0))
	if bool(shot[8]):
		# The wall a wall-mounted control stands on, flush with its back.
		_slab(root, Vector3(4, 3, 0.1), Vector3(0, 1.5, box.position.z - 0.05))
	var axis: Vector3 = shot[3]
	var angle := deg_to_rad(float(shot[4]))
	if mode == 1:
		# BEFORE: the reviewed file has no hinge, so the only thing a runtime
		# could turn is the part's own node -- about the asset origin.
		for part_name: Variant in shot[1]:
			var part := model.find_child(str(part_name), true, false) as Node3D
			if part == null:
				_fail("%s: no node %s in the old file" % [shot[0], part_name])
				continue
			part.rotate_object_local(axis, angle)
			_tint(part)
	else:
		var hinge := model.find_child(str(shot[2]), true, false) as Node3D
		if hinge == null:
			_fail("%s: the importer produced no %s" % [shot[0], shot[2]])
		else:
			var kids := hinge.get_children().map(func(n): return str(n.name))
			for part_name: Variant in shot[1]:
				if not kids.has(str(part_name)):
					_fail("%s: %s is not under %s after import"
						% [shot[0], part_name, shot[2]])
			if mode == 2:
				hinge.rotate_object_local(axis, angle)
				for hidden: Variant in shot[9]:
					var gone := model.find_child(str(hidden), true, false)
					if gone != null:
						(gone as Node3D).visible = false
			_tint(hinge)
	var cam := Camera3D.new()
	cam.fov = 40.0
	view.add_child(cam)
	cam.global_position = shot[7]
	cam.look_at(shot[6], Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[poseview] %s.png" % name)
	view.queue_free()


func _run() -> void:
	for raw: Variant in SHOTS:
		var shot: Array = raw
		var id := str(shot[0])
		await _frame("%s/batch049/connect/%s.glb" % [_new, id], shot, 0,
			"%s_0_rest" % id)
		await _frame("%s/batch049/connect/%s.glb" % [_old, id], shot, 1,
			"%s_1_old" % id)
		await _frame("%s/batch049/connect/%s.glb" % [_new, id], shot, 2,
			"%s_2_new" % id)
	if _problems.is_empty():
		print("[poseview] %d frame(s)" % _made)
		quit(0)
	else:
		quit(1)
