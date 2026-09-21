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

## HOW FAR THE TARGET'S HARDWARE REACHES BACK, from the element origin.
##
## `ActivityElement._build_target` hangs a 0.5 m stalk centred 0.3 m
## behind the face, so the hardware ends 0.55 m back. Mounting puts the
## origin exactly that far off the wall plane, and the stalk lands on
## the wall instead of in the air behind a target hanging in the middle
## of the room -- which is what the owner saw: "they have pegs and they
## should be sticking out of the walls".
const MOUNT_STALK := 0.55

## Clear of a doorway, beside the door's own half width.
##
## A side socket sits at the middle of a side wall (`_perimeter`), so
## the middle of a side wall is the one place on it a target may not go.
## A row that hung one there would be a shooting gallery across a door.
const MOUNT_DOOR_CLEAR := 0.6

## Steps the wall search takes along the wall, looking for room.
const MOUNT_STEP := 0.6
const MOUNT_TRIES := 16
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
		var yaw := 0.0
		var claimed := size
		var mounted := false
		# A TARGET GOES ON THE WALL, and tries the other wall before it
		# gives up on walls altogether.
		#
		# A ROOM THAT VOUCHED SURFACES IS NOT EXCLUDED, IT IS ASKED.
		#
		# It used to be excluded outright, because a `platform_path`'s
		# bounds reach forty metres down and the wall at `width/2` is a
		# wall over a kill pit -- `godot-zone-audit` caught the first
		# version putting six elements in `c006` with nothing under
		# them. That exclusion was the right call with no way to tell a
		# real wall from a nominal one. There is one now, and a
		# firing-position test to go with it, so the two questions that
		# actually decide it are asked directly: is there a wall, and is
		# there anywhere to shoot it from. A room that answers no to
		# either still falls through to the surface solve, which is
		# untouched.
		if trigger == ActivityElement.SHOT:
			var wall := _wall_spot(side, near + (far - near) * t, width,
					depth, size, height, taken, solids)
			if wall.is_empty():
				wall = _wall_spot(-side, near + (far - near) * t, width,
						depth, size, height, taken, solids)
			if not wall.is_empty():
				spot = wall["position"]
				yaw = float(wall["yaw"])
				claimed = wall["size"]
				mounted = true
		if not mounted and not surface.is_empty():
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
		element.rotation.y = yaw
		# SAID OUT LOUD ON THE ELEMENT, so a suite can tell a target that
		# found a wall from one that did not without re-deriving the
		# solve. A decline is a placement outcome, not a silent one.
		element.set_meta("mounted", mounted)
		# AND THE SPACE IT ACTUALLY CLAIMS. A mounted target is turned,
		# so its 0.9 m span runs along the wall and its 0.2 m thickness
		# across it -- the opposite of `rules["size"]`. `_footprints`
		# reads this rather than the family's nominal size, because that
		# list becomes `occupied` for the NEXT activity in the same
		# room: understating the along-wall extent by 0.7 m is a second
		# activity placed into the first one.
		# AN UNMOUNTED SHOT TARGET CLAIMS A SQUARE, because which way it
		# ends up facing is not decided yet -- `aim_shot_targets` turns
		# it once every element in the room exists. Claiming the
		# silhouette in both horizontal axes makes the footprint
		# rotation-invariant, so a later quarter turn cannot leave the
		# next activity's avoid-list describing a box the element no
		# longer occupies. It reserves a little more than it needs,
		# which is the safe direction to be wrong in.
		if trigger == ActivityElement.SHOT and not mounted:
			var span := maxf(size.x, size.z)
			claimed = Vector3(span, size.y, span)
		element.set_meta("claimed_size", claimed)
		element.set_meta("nominal_size", size)
		taken.append(_footprint(spot, claimed))
		built.append(element)
	return built

