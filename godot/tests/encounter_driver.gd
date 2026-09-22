extends Node
## THE WIDENED ENCOUNTERS, PLAYED (`make godot-encounter`).
##
## OV04 P08's other half. `roster_driver.gd` asks whether each role
## BEHAVES — one or two bodies on a bare floor, driven by hand, with the
## role as the subject. It says so itself: *"No encounter, no Zone, no
## walked route... whether encounters USE these roles is P08's question
## and a different suite's."* This is that suite.
##
## **A BRIDGE-VALID ENEMY LIST IS NOT A PLAYED ENCOUNTER.** The
## composition widening made seven more roles composable, which means a
## generated Zone can now ask for them — and "the schema accepted it" is
## not the same claim as "a player can fight it and finish the room".
## Every case here builds a real `ZoneController` from a DECLARED Zone,
## drops the controller's own player in, drives the REAL input path, and
## plays until the room is clear or the budget runs out.
##
## **IN FLIGHT, AND NOT YET A GATE.** There is no `godot-encounter`
## Makefile target on purpose: a suite in the Makefile is a suite CI must
## run, and this one still has open findings. Run it by hand with
## `godot-bin/godot --headless --path godot -- --encounter`. The target
## and the CI line land together, in the commit that makes it green.
##
## **DECLARED, and deliberately not exhaustive.** Each case names the
## roles it is about. Nothing forces all ten into one Zone: that is not a
## room anyone would generate, and a suite that built one would be
## measuring a fixture rather than a composition.
##
## **The enemy-value score is a content budget and not measured
## difficulty** (`content_value.ENEMY_VALUE`). Nothing here reads it, and
## nothing here concludes anything about it: a room at 22 is not
## "harder" than one at 18, and whether these fights are FUN is a
## playtest question the owner has not been given the chance to answer.
## What is asked is narrower and checkable: do they attack, can they be
## fought, and does the room finish.

const DT := 1.0 / 60.0

var failures := 0
var checks := 0
var notes := 0


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _note(message: String) -> void:
	notes += 1
	print("  NOTE: %s" % message)


func _ready() -> void:
	_run()


func _run() -> void:
	# WARM THE TREE BEFORE THE FIRST BUILD. `_ready` runs before any
	# physics frame has happened, and the first `ZoneController` built
	# there placed nothing: the player sat at world origin with both
	# enemies stacked on top of it, which reported as "melee do not
	# attack" for four runs. Every case after the first was fine because
	# frames had elapsed by then -- the tell that it was warm-up and not
	# the role.
	for _i in 10:
		await get_tree().physics_frame

	await _a_room_of_melee_fights_back_and_can_be_cleared()
	await _indirect_fire_reaches_a_player_who_stands_still()
	await _a_bulwark_has_to_be_flanked()
	await _a_room_of_flyers_is_completable_from_the_ground()
	await _a_beacon_dies_like_anything_else()
	await _the_room_is_not_clear_until_every_body_is()

	if failures == 0:
		print("GODOT ENCOUNTER TESTS OK (%d checks, %d notes)"
				% [checks, notes])
		get_tree().quit(0)
	else:
		print("GODOT ENCOUNTER TESTS: %d failures in %d checks"
				% [failures, checks])
		get_tree().quit(1)


# ---------------------------------------------------------------------------
# The Zone
# ---------------------------------------------------------------------------

## One arena that has to be cleared, carrying exactly the groups a case
## declares. `kill_all` is the objective under test: it is the one whose
## completion depends on the bodies rather than on where the player
## walks.
func _zone(groups: Array, width := 26.0, depth := 24.0) -> Dictionary:
	return {
		"schema_version": 7, "zone_id": "zone_fight", "seed": 11,
		"theme": "concrete_facility",
		"chambers": [{
			"id": "c001", "type": "arena", "theme": "concrete_facility",
			"width": width, "depth": depth, "wall_height": 6.0,
			"objective": "kill_all", "reward_location_id": 89100002,
			"activities": [], "features": [], "enemies": groups,
			"rewards": [], "interactables": [],
		}],
	}


