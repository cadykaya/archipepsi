extends "res://tests/transport_driver.gd"
## D13 1d / DESS'S D-4 — A DOORWAY HELD OPEN BY A DECLARED WEIGHT, PLAYED
## (`--held-route`).
##
##     make godot-held-route
##
## The Zone is `tests/fixtures/held_route_zone.json` (`make
## held-route-fixture`, `latched_route.compose_held_route` on the played
## Zone): an object-only MEDIUM plate in c002 whose `held_by` is a 40 kg
## `counterweight` homed in c002 (volume c001, c002), driving the shutter
## across e:c002:c003 DIRECTLY -- no LATCH. It is D-07's held sensor with
## D-07's guarantee: "Pressure present = active. Pressure removed =
## inactive. [...] If a puzzle genuinely requires a pressure plate to
## remain active, there must be a guaranteed physical way to keep pressure
## on it, such as a movable object/weight." Nothing below names those
## rooms; every case reads them from the fixture.
##
## **WHAT IS PLAYED, on the real player and real physics:** the rooms
## cleared with the base kit; the player alone on the plate (nothing: the
## plate is object-only); the weight picked up with the interact ray,
## carried onto the plate and put down; the doorway opening and STAYING
## open while it rests, with nobody near; through into the far room and
## back; the weight lifted by hand (the doorway shuts: held, never
## latched) and put back (it opens again).
##
## **HARNESS STEPS, each declared where it happens:** releasing the
## layout hold once the verdict wait ends with no bridge (as every offline
## Zone driver does); rebuilding the Zone from the pose its own
## `object_settled` reported, standing in for the bridge's `object_poses`
## across a reload; and, for the interlock, moving the weight off the
## plate while the player stands in the doorway. A hand cannot do that
## here -- the plate stands about 4 m from its doorway and the interact
## ray reaches 3 m -- so the move stands in for anything else that shifts
## the weight (a push, a knock) while somebody is under the panel.

const HELD_FIXTURE := "res://tests/fixtures/held_route_zone.json"
const WEIGHT := "counterweight"
const PLATE_ID := "weight_plate"
const SHUTTER_ID := "route_shutter"
## Horizontal distance, carried body to plate centre, at which the walk
## onto the plate stops and the weight is put down.
const OVER_PLATE_M := 0.3


func _only() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--held-only="):
			return arg.substr("--held-only=".length())
	return ""


