extends Node
## P14 — A ZONE ASKS FOR A SIGNAL CHAIN, AND GETS ONE (`--signal-graph`).
##
## `unweighted_switch.gd` has run this chain since EX50-033: a HEAVY
## class plate, a NOT, and a shutter. What it could not do was let a
## GENERATED Zone ask for it — the wiring was in the scenario, so the
## chain existed exactly once, in a room someone wrote by hand.
##
## So this builds Zones that DECLARE the chain and plays what comes out.
## `RoomGraphs` reads `Zone.room_graphs`, puts the plate and the shutter
## in the named room off the committed layout, and evaluates the graph
## in declaration order on every sensor change.
##
## **THE VOCABULARY IS REFUSED, NOT SILENTLY DROPPED.** §19.2 names
## eleven node types and §20 names eighteen sensors; one of each is
## implemented. A Zone that asks for `AND` or a `LEVER` must be told
## that the runtime does not have it, and told differently from a Zone
## that asks for `NAND` — which is not a thing. Both cases are here, and
## so is the one that matters more: nothing is half-built.
##
## **THE CLASS DISTINCTION IS THE POINT, and it is checked through the
## declared chain rather than beside it.** A `lightened` crate releases
## a `PRESSURE_PLATE` while weighing exactly what it weighed, because
## the plate reads a semantic class. EX50-033 §10 calls that the room's
## decisive negative control; here it is the declaration's.

var failures := 0
var notes: Array[String] = []


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)


func _note(message: String) -> void:
	notes.append(message)
	print("  NOTE: " + message)


func _ready() -> void:
	_run()


func _finish() -> void:
	if failures == 0:
		print("GODOT SIGNAL GRAPH TESTS OK (%d checks, %d notes)"
				% [_checks, notes.size()])
	else:
		print("GODOT SIGNAL GRAPH TESTS: %d failures in %d checks"
				% [failures, _checks])
	get_tree().quit(0 if failures == 0 else 1)


var _checks := 0


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

## THE ONE CHAIN, DECLARED: a HEAVY plate, a NOT, a commanded shutter.
func _chain(node_kind := "NOT", sensor_kind := "PRESSURE_PLATE",
		operation := "command", room := "c001") -> Dictionary:
	return {
		"room_id": room,
		"sensors": [{"node_id": "plate", "kind": sensor_kind,
				"requires_class": "HEAVY"}],
		"nodes": [{"node_id": "inverted", "kind": node_kind,
				"inputs": ["plate"]}],
		"actuators": [{"actuator_id": "shutter",
				"driven_by": "inverted", "operation": operation}],
	}


func _zone(graphs: Array) -> Dictionary:
	return {
		"schema_version": 7, "zone_id": "zone_signal", "seed": 14,
		"theme": "concrete_facility",
		"chambers": [{
			"id": "c001", "type": "arena", "theme": "concrete_facility",
			"width": 26.0, "depth": 24.0, "wall_height": 6.0,
			"objective": "reach_reward", "reward_location_id": 89100002,
			"activities": [], "features": [], "enemies": [],
			"rewards": [], "interactables": [],
		}],
		"room_graphs": graphs,
	}


func _built(zone: Dictionary) -> ZoneController:
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	controller.add_child(pool)
	controller.setup(zone)
	if controller.player != null:
		controller.player.stat_stack.pool = pool
	if not controller.layout_failed.is_empty():
		_check(false, "the declared Zone did not lay out: %s"
				% controller.layout_failed)
	for _i in 10:
		await get_tree().physics_frame
	return controller


func _drop(controller: ZoneController) -> void:
	controller.queue_free()
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame


