class_name MapFace
extends Control
## H-3D-MAP (CP4, V-21): THE MAP WALL -- the Zone as a miniature you can
## turn, tilt, zoom and pan (`04` §6-§7).
##
## **One projection, two views.** It asks `MinimapModel` exactly what the
## minimap asks, of the same two sources: shape from the built level
## (`ZoneController.room_bounds`, `room_places`, `room_joins`,
## `plug_positions`), state from the bridge's map (`BridgeClient.zone_map()`).
## The two maps cannot disagree about a room, a name or a gate, because
## neither of them decides one.
##
## **Render-only.** The miniature is meshes and labels in its own
## `World3D`: no scripts, no collision, no areas, no sounds, no timers,
## and nothing copied out of the Zone. Building it sends nothing, runs no
## room's `_ready` and simulates no machine (§7).
##
## **Cutaway, and one floor at a time.** A room is its floor and a low
## wall, never a roof, so a room under another is seen into, not over.
## The floor you stand on is solid and the others are ghosts; PgUp and
## PgDn show one floor alone.
##
## **Its controls leave the page turns alone.** Q, E, the pad's shoulders
## and the arrows at the wall's edges are the shell's and never reach this
## face. The map takes:
## - a drag, the arrow keys or the right stick: turn and tilt;
## - the wheel, + and -, or the triggers: zoom;
## - a right-drag, WASD or the left stick: pan;
## - C or Home, or the pad's Y: back to you;
## - PgUp and PgDn, or the d-pad's up and down: one floor, or all;
## - [ and ], or the d-pad's left and right: the next place you know, and
##   what is known about it, on the right.
##
## **What you were looking at stays put** through page turns and a close:
## the view, the floor and the place picked are this face's, and only
## another Zone resets them.
##
## PROVISIONAL ART: plain shapes and Godot's default font, until Glyph's
## kit (H-GLYPH-KIT) and Arty's circuit family (H-CIRCUITS).

const ORIGIN := Vector2(40, 92)
const AREA := Vector2(1200, 612)
const VIEW_SIZE := Vector2i(800, 612)
## The shell's page-turn arrows stand over the stage's edges, so the side
## column stops short of the page's right margin: nothing is read under
## an arrow (seen in the first renders).
const SIDE_WIDTH := 330.0
## How high a room's cutaway wall stands above its floor.
const WALL_HEIGHT := 2.4
const BEAM_WIDTH := 1.1
const BEAM_HEIGHT := 0.3
const YAW_STEP := 15.0
const PITCH_STEP := 7.5
const PAN_STEP := 0.15
const ZOOM_STEP := 1.25
const MIN_DISTANCE := 12.0
const MAX_DISTANCE := 260.0
const MIN_PITCH := 20.0
const MAX_PITCH := 85.0
const PULSE_HZ := 1.2
const STICK_DEADZONE := 0.25
## A blocker's indicator, and how far its pulse swings.
const BLOCKER_RADIUS := 1.8
const PULSE_SWING := 0.3

## The Zone this map is of, or `null` (the Hub has no map).
var zone: ZoneController = null
## THE VIEW, kept through page turns and closes.
var yaw := 30.0
var pitch := 55.0
var distance := 80.0
var target := Vector3.ZERO
## -1 shows every floor; otherwise the index of the one floor shown.
var floor_filter := -1
## The place picked for inspection (a room id), or "".
var selected := ""
## THIS ZONE'S CIRCUIT COLOURS, the minimap's (`MinimapModel.circuit_colours`).
var colours := {}
## The last build's cost in microseconds, and how many builds there have
## been: the cache is measured, not assumed.
var build_usec := 0
var builds := 0

var _rooms: Array = []
var _connectors: Array = []
## Standing height of each floor, lowest first, and which floor each
## room found is on -- decided once, where the floors are, so a room near
## a floor's edge cannot be put on one floor and shown on another.
var _floors: Array = []
var _room_band := {}
var _signature := 0
var _dirty := true
var _stick := {}

var _view: SubViewport
var _view_input: Control
var _world_root: Node3D
var _camera: Camera3D
var _room_nodes := {}
var _room_labels := {}
var _connector_nodes := {}
var _blocker_nodes := {}
var _plug_nodes := {}
var _player_mark: MeshInstance3D

