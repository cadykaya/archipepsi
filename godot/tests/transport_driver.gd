extends Node
## O05-02 / O05-03 — A REQUIRED OBJECT, CARRIED BETWEEN ROOMS AND
## INSTALLED (`--transport`).
##
##     make godot-transport
##
## The Zone is `tests/fixtures/transport_zone.json`, written by `make
## transport-fixture` from the played Zone through
## `transport_route.compose_transport`: today a 40 kg `power_cell` at
## home in c004, allowed in c004 -> c005, a `cell_socket` in c005 that
## sets `cell_power = powered`, lamps in c005 and c006, and the doorway
## e:c005:c006 declared shut until then. (Nothing below names those
## rooms; every case reads them from the fixture. The longer run through
## c006 is refused because the transit hall leaves 28 m above where it
## is entered -- P5-8.) It is entered through the same `ZoneController`
## an ordinary player enters through; nothing in it is edited here.
##
## **WHAT IS PLAYED, and what is not substituted.** The real player, on
## `move_forward`, `fire_pulse` and `interact`, through real collision:
## from the Zone's arrival, clearing each room with the base kit, into the
## shut doorway and stopped by it, back to the cell, picked up with the
## interact ray, carried through the real connectors (with no coordinate
## assignment between legs), aimed at the socket and installed, and then
## through the doorway the installation opened.
##
## **HARNESS STEPS, each declared where it happens:** releasing the
## layout hold once the verdict wait ends with no bridge (as P14's
## driver does); rebuilding a Zone from the progress its own intents
## reported, which stands in for the bridge's snapshot (the live suite,
## `godot-transport-live`, does the real restart); a second, wrong crate
## put down beside the socket; destroying the body to exercise the
## destroyed-object rule; placing Unweighted Switch's LIGHTENED
## applicator in the home room for the Status-continuity case; and
## removing a shielded Bulwark through the damage path, from behind,
## when the base-kit flank does not land (P5-7, counted in
## `harness_removals`).

const FIXTURE := "res://tests/fixtures/transport_zone.json"
const DT := 1.0 / 60.0
const CELL := "power_cell"
const SOCKET := "cell_socket"
const VARIABLE := "cell_power"

var failures := 0
var checks := 0
var notes: Array[String] = []

var _deaths := 0
var _taken := 0.0
var _last_hp := 0.0
var _held_frames := 0
var _feedback: Array = []
## Where the player stood, and what they were doing, for each feedback.
var _feedback_at: Array = []
var _prompts: Array = []
## The Zone being played, for chamber types and parameters.
var _zone_data: Dictionary = {}


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


## `--transport-only=<case>` runs one case, for iterating on it. The
## frozen run and CI run them all.
func _only() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--transport-only="):
			return arg.substr("--transport-only=".length())
	return ""


func _run() -> void:
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(FIXTURE))
	var only := _only()
	if only != "":
		_note("running ONE case, '%s' -- not the suite" % only)
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var reported := {"rooms": {CELL: str(volume[volume.size() - 1])},
			"consumed": {CELL: SOCKET}, "macro": {VARIABLE: "powered"}}
	if only in ["", "build"]:
		await _the_declaration_builds_one_object_one_socket_one_gate(
				zone_data)
	if only in ["", "journey"]:
		reported = await _the_journey_is_played_end_to_end(zone_data)
	if only in ["", "restore"]:
		await _installed_it_restores_installed_and_never_twice(zone_data,
				reported)
	if only in ["", "mid"]:
		await _placed_mid_branch_it_restores_where_it_was_left(zone_data)
	if only in ["", "wrong"]:
		await _a_wrong_object_is_refused_at_the_socket(zone_data)
	if only in ["", "volume"]:
		await _out_of_its_volume_it_comes_home_after_one_second(zone_data)
	if only in ["", "death"]:
		await _dying_while_carrying_drops_it_where_it_was(zone_data)
	if only in ["", "destroyed"]:
		await _a_destroyed_cell_comes_back_home_as_itself(zone_data)
	if only in ["", "interrupted"]:
		await _interrupted_beside_the_socket_it_is_not_installed(zone_data)
	if only in ["", "lightened"]:
		await _lightened_crosses_the_threshold_with_the_same_body(zone_data)
	_finish()


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

## Enter the Zone with whatever a snapshot would have carried.
func _enter(zone_data: Dictionary, carried := {}) -> ZoneController:
	_zone_data = zone_data
	var controller := ZoneController.new()
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	controller.add_child(pool)
	get_tree().root.add_child(controller)
	controller.macro_carried = carried.get("macro", {})
	controller.object_rooms_carried = carried.get("rooms", {})
	controller.object_poses_carried = carried.get("poses", {})
	controller.objects_consumed_carried = carried.get("consumed", {})
	BridgeClient.sent_intents.clear()
	controller.setup(zone_data)
	var player: Player = controller.player
	_feedback.clear()
	_feedback_at.clear()
	_prompts.clear()
	if player != null:
		player.stat_stack.pool = pool
		player.died.connect(func() -> void: _deaths += 1)
		player.carry_feedback.connect(
				func(text: String, _ok: bool) -> void:
					_feedback.append(text)
					_feedback_at.append("%s at %v (on floor %s, vy %.2f, "
							% [text, player.global_position,
								player.is_on_floor(), player.velocity.y]
							+ "room '%s', blocked by %s)" % [_room_holding(
								controller, player.global_position),
								player.carry.last_blocker]))
		player.interact_prompt_changed.connect(
				func(text: String) -> void: _prompts.append(text))
		_last_hp = player.hp
	# **HARNESS STEP: the verdict wait.** No bridge answers here; once the
	# controller has concluded the wait the hold is released, exactly as
	# `latched_route_driver._enter` does, and nothing else.
	_held_frames = 0
	for _i in 2400:
		if controller.layout_verdict != "":
			break
		await get_tree().physics_frame
		_held_frames += 1
	if player != null:
		player.release(ZoneController.LAYOUT_HOLD)
		player.input_frozen = false
	await _settle(4)
	return controller


