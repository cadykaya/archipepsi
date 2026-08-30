extends Node
## Headless builder tests (ACCEPTANCE_TESTS §5: 50–56).
## Run: `make godot-test` (boots the project with `--chamber-test`).
##
## This was a `--script` SceneTree run until S9. It stopped being one when
## chambers gained affordance features: a chamber now builds nodes that
## reach the player, and the player reaches `BridgeClient`, so the whole
## dependency chain fails to compile in a run that never instantiates the
## autoloads. The symptom was the one the Makefile guard exists for — the
## suite printed OK having loaded nothing at all.
##
## The geometry itself still needs no tree: every test builds a chamber,
## measures it and frees it, exactly as before.

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	_test_corridor()
	_test_arena()
	_test_chaining_no_overlap()
	_test_bent_layouts_never_overlap()
	_test_props_leave_a_walkable_lane()
	_test_a_brute_fits_through_a_doorway()
	_test_secrets_are_optional()
	_test_secrets_reach_the_vertical_chambers()
	_test_platform_path_bounds()
	_test_tower_route()
	_test_treasure_room()
	_test_exit_portal_appended()
	await _test_every_chamber_is_sealed()
	await _test_no_chamber_leaks_off_its_centre_line()
	_test_light_fixtures_are_not_buried()
	_test_playtime_measures_what_it_claims()
	_test_playtime_is_silent_about_a_zone_nobody_played()
	if failures == 0:
		print("GODOT CHAMBER TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT CHAMBER TESTS: %d failures" % failures)
		get_tree().quit(1)

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
					# ...and neither is a DOORWAY. A corridor gained end
					# walls when playtest 2.5 found it open at both
					# mouths, and their jambs sit at |x| = DOOR_WIDTH / 2
					# -- inside a 2.6 lane, because DOOR_WIDTH is 2.4.
					# That is not this test choking on a prop, it is the
					# door every other chamber type has always had; the
					# next test pins what it costs. This one is about
					# props, which is why floor, ceiling and side wall
					# are already exempt.
					if box.get_center().z <= ChamberBuilders.WALL_THICKNESS 							or box.get_center().z >= 30.0 							- ChamberBuilders.WALL_THICKNESS:
						continue          # end wall / doorway jamb
					var intrudes: bool = box.position.x < lane / 2.0 \
							and box.position.x + box.size.x > -lane / 2.0
					_check(not intrudes,
							"%s w=%.0f: a prop blocks the %.1fm lane at x=%.2f"
							% [theme, width, lane, box.get_center().x])
				result["root"].free()

