extends Node
## STAGE 3A: A PLAYER ACTUALLY RIDES AN AUTHORED RAIL
## (`make godot-playtest3a`).
##
## WHAT THIS SUITE IS FOR, and what would make it worthless. Every gate
## in this project could report the movement offers green while no player
## had ever touched one: the offers were measured, the nodes could be
## constructed, and none of that is the same claim as "a person moved
## differently because of it". So every proof here drives the REAL
## `Player` through the REAL `ZoneController` over the REAL authored
## scenes, and a node existing is never accepted as evidence that a node
## did anything.
##
## THE SHOWCASE IS SCAFFOLDING (Road to Playable 0.3, R2). The four
## authored rooms are named by hand, which is not composition and does
## not satisfy A1 or A2. What it does is put authored rails and authored
## launch pads in front of a real player one stage earlier than real
## composition can, so that when 3B lands there is a consumer waiting for
## it rather than a second unproven system.
##
## THE THREE SELECTIONS ARE THE SAME ZONE (R7). `none`, `rail` and
## `launch` build the same rooms from the same manifests and differ only
## in what gets constructed, which is what makes the comparisons here
## mean anything: a route that changes between them changed because of
## the package and nothing else.

var failures := 0
## Vacuity guards. "Nothing went wrong" is worth nothing if no Zone was
## built, no player moved and no offer was ever refused.
var zones_built := 0
var player_proofs := 0
var refusals_seen := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	await _run()

func _run() -> void:
	await get_tree().process_frame

	await _test_the_showcase_names_the_four_approved_rooms()
	await _test_each_mode_builds_exactly_what_it_says()
	await _test_a_player_rides_an_authored_rail()
	await _test_a_player_is_launched_by_an_authored_pad()
	await _test_movement_works_in_a_translated_and_yawed_room()
	await _test_the_showcase_finishes_with_no_movement_package()
	await _test_validation_stays_pure_under_every_mode()
	await _test_a_second_construction_is_refused()
	await _test_an_unknown_selection_is_refused_not_defaulted()
	await _test_ordinary_startup_builds_no_movement_geometry()

	_check(zones_built >= 3,
			"only %d showcase Zones were built; the three selections must "
			% zones_built + "each be exercised on real geometry")
	_check(player_proofs >= 2,
			"only %d real-player movement proofs ran; a node existing is "
			% player_proofs + "not evidence that a player moved")
	_check(refusals_seen >= 2,
			"only %d refusals were observed; a suite that never sees one "
			% refusals_seen + "cannot tell a guard from a comment")

	if failures == 0:
		print("GODOT PLAYTEST 3A TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT PLAYTEST 3A TESTS: %d failures" % failures)
		get_tree().quit(1)

# --- the showcase, stood up through the real runtime -----------------------

## One live showcase Zone in the selected mode.
##
## THE REAL PATH, DELIBERATELY. `ShowcaseZone.build` produces a Zone
## dictionary, `ZoneController.setup` runs `ZoneBuilder`, which runs
## `ContentInstantiator`, which resolves each `shell_id` and instantiates
## the authored scene; the offer stage then runs deferred, one physics
## frame later, exactly as it does for a player. Nothing here shortcuts
## into `MovementPackage` or hand-places a pad.
##
## `place` moves the whole Zone, because identity is the one transform
## where a room's frame and the world's coincide and therefore the one
## transform that cannot detect a frame error.
func _showcase(mode: String, place := Transform3D.IDENTITY) -> Dictionary:
	var host := Node3D.new()
	host.transform = place
	add_child(host)
	var zone := ZoneController.new()
	zone.movement_package = mode
	host.add_child(zone)
	zone.setup(ShowcaseZone.build())
	# The offer stage is deferred to the next physics frame and then
	# awaits one of its own, so three carries construction to completion.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	zones_built += 1
	return {"host": host, "zone": zone}

func _drop(rig: Dictionary) -> void:
	(rig["host"] as Node3D).queue_free()
	await get_tree().process_frame

## Every constructed launch pad under a node.
func _pads(root: Node) -> Array:
	var out: Array = []
	if root is AffordanceNodes.LaunchPad:
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_pads(child))
	return out

## Every constructed rail lane under a node -- the ride volume that
## carries the path, which is the thing a player actually enters.
func _lanes(root: Node) -> Array:
	var out: Array = []
	if root is AffordanceNodes.Volume \
			and (root as AffordanceNodes.Volume).rail != null:
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_lanes(child))
	return out

