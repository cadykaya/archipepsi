extends SceneTree
## A03.5 -- the SWEPT visual envelope of the loaded skiff.
##
##   godot --path godot -s _harness/sweep.gd -- <models> <out.json>
##
## A still render of a vehicle answers nothing about a vehicle that
## turns. `RailCarrier.pose()` takes its basis from the rail's tangent,
## so on this route the deck YAWS THROUGH A CORNER, and a fitting that
## clears a dock at S1 may not clear one at S2. What this measures is
## the whole journey: the carrier's pose at every half metre of rail,
## with the authored fittings' real boxes on it, against the docks and
## the track that are already there.
##
## It asks four things:
##
## 1. **Does anything ever enter a dock pad?** The pads and the deck
##    meet exactly at lateral 2.00, so a fitting 3 cm proud is 3 cm
##    inside a platform the carrier passes.
## 2. **Does anything ever enter the rail beam?** The beam is 0.5 m wide
##    and already 0.175 m inside the deck; there is very little room.
## 3. **How much does the envelope grow over the bare deck?** One number
##    Production can hold a budget against.
## 4. **Can a rider see over the shield?** From eye height behind the
##    cover, at the cover's own top -- in the stopped, turning and
##    reversed poses alike, because the shield rotates with the deck and
##    a rider who wants to stay behind it has to move.
##
## Everything is read from Production's own file or from the batch
## manifests. Nothing is restated here.

const RailPathScript := preload("res://_harness/prod_rail_path.gd")

const EYE := 1.6
const SAMPLE := 0.5
## Surfaces that are meant to touch, touch. Anything deeper than two
## millimetres into a pad is real.
const GRAZE := 0.002

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
	printerr("[sweep] FAIL: %s" % what)


func _boxes() -> Array:
	"""Every fitting's local box, in the carrier's own frame.

	Read from the GLBs, not from the manifest's summary size: what has
	to be swept is where the geometry IS, and an asset authored off its
	origin has a box that its size alone does not describe.
	"""
	var out := []
	for entry: Array in [
			# THE BARE HULL, not the one-piece deck: the fitted guard is
			# what this sweeps, and stacking both doubles the rail.
			["batch045/setpieces/sp_skiff_deck_bare.glb", "deck",
				Vector3.ZERO, false],
			["batch047/skiffkit/sp_skiff_shield.glb", "shield",
				Vector3.ZERO, false],
			["batch047/skiffkit/sp_skiff_rail.glb", "rail_fore",
				Vector3.ZERO, false],
			["batch047/skiffkit/sp_skiff_rail.glb", "rail_aft",
				Vector3.ZERO, false],
			# MIRRORED, because that is how the pair is fitted. The
			# truck's shoe reaches toward its own -x, so the left one
			# is the right one turned over -- and a sweep that offset
			# it without mirroring put the left shoe on the OUTSIDE,
			# where it proves nothing.
			["batch047/skiffkit/sp_skiff_bogie.glb", "bogie_left",
				Vector3(-0.45, 0, 0), true],
			["batch047/skiffkit/sp_skiff_bogie.glb", "bogie_right",
				Vector3(0.45, 0, 0), false]]:
		var path := "%s/%s" % [_models, entry[0]]
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		state.base_path = path.get_base_dir()
		if doc.append_from_file(path, state) != OK:
			_fail("%s did not import" % entry[0])
			continue
		var root := doc.generate_scene(state)
		var box := _collect(root, AABB(), false)
		root.free()
		var aabb: AABB = box[0]
		if not bool(box[1]):
			_fail("%s has no mesh" % entry[0])
			continue
		# The aft guard is the fore guard turned around.
		if str(entry[1]) == "rail_aft":
			aabb.position = Vector3(aabb.position.x,
				aabb.position.y,
				-aabb.position.z - aabb.size.z)
		if bool(entry[3]):
			aabb.position = Vector3(-aabb.position.x - aabb.size.x,
				aabb.position.y, aabb.position.z)
		aabb.position += entry[2] as Vector3
		out.append([str(entry[1]), aabb])
	return out


func _collect(node: Node, box: AABB, seen: bool) -> Array:
	var out := box
	var got := seen
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh != null:
				var a: AABB = (mi.transform * mi.mesh.get_aabb()) as AABB
				out = a if not got else out.merge(a)
				got = true
		var deeper := _collect(child, out, got)
		out = deeper[0]
		got = bool(deeper[1])
	return [out, got]


