extends Node
## H-3D-MAP (CP4): THE MAP WALL, on the real shell and a real built Zone
## (`--map-face`).
##
##     make godot-map-face
##
## The candidate Zone is built through the real `ZoneController`, and the
## face is mounted on the real `MenuShell`'s map page exactly as `Main`
## mounts it. The map state is Dess's projection of that Zone after real
## transitions (`map_snapshot.json`, `make map-fixture`). Keys, pad
## buttons and the pointer go in as device events, through the shell.
##
## **Declared harness steps.** As in `godot-minimap`: the player is placed
## inside a room and `_track_chamber` asked; each variant's map is set as
## the snapshot's `zone_map`; `assume_sent` stands the link up.

const CANDIDATE := "res://tests/fixtures/candidate_zone.json"
const MAPS := "res://tests/fixtures/map_snapshot.json"
const POWER_DOOR := "e:c005:c006"
const SPAN := "e:c002:c003"
const TURNING := "e:c004:c005"
## What a render-only miniature may be made of (§7: "Never duplicate live
## scripts, collision, enemies, reward nodes, sounds or state setters").
const RENDER_ONLY := ["Node3D", "MeshInstance3D", "Label3D"]

var zone: ZoneController
var shell: MenuShell
var face: MapFace
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
	await get_tree().process_frame
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
	shell = MenuShell.new()
	add_child(shell)
	# Mounted exactly as `Main` mounts it.
	face = MapFace.new()
	shell.page_root("map").add_child(face)
	face.bind(zone)
	var layer := CanvasLayer.new()
	add_child(layer)
	minimap = Minimap.new()
	layer.add_child(minimap)
	minimap.bind(zone)
	await _frames(3)
	var shots := _shots_dir()
	if shots != "":
		get_window().size = _shots_size()
		await _frames(3)
		await _shoot(shots)
		_finish()
		return
	await _the_wall_is_filled()
	await _the_shapes_are_the_built_level()
	await _one_projection_two_views()
	await _render_only()
	await _the_cache()
	await _the_green_circuit()
	await _a_reversible_closure_comes_back()
	await _floors_and_cutaway()
	await _keys_turn_the_map_not_the_page()
	await _the_pad()
	await _the_pointer()
	await _what_you_were_looking_at_stays()
	await _places_and_ways_back()
	await _the_hub()
	_finish()


func _finish() -> void:
	shell.close()
	BridgeClient.assume_sent = false
	print("")
	if _failures == 0:
		print("GODOT MAP FACE OK (%d checks, %d notes)" % [_checks, _notes])
		get_tree().quit(0)
		return
	print("GODOT MAP FACE TESTS: %d failures in %d checks"
			% [_failures, _checks])
	get_tree().quit(1)


# ---------------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


## A variant's map as the snapshot's `zone_map`, then the face asked to
## show what changed (the menu is open in every case that looks).
func _use_map(variant: String) -> void:
	BridgeClient.snapshot = {"type": "campaign_snapshot",
			"zone_map": (maps[variant] as Dictionary)["zone_map"]}
	if face != null:
		face.refresh()
	if minimap != null:
		minimap.rebuild()


func _stand_in(room: String) -> void:
	var box: AABB = zone.room_bounds[room]
	zone.player.global_position = box.get_center() \
			- Vector3(0, box.size.y * 0.5 - 0.2, 0)
	zone._track_chamber()
	await _frames(2)


func _open(page := "map") -> void:
	shell.open(page)
	await _frames(3)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await get_tree().process_frame


## Where on the screen a page pixel of the FRONT wall is drawn.
func _screen_point_of(page_pixel: Vector2) -> Vector2:
	var wall := shell.wall(shell.front())
	var wall_size := shell.wall_size()
	var u := page_pixel.x / float(MenuShell.PAGE_PIXELS.x) - 0.5
	var v := 0.5 - page_pixel.y / float(MenuShell.PAGE_PIXELS.y)
	var world := wall.global_transform \
			* Vector3(u * wall_size.x, v * wall_size.y, 0.0)
	return shell.camera().unproject_position(world)


## The middle of the miniature, in page pixels.
func _view_centre() -> Vector2:
	return MapFace.ORIGIN + Vector2(MapFace.VIEW_SIZE) * 0.5


