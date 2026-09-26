extends Node
## O05-09.1: `rooted` and `anchored` on an ENEMY (`make godot-status-family`).
##
## Design 5 §15.2, per target, and nothing looser:
##
## - `rooted`: "Cannot move under its own power; **can** still be pushed,
##   pulled, and thrown, unlike `anchored`; attacks continue."
## - `anchored`: "`mass_class` becomes `FIXED`; immune to all impulse,
##   wind, conveyor, and Physics; actor movement speed `0.0`, attacks
##   continue."
##
## **WHAT "ITS OWN POWER" IS, PER ROLE.** Every motion an enemy makes by
## itself reads `Enemy._held_in_place`: the approach, the job walk, a
## charger's rush, a diver's dive and a flyer's station. Turning,
## attacking and a beacon's pulse do not move it and are not withheld. A
## charger's attack IS a rush, so held it lunges where it stands; a
## diver's dive happens where it hangs; a flyer neither climbs back nor
## falls. Those are readings, stated in the ledger (O05-09.1).
##
## **DIRECT APPLICATION** first -- `statuses.apply`, the boundary every
## path goes through -- on a bare floor with the role as the subject. The
## last case is the **REAL PATH**: an Echo projectile whose on-hit Status
## is `rooted`, fired through the real input binding in a declared Zone's
## arena. That Echo is an INJECTED component: the bridge validates its
## on-hit modifier (`test_status_guarantee.py`) and no provider emits one
## yet, so the case proves the runtime, not a delivery.

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
	for _i in 10:
		await get_tree().physics_frame
	await _rooted_takes_no_step_and_still_hits()
	await _anchored_takes_no_step_and_no_knock()
	await _it_walks_again_when_it_expires()
	await _a_charge_and_a_dive_happen_where_they_stand()
	await _a_flyer_holds_where_it_is_and_a_bulwark_still_turns()
	await _a_real_on_hit_roots_an_enemy_in_a_declared_arena()
	if failures == 0:
		print("GODOT STATUS FAMILY OK (%d checks, %d notes)"
				% [checks, notes])
		get_tree().quit(0)
	else:
		print("GODOT STATUS FAMILY: %d failures in %d checks"
				% [failures, checks])
		get_tree().quit(1)


# ------------------------------------------------------------- building

func _settle(frames := 10) -> void:
	for _i in frames:
		await get_tree().physics_frame


## A floor to stand on, wide enough for a row of roles.
func _stage() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160.0, 1.0, 80.0)
	shape.shape = box
	ground.add_child(shape)
	root.add_child(ground)
	ground.position = Vector3(0.0, -0.5, 0.0)
	return root


func _enemy(root: Node3D, role: String, at: Vector3) -> Enemy:
	var made := Enemy.create(role, "concrete_facility")
	root.add_child(made)
	made.global_position = at
	return made


func _target(root: Node3D, at: Vector3) -> Player:
	var body := Player.create()
	root.add_child(body)
	body.global_position = at
	body.velocity = Vector3.ZERO
	return body


## Gone before the next case builds: `Enemy._find_player` takes the first
## player in the group, and a leftover would be the one every enemy in
## the next case watched.
func _drop(root: Node3D) -> void:
	root.queue_free()
	for _i in 3:
		await get_tree().process_frame
		await get_tree().physics_frame


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## How far a body travels over `frames` physics frames, on the floor.
func _travel(body: Node3D, frames: int) -> float:
	var from := body.global_position
	await _settle(frames)
	return _flat(body.global_position - from)


## The player steps into a melee enemy's reach; did it land a blow?
func _hit_in_reach(enemy: Enemy, mark: Player, frames := 150) -> float:
	var ahead := -enemy.global_transform.basis.z
	ahead.y = 0.0
	mark.global_position = enemy.global_position \
			+ ahead.normalized() * 1.4 + Vector3(0.0, 0.1, 0.0)
	mark.velocity = Vector3.ZERO
	var before := mark.hp
	for _i in frames:
		await get_tree().physics_frame
		if mark.hp < before:
			break
	return before - mark.hp


# ------------------------------------------------------------- the cases

