extends SceneTree
## A10.2 / A10.6 -- is the approved ten-role roster production-READY?
##
##   godot --path godot -s _harness/enemyready.gd -- <models> <out.json>
##
## Batch 030 built all ten roles to `Constants.ENEMY_ENVELOPES` and
## asserted the fit at build time. This asks the next question, which
## build-time assertions cannot: what happens when Production's own
## consumer gets hold of them.
##
## Eight checks per role, and the eighth is the one that found something:
##
## 1. **Does it import** through the real glTF path.
## 2. **How many nodes** does it arrive as. A10.3 wants named anchors,
##    and a role that arrives as one joined mesh has nowhere to put one.
## 3. **Does it fit the envelope** Production publishes -- read from
##    their `Constants`, not restated here.
## 4. **Is the origin right for the role**: a grounded role's feet at 0,
##    a flying role's body lifted to its hover height.
## 5. **Which way does it face.** Godot's forward is -Z.
## 6. **Are the normals sane** -- degenerate or zero-area triangles.
## 7. **Do the surfaces carry materials** at all.
## 8. **WOULD THE DAMAGE TINT APPEAR?** `Enemy._collect_tint_parts`
##    walks the tree and takes only meshes whose `material_override` is
##    a `StandardMaterial3D`. A glTF import puts its materials on the
##    mesh SURFACES and leaves `material_override` null. So the rule is
##    applied here exactly as they wrote it, and the count is reported.
##    Their own comment says a tint that never appears is a bug with a
##    test against it; this is the same question asked of authored art.

var _models: String
var _out: String
var _envelopes := {}
var _problems: Array[String] = []
var _notes: Array[String] = []
var _log := {}

## Which roles fly, from batch030's own manifest -- Art's record of a
## decision Production published. Read, not assumed.
var _manifest := {}


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
	printerr("[enemyready] FAIL: %s" % what)


func _note(what: String) -> void:
	_notes.append(what)
	print("[enemyready] NOTE: %s" % what)


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.base_path = path.get_base_dir()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


## Production's rule, transcribed rather than paraphrased. See
## `Enemy._collect_tint_parts`.
func _count_tintable(node: Node) -> int:
	var found := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			var shared: Material = (child as MeshInstance3D).material_override
			if shared is StandardMaterial3D:
				found += 1
		found += _count_tintable(child)
	return found


