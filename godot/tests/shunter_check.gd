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
## the weapon is the point (a Foundry shot, a Sightline shot, a full Mass
## Driver release).

var bay: FreightBay
var sh: Shunter
var hub_now: HubController
## Measured numbers, written to the notes file for the report.
var _results := {}


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
	await _walk_in()
	await _pre_contact()
	await _hearing_from_booth()
	await _horn_lane_and_hit()
	await _sidestep()
	await _jumps()
	await _crate_and_pillar()
	await _heavy_hits()
	await _driver_full()
	await _gate_checks()
	await _down_and_restart()
	await _way_out()
	await _doorway_rush()
	await _sounds()
	var sent: Array = BridgeClient.sent_intents.slice(intents_before)
	_check(sent.is_empty(),
			"A11: the Freight Bay sent nothing to the bridge (%d intents)"
			% sent.size())
	_state["shunter"] = _results


## U4: on foot, with the movement keys, from Station 1's front door up the
## corridor into the booth and down the ramp onto the floor. The annex
## announces itself (the music hook) and the booth door shuts behind.
func _walk_in() -> void:
	var p := hub_now.player
	var entered := [0]
	var on_entered := func() -> void: entered[0] += 1
	bay.annex_entered.connect(on_entered)
	await _place(Vector3(0, 0.1, 2.0))
	await _settle(6)
	_look_at(p, Vector3(0, 1.5, -20.0))
	Input.action_press("move_forward")
	var in_booth := await _await_live("the booth, on foot", func() -> bool:
			var at := bay.to_local(p.global_position)
			_look_at(p, bay.to_global(Vector3(7.0, 1.5 + 1.5, 11.5)))
			return at.y > FreightBay.BOOTH_FLOOR - 0.2 and at.z < 13.6, 8.0)
	_check(in_booth and entered[0] == 1 and bay.in_annex,
			"U4: on foot from Station 1 up the corridor into the booth "
			+ "(annex entered %d time(s))" % entered[0])
	var down := await _await_live("the bay floor, on foot", func() -> bool:
			_look_at(p, bay.to_global(Vector3(-3.0, 1.6, 13.0)))
			return bay.on_bay_floor, 8.0)
	Input.action_release("move_forward")
	await _settle(30)
	_check(down and bay.booth_door.goal < 0.5,
			"U4: down the ramp onto the bay floor; the booth door shuts behind")
	bay.annex_entered.disconnect(on_entered)


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
	# The weapons and the Shunter: Arty's Foundry in the station, the
	# Shunter braced with its lane lit, Arty's Driver in the bay.
	main.armory.select("foundry")
	p.global_position = Vector3(1.0, 0.0, 6.0)
	for _i in 40:
		_look_at(p, Vector3(1.0, 1.4, 14.0))
		await get_tree().physics_frame
	await _still(dir, "09_station_foundry")
	main.armory.select("switchback")
	await _arena_pose(FreightBay.DOCK, PI, Vector3(7.5, 0.0, -3.0))
	if await _await_live("the brace, for the still",
			func() -> bool: return sh.state == "brace", 8.0):
		p.global_position = bay.to_global(Vector3(10.5 - 1.2, 0.0, -2.0))
		_look_at(p, sh.global_position + Vector3(0, 0.8, 0))
		await _still(dir, "10_shunter_brace")
	await _reset()
	main.armory.select("driver")
	p.global_position = bay.to_global(Vector3(-2.0, 0.0, 6.0))
	for _i in 30:
		_look_at(p, sh.global_position + Vector3(0, 1.0, 0))
		await get_tree().physics_frame
	await _still(dir, "11_bay_driver")
	main.armory.select("")
	await _reset()


func _still(dir: String, still_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			dir.path_join(still_name + ".png"))


# ============================================================ scenarios

