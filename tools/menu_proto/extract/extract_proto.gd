extends SceneTree
## ART-LANE SCRATCH (Track A2, the interactive prototype): Production's OWN
## queries over Production's OWN saves, dumped as the prototype's sample.
## Nothing here decides a word the menus say; it records what Production's
## code answers. Lives only in a throwaway worktree of the Production branch.
##
##   godot -s res://_artlane/extract_proto.gd -- <out.json> <stress.json> <rev>
##
## Beyond what the studies took, it records what an INTERACTIVE face needs
## so that no answer has to be re-derived in the prototype:
##
## * every item's component description (the Equipment face's body text);
## * `EquipmentQuery.comparison` for EVERY candidate against EVERY item that
##   could be on its key -- so a previewed equip compares against the item
##   the preview put there, with Production's words;
## * `EquipmentQuery.refusal` for every item on every key;
## * each journal line's LINK: the connector, circuit or room it names,
##   found by re-writing the line with JournalQuery's own helpers and
##   matching it EXACTLY. A line that cannot be matched fails the run.

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
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
				TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var a := []
			for x in v:
				a.append(_plain(x))
			return a
		TYPE_OBJECT:
			return str(v)
	return v


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _fail(msg: String) -> void:
	push_error("[extract] " + msg)
	printerr("USER ERROR: [extract] " + msg)
	quit(1)


# ------------------------------------------------------------ equipment

func _equipment_variant(Q: GDScript, K: GDScript, snap: Dictionary,
		slots: Array, authored: Array) -> Dictionary:
	var rows: Array = Q.items(snap, snap.get("interpretations", []))
	var items := []
	for row: Dictionary in rows:
		var cid := str(row.get("component_id", ""))
		var component: Dictionary = row.get("component", {})
		var refusals := {}
		for s: String in slots:
			refusals[s] = Q.refusal(row, s)
		var echoes := []
		for e: Variant in row.get("echoes", []):
			var echo: Dictionary = e
			echoes.append({"name": str(echo.get("display_name", "")),
				"description": str(echo.get("description", "")),
				"mode": str(echo.get("mode", "")),
				"concepts": echo.get("concepts", [])})
		items.append({
			"id": cid, "name": Q.name_of(row), "kind": Q.kind_of(row),
			"family": Q.family(row), "source_game": Q.source_game(row),
			"description": str(component.get("description", "")),
			"mk": int(row.get("mk", 1)), "equipped_in": Q.equipped_in(row),
			"home_slot": Q.home_slot(row), "slotted": Q.is_slotted(row),
			"consumable": Q.is_consumable(row),
			"activation": str(row.get("activation", "")),
			"fits": row.get("compatible_slots", []),
			"charges_left": row.get("charges_left"),
			"charges_max": row.get("charges_max"),
			"siblings": row.get("siblings", []),
			"newest_seq": int(row.get("newest_seq", -1)),
			"does": Q.does(row), "use": Q.use_lines(row, rows),
			"cost": Q.cost_lines(row), "history": Q.history(row),
			"read": Q.read_lines(row), "echoes": echoes,
			"refusal": refusals, "held_back": Q.held_back(row),
			"authored": authored.has(cid),
		})
	# Every candidate against every item that could be on its key: the
	# preview's comparisons are Production's, whatever the preview seats.
	var comparisons := {}
	for s: String in slots:
		var fits := []
		for row: Dictionary in rows:
			if (row.get("compatible_slots", []) as Array).has(s):
				fits.append(row)
		var table := {}
		for cand: Dictionary in fits:
			var against := {}
			for occ: Dictionary in fits:
				if occ == cand:
					continue
				against[str(occ["component_id"])] = Q.comparison(cand, occ)
			table[str(cand["component_id"])] = against
		comparisons[s] = table
	var keys := []
	for s: String in slots:
		keys.append({"slot": s, "title": Q.slot_title(s), "keycap": K.of(s),
			"view": Q.slot_view(snap, s)})
	return {"items": items, "keys": keys, "comparisons": comparisons,
		"territories": (snap.get("inventory", {}) as Dictionary).get(
			"territories", []),
		"sort_labels": Q.SORT_LABELS}


