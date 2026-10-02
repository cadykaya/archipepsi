extends Node
## HB-F4c probe: lay out one Zone file exactly as the layout walk does,
## then say where two joined rooms and the chain between them stand, and
## name whatever the aperture probe finds in their doorways
## (`RoomAudit.aperture_blockers`, the reading behind the bridge's
## "measured it as solid").
##   godot --headless --path godot res://probe_tmp.tscn -- IN EDGE ROOM_A ROOM_B

func _ready() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(args[0]))
	var eid := str(args[1])
	var wanted := [str(args[2]), str(args[3])]
	var build: Dictionary = ZoneBuilder.build(zone, "",
			ZoneController.PLACEMENT_BUDGET_MS, {})
	if build.has("failed"):
		print("PROBE build failed: ", build["failed"])
		get_tree().quit()
		return
	print("PROBE built in %d attempt(s), nudged %s" % [
			int(build.get("placement_attempts", 1)),
			str(build.get("placement_nudges", {}))])
	add_child(build["root"] as Node3D)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var rooms: Dictionary = build.get("rooms", {})
	for rid: String in wanted:
		var placed: Dictionary = rooms.get(rid, {})
		print("PROBE room %s at %s yaw %s bounds %s arrival %s" % [rid,
				str(placed.get("position")), str(placed.get("yaw")),
				str(placed.get("bounds")), str(placed.get("arrival"))])
	var joins: Dictionary = build.get("joins", {})
	# WHICH JOINS LAY PIECES IN THE GAP between the two rooms.
	var gap := AABB(Vector3(58.0, 0.0, -80.0), Vector3(18.0, 10.0, 6.0))
	var order := 0
	for jid: String in joins:
		var j: Dictionary = joins[jid]
		var hits := []
		var n := 0
		for piece: Dictionary in j.get("chain", []):
			var b: AABB = piece.get("bounds", AABB())
			if b.intersects(gap):
				hits.append("#%d %s at %s yaw %.2f bounds %v..%v" % [n,
						str(piece.get("kind")), str(piece.get("position")),
						float(piece.get("yaw", 0.0)), b.position, b.end])
			n += 1
		if not hits.is_empty():
			print("PROBE join #%d %s (%s -> %s, %d pieces) lays in the gap: %s"
					% [order, jid, str(j.get("room_a")), str(j.get("room_b")),
						n, str(hits)])
		order += 1
	var spine: Array = []
	for raw: Variant in build.get("chambers", []):
		spine.append(str((raw as Dictionary)["chamber"].get("id", "")))
	print("PROBE chamber order: %s" % str(spine))
	var join: Dictionary = joins.get(eid, {})
	print("PROBE join %s: %s -> %s, socket_a %s socket_b %s, synthetic %s"
			% [eid, str(join.get("room_a")), str(join.get("room_b")),
				str(join.get("socket_a")), str(join.get("socket_b")),
				str(join.get("synthetic"))])
	var k := 0
	for piece: Dictionary in join.get("chain", []):
		print("PROBE   piece %d %s at %s yaw %s turn %s entry %s exit %s bounds %s"
				% [k, str(piece.get("kind")), str(piece.get("position")),
					str(piece.get("yaw")), str(piece.get("turn")),
					str(piece.get("entry")), str(piece.get("exit")),
					str(piece.get("bounds"))])
		k += 1
	for entry: Dictionary in build.get("chambers", []):
		var rid := str((entry["chamber"] as Dictionary).get("id", ""))
		if not wanted.has(rid):
			continue
		var room: Dictionary = entry["build"]
		var xform: Transform3D = entry["xform"]
		for raw: Variant in room.get("doors", []):
			var door: Dictionary = raw
			print("PROBE   %s door %s usage %s local %s world %s" % [rid,
					str(door.get("socket_id")), str(door.get("usage", "?")),
					str(door.get("position")),
					str(xform * (door.get("position", Vector3.ZERO) as Vector3))])
		var polarity := RoomAudit.aperture_polarity(room, xform, space)
		print("PROBE   %s apertures %s" % [rid, str(polarity)])
		var blockers := RoomAudit.aperture_blockers(room, xform, space)
		for socket: String in blockers:
			print("PROBE   %s/%s BLOCKED BY %s" % [rid, socket,
					str(blockers[socket])])
	get_tree().quit()
