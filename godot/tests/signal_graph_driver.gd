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
## **WHAT THIS CANNOT TELL APART, said here rather than implied by a
## green tick.** Two independent rules exclude the player and either
## alone would pass this case: `ClassPlate.occupants` skips anything in
## the `player` group, and `MassClass.of_node` returns "" for a node
## with no `mass_class()` -- which `Player` does not have. Deleting the
## group check does NOT fail this suite; that was checked. So what is
## pinned here is the BEHAVIOUR, that a player standing on a plate does
## not drive the chain, and the case proves the player is genuinely on
## the plate rather than merely near it. Which of the two rules is
## carrying it is not something this can answer, and a case that
## claimed otherwise would be the third in this lane to pass for the
## wrong reason.
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