func _drag(from: Vector2, by: Vector2, button: MouseButton) -> void:
	var at := _screen_point_of(from)
	var mask := MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT \
			else MOUSE_BUTTON_MASK_RIGHT
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.position = at
	press.global_position = at
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	for i in 4:
		var move := InputEventMouseMotion.new()
		move.position = at + by * float(i + 1) / 4.0
		move.global_position = move.position
		move.relative = by / 4.0
		move.button_mask = mask
		Input.parse_input_event(move)
		await get_tree().process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = at + by
	release.global_position = at + by
	Input.parse_input_event(release)
	await get_tree().process_frame


func _wheel(at_page: Vector2, button: MouseButton) -> void:
	var at := _screen_point_of(at_page)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await get_tree().process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = at
		event.global_position = at
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _view_state() -> Array:
	return [snappedf(face.yaw, 0.01), snappedf(face.pitch, 0.01),
			snappedf(face.distance, 0.01), face.target.snapped(Vector3.ONE
				* 0.01), face.floor_filter, face.selected]


func _blocker(edge_id: String) -> Dictionary:
	for row: Dictionary in face.blockers_shown():
		if str(row["edge_id"]) == edge_id:
			return row
	return {}


func _minimap_blocker(edge_id: String) -> Dictionary:
	for row: Dictionary in minimap.connectors_drawn():
		if str(row["edge_id"]) == edge_id and str(row["state"]) != "open":
			return row
	return {}


# ---------------------------------------------------------------------------
# The cases
# ---------------------------------------------------------------------------

## The wall no longer holds its place: the miniature is there, and the
## "not built yet" note is gone.
func _the_wall_is_filled() -> void:
	print("  -- the map wall is filled")
	var root := shell.page_root("map")
	_check(root.get_node_or_null("MapFace") == face
			and root.get_node_or_null("Incomplete") == null,
			"the map wall holds the map, and no 'not built yet' note")
	await _open()
	_use_map("walked")
	await _frames(2)
	_check(face.world_root().get_child_count() > 0
			and face.camera().current,
			"the miniature is built and its camera is the view's "
			+ "(%d nodes)" % face.world_root().get_child_count())
	shell.close()


## §6: "Build the map from the accepted realized layout: actual room
## envelopes/geometry, connector chains, vertical changes".
func _the_shapes_are_the_built_level() -> void:
	print("  -- the shapes are the built level")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	var matched := 0
	var roofless := 0
	for row: Dictionary in face.rooms_shown():
		var id := str(row["id"])
		var node := face.room_node(id)
		if node == null:
			continue
		var box: AABB = zone.room_bounds[id]
		var arrival: Vector3 = (zone.room_places[id] as Dictionary).get(
				"arrival", Vector3.ZERO)
		var mesh_box := node.mesh.get_aabb()
		if is_equal_approx(mesh_box.position.x, box.position.x) \
				and is_equal_approx(mesh_box.position.z, box.position.z) \
				and is_equal_approx(mesh_box.size.x, box.size.x) \
				and is_equal_approx(mesh_box.size.z, box.size.z) \
				and is_equal_approx(mesh_box.position.y, arrival.y):
			matched += 1
		if _no_roof(node.mesh, mesh_box.end.y):
			roofless += 1
	var shown := face.rooms_shown().size()
	_check(shown > 0 and matched == shown,
			"every room is its built envelope, standing at its arrival "
			+ "height (%d of %d)" % [matched, shown])
	_check(roofless == shown,
			"and none has a roof: a room is its floor and a low wall "
			+ "(%d of %d)" % [roofless, shown])
	var built: Array = MinimapModel.path_of(zone.room_joins[TURNING])
	var drawn: Array = face.connector_points(TURNING)
	var same := built.size() == drawn.size() and built.size() > 2
	for i in mini(built.size(), drawn.size()):
		same = same and (built[i] as Vector3).is_equal_approx(drawn[i])
	var climb := 0.0
	for p: Vector3 in drawn:
		climb = maxf(climb, absf(p.y - (drawn[0] as Vector3).y))
	_check(same, "%s is built along its chain, point for point, " % TURNING
			+ "in 3D (%d points; it climbs %.1f m)" % [drawn.size(), climb])
	shell.close()


## A mesh with no triangle lying in its top plane: no roof.
func _no_roof(mesh: Mesh, top: float) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(0, verts.size() - 2, 3):
		if is_equal_approx(verts[i].y, top) \
				and is_equal_approx(verts[i + 1].y, top) \
				and is_equal_approx(verts[i + 2].y, top):
			return false
	return true


