extends Node
## THE KINETIC PAIR ON EVERY TARGET THE RUNTIME MODELS
## (`make godot-status-kinetic`).
##
## H-STATUS, O05-09.1's remainder: "anchored object/player; lightened
## enemy/player". Design 5 §15.2's exact effects:
##
##   `anchored`   "Fixed in place." `mass_class` becomes FIXED; immune to
##                all impulse, wind, conveyor and Physics; actor movement
##                0.0, attacks continue; player movement 0.0, jump
##                blocked, all other actions permitted.
##   `lightened`  "Lighter than it should be." `mass_class` drops one
##                step; incoming impulse x2.0; wind and conveyors now
##                affect it.
##
## and Design 1 item 72: the two never coexist -- applying either removes
## the other.
##
## **THE GATE IS THE CONTRACT'S.** `StatusEffects` applies a kind to a
## target only once `SUPPORTED_STATUS_TARGETS` -- the bridge's schema,
## Dess's -- declares the runtime implements it there, and none of these
## four is declared yet. So each case hands its container the table AS IT
## WILL BE DECLARED and applies through the real path; and the first case
## asserts that the production gate agrees with the production table,
## whichever way Dess has declared it by the time this runs. On a runtime
## without that seam (the reproduction) the Status is written where an
## application would have put it, so what is measured is whether anything
## reads it.
##
## Everything else is the real thing: the real `Player` driven through
## `Input`, real enemies, real crates on a real floor.

const DECLARED := {"anchored": ["enemy", "object", "self"],
		"lightened": ["enemy", "object", "self"]}
const LONG := 30.0

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
	await _the_gate_is_the_contracts()
	await _an_anchored_player_does_not_move()
	await _it_climbs_nothing_and_shoves_nothing()
	await _it_is_no_passenger()
	await _an_anchored_player_acts()
	await _an_anchored_player_weighs_fixed_and_then_does_not()
	await _a_lightened_player()
	await _a_lightened_enemy()
	await _an_anchored_object()
	await _the_anchor_and_the_other_holds()
	if failures == 0:
		print("GODOT STATUS KINETIC OK (%d checks, %d notes)"
				% [checks, notes])
		get_tree().quit(0)
	else:
		print("GODOT STATUS KINETIC: %d failures in %d checks"
				% [failures, checks])
		get_tree().quit(1)


# ------------------------------------------------------------- building

func _settle(frames := 10) -> void:
	for _i in frames:
		await get_tree().physics_frame


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


func _player(root: Node3D, at: Vector3) -> Player:
	var body := Player.create()
	root.add_child(body)
	body.global_position = at
	body.velocity = Vector3.ZERO
	return body


func _crate(root: Node3D, id: String, kg: float, at: Vector3,
		bolted := false) -> ManipulableBody:
	var body := ManipulableBody.create(id, kg, Vector3(1.0, 1.0, 1.0),
			bolted)
	root.add_child(body)
	body.global_position = at
	return body


func _drop(root: Node3D) -> void:
	for action: String in ["move_forward", "jump", "fire_mobility",
			"fire_utility", "interact"]:
		Input.action_release(action)
	root.queue_free()
	for _i in 3:
		await get_tree().process_frame
		await get_tree().physics_frame


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## The table as it will be declared, over the generated one.
func _as_declared() -> Dictionary:
	var map: Dictionary = Constants.ECHO_STATUS_SUPPORTED_TARGETS.duplicate(
			true)
	map.merge(DECLARED, true)
	return map


## Apply `kind` to a container through the real path, the table handed
## over as it will be declared. On a runtime without that seam, write it
## where the application would have.
func _put(statuses: StatusEffects, kind: String, seconds: float) -> void:
	if "supported" in statuses:
		statuses.supported = _as_declared()
		statuses.apply(kind, seconds, 1.0)
		return
	statuses._active[kind] = {"remaining": seconds, "magnitude": 1.0}


func _put_object(body: ManipulableBody, kind: String, seconds: float) -> void:
	if body.statuses == null:
		body.statuses = StatusEffects.new()
		body.statuses.side = "object"
	if "supported" in body.statuses:
		body.statuses.supported = _as_declared()
		body.apply_status(kind, seconds, 1.0)
		return
	body.statuses._active[kind] = {"remaining": seconds, "magnitude": 1.0}
	body.set_physics_process(true)


