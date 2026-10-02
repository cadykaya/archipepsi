extends Node
## CP1 — FAIR COMBAT, counted in cumulative events (`make godot-combat-fairness`).
##
## PT-11, the owner's playtest: "Bombardment attacks through walls and
## from other rooms." The packet separates three questions, and so does
## this suite:
##
## - **Knowledge:** may the artillery commit a shell at a player it
##   cannot see?
## - **Path:** may a shell pass through an intact wall or roof?
## - **Cover:** may a blast damage through blast-blocking architecture?
##
## Each case counts every shell committed (`telegraph_started "shell"`),
## every shell launched (`telegraph_finished "shell"`, completed), every
## damage event (`Player.damaged_from`) and the hp lost, over the whole
## window. It never reads one number once. The **positive control**
## (low cover) must keep being shelled, so the repair cannot pass by
## silencing artillery.
##
## Cases C and D build a shell directly, and say so: they isolate the
## blast and the in-flight rule from the targeting decision.

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
	await _no_shell_through_a_solid_wall()
	await _no_shell_through_a_roof()
	await _no_shell_at_what_it_cannot_see()
	await _no_blast_through_a_wall()
	await _a_shell_stops_at_what_it_meets()
	await _low_cover_is_still_shelled()
	for role: String in ["drifter", "diver"]:
		await _a_flyer_is_hit_where_it_is_seen(role)
	await _the_drifter_in_every_state()
	await _the_diver_in_every_state()
	if failures == 0:
		print("GODOT COMBAT FAIRNESS OK (%d checks, %d notes)"
				% [checks, notes])
		get_tree().quit(0)
	else:
		print("GODOT COMBAT FAIRNESS: %d failures in %d checks"
				% [failures, checks])
		get_tree().quit(1)


# ------------------------------------------------------------- building

func _settle(frames := 10) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _stage() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	_box(root, Vector3(120.0, 1.0, 120.0), Vector3(0.0, -0.5, 0.0))
	return root


func _box(root: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	return body


## The player FIRST, and settled: a player and an enemy made in the same
## frame share the world origin for one physics step (O05-09.1's finding).
func _player(root: Node3D, at: Vector3) -> Player:
	var body := Player.create()
	root.add_child(body)
	body.global_position = at
	body.velocity = Vector3.ZERO
	await _settle(5)
	return body


## THE ROOM BEFORE THE GUN. A body added this frame is not in the
## physics space until the next step, and a gun placed in the same frame
## as its wall asked about a world without the wall -- one shell through
## an intact wall on the first run of case A. In a real Zone the geometry
## is built long before any enemy acts, so the stage settles first.
func _enemy(root: Node3D, role: String, at: Vector3) -> Enemy:
	await _settle(2)
	var made := Enemy.create(role, "concrete_facility")
	root.add_child(made)
	made.global_position = at
	return made


func _drop(root: Node3D) -> void:
	root.queue_free()
	for _i in 3:
		await get_tree().process_frame
		await get_tree().physics_frame


## Cumulative counters over one window.
func _watch(gun: Enemy, mark: Player) -> Dictionary:
	var tally := {"committed": 0, "launched": 0, "hits": 0,
			"hp_before": mark.hp}
	if gun != null:
		gun.telegraph_started.connect(func(kind: String, _s: float) -> void:
			if kind == "shell":
				tally["committed"] += 1)
		gun.telegraph_finished.connect(func(kind: String, done: bool) -> void:
			if kind == "shell" and done:
				tally["launched"] += 1)
	mark.damaged_from.connect(func(_from: Vector3) -> void:
		tally["hits"] += 1)
	return tally


func _lost(tally: Dictionary, mark: Player) -> float:
	return float(tally["hp_before"]) - mark.hp


## A shell made by hand (cases C and D): the blast and flight rules,
## without the targeting decision in front of them.
func _shell(root: Node3D, from: Vector3, to: Vector3) -> Node3D:
	var shell := Enemy.ArtilleryShell.new()
	shell.origin = from
	shell.target = to
	shell.seconds = Constants.ARTILLERY_FLIGHT_SECONDS
	shell.damage = 16.0
	shell.blast = Constants.ARTILLERY_BLAST_RADIUS
	root.add_child(shell)
	shell.global_position = from
	return shell


# ------------------------------------------------------------- the cases

## A: two rooms, one intact wall floor to ceiling between them.
func _no_shell_through_a_solid_wall() -> void:
	print("  -- A: another room, behind an intact wall")
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, -16.0))
	_box(root, Vector3(40.0, 8.0, 0.6), Vector3(0.0, 4.0, -8.0))
	var gun := await _enemy(root, "artillery", Vector3(0.0, 0.2, 0.0))
	var tally := _watch(gun, mark)
	await _settle(600)
	_check(tally["committed"] == 0 and tally["hits"] == 0,
			"through an intact wall from the next room, in 10 s: %d shells "
			% tally["committed"] + "committed, %d launched, %d hits, %.0f hp "
			% [tally["launched"], tally["hits"], _lost(tally, mark)]
			+ "lost -- it may not shell what it cannot see")
	await _drop(root)