func _built(zone: Dictionary) -> ZoneController:
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(zone)
	# DID THE ZONE EVEN BUILD? A case that plays a room which was never
	# laid out measures nothing and reports it as a behaviour failure:
	# every body sits at the origin, nothing has a floor, and "0.0 hp
	# lost" reads like a role that does not attack. `roster_driver`
	# learned the same lesson when four of its enemies fell out of the
	# world and it went on counting freed bodies.
	if not controller.layout_failed.is_empty():
		_check(false, "the declared Zone did not lay out: %s"
				% controller.layout_failed)
	# SETTLE BEFORE MEASURING ANYTHING. A flyer takes its hover height
	# under its own `_physics_process`; two frames after `setup` every
	# body is still standing where it was placed, so an altitude check
	# there measures the SPAWN and not the role. Half a second is enough
	# for `drifter` (2.55 m) and `diver` (1.9 m) to have climbed.
	for _i in 30:
		await get_tree().physics_frame
	var player: Player = controller.player
	_check(player != null and controller.room_bounds.has("c001")
			and (controller.room_bounds["c001"] as AABB).grow(2.0)
				.has_point(player.global_position),
			"the player starts inside the declared room (at %v, room %s)"
			% [Vector3.ZERO if player == null else player.global_position,
				str(controller.room_bounds.get("c001", AABB()))])
	return controller


func _drop(controller: ZoneController) -> void:
	Input.action_release("fire_pulse")
	controller.queue_free()
	await get_tree().process_frame


func _record(controller: ZoneController) -> Dictionary:
	for record: Dictionary in controller._chambers:
		if str(record["chamber"].get("id", "")) == "c001":
			return record
	return {}


func _living(record: Dictionary) -> Array:
	var out: Array = []
	for enemy: Variant in record.get("enemies", []):
		if is_instance_valid(enemy) and not (enemy as Enemy)._dead:
			out.append(enemy)
	return out


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

## AIM AT A BODY — at its CENTRE, which is not where its origin is.
##
## A harness setup and not a result: the player's own look is not under
## test, and a suite that also had to solve aiming would fail for two
## reasons at once and report one. But it has to aim the way a player
## aims, or it measures its own marksmanship.
##
## **THE FIRST VERSION AIMED AT THE FEET** and the damage told on it. An
## enemy's `global_position` is its origin, and `ENEMY_ENVELOPES` puts
## every body's mass well above that: `bulwark` is 2.05 m tall with its
## centre at 1.025, `drifter` hovers with its centre at 2.55. Aiming at
## the origin put the ray into the floor in front of a grounded body and
## under a flying one — the bulwark took 20.4 s to die instead of the
## 5.3 s its 90 hp implies at 17 dps, and the two flyers killed a player
## who never landed a shot on them. Neither was a finding about the
## roles; both were a finding about this function.
func _aim_at(player: Player, target: Node3D) -> void:
	var eye := player.camera.global_position
	var centre: Vector3 = target.global_position
	var envelope: Dictionary = Constants.ENEMY_ENVELOPES.get(
			(target as Enemy).archetype, {})
	if envelope.has("centre_y"):
		centre.y += float(envelope["centre_y"])
	var to: Vector3 = centre - eye
	if to.length() < 0.01:
		return
	player.camera.global_rotation = Vector3(
			asin(clampf(to.normalized().y, -1.0, 1.0)),
			atan2(-to.x, -to.z), 0.0)


