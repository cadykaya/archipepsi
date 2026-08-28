class_name ZoneController
extends Node3D
## Owns one loaded Zone instance: enemies, objective latching, rewards, the
## exit portal, and the player. Transient by design — nothing here survives
## leaving the Zone, which is why leaving resets objectives (§14.3).

signal exit_requested
## The player moved into a different chamber's bounds — the rule engine's
## `chamber_enter` event. Fires for the first chamber on the first frame.
signal chamber_entered(index: int)

var zone: Dictionary = {}
var zone_id := ""
var player: Player
var tones: Tones = null          # set by main; null in headless tests
var hud: Hud = null              # set by main; null in headless tests
## Set by main before setup(). The Zone geometry is whatever the schema
## said; this only changes how the last transmission is presented.
var is_finale := false

var _chambers: Array = []      # {chamber, objective, satisfied, enemies,
                               #  reward, goal_area}
var _exit_portal: ExitPortal
var _first_kill_seen := false
var _portal_was_locked := true
var _quiet_time := 0.0
var _last_claimed := -1
var _current_chamber := -1
## Union of every chamber and connector AABB the builder placed.
## `blink` tests its landing point against this: outside it is
## outside the level, wall or no wall (invariant I14).
var _world_bounds := AABB()
var _has_bounds := false
const _QUIET_BEFORE_ASIDE := 75.0

func setup(zone_dict: Dictionary) -> void:
	zone = zone_dict
	zone_id = zone.get("zone_id", "")
	var theme: String = zone.get("theme", "void_glitch")
	var build := ZoneBuilder.build(zone)
	add_child(build["root"])
	_exit_portal = build["exit_portal"]
	for box: AABB in build["bounds_list"]:
		_world_bounds = box if not _has_bounds \
				else _world_bounds.merge(box)
		_has_bounds = true
	_exit_portal.exit_requested.connect(func() -> void: exit_requested.emit())

	player = Player.create()
	add_child(player)
	player.set_spawn(build["spawn_transform"])

	# Optional ledges (DESIGN §19). Walked, not searched: nothing is
	# reported anywhere, so reaching one only ever earns a remark.
	for node in _collect_group(build["root"], ChamberBuilders.SECRET_GROUP):
		var area := node as Area3D
		area.body_entered.connect(_on_secret_entered.bind(area))

	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var xform: Transform3D = entry["xform"]
		var result: Dictionary = entry["build"]
		var record := {
			"chamber": chamber,
			"objective": _objective_of(chamber),
			"satisfied": false,
			"enemies": [] as Array,
			"reward": null,
			# Grown a metre so a doorway seam cannot flicker between
			# chambers frame to frame.
			"bounds": ZoneBuilder._world_aabb(result["bounds"], xform.origin,
					xform.basis.get_euler().y).grow(1.0),
		}

		for spawn: Dictionary in result.get("enemy_spawns", []):
			var enemy := Enemy.create(spawn["archetype"], theme)
			add_child(enemy)
			enemy.global_position = xform * spawn["position"]
			record["enemies"].append(enemy)
			enemy.enemy_died.connect(_on_enemy_died.bind(record))

		var location: Variant = chamber.get("reward_location_id")
		if location != null:
			var reward := RewardObject.create(int(location), zone_id, theme)
			add_child(reward)
			reward.global_position = xform * result.get(
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
			area.global_transform = Transform3D(xform.basis,
					xform * result.get("goal_area_position",
						result["exit_offset"]))
			area.body_entered.connect(
					_on_goal_area_entered.bind(record))

		_chambers.append(record)
	_evaluate_objectives()
	refresh()
	if is_finale and hud != null:
		hud.say_line("finale_open")

func _objective_of(chamber: Dictionary) -> String:
	# A corridor has no objective; a reward inside one is implicitly
	# reach_reward. treasure_room defaults reach_reward too.
	return str(chamber.get("objective", "reach_reward"))

func _on_enemy_died(enemy: Enemy, record: Dictionary) -> void:
	if tones != null:
		tones.play("hit")
	_quiet_time = 0.0                # a fight is not a quiet stretch
	# Objectives resolve BEFORE anything is said, so a one-enemy room says
	# "cleared" rather than having first_blood claim the kill and the
	# throttle swallow the line that actually mattered.
	var cleared := false
	if record["objective"] == "kill_all" and not record["satisfied"]:
		_evaluate_objectives()
		cleared = record["satisfied"]
	if hud == null:
		return
	if is_finale and enemy.archetype == "brute":
		# The finale's boss outranks both of the others.
		hud.say_line("finale_brute")
		_first_kill_seen = true
	elif cleared:
		hud.say_line("room_cleared")
		_first_kill_seen = true
	elif not _first_kill_seen:
		_first_kill_seen = true
		hud.say_line("first_blood")

## Walked into a secret. Says one thing, once, and stops watching: a ledge
## you are standing on should not keep congratulating you.
func _on_secret_entered(body: Node3D, area: Area3D) -> void:
	if not (body is Player):
		return
	area.set_deferred("monitoring", false)
	if tones != null:
		tones.play("secret")
	if hud != null:
		hud.say_line("secret_found")

## Walks a freshly built Zone for grouped nodes. `get_tree()` would also
## sweep up the previous Zone's nodes, which are queue_freed but still in
## the tree for the rest of the frame.
static func _collect_group(node: Node, group: String) -> Array[Node]:
	var out: Array[Node] = []
	if node.is_in_group(group):
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_group(child, group))
	return out

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
	var outstanding := 0
	for location in active.get("allocated_location_ids", []):
		if not BridgeClient.is_checked(int(location)):
			outstanding += 1
	_exit_portal.set_unlocked(complete, outstanding)
	# The unlock is pushed on every snapshot, so remark on the edge only.
	if complete and _portal_was_locked and hud != null:
		hud.say_line("portal_open")
	_portal_was_locked = not complete

