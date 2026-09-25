extends Node
## H-MINIMAP (CP4): THE MAP THAT STAYS ON SCREEN, on a real built Zone
## (`--minimap`).
##
##     make godot-minimap
##
## The candidate Zone (`candidate_zone.json`, the profile the owner played)
## is built through the real `ZoneController`, so every room envelope and
## connector chain is the builder's own. The map state is Dess's
## projection of that same Zone after real transitions
## (`map_snapshot.json`, `make map-fixture`): nothing here writes a gate
## state by hand.
##
## **Declared harness steps.** The player is placed inside a room's
## envelope and `_track_chamber` is asked, where a walk would reach the
## same line; each variant's map is set as the snapshot's `zone_map`, the
## field the bridge fills. `assume_sent` stands the link up so the
## `room_entered` intents are recorded as sent.

const CANDIDATE := "res://tests/fixtures/candidate_zone.json"
const MAPS := "res://tests/fixtures/map_snapshot.json"
const POWER_DOOR := "e:c005:c006"
const SPAN := "e:c002:c003"

var zone: ZoneController
var minimap: Minimap
var maps: Dictionary = {}
var _checks := 0
var _failures := 0
var _notes := 0


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % message)
		return
	_failures += 1
	printerr("FAIL: %s" % message)
	print("FAIL: %s" % message)


func _note(message: String) -> void:
	_notes += 1
	print("  NOTE: %s" % message)


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	get_window().size = Vector2i(1280, 720)
	maps = JSON.parse_string(FileAccess.get_file_as_string(MAPS))
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(CANDIDATE))
	BridgeClient.assume_sent = true
	BridgeClient.sent_intents.clear()
	zone = ZoneController.new()
	var pool := ResourcePool.new()
	pool.name = "ResourcePool"
	zone.add_child(pool)
	get_tree().root.add_child(zone)
	_use_map("start")
	zone.setup(zone_data)
	var layer := CanvasLayer.new()
	add_child(layer)
	minimap = Minimap.new()
	layer.add_child(minimap)
	minimap.bind(zone)
	await _frames(3)
	var shots := _shots_dir()
	if shots != "":
		await _shoot(shots)
		_finish()
		return
	await _the_shapes_are_the_built_level()
	await _entering_a_room_reports_it()
	await _names_come_from_the_bridge()
	await _nothing_undiscovered_is_drawn()
	await _the_green_circuit()
	await _a_reversible_closure_comes_back()
	await _the_player_is_the_centre()
	await _floors()
	await _what_the_plate_draws()
	await _the_ways_back()
	_finish()


