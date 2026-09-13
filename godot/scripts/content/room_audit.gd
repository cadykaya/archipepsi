class_name RoomAudit
extends RefCounted
## Does the room's geometry agree with what the room CLAIMS? (P1)
##
##     AUTHOR-DECLARED METADATA IS A CLAIM.
##     GODOT MEASUREMENT IS AUTHORITY.
##
## `room_contract.gd` checks that a room output is well FORMED. This
## checks that it is TRUE, and the two are unrelated failures: a `stand`
## socket with a perfectly valid position and extent can be a rectangle
## of empty air, and every structural check in the project would pass it.
##
## WHY IT HAS TO BE PROBES. This repository has now paid three times for
## trusting a description over the world:
##
##   * a pit whose recess was dug under an intact floor slab -- the
##     bounds dropped, the sockets sat below zero, a ray from INSIDE the
##     recess found its deck, and the pit was a sealed basement. Nothing
##     asked what a ray from ABOVE hits first.
##   * a band's access ramp 6.8 m long, which occupancy classified as
##     architecture and therefore could not see, so the way up was the
##     one invisible obstacle in the room.
##   * `platform_path` activities laid out against a nominal floor that
##     does not exist, over a kill pit.
##
## Every one of those was a self-consistent description. So this file
## never reads a claim to confirm another claim; it puts a ray, a shape
## or a capsule into the instantiated scene and reports what came back.
##
## PRODUCER-AGNOSTIC BY CONSTRUCTION. It takes a room OUTPUT and a
## physics space. It cannot tell, and must never be able to tell, whether
## a builder or an artist produced what it is measuring.
##
## THE ROOM MUST BE IN THE TREE. A detached node has no colliders
## registered, and a probe against one comes back clean because there is
## nothing there to hit -- which is the most dangerous possible false
## pass. `measure` refuses rather than reporting a clean sheet.

## How far a measured surface may sit from its declared height. Generous
## enough for float error and a 0.1 m lip; far tighter than the
## difference between standing on a floor and falling past it.
const HEIGHT_TOLERANCE := 0.15

## How far below a declared point support may be and still count as
## "under it" -- the same number the Zone audit uses for the same
## question, so the two cannot drift.
const GROUND_REACH := 1.2

## How far back from a declared jump endpoint to probe for support.
##
## The endpoints of a gap ARE the edges it is measured between -- moving
## them inward would inflate the span and refuse legal jumps -- so the
## probe steps back onto the surface instead. A ray at exactly the
## boundary of a collider is a coin toss.
const EDGE_INSET := 0.15

## Probe sizes, from the player's real capsule so they cannot drift from
## the thing they protect.
const HEADROOM := Constants.PLAYER_HEIGHT + 0.6

## How far a MEASURED movement may exceed a movement law before it is a
## different movement (P2).
##
## A measurement is not a declaration. A rise or a span is read off two
## ray hits against imported vertex data, and a .glb stores positions as
## quantised floats -- so a step an artist modelled at exactly 1.0 m
## measures 1.000039 m, and `1.000039 > 1.0` refuses a step the movement
## law explicitly permits. `MAX_VERTICAL_STEP` means the player CAN take
## a 1.0 m step; an audit that refuses the step at the limit is refusing
## the law it exists to enforce.
##
## ONE SLACK, TWO COMPARISONS. The span check has always carried a bare
## `+ 0.01` and the rise check carried nothing, so the same function held
## two views of how exact a measurement is -- which is how the eight
## authored shells produced a rise finding on the two stairs whose
## vertices happened to round up and none on the twenty-eight identical
## ones that rounded down. Naming it once is the point.
##
## 1 cm, and it stays 1 cm: the authored vocabulary steps in whole
## metres and the procedural one in `MAX_VERTICAL_STEP` units, so no
## real over-step in this project is anywhere near this small. A rise
## that genuinely exceeds the base kit exceeds it by tens of
## centimetres, and is still refused.
## ONE NUMBER, wherever it is read. The tolerance moved into
## `TraversalLaw` with the movement law it belongs to; this stays as its
## name here because the suite and the comments above reach for it, and
## two constants holding one idea is how they come to disagree.
const AS_BUILT_SLACK := TraversalLaw.AS_BUILT_SLACK

## Every way the room's geometry contradicts the room's claims.
##
## `space` must belong to a world the room is actually inside.
static func findings(result: Variant, space: PhysicsDirectSpaceState3D,
		who := "room") -> Array[String]:
	var out: Array[String] = []
	if typeof(result) != TYPE_DICTIONARY:
		return ["%s: no room to measure" % who]
	var room: Dictionary = result
	var root := room.get("root") as Node3D
	if root == null:
		return ["%s: no root to measure" % who]
	if space == null:
		return ["%s: no physics space; a probe with nowhere to go comes "
				% who + "back clean, which is the wrong kind of pass"]
	if not root.is_inside_tree():
		return ["%s: the room is not in the scene tree, so nothing it "
				% who + "contains has a collider to hit"]

	var to_world := root.global_transform
	var surfaces := RoomContract.sockets_of(room, "stand")
	out.append_array(_surfaces_hold_weight(surfaces, to_world, space, who))
	out.append_array(_points_have_ground(room, surfaces, to_world, space,
			who))
	out.append_array(_arrivals_are_standable(room, to_world, space, who))
	out.append_array(_openings_are_holes(room, to_world, space, who))
	out.append_array(_assigned_doors_match_their_usage(room, to_world,
			space, who))
	out.append_array(_arrival_is_safe(room, to_world, space, who))
	out.append_array(_traversal_is_true(room, to_world, space, who))
	out.append_array(_geometry_stays_inside_its_bounds(room, root, who))
	return out

# --- 1. a declared walkable surface holds weight ---------------------------

## CAN THIS SURFACE KEEP ITS PROMISE? (owner ruling C(ii))
##
## A `stand` Surface offers a bounded region and promises that a valid
## placement can be FOUND somewhere in it -- not that every point of it
## is clear. So this asks `Placement.find` for one, with the footprint of
## the consumer a `stand` surface exists for: a player, standing.
##
## WHAT CHANGED, AND WHAT DID NOT. The previous version sampled nine
## points and reported every one that failed, which reads `stand` as
## "every point is standable". Measured against the eight authored
## shells, that refused a ground floor for passing under its own
## staircase and a rubble stone for being overhung by the next stone --
## real architecture, 40 to 100 per cent usable. It ALSO refused three
## surfaces with nothing usable anywhere, and those must keep failing.
## Asking for ONE placement instead of demanding all of them separates
## exactly those two, and does it geometrically: there is a footprint
## that fits, or there is not. No percentage is a law here.
##
## THE SEALED PIT IS STILL THE HEADROOM CHECK. The pit's deck sat 1.66 m
## under an intact floor slab, and what makes that unwalkable is that a
## 1.8 m player does not fit in 1.66 m. Under the new reading the pit
## fails for the same reason it always did: there is nowhere in it a
## player fits. HEADROOM is the number `ElevationBand` validates at
## parse, so the schema and the probe cannot hold different views of what
## standing up requires.
##
## ONE SEARCH, TWO CONSUMERS. `Activities` calls the same
## `Placement.find` over the same candidates in the same order, with its
## own element footprint and its own evidence. If these two ever answer
## differently about the same region the contract is broken, and
## `_test_the_audit_and_the_composer_agree_about_a_surface` is what says
## so out loud.
static func _surfaces_hold_weight(surfaces: Array,
		to_world: Transform3D, space: PhysicsDirectSpaceState3D,
		who: String) -> Array[String]:
	var out: Array[String] = []
	for socket: Variant in surfaces:
		var patch: Dictionary = socket
		var at: Vector3 = patch["position"]
		var extent: Vector3 = patch.get("extent", Vector3.ONE)
		var named := str(patch.get("name", "?"))
		var stands := func(spot: Vector3) -> bool:
			return player_stands_here(spot, to_world, space)
		var verdict := Placement.find(at, extent, STANCE, 0.0, stands, true)
		if bool(verdict.get("fits", false)):
			continue
		if str(verdict.get("reason", "")) == "too_small":
			out.append("%s: walkable surface '%s' is %.2f x %.2f, and a "
					% [who, named, extent.x, extent.z]
					+ "player is %.2f across" % STANCE.x)
			continue
		out.append("%s: walkable surface '%s' at %v offers nowhere a "
				% [who, named, at] + "player can stand: %s"
				% _why_not(at, extent, to_world, space))
	return out

