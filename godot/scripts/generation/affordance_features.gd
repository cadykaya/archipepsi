class_name AffordanceFeatures
extends RefCounted
## The seven world affordances (ECHOES §13), as geometry.
##
## Epsilon names a tag and a fraction of the chamber; this file owns the
## metres, exactly as `ZoneBuilder` does for layout. That division is what
## makes §13.2 structural: a generator that could name a coordinate could
## name one in the exit lane, so it never gets to name one.
##
## **A corridor is the only chamber that can ever host one.** Every other
## chamber type carries a Check or a gating objective by construction, and
## §13.2 bars features from both — so the host is always 5–10 m wide with a
## ceiling at `CORRIDOR_HEIGHT`, and cramped. The first version of this file
## was written and tested against an 18×20 arena with a 6 m ceiling, which
## is a room the schema would refuse: four of the seven rewards sat above
## the corridor ceiling, unreachable, and nothing noticed because the suite
## built the arena too.
##
## Three guarantees are enforced here rather than trusted:
##
## 1. **Never on the mandatory path.** A feature's whole FOOTPRINT clears
##    the central walking lane, not merely its origin — a bounce pad whose
##    origin sat at the lane edge still put half its trigger inside the
##    lane, which launched a player who was only walking past.
## 2. **Never through the ceiling.** Each tag declares the headroom it
##    needs, and a corridor carrying it is built that tall. Clamping a
##    ledge to "as high as fits" instead put the grapple plate above a
##    solid ceiling slab, where no raycast could reach it.
## 3. **Never an AP reward.** What a feature holds is a
##    `LocalRewardPickup` — §14.2 — and there is no code path from here to
##    a `RewardObject`, a location id or a Check.
##
## A feature only reaches this file if the campaign owns the capability
## that makes it interactable: `validate_zone` refuses the Zone otherwise
## (I12). So nothing here has to ask whether the player can use it.

## Half-width of the walking lane a feature may never intrude on. The door
## is 2.4 m and the player is not a point; this leaves better than a body's
## clearance either side of the widest thing that has to get through.
const LANE_HALF_WIDTH := 2.0
## Clearance kept between a feature's outer edge and the wall's inner face,
## so nothing is built into masonry.
const WALL_MARGIN := 0.35
const GROUP := "affordance_feature"

## What each tag actually occupies, which is the thing the lane and the
## ceiling have to be checked against.
##
## `half_width` and `half_depth` are the geometry's reach either side of
## its origin — including anything hung off it, like the wind column's
## perch or the rail's beam. `height` is the headroom the chamber must
## have for the feature to work: the bounce pad's is a LAUNCH clearance,
## because a pad that fires you into a ceiling 0.4 m up is a pad that
## hurts.
const FOOTPRINT := {
	"grapple_anchor": {"half_width": 0.7, "half_depth": 0.7, "height": 5.6},
	"breakable_wall": {"half_width": 0.7, "half_depth": 1.3, "height": 3.6},
	"water_volume": {"half_width": 0.8, "half_depth": 0.8, "height": 3.6},
	"rail": {"half_width": 0.5, "half_depth": 3.5, "height": 3.6},
	"wind_volume": {"half_width": 0.8, "half_depth": 0.8, "height": 6.0},
	"bounce_pad": {"half_width": 0.6, "half_depth": 0.6, "height": 7.0},
	"moving_platform": {"half_width": 0.8, "half_depth": 0.8, "height": 5.2},
}

## Note text per tag, so a feature that yields a note says something about
## the capability that opened it rather than a generic congratulation.
const _NOTES := {
	"grapple_anchor": "Somebody else's grapple. Same ceiling.",
	"breakable_wall": "It was load-bearing. It is not any more.",
	"water_volume": "I filled it before I checked you could swim.",
	"rail": "Built for grinding. Grind responsibly.",
	"wind_volume": "The updraft is free. The landing is yours.",
	"bounce_pad": "No item required. Just enthusiasm.",
	"moving_platform": "It goes there, then it comes back. Forever.",
}