## Hold `action` for `frames`, reading how far and how high the body went.
func _hold(body: Player, action: String, frames: int) -> Dictionary:
	var from := body.global_position
	var high := 0.0
	Input.action_press(action)
	for _i in frames:
		await get_tree().physics_frame
		high = maxf(high, body.global_position.y - from.y)
	Input.action_release(action)
	return {"travel": _flat(body.global_position - from), "rise": high}


## A jump, pressed as a player presses it: a few frames down, then let go.
func _jump(body: Player, frames := 60) -> Dictionary:
	var from := body.global_position
	var high := 0.0
	var jumps := [0]
	var count := func() -> void: jumps[0] += 1
	body.jumped.connect(count)
	Input.action_press("jump")
	for frame in frames:
		if frame == 3:
			Input.action_release("jump")
		await get_tree().physics_frame
		high = maxf(high, body.global_position.y - from.y)
	Input.action_release("jump")
	body.jumped.disconnect(count)
	return {"rise": high, "jumps": jumps[0]}


# ------------------------------------------------------------- the gate

func _the_gate_is_the_contracts() -> void:
	print("  -- THE GATE IS THE CONTRACT'S")
	for pair: Array in [["anchored", "self"], ["anchored", "object"],
			["lightened", "self"], ["lightened", "enemy"]]:
		var kind: String = pair[0]
		var target: String = pair[1]
		var container := StatusEffects.new()
		container.side = target
		container.apply(kind, 5.0, 1.0)
		var declared: bool = target in (Constants.ECHO_STATUS_SUPPORTED_TARGETS
				.get(kind, []) as Array)
		_check(container.has(kind) == declared,
			"%s on %s: the production gate %s it, as the contract "
				% [kind, target, "applies" if container.has(kind)
					else "refuses"]
				+ "table %s it" % ("declares" if declared
					else "does not yet declare"))


# ------------------------------------------------------------- the player

func _an_anchored_player_does_not_move() -> void:
	print("  -- AN ANCHORED PLAYER DOES NOT MOVE (played)")
	var root := _stage()
	var free := _player(root, Vector3(-20.0, 0.1, 0.0))
	var held := _player(root, Vector3(20.0, 0.1, 0.0))
	await _settle(20)
	_put(held.statuses, "anchored", LONG)
	await _settle(2)
	# WALKING. Both bodies take the same input on the same frames.
	var from_free := free.global_position
	var from_held := held.global_position
	Input.action_press("move_forward")
	await _settle(60)
	Input.action_release("move_forward")
	await _settle(10)
	var walked := _flat(free.global_position - from_free)
	var stayed := _flat(held.global_position - from_held)
	_check(walked > 3.0 and stayed < 0.05,
		"a second held forward: the free player walks %.2f m, the "
			% walked + "anchored one %.3f m (movement 0.0)" % stayed)
	# JUMPING.
	var free_jump := await _jump(free)
	var held_jump := await _jump(held)
	_check(free_jump["rise"] > 1.2 and free_jump["jumps"] == 1
			and held_jump["rise"] < 0.02 and held_jump["jumps"] == 0,
		"jump: the free player rises %.2f m (%d jump), the anchored one "
			% [free_jump["rise"], free_jump["jumps"]]
			+ "%.3f m and no `jumped` for a rule to answer (%d)"
			% [held_jump["rise"], held_jump["jumps"]])
	# A KNOCK -- the brute's slam, the only enemy knock there is.
	from_free = free.global_position
	from_held = held.global_position
	free.receive_knockback(Vector3(7.0, 3.0, 0.0))
	held.receive_knockback(Vector3(7.0, 3.0, 0.0))
	var free_high := 0.0
	var held_high := 0.0
	for _i in 30:
		await get_tree().physics_frame
		free_high = maxf(free_high, free.global_position.y - from_free.y)
		held_high = maxf(held_high, held.global_position.y - from_held.y)
	_check(_flat(free.global_position - from_free) > 0.2
			and _flat(held.global_position - from_held) < 0.02
			and held_high < 0.02,
		"a knock (7, 3, 0): the free player is thrown %.2f m and "
			% _flat(free.global_position - from_free)
			+ "%.2f m up, the anchored one %.3f m and %.3f m up (immune "
			% [free_high, _flat(held.global_position - from_held),
				held_high] + "to all impulse)")
	# ANY OUTSIDE VELOCITY -- a pad, a rule's impulse, an updraft all
	# write it -- is held the same way.
	from_held = held.global_position
	held.velocity = Vector3(6.0, 12.0, 4.0)
	held_high = 0.0
	for _i in 30:
		await get_tree().physics_frame
		held_high = maxf(held_high, held.global_position.y - from_held.y)
	_check(_flat(held.global_position - from_held) < 0.02
			and held_high < 0.02,
		"a velocity written from outside (6, 12, 4) moves it %.3f m and "
			% _flat(held.global_position - from_held)
			+ "%.3f m up" % held_high)
	# GRAVITY STILL ACTS, as it does on an anchored enemy: fixed in place
	# where it stands, not hung in the air.
	var aloft := _player(root, Vector3(0.0, 3.0, 12.0))
	_put(aloft.statuses, "anchored", LONG)
	await _settle(90)
	_check(aloft.is_on_floor() and aloft.global_position.y < 0.2,
		"anchored three metres up, it comes down and stands (y %.2f)"
			% aloft.global_position.y)
	await _drop(root)


