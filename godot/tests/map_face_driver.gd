extends Node
## MENU-INT: THE MAP WALL AS APPROVED -- the LENS, a live 3D miniature seen
## through the riveted port -- on the real shell and a real built Zone
## (`--map-face`).
##
##     make godot-map-face
##
## The candidate Zone is built through the real `ZoneController`, and the
## four walls are mounted on the real `MenuShell` exactly as `Main` mounts
## them. The map state is Dess's projection of that Zone after real
## transitions (`map_snapshot.json`, `make map-fixture`). Keys, pad buttons
## and the pointer go in as device events, through the shell; a click on
## the miniature is aimed where the room is drawn, and checked to be what
## the pointer is over there.
##
## Every guarantee of H-3D-MAP's suite is kept, asked of the lens: the
## shapes are the built level, one projection feeds both maps, the
## miniature is render-only and cached, the green circuit and a reversible
## closure, floors, the keys, the pad, the pointer, what you were looking
## at, places and ways back, the Hub. Added (§8): being shown an entry and
## BACK TO YOUR VIEW, ordinary travel keeping the view, a link into the
## unknown landing on nothing, and the glass's tags never covering each
## other or the room picked.
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
const RENDER_ONLY := ["Node3D", "MeshInstance3D", "Label3D", "Sprite3D"]

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
	_run.call_deferred()


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
	# Mounted exactly as `Main` mounts them.
	var pause := PauseMenu.new()
	shell.add_child(pause)
	var settings := SettingsFace.new()
	settings.bind_pause(pause)
	shell.mount("settings", settings)
	shell.mount("equipment", EquipmentFace.new())
	face = MapFace.new()
	shell.mount("map", face)
	var journal := JournalFace.new()
	journal.bind_map(face)
	shell.mount("journal", journal)
	face.bind(zone)
	await _zone_settled()
	var layer := CanvasLayer.new()
	add_child(layer)
	minimap = Minimap.new()
	layer.add_child(minimap)
	minimap.bind(zone)
	await _frames(3)
	var shots := _arg("--shots=")
	if shots != "":
		var size := _arg("--shots-size=").split("x")
		if size.size() == 2:
			get_window().size = Vector2i(int(size[0]), int(size[1]))
		await _frames(3)
		await _shoot(shots)
		_finish("MAP FACE SHOTS")
		return
	await _the_wall_is_filled()
	await _the_shapes_are_the_built_level()
	await _one_projection_two_views()
	await _render_only()
	await _the_cache()
	await _the_green_circuit()
	await _a_reversible_closure_comes_back()
	await _floors_one_alone_the_rest_dimmed()
	await _keys_turn_the_map_not_the_page()
	await _the_pad()
	await _the_pointer()
	await _what_you_were_looking_at_stays()
	await _places_and_ways_back()
	await _shown_an_entry_and_back()
	await _travel_keeps_the_view()
	await _the_glass_tags()
	await _the_hub()
	_finish("GODOT MAP FACE")


func _finish(what: String) -> void:
	shell.close()
	BridgeClient.assume_sent = false
	print("")
	if _failures == 0:
		print("%s OK (%d checks, %d notes)" % [what, _checks, _notes])
		get_tree().quit(0)
		return
	print("%s TESTS: %d failures in %d checks" % [what, _failures, _checks])
	get_tree().quit(1)


func _arg(flag: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag):
			return arg.substr(flag.length())
	return ""


# ---------------------------------------------------------------------------

## The Zone certifies its chains and sends its layout on its own, over its
## first frames (`ZoneController._publish_layout`: replay runs that come
## and go under the chain's room). The cases wait for that to be done, so
## the Zone's own work is never counted as the map's.
func _zone_settled() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		for intent: Dictionary in BridgeClient.sent_intents:
			if str(intent.get("type", "")) == "layout_result":
				BridgeClient.sent_intents.clear()
				return
		await get_tree().process_frame
	_note("the Zone had not sent its layout after 30 s")


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


## Everything in flight on the walls arrived (the lens glides; a turn
## turns), or two seconds.
func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while (shell.kit.busy() or shell.is_turning()) \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _frames(2)


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
	await _settle()


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


## The middle of the lens's window, on the screen.
func _window_centre() -> Vector2:
	return shell.screen_of("map", MapFace.WINDOW.get_center())