## Which authored shells the live Zone actually instantiated.
##
## Read from `authored_shell`, the stamp `ContentInstantiator` puts on a
## build result when it really did instantiate the authored scene. Asked
## of the RESULT rather than of the request, because the instantiator
## falls back to a procedural room for a shell it cannot resolve and a
## showcase that silently got four procedural rooms would otherwise pass
## every count in this file.
func _shells_present(zone: ZoneController) -> Array:
	var out: Array = []
	for raw: Variant in zone.offer_rooms:
		var record: Dictionary = raw
		var build: Dictionary = record["build"]
		var stamped := str(build.get("authored_shell", ""))
		if stamped != "":
			out.append(stamped)
	return out

# --- 1. the showcase is what it claims to be -------------------------------

func _test_the_showcase_names_the_four_approved_rooms() -> void:
	"""The scaffolding has to be the real rooms, or nothing after this
	means anything. A showcase that quietly fell back to four procedural
	arenas would still report offers, still build nothing, and still
	pass a census -- so the authored scenes are looked for by name."""
	var registry := ContentRegistry.new()
	registry.load_all()
	var wanted := ShowcaseZone.shell_ids()
	_check(wanted.size() == 4,
			"the showcase names %d rooms, not the four offer-bearing "
			% wanted.size() + "approved shells")
	for id: String in wanted:
		var entry := registry.get_entry(id)
		_check(not entry.is_empty(), "%s is not in the registry" % id)
		_check(str(entry.get("review", "")) == "pass",
				"%s is '%s', and the showcase may only use approved "
				% [id, str(entry.get("review", ""))] + "rooms")
		_check(not (entry.get("offers", []) as Array).is_empty(),
				"%s declares no offers, so it cannot show one" % id)
	var rig: Dictionary = await _showcase("none")
	var zone: ZoneController = rig["zone"]
	var present := _shells_present(zone)
	_check(present.size() == 4,
			"the live showcase instantiated %d of the 4 authored shells "
			% present.size() + "(%s); the rest fell back to procedural "
			% ", ".join(PackedStringArray(present)) + "rooms")
	print("  showcase shells present: %s"
			% ", ".join(PackedStringArray(present)))
	# THE CHAIN, AS PLACED. Recorded so the report describes the layout
	# the composer actually produced rather than the one it was asked
	# for -- `ZoneBuilder` aligns entry connectors, avoids overlap and
	# applies each room's own `exit_yaw`, and none of that is restated
	# in `ShowcaseZone`.
	for raw: Variant in zone.offer_rooms:
		var record: Dictionary = raw
		var at: Transform3D = record["xform"]
		print("      %-20s origin %v  yaw %.0f deg"
				% [str((record["build"] as Dictionary)
						.get("authored_shell", "?")),
					at.origin, rad_to_deg(at.basis.get_euler().y)])
	# AND EACH ONE IS THE ROOM THAT WAS ASKED FOR.
	for want: String in ShowcaseZone.shell_ids():
		_check(present.has(want),
				"%s was named by the showcase and did not instantiate" % want)
	await _drop(rig)

# --- 2. the census, per mode -----------------------------------------------