func _drop(controller: ZoneController) -> void:
	for action: String in ["move_forward", "move_back", "move_left",
			"move_right", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	controller.queue_free()
	for _i in 4:
		await get_tree().process_frame
		await get_tree().physics_frame


func _settle(frames := 8) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _track_damage(player: Player) -> void:
	if player.hp < _last_hp:
		_taken += _last_hp - player.hp
	_last_hp = player.hp


func _intents(kind: String) -> Array:
	var out: Array = []
	for intent: Dictionary in BridgeClient.sent_intents:
		if str(intent.get("type", "")) == kind:
			out.append(intent)
	return out


## Every loose-or-seated body standing for `object_id` in the tree.
func _copies(object_id: String) -> int:
	var n := 0
	for node: Node in get_tree().root.find_children(
			"Transported_%s" % object_id, "ManipulableBody", true, false):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			n += 1
	return n


func _socket(controller: ZoneController) -> ObjectSocket:
	for raw: Variant in controller.object_sockets:
		var socket: ObjectSocket = raw
		if socket.mechanism_id == SOCKET:
			return socket
	return null


func _gate(controller: ZoneController) -> StateGates.StateGate:
	for raw: Variant in controller.state_gates:
		return raw
	return null


func _gated_edge(zone_data: Dictionary) -> Dictionary:
	for raw: Variant in zone_data.get("edges", []) as Array:
		if not ((raw as Dictionary).get("requires_state", []) as Array) \
				.is_empty():
			return raw
	return {}


func _lamps(controller: ZoneController) -> Array:
	var out: Array = []
	for raw: Variant in controller.zone_state_readers():
		var node: ZoneStateBuild.ZoneStateMechanism = raw
		if node.variable_id == VARIABLE:
			out.append(node)
	return out


# ---------------------------------------------------------------------------
# Walking -- the real body, on `move_forward`, through real collision
# (`latched_route_driver`'s walker, unchanged)
# ---------------------------------------------------------------------------

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
	# LOOK WHERE YOU WALK. Left pitched down from picking something up,
	# the camera carries the object along the floor.
	player.camera.rotation.x = 0.0
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
		# CARRYING, AND THE HELD OBJECT IS BEING PUSHED BACK: something is
		# in the way of it, not of the body. A player steers round that
		# before the object is squeezed out of their hands (§10.3's 0.40 m
		# rule), so this sidesteps at once rather than after a stall.
		var squeezed := player.carry != null and player.carry.holding() \
				and player.carry.body.global_position.distance_to(
					player.camera.global_position + Vector3.DOWN
					* HandCarry.BELOW_EYE_M) < HandCarry.FORWARD_M - 0.3
		if sidestepping > 0:
			sidestepping -= 1
			if sidestepping == 0:
				Input.action_release(sidestep)
				Input.action_press("move_forward")
		elif squeezed or (idle > 30 and idle % 30 == 1):
			# Squeezed: stop advancing into it while stepping aside.
			if squeezed:
				Input.action_release("move_forward")
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
## then the room's own arrival. From inside a platform path, its course is
## jumped first -- the room is crossed the way a player crosses it.
func _walk_into(controller: ZoneController, room: String) -> Dictionary:
	var standing := _room_holding(controller, controller.player.global_position)
	if standing != "" and standing != room \
			and str(_chamber(standing).get("type", "")) == "platform_path":
		var crossed := await _cross_platform_path(controller, standing)
		_check(crossed, "crossed the platform path %s on the real "
				% standing + "controller, island by island")
	var box: AABB = controller.room_bounds.get(room, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			room).get("arrival", box.get_center())
	var steps: Array[Vector3] = []
	var pieces: Array = controller.room_routes.get(room, []) as Array
	# LINE UP ON THE MOUTH FIRST: two metres short of the connector's
	# entry, along its own direction, then the entry itself. From across a
	# 59 m arena, a straight line to the first piece's far end meets the
	# doorframe at an angle and stalls there.
	if not pieces.is_empty():
		var first: Dictionary = pieces[0]
		if first.has("entry") and first.has("exit"):
			var along: Vector3 = (first["exit"] as Vector3) \
					- (first["entry"] as Vector3)
			along.y = 0.0
			if along.length() > 0.1:
				steps.append((first["entry"] as Vector3)
						- along.normalized() * 2.0)
			steps.append(first["entry"])
	for raw: Variant in pieces:
		var piece: Dictionary = raw
		if piece.has("exit"):
			steps.append(piece["exit"])
	steps.append(arrival)
	return await _follow(controller, steps, box)


## ON ALONG THE SPINE to `target`, room by room from wherever the player
## stands, clearing each room with the base kit on the way when asked.
func _advance_to(controller: ZoneController, target: String,
		clear := true) -> bool:
	var spine: Array = []
	for raw: Variant in _zone_data.get("chambers", []) as Array:
		spine.append(str((raw as Dictionary).get("id", "")))
	var goal := spine.find(target)
	if goal < 0:
		_check(false, "'%s' is not on the spine" % target)
		return false
	# A DEATH IS NOT THE END OF THE WALK. The player respawns at the
	# Zone's arrival with full health and the rooms they cleared stay
	# cleared; a person would walk back and carry on, and so does this.
	# Every death is counted and reported by the caller.
	for attempt in 3:
		var standing := _room_holding(controller,
				controller.player.global_position)
		var at := spine.find(standing)
		var ok := true
		for i in range(maxi(at, 0) + 1, goal + 1):
			var room := str(spine[i])
			var walk := await _walk_into(controller, room)
			if controller.player._dead:
				ok = false
				break
			if not bool(walk["inside"]):
				_check(false, "walked into %s (%.1f m, ended %v)"
						% [room, float(walk["walked"]),
							controller.player.global_position])
				return false
			if clear:
				await _cleared(controller, room)
			if controller.player._dead:
				ok = false
				break
		if ok:
			break
		_note("the player died on the way to %s (attempt %d); respawned "
				% [target, attempt + 1] + "at the arrival, walking on")
		await _wait_for(func() -> bool: return not controller.player._dead,
				int((Constants.RESPAWN_DELAY + 1.0) / DT))
		await _settle(10)
	_check(_room_holding(controller, controller.player.global_position)
			== target, "advanced along the spine to %s" % target)
	return true


## Back along the spine, room by room, to `target`. A death on the way
## respawns the player at the Zone's arrival, BEFORE the target: then the
## way there is forward again, and it is taken.
func _retreat_to(controller: ZoneController, target: String) -> bool:
	var spine: Array = []
	for raw: Variant in _zone_data.get("chambers", []) as Array:
		spine.append(str((raw as Dictionary).get("id", "")))
	var deaths_before := _deaths
	var ok := await _retreat_once(controller, target, spine)
	if not ok and _deaths > deaths_before:
		_note("the player died walking back to %s; respawned, walking on"
				% target)
		await _wait_for(func() -> bool: return not controller.player._dead,
				int((Constants.RESPAWN_DELAY + 1.0) / DT))
		await _settle(10)
		return await _advance_to(controller, target, false)
	return ok


func _retreat_once(controller: ZoneController, target: String,
		spine: Array) -> bool:
	var at := spine.find(_room_holding(controller,
			controller.player.global_position))
	var goal := spine.find(target)
	for i in range(at, goal, -1):
		var back := await _walk_back(controller, str(spine[i]),
				str(spine[i - 1]))
		if not bool(back["inside"]):
			if controller.player._dead or _room_holding(controller,
					controller.player.global_position) == str(spine[0]):
				return false
			_check(false, "walked back into %s (ended %v)"
					% [str(spine[i - 1]), controller.player.global_position])
			_note("  from %s box %s arrival %v; into %s box %s; pieces %s"
					% [str(spine[i]), controller.room_bounds[str(spine[i])],
						RoomGraphs.place_of(controller.room_places,
							str(spine[i])).get("arrival", Vector3.INF),
						str(spine[i - 1]),
						controller.room_bounds[str(spine[i - 1])],
						(controller.room_routes.get(str(spine[i]), [])
							as Array).map(func(q: Dictionary) -> String:
								return "%s:%v->%v" % [str(q.get("kind", "?")),
									q.get("entry", Vector3.INF),
									q.get("exit", Vector3.INF)])])
			return false
	return true


## AND BACK: the same pieces in reverse, each to its entry, then into the
## room before -- which is the room `room_routes[from_room]` came from.
func _walk_back(controller: ZoneController, from_room: String,
		to_room: String) -> Dictionary:
	var box: AABB = controller.room_bounds.get(to_room, AABB())
	var steps: Array[Vector3] = []
	# FIRST TO THIS ROOM'S OWN WAY IN: from the far end of a 59 m arena
	# the connector's mouth is not a straight line away.
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			from_room).get("arrival", Vector3.INF)
	if arrival != Vector3.INF:
		steps.append(arrival)
	var pieces: Array = (controller.room_routes.get(from_room, []) as Array)
	# EACH PIECE EXACTLY BACKWARDS: its exit (the doorway side), then its
	# entry. Stepping entry to entry cut a diagonal through a doorframe.
	for i in range(pieces.size() - 1, -1, -1):
		var piece: Dictionary = pieces[i]
		if piece.has("exit"):
			steps.append(piece["exit"])
		if piece.has("entry"):
			steps.append(piece["entry"])
	var centre := box.get_center()
	centre.y = controller.player.global_position.y
	steps.append(centre)
	return await _follow(controller, steps, box)


