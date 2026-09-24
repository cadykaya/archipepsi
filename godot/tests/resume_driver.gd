extends "res://tests/transport_driver.gd"
## H-RESUME-R, OFFLINE: WHAT THE ZONE BUILDS FROM A SAVED ENCOUNTER
## (`--resume-test`).
##
##     make godot-resume
##
## `candidate_zone.json` -- the candidate profile the owner played -- is
## built through the real `ZoneController` with the progress a resume
## would carry, and each case reads what `setup` produced BEFORE A SINGLE
## PHYSICS STEP has run: the moment that matters, because an enemy that
## exists for one frame is an enemy that could have acted.
##
## The two-process proof -- both processes killed and relaunched, the
## record crossing only through the save -- is `godot-resume-live`. This
## suite is its fast, deterministic companion, and the one the runtime
## sabotages break.
##
## The room is `c005`: two bulwarks and the station a resume returns to,
## the first bulwark's post almost on top of it (PT-16).

const CANDIDATE := "res://tests/fixtures/candidate_zone.json"
const ROOM := "c005"
const STATION := "st:c005"


func _run() -> void:
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(CANDIDATE))
	await _partly_cleared(zone_data)
	await _fully_cleared(zone_data)
	await _no_record(zone_data)
	await _a_first_entry(zone_data)
	await _a_death_is_reported_once(zone_data)
	_finish()


func _finish() -> void:
	if failures == 0:
		print("GODOT RESUME TESTS OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT RESUME TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


## Build the Zone as a resume would: the record, the anchor and the
## stations online are handed over BEFORE `setup`, exactly where `Main`
## hands them. Returns the controller before any physics step.
func _resumed(zone_data: Dictionary, defeated: Variant,
		anchor := STATION) -> ZoneController:
	_zone_data = zone_data
	var controller := ZoneController.new()
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	controller.add_child(pool)
	get_tree().root.add_child(controller)
	controller.defeated_carried = defeated
	controller.resume_anchor = anchor
	if anchor != "":
		controller.stations_online = {anchor: true}
	BridgeClient.sent_intents.clear()
	controller.setup(zone_data)
	return controller


func _drop_zone(controller: ZoneController) -> void:
	controller.queue_free()
	for _i in 3:
		await get_tree().process_frame


## Every member `setup` built, by declared identity, in one room.
func _members_in(controller: ZoneController, room: String) -> Array:
	var out: Array = []
	for record: Dictionary in controller._chambers:
		if str((record["chamber"] as Dictionary).get("id", "")) != room:
			continue
		for enemy: Variant in record["enemies"]:
			if is_instance_valid(enemy) and not (enemy as Enemy)._dead:
				out.append((enemy as Enemy).member)
	out.sort()
	return out


func _where(controller: ZoneController) -> Dictionary:
	var player := controller.player
	var station := controller._station_by_id(STATION)
	var at := player.global_position
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			ROOM).get("arrival", Vector3.INF)
	return {
		"room": _room_holding(controller, at),
		"at_station": station != null and Vector2(
				at.x - station.global_position.x,
				at.z - station.global_position.z).length() < 3.0,
		"at_arrival": Vector2(at.x - arrival.x, at.z - arrival.z).length()
				< 1.0,
	}


func _satisfied(controller: ZoneController, room: String) -> bool:
	for record: Dictionary in controller._chambers:
		if str((record["chamber"] as Dictionary).get("id", "")) == room:
			return bool(record["satisfied"])
	return false


# ---------------------------------------------------------------- cases

func _partly_cleared(zone_data: Dictionary) -> void:
	print("  -- a partly cleared room")
	var controller := await _resumed(zone_data,
			{"%s/bulwark#0" % ROOM: true})
	var built := _members_in(controller, ROOM)
	var where := _where(controller)
	_check(built == ["%s/bulwark#1" % ROOM],
			"the defeated bulwark is never built, before any physics step; "
			+ "the survivor is: %s" % [built])
	_check(_members_in(controller, "c011").size() == 5,
			"another room's encounter is untouched (c011: %d divers)"
			% _members_in(controller, "c011").size())
	_check(where["room"] == ROOM and where["at_arrival"]
			and not where["at_station"],
			"the player is restored at %s's arrival, not at the station "
			% ROOM + "among the living (%s)" % [where])
	_check(controller.resume_notice.begins_with("1 LEFT IN C005"),
			"and is told why: '%s'" % controller.resume_notice)
	await _drop_zone(controller)


func _fully_cleared(zone_data: Dictionary) -> void:
	print("  -- a cleared room")
	var controller := await _resumed(zone_data,
			{"%s/bulwark#0" % ROOM: true, "%s/bulwark#1" % ROOM: true})
	var where := _where(controller)
	_check(_members_in(controller, ROOM).is_empty()
			and _satisfied(controller, ROOM),
			"nobody is built in a cleared room, and its kill_all is "
			+ "satisfied at once")
	_check(where["at_station"] and controller.resume_notice == "",
			"with nobody left, the player resumes at the station itself, "
			+ "and nothing needs saying (%s)" % [where])
	await _drop_zone(controller)


func _no_record(zone_data: Dictionary) -> void:
	print("  -- a save with no record (unknown)")
	var controller := await _resumed(zone_data, null)
	var where := _where(controller)
	_check(_members_in(controller, ROOM) == ["%s/bulwark#0" % ROOM,
				"%s/bulwark#1" % ROOM],
			"nothing is invented: with no record, every member is built")
	_check(where["at_arrival"] and not where["at_station"],
			"and the player is not put among them: at %s's arrival (%s)"
			% [ROOM, where])
	_check(controller.resume_notice.begins_with("NO RECORD"),
			"the player is told the encounter is back and why: '%s'"
			% controller.resume_notice)
	await _drop_zone(controller)


func _a_first_entry(zone_data: Dictionary) -> void:
	print("  -- a first entry")
	var controller := await _resumed(zone_data, null, "")
	var entrance: Transform3D = controller.player.global_transform
	_check(controller.resume_notice == ""
			and _room_holding(controller, entrance.origin) == "c001",
			"a first entry starts at the Zone's own arrival, as always, "
			+ "with nothing to say ('%s')" % controller.resume_notice)
	await _drop_zone(controller)


func _a_death_is_reported_once(zone_data: Dictionary) -> void:
	print("  -- a death, reported by declared identity")
	var controller := await _resumed(zone_data, {})
	var survivors: Array = []
	for record: Dictionary in controller._chambers:
		if str((record["chamber"] as Dictionary).get("id", "")) == ROOM:
			survivors = record["enemies"]
	var target: Enemy = survivors[1]
	target.take_damage(target.max_hp * 40.0, Vector3.DOWN, 0.0)
	await _settle(4)
	var sent := BridgeClient.sent_intents.filter(
			func(i: Dictionary) -> bool:
				return str(i.get("type", "")) == "enemy_defeated")
	_check(sent.size() == 1 and str(sent[0].get("member", ""))
			== "%s/bulwark#1" % ROOM
			and str(sent[0].get("zone_id", "")) == controller.zone_id,
			"one death, one report, under its declared identity: %s" % [sent])
	_check(controller.defeated_members().has("%s/bulwark#1" % ROOM),
			"and it is remembered for a Hub return before the snapshot")
	await _drop_zone(controller)
