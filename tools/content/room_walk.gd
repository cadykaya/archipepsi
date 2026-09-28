extends Node
## THE REAL PLAYER THROUGH ONE ROOM, WITH NO JUMPS.
##
##   sh tools/content/run_room_walk.sh <out-dir>
##
## Runs inside a throwaway copy of Production's `godot/` at a pinned
## revision, so the body walking is Production's own `Player`: its speed,
## step law, eye height and camera are whatever that checkout says, and
## nothing here sets them. The route is driven the way Production's
## drivers drive one (`counterfire_driver.gd`, `_walk_to`): `move_forward`
## held, the body turned toward the next point. One difference, on
## purpose: a body that stops making progress FAILS instead of jumping.
## The room claims every route in it is a walk, and a hop would hide it
## if one were not.
##
## Two floors stand in for the connectors a Zone attaches at the sockets.
## The shell's own floor stops at the inner face of each end wall, which
## is where its sockets and `exit_offset` are, so without them the walk
## could only start and finish in the doorways. They are test fixtures,
## not part of the room.
##
## `-- --shots <dir>` (a rendering run) stands the player at two places
## the walk reached and saves what its own camera sees, lit only by the
## Zone's environment exactly as `ZoneBuilder` makes it.

const ROOM := "res://content/shells/shell_concourse_pier.tscn"
const THEME := "concrete_facility"
## A body is stuck when it has moved less than this per frame ...
const STILL_STEP := 0.012
## ... for this many frames running.
const STUCK_FRAMES := 30
const ARRIVE_WITHIN := 0.35
const HEIGHT_TOLERANCE := 0.15

const OUTSIDE_ENTRY := Vector3(0.0, 0.05, -2.5)
## A leg whose landing height is measured and printed but not asserted.
const LANDS_ANYWHERE := -1.0

## [label, where, the floor height the body should be standing on there]
const FLOOR_ROUTE := [
	["in through the entrance", Vector3(0.0, 0.0, 1.6), 0.0],
	["out from under the gallery", Vector3(5.8, 0.0, 6.0), 0.0],
	["down the exit-side lane past the pier", Vector3(5.8, 0.0, 16.0), 0.0],
	["to the exit", Vector3(4.8, 0.0, 21.0), 0.0],
	["out through the exit", Vector3(4.8, 0.0, 24.0), 0.0],
]
const LOOP_ROUTE := [
	["in through the entrance", Vector3(0.0, 0.0, 1.6), 0.0],
	["into the stair-side lane", Vector3(-3.8, 0.0, 6.0), 0.0],
	["behind the pier", Vector3(-3.8, 0.0, 13.3), 0.0],
	["to the foot of stair A", Vector3(-6.8, 0.0, 13.3), 0.0],
	["up stair A onto the gallery", Vector3(-6.8, 3.5, 2.2), 3.5],
	["along the gallery to the bridge", Vector3(1.2, 3.5, 2.2), 3.5],
	["over the bridge onto the pier", Vector3(1.2, 3.5, 10.0), 3.5],
	["to the head of stair B", Vector3(2.4, 3.5, 12.4), 3.5],
	["down stair B", Vector3(2.4, 0.0, 21.3), 0.0],
	["to the exit", Vector3(4.8, 0.0, 21.3), 0.0],
	["out through the exit", Vector3(4.8, 0.0, 24.0), 0.0],
]
## The pier's edge is open: stepping off it is a way down, not a trap.
const DROP_ROUTE := [
	["in through the entrance", Vector3(0.0, 0.0, 1.6), 0.0],
	["into the stair-side lane", Vector3(-3.8, 0.0, 6.0), 0.0],
	["behind the pier", Vector3(-3.8, 0.0, 13.3), 0.0],
	["to the foot of stair A", Vector3(-6.8, 0.0, 13.3), 0.0],
	["up stair A onto the gallery", Vector3(-6.8, 3.5, 2.2), 3.5],
	["along the gallery to the bridge", Vector3(1.2, 3.5, 2.2), 3.5],
	["over the bridge onto the pier", Vector3(1.2, 3.5, 10.0), 3.5],
	# Wherever the fall carries it: at a walk that is stair A's second
	# tread, 0.70 m, since the treads are solid to the floor. Reported,
	# not asserted -- the claim is the next leg, that it walks on down.
	["off the pier's stair-side edge", Vector3(-4.0, 0.0, 10.5),
			LANDS_ANYWHERE],
	["back down to the floor", Vector3(-3.8, 0.0, 14.5), 0.0],
]

