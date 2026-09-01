extends SceneTree
## Does every shipped shell actually import with collision?
##
## Production integrated the eight shells at `eda4fd9` and could not
## measure any of them: one MeshInstance3D, zero CollisionObject3D, zero
## CollisionShape3D, in every one. 625 findings, all of the "nothing is
## there" class, from that single cause. This is the check that would
## have caught it on the art side, run against the REAL shipped scene --
## the .tscn Production loads, through Godot's own importer, not against
## the Blender script that wrote the .glb.
##
## WHAT THIS IS NOT
## ----------------
## It is not RoomAudit and it does not decide anything. It reports two
## facts and no verdict:
##
##   1. how many colliders each shell imported with, and of what shape;
##   2. for each surface the manifest declares, what a downward ray
##      actually hits -- the same 3 x 3 inset grid RoomAudit samples.
##
## The word PASS is deliberately absent from its output. `room_audit.gd`
## fires the real probes at the real instantiated room inside a Zone,
## with the transform, the neighbours and the player capsule that only
## Production has. A shell is measurable when this is green; it is
## MEASURED when Production says so.
const REGISTRY := "res://content/registry/authored_art.json"

## RoomAudit's own numbers, so a report here means the same thing a
## finding there does.
const GROUND_REACH := 1.2
const HEIGHT_TOLERANCE := 0.15
## `RoomAudit.HEADROOM` = PLAYER_HEIGHT + 0.6. The P2 preflight predicted
## 47 places where one surface has another over it; with no collision in
## the scenes, nothing could confirm or refute a single one. Now it can.
const HEADROOM := 2.4


func _shapes(node: Node, out: Dictionary) -> void:
	if node is CollisionShape3D and node.shape != null:
		var kind: String = node.shape.get_class()
		out[kind] = int(out.get(kind, 0)) + 1
	if node is MeshInstance3D:
		out["MeshInstance3D"] = int(out.get("MeshInstance3D", 0)) + 1
	if node is CollisionObject3D:
		out["bodies"] = int(out.get("bodies", 0)) + 1
	for child in node.get_children():
		_shapes(child, out)


func _init() -> void:
	var text := FileAccess.get_file_as_string(REGISTRY)
	var doc: Dictionary = JSON.parse_string(text)
	var shells: Array = []
	for raw: Variant in doc["entries"]:
		var entry: Dictionary = raw
		if entry.get("category", "") == "room_shell":
			shells.append(entry)
	shells.sort_custom(func(a, b): return a["id"] < b["id"])

	var holder := Node3D.new()
	root.add_child(holder)
	await physics_frame

	var bad := 0
	for raw: Variant in shells:
		var entry: Dictionary = raw
		var id: String = entry["id"]
		var packed: PackedScene = load(entry["scene"])
		if packed == null:
			print("[collision] LOAD FAILED %s" % id)
			bad += 1
			continue
		var room: Node3D = packed.instantiate()
		holder.add_child(room)
		await physics_frame

		var counted := {}
		_shapes(room, counted)
		var bodies := int(counted.get("bodies", 0))
		var convex := int(counted.get("ConvexPolygonShape3D", 0))
		var concave := int(counted.get("ConcavePolygonShape3D", 0))
		var meshes := int(counted.get("MeshInstance3D", 0))

		# The probe, at the manifest's own declared surfaces.
		var space := holder.get_world_3d().direct_space_state
		var to_world := room.global_transform
		var samples := 0
		var empty := 0
		var wrong := 0
		var worst := 0.0
		var low := 0
		var tightest := HEADROOM
		var detail: Array[String] = []
		for surface_raw: Variant in entry.get("surfaces", []):
			var surface: Dictionary = surface_raw
			var centre: Array = surface["center"]
			var extent: Array = surface["extent"]
			var s_empty := 0
			var s_wrong := 0
			var s_at := 0.0
			var s_low := 0
			var s_clear := HEADROOM
			for u: float in [0.2, 0.5, 0.8]:
				for v: float in [0.2, 0.5, 0.8]:
					samples += 1
					var local := Vector3(
							float(centre[0]) + (u - 0.5) * float(extent[0]),
							float(centre[1]),
							float(centre[2]) + (v - 0.5) * float(extent[1]))
					var world: Vector3 = to_world * local
					var query := PhysicsRayQueryParameters3D.create(
							world + Vector3.UP * 0.4,
							world + Vector3.DOWN * GROUND_REACH)
					var up := PhysicsRayQueryParameters3D.create(
							world + Vector3.UP * 0.1,
							world + Vector3.UP * HEADROOM)
					var over := space.intersect_ray(up)
					if not over.is_empty():
						low += 1
						s_low += 1
						var gap: float = (over["position"] as Vector3).y - world.y
						s_clear = minf(s_clear, gap)
						tightest = minf(tightest, gap)
					var hit := space.intersect_ray(query)
					if hit.is_empty():
						empty += 1
						s_empty += 1
						continue
					var drop: float = world.y - (hit["position"] as Vector3).y
					if absf(drop) > HEIGHT_TOLERANCE:
						wrong += 1
						s_wrong += 1
						s_at = (hit["position"] as Vector3).y
						worst = maxf(worst, absf(drop))
			if s_empty > 0 or s_wrong > 0:
				detail.append("'%s' declared y=%.2f: %d/9 empty, %d/9 measure %.2f"
						% [surface.get("name", "?"), float(centre[1]),
							s_empty, s_wrong, s_at])
			if s_low > 0:
				# The COUNT and the MINIMUM are two different numbers and
				# the first wording ran them together as "9/9 under 0.50",
				# which reads as nine samples at 0.50 when it is nine
				# obstructed samples of which the tightest is 0.50.
				detail.append("'%s' declared y=%.2f: %d/9 obstructed, "
						% [surface.get("name", "?"), float(centre[1]),
							s_low] + "tightest %.2f m; a player needs %.2f"
						% [s_clear, HEADROOM])

		var line := ("[collision] %-24s bodies=%-3d convex=%-3d concave=%-3d "
				+ "visible_meshes=%-2d | surface samples %d: "
				+ "%d with nothing under them, %d off by up to %.2f m, "
				+ "%d obstructed overhead, tightest %.2f m")
		print(line % [id, bodies, convex, concave, meshes, samples,
				empty, wrong, worst, low, tightest])
		if bodies == 0 or convex + concave == 0:
			print("[collision]   ^ NO COLLISION -- not measurable")
			bad += 1
		elif empty > 0 or wrong > 0 or low > 0:
			for d: String in detail:
				print("[collision]   ^ %s" % d)
			print("[collision]   ^ measurable, and the probe disagrees "
					+ "with the manifest here; evidence for review, "
					+ "not a verdict")
			bad += 1
		room.queue_free()
		await physics_frame

	print("[collision] %d shell(s), %d needing attention" % [shells.size(), bad])
	print("[collision] EVIDENCE ONLY. RoomAudit remains the authority on "
			+ "whether a shell is physically sound.")
	quit(1 if bad > 0 else 0)
