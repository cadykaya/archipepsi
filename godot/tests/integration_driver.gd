extends Node
## Full-loop integration driver against a LIVE bridge (mock AP, fallback
## Epsilon): connect → mock campaign → generate → enter → objectives →
## claim → confirm → echo → equip → zone completes → exit unlocks.
##
##     make bridge-mock &        # python -m archipepsi_bridge --ap=mock
##     godot --headless --path godot -- --integration-test

var failures := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
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

	BridgeClient.send_intent({"type": "request_next_zone", "finale": false})
	if not await _await_condition("ZONE_READY",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_READY",
			30.0):
		_finish(1)
		return
	var record := BridgeClient.active_zone()
	var zone_dict: Dictionary = record.get("zone", {})
	_check(not zone_dict.is_empty(), "zone content arrived")
	print("zone: '%s' (%s), checks %s" % [zone_dict.get("display_name"),
			zone_dict.get("theme"),
			str(record.get("allocated_location_ids", []))])

	BridgeClient.send_intent({"type": "enter_zone",
			"zone_id": record.get("zone_id", "")})
	if not await _await_condition("ZONE_ACTIVE",
			func() -> bool: return BridgeClient.hub_mode() == "ZONE_ACTIVE"):
		_finish(1)
		return

	# Instantiate the Zone exactly as the game would.
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(zone_dict)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(controller.player != null, "player spawned")
	_check(controller._exit_portal != null, "exit portal appended")
	_check(controller._exit_portal.unlocked == false,
			"exit portal starts sealed")

	# Walk each chamber: satisfy its objective honestly, then claim.
	for chamber_record: Dictionary in controller._chambers:
		var reward: RewardObject = chamber_record["reward"]
		match chamber_record["objective"]:
			"kill_all":
				if reward != null:
					_check(reward.state == "locked",
							"kill_all reward locked before combat")
					reward.interact(controller.player)
					await get_tree().process_frame
					_check(not BridgeClient.is_pending(reward.location_id),
							"locked reward refuses interaction (test 58)")
				for enemy in chamber_record["enemies"]:
					if is_instance_valid(enemy):
						enemy.die()
				await get_tree().process_frame
			"platform_to_goal":
				# Latching is driven by the goal Area3D; trip it directly the
				# way a player crossing it would.
				controller._on_goal_area_entered(controller.player,
						chamber_record)
				await get_tree().process_frame
		if reward != null:
			if not await _await_condition("reward %d available"
					% reward.location_id,
					func() -> bool: return reward.state == "available", 5.0):
				continue
			# Objective latching survives player death (test 59).
			controller.player.take_damage(10000.0)
			await get_tree().process_frame
			_check(reward.state == "available",
					"objective stays latched through death (test 59)")
			reward.interact(controller.player)
			await _await_condition("check %d confirmed" % reward.location_id,
					func() -> bool:
						return BridgeClient.is_checked(reward.location_id),
					15.0)

	# The bridge completes the Zone when its last Check confirms.
	if not await _await_condition("zone auto-completes",
			func() -> bool: return BridgeClient.active_zone().is_empty(),
			15.0):
		_finish(1)
		return
	controller.refresh()
	_check(controller._exit_portal.unlocked, "exit portal unlocked")
	_check(int(BridgeClient.snapshot.get("completed_zone_count", 0)) == 1,
			"completed_zone_count == 1")

	# Echoes for the foreign recipients, equipped over the wire.
	var echoes: Array = BridgeClient.snapshot.get("echoes", [])
	var foreign := 0
	for location in record.get("allocated_location_ids", []):
		var scout := BridgeClient.scout_for(int(location))
		if not scout.get("recipient_is_self", false):
			foreign += 1
	_check(echoes.size() == foreign,
			"%d foreign checks produced %d echoes" % [foreign, echoes.size()])
	if not echoes.is_empty():
		var echo_id: String = echoes[0]["echo_id"]
		BridgeClient.send_intent({"type": "equip_echo", "echo_id": echo_id})
		await _await_condition("echo equipped",
				func() -> bool:
					return BridgeClient.snapshot.get("equipped_echo_id") \
							== echo_id)
		controller.player.echo_runtime.set_equipped(
				BridgeClient.equipped_echo())
		controller.player.echo_runtime.activate()
		_check(controller.player.echo_runtime.cooldown_remaining >= 0.0,
				"equipped echo activates on demand")

	_finish(0 if failures == 0 else 1)
