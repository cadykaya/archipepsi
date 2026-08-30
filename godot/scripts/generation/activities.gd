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
## `occupied` is every world-space box already spoken for in this room --
## the room's own props and every activity placed before this one. The row
## solver used to know the room's DIMENSIONS and nothing about its
## CONTENTS, so two `target_challenge`s of the same size in one room got
## identical positions (c002 and c006 in Zone 1, measured), and elements
## landed inside theme props. Passing it in is the whole fix; nothing here
## special-cases a room.
static func build(root: Node3D, activity: Dictionary, theme: String,
		width: float, depth: float, room_id := "",
		activity_id := "", occupied: Array[AABB] = []) -> Dictionary:
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
			bool(rules["roles"]), occupied, runtime.ordered)
	if bool(rules["simultaneous"]):
		_link(runtime, built, theme)
	runtime.adopt(built)
	return {"kind": kind, "elements": built, "runtime": runtime,
			"footprints": _footprints(built, rules["size"] as Vector3)}

## A conduit joining consecutive pads, so a routing puzzle reads as ONE
## system rather than as loose floor furniture.
##
## The simultaneity rule is otherwise invisible: nothing about four
## separate pads says they have to be held together. A physical bus says
## it without a legend and without hue, which is the requirement.
static func _link(root: Node3D, built: Array[ActivityElement],
		theme: String) -> void:
	for i in built.size() - 1:
		var a := built[i].position
		var b := built[i + 1].position
		var span := b - a
		var length := Vector2(span.x, span.z).length()
		if length < 0.01:
			continue
		var conduit := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.07, length)
		conduit.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = ActivityElement.HARDWARE
		material.roughness = 1.0
		conduit.material_override = material
		conduit.position = (a + b) * 0.5 - Vector3(0.0, 0.02, 0.0)
		conduit.rotation.y = atan2(span.x, span.z)
		conduit.name = "Conduit_%d" % i
		root.add_child(conduit)

## Elements spread across the room's width, clear of the walking lane at
## both ends -- the same lane an affordance is kept out of, for the same
## reason: an activity element standing in the doorway is an activity
## element the player walks into on the way past.
## How many alternates the solver tries before it accepts a crowded spot.
const PLACEMENT_TRIES := 24
## Grid resolution for the last-resort sweep, per axis.
const GRID_STEPS := 9

static func _row(root: Node3D, kind: String, count: int, size: Vector3,
		theme: String, width: float, depth: float, height: float,
		trigger: String, roles: bool, occupied: Array[AABB],
		ordered: bool) -> Array[ActivityElement]:
	var built: Array[ActivityElement] = []
	var tint := VisualOwnership.separated_from_reserved(
			ThemeMaterials.light_color(theme))
	# The element's near EDGE clears the walking lane and its far EDGE
	# clears the wall -- the same rule `AffordanceFeatures._placement`
	# already solves, and for the same reason it had to: checking the
	# ORIGIN is what let a 4-metre row of switches reach 0.7 m through
	# the wall of a 12 m room.
	var half := size.x / 2.0
	var inner := AffordanceFeatures.LANE_HALF_WIDTH + half
	var outer := width / 2.0 - AffordanceFeatures.WALL_MARGIN - half
	# A room too narrow to hold the row at all keeps the lane clear and
	# gives up the wall margin, rather than the other way round: standing
	# in the doorway is worse than touching the wall.
	outer = maxf(inner, outer)
	var near := AffordanceFeatures.THRESHOLD_CLEARANCE + size.z / 2.0
	var far := maxf(near, depth - AffordanceFeatures.THRESHOLD_CLEARANCE
			- size.z / 2.0)
	var taken: Array[AABB] = occupied.duplicate()
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var side := -1.0 if i % 2 == 0 else 1.0
		var role := ActivityElement.ROLE_ELEMENT
		if roles:
			if i == 0:
				role = ActivityElement.ROLE_START
			elif i == count - 1:
				role = ActivityElement.ROLE_GOAL
		var spot := _free_spot(
				side * (inner + (outer - inner) * t),
				near + (far - near) * t,
				height, size, inner, outer, near, far, taken)
		var element := ActivityElement.create(
				trigger, i, size, tint, role, i + 1 if ordered else 0)
		root.add_child(element)
		element.position = spot
		taken.append(_footprint(spot, size))
		built.append(element)
	return built

## The first spot at or near the ideal one that nothing else has claimed.
##
## Deterministic: the alternates are walked in a fixed order with no RNG,
## so the same Zone lays out identically every time it is built -- which
## the whole reproducible-baseline apparatus depends on.
##
## If every alternate is taken it returns the IDEAL spot rather than
## dropping the element. A crowded activity is a finding the real-Zone
## audit reports; a missing one is a puzzle that cannot be solved.
static func _free_spot(ideal_x: float, ideal_z: float, height: float,
		size: Vector3, inner: float, outer: float, near: float,
		far: float, taken: Array[AABB]) -> Vector3:
	var ideal := Vector3(ideal_x, height, ideal_z)
	if not _collides(ideal, size, taken):
		return ideal
	var side := signf(ideal_x)
	if side == 0.0:
		side = 1.0
	var step := maxf(size.z, 0.8)
	for attempt in PLACEMENT_TRIES:
		# Alternate along the room's length first -- that is where the
		# space is -- then across it, then on the opposite wall.
		var rings := attempt / 4 + 1
		var pattern := attempt % 4
		var x := ideal_x
		var z := ideal_z
		match pattern:
			0: z = ideal_z + step * rings
			1: z = ideal_z - step * rings
			2: x = side * clampf(absf(ideal_x) - 0.9 * rings, inner, outer)
			_: x = -side * clampf(absf(ideal_x), inner, outer)
		z = clampf(z, near, far)
		var candidate := Vector3(x, height, z)
		if not _collides(candidate, size, taken):
			return candidate

	# Last resort: sweep the whole legal band on a coarse grid, nearest
	# to the ideal first. The ring pattern above walks outward from one
	# spot and can miss a free pocket on the far side, which is what a
	# small arena with five plate-sized footprints turned out to be. Still
	# deterministic, and still inside the same lane and wall clearances --
	# the constraints do not move, the search gets better.
	var best := ideal
	var best_distance := INF
	var found := false
	for xi in GRID_STEPS:
		for zi in GRID_STEPS:
			for mirror: float in [1.0, -1.0]:
				var gx := mirror * lerpf(inner, outer,
						float(xi) / float(GRID_STEPS - 1))
				var gz := lerpf(near, far, float(zi) / float(GRID_STEPS - 1))
				var candidate := Vector3(gx, height, gz)
				if _collides(candidate, size, taken):
					continue
				var away := candidate.distance_to(ideal)
				if away < best_distance:
					best_distance = away
					best = candidate
					found = true
	if found:
		return best
	return ideal

static func _collides(at: Vector3, size: Vector3,
		taken: Array[AABB]) -> bool:
	var box := _footprint(at, size)
	for other in taken:
		if box.intersects(other):
			return true
	return false

## What this activity claimed, in room space, for the next one to avoid.
static func _footprints(built: Array[ActivityElement],
		size: Vector3) -> Array[AABB]:
	var out: Array[AABB] = []
	for element in built:
		out.append(_footprint(element.position, size))
	return out

## The space an element claims, a little wider than its mesh so two
## elements do not merely touch.
static func _footprint(at: Vector3, size: Vector3) -> AABB:
	var pad := Vector3(0.35, 0.2, 0.35)
	var full := size + pad * 2.0
	return AABB(at - full * 0.5, full)