func _follow(controller: ZoneController, steps: Array[Vector3],
		box: AABB) -> Dictionary:
	var walk: Dictionary = {}
	var total := 0.0
	var frames := 0
	# NO HOPPING WITH SOMETHING IN HAND: the stall-hop that gets a bare
	# body over a lip would lift a carried object into the lintel.
	var hop := not controller.player.carry.holding()
	for step: Vector3 in steps:
		walk = await _walk_to(controller.player, step, box.grow(-0.5),
				900, hop)
		total += float(walk["walked"])
		frames += int(walk["frames"])
		if box.grow(-0.5).has_point(controller.player.global_position):
			break
	walk["walked"] = total
	walk["frames"] = frames
	walk["legs"] = steps.size()
	walk["inside"] = box.grow(-0.5).has_point(
			controller.player.global_position)
	return walk


func _room_holding(controller: ZoneController, at: Vector3) -> String:
	for room: Variant in controller.room_bounds:
		if (controller.room_bounds[room] as AABB).has_point(at):
			return str(room)
	return ""


func _chamber(room: String) -> Dictionary:
	for raw: Variant in _zone_data.get("chambers", []) as Array:
		var entry: Dictionary = raw
		if str(entry.get("id", "")) == room:
			return entry
	return {}


## CROSS A PLATFORM PATH ON THE REAL CONTROLLER: a run-up and a jump at
## each lip, onto each island in turn and onto the far ledge. The course
## is the chamber's own declaration (`segment_count`, `gap_size`,
## `vertical_step`) laid out the way `ChamberBuilders.platform_path` lays
## it out, in the room's committed frame -- read, not guessed, and the
## first island is checked to stand inside the room before a jump is
## made at it.
func _cross_platform_path(controller: ZoneController, room: String) -> bool:
	var chamber := _chamber(room)
	var segments := int(chamber.get("segment_count", 4))
	var gap := float(chamber.get("gap_size", 2.0))
	var step := float(chamber.get("vertical_step", 0.5))
	var platform := float(Constants.MIN_PLATFORM_SIZE)
	var ledge := 4.0
	var place: Dictionary = controller.room_places.get(room, {})
	var xf := Transform3D(Basis(Vector3.UP, float(place.get("yaw", 0.0))),
			place.get("position", Vector3.ZERO) as Vector3)
	var surfaces: Array = [[0.0, ledge, 0.0]]
	for i in segments:
		var z0 := ledge + gap + (gap + platform) * float(i)
		surfaces.append([z0, z0 + platform, step * float(i + 1)])
	var total := ledge + (gap + platform) * float(segments) + gap + ledge
	surfaces.append([total - ledge, total, step * float(segments)])
	var first: Array = surfaces[1]
	var island := xf * Vector3(0.0, float(first[2]),
			(float(first[0]) + float(first[1])) * 0.5)
	var box: AABB = controller.room_bounds.get(room, AABB())
	if not box.grow(0.5).has_point(island):
		_note("platform course of %s does not lie in its room (%v)"
				% [room, island])
		return false
	var player := controller.player
	for k in range(1, surfaces.size()):
		if not await _hop(player, xf, surfaces[k - 1], surfaces[k]):
			_note("the hop onto surface %d of %s was missed (at %v)"
					% [k, room, player.global_position])
			return false
	return true


## One run-up and jump from `here` onto `there` (each `[z0, z1, y]` in
## the course's local frame).
func _hop(player: Player, xf: Transform3D, here: Array,
		there: Array) -> bool:
	var inv := xf.affine_inverse()
	var start_z := maxf(float(here[0]) + 0.3, float(here[1]) - 1.4)
	await _walk_to(player, xf * Vector3(0.0, float(here[2]), start_z),
			AABB(), 240, false, 0.3)
	var land := xf * Vector3(0.0, float(there[2]),
			(float(there[0]) + float(there[1])) * 0.5)
	var jumped := false
	Input.action_press("move_forward")
	for _i in 150:
		var to := land - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		var local := inv * player.global_position
		if not jumped and local.z >= float(here[1]) - 0.35:
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release("jump")
			jumped = true
			continue
		await get_tree().physics_frame
		if jumped and player.is_on_floor():
			var now := inv * player.global_position
			if now.z >= float(there[0]) - 0.1 \
					and now.y >= float(there[2]) - 0.4:
				break
		if (inv * player.global_position).y < float(there[2]) - 2.0:
			break
	Input.action_release("move_forward")
	await _settle(6)
	var final := inv * player.global_position
	return final.z >= float(there[0]) - 0.3 \
			and final.y >= float(there[2]) - 0.5


## Turn body and camera to look at a point.
func _look_at(player: Player, point: Vector3) -> void:
	var to := point - player.camera.global_position
	if to.length() < 0.01:
		return
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.camera.rotation.y = 0.0


## Walk up to `target` and look at it until the interact ray finds it.
func _approach(controller: ZoneController, target: Node3D,
		stand_off := 1.3, look_at := Vector3.INF) -> bool:
	var player := controller.player
	var point := target.global_position if look_at == Vector3.INF \
			else look_at
	var flat := Vector3(point.x - player.global_position.x, 0.0,
			point.z - player.global_position.z)
	var goal := point - flat.normalized() * stand_off
	goal.y = player.global_position.y
	await _walk_to(player, goal, AABB(), 900, false, 0.35)
	# COME TO A STOP FIRST. Released at the stand-off, the body slides on
	# for a few frames, and an aim taken while it slides drifts off a small
	# target by the next frame: the lever was aimed at and gone by the
	# press, with the ray reading null.
	for _i in 60:
		if Vector2(player.velocity.x, player.velocity.z).length() < 0.05:
			break
		await get_tree().physics_frame
	for _i in 30:
		_look_at(player, point)
		await get_tree().physics_frame
		if player._interact_target == target:
			# Held a second frame at rest, so the press lands on it.
			_look_at(player, point)
			await get_tree().physics_frame
			if player._interact_target == target:
				return true
	return player._interact_target == target


# ---------------------------------------------------------------------------
# Fighting -- the base kit, as `latched_route_driver` clears an arena
# ---------------------------------------------------------------------------

func _living_in(controller: ZoneController, room: String) -> Array:
	var out: Array = []
	for record: Dictionary in controller._chambers:
		if str((record["chamber"] as Dictionary).get("id", "")) != room:
			continue
		for enemy: Variant in record["enemies"]:
			if is_instance_valid(enemy) and not (enemy as Enemy)._dead:
				out.append(enemy)
	return out


func _aim_at_enemy(player: Player, target: Node3D) -> void:
	var centre: Vector3 = target.global_position
	var envelope: Dictionary = Constants.ENEMY_ENVELOPES.get(
			(target as Enemy).archetype, {})
	centre.y += float(envelope.get("centre_y", 0.8))
	_look_at(player, centre)


