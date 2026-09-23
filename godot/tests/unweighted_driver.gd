extends Node
## EX50-033 UNWEIGHTED SWITCH (`make godot-unweighted`).
##
## The specification is paper
## (`docs/design-library/EX50_entries/EX50-033.md`); this is the room it
## describes, held to §11's controls and to the owner's direction of
## 2026-09-21: exercise the REAL application through expiry -- class
## versus kilograms, collision, the approved physical effects, plate
## output, shutter behaviour and the complete route -- with no
## provisional class-shift substitute.
##
## **There is no substitute here.** Every case that changes the crate's
## class does it by starting a real `lightened` Status on a real
## `StatusEffects` whose target kind is `object`, through
## `ManipulableBody.apply_status`, refused at the engine's own boundary
## if the runtime does not implement that kind on that target. The room
## has no vocabulary of its own and nothing sets `mass_class` by hand.
##
## **Evidence classes are kept apart**, and each case says which it is:
##
##   direct handler   the Status is started by calling the crate's own
##                    handler, and the drive is commanded. What this
##                    measures is the machine, not the aim.
##   continuous play  a real player walks, jumps, shoots the applicator
##                    and crosses. `_the_complete_route` is the only one,
##                    and it is the one that answers "is this a room".
##   synthetic state  a body is placed and a value read, with no room
##                    around it.
##
## **What this does not measure.** Whether the contradiction READS as a
## contradiction to somebody who has not been told -- §4's legibility is
## a playtest question and a lamp colour is not an answer to it. And
## nothing here is composed, saved, or reachable from a campaign: the
## room is a development scenario, exactly as EX50-011 and EX50-021 are,
## and its interlocks and save requirements remain open rows.

const STEP := 1.0 / 60.0
## 8.0 s of `lightened` at 60 Hz, and then some.
const EXPIRY_FRAMES := 520

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
	await _the_room_stands()
	await _the_sill_is_out_of_reach_and_the_crate_top_is_not()
	await _placing_the_step_closes_the_route()
	await _the_class_moves_and_the_kilograms_do_not()
	await _the_crate_is_exactly_as_solid()
	await _an_impulse_doubles_on_the_room_s_own_crate()
	await _the_window_closes_it_again()
	await _the_bolt_outlasts_the_status()
	await _the_chain_is_the_declared_graph()
	await _a_refused_status_leaves_the_room_alone()
	await _the_disconnected_control()
	await _the_complete_route()
	print("")
	if _failures == 0:
		print("GODOT UNWEIGHTED OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT UNWEIGHTED: %d failures in %d checks"
			% [_failures, _checks])
	get_tree().quit(1)


func _settle(frames := 30) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _room(disconnected := false) -> UnweightedSwitch:
	var made := UnweightedSwitch.new()
	made.disconnected = disconnected
	add_child(made)
	return made


## Drive the crate and wait for the guide track to finish, without
## asserting how many frames that takes.
func _drive_to(room: UnweightedSwitch, recess: bool) -> void:
	var want := UnweightedSwitch.RECESS_Z if recess \
			else UnweightedSwitch.PARK_Z
	# THE LEVER IS A TOGGLE, so asking "is the crate there yet" is the
	# wrong question: after a player has pulled it the crate is not there
	# yet and is already on its way, and commanding it again sent it
	# straight back. Read where the track is HEADING.
	if not is_equal_approx(room.drive_goal_z(), want):
		room.drive.pulled.emit(room.drive)
	for _i in 600:
		await get_tree().physics_frame
		if room.crate.freeze \
				and is_equal_approx(room.crate.global_position.z, want):
			return


# --------------------------------------------------------- the parts

