extends Node
## A RAILWAY WITH POINTS IN IT (`make godot-rail-network`).
##
## H-RAIL-BREADTH, the engine half of DESS-01 items 1 and 2: a carrier
## that runs a network rather than one ordered route, and a switch whose
## position selects which track is live (`RailNetworkCarrier`,
## `RailPoints`). What each case asks is the packet's own list (P17.2-4,
## O05-16.2): physical branch selection; occupied points; unavailable
## links; conflicting commands; recall from every dock, including from
## another branch; safe holds; restoration -- and no motion anywhere the
## rail does not run.
##
## **HAND-STEPPED, like `godot-rail-carrier`.** `sync_to_physics` makes a
## carrier's `global_position` the physics server's opinion of last frame,
## so every case steps the points and the carrier itself and asserts on
## `pose()` and `offset`, which are what the carrier knows.
##
## **NO TELEPORTING.** Every journey records the largest distance the
## carrier moved in a single frame, and it is held to the fastest it
## travels (`JUMP`). A change of line at the points that jumped, or a
## recall that put the carrier somewhere by assignment, would show here.
##
## **WHAT THIS IS NOT.** The networks here are declaration-shaped
## dictionaries laid by `RailNetworkCarrier.lay_out` -- the shape a Zone
## would carry once it can declare a switch -- but no Zone declares one
## yet (the schema half is Dess's: DESS-01 items 3-5). So this proves the
## runtime, and says nothing about a composed occurrence.

const STEP := 1.0 / 60.0
const DECK := Vector3(4.0, 0.4, 4.0)
const THEME := "concrete_facility"
## Frames any one journey may take before it counts as stuck.
const BUDGET := 3000
## Frames for a throw to finish: the actuator's 2.0 s, and a margin.
const THROW := 150
## The most a carrier may move in one frame: its top speed, and room for
## a frame of rounding.
const JUMP := RailCarrier.SPEED * STEP * 1.5
## The most the deck's facing may turn in one frame. A curve at top speed
## turns it a degree or two; a kink at the points, or two lines meeting
## head to head with the deck facing each in turn, turns it tens of
## degrees at once, and `sync_to_physics` hands that to its passengers.
const TURN := 3.0

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
	_refusals()
	_branch_selection()
	_points_against()
	_route_lock()
	_conflicts()
	_unavailable_link()
	_recall_everywhere()
	_two_switches()
	_safe_hold_and_power()
	_unpowered_ordered_carrier()
	_reset_honours_clearance()
	_whole_steps_of_rail()
	_restore()
	_ordered_equivalence()
	_levers()
	_finish()


# ---------------------------------------------------------------------------
# The network under test
# ---------------------------------------------------------------------------

## A Y with a longer leg: T - S, then points beyond S dividing to A1 (and
## on to A2) and B1. Every dock is a room's width or more from the next.
func _y_docks() -> Array:
	return [
		{"dock_id": "T", "at": Vector3(0.0, 0.0, 0.0)},
		{"dock_id": "S", "at": Vector3(20.0, 0.0, 0.0)},
		{"dock_id": "A1", "at": Vector3(46.0, 0.0, -14.0)},
		{"dock_id": "A2", "at": Vector3(70.0, 0.0, -20.0)},
		{"dock_id": "B1", "at": Vector3(46.0, 0.0, 14.0)},
	]


func _y_spans(leg_a_open := true) -> Array:
	return [
		{"span_id": "ts", "from_dock": "T", "to_dock": "S",
				"commissioned": true},
		{"span_id": "sa", "from_dock": "S", "to_dock": "A1",
				"commissioned": leg_a_open},
		{"span_id": "aa", "from_dock": "A1", "to_dock": "A2",
				"commissioned": true},
		{"span_id": "sb", "from_dock": "S", "to_dock": "B1",
				"commissioned": true},
	]


func _y_switches(leg := 0) -> Array:
	return [{"switch_id": "p", "dock_id": "S", "legs": ["A1", "B1"],
			"leg": leg}]


func _index_of(id: String) -> int:
	var docks := _y_docks()
	for i in docks.size():
		if str((docks[i] as Dictionary)["dock_id"]) == id:
			return i
	return -1


func _y(home := "S", leg := 0, leg_a_open := true, levers := false) \
		-> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var built := RailNetworkCarrier.build(root, _y_docks(),
			_y_spans(leg_a_open), _y_switches(leg), DECK, THEME,
			_index_of(home), levers)
	_hand_stepped(built)
	built["root"] = root
	return built


func _hand_stepped(built: Dictionary) -> void:
	(built["carrier"] as RailNetworkCarrier).set_physics_process(false)
	for pt: RailPoints in built["points"] as Array[RailPoints]:
		pt.set_physics_process(false)
		if pt.actuator != null:
			pt.actuator.set_physics_process(false)


func _carrier(built: Dictionary) -> RailNetworkCarrier:
	return built["carrier"] as RailNetworkCarrier


func _points(built: Dictionary) -> RailPoints:
	return (built["points"] as Array[RailPoints])[0]


## One frame of the whole railway.
func _tick(built: Dictionary) -> void:
	for pt: RailPoints in built["points"] as Array[RailPoints]:
		pt.advance(STEP)
	_carrier(built).advance(STEP)


func _ticks(built: Dictionary, frames: int) -> void:
	for _i in frames:
		_tick(built)


