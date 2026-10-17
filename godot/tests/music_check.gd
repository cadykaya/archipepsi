class_name MusicCheck
extends "res://tests/shunter_check.gd"
## CONDI'S MUSIC ON HER HOOKS (`--unified-live=music`), through the real
## Hub, the real Freight Bay and a real Crossing: each row of her README's
## tables, in the order a player meets them. What is checked is what the
## runtime reports (its state, its player, its bus) and which calls were
## made -- the listening is the owner's.
##
## **HARNESS STEPS, declared:** the player is placed (in the station, in the
## annex, in the Shunter's sight); the Shunter is downed through
## `take_damage`; the player's death is `take_damage` past their HP.

var music: UnifiedMusic


func _run() -> void:
	await get_tree().process_frame
	BridgeClient.error_received.connect(func(err: Dictionary) -> void:
		_errors.append(err))
	_load_state()
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		match phase_from_cmdline():
			"music":
				await _phase_music()
			_:
				await super._run()
				return
	_save_state()
	_finish()


func _phase_music() -> void:
	if not await _await_live("the campaign",
			func() -> bool: return BridgeClient.hub_mode() != "NO_CAMPAIGN",
			30.0):
		return
	hub_now = await _the_hub()
	if hub_now == null:
		return
	bay = hub_now.freight_bay
	sh = bay.shunter
	music = main.music
	_check(music != null and music.station != null and music.freight != null,
			"the music director has both of Condi's cues")
	if music == null or music.station == null or music.freight == null:
		return
	var station: Node = music.station
	var freight: Node = music.freight
	var sp: AudioStreamPlayer = station.get("_player")
	var fp: AudioStreamPlayer = freight.get("_player")

	# -- the mix: buses ------------------------------------------------------
	_check(AudioServer.get_bus_index(&"Music") >= 0
			and AudioServer.get_bus_index(&"SFX") >= 0,
			"the bus layout has Music and SFX")
	var music_db := AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(&"Music"))
	_check(music_db <= 4.0, "the Music bus is inside Condi's +4 dB headroom "
			+ "(%.1f dB)" % music_db)
	_check(sp.bus == &"Music" and fp.bus == &"Music"
			and music.stinger.bus == &"Music",
			"both cues and the stinger player are on Music")
	_check(sh._horn.bus == &"SFX" and sh._horn.stream != null,
			"the Shunter's horn is Condi's tuned horn, on SFX")
	_check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"SFX"))
			== 0, "nothing on the SFX bus ducks or colours the horn")
	_results["music_bus_db"] = music_db

	# -- the station ----------------------------------------------------------
	await _settle(30)
	_check(music.where == "station" and sp.playing and not fp.playing
			and String(station.get_state_name()) == "Explore",
			"in Station 1: the station music plays, in Explore "
			+ "(%s, %s)" % [music.where, station.get_state_name()])
	var t0 := sp.get_playback_position()
	await _settle(60)
	_check(sp.get_playback_position() > t0,
			"the station loop advances (%.2f -> %.2f s)"
			% [t0, sp.get_playback_position()])

	# -- into the Freight Bay ------------------------------------------------
	await _place(bay.to_global(Vector3(7.0, FreightBay.BOOTH_FLOOR + 0.1, 12.6)))
	await _settle(10)
	_check(music.where == "freight" and fp.playing and not sp.playing
			and String(freight.get_state_name()) == "Exploration",
			"into the Freight Bay: station stops, Freight Bay plays Exploration "
			+ "(%s)" % freight.get_state_name())

	# -- the horn: engage -> Entry (+ stinger) -> Combat ----------------------
	var calls_before := music.calls.size()
	await _arena_pose(FreightBay.DOCK, PI, Vector3(6.0, 0.0, -4.0))
	var horned := await _await_live("the horn", func() -> bool:
			return sh.state == "horn", 6.0)
	var engaged := false
	for row: Array in music.calls.slice(calls_before):
		engaged = engaged or row[1] == "freight.engage"
	_check(horned and engaged, "the Shunter's HORN fires engage")
	# Out of its way while the music answers: back in the booth.
	await _place(bay.to_global(Vector3(7.0, FreightBay.BOOTH_FLOOR + 0.1, 12.6)))
	var entry := await _await_live("Entry", func() -> bool:
			return String(freight.get_state_name()) == "Entry", 5.0)
	_check(entry and _stung("entry"),
			"Entry, on the next two-bar line, plays the entry stinger once")
	var combat := await _await_live("Combat", func() -> bool:
			return String(freight.get_state_name()) == "Combat", 8.0)
	_check(combat, "Entry turns to Combat on its own")
	_check(music.stinger.bus == &"Music" and sh._horn.bus == &"SFX",
			"the stinger is on Music, the horn on SFX: no ducking either way")

	# -- DOWN: victory -> Victory (+ stinger) -> Exploration ------------------
	# Frontal armour takes 75 % while it closes, braces or rushes, so the
	# kill is hits until it is down, a frame apart (each frame is one hit).
	for _i in 12:
		if sh._dead:
			break
		sh.take_damage(Shunter.HP + 1.0, Vector3.FORWARD, 0.0)
		await get_tree().physics_frame
	_check(sh._dead and sh.state == "down", "the Shunter goes DOWN")
	var victory := await _await_live("Victory", func() -> bool:
			return String(freight.get_state_name()) == "Victory", 5.0)
	_check(victory and _stung("victory"),
			"the Shunter DOWN fires victory; Victory plays the victory stinger")
	var calm := await _await_live("Exploration again", func() -> bool:
			return String(freight.get_state_name()) == "Exploration", 30.0)
	_check(calm, "Victory goes back to Exploration on its own")

	# -- RESTART ----------------------------------------------------------------
	calls_before = music.calls.size()
	bay.restart()
	await _settle(10)
	_check(_called_since(calls_before, "freight.restart") and fp.playing
			and String(freight.get_state_name()) == "Exploration",
			"RESTART: stop, play -- Exploration again")
	# The new Shunter is the one whose horn counts.
	sh = bay.shunter
	calls_before = music.calls.size()
	await _arena_pose(FreightBay.DOCK, PI, Vector3(6.0, 0.0, -4.0))
	await _await_live("the new Shunter's horn", func() -> bool:
			return sh.state == "horn", 6.0)
	_check(_called_since(calls_before, "freight.engage"),
			"after RESTART, the new Shunter's horn fires engage")

	# -- a death in the bay -----------------------------------------------------
	calls_before = music.calls.size()
	var p := hub_now.player
	p.take_damage(p.hp + 1000.0, Vector3.INF, false)
	await _await_live("the restart on death", func() -> bool:
			return _called_since(calls_before, "freight.restart"), 3.0)
	_check(_called_since(calls_before, "freight.restart"),
			"a death in the bay restarts the Freight Bay music")
	await _await_live("the respawn", func() -> bool: return not p._dead, 8.0)
	await _settle(10)
	_check(music.where == "station" and sp.playing and not fp.playing,
			"respawned in the station: station music again (%s)" % music.where)

	# -- in and out on foot ----------------------------------------------------
	await _place(bay.to_global(Vector3(7.0, FreightBay.BOOTH_FLOOR + 0.1, 13.6)))
	await _settle(10)
	await _place(Vector3(0, 0.1, 3.0))
	await _settle(10)
	_check(music.where == "station" and sp.playing and not fp.playing
			and String(station.get_state_name()) == "Explore",
			"out of the Freight Bay: Freight Bay stops, the station plays, "
			+ "still Explore")

	# -- a Crossing: silence ----------------------------------------------------
	var forge := await _open_forge(hub_now, 1)
	if forge == null:
		return
	forge.request_draft()
	if not await _drafted():
		return
	var zid := str(BridgeClient.active_zone().get("zone_id", ""))
	forge.accept_draft()
	var crossing := await _entered(zid)
	if crossing == null:
		return
	await _settle(10)
	_check(music.where == "" and not sp.playing and not fp.playing,
			"in a Crossing: no music (none is approved there)")
	_check(String(station.get_state_name()) == "Explore",
			"the station cue never left Explore")
	_note("music calls: %s" % ", ".join(music.calls.map(
			func(r: Array) -> String: return String(r[1]))))
	_note("stingers: %s" % ", ".join(music.stingers.map(
			func(r: Array) -> String: return String(r[1]))))
	_state["music"] = _results


func _stung(kind: String) -> bool:
	var n := 0
	for row: Array in music.stingers:
		if row[1] == kind:
			n += 1
	return n >= 1 and music.stinger.playing


func _called_since(from: int, what: String) -> bool:
	for row: Array in music.calls.slice(from):
		if row[1] == what:
			return true
	return false