## B: the player under a roof, visible through the open side. The line of
## sight is clear, the arc is not: it must cross the roof slab.
func _no_shell_through_a_roof() -> void:
	print("  -- B: under a roof, seen through the open side")
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, -16.0))
	# The slab's underside at 2.0 m, reaching 4 m toward the gun past the
	# player: the arc is above it there, and would have to come down
	# through it.
	_box(root, Vector3(8.0, 0.3, 8.0), Vector3(0.0, 2.15, -16.0))
	var gun := await _enemy(root, "artillery", Vector3(0.0, 0.2, 0.0))
	var tally := _watch(gun, mark)
	await _settle(600)
	# Zero COMMITTED, not only zero hits: a shell that would meet the roof
	# is not fired at all (the arc check), which the in-flight rule alone
	# would not show.
	_check(tally["committed"] == 0 and tally["hits"] == 0
			and is_equal_approx(_lost(tally, mark), 0.0),
			"under an intact roof, in 10 s: %d shells committed, %d "
			% [tally["committed"], tally["launched"]] + "launched, %d hits, "
			% tally["hits"] + "%.0f hp lost -- no shell through the slab"
			% _lost(tally, mark))
	await _drop(root)


## F: KNOWLEDGE ALONE. A 2.5 m wall the arc clears easily, but sight does
## not: the gun has no way to know where the player is behind it.
func _no_shell_at_what_it_cannot_see() -> void:
	print("  -- F: hidden behind a wall the arc could clear")
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, -16.0))
	_box(root, Vector3(40.0, 2.5, 0.6), Vector3(0.0, 1.25, -8.0))
	var gun := await _enemy(root, "artillery", Vector3(0.0, 0.2, 0.0))
	var tally := _watch(gun, mark)
	await _settle(600)
	_check(tally["committed"] == 0 and tally["hits"] == 0,
			"unseen behind 2.5 m, in 10 s: %d shells committed, %d hits "
			% [tally["committed"], tally["hits"]] + "-- no shell at what it "
			+ "cannot see, though the arc would clear the wall")
	await _drop(root)


## C: DIRECT SHELL. It lands 1.2 m in front of a tall wall; the player
## stands 1.2 m behind it, 2.4 m from the blast, inside its 3.2 m radius.
func _no_blast_through_a_wall() -> void:
	print("  -- C: a blast on the far side of a wall (a shell built by hand)")
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, -1.2))
	_box(root, Vector3(20.0, 6.0, 0.4), Vector3(0.0, 3.0, 0.0))
	var tally := _watch(null, mark)
	_shell(root, Vector3(0.0, 8.0, 12.0), Vector3(0.0, 0.0, 1.2))
	await _settle(150)
	_check(tally["hits"] == 0,
			"a blast 2.4 m away, behind a 6 m wall: %d hits, %.0f hp lost "
			% [tally["hits"], _lost(tally, mark)] + "-- the wall is cover")
	# ...and the same blast with nothing between reaches the player.
	var root2 := _stage()
	root.queue_free()
	var mark2 := await _player(root2, Vector3(20.0, 0.2, -1.2))
	var tally2 := _watch(null, mark2)
	_shell(root2, Vector3(20.0, 8.0, 12.0), Vector3(20.0, 0.0, 1.2))
	await _settle(150)
	_check(tally2["hits"] == 1,
			"the control: the same blast in the open lands %d hit (%.0f hp)"
			% [tally2["hits"], _lost(tally2, mark2)])
	await _drop(root2)