## The box a standing player claims: their own capsule, squared off.
const STANCE := Vector3(Constants.PLAYER_RADIUS * 2.0,
		Constants.PLAYER_HEIGHT, Constants.PLAYER_RADIUS * 2.0)

## Support at the declared height, and room to stand up on it.
##
## PUBLIC because `Activities.can_place` is its opposite number and the
## suite has to be able to ask them both the same question about the same
## spot. The two see differently -- rays here, boxes there -- and that is
## survivable; answering differently is not.
static func player_stands_here(spot: Vector3, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D) -> bool:
	var world := to_world * spot
	var down := _ray(space, world + Vector3.UP * 0.4,
			world + Vector3.DOWN * GROUND_REACH)
	if down.is_empty():
		return false
	if absf(world.y - (down["position"] as Vector3).y) > HEIGHT_TOLERANCE:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	var box := Placement.clearance(spot, STANCE, HEADROOM)
	shape.size = box.size
	query.shape = shape
	query.transform = Transform3D(to_world.basis,
			to_world * (box.position + box.size * 0.5))
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()

## WHY a surface offered nothing, for the person who has to fix it.
##
## Diagnostic only -- it changes no verdict. The finding above is already
## decided; this says whether the region was empty air, at the wrong
## height, or roofed, because "offers nowhere to stand" sends an artist
## looking at three different things.
static func _why_not(at: Vector3, extent: Vector3, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D) -> String:
	var missing := 0
	var wrong := 0.0
	var wrong_n := 0
	var roofed := 0
	var spots := Placement.candidates(at, extent, STANCE)
	for spot: Vector3 in spots:
		var world := to_world * spot
		var down := _ray(space, world + Vector3.UP * 0.4,
				world + Vector3.DOWN * GROUND_REACH)
		if down.is_empty():
			missing += 1
			continue
		var measured: float = (down["position"] as Vector3).y
		if absf(world.y - measured) > HEIGHT_TOLERANCE:
			wrong += measured
			wrong_n += 1
			continue
		roofed += 1
	if missing == spots.size():
		return "there is nothing under it"
	if wrong_n == spots.size():
		return "it measures y=%.2f, not the y=%.2f it declares" \
				% [wrong / float(wrong_n), at.y]
	return "%d of %d spots sit at the right height and none has %.2f m " \
			% [roofed, spots.size(), HEADROOM] + "of headroom"

# --- 2. a placement point has something to place onto ----------------------

## Cover, barrels and elevated stances are single points, and each is an
## OFFER the composer may take. An offer standing in mid-air or buried in
## a wall is the builder telling the composer something untrue.
static func _points_have_ground(room: Dictionary, surfaces: Array,
		to_world: Transform3D, space: PhysicsDirectSpaceState3D,
		who: String) -> Array[String]:
	var out: Array[String] = []
	for kind: String in RoomContract.POINT_KINDS:
		for socket: Variant in RoomContract.sockets_of(room, kind):
			var patch: Dictionary = socket
			var local: Vector3 = patch["position"]
			var world := to_world * local
			var down := _ray(space, world + Vector3.UP * 0.3,
					world + Vector3.DOWN * GROUND_REACH)
			if down.is_empty():
				out.append("%s: a '%s' socket at %v has nothing under it"
						% [who, kind, local])
				continue
			if _buried(space, world + Vector3.UP * 0.45, 0.5):
				out.append("%s: a '%s' socket at %v is inside solid "
						% [who, kind, local] + "geometry")
				continue
			var named := str(patch.get("surface_id", ""))
			if named == "":
				continue
			var wanted := INF
			for other: Variant in surfaces:
				if str((other as Dictionary).get("name", "")) == named:
					wanted = ((other as Dictionary)["position"] as Vector3).y
			if wanted == INF:
				out.append("%s: a '%s' socket names surface '%s', which "
						% [who, kind, named] + "the room does not declare")
			elif absf(local.y - wanted) > GROUND_REACH:
				out.append("%s: a '%s' socket says it is on surface '%s' "
						% [who, kind, named] + "at y=%.2f and sits at "
						% wanted + "y=%.2f" % local.y)
	return out

# --- 3. the places the game PUTS things are standable ----------------------

## Every enemy spawn and the reward pedestal. These are not offers -- the
## game puts something there whatever the room thinks -- so a spawn point
## inside a wall is an enemy inside a wall, and a reward pocket in a void
## is a Check the player cannot reach.
static func _arrivals_are_standable(room: Dictionary,
		to_world: Transform3D, space: PhysicsDirectSpaceState3D,
		who: String) -> Array[String]:
	var out: Array[String] = []
	var places: Array = [["the reward position",
			room.get("reward_position", Vector3.ZERO)]]
	for spawn: Variant in room.get("enemy_spawns", []) as Array:
		if typeof(spawn) == TYPE_DICTIONARY:
			places.append(["an enemy spawn",
					(spawn as Dictionary).get("position", Vector3.ZERO)])
	for place: Array in places:
		var local: Vector3 = place[1]
		var world := to_world * local
		if _buried(space, world + Vector3.UP * (Constants.PLAYER_HEIGHT
				/ 2.0), Constants.PLAYER_RADIUS * 2.0):
			out.append("%s: %s at %v is inside solid geometry"
					% [who, str(place[0]), local])
			continue
		# Deliberately a long reach: a spawn is allowed to be dropped
		# from a little height, and the failure being caught is a void,
		# not a step.
		var down := _ray(space, world + Vector3.UP * 0.6,
				world + Vector3.DOWN * 4.0)
		if down.is_empty():
			out.append("%s: %s at %v has no floor beneath it"
					% [who, str(place[0]), local])
	return out

# --- 4. an opening is a hole ----------------------------------------------

