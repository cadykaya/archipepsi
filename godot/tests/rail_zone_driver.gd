extends Node
## A DECLARED RAILWAY, BUILT INTO A REAL ZONE (`make godot-rail-zone`).
##
## D-4's engine half. The bridge lane's `Zone.rail_networks` (`704f379`)
## lets a Zone ask for rail content; `RailNetworks` is what answers, and
## this is what certifies that the answer is the railway the Zone asked
## for rather than a railway.
##
## **What a certification has to check, and why each one.**
##
##   THE DOCKS ARE WHERE THE ZONE SAID. A dock is declared by ROOM, and
##   a carrier parked in the wrong room is a vehicle nobody can board.
##   Measured against `room_bounds`, which is the committed layout.
##   THE LINKS ARE THE DECLARED ONES. A span with a control starts
##   REFUSED -- it is the thing the player earns -- and a span with no
##   control ships commissioned, because the schema says a null
##   `control_room_id` means it needs none. A build that commissioned
##   everything would look identical until someone tried to earn one.
##   THE CONTROL IS IN ITS OWN ROOM. `control_room_id` names where the
##   lever lives, and a lever in the wrong room is a span nobody can
##   commission.
##   THE LATCH SURVIVES A REBUILD. §5.4a: the decision persists and the
##   machine is RECOMPUTED from it. So a second build handed the fired
##   latch must come up already commissioned, without anything having
##   saved a span.
##   AND A DECLARATION THE ENGINE CANNOT HONOUR IS REFUSED BY NAME.
##   `RailCarrier` runs one ordered route, so a span between
##   non-consecutive docks has no link to commission. The engine says so
##   and builds nothing, rather than guessing a route through the dock
##   in between -- which would be the engine deciding what the Zone
##   meant.
##
## **SYNTHETIC ZONES.** Each case composes a small Zone dictionary and
## builds it through the real `ZoneController`, so what is under test is
## the production path from a declaration to a machine. No Zone here is
## played and no route is walked: this answers "did the declaration
## become the right machine", and whether the railway is any good to
## ride is what `godot-rail-junction` and `godot-rail-carrier` already
## measure on the machine itself.