## D: DIRECT SHELL. A wall is raised across its path mid-flight; the shell
## must stop there, 8 m short, outside the blast radius of the player.
func _a_shell_stops_at_what_it_meets() -> void:
	print("  -- D: a wall raised across a shell's path in flight")
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, 0.0))
	var tally := _watch(null, mark)
	_shell(root, Vector3(0.0, 1.2, 20.0), Vector3(0.0, 0.0, 0.0))
	await _settle(24)
	_box(root, Vector3(20.0, 10.0, 0.6), Vector3(0.0, 5.0, 8.0))
	await _settle(150)
	_check(tally["hits"] == 0,
			"a wall across its path mid-flight: %d hits, %.0f hp lost -- "
			% [tally["hits"], _lost(tally, mark)] + "it detonates on the wall")
	await _drop(root)


## E: THE POSITIVE CONTROL. Low cover (0.6 m) between the gun and a
## standing player: indirect fire legitimately crosses it.
func _low_cover_is_still_shelled() -> void:
	print("  -- E: the control -- low cover is not a roof")
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, -16.0))
	_box(root, Vector3(40.0, 0.6, 0.6), Vector3(0.0, 0.3, -8.0))
	var gun := await _enemy(root, "artillery", Vector3(0.0, 0.2, 0.0))
	var tally := _watch(gun, mark)
	await _settle(600)
	_check(tally["launched"] >= 1 and tally["hits"] >= 1,
			"over 0.6 m cover, in 10 s: %d shells committed, %d launched, "
			% [tally["committed"], tally["launched"]] + "%d hits, %.0f hp lost "
			% [tally["hits"], _lost(tally, mark)] + "-- the repair did not "
			+ "silence artillery")
	await _drop(root)


# ------------------------------------------------------------- flyers (H-FLYER-HIT)

## The world box every mesh under `Visual` covers: what the player SEES.
static func _seen(enemy: Enemy) -> AABB:
	var box := AABB()
	var first := true
	for node: Node in enemy.visual.find_children("*", "MeshInstance3D",
			true, false):
		var mesh := node as MeshInstance3D
		var world := mesh.global_transform * mesh.get_aabb()
		box = world if first else box.merge(world)
		first = false
	return box


## The world box of its collider: what a shot can HIT.
static func _hittable(enemy: Enemy) -> AABB:
	for child: Node in enemy.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.shape is BoxShape3D:
			var size: Vector3 = (shape.shape as BoxShape3D).size
			# Through its world transform, so a body that has turned to
			# face the player is compared as turned -- exactly as its
			# meshes are.
			return shape.global_transform * AABB(-size / 2.0, size)
	return AABB()


func _aim_at(player: Player, point: Vector3) -> void:
	var eye := player.camera.global_position
	var flat := Vector3(point.x - eye.x, 0.0, point.z - eye.z)
	if flat.length() > 0.001:
		player.rotation.y = atan2(-flat.x, -flat.z)
	var rise := point.y - eye.y
	player.camera.rotation.x = atan2(rise, maxf(flat.length(), 0.001))