## Run until the carrier is at rest with no call waiting, recording the
## largest single-frame move. `{"frames": n or -1, "jump": m}`.
func _settle(built: Dictionary, budget := BUDGET) -> Dictionary:
	var carrier := _carrier(built)
	var worst := 0.0
	var turn := 0.0
	var last := carrier.pose()
	for i in budget:
		_tick(built)
		var now := carrier.pose()
		worst = maxf(worst, now.origin.distance_to(last.origin))
		turn = maxf(turn, rad_to_deg(now.basis.z.angle_to(last.basis.z)))
		last = now
		if not carrier.travelling() and carrier.call_state() != "queued":
			return {"frames": i + 1, "jump": worst, "turn": turn}
	return {"frames": -1, "jump": worst, "turn": turn}


## Every refusal a carrier makes, as `[reason, detail]`.
func _refusals_of(carrier: RailCarrier) -> Array:
	var out: Array = []
	carrier.refused.connect(func(reason: String, detail: String) -> void:
		out.append([reason, detail]))
	return out


func _last_reason(trail: Array) -> String:
	return str((trail.back() as Array)[0]) if not trail.is_empty() else ""


func _last_detail(trail: Array) -> String:
	return str((trail.back() as Array)[1]) if not trail.is_empty() else ""


func _at(built: Dictionary, id: String) -> bool:
	var carrier := _carrier(built)
	return carrier.at_dock() == carrier.dock_index(id)


func _gone(built: Dictionary) -> void:
	(built["root"] as Node).queue_free()


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

## THE SHAPE A DECLARATION BECOMES.
func _shape() -> void:
	print("  -- SHAPE: a fork laid from its declaration")
	var laid := RailNetworkCarrier.lay_out(_y_docks(), _y_spans(),
			_y_switches())
	var refused: Array = laid.get("refused", []) as Array
	_check(refused.is_empty(), "the Y network lays out (%s)" % str(refused))
	if not refused.is_empty():
		return
	var lines: Array[Dictionary] = laid["lines"]
	var specs: Array[Dictionary] = laid["points"]
	_check(lines.size() == 3 and specs.size() == 1,
			"…as three lines -- the heel and two legs -- meeting at one set "
			+ "of points (%d lines)" % lines.size())
	var p: Vector3 = specs[0]["at"]
	_check(absf(p.distance_to(Vector3(20.0, 0.0, 0.0))
			- RailNetworkCarrier.POINTS_LEAD) < 0.001,
			"the points stand %.1f m beyond the fork dock S"
			% RailNetworkCarrier.POINTS_LEAD)
	var nearest := INF
	for raw: Variant in _y_docks():
		nearest = minf(nearest, ((raw as Dictionary)["at"] as Vector3)
				.distance_to(p))
	_check(nearest >= Constants.RAIL_SWITCH_CLEARANCE_M,
			"…and no dock stands inside their %.1f m clearance (nearest "
			% Constants.RAIL_SWITCH_CLEARANCE_M + "%.1f m): a parked "
			% nearest + "carrier never holds the points")
	# DIRECTION ON EACH SIDE OF THE POINTS, over 2 cm: a kink shows at any
	# scale, and a curve's own bend over 2 cm is a fraction of a degree.
	var heel: Vector2i = specs[0]["heel"]
	var legs: Array[Vector2i] = specs[0]["legs"]
	var heel_rail: RailPath = lines[heel.x]["path"]
	var at_end := heel.y == RailNetworkCarrier.END
	var into := heel_rail.length() if at_end else 0.0
	var heel_at := heel_rail.at(into)
	var heel_dir := (heel_at - heel_rail.at(into - 0.02 if at_end
			else into + 0.02)).normalized()
	var worst_gap := 0.0
	var worst_turn := 0.0
	for leg: Vector2i in legs:
		var rail: RailPath = lines[leg.x]["path"]
		var leaves_start := leg.y == RailNetworkCarrier.START
		var from := 0.0 if leaves_start else rail.length()
		var out := (rail.at(from + 0.02 if leaves_start else from - 0.02)
				- rail.at(from)).normalized()
		worst_gap = maxf(worst_gap, rail.at(from).distance_to(heel_at))
		worst_turn = maxf(worst_turn, rad_to_deg(out.angle_to(heel_dir)))
	_check(worst_gap < 0.001 and worst_turn < 1.0,
			"every leg starts where the heel ends (%.4f m) and in the "
			% worst_gap + "direction it arrives (%.2f deg): a change of "
			% worst_turn + "line at the points is neither a jump nor a jolt")


## A DECLARATION THE CARRIER CANNOT RUN IS REFUSED BY NAME.
func _refusals() -> void:
	print("  -- REFUSALS: what is not a network says why")
	var loop := _y_spans()
	loop.append({"span_id": "ab", "from_dock": "A1", "to_dock": "B1"})
	_refused_with(RailNetworkCarrier.lay_out(_y_docks(), loop,
			_y_switches()), "one tree", "a loop")
	_refused_with(RailNetworkCarrier.lay_out(_y_docks(), _y_spans(), []),
			"declares no switch", "track dividing at S with no switch")
	var close := _y_docks()
	(close[2] as Dictionary)["at"] = Vector3(36.0, 0.0, -4.0)
	_refused_with(RailNetworkCarrier.lay_out(close, _y_spans(),
			_y_switches()), "inside the 10.0 m clearance",
			"a leg dock inside the points' clearance")
	_refused_with(RailNetworkCarrier.lay_out(_y_docks(), _y_spans(),
			[{"switch_id": "p", "dock_id": "S", "legs": ["A1"]}]),
			"at least two", "a switch with one leg")
	var back := _y_docks()
	(back[0] as Dictionary)["at"] = Vector3(60.0, 0.0, 0.0)
	_refused_with(RailNetworkCarrier.lay_out(back, _y_spans(),
			_y_switches()), "double back",
			"a heel that arrives from beyond the legs")
	var root := Node3D.new()
	add_child(root)
	var built := RailNetworkCarrier.build(root, _y_docks(), loop,
			_y_switches(), DECK, THEME)
	var carrier := _carrier(built)
	carrier.set_physics_process(false)
	var trail := _refusals_of(carrier)
	_check(not carrier.request(RailCarrier.FORWARD)
			and _last_reason(trail) == "not_a_railway"
			and (built["track"] as Array).is_empty(),
			"a refused network is still built as a carrier, lays no track, "
			+ "and refuses every command saying why")
	root.queue_free()


