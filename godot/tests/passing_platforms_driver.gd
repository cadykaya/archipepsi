extends Node
## EX50-011 PASSING PLATFORMS (`make godot-passing-platforms`).
##
## The specification is paper and is recorded as paper
## (`docs/design-library/EX50_entries/EX50-011.md`). What follows is the
## part of it that has been BUILT, measured against the bars the document
## sets for itself rather than against a restatement of them:
##
##   §11  a continuous body run from `A` boards `V`, transfers to `H`
##        with all motion active and reaches `G` -- and a counterpart
##        with `H`'s track shifted so nothing passes must NOT report the
##        same commanded timing successful.
##   §10  the world-space overlap duration, the relative velocity at the
##        transfer, railing collision, the jump landing and the
##        recovery-floor coverage are MEASURED. "Declared periods alone
##        do not prove any of those properties."
##   §10  the lowest-pressure solution is present: stop `H` near the
##        transfer, ride `V`, board `H`, restart. Built, or the paper
##        alternative is removed.
##   §8   the actual maximum fall height and the damage are verified.
##   §8   repeated calls cannot queue arrivals, and a stopped carrier
##        does not resume on an old command.
##
## **Evidence classes are kept apart, as they are in the junction
## suite.** `_the_continuous_run` and `_the_low_pressure_route` walk,
## ride and interact with nothing placed and nothing snapped. Everything
## else either steps the machines by hand -- which is arithmetic about
## two schedules and is labelled that way -- or places a body to measure
## one property. A hand-stepped overlap is not evidence that a person
## can make the transfer; the continuous run is.
##
## **What is NOT tested here, because it is not built:** §9's save
## behaviour. There is no 0.4 save representation yet, no campaign under
## this scenario and nothing that could restore a carrier pose, so the
## dwell-across-reload rule is paper. It is recorded as paper in the
## ledger rather than covered by a test that would only be re-reading
## the specification back to itself.

