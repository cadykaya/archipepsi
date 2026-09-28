class_name RoomPlaytestCheck
extends Node
## THE CONCOURSE-PIER PLAYTEST, CHECKED IN THE REAL GAME
## (`make godot-concourse-pier`).
##
##   godot --headless --path godot -- --concourse-pier --concourse-pier-check
##   godot --headless --path godot -- --concourse-pier --populated \
##       --concourse-pier-check
##
## Beside the real `Main`, like the reload proof: the Zone, the `Player`,
## the pause menu and the exit are the ones a tester gets, and the player
## is moved only by pressing what a tester presses (steer, walk, aim,
## fire, interact). Walks never jump; a body that stops making progress
## fails the walk. Sight lines are measured by ray, from the ranged
## enemy's own muzzle, without moving anyone.
##
## Room-local points are the registry's frame (x across, y the standing
## surface, z from the entry wall) and go through the shell's own
## transform, so the check follows the room wherever `ZoneBuilder` put it.

const FLAG := "--concourse-pier-check"
const STILL_STEP := 0.012
const STUCK_FRAMES := 30
const ARRIVE := 0.6

## The floor route (Arty's): in through the entrance, down the exit-side
## lane, out through the exit.
const FLOOR_ROUTE := [Vector3(0.0, 0.0, 2.5), Vector3(5.8, 0.0, 5.5),
	Vector3(5.8, 0.0, 19.0), Vector3(4.8, 0.0, 21.0)]
## The upper loop (Arty's): stair A up the right wall to the gallery, the
## bridge, the pier, stair B down to the landing beside the exit.
const UPPER_LOOP := [Vector3(-3.8, 0.0, 13.5), Vector3(-6.8, 0.0, 13.0),
	Vector3(-6.8, 3.5, 3.0), Vector3(1.2, 3.5, 2.6), Vector3(1.2, 3.5, 9.0),
	Vector3(2.4, 3.5, 12.4), Vector3(2.4, 0.0, 20.6), Vector3(4.8, 0.0, 21.0)]
## Where a player can stand, for the ranged enemy's sight lines.
const SIGHT_POINTS := {
	"entrance, under the gallery": Vector3(0.0, 0.0, 2.0),
	"just past the gallery": Vector3(0.0, 0.0, 5.0),
	"exit lane, near": Vector3(5.8, 0.0, 6.0),
	"exit lane, beside the pier": Vector3(5.8, 0.0, 10.5),
	"exit lane, against the pier": Vector3(4.2, 0.0, 10.5),
	"exit lane, far": Vector3(5.8, 0.0, 18.0),
	"stair lane, beside the pier": Vector3(-3.8, 0.0, 10.5),
	"stair lane, far": Vector3(-4.0, 0.0, 17.0),
	"exit landing": Vector3(4.8, 0.0, 20.5),
	"gallery": Vector3(-3.0, 3.5, 2.0),
	"bridge": Vector3(1.2, 3.5, 6.0),
}

var main: Node
var failures := 0