func _refused_with(laid: Dictionary, phrase: String, what: String) -> void:
	var said := "; ".join(PackedStringArray(laid.get("refused", []) as Array))
	_check(said.contains(phrase), "%s is refused by name ('%s')"
			% [what, said.left(110)])


## P17.2: THE POINTS DECIDE, AND THE POINTS ARE TRACK.
func _branch_selection() -> void:
	print("  -- BRANCH SELECTION: throwing the points moves track")
	var y := _y("S", 0)
	var carrier := _carrier(y)
	var pt := _points(y)
	var trail := _refusals_of(carrier)
	_check(_at(y, "S") and pt.live_leg() == 0,
			"parked at S, the points set for A1")
	var heel_line := carrier.line
	_check(carrier.request(RailCarrier.FORWARD), "FORWARD from S is taken")
	var ran := _settle(y)
	_check(_at(y, "A1") and carrier.line != heel_line
			and float(ran["jump"]) <= JUMP and float(ran["turn"]) <= TURN,
			"…and the carrier arrives at A1, changing line at the points "
			+ "with no step longer than %.3f m (largest %.3f m) and no "
			% [JUMP, float(ran["jump"])] + "turn of the deck over %.1f deg "
			% TURN + "in a frame (largest %.2f)" % float(ran["turn"]))
	carrier.request(RailCarrier.BACK)
	_settle(y)
	_check(_at(y, "S"), "…and BACK brings it to S again")
	var tongue := pt.get_node("Tongue") as Node3D
	var was := -tongue.global_transform.basis.z
	var said := pt.throw_to(1)
	_check(said == "set" and pt.set_leg() == 1 and pt.live_leg() == -1,
			"a throw to B1 from S applies at once ('%s') and, until the "
			% said + "tongue arrives, joins neither leg")
	var before := carrier.offset
	var went := carrier.request(RailCarrier.FORWARD)
	_ticks(y, 30)
	_check(not went and _last_reason(trail) == "points_moving"
			and is_equal_approx(carrier.offset, before),
			"…so FORWARD is refused ('%s') and nothing moves"
			% _last_detail(trail))
	_ticks(y, THROW)
	var now := -tongue.global_transform.basis.z
	var swung := rad_to_deg(was.angle_to(now))
	_check(pt.live_leg() == 1 and swung > 3.0
			and tongue.global_transform.is_equal_approx(pt.actuator.path[1]),
			"the tongue MOVED -- it swung %.1f deg onto B1's leg and locked "
			% swung + "there: the track changed, not a flag")
	_check(carrier.request(RailCarrier.FORWARD), "FORWARD from S is taken")
	ran = _settle(y)
	var b1: Vector3 = (_y_docks()[_index_of("B1")] as Dictionary)["at"]
	var flat := carrier.pose().origin - b1
	flat.y = 0.0
	_check(_at(y, "B1") and flat.length() < 0.1
			and float(ran["jump"]) <= JUMP and float(ran["turn"]) <= TURN,
			"…and now it runs to B1 and stands on B1's track (%.3f m off "
			% flat.length() + "it): the carrier follows the tongue")
	_gone(y)


## ARRIVING ON A LEG THE POINTS ARE NOT SET FOR.
func _points_against() -> void:
	print("  -- POINTS AGAINST: a leg that ends at the tongue")
	var y := _y("B1", 1)
	var carrier := _carrier(y)
	var pt := _points(y)
	var trail := _refusals_of(carrier)
	var said := pt.throw_to(0)
	_ticks(y, THROW)
	_check(said == "set" and pt.live_leg() == 0,
			"from B1, 20 m off, the points are thrown to A1 at once")
	var before := carrier.offset
	var went := carrier.request(RailCarrier.BACK)
	_ticks(y, 60)
	_check(not went and _last_reason(trail) == "points_against"
			and _last_detail(trail).contains("set for A1")
			and is_equal_approx(carrier.offset, before),
			"BACK from B1 is refused ('%s'): it is not routed onto the "
			% _last_detail(trail) + "other leg, and nothing moves")
	_gone(y)