## WHAT IT PRESSES INTO. The walk's intent, not only its speed: the step
## the law promises lifts a player by position, and the shove pushes what
## they walk into -- neither goes through the velocity the hold holds.
func _it_climbs_nothing_and_shoves_nothing() -> void:
	print("  -- PRESSING INTO A STEP AND A CRATE (played)")
	var root := _stage()
	var results := {}
	for anchor: bool in [false, true]:
		var x := -12.0 if not anchor else 12.0
		var body := _player(root, Vector3(x, 0.1, 0.0))
		var step := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 0.5, 1.2)
		shape.shape = box
		step.add_child(shape)
		root.add_child(step)
		step.global_position = Vector3(x, 0.25, -1.1)
		var crate := _crate(root, "shoved_%s" % anchor, 20.0,
				Vector3(x + 3.0, 0.5, -1.0))
		await _settle(20)
		if anchor:
			_put(body.statuses, "anchored", LONG)
		await _settle(2)
		var y0 := body.global_position.y
		var went := await _hold(body, "move_forward", 60)
		# AND THE CRATE, stood against: face it and lean in.
		body.global_position = Vector3(x + 3.0, 0.1, 0.2)
		body.rotation.y = 0.0
		await _settle(5)
		var at := crate.global_position
		await _hold(body, "move_forward", 60)
		results[anchor] = {"rise": went["rise"],
				"shoved": _flat(crate.global_position - at),
				"y0": y0}
	var free: Dictionary = results[false]
	var held: Dictionary = results[true]
	# TO THE MILLIMETRE, because that is the scale the defect shows at: a
	# walk intent left on an anchored body lifts it the step's 0.5 m every
	# frame and the floor snap pulls it back before the frame ends, which
	# leaves a few millimetres; a held body leaves none (HS2-1).
	_check(float(free["rise"]) > 0.4 and float(free["shoved"]) > 0.3
			and float(held["rise"]) < 0.002
			and float(held["shoved"]) < 0.02,
		"pressing forward: a free player climbs the 0.5 m step (%.2f m) "
			% float(free["rise"]) + "and shoves the crate %.2f m; anchored, "
			% float(free["shoved"]) + "it climbs %.4f m and shoves %.3f m"
			% [float(held["rise"]), float(held["shoved"])])
	await _drop(root)


