class_name CrossingDCheck
extends Node
## CROSSING D, CHECKED IN THE REAL GAME (`make godot-crossing-d`).
##
##   godot --headless --path godot -- --crossing-d --crossing-d-check
##   godot --headless --path godot -- --crossing-d --empty-yard \
##       --crossing-d-check
##
## Beside the real `Main`, through the same startup path a tester's launch
## takes, and the player is moved only by pressing what a tester presses:
## steer, walk, jump, aim, fire, use, hold the swing. Each phase says what
## it proves; a failure says where.
##
## 1. **Isolation and build.** The bridge client never opened; four rooms,
##    three Check stand-ins and one local reward; the encounter or none.
## 2. **Tempting, not grabbable** (D-17 rule 2), with the gantry's reach
##    measurement (`RailNetworks.reach_field`, the played jump, D-9):
##    no stand-in is within a hand's reach of anything the base kit
##    stands on without its room's activity, and the Machine Hall's gap is
##    wider than any base-kit jump from anything the near side reaches.
## 3. **The Courtyard:** pad, spring and pad up to the balcony's Check;
##    the rail back down into the hall; the swing tether on in the
##    Courtyard only, and a swing toward the tower ended at the opening.
## 4. **The Machine Hall:** the unpowered lift does nothing; the cell from
##    the hatch; the plate holds the bridge (and the player alone does
##    not); across, the lock (handle thrown to ON); the cell over and
##    installed; the glass door and the lift powered; back through the
##    glass door.
## 5. **The lift and the Upper Yard:** up in the cage; the alcove out of
##    the walkers' notice and nothing fired at it; THE PROJECTILE SWEEP --
##    every place the ranged role's thin sight ray reaches is also clear
##    for its 0.2 m shot; the fight as roles behave (approach, telegraphs,
##    hits); a crate broken; all three put down at baseline numbers; the
##    Check opened; enemies kept in the yard.
## 6. **Shortcuts and the exit:** the gate from the yard side, the stair
##    down, the exit used, the completion menu.
## 7. **From the top:** RESTART is a fresh Crossing; then the legal quick
##    carry (cell across on the rising bridge, lock never pulled) and a
##    run through the yard to the exit without a kill.

const FLAG := "--crossing-d-check"
const STILL_STEP := 0.01
const STUCK_FRAMES := 45
const ARRIVE := 0.6
## `EnemyProjectile`'s collision radius: the shot's real volume.
const SHOT_RADIUS := 0.2
## How far the hand reaches from the eye (`Player._update_interact_target`).
const HAND := 3.0

var failures := 0
var phase := ""
var host: CrossingD
var room: CrossingDRoom
var body: Player
var _notes: Array[String] = []


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "CrossingDCheck"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ONE CHECK ACROSS A RESTART. RESTART reloads the scene, which frees
	# `Main` and everything under it, and the new `Main` asks for a check
	# again: the first one moves to the root to outlive the reload, and a
	# second one finding it there leaves.
	var root := get_tree().root
	var existing := root.get_node_or_null("CrossingDCheck")
	if existing != null and existing != self:
		queue_free()
		return
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("[crossing]   ok    " if ok else "[crossing]   FAIL  ") + what)
	if not ok:
		failures += 1


func _note(what: String) -> void:
	print("[crossing]   note  " + what)


func _phase(name_in: String) -> void:
	phase = name_in
	print("[crossing] -- " + name_in)


func _run() -> void:
	reparent(get_tree().root)
	await _settle(10)
	if not _bind():
		_check(false, "the Crossing was built")
		get_tree().quit(1)
		return
	await _isolation_and_build()
	_tempting_not_grabbable()
	await _courtyard()
	await _machine_hall()
	await _ride_up()
	if CrossingD.empty_requested():
		await _empty_yard()
	else:
		await _alcove_and_fight()
	await _shortcuts_and_exit()
	if not CrossingD.empty_requested():
		await _from_the_top()
	print("[crossing] %s -- %d failure(s)"
			% ["PASS" if failures == 0 else "FAILED", failures])
	_release_all()
	get_tree().quit(1 if failures > 0 else 0)


func _bind() -> bool:
	var scene := get_tree().current_scene
	host = scene.get_node_or_null("CrossingDReview") as CrossingD \
			if scene != null else null
	if host == null:
		return false
	room = host.room
	body = host.player
	return room != null and body != null


# ======================================================== 1. isolation

func _isolation_and_build() -> void:
	_phase("isolation and build")
	_check(BridgeClient.isolated and not BridgeClient.online,
			"the bridge client is isolated and offline (no socket opened)")
	_check(room.stand_ins.size() == 4, "four stand-ins: %s"
			% [room.stand_ins.keys()])
	var checks := 0
	for stand_in: CrossingDParts.StandIn in room.stand_ins.values():
		checks += 1 if stand_in.kind == "check" else 0
	_check(checks == 3, "three of them Checks, one a local reward")
	var want := 0 if CrossingD.empty_requested() else 3
	_check(room.enemies.size() == want, "the yard holds %d enemies (%s)"
			% [room.enemies.size(), "empty yard" if want == 0
				else "ranged, melee, charger"])
	for enemy in room.enemies:
		var stats: Dictionary = Constants.ENEMY_STATS[enemy.archetype]
		_check(is_equal_approx(enemy.hp, float(stats["hp"])),
				"%s at baseline hp %.0f" % [enemy.archetype, enemy.hp])
	_check(not host.tether_on and (body.runtimes["echo_a"] as EchoRuntime)
			.equipped.is_empty(), "no swing tether at the arrival")
	_check((body.runtimes["mobility"] as EchoRuntime).equipped.is_empty(),
			"no dash, nor anything else, in the mobility slot")
	_check(not room.powered and room.lift.t == 0.0 and room.glass_door.is_shut(),
			"the lift dark at the bottom, the glass door shut")


# ======================================= 2. tempting, not grabbable

