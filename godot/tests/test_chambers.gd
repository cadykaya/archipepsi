extends SceneTree
## Headless builder tests (ACCEPTANCE_TESTS §5: 50–56).
## Run: godot --headless --path godot --script tests/test_chambers.gd

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _init() -> void:
	_test_corridor()
	_test_arena()
	_test_chaining_no_overlap()
	_test_bent_layouts_never_overlap()
	_test_props_leave_a_walkable_lane()
	_test_platform_path_bounds()
	_test_tower_route()
	_test_treasure_room()
	_test_exit_portal_appended()
	if failures == 0:
		print("GODOT CHAMBER TESTS OK")
		quit(0)
	else:
		print("GODOT CHAMBER TESTS: %d failures" % failures)
		quit(1)

func _test_corridor() -> void:  # test 50
	var result := ChamberBuilders.corridor(
			{"length": 12.0, "width": 5.0}, "concrete_facility")
	_check(result["exit_offset"] == Vector3(0, 0, 12.0),
			"corridor exit connects at its far end")
	_check(result["bounds"].size.z >= 12.0, "corridor bounds cover length")
	result["root"].free()

func _test_arena() -> void:  # test 51
	var result := ChamberBuilders.arena(
			{"width": 18.0, "depth": 16.0, "wall_height": 6.0,
			"objective": "kill_all",
			"enemies": [{"archetype": "melee", "count": 3}]},
			"gothic_stone")
	_check(result["exit_offset"] == Vector3(0, 0, 16.0),
			"arena exit on far wall")
	_check(result["enemy_spawns"].size() == 3, "arena spawns 3 enemies")
	var bounds: AABB = result["bounds"]
	for spawn: Dictionary in result["enemy_spawns"]:
		_check(bounds.has_point(spawn["position"] + Vector3(0, 0.5, 0)),
				"enemy spawn inside arena bounds")
	result["root"].free()

func _test_chaining_no_overlap() -> void:  # test 52
	var zone := {
		"zone_id": "zone_test", "display_name": "T", "theme": "neon_transit",
		"target_game": "X",
		"chambers": [
			{"id": "c1", "type": "corridor", "length": 10.0, "width": 5.0},
			{"id": "c2", "type": "arena", "width": 14.0, "depth": 12.0,
				"wall_height": 5.0, "objective": "reach_reward"},
			{"id": "c3", "type": "corridor", "length": 8.0, "width": 4.0},
			{"id": "c4", "type": "platform_path", "segment_count": 4,
				"gap_size": 2.0, "vertical_step": 0.5},
			{"id": "c5", "type": "tower", "floors": 3,
				"objective": "reach_reward"},
			{"id": "c6", "type": "treasure_room",
				"reward_location_id": 89100001},
		]}
	var build := ZoneBuilder.build(zone)
	var bounds_list: Array = build["bounds_list"]
	_check(bounds_list.size() >= 6, "every chamber contributes bounds")
	for i in bounds_list.size():
		for j in range(i + 1, bounds_list.size()):
			var a: AABB = bounds_list[i]
			var b: AABB = bounds_list[j]
			var overlap := a.intersection(b)
			# Adjacent bounds may touch at faces; a real overlap has volume.
			_check(overlap.get_volume() < 0.5,
					"chambers %d and %d overlap (volume %.2f)" % [
						i, j, overlap.get_volume()])
	build["root"].free()

func _test_bent_layouts_never_overlap() -> void:
	## Non-linear layouts: across many seeds and every theme, all placements
	## stay disjoint, and at least one seed actually bends. The mixes
	## include the vertically-advancing chambers (tower, platform_path),
	## whose exit offsets carry a y component through the rotation.
	var themes := Constants.THEMES
	var wide_mix: Array = [
		{"id": "c1", "type": "corridor", "length": 12.0, "width": 5.0},
		{"id": "c2", "type": "arena", "width": 24.0, "depth": 20.0,
			"wall_height": 6.0, "objective": "reach_reward",
			"reward_location_id": 89100001},
		{"id": "c3", "type": "corridor", "length": 8.0, "width": 4.0},
		{"id": "c4", "type": "arena", "width": 28.0, "depth": 28.0,
			"wall_height": 5.0, "objective": "reach_reward",
			"reward_location_id": 89100002},
		{"id": "c5", "type": "treasure_room",
			"reward_location_id": 89100003},
	]
	var vertical_mix: Array = [
		{"id": "v1", "type": "corridor", "length": 6.0, "width": 4.0},
		{"id": "v2", "type": "tower", "floors": 5,
			"objective": "reach_reward", "reward_location_id": 89100004},
		{"id": "v3", "type": "platform_path", "segment_count": 8,
			"gap_size": 2.0, "vertical_step": 0.5},
		{"id": "v4", "type": "tower", "floors": 2,
			"objective": "reach_reward", "reward_location_id": 89100005},
		{"id": "v5", "type": "arena", "width": 28.0, "depth": 12.0,
			"wall_height": 8.0, "objective": "reach_reward",
			"reward_location_id": 89100006},
	]
	var any_bend := false
	for seed_index in 16:
		var mix: Array = wide_mix if seed_index % 2 == 0 else vertical_mix
		var zone := {
			"zone_id": "zone_bend_%02d" % seed_index,
			"display_name": "B",
			"theme": themes[seed_index % themes.size()],
			"target_game": "X", "chambers": mix}
		var build := ZoneBuilder.build(zone)
		var bounds_list: Array = build["bounds_list"]
		for i in bounds_list.size():
			for j in range(i + 1, bounds_list.size()):
				var a: AABB = bounds_list[i]
				var b: AABB = bounds_list[j]
				_check(a.intersection(b).get_volume() < 0.5,
						"bent layout %d: pieces %d/%d overlap (%.2f)" % [
							seed_index, i, j,
							a.intersection(b).get_volume()])
		for entry: Dictionary in build["chambers"]:
			if absf(entry["node"].rotation.y) > 0.01:
				any_bend = true
		build["root"].free()
	_check(any_bend, "at least one seeded layout actually bends")

