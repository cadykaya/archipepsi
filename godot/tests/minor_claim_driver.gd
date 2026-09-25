extends "res://tests/transport_driver.gd"
## V-09 ON THE PLAYED ZONE: NO MINOR'S CHECK BEFORE ITS ROOM IS SOLVED
## (`--minor-claim`).
##
##     make godot-minor-claim
##
## `candidate_zone.json` is the candidate profile the owner played, built
## through the real `ZoneController`. For every minor it hosts, the room
## as built -- nothing operated -- is put to `ClaimCensus`: from every
## place the base kit reaches from the room's arrival, can the claim ray
## reach the Check? PT-05: "did not understand the goal, and walked to
## the Check." That is a failure of the ROOM, whatever its puzzle is.
##
## **NOT VACUOUS.** For each room, the same ray test from where a player
## who solved it stands -- beside the Check -- must claim. A census that
## could not see the Check from anywhere would pass this suite for the
## wrong reason.

const CANDIDATE := "res://tests/fixtures/candidate_zone.json"


func _run() -> void:
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(CANDIDATE))
	var controller := await _enter(zone_data)
	var player := controller.player
	player.hp = 100000.0
	# EVERY MINOR THE ZONE DECLARES, BUILT AS ITSELF. A room whose shell
	# the content validator refuses falls back to a plain arena, and a
	# census of the minors that remain would pass by measuring fewer of
	# them -- which is how a walled-up sabotage first passed this suite.
	var declared: Array = []
	for raw: Variant in zone_data.get("chambers", []) as Array:
		var chamber: Dictionary = raw
		if str(chamber.get("shell_id", "")).begins_with("minor_"):
			declared.append(str(chamber.get("id", "")))
	declared.sort()
	var hosted: Array = controller.minors.map(
			func(m: Dictionary) -> String: return str(m["room_id"]))
	hosted.sort()
	_check(not declared.is_empty() and hosted == declared,
			"every minor the played Zone declares is built as itself: "
			+ "declared %s, hosted %s" % [declared, hosted])
	for raw: Variant in controller.minors:
		var minor: Dictionary = raw
		await _census_of(controller, minor)
	for raw: Variant in controller.minors:
		var minor: Dictionary = raw
		if minor["hosted"] is UnweightedSwitchHosted:
			await _unweighted_as_built(controller, minor)
			await _unweighted_with_mobility(controller, minor)
			await _unweighted_in_transit(controller, minor)
			await _unweighted_return(controller, minor)
	_finish()


