extends SceneTree
## Does every shipped shell import with collision, and can every Surface
## it declares keep its promise?
##
## WHY IT EXISTS. Production integrated the eight shells at `eda4fd9` and
## could not measure any of them: one MeshInstance3D, zero
## CollisionObject3D, zero CollisionShape3D, so all 625 audit findings
## were of the "nothing is there" class. This is the check that would
## have caught that on the art side, run against the REAL shipped scene
## -- the .tscn Production loads, through Godot's own importer.
##
## WHAT A SURFACE PROMISES (owner ruling C(ii), Production `1648fa9`):
## a `stand` Surface does not promise that every point of its rect is
## clear. It promises that a valid placement can be FOUND somewhere in
## it. A Surface with ZERO valid placements is still invalid.
##
## The first version of this script predated that ruling and counted
## every obstructed sample, which reads `stand` as "every point is
## standable" -- it called a ground floor passing under its own staircase
## a problem. It now asks `Placement`'s question: is there one?
##
## WHAT THIS IS NOT. It is not RoomAudit and it decides nothing. The word
## PASS is deliberately absent from its output. `room_audit.gd` fires the
## real probes at the real room inside a Zone, with the transform, the
## neighbours and the player capsule that only Production has.
const REGISTRY := "res://content/registry/authored_art.json"

## `RoomAudit`'s own numbers, so a report here means what a finding
## there means. STANCE is the player's capsule squared off.
const GROUND_REACH := 1.2
const HEIGHT_TOLERANCE := 0.15
const HEADROOM := 2.4
const STANCE := Vector3(0.8, 1.8, 0.8)
## `Placement.GRID` and `Placement.LIFT`.
const GRID := 9
const LIFT := 0.02


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


## `Placement.candidates`: every footprint centre wholly inside the rect,
## row major over a fixed grid, no randomness.
func _candidates(at: Vector3, extent: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var span_x := maxf(extent.x - STANCE.x, 0.0)
	var span_z := maxf(extent.z - STANCE.z, 0.0)
	for xi in GRID:
		for zi in GRID:
			var u := float(xi) / float(GRID - 1)
			var v := float(zi) / float(GRID - 1)
			out.append(Vector3(at.x - span_x / 2.0 + span_x * u, at.y,
					at.z - span_z / 2.0 + span_z * v))
	return out


## `RoomAudit.player_stands_here`: support at the declared height, and
## room to stand up on it.
func _stands(spot: Vector3, to_world: Transform3D,
		space: PhysicsDirectSpaceState3D) -> bool:
	var world: Vector3 = to_world * spot
	var down := PhysicsRayQueryParameters3D.create(
			world + Vector3.UP * 0.4, world + Vector3.DOWN * GROUND_REACH)
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		return false
	if absf(world.y - (hit["position"] as Vector3).y) > HEIGHT_TOLERANCE:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(STANCE.x, HEADROOM - LIFT, STANCE.z)
	query.shape = box
	query.transform = Transform3D(to_world.basis,
			world + Vector3.UP * (LIFT + (HEADROOM - LIFT) / 2.0))
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()


func _init() -> void:
	var doc: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(REGISTRY))
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

		var space := holder.get_world_3d().direct_space_state
		var to_world := room.global_transform
		var offers: Array[String] = []
		var tightest := 1.0
		for surface_raw: Variant in entry.get("surfaces", []):
			var surface: Dictionary = surface_raw
			var centre: Array = surface["center"]
			var extent: Array = surface["extent"]
			var at := Vector3(float(centre[0]), float(centre[1]),
					float(centre[2]))
			var rect := Vector3(float(extent[0]), 0.0, float(extent[1]))
			var named := str(surface.get("name", "?"))
			if rect.x < STANCE.x or rect.z < STANCE.z:
				offers.append("'%s' is %.2f x %.2f and a player is %.2f "
						% [named, rect.x, rect.z, STANCE.x] + "across")
				continue
			var spots := _candidates(at, rect)
			var usable := 0
			for spot: Vector3 in spots:
				if _stands(spot, to_world, space):
					usable += 1
			if usable == 0:
				offers.append("'%s' at y=%.2f offers NOWHERE to stand "
						% [named, at.y] + "in %d spots" % spots.size())
			else:
				tightest = minf(tightest,
						float(usable) / float(spots.size()))

		print(("[collision] %-24s bodies=%-3d convex=%-3d concave=%-3d "
				+ "visible_meshes=%-2d | %d surface(s), every one offers a "
				+ "placement (tightest %.0f%% of spots)")
				% [id, bodies, convex, concave, meshes,
					(entry.get("surfaces", []) as Array).size(),
					tightest * 100.0] if offers.is_empty()
				else ("[collision] %-24s bodies=%-3d convex=%-3d "
				+ "concave=%-3d visible_meshes=%-2d | %d surface(s) offer "
				+ "nowhere to stand")
				% [id, bodies, convex, concave, meshes, offers.size()])
		for line: String in offers:
			print("[collision]   ^ %s" % line)
		if bodies == 0 or convex + concave == 0:
			print("[collision]   ^ NO COLLISION -- not measurable")
			bad += 1
		elif not offers.is_empty():
			bad += 1
		room.queue_free()
		await physics_frame

	print("[collision] %d shell(s), %d needing attention"
			% [shells.size(), bad])
	print("[collision] EVIDENCE ONLY, and to owner ruling C(ii): a "
			+ "Surface owes ONE findable placement, not a clear rect. "
			+ "RoomAudit remains the authority.")
	quit(1 if bad > 0 else 0)