## Connector segments belong to no chamber, so the current chamber holds
## until the next one's bounds are genuinely entered — hysteresis for free.
func _track_chamber() -> void:
	if player == null:
		return
	for index in _chambers.size():
		var bounds: AABB = _chambers[index].get("bounds", AABB())
		if bounds.has_point(player.global_position):
			if index != _current_chamber:
				_current_chamber = index
				chamber_entered.emit(index)
			return

func _process(delta: float) -> void:
	_track_chamber()
	if hud == null or player == null:
		return
	var claimed := 0
	var total := 0
	# Nearest actionable reward wins; a reward whose objective is already
	# satisfied outranks one that still needs clearing, so the waypoint
	# always names the thing you can finish soonest.
	var best: RewardObject = null
	var best_rank := 99
	var best_distance := INF
	for record: Dictionary in _chambers:
		var reward: RewardObject = record["reward"]
		if reward == null:
			continue
		total += 1
		if reward.state == "confirmed":
			claimed += 1
			continue
		var rank := 0 if reward.state == "available" else 1
		var distance := player.global_position.distance_to(
				reward.global_position)
		if rank < best_rank or (rank == best_rank and distance < best_distance):
			best = reward
			best_rank = rank
			best_distance = distance

	if total > 0:
		hud.set_objective_text("CHECKS %d/%d CLAIMED" % [claimed, total])
	else:
		hud.set_objective_text("")

	# A long stretch with nothing claimed usually means the player is lost
	# or exploring; either way it is the one moment a designer's aside is
	# welcome rather than an interruption.
	if claimed != _last_claimed:
		_last_claimed = claimed
		_quiet_time = 0.0
	else:
		_quiet_time += delta
		if _quiet_time >= _QUIET_BEFORE_ASIDE:
			_quiet_time = 0.0
			hud.say_line("long_walk")

	if best != null:
		var label := "CHECK %03d" % (best.location_id % 1000)
		if best.state == "sending":
			hud.set_waypoint(best.global_position, label + " · SENDING",
					Color(1.0, 0.9, 0.4))
		elif best.state == "available":
			hud.set_waypoint(best.global_position, label + " · READY",
					Color(0.45, 1.0, 0.9))
		else:
			hud.set_waypoint(best.global_position, label,
					Color(0.72, 0.78, 0.85))
	elif _exit_portal != null and _exit_portal.unlocked:
		hud.set_waypoint(_exit_portal.global_position + Vector3.UP * 2.0,
				"EXIT", Color(0.5, 1.0, 0.6))
	else:
		hud.clear_waypoint()

func _all_checks_confirmed() -> bool:
	var active := BridgeClient.active_zone()
	if active.is_empty():
		return true
	for location in active.get("allocated_location_ids", []):
		if not BridgeClient.is_checked(int(location)):
			return false
	return true

## The Zone's outer bounds in world space, or null before it is built.
## Returning null rather than a zero AABB matters: an empty box would read
## as "nowhere is inside the level" and refuse every blink.
func world_bounds() -> Variant:
	return _world_bounds if _has_bounds else null
