extends Node
## CAN THE PLAYER ACTUALLY GET TO THE EXIT? (`make godot-exit-reach`)
##
## **The complaint this answers.** A player with every Check claimed and
## the HUD reading `EXIT 2m`: *"the exit is still a wall. If it's a
## door, how am I meant to open it?"* They broke out of bounds to see
## the other side of it. Nothing errored; the Zone was built, accepted
## and committed, and every headless suite was green.
##
## **The two physical questions a finishable Zone owes.** Both are asked
## with rays against the built geometry, not read off the manifest:
##
##   APERTURE  standing outside the exit room's entry face, is there a
##             way THROUGH it -- an opening, at head height, on the
##             doorway's own centreline?
##   APPROACH  and once inside, is there a clear line from the entry to
##             the portal?
##
## When APERTURE fails, a third measurement runs: **the player's own
## experiment.** Walk backwards along the approach in half-metre steps
## and report the first solid thing and which room owns it -- so the
## finding names a room somebody can be sent to rather than three world
## coordinates.
##
## Measured in the exit room's committed frame (`room_places`), so
## nothing here copies a placement constant out of the builder.

## EVERY ZONE OF THE DECLARED SAMPLE, not the one the complaint came
## from. The defect this driver was written for was reported against a
## single Zone and was present in all twenty, because it lived in the
## contract between the composer and the engine rather than in a roll.
## A census that looks at one case would have called it fixed either
## way.
const SAMPLE := "res://tests/fixtures/sample"
## A Zone as it was composed before the way out could be declared, with
## the layout that was committed for it. See the fixture's own note.
const LEGACY := "res://tests/fixtures/legacy/sealed_exit_zone.json"
const EXIT_ROOM := "exit"
## How far either side of the entry face to fire the aperture ray. Well
## clear of `WALL_THICKNESS` (0.4) on both sides, and short enough that
## a clear result means the doorway and not the room beyond it.
const THROUGH := 2.5
## Head height. A gap a player cannot walk through is not a door, and a
## ray along the floor would pass over a step and call it one.
const EYE := 1.6
## How far back along the approach to look for the thing in the way.
const BACKTRACK := 40.0
const STEP := 0.5

var _failures := 0
var _checks := 0
## The room owning the first solid thing between the exit room and the
## rest of the level -- which is the room a player walks the approach
## from, and so the one whose departing face has to be open.
var _blocking_room := ""


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	var cases := _cases()
	# THE CENSUS'S OWN GUARD. An empty sample directory would pass every
	# check below while measuring nothing at all.
	_check(cases.size() >= 20, "the declared sample is present to "
			+ "measure (%d case(s) found)" % cases.size())
	for case: String in cases:
		await _one(case)
	await _an_older_save_still_builds()
	_finish()


## WHAT HAPPENS TO A ZONE SAVED BEFORE THE WAY OUT WAS DECLARABLE.
##
## Every default-scale Zone composed before `ZONE_EXIT` existed has its
## last room's `exit` SEALED, and a player's save holds that Zone plus
## the layout committed for it. Two questions, both answered by
## building, neither by reading the code:
##
##   REPLAY   with its committed layout, it must rebuild EXACTLY as
##            saved -- sealed exit and all. Refusing it would park a
##            Zone somebody is part way through over a defect they have
##            already been living with, which is a change made to their
##            save without asking.
##   FRESH    as a new proposal it must be REFUSED, naming the room, so
##            the bridge composes another instead of shipping a Zone
##            whose exit is visible and unreachable.
##
## Nothing is migrated. Nothing is abandoned.
func _an_older_save_still_builds() -> void:
	print("  -- an older save (sealed exit, committed layout)")
	var raw: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(LEGACY))
	if typeof(raw) != TYPE_DICTIONARY:
		_check(false, "%s did not parse" % LEGACY)
		return
	var fixture: Dictionary = raw
	var zone: Dictionary = fixture["zone"]
	var layout: Dictionary = fixture["layout"]
	# The fixture is only evidence while it still holds the thing it is
	# about: a last room whose exit is SEALED.
	var tail: Dictionary = (zone["chambers"] as Array).back()
	var sealed := false
	for d: Variant in (tail as Dictionary)["doors"]:
		if str((d as Dictionary)["socket_id"]) == "exit":
			sealed = str((d as Dictionary)["usage"]) == "SEALED"
	_check(sealed, "the older-save fixture still seals its last room's "
			+ "exit, which is the whole thing it is evidence about")

	# DECODED THE WAY THE CONTROLLER DECODES IT. A saved manifest is
	# JSON -- `[x, y, z]`, not `Vector3` -- and `ZoneController.setup`
	# runs it through `layout_from_json` before handing it to the
	# builder. Passing the raw form here would measure the decoder.
	var replayed := ZoneBuilder.build(
			zone, "", 0.0, ZoneBuilder.layout_from_json(layout))
	_check(str(replayed.get("status", "")) == "LAYOUT_OK",
			"an older save REBUILDS as committed: status '%s'%s"
			% [str(replayed.get("status", "?")),
				"" if not replayed.has("failed")
				else " -- " + str(replayed["failed"])])
	if replayed.has("root"):
		(replayed["root"] as Node3D).free()

	var fresh := ZoneBuilder.build(zone)
	_check(str(fresh.get("status", "")) == "LAYOUT_INFEASIBLE",
			"and the same Zone proposed FRESH is refused rather than "
			+ "built with an exit nobody can reach (status '%s')"
			% str(fresh.get("status", "?")))
	_check(str(fresh.get("failed", "")).find(str(tail["id"])) >= 0,
			"and the refusal names the room the exit would have hung "
			+ "off ('%s'): %s" % [str(tail["id"]),
				str(fresh.get("failed", "(no reason given)"))])
	if fresh.has("root"):
		(fresh["root"] as Node3D).free()


