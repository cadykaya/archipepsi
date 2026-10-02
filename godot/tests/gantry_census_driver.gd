extends Node
## WHICH ARENAS TAKE THE MEASURED GANTRY (`make godot-gantry-census`).
##
## Dess's note D-10, for D-6 step 4 (the composer): "measure whether the
## gantry fits in the arena sizes the composer can produce ... each with
## the track crossing the room on the arrival axis, as the three-dock
## S1-S2-S3 layout would lay it. With the smallest size that fits, the
## composer takes its room choice from your numbers, not from a guess."
##
## **WHAT IS MEASURED.** The three-dock layout `godot-rail-gantry` builds
## (a corridor, the control arena, a corridor; a dock in each, the track
## through all three arrivals), with the arena at `wall_height` 8.0,
## through the real `ZoneController`. Whether a gantry is placed is the
## engine's own answer (`RailNetworks.gantry_frame`); a refusal is
## counted by the test each candidate failed.
##
## **A SAMPLE OF LAYOUTS, NOT ONE.** Whether the gantry fits depends on
## where the arena's props fall and on the line the track takes through
## it, and each has its own seed:
## - the props are seeded by the arena's chamber id
##   (`ChamberBuilders._greeble_rng`), so each size is built under
##   `SAMPLES` chamber ids;
## - the line is the chain's. A corner may turn it before the arena,
##   after it, or both, and the turns are seeded by the ZONE ID
##   (`zone_builder.gd`, `"%s|%s|layout"`), so each size is built under
##   every `ZONE_IDS` entry, one per shape the chain can take.
##
## The result is a count over that sample, stated as one. A size every
## sampled layout takes is a size the composer may rely on to that extent
## and no further.
##
## **THE ZONE'S `seed` FIELD IS NOT THE LAYOUT'S SEED (D10-F2).** The
## engine never reads it. This census's first version varied it, and so
## built each layout three times: every count it gave was a multiple of
## three, and the turned chains were never built. The chain's shape is
## now read back from the built Zone, and the census fails unless every
## shape it names was built.

## THE RULE THIS HOLDS FOR THE COMPOSER (N-18): an arena at least this
## wide and this deep takes the gantry in every sampled layout. It is the
## landmark arena's range as the fallback composer rolls it
## (`epsilon/fallback.py`: width 24-28 m, depth 22-26 m). The census fails
## if an engine change breaks it, so the composer's room choice cannot
## drift from the engine's measurement unnoticed. If Dess's rule differs,
## these follow it.
const GANTRY_ROOM_MIN_WIDTH := 24.0
const GANTRY_ROOM_MIN_DEPTH := 22.0
## What is measured, width x depth:
## - the landmark's range at every 2 m point;
## - two points off that grid, because the fallback rolls to 0.1 m;
## - the procedural maximum D-10 names (28 x 28);
## - and the control, below the rule.
const SIZES := [[24.0, 22.0], [26.0, 22.0], [28.0, 22.0],
		[24.0, 24.0], [26.0, 24.0], [28.0, 24.0],
		[24.0, 26.0], [26.0, 26.0], [28.0, 26.0],
		[25.3, 23.7], [27.1, 25.4], [28.0, 28.0], [16.0, 16.0]]
## THE CONTROL: an arena this size refuses the gantry in some sampled
## layout (58 of 168 fit when measured). If it refuses none, the census
## has stopped seeing refusals, and a rule it holds means nothing.
const CONTROL := [16.0, 16.0]
const HEIGHT := 8.0
const SAMPLES := ["c002", "c011", "c023", "c037", "c041", "c058", "c064",
		"c079", "c083", "c095", "c106", "c118", "c127", "c134", "c149",
		"c152", "c166", "c171", "c188", "c193", "c205", "c219", "c226",
		"c238"]
## One zone id per shape of the chain at the arena, named by the chain's
## turn before the arena / after it, in degrees. `0/0` is the track on
## the arrival axis, straight through: the case D-10 names. A corner
## turns the chain 90 degrees and the next one turns it back
## (`next_turn` alternates), so a three-room chain has exactly these
## seven.
const ZONE_IDS := {
	"0/0": "zone_census_01", "+90/0": "zone_census_00",
	"-90/0": "zone_census_04", "0/+90": "zone_census_30",
	"0/-90": "zone_census_16", "+90/-90": "zone_census_02",
	"-90/+90": "zone_census_06",
}
## `--census-sizes=24x22,26x22` measures those sizes instead (width x
## depth), for a composer that asks about sizes this list does not hold.
const SIZES_ARG := "--census-sizes="
## Refusing layouts at a size are named one by one up to this many.
const NAMED_REFUSALS := 6

