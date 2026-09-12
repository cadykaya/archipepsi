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
## ONE LEG OF A CORRIDOR, not a whole journey. A route can be a dozen
## waypoints long, and giving each of them the whole budget turned a
## two-minute suite into an open-ended one. A connector is five metres
## and `WALK_SPEED` is seven, so a leg a body cannot finish in this many
## frames is a leg it is not going to finish.
const LEG_FRAMES := 300

## HOW MANY OF THE DECLARED SAMPLE LAY OUT TODAY. A ratchet, not a pass.
##
## The five preserved inputs are a strict gate: every one of them must
## lay out. The twenty-Zone sample is a COVERAGE MEASUREMENT, and
## pretending otherwise would be the same waiver this file just stopped
## granting -- so the number is recorded, every result including the
## failures is printed, and the run goes red if coverage drops or if a
## Zone that does lay out produces a manifest the bridge refuses.
##
## Sixteen, and TWO OF THE SIXTEEN ARE NOT CLEAN. `zone_10` and
## `zone_12` lay out with two rooms overlapping by more than
## `layout.py` accepts -- a millimetre on every axis, where the router
## tolerates half a cubic metre of volume at a join -- so the bridge
## would refuse those manifests. The router refusing them itself was
## measured and reverted (see `zone_builder.gd`, the reservation and
## overlap notes) because the stack of changes it needed cost four of
## the five preserved Zones. Counted here as laying out because they do;
## named here because they are not acceptable.
##
## The four that do not lay out -- `zone_07`, `zone_13`, `zone_18`,
## `zone_20` -- each wedge on an authored branch shell around 39 m deep
## and 50 m tall in a Zone 51 m tall with thirty to fifty rooms already
## standing. Raise this when the number goes up; do not lower it.
const SAMPLE_FLOOR := 16

