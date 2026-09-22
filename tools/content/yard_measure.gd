extends SceneTree
## MEASURE THE BLINDSIDE YARD, using Production's own RailPath.
##
## Art has to fit rails, docks, a swinging span and a gantry that already
## exist. Every number those things stand on is either a constant in
## `railway_scenario.gd` or a point on a Catmull-Rom curve -- and the
## curve points cannot be restated, only evaluated. An art lane that
## writes "the gap is about fourteen metres" into a Blender script has
## guessed; the last batch's gantry finding only held up because the
## arithmetic was done against their file rather than against a memory
## of it.
##
## So this harness rebuilds THEIR rail from THEIR five control points
## with THEIR RailPath (fetched read-only, `class_name` stripped) and
## writes what it measures. `build_yardkit.py` reads the result. Nothing
## here is authored, placed or changed: it is a ruler.
##
## The scenario's own constants are passed in from the runner, which
## greps them out of `railway_scenario.gd`, so a constant that moves in
## Production moves here on the next run instead of rotting quietly.

const RailPathScript := preload("res://_harness/prod_rail_path.gd")

var _out := ""
var _k := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: yard_measure.gd <constants.json> <out.json>")
		quit(2)
		return
	var text := FileAccess.get_file_as_string(args[0])
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("could not read the scenario constants from %s" % args[0])
		quit(2)
		return
	_k = parsed
	_out = args[1]
	# EVERY CONSTANT, UP FRONT, AND quit() RATHER THAN push_error().
	#
	# The first cut of this file raised a `push_error` from inside the
	# getters and carried on with a zero. Sabotage-tested by deleting
	# `DECK` from the constants file, it measured the deck top at 0.60
	# instead of 1.00 and reported PASS -- the runner never saw a
	# failure, because a `push_error` inside a `-s` script did not
	# surface as one here. A ruler that answers when it has nothing to
	# measure by is the same defect as a gate that cannot fail, and it
	# would have put a wrong number into a Blender script.
	#
	# So: the whole list is checked before anything is measured, and the
	# refusal is an EXIT STATUS, which `run_godot` cannot miss.
	var missing := []
	for key: String in SCALARS:
		if not _k.has(key) or typeof(_k[key]) not in [
				TYPE_FLOAT, TYPE_INT]:
			missing.append(key)
	for key: String in VECTORS:
		if not _k.has(key) or typeof(_k[key]) != TYPE_ARRAY \
				or (_k[key] as Array).size() < int(VECTORS[key]):
			missing.append(key)
	if not missing.is_empty():
		printerr("[yard] REFUSED: railway_scenario.gd no longer supplies "
			+ ", ".join(missing) + " in the shape this measurement "
			+ "needs. Nothing was written: a default nobody chose is "
			+ "not a measurement.")
		quit(3)
		return
	_measure()
	quit(0)


## The constants this measurement stands on, and the shape each must
## have. Named here so a rename in Production is a refusal, not a zero.
const SCALARS := ["RAIL_Y", "DOCK_OUT", "GANTRY_Y", "GANTRY_OUT",
	"GANTRY_PLATE_Y", "BRANCH_OUT", "SHIELD_HEIGHT"]
const VECTORS := {"DECK": 3, "DOCK": 3, "VOID_HALF": 2}


func _need(key: String) -> float:
	return float(_k[key])


