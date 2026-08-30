class_name Activities
## The graybox activity vocabulary (CAMPAIGN_SCALE.md 9).
##
## Four composable families, built from primitives the base kit can
## already beat: a switch is touched, a target is shot with Static Pulse,
## a plate is stood on, a timed run is run.
##
## This file used to place a row of `StaticBody3D` boxes and stop. It was
## honest graybox GEOMETRY and it was not gameplay: nothing anywhere in
## the client read the four kinds, so 57.7% of the played Zone's content
## value was glowing scenery. It now builds `ActivityElement`s and hands
## them to one `ActivityRuntime`, which owns every rule.
##
## `test_activity_coverage` reads this file and refuses any kind in the
## schema with no branch here. That test proves a branch EXISTS; it cannot
## see whether the branch produces something inert, which is exactly how
## the inert version survived. `godot/tests/test_activities.gd` is the
## half that drives each family to completion.
##
## An activity may now REQUIRE a semantic capability (owner ruling,
## 2026-08-30) — but nothing here decides that. The bridge has already
## refused any requirement it could not prove the campaign can satisfy,
## and `ActivityRuntime` renders what is left.

## Build one activity into `root`, returning what it made.
##
## `activity_id` is stable per Zone so a completed activity's local reward
## is the same note however many times it is solved.
static func build(root: Node3D, activity: Dictionary, theme: String,
		width: float, depth: float, room_id := "",
		activity_id := "") -> Dictionary:
	var kind := str(activity.get("kind", ""))
	if not ActivityRuntime.RULES.has(kind):
		push_error("no builder for activity kind '%s'" % kind)
		return {"kind": kind, "elements": [], "runtime": null}

	var runtime := ActivityRuntime.create(
			activity, room_id,
			activity_id if activity_id != "" else "%s_%s" % [room_id, kind])
	root.add_child(runtime)

	var rules := runtime.rules()
	var built := _row(runtime, runtime.kind, runtime.placed_count(),
			rules["size"] as Vector3, theme, width, depth,
			float(rules["height"]), str(rules["trigger"]),
			bool(rules["roles"]))
	runtime.adopt(built)
	return {"kind": kind, "elements": built, "runtime": runtime}

## Elements spread across the room's width, clear of the walking lane at
## both ends -- the same lane an affordance is kept out of, for the same
## reason: an activity element standing in the doorway is an activity
## element the player walks into on the way past.
static func _row(root: Node3D, kind: String, count: int, size: Vector3,
		theme: String, width: float, depth: float, height: float,
		trigger: String, roles: bool) -> Array[ActivityElement]:
	var built: Array[ActivityElement] = []
	var usable := maxf(1.0, width - 2.0 * AffordanceFeatures.LANE_HALF_WIDTH
			- size.x)
	var tint := ThemeMaterials.light_color(theme)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (AffordanceFeatures.LANE_HALF_WIDTH + size.x / 2.0
				+ usable * 0.5 * t)
		var z := depth * (0.25 + 0.5 * t)
		var role := ActivityElement.ROLE_ELEMENT
		if roles:
			if i == 0:
				role = ActivityElement.ROLE_START
			elif i == count - 1:
				role = ActivityElement.ROLE_GOAL
		var element := ActivityElement.create(trigger, i, size, tint, role)
		root.add_child(element)
		element.position = Vector3(x, height, z)
		built.append(element)
	return built