## A LAUNCH PAD AND A GRIND RAIL, the two things that carry a player:
## "immune to all impulse, wind, conveyor".
func _it_is_no_passenger() -> void:
	print("  -- A PAD AND A RAIL CARRY IT NOWHERE")
	var root := _stage()
	var pad := AffordanceNodes.LaunchPad.new()
	pad.position = Vector3(-30.0, 0.0, -20.0)
	pad.target = Vector3(10.0, 0.0, 0.0)
	root.add_child(pad)
	var held := _player(root, Vector3(-38.0, 0.1, -20.0))
	var free := _player(root, Vector3(-22.0, 0.1, -20.0))
	await _settle(20)
	_put(held.statuses, "anchored", LONG)
	var at := held.global_position
	var fired_before := pad.launched
	pad.launch(held)
	var fired_held := pad.launched - fired_before
	pad.launch(free)
	var fired_free := pad.launched - fired_before - fired_held
	await _settle(2)
	_check(fired_held == 0 and fired_free == 1
			and held.global_position.distance_to(at) < 0.02,
		"a launch pad fires the free player (%d) and not the anchored one "
			% fired_free + "(%d), which stays %.3f m from where it stood"
			% [fired_held, held.global_position.distance_to(at)])
	# THE RAIL: caught free, let go when anchored, not caught again.
	var rail := RailPath.from_points(PackedVector3Array([
			Vector3(20.0, 1.0, -30.0), Vector3(20.0, 1.0, -5.0)]))
	var rider := _player(root, Vector3(20.0, 2.0, -28.0))
	rider.velocity = Vector3(0.0, 0.0, 9.0)
	rider.offer_rail(rail)
	var caught := rider.riding_rail()
	await _settle(3)
	_put(rider.statuses, "anchored", LONG)
	await _settle(2)
	var let_go := not rider.riding_rail()
	rider.velocity = Vector3(0.0, 0.0, 9.0)
	rider.offer_rail(rail)
	var again := rider.riding_rail()
	_check(caught and let_go and not again,
		"a grind rail catches the free player (%s); anchored, it lets go "
			% caught + "(%s) and does not catch it again (%s)"
			% [let_go, again])
	await _drop(root)


func _an_anchored_player_acts() -> void:
	print("  -- ALL OTHER ACTIONS PERMITTED (played)")
	var root := _stage()
	var body := _player(root, Vector3(0.0, 0.1, 0.0))
	await _settle(20)
	var said: Array[String] = []
	body.carry_feedback.connect(func(text: String, _ok: bool) -> void:
		said.append(text))
	body.runtimes["mobility"].set_equipped({"kind": "action",
			"component_id": "t_dash", "display_name": "Dash",
			"slot": "mobility", "cooldown": 1.0,
			"primitive": {"type": "dash", "force": 12.0}, "modifiers": []})
	body.runtimes["utility"].set_equipped({"kind": "action",
			"component_id": "t_shield", "display_name": "Shield",
			"slot": "utility", "cooldown": 1.0,
			"primitive": {"type": "shield", "amount": 20.0,
				"duration": 2.0}, "modifiers": []})
	await _settle(2)
	# THE CONTROL: free, the dash fires and carries the player.
	var dash: EchoRuntime = body.runtimes["mobility"]
	var from := body.global_position
	Input.action_press("fire_mobility")
	await _settle(4)
	Input.action_release("fire_mobility")
	await _settle(20)
	_check(dash.cooldown_remaining > 0.0
			and _flat(body.global_position - from) > 0.3,
		"free, the dash fires (cooldown %.2f) and carries the player "
			% dash.cooldown_remaining + "%.2f m"
			% _flat(body.global_position - from))
	await _settle(80)
	dash.cooldown_remaining = 0.0
	_put(body.statuses, "anchored", LONG)
	await _settle(2)
	from = body.global_position
	said.clear()
	Input.action_press("fire_mobility")
	await _settle(4)
	Input.action_release("fire_mobility")
	await _settle(20)
	_check(dash.cooldown_remaining == 0.0
			and _flat(body.global_position - from) < 0.02
			and "ANCHORED -- FIXED IN PLACE" in said,
		"anchored, the dash refuses before it is paid for (cooldown "
			+ "%.2f), moves nothing (%.3f m), and says why: %s"
			% [dash.cooldown_remaining,
				_flat(body.global_position - from), said])
	# A DEFENSIVE ACTION is an action, and permitted.
	var shield: EchoRuntime = body.runtimes["utility"]
	Input.action_press("fire_utility")
	await _settle(4)
	Input.action_release("fire_utility")
	await _settle(2)
	_check(shield.cooldown_remaining > 0.0,
		"anchored, the shield fires (cooldown %.2f)"
			% shield.cooldown_remaining)
	# AND THE HANDS: a lever in reach is pulled.
	var lever := AlignmentControl.create("T", "concrete_facility")
	root.add_child(lever)
	var ahead := -body.global_transform.basis.z
	ahead.y = 0.0
	lever.global_position = body.global_position + ahead.normalized() * 1.4 \
			+ Vector3(0.0, AlignmentControl.BASE.y * 0.5, 0.0)
	await _settle(2)
	var d := lever.global_position - body.camera.global_position
	body.rotation.y = atan2(-d.x, -d.z)
	body.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await _settle(3)
	Input.action_press("interact")
	await _settle(2)
	Input.action_release("interact")
	await _settle(2)
	_check(lever.done, "anchored, a lever in reach is pulled")
	await _drop(root)


