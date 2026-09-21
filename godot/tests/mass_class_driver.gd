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
## **`lightened` IS NOT IN THE ENGINE AND IS NOT ADDED HERE.** See F-15.
## `StatusEffects.apply` refuses any kind outside the closed, GENERATED
## `Constants.ECHO_STATUS_KINDS`, and widening that enum is a shared
## bridge-schema change whose honest scope is the Status's whole
## specified effect — impulse, wind, conveyors and Physics eligibility
## as well as class. A kind the schema admits and no system implements
## is the inert-component failure that guard exists to prevent. It is
## raised as **D-7** and is not taken.
##
## What lowers the class here is `ManipulableBody`'s **provisional,
## room-local class shift**, which has the exact shape the Status would
## have and is named so it cannot be mistaken for it. That substitution
## does not weaken the claim these cases make: the claim is about what
## the two SENSORS do when the class moves and the kilograms do not, and
## it is true whatever moved the class.
##
## What this suite therefore does NOT establish: that `lightened` works,
## that the Amalgam Status system produced anything, or that EX50-033 is
## built. The room is not built.

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
	await _the_decisive_control()
	await _the_other_direction()
	await _the_shift_is_temporary()
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
	crate.shift_class_provisionally(1, 8.0)
	twin.shift_class_provisionally(1, 8.0)
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
	_note("the class was lowered by `ManipulableBody."
			+ "shift_class_provisionally`, NOT by the `lightened` "
			+ "Status, which this engine does not have (F-15, D-7). "
			+ "What is measured is what the two sensors do when a class "
			+ "moves and kilograms do not")
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
	crate.shift_class_provisionally(1, 0.5)
	await _settle(20)
	_check(not plate.satisfied(), "the plate released")
	for _i in 90:
		await get_tree().physics_frame
		if crate.shift_left() <= 0.0:
			break
	await _settle(20)
	_check(crate.mass_class() == MassClass.HEAVY,
		"the class came back on its own")
	_check(plate.satisfied(), "and the plate is held again")
	_check(flips == [false, true],
		"the plate announced exactly one release and one re-read, got %s"
			% [flips])
	world.queue_free()
