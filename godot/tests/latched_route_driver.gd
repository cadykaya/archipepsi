extends Node
## P14 — THE LATCHED ROUTE, PLAYED (`--latched-route`).
##
##     make godot-latched-route
##
## The Zone is `tests/fixtures/latched_route_zone.json`, which
## `compose_latched_route` writes from the played Zone (`make
## latched-route-fixture`): since D-07 (owner ruling, 2026-09-24) a
## LEVER -- a visibly permanent control -- a `LATCH`, and a shutter that
## `TopologyEdge e:c002:c003.opened_by` names. It is entered through the
## same `ZoneController` an ordinary player enters through, and nothing
## in it is edited here.
##
## **WHAT IS PLAYED, and what is not substituted.** The real player, on
## `move_forward` and `interact`, through real collision: from the Zone's
## own arrival, through the c001 -> c002 connector; into the shut doorway
## and stopped by it; to the lever, thrown with the interact ray; away
## from it; through the doorway into c003; and back. No handler is called
## by hand, no latch is pre-set, the shutter is not moved by anything but
## the graph, and nothing is placed beyond the door.
##
## **AND THE PLATE D-07 KEEPS** is the control below: an ordinary plate
## is a HELD sensor -- pressure present, open; pressure removed, shut
## (V-08) -- which is exactly why a permanent change is a lever.
##
## **THE ONE HARNESS STEP** is releasing the layout hold once the
## verdict wait has concluded with no bridge to answer it (`_enter`).
## `godot-latched-route-live` plays the same route with the bridge's own
## verdict, through the real `Main`, and across a restart.

const FIXTURE := "res://tests/fixtures/latched_route_zone.json"
const DT := 1.0 / 60.0

var failures := 0
var checks := 0
var notes: Array[String] = []


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
	# One frame first: `_ready` runs while the root is still adding its own
	# children, and an `add_child` on it then fails silently.
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(FIXTURE))
	# BOTH FORMS, WHATEVER THE FIXTURE DECLARES. The Zone as composed
	# first; then the other form by an explicit substitution of the
	# route's one sensor -- so a legacy step-once route (M-1) and the
	# lever (D-07) are each played on this same room and doorway before
	# and after the composer changes which one it writes.
	var composed := _route_sensor_kind(zone_data)
	await _the_route_is_played_end_to_end(zone_data,
			"the Zone as composed (%s)" % composed)
	if composed == "PULSE_BUTTON":
		await _the_route_is_played_end_to_end(_with_route_sensor(zone_data,
				"PRESSURE_PLATE"), "LEGACY step-once plate, as saved (M-1)")
	else:
		await _the_route_is_played_end_to_end(_with_route_sensor(zone_data,
				"PULSE_BUTTON"), "LEVER, D-07's permanent control")
	await _without_the_latch_the_route_does_not_hold(zone_data)
	_finish()


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

var _deaths := 0
var _taken := 0.0
var _last_hp := 0.0


func _enter(zone_data: Dictionary) -> ZoneController:
	var controller := ZoneController.new()
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	controller.add_child(pool)
	get_tree().root.add_child(controller)
	controller.setup(zone_data)
	var player: Player = controller.player
	if player != null:
		player.stat_stack.pool = pool
		player.died.connect(func() -> void: _deaths += 1)
		_last_hp = player.hp
	# **THE ONE HARNESS STEP, declared.** A Zone with edges holds its
	# player until the bridge certifies the layout; with no bridge the
	# silence is read as a refusal after a quarter second and the hold
	# stays on. `godot-latched-route-live` gets the real verdict from the
	# real bridge -- this standalone run stands in for it and nothing
	# else, and says so here rather than hiding it in a helper.
	#
	# **AFTER THE VERDICT WAIT, NOT AFTER A FIXED DELAY.** The publish is
	# two frames, the chain certification, the send and then the wait,
	# and the wait puts the hold back on when it starts. The first
	# version released after thirty frames, the certification outlasted
	# them, and the hold came back mid-walk: the arena fight fired four
	# shots in 8.8 s with the ray on target for 524 frames, and the
	# player died to five turrets while frozen. `room_contract_driver`
	# already waits the same way.
	_held_frames = 0
	for _i in 2400:
		if controller.layout_verdict != "":
			break
		await get_tree().physics_frame
		_held_frames += 1
	if player != null:
		_held_hp = player.hp
		_held_at = player.global_position
		player.release(ZoneController.LAYOUT_HOLD)
		player.input_frozen = false
	return controller


func _drop(controller: ZoneController) -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"jump", "fire_pulse"]:
		Input.action_release(action)
	controller.queue_free()
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame


func _track_damage(player: Player) -> void:
	if player.hp < _last_hp:
		_taken += _last_hp - player.hp
	_last_hp = player.hp


# ---------------------------------------------------------------------------
# Walking -- the real body, on `move_forward`, through real collision
# ---------------------------------------------------------------------------

