class_name HubController
extends Node3D
## The authored Hub: portal, status board, shop counter, Echo terminal, and
## the Hub-side abandon console. Every displayed fact is read off the
## snapshot — portal_enabled, finale_offered, generation_in_progress are
## computed by the bridge and never re-derived here.

signal enter_zone_requested
signal open_inventory_requested
signal open_shop_requested

const THEME := "concrete_facility"
const W := 22.0
const D := 16.0
const H := 5.0

var player: Player
var _portal: HubPortal
var _finale_portal: HubPortal
var _abandon: AbandonConsole
var _board: Label3D
var _sub_board: Label3D
var _static_root: Node3D
var _static_count := -1

func _ready() -> void:
	_build_room()
	player = Player.create()
	add_child(player)
	player.set_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 3.0)))
	refresh()

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.ambient_light_energy = 0.4
	environment.environment = env
	add_child(environment)

	var b := ChamberBuilders
	var root := Node3D.new()
	add_child(root)
	b._box(root, Vector3(W, 0.5, D), Vector3(0, -0.25, D / 2.0),
			ThemeMaterials.floor_mat(THEME))
	b._perimeter(root, W, D, H, THEME, false, false)
	b._box(root, Vector3(W, 0.4, D), Vector3(0, H, D / 2.0),
			ThemeMaterials.trim_mat(THEME))
	for position in [Vector3(-W / 4.0, H - 0.4, D / 2.0),
			Vector3(W / 4.0, H - 0.4, D / 2.0)]:
		b._light(root, position, THEME, 16.0)

	# The Zone portal, centre of the back wall.
	_portal = HubPortal.new()
	_portal.kind = "main"
	add_child(_portal)
	_portal.position = Vector3(0, 0, D - 1.2)
	_portal.activated.connect(_on_portal_activated)

	# The finale portal: smaller, redder, only shown when offered.
	_finale_portal = HubPortal.new()
	_finale_portal.kind = "finale"
	add_child(_finale_portal)
	_finale_portal.position = Vector3(W / 2.0 - 3.0, 0, D - 1.2)
	_finale_portal.activated.connect(_on_finale_activated)

	# Status board above the portal.
	_board = Label3D.new()
	_board.position = Vector3(0, 4.2, D - 1.4)
	_board.font_size = 96
	_board.pixel_size = 0.008
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_board)
	_sub_board = Label3D.new()
	_sub_board.position = Vector3(0, 3.4, D - 1.4)
	_sub_board.font_size = 40
	_sub_board.pixel_size = 0.008
	_sub_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_board.modulate = Color(0.75, 0.8, 0.85)
	add_child(_sub_board)

	# Shop counter, left wall.
	var shop := SimpleStation.new()
	shop.label_text = "QUESTIONABLE GOODS"
	shop.prompt = "[E] BROWSE SHOP"
	shop.station_color = Color(0.9, 0.7, 0.25)
	add_child(shop)
	shop.position = Vector3(-W / 2.0 + 1.6, 0, D * 0.45)
	shop.rotation.y = -PI / 2.0
	shop.used.connect(func() -> void: open_shop_requested.emit())

	# Echo terminal, right wall.
	var terminal := SimpleStation.new()
	terminal.label_text = "ECHO ARCHIVE"
	terminal.prompt = "[E] OPEN ECHO INVENTORY"
	terminal.station_color = Color(0.4, 0.9, 0.85)
	add_child(terminal)
	terminal.position = Vector3(W / 2.0 - 1.6, 0, D * 0.45)
	terminal.rotation.y = PI / 2.0
	terminal.used.connect(func() -> void: open_inventory_requested.emit())

	# Abandon console, next to the portal; the only exit from GENERATING
	# and ZONE_READY, which have no pause menu to reach.
	_abandon = AbandonConsole.new()
	add_child(_abandon)
	_abandon.position = Vector3(-W / 2.0 + 2.4, 0, D - 2.4)

	_static_root = Node3D.new()
	add_child(_static_root)

func _on_portal_activated() -> void:
	var hub := BridgeClient.hub()
	match BridgeClient.hub_mode():
		"ZONE_AVAILABLE":
			BridgeClient.send_intent(
					{"type": "request_next_zone", "finale": false})
		"FINALE_ONLY":
			BridgeClient.send_intent(
					{"type": "request_next_zone", "finale": true})
		"ZONE_READY", "ZONE_ACTIVE":
			enter_zone_requested.emit()

