extends SceneTree
## Batch 049 against A09's own sentences.
##
##   godot --path godot -s _harness/connfit.gd -- <models> <out.json>
##
## The usual three, plus the four things A09 asks for that can only be
## checked by looking at what actually imported.

const RUN_HEIGHT := 0.5
## A09.2's three kinds. They must all be present and they must be
## tellable apart by SHAPE -- colour does not survive a theme change.
const COMMITMENTS := ["conn_set_dial", "conn_hold_paddle",
	"conn_repair_seal"]
const POSE_TOLERANCE := 0.05
## A09.2: four distinct appearances, as nodes.
const READER_STATES := ["state_selected", "state_unselected",
	"state_blocked", "state_pending"]
## A09.1/A09.3: nothing is baked. These fields are populated at runtime.
const RUNTIME_FIELDS := {
	"conn_reader_panel": "label_field",
	"conn_id_plaque": "plaque_id_field",
}

var _models: String
var _out: String
var _problems: Array[String] = []
var _sizes := {}
var _log := {}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <models-dir> <out.json>")
		_finish()
		return
	_models = a[0]
	_out = a[1]
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[connfit] FAIL: %s" % what)


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.base_path = path.get_base_dir()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


func _walk(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			(out["names"] as Array).append(str(mi.name))
			if mi.mesh != null:
				var a: AABB = (mi.transform * mi.mesh.get_aabb()) as AABB
				(out["per_part"] as Dictionary)[str(mi.name)] = a
				if bool(out["seen"]):
					out["box"] = (out["box"] as AABB).merge(a)
				else:
					out["box"] = a
					out["seen"] = true
		elif child is CollisionShape3D or child is CollisionObject3D \
				or child is Light3D or child is Camera3D:
			(out["forbidden"] as Array).append(
				"%s (%s)" % [child.name, child.get_class()])
		if child is AnimationPlayer:
			(out["forbidden"] as Array).append(
				"%s (AnimationPlayer)" % child.name)
		if child.get_script() != null:
			(out["forbidden"] as Array).append(
				"%s carries a script" % child.name)
		_walk(child, out)


func _check(id: String) -> void:
	var root := _load("%s/batch049/connect/%s.glb" % [_models, id])
	if root == null:
		_fail("%s did not import" % id)
		return
	var out := {"names": [], "box": AABB(), "seen": false,
		"per_part": {}, "forbidden": []}
	_walk(root, out)
	var box: AABB = out["box"]
	var names: Array = out["names"]
	var per: Dictionary = out["per_part"]
	_sizes[id] = box.size
	_log[id] = {"nodes": names.size(), "parts": names,
		"size": [snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001),
			snappedf(box.size.z, 0.001)]}
	root.free()

	if not (out["forbidden"] as Array).is_empty():
		_fail("%s carries %s -- A09.1 is explicit that this kit is a "
				% [id, str(out["forbidden"])]
				+ "readable presentation, not a signal bus, and it does "
				+ "not bring a collider, light, camera, script or "
				+ "animation either")
	if names.size() < 2:
		_fail("%s arrived as %d node(s); its parts merged"
				% [id, names.size()])

	# A09.1: a band that changes width at a corner is a different
	# system, not the same run turning.
	for n: String in per:
		if not n.begins_with("state_band") \
				and not n.ends_with("_band"):
			continue
		var a: AABB = per[n]
		if absf(a.size.y - RUN_HEIGHT) > 0.002:
			_fail("%s: %s is %.3f m on the run's face axis and Batch "
					% [id, n, a.size.y]
					+ "043's run face is %.2f." % RUN_HEIGHT)

	if RUNTIME_FIELDS.has(id):
		var want: String = RUNTIME_FIELDS[id]
		if not names.has(want):
			_fail("%s has no `%s`. A09.2 and A09.3 want the identifier "
					% [id, want]
					+ "populated at RUNTIME; without the node there is "
					+ "nowhere to populate and the alternative is baked "
					+ "text.")

	if id == "conn_reader_panel":
		for want: String in READER_STATES:
			if not names.has(want):
				_fail("%s has no `%s`. A09.2 wants selected, unselected, "
						% [id, want]
						+ "blocked and pending to be DISTINCT, and four "
						+ "nodes is how a runtime shows one without "
						+ "swapping a material on a merged mesh.")


func _check_poses() -> void:
	for i in COMMITMENTS.size():
		if not _sizes.has(COMMITMENTS[i]):
			_fail("%s is missing. A09.2 needs all three commitments to "
					% COMMITMENTS[i]
					+ "exist, or the distinction it asks for cannot be "
					+ "made.")
			continue
		for j in range(i + 1, COMMITMENTS.size()):
			if not _sizes.has(COMMITMENTS[j]):
				continue
			var a: Vector3 = _sizes[COMMITMENTS[i]]
			var b: Vector3 = _sizes[COMMITMENTS[j]]
			if absf(a.x - b.x) < POSE_TOLERANCE \
					and absf(a.y - b.y) < POSE_TOLERANCE \
					and absf(a.z - b.z) < POSE_TOLERANCE:
				_fail("%s and %s are within %.2f m on every axis. A09.2: "
						% [COMMITMENTS[i], COMMITMENTS[j], POSE_TOLERANCE]
						+ "a persistent setting, a held input and a "
						+ "permanent repair must not share a pose, and a "
						+ "player cannot read a colour across a room.")
	_log["commitment_sizes"] = {}
	for id: String in COMMITMENTS:
		if _sizes.has(id):
			var v: Vector3 = _sizes[id]
			_log["commitment_sizes"][id] = [snappedf(v.x, 0.001),
				snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch049/connect/manifest.json" % _models)
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(data) != TYPE_DICTIONARY:
		_fail("no batch049 manifest")
		_finish()
		return
	for id: String in (data as Dictionary):
		_check(id)
	_check_poses()
	_finish()


func _finish() -> void:
	_log["problems"] = _problems
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[connfit] PASS -- %d asset(s) imported, kept their parts, "
				% (_log.size() - 2)
				+ "and keep A09's distinctions")
		quit(0)
	else:
		printerr("[connfit] %d problem(s)" % _problems.size())
		quit(1)