## HOW FAR THE PLAYER JOURNEY GETS TODAY, leg by leg, as a ratchet.
##
## Not a waiver and not a pass: the legs are measured separately and
## these are the numbers the measurement returns, so a change to any of
## them shows up here. Raise them when they rise; do not lower them.
##
## **`content` MEANS SOMETHING ELSE NOW, and that is why it fell from
## two to zero.** It used to mean "the body reached the room's geometric
## middle", which is a fact about a coordinate. It now means "the
## PLAYER'S OWN interact probe found something with `interact()`" --
## the same condition the reference round trip uses, and the same one
## the game uses to offer a prompt. The old two were not two.
##
## **`returned` rose from zero to two** for the opposite reason: the
## walk is stopped by the return trigger reporting the body inside it
## rather than by a four-metre tolerance that left it outside.
##
## What the current numbers say, and none of it is repaired here:
##
## * three approaches never reach the branch. `zone_01` FALLS at
##   waypoint 0 even with the climb; `zone_04` and `zone_05` stop short.
## * the two that get in reach nothing: a target exists in each room,
##   and the return device sits between the body and it, so the content
##   leg ends by being sent home. The device firing on the way PAST is
##   not the §5.7 defect (it does not fire on entry) but it is not an
##   intentional return either, and it is recorded as "by wandering".
## * neither walked back in afterwards.
const JOURNEY_FLOOR := {"valid": 5, "at_mouth": 5, "entered": 2,
		"stayed": 2, "content": 0, "returned": 2, "re_entered": 0}
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
var journeys_stayed := 0
var journeys_content := 0
var journeys_at_mouth := 0
var journeys_re_entered := 0
## WHICH FIXTURES THIS RUN IS ABOUT. Hardcoding the generated directory
## here read five files and then failed to read fifteen -- and reported
## "20 of 20 lay out" on the strength of fifteen empty Dictionaries that
## `ZoneBuilder` cheerfully composed into nothing.
var _where := "res://tests/fixtures/generated"
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
	# THE DECLARED SAMPLE, or the preserved regression controls.
	#
	# `--sample` runs the wider declared sample instead: the first twenty
	# consecutive ordinary Zones of a real campaign at `DEFAULT_CONFIG`,
	# of which the five preserved inputs are exactly the prefix. It is
	# declared in `docs/AGENT_FRONTIER.md` and regenerated by
	# `make zone-sample`, not chosen after the results were seen, and
	# every one of its results is reported including the failures.
	#
	# It also writes each committed manifest out, because a router
	# returning LAYOUT_OK is not the same claim as a bridge accepting
	# what it produced. `tools/check_sample_layouts.py` takes it from
	# there through the real `layout.validate`.
	var sampling := OS.get_cmdline_user_args().has("--sample")
	_where = "res://tests/fixtures/sample" if sampling \
			else "res://tests/fixtures/generated"
	var where := _where
	var dir := DirAccess.open(where)
	if dir == null:
		_check(false, "%s is not there; run `make %s`"
				% [where, "zone-sample" if sampling else "zone-fixtures"])
		get_tree().quit(1)
		return
	if sampling:
		DirAccess.make_dir_recursive_absolute(where + "/layouts")
	var names: Array[String] = []
	for file: String in dir.get_files():
		if file.begins_with("zone_") and file.ends_with(".json"):
			names.append(file)
	names.sort()
	_check(names.size() >= (20 if sampling else 3),
			"%d generated Zone(s) to walk; one shape is not a sample"
			% names.size())
	# THE REFERENCE FIRST. A driver that cannot make one round trip
	# through the real controller has nothing to say about five Zones.
	if not OS.get_cmdline_user_args().has("--no-walk") and not sampling:
		await _a_reference_round_trip()
		await _the_reference_would_catch_its_own_defects()
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
	print("JOURNEYS   %d valid start(s), %d crossed the junction to the "
			% [journeys_valid, journeys_at_mouth]
			+ "door: %d entered a branch, %d stayed in it, %d crossed "
			% [journeys_entered, journeys_stayed, journeys_content]
			+ "to its content, %d got back out. %d inconclusive (the "
			% [journeys_returned, journeys_inconclusive]
			+ "harness could not start)")
	# EVERY LEG RATCHETED. A journey that used to reach the middle of a
	# side room and stops reaching it is a finding whatever the reason,
	# and it fails here rather than being read off the paragraph above.
	# Not asked when sampling, which walks nothing.
	if not OS.get_cmdline_user_args().has("--no-walk") and not sampling:
		var got := {"valid": journeys_valid, "at_mouth": journeys_at_mouth,
				"entered": journeys_entered, "stayed": journeys_stayed,
				"content": journeys_content,
				"returned": journeys_returned,
				"re_entered": journeys_re_entered}
		for leg: String in JOURNEY_FLOOR:
			_check(int(got[leg]) >= int(JOURNEY_FLOOR[leg]),
					"%d journey(s) reached '%s' and %d did before"
					% [int(got[leg]), leg, int(JOURNEY_FLOOR[leg])])
			if int(got[leg]) > int(JOURNEY_FLOOR[leg]):
				print("  journeys reaching '%s' ROSE to %d; raise "
						% [leg, int(got[leg])]
						+ "JOURNEY_FLOOR in graph_driver.gd")

	# A HARNESS THAT NEVER MANAGED A VALID START MEASURED NOTHING, and
	# saying so is the difference between "no defects found" and "no
	# search performed". Not asked in compose-only mode, where no
	# journey was attempted and zero valid starts is the expected count
	# rather than a finding.
	if not OS.get_cmdline_user_args().has("--no-walk") \
			and not sampling:
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
	# THE SAMPLE IS MEASURED AGAINST ITS RECORDED COVERAGE, the preserved
	# controls against a strict all-of-them. Two questions, two gates.
	if sampling:
		if playable < SAMPLE_FLOOR:
			print("GODOT GRAPH TESTS: SAMPLE COVERAGE FELL -- %d of %d "
					% [playable, names.size()] + "lay out, and %d did "
					% SAMPLE_FLOOR + "before (%s)" % str(unplayable))
			get_tree().quit(1)
			return
		if playable > SAMPLE_FLOOR:
			print("  coverage ROSE to %d of %d; raise SAMPLE_FLOOR in "
					% [playable, names.size()]
					+ "graph_driver.gd to hold the gain")
		if failures == 0:
			print("GODOT GRAPH TESTS OK")
			get_tree().quit(0)
		else:
			print("GODOT GRAPH TESTS: %d failures" % failures)
			get_tree().quit(1)
		return
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