## §21.6, AND RB-F1: A CARRIER COMMITTED TO THE POINTS HOLDS THEM.
func _route_lock() -> void:
	print("  -- ROUTE LOCK: occupied and committed points (§21.6, RB-F1)")
	var y := _y("S", 0)
	var carrier := _carrier(y)
	var pt := _points(y)
	carrier.request(RailCarrier.FORWARD)
	_ticks(y, 3)
	var gap := carrier.pose().origin.distance_to(pt.global_position)
	_check(gap >= Constants.RAIL_SWITCH_CLEARANCE_M,
			"three frames out, the carrier is %.2f m from the points -- "
			% gap + "outside §21.6's clearance, so distance alone would "
			+ "let a throw through")
	var said := pt.throw_to(1)
	_check(said == "queued" and pt.set_leg() == 0 and pt.queued_leg() == 1,
			"…but it is committed to them, so the throw to B1 is QUEUED "
			+ "('%s'), never dropped" % said)
	var ran := _settle(y)
	_check(_at(y, "A1") and int(ran["frames"]) > 0,
			"…and the carrier arrives at A1, the route it was sent on")
	_ticks(y, THROW)
	_check(pt.set_leg() == 1 and pt.live_leg() == 1 and pt.queued_leg() == -1,
			"…and once it is clear the queued throw applies: the points "
			+ "go to B1")
	_gone(y)

	# PAST THE POINTS, STILL WITHIN THE CLEARANCE: distance holds them.
	var z := _y("S", 0)
	var c2 := _carrier(z)
	var p2 := _points(z)
	c2.request(RailCarrier.FORWARD)
	var passed := false
	for _i in BUDGET:
		_tick(z)
		if c2.line != c2.dock_line[c2.dock_index("S")] \
				and c2.pose().origin.distance_to(p2.global_position) > 3.0:
			passed = true
			break
	var said2 := p2.throw_to(1)
	_check(passed and said2 == "queued" and c2.holding().is_empty(),
			"3 m beyond the points, no longer committed to them, the "
			+ "carrier still holds them by §21.6's distance: '%s'" % said2)
	_settle(z)
	_ticks(z, THROW)
	_check(_at(z, "A1") and p2.live_leg() == 1,
			"…and the throw applies once it is clear of them")
	_gone(z)

	# CONTROL: THE LOCK OFF, which is §21.6's distance rule alone.
	var w := _y("S", 0)
	var c3 := _carrier(w)
	var p3 := _points(w)
	c3.route_lock = false
	var trail := _refusals_of(c3)
	c3.request(RailCarrier.FORWARD)
	_ticks(w, 3)
	var said3 := p3.throw_to(1)
	_settle(w)
	var at_points := c3.pose().origin.distance_to(p3.global_position)
	_check(said3 == "set" and c3.at_dock() < 0
			and _last_reason(trail) == "points_moved" and at_points < 1.0,
			"CONTROL (the lock off -- the distance rule alone): the same "
			+ "throw applies at once ('%s'), and the carrier is stopped " % said3
			+ "dead at the points (%.2f m from them): the defect RB-F1 names"
			% at_points)
	_gone(w)


## CONFLICTING COMMANDS.
func _conflicts() -> void:
	print("  -- CONFLICTS: two commands at once, and a hand on the lever")
	var y := _y("S", 0)
	var carrier := _carrier(y)
	var controls := RailControls.create(carrier)
	(y["root"] as Node).add_child(controls)
	controls.set_physics_process(false)
	var forward := RailReceiver.create(RailCarrier.FORWARD, 0)
	var back := RailReceiver.create(RailCarrier.BACK, 1)
	(y["root"] as Node).add_child(forward)
	(y["root"] as Node).add_child(back)
	controls.add(forward)
	controls.add(back)
	var said: Array = []
	controls.refused.connect(func(reason: String, _d: String) -> void:
		said.append(reason))
	var before := carrier.offset
	forward.commanded.emit(RailCarrier.FORWARD)
	back.commanded.emit(RailCarrier.BACK)
	controls.resolve()
	_ticks(y, 60)
	_check(said.has("conflicting") and is_equal_approx(carrier.offset, before),
			"FORWARD and BACK in the same moment: the network does neither, "
			+ "and says so")
	_gone(y)

	# A CALL WAITING ON THE POINTS, AND SOMEONE THROWS THEM BACK.
	var z := _y("S", 1)
	var c2 := _carrier(z)
	var p2 := _points(z)
	var states: Array = []
	c2.call_changed.connect(func(_d: String, state: String, _x: String) -> void:
		states.append(state))
	c2.call_to(c2.dock_index("A1"))
	_ticks(z, 20)
	var waiting := c2.call_state() == "queued" and p2.set_leg() == 0
	p2.throw_to(1)
	_ticks(z, THROW)
	_check(waiting and c2.call_state() == "cancelled" and _at(z, "S")
			and c2.call_detail().contains("thrown"),
			"a call waiting for the points to reach A1 is CANCELLED, not "
			+ "fought, when a hand throws them back ('%s')" % c2.call_detail())
	_gone(z)


