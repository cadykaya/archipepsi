extends SceneTree
## Repair 2026-09-28 -- before/after frames for the skiff and the panels.
##
##   godot --path godot -s _harness/tintview.gd -- <shots.json> <out-dir>
##
## One frame per shot: a model loaded through GLTFDocument (the importer's
## own path), one rig, one camera, and -- only where a shot asks -- named
## nodes given a flat REVIEW TINT and a ground arrow. Tints are this harness
## talking, never a colour proposal, and every sheet built from these says
## so. A shot that names a node the file does not have FAILS: that is also
## the check that the importer sees the names the manifests declare.
##
## shots.json: [{"name", "glb", "eye": [x,y,z], "look": [x,y,z],
##               "tint": {"node": [r,g,b]}, "arrow": [x, z, dx, dz, length],
##               "floor_y": y}]

var _bench: GDScript
var _problems: Array[String] = []
var _made := 0


func _init() -> void:
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[tintview] FAIL: %s" % what)


func _v3(raw: Variant) -> Vector3:
	var a: Array = raw
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _flat(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	return mat


func _shot(shot: Dictionary, out: String) -> void:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(760, 520), 0.45)
	var root := Node3D.new()
	view.add_child(root)
	_bench.call("add_lights", root, 1.5)
	var model: Node3D = _bench.call("load_glb", str(shot["glb"]))
	if model == null:
		_fail("could not load %s" % shot["glb"])
		view.queue_free()
		return
	root.add_child(model)
	_bench.call("force_nearest", model)
	var floor := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(12, 0.1, 12)
	floor.mesh = slab
	floor.material_override = _flat(Color(0.36, 0.38, 0.41))
	root.add_child(floor)
	floor.position = Vector3(0, float(shot.get("floor_y", 0.0)) - 0.05, 0)
	var tints: Dictionary = shot.get("tint", {})
	for node_name: Variant in tints:
		var node := model.find_child(str(node_name), true, false)
		if node == null or not node is MeshInstance3D:
			_fail("%s: no mesh node %s" % [shot["name"], node_name])
			continue
		var c: Array = tints[node_name]
		(node as MeshInstance3D).material_override = _flat(
				Color(float(c[0]), float(c[1]), float(c[2])))
	if shot.has("arrow"):
		# A flat arrow on the ground: shaft and head, pointing along (dx, dz).
		var a: Array = shot["arrow"]
		var from := Vector3(float(a[0]), float(shot.get("floor_y", 0.0))
				+ 0.02, float(a[1]))
		var dir := Vector3(float(a[2]), 0, float(a[3])).normalized()
		var length := float(a[4])
		var shaft := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.02, length)
		shaft.mesh = box
		shaft.material_override = _flat(Color(0.95, 0.95, 0.95))
		root.add_child(shaft)
		shaft.position = from + dir * length * 0.5
		shaft.look_at(from + dir * length + Vector3(0, 0.0001, 0), Vector3.UP)
		for side: float in [-1.0, 1.0]:
			var barb := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.02, 0.6)
			barb.mesh = b
			barb.material_override = shaft.material_override
			root.add_child(barb)
			var tip := from + dir * length
			var back := dir.rotated(Vector3.UP, side * 0.6)
			barb.position = tip - back * 0.3
			barb.look_at(tip + Vector3(0, 0.0001, 0), Vector3.UP)
	var cam := Camera3D.new()
	cam.fov = 40.0
	view.add_child(cam)
	cam.global_position = _v3(shot["eye"])
	cam.look_at(_v3(shot["look"]), Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	if image.save_png("%s/%s.png" % [out, shot["name"]]) != OK:
		_fail("could not write %s" % shot["name"])
	else:
		_made += 1
		print("[tintview] %s.png" % shot["name"])
	view.queue_free()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <shots.json> <out-dir>")
		quit(1)
		return
	var shots: Variant = JSON.parse_string(FileAccess.get_file_as_string(a[0]))
	if not shots is Array:
		_fail("%s is not a JSON list" % a[0])
		quit(1)
		return
	for raw: Variant in shots:
		await _shot(raw as Dictionary, a[1])
	if _problems.is_empty():
		print("[tintview] %d frame(s)" % _made)
		quit(0)
	else:
		quit(1)
