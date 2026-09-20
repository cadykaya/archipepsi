extends Node
## WHERE A CONVENIENCE RETURN MAY STAND, and where it may not.
##
## THE PRODUCT RULE. A return device is a courtesy: it exists so a dead
## end has a way home. It must never sit ON the route the player has to
## walk to reach what the room is for. On `platform_path` it did --
## `p:c021:start` landed on the last island of the course, between the
## arrival and the Check, so walking at the Check stepped on the pad and
## left the room. Measured on the owner's own committed placement.
##
## This file is that regression, and the diagnostic that found it.
## Nothing here knows c021's world coordinates: the subject is the
## PRODUCER, and a chamber built from the same declared fields.

var failures := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _note(text: String) -> void:
	print("     -- " + text)

func _ready() -> void:
	_run()

## The shape the owner's c021 declares, by its FIELDS and not its place.
##
## THE ACTIVITY IS PART OF THE SHAPE. A first version of this file left
## it out, and the room it built was NOT c021: with no switches to place,
## the end ledge stayed whole and the old rule chose the ledge -- while
## the real room, whose four switches are already standing on it, sent
## the old rule somewhere else entirely. A regression that reproduces a
## different room is not the regression. Every field the proposal
## declares for `c021` is here, verbatim; nothing about where it sits.
func _course() -> Dictionary:
	return {"id": "c021", "type": "platform_path", "segment_count": 3,
			"gap_size": 2.03, "vertical_step": 0.51,
			"objective": "platform_to_goal",
			"reward_location_id": 89100126,
			"features": [], "keys": [], "enemies": [],
			"additional_reward_location_ids": [],
			"arrive_edge": "e:c018:c021", "depart_edge": null,
			"shell_id": null, "size_class": null,
			"doors": [
				{"socket_id": "entry", "usage": "USED",
					"edge_id": "e:c018:c021", "key_id": null,
					"colour": null},
				{"socket_id": "exit", "usage": "SEALED",
					"edge_id": null, "key_id": null, "colour": null}],
			"activities": [
				{"kind": "switch_sequence", "element_count": 4,
					"time_limit": 0.0, "ordered": false,
					"requires": []}]}

func _run() -> void:
	var chamber := _course()
	# THE PIPELINE'S OWN RESULT, not the raw producer's.
	#
	# `zone_builder` calls `return_spot(result, chamber)` where `result`
	# is `ContentInstantiator.build_chamber` -- which has already spent
	# sockets on the reward and the activities. Asking the bare producer
	# is asking a different question: it still offers the end ledge, so
	# `return_spot` picks the ledge and lands on top of the reward, and
	# the real Zone does something else entirely.
	var build := ContentInstantiator.build_chamber(chamber, "neon_transit")
	var reward: Vector3 = build["reward_position"]
	var spot := ChamberBuilders.return_spot(build, chamber)

	print("RETURN PLACEMENT on a platform course")
	_note("declared: %d segments, gap %.2f, step %.2f"
			% [int(chamber["segment_count"]), float(chamber["gap_size"]),
				float(chamber["vertical_step"])])
	_note("the surfaces this room says hold weight, in order:")
	var stands: Array = build.get("sockets", [])
	for i in stands.size():
		var s: Dictionary = stands[i]
		var p: Vector3 = s.get("position", Vector3.ZERO)
		var e: Vector3 = s.get("extent", Vector3.ZERO)
		_note("   [%d] %-6s at %s extent %s"
				% [i, str(s.get("kind", "?")),
					str(p.snapped(Vector3.ONE * 0.01)),
					str(e.snapped(Vector3.ONE * 0.01))])
	_note("reward sits at %s" % str(reward.snapped(Vector3.ONE * 0.01)))
	_note("return chosen at %s" % str(spot.snapped(Vector3.ONE * 0.01)))

	# THE REQUIRED APPROACH is the run from the arrival to the reward.
	# On a linear course that is the whole course, so "off the approach"
	# means BEYOND the reward, not beside it.
	var approach_end := reward.z
	_check(spot.z >= approach_end,
			"the return stands at or past the reward (%.2f m along, "
			% spot.z + "reward at %.2f m), so reaching the reward does "
			% approach_end + "not cross it")
	var clearance: AABB = ChamberBuilders.reward_clearance(chamber, reward)
	_check(not clearance.has_point(Vector3(spot.x, clearance.position.y
			+ clearance.size.y * 0.5, spot.z)),
			"and it is outside the reward's own interaction space")
	# THE RULE THIS REPLACED, COMPUTED HERE, so the check above is
	# proved decisive without reverting the module. The old branch took
	# the LAST qualifying stand surface's CENTRE and consulted no claim;
	# on this room that centre IS the reward.
	var was := Vector3.INF
	var reach := Constants.PLAYER_RADIUS + 0.6
	for raw: Variant in stands:
		var s: Dictionary = raw
		if str(s.get("kind", "")) != "stand":
			continue
		var e: Vector3 = s.get("extent", Vector3.ZERO)
		if e.x < reach * 2.0 or e.z < reach * 2.0:
			continue
		was = s.get("position", Vector3.ZERO)
	_note("the rule this replaced would choose %s"
			% str(was.snapped(Vector3.ONE * 0.01)))
	_check(clearance.has_point(Vector3(was.x, clearance.position.y
			+ clearance.size.y * 0.5, was.z)),
			"and the OLD rule lands inside that interaction space -- so "
			+ "the check above fails when the repair is reverted, rather "
			+ "than passing either way")
	_check(was != spot,
			"the repair actually moved the device (%s -> %s)"
			% [str(was.snapped(Vector3.ONE * 0.01)),
				str(spot.snapped(Vector3.ONE * 0.01))])
	# AND IT IS STILL ON GROUND THE ROOM DECLARES.
	var on_a_surface := false
	for raw: Variant in stands:
		var s: Dictionary = raw
		var pos: Vector3 = s.get("position", Vector3.ZERO)
		var e: Vector3 = s.get("extent", Vector3.ZERO)
		if absf(spot.x - pos.x) <= e.x / 2.0 \
				and absf(spot.z - pos.z) <= e.z / 2.0 \
				and absf(spot.y - pos.y) < 0.01:
			on_a_surface = true
	_check(on_a_surface,
			"and it stands on a surface the room declares holds weight, "
			+ "not in the pit between them")
	print("GODOT RETURN PLACEMENT %s"
			% ("OK" if failures == 0 else "FAILED"))
	get_tree().quit(0 if failures == 0 else 1)