## §6: "one projection, two views". The map wall and the minimap agree
## about every room, name, gate and colour, because both only ask.
func _one_projection_two_views() -> void:
	print("  -- one projection, two views")
	await _open()
	for variant: String in ["walked", "carried", "powered", "all_rooms"]:
		_use_map(variant)
		await _frames(1)
		var a := {}
		for row: Dictionary in face.rooms_shown():
			a[row["id"]] = row["name"]
		var b := {}
		for row: Dictionary in minimap.rooms_drawn():
			b[row["id"]] = row["name"]
		var gates_a := {}
		for row: Dictionary in face.blockers_shown():
			gates_a[row["edge_id"]] = [row["symbol"], row["colour"]]
		var gates_b := {}
		for row: Dictionary in minimap.connectors_drawn():
			if str(row["state"]) == "open":
				continue
			var mark: Vector2 = row["mark_at"]
			if mark == Vector2.INF:
				continue
			var circuits: Array = row["circuits"]
			gates_b[row["edge_id"]] = [
					"?" if row["state"] == "unknown" else row["symbol"],
					minimap.colours.get(str(circuits[0])
						if not circuits.is_empty() else "",
						Color(0.85, 0.85, 0.85))]
		_check(a == b and not a.is_empty() and gates_a == gates_b,
				"%s: the same %d rooms under the same names, and the same "
				% [variant, a.size()] + "%d blockers in the same colours "
				% gates_a.size() + "with the same letters, on both maps")
	shell.close()


## §7: "Use render-only map geometry/resources. Never duplicate live
## scripts, collision, enemies, reward nodes, sounds or state setters ...
## Opening the map must not send a second Check, run a room `_ready` side
## effect or create another machine simulation. Cache appropriately and
## measure with a representative built Zone."
func _render_only() -> void:
	print("  -- render-only")
	# Another map first, so the build measured below is a real build and
	# not the cache answering (the first sabotage run found this check
	# passing with no build inside it: MF-17).
	_use_map("walked")
	var zone_nodes := _count(zone)
	BridgeClient.sent_intents.clear()
	var built := face.builds
	await _open()
	_use_map("all_rooms")
	await _frames(3)
	var kinds := {}
	var scripted: Array = []
	var total := 0
	for node: Node in _all(face.world_root()):
		total += 1
		kinds[node.get_class()] = int(kinds.get(node.get_class(), 0)) + 1
		if node.get_script() != null:
			scripted.append(node.name)
	var foreign: Array = []
	for kind: String in kinds:
		if not kind in RENDER_ONLY:
			foreign.append(kind)
	_check(foreign.is_empty() and scripted.is_empty() and total > 0,
			"the miniature is %d nodes of %s, none with a script; " % [total,
				kinds] + "nothing else: %s %s" % [foreign, scripted])
	_check(face.builds > built and BridgeClient.sent_intents.is_empty(),
			"opening it and building it (%d build) sent nothing: %s"
			% [face.builds - built, BridgeClient.sent_intents])
	_check(_count(zone) == zone_nodes,
			"and the Zone itself is untouched (%d nodes before and after)"
			% zone_nodes)
	_note("built from %d rooms and %d connectors in %.1f ms"
			% [face.rooms_shown().size(), face.connectors_shown().size(),
				face.build_usec / 1000.0])
	shell.close()


func _count(root: Node) -> int:
	return _all(root).size()


func _all(root: Node) -> Array:
	var out: Array = [root]
	for child: Node in root.get_children():
		out.append_array(_all(child))
	return out


## Built again only when what it shows has changed.
func _the_cache() -> void:
	print("  -- the cache")
	await _open()
	_use_map("carried")
	await _frames(2)
	var before := face.builds
	face.refresh()
	face.refresh()
	await _frames(3)
	_check(face.builds == before,
			"the same map asked for again is not built again (%d builds)"
			% face.builds)
	_use_map("powered")
	await _frames(2)
	_check(face.builds == before + 1,
			"a changed map is built once: %d -> %d" % [before, face.builds])
	shell.close()
	var closed := face.builds
	BridgeClient.snapshot = {"type": "campaign_snapshot",
			"zone_map": (maps["carried"] as Dictionary)["zone_map"]}
	face._on_snapshot({})
	await _frames(3)
	_check(face.builds == closed,
			"and nothing is built while the menu is closed")
	await _open()
	await _frames(2)
	_check(face.builds == closed + 1, "until it is opened")
	shell.close()