## A1 (second half): a Mass Driver charging in the booth (23 m) is not heard.
func _hearing_from_booth() -> void:
	await _reset()
	_place(bay.to_global(Vector3(7.0, FreightBay.BOOTH_FLOOR + 0.1, 12.6)))
	main.armory.select("driver")
	_look_at(hub_now.player, sh.global_position)
	Input.action_press("fire_pulse")
	await _settle(80)
	Input.action_release("fire_pulse")
	await _settle(30)
	_check(not sh.state in ["horn", "close", "brace", "rush"],
			"A1: a Mass Driver charging in the booth (%.0f m) goes unheard"
			% hub_now.player.global_position.distance_to(sh.global_position))
	_note("A1: hearing (18 m) and the notice radius (18 m) are the same "
			+ "distance, so inside 18 m it has already noticed by distance; "
			+ "the hearing rule only adds the hit-free trigger D-20 names "
			+ "(flagged for Dess)")
	main.armory.select("")


## A2-A5: notice -> horn 0.6 s, full damage in the horn, CLOSE; the lane
## at the wind-up's start, followed within 0.1 m; standing in it: 14 and a
## shove; the hit window 0.7 s.
func _horn_lane_and_hit() -> void:
	await _reset()
	await _arena_pose(Vector3(7.5, 0, -12.2), 0.0, Vector3(7.5, 0, -1.0))
	var p := hub_now.player
	if not await _await_live("the horn",
			func() -> bool: return sh.state == "horn", 5.0):
		return
	var hp0 := sh.hp
	sh.take_damage(6.0, (sh.global_position - p.global_position).normalized(),
			0.0)
	_check(is_equal_approx(hp0 - sh.hp, 6.0),
			"A2: in the horn the plough is up: full damage (%.2f of 6)"
			% (hp0 - sh.hp))
	var horn := await _time_in("horn")
	_check(absf(horn - Shunter.HORN_SECONDS) <= 2.0 * DT,
			"A2: the horn lasts %.3f s (0.6)" % horn)
	_results["horn_s"] = horn
	if not await _await_live("the brace",
			func() -> bool: return sh.state == "brace", 6.0):
		return
	var dir := sh._brace_dir
	var lane_dir := -sh._lane.global_transform.basis.z
	_check(sh._lane.visible and Vector2(lane_dir.x, lane_dir.z).normalized()
			.dot(Vector2(dir.x, dir.z).normalized()) > 0.999,
			"A3: the lane appears at the wind-up's start, along the locked "
			+ "direction")
	var start := sh.global_position
	var hp_player := p.hp
	var worst := 0.0
	while sh.state == "brace" or sh.state == "rush":
		await get_tree().physics_frame
		var rel := sh.global_position - start
		var off := Vector2(rel.x - dir.x * (rel.x * dir.x + rel.z * dir.z),
				rel.z - dir.z * (rel.x * dir.x + rel.z * dir.z)).length()
		worst = maxf(worst, off)
	var travelled := Vector2(sh.global_position.x - start.x,
			sh.global_position.z - start.z).length()
	_note("rush: from %v to %v (%.2f m), player at %v, dir %v, kind %s"
			% [start, sh.global_position, travelled, p.global_position, dir,
			sh._recover_kind])
	_check(worst <= 0.1 and travelled > 1.0,
			"A3: the rush follows its lane (worst %.3f m over %.1f m)"
			% [worst, travelled])
	_check(is_equal_approx(hp_player - p.hp, Shunter.RUSH_DAMAGE),
			"A4: standing in the lane: hit for %.0f (14)" % (hp_player - p.hp))
	var shove := Vector2(p.velocity.x, p.velocity.z)
	_check(sh._recover_kind == "hit" and shove.length() > 3.0,
			"A4: and shoved along the rush (%.1f m/s)" % shove.length())
	var window := await _time_in("recover")
	_check(absf(window - 0.7) <= 2.0 * DT,
			"A5: the hit window is %.3f s (0.7)" % window)
	_results["window_hit"] = window


## A4: a 1.1 m sidestep started 0.3 s into the wind-up: 0 damage; the miss
## window 1.1 s.
func _sidestep() -> void:
	await _reset()
	await _arena_pose(Vector3(7.5, 0, -12.2), 0.0, Vector3(7.5, 0, -1.0))
	var p := hub_now.player
	if not await _await_live("the brace",
			func() -> bool: return sh.state == "brace", 8.0):
		return
	while sh.state_time < 0.3:
		await get_tree().physics_frame
	var hp0 := p.hp
	var moved := await _sidestep_now(1.1)
	await _await_live("the rush ends",
			func() -> bool: return sh.state == "recover", 3.0)
	_check(is_equal_approx(p.hp, hp0) and sh._recover_kind == "miss",
			"A4: a %.2f m sidestep 0.3 s into the wind-up: %.0f damage, a miss"
			% [moved, hp0 - p.hp])
	var window := await _time_in("recover")
	_check(absf(window - 1.1) <= 2.0 * DT,
			"A5: the open-floor window is %.3f s (1.1)" % window)
	_results["window_miss"] = window


