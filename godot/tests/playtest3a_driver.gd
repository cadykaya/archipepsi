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
	await _test_selection_is_an_identity_and_survives_every_ordering()
	await _test_a_launch_is_carried_and_steered_and_neither_is_the_other()
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
		# SELECTED SITS BETWEEN ACCEPTED AND BUILT, and is its own fact:
		# `none` chooses nothing from twenty accepted offers, and the
		# other two choose four apiece and build exactly those.
		_check(int(census["selected"]) == int(expected[mode]),
				"mode %s selected %d offers and built %d"
				% [mode, int(census["selected"]), int(census["built"])])
		_check(int(census["selected"]) <= int(census["accepted"]),
				"mode %s selected %d of %d accepted offers"
				% [mode, int(census["selected"]), int(census["accepted"])])
		# EVERY ROOM WAS JUDGED BEFORE THE FIRST NODE WAS BUILT. Measured
		# by the runtime rather than asserted about its source: in a
		# per-room validate-then-construct lifecycle this is 1.
		_check(int(census["judged_before_first_build"]) == 4,
				"only %d room(s) had a verdict before the first "
				% int(census["judged_before_first_build"])
				+ "construction in mode %s; validation must finish for "
				% mode + "the whole Zone before anything is built")

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

# --- selection: an identity, not a filter (owner ruling, 2026-09-09) -------

## The showcase Zone with its rooms in the opposite order.
func _reversed_showcase() -> Dictionary:
	var zone := ShowcaseZone.build()
	var rooms: Array = (zone["chambers"] as Array).duplicate()
	rooms.reverse()
	zone["chambers"] = rooms
	return zone

## Every selected identity, as one sorted comparable string.
func _identities(selection: Array) -> String:
	var parts: Array[String] = []
	for raw: Variant in selection:
		parts.append(MovementSelection.key_of(raw as Dictionary))
	parts.sort()
	return " ; ".join(parts)

