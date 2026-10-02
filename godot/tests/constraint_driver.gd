extends Node
## THE EIGHT CONSTRAINT KINDS, SIMULATED (`make godot-constraints`).
##
## OV04 P13. Amalgam §14.8 and §26.5, pinned from Design 2, plus §21.10's
## three actuators — the ones `Actuator` refused by name when P15 landed
## §21's other nine.
##
## **THE CASE THE WHOLE PACKAGE IS ABOUT.** The Amalgam says the single
## most visible difference between Design 1 and Design 2 is that "a crane
## in Design 2 is a `PULLEY` with a load on one end and a `WINCH` driving
## it. **Its cargo swings.** Design 1's crane was a `PATH_MACHINE` whose
## cargo was a child transform and could not." A child transform keeps
## its offset from the hook exactly, forever; a suspended load falls and
## swings in under the anchor. That difference is one measurement, and
## `_a_suspended_load_swings` is it.
##
## **EVIDENCE.** Every case here is a real `RigidBody3D` under real
## gravity in a real physics world, stepped by real physics frames. There
## is no synthetic state in this suite: a constraint that did not
## actually hold a mass up would show as a body on the floor.
##
## **WHAT IS REFUSED, AND WHY THE REFUSAL IS A CASE.** `breakable_at` is
## checked "against the solver's reported constraint force" (§14.8). The
## four kinds this engine solves itself report one exactly; a Godot joint
## does not expose its reaction. So a `breakable_at` on a hinge is
## refused by name, and the refusal is asserted rather than worked
## around, in the same way P15 asserted `Actuator`'s.

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
	await _the_vocabulary()
	await _a_rope_is_taut_only()
	await _a_suspended_load_swings()
	await _a_chain_is_a_rope()
	await _a_pulley_shares_one_length()
	await _a_counterweight_is_a_pulley_with_a_mass()
	await _a_rope_breaks_and_a_required_one_rebuilds()
	await _a_hinge_turns_within_its_limits()
	await _a_slider_slides_within_its_limits()
	await _the_chain_cap()
	await _the_solver_is_reproducible()
	await _a_winch_raises_its_load()
	await _a_brake_locks_where_it_is()
	await _a_driver_applies_torque()
	await _the_gantry_loses_power()
	print("")
	if _failures == 0:
		print("GODOT CONSTRAINTS OK (%d checks, %d notes)" % [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT CONSTRAINTS: %d failures in %d checks" % [_failures, _checks])
	get_tree().quit(1)


func _settle(frames := 60) -> void:
	for _i in frames:
		await get_tree().physics_frame


## A world with a floor far enough down that a body which is NOT held up
## has somewhere to land — so "the constraint held it" and "it fell" are
## two different, measurable outcomes rather than one body at an
## ambiguous height.
func _world(at := Vector3.ZERO) -> Node3D:
	var world := Node3D.new()
	add_child(world)
	world.global_position = at
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)
	floor_body.global_position = at + Vector3(0.0, -20.0, 0.0)
	return world


func _crate(world: Node3D, id: String, kg: float, at: Vector3,
		size := Vector3(1.0, 1.0, 1.0)) -> ManipulableBody:
	var body := ManipulableBody.create(id, kg, size)
	world.add_child(body)
	body.global_position = at
	return body


func _solver(world: Node3D) -> Constraints:
	var links := Constraints.new()
	links.name = "Constraints"
	world.add_child(links)
	return links


func _the_vocabulary() -> void:
	print("\n-- §14.8: the eight kinds --")
	_check(Constants.CONSTRAINT_KINDS.size() == 8,
			"§14.8 declares eight constraint kinds (%d)"
			% Constants.CONSTRAINT_KINDS.size())
	var covered: Array[String] = []
	for kind: String in Constants.CONSTRAINT_SOLVED_KINDS:
		covered.append(kind)
	for kind: String in Constants.CONSTRAINT_JOINT_KINDS:
		covered.append(kind)
	covered.sort()
	var all_kinds: Array[String] = []
	for kind: String in Constants.CONSTRAINT_KINDS:
		all_kinds.append(kind)
	all_kinds.sort()
	_check(covered == all_kinds,
			"…and every one is either solved here or a Godot joint, with "
			+ "no kind in both and none in neither")
	_check(Constants.CONSTRAINT_SOLVER_ITERATIONS == 8,
			"the solver runs a FIXED eight iterations (%d) — not adaptive, "
			% Constants.CONSTRAINT_SOLVER_ITERATIONS
			+ "because §23.5 check 20 replays against it")
	_check(Constants.CONSTRAINT_CHAIN_CAP == 4,
			"chains are capped at four linked constraints")
	_check(Constants.CONSTRAINT_RUNTIME_CREATABLE.size() == 1,
			"exactly one kind may be created at runtime, and it is the "
			+ "one `TETHER` makes (%s)"
			% [Constants.CONSTRAINT_RUNTIME_CREATABLE])


## §14.8: "distance constraint, TAUT ONLY — resists extension, not
## compression." Both halves are measured, because a two-sided distance
## constraint holds a load on a stick and nothing swings.
func _a_rope_is_taut_only() -> void:
	print("\n-- §14.8: a rope is taut only --")
	var world := _world(Vector3(0.0, 0.0, 0.0))
	var links := _solver(world)
	var anchor := Vector3(0.0, 8.0, 0.0)
	var load := _crate(world, "load", 60.0, anchor - Vector3(0.0, 0.5, 0.0))
	links.declare([{
		"constraint_id": "rope", "kind": "ROPE", "b": load,
		"anchor_a": anchor, "length": 3.0,
	}])
	# THE FORCE IS SAMPLED WHILE IT IS BEING APPLIED. Once the load is
	# hanging still the rope is exactly at length, the solver has nothing
	# to correct, and the reported force is correctly zero — so the peak
	# is what says how hard it had to pull to arrest 60 kg.
	var peak := 0.0
	for _i in 200:
		await get_tree().physics_frame
		peak = maxf(peak, links.force_of("rope"))
	var hung := anchor.y - load.global_position.y
	_check(absf(hung - 3.0) < 0.35,
			"a 60 kg load on a 3.0 m rope hangs at %.3f m under the anchor "
			% hung + "rather than on the floor 20 m down")
	_check(peak > 100.0,
			"…and the solver reports the force it took to arrest it "
			+ "(%.0f N on 60 kg)" % peak)

	# COMPRESSION. Lift the load ABOVE the taut length: the rope goes
	# slack and does nothing at all. A two-sided distance constraint
	# would push it back down to exactly 3.0 m.
	load.global_position = anchor - Vector3(0.0, 1.0, 0.0)
	load.linear_velocity = Vector3.ZERO
	await _settle(2)
	var slack := links.force_of("rope")
	_check(is_equal_approx(slack, 0.0),
			"a slack rope applies nothing (%.3f N) — it resists extension "
			% slack + "and not compression")
	await _settle(120)
	_check(anchor.y - load.global_position.y > 2.5,
			"…so the load falls back to the taut length on its own "
			+ "(%.3f m)" % (anchor.y - load.global_position.y))

	# §14.8: A CONSTRAINED BODY DOES NOT SLEEP WHILE ITS VALUE IS
	# CHANGING. A load that dozed off mid-swing would come to rest in
	# mid-air, and everything downstream — the digest, the replay, the
	# force readout — would agree with it.
	load.global_position = anchor + Vector3(2.0, -1.0, 0.0)
	load.sleeping = true
	await _settle(30)
	_check(not load.sleeping,
			"a body whose constraint value is moving is woken rather than "
			+ "left asleep in mid-air")
	world.queue_free()
	await get_tree().process_frame


## THE HEADLINE. "Its cargo swings. Design 1's crane was a `PATH_MACHINE`
## whose cargo was a child transform and could not."
##
## A child transform keeps its offset from the hook exactly and forever.
## A suspended load dropped out to one side falls, goes taut, and swings
## in underneath. So the measurement is the horizontal offset: it starts
## at 2.4 m and has to collapse. Nothing in a kinematic crane does that.
func _a_suspended_load_swings() -> void:
	print("\n-- §26.5: the cargo swings --")
	var world := _world(Vector3(100.0, 0.0, 0.0))
	var links := _solver(world)
	var anchor := Vector3(100.0, 8.0, 0.0)
	var cargo := _crate(world, "cargo", 80.0,
			anchor + Vector3(2.4, -1.8, 0.0))
	links.declare([{
		"constraint_id": "hook", "kind": "ROPE", "b": cargo,
		"anchor_a": anchor, "length": 3.0,
	}])
	var started := absf(cargo.global_position.x - anchor.x)
	var lowest := 99.0
	var swung := 0.0
	for _i in 300:
		await get_tree().physics_frame
		var across := absf(cargo.global_position.x - anchor.x)
		lowest = minf(lowest, across)
		swung = maxf(swung, absf(cargo.global_position.z - anchor.z))
	_check(started > 2.0,
			"the cargo starts %.2f m out from under the anchor" % started)
	_check(lowest < started * 0.35,
			"…and swings in to %.2f m — a child transform would still be "
			% lowest + "%.2f m out, which is the whole difference between "
			% started + "Design 1's crane and this one")
	_check(anchor.y - cargo.global_position.y > 2.0,
			"…while the rope is still holding it up (%.2f m below the "
			% (anchor.y - cargo.global_position.y) + "anchor)")
	world.queue_free()
	await get_tree().process_frame


## §14.8: `CHAIN` is "same as `ROPE`, rendered segmented, IDENTICAL
## SOLVER TREATMENT." So the assertion is that they agree, not that the
## chain does something of its own.
func _a_chain_is_a_rope() -> void:
	print("\n-- §14.8: a chain is a rope --")
	var world := _world(Vector3(200.0, 0.0, 0.0))
	var links := _solver(world)
	var rope_anchor := Vector3(200.0, 8.0, 0.0)
	var chain_anchor := Vector3(206.0, 8.0, 0.0)
	var on_rope := _crate(world, "on_rope", 55.0,
			rope_anchor - Vector3(0.0, 0.5, 0.0))
	var on_chain := _crate(world, "on_chain", 55.0,
			chain_anchor - Vector3(0.0, 0.5, 0.0))
	links.declare([
		{"constraint_id": "r", "kind": "ROPE", "b": on_rope,
			"anchor_a": rope_anchor, "length": 2.5},
		{"constraint_id": "c", "kind": "CHAIN", "b": on_chain,
			"anchor_a": chain_anchor, "length": 2.5},
	])
	await _settle(200)
	var by_rope := rope_anchor.y - on_rope.global_position.y
	var by_chain := chain_anchor.y - on_chain.global_position.y
	_check(absf(by_rope - by_chain) < 0.02,
			"identical loads on a 2.5 m rope and a 2.5 m chain hang at the "
			+ "same depth (%.4f m and %.4f m)" % [by_rope, by_chain])
	world.queue_free()
	await get_tree().process_frame


## §14.8: "two rope constraints sharing a TOTAL LENGTH through a fixed
## point." The measurement is the sharing: one end going down must take
## the other end up, which two independent ropes would never do.
func _a_pulley_shares_one_length() -> void:
	print("\n-- §14.8: a pulley shares one length --")
	var world := _world(Vector3(300.0, 0.0, 0.0))
	var links := _solver(world)
	var pivot := Vector3(300.0, 10.0, 0.0)
	var heavy := _crate(world, "heavy", 200.0, pivot + Vector3(-2.0, -3.0, 0.0))
	var light := _crate(world, "light", 40.0, pivot + Vector3(2.0, -3.0, 0.0))
	links.declare([{
		"constraint_id": "pulley", "kind": "PULLEY", "a": heavy, "b": light,
		"pivot": pivot, "length": 8.0,
	}])
	# MEASURED FROM WHERE THE ROPE GOES TAUT, not from the drop. Both
	# ends free-fall the first half-metre while the pulley is slack, and
	# measuring through that would be measuring gravity.
	await _settle(60)
	var light_started := light.global_position.y
	var heavy_started := heavy.global_position.y
	await _settle(240)
	_check(heavy.global_position.y < heavy_started - 0.3,
			"the 200 kg end descends (%.2f m)"
			% (heavy_started - heavy.global_position.y))
	_check(light.global_position.y > light_started + 0.1,
			"…and the 40 kg end is DRAWN UP by it (%.2f m) — two "
			% (light.global_position.y - light_started)
			+ "independent ropes would have dropped both")
	var total := heavy.global_position.distance_to(pivot) \
			+ light.global_position.distance_to(pivot)
	_check(total <= 8.0 + 0.3,
			"…and the total length is held at %.3f m against the authored "
			% total + "8.0 m")
	world.queue_free()
	await get_tree().process_frame


## §14.8: "a `PULLEY` where one end carries an authored mass." So it is
## the same solver with a mass that is part of the machine rather than
## part of the puzzle — and the case that says so is that swapping which
## end is heavy swaps which end goes down.
func _a_counterweight_is_a_pulley_with_a_mass() -> void:
	print("\n-- §14.8: a counterweight --")
	var world := _world(Vector3(400.0, 0.0, 0.0))
	var links := _solver(world)
	var pivot := Vector3(400.0, 10.0, 0.0)
	var platform := _crate(world, "platform", 50.0,
			pivot + Vector3(-2.0, -3.0, 0.0))
	var weight := _crate(world, "weight", 260.0,
			pivot + Vector3(2.0, -3.0, 0.0))
	links.declare([{
		"constraint_id": "cw", "kind": "COUNTERWEIGHT",
		"a": platform, "b": weight, "pivot": pivot, "length": 8.0,
	}])
	await _settle(60)
	var lifted := platform.global_position.y
	await _settle(240)
	_check(platform.global_position.y > lifted + 0.1,
			"the 260 kg counterweight raises the 50 kg platform (%.2f m)"
			% (platform.global_position.y - lifted))
	_check(links.kind_of("cw") == "COUNTERWEIGHT",
			"…and it is still declared as what it is, not silently "
			+ "rewritten to PULLEY")
	world.queue_free()
	await get_tree().process_frame


## §14.8: "`breakable_at` is checked once per tick against the solver's
## reported constraint force. On break, the constraint is removed,
## `broken` is set, and BOTH BODIES KEEP THEIR CURRENT VELOCITY." And
## with §10.5: "a broken constraint on a `required` object rebuilds with
## the object at `home_transform`."
func _a_rope_breaks_and_a_required_one_rebuilds() -> void:
	print("\n-- §14.8: breaking, and rebuilding what a puzzle needs --")
	var world := _world(Vector3(500.0, 0.0, 0.0))
	var links := _solver(world)
	var anchor := Vector3(500.0, 12.0, 0.0)
	var too_heavy := _crate(world, "too_heavy", 300.0,
			anchor - Vector3(0.0, 0.5, 0.0))
	var broken_ids: Array[String] = []
	links.broke.connect(func(id: String, _f: float) -> void:
			broken_ids.append(id))
	links.declare([{
		"constraint_id": "thin", "kind": "ROPE", "b": too_heavy,
		"anchor_a": anchor, "length": 3.0, "breakable_at": 400.0,
	}])
	await _settle(180)
	_check(links.is_broken("thin") and broken_ids.has("thin"),
			"a 300 kg load on a rope rated 400 N breaks it, once (%s)"
			% [broken_ids])
	_check(too_heavy.linear_velocity.y < -0.5,
			"…and the load keeps the velocity it had (%.2f m/s down) "
			% too_heavy.linear_velocity.y + "rather than being stopped")
	await _settle(120)
	_check(anchor.y - too_heavy.global_position.y > 6.0,
			"…and goes on falling (%.1f m below the anchor)"
			% (anchor.y - too_heavy.global_position.y))

	# THE REQUIRED CASE. A required object left hanging by a snapped rope
	# is a puzzle nobody can finish, so §10.5 puts it back at home.
	var rebuilt_ids: Array[String] = []
	links.rebuilt.connect(func(id: String) -> void: rebuilt_ids.append(id))
	var needed := _crate(world, "needed", 300.0,
			anchor + Vector3(6.0, -0.5, 0.0))
	var home := needed.global_transform
	links.declare([{
		"constraint_id": "needed_rope", "kind": "ROPE", "b": needed,
		"anchor_a": anchor + Vector3(6.0, 0.0, 0.0), "length": 3.0,
		"breakable_at": 400.0, "required": true,
	}])
	await _settle(180)
	_check(rebuilt_ids.has("needed_rope"),
			"a required object's rope breaks and REBUILDS (%s)"
			% [rebuilt_ids])
	_check(not links.is_broken("needed_rope"),
			"…so the constraint is not left in the broken state")
	_check(needed.global_position.distance_to(home.origin) < 4.0,
			"…and the object is put back at its home rather than left "
			+ "wherever it fell (%.2f m away)"
			% needed.global_position.distance_to(home.origin))
	_note("An under-rated rope on a required object breaks and rebuilds "
			+ "%d times and then holds: each rebuild puts the load back "
			% rebuilt_ids.size() + "at rest at `home_transform`, and a "
			+ "load at rest does not snatch. It does not loop. Hanging a "
			+ "required load on a rope it snaps is still a composition "
			+ "error §23.5 should catch, recorded as P-5 rather than "
			+ "answered with a rule this lane invented.")

	# AND A FORCE THAT IS NOT THE CONSTRAINT'S IS NOT OFFERED. A Godot
	# joint does not report its reaction; a proxy from the body's
	# velocity would count every contact it made too.
	var refused := links.declare([{
		"constraint_id": "brittle_hinge", "kind": "HINGE",
		"b": _crate(world, "door", 40.0, Vector3(520.0, 6.0, 0.0)),
		"anchor_a": Vector3(520.0, 7.0, 0.0), "breakable_at": 900.0,
	}])
	_check(refused.size() == 1 and "breakable_at" in refused[0],
			"`breakable_at` on a hinge is refused by name rather than "
			+ "answered with a number that is not the constraint's (%s)"
			% [refused])
	world.queue_free()
	await get_tree().process_frame


## §14.8: "single-axis rotational joint with angular limits." The limit
## is what makes a hinge a puzzle piece rather than a free spin, so the
## case is that it stops there.
func _a_hinge_turns_within_its_limits() -> void:
	print("\n-- §14.8: a hinge, with limits --")
	var world := _world(Vector3(600.0, 0.0, 0.0))
	var links := _solver(world)
	var hinge_at := Vector3(600.0, 6.0, 0.0)
	var arm := _crate(world, "arm", 40.0, hinge_at + Vector3(1.6, 0.0, 0.0),
			Vector3(3.0, 0.3, 0.6))
	var refused := links.declare([{
		"constraint_id": "gate", "kind": "HINGE", "b": arm,
		"anchor_a": hinge_at, "limit_lower": -0.9, "limit_upper": 0.9,
	}])
	_check(refused.is_empty(), "a hinge builds (%s)" % [refused])
	await _settle(30)
	var held := arm.global_position.y
	arm.apply_torque_impulse(Vector3(0.0, 120.0, 0.0))
	await _settle(180)
	_check(absf(arm.global_position.y - held) < 1.0,
			"the arm is held at the pivot rather than falling away "
			+ "(%.2f m of drift)" % absf(arm.global_position.y - held))
	_check(absf(links.value_of("gate")) <= 1.2,
			"…and it turns no further than its authored limit "
			+ "(%.3f rad against 0.9)" % links.value_of("gate"))
	world.queue_free()
	await get_tree().process_frame


## §14.8: "single-axis translational joint with limits."
func _a_slider_slides_within_its_limits() -> void:
	print("\n-- §14.8: a slider, with limits --")
	var world := _world(Vector3(700.0, 0.0, 0.0))
	var links := _solver(world)
	var track := Vector3(700.0, 6.0, 0.0)
	var block := _crate(world, "block", 50.0, track)
	var refused := links.declare([{
		"constraint_id": "drawer", "kind": "SLIDER", "b": block,
		"anchor_a": track, "limit_lower": -1.0, "limit_upper": 1.0,
	}])
	_check(refused.is_empty(), "a slider builds (%s)" % [refused])
	await _settle(30)
	block.apply_central_impulse(Vector3(400.0, 0.0, 0.0))
	await _settle(180)
	_check(absf(links.value_of("drawer")) <= 1.4,
			"a shoved block slides no further than its authored limit "
			+ "(%.3f m against 1.0)" % links.value_of("drawer"))
	_check(absf(block.global_position.z - track.z) < 0.6,
			"…and does not leave its axis (%.3f m off)"
			% absf(block.global_position.z - track.z))
	world.queue_free()
	await get_tree().process_frame


## §14.8: "Constraint chains are capped at `4` linked constraints. A
## pulley feeding a seesaw feeding a hinge is three." What is counted is
## the chain, so an unrelated constraint across the room does not use up
## anybody's budget.
func _the_chain_cap() -> void:
	print("\n-- §14.8: the chain cap --")
	var world := _world(Vector3(800.0, 0.0, 0.0))
	var links := _solver(world)
	var bodies: Array[ManipulableBody] = []
	for i in 6:
		bodies.append(_crate(world, "n%d" % i, 30.0,
				Vector3(800.0 + float(i) * 1.5, 10.0, 0.0)))
	var refusals: Array[String] = []
	for i in 5:
		refusals.append_array(links.declare([{
			"constraint_id": "c%d" % i, "kind": "ROPE",
			"a": bodies[i], "b": bodies[i + 1], "length": 1.5,
		}]))
	_check(links.has("c3") and not links.has("c4"),
			"a chain of four links builds and the fifth does not")
	_check(refusals.size() == 1 and "caps it at 4" in refusals[0],
			"…and the refusal says what the cap is and what the chain "
			+ "would have been (%s)" % [refusals])
	# AN UNRELATED CONSTRAINT IS NOT PART OF ANYBODY'S CHAIN.
	var lone_a := _crate(world, "lone_a", 30.0, Vector3(830.0, 10.0, 0.0))
	var lone_b := _crate(world, "lone_b", 30.0, Vector3(831.5, 10.0, 0.0))
	var lone := links.declare([{
		"constraint_id": "elsewhere", "kind": "ROPE",
		"a": lone_a, "b": lone_b, "length": 1.5,
	}])
	_check(lone.is_empty() and links.has("elsewhere"),
			"…and a constraint sharing no body with that chain builds "
			+ "regardless (%s)" % [lone])
	world.queue_free()
	await get_tree().process_frame


## §14.8's reason for a FIXED iteration count: "reproducible on a given
## build, and what makes the reference-solution replay in §23.5 check 20
## meaningful." Two identical setups stepped identically must land in the
## same place.
func _the_solver_is_reproducible() -> void:
	print("\n-- §14.8: fixed iterations, reproducible --")
	# THE SAME PLACE, TWICE, ONE AFTER THE OTHER. Two worlds side by side
	# would be the same setup at different world coordinates, and any
	# disagreement would then be float32 resolution rather than the
	# solver. Running them sequentially in the same spot leaves the
	# solver as the only thing that could differ.
	var landed: Array[Vector3] = []
	for _run in 2:
		var world := _world(Vector3(900.0, 0.0, 0.0))
		var links := _solver(world)
		var anchor := world.global_position + Vector3(0.0, 9.0, 0.0)
		var load := _crate(world, "load", 70.0,
				anchor + Vector3(1.7, -1.2, 0.4))
		links.declare([{
			"constraint_id": "rope", "kind": "ROPE", "b": load,
			"anchor_a": anchor, "length": 2.6,
		}])
		await _settle(200)
		landed.append(load.global_position - world.global_position)
		world.queue_free()
		await get_tree().process_frame
	var apart := landed[0].distance_to(landed[1])
	_check(apart < 0.02,
			"the same swing run twice lands in the same place (%.5f m "
			% apart + "apart) — which is what §23.5 check 20 replays "
			+ "against")


## §21.10: a `WINCH` "shortens or lengthens a named `ROPE`, `CHAIN`, or
## `PULLEY` constraint at `rate_m_per_s` while its input is `ON`, between
## `length_min` and `length_max`", and "at `length_min` or `length_max`
## stops and holds; it does not wrap or error."
func _a_winch_raises_its_load() -> void:
	print("\n-- §21.10: the winch --")
	var world := _world(Vector3(1200.0, 0.0, 0.0))
	var links := _solver(world)
	var anchor := Vector3(1200.0, 12.0, 0.0)
	var load := _crate(world, "girder", 120.0, anchor - Vector3(0.0, 0.5, 0.0))
	links.declare([{
		"constraint_id": "cable", "kind": "ROPE", "b": load,
		"anchor_a": anchor, "length": 6.0,
		"length_min": 2.0, "length_max": 6.0,
	}])
	await _settle(200)
	var low := load.global_position.y
	_check(anchor.y - low > 5.0,
			"the load hangs on 6.0 m of cable (%.2f m down)"
			% (anchor.y - low))

	var winch := Actuator.constrained("WINCH", links, "cable", 1.5)
	world.add_child(winch)
	_check(winch.buildable(), "a WINCH on a ROPE builds (%s)"
			% [winch.violations()])
	winch.set_input(true)
	await _settle(200)
	_check(load.global_position.y > low + 1.5,
			"…and winding it in RAISES the load (%.2f m)"
			% (load.global_position.y - low))
	await _settle(240)
	_check(absf(links.length_of("cable") - 2.0) < 0.05,
			"…and it stops and holds at `length_min` (%.3f m) rather than "
			% links.length_of("cable") + "wrapping or erroring")
	_check(winch.wound() > 0.95,
			"…reporting itself fully wound in (%.3f)" % winch.wound())

	# §21.1.1: IT HOLDS ITS LENGTH. "A rope does not lengthen because a
	# generator stopped."
	winch.set_input(false)
	await _settle(30)
	var paying_out := links.length_of("cable")
	_check(paying_out > 2.05,
			"the input going OFF pays the cable back out (%.3f m)"
			% paying_out)
	winch.power(false)
	await _settle(120)
	# 0.05 m, NOT 0.02: resuming from an awaited physics frame can leave
	# one more tick of this actuator's `_physics_process` between the
	# reading and the power cut, and one tick at 1.5 m/s is 0.025 m. A
	# tolerance tighter than one tick would be measuring the await.
	_check(absf(links.length_of("cable") - paying_out) < 0.05,
			"…and power loss holds the length exactly where it was "
			+ "(%.3f m)" % links.length_of("cable"))

	# AND A WINCH ON A HINGE HAS NOTHING TO SHORTEN.
	var hinged := _crate(world, "flap", 30.0, Vector3(1220.0, 6.0, 0.0))
	links.declare([{
		"constraint_id": "flap_hinge", "kind": "HINGE", "b": hinged,
		"anchor_a": Vector3(1220.0, 7.0, 0.0),
	}])
	var wrong := Actuator.constrained("WINCH", links, "flap_hinge", 1.0)
	_check(not wrong.buildable(),
			"a WINCH on a HINGE is refused — §21.10 says which family "
			+ "each of the three drives (%s)" % [wrong.violations()])
	wrong.queue_free()
	world.queue_free()
	await get_tree().process_frame


## §21.10: a `BRAKE` "locks a named `HINGE`, `SLIDER`, or `SEESAW` at its
## CURRENT VALUE while its input is `ON`; releases on `OFF`", and "a
## `BRAKE` engaging mid-swing locks at the current value, whatever it is.
## It does not snap to a limit." Plus §21.1.1's fail-safe: an unpowered
## brake is a locked brake, whatever its input says.
func _a_brake_locks_where_it_is() -> void:
	print("\n-- §21.10: the brake --")
	var world := _world(Vector3(1300.0, 0.0, 0.0))
	var links := _solver(world)
	var pivot := Vector3(1300.0, 7.0, 0.0)
	var plank := _crate(world, "plank", 60.0, pivot + Vector3(0.0, 0.0, 0.0),
			Vector3(5.0, 0.3, 1.2))
	links.declare([{
		"constraint_id": "seesaw", "kind": "SEESAW", "b": plank,
		"anchor_a": pivot, "limit_lower": -0.7, "limit_upper": 0.7,
	}])
	await _settle(20)
	plank.apply_torque_impulse(Vector3(0.0, 0.0, 40.0))
	await _settle(18)
	var mid_swing := links.value_of("seesaw")
	# THE CASE IS ONLY ABOUT SOMETHING IF THE SEESAW IS ACTUALLY MID-SWING.
	# A plank already resting on its limit would lock at the limit and
	# "does not snap to a limit" would be true by accident.
	_check(absf(mid_swing) > 0.02 and absf(mid_swing) < 0.6,
			"the seesaw is mid-swing, inside its ±0.7 limits (%.3f rad)"
			% mid_swing)
	var brake := Actuator.constrained("BRAKE", links, "seesaw")
	world.add_child(brake)
	_check(brake.buildable(), "a BRAKE on a SEESAW builds (%s)"
			% [brake.violations()])
	brake.set_input(true)
	await _settle(120)
	_check(brake.brake_engaged(), "…and engages on its input")
	_check(absf(links.value_of("seesaw") - mid_swing) < 0.25,
			"…locking mid-swing at the value it had (%.3f rad against "
			% links.value_of("seesaw") + "%.3f) rather than snapping to a "
			% mid_swing + "limit at %.2f" % 0.7)
	brake.set_input(false)
	_check(not brake.brake_engaged(), "…and releases on OFF")

	# FAIL-SAFE. §21.1.1: "an unpowered brake is a locked brake." It is
	# the one kind whose power-loss answer ignores its input.
	brake.power(false)
	_check(brake.brake_engaged(),
			"an unpowered brake ENGAGES although its input says OFF")
	brake.set_input(false)
	_check(brake.brake_engaged(),
			"…and telling it OFF again while unpowered does not release it")
	brake.power(true)
	_check(not brake.brake_engaged(),
			"…and it goes back to obeying its input when power returns")
	world.queue_free()
	await get_tree().process_frame


## §21.10: a `DRIVER` "applies torque to a named `HINGE` toward
## `target_value` at `rate_rad_per_s` while its input is `ON`… It applies
## TORQUE, NOT POSITION. It can be resisted by mass and it can stall."
## And §21.1.1: on power loss it "releases torque, and its hinge locks at
## the current value under an implicit brake."
func _a_driver_applies_torque() -> void:
	print("\n-- §21.10: the driver --")
	var world := _world(Vector3(1400.0, 0.0, 0.0))
	var links := _solver(world)
	var pivot := Vector3(1400.0, 7.0, 0.0)
	var span := _crate(world, "drawbridge", 30.0, pivot + Vector3(1.0, 0.0, 0.0),
			Vector3(2.0, 0.3, 1.6))
	# A DRAWBRIDGE HINGE IS HORIZONTAL — §14.8's `SEESAW`, "a `HINGE`
	# with its axis horizontal and its pivot offset authored". On a
	# vertical-axis hinge gravity makes no torque at all, the span hangs
	# wherever it is put, and "the hinge locks on power loss" would be
	# true of a span that was never going to move.
	links.declare([{
		"constraint_id": "bridge_hinge", "kind": "SEESAW", "b": span,
		"anchor_a": pivot, "limit_lower": -1.4, "limit_upper": 1.4,
	}])
	await _settle(30)
	var rested := links.value_of("bridge_hinge")
	var driver := Actuator.constrained("DRIVER", links, "bridge_hinge", 1.2)
	world.add_child(driver)
	driver.target_value = 1.2
	driver.torque = 2000.0
	_check(driver.buildable(), "a DRIVER on a horizontal hinge builds (%s)"
			% [driver.violations()])
	driver.set_input(true)
	await _settle(200)
	var driven := links.value_of("bridge_hinge")
	_check(absf(driven - rested) > 0.1,
			"the driver turns the hinge (%.3f rad from %.3f)"
			% [driven, rested])

	# POWER LOSS: torque goes, and the hinge locks where it is. §23.5
	# rule 28 is the reason — "a drawbridge held up by torque alone is a
	# softlock waiting for a control room three rooms away."
	driver.power(false)
	_check(links.is_locked("bridge_hinge"),
			"power loss locks the hinge under an implicit brake")
	await _settle(180)
	_check(absf(links.value_of("bridge_hinge") - driven) < 0.3,
			"…so the span stays where it was (%.3f rad) instead of "
			% links.value_of("bridge_hinge") + "swinging down")
	driver.power(true)
	_check(not links.is_locked("bridge_hinge"),
			"…and the implicit brake releases when power returns")

	# "IT CAN BE RESISTED BY MASS AND IT CAN STALL." A stalled driver
	# holds its torque and SAYS SO; it does not give up, because a driver
	# that gave up would stop holding whatever it had already lifted.
	var slab := _crate(world, "slab", 900.0, pivot + Vector3(9.0, 0.0, 0.0),
			Vector3(2.0, 0.3, 1.6))
	links.declare([{
		"constraint_id": "slab_hinge", "kind": "SEESAW", "b": slab,
		"anchor_a": pivot + Vector3(8.0, 0.0, 0.0),
		"limit_lower": -1.4, "limit_upper": 1.4,
	}])
	# LET THE SLAB COME TO REST FIRST. Measuring while it is still
	# settling charges the driver for gravity's work: the first version
	# of this read 0.093 rad against a 0.1 threshold, which is a flake
	# rather than a margin.
	await _settle(180)
	var weak := Actuator.constrained("DRIVER", links, "slab_hinge", 1.0)
	world.add_child(weak)
	weak.target_value = 1.2
	weak.torque = 2.0
	weak.set_input(true)
	var stuck := links.value_of("slab_hinge")
	await _settle(200)
	_check(absf(links.value_of("slab_hinge") - stuck) < 0.1,
			"a 2 N·m·s driver under a 900 kg slab moves it nowhere "
			+ "(%.4f rad)" % absf(links.value_of("slab_hinge") - stuck))
	_check(weak.stalled(), "…and reports itself stalled rather than "
			+ "reporting nothing")
	_check(not driver.stalled(),
			"…while the one that is actually turning does not")
	world.queue_free()
	await get_tree().process_frame


## THE AMALGAM'S OWN FIXTURE, `fx_power_loss_gantry` (U4): a `WINCH` on a
## `ROPE` suspending a cart, a `BRAKE` on a `SEESAW`, and a `DRIVER` on a
## drawbridge hinge, all in one room. "On power dropping: the winch holds
## its length, both brakes engage, the drawbridge hinge locks at its
## current value. **Nothing moves.**"
##
## That sentence is the safety property the union had to add, because
## Design 3's `POWER_OFF` made power loss "a routine, player-caused,
## whole-room event" that Design 2 never faced.
func _the_gantry_loses_power() -> void:
	print("\n-- §21.1.1 / U4: the gantry loses power --")
	var world := _world(Vector3(1500.0, 0.0, 0.0))
	var links := _solver(world)
	var hook := Vector3(1500.0, 12.0, 0.0)
	var cart := _crate(world, "cart", 180.0, hook - Vector3(0.0, 3.0, 0.0))
	var pivot := Vector3(1508.0, 7.0, 0.0)
	var plank := _crate(world, "plank", 60.0, pivot, Vector3(5.0, 0.3, 1.2))
	var bridge_pivot := Vector3(1516.0, 7.0, 0.0)
	var span := _crate(world, "span", 30.0,
			bridge_pivot + Vector3(1.0, 0.0, 0.0), Vector3(2.0, 0.3, 1.6))
	links.declare([
		{"constraint_id": "cable", "kind": "ROPE", "b": cart,
			"anchor_a": hook, "length": 4.0, "length_min": 1.5,
			"length_max": 6.0},
		{"constraint_id": "seesaw", "kind": "SEESAW", "b": plank,
			"anchor_a": pivot, "limit_lower": -0.7, "limit_upper": 0.7},
		{"constraint_id": "bridge", "kind": "SEESAW", "b": span,
			"anchor_a": bridge_pivot, "limit_lower": -1.4,
			"limit_upper": 1.4},
	])
	var winch := Actuator.constrained("WINCH", links, "cable", 1.0)
	var brake := Actuator.constrained("BRAKE", links, "seesaw")
	var driver := Actuator.constrained("DRIVER", links, "bridge", 1.0)
	# U4'S SECOND BRAKE, on the drawbridge hinge. §23.5 rule 28: "no
	# `DRIVER` on a mandatory route drives a hinge whose free rotation
	# can leave the route impassable, unless a `BRAKE` on the same hinge
	# is on the same signal." The fixture has it, so this does.
	var bridge_brake := Actuator.constrained("BRAKE", links, "bridge")
	driver.target_value = 1.0
	driver.torque = 2000.0
	for a: Actuator in [winch, brake, driver]:
		world.add_child(a)
		a.set_input(true)
	world.add_child(bridge_brake)
	_check(winch.buildable() and brake.buildable() and driver.buildable()
			and bridge_brake.buildable(),
			"the gantry's four constraint actuators all build")
	await _settle(150)
	var cable_was := links.length_of("cable")
	var cart_was := cart.global_position
	var seesaw_was := links.value_of("seesaw")
	var bridge_was := links.value_of("bridge")

	for a: Actuator in [winch, brake, driver, bridge_brake]:
		a.power(false)
	await _settle(240)

	_check(absf(links.length_of("cable") - cable_was) < 0.05,
			"the winch HOLDS its length (%.4f m, was %.4f)"
			% [links.length_of("cable"), cable_was])
	_check(cart.global_position.distance_to(cart_was) < 0.6,
			"…so the 180 kg cart does not drop (%.3f m)"
			% cart.global_position.distance_to(cart_was))
	_check(brake.brake_engaged() and links.is_locked("seesaw"),
			"the brake ENGAGES")
	_check(absf(links.value_of("seesaw") - seesaw_was) < 0.25,
			"…holding the seesaw where it was (%.3f rad, was %.3f)"
			% [links.value_of("seesaw"), seesaw_was])
	_check(links.is_locked("bridge") and bridge_brake.brake_engaged(),
			"the drawbridge hinge locks — both under the driver's implicit "
			+ "brake and under rule 28's real one, which engaged unpowered")
	_check(absf(links.value_of("bridge") - bridge_was) < 0.3,
			"…so the drawbridge stays up (%.3f rad, was %.3f)"
			% [links.value_of("bridge"), bridge_was])
	_note("§21.11's deferral — POWER_OFF waiting while the player stands "
			+ "on the cart — is the macro layer's and is not built here.")
	world.queue_free()
	await get_tree().process_frame