func _an_anchored_player_weighs_fixed_and_then_does_not() -> void:
	print("  -- ITS CLASS, AND ITS END")
	var root := _stage()
	var plate := ClassPlate.create(Vector3(2.4, 0.12, 2.4), MassClass.HEAVY,
			"concrete_facility", true)
	root.add_child(plate)
	plate.global_position = Vector3(0.0, 0.06, 0.0)
	var body := _player(root, Vector3(0.0, 0.4, 0.0))
	await _settle(40)
	var before := {"class": body.mass_class(), "plate": plate.satisfied()}
	_put(body.statuses, "anchored", 1.0)
	await _settle(2)
	var during := {"class": body.mass_class(), "plate": plate.satisfied()}
	_check(str(before["class"]) == MassClass.MEDIUM
			and not bool(before["plate"])
			and str(during["class"]) == MassClass.FIXED
			and bool(during["plate"]),
		"a HEAVY plate that counts the player: MEDIUM leaves it %s; "
			% ("pressed" if before["plate"] else "unpressed")
			+ "anchored, the player reads %s and it is %s"
			% [during["class"], "pressed" if during["plate"]
				else "unpressed"])
	await _settle(80)
	var after := {"class": body.mass_class(), "plate": plate.satisfied()}
	var from := body.global_position
	Input.action_press("move_forward")
	await _settle(40)
	Input.action_release("move_forward")
	_check(not body.statuses.has("anchored")
			and str(after["class"]) == MassClass.MEDIUM
			and not bool(after["plate"])
			and _flat(body.global_position - from) > 1.0,
		"a second later it has run out: MEDIUM again, the plate released, "
			+ "and the player walks %.2f m" % _flat(body.global_position
				- from))
	await _drop(root)


func _a_lightened_player() -> void:
	print("  -- A LIGHTENED PLAYER")
	var root := _stage()
	var plain := _player(root, Vector3(-20.0, 0.1, 0.0))
	var light := _player(root, Vector3(20.0, 0.1, 0.0))
	await _settle(20)
	_put(light.statuses, "lightened", LONG)
	await _settle(2)
	_check(plain.mass_class() == MassClass.MEDIUM
			and light.mass_class() == MassClass.LIGHT,
		"its class drops a step: %s -> %s"
			% [plain.mass_class(), light.mass_class()])
	var v_plain := plain.velocity.x
	var v_light := light.velocity.x
	plain.receive_knockback(Vector3(4.0, 0.0, 0.0))
	light.receive_knockback(Vector3(4.0, 0.0, 0.0))
	var took_plain := plain.velocity.x - v_plain
	var took_light := light.velocity.x - v_light
	_check(absf(took_plain - 4.0) < 0.01 and absf(took_light - 8.0) < 0.01,
		"the same knock (4 m/s) gives the plain player %.2f m/s and the "
			% took_plain + "lightened one %.2f (incoming impulse x2.0)"
			% took_light)
	await _settle(60)
	# THE CONTROL: walking and jumping are not its to change.
	var walk_plain := plain.global_position
	var walk_light := light.global_position
	Input.action_press("move_forward")
	await _settle(40)
	Input.action_release("move_forward")
	await _settle(10)
	var a := _flat(plain.global_position - walk_plain)
	var b := _flat(light.global_position - walk_light)
	var jump_light := await _jump(light)
	_check(absf(a - b) < 0.05 * a and absf(jump_light["rise"] - 1.40) < 0.03,
		"it walks as far (%.2f m against %.2f) and jumps as high "
			% [b, a] + "(%.2f m)" % jump_light["rise"])
	# THE PAIR NEVER COEXISTS.
	_put(light.statuses, "anchored", LONG)
	var then_anchored := [light.statuses.has("anchored"),
			light.statuses.has("lightened"), light.mass_class()]
	_put(light.statuses, "lightened", LONG)
	var then_lightened := [light.statuses.has("anchored"),
			light.statuses.has("lightened"), light.mass_class()]
	_check(then_anchored == [true, false, MassClass.FIXED]
			and then_lightened == [false, true, MassClass.LIGHT],
		"anchoring it removes the lightness %s, and lightening it the "
			% [then_anchored] + "anchor %s" % [then_lightened])
	await _drop(root)