## PT-12: "Flyer hitbox above visible body." V-04: "Normal player camera
## shoots visible body across near/mid/far views. Hit volume follows
## rendered body; intentional miss outside it remains a miss."
##
## The player aims at the middle of what they can SEE and fires the
## Static Pulse through its real binding. The envelope's own hover height
## (the collider's centre above the floor) says where the body belongs.
## What is measured is the rendered meshes, never an internal centre: a
## test aiming at the collider would be green while the player aimed
## somewhere else.
func _a_flyer_is_hit_where_it_is_seen(role: String) -> void:
	print("  -- %s: seen, hit and placed where the contract says" % role)
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, 9.0))
	# Its shots are not what is being measured; the player outlasting
	# them is.
	mark.hp = 100000.0
	var flyer := await _enemy(root, role, Vector3(0.0, 0.2, 0.0))
	await _settle(120)
	var seen := _seen(flyer)
	var hittable := _hittable(flyer)
	var gap := absf(seen.get_center().y - hittable.get_center().y)
	var hover: float = float(flyer.envelope["centre_y"])
	var held := hittable.get_center().y
	_check(gap < 0.15,
			"%s: the body the player sees is centred %.2f m from the box a " % [role, gap]
			+ "shot can hit (seen %.2f m, hittable %.2f m)"
			% [seen.get_center().y, hittable.get_center().y])
	_check(seen.grow(0.05).encloses(hittable.grow(-0.2)) \
			and hittable.grow(0.05).encloses(seen),
			"%s: what is seen and what is hittable are the same box, not " % role
			+ "two that merely share a centre (seen %s, hittable %s)"
			% [seen, hittable])
	_check(absf(held - hover) < 0.3,
			"%s: its body holds at %.2f m above the floor, where its " % [role, held]
			+ "envelope's hover height (%.2f m, the collider's centre above " % hover
			+ "the floor) puts it")
	_check(seen.grow(0.1).has_point(flyer.muzzle()),
			"%s: its shots start inside the body the player sees (muzzle " % role
			+ "%s, seen %s)" % [flyer.muzzle(), seen])
	var facing := -flyer.global_transform.basis.z
	var toward := mark.global_position - flyer.global_position
	var flat_facing := Vector3(facing.x, 0.0, facing.z).normalized()
	var flat_toward := Vector3(toward.x, 0.0, toward.z).normalized()
	_check(rad_to_deg(flat_facing.angle_to(flat_toward)) < 30.0,
			"%s: having noticed the player, it faces them (%.0f deg off)"
			% [role, rad_to_deg(flat_facing.angle_to(flat_toward))])

	# ORDINARY AIMING across near, mid and far views: the middle of what
	# is seen, through the real fire binding.
	var hits := [0]
	mark.hit_confirmed.connect(func(_k: bool) -> void: hits[0] += 1)
	for distance: float in [4.0, 9.0, 18.0]:
		mark.global_position = Vector3(0.0, 0.2, distance)
		await _settle(6)
		var hp_before := flyer.hp
		hits[0] = 0
		await _fire(mark, func() -> Vector3: return _seen(flyer).get_center())
		_check(hits[0] >= 1 and flyer.hp < hp_before,
				"%s at %.0f m: aimed at the middle of its visible body, the " % [role, distance]
				+ "Static Pulse hits it %d time(s) (%.1f -> %.1f hp)"
				% [hits[0], hp_before, flyer.hp])
		flyer.hp = flyer.max_hp

	# THE DELIBERATE MISSES: just clear of the visible body, above it and
	# below it. Before the repair the one above is where the hidden
	# collider was, and it HIT.
	mark.global_position = Vector3(0.0, 0.2, 9.0)
	await _settle(6)
	for side: String in ["above", "below"]:
		var hp_before := flyer.hp
		hits[0] = 0
		await _fire(mark, func() -> Vector3:
			var box := _seen(flyer)
			return Vector3(box.get_center().x,
					box.end.y + 0.45 if side == "above"
						else box.position.y - 0.45,
					box.get_center().z))
		_check(hits[0] == 0 and is_equal_approx(flyer.hp, hp_before),
				"%s: aimed 0.45 m %s its visible body, the Static Pulse " % [role, side]
				+ "misses (%d hit(s), %.1f -> %.1f hp)"
				% [hits[0], hp_before, flyer.hp])

	# AN AREA WEAPON: a real explosive Echo shot aimed at the visible
	# body. It must meet the body and its blast must count the body --
	# measuring from a point under the flyer would make a direct hit on
	# something hovering 2.5 m up a blast that reaches nobody.
	var hp_before_blast := flyer.hp
	var shot := EchoProjectile.new()
	shot.damage = 10.0
	shot.speed = 15.0
	shot.blast_radius = 1.2
	shot.lifetime = 3.0
	var from := mark.global_position + Vector3.UP * 1.4
	shot.direction = (_seen(flyer).get_center() - from).normalized()
	root.add_child(shot)
	shot.global_position = from
	await _settle(60)
	_check(flyer.hp < hp_before_blast,
			"%s: an explosive Echo shot aimed at its visible body damages " % role
			+ "it (%.1f -> %.1f hp)" % [hp_before_blast, flyer.hp])
	await _drop(root)


## Hold the real fire binding for three pulses' worth of frames, aiming
## at `where` every frame (the body may drift; aiming tracks what is seen).
func _fire(mark: Player, where: Callable) -> void:
	for _i in 45:
		_aim_at(mark, where.call())
		Input.action_press("fire_pulse")
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	await _settle(4)


