class_name ResumeLiveDriver
extends "res://tests/candidate_live_driver.gd"
## H-RESUME-R / PT-16 — AN ENCOUNTER RESUMES AS IT WAS LEFT
## (`--resume-live=<phase>`).
##
##     make godot-resume-live
##
## The owner's ruling (D-06): "ordinary quit/reload should preserve
## encounter state. Enemies I killed stay dead; a partially cleared
## encounter restores the enemies that were still alive. Reloading is not
## an encounter-reset event." And for a save from before any of this was
## recorded: "no fabricated cleared rooms, but also absolutely no
## legacy-save ambushes."
##
## The room is `c005`, the power-cell room of the candidate the owner
## played: two bulwarks, a kill_all objective, and a warp station that
## comes online when the room's puzzle is solved. The station is where a
## resume puts the player -- and the first bulwark's post is almost on top
## of it, which is PT-16 exactly: a reload restored the player at the
## station and rebuilt both bulwarks around them.
##
## Each phase is a NEW client beside a NEW bridge (`--candidate=all`, the
## candidate launcher's profile); only the save crosses:
##
##   seed             the campaign and its first Zone.
##   partial          into c005; its station online; ONE bulwark killed.
##   partial_restore  both processes new. The killed bulwark is absent
##                    before anything acts; the survivor is at its post;
##                    the player is not put among the living; nothing
##                    struck the player while the Zone was being built.
##                    Then the survivor is killed.
##   clear_restore    both processes new. No bulwark in c005, the player
##                    at the station, kill_all satisfied, and nothing
##                    strikes them.
##   legacy           against a COPY of the save made after `partial`,
##                    with the per-enemy record removed (a save from
##                    before it existed). Nothing is invented: both
##                    bulwarks are back, the player is at the room's
##                    arrival rather than the station, the player is TOLD
##                    why, and nothing struck them during the build. Then
##                    one kill is recorded, which is persistence taking
##                    over from that point.
##
## **HARNESS STEPS, declared:** the player is PLACED at c005's arrival
## once, in `partial` (the walk there is other suites' business); c005's
## station is brought online through the same two calls a solved puzzle
## makes (`WarpStation.repair`, then the controller's own
## `_station_came_online`) -- the puzzle is not what is under test; and a
## bulwark is killed through the ordinary damage path, because HOW it dies
## is not under test here, only that it stays dead.

const RESUME_PHASE_FLAG := "--resume-live="
const RESUME_SAVE_FLAG := "--resume-save-dir="
const ROOM := "c005"
const STATION := "st:c005"
## How long the player stands still after control returns, to count what
## reaches them.
const WATCH_SECONDS := 5.0


static func resume_phase() -> String:
	return _arg(RESUME_PHASE_FLAG)