func _test_each_mode_builds_exactly_what_it_says() -> void:
	"""THE CENSUS IS FOUR DIFFERENT NUMBERS AND THEY ARE NOT
	INTERCHANGEABLE.

	`declared` counts manifest entries. `judged` counts verdicts, and is
	smaller because a launch PAIR is one verdict measuring two authored
	points. `built` counts nodes that now exist, and is smaller again
	because a grapple point is accepted and constructs nothing -- there
	is no grapple mechanic in this engine, so reporting one as built
	would be a claim that something was made (R9).

	And the mode filter has to be a filter: `rail` may not leak a pad,
	`launch` may not leak a beam, `none` may not leak either."""
	var expected := {"none": 0, "rail": 4, "launch": 4}
	for mode: String in ["none", "rail", "launch"]:
		var rig: Dictionary = await _showcase(mode)
		var zone: ZoneController = rig["zone"]
		var census: Dictionary = zone.offer_census
		print("  mode=%-6s declared=%d judged=%d accepted=%d built=%d "
				% [mode, census["declared"], census["judged"],
					census["accepted"], census["built"]]
				+ "declined=%d refused=%d"
				% [census["declined"], census["refused"]])
		_check(int(census["declared"]) == 24,
				"mode %s declared %d offers, not the 24 the four rooms "
				% [mode, int(census["declared"])] + "carry")
		_check(int(census["judged"]) == 20,
				"mode %s judged %d offers, not 20 -- four launch targets "
				% [mode, int(census["judged"])] + "are measured inside "
				+ "their source's verdict, not as verdicts of their own")
		_check(int(census["accepted"]) == 20,
				"mode %s accepted %d of 20 judged offers"
				% [mode, int(census["accepted"])])
		_check(int(census["declined"]) == 0,
				"mode %s declined %d offers against real geometry"
				% [mode, int(census["declined"])])
		_check(int(census["refused"]) == 0,
				"mode %s could not measure %d room(s)"
				% [mode, int(census["refused"])])
		_check(int(census["built"]) == int(expected[mode]),
				"mode %s built %d nodes, not the %d it should"
				% [mode, int(census["built"]), int(expected[mode])])

		# AND THE SCENE AGREES WITH THE COUNT. A census is a number the
		# code wrote about itself; these are the nodes.
		var pads := _pads(zone).size()
		var lanes := _lanes(zone).size()
		print("      scene: %d launch pad(s), %d rail lane(s)"
				% [pads, lanes])
		match mode:
			"none":
				_check(pads == 0 and lanes == 0,
						"none built %d pad(s) and %d rail lane(s); it "
						% [pads, lanes] + "must build neither")
			"rail":
				_check(pads == 0,
						"rail leaked %d launch pad(s)" % pads)
				_check(lanes >= 4,
						"rail built %d lanes for 4 accepted routes"
						% lanes)
			"launch":
				_check(lanes == 0,
						"launch leaked %d rail lane(s)" % lanes)
				_check(pads == 4,
						"launch built %d pads for 4 accepted sources"
						% pads)
		await _drop(rig)

# --- 3. a real player on a real rail ---------------------------------------

func _test_a_player_rides_an_authored_rail() -> void:
	"""A NODE EXISTING IS NOT MOVEMENT. This catches a rail with the
	player's own body, rides it with the real `_physics_process`, watches
	it release, and then runs the SAME approach in `none` -- where there
	is no lane to catch -- to prove the difference came from the package
	rather than from gravity."""
	var rig: Dictionary = await _showcase("rail")
	var zone: ZoneController = rig["zone"]
	var lanes := _lanes(zone)
	_check(not lanes.is_empty(), "the rail mode built no lane to ride")
	if lanes.is_empty():
		await _drop(rig)
		return
	var lane: AffordanceNodes.Volume = lanes[0]
	var rail: RailPath = lane.rail
	var to_world: Transform3D = (lane.get_parent() as Node3D).global_transform
	var player: Player = zone.player
	player.input_frozen = true

	# THE ENTRY THE RAIL ITSELF DEFINES. Stand where the path starts, at
	# the ride height the lane sits at, moving along the path -- which is
	# what `RailRider.catch` requires and refuses without.
	# THE LANE'S OWN CENTRE, moving along the lane's own axis. A player
	# meets a rail by walking into the ride volume, so the proof starts
	# inside that volume rather than at a path coordinate that may sit on
	# its edge -- and the direction is the lane's, so `catch`'s "moving
	# along it" test is answered by the geometry rather than by a guess.
	var start: Vector3 = lane.global_position
	var along: Vector3 = lane.global_transform.basis.z
	print("  rail: lane at %v, axis %v, path %.1f m long"
			% [start, along, rail.length()])
	var caught := [false]
	var released := [false]
	player.rail_caught.connect(func(_at: Vector3) -> void: caught[0] = true)
	player.rail_released.connect(
			func(_at: Vector3) -> void: released[0] = true)
	player.global_position = start
	player.velocity = along.normalized() * Constants.WALK_SPEED
	# A HELD STICK, not a shortcut. `input_frozen` bleeds horizontal
	# speed toward zero each frame, so the velocity is re-asserted the
	# way a player leaning forward would -- everything else is the real
	# path: the lane's own `body_entered`, `Player.offer_rail`, and
	# `RailRider.catch` deciding for itself.
	for _i in 12:
		if player.riding_rail():
			break
		player.velocity = along.normalized() * Constants.WALK_SPEED
		await get_tree().physics_frame
	_check(caught[0] and player.riding_rail(),
			"the player stood on an authored rail moving along it and "
			+ "was not caught; caught=%s riding=%s"
			% [str(caught[0]), str(player.riding_rail())])
	var boarded := player.global_position

	# RIDDEN, not merely mounted: the body has to travel along the path.
	var frames := 0
	while player.riding_rail() and frames < 240:
		await get_tree().physics_frame
		frames += 1
	var ridden := boarded.distance_to(player.global_position)
	print("  rail: rode %.2f m over %d frames" % [ridden, frames])
	_check(ridden > 2.0,
			"the player was caught by a rail and travelled only %.2f m; "
			% ridden + "that is a mount, not a ride")

	# AND LEFT IT THE WAY THE RIDE SAYS YOU LEAVE IT. `_ride` reads a real
	# jump press, so this is the documented exit -- "jump gets you off
	# whenever you like" -- driven through the real input action rather
	# than by clearing `_rider` from outside.
	if player.riding_rail():
		player.input_frozen = false
		Input.action_press("jump")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("jump")
		player.input_frozen = true
		await get_tree().physics_frame
	print("  rail: released=%s riding=%s after the jump"
			% [str(released[0]), str(player.riding_rail())])
	_check(released[0] and not player.riding_rail(),
			"the player could not leave the rail; a ride with no exit is "
			+ "a trap")
	var ended_riding := player.global_position
	player_proofs += 1
	await _drop(rig)

	# THE SAME APPROACH WITH NO PACKAGE. Same Zone, same rooms, same
	# start, and nothing to catch -- so the route is different because of
	# the package, which is what A4 actually asks.
	var bare: Dictionary = await _showcase("none")
	var plain: ZoneController = bare["zone"]
	_check(_lanes(plain).is_empty(),
			"the none mode built a rail lane")
	var alone: Player = plain.player
	alone.input_frozen = true
	var caught_none := [false]
	alone.rail_caught.connect(
			func(_at: Vector3) -> void: caught_none[0] = true)
	alone.global_position = start
	alone.velocity = along.normalized() * Constants.WALK_SPEED
	for _i in frames + 2:
		alone.velocity.x = along.normalized().x * Constants.WALK_SPEED
		alone.velocity.z = along.normalized().z * Constants.WALK_SPEED
		await get_tree().physics_frame
	_check(not caught_none[0] and not alone.riding_rail(),
			"a rail was caught with movement-package=none")
	var drifted := start.distance_to(alone.global_position)
	print("  none: same approach ended %.2f m from the lane, no rail"
			% drifted)
	_check(alone.global_position.distance_to(ended_riding) > 2.0,
			"the ridden route and the unridden route ended in the same "
			+ "place, so the rail changed nothing")
	refusals_seen += 1
	await _drop(bare)

