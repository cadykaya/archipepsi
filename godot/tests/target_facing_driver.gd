extends Node
## WHICH WAY A SHOT TARGET IS ACTUALLY POINTING (`make godot-target-facing`).
##
## **The complaint this answers.** A player in an ordinary Zone: *"some
## targets are facing the wrong way."* Nothing errors, nothing fails a
## suite, and the geometry, the state and the protocol are all correct —
## which is exactly the class the headless suites structurally cannot
## reach, and exactly what the second playtest was for.
##
## **Measured, not declared.** A target's face is its local +Z: the
## stalk that holds it off the wall is built at `(0, 0, -0.3)`, behind
## the face. So the two questions a mounted target owes are physical
## ones, and both are asked with rays rather than read off a field:
##
##   FACE   fire along +Z from the face. A target you can shoot has open
##          room in front of it.
##   BACK   fire along -Z. A target that reads as mounted equipment has
##          a wall immediately behind it, within the stalk's reach.
##
## A target that fails BACK is floating with its stalk in the air. One
## that fails FACE is aimed into the plaster. Either is "facing the
## wrong way" to the person holding the mouse.
##
## The Zone is `zone_01.json` of the declared sample, which is what the
## fallback provider composes for Zone 1 of every default-scale campaign
## — the Zone the complaint came from, seed for seed.

const CASE := "res://tests/fixtures/sample/zone_01.json"
## How far in front of a target counts as "room to shoot from".
const CLEAR_AHEAD := 2.0
## THE PRODUCER'S OWN WINDOW, and not a number chosen here.
##
## `activities._wall_behind` probes from `MOUNT_STALK` (0.55 m) behind
## the origin, outward for 0.9 m -- so the wall it accepted is anywhere
## from 0.55 m to 1.45 m back. The first cut of this driver fired from
## 0.35 m to 0.9 m and reported four correctly mounted targets as having
## NOTHING behind them: the wall was past the end of the ray. A
## threshold that does not match the one that placed the thing measures
## the threshold, not the thing.
const BACK_NEAR := 0.1
const BACK_FAR := 1.7