func _test_secrets_are_optional() -> void:
	## Optional ledges (DESIGN §19). Three things have to hold at once:
	## they must actually appear, they must be out of reach from the floor,
	## and they must never carry anything the run needs — a secret holding
	## a reward or an exit would be the mandatory Echo gate the design
	## forbids outright.
	var reach: float = Constants.JUMP_APEX_HEIGHT + 0.4
	var lip_min: float = ChamberBuilders.SECRET_LIP_MIN
	var underside_min: float = ChamberBuilders.SECRET_UNDERSIDE_MIN
	var found := 0
	var cramped := 0
	var at_the_floor := 0
	# The interesting ledge is the one pinned to SECRET_LIP_MIN, because
	# that is where it comes closest to the actors walking underneath it. A
	# coarse sweep missed it entirely: only wall_height 5.0 could produce
	# one, and the three seeds that reached 5.0 all failed the 34% roll, so
	# the minimum-lip branch was never built and the lip assertions below
	# were decorative. Sweep the legal range finely instead.
	for seed_index in 240:
		var width := 10.0 + float(seed_index % 5) * 4.0
		var depth := 12.0 + float(seed_index % 3) * 6.0
		# Every legal wall_height, 4 m to 8 m in 0.25 m steps.
		var wall_height := 4.0 + float(seed_index % 17) * 0.25
		var result := ChamberBuilders.arena(
				{"id": "secret_%03d" % seed_index, "type": "arena",
				"width": width, "depth": depth, "wall_height": wall_height,
				"objective": "reach_reward",
				"reward_location_id": 89100001,
				"enemies": [{"archetype": "melee", "count": 2}]},
				"concrete_facility")
		var ledges := 0
		for box: AABB in _collidable_boxes(result["root"]):
			# Perimeter walls reach the floor and door lintels sit on the
			# z faces; only interior geometry starting above head height
			# can be a ledge.
			var center := box.get_center()
			if center.z < 1.0 or center.z > depth - 1.0:
				continue
			if box.position.y <= reach:
				continue
			# ...and the CEILING, which is interior and above head height
			# and is not a ledge. It spans the whole room; a secret shelf
			# is a shelf. This list of exceptions is the cost of finding
			# ledges by shape instead of by name, and it grew the moment
			# `_perimeter` learned to roof itself.
			if box.size.x >= width - 0.5 and box.size.z >= depth - 0.5:
				continue
			ledges += 1
			found += 1
			var lip := box.position.y + box.size.y
			_check(lip >= lip_min - 0.001,
					"secret ledge lip at %.2f is under SECRET_LIP_MIN" % lip)
			if lip <= lip_min + 0.001:
				at_the_floor += 1
			# The one that actually bit: a slab whose UNDERSIDE sits at the
			# brute's collider height is not a ledge, it is a wall the
			# brute walks into and stops at.
			_check(box.position.y >= underside_min - 0.001,
					"secret ledge underside at %.2f blocks a %.1f m actor"
						% [box.position.y, ChamberBuilders.TALLEST_ACTOR])
			_check(lip + Constants.PLAYER_HEIGHT <= wall_height,
					"secret lip %.2f leaves no standing room under %.1f m"
						% [lip, wall_height])
			_check(absf(center.x) - box.size.x / 2.0
						>= ChamberBuilders.DOOR_WIDTH / 2.0,
					"secret ledge overhangs the door lane at x=%.2f"
						% center.x)
			if wall_height < 5.0:
				cramped += 1
		# One trigger per ledge, and it is a sensor, not an obstacle.
		var triggers := 0
		for child in result["root"].get_children():
			if not child.is_in_group(ChamberBuilders.SECRET_GROUP):
				continue
			triggers += 1
			_check(child is Area3D and not (child is PhysicsBody3D),
					"a secret trigger senses rather than blocks")
		_check(triggers == ledges,
				"%d secret ledges but %d triggers" % [ledges, triggers])
		# Nothing the run needs ever rides up there.
		_check(result["exit_offset"] == Vector3(0, 0, depth),
				"a secret never moves the arena exit")
		_check(absf(result["reward_position"].y) < 0.01,
				"a secret never lifts the reward off the floor")
		for spawn: Dictionary in result["enemy_spawns"]:
			_check(spawn["position"].y < reach,
					"a secret never strands an enemy out of reach")
		result["root"].free()
	_check(found > 0, "arenas grow secret ledges (%d across the sweep)" % found)
	_check(at_the_floor > 0,
			"the sweep builds the minimum-lip ledge, not just roomy ones")
	_check(cramped == 0, "a low arena got a secret it has no headroom for")

## The two chamber types that always had the vertical room and never got a
## secret. Both put theirs over the highest FLAT GROUND in the chamber —
## the platform_path's end ledge, the tower's top deck — which is the same
## argument the arena makes, applied to a floor that is not at zero.
##
## The measurement that matters is the lip's height ABOVE THAT FLOOR: an
## alcove measured from absolute zero in a chamber whose floor is at
## `rise` lands below the player, which is a step rather than a secret.
func _test_secrets_reach_the_vertical_chambers() -> void:
	var reach: float = Constants.JUMP_APEX_HEIGHT + 0.4
	var lip_min: float = ChamberBuilders.SECRET_LIP_MIN
	var paths := 0
	var towers := 0
	for seed_index in 60:
		var step := 0.25 + float(seed_index % 4) * 0.25
		var path := ChamberBuilders.platform_path(
				{"id": "path_%03d" % seed_index, "type": "platform_path",
				"segment_count": 3 + seed_index % 6,
				"gap_size": minf(2.0, Constants.max_safe_gap(step)),
				"vertical_step": step,
				"objective": "platform_to_goal"}, "concrete_facility")
		var rise: float = step * float(3 + seed_index % 6)
		paths += _count_secrets_above(path, rise, lip_min, reach,
				"platform_path")
		path["root"].free()

		var tower := ChamberBuilders.tower(
				{"id": "tower_%03d" % seed_index, "type": "tower",
				"floors": 2 + seed_index % 4, "objective": "reach_reward",
				"enemies": []}, "concrete_facility")
		# The top deck's height is the tower's own summit, which is what
		# `exit_offset` already reports.
		towers += _count_secrets_above(tower, tower["exit_offset"].y, lip_min,
				reach, "tower")
		tower["root"].free()
	_check(paths > 0, "platform_paths grow secrets (%d)" % paths)
	_check(towers > 0, "towers grow secrets (%d)" % towers)