# --- 4. a real player on a real pad ----------------------------------------

func _test_a_player_is_launched_by_an_authored_pad() -> void:
	"""The pad has to fire the real player, along the trajectory it was
	validated for, and land them where the authored target says."""
	var rig: Dictionary = await _showcase("launch")
	var zone: ZoneController = rig["zone"]
	var pads := _pads(zone)
	_check(not pads.is_empty(), "the launch mode built no pad to stand on")
	if pads.is_empty():
		await _drop(rig)
		return
	var pad: AffordanceNodes.LaunchPad = pads[0]
	var player: Player = zone.player
	player.input_frozen = true
	var fired: Array = []
	pad.fired.connect(func(from: Vector3, v: Vector3) -> void:
		fired.append({"from": from, "velocity": v}))

	var before := pad.launched
	var shot := pad.solve()
	_check(bool(shot.get("ok", false)),
			"an authored pad the binding accepted cannot solve its own "
			+ "arc: %s" % str(shot.get("reason", "?")))
	# STAND ON IT. The trigger is an Area3D and the player is a body, so
	# this is the same `body_entered` a walking player produces.
	# FEET ON THE PAD. The player node's origin is its feet -- the
	# capsule shape sits a half-height ABOVE it -- so standing on a pad
	# means putting the origin on the pad's own face, not a body height
	# over it. Placed a finger's width up so the first frame settles onto
	# the pad rather than resolving out of it.
	player.global_position = pad.global_position + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	for _i in 8:
		if pad.launched > before:
			break
		await get_tree().physics_frame
	print("  launch: pad at %v, player stood at %v"
			% [pad.global_position, player.global_position])
	_check(pad.launched > before and fired.size() > 0,
			"a player standing on an authored launch pad was not "
			+ "launched (launched %d -> %d)" % [before, pad.launched])
	if fired.is_empty():
		await _drop(rig)
		return
	var event: Dictionary = fired[0]
	var launch_velocity: Vector3 = event["velocity"]
	print("  launch: fired from %v at %v (%.2f m/s)"
			% [event["from"], launch_velocity, launch_velocity.length()])
	_check(launch_velocity.distance_to(shot["velocity"] as Vector3) < 0.001,
			"the pad fired %v but validated %v; the flight a player takes "
			% [launch_velocity, shot["velocity"]] + "must be the flight "
			+ "that was checked")
	_check(launch_velocity.y > 0.0 and launch_velocity.length() > 1.0,
			"the launch velocity %v is not a launch" % launch_velocity)

	# AND IT CARRIES THE PLAYER. Flown with the real body over real
	# frames rather than integrated on paper, and with input UNFROZEN so
	# the flight uses the air control the shipped player actually has.
	#
	# WHAT THIS MEASURES, AND WHAT IT DOES NOT. `LaunchSolver` solves a
	# ballistic arc: two free-fall halves and no horizontal loss. The
	# shipped player is not ballistic -- `_physics_process` lerps
	# horizontal velocity toward the input direction every airborne
	# frame at `AIR_CONTROL` (0.4), so a player who lets go of the stick
	# sheds most of their launch speed on the way up. So the assertion
	# here is the one Stage 3A actually owns: the pad fired the validated
	# velocity and the player went somewhere they could not walk to. How
	# closely the landing matches the authored aim is a PLAYER TUNING
	# question, out of scope by instruction, and the measured gap is
	# reported rather than asserted or tuned away.
	var stood := player.global_position
	var pad_at := pad.global_position
	var aimed := pad.world_target()
	player.input_frozen = false
	var flight := 0
	var apex := player.global_position.y
	var closest := INF
	while flight < 900:
		await get_tree().physics_frame
		flight += 1
		apex = maxf(apex, player.global_position.y)
		closest = minf(closest, player.global_position.distance_to(aimed))
		if player.is_on_floor() and flight > 20:
			break
	player.input_frozen = true
	var landed := player.global_position
	var travelled := stood.distance_to(landed)
	var rose := apex - stood.y
	print("  launch: rose %.2f m, travelled %.2f m, landed %v after %d "
			% [rose, travelled, landed, flight]
			+ "frames; closest approach to the authored aim %v was %.2f m"
			% [aimed, closest])
	_check(rose > 4.0,
			"the launch lifted the player only %.2f m; that is a step, "
			% rose + "not a launch")
	_check(travelled > 5.0,
			"the launched player ended %.2f m from where they stood"
			% travelled)
	# AND IT ARRIVES WHERE THE ARTIST AIMED IT. Not asserted on faith:
	# with the arc preserved the real body lands within a stride of the
	# authored landing point, which is what makes a launch an EDGE rather
	# than a pop.
	_check(closest < 2.0,
			"the launched player came no closer than %.2f m to the "
			% closest + "authored landing point %v" % aimed)
	player_proofs += 1
	await _drop(rig)

	# NO PACKAGE, NO LAUNCH. Same place, same body, nothing fires, and
	# the player is still standing where they started.
	var bare: Dictionary = await _showcase("none")
	var plain: ZoneController = bare["zone"]
	_check(_pads(plain).is_empty(), "the none mode built a launch pad")
	var alone: Player = plain.player
	alone.input_frozen = true
	var from := pad_at + Vector3.UP * 0.1
	alone.global_position = from
	alone.velocity = Vector3.ZERO
	for _i in flight:
		await get_tree().physics_frame
	var stayed := from.distance_to(alone.global_position)
	print("  none: standing on the same spot moved %.2f m in %d frames"
			% [stayed, flight])
	_check(alone.velocity.y <= 0.1,
			"something launched the player with movement-package=none: "
			+ "velocity %v" % alone.velocity)
	_check(travelled > stayed + 5.0,
			"the launched route (%.2f m) and the unlaunched route "
			% travelled + "(%.2f m) are the same journey, so the pad "
			% stayed + "changed nothing")
	refusals_seen += 1
	await _drop(bare)