## **SYNTHETIC STATE.** Does the room the specification describes exist,
## and does it start where §4 says it starts?
func _the_room_stands() -> void:
	print("  -- THE ROOM, as §2 and §4 describe it")
	var room := _room()
	await _settle(12)
	_check(room.plate != null and room.shutter != null
			and room.crate != null and room.applicator != null
			and room.bolt != null and room.drive != null
			and room.goal_plate != null,
			"plate, shutter, crate, applicator, bolt, drive and goal")
	_check(is_equal_approx(room.crate.mass, UnweightedSwitch.CRATE_KG),
			"the crate is %.0f kg" % room.crate.mass)
	_check(room.crate.mass_class() == MassClass.HEAVY,
			"...which reads %s" % room.crate.mass_class())
	_check(room.plate.requires == MassClass.HEAVY,
			"the plate requires HEAVY or heavier")
	_check(not room.plate.satisfied(),
			"§4: the crate is parked, so the plate is OFF")
	_check(room.shutter.is_open(),
			"§4: ...and the shutter is open")
	room.queue_free()
	await _settle(2)


## **SYNTHETIC STATE, measured against the real controller.** §2's whole
## premise: the sill is above a baseline jump from the floor and within
## one from the crate's top. Asserted from `Constants`, which is
## generated from `schemas/physics.py`, so the room cannot drift from the
## movement the bridge publishes. The walked proof is
## `_the_complete_route`.
func _the_sill_is_out_of_reach_and_the_crate_top_is_not() -> void:
	print("  -- THE CONTRADICTION: 1.9 m, from two different floors")
	var apex := Constants.JUMP_APEX_HEIGHT
	var sill := UnweightedSwitch.SILL_Y
	var top := UnweightedSwitch.CRATE.y
	_check(sill > apex,
			"from the floor, a jump reaches %.3f m and the sill is %.2f m"
			% [apex, sill])
	_check(sill > Constants.MAX_VERTICAL_STEP,
			"...and it is above a step-up of %.2f m too, so there is no "
			% Constants.MAX_VERTICAL_STEP + "walking bypass")
	_check(top + apex > sill,
			"from the crate top at %.2f m, a jump reaches %.3f m"
			% [top, top + apex])
	# EVERY OTHER LEDGE BY THE DOOR IS A BYPASS if it does the crate's job
	# (P5-16): the guide rails were 1.4 m, walkable, reached from the
	# parked crate, and a jump from them made the sill with the plate
	# empty and the crossing open.
	var rail := UnweightedSwitchRoom.RAIL_Y
	_check(rail + apex < sill,
			"the guide rails are no step: %.2f m, and a jump from them "
			% rail + "reaches %.3f m, under the sill" % (rail + apex))
	_note("margin from the crate top is %.3f m" % (top + apex - sill))


## **DIRECT HANDLER.** §2: "placing the step you need closes the route
## you want." The drive is commanded rather than walked to; what this
## measures is the plate's output and the shutter's response.
func _placing_the_step_closes_the_route() -> void:
	print("  -- PLACING THE STEP CLOSES THE ROUTE")
	var room := _room()
	await _settle(12)
	var before := room.shutter.is_open()
	await _drive_to(room, true)
	await _settle(6)
	var reading: Dictionary = room.plate.reading()
	_check(before, "BEFORE: the shutter is open")
	_check(reading["classes"] == [MassClass.HEAVY],
			"DURING: the plate reads one occupant, %s" % [reading["classes"]])
	_check(bool(reading["satisfied"]),
			"...and is satisfied")
	_check(room.plate.occupants().size() == 1,
			"...counting the crate and not the player (§3)")
	await _settle(150)
	_check(room.shutter.is_shut(),
			"AFTER: the shutter is shut, openness %.3f"
			% room.shutter.openness())
	room.queue_free()
	await _settle(2)