# ------------------------------------------------------------- the enemy

func _a_lightened_enemy() -> void:
	print("  -- A LIGHTENED ENEMY")
	var root := _stage()
	var plain := Enemy.create("melee", "concrete_facility")
	root.add_child(plain)
	plain.global_position = Vector3(-20.0, 0.1, 20.0)
	var light := Enemy.create("melee", "concrete_facility")
	root.add_child(light)
	light.global_position = Vector3(20.0, 0.1, 20.0)
	await _settle(30)
	# STILL, so the knock is all that moves them: `rooted` forbids their
	# own steps and still takes a knock (O05-09.1), and it is declared.
	plain.statuses.apply("rooted", LONG, 1.0)
	light.statuses.apply("rooted", LONG, 1.0)
	_put(light.statuses, "lightened", LONG)
	await _settle(20)
	var from_plain := plain.global_position
	var from_light := light.global_position
	plain.apply_knockback(Vector3(8.0, 0.0, 0.0))
	light.apply_knockback(Vector3(8.0, 0.0, 0.0))
	# THE FUNNEL, read before the next frame spends it.
	var took_plain: Vector3 = plain._knockback
	var took_light: Vector3 = light._knockback
	await _settle(40)
	var a := _flat(plain.global_position - from_plain)
	var b := _flat(light.global_position - from_light)
	_check(is_equal_approx(took_plain.x, 8.0)
			and is_equal_approx(took_light.x, 16.0)
			and a > 0.1 and b > 1.6 * a,
		"the same 8 m/s knock: the plain enemy takes %.1f m/s and goes "
			% took_plain.x + "%.2f m, the lightened one %.1f m/s and "
			% [a, took_light.x] + "%.2f m (incoming impulse x2.0)" % b)
	var eye := light.global_position + Vector3(0.0, 1.6, 6.0)
	var numbers: Dictionary = Manipulation.PHYSICS_PROFILES[
			"ab_physics_light"]
	var space := get_viewport().world_3d.direct_space_state
	_check(Manipulation.target_refusal("PUSH", light, eye, numbers, space)
			== Manipulation.ACTOR_MASS_UNMODELLED,
		"to the verbs it is still an actor whose mass is not modelled: "
			+ "no class to drop a step")
	# THE PAIR NEVER COEXISTS, on an enemy either.
	_put(light.statuses, "anchored", LONG)
	from_light = light.global_position
	light.apply_knockback(Vector3(8.0, 0.0, 0.0))
	await _settle(30)
	var anchored_moved := _flat(light.global_position - from_light)
	_put(light.statuses, "lightened", LONG)
	from_light = light.global_position
	light.apply_knockback(Vector3(8.0, 0.0, 0.0))
	await _settle(40)
	var lightened_moved := _flat(light.global_position - from_light)
	_check(anchored_moved < 0.01 and lightened_moved > 0.8 * b,
		"anchored over it, the knock moves it %.3f m; lightened over "
			% anchored_moved + "that, %.2f m again" % lightened_moved)
	await _drop(root)


# ------------------------------------------------------------- the object