## ONE ROUND TRIP, THROUGH THE PRODUCTION CONSUMER, BEFORE ANY SAMPLE.
##
## The five-Zone walk below was reporting a journey it was not making,
## and the flat steering was only the visible half. A source review found
## the rest, and every one of them is the harness measuring itself:
##
## * `ARRIVED` is four metres. A `ReturnPlug`'s trigger has a radius of
##   1.4, so a walk sent to the device stopped OUTSIDE it and the return
##   read as "could not get back". The runtime volume is not the thing
##   to widen.
## * `ReturnPlug` emits `traversed(edge_id, destination)` and moves
##   NOTHING. `ZoneController._on_plug_traversed` is what reads the
##   destination anchor and relocates the body -- so a driver that
##   instantiates the device and a `Player` and nothing else has no
##   consumer for the event at all, and could not tell a wired return
##   from an unwired one.
## * "reached its content" meant the room's geometric middle.
## * "re-entered" included putting the body at the arrival by hand.
##
## So this is the reference: a two-room Zone, a real `ZoneController`,
## the real return action, and every leg stopped by a condition the
## thing itself defines. **NO EDGES**, deliberately -- a Zone with no
## graph is `UNCERTIFIED` and is never held for a layout verdict, so
## this measures the return path and not the bridge.
func _a_reference_round_trip() -> void:
	print("\nREFERENCE  one round trip through ZoneController")
	var zone := {
		"zone_id": "zref", "theme": "concrete_facility",
		"chambers": [
			{"id": "r001", "type": "corridor", "length": 16.0,
					"width": 7.9, "enemies": [], "activities": [],
					"features": []},
			{"id": "r002", "type": "arena", "width": 18.0, "depth": 18.0,
					"wall_height": 6.0, "objective": "reach_exit",
					"enemies": [], "activities": [], "features": []},
		],
		"plugs": [{"edge_id": "p:r002:start", "room_id": "r002",
				"source_anchor": "room:r002:return",
				"destination": "zone_start", "device": "pad"}],
	}
	var controller := ZoneController.new()
	add_child(controller)
	controller.setup(zone)
	for _i in 8:
		await get_tree().physics_frame
	if controller.layout_failed != "":
		_check(false, "the reference Zone did not lay out: %s"
				% controller.layout_failed)
		controller.queue_free()
		return
	var body: Player = controller.player
	if not is_instance_valid(body):
		_check(false, "the reference Zone spawned no player")
		controller.queue_free()
		return
	_check(not body.input_frozen,
			"an edge-less Zone holds nobody: the reference walk starts "
			+ "free (holds %s)" % str(body.holds()))

	# THE DEVICE, AND A COUNTER ON ITS SIGNAL. The controller is already
	# connected -- that connection is the thing under test -- and this
	# second listener only counts, so a return that fires twice or fires
	# for the wrong edge is visible.
	var plug := _find_plug(controller)
	if plug == null:
		_check(false, "the reference Zone built no return device")
		controller.queue_free()
		return
	var fired: Array[String] = []
	plug.traversed.connect(func(edge: String, _to: String) -> void:
			fired.append(edge))
	var start: Vector3 = controller._zone_anchors.get("zone_start",
			Vector3.INF)
	var room: AABB = controller.room_bounds.get("r002", AABB())
	_check(room.has_volume() and start != Vector3.INF,
			"the reference Zone published its start anchor and its "
			+ "destination room's bounds")

	# 1. ENTER, on foot.
	var middle := room.position + room.size / 2.0
	await _walk(body, Vector3(middle.x, body.global_position.y, middle.z),
			room.grow(-1.0), WALK_FRAMES)
	var entered := room.grow(1.0).has_point(body.global_position)
	_check(entered, "the body walked into the destination room (at %v)"
			% body.global_position)
	if not entered:
		controller.queue_free()
		return

	# 2. REMAIN STANDING, and not be sent home on the way in.
	for _rest in 30:
		await get_tree().physics_frame
	_check(room.grow(1.0).has_point(body.global_position)
				and body.is_on_floor() and fired.is_empty(),
			"and stayed standing in it without the return firing (%d "
			% fired.size() + "traversal(s) so far)")

	# 3. REACH A REAL INTERACTION TARGET, stopped by the PLAYER'S OWN
	#    probe. `Player._update_interact_target` casts three metres from
	#    the camera and offers a prompt when it finds something with
	#    `interact()`; that is what "the player can reach it" means in
	#    this game, so that is the stopping condition.
	var target := _an_interactable_in(controller, room)
	if target == null:
		_check(false, "the destination room holds nothing interactable, "
				+ "so 'reached its content' would mean nothing")
	else:
		var prompted: Array[String] = []
		body.interact_prompt_changed.connect(
				func(text: String) -> void:
					if text != "":
						prompted.append(text))
		var at: Vector3 = (target as Node3D).global_position
		await _walk(body, Vector3(at.x, body.global_position.y, at.z),
				AABB(), WALK_FRAMES,
				func() -> bool: return not prompted.is_empty())
		_check(not prompted.is_empty(),
				"the player's own interact probe found %s: '%s'"
				% [(target as Node).name,
					prompted[0] if not prompted.is_empty() else ""])

	# 4. DELIBERATELY ENTER THE RETURN TRIGGER. Stopped by the trigger
	#    itself reporting the body inside it, not by a four-metre guess.
	var pad := plug.global_position
	await _walk(body, Vector3(pad.x, body.global_position.y, pad.z),
			AABB(), WALK_FRAMES,
			func() -> bool: return not fired.is_empty())

	# 5. ONE EVENT, FOR THE EXPECTED EDGE.
	_check(fired.size() == 1,
			"walking into the pad raised exactly one traversal, and it "
			+ "raised %d %s" % [fired.size(), str(fired)])
	_check(fired.has("p:r002:start"),
			"and it named the edge the composer assigned (%s)"
			% str(fired))

	# 6. AND THE PRODUCTION CONSUMER PUT THE BODY AT THAT EDGE'S
	#    DESTINATION. This is the half a driver without a controller
	#    cannot see: the device moves nobody.
	for _settle in 20:
		await get_tree().physics_frame
	var home := Vector2(body.global_position.x - start.x,
			body.global_position.z - start.z).length()
	_check(home < 3.0,
			"the return action put the body at 'zone_start' (%.1f m "
			% home + "away, at %v)" % body.global_position)

	# 7. AND BACK IN ON FOOT, not by relocation, and it stays.
	await _walk(body, Vector3(middle.x, body.global_position.y, middle.z),
			room.grow(-1.0), WALK_FRAMES)
	var again := room.grow(1.0).has_point(body.global_position)
	for _rest in 30:
		await get_tree().physics_frame
	_check(again and room.grow(1.0).has_point(body.global_position),
			"and walked back in and stayed: the return does not fire on "
			+ "entry (%d traversal(s) in total)" % fired.size())
	_check(fired.size() == 1,
			"re-entering raised no second traversal (%d in total)"
			% fired.size())
	controller.queue_free()
	await get_tree().process_frame

