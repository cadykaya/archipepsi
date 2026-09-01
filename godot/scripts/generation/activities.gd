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
		activity_id := "", occupied: Array[AABB] = [],
		surfaces: Array = []) -> Dictionary:
	var kind := str(activity.get("kind", ""))
	if not ActivityRuntime.RULES.has(kind):
		push_error("no builder for activity kind '%s'" % kind)
		return {"kind": kind, "elements": [], "runtime": null}

	var runtime := ActivityRuntime.create(
			activity, room_id,
			activity_id if activity_id != "" else "%s_%s" % [room_id, kind])
	root.add_child(runtime)

	var rules := runtime.rules()
	# WHAT IS PHYSICALLY THERE, derived once from the chamber root these
	# elements are about to join. `occupied` is the OCCUPANCY question --
	# furniture-scale solids plus the builder's reserved regions -- and it
	# deliberately cannot see room-scale architecture. Clearance is a
	# different question about the same room: what is OVER the spot. A
	# deck 2.0 m above a walkway is invisible to one and decisive to the
	# other.
	#
	# Derived HERE rather than passed in, because a caller that forgets an
	# argument gets a composer that places blind, and this is the argument
	# every existing caller would have forgotten.
	var solids := ChamberBuilders.all_solid_boxes(root)
	var built := _row(runtime, runtime.kind, runtime.placed_count(),
			rules["size"] as Vector3, theme, width, depth,
			float(rules["height"]), str(rules["trigger"]),
			bool(rules["roles"]), occupied, runtime.ordered, surfaces,
			solids)
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
		ordered: bool, surfaces: Array = [],
		solids: Array[AABB] = []) -> Array[ActivityElement]:
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
	# WHERE THERE IS FLOOR, when the builder has said. Everything above
	# solves against the room's WIDTH and DEPTH, which presumes a room
	# has a floor across them -- true of an arena and false of a
	# `platform_path`, where the space between the islands is a kill pit
	# and the bounds reach forty metres down. Chosen ONCE for the whole
	# activity, so a routing circuit stays on one island rather than
	# being split across a jump course nobody can cross inside the hold
	# window.
	var surface := _best_surface(surfaces, size, height, taken, solids)
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
		if not surface.is_empty():
			# THE OFFER MAY BE DECLINED. A surface that cannot produce a
			# physically valid point for THIS element is not used for it,
			# and the flat solve stands -- an element is never forced into
			# geometry to honour an offer.
			var on := _spot_on_surface(surface, surfaces, size, height,
					taken, solids)
			if bool(on.get("found", false)):
				spot = on["position"]
		var element := ActivityElement.create(
				trigger, i, size, tint, role, i + 1 if ordered else 0)
		root.add_child(element)
		element.position = spot
		taken.append(_footprint(spot, size))
		built.append(element)
	return built

## The vouched surface with the most room left on it, or {} if the room
## offered none this element can legally sit on.
##
## "Legally" is a measurement, not a list: what is left beside the
## element on its better axis has to be at least `BRUTE_LANE`, the width
## the game already uses for "the widest actor still gets past". It says
## what a `platform_path`'s 2.5 m islands are -- the MANDATORY ROUTE over
## a kill pit, with no way past a plate on one -- without naming
## platforms anywhere, so a builder that one day makes a wide island gets
## a usable one.
##
## DEFENCE IN DEPTH, recorded as such rather than dressed up. Sabotaging
## this test alone does not put an element on an island: the surface with
## the most room wins, and a ledge always has more than an island, right
## down to the crowded last resort. What is load bearing is that
## preference plus the room suite's assertion that nothing sits on an
## island at the largest room the schema admits. This is what keeps the
## rule true if that ordering is ever changed.
static func _best_surface(surfaces: Array, size: Vector3, height: float,
		taken: Array[AABB], solids: Array[AABB]) -> Dictionary:
	var best := {}
	var best_free := 0
	for entry: Variant in surfaces:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var patch: Dictionary = entry
		if str(patch.get("kind", "")) != "stand":
			continue
		var extent: Vector3 = patch.get("extent", Vector3.ZERO)
		if maxf(extent.x - size.x, extent.z - size.z) \
				< ChamberBuilders.BRUTE_LANE:
			continue
		# THE SAME SEARCH THE AUDIT RUNS, over the same candidates in the
		# same order, with this element's footprint and this composer's
		# evidence. `census` counts every valid spot rather than stopping
		# at the first, because the surface with the most room wins.
		var fits := func(spot: Vector3) -> bool:
			return can_place(spot, size, height, taken, solids)
		var verdict := Placement.find(
				patch.get("position", Vector3.ZERO), extent, size, height,
				fits, true)
		var free := int(verdict.get("usable", 0))
		if free > best_free:
			best_free = free
			best = patch
	return best