## **DIRECT HANDLER.** The room's whole claim, and the one a provisional
## class shift would have faked: the Status changes the CLASS and leaves
## the kilograms exactly where they were.
func _the_class_moves_and_the_kilograms_do_not() -> void:
	print("  -- CLASS VERSUS KILOGRAMS, through the real Status")
	var room := _room()
	await _settle(12)
	await _drive_to(room, true)
	await _settle(150)
	_check(room.shutter.is_shut(), "the route is closed to begin with")
	var kg_before := room.crate.mass
	room.crate.apply_status("lightened", UnweightedSwitch.LIGHTENED_SECONDS,
			UnweightedSwitch.LIGHTENED_MAGNITUDE)
	await _settle(2)
	_check(room.crate.statuses != null
			and room.crate.statuses.side == "object",
			"the Status is on a real StatusEffects at target `object`")
	_check(room.crate.statuses.has("lightened"),
			"...and `lightened` is actually active on it")
	_check(is_equal_approx(room.crate.mass, kg_before)
			and is_equal_approx(room.crate.mass,
				UnweightedSwitch.CRATE_KG),
			"THE KILOGRAMS DO NOT MOVE: still %.1f kg" % room.crate.mass)
	_check(room.crate.mass_class() == MassClass.MEDIUM,
			"THE CLASS DOES: HEAVY -> %s, one step" % room.crate.mass_class())
	_check(not room.plate.satisfied(),
			"the plate stops being satisfied without the crate moving")
	await _settle(150)
	_check(room.shutter.is_open(),
			"and the shutter opens, openness %.3f" % room.shutter.openness())
	room.queue_free()
	await _settle(2)


## **DIRECT HANDLER.** §8's other half. A Status that quietly shrank the
## crate, or let the player fall through it, would open the route by
## destroying the step instead of by changing its class -- and the suite
## above would still have gone green.
func _the_crate_is_exactly_as_solid() -> void:
	print("  -- COLLISION IS UNTOUCHED: the step is still a step")
	var room := _room()
	await _settle(12)
	await _drive_to(room, true)
	await _settle(30)
	var top_before := room.crate.global_position.y \
			+ UnweightedSwitch.CRATE.y * 0.5
	var hit_before := _ray_down(room, top_before + 0.5)
	room.crate.apply_status("lightened", UnweightedSwitch.LIGHTENED_SECONDS,
			UnweightedSwitch.LIGHTENED_MAGNITUDE)
	await _settle(30)
	var top_after := room.crate.global_position.y \
			+ UnweightedSwitch.CRATE.y * 0.5
	var hit_after := _ray_down(room, top_before + 0.5)
	_check(is_equal_approx(top_before, top_after),
			"the crate top stays at %.3f m" % top_after)
	_check(hit_before and hit_after,
			"a ray from above stops on it before AND while lightened")
	_check(room.crate.mass_class() == MassClass.MEDIUM,
			"...while the class is %s, so the change is semantic only"
			% room.crate.mass_class())
	room.queue_free()
	await _settle(2)


func _ray_down(room: UnweightedSwitch, from_y: float) -> bool:
	var space := room.get_world_3d().direct_space_state
	var at := Vector3(0.0, from_y, UnweightedSwitch.RECESS_Z)
	var query := PhysicsRayQueryParameters3D.create(at,
			at + Vector3.DOWN * 1.0)
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == room.crate


## **SYNTHETIC STATE, on the room's own crate.** Design 5 §15.2 gives
## `lightened` "incoming impulse x2.0", and the distinction from a
## continuous force is the part that is easy to get wrong. Measured here
## on the crate this room actually ships rather than on a fixture, with
## the guide track's parking brake released for the measurement.
func _an_impulse_doubles_on_the_room_s_own_crate() -> void:
	print("  -- THE APPROVED PHYSICAL EFFECT, on this crate")
	var room := _room()
	await _settle(12)
	var crate := room.crate
	# Off the track: the drive parks the crate by freezing it, and a
	# frozen body does not answer an impulse at all.
	room.set_physics_process(false)
	crate.freeze = false
	crate.gravity_scale = 0.0
	await _settle(4)
	crate.linear_velocity = Vector3.ZERO
	crate.receive_impulse(Vector3(0.0, 0.0, 40.0))
	await _settle(1)
	var plain := crate.linear_velocity.z
	crate.linear_velocity = Vector3.ZERO
	crate.apply_status("lightened", UnweightedSwitch.LIGHTENED_SECONDS,
			UnweightedSwitch.LIGHTENED_MAGNITUDE)
	await _settle(1)
	crate.linear_velocity = Vector3.ZERO
	crate.receive_impulse(Vector3(0.0, 0.0, 40.0))
	await _settle(1)
	var lifted := crate.linear_velocity.z
	_check(plain > 0.001 and is_equal_approx(lifted / plain, 2.0),
			"an impulse moves it %.4f m/s, and %.4f m/s lightened (x%.2f)"
			% [plain, lifted, lifted / plain if plain > 0.0 else 0.0])
	_check(is_equal_approx(crate.mass, UnweightedSwitch.CRATE_KG),
			"...on the same %.0f kg, so it is the SCALING that changed"
			% crate.mass)
	room.queue_free()
	await _settle(2)


