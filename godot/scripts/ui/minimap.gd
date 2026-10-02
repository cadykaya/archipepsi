class_name Minimap
extends Control
## H-MINIMAP (CP4, V-20): THE MAP THAT STAYS ON SCREEN (`04` §7).
##
## North-up and centred on the player: where you are, which way you face,
## the rooms you have found as their real shapes, the connectors near you
## as they actually run, and every known blocker in its circuit's colour
## with a symbol for its reason. The room you are in is named above it;
## everything longer waits for the 3D map.
##
## **It shows, it never decides.** Shapes are the built level's
## (`ZoneController.room_bounds`, `room_joins`); discovery, names, gate
## states, reasons and circuits are the bridge's map
## (`BridgeClient.zone_map()`). `MinimapModel` joins the two and is where
## the rules are tested.
##
## **The floor convention.** Rooms on the player's floor are filled.
## Rooms a storey above or below are outlined only, marked with a small
## triangle pointing up or down (drawn, not typed), and their connectors
## are drawn thinner.
##
## **A return plug** -- a device, not a corridor -- is a ring where it
## stands, once the bridge lists it.
##
## PROVISIONAL ART: plain shapes and Godot's default font, until Glyph's
## kit (H-GLYPH-KIT) and Arty's circuit family (H-CIRCUITS).

const SIZE := Vector2(236, 236)
## Metres of level per pixel of map: 236 px shows about 74 m across.
const PX_PER_M := 3.2
const MARGIN := 18.0

var zone: ZoneController = null
var _rooms: Array = []
var _connectors: Array = []
## This Zone's circuit colours (`MinimapModel.circuit_colours`).
var colours: Dictionary = {}
var _name_label: Label
var _map: _Plate
## What the last draw put on the plate, for the suite: every string it
## typed, and how many floor marks and plug rings it drew.
var draw_log := {"text": [], "floor_marks": 0, "plug_marks": 0}


func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -SIZE.x - MARGIN
	offset_right = -MARGIN
	offset_top = -SIZE.y - MARGIN - 26.0
	offset_bottom = -MARGIN
	_name_label = Label.new()
	_name_label.name = "Here"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_name_label.size = Vector2(SIZE.x, 24)
	_name_label.add_theme_font_size_override("font_size", 17)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_map = _Plate.new()
	_map.name = "Plate"
	_map.owner_map = self
	_map.position = Vector2(0, 26)
	_map.size = SIZE
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	BridgeClient.snapshot_received.connect(_on_snapshot)
	visible = false


## Follow a Zone, or nothing (`null`, in the Hub).
func bind(controller: ZoneController) -> void:
	zone = controller
	if zone != null and not zone.chamber_entered.is_connected(_on_entered):
		zone.chamber_entered.connect(_on_entered)
	visible = zone != null
	rebuild()


func rebuild() -> void:
	if zone == null or not is_instance_valid(zone):
		_rooms = []
		_connectors = []
		_name_label.text = ""
		return
	var zone_map := BridgeClient.zone_map()
	if str(zone_map.get("zone_id", "")) != zone.zone_id:
		# A snapshot about another Zone (or none) says nothing about this
		# one's gates; the session's own walking still draws its rooms.
		zone_map = {"rooms": [], "connectors": []}
	var floors := {}
	for rid: Variant in zone.room_places:
		floors[rid] = ((zone.room_places[rid] as Dictionary).get("arrival",
				Vector3.ZERO) as Vector3).y
	_rooms = MinimapModel.rooms(zone_map, zone.room_bounds,
			zone.rooms_entered(), zone.current_room(), floors)
	colours = MinimapModel.circuit_colours(zone.zone)
	_connectors = MinimapModel.connectors(zone_map, zone.room_joins,
			zone.plug_positions)
	_name_label.text = MinimapModel.here_name(_rooms)


func rooms_drawn() -> Array:
	return _rooms


func connectors_drawn() -> Array:
	return _connectors


## Screen position, inside the plate, of a world point.
func to_plate(world: Vector2) -> Vector2:
	var centre := _centre()
	return SIZE * 0.5 + (world - centre) * PX_PER_M


func _centre() -> Vector2:
	if zone != null and is_instance_valid(zone) and zone.player != null:
		var at := zone.player.global_position
		return Vector2(at.x, at.z)
	return Vector2.ZERO


func _player_floor_y() -> float:
	for row: Dictionary in _rooms:
		if bool(row.get("here", false)):
			return float(row.get("floor_y", 0.0))
	if zone != null and is_instance_valid(zone) and zone.player != null:
		return zone.player.global_position.y
	return 0.0


func _on_entered(_index: int) -> void:
	rebuild()


func _on_snapshot(_snapshot: Dictionary) -> void:
	rebuild()