## The narrowest chamber that can host this tag: lane, the feature's own
## reach, and clearance off the wall, on both sides.
##
## Per-tag rather than one number, because the tags are not the same size.
## A rail needs 5.9 m; a wind column with its perch needs 8.3 m. A single
## conservative constant would have refused the rail from every corridor
## the wind column could not fit in either.
static func required_width(tag: String) -> float:
	var reach: float = float(FOOTPRINT.get(tag, {}).get("half_width", 1.2))
	# TWICE the reach. A feature spans `reach` on each side of its origin,
	# so the origin must sit at least `LANE + reach` from centre AND at
	# most `width/2 - WALL_MARGIN - reach` from it; those two bounds only
	# leave room when the width covers the lane, the margin and the
	# feature's whole span. Counting the reach once put a 1.1 m-reach
	# anchor 3.1 m off centre in an 8 m room and let it poke 0.2 m out
	# through the wall.
	return 2.0 * (LANE_HALF_WIDTH + 2.0 * reach + WALL_MARGIN)

## The headroom this tag needs. A corridor carrying it is built this tall
## (`ChamberBuilders.corridor` reads `AffordanceFeatures.required_height`),
## because the alternative — clamping the feature to whatever fits — is
## what put a grapple plate above a solid ceiling.
static func required_height(chamber: Dictionary) -> float:
	var tallest := 0.0
	for feature: Dictionary in chamber.get("features", []):
		tallest = maxf(tallest, float(FOOTPRINT.get(
				str(feature.get("tag", "")), {}).get("height", 0.0)))
	return tallest

## Whether this chamber can host this tag at all.
##
## A room too narrow has no "beside the path" in it, and pushing a feature
## out of the lane would push it into the wall. Such a chamber gets no
## feature — which is not a failure: features are optional by definition,
## and a Zone missing one is strictly better than a Zone with a bounce pad
## inside the masonry or across the doorway.
## The shortest chamber that can host this tag, by the same argument as
## `required_width` along the other axis. A rail is seven metres long, so
## a twelve-metre corridor with two doorways to keep clear has nowhere to
## put it — and clamping it in anyway ran the beam out through a wall.
static func required_depth(tag: String) -> float:
	var reach: float = float(FOOTPRINT.get(tag, {}).get("half_depth", 1.2))
	return 2.0 * (THRESHOLD_CLEARANCE + reach)

static func fits(width: float, tag := "", depth := INF) -> bool:
	# A hair of tolerance, because the boundary is meant to be INCLUSIVE
	# and both sides compute it from float arithmetic. A chamber built at
	# exactly the minimum the schema admits was rejected here roughly half
	# the time, depending on how 2.0 + 1.2 + 0.35 happened to round.
	return (width >= required_width(tag) - 0.001
			and depth >= required_depth(tag) - 0.001)

## Where a feature actually lands, given what Epsilon asked for.
##
## `at` is a fraction of the chamber; the lateral half is pushed out of the
## walking lane by the feature's OWN reach, toward whichever side it
## already leaned. A feature asked for dead centre goes left rather than
## nowhere: refusing to place it would make a validated Zone quietly poorer
## than it read.
##
## Only meaningful where `fits(width, tag)`; callers check that first.
static func resolve_position(at: Array, width: float, depth: float,
		tag := "") -> Vector3:
	var reach: Dictionary = FOOTPRINT.get(tag, {})
	var half_width: float = float(reach.get("half_width", 1.2))
	var half_depth: float = float(reach.get("half_depth", 1.2))

	var u := clampf(float(at[0]) if at.size() > 0 else 0.5, 0.0, 1.0)
	var v := clampf(float(at[1]) if at.size() > 1 else 0.5, 0.0, 1.0)
	var x := (u - 0.5) * width
	var side := 1.0 if x >= 0.0 else -1.0
	# The feature's near EDGE clears the lane and its far edge clears the
	# wall. Checking the origin alone let a 2 m-wide pad reach 1 m into a
	# lane its centre was clear of.
	var inner := LANE_HALF_WIDTH + half_width
	var outer := width / 2.0 - WALL_MARGIN - half_width
	x = side * clampf(absf(x), inner, maxf(inner, outer))

	# Same rule along the length: both thresholds are where the mandatory
	# path is narrowest, and a rail is seven metres long.
	var near := THRESHOLD_CLEARANCE + half_depth
	var far := depth - THRESHOLD_CLEARANCE - half_depth
	var z := clampf(v * depth, near, maxf(near, far))
	return Vector3(x, 0.0, z)

## How far from either doorway a feature's geometry must stay.
const THRESHOLD_CLEARANCE := 2.0

