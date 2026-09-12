extends Node

## SEVERAL ORDINARY GENERATED ZONES, COMPOSED AND WALKED.
##
## `godot-room-contract` proves a great deal about ONE Zone, which is one
## shape the composer happened to make. This takes a run of consecutive
## Zones from a real campaign -- `bridge/tools/dump_zones.py`, the same
## `CampaignEngine` path the game drives -- and asks the same questions of
## each: does it compose, what shape is it, which branches were physically
## placed, and can the real `Player` reach one and get back.
##
## **The fixture is not the evidence.** These files exist so a body can be
## walked through them; the report below is what the body found.
##
## No topology is preferred. Hub-and-spoke, shallow branches, deep nesting,
## several branches off one junction, dead ends -- all legal, and nothing
## here scores one against another. What is measured is whether the shape
## the composer chose can be built and walked.

const WALK_FRAMES := 1500
const ARRIVED := 4.0

## ZONES THE ROUTER CANNOT LAY OUT TODAY, and the room it wedges on.
##
## Four of five ordinary generated Zones come back LAYOUT_INFEASIBLE:
## the graphs are legal and the placement walk is greedy and never
## backtracks, so a Zone with eight rooms off its spine paints itself
## into a corner and the room that cannot fit is whichever one was last.
## `docs/AGENT_FRONTIER.md` has the arithmetic -- at this rate about two
## Zones in five exhaust their recompositions and go DORMANT, which is a
## Zone the player is offered and cannot enter.
##
## **Listed rather than tolerated silently, and the list is checked both
## ways.** A Zone that composes today and stops is a regression and
## fails; a Zone on this list that starts composing means the router was
## fixed and the list is stale, which also fails. The alternative -- a
## target that is simply red on a known defect -- is a target people
## learn to ignore, and then the regression it was meant to catch
## arrives unnoticed.
const KNOWN_INFEASIBLE := {
	"zone_02.json": "branch room 'c021' off 'c016'",
	"zone_03.json": "branch room 'c015' off 'c014'",
	"zone_04.json": "branch room 'c019' off 'c018'",
	"zone_05.json": "room 'c017' could not be placed",
}