## TWO CONTROLS ON THE REFERENCE, because a measurement that cannot fail
## is not one. Both reproduce a defect the old driver had and show the
## new one detecting it.
func _the_reference_would_catch_its_own_defects() -> void:
	print("\nCONTROLS   the reference against its own two defects")
	var zone := {
		"zone_id": "zctl", "theme": "concrete_facility",
		"chambers": [
			{"id": "r001", "type": "corridor", "length": 16.0,
					"width": 7.9, "enemies": [], "activities": [],
					"features": []},
			{"id": "r002", "type": "arena", "width": 18.0, "depth": 18.0,
					"wall_height": 6.0, "objective": "reach_exit",
					"enemies": [], "activities": [], "features": []},
		],
		"plugs": [{"edge_id": "p:r002:start", "room_id": "r002",
				"source_anchor": "room:r002:return",
				"destination": "zone_start", "device": "pad"}],
	}

	# CONTROL 1: THE EVENT WITH NOBODY LISTENING. The old driver built
	# the device and a `Player` and no controller, so nothing consumed
	# `traversed` -- and a body that walked onto the pad simply stood on
	# it. If that reads as a completed return, the harness is measuring
	# the device and calling it the journey.
	var loose := ZoneController.new()
	add_child(loose)
	loose.setup(zone)
	for _i in 8:
		await get_tree().physics_frame
	var body: Player = loose.player
	var plug := _find_plug(loose)
	if plug == null or not is_instance_valid(body):
		_check(false, "the control Zone did not build a device and a "
				+ "player, so neither control can run")
		loose.queue_free()
		return
	# The one line that makes this the OLD harness: the production
	# consumer is taken off the signal.
	plug.traversed.disconnect(loose._on_plug_traversed)
	var fired: Array[String] = []
	plug.traversed.connect(func(edge: String, _to: String) -> void:
			fired.append(edge))
	var start: Vector3 = loose._zone_anchors.get("zone_start", Vector3.INF)
	var room: AABB = loose.room_bounds.get("r002", AABB())
	var middle := room.position + room.size / 2.0
	await _walk(body, Vector3(middle.x, body.global_position.y, middle.z),
			room.grow(-1.0), WALK_FRAMES)
	var pad := plug.global_position
	await _walk(body, Vector3(pad.x, body.global_position.y, pad.z),
			AABB(), WALK_FRAMES,
			func() -> bool: return not fired.is_empty())
	for _settle in 20:
		await get_tree().physics_frame
	var home := Vector2(body.global_position.x - start.x,
			body.global_position.z - start.z).length()
	_check(not fired.is_empty(),
			"the unwired control still RAISED the event -- the device "
			+ "works and only the consumer was removed")
	_check(home >= 3.0,
			"and with nothing consuming it the body did not go home "
			+ "(%.1f m from the start): a driver that asserts only the "
			% home + "event cannot tell a wired return from this")
	loose.queue_free()
	await get_tree().process_frame

	# CONTROL 2: STOPPING AT `ARRIVED`. Four metres is the tolerance the
	# old walk used everywhere, and a `ReturnPlug` trigger has a radius
	# of 1.4 -- so the body stops short of the device and nothing fires.
	var near := ZoneController.new()
	add_child(near)
	near.setup(zone)
	for _i in 8:
		await get_tree().physics_frame
	var walker: Player = near.player
	var device := _find_plug(near)
	if device == null or not is_instance_valid(walker):
		_check(false, "the second control Zone did not build")
		near.queue_free()
		return
	var late: Array[String] = []
	device.traversed.connect(func(edge: String, _to: String) -> void:
			late.append(edge))
	var box: AABB = near.room_bounds.get("r002", AABB())
	var centre := box.position + box.size / 2.0
	await _walk(walker, Vector3(centre.x, walker.global_position.y,
			centre.z), box.grow(-1.0), WALK_FRAMES)
	var spot := device.global_position
	# The OLD stopping rule: no `until`, so `_walk` stops at `ARRIVED`.
	await _walk(walker, Vector3(spot.x, walker.global_position.y, spot.z),
			AABB(), WALK_FRAMES)
	for _settle in 20:
		await get_tree().physics_frame
	var gap := Vector2(walker.global_position.x - spot.x,
			walker.global_position.z - spot.z).length()
	_check(gap > ReturnPlug.RADIUS,
			"stopping at ARRIVED leaves the body %.1f m from the pad, "
			% gap + "outside its %.1f m trigger" % ReturnPlug.RADIUS)
	_check(late.is_empty(),
			"and nothing fired: the four-metre tolerance is what made "
			+ "the old journey read 'could NOT get back' (%d event(s))"
			% late.size())
	near.queue_free()
	await get_tree().process_frame