func _run() -> void:
	await get_tree().process_frame
	BridgeClient.error_received.connect(func(err: Dictionary) -> void:
		_errors.append(err))
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		match resume_phase():
			"seed":
				await _resume_seed()
			"partial":
				await _partial()
			"partial_restore":
				await _partial_restore()
			"clear_restore":
				await _clear_restore()
			"legacy":
				await _legacy()
			_:
				_check(false, "no --resume-live phase was named")
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"move_back", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	var phase := resume_phase().to_upper()
	if failures == 0:
		print("GODOT RESUME LIVE %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT RESUME LIVE %s: %d failures in %d checks"
				% [phase, failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


# ------------------------------------------------------------- helpers

func _living(controller: ZoneController) -> Array:
	return _living_in(controller, ROOM)


## The per-enemy record the bridge holds for this Zone, read by name:
## `null` when there is none (a save from before it existed, or a
## runtime from before it did).
func _defeated_served() -> Variant:
	var progress := _served()
	return progress.get("defeated") if progress.has("defeated") else null


func _nearest_living(controller: ZoneController, at: Vector3) -> float:
	var nearest := INF
	for raw: Variant in _living(controller):
		nearest = minf(nearest, (raw as Enemy).global_position.distance_to(at))
	return nearest


## Wait for the verdict and count every strike from the very first frame
## the player exists -- the build included -- then stand still for
## `WATCH_SECONDS`, counting again. Counted from `damaged_from` and each
## `hp_changed` fall, never from health read at the end.
func _through_the_portal_counting() -> Dictionary:
	var tally := {"during_build": 0, "after": 0, "damage_after": 0.0,
		"controller": null, "placed_at": Vector3.INF, "nearest": INF,
		"living_at_control": -1, "room_at_control": "", "died": []}
	var hooked := [false]
	var watcher := func() -> void:
		var zone := main.zone as ZoneController
		if hooked[0] or zone == null or zone.player == null:
			return
		hooked[0] = true
		# EVERY DEATH THE ENGINE SEES, by declared identity, from the
		# moment the Zone exists -- so a record can be held to exactly
		# what died, not to what this harness happened to kill (PPT-02:
		# c006's melee can chase the player off the hall's drop and die
		# by the fall rule, and that death is recorded like any other).
		for record: Dictionary in zone._chambers:
			for raw: Variant in record["enemies"]:
				if is_instance_valid(raw):
					(raw as Enemy).enemy_died.connect(
							func(dead: Enemy) -> void:
								(tally["died"] as Array).append(dead.member))
		zone.player.damaged_from.connect(func(_at: Vector3) -> void:
			if zone.layout_verdict == "ACCEPTED":
				tally["after"] += 1
			else:
				tally["during_build"] += 1)
		var last := [zone.player.hp]
		zone.player.hp_changed.connect(func(hp: float, _s: float) -> void:
			if hp < last[0] and zone.layout_verdict == "ACCEPTED":
				tally["damage_after"] += last[0] - hp
			last[0] = hp)
	get_tree().process_frame.connect(watcher)
	var controller := await _through_the_portal()
	get_tree().process_frame.disconnect(watcher)
	if controller == null:
		return tally
	var player := controller.player
	tally["controller"] = controller
	tally["placed_at"] = player.global_position
	tally["room_at_control"] = _room_holding(controller,
			player.global_position)
	tally["living_at_control"] = _living(controller).size()
	tally["nearest"] = _nearest_living(controller, player.global_position)
	await _settle(int(WATCH_SECONDS * 60.0))
	return tally


## Wait for `predicate` without making it a claim.
func _quietly(predicate: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if predicate.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return false


## Kill one living bulwark in the room through the ordinary damage path
## (declared harness step: how it dies is not under test).
func _kill_one(controller: ZoneController) -> String:
	var living := _living(controller)
	if living.is_empty():
		return ""
	var target: Enemy = living[0]
	var member: Variant = target.get("member")
	var died := [false]
	target.enemy_died.connect(func(_e: Enemy) -> void: died[0] = true)
	target.take_damage(target.max_hp * 40.0, Vector3.DOWN, 0.0)
	await _await_live("the bulwark dies", func() -> bool: return died[0],
			5.0)
	return str(member) if member != null else "(no member identity)"


# --------------------------------------------------------------- phases

func _resume_seed() -> void:
	if not await _campaign():
		return
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	if not await _await_live("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			90.0):
		return
	var zone: Dictionary = BridgeClient.active_zone().get("zone", {})
	var bulwarks := 0
	for raw: Variant in zone.get("chambers", []) as Array:
		var chamber: Dictionary = raw
		if str(chamber.get("id", "")) != ROOM:
			continue
		for group: Variant in chamber.get("enemies", []) as Array:
			if str((group as Dictionary).get("archetype", "")) == "bulwark":
				bulwarks += int((group as Dictionary).get("count", 0))
	_check(bulwarks == 2, "the served Zone's %s declares two bulwarks (%d)"
			% [ROOM, bulwarks])
	print("seeded: %s with %s's two bulwarks" % [ZONE_ID, ROOM])


func _partial() -> void:
	if not await _campaign():
		return
	var controller := await _through_the_portal()
	if controller == null:
		return
	var player := controller.player
	# HARNESS STEP: placed at the room's arrival, once.
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			ROOM).get("arrival", (controller.room_bounds[ROOM] as AABB)
				.get_center())
	player.global_position = arrival
	player.velocity = Vector3.ZERO
	await _settle(4)
	_check(_living(controller).size() == 2,
			"%s holds its two bulwarks on the first entry" % ROOM)
	# HARNESS STEP: the station online by the calls a solved puzzle makes.
	var station: WarpStation = controller._station_by_id(STATION)
	if station == null:
		_check(false, "%s placed its station %s" % [ROOM, STATION])
		return
	station.repair()
	controller._station_came_online(STATION, "")
	await _await_live("the bridge records the resume station",
			func() -> bool:
				return str(_served().get("resume_anchor", "")) == STATION,
			10.0)
	var killed := await _kill_one(controller)
	await _settle(30)
	# A WAIT, NOT A CLAIM: the claims are the restore phase's, after both
	# processes are new. A runtime that records nothing reaches it too.
	await _quietly(func() -> bool:
		var d: Variant = _defeated_served()
		return typeof(d) == TYPE_ARRAY and (d as Array).has(killed), 5.0)
	print("played: %s's station online; %s killed; the bridge holds %s"
			% [ROOM, killed, _defeated_served()])
	_check(_living(controller).size() == 1,
			"one bulwark left alive in %s" % ROOM)


func _partial_restore() -> void:
	if not await _campaign():
		return
	var tally := await _through_the_portal_counting()
	var controller: ZoneController = tally["controller"]
	if controller == null:
		return
	var station := controller._station_by_id(STATION)
	var at_station := station != null and Vector2(
			(tally["placed_at"] as Vector3).x - station.global_position.x,
			(tally["placed_at"] as Vector3).z - station.global_position.z) \
			.length() < 3.0
	print("restored: %d bulwark(s) in %s at control; the player in '%s' "
			% [tally["living_at_control"], ROOM, tally["room_at_control"]]
			+ "%s; nearest living %.1f m; strikes during the build %d, "
			% ["AT THE STATION" if at_station else "at the arrival",
				tally["nearest"], tally["during_build"]]
			+ "in the next %.0f s %d (%.1f damage)"
			% [WATCH_SECONDS, tally["after"], tally["damage_after"]])
	_check(int(tally["living_at_control"]) == 1,
			"the bulwark killed before the restart stays dead: %d alive in "
			% tally["living_at_control"] + "%s, and 1 is right" % ROOM)
	_check(int(tally["during_build"]) == 0,
			"nothing struck the player while the Zone was being built (%d)"
			% tally["during_build"])
	_check(not at_station and float(tally["nearest"]) > 6.0,
			"the resumed player is not put among the living: at %s's "
			% ROOM + "arrival, not its station, %.1f m from the survivor"
			% tally["nearest"])
	var killed := await _kill_one(controller)
	await _settle(30)
	await _quietly(func() -> bool:
		var d: Variant = _defeated_served()
		return typeof(d) == TYPE_ARRAY and (d as Array).size() == 2, 5.0)
	print("played: %s killed; the bridge holds %s"
			% [killed, _defeated_served()])


func _clear_restore() -> void:
	if not await _campaign():
		return
	var tally := await _through_the_portal_counting()
	var controller: ZoneController = tally["controller"]
	if controller == null:
		return
	var satisfied := false
	for record: Dictionary in controller._chambers:
		if str((record["chamber"] as Dictionary).get("id", "")) == ROOM:
			satisfied = bool(record["satisfied"])
	var station := controller._station_by_id(STATION)
	var at_station := station != null and Vector2(
			(tally["placed_at"] as Vector3).x - station.global_position.x,
			(tally["placed_at"] as Vector3).z - station.global_position.z) \
			.length() < 3.0
	print("restored: %d bulwark(s) in %s; the player %s; kill_all %s; "
			% [tally["living_at_control"], ROOM,
				"at the station" if at_station else "elsewhere", satisfied]
			+ "strikes %d during the build, %d after"
			% [tally["during_build"], tally["after"]])
	_check(int(tally["living_at_control"]) == 0 and satisfied,
			"a cleared room stays cleared: no bulwark in %s, kill_all "
			% ROOM + "satisfied")
	_check(at_station,
			"with nobody left, the player resumes at the station itself")
	_check(int(tally["during_build"]) == 0 and int(tally["after"]) == 0,
			"nothing strikes the player (%d during the build, %d after)"
			% [tally["during_build"], tally["after"]])


func _legacy() -> void:
	if not await _campaign():
		return
	_check(_defeated_served() == null or not _served().has("defeated")
			or BridgeClient.active_zone().is_empty(),
			"the copied save holds no per-enemy record for %s" % ZONE_ID)
	var tally := await _through_the_portal_counting()
	var controller: ZoneController = tally["controller"]
	if controller == null:
		return
	var station := controller._station_by_id(STATION)
	var at_station := station != null and Vector2(
			(tally["placed_at"] as Vector3).x - station.global_position.x,
			(tally["placed_at"] as Vector3).z - station.global_position.z) \
			.length() < 3.0
	var told: Variant = controller.get("resume_notice")
	print("legacy: %d bulwark(s) in %s; the player in '%s' %s; told: %s; "
			% [tally["living_at_control"], ROOM, tally["room_at_control"],
				"AT THE STATION" if at_station else "at the arrival", told]
			+ "strikes during the build %d" % tally["during_build"])
	_check(int(tally["living_at_control"]) == 2,
			"with no record, nothing is invented: both bulwarks are back (%d)"
			% tally["living_at_control"])
	_check(not at_station and float(tally["nearest"]) > 6.0,
			"and the player is not put among them: at %s's arrival, %.1f m "
			% [ROOM, tally["nearest"]] + "from the nearest")
	_check(told != null and str(told) != "",
			"the player is TOLD why the enemies are back: '%s'" % told)
	_check(int(tally["during_build"]) == 0,
			"nothing struck the player while the Zone was being built (%d)"
			% tally["during_build"])
	var killed := await _kill_one(controller)
	await _settle(30)
	await _await_live("persistence takes over from here",
			func() -> bool:
				var d: Variant = _defeated_served()
				return typeof(d) == TYPE_ARRAY and (d as Array).has(killed),
			5.0)
	var died: Array = (tally["died"] as Array).duplicate()
	died.sort()
	var held: Array = (_defeated_served() as Array).duplicate() \
			if typeof(_defeated_served()) == TYPE_ARRAY else []
	held.sort()
	_check(held.has(killed) and held == died,
			"from this point the record is kept: the bridge holds exactly "
			+ "the members the engine saw die, %s (died %s; killed here %s)"
			% [held, died, killed])
