extends Node
## DOES THE RAILWAY TRAVEL, STOP, REFUSE AND REVERSE?
## (`make godot-rail-carrier`)
##
## **What this is testing, and what it deliberately is not.**
## `godot-passenger-carry` already established the substrate: a
## `CharacterBody3D` standing on an `AnimatableBody3D` with
## `sync_to_physics` is carried, grounded on 300 of 300 frames, in four
## cases. `RailCarrier` is that substrate given a `RailPath` instead of a
## cosine loop, so what remains unproven is the RAILWAY: does it stop at
## the dock it was sent to, does it refuse the track that is not there,
## does a second shot skip a dock, can a fail-safe stop be released.
##
## **The movement cases are hand-stepped on purpose.** `sync_to_physics`
## makes `global_position` a read of the physics server rather than of
## what was last assigned, so a test that awaited real frames and then
## read the node would be measuring last frame's opinion. `advance()` and
## `pose()` are what the carrier knows, and they are what is asserted on.
## The carry case is the exception -- there the physics server IS the
## thing under test -- and it runs on real frames.
##
## **Every refusal is checked by its reason, not by "it did not move".**
## A carrier that refuses everything would pass a test that only looked
## for absence of motion, and the negative control below exists to catch
## exactly that: the SAME command, on the SAME railway, once the link is
## commissioned, must travel.

## Sized for a passenger who moves. `godot-passenger-carry` found a
## walking rider crosses `MovingPlatform`'s 2.4 m square in ~0.4 s and
## recorded that a carrier's deck is a gameplay decision; this is that
## decision, not an inherited default.
const DECK := Vector3(4.0, 0.4, 4.0)
## Half the deck, less a margin: past this the passenger is over the lip.
const ABOARD_LIMIT := 1.9
const CARRIED_DRIFT := 0.35
const STEP := 1.0 / 60.0
## Long enough for any journey on this railway (~4 s) with room to spare,
## short enough that a carrier which never arrives fails instead of hangs.
const HAND_FRAMES := 1200

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
	_floor()
	_shape()
	_beam_follows_the_ride()
	_travel()
	_refusal_then_repair()
	_repeat_command()
	_reverse_mid_segment()
	_fail_safe_hold()
	await _receiver_takes_a_real_shot()
	_receiver_debounces()
	_conflicting_pair()
	await _carry()
	_finish()


## THE RAILWAY UNDER TEST. Three docks, two links, and a route that
## curves in plan -- a straight rail would never exercise the tangent
## frame, and the corner is where a carrier that cuts the curve would
## show it.
func _rail() -> RailPath:
	return RailPath.from_points(PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(9, 0, 0),
		Vector3(15, 0, 5),
		Vector3(15, 0, 13),
	]))


## THE BEAM MUST BE WHERE THE RIDE IS.
##
## `RailPath` gained Catmull-Rom handles in P3.5; `build_rail` still swept
## the CONTROL points. For the two-point rails shipped today those are
## the same thing, which is why nothing caught it. For the curved route a
## railway actually needs, the beam is the chord and the ride is the arc.
func _beam_follows_the_ride() -> void:
	print("  -- BEAM: the rail a player sees is the rail they ride")
	var straight := RailPath.from_points(PackedVector3Array([
		Vector3(0, 0, -5), Vector3(0, 0, 5)]))
	_check(AffordanceFeatures.rail_sweep_points(straight)
			== straight.segments(),
		"a straight rail is swept between its control points, unchanged")
	_check(straight.bow() <= 0.001,
		"because its curve IS its control polyline (bow %.4f m)"
			% straight.bow())

	var curved := _rail()
	var chord_gap := 0.0
	for point: Vector3 in curved.polyline():
		chord_gap = maxf(chord_gap, _off(point, curved.segments()))
	_check(chord_gap > AffordanceFeatures.RAIL_BEAM_THICKNESS * 0.5,
		"the curved route's ride leaves the control chord by %.3f m, "
			% chord_gap + "past the beam's own half-thickness")
	var swept := AffordanceFeatures.rail_sweep_points(curved)
	var swept_gap := 0.0
	for point: Vector3 in curved.polyline():
		swept_gap = maxf(swept_gap, _off(point, swept))
	_check(swept_gap <= AffordanceFeatures.RAIL_BEAM_THICKNESS * 0.5,
		"and the swept beam holds it to %.3f m, inside the beam"
			% swept_gap)
	print("    %d control points -> %d swept, ride within %.3f m (was %.3f)"
		% [curved.segments().size(), swept.size(), swept_gap, chord_gap])