# ------------------------------------------------ flyer action (H-FLYER-AI)

## PT-13 / V-05: "Actual declared role with ground/air/range/sight states
## recorded. Correct attack/wait state, real launched/impact events and
## cumulative damage; respawn cannot erase evidence."
##
## Every number below is COUNTED from an event as it happens: a
## telegraph from `telegraph_started`, a launch from a projectile or a
## dive commit appearing, an impact from the player's `damaged_from`,
## damage from each `hp_changed` fall, a death from `died`. Nothing is
## read off the player's health at the end, which is how an earlier
## diagnosis reported "zero damage" -- it read HP after a respawn.
##
## The player is driven through its REAL bindings (move, jump) except
## in the one state labelled DIRECT HANDLER: held in the air where a
## grapple arc would put it, as the roster suite does.
func _record(role: String, state: String, setup: Callable,
		drive: Callable, seconds := 6.0,
		drive_while_settling := false) -> Dictionary:
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 0.2, 8.0))
	mark.hp = 100000.0
	await setup.call(root, mark)
	var flyer := await _enemy(root, role, Vector3(0.0, 0.2, 0.0))
	# WHERE IT COMMITS FROM is watched from the moment it exists, settle
	# included: a commit made before the counting window is still one it
	# made.
	var farthest := [0.0]
	flyer.telegraph_started.connect(func(_k: String, _d: float) -> void:
		farthest[0] = maxf(farthest[0], flyer.body_centre().distance_to(
				mark.global_position + Vector3.UP
					* (Constants.PLAYER_HEIGHT / 2.0))))
	# Time to notice, face and take station -- before anything counts.
	# A state that has to hold from the start (a player already in the
	# air) is driven through this too.
	for frame in 90:
		if drive_while_settling:
			await drive.call(mark, frame)
		await get_tree().physics_frame
	var tally := {"role": role, "state": state, "telegraphs": 0,
		"launched": 0, "impacts": 0, "damage": 0.0, "deaths": 0,
		"noticed_frames": 0, "airborne_frames": 0, "off_floor_frames": 0,
		"sight_frames": 0,
		"frames": 0, "telegraphs_before_launch": true, "last_hp": mark.hp,
		"telegraph_open": false, "eye_at_telegraph": 0.0,
		"farthest_commit": 0.0}
	# A dive is a launch the moment its telegraph completes: that is when
	# it resolves into the committed dive, which may land in the same
	# frame it starts.
	flyer.telegraph_finished.connect(func(kind: String, done: bool) -> void:
		if kind == "dive" and done:
			tally["launched"] += 1)
	flyer.telegraph_started.connect(func(_k: String, _d: float) -> void:
		tally["telegraphs"] += 1
		tally["telegraph_open"] = true
		tally["eye_at_telegraph"] = maxf(float(tally["eye_at_telegraph"]),
				_eye_energy(flyer)))
	var on_added := func(node: Node) -> void:
		if node is Enemy.EnemyProjectile:
			tally["launched"] += 1
			if not tally["telegraph_open"] and role == "drifter":
				tally["telegraphs_before_launch"] = false
			tally["telegraph_open"] = false
	get_tree().node_added.connect(on_added)
	mark.damaged_from.connect(func(_at: Vector3) -> void:
		tally["impacts"] += 1)
	mark.hp_changed.connect(func(hp: float, _shield: float) -> void:
		if hp < float(tally["last_hp"]):
			tally["damage"] += float(tally["last_hp"]) - hp
		tally["last_hp"] = hp)
	mark.died.connect(func() -> void: tally["deaths"] += 1)
	for frame in int(seconds * 60.0):
		await drive.call(mark, frame)
		await get_tree().physics_frame
		tally["frames"] += 1
		if flyer._has_noticed:
			tally["noticed_frames"] += 1
		# Two readings of "in the air": off the floor at all, and the
		# diver's own rule, which is the one its dive answers to.
		if not mark.is_on_floor():
			tally["off_floor_frames"] += 1
		if flyer._player_is_airborne(mark):
			tally["airborne_frames"] += 1
		if flyer._has_line_of_sight(mark):
			tally["sight_frames"] += 1
	for action: String in ["jump", "move_left", "move_right"]:
		Input.action_release(action)
	get_tree().node_added.disconnect(on_added)
	tally["farthest_commit"] = farthest[0]
	tally["eye_now"] = _eye_energy(flyer)
	tally["flyer"] = flyer
	tally["mark"] = mark
	tally["root"] = root
	print("    [%s / %s] noticed %d/%d frames, off the floor %d, airborne " % [
			role, state, tally["noticed_frames"], tally["frames"],
			tally["off_floor_frames"]] + "by the diver's rule %d, sight %d; "
			% [tally["airborne_frames"], tally["sight_frames"]]
			+ "telegraphs %d, launched %d, impacts %d, damage %.1f, " % [
			tally["telegraphs"], tally["launched"], tally["impacts"],
			tally["damage"]] + "deaths %d" % tally["deaths"])
	return tally


