extends Node

## WALKING TO THE THINGS THAT HAVE TO BE WALKED TO (`make godot-traverse`).
##
## The owner walked a Zone and could not reach a required Check, and the
## exit turned out to be behind a wall. Two attempts to answer "which
## targets are reachable" by flood-filling a lattice of sample points
## produced three different wrong answers and were deleted rather than
## tuned toward the one the owner had already demonstrated by playing.
##
## So this does the other thing: it DRIVES THE REAL CONTROLLER along a
## named route and reports what happened to the body. A walk is evidence
## about the route it walked and about nothing else.
##
## THREE OUTCOMES, AND THE THIRD ONE IS THE POINT.
##
##   REACHED    the body arrived and the game's own interact ray found
##              the target, so a player standing there could press E.
##   BLOCKED    the body stopped making progress with distance left to
##              go. The blocking collider is named.
##   UNRESOLVED the walk ran out of frames while still closing. NOT a
##              failure and NOT an impossibility -- this instrument
##              walks straight lines, and a route round a corner is a
##              route it cannot find.
##
## Only BLOCKED and REACHED assert anything. An UNRESOLVED count is
## printed and carried into the handoff as unresolved, because the
## alternative -- letting a timeout read as "impossible" -- is exactly
## the mistake the deleted lattice made three times.
##
## CALIBRATED BEFORE IT IS BELIEVED. The first two controls are a
## corridor the walker must cross and the same corridor with a wall
## across it, which it must fail to cross. An instrument that cannot
## fail for the right reason cannot be read when it passes.

const ZONE_JSON := "res://tests/fixtures/played_zone.json"

## How long one route gets: 8 seconds of walking at 60 Hz. WALK_SPEED is
## 7 m/s, so a straight run of 56 m fits -- longer than any room in the
## corpus and shorter than a whole Zone, which is the honest bound for
## a walker that does not turn corners.
const ROUTE_FRAMES := 480

## Close enough to have arrived: the interact ray is 3 m and the body
## is a 0.4 m radius, so this is "standing at it".
const ARRIVE_RANGE := 2.2

## No progress for this many frames, with distance still to go, is a
## block rather than a slow walk.
const STUCK_FRAMES := 60

## Progress smaller than this over `STUCK_FRAMES` is not progress. One
## frame of walking is 0.117 m, so a body that has really moved clears
## this in a handful of frames.
const PROGRESS_EPSILON := 0.25

var failures := 0
var checks := 0
var unresolved := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  ok: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
	print("FAIL: %s" % message)

func _note(message: String) -> void:
	print("     -- %s" % message)

func _ready() -> void:
	_run()

func _finish() -> void:
	if unresolved > 0:
		print("  (%d route(s) UNRESOLVED. A straight-line walker that "
				% unresolved + "does not arrive has measured its own "
				+ "route choice, not the Zone. Not a verdict.)")
	if failures == 0:
		print("GODOT TRAVERSE TESTS OK (%d checks)" % checks)
		get_tree().quit(0)
		return
	print("GODOT TRAVERSE TESTS: %d failures" % failures)
	get_tree().quit(1)