func _test_selection_is_an_identity_and_survives_every_ordering() -> void:
	"""SELECTED IS ITS OWN FACT, between accepted and built.

	Construction once took a KIND, so "build what was chosen" and "build
	everything that matches" were the same call and no test could tell
	them apart. The selector now names offers one at a time, and what is
	proven here is that the names do not move: not when the rooms are
	placed in the opposite order, not when the manifest lists offers
	backwards, not when a Dictionary or the physics server answers in
	whatever order it likes."""
	var rig: Dictionary = await _showcase("rail")
	var zone: ZoneController = rig["zone"]
	var chosen := _identities(zone.offer_selection)
	print("  selection rail: %s" % chosen)
	_check(zone.offer_selection.size() == 4,
			"rail selected %d offers, not the 4 the four rooms carry"
			% zone.offer_selection.size())
	# 4 -- KIND ISOLATION IS A PROPERTY OF THE SELECTION, not only of the
	# nodes that came out of it.
	for raw: Variant in zone.offer_selection:
		_check(str((raw as Dictionary)["kind"]) == "rail_route",
				"rail selected a %s" % str((raw as Dictionary)["kind"]))

	# 8 -- VALIDATION IS THE SAME BEFORE AND AFTER SELECTING. Selection
	# builds nothing, so a verdict taken after it must match one taken
	# before it.
	for entry: Variant in zone.offer_rooms:
		var record: Dictionary = entry
		var root: Node3D = record["node"]
		var build: Dictionary = record["build"]
		var before := OfferBinding.validate(root, build, "before")
		var again := MovementSelection.select("rail",
				[{"chamber": "x", "accepted": before["accepted"]}])
		var after := OfferBinding.validate(root, build, "after")
		_check(_names(before["accepted"] as Array)
				== _names(after["accepted"] as Array),
				"selecting changed a room's verdict from [%s] to [%s]"
				% [_names(before["accepted"] as Array),
					_names(after["accepted"] as Array)])
		# 6 -- PURE AND REPEATABLE.
		var twice := MovementSelection.select("rail",
				[{"chamber": "x", "accepted": before["accepted"]}])
		_check(_identities(again) == _identities(twice),
				"selecting twice from one verdict gave [%s] then [%s]"
				% [_identities(again), _identities(twice)])

		# 2/3 -- THE MANIFEST'S ORDER, AND ANY OTHER ORDER. The offers
		# array is reversed and the accepted array shuffled; the real
		# validator measures the real room either way.
		var flipped: Dictionary = build.duplicate()
		var backwards: Array = (build.get("offers", []) as Array).duplicate()
		backwards.reverse()
		flipped["offers"] = backwards
		var reversed_verdict := OfferBinding.validate(root, flipped, "rev")
		var jumbled: Array = (reversed_verdict["accepted"] as Array) \
				.duplicate()
		jumbled.reverse()
		var from_reversed := MovementSelection.select("rail",
				[{"chamber": "x", "accepted": jumbled}])
		_check(_identities(again) == _identities(from_reversed),
				"reversing the manifest offers and the verdict order "
				+ "changed the selection from [%s] to [%s]"
				% [_identities(again), _identities(from_reversed)])
	await _drop(rig)

	# 1 -- THE ROOM ARRAY, REVERSED, through the whole live runtime.
	var host := Node3D.new()
	add_child(host)
	var flipped_zone := ZoneController.new()
	flipped_zone.movement_package = "rail"
	host.add_child(flipped_zone)
	flipped_zone.setup(_reversed_showcase())
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	zones_built += 1
	var flipped_ids := _identities(flipped_zone.offer_selection)
	print("  selection rail, rooms reversed: %s" % flipped_ids)
	_check(flipped_ids == chosen,
			"reversing the room array changed the selection:\n    [%s]\n"
			% chosen + "    [%s]" % flipped_ids)
	_check(int(flipped_zone.offer_census["built"]) == 4,
			"the reversed Zone built %d nodes, not 4"
			% int(flipped_zone.offer_census["built"]))
	host.queue_free()
	await get_tree().process_frame

	# 4 -- THE OTHER TWO MODES.
	var launch_rig: Dictionary = await _showcase("launch")
	var launch_zone: ZoneController = launch_rig["zone"]
	print("  selection launch: %s" % _identities(launch_zone.offer_selection))
	for raw: Variant in launch_zone.offer_selection:
		_check(str((raw as Dictionary)["kind"]) == "launch_source",
				"launch selected a %s" % str((raw as Dictionary)["kind"]))
	await _drop(launch_rig)
	var quiet_rig: Dictionary = await _showcase("none")
	var quiet_zone: ZoneController = quiet_rig["zone"]
	_check(quiet_zone.offer_selection.is_empty(),
			"none selected %d offer(s)" % quiet_zone.offer_selection.size())
	_check(int(quiet_zone.offer_census["selected"]) == 0
			and int(quiet_zone.offer_census["built"]) == 0,
			"none selected %d and built %d"
			% [int(quiet_zone.offer_census["selected"]),
				int(quiet_zone.offer_census["built"])])

	# 5/7 -- ACCEPTED IS NOT SELECTED, AND SELECTED IS NOT A FILTER.
	# The `none` Zone has built nothing, so its rooms can be constructed
	# into here -- with a deliberately SHORT list. If construction were
	# still filtering by kind it would build the room's rail and launch
	# regardless of what it was handed.
	var probed := 0
	for entry: Variant in quiet_zone.offer_rooms:
		var record: Dictionary = entry
		var root: Node3D = record["node"]
		var build: Dictionary = record["build"]
		var seen := OfferBinding.validate(root, build, "exact")
		var grapples := 0
		var names: Array = []
		for raw: Variant in seen["accepted"] as Array:
			var offer: Dictionary = raw
			names.append(str(offer["name"]))
			if str(offer["kind"]) == "grapple_point":
				grapples += 1
		_check(grapples == 3,
				"a showcase room accepted %d grapple points, not 3"
				% grapples)
		# NOTHING SELECTED: nothing built, and the accepted grapples in
		# particular construct no node.
		var before_nodes := _count_nodes(root)
		var nothing := OfferBinding.construct_selected(root,
				seen["accepted"] as Array, [], "exact")
		_check((nothing["built"] as Array).is_empty()
				and _count_nodes(root) == before_nodes,
				"an empty selection built %d node(s)"
				% (_count_nodes(root) - before_nodes))
		probed += 1
	print("  exact selection: %d room(s) built nothing from an empty "
			% probed + "selection; 12 accepted grapple points across the "
			+ "Zone construct zero nodes")
	_check(probed == 4, "only %d rooms were probed" % probed)
	_check(_pads(quiet_zone).is_empty() and _lanes(quiet_zone).is_empty(),
			"the none Zone gained offer geometry")
	await _drop(quiet_rig)

	# 7 again, on a fresh Zone: ONE name in, exactly that one out.
	var one_rig: Dictionary = await _showcase("none")
	var one_zone: ZoneController = one_rig["zone"]
	var single := 0
	for entry: Variant in one_zone.offer_rooms:
		var record: Dictionary = entry
		var root: Node3D = record["node"]
		var seen := OfferBinding.validate(root,
				record["build"] as Dictionary, "one")
		var pick := ""
		for raw: Variant in seen["accepted"] as Array:
			if str((raw as Dictionary)["kind"]) == "rail_route":
				pick = str((raw as Dictionary)["name"])
		if pick == "":
			continue
		var made := OfferBinding.construct_selected(root,
				seen["accepted"] as Array, [pick], "one")
		_check((made["built"] as Array).size() == 1
				and str((made["built"] as Array)[0]["name"]) == pick,
				"a selection of one built %d offer(s): %s"
				% [(made["built"] as Array).size(), str(made["built"])])
		_check(_pads(root).is_empty(),
				"a selection naming only a rail built a launch pad")
		single += 1
	_check(single == 4,
			"only %d room(s) proved the one-name selection" % single)
	await _drop(one_rig)