var _failures := 0
var _checks := 0
var _notes := 0


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _note(message: String) -> void:
	_notes += 1
	print("  NOTE: %s" % message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	await _a_declaration_becomes_a_machine()
	await _the_links_are_the_declared_ones()
	await _a_fired_latch_rebuilds_commissioned()
	await _a_span_the_carrier_cannot_run_is_refused()
	await _a_zone_with_no_railway_builds_none()
	await _the_carrier_parks_where_the_zone_says()
	print("")
	if _failures == 0:
		print("GODOT RAIL ZONE OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT RAIL ZONE: %d failures in %d checks"
			% [_failures, _checks])
	get_tree().quit(1)


func _settle(frames := 8) -> void:
	for _i in frames:
		await get_tree().physics_frame


## A three-room Zone with one railway across it. `spans` is filled by
## the caller so each case declares exactly the shape it is about.
func _zone(spans: Array, docks := 3) -> Dictionary:
	var chambers: Array = []
	var dock_list: Array = []
	for i in docks:
		var rid := "c%03d" % (i + 1)
		chambers.append({
			"id": rid, "type": "corridor", "theme": "concrete_facility",
			"activities": [], "features": [], "enemies": [],
			"rewards": [], "interactables": [],
		})
		dock_list.append({"dock_id": "d%d" % i, "room_id": rid})
	return {
		"schema_version": 7, "zone_id": "zone_rail", "seed": 7,
		"theme": "concrete_facility", "chambers": chambers,
		"rail_networks": [{
			"network_id": "yard", "docks": dock_list, "spans": spans,
		}],
	}


func _built(zone: Dictionary) -> ZoneController:
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(zone)
	return controller


func _drop(controller: ZoneController) -> void:
	controller.queue_free()
	await get_tree().process_frame


# --------------------------------------------------- the declaration

## Does a declared network become a carrier, a junction and a span, in
## the rooms the Zone named?
func _a_declaration_becomes_a_machine() -> void:
	print("  -- A DECLARATION BECOMES A MACHINE")
	var controller := _built(_zone([{
		"span_id": "s0", "from_dock": "d0", "to_dock": "d1",
		"control_room_id": "c002", "latch_id": "span_one",
		"mandatory": true,
	}]))
	await _settle()
	_check(controller.layout_failed == "",
			"the Zone built: %s" % [controller.layout_failed])
	var junctions: Array = controller.rail_junctions()
	_check(junctions.size() == 1,
			"one declared network built one junction (%d)"
			% junctions.size())
	if junctions.is_empty():
		await _drop(controller)
		return
	var junction: RailJunction = junctions[0]
	_check(junction.package_id == "yard",
			"the junction's package is the NETWORK ID '%s', which is "
			% junction.package_id
			+ "what its latches will be reported under")
	var carriers: Array = controller.rail_carriers()
	var carrier: RailCarrier = carriers[0]
	_check(carrier.dock_ids.size() == 3,
			"three declared docks became three stops (%d)"
			% carrier.dock_ids.size())

	# EVERY DOCK IN THE ROOM THAT DECLARED IT.
	var astray := 0
	for i in carrier.dock_ids.size():
		var rid := "c%03d" % (i + 1)
		var bounds: AABB = controller.room_bounds.get(rid, AABB())
		var at := carrier.path.at(carrier.dock_offsets[i])
		# Generous in Y only: the rail runs a deck-height above arrival
		# on purpose, so a player steps ON it.
		if not bounds.grow(1.5).has_point(at):
			astray += 1
			_note("dock %s at %v is outside %s %v"
					% [carrier.dock_ids[i], at, rid, bounds])
	_check(astray == 0,
			"every dock stands in the room its declaration names "
			+ "(%d astray)" % astray)

	_check(junction.spans().size() == 1,
			"one declared span became one span (%d)"
			% junction.spans().size())
	_check(junction.latch_ref(junction.spans()[0]) == "yard/span_one",
			"the span persists under the declared latch, as '%s'"
			% junction.latch_ref(junction.spans()[0]))

	# THE CONTROL IS IN THE ROOM THAT NAMED IT.
	var controls: Array[AlignmentControl] = junction.controls()
	_check(controls.size() == 1 and controls[0] != null,
			"the declared control room produced a control")
	if not controls.is_empty() and controls[0] != null:
		var home: AABB = controller.room_bounds.get("c002", AABB())
		_check(home.grow(1.5).has_point(controls[0].global_position),
				"...standing in c002, the room that declared it, at %v"
				% controls[0].global_position)
	await _drop(controller)


## A span with a control starts REFUSED; one without starts open.
func _the_links_are_the_declared_ones() -> void:
	print("  -- A SPAN IS THE THING YOU EARN, OR IT IS NOT A SPAN")
	var controller := _built(_zone([{
		"span_id": "s0", "from_dock": "d0", "to_dock": "d1",
		"control_room_id": "c002", "latch_id": "earned",
		"mandatory": true,
	}, {
		"span_id": "s1", "from_dock": "d1", "to_dock": "d2",
		"control_room_id": null, "latch_id": "given",
		"mandatory": false,
	}]))
	await _settle()
	var carriers: Array = controller.rail_carriers()
	_check(not carriers.is_empty(), "the Zone built a carrier")
	if carriers.is_empty():
		await _drop(controller)
		return
	var carrier: RailCarrier = carriers[0]
	_check(carrier.commissioned.size() == 2,
			"three docks leave two links (%d)"
			% carrier.commissioned.size())
	_check(not carrier.commissioned[0],
			"the span WITH a control starts refused: it is what the "
			+ "player earns")
	_check(carrier.commissioned[1],
			"the span with a NULL control ships commissioned, which is "
			+ "what the schema says a null control_room_id means")
	var junction: RailJunction = controller.rail_junctions()[0]
	var with_control := 0
	for control: Variant in junction.controls():
		if control != null:
			with_control += 1
	_check(with_control == 1,
			"one lever for the one span that needs one (%d)"
			% with_control)
	await _drop(controller)


## §5.4a: the decision persists, the machine is recomputed from it.
func _a_fired_latch_rebuilds_commissioned() -> void:
	print("  -- THE LATCH PERSISTS, THE SPAN IS RECOMPUTED")
	var zone := _zone([{
		"span_id": "s0", "from_dock": "d0", "to_dock": "d1",
		"control_room_id": "c002", "latch_id": "earned",
		"mandatory": true,
	}])
	var first := _built(zone)
	await _settle()
	var before: RailCarrier = first.rail_carriers()[0]
	_check(not before.commissioned[0],
			"a fresh Zone comes up with the span NOT commissioned")
	await _drop(first)

	# The same Zone, rebuilt knowing the latch fired -- which is exactly
	# what a snapshot carries after a player earned it and walked out.
	var second := ZoneController.new()
	get_tree().root.add_child(second)
	second.latches_carried = {"yard/earned": true}
	second.setup(zone)
	await _settle()
	var after: RailCarrier = second.rail_carriers()[0]
	_check(after.commissioned[0],
			"rebuilt from the latch, the span is commissioned again")
	_check(after.dock_offsets.size() == 3,
			"...and the carrier still has its three docks")
	_note("nothing saved a span: the latch ref is the only thing that "
			+ "crossed between the two builds")
	await _drop(second)


## THE REFUSAL. A carrier runs one ordered route.
func _a_span_the_carrier_cannot_run_is_refused() -> void:
	print("  -- A SPAN THE CARRIER CANNOT RUN IS REFUSED BY NAME")
	var controller := _built(_zone([{
		"span_id": "s_jump", "from_dock": "d0", "to_dock": "d2",
		"control_room_id": "c002", "latch_id": "jumped",
		"mandatory": true,
	}]))
	await _settle()
	_check(controller.rail_junctions().is_empty(),
			"nothing was built for a network the engine cannot honour")
	_check(controller.rail_refusals.size() == 1,
			"...and it said so once (%d refusal(s))"
			% controller.rail_refusals.size())
	if not controller.rail_refusals.is_empty():
		var why: String = controller.rail_refusals[0]
		_check(why.contains("s_jump") and why.contains("consecutive"),
				"...naming the span and the reason: %s" % why)
	_check(controller.layout_failed == "",
			"the Zone itself still built: a railway the engine will not "
			+ "guess at is a finding, not a crash")
	_note("this is the D-4 question for the bridge lane: either spans "
			+ "join neighbouring docks, or the carrier becomes "
			+ "graph-capable. The engine refuses rather than deciding.")
	await _drop(controller)


## THE ADDITIVE HALF. A Zone composed before `rail_networks` existed has
## none, and must be untouched by any of this.
func _a_zone_with_no_railway_builds_none() -> void:
	print("  -- A ZONE THAT DECLARES NO RAILWAY GETS NONE")
	var zone := _zone([])
	zone.erase("rail_networks")
	var controller := _built(zone)
	await _settle()
	_check(controller.layout_failed == "",
			"a Zone with no `rail_networks` key builds: %s"
			% [controller.layout_failed])
	_check(controller.rail_junctions().is_empty()
			and controller.rail_refusals.is_empty(),
			"...with no junction and nothing refused")
	await _drop(controller)


## F-24 answer 3: `home_dock` is the Zone's declaration now, not an
## engine assumption. `null` still means the first dock, so the default
## is what it always was and a Zone composed before the field is
## unaffected.
func _the_carrier_parks_where_the_zone_says() -> void:
	print("  -- THE CARRIER PARKS WHERE THE ZONE SAYS")
	var declared := _zone([{
		"span_id": "s0", "from_dock": "d0", "to_dock": "d1",
		"control_room_id": null, "latch_id": "given", "mandatory": false,
	}])
	(declared["rail_networks"] as Array)[0]["home_dock"] = "d2"
	var controller := _built(declared)
	await _settle()
	var carrier: RailCarrier = controller.rail_carriers()[0]
	_check(is_equal_approx(carrier.offset, carrier.dock_offsets[2]),
			"a network naming `home_dock: d2` parks at dock 2 (offset "
			+ "%.2f, dock 2 is %.2f)" % [carrier.offset,
				carrier.dock_offsets[2]])
	await _drop(controller)

	# AND THE DEFAULT IS UNCHANGED. A null home_dock is the first dock,
	# which is what the engine assumed before the field existed -- so
	# this is the control that says the answer cost nothing.
	var plain := _built(_zone([{
		"span_id": "s0", "from_dock": "d0", "to_dock": "d1",
		"control_room_id": null, "latch_id": "given", "mandatory": false,
	}]))
	await _settle()
	var default_carrier: RailCarrier = plain.rail_carriers()[0]
	_check(is_equal_approx(default_carrier.offset,
			default_carrier.dock_offsets[0]),
			"a network declaring no home_dock still parks at the first")
	await _drop(plain)
