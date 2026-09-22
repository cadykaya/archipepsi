extends SceneTree
## Do the batch 045 setpiece visuals IMPORT, keep their parts, and FIT?
##
##   godot --path godot -s _harness/setfit.gd -- <models> <out.json>
##
## Three questions, and the third is the one that matters:
##
## 1. **Does it import at all**, through the same glTF path the engine
##    uses, from a clean load.
## 2. **Do the named parts survive?** A region a runtime has to drive must
##    arrive as a node a script can fetch by name. A material slot is not
##    a hinge, and a merged mesh is not a shutter.
## 3. **Does it fit the envelope Production actually runs?** The numbers
##    are read from `PRODUCTION` below, which mirrors the 0.4 branch's own
##    constants. An asset that is 4.1 m where the deck is 4.0 does not
##    "nearly" fit -- it hangs over the dock edge a rider steps across.
##
## And one negative: **nothing rides along.** A visual replacement that
## smuggles in a collider, a light, a camera or a script is a second
## implementation of somebody else's mechanic. The importer would happily
## carry all four.

## Production's constants, mirrored. `tolerance` is per asset because the
## rules differ: a deck must match its collider exactly, a hood in a wall
## only has to stay inside the room.
const PRODUCTION := {
	"sp_skiff_deck": {"x": 4.0, "z": 4.0, "tol": 0.001,
		"why": "RailCarrier deck box; the docks meet its outer edge exactly",
		"free_axis": "z"},
	"sp_hoist_car": {"x": 4.0, "z": 4.0, "tol": 0.001,
		"why": "passing_platforms DECK", "free_axis": ""},
	"sp_crossing_carrier": {"x": 4.0, "z": 4.0, "tol": 0.001,
		"why": "passing_platforms DECK", "free_axis": "x"},
	"sp_shutter_leaf": {"x": 0.4, "z": 2.4, "tol": 0.12,
		"why": "counterfire SHUTTER (0.4, 2.6, 2.4)", "free_axis": ""},
	"sp_weight_plate": {"x": 2.4, "z": 2.4, "tol": 0.001,
		"why": "unweighted PLATE (2.4, 0.12, 2.4)", "free_axis": ""},
	"sp_ballast_crate": {"x": 2.0, "z": 2.0, "tol": 0.12,
		"why": "unweighted CRATE (2.0, 1.0, 2.0); the BANDS may stand proud",
		"free_axis": ""},
}
## The crate is a STEP. `MAX_VERTICAL_STEP` is 1.0 and so is the crate, in
## every state -- a model that shrinks to look lighter is a step that
## stopped existing.
const CRATE_HEIGHT := 1.0
const MAX_VERTICAL_STEP := 1.0
## Nothing above a rideable deck may become a step to the 3.1 m gantry.
const RIDEABLE := ["sp_skiff_deck", "sp_hoist_car", "sp_crossing_carrier"]
const DECK_CENTRE_Y := 0.8
const GANTRY_Y := 3.1
const JUMP_APEX := 1.3333333333333333

var _models: String
var _out: String
var _problems: Array[String] = []
var _log := {}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <models-dir> <out.json>")
	else:
		_models = a[0]
		_out = a[1]
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[setfit] FAIL: %s" % what)


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.base_path = path.get_base_dir()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


func _walk(node: Node, names: Array[String], forbidden: Array[String],
		box: AABB, first: bool) -> Array:
	var out_box := box
	var seen := first
	for child in node.get_children():
		var n := child as Node3D
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			names.append(str(mi.name))
			if mi.mesh != null:
				var aabb: AABB = (n.transform * mi.mesh.get_aabb()) as AABB
				out_box = aabb if not seen else out_box.merge(aabb)
				seen = true
		elif child is CollisionShape3D or child is CollisionObject3D \
				or child is Light3D or child is Camera3D:
			forbidden.append("%s (%s)" % [child.name, child.get_class()])
		if child.get_script() != null:
			forbidden.append("%s carries a script" % child.name)
		var deeper := _walk(child, names, forbidden, out_box, seen)
		out_box = deeper[0]
		seen = bool(deeper[1])
	return [out_box, seen]


func _check(id: String) -> void:
	var path := "%s/batch045/setpieces/%s.glb" % [_models, id]
	var root := _load(path)
	if root == null:
		_fail("%s did not import" % id)
		return
	var names: Array[String] = []
	var forbidden: Array[String] = []
	var walked := _walk(root, names, forbidden, AABB(), false)
	var box: AABB = walked[0]
	var note := {
		"nodes": names.size(),
		"parts": names,
		"size": [snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001),
				snappedf(box.size.z, 0.001)],
		"min_y": snappedf(box.position.y, 0.001),
	}
	_log[id] = note

	if forbidden.size() > 0:
		_fail("%s carries %s -- a visual replacement does not bring its own "
				% [id, str(forbidden)]
				+ "collider, light, camera or script")
	if names.size() < 2:
		_fail("%s arrived as %d node(s). Its state regions merged, so the "
				% [id, names.size()]
				+ "only handle a runtime has on them is a material slot")

	if PRODUCTION.has(id):
		var want: Dictionary = PRODUCTION[id]
		var tol: float = want["tol"]
		for axis in ["x", "z"]:
			if str(want["free_axis"]) == axis:
				continue
			var got: float = box.size.x if axis == "x" else box.size.z
			if absf(got - float(want[axis])) > tol:
				_fail("%s is %.3f m in %s and Production's envelope is "
						% [id, got, axis]
						+ "%.3f (%s)" % [float(want[axis]), want["why"]])
		note["fits"] = want["why"]

	if id == "sp_ballast_crate":
		# The whole point of the asset.
		if absf(box.size.y - CRATE_HEIGHT) > 0.001:
			_fail("the crate is %.3f m tall and MAX_VERTICAL_STEP is %.2f. "
					% [box.size.y, MAX_VERTICAL_STEP]
					+ "It is a step in every state; a model that is not "
					+ "exactly 1.0 has stopped being one.")
		var lit := 0
		for n: String in names:
			if n.begins_with("lightened_"):
				lit += 1
		if lit == 0:
			_fail("the crate has no `lightened_*` node, so LIGHTENED can "
					+ "only be shown by moving or scaling the step")
		note["lightened_nodes"] = lit

	if RIDEABLE.has(id):
		# Node-space top -> world, then the jump.
		var top := box.position.y + box.size.y
		var reach := DECK_CENTRE_Y + top + JUMP_APEX
		note["world_top"] = snappedf(DECK_CENTRE_Y + top, 0.001)
		note["reach_if_solid"] = snappedf(reach, 0.001)
		if reach >= GANTRY_Y:
			_fail("%s tops out at world %.3f; a body standing there reaches "
					% [id, DECK_CENTRE_Y + top]
					+ "%.3f and the gantry is at %.1f. That is a walking "
					% [reach, GANTRY_Y]
					+ "bypass the scenario says must not exist.")
	root.free()


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch045/setpieces/manifest.json" % _models)
	if text == "":
		_fail("no batch045 manifest")
		_finish()
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_fail("the manifest did not parse")
		_finish()
		return
	for id: String in (data as Dictionary):
		_check(id)
	_finish()


func _finish() -> void:
	_log["problems"] = _problems
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[setfit] PASS -- %d asset(s) imported, kept their parts, fit "
				% (_log.size() - 1) + "Production's envelope, and brought "
				+ "nothing else")
		quit(0)
	else:
		printerr("[setfit] %d problem(s)" % _problems.size())
		quit(1)