func _equipment(stress_path: String) -> Dictionary:
	var Q: GDScript = load("res://scripts/ui/equipment_query.gd")
	var K: GDScript = load("res://scripts/ui/slot_keycaps.gd")
	var slots: Array = root.get_node("Constants").SLOT_NAMES
	var fixture: Dictionary = _json("res://tests/fixtures/equipment_snapshot.json")
	var stress: Dictionary = _json(stress_path)
	return {
		"slots": slots,
		"base": _equipment_variant(Q, K, fixture["base"], slots, []),
		"stress": _equipment_variant(Q, K, stress["snapshot"], slots,
			stress["authored"]),
	}


# ------------------------------------------------------------ map + journal

## One save, both faces: MapFace's rows over the save's own zone_map, and
## JournalQuery's answers over the same save, each line with its link.
func _save(J: GDScript, zone: Node, snap: Dictionary) -> Dictionary:
	var client: Node = root.get_node("BridgeClient")
	client.set("snapshot", {"type": "campaign_snapshot",
		"zone_map": snap["zone_map"]})
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
	var bands := {}
	for row: Dictionary in rooms:
		var rid := str(row.get("id", ""))
		face.call("pick", rid)
		details[rid] = face.call("detail_text")
		bands[rid] = face.call("band_of_room", rid)
	var map := {"zone_map": snap["zone_map"], "rooms": rooms,
		"connectors": connectors, "points": points,
		"floors": face.call("floors"), "bands": bands,
		"player_floor": face.call("player_floor"),
		"blockers": face.call("blockers_shown"),
		"colours": face.get("colours"), "details": details,
		"pulse_hz": face.get("PULSE_HZ"),
		"pulse_swing": face.get("PULSE_SWING")}
	face.queue_free()
	var journal := {"objectives": J.objectives(snap),
		"done_here": J.done_here(snap), "still_shut": J.still_shut(snap),
		"places": J.places(snap),
		"notes": J.notes(snap.get("interpretations", [])),
		"campaign": J.campaign(snap, true)}
	journal["links"] = _links(J, snap, journal)
	return {"map": map, "journal": journal}