## §6's example: "The 3D map draws a small pulsing green indicator at
## that passage/area. If the player merely owns the supply, the barrier
## stays; after installation, it changes only when the real passage
## state changes."
func _the_green_circuit() -> void:
	print("  -- the green circuit")
	await _open()
	_use_map("carried")
	await _frames(2)
	var door := _blocker(POWER_DOOR)
	var colour: Color = face.colours.get("state:cell_power", Color.BLACK)
	_check(not door.is_empty() and door["symbol"] == "P"
			and door["colour"] == colour and door["state"] == "blocked",
			"carrying the cell: a P indicator in the power circuit's colour "
			+ "on the power door: %s" % [door])
	var points: Array = face.connector_points(POWER_DOOR)
	var on_path := false
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var at: Vector3 = door.get("at", Vector3.INF)
		var closest := Geometry3D.get_closest_point_to_segment(at, a, b)
		on_path = on_path or closest.distance_to(at) < 0.05
	_check(on_path, "standing on the connector through the door")
	var node := face.blocker_node(POWER_DOOR)
	var sizes := {}
	for i in 8:
		# By the clock, not by frames: a headless frame can take well under
		# a millisecond, and the pulse is about one beat a second.
		await get_tree().create_timer(0.11).timeout
		await _frames(1)
		if node != null:
			sizes[snappedf(node.scale.x, 0.01)] = true
	_check(sizes.size() > 2, "and it pulses (%d sizes in 0.9 s)"
			% sizes.size())
	_use_map("powered")
	await _frames(2)
	_check(_blocker(POWER_DOOR).is_empty(),
			"installed: the bridge's map opens it, and the indicator is gone")
	shell.close()


func _a_reversible_closure_comes_back() -> void:
	print("  -- a reversible closure comes back")
	await _open()
	_use_map("span_lowered")
	await _frames(1)
	var lowered := _blocker(SPAN).is_empty()
	_use_map("span_stowed")
	await _frames(1)
	var stowed := _blocker(SPAN)
	_check(lowered and not stowed.is_empty() and stowed["symbol"] == "P",
			"the span: no indicator lowered, a P indicator put back")
	shell.close()


## §7: "Offer cutaway roofs or selected-floor isolation so stacked rooms
## remain readable ... distinguish current from other floors".
func _floors_and_cutaway() -> void:
	print("  -- floors")
	await _open()
	_use_map("all_rooms")
	await _stand_in("c001")
	face.refresh()
	await _frames(2)
	var floors := face.floors()
	var mine := face.player_floor()
	_check(floors.size() > 1 and mine >= 0,
			"%d floors known; you stand on floor %d" % [floors.size(),
				mine + 1])
	var solid := 0
	var ghosts := 0
	for row: Dictionary in face.rooms_shown():
		var node := face.room_node(str(row["id"]))
		if bool(node.get_meta("solid")):
			solid += 1
		else:
			ghosts += 1
	_check(solid > 0 and ghosts > 0,
			"every floor shown: yours solid (%d rooms), the others ghosts "
			% solid + "(%d)" % ghosts)
	await _key(KEY_PAGEUP)
	var visible := 0
	var wrong := 0
	for row: Dictionary in face.rooms_shown():
		var node := face.room_node(str(row["id"]))
		if node.visible:
			visible += 1
			if MinimapModel.floor_offset(float(row["floor_y"]),
					float(floors[mine])) != 0:
				wrong += 1
	_check(face.floor_filter == mine and visible == solid and wrong == 0,
			"PgUp shows your floor alone: %d rooms, none from another" % visible)
	await _key(KEY_PAGEUP)
	_check(face.floor_filter == mine + 1 or (mine + 1 >= floors.size()
			and face.floor_filter == -1),
			"PgUp again: the floor above (%d)" % face.floor_filter)
	for i in floors.size() + 1:
		if face.floor_filter == -1:
			break
		await _key(KEY_PAGEUP)
	_check(face.floor_filter == -1,
			"and past the top, every floor again")
	shell.close()