func _off(point: Vector3, poly: PackedVector3Array) -> float:
	var best := INF
	for i in poly.size() - 1:
		best = minf(best, point.distance_to(
			Geometry3D.get_closest_point_to_segment(point, poly[i],
				poly[i + 1])))
	return best


func _railway(links: Array[bool], deck := DECK) -> RailCarrier:
	var rail := _rail()
	var offsets := PackedFloat32Array([
		0.0,
		rail.nearest_offset(Vector3(15, 0, 5)),
		rail.length(),
	])
	var made := RailCarrier.create(rail, offsets,
		PackedStringArray(["S1", "S2", "S3"]), links, deck,
		"concrete_facility")
	add_child(made)
	# HAND-STEPPED: see the header. The engine must not also advance it.
	made.set_physics_process(false)
	return made


## Ground under everything, so a passenger who is NOT carried lands
## somewhere measurable instead of falling out of the world.
func _floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 1.0, 120.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -8.0, 0)
	add_child(body)


## Run the railway until it arrives or the budget runs out.
func _drive(carrier: RailCarrier, frames := HAND_FRAMES) -> int:
	for i in frames:
		if carrier.heading == RailCarrier.HOLD:
			return i
		carrier.advance(STEP)
	return -1


func _reasons(carrier: RailCarrier) -> Array:
	var out: Array = []
	carrier.refused.connect(func(reason: String, _detail: String) -> void:
		out.append(reason))
	return out


## A RAILWAY THAT IS NOT ONE DOES NOT MOVE.
func _shape() -> void:
	print("  -- SHAPE: a malformed railway refuses instead of guessing")
	var rail := _rail()
	# Three docks, ONE link. The missing entry is indistinguishable from
	# "the last link is broken", which is why the count is refused rather
	# than interpreted.
	var bad := RailCarrier.create(rail,
		PackedFloat32Array([0.0, 10.0, rail.length()]),
		PackedStringArray(["S1", "S2", "S3"]), [true], DECK,
		"concrete_facility")
	add_child(bad)
	bad.set_physics_process(false)
	var reasons := _reasons(bad)
	var moved := bad.request(RailCarrier.FORWARD)
	_check(not moved, "a short link array refuses the command")
	_check(reasons == ["not_a_railway"],
		"and says which fact about its own shape is wrong, got %s"
			% [reasons])
	_check(bad.offset == 0.0, "and does not move")
	bad.queue_free()

	var ok := _railway([true, true])
	_check(ok.violations().is_empty(),
		"a well-formed railway has nothing to refuse, got %s"
			% [ok.violations()])
	ok.queue_free()


## DOCK TO DOCK, AND STOP.
func _travel() -> void:
	print("  -- TRAVEL: S1 to S2 arrives and stops")
	var carrier := _railway([true, true])
	var landed: Array = []
	carrier.arrived.connect(func(dock: String) -> void: landed.append(dock))
	var left: Array = []
	carrier.departed.connect(func(dock: String, _d: int) -> void:
		left.append(dock))

	_check(carrier.at_dock() == 0, "the carrier starts at S1")
	_check(carrier.request(RailCarrier.FORWARD), "FORWARD is accepted")
	_check(left == ["S1"], "and reports leaving S1, got %s" % [left])
	var frames := _drive(carrier)
	_check(frames > 0, "the journey ends within the budget (%d frames)"
		% frames)
	_check(landed == ["S2"], "at S2, once, got %s" % [landed])
	_check(carrier.at_dock() == 1, "and `at_dock` agrees")
	_check(is_equal_approx(carrier.offset, carrier.dock_offsets[1]),
		"stopped ON the dock offset (%.4f vs %.4f)"
			% [carrier.offset, carrier.dock_offsets[1]])
	_check(carrier.speed == 0.0, "with no speed left")
	_check(carrier.heading == RailCarrier.HOLD, "and no heading")
	# THE DECK IS WHERE THE RAIL IS. A carrier whose offset is right and
	# whose transform is not would strand a passenger in mid air.
	var want := carrier.path.at(carrier.dock_offsets[1])
	var got := carrier.pose().origin
	_check(got.distance_to(want) <= DECK.y * 0.5 + 0.01,
		"and the deck sits on the rail at the dock (%.3f m off)"
			% got.distance_to(want))
	print("    S1->S2 %.2f m in %.2f s" % [carrier.dock_offsets[1],
		float(frames) * STEP])
	carrier.queue_free()