var _here_label: Label
var _floor_label: Label
var _detail: Label
var _places: VBoxContainer
var _ways_back: Label
var _hub_note: Label


func _ready() -> void:
	name = "MapFace"
	position = ORIGIN
	size = AREA
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_view()
	_build_side()
	BridgeClient.snapshot_received.connect(_on_snapshot)


# ------------------------------------------------------------------ API

## Follow a Zone, or nothing (`null`, in the Hub). Another Zone resets
## the view; the same Zone keeps it.
func bind(controller: ZoneController) -> void:
	var same := controller != null and zone != null \
			and is_instance_valid(zone) and controller == zone
	zone = controller
	if zone != null and not zone.chamber_entered.is_connected(_on_entered):
		zone.chamber_entered.connect(_on_entered)
	if not same:
		floor_filter = -1
		selected = ""
		_signature = 0
		recentre()
	# Built -- or, with no Zone, cleared -- when it is first shown
	# (`refresh`, from `_process`), not on every Zone load. One place
	# clears the miniature, so no second copy can mask a broken first.
	_dirty = true
	_update_side()


## Rebuild the miniature if what it shows has changed; otherwise nothing.
func refresh() -> void:
	_dirty = false
	if zone == null or not is_instance_valid(zone):
		_rooms = []
		_connectors = []
		_floors = []
		_clear_world()
		_signature = 0
		_update_side()
		return
	var zone_map := BridgeClient.zone_map()
	if str(zone_map.get("zone_id", "")) != zone.zone_id:
		zone_map = {"rooms": [], "connectors": []}
	var floors := {}
	for rid: Variant in zone.room_places:
		floors[rid] = ((zone.room_places[rid] as Dictionary).get("arrival",
				Vector3.ZERO) as Vector3).y
	var rooms := MinimapModel.rooms(zone_map, zone.room_bounds,
			zone.rooms_entered(), zone.current_room(), floors)
	var connectors := MinimapModel.connectors(zone_map, zone.room_joins,
			zone.plug_positions)
	var signature := hash(str([zone.zone_id, rooms, connectors]))
	if signature == _signature:
		return
	_signature = signature
	_rooms = rooms
	_connectors = connectors
	colours = MinimapModel.circuit_colours(zone.zone)
	var started := Time.get_ticks_usec()
	_build_world()
	build_usec = Time.get_ticks_usec() - started
	builds += 1
	_update_side()


## Back to the player: the view centres on you, nothing is picked.
func recentre() -> void:
	selected = ""
	if zone != null and is_instance_valid(zone) and zone.player != null:
		target = zone.player.global_position
	_place_camera()
	_update_side()


func rooms_shown() -> Array:
	return _rooms


func connectors_shown() -> Array:
	return _connectors


## The standing heights of the floors this map knows, lowest first.
func floors() -> Array:
	return _floors


## Which floor the player stands on (an index into `floors()`), or -1:
## the floor of the room they are in, or failing that of their height.
func player_floor() -> int:
	for row: Dictionary in _rooms:
		if bool(row.get("here", false)):
			return band_of_room(str(row["id"]))
	return _band_of(_player_floor_y())


## The blockers the miniature shows: `{edge_id, state, symbol, colour,
## at (Vector3)}`, one per blocked or unknown connector drawn.
func blockers_shown() -> Array:
	var out: Array = []
	for eid: String in _blocker_nodes:
		var node: MeshInstance3D = _blocker_nodes[eid]
		out.append({"edge_id": eid, "state": node.get_meta("state"),
				"symbol": node.get_meta("symbol"),
				"colour": node.get_meta("colour"),
				"at": node.get_meta("at"), "visible": node.visible})
	return out


## The 3D points a connector was built along (the built chain's).
func connector_points(edge_id: String) -> Array:
	var node: Variant = _connector_nodes.get(edge_id)
	if node == null:
		return []
	return (node as Node).get_meta("points", [])


## The miniature's root, for the suite to take a census of.
func world_root() -> Node3D:
	return _world_root


func camera() -> Camera3D:
	return _camera


func room_node(id: String) -> MeshInstance3D:
	return _room_nodes.get(id)


func plug_node(edge_id: String) -> MeshInstance3D:
	return _plug_nodes.get(edge_id)