## How far in front of a shot target has to be clear for it to be
## shootable. `godot-target-facing`'s own `CLEAR_AHEAD`, so the builder
## and the census are answering one question.
const AIM_CLEAR := 2.0
## The yaws an unmounted target tries, in order. The room's default is
## first, so a target that is already fine does not move.
## Sixteen facings, cardinals first so a target that is already fine does
## not move, then the diagonals, then the half-steps between. All of them
## are still only a rotation -- nothing is relocated -- and in a narrow
## room an off-axis facing is often the only one with two clear metres in
## it.

## AIM EVERY UNMOUNTED SHOT TARGET IN A ROOM, once all of them exist.
##
## Called by the instantiator after the room's LAST activity is placed,
## and that level matters: an activity's own row can only see the rows
## before it, so a target in the first activity faced a target in the
## third. Three of the seven original failures were exactly that, and
## four more were the same thing one level down.
##
## `before` is the room's occupied list as it stood BEFORE any activity
## was placed. The elements themselves are read from the scene, so
## nothing here consults a footprint an element has since stopped
## occupying.
## THE SOLIDS ARE READ OFF THE FINISHED ROOM, minus the elements.
##
## Both halves of that are paid for. Reading them BEFORE the activities
## were built missed whatever the activities themselves add -- a target
## turned to face a prop a later activity had put there, and the census
## found it at 1.90 m. Reading them after WITHOUT pruning the elements
## put every target's own collider in its own way, and nothing turned at
## all. So the walk skips the element subtrees, and the elements are
## modelled from the footprints they claimed instead.
static func aim_shot_targets(root: Node3D) -> void:
	var elements: Array[ActivityElement] = []
	_gather_elements(root, elements)
	if elements.is_empty():
		return
	var skip: Array = []
	for element in elements:
		skip.append(element)
	_aim_the_unmounted(elements,
			ChamberBuilders.all_solid_boxes(root, Transform3D.IDENTITY,
					skip))

static func _gather_elements(node: Node,
		into: Array[ActivityElement]) -> void:
	var element := node as ActivityElement
	if element != null:
		into.append(element)
	for child in node.get_children():
		_gather_elements(child, into)

## TURN THE UNMOUNTED TARGETS TO FACE SOMETHING SHOOTABLE.
##
## `yaw` is written in exactly one place in `_row` -- the mounted branch
## -- so a SHOT element that found no wall kept the room's default
## orientation, and the floor solver that then placed it asks about
## SPACE and never about what is in front of the face. In the diagnostic
## Zone twelve of twenty-seven targets were unmounted, all of them
## facing room-local +Z, and seven faced into geometry: two into a
## shell's own back wall and three into each other.
##
## A SECOND PASS, AND THAT IS NOT A STYLE CHOICE. Inside `_row`'s loop
## `taken` holds elements `0..i-1` only, and three of those seven faced
## elements placed AFTER them. A yaw chosen there cannot see what has
## not been built yet.
##
## POSITIONS DO NOT MOVE, and no element is ever dropped. This rotates
## objects and relocates no room, no Check and no element; one that can
## find no clear facing keeps the arrangement it had, so the census
## reports a real remaining case rather than the builder hiding it.
static func _aim_tries() -> Array[float]:
	var out: Array[float] = [0.0, PI / 2.0, -PI / 2.0, PI]
	for step in 12:
		var eighth := PI / 4.0 + float(step) * PI / 8.0
		out.append(wrapf(eighth, -PI, PI))
	return out

static func _aim_the_unmounted(built: Array[ActivityElement],
		solids: Array[AABB]) -> void:
	var tries := _aim_tries()
	for element in built:
		if element.trigger != ActivityElement.SHOT:
			continue
		if bool(element.get_meta("mounted", false)):
			continue
		var size: Vector3 = element.get_meta("nominal_size",
				ActivityElement.TARGET_SIZE)
		# TWO WIDTHS, AND THE WIDE ONE FIRST. The preference is a facing
		# with the target's own width clear in front of it, because
		# "clear" should not mean a shot threading a gap narrower than
		# the thing being shot at. But the census fires a single
		# zero-width ray, so that preference is strictly stricter than
		# the bar -- and one boxed-in target in the diagnostic Zone has
		# no generously clear facing at all. Keeping it pointed at a
		# wall 1.9 m away to honour the preference would be the wrong
		# trade: a narrow pass runs second, and only a target that fails
		# BOTH keeps the arrangement it had.
		var found := false
		for width: float in [1.0, NARROW_AIM]:
			for yaw: float in tries:
				if not _aim_is_clear(element, yaw, size, built, solids,
						width):
					continue
				element.rotation.y = yaw
				found = true
				break
			if found:
				break
		if not found:
			# NAMED, NOT SWALLOWED. A target no rotation can clear is a
			# real remaining case and the census is entitled to say so.
			push_warning(("activity target %s at %v has no clear facing "
					% [element.name, element.position])
					+ "in any of %d tried" % tries.size())