func _process(_delta: float) -> void:
	if visible:
		_map.queue_redraw()


## The drawing surface. Separate so it can clip without clipping the name.
class _Plate extends Control:
	var owner_map: Minimap = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08, 0.72))
		if owner_map == null:
			return
		owner_map.draw_log = {"text": [], "floor_marks": 0, "plug_marks": 0}
		var floor_y := owner_map._player_floor_y()
		for row: Dictionary in owner_map._rooms:
			var rect: Rect2 = row["rect"]
			var at := owner_map.to_plate(rect.position)
			var box := Rect2(at, rect.size * Minimap.PX_PER_M)
			var level := MinimapModel.floor_offset(float(row["floor_y"]),
					floor_y)
			var here := bool(row["here"])
			if level == 0:
				draw_rect(box, Color(0.55, 0.62, 0.70, 0.55 if here else 0.30))
				draw_rect(box, Color(0.85, 0.9, 0.95, 0.9 if here else 0.5),
						false, 2.0 if here else 1.0)
			else:
				draw_rect(box, Color(0.6, 0.65, 0.7, 0.45), false, 1.0)
				draw_colored_polygon(MinimapModel.floor_triangle(
						box.get_center(), level), Color(0.8, 0.85, 0.9, 0.8))
				owner_map.draw_log["floor_marks"] += 1
		for row: Dictionary in owner_map._connectors:
			var path: PackedVector2Array = row["path"]
			if path.size() < 2:
				_draw_plug(row, floor_y)
				continue
			var points := PackedVector2Array()
			for p: Vector2 in path:
				points.append(owner_map.to_plate(p))
			var ys: PackedFloat32Array = row["ys"]
			var level := MinimapModel.floor_offset(
					ys[0] if not ys.is_empty() else floor_y, floor_y)
			var state := str(row["state"])
			var tint := Color(0.78, 0.82, 0.86, 0.9)
			if state != "open":
				var circuits: Array = row["circuits"]
				tint = owner_map.colours.get(
						str(circuits[0]) if not circuits.is_empty() else "",
						Color(0.85, 0.85, 0.85))
			draw_polyline(points, tint, 3.0 if level == 0 else 1.5)
			if state != "open":
				_draw_blocker(owner_map.to_plate(row["mark_at"]), tint,
						str(row["symbol"]), state == "unknown")
		_draw_player()

	## A return plug: a ring where the device stands. Blocked or unknown,
	## it is a blocker like any other.
	func _draw_plug(row: Dictionary, floor_y: float) -> void:
		var mark: Vector2 = row["mark_at"]
		if mark == Vector2.INF:
			return
		var at := owner_map.to_plate(mark)
		var state := str(row["state"])
		if state != "open":
			var circuits: Array = row["circuits"]
			_draw_blocker(at, owner_map.colours.get(
					str(circuits[0]) if not circuits.is_empty() else "",
					Color(0.85, 0.85, 0.85)), str(row["symbol"]),
					state == "unknown")
			return
		var ys: PackedFloat32Array = row["ys"]
		var level := MinimapModel.floor_offset(
				ys[0] if not ys.is_empty() else floor_y, floor_y)
		var tint := Color(0.85, 0.92, 1.0, 0.95 if level == 0 else 0.5)
		draw_arc(at, 5.0, 0.0, TAU, 20, tint, 2.0)
		draw_circle(at, 1.8, tint)
		owner_map.draw_log["plug_marks"] += 1

	func _draw_blocker(at: Vector2, tint: Color, letter: String,
			unknown: bool) -> void:
		var r := 7.0
		var diamond := PackedVector2Array([at + Vector2(0, -r),
				at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
		draw_colored_polygon(diamond, tint.darkened(0.45))
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), tint, 2.0)
		_text(at + Vector2(-4, 4), "?" if unknown else letter, 11)

	## Every string on the plate goes through here, so the suite can ask
	## whether the font it is drawn in has every character of it.
	func _text(at: Vector2, text: String, font_size: int) -> void:
		draw_string(get_theme_default_font(), at, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		(owner_map.draw_log["text"] as Array).append(text)

	func _draw_player() -> void:
		var zone := owner_map.zone
		if zone == null or not is_instance_valid(zone) or zone.player == null:
			return
		var ahead := -zone.player.global_transform.basis.z
		var facing := Vector2(ahead.x, ahead.z).normalized()
		if facing == Vector2.ZERO:
			facing = Vector2(0, -1)
		var side := Vector2(-facing.y, facing.x)
		var at := size * 0.5
		draw_colored_polygon(PackedVector2Array([at + facing * 9.0,
				at - facing * 5.0 + side * 6.0,
				at - facing * 5.0 - side * 6.0]), Color(1.0, 0.95, 0.55))
