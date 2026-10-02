extends "res://tests/transport_driver.gd"
## PT-13 / V-05 IN THE ROOM THE OWNER PLAYED (`--flyer-room`).
##
##     make godot-flyer-room
##
## `candidate_zone.json` is the candidate profile on the played Zone --
## what the candidate launcher composes. Its only flyers are the five
## divers in `c011`, an arena with a 1.64 m gallery and a kill_all
## objective: the flyers the owner met, and the ones that "seemingly do
## not attack".
##
## The player starts at `c011`'s own arrival (a declared harness step,
## below). Then, counting every number from an event as it happens
## (never from health read at the end, which is how an earlier diagnosis
## reported "zero damage"):
##
## 1. **Grounded, five seconds, standing still.** Every diver notices and
##    WAITS: no dive commits and nothing lands, and its eye is at the
##    watching level -- waiting reads as watching, not as idle.
## 2. **Jumping on the real binding, six seconds.** Leaving the ground
##    draws dives, and they land.
## 3. **Cleared with the Static Pulse** held through `Input`, the camera
##    aimed at each diver's body -- which is its visible body now
##    (H-FLYER-HIT) -- by the suite's own `_clear_room`. All five die,
##    counted from `enemy_died`, and the room's kill_all is satisfied.
##
## **HARNESS STEPS, declared:** the layout hold released after the
## verdict wait, as every hosted driver does; and the player's health
## raised before the walk, so that a death cannot cut a recording short.
## Deaths are still counted, from `died`.

const CANDIDATE := "res://tests/fixtures/candidate_zone.json"
const ROOM := "c011"