## `rooted` on a melee enemy: no step toward the player, the blow still
## lands when the player walks into reach, and a knock still moves it.
func _rooted_takes_no_step_and_still_hits() -> void:
	print("  -- ROOTED: no step of its own, the attack kept, a knock taken")
	var root := _stage()
	var mark := _target(root, Vector3(0.0, 1.0, 0.0))
	var held := _enemy(root, "melee", Vector3(-4.0, 1.0, -8.0))
	var loose := _enemy(root, "melee", Vector3(4.0, 1.0, -8.0))
	await _settle(20)
	held.statuses.apply("rooted", 30.0, 1.0)
	# CAUGHT MID-STRIDE, its momentum runs down at the rate an enemy
	# standing in reach sheds it; what follows is measured once it has.
	var slide := await _travel(held, 20)
	var loose_from := loose.global_position
	var held_moved := await _travel(held, 90)
	var loose_moved := _flat(loose.global_position - loose_from)
	_check(held.statuses.has("rooted") and slide < 0.3 and held_moved < 0.01
			and loose_moved > 2.0,
			"rooted mid-stride, a melee enemy sheds its momentum in %.2f m "
			% slide + "and then takes no step (%.4f m in 1.5 s), while an "
			% held_moved + "unrooted one closes %.2f m" % loose_moved)
	loose.queue_free()
	await _settle(2)
	var place := held.global_position
	var dealt := await _hit_in_reach(held, mark)
	_check(dealt > 0.0 and _flat(held.global_position - place) < 0.05,
			"attacks continue: the player steps into its reach and takes "
			+ "%.1f, and it struck without stepping (%.3f m)"
			% [dealt, _flat(held.global_position - place)])
	# A KNOCK STILL MOVES IT -- "can still be pushed ... unlike anchored".
	mark.global_position = Vector3(0.0, 1.0, 12.0)
	await _settle(4)
	var knocked_from := held.global_position
	held.apply_knockback(Vector3(8.0, 0.0, 0.0))
	await _settle(40)
	var knocked := _flat(held.global_position - knocked_from)
	_check(knocked > 0.25,
			"and a knock still moves it: %.2f m from an 8 m/s knock" % knocked)
	await _drop(root)


## `anchored`: the same stillness, the same blow, and no knock at all --
## and the verbs refuse it as FIXED rather than as an unmodelled mass.
func _anchored_takes_no_step_and_no_knock() -> void:
	print("  -- ANCHORED: no step, no knock, and FIXED to the verbs")
	var root := _stage()
	var mark := _target(root, Vector3(0.0, 1.0, 0.0))
	var fixed := _enemy(root, "melee", Vector3(-4.0, 1.0, -8.0))
	var rooted := _enemy(root, "melee", Vector3(4.0, 1.0, -8.0))
	var plain := _enemy(root, "melee", Vector3(12.0, 1.0, -30.0))
	await _settle(20)
	fixed.statuses.apply("anchored", 30.0, 1.0)
	rooted.statuses.apply("rooted", 30.0, 1.0)
	# "FIXED IN PLACE": no momentum to shed, mid-stride or not.
	var still := await _travel(fixed, 90)
	_check(fixed.statuses.has("anchored") and still < 0.01,
			"anchored mid-stride, it stops where it is: %.4f m in 1.5 s"
			% still)
	await _settle(20)
	var fixed_from := fixed.global_position
	var rooted_from := rooted.global_position
	fixed.apply_knockback(Vector3(8.0, 0.0, 0.0))
	rooted.apply_knockback(Vector3(8.0, 0.0, 0.0))
	await _settle(40)
	var fixed_knocked := _flat(fixed.global_position - fixed_from)
	var rooted_knocked := _flat(rooted.global_position - rooted_from)
	_check(fixed_knocked < 0.001 and rooted_knocked > 0.25,
			"immune to impulse: the same 8 m/s knock moves the anchored one "
			+ "%.4f m and the rooted one %.2f m"
			% [fixed_knocked, rooted_knocked])
	# The verbs. PUSH, PULL and PIN are the actor verbs (§14.2).
	var eye := mark.camera.global_position
	var numbers: Dictionary = Manipulation.PHYSICS_PROFILES["ab_physics_light"]
	var space := get_viewport().world_3d.direct_space_state
	var on_fixed := Manipulation.target_refusal("PUSH", fixed, eye, numbers,
			space)
	var on_rooted := Manipulation.target_refusal("PUSH", rooted, eye,
			numbers, space)
	var on_plain := Manipulation.target_refusal("PULL", plain, eye, numbers,
			space)
	var held_fixed := Manipulation.target_refusal("HOLD", fixed, eye,
			numbers, space)
	_check(on_fixed == Manipulation.FIXED
			and on_rooted == Manipulation.ACTOR_MASS_UNMODELLED
			and on_plain == Manipulation.ACTOR_MASS_UNMODELLED
			and held_fixed == Manipulation.ACTOR_RULE,
			"to the verbs, an anchored enemy is FIXED (%s); a rooted one and "
			% on_fixed + "a plain one are still unmodelled (%s, %s); HOLD is "
			% [on_rooted, on_plain] + "the actor rule either way (%s)"
			% held_fixed)
	rooted.queue_free()
	plain.queue_free()
	await _settle(2)
	var place := fixed.global_position
	var dealt := await _hit_in_reach(fixed, mark)
	_check(dealt > 0.0 and _flat(fixed.global_position - place) < 0.01,
			"attacks continue: the player in its reach takes %.1f" % dealt)
	await _drop(root)