## A4: take off 0.23 s before plough contact: 0 damage, lands behind;
## take off 0.10 s before: hit.
func _jumps() -> void:
	for lead: float in [0.23, 0.10]:
		await _reset()
		await _arena_pose(Vector3(7.5, 0, -12.2), 0.0, Vector3(7.5, 0, -1.0))
		var p := hub_now.player
		if not await _await_live("the rush",
				func() -> bool: return sh.state == "rush", 8.0):
			return
		var dir := sh._brace_dir
		var rel := p.global_position - sh.global_position
		var along := rel.x * dir.x + rel.z * dir.z
		var contact := (along - Shunter.HIT_ALONG) / Shunter.RUSH_SPEED \
				- sh.state_time
		var hp0 := p.hp
		var wait := contact - lead
		while wait > 0.0:
			await get_tree().physics_frame
			wait -= DT
		Input.action_press("jump")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("jump")
		await _await_live("the rush ends",
				func() -> bool: return sh.state != "rush", 3.0)
		await _settle(40)
		var behind := (p.global_position - sh.global_position).dot(dir) < 0.0
		if lead > 0.2:
			_check(is_equal_approx(p.hp, hp0) and behind,
					"A4: a jump %.2f s before contact clears it and lands behind"
					% lead + " (%.0f damage)" % (hp0 - p.hp))
		else:
			_check(p.hp < hp0,
					"A4: a jump %.2f s before contact is hit (%.0f damage)"
					% [lead, hp0 - p.hp])


## A5: a crate stops it 1.1 s and bursts; a pillar crumples it 1.8 s; the
## plume fades in the last 0.2 s; a heavy hit in the window adds nothing.
func _crate_and_pillar() -> void:
	# The crate C1 at (-7, 3): bait in front of it, sidestep.
	await _reset()
	var crate := bay.crates[0]
	await _arena_pose(Vector3(-7, 0, -8), 0.0, Vector3(-7, 0, 1.6))
	if await _await_live("the brace",
			func() -> bool: return sh.state == "brace", 8.0):
		while sh.state_time < 0.3:
			await get_tree().physics_frame
		await _sidestep_now(1.4)
		await _await_live("the rush ends",
				func() -> bool: return sh.state == "recover", 3.0)
		var window := await _time_in("recover")
		_check(sh._recover_kind == "crate" and not is_instance_valid(crate),
				"A5: into the crate: it bursts (kind %s)" % sh._recover_kind)
		_check(absf(window - 1.1) <= 2.0 * DT,
				"A5: the crate window is %.3f s (1.1)" % window)
		_results["window_crate"] = window
	# The pillar P1 at (-5, -3): bait in front of it, sidestep.
	await _reset()
	await _arena_pose(Vector3(-5, 0, -12), 0.0, Vector3(-5, 0, -4.6))
	if not await _await_live("the brace",
			func() -> bool: return sh.state == "brace", 8.0):
		return
	while sh.state_time < 0.3:
		await get_tree().physics_frame
	await _sidestep_now(1.4)
	if not await _await_live("the rush ends",
			func() -> bool: return sh.state == "recover", 3.0):
		return
	_check(sh._recover_kind == "steel",
			"A5: into the pillar: steel (kind %s)" % sh._recover_kind)
	var length := sh._recover_length
	var alpha := {}
	var hit_at := length - 0.9
	var frames := 0
	while sh.state == "recover":
		var t := sh.state_time
		if absf(t - (length - 0.35)) < DT / 2.0:
			alpha["early"] = sh._plume_mat.albedo_color.a
		if absf(t - (length - 0.1)) < DT / 2.0:
			alpha["late"] = sh._plume_mat.albedo_color.a
		if absf(t - hit_at) < DT / 2.0:
			sh.take_damage(15.0, -(-sh.global_transform.basis.z), 0.0)
		frames += 1
		await get_tree().physics_frame
	var window := frames * DT
	_check(absf(window - 1.8) <= 2.0 * DT,
			"A5: the steel window is %.3f s (1.8), a heavy hit in it changed "
			% window + "nothing")
	_results["window_steel"] = window
	_check(float(alpha.get("early", 0.0)) > 0.5
			and float(alpha.get("late", 1.0)) < float(alpha.get("early", 0.0))
			and float(alpha.get("late", 1.0)) > 0.0,
			"A5: the plume fades in the last 0.2 s (%.2f -> %.2f)"
			% [float(alpha.get("early", -1)), float(alpha.get("late", -1))])