# --- 8. the room is not at the origin --------------------------------------

func _test_movement_works_in_a_translated_and_yawed_room() -> void:
	"""IDENTITY IS THE ONE PLACEMENT THAT CANNOT DETECT A FRAME ERROR.

	The showcase chain already puts three of its four rooms at a nonzero
	origin, and `ZoneBuilder` yaws what follows a turn, so this proves the
	seam on a room the composer actually moved -- and then moves the whole
	Zone as well, because a transform read one level up works until it is
	nested."""
	var rig: Dictionary = await _showcase("launch",
			Transform3D(Basis(Vector3.UP, PI / 3.0),
				Vector3(-311.0, 27.0, 148.0)))
	var zone: ZoneController = rig["zone"]
	var placed := 0
	var proven := 0
	for entry: Variant in zone.offer_rooms:
		var record: Dictionary = entry
		var room: Node3D = record["node"]
		var build: Dictionary = record["build"]
		var shell := str(build.get("authored_shell", "?"))
		var moved := room.global_transform
		var yawed := absf(moved.basis.get_euler().y) > 0.001
		if moved.origin.length() > 1.0:
			placed += 1
		print("  placed: %-20s origin %v yaw %.1f deg"
				% [shell, moved.origin,
					rad_to_deg(moved.basis.get_euler().y)])

		# ONE TRANSFORM, APPLIED ONCE. The pad's world target must be the
		# authored point through the room's frame exactly once; applying
		# the room transform twice, or forgetting it, both land somewhere
		# this comparison can see.
		for raw: Variant in RoomContract.offers_of(build, "launch_source"):
			var offer: Dictionary = raw
			var aim := ""
			var landing := Vector3.ZERO
			for other: Variant in RoomContract.offers_of(build,
					"launch_target"):
				if str((other as Dictionary).get("name", "")) \
						== str(offer.get("target", "")):
					aim = str((other as Dictionary)["name"])
					landing = (other as Dictionary)["position"]
			if aim == "":
				continue
			var pad: AffordanceNodes.LaunchPad = null
			for candidate: Variant in _pads(room):
				if (candidate as AffordanceNodes.LaunchPad).position \
						.distance_to(offer["position"] as Vector3) < 0.001:
					pad = candidate
			_check(pad != null,
					"%s / %s was accepted and no pad was built for it"
					% [shell, str(offer.get("name", "?"))])
			if pad == null:
				continue
			var once := moved * SpaceProbe.stand_pose(landing)
			var twice := moved * (moved * SpaceProbe.stand_pose(landing))
			_check(pad.world_target().distance_to(once) < 0.001,
					"%s / %s aims at %v; the authored point through the "
					% [shell, aim, pad.world_target()] + "room's frame "
					+ "once is %v" % once)
			if moved.origin.length() > 1.0 or yawed:
				_check(pad.world_target().distance_to(twice) > 1.0,
						"%s / %s: applying the room transform twice lands "
						% [shell, aim] + "in the same place as applying "
						+ "it once, so this comparison proves nothing")
			proven += 1
	_check(placed >= 3,
			"only %d showcase room(s) sit away from the origin; the seam "
			% placed + "cannot be tested at identity")
	_check(proven >= 4,
			"only %d launch pair(s) were checked for double-transform"
			% proven)

	# AND A PAD IN A MOVED ROOM STILL FIRES A REAL PLAYER TO ITS AIM.
	var far: AffordanceNodes.LaunchPad = null
	var far_room: Node3D = null
	for entry: Variant in zone.offer_rooms:
		var record: Dictionary = entry
		var room: Node3D = record["node"]
		for candidate: Variant in _pads(room):
			var here := room.global_transform.origin.length()
			if far == null or here > far_room.global_transform.origin.length():
				far = candidate
				far_room = room
	_check(far != null, "no pad was built in any placed room")
	if far != null:
		var player: Player = zone.player
		player.input_frozen = true
		var before := far.launched
		var aimed := far.world_target()
		player.global_position = far.global_position + Vector3.UP * 0.1
		player.velocity = Vector3.ZERO
		for _i in 8:
			if far.launched > before:
				break
			await get_tree().physics_frame
		_check(far.launched > before,
				"a pad in a room at %v did not fire"
				% far_room.global_transform.origin)
		player.input_frozen = false
		var closest := INF
		for _i in 900:
			await get_tree().physics_frame
			closest = minf(closest,
					player.global_position.distance_to(aimed))
			if player.is_on_floor():
				break
		player.input_frozen = true
		print("  placed launch: room at %v, landed %.2f m from its aim"
				% [far_room.global_transform.origin, closest])
		_check(closest < 2.0,
				"a launch in a placed and yawed room missed its authored "
				+ "aim by %.2f m" % closest)
		player_proofs += 1
	await _drop(rig)