## The Status runs out and the legs come back.
func _it_walks_again_when_it_expires() -> void:
	print("  -- EXPIRY: rooted for a second, then walking")
	var root := _stage()
	var _mark := _target(root, Vector3(0.0, 1.0, 0.0))
	var held := _enemy(root, "melee", Vector3(0.0, 1.0, -10.0))
	await _settle(20)
	held.statuses.apply("rooted", 1.0, 1.0)
	await _settle(20)
	var during := await _travel(held, 30)
	await _settle(20)
	var gone := not held.statuses.has("rooted")
	var after := await _travel(held, 60)
	_check(during < 0.05 and gone and after > 1.0,
			"for its 1.0 s it takes no step (%.3f m once stopped); expired, it closes "
			% during + "%.2f m in the next second" % after)
	await _drop(root)


## THE COMMITTED MOTIONS, held. With no player in the world, so what is
## measured is the motion and not a collision.
func _a_charge_and_a_dive_happen_where_they_stand() -> void:
	print("  -- A CHARGE AND A DIVE, held: the attack where it stands")
	var root := _stage()
	var held := _enemy(root, "charger", Vector3(-20.0, 1.0, 0.0))
	var loose := _enemy(root, "charger", Vector3(-10.0, 1.0, 0.0))
	await _settle(6)
	held.statuses.apply("rooted", 30.0, 1.0)
	await _settle(20)
	var held_from := held.global_position
	var loose_from := loose.global_position
	for foe: Enemy in [held, loose]:
		foe._rush_dir = Vector3(0.0, 0.0, -1.0)
		foe._rush = Constants.CHARGER_RUSH_SECONDS
	# The rush is 1.1 s; its recovery follows it.
	await _settle(80)
	var held_ran := _flat(held.global_position - held_from)
	var loose_ran := _flat(loose.global_position - loose_from)
	_check(held_ran < 0.1 and loose_ran > 3.0 and held._recover > 0.0,
			"a rooted charger's rush goes nowhere (%.3f m) and still ends "
			% held_ran + "in its recovery, while an unrooted one's carries "
			+ "%.2f m" % loose_ran)
	var diver := _enemy(root, "diver", Vector3(10.0, 2.0, 0.0))
	var control := _enemy(root, "diver", Vector3(20.0, 2.0, 0.0))
	await _settle(60)
	diver.statuses.apply("rooted", 30.0, 1.0)
	await _settle(30)
	var dive_from := diver.global_position
	var control_from := control.global_position
	for foe: Enemy in [diver, control]:
		foe._rush_dir = Vector3(0.0, -0.3, -1.0).normalized()
		foe._dive = Constants.DIVER_DIVE_SECONDS
	await _settle(20)
	var dived := diver.global_position.distance_to(dive_from)
	var control_dived := control.global_position.distance_to(control_from)
	_check(dived < 0.1 and control_dived > 1.0,
			"a rooted diver's dive happens where it hangs (%.3f m); an "
			% dived + "unrooted one's carries %.2f m" % control_dived)
	await _drop(root)