## Clear a room with the Static Pulse held through `Input`: to the centre
## of the living enemies, then each in sight, nearest first.
func _clear_room(controller: ZoneController, room: String,
		budget := 3600) -> Dictionary:
	var player: Player = controller.player
	var battery := _living_in(controller, room)
	if battery.is_empty():
		return {"guns": 0, "left": 0, "frames": 0}
	var among := Vector3.ZERO
	for raw: Variant in battery:
		among += (raw as Node3D).global_position
	among = among / maxf(1.0, float(battery.size()))
	among.y = player.global_position.y
	var walk := await _walk_to(player, among, AABB(), 900, false, 1.0)
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
		alive.sort_custom(func(one: Node3D, two: Node3D) -> bool:
			return one.global_position.distance_to(player.global_position) \
					< two.global_position.distance_to(player.global_position))
		var sighted: Node3D = null
		for raw: Variant in alive:
			_aim_at_enemy(player, raw as Node3D)
			var ray := player.camera_ray(Constants.STATIC_PULSE_RANGE)
			if not ray.is_empty() and ray["collider"] == raw:
				sighted = raw
				break
		if sighted == null:
			_aim_at_enemy(player, alive[0] as Node3D)
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
	player.camera.rotation.x = 0.0
	return {"guns": battery.size(),
			"left": _living_in(controller, room).size(),
			"frames": int(walk["frames"]) + frames}


## A BULWARK IS FLANKED, NOT OUT-SHOT. Its front is armoured and it turns
## at `BULWARK_TURN_RATE_DEG_S` (90), so the orbit has to out-turn it --
## at 7 m/s a 4 m orbit is ~100 deg/s -- while staying outside its slam,
## which lands within reach x 1.4 = 3.36 m (`enemy._slam`). A 2.8-3.8 m
## band sat inside the slam and lost the player; 4-6 m could not out-turn
## it. 3.6-4.6 m does both. Always the NEAREST shield: circling one while
## the other walks into the orbit is how the player was lost.
func _flank_bulwarks(controller: ZoneController, room: String,
		budget := 3600) -> int:
	var player: Player = controller.player
	var frames := 0
	var strafe := "move_left"
	var stuck := 0
	var was := player.global_position
	var engaged := false
	while frames < budget and not player._dead:
		var shields := _living_in(controller, room).filter(
				func(e: Enemy) -> bool: return e.archetype == "bulwark")
		if shields.is_empty():
			break
		shields.sort_custom(func(one: Node3D, two: Node3D) -> bool:
			return one.global_position.distance_to(player.global_position) \
					< two.global_position.distance_to(player.global_position))
		var target: Enemy = shields[0]
		if not engaged:
			var near := await _walk_to(player, target.global_position,
					AABB(), 300, false, 3.5)
			frames += int(near["frames"])
			Input.action_press("fire_pulse")
			Input.action_press(strafe)
			engaged = true
		_aim_at_enemy(player, target)
		await get_tree().physics_frame
		frames += 1
		_track_damage(player)
		var step := player.global_position.distance_to(was)
		was = player.global_position
		stuck = stuck + 1 if step < 0.01 else 0
		if stuck > 20:
			Input.action_release(strafe)
			strafe = "move_right" if strafe == "move_left" else "move_left"
			Input.action_press(strafe)
			stuck = 0
		var gap := player.global_position.distance_to(target.global_position)
		if gap < 3.6:
			Input.action_release("move_forward")
			Input.action_press("move_back")
		elif gap > 4.6:
			Input.action_release("move_back")
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
			Input.action_release("move_back")
	for action: String in ["move_left", "move_right", "move_forward",
			"move_back", "fire_pulse"]:
		Input.action_release(action)
	return frames


## OUT OF A PIT BY ITS RAMP. A fight can end with the player down in a
## pit arena's sunken floor, and the straight line to the next doorway
## meets the pit wall. The builder declares each band's way up as an
## `access` socket (its centre, axis and run); the low and high ends are
## told apart by probing the floor under each. A player walks up the
## ramp, and so does this.
func _climb_out(controller: ZoneController, room: String) -> void:
	var player := controller.player
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			room).get("arrival", player.global_position)
	if player.global_position.y > arrival.y - 0.8:
		return
	for raw: Variant in controller.offer_rooms:
		var entry: Dictionary = raw
		var chamber: Dictionary = entry.get("chamber", {})
		if str(chamber.get("id", "")) != room:
			continue
		var xform: Transform3D = entry.get("xform", Transform3D.IDENTITY)
		var result: Dictionary = entry.get("build", {})
		for socket: Variant in result.get("sockets", []) as Array:
			var one: Dictionary = socket
			if str(one.get("kind", "")) != "access":
				continue
			var half := float(one.get("length", 6.0)) * 0.5
			var axis := Vector3(1, 0, 0) if str(one.get("along", "x")) \
					== "x" else Vector3(0, 0, 1)
			var centre: Vector3 = one.get("position", Vector3.ZERO)
			var a := xform * (centre - axis * half)
			var b := xform * (centre + axis * half)
			var low := a if _floor_y(controller, a) < _floor_y(controller, b) \
					else b
			var high := b if low == a else a
			var onward := high + (high - low).normalized() * 1.5
			for step: Vector3 in [low, high, onward]:
				await _walk_to(player, step, AABB(), 360, false, 0.5)
			_note("climbed out of %s's pit by its ramp (now y %.2f, floor "
					% [room, player.global_position.y] + "at %.2f)"
					% arrival.y)
			return


func _floor_y(controller: ZoneController, at: Vector3) -> float:
	var space := controller.player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0,
			at + Vector3.DOWN * 6.0)
	query.exclude = [controller.player.get_rid()]
	var hit := space.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else -INF


## HARNESS STEP, declared and counted: a room holding Bulwarks is
## cleared through the real damage path -- `take_damage` from directly
## behind, where the shield takes nothing -- rather than by a scripted
## orbit. This suite measures carrying and installing. Bulwark counterplay
## is `godot-encounter`'s played acceptance ("circling with the base kit
## clears the room"), and a scripted two-Bulwark fight in a pit arena
## proved too sensitive to its start to be evidence of anything here
## (O05 ledger, P5-7). Every removal is printed.
var harness_removals := 0


func _clear_shielded(controller: ZoneController, room: String) -> int:
	var removed := 0
	for raw: Variant in _living_in(controller, room):
		var enemy: Enemy = raw
		if enemy.archetype != "bulwark":
			continue
		var behind: Vector3 = enemy.global_position \
				+ enemy.global_transform.basis.z * 3.0
		enemy.take_damage(enemy.hp * 2.0 + 10.0,
				enemy.global_position - behind, 0.0)
		removed += 1
	await _settle(10)
	harness_removals += removed
	if removed > 0:
		_note("HARNESS: %d bulwark(s) in %s removed through the damage "
				% [removed, room] + "path, from behind (see P5-7)")
	return removed


func _cleared(controller: ZoneController, room: String) -> bool:
	await _clear_shielded(controller, room)
	var guns := _living_in(controller, room).size()
	var flanked := 0
	for round in 3:
		if controller.player._dead:
			break
		flanked += await _flank_bulwarks(controller, room)
		if not _living_in(controller, room).any(
				func(e: Enemy) -> bool: return e.archetype == "bulwark"):
			break
	if flanked > 0:
		_note("%s: %d bulwark(s) flanked in %.1f s, %d of %d enemies left"
				% [room, guns - _living_in(controller, room).size(),
					float(flanked) * DT, _living_in(controller, room).size(),
					guns])
	if controller.player._dead:
		return false
	var fight := await _clear_room(controller, room)
	await _climb_out(controller, room)
	_check(int(fight["left"]) == 0,
			"%s cleared with the base kit: %d of %d down in %.1f s"
			% [room, int(fight["guns"]) - int(fight["left"]),
				int(fight["guns"]), float(fight["frames"]) * DT])
	return int(fight["left"]) == 0


# ---------------------------------------------------------------------------
# 1. What the declaration builds
# ---------------------------------------------------------------------------