## FIGHT UNTIL THE ROOM IS CLEAR, with the base kit and nothing else.
##
## The Static Pulse, through `Input.action_press("fire_pulse")` and the
## player's own `_physics_process` — not `_fire_static_pulse()` called
## by hand. A room that can only be cleared by a harness reaching past
## the input path is a room no player can clear.
##
## Returns what happened, so a case can assert on the fight and not only
## on its outcome.
func _fight(controller: ZoneController, record: Dictionary,
		budget := 2400) -> Dictionary:
	var player: Player = controller.player
	player.input_frozen = false
	var opened: float = player.hp
	var lowest: float = player.hp
	var frames := 0
	Input.action_press("fire_pulse")
	while frames < budget:
		var alive := _living(record)
		if alive.is_empty():
			break
		_aim_at(player, alive[0] as Node3D)
		await get_tree().physics_frame
		lowest = minf(lowest, player.hp)
		frames += 1
		if player._dead:
			break
	Input.action_release("fire_pulse")
	player.input_frozen = true
	return {"frames": frames, "left": _living(record).size(),
			"opened": opened, "lowest": lowest,
			"hurt": opened - lowest, "died": player._dead}


## LET THE ROOM HIT BACK while the player does nothing.
##
## **THIS IS HOW THREAT IS MEASURED, and the first draft got it wrong.**
## That version asserted on the damage taken DURING the kill run, which
## made "is this room a threat" a question about how fast the harness
## shoots: two melee need about three seconds to close and the base kit
## killed them in three and a bit, so a room full of live enemies
## reported "0.0 hp lost" and the case failed for a reason that had
## nothing to do with the roles in it.
##
## Standing still asks the question directly. Clearability is the other
## half and `_fight` answers that one; they are separate measurements
## because they are separate claims.
func _stand_still(controller: ZoneController, frames: int) -> float:
	var player: Player = controller.player
	player.input_frozen = false
	var opened: float = player.hp
	for _i in frames:
		await get_tree().physics_frame
	player.input_frozen = true
	return opened - player.hp


## WHY A ROOM DID NOT ENGAGE, in the failure rather than in a later run.
##
## "0.0 hp lost" is the symptom of at least three different problems --
## the bodies are out of aggro range, the player spawned somewhere the
## room is not, or the role does not attack -- and they want different
## fixes. `ENEMY_AGGRO_RADIUS` is 18 m, widened per role to its own
## reach, so the distance is the first thing worth knowing.
func _engagement(controller: ZoneController, record: Dictionary) -> String:
	var player: Player = controller.player
	var parts: Array[String] = []
	for enemy: Variant in _living(record):
		var body := enemy as Enemy
		var gap := body.global_position.distance_to(player.global_position)
		parts.append("%s %.1fm" % [body.archetype, gap])
	var box: AABB = record.get("bounds", AABB())
	return "player at %v (%s the room), aggro %.0f m; %s" % [
			player.global_position,
			"inside" if box.has_point(player.global_position) else "OUTSIDE",
			Constants.ENEMY_AGGRO_RADIUS,
			"nothing alive" if parts.is_empty() else ", ".join(parts)]


# ---------------------------------------------------------------------------
# The cases
# ---------------------------------------------------------------------------

## THE BASELINE, and everything else is a variation on it. Two `melee`
## close, hurt the player, die to the base kit, and the room reports
## itself finished.
func _a_room_of_melee_fights_back_and_can_be_cleared() -> void:
	print("  -- melee x2: they close, they hurt, the room clears")
	var controller := await _built(_zone([
			{"archetype": "melee", "count": 2}]))
	var record := _record(controller)
	_check(not record.is_empty(), "the declared arena became a room")
	_check(_living(record).size() == 2,
			"both declared bodies are in it, got %d"
			% _living(record).size())
	_check(not bool(record["satisfied"]),
			"and it does NOT start satisfied — two enemies are alive")

	var hurt := await _stand_still(controller, 420)
	_check(hurt > 0.0,
			"they close and they hit: seven seconds of doing nothing "
			+ "cost %.1f hp -- %s" % [hurt, _engagement(controller, record)])

	var fight := await _fight(controller, record)
	_check(int(fight["left"]) == 0,
			"and the room clears with the base kit in %d frames"
			% int(fight["frames"]))
	_check(not bool(fight["died"]),
			"without the player dying (%.1f hp left)"
			% controller.player.hp)
	controller._evaluate_objectives()
	_check(bool(record["satisfied"]),
			"kill_all is satisfied now that nothing is alive")
	await _drop(controller)