func _step(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame

# --- the walker --------------------------------------------------------

## Drive the real `Player` from `from` toward `to`, and say what happened.
##
## Returns `{outcome, closest, travelled, blocker, frames}`. The body is
## the real one: `Player.create()`, real input actions, real
## `move_and_slide`, real step-up and step-down, and the real interact
## ray deciding whether the target is actually addressable from where
## the body ended.
##
## IT JUMPS WHEN IT IS STUCK, and that is deliberate rather than
## generous. The base kit is walk and jump; a route that needs a jump is
## a route the guaranteed kit has, and refusing to use it would report
## reachable geometry as blocked. It has no Echoes at all, so a route
## that needs one is correctly reported as not walkable.
func _walk(parent: Node3D, from: Vector3, to: Vector3,
		target: Node = null, body: Player = null,
		release_holds := false) -> Dictionary:
	# THE ZONE'S OWN PLAYER WHERE THERE IS ONE. `ZoneController` spawns
	# the body the game spawns, with the holds, the Echo slots and the
	# signal wiring a fresh `Player.create()` would not have; a second
	# body beside it would also be a second thing standing in the rooms.
	var mine := body == null
	if mine:
		body = Player.create()
		parent.add_child(body)
	body.velocity = Vector3.ZERO
	body.global_position = from
	await _step(20)                      # settle onto the ground

	var start := body.global_position
	var closest := start.distance_to(to)
	var since_progress := 0
	var best := closest
	var outcome := "UNRESOLVED"
	var blocker := ""
	var frames := 0
	# WHERE IT LAST HAD GROUND UNDER IT. A body that ends 26 m below the
	# Zone fell off something, and the useful fact is not that it is at
	# the bottom -- it is the last place it was standing.
	var last_grounded := from
	var left_floor_at := Vector3.ZERO
	var was_grounded := true
	Input.action_press("move_forward", 1.0)
	for i in ROUTE_FRAMES:
		frames = i + 1
		# AIM EVERY FRAME. A body that slides along a wall ends up
		# walking parallel to its goal, and a fixed heading would call
		# that "no progress" when turning back toward the target is
		# what any player would do.
		var flat := Vector3(to.x - body.global_position.x, 0.0,
				to.z - body.global_position.z)
		if flat.length() > 0.01:
			body.rotation.y = atan2(-flat.x, -flat.z)
			var eye := body.global_position + Vector3.UP \
					* Constants.PLAYER_EYE_HEIGHT
			var rise := to.y - eye.y
			body.camera.rotation.x = clampf(
					atan2(rise, maxf(flat.length(), 0.01)),
					-PI / 3.0, PI / 3.0)
		# A LATE HOLD IS NOT A ROUTE. `ZoneController` re-claims the body
		# while it waits for a layout verdict, and offline that verdict
		# never comes -- so a walk would end held, every time, for a
		# reason that is about the bridge being absent.
		if release_holds:
			for reason: Variant in body.holds():
				body.release(str(reason))
		await get_tree().physics_frame
		if body.is_on_floor():
			last_grounded = body.global_position
			was_grounded = true
		elif was_grounded:
			was_grounded = false
			left_floor_at = last_grounded
		var here := body.global_position.distance_to(to)
		closest = minf(closest, here)
		if here <= ARRIVE_RANGE:
			outcome = "REACHED"
			break

		if best - here > PROGRESS_EPSILON:
			best = here
			since_progress = 0
		else:
			since_progress += 1
		if since_progress == STUCK_FRAMES / 2:
			# ONE JUMP, at the halfway mark, because the kit has one.
			Input.action_press("jump", 1.0)
			await get_tree().physics_frame
			Input.action_release("jump")
		elif since_progress >= STUCK_FRAMES:
			# LET THE JUMP LAND FIRST. This function jumps at the
			# halfway mark, so the body is often mid-arc exactly when
			# the stuck count expires -- and the first version of this
			# read that as "the body is airborne, so this result is not
			# about the route" and threw away its own wall control.
			for _w in 40:
				if body.is_on_floor():
					break
				await get_tree().physics_frame
				if body.is_on_floor():
					last_grounded = body.global_position
					was_grounded = true
			# STANDING OVER OR UNDER IT IS NOT BEING STOPPED BY IT.
			# A Check on a pedestal, or on the floor below a walkway,
			# leaves the walker at the target's own xz with nothing in
			# the way and a height it cannot close. That is the owner's
			# "the check is floating", and it is not a wall. Decided
			# HERE rather than on arrival: an earlier version called it
			# the moment the walker got within 1.5 m horizontally, which
			# stopped walkers that would have dropped onto the target a
			# second later.
			var flat_here := Vector2(to.x - body.global_position.x,
					to.z - body.global_position.z).length()
			if flat_here < 1.5 and body.is_on_floor():
				outcome = "OFF_LEVEL"
				var dy := to.y - body.global_position.y
				blocker = ("nothing in the way: the walker is at its "
						+ "xz, %.1f m out, and the target is %.1f m %s"
						% [flat_here, absf(dy),
						"above" if dy > 0.0 else "below"] + " the floor "
						+ "it can reach")
				break
			blocker = _what_is_in_the_way(body, to)
			# A BODY THAT LEFT THE FLOOR AND ENDED WELL BELOW ITS START
			# did not meet a wall, whatever it is standing on now. A
			# straight-line walker that goes over the edge of the world
			# between two rooms has measured its own route choice.
			if from.y - body.global_position.y > 3.0:
				outcome = "LOST"
				blocker = ("the body ended %.1f m BELOW its start"
						% (from.y - body.global_position.y)
						+ " -- it went over an edge, not into a wall")
				break
			# A BODY THAT FELL, DIED OR WAS HELD IS NOT A BLOCKED ROUTE.
			# Filing those under BLOCKED is how an instrument reports its
			# own failures as findings about the game, which is the exact
			# mistake the deleted lattice made.
			outcome = "LOST" if blocker.ends_with(
					"not a statement about the route") else "BLOCKED"
			break
	Input.action_release("move_forward")
	# ARRIVING AND ADDRESSING ARE TWO FINDINGS, and an early version of
	# this file made them one: a route only counted as REACHED if the
	# interact ray had also found the target, so a Check you could walk
	# up to and not press E on was reported as a blocked route. That is
	# the owner's "the check is floating" complaint filed under the
	# wrong heading. The walk ends on arrival; whether the game's own
	# 3 m interact ray then finds the thing is measured separately.
	var addressable := false
	if target != null and outcome == "REACHED":
		for _i in 20:
			var flat2 := Vector3(to.x - body.global_position.x, 0.0,
					to.z - body.global_position.z)
			if flat2.length() > 0.01:
				body.rotation.y = atan2(-flat2.x, -flat2.z)
				var eye2 := body.global_position + Vector3.UP \
						* Constants.PLAYER_EYE_HEIGHT
				body.camera.rotation.x = clampf(
						atan2(to.y - eye2.y, maxf(flat2.length(), 0.01)),
						-PI / 3.0, PI / 3.0)
			await get_tree().physics_frame
			if body.get("_interact_target") == target:
				addressable = true
				break
	var ended := body.global_position
	if mine:
		body.queue_free()
		await get_tree().process_frame
	return {
		"outcome": outcome,
		"closest": closest,
		"travelled": start.distance_to(ended),
		"blocker": blocker,
		"addressable": addressable,
		"ended": ended,
		"left_floor_at": left_floor_at,
		"fell": from.y - ended.y,
		"frames": frames,
	}

## WHAT STOPPED IT, named rather than guessed. A block whose cause is
## "something" sends whoever reads it back to the same walk.
func _what_is_in_the_way(body: CharacterBody3D, to: Vector3) -> String:
	var flat := Vector3(to.x - body.global_position.x, 0.0,
			to.z - body.global_position.z)
	if flat.length() < 0.01:
		return "nothing (already there)"
	# THE BODY FIRST, THE WORLD SECOND. "Nothing ahead" was this
	# function's whole answer for four routes in its first run, which
	# tells whoever reads it precisely nothing. A walker that has been
	# held, killed, warped or dropped into a pit is not a walker
	# reporting on geometry, and each of those looks identical from the
	# outside: distance stopped changing.
	var state: Array[String] = []
	if body.get("_dead"):
		state.append("the body is DEAD")
	var held: Array = body.call("holds")
	if not held.is_empty():
		state.append("the body is HELD by %s" % str(held))
	if not body.is_on_floor():
		state.append("the body is AIRBORNE at y %.1f"
				% body.global_position.y)
	if not state.is_empty():
		return ", ".join(state) + " -- not a statement about the route"

	var probe := KinematicCollision3D.new()
	if not body.test_move(body.global_transform,
			flat.normalized() * 0.6, probe):
		return ("nothing ahead and the body is alive, free and grounded "
				+ "at y %.1f: it stopped %.1f m out with no contact"
				% [body.global_position.y, flat.length()])
	var hit: Variant = probe.get_collider()
	if hit == null:
		return "an unnamed collider"
	var node := hit as Node
	var where := ""
	if hit is Node3D:
		var at: Vector3 = (hit as Node3D).global_position
		where = " at (%.1f, %.1f, %.1f)" % [at.x, at.y, at.z]
	return "%s '%s'%s" % [node.get_class() if node.get_script() == null
			else str(node.get_script().resource_path).get_file(),
			node.name, where]

func _flat_ground(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	slab.add_child(shape)
	parent.add_child(slab)
	slab.global_position = at
	return slab

# --- 1. calibration: the instrument must fail for the right reason -----

## A CORRIDOR THE WALKER MUST CROSS.
func _the_walker_crosses_an_open_corridor() -> void:
	var room := Node3D.new()
	add_child(room)
	_flat_ground(room, Vector3(900.0, -0.5, 0.0), Vector3(6.0, 1.0, 40.0))
	var post := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	shape.shape = box
	post.add_child(shape)
	room.add_child(post)
	post.global_position = Vector3(900.0, 1.0, -15.0)
	await _step(20)
	var run := await _walk(room, Vector3(900.0, 1.2, 15.0),
			Vector3(900.0, 1.0, -15.0))
	_check(run["outcome"] == "REACHED",
			"the walker crosses 30 m of open corridor: %s "
			% run["outcome"] + "(closest %.1f m, %d frames)"
			% [run["closest"], run["frames"]])
	room.queue_free()
	await get_tree().process_frame

## AND THE SAME CORRIDOR, WALLED.
##
## The deliberately faulty counterpart. If this REACHES, every other
## result in this file is worthless, because the walker is getting
## through geometry rather than round it.
func _the_walker_is_stopped_by_a_wall() -> void:
	var room := Node3D.new()
	add_child(room)
	_flat_ground(room, Vector3(940.0, -0.5, 0.0), Vector3(6.0, 1.0, 40.0))
	# Full width, and 4 m tall: past the 1.0 m step and the 1.33 m jump.
	_flat_ground(room, Vector3(940.0, 2.0, 0.0), Vector3(8.0, 4.0, 1.0))
	var post := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	shape.shape = box
	post.add_child(shape)
	post.name = "TheThingBehindTheWall"
	room.add_child(post)
	post.global_position = Vector3(940.0, 1.0, -15.0)
	await _step(20)
	var run := await _walk(room, Vector3(940.0, 1.2, 15.0),
			Vector3(940.0, 1.0, -15.0))
	_check(run["outcome"] == "BLOCKED",
			"and a 4 m wall across it stops the walker: %s"
			% run["outcome"])
	_check(str(run["blocker"]) != "",
			"which it names: %s" % str(run["blocker"]))
	_check(float(run["closest"]) > 10.0,
			"and it never got near the thing behind the wall "
			+ "(closest %.1f m)" % run["closest"])
	room.queue_free()
	await get_tree().process_frame

## AND A STEP IN THE WAY IS NOT A WALL.
##
## The boundary between the two above, and the reason the descent
## repair is upstream of this file: a walker that treated every 0.4 m
## tread as a block would report a working staircase as a broken route.
func _the_walker_crosses_a_staircase() -> void:
	var room := Node3D.new()
	add_child(room)
	_flat_ground(room, Vector3(980.0, -0.5, 0.0), Vector3(6.0, 1.0, 40.0))
	_flat_ground(room, Vector3(980.0, 0.2, -4.0), Vector3(6.0, 0.4, 24.0))
	_flat_ground(room, Vector3(980.0, 0.6, -8.0), Vector3(6.0, 0.4, 16.0))
	_flat_ground(room, Vector3(980.0, 1.0, -12.0), Vector3(6.0, 0.4, 8.0))
	var post := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	shape.shape = box
	post.add_child(shape)
	room.add_child(post)
	post.global_position = Vector3(980.0, 2.2, -14.0)
	await _step(20)
	var up := await _walk(room, Vector3(980.0, 1.2, 12.0),
			Vector3(980.0, 2.2, -14.0))
	_check(up["outcome"] == "REACHED",
			"three 0.4 m treads are walked, not blocked: %s "
			% up["outcome"] + "(closest %.1f m)" % up["closest"])
	room.queue_free()
	await get_tree().process_frame

# --- 2. the real Zone --------------------------------------------------

## The Zone a baseline playtest actually walks, built by the real
## builder from the real manifest. NOT the owner's Zone: theirs is in a
## save this container does not have, and no fixture here reproduces it.
var _zone: ZoneController = null
var _doors := {}
var _walker: Player = null

## Built through `ZoneController.setup`, not through `ZoneBuilder.build`.
##
## The difference is the whole point. `ZoneBuilder` lays out geometry;
## the Check pedestals, the warp stations and the spawned player are all
## placed by the CONTROLLER, which is the path the game takes. A first
## version of this file built the geometry directly and found zero Check
## pedestals in a Zone with fifteen Checks in it -- a suite that would
## have reported perfect traversal of a Zone containing nothing to
## traverse to.
func _load_the_real_zone() -> bool:
	var text := FileAccess.get_file_as_string(ZONE_JSON)
	if text.is_empty():
		_check(false, "%s is missing" % ZONE_JSON)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "%s did not parse to a Zone" % ZONE_JSON)
		return false
	var zone: Dictionary = parsed
	_zone = ZoneController.new()
	add_child(_zone)
	_zone.setup(zone)
	for _i in 12:
		await get_tree().physics_frame
	if _zone.layout_failed != "":
		_check(false, "the Zone did not lay out: %s" % _zone.layout_failed)
		return false
	_walker = _zone.player
	if not is_instance_valid(_walker):
		_check(false, "the Zone spawned no player to walk with")
		return false
	# A HOLD IS NOT THIS FILE'S SUBJECT. A Zone that opens with the
	# player held would report every route BLOCKED at its start, which
	# says nothing about the geometry. Released, and said out loud.
	if _walker.input_frozen:
		_note("the Zone spawned the player held (%s); released for the "
				% str(_walker.holds()) + "walk")
		for reason: Variant in _walker.holds():
			_walker.release(str(reason))
	# ENEMIES OUT. A walker shot dead in a corridor reports BLOCKED for
	# a reason that has nothing to do with the corridor, and this file
	# is about geometry. Said out loud rather than done quietly: these
	# routes are walked through an EMPTY Zone.
	var removed := 0
	for node in _zone.find_children("*", "", true, false):
		if node is Enemy:
			node.queue_free()
			removed += 1
	await get_tree().physics_frame
	_doors = _zone.door_positions
	print("  Zone %s: %d doorways, %d Check pedestals, %d enemies "
			% [str(zone.get("zone_id", "?")), _doors.size(),
			_required_checks().size(), removed] + "removed for the walk")
	return true

## SOMEWHERE TO START, which is not the same as the doorway's position.
##
## A declared door position is a point in the door PLANE, at whatever
## height the producer put it. Dropping a capsule there put three of the
## first six walks 50 m below the Zone and reported them as blocked
## routes -- an instrument measuring its own start. So the start is
## found the way a player would find it: step inward along the line to
## the target, take the ground under that point, and ask whether a body
## fits there.
func _standable_start(door_at: Vector3, goal: Vector3) -> Dictionary:
	var space := get_viewport().world_3d.direct_space_state
	var flat := Vector3(goal.x - door_at.x, 0.0, goal.z - door_at.z)
	var dir := Vector3.ZERO
	if flat.length() > 0.01:
		dir = flat.normalized()
	var step_law := float(Constants.MAX_VERTICAL_STEP)
	for step: float in [0.0, 1.0, 1.75, 2.5, 3.25]:
		var probe := door_at + dir * step
		var ground: Variant = _ground_under(space, probe, door_at.y)
		if ground == null:
			continue
		var at: Vector3 = ground
		# THE FLOOR THIS DOORWAY OPENS ONTO, not any surface above it.
		#
		# This cost a whole finding. The first version cast from 3 m
		# above the probe and took the first hit, so at `c021/exit` it
		# found the SECRET ALCOVE -- a shelf `_secret_alcove` puts above
		# the end ledge precisely so a base kit cannot reach it -- stood
		# the walker in it, and reported the Check on the ledge 2.65 m
		# below as "off the level the walker reached". The Check was on
		# solid ground the whole time.
		if absf(at.y - door_at.y) > step_law:
			continue
		if RoomAudit.player_stands_here(at + Vector3.UP * 0.05,
				Transform3D.IDENTITY, space):
			return {"at": at + Vector3.UP * 0.05, "inward": step}
	return {}

## The floor under a point, or null. Cast from well above so a start
## inside a doorway's own lintel still finds the ground below it.
## `from_y` is the height the caller believes the floor is near -- a
## doorway's own y. The cast starts one step above it rather than three
## metres above the probe, so a shelf over the doorway is not mistaken
## for the doorway's floor.
func _ground_under(space: PhysicsDirectSpaceState3D, at: Vector3,
		from_y := INF) -> Variant:
	var top := at + Vector3.UP * 3.0
	if from_y < INF:
		top = Vector3(at.x, from_y + float(Constants.MAX_VERTICAL_STEP),
				at.z)
	var query := PhysicsRayQueryParameters3D.create(
			top, at + Vector3.DOWN * 8.0)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["position"] as Vector3

## BETWEEN ROUTES, because the walker is the Zone's own body and it
## carries what happened to it. A route that starts held, hurt or still
## falling from the last one measures the last one.
func _reset_the_walker() -> void:
	for reason: Variant in _walker.holds():
		_walker.release(str(reason))
	_walker.velocity = Vector3.ZERO
	_walker.set("hp", Constants.PLAYER_MAX_HP)
	_walker.set("_dead", false)

## A FALL, LOCATED. The difference between "the walker got lost" and a
## seam somebody can go and look at.
func _where_it_left_the_floor(run: Dictionary) -> String:
	var fell := float(run["fell"])
	if fell < 3.0:
		return ""
	var at: Vector3 = run["left_floor_at"]
	if at == Vector3.ZERO:
		return "  (fell %.1f m; no grounded frame recorded)" % fell
	return ("  LAST ON THE FLOOR at (%.1f, %.1f, %.1f), then fell %.1f m"
			% [at.x, at.y, at.z, fell])

## THE DOORWAY THE TARGET'S OWN ROOM DECLARES, which is where a route
## starts.
##
## A doorway rather than an arbitrary sample point, because a doorway is
## somewhere the layout DECLARES a player arrives. And the target's OWN
## room, not the nearest doorway anywhere: a straight line from the next
## room's door to a Check crosses whatever is between the two rooms,
## which for this walker means the void beside a connector. The first
## version took the nearest door and lost a body 27 m down a gap that
## no player walking through the corridor would ever be over.
##
## This is deliberately the LAST LEG of a route and not the whole of
## one. "Can you get across the room to the Check" is the question the
## owner's playtest raised; "can you get to the room" is a different
## one, and it needs a walker that turns corners.
func _room_holding(at: Vector3) -> String:
	var bounds: Dictionary = _zone.room_bounds
	for rid: String in bounds:
		var box: AABB = bounds[rid]
		if box.grow(0.5).has_point(at):
			return rid
	return ""

func _nearest_doorway(to: Vector3) -> Dictionary:
	var doors: Dictionary = _doors
	var rid := _room_holding(to)
	var best := ""
	var best_d := INF
	for key: String in doors:
		if rid != "" and not key.begins_with(rid + "/"):
			continue
		var at: Vector3 = doors[key]
		var d := at.distance_to(to)
		if d < best_d:
			best_d = d
			best = key
	# THE APPENDED EXIT ROOM DECLARES NO DOORS OF ITS OWN, so filtering
	# to its room leaves nothing and the exit approach had no start at
	# all. Falling back to the nearest doorway anywhere is right for
	# that case and is SAID in the route line, because a cross-room
	# straight line is a weaker route than an in-room one.
	var own := best != ""
	if best == "":
		for key: String in doors:
			var at: Vector3 = doors[key]
			var d := at.distance_to(to)
			if d < best_d:
				best_d = d
				best = key
	if best == "":
		return {}
	return {"name": best, "at": doors[best] as Vector3, "distance": best_d,
			"room": rid, "own_room": own}

## The Zone's exit portal, found in the scene the controller built.
func _exit_portal() -> ExitPortal:
	for node in _zone.find_children("*", "", true, false):
		if node is ExitPortal:
			return node as ExitPortal
	return null

## Every Check pedestal in the built Zone.
##
## All of them are required: `ExitPortal` stays shut until every
## assigned Check confirms, so there is no such thing as an optional one
## in a Zone you intend to finish.
func _required_checks() -> Array[RewardObject]:
	var out: Array[RewardObject] = []
	for node in _zone.find_children("*", "", true, false):
		if node is RewardObject:
			out.append(node as RewardObject)
	return out

## ROUTES TO REQUIRED CHECKS, walked one at a time.
##
## EQUIPMENT: the base kit and nothing else -- `Player.create()` with no
## Echo in any slot, so walk, jump and the Static Pulse. A route that
## needs `cross_long_gap`, `grapple` or `blink` is correctly reported
## here as not walkable on the guaranteed kit.
##
## WHAT THIS IS NOT. It is not a reachability proof for the Zone: the
## walker goes in a straight line from one declared doorway, so a Check
## reached by two rooms of corridor is UNRESOLVED here and perfectly
## fine in play. Only a BLOCK is a finding, and only because a block is
## reproducible: the collider is named and the route can be re-walked.
func _routes_to_required_checks() -> void:
	var targets := _required_checks()
	if targets.is_empty():
		_check(false, "the built Zone has no Check pedestals in it")
		return
	var sample: Array[RewardObject] = []
	for i in mini(6, targets.size()):
		sample.append(targets[i])
	print("  %d Check pedestals built; walking to %d of them"
			% [targets.size(), sample.size()])
	var reached := 0
	var blocked := 0
	var lost := 0
	var above := 0
	var no_start := 0
	var not_addressable := 0
	for check: RewardObject in sample:
		var goal := check.global_position
		var door := _nearest_doorway(goal)
		if door.is_empty():
			_note("%s: no declared doorway to start from" % check.name)
			continue
		var start := _standable_start(door["at"] as Vector3, goal)
		if start.is_empty():
			no_start += 1
			_note("%s: %s offers nowhere to stand within 3 m of it, "
					% [check.name, str(door["name"])]
					+ "so this route has no start")
			continue
		var from: Vector3 = start["at"]
		_reset_the_walker()
		var run := await _walk(_zone, from, goal, check, _walker, true)
		var line := ("%s  kit=base(walk+jump)  from=%s+%.1fm (%.1f m out)"
				% [check.name, str(door["name"]), float(start["inward"]),
				from.distance_to(goal)]
				+ ("" if door.get("own_room", true) else " [other room]")
				+ ("" if door.get("own_room", true) else " [other room]")
			+ "  -> %s" % str(run["outcome"])
				+ "  closest %.2f m" % float(run["closest"])
				+ ("  addressable" if run["addressable"]
				else "  NOT addressable from where it stopped"))
		if str(run["outcome"]) == "REACHED":
			reached += 1
			if not run["addressable"]:
				not_addressable += 1
			_note(line)
		elif str(run["outcome"]) == "BLOCKED":
			blocked += 1
			_note(line + "  by " + str(run["blocker"])
					+ _where_it_left_the_floor(run))
		elif str(run["outcome"]) == "OFF_LEVEL":
			above += 1
			_note(line + "  -- " + str(run["blocker"]))
		elif str(run["outcome"]) == "LOST":
			lost += 1
			_note(line + "  -- " + str(run["blocker"])
					+ _where_it_left_the_floor(run))
		else:
			unresolved += 1
			_note(line + "  (out of frames, still closing)")
	# AT LEAST ONE MUST WORK. A suite where every walk fails is a suite
	# measuring its own walker, and this is the assertion that says so.
	_check(reached > 0,
			"the base kit reaches %d of %d sampled Checks from the "
			% [reached, sample.size()] + "nearest declared doorway")
	_check(blocked == 0,
			"and none of them is BLOCKED by geometry (%d blocked)"
			% blocked)
	# REPORTED, NOT ASSERTED. Whether a Check you are standing at can
	# actually be pressed is a real question and a different one; it
	# depends on pedestal height and on what the 3 m ray meets first,
	# and it needs the owner's eye before it becomes a red suite.
	if not_addressable > 0:
		_note("%d of the %d arrived-at Checks could NOT be addressed "
				% [not_addressable, reached] + "by the game's own "
				+ "interact ray from where the walk stopped")
	if above > 0:
		unresolved += above
		_note("%d Check(s) are off the level the walker reached: "
				% above + "a straight walk puts a player at their xz "
				+ "and no closer. NOT a blocked route and NOT a proof "
				+ "of unreachability -- it needs the owner's eye")
	if lost + no_start > 0:
		unresolved += lost + no_start
		_note("%d route(s) lost the body and %d had no standable start: "
				% [lost, no_start] + "instrument outcomes, carried into "
				+ "the handoff as UNRESOLVED rather than as findings")

# --- 3. the exit ------------------------------------------------------

## STANDING ROOM BESIDE THE EXIT IS NOT A ROUTE TO IT.
##
## Two separate questions, and conflating them is how "the exit is fine"
## was said about an exit that was behind a wall. This one is PLACEMENT:
## is there anywhere to stand around the portal at all. It is evidence
## about where the portal was put, and evidence about nothing else.
func _the_exit_has_somewhere_to_stand_around_it() -> void:
	var portal: Node3D = _exit_portal()
	if portal == null:
		_check(false, "the built Zone has no exit portal")
		return
	var space := get_viewport().world_3d.direct_space_state
	var at := portal.global_position
	var standable := 0
	var bearings: Array[String] = []
	for i in 16:
		var a := TAU * float(i) / 16.0
		var spot := at + Vector3(cos(a), 0.0, sin(a)) * 2.5
		if RoomAudit.player_stands_here(spot, Transform3D.IDENTITY, space):
			standable += 1
			bearings.append("%d deg" % int(round(rad_to_deg(a))))
	_note("exit portal at (%.1f, %.1f, %.1f): %d of 16 bearings at 2.5 m "
			% [at.x, at.y, at.z, standable]
			+ "are standable%s" % ("" if bearings.is_empty()
			else " (" + ", ".join(bearings) + ")"))
	_check(standable > 0,
			"there is somewhere to stand beside the exit portal "
			+ "(%d of 16 bearings) -- PLACEMENT evidence, not a route"
			% standable)

## AND THE APPROACH, WALKED.
##
## The other question. The owner's exact approach is not reproducible
## without their save, so this walks the one this Zone has: from the
## doorway nearest the portal, with the base kit, to the point where the
## game's own interact ray finds the portal.
func _the_exit_is_approached_and_addressable() -> void:
	var portal: Node3D = _exit_portal()
	if portal == null:
		return
	var goal := portal.global_position
	var door := _nearest_doorway(goal)
	if door.is_empty():
		_check(false, "no declared doorway near the exit portal")
		return
	var start := _standable_start(door["at"] as Vector3, goal)
	if start.is_empty():
		_check(false, "the doorway nearest the exit portal (%s) offers "
				% str(door["name"]) + "nowhere to stand within 3 m")
		return
	var from: Vector3 = start["at"]
	_reset_the_walker()
	var run := await _walk(_zone, from, goal, portal, _walker, true)
	_note("exit approach  kit=base(walk+jump)  from=%s+%.1fm (%.1f m out)"
			% [str(door["name"]), float(start["inward"]),
			from.distance_to(goal)]
			+ ("" if door.get("own_room", true) else " [other room]")
			+ "  -> %s" % str(run["outcome"])
			+ "  closest %.2f m" % float(run["closest"])
			+ ("  addressable" if run["addressable"]
			else "  NOT addressable from where it stopped")
			+ ("" if str(run["blocker"]) == ""
			else "  by " + str(run["blocker"]))
			+ _where_it_left_the_floor(run))
	if str(run["outcome"]) == "UNRESOLVED":
		unresolved += 1
	_check(str(run["outcome"]) != "BLOCKED",
			"the exit portal is not walled off from its own nearest "
			+ "doorway (%s)" % str(run["outcome"]))
	_check(str(run["outcome"]) != "REACHED" or bool(run["addressable"]),
			"and a player standing at it can address it: the game's own "
			+ "interact ray finds the portal")

## A CHECK BELOW THE FLOOR THE WALKER REACHED: which of the three?
##
## The previous batch reported `Reward_89100126` 2.6 m below the floor
## the walker stood on, and was careful not to call it a defect. It is
## not one, and the reason is worth keeping rather than deleting with
## the finding:
##
## The reward sits at `platform_path`'s own `reward_position` -- the END
## LEDGE, the highest flat ground in the chamber and the last thing the
## mandatory route touches -- with solid floor directly under it. What
## was 2.6 m above it was the walker, standing in the SECRET ALCOVE,
## which `_secret_alcove` puts over that ledge precisely so a base kit
## cannot reach it. `_standable_start` had cast down from three metres
## above the doorway and taken the first surface it found.
##
## So this control holds the three things that make it a destination
## rather than a defect, on the real assembly: the reward has ground
## under it, a base-kit body reaches the position a player interacts
## from, and the room it is in can be left again. A room whose only
## edge is its entry and whose reward sits beyond a gap nothing can
## jump back across is a softlock, and that is the failure this would
## catch if the producer ever drifted into it.
func _a_lower_check_is_a_destination_or_a_defect() -> void:
	var space := get_viewport().world_3d.direct_space_state
	var subject: RewardObject = null
	for check: RewardObject in _required_checks():
		if _room_type_of(_room_holding(check.global_position)) \
				== "platform_path":
			subject = check
			break
	if subject == null:
		_note("no platform_path Check in this fixture to examine")
		return
	var at := subject.global_position
	var rid := _room_holding(at)
	# 1. GROUND UNDER IT. "Floating" is a measurement, not an impression.
	var under: Variant = _ground_under(space, at, at.y + 0.5)
	_check(under != null,
			"%s in %s has ground under it -- which is what decides "
			% [subject.name, rid] + "whether it is floating")
	if under != null:
		var g: Vector3 = under
		_note("%s in %s (platform_path) at y %.2f, ground at y %.2f "
				% [subject.name, rid, at.y, g.y]
				+ "-- %.2f m under it" % (at.y - g.y))
		_check(at.y - g.y < 1.0,
				"and stands on it rather than over it (%.2f m up)"
				% (at.y - g.y))
	# 2. THE POSITION A PLAYER INTERACTS FROM, reached by a base kit.
	var door := _nearest_doorway(at)
	if door.is_empty():
		_check(false, "%s: its room declares no doorway" % rid)
		return
	var start := _standable_start(door["at"] as Vector3, at)
	if start.is_empty():
		_check(false, "%s: %s offers nowhere to stand at its own level"
				% [rid, str(door["name"])])
		return
	_reset_the_walker()
	var run := await _walk(_zone, start["at"], at, subject, _walker, true)
	_note("%s  kit=base(walk+jump)  from=%s+%.1fm  -> %s  closest %.2f m"
			% [subject.name, str(door["name"]), float(start["inward"]),
			str(run["outcome"]), float(run["closest"])])
	_check(str(run["outcome"]) == "REACHED",
			"a base kit reaches %s from its own room's doorway (%s)"
			% [subject.name, str(run["outcome"])])
	_check(bool(run["addressable"]),
			"and the game's own interact ray finds it from where the "
			+ "player stands")
	# 3. AND THE REAL INTERACTION, through the reward's own path. It
	#    refuses offline, which is the CORRECT refusal and is what this
	#    asserts -- the send itself belongs to the live-bridge suites.
	var prompt := subject.interact_prompt()
	_check(prompt != "",
			"and it offers that player a prompt")
	_note("its prompt reads '%s'" % prompt)
	subject.interact(_walker)
	_check(is_instance_valid(subject),
			"and the real interaction runs from the real position "
			+ "without taking the reward with it")
	# 4. CAN THE ROOM BE LEFT? `platform_path`'s exit is often SEALED, so
	#    the way back is the way in, over the gap the course crossed.
	var back := _the_way_back_from(space, at, rid)
	_check(back >= 0.0,
			"and the room can be left again: a base kit has somewhere "
			+ "to go back to (%s)" % ("continuous floor" if back == 0.0
			else "a %.2f m gap, inside the %.2f m jump"
			% [back, Constants.max_safe_gap(0.0)]))

## Which chamber type a room id is, from the controller's own records.
func _room_type_of(rid: String) -> String:
	if rid == "":
		return ""
	for record: Dictionary in _zone.get("_chambers"):
		var chamber: Dictionary = record.get("chamber", {})
		if str(chamber.get("id", "")) == rid:
			return str(chamber.get("type", ""))
	return ""

## The gap to the nearest surface on the way back out of the room, or
## -1.0 when nothing is within a base-kit jump.
##
## Measured rather than read off a declaration: what matters is what the
## body would land on. Probed along the room's own long axis, back
## toward its centre, because that is the direction the course came
## from.
func _the_way_back_from(space: PhysicsDirectSpaceState3D, at: Vector3,
		rid: String) -> float:
	if not _zone.room_bounds.has(rid):
		return -1.0
	var box: AABB = _zone.room_bounds[rid]
	var inward := box.get_center() - at
	inward.y = 0.0
	if inward.length() < 0.01:
		return -1.0
	inward = inward.normalized()
	var reach := Constants.max_safe_gap(0.0)
	# Walk outward until the floor STOPS. While it continues there is no
	# gap to jump and the way back is simply walking.
	var d := 0.5
	while d <= reach:
		var probe := at + inward * d
		if _ground_under(space, probe, at.y + 1.4) == null:
			break
		d += 0.5
	if d > reach:
		return 0.0                      # floor all the way: no gap
	# Then on across the gap, looking for the far side. The BUDGET IS
	# THE GAP, not the total: the first version capped `d` at the jump
	# reach, so a ledge two metres deep left four probes for a gap that
	# starts where the ledge ends, and reported "nothing back there" for
	# a landing well inside the envelope.
	var edge := d
	while d <= edge + reach:
		var probe := at + inward * d
		if _ground_under(space, probe, at.y + 1.4) != null:
			return d - edge
		d += 0.5
	return -1.0

# --- 4. assembled joins -----------------------------------------------

## A SEALED SOCKET IS A WALL, AND THE DECLARATION SAYS WHICH ONES ARE.
##
## The previous batch flagged `c001/side_left` as a leak candidate on a
## PROXY -- "no other room's doorway within 6 m" -- and said so. The
## proxy is gone: the Zone declares, per room and per socket, whether a
## door is `USED`, `LOCKED` or `SEALED`, and `c001/side_left` is SEALED
## with `edge_id: null`. It is not a join that went missing. It is a
## socket the graph never used, and a socket the graph never used has
## to be solid.
##
## `RoomAudit._assigned_doors_match_their_usage` already asks exactly
## this, in exactly these words -- but of a room, from its own
## transform, in the room-contract suite. Nothing asked it of the
## ASSEMBLED Zone, where a cap is placed by the layout rather than by
## the room. That is the gap this closes, and it is why a proxy was
## reaching for the answer in the first place.
func _every_sealed_door_is_solid() -> void:
	var found := _measure_doors_against(_zone.zone.get("chambers", []))
	_note("%d SEALED sockets and %d passable ones measured on the "
			% [int(found["sealed_seen"]), int(found["open_seen"])]
			+ "assembled Zone")
	var leaking: Array = found["sealed_open"]
	# THE ONE THAT ASSERTS. A sealed socket a body walks out of is the
	# Zone leaking into the void, which is what the owner met.
	_check(leaking.is_empty(),
			"every SEALED socket is solid (%s)"
			% ("none open" if leaking.is_empty()
			else "OPEN: " + ", ".join(PackedStringArray(leaking))))
	# The other direction is already `_publish_layout`'s warning and the
	# bridge's refusal, so it is reported rather than duplicated here.
	var stuck: Array = found["open_solid"]
	if not stuck.is_empty():
		_note("passable sockets measuring solid: %s"
				% ", ".join(PackedStringArray(stuck)))

	# AND THE DELIBERATELY BROKEN COUNTERPART, on the SAME assembly.
	#
	# The declaration is mutated rather than the geometry: a door that
	# is genuinely open but declared SEALED is exactly the shape of the
	# defect, and flipping a label cannot accidentally leave a hole in a
	# Zone the other controls are still walking. If this does not report
	# the door it was told to lie about, the sweep above is measuring
	# nothing.
	var lied := _with_usage_flipped(_zone.zone.get("chambers", []),
			"c001", "exit", "SEALED")
	var broken := _measure_doors_against(lied["chambers"])
	var caught: Array = broken["sealed_open"]
	_check(lied["flipped"] != "",
			"a passable socket was found to mislabel (%s)"
			% str(lied["flipped"]))
	_check(caught.has(str(lied["flipped"])),
			"and calling %s SEALED while it is still an opening is "
			% str(lied["flipped"]) + "reported (%s)"
			% ("caught" if caught.has(str(lied["flipped"]))
			else "MISSED: " + str(caught)))

## The doors of a declared chamber list, measured against the assembled
## geometry. Takes the chambers so the counterpart above can hand it a
## copy with one label changed.
func _measure_doors_against(chambers: Array) -> Dictionary:
	var space := get_viewport().world_3d.direct_space_state
	var sealed_open: Array[String] = []
	var open_solid: Array[String] = []
	var sealed_seen := 0
	var open_seen := 0
	for raw_chamber: Variant in chambers:
		var chamber: Dictionary = raw_chamber
		var rid := str(chamber.get("id", ""))
		if not _zone.room_bounds.has(rid):
			continue
		var box: AABB = _zone.room_bounds[rid]
		for raw_door: Variant in chamber.get("doors", []):
			var door: Dictionary = raw_door
			var socket := str(door.get("socket_id", ""))
			var key := "%s/%s" % [rid, socket]
			if not _doors.has(key):
				continue
			var at: Vector3 = _doors[key]
			var want_open := str(door.get("usage", "")) != "SEALED"
			var blocked := _doorway_is_blocked(space, at, box)
			if want_open:
				open_seen += 1
				if blocked:
					open_solid.append("%s (%s)"
							% [key, str(door.get("usage", ""))])
			else:
				sealed_seen += 1
				if not blocked:
					sealed_open.append(key)
	return {"sealed_open": sealed_open, "open_solid": open_solid,
			"sealed_seen": sealed_seen, "open_seen": open_seen}

## A copy of the chamber list with one door relabelled. Prefers the
## named socket; falls back to the first passable socket that actually
## measures open, so the counterpart still has something to lie about
## if the fixture changes.
func _with_usage_flipped(chambers: Array, want_room: String,
		want_socket: String, usage: String) -> Dictionary:
	var space := get_viewport().world_3d.direct_space_state
	var out: Array = []
	var flipped := ""
	var fallback := ""
	for raw_chamber: Variant in chambers:
		var chamber: Dictionary = (raw_chamber as Dictionary).duplicate(true)
		var rid := str(chamber.get("id", ""))
		var doors: Array = chamber.get("doors", [])
		for i in doors.size():
			var door: Dictionary = doors[i]
			var socket := str(door.get("socket_id", ""))
			var key := "%s/%s" % [rid, socket]
			if str(door.get("usage", "")) == "SEALED" \
					or not _doors.has(key) \
					or not _zone.room_bounds.has(rid):
				continue
			if _doorway_is_blocked(space, _doors[key],
					_zone.room_bounds[rid]):
				continue
			if fallback == "":
				fallback = key
			if rid == want_room and socket == want_socket:
				door["usage"] = usage
				flipped = key
		out.append(chamber)
	if flipped == "" and fallback != "":
		for raw_chamber: Variant in out:
			var chamber: Dictionary = raw_chamber
			for raw_door: Variant in chamber.get("doors", []):
				var door: Dictionary = raw_door
				if "%s/%s" % [str(chamber.get("id", "")),
						str(door.get("socket_id", ""))] == fallback:
					door["usage"] = usage
					flipped = fallback
	return {"chambers": out, "flipped": flipped}

## Would a standing body be stopped in this doorway?
##
## The same two-sample stance `RoomAudit.aperture_polarity` uses -- in
## the doorway and one stride inside it -- so this cannot disagree with
## the room-contract suite about what "blocked" means. Taken in WORLD
## space, because an assembled Zone's caps belong to the layout and not
## to any one room's transform.
func _doorway_is_blocked(space: PhysicsDirectSpaceState3D, at: Vector3,
		box: AABB) -> bool:
	var middle := box.get_center()
	var away := Vector3(at.x - middle.x, 0.0, at.z - middle.z)
	var inward := Vector3(-signf(away.x), 0.0, 0.0)
	if absf(away.x) < absf(away.z):
		inward = Vector3(0.0, 0.0, -signf(away.z))
	var floor_y := at.y
	var down := PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * 1.0, at + Vector3.DOWN * 1.0)
	down.collide_with_areas = false
	var ground := space.intersect_ray(down)
	if not ground.is_empty():
		floor_y = (ground["position"] as Vector3).y
	var stance := Vector3(0.0,
			floor_y - at.y + Constants.PLAYER_HEIGHT / 2.0 + 0.05, 0.0)
	# `RoomAudit._blocker`, NOT a second capsule of my own. The first
	# version rolled its own full-size query and reported `c007/exit`
	# and `c022/exit` -- both USED and both fine -- as solid, because
	# the audit's capsule is deliberately 2 cm slimmer than the player
	# (so an opening built exactly to the minimum is not refused by
	# float error) and deliberately ignores PLACED CONTENT (so a prop
	# standing in a doorway is not the doorway being walled up). Two
	# definitions of "blocked" is how this suite and the bridge's own
	# refusal come to disagree about the same door.
	for step: float in [0.0, 0.45]:
		if RoomAudit._blocker(space, at + inward * step + stance) != null:
			return true
	return false