## Walk toward `goal` until arriving, entering `stop_inside`, or a stall.
##
## Turned by yaw and moved by `move_forward` only. A stall (no progress
## for half a second) sidesteps for a moment and tries again, which is
## how a body gets round a turret standing in its line; `jumps` also lets
## it hop a lip, which the connector pieces need and the room legs do
## not. Returns where it ended and whether it was stopped for good.
func _walk_to(player: Player, goal: Vector3, stop_inside := AABB(),
		budget := 900, jumps := false, arrive := 0.6) -> Dictionary:
	var closest := INF
	var idle := 0
	var sidestepping := 0
	var sidestep := "move_right"
	var start := player.global_position
	var used := 0
	var walked := 0.0
	var was := player.global_position
	Input.action_press("move_forward")
	for i in budget:
		used = i + 1
		_track_damage(player)
		var here := player.global_position
		if stop_inside.has_volume() and stop_inside.has_point(here):
			break
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() <= arrive:
			break
		idle = 0 if flat.length() < closest - 0.05 else idle + 1
		closest = minf(closest, flat.length())
		if idle > 300:
			break
		player.rotation.y = atan2(-flat.x, -flat.y)
		if sidestepping > 0:
			sidestepping -= 1
			if sidestepping == 0:
				Input.action_release(sidestep)
		elif idle > 30 and idle % 30 == 1:
			sidestep = "move_left" if sidestep == "move_right" \
					else "move_right"
			Input.action_press(sidestep)
			sidestepping = 24
			if jumps and player.is_on_floor():
				Input.action_press("jump")
				await get_tree().physics_frame
				Input.action_release("jump")
		await get_tree().physics_frame
		walked += was.distance_to(player.global_position)
		was = player.global_position
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	var ended := player.global_position
	return {"from": start, "at": ended, "frames": used, "walked": walked,
			"closest": closest,
			"arrived": Vector2(goal.x - ended.x, goal.z - ended.z).length()
					<= arrive or (stop_inside.has_volume()
						and stop_inside.has_point(ended)),
			"stalled": idle > 300}


## Press straight at `goal` for `frames`, with NO sidestep and NO jump,
## and report how far the body got. Used where the claim is "this is a
## wall": a harness that steered round the thing it was testing would
## prove nothing about it.
func _press_toward(player: Player, goal: Vector3, frames: int) -> Dictionary:
	var start := player.global_position
	Input.action_press("move_forward")
	for _i in frames:
		_track_damage(player)
		var here := player.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() > 0.05:
			player.rotation.y = atan2(-flat.x, -flat.y)
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return {"from": start, "at": player.global_position}


## FOLLOW THE COMMITTED ROUTE INTO A ROOM: every connector piece's exit,
## then the room's own arrival. The same pieces `reload_driver` follows,
## read off `room_routes`, which is the builder's `links`.
func _walk_into(controller: ZoneController, room: String) -> Dictionary:
	var box: AABB = controller.room_bounds.get(room, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			room).get("arrival", box.get_center())
	var steps: Array[Vector3] = []
	for raw: Variant in (controller.room_routes.get(room, []) as Array):
		var piece: Dictionary = raw
		if piece.has("exit"):
			steps.append(piece["exit"])
	steps.append(arrival)
	var walk: Dictionary = {}
	var total := 0.0
	var frames := 0
	for step: Vector3 in steps:
		walk = await _walk_to(controller.player, step, box.grow(-0.5),
				900, true)
		total += float(walk["walked"])
		frames += int(walk["frames"])
		if box.grow(-0.5).has_point(controller.player.global_position):
			break
	walk["walked"] = total
	walk["frames"] = frames
	walk["legs"] = steps.size()
	return walk


## Which side of a doorway a point is on: positive is the room the
## doorway belongs to, negative is past it.
func _side_of(frame: Dictionary, inward: Vector3, point: Vector3) -> float:
	var door: Vector3 = frame["position"]
	return Vector3(point.x - door.x, 0.0, point.z - door.z).dot(inward)


func _inward_of(frame: Dictionary, box: AABB) -> Vector3:
	var door: Vector3 = frame["position"]
	var normal := Basis(Vector3.UP, float(frame["yaw"])) * Vector3(0, 0, 1)
	var to_centre := box.get_center() - door
	to_centre.y = 0.0
	return normal if normal.dot(to_centre) >= 0.0 else -normal


func _player_on(plate: ClassPlate, player: Player) -> bool:
	var sensor: Area3D = plate.get_node("Sensor")
	for body: Node3D in sensor.get_overlapping_bodies():
		if body == player:
			return true
	return false


## The edge an actuator opens. **`opened_by` is null on every other
## edge**, and `str(null)` is `"<null>"`, not empty -- the first version
## of this matched the Zone's first edge and aimed every doorway check
## at the wrong door.
func _route_edge(zone_data: Dictionary) -> Dictionary:
	for raw: Variant in zone_data.get("edges", []) as Array:
		var named: Variant = (raw as Dictionary).get("opened_by")
		if named != null and str(named) != "":
			return raw
	return {}