## Secret triggers above `floor_y`, checking each is genuinely out of reach
## FROM that floor and that nothing the run needs went up with it.
func _count_secrets_above(result: Dictionary, floor_y: float,
		lip_min: float, reach: float, what: String) -> int:
	var found := 0
	for child in result["root"].get_children():
		if not child.is_in_group(ChamberBuilders.SECRET_GROUP):
			continue
		found += 1
		var above := (child as Node3D).position.y - floor_y
		_check(above > reach,
				"a %s secret sits %.2fm over its floor — a base jump reaches "
					% [what, above] + "%.2fm, so that is a step" % reach)
		_check(above >= lip_min - 1.5,
				"a %s secret at %.2fm over its floor is not the alcove"
					% [what, above])
	# Nothing the run needs rides up with it.
	if found > 0:
		_check(absf(result["reward_position"].y - floor_y) < 2.5,
				"a %s secret never lifts the reward to itself" % what)
		for spawn: Dictionary in result["enemy_spawns"]:
			_check(spawn["position"].y - floor_y < reach,
					"a %s secret never strands an enemy out of reach" % what)
	return found

func _test_platform_path_bounds() -> void:  # test 53
	# Every legal parameter combination stays within the derived bound.
	for segments in range(3, 9):
		for step_index in range(0, 11):
			var step := float(Constants.MAX_VERTICAL_STEP) \
					* float(step_index) / 10.0
			var allowed := Constants.max_safe_gap(step)
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

		# The ascent itself. `platform_path` has had its gaps bounded by
		# the schema since v0.4; the tower's spiral is placed here, where
		# nothing measured it, and it asked for 2.4 m at a 1.0 m rise
		# against a bound of 2.0 -- the engine breaking a rule it imposes
		# on Epsilon. Measured off the built positions, not inferred, so
		# a change to the spiral cannot slip past.
		var platforms: Array = result.get("platforms", [])
		_check(not platforms.is_empty(),
				"the tower reports its ascent (floors=%d)" % floors)
		# The first platform is reached from the floor DIRECTLY BENEATH
		# it -- the entry slab spans the whole footprint, so the player
		# walks under it and jumps straight up. Starting from a guessed
		# floor position instead measures a walk as though it were a
		# jump, which is how the first version of this check reported a
		# 4.74 m leap that nobody has to make.
		var first: Vector3 = platforms[0]
		var previous := Vector3(first.x, 0.0, first.z)
		for platform: Vector3 in platforms:
			var rise_to := platform.y - previous.y
			var flat := Vector2(platform.x - previous.x,
					platform.z - previous.z).length()
			var allowed := Constants.max_safe_gap(maxf(rise_to, 0.0))
			_check(flat <= allowed + 0.001,
					("tower jump of %.2f m at a %.2f m rise exceeds the "
					% [flat, rise_to])
					+ "base kit's safe reach of %.2f m (floors=%d)"
					% [allowed, floors])
			_check(rise_to <= Constants.MAX_VERTICAL_STEP + 0.001,
					"tower step of %.2f m exceeds MAX_VERTICAL_STEP"
					% rise_to)
			previous = platform
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