## Mesh IS collider in this project, so a doorway that was modelled and
## not cut is a wall the chain believes is a door -- and the player finds
## out standing in front of it. Swept with the player's own capsule
## through the entry plane and the exit plane, which is where the two
## rooms actually meet.
static func _openings_are_holes(room: Dictionary, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D, who: String) -> Array[String]:
	var out: Array[String] = []
	var bounds: AABB = room["bounds"]
	var exit_at: Vector3 = room["exit_offset"]
	# THE DOOR IS ON THE WALL, AND `exit_offset` IS NOT ALWAYS THE WALL.
	# It is where the NEXT ROOM'S ORIGIN goes, which for most builders is
	# the same point and for a tower is deliberately 2.2 m past the back
	# face -- a summit landing needs the next room pushed clear. Probing
	# `exit_offset` therefore measured a point in mid-air outside the
	# tower and called its perfectly good summit door sealed. The
	# producer-agnostic statement is the room's own +Z boundary at the
	# height the exit leaves from.
	#
	# THE ENTRY IS WHERE THE ROOM SAYS IT IS (owner ruling, 2026-09-03).
	# This read `Vector3(0, 0, bounds.position.z)` -- the origin -- for
	# every room, because every room that existed when it was written
	# happened to be entered there. A room entered at its top or along
	# its side measured as having a sealed door in a solid wall, and the
	# message blamed the geometry for an assumption in the probe.
	#
	# NO FLOOR IS REQUIRED UNDER A CONNECTOR. It is an attachment
	# transform on the envelope and may sit slightly outside it -- the
	# yard's is 0.4 m past its own west wall -- so the ground ray below
	# stays a CONVENIENCE that recentres the stance on a thick slab, and
	# its absence is not a finding. Whether the player's body is safe
	# where it arrives is `player_entry`'s question, asked separately in
	# `_arrival_is_safe`.
	var entry_at: Vector3 = room.get("entry_offset",
			RoomContract.LEGACY_ENTRY)
	# OUTWARD FROM THE ROOM, for both doors and by the same rule: a
	# connector's aperture is tested on the side the neighbour arrives
	# from. Stated as "away from the middle of the room" rather than as a
	# fixed axis, which is what made it wrong for a side entry -- and for
	# a room entered at its origin this is exactly the -Z it always was.
	for door: Array in [
			["the entry", entry_at, _outward(entry_at, bounds)],
			["the exit", Vector3(exit_at.x, exit_at.y, bounds.end.z),
				Vector3.BACK]]:
		var at: Vector3 = door[1]
		var into: Vector3 = door[2]
		# From just outside the plane to just inside it. Short on
		# purpose: this asks whether the OPENING is open, not whether the
		# room is walkable end to end -- a `platform_path` is not, by
		# design, and a walkability prover is a different tool.
		# STAND WHERE THE FLOOR IS, measured. The declared exit height is
		# not always a walking plane: a tower's landing slab is 0.5 m
		# thick and CENTRED on the height its `exit_offset` names, so a
		# capsule placed at that height starts 0.25 m inside the deck and
		# every summit door in the game measured as sealed. Finding the
		# floor first is the same move the Zone audit's floor probe makes,
		# for the same reason.
		var ground := _ray(space, to_world * (at + Vector3.UP * 1.0),
				to_world * (at + Vector3.DOWN * 1.0))
		var base := at.y
		if not ground.is_empty():
			base = (to_world.affine_inverse()
					* (ground["position"] as Vector3)).y
		var stance := Vector3.UP * (base - at.y
				+ Constants.PLAYER_HEIGHT / 2.0 + 0.05)
		# ON the plane and just inside it. Two stances rather than a
		# swept motion: `cast_motion` reports the fraction of a path a
		# shape can travel and quietly returns "all of it" for a shape
		# that starts clear and ends clear, which a 0.4 m door jamb
		# between two open points is. Asking "does the player FIT here"
		# is the question, and it has one answer.
		for step: float in [0.0, 0.45]:
			if _blocked(space, to_world * (at + into * step + stance)):
				out.append("%s: %s at %v is sealed; the player's own "
						% [who, str(door[0]), at]
						+ "capsule does not fit through it")
				break
	return out

# --- 4b. every assigned door is what it was declared to be ----------------

## THE SAME MEASUREMENT, WITH THE EXPECTED ANSWER FROM THE DECLARATION.
##
## `_openings_are_holes` asks one question of two fixed doors and always
## wants the same answer. A composed room has N doors and two answers:
## `USED` and `LOCKED` carve an aperture, `SEALED` does not.
##
## **A sealed door is checked HARDER, never skipped.** Skipping it is the
## tempting shortcut and it is the recurring defect this project keeps
## finding -- a measurement that exists, is correct, and is never handed
## the case that fails it. A sealed door that is accidentally a hole is a
## way past a lock, and if the probe is skipped it is indistinguishable
## in the report from one that is correctly solid.
## IS EACH DECLARED DOOR A HOLE? The measurement, without the verdict.
##
## **Architectural, not "can the player walk through right now".** A
## `LOCKED` door is a slab standing in an aperture that IS carved, and
## the two are different facts: the hole is the architecture and the lock
## is content placed in it. `_blocked` skips placed content -- a
## `LockedDoor` included -- so a locked door measures as the hole it is,
## and whether it currently stops the player is the lock's business and
## is reported separately.
##
## Returns `socket_id -> passes`, one entry per declared door, `SEALED`
## ones included: a door the layout does not report is refused by the
## bridge rather than skipped, which is what makes the probe inverted
## rather than optional.
## THE WHOLE LAYOUT'S EVIDENCE, measured once, in one place.
##
## `apertures` and `arrival_ok` are what the bridge refuses a layout on,
## and only the engine can see the geometry they are about. Living
## inside `ZoneController` meant only a live played Zone could produce
## them -- so a harness that composed twenty Zones and sent their
## manifests off to the validator had every one of them refused for
## carrying no measurement, which says nothing about the layouts and
## everything about the harness. The Zone's root must be in the tree and
## settled; `space` is `get_world_3d().direct_space_state`.
static func measure_layout(build: Dictionary,
		space: PhysicsDirectSpaceState3D) -> Dictionary:
	var apertures := {}
	for entry: Dictionary in build.get("chambers", []):
		var rid := str((entry["chamber"] as Dictionary).get("id", ""))
		var measured := aperture_polarity(entry["build"] as Dictionary,
				entry["xform"] as Transform3D, space)
		for socket: String in measured:
			apertures["%s/%s" % [rid, socket]] = bool(measured[socket])
	# THE RETURN ANCHOR IS SETTLED BEFORE IT IS REPORTED.
	#
	# `ChamberBuilders.return_spot` reserves against the room's own
	# furniture, which is what §5.7 asks for and is not the same as
	# standing somewhere. A room with a chasm, a sunken bay or a floor
	# the builder does not model as furniture can offer a spot that
	# reserves cleanly and holds no body -- and the bridge refuses the
	# WHOLE layout for it. Measured in a live campaign: "a standing
	# capsule does not fit at 'room:c003:return'", nine times, five
	# Zones discarded. So where reservation ends, the probe begins.
	var placement := _settle_return_anchors(build, space)
	var arrival_ok := {}
	for name: String in build.get("anchors", {}):
		arrival_ok[name] = arrival_is_supported(space,
				(build["anchors"] as Dictionary)[name])
	return {"apertures": apertures, "arrival_ok": arrival_ok,
			"plug_clear": plugs_clear_of_arrivals(build),
			# WHAT THE ENGINE FOUND WHEN IT PLACED EACH RETURN, and the
			# bounded search it ran. `plug_clear` answers "is THIS
			# position clear"; only this says whether a position was
			# found at all -- and only `NO_CANDIDATE` is a statement
			# about the ROOM. See `PLACEMENT_*`.
			"plug_placement": placement}

