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
			"art":
				await _phase_art()
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

	# Consumables work only inside a Crossing (the unified build's rule).
	var refusals: Array = []
	var on_refused := func(why: String) -> void: refusals.append(why)
	hub.player.consumable_refused.connect(on_refused)
	var intents_before := BridgeClient.sent_intents.size()
	hub.player.press_slot("consumable")
	await _settle(4)
	_check(refusals == [Player.NOT_IN_A_CROSSING]
			and BridgeClient.sent_intents.size() == intents_before
			and _toast_says("Consumables only work inside a Crossing."),
			"in the station the consumable key is refused, said, and "
			+ "nothing is asked of the bridge (%s)" % str(refusals))
	hub.player.consumable_refused.disconnect(on_refused)

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
	var inside: Array = []
	crossing.player.consumable_refused.connect(
			func(why: String) -> void: inside.append(why))
	crossing.player.press_slot("consumable")
	await _settle(4)
	_check(not Player.NOT_IN_A_CROSSING in inside and crossing.player.in_crossing(),
			"inside a Crossing the station rule does not refuse the key (%s)"
			% str(inside))
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


# -- art ------------------------------------------------------------------------

## Arty's weapons and Glyph effects on the game's player, and her two
## reported issues: Mass Driver impacts that never entered the world, and
## effect nodes renamed on repeated hits (counted by list, never by name).
func _phase_art() -> void:
	if not await _await_live("the campaign",
			func() -> bool: return BridgeClient.hub_mode() != "NO_CAMPAIGN",
			30.0):
		return
	var hub := await _the_hub()
	if hub == null:
		return
	var armory: UnifiedArmory = main.armory
	var w := armory.weapons
	var rig := w.rig
	_check(armory.dressed.size() == 5,
			"all five weapons wear Arty's art (%s)" % ", ".join(armory.dressed))
	for id: String in RangeWeapons.IDS:
		var model: Node3D = rig.models[id]
		var art := model.get_node_or_null("WeaponArt")
		var muzzle := model.get_node_or_null("Muzzle")
		var placeholder := 0
		for child in model.get_children():
			if not String(child.name) in WeaponArt.RIG_OWNED \
					and child != art and not child.is_queued_for_deletion():
				placeholder += 1
		_check(art != null and muzzle != null and placeholder == 0,
				"%s: the art is in, the rig's Muzzle kept, no placeholder left"
				% id)
		for key: String in WeaponArt.PARTS[id]:
			var part: Node3D = (rig.get("_parts") as Dictionary).get(id + "/" + key)
			_check(part != null and art != null and art.is_ancestor_of(part)
					or (part != null and String(part.name) == "CarouselDrive"),
					"%s/%s drives the art's %s" % [id, key, WeaponArt.PARTS[id][key]])
		var lean: StandardMaterial3D = WeaponArt._materials.get(id)
		_check(lean != null
				and lean.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY
				and lean.normal_texture.get_image().get_format() == Image.FORMAT_RG8
				and lean.texture_filter
						== BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,
				"%s: lean material (MULTIPLY lamp, RG8 normal, nearest+mips)" % id)
	var core := (rig.get("_parts") as Dictionary).get("driver/core") as MeshInstance3D
	# Every sheet fx.json names loads, as it will in an exported build.
	var unloaded: Array[String] = []
	var sheets: Dictionary = armory.fx.fx
	for sheet: String in sheets:
		if sheet.begins_with("_"):
			continue
		var path := armory.fx.fx_dir.path_join(String(sheets[sheet]["file"]))
		if not load(path) is Texture2D:
			unloaded.append(sheet)
	_check(unloaded.is_empty() and sheets.size() > 30,
			"all %d Glyph sheets load through the importer%s" % [sheets.size() - 1,
			"" if unloaded.is_empty() else " (missing: %s)" % ", ".join(unloaded)])
	_check(core != null and core.material_override is StandardMaterial3D
			and (core.material_override as StandardMaterial3D).emission_operator
					== BaseMaterial3D.EMISSION_OP_ADD,
			"the Driver's core glow is the ADD override the rig drives")

	# Face the back wall, 13 m off.
	_look_at(hub.player, hub.player.global_position + Vector3(0, 1.0, 10))
	# One shot each: its authored flash plays on the shot.
	for key: int in [KEY_1, KEY_2, KEY_4]:
		await _key(key)
		var fired := _fx_events("fired").size()
		await _press("fire_pulse")
		await _settle(30)
		_check(_fx_events("fired").size() == fired + 1,
				"%s: one authored flash on the shot" % armory.out())
		await _settle(90)

	# Arty's issue 2: a burst, every hit counted by list, never by name.
	await _key(KEY_3)
	var impacts_before := _fx_events("impact").size()
	var marks_before := _fx_events("mark").size()
	var shots_before := w.shots
	Input.action_press("fire_pulse")
	for _i in 120:
		await get_tree().physics_frame
	Input.action_release("fire_pulse")
	await _settle(40)
	var rounds := w.shots - shots_before
	var fx_impacts := _fx_events("impact").size() - impacts_before
	var fx_marks := _fx_events("mark").size() - marks_before
	var renamed := 0
	for node: Variant in w.impacts.marks:
		if node is Node and is_instance_valid(node) \
				and String((node as Node).name).begins_with("@"):
			renamed += 1
	_check(rounds >= 10 and fx_impacts == rounds and fx_marks == rounds,
			"Switchback burst: %d rounds, %d authored impacts, %d authored marks"
			% [rounds, fx_impacts, fx_marks])
	_note("issue 2: %d of the burst's marks carry Godot's renamed form "
			% renamed + "(@...), and every one was still counted (by list)")

	# Arty's issue 1: the Mass Driver's impact and its sound enter the world.
	await _key(KEY_5)
	await _settle(30)
	var sounds_before := _impact_sounds(hub).size()
	Input.action_press("fire_pulse")
	await _settle(110)
	Input.action_release("fire_pulse")
	var landed := false
	for _i in 120:
		await get_tree().physics_frame
		if not w.last_slug.is_empty():
			landed = true
			break
	await _settle(4)
	var last: Dictionary = w.impacts.last
	var root: Variant = last.get("root")
	_check(landed and root is Node3D and is_instance_valid(root)
			and (root as Node3D).is_inside_tree(),
			"Mass Driver: the impact's sparks/light root is in the world")
	_check(_impact_sounds(hub).size() > sounds_before,
			"Mass Driver: the impact sound is in the world and playing")
	var orphan := false
	for e: Dictionary in _fx_events("impact"):
		if String(e.get("weapon", "")) == "driver" and bool(e.get("orphan", false)):
			orphan = true
	_check(not orphan,
			"Mass Driver: the authored impact plays from the impact itself, "
			+ "not the adapter's fallback")


func _fx_events(kind: String) -> Array:
	var out: Array = []
	var armory: UnifiedArmory = main.armory
	for e: Dictionary in armory.fx.events:
		if String(e.get("event", "")) == kind:
			out.append(e)
	return out


## Positional impact sounds alive in the tree.
func _impact_sounds(_hub: Node) -> Array:
	var out: Array = []
	for node: Node in get_tree().root.find_children("*", "AudioStreamPlayer3D",
			true, false):
		var sound := node as AudioStreamPlayer3D
		if sound.is_inside_tree() and sound.stream != null \
				and sound.stream.resource_path.get_file().contains("impact"):
			out.append(sound)
	return out


## A toast on the HUD with exactly this text.
func _toast_says(text: String) -> bool:
	for child: Node in main.hud._toast_box.get_children():
		if child is Label and (child as Label).text == text:
			return true
	return false


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