## **DIRECT HANDLER.** THE EXPIRY, which is the reason the bolt exists.
## §3: the Status is temporary, so the crossing it opens is temporary,
## and a room that only ever measured the opening would never have found
## that out.
func _the_window_closes_it_again() -> void:
	print("  -- THROUGH EXPIRY: the window shuts by itself")
	var room := _room()
	await _settle(12)
	await _drive_to(room, true)
	await _settle(150)
	room.crate.apply_status("lightened", UnweightedSwitch.LIGHTENED_SECONDS,
			UnweightedSwitch.LIGHTENED_MAGNITUDE)
	await _settle(150)
	_check(room.shutter.is_open(), "open while the Status runs")
	await _settle(EXPIRY_FRAMES)
	_check(room.crate.statuses != null
			and not room.crate.statuses.has("lightened"),
			"after %.1f s the Status has expired"
			% UnweightedSwitch.LIGHTENED_SECONDS)
	_check(room.crate.mass_class() == MassClass.HEAVY,
			"...the crate reads %s again" % room.crate.mass_class())
	_check(room.plate.satisfied(),
			"...the plate is satisfied again, with nothing having moved")
	await _settle(150)
	_check(room.shutter.is_shut(),
			"...and the shutter has shut, openness %.3f"
			% room.shutter.openness())
	_check(not room.bolted, "the bolt was never touched")
	room.queue_free()
	await _settle(2)


## **DIRECT HANDLER.** §3: "Reaching and operating it makes the useful
## crossing persistent without requiring the temporary Status to remain
## active forever." So the same expiry that shut the door above must
## leave it open here, and the return stair must exist from then on.
func _the_bolt_outlasts_the_status() -> void:
	print("  -- §9: THE BOLT IS PERMANENT AND THE STATUS IS NOT")
	var room := _room()
	await _settle(12)
	var stairs_before := _stair_count(room)
	await _drive_to(room, true)
	await _settle(150)
	room.crate.apply_status("lightened", UnweightedSwitch.LIGHTENED_SECONDS,
			UnweightedSwitch.LIGHTENED_MAGNITUDE)
	await _settle(150)
	_check(room.shutter.is_open(), "the crossing is open")
	room.bolt.pulled.emit(room.bolt)
	await _settle(8)
	_check(room.bolted, "the bolt is engaged")
	_check(_stair_count(room) > stairs_before,
			"...and the fixed return stair now exists (%d -> %d steps)"
			% [stairs_before, _stair_count(room)])
	await _settle(EXPIRY_FRAMES)
	_check(not room.crate.statuses.has("lightened"),
			"the Status has expired")
	_check(room.crate.mass_class() == MassClass.HEAVY
			and room.plate.satisfied(),
			"...and the plate is satisfied again")
	await _settle(150)
	_check(room.shutter.is_open(),
			"AND THE SHUTTER IS STILL OPEN: the bolt outranks the plate")
	_check(_stair_count(room) > stairs_before,
			"...and the stair is still there")
	room.queue_free()
	await _settle(2)


