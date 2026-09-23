extends Node
## O05-08.1-.4: ALL TWELVE VERBS' RUNTIME, AND NOTHING ELSE -- PUSH, PULL,
## HOLD, ALIGN, SETTLE, PIN, TETHER, ROTATE, ATTACH, DETACH, LIGHTEN_FIELD
## AND ANCHOR_FIELD -- and the relations ledger.
##
## `Manipulation.impulse_verb`, `VerbHold`, `VerbAlign`,
## `Manipulation.settle`, `VerbPin`, `VerbTether`, `VerbRotate` and
## `VerbRelations` against Design 2 §14.2 (eligibility), §14.3 (each
## verb's contract), §14.4 (the ceilings) and §31.2 (exclusivity), with
## the numbered acceptance items of Design 2's own list where they apply
## (5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 28), on real bodies in
## a real physics world. The caster is a real `Player` wherever the verb
## watches one, so its eye, its body and its death are the real ones.
##
## **EVIDENCE CLASS: DIRECT INVOCATION, RUNTIME ONLY.** No Echo Action
## reaches this verb -- the accepted delivery is the Amalgam's atom
## grammar, which the running Echo model does not implement (see
## `PROD_OV05.md`, O05-08) -- so every case calls the verb by hand from
## an eye point. That proves the verb, and nothing about delivering it or
## about a mandatory route qualifying on it. Those are separate claims.

const DT := 1.0 / 60.0

var _failures := 0
var _checks := 0
var _notes := 0
## Why each watched hold ended, in order.
var _released_why: Array[String] = []
var _eye: Vector3 = Vector3(0.0, 1.6, 0.0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: " + message)
	else:
		_failures += 1
		print("FAIL: " + message)


func _note(message: String) -> void:
	_notes += 1
	print("  NOTE: " + message)


func _ready() -> void:
	_run.call_deferred()


func _finish() -> void:
	if _failures == 0:
		print("GODOT VERB RUNTIME OK (%d checks, %d notes)"
				% [_checks, _notes])
		get_tree().quit(0)
	else:
		print("GODOT VERB RUNTIME: %d failures in %d checks"
				% [_failures, _checks])
		get_tree().quit(1)


func _run() -> void:
	await get_tree().physics_frame
	await _push_is_one_impulse_by_the_formula()
	await _pull_comes_back_along_the_ray()
	await _the_ceilings_hold()
	await _the_acceptance_numbers()
	await _lightened_doubles_and_opens_the_door()
	await _each_refusal_is_its_own_answer()
	await _hold_moves_and_maintains()
	await _hold_meets_the_world_and_passes_actors()
	await _hold_lets_go_when_it_should()
	await _align_turns_then_holds()
	await _settle_calms_what_it_may()
	await _a_settled_body_in_mid_air()
	await _no_verb_moves_the_player()
	await _pin_holds_what_it_pins()
	await _tether_ties_two_ends()
	await _rotate_turns_a_hinge_and_spins_a_body()
	await _relations_are_counted_and_exclusive()
	await _attach_welds_and_detach_gives_back()
	await _fields_scale_kilograms()
	_finish()


# ------------------------------------------------------------- building

## A body floating at `at`: no floor under it, so what it does in the
## first frames is the impulse and gravity, not friction.
func _crate(kg: float, at: Vector3, size := Vector3(0.8, 0.8, 0.8)
		) -> ManipulableBody:
	var body := ManipulableBody.create("crate_%d" % get_child_count(), kg,
			size)
	add_child(body)
	body.global_position = at
	return body


## A floor, and a real Player standing on it: the Player's own camera is
## the eye, and its body is the caster HOLD watches.
func _stage(at: Vector3) -> Dictionary:
	var world := Node3D.new()
	world.name = "Stage_%d" % get_child_count()
	add_child(world)
	world.global_position = at
	var ground := StaticBody3D.new()
	ground.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.position = Vector3(0.0, -0.5, 0.0)
	var player := Player.create()
	world.add_child(player)
	player.global_position = at
	return {"world": world, "player": player}


## A wall to stand between an eye and a body.
func _wall(parent: Node, at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	wall.global_position = at
	return wall


## An enemy that stands where it is put: its mind switched off, its body
## left in the physics world.
func _statue(parent: Node, at: Vector3) -> Enemy:
	var enemy := Enemy.create("melee", "concrete_facility")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	parent.add_child(enemy)
	enemy.global_position = at
	return enemy


## Start a HOLD by the stage's player and record why it ends.
func _held(player: Player, body: ManipulableBody,
		profile := "ab_physics_light") -> VerbHold:
	var out := VerbHold.begin(player.camera, body, profile, player)
	var hold: VerbHold = out.get("hold")
	if hold != null:
		hold.released.connect(func(why: String) -> void:
			_released_why.append(why))
	return hold


## Watch a held body for `ticks`: when it first came within 0.1 m of the
## hold point, its highest speed, and its longest single-tick step.
func _follow(body: ManipulableBody, hold: VerbHold, ticks: int
		) -> Dictionary:
	var arrived := -1
	var fastest := 0.0
	var step := 0.0
	var previous := body.global_position
	for tick in ticks:
		await get_tree().physics_frame
		fastest = maxf(fastest, body.linear_velocity.length())
		step = maxf(step, body.global_position.distance_to(previous))
		previous = body.global_position
		if arrived < 0 and is_instance_valid(hold) and hold.holding() \
				and body.global_position.distance_to(hold.hold_point()) \
				<= 0.1:
			arrived = tick + 1
	return {"arrived": arrived, "fastest": fastest, "step": step}


## Does `body`'s hull overlap `other` right now? Asked of the space, which
## sees through collision exceptions.
func _overlapping(body: ManipulableBody, other: CollisionObject3D) -> bool:
	var hull := body.get_node("hull") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull.shape
	query.transform = hull.global_transform
	for hit: Dictionary in _space().intersect_shape(query, 32):
		if hit.get("rid") == other.get_rid():
			return true
	return false


## Still holding? A finished hold frees itself once nothing overlaps.
func _holding(hold: Variant) -> bool:
	return is_instance_valid(hold) and (hold as VerbHold).holding()


## Is `node` in `list`? By identity, so a typed list may be asked about a
## node of any type.
func _contains(list: Array, node: Object) -> bool:
	for item: Variant in list:
		if is_same(item, node):
			return true
	return false


## Still in force? A finished relation frees itself.
func _live(relation: Variant) -> bool:
	return is_instance_valid(relation) and bool(
			(relation as Object).call("active"))


## A flat beam to strike, its underside at `underside`.
func _beam(parent: Node, underside: Vector3) -> StaticBody3D:
	var beam := StaticBody3D.new()
	beam.name = "Beam"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.4, 6.0)
	shape.shape = box
	beam.add_child(shape)
	parent.add_child(beam)
	beam.global_position = underside + Vector3(0.0, 0.2, 0.0)
	return beam


func _flat(velocity: Vector3) -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()


func _space() -> PhysicsDirectSpaceState3D:
	return get_viewport().world_3d.direct_space_state


func _aim_at(point: Vector3) -> Vector3:
	return (point - _eye).normalized()


## The velocity a verb reported, or zero when it refused: a refusal where
## an impulse was expected has to fail its check by name, not end the
## case in a script error before the check is counted.
func _v(out: Dictionary) -> Vector3:
	return out.get("velocity", Vector3.ZERO)


func _settle(frames := 2) -> void:
	for _i in frames:
		await get_tree().physics_frame


# ---------------------------------------------------------------- cases

## §14.3: `impulse_velocity = clamp(force / mass_kg, 0.0, 30.0)`, applied
## once, on commit -- not continuously.
func _push_is_one_impulse_by_the_formula() -> void:
	print("  -- PUSH: one impulse, force over mass, along the aim")
	var body := _crate(40.0, Vector3(0.0, 1.6, -6.0))
	await _settle()
	var aim := _aim_at(body.global_position)
	var out := Manipulation.impulse_verb("PUSH", body, _eye, aim,
			"ab_physics_light", _space())
	var want := 700.0 / 40.0
	_check(bool(out["applied"]) and absf(_v(out)
			.length() - want) < 0.001,
			"700 N on 40 kg is %.2f m/s (the verb says %.2f)"
			% [want, _v(out).length()])
	await _settle(1)
	var flat := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	_check(flat.length() > want * 0.9 and flat.normalized().dot(
			Vector3(aim.x, 0.0, aim.z).normalized()) > 0.99,
			"and the body moves away from the eye at %.2f m/s"
			% flat.length())
	var early := flat.length()
	await _settle(30)
	flat = Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	_check(flat.length() < early,
			"once, not held: half a second on it has slowed to %.2f m/s"
			% flat.length())
	body.queue_free()


func _pull_comes_back_along_the_ray() -> void:
	print("  -- PULL: toward the eye along the same ray")
	var body := _crate(50.0, Vector3(3.0, 1.6, -8.0))
	await _settle()
	var aim := _aim_at(body.global_position)
	var out := Manipulation.impulse_verb("PULL", body, _eye, aim,
			"ab_physics_standard", _space())
	await _settle(1)
	var flat := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	_check(bool(out["applied"]) and flat.normalized().dot(
			-Vector3(aim.x, 0.0, aim.z).normalized()) > 0.99
			and absf(_v(out).length() - 28.0) < 0.001,
			"1400 N on 50 kg is 28 m/s, back along the aim (%.2f m/s)"
			% flat.length())
	body.queue_free()


## §14.4: 30 m/s overall; 14 m/s vertically from any player-caused
## impulse, which is what keeps a launched object from being a staircase.
func _the_ceilings_hold() -> void:
	print("  -- the ceilings: 30 m/s, and 14 m/s up")
	var light := _crate(10.0, Vector3(0.0, 1.6, -5.0))
	await _settle()
	var out := Manipulation.impulse_verb("PUSH", light, _eye,
			_aim_at(light.global_position), "ab_physics_strong", _space())
	_check(bool(out["applied"]) and absf(_v(out)
			.length() - 30.0) < 0.001,
			"2600 N on 10 kg would be 260 m/s; it is %.1f"
			% _v(out).length())
	light.queue_free()
	var high := _crate(10.0, Vector3(0.0, 6.6, -3.0))
	await _settle()
	var up := _aim_at(high.global_position)
	out = Manipulation.impulse_verb("PUSH", high, _eye, up,
			"ab_physics_strong", _space())
	var v := _v(out)
	_check(bool(out["applied"]) and is_equal_approx(v.y, 14.0)
			and up.y * 30.0 > 14.0,
			"aimed steeply up (%.0f m/s of it upward), it leaves at %.1f "
			% [up.y * 30.0, v.y] + "m/s vertically")
	await _settle(1)
	_check(high.linear_velocity.y <= 14.0 + 0.01,
			"and the body's own vertical speed is %.2f m/s"
			% high.linear_velocity.y)
	high.queue_free()


## Design 5 §15.2 through the verb: `lightened` doubles an incoming
## impulse, and makes a HEAVY body eligible where its kilograms are not.
func _lightened_doubles_and_opens_the_door() -> void:
	print("  -- lightened: twice the impulse, and HEAVY let in")
	var body := _crate(100.0, Vector3(0.0, 1.6, -6.0))
	await _settle()
	var plain := Manipulation.impulse_verb("PUSH", body, _eye,
			_aim_at(body.global_position), "ab_physics_light", _space())
	body.linear_velocity = Vector3.ZERO
	body.apply_status("lightened", 8.0, 1.0)
	await _settle()
	var doubled := Manipulation.impulse_verb("PUSH", body, _eye,
			_aim_at(body.global_position), "ab_physics_light", _space())
	_check(bool(doubled["applied"]) and is_equal_approx(
			_v(doubled).length(),
			2.0 * _v(plain).length()),
			"100 kg: %.1f m/s plain, %.1f lightened"
			% [_v(plain).length(),
				_v(doubled).length()])
	body.queue_free()
	var heavy := _crate(150.0, Vector3(0.0, 1.6, -6.0))
	await _settle()
	var refused := Manipulation.impulse_verb("PUSH", heavy, _eye,
			_aim_at(heavy.global_position), "ab_physics_light", _space())
	heavy.apply_status("lightened", 8.0, 1.0)
	await _settle()
	var admitted := Manipulation.impulse_verb("PUSH", heavy, _eye,
			_aim_at(heavy.global_position), "ab_physics_light", _space())
	_check(refused["refused"] == Manipulation.TOO_HEAVY
			and bool(admitted["applied"]),
			"150 kg against a 120 kg limit: refused (%s), then admitted "
			% refused["refused"] + "lightened at %.2f m/s"
			% _v(admitted).length())
	heavy.queue_free()


## §14.2's refusals. Each is a different thing to tell the player, and
## none of them moves anything.
func _each_refusal_is_its_own_answer() -> void:
	print("  -- §14.2: every refusal named, nothing moved")
	var space := _space()
	# Off to the side, so it stands in no other case's line of sight.
	var ok := _crate(40.0, Vector3(4.0, 1.6, -6.0))
	await _settle()
	var aim := _aim_at(ok.global_position)
	await _refused_and_still(Manipulation.impulse_verb("HOLD", ok, _eye, aim,
			"ab_physics_light", space), Manipulation.NOT_AN_IMPULSE_VERB,
			"HOLD is not an impulse verb", ok)
	await _refused_and_still(Manipulation.impulse_verb("PUSH", ok, _eye, aim,
			"ab_physics_mega", space), Manipulation.UNKNOWN_PROFILE,
			"a profile §14.3 does not name", ok)
	_expect(Manipulation.impulse_verb("PUSH", null, _eye, aim,
			"ab_physics_light", space), Manipulation.NO_TARGET,
			"aimed at nothing (§12.3: it spends nothing)")

	var far := _crate(40.0, Vector3(0.0, 1.6, -21.0))
	await _settle()
	await _refused_and_still(Manipulation.impulse_verb("PUSH", far, _eye,
			_aim_at(far.global_position), "ab_physics_light", space),
			Manipulation.OUT_OF_REACH, "21 m against the light profile's 20",
			far)
	_check(bool(Manipulation.impulse_verb("PUSH", far, _eye,
			_aim_at(far.global_position), "ab_physics_strong",
			space)["applied"]), "and the strong profile's 28 m reaches it")
	far.queue_free()

	var heavy := _crate(130.0, Vector3(0.0, 1.6, -6.0))
	await _settle()
	await _refused_and_still(Manipulation.impulse_verb("PUSH", heavy, _eye,
			_aim_at(heavy.global_position), "ab_physics_light", space),
			Manipulation.TOO_HEAVY, "130 kg against a 120 kg limit", heavy)
	heavy.queue_free()

	var bolted := _crate(20.0, Vector3(2.0, 1.6, -6.0))
	bolted.constrained = true
	var ballast := _crate(450.0, Vector3(-2.0, 1.6, -6.0))
	await _settle()
	await _refused_and_still(Manipulation.impulse_verb("PUSH", bolted, _eye,
			_aim_at(bolted.global_position), "ab_physics_strong", space),
			Manipulation.FIXED, "a bolted 20 kg bracket is FIXED", bolted)
	await _refused_and_still(Manipulation.impulse_verb("PUSH", ballast, _eye,
			_aim_at(ballast.global_position), "ab_physics_strong", space),
			Manipulation.FIXED, "450 kg is FIXED, whatever the profile",
			ballast)
	bolted.queue_free()
	ballast.queue_free()

	var required := _crate(40.0, Vector3(-3.0, 1.6, -6.0))
	required.add_to_group(Constants.REQUIRED_OBJECT_GROUP)
	await _settle()
	_check(bool(Manipulation.impulse_verb("PUSH", required, _eye,
			_aim_at(required.global_position), "ab_physics_light",
			space)["applied"]),
			"a required object responds by default (Design 2 §4.8)")
	required.physics_permitted = false
	required.linear_velocity = Vector3.ZERO
	await _refused_and_still(Manipulation.impulse_verb("PUSH", required, _eye,
			_aim_at(required.global_position), "ab_physics_light", space),
			Manipulation.NOT_PERMITTED,
			"and not once `physics_permitted` is false", required)
	required.queue_free()

	var hidden := _crate(40.0, Vector3(0.0, 1.6, -10.0))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.4)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = Vector3(0.0, 1.6, -5.0)
	await _settle()
	await _refused_and_still(Manipulation.impulse_verb("PUSH", hidden, _eye,
			_aim_at(hidden.global_position), "ab_physics_light", space),
			Manipulation.NO_LINE_OF_SIGHT, "a wall between eye and body",
			hidden)
	wall.queue_free()
	hidden.queue_free()

	var player := StaticBody3D.new()
	player.add_to_group("player")
	add_child(player)
	_expect(Manipulation.impulse_verb("PUSH", player, _eye, aim,
			"ab_physics_light", space), Manipulation.NEVER_THE_PLAYER,
			"the player is never a target")
	# Gone now, not at the end of the frame: the Enemy below looks for a
	# `Player` in this group on its first physics tick.
	player.free()
	var enemy := Enemy.create("melee", "concrete_facility")
	add_child(enemy)
	enemy.global_position = Vector3(0.0, 0.0, -6.0)
	_expect(Manipulation.impulse_verb("PUSH", enemy, _eye, aim,
			"ab_physics_light", space), Manipulation.ACTOR_MASS_UNMODELLED,
			"an enemy: §14.3 divides by a mass no enemy has here")
	enemy.queue_free()
	var scenery := StaticBody3D.new()
	add_child(scenery)
	_expect(Manipulation.impulse_verb("PUSH", scenery, _eye, aim,
			"ab_physics_light", space), Manipulation.NOT_MANIPULABLE,
			"scenery is not manipulable")
	scenery.queue_free()
	ok.queue_free()