func _the_declaration_builds_one_object_one_socket_one_gate(
		zone_data: Dictionary) -> void:
	print("  -- the composed declaration becomes one cell, one socket, "
			+ "one gate")
	var controller := await _enter(zone_data)
	var declared: Dictionary = (zone_data["transported_objects"] as Array)[0]
	var home := str(declared["home_room_id"])
	var cell := controller.objects.body_of(CELL)
	_check(controller.object_refusals.is_empty()
			and controller.object_socket_refusals.is_empty()
			and controller.state_gate_refusals.is_empty()
			and controller.zone_state_refusals.is_empty(),
			"nothing refused: objects %s, sockets %s, gates %s, state %s"
			% [controller.object_refusals,
				controller.object_socket_refusals,
				controller.state_gate_refusals,
				controller.zone_state_refusals])
	_check(cell != null and _copies(CELL) == 1,
			"exactly one power cell exists (%d)" % _copies(CELL))
	if cell == null:
		await _drop(controller)
		return
	var home_box: AABB = controller.room_bounds[home]
	_check(controller.objects.room_of(CELL) == home
			and home_box.has_point(cell.global_position),
			"it is at home in %s, physically (%v in %s)"
			% [home, cell.global_position, home_box])
	_check(is_equal_approx(cell.mass, float(declared["mass_kg"]))
			and cell.carriable
			and cell.mass_class() == MassClass.MEDIUM
			and cell.is_in_group(Constants.REQUIRED_OBJECT_GROUP),
			"it is the declared object: %.0f kg, carriable, %s, required"
			% [cell.mass, cell.mass_class()])
	var socket := _socket(controller)
	var consumer: Dictionary = (zone_data["object_consumers"] as Array)[0]
	_check(socket != null and socket.room_id == str(consumer["room_id"])
			and (controller.room_bounds[socket.room_id] as AABB).grow(0.1)
				.has_point(socket.global_position),
			"the socket stands in %s" % str(consumer["room_id"]))
	var levers := 0
	for raw: Variant in controller.zone_state_setters():
		if (raw as ZoneStateBuild.ZoneStateSetterControl).variable_id \
				== VARIABLE:
			levers += 1
	_check(levers == 0,
			"no lever sets '%s': the installation is its setter (%d)"
			% [VARIABLE, levers])
	var lamps := _lamps(controller)
	_check(lamps.size() == 2 and lamps.all(
			func(l: ZoneStateBuild.ZoneStateMechanism) -> bool:
				return not l.driven),
			"both lamps are built and dark (%d)" % lamps.size())
	var gate := _gate(controller)
	var edge := _gated_edge(zone_data)
	_check(gate != null and gate.edge_id == str(edge.get("edge_id", ""))
			and gate.shutter.is_shut(),
			"the doorway '%s' is shut by its declared gate"
			% str(edge.get("edge_id", "")))
	if gate != null:
		var frame := RoomGraphs.doorway_frame(str(edge["room_a"]), edge,
				zone_data.get("chambers", []) as Array,
				controller.door_frames)
		var socket_ref := "%s/%s" % [str(edge["room_a"]),
				str(frame.get("socket_id", ""))]
		_check(controller.measured_apertures.has(socket_ref)
				and bool(controller.measured_apertures[socket_ref]),
				"the layout evidence reads %s as an opening, gate and all"
				% socket_ref)
	await _drop(controller)


# ---------------------------------------------------------------------------
# 2. The journey
# ---------------------------------------------------------------------------