func _tempting_not_grabbable() -> void:
	_phase("tempting, not grabbable (D-9 reach)")
	var space := room.get_world_3d().direct_space_state
	var apex := RailNetworks.stepped_apex()
	_note("the played jump tops out at %.2f m (stepped_apex)" % apex)
	# THE COURTYARD: the floor's reach, pads and spring left out -- what
	# the field reaches is what a player reaches without the activity.
	var court := room.courtyard_box()
	var field := RailNetworks.reach_field(space, court, 0.0)
	for id in ["courtyard_balcony", "courtyard_overlook"]:
		var at: Vector3 = (room.stand_ins[id] as Node3D).global_position
		var near := _closest_reach(field, 0.0, at + Vector3.UP * 0.5)
		_check(near > HAND + 0.5, "%s: the nearest eye the base kit stands "
				% id + "or jumps to is %.1f m from it (a hand reaches %.1f)"
				% [near, HAND])
	# The ledges are the activity's, not the floor's.
	for ledge in [room.LEDGE_1, room.LEDGE_2]:
		var top := Vector3(ledge.get_center().x, ledge.end.y,
				ledge.get_center().z)
		_check(not _reached_at(field, 0.0, top), "ledge %.1f m up is not "
				% ledge.end.y + "climbed from the floor")
	# THE MACHINE HALL: the near side and the pit only, the bridge up.
	var near_box := AABB(Vector3(room.MACHINE.position.x, room.PIT_FLOOR - 1.0,
			room.GAP_Z.x), Vector3(room.MACHINE.size.x,
			room.MACHINE_CEILING - room.PIT_FLOOR + 1.0,
			room.MACHINE.end.y - room.GAP_Z.x))
	var near_field := RailNetworks.reach_field(space, near_box, 0.0)
	var worst := INF
	var heights: PackedFloat32Array = near_field["heights"]
	var came: PackedInt32Array = near_field["came"]
	for i in heights.size():
		if came[i] == -2:
			continue
		var z := float(near_field["z0"]) + (int(near_field["zs"][i]) + 0.5) \
				* RailNetworks.REACH_CELL
		var across := z - room.GAP_Z.x
		var reach := RailNetworks.jump_reach(heights[i], 0.0)
		if reach < 0.0:
			continue
		worst = minf(worst, across - reach)
	_check(worst > 0.0, "the gap: from everything the near side and the pit "
			+ "reach, the far side is %.2f m beyond the longest base-kit jump"
			% worst)
	var gap := room.GAP_Z.y - room.GAP_Z.x
	_note("the gap is %.1f m edge to edge; the measurement's own jump, "
			% gap + "radii and cell included, carries %.2f m"
			% RailNetworks.jump_reach(0.0, 0.0))
	# THE YARD: the Check stands in a closed glass case until it is clear.
	var check: Node3D = room.stand_ins["upper_yard"]
	var probe := PhysicsRayQueryParameters3D.create(
			check.global_position + Vector3(0, 1.4, 3.0),
			check.global_position + Vector3(0, 1.3, 0))
	var hit := space.intersect_ray(probe)
	if room.populated:
		_check(not hit.is_empty() and hit["collider"] != check,
				"the yard's Check is behind its case while enemies stand")
		_check(not (check as CrossingDParts.StandIn).available,
				"and is not available")


## The base kit's reach field, read: how near any reached surface brings
## an eye -- standing, or at the top of the played jump -- to `point`.
func _closest_reach(field: Dictionary, floor_y: float, point: Vector3) -> float:
	var best := INF
	var heights: PackedFloat32Array = field["heights"]
	var came: PackedInt32Array = field["came"]
	var top := RailNetworks.stepped_apex()
	for i in heights.size():
		if came[i] == -2:
			continue
		var x := float(field["x0"]) + (int(field["xs"][i]) + 0.5) \
				* RailNetworks.REACH_CELL
		var z := float(field["z0"]) + (int(field["zs"][i]) + 0.5) \
				* RailNetworks.REACH_CELL
		var foot := floor_y + heights[i]
		for lift in [0.0, top]:
			var eye := Vector3(x, foot + Constants.PLAYER_EYE_HEIGHT + lift, z)
			best = minf(best, eye.distance_to(point))
	return best


func _reached_at(field: Dictionary, floor_y: float, at: Vector3) -> bool:
	var ix := int(floor((at.x - float(field["x0"])) / RailNetworks.REACH_CELL))
	var iz := int(floor((at.z - float(field["z0"])) / RailNetworks.REACH_CELL))
	if ix < 0 or iz < 0 or ix >= int(field["nx"]) or iz >= int(field["nz"]):
		return false
	var heights: PackedFloat32Array = field["heights"]
	var came: PackedInt32Array = field["came"]
	for i: int in (field["in_cell"] as Array)[iz * int(field["nx"]) + ix]:
		if absf(floor_y + heights[i] - at.y) < 0.3 and came[i] != -2:
			return true
	return false


# ===================================================== 3. the courtyard

func _courtyard() -> void:
	_phase("the courtyard")
	_check(await _walk(Vector3(-7.0, 0, 6.0)), "into the hall from the arrival")
	# The lift, before any power: a pull does nothing and says why.
	_check(await _walk(Vector3(-7.0, 0, -6.6)), "to the lift's open door")
	_check(await _walk(Vector3(-7.0, 0, -10.0), 0.4), "into the dark cage")
	await _hold(2.5)
	_check(room.lift.t == 0.0 and not room.powered,
			"standing in the cage without power: nothing moves (t = %.2f)"
			% room.lift.t)
	_check(host._note.text.contains("no power"),
			"and says so: \"%s\"" % host._note.text)
	_check(await _walk(Vector3(-6.5, 0, -5.0)), "back out of the cage")
	_check(await _walk(Vector3(8.0, 0, 1.0)), "across the hall")
	_check(await _walk(Vector3(14.0, 0, 1.0)), "through the wide opening")
	await _settle(2)
	_check(host.tether_on and not (body.runtimes["echo_a"] as EchoRuntime)
			.equipped.is_empty(), "the swing tether comes on in the Courtyard")
	# PAD 1: from the floor to the first ledge.
	var pad: AffordanceNodes.LaunchPad = room.pads[0]
	var fired := pad.launched
	_check(await _walk(Vector3(14.2, 0, 9.0), 0.4), "short of the first pad")
	await _walk_into(room.PAD_1, 1.2)
	_check(pad.launched > fired, "the first pad fires")
	var landed := await _land()
	_check(landed and _on_top(room.LEDGE_1),
			"and lands the player on the first ledge (at %s)" % _v(body.global_position))
	# THE SPRING: along the ledge and over, onto the second.
	var spring: AffordanceNodes.BouncePad = room.springs[0]
	_check(await _walk(Vector3(31.5, 3.5, 9.0)), "along the first ledge")
	var bounced := spring.launched
	await _walk_through(Vector3(41.0, 6.5, 9.0), 2.6)
	_check(spring.launched > bounced, "the spring fires")
	await _land()
	_check(_on_top(room.LEDGE_2),
			"and the second ledge is where it lands (at %s)" % _v(body.global_position))
	# PAD 2: up to the balcony.
	var pad2: AffordanceNodes.LaunchPad = room.pads[1]
	fired = pad2.launched
	_check(await _walk(Vector3(40.5, 6.5, 7.6), 0.4), "short of the second pad")
	await _walk_into(room.PAD_2, 1.2)
	_check(pad2.launched > fired, "the second pad fires")
	await _land()
	_check(_on_top(room.BALCONY), "onto the balcony, 9.5 m up (at %s)"
			% _v(body.global_position))
	var check: CrossingDParts.StandIn = room.stand_ins["courtyard_balcony"]
	_check(await _walk(check.global_position + Vector3(0, 0, 2.0)),
			"to the balcony's Check")
	await _use(check.global_position + Vector3(0, 0.6, 0))
	_check(check.claimed and host.found.has(check.id),
			"the balcony's Check (stand-in) is found")
	# THE RAIL, from the balcony back down into the hall.
	await _rail_home()
	# Back in: THE SWING, from the floor, to the overlook only it reaches;
	# and one aimed out at the tower, which the opening ends.
	_check(await _walk(Vector3(14.0, 0, 1.0)), "back into the Courtyard")
	await _swing_to_overlook()
	await _swing_at_the_tower()