func _graph(controller: ZoneController) -> SignalGraph:
	for raw: Variant in controller.signal_graphs:
		return raw as SignalGraph
	return null


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _run() -> void:
	# **ONE FRAME BEFORE ANYTHING IS ADDED.** `_ready` runs while the
	# root is still setting up its own children, and `add_child` on a
	# parent in that state FAILS -- the node is left unparented, with no
	# name, out of the tree, and every `get_tree()` inside it returns
	# null. The symptom is nothing like the cause: the Zone builds, the
	# graph evaluates, and the shutter simply never moves because its
	# `_physics_process` is not running. `integration_driver` waits a
	# frame here for the same reason.
	await get_tree().process_frame
	await _a_declared_chain_is_built_and_starts_settled()
	await _a_heavy_occupant_closes_it_and_leaving_opens_it()
	await _the_player_is_not_an_occupant()
	await _lightened_releases_the_plate_without_losing_a_kilogram()
	await _a_node_the_runtime_lacks_is_refused_and_nothing_is_built()
	await _a_kind_the_design_does_not_name_is_refused_differently()
	await _a_graph_in_a_room_that_is_not_there_is_refused()
	await _a_latch_holds_its_value_and_is_restored()
	await _a_latch_chain_is_declarable_and_builds()
	await _a_class_is_not_a_sum_and_one_off_is_not_both()
	await _a_graph_that_is_gone_hears_nothing()
	_finish()


## A HEAVY crate, dropped where the plate is and left to settle.
func _crate(controller: ZoneController, plate: ClassPlate,
		kilograms := 200.0) -> ManipulableBody:
	var body := ManipulableBody.create("crate", kilograms,
			Vector3(1.4, 1.0, 1.4))
	controller.add_child(body)
	body.global_position = plate.global_position + Vector3(0.0, 1.2, 0.0)
	for _i in 60:
		await get_tree().physics_frame
	return body


## Wait for a predicate, up to a budget of physics frames.
func _until(predicate: Callable, frames := 420) -> bool:
	for _i in frames:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return false


## THE CHAIN EXISTS BECAUSE THE ZONE ASKED FOR IT, and it starts in the
## state the graph says rather than the state the shutter was built in.
## An empty plate is not satisfied, `NOT` of that is true, and true
## commands the shutter open.
func _a_declared_chain_is_built_and_starts_settled() -> void:
	print("  -- a Zone declares the chain")
	var controller := await _built(_zone([_chain()]))
	_check(controller.signal_graph_refusals.is_empty(),
			"nothing was refused: %s" % [controller.signal_graph_refusals])
	var graph := _graph(controller)
	if graph == null:
		_check(false, "a graph was built for the room that declared one")
		await _drop(controller)
		return
	_check(graph.room_id == "c001", "it belongs to the room that asked")
	_check(graph.sensors.has("plate")
			and graph.sensors["plate"] is ClassPlate,
			"the PRESSURE_PLATE is a real ClassPlate in the world")
	_check(graph.actuators.has("shutter"),
			"and the actuator it drives is bound")
	var plate: ClassPlate = graph.sensors["plate"]
	_check((controller.room_bounds["c001"] as AABB).grow(0.5)
			.has_point(plate.global_position),
			"the plate is inside the room that declared it (at %v)"
			% plate.global_position)
	_check(graph.ticks > 0,
			"the graph has been evaluated (%d tick(s))" % graph.ticks)
	_check(not bool(graph.values.get("plate", true)),
			"an empty plate reads false")
	_check(bool(graph.values.get("inverted", false)),
			"and NOT of that is true -- %s" % graph.reading())
	var shutter: ServiceShutter = graph.actuators["shutter"]["node"]
	_check(await _until(func() -> bool: return shutter.is_open()),
			"so the shutter it commands is open (%.2f)"
			% shutter.openness())
	await _drop(controller)


