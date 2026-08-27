extends Node
## Application flow: MENU → HUB → ZONE. The bridge owns campaign truth;
## this node routes snapshots into whichever view is loaded and forwards
## player intents back.

enum View { MENU, HUB, ZONE }

var view := View.MENU
var world: Node3D
var hub: HubController
var zone: ZoneController
var menu: MainMenu
var hud: Hud
var reveal: RevealLayer
var inventory: InventoryLayer
var pause_menu: PauseMenu
var debug: DebugOverlay
var tones: Tones

var _entering_zone := false
var _abandoning := false

## Headless integration mode: the driver owns the flow; views stay quiet.
var headless_test := false

func _ready() -> void:
	headless_test = "--integration-test" in OS.get_cmdline_user_args()
	if headless_test:
		var driver: Node = load("res://tests/integration_driver.gd").new()
		add_child(driver)
		return
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	tones = Tones.new()
	add_child(tones)
	menu = MainMenu.new()
	add_child(menu)
	hud = Hud.new()
	add_child(hud)
	hud.visible = false
	reveal = RevealLayer.new()
	reveal.tones = tones
	add_child(reveal)
	inventory = InventoryLayer.new()
	add_child(inventory)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	debug = DebugOverlay.new()
	add_child(debug)

	menu.connect_pressed.connect(_on_menu_connect)
	menu.mock_pressed.connect(_on_menu_mock)
	reveal.reveal_started.connect(_update_modal)
	reveal.reveal_finished.connect(_update_modal)
	inventory.closed.connect(_update_modal)
	pause_menu.resumed.connect(_update_modal)
	pause_menu.return_to_hub_requested.connect(_on_return_to_hub)
	pause_menu.abandon_confirmed.connect(_on_abandon)

	BridgeClient.snapshot_received.connect(_on_snapshot)
	BridgeClient.notification_received.connect(_on_notification)
	BridgeClient.error_received.connect(_on_bridge_error)
	BridgeClient.bridge_state_changed.connect(
			func(_online: bool) -> void: menu.refresh())

func _on_menu_connect(server: String, slot: String, password: String) -> void:
	menu.show_error("Connecting to %s…" % server)
	BridgeClient.send_intent({"type": "ap_connect", "server": server,
			"slot_name": slot, "password": password})

func _on_menu_mock() -> void:
	BridgeClient.send_intent({"type": "start_mock_campaign"})

# ---------------------------------------------------------------------------

func _on_snapshot(snapshot: Dictionary) -> void:
	menu.refresh()
	debug.refresh()
	var mode := BridgeClient.hub_mode()
	match view:
		View.MENU:
			if mode != "NO_CAMPAIGN":
				_to_hub()
		View.HUB:
			if mode == "NO_CAMPAIGN":
				_to_menu()
			elif _entering_zone and mode == "ZONE_ACTIVE" \
					and not BridgeClient.active_zone().get("zone", {}).is_empty():
				_entering_zone = false
				_to_zone(BridgeClient.active_zone()["zone"])
			elif hub != null:
				hub.refresh()
		View.ZONE:
			if mode == "NO_CAMPAIGN":
				_to_menu()
			elif _abandoning and BridgeClient.active_zone().is_empty():
				_abandoning = false
				_to_hub()
			elif zone != null:
				zone.refresh()
				_sync_equipped()
	if inventory.visible:
		inventory.rebuild()
	hud.refresh_echo()

func _sync_equipped() -> void:
	if zone != null and zone.player != null:
		zone.player.echo_runtime.set_equipped(BridgeClient.equipped_echo())

func _on_notification(note: Dictionary) -> void:
	var kind := str(note.get("kind", ""))
	match kind:
		"reveal", "check_confirmed", "echo_acquired", "goal_reached":
			reveal.enqueue(note)
			if kind != "echo_acquired":
				tones.play("reward")
		"coin_received", "signal_key_received":
			tones.play("purchase")
			hud.toast(str(note.get("title", "")), Color(0.95, 0.85, 0.4))
		"static_received":
			hud.toast("EPSILON STATIC accumulates…", Color(0.9, 0.4, 0.9))
		"shop_purchased":
			tones.play("purchase")
			hud.toast(str(note.get("title", "")), Color(0.7, 1.0, 0.7))
		"fallback_used":
			hud.toast("EPSILON OFFLINE — FALLBACK USED", Color(1.0, 0.6, 0.5))
		"sync_warning":
			hud.toast(str(note.get("title", "")), Color(1.0, 0.5, 0.4), 6.0)
		"zone_abandoned":
			hud.toast(str(note.get("title", "")), Color(1.0, 0.6, 0.4))
		"ap_offline":
			hud.toast("ARCHIPELAGO OFFLINE", Color(1.0, 0.5, 0.4))