## THE CONTROL, run first: the same walker sent into the pier's solid
## side must stop short and name what stopped it. If it arrives, the
## instrument cannot see a wall and nothing it passed means anything.
const CONTROL_ROUTE := [
	["in through the entrance", Vector3(0.0, 0.0, 1.6), 0.0],
	["under the bridge", Vector3(0.8, 0.0, 6.0), 0.0],
	["into the pier (must be refused)", Vector3(0.8, 0.0, 10.5), 0.0],
]

## Where the two pictures are taken: [file, feet, yaw, pitch in degrees].
## Coming in: level, into the room. On the pier: back along the bridge
## to the gallery and stair A, the way the upper loop came, a little down.
const SHOTS := [
	["room_entry_eye.png", Vector3(0.0, 0.0, 1.2), PI, 0.0],
	["room_pier_eye.png", Vector3(1.2, 3.5, 11.6), 0.0, -12.0],
]

var failures := 0
var room: Node3D
var player: Player


func _ready() -> void:
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var shots := ""
	var at := args.find("--shots")
	if at >= 0 and at + 1 < args.size():
		shots = args[at + 1]
	_build()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if shots.is_empty():
		await _route("control", CONTROL_ROUTE, true)
		await _route("floor", FLOOR_ROUTE)
		await _route("upper loop", LOOP_ROUTE)
		await _route("drop from the pier", DROP_ROUTE)
		if failures == 0:
			print("[walk] PASS -- the real player walked every route, "
					+ "no jumps")
		else:
			print("[walk] FAILED -- %d problem(s)" % failures)
	else:
		await _shots(shots)
	get_tree().quit(1 if failures > 0 else 0)


func _fail(message: String) -> void:
	failures += 1
	print("[walk] FAIL: " + message)


func _build() -> void:
	var scene: PackedScene = load(ROOM)
	if scene == null:
		_fail("%s did not load" % ROOM)
		return
	room = scene.instantiate()
	add_child(room)
	# The connector floors: at socket height, from the doorway outward.
	_fixture("entry_connector_floor", Vector3(-3.0, -0.5, -5.0),
			Vector3(3.0, 0.0, 0.0))
	_fixture("exit_connector_floor", Vector3(1.8, -0.5, 22.0),
			Vector3(7.8, 0.0, 27.0))
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	# `ZoneBuilder`'s Zone environment, value for value.
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(THEME)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = ThemeMaterials.void_color(THEME).lightened(0.1)
	env.fog_density = 0.012
	holder.environment = env
	add_child(holder)