## O05-07: THE CHAIN IS THE MINOR'S DECLARED GRAPH, RUN BY `SignalGraph`.
## The rest of this suite is the comparison -- the room behaves as it did
## when the chain was wired by hand. This is the evidence that the shared
## runtime is what makes it behave: the room's machines are bound to the
## contract's own ids, and the graph's values move with the plate and the
## bolt.
func _the_chain_is_the_declared_graph() -> void:
	print("  -- THE CHAIN: the contract's graph, run by the shared runtime")
	var room := _room()
	await _settle(12)
	var graph: SignalGraph = room.room.graph
	var shutter_binding: Dictionary = graph.actuators.get("shutter", {}) \
			if graph != null else {}
	_check(graph != null and graph.sensors.get("plate") == room.plate
			and graph.sensors.get("bolt_lever") == room.bolt
			and shutter_binding.get("node") == room.shutter
			and shutter_binding.get("driven_by") == "open",
			"the room's plate, bolt lever and shutter are bound to the "
			+ "contract's declared ids, the shutter driven by 'open'")
	if graph == null:
		room.queue_free()
		return
	var kinds: Array = graph.nodes.map(
			func(n: Dictionary) -> String: return str(n["kind"]))
	_check(kinds == ["NOT", "LATCH", "OR"],
			"the declared nodes, in order: %s" % [kinds])
	_check(bool(graph.values.get("open", false)) and room.shutter.is_open(),
			"at rest the graph reads OPEN and the crossing is open")
	await _drive_to(room, true)
	for _i in 300:
		await get_tree().physics_frame
		if room.shutter.is_shut():
			break
	_check(bool(graph.values.get("plate", false))
			and not bool(graph.values.get("unloaded", true))
			and not bool(graph.values.get("open", true))
			and room.shutter.is_shut(),
			"the crate on the plate: plate ON, NOT OFF, OR OFF, and the "
			+ "graph shut the crossing")
	var latch_fired: Array[int] = [0]
	var engaged: Array[int] = [0]
	graph.fired.connect(func(_package: String, node_id: String) -> void:
		if node_id == "bolt":
			latch_fired[0] += 1)
	room.room.bolt_engaged.connect(func() -> void: engaged[0] += 1)
	room.bolt.pulled.emit(room.bolt)
	for _i in 300:
		await get_tree().physics_frame
		if room.shutter.is_open():
			break
	# A REPEATED PULL (O05-07.5) is not a second decision: the LATCH is
	# set once, and the room engages its bolt once.
	room.bolt.pulled.emit(room.bolt)
	await _settle(4)
	_check(latch_fired[0] == 1 and engaged[0] == 1,
			"a second pull fires nothing more: the LATCH fired %d time(s), "
			% latch_fired[0] + "the room engaged %d" % engaged[0])
	_check(graph.latched.has("bolt") and bool(graph.values.get("open",
			false)) and bool(graph.values.get("plate", false))
			and room.shutter.is_open() and room.bolted,
			"the bolt's one-tick pulse set the LATCH, and the OR holds the "
			+ "crossing open with the plate still loaded")
	# ONE LATER TICK. `values` is the last tick's snapshot and the graph
	# evaluates on events, so "later" has to be made to happen: §19.3's
	# pulse lives exactly one tick, and the latch it set does not.
	graph.evaluate()
	_check(not bool(graph.values.get("bolt_lever", true))
			and graph.latched.has("bolt")
			and bool(graph.values.get("open", false)),
			"and on the next tick the pulse is gone -- the lever reads OFF "
			+ "-- while the LATCH still holds the crossing open")
	room.queue_free()
	var cut := _room(true)
	await _settle(12)
	_check(cut.room.graph.sensors.has("plate")
			and cut.room.graph.sensors["plate"] == null,
			"§11's control: the plate sensor is declared and left unbound")
	cut.queue_free()
	await _settle(4)


func _stair_count(room: UnweightedSwitch) -> int:
	return room.return_stair_steps()