## Returns the progress the journey's own intents reported, for the
## restore case that follows.
func _the_journey_is_played_end_to_end(zone_data: Dictionary) -> Dictionary:
	print("  -- the journey: clear, fetch, carry across the connectors, "
			+ "install, walk through")
	_deaths = 0
	_taken = 0.0
	var controller := await _enter(zone_data)
	var player: Player = controller.player
	var declared: Dictionary = (zone_data["transported_objects"] as Array)[0]
	var volume: Array = declared["allowed_volume"]
	var home := str(volume[0])
	var consumer_room := str(volume[volume.size() - 1])
	var edge := _gated_edge(zone_data)
	var beyond := str(edge["room_b"]) if str(edge["room_a"]) \
			== consumer_room else str(edge["room_a"])
	var gate := _gate(controller)
	var socket := _socket(controller)

	# ---- clear the way first: a carrying player cannot fire -----------
	if not await _advance_to(controller, consumer_room):
		await _drop(controller)
		return {}

	# ---- the doorway is shut before the delivery -----------------------
	var frame := RoomGraphs.doorway_frame(consumer_room, edge,
			zone_data.get("chambers", []) as Array, controller.door_frames)
	var door: Vector3 = frame.get("position", Vector3.ZERO)
	var box: AABB = controller.room_bounds[consumer_room]
	var inward := _inward_of(frame, box)
	await _walk_to(player, door + inward * 2.5, AABB(), 600, false, 0.4)
	var pressed := await _press_toward(player, door - inward * 3.0, 150)
	# NOT VACUOUS: the player is AT the doorway, on its floor. (It was
	# once "held back" by a door 27 m overhead, in the transit hall, and
	# passed. P5-8.)
	var stood: Vector3 = pressed["at"]
	var across := Vector2(stood.x - door.x, stood.z - door.z).length()
	_check(absf(stood.y - door.y) < 1.5 and across < 3.5,
			"at the doorway itself: %.2f m off its floor, %.2f m across"
			% [absf(stood.y - door.y), across])
	_check(_side_of(frame, inward, pressed["at"]) > 0.0
			and gate.shutter.is_shut(),
			"pressed at the shut doorway for 2.5 s, the player stays on "
			+ "this side (%.2f m in)" % _side_of(frame, inward, pressed["at"]))

	# ---- back for the cell ---------------------------------------------
	_check(await _retreat_to(controller, home),
			"walked back to %s for the cell" % home)
	var cell := controller.objects.body_of(CELL)
	var seen := await _approach(controller, cell, 1.3)
	_check(seen and player._last_prompt == "[E] PICK UP · 40 kg",
			"looking at the cell offers \"%s\"" % player._last_prompt)
	await _press("interact")
	_check(player.carry.holding() and player.carry.body == cell,
			"picked up with `interact`: %s" % [_feedback.back()
				if not _feedback.is_empty() else "(no feedback)"])
	_check(is_equal_approx(player.carry.speed_factor(),
			HandCarry.MEDIUM_SPEED_FACTOR),
			"a MEDIUM cell costs the 0.85 walk (%.2f)"
			% player.carry.speed_factor())

	# ---- carry it through the real connectors -------------------------
	BridgeClient.sent_intents.clear()
	var owned: Array = []
	var connector_frames := 0
	var recoveries_before := controller.object_recoveries.size()
	for i in range(1, volume.size()):
		var room := str(volume[i])
		var watch := _watch_ownership(controller, cell, owned)
		var walk := await _walk_into(controller, room)
		connector_frames += _stop_watching(watch)
		_check(bool(walk["inside"]) and player.carry.holding(),
				"carried into %s over %.1f m, still in hand"
				% [room, float(walk["walked"])])
		_check(controller.objects.room_of(CELL) == room,
				"the cell's owning room is now %s"
				% controller.objects.room_of(CELL))
	_check(connector_frames > 0,
			"for %d frames the cell was in no room's box, in a connector "
			% connector_frames + "-- and was never sent home for it")
	_check(controller.object_recoveries.size() == recoveries_before,
			"no recovery during the carry")
	var occluded := _feedback.filter(func(t: String) -> bool:
		return t.begins_with("NO ROOM"))
	_check(occluded.is_empty(),
			"the cell's own shape cleared every doorway: no occluded drop "
			+ "(%s)" % [_feedback_at.filter(func(t: String) -> bool:
				return t.begins_with("NO ROOM"))])
	var moved := _intents("object_transported")
	_check(moved.size() == volume.size() - 1
			and str((moved.back() as Dictionary).get("room_id", ""))
				== consumer_room,
			"each crossing was reported once, in order: %s"
			% [moved.map(func(m: Dictionary) -> String:
				return str(m["room_id"]))])

	# ---- same-room presence is not installation ------------------------
	_check(controller.zone_state.value_of(VARIABLE) == "dark"
			and socket.installed_object == ""
			and _intents("object_consumed").is_empty(),
			"standing in %s with the cell changes nothing on its own"
			% consumer_room)

	# ---- install ------------------------------------------------------
	var aim := socket.global_position + Vector3(0.0, ObjectSocket.BASE.y
			* 0.6, 0.0)
	var at_socket := await _approach(controller, socket, 1.4, aim)
	_check(at_socket and player._last_prompt == "[E] INSTALL",
			"looking at the socket while carrying offers \"%s\""
			% player._last_prompt)
	await _press("interact")
	await _settle(4)
	_check(not player.carry.holding()
			and controller.objects.consumed_by(CELL) == SOCKET
			and socket.installed_object == CELL
			and socket.seated == cell,
			"installed: the same body is seated in the socket")
	_check(controller.zone_state.value_of(VARIABLE) == "powered",
			"the declared consequence holds: %s = %s"
			% [VARIABLE, controller.zone_state.value_of(VARIABLE)])
	var lamps := _lamps(controller)
	_check(lamps.size() == 2 and lamps.all(
			func(l: ZoneStateBuild.ZoneStateMechanism) -> bool:
				return l.driven),
			"both lamps lit, here and in %s" % beyond)
	var consumed := _intents("object_consumed")
	_check(consumed.size() == 1
			and str((consumed[0] as Dictionary).get("mechanism_id", ""))
				== SOCKET,
			"the installation was reported once, as `object_consumed`")
	var selected := _intents("zone_state_selected").filter(
			func(m: Dictionary) -> bool:
				return str(m["variable_id"]) == VARIABLE)
	_check(selected.is_empty(),
			"and never as a `zone_state_selected` the bridge would refuse")
	var opened := await _wait_for(func() -> bool:
		return gate.shutter.is_open(), 600)
	_check(opened, "the doorway '%s' opened (%.0f%%)"
			% [gate.edge_id, gate.shutter.openness() * 100.0])
	_check(_copies(CELL) == 1, "still exactly one cell (%d)" % _copies(CELL))

	# ---- through the door it opened ------------------------------------
	# Back to where the doorway held them, then on through it.
	await _walk_to(player, door + inward * 2.5, AABB(), 900, false, 0.5)
	var through := await _walk_into(controller, beyond)
	_check(bool(through["inside"]),
			"and the player walks through into %s (%.1f m, ended %v)"
			% [beyond, float(through["walked"]), player.global_position])
	if not bool(through["inside"]):
		_note("  %s box %s arrival %v; door %v; pieces %s" % [beyond,
				controller.room_bounds[beyond], RoomGraphs.place_of(
					controller.room_places, beyond).get("arrival",
					Vector3.INF), door,
				(controller.room_routes.get(beyond, []) as Array).map(
					func(q: Dictionary) -> String:
						return "%s:%v->%v" % [str(q.get("kind", "?")),
							q.get("entry", Vector3.INF),
							q.get("exit", Vector3.INF)])])
	_check(_deaths == 0 or controller.objects.consumed_by(CELL) == SOCKET,
			"the delivery was made (%d death(s) on the way, %.0f hp taken; "
			% [_deaths, _taken] + "none while carrying: the carry legs "
			+ "report their own drops)")
	var reported := {
		"rooms": {CELL: consumer_room},
		"consumed": {CELL: SOCKET},
		"macro": {VARIABLE: "powered"},
	}
	await _drop(controller)
	return reported


## Count frames the carried body spends outside every room box while its
## owning room holds. Returns a handle for `_stop_watching`.
func _watch_ownership(controller: ZoneController, body: ManipulableBody,
		owned: Array) -> Dictionary:
	var handle := {"frames": 0, "owned": owned}
	var tick := func() -> void:
		if not is_instance_valid(body):
			return
		var inside := false
		for room: Variant in controller.room_bounds:
			if (controller.room_bounds[room] as AABB).has_point(
					body.global_position):
				inside = true
				break
		if not inside and controller.objects.room_of(CELL) != "":
			handle["frames"] = int(handle["frames"]) + 1
	handle["tick"] = tick
	get_tree().physics_frame.connect(tick)
	return handle


func _stop_watching(handle: Dictionary) -> int:
	get_tree().physics_frame.disconnect(handle["tick"])
	return int(handle["frames"])


func _side_of(frame: Dictionary, inward: Vector3, point: Vector3) -> float:
	var door: Vector3 = frame["position"]
	return Vector3(point.x - door.x, 0.0, point.z - door.z).dot(inward)


func _inward_of(frame: Dictionary, box: AABB) -> Vector3:
	var door: Vector3 = frame["position"]
	var normal := Basis(Vector3.UP, float(frame["yaw"])) * Vector3(0, 0, 1)
	var to_centre := box.get_center() - door
	to_centre.y = 0.0
	return normal if normal.dot(to_centre) >= 0.0 else -normal


func _wait_for(predicate: Callable, frames: int) -> bool:
	for _i in frames:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return predicate.call()


# ---------------------------------------------------------------------------
# 3. Restore and uniqueness
# ---------------------------------------------------------------------------

func _installed_it_restores_installed_and_never_twice(
		zone_data: Dictionary, reported: Dictionary) -> void:
	print("  -- rebuilt from what the journey reported: installed, once")
	# HARNESS STEP: the progress the journey's intents reported stands in
	# for the bridge's snapshot. `godot-transport-live` restarts for real.
	var controller := await _enter(zone_data, reported)
	var socket := _socket(controller)
	_check(controller.objects.body_of(CELL) == null,
			"no loose cell is built in any room")
	_check(_copies(CELL) == 1 and socket.seated != null
			and socket.installed_object == CELL,
			"exactly one cell, seated in the socket (%d)" % _copies(CELL))
	var gate := _gate(controller)
	_check(gate != null and gate.shutter.is_open(),
			"the doorway is open at load, not opening in front of the player")
	var lamps := _lamps(controller)
	_check(lamps.all(func(l: ZoneStateBuild.ZoneStateMechanism) -> bool:
		return l.driven), "and the lamps are lit")
	await _settle(30)
	_check(_intents("object_consumed").is_empty()
			and _intents("object_transported").is_empty(),
			"a restored installation reports nothing back")
	await _drop(controller)


