extends "res://tests/minor_claim_driver.gd"
## H-PASSING (PT-06, PT-07, D12's card) — EX50-011 AS A ZONE HOSTS IT
## (`--passing-hosted`).
##
##     make godot-passing-hosted [PASSING_ZONE=<path>]
##
## PT-06: "Passing machinery interesting, but neither problem nor solution
## readable; pickup directly reachable." PT-07: "Passing branch end had no
## recognizable return except random teleport." The candidate hosts
## EX50-011 where the offer order reaches it -- zone_002 -- and no fixture
## carries that Zone yet (note N-10), so this suite reads the Zone from
## `--passing-zone=<path>` when given one: locally, a capture of the Zone
## the real bridge served (`godot-candidate-live`'s next phase with
## `--candidate-dump-zone`), unedited. Its default is the fixture Dess's
## `passing-fixture` will write.
##
## **WHAT IS ASKED, of the room as the Zone builds it:**
##   census    D12 R2 and PT-06: from everywhere the base kit reaches from
##             the arrival, does the claim ray reach the Check? As built,
##             and again with the shuttle docked at G and its gate open.
##   reads     what the room says: every control by what it does and none
##             of them by when, the gate by what opens it, and the Check
##             in sight from the arrival through nothing but glass.
##   as built  the card's obstruction: G is not reached from the arrival
##             with the base kit.
##   gate      the shuttle opens the gallery: called east from A's board,
##             the gate stays shut while it travels, opens once it stands
##             docked, and shuts behind it when it is called away.
##   V-10      blink, double jump and grapple at the schema maxima, the
##             room as built: no claim from anywhere but G.
##   arrivals  R3 and PT-07: an arrival ANYWHERE on G releases the
##             service stair, and the stair walks back down to A.
##   interlock the gate never shuts on a body: the player in its doorway
##             on G sends the shuttle west from G's own lever.
##
## The baseline route itself -- lift, transfer, shuttle, off at G, the
## stair accepted and the Check confirmed through the real bridge -- is
## `godot-candidate-live`'s next phase, on this same hosted room.
##
## **HARNESS STEPS, declared where they happen:** the player is placed on
## each arrival point on G (standing in for however they got there), and
## back at the room's arrival between cases; `_mobility` places them for
## each blink and flight; health is raised for the census and the V-10
## sweep only, as `godot-minor-claim` does. Every lever is pulled by the
## player, by aiming at it and pressing interact.

const PASSING_FIXTURE := "res://tests/fixtures/passing_zone.json"
## Words that would print an order of operations rather than an action.
const SEQUENCE_WORDS := ["FIRST", "THEN", "NEXT", "STEP ", "1.", "2."]


func _zone_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--passing-zone="):
			return arg.substr("--passing-zone=".length())
	return PASSING_FIXTURE


