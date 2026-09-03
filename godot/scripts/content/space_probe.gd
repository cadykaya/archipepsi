class_name SpaceProbe
extends RefCounted
## THE ONE REAL-GEOMETRY QUESTION, asked in one place (owner ruling,
## 2026-09-03).
##
## THE GAP THIS CLOSES. `MovementPackage` has had eight call sites in
## this repository and every one of them passed a constant or a
## half-space predicate over a bare-box fixture. The string
## `PhysicsDirectSpaceState3D` never appeared in the file that called it.
## So the offer rules and the geometry they were written to judge had
## never been in the same room, and every offer verdict on record was
## produced by a lambda that said `true`.
##
## Two errors came out of that, and they had DIFFERENT causes, which is
## why this file exists rather than a wider tolerance:
##
##   * `_grapples` walked down in 2 m strides and asked a WINDOW at each
##     step. A window narrower than the stride leaves blind bands, one
##     per step, each `stride - window` wide -- so three physically real
##     anchors over a basin floor were refused because the floor fell
##     between two samples. Widening the window fixes that and makes the
##     other error worse.
##   * A window also reaches PAST the thing it is asked about: `up` above
##     the first sample and `down` below the last, so the same loop
##     accepted hang space shallower than `SWING_ROOM` and ground deeper
##     than `GRAPPLE_DROP`. No window width is correct, because the
##     question was never a window question.
##
## THE FIX IS TO ASK CONTINUOUSLY. A distance, measured once, compared
## against both bounds; a swept column rather than two endpoint samples.
## Nothing here has a stride, and nothing here has a window.
##
## NEVER A VACUOUS PASS. A probe with nowhere to go comes back clean, and
## that is the most dangerous answer a validator can give -- it is how a
## room that never built once reported a clean audit sheet. So a detached
## root or an absent space is REFUSED here, explicitly and by name,
## rather than answered.

## No ground was found. Distinguishable from every real height, including
## a floor at y = 0, which is what a sentinel of 0.0 would have hidden.
const NO_GROUND := -INF

## WHAT TURNS A FOOT-CONTACT POINT INTO A BODY POSE.
##
## A capsule centred on the floor point it stands on is half buried in
## the floor. Every probe in `RoomAudit` that puts a player somewhere
## already adds this lift; naming it here is what stops a launch target
## and an audit stance from holding two views of what standing means.
## The extra 0.05 m is the same skin `RoomAudit._blocked` has always
## used, so a surface built exactly to the minimum is not refused by
## float error.
const SUPPORT_LIFT := Constants.PLAYER_HEIGHT / 2.0 + 0.05

## How finely a swept span is sampled.
##
## The player's own radius: a gap narrower than this cannot admit them,
## so a solid the sweep could hide between two samples is a solid the
## player could not have passed through anyway. This is a resolution,
## NOT a stride with a window -- every sample tests the body itself, and
## consecutive samples overlap by construction.
const SWEEP_STEP := Constants.PLAYER_RADIUS

## Allowance for a contact exactly on a collider face.
##
## A ray whose endpoint lands exactly on a face, or a point lying exactly
## on one, is a case the physics engine may answer either way -- the
## audit's own comments call it a coin toss. A landing surface is
## authored as exactly that contact, so the downward probe starts this
## far above its point to make an on-face contact land the same way every
## run. The reach BELOW the point stays exact.
const CONTACT_EPS := 0.001

## Why this room cannot be measured, or "" when it can.
##
## Both halves matter and they fail differently: a room outside the scene
## tree has no colliders registered, and a space that is null has nothing
## to ask. Either one answers every query with "nothing there", which
## reads as clean.
static func refusal(root: Node3D, space: PhysicsDirectSpaceState3D,
		who := "offers") -> String:
	if space == null:
		return ("%s: cannot be validated -- no physics space was " % who
				+ "supplied, so every probe would come back clean")
	if root == null or not root.is_inside_tree():
		return ("%s: cannot be validated -- the room is not in the " % who
				+ "scene tree, so its colliders are not registered and "
				+ "every probe would come back clean")
	return ""

## THE FIRST GROUND AT OR BELOW `at`, or `NO_GROUND`.
##
## Not a window. The ray starts `CONTACT_EPS` above `at` so a point
## resting exactly on a face is deterministic, and ends exactly `reach`
## below it -- so a caller asking for `GRAPPLE_DROP` cannot be handed
## ground `down` metres past it.
static func ground_below(space: PhysicsDirectSpaceState3D, at: Vector3,
		reach: float) -> float:
	if space == null:
		return NO_GROUND
	var query := PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * CONTACT_EPS, at + Vector3.DOWN * reach)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NO_GROUND
	return (hit["position"] as Vector3).y