func _drag(at: Vector2, by: Vector2, button: MouseButton) -> void:
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


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await get_tree().process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func _wheel(at: Vector2, button: MouseButton) -> void:
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


## Where a known room's floor centre is drawn on the screen now.
func _screen_of_room(id: String) -> Vector2:
	var local: Vector3 = (face._mini[id] as Dictionary)["centre"]
	var world := face.face.global_transform * (face.world_root().transform * local)
	return shell.camera().unproject_position(world)


## A room the pointer is over where its floor is drawn (nothing in front of
## it): the room a hand could click.
func _clickable_room(skip := "") -> String:
	for id: String in face.known():
		if id == skip or not face._mini.has(id):
			continue
		if face._floor_view(id) == "hidden":
			continue
		var at := _screen_of_room(id)
		if face._ray_pick(shell.pick_at(at)) == id:
			return id
	return ""


func _view_state() -> Array:
	var st := face.state()
	return [st["yaw"], st["pitch"], st["zoom"], st["target"], st["floor"],
			st["alone"], st["picked"], st["expanded"]]


func _blocker(edge_id: String) -> Dictionary:
	for row: Dictionary in face.blockers_shown():
		if str(row["edge_id"]) == edge_id:
			return row
	return {}


## Whether the glass carries an exit tag for this way.
func _exit_tag(edge_id: String) -> bool:
	for t: Dictionary in face._tags:
		if str(t["kind"]) == "exit" and str(t["ref"]) == edge_id:
			return true
	return false


func _count(root: Node) -> int:
	return _all(root).size()


func _all(root: Node) -> Array:
	var out: Array = [root]
	for child: Node in root.get_children():
		out.append_array(_all(child))
	return out


# ---------------------------------------------------------------------------
# The cases
# ---------------------------------------------------------------------------

## The map wall holds the lens: the miniature, built, behind the port.
func _the_wall_is_filled() -> void:
	print("  -- the map wall is filled")
	await _open()
	_use_map("walked")
	await _frames(2)
	_check(shell.controller("map") == face and not face.hub_note().visible,
			"the map wall holds the map, and no 'no map here' note")
	var root := face.world_root()
	var behind := (root.transform.origin.z < -0.5) \
			and root.get_parent() == shell.face_node("map")
	_check(root.get_child_count() > 0 and behind,
			"the miniature is built (%d nodes) and stands behind the wall's "
			% _count(root) + "port, in the box's own world")
	_check(not shell.wall("map").visible,
			"the wall is a frame round an opening, not a painted panel")
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
	var shown := face.rooms_shown().size()
	for row: Dictionary in face.rooms_shown():
		var id := str(row["id"])
		var node := face.room_node(id)
		if node == null:
			continue
		var box: AABB = zone.room_bounds[id]
		var arrival: Vector3 = (zone.room_places[id] as Dictionary).get(
				"arrival", Vector3.ZERO)
		var envelope: AABB = node.get_meta("envelope")
		var lens_box := AABB(face.to_lens(envelope.position), Vector3.ZERO) \
				.expand(face.to_lens(envelope.end))
		var mesh_box := node.mesh.get_aabb()
		if is_equal_approx(envelope.position.x, box.position.x) \
				and is_equal_approx(envelope.position.z, box.position.z) \
				and is_equal_approx(envelope.size.x, box.size.x) \
				and is_equal_approx(envelope.size.z, box.size.z) \
				and is_equal_approx(envelope.position.y, arrival.y) \
				and mesh_box.position.is_equal_approx(lens_box.position) \
				and mesh_box.size.is_equal_approx(lens_box.size):
			matched += 1
		if _no_roof(node.mesh, lens_box.end.y):
			roofless += 1
	_check(shown > 0 and matched == shown,
			"every room is its built envelope, standing at its arrival "
			+ "height, drawn to it in the lens (%d of %d)" % [matched, shown])
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
	for surface in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(surface)[
				Mesh.ARRAY_VERTEX]
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
	# not the cache answering (MF-17).
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
			"and the Zone itself is untouched (%d nodes before, %d after)"
			% [zone_nodes, _count(zone)])
	_note("built from %d rooms and %d connectors in %.1f ms"
			% [face.rooms_shown().size(), face.connectors_shown().size(),
				face.build_usec / 1000.0])
	shell.close()


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


