extends SceneTree
## Batch 048 against the three rooms' own constants.
##
##   godot --path godot -s _harness/roomfit.gd -- <models> <out.json>
##
## The same three questions as the other fit harnesses -- does it
## import, do the named parts survive, does anything ride along that
## should not -- plus the promises this batch makes in particular, each
## of which is a sentence in A06-A08 that could otherwise only be
## checked by reading the builder's comments.

## `counterfire_arcade.gd`
const OPEN_SECONDS := 8
const RECEIVER_Y := 0.85
const SHOT_CLEARANCE := 0.25
const GUNNER_ENVELOPE := Vector3(0.7, 1.4, 0.7)
## `passing_platforms.gd`
const RAIL_HEIGHT := 1.1
## Measured by run_controller_limits.sh.
const WALK_UP := 0.12
const FOOTHOLD := 0.35
## Words a semantic-class read must not use. A08.2: "do not reuse the
## accumulating-kilogram gauge as though the two sensors mean the same
## thing." A needle, a dial or a scale is that gauge by another name.
const NOT_A_CLASS_READ := ["gauge", "needle", "dial", "scale", "meter",
	"kg", "kilo"]

var _models: String
var _out: String
var _problems: Array[String] = []
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
	printerr("[roomfit] FAIL: %s" % what)


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
			out["names"].append(str(mi.name))
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
	var path := "%s/batch048/roomkits/%s.glb" % [_models, id]
	var root := _load(path)
	if root == null:
		_fail("%s did not import" % id)
		return
	var out := {"names": [], "box": AABB(), "seen": false,
		"per_part": {}, "forbidden": []}
	_walk(root, out)
	var box: AABB = out["box"]
	var names: Array = out["names"]
	var per: Dictionary = out["per_part"]
	_log[id] = {
		"nodes": names.size(), "parts": names,
		"size": [snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001),
			snappedf(box.size.z, 0.001)],
		"min_y": snappedf(box.position.y, 0.001),
	}
	root.free()

	if not (out["forbidden"] as Array).is_empty():
		_fail("%s carries %s -- a visual does not bring its own "
				% [id, str(out["forbidden"])]
				+ "collider, light, camera, script or animation")
	if names.size() < 2:
		_fail("%s arrived as %d node(s); its parts merged"
				% [id, names.size()])

	match id:
		"cf_shutter_track":
			# A07.4: the interval is DATA, and there are eight seconds
			# of it. Eight named pips, and no clock in the asset.
			var pips := 0
			for n: String in names:
				if n.begins_with("interval_pip_"):
					pips += 1
			_log[id]["interval_pips"] = pips
			if pips != OPEN_SECONDS:
				_fail("%s has %d interval pip(s) and OPEN_SECONDS is %d. "
						% [id, pips, OPEN_SECONDS]
						+ "The indicator is addressable per second or it "
						+ "is decoration.")
		"cf_lane_mark":
			# A07.3: it may not obscure a projectile.
			var top: float = box.position.y + box.size.y
			_log[id]["top"] = snappedf(top, 0.001)
			if top > RECEIVER_Y - SHOT_CLEARANCE:
				_fail("%s tops out at %.3f and the shot travels at %.2f. "
						% [id, top, RECEIVER_Y]
						+ "A projectile would pass behind it.")
		"cf_gunner_mount":
			# A07.2: built on the ranged enemy's published envelope, not
			# on a shape Art preferred.
			for axis: Array in [["x", box.size.x, GUNNER_ENVELOPE.x],
					["z", box.size.z, GUNNER_ENVELOPE.z]]:
				var got: float = float(axis[1])
				var env: float = float(axis[2])
				if got < env:
					_fail("%s is %.3f m in %s and the ranged envelope is "
							% [id, got, str(axis[0])]
							+ "%.3f -- the emplacement is smaller than "
							% env + "the thing standing on it.")
		"pp_transfer_edge":
			# A06.2: Production's railing height, not Art's.
			var cap: float = -INF
			for n: String in per:
				if n.begins_with("edge_cap_"):
					var a: AABB = per[n]
					cap = maxf(cap, a.position.y + a.size.y)
			_log[id]["rail_top"] = snappedf(cap, 0.001)
			if cap > -INF and absf(cap - RAIL_HEIGHT) > 0.06:
				_fail("%s's railing tops at %.3f and RAIL_HEIGHT is %.2f."
						% [id, cap, RAIL_HEIGHT])
		"uw_plate_frame":
			# A08.2: a CLASS read, not a kilogram gauge.
			var marks := 0
			for n: String in names:
				var low := n.to_lower()
				for banned: String in NOT_A_CLASS_READ:
					if low.contains(banned):
						_fail("%s has a part called '%s'. A08.2 is "
								% [id, n]
								+ "explicit that the semantic-class "
								+ "sensor is not the accumulating "
								+ "kilogram gauge, and a part named "
								+ "like one says it is.")
				if n.begins_with("class_mark_"):
					marks += 1
			_log[id]["class_marks"] = marks
			if marks < 2:
				_fail("%s has %d class mark(s). A class read needs "
						% [id, marks]
						+ "discrete positions; one is a light and none "
						+ "is a blank plate.")
		"uw_return_rail":
			# A08.5: no base-kit stair before completion.
			for n: String in per:
				var a: AABB = per[n]
				if a.position.y + a.size.y <= WALK_UP:
					continue
				if a.size.x >= FOOTHOLD and a.size.z >= FOOTHOLD:
					_fail("%s: %s presents a %.2f x %.2f m face %.3f m "
							% [id, n, a.size.x, a.size.z,
								a.position.y + a.size.y]
							+ "up. A08.5 says no stair before the room "
							+ "is completed, and a tread is a stair.")


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch048/roomkits/manifest.json" % _models)
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(data) != TYPE_DICTIONARY:
		_fail("no batch048 manifest")
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
		print("[roomfit] PASS -- %d asset(s) imported, kept their parts, "
				% (_log.size() - 1)
				+ "and keep the promises A06-A08 asked for")
		quit(0)
	else:
		printerr("[roomfit] %d problem(s)" % _problems.size())
		quit(1)