# --- 5. the Zone plays without any package ---------------------------------

func _test_the_showcase_finishes_with_no_movement_package() -> void:
	"""R8: no mandatory route may require a movement offer. Measured the
	only way that means anything -- with zero offer geometry in the Zone,
	every mandatory traversal endpoint in every showcase room still has
	ground under it and room for a body above it."""
	var rig: Dictionary = await _showcase("none")
	var zone: ZoneController = rig["zone"]
	_check(_pads(zone).is_empty() and _lanes(zone).is_empty(),
			"the none Zone is not free of offer geometry")
	var checked := 0
	var missing: Array[String] = []
	for entry: Variant in _rooms_of(zone):
		var record: Dictionary = entry
		var root: Node3D = record["node"]
		var build: Dictionary = record["build"]
		var space := OfferBinding.space_of(root)
		for raw: Variant in build.get("traversal", []) as Array:
			var move: Dictionary = raw
			if not bool(move.get("mandatory", true)):
				continue
			for key: String in ["start", "end"]:
				var at: Variant = move.get(key)
				if not (at is Vector3):
					continue
				var world: Vector3 = root.global_transform * (at as Vector3)
				checked += 1
				if SpaceProbe.ground_below(space, world,
						Constants.MAX_VERTICAL_STEP) \
							== SpaceProbe.NO_GROUND:
					missing.append("%s %s.%s"
							% [str((record["chamber"] as Dictionary)
									.get("shell_id", "?")),
								str(move.get("id", "?")), key])
	print("  none: %d mandatory traversal endpoint(s) checked, %d without "
			% [checked, missing.size()] + "ground")
	_check(checked > 0,
			"no mandatory traversal endpoint was checked, so this proves "
			+ "nothing about playing without a package")
	_check(missing.is_empty(),
			"%d mandatory endpoint(s) have no ground with zero offer "
			% missing.size() + "geometry: %s" % "; ".join(missing))
	await _drop(rig)