## **DIRECT HANDLER.** The owner's boundary requirement, asked inside the
## room rather than at a fixture: a kind the runtime does not implement
## on an OBJECT must create no active state and no success event, and
## must leave the machines exactly as it found them.
func _a_refused_status_leaves_the_room_alone() -> void:
	print("  -- A REFUSED APPLICATION CHANGES NOTHING")
	var room := _room()
	await _settle(12)
	await _drive_to(room, true)
	await _settle(150)
	var shut_before := room.shutter.is_shut()
	var class_before := room.crate.mass_class()
	var seen: Array[String] = []
	room.crate.apply_status("lightened", 0.0, 0.0)
	if room.crate.statuses != null:
		room.crate.statuses.status_applied.connect(
				func(k: String) -> void: seen.append(k))
	# `burning` is implemented on `self` and `enemy` and on no object,
	# and `anchored` is named by the design with nothing behind it at
	# all. Both doors, one answer.
	for kind: String in ["burning", "anchored", "slippery"]:
		room.crate.apply_status(kind, 6.0, 1.0)
		await _settle(2)
		_check(not room.crate.statuses.has(kind),
				"'%s' on an object is refused, not stored" % kind)
	_check(seen.is_empty(),
			"...and no success event was emitted: %s" % [seen])
	_check(room.crate.mass_class() == class_before,
			"the crate still reads %s" % room.crate.mass_class())
	_check(room.plate.satisfied() and room.shutter.is_shut() == shut_before,
			"the plate and the shutter are exactly as they were")
	room.queue_free()
	await _settle(2)


## **DIRECT HANDLER.** §11's control, and the reason it is written down:
## a suite that only ever watched the shutter open would pass on a room
## where the plate's output went nowhere. With the one link cut, the
## EXPECTED response must fail.
func _the_disconnected_control() -> void:
	print("  -- §11's CONTROL: the plate's output goes nowhere")
	var room := _room(true)
	await _settle(12)
	_check(room.disconnected, "the room is built with the link cut")
	_check(room.shutter.is_open(), "the shutter starts open, as before")
	await _drive_to(room, true)
	await _settle(200)
	_check(room.plate.satisfied(),
			"the plate IS satisfied: the sensor is not what was cut")
	_check(room.shutter.is_open(),
			"...AND THE SHUTTER DID NOT CLOSE -- the expected response "
			+ "fails, which is what the control is for")
	room.crate.apply_status("lightened", UnweightedSwitch.LIGHTENED_SECONDS,
			UnweightedSwitch.LIGHTENED_MAGNITUDE)
	await _settle(200)
	_check(not room.plate.satisfied() and room.shutter.is_open(),
			"...and releasing it changes nothing either, because nothing "
			+ "downstream is listening")
	room.queue_free()
	await _settle(2)