func _latch_reports() -> Array:
	var out: Array = []
	for intent: Dictionary in BridgeClient.sent_intents:
		if str(intent.get("type", "")) == "latch_fired":
			out.append(intent)
	return out


func _wait_for(predicate: Callable, frames: int) -> bool:
	for _i in frames:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return predicate.call()


## THE ROOM'S OWN ENEMIES, alive.
func _living_in(controller: ZoneController, room: String) -> Array:
	var out: Array = []
	for record: Dictionary in controller._chambers:
		if str((record["chamber"] as Dictionary).get("id", "")) != room:
			continue
		for enemy: Variant in record["enemies"]:
			if is_instance_valid(enemy) and not (enemy as Enemy)._dead:
				out.append(enemy)
	return out


## Aim the body's yaw and the camera's pitch at a target's CENTRE, which
## is not its origin -- `encounter_driver._aim_at`'s lesson.
func _aim_at(player: Player, target: Node3D) -> void:
	var centre: Vector3 = target.global_position
	var envelope: Dictionary = Constants.ENEMY_ENVELOPES.get(
			(target as Enemy).archetype, {})
	centre.y += float(envelope.get("centre_y", 0.8))
	var to: Vector3 = centre - player.camera.global_position
	if to.length() < 0.01:
		return
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.camera.rotation.y = 0.0


## CLEAR THE ARENA WITH THE BASE KIT, which is what the normal route
## through a `kill_all` room is.
##
## **Why this is here at all.** The first run walked the route with the
## room's five artillery live and the player died three times -- 360 hp
## taken -- during the approach and the stationary press at the door.
## A continuous interaction cannot survive a live arena, and a player
## would not try: they clear it. Nothing here is killed by a helper: the
## Static Pulse is held through `Input`, the body is walked on
## `move_forward`, and the guns die to the shots that land.
##
## **IN AMONG THE GUNS, WHICH IS THE ROLE'S OWN COUNTERPLAY.** Artillery
## "cannot depress" (`enemy.gd`): inside `ARTILLERY_MIN_RANGE` it has no
## answer at all. c002's battery stands in an arc before the exit, so the
## ground among it is ground none of it can shell. The second version
## fought from the entry instead -- strafing left and right, which walked
## the body back under shells aimed at where it had been, with the
## arena's cover block between it and the nearest gun eating 611 of 715
## frames' rays -- and lost the player twice in 11.9 s. A player who has
## read the room walks in among the guns and shoots them from there, and
## so does this: to the centre of the living battery, then each gun in
## turn, nearest first. The walk in costs whatever shells were already in
## the air; the stand costs none, and `widest` records that every gun
## was inside its own minimum range while the player stood there.
func _clear_room(controller: ZoneController, room: String,
		budget := 3600) -> Dictionary:
	var player: Player = controller.player
	var opened: float = player.hp
	_shots = 0
	_landed = 0
	player.fired_pulse.connect(_on_pulse)
	player.hit_confirmed.connect(_on_landed)
	var battery := _living_in(controller, room)
	# NOTHING TO FIGHT is an answer, not a walk to the world origin: the
	# centre of no guns is `Vector3.ZERO`.
	if battery.is_empty():
		player.fired_pulse.disconnect(_on_pulse)
		player.hit_confirmed.disconnect(_on_landed)
		return {"frames": 0, "left": 0, "guns": 0, "shots": 0, "landed": 0,
				"walked_in": 0.0, "hurt_walking": 0.0, "hurt_standing": 0.0,
				"widest": 0.0}
	var among := Vector3.ZERO
	for raw: Variant in battery:
		among += (raw as Node3D).global_position
	among = among / maxf(1.0, float(battery.size()))
	among.y = player.global_position.y
	var walk := await _walk_to(player, among, AABB(), 900, false, 1.0)
	var hurt_walking: float = opened - player.hp
	var widest := 0.0
	for raw: Variant in _living_in(controller, room):
		widest = maxf(widest, (raw as Node3D).global_position.distance_to(
				player.global_position))
	var frames := 0
	var strafe := "move_left"
	var strafing := false
	var still := 0
	var was := player.global_position
	Input.action_press("fire_pulse")
	while frames < budget:
		var alive := _living_in(controller, room)
		if alive.is_empty() or player._dead:
			break
		# THE GUN THAT CAN BE SEEN, nearest first. From the middle of the
		# battery the reward pedestal it guards stands in front of the
		# gun behind it -- 1,700 frames of rays into `Reward_89100076`
		# before this looked -- so the player shoots what is in sight and
		# steps sideways only when nothing is.
		alive.sort_custom(func(one: Node3D, two: Node3D) -> bool:
			return one.global_position.distance_to(player.global_position) \
					< two.global_position.distance_to(player.global_position))
		var sighted: Node3D = null
		for raw: Variant in alive:
			_aim_at(player, raw as Node3D)
			var ray := player.camera_ray(Constants.STATIC_PULSE_RANGE)
			if not ray.is_empty() and ray["collider"] == raw:
				sighted = raw
				break
		if sighted == null:
			_aim_at(player, alive[0] as Node3D)
			# Round the nearest gun, which keeps the body inside the
			# battery; the other way when a wall stops it.
			if not strafing:
				Input.action_press(strafe)
				strafing = true
			elif still > 20:
				Input.action_release(strafe)
				strafe = "move_right" if strafe == "move_left" \
						else "move_left"
				Input.action_press(strafe)
				still = 0
		elif strafing:
			Input.action_release(strafe)
			strafing = false
		_track_damage(player)
		await get_tree().physics_frame
		frames += 1
		still = still + 1 if strafing \
				and was.distance_to(player.global_position) < 0.02 else 0
		was = player.global_position
	Input.action_release(strafe)
	Input.action_release("fire_pulse")
	player.fired_pulse.disconnect(_on_pulse)
	player.hit_confirmed.disconnect(_on_landed)
	return {"frames": int(walk["frames"]) + frames,
			"left": _living_in(controller, room).size(),
			"guns": battery.size(), "shots": _shots, "landed": _landed,
			"walked_in": float(walk["walked"]),
			"hurt_walking": hurt_walking,
			"hurt_standing": opened - hurt_walking - player.hp,
			"widest": widest}


