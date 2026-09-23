extends Node
## O05-08: THE PUSH AND PULL RUNTIME, AND NOTHING ELSE.
##
## `Manipulation.impulse_verb` against Design 2 §14.2 (eligibility) and
## §14.3/§14.4 (one impulse, its formula and its ceilings), on real bodies
## in a real physics world.
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
var _eye: Vector3 = Vector3(0.0, 1.6, 0.0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: " + message)
	else:
		_failures += 1
		print("FAIL: " + message)


func _ready() -> void:
	_run.call_deferred()


func _finish() -> void:
	if _failures == 0:
		print("GODOT VERB RUNTIME OK (%d checks)" % _checks)
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
	await _lightened_doubles_and_opens_the_door()
	await _each_refusal_is_its_own_answer()
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