func _run() -> void:
	await get_tree().process_frame
	var path := _zone_path()
	if not FileAccess.file_exists(path):
		_check(false, "the Zone to play is at '%s' (see N-10)" % path)
		_finish()
		return
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(path))
	var controller := await _enter(zone_data)
	var minor := {}
	for raw: Variant in controller.minors:
		if (raw as Dictionary)["hosted"] is PassingPlatformsHosted:
			minor = raw
	_check(not minor.is_empty(),
			"%s hosts EX50-011: %s" % [str(zone_data.get("zone_id", "?")),
				controller.minors.map(func(m: Dictionary) -> String:
					return "%s:%s" % [m["room_id"], m["hosted"].name])])
	if minor.is_empty():
		_finish()
		return
	var args := OS.get_cmdline_user_args()
	if args.has("--passing-only=place"):
		await _place_survey(controller, minor)
		_finish()
		return
	if args.has("--passing-only=why"):
		await _why_survey(controller, minor)
		_finish()
		return
	var hp := controller.player.hp
	controller.player.hp = 100000.0
	await _census_of(controller, minor)
	controller.player.hp = hp
	_passing_reads(controller, minor)
	await _passing_as_built(controller, minor)
	await _passing_gate(controller, minor)
	await _passing_arrivals_release_the_stair(controller, minor)
	await _passing_interlock(controller, minor)
	_passing_restore(minor)
	if not args.has("--passing-only=quick"):
		# ON A FRESH BUILD OF THE SAME ZONE: the room as built, nothing
		# operated and nothing released. A legal arrival on G during the
		# sweep releases the stair, and that is reported, not reset.
		await _drop(controller)
		controller = await _enter(zone_data)
		for raw: Variant in controller.minors:
			if (raw as Dictionary)["hosted"] is PassingPlatformsHosted:
				minor = raw
		await _passing_mobility(controller, minor)
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_back", "move_left",
			"move_right", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	if failures == 0:
		print("GODOT PASSING HOSTED OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT PASSING HOSTED TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _room_of(minor: Dictionary) -> PassingPlatformsRoom:
	return (minor["hosted"] as PassingPlatformsHosted).room


func _arrival_of(controller: ZoneController, rid: String) -> Vector3:
	var box: AABB = controller.room_bounds.get(rid, AABB())
	return RoomGraphs.place_of(controller.room_places, rid).get("arrival",
			box.get_center())


## Back to the room's arrival, standing. A declared harness step.
func _to_arrival(controller: ZoneController, rid: String) -> void:
	controller.player.global_position = _arrival_of(controller, rid) \
			+ Vector3(0.0, 0.2, 0.0)
	controller.player.velocity = Vector3.ZERO
	await _settle(20)


## Pulled by the player: walked up to, aimed at, interact pressed.
func _pull_lever(controller: ZoneController, lever: CallLever) -> bool:
	var top := lever.global_position + Vector3(0.0, CallLever.BASE.y * 0.25,
			0.0)
	if not await _approach(controller, lever, 1.3, top):
		return false
	var before := lever.pulls
	await _press("interact")
	await _settle(2)
	return lever.pulls > before


## On G: the gallery at the transfer height, east of the shuttle's
## eastern dock.
func _on_g(room: PassingPlatformsRoom) -> Callable:
	return func(at: Vector3) -> bool:
		var local := room.to_local(at)
		return local.y > PassingPlatformsRoom.TRANSFER_Y - 0.3 \
				and local.x > PassingPlatformsRoom.G_WEST - 0.1 \
				and local.z > -1.0 and local.z < 6.0


# ---------------------------------------------------------------------------
# What the room says
# ---------------------------------------------------------------------------

## PT-06, "neither problem nor solution readable", as far as a test can
## read it: every control says what it does (and nothing says in which
## order), the gate says what opens it, G's three open sides are glass,
## and the Check is in sight from the arrival through nothing but glass.
func _passing_reads(controller: ZoneController, minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	print("  -- %s: what the room says" % rid)
	var wrong: Array = []
	for key: String in room.levers.keys():
		var lever: CallLever = room.levers[key]
		if lever.label != str(PassingPlatformsRoom.CONTROL_TEXT.get(key, "")):
			wrong.append("%s reads '%s'" % [key, lever.label])
	var shown: Array = room.levers.values().map(
			func(lever: CallLever) -> String: return lever.interact_prompt())
	_check(wrong.is_empty() and room.levers.size()
			== PassingPlatformsRoom.CONTROL_TEXT.size(),
			"%s: each of its %d controls reads as what it does, e.g. %s; "
			% [rid, room.levers.size(), shown.slice(0, 3)]
			+ "wrong: %s" % [wrong])
	var texts: Array = []
	for node: Node in room.find_children("*", "Label3D", true, false):
		texts.append((node as Label3D).text)
	for lever: CallLever in room.levers.values():
		texts.append(lever.label)
	var ordered: Array = texts.filter(func(text: String) -> bool:
		for word: String in SEQUENCE_WORDS:
			if text.to_upper().contains(word):
				return true
		return false)
	_check(ordered.is_empty(),
			"%s: nothing prints an order of operations (%d signs and labels "
			% [rid, texts.size()] + "read; any that do: %s)" % [ordered])
	var gate_says := texts.filter(func(text: String) -> bool:
		return text.contains("GALLERY GATE") \
				and text.contains("WHILE THE SHUTTLE IS DOCKED"))
	_check(gate_says.size() == 1,
			"%s: the gate says what opens it: %s" % [rid, gate_says])
	var panes: Array = room.find_children("GalleryGlass*", "StaticBody3D",
			false, false).map(func(node: Node) -> String:
				return String(node.name).trim_prefix("GalleryGlass"))
	var sides := ["West", "North", "South"].filter(func(side: String) -> bool:
		return panes.any(func(pane: String) -> bool:
			return pane.begins_with(side)))
	_check(sides.size() == 3 and panes.has("OverGate")
			and panes.has("StairCut") and room.gallery_gate != null,
			"%s: G is glass on its three open sides, with its gate where the "
			% rid + "shuttle docks and its stair cut still closed: %s" % [panes])
	var reward := _reward_in(controller, rid)
	var eye := _arrival_of(controller, rid) + Vector3(0.0,
			Constants.PLAYER_EYE_HEIGHT, 0.0)
	var sight := _through_glass(controller, eye, reward)
	_check(bool(sight["seen"]),
			"%s: the Check is in sight from the arrival, through nothing but "
			% rid + "glass (through %s%s)" % [sight["through"],
				"" if bool(sight["seen"]) else "; stopped by %s"
					% sight["stopped"]])


## Along a line from `eye` to any of the Check's points: is the first
## thing that is not glass the Check itself?
func _through_glass(controller: ZoneController, eye: Vector3,
		reward: RewardObject) -> Dictionary:
	var space := controller.player.get_world_3d().direct_space_state
	var stopped := ""
	for point: Vector3 in ClaimCensus._target_points(reward):
		var skip: Array[RID] = [controller.player.get_rid()]
		var through: Array = []
		for _i in 12:
			var query := PhysicsRayQueryParameters3D.create(eye, point
					+ (point - eye).normalized() * 0.5)
			query.exclude = skip
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			var body: Node = hit["collider"]
			if body == reward:
				return {"seen": true, "through": through, "stopped": ""}
			var named := String(body.name)
			if named.begins_with("GalleryGlass") or named == "GalleryGate":
				through.append(named)
				skip.append((body as CollisionObject3D).get_rid())
				continue
			stopped = named
			break
	return {"seen": false, "through": [], "stopped": stopped}


# ---------------------------------------------------------------------------
# The obstruction, and the machine that opens it
# ---------------------------------------------------------------------------

## The card's obstruction: "No carrier alone reaches G" -- and without
## the carriers, nothing does. From the arrival, with the base kit.
func _passing_as_built(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	print("  -- %s: G, as built, from the arrival" % rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var reach := ClaimCensus.reach(controller.player, box,
			_arrival_of(controller, rid), _living_in(controller, rid))
	var on_g := _on_g(room)
	var cells: Dictionary = reach["cells"]
	var reached_g: Array = []
	var reached_shelf := 0
	for key: Variant in (reach["reached"] as Dictionary).keys():
		var at: Vector3 = cells[key]
		if on_g.call(at):
			reached_g.append(room.to_local(at).snapped(Vector3.ONE * 0.1))
		elif room.to_local(at).y > PassingPlatformsRoom.SHELF_Y - 0.3:
			reached_shelf += 1
	_check(reached_g.is_empty(),
			"%s: G is NOT reached from the arrival with the base kit, the "
			% rid + "room as built (%d cells reached; on G: %s)"
			% [(reach["reached"] as Dictionary).size(), reached_g.slice(0, 6)])
	_note("%s: %d shelf cell(s) reached from the arrival as built"
			% [rid, reached_shelf])


## THE SHUTTLE OPENS THE GALLERY (PT-06's "machinery-operated release
## condition"). Called east by the player at A's board, and called back.
## While it stands docked, the base-kit census is taken again: the gate
## is open then, and the shuttle's deck covers the floor under the lip.
func _passing_gate(controller: ZoneController, minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var gate := room.gallery_gate
	print("  -- %s: the shuttle opens the gallery" % rid)
	_check(gate != null and gate.is_shut()
			and room.h.at_dock() == PassingPlatformsRoom.H_WEST,
			"%s: as built, the shuttle at its west berth and the gallery gate "
			% rid + "shut")
	if gate == null:
		return
	await _to_arrival(controller, rid)
	var called := await _pull_lever(controller, room.levers["H EAST"])
	var most := 0.0
	var frames := 0
	for frame in 2400:
		if room.shuttle_docked_at_g():
			break
		most = maxf(most, gate.openness())
		frames = frame
		await get_tree().physics_frame
	var docked := room.shuttle_docked_at_g()
	_check(called and docked and is_zero_approx(most),
			"%s: 'CALL SHUTTLE EAST' pulled at A's board; the shuttle crossed "
			% rid + "to G in %.1f s, and the gate stayed shut all the way "
			% (frames / 60.0) + "(most open %.2f)" % most)
	var wait := 0
	var opened := false
	for frame in 400:
		if gate.is_open():
			opened = true
			wait = frame
			break
		await get_tree().physics_frame
	_check(opened, "%s: docked at G, the gate opens (%.1f s)"
			% [rid, wait / 60.0])
	# THE LIP, WITH THE GATE OPEN.
	var reward := _reward_in(controller, rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var hp := controller.player.hp
	controller.player.hp = 100000.0
	var census := ClaimCensus.take(controller.player, box,
			_arrival_of(controller, rid), reward, _living_in(controller, rid))
	controller.player.hp = hp
	var where: Array = (census["claims"] as Array).slice(0, 6).map(
			func(c: Dictionary) -> String:
				return "%v" % room.to_local(c["at"]).snapped(Vector3.ONE * 0.1))
	_check(int(census["from_cells"]) == 0,
			"%s: with the shuttle docked and the gate open, nothing the base "
			% rid + "kit reaches from the arrival claims the Check (%d cells "
			% int(census["reached"])
			+ "reached; claims from: %s)" % [where])
	# CALLED AWAY: the gate shuts behind it.
	var back := await _pull_lever(controller, room.levers["H WEST"])
	var shut := false
	for frame in 400:
		if gate.is_shut() and not room.shuttle_docked_at_g():
			shut = true
			wait = frame
			break
		await get_tree().physics_frame
	_check(back and shut,
			"%s: 'CALL SHUTTLE WEST' pulled at A's board; the shuttle left G "
			% rid + "and the gate shut behind it (%.1f s)" % (wait / 60.0))
	var home := func() -> bool:
		return room.h.at_dock() == PassingPlatformsRoom.H_WEST
	_check(await _wait_for(home, 2400),
			"%s: and the shuttle is back at its west berth, the room as built"
			% rid)


# ---------------------------------------------------------------------------
# V-10
# ---------------------------------------------------------------------------

func _passing_mobility(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	print("  -- %s: movement assistance, the room as built (V-10)" % rid)
	var reward := _reward_in(controller, rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var y := PassingPlatformsRoom.TRANSFER_Y
	var aims: Array = [reward.global_position + Vector3(0.0, 1.3, 0.0),
			room.to_global(Vector3(PassingPlatformsRoom.G_WEST + 0.3, y + 1.3,
				PassingPlatformsRoom.H_Z)),
			room.to_global(Vector3(12.5, PassingPlatformsRoom.GLASS_TOP + 1.0,
				2.5))]
	var hp := controller.player.hp
	controller.player.hp = 100000.0
	var tally := await _mobility(controller, rid, box,
			_arrival_of(controller, rid), reward, _on_g(room), aims)
	controller.player.hp = hp
	_note("%s mobility: %s" % [rid, tally["summary"]])
	_note("%s: after the sweep the stair is %s" % [rid, "released, by an "
			+ "arrival on G" if room.stair_released else "still held"])
	_check((tally["claims_off_goal"] as Array).is_empty(),
			"%s: V-10 -- no blink, double jump or grapple puts the Check in "
			% rid + "claim reach from anywhere but G (%s); off-G claims: %s"
			% [tally["summary"], tally["claims_off_goal"]])


# ---------------------------------------------------------------------------
# R3 and PT-07: the way back
# ---------------------------------------------------------------------------

## R3 AND PT-07: "The service stair to the arrival floor, released on ANY
## arrival at G." Points spread over G, clear of the Check's pedestal and
## the plate that used to be the only thing that released it; the stair
## is one latch, so the first point that releases it answers for the rest.
func _passing_arrivals_release_the_stair(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var player := controller.player
	print("  -- %s: an arrival anywhere on G releases the way back" % rid)
	if room.stair_released:
		_check(false, "%s: the stair is still held before anybody arrives "
				% rid + "on G")
		return
	var y := PassingPlatformsRoom.TRANSFER_Y
	var points: Array = [
		Vector3(13.25, y, -0.35), Vector3(13.25, y, 3.55),
		Vector3(11.65, y, 3.6), Vector3(12.5, y, 0.9), Vector3(11.65, y, 0.9),
	]
	var missed: Array = []
	var released_at := Vector3.INF
	for point: Vector3 in points:
		if room.stair_released:
			break
		# HARNESS STEP: an arrival on G, placed as a blink lands.
		player.global_position = room.to_global(point) + Vector3.UP * 0.1
		player.velocity = Vector3.ZERO
		await _settle(40)
		if room.stair_released:
			released_at = point
		else:
			missed.append(point)
	var plate := room.to_local(room.goal_plate.global_position)
	_check(missed.is_empty() and released_at != Vector3.INF,
			"%s: the first arrival on G releases the service stair (at %v, "
			% [rid, released_at] + "%.1f m from the old goal plate; arrivals "
			% Vector2(released_at.x - plate.x, released_at.z - plate.z).length()
			+ "that did not: %s)" % [missed])
	# AND IT IS A WAY BACK: down the stair to A, walked.
	if not room.stair_released:
		return
	var sx := PassingPlatformsRoom.STAIR_X + 0.45
	var head := room.to_global(Vector3(sx, y,
			PassingPlatformsRoom.STAIR_HEAD_Z + 0.6))
	var foot := room.to_global(Vector3(sx, 0.0,
			PassingPlatformsRoom.STAIR_FOOT_Z - 0.8))
	await _walk_to(player, head, AABB(), 900, false, 0.5)
	await _walk_to(player, foot, AABB(), 900, false, 0.6)
	await _settle(20)
	var local := room.to_local(player.global_position)
	var signed := room.service_stair.find_children("*", "Label3D", false,
			false).map(func(label: Label3D) -> String: return label.text)
	_check(absf(local.y) < 0.4 and signed.has("STAIR DOWN TO ARRIVAL"),
			"%s: and the stair, signed %s at its head, walks back down to A (%v)"
			% [rid, signed, local.snapped(Vector3.ONE * 0.1)])


# ---------------------------------------------------------------------------
# §21.2: the gate never shuts on a body
# ---------------------------------------------------------------------------

## The shuttle called back to G from A's board, the stair climbed, and the
## player standing in the open gate sends the shuttle west from G's own
## lever. The gate is told to shut and must not: it holds fully open over
## them, costs nothing and moves them nowhere, and shuts when they step
## out onto G.
func _passing_interlock(controller: ZoneController,
		minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var player := controller.player
	var gate := room.gallery_gate
	print("  -- %s: the gate never shuts on a body" % rid)
	if gate == null or not room.stair_released:
		_check(false, "%s: the gate and the released stair to reach it" % rid)
		return
	var called := await _pull_lever(controller, room.levers["H EAST"])
	var docked := await _wait_for(room.shuttle_docked_at_g, 2400)
	var open := await _wait_for(gate.is_open, 400)
	var y := PassingPlatformsRoom.TRANSFER_Y
	var sx := PassingPlatformsRoom.STAIR_X + 0.45
	await _walk_to(player, room.to_global(Vector3(sx, 0.0,
			PassingPlatformsRoom.STAIR_FOOT_Z - 0.8)), AABB(), 900, false, 0.6)
	await _walk_to(player, room.to_global(Vector3(sx, y,
			PassingPlatformsRoom.STAIR_HEAD_Z + 0.6)), AABB(), 900, false, 0.5)
	await _walk_to(player, room.to_global(Vector3(sx, y, 0.9)), AABB(), 600,
			false, 0.4)
	await _walk_to(player, room.to_global(Vector3(11.6, y, 0.9)), AABB(), 600,
			false, 0.3)
	await _settle(20)
	var in_doorway := gate.doorway_occupied()
	_check(called and docked and open and in_doorway,
			"%s: the shuttle called back to G from A's board, the stair "
			% rid + "climbed, and the player standing in the open gate (%v)"
			% room.to_local(player.global_position).snapped(Vector3.ONE * 0.1))
	var sent := await _pull_lever(controller, room.levers["H WEST (G)"])
	var hp := player.hp
	var at := player.global_position
	var refused := gate.refusals()
	var lowest := 1.0
	for _i in 240:
		lowest = minf(lowest, gate.openness())
		await get_tree().physics_frame
	var left := room.h.at_dock() != PassingPlatformsRoom.H_EAST
	var moved := player.global_position.distance_to(at)
	_check(sent and left and gate.refusals() > refused and lowest > 0.99
			and player.hp >= hp and moved < 0.1,
			"%s: 'SEND SHUTTLE WEST' pulled on G from the doorway; the shuttle "
			% rid + "left and the gate was refused its closure %d time(s), "
			% (gate.refusals() - refused) + "never below %.2f open, costing "
			% lowest + "%.0f health and moving the player %.2f m"
			% [hp - player.hp, moved])
	await _walk_to(player, room.to_global(Vector3(13.1, y, 1.2)), AABB(), 600,
			false, 0.4)
	var shut := await _wait_for(gate.is_shut, 600)
	_check(shut and not gate.doorway_occupied(),
			"%s: stepping out onto G, the gate shuts behind the shuttle" % rid)


## §9 AND THE GATE. A save with the shuttle docked at G loads with the
## gate already open -- in the same frame, not sliding open in front of
## the player -- and one with the shuttle anywhere else loads it shut.
## HARNESS STEP: the rests a save carries, put back through the room's own
## `restore_carrier`, as the hosted room does before the player arrives.
func _passing_restore(minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var gate := room.gallery_gate
	print("  -- %s: the gate comes back with its shuttle" % rid)
	room.restore_carrier(PassingPlatformsRoom.SHUTTLE, room.rail.length(),
			"EAST", false)
	var open_at_once := gate.is_open()
	room.restore_carrier(PassingPlatformsRoom.SHUTTLE, 0.0, "WEST", false)
	var shut_at_once := gate.is_shut()
	_check(open_at_once and shut_at_once,
			"%s: restored docked at G, the gate is open in the same frame; "
			% rid + "restored at the west berth, it is shut (%s, %s)"
			% [open_at_once, shut_at_once])


# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

## DIAGNOSTIC ONLY (`--passing-only=place`): the Check moved over a grid
## of spots on G, and the census re-taken at each -- where on G can it
## stand so that nothing off G claims it? Prints; checks nothing.
func _place_survey(controller: ZoneController, minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var reward := _reward_in(controller, rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var arrival := _arrival_of(controller, rid)
	controller.player.global_position = arrival + Vector3(0.0, 40.0, 0.0)
	await _settle(2)
	var y := PassingPlatformsRoom.TRANSFER_Y
	print("PLACE reward now at %v (room frame)" % room.to_local(
			reward.global_position))
	for ix in range(0, 5):
		for iz in range(0, 9):
			var local := Vector3(11.85 + ix * 0.5, y, -0.4 + iz * 0.7)
			reward.global_position = room.to_global(local)
			await _settle(1)
			var census := ClaimCensus.take(controller.player, box, arrival,
					reward, _living_in(controller, rid))
			var beside := ClaimCensus.claims_from(controller.player,
					_beside(reward, box), reward)
			print("PLACE %v claims %d control %s" % [local,
					census["from_cells"], beside])
			if ix == 4 and iz in [1, 4]:
				for c: Dictionary in census["claims"]:
					print("PLACE   from %v eye %v rise %.2f" % [
							room.to_local(c["at"]).snapped(Vector3.ONE * 0.1),
							room.to_local(c["eye"]).snapped(Vector3.ONE * 0.1),
							float(c["rise"])])


## DIAGNOSTIC ONLY (`--passing-only=why`): for each claim the census
## finds, the ray that makes it -- from which eye, to which point of the
## Check, and what else lies on it. Prints; checks nothing.
func _why_survey(controller: ZoneController, minor: Dictionary) -> void:
	var rid := str(minor["room_id"])
	var room := _room_of(minor)
	var reward := _reward_in(controller, rid)
	var box: AABB = controller.room_bounds.get(rid, AABB())
	var census := ClaimCensus.take(controller.player, box,
			_arrival_of(controller, rid), reward, _living_in(controller, rid))
	var space := controller.player.get_world_3d().direct_space_state
	print("WHY reward at %v (room frame); room basis %s origin %v" % [
			room.to_local(reward.global_position), room.global_basis,
			room.global_position])
	var claims: Array = (census["claims"] as Array).slice(0, 4)
	# `--passing-why-at=x,y,z;x,y,z`: feet positions in the room's frame.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--passing-why-at="):
			claims.clear()
			for spot: String in arg.substr("--passing-why-at=".length()) \
					.split(";"):
				var xyz := spot.split_floats(",")
				var feet := room.to_global(Vector3(xyz[0], xyz[1], xyz[2]))
				claims.append({"at": feet, "eye": feet + Vector3(0.0,
						Constants.PLAYER_EYE_HEIGHT, 0.0)})
	for c: Dictionary in claims:
		var eye: Vector3 = c["eye"]
		print("WHY claim from %v eye %v" % [room.to_local(c["at"]).snapped(
				Vector3.ONE * 0.01), room.to_local(eye).snapped(
				Vector3.ONE * 0.01)])
		for point: Vector3 in ClaimCensus._target_points(reward):
			var query := PhysicsRayQueryParameters3D.create(eye, eye
					+ (point - eye).normalized() * ClaimCensus.CLAIM_REACH)
			query.exclude = [controller.player.get_rid()]
			var hit := space.intersect_ray(query)
			var what := "nothing"
			if not hit.is_empty():
				var collider: Node = hit["collider"]
				what = "%s at %v" % [room.get_path_to(collider) if
						room.is_ancestor_of(collider) else collider.name,
						room.to_local(hit["position"]).snapped(
							Vector3.ONE * 0.01)]
			print("WHY   to %v: %s" % [room.to_local(point).snapped(
					Vector3.ONE * 0.01), what])