## INDIRECT FIRE DENIES GROUND, which only means something if standing
## on it costs. `artillery` has speed 0 and reach 34 -- it never closes,
## so a player who is never hurt by it is a player it is not reaching.
func _indirect_fire_reaches_a_player_who_stands_still() -> void:
	print("  -- ranged + artillery: standing still costs")
	var controller := await _built(_zone([
			{"archetype": "ranged", "count": 1},
			{"archetype": "artillery", "count": 1}], 30.0, 28.0))
	var record := _record(controller)
	_check(_living(record).size() == 2, "both are placed")

	var hurt := await _stand_still(controller, 900)
	_check(hurt > 0.0,
			"a player who does nothing for fifteen seconds is hurt "
			+ "(%.1f hp) — the shots arrive -- %s"
			% [hurt, _engagement(controller, record)])

	var fight := await _fight(controller, record)
	_check(int(fight["left"]) == 0,
			"and the room is still clearable, in %d frames"
			% int(fight["frames"]))
	await _drop(controller)


## THE HEAVIEST ROLE THAT IS NOT A BRUTE, and the one with actual
## counterplay in it.
##
## **THE FIRST VERSION OF THIS CASE WAS WRONG AND THE ROLE WAS RIGHT.**
## It stood in front of a bulwark, held the trigger, and asserted the
## room would clear; the bulwark killed the player instead and the case
## reported that as a failure. But `roster_driver` proves that a bulwark
## CANNOT BE FOUGHT FRONTALLY -- that is its whole brief -- so a case
## that fights it frontally and expects to win is a case asserting the
## opposite of the design.
##
## So this asks the question the role is built for: does the counterplay
## work? Frontal fire is measured, the player walks around, and flanking
## fire is measured against it.
func _a_bulwark_has_to_be_flanked() -> void:
	print("  -- bulwark: frontal fire is refused, flanking is not")
	var controller := await _built(_zone([
			{"archetype": "bulwark", "count": 1}]))
	var record := _record(controller)
	_check(_living(record).size() == 1, "one bulwark is placed")
	var target: Enemy = _living(record)[0]
	var opened: float = target.hp

	# FROM THE FRONT. The bulwark turns to face the player, so standing
	# still and shooting is the frontal case by construction.
	await _shoot_for(controller, target, 240)
	var frontal: float = opened - target.hp

	# ...AND FROM BEHIND. A harness setup: the player is put on the far
	# side, which is what walking around would achieve, and the shooting
	# after it is real.
	var behind: Vector3 = target.global_position \
			- target.global_transform.basis.z * 4.0
	controller.player.global_position = Vector3(
			behind.x, controller.player.global_position.y, behind.z)
	await get_tree().physics_frame
	var before_flank: float = target.hp
	await _shoot_for(controller, target, 240)
	var flanked: float = before_flank - target.hp

	_check(flanked > frontal,
			"flanking beats a frontal fight (%.1f hp against %.1f in the "
			% [flanked, frontal] + "same four seconds)")
	_note("bulwark: %.1f hp frontal / %.1f hp flanked per four seconds "
			% [frontal, flanked]
			+ "of base-kit fire. Whether that RATIO is right is a "
			+ "playtest question, and the provisional value of 7 has had "
			+ "no playtest.")
	await _drop(controller)