var failures := 0
var walked_zones := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: %s" % message)
		return
	failures += 1
	print("FAIL: %s" % message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var dir := DirAccess.open("res://tests/fixtures/generated")
	if dir == null:
		_check(false, "res://tests/fixtures/generated is not there; run "
				+ "`make zone-fixtures`")
		get_tree().quit(1)
		return
	var names: Array[String] = []
	for file: String in dir.get_files():
		if file.begins_with("zone_") and file.ends_with(".json"):
			names.append(file)
	names.sort()
	_check(names.size() >= 3,
			"%d generated Zone(s) to walk; one shape is not a sample"
			% names.size())
	for file: String in names:
		await _walk_one(file)
	print("\n%d of %d Zone(s) had a branch a body reached from the "
			% [walked_zones, names.size()] + "junction doorway; see the "
			+ "note in `_walk_one` for why that is reported and not "
			+ "asserted here")
	if failures == 0:
		print("GODOT GRAPH TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT GRAPH TESTS: %d failures" % failures)
		get_tree().quit(1)

func _walk_one(file: String) -> void:
	var text := FileAccess.get_file_as_string(
			"res://tests/fixtures/generated/%s" % file)
	var zone: Dictionary = JSON.parse_string(text)
	var shape := _shape_of(zone)
	print("\n%s  %d rooms, %d joined edges, degrees %s"
			% [file, shape["rooms"], shape["edges"],
				str(shape["degrees"])])
	print("    junctions %s" % str(shape["junctions"]))
	print("    dead ends %s" % str(shape["dead_ends"]))

	# 1. DOES IT COMPOSE? The three answers are different answers and
	#    the report keeps them apart.
	var out := ZoneBuilder.build(zone)
	var status := str(out.get("status", "?"))
	print("    layout %s%s" % [status,
			"" if status == "LAYOUT_OK"
			else ": %s" % str(out.get("failed", "?"))])
	if KNOWN_INFEASIBLE.has(file):
		# A CLAIM, NOT A NARRATION OF THE FAILURE. `_check` prints its
		# message either way, so it has to read true when it passes.
		_check(status != "LAYOUT_OK",
				"%s is still one the router cannot lay out; the day it "
				% file + "composes, this list is stale and this line is "
				+ "how you find out")
		_check(str(out.get("failed", "")).contains(
					str(KNOWN_INFEASIBLE[file])),
				"%s wedges where it was recorded wedging (%s) rather "
				% [file, str(KNOWN_INFEASIBLE[file])]
				+ "than somewhere new: %s" % str(out.get("failed", "")))
	else:
		_check(status == "LAYOUT_OK",
				"%s composes (%s)" % [file, str(out.get("failed", ""))])
	if status != "LAYOUT_OK" or not out.has("root"):
		return
	add_child(out["root"] as Node3D)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 2. WHICH ROOMS WERE PHYSICALLY PLACED, and which of the off-spine
	#    ones among them. A branch in the graph that no transform exists
	#    for is a room the player cannot be in.
	var rooms: Dictionary = out["rooms"]
	var spine: Array = ZoneBuilder.placement_plan(zone).get("spine", [])
	var side: Array[String] = []
	var unplaced: Array[String] = []
	for raw: Variant in zone.get("chambers", []):
		var rid := str((raw as Dictionary)["id"])
		if not rooms.has(rid):
			unplaced.append(rid)
		elif not spine.has(rid):
			side.append(rid)
	side.sort()
	unplaced.sort()
	print("    placed: %d of %d rooms; %d off the spine %s"
			% [rooms.size() - (1 if rooms.has("exit") else 0),
				(zone.get("chambers", []) as Array).size(),
				side.size(), str(side)])
	_check(unplaced.is_empty(),
			"%s placed every room it declares (missing %s)"
			% [file, str(unplaced)])

	# 3. AND CAN A BODY GET TO ONE AND BACK? The real `Player`, from the
	#    junction the side room hangs off, through the doorway the
	#    assignment names.
	# COMPOSE-ONLY, for iterating on the router. The walk is the slow
	# half by two orders of magnitude, and a change to the placement
	# search is answered by whether the five Zones lay out.
	if OS.get_cmdline_user_args().has("--no-walk"):
		(out["root"] as Node3D).queue_free()
		await get_tree().process_frame
		return

	# THE PLAYER LEG IS REPORTED, NOT ASSERTED, AND HERE IS WHY.
	#
	# Standing a body at an arbitrary junction's side doorway is not a
	# solved problem: the room-contract journey walks c008's interior
	# and its branch from a spawn that was established for that room,
	# and this driver has no equivalent for a junction it has never
	# seen. A walk that cannot START is a finding about the harness, and
	# failing the target on it would report a Zone defect that is not
	# there — which is the opposite of separating the claims.
	#
	# What this target DOES assert is composition and placement, which
	# are the engine's and are where it is currently red.
	var reached := await _reach_a_branch(out, zone, spine, side)
	print("    player: %s" % str(reached["how"]))
	if bool(reached["walked"]):
		walked_zones += 1
	(out["root"] as Node3D).queue_free()
	await get_tree().process_frame

## Walks the real Player from a junction into one of its side rooms and
## back out, and says what happened.
func _reach_a_branch(out: Dictionary, zone: Dictionary, spine: Array,
		side: Array) -> Dictionary:
	if side.is_empty():
		return {"walked": false, "how": "no side destination to reach"}
	var doors: Dictionary = out.get("doors", {})
	var rooms: Dictionary = out["rooms"]
	for raw: Variant in zone.get("chambers", []):
		var chamber: Dictionary = raw
		var junction := str(chamber["id"])
		for raw_door: Variant in chamber.get("doors", []):
			var door: Dictionary = raw_door
			if str(door.get("usage", "")) != "USED":
				continue
			if not str(door.get("socket_id", "")).begins_with("side_"):
				continue
			var served := ""
			for raw_edge: Variant in zone.get("edges", []):
				var edge: Dictionary = raw_edge
				if str(edge.get("edge_id", "")) \
						!= str(door.get("edge_id", "")):
					continue
				served = str(edge["room_b"]) \
						if str(edge["room_a"]) == junction \
						else str(edge["room_a"])
			if served == "" or not side.has(served) \
					or not rooms.has(served):
				continue
			var mouth: Vector3 = doors.get(
					"%s/%s" % [junction, str(door["socket_id"])],
					Vector3.INF)
			if mouth == Vector3.INF:
				continue
			return await _walk_into(out, junction, served, mouth)
	return {"walked": false,
			"how": "no open side door onto a placed off-spine room"}

func _walk_into(out: Dictionary, junction: String, branch: String,
		mouth: Vector3) -> Dictionary:
	var rooms: Dictionary = out["rooms"]
	var box: AABB = (rooms[branch] as Dictionary)["bounds"]
	var target := box.position + box.size / 2.0
	var body := Player.create()
	(out["root"] as Node3D).add_child(body)
	# INSIDE THE JUNCTION, a quarter of the way toward its middle. The
	# doorway itself is a hole in a wall and the floor either side of it
	# is the room's, not the opening's: a body dropped ON the mouth falls
	# through the gap the connector bridges and the walk then reports how
	# far it got from the bottom of the world.
	var from: AABB = (rooms[junction] as Dictionary)["bounds"]
	var stand := mouth.lerp(from.position + from.size / 2.0, 0.25)
	body.global_position = Vector3(stand.x,
			mouth.y + Constants.PLAYER_HEIGHT, stand.z)
	body.velocity = Vector3.ZERO
	for _settle in 20:
		await get_tree().physics_frame
	var into := await _walk(body, Vector3(target.x,
			body.global_position.y, target.z), box.grow(1.0))
	var inside := box.grow(2.0).has_point(Vector3(
			body.global_position.x, target.y, body.global_position.z))
	if not inside:
		body.queue_free()
		return {"walked": false,
				"how": "%s -> %s: stopped %.1f m short at %v"
					% [junction, branch, float(into["closest"]),
						body.global_position]}
	var back := await _walk(body, Vector3(mouth.x,
			body.global_position.y, mouth.z), AABB())
	var out_again := not box.grow(1.0).has_point(body.global_position)
	body.queue_free()
	return {"walked": true,
			"how": "%s -> %s entered, and %s"
				% [junction, branch,
					("walked back out" if bool(back["arrived"])
						or out_again
					else "could not walk back out (closest %.1f m)"
						% float(back["closest"]))]}

## The same steer-and-press the room contract uses, kept short here: this
## driver's subject is the graph, not the controller.
func _walk(body: Player, goal: Vector3, stop_inside: AABB) -> Dictionary:
	var closest := INF
	var still := 0
	var last := body.global_position
	Input.action_press("move_forward", 1.0)
	for i in WALK_FRAMES:
		var here := body.global_position
		if stop_inside.has_volume() and stop_inside.has_point(here):
			break
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		closest = minf(closest, flat.length())
		if flat.length() <= ARRIVED:
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		if (here - last).length() < 0.012:
			still += 1
			if still == 24 and body.is_on_floor():
				Input.action_press("jump", 1.0)
				await get_tree().physics_frame
				Input.action_release("jump")
				still = 0
		else:
			still = 0
		last = here
		if still > 90:
			break
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var final := Vector2(goal.x - body.global_position.x,
			goal.z - body.global_position.z).length()
	return {"arrived": final <= ARRIVED, "closest": closest}

func _shape_of(zone: Dictionary) -> Dictionary:
	var adjacency := {}
	var joined := 0
	for raw: Variant in zone.get("edges", []):
		var edge: Dictionary = raw
		if str(edge.get("realization", "JOINED")) != "JOINED":
			continue
		joined += 1
		for pair: Array in [[str(edge["room_a"]), str(edge["room_b"])],
				[str(edge["room_b"]), str(edge["room_a"])]]:
			if not adjacency.has(pair[0]):
				adjacency[pair[0]] = {}
			(adjacency[pair[0]] as Dictionary)[pair[1]] = true
	var degrees := {}
	var junctions: Array[String] = []
	var dead_ends: Array[String] = []
	for raw: Variant in zone.get("chambers", []):
		var rid := str((raw as Dictionary)["id"])
		var n := (adjacency.get(rid, {}) as Dictionary).size()
		degrees[n] = int(degrees.get(n, 0)) + 1
		if n >= 3:
			junctions.append(rid)
		elif n == 1:
			dead_ends.append(rid)
	junctions.sort()
	dead_ends.sort()
	return {"rooms": (zone.get("chambers", []) as Array).size(),
			"edges": joined, "degrees": degrees,
			"junctions": junctions, "dead_ends": dead_ends}