## Each journal line's link, by re-writing the line with JournalQuery's
## own helpers and matching it EXACTLY -- never by its position among
## lines. What a line names: a connector (STILL SHUT), a circuit's
## connectors (a setting, a latch, a lock -- "Open now: ..."), a room
## (PLACES). A line with no place on the map has no link.
func _links(J: GDScript, snap: Dictionary, journal: Dictionary) -> Dictionary:
	var map: Dictionary = J.zone_map(snap)
	var names: Dictionary = J.room_names(map)
	var out := {"still_shut": [], "done_here": [], "places": []}
	# STILL SHUT: JournalQuery.still_shut's own sentence, per connector.
	var shut_lines: Array = journal["still_shut"]
	for raw: Variant in map.get("connectors", []):
		var row: Dictionary = raw
		var state := str(row.get("state", "open"))
		if state == "open":
			continue
		var reason := str(row.get("reason", ""))
		var line := "%s: %s" % [J._way(names, str(row.get("room_a", "")),
				str(row.get("room_b", ""))),
				reason if reason != "" else (
					"shut; only the room can tell" if state == "unknown"
					else "shut")]
		var at := shut_lines.find(line)
		if at < 0:
			_fail("a shut connector's sentence is not in still_shut: " + line)
			return {}
		out["still_shut"].append({"index": at, "text": line,
			"edge_id": str(row.get("edge_id", "")), "state": state,
			"circuits": row.get("circuits", [])})
	if (out["still_shut"] as Array).size() != shut_lines.size():
		_fail("still_shut has lines no connector accounts for")
		return {}
	# DONE HERE: the lines that say what they opened.
	var zone: Dictionary = J.active_zone(snap)
	var progress: Dictionary = zone.get("progress", {}) \
			if typeof(zone.get("progress")) == TYPE_DICTIONARY else {}
	var declared: Dictionary = zone.get("zone", {}) \
			if typeof(zone.get("zone")) == TYPE_DICTIONARY else {}
	var done: Array = journal["done_here"]
	var initial := {}
	for raw: Variant in declared.get("zone_state", []):
		var v: Dictionary = raw
		initial[str(v.get("variable_id", ""))] = str(v.get("initial", ""))
	for raw: Variant in J._pairs(progress.get("macro_state", [])):
		var pair: Array = raw
		var variable := str(pair[0])
		var value := str(pair[1])
		if initial.get(variable, "") == value:
			continue
		var circuit: Dictionary = J._circuit(map, "state:" + variable)
		var line := "%s: %s" % [J._sentence(J._words(variable)), value]
		var setters: Array = []
		for rid: Variant in circuit.get("rooms", []):
			if names.has(str(rid)):
				setters.append(names[str(rid)])
		if not setters.is_empty():
			line += ", set in %s" % ", ".join(setters)
		line += "." + J._opened_by(map, names, circuit)
		_link_done(out, done, line, [circuit])
	for lock: Variant in J._sorted(progress.get("opened_locks", [])):
		var parts := str(lock).split("/")
		var room := parts[0] if parts.size() > 0 else ""
		var key: String = J._door_key(declared, room,
				parts[1] if parts.size() > 1 else "")
		var line := "Unlocked the %s door%s." % [
				J._key_words(declared, key) if key != "" else "locked",
				J._in(names, room)]
		_link_done(out, done, line, [J._circuit(map, "key:" + key)])
	for latch: Variant in J._sorted(progress.get("latched", [])):
		var package := str(latch).split("/")[0]
		var room := package.trim_prefix("graph_")
		var line := "A latch held%s." % J._in(names, room)
		var circuits := []
		for raw: Variant in map.get("circuits", []):
			var circuit: Dictionary = raw
			if str(circuit.get("circuit_id", "")).begins_with(
					"machine:%s:" % room):
				line += J._opened_by(map, names, circuit)
				circuits.append(circuit)
		_link_done(out, done, line, circuits)
	# PLACES: the n-th discovered, named room -- matched by its name.
	var places: Array = journal["places"]
	for raw: Variant in map.get("rooms", []):
		var row: Dictionary = raw
		if bool(row.get("discovered", false)) and str(row.get("name", "")) != "":
			var at := places.find(str(row["name"]))
			if at < 0:
				_fail("a discovered room is not in places: " + str(row["name"]))
				return {}
			out["places"].append({"index": at, "text": str(row["name"]),
				"room_id": str(row["room_id"])})
	return out


func _link_done(out: Dictionary, done: Array, line: String,
		circuits: Array) -> void:
	var at := done.find(line)
	if at < 0:
		_fail("a done-here sentence did not match: " + line)
		return
	var edges := []
	var ids := []
	for c: Variant in circuits:
		var circuit: Dictionary = c
		if circuit.is_empty():
			continue
		ids.append(str(circuit.get("circuit_id", "")))
		for e: Variant in circuit.get("connectors", []):
			edges.append(str(e))
	out["done_here"].append({"index": at, "text": line, "circuits": ids,
		"edges": edges})


# ------------------------------------------------------------ run

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0]
	var stress_path: String = args[1]
	var rev: String = args[2]
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
	var J: GDScript = load("res://scripts/ui/journal_query.gd")
	var journal: Dictionary = _json("res://tests/fixtures/journal_snapshot.json")
	var saves := {}
	for variant: String in ["walked", "progressed", "latched"]:
		saves[variant] = _save(J, zone, journal[variant])
		await process_frame
	var dump := {
		"_source": {"production_rev": rev,
			"note": "SAMPLE DATA. Production's own queries (EquipmentQuery, "
				+ "MapFace, JournalQuery, ZoneController) over Production's "
				+ "own fixtures, plus ONE authored layout-stress Echo log "
				+ "folded by Production's own model (stress_equipment.py)."},
		"equipment": _equipment(stress_path),
		"saves": saves,
		"save_order": ["walked", "progressed", "latched"],
	}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_plain(dump), " ", true))
	f.close()
	print("[extract] prototype sample -> %s" % out_path)
	quit(0)
