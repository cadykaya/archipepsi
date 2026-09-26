extends Node
## EX50-033's PROPERTY DISTINCTION (`make godot-mass-class`).
##
## EX50-033 Unweighted Switch turns on one claim: **an object can stop
## satisfying a sensor while remaining exactly as useful to stand on.**
## Its §10 says what to do before building anything:
##
##   "Before building a platform room, verify that the same object
##    remains collidable while the plate's output changes under
##    LIGHTENED."
##
## and what the decisive control is:
##
##   "The decisive negative control replaces the class plate with a
##    summed-kilogram sensor without changing the Status. The expected
##    effect should then differ if kilograms are unchanged. That control
##    prevents the implementation from conflating two distinct mass
##    vocabularies."
##
## So this suite is that verification and that control, and nothing else.
## The summed-kilogram sensor is not written for the occasion: it is
## `PoweredLink`, the one that already exists and already ships.
##
## What lowers the class is the **real `lightened` Status**, applied
## through `ManipulableBody.apply_status` into a `StatusEffects` whose
## target kind is `object`, and read back by `MassClass.read`. There is
## no stand-in and no second vocabulary: the support declaration
## `lightened: ("object",)` and this effect landed in one change, which
## is what that table's rule requires.

const HEAVY_KG := 200.0
const MEDIUM_KG := 100.0

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
	_the_vocabulary()
	await _the_plate_reads_class()
	await _debris_does_not_add_up()
	await _the_player_does_not_count()
	await _counts_player_is_the_only_door()
	await _the_decisive_control()
	await _the_other_direction()
	await _the_shift_is_temporary()
	await _the_boundary_refuses_an_unsupported_target()
	await _an_impulse_doubles_and_a_force_does_not()
	await _eligibility_opens_and_the_boundary_holds()
	await _wind_lifts_a_lightened_crate_only()
	print("")
	if _failures == 0:
		print("GODOT MASS CLASS OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
		return
	printerr("GODOT MASS CLASS FAILED (%d of %d)" % [_failures, _checks])
	get_tree().quit(1)


## The thresholds are Design 2 §10.2's, transcribed, and the boundaries
## are where a transcription goes wrong.
func _the_vocabulary() -> void:
	print("  -- VOCABULARY: the pinned thresholds, at their edges")
	var cases := [
		[0.0, MassClass.LIGHT], [29.999, MassClass.LIGHT],
		[30.0, MassClass.MEDIUM], [119.999, MassClass.MEDIUM],
		[120.0, MassClass.HEAVY], [399.999, MassClass.HEAVY],
		[400.0, MassClass.FIXED], [5000.0, MassClass.FIXED],
	]
	for case: Array in cases:
		var got := MassClass.of_mass(float(case[0]))
		_check(got == case[1], "%.3f kg is %s" % [case[0], case[1]]
				+ ("" if got == case[1] else ", got %s" % got))
	_check(MassClass.of_mass(5.0, false) == MassClass.FIXED,
		"and a thing that cannot be manipulated is FIXED whatever it "
			+ "weighs -- §10.2's second clause")
	# The ladder, and its floor.
	_check(MassClass.step_down(MassClass.HEAVY) == MassClass.MEDIUM,
		"one step down from HEAVY is MEDIUM")
	_check(MassClass.step_down(MassClass.LIGHT) == MassClass.LIGHT,
		"and nothing falls off the bottom of the ladder")
	_check(MassClass.at_least(MassClass.FIXED, MassClass.HEAVY)
			and not MassClass.at_least(MassClass.MEDIUM, MassClass.HEAVY),
		"'at least HEAVY' admits FIXED and refuses MEDIUM")


## A stage: a floor, a class plate, and the summed-kilogram sensor that
## already ships, side by side.
func _stage() -> Dictionary:
	var world := Node3D.new()
	add_child(world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.global_position = Vector3(0.0, -0.5, 0.0)
	var plate := ClassPlate.create(Vector3(2.4, 0.12, 2.4),
			MassClass.HEAVY)
	world.add_child(plate)
	plate.global_position = Vector3(0.0, 0.06, 0.0)
	# THE CONTROL, and it is the shipping one. `PoweredLink`'s plate adds
	# up `ManipulableBody.mass` -- numerical kilograms, summed -- which is
	# exactly the sensor §10 asks to be compared against.
	var kilos := PoweredLink.create("concrete_facility",
			Vector3(0.0, 1.6, 6.0), 120.0)
	world.add_child(kilos)
	kilos.global_position = Vector3(12.0, 0.0, 0.0)
	return {"world": world, "plate": plate, "kilos": kilos}


func _crate(world: Node3D, id: String, kg: float, at: Vector3,
		size := Vector3(1.4, 1.0, 1.4)) -> ManipulableBody:
	var body := ManipulableBody.create(id, kg, size)
	world.add_child(body)
	body.global_position = at
	return body


func _settle(frames := 40) -> void:
	for _i in frames:
		await get_tree().physics_frame


## The plate reads the class the object is, and says which.
func _the_plate_reads_class() -> void:
	print("  -- PLATE: what a class sensor is actually reading")
	var kit := _stage()
	var world: Node3D = kit["world"]
	var plate: ClassPlate = kit["plate"]
	await _settle(10)
	_check(not plate.satisfied(), "an empty HEAVY plate is not satisfied")
	var crate := _crate(world, "crate", HEAVY_KG, Vector3(0.0, 0.8, 0.0))
	await _settle(60)
	_check(crate.mass_class() == MassClass.HEAVY,
		"a %.0f kg crate is HEAVY" % HEAVY_KG)
	_check(plate.satisfied(), "and it satisfies the plate")
	var reading := plate.reading()
	_check(str(reading["requires"]) == MassClass.HEAVY
			and (reading["classes"] as Array).has(MassClass.HEAVY),
		"the plate can say what it requires and what it sees: %s"
			% [reading])
	world.queue_free()


## §8: "Optional debris cannot accumulate into HEAVY on this semantic
## plate; the source contract explicitly distinguishes that from summed
## mass."
func _debris_does_not_add_up() -> void:
	print("  -- DEBRIS: three of the wrong class are still wrong")
	var kit := _stage()
	var world: Node3D = kit["world"]
	var plate: ClassPlate = kit["plate"]
	var kilos: PoweredLink = kit["kilos"]
	await _settle(10)
	for i in 3:
		var _unused := _crate(world, "debris_%d" % i, MEDIUM_KG,
				Vector3(-0.7 + 0.7 * float(i), 0.9 + 0.3 * float(i), 0.0),
				Vector3(0.6, 0.6, 0.6))
	await _settle(120)
	var total := 3.0 * MEDIUM_KG
	_check(not plate.satisfied(),
		"%0.f kg of MEDIUM debris does not make a HEAVY plate" % total)
	# ...and the sensor that DOES add up would have been held by it.
	_check(total >= kilos.threshold_kg,
		"while the same mass is %.0f kg against a %.0f kg summed "
			% [total, kilos.threshold_kg]
			+ "threshold -- the two sensors disagree by design")
	world.queue_free()


## §3: "the player's own mass class does not count toward its threshold
## in this arrangement."
func _the_player_does_not_count() -> void:
	print("  -- PLAYER: standing on it is not an occupant")
	var kit := _stage()
	var world: Node3D = kit["world"]
	var plate: ClassPlate = kit["plate"]
	var body := Player.create()
	world.add_child(body)
	body.set_spawn(Transform3D(Basis(), Vector3(0.0, 1.4, 0.0)))
	body.velocity = Vector3.ZERO
	await _settle(60)
	_check(body.global_position.y < 1.2 and body.is_on_floor(),
		"the player is standing on the plate at y=%.2f"
			% body.global_position.y)
	_check(not plate.satisfied(),
		"and the plate is not satisfied by them")
	_check(plate.occupants().is_empty(),
		"they are not even counted as an occupant")
	world.queue_free()


## `counts_player` IS THE ONLY DOOR, on a plate the player's own class
## would satisfy.
##
## `Player.mass_class()` exists now (D-10, P14: `MEDIUM` at the exported
## 80 kg), so `MassClass.of_node` no longer answers "" for the player and
## the plate's opt-in is the one rule left between a body and an object
## plate. The case above cannot show that: its plate wants `HEAVY`, which
## a `MEDIUM` player could never satisfy with or without the rule. This
## one uses a `MEDIUM` plate, where only the opt-in decides: off, the
## player stands on it and it reads empty (EX50-033's object-only plate,
## unchanged); on, the same body on the same plate satisfies it.
func _counts_player_is_the_only_door() -> void:
	print("  -- PLAYER: only a plate that opts in counts them")
	var results := {}
	for opted: bool in [false, true]:
		var kit := _stage()
		var world: Node3D = kit["world"]
		var plate: ClassPlate = kit["plate"]
		plate.requires = MassClass.MEDIUM
		plate.counts_player = opted
		var body := Player.create()
		world.add_child(body)
		body.set_spawn(Transform3D(Basis(), Vector3(0.0, 1.4, 0.0)))
		body.velocity = Vector3.ZERO
		await _settle(60)
		_check(body.global_position.y < 1.2 and body.is_on_floor(),
			"counts_player=%s: the player is standing on the plate at "
				% opted + "y=%.2f" % body.global_position.y)
		results[opted] = {"satisfied": plate.satisfied(),
				"occupants": plate.occupants().size(),
				"class": body.mass_class()}
		world.queue_free()
	_check(str(results[false]["class"]) == MassClass.MEDIUM,
		"the player's class is MEDIUM, which this plate wants (%s)"
			% results[false]["class"])
	_check(not bool(results[false]["satisfied"])
			and int(results[false]["occupants"]) == 0,
		"off (the default): the player is no occupant and the plate is "
			+ "not satisfied (%s)" % [results[false]])
	_check(bool(results[true]["satisfied"])
			and int(results[true]["occupants"]) == 1,
		"on: the same body satisfies the same plate (%s)"
			% [results[true]])
	var bare := ClassPlate.create(Vector3.ONE)
	_check(not bare.counts_player,
		"and a plate is object-only unless it is declared otherwise")
	bare.free()


## §10's DECISIVE NEGATIVE CONTROL, and §10's "verify that the same
## object remains collidable while the plate's output changes".
func _the_decisive_control() -> void:
	print("  -- CONTROL: class moves, kilograms do not, and the crate "
			+ "is still a step")
	var kit := _stage()
	var world: Node3D = kit["world"]
	var plate: ClassPlate = kit["plate"]
	var kilos: PoweredLink = kit["kilos"]
	await _settle(10)
	var crate := _crate(world, "crate", HEAVY_KG, Vector3(0.0, 0.8, 0.0))
	# The SAME crate on the summed sensor, so both readings are of one
	# object rather than of two that were set up to agree.
	var twin := _crate(world, "twin", HEAVY_KG,
			kilos.plate_position() + Vector3(0.0, 0.9, 0.0))
	await _settle(90)
	_check(plate.satisfied() and kilos.powered,
		"both sensors are held: class HEAVY, %.0f kg summed"
			% kilos.mass_on_plate())
	var top_before := crate.global_position.y + 0.5
	var kg_before := kilos.mass_on_plate()

	# ...AND THEN THE CLASS DROPS ONE STEP. Provisional, and labelled.
	crate.apply_status("lightened", 8.0, 0.40)
	twin.apply_status("lightened", 8.0, 0.40)
	await _settle(20)
	_check(crate.mass_class() == MassClass.MEDIUM,
		"the crate now reads MEDIUM")
	_check(is_equal_approx(crate.mass, HEAVY_KG),
		"while its mass is still %.0f kg -- the kilograms did not move"
			% crate.mass)
	_check(not plate.satisfied(),
		"the CLASS plate has released")
	_check(kilos.powered and is_equal_approx(kilos.mass_on_plate(),
			kg_before),
		"and the SUMMED-KILOGRAM sensor has not, reading %.0f kg still"
			% kilos.mass_on_plate())

	# STILL A STEP. Something dropped on it lands on it, as before.
	var probe := _crate(world, "probe", 5.0,
			Vector3(0.0, top_before + 1.6, 0.0),
			Vector3(0.4, 0.4, 0.4))
	await _settle(90)
	var resting := probe.global_position.y - 0.2
	_check(absf(resting - (crate.global_position.y + 0.5)) < 0.15,
		"a body dropped on the lightened crate comes to rest on its "
			+ "top at y=%.2f, not through it" % resting)
	_check(absf(crate.global_position.y - (top_before - 0.5)) < 0.2,
		"and the crate has not moved, shrunk or fallen: its top is "
			+ "still at %.2f" % (crate.global_position.y + 0.5))
	_note("the class was lowered by the REAL `lightened` Status, applied "
			+ "through `ManipulableBody.apply_status` -> `StatusEffects` "
			+ "-> `MassClass.read`. No stand-in: the support declaration "
			+ "`lightened: (object,)` and this effect landed together")
	world.queue_free()


## §6, the other direction: "A mass-field ability that changes kilograms
## without changing the plate's semantic class may not release the
## plate."
func _the_other_direction() -> void:
	print("  -- CONVERSE: kilograms move, class does not, plate holds")
	var kit := _stage()
	var world: Node3D = kit["world"]
	var plate: ClassPlate = kit["plate"]
	var kilos: PoweredLink = kit["kilos"]
	await _settle(10)
	var crate := _crate(world, "crate", HEAVY_KG, Vector3(0.0, 0.8, 0.0))
	var twin := _crate(world, "twin", HEAVY_KG,
			kilos.plate_position() + Vector3(0.0, 0.9, 0.0))
	await _settle(90)
	var before := kilos.mass_on_plate()
	_check(plate.satisfied(), "the class plate is held")
	# A MASS FIELD: real kilograms off, class untouched (150 is still
	# within HEAVY's 120..400 band).
	crate.mass = 150.0
	twin.mass = 150.0
	await _settle(20)
	_check(crate.mass_class() == MassClass.HEAVY,
		"50 kg lighter and the crate is still HEAVY")
	_check(plate.satisfied(),
		"so the class plate does NOT release -- which is the feedback "
			+ "§6 says a player must be able to tell from a broken spell")
	_check(kilos.mass_on_plate() < before,
		"while the summed sensor's reading fell from %.0f to %.0f kg"
			% [before, kilos.mass_on_plate()])
	world.queue_free()


## §9: "LIGHTENED itself is ephemeral... On restore, the crate's original
## class returns, then the plate and shutter command are recomputed."
func _the_shift_is_temporary() -> void:
	print("  -- EPHEMERAL: the class comes back and the plate re-reads")
	var kit := _stage()
	var world: Node3D = kit["world"]
	var plate: ClassPlate = kit["plate"]
	await _settle(10)
	var crate := _crate(world, "crate", HEAVY_KG, Vector3(0.0, 0.8, 0.0))
	await _settle(90)
	var flips: Array = []
	plate.occupancy_changed.connect(func(now: bool) -> void:
		flips.append(now))
	crate.apply_status("lightened", 0.5, 0.40)
	await _settle(20)
	_check(not plate.satisfied(), "the plate released")
	for _i in 90:
		await get_tree().physics_frame
		if not crate.statuses.has("lightened"):
			break
	await _settle(20)
	_check(crate.mass_class() == MassClass.HEAVY,
		"the class came back on its own")
	_check(plate.satisfied(), "and the plate is held again")
	_check(flips == [false, true],
		"the plate announced exactly one release and one re-read, got %s"
			% [flips])
	world.queue_free()


## SUPPORT IS PER TARGET, AND THE ENGINE ASKS TOO.
##
## The bridge refuses to EMIT a Status at a target the runtime does not
## implement. That is half a gate: a room applies statuses directly, and
## without the same question at the engine's own application boundary a
## scenario could start on an actor what a campaign would have been
## refused. A refusal must leave NOTHING -- no entry, and no
## `status_applied`, because a rule listening for that edge would
## otherwise see a success that did not happen.
func _the_boundary_refuses_an_unsupported_target() -> void:
	print("  -- BOUNDARY: a kind is supported ON something, not merely at all")
	var supported: Array = Constants.ECHO_STATUS_SUPPORTED_TARGETS.get("lightened", [])
	_check(supported == ["object"],
		"the export says `lightened` is implemented on %s" % [supported])

	# ON AN ACTOR: named, implemented, and not for this target.
	var actor := StatusEffects.new()
	actor.side = "self"
	var actor_events: Array = []
	actor.status_applied.connect(func(k: String) -> void:
		actor_events.append(k))
	actor.apply("lightened", 8.0, 0.40)
	_check(not actor.has("lightened"),
		"`lightened` on a `self` target is refused")
	_check(actor.active_kinds().is_empty(),
		"...leaving no active state: %s" % [actor.active_kinds()])
	_check(actor_events.is_empty(),
		"...and no `status_applied` event: %s" % [actor_events])

	# AND THE OTHER WAY ROUND, so this is not a rule about one word.
	var crate := StatusEffects.new()
	crate.side = "object"
	var crate_events: Array = []
	crate.status_applied.connect(func(k: String) -> void:
		crate_events.append(k))
	crate.apply("burning", 5.0, 1.0)
	_check(not crate.has("burning"),
		"`burning` on an `object` target is refused -- it is implemented "
			+ "on actors and nothing has implemented it on a crate")
	_check(crate_events.is_empty(), "...with no event")

	# THE POSITIVE, so the refusals are not a container that refuses all.
	crate.apply("lightened", 8.0, 0.40)
	_check(crate.has("lightened"),
		"`lightened` on an `object` target is accepted")
	_check(crate_events == ["lightened"],
		"...and announces exactly that: %s" % [crate_events])


## §15.2 gives `lightened` "incoming impulse x2.0". It says nothing
## about a continuous force, and the two are not the same thing: this
## body's KILOGRAMS never change, so the same newtons produce the same
## acceleration whatever its class. Doubling both would be inventing an
## effect.
func _an_impulse_doubles_and_a_force_does_not() -> void:
	print("  -- IMPULSE: doubled; FORCE: untouched, and that is the contract")
	var kit := _stage()
	var world: Node3D = kit["world"]
	await _settle(10)
	var plain := _crate(world, "plain", HEAVY_KG, Vector3(-4.0, 6.0, 0.0))
	var light := _crate(world, "light", HEAVY_KG, Vector3(4.0, 6.0, 0.0))
	light.apply_status("lightened", 8.0, 0.40)
	await _settle(6)
	_check(light.impulse_scale() > plain.impulse_scale(),
		"the lightened crate takes impulses at x%.1f against x%.1f"
			% [light.impulse_scale(), plain.impulse_scale()])
	var push := Vector3(0.0, 0.0, 12.0) * HEAVY_KG
	plain.receive_impulse(push)
	light.receive_impulse(push)
	await _settle(2)
	var ratio := light.linear_velocity.z / maxf(plain.linear_velocity.z, 0.001)
	_check(absf(ratio - ManipulableBody.LIGHTENED_IMPULSE) < 0.05,
		"the same impulse moves it %.2f times as fast (%.2f vs %.2f m/s)"
			% [ratio, light.linear_velocity.z, plain.linear_velocity.z])

	# AND A FORCE, on two fresh crates, does the same to both.
	var a := _crate(world, "a", HEAVY_KG, Vector3(-8.0, 6.0, 0.0))
	var b := _crate(world, "b", HEAVY_KG, Vector3(8.0, 6.0, 0.0))
	b.apply_status("lightened", 8.0, 0.40)
	await _settle(4)
	for _i in 10:
		a.receive_force(Vector3(0.0, 0.0, 900.0))
		b.receive_force(Vector3(0.0, 0.0, 900.0))
		await get_tree().physics_frame
	_check(absf(a.linear_velocity.z - b.linear_velocity.z) < 0.05,
		"the same continuous force moves both alike: %.3f and %.3f m/s"
			% [a.linear_velocity.z, b.linear_velocity.z])
	world.queue_free()


## "Becomes Physics-eligible if it was HEAVY" -- a PERMISSIVE clause.
## Nothing that could be pushed stops being pushable, which matters at
## exactly one number: 120.0 kg is the envelope's limit AND the
## MEDIUM/HEAVY boundary, read with different comparators.
func _eligibility_opens_and_the_boundary_holds() -> void:
	print("  -- ELIGIBILITY: the class opens the door, it never shuts it")
	var kit := _stage()
	var world: Node3D = kit["world"]
	await _settle(10)
	var envelope := Manipulation.Envelope.of(Constants.ENVELOPE_FORCE_N,
			Constants.ENVELOPE_RANGE_M, Constants.ENVELOPE_MASS_KG)
	var crate := _crate(world, "crate", HEAVY_KG, Vector3(0.0, 0.8, 0.0))
	await _settle(30)
	var from := crate.global_position + Vector3(0.0, 1.0, -3.0)
	var toward := crate.global_position + Vector3(0.0, 0.0, 6.0)
	var before := Manipulation.push(crate, from, toward, envelope)
	_check(str(before["refused"]) == Manipulation.TOO_HEAVY,
		"a %.0f kg HEAVY crate is refused by a %.0f kg envelope"
			% [crate.mass, envelope.mass_limit_kg])

	crate.apply_status("lightened", 8.0, 0.40)
	await _settle(4)
	var after := Manipulation.push(crate, from, toward, envelope)
	_check(str(after["refused"]) == "" and float(after["applied"]) > 0.0,
		"lightened, the same crate is eligible -- and its mass is still "
			+ "%.0f kg" % crate.mass)

	# THE BOUNDARY, unchanged in both directions.
	var edge := _crate(world, "edge", Constants.ENVELOPE_MASS_KG,
			Vector3(6.0, 0.8, 0.0))
	await _settle(30)
	var edge_from := edge.global_position + Vector3(0.0, 1.0, -3.0)
	var edge_to := edge.global_position + Vector3(0.0, 0.0, 6.0)
	var at_edge := Manipulation.push(edge, edge_from, edge_to, envelope)
	_check(str(at_edge["refused"]) == "",
		"a body at exactly %.1f kg is still pushable, as it was before "
			% edge.mass + "the class was read at all")
	_check(MassClass.of_mass(Constants.ENVELOPE_MASS_KG) == MassClass.HEAVY,
		"...even though its class is HEAVY -- the two vocabularies "
			+ "disagree at this number and the kilograms still decide")
	world.queue_free()


## "Wind and conveyors now affect it." The gate read `if body is Player`,
## so a crate in an updraft was ignored entirely. Design 1 §26.2 makes
## the interaction mass-class based, which is what makes `lightened` the
## thing that puts a heavy crate into the air.
func _wind_lifts_a_lightened_crate_only() -> void:
	print("  -- WIND: reaches objects now, and only light enough ones")
	var kit := _stage()
	var world: Node3D = kit["world"]
	var column := AffordanceNodes.Volume.new()
	column.extents = Vector3(12.0, 10.0, 12.0)
	column.influence = {"lift": 30.0, "gravity_scale": 0.75}
	column.visible_shell = false
	world.add_child(column)
	column.global_position = Vector3(0.0, 5.0, 0.0)
	await _settle(10)
	var heavy := _crate(world, "heavy", HEAVY_KG, Vector3(-2.0, 3.0, 0.0))
	var light := _crate(world, "light", HEAVY_KG, Vector3(2.0, 3.0, 0.0))
	light.apply_status("lightened", 8.0, 0.40)
	var heavy_from := heavy.global_position.y
	var light_from := light.global_position.y
	await _settle(90)
	_check(light.global_position.y > light_from,
		"the lightened crate rises: %.2f -> %.2f"
			% [light_from, light.global_position.y])
	_check(heavy.global_position.y < heavy_from,
		"the HEAVY one is not moved by air and falls: %.2f -> %.2f"
			% [heavy_from, heavy.global_position.y])
	world.queue_free()