func _run() -> void:
	await get_tree().process_frame
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(CANDIDATE))
	var controller := await _enter(zone_data)
	var player := controller.player
	player.hp = 100000.0
	var divers_declared := 0
	for raw: Variant in (_chamber(ROOM).get("enemies", []) as Array):
		if str((raw as Dictionary).get("archetype", "")) == "diver":
			divers_declared += int((raw as Dictionary).get("count", 0))
	_check(divers_declared == 5,
			"the played Zone's c011 declares its divers (%d)" % divers_declared)

	# **HARNESS STEP: placed at the room's own arrival.** The walk along
	# the spine is not what is under test here, and on this fixture the
	# suite's walker stalls in c003's platform course (noted, not hidden:
	# `PPT-01` in the ledger). The room, its geometry, its five divers
	# where the Zone placed them and everything after this line are the
	# real ones, played.
	var arrival: Vector3 = RoomGraphs.place_of(controller.room_places,
			ROOM).get("arrival", (controller.room_bounds[ROOM] as AABB)
				.get_center())
	player.global_position = arrival
	player.velocity = Vector3.ZERO
	await _settle(2)
	_check(_room_holding(controller, player.global_position) == ROOM,
			"the player stands in %s, at its arrival" % ROOM)
	var divers := _living_in(controller, ROOM)
	_check(divers.size() == divers_declared,
			"all %d divers are alive when the player arrives" % divers.size())
	if divers.is_empty():
		_finish()
		return

	var tally := {"telegraphs": 0, "dives": 0, "impacts": 0, "damage": 0.0,
		"deaths": 0, "killed": 0, "last_hp": player.hp, "pending": 0.0,
		"by_source": {}}
	for raw: Variant in divers:
		var diver: Enemy = raw
		diver.telegraph_started.connect(func(kind: String, _d: float) -> void:
			if kind == "dive":
				tally["telegraphs"] += 1)
		diver.telegraph_finished.connect(func(kind: String, done: bool) -> void:
			if kind == "dive" and done:
				tally["dives"] += 1)
		diver.enemy_died.connect(func(_e: Enemy) -> void:
			tally["killed"] += 1)
	# EVERY IMPACT IS ATTRIBUTED to what struck it. `hp_changed` fires
	# before `damaged_from` inside the player's `take_damage`, so the fall
	# just recorded belongs to the source named next. Only a diver's own
	# impacts count as a diver's; anything else that reached the player in
	# this room (a neighbour that followed them in) is reported by name.
	player.hp_changed.connect(func(hp: float, _shield: float) -> void:
		if hp < float(tally["last_hp"]):
			tally["pending"] = float(tally["last_hp"]) - hp
		tally["last_hp"] = hp)
	player.damaged_from.connect(func(at: Vector3) -> void:
		var source := _source_of(at)
		var fall := float(tally["pending"])
		tally["pending"] = 0.0
		var by: Dictionary = tally["by_source"]
		if not by.has(source):
			by[source] = {"impacts": 0, "damage": 0.0}
		by[source]["impacts"] += 1
		by[source]["damage"] += fall
		if source == "diver":
			tally["impacts"] += 1
			tally["damage"] += fall)
	player.died.connect(func() -> void: tally["deaths"] += 1)

	# 1. GROUNDED AND STILL.
	await _settle(300)
	var watching := 0
	for raw: Variant in divers:
		var diver: Enemy = raw
		# Read by name, so this same driver also runs against a runtime
		# from before the eye states existed -- the reproduction.
		var level: Variant = diver.get("_eye_level")
		var named: Dictionary = (diver.get_script() as Script) \
				.get_script_constant_map()
		if is_instance_valid(diver) and diver._has_noticed \
				and level != null and named.has("EYE_WATCHING") \
				and is_equal_approx(float(level),
					float(named["EYE_WATCHING"])):
			watching += 1
	print("    [c011 / grounded] telegraphs %d, dives %d, impacts %d, "
			% [tally["telegraphs"], tally["dives"], tally["impacts"]]
			+ "damage %.1f, watching %d of %d" % [tally["damage"], watching,
				divers.size()])
	_check(tally["dives"] == 0 and tally["impacts"] == 0,
			"c011, the player standing on the floor: the divers WAIT -- "
			+ "%d dives, %d impacts in 5 s" % [tally["dives"], tally["impacts"]])
	_check(watching == divers.size(),
			"c011, waiting reads as watching: %d of %d divers have noticed "
			% [watching, divers.size()] + "the player and hold their eye "
			+ "at the watching level")

	# 2. JUMPING, on the real binding.
	var before := tally.duplicate()
	for frame in 360:
		if frame % 48 == 0:
			Input.action_press("jump")
		elif frame % 48 == 1:
			Input.action_release("jump")
		await get_tree().physics_frame
	Input.action_release("jump")
	await _settle(30)
	print("    [c011 / jumping] impacts by source: %s" % [tally["by_source"]])
	var dives := int(tally["dives"]) - int(before["dives"])
	var impacts := int(tally["impacts"]) - int(before["impacts"])
	var damage := float(tally["damage"]) - float(before["damage"])
	print("    [c011 / jumping] telegraphs %d, dives %d, impacts %d, "
			% [int(tally["telegraphs"]) - int(before["telegraphs"]), dives,
				impacts] + "damage %.1f" % damage)
	_check(dives >= 1 and impacts >= 1 and damage > 0.0,
			"c011, the player jumping: leaving the ground draws dives and "
			+ "they land (%d dives, %d impacts, %.1f damage)"
			% [dives, impacts, damage])

	# 3. CLEARED, with ordinary aim at the bodies the player can see.
	var fight := await _clear_room(controller, ROOM)
	await _settle(30)
	var satisfied := false
	for record: Dictionary in controller._chambers:
		if str((record["chamber"] as Dictionary).get("id", "")) == ROOM:
			satisfied = bool(record["satisfied"])
	print("    [c011 / cleared] killed %d of %d in %.1f s; player deaths %d"
			% [tally["killed"], divers.size(), float(fight["frames"]) * DT,
				tally["deaths"]])
	_check(int(tally["killed"]) == divers.size() and satisfied,
			"c011 cleared with the Static Pulse aimed at the divers' bodies: "
			+ "%d of %d killed, counted from enemy_died; kill_all satisfied: %s"
			% [tally["killed"], divers.size(), satisfied])
	_finish()


## What struck the player from `at`: the archetype of the enemy whose
## body or pivot is there (a diver strikes from its body centre, a
## walker from its pivot), or "other".
func _source_of(at: Vector3) -> String:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.body_centre().distance_to(at) < 0.3 \
				or enemy.global_position.distance_to(at) < 0.3:
			return enemy.archetype
	return "other"


func _finish() -> void:
	if failures == 0:
		print("GODOT FLYER ROOM OK (%d checks, %d notes)"
				% [checks, notes.size()])
	else:
		print("GODOT FLYER ROOM: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
