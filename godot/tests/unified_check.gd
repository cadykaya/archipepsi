class_name UnifiedCheck
extends "res://tests/d22_slice_driver.gd"
## THE UNIFIED BUILD'S SEAMS (`--unified-live=<phase>`), through the real
## slice bridge and the real Main, the way `D22SliceDriver` checks the loop.
##
##     tools/unified_check.sh        (or: make godot-unified)
##
## Each phase checks one place where two systems meet:
##
##   weapons   the five weapons on the game's own player. In the station:
##             each key draws its weapon on Echo slot B and fires it with
##             the left button; 0 holsters, the Pulse fires again and the
##             saved Echo-B comes back. Then a Crossing: the weapon drawn
##             in the station is still out after the door, and a Foundry
##             shot takes 15 from a Crossing enemy through the ordinary
##             damage path.
##
## **HARNESS STEPS, declared:** the Forge is used through its own handlers
## (as in the slice check); an enemy is aimed at by turning the player to
## it, and the player is placed facing it -- the walk is the Crossing's
## business.

const UNIFIED_PHASE_FLAG := "--unified-live="


static func phase_from_cmdline() -> String:
	return _arg(UNIFIED_PHASE_FLAG)


func _run() -> void:
	await get_tree().process_frame
	BridgeClient.error_received.connect(func(err: Dictionary) -> void:
		_errors.append(err))
	_load_state()
	if await _await_live("bridge connection",
			func() -> bool: return BridgeClient.online, 20.0):
		_check(Unified.active(), "the build runs with --unified")
		match phase_from_cmdline():
			"weapons":
				await _phase_weapons()
			_:
				_check(false, "no --unified-live phase was named")
	_save_state()
	_finish()


func _finish() -> void:
	for action: String in ["move_forward", "move_left", "move_right",
			"move_back", "jump", "fire_pulse", "interact"]:
		Input.action_release(action)
	for line: String in notes:
		print("  NOTE " + line)
	var phase := phase_from_cmdline().to_upper()
	if failures == 0:
		print("GODOT UNIFIED %s OK (%d checks, %d notes)"
				% [phase, checks, notes.size()])
	else:
		print("GODOT UNIFIED %s: %d failures in %d checks"
				% [phase, failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


# -- weapons --------------------------------------------------------------------

func _phase_weapons() -> void:
	if not await _await_live("the campaign",
			func() -> bool: return BridgeClient.hub_mode() != "NO_CAMPAIGN",
			30.0):
		return
	var hub := await _the_hub()
	if hub == null:
		return
	var armory: UnifiedArmory = main.armory
	_check(armory != null and armory.player == hub.player,
			"the station's player is armed")
	if armory == null:
		return
	var echo_b: EchoRuntime = hub.player.runtimes[RangeWeapons.SLOT]
	var saved := BridgeClient.slotted_action(RangeWeapons.SLOT)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_look_at(hub.player, hub.player.global_position + Vector3(0, 1.2, 6))
	for key: int in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
		var id: String = UnifiedArmory.KEYS[key]
		await _key(key)
		_check(armory.out() == id
				and str(echo_b.equipped.get("component_id", "")) == "range_" + id,
				"key %s draws %s on Echo-B" % [OS.get_keycode_string(key), id])
		var before := armory.weapons.shots
		if id == "driver":
			Input.action_press("fire_pulse")
			await _settle(90)
			Input.action_release("fire_pulse")
			await _settle(20)
		else:
			await _press("fire_pulse")
			await _settle(10)
		_check(armory.weapons.shots > before,
				"%s fires on the left button in the station" % id)
		# Let the cooldown pass before the next weapon.
		await _settle(130)
	await _key(KEY_0)
	_check(armory.out() == "" and hub.player.viewmodel.visible,
			"0 holsters: the Static Pulse viewmodel is back")
	_check(echo_b.equipped == saved,
			"holstering hands the saved Echo-B back (%s)"
			% str(saved.get("display_name", "empty")))
	var pulses := [0]
	hub.player.fired_pulse.connect(func() -> void: pulses[0] += 1)
	await _press("fire_pulse")
	await _settle(4)
	_check(pulses[0] == 1, "with no weapon out, the left button is the Pulse")

	# A snapshot does not take the weapon away.
	await _key(KEY_1)
	main._sync_equipped()
	_check(str(echo_b.equipped.get("component_id", "")) == "range_foundry",
			"a snapshot's re-equip leaves the weapon out")

	# Into a Crossing with the Foundry out.
	var forge := await _open_forge(hub, 1)
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
	armory = main.armory
	_check(armory != null and armory.player == crossing.player
			and armory.out() == "foundry",
			"through the door the Foundry is still out, on the new player")
	var enemy := _nearest_enemy(crossing)
	_check(enemy != null, "the Crossing has an enemy to try it on")
	if enemy == null:
		return
	var hp_before: float = enemy.hp
	# The TARGET is brought to the shooter, on the shooter's own floor: a
	# placed player can land off a ledge (the first version did, into an
	# arena basin), and the walk is not what is under test.
	await _settle(20)
	var p := crossing.player
	var ahead := -p.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	enemy.global_position = p.global_position + ahead * 5.0
	enemy.velocity = Vector3.ZERO
	_note("HARNESS STEP: %s placed 5 m in front of the player" % enemy.name)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var landed := false
	for _try in 3:
		for _i in 6:
			_look_at(p, enemy.global_position + Vector3(0, 0.9, 0))
			await get_tree().physics_frame
		await _press("fire_pulse")
		await _settle(8)
		if not is_instance_valid(enemy) or enemy.hp < hp_before:
			landed = true
			break
		await _settle(50)
	_check(landed and (not is_instance_valid(enemy)
			or is_equal_approx(hp_before - enemy.hp, 15.0)
			or enemy.hp <= 0.0),
			"a Foundry shot takes 15 from a Crossing enemy (%.1f -> %s)"
			% [hp_before, str(enemy.hp) if is_instance_valid(enemy) else "dead"])
	_state["weapons_zone"] = zid


func _key(key: int) -> void:
	var down := InputEventKey.new()
	down.keycode = key
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _settle(3)


func _nearest_enemy(crossing: ZoneController) -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for node: Node in crossing.find_children("*", "Enemy", true, false):
		var e := node as Enemy
		if e == null or e._dead:
			continue
		var d := e.global_position.distance_to(crossing.player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