## THE HONEST REFUSAL, AND THE NEGATIVE CONTROL THAT PROVES IT IS ONE.
func _refusal_then_repair() -> void:
	print("  -- REFUSAL: S2 to S3 over track that is not there")
	var carrier := _railway([true, false])
	carrier.request(RailCarrier.FORWARD)
	_drive(carrier)
	_check(carrier.at_dock() == 1, "the carrier is at S2")

	var reasons := _reasons(carrier)
	var parked := carrier.offset
	_check(not carrier.request(RailCarrier.FORWARD),
		"FORWARD over the broken link is refused")
	_check(reasons == ["no_link"], "for the right reason, got %s" % [reasons])
	_drive(carrier, 120)
	_check(carrier.offset == parked,
		"and the carrier does not glide over missing rail")
	_check(carrier.at_dock() == 1,
		"nor is it stranded off a dock by the refusal")

	# THE CONTROL. Absence of motion is not evidence of a working
	# refusal: a carrier that refused everything would pass every check
	# above. The SAME command on the SAME carrier must travel once the
	# link exists.
	print("  -- REPAIR: the same command, once the link is commissioned")
	carrier.commissioned[1] = true
	_check(carrier.request(RailCarrier.FORWARD),
		"the same command is now accepted")
	var frames := _drive(carrier)
	_check(frames > 0 and carrier.at_dock() == 2,
		"and the carrier reaches S3")
	carrier.queue_free()


## A SHOTGUN'S PELLETS ARE ONE REQUEST, NOT FIVE.
func _repeat_command() -> void:
	print("  -- REPEAT: a second shot does not skip a dock")
	var carrier := _railway([true, true])
	var landed: Array = []
	carrier.arrived.connect(func(dock: String) -> void: landed.append(dock))
	var left: Array = []
	carrier.departed.connect(func(dock: String, _d: int) -> void:
		left.append(dock))
	carrier.request(RailCarrier.FORWARD)
	var reasons := _reasons(carrier)
	for _i in 30:
		carrier.advance(STEP)
	for _i in 5:
		_check(not carrier.request(RailCarrier.FORWARD),
			"a repeat FORWARD mid-journey is refused")
	_check(reasons.count("already_moving") == 5,
		"each one saying it is already travelling, got %s" % [reasons])
	_check(carrier.target_dock == 1, "the destination is unchanged")
	var frames := _drive(carrier)
	_check(frames > 0 and landed == ["S2"],
		"and the carrier stops at S2, not S3, got %s" % [landed])
	_check(left == ["S1"], "with one departure, got %s" % [left])
	carrier.queue_free()


## REVERSING IS LEGAL WHERE THE CARRIER HAS JUST BEEN.
func _reverse_mid_segment() -> void:
	print("  -- REVERSE: back the way it came, mid-segment")
	var carrier := _railway([true, true])
	carrier.request(RailCarrier.FORWARD)
	for _i in 60:
		carrier.advance(STEP)
	var reached := carrier.offset
	_check(reached > 0.5, "the carrier is under way (%.2f m along)" % reached)
	var landed: Array = []
	carrier.arrived.connect(func(dock: String) -> void: landed.append(dock))
	_check(carrier.request(RailCarrier.BACK), "BACK is accepted")
	_check(carrier.target_dock == 0, "aimed at the dock it departed from")
	var frames := _drive(carrier)
	_check(frames > 0 and landed == ["S1"],
		"and it returns to S1, got %s" % [landed])
	_check(is_equal_approx(carrier.offset, 0.0),
		"exactly on the dock (%.4f)" % carrier.offset)
	carrier.queue_free()