## THE CHAIN CARRIES A VALUE. A qualifying occupant satisfies the plate,
## the NOT inverts it, and the shutter is commanded shut -- then the
## whole thing runs backwards when the crate comes off.
func _a_heavy_occupant_closes_it_and_leaving_opens_it() -> void:
	print("  -- a HEAVY occupant drives it, both ways")
	var controller := await _built(_zone([_chain()]))
	var graph := _graph(controller)
	if graph == null:
		_check(false, "a graph was built")
		await _drop(controller)
		return
	var plate: ClassPlate = graph.sensors["plate"]
	var shutter: ServiceShutter = graph.actuators["shutter"]["node"]
	await _until(func() -> bool: return shutter.is_open())
	var ticks := graph.ticks

	var crate := await _crate(controller, plate)
	_check(MassClass.of_node(crate) == MassClass.HEAVY,
			"a 200 kg crate is HEAVY (%s)" % MassClass.of_node(crate))
	_check(plate.satisfied(), "and it satisfies the plate")
	_check(graph.ticks > ticks,
			"the sensor change re-evaluated the graph (%d -> %d)"
			% [ticks, graph.ticks])
	_check(not bool(graph.values.get("inverted", true)),
			"NOT now reads false -- %s" % graph.reading())
	_check(await _until(func() -> bool: return shutter.is_shut()),
			"and the shutter is shut (%.2f)" % shutter.openness())

	crate.global_position += Vector3(0.0, 0.0, 8.0)
	for _i in 60:
		await get_tree().physics_frame
	_check(not plate.satisfied(), "taking it off releases the plate")
	_check(await _until(func() -> bool: return shutter.is_open()),
			"and the shutter opens again (%.2f)" % shutter.openness())
	await _drop(controller)


## §3: THE PLAYER IS NOT AN OCCUPANT. A room whose machine the player's
## own body operates is a room they cannot stand in.
##
## **WHICH RULE CARRIES IT.** Until P14 two independent rules excluded
## the player and either alone passed this case: the plate skipped the
## `player` group, and `MassClass.of_node` answered "" because `Player`
## had no `mass_class()`. It has one now (`MEDIUM` at the exported
## 80 kg), so the plate's `counts_player` opt-in -- false unless the
## declaration says otherwise -- is the only rule left. This plate wants
## `HEAVY`, which a `MEDIUM` body could not satisfy anyway, so the
## decisive pair lives in `mass_class_driver`
## (`_counts_player_is_the_only_door`, on a `MEDIUM` plate). What is
## pinned here is the BEHAVIOUR on the shipped chain, and that the
## player is genuinely on the plate rather than merely near it.
func _the_player_is_not_an_occupant() -> void:
	print("  -- the player does not count")
	var controller := await _built(_zone([_chain()]))
	var graph := _graph(controller)
	if graph == null:
		_check(false, "a graph was built")
		await _drop(controller)
		return
	var plate: ClassPlate = graph.sensors["plate"]
	var shutter: ServiceShutter = graph.actuators["shutter"]["node"]
	await _until(func() -> bool: return shutter.is_open())
	var player: Player = controller.player
	player.global_position = plate.global_position + Vector3(0.0, 1.5, 0.0)
	for _i in 90:
		await get_tree().physics_frame
	# ON IT, NOT NEAR IT. The plate's own sensing volume is what decides
	# what is resting on it, so the case asks the volume rather than
	# measuring a distance and hoping.
	var sensor: Area3D = plate.get_node("Sensor")
	var overlapping := false
	for body: Variant in sensor.get_overlapping_bodies():
		if (body as Node).is_in_group("player"):
			overlapping = true
	_check(overlapping,
			"the player is inside the plate's own sensing volume "
			+ "(player %v, plate %v)"
			% [player.global_position, plate.global_position])
	_check(plate.occupants().is_empty(),
			"and the plate counts no occupants (%d)"
			% plate.occupants().size())
	_check(not plate.satisfied(), "so it is not satisfied")
	_check(shutter.is_open() or shutter.openness() > 0.5,
			"the shutter stays open (%.2f)" % shutter.openness())
	await _drop(controller)