func _finish() -> void:
	BridgeClient.assume_sent = false
	print("")
	if _failures == 0:
		print("GODOT MINIMAP OK (%d checks, %d notes)" % [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT MINIMAP TESTS: %d failures in %d checks"
			% [_failures, _checks])
	get_tree().quit(1)


# ---------------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _use_map(variant: String) -> void:
	BridgeClient.snapshot = {"type": "campaign_snapshot",
			"zone_map": (maps[variant] as Dictionary)["zone_map"]}
	if minimap != null:
		minimap.rebuild()


func _stand_in(room: String) -> void:
	var box: AABB = zone.room_bounds[room]
	zone.player.global_position = box.get_center() \
			- Vector3(0, box.size.y * 0.5 - 0.2, 0)
	zone._track_chamber()
	await _frames(2)


func _room_ids() -> Array:
	var out: Array = []
	for row: Dictionary in minimap.rooms_drawn():
		out.append(str(row["id"]))
	out.sort()
	return out


func _connector(edge_id: String) -> Dictionary:
	for row: Dictionary in minimap.connectors_drawn():
		if str(row["edge_id"]) == edge_id:
			return row
	return {}


func _entered_intents(room: String) -> int:
	var n := 0
	for intent: Dictionary in BridgeClient.sent_intents:
		if intent.get("type") == "room_entered" \
				and intent.get("room_id") == room:
			n += 1
	return n


# ---------------------------------------------------------------------------

## §6: "Build the map from the accepted realized layout ... The overview
## graph alone can misrepresent a turning 76-m connector as a straight
## line; the map must not repeat that old traversal-harness error."
func _the_shapes_are_the_built_level() -> void:
	print("  -- the shapes are the built level")
	_use_map("all_rooms")
	var matched := 0
	for row: Dictionary in minimap.rooms_drawn():
		var box: AABB = zone.room_bounds[row["id"]]
		var rect: Rect2 = row["rect"]
		if rect.position.is_equal_approx(Vector2(box.position.x,
				box.position.z)) and rect.size.is_equal_approx(
					Vector2(box.size.x, box.size.z)):
			matched += 1
	# The Zone's own rooms: the builder also places the exit room, which
	# is no room of the map's.
	var declared := 0
	for raw: Variant in maps["all_rooms"]["zone_map"]["rooms"]:
		if zone.room_bounds.has(str((raw as Dictionary)["room_id"])):
			declared += 1
	_check(declared > 0 and matched == declared
			and matched == minimap.rooms_drawn().size(),
			"every room is drawn as its built envelope (%d of %d)"
			% [matched, declared])
	# THE TURNING CONNECTOR: the one whose drawn path strays furthest
	# from the straight line between its ends. A straight line between
	# room centres is the error 04 §6 names; this is what it would hide.
	var turning := {}
	var stray := 0.0
	var joined := 0
	for row: Dictionary in minimap.connectors_drawn():
		var path: PackedVector2Array = row["path"]
		if path.size() < 2:
			continue
		joined += 1
		var off := _deviation(path)
		if off > stray:
			stray = off
			turning = row
	var drawn: PackedVector2Array = turning.get("path",
			PackedVector2Array())
	_check(joined > 0 and stray > 2.0 and drawn.size() > 2,
			"%s turns: its drawn path strays %.1f m from the line between "
			% [turning.get("edge_id", "?"), stray]
			+ "its ends, through %d points (%.1f m along)" % [drawn.size(),
				MinimapModel.length_of(drawn)])
	var join: Dictionary = zone.room_joins.get(str(turning.get("edge_id",
			"")), {})
	var built: Array = MinimapModel.path_of(join) if not join.is_empty() \
			else []
	var same := built.size() == drawn.size()
	for i in mini(built.size(), drawn.size()):
		var at: Vector3 = built[i]
		same = same and drawn[i].is_equal_approx(Vector2(at.x, at.z))
	_check(same, "and every point of it is the built chain's, in order "
			+ "(%d of %d)" % [drawn.size(), built.size()])


## How far a path strays from the straight line between its two ends.
func _deviation(path: PackedVector2Array) -> float:
	var a := path[0]
	var b := path[path.size() - 1]
	var most := 0.0
	for p: Vector2 in path:
		most = maxf(most, p.distance_to(
				Geometry2D.get_closest_point_to_segment(p, a, b)))
	return most


## D-2: "Send room_entered wherever the minimap marks a room seen."
func _entering_a_room_reports_it() -> void:
	print("  -- entering a room marks it and reports it")
	_use_map("start")
	await _stand_in("c001")
	BridgeClient.sent_intents.clear()
	await _stand_in("c002")
	_check(_room_ids().has("c002"),
			"c002 is on the map the moment the player stands in it: %s"
			% [_room_ids()])
	_check(_entered_intents("c002") == 1,
			"and `room_entered` for c002 went once: %s"
			% [BridgeClient.sent_intents])
	await _stand_in("c001")
	await _stand_in("c002")
	_check(_entered_intents("c002") == 1,
			"walking back in does not send it again")
	# The bridge's map does not show c002 yet: the next snapshot resends.
	var resent := zone.resend_undiscovered()
	_check(resent.has("c002") and _entered_intents("c002") == 2,
			"a snapshot whose map lacks it resends it: %s" % [resent])
	_use_map("walked")
	resent = zone.resend_undiscovered()
	_check(resent.is_empty(),
			"and once the bridge's map shows it, nothing is resent: %s"
			% [resent])


## M-3: a room's name is the bridge's, presentation only.
func _names_come_from_the_bridge() -> void:
	print("  -- the room you are in is named")
	_use_map("walked")
	await _stand_in("c002")
	var expect := ""
	for raw: Variant in maps["walked"]["zone_map"]["rooms"]:
		if str((raw as Dictionary)["room_id"]) == "c002":
			expect = str((raw as Dictionary)["name"])
	var label := minimap.get_node("Here") as Label
	_check(expect != "" and label.text == expect,
			"the label reads the bridge's name for c002: '%s' (expected "
			% label.text + "'%s')" % expect)
	_check(not label.text.contains("c0"),
			"and it is not the save's id")


## §6: "Do not reveal undiscovered control locations or hidden Check
## contents as a side effect of the map's access to complete generation
## data."
func _nothing_undiscovered_is_drawn() -> void:
	print("  -- nothing undiscovered is drawn")
	_use_map("walked")
	var found := {}
	for raw: Variant in maps["walked"]["zone_map"]["rooms"]:
		if bool((raw as Dictionary)["discovered"]):
			found[str((raw as Dictionary)["room_id"])] = true
	var stray: Array = []
	for rid: String in _room_ids():
		if not found.has(rid) and not zone.rooms_entered().has(rid):
			stray.append(rid)
	_check(stray.is_empty() and _room_ids().size() < zone.room_bounds.size(),
			"%d of %d rooms drawn, all discovered or walked; none beyond: %s"
			% [_room_ids().size(), zone.room_bounds.size(), stray])
	var listed := {}
	for raw: Variant in maps["walked"]["zone_map"]["connectors"]:
		listed[str((raw as Dictionary)["edge_id"])] = true
	var extra: Array = []
	for row: Dictionary in minimap.connectors_drawn():
		if not listed.has(str(row["edge_id"])):
			extra.append(row["edge_id"])
	_check(extra.is_empty() and minimap.connectors_drawn().size()
			== listed.size(),
			"every connector drawn is one the bridge lists (%d)" % listed.size())


## §6's example: "green supply -> green receiver -> green door. The
## minimap draws a green blocker on the connector through that door. If
## the player merely owns the supply, the barrier stays; after
## installation, it changes only when the real passage state changes."
func _the_green_circuit() -> void:
	print("  -- the green circuit")
	_use_map("carried")
	var door := _connector(POWER_DOOR)
	_check(door.get("state") == "blocked" and door.get("symbol") == "P"
			and (door.get("circuits", []) as Array) == ["state:cell_power"],
			"carrying the cell: the door is a P blocker in its circuit: "
			+ "%s %s %s" % [door.get("state"), door.get("symbol"),
			door.get("circuits")])
	_check(door.get("mark_at", Vector2.INF) != Vector2.INF
			and _on_path(door["path"], door["mark_at"]),
			"its mark sits on the connector through the door")
	var colours := MinimapModel.circuit_colours(zone.zone)
	var colour: Color = colours.get("state:cell_power", Color.BLACK)
	var clashes: Array = []
	for cid: String in colours:
		if cid != "state:cell_power" and colours[cid] == colour:
			clashes.append(cid)
	_check(minimap.colours.get("state:cell_power") == colour
			and clashes.is_empty(),
			"drawn in its circuit's colour, which no other circuit in the "
			+ "Zone shares -- not the green key's, not the span's: %s"
			% [clashes])
	var again := MinimapModel.circuit_colours(zone.zone)
	_check(again == colours,
			"and the colours are the Zone's, the same every time they are "
			+ "asked for")
	# THE RULE, NOT THIS ZONE'S LUCK. Three circuits can miss each other
	# by chance under any scheme; a full palette's worth, dealt in the
	# order the Zone declares them, cannot. (The first sabotage run found
	# a hash of the id passing on this Zone's three: MM-8.)
	var declared: Array = []
	for name: String in ["a", "b", "c", "d", "e"]:
		declared.append({"variable_id": name})
	var dealt := MinimapModel.circuit_colours({"zone_state": declared})
	var in_order := true
	for i in declared.size():
		in_order = in_order and dealt.get("state:" + str(declared[i][
				"variable_id"])) == MinimapModel.PALETTE[i]
	_check(in_order and dealt.values().size() == MinimapModel.PALETTE.size(),
			"five circuits get the palette's five colours, in declared order")
	_use_map("powered")
	door = _connector(POWER_DOOR)
	_check(door.get("state") == "open",
			"installed: the bridge's map opens it, and the map follows: %s"
			% door.get("state"))


func _on_path(path: PackedVector2Array, at: Vector2) -> bool:
	for i in range(1, path.size()):
		var closest := Geometry2D.get_closest_point_to_segment(at,
				path[i - 1], path[i])
		if closest.distance_to(at) < 0.05:
			return true
	return false


## §6: "A reversible closure reappears correctly."
func _a_reversible_closure_comes_back() -> void:
	print("  -- a reversible closure comes back")
	_use_map("span_lowered")
	var lowered := str(_connector(SPAN).get("state"))
	_use_map("span_stowed")
	var stowed := str(_connector(SPAN).get("state"))
	_check(lowered == "open" and stowed == "blocked",
			"the span reads open lowered and blocked put back: %s, %s"
			% [lowered, stowed])


func _the_player_is_the_centre() -> void:
	print("  -- where you are and which way you face")
	await _stand_in("c002")
	var at := zone.player.global_position
	var centre := minimap.to_plate(Vector2(at.x, at.z))
	_check(centre.is_equal_approx(Minimap.SIZE * 0.5),
			"the player is the centre of the plate: %s" % centre)
	var east := minimap.to_plate(Vector2(at.x + 10.0, at.z))
	_check(is_equal_approx(east.x - centre.x, 10.0 * Minimap.PX_PER_M)
			and is_equal_approx(east.y, centre.y),
			"north-up, at %.1f px a metre" % Minimap.PX_PER_M)


## §7: "an unambiguous floor/elevation convention". A room's floor is
## where a body stands on arriving; the envelope's bottom is not a floor
## (a pit reaches far below it).
func _floors() -> void:
	print("  -- floors")
	_use_map("all_rooms")
	var heights := {}
	for row: Dictionary in minimap.rooms_drawn():
		var arrival: Vector3 = (zone.room_places[row["id"]] as Dictionary) \
				.get("arrival", Vector3.ZERO)
		_check(is_equal_approx(float(row["floor_y"]), arrival.y),
				"%s's floor is its arrival height (%.1f)" % [row["id"],
				arrival.y]) if row["id"] in ["c001", "c009", "c021"] else null
		heights[row["id"]] = float(row["floor_y"])
	var lowest := INF
	var highest := -INF
	for rid: Variant in heights:
		lowest = minf(lowest, float(heights[rid]))
		highest = maxf(highest, float(heights[rid]))
	_note("standing heights in the candidate Zone span %.1f m"
			% (highest - lowest))
	_check(MinimapModel.floor_offset(lowest + 1.0, lowest) == 0
			and MinimapModel.floor_offset(lowest + 3.0, lowest) == 1
			and MinimapModel.floor_offset(lowest - 3.0, lowest) == -1,
			"a 1 m step is the same floor; 3 m up or down is another")


## §9: "Long generated names, punctuation and unsupported characters must
## have a visible fallback rather than blanks." Asked of what the plate
## actually drew, not of the model: every character it typed is in the
## font it typed it in, and the floor marks are shapes. (The first draft
## typed ▲ and ▼, which Godot's default font does not have.)
func _what_the_plate_draws() -> void:
	print("  -- what the plate draws")
	_use_map("all_rooms")
	await _stand_in("c001")
	await _frames(2)
	var drew: Dictionary = minimap.draw_log
	var typed: Array = drew["text"]
	var font: Font = (minimap.get_node("Plate") as Control) \
			.get_theme_default_font()
	var missing: Array = []
	for text: String in typed:
		for i in text.length():
			if not font.has_char(text.unicode_at(i)):
				missing.append(text[i])
	var label := minimap.get_node("Here") as Label
	var label_font: Font = label.get_theme_font("font")
	for i in label.text.length():
		if not label_font.has_char(label.text.unicode_at(i)):
			missing.append(label.text[i])
	_check(not typed.is_empty() and missing.is_empty(),
			"every character on the map is in the font it is drawn in "
			+ "(%d strings typed, and the name '%s'); missing: %s"
			% [typed.size(), label.text, missing])
	var other := 0
	for row: Dictionary in minimap.rooms_drawn():
		if MinimapModel.floor_offset(float(row["floor_y"]),
				minimap._player_floor_y()) != 0:
			other += 1
	_check(other > 0 and int(drew["floor_marks"]) == other,
			"from c001, %d rooms are on other floors and %d floor marks "
			% [other, int(drew["floor_marks"])] + "are drawn, as shapes")
	var up := MinimapModel.floor_triangle(Vector2.ZERO, 1)
	var down := MinimapModel.floor_triangle(Vector2.ZERO, -1)
	_check(up[0].y < 0.0 and down[0].y > 0.0,
			"a room above is marked pointing up, one below pointing down")


## §7: "useful known markers". A return plug is a connector with no
## corridor: it is a ring where its device stands, once the bridge lists
## it -- and the bridge lists it only once its own room is found.
func _the_ways_back() -> void:
	print("  -- the ways back")
	_use_map("all_rooms")
	await _stand_in("c001")
	await _frames(2)
	var listed := 0
	var placed := 0
	for row: Dictionary in minimap.connectors_drawn():
		if str(row["realization"]) != "traversal_only":
			continue
		listed += 1
		var at: Variant = zone.plug_positions.get(str(row["edge_id"]))
		if at is Vector3 and (row["mark_at"] as Vector2).is_equal_approx(
				Vector2((at as Vector3).x, (at as Vector3).z)):
			placed += 1
	_check(listed > 0 and placed == listed
			and int(minimap.draw_log["plug_marks"]) == listed,
			"every way back the bridge lists is a ring where its device "
			+ "stands (%d listed, %d placed, %d drawn)" % [listed, placed,
				int(minimap.draw_log["plug_marks"])])
	_use_map("walked")
	await _frames(2)
	_check(zone.plug_positions.size() > 0
			and int(minimap.draw_log["plug_marks"]) == 0,
			"and none is drawn before the bridge lists it: %d of the "
			% int(minimap.draw_log["plug_marks"])
			+ "Zone's %d, with five rooms found" % zone.plug_positions.size())


# ---------------------------------------------------------------------------
# Screenshots (`make minimap-shots`)
# ---------------------------------------------------------------------------

func _shots_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			return arg.substr("--shots=".length())
	return ""


func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for shot: Array in [["walked", "c002", "span_blocked_in_c002"],
			["carried", "c005", "power_door_blocked_in_c005"],
			["powered", "c005", "power_door_open_in_c005"],
			["all_rooms", "c009", "all_rooms_from_c009"]]:
		_use_map(str(shot[0]))
		await _stand_in(str(shot[1]))
		minimap.rebuild()
		await _frames(8)
		var image := get_viewport().get_texture().get_image()
		var path := dir.path_join("minimap_%s.png" % str(shot[2]))
		image.save_png(path)
		_check(image.get_width() > 64, "saved %s" % path.get_file())