## §7: "Mapping controls must not compete with the page-turn arrows."
func _keys_turn_the_map_not_the_page() -> void:
	print("  -- the keys")
	await _open()
	_use_map("all_rooms")
	await _stand_in("c002")
	face.refresh()
	face.recentre()
	await _frames(2)
	var yaw := face.yaw
	await _key(KEY_RIGHT)
	_check(not is_equal_approx(face.yaw, yaw) and shell.front() == "map",
			"Right turns the map (%.0f -> %.0f), not the page" % [yaw,
				face.yaw])
	var pitch := face.pitch
	await _key(KEY_UP)
	_check(face.pitch > pitch, "Up tilts it (%.1f -> %.1f)" % [pitch,
			face.pitch])
	var far := face.distance
	await _key(KEY_EQUAL)
	_check(face.distance < far, "= zooms in (%.1f -> %.1f)" % [far,
			face.distance])
	await _key(KEY_MINUS)
	await _key(KEY_MINUS)
	_check(face.distance > far, "- zooms out (%.1f)" % face.distance)
	for i in 40:
		await _key(KEY_MINUS)
	_check(is_equal_approx(face.distance, MapFace.MAX_DISTANCE),
			"and stops at %.0f m" % MapFace.MAX_DISTANCE)
	var at := face.target
	await _key(KEY_W)
	await _key(KEY_D)
	_check(face.target.distance_to(at) > 1.0,
			"W and D pan (%.1f m)" % face.target.distance_to(at))
	await _key(KEY_C)
	var you := zone.player.global_position
	_check(face.target.is_equal_approx(you) and face.selected == "",
			"C: back to you")
	var pages: Array = []
	for code: Key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_W, KEY_A,
			KEY_S, KEY_D, KEY_EQUAL, KEY_MINUS, KEY_C, KEY_PAGEUP,
			KEY_PAGEDOWN, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_HOME]:
		await _key(code)
		pages.append(shell.front())
	_check(pages.all(func(p: Variant) -> bool: return p == "map"),
			"none of the map's keys turns the page: %s" % [pages])
	await _key(KEY_Q)
	await _frames(20)
	_check(shell.front() == "journal",
			"and Q still does: the map -> '%s'" % shell.front())
	shell.close()


