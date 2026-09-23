extends Node
## O05-01 — ORDINARY HAND CARRY, OPERATED (`--carry`).
##
##     make godot-carry
##
## A real `Player` in a small built room, driven through the real input
## path: `interact` to pick up and put down, `move_forward` to walk and
## carry, `fire_pulse` and the mobility slot to prove they are blocked.
## Where the harness sets something directly, the case says so: aiming
## (the body's yaw and the camera's pitch, as every played suite aims),
## the one declared start position per case, and the modal hold, which is
## the same `player.hold("modal")` claim `Main._update_modal` takes when
## the Archive opens.

const DT := 1.0 / 60.0

var failures := 0
var checks := 0
var notes: Array[String] = []

var _world: Node3D
var _player: Player
var _feedback: Array[String] = []
var _prompts: Array[String] = []
var _shots := 0


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)


func _note(message: String) -> void:
	notes.append(message)
	print("  NOTE: " + message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	_build_room()
	await _settle(30)
	await _a_legal_object_is_picked_up_and_follows_the_view()
	await _blocked_actions_while_carrying()
	await _the_wall_stops_it_and_it_is_never_inside()
	await _it_is_put_down_at_rest_and_picked_up_again()
	await _the_wrong_objects_are_refused_with_the_reason()
	await _the_boundary_is_kilograms()
	await _walking_speed_follows_the_class()
	await _a_modal_cannot_drop_it()
	await _death_puts_it_down_where_it_was()
	_finish()


# ---------------------------------------------------------------------------
# The room
# ---------------------------------------------------------------------------

var _bodies := {}
var _wall: StaticBody3D


func _build_room() -> void:
	_world = Node3D.new()
	add_child(_world)
	_world.add_child(_slab(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0)))
	# THE WALL the carry is walked into: its near face at z = -12.
	_wall = _slab(Vector3(0.0, 2.0, -12.2), Vector3(20.0, 4.0, 0.4))
	_world.add_child(_wall)
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	_world.add_child(pool)
	_player = Player.create()
	_world.add_child(_player)
	_player.stat_stack.pool = pool
	_player.set_spawn(Transform3D(Basis(), Vector3(0.0, 0.1, 0.0)))
	_player.carry_feedback.connect(func(text: String, _ok: bool) -> void:
		_feedback.append(text))
	_player.interact_prompt_changed.connect(func(text: String) -> void:
		_prompts.append(text))
	_player.fired_pulse.connect(func() -> void: _shots += 1)
	# id, kg, carriable, where
	for spec: Array in [
			["cell", 18.0, true, Vector3(0.0, 0.35, -2.0)],
			["part", 40.0, true, Vector3(6.0, 0.35, -2.0)],
			["fixture", 18.0, false, Vector3(-6.0, 0.35, -2.0)],
			["limit", 60.0, true, Vector3(0.0, 0.35, 6.0)],
			["over", 60.01, true, Vector3(6.0, 0.35, 6.0)],
			["heavy_lightened", 70.0, true, Vector3(-6.0, 0.35, 6.0)]]:
		var made := ManipulableBody.create(str(spec[0]), float(spec[1]),
				Vector3(0.7, 0.7, 0.7))
		made.carriable = bool(spec[2])
		_world.add_child(made)
		made.global_position = spec[3]
		_bodies[str(spec[0])] = made


