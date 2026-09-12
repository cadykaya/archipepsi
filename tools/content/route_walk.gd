extends SceneTree
## Walk a declared route with a player-shaped body, and say whether it ends.
##
##   godot --path godot -s _harness/route.gd -- <models> <out>
##
## The span-basin acceptance question is whether the CURRENT Player can
## complete the intended basin-to-deck route, including the final
## transition onto the deck -- not whether the stairs look finished. A ray
## dropped from above cannot answer it: rays are what measured this stair
## as three risers short when it has all sixteen and three of them were
## buried under the landing.
##
## So a body walks it. It heads for each waypoint at `WALK_SPEED`, and when
## it stops making horizontal progress with ground under it, it jumps --
## which is what a player does at a riser, and what a player MUST do here,
## because `move_and_slide` has no step-up and the measured walk-up limit
## is 0.12 m against a 0.875 m riser.
##
## NOT `player.gd`: Production's capsule, gravity, walk speed, jump
## velocity and floor angle, and the engine's own `move_and_slide`. No
## movement packages, no volumes, no assistance, no camera. It is evidence
## about the geometry of the route. The full-player proof is Production's.

const GRAVITY := 24.0
const WALK_SPEED := 7.0
const JUMP_VELOCITY := 8.0
const PLAYER_HEIGHT := 1.8
const PLAYER_RADIUS := 0.4
const FLOOR_MAX_ANGLE := deg_to_rad(46.0)
const STEP := 1.0 / 60.0
const ARRIVED := 1.2             # m of the waypoint that counts as reached
const STALL_FRAMES := 8          # frames of no progress before jumping

var _models: String
var _out: String
var _bench: GDScript
var _log := {}
var _problems: Array[String] = []


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <models-dir> <out-dir>")
	else:
		_models = a[0]
		_out = a[1]
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[route] FAIL: %s" % what)


func _collide(node: Node3D) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mi.mesh.create_trimesh_shape()
		body.add_child(shape)
		mi.add_child(body)


func _walk(glb: String, waypoints: Array, budget: float) -> Dictionary:
	var root := Node3D.new()
	get_root().add_child(root)
	var shell: Node3D = _bench.call("load_glb", glb)
	if shell == null:
		_fail("could not load %s" % glb)
		root.free()
		return {}
	root.add_child(shell)
	_collide(shell)

	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = PLAYER_HEIGHT
	capsule.radius = PLAYER_RADIUS
	shape.shape = capsule
	body.add_child(shape)
	body.floor_max_angle = FLOOR_MAX_ANGLE
	root.add_child(body)
	var start: Vector3 = waypoints[0]
	body.global_position = start + Vector3(0, PLAYER_HEIGHT / 2.0 + 0.05, 0)

	var leg := 1
	var jumps := 0
	var stalled := 0
	var last := start
	var highest := start.y
	var reached := []
	for _i in range(int(budget / STEP)):
		if leg >= waypoints.size():
			break
		var goal: Vector3 = waypoints[leg]
		var here := body.global_position - Vector3(0, PLAYER_HEIGHT / 2.0, 0)
		var flat := Vector3(goal.x - here.x, 0.0, goal.z - here.z)
		# Arrived at this waypoint when it is under foot AND at its height.
		if flat.length() < ARRIVED and absf(here.y - goal.y) < 0.6:
			reached.append(leg)
			leg += 1
			continue

		var v := body.velocity
		if body.is_on_floor():
			v.y = 0.0
			if stalled > STALL_FRAMES:
				v.y = JUMP_VELOCITY
				jumps += 1
				stalled = 0
		else:
			v.y -= GRAVITY * STEP
		var dir := flat.normalized() * WALK_SPEED
		v.x = dir.x
		v.z = dir.z
		body.velocity = v
		body.move_and_slide()

		# Stalled means NO PROGRESS TOWARD THE GOAL, not "did not move".
		# Measuring raw displacement counted being shoved sideways out of a
		# riser as progress, so the body never jumped once in 40 seconds.
		var after := body.global_position - Vector3(0, PLAYER_HEIGHT / 2.0, 0)
		var gained := Vector3(last.x - goal.x, 0.0, last.z - goal.z).length() \
				- Vector3(after.x - goal.x, 0.0, after.z - goal.z).length()
		if gained < WALK_SPEED * STEP * 0.25:
			stalled += 1
		else:
			stalled = 0
		last = after
		highest = maxf(highest, body.global_position.y - PLAYER_HEIGHT / 2.0)

	var end := body.global_position - Vector3(0, PLAYER_HEIGHT / 2.0, 0)
	var done := leg >= waypoints.size()
	root.free()
	return {
		"completed": done,
		"waypoints_reached": reached.size(),
		"waypoints_total": waypoints.size() - 1,
		"jumps": jumps,
		"highest_y": snappedf(highest, 0.01),
		"ended_at": [snappedf(end.x, 0.01), snappedf(end.y, 0.01),
				snappedf(end.z, 0.01)],
	}


func _run() -> void:
	# The declared route, then the final transition the request names:
	# up the flight, west onto the landing, and out onto the deck.
	var glb := "%s/batch040/shells/shell_span_basin.glb" % _models
	var south := [
		# On the basin, clear of the flight. The declared start [11.9, 0,
		# 2.6] is INSIDE tread0's box (z 1.60..2.70, y 0..0.88) -- a body
		# put there spawns in solid geometry and is shoved out, so the walk
		# begins on the floor the route begins on and arrives at the same
		# place.
		Vector3(11.9, 0.0, 0.9),
		Vector3(11.9, 14.0, 16.6),    # the flight's head, declared end
		Vector3(6.0, 14.0, 16.6),     # the landing
		Vector3(0.0, 14.0, 16.0),     # the deck
	]
	var north := [
		Vector3(11.9, 0.0, 89.0),
		Vector3(11.9, 14.0, 73.4),
		Vector3(6.0, 14.0, 73.4),
		Vector3(0.0, 14.0, 74.0),
	]
	_log["basin_south_to_deck"] = _walk(glb, south, 40.0)
	_log["basin_north_to_deck"] = _walk(glb, north, 40.0)

	for key: String in _log:
		print("[route] %s: %s" % [key, JSON.stringify(_log[key])])
		var got: Dictionary = _log[key]
		if not got.get("completed", false):
			_fail("%s: the player did not reach the deck -- %s"
					% [key, JSON.stringify(got)])

	if _out != "":
		var f := FileAccess.open("%s/route_walk.json" % _out, FileAccess.WRITE)
		if f == null:
			_fail("could not write route_walk.json under %s" % _out)
		else:
			f.store_string(JSON.stringify(_log, "  "))
			f.close()
	if _problems.is_empty():
		print("[route] both basin routes completed, onto the deck")
		quit(0)
		return
	quit(1)
