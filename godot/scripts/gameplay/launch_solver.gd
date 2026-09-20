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

## How far below a declared endpoint a refusal looks for the surface it
## MISSED.
##
## The contact test itself is `SpaceProbe.CONTACT_EPS` and nothing else.
## This distance exists only so the message can say WHICH surface the
## point floats over and by how much -- "no ground within 1.0 m" sent
## whoever had to fix it looking for a missing floor when the floor was
## right there, half a metre down. Deeper than any room in the library is
## tall, so a point over a real floor always names it; a point over
## nothing at all is reported as exactly that.
const CONTACT_REPORT_REACH := 40.0

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

## Why this declared foot-contact point is not touching the surface under
## it, or "" when it is.
##
## A CONTACT TEST, NOT A STEP TEST (F-1, 2026-09-03). `content.py` says
## both `launch_source.position` and `launch_target.position` ARE the
## foot-contact centre. The check that guarded them asked for ground
## within `Constants.MAX_VERTICAL_STEP` -- a full metre of permitted
## daylight under a point the schema calls contact. The schema and the
## probe held two views of one word, and the yard's pad hovered 0.5 m
## over `yd_floor` through every gate in the project: its trigger box
## started at knee height, its mesh floated, and the capture teleported
## the player half a metre into the air before firing.
##
## So the tolerance is `SpaceProbe.CONTACT_EPS` -- the same on-face
## allowance the probe already uses so that a ray landing exactly on a
## face answers the same way twice -- and the test is a COMPARISON: the
## declared world height against the height actually hit. Not a range, not
## a step, and no second meaning of the word.
##
## `at` is already in WORLD space. This measures the ground and nothing
## else: whether a body fits where the point implies one stands is a
## separate question, asked separately, so a buried endpoint is refused
## by the check that can name the solid it is buried in.
static func off_surface(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> String:
	var hit := SpaceProbe.ground_below(space, at, CONTACT_REPORT_REACH)
	if hit == SpaceProbe.NO_GROUND:
		return ("there is no surface at all within %.0f m under it"
				% CONTACT_REPORT_REACH)
	var gap := at.y - hit
	if absf(gap) <= SpaceProbe.CONTACT_EPS:
		return ""
	var floor_node := SpaceProbe.ground_collider(space, at,
			CONTACT_REPORT_REACH)
	return "it floats %.4f m over %s" % [gap,
			("the surface below" if floor_node == null
				else floor_node.name)]

## Every way this launch is not usable. Empty is a pad that may be built.
##
## A LAUNCH TARGET NAMES THE FLOOR, NOT THE BODY (owner ruling,
## 2026-09-03).
##
## This is the convention that was missing, and its absence was about to
## manufacture three false findings. A `launch_target` is an authored
## LANDING SURFACE -- a foot-contact point, sitting exactly on the top
## face of a deck, a gantry or a catwalk. `clear` was documented as "does
## the player's body fit at this point", and a body centred on a floor
## point is half buried in that floor, so every correctly authored
## landing in the library would have been refused for having no room in
## it. Sabotaged and confirmed: dropping the lift refuses a landing on a
## clean deck face at 96% along its own arc.
##
## So the floor point is proven to BE floor, the body pose is derived
## from it with `SpaceProbe.stand_pose`, and the arc is flown between
## body poses -- because an arc is the path of a body, and a trajectory
## that starts and ends at ankle height clips the very surfaces it leaves
## from and arrives at. A target buried in the interior of a solid still
## fails, and fails on the body pose, which is the case this must keep
## refusing.
##
## THE ORDER MATTERS. An unsolvable pair is reported as unsolvable rather
## than as an obstructed arc, because they send whoever has to fix it to
## different places.
## AUTHORED LOCAL IN, WORLD PHYSICS OUT. Both feet are room-local
## floor-contact points; `to_world` is the live room's own transform, and
## every probe and the whole trajectory happen on the far side of it.
## Messages name the LOCAL point, because that is the number an artist
## can find.
static func violations(source_foot: Vector3, target_foot: Vector3,
		landing_radius: float, space: PhysicsDirectSpaceState3D,
		to_world := Transform3D.IDENTITY,
		who := "launch_pad", source_radius := 0.0) -> Array[String]:
	var out: Array[String] = []
	# THE RESERVATION MUST HOLD THE MECHANISM. `launch_source.radius` is
	# the floor set aside for the consuming package to build in -- so the
	# one thing it has to be big enough for is the thing that gets built.
	# It is NOT a set of places the flight may begin from: exactly one
	# trajectory is validated, from `position`, and the runtime captures
	# the player to it.
	if source_radius > 0.0 \
			and source_radius < AffordanceNodes.LaunchPad.PAD_REACH:
		out.append("%s: a %.2f m reservation cannot hold the launch pad, "
				% [who, source_radius] + "which reaches %.2f m from its "
				% AffordanceNodes.LaunchPad.PAD_REACH + "centre")
	var source := SpaceProbe.stand_pose(to_world * source_foot)
	var target := SpaceProbe.stand_pose(to_world * target_foot)
	# THE PAD ITSELF MUST BE STANDABLE. A source buried in a slab or
	# hanging in mid-air is a pad nobody can step onto, and nothing
	# checked it: the arc skips its own first sample by design, so the
	# one place the source was ever looked at was the place it was
	# excluded from.
	var under := off_surface(space, to_world * source_foot)
	if under != "":
		out.append("%s: the launch source at %v is not a foot-contact "
				% [who, source_foot] + "point: %s" % under)
	var on_pad := SpaceProbe.obstruction(space, source)
	if on_pad != null:
		out.append("%s: a player standing on the launch source at %v "
				% [who, source_foot] + "does not fit; their body is "
				+ "inside %s" % on_pad.name)
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
		var blocker := SpaceProbe.obstruction(space, points[i] as Vector3)
		if blocker != null:
			out.append("%s: the arc is obstructed %.0f%% of the way "
					% [who, 100.0 * float(i) / float(points.size() - 1)]
					+ "along it, at %v (%s)"
					% [to_world.affine_inverse() * (points[i] as Vector3),
						blocker.name])
			break
	var landed: Vector3 = points[points.size() - 1]
	if landed.distance_to(target) > 0.05:
		out.append("%s: the solved arc ends at %v, not the %v it "
				% [who, landed, target] + "was aimed at")
	# THE AUTHORED POINT MUST BE THE FLOOR ITSELF, not a point hovering
	# over one -- same test as the source, because the schema gives both
	# words the same meaning.
	var ground := off_surface(space, to_world * target_foot)
	if ground != "":
		out.append("%s: the landing point at %v is not a foot-contact "
				% [who, target_foot] + "point: %s" % ground)
	# AND THE BODY THAT STANDS ON IT MUST FIT. This is what refuses a
	# target buried inside a slab: its derived stance is inside the slab
	# too, and no lift rescues it.
	var standing := SpaceProbe.obstruction(space, target)
	if standing != null:
		out.append("%s: a player standing on the landing point at %v "
				% [who, target_foot] + "does not fit; their body at %v "
				% (to_world.affine_inverse() * target)
				+ "is inside %s" % standing.name)
	return out
