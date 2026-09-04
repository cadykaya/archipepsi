class_name RailRider
extends RefCounted
## Riding a rail: entry, travel, and getting off (P3.0).
##
## A STATE MACHINE, NOT A CUTSCENE. While riding, the player's position
## is the path's and their speed is theirs -- gravity still acts along
## the rail, so a climb costs speed and a drop pays it back, and a rail
## you enter too slowly drops you off part way up. What the rider takes
## away is lateral control; what it never takes away is the sense of
## moving under momentum you brought.
##
## PURE ON PURPOSE. This owns no node, reads no input singleton and
## touches no scene. It is handed a position, a velocity and a delta, and
## it hands back a position, a velocity and whether the ride continues.
## That is what lets the whole of B be driven headlessly, deterministic
## and frame-exact, instead of being provable only by a human on a
## controller.
##
## ONE PATH. Every query goes to the `RailPath` it was caught on; there
## is no second copy of the shape here to fall out of step with the beam
## the player can see.

## How close the player must be to the path to catch it, and how far
## below the path their feet may be. Generous laterally -- a rail you
## have to thread is a rail nobody rides -- and tight vertically, so
## walking under one does not snatch you off the floor.
const CATCH_RADIUS := 1.6
const CATCH_BELOW := 2.2

## THE RAIL DRIVES. A grind rail is powered, not a frictionless wire, and
## that is a progression requirement rather than a taste: the map
## provides rails, so a route through one may be MANDATORY, and a
## mandatory route must be completable by a player who owns nothing
## (NO REQUIREMENT BEFORE GUARANTEE). A purely ballistic rail is not --
## the first draft of this file was, and a walking player stalled a third
## of the way up a six-metre climb.
##
## So the rail holds a target pace, slope shifts that target, and the
## speed you ARRIVE with rides on top of it and bleeds away. Fast entry
## is rewarded, slow entry still finishes, and the ride still reads as
## momentum rather than as a lift.
const DRIVE_SPEED := 9.0

## How far the target moves per unit of slope. At the steepest legal
## pitch the target is still above `MIN_SPEED`, which is what makes
## "every legal rail is completable" true by construction rather than by
## hoping about numbers.
const SLOPE_BIAS := 5.0

## The band the ride is held inside. `MIN_SPEED` is the floor the drive
## maintains on the steepest legal climb; `MAX_SPEED` stops a long
## descent from becoming a projectile nobody can aim.
const MIN_SPEED := 4.0
const MAX_SPEED := 22.0

## How quickly speed converges on the target, per second. Slow enough
## that the momentum you brought is still yours for a second or two.
const SETTLE := 1.6

## What the player keeps of the speed they arrive with. Entering slowly
## still works -- the drive takes over -- which is exactly what stops the
## rail being usable only by a player who owns a movement Echo.
const ENTRY_KEEP := 0.9

## How far above the path the rider's body sits, so they read as ON the
## rail rather than inside it.
const STAND_OFFSET := 1.0

var path: RailPath = null
var offset := 0.0
var speed := 0.0
## +1 rides toward the far end, -1 back toward the start.
var heading := 1

## THE ROOM'S OWN FRAME. ONE authored path, one derived transform.
##
## The path is room-local, because it is the authored offer and it is
## what gets parented into the room. The player's position and velocity
## are world. This compared the two directly and then handed local path
## positions back as world player positions -- so in a placed Zone a rail
## could be caught from across the map and, once caught, teleported the
## player to wherever the room's local coordinates happened to point.
##
## A DERIVED TRANSFORM, NEVER A SECOND PATH. Translating or rotating a
## room may not change which rail it is: the semantic rail is the
## authored one, and this is only how to look at it from outside.
var to_world := Transform3D.IDENTITY