## EX50-033'S DECISIVE CONTROL, THROUGH THE DECLARATION. `lightened`
## drops the crate's CLASS one step and touches none of its kilograms,
## so a plate that reads a class releases while the crate is exactly as
## heavy and exactly as solid as it was.
func _lightened_releases_the_plate_without_losing_a_kilogram() -> void:
	print("  -- lightened releases a class plate, at the same mass")
	var controller := await _built(_zone([_chain()]))
	var graph := _graph(controller)
	if graph == null:
		_check(false, "a graph was built")
		await _drop(controller)
		return
	var plate: ClassPlate = graph.sensors["plate"]
	var shutter: ServiceShutter = graph.actuators["shutter"]["node"]
	var crate := await _crate(controller, plate)
	await _until(func() -> bool: return shutter.is_shut())
	var kilograms := crate.mass

	crate.apply_status("lightened", 8.0, 0.40)
	for _i in 10:
		await get_tree().physics_frame
	_check(MassClass.of_node(crate) == MassClass.MEDIUM,
			"the crate is MEDIUM now (%s)" % MassClass.of_node(crate))
	_check(is_equal_approx(crate.mass, kilograms),
			"and it weighs exactly what it weighed (%.1f kg)" % crate.mass)
	_check(not plate.satisfied(),
			"the plate releases -- it reads a class, not kilograms")
	_check(await _until(func() -> bool: return shutter.is_open()),
			"and the chain opens the shutter (%.2f)" % shutter.openness())
	await _drop(controller)


## A NODE §19.2 NAMES AND NOTHING IMPLEMENTS is a GAP, and the refusal
## says so. Nothing is built: a graph whose logic node is missing would
## drive its actuator from whatever the default was, which is worse than
## no chain at all.
func _a_node_the_runtime_lacks_is_refused_and_nothing_is_built() -> void:
	print("  -- AND is named by the design and has no runtime")
	var controller := await _built(_zone([_chain("AND")]))
	_check(controller.signal_graph_refusals.size() == 1,
			"one refusal (%s)" % [controller.signal_graph_refusals])
	var why := str(controller.signal_graph_refusals[0]
			if not controller.signal_graph_refusals.is_empty() else "")
	_check(why.contains("no runtime implements"),
			"and it reads as a gap rather than a typo: '%s'" % why)
	_check(_graph(controller) == null, "no graph was built")
	var plates := 0
	for child: Node in controller.get_children():
		if child is ClassPlate or child is ServiceShutter:
			plates += 1
	_check(plates == 0,
			"and no half of the chain was left standing (%d)" % plates)
	await _drop(controller)


## A KIND THE DESIGN DOES NOT NAME AT ALL is a TYPO, and it gets a
## different answer. One message for both would make a misspelling read
## as a feature request.
func _a_kind_the_design_does_not_name_is_refused_differently() -> void:
	print("  -- NAND is not one of the eleven")
	var controller := await _built(_zone([_chain("NAND")]))
	var why := str(controller.signal_graph_refusals[0]
			if not controller.signal_graph_refusals.is_empty() else "")
	_check(why.contains("eleven node types"),
			"the refusal names the vocabulary: '%s'" % why)
	_check(not why.contains("no runtime implements"),
			"and does NOT call it a missing runtime")
	await _drop(controller)

	print("  -- LEVER is a sensor with no runtime")
	var second := await _built(_zone([_chain("NOT", "LEVER")]))
	var sensor_why := str(second.signal_graph_refusals[0]
			if not second.signal_graph_refusals.is_empty() else "")
	_check(sensor_why.contains("no runtime implements"),
			"a named sensor with no runtime is a gap too: '%s'"
			% sensor_why)
	await _drop(second)


## A GRAPH IN A ROOM THIS ZONE DID NOT BUILD drives nothing. The schema
## refuses it, so a Zone reaching the engine with one is a Zone that
## came from somewhere else -- and the engine must not build half of it.
func _a_graph_in_a_room_that_is_not_there_is_refused() -> void:
	print("  -- a graph in a room that is not there")
	var controller := await _built(_zone([_chain("NOT", "PRESSURE_PLATE",
			"command", "c009")]))
	var why := str(controller.signal_graph_refusals[0]
			if not controller.signal_graph_refusals.is_empty() else "")
	_check(why.contains("c009"),
			"the refusal names the room: '%s'" % why)
	_check(_graph(controller) == null, "and nothing was built")
	await _drop(controller)