## THE PLACEMENT OUTCOME CONTRACT, and it is ONE contract.
##
## A room was being barred from branch selection on `plug_clear ==
## false`, and that boolean cannot tell "nothing was measured" from
## "this position is bad" from "no position works". This says which,
## PER PLUG, and `layout.py` branches on it:
##
## | outcome | means | the bridge (`AMALGAM_BRIDGE.md` 5.9) |
## |---|---|---|
## | *(no entry)* | this payload predates the field | the check does not apply |
## | `NO_EVIDENCE` | the engine measured nothing | refuse; do not bar |
## | `NO_CANDIDATE` | the declared bounded search finished and nothing held | refuse **and bar the host** |
## | `PLACED` | a position with support and clearance | nothing |
##
## **KEYED BY `edge_id`, NOT BY ROOM**, and spelled the way `layout.py`
## spells it. This producer wrote `MEASURED` / `REPAIRED` /
## `NO_EVIDENCE` / `NO_CANDIDATE` keyed by ROOM id while the consumer
## read its own set keyed by EDGE id -- two vocabularies for one fact
## across one wire, which is a contract that cannot be true. Measured on
## the far side: a `NO_CANDIDATE` in this shape was ACCEPTED, so a Zone
## committed with a return device that was never placed. A room-keyed
## report is now REFUSED rather than ignored, which is how the mismatch
## stayed silent.
##
## `MEASURED` and `REPAIRED` COLLAPSE INTO `PLACED`: the device is
## placed, and which position it ended on is diagnostic. That rides
## along as `repaired` and `how`.
##
## ABSENCE IS FOR OLDER CLIENTS, AND THIS ONE IS NOT ONE. An engine that
## speaks this contract says `NO_EVIDENCE` when it measured nothing
## rather than saying nothing at all -- silence is reserved for a
## payload that predates the field, and a current client falling silent
## would be indistinguishable from one. What must never be sent is a
## malformed entry: a present-but-unreadable report is refused, not read
## as absence, which is why the outcome is written from the constants
## below and never assembled from a string.
##
## `searched`, `probed` and `policy` are for the log: what search ran
## and how much of it. No exhaustive proof of impossibility is asked for
## -- but a `NO_CANDIDATE` that enumerated nothing is a bug and not a
## verdict, so the two counts are separate and both are sent.
const PLACEMENT_PLACED := "PLACED"
const PLACEMENT_NO_EVIDENCE := "NO_EVIDENCE"
const PLACEMENT_NO_CANDIDATE := "NO_CANDIDATE"

## Where the settle looks for standable ground: a LATTICE around the
## room's arrival, not a ring.
##
## A ring at four and seven metres finds nothing in a corridor seven
## metres wide -- every bearing but two is outside the envelope, and the
## two that are not are the ones the ring steps over. Measured: nine
## refusals of `room:c003:return` before and nine after, byte for byte.
## Offsets on both axes, nearest first, so a narrow room is served by
## its long axis and a wide one by whichever is clear.
##
## Every offset is at least the device's trigger plus a capsule from the
## arrival, so a spot this finds cannot be one the player is standing on
## when they walk in -- which is the defect the whole anchor exists for.
## `ReturnPlug.RADIUS` (1.4) plus `PLAYER_RADIUS` (0.4) is 1.8, so 2.5
## is the nearest offset that still leaves a body at the arrival outside
## the trigger -- and a small room needs a near one or it has no
## candidates at all: `played_zone`'s `c012` had none at three metres.
const RETURN_OFFSETS := [2.5, -2.5, 3.5, -3.5, 5.0, -5.0, 8.0, -8.0]