var _failures := 0
var _checks := 0


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
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CASE))
	if typeof(parsed) != TYPE_DICTIONARY:
		_check(false, "%s did not parse as a Zone" % CASE)
		get_tree().quit(1)
		return
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(parsed as Dictionary)
	if controller.layout_failed != "":
		_check(false, "the control Zone did not build: %s"
				% controller.layout_failed)
		get_tree().quit(1)
		return
	# COLLIDERS ARE REAL ONE PHYSICS FRAME FROM HERE, and a ray against a
	# body the physics server has not registered answers "nothing there"
	# -- which would report every target as floating.
	for _i in 6:
		await get_tree().physics_frame

	var targets: Array[Node] = []
	_gather(controller, targets)
	print("  ZONE: '%s', %d SHOT target(s) built"
			% [str((parsed as Dictionary).get("zone_id", "?")),
				targets.size()])
	_check(not targets.is_empty(),
			"the control Zone contains SHOT targets to measure")

	var space := get_viewport().world_3d.direct_space_state
	var mounted := 0
	var wrong: Array[String] = []
	for node: Node in targets:
		var t := node as Node3D
		var at := t.global_position
		var face := t.global_transform.basis.z.normalized()
		var claims_mounted := bool(t.get_meta("mounted", false))
		if claims_mounted:
			mounted += 1
		var front := _probe(space, at, face, 0.1, CLEAR_AHEAD, t)
		var back := _probe(space, at, -face, BACK_NEAR, BACK_FAR, t)
		var ahead := front.is_empty()
		var behind := not back.is_empty()
		# TWO POPULATIONS, TWO CONTRACTS. A MOUNTED target claims a wall
		# and owes one. An UNMOUNTED one is free-standing by design and
		# owes nothing behind it -- asking for a wall there would fail
		# every correctly placed floor target. What BOTH owe is somewhere
		# to shoot them from.
		var ok := ahead and (behind or not claims_mounted)
		var line := ("%s in %s  mounted=%s  at %.1f,%.1f,%.1f  facing %.2f,%.2f"
				% [t.name, _room_of(controller, at), str(claims_mounted),
					at.x, at.y, at.z, face.x, face.z]
				+ "  front=%s  back=%s"
				% ["clear" if ahead
					else "BLOCKED by %s at %.2f m" % [
						str((front["collider"] as Node).name),
						at.distance_to(front["position"])],
					"wall at %.2f m" % at.distance_to(back["position"])
					if behind else "nothing"])
		print("    %s" % line)
		if not ok:
			wrong.append(line)
			_propose(space, controller, t, at, face)

	print("  MOUNTED: %d of %d target(s) claim a wall"
			% [mounted, targets.size()])
	_check(wrong.is_empty(),
			"every SHOT target can be shot from in front, and every "
			+ "target claiming a mount has one (%d of %d do not)"
			% [wrong.size(), targets.size()])
	if _failures == 0:
		print("GODOT TARGET FACING OK (%d checks)" % _checks)
	else:
		print("GODOT TARGET FACING FAILED (%d of %d checks)"
				% [_failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


## THE SMALLEST SAME-ROOM NUDGE that would give this target somewhere to
## shoot it from -- reported, never applied.
##
## Owner direction, 2026-09-21: when rotation alone cannot solve a named
## placement, the answer is "the smallest same-room placement correction
## rather than another unbounded rotation search or a reduced clearance
## threshold". So this is a BOUNDED ladder, not a search: half-metre of
## travel in five-centimetre steps, along the target's own facing axis
## and the two perpendiculars, at the SAME clearance every other target
## is held to. If nothing inside that box works, it says so and proposes
## nothing -- which is a different finding and belongs to whoever placed
## the room, not to this threshold.
##
## A candidate has to survive two questions, because a target shoved
## into the wall behind it has "clear room in front" for the worst
## possible reason:
##   AHEAD    `CLEAR_AHEAD` of nothing, exactly as the census asks.
##   STANDING the new origin is not inside anything, probed short in all
##            four horizontal directions.
const NUDGE_STEP := 0.05
const NUDGE_LIMIT := 0.50
## Enough to catch an origin buried in a solid without tripping on the
## neighbour the target is meant to sit beside.
const NUDGE_CLEAR := 0.22

func _propose(space: PhysicsDirectSpaceState3D, controller: ZoneController,
		t: Node3D, at: Vector3, face: Vector3) -> void:
	var side := Vector3(-face.z, 0.0, face.x).normalized()
	var ways: Array = [
		["back along its own facing", -face],
		["forward along its own facing", face],
		["sideways", side],
		["sideways", -side]]
	var best_label := ""
	var best_at := Vector3.ZERO
	var best_far := NUDGE_LIMIT + 1.0
	var steps := int(NUDGE_LIMIT / NUDGE_STEP)
	for way: Array in ways:
		for i in range(1, steps + 1):
			var far := float(i) * NUDGE_STEP
			if far >= best_far:
				break
			var here: Vector3 = at + (way[1] as Vector3) * far
			if not _probe(space, here, face, 0.1, CLEAR_AHEAD, t).is_empty():
				continue
			if not _standing_clear(space, here, t):
				continue
			if _room_of(controller, here) != _room_of(controller, at):
				continue
			best_far = far
			best_at = here
			best_label = str(way[0])
			break
	if best_label == "":
		print("      PROPOSAL: none within %.2f m in four directions -- "
				% NUDGE_LIMIT + "this is a room question, not a nudge")
		return
	print("      PROPOSAL: move %.2f m %s, to %.2f,%.2f,%.2f (same room, "
			% [best_far, best_label, best_at.x, best_at.y, best_at.z]
			+ "same %.1f m clearance, no rotation)" % CLEAR_AHEAD)


## Is this origin standing in open air rather than inside something?
func _standing_clear(space: PhysicsDirectSpaceState3D, here: Vector3,
		own: Node3D) -> bool:
	for dir: Vector3 in [Vector3.LEFT, Vector3.RIGHT,
			Vector3.FORWARD, Vector3.BACK]:
		if not _probe(space, here, dir, 0.0, NUDGE_CLEAR, own).is_empty():
			return false
	return true


## WHICH ROOM A TARGET IS IN, so a finding is somewhere a player can be
## sent rather than three world coordinates.
##
## Off `room_bounds`, which the controller already resolved from the
## committed layout -- not re-derived here, because two answers to "where
## is c014" is one answer too many.
func _room_of(controller: ZoneController, at: Vector3) -> String:
	for rid: String in controller.room_bounds:
		var box: AABB = controller.room_bounds[rid]
		if box.grow(0.5).has_point(at):
			return rid
	return "?"


func _gather(root: Node, out: Array[Node]) -> void:
	if root is ActivityElement and str(root.get("trigger")) == "shot":
		out.append(root)
	for child: Node in root.get_children():
		_gather(child, out)


## THE TARGET'S OWN HARDWARE IS NOT THE WALL. Its frame bars and stalk
## are bodies too, and a ray fired from the middle of it hits itself
## first -- which would report every target as correctly mounted and
## every target as blocked at once.
func _probe(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3,
		near: float, far: float, own: Node3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
			from + dir * near, from + dir * far)
	var mine: Array[RID] = []
	_rids(own, mine)
	query.exclude = mine
	return space.intersect_ray(query)


func _rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child: Node in node.get_children():
		_rids(child, out)