# ---------------------------------------------------------------------------
# LATCH — the node that lets a chain OPEN a route instead of only denying one
# ---------------------------------------------------------------------------

## D-10's finding, and the answer to it.
##
## With `PRESSURE_PLATE` and `NOT` alone every sensor rests false, so a
## chain can only ever DENY a route: the player loads the plate and
## something shuts. Denying strands nobody and constrains nothing, which
## is a weak puzzle — and `plate -> shutter` with no inversion is worse,
## because the player would have to stand on the plate AND walk through
## the door it opens, which is two places at once.
##
## `LATCH` is the node that fixes it: step on the plate once, the value
## holds, the way stays open. **The semantics are checked here directly**
## rather than through `RoomGraphs`, because the builder reads
## `Constants.SIGNAL_NODE_KINDS_IMPLEMENTED` — generated from the
## schema's `SUPPORTED_NODE_KINDS` — and the schema has not admitted
## `LATCH` yet. That is the dependency order working: the runtime
## exists, and the declaration opens when the last piece does.
func _a_latch_holds_its_value_and_is_restored() -> void:
	print("  -- LATCH: set once, held after, restored on rebuild")
	var graph := SignalGraph.new()
	graph.room_id = "c001"
	graph.nodes.append({"id": "held", "kind": "LATCH",
			"inputs": ["plate"]})
	add_child(graph)
	var fired: Array[String] = []
	var packages: Array[String] = []
	graph.fired.connect(func(package: String, node: String) -> void:
			packages.append(package)
			fired.append(node))

	# The sensor is read from `values`, so a case can drive it without a
	# physical plate: this one is about the NODE, and the plate has its
	# own cases above.
	graph.values["plate"] = false
	graph.evaluate()
	_check(not bool(graph.values.get("held", true)),
			"an unset latch with a false input reads false")

	graph.values["plate"] = true
	graph.evaluate()
	_check(bool(graph.values.get("held", false)),
			"a true input sets it")
	_check(fired.size() == 1 and fired[0] == "held",
			"and it says so ONCE (%s)" % [fired])
	_check(packages.size() == 1 and packages[0] == "graph_c001",
			"under a package of its own, not the bare room id (%s)"
			% [packages])

	# THE PLAYER STEPS OFF. This is the whole difference from `NOT`.
	graph.values["plate"] = false
	graph.evaluate()
	_check(bool(graph.values.get("held", false)),
			"and it HOLDS when the input goes away -- which is what "
			+ "lets one action open a way and then walk through it")
	graph.evaluate()
	_check(fired.size() == 1,
			"it does not re-announce itself every tick (%d)" % fired.size())
	graph.queue_free()

	# REBUILT FROM THE CAMPAIGN'S RECORD, not from anything the engine
	# was told about the machine. §5.4a.
	var rebuilt := SignalGraph.new()
	rebuilt.room_id = "c001"
	rebuilt.nodes.append({"id": "held", "kind": "LATCH",
			"inputs": ["plate"]})
	add_child(rebuilt)
	rebuilt.values["plate"] = false
	rebuilt.evaluate()
	_check(not bool(rebuilt.values.get("held", true)),
			"a fresh graph starts unlatched")
	# THE BARE ROOM ID IS NOT THIS GRAPH'S PACKAGE, so a record that
	# used it must not restore anything.
	var announced := fired.size()
	var back := rebuilt.restore_from(["c001/held", "other/thing",
			"graph_c001/held"])
	_check(back == 1,
			"one latch is restored; the bare-room ref and the stranger "
			+ "are ignored (%d)" % back)
	# RESTORE RECORDS; THE FIRST EVALUATION IS `start()`'s. The value is
	# not in `values` until then, which is the point: nothing downstream
	# ever saw the latch unset on a reload.
	rebuilt.start()
	_check(bool(rebuilt.values.get("held", false)),
			"the decision comes back with the Zone, with the plate "
			+ "clear and nothing standing on it")
	_check(fired.size() == announced,
			"and putting it back is NOT announced as a new decision")
	rebuilt.queue_free()
	await get_tree().process_frame