## HOLD THE TRIGGER ON ONE BODY for a fixed span, and report nothing --
## the caller measures what it wants from the target itself.
func _shoot_for(controller: ZoneController, target: Enemy,
		frames: int) -> void:
	var player: Player = controller.player
	player.input_frozen = false
	Input.action_press("fire_pulse")
	for _i in frames:
		if not is_instance_valid(target) or target._dead:
			break
		_aim_at(player, target)
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	player.input_frozen = true


## FLYERS HOLD ALTITUDE, and a grounded player has to be able to finish
## the room anyway. `drifter` denies melee by height; if the base kit
## could not reach it, a Zone containing one would be unsolvable for a
## player who never earned an air Echo.
func _a_room_of_flyers_is_completable_from_the_ground() -> void:
	print("  -- drifter + diver: killable from the floor")
	var controller := await _built(_zone([
			{"archetype": "drifter", "count": 1},
			{"archetype": "diver", "count": 1}], 30.0, 28.0))
	var record := _record(controller)
	_check(_living(record).size() == 2, "both flyers are placed")
	var above := 0
	for enemy: Variant in _living(record):
		if (enemy as Node3D).global_position.y > 1.6:
			above += 1
	_check(above > 0,
			"at least one is off the floor (%d of 2), so this is a "
			% above + "height problem and not a walk-up")
	var fight := await _fight(controller, record, 3600)
	_check(int(fight["left"]) == 0,
			"and the room finishes from the ground in %d frames "
			% int(fight["frames"]) + "(%d left, player %s)"
			% [int(fight["left"]),
				"DIED" if bool(fight["died"]) else "alive"])
	_check(not bool(fight["died"]),
			"with the player alive — a room a grounded player cannot "
			+ "survive is a room that needs an air Echo to be solvable, "
			+ "and nothing declares that gate")
	await _drop(controller)


## A BEACON MAKES ITS NEIGHBOURS WORSE, and is itself an ordinary body.
## Its own damage is 2.0 -- the lowest in the roster -- so a room that
## contained only beacons would be a room with no threat in it. Paired,
## which is how it is meant to appear.
func _a_beacon_dies_like_anything_else() -> void:
	print("  -- beacon + melee: the support role is a target")
	var controller := await _built(_zone([
			{"archetype": "beacon", "count": 1},
			{"archetype": "melee", "count": 1}]))
	var record := _record(controller)
	_check(_living(record).size() == 2, "both are placed")
	var hurt := await _stand_still(controller, 420)
	_check(hurt > 0.0,
			"the pair is a threat: %.1f hp for standing still -- %s"
			% [hurt, _engagement(controller, record)])
	var fight := await _fight(controller, record, 3000)
	_check(int(fight["left"]) == 0,
			"and both die like anything else, in %d frames"
			% int(fight["frames"]))
	await _drop(controller)


## THE OBJECTIVE IS ABOUT BODIES, not about time or intent. One survivor
## has to keep the room open, or `kill_all` is a timer wearing an
## objective's name.
func _the_room_is_not_clear_until_every_body_is() -> void:
	print("  -- kill_all: one survivor keeps the room open")
	var controller := await _built(_zone([
			{"archetype": "scuttler", "count": 3}], 30.0, 28.0))
	var record := _record(controller)
	var placed := _living(record).size()
	_check(placed == 3, "three scuttlers are placed, got %d" % placed)

	# Kill all but one, directly: the fight itself is the previous
	# cases' subject, and this one is about the predicate.
	var alive := _living(record)
	for i in range(alive.size() - 1):
		(alive[i] as Enemy).take_damage(9999.0, Vector3.FORWARD, 0.0)
	await get_tree().physics_frame
	controller._evaluate_objectives()
	_check(_living(record).size() == 1, "one is left")
	_check(not bool(record["satisfied"]),
			"and the room is NOT satisfied with a body still standing")

	var fight := await _fight(controller, record, 1800)
	_check(int(fight["left"]) == 0, "the last one dies")
	controller._evaluate_objectives()
	_check(bool(record["satisfied"]), "and only then is the room clear")
	await _drop(controller)