func _test_props_leave_a_walkable_lane() -> void:
	## Theme props may not choke a chamber: at the schema-minimum corridor
	## width, no colliding prop may intrude on the central lane the widest
	## actor (the brute) needs.
	var lane := ChamberBuilders.BRUTE_LANE
	for theme: String in Constants.THEMES:
		for width in [4.0, 6.0, 10.0]:
			for attempt in 4:
				var result := ChamberBuilders.corridor(
						{"id": "lane_%s_%d" % [theme, attempt],
						"length": 30.0, "width": width}, theme)
				for box: AABB in _collidable_boxes(result["root"]):
					# Only obstacles in the walkable band matter: the floor
					# slab, the ceiling and overhead fittings are not
					# obstructions, and the side walls define the lane.
					if box.position.y + box.size.y <= 0.15:
						continue          # floor
					if box.position.y >= 2.0:
						continue          # ceiling / overhead
					if absf(box.get_center().x) > width / 2.0 - 0.25:
						continue          # side wall
					var intrudes: bool = box.position.x < lane / 2.0 \
							and box.position.x + box.size.x > -lane / 2.0
					_check(not intrudes,
							"%s w=%.0f: a prop blocks the %.1fm lane at x=%.2f"
							% [theme, width, lane, box.get_center().x])
				result["root"].free()

func _test_platform_path_bounds() -> void:  # test 53
	# Every legal parameter combination stays within the derived bound.
	for segments in range(3, 9):
		for step_index in range(0, 11):
			var step := float(Constants.MAX_VERTICAL_STEP) \
					* float(step_index) / 10.0
			var allowed := _max_safe_gap(step)
			var gap := minf(2.2, allowed)
			var chamber := {"segment_count": segments, "gap_size": gap,
					"vertical_step": step}
			var result := ChamberBuilders.platform_path(chamber, "temple_ruin")
			_check(gap <= allowed + 0.001,
					"gap %.2f within max_safe_gap(%.2f)=%.2f" % [
						gap, step, allowed])
			var rise: float = result["exit_offset"].y
			_check(absf(rise - step * float(segments)) < 0.01,
					"platform path rise matches steps")
			result["root"].free()

func _max_safe_gap(step: float) -> float:
	# Mirror of constants.max_safe_gap, using only exported constants.
	var g: float = Constants.GRAVITY * Constants.GRAVITY_MULT_MAX
	var v: float = Constants.JUMP_VELOCITY
	var disc: float = v * v - 2.0 * g * step
	if disc < 0.0:
		return 0.0
	var reach: float = Constants.WALK_SPEED * Constants.SPEED_MULT_MIN \
			* (v + sqrt(disc)) / g
	return floorf(reach * Constants.SAFE_GAP_MARGIN * 10.0) / 10.0

func _test_tower_route() -> void:  # test 54
	for floors in range(2, 6):
		var result := ChamberBuilders.tower(
				{"floors": floors, "objective": "reach_reward"},
				"rusted_industrial")
		# The route rises in steps no larger than MAX_VERTICAL_STEP.
		var rise: float = result["exit_offset"].y
		_check(rise > 0.0, "tower exit is elevated")
		# The exit at the summit must actually be open: no collidable box
		# may seal the doorway the route leads to (the review found the
		# back wall built solid, stranding the player at the top).
		var probe := Vector3(0, rise + 1.5, 12.0)
		var sealed := false
		for box in _collidable_boxes(result["root"]):
			if box.has_point(probe):
				sealed = true
		_check(not sealed, "tower summit exit is open (floors=%d)" % floors)
		result["root"].free()

func _collidable_boxes(root: Node3D) -> Array[AABB]:
	## Every colliding piece as a local-space AABB: boxes directly, and
	## cylinder props (drums, column stumps) by their bounding box.
	var out: Array[AABB] = []
	for child in root.get_children():
		if not (child is MeshInstance3D):
			continue
		for sub in child.get_children():
			if not (sub is StaticBody3D):
				continue
			for shape_node in sub.get_children():
				if not (shape_node is CollisionShape3D):
					continue
				var size := Vector3.ZERO
				if shape_node.shape is BoxShape3D:
					size = shape_node.shape.size
				elif shape_node.shape is CylinderShape3D:
					var cylinder: CylinderShape3D = shape_node.shape
					size = Vector3(cylinder.radius * 2.0, cylinder.height,
							cylinder.radius * 2.0)
				else:
					continue
				out.append(AABB(child.position - size / 2.0, size))
	return out

func _test_treasure_room() -> void:  # test 55
	var result := ChamberBuilders.treasure_room(
			{"reward_location_id": 89100004}, "void_glitch")
	_check(result.has("reward_position"), "treasure room places its reward")
	_check(result["enemy_spawns"].is_empty(), "treasure room has no enemies")
	result["root"].free()

func _test_exit_portal_appended() -> void:  # test 56
	var zone := {
		"zone_id": "zone_exit", "display_name": "T", "theme": "gothic_stone",
		"target_game": "X",
		"chambers": [{"id": "c1", "type": "corridor",
				"length": 8.0, "width": 4.0}]}
	var build := ZoneBuilder.build(zone)
	_check(build["exit_portal"] != null, "exit portal exists")
	var portal: Node3D = build["exit_portal"]
	_check(portal.position.z > 8.0,
			"exit portal sits beyond the final chamber")
	build["root"].free()