const STEP := 1.0 / 60.0
## A hand-stepped schedule is allowed a generous ceiling: 40 s at 60 Hz.
const HAND_FRAMES := 2400

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
	_shape()
	_the_decks_never_touch()
	_the_overlap_is_measured()
	_the_dwell_is_declared()
	_no_queued_arrivals()
	_a_stop_is_not_undone_by_an_old_command()
	await _the_railings_and_the_floor()
	await _the_fall_is_measured()
	await _the_continuous_run()
	await _the_low_pressure_route()
	await _reset_never_teleports()
	print("")
	if _failures == 0:
		print("GODOT PASSING PLATFORMS OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
		return
	printerr("GODOT PASSING PLATFORMS FAILED (%d of %d)"
			% [_failures, _checks])
	get_tree().quit(1)


## A room, built and settled.
func _room(parted := false) -> PassingPlatforms:
	var made := PassingPlatforms.new()
	made.parted = parted
	add_child(made)
	return made


func _settle(frames := 40) -> void:
	for _i in frames:
		await get_tree().physics_frame


# --------------------------------------------------------------- shape

## The room is the room the paper describes, in the numbers that matter.
func _shape() -> void:
	print("  -- SHAPE: two machines, one plane, one gap")
	var room := _room()
	_check(room.v.violations().is_empty(),
		"the lift is well-formed, got %s" % [room.v.violations()])
	_check(room.h.violations().is_empty(),
		"the shuttle is well-formed, got %s" % [room.h.violations()])
	_check(is_equal_approx(room.v_top(), 0.0),
		"the lift starts at the arrival floor, at %.2f" % room.v_top())
	_check(is_equal_approx(room.h_top(), PassingPlatforms.TRANSFER_Y),
		"the shuttle's deck top is the transfer plane, at %.2f"
			% room.h_top())
	_check(is_equal_approx(room.v.stops[PassingPlatforms.V_TRANSFER],
			PassingPlatforms.TRANSFER_Y),
		"the lift's intermediate stop IS the transfer plane")
	_check(is_equal_approx(room.v.dwells[PassingPlatforms.V_TRANSFER],
			PassingPlatforms.V_DWELL),
		"the authored pause is %.1f s and is declared with the stop"
			% PassingPlatforms.V_DWELL)
	var gap := room.transfer_gap()
	_check(absf(gap - PassingPlatforms.GAP) < 0.001,
		"the decks are %.2f m apart at the transfer plane" % gap)
	var run_up := room.rendezvous_offset()
	_check(absf(run_up - 9.0) < 0.2,
		"the west berth is %.2f m from the rendezvous (paper says 9)"
			% run_up)
	_note("service speed %.1f m/s, so the run-up is about %.1f s"
			% [room.h.top_speed, run_up / room.h.top_speed])
	room.queue_free()


## §4: "The carriers do not collide during a mistimed meeting."
##
## NOT A SAMPLE OF THE SCHEDULE -- the whole cross product of where each
## machine can be. A timing test would only ever prove that today's two
## schedules happen not to meet; the separation the paper asks for is a
## property of the geometry, and it is checked as one.
func _the_decks_never_touch() -> void:
	print("  -- GEOMETRY: no pair of positions puts the decks together")
	var room := _room()
	var deck: Vector3 = PassingPlatforms.DECK
	var worst := INF
	var touching := 0
	for i in 41:
		var v_at: float = lerpf(0.0, PassingPlatforms.SHELF_Y,
				float(i) / 40.0)
		var v_box := AABB(Vector3(PassingPlatforms.V_X - deck.x * 0.5,
				v_at - deck.y, PassingPlatforms.V_Z - deck.z * 0.5), deck)
		for j in 41:
			var h_at: float = lerpf(0.0, room.rail.length(),
					float(j) / 40.0)
			var at := room.rail.at(h_at)
			var h_box := AABB(Vector3(at.x - deck.x * 0.5, at.y,
					at.z - deck.z * 0.5), deck)
			if v_box.intersects(h_box):
				touching += 1
			worst = minf(worst, h_box.position.z
					- (v_box.position.z + v_box.size.z))
	_check(touching == 0,
		"no pair of positions overlaps (%d of 1681 sampled)" % touching)
	_check(worst > 0.0,
		"the closest the two sweeps ever come is %.2f m, in z" % worst)
	room.queue_free()


## §10: "Authoring must measure the world-space overlap duration".
##
## HAND-STEPPED ARITHMETIC, and that is all it is: two schedules advanced
## by `advance(STEP)` with no body in the room. It says how long the
## opportunity lasts, not whether a person can take it.
func _the_overlap_is_measured() -> void:
	print("  -- OVERLAP: how long the chance to step across lasts")
	for board: float in [1.0, 2.0, 3.0]:
		var room := _room()
		var measured := _sweep(room, board)
		_check(float(measured["overlap"]) > 1.0,
			("a %.0f s board-and-launch leaves %.2f s in which the "
				+ "shuttle is under the lift's deck AND the lift is at "
				+ "the transfer plane") % [board, measured["overlap"]])
		_note("board %.0f s: relative speed at the first overlapping "
				% board
				+ "frame %.2f m/s; the lift is stationary for %.1f s of it"
				% [measured["relative"], measured["dwelt"]])
		room.queue_free()
	# AND THE COUNTEREXAMPLE FOR THIS INSTRUMENT. A measurement that
	# reports an overlap in a room where nothing passes is not measuring
	# the room.
	var parted := _room(true)
	var none := _sweep(parted, 2.0)
	_check(float(none["overlap"]) == 0.0,
		"the parted room reports no overlap at all, got %.2f s"
			% none["overlap"])
	parted.queue_free()


## Advance both machines with the lift launched `board` seconds after the
## shuttle is called, and report the overlap.
func _sweep(room: PassingPlatforms, board: float) -> Dictionary:
	var v: ShuttleDeck = room.v
	var h: RailCarrier = room.h
	h.hold(false)
	h.request(RailCarrier.FORWARD)
	var launched := false
	var overlap := 0.0
	var dwelt := 0.0
	var relative := -1.0
	var deck: Vector3 = PassingPlatforms.DECK
	for i in HAND_FRAMES:
		var t := float(i) * STEP
		if not launched and t >= board:
			launched = true
			v.go_to(PassingPlatforms.V_SHELF)
		v.advance(STEP)
		h.advance(STEP)
		# THE STEP IS ACROSS z AND ALONG x, so an overlap needs the
		# shuttle's deck to cover the lift's column in x and the lift's
		# deck to be level with the transfer plane. Both, or there is
		# nothing to step onto.
		var span := room.h_span()
		var under := span.x <= PassingPlatforms.V_X \
				and span.y >= PassingPlatforms.V_X
		# Level enough to be a step rather than a climb: half the deck's
		# own thickness.
		var level := absf(room.v_top() - PassingPlatforms.TRANSFER_Y) \
				<= deck.y * 0.5
		# AND THE TRACKS MUST ACTUALLY PASS. In the parted room every
		# other condition still holds and the step is into the air.
		var reachable := room.transfer_gap() <= 1.0
		if under and level and reachable:
			overlap += STEP
			if relative < 0.0:
				relative = absf(h.speed - v.speed)
			if v.dwelling_at() == PassingPlatforms.V_TRANSFER:
				dwelt += STEP
		if h.at_dock() == PassingPlatforms.H_EAST and launched:
			break
	return {"overlap": overlap, "dwelt": dwelt,
			"relative": maxf(relative, 0.0)}


## §2: the pause is "visible as a docking slowdown, not a hidden grace
## period" -- so it is announced, it is the declared length, and it is
## spent at the transfer plane rather than somewhere near it.
func _the_dwell_is_declared() -> void:
	print("  -- DWELL: announced, declared and spent where it is claimed")
	var room := _room()
	var seen: Array = []
	room.v.dwelling.connect(func(stop: int, secs: float) -> void:
		seen.append([stop, secs]))
	room.v.go_to(PassingPlatforms.V_SHELF)
	var held := 0.0
	var at_plane := true
	for _i in HAND_FRAMES:
		room.v.advance(STEP)
		if room.v.dwelling_at() == PassingPlatforms.V_TRANSFER:
			held += STEP
			at_plane = at_plane and absf(room.v_top()
					- PassingPlatforms.TRANSFER_Y) < 0.05
		if room.v.at_stop() == PassingPlatforms.V_SHELF:
			break
	_check(seen.size() == 1 and int(seen[0][0])
			== PassingPlatforms.V_TRANSFER,
		"the lift announced exactly one dwell, at the transfer stop")
	_check(absf(held - PassingPlatforms.V_DWELL) < 0.05,
		"it held for %.2f s of the declared %.1f s"
			% [held, PassingPlatforms.V_DWELL])
	_check(at_plane, "and it held AT the transfer plane throughout")
	_check(room.v.at_stop() == PassingPlatforms.V_SHELF,
		"then carried on to the shelf")
	room.queue_free()


## §8: "Repeated call presses cannot create multiple scheduled arrivals."
func _no_queued_arrivals() -> void:
	print("  -- SCHEDULE: one destination, one motion state")
	var room := _room()
	var arrivals: Array = []
	room.v.arrived.connect(func(stop: int) -> void: arrivals.append(stop))
	for _i in 5:
		room.v.go_to(PassingPlatforms.V_SHELF)
	_check(room.v.destination == PassingPlatforms.V_SHELF,
		"five presses are one destination")
	for _i in HAND_FRAMES:
		room.v.advance(STEP)
		if room.v.at_stop() == PassingPlatforms.V_SHELF:
			break
	for _i in 120:
		room.v.advance(STEP)
	_check(arrivals.size() == 1,
		"and one arrival, got %d" % arrivals.size())
	# A SECOND CALL REPLACES THE FIRST rather than queueing behind it.
	room.v.go_to(PassingPlatforms.V_ARRIVAL)
	room.v.go_to(PassingPlatforms.V_TRANSFER)
	for _i in HAND_FRAMES:
		room.v.advance(STEP)
		if room.v.at_stop() == PassingPlatforms.V_TRANSFER:
			break
	for _i in 300:
		room.v.advance(STEP)
	_check(room.v.at_stop() == PassingPlatforms.V_TRANSFER,
		"the later call replaced the earlier one and nothing "
			+ "resumed afterwards")
	room.queue_free()


## §8: "An old delayed command must not resume travel after the player
## has explicitly stopped it."
func _a_stop_is_not_undone_by_an_old_command() -> void:
	print("  -- STOP: an old command does not restart a stopped carrier")
	var room := _room()
	room.v.go_to(PassingPlatforms.V_SHELF)
	for _i in 60:
		room.v.advance(STEP)
	room.v.stop_here()
	var where := room.v.offset
	for _i in 600:
		room.v.advance(STEP)
	_check(is_equal_approx(room.v.offset, where),
		"ten seconds after STOP the lift is still at %.3f, now %.3f"
			% [where, room.v.offset])
	_check(room.v.destination == PassingPlatforms.V_SHELF,
		"its saved destination survives the stop")
	# AND A CALL WHILE STOPPED IS REFUSED BY NAME rather than obeyed.
	var refusals: Array = []
	room.v.refused.connect(func(why: String, _d: String) -> void:
		refusals.append(why))
	room.v.go_to(PassingPlatforms.V_ARRIVAL)
	for _i in 60:
		room.v.advance(STEP)
	_check(refusals.has("held") and is_equal_approx(room.v.offset, where),
		"a call while stopped is refused as 'held' and moves nothing")
	_check(room.v.destination == PassingPlatforms.V_ARRIVAL,
		"but it does change where the lift goes when released -- "
			+ "resume follows the saved destination")
	room.v.resume()
	for _i in HAND_FRAMES:
		room.v.advance(STEP)
		if room.v.at_stop() == PassingPlatforms.V_ARRIVAL:
			break
	_check(room.v.at_stop() == PassingPlatforms.V_ARRIVAL,
		"and released, it goes there from between floors")
	room.queue_free()


## §10: railing collision, and recovery-floor coverage.
func _the_railings_and_the_floor() -> void:
	print("  -- GUARDS: what the railings stop, and what catches a miss")
	var room := _room()
	await _settle()
	var space := get_viewport().world_3d.direct_space_state
	# BOTH MACHINES AT THE RENDEZVOUS, so the two questions are asked of
	# the arrangement the player actually meets. Asking them of a lift
	# still parked at the arrival floor is asking them of empty air, and
	# the first cut of this case did exactly that: the "stepping
	# direction is open" check passed because there was nothing at that
	# height to be open or shut.
	room.h.offset = room.rendezvous_offset()
	room.h._place()
	room.v.offset = PassingPlatforms.TRANSFER_Y
	room.v._place()
	await _settle(4)
	var chest := PassingPlatforms.TRANSFER_Y + 0.9
	var v_centre := Vector3(PassingPlatforms.V_X, chest,
			PassingPlatforms.V_Z)
	var h_centre := Vector3(PassingPlatforms.V_X, chest,
			room.h.pose().origin.z)
	_check(_clear(space, v_centre, h_centre),
		"nothing stands between the lift's deck and the shuttle's -- "
			+ "the intended stepping direction is open")
	# ...and the sides that are not for stepping off are not open.
	var north := h_centre + Vector3(0.0, 0.0,
			PassingPlatforms.DECK.z * 0.5 + 0.6)
	_check(not _clear(space, h_centre, north),
		"the shuttle's north edge is railed")
	var v_east := v_centre + Vector3(PassingPlatforms.DECK.x * 0.5 + 0.6,
			0.0, 0.0)
	_check(not _clear(space, v_centre, v_east),
		"the lift's east edge is railed")
	# RECOVERY-FLOOR COVERAGE: straight down from everywhere a body can
	# be at the transfer plane, is there a floor?
	var uncovered: Array[Vector3] = []
	var deepest := 0.0
	for i in 25:
		for j in 21:
			var at := Vector3(lerpf(-12.0, 12.0, float(i) / 24.0),
					PassingPlatforms.TRANSFER_Y + 0.1,
					lerpf(-4.0, 6.0, float(j) / 20.0))
			var down: Variant = _floor_under(space, at)
			if down == null:
				uncovered.append(at)
				continue
			deepest = maxf(deepest, at.y - float(down))
	_check(uncovered.is_empty(),
		"every point of the transfer level has a floor under it "
			+ "(%d without)" % uncovered.size())
	_check(deepest <= 4.2,
		"and the longest drop from that level is %.2f m" % deepest)
	room.queue_free()


func _clear(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	return space.intersect_ray(query).is_empty()


## The height of the first solid thing under `at`, or null.
func _floor_under(space: PhysicsDirectSpaceState3D, at: Vector3) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(at,
			at - Vector3(0.0, 40.0, 0.0))
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return float((hit["position"] as Vector3).y)


## §8: "Missing H lands the player on the recovery floor. The actual
## maximum fall height and damage must be verified."
##
## PLACED, NOT WALKED, and labelled so: the body is stood on the lift at
## the transfer plane with the shuttle at its west berth, and then walked
## off the edge. What this measures is the consequence of a miss, not
## whether a person would make one.
func _the_fall_is_measured() -> void:
	print("  -- MISS: how far a missed transfer falls, and what it costs")
	var room := _room()
	await _settle()
	var body: Player = room.player
	room.v.offset = PassingPlatforms.TRANSFER_Y
	room.v._place()
	body.global_position = Vector3(PassingPlatforms.V_X,
			PassingPlatforms.TRANSFER_Y + 1.0, PassingPlatforms.V_Z)
	body.velocity = Vector3.ZERO
	await _settle(20)
	var before: float = body.hp
	var from := body.global_position.y
	await _face_and_hold(body, PI, 40)
	var lowest := body.global_position.y
	for _i in 200:
		await get_tree().physics_frame
		lowest = minf(lowest, body.global_position.y)
		if body.is_on_floor():
			break
	var drop := from - body.global_position.y
	_check(body.is_on_floor(),
		"a missed transfer lands on a floor, at y=%.2f"
			% body.global_position.y)
	_check(body.global_position.y > Constants.FALL_KILL_Y + 1.0,
		"and not into a void")
	_check(absf(body.global_position.y - PassingPlatforms.RECOVERY_Y)
			< 1.2,
		"the floor it lands on is the recovery floor (y=%.2f, expected "
			% body.global_position.y + "%.2f)" % PassingPlatforms.RECOVERY_Y)
	_check(is_equal_approx(body.hp, before),
		"the fall of %.2f m cost %.0f HP" % [drop, before - body.hp])
	# THE MEASURED ANSWER TO §8, and it is not the one the paper guesses
	# at. This engine has no fall damage at all: `FALL_KILL_Y` is the
	# only height that matters and it is thirty metres below the floor.
	_note("measured fall %.2f m; this runtime applies NO fall damage at "
			% drop + "any height -- the only fatal fall is past y=%.0f"
			% Constants.FALL_KILL_Y)
	_note("the tallest unrailed drop in the room is the shelf's lift "
			+ "opening at %.1f m, open whenever the lift is away; "
				% (PassingPlatforms.SHELF_Y)
			+ "boarding gates and interlocks (§8) are NOT built")
	room.queue_free()


# ----------------------------------------------------- continuous play

## §11, THE POSITIVE RUN. Nothing placed, nothing snapped.
##
## Every metre is walked or ridden and every command is a keypress on a
## lever the player is looking at. The railings stay where they are.
func _the_continuous_run() -> void:
	print("  -- CONTINUOUS: A to G, walked and ridden, nothing placed")
	var room := _room()
	await _settle()
	var out := await _the_plan(room, -1)
	_check(bool(out["boarded_v"]), "the player boarded the lift and rose "
			+ "with it to the transfer plane")
	_check(bool(out["boarded_h"]),
		"stepped across onto the shuttle with both machines commanded "
			+ "and the shuttle still moving")
	_check(room.reached_g,
		"and rode it to the goal gallery, reaching G")
	_check(room.stair_released,
		"arriving released the permanent service stair")
	_check(int(out["railings"]) == int(out["railings_end"]),
		"the railings were untouched throughout (%d colliders before, "
			% out["railings"] + "%d after)" % out["railings_end"])
	_note("relative speed at the transfer %.2f m/s; the step was taken "
			% out["relative"]
			+ "%.2f s after the launch lever" % (float(out["after"]) * STEP))
	var after := int(out["after"])
	room.queue_free()

	# §11, THE COUNTERPART. The same commanded timing -- the same
	# interval between pulling LAUNCH and stepping north -- in a room
	# whose tracks do not pass.
	print("  -- COUNTERPART: the same timing where nothing passes")
	var parted := _room(true)
	await _settle()
	var miss := await _the_plan(parted, after)
	_check(bool(miss["boarded_v"]),
		"the same plan still boards the lift")
	_check(not bool(miss["boarded_h"]),
		"and there is nothing to step onto")
	_check(not parted.reached_g,
		"G is NOT reached, so the positive run was measuring the room "
			+ "and not its own commands")
	_check(not parted.stair_released, "and no stair is released")
	_check(absf(parted.player.global_position.y
			- PassingPlatforms.RECOVERY_Y) < 1.5,
		"the body is on the recovery floor at y=%.2f"
			% parted.player.global_position.y)
	parted.queue_free()


## The plan, as a player performs it.
##
## `after_launch` is the ONE number the counterpart replays: how many
## frames pass between pulling LAUNCH and stepping north. Pass -1 to
## decide it live -- which is what a player does, by watching the
## shuttle -- and the frame count is returned. Everything else is the
## same physical sequence in both rooms: walk to the lever, pull it,
## walk to the lift, pull LAUNCH, ride, step, ride, walk off.
##
## THE WALKS ARE NOT REPLAYED BY FRAME and deliberately so. A body that
## arrives at a lever one frame later in the second room would fire its
## interact into the air, and the run would fail for a reason that has
## nothing to do with whether the tracks pass. What §11 asks to be held
## identical is the commanded timing of the transfer, and that is what is
## held identical.
func _the_plan(room: PassingPlatforms, after_launch: int) -> Dictionary:
	var body: Player = room.player
	var v: ShuttleDeck = room.v
	var railings := _railing_count(room)

	# 1. THE CALL AT `A`. `H` leaves the west berth.
	var call_lever: CallLever = room.levers["H EAST"]
	await _walk_to(body, call_lever.global_position, 1.4)
	var called := await _pull(body, call_lever)
	_check(called, "the call lever at A was pulled")
	_check(room.h.heading == RailCarrier.FORWARD,
		"and the shuttle left the west berth for the east")

	# 2. ABOARD `V`. The deck is flush with the arrival floor, so this is
	#    a walk onto it and not a climb.
	var board := Vector3(PassingPlatforms.V_X + 1.0, 0.0,
			PassingPlatforms.V_Z - 1.0)
	await _walk_to(body, board, 0.7)
	var on_deck := _standing_on(body, v)
	var launch: CallLever = room.levers["LAUNCH"]
	var launched := await _pull(body, launch)
	_check(launched, "the launch lever on the lift's own deck was pulled")

	# 3. THE RIDE UP, and the decision.
	var waited := 0
	var stepped := after_launch
	for i in HAND_FRAMES:
		await get_tree().physics_frame
		waited = i
		if after_launch >= 0:
			if i >= after_launch:
				break
			continue
		# LIVE: step when the lift is holding at the transfer plane AND
		# the shuttle's deck has reached the column, with a deck's
		# quarter of margin so the step is not onto an edge.
		if v.dwelling_at() != PassingPlatforms.V_TRANSFER:
			continue
		var span := room.h_span()
		var margin: float = PassingPlatforms.DECK.x * 0.25
		if span.x + margin <= PassingPlatforms.V_X \
				and span.y - margin >= PassingPlatforms.V_X:
			break
	if after_launch < 0:
		stepped = waited
	var boarded_v := _standing_on(body, v) \
			and absf(body.global_position.y
				- PassingPlatforms.TRANSFER_Y) < 1.2
	var relative := absf(room.h.speed - v.speed)

	# 4. THE STEP ACROSS, north, at walking speed. No jump: the decks are
	#    level and 0.2 m apart.
	await _face_and_hold(body, PI, 34)
	await _settle(10)
	var boarded_h := _standing_on(body, room.h)

	# 5. CARRIED EAST. Nothing is pressed; the shuttle is doing this.
	for _i in HAND_FRAMES:
		await get_tree().physics_frame
		if room.h.at_dock() == PassingPlatforms.H_EAST:
			break

	# 6. OFF AT `G`.
	await _walk_to(body, Vector3(PassingPlatforms.G_WEST + 1.8,
			PassingPlatforms.TRANSFER_Y, 2.2), 1.0, 420)
	await _settle(20)
	return {"boarded_v": boarded_v and on_deck, "boarded_h": boarded_h,
			"after": stepped, "relative": relative,
			"railings": railings, "railings_end": _railing_count(room)}


## §6 and §10: "The lowest-pressure solution must be present too: stop H
## near the transfer, ride V, board H, restart. If no accessible control
## permits that sequence, the paper alternative is false and must be
## removed or built rather than left as reassuring prose."
##
## So it is walked, from controls a body can actually reach: the STOP at
## `A`, then the lift, then the shuttle's OWN onboard lever.
func _the_low_pressure_route() -> void:
	print("  -- PATIENT: stop the shuttle first, then ride across")
	var room := _room()
	await _settle()
	var body: Player = room.player
	var call_lever: CallLever = room.levers["H EAST"]
	var stop_lever: CallLever = room.levers["STOP H"]
	await _walk_to(body, call_lever.global_position, 1.4)
	_check(await _pull(body, call_lever), "the shuttle was called east")
	# STAND AT THE STOP LEVER AND WATCH. The player has all the time they
	# need; what they must judge is one press.
	await _walk_to(body, stop_lever.global_position, 1.4)
	var pressed := false
	for _i in HAND_FRAMES:
		await get_tree().physics_frame
		# NEAR THE RENDEZVOUS MEANS CENTRED ON IT, not merely touching
		# it. Stopping the instant the deck's leading edge crosses the
		# column parks the player's boarding line against the shuttle's
		# west railing, which is a legal place to stop and a poor one --
		# and §6's alternative is about removing time pressure from the
		# transfer, not about removing the judgement of where to stop.
		if absf(room.h.pose().origin.x - PassingPlatforms.V_X) < 1.0:
			pressed = await _pull(body, stop_lever)
			break
	_check(pressed, "and stopped near the rendezvous with a control at A")
	await _settle(30)
	_check(room.h.speed == 0.0 and room.h.at_dock() < 0,
		"the shuttle is standing between its berths, not at one")
	var parked := room.h.offset
	# RIDE UP TO IT. No timing at all now.
	await _walk_to(body, Vector3(PassingPlatforms.V_X + 1.0, 0.0,
			PassingPlatforms.V_Z - 1.0), 0.7)
	_check(await _pull(body, room.levers["LAUNCH"]), "the lift was launched")
	for _i in HAND_FRAMES:
		await get_tree().physics_frame
		if room.v.dwelling_at() == PassingPlatforms.V_TRANSFER:
			break
	_check(is_equal_approx(room.h.offset, parked),
		"the shuttle did not drift while the lift rose")
	await _face_and_hold(body, PI, 34)
	await _settle(10)
	_check(_standing_on(body, room.h),
		"the player stepped onto a stationary shuttle")
	# RESTART IT FROM ITS OWN CONTROL (§6).
	var onboard: CallLever = room.levers["H ON EAST"]
	await _walk_to(body, onboard.global_position, 1.3, 200)
	_check(await _pull(body, onboard),
		"and restarted it from the lever on its deck")
	for _i in HAND_FRAMES:
		await get_tree().physics_frame
		if room.h.at_dock() == PassingPlatforms.H_EAST:
			break
	_check(room.h.at_dock() == PassingPlatforms.H_EAST,
		"which carried them to the east berth")
	await _walk_to(body, Vector3(PassingPlatforms.G_WEST + 1.8,
			PassingPlatforms.TRANSFER_Y, 2.2), 1.0, 420)
	await _settle(20)
	_check(room.reached_g,
		"the patient route reaches G as well -- the paper alternative "
			+ "is built, not prose")
	room.queue_free()


## §8: "Reset while occupied uses the normal safe motion/checkpoint
## treatment, not instant relocation into a dock", and "No reset undoes
## G's released service stair".
func _reset_never_teleports() -> void:
	print("  -- RESET: ordinary motion, and it does not undo the stair")
	var room := _room()
	await _settle()
	room.stair_released = true
	room.v.go_to(PassingPlatforms.V_SHELF)
	for _i in 90:
		room.v.advance(STEP)
	var before := room.v.offset
	room.reset_carriers()
	var worst := 0.0
	var last := room.v.offset
	for _i in HAND_FRAMES:
		room.v.advance(STEP)
		worst = maxf(worst, absf(room.v.offset - last))
		last = room.v.offset
		if room.v.at_stop() == PassingPlatforms.V_ARRIVAL:
			break
	# ONE FRAME OF TRAVEL, plus the docking epsilon the last step snaps
	# across. Anything larger is a relocation.
	var ceiling := ShuttleDeck.SPEED * STEP + ShuttleDeck.STOP_EPSILON
	_check(worst <= ceiling,
		("the lift came down at ordinary speed -- its largest single "
			+ "step was %.4f m against a ceiling of %.4f, where "
			+ "relocating into the berth would have been one step of "
			+ "%.2f m") % [worst, ceiling, before])
	_check(room.v.at_stop() == PassingPlatforms.V_ARRIVAL,
		"and arrived at the arrival berth")
	_check(room.stair_released,
		"the released service stair survived the reset")
	room.queue_free()


# ------------------------------------------------------------- helpers

## Every railing that RIDES ON A DECK, which is what §11 means by not
## disabling one to pass. The fixed railings round the shelf and the
## gallery are part of the room and are covered by the ray checks.
##
## COUNTED FROM THE DECKS THEMSELVES rather than by searching the room
## for a name: `find_children` matches a name Godot has already made
## unique among siblings, so the shuttle's second railing is "Railing2"
## and a search for "Railing" quietly returns two of the three.
func _railing_count(room: PassingPlatforms) -> int:
	var found := 0
	for deck: Node3D in [room.v, room.h]:
		for node in deck.get_children():
			var body := node as StaticBody3D
			if body != null and String(body.name).begins_with("Railing"):
				found += 1
	return found


## Is the body's feet on `machine` right now?
##
## READ FROM WHAT IS UNDER THE FEET rather than from a height
## comparison: a player standing at y=4.2 is not evidence of standing on
## the shuttle, and this suite has to be able to tell "landed on the
## deck" from "happened to be at deck height".
##
## THE SLIDE COLLISION ALONE IS NOT ENOUGH, which cost a false failure.
## A body resting on a STATIONARY deck with no input can finish a
## physics frame having slid against nothing, so `get_slide_collision`
## reports an empty list and the instrument says the player is not
## aboard -- while `is_on_floor()` is true and the deck is right there.
## The ray is the fallback, and it is what actually answers the
## question.
func _standing_on(body: Player, machine: Node3D) -> bool:
	if not body.is_on_floor():
		return false
	for i in body.get_slide_collision_count():
		if _is_part_of(body.get_slide_collision(i).get_collider(), machine):
			return true
	var space := get_viewport().world_3d.direct_space_state
	var from := body.global_position
	var query := PhysicsRayQueryParameters3D.create(from,
			from - Vector3(0.0, 2.0, 0.0))
	query.exclude = [body.get_rid()]
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	return _is_part_of(hit["collider"], machine)


func _is_part_of(who: Variant, machine: Node3D) -> bool:
	if who == machine:
		return true
	var node := who as Node
	return node != null and node.get_parent() == machine


func _aim(body: Player, at: Vector3) -> void:
	var d: Vector3 = at - body.camera.global_position
	body.rotation.y = atan2(-d.x, -d.z)
	body.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## Look at a lever and press the interact key until it registers.
##
## `is_action_just_pressed` is read inside `_physics_process`, and a
## press issued from a coroutine lands BETWEEN frames -- so the press is
## held across several frames and released once the lever has counted it,
## rather than pressed and released blind on one frame.
func _pull(body: Player, lever: CallLever) -> bool:
	var before := lever.pulls
	_aim(body, lever.global_position + Vector3(0.0, 0.1, 0.0))
	await get_tree().physics_frame
	Input.action_press("interact", 1.0)
	for _i in 12:
		await get_tree().physics_frame
		if lever.pulls > before:
			break
	Input.action_release("interact")
	await get_tree().physics_frame
	return lever.pulls > before


## Walk, on the flat, to a point. Returns whether it got there.
func _walk_to(body: Player, goal: Vector3, within := 1.2,
		frames := 320) -> bool:
	var arrived := false
	var still := 0
	var last := body.global_position
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		body.camera.rotation.x = 0.0
		if (here - last).length() < 0.012:
			still += 1
			if still == 18 and body.is_on_floor():
				Input.action_press("jump", 1.0)
				await get_tree().physics_frame
				Input.action_release("jump")
				still = 0
		else:
			still = 0
		last = here
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	return arrived


## Face `yaw` and hold forward for `frames`. The step across, and the
## step off the edge, are the same action in different rooms.
func _face_and_hold(body: Player, yaw: float, frames: int) -> void:
	body.rotation.y = yaw
	body.camera.rotation.x = 0.0
	Input.action_press("move_forward", 1.0)
	for _i in frames:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
