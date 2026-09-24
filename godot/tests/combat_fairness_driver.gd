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
			return AABB(shape.global_position - size / 2.0, size)
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