static func requested() -> bool:
	return FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in 4:
		await get_tree().physics_frame
	await _run()
	print("[pier] %s -- %d failure(s)"
			% ["PASS" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[pier]   ok    " + what)
	else:
		failures += 1
		print("[pier]   FAIL  " + what)


func _note(what: String) -> void:
	print("[pier]   note  " + what)


func _run() -> void:
	var populated := RoomPlaytest.populated_requested()
	print("[pier] mode: %s" % ("populated" if populated else "empty"))
	_isolated_and_pending()
	var shell := _built()
	if shell == null:
		return
	_lights(shell)
	var zone: ZoneController = main.zone
	_check(zone._exit_portal != null and zone._exit_portal.unlocked,
			"the exit portal is open on entry, before anything is killed "
			+ "(the Zone holds no Checks)")
	for record: Dictionary in zone._chambers:
		_check(str(record["objective"]) == RoomPlaytest.OBJECTIVE,
				"%s's objective is %s, as in the other mode"
				% [str(record["chamber"].get("id", "?")), record["objective"]])
	var body: Player = zone.player
	_check(body != null and _room_local(shell, body.global_position).z < -1.0,
			"the player starts in the approach, outside the room")
	if populated:
		await _encounter(zone, shell, body)
	else:
		_check(await _approach(zone, shell, body),
				"the approach -- corridor, connector, corner -- walks into "
				+ "the room through its entrance")
		await _empty(zone, shell, body)
	await _menu()
	_settings_stay_unwritten()
	_check(not BridgeClient.online and not BridgeClient.is_processing()
			and BridgeClient.isolated,
			"after all of it, still never connected (every intent raised, "
			+ "%d, was dropped offline)" % BridgeClient.sent_total)


## Isolation and the catalogue, before anything else.
func _isolated_and_pending() -> void:
	_check(BridgeClient.isolated and not BridgeClient.online
			and not BridgeClient.is_processing()
			and BridgeClient._socket.get_ready_state()
				== WebSocketPeer.STATE_CLOSED,
			"the launch never opened a bridge socket and retries none")
	var text := FileAccess.get_file_as_string(
			"res://content/registry/authored_art.json")
	var parsed: Variant = JSON.parse_string(text)
	var on_disk := {}
	if typeof(parsed) == TYPE_DICTIONARY:
		for raw: Variant in (parsed as Dictionary).get("entries", []):
			if typeof(raw) == TYPE_DICTIONARY \
					and str((raw as Dictionary).get("id", "")) \
						== RoomPlaytest.SHELL_ID:
				on_disk = raw
	var spawns := 0
	for volume: Variant in on_disk.get("volumes", []):
		if str((volume as Dictionary).get("kind", "")) == "enemy_spawn":
			spawns += 1
	_check(str(on_disk.get("review", "")) == "pending" and spawns == 0
			and not VisualOwnership.is_shippable(on_disk),
			"the catalogue on disk still says pending, with no spawns: "
			+ "the load exception lives in this process's memory only")
	_check(VisualOwnership.is_shippable(ContentRegistry.shared().get_entry(
			RoomPlaytest.SHELL_ID)),
			"and in memory, for this launch, the one room is admitted")


func _built() -> Node3D:
	var zone: ZoneController = main.zone
	_check(main.view == 2 and zone != null
			and zone.zone_id == RoomPlaytest.ZONE_ID
			and zone.layout_failed == "",
			"the playtest Zone is built and entered")
	var shell := RoomPlaytest.shell_root(zone)
	_check(shell != null and shell.scene_file_path.ends_with(
			"shell_concourse_pier.tscn"),
			"the ACTUAL shell_concourse_pier scene is built, not the "
			+ "procedural substitute")
	return shell


## The same three lights in both modes, where the plan puts them.
func _lights(shell: Node3D) -> void:
	var lights: Array = []
	for n: Node in shell.find_children("*", "OmniLight3D", true, false):
		lights.append(n)
	var size: Array = ContentRegistry.shared().get_entry(
			RoomPlaytest.SHELL_ID).get("size", [])
	var want := RoomPlaytest.light_plan(float(size[0]) - 0.8,
			float(size[2]) - 0.8, RoomPlaytest.INTERIOR_HEIGHT)
	var matched := 0
	for spec: Array in want:
		for light: OmniLight3D in lights:
			if light.position.distance_to(spec[0]) < 0.01 \
					and is_equal_approx(light.omni_range, float(spec[1])):
				matched += 1
	_check(lights.size() == want.size() and matched == want.size(),
			"%d lights in the room, all at the planned places" % lights.size())


## From the spawn to just inside the room: the corridor, the connector
## and the corner the builder laid, then through the entry doorway.
func _approach(zone: ZoneController, shell: Node3D, body: Player) -> bool:
	var connector := zone.find_child("Connector", true, false) as Node3D
	if connector == null:
		return false
	if not await _walk(body, connector.global_position):
		return false
	return await _walk_route(body, shell, [Vector3(0.0, 0.0, -2.0),
			Vector3(0.0, 0.0, 2.5)])


func _empty(zone: ZoneController, shell: Node3D, body: Player) -> void:
	# THE FLOOR ROUTE.
	var ok: bool = await _walk_route(body, shell, FLOOR_ROUTE)
	_check(ok, "the floor route walks through the room to the exit doorway, "
			+ "no jumps, no stalls")
	# COLLISION, the control: back up the exit lane, under the bridge, and
	# straight at the pier's face.
	await _walk_route(body, shell, [Vector3(5.8, 0.0, 19.0),
			Vector3(5.8, 0.0, 6.0), Vector3(0.8, 0.0, 6.0)])
	var stopped := not await _walk(body, _world(shell, Vector3(0.8, 0.0,
			10.5)))
	var at := _room_local(shell, body.global_position)
	_check(stopped and at.z < 8.0 and at.z > 6.5,
			"walking into the pier stops at its face (z %.2f; face 8.0)"
			% at.z)
	# THE UPPER LOOP, optional, and still walkable: round to the stair lane
	# under the bridge, then stair A.
	await _walk_route(body, shell, [Vector3(0.8, 0.0, 6.0),
			Vector3(-3.8, 0.0, 6.5)])
	var high: float = await _walk_route(body, shell, UPPER_LOOP, true)
	_check(high >= 3.4, "the upper loop walks: stair A, gallery, bridge, "
			+ "pier, stair B, to the exit (highest standing %.2f m)" % high)
	await _exit_resets(body)


## POPULATED: placement, sight, movement, attacks both ways, the stairs,
## and leaving with the encounter alive. Two passes of the route: the
## first fights, the second walks the upper loop with both enemies alive
## and leaves.
func _encounter(zone: ZoneController, shell: Node3D, body: Player) -> void:
	var pair := _pair(zone)
	var ranged: Enemy = pair[0]
	var walker: Enemy = pair[1]
	_check(ranged != null and walker != null and _enemies(zone).size() == 2,
			"two enemies: one ranged and one melee (%d)" % _enemies(zone).size())
	if ranged == null or walker == null:
		return
	# PLACEMENT, on entry, before the player has moved.
	var ranged_at := _room_local(shell, ranged.global_position)
	var walker_at := _room_local(shell, walker.global_position)
	_check(ranged_at.y > 3.3 and Rect2(-2.0, 8.0, 5.6, 5.0).has_point(
			Vector2(ranged_at.x, ranged_at.z)),
			"the ranged enemy stands on the pier top (%s)" % _v(ranged_at))
	_check(walker_at.y < 0.3 and walker_at.z > 13.0,
			"the melee enemy stands on the floor behind the pier (%s)"
			% _v(walker_at))
	# SIGHT LINES, from the ranged enemy's own muzzle.
	var seen: Array = []
	var hidden: Array = []
	var answer: Array = []
	for name: String in SIGHT_POINTS:
		var point := _world(shell, SIGHT_POINTS[name])
		if _clear(ranged, point + Vector3.UP * 1.0):
			seen.append(name)
			# And can the player at that spot hit it back? From the eye.
			if _clear_to(point + Vector3.UP * 1.6, ranged):
				answer.append(name)
		else:
			hidden.append(name)
	_note("the ranged enemy SEES: %s" % ", ".join(seen))
	_note("and does NOT see: %s" % ", ".join(hidden))
	_note("of the spots it sees, the player can shoot back from: %s"
			% (", ".join(answer) if not answer.is_empty() else "none"))
	_check(not seen.is_empty() and not hidden.is_empty(),
			"the pier top covers some of the room and not all of it")
	_check(not answer.is_empty(), "somewhere it can be fought from")
	# THE WALK IN, and the melee's route to the player.
	var hits := {"melee": 0, "ranged": 0}
	var on_hit := func(source: Vector3) -> void:
		var by := "melee" if is_instance_valid(walker) \
				and source.distance_to(walker.global_position) < 3.0 \
				else "ranged"
		hits[by] += 1
	body.damaged_from.connect(on_hit)
	var path := {"lanes": {}, "closest": INF}
	var follow := func() -> void:
		while is_instance_valid(walker) and not walker._dead \
				and is_instance_valid(body) and main.view == 2:
			var at := _room_local(shell, walker.global_position)
			if at.z > 7.5 and at.z < 13.5:
				path["lanes"]["exit side" if at.x > 3.6 else "stair side" \
						if at.x < -2.0 else "?"] = true
			path["closest"] = minf(path["closest"],
					walker.global_position.distance_to(body.global_position))
			await get_tree().physics_frame
	follow.call()
	var hp0 := body.hp
	await _approach(zone, shell, body)
	# Wait for it in the exit lane, out of the ranged enemy's sight, so the
	# melee is measured on its own.
	await _walk(body, _world(shell, Vector3(5.8, 0.0, 6.0)))
	for _i in int(10.0 * Engine.physics_ticks_per_second):
		if hits["melee"] > 0:
			break
		await get_tree().physics_frame
	_note("the melee came round the pier by the %s lane(s); closest %.1f m"
			% [", ".join(path["lanes"].keys()), path["closest"]])
	_check(path["closest"] < 2.6 and hits["melee"] > 0,
			"the melee reaches the player round the pier, and its strikes "
			+ "land (%d; hp %.0f -> %.0f)" % [hits["melee"], hp0, body.hp])
	# THE PLAYER'S ANSWER: the melee first, from where the player stands.
	var killed_walker := await _shoot(body, walker, 10.0)
	_check(killed_walker, "the Static Pulse kills the melee where it stands "
			+ "(%d strikes taken first)" % hits["melee"])
	# THE RANGED: step out past the gallery, where it can see the player.
	await _walk_route(body, shell, [Vector3(0.8, 0.0, 6.0),
			Vector3(0.0, 0.0, 5.0)])
	# Counted from standing still: a shot's aim is fixed when its telegraph
	# starts, so shots begun while the player walked are not this test.
	var shots_before := _projectiles_seen
	var ranged_hits_before: int = hits["ranged"]
	for _i in int(6.0 * Engine.physics_ticks_per_second):
		_count_projectiles()
		await get_tree().physics_frame
	_check(_projectiles_seen > shots_before
			and hits["ranged"] > ranged_hits_before,
			"from the pier top the ranged enemy fires on the player past "
			+ "the gallery, and hits (%d shots, %d hits)"
			% [_projectiles_seen - shots_before,
			hits["ranged"] - ranged_hits_before])
	var from_floor := "just past the gallery" in answer \
			or "entrance, under the gallery" in answer
	if from_floor and not "just past the gallery" in answer:
		await _walk(body, _world(shell, SIGHT_POINTS[
				"entrance, under the gallery"]))
	elif not from_floor:
		# Up to the bridge by the upper loop: the only answer to the turret.
		await _walk_route(body, shell, [Vector3(-3.8, 0.0, 5.0),
				Vector3(-3.8, 0.0, 13.5)] + UPPER_LOOP.slice(1, 4)
				+ [Vector3(1.2, 3.5, 6.0)])
	var killed_ranged := await _shoot(body, ranged, 12.0)
	_check(killed_ranged, "and the Static Pulse kills it from %s"
			% ("the floor at the entrance" if from_floor
			else "the bridge, up the loop"))
	_note("first pass: hp %.0f -> %.0f; melee strikes %d, ranged hits %d"
			% [hp0, body.hp, hits["melee"], hits["ranged"]])
	if from_floor:
		await _walk_route(body, shell, FLOOR_ROUTE.slice(1))
	else:
		await _walk_route(body, shell, UPPER_LOOP.slice(4))
	await _exit_resets(body)
	# SECOND PASS, both alive: the stairs, and leaving without a kill.
	zone = main.zone
	shell = RoomPlaytest.shell_root(zone)
	body = zone.player
	pair = _pair(zone)
	ranged = pair[0]
	walker = pair[1]
	_check(ranged != null and walker != null,
			"the reset brought both enemies back")
	if ranged == null or walker == null:
		return
	var track := {"top": 0.0, "on": true}
	var climb := func() -> void:
		while track["on"] and is_instance_valid(walker) \
				and is_instance_valid(body) and main.view == 2:
			track["top"] = maxf(track["top"],
					_room_local(shell, walker.global_position).y)
			await get_tree().physics_frame
	climb.call()
	var hp1 := body.hp
	await _approach(zone, shell, body)
	await _walk_route(body, shell, [Vector3(-3.8, 0.0, 5.0),
			Vector3(-3.8, 0.0, 13.5)])
	var high: float = await _walk_route(body, shell, UPPER_LOOP.slice(1, 4),
			true)
	await _hold(3.0)
	track["on"] = false
	var walker_top: float = track["top"]
	var below := _room_local(shell, walker.global_position) \
			if is_instance_valid(walker) else Vector3.ZERO
	_note("with the player on the gallery (%.2f m), the melee's highest "
			% high + "footing was %.2f m; it waits at %s" % [walker_top,
			_v(below)])
	if walker_top < 1.0:
		_note("LIMITATION: the melee does not follow up the stairs (direct "
				+ "steering, no navmesh); the upper loop is out of its reach")
	var rest: float = await _walk_route(body, shell, UPPER_LOOP.slice(4),
			true)
	_check(rest >= 3.4 and is_instance_valid(ranged) and not ranged._dead
			and is_instance_valid(walker) and not walker._dead,
			"the loop continues over the pier past the live ranged enemy, "
			+ "down stair B, with both enemies still alive")
	_note("second pass: hp %.0f -> %.0f" % [hp1, body.hp])
	await _exit_resets(body)


## [ranged, melee] in a Zone, or nulls.
func _pair(zone: ZoneController) -> Array:
	var ranged: Enemy = null
	var walker: Enemy = null
	for enemy: Enemy in _enemies(zone):
		if enemy.archetype == "ranged":
			ranged = enemy
		elif enemy.archetype == "melee":
			walker = enemy
	return [ranged, walker]


var _projectiles_seen := 0
var _projectile_ids := {}


var _last_at := {}


func _count_projectiles() -> void:
	var alive := {}
	for n: Node in get_tree().current_scene.get_children():
		if n is Enemy.EnemyProjectile:
			alive[n.get_instance_id()] = true
			_last_at[n.get_instance_id()] = (n as Node3D).global_position
			if not _projectile_ids.has(n.get_instance_id()):
				_projectile_ids[n.get_instance_id()] = true
				_projectiles_seen += 1
	for id: int in _last_at.keys():
		if not alive.has(id):
			_last_at.erase(id)


func _enemies(zone: ZoneController) -> Array:
	var out: Array = []
	for n: Node in zone.find_children("*", "", true, false):
		if n is Enemy and not (n as Enemy)._dead:
			out.append(n)
	return out


## A clear line from the enemy's muzzle to `point`, as its own sight test
## draws one.
func _clear(enemy: Enemy, point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(enemy.muzzle(), point)
	query.exclude = [enemy.get_rid()]
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["collider"] is Player)


## A clear line from `from` to the enemy's body, as the player's shot
## would draw one.
func _clear_to(from: Vector3, enemy: Enemy) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, enemy.body_centre())
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == enemy


## The exit portal, walked to and used: the route starts again.
func _exit_resets(body: Player) -> void:
	var before: ZoneController = main.zone
	var before_id := before.get_instance_id()
	var portal: Node3D = before._exit_portal
	await _walk(body, portal.global_position, 1.8)
	for _i in 90:
		if not is_instance_valid(main.zone) \
				or main.zone.get_instance_id() != before_id:
			break
		if not is_instance_valid(body):
			break
		_aim(body, portal.global_position + Vector3.UP * 1.2)
		if _i % 10 == 0:
			Input.action_press("interact", 1.0)
		elif _i % 10 == 2:
			Input.action_release("interact")
		await get_tree().physics_frame
	Input.action_release("interact")
	for _i in 6:
		await get_tree().physics_frame
	_reset_is_fresh(before_id, "the exit portal")


func _reset_is_fresh(before_id: int, how: String) -> void:
	var zone: ZoneController = main.zone
	var shell := RoomPlaytest.shell_root(zone)
	_check(main.view == 2 and zone != null
			and zone.get_instance_id() != before_id
			and zone.zone_id == RoomPlaytest.ZONE_ID and shell != null
			and zone.player != null
			and _room_local(shell, zone.player.global_position).z < -1.0,
			"%s starts the route again: a fresh Zone, the actual room, the " % how
			+ "player back in the approach")
	if shell != null:
		_lights(shell)


## RESUME, RETURN TO HUB and ABANDON, through the real pause menu.
func _menu() -> void:
	if main.view != 2:
		return
	await _pause()
	var pause: PauseMenu = main.pause_menu
	_check(main.menu_shell.is_open() and PauseMenu.RESUME in pause.switches()
			and PauseMenu.RETURN_TO_HUB in pause.switches()
			and PauseMenu.QUIT in pause.switches(),
			"pause opens the menu (%s)" % ", ".join(pause.switches()))
	pause.press(PauseMenu.RESUME)
	await get_tree().process_frame
	_check(not main.menu_shell.is_open() and main.view == 2,
			"RESUME closes it and play continues")
	var before_id: int = main.zone.get_instance_id()
	await _pause()
	pause.press(PauseMenu.RETURN_TO_HUB)
	for _i in 6:
		await get_tree().process_frame
	_reset_is_fresh(before_id, "RETURN TO HUB")
	before_id = main.zone.get_instance_id()
	await _pause()
	pause.press(PauseMenu.ABANDON)
	await get_tree().create_timer(PauseMenu.ARM_GUARD + 0.1).timeout
	pause.press(PauseMenu.CONFIRM)
	for _i in 6:
		await get_tree().process_frame
	_reset_is_fresh(before_id, "ABANDON, confirmed,")
	_check(not main.menu_shell.is_open(), "and the menu is closed after it")


## The player's own files are read, never written, in this launch.
## (`make godot-concourse-pier` compares their bytes before and after.)
func _settings_stay_unwritten() -> void:
	var settings := PlayerSettings.shared()
	var fov := settings.value("field_of_view")
	settings.set_value("field_of_view", fov + 1.0)
	settings.save_to_disk()
	settings.set_value("field_of_view", fov)
	Favourites._save()
	EquipmentSeen._save()
	_note("a setting was changed and every save path called; the files "
			+ "must be byte-identical afterwards")


## The pause key, and the frames `_unhandled_input` needs to see it.
func _pause() -> void:
	_press_pause()
	for _i in 3:
		await get_tree().process_frame


func _press_pause() -> void:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = "pause"
	up.pressed = false
	Input.parse_input_event(up)


## Aim the camera at an enemy and fire until it dies or time runs out,
## from where the player stands: nothing is moved.
func _shoot(body: Player, target: Enemy, seconds: float) -> bool:
	for _i in int(seconds * Engine.physics_ticks_per_second):
		if not is_instance_valid(target) or target._dead:
			Input.action_release("fire_pulse")
			return true
		if not is_instance_valid(body):
			break
		_aim(body, target.body_centre())
		if _i % 20 == 0:
			Input.action_press("fire_pulse", 1.0)
		elif _i % 20 == 3:
			Input.action_release("fire_pulse")
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	return not is_instance_valid(target) or target._dead


func _aim(body: Player, at: Vector3) -> void:
	var eye := body.camera.global_position
	var flat := Vector2(at.x - eye.x, at.z - eye.z)
	body.rotation.y = atan2(-flat.x, -flat.y)
	body.camera.rotation.x = atan2(at.y - eye.y, flat.length())


func _hold(seconds: float) -> void:
	for _i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## Walk each room-local point in turn. With `height`, returns the highest
## room-local standing height reached (or -1.0 on a stall); else whether
## every point was reached.
func _walk_route(body: Player, shell: Node3D, points: Array,
		height := false) -> Variant:
	var high := 0.0
	for local: Vector3 in points:
		if not await _walk(body, _world(shell, local)):
			return -1.0 if height else false
		if is_instance_valid(body):
			high = maxf(high, _room_local(shell, body.global_position).y)
	return high if height else true


## Steer and press, never jump. False if the body stalls.
func _walk(body: Player, goal: Vector3, within := ARRIVE) -> bool:
	var still := 0
	var last := body.global_position
	var arrived := false
	Input.action_press("move_forward", 1.0)
	for _i in 1500:
		if not is_instance_valid(body) or main.view != 2:
			break
		var here := body.global_position
		var flat := Vector2(goal.x - here.x, goal.z - here.z)
		if flat.length() < within:
			arrived = true
			break
		body.rotation.y = atan2(-flat.x, -flat.y)
		body.camera.rotation.x = 0.0
		still = still + 1 if (here - last).length() < STILL_STEP else 0
		if still >= STUCK_FRAMES:
			_note("stalled at %s short of %s" % [_v(here), _v(goal)])
			break
		last = here
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	return arrived


func _world(shell: Node3D, local: Vector3) -> Vector3:
	return shell.global_transform * local


func _room_local(shell: Node3D, world: Vector3) -> Vector3:
	return shell.global_transform.affine_inverse() * world


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