## A LEG WITHOUT TRACK REFUSES, AND ONLY THAT LEG.
func _unavailable_link() -> void:
	print("  -- UNAVAILABLE LINK: missing track on one leg")
	var y := _y("S", 0, false)
	var carrier := _carrier(y)
	var pt := _points(y)
	var trail := _refusals_of(carrier)
	var before := carrier.offset
	var went := carrier.request(RailCarrier.FORWARD)
	_ticks(y, 60)
	_check(not went and _last_reason(trail) == "no_link"
			and _last_detail(trail).contains("span sa")
			and is_equal_approx(carrier.offset, before),
			"the points set for A1 but S-A1 not commissioned: FORWARD is "
			+ "refused ('%s') and nothing moves" % _last_detail(trail))
	var called := carrier.call_to(carrier.dock_index("A2"))
	_check(not called and carrier.call_state() == "refused"
			and carrier.call_detail().contains("span sa"),
			"…and a call from A2, beyond it, is refused before anything "
			+ "moves ('%s')" % carrier.call_detail())
	pt.throw_to(1)
	_ticks(y, THROW)
	carrier.request(RailCarrier.FORWARD)
	_settle(y)
	_check(_at(y, "B1"), "…while the other leg runs: aligning one leg "
			+ "can never lay the other, and missing one blocks only it")
	carrier.request(RailCarrier.BACK)
	_settle(y)
	pt.throw_to(0)
	_ticks(y, THROW)
	# COMMISSIONED THE WAY A PLAYER DOES IT: a span on that edge, through
	# the junction, locking home.
	var junction := RailJunction.create(carrier, "net")
	(y["root"] as Node).add_child(junction)
	var e := carrier.edge_between(carrier.dock_index("S"),
			carrier.dock_index("A1"))
	var span := RailSpan.create("sa_latch", e, 18.0, THEME)
	(y["root"] as Node).add_child(span)
	span.set_physics_process(false)
	junction.add(span, null)
	var fired: Array = []
	junction.latch_fired.connect(func(_p: String, latch: String) -> void:
		fired.append(latch))
	span.begin()
	for _i in 240:
		span.advance(STEP)
	_check(span.locked and carrier.commissioned[e] and fired == ["sa_latch"],
			"a span on that leg locks home through the junction, which "
			+ "commissions exactly edge %d and reports its latch once" % e)
	carrier.request(RailCarrier.FORWARD)
	_settle(y)
	_check(_at(y, "A1"), "…and FORWARD from S now reaches A1")
	_gone(y)


## P17.3: RECALL FROM EVERY DOCK, INCLUDING FROM ANOTHER BRANCH.
func _recall_everywhere() -> void:
	print("  -- RECALL: every dock calls, from every other dock")
	var ids := ["T", "S", "A1", "A2", "B1"]
	var passed := 0
	var total := 0
	var worst := 0.0
	var turned := 0.0
	var failed: Array[String] = []
	var b1_to_a2: Array = []
	var b1_to_a2_states: Array = []
	for i in ids.size():
		for j in ids.size():
			if i == j:
				continue
			total += 1
			var from: String = ids[i]
			var to: String = ids[j]
			# The points start wherever the pair's parity puts them, so
			# half the calls have to throw them on the way.
			var y := _y(from, (i + j) % 2)
			var carrier := _carrier(y)
			var arrivals: Array = []
			var states: Array = []
			carrier.arrived.connect(func(d: String) -> void: arrivals.append(d))
			carrier.call_changed.connect(
					func(_d: String, state: String, _x: String) -> void:
						states.append(state))
			var took := carrier.call_to(carrier.dock_index(to))
			var ran := _settle(y, BUDGET * 2)
			worst = maxf(worst, float(ran["jump"]))
			turned = maxf(turned, float(ran["turn"]))
			if took and _at(y, to) and carrier.call_state() == "completed" \
					and float(ran["jump"]) <= JUMP \
					and float(ran["turn"]) <= TURN:
				passed += 1
			else:
				failed.append("%s->%s (%s: %s)" % [from, to,
						carrier.call_state(), carrier.call_detail()])
			if from == "B1" and to == "A2":
				b1_to_a2 = arrivals
				b1_to_a2_states = states
			_gone(y)
	_check(passed == total,
			"a player at each of the five docks calls the carrier from each "
			+ "of the other four: %d of %d arrive, no step longer than " % [
				passed, total] + "%.3f m (largest %.3f m), no turn over " % [
				JUMP, worst] + "%.1f deg a frame (largest %.2f) %s" % [TURN,
				turned, str(failed)])
	_check(b1_to_a2 == ["S", "A2"],
			"from B1 to A2 -- another branch -- it stops only where the route "
			+ "turns back, at S, and runs through A1 without stopping "
			+ "(stops: %s)" % str(b1_to_a2))
	_check(b1_to_a2_states.has("queued") and b1_to_a2_states.has("executing")
			and b1_to_a2_states.back() == "completed",
			"…reporting its states as it goes: %s" % str(b1_to_a2_states))


## TWO SWITCHES WHOSE LEGS MEET: a leg that is a leg at both ends.
##
## T1 - S1, points P1 dividing to A and M; T2 - S2, points P2 dividing to
## M and B. M's track runs from P1 to P2 and is a leg of both, so the
## line it lies on meets P2 head to head with P2's heel: their own
## directions are opposite there, and a deck that faced its line would
## turn half a circle crossing it.
func _two_docks() -> Array:
	return [
		{"dock_id": "T1", "at": Vector3(-20.0, 0.0, 0.0)},
		{"dock_id": "S1", "at": Vector3(0.0, 0.0, 0.0)},
		{"dock_id": "A", "at": Vector3(26.0, 0.0, -14.0)},
		{"dock_id": "M", "at": Vector3(26.0, 0.0, 14.0)},
		{"dock_id": "S2", "at": Vector3(52.0, 0.0, 28.0)},
		{"dock_id": "B", "at": Vector3(26.0, 0.0, 42.0)},
		{"dock_id": "T2", "at": Vector3(72.0, 0.0, 28.0)},
	]