## Build every feature a chamber declares. Called from `ChamberBuilders`
## after the room exists, so the extent is known and the lane is real.
static func place_all(root: Node3D, chamber: Dictionary, theme: String,
		width: float, depth: float, height: float) -> Array:
	var built: Array = []
	for index in (chamber.get("features", []) as Array).size():
		var feature: Dictionary = chamber["features"][index]
		var tag := str(feature.get("tag", ""))
		if not fits(width, tag, depth):
			# Too small for THIS tag, on either axis. Dropped rather than
			# crammed in: features are optional, and one built into a wall
			# or across a doorway is worse than one absent.
			continue
		var origin := resolve_position(
				feature.get("at", [0.5, 0.5]), width, depth, tag)
		# Zone-scoped, because the bridge's idempotence key is the reward
		# id alone. Chamber-scoped ids repeat across Zones — the fallback
		# emits `c1` and `c3` in every one — so the second Zone's note
		# vanished on pickup and was silently discarded as a duplicate.
		var reward_id := "%s_%s_%s_%d" % [
				str(chamber.get("zone_id", "z")),
				str(chamber.get("id", "c")), tag, index]
		var node := _build(root, tag, theme, origin, width, depth, height,
				reward_id, str(feature.get("note", "")))
		if node != null:
			node.add_to_group(GROUP)
			node.set_meta("affordance_tag", tag)
			built.append(node)
	return built

static func _build(root: Node3D, tag: String, theme: String,
		origin: Vector3, width: float, depth: float, height: float,
		reward_id: String, note: String) -> Node3D:
	match tag:
		"grapple_anchor":
			return _grapple_anchor(root, theme, origin, height, reward_id, note)
		"breakable_wall":
			return _breakable_wall(root, theme, origin, width, reward_id, note)
		"water_volume":
			return _water_volume(root, theme, origin, reward_id, note)
		"rail":
			return _rail(root, theme, origin, depth, reward_id, note)
		"wind_volume":
			return _wind_volume(root, theme, origin, height, reward_id, note)
		"bounce_pad":
			return _bounce_pad(root, theme, origin, height, reward_id, note)
		"moving_platform":
			return _moving_platform(root, theme, origin, height, reward_id, note)
	# An unknown tag is drift between the schema and this file, not a Zone
	# to silently degrade: the schema's Literal is closed, so reaching here
	# means a tag was added without geometry.
	push_error("affordance tag '%s' has no geometry" % tag)
	return null

## The reward a feature yields, hung at `where`. Always local (§14.2).
static func _reward(root: Node3D, tag: String, at: Vector3,
		reward_id: String, note: String) -> LocalRewardPickup:
	var text := note if note != "" else str(_NOTES.get(tag, "A fragment."))
	var pickup := LocalRewardPickup.create(
			"epsilon_note", reward_id, "Note: %s" % tag.replace("_", " "),
			text)
	pickup.position = at
	root.add_child(pickup)
	return pickup


# --- The seven ------------------------------------------------------------
#
# Every vertical number below is measured against the room the feature is
# actually built in: `required_height` makes the chamber tall enough, and
# `CEILING_GAP` keeps geometry out of the slab. The previous version
# clamped to "as high as fits" instead, which in a 3.6 m corridor put the
# grapple plate, the bounce reward and the wind perch above a solid
# ceiling.

## Clearance kept under the ceiling slab, so nothing is built into it.
const CEILING_GAP := 0.5
## A standing jump tops out at 1.33 m and the player has no mantle, so a
## ledge above this needs the capability that pays for the feature.
const OUT_OF_JUMP_REACH := 2.1