func _cases() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(SAMPLE)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.begins_with("zone_") and name.ends_with(".json"):
			out.append("%s/%s" % [SAMPLE, name])
	out.sort()
	return out


func _one(case: String) -> void:
	print("  -- %s" % case.get_file())
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(case))
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(parsed as Dictionary)
	if controller.layout_failed != "":
		# A REFUSAL IS NOT A BLOCKED EXIT. The bridge recomposes a Zone
		# whose layout is infeasible and the player never sees it, so
		# reporting it here would file a working refusal as an
		# unfinishable Zone. Said out loud rather than skipped silently.
		print("    refused before building: %s" % controller.layout_failed)
		controller.queue_free()
		return
	# COLLIDERS ARE REAL ONE PHYSICS FRAME FROM HERE. A ray against a
	# body the physics server has not registered answers "nothing there",
	# which would report a sealed wall as an open doorway.
	for _i in 6:
		await get_tree().physics_frame

	var portal: Node3D = _find(controller, "ExitPortal")
	_check(portal != null, "%s built an exit portal" % case.get_file())
	if portal == null:
		controller.queue_free()
		return
	var at := portal.global_position
	print("  PORTAL: at %.1f, %.1f, %.1f, in room '%s'"
			% [at.x, at.y, at.z, _room_of(controller, at)])

	var place: Dictionary = controller.room_places.get(EXIT_ROOM, {})
	if place.is_empty():
		_check(false, "%s carries no frame for room '%s', so there is "
				% [case.get_file(), EXIT_ROOM] + "nothing to measure from")
		controller.queue_free()
		return
	# THE ENTRY FACE, in the exit room's own frame: its origin is the
	# middle of that face and +Z points into the room.
	var origin: Vector3 = place["position"]
	var yaw := float(place["yaw"])
	var forward := Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
	var space := get_viewport().world_3d.direct_space_state

	# 1. IS THERE A WAY THROUGH THE ENTRY FACE AT ALL?
	var outside := origin - forward * THROUGH + Vector3.UP * EYE
	var inside := origin + forward * THROUGH + Vector3.UP * EYE
	var door := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(outside, inside))
	var open := door.is_empty()
	if open:
		print("  APERTURE: open -- clear through the entry face")
	else:
		var slab: Node = door["collider"]
		var hit: Vector3 = door["position"]
		print("  APERTURE: SEALED by '%s' %.2f m outside the face, in "
				% [slab.name, origin.distance_to(hit)]
				+ "room '%s'" % _room_of(controller, hit))
	_check(open, "%s: the exit room's entry face has an opening a "
			% case.get_file() + "player can walk through")

	# 2. AND FROM THE ENTRY, IS THE PORTAL REACHABLE? A portal inside
	#    the room but behind its own back wall is still unusable.
	var eye := origin + forward * 1.0 + Vector3.UP * EYE
	var aim := at + Vector3.UP * 1.0
	# THE PORTAL IS NOT THE WALL. Its own trigger volume is the last
	# thing on this ray, and the first cut reported the destination as
	# the obstruction -- which would call every reachable exit blocked.
	var query := PhysicsRayQueryParameters3D.create(eye, aim)
	var own: Array[RID] = []
	_rids(portal, own)
	query.exclude = own
	var blocked := space.intersect_ray(query)
	if blocked.is_empty():
		print("  APPROACH: clear, %.1f m from the entry to the portal"
				% eye.distance_to(aim))
	else:
		print("  APPROACH: BLOCKED by '%s' at %.1f m of the %.1f m"
				% [(blocked["collider"] as Node).name,
					eye.distance_to(blocked["position"]),
					eye.distance_to(aim)])
	_check(blocked.is_empty(), "%s: there is a clear line from the "
			% case.get_file() + "exit room's entry to the portal")

	# 3. THE PLAYER'S OWN EXPERIMENT: walk back up the approach and
	#    name everything in the way. Always, not only when the face is
	#    sealed -- the face being open says nothing about the far end of
	#    the corridor, which is where the player actually stopped.
	_name_the_wall(controller, space, origin, forward)
	# 4. AND THE FACE THE APPROACH LEAVES THROUGH. The engine appends
	#    the exit room and routes a corridor to it out of the LAST
	#    room's exit face, whatever that room's door assignment says. If
	#    that face is SEALED, the corridor leaves through a solid wall
	#    and no amount of open doorway at the far end helps.
	_check(_departure_open(controller, space, _blocking_room),
			"%s: the room the exit corridor leaves from has an opening "
			% case.get_file() + "in the face it leaves through")
	controller.queue_free()