func _an_anchored_object() -> void:
	print("  -- AN ANCHORED OBJECT")
	var root := _stage()
	var plain := _crate(root, "plain", 60.0, Vector3(-6.0, 0.5, 0.0))
	var fixed := _crate(root, "fixed", 60.0, Vector3(6.0, 0.5, 0.0))
	await _settle(40)
	_put_object(fixed, "anchored", LONG)
	await _settle(2)
	_check(fixed.mass_class() == MassClass.FIXED
			and plain.mass_class() == MassClass.MEDIUM,
		"it reads FIXED (%s; the same crate plain is %s)"
			% [fixed.mass_class(), plain.mass_class()])
	# IMPULSE, then a steady force.
	var at_plain := plain.global_position
	var at_fixed := fixed.global_position
	plain.receive_impulse(Vector3(0.0, 0.0, 60.0 * 5.0))
	fixed.receive_impulse(Vector3(0.0, 0.0, 60.0 * 5.0))
	await _settle(30)
	for _i in 30:
		fixed.receive_force(Vector3(0.0, 0.0, 3000.0))
		await get_tree().physics_frame
	_check(_flat(plain.global_position - at_plain) > 0.5
			and fixed.global_position.distance_to(at_fixed) < 0.01,
		"a 5 m/s impulse moves the plain crate %.2f m; the anchored one, "
			% _flat(plain.global_position - at_plain)
			+ "with a 3 kN push on top, %.3f m"
			% fixed.global_position.distance_to(at_fixed))
	# PHYSICS: the verbs, the push, the hands.
	var body := _player(root, Vector3(6.0, 0.1, 4.0))
	await _settle(20)
	var eye := body.camera.global_position
	var numbers: Dictionary = Manipulation.PHYSICS_PROFILES[
			"ab_physics_light"]
	var space := get_viewport().world_3d.direct_space_state
	var refused := Manipulation.target_refusal("PUSH", fixed, eye, numbers,
			space)
	var pushed := Manipulation.push(fixed, eye,
			fixed.global_position + Vector3(0.0, 0.0, -3.0),
			Manipulation.Envelope.at_the_envelope())
	var hands := HandCarry.refusal(fixed)
	_check(refused == Manipulation.FIXED
			and str(pushed.get("refused", "")) == Manipulation.FIXED
			and hands == "FIXED IN PLACE",
		"the verbs refuse it (%s), so does a push (%s), and the hands say "
			% [refused, pushed.get("refused", "")] + "'%s'" % hands)
	# WALKED INTO, it does not give.
	var ahead := fixed.global_position - body.global_position
	body.rotation.y = atan2(-ahead.x, -ahead.z)
	at_fixed = fixed.global_position
	var walk := await _hold(body, "move_forward", 90)
	_check(fixed.global_position.distance_to(at_fixed) < 0.01,
		"walked into for a second and a half, it gives %.3f m"
			% fixed.global_position.distance_to(at_fixed))
	# FIXED IN PLACE, in the air too; and when it ends, it falls.
	var aloft := _crate(root, "aloft", 60.0, Vector3(0.0, 3.0, -8.0))
	await _settle(1)
	_put_object(aloft, "anchored", 1.0)
	await _settle(40)
	var held_y := aloft.global_position.y
	await _settle(90)
	_check(held_y > 2.95 and aloft.global_position.y < 0.7
			and not aloft.freeze,
		"anchored three metres up, it hangs there (y %.2f); when the "
			% held_y + "Status ends it is thawed and falls (y %.2f)"
			% aloft.global_position.y)
	_note("walking into the anchored crate the player went %.2f m"
			% walk["travel"])
	# AN IMPULSE LANDED WHILE ANCHORED IS NOT KEPT FOR LATER: when the
	# anchor ends, the crate does not set off with it.
	var kept := _crate(root, "kept", 60.0, Vector3(-12.0, 0.5, 10.0))
	await _settle(30)
	_put_object(kept, "anchored", 0.6)
	await _settle(2)
	var rest := kept.global_position
	kept.receive_impulse(Vector3(0.0, 0.0, 60.0 * 5.0))
	await _settle(90)
	_check(not kept.freeze and _flat(kept.global_position - rest) < 0.02,
		"an impulse landed while anchored is not released when the anchor "
			+ "ends: thawed, the crate has moved %.3f m"
			% _flat(kept.global_position - rest))
	await _drop(root)


