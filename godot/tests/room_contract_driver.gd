extends Node
## THE ROOM CONTRACT CONFORMANCE SUITE (`make godot-room-contract`).
##
## ONE suite, keyed to `room_contract.gd` and `room_audit.gd`, run over
## BOTH producers. That is the whole design and it is not a stylistic
## preference: this project has now watched three per-path suites inherit
## the blind spot of the fix they were written to protect --
## `activity_driver.gd` proved the activity runtime worked while the game
## built activities in zero rooms; `_test_a_pit_is_a_hole_not_a_painted_floor`
## proved a pit was dug while the floor slab above it was still a lid;
## the first version of the environment-vs-activity test used a room big
## enough that the bug it was written for could not occur.
##
## A suite whose assumptions mirror one producer proves that producer is
## self-consistent. The question here is different and it is the owner's:
##
##     BEFORE WE PUT AUTHORED ROOMS INTO THE GAME, MAKE "THIS IS A VALID
##     ROOM" MEAN THE SAME THING REGARDLESS OF WHO PRODUCED IT.
##
## So every case below is the same two calls -- `RoomContract.violations`
## then `RoomAudit.findings` -- against rooms from `ChamberBuilders`, from
## `ContentInstantiator._from_authored_scene`, and from deliberately
## broken authored fixtures that MUST be caught. The suite cannot tell
## which producer made what it is holding, and neither can the contract.

const AUTHORED_ROOM := "res://content/test_fixtures/shell_room_honest.tscn"
const AUTHORED_LID := "res://content/test_fixtures/shell_room_lid.tscn"
const AUTHORED_SEALED := "res://content/test_fixtures/shell_room_sealed.tscn"

var failures := 0
## Vacuity guards. Every "nothing was wrong" assertion is worth nothing
## if no room was built and no probe was fired.
var rooms_checked := 0
var authored_checked := 0
var probes_expected_to_fail := 0
## Authored shells that are `review: pending` AND do not yet measure
## true. Reported, never fatal: nothing can select them.
var shells_awaiting_review := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

## P1 reported the reward-inside-a-crate finding as a pinned NOTE, since
## fixing it meant moving what the player sees. P2 fixed it -- the arena
## reserves the Check's space before it scatters anything -- so there is
## nothing left to excuse and every finding is a failure again.
func _judge(found: Array[String], who: String) -> void:
	_check(found.is_empty(),
			"%s does not match its own geometry: %s"
			% [who, "; ".join(found)])

func _ready() -> void:
	await _run()

func _run() -> void:
	await get_tree().process_frame
	BridgeClient.snapshot = _snapshot()

	await _test_every_procedural_room_meets_the_contract()
	await _test_an_authored_room_meets_the_same_contract()
	await _test_both_producers_offer_the_same_vocabulary()
	await _test_the_audit_catches_a_lid_over_a_declared_surface()
	await _test_the_audit_catches_a_surface_made_of_air()
	await _test_the_audit_catches_a_sealed_opening()
	await _test_the_audit_refuses_to_pass_what_it_cannot_measure()
	await _test_a_shell_that_overflows_its_envelope_is_refused()
	await _test_the_contract_refuses_a_malformed_room()
	await _test_a_jump_is_measured_the_same_for_both_producers()
	await _test_a_declared_turn_steers_the_chain()
	await _test_a_tower_shell_built_for_other_floor_counts_is_not_used()
	await _test_a_check_never_stands_inside_the_room()
	await _test_one_envelope_convention_binds_both_producers()
	await _test_every_authored_shell_in_the_registry_is_measured()
	await _test_a_pending_shell_never_reaches_a_zone()

	_check(rooms_checked >= 8,
			"only %d rooms went through the contract; the suite is not "
			% rooms_checked + "exercising the producers")
	_check(authored_checked >= 1,
			"no authored room went through the contract, so this is a "
			+ "procedural suite wearing a contract's name")
	_check(probes_expected_to_fail >= 3,
			"only %d deliberately broken rooms were caught; a suite that "
			% probes_expected_to_fail + "never sees a failure is a suite "
			+ "nobody can trust")

	if shells_awaiting_review > 0:
		print("  %d pending shell(s) do not yet measure true; they are "
				% shells_awaiting_review
				+ "not selectable and are the owner's to review")

	if failures == 0:
		print("GODOT ROOM CONTRACT TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT ROOM CONTRACT TESTS: %d failures" % failures)
		get_tree().quit(1)

# --- fixtures -------------------------------------------------------------

func _snapshot() -> Dictionary:
	return {
		"type": "campaign_snapshot",
		"mechanics": {"owned": [], "aliases": [], "links": [],
				"statuses": [], "resources": []},
		"slots": {}, "local_rewards": [],
		"available_capabilities": ["ranged_hit"],
		"coins_received": 0, "coins_spent": 0, "hub": {"state": "IDLE"},
	}