## AND NOW IT IS DECLARABLE. The schema admitted `LATCH` (Dess, 9ef2676),
## so a Zone asking for `plate -> LATCH -> shutter` gets one built --
## this case asserted the opposite until that landed, and the flip is the
## dependency order working rather than a test being loosened.
func _a_latch_chain_is_declarable_and_builds() -> void:
	print("  -- a declared LATCH chain builds")
	_check(Constants.SIGNAL_NODE_KINDS_IMPLEMENTED.has("LATCH"),
			"the schema admits LATCH (%s)"
			% [Constants.SIGNAL_NODE_KINDS_IMPLEMENTED])
	var controller := await _built(_zone([_chain("LATCH")]))
	_check(controller.signal_graph_refusals.is_empty(),
			"nothing was refused: %s" % [controller.signal_graph_refusals])
	var graph := _graph(controller)
	_check(graph != null and graph.nodes.size() == 1
			and str((graph.nodes[0] as Dictionary).get("kind", "")) == "LATCH",
			"and the graph carries the latch")
	await _drop(controller)


## O05-07.5: A CLASS IS NOT A SUM, AND TWO OCCUPANTS ARE ONE ANSWER --
## through the graph, not only at the plate (the plate-level pair is
## `mass_class_driver._debris_does_not_add_up`). MEDIUM debris whose
## kilograms add past HEAVY's floor leaves the NOT true and the shutter
## open. Two HEAVY bodies are one answer, not a count: taking one off
## leaves the plate satisfied and the shutter shut, and only the last one
## leaving releases it.
func _a_class_is_not_a_sum_and_one_off_is_not_both() -> void:
	print("  -- two occupants: a class is not a sum; one off is not both")
	var controller := await _built(_zone([_chain()]))
	var graph := _graph(controller)
	if graph == null:
		_check(false, "a graph was built")
		await _drop(controller)
		return
	var plate: ClassPlate = graph.sensors["plate"]
	var shutter: ServiceShutter = graph.actuators["shutter"]["node"]
	await _until(func() -> bool: return shutter.is_open())

	var debris: Array[ManipulableBody] = [
		await _small_crate(controller, plate, "debris_a", -0.55, 100.0),
		await _small_crate(controller, plate, "debris_b", 0.55, 100.0)]
	var classes: Array = debris.map(
			func(b: ManipulableBody) -> String: return MassClass.of_node(b))
	_check(classes == [MassClass.MEDIUM, MassClass.MEDIUM]
			and plate.occupants().size() == 2 and not plate.satisfied()
			and bool(graph.values.get("inverted", false))
			and shutter.is_open(),
			"two MEDIUM bodies, 200 kg together against HEAVY's %.0f kg "
			% MassClass.MEDIUM_BELOW + "floor: the plate is not satisfied, "
			+ "NOT is still true and the shutter open -- %s"
			% [plate.reading()])
	for body in debris:
		body.global_position += Vector3(0.0, 0.0, 5.0)
	for _i in 60:
		await get_tree().physics_frame
	_check(plate.occupants().is_empty(), "the debris is off the plate")

	var first := await _small_crate(controller, plate, "heavy_a", -0.55,
			200.0)
	var second := await _small_crate(controller, plate, "heavy_b", 0.55,
			200.0)
	_check(plate.occupants().size() == 2 and plate.satisfied(),
			"two HEAVY bodies on the plate: %s" % [plate.reading()])
	_check(await _until(func() -> bool: return shutter.is_shut()),
			"and the shutter is shut")
	# EVERY ANSWER THE PLATE GIVES, not only the last: a plate that
	# released for one frame when a body left, and took it back the next,
	# would end up satisfied with the shutter shut and still have told the
	# graph the crossing was open.
	var answers: Array[bool] = []
	plate.occupancy_changed.connect(func(now: bool) -> void:
		answers.append(now))
	first.global_position += Vector3(0.0, 0.0, 8.0)
	for _i in 60:
		await get_tree().physics_frame
	_check(plate.occupants().size() == 1 and plate.satisfied()
			and answers.is_empty()
			and not bool(graph.values.get("inverted", true))
			and shutter.is_shut(),
			"one taken off: the plate never changed its answer (%s), NOT is "
			% [answers] + "still false and the shutter still shut -- %s"
			% graph.reading())
	second.global_position += Vector3(0.0, 0.0, 8.0)
	for _i in 60:
		await get_tree().physics_frame
	_check(not plate.satisfied() and answers == [false]
			and await _until(func() -> bool: return shutter.is_open()),
			"the last one off releases the plate, once (%s), and the "
			% [answers] + "shutter opens")
	await _drop(controller)