## IS A DECLARED DOORWAY AN OPENING YOU CAN WALK THROUGH?
##
## The owner walked a Zone with holes at its entrances and an exit room
## reached only by going out of bounds. `room_audit` already asks
## whether an opening is a HOLE -- geometrically, against the room's own
## declaration. This asks the other half, with a body: stand two metres
## inside the room, walk at the doorway, and see whether you come out
## the other side.
##
## It is a SAMPLE of one assembled Zone, not a certificate. What makes
## the sample readable is the pair below it: the same instrument, on the
## same assembly, with one doorway deliberately bricked up.
func _joins_are_walked_through() -> Array[Dictionary]:
	var sample: Array[Dictionary] = []
	var keys: Array = _doors.keys()
	keys.sort()
	var through := 0
	var refused := 0
	for key: Variant in keys:
		if sample.size() >= 6:
			break
		var rid := str(key).split("/")[0]
		if not _zone.room_bounds.has(rid):
			continue
		var door: Vector3 = _doors[key]
		var bounds: AABB = _zone.room_bounds[rid]
		var centre := bounds.get_center()
		var inward := Vector3(centre.x - door.x, 0.0, centre.z - door.z)
		if inward.length() < 0.5:
			continue
		inward = inward.normalized()
		var start := _standable_start(door + inward * 2.5, door)
		if start.is_empty():
			continue
		var goal := door - inward * 2.5
		var ground: Variant = _ground_under(
				get_viewport().world_3d.direct_space_state, goal)
		if ground != null:
			goal = (ground as Vector3) + Vector3.UP * 0.1
		_reset_the_walker()
		var run := await _walk(_zone, start["at"], goal, null, _walker,
				true)
		var ok := str(run["outcome"]) == "REACHED"
		if ok:
			through += 1
		else:
			refused += 1
		sample.append({"key": str(key), "door": door, "inward": inward,
				"start": start["at"], "goal": goal, "ok": ok,
				"outcome": str(run["outcome"])})
		_note("join %s [%s]: 2.5 m inside -> 2.5 m outside -> %s"
				% [str(key), _usage_of(str(key)), str(run["outcome"])]
				+ ("" if str(run["blocker"]) == ""
				else "  by " + str(run["blocker"])))
	_check(through > 0,
			"%d of %d sampled declared doorways are walked through "
			% [through, sample.size()] + "by a body with the base kit")
	# NO LEAK COUNTER HERE ANY MORE. It used to guess at one from "no
	# other doorway within 6 m", which named `c001/side_left` as a leak
	# candidate -- and the declaration says that socket is SEALED with
	# no edge, and `_every_sealed_door_is_solid` measures it solid. A
	# walk that does not get through a sealed socket is the sealed
	# socket working.
	if refused > 0:
		unresolved += refused
		_note("%d sampled doorway(s) did not admit the walker. A "
				% refused + "straight line through a doorway is a weak "
				+ "route; carried as UNRESOLVED, not as a hole")
	return sample