## A refusal is named, and it moves nothing: a frame later the body it
## was aimed at has no sideways speed. The aims here are all near level,
## so an impulse that got through would show sideways; gravity, the one
## other thing acting on a floating body, is vertical.
func _refused_and_still(out: Dictionary, reason: String, what: String,
		body: RigidBody3D) -> void:
	await _settle(1)
	var flat := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	_check(not bool(out["applied"]) and out["refused"] == reason
			and flat.length() < 0.001,
			"%s: refused as %s, and it has not moved (%.3f m/s sideways)"
			% [what, out["refused"], flat.length()])


func _expect(out: Dictionary, reason: String, what: String) -> void:
	_check(not bool(out["applied"]) and out["refused"] == reason,
			"%s: refused as %s" % [what, out["refused"]])


## Design 2's own acceptance list, for the impulse verbs: items 5, 28, 7.
func _the_acceptance_numbers() -> void:
	print("  -- Design 2's acceptance items 5, 28 and 7")
	var space := _space()
	var body := _crate(120.0, Vector3(0.0, 1.6, -6.0))
	await _settle()
	var aim := _aim_at(body.global_position)
	var out := Manipulation.impulse_verb("PUSH", body, _eye, aim,
			"ab_physics_light", space)
	_check(bool(out["applied"]) and absf(_v(out).length() - 5.83) <= 0.01,
			"item 5: PUSH at 700 N on a 120 kg object is 5.83 m/s +/- 0.01 "
			+ "(%.4f)" % _v(out).length())
	body.mass = 120.1
	out = Manipulation.impulse_verb("PUSH", body, _eye, aim,
			"ab_physics_light", space)
	_check(out["refused"] == Manipulation.TOO_HEAVY,
			"item 28: `ab_physics_light` moves 120.0 kg and refuses 120.1 kg "
			+ "(%s)" % out["refused"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5083
	var profiles: Array = Manipulation.PHYSICS_PROFILES.keys()
	var applied := 0
	var highest := -INF
	var fastest := 0.0
	for i in 10000:
		if i == 5000:
			body.apply_status("lightened", 60.0, 1.0)
		body.mass = rng.randf_range(1.0, 399.0)
		var toward := Vector3(rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if toward.length() < 0.01:
			continue
		var tried := Manipulation.impulse_verb(
				"PUSH" if rng.randf() < 0.5 else "PULL", body, _eye,
				toward.normalized(), str(profiles[rng.randi() % 3]), space)
		if not bool(tried["applied"]):
			continue
		applied += 1
		highest = maxf(highest, _v(tried).y)
		fastest = maxf(fastest, _v(tried).length())
	_check(applied > 5000 and highest <= 14.0 + 0.0001
			and fastest <= 30.0 + 0.0001,
			"item 7: over 10,000 random verbs, angles and masses (%d applied, "
			% applied + "the second half lightened), nothing leaves faster "
			+ "than %.4f m/s upward or %.4f m/s overall" % [highest, fastest])
	body.queue_free()


## §14.3: "Moves the target to `hold_distance` ahead of the eye at up to
## `8.0 m/s`, then maintains it there." Items 8 and 9.
func _hold_moves_and_maintains() -> void:
	print("  -- HOLD: to 3.5 m at up to 8 m/s, then kept there")
	var stage := _stage(Vector3(600.0, 0.0, 0.0))
	var player: Player = stage["player"]
	await _settle(20)
	var crate := _crate(40.0, player.global_position
			+ Vector3(0.0, 0.4, -7.0))
	await _settle(30)
	var hold := _held(player, crate)
	_check(hold != null and hold.holding()
			and is_equal_approx(hold.hold_distance, 3.5),
			"a 40 kg crate 7 m out is held, at the default 3.5 m")
	if hold == null:
		(stage["world"] as Node).queue_free()
		return
	var track := await _follow(crate, hold, 90)
	_check(int(track["arrived"]) >= 20 and int(track["arrived"]) <= 60
			and float(track["fastest"]) <= VerbHold.SPEED_MAX + 0.001
			and float(track["step"]) <= VerbHold.SPEED_MAX * DT + 0.001,
			"it travels there and is not placed: at the hold point after %d "
			% track["arrived"] + "ticks, never over %.3f m/s or %.3f m in "
			% [track["fastest"], track["step"]] + "one tick")
	var worst := 0.0
	for _i in 120:
		await get_tree().physics_frame
		worst = maxf(worst, crate.global_position.distance_to(
				hold.hold_point()))
	_check(hold.holding() and worst <= 0.1
			and is_zero_approx(crate.gravity_scale),
			"item 8: held at `hold_distance` +/- 0.1 m for 2 s (worst %.3f m), "
			% worst + "gravity suspended")
	var high := hold.set_hold_distance(10.0)
	var low := hold.set_hold_distance(0.5)
	_check(is_equal_approx(high, 6.0) and is_equal_approx(low, 1.5),
			"item 9: the distance adjusts only within 1.5-6.0 m (asked 10 "
			+ "and 0.5, given %.1f and %.1f)" % [high, low])
	hold.set_hold_distance(5.5)
	track = await _follow(crate, hold, 90)
	var out_to := player.camera.global_position.distance_to(
			crate.global_position)
	_check(int(track["arrived"]) > 0
			and float(track["step"]) <= VerbHold.SPEED_MAX * DT + 0.001
			and absf(out_to - 5.5) <= 0.1,
			"set to 5.5 m, the body travels out and is held there (%.2f m)"
			% out_to)
	player.global_position += Vector3(4.0, 0.0, 0.0)
	track = await _follow(crate, hold, 90)
	_check(int(track["arrived"]) > 0
			and float(track["step"]) <= VerbHold.SPEED_MAX * DT + 0.001,
			"the caster steps 4 m aside: the body follows, never more than "
			+ "%.3f m in a tick, and is held again after %d ticks"
			% [track["step"], track["arrived"]])
	_released_why.clear()
	hold.release(VerbHold.INPUT)
	await _settle(60)
	_check(_released_why == [VerbHold.INPUT]
			and is_equal_approx(crate.gravity_scale, 1.0)
			and crate.global_position.y - player.global_position.y < 0.5,
			"released by input: gravity is its own again and it falls to the "
			+ "floor (%.2f m up)"
			% (crate.global_position.y - player.global_position.y))
	(stage["world"] as Node).queue_free()
	crate.queue_free()
	await _settle(4)


## "The held object collides with world geometry and stops against it; it
## passes through actors."
func _hold_meets_the_world_and_passes_actors() -> void:
	print("  -- HOLD: stopped by the floor, never by an actor")
	var stage := _stage(Vector3(700.0, 0.0, 0.0))
	var world: Node3D = stage["world"]
	var player: Player = stage["player"]
	await _settle(20)
	var crate := _crate(40.0, player.global_position
			+ Vector3(0.0, 0.4, -4.0))
	await _settle(30)
	var hold := _held(player, crate)
	await _settle(60)
	player.camera.rotation.x = -deg_to_rad(60.0)
	var lowest := INF
	for _i in 90:
		await get_tree().physics_frame
		lowest = minf(lowest,
				crate.global_position.y - player.global_position.y)
	var under := hold.hold_point().y - player.global_position.y
	var resting := crate.global_position.y - player.global_position.y
	# Stopped against it, by the solver: at the moment of impact a body
	# driven at 8 m/s can be one tick's travel into the surface before
	# the contact resolves, as any body arriving at that speed can. It is
	# never further in, and it comes to rest on the surface.
	_check(_holding(hold) and under < -1.0
			and lowest >= 0.4 - VerbHold.SPEED_MAX * DT
			and absf(resting - 0.4) <= 0.03,
			"looking steeply down, the hold point is %.2f m under the floor; "
			% under + "the crate stops against the floor and rests on it "
			+ "(centre %.3f m; 0.4 is resting; lowest at impact %.3f m, "
			% [resting, lowest] + "one tick's travel is %.3f m)"
			% (VerbHold.SPEED_MAX * DT))

	player.camera.rotation.x = -deg_to_rad(15.0)
	var point := hold.hold_point()
	var enemy := _statue(world, Vector3(point.x, player.global_position.y,
			point.z))
	var standing := enemy.global_position
	var track := await _follow(crate, hold, 90)
	_check(int(track["arrived"]) > 0 and _overlapping(crate, enemy)
			and enemy.global_position.distance_to(standing) < 0.01,
			"an enemy stands at the hold point: the crate goes into it and "
			+ "is held there (after %d ticks), and the enemy is not moved"
			% track["arrived"])
	_released_why.clear()
	hold.release(VerbHold.INPUT)
	var drift := 0.0
	for _i in 20:
		await get_tree().physics_frame
		drift = maxf(drift, _flat(crate.linear_velocity))
	_check(_released_why == [VerbHold.INPUT] and is_instance_valid(hold)
			and enemy.get_collision_exceptions().has(crate) and drift < 0.5,
			"released inside the enemy, it falls through without being thrown "
			+ "out (%.2f m/s sideways at most): the exception holds while " % drift
			+ "they overlap")
	enemy.global_position += Vector3(6.0, 0.0, 0.0)
	await _settle(4)
	_check(not is_instance_valid(hold)
			and not enemy.get_collision_exceptions().has(crate)
			and not crate.get_collision_exceptions().has(enemy),
			"once apart, both exceptions go, and the finished hold with them")
	var refused_enemy := VerbHold.begin(player.camera, enemy,
			"ab_physics_light", player)
	var heavy := _crate(130.0, player.global_position
			+ Vector3(2.0, 0.5, -4.0), Vector3(1.0, 1.0, 1.0))
	await _settle(2)
	var refused_heavy := VerbHold.begin(player.camera, heavy,
			"ab_physics_light", player)
	var refused_self := VerbHold.begin(player.camera, player,
			"ab_physics_light", player)
	_check(refused_enemy["refused"] == Manipulation.ACTOR_RULE
			and refused_heavy["refused"] == Manipulation.TOO_HEAVY
			and refused_self["refused"] == Manipulation.NEVER_THE_PLAYER,
			"§14.2 for HOLD: an enemy (%s), 130 kg on the light profile (%s), "
			% [refused_enemy["refused"], refused_heavy["refused"]]
			+ "the player (%s)" % refused_self["refused"])
	world.queue_free()
	crate.queue_free()
	heavy.queue_free()
	await _settle(4)


## §14.3: "Releases on: input release, target leaving `range x 1.5`, line
## of sight blocked for `0.5 s`, `breakable_at` exceeded on a constraint
## the object participates in, player death, room unload, save, or the
## target being destroyed." Each one the runtime watches, driven for
## real; input release was driven above, and save, like input, is the
## caller's to call.
func _hold_lets_go_when_it_should() -> void:
	print("  -- HOLD: the release list")
	var stage := _stage(Vector3(800.0, 0.0, 0.0))
	var world: Node3D = stage["world"]
	var player: Player = stage["player"]
	await _settle(20)
	var start := player.global_position

	var crate := _crate(40.0, start + Vector3(0.0, 0.4, -4.0))
	await _settle(10)
	_released_why.clear()
	var hold := _held(player, crate)
	await _settle(40)
	player.global_position = start + Vector3(0.0, 0.0, 25.0)
	await _settle(2)
	var kept := hold.holding()
	player.global_position = start + Vector3(0.0, 0.0, 28.0)
	await _settle(2)
	_check(kept and _released_why == [VerbHold.OUT_OF_RANGE],
			"range x 1.5: held with the body about 28 m away, released past "
			+ "30 m (%s)" % [_released_why])
	player.global_position = start
	crate.queue_free()
	await _settle(10)

	crate = _crate(40.0, start + Vector3(0.0, 0.4, -4.0))
	await _settle(10)
	_released_why.clear()
	hold = _held(player, crate)
	await _settle(60)
	var wall := _wall(world, start + Vector3(0.0, 1.6, -2.0))
	await _settle(20)
	var still := hold.holding() and hold.occluded_for > 0.2
	wall.queue_free()
	await _settle(3)
	var reset := hold.holding() and is_zero_approx(hold.occluded_for)
	wall = _wall(world, start + Vector3(0.0, 1.6, -2.0))
	var ticks := 0
	while _holding(hold) and ticks < 90:
		await get_tree().physics_frame
		ticks += 1
	_check(still and reset and _released_why == [VerbHold.OCCLUDED]
			and ticks >= 30 and ticks <= 32,
			"line of sight: a wall for 20 ticks is not enough and the count "
			+ "starts again, then %d ticks of it release the hold (0.5 s is 30)"
			% ticks)
	wall.queue_free()
	crate.queue_free()
	await _settle(10)

	var links := Constraints.new()
	links.name = "Constraints"
	world.add_child(links)
	crate = _crate(40.0, start + Vector3(0.0, 0.4, -4.0))
	links.declare([{
		"constraint_id": "leash", "kind": "ROPE", "b": crate,
		"anchor_a": start + Vector3(0.0, 0.5, -4.0), "length": 1.0,
		"length_min": 0.5, "length_max": 2.0, "breakable_at": 200.0,
	}])
	await _settle(10)
	_released_why.clear()
	hold = _held(player, crate)
	ticks = 0
	while _holding(hold) and ticks < 90:
		await get_tree().physics_frame
		ticks += 1
	_check(_released_why == [VerbHold.CONSTRAINT_BROKE]
			and links.is_broken("leash"),
			"a 200 N rope it hangs on breaks, and the hold lets go with it "
			+ "(after %d ticks)" % ticks)
	crate.queue_free()
	await _settle(4)

	crate = _crate(40.0, start + Vector3(0.0, 0.4, -4.0))
	await _settle(10)
	_released_why.clear()
	hold = _held(player, crate)
	await _settle(10)
	crate.queue_free()
	await _settle(2)
	_check(_released_why == [VerbHold.TARGET_GONE],
			"the target destroyed: released (%s)" % [_released_why])

	crate = _crate(40.0, start + Vector3(0.0, 0.4, -4.0))
	await _settle(10)
	_released_why.clear()
	var first := _held(player, crate)
	await _settle(4)
	var second := _held(player, crate)
	await _settle(4)
	_check(_released_why == [VerbHold.SUPERSEDED] and second != null
			and _holding(second) and not _holding(first),
			"a second HOLD on the held body releases the first (§31.2)")
	second.release(VerbHold.SAVE)
	await _settle(4)

	_released_why.clear()
	hold = _held(player, crate)
	await _settle(10)
	world.remove_child(player)
	await _settle(2)
	_check(_released_why == [VerbHold.CASTER_GONE]
			and is_equal_approx(crate.gravity_scale, 1.0),
			"the caster leaves the world, as a Zone exit takes it: released, "
			+ "gravity restored (%s)" % [_released_why])
	world.add_child(player)
	player.global_position = start
	await _settle(10)

	_released_why.clear()
	hold = _held(player, crate)
	await _settle(10)
	player.take_damage(Constants.PLAYER_MAX_HP * 10.0)
	await _settle(2)
	_check(_released_why == [VerbHold.DEATH]
			and is_equal_approx(crate.gravity_scale, 1.0),
			"the caster dies: released, gravity restored (%s)"
			% [_released_why])
	world.queue_free()
	crate.queue_free()
	await _settle(4)


## §14.3: "Rotates to the nearest axis-aligned orientation over `0.3 s`,
## then holds orientation for `2.5 s` while translation continues
## normally." Item 10: "within 0.02 rad of axis alignment and holds
## orientation 2.5 s while gravity still acts on it." In free fall.
func _align_turns_then_holds() -> void:
	print("  -- ALIGN: a turn over 0.3 s, then 2.5 s without rotating")
	var at := Vector3(900.0, 60.0, 0.0)
	var eye := at + Vector3(0.0, 0.0, 6.0)
	var crate := _crate(40.0, at)
	crate.global_transform.basis = Basis(Vector3(1.0, 2.0, 0.5).normalized(),
			0.7)
	# THE CONTROL: the same body, the same fall, no ALIGN.
	var twin := _crate(40.0, at + Vector3(3.0, 0.0, 0.0))
	twin.global_transform.basis = crate.global_transform.basis
	await _settle(1)
	var out := VerbAlign.begin(eye, crate, "ab_physics_light", _space())
	var align: VerbAlign = out.get("align")
	var turn := float(out.get("turn_rad", 0.0))
	var ticks := 0
	var halfway := -1.0
	while align != null and not align.locked and ticks < 60:
		await get_tree().physics_frame
		ticks += 1
		if ticks == 9:
			halfway = VerbAlign.angle_between(crate.global_transform.basis,
					align.goal)
	var arrived := VerbAlign.angle_between(crate.global_transform.basis,
			align.goal)
	_check(bool(out["applied"]) and turn > 0.2 and ticks >= 18
			and ticks <= 21 and arrived <= 0.02
			and halfway > turn * 0.35 and halfway < turn * 0.65,
			"item 10: it turns %.3f rad to the nearest axis-aligned " % turn
			+ "orientation over %d ticks (0.3 s is 18) -- %.3f rad still to "
			% [ticks, halfway] + "go at tick 9 -- and arrives within %.4f rad"
			% arrived)
	var fell_from := crate.global_position.y
	var worst := 0.0
	var held := 0
	var sideways := 0.0
	var apart := 0.0
	while is_instance_valid(align) and held < 200:
		await get_tree().physics_frame
		if not is_instance_valid(align):
			break
		held += 1
		worst = maxf(worst, VerbAlign.angle_between(
				crate.global_transform.basis, align.goal))
		apart = maxf(apart, absf(crate.global_position.y
				- twin.global_position.y))
		if held == 60:
			crate.apply_impulse(Vector3(0.0, 0.0, 40.0),
					Vector3(0.4, 0.4, 0.0))
		if held == 61:
			sideways = crate.linear_velocity.z
	var fell := fell_from - crate.global_position.y
	_check(held >= 149 and held <= 152 and worst <= 0.02,
			"it holds that orientation for %d ticks (2.5 s is 150), never " % held
			+ "more than %.4f rad off, through an off-centre knock" % worst)
	_check(fell > 5.0 and apart < 0.02 and sideways > 0.9,
			"while translation carries on as it would have: it fell %.1f m, " % fell
			+ "never more than %.3f m from a twin falling without ALIGN, " % apart
			+ "and the knock moved it along at %.2f m/s" % sideways)
	var before := crate.global_transform.basis
	crate.apply_impulse(Vector3(0.0, 0.0, 40.0), Vector3(0.4, 0.4, 0.0))
	await _settle(10)
	var spun := VerbAlign.angle_between(before, crate.global_transform.basis)
	_check(not crate.axis_lock_angular_x and not crate.axis_lock_angular_y
			and not crate.axis_lock_angular_z and spun > 0.05,
			"then its own locks are given back: the same knock now turns it "
			+ "(%.3f rad)" % spun)
	var enemy := _statue(self, at + Vector3(4.0, 0.0, 0.0))
	await _settle(1)
	_check(VerbAlign.begin(eye, enemy, "ab_physics_light", _space())
			["refused"] == Manipulation.ACTOR_RULE,
			"§14.2: ALIGN on an enemy is refused by the actor rule")
	enemy.queue_free()
	crate.queue_free()
	twin.queue_free()
	await _settle(2)


## §14.3 SETTLE, and item 20: "zeroes velocity on every eligible body in
## radius and forces sleep next tick, and does not affect a body under
## WINCH drive."
func _settle_calms_what_it_may() -> void:
	print("  -- SETTLE: calm, asleep next tick; machinery, actors, FIXED "
			+ "and a withheld required object left alone")
	var stage := _stage(Vector3(1000.0, 0.0, 0.0))
	var world: Node3D = stage["world"]
	var player: Player = stage["player"]
	await _settle(20)
	var base := player.global_position + Vector3(0.0, 0.0, -12.0)
	var sliding: Array[ManipulableBody] = []
	for i in 3:
		sliding.append(_crate(30.0, base + Vector3(-3.0 + 3.0 * i, 0.4, 0.0)))
	var outside := _crate(30.0, base + Vector3(9.5, 0.4, 0.0))
	var ballast := _crate(450.0, base + Vector3(0.0, 0.5, -4.0),
			Vector3(1.0, 1.0, 1.0))
	var barred := _crate(30.0, base + Vector3(-4.0, 0.4, -3.0))
	barred.add_to_group(Constants.REQUIRED_OBJECT_GROUP)
	barred.physics_permitted = false
	var links := Constraints.new()
	links.name = "Constraints"
	world.add_child(links)
	var load := _crate(60.0, base + Vector3(4.0, 3.0, -4.0))
	links.declare([{
		"constraint_id": "hoist", "kind": "ROPE", "b": load,
		"anchor_a": base + Vector3(4.0, 9.0, -4.0), "length": 6.0,
		"length_min": 2.0, "length_max": 6.0,
	}])
	var enemy := _statue(world, base + Vector3(-2.0, 0.0, -2.0))
	await _settle(120)
	var winch := Actuator.constrained("WINCH", links, "hoist", 1.5)
	world.add_child(winch)
	winch.set_input(true)
	await _settle(20)
	for crate in sliding:
		crate.linear_velocity = Vector3(0.0, 0.0, 3.0)
	outside.linear_velocity = Vector3(0.0, 0.0, 3.0)
	ballast.linear_velocity = Vector3(0.0, 0.0, 3.0)
	barred.linear_velocity = Vector3(0.0, 0.0, 3.0)
	await _settle(1)
	enemy.velocity = Vector3(3.0, 0.0, 0.0)
	var eye := player.camera.global_position
	var exclude: Array[RID] = [player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(eye,
			sliding[1].global_position)
	ray.exclude = exclude
	var aim_point: Vector3 = _space().intersect_ray(ray).get("position",
			sliding[1].global_position)
	var out := Manipulation.settle(eye, aim_point, "ab_settle_standard",
			_space(), get_tree(), exclude)
	var settled: Array = out.get("settled", [])
	var left: Dictionary = out.get("left", {})
	var enemy_kept := enemy.velocity.is_equal_approx(Vector3(3.0, 0.0, 0.0))
	var zeroed := sliding.all(func(b: ManipulableBody) -> bool:
		return b.linear_velocity == Vector3.ZERO \
				and b.angular_velocity == Vector3.ZERO)
	_check(bool(out["applied"]) and settled.size() == 3
			and sliding.all(func(b: ManipulableBody) -> bool:
				return settled.has(b))
			and left.get(ballast, "") == Manipulation.FIXED
			and left.get(barred, "") == Manipulation.NOT_PERMITTED
			and left.get(load, "") == Manipulation.DRIVEN
			and not settled.has(outside) and not left.has(outside),
			"the three moving crates are settled; left alone and named: 450 kg "
			+ "(%s), a withheld required object (%s), a winch's load (%s); "
			% [left.get(ballast, "-"), left.get(barred, "-"),
				left.get(load, "-")] + "one 9.5 m out is not in the volume")
	await get_tree().physics_frame
	# THE CONTRACT'S TWO STEPS, THEN WHAT THEY ARE FOR: zeroed on the call,
	# asleep on the next tick, and not moving after. The velocity the
	# solver reports for a resting body one step after an abrupt stop is
	# its contact bookkeeping, not motion; the half second after says so.
	var where: Array[Vector3] = []
	var asleep := true
	var residual := 0.0
	for b in sliding:
		where.append(b.global_position)
		asleep = asleep and b.sleeping
		residual = maxf(residual, b.linear_velocity.length())
	_check(_flat(outside.linear_velocity) > 1.0
			and _flat(ballast.linear_velocity) > 1.0
			and _flat(barred.linear_velocity) > 1.0
			and load.linear_velocity.y > 0.5 and not load.sleeping
			and enemy_kept,
			"and everything left alone keeps moving: the crate outside %.2f, "
			% _flat(outside.linear_velocity) + "450 kg %.2f, the withheld "
			% _flat(ballast.linear_velocity) + "object %.2f m/s, the "
			% _flat(barred.linear_velocity) + "load rising at %.2f m/s under "
			% load.linear_velocity.y + "its winch, the enemy's own velocity "
			+ "untouched")
	await _settle(30)
	var drifted := 0.0
	for i in sliding.size():
		drifted = maxf(drifted, sliding[i].global_position.distance_to(
				where[i]))
	_check(zeroed and asleep and drifted < 0.002,
			"item 20: the three are zeroed on the call and asleep on the next "
			+ "tick, and half a second on they have moved %.4f m (the " % drifted
			+ "solver's reading one step after the stop: %.3f m/s)" % residual)
	var far := Manipulation.settle(eye, eye + Vector3(0.0, 0.0, -26.0),
			"ab_settle_standard", _space(), get_tree(), exclude)
	var wall := _wall(world, eye + Vector3(0.0, 0.0, -2.0))
	await _settle(1)
	var blind := Manipulation.settle(eye, aim_point, "ab_settle_standard",
			_space(), get_tree(), exclude)
	var unknown := Manipulation.settle(eye, aim_point, "ab_settle_wide",
			_space(), get_tree(), exclude)
	_check(far["refused"] == Manipulation.OUT_OF_REACH
			and blind["refused"] == Manipulation.NO_LINE_OF_SIGHT
			and unknown["refused"] == Manipulation.UNKNOWN_PROFILE,
			"refused: a centre 26 m away (%s), a wall before the centre (%s), "
			% [far["refused"], blind["refused"]] + "a profile §14.3 does not "
			+ "name (%s)" % unknown["refused"])
	wall.queue_free()
	world.queue_free()
	for crate in sliding:
		crate.queue_free()
	for body: ManipulableBody in [outside, ballast, barred, load]:
		body.queue_free()
	await _settle(4)


## SETTLE on a body with nothing under it. §14.3 says to force it to
## sleep, and asleep the solver does not move it -- gravity included.
## Measured, not asserted: whether that is intended is the source's
## question (see `PROD_OV05.md`, O05-08.1).
func _a_settled_body_in_mid_air() -> void:
	print("  -- SETTLE in mid-air: what the letter of the contract does")
	var at := Vector3(1100.0, 60.0, 0.0)
	var crate := _crate(30.0, at)
	await _settle(2)
	var eye := at + Vector3(0.0, 0.0, 6.0)
	var ray := PhysicsRayQueryParameters3D.create(eye, at)
	var aim_point: Vector3 = _space().intersect_ray(ray).get("position", at)
	var out := Manipulation.settle(eye, aim_point, "ab_settle_standard",
			_space(), get_tree())
	var from := crate.global_position.y
	await _settle(61)
	var fell := from - crate.global_position.y
	_check(bool(out["applied"]) \
			and _contains(out["settled"] as Array, crate),
			"a falling crate in mid-air is settled like any other")
	_note("asleep with nothing under it, it has fallen %.3f m in 1 s: " % fell
			+ "the forced sleep holds it in the air until something wakes it")
	crate.queue_free()
	await _settle(2)


## Item 21: "No sequence of verb inputs moves the player, across 10,000
## randomised attempts."
func _no_verb_moves_the_player() -> void:
	print("  -- item 21: no verb moves the player")
	var stage := _stage(Vector3(1200.0, 0.0, 0.0))
	var player: Player = stage["player"]
	await _settle(30)
	var before := player.global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = 2108
	var space := _space()
	var profiles: Array = Manipulation.PHYSICS_PROFILES.keys()
	var targeted := 0
	var refused := 0
	var volumes := 0
	var touched := 0
	for i in 10000:
		var eye := before + Vector3(rng.randf_range(-6.0, 6.0),
				rng.randf_range(0.2, 3.0), rng.randf_range(-6.0, 6.0))
		var aim := (before + Vector3(0.0, 0.9, 0.0) - eye).normalized()
		var profile := str(profiles[rng.randi() % 3])
		var kind := rng.randi() % 5
		if kind == 4:
			volumes += 1
			var out := Manipulation.settle(eye, before, "ab_settle_standard",
					space, get_tree())
			if bool(out["applied"]) \
					and _contains(out["settled"] as Array, player):
				touched += 1
			continue
		targeted += 1
		var tried: Dictionary
		match kind:
			0:
				tried = Manipulation.impulse_verb("PUSH", player, eye, aim,
						profile, space)
			1:
				tried = Manipulation.impulse_verb("PULL", player, eye, aim,
						profile, space)
			2:
				tried = VerbHold.begin(player.camera, player, profile, player)
			_:
				tried = VerbAlign.begin(eye, player, profile, space)
		if tried["refused"] == Manipulation.NEVER_THE_PLAYER:
			refused += 1
	await _settle(5)
	var moved := player.global_position.distance_to(before)
	_check(refused == targeted and touched == 0 and moved < 0.01
			and player.velocity.length() < 0.01,
			"item 21: %d aimed verbs all refused as never the player, %d "
			% [targeted, volumes] + "SETTLE volumes around it never touched "
			+ "it, and it has moved %.4f m" % moved)
	(stage["world"] as Node).queue_free()
	await _settle(4)


## §14.3 PIN, and item 13: "PIN holds a 260 kg object against gravity for
## exactly 6.0 s on `ab_pin_brief`, and supports a 140 kg object resting
## on it."
func _pin_holds_what_it_pins() -> void:
	print("  -- PIN: 260 kg held in the air for exactly 6 s, bearing 140 kg")
	var at := Vector3(1300.0, 30.0, 0.0)
	var eye := at + Vector3(0.0, 0.0, 8.0)
	var slab := _crate(260.0, at, Vector3(2.0, 0.5, 2.0))
	await _settle(1)
	var out := VerbPin.begin(eye, slab, "ab_pin_brief", _space())
	var pin: VerbPin = out.get("pin")
	# TIMED BY THE PIN ITSELF: the physics frame it began on and the one
	# its release fired on. A loop counting its own resumes would count
	# the step after the release too, and read the fall that follows it.
	var began := Engine.get_physics_frames()
	var why: Array[String] = []
	var ended_on: Array[int] = []
	if pin != null:
		pin.released.connect(func(r: String) -> void:
			why.append(r)
			ended_on.append(Engine.get_physics_frames()))
	var weight := _crate(140.0, at + Vector3(0.0, 1.2, 0.0))
	var start := slab.global_position
	var ticks := 0
	var drift := 0.0
	var resting := 0.0
	var weight_speed := 0.0
	while ticks < 400:
		await get_tree().physics_frame
		if not _live(pin):
			break
		ticks += 1
		drift = maxf(drift, slab.global_position.distance_to(start))
		if ticks == 300:
			resting = weight.global_position.y - slab.global_position.y
			weight_speed = weight.linear_velocity.length()
	var held_for := (ended_on[0] - began) if not ended_on.is_empty() else -1
	_check(bool(out["applied"]) and why == [VerbPin.EXPIRED]
			and held_for >= 359 and held_for <= 361 and drift < 0.001,
			"item 13: 260 kg pinned on `ab_pin_brief` does not move "
			+ "(%.4f m) for %d physics frames (6.0 s is 360), then the pin "
			% [drift, held_for] + "expires")
	_check(absf(resting - 0.65) < 0.05 and weight_speed < 0.05,
			"and 140 kg rests on it, not through it: %.3f m above its " % resting
			+ "centre (0.65 is resting), moving at %.3f m/s" % weight_speed)
	await _settle(20)
	_check(slab.global_position.y < start.y - 0.05 and not slab.freeze,
			"unpinned, it falls (%.2f m), frozen no longer"
			% (start.y - slab.global_position.y))
	var heavy := _crate(300.0, at + Vector3(6.0, 0.0, 0.0),
			Vector3(1.0, 1.0, 1.0))
	var enemy := _statue(self, at + Vector3(-6.0, -1.0, 0.0))
	await _settle(1)
	var too_heavy := VerbPin.begin(eye, heavy, "ab_pin_brief", _space())
	var actor := VerbPin.begin(eye, enemy, "ab_pin_brief", _space())
	_check(too_heavy["refused"] == Manipulation.TOO_HEAVY
			and actor["refused"] == Manipulation.ACTOR_MASS_UNMODELLED,
			"refused: 300 kg on a 260 kg profile (%s), an enemy (%s: §14.2 "
			% [too_heavy["refused"], actor["refused"]] + "admits PIN on one, "
			+ "and its mass limit reads a mass no enemy has here)")
	var pins: Array = []
	var ended: Array[String] = []
	for i in 3:
		var crate := _crate(20.0, at + Vector3(-3.0 + 3.0 * i, 6.0, 0.0))
		await _settle(1)
		var held: VerbPin = VerbPin.begin(eye, crate, "ab_pin_brief",
				_space()).get("pin")
		held.released.connect(func(r: String) -> void: ended.append(r))
		pins.append(held)
	_check(ended == [VerbPin.MAX_PINNED] and not _live(pins[0])
			and _live(pins[1]) and _live(pins[2]),
			"`max_pinned` is 2 on `ab_pin_brief`: a third pin releases the "
			+ "oldest (%s)" % [ended])
	for held: Variant in pins:
		if _live(held):
			(held as VerbPin).release(VerbPin.DETACHED)
	enemy.queue_free()
	for body: Node in [slab, weight, heavy]:
		body.queue_free()
	await _settle(4)


## §14.3 TETHER, items 11 and 12: "TETHER between two points 9 m apart
## creates a ROPE of length 9.45 (x1.05)" and "A tether beyond
## `max_length` fails on the second activation and refunds nothing."
func _tether_ties_two_ends() -> void:
	print("  -- TETHER: two activations, a rope 1.05 of the span")
	var stage := _stage(Vector3(1400.0, 0.0, 0.0))
	var world: Node3D = stage["world"]
	var player: Player = stage["player"]
	await _settle(20)
	var base := player.global_position
	var links := Constraints.new()
	links.name = "Constraints"
	world.add_child(links)
	var beam := _beam(world, base + Vector3(0.0, 9.4, -6.0))
	var crate := _crate(40.0, base + Vector3(0.0, 0.4, -6.0))
	await _settle(20)
	var eye := player.camera.global_position
	var space := _space()
	var up := base + Vector3(0.0, 9.4, -6.0)
	var first := VerbTether.first(eye, beam, up, "ab_tether_light", space,
			player)
	var pending: VerbTether.Pending = first.get("pending")
	var tied := pending.second(eye, crate,
			crate.global_position + Vector3(0.0, 0.4, 0.0), space, links)
	var tether: VerbTether = tied.get("tether")
	var why: Array[String] = []
	if tether != null:
		tether.released.connect(func(r: String) -> void: why.append(r))
	var id := tether.rope_id if tether != null else ""
	_check(bool(first["applied"]) and bool(tied["applied"])
			and absf(float(tied["length_m"]) - 9.45) < 0.01
			and absf(links.length_of(id) - 9.45) < 0.01
			and links.kind_of(id) == "ROPE"
			and is_equal_approx(links.breakable_at_of(id), 2500.0),
			"item 11: a beam's underside and a crate 9 m below it make a "
			+ "ROPE of %.3f m (x1.05), breakable at the profile's %.0f N"
			% [links.length_of(id), links.breakable_at_of(id)])
	# 18 m from the eye, within the profile's 22; 15 m from the beam.
	var far := _crate(40.0, base + Vector3(0.0, 0.4, -18.0))
	var ropes := links.ids().size()
	await _settle(2)
	var again := VerbTether.first(eye, beam, up, "ab_tether_light", space,
			player)
	var pending_far: VerbTether.Pending = again.get("pending")
	var long := pending_far.second(eye, far,
			far.global_position + Vector3(0.0, 0.4, 0.0), space, links)
	var retry := pending_far.second(eye, crate,
			crate.global_position + Vector3(0.0, 0.4, 0.0), space, links)
	_check(long["refused"] == VerbTether.TOO_LONG
			and retry["refused"] == VerbTether.SPENT
			and links.ids().size() == ropes,
			"item 12: %.1f m against a 14 m `max_length` fails on the second "
			% float(long.get("span_m", 0.0)) + "activation (%s), and the "
			% long["refused"] + "spent first is not refunded: a retry is "
			+ "refused as %s and no rope is made" % retry["refused"])
	var enemy := _statue(world, base + Vector3(3.0, 0.0, -6.0))
	await _settle(1)
	var at_enemy := VerbTether.first(eye, enemy, enemy.global_position
			+ Vector3(0.0, 1.0, 0.0), "ab_tether_light", space, player)
	var at_player := VerbTether.first(eye, player, player.global_position,
			"ab_tether_light", space, player)
	var out_of_range := VerbTether.first(eye, beam, up + Vector3(0.0, 0.0,
			-30.0), "ab_tether_light", space, player)
	_check(at_enemy["refused"] == Manipulation.ACTOR_RULE
			and at_player["refused"] == Manipulation.NEVER_THE_PLAYER
			and out_of_range["refused"] == Manipulation.OUT_OF_REACH,
			"refused at the first activation: an enemy (%s), the player (%s), "
			% [at_enemy["refused"], at_player["refused"]] + "a point past 22 m "
			+ "(%s)" % out_of_range["refused"])
	enemy.queue_free()
	tether.release(VerbTether.SAVE)
	await _settle(1)
	_check(why == [VerbTether.SAVE] and not links.has(id),
			"EPHEMERAL: a save takes the rope out of the solver")
	# A rope to each of three crates, one at a time: `concurrent` is 2.
	var three: Array = []
	var ended: Array[String] = []
	for i in 3:
		var hung := _crate(20.0, base + Vector3(-2.0 + 2.0 * i, 0.4, -6.0))
		await _settle(2)
		var start := VerbTether.first(eye, beam, up, "ab_tether_light",
				space, player)
		var made: VerbTether = (start["pending"] as VerbTether.Pending) \
				.second(eye, hung, hung.global_position, space, links) \
				.get("tether")
		made.released.connect(func(r: String) -> void: ended.append(r))
		three.append([made, hung])
	_check(ended == [VerbTether.CONCURRENT] and not _live(three[0][0])
			and _live(three[1][0]) and _live(three[2][0]),
			"`concurrent` is 2 on `ab_tether_light`: a third rope releases the "
			+ "oldest (%s)" % [ended])
	ended.clear()
	(three[1][1] as Node).queue_free()
	await _settle(2)
	var gone_rope: bool = not links.has((three[1][0] as Object).get(
			"rope_id")) if is_instance_valid(three[1][0]) else true
	player.take_damage(Constants.PLAYER_MAX_HP * 10.0)
	await _settle(2)
	_check(ended == [VerbTether.TARGET_GONE, VerbTether.DEATH] and gone_rope
			and links.ids().size() == ropes - 1,
			"a tied crate destroyed takes its rope, and the caster's death "
			+ "takes the rest (%s)" % [ended])
	world.queue_free()
	crate.queue_free()
	far.queue_free()
	await _settle(4)


## §14.3 ROTATE, item 17: "ROTATE on a HINGE-constrained object drives it
## within limits and stops at `limit_upper` without oscillating."
func _rotate_turns_a_hinge_and_spins_a_body() -> void:
	print("  -- ROTATE: a hinge driven to its limit, a free body spun")
	var at := Vector3(1500.0, 10.0, 0.0)
	var world := Node3D.new()
	add_child(world)
	var links := Constraints.new()
	links.name = "Constraints"
	world.add_child(links)
	var wheel := _crate(60.0, at, Vector3(2.0, 0.2, 0.4))
	links.declare([{"constraint_id": "valve", "kind": "HINGE", "b": wheel,
			"anchor_a": at, "limit_lower": 0.0, "limit_upper": 1.2}])
	var eye := Node3D.new()
	world.add_child(eye)
	eye.global_position = at + Vector3(0.0, 5.0, 0.0)
	eye.look_at(at, Vector3.FORWARD)
	await _settle(10)
	var out := VerbRotate.begin(eye, wheel, "ab_physics_light", null, -1.0)
	var turned := -1
	var peak := -INF
	for tick in 120:
		await get_tree().physics_frame
		peak = maxf(peak, links.value_of("valve"))
		if turned < 0 and links.value_of("valve") > 1.15:
			turned = tick + 1
	# ARRIVED; NOW, DOES IT SIT THERE? A second more, still driven.
	var lowest := INF
	var highest := -INF
	for _i in 60:
		await get_tree().physics_frame
		lowest = minf(lowest, links.value_of("valve"))
		highest = maxf(highest, links.value_of("valve"))
		peak = maxf(peak, highest)
	_check(bool(out["applied"]) and bool(out["on_hinge"]) and turned > 0
			and absf(highest - 1.2) < 0.05 and peak <= 1.2 + 0.05
			and highest - lowest < 0.02,
			"item 17: seen from above, a hinged valve turns to its 1.2 rad "
			+ "limit (past 1.15 after %d ticks, never beyond %.3f) and sits "
			% [turned, peak] + "there, still driven: %.4f rad of wander in "
			% (highest - lowest) + "a second")
	(out["rotate"] as VerbRotate).release(VerbRotate.INPUT)
	var spun := _crate(20.0, at + Vector3(4.0, 0.0, 0.0))
	var eye_side := Node3D.new()
	world.add_child(eye_side)
	eye_side.global_position = spun.global_position + Vector3(0.0, 0.0, 6.0)
	eye_side.look_at(spun.global_position, Vector3.UP)
	await _settle(1)
	var free := VerbRotate.begin(eye_side, spun, "ab_physics_light")
	await _settle(10)
	var view := (-eye_side.global_transform.basis.z).normalized()
	var omega := spun.angular_velocity
	_check(bool(free["applied"]) and not bool(free["on_hinge"])
			and absf(omega.length() - 2.5) < 0.1
			and omega.normalized().dot(view) > 0.99,
			"a free body spins at %.2f rad/s about the view axis" % omega.length())
	(free["rotate"] as VerbRotate).release(VerbRotate.INPUT)
	var bolted := _crate(20.0, at + Vector3(8.0, 0.0, 0.0))
	bolted.constrained = true
	var drawbridge := _crate(500.0, at + Vector3(-6.0, 0.0, 0.0),
			Vector3(3.0, 0.3, 1.0))
	links.declare([{"constraint_id": "bridge", "kind": "HINGE",
			"b": drawbridge, "anchor_a": drawbridge.global_position,
			"limit_lower": 0.0, "limit_upper": 0.8}])
	var enemy := _statue(world, at + Vector3(0.0, 0.0, 6.0))
	await _settle(2)
	var unhinged := VerbRotate.begin(eye, bolted, "ab_physics_light")
	var hinged := VerbRotate.begin(eye, drawbridge, "ab_physics_light")
	var actor := VerbRotate.begin(eye, enemy, "ab_physics_light")
	_check(unhinged["refused"] == Manipulation.FIXED
			and bool(hinged["applied"]) and bool(hinged["on_hinge"])
			and actor["refused"] == Manipulation.ACTOR_RULE,
			"§14.2: a FIXED body with no hinge is refused (%s); a 500 kg one "
			% unhinged["refused"] + "on a hinge is ROTATE's, by its axis; an "
			+ "enemy is refused (%s)" % actor["refused"])
	if bool(hinged["applied"]):
		(hinged["rotate"] as VerbRotate).release(VerbRotate.INPUT)
	world.queue_free()
	for body: Node in [wheel, spun, bolted, drawbridge]:
		body.queue_free()
	await _settle(4)


## §14.4 and §31.2, items 22 and 23: "`max_relations` at 3 releases the
## oldest relation on a fourth; `RULE_RELATION_COUNT` raises it and never
## past 6" and "A second relation on an already-held object releases the
## first."
func _relations_are_counted_and_exclusive() -> void:
	print("  -- relations: exclusive per object, three at once, oldest out")
	var stage := _stage(Vector3(1600.0, 0.0, 0.0))
	var world: Node3D = stage["world"]
	var player: Player = stage["player"]
	await _settle(20)
	var base := player.global_position
	var links := Constraints.new()
	links.name = "Constraints"
	world.add_child(links)
	var beam := _beam(world, base + Vector3(0.0, 9.0, -8.0))
	var crates: Array[ManipulableBody] = []
	for i in 4:
		crates.append(_crate(20.0, base + Vector3(-3.0 + 2.0 * i, 0.4, -5.0)))
	await _settle(20)
	var eye := player.camera.global_position
	var space := _space()
	var ended: Array[String] = []
	var hold := _held(player, crates[0])
	hold.released.connect(func(r: String) -> void: ended.append("hold " + r))
	await _settle(2)
	var pin: VerbPin = VerbPin.begin(eye, crates[0], "ab_pin_brief", space,
			player).get("pin")
	await _settle(1)
	_check(ended == ["hold superseded"] and _live(pin)
			and VerbRelations.of(player).count() == 1,
			"item 23: pinning the held crate releases the HOLD (%s); one "
			% [ended] + "relation, not two")
	ended.clear()
	pin.released.connect(func(r: String) -> void: ended.append("pin " + r))
	var tether: VerbTether = (VerbTether.first(eye, beam,
			base + Vector3(-1.0, 9.0, -8.0), "ab_tether_light", space,
			player)["pending"] as VerbTether.Pending).second(eye, crates[1],
			crates[1].global_position, space, links).get("tether")
	var second_hold := _held(player, crates[2])
	await _settle(1)
	var three := VerbRelations.of(player).count()
	var fourth: VerbPin = VerbPin.begin(eye, crates[3], "ab_pin_brief",
			space, player).get("pin")
	await _settle(1)
	_check(three == 3 and ended == ["pin max_relations"] and _live(tether)
			and _live(second_hold) and _live(fourth)
			and VerbRelations.of(player).count() == 3,
			"item 22: a pin, a tether and a hold are three; a fourth relation "
			+ "releases the oldest (%s)" % [ended])
	var ledger := VerbRelations.of(player)
	var raised := ledger.raise_by(1)
	var capped := ledger.raise_by(9)
	_check(raised == 4 and capped == VerbRelations.CEILING,
			"`RULE_RELATION_COUNT` raises the cap (+1 is %d) and never past 6 "
			% raised + "(+9 is %d)" % capped)
	for held: Variant in ledger.relations():
		(held as Object).call("release", "input")
	world.queue_free()
	for crate in crates:
		crate.queue_free()
	await _settle(4)


## A GIRDER as §10.1 has it: 95 kg, and "attaches at both ends" -- METAL,
## with a point at each end that takes METAL. The points sit one girder's
## length out, so a girder welded at one continues the span.
func _girder(at: Vector3) -> ManipulableBody:
	var girder := _crate(95.0, at, Vector3(2.0, 0.3, 0.3))
	girder.material = "METAL"
	var metal: Array[String] = ["METAL"]
	girder.attach_points = [
		AttachPoint.at(Transform3D(Basis(), Vector3(2.0, 0.0, 0.0)), metal),
		AttachPoint.at(Transform3D(Basis(), Vector3(-2.0, 0.0, 0.0)), metal),
	]
	return girder


## Hold `body` from where the player stands now, in reach of `point`.
func _hold_near(player: Player, body: ManipulableBody, point: Vector3,
		profile := "ab_physics_light") -> VerbHold:
	player.global_position = Vector3(point.x, player.global_position.y,
			point.z + 2.0)
	await _settle(2)
	return _held(player, body, profile)


## §14.3 ATTACH and DETACH, items 14-16: "`ATTACH` joins two `GIRDER`s
## into one body of `190 kg`, class `HEAVY`"; "A fifth `ATTACH` onto a
## four-object chain is rejected"; "`DETACH` restores both bodies at their
## world transforms with zero velocity".
func _attach_welds_and_detach_gives_back() -> void:
	print("  -- ATTACH / DETACH: one welded body, and both given back")
	var stage := _stage(Vector3(1700.0, 0.0, 0.0))
	var world: Node3D = stage["world"]
	var player: Player = stage["player"]
	await _settle(20)
	var base := player.global_position
	var girders: Array[ManipulableBody] = []
	for i in 5:
		girders.append(_girder(base + Vector3(-8.0 + 4.0 * i, 0.15, -6.0)))
	await _settle(40)
	var root := girders[0]
	var socket := VerbAttach.world_transform_of(root) \
			* (root.attach_points[0] as AttachPoint).local_transform
	var hold := await _hold_near(player, girders[1], socket.origin)
	var eye := player.camera.global_position
	_released_why.clear()
	var out := VerbAttach.attach(hold, root, 0, eye)
	await _settle(2)
	_check(bool(out["applied"]) and is_equal_approx(root.mass, 190.0)
			and root.mass_class() == MassClass.HEAVY
			and VerbAttach.count(root) == 2
			and girders[1].welded_into == root and not girders[1].visible
			and girders[1].collision_layer == 0 and not _holding(hold)
			and _released_why == [VerbAttach.ATTACHED],
			"item 14: two 95 kg GIRDERs are one body of %.0f kg, class %s; "
			% [root.mass, root.mass_class()] + "the held one left the hand "
			+ "for the weld (%s)" % [_released_why])
	# ONE BODY: a push on the root carries the welded girder's shape.
	var part_hull: Node3D = null
	for child: Node in root.get_children():
		if child is CollisionShape3D and str(child.name).ends_with("hull") \
				and child.name != "hull":
			part_hull = child
	var from := part_hull.global_position if part_hull != null \
			else Vector3.ZERO
	root.receive_impulse(Vector3(0.0, 0.0, 190.0 * 2.0))
	await _settle(10)
	var carried := part_hull.global_position.distance_to(from) \
			if part_hull != null else 0.0
	_check(part_hull != null and carried > 0.1,
			"and it moves as one: a push on the root carries the welded "
			+ "girder's own hull %.2f m" % carried)
	# THE CHAIN: two more make four, and a fifth is refused.
	for spec: Array in [[2, root, 1], [3, girders[1], 0]]:
		var host: ManipulableBody = spec[1]
		var at := VerbAttach.world_transform_of(host) \
				* (host.attach_points[spec[2]] as AttachPoint).local_transform
		var held := await _hold_near(player, girders[spec[0]], at.origin)
		VerbAttach.attach(held, host, spec[2], player.camera.global_position)
		await _settle(2)
	var fifth_at := VerbAttach.world_transform_of(girders[2]) \
			* (girders[2].attach_points[1] as AttachPoint).local_transform
	# The fifth waits 20 m down the floor: the strong profile's 28 m.
	var fifth := await _hold_near(player, girders[4], fifth_at.origin,
			"ab_physics_strong")
	var refused := VerbAttach.attach(fifth, girders[2], 1,
			player.camera.global_position)
	_check(VerbAttach.count(root) == 4
			and refused["refused"] == VerbAttach.CHAIN_FULL
			and _holding(fifth) and is_equal_approx(root.mass, 380.0),
			"item 15: four GIRDERs are one chain of %d (%.0f kg); a fifth is "
			% [VerbAttach.count(root), root.mass] + "refused (%s) and stays "
			% refused["refused"] + "in the hand")
	fifth.release(VerbHold.INPUT)
	await _settle(30)
	# DETACH: the first girder welded, given back where it is now.
	var where := VerbAttach.world_transform_of(girders[1])
	var detached := VerbAttach.detach(girders[1])
	var hull := girders[1].get_node_or_null("hull") as CollisionShape3D
	_check(bool(detached["applied"])
			and girders[1].global_transform.origin.distance_to(where.origin)
				< 0.001
			and hull != null and girders[1].visible
			and girders[1].collision_layer != 0 and not girders[1].freeze
			and girders[1].linear_velocity == Vector3.ZERO
			and root.linear_velocity == Vector3.ZERO
			and is_equal_approx(root.mass, 285.0)
			and girders[1].welded_into == null,
			"item 16: DETACH gives the girder back at its world transform "
			+ "(%.4f m off), its own hull back under its own name, both "
			% girders[1].global_transform.origin.distance_to(where.origin)
			+ "bodies at rest, and the root %.0f kg" % root.mass)
	await _settle(4)
	# Its other part, girder 3, rode on girder 1: after the DETACH it is
	# still on the root, where it was.
	_check(girders[3].welded_into == root and VerbAttach.count(root) == 3,
			"and the rest of the chain is untouched (%d on the root)"
			% VerbAttach.count(root))
	# THE BASE KIT'S UNDO: `interact` on the assembly takes back the
	# newest weld a player made; an authored weld stays.
	var prompt := root.interact_prompt()
	root.interact(player)
	await _settle(2)
	_check(prompt == "DETACH" and girders[3].welded_into == null
			and VerbAttach.count(root) == 2,
			"a player with no DETACH Echo undoes their own newest weld with "
			+ "`interact` (prompt %s)" % prompt)
	var authored_at := VerbAttach.world_transform_of(root) \
			* (root.attach_points[0] as AttachPoint).local_transform
	var authored := await _hold_near(player, girders[3],
			authored_at.origin)
	VerbAttach.attach(authored, root, 0, player.camera.global_position,
			false)
	await _settle(2)
	root.interact(player)
	root.interact(player)
	await _settle(2)
	_check(girders[3].welded_into == root and girders[2].welded_into == null,
			"an authored weld is not undone by `interact`: the player's own "
			+ "goes, the authored one stays")
	# THE REFUSALS, beside a free girder, with the player next to its point.
	var host := girders[4]
	var free_at := VerbAttach.world_transform_of(host) \
			* (host.attach_points[0] as AttachPoint).local_transform
	player.global_position = Vector3(free_at.origin.x, base.y,
			free_at.origin.z + 2.0)
	await _settle(4)
	var crate := _crate(20.0, Vector3(free_at.origin.x + 1.5, base.y + 0.4,
			free_at.origin.z + 1.0))
	crate.material = "WOOD"
	var bare := _crate(20.0, Vector3(free_at.origin.x - 1.5, base.y + 0.4,
			free_at.origin.z + 1.0))
	await _settle(10)
	var wood: VerbHold = VerbHold.begin(player.camera, crate,
			"ab_physics_light", player).get("hold")
	var wrong := VerbAttach.attach(wood, host, 0,
			player.camera.global_position)
	if wood != null:
		wood.release(VerbHold.INPUT)
	var unknown: VerbHold = VerbHold.begin(player.camera, bare,
			"ab_physics_light", player).get("hold")
	var no_material := VerbAttach.attach(unknown, host, 0,
			player.camera.global_position)
	var far := VerbAttach.attach(unknown, host, 0,
			player.camera.global_position + Vector3(0.0, 0.0, 6.0))
	# OCCUPIED: a METAL body is welded at the point, then another tried.
	bare.material = "METAL"
	VerbAttach.attach(unknown, host, 0, player.camera.global_position)
	await _settle(2)
	crate.material = "METAL"
	var second_out := VerbHold.begin(player.camera, crate,
			"ab_physics_light", player)
	var second: VerbHold = second_out.get("hold")
	var full := VerbAttach.attach(second, host, 0,
			player.camera.global_position) if second != null \
			else {"refused": "no hold: %s" % second_out["refused"]}
	# Released, and asked at once -- before the hold frees itself.
	if second != null:
		second.release(VerbHold.INPUT)
	var not_held := VerbAttach.attach(second, host, 1,
			player.camera.global_position)
	_check(wrong["refused"] == VerbAttach.WRONG_MATERIAL
			and no_material["refused"] == VerbAttach.NO_MATERIAL
			and far["refused"] == VerbAttach.POINT_OUT_OF_REACH
			and full["refused"] == VerbAttach.OCCUPIED
			and not_held["refused"] == VerbAttach.NOT_HELD,
			"refused: WOOD at a METAL point (%s), a body of no declared "
			% wrong["refused"] + "material (%s), a point past 4 m (%s), an "
			% [no_material["refused"], far["refused"]] + "occupied point "
			+ "(%s), nothing held (%s)" % [full["refused"],
				not_held["refused"]])
	# DETACH on a constraint: only a breakable one breaks.
	var links := Constraints.new()
	links.name = "Constraints"
	world.add_child(links)
	var hung := _crate(20.0, base + Vector3(6.0, 3.0, -6.0))
	links.declare([
		{"constraint_id": "frail", "kind": "ROPE", "b": hung,
			"anchor_a": base + Vector3(6.0, 6.0, -6.0), "length": 3.0,
			"breakable_at": 900.0},
		{"constraint_id": "sound", "kind": "ROPE", "b": crate,
			"anchor_a": base + Vector3(0.0, 4.0, -3.0), "length": 4.0},
	])
	await _settle(2)
	var severed := VerbAttach.sever(links, "frail")
	var kept := VerbAttach.sever(links, "sound")
	_check(bool(severed["applied"]) and links.is_broken("frail")
			and kept["refused"] == VerbAttach.UNBREAKABLE
			and not links.is_broken("sound"),
			"DETACH on a constraint breaks the breakable one and refuses the "
			+ "unbreakable (%s)" % kept["refused"])
	world.queue_free()
	for body: Node in [crate, bare, hung]:
		body.queue_free()
	for girder in girders:
		girder.queue_free()
	await _settle(4)


## The aim point on `body`: where a ray from `eye` meets it.
func _aim_point(eye: Vector3, body: Node3D, exclude: Array[RID]) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(eye, body.global_position)
	ray.exclude = exclude
	return _space().intersect_ray(ray).get("position", body.global_position)


## §14.3 LIGHTEN_FIELD / ANCHOR_FIELD, items 18 and 19: "`LIGHTEN_FIELD` at
## `0.35` on a `320 kg` `BALLAST` yields `112 kg`, class `MEDIUM`, and the
## change reverts exactly on expiry" and "Two overlapping fields do not
## stack; the later-applied wins."
func _fields_scale_kilograms() -> void:
	print("  -- the mass fields: kilograms scaled, never stacked, given back")
	var stage := _stage(Vector3(1800.0, 0.0, 0.0))
	var world: Node3D = stage["world"]
	var player: Player = stage["player"]
	await _settle(20)
	var base := player.global_position
	var ballast := _crate(320.0, base + Vector3(0.0, 0.5, -8.0),
			Vector3(1.0, 1.0, 1.0))
	await _settle(40)
	var eye := player.camera.global_position
	var exclude: Array[RID] = [player.get_rid()]
	var space := _space()
	var aim := _aim_point(eye, ballast, exclude)
	var before := Manipulation.target_refusal("PUSH", ballast, eye,
			Manipulation.PHYSICS_PROFILES["ab_physics_light"], space, exclude)
	var out := VerbField.begin(VerbField.LIGHTEN, eye, aim, "ab_mass_light",
			space, world, exclude)
	var light: VerbField = out.get("field")
	var began := Engine.get_physics_frames()
	var ended_on: Array[int] = []
	if light != null:
		light.ended.connect(func(_r: String) -> void:
			ended_on.append(Engine.get_physics_frames()))
	var rest := ballast.global_position
	await _settle(10)
	var during := Manipulation.target_refusal("PUSH", ballast, eye,
			Manipulation.PHYSICS_PROFILES["ab_physics_light"], space, exclude)
	_check(bool(out["applied"]) and is_equal_approx(ballast.mass, 112.0)
			and ballast.mass_class() == MassClass.MEDIUM
			and ballast.statuses == null,
			"item 18: LIGHTEN_FIELD at 0.35 makes a 320 kg BALLAST %.1f kg, "
			% ballast.mass + "class %s -- in kilograms, with no Status on it"
			% ballast.mass_class())
	_check(before == Manipulation.TOO_HEAVY and during == ""
			and ballast.global_position.distance_to(rest) < 0.01,
			"\"immovable until it is lightened\": the light profile's PUSH "
			+ "refuses it (%s) and then admits it, and the field itself " % before
			+ "moved nothing (%.4f m)" % ballast.global_position.distance_to(rest))
	# Item 19, while the LIGHTEN_FIELD runs: an ANCHOR_FIELD over it.
	var heavy_out := VerbField.begin(VerbField.ANCHOR, eye, aim,
			"ab_mass_heavy", space, world, exclude)
	var heavy: VerbField = heavy_out.get("field")
	# Read every tick, not once: a field that judged eligibility on the
	# kilograms it scaled would drop the body it had made FIXED, give it back
	# its 320, and take it again the tick after -- a flicker one reading on
	# the right tick would miss.
	var readings: Array[float] = []
	var classes: Array[String] = []
	for i in 12:
		await get_tree().physics_frame
		readings.append(ballast.mass)
		classes.append(ballast.mass_class())
	var anchored := ballast.mass
	var steady := readings.all(func(kg: float) -> bool:
			return is_equal_approx(kg, 800.0))
	var fixed_all := classes.all(func(c: String) -> bool:
			return c == MassClass.FIXED)
	var seen: Array[String] = []
	for c in classes:
		if not seen.has(c):
			seen.append(c)
	_check(bool(heavy_out["applied"]) and steady and fixed_all,
			"item 19: an ANCHOR_FIELD laid over it wins, and does not stack: "
			+ "%.0f kg (320 x 2.5, not 112 x 2.5 = 280) on every one of %d "
			% [anchored, readings.size()] + "ticks (%.0f to %.0f), class "
			% [readings.min(), readings.max()] + "%s on all of them -- "
			% "/".join(seen)
			+ "which does not drop it from the field, whose eligibility reads "
			+ "its own 320 kg")
	heavy.end("test")
	await _settle(2)
	_check(is_equal_approx(ballast.mass, 112.0) and light.active(),
			"the later one gone, the earlier one -- still running -- has it "
			+ "again: %.1f kg" % ballast.mass)
	while ended_on.is_empty() and Engine.get_physics_frames() - began < 700:
		await get_tree().physics_frame
	var lasted := (ended_on[0] - began) if not ended_on.is_empty() else -1
	_check(ballast.mass == 320.0 and ballast.mass_class() == MassClass.HEAVY
			and lasted >= 599 and lasted <= 601,
			"item 18: and on expiry after %d physics frames (10 s is 600) it "
			% lasted + "is exactly %.1f kg again, class %s"
			% [ballast.mass, ballast.mass_class()])
	# KILOGRAMS AND CLASS, KEPT APART: a `lightened` crate in a field.
	var crate := _crate(100.0, base + Vector3(3.0, 0.4, -8.0))
	crate.apply_status("lightened", 60.0, 1.0)
	await _settle(4)
	var status_only := crate.mass_class()
	var both_out := VerbField.begin(VerbField.LIGHTEN, eye,
			_aim_point(eye, crate, exclude), "ab_mass_light", space, world,
			exclude)
	var both: VerbField = both_out.get("field")
	await _settle(2)
	var scaled := crate.mass
	var both_class := crate.mass_class()
	both.end("test")
	await _settle(2)
	_check(status_only == MassClass.LIGHT and is_equal_approx(scaled, 35.0)
			and both_class == MassClass.LIGHT and crate.mass == 100.0
			and crate.statuses.has("lightened")
			and crate.mass_class() == MassClass.LIGHT,
			"a Status steps the class and a field scales the kilograms: "
			+ "100 kg lightened reads %s; in the field it is %.0f kg, "
			% [status_only, scaled] + "derived MEDIUM stepped to %s; out of "
			% both_class + "it, 100 kg again with the Status still on it")
	# MEMBERSHIP: in, and out.
	var drifter := _crate(20.0, base + Vector3(12.0, 0.4, -8.0))
	var wide := VerbField.begin(VerbField.LIGHTEN, eye, aim, "ab_mass_light",
			space, world, exclude).get("field") as VerbField
	await _settle(2)
	var outside := drifter.mass
	drifter.global_position = ballast.global_position + Vector3(2.0, 0.0, 0.0)
	await _settle(2)
	var inside := drifter.mass
	drifter.global_position = base + Vector3(12.0, 0.4, -8.0)
	await _settle(2)
	_check(is_equal_approx(outside, 20.0) and is_equal_approx(inside, 7.0)
			and is_equal_approx(drifter.mass, 20.0),
			"a volume, not a snapshot: a crate outside it is %.0f kg, carried "
			% outside + "in it is %.0f kg, and carried out, its own %.0f kg "
			% [inside, drifter.mass] + "again")
	wide.end("test")
	# WHAT A FIELD LEAVES ALONE, AND WHAT IS REFUSED.
	var fixed := _crate(450.0, base + Vector3(-2.0, 0.5, -8.0),
			Vector3(1.0, 1.0, 1.0))
	var withheld := _crate(40.0, base + Vector3(1.5, 0.4, -9.5))
	withheld.add_to_group(Constants.REQUIRED_OBJECT_GROUP)
	withheld.physics_permitted = false
	await _settle(4)
	var last := VerbField.begin(VerbField.LIGHTEN, eye, aim, "ab_mass_light",
			space, world, exclude).get("field") as VerbField
	await _settle(2)
	_check(fixed.mass == 450.0 and withheld.mass == 40.0
			and last.governed.has(ballast),
			"left alone in the volume: 450 kg (FIXED) and a required object "
			+ "whose package withholds physics")
	last.end("test")
	var wrong := VerbField.begin(VerbField.LIGHTEN, eye, aim,
			"ab_mass_heavy", space, world, exclude)
	var far := VerbField.begin(VerbField.LIGHTEN, eye,
			eye + Vector3(0.0, 0.0, -25.0), "ab_mass_light", space, world,
			exclude)
	var wall := _wall(world, eye + Vector3(0.0, 0.0, -2.0))
	await _settle(1)
	var blind := VerbField.begin(VerbField.LIGHTEN, eye, aim,
			"ab_mass_light", space, world, exclude)
	var neither := VerbField.begin("SHRINK_FIELD", eye, aim,
			"ab_mass_light", space, world, exclude)
	_check(wrong["refused"] == VerbField.WRONG_DIRECTION
			and far["refused"] == Manipulation.OUT_OF_REACH
			and blind["refused"] == Manipulation.NO_LINE_OF_SIGHT
			and neither["refused"] == VerbField.NOT_A_FIELD,
			"refused: a LIGHTEN_FIELD on the anchoring profile (%s), a "
			% wrong["refused"] + "centre 25 m off (%s), a wall before it "
			% far["refused"] + "(%s), and a field §14.1 does not name (%s)"
			% [blind["refused"], neither["refused"]])
	wall.queue_free()
	await _settle(2)
	# A WELD UNDER A FIELD KEEPS ITS KILOGRAMS: two 95 kg girders welded
	# inside a LIGHTEN_FIELD are one body of 190 kg, which the field scales;
	# the field gone, 190; detached, 95 each.
	var g_root := _girder(base + Vector3(-5.0, 0.15, -14.0))
	var g_part := _girder(base + Vector3(-5.0, 0.15, -11.0))
	await _settle(20)
	player.global_position = base + Vector3(-3.0, 0.0, -9.0)
	await _settle(4)
	var near_eye := player.camera.global_position
	var weld_field: VerbField = VerbField.begin(VerbField.LIGHTEN, near_eye,
			_aim_point(near_eye, g_root, exclude), "ab_mass_light", _space(),
			world, exclude).get("field")
	# Asked now: an ended field frees itself, and a freed one reads null.
	var laid := weld_field != null
	await _settle(2)
	var socket := VerbAttach.world_transform_of(g_root) \
			* (g_root.attach_points[0] as AttachPoint).local_transform
	var weld_hold := await _hold_near(player, g_part, socket.origin)
	VerbAttach.attach(weld_hold, g_root, 0, player.camera.global_position)
	await _settle(2)
	var welded_scaled := g_root.mass
	if weld_field != null:
		weld_field.end("test")
	await _settle(2)
	var welded_own := g_root.mass
	VerbAttach.detach(g_part)
	await _settle(2)
	_check(laid and is_equal_approx(welded_scaled, 66.5)
			and is_equal_approx(welded_own, 190.0)
			and is_equal_approx(g_root.mass, 95.0)
			and is_equal_approx(g_part.mass, 95.0),
			"a weld under a field keeps its kilograms: two girders welded in "
			+ "a LIGHTEN_FIELD are %.1f kg (190 x 0.35); the field gone, " % welded_scaled
			+ "%.0f; detached, %.0f and %.0f" % [welded_own, g_root.mass,
				g_part.mass])
	world.queue_free()
	for body: Node in [ballast, crate, drifter, fixed, withheld, g_root,
			g_part]:
		body.queue_free()
	await _settle(4)