func blocker_node(edge_id: String) -> MeshInstance3D:
	return _blocker_nodes.get(edge_id)


## An edge id as a node name: Godot does not allow ':' in one, so the
## id itself travels as the node's `edge_id` meta.
static func _node_name(edge_id: String) -> String:
	return edge_id.replace(":", "_")


func detail_text() -> String:
	return _detail.text


func place_buttons() -> Array:
	return _places.get_children()


## One floor up (+1) or down (-1). From every floor, the first step shows
## yours; stepping past the top or the bottom shows every floor again.
func step_floor(step: int) -> void:
	if _floors.is_empty():
		floor_filter = -1
	elif floor_filter == -1:
		floor_filter = maxi(player_floor(), 0)
	else:
		floor_filter += step
		if floor_filter < 0 or floor_filter >= _floors.size():
			floor_filter = -1
	_apply_visibility()
	_update_side()


## The next (+1) or previous (-1) place you know, picked for inspection.
func step_place(step: int) -> void:
	var ids: Array = _known_ids()
	if ids.is_empty():
		return
	var at := ids.find(selected)
	if at == -1:
		at = 0 if step > 0 else ids.size() - 1
	else:
		at = posmod(at + step, ids.size())
	pick(str(ids[at]))


## Inspect a known place: the view centres on it and the right says what
## is known about it.
func pick(room_id: String) -> void:
	for row: Dictionary in _rooms:
		if str(row["id"]) == room_id:
			selected = room_id
			var rect: Rect2 = row["rect"]
			var centre := rect.get_center()
			target = Vector3(centre.x, float(row["floor_y"]), centre.y)
			_place_camera()
			_apply_visibility()
			_update_side()
			return


func turn_view(yaw_step: float, pitch_step: float) -> void:
	yaw = fposmod(yaw + yaw_step, 360.0)
	pitch = clampf(pitch + pitch_step, MIN_PITCH, MAX_PITCH)
	_place_camera()


func zoom_view(factor: float) -> void:
	distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	_place_camera()


## Pan in the ground plane, as seen from the camera: +x right, +y ahead.
func pan_view(right: float, ahead: float) -> void:
	var y := deg_to_rad(yaw)
	var forward := -Vector3(sin(y), 0.0, cos(y))
	var side := Vector3(cos(y), 0.0, -sin(y))
	target += (side * right + forward * ahead) * distance * PAN_STEP
	_place_camera()


# --------------------------------------------------------------- input

## The map's own keys and buttons. Everything the shell uses (Q, E, Tab,
## Escape, the shoulders, Start, Back) is taken before it gets here.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or zone == null:
		return
	var used := false
	if event is InputEventKey and event.pressed:
		used = _on_key((event as InputEventKey).keycode)
	elif event is InputEventJoypadButton and event.pressed:
		used = _on_pad_button((event as InputEventJoypadButton).button_index)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		_stick[motion.axis] = motion.axis_value
		used = true
	if used:
		get_viewport().set_input_as_handled()


func _on_key(key: Key) -> bool:
	match key:
		KEY_LEFT:
			turn_view(-YAW_STEP, 0.0)
		KEY_RIGHT:
			turn_view(YAW_STEP, 0.0)
		KEY_UP:
			turn_view(0.0, PITCH_STEP)
		KEY_DOWN:
			turn_view(0.0, -PITCH_STEP)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_view(1.0 / ZOOM_STEP)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_view(ZOOM_STEP)
		KEY_W:
			pan_view(0.0, 1.0)
		KEY_S:
			pan_view(0.0, -1.0)
		KEY_A:
			pan_view(-1.0, 0.0)
		KEY_D:
			pan_view(1.0, 0.0)
		KEY_C, KEY_HOME:
			recentre()
		KEY_PAGEUP:
			step_floor(1)
		KEY_PAGEDOWN:
			step_floor(-1)
		KEY_BRACKETRIGHT:
			step_place(1)
		KEY_BRACKETLEFT:
			step_place(-1)
		_:
			return false
	return true


func _on_pad_button(button: JoyButton) -> bool:
	match button:
		JOY_BUTTON_Y:
			recentre()
		JOY_BUTTON_DPAD_UP:
			step_floor(1)
		JOY_BUTTON_DPAD_DOWN:
			step_floor(-1)
		JOY_BUTTON_DPAD_RIGHT:
			step_place(1)
		JOY_BUTTON_DPAD_LEFT:
			step_place(-1)
		_:
			return false
	return true