## A FAIL-SAFE THAT CANNOT BE RELEASED IS A TRAP WITH A PASSENGER IN IT.
func _fail_safe_hold() -> void:
	print("  -- HOLD: stop safely, and be able to go again")
	var carrier := _railway([true, true])
	carrier.request(RailCarrier.FORWARD)
	for _i in 60:
		carrier.advance(STEP)
	var stopped_at := carrier.offset
	carrier.hold(true)
	_check(carrier.speed == 0.0 and carrier.heading == RailCarrier.HOLD,
		"holding stops the carrier where it is")
	var reasons := _reasons(carrier)
	_check(not carrier.request(RailCarrier.FORWARD),
		"and a travel command is refused while held")
	_check(reasons == ["held"], "for the right reason, got %s" % [reasons])
	_drive(carrier, 120)
	_check(carrier.offset == stopped_at, "the held carrier does not drift")

	carrier.hold(false)
	_check(carrier.at_dock() < 0,
		"released, the carrier is stranded between docks (%.2f m)"
			% carrier.offset)
	_check(carrier.request(RailCarrier.FORWARD),
		"and can still be sent on")
	var frames := _drive(carrier)
	_check(frames > 0 and carrier.at_dock() == 1, "arriving at S2")
	# AND BACKWARD OUT OF A HOLD, because a passenger stopped by a
	# fail-safe wants the way they came at least as often as the way
	# they were going.
	carrier.request(RailCarrier.FORWARD)
	for _i in 60:
		carrier.advance(STEP)
	carrier.hold(true)
	carrier.hold(false)
	_check(carrier.request(RailCarrier.BACK),
		"a released carrier can also go back")
	_drive(carrier)
	_check(carrier.at_dock() == 1, "returning to S2")
	carrier.queue_free()


## AND A REAL PASSENGER, ON THE REAL PHYSICS SERVER, AROUND THE CORNER.
##
## Measured in the carrier's OWN frame. A carrier following a curve
## rotates, and a perfectly carried passenger standing off-centre swings
## with it: their world-space offset from the deck origin changes while
## nothing has gone wrong at all. The local frame is the instrument that
## answers the question actually being asked -- are they still standing
## where they were standing on the deck.
func _carry() -> void:
	print("  -- CARRY: a player rides S1 to S2 around the corner")
	var carrier := _railway([true, true])
	carrier.set_physics_process(true)
	await get_tree().physics_frame

	var player := Player.create()
	add_child(player)
	player.global_position = carrier.pose().origin \
		+ Vector3(0, DECK.y * 0.5 + 1.2, 0)
	player.velocity = Vector3.ZERO
	for _i in 40:
		await get_tree().physics_frame
	if not player.is_on_floor():
		_check(false, "the passenger never landed on the deck, so nothing "
			+ "below is a measurement of carrying")
		player.queue_free()
		carrier.queue_free()
		await get_tree().process_frame
		return

	var start := carrier.pose().affine_inverse() * player.global_position
	var worst := 0.0
	var grounded := 0
	var frames := 0
	var left_at := -1.0
	var top := 0.0
	carrier.request(RailCarrier.FORWARD)
	while carrier.heading != RailCarrier.HOLD and frames < HAND_FRAMES:
		await get_tree().physics_frame
		frames += 1
		top = maxf(top, carrier.speed)
		if player.is_on_floor():
			grounded += 1
		var local := carrier.pose().affine_inverse() * player.global_position
		worst = maxf(worst, (local - start).length())
		if left_at < 0.0 and Vector2(local.x, local.z).length() \
				> ABOARD_LIMIT:
			left_at = float(frames) * STEP
	var aboard := left_at < 0.0
	var fraction := float(grounded) / maxf(float(frames), 1.0)
	print("    DRIFT %.3f m   GROUNDED %d/%d (%.0f%%)   ABOARD %s"
		% [worst, grounded, frames, fraction * 100.0,
			"yes" if aboard else "left the deck at %.2f s" % left_at])
	print("    top speed %.2f m/s   ride %.2f s" % [top, float(frames) * STEP])

	_check(carrier.at_dock() == 1, "the ride ends at S2")
	_check(aboard, "and the passenger is still on the deck")
	_check(fraction >= 0.9,
		"grounded for %.0f%% of the ride" % (fraction * 100.0))
	if worst > CARRIED_DRIFT:
		_note("the passenger slid %.3f m against the deck (over %.2f m) "
			% [worst, CARRIED_DRIFT]
			+ "-- carried, but ACCEL %.1f m/s^2 is a candidate to lower"
			% RailCarrier.ACCEL)
	player.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


