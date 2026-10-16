class_name ShunterCheck
extends "res://tests/unified_check.gd"
## D-20 rev 2 §8.A, THE SHUNTER'S SCRIPTED CHECKS, in the Freight Bay annex
## of the real Hub (`--unified-live=shunter`). Truth, not fun: the owner's
## playtest is the real acceptance.
##
## **HARNESS STEPS, declared:** the player is PLACED (in the booth, on the
## bay floor, in a lane) -- the walk there is the annex's corridor, checked
## once on foot; dodges are the player's own move/jump inputs, timed from
## the Shunter's state; a hit whose REACTION is under test is delivered
## through `take_damage`, the same call every weapon's hit makes, with the
## weapon's real numbers -- and the weapons themselves are fired live where
## the weapon is the point (a Foundry shot, a Sightline shot, a capped
## Mass Driver release).

var bay: FreightBay
var sh: Shunter
var hub_now: HubController


func _run() -> void:
	await get_tree().process_frame
	BridgeClient.error_received.connect(func(err: Dictionary) -> void:
		_errors.append(err))
	_load_state()
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		match phase_from_cmdline():
			"shunter":
				await _phase_shunter()
			_:
				await super._run()
				return
	_save_state()
	_finish()


func _phase_shunter() -> void:
	if not await _await_live("the campaign",
			func() -> bool: return BridgeClient.hub_mode() != "NO_CAMPAIGN",
			30.0):
		return
	hub_now = await _the_hub()
	if hub_now == null:
		return
	bay = hub_now.freight_bay
	_check(bay != null, "the Freight Bay annex is built off Station 1")
	if bay == null:
		return
	sh = bay.shunter
	var intents_before := BridgeClient.sent_intents.size()
	await _looks()
	await _pre_contact()
	_note("events: %s" % str(_summary()))


## A1: from the booth, at least two tend beats and one dock, no notice.
func _pre_contact() -> void:
	_place(bay.to_global(Vector3(7.0, FreightBay.BOOTH_FLOOR + 0.1, 12.6)))
	var tends := 0
	var docks := 0
	var horns := 0
	var seen_state := ""
	for _i in 60 * 45:
		await get_tree().physics_frame
		if sh.state != seen_state:
			seen_state = sh.state
			if seen_state == "dock":
				docks += 1
			if seen_state == "horn":
				horns += 1
		if sh._tend > 0.0 and sh._tend >= FreightBay.STACK.x and false:
			pass
		if docks >= 1 and _count("tend") >= 2:
			break
	tends = _count("tend")
	_check(tends >= 2 and docks >= 1 and horns == 0,
			"A1: from the booth, %d tend beats and %d dock(s), no notice"
			% [tends, docks])


func _count(kind: String) -> int:
	var n := 0
	for row: Dictionary in sh.events_log:
		if String(row.get("event", "")) == kind:
			n += 1
	return n


func _summary() -> Dictionary:
	var out := {}
	for row: Dictionary in sh.events_log:
		var k := String(row.get("event", ""))
		out[k] = int(out.get(k, 0)) + 1
	return out


func _place(at: Vector3) -> void:
	var p := hub_now.player
	p.global_position = at
	p.velocity = Vector3.ZERO
	await _settle(4)


const SHOTS_FLAG := "--unified-shots="


## Optional stills (`--unified-shots=DIR`, under a real renderer): the
## corridor, the booth's view, the bay floor and the gate.
func _looks() -> void:
	var dir := _arg(SHOTS_FLAG)
	if dir == "":
		return
	var p := hub_now.player
	var views := [
		["01_station_door", Vector3(0, 0.0, 2.5), Vector3(0, 1.6, -3)],
		["02_corridor", Vector3(0, 0.0, -0.5), Vector3(0, 2.0, -6)],
		["03_booth_view", bay.to_global(Vector3(7, 1.6, 12.8)),
				bay.to_global(Vector3(2, 0.5, -8))],
		["04_bay_from_door", bay.to_global(Vector3(-1.5, 0.0, 12.5)),
				bay.to_global(Vector3(0, 1.5, -6))],
		["05_gate_and_dock", bay.to_global(Vector3(-4, 0.0, 6)),
				bay.to_global(Vector3(3, 1.0, -12))],
		["06_booth_from_bay", bay.to_global(Vector3(3, 0.0, 3)),
				bay.to_global(Vector3(6, 2.0, 12.5))],
		["07_booth_back", bay.to_global(Vector3(7, 1.6, 11.6)),
				bay.to_global(Vector3(7, 2.5, 16))],
		["08_booth_west", bay.to_global(Vector3(8.5, 1.6, 12.5)),
				bay.to_global(Vector3(0, 1.5, 13))],
	]
	for v: Array in views:
		p.global_position = v[1]
		p.velocity = Vector3.ZERO
		for _i in 20:
			_look_at(p, v[2])
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				dir.path_join(String(v[0]) + ".png"))