func _run() -> void:
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(HELD_FIXTURE))
	var only := _only()
	if only != "":
		_note("running ONE case, '%s' -- not the suite" % only)
	if only == "survey":
		await _survey(zone_data)
	if only in ["", "build"]:
		await _the_held_route_builds(zone_data)
	var left := {}
	if only in ["", "played", "restore"]:
		left = await _the_weight_holds_the_doorway(zone_data)
	if only in ["", "restore"] and not left.is_empty():
		await _a_reload_puts_the_weight_back_and_the_door_opens(zone_data,
				left)
	if only in ["", "interlock"]:
		await _shifted_with_the_player_in_the_doorway(zone_data)
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_back", "move_left",
			"move_right", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	if failures == 0:
		print("GODOT HELD ROUTE OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT HELD ROUTE TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------------------
# The route, read off the built Zone and the declaration it was built from
# ---------------------------------------------------------------------------

func _held_edge(zone_data: Dictionary) -> Dictionary:
	for raw: Variant in zone_data.get("edges", []) as Array:
		if str((raw as Dictionary).get("opened_by", "")) == SHUTTER_ID:
			return raw
	return {}


func _held(controller: ZoneController, zone_data: Dictionary) -> Dictionary:
	var edge := _held_edge(zone_data)
	if controller.signal_graphs.is_empty() or edge.is_empty():
		_check(false, "the held route was built: graphs %s, refusals %s"
				% [controller.signal_graphs.size(),
					controller.signal_graph_refusals])
		return {}
	var graph: SignalGraph = controller.signal_graphs[0]
	var room := graph.room_id
	var frame := RoomGraphs.doorway_frame(room, edge,
			zone_data.get("chambers", []) as Array, controller.door_frames)
	var box: AABB = controller.room_bounds[room]
	var far := str(edge.get("room_b", "")) \
			if str(edge.get("room_a", "")) == room \
			else str(edge.get("room_a", ""))
	var binding: Variant = graph.actuators.get(SHUTTER_ID)
	var shutter: Variant = (binding as Dictionary).get("node") \
			if typeof(binding) == TYPE_DICTIONARY else binding
	return {"graph": graph, "room": room, "far_room": far,
			"plate": graph.sensors.get(PLATE_ID), "shutter": shutter,
			"frame": frame, "box": box,
			"far_box": controller.room_bounds[far],
			"inward": _inward_of(frame, box),
			"weight": controller.objects.body_of(WEIGHT)}


## Horizontal distance from the weight to the plate's centre.
func _off_centre(weight: Node3D, plate: Node3D) -> float:
	return Vector2(weight.global_position.x - plate.global_position.x,
			weight.global_position.z - plate.global_position.z).length()


## Is the weight lying on the plate's top, inside its footprint?
func _on_plate(weight: Node3D, plate: ClassPlate) -> bool:
	var local := weight.global_position - plate.global_position
	return absf(local.x) < plate.size.x * 0.5 \
			and absf(local.z) < plate.size.z * 0.5 \
			and local.y > 0.0 and local.y < 1.0


## WALK THE CARRIED WEIGHT OVER THE PLATE AND PUT IT DOWN, with the real
## `move_forward` and `interact`: face the plate's centre, level, walk
## until the body carried 1.2 m ahead is over it, stop, and press.
func _carry_onto(controller: ZoneController, plate: ClassPlate,
		weight: ManipulableBody) -> bool:
	var player := controller.player
	var target := plate.global_position
	var closest := INF
	for _i in 900:
		var to := target - player.global_position
		to.y = 0.0
		if to.length() > 0.01:
			player.rotation.y = atan2(-to.x, -to.z)
		player.camera.rotation.x = 0.0
		var over := _off_centre(weight, plate)
		closest = minf(closest, over)
		if over < OVER_PLATE_M:
			break
		Input.action_press("move_forward")
		await get_tree().physics_frame
	Input.action_release("move_forward")
	for _i in 60:
		if Vector2(player.velocity.x, player.velocity.z).length() < 0.05:
			break
		await get_tree().physics_frame
	if _off_centre(weight, plate) > plate.size.x * 0.4:
		_note("the carry stopped %.2f m off the plate's centre (closest "
				% _off_centre(weight, plate) + "%.2f); player at %v"
				% [closest, player.global_position])
	BridgeClient.sent_intents.clear()
	await _press("interact")
	await _settle(120)
	return not player.carry.holding()


## DIAGNOSTIC ONLY (`--held-only=survey`): where things stand in the
## plate's room. Prints; checks nothing.
func _survey(zone_data: Dictionary) -> void:
	var controller := await _enter(zone_data)
	var route := _held(controller, zone_data)
	var room := str(route.get("room", ""))
	var plate: Node3D = route.get("plate")
	var weight: Node3D = route.get("weight")
	var frame: Dictionary = route.get("frame", {})
	print("SURVEY room %s box %s arrival %v" % [room, route.get("box"),
			RoomGraphs.place_of(controller.room_places, room).get("arrival",
				Vector3.INF)])
	print("SURVEY door %v yaw %.2f inward %v" % [frame.get("position",
			Vector3.INF), float(frame.get("yaw", 0.0)), route.get("inward")])
	print("SURVEY plate %v  weight %v" % [plate.global_position,
			weight.global_position])
	var floor_y: float = RoomGraphs.place_of(controller.room_places,
			room).get("arrival", Vector3.ZERO).y
	var space := controller.get_world_3d().direct_space_state
	var exclude := [controller.player.get_rid(), weight.get_rid()]
	# Per cell: the ground under 1.5 m, and the lowest overhead surface
	# above the floor (to 4 m). 0.5 m cells, x down the page, z across.
	for ix in range(-12, 13):
		var line := ""
		for iz in range(-10, 11):
			var at := plate.global_position + Vector3(ix * 0.5, 0.0, iz * 0.5)
			at.y = floor_y
			var down := PhysicsRayQueryParameters3D.create(
					at + Vector3(0, 1.5, 0), at + Vector3(0, -1.0, 0))
			down.exclude = exclude
			var hit := space.intersect_ray(down)
			var ground := -9.0 if hit.is_empty() \
					else (hit["position"] as Vector3).y - floor_y
			var up := PhysicsRayQueryParameters3D.create(
					at + Vector3(0, 0.05, 0), at + Vector3(0, 4.0, 0))
			up.exclude = exclude
			var over := space.intersect_ray(up)
			var head := 9.9 if over.is_empty() \
					else (over["position"] as Vector3).y - floor_y
			var mark := "."
			if ground < -1.0:
				mark = " "
			elif ground > 0.3:
				mark = "#"
			elif ground > 0.05:
				mark = "p"
			if head < 2.0:
				mark = "g" if mark == "." or mark == "p" else mark
			line += mark
		print("SURVEY x%+5.1f %s" % [ix * 0.5, line])
	await _drop(controller)


# ---------------------------------------------------------------------------
# 1. Built as declared
# ---------------------------------------------------------------------------

func _the_held_route_builds(zone_data: Dictionary) -> void:
	print("  -- the declaration builds: an object-only plate, its weight, "
			+ "its doorway shut")
	var controller := await _enter(zone_data)
	var route := _held(controller, zone_data)
	if route.is_empty():
		await _drop(controller)
		return
	var plate: Variant = route["plate"]
	var weight: Variant = route["weight"]
	var shutter: Variant = route["shutter"]
	_check(controller.signal_graph_refusals.is_empty()
			and controller.object_socket_refusals.is_empty(),
			"nothing refused: graphs %s, sockets %s"
			% [controller.signal_graph_refusals,
				controller.object_socket_refusals])
	_check(plate is ClassPlate and not (plate as ClassPlate).counts_player
			and (plate as ClassPlate).requires == MassClass.MEDIUM,
			"the sensor is an object-only MEDIUM plate (%s)"
			% [(plate as ClassPlate).reading() if plate is ClassPlate
				else plate])
	_check(weight is ManipulableBody
			and is_equal_approx((weight as ManipulableBody).mass, 40.0)
			and (weight as ManipulableBody).mass_class() == MassClass.MEDIUM
			and controller.objects.room_of(WEIGHT) == route["room"]
			and _copies(WEIGHT) == 1,
			"its weight is built: one 40 kg MEDIUM '%s' at home in %s"
			% [WEIGHT, controller.objects.room_of(WEIGHT)])
	_check(shutter is ServiceShutter and (shutter as ServiceShutter).is_shut()
			and plate is ClassPlate and not (plate as ClassPlate).satisfied(),
			"the doorway starts shut, the plate empty")
	# SAID, NOT LEFT TO BE GUESSED (D-07): the plate names its weight and
	# the rule, and the weight names what it is for.
	var sign := (plate as Node).get_node_or_null("HeldSign") as Label3D \
			if plate is Node else null
	var tag := (weight as Node).get_node_or_null("WeightSign") as Label3D \
			if weight is Node else null
	_check(sign != null and "COUNTERWEIGHT" in sign.text
			and "HOLDS THE SHUTTER OPEN" in sign.text,
			"the plate says what holds it: '%s'"
			% (sign.text.replace("\n", " / ") if sign != null else "(no sign)"))
	_check(tag != null and "COUNTERWEIGHT · 40 kg" in tag.text
			and "LOAD PLATE" in tag.text,
			"and the weight says what it is for: '%s'"
			% (tag.text.replace("\n", " / ") if tag != null else "(no label)"))
	var door: Vector3 = (route["frame"] as Dictionary).get("position",
			Vector3.ZERO)
	if plate is ClassPlate and weight is Node3D:
		_note("the plate stands %.1f m from its doorway; the weight's "
				% Vector2((plate as Node3D).global_position.x - door.x,
					(plate as Node3D).global_position.z - door.z).length()
				+ "home is %.1f m from the plate"
				% (weight as Node3D).global_position.distance_to(
					(plate as Node3D).global_position))
	await _drop(controller)


# ---------------------------------------------------------------------------
# 2. Played: the weight holds the doorway open, and only while it rests
# ---------------------------------------------------------------------------

func _the_weight_holds_the_doorway(zone_data: Dictionary) -> Dictionary:
	print("  -- played: the weight carried onto the plate holds the doorway "
			+ "open while it rests there")
	_deaths = 0
	_taken = 0.0
	var controller := await _enter(zone_data)
	var player: Player = controller.player
	var route := _held(controller, zone_data)
	if route.is_empty():
		await _drop(controller)
		return {}
	var room := str(route["room"])
	var far_room := str(route["far_room"])
	var plate: ClassPlate = route["plate"]
	var weight: ManipulableBody = route["weight"]
	var shutter: ServiceShutter = route["shutter"]
	var graph: SignalGraph = route["graph"]
	var door: Vector3 = (route["frame"] as Dictionary)["position"]
	var inward: Vector3 = route["inward"]

	# ---- clear the way first: a carrying player cannot fire -----------
	if not await _advance_to(controller, room):
		await _drop(controller)
		return {}

	# ---- the player alone is not a load --------------------------------
	await _walk_to(player, plate.global_position, AABB(), 900, false, 0.3)
	await _settle(120)
	var standing := Vector2(player.global_position.x
			- plate.global_position.x, player.global_position.z
			- plate.global_position.z).length()
	_check(standing < plate.size.x * 0.5 and not plate.satisfied()
			and shutter.is_shut(),
			"STANDING ON THE PLATE, %.2f m from its centre: it reads %s "
			% [standing, plate.reading()["classes"]]
			+ "and the doorway stays shut (object-only)")

	# ---- pick the weight up ----------------------------------------------
	var seen := await _approach(controller, weight, 1.3)
	_check(seen and player._last_prompt == "[E] PICK UP · 40 kg",
			"looking at the weight offers \"%s\"" % player._last_prompt)
	await _press("interact")
	_check(player.carry.holding() and player.carry.body == weight,
			"picked up with `interact`")

	# ---- onto the plate ----------------------------------------------
	var put := await _carry_onto(controller, plate, weight)
	var settled := _intents("object_settled")
	_check(put and _on_plate(weight, plate) and plate.satisfied(),
			"PUT DOWN ON THE PLATE, %.2f m from its centre: it reads %s"
			% [_off_centre(weight, plate), plate.reading()["classes"]])
	_check(not settled.is_empty()
			and str((settled.back() as Dictionary).get("object_id", ""))
				== WEIGHT
			and str((settled.back() as Dictionary).get("room_id", ""))
				== room,
			"and its resting pose was reported in %s (%d report(s))"
			% [room, settled.size()])
	var opened := await _wait_for(func() -> bool: return shutter.is_open(),
			300)
	_check(opened, "the doorway OPENS under the weight (%.2f)"
			% shutter.openness())
	_check(graph.latched.is_empty(),
			"and nothing latched: the plate drives the shutter directly")

	# ---- it stays open while the weight rests, with nobody near --------
	await _walk_to(player, door + inward * 1.4, AABB(), 600, false, 0.5)
	var dropped_open := 0
	for _i in 300:
		await get_tree().physics_frame
		if not shutter.is_open():
			dropped_open += 1
	_check(dropped_open == 0 and plate.satisfied(),
			"it STAYS OPEN for 5 s with the weight resting and the player "
			+ "at the doorway (%d frame(s) not open)" % dropped_open)

	# ---- through, and back -------------------------------------------
	var through := await _walk_into(controller, far_room)
	var far_box: AABB = route["far_box"]
	_check(bool(through["inside"])
			and far_box.has_point(player.global_position),
			"THROUGH: walked into %s (ended %v)"
			% [far_room, player.global_position])
	_check(shutter.is_open() and plate.satisfied(),
			"the doorway is still open behind the player")
	# BACK THE WAY THEY CAME: turned round, through the same doorway.
	# (`_walk_into` from a platform path crosses the whole path first,
	# which is a journey onward, not a return.)
	await _walk_to(player, door + inward * 2.5, AABB(), 900, false, 0.5)
	var box: AABB = route["box"]
	_check(box.has_point(player.global_position) and _deaths == 0,
			"AND BACK: returned into %s through the held doorway (ended %v)"
			% [room, player.global_position])

	# ---- lifted: pressure removed, inactive ----------------------------
	var lifted := await _approach(controller, weight, 1.3)
	await _press("interact")
	_check(lifted and player.carry.holding() and not plate.satisfied(),
			"LIFTED off the plate by hand: it reads %s"
			% [plate.reading()["classes"]])
	var shut := await _wait_for(func() -> bool: return shutter.is_shut(),
			400)
	_check(shut and graph.latched.is_empty(),
			"and the doorway SHUTS: held, never latched (%.2f open)"
			% shutter.openness())

	# ---- put back: pressure present again, active again ------------------
	put = await _carry_onto(controller, plate, weight)
	opened = await _wait_for(func() -> bool: return shutter.is_open(), 300)
	_check(put and plate.satisfied() and opened,
			"PUT BACK: the plate reads %s and the doorway opens again"
			% [plate.reading()["classes"]])
	settled = _intents("object_settled")
	var left := {}
	if not settled.is_empty():
		var last: Dictionary = settled.back()
		var at: Array = last["position"]
		left = {"room": str(last["room_id"]),
				"pose": Vector3(float(at[0]), float(at[1]), float(at[2])),
				"yaw": float(last["yaw"])}
	_check(not left.is_empty() and str(left["room"]) == room
			and (left["pose"] as Vector3).distance_to(
				weight.global_position) < 0.05,
			"the reported pose is where it lies on the plate: %s report(s), "
			% settled.size() + "the last %.3f m from it (%v, lying at %v)"
			% [(left["pose"] as Vector3).distance_to(weight.global_position)
				if not left.is_empty() else INF,
				left.get("pose", Vector3.INF), weight.global_position])
	_check(_deaths == 0 and _copies(WEIGHT) == 1,
			"no death (%d) and still exactly one weight (%d)"
			% [_deaths, _copies(WEIGHT)])
	await _drop(controller)
	return left


# ---------------------------------------------------------------------------
# 3. Reloaded: the weight's pose, not the plate's state, opens the door
# ---------------------------------------------------------------------------

func _a_reload_puts_the_weight_back_and_the_door_opens(
		zone_data: Dictionary, left: Dictionary) -> void:
	print("  -- reloaded: the weight is back on the plate and the doorway "
			+ "opens, with no plate state saved")
	var room := str(left["room"])
	var pose: Vector3 = left["pose"]
	# HARNESS STEP: rebuilt from the pose the Zone reported, which is all
	# the bridge's `object_poses` holds for it. No latch and no plate state
	# is carried, because none exists to carry.
	var controller := await _enter(zone_data, {
		"rooms": {WEIGHT: room},
		"poses": {WEIGHT: [room, pose, float(left["yaw"])]},
	})
	var route := _held(controller, zone_data)
	if route.is_empty():
		await _drop(controller)
		return
	var plate: ClassPlate = route["plate"]
	var weight: ManipulableBody = route["weight"]
	var shutter: ServiceShutter = route["shutter"]
	var graph: SignalGraph = route["graph"]
	_check(controller.latches_carried.is_empty() and graph.latched.is_empty(),
			"nothing latched was carried in, and nothing is latched")
	_check(weight != null and _copies(WEIGHT) == 1
			and weight.global_position.distance_to(pose) < 0.1,
			"one weight, restored where it was left (%.3f m off)"
			% (weight.global_position.distance_to(pose)
				if weight != null else INF))
	var opened := await _wait_for(func() -> bool: return shutter.is_open(),
			300)
	_check(opened and plate.satisfied() and _on_plate(weight, plate),
			"the doorway OPENS because the weight is on the plate (%.2f)"
			% shutter.openness())
	await _drop(controller)


# ---------------------------------------------------------------------------
# 4. The interlock: the weight shifts while the player is in the doorway
# ---------------------------------------------------------------------------

func _shifted_with_the_player_in_the_doorway(zone_data: Dictionary) -> void:
	print("  -- the weight leaves the plate with the player in the doorway: "
			+ "the panel holds off them")
	var controller := await _enter(zone_data)
	var player: Player = controller.player
	var route := _held(controller, zone_data)
	if route.is_empty():
		await _drop(controller)
		return
	var room := str(route["room"])
	var plate: ClassPlate = route["plate"]
	var weight: ManipulableBody = route["weight"]
	var shutter: ServiceShutter = route["shutter"]
	var door: Vector3 = (route["frame"] as Dictionary)["position"]
	var inward: Vector3 = route["inward"]
	if not await _advance_to(controller, room):
		await _drop(controller)
		return
	var home := weight.global_position
	await _approach(controller, weight, 1.3)
	await _press("interact")
	await _carry_onto(controller, plate, weight)
	await _wait_for(func() -> bool: return shutter.is_open(), 300)
	# INTO THE DOORWAY ITSELF, under the panel.
	await _walk_to(player, door, AABB(), 600, false, 0.3)
	await _settle(30)
	_check(shutter.is_open() and shutter.doorway_occupied(),
			"standing in the open doorway, under the panel (occupied %s)"
			% shutter.doorway_occupied())
	var hp := player.hp
	var at := player.global_position
	# HARNESS STEP: the weight moved off the plate while the player is in
	# the doorway -- a hand cannot reach it from here (see the header).
	weight.linear_velocity = Vector3.ZERO
	weight.angular_velocity = Vector3.ZERO
	weight.global_position = home
	weight.sleeping = false
	var lowest := 1.0
	for _i in 180:
		await get_tree().physics_frame
		lowest = minf(lowest, shutter.openness())
	_check(not plate.satisfied() and shutter.refusals() >= 1,
			"the plate is empty and the panel was refused its closure %d "
			% shutter.refusals() + "time(s) while the doorway was occupied")
	_check(lowest > 0.5 and player.hp >= hp
			and player.global_position.distance_to(at) < 0.3,
			"it never came down on the player: lowest %.2f open, %.0f hp "
			% [lowest, player.hp] + "(was %.0f), moved %.2f m"
			% [hp, player.global_position.distance_to(at)])
	# OUT OF THE DOORWAY, back into the room: now it may shut.
	await _walk_to(player, door + inward * 2.5, AABB(), 600, false, 0.5)
	var shut := await _wait_for(func() -> bool: return shutter.is_shut(),
			400)
	_check(shut and not shutter.doorway_occupied(),
			"stepped out of the doorway: it SHUTS (%.2f open)"
			% shutter.openness())
	await _drop(controller)
