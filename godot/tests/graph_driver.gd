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

## ZONES THE ROUTER CANNOT LAY OUT TODAY: the status, and where it wedges.
##
## **EMPTY, AND THAT IS THE POINT.** Every preserved ordinary input lays
## out, so there is no waiver left to grant and each of the five is a
## POSITIVE regression control: the `else` arm below demands
## `LAYOUT_OK` of any Zone not named here, and nothing is named here.
##
## It stays in the file because the shape of the record is what made the
## repair legible. Four Zones sat on it -- `zone_02` wedging on branch
## `c021` off `c016`, `zone_03` on `c015` off `c014`, `zone_04` on
## `c019` off `c018`, `zone_05` on spine room `c017` -- and the entries
## pinned the STATUS as well as the room, because `LAYOUT_TIMEOUT` and
## `LAYOUT_INFEASIBLE` are different answers and a repair that swapped
## one for the other while the Zone stayed unbuildable would have read
## as "unchanged".
##
## **A BASELINE IS NOT A PASS.** If a Zone is ever added back here, it
## records what is broken so a change to it is visible; it does not make
## that Zone playable. The strict playable-acceptance result below counts
## every Zone that does not lay out, whether or not it is listed here,
## and fails. Two results, deliberately: one answers "did this change?",
## the other answers "can a player be given this Zone?", and they are
## not the same question.
##
## Checked both ways. A Zone that composes today and stops is a
## regression; a Zone on this list that starts composing means the router
## was repaired and the list is stale. Both fail.
const KNOWN_INFEASIBLE := {}