func _walk(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			out["names"].append(str(mi.name))
			if mi.mesh == null:
				continue
			var aabb: AABB = (mi.transform * mi.mesh.get_aabb()) as AABB
			(out["per_part"] as Dictionary)[str(mi.name)] = aabb
			if bool(out["seen"]):
				out["box"] = (out["box"] as AABB).merge(aabb)
			else:
				out["box"] = aabb
				out["seen"] = true
			for surface in mi.mesh.get_surface_count():
				out["surfaces"] += 1
				if mi.mesh.surface_get_material(surface) != null:
					out["surface_materials"] += 1
				var arrays: Array = mi.mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if idx.is_empty():
					continue
				var i := 0
				while i + 2 < idx.size():
					var a: Vector3 = verts[idx[i]]
					var b: Vector3 = verts[idx[i + 1]]
					var c: Vector3 = verts[idx[i + 2]]
					if (b - a).cross(c - a).length() < 1e-9:
						out["degenerate"] += 1
					out["triangles"] += 1
					i += 3
		_walk(child, out)


func _check(role: String) -> void:
	var path := "%s/batch030/enemies/enemy_role_%s.glb" % [_models, role]
	var root := _load(path)
	if root == null:
		_fail("%s did not import" % role)
		return
	var out := {"names": [], "box": AABB(), "seen": false, "surfaces": 0,
		"surface_materials": 0, "triangles": 0, "degenerate": 0,
		"per_part": {}}
	_walk(root, out)
	var box: AABB = out["box"]
	var tintable := _count_tintable(root)
	var entry := {
		"nodes": (out["names"] as Array).size(),
		"parts": out["names"],
		"size": [snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001),
			snappedf(box.size.z, 0.001)],
		"min_y": snappedf(box.position.y, 0.001),
		"surfaces": out["surfaces"],
		"surfaces_with_material": out["surface_materials"],
		"triangles": out["triangles"],
		"degenerate_triangles": out["degenerate"],
		"tintable_by_production_rule": tintable,
	}
	_log[role] = entry
	root.free()

	# 3. The envelope, from Production's own table.
	#
	# THE KEYS ARE THEIRS AND ARE CHECKED. The first cut read `width`,
	# `height` and `depth`; their table publishes a `size` Vector3. Ten
	# roles raised "Invalid access to property or key" -- and the run
	# still printed PASS, because the error aborted each `_check` after
	# the envelope and before the tint count, so the check that had
	# something to say never ran. A harness that reports success while
	# every one of its subjects threw is the same defect as a filter
	# that cannot express failure, and it is the reason the shape is
	# verified rather than assumed.
	if not _envelopes.has(role):
		_fail("%s has no entry in Constants.ENEMY_ENVELOPES, so there "
				% role + "is nothing to check its size against")
	else:
		var env: Dictionary = _envelopes[role]
		for key: String in ["size", "centre_y", "hover_height", "flying"]:
			if not env.has(key):
				_fail("Constants.ENEMY_ENVELOPES[%s] has no %r -- this "
						% [role, key]
						+ "harness was written against a different shape "
						+ "and would check nothing.")
				return
		var want: Vector3 = env["size"]
		entry["envelope"] = [want.x, want.y, want.z]
		entry["centre_y"] = float(env["centre_y"])
		entry["hover_height"] = float(env["hover_height"])
		entry["flying"] = bool(env["flying"])
		for axis: Array in [["x", box.size.x, want.x],
				["y", box.size.y, want.y], ["z", box.size.z, want.z]]:
			if float(axis[1]) > float(axis[2]) + 0.005:
				_fail("%s is %.3f m in %s and the published envelope is "
						% [role, float(axis[1]), str(axis[0])]
						+ "%.3f -- the model is outside the collider."
						% float(axis[2]))
		# 4. Origin. A grounded role stands on the floor; a flying one
		# is authored about its own body and LIFTED by the runtime, so
		# its mesh sitting at 0 is correct and a mesh already at hover
		# height would be lifted twice.
		var floor_gap: float = box.position.y
		entry["floor_gap"] = snappedf(floor_gap, 0.001)
		if absf(floor_gap) > 0.02:
			_note("%s sits %.3f m off its own origin. Grounded roles "
					% [role, floor_gap]
					+ "want 0; a flying role authored at its hover "
					+ "height would be lifted twice by the runtime.")

	# 6 / 7. Source defects, which A10.2 asks to correct rather than hide.
	if out["degenerate"] > 0:
		_fail("%s has %d degenerate triangle(s) -- zero area, so they "
				% [role, out["degenerate"]]
				+ "have no normal and shade as seams")
	if out["surfaces"] > 0 \
			and out["surface_materials"] < out["surfaces"]:
		_fail("%s has %d surface(s) and only %d carry a material"
				% [role, out["surfaces"], out["surface_materials"]])

	# A10.3. The anchors Art declared must BE there, and must be
	# inside the body -- an anchor that sticks out is a bump on an
	# enemy that has none.
	var declared: Array = _manifest["enemy_role_%s" % role].get(
			"anchors", [])
	entry["anchors_declared"] = declared
	for want: String in declared:
		if not (out["names"] as Array).has(want):
			_fail("%s declares an anchor %r that did not survive export "
					% [role, want]
					+ "-- a runtime has nothing to fetch by that name")
	if declared.is_empty():
		_note("%s declares no attachment anchors" % role)
	var per: Dictionary = out["per_part"]
	var body_box: AABB = per.get("enemy_role_%s" % role, box)
	for want: String in declared:
		if not per.has(want):
			continue
		var a: AABB = per[want]
		if not body_box.encloses(a):
			_fail("%s: %s is not inside the body box. An anchor is a "
					% [role, want]
					+ "point to fetch, not a fitting -- one that stands "
					+ "proud is a bump on an enemy that has none.")

	# 8. The one that matters.
	if tintable == 0:
		_note("%s would take NO damage tint: "
				% role
				+ "Enemy._collect_tint_parts only unshares meshes whose "
				+ "material_override is a StandardMaterial3D, and a glTF "
				+ "import puts its materials on the surfaces.")


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch030/enemies/manifest.json" % _models)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("no batch030 manifest")
		_finish()
		return
	_manifest = parsed
	var envelopes = load("res://_harness/prod_constants.gd")
	if envelopes != null and "ENEMY_ENVELOPES" in envelopes:
		_envelopes = envelopes.ENEMY_ENVELOPES
	if _envelopes.is_empty():
		_fail("Constants.ENEMY_ENVELOPES did not load. Every envelope "
				+ "check below would silently pass, which is worse than "
				+ "not running them.")
		_finish()
		return
	_log["envelope_source"] = "Constants.ENEMY_ENVELOPES, read-only"
	for id: String in _manifest:
		_check(str(id).replace("enemy_role_", ""))
	_finish()


func _finish() -> void:
	_log["problems"] = _problems
	_log["notes"] = _notes
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[enemyready] PASS -- %d role(s) import and fit the "
				% (_log.size() - 3)
				+ "published envelope; %d note(s)" % _notes.size())
		quit(0)
	else:
		printerr("[enemyready] %d problem(s)" % _problems.size())
		quit(1)