func _v3(key: String) -> Vector3:
	var a: Array = _k[key]
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _measure() -> void:
	var rail_y := _need("RAIL_Y")
	var deck := _v3("DECK")
	var dock := _v3("DOCK")
	var dock_out := _need("DOCK_OUT")
	var gantry_y := _need("GANTRY_Y")
	var gantry_out := _need("GANTRY_OUT")
	var plate_y := _need("GANTRY_PLATE_Y")
	var branch_out := _need("BRANCH_OUT")
	var shield_h := _need("SHIELD_HEIGHT")
	var void_half: Variant = _k["VOID_HALF"]

	# THEIR five control points, in their order. `_ready()` lays these
	# and nothing else decides the shape of the ride.
	var rail = RailPathScript.from_points(PackedVector3Array([
		Vector3(0, rail_y, 0),
		Vector3(16, rail_y, 0),
		Vector3(24, rail_y, 6),
		Vector3(24, rail_y, 12),
		Vector3(24, rail_y, 26),
	]))
	var offsets := PackedFloat32Array([
		0.0,
		rail.nearest_offset(Vector3(24, rail_y, 12)),
		rail.length(),
	])

	var top := rail_y + deck.y
	var docks := []
	for i in offsets.size():
		var where: Vector3 = rail.at(offsets[i])
		var along: Vector3 = rail.tangent(offsets[i])
		var side: Vector3 = Vector3.UP.cross(along).normalized()
		var centre := where + side * dock_out \
			+ Vector3(0.0, top - rail_y - dock.y * 0.5, 0.0)
		docks.append({
			"name": ["S1", "S2", "S3"][i],
			"offset": offsets[i],
			"rail_point": _a(where),
			"along": _a(along),
			"side": _a(side),
			"pad_centre": _a(centre),
			"pad_size_local": _a(dock),
			"pad_top_y": centre.y + dock.y * 0.5,
			# The lateral coordinates art may not cross: the pad's inner
			# edge is where the deck's outer edge arrives.
			"lateral_inner": dock_out - dock.x * 0.5,
			"lateral_outer": dock_out + dock.x * 0.5,
			"receiver_lateral": 2.6,
			"receiver_along": 1.9,
			"receiver_head_y": top + 1.5,
		})

	# THE SPAN. Its pivot frame is the scenario's `SpanPivot`: the S2
	# rail point, looking along the track. The beam hangs half a gap
	# down its local +Z, and the stow is a pitch about local X.
	var gap: float = offsets[2] - offsets[1]
	var stow_deg := 62.0
	var span_far_stowed := Vector3(0.0, sin(deg_to_rad(stow_deg)) * gap,
		cos(deg_to_rad(stow_deg)) * gap)

	# THE GANTRY, measured off S2 exactly as `_gantry()` does.
	var g_where: Vector3 = rail.at(offsets[1])
	var g_along: Vector3 = rail.tangent(offsets[1])
	var g_side: Vector3 = Vector3.UP.cross(g_along).normalized()
	var g_deck := g_where + g_side * gantry_out \
		+ Vector3(0.0, gantry_y, 0.0)
	var g_plate := g_deck - g_side * 2.0 \
		+ Vector3(0.0, plate_y - g_deck.y, 0.0)

	var report := {
		"measured_with": "Production's own RailPath, read-only",
		"constants": _k,
		"rail": {
			"length": rail.length(),
			"y": rail_y,
			"polyline": _poly(rail),
		},
		"deck_top_y": top,
		"docks": docks,
		"span": {
			"pivot": _a(g_where),
			"pivot_forward": _a(g_along),
			"gap": gap,
			"beam_thickness": 0.45,
			"beam_centre_local": [0.0, 0.0, gap * 0.5],
			"stowed_degrees": stow_deg,
			"far_end_local_stowed": _a(span_far_stowed),
			"far_end_local_aligned": [0.0, 0.0, gap],
			# The stow is steeper than the controller's walkable limit,
			# so a raised span is not a ramp. Art must not flatten it.
			"walkable_limit_degrees": 46.0,
		},
		"gantry": {
			"along": 0.0,
			"deck_centre": _a(g_deck),
			"deck_size": [4.0, 0.4, 4.0],
			"column_size": [0.6, gantry_y, 0.6],
			"plate_centre": _a(g_plate),
			"plate_size": [1.2, 0.3, 1.2],
			"ring_centre": _a(g_plate - Vector3(0.0, 0.32, 0.0)),
			"ring_outer_radius": 0.42,
			"lateral_deck": gantry_out,
			"lateral_plate": gantry_out - 2.0,
		},
		"branch": {
			# `branch_lane()` is -tangent * 3.0, so the walkway and the
			# yard sit THREE METRES BACK ALONG THE TRACK from S2 while
			# the gantry sits square on it. The eye-to-ring line is
			# therefore a diagonal in plan, not a line down one axis --
			# which is why the sight corridor carries an along-track
			# extent as well as a height.
			"lane_along": -3.0,
			"half_across": 5.0,
			"lateral_yard": branch_out,
			"yard_size": [10.0, 0.4, 10.0],
			"walk_from": dock_out,
			"walk_to": branch_out - 4.0,
			"walkway_width": 3.0,
			"top_y": top,
		},
		"shield": {
			"size": [0.3, shield_h, deck.z],
			"local_centre": [-(deck.x * 0.5 - 0.15),
				deck.y * 0.5 + shield_h * 0.5, 0.0],
		},
		"void_half": void_half,
	}
	# THE SIGHTLINE, solved rather than asserted. A05.1 says the
	# hookshot target stays visible from the first-visit approach, so
	# the number art has to obey is the height of the line from a
	# player's eye on the branch to the ring -- at every lateral
	# position between them.
	# THE TIGHTEST VIEWPOINT, NOT A CONVENIENT ONE.
	#
	# The first cut drew one line from the middle of the branch yard at
	# lateral 20 and called that the sightline. It is the most generous
	# viewpoint there is: the further back the player stands, the flatter
	# the line to the ring and the more room art has underneath it. A
	# player walking out along the walkway sees the same ring over a
	# STEEPER line, and clears less. Gating on the generous one would
	# have let this batch build something that hides the hookshot target
	# from most of the approach and still passes.
	#
	# So the ceiling at each lateral is the LOWEST the line ever is,
	# across every viewpoint on the approach -- from the near end of the
	# walkway out to the far edge of the branch yard.
	var eye := 1.6
	var nearest: float = report["branch"]["walk_to"]
	var furthest: float = branch_out + 5.0
	report["sightline"] = _sightline(nearest, furthest, top + eye,
		report["gantry"]["lateral_plate"], g_plate.y - 0.32,
		report["branch"]["lane_along"], report["branch"]["half_across"],
		report["gantry"]["along"])
	_write(report)