## A fight's own account of itself, for a message.
func _account(fight: Dictionary) -> String:
	return ("%d of %d down in %.1f s, %d shots / %d landed; walked in "
			% [int(fight["guns"]) - int(fight["left"]), int(fight["guns"]),
				float(fight["frames"]) * DT, int(fight["shots"]),
				int(fight["landed"])]
			+ "%.1f m for %.0f hp, stood with every gun within %.1f m "
			% [float(fight["walked_in"]), float(fight["hurt_walking"]),
				float(fight["widest"])]
			+ "(minimum range %.0f m) for %.0f hp"
			% [Constants.ARTILLERY_MIN_RANGE, float(fight["hurt_standing"])])


var _shots := 0
var _landed := 0
## What the verdict wait cost: how long the Zone held the player at its
## arrival, and the hp and place it released them with.
var _held_frames := 0
var _held_hp := 0.0
var _held_at := Vector3.ZERO


func _on_pulse() -> void:
	_shots += 1


func _on_landed(_killed: bool) -> void:
	_landed += 1


## THE ACCEPTANCE, in the owner's order, with the real body throughout.
func _the_route_is_played_end_to_end(zone_data: Dictionary,
		form: String) -> void:
	print("  -- the latched route, played from the Zone's own arrival: %s"
			% form)
	_deaths = 0
	_taken = 0.0
	BridgeClient.sent_intents.clear()
	var controller := await _enter(zone_data)
	var player: Player = controller.player
	_check(controller.layout_verdict != "" and player.holds().is_empty(),
			"the verdict wait is over (%s, no bridge) and the player is "
			% controller.layout_verdict + "free to act (holds %s)"
			% [player.holds()])
	# NOTHING ACTS ON A PLAYER THE VERDICT IS HOLDING. The first played
	# run lost 80 hp here, frozen at the arrival, to the battery in c002
	# -- `enemy._find_player`. Not vacuous: the guns can reach this spot.
	var reach := INF
	for record: Dictionary in controller._chambers:
		for raw: Variant in record["enemies"]:
			if is_instance_valid(raw):
				reach = minf(reach, (raw as Node3D).global_position
						.distance_to(_held_at))
	_check(_held_hp == Constants.PLAYER_MAX_HP,
			"HELD: the verdict held the player %.1f s at the arrival and "
			% (float(_held_frames) * DT) + "nothing acted on them "
			+ "(%.0f hp of %.0f)" % [_held_hp, Constants.PLAYER_MAX_HP])
	_check(reach >= Constants.ARTILLERY_MIN_RANGE
			and reach <= float(Constants.ENEMY_STATS["artillery"]["reach"]),
			"and the room's guns could reach that spot: nearest %.1f m, "
			% reach + "inside artillery's %.0f-%.0f m"
			% [Constants.ARTILLERY_MIN_RANGE,
				float(Constants.ENEMY_STATS["artillery"]["reach"])])
	_check(controller.signal_graph_refusals.is_empty(),
			"the declared graph built, nothing refused: %s"
			% [controller.signal_graph_refusals])
	if controller.signal_graphs.is_empty():
		await _drop(controller)
		return
	var graph: SignalGraph = controller.signal_graphs[0]
	var edge := _route_edge(zone_data)
	var room := graph.room_id
	# THE DOORWAY, FROM THE DECLARATION: the edge that names this
	# actuator, and the socket the room's own door plan assigned to it.
	var frame := RoomGraphs.doorway_frame(room, edge,
			zone_data.get("chambers", []) as Array, controller.door_frames)
	_check(not frame.is_empty(),
			"the edge '%s' resolves to a built doorway: %s/%s"
			% [str(edge.get("edge_id", "")), room,
				str(frame.get("socket_id", "?"))])
	if frame.is_empty():
		await _drop(controller)
		return
	var far_room := str(edge.get("room_b", "")) \
			if str(edge.get("room_a", "")) == room \
			else str(edge.get("room_a", ""))
	var sensor: Node3D = graph.sensors.values()[0]
	var lever := sensor as CallLever
	var plate := sensor as ClassPlate
	var declared_kind := _route_sensor_kind(zone_data)
	_check((declared_kind == "PULSE_BUTTON" and lever != null)
			or (declared_kind == "PRESSURE_PLATE" and plate != null),
			"the declared %s is BUILT AS %s" % [declared_kind,
				"A LEVER, a visibly permanent control" if lever != null
				else "A PLATE" if plate != null else "nothing it can use"])
	if lever == null and plate == null:
		await _drop(controller)
		return
	var binding: Dictionary = graph.actuators.values()[0]
	var shutter: ServiceShutter = binding["node"]
	var box: AABB = controller.room_bounds[room]
	var far_box: AABB = controller.room_bounds[far_room]
	var inward := _inward_of(frame, box)
	var door: Vector3 = frame["position"]

	# ---- PLACEMENT: across the named doorway, from its committed frame --
	var width := float(frame["width"])
	var height := float(frame["height"])
	_check(str(binding.get("gates", "")) == str(edge.get("edge_id", "")),
			"the shutter is bound to the edge that names it (%s)"
			% str(binding.get("gates", "")))
	_check(shutter.shut_at.distance_to(door + Vector3(0, height * 0.5, 0))
			< 0.05, "its centre is the doorway's own centre (%v vs door %v)"
			% [shutter.shut_at, door])
	_check(absf(angle_difference(shutter.rotation.y, float(frame["yaw"])))
			< 0.01, "it is turned to the socket's world yaw (%.1f deg)"
			% rad_to_deg(shutter.rotation.y))
	_check(shutter.panel.x >= width - 0.01
			and shutter.panel.y >= height - 0.01,
			"and it is the opening's full size (%v for a %.1f x %.1f door)"
			% [shutter.panel, width, height])
	if lever != null:
		_check(lever.locks_with == "held" and not lever.locked
				and lever.interact_prompt().begins_with("[E] THROW BOLT"),
				"it names what it does and what it sets: '%s', setting '%s'"
				% [lever.interact_prompt(), lever.locks_with])
	else:
		_check(plate.counts_player and plate.requires == MassClass.MEDIUM,
				"the plate is MEDIUM and counts the player, as saved")
	_check(_side_of(frame, inward, sensor.global_position) > 1.0,
			"the control is on this room's side of the door (%.1f m in)"
			% _side_of(frame, inward, sensor.global_position))
	_check(shutter.is_shut() and not graph.latched.has("held"),
			"and the route starts shut, unlatched")
	# THE OPENING IS STILL A HOLE TO THE LAYOUT PROBE, with the shut gate
	# standing in it: the evidence the bridge validates says `c002/exit`
	# is open, as a locked door's does. Without this the bridge refused
	# the live layout ("USED and the engine measured it as solid").
	var socket_ref := "%s/%s" % [room, str(frame.get("socket_id", ""))]
	_check(controller.measured_apertures.has(socket_ref)
			and bool(controller.measured_apertures[socket_ref]),
			"and the layout evidence reads %s as an opening, gate and all "
			% socket_ref + "(%s)" % [controller.measured_apertures.get(
				socket_ref, "unmeasured")])

	# ---- 1. ARRIVE THROUGH THE NORMAL ROUTE --------------------------
	var arrival := player.global_position
	var into := await _walk_into(controller, room)
	_check(box.has_point(player.global_position),
			"ARRIVE: from the Zone's own arrival %v, through %d connector "
			% [arrival, int(into["legs"]) - 1]
			+ "leg(s), into %s (%.1f m walked, %d frames)"
			% [room, float(into["walked"]), int(into["frames"])])

	# ---- 1b. THE ARENA IS CLEARED, because it is a `kill_all` room ----
	var hp_before := player.hp
	var fight := await _clear_room(controller, room)
	_check(int(fight["guns"]) > 0 and int(fight["left"]) == 0
			and _deaths == 0,
			"CLEAR: the arena is cleared with the base kit, no death: %s"
			% _account(fight))
	_note("the room's own fight cost %.0f hp of %.0f before the door "
			% [hp_before - player.hp, hp_before] + "was touched")
	# Let the bodies sink and free: a corpse is not an obstacle, and a
	# body that has not finished dying still has a collider for a frame.
	for _i in 60:
		await get_tree().physics_frame

	# ---- 2. THE DOORWAY IS BLOCKED BEFORE ACTIVATION -------------------
	# Up to the door WITHOUT touching the lever, then pressed straight at
	# a point beyond it with no steering at all.
	var front := door + inward * 1.4
	var up := await _walk_to(player, front, AABB(), 900, false, 0.5)
	_check(bool(up["arrived"]),
			"BLOCKED: walked up to the doorway (%.1f m from its face)"
			% _side_of(frame, inward, player.global_position))
	_check(not graph.latched.has("held") and (lever.pulls == 0
				if lever != null else not plate.satisfied()),
			"without touching the control on the way")
	var past := door - inward * 4.0
	await _press_toward(player, past, 150)
	var side := _side_of(frame, inward, player.global_position)
	_check(side > 0.0,
			"pressed at it for 2.5 s and did not get through (%.2f m on "
			% side + "this side)")
	_check(side < 1.0,
			"having reached the door itself, not stopped short (%.2f m)"
			% side)
	var ahead := player.camera_ray(2.5, -player.global_transform.basis.z)
	_check(not ahead.is_empty() and ahead.get("collider") == shutter,
			"and what it is pressed against is the route shutter (%s)"
			% ("nothing" if ahead.is_empty()
				else str((ahead["collider"] as Node).name)))

	var announced: Array[String] = []
	graph.fired.connect(func(_package: String, node: String) -> void:
			announced.append(node))
	if lever != null:
		await _throw_the_bolt(controller, graph, lever, front, announced)
	else:
		await _step_once_on_the_plate(controller, graph, plate, front,
				shutter, announced)

	# ---- 5. THROUGH THE ACTUAL DOORWAY INTO THE FAR ROOM ---------------
	var through := await _walk_into(controller, far_room)
	_check(far_box.has_point(player.global_position),
			"THROUGH: walked the doorway into %s (%.1f m, ended %v)"
			% [far_room, float(through["walked"]), player.global_position])
	_check(_side_of(frame, inward, player.global_position) < 0.0,
			"on the far side of the door plane (%.1f m past it)"
			% -_side_of(frame, inward, player.global_position))

	# ---- 6. AND BACK: the passage works both ways ----------------------
	await _walk_to(player, door, AABB(), 600, true, 0.8)
	var home := await _walk_to(player, front, box.grow(-0.5), 600, true, 0.5)
	_check(box.grow(-0.5).has_point(player.global_position),
			"BACK: walked back through the doorway into %s" % room)

	_check(_deaths == 0,
			"the player never died: a respawn would have broken the "
			+ "continuous interaction (%.1f hp taken in total)" % _taken)
	_note("latched route played (%s): arrival -> %s -> %s -> away -> %s -> "
			% [form, room, "lever" if lever != null else "plate", far_room]
			+ "back, %.1f hp taken in total, %d death(s)"
			% [_taken, _deaths])
	await _drop(controller)