## From the Courtyard floor south of the overlook's block: jump, tether to
## the third plate over its top, hold forward -- as a player does, since
## the walk solve's air control pulls toward the stick -- and ride up the
## block's face onto it.
func _swing_to_overlook() -> void:
	_check(await _walk(Vector3(15.75, 0, 1.0), 0.4),
			"to the floor south of the overlook")
	var anchor: Vector3 = room.SWING_PLATES[2] - Vector3(0, 0.3, 0)
	_aim(anchor)
	await _settle(2)
	var hit := body.camera_ray(28.0)
	_check(not hit.is_empty() and hit["collider"] is StaticBody3D,
			"the third swing plate is within the tether's 28 m")
	var swung := await _swing(anchor)
	_check(swung, "the tether catches and swings")
	_check(_on_top(room.OVERLOOK), "the swing reaches the overlook, 14 m up "
			+ "(at %s)" % _v(body.global_position))
	if _on_top(room.OVERLOOK):
		var reward: CrossingDParts.StandIn = room.stand_ins["courtyard_overlook"]
		await _walk(reward.global_position + Vector3(1.4, 0, 0.0), 0.4)
		await _use(reward.global_position + Vector3(0, 0.6, 0))
		_check(reward.claimed, "and its local reward (stand-in) is found")
		# Down again: off the edge. No fall damage in this revision.
		var hp := body.hp
		await _walk_through(Vector3(16.0, 14.0, -6.0), 1.0)
		await _land()
		_check(body.global_position.y < 0.5 and body.hp == hp,
				"off the overlook to the floor, unhurt")


## A SWING AIMED OUT OF THE COURTYARD at the tower's head: the tether is
## taken away at the opening, mid-swing.
func _swing_at_the_tower() -> void:
	_check(await _walk(Vector3(14.5, 0, 0.0), 0.4), "to the opening's edge")
	var head := Vector3(-7.0, room.TOWER_HEAD - 0.7, -7.0)
	_aim(head)
	await _settle(2)
	var hit := body.camera_ray(28.0)
	if hit.is_empty():
		_note("the tower's head is out of the tether's reach from here")
		return
	var left_at := [Vector3.INF]
	var ended_outside := [false]
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _settle(7)
	_aim(head)
	Input.action_press("fire_echo")
	var started := false
	for _i in 240:
		await get_tree().physics_frame
		var flat := Vector2(head.x - body.global_position.x,
				head.z - body.global_position.z)
		body.rotation.y = atan2(-flat.x, -flat.y)
		Input.action_press("move_forward", 1.0)
		if body._swing_time > 0.0:
			started = true
		if started and left_at[0] == Vector3.INF \
				and body.global_position.x < room.HALL.end.x:
			left_at[0] = body.global_position
			await _settle(2)
			ended_outside[0] = body._swing_time <= 0.0 \
					and (body.runtimes["echo_a"] as EchoRuntime).equipped.is_empty()
			break
		if body.is_on_floor() and _i > 10:
			break
	Input.action_release("fire_echo")
	Input.action_release("move_forward")
	await _land()
	if not started:
		_note("the swing toward the tower did not catch; not measured")
		return
	_check(left_at[0] == Vector3.INF or ended_outside[0],
			"a swing toward the tower is cut at the opening: %s"
			% ("never left the Courtyard" if left_at[0] == Vector3.INF
				else "ended crossing into the hall at %s" % _v(left_at[0])))
	_check(body.global_position.y < 3.0,
			"and the player comes down in the hall, not up the tower (at %s)"
			% _v(body.global_position))


## Jump, tether to `anchor`, hold forward toward it until a floor.
func _swing(anchor: Vector3) -> bool:
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _settle(7)
	_aim(anchor)
	Input.action_press("fire_echo")
	var swung := false
	for _i in 300:
		await get_tree().physics_frame
		if body._swing_time > 0.0:
			swung = true
		var flat := Vector2(anchor.x - body.global_position.x,
				anchor.z - body.global_position.z)
		if flat.length() > 0.4:
			body.rotation.y = atan2(-flat.x, -flat.y)
		Input.action_press("move_forward", 1.0)
		if body.is_on_floor() and _i > 10:
			break
	Input.action_release("fire_echo")
	Input.action_release("move_forward")
	await _land()
	return swung


func _rail_home() -> void:
	if not _on_top(room.BALCONY):
		_check(false, "the rail starts from the balcony; the climb back failed")
		return
	var start: Vector3 = room.RAIL_POINTS[0]
	var caught := [false]
	var released := [Vector3.INF]
	var on_catch := func(_at: Vector3) -> void: caught[0] = true
	var on_release := func(at: Vector3) -> void: released[0] = at
	body.rail_caught.connect(on_catch)
	body.rail_released.connect(on_release)
	_check(await _walk(Vector3(start.x + 1.8, 9.5, start.z - 0.4)),
			"to the rail's head on the balcony")
	await _walk_through(Vector3(start.x - 6.0, 9.5, start.z + 4.0), 2.0)
	for _i in 900:
		await get_tree().physics_frame
		if OS.has_environment("CROSSING_DEBUG") and _i % 20 == 0:
			_note("rail t=%d at %s v=%s riding=%s floor=%s" % [_i,
					_v(body.global_position), _v(body.velocity),
					body._rider != null, body.is_on_floor()])
		if caught[0] and released[0] != Vector3.INF:
			break
	await _land()
	body.rail_caught.disconnect(on_catch)
	body.rail_released.disconnect(on_release)
	_check(caught[0], "walking onto the rail catches it")
	var here := body.global_position
	_check(here.x < room.HALL.end.x and here.y < 0.5,
			"and it brings the player down into the Central Hall (at %s)"
			% _v(here))
	await _settle(2)
	_check(not host.tether_on and (body.runtimes["echo_a"] as EchoRuntime)
			.equipped.is_empty(), "the tether goes off outside the Courtyard")