func _the_pad() -> void:
	print("  -- the pad")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	face.floor_filter = -1
	await _pad(JOY_BUTTON_DPAD_UP)
	_check(face.floor_filter == face.player_floor(),
			"the d-pad's up shows one floor: %d" % face.floor_filter)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_check(face.selected != "", "its right picks a place: %s" % face.selected)
	var yaw := face.yaw
	await _stick(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(10)
	await _stick(JOY_AXIS_RIGHT_X, 0.0)
	var turned := face.yaw
	await _frames(10)
	_check(not is_equal_approx(turned, yaw)
			and is_equal_approx(face.yaw, turned),
			"the right stick turns it while held, and stops when let go "
			+ "(%.0f -> %.0f)" % [yaw, turned])
	await _pad(JOY_BUTTON_Y)
	_check(face.selected == ""
			and face.target.is_equal_approx(zone.player.global_position),
			"Y: back to you")
	_check(shell.front() == "map", "and the page never turned")
	# A stick held as the page turns away must not keep turning the map.
	await _stick(JOY_AXIS_RIGHT_X, 1.0)
	shell.turn(1)
	await _frames(30)
	var away := face.yaw
	await _frames(10)
	_check(is_equal_approx(face.yaw, away),
			"a stick still held when the page turned away turns nothing")
	await _stick(JOY_AXIS_RIGHT_X, 0.0)
	shell.close()


## The pointer, carried through the 3D stage like every other page's.
func _the_pointer() -> void:
	print("  -- the pointer")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	var yaw := face.yaw
	await _drag(_view_centre(), Vector2(60, 0), MOUSE_BUTTON_LEFT)
	_check(not is_equal_approx(face.yaw, yaw),
			"a drag across the miniature turns it (%.0f -> %.0f)"
			% [yaw, face.yaw])
	var at := face.target
	await _drag(_view_centre(), Vector2(0, 60), MOUSE_BUTTON_RIGHT)
	_check(face.target.distance_to(at) > 0.5,
			"a right-drag pans it (%.1f m)" % face.target.distance_to(at))
	var far := face.distance
	await _wheel(_view_centre(), MOUSE_BUTTON_WHEEL_UP)
	_check(face.distance < far, "the wheel zooms (%.1f -> %.1f)" % [far,
			face.distance])
	var buttons := face.place_buttons()
	var first: Button = buttons[1] if buttons.size() > 1 else null
	if first != null:
		var centre := first.get_global_rect().get_center()
		var at_screen := _screen_point_of(centre)
		var move := InputEventMouseMotion.new()
		move.position = at_screen
		move.global_position = at_screen
		Input.parse_input_event(move)
		await get_tree().process_frame
		for down: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = at_screen
			click.global_position = at_screen
			click.pressed = down
			Input.parse_input_event(click)
			await get_tree().process_frame
	_check(first != null and face.selected == str(first.get_meta("room_id")),
			"a click on a place picks it: %s" % face.selected)
	shell.close()


## §7: "preserve useful inspection state through page changes".
func _what_you_were_looking_at_stays() -> void:
	print("  -- what you were looking at stays")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	await _key(KEY_BRACKETRIGHT)
	await _key(KEY_BRACKETRIGHT)
	await _key(KEY_RIGHT)
	await _key(KEY_EQUAL)
	await _key(KEY_PAGEUP)
	var kept := _view_state()
	await _key(KEY_Q)
	await _frames(20)
	await _key(KEY_E)
	await _frames(20)
	_check(shell.front() == "map" and _view_state() == kept,
			"a turn to the journal and back keeps the view, the floor and "
			+ "the place: %s" % [kept])
	shell.close()
	await _frames(2)
	await _open()
	_check(_view_state() == kept, "and so do a close and a reopen")
	shell.close()


## §7: "Known destinations and return routes should remain inspectable
## without spoilers." §6: "Do not reveal undiscovered control locations".
func _places_and_ways_back() -> void:
	print("  -- places and ways back")
	await _open()
	_use_map("walked")
	await _frames(2)
	var found: Array = []
	for raw: Variant in maps["walked"]["zone_map"]["rooms"]:
		if bool((raw as Dictionary)["discovered"]):
			found.append(str((raw as Dictionary)["room_id"]))
	found.sort()
	var listed: Array = []
	for button: Node in face.place_buttons():
		listed.append(str(button.get_meta("room_id")))
	# Found in the bridge's map, or walked this session: nothing else.
	var expected := {}
	for id: String in found:
		expected[id] = true
	for id: Variant in zone.rooms_entered():
		expected[str(id)] = true
	var want: Array = expected.keys()
	want.sort()
	_check(not listed.is_empty() and listed == want,
			"the places you know are the rooms found or walked, and "
			+ "nothing beyond them: %s" % [listed])
	face.pick("c002")
	var said := face.detail_text()
	var room_name := ""
	for row: Dictionary in face.rooms_shown():
		if str(row["id"]) == "c002":
			room_name = str(row["name"])
	_check(room_name != "" and said.begins_with(room_name.to_upper())
			and said.contains("blocked")
			and said.contains("set by a control in"),
			"picking %s says its name and each way on, with the " % room_name
			+ "bridge's reasons:\n%s" % said)
	_check(not said.contains("c0"), "and no save id")
	_use_map("all_rooms")
	await _frames(2)
	var rings := 0
	for row: Dictionary in face.connectors_shown():
		if str(row["realization"]) == "traversal_only" \
				and face.plug_node(str(row["edge_id"])) != null:
			rings += 1
	_check(rings == zone.plug_positions.size() and rings > 0,
			"every way back the bridge lists is a ring where it stands (%d)"
			% rings)
	shell.close()


func _the_hub() -> void:
	print("  -- the Hub")
	face.bind(null)
	await _open()
	await _frames(2)
	var note := face.get_node("HubNote") as Label
	_check(note.visible and face.world_root().get_child_count() == 0,
			"in the Hub the wall says there is no map here, and draws nothing")
	shell.close()
	face.bind(zone)


# ---------------------------------------------------------------------------
# Screenshots (`make map-face-shots`)
# ---------------------------------------------------------------------------

func _shots_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			return arg.substr("--shots=".length())
	return ""

## `--shots-size=WxH`: the window the screenshots are taken at (CP4's
## "resizing" proof). Absent, the suite's own 1280 x 720.
func _shots_size() -> Vector2i:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-size="):
			var parts := arg.substr("--shots-size=".length()).split("x")
			if parts.size() == 2:
				return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(1280, 720)


func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for shot: Array in [["all_rooms", "c009", "every_floor_from_c009", ""],
			["all_rooms", "c001", "your_floor_alone_from_c001", "floor"],
			["carried", "c005", "power_door_blocked_from_c005", "c005"],
			["powered", "c005", "power_door_open_from_c005", "c005"]]:
		_use_map(str(shot[0]))
		await _stand_in(str(shot[1]))
		face.bind(zone)
		face.floor_filter = -1
		face.recentre()
		await _open()
		face.refresh()
		if str(shot[3]) == "floor":
			face.step_floor(1)
		elif str(shot[3]) != "":
			face.pick(str(shot[3]))
		await _frames(10)
		var image := get_viewport().get_texture().get_image()
		var path := dir.path_join("map_%s.png" % str(shot[2]))
		image.save_png(path)
		_check(image.get_width() > 64, "saved %s" % path.get_file())
		shell.close()
		await _frames(2)