## The first `ReturnPlug` this controller built, or null.
func _find_plug(node: Node) -> ReturnPlug:
	for child in node.get_children():
		if child is ReturnPlug:
			return child
		var deeper := _find_plug(child)
		if deeper != null:
			return deeper
	return null

## Something in this room a PLAYER can interact with -- the production
## test is `has_method("interact")`, which is what `Player`'s own probe
## asks. A pedestal, a station, the exit portal: whatever the room
## actually holds, rather than its geometric middle.
func _an_interactable_in(node: Node, room: AABB) -> Node3D:
	for child in node.get_children():
		if child is Node3D and (child as Node3D).is_inside_tree() \
				and child.has_method("interact") \
				and room.grow(1.0).has_point(
					(child as Node3D).global_position):
			return child
		var deeper := _an_interactable_in(child, room)
		if deeper != null:
			return deeper
	return null

func _walk_one(file: String) -> void:
	var text := FileAccess.get_file_as_string("%s/%s" % [_where, file])
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "%s/%s did not parse as a Zone; a run that cannot "
				% [_where, file] + "read its inputs has measured nothing")
		return
	var zone: Dictionary = parsed
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
	# THE MANIFEST GOES OUT FOR THE BRIDGE TO JUDGE. LAYOUT_OK is the
	# router's answer; whether the proposal it produced is acceptable is
	# the validator's, and only one of those two is measured in here.
	#
	# MEASURED FIRST, AND IN THE TREE. `apertures` and `arrival_ok` come
	# from probing real collision in a real world, which is why a
	# manifest written straight out of the router was refused twenty
	# times out of twenty for carrying no evidence -- a fact about the
	# harness and not about a single layout. The Zone stands, settles,
	# and is measured by the same `RoomAudit.measure_layout` a played
	# Zone uses.
	if OS.get_cmdline_user_args().has("--sample") and status == "LAYOUT_OK":
		add_child(out["root"] as Node3D)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var evidence := RoomAudit.measure_layout(out,
				get_viewport().world_3d.direct_space_state)
		out["apertures"] = evidence["apertures"]
		out["arrival_ok"] = evidence["arrival_ok"]
		out["plug_clear"] = evidence["plug_clear"]
		out["plug_placement"] = evidence["plug_placement"]
		var sink := FileAccess.open("%s/layouts/%s" % [_where, file],
				FileAccess.WRITE)
		if sink != null:
			sink.store_string(JSON.stringify(
					ZoneBuilder.layout_to_json(out), " "))
			sink.close()
		(out["root"] as Node3D).queue_free()
		await get_tree().process_frame
		return
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
	elif not OS.get_cmdline_user_args().has("--sample"):
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
	if OS.get_cmdline_user_args().has("--no-walk") \
			or OS.get_cmdline_user_args().has("--sample"):
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
	# THE JOURNEY RUNS ON A REAL CONTROLLER, like the reference above.
	#
	# The structural pass just made needs the raw build (its status, its
	# attempt count, its room list); the JOURNEY needs the production
	# return action, which lives in `ZoneController`. So the measured
	# build is let go and the Zone is stood up again the way the game
	# stands it up. Two builds per Zone, and the second one is the one a
	# player would be in.
	(out["root"] as Node3D).queue_free()
	await get_tree().process_frame
	var controller := ZoneController.new()
	add_child(controller)
	controller.setup(zone)
	for _i in 10:
		await get_tree().physics_frame
	if controller.layout_failed != "" or not is_instance_valid(
			controller.player):
		_check(false, "%s laid out once and not twice: %s"
				% [file, controller.layout_failed])
		controller.queue_free()
		return
	# THE ACCEPTANCE HOLD IS NOT THIS SUITE'S SUBJECT. These fixtures
	# carry edges, so `_await_verdict` holds the player until a bridge
	# answers -- and there is no bridge here. `godot-integration` is
	# where acceptance is measured; this driver measures the walk, so it
	# takes that one claim off and says so.
	if is_instance_valid(controller.player):
		controller.player.release(ZoneController.LAYOUT_HOLD)
	var reached := await _reach_a_branch(controller, out, zone, spine,
			side)
	controller.queue_free()
	await get_tree().process_frame
	print("    player: %s" % str(reached["how"]))
	if not bool(reached["valid"]):
		journeys_inconclusive += 1
		print("    player: INCONCLUSIVE -- the harness could not start, "
				+ "so this says nothing about the Zone")
	else:
		journeys_valid += 1
		if bool(reached["entered"]):
			journeys_entered += 1
		if bool(reached.get("stayed", false)):
			journeys_stayed += 1
		if bool(reached.get("content", false)):
			journeys_content += 1
		if bool(reached["returned"]):
			journeys_returned += 1
		# EACH LEG ASSERTED WHERE IT HAPPENS. A journey that broke in
		# the middle fails on the leg that broke, and the legs after it
		# are not asked -- reporting "did not get back" for a body that
		# never got in would name the wrong Zone finding.
		if bool(reached.get("at_mouth", false)):
			journeys_at_mouth += 1
		# THE RETURN DEVICE, USED ON PURPOSE AND EXACTLY ONCE. Only
		# asked of a journey that actually took one: a branch with no
		# plug returns through the junction and that is a whole
		# journey too.
		if bool(reached.get("used_pad", false)):
			_check(int(reached.get("traversals", 0)) == 1,
					"%s: the return device raised exactly one traversal "
					% file + "(%d)" % int(reached.get("traversals", 0)))
			if bool(reached.get("re_entered", false)):
				journeys_re_entered += 1
			# ASKED OF A DELIBERATE RETURN ONLY. A device the body
			# wandered onto while crossing the room was not chosen, and
			# whether the walk back in succeeds after an accidental
			# return says nothing about §5.7's property. The counter
			# above ratchets either way.
			if bool(reached.get("deliberate", false)):
				_check(bool(reached.get("re_entered", false)),
						"%s: and walking back into the side room did "
						% file + "not fire its return again (%s)"
						% str(reached["how"]))