# --- the amendment: a launch is carried, and steered, and neither is the
#     other (owner ruling, 2026-09-09) ---------------------------------------

## Stand a player on a pad and let it fire.
##
## Returns the pad, the carrier it was fired with, and the aim -- the
## three things every proof below compares against.
func _fire(zone: ZoneController, pad: AffordanceNodes.LaunchPad) -> Dictionary:
	var player: Player = zone.player
	player.input_frozen = true
	var before := pad.launched
	player.global_position = pad.global_position + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	for _i in 8:
		if pad.launched > before:
			break
		await get_tree().physics_frame
	return {"fired": pad.launched > before, "carrier": player.launch_carrier(),
			"aim": pad.world_target(), "from": pad.global_position}

## Hold a direction, in the player's own frame, for the whole flight.
##
## THE REAL INPUT PATH. `_physics_process` reads `Input.get_vector`, so
## the correction under test is the one a hand on a stick produces --
## not a velocity poked in from the side. The player is yawed so that the
## pressed action points where the proof needs it to.
## `track` is an axis to watch WHILE THE ARC LASTS: the returned
## `min_along` is the least displacement along it seen at any moment the
## player was still in launch flight. Measured in flight only, because
## once the arc ends ordinary movement resumes and a held direction
## simply walks -- which is correct, and is not the launch reversing.
func _fly_holding(player: Player, action: String, face: Vector3,
		budget := 900, track := Vector3.ZERO,
		aim := Vector3.INF) -> Dictionary:
	player.input_frozen = false
	if face.length() > 0.001:
		# A Y-rotation by t puts basis.x at (cos t, 0, -sin t), and
		# `move_right` pushes along basis.x.
		player.rotation.y = atan2(-face.z, face.x)
	if action != "":
		Input.action_press(action)
	var frames := 0
	var carrier_drift := 0.0
	var start := player.launch_carrier()
	var from := player.global_position
	var axis := track.normalized() if track.length() > 0.001 \
			else Vector3.ZERO
	var min_along := 0.0
	# THE CARRIER'S APPLIED CONTRIBUTION, sampled every frame of the arc.
	# `worst_axial` is the least the velocity ACTUALLY APPLIED to the body
	# ever contributed along the authored axis, minus what the carrier
	# alone contributes: negative means something ate into the carrier.
	var worst_axial := INF
	var arc_along := 0.0
	var arc_end := player.global_position
	var closest := INF
	while frames < budget:
		await get_tree().physics_frame
		frames += 1
		carrier_drift = maxf(carrier_drift,
				start.distance_to(player.launch_carrier()))
		if player.in_launch_flight():
			worst_axial = minf(worst_axial, player.launch_axis_speed()
					- player.launch_carrier_axis_speed())
		if aim != Vector3.INF:
			closest = minf(closest,
					player.global_position.distance_to(aim))
		if axis != Vector3.ZERO and player.in_launch_flight():
			min_along = minf(min_along,
					(player.global_position - from).dot(axis))
			# THE ARC'S OWN PROGRESS, taken on the last frame the arc was
			# still running. Measuring at the loop's end would include
			# whatever ordinary walking the held direction did after
			# landing -- which is correct behaviour and is not the
			# launch.
			arc_along = (player.global_position - from).dot(axis)
			arc_end = player.global_position
		if player.is_on_floor() and frames > 20:
			# ONE MORE FRAME. `is_on_floor()` is set by `move_and_slide`
			# at the END of a physics tick, so the tick that notices the
			# landing has already returned -- the tick that ENDS the arc
			# is the next one.
			await get_tree().physics_frame
			break
	if action != "":
		Input.action_release(action)
	player.input_frozen = true
	return {"landed": player.global_position, "frames": frames,
			"carrier_drift": carrier_drift, "min_along": min_along,
			"worst_axial": (0.0 if worst_axial == INF else worst_axial),
			"arc_along": arc_along, "arc_end": arc_end,
			"closest": (0.0 if closest == INF else closest),
			"travel": from.distance_to(player.global_position)}