## **CONTINUOUS PLAY.** Every metre walked, the applicator shot rather
## than called, the crate climbed, the crossing made and the goal stood
## on. This is the case that answers whether EX50-033 is a room.
func _the_complete_route() -> void:
	print("  -- THE COMPLETE ROUTE, walked")
	var room := _room()
	await _settle(20)
	var body := room.player
	if body == null:
		_check(false, "the room spawned a player")
		return
	# A: the arrival floor, below the sill with nothing to climb.
	var start := body.global_position
	_check(start.y < UnweightedSwitch.SILL_Y,
			"arrival A is below the sill, at %.2f m" % start.y)

	# The drive, pulled by hand at the lever.
	var drove := await _pull(body, room.drive)
	_check(drove, "the SERVICE DRIVE lever is reachable and pulls")
	await _drive_to(room, true)
	await _settle(200)
	_check(room.shutter.is_shut(),
			"the step is placed, and the crossing has closed")

	# The applicator, SHOT. §8: a miss changes nothing, so this is a
	# real aim at a real target and not a call into the handler.
	# A BOX, NOT AN INT. GDScript lambdas capture by VALUE, so a captured
	# `int` counter is incremented inside the lambda's own copy and reads
	# zero outside it -- which is what this case reported while the
	# applicator was firing perfectly well. An Array is captured by
	# reference and actually counts.
	var triggers: Array[int] = [0]
	room.applicator.triggered.connect(
			func(_w: ActivityElement) -> void: triggers[0] += 1)
	var seen := await _shoot(body, room.applicator)
	_check(seen == "the applicator",
			"the shot has line of sight to the applicator, and sees %s"
			% seen)
	_check(triggers[0] > 0,
			"...and the applicator fired (%d trigger(s))" % triggers[0])
	_check(room.crate.statuses != null
			and room.crate.statuses.has("lightened"),
			"...and the crate is carrying `lightened`")
	await _settle(200)
	_check(room.shutter.is_open(), "the crossing has opened")

	# Onto the crate, and through the doorway.
	var climbed := await _walk_to(body,
			Vector3(0.0, 0.0, UnweightedSwitch.RECESS_Z), 1.4)
	# SETTLED, not sampled mid-jump: an airborne player passes an
	# altitude test without standing on anything.
	await _settle(24)
	_check(climbed and body.is_on_floor()
			and absf(body.global_position.y - UnweightedSwitch.CRATE.y)
				< 0.2,
			"the player is STANDING on the crate top, feet at %.2f m"
			% body.global_position.y)
	var crossed := await _walk_to(body,
			Vector3(0.0, 0.0, UnweightedSwitch.NORTH_Z + 1.6), 1.6)
	_check(crossed and body.global_position.z > UnweightedSwitch.NORTH_Z,
			"the player is through the doorway at z %.2f"
			% body.global_position.z)

	# The bolt, then the goal.
	var bolted := await _pull(body, room.bolt)
	_check(bolted and room.bolted, "the HOLD-OPEN BOLT is pulled")
	var reached := await _walk_to(body, room.goal_plate.global_position, 1.0)
	await _settle(40)
	_check(reached and room.reached_goal,
			"THE GOAL IS REACHED, on foot, from arrival A")
	_note("route completed with the Status expiring behind the player: "
			+ "`lightened` active at the goal = %s"
			% [room.crate.statuses.has("lightened")])
	room.queue_free()
	await _settle(2)


# ------------------------------------------------- the player's hands

func _aim(body: Player, at: Vector3) -> void:
	var d := (at - (body.global_position + Vector3(0.0, 1.5, 0.0)))
	body.rotation.y = atan2(-d.x, -d.z)
	if body.camera != null:
		body.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## Aim and fire the baseline Static Pulse, and say what the shot could
## actually SEE. The Pulse is a hitscan through `camera_ray`, so "did it
## trigger" and "was anything in the way" are two different answers, and
## a route that failed for want of line of sight looked exactly like a
## target that ignores shots.
func _shoot(body: Player, at: ActivityElement) -> String:
	_aim(body, at.global_position)
	await get_tree().physics_frame
	var seen := "nothing"
	var ray: Dictionary = body.camera_ray(Constants.STATIC_PULSE_RANGE)
	if not ray.is_empty():
		var who: Variant = ray["collider"]
		seen = "%s (%s)" % [who.name, who.get_class()]
		var owner_node: Node = who
		while owner_node != null and owner_node != at:
			owner_node = owner_node.get_parent()
		if owner_node == at:
			seen = "the applicator"
	Input.action_press("fire_pulse", 1.0)
	for _i in 3:
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	for _i in 30:
		await get_tree().physics_frame
	return seen


func _pull(body: Player, lever: CallLever) -> bool:
	var walked := await _walk_to(body,
			lever.global_position, 1.6)
	if not walked:
		return false
	var before := lever.pulls
	_aim(body, lever.global_position + Vector3(0.0, 0.1, 0.0))
	await get_tree().physics_frame
	Input.action_press("interact", 1.0)
	for _i in 16:
		await get_tree().physics_frame
		if lever.pulls > before:
			break
	Input.action_release("interact")
	await get_tree().physics_frame
	return lever.pulls > before


func _walk_to(body: Player, goal: Vector3, within := 1.2,
		frames := 420) -> bool:
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
		if body.camera != null:
			body.camera.rotation.x = 0.0
		if (here - last).length() < 0.012:
			still += 1
			if still == 14 and body.is_on_floor():
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
