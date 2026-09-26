extends Node
## IS A PLAYER ACTUALLY CARRIED ON A MOVING PLATFORM?
## (`make godot-passenger-carry`)
##
## **Why this exists before any vehicle does.** `AffordanceNodes.MovingPlatform`
## is an `AnimatableBody3D` with `sync_to_physics = true`, and its docstring
## says that is *"how Godot carries a `CharacterBody3D` standing on it — a
## bespoke ride would desync from `move_and_slide`"*. That claim is the
## foundation the Blindside skiff is planned on, and **nothing has ever
## tested it**: `affordance_driver.gd`'s platform case checks loop
## determinism and that the body's own transform moves. It never puts a
## player on one.
##
## **This measures. It does not prescribe.** There are four known places in
## `player.gd` that could plausibly fight a moving deck -- the bespoke
## step-down walker (`_note_a_step_down_ahead` / `_follow_the_step_down`,
## which does a raw `move_and_collide` and forces `velocity.y = 0`), the
## step-up climb (`_climb_a_step_the_law_promises`, which teleports via
## `global_position +=`), world-space-absolute walk targets, and control
## gated on `is_on_floor()`. Whether any of them actually bites is a
## question for the physics server, not for a reading of the source. So
## this driver reports numbers, and the repair -- if one is needed at all --
## is chosen from what the numbers say.
##
## **What is measured, per case:** the passenger's offset from the deck
## origin every physics frame. A body that is carried keeps that offset
## roughly constant. A body that is not slides toward the back of the deck
## and eventually off it.
##
##   DRIFT      max |offset - offset_at_start|, in metres
##   GROUNDED   fraction of frames with `is_on_floor()` true
##   ABOARD     did the body stay within the deck footprint

const DECK := Vector3(2.4, 0.4, 2.4)
## THE DECK'S REAL EDGE. `MovingPlatform` builds a 2.4 m square, so half
## of it is 1.2 m; past that the passenger is over the lip rather than
## merely jostled. An earlier cut used 1.0 m and reported a passenger
## "leaving" while they were still standing on the deck.
const ABOARD_LIMIT := 1.15
## What counts as carried. A body perfectly carried drifts 0; the physics
## server's own tolerances and one frame of lag put a real one slightly
## above that. This is the reporting threshold, not a tuned pass mark --
## the measured number is printed either way.
const CARRIED_DRIFT := 0.35

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
	# THE SKIFF'S CASE FIRST. A rail carrier travels horizontally; the
	# shipped platform's default `travel` is vertical, so the case the
	# vehicle actually needs is the one nobody has ever run.
	await _carry("HORIZONTAL (the skiff's case)", Vector3(6.0, 0, 0))
	await _carry("VERTICAL (the shipped case)", Vector3(0, 3.0, 0))
	await _carry("DIAGONAL (a climbing segment)", Vector3(4.0, 2.0, 0))
	# THE LAST OPEN HYPOTHESIS. `player.gd` lerps `velocity.x/z` toward a
	# WORLD-SPACE absolute walk target and never adds the deck's own
	# motion into it; Godot's platform handling adds that separately
	# inside `move_and_slide`. Whether the two compose or fight is the
	# question a rider aiming at a receiver actually depends on.
	await _carry("HORIZONTAL, passenger takes a step", Vector3(6.0, 0, 0),
			"move_forward")
	_deck_size_note()
	_finish()


## Ground under everything, so a passenger that is NOT carried lands
## somewhere measurable instead of falling out of the world.
func _floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -6.0, 0)
	add_child(body)