func _the_anchor_and_the_other_holds() -> void:
	print("  -- THE ANCHOR AMONG THE OTHER HOLDS")
	var root := _stage()
	# A BOLTED crate is frozen already; the anchor must not thaw it.
	var bolted := _crate(root, "bolted", 60.0, Vector3(-8.0, 0.5, 0.0), true)
	await _settle(10)
	_put_object(bolted, "anchored", 0.5)
	await _settle(60)
	_check(not bolted.statuses.has("anchored") and bolted.freeze,
		"a bolted crate anchored and released is still frozen (the anchor "
			+ "thaws only what it froze)")
	# THE PAIR ON AN OBJECT. `lightened` on an object is declared already.
	var crate := _crate(root, "pair", 60.0, Vector3(0.0, 0.5, 0.0))
	var plain := _crate(root, "plain", 60.0, Vector3(8.0, 0.5, 0.0))
	await _settle(30)
	_put_object(crate, "lightened", LONG)
	_put_object(crate, "anchored", LONG)
	await _settle(2)
	var anchored_over := [crate.statuses.has("lightened"),
			crate.impulse_scale(), crate.mass_class(), crate.freeze]
	_put_object(crate, "lightened", LONG)
	await _settle(2)
	var lightened_over := [crate.statuses.has("anchored"), crate.freeze,
			crate.mass_class()]
	var at_crate := crate.global_position
	var at_plain := plain.global_position
	crate.receive_impulse(Vector3(0.0, 0.0, 60.0 * 3.0))
	plain.receive_impulse(Vector3(0.0, 0.0, 60.0 * 3.0))
	await _settle(40)
	var a := _flat(plain.global_position - at_plain)
	var b := _flat(crate.global_position - at_crate)
	_check(anchored_over == [false, 1.0, MassClass.FIXED, true]
			and lightened_over == [false, false, MassClass.LIGHT]
			and b > 1.5 * a and a > 0.1,
		"anchored over lightened it is FIXED and frozen %s; lightened over "
			% [anchored_over] + "that it is thawed and LIGHT %s, and the "
			% [lightened_over] + "same impulse moves it %.2f m to a plain "
			% b + "crate's %.2f" % a)
	# A CLASS PLATE reads what the crate is now.
	var plate := ClassPlate.create(Vector3(2.4, 0.12, 2.4), MassClass.HEAVY)
	root.add_child(plate)
	plate.global_position = Vector3(0.0, 0.06, 12.0)
	var weight := _crate(root, "weight", 60.0, Vector3(0.0, 0.8, 12.0))
	await _settle(60)
	var bare := plate.satisfied()
	_put_object(weight, "anchored", 1.0)
	await _settle(2)
	var fixed_on := plate.satisfied()
	await _settle(90)
	_check(not bare and fixed_on and not plate.satisfied(),
		"a HEAVY plate: the MEDIUM crate leaves it %s, anchored it is %s, "
			% ["pressed" if bare else "unpressed",
				"pressed" if fixed_on else "unpressed"]
			+ "and when the anchor ends %s -- the plate reads the crate's "
			% ("pressed" if plate.satisfied() else "unpressed")
			+ "class as it is, not as it was")
	# IN THE HANDS: anchored there, it is let go and stays where it was.
	var body := _player(root, Vector3(-3.0, 0.1, -10.0))
	var light := _crate(root, "carried", 20.0, Vector3(-3.0, 0.5, -11.5))
	light.carriable = true
	await _settle(30)
	var picked: bool = body.carry.try_pick_up(light)
	await _settle(10)
	var said: Array[String] = []
	body.carry_feedback.connect(func(text: String, _ok: bool) -> void:
		said.append(text))
	_put_object(light, "anchored", LONG)
	await _settle(3)
	var where := light.global_position
	await _settle(40)
	_check(picked and not body.carry.holding()
			and light.global_position.distance_to(where) < 0.02
			and said.any(func(t: String) -> bool:
				return t.contains("FIXED IN PLACE")),
		"a carried crate anchored is let go (%s) and stays where it was "
			% [said] + "(%.3f m)" % light.global_position.distance_to(where))
	await _drop(root)