## Does the player's own capsule fit, centred here?
##
## Slightly slimmer than the player for the same reason
## `RoomAudit._blocked` is: an opening built exactly to the minimum must
## not be refused by float error. Content the composer PLACED is ignored
## -- a crate is furniture, and a room is not wrong because something was
## put in it.
static func body_fits(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> bool:
	return _obstruction(space, at) == null

## Does the player fit STANDING ON `foot`, allowing for the step they
## are taking onto it?
##
## THE DISTINCTION THAT MATTERS. A traversal endpoint sits at the lip of
## the thing it leaves or arrives on, so the riser beside it is within a
## body radius of it by nature -- and testing the whole capsule there
## refuses every endpoint in every stepped room, which is the lesson
## `TraversalLaw.boxes_fit` already carries: "a ledge under
## `MAX_VERTICAL_STEP` is something the player steps onto; testing the
## whole capsule would refuse every node within a radius of every
## riser." So only the body ABOVE step height is asked about, which is
## the real question: is there room where a step cannot help.
##
## `body_fits` stays the whole capsule, for anchors and landings, where
## nothing is being stepped onto and the full envelope is the claim.
static func stance_fits(space: PhysicsDirectSpaceState3D,
		foot: Vector3) -> bool:
	return stance_obstruction(space, foot) == null

## The collider blocking that stance, or null.
static func stance_obstruction(space: PhysicsDirectSpaceState3D,
		foot: Vector3) -> Node:
	if space == null:
		return null
	var above: float = Constants.PLAYER_HEIGHT \
			- Constants.MAX_VERTICAL_STEP
	var capsule := CapsuleShape3D.new()
	capsule.radius = Constants.PLAYER_RADIUS - 0.02
	capsule.height = above
	return _shape_obstruction(space, capsule, foot + Vector3.UP
			* (Constants.MAX_VERTICAL_STEP + 0.05 + above / 2.0))

## The collider blocking the body at `at`, or null.
##
## Returned as the node rather than a bool so a diagnostic can NAME what
## is in the way. A reason without a subject sends whoever has to fix it
## looking.
static func obstruction(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> Node:
	return _obstruction(space, at)

## The blocking collider's name, or "" -- for a message.
static func blocker_name(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> String:
	var node := _obstruction(space, at)
	return "" if node == null else node.name

## THE BODY POSE that stands on `foot`.
##
## The owner's ruling in one line: an authored landing point names the
## FLOOR, and the body that stands on it is centred `SUPPORT_LIFT` above.
static func stand_pose(foot: Vector3) -> Vector3:
	return foot + Vector3.UP * SUPPORT_LIFT

## Is the whole span from `from` to `to` clear for the player's body?
##
## SWEPT, not sampled at the ends. Two endpoint samples say nothing about
## the middle, and the middle is where a beam crosses a swing column.
## `Placement`-style step sampling rather than `cast_motion`, because
## `cast_motion` reports the fraction of a path a shape can travel and
## returns "all of it" for a shape that starts clear and ends clear --
## which a 0.4 m jamb between two open points is.
static func column_is_clear(space: PhysicsDirectSpaceState3D,
		from: Vector3, to: Vector3) -> bool:
	return first_obstruction_along(space, from, to) == null

## The first blocking collider along a span, or null. Same sweep as
## `column_is_clear`, kept as one implementation so the diagnostic and
## the verdict cannot disagree.
static func first_obstruction_along(space: PhysicsDirectSpaceState3D,
		from: Vector3, to: Vector3) -> Node:
	if space == null:
		return null
	var span := from.distance_to(to)
	var steps := maxi(1, int(ceil(span / SWEEP_STEP)))
	for i in steps + 1:
		var at := from.lerp(to, float(i) / float(steps))
		var node := _obstruction(space, at)
		if node != null:
			return node
	return null

## The point along a span where the body is first blocked, or `NO_GROUND`
## in `x` when nothing blocks. Reported so a message can say WHERE.
static func first_block_point(space: PhysicsDirectSpaceState3D,
		from: Vector3, to: Vector3) -> Variant:
	if space == null:
		return null
	var span := from.distance_to(to)
	var steps := maxi(1, int(ceil(span / SWEEP_STEP)))
	for i in steps + 1:
		var at := from.lerp(to, float(i) / float(steps))
		if _obstruction(space, at) != null:
			return at
	return null

## Is `at` clear of solid geometry for a shape of `radius`?
##
## For a rail BEAM rather than a body: a beam is thinner than a player
## and its own half-thickness is what has to clear, so asking the
## player's capsule about it would refuse routes a beam fits through and
## pass routes it does not.
static func sphere_is_clear(space: PhysicsDirectSpaceState3D, at: Vector3,
		radius: float) -> bool:
	return _sphere_obstruction(space, at, radius) == null

## The collider a sphere of `radius` at `at` touches, or null.
static func sphere_obstruction(space: PhysicsDirectSpaceState3D,
		at: Vector3, radius: float) -> Node:
	return _sphere_obstruction(space, at, radius)

static func _obstruction(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> Node:
	if space == null:
		return null
	var capsule := CapsuleShape3D.new()
	capsule.radius = Constants.PLAYER_RADIUS - 0.02
	capsule.height = Constants.PLAYER_HEIGHT - 0.04
	return _shape_obstruction(space, capsule, at)

static func _sphere_obstruction(space: PhysicsDirectSpaceState3D,
		at: Vector3, radius: float) -> Node:
	if space == null:
		return null
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius, 0.01)
	return _shape_obstruction(space, sphere, at)

static func _shape_obstruction(space: PhysicsDirectSpaceState3D,
		shape: Shape3D, at: Vector3) -> Node:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), at)
	query.collide_with_areas = false
	for hit: Dictionary in space.intersect_shape(query, 8):
		var node := hit.get("collider") as Node
		if not is_placed_content(node):
			return node
	return null

## Something the composer PUT in the room, rather than the room itself.
##
## Shared with `RoomAudit`, which asked the same question and owned the
## only answer. A crate standing where an offer is declared is not the
## room being wrong.
static func is_placed_content(collider: Variant) -> bool:
	var node := collider as Node
	while node != null:
		if node is ActivityElement:
			return true
		if node.is_in_group(DestructibleCover.GROUP):
			return true
		node = node.get_parent()
	return false