## A FLYER'S STATION IS ITS OWN POWER, and TURNING IS NOT MOVING.
func _a_flyer_holds_where_it_is_and_a_bulwark_still_turns() -> void:
	print("  -- A FLYER HELD, AND A BULWARK THAT STILL TURNS")
	var root := _stage()
	var held := _enemy(root, "drifter", Vector3(-20.0, 4.0, 0.0))
	var loose := _enemy(root, "drifter", Vector3(-40.0, 4.0, 0.0))
	await _settle(90)
	held.statuses.apply("rooted", 30.0, 1.0)
	await _settle(30)
	var held_from := held.global_position
	var loose_from := loose.global_position
	await _settle(120)
	var held_moved := held.global_position.distance_to(held_from)
	var loose_moved := _flat(loose.global_position - loose_from)
	# "Neither falls" is asked of its BODY: the pivot rests on the floor
	# and the body hangs at the envelope's hover height above it (PT-12).
	_check(held_moved < 0.05 and held.body_centre().y > 2.0
			and loose_moved > 0.3,
			"a rooted drifter stays where it hangs (%.3f m in 2 s, body y "
			% held_moved + "%.2f): it neither drifts nor " % held.body_centre().y
			+ "falls, while an unrooted one drifts %.2f m" % loose_moved)
	# OFF STATION, IT DOES NOT CLIMB BACK: the station is its own power.
	# **DIRECT HANDLER.** Both are put a metre below where they hang. A
	# knock was the first probe and measured nothing: a flyer's station
	# hold overwrites its vertical velocity every frame, so a downward
	# knock never moved the unrooted control either.
	for foe: Enemy in [held, loose]:
		foe.global_position.y -= 1.0
	await _settle(2)
	var held_low := held.global_position.y
	var loose_low := loose.global_position.y
	await _settle(90)
	var held_back := held.global_position.y - held_low
	var loose_back := loose.global_position.y - loose_low
	_check(absf(held_back) < 0.05 and loose_back > 0.5,
			"a metre below its station, the rooted drifter stays there "
			+ "(%.3f m back up in 1.5 s), while an unrooted one climbs " % held_back
			+ "%.2f m back" % loose_back)
	await _drop(root)
	# THE BULWARK: rooted, it still turns to meet the player.
	#
	# THE PLAYER FIRST, AND SETTLED. Made in the same frame, the player's
	# body stood at the world origin for one physics step -- where this
	# bulwark was placed -- so the bulwark was lifted onto it and then
	# carried 8 m when the player's own position arrived: two runs of this
	# case measured that ride and called it a step. Rooted at once, too:
	# left to walk, it would reach the player and climb them (P-4).
	var stage := _stage()
	var mark := _target(stage, Vector3(0.0, 1.0, -8.0))
	await _settle(5)
	var wall := _enemy(stage, "bulwark", Vector3(0.0, 1.0, 0.0))
	await _settle(10)
	wall.statuses.apply("rooted", 30.0, 1.0)
	await _settle(60)
	var facing := -wall.global_transform.basis.z
	var place := wall.global_position
	# To its side, well inside its notice and out of its reach.
	mark.global_position = Vector3(7.0, 1.0, 0.0)
	mark.velocity = Vector3.ZERO
	await _settle(150)
	var now := -wall.global_transform.basis.z
	var turned := rad_to_deg(Vector2(facing.x, facing.z).angle_to(
			Vector2(now.x, now.z)))
	_check(absf(turned) > 45.0 and _flat(wall.global_position - place) < 0.05
			and wall.global_position.y < 1.5,
			"a rooted bulwark still turns to meet the player (%.0f°) and "
			% absf(turned) + "takes no step (%.3f m)"
			% _flat(wall.global_position - place))
	await _drop(stage)