## Is there `AIM_CLEAR` of nothing in front of `element` at `yaw`?
##
## Measured against the same three things the census measures against:
## the room's solids, the other activities already in the room, and the
## OTHER elements of this row -- the last being the case a first pass
## structurally cannot see.
## How wide the second, fallback probe is: a sliver, so it asks very
## nearly the question the census's single ray asks.
const NARROW_AIM := 0.12

static func _aim_is_clear(element: ActivityElement, yaw: float,
		size: Vector3, built: Array[ActivityElement],
		solids: Array[AABB], width_scale := 1.0) -> bool:
	var face := Vector3(sin(yaw), 0.0, cos(yaw))
	var at := element.position
	# Starting clear of the element's own face rather than at its origin:
	# the census excludes the target's own colliders, and a probe that
	# began inside them would refuse every yaw.
	var start := at + face * (size.z * 0.5 + 0.15)
	var stop := at + face * AIM_CLEAR
	# PERPENDICULAR TO TRAVEL, AND ONLY PERPENDICULAR. As wide as the
	# target itself, so "clear" cannot mean a shot threading a gap
	# narrower than the thing being shot at -- but padding the TRAVEL
	# axis as well reaches backwards through the element into whatever
	# stands behind it, and a target 0.45 m off a wall then refused
	# every facing including the open ones. Four of them did, and the
	# census read that as the original defect rather than as this one.
	var perp := Vector3(face.z, 0.0, -face.x) * (size.x * 0.5 * width_scale)
	var lo := Vector3(INF, at.y - size.y * 0.5, INF)
	var hi := Vector3(-INF, at.y + size.y * 0.5, -INF)
	for corner: Vector3 in [start + perp, start - perp,
			stop + perp, stop - perp]:
		lo.x = minf(lo.x, corner.x)
		lo.z = minf(lo.z, corner.z)
		hi.x = maxf(hi.x, corner.x)
		hi.z = maxf(hi.z, corner.z)
	var probe := AABB(lo, hi - lo)
	# SOLIDS AND ELEMENTS, NOT RESERVATIONS. `occupied` is the room's
	# avoid-list -- padded claims that keep two pieces of content from
	# landing on each other. It is not what a shot travels through, and
	# refusing a facing because of one made this stricter than the census
	# it exists to satisfy: a target with two clear metres of air in front
	# of it kept a facing into a wall because a reward had reserved the
	# space. What a ray can hit is solids and other elements' bodies, and
	# that is what is asked.
	if ChamberBuilders.box_hits(probe, solids):
		return false
	for other in built:
		if other == element:
			continue
		var claimed: Vector3 = other.get_meta("claimed_size", size)
		if probe.intersects(_footprint(other.position, claimed)):
			return false
	return true

