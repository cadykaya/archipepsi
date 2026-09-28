extends SceneTree
## ART-LANE SCRATCH (Track A2): build the candidate Zone the way Production's
## own H-3D-MAP repro driver does, and dump the committed geometry the maps
## read -- room_bounds, room_places, room_joins, plug_positions. Read-only
## on Production's code; lives only in a throwaway worktree.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run.call_deferred()
	return false


func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR3:
			return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
		TYPE_VECTOR2:
			return [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]
		TYPE_AABB:
			return {"position": _plain(v.position), "size": _plain(v.size)}
		TYPE_TRANSFORM3D:
			return {"origin": _plain(v.origin), "basis_z": _plain(v.basis.z)}
		TYPE_FLOAT:
			return snappedf(v, 0.001)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _plain(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var a := []
			for x in v:
				a.append(_plain(x))
			return a
		TYPE_OBJECT:
			return str(v)
	return v


func _run() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if main.has_method("boot"):
		main.call("boot")
	for i in 2:
		await process_frame
	var zone_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://tests/fixtures/candidate_zone.json"))
	# Loaded at RUN time, not named: a class named in a `-s` script is
	# compiled before the autoloads exist, and ZoneController names one.
	var zone: Node = load("res://scripts/gameplay/zone_controller.gd").new()
	var pool: Node = load("res://scripts/gameplay/resource_pool.gd").new()
	pool.name = "ResourcePool"
	zone.add_child(pool)
	root.add_child(zone)
	zone.call("setup", zone_data)
	for i in 3:
		await process_frame
	var dump := {
		"_source": "Production claude/archipepsi-0-4-blindside @ 3b96bc4, "
			+ "ZoneController.setup(candidate_zone.json)",
		"room_bounds": _plain(zone.get("room_bounds")),
		"room_places": _plain(zone.get("room_places")),
		"room_joins": _plain(zone.get("room_joins")),
		"plug_positions": _plain(zone.get("plug_positions")),
	}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(dump, " ", true))
	f.close()
	print("[extract] rooms %d joins %d plugs %d -> %s" % [zone.get("room_bounds").size(),
		zone.get("room_joins").size(), zone.get("plug_positions").size(), out_path])
	quit(0)
