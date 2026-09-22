extends Node
## THE TWELVE ACTUATOR KINDS AND SAFE INTERRUPTION (`make godot-actuator`).
##
## OV04 P15. Amalgam §21: one common contract (§21.1), one power-loss
## table (§21.1.1), and §21.2's interlock — the row this lane has carried
## as a measured delta since the counterfire work (`C4a`).
##
## **THE DEFECT THIS SUITE EXISTS TO PIN.** `ServiceShutter` refused to
## crush anybody, which is the important half, and then stopped where it
## was. §21.2 requires a refused closure to "stop and reverse to fully
## open, then retry after `1.0 s`, repeating indefinitely". A panel
## parked halfway is still narrowing the doorway it was asked to clear.
## The discriminating measurement is `openness()` at the moment of
## refusal: a stop-and-wait shutter holds whatever fraction it had
## reached, and a §21.2 shutter goes back to `1.0`. Several checks below
## assert exactly that number for exactly that reason.
##
## **EVIDENCE CLASSES ARE KEPT APART, as everywhere in this lane.**
##
##   MACHINE ARITHMETIC — an `Actuator` in the tree with its own
##   `_physics_process` off, stepped by hand at a fixed delta. This is
##   the only way to land on a chosen `t` mid-motion and flip an input
##   there, which is what §21.1's reversal rows are about. It proves the
##   transition table and nothing about geometry.
##   PHYSICAL — a real `Area3D` doorway, real bodies in it, real physics
##   frames. This is what §21.2's "would intersect the player or any
##   `required = true` object" has to be measured with, because the
##   interlock's whole subject is a body being somewhere.
##
## **WHAT THIS SUITE DOES NOT CLAIM.** Three of §21's twelve kinds —
## `WINCH`, `BRAKE`, `DRIVER` (§21.10) — drive a constraint solver the
## engine does not have. They are in the vocabulary and in the power-loss
## table, and `Actuator.create` refuses them by name. The last case here
## asserts the refusal rather than pretending at a stub.