## Moves each `room:<rid>:return` anchor onto ground a body can stand on,
## when the reserved spot is not. Bounded: sixteen probes, the room's own
## envelope, and the first that holds -- and if none does, the anchor is
## left exactly where the builder put it and the bridge refuses the
## layout, which is the honest outcome and not a silent one.
##
## The plug NODE moves with the anchor. Publishing one place and standing
## the device in another is two truths about one thing.
static func _settle_return_anchors(build: Dictionary,
		space: PhysicsDirectSpaceState3D) -> Dictionary:
	var report := {}
	var anchors: Dictionary = build.get("anchors", {})
	var rooms: Dictionary = build.get("rooms", {})
	for name: String in anchors.keys():
		if not name.begins_with("room:") or not name.ends_with(":return"):
			continue
		var rid := name.substr(5, name.length() - 12)
		var placed: Dictionary = rooms.get(rid, {})
		# ONE SOURCE FOR THE ARRIVAL, and the published one.
		#
		# This read `rooms[rid].arrival` while `plugs_clear_of_arrivals`
		# read `anchors["room:<rid>:arrival"]` -- two places holding one
		# fact, and a control that removed one of them got a "missing
		# evidence" verdict from the settle and a measured boolean from
		# the clearance. The ANCHOR is what the bridge validates, so the
		# anchor is what both ask; the committed transform is the
		# fallback for a build that predates it.
		var published: Variant = anchors.get("room:%s:arrival" % rid)
		if published == null:
			published = placed.get("arrival")
		if placed.is_empty() or published == null:
			# NOTHING TO MEASURE AGAINST, AND THE REPORT SAYS SO.
			#
			# `NO_EVIDENCE`, not silence: the bridge refuses the layout
			# -- an unmeasured return is not a placed one -- and does
			# NOT bar the room, because nothing was learned about it.
			# Silence would mean something else entirely, "this client
			# predates the field", and a current engine claiming that
			# about itself is the one thing absence must never cover.
			_say_placement(report, build, rid, {
					"outcome": PLACEMENT_NO_EVIDENCE, "searched": 0,
					"probed": 0,
					"why": "no published arrival anchor to measure against"})
			continue
		var box: AABB = placed.get("bounds", AABB())
		var from: Vector3 = published
		# SUPPORT **AND** CLEARANCE, and the second one is the fix.
		#
		# This skipped the search whenever the current anchor was
		# standable -- so a pad on solid ground two metres from the
		# arrival, well inside its own trigger, was left exactly where
		# it was and reported `plug_clear = false`. The candidate was
		# repairable and the room was barred for it.
		if arrival_is_supported(space, anchors[name]) \
				and clear_of_arrival(anchors[name], from):
			_say_placement(report, build, rid, {
					"outcome": PLACEMENT_PLACED, "repaired": false,
					"searched": 0, "probed": 0,
					"how": "the position the builder reserved"})
			continue
		var moved := Vector3.INF
		# THE ROOM'S OWN DECLARED GROUND FIRST, probed in world space.
		#
		# A lattice around the arrival keeps the arrival's HEIGHT, and
		# `platform_path` is rising islands over a kill pit: every
		# candidate at the start ledge's height is over the void, which
		# is why `played_zone`'s `c012` refused its layout however wide
		# the lattice got. The room already declares which square metres
		# hold weight; the farthest one that holds a capsule and leaves
		# a body at the arrival outside the trigger is the answer.
		var clearance := ReturnPlug.RADIUS + Constants.PLAYER_RADIUS
		var best_gap := clearance
		var examined := 0
		# HOW MUCH OF THE DECLARED SEARCH RAN, in two numbers, because
		# one of them cannot tell a finished search from an absent one.
		#
		# `probed` counts physics queries -- positions actually put to
		# the world. `searched` counts every candidate the bounded
		# search enumerated, admissible or not. A `NO_CANDIDATE` with
		# `searched: 0` is a search that never ran and a report that
		# should never have been written; `searched: 16, probed: 0` is a
		# room whose envelope holds none of the lattice, which is a real
		# and reportable answer. The missing `dz = 0` below was the
		# first kind wearing the second kind's clothes, and no field in
		# the report said so.
		var searched := 0
		for raw: Variant in build.get("chambers", []):
			var entry: Dictionary = raw
			if str((entry["chamber"] as Dictionary).get("id", "")) != rid:
				continue
			var to_world: Transform3D = entry["xform"]
			for raw_socket: Variant in (entry["build"] as Dictionary) \
					.get("sockets", []):
				if typeof(raw_socket) != TYPE_DICTIONARY:
					continue
				var surface: Dictionary = raw_socket
				if str(surface.get("kind", "")) != "stand":
					continue
				var at: Vector3 = to_world * (surface.get("position",
						Vector3.ZERO) as Vector3)
				searched += 1
				var gap := Vector2(at.x - from.x, at.z - from.z).length()
				if gap < clearance or gap < best_gap:
					continue
				examined += 1
				if arrival_is_supported(space, at) \
						and clear_of_arrival(at, from):
					moved = at
					best_gap = gap
		if moved != Vector3.INF:
			_stand_the_device(build, anchors, name, rid, moved)
			_say_placement(report, build, rid, {
					"outcome": PLACEMENT_PLACED, "repaired": true,
					"searched": searched, "probed": examined,
					"how": "a declared stand"})
			continue
		var inside := box.grow(-0.6)
		# BOTH AXES INCLUDE ZERO, and leaving it off one of them cost
		# every corridor in the game its return.
		#
		# The comment above `RETURN_OFFSETS` promises "a narrow room is
		# served by its long axis". The inner loop offered `dx = 0`; the
		# outer loop never offered `dz = 0`, so every candidate was at
		# least 2.5 m off the arrival ON BOTH AXES -- and in a room 8 m
		# long and 4 m wide, `bounds.grow(-0.6)` is 2.8 m deep, so every
		# one of them fell outside the envelope before it was probed.
		# MEASURED: a corridor 8.0 x 4.0, a vault and a shaft each
		# reported `NO_CANDIDATE` with `tried: 0` -- the search never
		# ran a single query, and `tried: 0` is what says so. The one
		# outcome that bars a host was being reported for ordinary rooms
		# with metres of clear floor down their length.
		#
		# `(0, 0)` is the arrival itself, which is not a candidate and
		# is not counted as one.
		var lattice: Array = ([0.0] as Array) + RETURN_OFFSETS
		for dz: float in lattice:
			if moved != Vector3.INF:
				break
			for dx: float in lattice:
				if is_zero_approx(dx) and is_zero_approx(dz):
					continue
				searched += 1
				var at := from + Vector3(float(dx), 0.0, dz)
				if not inside.has_point(at):
					continue
				examined += 1
				if arrival_is_supported(space, at) \
						and clear_of_arrival(at, from):
					moved = at
					break
		if moved == Vector3.INF:
			# SAY SO, because the bridge's refusal names the anchor and
			# not the reason. A room over a kill pit -- `platform_path`
			# is rising islands and two narrow ledges -- can have NO
			# ground that both holds a capsule and leaves a body at the
			# arrival outside the device's trigger. That is a composition
			# question (should such a room host a return at all?) and not
			# a placement one, and the engine refusing is the contract
			# working rather than the contract failing.
			push_warning("zone: no standable spot in room '%s' is clear "
					% rid + "of its arrival, so its return device has "
					+ "nowhere to stand; the layout will be refused")
			# THE ONE OUTCOME THAT IS ABOUT THE ROOM, and it says what
			# it searched rather than claiming impossibility: this many
			# candidates, the room's own declared stands and a lattice
			# bounded by `RETURN_OFFSETS` inside the committed envelope.
			#
			# WHICH OF THE TWO REFUSALS, and the difference is whether
			# the declared search could run at all. A room with no
			# committed envelope has no lattice to bound -- there is
			# nothing to search INSIDE -- so nothing was established
			# about the room and `NO_EVIDENCE` is the honest word.
			# `NO_CANDIDATE` is the one outcome with teeth and it may
			# only be said of a search that finished.
			_say_placement(report, build, rid, {
					"outcome": PLACEMENT_NO_CANDIDATE if box.has_volume()
						else PLACEMENT_NO_EVIDENCE,
					"searched": searched, "probed": examined,
					"policy": {"offsets": RETURN_OFFSETS,
						"clearance": clearance,
						"inside": "committed bounds less 0.6 m"}})
			continue
		_stand_the_device(build, anchors, name, rid, moved)
		_say_placement(report, build, rid, {
				"outcome": PLACEMENT_PLACED, "repaired": true,
				"searched": searched, "probed": examined,
				"how": "a probed lattice"})
	return report

## Files one placement outcome under EVERY plug the room hosts.
##
## The search is per ROOM -- one return position, whoever asks for it --
## and the contract is per PLUG, because that is the identity
## `layout.py` iterates and the identity a `PlugAssignment` carries. A
## room with no plug says nothing: there is no device whose placement it
## would be about.
static func _say_placement(report: Dictionary, build: Dictionary,
		rid: String, told: Dictionary) -> void:
	for raw: Variant in build.get("plugs", []):
		if not is_instance_valid(raw as Object):
			continue
		var plug: ReturnPlug = raw
		if str(plug.get_meta("room_id", "")) == rid:
			report[plug.edge_id] = told.duplicate()

## Publishes an anchor and moves the device standing on it together.
## One place, because publishing one and standing the other somewhere
## else is two truths about one thing.
static func _stand_the_device(build: Dictionary, anchors: Dictionary,
		name: String, rid: String, at: Vector3) -> void:
	anchors[name] = at
	for raw: Variant in build.get("plugs", []):
		if not is_instance_valid(raw as Object):
			continue
		var plug: ReturnPlug = raw
		if str(plug.get_meta("room_id", "")) == rid:
			plug.global_position = at