## A6: Foundry (live) breaks a brace, once per cycle; the locked re-brace
## sparks only; a heavy hit in RUSH changes nothing; Sightline (live)
## never breaks it; Bulkhead's pellets of one pull summed: 3 break, 2 not.
## Armour applies to damage, not to the reaction.
func _heavy_hits() -> void:
	var p := hub_now.player
	await _reset()
	await _arena_pose(Vector3(7.5, 0, -12.2), 0.0, Vector3(7.5, 0, -0.5))
	main.armory.select("foundry")
	await _settle(50)
	if not await _await_live("the brace",
			func() -> bool: return sh.state == "brace", 8.0):
		return
	var hp0 := sh.hp
	await _fire_at_shunter()
	await _settle(2)
	_check(sh.state == "reaim" and sh._brace_broken_this_cycle,
			"A6: a live Foundry shot (15, heavy) breaks the brace")
	_check(absf((hp0 - sh.hp) - 15.0 * Shunter.ARMOUR_TAKEN) < 0.01,
			"A6: armour took the damage (%.2f of 15), not the reaction"
			% (hp0 - sh.hp))
	_check(absf(sh.state_time) < 0.1 and Shunter.REAIM_SECONDS == 0.6,
			"A6: the broken brace re-aims for 0.6 s, plough up")
	# The next brace this cycle is locked.
	if await _await_live("the second brace",
			func() -> bool: return sh.state == "brace", 8.0):
		sh.take_damage(15.0, (sh.global_position - p.global_position)
				.normalized(), 0.0)
		await _settle(2)
		_check(sh.state == "brace", "A6: the locked re-brace sparks only")
		if await _await_live("the rush",
				func() -> bool: return sh.state == "rush", 2.0):
			sh.take_damage(45.0 * 0.0 + 15.0, (sh.global_position
					- p.global_position).normalized(), 0.0)
			await _settle(2)
			_check(sh.state == "rush", "A6: a heavy hit in the rush changes "
					+ "nothing")
	main.armory.select("")
	# A new cycle: Sightline (live, 12) never breaks it.
	await _reset()
	await _arena_pose(Vector3(7.5, 0, -12.2), 0.0, Vector3(7.5, 0, -0.5))
	main.armory.select("sightline")
	await _settle(40)
	if await _await_live("the brace",
			func() -> bool: return sh.state == "brace", 8.0):
		await _fire_at_shunter()
		await _settle(2)
		_check(sh.state in ["brace", "rush"],
				"A6: a live Sightline shot (12) never breaks it (owner: "
				+ "threshold above 12)")
	main.armory.select("")
	# Bulkhead: one pull's pellets summed for the reaction.
	for pellets: int in [2, 3]:
		await _reset()
		await _arena_pose(Vector3(7.5, 0, -12.2), 0.0, Vector3(7.5, 0, -0.5))
		if not await _await_live("the brace",
				func() -> bool: return sh.state == "brace", 8.0):
			return
		var from := (sh.global_position - p.global_position).normalized()
		for _i in pellets:
			sh.take_damage(6.0, from, 0.0)
		await _settle(2)
		var broken := sh.state == "reaim"
		_check(broken == (pellets >= 3),
				"A6: %d Breacher pellets in one pull (%d): %s" % [pellets,
				pellets * 6, "breaks the brace" if broken else "no break"])
	_results["heavy_at"] = Shunter.HEAVY_AT