## Is this spot one an element can actually occupy?
##
## PUBLIC, and the composer's half of the contract: `RoomAudit`'s
## `player_stands_here` is the other half. Both are handed to the same
## `Placement.find`, and the suite asks them the same question about the
## same regions to prove they have not drifted apart.
##
## TWO QUESTIONS, and they are not the same one. `taken` is what is
## already claimed -- other elements, props, the builder's reserved
## regions -- and crowding it is a trade-off the composer is allowed to
## make. `solids` is the room's real geometry, and there is no trade-off
## available: an element inside a staircase is inside a staircase.
static func can_place(spot: Vector3, size: Vector3, height: float,
		taken: Array[AABB], solids: Array[AABB]) -> bool:
	return _clear_of_geometry(spot, size, height, solids) \
			and not _collides(spot, size, taken)

## Nothing of the room is in the volume this element needs.
##
## `RoomAudit` asks the same question of the same volume with a shape
## query, because it has a physics space and this does not: a chamber is
## composed while its root is still DETACHED, so there is nothing to
## query. One search, one definition of the volume, two kinds of evidence
## -- and the suite pins the two verdicts against each other.
##
## FROM THE SURFACE, not from the element. `height` is how far above the
## surface the rules park this element, so `spot.y - height` is the
## walking plane, and the volume that matters runs from there -- a player
## has to stand at the thing to press it. `RoomAudit.HEADROOM` rather
## than a number of its own: the composer builds to exactly what the
## audit measures, or one of them is wrong.
static func _clear_of_geometry(spot: Vector3, size: Vector3,
		height: float, solids: Array[AABB]) -> bool:
	if solids.is_empty():
		return true
	var box := Placement.clearance(
			Vector3(spot.x, spot.y - height, spot.z), size,
			RoomAudit.HEADROOM)
	return not ChamberBuilders.box_hits(box, solids)

## A free spot on `surface`, falling through to the other vouched
## surfaces before it gives up.
##
## Preference, in order: away from the surface's near and far EDGES,
## which for a ledge is where its doorway is, and then out to the sides,
## off the middle where the mandatory route runs. That is the same lane
## discipline the flat solve applies, expressed as a preference rather
## than a bound -- a 4 m ledge cannot give up 2 m at each end and still
## hold anything, and a crowded plate on real floor beats a tidy one
## over a pit.
static func _spot_on_surface(surface: Dictionary, surfaces: Array,
		size: Vector3, height: float, taken: Array[AABB],
		solids: Array[AABB]) -> Dictionary:
	var order: Array = [surface]
	for entry: Variant in surfaces:
		if typeof(entry) == TYPE_DICTIONARY and entry != surface \
				and str((entry as Dictionary).get("kind", "")) == "stand":
			order.append(entry)
	var fallback := Vector3.ZERO
	var have_fallback := false
	for entry: Variant in order:
		var patch: Dictionary = entry
		var at: Vector3 = patch.get("position", Vector3.ZERO)
		var extent: Vector3 = patch.get("extent", Vector3.ZERO)
		if not Placement.holds(extent, size):
			continue
		if maxf(extent.x - size.x, extent.z - size.z) \
				< ChamberBuilders.BRUTE_LANE:
			continue
		var best := Vector3.ZERO
		var best_score := -INF
		var found := false
		for candidate: Vector3 in Placement.candidates(
				at, extent, size, height):
			# THE LAST RESORT IS STILL A REAL SPOT. The old fallback took
			# the first candidate whatever was there; it now takes the
			# first one the ROOM allows, and only CROWDING is traded away.
			# A missing element is worse than a tight one; an element
			# inside a staircase is worse than both.
			if not _clear_of_geometry(candidate, size, height, solids):
				continue
			if not have_fallback:
				fallback = candidate
				have_fallback = true
			if _collides(candidate, size, taken):
				continue
			var from_edge := minf(
					absf(candidate.z - at.z + extent.z / 2.0),
					absf(at.z + extent.z / 2.0 - candidate.z))
			var score := from_edge * 10.0 + absf(candidate.x)
			if score > best_score:
				best_score = score
				best = candidate
				found = true
		if found:
			return {"found": true, "position": best}
	# Every vouched surface is full. Crowded, and still ON one: the flat
	# solve makes the same choice for the same reason, because a missing
	# element is a puzzle nobody can finish.
	if have_fallback:
		return {"found": true, "position": fallback}
	# NOTHING the room offered can hold this element. The offer is
	# declined and the caller keeps its flat solve, rather than an element
	# being pushed into the one place the room said not to.
	return {"found": false}

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