## Walks the real Player from a junction into one of its side rooms and
## back out, and says what happened.
func _reach_a_branch(controller: ZoneController, out: Dictionary,
		zone: Dictionary, spine: Array, side: Array) -> Dictionary:
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
			return await _walk_into(controller, out, junction, served,
					mouth)
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

## THE WHOLE JOURNEY, AND EACH LEG NAMED SEPARATELY.
##
## Walking straight at the destination's centre is not the journey a
## player makes. A side room is reached through a DOORWAY and along a
## corridor the router solved, and a body steered at the room's middle
## walks into whichever wall is between it and there -- which is what
## three of the five Zones were reporting as "stopped N metres short"
## while the route they were meant to take stood open. The committed
## `links` chain is that route, waypoint by waypoint, so this follows it.
##
## Six answers, kept apart because they fail for different reasons:
## a valid START, ARRIVAL at the intended opening, ENTRY into the side
## destination, the ability to REMAIN there, reaching its CONTENT, and a
## successful intended RETURN. A body crossing a room boundary is one of
## those six and is reported as one of those six.
func _walk_into(controller: ZoneController, out: Dictionary,
		junction: String, branch: String, mouth: Vector3) -> Dictionary:
	var rooms: Dictionary = out["rooms"]
	var box: AABB = (rooms[branch] as Dictionary)["bounds"]
	var from: AABB = (rooms[junction] as Dictionary)["bounds"]
	var body: Player = controller.player
	# INSIDE THE JUNCTION, a quarter of the way toward its middle. The
	# doorway itself is a hole in a wall and the floor either side of it
	# is the room's, not the opening's: a body dropped ON the mouth falls
	# through the gap the connector bridges and the walk then reports how
	# far it got from the bottom of the world.
	#
	# THE CONTROLLER'S OWN PLAYER, moved to the start of the leg under
	# test. That is a harness setup and it is not a result: everything
	# after it is walked, and the re-entry at the end is walked too.
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
		return _no_start("the body fell out of '%s' before it took a "
				% junction + "step (ended at %v)"
				% body.global_position)
	if not from.grow(1.0).has_point(body.global_position):
		return _no_start("the body settled outside '%s', so it never "
				% junction + "stood in the junction (at %v)"
				% body.global_position)

	# 1. THROUGH THE JUNCTION INTERIOR TO THE INTENDED OPENING.
	var reached_mouth := await _leg(body, mouth, LEG_FRAMES * 2)
	var at_mouth := bool(reached_mouth["arrived"])
	var crossed := stand.distance_to(body.global_position)

	# 2. ALONG THE COMMITTED CORRIDOR, AT ITS OWN HEIGHTS.
	#
	# `links[branch]` is the chain the router solved, and each piece
	# records where it is entered and left -- INCLUDING its `y`. The
	# first version of this projected every waypoint onto the body's
	# current height, which is how three of five approaches walked off a
	# ledge: a route that climbs was steered as though it were flat, and
	# the fall then read as "stopped N metres short".
	var route := _corridor(out, branch)
	var fell_at := -1
	for i in route.size():
		var step: Vector3 = route[i]
		if box.grow(1.0).has_point(body.global_position):
			break
		var leg := await _leg(body, step, LEG_FRAMES)
		if bool(leg["fell"]):
			fell_at = i
			break

	# 3. ENTRY.
	var entered := box.grow(2.0).has_point(body.global_position)
	if not entered:
		var stopped := body.global_position
		var gap := Vector2(box.position.x + box.size.x / 2.0 - stopped.x,
				box.position.z + box.size.z / 2.0 - stopped.z).length()
		return {"valid": true, "at_mouth": at_mouth, "entered": false,
				"stayed": false, "content": false, "returned": false,
				"how": "%s -> %s: crossed %.1f m of junction%s, then "
					% [junction, branch, crossed,
						"" if at_mouth else " but never reached the door"]
					+ "%s %.1f m short of the room at %v"
					% ["FELL off the route at waypoint %d," % fell_at
						if fell_at >= 0 else "stopped", gap, stopped]}

	# 4. CAN IT REMAIN THERE? A body that enters and is immediately
	#    somewhere else has not arrived, and the two ways that happens
	#    are opposite failures: falling through the floor, and a return
	#    that fires on entry and sends the player home.
	var start := _anchor_of(out, "zone_start")
	for _rest in 30:
		await get_tree().physics_frame
	var sent_home := start != Vector3.INF and Vector2(
			body.global_position.x - start.x,
			body.global_position.z - start.z).length() < 6.0
	var stayed := box.grow(2.0).has_point(body.global_position) \
			and body.is_on_floor() and not sent_home
	if not stayed:
		return {"valid": true, "at_mouth": at_mouth, "entered": true,
				"stayed": false, "content": false, "returned": false,
				"how": "%s -> %s entered, then %s (at %v)"
					% [junction, branch,
						"the return fired on entry and sent it home"
						if sent_home else "could not stay standing in it",
						body.global_position]}

	# THE DEVICE IS WATCHED FROM HERE, before the content leg, so a pad
	# the body WANDERS onto on its way round the room is distinguishable
	# from one it is sent to. "Using it intentional" is the §5.7
	# property; firing on the way past is not firing on entry, and it is
	# not a deliberate return either.
	var plug := _plug_of(controller, branch)
	var fired: Array[String] = []
	var deliberate := false
	if plug != null:
		plug.traversed.connect(func(edge: String, _to: String) -> void:
				fired.append(edge))

	# 5. AND REACH SOMETHING IN THERE THE PLAYER CAN ACTUALLY USE,
	#    stopped by the player's OWN interact probe -- the same
	#    condition the reference round trip uses. The room's geometric
	#    middle is not content.
	var target := _an_interactable_in(controller, box)
	var content := false
	var holds_nothing := target == null
	if target != null:
		var prompted: Array[String] = []
		var listener := func(text: String) -> void:
				if text != "":
					prompted.append(text)
		body.interact_prompt_changed.connect(listener)
		await _leg(body, (target as Node3D).global_position,
				LEG_FRAMES * 2,
				func() -> bool: return not prompted.is_empty())
		body.interact_prompt_changed.disconnect(listener)
		content = not prompted.is_empty()

	# 6. AND BACK, BY THE ROUTE THE ZONE OFFERS. The return DEVICE if the
	#    room has one -- deliberately, after the content, stopped by the
	#    trigger itself -- and otherwise the corridor in reverse.
	if plug != null and fired.is_empty():
		deliberate = true
		await _leg(body, plug.global_position, LEG_FRAMES * 2,
				func() -> bool: return not fired.is_empty())
		for _settle in 20:
			await get_tree().physics_frame
		deliberate = not fired.is_empty()
	if fired.is_empty():
		var home := route.duplicate()
		home.reverse()
		home.append(mouth)
		for step: Vector3 in home:
			if from.grow(1.0).has_point(body.global_position):
				break
			await _leg(body, step, LEG_FRAMES)
	var by_pad := start != Vector3.INF and Vector2(
			body.global_position.x - start.x,
			body.global_position.z - start.z).length() < 6.0
	var returned := from.grow(2.0).has_point(body.global_position) or by_pad
	var ended := body.global_position

	# 7. AND BACK IN ON FOOT. The defect §5.7 repaired was a return that
	#    fired on entry, so the proof it is gone is a SECOND entry that
	#    sticks -- WALKED, because relocating the body to the arrival
	#    proves the arrival is standable and nothing about the route.
	var re_entered := false
	# ASKED OF A DELIBERATE RETURN. After an accidental one the walk
	# back in is not measuring §5.7's property, and the legs are not
	# free: this suite has to stay a bounded run.
	if returned and (deliberate or plug == null):
		for step: Vector3 in route:
			if box.grow(1.0).has_point(body.global_position):
				break
			await _leg(body, step, LEG_FRAMES)
		for _rest in 30:
			await get_tree().physics_frame
		re_entered = box.grow(2.0).has_point(body.global_position)
	return {"valid": true, "at_mouth": at_mouth, "entered": true,
			"stayed": true, "content": content, "returned": returned,
			"used_pad": not fired.is_empty(), "re_entered": re_entered,
			"traversals": fired.size(), "holds_nothing": holds_nothing,
			"deliberate": deliberate,
			"how": "%s -> %s: crossed %.1f m of junction, %s, entered, "
				% [junction, branch, crossed,
					"through the door" if at_mouth
					else "reached the corridor"]
				+ "stayed, %s, and %s%s"
				% ["reached what it holds" if content
					else ("holds nothing a player can use" if holds_nothing
					else "could NOT reach anything it holds"),
					("took the return device home %s(%d event(s))"
					% ["deliberately " if deliberate else "by wandering "
						+ "onto it, ", fired.size()]
					if not fired.is_empty()
					else ("was taken home by a device it did not choose"
					if by_pad else "walked back into the junction"))
					if returned
					else "could NOT get back (ended at %v)" % ended,
					"" if not returned else
					("; walked back in and stayed" if re_entered
					else "; could not walk back in")]}