func _views() -> Dictionary:
	var out := {"shown": [], "dimmed": [], "hidden": []}
	for row: Dictionary in face.rooms_shown():
		var node := face.room_node(str(row["id"]))
		(out[str(node.get_meta("floor_view"))] as Array).append(str(row["id"]))
	return out


## §7: "Offer cutaway roofs or selected-floor isolation so stacked rooms
## remain readable ... distinguish current from other floors"; §8: "Keep
## the real single-floor view alongside dimmed multi-floor context."
func _floors_one_alone_the_rest_dimmed() -> void:
	print("  -- floors: yours, dimmed context, alone")
	await _open()
	face.overview()
	_use_map("all_rooms")
	await _stand_in("c001")
	face.refresh()
	await _frames(2)
	var floors := face.floors()
	var mine := face.player_floor()
	_check(floors.size() > 1 and mine >= 0,
			"%d floors known; you stand on floor %d" % [floors.size(), mine + 1])
	var v := _views()
	_check(not (v["shown"] as Array).is_empty() and not (v["dimmed"] as Array).is_empty()
			and (v["hidden"] as Array).is_empty(),
			"every floor shown: yours at full tone (%d rooms), the others "
			% (v["shown"] as Array).size() + "dimmed (%d), none hidden"
			% (v["dimmed"] as Array).size())
	var yours: Array = v["shown"]
	await _key(KEY_PAGEUP)
	v = _views()
	_check(face.floor_filter == mine and not face.floor_alone
			and v["shown"] == yours and (v["hidden"] as Array).is_empty()
			and str(face.state()["floor_words"]) != "",
			"PgUp: your floor picked out, the others still there, dimmed, "
			+ "and the glass says which: '%s'" % face.state()["floor_words"])
	await _key(KEY_PAGEUP)
	v = _views()
	var wrong := 0
	for id: String in v["shown"]:
		if face.band_of_room(id) != mine:
			wrong += 1
	_check(face.floor_alone and v["shown"] == yours and (v["dimmed"] as Array).is_empty()
			and wrong == 0,
			"PgUp again: your floor alone, %d rooms, none from another"
			% (v["shown"] as Array).size())
	await _key(KEY_PAGEUP)
	_check(face.floor_filter == mine + 1 or (mine + 1 >= floors.size()
			and face.floor_filter == -1),
			"PgUp again: the floor above, with the rest dimmed (%d)"
			% face.floor_filter)
	for i in floors.size() * 2 + 2:
		if face.floor_filter == -1:
			break
		await _key(KEY_PAGEUP)
	_check(face.floor_filter == -1, "and past the top, every floor again")
	shell.close()


## §7: "Mapping controls must not compete with the page-turn arrows."
func _keys_turn_the_map_not_the_page() -> void:
	print("  -- the keys")
	await _open()
	_use_map("all_rooms")
	await _stand_in("c002")
	face.refresh()
	face.recentre()
	await _settle()
	var yaw := face.yaw
	await _key(KEY_RIGHT)
	await _settle()
	_check(not is_equal_approx(face.yaw, yaw) and shell.front() == "map",
			"Right turns the map (%.0f -> %.0f), not the page" % [yaw, face.yaw])
	var pitch := face.pitch
	await _key(KEY_UP)
	await _settle()
	_check(face.pitch > pitch, "Up tilts it (%.1f -> %.1f)" % [pitch, face.pitch])
	var near := face.zoom
	await _key(KEY_EQUAL)
	await _settle()
	_check(face.zoom > near, "= zooms in (x%.2f -> x%.2f)" % [near, face.zoom])
	await _key(KEY_MINUS)
	await _key(KEY_MINUS)
	await _settle()
	_check(face.zoom < near, "- zooms out (x%.2f)" % face.zoom)
	for i in 40:
		await _key(KEY_MINUS)
	await _settle()
	var limits := face.zoom_limits()
	_check(is_equal_approx(face.zoom, limits.x),
			"and stops at its widest (x%.4f)" % limits.x)
	var at: Array = face.state()["target"]
	await _key(KEY_W)
	await _key(KEY_D)
	await _settle()
	_check(face.state()["target"] != at, "W and D pan")
	await _key(KEY_C)
	await _settle()
	_check(face.selected == "" and face.floor_filter == -1
			and is_equal_approx(face.zoom, face.fit),
			"C: the overview, the whole known Zone in the window")
	var pages: Array = []
	for code: Key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_W, KEY_A,
			KEY_S, KEY_D, KEY_EQUAL, KEY_MINUS, KEY_C, KEY_PAGEUP,
			KEY_PAGEDOWN, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_HOME]:
		await _key(code)
		pages.append(shell.front())
	_check(pages.all(func(p: Variant) -> bool: return p == "map"),
			"none of the map's keys turns the page: %s" % [pages])
	await _key(KEY_Q)
	await _settle()
	_check(shell.front() == "journal",
			"and Q still does: the map -> '%s'" % shell.front())
	shell.close()