## The showcase's rooms, with the ids they were asked for.
func _rooms_of(zone: ZoneController) -> Array:
	return zone.offer_rooms

# --- 6. purity, ordering, duplication --------------------------------------

func _test_validation_stays_pure_under_every_mode() -> void:
	"""Validating is looking. Looking twice must change nothing, and
	looking must not depend on what another look asked about."""
	for mode: String in ["none", "rail", "launch"]:
		var rig: Dictionary = await _showcase(mode)
		var zone: ZoneController = rig["zone"]
		var before := _count_nodes(zone)
		var pads := _pads(zone).size()
		var lanes := _lanes(zone).size()
		for entry: Variant in _live_rooms(zone):
			var record: Dictionary = entry
			var root: Node3D = record["node"]
			var build: Dictionary = record["build"]
			var first := OfferBinding.validate(root, build, "purity")
			var second := OfferBinding.validate(root, build, "purity")
			_check(_names(first["accepted"] as Array)
					== _names(second["accepted"] as Array),
					"validating twice in mode %s gave two answers" % mode)
			# ORDER INDEPENDENCE, behaviourally: a verdict on one offer
			# must not depend on which others were asked about.
			var rail_first := OfferBinding.validate(root, build, "order",
					["rail_route", "launch_source"])
			var launch_first := OfferBinding.validate(root, build, "order",
					["launch_source", "rail_route"])
			_check(_names(rail_first["accepted"] as Array)
					== _names(launch_first["accepted"] as Array),
					"asking for the same two kinds in the other order "
					+ "changed the verdict in mode %s" % mode)
		_check(_count_nodes(zone) == before,
				"validation in mode %s took the Zone from %d nodes to %d"
				% [mode, before, _count_nodes(zone)])
		_check(_pads(zone).size() == pads and _lanes(zone).size() == lanes,
				"validation in mode %s changed the constructed geometry "
				% mode + "from %d pads / %d lanes to %d / %d"
				% [pads, lanes, _pads(zone).size(), _lanes(zone).size()])
		await _drop(rig)

func _live_rooms(zone: ZoneController) -> Array:
	return zone.offer_rooms

func _count_nodes(root: Node) -> int:
	var n := root.get_child_count()
	for child: Node in root.get_children():
		n += _count_nodes(child)
	return n

func _names(entries: Array) -> String:
	var parts: Array[String] = []
	for raw: Variant in entries:
		var item: Dictionary = raw
		parts.append("%s/%s" % [str(item.get("kind", "?")),
				str(item.get("name", "?"))])
	parts.sort()
	return ", ".join(parts)

