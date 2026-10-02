extends Node
## H-GRAPHS: DESIGN 3 §14's FIVE SIGNAL VERBS, ON THE GRAPHS REAL ROOMS RUN.
##
## Runtime-only (N-15): no Echo primitive delivers a verb yet, so each
## case calls `SignalGraph.apply_verb` where a delivered verb would. Every
## graph below is one the game builds for real:
## - the HELD ROUTE (D-07): `held_route_zone.json`, a plate driving a
##   shutter, built through the real `ZoneController`;
## - the LATCHED ROUTE: `latched_route_zone.json`, plate -> LATCH ->
##   shutter, the same way;
## - EX50-033, the Unweighted Switch, with its real crate on its drive:
##   plate -> NOT, bolt lever -> LATCH, OR -> shutter;
## - EX50-021, the Counterfire Arcade: receiver -> TIMER (8 s), release
##   lever -> LATCH, OR -> shutter.
##
## What is held to account (the packet's H-GRAPHS evidence): the input and
## the consequence on a real shutter; the override's expiry; that nothing
## a verb does persists -- no latch set, nothing left on a rebuilt room --
## and each refusal, with nothing changed.
##
## **TIME IS STEPPED BY HAND.** Each graph's own clock is paused
## (`set_physics_process(false)`) and `advance` is called, so "it expires
## after its seconds" is a number, not a wait. The shutters still move on
## real physics frames.

const HELD_FIXTURE := "res://tests/fixtures/held_route_zone.json"
const LATCHED_FIXTURE := "res://tests/fixtures/latched_route_zone.json"
const HELD_PLATE := "weight_plate"
const HELD_SHUTTER := "route_shutter"
## How long a verb lasts in these cases.
const LASTS := 3.0

var failures := 0
var checks := 0
var notes: Array[String] = []


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)