## A ceiling hook with a ledge under it. The grapple family reaches it;
## nothing else does, and nothing required is up there.
static func _grapple_anchor(root: Node3D, theme: String, origin: Vector3,
		height: float, reward_id: String, note: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.position = origin
	root.add_child(anchor)
	# The plate is what a grapple raycast bites, so it must be BELOW the
	# ceiling with room for the ledge under it.
	var plate_y := height - CEILING_GAP
	var lip := maxf(OUT_OF_JUMP_REACH, plate_y - 2.2)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.position = Vector3(0, plate_y - 0.3, 0)
	ring.rotation.x = PI / 2.0
	ring.material_override = ThemeMaterials.glow_material(
			Constants.AFFORDANCE_SIGNAL, 1.8)
	anchor.add_child(ring)
	_solid(anchor, Vector3(1.0, 0.25, 1.0), Vector3(0, plate_y, 0),
			ThemeMaterials.trim_mat(theme))
	_solid(anchor, Vector3(1.4, 0.3, 1.4), Vector3(0, lip, 0),
			ThemeMaterials.accent_mat(theme))
	_reward(anchor, "grapple_anchor", Vector3(0, lip + 0.75, 0), reward_id, note)
	return anchor

## A false wall panel with a shallow alcove behind it, set INTO the room
## rather than through the wall.
##
## The previous version put the recess and its reward at `width/2 + 1.35`
## — outside the chamber, behind masonry that is never removed — so
## breaking the panel revealed a wall and the payoff was permanently
## unreachable. An alcove that protrudes inward is honest geometry: a
## cupboard in a false wall, and everything in it is inside the room.
static func _breakable_wall(root: Node3D, theme: String, origin: Vector3,
		width: float, reward_id: String, note: String) -> Node3D:
	var nook := Node3D.new()
	var side := 1.0 if origin.x >= 0.0 else -1.0
	nook.position = Vector3(side * (width / 2.0 - WALL_MARGIN - 0.7),
			0.0, origin.z)
	root.add_child(nook)
	var wall := ThemeMaterials.wall_mat(theme)
	# The alcove's own three sides, so what the panel hides is a room.
	_solid(nook, Vector3(0.25, 2.6, 2.4), Vector3(side * 0.65, 1.3, 0), wall)
	for end_z in [-1.0, 1.0]:
		_solid(nook, Vector3(1.5, 2.6, 0.25),
				Vector3(0, 1.3, end_z * 1.2), wall)
	var panel := AffordanceNodes.BreakablePanel.new()
	panel.position = Vector3(side * -0.65, 1.3, 0)
	# Was `hazard_mat`. A breakable wall is an OPPORTUNITY, not a
	# warning, and hazard orange is reserved for things that hurt you
	# (art requirements 15 and 20). The damage channel is unaffected:
	# it rides emission ENERGY, not hue.
	panel.tint = Constants.AFFORDANCE_SIGNAL
	nook.add_child(panel)
	_reward(nook, "breakable_wall", Vector3(0, 0.9, 0), reward_id, note)
	return nook

## A shallow pool. Buoyant and draggy: you sink slowly, you swim slowly,
## and you can always get out — `Player.MIN_VOLUME_SPEED_SCALE` is the
## floor that makes "always" structural.
static func _water_volume(root: Node3D, _theme: String, origin: Vector3,
		reward_id: String, note: String) -> Node3D:
	var pool := AffordanceNodes.Volume.new()
	pool.influence = {
		"gravity_scale": 0.22, "speed_scale": 0.62,
		"drag": 2.4, "terminal_fall": 3.5,
	}
	pool.extents = Vector3(1.5, 2.2, 1.5)
	pool.tint = Constants.AFFORDANCE_SIGNAL
	pool.position = origin + Vector3(0, 1.1, 0)
	root.add_child(pool)
	var basin := MeshInstance3D.new()
	var basin_mesh := BoxMesh.new()
	basin_mesh.size = Vector3(1.6, 0.1, 1.6)
	basin.mesh = basin_mesh
	basin.position = origin + Vector3(0, 2.15, 0)
	basin.material_override = ThemeMaterials.glow_material(
			Constants.AFFORDANCE_SIGNAL, 0.5)
	root.add_child(basin)
	_reward(root, "water_volume", origin + Vector3(0, 0.6, 0), reward_id, note)
	return pool

## How high above the rail's own origin the beam sits, and how far above
## the beam the ride volume's centre is. Named because the mesh and the
## volume both derive from them; they used to be two sets of literals
## sitting next to each other.
const RAIL_BEAM_Y := 1.1
const RAIL_RIDE_Y := 2.0
const RAIL_BEAM_THICKNESS := 0.35

## The AUTHORITATIVE geometric path of a rail, in root-local space
## (art requirement 16).
##
## Owner ruling 2026-08-28: `ride_path` is *the authoritative geometric
## path shared by visual mesh and runtime riding geometry* — *"do not
## independently hand-author visual rail and collision/ride path."* The
## beam mesh and the ride volume used to be two hand-written boxes with
## different centres and different sizes that happened to share one
## `length`, which is precisely two authorings of one thing.
##
## A POLYLINE, not a segment, even though today it holds two points. The
## ruling confirmed *one ride volume per straight polyline segment* as
## the integration direction, so a curved authored rail arrives as more
## points and needs no new code — only the wider footprint, which is
## recorded as future expansion rather than a blocker.
static func rail_ride_path(origin: Vector3) -> PackedVector3Array:
	# Bounded by the footprint's own half_depth, so the beam cannot reach
	# past a doorway that `resolve_position` kept its origin clear of.
	var length := 2.0 * float(FOOTPRINT["rail"]["half_depth"]) - 1.0
	var half := length / 2.0
	return PackedVector3Array([
		origin + Vector3(0, RAIL_BEAM_Y, -half),
		origin + Vector3(0, RAIL_BEAM_Y, half),
	])

## A grind rail: a beam with a low-friction lane over it, so a dash along
## it carries much further than a dash on the floor. Both are swept along
## `rail_ride_path`, so they cannot drift apart.
static func _rail(root: Node3D, theme: String, origin: Vector3,
		_depth: float, reward_id: String, note: String) -> Node3D:
	var path := rail_ride_path(origin)
	var built := build_rail_along(root, path)
	var beam: Node3D = built["beams"][0] if not built["beams"].is_empty() \
			else null

	# Posts at the path's ENDS, wherever the path put them.
	for end_point: Vector3 in [path[0], path[path.size() - 1]]:
		_solid(root, Vector3(0.25, RAIL_BEAM_Y, 0.25),
				Vector3(end_point.x, origin.y + RAIL_BEAM_Y / 2.0,
					end_point.z),
				ThemeMaterials.trim_mat(theme), false)

	# On the rail, at its far end: riding it IS how you reach this. Taken
	# from the path rather than recomputed from `length`.
	var far: Vector3 = path[path.size() - 1]
	var approach := (far - path[path.size() - 2]).normalized()
	_reward(root, "rail", far + Vector3(0, 0.5, 0) - approach * 0.6,
			reward_id, note)
	return beam

## Sweep a rail's mesh and its ride volumes along one path.
##
## Separated out so it can be exercised with a MULTI-SEGMENT path. The
## footprint only allows a straight rail today, which means the whole
## polyline claim is untestable through `_rail` -- a two-point path has
## one segment, and a hardcoded length is indistinguishable from a
## derived one when there is only one of them. This is the seam a curved
## authored rail arrives through, so this is what gets tested.
##
## Returns `{"beams": [MeshInstance3D], "lanes": [Volume]}`, one of each
## per segment.
static func build_rail_along(root: Node3D,
		path: PackedVector3Array) -> Dictionary:
	var beams: Array = []
	var lanes: Array = []
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var midpoint := (a + b) * 0.5
		var run := (b - a).length()
		var segment := _solid(root,
				Vector3(RAIL_BEAM_THICKNESS, RAIL_BEAM_THICKNESS, run),
				midpoint,
				ThemeMaterials.glow_material(Constants.AFFORDANCE_SIGNAL, 1.2))
		_aim_along(segment, a, b)
		beams.append(segment)

		# One ride volume per straight segment -- the shape the ruling
		# confirmed. Built from the SAME two points as the mesh above it,
		# so a rail that turns turns underfoot as well as on screen.
		var lane := AffordanceNodes.Volume.new()
		# A real grind: near-frictionless along the rail and a touch of
		# lift, so a dash carries. The previous influence was
		# `{drag: 0.0, speed_scale: 1.0}` -- both the identity element of
		# how the player merges them, so the rail's whole point did
		# nothing at all.
		lane.influence = {"friction_scale": 0.05, "speed_scale": 1.25,
				"gravity_scale": 0.85}
		lane.extents = Vector3(1.1, 1.4, run)
		lane.tint = Constants.AFFORDANCE_SIGNAL
		lane.visible_shell = false
		lane.position = midpoint + Vector3(0, RAIL_RIDE_Y - RAIL_BEAM_Y, 0)
		root.add_child(lane)
		_aim_along(lane, a, b)
		lanes.append(lane)
	return {"beams": beams, "lanes": lanes}

## Point a node's local -Z along a path segment. A no-op for the straight
## rail the footprint currently allows, and the thing that makes a curved
## one work without touching anything above.
static func _aim_along(node: Node3D, from: Vector3, to: Vector3) -> void:
	var run := to - from
	if run.length() < 0.001:
		return
	node.rotation.y = atan2(run.x, run.z)

## An updraft with a perch. Lift only — it can carry you up, never hold
## you down.
static func _wind_volume(root: Node3D, theme: String, origin: Vector3,
		height: float, reward_id: String, note: String) -> Node3D:
	var column := AffordanceNodes.Volume.new()
	# Lift has to BEAT gravity, not merely soften it: at gravity_scale 0.75
	# the column still pulls 18 m/s², so a 16 m/s² updraft is a slightly
	# slower fall dressed up as an updraft.
	column.influence = {"lift": 30.0, "gravity_scale": 0.75,
			"terminal_fall": 6.0}
	var column_height := height - CEILING_GAP
	column.extents = Vector3(1.5, column_height, 1.5)
	column.tint = Constants.AFFORDANCE_SIGNAL
	column.position = origin + Vector3(0, column_height / 2.0, 0)
	root.add_child(column)
	for ring in range(1, 4):
		var mark := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.7
		torus.outer_radius = 0.85
		mark.mesh = torus
		mark.position = origin + Vector3(0, float(ring) * 1.2, 0)
		mark.material_override = ThemeMaterials.glow_material(
				Constants.AFFORDANCE_SIGNAL, 0.7)
		root.add_child(mark)
	# Toward the room's centre, never blindly +x: a perch that always went
	# right sat outside the wall on one side and in the walking lane on the
	# other, and the fallback alternates sides every feature.
	# Directly over the column, not beside it. A perch offset sideways
	# needs its offset PLUS its own half-width of clearance, which pushed
	# the wind volume past the widest corridor the schema allows — and an
	# earlier version offset it blindly toward +x, so it sat outside the
	# wall on one side of the room and in the walking lane on the other.
	# Riding the column up to a platform directly above it is also the
	# clearer read.
	var lip := maxf(OUT_OF_JUMP_REACH, height - CEILING_GAP - 1.4)
	_solid(root, Vector3(1.5, 0.3, 1.5), origin + Vector3(0, lip, 0),
			ThemeMaterials.accent_mat(theme))
	_reward(root, "wind_volume", origin + Vector3(0, lip + 0.75, 0),
			reward_id, note)
	return column

## Base-kit usable: it launches whoever stands on it, item or no item.
static func _bounce_pad(root: Node3D, theme: String, origin: Vector3,
		height: float, reward_id: String, note: String) -> Node3D:
	var pad := AffordanceNodes.BouncePad.new()
	pad.position = origin
	pad.tint = Constants.AFFORDANCE_SIGNAL
	root.add_child(pad)
	# Under the ceiling, and inside the arc the pad actually produces: at
	# LAUNCH 16 and GRAVITY 24 the apex is 5.33 m, so a reward hung at 4.6
	# in a room whose ceiling is at 3.4 was simply inside the slab.
	var apex := AffordanceNodes.BouncePad.LAUNCH * AffordanceNodes.BouncePad.LAUNCH \
			/ (2.0 * Constants.GRAVITY)
	_reward(root, "bounce_pad",
			origin + Vector3(0, minf(apex - 0.6, height - CEILING_GAP - 0.6), 0),
			reward_id, note)
	return pad

## Base-kit usable: it carries whoever stands on it. An `AnimatableBody3D`,
## so Godot's own mover carries the player rather than a bespoke ride.
static func _moving_platform(root: Node3D, theme: String, origin: Vector3,
		height: float, reward_id: String, note: String) -> Node3D:
	var platform := AffordanceNodes.MovingPlatform.new()
	var top := height - CEILING_GAP - 1.9    # room to stand at the top
	platform.travel = Vector3(0, clampf(top - 0.4, 1.6, 3.6), 0)
	platform.position = origin + Vector3(0, 0.4, 0)
	platform.tint = Constants.AFFORDANCE_SIGNAL
	root.add_child(platform)
	# Beside the platform's top, not above it: the reward is what riding it
	# reaches, and one directly overhead is one you cannot stand under.
	_reward(root, "moving_platform",
			origin + Vector3(0, 0.4 + platform.travel.y + 0.9, 0),
			reward_id, note)
	return platform

## One collidable box, which is most of what every feature above is made
## of. Returns the body so a builder can keep it.
static func _solid(parent: Node3D, size: Vector3, at: Vector3,
		material: Material, collide := true) -> Node3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	if not collide:
		mesh_node.position = at
		parent.add_child(mesh_node)
		return mesh_node
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mesh_node)
	body.position = at
	parent.add_child(body)
	return body
