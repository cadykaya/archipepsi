extends Node
## Full-campaign integration driver against a LIVE bridge (mock AP,
## fallback Epsilon): plays the whole game headlessly.
##
## Pass 1 (detailed): first zone with objective-gating assertions
## (tests 58/59), echo grant, equip.
## Pass 2 (campaign): loops zones to the finale and postgame, buying shop
## stock when affordable (with a double-buy refusal probe — test O),
## until ALL_CHECKS_CLEARED.
##
##     make bridge-mock &
##     godot --headless --path godot -- --integration-test

var failures := 0
var _bought_once := false
var _double_buy_probed := false
var _error_count := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	BridgeClient.error_received.connect(
			func(_err: Dictionary) -> void: _error_count += 1)
	_run()

func _finish(code: int) -> void:
	print("GODOT INTEGRATION %s" % ("OK" if code == 0 else "FAILED"))
	get_tree().quit(code)

func _await_condition(what: String, predicate: Callable,
		timeout := 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	_check(false, "timed out waiting for " + what)
	return false

func _run() -> void:
	await get_tree().process_frame
	if not await _await_condition("bridge connection",
			func() -> bool: return BridgeClient.online, 10.0):
		_finish(1)
		return
	print("bridge online")

	BridgeClient.send_intent({"type": "start_mock_campaign"})
	if not await _await_condition("ZONE_AVAILABLE",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_AVAILABLE"):
		_finish(1)
		return
	_check(BridgeClient.snapshot.get("scouted", []).size() == 30,
			"30 locations scouted")
	await _check_hub_builds()
	_check_enemy_silhouettes()
	_check_theme_agreement()

	if not await _play_one_zone(true):
		_finish(1)
		return

	# ---- Pass 2: play the campaign to the end -----------------------------
	var zones_played := 1
	var stock_ever_seen := false
	while zones_played < 40:
		var mode := BridgeClient.hub_mode()
		if mode == "ALL_CHECKS_CLEARED":
			break
		if mode == "WAITING_FOR_AP":
			# Mock AP only delivers on checks; this should clear itself as
			# deliveries land. Give it a moment.
			await _await_condition("WAITING_FOR_AP to clear",
					func() -> bool:
						return BridgeClient.hub_mode() != "WAITING_FOR_AP",
					10.0)
			continue
		if not BridgeClient.snapshot.get("shop", {}).get("stock",
				[]).is_empty():
			stock_ever_seen = true
			await _try_shop_purchase()
		if mode in ["ZONE_AVAILABLE", "FINALE_ONLY"]:
			if not await _play_one_zone(false):
				_finish(1)
				return
			zones_played += 1
			continue
		await get_tree().process_frame

	var snapshot := BridgeClient.snapshot
	_check(BridgeClient.hub_mode() == "ALL_CHECKS_CLEARED",
			"campaign reaches ALL_CHECKS_CLEARED (after %d zones)"
			% zones_played)
	_check(snapshot.get("checked_location_ids", []).size() == 30,
			"all 30 checks confirmed")
	_check(bool(snapshot.get("hub", {}).get("goal_sent", false)),
			"goal reported")
	var foreign := 0
	for scout: Dictionary in snapshot.get("scouted", []):
		if not scout.get("recipient_is_self", false):
			foreign += 1
	_check(snapshot.get("echoes", []).size() == foreign,
			"%d foreign checks -> %d echoes, none missing, none duplicated"
			% [foreign, snapshot.get("echoes", []).size()])
	_check(stock_ever_seen, "shop stocked at least once during the campaign")
	if stock_ever_seen:
		_check(_bought_once, "at least one shop purchase completed")
		_check(int(snapshot.get("coins_spent", 0)) > 0,
				"coins were genuinely spent")
	_finish(0 if failures == 0 else 1)

# ---------------------------------------------------------------------------

## The Hub is authored, not generated, so nothing else in this driver
## exercises it — but it is where the player spends half their time, and
## its board reads live campaign state.
func _check_hub_builds() -> void:
	var hub := HubController.new()
	get_tree().root.add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hub.player != null, "hub spawns the player")
	_check(hub._board_cells.size() == Constants.LOCATION_COUNT,
			"campaign board has one cell per Check (%d)"
			% hub._board_cells.size())
	hub.refresh()
	await get_tree().process_frame
	var legend: String = hub._board_legend.text
	_check(legend.contains("sent") and legend.contains("key-locked"),
			"campaign board legend reads live state: '%s'" % legend)
	var lit := 0
	for cell: MeshInstance3D in hub._board_cells:
		if cell.material_override != null:
			lit += 1
	_check(lit == Constants.LOCATION_COUNT,
			"every board cell is tinted (%d)" % lit)
	hub.queue_free()
	await get_tree().process_frame

## The client colours a game by re-deriving the bridge's theme rule. If
## the two ever disagree, the Hub board and reveal cards would tint a game
## differently from the Zone the bridge actually built for it.
##
## Expectations are generated by the bridge's own `_theme_for`; see
## bridge/tests/test_theme_agreement.py, which pins the same pairs.
func _check_theme_agreement() -> void:
	var expected := {
		"Ocarina of Time": "temple_ruin",       # pinned hint
		"Archipepsi": "void_glitch",            # pinned hint
		"Hollow Knight": "void_glitch",         # sha256-hashed
		"Celeste": "temple_ruin",
		"Factorio": "void_glitch",
		"A Link to the Past": "rusted_industrial",
		"Slay the Spire": "neon_transit",
	}
	for game: String in expected:
		var got := ThemeMaterials.theme_for_game(game)
		_check(got == expected[game],
				"theme for '%s' matches the bridge (%s)" % [game, got])

## An enemy's visible body must stay inside its collision box: geometry
## reaching past it clips through walls and doorframes, and every corridor
## lane budget is sized to the collider, not to the silhouette.
func _check_enemy_silhouettes() -> void:
	for kind: String in Constants.ENEMY_ARCHETYPES:
		var enemy := Enemy.create(kind, "gothic_stone")
		var half_width := 0.0
		for child in enemy.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				half_width = child.shape.size.x / 2.0
		var worst := 0.0
		for child in enemy.get_children():
			if not (child is MeshInstance3D):
				continue
			var mesh: Mesh = child.mesh
			var extent := 0.0
			if mesh is BoxMesh:
				extent = (mesh as BoxMesh).size.x / 2.0
			elif mesh is PrismMesh:
				extent = (mesh as PrismMesh).size.x / 2.0
			else:
				continue
			worst = maxf(worst, absf(child.position.x) + extent)
		_check(half_width > 0.0 and worst <= half_width + 0.001,
				"%s silhouette fits its collider (%.2f <= %.2f)"
				% [kind, worst, half_width])
		enemy.free()

func _play_one_zone(detailed: bool) -> bool:
	var mode := BridgeClient.hub_mode()
	# finale_offered stays true in postgame by schema construction (both its
	# operands remain honestly true); the goal being missing is the extra
	# client-side condition. See docs/IMPLEMENTATION_DECISIONS.md.
	var goal_missing := false
	for loc in BridgeClient.snapshot.get("missing_location_ids", []):
		if int(loc) == Constants.GOAL_LOCATION_ID:
			goal_missing = true
	var finale := goal_missing and (mode == "FINALE_ONLY"
			or bool(BridgeClient.hub().get("finale_offered", false)))
	BridgeClient.send_intent({"type": "request_next_zone", "finale": finale})
	if not await _await_condition("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		return false
	var record := BridgeClient.active_zone()
	var zone_dict: Dictionary = record.get("zone", {})
	if detailed:
		_check(not zone_dict.is_empty(), "zone content arrived")
	print("zone %s: '%s' (%s)%s checks %s" % [record.get("zone_id"),
			zone_dict.get("display_name"), zone_dict.get("theme"),
			" [FINALE]" if record.get("is_finale") else "",
			str(record.get("allocated_location_ids", []))])

	BridgeClient.send_intent({"type": "enter_zone",
			"zone_id": record.get("zone_id", "")})
	if not await _await_condition("ZONE_ACTIVE",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		return false

	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(zone_dict)
	await get_tree().process_frame
	await get_tree().process_frame

	if detailed:
		_check(controller.player != null, "player spawned")
		_check(controller._exit_portal != null, "exit portal appended")
		_check(controller._exit_portal.unlocked == false,
				"exit portal starts sealed")
		controller = await _test_leave_and_resume(controller, zone_dict)
		if controller == null:
			return false

	for chamber_record: Dictionary in controller._chambers:
		await _process_chamber(controller, chamber_record, detailed)

	if not await _await_condition("zone completes",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			15.0):
		return false
	controller.refresh()
	if detailed:
		_check(controller._exit_portal.unlocked, "exit portal unlocked")
		var echoes: Array = BridgeClient.snapshot.get("echoes", [])
		if not echoes.is_empty():
			var echo_id: String = echoes[0]["echo_id"]
			BridgeClient.send_intent({"type": "equip_echo",
					"echo_id": echo_id})
			await _await_condition("echo equipped",
					func() -> bool:
						return BridgeClient.snapshot.get("equipped_echo_id") \
								== echo_id)
			controller.player.echo_runtime.set_equipped(
					BridgeClient.equipped_echo())
			controller.player.echo_runtime.activate()
			_check(controller.player.echo_runtime.cooldown_remaining >= 0.0,
					"equipped echo activates on demand")
	controller.queue_free()
	await get_tree().process_frame
	return true

## Satisfy one chamber's objective honestly, then claim its reward.
func _process_chamber(controller: ZoneController,
		chamber_record: Dictionary, detailed: bool) -> void:
	var reward: RewardObject = chamber_record["reward"]
	if reward != null and BridgeClient.is_checked(reward.location_id):
		return                                    # confirmed on a prior visit
	match chamber_record["objective"]:
		"kill_all":
			if detailed and reward != null and reward.state == "locked":
				reward.interact(controller.player)
				await get_tree().process_frame
				_check(not BridgeClient.is_pending(reward.location_id),
						"locked reward refuses interaction (test 58)")
			for enemy in chamber_record["enemies"]:
				if is_instance_valid(enemy):
					enemy.die()
			await get_tree().process_frame
		"platform_to_goal":
			controller._on_goal_area_entered(controller.player,
					chamber_record)
			await get_tree().process_frame
	if reward == null:
		return
	if not await _await_condition("reward %d available" % reward.location_id,
			func() -> bool: return reward.state == "available", 5.0):
		return
	if detailed:
		controller.player.take_damage(10000.0)
		await get_tree().process_frame
		_check(reward.state == "available",
				"objective stays latched through death (test 59)")
	reward.interact(controller.player)
	await _await_condition("check %d confirmed" % reward.location_id,
			func() -> bool:
				return BridgeClient.is_checked(reward.location_id), 15.0)

## Acceptance Test I: leave and resume. Clears ONE chamber, leaves via the
## pause path, verifies the Zone stays ACTIVE and no new Zone can start,
## then rebuilds the scene and verifies transient reset + persistence.
func _test_leave_and_resume(controller: ZoneController,
		zone_dict: Dictionary) -> ZoneController:
	var first: Dictionary = {}
	for chamber_record: Dictionary in controller._chambers:
		if chamber_record["reward"] != null:
			first = chamber_record
			break
	if first.is_empty():
		return controller
	await _process_chamber(controller, first, true)
	var claimed: int = first["reward"].location_id
	_check(BridgeClient.is_checked(claimed), "first check confirmed")

	var zone_id := controller.zone_id
	controller.queue_free()
	await get_tree().process_frame
	BridgeClient.send_intent({"type": "leave_zone", "zone_id": zone_id})
	await get_tree().process_frame
	if not await _await_condition("snapshot after leave",
			func() -> bool:
				return BridgeClient.hub_mode() == "ZONE_ACTIVE", 5.0):
		return null
	_check(BridgeClient.hub_mode() == "ZONE_ACTIVE",
			"zone stays ACTIVE after leaving (test I)")

	var errors_before := _error_count
	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	await _await_condition("second zone request refused",
			func() -> bool: return _error_count > errors_before, 5.0)
	_check(BridgeClient.hub_mode() == "ZONE_ACTIVE",
			"no new zone can be generated while one is ACTIVE (test I)")

	var resumed := ZoneController.new()
	get_tree().root.add_child(resumed)
	resumed.setup(zone_dict)
	await get_tree().process_frame
	await get_tree().process_frame
	for chamber_record: Dictionary in resumed._chambers:
		var reward: RewardObject = chamber_record["reward"]
		if reward == null:
			continue
		if reward.location_id == claimed:
			_check(reward.state == "confirmed",
					"confirmed reward stays disabled after resume (test I)")
		elif chamber_record["objective"] != "reach_reward":
			_check(reward.state == "locked",
					"objectives reset on resume (test I)")
	_check(resumed._exit_portal.unlocked == false,
			"exit portal stays locked until every check confirms (test I)")
	return resumed

func _try_shop_purchase() -> void:
	var snapshot := BridgeClient.snapshot
	var coins := int(snapshot.get("coins_available", 0))
	for item: Dictionary in snapshot.get("shop", {}).get("stock", []):
		var cost := int(item.get("cost", 0))
		if coins < cost:
			continue
		var location := int(item.get("location_id", 0))
		var spent_before := int(snapshot.get("coins_spent", 0))
		BridgeClient.send_intent({"type": "buy_shop_stock",
				"location_id": location})
		if not _double_buy_probed:
			# Test O: the second intent for the same location must be
			# refused and charge nothing.
			_double_buy_probed = true
			BridgeClient.send_intent({"type": "buy_shop_stock",
					"location_id": location})
		var confirmed := await _await_condition(
				"purchase %d confirms" % location,
				func() -> bool: return BridgeClient.is_checked(location),
				15.0)
		if confirmed:
			_bought_once = true
			var spent_after := int(
					BridgeClient.snapshot.get("coins_spent", 0))
			_check(spent_after == spent_before + cost,
					"double buy charged exactly once (test O)")
		return