func _note(message: String) -> void:
	notes.append(message)
	print("  note: " + message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	await _the_held_route()
	await _the_latched_route()
	await _the_unweighted_switch()
	await _the_counterfire_arcade()
	if failures == 0:
		print("GODOT SIGNAL VERBS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT SIGNAL VERBS FAILED (%d of %d)" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## One verb, through the runtime. A runtime with no verbs answers as a
## refusal, so the reproduction on the old code fails each check by name
## rather than with a script error.
func _verb(graph: SignalGraph, verb: String, target: String,
		seconds := LASTS, to := "") -> Dictionary:
	if graph == null or not graph.has_method("apply_verb"):
		return {"ok": false, "reason": "the runtime has no signal verbs"}
	return graph.call("apply_verb", verb, target, seconds, to)


func _standing(graph: SignalGraph) -> int:
	if graph == null or not "overrides" in graph:
		return 0
	return (graph.get("overrides") as Dictionary).size() \
			+ (graph.get("bridges") as Array).size()


func _verified(graph: SignalGraph, id: String) -> Variant:
	if graph == null or not "verified" in graph:
		return null
	return (graph.get("verified") as Dictionary).get(id)


func _until(predicate: Callable, frames := 420) -> bool:
	for _i in frames:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return predicate.call()


func _zone(path: String) -> ZoneController:
	var data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(path))
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	controller.add_child(pool)
	controller.setup(data)
	if controller.player != null:
		controller.player.stat_stack.pool = pool
	for _i in 10:
		await get_tree().physics_frame
	return controller


func _drop(node: Node) -> void:
	node.queue_free()
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame


func _first_graph(controller: ZoneController) -> SignalGraph:
	for raw: Variant in controller.signal_graphs:
		return raw as SignalGraph
	return null


func _actuator(graph: SignalGraph, id: String) -> Variant:
	var binding: Variant = graph.actuators.get(id)
	return (binding as Dictionary).get("node") \
			if typeof(binding) == TYPE_DICTIONARY else binding


func _fired_counter(graph: SignalGraph) -> Array:
	var seen: Array = []
	graph.fired.connect(func(_package: String, node: String) -> void:
			seen.append(node))
	return seen


# ---------------------------------------------------------------------------
# The held route (D-07): plate -> shutter
# ---------------------------------------------------------------------------

func _the_held_route() -> void:
	print("  -- THE HELD ROUTE (D-07): a plate driving a shutter")
	var controller := await _zone(HELD_FIXTURE)
	var graph := _first_graph(controller)
	if graph == null:
		_check(false, "the held route builds its graph")
		await _drop(controller)
		return
	graph.set_physics_process(false)
	var shutter: Variant = _actuator(graph, HELD_SHUTTER)
	_check(shutter != null and await _until(func() -> bool:
			return shutter.is_shut()),
			"with nothing on the plate the shutter is shut")

	var held := _verb(graph, "HOLD_SIGNAL", HELD_PLATE)
	_check(bool(held["ok"]) and await _until(func() -> bool:
			return shutter.is_open()),
			"HOLD_SIGNAL on the empty plate opens the shutter (%s)"
			% held.get("reason", "applied"))
	_check(_verified(graph, HELD_PLATE) == false,
			"and the plate itself still reads empty: its verified value "
			+ "is OFF (%s)" % str(_verified(graph, HELD_PLATE)))

	var was := _standing(graph)
	graph.advance(LASTS + 0.1)
	_check(was == 1 and _standing(graph) == 0 and await _until(
			func() -> bool: return shutter.is_shut()),
			"after its %.1fs the verb expires and the shutter shuts again "
			% LASTS + "(standing %d, then %d)" % [was, _standing(graph)])

	var inverted := _verb(graph, "INVERT", HELD_SHUTTER)
	_check(bool(inverted["ok"]) and await _until(func() -> bool:
			return shutter.is_open()),
			"INVERT on the shutter's own input opens it too (%s)"
			% inverted.get("reason", "applied"))
	was = _standing(graph)
	graph.advance(LASTS + 0.1)
	_check(was == 1 and await _until(func() -> bool:
			return shutter.is_shut()),
			"and it shuts when that expires (standing %d before)" % was)
	await _drop(controller)


# ---------------------------------------------------------------------------
# The latched route: plate -> LATCH -> shutter
# ---------------------------------------------------------------------------

func _the_latched_route() -> void:
	print("  -- THE LATCHED ROUTE: plate -> LATCH -> shutter")
	var controller := await _zone(LATCHED_FIXTURE)
	var graph := _first_graph(controller)
	if graph == null:
		_check(false, "the latched route builds its graph")
		await _drop(controller)
		return
	graph.set_physics_process(false)
	var fired := _fired_counter(graph)
	var latch_id := ""
	var plate_id := ""
	for raw: Variant in graph.nodes:
		if str((raw as Dictionary).get("kind", "")) == "LATCH":
			latch_id = str((raw as Dictionary)["id"])
			plate_id = str(((raw as Dictionary)["inputs"] as Array)[0])
	var shutter_id := str(graph.actuators.keys()[0])
	var shutter: Variant = _actuator(graph, shutter_id)

	var held := _verb(graph, "HOLD_SIGNAL", plate_id)
	for _i in 30:
		await get_tree().physics_frame
	_check(bool(held["ok"]) and graph.latched.is_empty() and fired.is_empty()
			and shutter.is_shut(),
			"HOLD_SIGNAL on the plate never sets the recorded LATCH (N-15): "
			+ "latched %s, announced %s, shutter shut %s"
			% [graph.latched.keys(), fired, shutter.is_shut()])
	graph.advance(LASTS + 0.1)

	var door := _verb(graph, "HOLD_SIGNAL", shutter_id)
	_check(bool(door["ok"]) and await _until(func() -> bool:
			return shutter.is_open()),
			"HOLD_SIGNAL on the shutter's input holds the way open (%s)"
			% door.get("reason", "applied"))
	var was := _standing(graph)
	graph.advance(LASTS + 0.1)
	_check(was == 1 and await _until(func() -> bool:
			return shutter.is_shut())
			and graph.latched.is_empty() and fired.is_empty(),
			"and when it expires the way shuts, with nothing recorded "
			+ "(latched %s, announced %s)" % [graph.latched.keys(), fired])

	for verb: String in ["HOLD_SIGNAL", "INVERT"]:
		var refused := _verb(graph, verb, latch_id)
		_check(not bool(refused["ok"])
				and str(refused.get("reason", "")).contains("§14.3")
				and _standing(graph) == 0,
				"a LATCH cannot take %s (§14.3), and nothing changed: %s"
				% [verb, refused.get("reason", "")])

	# NOTHING A VERB DID OUTLIVES THE ROOM. Rebuilt from the same Zone,
	# as a reload rebuilds it.
	_verb(graph, "CUT", shutter_id, 60.0)
	await _drop(controller)
	var again := await _zone(LATCHED_FIXTURE)
	var rebuilt := _first_graph(again)
	_check(rebuilt != null and _standing(rebuilt) == 0
			and rebuilt.latched.is_empty(),
			"a rebuilt room carries no verb and no latch it did not earn "
			+ "(standing %d)" % _standing(rebuilt))
	await _drop(again)


# ---------------------------------------------------------------------------
# EX50-033, the Unweighted Switch: plate -> NOT; bolt -> LATCH; OR
# ---------------------------------------------------------------------------

func _drive_to(scene: UnweightedSwitch, recess: bool) -> void:
	var want := UnweightedSwitch.RECESS_Z if recess \
			else UnweightedSwitch.PARK_Z
	if not is_equal_approx(scene.drive_goal_z(), want):
		scene.drive.pulled.emit(scene.drive)
	for _i in 600:
		await get_tree().physics_frame
		if scene.crate.freeze \
				and is_equal_approx(scene.crate.global_position.z, want):
			return


func _the_unweighted_switch() -> void:
	print("  -- EX50-033: plate -> NOT, bolt -> LATCH, OR -> shutter")
	var scene := UnweightedSwitch.new()
	add_child(scene)
	for _i in 20:
		await get_tree().physics_frame
	var room := scene.room
	var graph := room.graph
	graph.set_physics_process(false)
	var shutter := room.shutter
	var fired := _fired_counter(graph)

	_check(await _until(func() -> bool: return shutter.is_open()),
			"with the crate parked, the plate is unloaded and the shutter "
			+ "open")
	var inverted := _verb(graph, "INVERT", "unloaded")
	_check(bool(inverted["ok"]) and await _until(func() -> bool:
			return shutter.is_shut()),
			"INVERT on the NOT turns it over: the shutter shuts (%s)"
			% inverted.get("reason", "applied"))
	var was := _standing(graph)
	graph.advance(LASTS + 0.1)
	_check(was == 1 and await _until(func() -> bool:
			return shutter.is_open()),
			"and opens again when the verb expires (standing %d before)"
			% was)

	await _drive_to(scene, true)
	_check(await _until(func() -> bool: return shutter.is_shut()),
			"the crate on the plate holds the shutter shut")
	var bridged := _verb(graph, "BRIDGE", "plate", LASTS, "open")
	_check(bool(bridged["ok"]) and await _until(func() -> bool:
			return shutter.is_open()),
			"BRIDGE from the plate into the OR: the crate that holds the "
			+ "shutter shut now holds it open (%s)"
			% bridged.get("reason", "applied"))
	was = _standing(graph)
	graph.advance(LASTS + 0.1)
	_check(was == 1 and _standing(graph) == 0 and await _until(
			func() -> bool: return shutter.is_shut()),
			"and the bridge comes down when it expires: shut again "
			+ "(standing %d before)" % was)

	var cycle := _verb(graph, "BRIDGE", "open", LASTS, "unloaded")
	_check(not bool(cycle["ok"])
			and str(cycle.get("reason", "")).contains("cycle")
			and _standing(graph) == 0 and shutter.is_shut(),
			"a BRIDGE from the OR back into the NOT would close a cycle, "
			+ "and is refused with nothing changed (§19.7): %s"
			% cycle.get("reason", ""))
	var into_latch := _verb(graph, "BRIDGE", "plate", LASTS, "bolt")
	var from_door := _verb(graph, "BRIDGE", "shutter", LASTS, "open")
	_check(str(into_latch.get("reason", "")).contains("destination (§14.3)")
			and str(from_door.get("reason", "")).contains("source (§14.3)")
			and _standing(graph) == 0,
			"a LATCH is no BRIDGE's destination, nor a shutter's input its "
			+ "source (§14.3): %s / %s"
			% [into_latch.get("reason", ""), from_door.get("reason", "")])

	var held := _verb(graph, "HOLD_SIGNAL", "bolt_lever")
	for _i in 30:
		await get_tree().physics_frame
	_check(bool(held["ok"]) and not room.bolted
			and not graph.latched.has("bolt") and fired.is_empty()
			and shutter.is_shut(),
			"HOLD_SIGNAL on the bolt lever never throws the bolt (N-15): "
			+ "bolted %s, announced %s" % [room.bolted, fired])
	graph.advance(LASTS + 0.1)

	# The control: the lever itself still throws it, once.
	room.bolt.pulled.emit(room.bolt)
	_check(await _until(func() -> bool: return shutter.is_open())
			and graph.latched.has("bolt") and fired == ["bolt"],
			"the real lever still throws the bolt, once (%s)" % [fired])
	var cut := _verb(graph, "CUT", "bolt")
	_check(bool(cut["ok"]) and await _until(func() -> bool:
			return shutter.is_shut()),
			"CUT on the thrown bolt reports it OFF: the shutter shuts (%s)"
			% cut.get("reason", "applied"))
	_check(graph.latched.has("bolt") and fired == ["bolt"]
			and _verified(graph, "bolt") == true,
			"and the record is untouched: still thrown, announced once, "
			+ "verified ON")
	was = _standing(graph)
	graph.advance(LASTS + 0.1)
	_check(was == 1 and await _until(func() -> bool:
			return shutter.is_open()),
			"when the CUT expires the thrown bolt holds the way open again "
			+ "(standing %d before)" % was)
	scene.queue_free()
	for _i in 4:
		await get_tree().physics_frame


# ---------------------------------------------------------------------------
# EX50-021, the Counterfire Arcade: receiver -> TIMER; release -> LATCH
# ---------------------------------------------------------------------------

func _the_counterfire_arcade() -> void:
	print("  -- EX50-021: receiver -> TIMER (8 s), release -> LATCH, OR")
	var room := CounterfireArcadeRoom.new()
	room.with_gunner = false
	room.development_signs = false
	room.build()
	add_child(room)
	for _i in 20:
		await get_tree().physics_frame
	var graph := room.graph
	graph.set_physics_process(false)
	var shutter := room.shutter
	_check(await _until(func() -> bool: return shutter.is_shut()),
			"at rest, no window and no release: the shutter is shut")

	var refused := _verb(graph, "INVERT", "window")
	_check(not bool(refused["ok"])
			and str(refused.get("reason", "")).contains("§14.3")
			and _standing(graph) == 0,
			"a TIMER cannot take INVERT (§14.3): %s"
			% refused.get("reason", ""))

	var held := _verb(graph, "HOLD_SIGNAL", "window", 12.0)
	_check(bool(held["ok"]) and await _until(func() -> bool:
			return shutter.is_open()),
			"HOLD_SIGNAL on the TIMER opens the window (%s)"
			% held.get("reason", "applied"))
	graph.advance(9.0)
	for _i in 10:
		await get_tree().physics_frame
	_check(shutter.is_open() and _standing(graph) == 1,
			"and holds it past the TIMER's own eight seconds")
	var was := _standing(graph)
	graph.advance(3.1)
	_check(was == 1 and _standing(graph) == 0 and await _until(
			func() -> bool: return shutter.is_shut()),
			"then the hold expires and the window shuts (standing %d "
			% was + "before)")

	var probed := _verb(graph, "PROBE", "release")
	var seen: Dictionary = probed.get("probe", {})
	_check(bool(probed["ok"]) and str(seen.get("kind", "")) == "LATCH"
			and str(seen.get("predicate", "")) == "LATCH, not set"
			and (seen.get("inputs", []) as Array).size() == 1
			and str((seen["inputs"] as Array)[0].get("id", ""))
				== "release_lever"
			and _standing(graph) == 0 and shutter.is_shut(),
			"PROBE reveals the release LATCH -- its value, its input, its "
			+ "predicate -- and changes nothing (%s)" % str(seen))

	var odd := [_verb(graph, "SHOUT", "window"),
			_verb(graph, "CUT", "window", 0.0),
			_verb(graph, "CUT", "no_such_node")]
	var said: Array = odd.map(func(r: Dictionary) -> String:
			return str(r.get("reason", "")))
	_check(not bool(odd[0]["ok"]) and said[0].contains("not a signal verb")
			and not bool(odd[1]["ok"])
			and said[1].contains("positive number of seconds")
			and not bool(odd[2]["ok"]) and said[2].contains("not part of")
			and _standing(graph) == 0,
			"an unknown verb, a duration of 0 and a node that is not there "
			+ "are refused: %s" % str(odd.map(func(r: Dictionary) -> String:
				return str(r.get("reason", "")))))
	room.queue_free()
	for _i in 4:
		await get_tree().physics_frame