## IS A BODY AT THE ROOM'S ARRIVAL OUTSIDE THE RETURN DEVICE?
##
## `AMALGAM_BRIDGE.md` §5.7 rule 4b, and the question is deliberately
## about a BODY and not about two points. `ReturnPlug`'s trigger is a
## cylinder of `RADIUS` by `HEIGHT` standing on the device; a player is
## a capsule of `PLAYER_RADIUS` by `PLAYER_HEIGHT` standing on the
## arrival. They overlap when the horizontal gap is less than the two
## radii together AND the two vertical spans meet -- which is the
## `Area3D` would actually report, arithmetic rather than a guess.
##
## One entry per plug, keyed by edge id. Missing is a refusal on the
## bridge side, so a plug whose room published no arrival still gets an
## answer here: `false`, because nothing was shown to be clear.
static func plugs_clear_of_arrivals(build: Dictionary) -> Dictionary:
	var out := {}
	var anchors: Dictionary = build.get("anchors", {})
	for raw: Variant in build.get("plugs", []):
		if not is_instance_valid(raw as Object):
			continue
		var plug: ReturnPlug = raw
		var room := str(plug.get_meta("room_id", ""))
		var arrive: Variant = anchors.get("room:%s:arrival" % room)
		if arrive == null:
			# NO ENTRY AT ALL, rather than `false`.
			#
			# `false` here meant "measured, and a body at the arrival
			# stands inside the device" -- a fact about a POSITION, and
			# the bridge bars a host on it. Writing it when there was no
			# arrival to measure against made MISSING EVIDENCE
			# indistinguishable from a measured failure, and a room
			# could be removed from branch selection because its anchor
			# had not been published. Rule 4b already refuses a layout
			# whose plug carries no measurement; that refuses the
			# LAYOUT, which is right, and does not condemn the ROOM.
			continue
		var at: Vector3 = arrive
		var here := plug.global_position if plug.is_inside_tree() \
				else plug.position
		out[plug.edge_id] = clear_of_arrival(here, at)
	return out

## Is a body standing at `arrival` outside the device standing at `at`?
##
## The trigger is a cylinder of `RADIUS` by `HEIGHT`; the body is a
## capsule of `PLAYER_RADIUS` by `PLAYER_HEIGHT`. They miss each other
## when the horizontal gap covers both radii, or when the two vertical
## spans do not meet -- which is what the `Area3D` itself would report.
static func clear_of_arrival(at: Vector3, arrival: Vector3) -> bool:
	var flat := Vector2(arrival.x - at.x, arrival.z - at.z).length()
	var apart := flat >= ReturnPlug.RADIUS + Constants.PLAYER_RADIUS
	var above := arrival.y >= at.y + ReturnPlug.HEIGHT
	var below := arrival.y + Constants.PLAYER_HEIGHT <= at.y
	return apart or above or below