func _test_a_launch_is_carried_and_steered_and_neither_is_the_other() -> void:
	"""THE OWNER RULING: protect the launch, do not lock the player.

	Three behaviours, proven apart. The carrier is the validated
	ballistic motion and nothing airborne may erode it. The correction is
	a modest layer on top that may bend the arc. Ordinary movement is
	what happens when neither applies, and it is unchanged."""
	var rig: Dictionary = await _showcase("launch")
	var zone: ZoneController = rig["zone"]
	var pads := _pads(zone)
	_check(not pads.is_empty(), "the launch mode built no pad")
	if pads.is_empty():
		await _drop(rig)
		return
	var pad: AffordanceNodes.LaunchPad = pads[0]
	var player: Player = zone.player

	# 1 -- NO INPUT. The solver's own arc, landing where it was aimed.
	var shot: Dictionary = await _fire(zone, pad)
	_check(bool(shot["fired"]), "the pad did not fire")
	var carrier: Vector3 = shot["carrier"]
	var aim: Vector3 = shot["aim"]
	var origin: Vector3 = shot["from"]
	_check(carrier.length() > 1.0,
			"the protected carrier is %v, which is not a launch" % carrier)
	var quiet: Dictionary = await _fly_holding(player, "", Vector3.ZERO,
			900, Vector3.ZERO, aim)
	var quiet_miss: float = (quiet["landed"] as Vector3).distance_to(aim)
	# TWO MEASUREMENTS, REPORTED AS TWO. `closest` is the nearest the arc
	# ever comes to the authored aim; `landed` is where the body finally
	# stops. They are different numbers about different moments and one
	# has been mistaken for the other before.
	var quiet_closest: float = float(quiet["closest"])
	print("  amend: no input -> closest approach %.2f m, LANDED %.2f m "
			% [quiet_closest, quiet_miss] + "from the authored aim; "
			+ "carrier %v drifted %.4f m/s"
			% [carrier, quiet["carrier_drift"]])
	_check(quiet_miss < 2.0,
			"with no input the launch landed %.2f m from its authored aim"
			% quiet_miss)
	# AND THE LANDING IS A PLACE A PLAYER CAN BE, not merely a number
	# near the aim. Ground under the feet, and the capsule fits.
	var space := OfferBinding.space_of(zone)
	var floor_y := SpaceProbe.ground_below(space,
			(quiet["landed"] as Vector3) + Vector3.UP * 0.2, 1.0)
	var blocker := SpaceProbe.obstruction(space,
			SpaceProbe.stand_pose(quiet["landed"] as Vector3))
	print("  amend: landing support -> ground %s, capsule %s"
			% [("none" if floor_y == SpaceProbe.NO_GROUND
					else "at y=%.3f" % floor_y),
				("clear" if blocker == null else "inside %s" % blocker.name)])
	_check(floor_y != SpaceProbe.NO_GROUND,
			"the launched player came to rest at %v with no ground under "
			% (quiet["landed"] as Vector3) + "them")
	_check(blocker == null,
			"the launched player came to rest inside %s"
			% ("nothing" if blocker == null else blocker.name))
	# 4 -- THE CARRIER IS NOT INTERPOLATED. Sampled every frame of the
	# flight: the ordinary air-control lerp would have eaten it.
	_check(float(quiet["carrier_drift"]) < 0.001,
			"the protected carrier moved %.4f m/s during the flight; "
			% float(quiet["carrier_drift"]) + "something is interpolating it")
	player_proofs += 1

	# 2 -- PERPENDICULAR INPUT BENDS IT. Same pad, same arc, one held
	# direction across the carrier.
	var lateral := Vector3(-carrier.z, 0.0, carrier.x).normalized()
	var again: Dictionary = await _fire(zone, pad)
	_check(bool(again["fired"]), "the pad did not fire a second time")
	var steered: Dictionary = await _fly_holding(player, "move_right",
			lateral)
	var bent := (steered["landed"] as Vector3) - (quiet["landed"] as Vector3)
	var sideways := absf(bent.dot(lateral))
	print("  amend: perpendicular input -> landed %v, %.2f m across the "
			% [steered["landed"], sideways] + "arc (%.2f m from the quiet "
			% (quiet["landed"] as Vector3).distance_to(
				steered["landed"] as Vector3) + "landing)")
	_check(sideways > 1.0,
			"holding a direction across the arc moved the landing %.2f m "
			% sideways + "sideways; the correction is not reaching the "
			+ "flight")
	_check(float(steered["carrier_drift"]) < 0.001,
			"steering changed the protected carrier by %.4f m/s"
			% float(steered["carrier_drift"]))
	player_proofs += 1

	# 3 -- OPPOSING INPUT CANNOT UNDO IT. Held directly back along the
	# authored direction for the whole flight.
	var backward := -Vector3(carrier.x, 0.0, carrier.z).normalized()
	var third: Dictionary = await _fire(zone, pad)
	_check(bool(third["fired"]), "the pad did not fire a third time")
	var fought: Dictionary = await _fly_holding(player, "move_right",
			backward)
	var landed: Vector3 = fought["landed"]
	var travelled := (landed - origin)
	var forward := Vector3(carrier.x, 0.0, carrier.z).normalized()
	var along := travelled.dot(forward)
	print("  amend: opposing input -> landed %v, %.2f m ALONG the "
			% [landed, along] + "authored direction, %.2f m from the pad"
			% Vector3(travelled.x, 0.0, travelled.z).length())
	_check(along > 0.0,
			"holding back reversed the launch: the player ended %.2f m "
			% along + "along the authored direction")
	_check(landed.distance_to(origin) > 3.0,
			"holding back returned the player to within %.2f m of the "
			% landed.distance_to(origin) + "pad they left")
	refusals_seen += 1

	# 6/7 -- THE STATE IS CLEAN AFTERWARDS, and a later launch is its own.
	_check(not player.in_launch_flight()
			and player.launch_carrier().length() < 0.001,
			"the launch state survived the landing: flight=%s carrier=%v"
			% [str(player.in_launch_flight()), player.launch_carrier()])
	var fourth: Dictionary = await _fire(zone, pad)
	_check((fourth["carrier"] as Vector3).distance_to(carrier) < 0.001,
			"a later launch began with carrier %v, not the %v this pad "
			% [fourth["carrier"], carrier] + "fires")
	# ... and a respawn, which is also the out-of-bounds recovery, clears
	# it mid-flight.
	player.take_damage(Constants.PLAYER_MAX_HP * 10.0)
	await get_tree().process_frame
	_check(not player.in_launch_flight(),
			"a killed player kept their launch flight")
	for _i in int(Constants.RESPAWN_DELAY * 70.0):
		await get_tree().physics_frame
	_check(not player.in_launch_flight()
			and player.launch_carrier().length() < 0.001,
			"a respawned player came back carrying a launch arc")
	# ... and so does entering a Zone.
	var fifth: Dictionary = await _fire(zone, pad)
	_check(bool(fifth["fired"]), "the pad stopped firing after a respawn")
	player.set_spawn(Transform3D(Basis(), Vector3(0, 1, 0)))
	_check(not player.in_launch_flight()
			and player.launch_carrier().length() < 0.001,
			"set_spawn left the launch state behind")
	await _drop(rig)

	# 5 -- ORDINARY JUMPING IS UNCHANGED. Not in a launch, the airborne
	# horizontal still decays toward the input the way it always did.
	var plain: Dictionary = await _showcase("none")
	var ground: ZoneController = plain["zone"]
	var walker: Player = ground.player
	walker.input_frozen = true
	_check(not walker.in_launch_flight(),
			"a player who has not been launched is in launch flight")
	walker.global_position = pad_free_air(ground)
	walker.velocity = Vector3(6.0, 6.0, 0.0)
	var before_speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	for _i in 20:
		await get_tree().physics_frame
	var after_speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	print("  amend: ordinary airborne horizontal %.2f -> %.2f m/s over 20 "
			% [before_speed, after_speed] + "frames (the lerp still runs)")
	_check(after_speed < before_speed * 0.5,
			"ordinary airborne horizontal went %.2f -> %.2f m/s; the "
			% [before_speed, after_speed] + "existing air control is no "
			+ "longer running for un-launched players")

	# 3-bis -- THE CARRIER MAY NOT BE CANCELLED, at the boundary where
	# that is load-bearing. On the hall pad the carrier is 7.06 m/s and
	# the correction is capped at 2.0, so "opposing input cannot undo the
	# launch" is arithmetic there. Where it is a guard is a carrier
	# SLOWER than the correction: a real player, a real launch state, a
	# deliberately slow 1.0 m/s arc, and a held direction straight back
	# down it. Run twice -- quiet, then fought -- because the proof is
	# that the two are the SAME.
	var slow: Player = ground.player
	var creep := Vector3(1.0, 0.0, 0.0)
	var quiet_slow: Dictionary = await _slow_arc(slow, ground, creep, "",
			Vector3.ZERO)
	var fought_slow: Dictionary = await _slow_arc(slow, ground, creep,
			"move_right", -creep.normalized())
	print("  amend: slow arc  no input -> %.3f m along, worst applied "
			% float(quiet_slow["along"])
			+ "axial %.4f m/s under the carrier"
			% float(quiet_slow["worst_axial"]))
	print("  amend: slow arc  full opposing input -> %.3f m along, worst "
			% float(fought_slow["along"])
			+ "applied axial %.4f m/s under the carrier"
			% float(fought_slow["worst_axial"]))
	_check(float(quiet_slow["along"]) > 0.5,
			"a 1.0 m/s carrier with no input travelled only %.3f m along "
			% float(quiet_slow["along"]) + "its authored direction")
	# NO CANCELLATION. Opposing input contributes no axial correction at
	# all, so the crossing is the same one.
	_check(absf(float(fought_slow["along"]) - float(quiet_slow["along"]))
				< 0.05,
			"holding directly backward changed the forward progress from "
			+ "%.3f m to %.3f m; opposing input must contribute no axial "
			% [float(quiet_slow["along"]), float(fought_slow["along"])]
			+ "correction at all")
	# NO REVERSAL, and the carrier's own contribution intact every frame.
	_check(float(fought_slow["min_along"]) >= -0.01,
			"holding back reversed the launch by %.4f m in flight"
			% -float(fought_slow["min_along"]))
	for label: String in ["quiet", "fought"]:
		var run: Dictionary = quiet_slow if label == "quiet" \
				else fought_slow
		_check(float(run["worst_axial"]) >= -0.001,
				"the applied velocity's authored-axis component fell "
				+ "%.4f m/s below the carrier's own during the %s run; "
				% [-float(run["worst_axial"]), label] + "a carrier that "
				+ "is stored and not applied is not preserved")
	refusals_seen += 1
	await _drop(plain)

## One deliberately slow authored-style arc, flown twice for comparison.
##
## The launch state is begun through the real `begin_launch_flight`, so
## the carrier is taken from the velocity exactly as a pad's would be.
func _slow_arc(player: Player, zone: ZoneController, creep: Vector3,
		action: String, face: Vector3) -> Dictionary:
	player.input_frozen = true
	player.global_position = pad_free_air(zone) + Vector3.UP * 8.0
	player.velocity = creep + Vector3.UP * 12.0
	player.begin_launch_flight()
	var from := player.global_position
	var flight: Dictionary = await _fly_holding(player, action, face, 600,
			creep)
	return {"along": flight["arc_along"],
			"min_along": flight["min_along"],
			"worst_axial": flight["worst_axial"],
			"frames": flight["frames"]}

## Somewhere in the first room with air under it, for the ordinary-jump
## comparison. Read off the Zone rather than guessed.
func pad_free_air(zone: ZoneController) -> Vector3:
	for raw: Variant in zone.offer_rooms:
		var record: Dictionary = raw
		var root: Node3D = record["node"]
		return root.global_transform * Vector3(0.0, 12.0, 20.0)
	return Vector3(0.0, 12.0, 20.0)