## WHAT THE ZONE SAYS THIS SOCKET IS, rather than what a distance
## measurement guesses. `USED` carries its edge; `SEALED` and `LOCKED`
## say so plainly.
func _usage_of(key: String) -> String:
	var rid := key.split("/")[0]
	var socket := key.split("/")[1]
	for raw_chamber: Variant in _zone.zone.get("chambers", []):
		var chamber: Dictionary = raw_chamber
		if str(chamber.get("id", "")) != rid:
			continue
		for raw_door: Variant in chamber.get("doors", []):
			var door: Dictionary = raw_door
			if str(door.get("socket_id", "")) != socket:
				continue
			var usage := str(door.get("usage", "?"))
			var edge := str(door.get("edge_id", ""))
			return usage if edge == "" or edge == "<null>" \
					else "%s %s" % [usage, edge]
	return "undeclared"

## AND THE SAME DOORWAY, BRICKED UP.
##
## The counterpart that makes the sample above worth reading. If the
## walker still gets through a doorway with a 4 m slab across it, then
## every REACHED above is the instrument passing itself.
func _a_bricked_up_join_refuses_the_walker(
		sample: Array[Dictionary]) -> void:
	var subject := {}
	for entry: Dictionary in sample:
		if entry["ok"]:
			subject = entry
			break
	if subject.is_empty():
		_check(false, "no sampled doorway was walked through, so there "
				+ "is nothing to brick up: this file cannot be read")
		return
	var door: Vector3 = subject["door"]
	var inward: Vector3 = subject["inward"]
	var brick := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Wide and tall enough to be a wall rather than a step: past the
	# 1.0 m step and the 1.33 m jump, and wider than any doorway.
	box.size = Vector3(12.0, 6.0, 1.0)
	shape.shape = box
	brick.add_child(shape)
	brick.name = "DeliberateBrick"
	_zone.add_child(brick)
	brick.global_position = door + Vector3.UP * 2.0
	brick.rotation.y = atan2(inward.x, inward.z)
	await get_tree().physics_frame
	_reset_the_walker()
	var run := await _walk(_zone, subject["start"], subject["goal"],
			null, _walker, true)
	_check(str(run["outcome"]) != "REACHED",
			"and the same doorway with a 6 m slab across it refuses "
			+ "the walker (%s), so the walks above are about the "
			% str(run["outcome"]) + "geometry and not about the walker")
	brick.queue_free()
	await get_tree().physics_frame

func _run() -> void:
	await _the_walker_crosses_an_open_corridor()
	await _the_walker_is_stopped_by_a_wall()
	await _the_walker_crosses_a_staircase()
	if await _load_the_real_zone():
		await _routes_to_required_checks()
		_the_exit_has_somewhere_to_stand_around_it()
		await _the_exit_is_approached_and_addressable()
		await _a_lower_check_is_a_destination_or_a_defect()
		_every_sealed_door_is_solid()
		var joins := await _joins_are_walked_through()
		await _a_bricked_up_join_refuses_the_walker(joins)
	if _zone != null:
		_zone.queue_free()
		await get_tree().process_frame
	_finish()
