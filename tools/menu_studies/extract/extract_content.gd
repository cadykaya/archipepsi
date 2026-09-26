extends SceneTree
## ART-LANE SCRATCH (Track A2): Production's OWN queries over Production's
## OWN fixtures, dumped as the studies' sample content. Nothing here decides
## a word the menus say; it only records what Production's code answers.
## Lives only in a throwaway worktree of the Production branch.

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
		TYPE_RECT2:
			return {"position": _plain(v.position), "size": _plain(v.size)}
		TYPE_COLOR:
			return "#" + v.to_html(false)
		TYPE_FLOAT:
			return snappedf(v, 0.001)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _plain(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var a := []
			for x in v:
				a.append(_plain(x))
			return a
		TYPE_OBJECT:
			return str(v)
	return v


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _equipment() -> Dictionary:
	var Q: GDScript = load("res://scripts/ui/equipment_query.gd")
	var slots: Array = root.get_node("Constants").SLOT_NAMES
	var fixture: Dictionary = _json("res://tests/fixtures/equipment_snapshot.json")
	var out := {}
	for variant: String in ["base", "acquired", "swapped", "exhausted"]:
		var snap: Dictionary = fixture[variant]
		var rows: Array = Q.items(snap, snap.get("interpretations", []))
		var items := []
		for row: Dictionary in rows:
			var cid := str(row.get("component_id", ""))
			var home: String = Q.home_slot(row)
			var occupant := {}
			if home != "":
				var holds: Variant = Q.slot_view(snap, home).get("holds")
				if holds != null and str(holds) != cid:
					occupant = Q.item_by_id(rows, str(holds))
			items.append({
				"id": cid, "name": Q.name_of(row), "kind": Q.kind_of(row),
				"family": Q.family(row), "source_game": Q.source_game(row),
				"mk": int(row.get("mk", 1)), "equipped_in": Q.equipped_in(row),
				"home_slot": home, "consumable": Q.is_consumable(row),
				"activation": str(row.get("activation", "")),
				"charges_left": row.get("charges_left"),
				"charges_max": row.get("charges_max"),
				"siblings": row.get("siblings", []),
				"newest_seq": int(row.get("newest_seq", -1)),
				"does": Q.does(row), "use": Q.use_lines(row, rows),
				"cost": Q.cost_lines(row),
				"compare_to": Q.name_of(occupant) if not occupant.is_empty() else "",
				"comparison": Q.comparison(row, occupant) if not occupant.is_empty() else [],
				"history": Q.history(row), "read": Q.read_lines(row),
				"refusal": Q.refusal(row, home) if home != "" else "",
				"held_back": Q.held_back(row),
			})
		var keys := []
		for s: String in slots:
			keys.append({"slot": s, "title": Q.slot_title(s),
				"view": Q.slot_view(snap, s)})
		out[variant] = {"items": items, "keys": keys,
			"territories": (snap.get("inventory", {}) as Dictionary).get("territories", [])}
	return out


func _map(zone: Node) -> Dictionary:
	var fixture: Dictionary = _json("res://tests/fixtures/map_snapshot.json")
	# The journal's own saves carry their own zone_map of the same Zone:
	# a study that joins the two faces reads both from ONE save.
	var journal: Dictionary = _json("res://tests/fixtures/journal_snapshot.json")
	for variant: String in ["progressed", "latched"]:
		fixture["journal_" + variant] = {"zone_map":
			(journal[variant] as Dictionary)["zone_map"]}
	var client: Node = root.get_node("BridgeClient")
	var out := {}
	for variant: String in ["walked", "carried", "powered", "all_rooms",
			"journal_progressed", "journal_latched"]:
		client.set("snapshot", {"type": "campaign_snapshot",
			"zone_map": (fixture[variant] as Dictionary)["zone_map"]})
		var face: Control = load("res://scripts/ui/map_face.gd").new()
		root.add_child(face)
		face.call("bind", zone)
		face.call("refresh")
		var rooms: Array = face.call("rooms_shown")
		var connectors: Array = face.call("connectors_shown")
		var points := {}
		for row: Dictionary in connectors:
			var eid := str(row.get("edge_id", ""))
			points[eid] = face.call("connector_points", eid)
		var details := {}
		for row: Dictionary in rooms:
			var rid := str(row.get("id", ""))
			face.call("pick", rid)
			details[rid] = face.call("detail_text")
		out[variant] = {"zone_map": (fixture[variant] as Dictionary)["zone_map"],
			"rooms": rooms, "connectors": connectors, "points": points,
			"floors": face.call("floors"), "blockers": face.call("blockers_shown"),
			"colours": face.get("colours"), "details": details}
		face.queue_free()
	return out


func _journal() -> Dictionary:
	var J: GDScript = load("res://scripts/ui/journal_query.gd")
	var fixture: Dictionary = _json("res://tests/fixtures/journal_snapshot.json")
	var out := {}
	for variant: String in ["walked", "progressed", "latched"]:
		var snap: Dictionary = fixture[variant]
		out[variant] = {"objectives": J.objectives(snap),
			"done_here": J.done_here(snap), "still_shut": J.still_shut(snap),
			"places": J.places(snap),
			"notes": J.notes(snap.get("interpretations", [])),
			"campaign": J.campaign(snap, true)}
	return out


func _run() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if main.has_method("boot"):
		main.call("boot")
	for i in 2:
		await process_frame
	var zone: Node = load("res://scripts/gameplay/zone_controller.gd").new()
	var pool: Node = load("res://scripts/gameplay/resource_pool.gd").new()
	pool.name = "ResourcePool"
	zone.add_child(pool)
	root.add_child(zone)
	zone.call("setup", _json("res://tests/fixtures/candidate_zone.json"))
	for i in 3:
		await process_frame
	var dump := {
		"_source": "Production claude/archipepsi-0-4-blindside @ 3b96bc4: "
			+ "EquipmentQuery on equipment_snapshot.json, MapFace bound to "
			+ "candidate_zone.json with map_snapshot.json, JournalQuery on "
			+ "journal_snapshot.json. SAMPLE DATA -- Production's own fixtures.",
		"equipment": _equipment(),
		"map": _map(zone),
		"journal": _journal(),
	}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_plain(dump), " ", true))
	f.close()
	print("[extract] content -> %s" % out_path)
	quit(0)