## A REAL SHOT FROM THE BASE KIT COMMANDS THE RAILWAY.
##
## Fired through `Player._fire_static_pulse`, not by calling the
## element: the failure this project has already paid for once is a
## target that looks correct in the scene tree and that no weapon in the
## game can actually reach.
func _receiver_takes_a_real_shot() -> void:
	print("  -- RECEIVER: the Static Pulse sends the carrier")
	var carrier := _railway([true, true])
	var controls := RailControls.create(carrier)
	add_child(controls)
	controls.set_physics_process(false)
	var forward := RailReceiver.create(RailCarrier.FORWARD, 0)
	add_child(forward)
	forward.set_process(false)
	controls.add(forward)

	var player := Player.create()
	add_child(player)
	# Well clear of the railway: the rail and its carrier are real
	# colliders, and a ray that stopped on the deck would be measuring
	# the scene's furniture rather than the receiver.
	player.global_position = Vector3(-40, -6.0, -40)
	await get_tree().process_frame
	for _i in 30:
		await get_tree().physics_frame
	forward.global_position = player.camera.global_position \
		+ (-player.camera.global_transform.basis.z) * 3.0
	await get_tree().physics_frame

	var aimed: Variant = player.camera_ray(30.0).get("collider")
	_check(aimed != null and aimed.get("element") == forward.element,
		"the shot is actually aimed at the receiver, hit %s"
			% [aimed])
	var sent: Array = []
	forward.commanded.connect(func(d: int) -> void: sent.append(d))
	var home: Vector3 = forward.arrow.position

	player._fire_static_pulse()
	_check(sent == [RailCarrier.FORWARD],
		"one Static Pulse is one FORWARD command, got %s" % [sent])
	_check(not forward.armed(), "and the control is re-arming")
	forward.advance(0.0)
	# MOTION, NOT COLOUR. The arrow lunges the way it sends the carrier,
	# so the pair reads without separating two tints.
	var moved: float = (forward.arrow.position - home).z \
		* float(forward.direction)
	_check(moved > 0.0,
		"the arrow lunges the way it points (%.3f m)" % moved)

	_check(carrier.at_dock() == 0, "the carrier has not moved yet")
	controls.resolve()
	_check(carrier.heading == RailCarrier.FORWARD,
		"the station resolves the command and the carrier departs")
	var frames := _drive(carrier)
	_check(frames > 0 and carrier.at_dock() == 1, "arriving at S2")

	player.queue_free()
	forward.queue_free()
	controls.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


