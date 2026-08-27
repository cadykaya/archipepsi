class_name ZoneController
extends Node3D
## Owns one loaded Zone instance: enemies, objective latching, rewards, the
## exit portal, and the player. Transient by design — nothing here survives
## leaving the Zone, which is why leaving resets objectives (§14.3).

signal exit_requested

var zone: Dictionary = {}
var zone_id := ""
var player: Player

var _chambers: Array = []      # {chamber, objective, satisfied, enemies,
                               #  reward, goal_area}
var _exit_portal: ExitPortal

func setup(zone_dict: Dictionary) -> void:
	zone = zone_dict
	zone_id = zone.get("zone_id", "")
	var theme: String = zone.get("theme", "void_glitch")
	var build := ZoneBuilder.build(zone)
	add_child(build["root"])
	_exit_portal = build["exit_portal"]
	_exit_portal.exit_requested.connect(func() -> void: exit_requested.emit())

	player = Player.create()
	add_child(player)
	player.set_spawn(build["spawn_transform"])

	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var origin: Vector3 = entry["origin"]
		var result: Dictionary = entry["build"]
		var record := {
			"chamber": chamber,
			"objective": _objective_of(chamber),
			"satisfied": false,
			"enemies": [] as Array,
			"reward": null,
		}

		for spawn: Dictionary in result.get("enemy_spawns", []):
			var enemy := Enemy.create(spawn["archetype"], theme)
			add_child(enemy)
			enemy.global_position = origin + spawn["position"]
			record["enemies"].append(enemy)
			enemy.enemy_died.connect(_on_enemy_died.bind(record))

		var location: Variant = chamber.get("reward_location_id")
		if location != null:
			var reward := RewardObject.create(int(location), zone_id, theme)
			add_child(reward)
			reward.global_position = origin + result.get(
					"reward_position", Vector3(0, 0, 1))
			record["reward"] = reward

		if record["objective"] == "platform_to_goal":
			var area := Area3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(7.0, 4.0, 3.0)
			shape.shape = box
			area.add_child(shape)
			add_child(area)
			area.global_position = origin + result.get(
					"goal_area_position", result["exit_offset"])
			area.body_entered.connect(
					_on_goal_area_entered.bind(record))

		_chambers.append(record)
	_evaluate_objectives()
	refresh()

func _objective_of(chamber: Dictionary) -> String:
	# A corridor has no objective; a reward inside one is implicitly
	# reach_reward. treasure_room defaults reach_reward too.
	return str(chamber.get("objective", "reach_reward"))

func _on_enemy_died(_enemy: Enemy, record: Dictionary) -> void:
	if record["objective"] == "kill_all" and not record["satisfied"]:
		_evaluate_objectives()

func _on_goal_area_entered(body: Node3D, record: Dictionary) -> void:
	if body is Player and not record["satisfied"]:
		record["satisfied"] = true          # latches for this instance
		_push_objective_state(record)

func _evaluate_objectives() -> void:
	for record: Dictionary in _chambers:
		if record["satisfied"]:
			continue
		match record["objective"]:
			"reach_reward":
				record["satisfied"] = true
			"kill_all":
				var alive := false
				for enemy in record["enemies"]:
					if is_instance_valid(enemy) and not enemy._dead:
						alive = true
						break
				record["satisfied"] = not alive
			"platform_to_goal":
				pass                        # area callback drives it
		_push_objective_state(record)

func _push_objective_state(record: Dictionary) -> void:
	var reward: RewardObject = record["reward"]
	if reward != null:
		reward.set_objective_satisfied(record["satisfied"])

## Called on every campaign snapshot while this Zone is loaded.
func refresh() -> void:
	for record: Dictionary in _chambers:
		var reward: RewardObject = record["reward"]
		if reward != null:
			reward.refresh_from_snapshot()
	# The bridge auto-completes the Zone when its last Check confirms; the
	# snapshot then reports no active zone (or a different one). That is the
	# exit portal's unlock signal.
	var active := BridgeClient.active_zone()
	var complete: bool = active.is_empty() \
			or active.get("zone_id") != zone_id \
			or _all_checks_confirmed()
	_exit_portal.set_unlocked(complete)

func _all_checks_confirmed() -> bool:
	var active := BridgeClient.active_zone()
	if active.is_empty():
		return true
	for location in active.get("allocated_location_ids", []):
		if not BridgeClient.is_checked(int(location)):
			return false
	return true