## Can the player leave the level? (`make godot-test`)
##
## Playtest 2 found a room with a bounce pad and two of its four walls,
## and used the one to get out through the other. Only three of the six
## chamber builders call `_perimeter`; `corridor`, `platform_path` and
## `corner` each raise their own walls, and a wall nobody raises is not a
## wall anybody notices missing -- the bounds Dictionary still says the
## right thing, the exit socket is still in the right place, and every
## existing assertion passes.
##
## So this stands INSIDE each archetype and fires rays outward. Sideways
## and upward must be stopped. Forward and back are the doorways and are
## allowed through.
func _test_every_chamber_is_sealed() -> void:  # test 57
	var world := Node3D.new()
	add_child(world)
	var cases := {
		"corridor": ChamberBuilders.corridor(
				{"length": 12.0, "width": 5.0}, "concrete_facility"),
		"arena": ChamberBuilders.arena(
				{"width": 18.0, "depth": 16.0}, "concrete_facility"),
		"platform_path": ChamberBuilders.platform_path(
				{"width": 12.0, "length": 20.0, "gap_size": 1.6,
				"platform_count": 4, "vertical_step": 0.8},
				"concrete_facility"),
		"treasure_room": ChamberBuilders.treasure_room(
				{}, "concrete_facility"),
		# Art requirement 19: normal room shells are ENCLOSED BY DEFAULT,
		# towers included. The tower was one of the two that used to be
		# open, and it was missing from this suite -- so the fix held by
		# luck rather than by test.
		"tower": ChamberBuilders.tower({"floors": 3}, "concrete_facility"),
		"tower_tall": ChamberBuilders.tower({"floors": 6},
				"concrete_facility"),
		"corner_left": ChamberBuilders.corner(-1, "concrete_facility"),
		"corner_right": ChamberBuilders.corner(1, "concrete_facility"),
		# Extremes of the schema, because a wall that seals at the
		# default width can still miss at the widest one.
		"corridor_widest": ChamberBuilders.corridor(
				{"length": 30.0, "width": 10.0}, "concrete_facility"),
		"corridor_narrowest": ChamberBuilders.corridor(
				{"length": 6.0, "width": 4.0}, "concrete_facility"),
		"arena_widest": ChamberBuilders.arena(
				{"width": 28.0, "depth": 28.0}, "concrete_facility"),
		"platform_path_long": ChamberBuilders.platform_path(
				{"width": 12.0, "length": 30.0, "gap_size": 2.0,
				"segment_count": 8, "vertical_step": 1.0},
				"concrete_facility"),
	}
	# Spread far apart. Built at the origin they overlap, and a ray
	# leaving one chamber lands in another's wall -- so the suite passes
	# by borrowing geometry the player would never be standing in. That
	# is not a hypothetical: deleting platform_path's ceiling failed the
	# ARENA, which had been leaning on it.
	var lane := 0
	var spread := 400.0
	for name: String in cases:
		var result: Dictionary = cases[name]
		var root: Node3D = result["root"]
		root.position = Vector3(float(lane) * spread, 0.0, 0.0)
		lane += 1
		world.add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space := world.get_world_3d().direct_space_state
	for name: String in cases:
		var result: Dictionary = cases[name]
		var bounds: AABB = result["bounds"]
		var root: Node3D = result["root"]
		var centre := bounds.get_center() + root.position
		# Chest height, and again high enough that a bounce pad reaches.
		for eye_y: float in [centre.y, bounds.position.y + bounds.size.y * 0.8]:
			var from := Vector3(centre.x, eye_y, centre.z)
			# A corner LEAVES through its side, so the direction of its
			# own exit is a doorway rather than a hole. Everything else
			# has to stop you.
			var exit_dir: Vector3 = (result["exit_offset"] as Vector3)
			exit_dir.y = 0.0
			for dir: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.UP]:
				if exit_dir.length() > 0.01 \
						and dir.dot(exit_dir.normalized()) > 0.5:
					continue
				var reach: float = bounds.size.length() + 4.0
				var probe := PhysicsRayQueryParameters3D.create(
						from, from + dir * reach)
				_check(not space.intersect_ray(probe).is_empty(),
						"%s has no surface %s of its centre at y=%.1f: "
						% [name, dir, eye_y]
						+ "the player leaves the level through it")
	world.queue_free()