## The pointer over the miniature: drag turns and tilts, a right-drag
## pans, the wheel zooms.
func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_view(1.0 / ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_view(ZOOM_STEP)
		_view_input.accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			turn_view(motion.relative.x * 0.4, motion.relative.y * 0.3)
			_view_input.accept_event()
		elif motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			pan_view(-motion.relative.x * 0.01, motion.relative.y * 0.01)
			_view_input.accept_event()


func _process(delta: float) -> void:
	var page := get_viewport() as SubViewport
	if page != null and _view != null:
		_view.render_target_update_mode = page.render_target_update_mode
	var showing := page == null \
			or page.render_target_update_mode != SubViewport.UPDATE_DISABLED
	if not showing:
		_stick.clear()
		return
	if _dirty:
		refresh()
	# A stick held as the page turned away sends its release to another
	# page; what this face last heard must not keep turning the map.
	if _is_front():
		_apply_sticks(delta)
	else:
		_stick.clear()
	_pulse()
	_place_player()


func _apply_sticks(delta: float) -> void:
	var rx := _axis(JOY_AXIS_RIGHT_X)
	var ry := _axis(JOY_AXIS_RIGHT_Y)
	var lx := _axis(JOY_AXIS_LEFT_X)
	var ly := _axis(JOY_AXIS_LEFT_Y)
	var zoom := _axis(JOY_AXIS_TRIGGER_LEFT) - _axis(JOY_AXIS_TRIGGER_RIGHT)
	if rx != 0.0 or ry != 0.0:
		turn_view(rx * 120.0 * delta, -ry * 60.0 * delta)
	if lx != 0.0 or ly != 0.0:
		pan_view(lx * 4.0 * delta, -ly * 4.0 * delta)
	if zoom != 0.0:
		zoom_view(pow(ZOOM_STEP, zoom * 4.0 * delta))


## Whether the map is the page facing the camera. Mounted outside a
## shell (a test), it always is.
func _is_front() -> bool:
	var node: Node = get_parent()
	while node != null and not (node is MenuShell):
		node = node.get_parent()
	return node == null or (node as MenuShell).front() == "map"


func _axis(axis: int) -> float:
	var value := float(_stick.get(axis, 0.0))
	return value if absf(value) >= STICK_DEADZONE else 0.0


func _on_snapshot(_snapshot: Dictionary) -> void:
	_dirty = true


func _on_entered(_index: int) -> void:
	_dirty = true


# ------------------------------------------------------------ building

func _build_view() -> void:
	var holder := SubViewportContainer.new()
	holder.name = "View"
	holder.stretch = true
	holder.size = Vector2(VIEW_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_view = SubViewport.new()
	_view.name = "Miniature"
	_view.size = VIEW_SIZE
	_view.own_world_3d = true
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	holder.add_child(_view)
	var env := WorldEnvironment.new()
	env.name = "Environment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.08)
	env.environment = environment
	_view.add_child(env)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 50.0
	_camera.far = 2000.0
	_view.add_child(_camera)
	_world_root = Node3D.new()
	_world_root.name = "Zone"
	_view.add_child(_world_root)
	# The pointer: a plain Control over the view, so a drag or the wheel
	# reaches the map and nothing else.
	_view_input = Control.new()
	_view_input.name = "ViewInput"
	_view_input.size = Vector2(VIEW_SIZE)
	_view_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_view_input.gui_input.connect(_on_view_input)
	add_child(_view_input)
	_hub_note = Label.new()
	_hub_note.name = "HubNote"
	_hub_note.text = "The Hub has no map. Every Zone has one."
	_hub_note.position = Vector2(24, 24)
	_hub_note.add_theme_font_size_override("font_size", 22)
	add_child(_hub_note)
	_place_camera()


func _build_side() -> void:
	var side := VBoxContainer.new()
	side.name = "Side"
	side.position = Vector2(VIEW_SIZE.x + 28, 0)
	side.size = Vector2(SIDE_WIDTH, AREA.y)
	side.add_theme_constant_override("separation", 8)
	add_child(side)
	_here_label = _side_label(side, "Here", 20)
	_floor_label = _side_label(side, "Floors", 16)
	# The picked place's detail scrolls in a fixed height, so a room with
	# many ways on cannot push the column off the page.
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.custom_minimum_size = Vector2(SIDE_WIDTH, 150)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(detail_scroll)
	_detail = _side_label(detail_scroll, "Detail", 16)
	var heading := _side_label(side, "PlacesHeading", 16)
	heading.text = "PLACES YOU KNOW"
	var scroll := ScrollContainer.new()
	scroll.name = "PlacesScroll"
	scroll.custom_minimum_size = Vector2(SIDE_WIDTH, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	side.add_child(scroll)
	_places = VBoxContainer.new()
	_places.name = "Places"
	_places.custom_minimum_size = Vector2(SIDE_WIDTH - 16, 0)
	scroll.add_child(_places)
	_ways_back = _side_label(side, "WaysBack", 15)
	var legend := _side_label(side, "Legend", 13)
	legend.modulate = Color(0.75, 0.78, 0.8)
	legend.text = ("Drag or arrows: turn and tilt. Wheel or + -: zoom. "
			+ "Right-drag or WASD: pan. C: back to you. PgUp PgDn: one "
			+ "floor. [ ]: next place. Pad: right stick turns, left stick "
			+ "pans, triggers zoom, Y back to you, d-pad floors and places.")


## Every label in the column wraps at the column's width. One that does
## not asks the column to be as wide as its longest line, and the column
## then grows under the shell's arrow (the first renders).
func _side_label(parent: Control, node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	parent.add_child(label)
	return label


func _clear_world() -> void:
	for child: Node in _world_root.get_children():
		_world_root.remove_child(child)
		child.queue_free()
	_room_nodes.clear()
	_room_labels.clear()
	_connector_nodes.clear()
	_blocker_nodes.clear()
	_plug_nodes.clear()
	_player_mark = null


func _build_world() -> void:
	_clear_world()
	_floors = _floor_bands()
	for row: Dictionary in _rooms:
		var id := str(row["id"])
		var room := MeshInstance3D.new()
		room.name = "Room_%s" % id
		room.mesh = _room_mesh(row["rect"], float(row["floor_y"]))
		room.set_meta("floor_y", float(row["floor_y"]))
		room.set_meta("here", bool(row["here"]))
		_world_root.add_child(room)
		_room_nodes[id] = room
		var label := Label3D.new()
		label.name = "Name_%s" % id
		label.text = str(row["name"])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.font_size = 26
		label.no_depth_test = true
		var rect: Rect2 = row["rect"]
		# Above the walls and clear of the player's marker, which stands
		# in the same room.
		label.position = Vector3(rect.get_center().x,
				float(row["floor_y"]) + WALL_HEIGHT + 4.0, rect.get_center().y)
		_world_root.add_child(label)
		_room_labels[id] = label
	for row: Dictionary in _connectors:
		var eid := str(row["edge_id"])
		var points := _points3(row)
		var state := str(row["state"])
		var circuits: Array = row["circuits"]
		var tint: Color = Color(0.78, 0.82, 0.86) if state == "open" \
				else colours.get(str(circuits[0]) if not circuits.is_empty()
					else "", Color(0.85, 0.85, 0.85))
		if points.size() >= 2:
			var beam := MeshInstance3D.new()
			beam.name = "Connector_%s" % _node_name(eid)
			beam.set_meta("edge_id", eid)
			beam.mesh = _beam_mesh(points)
			beam.material_override = _flat(tint, 1.0)
			beam.set_meta("points", points)
			beam.set_meta("rooms", [str(row["room_a"]), str(row["room_b"])])
			_world_root.add_child(beam)
			_connector_nodes[eid] = beam
		var mark := _mark3(row, points)
		if mark == Vector3.INF:
			continue
		if state != "open":
			_add_blocker(eid, row, mark, tint)
		elif points.size() < 2:
			var ring := MeshInstance3D.new()
			ring.name = "WayBack_%s" % _node_name(eid)
			ring.set_meta("edge_id", eid)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.7
			torus.outer_radius = 1.2
			ring.mesh = torus
			ring.material_override = _flat(Color(0.85, 0.92, 1.0), 1.0)
			ring.position = mark + Vector3(0, 0.3, 0)
			ring.set_meta("rooms", [str(row["room_a"])])
			_world_root.add_child(ring)
			_plug_nodes[eid] = ring
	_player_mark = MeshInstance3D.new()
	_player_mark.name = "You"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.6
	cone.height = 3.8
	_player_mark.mesh = cone
	# Drawn over everything: where you are is never behind a wall.
	var you := _flat(Color(1.0, 0.85, 0.1), 1.0)
	you.no_depth_test = true
	you.render_priority = 10
	_player_mark.material_override = you
	_world_root.add_child(_player_mark)
	_place_player()
	_apply_visibility()


func _add_blocker(eid: String, row: Dictionary, at: Vector3,
		tint: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = "Blocker_%s" % _node_name(eid)
	node.set_meta("edge_id", eid)
	var sphere := SphereMesh.new()
	sphere.radius = BLOCKER_RADIUS
	sphere.height = BLOCKER_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	node.mesh = sphere
	node.material_override = _flat(tint, 1.0)
	node.position = at + Vector3(0, BLOCKER_RADIUS, 0)
	var state := str(row["state"])
	var letter := "?" if state == "unknown" else str(row["symbol"])
	node.set_meta("state", state)
	node.set_meta("symbol", letter)
	node.set_meta("colour", tint)
	node.set_meta("at", at)
	node.set_meta("rooms", [str(row["room_a"]), str(row["room_b"])])
	var label := Label3D.new()
	label.name = "Reason"
	label.text = letter
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 30
	label.no_depth_test = true
	label.position = Vector3(0, BLOCKER_RADIUS * 1.8, 0)
	node.add_child(label)
	_world_root.add_child(node)
	_blocker_nodes[eid] = node


## A connector's path in 3D: the minimap's XZ points with their heights.
func _points3(row: Dictionary) -> Array:
	var path: PackedVector2Array = row["path"]
	var ys: PackedFloat32Array = row["ys"]
	var out: Array = []
	for i in path.size():
		var y := ys[i] if i < ys.size() else 0.0
		out.append(Vector3(path[i].x, y, path[i].y))
	return out


## Where a connector's mark stands in 3D: halfway along its path by
## length, or where its device is.
func _mark3(row: Dictionary, points: Array) -> Vector3:
	if points.size() >= 2:
		var total := 0.0
		for i in range(1, points.size()):
			total += (points[i - 1] as Vector3).distance_to(points[i])
		var half := total * 0.5
		var walked := 0.0
		for i in range(1, points.size()):
			var a: Vector3 = points[i - 1]
			var b: Vector3 = points[i]
			var step := a.distance_to(b)
			if walked + step >= half and step > 0.0:
				return a.lerp(b, (half - walked) / step)
			walked += step
		return points[points.size() - 1]
	var at: Vector2 = row["mark_at"]
	if at == Vector2.INF:
		return Vector3.INF
	var ys: PackedFloat32Array = row["ys"]
	return Vector3(at.x, ys[0] if not ys.is_empty() else 0.0, at.y)


## A room without a roof: its floor, and four walls WALL_HEIGHT high.
func _room_mesh(rect: Rect2, floor_y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var y0 := floor_y
	var y1 := floor_y + WALL_HEIGHT
	_quad(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1),
			Vector3(x0, y0, z1))
	_quad(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0),
			Vector3(x0, y1, z0))
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1),
			Vector3(x0, y1, z1))
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1),
			Vector3(x0, y1, z0))
	_quad(st, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1),
			Vector3(x1, y1, z0))
	var mesh := st.commit()
	# The rim: the floor's outline and the walls' top edge, as lines, so a
	# ghosted room is still a readable shape.
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_LINES)
	for y: float in [y0 + 0.02, y1]:
		var corners := [Vector3(x0, y, z0), Vector3(x1, y, z0),
				Vector3(x1, y, z1), Vector3(x0, y, z1)]
		for i in 4:
			rim.add_vertex(corners[i])
			rim.add_vertex(corners[(i + 1) % 4])
	return rim.commit(mesh)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(v)