## What the player sees of its eye: the glow of its first `Eye` mesh.
static func _eye_energy(enemy: Enemy) -> float:
	for eye: Node in enemy.visual.find_children("Eye*", "MeshInstance3D",
			true, false):
		return ((eye as MeshInstance3D).material_override
				as StandardMaterial3D).emission_energy_multiplier
	return -1.0


func _nothing(_root: Node3D, _mark: Player) -> void:
	await get_tree().physics_frame


func _still(_mark: Player, _frame: int) -> void:
	pass


## Strafing across the flyer's line, a second each way, on the real
## movement bindings.
func _strafe(_mark: Player, frame: int) -> void:
	var right := (frame / 60) % 2 == 0
	Input.action_release("move_left" if right else "move_right")
	Input.action_press("move_right" if right else "move_left")


## An ordinary jump every 0.8 s on the real binding.
func _hop(_mark: Player, frame: int) -> void:
	if frame % 48 == 0:
		Input.action_press("jump")
	elif frame % 48 == 1:
		Input.action_release("jump")


## DIRECT HANDLER: held 4 m above the floor, where a grapple arc puts a
## player, for the whole window.
func _held_up(mark: Player, _frame: int) -> void:
	mark.global_position = Vector3(mark.global_position.x, 4.0,
			mark.global_position.z)
	mark.velocity = Vector3.ZERO


## A 6 m wall across the line, 4 m from the flyer.
func _walled(root: Node3D, _mark: Player) -> void:
	_box(root, Vector3(12.0, 6.0, 0.4), Vector3(0.0, 3.0, 4.0))
	await _settle(2)


func _far_away(_root: Node3D, mark: Player) -> void:
	mark.global_position = Vector3(0.0, 0.2, 30.0)
	await _settle(3)


func _the_drifter_in_every_state() -> void:
	print("  -- DRIFTER: every state, counted from events")
	var still := await _record("drifter", "stationary on the ground",
			_nothing, _still)
	_check(still["telegraphs"] >= 2 and still["launched"] >= 2
			and still["impacts"] >= 1 and still["damage"] > 0.0,
			"drifter, stationary player in range and sight: it attacks "
			+ "(%d telegraphed, %d launched, %d impacts, %.1f damage)"
			% [still["telegraphs"], still["launched"], still["impacts"],
				still["damage"]])
	_check(still["telegraphs_before_launch"],
			"drifter: every shot is telegraphed before it leaves (a shot "
			+ "with nothing to see first cannot be dodged)")
	_check(float(still["eye_at_telegraph"]) >= Enemy.EYE_ENERGY
			* Enemy.EYE_FLARE - 0.01,
			"drifter: its eye flares while it telegraphs (%.2f, resting %.2f)"
			% [still["eye_at_telegraph"], Enemy.EYE_ENERGY])
	await _drop(still["root"])
	var moving := await _record("drifter", "strafing on the ground",
			_nothing, _strafe)
	_check(moving["launched"] >= 2,
			"drifter, strafing player: it keeps attacking (%d launched, "
			% moving["launched"] + "%d impacts)" % moving["impacts"])
	await _drop(moving["root"])
	var hopping := await _record("drifter", "jumping", _nothing, _hop)
	_check(hopping["launched"] >= 2 and hopping["off_floor_frames"] > 0,
			"drifter, jumping player: it attacks whether or not the player "
			+ "is in the air (%d launched, %d frames off the floor)"
			% [hopping["launched"], hopping["off_floor_frames"]])
	await _drop(hopping["root"])
	var hidden := await _record("drifter", "behind a wall", _walled, _still)
	_check(hidden["launched"] == 0 and hidden["impacts"] == 0,
			"drifter, player behind a wall: nothing launched, nothing lands "
			+ "(%d, %d)" % [hidden["launched"], hidden["impacts"]])
	await _drop(hidden["root"])
	var far := await _record("drifter", "out of range", _far_away, _still)
	_check(far["launched"] == 0,
			"drifter, player 30 m away (reach %.0f): nothing launched (%d)"
			% [float(Constants.ENEMY_STATS["drifter"]["reach"]),
				far["launched"]])
	await _drop(far["root"])