func _fixture(label: String, low: Vector3, high: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = high - low
	shape.shape = box
	body.position = (low + high) / 2.0
	body.add_child(shape)
	add_child(body)


func _spawn(feet: Vector3, yaw: float) -> void:
	if player != null:
		player.queue_free()
		await get_tree().physics_frame
	player = Player.create()
	add_child(player)
	player.set_spawn(Transform3D(Basis(Vector3.UP, yaw), feet))
	player.velocity = Vector3.ZERO
	if player.camera != null:
		player.camera.current = true
	for _i in 20:
		await get_tree().physics_frame


func _route(label: String, legs: Array, last_is_a_wall := false) -> void:
	await _spawn(OUTSIDE_ENTRY, PI)
	var frames := 0
	var walked := 0.0
	var airborne := 0
	var longest_air := 0
	var lowest := INF
	var ok := true
	Input.action_press("move_forward", 1.0)
	for n in legs.size():
		var leg: Array = legs[n]
		var wall := last_is_a_wall and n == legs.size() - 1
		var goal: Vector3 = leg[1]
		var arrived := false
		var still := 0
		var last := player.global_position
		for _i in 1200:
			var here := player.global_position
			var flat := Vector2(goal.x - here.x, goal.z - here.z)
			if flat.length() < ARRIVE_WITHIN:
				arrived = true
				break
			player.rotation.y = atan2(-flat.x, -flat.y)
			player.camera.rotation.x = 0.0
			var moved := (here - last).length()
			walked += moved
			still = still + 1 if moved < STILL_STEP else 0
			if still >= STUCK_FRAMES:
				break
			if player.is_on_floor():
				airborne = 0
			else:
				airborne += 1
				longest_air = maxi(longest_air, airborne)
			lowest = minf(lowest, here.y)
			last = here
			frames += 1
			await get_tree().physics_frame
		# Measured STANDING. A body that has just walked off an edge is
		# still falling when it passes over the point, and its height then
		# says nothing about where it lands, so it gets the frames to land.
		# A body balanced on a step's edge counts as on the floor and gets
		# no such grace.
		var settle := 0
		while arrived and not player.is_on_floor() and settle < 90:
			settle += 1
			frames += 1
			await get_tree().physics_frame
		var y := player.global_position.y
		var want := float(leg[2])
		if wall:
			if arrived:
				_fail("%s: the walker went THROUGH '%s'; it cannot see "
						% [label, leg[0]] + "a wall, so no walk proves anything")
			else:
				print("[walk]   %-20s %-34s stopped at %s, %s"
						% [label, leg[0], _v(player.global_position),
							_blockers()])
			ok = not arrived
			break
		if not arrived:
			_fail("%s: stopped short of '%s' at %s, %s"
					% [label, leg[0], _v(player.global_position),
						_blockers()])
			ok = false
			break
		if want != LANDS_ANYWHERE and absf(y - want) > HEIGHT_TOLERANCE:
			_fail("%s: '%s' reached at height %.2f, expected %.2f"
					% [label, leg[0], y, want])
			ok = false
			break
		print("[walk]   %-20s %-34s at %s  standing at %.2f"
				% [label, leg[0], _v(player.global_position), y])
	Input.action_release("move_forward")
	await get_tree().physics_frame
	if lowest < -0.2:
		_fail("%s: the body went %.2f below the floor" % [label, -lowest])
		ok = false
	print("[walk] %s %-18s %d legs, %.1f m in %.1f s, longest airborne "
			% ["ok  " if ok else "FAIL", label, legs.size(), walked,
				frames / float(Engine.physics_ticks_per_second)]
			+ "spell %d frame(s); eye %.2f m above the feet, fov %.0f"
			% [longest_air, player.camera.global_position.y
				- player.global_position.y, player.camera.fov])


func _blockers() -> String:
	var names: Array[String] = []
	for i in player.get_slide_collision_count():
		var hit := player.get_slide_collision(i)
		var what := hit.get_collider() as Node
		if what != null and not names.has(str(what.name)):
			names.append(str(what.name))
	return "touching %s" % (", ".join(names) if not names.is_empty()
			else "nothing")


func _shots(out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	for shot: Array in SHOTS:
		await _spawn((shot[1] as Vector3) + Vector3(0.0, 0.05, 0.0),
				float(shot[2]))
		player.camera.rotation.x = deg_to_rad(float(shot[3]))
		for _i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := out_dir.path_join(str(shot[0]))
		if image == null or image.save_png(path) != OK:
			_fail("could not save %s" % path)
			continue
		print("[walk] shot %s  eye at %s  looking %s" % [path,
				_v(player.camera.global_position),
				_v(-player.camera.global_transform.basis.z)])


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