## ONE LEG, AT THE WAYPOINT'S OWN HEIGHT.
##
## `_walk` steers in XZ, which is what steering is; what this adds is the
## route's `y`. A leg is finished when the body is within `ARRIVED`
## horizontally AND within a storey vertically, and it has FALLEN when
## the body ends a storey and a half below where the waypoint said the
## floor was. Reported rather than walked past: a body at the bottom of
## a pit that keeps being steered at the next waypoint is what produced
## "stopped 131.6 m short".
func _leg(body: Player, to: Vector3, frames: int,
		until := Callable()) -> Dictionary:
	var was := body.global_position
	var out := await _walk(body, to, AABB(), frames,
			until if until.is_valid()
			else (func() -> bool:
					var here := body.global_position
					return Vector2(to.x - here.x,
							to.z - here.z).length() <= ARRIVED \
							and absf(here.y - to.y) <= ARRIVED))
	var dropped := was.y - body.global_position.y
	return {"arrived": bool(out["arrived"]), "closest": out["closest"],
			"fell": body.global_position.y < to.y - ARRIVED * 1.5
					and dropped > ARRIVED}

## The return device this room holds, from the controller's own scene.
func _plug_of(node: Node, room: String) -> ReturnPlug:
	for child in node.get_children():
		if child is ReturnPlug \
				and str((child as ReturnPlug).get_meta("room_id", "")) \
					== room:
			return child
		var deeper := _plug_of(child, room)
		if deeper != null:
			return deeper
	return null

