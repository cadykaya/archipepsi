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
# m of the waypoint that counts as reached. THE DEFAULT IS WIDER THAN SOME
# ROUTES ARE. 1.2 m of slop in a 2.5 m service passage lets the body turn a
# corner up to 1.2 m early -- which is how it came to turn west while still
# south of the plant's north face and walk into the machine. So it is a
# property of the walk, and a route that threads a passage passes a tighter
# one. Tighter is STRICTER: the body has to reach each waypoint more nearly,
# and may cut less.
const ARRIVED := 1.2
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


func _walk(glb: String, waypoints: Array, budget: float,
		arrived: float = ARRIVED) -> Dictionary:
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
	# WHERE it jumped, not just how often. Twice now a jump count alone
	# has been diagnosed by reading the geometry and guessing, and twice
	# the guess was wrong. A number that cannot say where is a number you
	# argue with.
	var jumped_at := []
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
		if flat.length() < arrived and absf(here.y - goal.y) < 0.6:
			reached.append(leg)
			leg += 1
			continue

		var v := body.velocity
		if body.is_on_floor():
			v.y = 0.0
			if stalled > STALL_FRAMES:
				v.y = JUMP_VELOCITY
				jumps += 1
				var foot := body.global_position \
						- Vector3(0, PLAYER_HEIGHT / 2.0, 0)
				jumped_at.append([snappedf(foot.x, 0.1),
						snappedf(foot.y, 0.1), snappedf(foot.z, 0.1), leg])
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
		"arrived_within": arrived,
		"jumps": jumps,
		"jumped_at": jumped_at,
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

	# --- the branching rooms, inside ---------------------------------
	#
	# Crossing a doorway is `crossing_test.gd`'s question. This one is
	# whether the room BEHIND the doorway is navigable: can a body get
	# from the way in to each way out, and to the space the runtime puts
	# its content in. A junction whose branches are visible and
	# unreachable is worse than a corridor.
	var tri := "%s/batch044/shells/shell_junction_triad.glb" % _models
	_log["triad entry to exit"] = _walk(tri, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 13.0),
		Vector3(0.0, 0.0, 24.6)], 25.0)
	_log["triad entry to the east branch"] = _walk(tri, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 13.0),
		Vector3(11.6, 0.0, 13.0)], 25.0)
	_log["triad entry to the west bay"] = _walk(tri, [
		Vector3(0.0, 0.0, 1.4), Vector3(-4.0, 0.0, 13.0),
		Vector3(-9.6, 0.0, 13.0)], 25.0)

	# The cross is walked AROUND the plant on purpose: a straight line
	# from entry to exit goes through five metres of machine.
	var crs := "%s/batch044/shells/shell_junction_cross.glb" % _models
	# Every one of these goes UP THE ARM FIRST and then round the plant.
	# A straight line from the entry to anywhere else in this room passes
	# through either a corner fill or five metres of machine, which is the
	# room working: you cannot cut the corner of a plant room.
	# THROUGH THE BAY and THROUGH THE PASSAGE, which are now two different
	# walks rather than two halves of one ring.
	_log["cross entry to exit, through the bay"] = _walk(crs, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 8.0),
		Vector3(-5.0, 0.0, 10.0), Vector3(-5.0, 0.0, 22.0),
		Vector3(0.0, 0.0, 28.6)], 40.0, 0.5)
	# The fourth waypoint is the ROUTE, not a concession. Without it the
	# list asked the body to go from (7.7, 22.5) straight at the exit,
	# and that line crosses the north-east corner fill -- solid mass,
	# floor to roof -- at about x 5.8. The body stalled against it, jumped
	# (uselessly, 1.33 m of nothing), then slid west along the face and
	# completed anyway. That one jump was the harness cutting a corner
	# through a wall, not the room asking for a jump: the bay route walks
	# the same shape and reports none only because -5.0 happens to lie
	# inside the north arm's +-4 m mouth by 0.5 m. Walking the passage out
	# to the arm's centre line first is what a player does.
	_log["cross entry to exit, through the passage"] = _walk(crs, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 8.0),
		Vector3(7.7, 0.0, 11.0), Vector3(7.7, 0.0, 22.75),
		Vector3(0.0, 0.0, 22.75), Vector3(0.0, 0.0, 28.6)], 40.0, 0.5)
	_log["cross entry to the east branch"] = _walk(crs, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 8.0),
		Vector3(7.7, 0.0, 12.0), Vector3(13.6, 0.0, 15.0)], 40.0)
	_log["cross entry to the sump"] = _walk(crs, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 8.0),
		Vector3(-6.0, 0.0, 9.6)], 40.0)

	var bay := "%s/batch044/shells/shell_bay_terminus.glb" % _models
	_log["terminus entry to the prize"] = _walk(bay, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 12.0),
		Vector3(0.0, 0.0, 18.0)], 25.0)
	_log["terminus entry to the west door"] = _walk(bay, [
		Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 13.0),
		Vector3(-7.6, 0.0, 16.0)], 25.0)

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