## D12's card, "Actual obstruction": as built, the gallery G is not
## reached from the arrival with the base kit -- not by walking, jumping
## or dropping, and not from the parked carriage.
func _unweighted_as_built(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room: UnweightedSwitchRoom = (minor["hosted"] as UnweightedSwitchHosted).room
	print("  -- %s: the gallery, as built, from the arrival" % rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", box.get_center())
	var on_g := room.to_global(Vector3(-1.5, UnweightedSwitchRoom.SILL_Y,
			UnweightedSwitchRoom.NORTH_Z + 2.0))
	var from_arrival := ClaimCensus.reach(controller.player, box, arrival,
			_living_in(controller, rid))
	_check(not ClaimCensus.reaches_near(from_arrival, on_g, 2.5)
			and not room.crate_is_placed() and not room.bolted,
			"%s: G is NOT reached from the arrival with the base kit, the "
			% rid + "room as built (%d cells reached)"
			% (from_arrival["reached"] as Dictionary).size())


## V-10, MOVEMENT ASSISTANCE UNDER ITS REAL RULES, on the room as built.
##
## D12: the goal accepts any legal arrival (R1) and a mobility alternate
## is an accelerator (R4) -- so reaching G by blink, a double jump or a
## grapple is not a defect, and nothing here is nerfed to stop it. What is
## a defect is R2's: a claim from anywhere BUT G, "no teleport target
## landing inside the reward's reach from outside G". So each verb runs
## through the player's real `EchoRuntime` at its schema's longest reach,
## and every landing, and every frame of every flight, asks one thing: is
## the Check in claim reach while the player is not on G?
func _unweighted_with_mobility(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room: UnweightedSwitchRoom = (minor["hosted"] as UnweightedSwitchHosted).room
	print("  -- %s: movement assistance, the room as built (V-10)" % rid)
	var reward := _reward_in(controller, rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", box.get_center())
	# ON G: the gallery, and the sill that is its edge -- standing in the
	# crossing is arriving.
	var on_goal := func(at: Vector3) -> bool:
		var local := room.to_local(at)
		return local.z > UnweightedSwitchRoom.NORTH_Z - 0.7 \
				and local.y > UnweightedSwitchRoom.SILL_Y - 0.3
	var aims: Array = [reward.global_position + Vector3(0.0, 1.3, 0.0),
			room.to_global(Vector3(0.0, UnweightedSwitchRoom.SILL_Y + 0.5,
				UnweightedSwitchRoom.NORTH_Z + 2.0)),
			room.to_global(Vector3(4.5, UnweightedSwitchRoom.SILL_Y + 1.0,
				UnweightedSwitchRoom.NORTH_Z + 1.0))]
	var tally := await _mobility(controller, rid, box, arrival, reward,
			on_goal, aims)
	_note("%s mobility: %s" % [rid, tally["summary"]])
	_check((tally["claims_off_goal"] as Array).is_empty(),
			"%s: V-10 -- no blink, double jump or grapple puts the Check in "
			% rid + "claim reach from anywhere but G (%s); off-goal claims: %s"
			% [tally["summary"], tally["claims_off_goal"]])
	_check(int(tally["arrivals"]) > 0,
			"%s: and movement is not nerfed: %d attempt(s) arrived on G, "
			% [rid, tally["arrivals"]] + "which D12 accepts as a legal arrival")


## The three verbs, as the player's real runtimes run them. Blink: from a
## sample of every cell the base kit reaches, aimed every way and at each
## of `aims`. Double jump and grapple: flown from the arrival floor toward
## each aim, checked frame by frame.
func _mobility(controller: ZoneController, rid: String, box: AABB,
		arrival: Vector3, reward: RewardObject, on_goal: Callable,
		aims: Array) -> Dictionary:
	var player := controller.player
	var runtime: EchoRuntime = player.runtimes["mobility"]
	var saved: Dictionary = runtime.equipped
	var tally := {"blinks": 0, "moved": 0, "arrivals": 0,
		"claims_off_goal": [], "flights": 0,
		"by": {"blink": 0, "double_jump": 0, "grapple_to_surface": 0}}
	var reach := ClaimCensus.reach(player, box, arrival,
			_living_in(controller, rid))
	var cells: Dictionary = reach["cells"]
	var keys: Array = (reach["reached"] as Dictionary).keys()
	keys.sort()
	var dirs: Array = []
	for az in 8:
		for el: float in [-0.5, 0.0, 0.5]:
			var a := TAU * float(az) / 8.0
			dirs.append(Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el)))
	dirs.append(Vector3.UP)
	# ---- blink, 25 m ----------------------------------------------------
	runtime.equipped = {"component_id": "v10_blink", "slot": "mobility",
		"cooldown": 0.0, "modifiers": [], "primitive": {"type": "blink",
			"range": 25.0, "clearance": float(Constants.PLAYER_RADIUS)}}
	for i in range(0, keys.size(), 6):
		var origin: Vector3 = cells[keys[i]]
		var toward: Array = dirs.duplicate()
		for aim: Vector3 in aims:
			toward.append((aim - (origin + Vector3(0.0,
					Constants.PLAYER_EYE_HEIGHT, 0.0))).normalized())
		for dir: Vector3 in toward:
			player.global_position = origin
			player.velocity = Vector3.ZERO
			var flat := Vector3(dir.x, 0.0, dir.z)
			if flat.length() < 0.001:
				flat = Vector3.FORWARD
			player.rotation.y = atan2(-flat.x, -flat.z)
			player.camera.rotation.x = clampf(asin(clampf(dir.y, -1.0, 1.0)),
					-PI / 2.0, PI / 2.0)
			runtime.cooldown_remaining = 0.0
			tally["blinks"] += 1
			runtime.activate()
			var landed := player.global_position
			if landed.distance_to(origin) < 0.001:
				continue
			tally["moved"] += 1
			if on_goal.call(landed):
				tally["arrivals"] += 1
				tally["by"]["blink"] += 1
				continue
			for rise: float in ClaimCensus.rises_for(player, landed):
				var eye := landed + Vector3(0.0,
						Constants.PLAYER_EYE_HEIGHT + rise, 0.0)
				if ClaimCensus.claims_from(player, eye, reward):
					(tally["claims_off_goal"] as Array).append(
							"blink from %v to %v" % [origin.snapped(
								Vector3.ONE * 0.1), landed.snapped(
								Vector3.ONE * 0.1)])
					break
	# ---- double jump (11.2 m/s, twice) and grapple (35 m, 25 m/s) ------
	var verbs := [
		{"type": "double_jump", "force": Constants.JUMP_VELOCITY * 1.4,
			"extra_jumps": 2},
		{"type": "grapple_to_surface", "range": 35.0, "pull_force": 25.0},
	]
	for prim: Dictionary in verbs:
		runtime.equipped = {"component_id": "v10_%s" % prim["type"],
			"slot": "mobility", "cooldown": 0.0, "modifiers": [],
			"primitive": prim}
		for aim: Vector3 in aims:
			for back: float in [1.0, 2.5, 4.0]:
				await _fly(controller, runtime, prim, arrival, aim, back,
						on_goal, reward, tally)
	runtime.equipped = saved
	player.global_position = arrival + Vector3(0.0, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	await _settle(10)
	tally["summary"] = ("%d blinks (%d moved), %d flights, %d arrived on G "
			% [tally["blinks"], tally["moved"], tally["flights"],
				tally["arrivals"]]) + "(by blink %d, double jump %d, grapple %d)" \
			% [tally["by"]["blink"], tally["by"]["double_jump"],
				tally["by"]["grapple_to_surface"]]
	return tally


## One flight: placed on the floor `back` metres short of `aim` (as seen
## from the arrival), facing it, a jump, then the verb -- at the apex for
## a double jump (both of them), at once for a grapple -- holding forward.
func _fly(controller: ZoneController, runtime: EchoRuntime, prim: Dictionary,
		arrival: Vector3, aim: Vector3, back: float, on_goal: Callable,
		reward: RewardObject, tally: Dictionary) -> void:
	var player := controller.player
	var flat := Vector3(aim.x - arrival.x, 0.0, aim.z - arrival.z)
	var start := Vector3(aim.x, arrival.y, aim.z) - flat.normalized() \
			* (back + 3.0)
	# Onto the floor there, if there is floor; otherwise from the arrival.
	var down := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 3.0,
			start + Vector3.DOWN * 3.0)
	down.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(down)
	var foot: Vector3 = hit["position"] if not hit.is_empty() else arrival
	player.global_position = foot + Vector3(0.0, 0.05, 0.0)
	player.velocity = Vector3.ZERO
	await _settle(4)
	tally["flights"] += 1
	var used := 0
	var landed_on_goal := false
	for frame in 150:
		var eye := player.global_position + Vector3(0.0,
				Constants.PLAYER_EYE_HEIGHT, 0.0)
		var to := aim - player.camera.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		Input.action_press("move_forward")
		if frame == 0:
			Input.action_press("jump")
		elif frame == 1:
			Input.action_release("jump")
		var want := false
		if str(prim["type"]) == "double_jump":
			want = not player.is_on_floor() and player.velocity.y <= 0.5 \
					and used < int(prim["extra_jumps"])
		else:
			want = frame == 4
		if want:
			runtime.cooldown_remaining = 0.0
			runtime.activate()
			used += 1
		await get_tree().physics_frame
		var here := player.global_position
		if on_goal.call(here):
			landed_on_goal = true
		elif ClaimCensus.claims_from(player, here + Vector3(0.0,
				Constants.PLAYER_EYE_HEIGHT, 0.0), reward):
			(tally["claims_off_goal"] as Array).append("%s toward %v at %v"
					% [prim["type"], aim.snapped(Vector3.ONE * 0.1),
						here.snapped(Vector3.ONE * 0.1)])
			break
		if frame > 20 and player.is_on_floor():
			break
	Input.action_release("move_forward")
	Input.action_release("jump")
	if landed_on_goal:
		tally["arrivals"] += 1
		tally["by"][str(prim["type"])] += 1
	await _settle(4)


## D12's card, "Return" and R3: the way back exists after EVERY accepted
## arrival. An alternate arrival -- a strong jump, a mobility tool -- puts
## the player on G with nothing pulled and the crossing shut behind; the
## gallery drops back through the return gap. Then the bolt, pulled by
## hand on G, holds the crossing and lowers the stair: the way back again.
func _unweighted_return(controller: ZoneController, minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room: UnweightedSwitchRoom = (minor["hosted"] as UnweightedSwitchHosted).room
	print("  -- %s: the return, after an alternate arrival and after the bolt"
			% rid)
	var player := controller.player
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", box.get_center())
	var on_g := room.to_global(Vector3(-1.5, UnweightedSwitchRoom.SILL_Y
			+ 0.1, UnweightedSwitchRoom.NORTH_Z + 2.0))
	# Shut behind: the carriage on the weighbridge, nothing LIGHTENED.
	var shut := await _wait_for_shut(room)
	# HARNESS STEP: an alternate arrival, placed on G.
	player.global_position = on_g
	player.velocity = Vector3.ZERO
	await _settle(20)
	var back := ClaimCensus.reach(player, box, player.global_position,
			_living_in(controller, rid))
	_check(shut and not room.bolted
			and ClaimCensus.reaches_near(back, arrival, 1.5),
			"%s: ALTERNATE ARRIVAL, crossing shut, nothing pulled: the "
			% rid + "arrival floor is reached from G (the return gap)")
	# The bolt, by hand, on G.
	var top := room.bolt.global_position \
			+ Vector3(0.0, CallLever.BASE.y * 0.25, 0.0)
	var pulled := false
	if await _approach(controller, room.bolt, 1.3, top):
		await _press("interact")
		await _settle(20)
		pulled = room.bolted
	_check(pulled and room.return_stair_steps() > 0
			and room.bolt.locked and room.bolt.interact_prompt()
				.begins_with("BOLT HELD"),
			"%s: the HOLD-OPEN BOLT pulled by hand on G: the stair is down "
			% rid + "(%d steps) and the bolt stays thrown, saying so: '%s'"
			% [room.return_stair_steps(), room.bolt.interact_prompt()])
	var opened := await _wait_for_open(room)
	var stair_back := ClaimCensus.reach(player, box, player.global_position,
			_living_in(controller, rid))
	_check(opened and ClaimCensus.reaches_near(stair_back, arrival, 1.5),
			"%s: and the crossing is held open with the carriage still on "
			% rid + "the weighbridge; the arrival floor is reached from G")


func _wait_for_shut(room: UnweightedSwitchRoom) -> bool:
	for _i in 600:
		if room.shutter.is_shut():
			return true
		await get_tree().physics_frame
	return room.shutter.is_shut()


func _wait_for_open(room: UnweightedSwitchRoom) -> bool:
	for _i in 600:
		if room.shutter.is_open():
			return true
		await get_tree().physics_frame
	return room.shutter.is_open()


## EX50-033'S TRANSIT: THE CARRIAGE AS A STEP BEFORE IT IS A WEIGHT.
##
## The room's insight is that the carriage is a step only where it is
## also a HEAVY weight on the plate -- so the crossing it would reach is
## shut. But the carriage DRIVES to the recess, and on its way it can be
## a step within a jump of the sill while it is not yet on the plate.
## So this rides it, and jumps -- not once, at one lucky moment, but at
## every point of its travel a jump could matter, from further out than
## a run-up reaches to the recess itself. No LIGHTENED, ever. Any one of
## them landing on G is the bypass.
func _unweighted_in_transit(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room: UnweightedSwitchRoom = (minor["hosted"] as UnweightedSwitchHosted).room
	print("  -- %s: the carriage in transit, ridden, nothing LIGHTENED" % rid)
	var player := controller.player
	# The drive, by hand, once: that it is reachable and pulls.
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", Vector3.ZERO)
	player.global_position = arrival + Vector3(0.0, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	await _settle(20)
	var lever_top := room.drive.global_position \
			+ Vector3(0.0, CallLever.BASE.y * 0.25, 0.0)
	var pulled := false
	if await _approach(controller, room.drive, 1.3, lever_top):
		var before := room.drive.pulls
		await _press("interact")
		await _settle(2)
		pulled = room.drive.pulls > before
	_check(pulled, "%s: the SERVICE DRIVE pulled by hand" % rid)
	var outcomes: Array = []
	var through: Array = []
	var lightened := false
	# The carriage's north edge's distance from the wall's face when the
	# jump is taken: from beyond any run-up to the recess.
	for gap: float in [4.9, 4.6, 4.3, 4.0, 3.7, 3.4, 3.1, 2.8, 2.5, 2.2, 1.9,
			1.6, 1.3, 1.0]:
		var result := await _ride_and_jump(controller, room, gap)
		lightened = lightened or bool(result["lightened"])
		outcomes.append("%.1f m:%s" % [gap, "G" if result["through"] else
				"no"])
		if bool(result["through"]):
			through.append("%.1f m from the wall (crossing %.2f open%s)"
					% [gap, float(result["open_at_jump"]),
						", walked on to G" if bool(result["on_g"]) else ""])
	_note("%s transit jumps: %s" % [rid, " ".join(outcomes)])
	_check(through.is_empty() and not lightened,
			"%s: NO CROSSING FROM THE CARRIAGE IN TRANSIT -- ridden and "
			% rid + "jumped at 14 points of its travel, nothing LIGHTENED; "
			+ "reached G from: %s" % [through])


## HARNESS STEPS, both declared: the carriage is put back in its bay with
## the drive idle (the room's own state between attempts), and the player
## is put aboard. Then the drive is commanded, and everything after is
## input: forward along the carriage top, and a jump at its north edge
## when that edge is `gap` metres from the wall.
func _ride_and_jump(controller: ZoneController, room: UnweightedSwitchRoom,
		gap: float) -> Dictionary:
	var player := controller.player
	room.crate.position.z = UnweightedSwitchRoom.PARK_Z
	room.crate.freeze = true
	room._drive_goal = UnweightedSwitchRoom.PARK_Z
	await _wait_for_open(room)
	player.global_position = room.to_global(room.crate.position
			+ Vector3(0.0, UnweightedSwitchRoom.CRATE.y * 0.5 + 0.1, -0.6))
	player.velocity = Vector3.ZERO
	await _settle(6)
	room.drive.interact(player)
	var jumped := false
	var left_floor := false
	var open_at_jump := -1.0
	var lightened := false
	for frame in 480:
		if room.crate.statuses != null and room.crate.statuses.has("lightened"):
			lightened = true
		var local := room.to_local(player.global_position)
		var edge := room.crate.position.z + UnweightedSwitchRoom.CRATE.z * 0.5
		var wall := UnweightedSwitchRoom.NORTH_Z - 0.25
		var goal := room.to_global(Vector3(0.0, UnweightedSwitchRoom.SILL_Y,
				UnweightedSwitchRoom.NORTH_Z + 1.5))
		var flat := Vector3(goal.x - player.global_position.x, 0.0,
				goal.z - player.global_position.z)
		player.rotation.y = atan2(-flat.x, -flat.z)
		var at_edge := local.z > edge - 0.5
		var ready := wall - edge <= gap
		if at_edge and not jumped and not ready:
			Input.action_release("move_forward")
		else:
			Input.action_press("move_forward")
		if not jumped and at_edge and ready and player.is_on_floor():
			jumped = true
			open_at_jump = room.shutter.openness()
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release("jump")
		else:
			await get_tree().physics_frame
		if jumped and not player.is_on_floor():
			left_floor = true
		if left_floor and player.is_on_floor():
			break
		if room.crate_is_placed() and not jumped and room.shutter.is_shut():
			break
	# LANDED IN THE CROSSING IS THROUGH IT. A body on the sill stands in
	# the doorway, where the shutter's closure interlock holds the panel
	# off it (D12 lists "standing in the closing shutter" as a legitimate
	# alternate) -- so the walk simply goes on, north, onto G.
	var landed := room.to_local(player.global_position)
	var in_crossing := landed.y > UnweightedSwitchRoom.SILL_Y - 0.3 \
			and landed.z > UnweightedSwitchRoom.NORTH_Z - 0.7
	if in_crossing:
		for _i in 90:
			Input.action_press("move_forward")
			await get_tree().physics_frame
	Input.action_release("move_forward")
	await _settle(20)
	var ended := room.to_local(player.global_position)
	return {"through": in_crossing or (ended.z > UnweightedSwitchRoom.NORTH_Z
				and ended.y > UnweightedSwitchRoom.SILL_Y - 0.3),
			"on_g": ended.z > UnweightedSwitchRoom.NORTH_Z + 0.4
				and ended.y > UnweightedSwitchRoom.SILL_Y - 0.3,
			"open_at_jump": open_at_jump, "lightened": lightened}


func _census_of(controller: ZoneController, minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var hosted: Node3D = minor["hosted"]
	print("  -- %s (%s), as built, nothing operated" % [rid, hosted.name])
	var reward := _reward_in(controller, rid)
	_check(reward != null, "%s holds its Check" % rid)
	if reward == null:
		return
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", box.get_center())
	# Parked out of the room: the census's queries skip the player, but
	# its capsule would still stand in the doorway.
	controller.player.global_position = arrival + Vector3(0.0, 40.0, 0.0)
	await _settle(2)
	var started := Time.get_ticks_msec()
	var census := ClaimCensus.take(controller.player, box, arrival, reward,
			_living_in(controller, rid))
	var took := Time.get_ticks_msec() - started
	var where: Array = (census["claims"] as Array).map(
			func(c: Dictionary) -> String:
				var local: Vector3 = hosted.to_local(c["at"])
				return "stand %v +%.2f m" % [local.snapped(Vector3.ONE * 0.1),
						float(c["rise"])])
	_note("%s: %d standable cells, %d reached from the arrival with the base "
			% [rid, census["cells"], census["reached"]]
			+ "kit, %d claim the Check (%d ms)"
			% [census["from_cells"], took])
	_check(int(census["reached"]) > 20,
			"%s: the census walks the room (%d cells reached)"
			% [rid, census["reached"]])
	_check(int(census["from_cells"]) == 0,
			"%s: NO CLAIM BEFORE THE ROOM IS SOLVED -- %d reached cell(s) "
			% [rid, census["from_cells"]]
			+ "claim the Check, in the hosted room's own frame: %s" % [where])
	if not (census["claims"] as Array).is_empty():
		await _played_witness(controller, rid, hosted, reward,
				(census["claims"] as Array)[0])
	# THE CONTROL: from beside the Check, where a player who solved the
	# room stands, the same test claims.
	var beside := _beside(reward, box)
	_check(ClaimCensus.claims_from(controller.player, beside, reward),
			"%s: control -- from beside the Check (eye %v) the same test "
			% [rid, beside.snapped(Vector3.ONE * 0.1)] + "claims it")


## WHAT THE CENSUS FOUND, PLAYED: the real player walks from the room's
## arrival to the first cell the census says claims, hops, and presses
## `interact` the moment the prompt offers the Check. Evidence that the
## census's reach is the game's reach, not a model's.
##
## **HARNESS STEPS**, both declared: the player is placed at the room's
## arrival, and the snapshot says Archipelago is connected -- offline, a
## Check answers "RECONNECT TO SEND" and sends nothing, which would hide
## the claim this is looking for.
func _played_witness(controller: ZoneController, rid: String,
		hosted: Node3D, reward: RewardObject, claim: Dictionary) -> void:
	var player := controller.player
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			rid).get("arrival", Vector3.ZERO)
	player.global_position = arrival + Vector3(0.0, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	await _settle(20)
	var at: Vector3 = claim["at"]
	await _walk_to(player, at, AABB(), 900, false, 0.25)
	for _i in 60:
		if Vector2(player.velocity.x, player.velocity.z).length() < 0.05:
			break
		await get_tree().physics_frame
	var stood := hosted.to_local(player.global_position)
	var was_connected: Variant = BridgeClient.snapshot.get("ap_connected",
			false)
	BridgeClient.snapshot["ap_connected"] = true
	BridgeClient.sent_intents.clear()
	var aim := reward.global_position + Vector3(0.0, 1.3, 0.0)
	var prompt := ""
	for attempt in 3:
		Input.action_press("jump")
		await get_tree().physics_frame
		Input.action_release("jump")
		for _i in 50:
			_look_at(player, aim)
			await get_tree().physics_frame
			if player._interact_target == reward:
				prompt = reward.interact_prompt()
				await _press("interact")
				break
		if prompt != "":
			break
		await _settle(40)
	await _settle(4)
	var claims := BridgeClient.sent_intents.filter(
			func(i: Dictionary) -> bool:
				return str(i.get("type", "")) == "claim_check" \
						and int(i.get("location_id", -1)) == reward.location_id)
	BridgeClient.snapshot["ap_connected"] = was_connected
	_check(claims.is_empty(),
			("%s: PLAYED -- walked from the arrival to stand at %v (the "
			% [rid, stood.snapped(Vector3.ONE * 0.1)])
			+ "room's frame), hopped and looked: the prompt read '%s' and "
			% prompt + "%d claim(s) went out before the room was solved"
			% claims.size())


## An eye beside the Check at its own floor: a metre and a half back from
## it toward the room's centre, standing height.
func _beside(reward: RewardObject, box: AABB) -> Vector3:
	var at := reward.global_position
	var toward := Vector3.FORWARD
	var flat := Vector3(box.get_center().x - at.x, 0.0,
			box.get_center().z - at.z)
	if flat.length() > 0.1:
		toward = flat.normalized()
	return at + toward * 1.5 + Vector3(0.0, Constants.PLAYER_EYE_HEIGHT, 0.0)


## The Check pedestal standing in a room, found by where it stands.
func _reward_in(controller: ZoneController, room_id: String) -> RewardObject:
	var box: AABB = controller.room_bounds.get(room_id, AABB())
	for node: Node in controller.find_children("*", "", true, false):
		var reward := node as RewardObject
		if reward != null and box.has_point(reward.global_position):
			return reward
	return null


func _finish() -> void:
	if failures == 0:
		print("GODOT MINOR CLAIM TESTS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT MINOR CLAIM TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