## No light fixture may sit inside the geometry it hangs from.
##
## The arena puts its lamps at `height - 0.3` and the fixture used to be
## raised 0.15 ABOVE that, which placed it inside the ceiling slab with
## its faces exactly coplanar -- the shimmer along the ceiling strips in
## playtest 2. Coincident faces are the whole of z-fighting: two surfaces
## at the same depth, and the renderer picking per pixel.
func _test_light_fixtures_are_not_buried() -> void:  # test 58
	var cases := {
		"arena": ChamberBuilders.arena(
				{"width": 18.0, "depth": 16.0, "wall_height": 5.0},
				"concrete_facility"),
		"corridor": ChamberBuilders.corridor(
				{"length": 16.0, "width": 6.0}, "concrete_facility"),
		"platform_path": ChamberBuilders.platform_path(
				{"width": 12.0, "length": 20.0, "gap_size": 1.6,
				"segment_count": 4, "vertical_step": 0.8},
				"concrete_facility"),
		"treasure_room": ChamberBuilders.treasure_room(
				{}, "concrete_facility"),
	}
	var checked := 0
	for name: String in cases:
		var result: Dictionary = cases[name]
		var root: Node3D = result["root"]
		var solids: Array[AABB] = _collidable_boxes(root)
		for box: AABB in _fixture_boxes(root):
			checked += 1
			for solid: AABB in solids:
				_check(not box.intersects(solid),
						"%s buries a light fixture at %.2v in geometry "
						% [name, box.get_center()]
						+ "at %.2v -- coplanar faces shimmer" % solid.position)
		root.free()
	_check(checked >= 4,
			"only %d light fixtures found; this suite would pass on a "
			% checked + "level with no lights in it")

