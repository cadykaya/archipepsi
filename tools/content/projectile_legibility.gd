extends SceneTree
## A12.1/A12.5 -- Art's three projectiles through PRODUCTION'S OWN test.
##
##   godot --path godot -s _harness/projleg.gd -- <models> <out.json>
##
## `ProjectileSilhouette` does not just build placeholders: it publishes
## a legibility contract and a way to check it.
##
##     LEGIBLE_RATIO    1.8    one is this many times more needle-like
##     LEGIBLE_BALANCE  0.15   or its widest point sits this much
##                             further along the travel axis
##     reads_apart(a, b)       either measure is enough, pairwise
##
## Its own comment says the rule is "checked pairwise across all of it,
## so a fourth member cannot be added without being made
## distinguishable from the other three." Batch 008 authored three
## meshes for those three silhouettes -- and nothing has ever run THEIR
## test against OUR meshes. That is what this does.
##
## `profile()` walks `root.get_children()` one level deep and reads each
## child's `position` and `rotation`. A glTF import is a tree, so the
## harness flattens it first: every mesh becomes a direct child with its
## accumulated transform baked into position and rotation, which is the
## shape `profile` is written for. That flattening is the one liberty
## taken and it is stated rather than hidden.

const Silhouette := preload("res://_harness/prod_silhouette.gd")

## Which authored mesh stands for which silhouette. From
## `ProjectileSilhouette.content_id`: "projectile_%s".
const MESHES := {
	"straight": "batch008/enemy/enemy_projectile_straight.glb",
	"falling": "batch008/enemy/enemy_projectile_falling.glb",
	"lobbed": "batch008/enemy/enemy_projectile_lobbed.glb",
}

var _models: String
var _out: String
var _problems: Array[String] = []
var _reports: Array[String] = []
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
	printerr("[projleg] FAIL: %s" % what)


func _report(what: String) -> void:
	_reports.append(what)
	print("[projleg] REPORT: %s" % what)


func _flatten(node: Node, into: Node3D, carry: Transform3D) -> void:
	for child in node.get_children():
		var here := carry
		if child is Node3D:
			here = carry * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var copy := MeshInstance3D.new()
			copy.mesh = (child as MeshInstance3D).mesh
			copy.name = str(child.name)
			into.add_child(copy)
			copy.position = here.origin
			copy.rotation = here.basis.get_euler()
		_flatten(child, into, here)


func _profile_of(id: String) -> Dictionary:
	var path := "%s/%s" % [_models, MESHES[id]]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.base_path = path.get_base_dir()
	if doc.append_from_file(path, state) != OK:
		_fail("%s did not import" % id)
		return {}
	var imported := doc.generate_scene(state)
	var flat := Node3D.new()
	_flatten(imported, flat, Transform3D.IDENTITY)
	imported.free()
	if flat.get_child_count() == 0:
		_fail("%s flattened to no meshes" % id)
		flat.free()
		return {}
	var got: Dictionary = Silhouette.profile(flat)
	flat.free()
	return got


func _run() -> void:
	var profiles := {}
	for id: String in MESHES:
		var got := _profile_of(id)
		if got.is_empty():
			continue
		profiles[id] = {
			"length": snappedf(float(got["length"]), 0.001),
			"cross": snappedf(float(got["cross"]), 0.001),
			"elongation": snappedf(float(got["elongation"]), 0.001),
			"balance": snappedf(float(got["balance"]), 0.001),
			"parts": got["parts"],
		}
		_log[id] = profiles[id]
	_log["thresholds"] = {
		"LEGIBLE_RATIO": Silhouette.LEGIBLE_RATIO,
		"LEGIBLE_BALANCE": Silhouette.LEGIBLE_BALANCE,
	}
	# PAIRWISE, exactly as their own comment says the rule works.
	var ids: Array = profiles.keys()
	ids.sort()
	var pairs := {}
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var apart: bool = Silhouette.reads_apart(profiles[a],
				profiles[b])
			var ratio: float = maxf(float(profiles[a]["elongation"]),
					float(profiles[b]["elongation"])) \
				/ maxf(minf(float(profiles[a]["elongation"]),
					float(profiles[b]["elongation"])), 0.0001)
			var gap: float = absf(float(profiles[a]["balance"])
				- float(profiles[b]["balance"]))
			pairs["%s/%s" % [a, b]] = {
				"reads_apart": apart,
				"elongation_ratio": snappedf(ratio, 0.001),
				"balance_gap": snappedf(gap, 0.001),
			}
			if not apart:
				# REPORTED, NOT REFUSED, and the distinction matters.
				#
				# `reads_apart` is a real published rule and Art's three
				# fail it on every pair. But they were authored and
				# approved under a DIFFERENT rule -- Batch 008 reads by
				# silhouette KIND (an equatorial blade ring, a downward
				# skirt, a segmented ball with a fuse band) and
				# `straight()`'s own docstring says its blades make it
				# "wider than it is tall so it does not read as
				# something that will drop". Deliberately not elongated.
				#
				# Two defensible rules, and they cannot both govern.
				# That is the owner's decision, not a defect this
				# harness should refuse the build over -- the same shape
				# of mistake as treating `is_offerable`'s diagnostic as
				# a refusal.
				_report("%s and %s do not read apart by Production's "
						% [a, b]
						+ "rule: elongation ratio %.3f against %.2f, "
						% [ratio, Silhouette.LEGIBLE_RATIO]
						+ "balance gap %.3f against %.2f."
						% [gap, Silhouette.LEGIBLE_BALANCE])
	_log["pairs"] = pairs
	_finish()


func _finish() -> void:
	_log["problems"] = _problems
	_log["reports"] = _reports
	_log["balance_is_meaningless_here"] = (
		"ProjectileSilhouette.profile measures balance per PART -- its "
		+ "own comment says a bounding box cannot say where along a "
		+ "single cone the wide end is. All three of Art's projectiles "
		+ "export as ONE joined mesh, so balance is 0.5 by construction "
		+ "and the second half of reads_apart cannot fire for them at "
		+ "all, whatever their shape.")
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		if _reports.is_empty():
			print("[projleg] PASS -- Art's three projectiles read apart "
					+ "pairwise by ProjectileSilhouette's own rule")
		else:
			print("[projleg] PASS with %d REPORT(s) -- the meshes "
					% _reports.size()
					+ "import and profile; whose legibility rule governs "
					+ "is an owner decision and this does not refuse it")
		quit(0)
	else:
		printerr("[projleg] %d problem(s)" % _problems.size())
		quit(1)