# ================================================== 4. the machine hall

func _machine_hall() -> void:
	_phase("the machine hall")
	_check(await _walk(Vector3(-9.0, 0, 7.0)), "across the hall to the Machine Hall")
	_check(await _walk(Vector3(-15.0, 0, 7.0)), "in through its open way")
	# The tether is the Courtyard's: here a press does nothing.
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _hold(0.15)
	_aim(Vector3(-22.0, room.MACHINE_CEILING, -2.0))
	Input.action_press("fire_echo")
	await _hold(0.5)
	Input.action_release("fire_echo")
	_check(body._swing_time <= 0.0, "no swing in the Machine Hall")
	await _land()
	# The player alone on the plate holds nothing.
	_check(await _walk(room.PLATE_AT, 0.3), "onto the plate, empty-handed")
	await _settle(10)
	_check(not room.plate.satisfied() and room.bridge.t == 0.0,
			"the plate needs an object, not the player: the bridge stays up")
	# THE CELL, from the hatch.
	var hatch := Vector3(room.CELL_AT.x, 0, room.MACHINE.end.y - 0.55)
	_check(await _walk(hatch, 0.3), "to the low hatch")
	await _use(room.cell.global_position)
	_check(body.carry.holding() and body.carry.body == room.cell,
			"the cell comes out of the hatch with E")
	# ONTO THE PLATE.
	await _put_on_plate()
	await _hold(room.BRIDGE_SECONDS + 0.6)
	_check(room.plate.satisfied() and room.bridge.t >= 0.999,
			"the cell holds the plate and the bridge comes down (t = %.2f)"
			% room.bridge.t)
	_check(room.line_live("plate") and room.badge_on("bridge"),
			"the plate's line and the bridge's badge light")
	# ACROSS, AND THE LOCK.
	_check(await _walk(Vector3(-22.0, 0, 5.0)), "to the bridge")
	_check(await _walk(Vector3(-22.0, 0, -5.4)), "across it")
	_check(body.global_position.y > -0.5, "on the far side, not in the pit")
	_check(await _walk(Vector3(-17.5, 0, -5.4), 0.4), "to the lock lever")
	await _use(room.lock_lever.global_position + Vector3(0, 0.05, 0))
	await _hold(0.8)
	_check(room.bridge_locked and room.lock_lever.locked,
			"the far lever locks the bridge down")
	_check(absf(room.lock_lever.handle_degrees() - 55.0) < 2.0,
			"its handle stands thrown at ON (%.1f deg), not upright"
			% room.lock_lever.handle_degrees())
	_check(room.lock_lever.interact_prompt() == "BRIDGE LOCKED DOWN",
			"and its prompt says what it did")
	# BACK FOR THE CELL: the lock holds the bridge without it.
	_check(await _walk(Vector3(-22.0, 0, -4.6)), "back to the bridge")
	_check(await _walk(Vector3(-22.0, 0, 5.5)), "back across")
	_check(await _walk(room.PLATE_AT + Vector3(-1.6, 0, 0), 0.4),
			"beside the plate")
	await _use(room.cell.global_position)
	_check(body.carry.holding(), "the cell picked up off the plate")
	await _hold(room.BRIDGE_SECONDS + 0.4)
	_check(not room.plate.satisfied() and room.bridge.t >= 0.999,
			"the lock keeps the bridge down with the plate empty")
	_check(await _walk(Vector3(-22.0, 0, 4.4)), "carrying, to the bridge")
	_check(await _walk(Vector3(-22.0, 0, -5.4)), "carrying, across")
	_check(await _walk(room.SOCKET_AT + Vector3(0, 0, 1.4), 0.3),
			"carrying, to the socket")
	await _use(room.socket.global_position + Vector3(0, 0.5, 0))
	await _hold(0.5)
	_check(room.socket.installed_object != "" and room.powered,
			"the cell installs: the Machine Hall has power")
	await _hold(3.0)
	_check(room.glass_door.is_open(), "the glass door opens")
	_check(room.lift.powered and room.badge_on("lift")
			and room.line_live("power") and room.line_live("power_hall"),
			"the lift has power, and both lines say so")
	_check(room.sign_text("lift") == "LIFT — STEP IN TO RIDE",
			"the lift's sign agrees")
	var far_check: CrossingDParts.StandIn = room.stand_ins["machine_far_ledge"]
	_check(await _walk(far_check.global_position + Vector3(1.4, 0, 0.0), 0.4),
			"to the far ledge's Check")
	await _use(far_check.global_position + Vector3(0, 0.6, 0))
	_check(far_check.claimed, "the far ledge's Check (stand-in) is found")
	# THE SHORTCUT: through the glass door, straight into the hall.
	_check(await _walk(Vector3(-13.6, 0, -6.5), 0.4), "to the glass door")
	_check(await _walk(Vector3(-10.6, 0, -5.0), 0.4),
			"through it into the Central Hall")


## Aim the carried cell over the plate and put it down.
func _put_on_plate() -> void:
	_check(await _walk(room.PLATE_AT + Vector3(-1.9, 0, 0), 0.3),
			"carrying, beside the plate")
	_aim(room.PLATE_AT + Vector3(0, 0.2, 0))
	await _settle(8)
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await _hold(1.2)
	if not room.plate.satisfied():
		_note("the cell landed at %s, off the plate; nudging"
				% _v(room.cell.global_position))


# ========================================== 5. the lift and the upper yard

func _ride_up() -> void:
	_phase("the lift")
	_check(await _walk(Vector3(-7.0, 0, -6.6)), "to the lift")
	_check(room.lift.at_stop() == 0 and room.lift_door_bottom.is_open(),
			"the cage waits at the bottom, its door open")
	_check(await _walk(Vector3(-7.0, 0, -10.0), 0.4), "into the cage")
	for _i in 900:
		await get_tree().physics_frame
		if room.lift.at_stop() == 1 and room.lift_door_top.is_open():
			break
	_check(room.lift.at_stop() == 1 and room.lift_door_top.is_open(),
			"the doors shut, the cage rises, the top door opens")
	_check(body.global_position.y > room.YARD_FLOOR,
			"with the player in it (at %s)" % _v(body.global_position))
	_check(await _walk(Vector3(-7.0, room.YARD_FLOOR, -14.2), 0.4),
			"out into the alcove")


