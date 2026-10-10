extends SceneTree
## Do the batch 046 yard visuals IMPORT, keep their parts, and FIT?
##
##   godot --path godot -s _harness/yardfit.gd -- <models> <out.json>
##
## Same three questions as `setpiece_fit.gd`, against a different kind
## of asset -- and one more that only applies here.
##
## **THE SPAN HAS TO REACH.** `yard_fit.json` measured the gap between S2
## and S3 at 14.048 m, and it is measured rather than restated because
## three of the rail's five control points sit on a Catmull-Rom corner:
## no reading of `railway_scenario.gd` yields that number. A span beam
## authored at "about fourteen metres" lands short of the far rail, and
## nothing in Blender would have said so -- the builder was sabotaged
## with exactly that constant and produced a clean 14.00 m beam with no
## complaint. This is the check that catches it.
##
## Everything compared here comes out of that same measurement file, so
## a builder that drifts from it fails rather than exporting confidently.

var _models: String
var _out: String
var _fit := {}
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
	printerr("[yardfit] FAIL: %s" % what)


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
	var path := "%s/batch046/yardkit/%s.glb" % [_models, id]
	var root := _load(path)
	if root == null:
		_fail("%s did not import" % id)
		return
	var names: Array[String] = []
	var forbidden: Array[String] = []
	var walked := _walk(root, names, forbidden, AABB(), false)
	var box: AABB = walked[0]
	_log[id] = {
		"nodes": names.size(),
		"parts": names,
		"size": [snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001),
				snappedf(box.size.z, 0.001)],
		"min_y": snappedf(box.position.y, 0.001),
	}

	if forbidden.size() > 0:
		_fail("%s carries %s -- a visual does not bring its own collider, "
				% [id, str(forbidden)]
				+ "light, camera or script")
	if names.size() < 2:
		_fail("%s arrived as %d node(s); its parts merged and a runtime "
				% [id, names.size()]
				+ "has nothing to fetch by name")

	match id:
		"yk_span_beam":
			_check_span(id, box, names)
		"yk_dock_edge":
			_check_dock_edge(id, box)
		"yk_track_module":
			_check_track(id, box)
		"yk_gantry_head":
			_check_gantry_head(id, box)
		"yk_branch_mast":
			_check_mast(id, box)
	root.free()


## THE ONE THAT MATTERS. Runtime z is the glTF conversion of the
## authoring y, so the span's length arrives on z.
func _check_span(id: String, box: AABB, names: Array[String]) -> void:
	var gap: float = float(_fit["span"]["gap"])
	var got: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if absf(got - gap) > 0.01:
		_fail("%s is %.3f m long and the measured gap between S2 and S3 "
				% [id, got]
				+ "is %.3f. The aligned span must meet BOTH track ends; "
				% gap
				+ "this one is %.3f m %s." % [absf(got - gap),
					"short" if got < gap else "long"])
	# The pivot end and the landing end are different jobs and a runtime
	# that wants to light one has to be able to find it.
	for needed: String in ["span_heel", "span_toe"]:
		if not names.has(needed):
			_fail("%s has no `%s` node, so the end that %s cannot be "
					% [id, needed,
						"pivots" if needed == "span_heel"
						else "lands on the far rail"]
					+ "addressed")
	# Stowed, this thing stands 62 degrees up against a 46-degree
	# walkable limit. Nothing on it may be flat enough to stand on.
	var stow: float = float(_fit["span"]["stowed_degrees"])
	var walkable: float = float(_fit["span"]["walkable_limit_degrees"])
	if stow <= walkable:
		_fail("the measurement now says the span stows at %.1f degrees "
				% stow
				+ "against a walkable limit of %.1f. A raised span that "
				% walkable
				+ "is walkable is a ramp to the far side, and this art "
				+ "was built on the assumption it is not.")
	_log[id]["gap"] = gap