## A SHOTGUN'S PELLETS ARE ONE REQUEST.
##
## Each pellet is its own `take_damage` call -- that is what a
## multi-pellet weapon does -- so the burst is delivered the way a
## weapon delivers it rather than through a convenience hook.
func _receiver_debounces() -> void:
	print("  -- DEBOUNCE: one blast is one command")
	var forward := RailReceiver.create(RailCarrier.FORWARD, 0)
	add_child(forward)
	forward.set_process(false)
	var sent: Array = []
	forward.commanded.connect(func(d: int) -> void: sent.append(d))

	var landed := 0
	for _i in 8:
		if forward.element.take_damage(1.0):
			landed += 1
	_check(landed == 1, "only the first pellet registers, %d did" % landed)
	_check(sent.size() == 1, "and one blast is one command, got %d"
		% sent.size())

	# Still one command halfway through the window...
	forward.advance(RailReceiver.REARM_SECONDS * 0.5)
	forward.element.take_damage(1.0)
	_check(sent.size() == 1,
		"a hit inside the re-arm window is still the same command")
	_check(not forward.armed(), "because the control is not armed yet")

	# ...and a second command once it has re-armed, because a player who
	# meant to send the carrier twice must be able to.
	forward.advance(RailReceiver.REARM_SECONDS)
	_check(forward.armed(), "the control re-arms")
	_check(not forward.element.is_set, "and goes dim again")
	forward.element.take_damage(1.0)
	_check(sent.size() == 2, "a later shot is a second command, got %d"
		% sent.size())
	forward.queue_free()


## FORWARD AND BACK IN THE SAME INSTANT.
##
## A splash, a close shotgun or two players. Whichever the engine
## happened to deliver first would win, and would win differently
## elsewhere -- so the pair cancels, and says so.
func _conflicting_pair() -> void:
	print("  -- CONFLICT: two opposed commands in one frame")
	var carrier := _railway([true, true])
	carrier.request(RailCarrier.FORWARD)
	_drive(carrier)
	_check(carrier.at_dock() == 1, "the carrier is parked at S2")

	var controls := RailControls.create(carrier)
	add_child(controls)
	controls.set_physics_process(false)
	var forward := RailReceiver.create(RailCarrier.FORWARD, 0)
	var back := RailReceiver.create(RailCarrier.BACK, 1)
	for receiver: RailReceiver in [forward, back]:
		add_child(receiver)
		receiver.set_process(false)
		controls.add(receiver)
	# SHAPE, BEFORE ANY OF THIS. The two controls point opposite ways,
	# which is the cue a player reads first and the one that survives
	# both tints looking the same.
	_check(signf(forward.arrow.position.z) != signf(back.arrow.position.z),
		"the two arrows point opposite ways")

	var reasons: Array = []
	controls.refused.connect(func(reason: String, _d: String) -> void:
		reasons.append(reason))
	var parked := carrier.offset
	forward.element.take_damage(1.0)
	back.element.take_damage(1.0)
	controls.resolve()
	_check(reasons == ["conflicting"],
		"the pair cancels and says so, got %s" % [reasons])
	_check(carrier.heading == RailCarrier.HOLD, "the carrier stays put")
	_drive(carrier, 120)
	_check(carrier.offset == parked, "and does not move")

	# THE CONTROL. A station that refused everything would pass every
	# check above; the same receiver, alone, must send the carrier.
	for receiver: RailReceiver in [forward, back]:
		receiver.advance(RailReceiver.REARM_SECONDS)
	forward.element.take_damage(1.0)
	controls.resolve()
	_check(carrier.heading == RailCarrier.FORWARD,
		"the same FORWARD control, alone, commands the carrier")
	var frames := _drive(carrier)
	_check(frames > 0 and carrier.at_dock() == 2, "and it reaches S3")

	# AND THE CARRIER'S OWN REFUSALS REACH THE SAME PLACE, so a readout
	# does not have to know whether the station or the vehicle said no.
	reasons.clear()
	for receiver: RailReceiver in [forward, back]:
		receiver.advance(RailReceiver.REARM_SECONDS)
	forward.element.take_damage(1.0)
	controls.resolve()
	_check(reasons == ["no_link"],
		"the carrier's refusal is relayed by the station, got %s"
			% [reasons])

	forward.queue_free()
	back.queue_free()
	controls.queue_free()
	carrier.queue_free()


func _finish() -> void:
	print("  MEASURED %d check(s), %d note(s)" % [_checks, _notes])
	if _failures == 0:
		print("GODOT RAIL CARRIER OK (%d checks)" % _checks)
	else:
		print("GODOT RAIL CARRIER FAILED (%d of %d checks)"
			% [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