var _rows: Array = []
## Shapes named by `ZONE_IDS` that a zone id did not build, by size.
var _unbuilt: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	for _i in 5:
		await get_tree().physics_frame
	var total := SAMPLES.size() * ZONE_IDS.size()
	var shapes: Array[String] = []
	for shape: String in ZONE_IDS:
		shapes.append(shape)
	print("width\tdepth\tfits\tof\trefusals (summed)\tms per build")
	for size: Array in _sizes():
		var fits := 0
		var why: Dictionary = {}
		var spent := 0
		var by_shape: Dictionary = {}
		var refused: Array[String] = []
		for shape: String in shapes:
			by_shape[shape] = 0
			for room: String in SAMPLES:
				var zone := _zone(room, float(size[0]), float(size[1]),
						str(ZONE_IDS[shape]))
				var t0 := Time.get_ticks_msec()
				var controller := ZoneController.new()
				get_tree().root.add_child(controller)
				controller.setup(zone)
				spent += Time.get_ticks_msec() - t0
				for _i in 3:
					await get_tree().physics_frame
				var built := _shape_of(controller.room_places, room)
				if built != shape:
					_unbuilt.append("%s: %s built %s, not %s" % [_dims(size),
							ZONE_IDS[shape], built, shape])
				if controller.layout_failed != "":
					why["layout failed"] = int(why.get("layout failed", 0)) + 1
				elif controller.rail_refusals.is_empty() \
						and not controller.rail_junctions().is_empty():
					fits += 1
					by_shape[shape] = int(by_shape[shape]) + 1
				else:
					for refusal: String in controller.rail_refusals:
						_tally(refusal, why)
						var cut := refusal.find("': ",
								maxi(refusal.find("in room"), 0))
						refused.append("%s at %s: %s" % [room, shape,
								refusal.substr(cut + 3 if cut >= 0 else 0)])
				controller.queue_free()
				for _i in 2:
					await get_tree().process_frame
		var parts: Array[String] = []
		for key: String in why:
			parts.append("%s %d" % [key, why[key]])
		print("%s\t%s\t%d\t%d\t%s\t%d" % [_dim(size[0]), _dim(size[1]), fits,
				total, ", ".join(parts) if not parts.is_empty() else "-",
				spent / total])
		if refused.size() <= NAMED_REFUSALS:
			for line: String in refused:
				print("  refused: " + line)
		_rows.append([size, fits, by_shape])
	print("")
	print("by the chain's turn before the arena / after it (0/0: the track on"
			+ " the arrival axis), of %d each:" % SAMPLES.size())
	print("width\tdepth\t" + "\t".join(shapes))
	for row: Array in _rows:
		var size: Array = row[0]
		var cells: Array[String] = []
		for shape: String in shapes:
			cells.append(str(row[2][shape]))
		print("%s\t%s\t" % [_dim(size[0]), _dim(size[1])] + "\t".join(cells))
	var every: Array[String] = []
	var some: Array[String] = []
	for row: Array in _rows:
		(every if int(row[1]) == total else some).append(_dims(row[0]))
	print("")
	print("every sampled layout (%d) takes the gantry at: %s" % [total,
			", ".join(every) if not every.is_empty() else "none"])
	print("some refuse it at: %s" % (", ".join(some)
			if not some.is_empty() else "none"))
	var failed := false
	# THE SAMPLE IS WHAT IT SAYS (D10-F2): every shape it names was built.
	if not _unbuilt.is_empty():
		failed = true
		print("FAIL: the sample did not build the chain shapes it names "
				+ "(%d): " % _unbuilt.size() + "; ".join(_unbuilt.slice(0, 4)))
	else:
		print("every size was built in all %d chain shapes" % shapes.size())
	# THE CONTROL: the census can see a refusal.
	for row: Array in _rows:
		if _dims(row[0]) != _dims(CONTROL):
			continue
		if int(row[1]) == total:
			failed = true
			print("FAIL: the control (%s) refuses no layout: the census "
					% _dims(CONTROL) + "cannot see a refusal")
		else:
			print("the control (%s) refuses %d of %d layouts" % [_dims(CONTROL),
					total - int(row[1]), total])
	# THE COMPOSER'S RULE, held.
	var broken: Array[String] = []
	for row: Array in _rows:
		var size: Array = row[0]
		if float(size[0]) >= GANTRY_ROOM_MIN_WIDTH \
				and float(size[1]) >= GANTRY_ROOM_MIN_DEPTH \
				and int(row[1]) < total:
			broken.append("%s takes %d of %d" % [_dims(size), row[1], total])
	var rule := "width %s m or more, depth %s m or more" % [
			_dim(GANTRY_ROOM_MIN_WIDTH), _dim(GANTRY_ROOM_MIN_DEPTH)]
	if not broken.is_empty():
		failed = true
		print("FAIL: the composer's rule (%s) is broken: " % rule
				+ "; ".join(broken))
	if not failed:
		print("GANTRY CENSUS OK (every sampled layout of an arena %s " % rule
				+ "takes a gantry)")
		get_tree().quit(0)
		return
	print("GANTRY CENSUS: FAILED")
	get_tree().quit(1)