## A body small enough that two stand on one plate side by side.
func _small_crate(controller: ZoneController, plate: ClassPlate,
		id: String, across: float, kilograms: float) -> ManipulableBody:
	var body := ManipulableBody.create(id, kilograms,
			Vector3(0.9, 0.9, 0.9))
	controller.add_child(body)
	body.global_position = plate.global_position \
			+ Vector3(across, 1.0, 0.0)
	for _i in 60:
		await get_tree().physics_frame
	return body


## O05-07.5: STALE CALLBACKS AND A REPEATED PULSE. A lever outlives the
## graph that wired it: freeing the graph leaves nothing on the lever, so
## no pull can reach a graph that is gone. The graph that replaces it is
## wired once however often it starts, and hears one pull once -- the
## LATCH sets and fires once -- while a second pull fires nothing more.
func _a_graph_that_is_gone_hears_nothing() -> void:
	print("  -- a lever outlives its graph; the next graph hears it once")
	var lever := CallLever.make("TEST", Color(1.0, 1.0, 1.0))
	add_child(lever)
	var old := _button_latch(lever)
	add_child(old)
	old.start()
	_check(lever.pulled.get_connections().size() == 1,
			"a started graph wired the lever once")
	old.free()
	_check(lever.pulled.get_connections().is_empty(),
			"the freed graph left nothing wired to the lever")
	var fresh := _button_latch(lever)
	add_child(fresh)
	fresh.start()
	fresh.start()
	# WIRED ONCE is held twice over: the graph skips a lever it has
	# wired, and behind that the engine refuses an identical connection
	# (with an error). Removing the graph's guard does not fail this
	# check; it adds the engine's error to the log.
	_check(lever.pulled.get_connections().size() == 1,
			"its replacement, started twice, is wired once")
	var fired: Array[String] = []
	fresh.fired.connect(func(_package: String, id: String) -> void:
		fired.append(id))
	lever.interact(self)
	_check(fired == ["held"] and fresh.latched.has("held"),
			"one pull: the LATCH set and fired once (%s)" % [fired])
	lever.interact(self)
	fresh.evaluate()
	_check(fired == ["held"] and bool(fresh.values.get("held", false))
			and not bool(fresh.values.get("button", true)),
			"a second pull fires nothing more, and on the next tick the "
			+ "pulse is gone while the latch holds")
	fresh.free()
	lever.free()


## A PULSE_BUTTON into a LATCH, the way a hosted minor binds its lever.
func _button_latch(lever: CallLever) -> SignalGraph:
	var graph := SignalGraph.new()
	graph.room_id = "test"
	graph.sensors["button"] = lever
	graph.nodes.append({"id": "held", "kind": "LATCH",
			"inputs": ["button"]})
	return graph