## No per-target cap (owner, 2026-10-17; D-20 §13.5): a full Mass Driver
## release does its 60 here as anywhere, and that one perfect shot downs a
## 40 HP Shunter. Then a Foundry-sized heavy hit (15, at the plough's
## rating of 14) while it works delays the horn to 0.9 s.
func _driver_full() -> void:
	await _reset()
	var p := hub_now.player
	await _arena_pose(Vector3(6, 0, -12.2), 0.0, Vector3(6, 0, 8.5))
	await _settle(10)
	_check(sh.state in ["work", "dock"], "the Shunter is still at work, 20 m off")
	main.armory.select("driver")
	await _settle(30)
	_look_at(p, sh.global_position + Vector3(0, 0.6, 0))
	Input.action_press("fire_pulse")
	for _i in 80:
		_look_at(p, sh.global_position + Vector3(0, 0.6, 0))
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	await _await_live("the slug lands", func() -> bool: return sh._dead, 3.0)
	var raw := 0.0
	for row: Dictionary in sh.events_log:
		if row.get("event", "") == "hit":
			raw = maxf(raw, float(row.get("raw", 0.0)))
	_check(sh._dead and raw >= 59.9,
			"no cap: a full Mass Driver release lands its %.1f and downs it" % raw)
	_results["driver_raw"] = raw
	main.armory.select("")
	await _reset()
	await _arena_pose(Vector3(6, 0, -12.2), 0.0, Vector3(6, 0, 8.5))
	await _settle(10)
	sh.take_damage(15.0, (sh.global_position - p.global_position).normalized(),
			0.0)
	var horn := await _time_in("horn")
	_check(absf(horn - (Shunter.HORN_SECONDS + Shunter.HORN_HEAVY_EXTRA))
			<= 2.0 * DT,
			"A2: a heavy hit (15) while it works delays the horn: %.3f s (0.9)"
			% horn)
	_check(Shunter.HEAVY_AT > 12.0 and Shunter.HEAVY_AT <= 15.0,
			"the plough's rating (%.0f): Sightline's 12 refused, Foundry's 15 "
			% Shunter.HEAVY_AT + "accepted (D-20 §13.3)")


## A7: the gate closes in about 1.6 s (recorded), never on somebody,
## stops a rush (1.8 s), reopens after 6 s; the Shunter walks round it.
func _gate_checks() -> void:
	var p := hub_now.player
	await _reset()
	# Never on somebody: stand in the opening, pull.
	_place(bay.to_global(FreightBay.GATE_AT + Vector3(0, 0, 0)))
	bay._on_gate_lever(bay.gate_levers[0])
	await _settle(150)
	_check(bay.gate.offset > 0.5,
			"A7: with the player in the opening it does not come down "
			+ "(offset %.2f)" % bay.gate.offset)
	_place(bay.to_global(FreightBay.GATE_AT + Vector3(0, 0, 4.0)))
	var closed_after := await _await_live("the gate closes once clear",
			func() -> bool: return bay.gate.is_shut(), 8.0)
	_check(closed_after, "A7: once the opening is clear it closes (refused "
			+ "%d time(s) while occupied)" % bay.gate.refusals())
	# A clean close, timed from the pull.
	await _reset()
	_place(bay.to_global(Vector3(0, 0, 8.0)))
	var refused := bay.gate.refusals()
	var logged := bay.gate_log.size()
	bay._on_gate_lever(bay.gate_levers[0])
	var trace: Array = []
	for _i in 60 * 8:
		await get_tree().physics_frame
		if _i % 30 == 0:
			trace.append("%.2f/%s/%s" % [bay.gate.offset,
					str(bay.gate.doorway_occupied()), str(bay.gate.goal)])
		if bay.gate_log.size() > logged:
			break
	_note("gate trace (offset/occupied/goal every 0.5 s): %s; refusals %d -> %d"
			% [", ".join(trace), refused, bay.gate.refusals()])
	var took := float(bay.gate_log.back().get("closed_in", -1.0)) \
			if not bay.gate_log.is_empty() else -1.0
	_check(took > 0.0, "A7: the gate closes in %.2f s (D-20 A2 assumed 1.6)"
			% took)
	_results["gate_close_s"] = took
	# The Shunter walks round it: player south, Shunter north.
	sh.global_position = bay.to_global(Vector3(0, 0, -6.0))
	sh.rotation.y = PI
	sh._enter("work")
	_place(bay.to_global(Vector3(0, 0, 8.0)))
	var rounded := false
	var walk: Array[String] = []
	for i in 60 * 5:
		await get_tree().physics_frame
		if i % 30 == 0:
			var at := bay.to_local(sh.global_position)
			walk.append("%s(%.1f,%.1f)%s" % [sh.state, at.x, at.z,
					"g" if bay.gate.is_open() else "G"])
		if sh.state in ["brace", "rush"] or bay.to_local(sh.global_position).z > 1.5:
			rounded = true
			break
	_note("walk round: %s" % " ".join(walk))
	_check(rounded, "A7: it walks round the closed gate")
	_check(sh.grind_max <= 2.0,
			"A10: no grinding against the gate (longest %.2f s)" % sh.grind_max)
	_results["grind_max"] = sh.grind_max
	# Reopens after 6 s.
	await _await_live("the gate reopens", func() -> bool:
			return bay.gate.is_open(), 12.0)
	_check(bay.gate.is_open(), "A7: it reopens on its own after 6 s "
			+ "(offset %.2f of %.2f, goal %.2f, reopen in %.2f, occupied %s)"
			% [bay.gate.offset, bay.gate.travel, bay.gate.goal, bay._gate_reopen,
			str(bay.gate.doorway_occupied())])
	# It stops a rush: closed, the player in front of the steel, sidestep.
	await _reset()
	var before := bay.gate_log.size()
	bay._on_gate_lever(bay.gate_levers[0])
	await _await_live("the gate closes", func() -> bool:
			return bay.gate_log.size() > before, 6.0)
	await _arena_pose(Vector3(0, 0, -9.0), 0.0, Vector3(0, 0, -0.4))
	if await _await_live("the brace",
			func() -> bool: return sh.state == "brace", 6.0):
		while sh.state_time < 0.3:
			await get_tree().physics_frame
		await _sidestep_now(1.6)
		await _await_live("the rush ends",
				func() -> bool: return sh.state == "recover", 3.0)
		_check(sh._recover_kind == "steel",
				"A7: the closed gate stops a rush: steel (%s), the 1.8 s window"
				% sh._recover_kind)