## Steps 3 and 4, D-07's form: the lever, thrown with the interact ray,
## stays thrown; walking away changes nothing; a second pull does nothing.
func _throw_the_bolt(controller: ZoneController, graph: SignalGraph,
		lever: CallLever, front: Vector3, announced: Array[String]) -> void:
	var player: Player = controller.player
	var shutter: ServiceShutter = (graph.actuators.values()[0]
			as Dictionary)["node"]
	# ---- 3. THROW THE BOLT: the lever, pulled with the interact ray ------
	var thrown := await _throw(controller, lever)
	_check(thrown and lever.pulls == 1,
			"THROW: the player's own interact pulls the lever (%d pull(s))"
			% lever.pulls)
	_check(graph.latched.has("held"), "the latch is set")
	_check(announced.size() == 1,
			"and announced once as a new decision (%d)" % announced.size())
	var reports := _latch_reports()
	var report: Dictionary = reports.back() if not reports.is_empty() else {}
	_check(reports.size() == 1
			and str(report.get("package_id", "")) == "graph_%s" % graph.room_id
			and str(report.get("latch_id", "")) == "held"
			and str(report.get("zone_id", "")) == controller.zone_id,
			"the real `latch_fired` went out: %s" % [report])
	_check(shutter.goal >= shutter.travel - 0.01,
			"and the shutter is commanded open")
	# D-07: IT LOOKS PERMANENT BECAUSE IT IS. The arm stays thrown and the
	# prompt says what it did; a plate that silently stayed "pressed" is
	# what the owner rejected.
	for _i in 60:
		await get_tree().physics_frame
	_check(lever.locked and lever.swing() >= 0.99
			and not lever.interact_prompt().begins_with("[E]"),
			"the lever STAYS THROWN and says so: '%s' (arm %.2f)"
			% [lever.interact_prompt(), lever.swing()])

	# ---- 4. WALK AWAY: the latch holds, and a second pull does nothing --
	await _walk_to(player, front, AABB(), 600, false, 0.5)
	_check(graph.latched.has("held") and bool(graph.values.get("held")),
			"the latch still holds")
	var opened := await _wait_for(func() -> bool: return shutter.is_open(),
			300)
	_check(opened, "the way opens fully, with nobody at the lever "
			+ "(openness %.2f)" % shutter.openness())
	lever.interact(player)
	await _settle_frames(10)
	_check(lever.pulls == 1 and _latch_reports().size() == 1,
			"and pulling it again does nothing: %d pull(s), %d report(s)"
			% [lever.pulls, _latch_reports().size()])