## Every chamber type the generator can produce, including the two shapes
## ROOM GRAMMAR v0 added. Not a sample: the contract has to hold for the
## room a Zone actually contains, and the arena WITH a band is a
## different physical object from the arena without one.
func _procedural_chambers() -> Array:
	return [
		{"id": "k1", "type": "corridor", "length": 14.0, "width": 6.0},
		{"id": "k2", "type": "arena", "width": 20.0, "depth": 18.0,
			"wall_height": 6.5, "objective": "kill_all",
			"enemies": [{"archetype": "ranged", "count": 3}]},
		{"id": "k3", "type": "arena", "width": 20.0, "depth": 18.0,
			"wall_height": 6.5, "objective": "kill_all",
			"enemies": [{"archetype": "ranged", "count": 3}],
			"elevation": {"kind": "gallery", "rise": 2.2,
				"coverage": 0.35, "side": "left", "access": "ramp"}},
		{"id": "k4", "type": "arena", "width": 22.0, "depth": 20.0,
			"wall_height": 6.5, "objective": "kill_all",
			"enemies": [{"archetype": "melee", "count": 2}],
			"elevation": {"kind": "pit", "rise": 1.6, "coverage": 0.35,
				"side": "back", "access": "ramp"}},
		{"id": "k5", "type": "platform_path", "segment_count": 4,
			"gap_size": 2.1, "vertical_step": 0.51,
			"enemies": [{"archetype": "melee", "count": 2}]},
		{"id": "k6", "type": "tower", "floors": 3,
			"enemies": [{"archetype": "ranged", "count": 2}]},
		{"id": "k7", "type": "treasure_room"},
	]

## Built through the SAME entry point the game uses. A room this suite
## constructed itself would be a room only this suite has ever seen.
func _build(chamber: Dictionary) -> Dictionary:
	var result := ContentInstantiator.build_chamber(
			chamber, "concrete_facility")
	if result.get("root") != null:
		add_child(result["root"] as Node3D)
	return result

func _space() -> PhysicsDirectSpaceState3D:
	return get_viewport().world_3d.direct_space_state

## An authored entry whose declarations match `shell_room_honest.tscn`.
##
## The same manifest is reused for the BROKEN fixtures, exactly as the D1
## traversal test does: nothing in the metadata distinguishes a shell
## with a lid over its balcony from one without, so only measuring can.
func _authored_entry(scene: String) -> Dictionary:
	return {
		"id": "shell_room_test", "level": 3, "category": "room_shell",
		"display_name": "Contract Room", "procedural_fallback": false,
		"scene": scene, "size_class": "medium", "review": "pass",
		"size": [12.0, 6.0, 16.0],
		"sockets": [
			{"name": "entry", "kind": "doorway",
				"position": [0.0, 0.0, 0.0], "width": 2.4, "height": 3.2},
			{"name": "exit", "kind": "doorway",
				"position": [0.0, 0.0, 16.0], "width": 2.4,
				"height": 3.2},
			{"name": "crate_a", "kind": "cover",
				"position": [-3.4, 0.0, 6.0], "surface_id": "floor"},
			{"name": "drum_a", "kind": "reactive",
				"position": [3.4, 0.0, 6.0], "surface_id": "floor"},
			{"name": "perch", "kind": "enemy_high",
				"position": [-3.6, 3.0, 11.0], "surface_id": "balcony"},
		],
		"surfaces": [
			{"name": "floor", "center": [0.0, 0.0, 8.0],
				"extent": [11.2, 15.2]},
			{"name": "balcony", "center": [-3.6, 3.0, 11.0],
				"extent": [4.0, 5.6]},
		],
		"volumes": [
			{"name": "under_balcony", "kind": "no_build",
				"center": [-3.6, 1.5, 11.0], "size": [4.0, 3.0, 5.6]},
			{"name": "prize", "kind": "objective",
				"center": [0.0, 0.0, 12.0], "size": [2.0, 2.0, 2.0]},
		],
	}

func _authored_room(scene: String) -> Dictionary:
	var entry := _authored_entry(scene)
	var result: Dictionary = ContentInstantiator.build_chamber(
			{"id": "auth", "type": "arena", "width": 12.0, "depth": 16.0,
				"wall_height": 6.0, "objective": "reach_exit",
				"enemies": [], "shell_id": str(entry["id"])},
			"concrete_facility", _registry_for(entry))
	if result.get("root") != null:
		add_child(result["root"] as Node3D)
	return result

## A registry holding exactly one authored shell, named by the chamber,
## so `build_chamber` takes the authored branch instead of the procedural
## fallback every shipped entry declares.
func _registry_for(entry: Dictionary) -> ContentRegistry:
	var registry := ContentRegistry.new()
	registry.entries[str(entry["id"])] = entry
	return registry

# --- the contract, over both producers ------------------------------------

func _test_every_procedural_room_meets_the_contract() -> void:
	for chamber: Dictionary in _procedural_chambers():
		var result := _build(chamber)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var who := "procedural %s" % str(chamber["type"])
		var structural := RoomContract.violations(result, who)
		_check(structural.is_empty(),
				"%s breaks the contract: %s" % [who, "; ".join(structural)])
		_judge(RoomAudit.findings(result, _space(), who), who)
		rooms_checked += 1
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame

func _test_an_authored_room_meets_the_same_contract() -> void:
	"""The asymmetry this whole slice exists to close.

	Before P1 this room came back with no `sockets` key at all, so it
	offered no cover, no barrels, no reserved regions and nowhere to
	stand -- and `Activities` flat-solved against its bounds, which is
	the defect `552469d` closed for `platform_path` sitting in the one
	path no Zone takes yet."""
	var result := _authored_room(AUTHORED_ROOM)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(result.get("root") != null, "the authored fixture did not build")
	var structural := RoomContract.violations(result, "authored")
	_check(structural.is_empty(),
			"an authored room breaks the contract: %s"
			% "; ".join(structural))
	var measured := RoomAudit.findings(result, _space(), "authored")
	_check(measured.is_empty(),
			"an authored room does not match its own geometry: %s"
			% "; ".join(measured))
	rooms_checked += 1
	authored_checked += 1
	if result.get("root") != null:
		(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

## Everything a COMPOSER reads off a room. `access` is deliberately not
## here: it is builder-internal, consumed only by the audits that ask
## whether a band can be walked to, and an authored shell says the same
## thing with a traversal segment.
const COMPOSED_KINDS := ["stand", "reserved", "cover", "reactive",
		"enemy_high"]

func _test_both_producers_offer_the_same_vocabulary() -> void:
	"""Parity is not "both pass the checks" -- an empty room passes every
	check there is. It is "both can SAY the same things", and a contract
	only one producer can speak is a description of that producer.

	Not every room says everything: an arena has no jumps to declare and
	a corridor has no balcony. The claim is that no kind belongs to one
	PRODUCER."""
	var authored := _authored_room(AUTHORED_ROOM)
	await get_tree().physics_frame
	var offered_by_procedural := {}
	var rooms: Array[Node3D] = []
	for chamber: Dictionary in _procedural_chambers():
		var room := _build(chamber)
		await get_tree().physics_frame
		for kind: String in RoomContract.SOCKET_KINDS:
			if not RoomContract.sockets_of(room, kind).is_empty():
				offered_by_procedural[kind] = true
		if room.get("root") != null:
			rooms.append(room["root"] as Node3D)
		rooms_checked += 1

	for kind: String in COMPOSED_KINDS:
		_check(not RoomContract.sockets_of(authored, kind).is_empty(),
				"the authored room offers no '%s'; before P1 it offered "
				% kind + "NOTHING, which is the asymmetry this closes")
		_check(offered_by_procedural.has(kind),
				"no procedural room offers '%s', so the contract has a "
				% kind + "kind only one producer can speak")
	_check(offered_by_procedural.has("access"),
			"no procedural room offers 'access'; the band reachability "
			+ "audits read it")
	authored_checked += 1
	rooms.append(authored["root"] as Node3D)
	for room in rooms:
		room.queue_free()
	await get_tree().process_frame

func _test_a_declared_turn_steers_the_chain() -> void:
	"""P2-B. The corner shells are the whole reason: their geometry
	always assumed a turning exit, which is why `exit_offset` already
	carries it, and until now nothing downstream could act on that.

	The sign is established and was expensive -- `ZoneBuilder` rotates by
	`Basis(Vector3.UP, yaw)` and ADDS the turn, so a shell leaving
	through its +X wall turns the chain +90 and is the LEFT corner. An
	earlier version of the art builders had the two names swapped and it
	was caught by a render disagreeing with its own caption."""
	var straight := _authored_room(AUTHORED_ROOM)
	await get_tree().physics_frame
	_check(float(straight.get("exit_yaw", 0.0)) == 0.0,
			"a shell that declares no turn must go straight through")
	(straight["root"] as Node3D).queue_free()

	for turn: float in [90.0, -90.0]:
		var entry := _authored_entry(AUTHORED_ROOM)
		entry["exit_yaw"] = turn
		var registry := _registry_for(entry)
		var result: Dictionary = ContentInstantiator.build_chamber(
				{"id": "turn", "type": "arena", "width": 12.0,
					"depth": 16.0, "wall_height": 6.0,
					"objective": "reach_exit", "enemies": [],
					"shell_id": str(entry["id"])},
				"concrete_facility", registry)
		add_child(result["root"] as Node3D)
		await get_tree().physics_frame
		_check(float(result.get("exit_yaw", 0.0)) == turn,
				"a shell declaring %.0f must carry it into the contract"
				% turn)
		_check(RoomContract.violations(result, "turn").is_empty(),
				"a quarter turn must satisfy the contract")
		rooms_checked += 1
		authored_checked += 1
		(result["root"] as Node3D).queue_free()

	# And the chain actually turns. Measured on the built Zone rather
	# than asserted about the number: two rooms whose exits both turn
	# +90 must leave the second one facing across the first.
	var zone := _turning_zone(90.0)
	await get_tree().physics_frame
	var yaws := _chamber_yaws(zone)
	_check(yaws.size() >= 2, "the turning Zone built %d rooms"
			% yaws.size())
	if yaws.size() >= 2:
		var delta: float = rad_to_deg(yaws[1] - yaws[0])
		_check(absf(delta - 90.0) < 1.0,
				"a +90 exit must turn the chain +90; it turned %.1f"
				% delta)
	(zone["root"] as Node3D).queue_free()

	var back := _turning_zone(0.0)
	await get_tree().physics_frame
	var straight_yaws := _chamber_yaws(back)
	if straight_yaws.size() >= 2:
		_check(absf(straight_yaws[1] - straight_yaws[0]) < 0.001,
				"a shell declaring no turn must leave the chain straight")
	(back["root"] as Node3D).queue_free()
	# AND THE REAL CORNERS. The fixture proves the mechanism; these are
	# the shells the turn exists for, with the sign the art lane derived.
	var registry := ContentRegistry.new()
	registry.load_all()
	for pair: Array in [["shell_corner_left", 90.0],
			["shell_corner_right", -90.0]]:
		var entry := registry.get_entry(str(pair[0]))
		_check(not entry.is_empty(), "%s is not in the registry"
				% str(pair[0]))
		if entry.is_empty():
			continue
		_check(float(entry.get("exit_yaw", 0.0)) == float(pair[1]),
				"%s declares exit_yaw %.1f; the art lane derived %.0f "
				% [str(pair[0]), float(entry.get("exit_yaw", 0.0)),
					float(pair[1])]
				+ "and that sign was expensive")
		var lifted := entry.duplicate(true)
		lifted["review"] = "pass"
		var private := ContentRegistry.new()
		private.entries[str(pair[0])] = lifted
		var built: Dictionary = ContentInstantiator.build_chamber(
				_chamber_for(lifted), "concrete_facility", private)
		add_child(built["root"] as Node3D)
		await get_tree().physics_frame
		_check(float(built.get("exit_yaw", 0.0)) == float(pair[1]),
				"%s: the turn did not reach the room contract"
				% str(pair[0]))
		rooms_checked += 1
		authored_checked += 1
		(built["root"] as Node3D).queue_free()
	probes_expected_to_fail += 1
	await get_tree().process_frame

## A two-room Zone whose rooms are the authored fixture, turning by
## `turn`. Built through `ZoneBuilder.build`, which is the only place
## chaining happens.
func _turning_zone(turn: float) -> Dictionary:
	var entry := _authored_entry(AUTHORED_ROOM)
	entry["exit_yaw"] = turn
	# `ZoneBuilder` reaches the SHARED registry, which is the whole
	# point: this has to be the chaining the game does, not a private
	# copy of it. Lend the shared one the fixture and hand it back.
	ContentRegistry.shared().entries[str(entry["id"])] = entry
	var chambers: Array = []
	for i in 2:
		chambers.append({"id": "t%d" % i, "type": "arena", "width": 12.0,
				"depth": 16.0, "wall_height": 6.0,
				"objective": "reach_exit", "enemies": [],
				"shell_id": str(entry["id"])})
	var zone := ZoneBuilder.build({"zone_id": "zt", "theme":
			"concrete_facility", "chambers": chambers})
	ContentRegistry.reset_shared()
	add_child(zone["root"] as Node3D)
	return zone

func _chamber_yaws(zone: Dictionary) -> Array[float]:
	var out: Array[float] = []
	for entry: Dictionary in zone["chambers"]:
		out.append((entry["xform"] as Transform3D).basis.get_euler().y)
	return out

func _test_a_tower_shell_built_for_other_floor_counts_is_not_used() -> void:
	"""P2-C. The art lane's towers are 2, 3 and 5 floors; the generator
	may ask for 4. A shell either was built for the count or it was not,
	and when none was, the permanent procedural builder makes the room.

	Do not stretch a 3-floor tower into a 4-floor one: the climb is
	geometry, and a floor that is not there is a route the player cannot
	finish."""
	var entry := _authored_entry(AUTHORED_ROOM)
	entry["id"] = "shell_tower_test"
	entry["fits_floors"] = [3]
	var registry := _registry_for(entry)
	for floors: int in [3, 4]:
		var result: Dictionary = ContentInstantiator.build_chamber(
				{"id": "tw", "type": "tower", "floors": floors,
					"enemies": [], "shell_id": str(entry["id"])},
				"concrete_facility", registry)
		add_child(result["root"] as Node3D)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var authored := not (result.get("sockets", []) as Array).is_empty()
		if floors == 3:
			_check(authored, "a tower shell built for 3 floors must be "
					+ "used for a 3-floor tower")
		else:
			_check(not authored,
					"a tower shell built for 3 floors was used for a "
					+ "4-floor tower")
			# And what came back is a real room, not a refusal.
			_check(RoomContract.violations(result, "tower4").is_empty(),
					"the procedural fallback must still be a valid room")
			_judge(RoomAudit.findings(result, _space(), "tower4"),
					"tower4")
		rooms_checked += 1
		(result["root"] as Node3D).queue_free()
	# AND THE REAL TOWERS. 2, 3 and 5 exist; the generator may ask for 4.
	var shipped := ContentRegistry.new()
	shipped.load_all()
	var declared := {}
	for id: String in ["shell_tower_collapsed", "shell_tower_spiral",
			"shell_tower_gantry"]:
		var real := shipped.get_entry(id)
		_check(not real.is_empty(), "%s is not in the registry" % id)
		if real.is_empty():
			continue
		var fits: Array = real.get("fits_floors", [])
		_check(fits.size() == 1, "%s declares %d floor counts; each art "
				% [id, fits.size()] + "tower was built for exactly one")
		if not fits.is_empty():
			declared[int(fits[0])] = id
	_check(declared.keys().size() == 3,
			"the three art towers cover %d distinct floor counts"
			% declared.keys().size())
	_check(not declared.has(4),
			"a tower shell claims to fit 4 floors; the art lane built "
			+ "2, 3 and 5")
	# The request the catalog cannot serve.
	var four := shipped.get_entry("shell_tower_spiral").duplicate(true)
	four["review"] = "pass"
	var only_spiral := ContentRegistry.new()
	only_spiral.entries["shell_tower_spiral"] = four
	var fallback: Dictionary = ContentInstantiator.build_chamber(
			{"id": "t4", "type": "tower", "floors": 4, "enemies": [],
				"shell_id": "shell_tower_spiral"},
			"concrete_facility", only_spiral)
	add_child(fallback["root"] as Node3D)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check((fallback.get("traversal", []) as Array).is_empty(),
			"a 4-floor tower was served by a 3-floor authored shell")
	_check(RoomContract.violations(fallback, "tower4real").is_empty(),
			"the procedural room a 4-floor tower falls back to must be "
			+ "a valid room")
	_judge(RoomAudit.findings(fallback, _space(), "tower4real"),
			"tower4real")
	rooms_checked += 1
	(fallback["root"] as Node3D).queue_free()
	probes_expected_to_fail += 1
	await get_tree().process_frame

func _test_a_check_never_stands_inside_the_room() -> void:
	"""P2-A, at the scale the bug lived at.

	Two of four arenas in the P1 suite dropped a Check pedestal inside
	one of their own crates. Sixteen arenas here, each with a Check
	declared, each measured where `ZoneController` will really put the
	pedestal -- because one arena passing is how the original bug hid."""
	var buried := 0
	for i in 16:
		var chamber := {
			"id": "rw%d" % i, "type": "arena",
			"width": 12.0 + float(i % 5) * 2.5,
			"depth": 10.0 + float(i % 4) * 3.0,
			"wall_height": 6.0, "objective": "kill_all",
			"reward_location_id": 89100001 + i,
			"enemies": [{"archetype": "melee", "count": 2}]}
		if i % 3 == 0:
			chamber["elevation"] = {"kind": "gallery", "rise": 2.2,
					"coverage": 0.45,
					"side": ["left", "right", "back"][i % 3],
					"access": "ramp"}
		var result := _build(chamber)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var at: Vector3 = result["reward_position"]
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(ChamberBuilders.REWARD_PEDESTAL,
				ChamberBuilders.REWARD_PEDESTAL_HEIGHT - 0.4,
				ChamberBuilders.REWARD_PEDESTAL)
		query.shape = shape
		query.transform = Transform3D(Basis(), at + Vector3.UP
				* (ChamberBuilders.REWARD_PEDESTAL_HEIGHT / 2.0 + 0.2))
		query.collide_with_areas = false
		if not (result["root"] as Node3D).get_world_3d() 				.direct_space_state.intersect_shape(query, 1).is_empty():
			buried += 1
		rooms_checked += 1
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame
	_check(buried == 0,
			"%d of 16 arenas stand a Check inside their own geometry"
			% buried)

func _test_one_envelope_convention_binds_both_producers() -> void:
	"""THE P2 ENVELOPE DEFECT, and the asymmetry that hid it.

	`ShellValidator._check_envelope` allowed 0.15 m outside a room's
	declared box and ran on the AUTHORED PATH ALONE. It refused all
	eight P2 shells, whose entry wall sits at z in [-0.40, 0] -- and
	every procedural room breaks the same rule by 0.05 m, because
	`_perimeter` CENTRES its walls on the boundary and overhangs by
	WALL_THICKNESS / 2 on all four sides. A convention that describes
	neither producer is not a convention, and a check only one producer
	takes is not a contract.

	Measured, not argued: this walks both producers and reports the real
	overhang, then proves the shared rule still bites."""
	var worst_procedural := 0.0
	for chamber: Dictionary in _procedural_chambers():
		var result := _build(chamber)
		await get_tree().physics_frame
		var bounds: AABB = result["bounds"]
		for box in ShellValidator.mesh_boxes(
				result["root"] as Node3D, Transform3D.IDENTITY):
			for axis in 3:
				worst_procedural = maxf(worst_procedural, maxf(
						bounds.position[axis] - box.position[axis],
						box.end[axis] - bounds.end[axis]))
		rooms_checked += 1
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame
	print("  procedural rooms overhang their bounds by up to %.2f m"
			% worst_procedural)
	_check(worst_procedural > 0.15,
			"no procedural room overhangs by more than the old 0.15 m "
			+ "allowance, so this test is not measuring the defect")
	_check(worst_procedural <= RoomContract.WALL_ALLOWANCE,
			"a procedural room reaches %.2f m outside its bounds, past "
			% worst_procedural + "the shared allowance of %.2f"
			% RoomContract.WALL_ALLOWANCE)

	# The authored side of the same rule, at its real worst.
	var registry := ContentRegistry.new()
	registry.load_all()
	var worst_authored := 0.0
	var seen := 0
	for id: String in registry.ids_of_category("room_shell"):
		var entry := registry.get_entry(id)
		if bool(entry.get("procedural_fallback", false)):
			continue
		var size: Array = entry.get("size", [])
		if size.size() < 3:
			continue
		var node: Node3D = (load(str(entry["scene"])) as PackedScene
				).instantiate()
		var declared := AABB(
				Vector3(-float(size[0]) / 2.0,
					-ContentInstantiator.FLOOR_ALLOWANCE, 0.0),
				Vector3(float(size[0]),
					float(size[1]) + ContentInstantiator.FLOOR_ALLOWANCE,
					float(size[2])))
		for box in ShellValidator.mesh_boxes(node, Transform3D.IDENTITY):
			for axis in 3:
				worst_authored = maxf(worst_authored, maxf(
						declared.position[axis] - box.position[axis],
						box.end[axis] - declared.end[axis]))
		seen += 1
		node.free()
	print("  authored shells overhang their envelope by up to %.2f m "
			% worst_authored + "(%d measured)" % seen)
	_check(seen >= 8, "only %d authored shells were measured" % seen)
	_check(worst_authored > 0.15,
			"no authored shell overhangs by more than the old 0.15 m "
			+ "allowance, so this test is not measuring the defect")
	_check(worst_authored <= RoomContract.WALL_ALLOWANCE,
			"an authored shell reaches %.2f m outside its envelope, past "
			% worst_authored + "the shared allowance of %.2f"
			% RoomContract.WALL_ALLOWANCE)

	# AND IT STILL BITES. A shared convention that accepts everything is
	# not a convention either.
	_check(RoomContract.WALL_ALLOWANCE < ChamberBuilders.WALL_THICKNESS * 2.0,
			"the allowance is two walls wide; geometry that far out is "
			+ "inside the neighbour's interior")

## Which chamber the art lane built each family for. Read off the entry's
## own `semantic_tags`, so a shell that renames itself is audited as
## whatever it now says it is rather than as whatever this list
## remembers.
const FAMILY_TYPE := {
	"tower": "tower", "treasure_room": "treasure_room",
	# The corners are tagged `corner`, which is NOT a chamber type -- see
	# the note in the test. Audited as the corridor-shaped room they are.
	"corner": "corridor",
}

func _test_every_authored_shell_in_the_registry_is_measured() -> void:
	"""EVERY authored room shell the registry carries, through the SAME
	contract and the SAME probes a procedural room gets.

	No F3-specific exemption exists and none may: the audit takes a room
	output and a physics space and cannot tell who produced it. The one
	thing lifted here is the art-lane REVIEW GATE, because that is
	exactly the question being asked -- would this asset be safe if
	somebody promoted it? Everything else is the live path: the same
	`build_chamber`, the same `ShellValidator`, the same fallback chain.
	"""
	var registry := ContentRegistry.new()
	registry.load_all()
	var shells: Array[String] = []
	for id: String in registry.ids_of_category("room_shell"):
		if not bool(registry.get_entry(id).get("procedural_fallback", false)):
			shells.append(id)
	shells.sort()
	_check(shells.size() >= 8,
			"the registry carries %d authored room shells; the P2 pack "
			% shells.size() + "is eight")

	for id in shells:
		var entry: Dictionary = registry.get_entry(id).duplicate(true)
		# The review gate, and ONLY the review gate.
		entry["review"] = "pass"
		var chamber := _chamber_for(entry)
		var private := ContentRegistry.new()
		private.entries[id] = entry
		var result: Dictionary = ContentInstantiator.build_chamber(
				chamber, "concrete_facility", private)
		add_child(result["root"] as Node3D)
		await get_tree().physics_frame
		await get_tree().physics_frame

		var authored := not (result.get("sockets", []) as Array).is_empty()
		_check(authored, "%s: the authored scene was refused and the "
				% id + "procedural builder answered instead")
		var structural := RoomContract.violations(result, id)
		var measured := RoomAudit.findings(result, _space(), id)
		var pending := str(registry.get_entry(id).get("review", "")) \
				== "pending"
		print("  %-24s %-8s surfaces=%-2d traversal=%-2d sockets=%-2d "
				% [id, "PENDING" if pending else "PASS",
					RoomContract.sockets_of(result, "stand").size(),
					(result.get("traversal", []) as Array).size(),
					(result.get("sockets", []) as Array).size()]
				+ "structural=%d measured=%d"
				% [structural.size(), measured.size()])
		# Grouped by KIND rather than listed. Eight shells sharing one
		# root cause produce six hundred sentences saying it, and the
		# thing a reviewer needs is which CLASSES of claim failed.
		var classes := {}
		for finding: String in structural + measured:
			var label := "other"
			for probe: String in ["has no geometry under it",
					"of headroom", "has nothing under it",
					"is sealed", "no floor beneath it",
					"inside solid geometry", "as built",
					"nothing to stand on", "outside the room's own bounds",
					"declared a gap"]:
				if finding.contains(probe):
					label = probe
			classes[label] = int(classes.get(label, 0)) + 1
		for label: String in classes:
			print("      %-32s x%d" % [label, classes[label]])
		# THE REVIEW GATE IS THE AUDIT GATE. A `pending` shell is content
		# nobody has approved and nothing can select, so its findings are
		# EVIDENCE FOR THAT REVIEW rather than a broken build. The moment
		# somebody flips one to `pass`, this line starts demanding it be
		# clean -- which is the property that makes promotion safe rather
		# than a decision taken by whoever edits a JSON field.
		if not pending:
			_check(structural.is_empty() and measured.is_empty(),
					"%s is approved content and fails the room contract"
					% id)
		elif not (structural.is_empty() and measured.is_empty()):
			shells_awaiting_review += 1
		rooms_checked += 1
		authored_checked += 1
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame

## The chamber a shell was built to be, with the parameters it declares.
func _chamber_for(entry: Dictionary) -> Dictionary:
	var type := "arena"
	for tag: Variant in entry.get("semantic_tags", []):
		if FAMILY_TYPE.has(str(tag)):
			type = str(FAMILY_TYPE[str(tag)])
	var size: Array = entry.get("size", [12.0, 6.0, 12.0])
	var chamber := {"id": "audit", "type": type,
			"shell_id": str(entry["id"]), "enemies": []}
	match type:
		"tower":
			var fits: Array = entry.get("fits_floors", [])
			chamber["floors"] = int(fits[0]) if not fits.is_empty() else 3
		"corridor":
			chamber["length"] = float(size[2])
			chamber["width"] = float(size[0])
		"treasure_room":
			pass
		_:
			chamber["width"] = float(size[0])
			chamber["depth"] = float(size[2])
			chamber["wall_height"] = float(size[1])
			chamber["objective"] = "reach_exit"
	return chamber

func _test_a_pending_shell_never_reaches_a_zone() -> void:
	"""The art lane's gate, measured rather than trusted.

	A file existing in the tree is not approval, and an asset that
	validates is not an asset somebody decided to ship. The eight P2
	shells are `review: pending`, so the room a player would walk into is
	the procedural one -- and it is a real room, not a refusal."""
	var registry := ContentRegistry.new()
	registry.load_all()
	var pending := 0
	for id: String in registry.ids_of_category("room_shell"):
		var entry := registry.get_entry(id)
		if str(entry.get("review", "")) != "pending":
			continue
		pending += 1
		var result: Dictionary = ContentInstantiator.build_chamber(
				_chamber_for(entry), "concrete_facility", registry)
		add_child(result["root"] as Node3D)
		await get_tree().physics_frame
		_check((result.get("sockets", []) as Array).is_empty()
				or not (result.get("traversal", []) as Array).is_empty()
					== false,
				"%s is pending and its authored scene was built anyway"
				% id)
		_check(RoomContract.violations(result, id).is_empty(),
				"%s: the room a player gets instead must be a valid one"
				% id)
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame
	_check(pending >= 8,
			"only %d shells are pending; the P2 pack is eight and none "
			% pending + "of them may be player-selectable yet")
	probes_expected_to_fail += 1

# --- the audit catches what a description cannot --------------------------

func _test_the_audit_catches_a_lid_over_a_declared_surface() -> void:
	"""The sealed-pit lesson, generalised and moved to the import gate.

	`shell_room_lid.tscn` is `shell_room_honest.tscn` with one slab added
	over the balcony. It carries the IDENTICAL manifest: same surfaces,
	same sockets, same volumes, all internally consistent. Every
	structural check passes it. Only a ray from above can tell."""
	var result := _authored_room(AUTHORED_LID)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var structural := RoomContract.violations(result, "lid")
	_check(structural.is_empty(),
			"the lid fixture must be structurally VALID, or the test is "
			+ "proving the wrong thing: %s" % "; ".join(structural))
	var measured := RoomAudit.findings(result, _space(), "lid")
	_check(not measured.is_empty(),
			"a slab over a declared walkable surface was not measured")
	_check("; ".join(measured).contains("lid")
			or "; ".join(measured).contains("headroom"),
			"the finding must name what was measured: %s"
			% "; ".join(measured))
	probes_expected_to_fail += 1
	authored_checked += 1
	if result.get("root") != null:
		(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_the_audit_catches_a_surface_made_of_air() -> void:
	"""The plainest lie a room can tell, and the one the whole slice
	exists for: "you can stand here", where there is nothing.

	Every structural check passes it -- the socket is well formed, the
	extent is real, the position is inside the bounds. The room is built
	honestly and then its declaration is moved two metres up, so the
	geometry and the claim disagree by exactly the amount a floor is
	worth."""
	var result := _authored_room(AUTHORED_ROOM)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var moved := result.duplicate()
	var sockets: Array = []
	for socket: Variant in result.get("sockets", []) as Array:
		var copy: Dictionary = (socket as Dictionary).duplicate()
		if str(copy.get("kind", "")) == "stand" \
				and str(copy.get("name", "")) == "balcony":
			copy["position"] = (copy["position"] as Vector3) \
					+ Vector3.UP * 2.0
		sockets.append(copy)
	moved["sockets"] = sockets
	_check(RoomContract.violations(moved, "air").is_empty(),
			"the moved surface must stay structurally VALID, or this "
			+ "measures the wrong thing")
	var measured := RoomAudit.findings(moved, _space(), "air")
	_check(not measured.is_empty(),
			"a walkable surface declared in mid-air was not measured")
	_check("; ".join(measured).contains("nothing under it")
			or "; ".join(measured).contains("has no geometry under it"),
			"the finding must say what was missing: %s"
			% "; ".join(measured))
	probes_expected_to_fail += 1
	authored_checked += 1
	if result.get("root") != null:
		(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_the_audit_catches_a_sealed_opening() -> void:
	"""Mesh IS collider here, so a doorway that was modelled and never
	cut is a wall the chain believes is a door. The player finds out
	standing in front of it, three rooms into a Zone."""
	var result := _authored_room(AUTHORED_SEALED)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var measured := RoomAudit.findings(result, _space(), "sealed")
	_check(not measured.is_empty(), "a sealed exit was not measured")
	_check("; ".join(measured).contains("sealed"),
			"the finding must say the opening is sealed: %s"
			% "; ".join(measured))
	probes_expected_to_fail += 1
	authored_checked += 1
	if result.get("root") != null:
		(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_the_audit_refuses_to_pass_what_it_cannot_measure() -> void:
	"""A probe against a detached node comes back clean because there is
	nothing there to hit. That is the most dangerous possible pass, and
	it is how a whole batch once shipped green."""
	var chamber: Dictionary = _procedural_chambers()[1]
	var detached := ContentInstantiator.build_chamber(
			chamber, "concrete_facility")
	var measured := RoomAudit.findings(detached, _space(), "detached")
	_check(not measured.is_empty(),
			"a room outside the scene tree was reported clean")
	_check("; ".join(measured).contains("scene tree"),
			"the refusal must say why nothing could be measured: %s"
			% "; ".join(measured))
	var spaceless := RoomAudit.findings(detached, null, "spaceless")
	_check(not spaceless.is_empty(),
			"an audit with no physics space was reported clean")
	probes_expected_to_fail += 1
	(detached["root"] as Node3D).free()

func _test_a_shell_that_overflows_its_envelope_is_refused() -> void:
	"""`content.py` has always DOCUMENTED that Godot re-derives `size`
	from the real scene and refuses a manifest that lies about it. Until
	P1 nothing kept that promise, and it is the one claim a room cannot
	be allowed to get wrong: rooms are chained by butting their declared
	envelopes together, so a shell bigger than its manifest reaches into
	the next room -- and the overlap guard that would catch it is fed the
	very number being lied about."""
	var entry := _authored_entry(AUTHORED_ROOM)
	# The same honest 12 x 6 x 16 m room, declared four metres narrower.
	entry["size"] = [8.0, 6.0, 16.0]
	var scene: PackedScene = load(AUTHORED_ROOM)
	var instance: Node3D = scene.instantiate()
	add_child(instance)
	var refusals := ShellValidator.refusals(entry, instance)
	_check(not refusals.is_empty(),
			"a shell four metres wider than its manifest was accepted")
	_check("\n".join(refusals).contains("envelope"),
			"the refusal must name what was measured against: %s"
			% "\n".join(refusals))
	instance.free()

	# And the honest one still passes, or the check is just a refusal.
	var honest: Node3D = (load(AUTHORED_ROOM) as PackedScene).instantiate()
	add_child(honest)
	_check(ShellValidator.refusals(_authored_entry(AUTHORED_ROOM),
			honest).is_empty(),
			"the honest fixture must survive its own envelope check")
	honest.free()
	probes_expected_to_fail += 1
	await get_tree().process_frame

func _test_the_contract_refuses_a_malformed_room() -> void:
	"""The other half. Structure and geometry fail differently, and a
	suite that only measures would accept a room with no exit."""
	var result := _build(_procedural_chambers()[1])
	await get_tree().physics_frame
	for broken: Array in [
			["a room with no exit", "exit_offset"],
			["a room with no bounds", "bounds"],
			["a room with no spawns", "enemy_spawns"]]:
		var copy := result.duplicate()
		copy.erase(str(broken[1]))
		_check(not RoomContract.violations(copy).is_empty(),
				"%s was accepted" % str(broken[0]))
	var bad_socket := result.duplicate()
	bad_socket["sockets"] = [{"kind": "trapdoor",
			"position": Vector3.ZERO}]
	_check(not RoomContract.violations(bad_socket).is_empty(),
			"a socket kind outside the contract was accepted")
	var no_extent := result.duplicate()
	no_extent["sockets"] = [{"kind": "stand", "position": Vector3.ZERO,
			"extent": Vector3.ZERO}]
	_check(not RoomContract.violations(no_extent).is_empty(),
			"a walkable surface with no area was accepted")
	var far_away := result.duplicate()
	far_away["sockets"] = [{"kind": "cover",
			"position": Vector3(0.0, 0.0, 900.0)}]
	_check(not RoomContract.violations(far_away).is_empty(),
			"a socket outside the room's own bounds was accepted")
	probes_expected_to_fail += 1
	(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_a_jump_is_measured_the_same_for_both_producers() -> void:
	"""One movement law, one measurement, whoever declared the jump.

	`platform_path` has always HAD mandatory jumps bounded by
	`max_safe_gap`, and until P1 nothing downstream could see that a jump
	existed. Now it declares them in the same words an authored shell
	does, and the same audit measures both."""
	var result := _build(_procedural_chambers()[4])
	await get_tree().physics_frame
	await get_tree().physics_frame
	var declared: Array = result.get("traversal", []) as Array
	_check(declared.size() == 5,
			"a 4-segment platform path makes 5 mandatory jumps and "
			+ "declared %d" % declared.size())
	_check(RoomAudit.findings(result, _space(), "jumps").is_empty(),
			"the platform path's own declared jumps do not measure true")

	# The same audit, on the same room, with one jump quietly widened
	# past the base kit's reach. Nothing else changes.
	var lying := result.duplicate()
	var faked: Array = []
	for segment: Variant in declared:
		var copy: Dictionary = (segment as Dictionary).duplicate()
		faked.append(copy)
	var first: Dictionary = faked[0]
	first["end"] = (first["end"] as Vector3) + Vector3(0.0, 0.0, 6.0)
	lying["traversal"] = faked
	var measured := RoomAudit.findings(lying, _space(), "jumps")
	_check(not measured.is_empty(),
			"a jump past the base kit's reach was not measured")
	_check("; ".join(measured).contains("as built"),
			"the finding must field what was MEASURED: %s"
			% "; ".join(measured))
	rooms_checked += 1
	probes_expected_to_fail += 1
	(result["root"] as Node3D).queue_free()
	await get_tree().process_frame