## Down: power-down, the booth door reopens; RESTART restores everything.
func _down_and_restart() -> void:
	await _reset()
	await _arena_pose(Vector3(6, 0, -12.2), 0.0, Vector3(6, 0, 8.5))
	var shut := await _await_live("the booth door shuts behind",
			func() -> bool: return bay.booth_door.is_shut(), 5.0)
	_check(shut and bay.on_bay_floor,
			"A10: on the bay floor the booth door shuts behind the player")
	var downs := [0]
	sh.powered_down.connect(func() -> void: downs[0] += 1)
	sh.take_damage(Shunter.HP + 1.0, Vector3.FORWARD, 0.0)
	await _settle(90)
	_check(downs[0] == 1 and sh.state == "down" and sh._dead,
			"down: it powers down once")
	_check(bay.booth_door.is_open() or bay.booth_door.offset > 1.0,
			"A10: a kill reopens the booth door")
	var f: Dictionary = sh.fight_summary
	_check(f.has("time_to_kill") and f.has("rushes")
			and not (f.get("weapons", {}) as Dictionary).is_empty()
			and bay.fight_board.text.begins_with("LAST FIGHT: down in"),
			"telemetry: time to kill, rushes and per-weapon damage on the "
			+ "booth's board (%s)" % JSON.stringify(f))
	# Spend a crate and close the gate, then RESTART.
	bay.crates[1].take_damage(100.0)
	bay._on_gate_lever(bay.gate_levers[0])
	await _settle(30)
	bay.restart()
	await _settle(40)
	sh = bay.shunter
	_check(sh.state in ["work", "dock"] and not sh._dead and sh.hp == Shunter.HP
			and bay.to_local(sh.global_position).distance_to(FreightBay.DOCK) < 0.6
			and bay.crates.size() == 2 and bay.gate.is_open()
			and bay.booth_door.goal < 0.5 and bay.on_bay_floor,
			"A10: RESTART: Shunter at the dock at 40 HP, crates whole, gate "
			+ "open; the booth door shut behind the player still on the floor")