## Every light fixture's mesh, as an AABB in the chamber's own space.
##
## `_light` names the housing "LightFixture" whether it built the
## procedural box itself or instantiated an authored scene. The two are
## not the same SHAPE of node: the procedural fixture IS a
## MeshInstance3D, and an authored housing is a Node3D whose meshes are
## children of it.
##
## So a detector that demanded `is MeshInstance3D` on the named node
## found the procedural fixture and, the moment real art arrived through
## the seam, silently found NOTHING -- and a buried-fixture test that
## inspects zero fixtures passes every time. That is exactly what the
## `checked >= 4` guard below is for, and it is what caught this.
##
## Descending also means the check now covers the AUTHORED housings,
## which is the version that matters: they are larger than the 0.8 x 0.1
## x 0.4 slab they replace, so they have more room to reach the ceiling.
func _fixture_boxes(root: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	for child in root.get_children():
		if not (child is Node3D):
			continue
		if not child.name.begins_with("LightFixture"):
			continue
		var node := child as Node3D
		_collect_fixture_meshes(node, node.transform, out)
	return out

func _collect_fixture_meshes(node: Node3D, xform: Transform3D,
		out: Array[AABB]) -> void:
	if node is MeshInstance3D:
		out.append(xform * (node as MeshInstance3D).get_aabb())
	for sub in node.get_children():
		if sub is Node3D:
			var child := sub as Node3D
			_collect_fixture_meshes(child, xform * child.transform, out)


## CAMPAIGN_SCALE.md 13. The forty-minute Zone is a TARGET; this is the
## only thing that can make it a measurement, so what it reports has to
## be what happened.
func _test_playtime_measures_what_it_claims() -> void:
	var log := PlaytimeLog.new()
	log.begin(3)
	log.enter_chamber(0)
	for i in 60:
		log.tick(0.1)                       # 6s in the first room
	log.enter_chamber(2)
	for i in 100:
		log.tick(0.1)                       # 10s in the third
	# A fight: engaged with two alive, ends when the last one dies.
	log.note_engagement(2)
	for i in 40:
		log.tick(0.1)
	log.note_enemy_died(1)
	log.note_enemy_died(0)
	log.note_check_confirmed()
	log.note_death()

	var intent: Dictionary = log.to_intent("zone_001", true)
	_check(intent.get("type") == "zone_timing", "not a zone_timing intent")
	_check(absf(float(intent["elapsed_seconds"]) - 20.0) < 0.05,
			"elapsed reported %s, not 20s" % intent["elapsed_seconds"])
	_check(int(intent["deaths"]) == 1, "deaths not counted")
	_check(int(intent["checks_completed"]) == 1, "Checks not counted")
	var dwell: Array = intent["dwell"]
	_check(dwell.size() == 3,
			"one entry per chamber; got %d" % dwell.size())
	_check(absf(float(dwell[0]["seconds"]) - 6.0) < 0.05,
			"room 0 dwell reported %s, not 6s" % dwell[0]["seconds"])
	_check(float(dwell[1]["seconds"]) == 0.0,
			"a room nobody entered reported time in it")
	# 10s in room 2 up to the fight, then 4s of fighting.
	_check(absf(float(dwell[2]["seconds"]) - 14.0) < 0.05,
			"room 2 dwell reported %s, not 14s" % dwell[2]["seconds"])
	var encounters: Array = intent["encounter_seconds"]
	_check(encounters.size() == 1,
			"a fight from first engagement to last kill is ONE encounter; "
			+ "got %d" % encounters.size())
	_check(absf(float(encounters[0]) - 4.0) < 0.05,
			"encounter reported %s, not 4s" % encounters[0])
	_check(bool(intent["completed"]), "completed flag lost")

func _test_playtime_is_silent_about_a_zone_nobody_played() -> void:
	var log := PlaytimeLog.new()
	log.begin(4)
	_check(log.to_intent("zone_001", true).is_empty(),
			"a Zone with no elapsed time still reported a measurement")
	log.tick(1.0)
	_check(log.to_intent("", true).is_empty(),
			"a timing was reported for no Zone at all")
	# ...and a death mid-fight does not report the respawn walk as combat.
	log.note_engagement(2)
	log.tick(3.0)
	log.note_death()
	log.tick(30.0)
	log.note_enemy_died(0)
	_check(log.to_intent("zone_001", false)["encounter_seconds"].is_empty(),
			"a fight the player died in was reported as a long encounter")

## The same question as test 57, asked from more than one place.
##
## Test 57 probes from the chamber's CENTRE, in three directions. That
## was enough for the bug it was written for -- a missing ceiling and two
## missing end walls are visible from anywhere in the room -- and it is a
## guard shaped exactly like its own fix. A hole that is not on the
## centre line is invisible to it, and playtest 2.5 walked into one while
## test 57 was green.
##
## So this stands at 81 positions across the floor, at two heights, and
## looks in all four horizontal directions. Only the doorways are
## licensed, and licensed narrowly: `_end_wall` raises solid full-height
## slabs either side of a DOOR_WIDTH gap, so an escape wider than half a
## door from the door's own centre line is a hole at ANY height, and a
## sideways escape is one unless that chamber's exit actually goes
## sideways at that point along its length.
func _test_no_chamber_leaks_off_its_centre_line() -> void:
	var world := Node3D.new()
	add_child(world)
	var cases := {
		"corridor": ChamberBuilders.corridor(
				{"length": 12.0, "width": 5.0}, "concrete_facility"),
		"corridor_widest": ChamberBuilders.corridor(
				{"length": 30.0, "width": 10.0}, "concrete_facility"),
		"corridor_narrowest": ChamberBuilders.corridor(
				{"length": 6.0, "width": 4.0}, "concrete_facility"),
		"arena": ChamberBuilders.arena(
				{"width": 18.0, "depth": 16.0}, "concrete_facility"),
		"arena_widest": ChamberBuilders.arena(
				{"width": 28.0, "depth": 28.0}, "concrete_facility"),
		"platform_path": ChamberBuilders.platform_path(
				{"width": 12.0, "length": 20.0, "gap_size": 1.6,
				"platform_count": 4, "vertical_step": 0.8},
				"concrete_facility"),
		"treasure_room": ChamberBuilders.treasure_room(
				{}, "concrete_facility"),
		"tower": ChamberBuilders.tower({"floors": 3}, "concrete_facility"),
		"corner_left": ChamberBuilders.corner(-1, "concrete_facility"),
		"corner_right": ChamberBuilders.corner(1, "concrete_facility"),
	}
	# The tower's declared bounds run 2.2 m PAST its shaft: the last of
	# that is the bridge strip the climb leaves on, which is outside the
	# back wall by design and open on both sides on purpose. Probing it
	# would be asking why the outdoors has no walls.
	var interior_depth := {"tower": 12.0}

	var lane := 0
	for name: String in cases:
		var root: Node3D = (cases[name] as Dictionary)["root"]
		root.position = Vector3(float(lane) * 400.0, 0.0, 0.0)
		lane += 1
		world.add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space := world.get_world_3d().direct_space_state
	var half_door: float = ChamberBuilders.DOOR_WIDTH / 2.0 + 0.05
	for name: String in cases:
		var result: Dictionary = cases[name]
		var bounds: AABB = result["bounds"]
		var origin: Vector3 = (result["root"] as Node3D).position
		var exit_offset: Vector3 = result["exit_offset"]
		# Inset off the walls, and measured UP FROM THE FLOOR. The AABB
		# bottom is under the floor slab -- forty metres under it for a
		# platform_path, whose kill volume is part of its bounds -- so
		# sampling from `bounds.position.y` stands the probe in dirt and
		# every ray escapes for the most boring possible reason.
		var inset := 0.7
		var x0: float = bounds.position.x + inset
		var x1: float = bounds.position.x + bounds.size.x - inset
		var z0: float = bounds.position.z + inset
		var z1: float = bounds.position.z + float(interior_depth.get(
				name, bounds.size.z)) - inset
		var top: float = bounds.position.y + bounds.size.y
		var escapes := 0
		var worst := ""
		for fx in range(0, 9):
			for fz in range(0, 9):
				var local := Vector3(
						lerpf(x0, x1, float(fx) / 8.0), 0.0,
						lerpf(z0, z1, float(fz) / 8.0))
				for eye: float in [0.9, 2.4]:
					local.y = eye
					if local.y > top - 0.2:
						continue
					for dir: Vector3 in [Vector3.LEFT, Vector3.RIGHT,
							Vector3.FORWARD, Vector3.BACK]:
						if _is_a_doorway(dir, local, exit_offset, half_door):
							continue
						var from := origin + local
						var probe := PhysicsRayQueryParameters3D.create(
								from, from + dir * 200.0)
						if not space.intersect_ray(probe).is_empty():
							continue
						escapes += 1
						if worst == "":
							worst = "standing at (%.1f, %.1f, %.1f) " \
									% [local.x, local.y, local.z] \
									+ "looking %s" % dir
		_check(escapes == 0,
				"%s has %d sightlines out of the level that are not "
				% [name, escapes] + "doorways: %s" % worst)
	world.queue_free()

## Whether an escape in `dir` from `local` goes out a door rather than
## through a wall that should be there. The end walls carry their gap at
## x = 0; a sideways exit carries its gap at the exit's own z.
func _is_a_doorway(dir: Vector3, local: Vector3, exit_offset: Vector3,
		half_door: float) -> bool:
	if absf(dir.z) > 0.5:
		return absf(local.x) <= half_door
	if absf(exit_offset.x) < 0.01 or dir.x * exit_offset.x <= 0.0:
		return false          # nothing leaves sideways here
	return absf(local.z - exit_offset.z) <= half_door


## What a doorway costs, stated rather than assumed.
##
## DOOR_WIDTH is 2.4 and BRUTE_LANE is 2.6, so no doorway in this game
## has ever satisfied the lane budget -- not the arena's, not the
## tower's, not the treasure room's. Nothing noticed until a corridor
## grew ends, because the lane test only ever ran on the one chamber type
## with no doors in it.
##
## The resolution is that BRUTE_LANE is a PROP budget (1.8 m brute plus
## 0.4 of margin either side) and a doorway is a designed narrowing that
## the brute still passes: 2.4 against 1.8 leaves 0.3 a side. That is the
## claim, so it is a test. Widen the brute past a door and this fails
## here, with the reason, instead of failing as a stuck enemy.
func _test_a_brute_fits_through_a_doorway() -> void:
	var envelope: Dictionary = Constants.ENEMY_ENVELOPES["brute"]
	var brute: float = float((envelope["size"] as Vector3).x)
	var door: float = ChamberBuilders.DOOR_WIDTH
	_check(brute < door,
			"the brute is %.1f m wide and a doorway is %.1f: it cannot "
			% [brute, door] + "leave the room it spawned in")
	_check(door < ChamberBuilders.BRUTE_LANE,
			"DOOR_WIDTH %.1f now meets BRUTE_LANE %.1f, so the prop test "
			% [door, ChamberBuilders.BRUTE_LANE]
			+ "no longer needs to exempt doorway jambs -- drop the exemption")
	print("chambers: doorway %.1f m, brute %.1f m, clearance %.2f a side"
			% [door, brute, (door - brute) / 2.0])