## Can this player catch this rail right now, and where?
##
## THREE CONDITIONS, and each is a real failure it prevents. Near enough
## -- or a rail catches you across the room. Not already past an end --
## or the far post grabs you as you fall past it. Moving with some
## component ALONG the path -- or walking sideways into a rail launches
## you down it, which reads as the room shoving you.
##
## Returns `{}` when the rail cannot be caught, so the caller has one
## thing to test rather than a bool plus out-parameters.
static func catch(rail: RailPath, position: Vector3,
		velocity: Vector3, to_world := Transform3D.IDENTITY) -> Dictionary:
	if rail == null or not rail.violations().is_empty():
		return {}
	var span := rail.length()
	if span <= 0.0:
		return {}
	# ONE FRAME FOR THE COMPARISON. The player arrives in world; the path
	# lives in the room. Both are brought into the room's frame here --
	# rather than the path into the world -- so the offsets, tangents and
	# arc lengths below stay the authored ones.
	var into_room := to_world.affine_inverse()
	var local_at := into_room * position
	var local_go := into_room.basis * velocity
	var here := rail.nearest_offset(local_at)
	var on_path := rail.at(here)
	var gap := Vector2(local_at.x - on_path.x,
			local_at.z - on_path.z).length()
	if gap > CATCH_RADIUS:
		return {}
	var drop := on_path.y - local_at.y
	if drop > CATCH_BELOW or drop < -CATCH_BELOW:
		return {}
	var along := rail.tangent(here)
	var pace := local_go.dot(along)
	if absf(pace) < 0.5:
		return {}
	var rider := RailRider.new()
	rider.path = rail
	rider.to_world = to_world
	rider.offset = here
	rider.heading = 1 if pace > 0.0 else -1
	rider.speed = clampf(maxf(absf(pace) * ENTRY_KEEP, DRIVE_SPEED),
			MIN_SPEED, MAX_SPEED)
	# Caught at an end, already heading off it: that is falling past a
	# post, not mounting a rail.
	if (here <= 0.0 and rider.heading < 0) \
			or (here >= span and rider.heading > 0):
		return {}
	return {"rider": rider, "offset": here, "speed": rider.speed,
			"heading": rider.heading}

## Where the rider's body goes for this offset, IN WORLD SPACE -- which
## is the frame the player's own position is in.
func body_position() -> Vector3:
	return to_world * (path.at(offset) + Vector3.UP * STAND_OFFSET)

## Which way the ride is travelling, as a WORLD unit vector.
##
## The basis is a rotation, so this preserves length and the speeds below
## mean the same thing in either frame; what it does fix is the direction
## the player is actually pushed, which a yawed room otherwise sent off
## by exactly that yaw.
func facing() -> Vector3:
	return to_world.basis * (path.tangent(offset) * float(heading))


## One physics step of the ride.
##
## Returns `{position, velocity, riding, reason}`. `riding` false means
## the player has left the rail and `velocity` is what they leave with --
## momentum, never a stop, because a grind that ends in a dead drop is a
## grind nobody uses twice.
func advance(delta: float, jump := false) -> Dictionary:
	var span := path.length()
	var along := facing()
	# THE TARGET THIS SLOPE SUSTAINS. `along.y` is the sine of the pitch
	# in the direction of travel, so a climb lowers the target and a
	# descent raises it, from ONE expression rather than an if.
	var target := clampf(DRIVE_SPEED - along.y * SLOPE_BIAS,
			MIN_SPEED, MAX_SPEED)
	# Toward it, never snapped to it: the speed you arrived with is still
	# yours for a moment, which is the difference between a grind and a
	# conveyor belt.
	speed = lerpf(speed, target, clampf(SETTLE * delta, 0.0, 1.0))
	speed = clampf(speed, MIN_SPEED, MAX_SPEED)

	if jump:
		# Off, upward, and still carrying the ride. The rail's own
		# direction plus a normal jump: a dismount is a jump you take
		# from a moving floor.
		return _leave(along * speed
				+ Vector3.UP * Constants.JUMP_VELOCITY, "jumped")

	offset = clampf(offset + speed * float(heading) * delta, 0.0, span)
	if offset <= 0.0 or offset >= span:
		# Off the end, still moving the way the rail pointed.
		return _leave(to_world.basis
				* (path.tangent(offset) * float(heading)) * speed,
				"end")
	return {"position": body_position(), "velocity": along * speed,
			"riding": true, "reason": ""}

func _leave(velocity: Vector3, why: String) -> Dictionary:
	return {"position": body_position(), "velocity": velocity,
			"riding": false, "reason": why}