func _the_diver_in_every_state() -> void:
	print("  -- DIVER: every state, counted from events")
	var still := await _record("diver", "stationary on the ground",
			_nothing, _still)
	_check(still["noticed_frames"] == still["frames"]
			and still["launched"] == 0 and still["impacts"] == 0,
			"diver, stationary player on the ground: it has noticed them "
			+ "(%d/%d frames) and WAITS -- nothing launched (%d)"
			% [still["noticed_frames"], still["frames"], still["launched"]])
	var diver: Enemy = still["flyer"]
	var target: Vector3 = (still["mark"] as Player).global_position \
			+ Vector3.UP * (Constants.PLAYER_HEIGHT / 2.0)
	var nose := -diver.visual.global_transform.basis.z
	var aim := (target - diver.visual.global_position).normalized()
	_check(rad_to_deg(nose.angle_to(aim)) < 12.0,
			"diver, waiting: its nose is on the player -- it reads as "
			+ "watching, not idle (%.0f deg off)"
			% rad_to_deg(nose.angle_to(aim)))
	var reach_now := diver.body_centre().distance_to(target)
	_check(reach_now <= float(Constants.ENEMY_STATS["diver"]["speed"])
			* Constants.DIVER_DIVE_SECONDS + 1.6,
			"diver, waiting: it holds within a dive's reach of the player "
			+ "(%.1f m; a dive carries %.1f m and lands within 1.6 m)"
			% [reach_now, float(Constants.ENEMY_STATS["diver"]["speed"])
				* Constants.DIVER_DIVE_SECONDS])
	await _drop(still["root"])
	var moving := await _record("diver", "strafing on the ground",
			_nothing, _strafe)
	_check(moving["launched"] == 0,
			"diver, strafing player on the ground: it still waits (%d)"
			% moving["launched"])
	await _drop(moving["root"])
	var hopping := await _record("diver", "jumping", _nothing, _hop)
	_check(hopping["airborne_frames"] > 0 and hopping["launched"] >= 1,
			"diver, ORDINARY jumps: leaving the ground draws a dive (%d "
			% hopping["off_floor_frames"] + "frames off the floor, %d "
			% hopping["airborne_frames"] + "airborne by its rule, %d dives)"
			% hopping["launched"])
	_check(hopping["impacts"] >= 1 and hopping["damage"] > 0.0,
			"diver, jumping player who stays put: a dive lands (%d impacts, "
			% hopping["impacts"] + "%.1f damage)" % hopping["damage"])
	await _drop(hopping["root"])
	# NOT A HOMING HIT (P06.4: "it must not become an unavoidable
	# collision or a permanent homing hit"). The dive's aim is fixed when
	# its telegraph resolves, so a player who keeps moving after the jump
	# is somewhere else when it arrives.
	var evading := await _record("diver", "jumping while strafing",
			_nothing, func(mark: Player, frame: int) -> void:
				_strafe(mark, frame)
				_hop(mark, frame))
	_check(evading["launched"] >= 1
			and evading["impacts"] < evading["launched"],
			"diver, a player who jumps and keeps moving: it still commits, "
			+ "and the dive can be avoided (%d dives, %d landed)"
			% [evading["launched"], evading["impacts"]])
	await _drop(evading["root"])
	# COMMITTED ONLY WHERE A DIVE CAN ARRIVE. Airborne from the start and
	# 14 m off: inside what it notices (18 m), outside what a dive
	# reaches (6.3 m carried + 1.6 m contact). It has to close first.
	var afar := await _record("diver", "in the air 14 m away",
			func(_root: Node3D, mark: Player) -> void:
				mark.global_position = Vector3(0.0, 4.0, 14.0)
				await _settle(2),
			_held_up, 6.0, true)
	var dive_reach := float(Constants.ENEMY_STATS["diver"]["speed"]) \
			* Constants.DIVER_DIVE_SECONDS + Enemy.DIVE_CONTACT
	_check(afar["launched"] >= 1 and afar["impacts"] >= 1
			and float(afar["farthest_commit"]) <= dive_reach + 0.05,
			"diver, a player in the air 14 m off: it closes before it "
			+ "commits -- farthest commit %.1f m (a dive reaches %.1f), "
			% [afar["farthest_commit"], dive_reach] + "%d dives, %d landed"
			% [afar["launched"], afar["impacts"]])
	await _drop(afar["root"])
	var up := await _record("diver", "held in the air (direct handler)",
			_nothing, _held_up)
	_check(up["launched"] >= 1 and up["impacts"] >= 1,
			"diver, player held where a grapple arc puts them: it dives and "
			+ "lands (%d dives, %d impacts, %.1f damage)"
			% [up["launched"], up["impacts"], up["damage"]])
	await _drop(up["root"])
	await _a_dive_is_stopped_by_a_wall_raised_in_its_path()
	var hidden := await _record("diver", "in the air behind a wall",
			_walled, _held_up)
	_check(hidden["launched"] == 0 and hidden["impacts"] == 0,
			"diver, airborne player behind a wall: no dive, nothing lands "
			+ "(%d, %d)" % [hidden["launched"], hidden["impacts"]])
	await _drop(hidden["root"])
	var far := await _record("diver", "jumping out of range", _far_away,
			_hop)
	_check(far["launched"] == 0,
			"diver, player jumping 30 m away: no dive (%d)" % far["launched"])
	_check(is_equal_approx(float(still["eye_now"]), Enemy.EYE_ENERGY
			* Enemy.EYE_WATCHING) and is_equal_approx(float(far["eye_now"]),
			Enemy.EYE_ENERGY * Enemy.EYE_IDLE),
			"diver: WAITING READS AS WATCHING, not as idle -- its eye burns "
			+ "at %.2f with the player noticed, %.2f with no one there"
			% [still["eye_now"], far["eye_now"]])
	_check(float(hopping["eye_at_telegraph"]) >= Enemy.EYE_ENERGY
			* Enemy.EYE_FLARE - 0.01,
			"diver: committing, its eye flares (%.2f)"
			% hopping["eye_at_telegraph"])
	await _drop(far["root"])


