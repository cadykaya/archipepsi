extends Node
## Invariant I14 (ACCEPTANCE_TESTS §5.7), swept across every chamber builder.
##
##     godot --headless --path godot --script tests/test_blink.gd
##
## `blink` is the one verb in the S2 catalog that can put the player outside
## the world, because it is the only one that sets a position instead of a
## velocity. Everything else is eventually answered by move_and_slide; a
## teleport is answered by nothing. So it gets its own suite, with real
## colliders and real physics frames rather than the geometry-only checks
## the chamber tests do.
##
## Four properties, on every attempt:
##   1. no surface hit  ->  the player does not move at all
##   2. it moved        ->  by no more than `range`
##   3. it moved        ->  the landing point is not inside geometry
##   4. it moved        ->  the landing point is inside the Zone bounds
##
## The sweep matters as much as the assertions. A blink test that fires down
## a corridor proves a corridor; the failures live at the corners, over the
## platform gaps and off the top of the tower, so this fires from many
## points in many directions in every builder and counts how many actually
## resolved -- a suite where nothing ever teleported would pass all four
## properties vacuously.

var failures := 0
var _resolved := 0
var _refused := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().physics_frame
	for theme: String in ["concrete_facility", "rusted_industrial",
			"gothic_stone", "temple_ruin", "void_glitch"]:
		for kind: String in ["corridor", "arena", "platform_path", "tower",
				"treasure_room"]:
			await _sweep_zone(kind, theme)

	# Vacuity guard: if nothing ever blinked, the four properties above are
	# all trivially true and this suite proves nothing.
	_check(_resolved >= 50,
			("the sweep actually teleported (resolved %d, refused %d)"
			% [_resolved, _refused]))
	# ...and the converse: a blink that ALWAYS resolves means the no-hit
	# refusal path never ran, which is property 1.
	_check(_refused >= 10,
			("the sweep also aimed at nothing and was refused (refused %d)"
			% _refused))

	if failures == 0:
		print("blink resolved %d, refused %d" % [_resolved, _refused])
		print("GODOT BLINK TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT BLINK TESTS: %d failures" % failures)
		get_tree().quit(1)

## One zone of a single chamber kind, built the way ZoneController builds it,
## with a stand-in that answers `world_bounds()` the same way.
func _sweep_zone(kind: String, theme: String) -> void:
	var zone := {
		"zone_id": "blink_%s" % kind, "theme": theme,
		"display_name": "Blink %s" % kind,
		"chambers": [_chamber_spec(kind)],
	}
	var build := ZoneBuilder.build(zone)

	var holder := BlinkZoneStub.new()
	holder.name = "ZoneStub_%s_%s" % [kind, theme]
	for box: AABB in build["bounds_list"]:
		holder.add_bounds(box)
	add_child(holder)
	holder.add_child(build["root"])

	var player := Player.create()
	holder.add_child(player)
	# Frozen: this suite is about where a blink LANDS, and a player walking
	# or falling between attempts would move the origin out from under the
	# assertion.
	player.input_frozen = true

	# Two frames: one for the colliders to enter the physics server, one for
	# the server to have stepped with them in it.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var runtime: EchoRuntime = player.get_node("EchoRuntime")
	var bounds: AABB = holder.world_bounds()

	for reach: float in [3.0, 9.0, 25.0]:
		runtime.equipped = {
			"component_id": "act_blink", "slot": "echo_a", "cooldown": 0.6,
			"primitive": {"type": "blink", "range": reach,
					"clearance": float(Constants.PLAYER_RADIUS)},
			"modifiers": [],
		}
		for origin: Vector3 in _origins(bounds):
			for aim: Vector3 in _aims():
				_attempt(player, runtime, origin, aim, reach, bounds,
						"%s/%s" % [kind, theme])

	holder.queue_free()
	await get_tree().physics_frame