## The committed corridor to `room`, as waypoints. Each piece of the
## chain the router solved records where it is entered and where it is
## left; the exits in order are the route a body walks.
func _corridor(out: Dictionary, room: String) -> Array[Vector3]:
	var steps: Array[Vector3] = []
	for raw: Variant in (out.get("links", {}) as Dictionary).get(room, []):
		var piece: Dictionary = raw
		if piece.has("exit"):
			steps.append(piece["exit"])
	var arrival: Variant = (out["rooms"] as Dictionary).get(
			room, {}).get("arrival")
	if arrival != null:
		steps.append(arrival)
	return steps

## The Zone start, from the committed anchors, or `Vector3.INF`.
func _anchor_of(out: Dictionary, name: String) -> Vector3:
	var anchors: Dictionary = out.get("anchors", {})
	if not anchors.has(name):
		return Vector3.INF
	return anchors[name]

## The same steer-and-press the room contract uses, kept short here: this
## driver's subject is the graph, not the controller.
func _walk(body: Player, goal: Vector3, stop_inside: AABB,
		frames := WALK_FRAMES, until := Callable()) -> Dictionary:
	var closest := INF
	var still := 0
	var last := body.global_position
	var met := false
	Input.action_press("move_forward", 1.0)
	for i in frames:
		var here := body.global_position
		if stop_inside.has_volume() and stop_inside.has_point(here):
			break
		# THE CONDITION THE THING ITSELF DEFINES.
		#
		# `ARRIVED` is four metres, which is a tolerance for "near the
		# middle of a room" and nothing else: a `ReturnPlug` trigger has
		# a radius of 1.4, so a walk that stopped at `ARRIVED` stopped
		# OUTSIDE the device it was sent to and the journey then read as
		# "could not get back". The runtime volume is not the thing to
		# widen. A leg with a real stopping condition passes its own.
		if until.is_valid() and until.call():
			met = true
			break
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		closest = minf(closest, flat.length())
		if until.is_valid():
			body.rotation.y = atan2(-flat.x, -flat.y)
			# A ROUTE THAT CLIMBS IS CLIMBED. `MAX_VERTICAL_STEP` is a
			# metre, so anything above that is a jump the player has to
			# make -- and waiting to be STUCK first is how a body ends a
			# leg at the bottom of the rise it was meant to go up.
			# Pressed while moving, on the ground, at the rate a player
			# can actually repeat it.
			if goal.y - here.y > Constants.MAX_VERTICAL_STEP \
					and body.is_on_floor() and i % 24 == 0:
				Input.action_press("jump", 1.0)
				await get_tree().physics_frame
				Input.action_release("jump")
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
			continue
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
	if until.is_valid():
		return {"arrived": met, "closest": closest}
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