## The dive's analogue of artillery case D: a wall raised across a
## committed dive's path. The dive was committed at a player in plain
## sight; the wall arrives while it telegraphs. Pressed against it, the
## diver's body ends within its contact distance of the player standing
## right behind -- and a dive that lands through a wall is the
## through-wall hit PT-11 was, on another role.
func _a_dive_is_stopped_by_a_wall_raised_in_its_path() -> void:
	print("  -- diver: a wall raised across a committed dive")
	var root := _stage()
	var mark := await _player(root, Vector3(0.0, 1.0, 2.2))
	mark.hp = 100000.0
	var diver := await _enemy(root, "diver", Vector3(0.0, 0.2, 0.0))
	var impacts := [0]
	var raised := [false]
	mark.damaged_from.connect(func(_at: Vector3) -> void: impacts[0] += 1)
	diver.telegraph_started.connect(func(kind: String, _d: float) -> void:
		if kind == "dive" and not raised[0]:
			raised[0] = true
			_box(root, Vector3(4.0, 5.0, 0.4), Vector3(0.0, 2.5, 1.5)))
	for _i in 150:
		# Held in the air behind where the wall will stand.
		mark.global_position = Vector3(0.0, 1.0, 2.2)
		mark.velocity = Vector3.ZERO
		await get_tree().physics_frame
	var closest := diver.body_centre().distance_to(
			mark.global_position + Vector3.UP * (Constants.PLAYER_HEIGHT / 2.0))
	_check(raised[0] and impacts[0] == 0,
			"diver: a wall raised across its committed dive stops it -- %d "
			% impacts[0] + "impacts, though its body ends %.2f m from the "
			% closest + "player's (contact is %.1f m)" % Enemy.DIVE_CONTACT)
	await _drop(root)