func _on_finale_activated() -> void:
	BridgeClient.send_intent({"type": "request_next_zone", "finale": true})

## Applies the latest snapshot to every display in the room.
func refresh() -> void:
	var snapshot := BridgeClient.snapshot
	var hub := BridgeClient.hub()
	var mode := BridgeClient.hub_mode()

	_board.text = str(hub.get("headline", ""))
	var lines: Array[String] = []
	var detail := str(hub.get("detail", ""))
	if detail != "":
		lines.append(detail)
	lines.append("CHECKS %d/30   KEYS %d/2   COINS %d" % [
			snapshot.get("checked_location_ids", []).size(),
			int(snapshot.get("signal_keys", 0)),
			int(snapshot.get("coins_available", 0))])
	if hub.get("finale_unlocked", false):
		lines.append("FINALE UNLOCKED")
	elif int(hub.get("finale_progress", 0)) > 0:
		lines.append("FINALE %d/%d + %d/%d KEYS" % [
				int(hub.get("finale_progress", 0)),
				int(hub.get("finale_required", 24)),
				int(hub.get("signal_keys", 0)),
				int(hub.get("signal_keys_required", 2))])
	if not snapshot.get("ap_connected", false):
		lines.append("ARCHIPELAGO OFFLINE")
	_sub_board.text = "\n".join(lines)

	_portal.refresh(hub, mode)
	# finale_offered stays true in postgame (schema-computed from thresholds
	# that remain met); only offer it while the goal is actually missing.
	var goal_missing := false
	for loc in snapshot.get("missing_location_ids", []):
		if int(loc) == Constants.GOAL_LOCATION_ID:
			goal_missing = true
	_finale_portal.visible = bool(hub.get("finale_offered", false)) \
			and goal_missing and mode == "ZONE_AVAILABLE"
	_finale_portal.refresh(hub, "FINALE_OFFERED")
	_abandon.refresh(mode, BridgeClient.active_zone())
	_refresh_static(int(snapshot.get("static_glitch_units", 0)))

## Epsilon Static: permanent cosmetic Hub corruption, one unit per Static.
func _refresh_static(count: int) -> void:
	count = mini(count, int(Constants.STATIC_GLITCH_VISUAL_CAP))
	if count == _static_count:
		return
	_static_count = count
	for child in _static_root.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 891
	for i in count:
		var glitch := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var s := rng.randf_range(0.15, 0.5)
		mesh.size = Vector3(s, s, s)
		glitch.mesh = mesh
		glitch.position = Vector3(rng.randf_range(-W / 2.0 + 1, W / 2.0 - 1),
				rng.randf_range(0.3, H - 0.5),
				rng.randf_range(1.0, D - 1.0))
		glitch.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		glitch.material_override = ThemeMaterials.glow_material(
				Color(1.0, 0.0, 0.9) if i % 2 == 0 else Color(0.0, 1.0, 0.75),
				0.9)
		_static_root.add_child(glitch)