func _two_switches() -> void:
	print("  -- TWO SWITCHES: legs that meet, head to head")
	var spans: Array = []
	for pair: Array in [["T1", "S1"], ["S1", "A"], ["S1", "M"], ["S2", "M"],
			["S2", "B"], ["T2", "S2"]]:
		spans.append({"span_id": "%s_%s" % [pair[0], pair[1]],
				"from_dock": pair[0], "to_dock": pair[1]})
	var switches := [
		{"switch_id": "p1", "dock_id": "S1", "legs": ["A", "M"]},
		{"switch_id": "p2", "dock_id": "S2", "legs": ["M", "B"]},
	]
	var laid := RailNetworkCarrier.lay_out(_two_docks(), spans, switches)
	var refused: Array = laid.get("refused", []) as Array
	_check(refused.is_empty(), "two switches whose legs meet at M lay out "
			+ "(%s)" % str(refused))
	if not refused.is_empty():
		return
	var ids: Array[String] = []
	for raw: Variant in _two_docks():
		ids.append(str((raw as Dictionary)["dock_id"]))
	var passed := 0
	var total := 0
	var worst := 0.0
	var turned := 0.0
	var failed: Array[String] = []
	var across: Array = []
	for i in ids.size():
		for j in ids.size():
			if i == j:
				continue
			total += 1
			var root := Node3D.new()
			add_child(root)
			var built := RailNetworkCarrier.build(root, _two_docks(), spans,
					switches, DECK, THEME, i)
			_hand_stepped(built)
			built["root"] = root
			var carrier := _carrier(built)
			var arrivals: Array = []
			carrier.arrived.connect(func(d: String) -> void: arrivals.append(d))
			var took := carrier.call_to(j)
			var ran := _settle(built, BUDGET * 3)
			worst = maxf(worst, float(ran["jump"]))
			turned = maxf(turned, float(ran["turn"]))
			if took and carrier.at_dock() == j \
					and carrier.call_state() == "completed" \
					and float(ran["jump"]) <= JUMP \
					and float(ran["turn"]) <= TURN:
				passed += 1
			else:
				failed.append("%s->%s (%s: %s, turn %.1f)" % [ids[i], ids[j],
						carrier.call_state(), carrier.call_detail(),
						float(ran["turn"])])
			if ids[i] == "T1" and ids[j] == "T2":
				across = arrivals
			root.queue_free()
	_check(passed == total,
			"every dock calls the carrier from every other: %d of %d arrive "
			% [passed, total] + "through one set of points or both, no step "
			+ "over %.3f m (largest %.3f m), no turn over %.1f deg a " % [
				JUMP, worst, TURN] + "frame (largest %.2f) %s" % [turned,
				str(failed)])
	_check(across == ["T2"],
			"T1 to T2 crosses both sets of points and M in one run (stops: %s)"
			% str(across))


## P17.3: SAFE HOLDS AND POWER.
func _safe_hold_and_power() -> void:
	print("  -- HOLDS: power loss and the fail-safe stop, on a network")
	var y := _y("S", 0)
	var carrier := _carrier(y)
	var pt := _points(y)
	var trail := _refusals_of(carrier)
	carrier.request(RailCarrier.FORWARD)
	for _i in BUDGET:
		_tick(y)
		if carrier.pose().origin.distance_to(pt.global_position) < 6.0:
			break
	carrier.power(false)
	var held_at := carrier.offset
	_ticks(y, 180)
	_check(is_equal_approx(carrier.offset, held_at),
			"power lost 6 m short of the points: the carrier holds there")
	var said := pt.throw_to(1)
	_check(said == "queued",
			"…and the points it is committed to stay locked through the "
			+ "outage: a throw is QUEUED ('%s')" % said)
	var went := carrier.request(RailCarrier.BACK)
	_ticks(y, 60)
	_check(not went and _last_reason(trail) == "unpowered"
			and is_equal_approx(carrier.offset, held_at),
			"…and a command with no power is refused, not driven")
	carrier.power(true)
	_settle(y)
	_check(_at(y, "A1"), "power restored, it carries on to A1, the route "
			+ "it left on")
	_ticks(y, THROW)
	_check(pt.live_leg() == 1, "…and the queued throw applies behind it")
	_gone(y)

	# THE FAIL-SAFE STOP beyond the points, and the points thrown behind.
	var z := _y("S", 0)
	var c2 := _carrier(z)
	var p2 := _points(z)
	var trail2 := _refusals_of(c2)
	c2.request(RailCarrier.FORWARD)
	for _i in BUDGET:
		_tick(z)
		if c2.line != c2.dock_line[c2.dock_index("S")] \
				and c2.pose().origin.distance_to(p2.global_position) > 12.0:
			break
	c2.hold(true)
	var stopped := c2.offset
	_ticks(z, 60)
	_check(is_equal_approx(c2.offset, stopped) and c2.at_dock() < 0,
			"a fail-safe stop holds the carrier on the leg, 12 m past the "
			+ "points")
	var thrown := p2.throw_to(1)
	_ticks(z, THROW)
	c2.hold(false)
	var back_ok := c2.request(RailCarrier.BACK)
	_check(thrown == "set" and not back_ok
			and _last_reason(trail2) == "points_against",
			"…the points are thrown behind it, and released it may not go "
			+ "back through them: the track behind it ends at the tongue "
			+ "('%s')" % _last_detail(trail2))
	p2.throw_to(0)
	_ticks(z, THROW)
	_check(c2.request(RailCarrier.BACK), "…set back, BACK is taken")
	_settle(z)
	_check(_at(z, "S"), "…and it returns to S")
	_gone(z)

	# STRANDED, THEN CALLED.
	var w := _y("S", 0)
	var c3 := _carrier(w)
	c3.request(RailCarrier.FORWARD)
	_ticks(w, 90)
	c3.hold(true)
	c3.hold(false)
	var took := c3.call_to(c3.dock_index("T"))
	var ran := _settle(w)
	_check(took and _at(w, "T") and float(ran["jump"]) <= JUMP,
			"stranded between docks by a hold, a call still brings it home "
			+ "to T")
	_gone(w)