const STEP := 1.0 / 60.0

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
	await _the_vocabulary_is_the_documents()
	await _the_transition_table()
	await _reset_animates_back()
	await _the_power_loss_table()
	await _a_lift_travels_to_its_selected_stop()
	await _a_path_machine_rotates()
	await _a_rail_switch_waits_for_clearance()
	await _the_interlock_reverses_to_fully_open()
	await _the_interlock_protects_required_objects()
	await _an_authored_crusher_does_not_reverse()
	await _the_shipped_shutter_obeys_21_2()
	await _the_shipped_carriers_hold_on_power_loss()
	await _the_constraint_kinds_are_refused_by_name()
	print("")
	if _failures == 0:
		print("GODOT ACTUATOR OK (%d checks, %d notes)" % [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT ACTUATOR: %d failures in %d checks" % [_failures, _checks])
	get_tree().quit(1)


## A two-waypoint vertical path, which is what most kinds want.
func _rise(height := 3.0) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.append(Transform3D(Basis(), Vector3.ZERO))
	out.append(Transform3D(Basis(), Vector3(0.0, height, 0.0)))
	return out


## Build one, park it in the tree, and take its clock away so the case
## decides when time passes.
func _made(kind: String, waypoints: Array[Transform3D],
		seconds := 2.0) -> Actuator:
	var made := Actuator.create(kind, waypoints, seconds)
	add_child(made)
	made.set_physics_process(false)
	return made


func _drive(a: Actuator, seconds: float) -> void:
	var frames := int(round(seconds / STEP))
	for _i in frames:
		a.advance(STEP)


# ---------------------------------------------------------------------
# §21.1 / §21.1.1 — the vocabulary
# ---------------------------------------------------------------------

## THE TWELVE ARE TWELVE, and every one has an answer for power loss. A
## table with a hole in it is how a kind ends up silently holding when
## the document says it closes.
func _the_vocabulary_is_the_documents() -> void:
	print("\n-- §21.1: the vocabulary --")
	_check(Constants.ACTUATOR_KINDS.size() == 12,
			"§21.1 declares twelve actuator kinds (%d)"
			% Constants.ACTUATOR_KINDS.size())
	var missing: Array[String] = []
	for kind: String in Constants.ACTUATOR_KINDS:
		if not Constants.ACTUATOR_POWER_LOSS.has(kind):
			missing.append(kind)
	_check(missing.is_empty(),
			"every kind has a §21.1.1 power-loss answer (missing %s)"
			% [missing])
	# The four answers, named. `hold` is the big one on purpose:
	# everything that carries, supports or suspends the player is in it.
	var holds := 0
	for kind: String in Constants.ACTUATOR_POWER_LOSS:
		if str(Constants.ACTUATOR_POWER_LOSS[kind]) == "hold":
			holds += 1
	_check(holds == 7,
			"seven kinds hold on power loss — the five kinematic carriers "
			+ "plus §21.10's WINCH and DRIVER (%d)" % holds)
	_check(str(Constants.ACTUATOR_POWER_LOSS["DOOR"]) == "close",
			"a DOOR closes on power loss, which is safe only because "
			+ "§21.2 makes it safe")
	_check(str(Constants.ACTUATOR_POWER_LOSS["BRAKE"]) == "engage",
			"an unpowered BRAKE engages — fail-safe, the one kind whose "
			+ "power-loss answer ignores its input")


## §21.1'S TRANSITION TABLE, every row that can be measured on a mover.
func _the_transition_table() -> void:
	print("\n-- §21.1: the transition table --")
	var a := _made("PATH_MACHINE", _rise(), 2.0)

	# ROW 1: input ON at t=0 moves toward 1 at 1/travel_time.
	a.set_input(true)
	_drive(a, 1.0)
	_check(absf(a.t - 0.5) < 0.02,
			"ON at t=0 travels at 1/travel_time (t=%.3f after 1.0 s of a "
			% a.t + "2.0 s sweep)")
	_check(a.direction == 1, "…and reports direction +1 while it does")

	# ROW 3: reverse mid-motion. From the CURRENT t, immediately: no
	# snap, no pause, no completion of the leg. The measurement that
	# separates those is the very next frame.
	var at_flip := a.t
	a.set_input(false)
	a.advance(STEP)
	var after := a.t
	_check(after < at_flip and absf(at_flip - after) <= STEP / 2.0 + 1e-4,
			"a reversed input turns round on the NEXT frame from where it "
			+ "was (%.4f -> %.4f, one frame is %.4f)"
			% [at_flip, after, STEP / 2.0])
	_check(a.direction == -1, "…and the direction flips with it")

	# ROW 4: reverse again mid-reversal.
	_drive(a, 0.2)
	var second_flip := a.t
	a.set_input(true)
	a.advance(STEP)
	_check(a.t > second_flip and a.direction == 1,
			"reversing again mid-reversal turns round again (%.4f -> %.4f)"
			% [second_flip, a.t])

	# ROW 2: OFF at t=1 travels back to 0, and arriving is reported once.
	_drive(a, 3.0)
	_check(is_equal_approx(a.t, 1.0) and a.direction == 0,
			"it arrives at t=1 and stops (t=%.4f, direction %d)"
			% [a.t, a.direction])
	# A COUNTER HAS TO BE A REFERENCE TYPE: GDScript lambdas capture
	# locals by value, so an `int` incremented in here would stay 0 out
	# there and the check would be measuring nothing.
	var arrivals: Array[float] = []
	a.arrived.connect(func(at: float) -> void: arrivals.append(at))
	a.set_input(false)
	_drive(a, 3.0)
	_check(is_equal_approx(a.t, 0.0), "OFF at t=1 returns it to t=0")
	_check(arrivals.size() == 1 and is_equal_approx(arrivals[0], 0.0),
			"arrival is reported once rather than every frame it sits "
			+ "there (%s)" % [arrivals])
	a.queue_free()


## §21.1'S RESET ROW: "it animates back; it does not teleport." The
## distinction is the whole row, so it is measured frame by frame.
func _reset_animates_back() -> void:
	print("\n-- §21.1: reset mid-motion --")
	var a := _made("PATH_MACHINE", _rise(), 2.0)
	a.initial_t = 0.25
	a.t = 0.25
	a.set_input(true)
	_drive(a, 1.0)
	var from := a.t
	a.reset()
	a.advance(STEP)
	var one_frame := a.t
	_check(absf(from - one_frame) <= STEP / 2.0 + 1e-4 and one_frame < from,
			"reset moves one frame's worth toward initial_t rather than "
			+ "snapping (%.4f -> %.4f)" % [from, one_frame])
	_check(a.is_resetting(), "…and says it is resetting while it travels")
	_drive(a, 2.0)
	_check(absf(a.t - 0.25) < 1e-3,
			"…and settles at initial_t (%.4f)" % a.t)
	# AND STAYS. The input still says ON; an actuator that treated
	# arriving as the end of the reset would set off for t=1 again the
	# moment it got home, and the reset would have reset nothing.
	_check(a.is_resetting(),
			"…and is still in reset, holding there, with its input "
			+ "unchanged")
	_drive(a, 2.0)
	_check(absf(a.t - 0.25) < 1e-3,
			"…two more seconds later, still at initial_t (%.4f)" % a.t)
	a.set_input(true)
	_drive(a, 0.5)
	_check(a.t > 0.3 and not a.is_resetting(),
			"…and the next command is what releases it (%.4f)" % a.t)
	a.queue_free()


## §21.1.1, KIND BY KIND, physically rather than by reading the table
## back. Each one is interrupted MID-MOTION, because that is the case
## the table exists for.
func _the_power_loss_table() -> void:
	print("\n-- §21.1.1: power loss, by kind --")
	for kind: String in ["BRIDGE", "MOVING_PLATFORM", "LIFT",
			"PATH_MACHINE", "RAIL_SWITCH"]:
		var carrier := _made(kind, _rise(), 2.0)
		carrier.set_input(true)
		carrier.select(1)
		carrier.switch_to(1)
		_drive(carrier, 0.8)
		var caught := carrier.t
		carrier.power(false)
		_drive(carrier, 2.0)
		_check(is_equal_approx(carrier.t, caught),
				"%s HOLDS at the t it was caught at (%.4f) — the danger "
				% [kind, caught] + "is the motion itself and no interlock "
				+ "helps with a lift that drops")
		# …and resumes toward what the input commands, from there.
		carrier.power(true)
		_drive(carrier, 2.0)
		_check(is_equal_approx(carrier.t, 1.0),
				"…and power restored resumes it toward the commanded "
				+ "position from where it stopped")
		carrier.queue_free()

	var door := _made("DOOR", _rise(2.4), 2.0)
	door.safe_closure = false  # no interlock in the way of the measurement
	door.set_input(true)
	_drive(door, 2.5)
	door.power(false)
	_drive(door, 2.5)
	_check(is_equal_approx(door.t, 0.0),
			"a DOOR CLOSES on power loss (t=%.4f) even though its input "
			% door.t + "still says open")
	door.queue_free()

	var pad := _made("LAUNCHPAD", _rise(), 0.0)
	_check(pad.is_live(), "a LAUNCHPAD starts live")
	pad.power(false)
	_check(not pad.is_live(),
			"…and becomes INERT GEOMETRY on power loss (§21.7)")
	pad.power(true)
	_check(pad.is_live(), "…and is live again when power returns")
	pad.queue_free()

	var hazard := _made("HAZARD_CONTROLLER", _rise(), 0.0)
	hazard.set_input(true)
	_drive(hazard, 0.5)
	_check(hazard.hazard_running() and hazard.wind_up() > 0.4,
			"a HAZARD_CONTROLLER runs its hazard and winds up (%.2f s)"
			% hazard.wind_up())
	hazard.power(false)
	_check(not hazard.hazard_running() and is_equal_approx(
			hazard.wind_up(), 0.0),
			"…and power loss DISABLES it and clears the wind-up (§21.8) "
			+ "— an unpowered room is not more dangerous than a powered one")
	hazard.power(true)
	_drive(hazard, 0.2)
	_check(hazard.hazard_running() and hazard.wind_up() < 0.3,
			"…and it restarts its cycle rather than resuming a "
			+ "half-charged one (%.2f s)" % hazard.wind_up())
	hazard.queue_free()

	var lamp := _made("LIGHT_CONTROLLER", _rise(), 1.0)
	lamp.set_input(true)
	_drive(lamp, 1.5)
	_check(is_equal_approx(lamp.light_level(), 1.0),
			"a LIGHT_CONTROLLER reaches `lit` over travel_time")
	lamp.power(false)
	_drive(lamp, 1.5)
	_check(is_equal_approx(lamp.light_level(), 0.0),
			"…and TRANSITIONS to `unlit` on power loss (§21.9) rather "
			+ "than snapping, because it is still a travel")
	lamp.queue_free()


## §21.4. The selector is a position, not a direction, and changing it
## mid-travel "redirects immediately from the current position — it does
## not complete its current leg first."
func _a_lift_travels_to_its_selected_stop() -> void:
	print("\n-- §21.4: the lift selector --")
	var stops: Array[Transform3D] = []
	for i in 5:
		stops.append(Transform3D(Basis(), Vector3(0.0, float(i) * 2.0, 0.0)))
	var lift := _made("LIFT", stops, 4.0)
	var reached: Array[int] = []
	lift.stop_reached.connect(func(i: int) -> void: reached.append(i))
	lift.select(2)
	_drive(lift, 5.0)
	_check(lift.at_stop() == 2,
			"a LIFT told stop 2 of five arrives at stop 2 (at %d, t=%.4f)"
			% [lift.at_stop(), lift.t])
	_check(reached.size() == 1 and reached[0] == 2,
			"…and reports the stop it reached, once (%s)" % [reached])
	# REDIRECT MID-TRAVEL. Send it to 4, then change to 0 halfway: the
	# discriminator against "finish the leg" is that it never touches 3.
	lift.select(4)
	_drive(lift, 1.0)
	var mid := lift.t
	lift.select(0)
	lift.advance(STEP)
	_check(lift.t < mid,
			"changing the selector mid-travel redirects from the current "
			+ "position on the next frame (%.4f -> %.4f)" % [mid, lift.t])
	_drive(lift, 5.0)
	_check(lift.at_stop() == 0 and not 3 in reached and not 4 in reached,
			"…and it lands on the new stop without having visited the old "
			+ "one (%s)" % [reached])
	lift.queue_free()


## §21.5. "cranes, rotating machinery, pistons, moving walls" — so the
## path is transforms, and the interpolation has to carry rotation or a
## PATH_MACHINE is only ever a slider with extra words.
func _a_path_machine_rotates() -> void:
	print("\n-- §21.5: the general mover --")
	var arc: Array[Transform3D] = []
	arc.append(Transform3D(Basis(), Vector3.ZERO))
	arc.append(Transform3D(Basis(Quaternion(Vector3.UP, PI / 2.0)),
			Vector3(4.0, 0.0, 0.0)))
	var crane := _made("PATH_MACHINE", arc, 2.0)
	var hook := Node3D.new()
	add_child(hook)
	crane.driven = hook
	crane.set_input(true)
	_drive(crane, 1.0)
	var half := crane.at(0.5)
	_check(absf(half.origin.x - 2.0) < 0.05,
			"a PATH_MACHINE at t=0.5 is halfway along its path (x=%.3f)"
			% half.origin.x)
	var turned := half.basis.get_euler().y
	_check(absf(turned - PI / 4.0) < 0.05,
			"…and halfway through its ROTATION too (%.3f rad of %.3f) — "
			% [turned, PI / 2.0] + "a crane, not a slider")
	_drive(crane, 2.0)
	_check(hook.global_position.distance_to(Vector3(4.0, 0.0, 0.0)) < 0.05,
			"…and it actually places what it drives (%s)"
			% hook.global_position)
	hook.queue_free()
	crane.queue_free()


## §21.6. "The change takes effect only when no actor is on the rail
## within 10.0 m of the junction; otherwise it is QUEUED and applies when
## the rail clears." Queued, not refused: a dropped switch request is how
## a player ends up on a branch nobody asked for.
func _a_rail_switch_waits_for_clearance() -> void:
	print("\n-- §21.6: rail switch clearance --")
	var switch := _made("RAIL_SWITCH", _rise(), 1.0)
	switch.global_position = Vector3.ZERO
	var rider := Node3D.new()
	add_child(rider)
	rider.global_position = Vector3(6.0, 0.0, 0.0)
	switch.rail_actors = [rider]
	var queued: Array[int] = []
	var changed: Array[int] = []
	switch.branch_queued.connect(func(i: int) -> void: queued.append(i))
	switch.branch_changed.connect(func(i: int) -> void: changed.append(i))

	switch.switch_to(1)
	_drive(switch, 0.5)
	_check(switch.branch() == 0 and switch.queued_branch() == 1,
			"an actor 6.0 m from the junction (inside %.1f m) leaves the "
			% Constants.RAIL_SWITCH_CLEARANCE_M
			+ "branch where it was and QUEUES the change")
	_check(queued.size() == 1 and queued[0] == 1 and changed.is_empty(),
			"…and says so, once, rather than silently doing nothing")

	# STILL INSIDE, AT THE EDGE. 9.9 m is on the rail by §21.6's number.
	rider.global_position = Vector3(9.9, 0.0, 0.0)
	_drive(switch, 0.5)
	_check(switch.branch() == 0,
			"…and 9.9 m is still inside the 10.0 m clearance")

	rider.global_position = Vector3(12.0, 0.0, 0.0)
	_drive(switch, 0.5)
	_check(switch.branch() == 1 and switch.queued_branch() == -1,
			"…and the moment the rail clears, the QUEUED change applies "
			+ "(branch %d)" % switch.branch())
	_check(changed.size() == 1 and changed[0] == 1,
			"…reported once, as a change rather than as a new request")
	rider.queue_free()
	switch.queue_free()


# ---------------------------------------------------------------------
# §21.2 — the interlock. Physical evidence from here down.
# ---------------------------------------------------------------------

## A doorway volume with a body standing in it, both real.
func _doorway(at: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.global_position = at
	return area


func _body(at: Vector3, group := "") -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.8, 0.8)
	shape.shape = box
	body.add_child(shape)
	if group != "":
		body.add_to_group(group)
	add_child(body)
	body.global_position = at
	return body


## THE C4a ROW, on the contract. The measurement that separates §21.2
## from "stop and wait" is `t` at the refusal: stopping holds whatever
## fraction it had reached; §21.2 returns it to 1.0.
func _the_interlock_reverses_to_fully_open() -> void:
	print("\n-- §21.2: a refused closure reverses to FULLY OPEN --")
	var door := _made("DOOR", _rise(2.4), 1.0)
	door.global_position = Vector3(0.0, 0.0, 0.0)
	door.obstruction = _doorway(Vector3(0.0, 1.0, 0.0),
			Vector3(2.0, 2.0, 1.4))
	door.set_input(true)
	_drive(door, 1.5)
	_check(is_equal_approx(door.t, 1.0), "the door opens fully first")

	# THE BLOCK HAS TO ARRIVE MID-CLOSURE, or this measures nothing.
	# A door asked to shut on somebody who is ALREADY standing there
	# never starts moving, and "stopped where it was" and "reversed to
	# fully open" are then the same number. §21.2's subject is a closure
	# that has begun: "if closing WOULD INTERSECT the player". So the
	# panel is let halfway down first, and the player walks in there.
	door.set_input(false)
	_drive(door, 0.5)
	var halfway := door.t
	_check(halfway > 0.3 and halfway < 0.7,
			"the door is halfway shut with the doorway clear (t=%.4f)"
			% halfway)
	var who := _body(Vector3(0.0, 1.0, 0.0), "player")
	await get_tree().physics_frame
	await get_tree().physics_frame
	door.advance(STEP)
	_drive(door, 1.5)
	_check(is_equal_approx(door.t, 1.0),
			"…and somebody stepping into it sends the panel back to FULLY "
			+ "OPEN (t=%.4f, it was %.4f). A stop-and-wait door stays at "
			% [door.t, halfway] + "the fraction it had reached.")
	_check(door.refusals() >= 1 and door.overrun() > 0.0,
			"…and it reports the refusal and how long it has wanted to "
			+ "shut (%d refusals, %.2f s)" % [door.refusals(), door.overrun()])

	# "IT REPEATS INDEFINITELY." Three seconds of somebody standing there
	# is three more attempts, not one refusal and then silence.
	var first := door.refusals()
	_drive(door, 3.2)
	_check(door.refusals() >= first + 3,
			"…and it retries every %.1f s for as long as they stand there "
			% Constants.SAFE_CLOSURE_RETRY_SECONDS
			+ "(%d refusals, was %d)" % [door.refusals(), first])
	_check(is_equal_approx(door.t, 1.0),
			"…without ever creeping downward at them (t=%.4f)" % door.t)

	# AND IT SHUTS WHEN THEY LEAVE — ON THE NEXT RETRY, not on the edge
	# of them leaving. §21.2 gives the door a cadence, and a door that
	# resumed the instant the volume cleared would be a door that closes
	# on the heel of somebody stepping out of it. The countdown is a
	# readout, so this is measured rather than timed hopefully.
	who.global_position = Vector3(0.0, 1.0, 40.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var until := door.retry_left()
	_check(until > 0.0,
			"the doorway clears mid-cadence, %.3f s before the next retry"
			% until)
	_drive(door, maxf(until - 3.0 * STEP, 0.0))
	_check(is_equal_approx(door.t, 1.0),
			"…and up to the last frames before that retry it is still "
			+ "fully open (t=%.4f)" % door.t)
	_drive(door, 0.2)
	_check(door.t < 1.0,
			"…and the retry is what starts it moving (t=%.4f)" % door.t)
	_drive(door, 2.0)
	_check(is_equal_approx(door.t, 0.0),
			"…and it shuts (t=%.4f)" % door.t)
	_check(is_equal_approx(door.overrun(), 0.0),
			"…and stops counting overrun once it is no longer being denied")
	who.queue_free()
	door.obstruction.queue_free()
	door.queue_free()


## §21.2 protects "the player or any `required = true` object". A crate
## a puzzle cannot be finished without is as uncrushable as the player,
## and the marker travels on the BODY because the interlock's question is
## asked of whatever is standing there.
func _the_interlock_protects_required_objects() -> void:
	print("\n-- §21.2: …and any `required = true` object --")
	var door := _made("DOOR", _rise(2.4), 1.0)
	door.global_position = Vector3(30.0, 0.0, 0.0)
	door.obstruction = _doorway(Vector3(30.0, 1.0, 0.0),
			Vector3(2.0, 2.0, 1.4))
	door.set_input(true)
	_drive(door, 1.5)

	var crate := _body(Vector3(30.0, 1.0, 0.0),
			Constants.REQUIRED_OBJECT_GROUP)
	await get_tree().physics_frame
	await get_tree().physics_frame
	door.set_input(false)
	_drive(door, 0.6)
	_check(is_equal_approx(door.t, 1.0) and door.refusals() >= 1,
			"a required object in the doorway refuses the closure exactly "
			+ "as the player does (t=%.4f)" % door.t)

	# AND AN ORDINARY BODY DOES NOT. Otherwise the rule is "anything at
	# all", the door never shuts, and the distinction the contract draws
	# is decoration.
	crate.remove_from_group(Constants.REQUIRED_OBJECT_GROUP)
	await get_tree().physics_frame
	_drive(door, 2.5)
	_check(is_equal_approx(door.t, 0.0),
			"…and the same body with the `required` marker taken off does "
			+ "not (t=%.4f) — it gets pushed, per §21.1" % door.t)
	crate.queue_free()
	door.obstruction.queue_free()
	door.queue_free()


## §21.2's other half: `safe_closure = false` "marks the door as an
## authored hazard. It deals HAZARD damage per §25.1 and does not
## reverse." The actuator reports the body; the damage is the caller's,
## because a controller that dealt damage would own two things.
func _an_authored_crusher_does_not_reverse() -> void:
	print("\n-- §21.2: the authored crusher --")
	var door := _made("DOOR", _rise(2.4), 1.0)
	door.safe_closure = false
	door.global_position = Vector3(60.0, 0.0, 0.0)
	door.obstruction = _doorway(Vector3(60.0, 1.0, 0.0),
			Vector3(2.0, 2.0, 1.4))
	var struck: Array[String] = []
	door.crushed.connect(func(b: Node3D) -> void: struck.append(b.name))
	door.set_input(true)
	_drive(door, 1.5)
	var victim := _body(Vector3(60.0, 1.0, 0.0), "player")
	victim.name = "Victim"
	await get_tree().physics_frame
	await get_tree().physics_frame
	door.set_input(false)
	_drive(door, 2.0)
	_check(is_equal_approx(door.t, 0.0),
			"a `safe_closure = false` door closes on the player (t=%.4f)"
			% door.t)
	var unique := {}
	for who_name: String in struck:
		unique[who_name] = true
	_check(unique.has("Victim") and unique.size() == 1,
			"…and names the body so the caller can deal HAZARD damage")
	_check(struck.size() > 30,
			"…every frame of the contact rather than once, because §25.1 "
			+ "hazard damage is a rate the caller scales by delta (%d)"
			% struck.size())
	_check(door.refusals() == 0,
			"…and has no interlock to refuse anything (%d refusals)"
			% door.refusals())
	victim.queue_free()
	door.obstruction.queue_free()
	door.queue_free()


## THE SHIPPED MACHINE. `ServiceShutter` is what EX50-021's arcade
## actually uses, so §21.2 landing on `Actuator` alone would have fixed
## nothing that is in a room today.
func _the_shipped_shutter_obeys_21_2() -> void:
	print("\n-- C4a: the shipped ServiceShutter --")
	var shutter := ServiceShutter.create(Vector3(90.0, 1.3, 0.0),
			Vector3(2.4, 2.6, 0.3), 2.6, 8.0)
	add_child(shutter)
	await get_tree().physics_frame
	await get_tree().physics_frame
	shutter.command(true)
	for _i in 200:
		await get_tree().physics_frame
	_check(shutter.is_open(), "it opens on command (%.3f)" % shutter.openness())

	# SHUT IT ON A CLEAR DOORWAY FIRST, and interrupt the closure partway
	# down. The interruption is the case; a door that never started
	# moving cannot tell "stopped" from "reversed".
	shutter.command(false)
	var caught := 1.0
	for _i in 200:
		await get_tree().physics_frame
		caught = shutter.openness()
		if caught < 0.6:
			break
	_check(caught < 0.6 and caught > 0.05,
			"the panel is partway down with the doorway clear (%.3f)"
			% caught)
	var who := _body(Vector3(90.0, 1.3, 0.0), "player")
	for _i in 4:
		await get_tree().physics_frame
	_check(shutter.doorway_occupied(),
			"the doorway volume sees a real body walk into it")
	for _i in 200:
		await get_tree().physics_frame
	_check(shutter.openness() > 0.99,
			"…and the panel goes back to FULLY OPEN (%.3f, it was %.3f). "
			% [shutter.openness(), caught]
			+ "Before this repair it held at the fraction it had reached.")
	_check(shutter.reversing() and shutter.refusals() >= 1,
			"…and it says it is holding open under refusal (%d)"
			% shutter.refusals())
	var held := shutter.overrun()
	_check(held > 0.5, "…and how long it has wanted to shut (%.2f s)" % held)

	who.global_position = Vector3(90.0, 1.3, 40.0)
	for _i in 4:
		await get_tree().physics_frame
	_check(not shutter.doorway_occupied(), "they step out of the doorway")
	for _i in 180:
		await get_tree().physics_frame
	_check(shutter.is_shut(),
			"…and the retry shuts it (%.3f)" % shutter.openness())
	_check(is_equal_approx(shutter.overrun(), 0.0),
			"…and the overrun clears once it is no longer being denied")

	# AND A REQUIRED OBJECT HOLDS IT TOO — the same widened protected set
	# on the shipped machine, not only on the contract class.
	shutter.command(true)
	for _i in 200:
		await get_tree().physics_frame
	var crate := _body(Vector3(90.0, 1.3, 0.0),
			Constants.REQUIRED_OBJECT_GROUP)
	for _i in 4:
		await get_tree().physics_frame
	shutter.command(false)
	for _i in 60:
		await get_tree().physics_frame
	_check(shutter.openness() > 0.99 and shutter.reversing(),
			"a required object holds the shipped shutter open too (%.3f)"
			% shutter.openness())
	crate.queue_free()
	who.queue_free()
	shutter.queue_free()


## §21.1.1 ON MACHINES THAT ARE IN ROOMS TODAY.
##
## "Everything that carries or supports the player holds position, because
## the failure modes there are not symmetrical: a lift that drops to the
## bottom when a generator fails can strand or kill the player, and a
## bridge that retracts mid-crossing is a softlock generator. Neither of
## those is made safe by an interlock, because the danger is the motion
## itself rather than a pinch point."
##
## `ShuttleDeck` is the engine's LIFT and `RailCarrier` its
## MOVING_PLATFORM. Landing the table on `Actuator` alone would have left
## both of them with no answer at all.
func _the_shipped_carriers_hold_on_power_loss() -> void:
	print("\n-- §21.1.1 on the shipped carriers --")
	var deck := ShuttleDeck.create(Vector3.UP, Vector3(120.0, 0.0, 0.0),
			PackedFloat32Array([0.0, 4.0, 8.0]),
			PackedStringArray(["b0", "b1", "b2"]),
			PackedFloat32Array([0.0, 0.0, 0.0]),
			Vector3(4.0, 0.4, 4.0))
	add_child(deck)
	deck.set_physics_process(false)
	deck.go_to(2)
	for _i in 60:
		deck.advance(STEP)
	var lifted := deck.offset
	_check(lifted > 0.3 and lifted < 8.0,
			"the deck is partway up its shaft (%.3f m)" % lifted)
	deck.power(false)
	for _i in 180:
		deck.advance(STEP)
	_check(is_equal_approx(deck.offset, lifted),
			"…and power loss HOLDS it exactly where it is (%.3f m) rather "
			% deck.offset + "than letting it settle to the bottom")
	deck.power(true)
	for _i in 600:
		deck.advance(STEP)
	_check(deck.at_stop() == 2,
			"…and it resumes toward the stop it was sent to (at %d)"
			% deck.at_stop())

	# AND A DECK THE PLAYER STOPPED BY HAND IS NOT RESTARTED BY POWER.
	# Two different facts; `resume()` is still the only way out of
	# `stop_here()`.
	deck.go_to(0)
	deck.stop_here()
	deck.power(false)
	deck.power(true)
	for _i in 120:
		deck.advance(STEP)
	_check(deck.at_stop() == 2,
			"…and power returning does not undo a `stop_here` the player "
			+ "asked for (at %d)" % deck.at_stop())
	deck.queue_free()

	var rail := RailPath.from_points(PackedVector3Array([
		Vector3(200.0, 0.0, 0.0), Vector3(215.0, 0.0, 0.0),
		Vector3(230.0, 0.0, 0.0)]))
	var carrier := RailCarrier.create(rail,
			PackedFloat32Array([0.0, rail.length() * 0.5, rail.length()]),
			PackedStringArray(["d0", "d1", "d2"]), [true, true],
			Vector3(4.0, 0.4, 4.0), "concrete_facility")
	add_child(carrier)
	carrier.set_physics_process(false)
	_check(carrier.request(1),
			"the carrier accepts a run to the next dock")
	for _i in 60:
		carrier.advance(STEP)
	var along := carrier.offset
	_check(along > 0.5 and along < rail.length() * 0.5,
			"…and is partway down the span (%.3f m)" % along)
	carrier.power(false)
	for _i in 180:
		carrier.advance(STEP)
	_check(is_equal_approx(carrier.offset, along),
			"…power loss holds it where it is (%.3f m)" % carrier.offset)
	# THE ERRAND HAS TO SURVIVE THE OUTAGE. `hold()` clears `target_dock`
	# on purpose — a held carrier has no errand — and reusing it here
	# would bring the carrier back powered and parked halfway down a span
	# with its passenger aboard and nothing to say where it was going.
	carrier.power(true)
	for _i in 900:
		carrier.advance(STEP)
	_check(carrier.at_dock() == 1,
			"…and power restored resumes the errand it was on, from where "
			+ "it stopped (at dock %d, %.3f m)"
			% [carrier.at_dock(), carrier.offset])
	carrier.queue_free()


## §21.10's three are declared and NOT built. The refusal is the report.
func _the_constraint_kinds_are_refused_by_name() -> void:
	print("\n-- §21.10: the three this engine cannot build yet --")
	for kind: String in ["WINCH", "BRAKE", "DRIVER"]:
		var a := Actuator.create(kind, _rise(), 1.0)
		add_child(a)
		_check(not a.buildable() and not a.violations().is_empty(),
				"%s is refused by name rather than stubbed (%s)"
				% [kind, a.violations()[0]])
		var before := a.t
		a.set_input(true)
		_drive(a, 2.0)
		_check(is_equal_approx(a.t, before),
				"…and a refused actuator holds still rather than "
				+ "half-working")
		a.queue_free()
	var nonsense := Actuator.create("GANTRY", _rise(), 1.0)
	_check(not nonsense.buildable(),
			"a kind that is not one of the twelve is refused too (%s)"
			% nonsense.violations())
	nonsense.queue_free()
	var stunted: Array[Transform3D] = [Transform3D()]
	var short := Actuator.create("BRIDGE", stunted, 1.0)
	_check(not short.buildable(),
			"…and so is a path §21.1's `length >= 2` cannot mean (%s)"
			% short.violations())
	short.queue_free()
	_note("WINCH/BRAKE/DRIVER are OV04 P13's; §21.1.1's rows for them "
			+ "are declared here so the table has no hole.")