## A connector as a beam along its built path: one box per step.
func _beam_mesh(points: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var along := b - a
		if along.length() < 0.01:
			continue
		var flat := Vector3(along.x, 0.0, along.z)
		var side := Vector3(-flat.z, 0.0, flat.x).normalized() \
				if flat.length() > 0.01 else Vector3.RIGHT
		var w := side * BEAM_WIDTH * 0.5
		var h := Vector3(0, BEAM_HEIGHT, 0)
		var lift := Vector3(0, 0.05, 0)
		var corners := [a - w + lift, a + w + lift, b + w + lift,
				b - w + lift]
		_quad(st, corners[0] + h, corners[1] + h, corners[2] + h,
				corners[3] + h)
		_quad(st, corners[0], corners[1], corners[1] + h, corners[0] + h)
		_quad(st, corners[1], corners[2], corners[2] + h, corners[1] + h)
		_quad(st, corners[2], corners[3], corners[3] + h, corners[2] + h)
		_quad(st, corners[3], corners[0], corners[0] + h, corners[3] + h)
	return st.commit()


func _flat(colour: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# ---------------------------------------------------------- the floors

## The floors of the rooms found, lowest first: a room whose standing
## height is within `MinimapModel.FLOOR_STEP` of a floor's is on it.
func _floor_bands() -> Array:
	var rows := _rooms.duplicate()
	rows.sort_custom(_lower_floor)
	var out: Array = []
	_room_band.clear()
	for row: Dictionary in rows:
		var y := float(row["floor_y"])
		if out.is_empty() or y - float(out[out.size() - 1]) \
				>= MinimapModel.FLOOR_STEP:
			out.append(y)
		_room_band[str(row["id"])] = out.size() - 1
	return out


static func _lower_floor(a: Dictionary, b: Dictionary) -> bool:
	return float(a["floor_y"]) < float(b["floor_y"])


## The floor a room found is on.
func band_of_room(room_id: String) -> int:
	return int(_room_band.get(room_id, -1))


## The floor a height is on: the highest whose floor it stands at or
## above (a body a little below its floor still counts).
func _band_of(y: float) -> int:
	var at := -1
	for i in _floors.size():
		if y >= float(_floors[i]) - 0.5:
			at = i
	return at


func _player_floor_y() -> float:
	for row: Dictionary in _rooms:
		if bool(row.get("here", false)):
			return float(row.get("floor_y", 0.0))
	if zone != null and is_instance_valid(zone) and zone.player != null:
		return zone.player.global_position.y
	return 0.0


## Every floor: yours solid, the others ghosts. One floor: only it.
func _apply_visibility() -> void:
	var mine := player_floor()
	var shown := {}
	for row: Dictionary in _rooms:
		var id := str(row["id"])
		var band := band_of_room(id)
		var visible := floor_filter == -1 or band == floor_filter
		shown[id] = visible
		var node: MeshInstance3D = _room_nodes.get(id)
		if node == null:
			continue
		node.visible = visible
		var solid := band == (mine if floor_filter == -1 else floor_filter)
		var here := bool(row["here"])
		var tint := Color(0.62, 0.70, 0.80) if here or id == selected \
				else Color(0.55, 0.62, 0.70)
		node.material_override = _flat(tint, 0.55 if solid else 0.12)
		node.set_meta("solid", solid)
		var label: Label3D = _room_labels.get(id)
		if label != null:
			label.visible = visible and (here or id == selected)
	for group: Dictionary in [_connector_nodes, _blocker_nodes, _plug_nodes]:
		for eid: String in group:
			var node: Node3D = group[eid]
			var rooms: Array = node.get_meta("rooms", [])
			var any := false
			for rid: Variant in rooms:
				any = any or bool(shown.get(str(rid), false))
			node.visible = floor_filter == -1 or any


func _pulse() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var s := 1.0 + PULSE_SWING * sin(t * TAU * PULSE_HZ)
	for eid: String in _blocker_nodes:
		(_blocker_nodes[eid] as Node3D).scale = Vector3.ONE * s


func _place_player() -> void:
	if _player_mark == null or zone == null or not is_instance_valid(zone) \
			or zone.player == null:
		return
	var at := zone.player.global_position
	var ahead := -zone.player.global_transform.basis.z
	var facing := Vector3(ahead.x, 0.0, ahead.z)
	if facing.length() < 0.01:
		facing = Vector3(0, 0, -1)
	# The cone's tip is +y; lay it down along the facing.
	var basis := Basis.looking_at(facing.normalized(), Vector3.UP)
	basis = basis * Basis(Vector3.RIGHT, -PI * 0.5)
	_player_mark.transform = Transform3D(basis, at + Vector3(0, 1.4, 0))


func _place_camera() -> void:
	if _camera == null:
		return
	var p := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	var offset := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
	var at := target + offset
	_camera.transform = Transform3D(Basis.looking_at(target - at,
			Vector3.UP), at)


# ------------------------------------------------------------ the side

func _known_ids() -> Array:
	var out: Array = []
	for row: Dictionary in _rooms:
		out.append(str(row["id"]))
	out.sort()
	return out


func _name_of(room_id: String) -> String:
	for row: Dictionary in _rooms:
		if str(row["id"]) == room_id:
			return str(row["name"])
	return ""


func _update_side() -> void:
	if _here_label == null:
		return
	var has_zone := zone != null and is_instance_valid(zone)
	_hub_note.visible = not has_zone
	if not has_zone:
		_here_label.text = ""
		_floor_label.text = ""
		_detail.text = ""
		_ways_back.text = ""
		for child: Node in _places.get_children():
			_places.remove_child(child)
			child.queue_free()
		return
	var here := MinimapModel.here_name(_rooms)
	_here_label.text = "You are in %s" % here if here != "" else ""
	var mine := player_floor()
	if _floors.size() <= 1:
		_floor_label.text = "One floor"
	elif floor_filter == -1:
		_floor_label.text = ("Every floor (%d). Yours is solid; "
				% _floors.size() + "the others are ghosts.")
	else:
		_floor_label.text = "Floor %d of %d: %s" % [floor_filter + 1,
				_floors.size(), _floor_words(floor_filter - mine).to_lower()]
	_detail.text = _describe(selected) if selected != "" \
			else "Pick a place ([ ] or a click) for its ways on."
	_rebuild_places()
	# A count, not a list: each place's own detail names its way back, and
	# a list would grow with the Zone.
	var backs := _plug_nodes.size()
	_ways_back.text = ("Ways back: %d, each a ring where it stands." % backs) \
			if backs > 0 else ""


## What is known about a place: its name, its floor, and each way on with
## its state and the bridge's reason. Nothing the bridge withholds.
func _describe(room_id: String) -> String:
	var lines: Array = []
	for row: Dictionary in _rooms:
		if str(row["id"]) != room_id:
			continue
		lines.append(str(row["name"]).to_upper())
		lines.append(_floor_words(band_of_room(room_id) - player_floor()))
	for row: Dictionary in _connectors:
		var a := str(row["room_a"])
		var b := str(row["room_b"])
		if a != room_id and b != room_id:
			continue
		var other := b if a == room_id else a
		var other_name := _name_of(other)
		var where := ("to " + other_name) if other_name != "" \
				else "a way on, not yet walked"
		if _plug_nodes.has(str(row["edge_id"])):
			where = "a way back"
		var state := str(row["state"])
		var reason := str(row["reason"])
		var said := state if reason == "" else "%s: %s" % [state, reason]
		lines.append("- %s: %s" % [where, said])
	return "\n".join(lines)


## A floor relative to yours, in words. ASCII only: every character here
## must be in the font it is drawn in (H-MINIMAP's MM-F3).
static func _floor_words(rel: int) -> String:
	if rel == 0:
		return "Your floor"
	var n := absi(rel)
	return "%d floor%s %s" % [n, "" if n == 1 else "s",
			"up" if rel > 0 else "down"]


func _rebuild_places() -> void:
	var ids := _known_ids()
	var have: Array = []
	for child: Node in _places.get_children():
		have.append(str(child.get_meta("room_id", "")))
	if have == ids:
		for child: Node in _places.get_children():
			(child as Button).text = _name_of(str(child.get_meta("room_id")))
		return
	for child: Node in _places.get_children():
		_places.remove_child(child)
		child.queue_free()
	for id: String in ids:
		var button := Button.new()
		button.name = "Place_%s" % id
		button.text = _name_of(id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.set_meta("room_id", id)
		# The keys and the pad pick places with [ ] and the d-pad; the
		# arrows turn the map. A focus ring here would be a second cursor.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(pick.bind(id))
		_places.add_child(button)