func _placed_mid_branch_it_restores_where_it_was_left(
		zone_data: Dictionary) -> void:
	print("  -- placed mid-branch by the player: restored at that pose")
	var controller := await _enter(zone_data)
	var player := controller.player
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var home := str(volume[0])
	var mid := str(volume[1])
	await _advance_to(controller, mid)
	await _retreat_to(controller, home)
	var cell := controller.objects.body_of(CELL)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	await _walk_into(controller, mid)
	# PUT DOWN with `interact`, looking at nothing: a drop at rest.
	player.camera.rotation.x = 0.0
	await _settle(2)
	BridgeClient.sent_intents.clear()
	await _press("interact")
	await _settle(90)
	var settled := _intents("object_settled")
	_check(not player.carry.holding() and not settled.is_empty(),
			"put down in %s; its resting pose was reported (%d)"
			% [mid, settled.size()])
	if settled.is_empty():
		await _drop(controller)
		return
	var last: Dictionary = settled.back()
	var at: Array = last["position"]
	var pose := Vector3(float(at[0]), float(at[1]), float(at[2]))
	var yaw := float(last["yaw"])
	_check(str(last["room_id"]) == mid
			and pose.distance_to(cell.global_position) < 0.05,
			"the reported pose is where it lies, in %s" % mid)
	await _drop(controller)
	# HARNESS STEP: rebuilt from what was reported.
	var again := await _enter(zone_data, {
		"rooms": {CELL: mid},
		"poses": {CELL: [mid, pose, yaw]},
	})
	var restored := again.objects.body_of(CELL)
	await _settle(30)
	_check(restored != null and _copies(CELL) == 1,
			"exactly one cell after the rebuild (%d)" % _copies(CELL))
	if restored != null:
		_check(restored.global_position.distance_to(pose) < 0.1
				and absf(angle_difference(restored.rotation.y, yaw)) < 0.05,
				"at the pose it was left at in %s (%.3f m off), not at home"
				% [mid, restored.global_position.distance_to(pose)])
	_check(again.objects.room_of(CELL) == mid
			and _socket(again).installed_object == ""
			and _gate(again).shutter.is_shut(),
			"owned by %s, socket empty, doorway shut" % mid)
	await _drop(again)


# ---------------------------------------------------------------------------
# 4. Refusal at the socket
# ---------------------------------------------------------------------------

func _a_wrong_object_is_refused_at_the_socket(zone_data: Dictionary) -> void:
	print("  -- a different carriable object is refused by the socket")
	var controller := await _enter(zone_data)
	var player := controller.player
	var socket := _socket(controller)
	var consumer_room := socket.room_id
	# HARNESS STEP: a second, legal-to-carry crate put down beside the
	# socket. It is not the declared object.
	await _advance_to(controller, consumer_room)
	var crate := ManipulableBody.create("stray", 12.0,
			Vector3(0.4, 0.4, 0.4))
	crate.carriable = true
	controller.add_child(crate)
	var ahead := -player.global_transform.basis.z
	ahead.y = 0.0
	crate.global_position = player.global_position \
			+ ahead.normalized() * 1.5 + Vector3(0.0, 0.25, 0.0)
	await _settle(30)
	var seen := await _approach(controller, crate, 1.2)
	await _press("interact")
	_check(seen and player.carry.holding() and player.carry.body == crate,
			"the stray crate is picked up")
	# Back to the room's way in, where the socket stands, from wherever
	# the fight ended in a 40 x 59 m arena.
	await _walk_to(player, RoomGraphs.place_of(controller.room_places,
			consumer_room).get("arrival", socket.global_position), AABB(),
			900, false, 1.0)
	var aim := socket.global_position + Vector3(0.0, ObjectSocket.BASE.y
			* 0.6, 0.0)
	await _approach(controller, socket, 1.4, aim)
	_check(player._last_prompt.begins_with("WRONG PART"),
			"the socket says \"%s\"" % player._last_prompt)
	await _press("interact")
	_check(player.carry.holding() and socket.installed_object == ""
			and controller.zone_state.value_of(VARIABLE) == "dark"
			and _intents("object_consumed").is_empty(),
			"interact changes nothing: still carried, socket empty, dark")
	await _drop(controller)


# ---------------------------------------------------------------------------
# 5. Recovery (O05-03.4)
# ---------------------------------------------------------------------------

func _out_of_its_volume_it_comes_home_after_one_second(
		zone_data: Dictionary) -> void:
	print("  -- carried out of its volume: home after 1.0 s, not before")
	var controller := await _enter(zone_data)
	var player := controller.player
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var home := str(volume[0])
	var spine_ids: Array = (zone_data["chambers"] as Array).map(
			func(c: Dictionary) -> String: return str(c["id"]))
	var before := str(spine_ids[spine_ids.find(home) - 1])
	await _advance_to(controller, home)
	var cell := controller.objects.body_of(CELL)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	_check(player.carry.holding(), "carrying the cell in %s" % home)
	BridgeClient.sent_intents.clear()
	# Back into the room before home, which is outside the volume.
	var out_box: AABB = controller.room_bounds[before]
	# Shared with the per-frame watcher: a lambda captures locals by value.
	var seen := {"frames": 0, "left": -1, "recovered": -1}
	var pieces: Array = controller.room_routes.get(home, []) as Array
	var steps: Array[Vector3] = []
	for i in range(pieces.size() - 1, -1, -1):
		if (pieces[i] as Dictionary).has("entry"):
			steps.append((pieces[i] as Dictionary)["entry"])
	var inside_point := out_box.get_center()
	inside_point.y = player.global_position.y
	steps.append(inside_point)
	var tick := func() -> void:
		seen["frames"] = int(seen["frames"]) + 1
		if int(seen["left"]) < 0 and out_box.has_point(cell.global_position):
			seen["left"] = seen["frames"]
		if int(seen["recovered"]) < 0 \
				and not controller.object_recoveries.is_empty():
			seen["recovered"] = seen["frames"]
	get_tree().physics_frame.connect(tick)
	for step: Vector3 in steps:
		await _walk_to(player, step, AABB(), 600, true)
		if int(seen["recovered"]) >= 0:
			break
	for _i in 120:
		if int(seen["recovered"]) >= 0:
			break
		await get_tree().physics_frame
	get_tree().physics_frame.disconnect(tick)
	var left_at := int(seen["left"])
	var recovered_at := int(seen["recovered"])
	var held := float(recovered_at - left_at) * DT
	_check(left_at >= 0 and recovered_at >= 0
			and held >= TransportedObjects.LEAVE_VOLUME_S - 0.05
			and held <= TransportedObjects.LEAVE_VOLUME_S + 0.25,
			"it crossed into %s and was recovered %.2f s later"
			% [before, held])
	_check(not player.carry.holding()
			and controller.objects.room_of(CELL) == home
			and (controller.room_bounds[home] as AABB).has_point(
				cell.global_position) and _copies(CELL) == 1,
			"out of the player's hands, home in %s, one copy" % home)
	_check(_intents("object_recovered").size() == 1,
			"reported as one `object_recovered`")
	await _drop(controller)


func _dying_while_carrying_drops_it_where_it_was(
		zone_data: Dictionary) -> void:
	print("  -- dying while carrying: dropped in place, still owned")
	var controller := await _enter(zone_data)
	var player := controller.player
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var home := str(volume[0])
	var mid := str(volume[1])
	await _advance_to(controller, mid)
	await _retreat_to(controller, home)
	var cell := controller.objects.body_of(CELL)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	await _walk_into(controller, mid)
	_check(player.carry.holding() and controller.objects.room_of(CELL)
			== mid, "carrying the cell in %s" % mid)
	var at := cell.global_position
	BridgeClient.sent_intents.clear()
	# The one direct call: lethal damage, as any hit that kills does.
	player.take_damage(Constants.PLAYER_MAX_HP * 4.0)
	await _settle(90)
	_check(not player.carry.holding() and _copies(CELL) == 1
			and cell.global_position.distance_to(at) < 1.5
			and controller.objects.room_of(CELL) == mid,
			"it fell where it was held (%.2f m away), still owned by %s"
			% [cell.global_position.distance_to(at), mid])
	_check(controller.object_recoveries.is_empty(),
			"death is not a recovery")
	var settled := _intents("object_settled")
	_check(not settled.is_empty() and str((settled.back() as Dictionary)
			.get("room_id", "")) == mid,
			"it came to rest and its pose was reported in %s" % mid)
	await _drop(controller)