func _the_pad() -> void:
	print("  -- the pad")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	face.overview()
	await _settle()
	await _pad(JOY_BUTTON_DPAD_UP)
	_check(face.floor_filter == face.player_floor(),
			"the d-pad's up picks out a floor: %d" % face.floor_filter)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_check(face.selected != "" and face.known().has(face.selected),
			"its right picks a known place: %s" % face.selected)
	await _settle()
	var yaw := face.yaw
	await _stick(JOY_AXIS_RIGHT_X, 1.0)
	await get_tree().create_timer(0.3).timeout
	await _stick(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	var turned := face.yaw
	await get_tree().create_timer(0.2).timeout
	_check(not is_equal_approx(turned, yaw)
			and is_equal_approx(face.yaw, turned),
			"the right stick turns it while held, and stops when let go "
			+ "(%.0f -> %.0f)" % [yaw, turned])
	await _pad(JOY_BUTTON_Y)
	await _settle()
	_check(face.selected == "" and face.floor_filter == -1,
			"Y: the overview")
	_check(shell.front() == "map", "and the page never turned")
	# A stick held as the page turns away must not keep turning the map.
	await _stick(JOY_AXIS_RIGHT_X, 1.0)
	shell.turn(1)
	await _settle()
	var away := face.yaw
	await get_tree().create_timer(0.2).timeout
	_check(is_equal_approx(face.yaw, away),
			"a stick still held when the page turned away turns nothing")
	await _stick(JOY_AXIS_RIGHT_X, 0.0)
	shell.close()


## The pointer, carried through the port to the miniature behind it.
func _the_pointer() -> void:
	print("  -- the pointer")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	face.overview()
	await _settle()
	var yaw := face.yaw
	await _drag(_window_centre(), Vector2(60, 0), MOUSE_BUTTON_LEFT)
	_check(not is_equal_approx(face.yaw, yaw),
			"a drag across the miniature turns it (%.0f -> %.0f)" % [yaw, face.yaw])
	var at: Array = face.state()["target"]
	await _drag(_window_centre(), Vector2(0, 60), MOUSE_BUTTON_RIGHT)
	await _settle()
	_check(face.state()["target"] != at, "a right-drag pans it")
	var near := face.zoom
	await _wheel(_window_centre(), MOUSE_BUTTON_WHEEL_UP)
	await _settle()
	_check(face.zoom > near, "the wheel zooms (x%.2f -> x%.2f)" % [near, face.zoom])
	face.overview()
	await _settle()
	var room := _clickable_room()
	var drawn := _screen_of_room(room) if room != "" else Vector2.ZERO
	await _click(drawn)
	await _settle()
	_check(room != "" and face.selected == room,
			"a click on a room, where it is drawn in the miniature, picks it: "
			+ "%s" % face.selected)
	var still := _screen_of_room(room) if room != "" else Vector2.INF
	_check(still.distance_to(drawn) < 2.0,
			"and the lens closes round it: it stays under the pointer (%.1f px)"
			% still.distance_to(drawn))
	await _click(still)
	await _settle()
	_check(face.expanded and face.detail_text().begins_with(
			face._room_name(room).to_upper()),
			"a second click on it opens its detail")
	shell.close()
	face.overview()


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
	await _settle()
	var kept := _view_state()
	await _key(KEY_Q)
	await _settle()
	await _key(KEY_E)
	await _settle()
	_check(shell.front() == "map" and _view_state() == kept,
			"a turn to the journal and back keeps the view, the floor and "
			+ "the place: %s" % [kept])
	shell.close()
	await _frames(2)
	await _open()
	_check(_view_state() == kept, "and so do a close and a reopen")
	shell.close()
	face.overview()


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
	# Found in the bridge's map, or walked this session: nothing else.
	var expected := {}
	for id: String in found:
		expected[id] = true
	for id: Variant in zone.rooms_entered():
		expected[str(id)] = true
	var want: Array = expected.keys()
	want.sort()
	var stepped: Array = []
	for i in want.size() + 1:
		await _key(KEY_BRACKETRIGHT)
		if not stepped.has(face.selected):
			stepped.append(face.selected)
	stepped.sort()
	_check(not face.known().is_empty() and face.known() == want and stepped == want,
			"the places [ and ] step through are the rooms found or walked, "
			+ "and nothing beyond them: %s" % [stepped])
	face.pick("c002")
	var said := face.detail_text()
	var room_name := face._room_name("c002")
	_check(room_name != "" and said.begins_with(room_name.to_upper())
			and said.contains("blocked")
			and said.contains("set by a control in"),
			"picking %s says its name and each way on, with the " % room_name
			+ "bridge's reasons:\n%s" % said)
	_check(not said.contains("c0"), "and no save id")
	_check(int(face.state()["edge_marks_unknown"]) == 0,
			"and no mark points at a room not found")
	_use_map("all_rooms")
	await _frames(2)
	var rings := 0
	for row: Dictionary in face.connectors_shown():
		if str(row["realization"]) == "traversal_only" \
				and face.plug_node(str(row["edge_id"])) != null:
			rings += 1
	_check(rings == zone.plug_positions.size() and rings > 0,
			"every way back the bridge lists is a way-out mark where it "
			+ "stands (%d)" % rings)
	# A way back is a way out of the room it stands in (room_a) and of no
	# other: where it lands, it is neither an exit tag nor counted.
	var plug: Dictionary = {}
	for row: Dictionary in face.connectors_shown():
		if str(row["realization"]) == "traversal_only" \
				and face.plug_node(str(row["edge_id"])) != null:
			plug = row
			break
	var eid := str(plug.get("edge_id", ""))
	var stands := str(plug.get("room_a", ""))
	var lands := str(plug.get("room_b", ""))
	face.pick(stands)
	await _frames(2)
	var there := face.detail_text()
	var tagged_there := _exit_tag(eid)
	face.pick(lands)
	await _frames(2)
	var here := face.detail_text()
	var lands_name := face._room_name(lands)
	var stands_name := face._room_name(stands)
	_check(eid != "" and tagged_there
			and there.contains("- a way back to %s: open" % lands_name),
			"where a way back stands it is a way out, and says where it "
			+ "takes you:\n%s" % there)
	_check(not _exit_tag(eid) and not here.contains("- a way back")
			and here.contains("- the way back from %s lands here" % stands_name),
			"where it lands it is not a way out -- no tag, no count -- and "
			+ "says only where it comes from:\n%s" % here)
	shell.close()
	face.overview()


## §8: "Following a journal entry frames its destination and keeps the
## prior view. BACK TO YOUR VIEW stays a direct action. A contextual Back
## prompt must say what the next press does."
func _shown_an_entry_and_back() -> void:
	print("  -- shown an entry, and back to your view")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	await _key(KEY_RIGHT)
	await _key(KEY_PAGEUP)
	await _settle()
	var mine := _view_state()
	face.follow({"room": "c005"})
	await _settle()
	var shown := face.target_world({"room": "c005"})
	_check(face.selected == "c005" and face.can_return()
			and bool(shown.get("inside", false)) and face.floor_filter == -1,
			"shown c005: it is picked, in the window, every floor shown")
	_check(shell.back_words() == "your view" and face.state()["back"] == "your view",
			"and the Back prompt says the next press goes back to your view")
	face.follow({"edge": POWER_DOOR})
	await _settle()
	var door := face.target_world({"edge": POWER_DOOR})
	_check(bool(door.get("inside", false)),
			"shown a passage: its mark is put in the window")
	var back := shell.kit.targets("map").get("back_view") as Node3D
	var at := shell.screen_of_node(back) if back != null else Vector2.ZERO
	_check(back != null and str(shell.pick_at(at).get("target", "")) == "back_view",
			"BACK TO YOUR VIEW is on the glass, under the pointer where it is drawn")
	await _click(at)
	await _settle()
	_check(_view_state() == mine and not face.can_return(),
			"one click and it is your view again -- the view you had before the "
			+ "first entry, however many were shown after it: %s" % [mine])
	face.follow({"room": "c005"})
	await _settle()
	await _key(KEY_ESCAPE)
	await _settle()
	_check(shell.is_open() and _view_state() == mine,
			"and Escape, when that is what it says, does the same")
	# A link into the unknown lands on nothing.
	var before := _view_state()
	face.follow({"room": "c999"})
	face.follow({"edge": "e:c998:c999"})
	await _settle()
	_check(_view_state() == before and not face.can_return()
			and face.target_local({"room": "c999"}) == Vector3.INF,
			"a link to a place the map does not know shows nothing and moves "
			+ "nothing")
	shell.close()
	face.overview()


## §8: "Ordinary travel preserves the map view."
func _travel_keeps_the_view() -> void:
	print("  -- ordinary travel keeps the view")
	_use_map("all_rooms")
	await _stand_in("c002")
	await _open()
	await _key(KEY_BRACKETRIGHT)
	await _key(KEY_RIGHT)
	await _key(KEY_EQUAL)
	await _settle()
	var kept := _view_state()
	var builds := face.builds
	shell.close()
	await _stand_in("c003")
	await _open()
	_check(face.builds > builds and _view_state() == kept,
			"walking into another room rebuilds the map (you are elsewhere) and "
			+ "keeps the lens where you left it: %s" % [kept])
	var you: Vector3 = face._you.get_meta("at", Vector3.INF) if face._you != null \
			else Vector3.INF
	_check(you.distance_to(zone.player.global_position) < 0.01,
			"and YOU stands where you are now, live")
	shell.close()
	face.overview()


func _the_glass_tags() -> void:
	print("  -- the glass's tags")
	await _open()
	_use_map("all_rooms")
	await _frames(2)
	face.overview()
	await _settle()
	var over := int(face.state()["tag_clashes"])
	await _key(KEY_BRACKETRIGHT)
	await _settle()
	var picked := int(face.state()["tag_clashes"])
	await _key(KEY_ENTER)
	await _settle()
	var expanded := int(face.state()["tag_clashes"])
	_check(over == 0 and picked == 0 and expanded == 0 and face.expanded,
			"no tag covers another, the room picked, or leaves the window: "
			+ "overview %d, picked %d, detail %d" % [over, picked, expanded])
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _settle()
	_check(not face.expanded and face.selected == "" and shell.is_open(),
			"Escape closes the detail, then the pick, before the menu")
	shell.close()


func _the_hub() -> void:
	print("  -- the Hub")
	face.bind(null)
	await _open()
	await _frames(2)
	_check(face.hub_note().visible and face.world_root().get_child_count() == 0,
			"in the Hub the wall says there is no map here, and draws nothing")
	_check(face.prompts().is_empty() and shell.back_words() == "close",
			"and offers nothing to do but go back")
	shell.close()
	face.bind(zone)


# ---------------------------------------------------------------------------
# Screenshots (`make map-face-shots`, under the game's renderer)
# ---------------------------------------------------------------------------

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for shot: Array in [["all_rooms", "c009", "every_floor_from_c009", ""],
			["all_rooms", "c001", "your_floor_dimmed_rest_from_c001", "floor"],
			["all_rooms", "c001", "your_floor_alone_from_c001", "alone"],
			["carried", "c005", "power_door_blocked_from_c005", "c005"],
			["powered", "c005", "power_door_open_from_c005", "c005"]]:
		_use_map(str(shot[0]))
		await _stand_in(str(shot[1]))
		face.bind(zone)
		face.overview()
		await _open()
		face.refresh()
		if str(shot[3]) == "floor":
			face.step_floor(1)
		elif str(shot[3]) == "alone":
			face.step_floor(1)
			face.step_floor(1)
		elif str(shot[3]) != "":
			face.pick(str(shot[3]))
			face.toggle_detail()
		await _settle()
		await _frames(6)
		var image := get_viewport().get_texture().get_image()
		var path := dir.path_join("map_%s.png" % str(shot[2]))
		image.save_png(path)
		_save_words(path)
		_check(image.get_width() > 64, "saved %s" % path.get_file())
		shell.close()
		await _frames(2)


## What the words on the front wall are, and where, beside the render:
## what `tools/menu_contrast.py` measures the render's contrast from.
func _save_words(png: String) -> void:
	var out := FileAccess.open(png.get_basename() + ".words.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(shell.words_on_screen()))
	out.close()