## `SIZES`, or the sizes `--census-sizes=` names.
static func _sizes() -> Array:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with(SIZES_ARG):
			continue
		var out: Array = []
		for pair: String in arg.substr(SIZES_ARG.length()).split(","):
			var parts := pair.split("x")
			out.append([float(parts[0]), float(parts[1])])
		return out
	return SIZES


## The chain's turn before the arena and after it, read from where the
## Zone put its rooms: "+90/-90" is a corner each side, the second
## turning back.
static func _shape_of(places: Dictionary, room: String) -> String:
	var yaws: Array[float] = []
	for rid: String in ["c001", room, "c003"]:
		yaws.append(float((places.get(rid, {}) as Dictionary).get("yaw", 0.0)))
	var turns: Array[String] = []
	for i in 2:
		var turn := roundi(rad_to_deg(wrapf(yaws[i + 1] - yaws[i], -PI, PI)))
		turns.append("%+d" % turn if turn != 0 else "0")
	return "/".join(turns)


static func _dim(value: float) -> String:
	return "%.0f" % value if is_equal_approx(value, roundf(value)) \
			else "%.1f" % value


static func _dims(size: Array) -> String:
	return "%s x %s" % [_dim(float(size[0])), _dim(float(size[1]))]


## Sum a refusal's per-test counts ("no position ... (900 tried: 526
## outside the room, 324 on the track, ...)"), or count it whole.
func _tally(refusal: String, why: Dictionary) -> void:
	var open := refusal.find("tried: ")
	if open < 0:
		var key := refusal.substr(refusal.find(": ") + 2, 40)
		why[key] = int(why.get(key, 0)) + 1
		return
	var close := refusal.find(")", open)
	for part: String in refusal.substr(open + 7, close - open - 7).split(", "):
		var space := part.find(" ")
		var key := part.substr(space + 1)
		why[key] = int(why.get(key, 0)) + int(part.substr(0, space))


func _zone(room: String, width: float, depth: float,
		zone_id: String) -> Dictionary:
	var chambers: Array = []
	var docks: Array = []
	var ids := ["c001", room, "c003"]
	for i in 3:
		var rid: String = ids[i]
		var chamber := {
			"id": rid, "type": "corridor", "theme": "concrete_facility",
			"activities": [], "features": [], "enemies": [],
			"rewards": [], "interactables": [],
		}
		if i == 1:
			chamber["type"] = "arena"
			chamber["width"] = width
			chamber["depth"] = depth
			chamber["wall_height"] = HEIGHT
		chambers.append(chamber)
		docks.append({"dock_id": "d%d" % i, "room_id": rid})
	return {
		"schema_version": 7, "zone_id": zone_id, "seed": 7,
		"theme": "concrete_facility", "chambers": chambers,
		"rail_networks": [{
			"network_id": "yard", "docks": docks,
			"spans": [{"span_id": "s0", "from_dock": "d0", "to_dock": "d1",
				"control_room_id": room, "latch_id": "s0_latch",
				"mandatory": true, "control_placement": "gantry"}],
		}],
	}