func _alcove_and_fight() -> void:
	_phase("the upper yard")
	var hp := body.hp
	var shots_before := _projectiles()
	await _hold(3.0)
	var noticed := []
	for enemy in room.enemies:
		_note("%s at %s, %.1f m from the player" % [enemy.archetype,
				_v(enemy.global_position), enemy.global_position.distance_to(
					body.global_position)])
		if enemy._has_noticed:
			noticed.append(enemy.archetype)
	_check(not ("melee" in noticed) and not ("charger" in noticed),
			"in the alcove the walkers have not noticed the player (%s)"
			% ("noticed: %s" % [noticed] if not noticed.is_empty() else "none"))
	_check(body.hp == hp and _projectiles() == shots_before,
			"nothing is fired at the alcove and nothing lands (hp %.0f)" % body.hp)
	if "ranged" in noticed:
		_note("the ranged role notices at its 40 m reach (aggro is the "
				+ "greater of 18 m and reach) but has no line into the alcove")
	_projectile_sweep()
	await _fight()


## EVERY PLACE THE RANGED ROLE CAN SEE IS A PLACE ITS SHOT CAN GO.
##
## `Enemy._has_line_of_sight` is a ray from the muzzle to the player's
## chest, and a committed shot is a 0.2 m sphere along the same line. A
## lip or a parapet that the ray clears and the sphere does not is a shot
## the role commits and wastes -- the concourse pier's first placement
## lost every shot to its own edge that way. So the yard floor, the ramp
## and the post are walked in 1 m steps and both are asked.
func _projectile_sweep() -> void:
	var ranged: Enemy = null
	for enemy in room.enemies:
		if enemy.archetype == "ranged":
			ranged = enemy
	if ranged == null:
		return
	var space := ranged.get_world_3d().direct_space_state
	var muzzle := ranged.muzzle()
	var exclude: Array[RID] = []
	for enemy in room.enemies:
		exclude.append(enemy.get_rid())
	exclude.append(body.get_rid())
	var sphere := SphereShape3D.new()
	sphere.radius = SHOT_RADIUS
	var seen := 0
	var clipped: Array[String] = []
	var x := room.YARD.position.x + 0.5
	while x < room.YARD.end.x:
		var z := room.YARD.position.y + 0.5
		while z < room.HALL.position.y - 0.5:
			var stand := _floor_under(space, Vector3(x, room.YARD_CEILING - 0.2, z))
			# Where a player can stand: the floor, the ramp and the post's
			# top -- not the alcove's roof, which nothing reaches.
			if stand != Vector3.INF and stand.y >= room.YARD_FLOOR - 0.05 \
					and stand.y <= room.POST.end.y + 0.05 \
					and stand.distance_to(muzzle) > 1.5:
				var chest := stand + Vector3.UP * 1.0
				var ray := PhysicsRayQueryParameters3D.create(muzzle, chest)
				ray.exclude = exclude
				if space.intersect_ray(ray).is_empty():
					seen += 1
					var shape := PhysicsShapeQueryParameters3D.new()
					shape.shape = sphere
					shape.transform = Transform3D(Basis.IDENTITY, muzzle)
					var travel := chest - muzzle
					shape.motion = travel * maxf(0.0,
							1.0 - 0.45 / travel.length())
					shape.exclude = exclude
					var cast := space.cast_motion(shape)
					if cast.size() > 0 and cast[0] < 0.999:
						shape.transform = Transform3D(Basis.IDENTITY,
								muzzle + shape.motion * cast[1])
						var rest := space.get_rest_info(shape)
						var what := "?"
						if rest.has("collider_id"):
							var hit_node := instance_from_id(
									int(rest["collider_id"])) as Node
							if hit_node != null:
								what = str(hit_node.get_parent().name) \
										if hit_node is StaticBody3D \
										and hit_node.get_parent() is \
										MeshInstance3D else str(hit_node.name)
						clipped.append("%s on %s" % [_v(stand), what])
			z += 1.0
		x += 1.0
	_check(seen > 40, "the ranged role sees %d standing places in the yard"
			% seen)
	# WHAT A CLIP IS. Where a sight ray clears an edge by less than the
	# shot's radius, the shot is spent on that edge. At a piece of cover
	# that is the edge of its shadow -- the player there is just covered,
	# and the shot hits the cover they stand behind: cover working, and
	# reported by piece. What fails is the concourse pier's defect, the
	# shooter's own platform eating shots to the floor beyond its foot,
	# and any shot spent on bare structure (walls, floor, ramp).
	var own_lip: Array[String] = []
	var structure: Array[String] = []
	var by_piece := {}
	const COVER := ["HighCover", "LowCover", "DestructibleCover", "@StaticBody3D",
			"CaseGlass", "AlcoveEast", "AlcoveWest", "AlcoveKerb",
			"AlcoveWindow", "Post"]
	for entry in clipped:
		var at := _parse_v(entry.get_slice(" on ", 0))
		var what := entry.get_slice(" on ", 1)
		if what == "Post" and _flat_gap(room.POST, at) > 3.0:
			own_lip.append(entry)
		var is_cover := false
		for prefix: String in COVER:
			if what.begins_with(prefix):
				is_cover = true
		if not is_cover:
			structure.append(entry)
		var key := "crate" if (what.begins_with("@StaticBody3D")
				or what.begins_with("DestructibleCover")) else what
		by_piece[key] = int(by_piece.get(key, 0)) + 1
	_check(own_lip.is_empty(), "the post's own edge spends no shot aimed "
			+ "beyond 3 m of its foot (%s)" % [", ".join(own_lip)
				if not own_lip.is_empty() else "none"])
	_check(structure.is_empty(), "no shot is spent on bare structure (%s)"
			% [", ".join(structure) if not structure.is_empty() else "none"])
	_note("grazes by piece: %s" % [by_piece])
	_note("%d of %d visible places are grazes along cover (%.1f%%)"
			% [clipped.size(), seen, 100.0 * clipped.size() / maxf(seen, 1.0)])
	for entry in clipped:
		_note("graze: " + entry)