class HubPortal extends StaticBody3D:
	signal activated
	var kind := "main"
	var _core: MeshInstance3D
	var _label: Label3D
	var _enabled := false
	var _prompt := ""

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 4.0, 0.8) if kind == "main" \
				else Vector3(2.0, 3.0, 0.8)
		shape.shape = box
		shape.position = Vector3(0, box.size.y / 2.0, 0)
		add_child(shape)
		var frame := MeshInstance3D.new()
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = box.size + Vector3(0.4, 0.4, -0.2)
		frame.mesh = frame_mesh
		frame.position = Vector3(0, box.size.y / 2.0, 0)
		frame.material_override = ThemeMaterials.trim_mat(HubController.THEME)
		add_child(frame)
		_core = MeshInstance3D.new()
		var core_mesh := BoxMesh.new()
		core_mesh.size = box.size - Vector3(0.4, 0.4, 0.5)
		_core.mesh = core_mesh
		_core.position = Vector3(0, box.size.y / 2.0, 0.2)
		add_child(_core)
		_label = Label3D.new()
		_label.position = Vector3(0, box.size.y + 0.5, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 40
		_label.pixel_size = 0.007
		add_child(_label)

	func refresh(hub: Dictionary, mode: String) -> void:
		if kind == "finale":
			_enabled = bool(hub.get("finale_offered", false))
			_prompt = "[E] GENERATE THE FINALE"
			_label.text = "FINALE"
			_core.material_override = ThemeMaterials.glow_material(
					Color(1.0, 0.25, 0.2), 1.8 if _enabled else 0.3)
			return
		_enabled = bool(hub.get("portal_enabled", false))
		match mode:
			"ZONE_AVAILABLE":
				_prompt = "[E] GENERATE NEXT ZONE"
				_label.text = "PORTAL"
			"FINALE_ONLY":
				_prompt = "[E] GENERATE THE FINALE"
				_label.text = "FINALE"
			"ZONE_READY":
				_prompt = "[E] ENTER ZONE"
				_label.text = "ZONE READY"
			"ZONE_ACTIVE":
				_prompt = "[E] RESUME ZONE"
				_label.text = "ZONE IN PROGRESS"
			"GENERATING":
				_prompt = "EPSILON IS DESIGNING…"
				_label.text = "GENERATING"
			_:
				_prompt = ""
				_label.text = "PORTAL"
		var color := Color(0.4, 0.9, 1.0) if _enabled else Color(0.25, 0.25, 0.3)
		if mode == "GENERATING":
			color = Color(0.9, 0.5, 1.0)
		_core.material_override = ThemeMaterials.glow_material(
				color, 1.8 if _enabled else 0.5)

	func interact_prompt() -> String:
		return _prompt if _enabled else _prompt

	func interact(_player: Node) -> void:
		if _enabled:
			activated.emit()


class SimpleStation extends StaticBody3D:
	signal used
	var label_text := ""
	var prompt := ""
	var station_color := Color.WHITE

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.4, 1.4, 1.0)
		shape.shape = box
		shape.position = Vector3(0, 0.7, 0)
		add_child(shape)
		var counter := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 1.1, 0.9)
		counter.mesh = mesh
		counter.position = Vector3(0, 0.55, 0)
		counter.material_override = ThemeMaterials.accent_mat(
				HubController.THEME)
		add_child(counter)
		var sign := MeshInstance3D.new()
		var sign_mesh := BoxMesh.new()
		sign_mesh.size = Vector3(2.2, 0.5, 0.1)
		sign.mesh = sign_mesh
		sign.position = Vector3(0, 2.2, 0)
		sign.material_override = ThemeMaterials.glow_material(
				station_color, 1.2)
		add_child(sign)
		var label := Label3D.new()
		label.text = label_text
		label.position = Vector3(0, 2.2, 0.1)
		label.font_size = 36
		label.pixel_size = 0.006
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

	func interact_prompt() -> String:
		return prompt

	func interact(_player: Node) -> void:
		used.emit()


class AbandonConsole extends StaticBody3D:
	var _visible_modes := ["GENERATING", "ZONE_READY", "ZONE_ACTIVE"]
	var _zone_id := ""
	var _armed := false
	var _label: Label3D

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.3, 1.0)
		shape.shape = box
		shape.position = Vector3(0, 0.65, 0)
		add_child(shape)
		var console := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(1.0, 1.2, 0.8)
		console.mesh = mesh
		console.position = Vector3(0, 0.6, 0)
		console.material_override = ThemeMaterials.glow_material(
				Color(0.8, 0.2, 0.15), 0.8)
		add_child(console)
		_label = Label3D.new()
		_label.position = Vector3(0, 1.7, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 30
		_label.pixel_size = 0.006
		add_child(_label)

	func refresh(mode: String, active_zone: Dictionary) -> void:
		visible = mode in _visible_modes
		_zone_id = str(active_zone.get("zone_id", ""))
		if not visible:
			_armed = false
		_label.text = "ABANDON ZONE" if not _armed \
				else "CONFIRM ABANDON?\nUnclaimed Checks return to the pool"

	func interact_prompt() -> String:
		return "[E] CONFIRM ABANDON — unclaimed Checks return to the pool" \
				if _armed else "[E] ABANDON HELD ZONE"

	func interact(_player: Node) -> void:
		if _zone_id == "":
			return
		if not _armed:
			_armed = true
			_label.text = "CONFIRM ABANDON?"
			return
		_armed = false
		BridgeClient.send_intent(
				{"type": "abandon_zone", "zone_id": _zone_id})