var failures := 0
## The retry ladder, measured rather than estimated.
var attempts_total := 0
var solve_ms_total := 0.0
## THE THREE OUTCOMES OF A JOURNEY, COUNTED APART.
##
## `inconclusive` is the one that matters: a harness that could not
## START -- no junction with a placed off-spine neighbour, no committed
## door position, a body that fell through the floor before it took a
## step -- has measured nothing about the Zone. Reporting that as a pass
## is how a suite comes to claim more than it did.
var journeys_valid := 0
var journeys_entered := 0
var journeys_returned := 0
var journeys_inconclusive := 0
## Zones that did not lay out, whether or not they are on the list.
var unplayable: Array[String] = []

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

	# --- the two results, reported apart ---------------------------------
	print("\nBASELINE   %d Zone(s) waived as unbuildable; the other %d "
			% [KNOWN_INFEASIBLE.size(),
				names.size() - KNOWN_INFEASIBLE.size()]
			+ "are positive controls and must lay out"
			if failures == 0
			else "\nBASELINE   drifted; see the failures above")
	print("SOLVE      %d placement attempt(s) across %d Zone(s) in "
			% [attempts_total, names.size()]
			+ "%.0f ms total" % solve_ms_total)
	print("JOURNEYS   %d valid start(s): %d entered a branch, %d got "
			% [journeys_valid, journeys_entered, journeys_returned]
			+ "back out. %d inconclusive (the harness could not start)"
			% journeys_inconclusive)

	# A HARNESS THAT NEVER MANAGED A VALID START MEASURED NOTHING, and
	# saying so is the difference between "no defects found" and "no
	# search performed". Not asked in compose-only mode, where no
	# journey was attempted and zero valid starts is the expected count
	# rather than a finding.
	if not OS.get_cmdline_user_args().has("--no-walk"):
		_check(journeys_valid >= 1,
				"at least one Zone gave the harness a valid start; %d "
				% journeys_inconclusive + "were inconclusive and a suite "
				+ "that cannot begin has not passed")

	# --- STRICT PLAYABLE ACCEPTANCE, which is a different question -------
	#
	# `KNOWN_INFEASIBLE` documents what is broken so a CHANGE to it is
	# visible. It does not make a Zone playable, and a suite that went
	# green on the strength of it would be reporting "unchanged" as
	# "ready". A Zone the composer produced and the router cannot lay out
	# is a Zone the player is offered and cannot enter.
	var playable := names.size() - unplayable.size()
	print("PLAYABLE   %d of %d generated Zone(s) lay out%s"
			% [playable, names.size(),
				"" if unplayable.is_empty()
				else "; unbuildable: %s" % str(unplayable)])
	if not unplayable.is_empty():
		print("GODOT GRAPH TESTS: NOT PLAYABLE -- %d of %d Zone(s) do "
				% [unplayable.size(), names.size()] + "not lay out (%s)"
				% str(unplayable)
				+ "\n  the baseline is unchanged, which is not the same "
				+ "claim: see KNOWN_INFEASIBLE in graph_driver.gd")
		get_tree().quit(1)
		return
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
	# WHAT THE REPAIR ACTUALLY COST, per input: how many bounded
	# re-solves it took and how long they took. "Four of five failed" is
	# an observation about layouts; this is an observation about the
	# retry ladder, and they are different numbers.
	print("    solve  %d placement attempt(s) in %.0f ms; nudged %s"
			% [int(out.get("placement_attempts", 1)),
				float(out.get("placement_ms", 0.0)),
				"nothing" if (out.get("placement_nudges", {})
					as Dictionary).is_empty()
				else str(out.get("placement_nudges", {}))])
	attempts_total += int(out.get("placement_attempts", 1))
	solve_ms_total += float(out.get("placement_ms", 0.0))
	if status != "LAYOUT_OK":
		unplayable.append(file)
	if KNOWN_INFEASIBLE.has(file):
		var recorded: Dictionary = KNOWN_INFEASIBLE[file]
		# A CLAIM, NOT A NARRATION OF THE FAILURE. `_check` prints its
		# message either way, so it has to read true when it passes.
		_check(status != "LAYOUT_OK",
				"%s is still one the router cannot lay out; the day it "
				% file + "composes, this list is stale and this line is "
				+ "how you find out")
		# THE STATUS, NOT ONLY THE ROOM. A timeout and an infeasibility
		# are different answers -- the clock ran out, versus no layout
		# exists -- and a change that swapped one for the other while
		# the Zone stayed unbuildable would otherwise read as
		# "unchanged".
		_check(status == str(recorded["status"]),
				"%s still fails as %s, which is the status recorded for "
				% [file, status] + "it (%s)" % str(recorded["status"]))
		_check(str(out.get("failed", "")).contains(
					str(recorded["where"])),
				"%s wedges where it was recorded wedging (%s) rather "
				% [file, str(recorded["where"])]
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

	# THREE OUTCOMES, AND THEY ARE NOT ONE OUTCOME.
	#
	# * **setup** -- could the harness even start? No junction with a
	#   placed off-spine neighbour, no committed door position, or a
	#   body that fell through the floor before it took a step, and this
	#   run has measured NOTHING about the Zone. That is inconclusive,
	#   not a pass: the previous version returned `walked` for it and
	#   the summary then claimed a journey nobody made.
	# * **entry** -- did the body reach the side destination?
	# * **return** -- did it get back out, by the junction or by the
	#   Zone's own return pad?
	#
	# Once the setup is valid the last two are ASSERTED. A journey that
	# started and then broke is a Zone finding, and a harness whose
	# route can break without failing anything is a harness measuring
	# nothing.
	var reached := await _reach_a_branch(out, zone, spine, side)
	print("    player: %s" % str(reached["how"]))
	if not bool(reached["valid"]):
		journeys_inconclusive += 1
		print("    player: INCONCLUSIVE -- the harness could not start, "
				+ "so this says nothing about the Zone")
	else:
		journeys_valid += 1
		if bool(reached["entered"]):
			journeys_entered += 1
		if bool(reached["returned"]):
			journeys_returned += 1
		_check(bool(reached["entered"]),
				"%s: a body that started at the junction reached the "
				% file + "side destination (%s)" % str(reached["how"]))
		if bool(reached["entered"]):
			_check(bool(reached["returned"]),
					"%s: and got back out again (%s)"
					% [file, str(reached["how"])])
	(out["root"] as Node3D).queue_free()
	await get_tree().process_frame

## Walks the real Player from a junction into one of its side rooms and
## back out, and says what happened.
func _reach_a_branch(out: Dictionary, zone: Dictionary, spine: Array,
		side: Array) -> Dictionary:
	if side.is_empty():
		return _no_start("no side destination to reach")
	var doors: Dictionary = out.get("doors", {})
	var rooms: Dictionary = out["rooms"]
	for raw: Variant in zone.get("chambers", []):
		var chamber: Dictionary = raw
		var junction := str(chamber["id"])
		for raw_door: Variant in chamber.get("doors", []):
			var door: Dictionary = raw_door
			if str(door.get("usage", "")) != "USED":
				continue
			# **THE ASSIGNMENT SAYS WHICH DOOR SERVES THE BRANCH, not
			# the socket's name.** This used to require a `side_` prefix,
			# which was the procedural room's naming convention and
			# nothing more -- so Arty's `branch_east` / `branch_west`
			# openings were invisible to it and a junction built from one
			# of those shells read as "no open side door". What makes a
			# door a branch door is the JOINED edge it carries and the
			# off-spine room at the other end of it.
			var served := _joined_through(zone, junction,
					str(door.get("edge_id", "")))
			if served == "" or not side.has(served) \
					or not rooms.has(served):
				continue
			var mouth: Vector3 = doors.get(
					"%s/%s" % [junction, str(door["socket_id"])],
					Vector3.INF)
			if mouth == Vector3.INF:
				continue
			return await _walk_into(out, junction, served, mouth)
	return _no_start("no door carrying a JOINED edge onto a placed "
			+ "off-spine room")

## The room on the other end of `edge_id`, if it is a JOINED edge of
## `from`. Empty for a plug, an unrealized edge, or an id nothing carries.
func _joined_through(zone: Dictionary, from: String,
		edge_id: String) -> String:
	if edge_id == "":
		return ""
	for raw: Variant in zone.get("edges", []):
		var edge: Dictionary = raw
		if str(edge.get("edge_id", "")) != edge_id:
			continue
		if str(edge.get("realization", "JOINED")) != "JOINED":
			return ""
		return str(edge["room_b"]) if str(edge["room_a"]) == from \
				else str(edge["room_a"])
	return ""

## The harness could not begin. Not a pass and not a Zone failure.
func _no_start(why: String) -> Dictionary:
	return {"valid": false, "entered": false, "returned": false,
			"how": why}

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
	# DID THE BODY EVEN GET A PLACE TO STAND? A capsule that fell out of
	# the world during the settle never started, and everything measured
	# after that is about the fall. `from` is the junction's committed
	# envelope, so "below its floor" is a fact and not a guess.
	if body.global_position.y < from.position.y - Constants.PLAYER_HEIGHT:
		var fell := body.global_position
		body.queue_free()
		return _no_start("the body fell out of '%s' before it took a "
				% junction + "step (ended at %v)" % fell)

	var into := await _walk(body, Vector3(target.x,
			body.global_position.y, target.z), box.grow(1.0))
	var inside := box.grow(2.0).has_point(Vector3(
			body.global_position.x, target.y, body.global_position.z))
	if not inside:
		var stopped := body.global_position
		body.queue_free()
		return {"valid": true, "entered": false, "returned": false,
				"how": "%s -> %s: stopped %.1f m short at %v"
					% [junction, branch, float(into["closest"]), stopped]}

	# AND BACK. Either way the Zone offers: out through the junction, or
	# the return pad the composer put in the destination. `returned` is
	# the answer to that question and not to the previous one -- the
	# version before this reported success for a journey that got in and
	# could not get out, which is the half that matters to a player.
	var back := await _walk(body, Vector3(mouth.x,
			body.global_position.y, mouth.z), AABB())
	var start := _anchor_of(out, "zone_start")
	var by_pad := start != Vector3.INF and Vector2(
			body.global_position.x - start.x,
			body.global_position.z - start.z).length() < 6.0
	var out_again := not box.grow(1.0).has_point(body.global_position)
	var returned := bool(back["arrived"]) or by_pad or out_again
	var ended := body.global_position
	body.queue_free()
	return {"valid": true, "entered": true, "returned": returned,
			"how": "%s -> %s entered, and %s"
				% [junction, branch,
					("walked back out" if bool(back["arrived"])
					else ("taken home by the return pad" if by_pad
					else ("left the room" if out_again
					else "could NOT get back out (closest %.1f m, at %v)"
						% [float(back["closest"]), ended])))]}

## The Zone start, from the committed anchors, or `Vector3.INF`.
func _anchor_of(out: Dictionary, name: String) -> Vector3:
	var anchors: Dictionary = out.get("anchors", {})
	if not anchors.has(name):
		return Vector3.INF
	return anchors[name]

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