func _floor_under(space: PhysicsDirectSpaceState3D, from: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return Vector3.INF
	# Only real floor: crates, cover and enemies are not somewhere to stand.
	var collider: Object = hit["collider"]
	if collider is DestructibleCover or collider is Enemy:
		return Vector3.INF
	return hit["position"]


## THE ONE FIGHT, played: out by the low route, the roles doing what they
## do, a crate broken, and all three put down with the Static Pulse.
func _fight() -> void:
	var start_hp := body.hp
	var telegraphs := {}
	var hits := {"melee": 0, "charger": 0, "ranged": 0}
	for enemy in room.enemies:
		var kind := enemy.archetype
		enemy.telegraph_started.connect(func(what: String, _s: float) -> void:
				telegraphs[kind + ":" + what] = int(telegraphs.get(
					kind + ":" + what, 0)) + 1)
	var last_hp := [body.hp]
	var tracker := func(hp_now: float, _shield: float) -> void:
		if hp_now < last_hp[0]:
			var nearest := _nearest_enemy()
			if nearest != null and nearest.global_position.distance_to(
					body.global_position) < 3.2:
				hits[nearest.archetype] += 1
			else:
				hits["ranged"] += 1
		last_hp[0] = hp_now
	body.hp_changed.connect(tracker)
	var deaths := [0]
	var on_died := func() -> void: deaths[0] += 1
	body.died.connect(on_died)
	var started := Time.get_ticks_msec()
	var sim_started := Engine.get_physics_frames()
	# Out over the sill and along the low route.
	_check(await _walk(Vector3(-2.6, room.YARD_FLOOR, -14.6), 0.5),
			"out of the alcove over its sill")
	var kept_in := true
	# Into the walkers' 18 m: beside the first low wall.
	await _walk(Vector3(3.0, room.YARD_FLOOR, -17.0), 0.6)
	await _walk(Vector3(2.6, room.YARD_FLOOR, -22.6), 0.6)
	# Let the roles come, and watch what they do for a few seconds.
	for _i in 300:
		await get_tree().physics_frame
		kept_in = kept_in and _enemies_in_yard()
	var melee_closed := false
	for enemy in room.enemies:
		if enemy.archetype == "melee":
			melee_closed = enemy.global_position.distance_to(
					enemy.post) > 3.0
	_check(melee_closed, "the melee leaves its post for the player")
	# A crate that breaks: orange, and it does.
	var crate: DestructibleCover = null
	for piece in room.covers:
		if is_instance_valid(piece):
			crate = piece
			break
	if crate != null:
		var broke := [false]
		crate.broken.connect(func(_at: Vector3) -> void: broke[0] = true)
		var cover_hp := crate.hp
		await _shoot_at(crate, 10.0, true)
		_check(broke[0] or not is_instance_valid(crate),
				"an orange crate breaks under the Static Pulse (40 hp, %s)"
				% ("broken" if not is_instance_valid(crate) else
					"%.0f hp left of %.0f" % [crate.hp, cover_hp]))
	# Now put them down: the nearest first, from wherever the player is.
	for _round in 4:
		var target := _nearest_enemy()
		while target != null:
			await _engage(target)
			kept_in = kept_in and _enemies_in_yard()
			if is_instance_valid(target) and not target._dead:
				break
			target = _nearest_enemy()
	var alive := 0
	for enemy in room.enemies:
		if is_instance_valid(enemy) and not enemy._dead:
			alive += 1
	var sim := float(Engine.get_physics_frames() - sim_started) \
			/ float(Engine.physics_ticks_per_second)
	_check(alive == 0, "all three put down at baseline numbers "
			+ "(%.0f s of play, %d player death(s))" % [sim, deaths[0]])
	_note("telegraphs seen: %s" % [telegraphs])
	_note("damage taken: from %.0f hp, hits by role %s" % [start_hp, hits])
	_check(telegraphs.has("charger:charge"), "the charger telegraphs its rush")
	_check(telegraphs.has("ranged:aim"), "the ranged role telegraphs its shot")
	_check(hits["melee"] > 0 or hits["charger"] > 0 or hits["ranged"] > 0,
			"and their attacks land on the player")
	_check(kept_in, "every enemy stays inside the yard")
	body.hp_changed.disconnect(tracker)
	body.died.disconnect(on_died)
	_note("wall time for the fight: %.1f s" % ((Time.get_ticks_msec() - started)
			/ 1000.0))
	await _hold(0.6)
	_check(room.cleared, "the yard is clear")
	var check: CrossingDParts.StandIn = room.stand_ins["upper_yard"]
	_check(check.available, "its Check is open")
	_check(await _route([Vector3(11.0, room.YARD_FLOOR, -18.0),
			Vector3(11.0, room.YARD_FLOOR, -37.5),
			Vector3(1.0, room.YARD_FLOOR, -38.0)]),
			"down the east lane to the yard's Check")
	await _use(check.global_position + Vector3(0, 0.6, 0))
	_check(check.claimed, "the yard's Check (stand-in) is found")


func _engage(enemy: Enemy) -> void:
	# From where the player is if the shot is clear; otherwise from the
	# nearest of a few places on the floor with a view.
	var vantage := [Vector3(3.5, room.YARD_FLOOR, -27.0),
			Vector3(0.0, room.YARD_FLOOR, -21.0),
			Vector3(8.0, room.YARD_FLOOR, -24.5),
			Vector3(-4.5, room.YARD_FLOOR, -26.0)]
	for attempt in 6:
		if not is_instance_valid(enemy) or enemy._dead:
			return
		if body._dead:
			await _hold(Constants.RESPAWN_DELAY + 0.4)
			# Back from the alcove after a respawn.
			await _walk(Vector3(-2.6, room.YARD_FLOOR, -14.6), 0.5)
		if _clear_to(body.camera.global_position, enemy):
			await _shoot_at(enemy, 4.0)
			continue
		var goal: Vector3 = vantage[attempt % vantage.size()]
		await _walk(goal, 0.8)


## Aim at `target` and fire: taps, or the trigger held (the Pulse fires
## at its cooldown while the button is down).
func _shoot_at(target: Node3D, seconds: float, held := false) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		if not is_instance_valid(target):
			break
		if target is Enemy and (target as Enemy)._dead:
			break
		var at := (target as Enemy).body_centre() if target is Enemy \
				else target.global_position
		_aim(at)
		if held or i % 18 == 0:
			Input.action_press("fire_pulse", 1.0)
		elif i % 18 == 3:
			Input.action_release("fire_pulse")
		await get_tree().physics_frame
	Input.action_release("fire_pulse")


func _clear_to(from: Vector3, enemy: Enemy) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, enemy.body_centre())
	ray.exclude = [body.get_rid()]
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit["collider"] == enemy


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for enemy in room.enemies:
		if not is_instance_valid(enemy) or enemy._dead:
			continue
		var d := enemy.global_position.distance_to(body.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _enemies_in_yard() -> bool:
	var box := room.yard_box().grow(0.3)
	for enemy in room.enemies:
		if is_instance_valid(enemy) and not enemy._dead \
				and not box.has_point(enemy.global_position):
			return false
	return true


func _projectiles() -> int:
	var count := 0
	for node in get_tree().root.find_children("*", "", true, false):
		if node is Enemy.EnemyProjectile:
			count += 1
	return count


# ===================================================== 6. shortcuts, exit

func _shortcuts_and_exit() -> void:
	_phase("shortcuts and the exit")
	_check(await _route([Vector3(11.0, room.YARD_FLOOR, -37.5),
			Vector3(11.0, room.YARD_FLOOR, -18.0),
			Vector3(room.GATE_LEVER_AT.x, room.YARD_FLOOR, -15.0)]),
			"up the east lane to the gate lever")
	await _use(room.gate_lever.global_position + Vector3(0, 0.05, 0))
	await _hold(3.0)
	_check(room.gate_lever.locked and room.gate.is_open(),
			"the gate lever opens the gate from the yard side")
	_check(await _walk(Vector3(10.75, room.YARD_FLOOR, -15.0), 0.4)
			and await _walk(Vector3(10.75, room.YARD_FLOOR, -13.4), 0.4),
			"round the lever to the gate")
	_check(await _walk(Vector3(10.75, room.YARD_FLOOR, -10.8), 0.4),
			"over the sill onto the landing")
	_check(await _walk(Vector3(-3.6, 0, -10.75), 0.6), "down the stair")
	_check(body.global_position.y < 0.5, "into the Central Hall (at %s)"
			% _v(body.global_position))
	# The lift, left at the top: wait at its landing and it comes down.
	if room.powered and room.lift.at_stop() == 1:
		_check(await _walk(Vector3(-7.0, 0, -6.2), 0.4),
				"to the lift's landing in the hall")
		for _i in 900:
			await get_tree().physics_frame
			if room.lift.at_stop() == 0 and room.lift_door_bottom.is_open():
				break
		_check(room.lift.at_stop() == 0 and room.lift_door_bottom.is_open(),
				"waiting at the landing brings the cage down to the hall")
	# Round the tower's front -- not through the lift's open door, where
	# a player who stood a second would be taken up -- to the stair's foot.
	_check(await _route([Vector3(-3.0, 0, -6.2), Vector3(-3.6, 0, -10.75),
			Vector3(8.0, 0, -10.75), Vector3(10.75, room.YARD_FLOOR, -10.8)]),
			"and back up the stair from its foot: the yard without the lift")
	_check(await _walk(Vector3(10.75, room.YARD_FLOOR, -14.0), 0.5),
			"through the gate")
	_check(await _route([Vector3(11.0, room.YARD_FLOOR, -18.0),
			Vector3(11.0, room.YARD_FLOOR, -38.0),
			Vector3(8.0, room.YARD_FLOOR, -40.5)]),
			"across the clear yard to the exit")
	_check(await _walk(Vector3(8.0, room.YARD_FLOOR, -44.0), 0.5),
			"over the exit's sill")
	await _use(room.exit_door.global_position + Vector3(0, 1.8, 0))
	await _settle(3)
	_check(host.completed and host.menu_open(),
			"the exit ends the Crossing and shows the result")
	_check(get_tree().paused, "with the world paused behind it")
	_check(host.found.size() == 4, "all four stand-ins found (%d)"
			% host.found.size())


# ======================================================= 7. from the top

func _from_the_top() -> void:
	_phase("from the top")
	var before := host.get_instance_id()
	host.restart()
	await _settle(12)
	var bound := _bind()
	_check(bound and host.get_instance_id() != before,
			"RESTART builds a fresh Crossing")
	if not bound:
		return
	_check(not room.powered and not room.bridge_locked and room.lift.t == 0.0
			and room.socket.installed_object == "" and not get_tree().paused,
			"nothing of the last run survives it, and the world runs")
	# The menu: open and closed again by the pause key.
	await _press("pause")
	await _settle(3)
	_check(host.menu_open() and get_tree().paused, "Esc opens the menu, paused")
	await _press("pause")
	await _settle(3)
	_check(not host.menu_open() and not get_tree().paused,
			"Esc again closes it and the world runs")
	await _quick_carry()
	await _run_past()


## THE LEGAL QUICK CARRY (D-17, Machine Hall): the cell lifted off the
## plate and carried onto the bridge before it rises; ride it up, step off
## the far end, install -- the lock never pulled.
func _quick_carry() -> void:
	_phase("the quick carry (legal, lock never pulled)")
	await _walk(Vector3(-7.0, 0, 6.0))
	await _walk(Vector3(-15.0, 0, 7.0))
	await _walk(Vector3(room.CELL_AT.x, 0, room.MACHINE.end.y - 0.55), 0.3)
	await _use(room.cell.global_position)
	if not body.carry.holding():
		_check(false, "the cell from the hatch (second run)")
		return
	await _put_on_plate()
	await _hold(room.BRIDGE_SECONDS + 0.4)
	_check(room.bridge.t >= 0.999, "the bridge down under the plate")
	_check(await _walk(room.PLATE_AT + Vector3(-1.6, 0, -0.9), 0.4),
			"beside the plate, on the bridge's side")
	await _use(room.cell.global_position)
	_check(body.carry.holding(), "the cell off the plate: the bridge starts up")
	# Straight onto the rising bridge's near end, and along it.
	var lifted_at := Engine.get_physics_frames()
	await _walk(Vector3(-21.2, 0, 4.6), 0.5)
	var on_bridge := Engine.get_physics_frames() - lifted_at
	_note("at the bridge's near end %.2f s after the lift-off, the bridge "
			% (on_bridge / 60.0) + "%.2f m up" % (room.bridge_body.position.y
				+ 0.25))
	await _walk_through(Vector3(-22.0, 0, -6.0), 3.5)
	await _land()
	var here := body.global_position
	_check(here.z < room.GAP_Z.x - 0.2 and here.y > -0.5,
			"across on the rising bridge, onto the far side (at %s)" % _v(here))
	_check(not room.bridge_locked, "with the lock never pulled")
	if body.carry.holding():
		_check(await _walk(room.SOCKET_AT + Vector3(0, 0, 1.4), 0.3),
				"carrying, to the socket")
		await _use(room.socket.global_position + Vector3(0, 0.5, 0))
	await _hold(0.5)
	_check(room.powered, "and the power is restored without the lock: legal, kept")
	await _hold(3.0)
	_check(await _walk(Vector3(-13.6, 0, -6.5), 0.4) and await _walk(
			Vector3(-10.6, 0, -5.0), 0.4), "the glass door still gets them back")


## RUNNING IS LEGAL: up the lift and across the yard to the exit, no kill.
func _run_past() -> void:
	_phase("through the yard without a kill")
	if not room.powered:
		_check(false, "the run past needs the power from the quick carry")
		return
	await _walk(Vector3(-7.0, 0, -6.6))
	await _walk(Vector3(-7.0, 0, -10.0), 0.4)
	for _i in 900:
		await get_tree().physics_frame
		if room.lift.at_stop() == 1 and room.lift_door_top.is_open():
			break
	await _walk(Vector3(-7.0, room.YARD_FLOOR, -14.2), 0.4)
	await _walk(Vector3(-2.6, room.YARD_FLOOR, -14.6), 0.5)
	var kills_before := 0
	for enemy in room.enemies:
		kills_before += 1 if (not is_instance_valid(enemy) or enemy._dead) else 0
	var route := [Vector3(4.0, room.YARD_FLOOR, -16.0),
			Vector3(11.0, room.YARD_FLOOR, -18.0),
			Vector3(11.0, room.YARD_FLOOR, -38.0),
			Vector3(8.0, room.YARD_FLOOR, -40.5),
			Vector3(8.0, room.YARD_FLOOR, -44.0)]
	var made_it := true
	for point: Vector3 in route:
		if body._dead:
			made_it = false
			break
		made_it = await _walk(point, 0.7) and made_it
	if made_it:
		await _use(room.exit_door.global_position + Vector3(0, 1.8, 0))
		await _settle(3)
	var alive := 0
	for enemy in room.enemies:
		alive += 1 if (is_instance_valid(enemy) and not enemy._dead) else 0
	_check(host.completed, "the exit reached and used with %d of 3 still "
			% alive + "standing (hp %.0f)" % body.hp)
	_check(kills_before == 0, "and none put down on the way")


# ====================================================== the empty yard

func _empty_yard() -> void:
	_phase("the empty yard")
	var check: CrossingDParts.StandIn = room.stand_ins["upper_yard"]
	_check(check.available and room.yard_case.get_child_count() == 0,
			"with no enemies the yard's Check is open from the start")
	_check(room.enemies.is_empty(), "and nothing in it fights")
	_check(await _walk(Vector3(-2.6, room.YARD_FLOOR, -14.6), 0.5),
			"out of the alcove over its sill")
	_check(await _route([Vector3(11.0, room.YARD_FLOOR, -18.0),
			Vector3(11.0, room.YARD_FLOOR, -37.5),
			Vector3(1.0, room.YARD_FLOOR, -38.0)]),
			"down the east lane to the yard's Check")
	await _use(check.global_position + Vector3(0, 0.6, 0))
	_check(check.claimed, "the yard's Check (stand-in) is found")


# ============================================================== helpers

func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _hold(seconds: float) -> void:
	await _settle(int(seconds * Engine.physics_ticks_per_second))


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


## Aim at `at` and press E, as a hand at the controls would.
func _use(at: Vector3) -> void:
	_aim(at)
	await _settle(4)
	_aim(at)
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await _settle(4)


func _aim(at: Vector3) -> void:
	var eye := body.camera.global_position
	var flat := Vector2(at.x - eye.x, at.z - eye.z)
	body.rotation.y = atan2(-flat.x, -flat.y)
	body.camera.rotation.x = atan2(at.y - eye.y, flat.length())


## Steer at `goal` on the flat and walk until within `within`; a body that
## stops making progress fails the walk. Never jumps.
func _walk(goal: Vector3, within := ARRIVE) -> bool:
	var still := 0
	var last := body.global_position
	var arrived := false
	Input.action_press("move_forward", 1.0)
	for _i in 2400:
		if not is_instance_valid(body):
			break
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		body.camera.rotation.x = 0.0
		still = still + 1 if (here - last).length() < STILL_STEP else 0
		if still >= STUCK_FRAMES and body.is_on_floor():
			_note("stalled at %s short of %s" % [_v(here), _v(goal)])
			break
		last = here
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	return arrived


## Walk a list of points in turn; true when every one is reached.
func _route(points: Array) -> bool:
	for point: Vector3 in points:
		if not await _walk(point, 0.6):
			return false
	return true


## Hold forward toward `goal` for `seconds` whatever happens on the way:
## for a pad, a spring or a rail, which carry the body past any goal.
func _walk_through(goal: Vector3, seconds: float) -> void:
	Input.action_press("move_forward", 1.0)
	for _i in int(seconds * Engine.physics_ticks_per_second):
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() > 0.3:
			body.rotation.y = atan2(-flat.x, -flat.y)
		body.camera.rotation.x = 0.0
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame


## Walk onto a pad until it fires (the pad captures and throws the body).
func _walk_into(pad_at: Vector3, seconds: float) -> void:
	var start := Engine.get_physics_frames()
	Input.action_press("move_forward", 1.0)
	while Engine.get_physics_frames() - start < int(seconds * 60.0):
		var here := body.global_position
		var flat := Vector2(pad_at.x - here.x, pad_at.z - here.z)
		if not body.is_on_floor():
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		await get_tree().physics_frame
	Input.action_release("move_forward")


## Wait for the body to be in the air and then on a floor again.
func _land(seconds := 6.0) -> bool:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	var airborne := not body.is_on_floor()
	for _i in frames:
		await get_tree().physics_frame
		if not body.is_on_floor():
			airborne = true
		elif airborne or _i > 30:
			await _settle(3)
			return true
	return body.is_on_floor()


## Standing on top of `box` right now.
func _on_top(box: AABB) -> bool:
	var here := body.global_position
	return here.x > box.position.x - 0.2 and here.x < box.end.x + 0.2 \
			and here.z > box.position.z - 0.2 and here.z < box.end.z + 0.2 \
			and absf(here.y - box.end.y) < 0.45 and body.is_on_floor()


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right",
			"jump", "fire_pulse", "fire_echo", "interact"]:
		Input.action_release(action)


## How far `at` is from `box` across the floor (0 inside its footprint).
func _flat_gap(box: AABB, at: Vector3) -> float:
	var dx := maxf(maxf(box.position.x - at.x, at.x - box.end.x), 0.0)
	var dz := maxf(maxf(box.position.z - at.z, at.z - box.end.z), 0.0)
	return Vector2(dx, dz).length()


func _parse_v(text: String) -> Vector3:
	var parts := text.trim_prefix("(").trim_suffix(")").split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