## RB-F3: THE ORDERED CARRIER, UNPOWERED, MOVED ON COMMAND.
func _unpowered_ordered_carrier() -> void:
	print("  -- RB-F3: an unpowered ordered carrier")
	var rail := RailPath.from_points(PackedVector3Array([
			Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(40, 0, 0)]))
	var carrier := RailCarrier.create(rail, PackedFloat32Array([0.0,
			rail.curve().get_closest_offset(Vector3(20, 0, 0)),
			rail.length()]), PackedStringArray(["d0", "d1", "d2"]),
			[true, true] as Array[bool], DECK, THEME)
	add_child(carrier)
	carrier.set_physics_process(false)
	var trail := _refusals_of(carrier)
	carrier.power(false)
	var took := carrier.request(RailCarrier.FORWARD)
	for _i in 240:
		carrier.advance(STEP)
	_check(not took and _last_reason(trail) == "unpowered"
			and is_equal_approx(carrier.offset, 0.0),
			"with no power, a travel command is refused and the carrier does "
			+ "not move (offset %.3f m)" % carrier.offset)
	carrier.power(true)
	_check(carrier.request(RailCarrier.FORWARD), "…power restored, it is taken")
	for _i in BUDGET:
		if carrier.heading == RailCarrier.HOLD:
			break
		carrier.advance(STEP)
	_check(carrier.at_dock() == 1, "…and it runs to the next dock")
	carrier.queue_free()


## RB-F2: A RESET MOVED A RAIL SWITCH UNDER WHATEVER WAS ON IT.
func _reset_honours_clearance() -> void:
	print("  -- RB-F2: a rail switch's reset is a branch change")
	var poses: Array[Transform3D] = [Transform3D(Basis(), Vector3.ZERO),
			Transform3D(Basis(Vector3.UP, 0.3), Vector3.ZERO)]
	var sw := Actuator.create("RAIL_SWITCH", poses, 1.0)
	add_child(sw)
	sw.set_physics_process(false)
	sw.restore_branch(1)
	var rider := Node3D.new()
	add_child(rider)
	rider.global_position = Vector3(4.0, 0.0, 0.0)
	sw.rail_actors = [rider]
	sw.reset()
	for _i in 120:
		sw.advance(STEP)
	_check(is_equal_approx(sw.t, 1.0) and sw.branch() == 1
			and sw.queued_branch() == 0,
			"with an actor 4 m from the junction, a reset is QUEUED like any "
			+ "throw and the tongue stays put (t %.2f, branch %d)"
			% [sw.t, sw.branch()])
	rider.global_position = Vector3(20.0, 0.0, 0.0)
	for _i in 120:
		sw.advance(STEP)
	_check(sw.branch() == 0 and is_equal_approx(sw.t, 0.0),
			"…and applies once the rail is clear (t %.2f)" % sw.t)
	sw.restore_branch(1)
	sw.lock_route(self, true)
	sw.reset()
	for _i in 120:
		sw.advance(STEP)
	var held := is_equal_approx(sw.t, 1.0)
	sw.lock_route(self, false)
	for _i in 120:
		sw.advance(STEP)
	_check(held and sw.branch() == 0 and is_equal_approx(sw.t, 0.0),
			"…and a route lock holds a reset exactly as a present actor does")
	rider.queue_free()
	sw.queue_free()


## RB-F5: A FLAT RAIL REFUSED AS A 90-DEGREE PITCH.
##
## Found by `_two_switches`: the heel line T1-S1-P1 there is a straight
## 31 m, a whole number of 0.2 m steps, and `RailPath.polyline` doubled
## its last sample. Held here on its own, on rails of every length from
## 30 to 32 m in centimetres, so any length that lands on a step is met.
func _whole_steps_of_rail() -> void:
	print("  -- RB-F5: a rail whose length is a whole number of steps")
	var refused := 0
	var degenerate := 0
	var shortest := INF
	for cm in range(3000, 3201):
		var reach := float(cm) / 100.0
		var rail := RailPath.from_points(PackedVector3Array([
				Vector3(-20.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0),
				Vector3(reach - 20.0, 0.0, 0.0)]))
		if not rail.violations("rail").is_empty():
			refused += 1
		var walked := rail.polyline()
		for i in walked.size() - 1:
			var run := walked[i].distance_to(walked[i + 1])
			shortest = minf(shortest, run)
			if run < 0.0001:
				degenerate += 1
	_check(refused == 0 and degenerate == 0,
			"201 straight, level rails from 30 to 32 m: none refused (%d) and "
			% refused + "no sampled segment of no length (%d; shortest %.5f m)"
			% [degenerate, shortest])