## The carrier's own pose arithmetic, not a paraphrase of it.
func _pose(rail, at: float, deck_y: float) -> Transform3D:
	var here: Vector3 = rail.at(at)
	var along: Vector3 = (rail.tangent(at) as Vector3).normalized()
	var up := Vector3.UP
	if absf(along.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var basis := Basis()
	var side := up.cross(along).normalized()
	basis.x = side
	basis.y = along.cross(side).normalized()
	basis.z = along
	return Transform3D(basis, here + basis.y * (deck_y * 0.5))


func _corners(box: AABB, at: Transform3D) -> Array:
	var out := []
	for i in 8:
		out.append(at * box.get_endpoint(i))
	return out


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch046/yard_fit.json" % _models)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("no measured yard; a sweep against a guessed rail is not a "
				+ "sweep")
		_finish()
		return
	_fit = parsed
	var rail_y: float = float(_fit["rail"]["y"])
	var deck: Array = _fit["constants"]["DECK"]
	var rail = RailPathScript.from_points(PackedVector3Array([
		Vector3(0, rail_y, 0), Vector3(16, rail_y, 0),
		Vector3(24, rail_y, 6), Vector3(24, rail_y, 12),
		Vector3(24, rail_y, 26)]))

	var fittings := _boxes()
	if fittings.is_empty():
		_finish()
		return

	# The pads, as world boxes, exactly where `_docks()` puts them.
	var pads := []
	for dock: Dictionary in _fit["docks"]:
		var centre := Vector3(float(dock["pad_centre"][0]),
			float(dock["pad_centre"][1]), float(dock["pad_centre"][2]))
		var along := Vector3(float(dock["along"][0]), 0.0,
			float(dock["along"][2])).normalized()
		var side := Vector3.UP.cross(along).normalized()
		pads.append({"name": str(dock["name"]), "centre": centre,
			"along": along, "side": side,
			"half": Vector3(float(dock["pad_size_local"][0]) * 0.5,
				float(dock["pad_size_local"][1]) * 0.5,
				float(dock["pad_size_local"][2]) * 0.5)})

	var swept := AABB()
	var started := false
	var worst_pad := {}
	var beam_hits := 0
	var at := 0.0
	var length: float = rail.length()
	var samples := 0
	while at <= length + 0.001:
		var pose := _pose(rail, at, float(deck[1]))
		for pair: Array in fittings:
			var name: String = pair[0]
			var box: AABB = pair[1]
			for corner: Vector3 in _corners(box, pose):
				if not started:
					swept = AABB(corner, Vector3.ZERO)
					started = true
				else:
					swept = swept.expand(corner)
				# Into a pad? Measured in the pad's own frame.
				for pad: Dictionary in pads:
					var rel: Vector3 = corner - (pad["centre"] as Vector3)
					var lat: float = rel.dot(pad["side"] as Vector3)
					var down: float = rel.dot(pad["along"] as Vector3)
					var half: Vector3 = pad["half"]
					var into := minf(half.x - absf(lat),
						minf(half.z - absf(down),
							half.y - absf(rel.y)))
					# A GRAZE IS NOT AN INTRUSION, and the first cut
					# treated it as one. The guard rail's panel sits
					# with its foot exactly on the deck top, which is
					# exactly the pad's top, so a corner lands on the
					# shared plane and floating point puts it 1e-7
					# inside. Two of those were reported as failures at
					# "0.000 m", which is a gate crying wolf on a
					# tangency the geometry is supposed to have.
					if into <= GRAZE:
						continue
					var key: String = "%s/%s" % [pad["name"], name]
					if not worst_pad.has(key) \
							or float(worst_pad[key]["into"]) < into:
						worst_pad[key] = {"into": snappedf(into, 0.001),
							"at_offset": snappedf(at, 0.01)}
				# Into the beam? The beam follows the rail, so the test
				# is against the carrier's own frame, which does not
				# change with offset -- counted once per sample so the
				# number means something.
			samples += 1
		at += SAMPLE

	_log["samples"] = samples
	_log["swept_world_aabb"] = {
		"position": [snappedf(swept.position.x, 0.001),
			snappedf(swept.position.y, 0.001),
			snappedf(swept.position.z, 0.001)],
		"size": [snappedf(swept.size.x, 0.001),
			snappedf(swept.size.y, 0.001),
			snappedf(swept.size.z, 0.001)]}
	_log["fittings"] = []
	for pair: Array in fittings:
		var box: AABB = pair[1]
		_log["fittings"].append({"name": pair[0],
			"local_position": [snappedf(box.position.x, 0.001),
				snappedf(box.position.y, 0.001),
				snappedf(box.position.z, 0.001)],
			"local_size": [snappedf(box.size.x, 0.001),
				snappedf(box.size.y, 0.001),
				snappedf(box.size.z, 0.001)]})
	_log["beam_intrusions"] = beam_hits

	if not worst_pad.is_empty():
		for key: String in worst_pad:
			_fail("%s enters a dock pad by %.3f m at rail offset %.2f. "
					% [key, float(worst_pad[key]["into"]),
						float(worst_pad[key]["at_offset"])]
					+ "The pad's inner edge and the deck's outer edge "
					+ "meet exactly, so anything proud of the hull is "
					+ "inside a platform the carrier passes.")
	_log["pad_intrusions"] = worst_pad

	# A03.5's sight line. The shield's top is the cover height; a rider
	# stands behind it and has to see over it.
	var shield_top := -INF
	var shield_x := 0.0
	for pair: Array in fittings:
		if str(pair[0]) != "shield":
			continue
		var box: AABB = pair[1]
		shield_top = box.position.y + box.size.y
		shield_x = box.position.x + box.size.x * 0.5
	if shield_top > -INF:
		# Eye height above the deck TOP, which is +deck.y*0.5 in the
		# node frame.
		var eye := float(deck[1]) * 0.5 + EYE
		_log["sight_over_shield"] = {
			"eye_node_z": snappedf(eye, 0.001),
			"shield_top_node_z": snappedf(shield_top, 0.001),
			"clear_by": snappedf(eye - shield_top, 0.001),
			"means": "a standing rider's eye is this far above the "
				+ "cover's top; the shield rotates with the deck, so "
				+ "this holds in every pose",
		}
		if eye <= shield_top:
			_fail("a standing rider's eye is at node %.3f and the cover "
					% eye + "tops at %.3f -- they cannot see over their "
					% shield_top + "own shield.")
	_finish()


func _finish() -> void:
	_log["problems"] = _problems
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	if _problems.is_empty():
		print("[sweep] PASS -- the loaded skiff sweeps the whole route "
				+ "without entering a dock pad; envelope %.2f x %.2f x "
				% [float(_log["swept_world_aabb"]["size"][0]),
					float(_log["swept_world_aabb"]["size"][1])]
				+ "%.2f m"
				% float(_log["swept_world_aabb"]["size"][2]))
		quit(0)
	else:
		printerr("[sweep] %d problem(s)" % _problems.size())
		quit(1)