## One blink attempt, with the four properties checked against it.
func _attempt(player: Player, runtime: EchoRuntime, origin: Vector3,
		aim: Vector3, reach: float, bounds: AABB, where: String) -> void:
	player.global_position = origin
	player.velocity = Vector3.ZERO
	# Aim by rotating the body and pitching the camera, which is how the
	# real thing is aimed -- setting a look_at on the camera alone would
	# test a configuration the game cannot produce.
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length() < 0.001:
		flat = Vector3.FORWARD
	player.rotation.y = atan2(-flat.x, -flat.z)
	player.camera.rotation.x = clampf(asin(clampf(aim.normalized().y,
			-1.0, 1.0)), -PI / 2.0, PI / 2.0)
	# No physics frame per attempt. `global_transform` updates on assignment,
	# and the ray excludes the player's own body, so nothing in an attempt
	# waits on the server having stepped since the last one. Awaiting here
	# cost ~23,000 frames of wall clock and proved nothing extra.
	var from := player.camera.global_position
	var dir := -player.camera.global_transform.basis.z
	var surface := _ray(player, from, dir, reach)
	runtime.cooldown_remaining = 0.0
	runtime.activate()
	var landed := player.global_position
	var moved := landed.distance_to(origin)

	if surface.is_empty():
		# 1. No hit, no blink. Free-space teleport is the bug this forbids.
		_check(moved < 0.001,
				("%s: blink with no surface hit did not move the player "
				+ "(moved %.3f)") % [where, moved])
		_refused += 1
		return

	if moved < 0.001:
		# Refused for clearance or bounds. That is a legal outcome, and the
		# cooldown must have been refunded so it does not read as broken.
		_check(runtime.cooldown_remaining <= 0.0,
				"%s: a refused blink refunds its cooldown" % where)
		_refused += 1
		return

	_resolved += 1
	# 2. Never further than the primitive's own bound.
	_check(moved <= reach + 0.35,
			("%s: blink travelled %.2f m, bound is %.2f m"
			% [where, moved, reach]))
	# 3. Never inside geometry. Asked with a shape, not a ray: a ray can
	#    thread a gap the body does not fit through.
	_check(_body_fits(player, landed),
			"%s: blink landed clear of geometry (at %v)" % [where, landed])
	# 4. Never outside the Zone. The margin matches the runtime's own.
	_check(bounds.grow(0.6).has_point(landed),
			("%s: blink landed inside zone bounds (at %v, bounds %s)"
			% [where, landed, bounds]))

func _ray(player: Player, from: Vector3, dir: Vector3,
		distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * distance)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)

## Is there room for the player where it landed? Probed at mid-height with
## the capsule's own radius; a sphere at the feet always meets the floor.
func _body_fits(player: Player, at: Vector3) -> bool:
	var radius := float(Constants.PLAYER_RADIUS)
	var shape := SphereShape3D.new()
	shape.radius = radius * 0.92
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY,
			at + Vector3.UP * (float(Constants.PLAYER_HEIGHT) / 2.0))
	return player.get_world_3d().direct_space_state \
			.intersect_shape(query, 1).is_empty()

## Nine points spread through the zone's volume, low and high.
func _origins(bounds: AABB) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for fx: float in [0.2, 0.5, 0.8]:
		for fz: float in [0.15, 0.5, 0.85]:
			out.append(bounds.position + Vector3(
					bounds.size.x * fx,
					minf(1.0, bounds.size.y * 0.35),
					bounds.size.z * fz))
	return out

## Aims spanning the sphere, including straight up and straight down --
## the two that most easily produce "no hit" and "hit the floor you are
## standing on", which are properties 1 and 3.
func _aims() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for yaw_step: int in range(8):
		var yaw := TAU * float(yaw_step) / 8.0
		for pitch: float in [-0.9, -0.3, 0.0, 0.5]:
			out.append(Vector3(sin(yaw) * cos(pitch), sin(pitch),
					cos(yaw) * cos(pitch)).normalized())
	out.append(Vector3.UP)
	out.append(Vector3.DOWN)
	return out

func _chamber_spec(kind: String) -> Dictionary:
	match kind:
		"corridor":
			return {"chamber_id": "c1", "kind": "corridor",
					"params": {"length": 16.0, "width": 5.0},
					"objective": "none"}
		"arena":
			return {"chamber_id": "c1", "kind": "arena",
					"params": {"width": 20.0, "depth": 18.0,
							"wall_height": 6.0,
							"enemies": [{"archetype": "melee", "count": 2}]},
					"objective": "kill_all"}
		"platform_path":
			return {"chamber_id": "c1", "kind": "platform_path",
					"params": {"platforms": 5, "gap": 3.0, "rise": 1.2},
					"objective": "reach_exit"}
		"tower":
			return {"chamber_id": "c1", "kind": "tower",
					"params": {"floors": 3, "radius": 7.0},
					"objective": "reach_exit"}
		_:
			return {"chamber_id": "c1", "kind": "treasure_room",
					"params": {"reward_location_id": 89100004},
					"objective": "none"}