## P17.4, THE ENGINE HALF: THE SETTING COMES BACK, AND SAYS NOTHING.
func _restore() -> void:
	print("  -- RESTORE: points and carrier rebuilt from saved facts")
	var y := _y("T", 0)
	var carrier := _carrier(y)
	var pt := _points(y)
	var changed: Array = []
	pt.actuator.branch_changed.connect(func(i: int) -> void: changed.append(i))
	pt.actuator.branch_queued.connect(func(i: int) -> void: changed.append(i))
	var moves: Array = []
	carrier.arrived.connect(func(d: String) -> void: moves.append(d))
	carrier.departed.connect(func(d: String, _w: int) -> void: moves.append(d))
	var junction := RailJunction.create(carrier, "net")
	(y["root"] as Node).add_child(junction)
	junction.home_dock = carrier.dock_index("B1")
	var restored := carrier.restore_points({"p": "B1"})
	junction.restore_from([])
	_check(restored == 1 and pt.live_leg() == 1
			and is_equal_approx(pt.actuator.t, 1.0),
			"the points come back set for B1, the tongue already there")
	_check(_at(y, "B1"),
			"…and the carrier parks at the declared home B1, not dock 0")
	_check(changed.is_empty() and moves.is_empty(),
			"…and nothing is reported: a restore is not a throw and not a "
			+ "journey")
	var took := carrier.call_to(carrier.dock_index("T"))
	_settle(y)
	_check(took and _at(y, "T"),
			"…and the restored network runs: a call at T brings it from B1")
	_check(carrier.restore_points({"p": 0}) == 1 and pt.live_leg() == 0,
			"a setting restores by leg index as well as by the leg's dock")
	_gone(y)


## THE ORDERED ROUTE IS A CASE OF THE NETWORK.
func _ordered_equivalence() -> void:
	print("  -- ORDERED: a chain on both carriers")
	var at: Array[Vector3] = [Vector3(0, 0, 0), Vector3(18, 0, 4),
			Vector3(34, 0, -3), Vector3(52, 0, 2)]
	var docks: Array = []
	var ids := PackedStringArray()
	for i in at.size():
		docks.append({"dock_id": "d%d" % i, "at": at[i]})
		ids.append("d%d" % i)
	var spans: Array = []
	for i in range(1, at.size()):
		spans.append({"span_id": "s%d" % i, "from_dock": "d%d" % (i - 1),
				"to_dock": "d%d" % i})
	var root := Node3D.new()
	add_child(root)
	var built := RailNetworkCarrier.build(root, docks, spans, [], DECK, THEME)
	_hand_stepped(built)
	built["root"] = root
	var net := _carrier(built)
	var rail := RailPath.from_points(PackedVector3Array(at))
	var offsets := PackedFloat32Array()
	for point: Vector3 in at:
		offsets.append(rail.curve().get_closest_offset(point))
	var ordered := RailCarrier.create(rail, offsets, ids,
			[true, true, true] as Array[bool], DECK, THEME)
	root.add_child(ordered)
	ordered.set_physics_process(false)
	var worst_offset := 0.0
	var worst_frames := 0
	var same_docks := true
	for command: int in [RailCarrier.FORWARD, RailCarrier.FORWARD,
			RailCarrier.FORWARD, RailCarrier.BACK, RailCarrier.BACK,
			RailCarrier.FORWARD, RailCarrier.BACK, RailCarrier.BACK]:
		var a := net.request(command)
		var b := ordered.request(command)
		var ran := _settle(built)
		var frames := 0
		for i in BUDGET:
			if ordered.heading == RailCarrier.HOLD:
				frames = i
				break
			ordered.advance(STEP)
		same_docks = same_docks and a == b \
				and net.at_dock() == ordered.at_dock()
		worst_offset = maxf(worst_offset, absf(net.offset - ordered.offset))
		worst_frames = maxi(worst_frames, absi(int(ran["frames"]) - frames))
	_check(same_docks and worst_offset < 0.001 and worst_frames <= 1,
			"a chain of four docks and no switch: the network carrier and the "
			+ "ordered carrier stop at the same docks, at the same offsets "
			+ "(largest difference %.5f m), in the same frames (%d)"
			% [worst_offset, worst_frames])
	root.queue_free()


## THE LEVERS: the game's own interact verb.
func _levers() -> void:
	print("  -- LEVERS: call and points, pulled")
	var y := _y("T", 0, true, true)
	var carrier := _carrier(y)
	var pt := _points(y)
	var calls: Array[CallLever] = y["calls"]
	var throws: Array[CallLever] = y["throws"]
	_check(calls.size() == 5 and throws.size() == 1,
			"a CALL lever at each of the five docks and a POINTS lever at "
			+ "the fork")
	var clear := INF
	for i in calls.size():
		var rail: RailPath = carrier.lines[carrier.dock_line[i]]["path"]
		clear = minf(clear, rail.at(carrier.dock_offsets[i])
				.distance_to(calls[i].global_position))
	_check(clear > DECK.x * 0.5 + 1.0,
			"…each standing %.1f m from the track, clear of the deck" % clear)
	calls[carrier.dock_index("A2")].interact(null)
	var state := carrier.call_state()
	_settle(y)
	_check((state == "queued" or state == "executing") and _at(y, "A2"),
			"pulling A2's CALL lever brings the carrier there from T (%s)"
			% state)
	throws[0].interact(null)
	_ticks(y, THROW)
	_check(pt.live_leg() == 1,
			"pulling the POINTS lever throws them to the other leg")
	calls[carrier.dock_index("B1")].interact(null)
	_settle(y)
	_check(_at(y, "B1"), "…and B1's CALL lever brings it over from A2")
	_gone(y)


func _finish() -> void:
	print("  MEASURED %d check(s), %d note(s)" % [_checks, _notes])
	if _failures == 0:
		print("GODOT RAIL NETWORK OK (%d checks)" % _checks)
	else:
		print("GODOT RAIL NETWORK FAILED (%d of %d checks)"
				% [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