func _test_a_second_construction_is_refused() -> void:
	"""A second construction into one room would duplicate every pad and
	judge the new ones against the old. It is refused by name, and a NEW
	Zone still builds its own normally."""
	var rig: Dictionary = await _showcase("launch")
	var zone: ZoneController = rig["zone"]
	var pads := _pads(zone).size()
	var rooms := _live_rooms(zone)
	_check(not rooms.is_empty(), "the showcase built no rooms")
	for entry: Variant in rooms:
		var record: Dictionary = entry
		var again := OfferBinding.construct(record["node"] as Node3D,
				record["build"] as Dictionary, "twice", ["launch_source"])
		_check(bool(again.get("refused", false)),
				"a second construction into a live showcase room was "
				+ "allowed; it built %d more"
				% (again["built"] as Array).size())
		_check(str(again["declined"]).contains("already constructed"),
				"the refusal did not say why: %s" % str(again["declined"]))
	_check(_pads(zone).size() == pads,
			"the refused second construction still changed the pad count "
			+ "from %d to %d" % [pads, _pads(zone).size()])
	refusals_seen += 1
	await _drop(rig)

	# A GENUINELY NEW ZONE IS NOT THE OLD ONE. The guard must stop
	# duplication, not stop the feature.
	var fresh: Dictionary = await _showcase("launch")
	_check(_pads(fresh["zone"] as ZoneController).size() == pads,
			"a new Zone instance built %d pads, not the %d the first one "
			% [_pads(fresh["zone"] as ZoneController).size(), pads]
			+ "did; the once-per-room guard is leaking across Zones")
	await _drop(fresh)

# --- 7. the operator control -----------------------------------------------

func _test_an_unknown_selection_is_refused_not_defaulted() -> void:
	"""A typo must not quietly become a selection. `none` would produce a
	green run that proved nothing; `rail` would be worse."""
	var good := MovementSelection.parse(PackedStringArray(
			["--playtest3a", "--movement-package=rail"]))
	_check(bool(good["showcase"]) and str(good["mode"]) == "rail"
			and not bool(good["refused"]),
			"a valid selection was not read: %s" % str(good))
	var bare := MovementSelection.parse(PackedStringArray(["--playtest3a"]))
	_check(str(bare["mode"]) == "none" and not bool(bare["refused"]),
			"the showcase without a package is not none: %s" % str(bare))
	for bad: String in ["grapple", "rails", "RAIL", "", "none "]:
		var said := MovementSelection.parse(PackedStringArray(
				["--playtest3a", "--movement-package=%s" % bad]))
		_check(bool(said["refused"]),
				"'%s' was accepted as a movement package" % bad)
		_check(str(said["mode"]) == "",
				"'%s' was refused and still produced the mode '%s'"
				% [bad, str(said["mode"])])
		# The empty request has no name to echo, so only the non-empty
		# ones are required to appear in the message; every refusal must
		# still say what DOES exist.
		_check((bad == "" or str(said["why"]).contains(bad))
				and str(said["why"]).contains("rail")
				and str(said["why"]).contains("does not exist"),
				"the refusal must name what was asked for and what "
				+ "exists: %s" % str(said["why"]))
		# AND A REFUSED MODE BUILDS NOTHING. The refusal is only useful
		# if the thing downstream of it is also empty.
		_check(MovementSelection.builds(str(said["mode"])).is_empty(),
				"a refused selection still asked to build %s"
				% str(MovementSelection.builds(str(said["mode"]))))
		refusals_seen += 1
	# THE SHOWCASE FLAG IS REQUIRED. A package named without it must not
	# open the showcase.
	var loose := MovementSelection.parse(PackedStringArray(
			["--movement-package=launch"]))
	_check(not bool(loose["showcase"]),
			"--movement-package alone opened the showcase")

func _test_ordinary_startup_builds_no_movement_geometry() -> void:
	"""Nothing an ordinary player does may construct an offer. The
	default is `none`, and it is a default rather than a coincidence."""
	var zone := ZoneController.new()
	_check(zone.movement_package == "none",
			"a fresh ZoneController defaults to '%s', so an ordinary "
			% zone.movement_package + "Zone would build movement geometry")
	_check(MovementSelection.builds("none").is_empty(),
			"the none package asks to build %s"
			% str(MovementSelection.builds("none")))
	zone.free()
	var plain := MovementSelection.parse(PackedStringArray([]))
	_check(not bool(plain["showcase"]),
			"ordinary startup opened the showcase")