## Steps 3 and 4, the LEGACY form (M-1: "Existing saved Zones containing
## the old step-once route retain their saved behavior"): one step on the
## plate sets the latch, and stepping fully off leaves the way open.
func _step_once_on_the_plate(controller: ZoneController, graph: SignalGraph,
		plate: ClassPlate, front: Vector3, shutter: ServiceShutter,
		announced: Array[String]) -> void:
	var player: Player = controller.player
	# ---- 3. STEP ON THE PLAYER-ENABLED PLATE ---------------------------
	await _walk_to(player, plate.global_position, AABB(), 900, false, 0.3)
	var on := await _wait_for(func() -> bool: return plate.satisfied(), 60)
	_check(on and _player_on(plate, player),
			"STEP ON: the player's own body satisfies the plate (%s)"
			% [plate.reading()])
	_check(graph.latched.has("held"), "the latch is set")
	_check(announced.size() == 1,
			"and announced once as a new decision (%d)" % announced.size())
	var reports := _latch_reports()
	var report: Dictionary = reports.back() if not reports.is_empty() else {}
	_check(reports.size() == 1
			and str(report.get("package_id", "")) == "graph_%s" % graph.room_id
			and str(report.get("latch_id", "")) == "held"
			and str(report.get("zone_id", "")) == controller.zone_id,
			"the real `latch_fired` went out: %s" % [report])
	_check(shutter.goal >= shutter.travel - 0.01,
			"and the shutter is commanded open")

	# ---- 4. STEP FULLY OFF: the sensor releases, the latch holds ------
	await _walk_to(player, front, AABB(), 600, false, 0.5)
	var off := await _wait_for(func() -> bool:
			return not _player_on(plate, player) and not plate.satisfied(),
			60)
	_check(off, "STEP OFF: the body is out of the plate's sensing volume "
			+ "and the plate reads empty (%s)" % [plate.reading()])
	_check(graph.latched.has("held") and bool(graph.values.get("held")),
			"the latch still holds")
	var opened := await _wait_for(func() -> bool: return shutter.is_open(),
			300)
	_check(opened, "the way opens fully with nobody on the plate "
			+ "(openness %.2f)" % shutter.openness())
	_check(_latch_reports().size() == 1,
			"and stepping off reported nothing new")