func _slab(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	return body


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


## DECLARED HARNESS STEP: where a case starts, and where the player looks.
func _stand(at: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	await _settle(10)


func _aim_at(target: Vector3) -> void:
	var to := target - _player.camera.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _anchor() -> Vector3:
	return _player.camera.global_position + Vector3.DOWN * HandCarry.BELOW_EYE_M


# ---------------------------------------------------------------------------
# The cases
# ---------------------------------------------------------------------------

func _a_legal_object_is_picked_up_and_follows_the_view() -> void:
	print("  -- a legal object, picked up with `interact`")
	var cell: ManipulableBody = _bodies["cell"]
	await _stand(Vector3(0.0, 0.1, 0.0))
	_aim_at(cell.global_position)
	await _settle(3)
	_check(not _prompts.is_empty() and _prompts.back() == "[E] PICK UP · 18 kg",
			"looking at it offers the pickup: \"%s\""
			% [_prompts.back() if not _prompts.is_empty() else ""])
	await _press("interact")
	_check(_player.carry.holding() and _player.carry.body == cell,
			"`interact` picked it up (holding %s)" % [
				_player.carry.body.body_id if _player.carry.holding()
				else "nothing"])
	_check(cell.freeze and cell.collision_layer == 0
			and cell.carried_by == _player,
			"it is carried, not inventoried: a body in the world, moved "
			+ "along the carry line and passed through by actors")
	# FOLLOWING THE VIEW, at the pose.
	_aim_at(_player.camera.global_position + Vector3(0.0, 0.0, -5.0))
	await _settle(30)
	var reach := cell.global_position.distance_to(_anchor())
	_check(absf(reach - HandCarry.FORWARD_M) < 0.1,
			"held %.2f m out along the view (the pose says %.2f m)"
			% [reach, HandCarry.FORWARD_M])
	var before := cell.global_position
	_player.rotation.y += PI * 0.5
	await _settle(40)
	var forward := -_player.camera.global_transform.basis.z
	var toward := (cell.global_position - _anchor()).normalized()
	_check(toward.dot(forward) > 0.97
			and cell.global_position.distance_to(before) > 1.0,
			"turning 90° carries it round to the new view (alignment %.3f)"
			% toward.dot(forward))
	_player.camera.rotation.x = deg_to_rad(-35.0)
	await _settle(30)
	_check(cell.global_position.y < _anchor().y - 0.4,
			"and looking down lowers it (%.2f m below the carry anchor)"
			% (_anchor().y - cell.global_position.y))
	_player.camera.rotation.x = 0.0
	await _settle(20)


func _blocked_actions_while_carrying() -> void:
	print("  -- what carrying blocks, and what it leaves")
	_shots = 0
	Input.action_press("fire_pulse")
	await _settle(40)
	Input.action_release("fire_pulse")
	_check(_player.carry.holding() and _shots == 0,
			"the Static Pulse does not fire while carrying (%d shots)"
			% _shots)
	_feedback.clear()
	await _press("fire_mobility")
	_check(_feedback.has("MOBILITY BLOCKED WHILE CARRYING"),
			"Mobility is blocked, and says so: %s" % [_feedback])
	_check(_player.carry.holding(),
			"and neither of them put the object down")


func _the_wall_stops_it_and_it_is_never_inside() -> void:
	print("  -- walked into a wall while carrying")
	var cell: ManipulableBody = _bodies["cell"]
	_aim_at(_player.camera.global_position + Vector3(0.0, 0.0, -5.0))
	await _stand(Vector3(0.0, 0.1, -6.0))
	_check(_player.carry.holding(),
			"carried to the start of the walk (still holding)")
	_aim_at(_player.camera.global_position + Vector3(0.0, 0.0, -5.0))
	var deepest := -INF
	var held_short := false
	Input.action_press("move_forward")
	for _i in 180:
		await get_tree().physics_frame
		if not _player.carry.holding():
			break
		# THE BOX'S FAR FACE, against the wall's near face at z = -12.0.
		deepest = maxf(deepest, -(cell.global_position.z - 0.35) - 12.0)
		if cell.global_position.distance_to(_anchor()) \
				< HandCarry.FORWARD_M - 0.2:
			held_short = true
	Input.action_release("move_forward")
	_check(deepest <= 0.01,
			"the carried box never entered the wall (deepest %.3f m past "
			% deepest + "its face)")
	_check(held_short or not _player.carry.holding(),
			"it was held short of its pose rather than pushed through "
			+ "(%s)" % ("held short" if held_short else "dropped at the feet"))
	if not _player.carry.holding():
		_note("walking all the way in dropped it at the player's feet")
		_aim_at(cell.global_position)
		await _settle(3)
		await _press("interact")
	await _stand(Vector3(0.0, 0.1, -2.0))
	_aim_at(_player.camera.global_position + Vector3(0.0, 0.0, -5.0))
	await _settle(30)


func _it_is_put_down_at_rest_and_picked_up_again() -> void:
	print("  -- put down with `interact`, and picked up again")
	var cell: ManipulableBody = _bodies["cell"]
	_check(_player.carry.holding(), "still carrying before the drop")
	var carried_at := cell.global_position
	await _press("interact")
	_check(not _player.carry.holding() and not cell.freeze
			and cell.collision_layer != 0,
			"`interact` at nothing put it down: a body again, colliding")
	_check(cell.linear_velocity.length() < 0.5,
			"at zero velocity, no throw (%.2f m/s the frame after)"
			% cell.linear_velocity.length())
	await _settle(90)
	var drift := Vector2(cell.global_position.x - carried_at.x,
			cell.global_position.z - carried_at.z).length()
	_check(drift < 0.15 and cell.global_position.y < 0.5,
			"it came to rest on the floor where it was held (%.2f m of "
			% drift + "drift, y %.2f)" % cell.global_position.y)
	_aim_at(cell.global_position)
	await _settle(3)
	await _press("interact")
	_check(_player.carry.holding() and _player.carry.body == cell,
			"and it can be picked up again")
	await _press("interact")
	_check(not _player.carry.holding(), "and put down again")


func _the_wrong_objects_are_refused_with_the_reason() -> void:
	print("  -- the same 18 kg, not carriable")
	var fixture: ManipulableBody = _bodies["fixture"]
	await _stand(fixture.global_position + Vector3(0.0, -0.25, 2.0))
	_aim_at(fixture.global_position)
	await _settle(3)
	_check(not _prompts.is_empty() and _prompts.back() == "CAN'T CARRY THAT",
			"the prompt says so before the press: \"%s\""
			% [_prompts.back() if not _prompts.is_empty() else ""])
	_feedback.clear()
	await _press("interact")
	_check(not _player.carry.holding()
			and _feedback.has("CAN'T CARRY THAT"),
			"and `interact` refuses it with the reason: %s" % [_feedback])


func _the_boundary_is_kilograms() -> void:
	print("  -- 60.00 kg is carriable, 60.01 kg is not")
	var limit: ManipulableBody = _bodies["limit"]
	await _stand(limit.global_position + Vector3(0.0, -0.25, 2.0))
	_aim_at(limit.global_position)
	await _settle(3)
	await _press("interact")
	_check(_player.carry.holding() and _player.carry.body == limit,
			"exactly %s is picked up" % HandCarry.kg(limit.mass))
	await _press("interact")
	var over: ManipulableBody = _bodies["over"]
	await _stand(over.global_position + Vector3(0.0, -0.25, 2.0))
	_aim_at(over.global_position)
	await _settle(3)
	_feedback.clear()
	await _press("interact")
	_check(not _player.carry.holding() and not _feedback.is_empty()
			and _feedback.back().begins_with("TOO HEAVY TO CARRY · 60.01 kg"),
			"just over is refused, and says by how much: %s" % [_feedback])
	# LIGHTENED IS A CLASS, NOT KILOGRAMS.
	if _player.carry.holding():
		_player.carry.release("drop")
	var heavy: ManipulableBody = _bodies["heavy_lightened"]
	heavy.apply_status("lightened", 30.0, 1.0)
	await _stand(heavy.global_position + Vector3(0.0, -0.25, 2.0))
	_aim_at(heavy.global_position)
	await _settle(3)
	_feedback.clear()
	await _press("interact")
	_check(not _player.carry.holding() and heavy.mass == 70.0
			and heavy.mass_class() == MassClass.LIGHT
			and _feedback.has("TOO HEAVY TO CARRY · 70 kg (limit 60 kg)"),
			"a LIGHTENED 70 kg object reads %s and is still refused: the "
			% heavy.mass_class() + "limit is kilograms (%s)" % [_feedback])


func _walking_speed_follows_the_class() -> void:
	print("  -- walking speed while carrying")
	var free_speed := await _walk_speed(null)
	var light := await _walk_speed(_bodies["cell"])
	var part: ManipulableBody = _bodies["part"]
	var medium := await _walk_speed(part)
	part.apply_status("lightened", 30.0, 1.0)
	var lightened := await _walk_speed(part)
	_check(absf(light / free_speed - 1.0) < 0.03,
			"a LIGHT object costs nothing (%.2f vs %.2f m/s)"
			% [light, free_speed])
	_check(absf(medium / free_speed - HandCarry.MEDIUM_SPEED_FACTOR) < 0.03,
			"a MEDIUM object walks at %.2f of free speed (the rule says "
			% (medium / free_speed) + "%.2f)" % HandCarry.MEDIUM_SPEED_FACTOR)
	_check(absf(lightened / free_speed - 1.0) < 0.03 and part.mass == 40.0,
			"the same 40 kg LIGHTENED reads %s and walks free "
			% part.mass_class() + "(%.2f of free speed)"
			% (lightened / free_speed))


## Metres per second over a straight walk, carrying `body` or nothing.
func _walk_speed(body: ManipulableBody) -> float:
	await _stand(Vector3(-10.0, 0.1, 10.0))
	if body != null:
		body.global_position = Vector3(-10.0, 0.35, 8.0)
		body.linear_velocity = Vector3.ZERO
		await _settle(20)
		_aim_at(body.global_position)
		await _settle(3)
		await _press("interact")
		if not _player.carry.holding():
			_check(false, "picked up %s to walk with" % body.body_id)
			return 0.0
	_player.rotation.y = PI * 0.5
	_player.camera.rotation.x = 0.0
	Input.action_press("move_forward")
	await _settle(40)
	var from := _player.global_position
	await _settle(60)
	var covered := Vector2(_player.global_position.x - from.x,
			_player.global_position.z - from.z).length()
	Input.action_release("move_forward")
	await _settle(20)
	if body != null:
		await _press("interact")
	return covered / (60.0 * DT)


func _a_modal_cannot_drop_it() -> void:
	print("  -- the Archive's hold cannot drop what is carried")
	var cell: ManipulableBody = _bodies["cell"]
	await _stand(Vector3(0.0, 0.1, 0.0))
	cell.global_position = Vector3(0.0, 0.35, -2.0)
	cell.linear_velocity = Vector3.ZERO
	await _settle(20)
	_aim_at(cell.global_position)
	await _settle(3)
	await _press("interact")
	_check(_player.carry.holding(), "carrying before the modal opens")
	# DECLARED: the same claim `Main._update_modal` takes for the Archive.
	_player.hold("modal")
	for _i in 3:
		await _press("interact")
	_check(_player.carry.holding() and cell.freeze,
			"three `interact` presses under the modal hold dropped nothing")
	_player.release("modal")
	await _settle(3)
	await _press("interact")
	_check(not _player.carry.holding(),
			"and the first press after it closes puts it down")


func _death_puts_it_down_where_it_was() -> void:
	print("  -- dying while carrying")
	var cell: ManipulableBody = _bodies["cell"]
	_aim_at(cell.global_position)
	await _settle(3)
	await _press("interact")
	_check(_player.carry.holding(), "carrying again")
	await _settle(20)
	var held_at := cell.global_position
	_player.take_damage(Constants.PLAYER_MAX_HP * 10.0)
	await _settle(5)
	_check(not _player.carry.holding() and is_instance_valid(cell)
			and not cell.freeze,
			"death put it down: still in the world, a body again")
	await _settle(90)
	var drift := Vector2(cell.global_position.x - held_at.x,
			cell.global_position.z - held_at.z).length()
	_check(drift < 0.2,
			"where it was held, at rest (%.2f m), not sent home and not "
			% drift + "deleted")
	await _settle(int(Constants.RESPAWN_DELAY * 60.0) + 30)


func _finish() -> void:
	for action: String in ["move_forward", "fire_pulse", "interact"]:
		Input.action_release(action)
	if failures == 0:
		print("GODOT CARRY TESTS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT CARRY TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