## The dock edge may not cross the line the deck arrives on.
func _check_dock_edge(id: String, box: AABB) -> void:
	var inner: float = float(_fit["docks"][0]["lateral_inner"])
	var receiver: float = float(_fit["docks"][0]["receiver_lateral"])
	# Authored with local x = 0 ON the inner edge, growing outward.
	if box.position.x < -0.001:
		_fail("%s reaches %.3f m INBOARD of its own origin, and that "
				% [id, -box.position.x]
				+ "origin is the line where the deck's outer edge "
				+ "arrives (lateral %.2f). Anything past it is inside "
				% inner
				+ "the vehicle.")
	var reach: float = inner + box.position.x + box.size.x
	# PAST THE RECEIVER POSTS IS ONLY A PROBLEM IF IT STANDS UP.
	#
	# The first cut of this refused the edge outright for reaching
	# lateral 3.10 when the posts are at 2.60 -- but the whole asset is
	# 0.09 m tall and passes UNDER them, which is what a platform edge
	# treatment does. What must not happen is art that stands between a
	# player and a control they have to shoot, and a floor marking is
	# not that. Height is the part of the rule that was missing.
	if reach > receiver - 0.001 and box.size.y > 0.12:
		_fail("%s reaches lateral %.3f standing %.3f m proud, and the "
				% [id, reach, box.size.y]
				+ "shootable receiver posts stand at %.2f. Art between "
				% receiver
				+ "a player and a control they have to shoot is not "
				+ "dressing.")
	# Boarding happens across this edge; a kerb here is a kerb to climb.
	if box.size.y > 0.12:
		_fail("%s stands %.3f m proud of the pad and the measured "
				% [id, box.size.y]
				+ "walk-up limit is 0.12. This is the edge people board "
				+ "across.")
	_log[id]["reaches_lateral"] = snappedf(reach, 0.001)


## A track piece lives inside the envelope their own `_track()` lays.
func _check_track(id: String, box: AABB) -> void:
	if box.size.y > 0.35 + 0.001:
		_fail("%s is %.3f m tall and Production's track pieces are 0.35 "
				% [id, box.size.y]
				+ "-- it would stand proud of the beam it dresses")


## The head casting exists to close the gap between the column top and
## the platform underside. If it does not span that, it is decoration.
func _check_gantry_head(id: String, box: AABB) -> void:
	var deck_y: float = float(_fit["gantry"]["deck_centre"][1])
	var deck_h: float = float(_fit["gantry"]["deck_size"][1])
	var column_top: float = float(_fit["gantry"]["column_size"][1])
	var want: float = (deck_y - deck_h * 0.5) - column_top
	if want <= 0.0:
		_log[id]["note"] = ("the column now reaches the platform; the "
			+ "head casting is dressing rather than a repair")
		return
	# The casting is the tallest thing in the asset by design.
	if box.size.y + 0.001 < want:
		_fail("%s is %.3f m tall and the gap between the gantry column's "
				% [id, box.size.y]
				+ "top (%.2f) and the platform's underside (%.2f) is "
				% [column_top, deck_y - deck_h * 0.5]
				+ "%.3f. It does not close it." % want)
	_log[id]["closes_gap_of"] = snappedf(want, 0.001)


## The branch landmark is nonblocking, and its height is the proof.
func _check_mast(id: String, box: AABB) -> void:
	var floor_y: float = float(_fit["branch"]["top_y"])
	var at: float = float(_fit["branch"]["walk_to"]) - 0.5
	var lowest := INF
	for sample: Dictionary in _fit["sightline"]["samples"]:
		if absf(float(sample["lateral"]) - at) <= 1.0:
			lowest = minf(lowest, float(sample["low_y"]))
	if lowest == INF:
		return
	var top: float = floor_y + box.position.y + box.size.y
	if top >= lowest:
		_fail("%s tops out at world %.3f and the eye-to-ring ray bundle "
				% [id, top]
				+ "at the walkway's end has its floor at %.3f. A05.4 "
				% lowest
				+ "asked for a NONBLOCKING landmark.")
	_log[id]["world_top"] = snappedf(top, 0.001)
	_log[id]["corridor_floor"] = snappedf(lowest, 0.001)


func _run() -> void:
	var fit_text := FileAccess.get_file_as_string(
			"%s/batch046/yard_fit.json" % _models)
	var fit: Variant = JSON.parse_string(fit_text) if fit_text != "" \
			else null
	if typeof(fit) != TYPE_DICTIONARY:
		_fail("no measured yard at batch046/yard_fit.json. Every number "
				+ "this harness compares against lives there; without it "
				+ "there is nothing to check, and passing would be a lie.")
		_finish()
		return
	_fit = fit
	var text := FileAccess.get_file_as_string(
			"%s/batch046/yardkit/manifest.json" % _models)
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(data) != TYPE_DICTIONARY:
		_fail("no batch046 manifest")
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
		print("[yardfit] PASS -- %d asset(s) imported, kept their parts, "
				% (_log.size() - 1)
				+ "and fit the MEASURED yard")
		quit(0)
	else:
		printerr("[yardfit] %d problem(s)" % _problems.size())
		quit(1)