## D-20 §13.1: the annex always has a way out. From the floor the LEAVE
## lever opens the booth door while the Shunter is away from it; with the
## Shunter at the door the door is shut and the lever refuses, wherever
## the player is -- its 0.9 m body would fit the doorway.
func _way_out() -> void:
	await _reset()
	await _arena_pose(FreightBay.DOCK, 0.0, Vector3(-2.0, 0.0, 12.0))
	await _settle(40)
	_check(bay.on_bay_floor and bay.booth_door.goal < 0.5,
			"way out: on the floor, the booth door is shut behind you")
	bay.exit_lever.pulled.emit(bay.exit_lever)
	var opened := await _await_live("the way out opens", func() -> bool:
			return bay.booth_door.is_open(), 4.0)
	_check(opened, "way out: LEAVE THE BAY opens the booth door "
			+ "(the Shunter %.0f m from it)" % bay.to_local(
			sh.global_position).distance_to(FreightBay.BOOTH_DOOR_AT))
	await _place(bay.to_global(Vector3(7.0, FreightBay.BOOTH_FLOOR + 0.1, 12.6)))
	await _settle(20)
	_check(not bay.on_bay_floor and bay.booth_door.goal > 0.5,
			"way out: up the ramp into the booth, the door stays open")
	# The Shunter at the door: shut, whether you are in the booth or not.
	sh.global_position = bay.to_global(Vector3(-3.0, 0.0, 10.0))
	sh.velocity = Vector3.ZERO
	var shut := await _await_live("the door shuts on the Shunter's approach",
			func() -> bool: return bay.booth_door.is_shut(), 5.0)
	_check(shut, "way out: with the Shunter at the door it shuts, even with "
			+ "you in the booth (it would fit the doorway)")
	await _place(bay.to_global(Vector3(-1.5, 0.0, 12.6)))
	sh.global_position = bay.to_global(Vector3(-3.0, 0.0, 9.5))
	await _settle(4)
	bay.exit_lever.pulled.emit(bay.exit_lever)
	await _settle(20)
	_check(bay.exit_lever.locked and bay.booth_door.goal < 0.5
			and bay.shunter_at_door(),
			"way out: the lever refuses while the Shunter is at the door")
	await _reset()


## Dess's pre-playtest check (f320b47b): the booth doorway must stop the
## Shunter PHYSICALLY. A rush covers the door's 5 m interlock in about
## 0.4 s and the door takes about 1.5 s to shut, so a timing rule cannot.
## Two scripted rushes at it, with the player just inside the channel and
## the door open: one from the floor in line with the door, and one braced
## from the doorway's own mouth, aimed straight at the door. Neither may
## carry it past the door's plane.
func _doorway_rush() -> void:
	var p := hub_now.player
	for start: Array in [[Vector3(-9.0, 0.0, 13.4), "from the floor, in line"],
			[Vector3(-0.6, 0.0, 10.6), "from the doorway's mouth"]]:
		await _reset()
		var inside := bay.to_global(Vector3(1.0, 0.5, 13.4))
		p.global_position = inside
		p.velocity = Vector3.ZERO
		await _settle(30)
		sh.global_position = bay.to_global(start[0])
		sh.velocity = Vector3.ZERO
		var door := bay.to_global(FreightBay.BOOTH_DOOR_AT + Vector3(0, 0, 0.4))
		var to := door - sh.global_position
		to.y = 0.0
		sh.rotation.y = atan2(-to.x, -to.z)
		# Straight into the brace, aimed at the door (the harness step:
		# whatever the encounter would decide, this is the worst case).
		sh._has_noticed = true
		sh._enter("brace")
		sh._brace_dir = to.normalized()
		sh.rotation.y = atan2(-to.x, -to.z)
		var furthest := -INF
		var corner := -INF
		var hp0 := p.hp
		# The rush, its recovery, and the walk at the door after it.
		for _i in 60 * 8:
			await get_tree().physics_frame
			p.global_position = inside
			furthest = maxf(furthest, bay.to_local(sh.global_position).x)
			corner = maxf(corner, _footprint_max_x())
		# Through the doorway means its middle reaches the door (a corner
		# jammed in the frame is not through) or its rush reaches the
		# player standing a metre inside.
		_check(furthest < -0.2 and p.hp == hp0,
				"doorway: a rush %s cannot get through the booth door "
				% start[1] + "(centre x %.2f, furthest corner %.2f, player "
				% [furthest, corner] + "%d -> %d HP)" % [hp0, p.hp])
	await _reset()