## A SHOT TARGET GOES ON A WALL.
##
## The row solve above spreads every element across the room's floor
## plan, which is right for a switch you walk to and a plate you stand
## on, and wrong for the one element nobody ever touches. A target at
## `height` 2.2 with nothing behind it is a 0.9 m square floating at
## head height on a stalk that holds it off nothing.
##
## So a `SHOT` element is offered a wall first. The side walls, not the
## ends: the entry and the exit are where the player comes in, the row
## already keeps `THRESHOLD_CLEARANCE` off both, and a target across a
## doorway is worse than a target in the air. The element turns to face
## the room, so its 0.9 m span now runs ALONG the wall and its 0.2 m
## thickness across it, and the origin sits `MOUNT_STALK` off the wall
## plane so the hardware meets the plaster.
##
## THE OFFER MAY BE DECLINED, exactly as `_spot_on_surface`'s is. A wall
## with no legal span left -- crowded, or nothing but doorway -- returns
## `{}` and the flat solve stands. An element is never dropped and never
## forced into geometry to honour an offer.
##
## WHAT THIS DOES NOT CLAIM. It solves against the room's OWN declared
## envelope, `width` and `depth`, in the room's own frame -- so a room
## placed at any yaw in the Zone mounts correctly, because the element
## is a child of it. A room whose interior wall is not parallel to its
## own axes is not handled here and is not pretended to be: such a wall
## reaches the composer only as an axis-aligned solid, and the honest
## thing is that this rule reads the declaration rather than guessing at
## the mesh. `_clear_of_geometry` still refuses a mounted spot that a
## solid occupies, so the worst case is a decline and not a target
## inside a pillar.
static func _wall_spot(side: float, ideal_z: float, width: float,
		depth: float, size: Vector3, height: float,
		taken: Array[AABB], solids: Array[AABB]) -> Dictionary:
	var plane := width / 2.0 - AffordanceFeatures.WALL_MARGIN
	var x := side * (plane - MOUNT_STALK)
	# Turned to face the room: the face normal is local +Z.
	var yaw := PI / 2.0 if side < 0.0 else -PI / 2.0
	# Rotated, so the extents swap: `size.x` now runs along the wall.
	var along := size.x / 2.0
	var lo := AffordanceFeatures.THRESHOLD_CLEARANCE + along
	var hi := maxf(lo, depth - AffordanceFeatures.THRESHOLD_CLEARANCE
			- along)
	if hi <= lo:
		return {}
	var door := depth / 2.0
	var bar := ChamberBuilders.DOOR_WIDTH / 2.0 + MOUNT_DOOR_CLEAR + along
	var turned := Vector3(size.z, size.y, size.x)
	for attempt in MOUNT_TRIES:
		# Outward from the ideal, alternating, so a row keeps its order
		# and its spread rather than piling up at one end.
		var step := float((attempt + 1) / 2) * MOUNT_STEP
		var z := ideal_z + (step if attempt % 2 == 0 else -step)
		if z < lo or z > hi:
			continue
		if absf(z - door) < bar:
			continue
		var spot := Vector3(x, height, z)
		if not can_place(spot, turned, height, taken, solids):
			continue
		# IS THERE ACTUALLY A WALL BEHIND THE STALK?
		#
		# The first version took `width / 2 - WALL_MARGIN` as the wall
		# plane and never looked. That is the room's declared ENVELOPE,
		# which is where a wall would be -- not evidence that one is.
		# Every wall is built by `_box` and `_box` gives it a collision
		# hull; `all_solid_boxes` reads hulls WITHOUT the architecture
		# filter it applies to meshes, so the wall really is in `solids`
		# and can be asked for.
		if not _wall_behind(spot, side, size, solids):
			continue
		# NOT "floor under it". Nobody stands beneath a wall target.
		#
		# A first cut required ground directly below the mount, which is
		# the question a FLOOR-PLACED element is owed and the wrong one
		# here: it refuses a perfectly ordinary target hanging over a
		# walkway recess, and it is not what makes a mount usable. What
		# does is the wall above and a place to stand and shoot from,
		# which is the next test.
		# AND SOMEWHERE TO STAND AND SHOOT IT FROM. This is the second
		# requirement in full: a real wall over a KILL PIT is a target
		# nobody can address, and a real wall over a GAP with a walkway
		# seven metres out is a perfectly ordinary one.
		#
		# MEASURED, NOT DECLARED. An earlier cut asked the room's vouched
		# `stand` patches on the assumption that only a platform course
		# vouches any -- an arena vouches them too, so every arena target
		# was refused by a rule reading a list it had misunderstood.
		# Floor is floor: this asks the same solids the wall test asks.
		if not _firing_position(spot, side, height, solids):
			continue
		return {"position": spot, "yaw": yaw, "size": turned}
	return {}