## THE CONTROL, AND V-08: THE SAME ROOM, AN ORDINARY PLATE, NO LATCH.
##
## D-07: "Pressure plates are held sensors. Pressure present = active.
## Pressure removed = inactive." Whatever the route's control is, it is
## replaced here by an ordinary plate that counts the player, driving
## the shutter with no latch between.
##
## The plate drives the shutter directly, so the way is open only while
## somebody stands on the plate -- D-8 §11.2's held requirement, which the
## bridge refuses as a route and which is built here only to show what
## the latch is for. Step on, step off, and the door must SHUT again; the
## walk through must fail. If this passed, the acceptance above would be
## proving the shutter and not the latch.
func _without_the_latch_the_route_does_not_hold(zone_data: Dictionary) -> void:
	print("  -- control: the latch removed, the route does not hold")
	var held_zone: Dictionary = zone_data.duplicate(true)
	var graphs: Array = held_zone.get("room_graphs", []) as Array
	var declared: Dictionary = graphs[0]
	var plate_id := "step_plate"
	declared["sensors"] = [{"node_id": plate_id, "kind": "PRESSURE_PLATE",
			"requires_class": "MEDIUM", "counts_player": true}]
	declared["nodes"] = []
	for raw: Variant in declared["actuators"] as Array:
		(raw as Dictionary)["driven_by"] = plate_id
	_deaths = 0
	_taken = 0.0
	var controller := await _enter(held_zone)
	var player: Player = controller.player
	if controller.signal_graphs.is_empty():
		_check(false, "the control's graph built: %s"
				% [controller.signal_graph_refusals])
		await _drop(controller)
		return
	var graph: SignalGraph = controller.signal_graphs[0]
	var edge := _route_edge(held_zone)
	var room := graph.room_id
	var frame := RoomGraphs.doorway_frame(room, edge,
			held_zone.get("chambers", []) as Array, controller.door_frames)
	var far_room := str(edge.get("room_b", "")) \
			if str(edge.get("room_a", "")) == room \
			else str(edge.get("room_a", ""))
	var plate: ClassPlate = graph.sensors.values()[0]
	var shutter: ServiceShutter = (graph.actuators.values()[0]
			as Dictionary)["node"]
	var box: AABB = controller.room_bounds[room]
	var far_box: AABB = controller.room_bounds[far_room]
	var inward := _inward_of(frame, box)
	var front: Vector3 = (frame["position"] as Vector3) + inward * 1.4
	await _walk_into(controller, room)
	var fight := await _clear_room(controller, room)
	_check(int(fight["guns"]) > 0 and int(fight["left"]) == 0
			and _deaths == 0,
			"CONTROL: the arena is cleared the same way: %s"
			% _account(fight))
	for _i in 60:
		await get_tree().physics_frame
	await _walk_to(player, plate.global_position, AABB(), 900, false, 0.3)
	var on := await _wait_for(func() -> bool: return plate.satisfied(), 60)
	_check(on, "CONTROL: standing on the plate satisfies it")
	# NOT VACUOUS: the plate drives the door directly here, so standing on
	# it must open the way. A control whose door never opened would pass
	# "it shuts again" without ever having tested the latch's absence.
	var opened := await _wait_for(
			func() -> bool: return shutter.openness() > 0.5, 300)
	_check(on and opened,
			"CONTROL: and while the player stands there the way opens "
			+ "(openness %.2f)" % shutter.openness())
	await _walk_to(player, front, AABB(), 600, false, 0.5)
	await _wait_for(func() -> bool: return not plate.satisfied(), 60)
	# Give the door every chance: longer than it takes to open.
	for _i in 240:
		await get_tree().physics_frame
	_check(opened and not shutter.is_open() and shutter.goal <= 0.01,
			"CONTROL: with nothing to hold it, stepping off shuts the way "
			+ "again (goal %.2f, openness %.2f)"
			% [shutter.goal, shutter.openness()])
	await _walk_into(controller, far_room)
	var ended := player.global_position
	var door: Vector3 = frame["position"]
	var short := Vector2(ended.x - door.x, ended.z - door.z).length()
	# AT THE DOOR, not merely somewhere other than c003: a walk that died
	# or wandered off would also be "not in c003".
	_check(opened and _deaths == 0 and not far_box.has_point(ended)
			and _side_of(frame, inward, ended) > 0.0 and short < 2.5,
			"CONTROL: and the walk into %s is stopped at the door "
			% far_room + "(ended %v, %.1f m from it, this side, %d death(s))"
			% [ended, short, _deaths])
	await _drop(controller)