## The furthest the Shunter's body reaches toward the booth (bay x): the
## corners of its collider's footprint, not its centre.
func _footprint_max_x() -> float:
	var size: Vector3 = sh.envelope["size"]
	var most := -INF
	for cx: float in [-0.5, 0.5]:
		for cz: float in [-0.5, 0.5]:
			var corner := sh.global_transform * Vector3(cx * size.x, 0.0,
					cz * size.z)
			most = maxf(most, bay.to_local(corner).x)
	return most


## Condi's Shunter set (PR #45): the seven candidates and the approved horn
## load from her events.json, and the states play them.
func _sounds() -> void:
	var lib := Shunter._sfx_library()
	_check(lib.size() == 8, "Condi's Shunter set: %d of 8 events load" % lib.size())
	await _reset()
	await _arena_pose(Vector3(7.5, 0, -12.2), 0.0, Vector3(7.5, 0, -0.5))
	var heard := {}
	for _i in 60 * 8:
		await get_tree().physics_frame
		for event: String in sh._sfx:
			if (sh._sfx[event] as AudioStreamPlayer3D).playing:
				heard[event] = true
		if heard.has("shunter.plume_hiss"):
			break
	_check(heard.has("shunter.plough_scrape") and heard.has("shunter.rush")
			and heard.has("shunter.plume_hiss"),
			"brace, rush and recovery play her scrape, rush and plume hiss (%s)"
			% ", ".join(heard.keys()))
	var bus_ok := true
	for event: String in sh._sfx:
		bus_ok = bus_ok and (sh._sfx[event] as AudioStreamPlayer3D).bus == &"SFX"
	_check(bus_ok, "every Shunter sound is on the SFX bus, never Music")
	await _reset()


# ============================================================ helpers

func _reset() -> void:
	# Out of its sight first, so the fresh Shunter does not notice whoever
	# the last scenario left standing in the bay.
	_place(bay.to_global(Vector3(7.0, FreightBay.BOOTH_FLOOR + 0.1, 12.6)))
	await _settle(2)
	bay.restart()
	await _settle(4)
	sh = bay.shunter
	hub_now.player.hp = Constants.PLAYER_MAX_HP
	hub_now.player.velocity = Vector3.ZERO


## HARNESS STEP: the Shunter placed at work at `at` (bay-local), and the
## player at `player_at`, facing it. It then notices, or not, on its own.
func _arena_pose(at: Vector3, yaw: float, player_at: Vector3) -> void:
	sh.global_position = bay.to_global(at)
	sh.rotation.y = yaw
	sh.velocity = Vector3.ZERO
	var p := hub_now.player
	p.global_position = bay.to_global(player_at)
	p.velocity = Vector3.ZERO
	for _i in 3:
		_look_at(p, sh.global_position + Vector3(0, 0.6, 0))
		await get_tree().physics_frame


## How long the Shunter stays in `name`, from now (it must be in it).
func _time_in(name: String) -> float:
	var frames := 0
	if sh.state != name:
		await _await_live(name, func() -> bool: return sh.state == name, 6.0)
	var started := sh.state_time
	while sh.state == name:
		frames += 1
		await get_tree().physics_frame
	return started + frames * DT


## The player's own sidestep: move_left until `metres` lateral, or 0.4 s.
func _sidestep_now(metres: float) -> float:
	var p := hub_now.player
	var from := p.global_position
	Input.action_press("move_left")
	for _i in 24:
		await get_tree().physics_frame
		if Vector2(p.global_position.x - from.x,
				p.global_position.z - from.z).length() >= metres:
			break
	Input.action_release("move_left")
	return Vector2(p.global_position.x - from.x,
			p.global_position.z - from.z).length()


## A live shot from the weapon out, aimed at the Shunter's body.
func _fire_at_shunter() -> void:
	var p := hub_now.player
	for _i in 3:
		_look_at(p, sh.global_position + Vector3(0, 0.6, 0))
		await get_tree().physics_frame
	await _press("fire_pulse")