## Room architecture immediately behind a mounted target.
##
## A slab reaching from the stalk's tip outward, so what it asks is
## "does this stalk end on something" rather than "is the envelope wide
## enough". Deliberately shallow: a pillar is a mounting surface and a
## wall is a mounting surface, and neither is the point -- what is
## refused is a stalk ending in air.
static func _wall_behind(spot: Vector3, side: float, size: Vector3,
		solids: Array[AABB]) -> bool:
	if solids.is_empty():
		return false
	var tip := spot.x + side * MOUNT_STALK
	var reach := 0.9
	var lo := minf(tip, tip + side * reach)
	var box := AABB(
			Vector3(lo, spot.y - size.y / 2.0, spot.z - size.x / 2.0),
			Vector3(reach, size.y, size.x))
	return ChamberBuilders.box_hits(box, solids)

## Floor below a point, within a player's reach of it.
##
## A thin column under the point's own footprint. Thin on purpose: it
## must not find the WALL beside it and call that a floor. Asked of a
## FIRING POSITION, never of the mount -- nobody stands under a wall
## target.
static func _floor_under(spot: Vector3, height: float,
		solids: Array[AABB]) -> bool:
	if solids.is_empty():
		return false
	var drop := height + RoomAudit.GROUND_REACH
	var column := AABB(
			Vector3(spot.x - 0.15, spot.y - drop, spot.z - 0.15),
			Vector3(0.3, drop - 0.1, 0.3))
	return ChamberBuilders.box_hits(column, solids)

## A place a player can STAND and shoot this target from.
##
## Sampled out into the room on the target's own side. Each sample needs
## two things, both measured against the same solids the wall test
## reads: floor under it, and room for a standing body above that floor
## -- a slot under a deck with 1.2 m of headroom is not a firing
## position.
##
## The far sample is well inside the Static Pulse's forty metres: a shot
## from across the room is legal and is not what a usable firing
## position means. The near one is outside the target's own footprint,
## because standing inside a thing is not standing at it.
static func _firing_position(spot: Vector3, side: float, height: float,
		solids: Array[AABB]) -> bool:
	for out: float in [2.0, 3.5, 5.0, 7.0, 9.0]:
		var at := Vector3(spot.x - side * out, spot.y, spot.z)
		if not _floor_under(at, height, solids):
			continue
		if _has_headroom(at, height, solids):
			return true
	return false

## Room for a standing body on the floor a sample found.
##
## `RoomAudit.HEADROOM` rather than a number of its own: the composer
## builds to exactly what the audit measures, or one of them is wrong.
## The same reason `_clear_of_geometry` uses it.
static func _has_headroom(at: Vector3, height: float,
		solids: Array[AABB]) -> bool:
	var stand := Placement.clearance(
			Vector3(at.x, at.y - height, at.z),
			Vector3(Constants.PLAYER_RADIUS * 2.0, 0.0,
				Constants.PLAYER_RADIUS * 2.0),
			RoomAudit.HEADROOM)
	return not ChamberBuilders.box_hits(stand, solids)

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
## THE SPACE EACH ELEMENT CLAIMED, for the next activity in this room.
##
## Per element rather than from the family's nominal size: a mounted
## `SHOT` target is turned, so its extents are swapped, and `_row`
## records what each one actually took.
static func _footprints(built: Array[ActivityElement],
		size: Vector3) -> Array[AABB]:
	var out: Array[AABB] = []
	for element in built:
		var claimed: Vector3 = element.get_meta("claimed_size", size)
		out.append(_footprint(element.position, claimed))
	return out

## The space an element claims, a little wider than its mesh so two
## elements do not merely touch.
static func _footprint(at: Vector3, size: Vector3) -> AABB:
	var pad := Vector3(0.35, 0.2, 0.35)
	var full := size + pad * 2.0
	return AABB(at - full * 0.5, full)