## IS THE FAR END OF THE APPROACH OPEN? The same ray as APERTURE, fired
## through the departing room's own `exit` doorway.
##
## `door_positions` is where each socket IS, not proof that a hole was
## cut there: a SEALED socket still has a position, because the lock
## slab and the door probe need one. So the position is the aim and the
## ray is the evidence.
func _departure_open(controller: ZoneController,
		space: PhysicsDirectSpaceState3D, rid: String) -> bool:
	if rid == "" or rid == "?":
		print("  DEPARTURE: nothing blocked the approach, so there is "
				+ "no departing face to name")
		return true
	var key := "%s/exit" % rid
	if not controller.door_positions.has(key):
		print("  DEPARTURE: room '%s' declares no exit socket at all, "
				% rid + "so the corridor leaves through unbroken wall")
		return false
	var socket: Vector3 = controller.door_positions[key]
	var place: Dictionary = controller.room_places.get(rid, {})
	var yaw := float(place.get("yaw", 0.0))
	var forward := Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
	var probe := PhysicsRayQueryParameters3D.create(
			socket - forward * THROUGH + Vector3.UP * EYE,
			socket + forward * THROUGH + Vector3.UP * EYE)
	var hit := space.intersect_ray(probe)
	if hit.is_empty():
		print("  DEPARTURE: room '%s' exit doorway at %.1f, %.1f, %.1f "
				% [rid, socket.x, socket.y, socket.z] + "is open")
		return true
	print("  DEPARTURE: room '%s' exit doorway at %.1f, %.1f, %.1f is "
			% [rid, socket.x, socket.y, socket.z]
			+ "SEALED by '%s'" % (hit["collider"] as Node).name)
	return false


func _rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child: Node in node.get_children():
		_rids(child, out)


## WHAT THE PLAYER WALKED INTO, and which room owns it.
##
## Steps backwards along the approach at head height and reports every
## distinct body between the exit room and the last open air -- so the
## report says "room c023's back wall" and not "a StaticBody3D".
func _name_the_wall(controller: ZoneController,
		space: PhysicsDirectSpaceState3D, origin: Vector3,
		forward: Vector3) -> void:
	print("  BACKTRACK: walking out from the entry face --")
	var seen := {}
	var d := 0.0
	_blocking_room = ""
	while d < BACKTRACK:
		var a := origin - forward * d + Vector3.UP * EYE
		var b := origin - forward * (d + STEP) + Vector3.UP * EYE
		var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(a, b))
		if not hit.is_empty():
			var who: Node = hit["collider"]
			var where: Vector3 = hit["position"]
			var room := _room_of(controller, where)
			var line := "%s in room '%s'" % [who.name, room]
			if not seen.has(line):
				seen[line] = true
				if _blocking_room == "" and who is StaticBody3D:
					_blocking_room = room
				print("    %.1f m back: %s" % [d, line])
		d += STEP
	if seen.is_empty():
		print("    nothing solid within %.0f m -- the approach is open "
				% BACKTRACK + "and the seal is elsewhere")


## WHICH ROOM A POINT IS IN, off the bounds the controller resolved from
## the committed layout -- not re-derived, because two answers to "where
## is this" is one answer too many.
func _room_of(controller: ZoneController, at: Vector3) -> String:
	for rid: String in controller.room_bounds:
		var box: AABB = controller.room_bounds[rid]
		if box.grow(0.5).has_point(at):
			return rid
	return "?"


func _finish() -> void:
	if _failures == 0:
		print("GODOT EXIT REACH OK (%d checks)" % _checks)
	else:
		print("GODOT EXIT REACH FAILED (%d of %d checks)"
				% [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _find(root: Node, class_wanted: String) -> Node3D:
	if root.get_script() != null \
			and (root.get_script() as GDScript).get_global_name() \
				== class_wanted:
		return root as Node3D
	for child: Node in root.get_children():
		var found := _find(child, class_wanted)
		if found != null:
			return found
	return null
