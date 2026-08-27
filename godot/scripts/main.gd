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
var shop: ShopUI
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
	shop = ShopUI.new()
	add_child(shop)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	debug = DebugOverlay.new()
	add_child(debug)

	menu.connect_pressed.connect(_on_menu_connect)
	menu.mock_pressed.connect(_on_menu_mock)
	reveal.reveal_started.connect(_update_modal)
	reveal.reveal_finished.connect(_update_modal)
	inventory.closed.connect(_update_modal)
	shop.closed.connect(_update_modal)
	pause_menu.resumed.connect(_update_modal)
	pause_menu.return_to_hub_requested.connect(_on_return_to_hub)
	pause_menu.abandon_confirmed.connect(_on_abandon)

	BridgeClient.snapshot_received.connect(_on_snapshot)
	BridgeClient.notification_received.connect(_on_notification)
	BridgeClient.error_received.connect(_on_bridge_error)
	BridgeClient.bridge_state_changed.connect(
			func(_online: bool) -> void:
				menu.refresh()
				_refresh_banner())

func _refresh_banner() -> void:
	if not BridgeClient.online:
		hud.set_banner("BRIDGE OFFLINE — RECONNECTING…")
	elif view != View.MENU \
			and not BridgeClient.snapshot.get("ap_connected", false):
		hud.set_banner("ARCHIPELAGO OFFLINE")
	else:
		hud.set_banner("")

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
	_refresh_banner()
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
	if shop.visible:
		shop.rebuild()
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
	hud.clear_waypoint()
	hud.set_objective_text("")
	tones.stop_ambience()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.refresh()

func _to_hub() -> void:
	_clear_world()
	view = View.HUB
	menu.visible = false
	hud.visible = true
	hud.clear_waypoint()
	hud.set_objective_text("")
	hud.reset_voice()
	hub = HubController.new()
	world.add_child(hub)
	hub.enter_zone_requested.connect(_on_enter_zone)
	hub.open_inventory_requested.connect(_toggle_inventory)
	hub.open_shop_requested.connect(_toggle_shop)
	hub.refresh()
	hud.bind_player(hub.player)
	hub.player.fired_pulse.connect(func() -> void: tones.play("pulse"))
	hub.player.footstep.connect(func(kind: String) -> void: tones.play(kind))
	hub.player.echo_runtime.set_equipped(BridgeClient.equipped_echo())
	tones.play_ambience(1.0)
	_update_modal()

func _toggle_inventory() -> void:
	if inventory.visible:
		inventory.close()
	else:
		inventory.open()
	_update_modal()

func _toggle_shop() -> void:
	if shop.visible:
		shop.close()
	else:
		shop.open()
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
	hud.reset_voice()
	var record := BridgeClient.active_zone()
	zone = ZoneController.new()
	zone.tones = tones
	zone.hud = hud
	zone.is_finale = bool(record.get("is_finale", false))
	world.add_child(zone)
	zone.setup(zone_dict)
	zone.exit_requested.connect(_on_exit_zone)
	hud.bind_player(zone.player)
	zone.player.fired_pulse.connect(func() -> void: tones.play("pulse"))
	zone.player.footstep.connect(func(kind: String) -> void: tones.play(kind))
	# Only the connect ticks here: a kill already has the death tone that
	# ZoneController plays, and stacking both on one shot reads as a stutter.
	zone.player.hit_confirmed.connect(func(killed: bool) -> void:
		if not killed:
			tones.play("confirm"))
	var theme := str(zone_dict.get("theme", "void_glitch"))
	# The last transmission gets a lower, heavier room tone than any Zone
	# before it, so the finale sounds different before it looks different.
	tones.play_ambience(0.55 if zone.is_finale
			else 0.8 + float(hash(theme) % 100) / 200.0)

	# Count the zones the player has actually played, not the generation
	# counter — that also advances for zones generated then abandoned, and
	# would disagree with the Hub's completed-zone count on screen.
	var played := int(BridgeClient.snapshot.get("completed_zone_count", 0)) + 1
	var index_text := "FINALE TRANSMISSION" if record.get("is_finale", false) \
			else "ZONE %d · %s" % [played,
				str(zone_dict.get("target_game", "?")).to_upper()]
	# NOT `x or ""`: GDScript's `or` yields a bool, so that renders the
	# literal text "true"/"false" on the card.
	var note_value: Variant = zone_dict.get("designer_note")
	var note := str(note_value) if note_value != null else ""
	# If Epsilon designed around an Echo you own, say so — that connection
	# is the premise, and it was previously invisible.
	var featured: Array = zone_dict.get("featured_echo_ids", [])
	if not featured.is_empty():
		for echo: Dictionary in BridgeClient.snapshot.get("echoes", []):
			if echo.get("echo_id") == featured[0]:
				note = "Built with your %s in mind. %s" % [
						echo.get("display_name", "Echo"), note]
				break
	hud.show_zone_title(index_text, str(zone_dict.get("display_name", "")),
			note.strip_edges(),
			Color(ThemeMaterials.spec(theme)["accent_color"]).lightened(0.25))
	_sync_equipped()
	zone.refresh()
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
		elif shop.visible:
			shop.close()
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
	var modal: bool = pause_menu.visible or inventory.visible \
			or shop.visible or reveal.visible
	var player: Player = null
	if hub != null:
		player = hub.player
	elif zone != null:
		player = zone.player
	if player != null:
		player.input_frozen = modal
	hud.set_crosshair_visible(not modal)
	if view == View.MENU or pause_menu.visible or inventory.visible \
			or shop.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