static func aperture_polarity(room: Dictionary, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D) -> Dictionary:
	var out := {}
	for raw: Variant in room.get("doors", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw
		var at: Vector3 = door["position"]
		var stance := _door_stance(to_world, space, at)
		# INWARD, because a room's own doors are measured from inside it.
		var inward := _inward(at, room["bounds"] as AABB)
		var blocked := false
		for step: float in [0.0, 0.45]:
			if _blocked(space, to_world * (at + inward * step + stance)):
				blocked = true
				break
		out[str(door["socket_id"])] = not blocked
	return out

## Where a body stands to be measured in this doorway.
##
## Stand where the floor is: an aperture's sill is not always the height
## its socket names. Shared by the polarity reading and the blocker
## reading, because two stances for one doorway is how a report and the
## refusal it explains come to disagree.
static func _door_stance(to_world: Transform3D,
		space: PhysicsDirectSpaceState3D, at: Vector3) -> Vector3:
	var ground := _ray(space, to_world * (at + Vector3.UP * 1.0),
			to_world * (at + Vector3.DOWN * 1.0))
	var base := at.y
	if not ground.is_empty():
		base = (to_world.affine_inverse()
				* (ground["position"] as Vector3)).y
	return Vector3.UP * (base - at.y + Constants.PLAYER_HEIGHT / 2.0
			+ 0.05)

static func _assigned_doors_match_their_usage(room: Dictionary,
		to_world: Transform3D, space: PhysicsDirectSpaceState3D,
		who: String) -> Array[String]:
	var out: Array[String] = []
	# ONE MEASUREMENT, TWO CONSUMERS. The audit turns it into a
	# violation; the layout result puts it on the wire. Two probes for
	# one question is how the report and the refusal come to disagree.
	var measured := aperture_polarity(room, to_world, space)
	for raw: Variant in room.get("doors", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw
		var want_open := bool(door["passable"])
		var blocked := not bool(measured.get(str(door["socket_id"]), true))
		if want_open and blocked:
			out.append("%s: door '%s' is %s and must be passable, but "
					% [who, str(door["socket_id"]), str(door["usage"])]
					+ "the player's own capsule does not fit through it")
		elif not want_open and not blocked:
			out.append("%s: door '%s' is SEALED and must be solid, but "
					% [who, str(door["socket_id"])]
					+ "the player's own capsule passes straight through it")
	return out

## Toward the middle of the room from a point on its shell.
static func _inward(at: Vector3, bounds: AABB) -> Vector3:
	var middle := bounds.get_center()
	var away := Vector3(at.x - middle.x, 0.0, at.z - middle.z)
	if absf(away.x) >= absf(away.z):
		return Vector3(-signf(away.x), 0, 0)
	return Vector3(0, 0, -signf(away.z))

# --- 5. a declared movement is the movement the geometry makes -------------

## The claim an artist is most likely to get wrong and least likely to
## notice, because a jump that is 20% too far still looks fine in the
## viewport. Measured ends, measured span, measured rise, against the
## same `max_safe_gap` a `platform_path` has always been held to.
static func _traversal_is_true(room: Dictionary, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D, who: String) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in room.get("traversal", []) as Array:
		var seg: Dictionary = entry
		var name := str(seg.get("name", "?"))
		var kind := str(seg.get("kind", "walk"))
		var start: Vector3 = seg.get("start", Vector3.ZERO)
		var end: Vector3 = seg.get("end", Vector3.ZERO)
		# Stepped back onto each surface, away from the other end.
		var away := Vector3(end.x - start.x, 0.0, end.z - start.z)
		away = away.normalized() * EDGE_INSET if away.length() > 0.001 \
				else Vector3.ZERO
		var ends := {"start": start - away, "end": end + away}
		var landed := {}
		for label: String in ends:
			var world: Vector3 = to_world * (ends[label] as Vector3)
			var down := _ray(space, world + Vector3.UP * 0.4,
					world + Vector3.DOWN * GROUND_REACH)
			if down.is_empty():
				out.append("%s: traversal '%s' %ss where there is "
						% [who, name, label] + "nothing to stand on")
			else:
				var floor_y: float = (to_world.affine_inverse()
						* (down["position"] as Vector3)).y
				# STANDABLE, NOT MERELY OVER SOMETHING (owner ruling,
				# 2026-09-03). A ray answers "is there a surface below",
				# and a surface below is not a destination -- the plenum
				# declares three collar endpoints on the axis of eight
				# metres of hanging machine, and a ray at the declared
				# height is answered by the collar while the player's
				# body has nowhere to be. This runs on EVERY segment,
				# optional ones included: an optional destination is
				# still a claim about where a player can get to.
				var in_the_way := _nowhere_to_stand(space, to_world,
						ends[label] as Vector3, floor_y)
				if in_the_way != "":
					out.append("%s: traversal '%s' %ss at %v, where "
							% [who, name, label, ends[label]]
							+ "the ground holds but there is nowhere "
							+ "within a step of it the player's own "
							+ "body fits (%s)" % in_the_way)
				landed[label] = (down["position"] as Vector3).y
		if kind == "gap" and landed.size() == 2:
			# A gap you can walk across is not a gap, and a room that
			# declares one is describing a jump the player never makes.
			var mid := to_world * ((start + end) * 0.5)
			var bridged := _ray(space, mid + Vector3.UP * 0.4,
					mid + Vector3.DOWN * GROUND_REACH)
			if not bridged.is_empty():
				out.append("%s: traversal '%s' is declared a gap and "
						% [who, name] + "has floor across it")
		if not bool(seg.get("mandatory", true)) or landed.size() < 2:
			continue
		# MEASURED ENDPOINTS, not declared ones. The heights come from
		# the rays above, so a manifest that lies within the drift
		# tolerance is still judged on what was actually built -- the
		# property that caught two stairs measuring 1.000039 m.
		var built_start := Vector3(start.x, float(landed["start"]), start.z)
		var built_end := Vector3(end.x, float(landed["end"]), end.z)
		# THE SAME LAW `ShellValidator` RUNS, with rays instead of mesh
		# boxes. One statement of what each kind claims; two ways of
		# seeing. A walk is measured as GROUND CONTINUITY rather than as
		# a jump between its endpoints, which is what a walk is.
		# THE RAY MUST REACH A LEGAL STEP DOWN. At 2.0 m total it looked
		# from 1.2 m above the reference to 0.8 m below it, so a floor
		# exactly one `MAX_VERTICAL_STEP` lower -- a step the base kit
		# takes every day -- was out of its reach and read as a void.
		# That is what made `shell_tower_spiral`'s deck walk look
		# disconnected across a strip 1.0 m below it.
		var ground := func(at: Vector3) -> float:
			var world := to_world * at
			var hit := _ray(space, world + Vector3.UP * 1.2,
					world + Vector3.DOWN
						* (Constants.MAX_VERTICAL_STEP + 0.4))
			if hit.is_empty():
				return -INF
			return (to_world.affine_inverse()
					* (hit["position"] as Vector3)).y
		# THE PLAYER'S OWN BODY, not just a floor ray (P3.5A). This is
		# the final authority: real physics, real capsule, and a witness
		# node only where a player could actually stand.
		# ONLY THE BODY ABOVE STEP HEIGHT. A ledge under
		# `MAX_VERTICAL_STEP` is something the player steps onto; testing
		# the whole capsule would refuse every node within a radius of
		# every riser, and a lattice needs a node either side of one to
		# cross it. What is left is the real question: is there room
		# where a step cannot help.
		var above := Constants.PLAYER_HEIGHT - Constants.MAX_VERTICAL_STEP
		var fits := func(at_floor: Vector3) -> bool:
			var query := PhysicsShapeQueryParameters3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = Constants.PLAYER_RADIUS
			shape.height = above
			query.shape = shape
			query.transform = Transform3D(to_world.basis, to_world
					* (at_floor + Vector3.UP
						* (Constants.MAX_VERTICAL_STEP + 0.05
							+ above / 2.0)))
			query.collide_with_areas = false
			return space.intersect_shape(query, 1).is_empty()
		for problem: String in TraversalLaw.violations(kind, built_start,
				built_end, ground, "%s: traversal '%s'" % [who, name],
				RoomContract.sockets_of(room, "stand"), fits):
			out.append(problem)
	return out

# --- 6. the room fits in the box it reserved ------------------------------

## Rooms are chained by butting their bounds together, so geometry
## outside them is geometry inside the neighbour.
##
## EVERY mesh, not just the furniture-scale ones. The first version
## reused `solid_boxes`, which SKIPS room-scale geometry so a placement
## solver has somewhere to stand -- and a room's walls are exactly the
## geometry that can reach into the neighbour, so the check that mattered
## was the one being skipped. The authored-only `_check_envelope` looked
## at all of them and was therefore the only thing measuring this at all,
## which is how it came to refuse eight authored shells for a rule no
## procedural room obeyed either.
##
## The allowance is `RoomContract.WALL_ALLOWANCE` -- one shared number,
## one shared convention, both producers.
static func _geometry_stays_inside_its_bounds(room: Dictionary,
		root: Node3D, who: String) -> Array[String]:
	var out: Array[String] = []
	var bounds: AABB = room["bounds"]
	var roomy := RoomContract.envelope(bounds)
	var worst := 0.0
	var count := 0
	for box in ShellValidator.mesh_boxes(root, Transform3D.IDENTITY):
		if roomy.encloses(box):
			continue
		count += 1
		for axis in 3:
			worst = maxf(worst, maxf(
					roomy.position[axis] - box.position[axis],
					box.end[axis] - roomy.end[axis]))
	if count > 0:
		out.append("%s: %d piece(s) of geometry reach up to %.2f m "
				% [who, count, worst] + "outside the room's own bounds "
				+ "(a wall's worth is %.2f)" % RoomContract.WALL_ALLOWANCE)
	return out

# --- probes ---------------------------------------------------------------

static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)

## Is anything solid sharing this space? A box rather than a ray: a
## socket fully inside a wall is something no ray from outside reaches,
## and "can I see it" is the wrong question.
##
## PLACED CONTENT DOES NOT COUNT. The audit runs on a finished room, so
## by the time it looks, the crate the `cover` socket offered is standing
## on that socket. Reporting it would be the audit reporting the socket's
## own success as a defect. The question is only ever about the LEVEL.
static func _buried(space: PhysicsDirectSpaceState3D, at: Vector3,
		size: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size
	query.shape = shape
	query.transform = Transform3D(Basis(), at)
	query.collide_with_areas = false
	for hit: Dictionary in space.intersect_shape(query, 8):
		if not _is_placed_content(hit.get("collider")):
			return true
	return false

## Something the composer PUT in the room, rather than the room itself.
##
## One implementation, in `SpaceProbe`, because the offer validators ask
## the same question and two answers to it is how they would come to
## disagree about the same crate.
static func _is_placed_content(collider: Variant) -> bool:
	return SpaceProbe.is_placed_content(collider)

## Does the player's own capsule get from `from` to `to`? Returns true
## when it is BLOCKED, which is the finding.
## Does the player's own capsule fail to fit here? Returns true when it
## is BLOCKED, which is the finding.
## Is there NOWHERE within a step of this endpoint a player fits? The
## blocking collider's name when so, "" when the endpoint is usable.
##
## THE MARKER IS WHERE THE MOVEMENT IS MEASURED, not where the player
## must stand -- the same rule `TraversalLaw._seed` states and for the
## same reason. An endpoint sits at the lip of the surface it leaves, and
## under owner ruling C(ii) that surface is a REGION in which a valid
## placement can be found. So a rubble stone overhung by the next stone
## keeps its endpoint, which is real architecture rather than a defect,
## and only an endpoint with no standable spot anywhere in its own
## neighbourhood is a false destination.
##
## What this still catches is the case it was added for: the plenum
## declares three collar endpoints on the axis of eight metres of hanging
## machine, where the whole neighbourhood is inside the machine and a ray
## at the declared height is answered by the collar's own collision.
static func _nowhere_to_stand(space: PhysicsDirectSpaceState3D,
		to_world: Transform3D, at: Vector3, floor_y: float) -> String:
	var step := Constants.PLAYER_RADIUS
	var named := ""
	for dx in [0, -1, 1]:
		for dz in [0, -1, 1]:
			var probe := Vector3(at.x + float(dx) * step, floor_y,
					at.z + float(dz) * step)
			# Re-grounded per neighbour: a spot one cell aside may be a
			# step down, and testing it at this endpoint's height would
			# ask about mid-air.
			if dx != 0 or dz != 0:
				var under := _ray(space,
						to_world * (probe + Vector3.UP
							* Constants.MAX_VERTICAL_STEP),
						to_world * (probe + Vector3.DOWN
							* Constants.MAX_VERTICAL_STEP))
				if under.is_empty():
					continue
				probe.y = (to_world.affine_inverse()
						* (under["position"] as Vector3)).y
			var blocked := SpaceProbe.stance_obstruction(space,
					to_world * probe)
			if blocked == null:
				return ""
			if named == "":
				named = blocked.name
	return named if named != "" else "nothing to stand on"

## Away from the middle of the room, horizontally.
##
## A connector sits on a wall, so "outside" is the direction that leaves
## the room through it. Derived rather than declared because a room may
## be entered on any face and an artist should not have to also state
## which way is out.
static func _outward(at: Vector3, bounds: AABB) -> Vector3:
	var away := at - bounds.get_center()
	away.y = 0.0
	return away.normalized() if away.length() > 0.001 else Vector3.FORWARD

## IS THE ARRIVAL SAFE? (owner ruling, 2026-09-03)
##
## The connector says where the rooms join; this says where the PLAYER
## ends up, and they are different questions -- the connector may be
## outside the envelope, and the body may not.
##
## `player_entry` has been a legal volume kind since S12 with no
## consumer at all, so three rooms declared an arrival region that
## nothing ever looked at. A room that declares one is held to it: the
## player's own capsule must fit standing there, and there must be
## something under it to stand on. A room that declares none is not
## required to -- the nine shells that predate the ruling do not.
## CAN A BODY ARRIVE HERE? Ground under it AND room to stand in it.
##
## The two halves are one question and were split in half: the layout
## result asked only whether a capsule had EMPTY SPACE, so an anchor over
## a hole in the floor passed -- a body would appear there and fall.
## `_arrival_is_safe` has asked both since it was written, and this is
## that pair pulled out, so the audit and the layout result read one
## measurement instead of two.
##
## THE FLOOR MUST BE WITHIN A STEP. Ground forty metres down is not
## ground the arriving body lands on.
##
## THE PROBING BODY IS ALREADY EXCLUDED, and not by a second mechanism.
## `SpaceProbe.is_placed_content` answers for the `Player` class -- "a
## room is not wrong because somebody is standing in it" -- so `_blocked`
## looks past a body at the anchor, and the downward ray starts INSIDE
## that body's capsule and therefore never reports it as ground. An
## `ignore` list here would be a second answer to a question that has
## one, which is the shape of defect this file exists to catch.
static func arrival_is_supported(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> bool:
	var ground := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(
				at + Vector3.UP * 0.5,
				at + Vector3.DOWN * (0.5 + Constants.MAX_VERTICAL_STEP)))
	if ground.is_empty():
		return false
	var floor_y: float = (ground["position"] as Vector3).y
	var stance := Vector3(at.x, floor_y, at.z) \
			+ Vector3.UP * (Constants.PLAYER_HEIGHT / 2.0 + 0.05)
	return not _blocked(space, stance)

static func _arrival_is_safe(room: Dictionary, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D, who: String) -> Array[String]:
	var out: Array[String] = []
	var region: Dictionary = room.get("player_entry", {})
	if region.is_empty():
		return out
	var at: Vector3 = region.get("position", Vector3.ZERO)
	var world := to_world * at
	# The declared centre is the middle of a standing box, so the floor
	# is half its height down rather than at the centre itself.
	var half: float = (region.get("extent", Vector3.ONE) as Vector3).y / 2.0
	var down := _ray(space, world + Vector3.UP * half,
			world + Vector3.DOWN * (half + Constants.MAX_VERTICAL_STEP))
	if down.is_empty():
		out.append("%s: the player_entry region at %v has no floor "
				% [who, at] + "under it")
		return out
	var floor_y: float = (to_world.affine_inverse()
			* (down["position"] as Vector3)).y
	var stance := Vector3(at.x, floor_y, at.z) \
			+ Vector3.UP * (Constants.PLAYER_HEIGHT / 2.0 + 0.05)
	if _blocked(space, to_world * stance):
		out.append("%s: the player_entry region at %v is blocked; the "
				% [who, at] + "player's own capsule does not fit where "
				+ "the room says they arrive")
	return out

static func _blocked(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> bool:
	return _blocker(space, at) != null

## WHAT IS STANDING HERE, not merely that something is.
##
## One probe, two readings. `_blocked` asked a yes/no question and threw
## the answer away, so every refusal downstream -- including the bridge's
## "the engine measured it as solid", which stops a Zone opening -- named
## the door and nothing else. Whoever had to fix it then had a doorway
## and no suspect.
static func _blocker(space: PhysicsDirectSpaceState3D,
		at: Vector3) -> Node:
	var capsule := CapsuleShape3D.new()
	# Very slightly slimmer than the player, so an opening built exactly
	# to the minimum is not refused by float error.
	capsule.radius = Constants.PLAYER_RADIUS - 0.02
	capsule.height = Constants.PLAYER_HEIGHT - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), at)
	query.collide_with_areas = false
	for hit: Dictionary in space.intersect_shape(query, 8):
		if not _is_placed_content(hit.get("collider")):
			return hit.get("collider") as Node
	return null

## `socket_id -> what stands in it`, for the declared doors that measure
## solid. Empty when every aperture is the hole it was declared to be.
static func aperture_blockers(room: Dictionary, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D) -> Dictionary:
	var out := {}
	for raw: Variant in room.get("doors", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw
		var at: Vector3 = door["position"]
		var inward := _inward(at, room["bounds"] as AABB)
		for step: float in [0.0, 0.45]:
			var who := _blocker(space, to_world * (at + inward * step
					+ _door_stance(to_world, space, at)))
			if who == null:
				continue
			out[str(door["socket_id"])] = ("%s (%s), %.2f m inside the "
					% [str(who.get_path()), who.get_class(), step]
					+ "doorway")
			break
	return out