func _on_bridge_error(err: Dictionary) -> void:
	var message := str(err.get("message", "bridge error"))
	tones.play("denied")
	if view == View.MENU:
		menu.show_error(message)
	else:
		hud.toast(message, Color(1.0, 0.45, 0.4), 5.0)

# -- view transitions -------------------------------------------------------

func _clear_world() -> void:
	for child in world.get_children():
		child.queue_free()
	hub = null
	zone = null

func _to_menu() -> void:
	_clear_world()
	view = View.MENU
	menu.visible = true
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.refresh()

func _to_hub() -> void:
	_clear_world()
	view = View.HUB
	menu.visible = false
	hud.visible = true
	hub = HubController.new()
	world.add_child(hub)
	hub.enter_zone_requested.connect(_on_enter_zone)
	hub.open_inventory_requested.connect(_toggle_inventory)
	hub.open_shop_requested.connect(_toggle_inventory)  # shop UI: Phase 6
	hub.refresh()
	hud.bind_player(hub.player)
	hub.player.echo_runtime.set_equipped(BridgeClient.equipped_echo())
	_update_modal()

func _toggle_inventory() -> void:
	if inventory.visible:
		inventory.close()
	else:
		inventory.open()
	_update_modal()

func _on_enter_zone() -> void:
	var active := BridgeClient.active_zone()
	if active.is_empty():
		return
	_entering_zone = true
	BridgeClient.send_intent({"type": "enter_zone",
			"zone_id": active.get("zone_id", "")})

func _to_zone(zone_dict: Dictionary) -> void:
	_clear_world()
	view = View.ZONE
	menu.visible = false
	hud.visible = true
	zone = ZoneController.new()
	world.add_child(zone)
	zone.setup(zone_dict)
	zone.exit_requested.connect(_on_exit_zone)
	hud.bind_player(zone.player)
	_sync_equipped()
	zone.refresh()
	hud.toast(str(zone_dict.get("display_name", "")), Color(0.7, 0.9, 1.0))
	var note: Variant = zone_dict.get("designer_note")
	if note:
		hud.toast(str(note), Color(0.55, 0.65, 0.7), 6.0)
	_update_modal()

func _on_exit_zone() -> void:
	BridgeClient.send_intent({"type": "exit_zone", "zone_id": zone.zone_id})
	_to_hub()

func _on_return_to_hub() -> void:
	pause_menu.close()
	if view == View.ZONE:
		BridgeClient.send_intent({"type": "leave_zone",
				"zone_id": zone.zone_id})
		_to_hub()

func _on_abandon() -> void:
	pause_menu.close()
	if view == View.ZONE:
		_abandoning = true
		BridgeClient.send_intent({"type": "abandon_zone",
				"zone_id": zone.zone_id})

# -- global input -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		debug.toggle()
	if view == View.MENU:
		return
	if event.is_action_pressed("pause"):
		if inventory.visible:
			inventory.close()
		elif pause_menu.visible:
			pause_menu.close()
		else:
			pause_menu.open(view == View.ZONE)
		_update_modal()
	elif event.is_action_pressed("inventory"):
		if inventory.visible:
			inventory.close()
		else:
			inventory.open()
		_update_modal()
	elif event.is_action_pressed("cycle_echo"):
		_cycle_echo()

func _cycle_echo() -> void:
	var echoes: Array = BridgeClient.snapshot.get("echoes", [])
	if echoes.is_empty():
		return
	var equipped: Variant = BridgeClient.snapshot.get("equipped_echo_id")
	var ids: Array = echoes.map(
			func(echo: Dictionary) -> String: return str(echo["echo_id"]))
	var index := ids.find(equipped) if equipped != null else -1
	var next: String = ids[(index + 1) % ids.size()]
	BridgeClient.send_intent({"type": "equip_echo", "echo_id": next})

func _update_modal() -> void:
	var modal := pause_menu.visible or inventory.visible or reveal.visible
	var player: Player = null
	if hub != null:
		player = hub.player
	elif zone != null:
		player = zone.player
	if player != null:
		player.input_frozen = modal
	hud.set_crosshair_visible(not modal)
	if view == View.MENU or pause_menu.visible or inventory.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
