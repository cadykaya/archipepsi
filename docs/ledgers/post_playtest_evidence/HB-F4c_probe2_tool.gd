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
		# EVERY BODY IN EACH USED DOORWAY, with its shapes' real extents.
		for raw: Variant in room.get("doors", []):
			var door: Dictionary = raw
			if str(door.get("usage", "")) == "SEALED":
				continue
			var at: Vector3 = door["position"]
			var stance: Vector3 = RoomAudit._door_stance(xform, space, at)
			var point := xform * (at + stance)
			var capsule := CapsuleShape3D.new()
			capsule.radius = Constants.PLAYER_RADIUS - 0.02
			capsule.height = Constants.PLAYER_HEIGHT - 0.04
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = capsule
			q.transform = Transform3D(Basis(), point)
			q.collide_with_areas = false
			print("PROBE   %s/%s capsule at world %s (stance %s)" % [rid,
					str(door["socket_id"]), str(point), str(stance)])
			for hit: Dictionary in space.intersect_shape(q, 16):
				var body := hit["collider"] as Node3D
				var extents := []
				for c: Node in body.get_children():
					var cs := c as CollisionShape3D
					if cs == null or cs.shape == null:
						continue
					var box := cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
					extents.append("world %v..%v" % [box.position, box.end])
				print("PROBE     hit %s (%s) body at %v; shapes %s; parent chain %s" % [
						str(body.get_path()), body.get_class(),
						body.global_position, str(extents),
						_chain(body)])
	# THE CONNECTOR NODES OF THE JOIN, as built.
	for child: Node in (build["root"] as Node3D).get_children():
		var n3 := child as Node3D
		if n3 == null or str(n3.name).begins_with("Chamber_"):
			continue
		var p := n3.global_position
		if absf(p.x - 65.15) < 8.0 and p.z < -70.0 and p.z > -84.0:
			print("PROBE   node %s (%s) at %v yaw %.3f" % [str(n3.name),
					n3.get_class(), p, n3.global_rotation.y])
			for c: Node in n3.get_children():
				var c3 := c as Node3D
				if c3 == null:
					continue
				var mi := c3 as MeshInstance3D
				var size := ""
				if mi != null and mi.mesh is BoxMesh:
					size = str((mi.mesh as BoxMesh).size)
				print("PROBE     child %s (%s) at %v %s" % [str(c3.name),
						c3.get_class(), c3.global_position, size])
	get_tree().quit()


func _chain(n: Node) -> String:
	var parts := []
	var at := n.get_parent()
	for _i in 3:
		if at == null:
			break
		parts.append("%s@%v" % [str(at.name), (at as Node3D).global_position
				if at is Node3D else Vector3.ZERO])
		at = at.get_parent()
	return str(parts)