func _a_destroyed_cell_comes_back_home_as_itself(
		zone_data: Dictionary) -> void:
	print("  -- destroyed: the same identity is home after 2.0 s")
	var controller := await _enter(zone_data)
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var home := str(volume[0])
	var cell := controller.objects.body_of(CELL)
	BridgeClient.sent_intents.clear()
	# HARNESS STEP: nothing in the game destroys a cell yet (no hazard
	# does), so the body is freed directly to exercise the rule.
	cell.queue_free()
	await _settle(60)
	_check(controller.objects.body_of(CELL) == null
			and controller.object_recoveries.is_empty(),
			"one second after it is destroyed it has not come back")
	await _settle(75)
	var again := controller.objects.body_of(CELL)
	_check(again != null and again != cell and _copies(CELL) == 1
			and controller.objects.room_of(CELL) == home
			and controller.objects.id_of(again) == CELL,
			"after 2.0 s one '%s' is back home in %s" % [CELL, home])
	_check(_intents("object_recovered").size() == 1,
			"reported as one `object_recovered`")
	await _drop(controller)


func _interrupted_beside_the_socket_it_is_not_installed(
		zone_data: Dictionary) -> void:
	print("  -- interrupted beside the socket: restored loose, not installed")
	var controller := await _enter(zone_data)
	var player := controller.player
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	await _advance_to(controller, str(volume[volume.size() - 1]))
	await _retreat_to(controller, str(volume[0]))
	var cell := controller.objects.body_of(CELL)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	BridgeClient.sent_intents.clear()
	for i in range(1, volume.size()):
		await _walk_into(controller, str(volume[i]))
	var socket := _socket(controller)
	await _approach(controller, socket, 1.4, socket.global_position
			+ Vector3(0.0, ObjectSocket.BASE.y * 0.6, 0.0))
	_check(player.carry.holding() and player._last_prompt == "[E] INSTALL",
			"carrying the cell, one press from installing it")
	# THE INTERRUPTION: the session ends here. What the bridge was told is
	# the rooms it crossed and nothing else -- it was never put down.
	var reported := {"rooms": {}, "poses": {}}
	for intent: Dictionary in _intents("object_transported"):
		reported["rooms"][str(intent["object_id"])] = str(intent["room_id"])
	await _drop(controller)
	var again := await _enter(zone_data, reported)
	var restored := again.objects.body_of(CELL)
	var consumer_room := str(volume[volume.size() - 1])
	_check(restored != null and _copies(CELL) == 1
			and again.objects.room_of(CELL) == consumer_room
			and (again.room_bounds[consumer_room] as AABB).has_point(
				restored.global_position),
			"one loose cell, in %s where it was last reported"
			% consumer_room)
	_check(_socket(again).installed_object == ""
			and again.zone_state.value_of(VARIABLE) == "dark"
			and _gate(again).shutter.is_shut(),
			"not installed, nothing powered, the doorway still shut")
	await _drop(again)


# ---------------------------------------------------------------------------
# 6. Status continuity (O05-02.5)
# ---------------------------------------------------------------------------

func _lightened_crosses_the_threshold_with_the_same_body(
		zone_data: Dictionary) -> void:
	print("  -- LIGHTENED from its real applicator, carried over a "
			+ "threshold, running out on its own clock")
	var controller := await _enter(zone_data)
	var player := controller.player
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	var home := str(volume[0])
	var mid := str(volume[1])
	await _advance_to(controller, mid)
	await _retreat_to(controller, home)
	var cell := controller.objects.body_of(CELL)
	# HARNESS STEP: Unweighted Switch's applicator -- the same
	# `ActivityElement.SHOT`, the same explicit binding to one body, the
	# same Status numbers -- put up in the home room. The composed Zone
	# declares no applicator; this case is about the Status crossing the
	# doorway, not about where the applicator comes from.
	var applicator := ActivityElement.create(ActivityElement.SHOT, 0,
			ActivityElement.TARGET_SIZE, Color(0.55, 0.9, 1.0))
	controller.add_child(applicator)
	applicator.global_position = cell.global_position + Vector3(0.0, 1.4,
			-2.5)
	applicator.triggered.connect(func(_which: ActivityElement) -> void:
		cell.apply_status("lightened", UnweightedSwitch.LIGHTENED_SECONDS,
				UnweightedSwitch.LIGHTENED_MAGNITUDE))
	await _walk_to(player, applicator.global_position + Vector3(0.0, 0.0,
			5.0), AABB(), 600, false, 0.5)
	for _i in 10:
		_look_at(player, applicator.global_position)
		await get_tree().physics_frame
	var shot_at := -1.0
	Input.action_press("fire_pulse")
	for i in 90:
		await get_tree().physics_frame
		if cell.statuses != null and cell.statuses.has("lightened"):
			shot_at = float(i) * DT
			break
	Input.action_release("fire_pulse")
	var lit_frame := Engine.get_physics_frames()
	_check(shot_at >= 0.0 and cell.mass_class() == MassClass.LIGHT
			and is_equal_approx(cell.mass, 40.0),
			"the Static Pulse hit the applicator: the cell reads %s and "
			% cell.mass_class() + "still weighs %.0f kg" % cell.mass)
	await _approach(controller, cell, 1.3)
	await _press("interact")
	_check(player.carry.holding()
			and is_equal_approx(player.carry.speed_factor(), 1.0),
			"picked up LIGHTENED: no walking penalty (%.2f)"
			% player.carry.speed_factor())
	var walk := await _walk_into(controller, mid)
	var elapsed := float(Engine.get_physics_frames() - lit_frame) * DT
	_check(bool(walk["inside"]) and player.carry.body == cell
			and controller.objects.room_of(CELL) == mid,
			"the same body carried over the threshold into %s (%.1f s on)"
			% [mid, elapsed])
	if elapsed < UnweightedSwitch.LIGHTENED_SECONDS:
		_check(cell.statuses.has("lightened")
				and cell.mass_class() == MassClass.LIGHT
				and is_equal_approx(player.carry.speed_factor(), 1.0),
				"on the far side it is still LIGHTENED: %s, factor %.2f"
				% [cell.mass_class(), player.carry.speed_factor()])
	else:
		_note("the walk outlasted the Status (%.1f s); the far-side "
				% elapsed + "reading was not taken")
	var sent := _intents("object_transported")
	_check(sent.all(func(m: Dictionary) -> bool:
		return not m.has("statuses") and not m.has("status")),
			"nothing about the Status was sent to be saved")
	var expired := await _wait_for(func() -> bool:
		return cell.statuses == null or not cell.statuses.has("lightened"),
			int((UnweightedSwitch.LIGHTENED_SECONDS + 2.0) / DT))
	var gone_after := float(Engine.get_physics_frames() - lit_frame) * DT
	_check(expired and cell.mass_class() == MassClass.MEDIUM
			and is_equal_approx(cell.mass, 40.0)
			and is_equal_approx(player.carry.speed_factor(),
				HandCarry.MEDIUM_SPEED_FACTOR),
			"it ran out on its own clock (%.1f s after the hit): MEDIUM "
			% gone_after + "again, 40 kg, factor %.2f"
			% player.carry.speed_factor())
	await _drop(controller)


func _finish() -> void:
	if failures == 0:
		print("GODOT TRANSPORT TESTS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT TRANSPORT TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