func _carry(label: String, travel: Vector3, hold := "") -> void:
	print("  -- %s  travel=%v" % [label, travel])
	var platform := AffordanceNodes.MovingPlatform.new()
	# BEFORE `add_child`: `_ready` captures `_origin` from `position`, so a
	# platform moved afterwards would loop around the wrong point.
	platform.position = Vector3.ZERO
	platform.travel = travel
	add_child(platform)
	await get_tree().physics_frame

	# Dropped a little above the deck rather than placed exactly on it:
	# settling through a real contact is how a player arrives, and a body
	# spawned intersecting the deck would be resolved by depenetration,
	# which is not the thing being measured.
	var player := Player.create()
	add_child(player)
	player.global_position = platform.global_position \
			+ Vector3(0, DECK.y * 0.5 + 1.2, 0)
	player.velocity = Vector3.ZERO
	for _i in 30:
		await get_tree().physics_frame

	if not player.is_on_floor():
		_check(false, "%s: the passenger never landed on the deck, so "
				% label + "nothing below is a measurement of carrying")
		player.queue_free()
		platform.queue_free()
		await get_tree().process_frame
		return

	# THE OFFSET IS THE MEASUREMENT. Constant offset means carried.
	var start := player.global_position - platform.global_position
	var worst := 0.0
	var grounded := 0
	var frames := 0
	var left_at := -1.0
	# A BURST, NOT A HOLD. The first cut of this case pressed `forward`
	# for the whole five-second period and reported the passenger
	# "leaving the deck at 0.15 s" -- which is arithmetic about a 2.4 m
	# deck and a 6 m/s walk, not a fact about carrying. What a rider
	# actually does is take a step to line up a shot and stop, so that is
	# what is measured: a quarter-second of input, then carried again.
	if hold != "":
		Input.action_press(hold)
	platform.elapsed = 0.0
	var span := int(AffordanceNodes.MovingPlatform.PERIOD
			/ maxf(get_physics_process_delta_time(), 0.001))
	# ONE FOOTFALL. A quarter-second is ~1.5 m at walking speed, which is
	# most of a 2.4 m deck -- so that measured the deck's width again
	# rather than the carry. A tenth of a second is a step.
	var release_at := int(0.1 / maxf(get_physics_process_delta_time(), 0.001))
	for i in span:
		await get_tree().physics_frame
		if hold != "" and i == release_at:
			Input.action_release(hold)
		frames += 1
		if player.is_on_floor():
			grounded += 1
		var offset := player.global_position - platform.global_position
		var drift := (offset - start).length()
		worst = maxf(worst, drift)
		if left_at < 0.0 and Vector2(offset.x, offset.z).length() \
				> ABOARD_LIMIT:
			left_at = float(i) * get_physics_process_delta_time()

	if hold != "" and Input.is_action_pressed(hold):
		Input.action_release(hold)
	var aboard := left_at < 0.0
	var grounded_fraction := float(grounded) / maxf(float(frames), 1.0)
	print("    DRIFT %.3f m   GROUNDED %d/%d (%.0f%%)   ABOARD %s"
			% [worst, grounded, frames, grounded_fraction * 100.0,
				"yes" if aboard else "left the deck at %.2f s" % left_at])
	print("    start offset %v -> final %v"
			% [start.snapped(Vector3.ONE * 0.01),
				(player.global_position - platform.global_position)
					.snapped(Vector3.ONE * 0.01)])

	_check(aboard, "%s: the passenger stays on the deck" % label)
	# REPORTED SEPARATELY FROM THE PASS. Staying aboard is the contract;
	# how hard the body fought to do it is the diagnostic that says
	# whether a repair is needed and which one.
	if hold != "":
		_note("%s: drift includes the step itself -- a passenger who "
				% label + "moves is meant to move relative to the deck. "
				+ "What is measured is that the step lands, they stay "
				+ "aboard, and the deck carries them again afterwards")
	elif worst > CARRIED_DRIFT:
		_note("%s drifts %.3f m against the deck (over %.2f m) -- "
				% [label, worst, CARRIED_DRIFT]
				+ "carried, but not cleanly; a candidate repair in "
				+ "`player.gd` is indicated rather than assumed")
	if grounded_fraction < 0.9:
		_note("%s: grounded only %.0f%% of frames -- the passenger is "
				% [label, grounded_fraction * 100.0]
				+ "separating from the deck, which costs control "
				+ "authority (`is_on_floor()` gates input in player.gd)")

	player.queue_free()
	platform.queue_free()
	await get_tree().process_frame


## A FINDING FOR WHOEVER BUILDS THE CARRIER, not a defect in this class.
## `MovingPlatform` is a 2.4 m square built for stepping onto and riding,
## and a rider who walks crosses it in about four tenths of a second. A
## skiff whose passenger is expected to move -- to reach a firing
## position, to take cover behind a shield -- needs a deck sized for that
## movement, and its size is therefore a gameplay decision rather than a
## detail inherited from this class.
func _deck_size_note() -> void:
	_note("the shipped deck is 2.4 m square: a walking passenger crosses "
			+ "it in ~0.4 s. A carrier whose rider moves to aim or take "
			+ "cover needs a larger deck -- size it from the rider's "
			+ "movement, do not inherit 2.4 m from MovingPlatform")


func _finish() -> void:
	print("  MEASURED %d case(s), %d note(s)" % [_checks, _notes])
	if _failures == 0:
		print("GODOT PASSENGER CARRY OK (%d checks)" % _checks)
	else:
		print("GODOT PASSENGER CARRY FAILED (%d of %d checks)"
				% [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)
