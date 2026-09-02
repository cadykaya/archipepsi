class_name LaunchSolver
extends RefCounted
## A directed ballistic traversal edge, solved rather than authored (P3.0).
##
## THE RULE THIS EXISTS FOR: *"A LaunchPad must not contain a
## hand-authored arbitrary velocity vector."* Given a source, a
## destination and gravity, the trajectory is DERIVED -- so a pad that
## has been moved lands where it says it lands, and a pad that cannot
## reach its destination says so instead of firing the player at a wall.
##
## WHY IT IS NOT A BOUNCE PAD. A bounce pad is a local vertical
## opportunity: it launches you up, and where you come down is your
## problem. A launch pad is an EDGE -- source and destination are both
## part of the contract, and the pad exists to cross a distance that
## walking cannot. Both stay, because they are different offers.
##
## A READABLE ARC, NOT MINIMUM TIME. The ballistics have a family of
## solutions and the fast flat one is the worst of them: it reads as
## being shot, it gives the player no time to see where they are going,
## and it clears nothing. So the apex is CHOSEN -- a fixed clearance over
## the higher end -- and the launch velocity follows from it. That also
## makes the solution unique, which is what makes it deterministic.
##
## NO ECHO REQUIRED. The map provides this movement, so the solve uses
## nothing but gravity, the two endpoints and the player's own
## dimensions. A traversal the base kit cannot use is a traversal that
## cannot be mandatory (`docs/design-packet-v0.10` NO REQUIREMENT BEFORE
## GUARANTEE), and this one can be.

## How far above the higher endpoint the arc peaks. Enough to read as an
## arc from the ground, and enough that ordinary architecture between the
## ends is cleared rather than grazed.
const APEX_CLEARANCE := 3.5

## How many points the arc is sampled at for validation and drawing. ONE
## number, so the arc that is checked is the arc that is drawn.
const ARC_SAMPLES := 24

## The furthest a single launch may throw the player. A pad that crosses
## more than this is describing a Zone, not a room.
const MAX_RANGE := 80.0

## How forgiving the landing has to be. A pad the player can miss by
## leaning on the stick is a pad that reads as broken, so the declared
## landing region must be at least this wide -- the validator refuses a
## pad whose target is a pinpoint rather than trusting the player to
## stop steering.
const MIN_LANDING_RADIUS := 2.5

## Solve the launch from `source` to `target`.
##
## Returns `{velocity, time, apex, ok}`; `ok` false with a `reason` when
## the pair cannot be connected at all.
static func solve(source: Vector3, target: Vector3,
		gravity := Constants.GRAVITY) -> Dictionary:
	if gravity <= 0.0:
		return {"ok": false, "reason": "gravity must be positive"}
	var span := source.distance_to(target)
	if span < 0.5:
		return {"ok": false,
				"reason": "source and target are the same place"}
	if span > MAX_RANGE:
		return {"ok": false,
				"reason": "%.1f m is past the %.0f m a launch may cover"
					% [span, MAX_RANGE]}
	var apex := maxf(source.y, target.y) + APEX_CLEARANCE
	# Up from the source to the apex, then down from the apex to the
	# target. Both halves are free fall, so each is a square root and the
	# flight time is their sum -- no solver, no iteration, no seed.
	var rise := apex - source.y
	var fall := apex - target.y
	if rise <= 0.0 or fall <= 0.0:
		return {"ok": false, "reason": "the apex does not clear both ends"}
	var up_speed := sqrt(2.0 * gravity * rise)
	var time := up_speed / gravity + sqrt(2.0 * fall / gravity)
	var flat := Vector3(target.x - source.x, 0.0, target.z - source.z)
	return {"ok": true, "velocity": flat / time + Vector3.UP * up_speed,
			"time": time, "apex": apex, "reason": ""}

## The arc that solve produced, as points. Deterministic, and the same
## samples the validator walks and the pad draws.
static func arc(source: Vector3, velocity: Vector3, time: float,
		gravity := Constants.GRAVITY) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in ARC_SAMPLES + 1:
		var t := time * float(i) / float(ARC_SAMPLES)
		out.append(source + velocity * t
				+ Vector3.DOWN * (0.5 * gravity * t * t))
	return out

## Every way this launch is not usable. Empty is a pad that may be built.
##
## `clear` answers "does the player's body fit at this point" and is the
## caller's, for the same reason `Placement.find` takes one: the audit
## has a physics space and a composer building a detached chamber does
## not. `supported` answers "is there ground under the landing".
##
## THE ORDER MATTERS. An unsolvable pair is reported as unsolvable rather
## than as an obstructed arc, because they send whoever has to fix it to
## different places.
static func violations(source: Vector3, target: Vector3,
		landing_radius: float, clear: Callable, supported: Callable,
		who := "launch_pad") -> Array[String]:
	var out: Array[String] = []
	var shot := solve(source, target)
	if not bool(shot.get("ok", false)):
		out.append("%s: cannot be solved: %s"
				% [who, str(shot.get("reason", "?"))])
		return out
	if landing_radius < MIN_LANDING_RADIUS:
		out.append("%s: a %.2f m landing region is smaller than the "
				% [who, landing_radius] + "%.2f m a player can be "
				% MIN_LANDING_RADIUS + "trusted to hit")
	var points := arc(source, shot["velocity"] as Vector3,
			float(shot["time"]))
	# The first sample is the pad itself and would report the pad as an
	# obstruction; the arc has to LEAVE the source before it is asked to
	# be clear of it.
	for i in points.size():
		if i == 0:
			continue
		if not bool(clear.call(points[i] as Vector3)):
			out.append("%s: the arc is obstructed %.0f%% of the way "
					% [who, 100.0 * float(i) / float(points.size() - 1)]
					+ "along it, at %v" % points[i])
			break
	var landed: Vector3 = points[points.size() - 1]
	if landed.distance_to(target) > 0.05:
		out.append("%s: the solved arc ends at %v, not the %v it "
				% [who, landed, target] + "was aimed at")
	if not bool(clear.call(target)):
		out.append("%s: the landing region at %v has no room for the "
				% [who, target] + "player")
	if not bool(supported.call(target)):
		out.append("%s: the landing region at %v has nothing under it"
				% [who, target])
	return out