# ------------------------------------------------------------- the real path

func _zone(groups: Array) -> Dictionary:
	return {
		"schema_version": 7, "zone_id": "zone_status", "seed": 11,
		"theme": "concrete_facility",
		"chambers": [{
			"id": "c001", "type": "arena", "theme": "concrete_facility",
			"width": 26.0, "depth": 24.0, "wall_height": 6.0,
			"objective": "kill_all", "reward_location_id": 89100002,
			"activities": [], "features": [], "enemies": groups,
			"rewards": [], "interactables": [],
		}],
	}


func _aim(player: Player, point: Vector3) -> void:
	var eye := player.camera.global_position
	var flat := Vector3(point.x - eye.x, 0.0, point.z - eye.z)
	if flat.length() > 0.001:
		player.rotation.y = atan2(-flat.x, -flat.z)
	var rise := point.y - eye.y
	player.camera.rotation.x = atan2(rise, maxf(flat.length(), 0.001))


## **INTEGRATED, with an injected Echo.** A declared Zone's arena, the
## controller's own player, the real `fire_echo` binding, a real
## projectile, the real on-hit Status and a real melee enemy -- which was
## closing on the player and stops.
func _a_real_on_hit_roots_an_enemy_in_a_declared_arena() -> void:
	print("  -- THE REAL PATH: an on-hit `rooted`, fired in a declared arena")
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	controller.add_child(pool)
	controller.setup(_zone([{"archetype": "melee", "count": 1}]))
	var player: Player = controller.player
	if player != null:
		player.stat_stack.pool = pool
	await _settle(30)
	var foe: Enemy = null
	for record: Dictionary in controller._chambers:
		for body: Variant in record.get("enemies", []):
			if is_instance_valid(body):
				foe = body
	_check(controller.layout_failed.is_empty() and player != null
			and foe != null,
			"the declared arena laid out with its player and one melee")
	if player == null or foe == null:
		controller.queue_free()
		await _settle(4)
		return
	# CLOSING ON THE PLAYER before anything is fired: the stop measured
	# below is a stop, not an enemy that was standing still anyway.
	var waited := 0
	while not foe._has_noticed and waited < 240:
		await get_tree().physics_frame
		waited += 1
	var closing := await _travel(foe, 15)
	var gap := _flat(foe.global_position - player.global_position)
	player.runtimes["echo_a"].set_equipped({"kind": "action",
			"component_id": "act_probe_root", "slot": "echo_a",
			"cooldown": 0.5,
			"primitive": {"type": "projectile_damage", "damage": 1.0,
				"speed": 40.0, "lifetime": 2.0, "gravity_scale": 0.0,
				"bounces": 0},
			"modifiers": [{"type": "apply_status_on_hit",
				"status": "rooted", "duration": 4.0, "magnitude": 1.0}]})
	player.runtimes["echo_a"].reset_cooldown()
	_aim(player, foe.global_position + Vector3.UP * 0.9)
	Input.action_press("fire_echo")
	await _settle(2)
	Input.action_release("fire_echo")
	var landed := 0
	while not foe.statuses.has("rooted") and landed < 60:
		await get_tree().physics_frame
		_aim(player, foe.global_position + Vector3.UP * 0.9)
		landed += 1
	var rooted := foe.statuses.has("rooted")
	var hurt := foe.hp < foe.max_hp
	var slide := await _travel(foe, 20)
	var stopped := await _travel(foe, 60)
	_check(closing > 0.3 and gap > 3.0 and rooted and hurt
			and slide < 0.3 and stopped < 0.01,
			"closing at %.2f m per quarter-second from %.1f m, the melee "
			% [closing, gap] + "is hit (%.1f/%.1f) and rooted by the Echo's "
			% [foe.hp, foe.max_hp] + "own on-hit Status; it sheds its stride "
			+ "in %.2f m and then takes no step: %.4f m in the next second"
			% [slide, stopped])
	_note("the Echo here is injected (`set_equipped`); the bridge admits "
			+ "its on-hit `rooted`, and no provider emits one yet")
	controller.queue_free()
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