## The ceiling art may not build above, between the ring and the branch.
##
## For each lateral between the two, the lowest the eye-to-ring line
## sits over ANY viewpoint on the approach. Monotonic in the viewer's
## lateral, so the minimum is at the nearest viewpoint -- but it is
## sampled rather than argued, because the argument is the kind that is
## right until the geometry changes.
func _sightline(nearest: float, furthest: float, from_y: float,
		to_lateral: float, to_y: float, lane_along: float,
		half_across: float, to_along: float) -> Dictionary:
	var views := []
	var v := nearest
	while v <= furthest + 0.001:
		views.append(v)
		v += 1.0
	# A SWEPT CORRIDOR, AND TWO EARLIER CUTS WERE BOTH WRONG.
	#
	# The first reported one height per lateral and the builder refused
	# anything ABOVE it -- which is not what occlusion is. A beam hanging
	# over the eye-to-ring line does not stand in front of the ring; it
	# stands over it. That gate fired on a legal support stay.
	#
	# The second fixed the inequality but stayed flat, collapsing the
	# along-track axis. `branch_lane()` puts the whole branch 3 m BACK
	# along the track while the gantry sits square on it, so every ray is
	# a diagonal in plan -- and a flat gate says a mast beside the
	# walkway blocks a view it is nowhere near. It refused the branch
	# landmark, and the honest fix was the measurement, not a shorter
	# mast.
	#
	# So each lateral now reports the extent of the RAY BUNDLE there, in
	# height and along-track alike, over every eye position on the
	# branch: the walkway's width and the yard's. Art occludes only when
	# it overlaps both.
	var samples := []
	var lateral := to_lateral
	while lateral <= furthest - 0.999:
		var low_y := INF
		var high_y := -INF
		var low_a := INF
		var high_a := -INF
		for view: float in views:
			if view <= lateral + 0.001:
				continue
			var t := (view - lateral) / (view - to_lateral)
			var h := lerpf(from_y, to_y, t)
			low_y = minf(low_y, h)
			high_y = maxf(high_y, h)
			# The eye sweeps the branch's own width, so the bundle is
			# wider than one line: both edges are carried.
			for across: float in [lane_along - half_across,
					lane_along + half_across]:
				var a := lerpf(across, to_along, t)
				low_a = minf(low_a, a)
				high_a = maxf(high_a, a)
		if low_y < INF:
			samples.append({
				"lateral": snappedf(lateral, 0.001),
				"low_y": snappedf(low_y, 0.001),
				"high_y": snappedf(high_y, 0.001),
				"low_along": snappedf(low_a, 0.001),
				"high_along": snappedf(high_a, 0.001),
			})
		lateral += 0.5
	return {
		"from": {"nearest_lateral": nearest, "furthest_lateral": furthest,
			"eye_y": from_y, "lane_along": lane_along,
			"half_across": half_across,
			"means": "player eye anywhere on the acquisition approach"},
		"to": {"lateral": to_lateral, "y": to_y, "along": to_along,
			"means": "the grapple ring's centre"},
		"rule": "art occludes only where it overlaps BOTH the "
			+ "low_y..high_y band and the low_along..high_along band at "
			+ "a lateral it occupies. Above, below or beside are clear.",
		"samples": samples,
	}


func _poly(rail) -> Array:
	var out := []
	for p: Vector3 in rail.polyline(1.0):
		out.append(_a(p))
	return out


func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001),
		snappedf(v.z, 0.0001)]


func _write(report: Dictionary) -> void:
	var f := FileAccess.open(_out, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % _out)
		return
	f.store_string(JSON.stringify(report, "  ", true, true))
	f.close()
	print("[yard] measured: rail %.2f m, gap %.2f m, %d docks, "
		% [report["rail"]["length"], report["span"]["gap"],
			report["docks"].size()]
		+ "%d sight-corridor samples"
		% report["sightline"]["samples"].size())