## The kind of the route's one sensor, as the Zone declares it.
func _route_sensor_kind(zone_data: Dictionary) -> String:
	var graphs: Array = zone_data.get("room_graphs", []) as Array
	if graphs.is_empty():
		return ""
	var sensors: Array = (graphs[0] as Dictionary).get("sensors", []) as Array
	return "" if sensors.is_empty() \
			else str((sensors[0] as Dictionary).get("kind", ""))


## THE SAME ROUTE WITH ITS ONE SENSOR SWAPPED, and nothing else touched:
## the room, the doorway, the LATCH and the shutter are the Zone's own.
## A test declaration, said so -- `PULSE_BUTTON` is D-07's lever,
## `PRESSURE_PLATE` the legacy step-once plate a saved Zone may still
## hold (M-1). Which one the composer writes is the bridge's to decide.
func _with_route_sensor(zone_data: Dictionary, kind: String) -> Dictionary:
	var out: Dictionary = zone_data.duplicate(true)
	var declared: Dictionary = (out["room_graphs"] as Array)[0]
	var old_id := str(((declared["sensors"] as Array)[0]
			as Dictionary)["node_id"])
	var new_id := "route_lever" if kind == "PULSE_BUTTON" else "route_plate"
	declared["sensors"] = [{"node_id": new_id, "kind": kind}] \
			if kind == "PULSE_BUTTON" else [{"node_id": new_id,
				"kind": kind, "requires_class": "MEDIUM",
				"counts_player": true}]
	for raw: Variant in declared.get("nodes", []) as Array:
		var node: Dictionary = raw
		var inputs: Array = node.get("inputs", []) as Array
		for i in inputs.size():
			if str(inputs[i]) == old_id:
				inputs[i] = new_id
	return out


## Walk to the lever, look at its top, and press the real `interact`.
func _throw(controller: ZoneController, lever: CallLever) -> bool:
	var player := controller.player
	# INTO THE BASE, the collider the interact probe finds: a point inside
	# it, so the ray meets its surface on the way whatever the angle.
	var top := lever.global_position + Vector3(0.0, CallLever.BASE.y * 0.25,
			0.0)
	var flat := Vector3(top.x - player.global_position.x, 0.0,
			top.z - player.global_position.z)
	var goal := top - flat.normalized() * 1.3
	goal.y = player.global_position.y
	await _walk_to(player, goal, AABB(), 900, false, 0.35)
	# COME TO A STOP FIRST, then hold the aim until the interact ray has
	# the lever: an aim taken while the body still slides is gone by the
	# press (`transport_driver._approach`, the same lesson).
	for _i in 60:
		if Vector2(player.velocity.x, player.velocity.z).length() < 0.05:
			break
		await get_tree().physics_frame
	for _i in 30:
		_aim(player, top)
		await get_tree().physics_frame
		if player._interact_target == lever:
			break
	if player._interact_target != lever:
		print("    (the lever at %s is not under the ray from %s, %.2f m: "
				% [top, player.global_position,
					player.global_position.distance_to(top)]
				+ "target %s)" % [player._interact_target])
	var before := lever.pulls
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("interact")
	await _settle_frames(4)
	return lever.pulls > before


func _aim(player: Player, point: Vector3) -> void:
	var to := point - player.camera.global_position
	if to.length() < 0.01:
		return
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.camera.rotation.y = 0.0


func _settle_frames(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _finish() -> void:
	if failures == 0:
		print("GODOT LATCHED ROUTE TESTS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT LATCHED ROUTE TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
