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
## Current resource values. Deliberately NOT campaign state:
## definitions and upgrades persist, current values reset on Zone
## entry (ECHOES.md 22), so nothing here is ever saved and no
## reconnect path has to reconcile a half-spent meter.
var resource_pool: ResourcePool
var rule_runtime: RuleRuntime
var _abandoning := false

## Headless integration mode: the driver owns the flow; views stay quiet.
var headless_test := false

## The headless suites, as PRELOADS rather than runtime `load`s.
##
## `preload` is resolved at parse time, which puts every driver into the
## dependency graph `--import` walks — so `make godot-import` compiles
## them, which is the guard that already exists. A runtime `load` does
## not: a parse error confined to a driver (a `var x := dict.get(...)`,
## Variant inference, a warning treated as an error here) sat undetected
## through a green import and surfaced only as "Nonexistent function
## 'new' in base 'GDScript'" four minutes into an integration run, with
## the bridge already up.
##
## Every suite boots the real project rather than running under
## `--script`, because a SceneTree script never instantiates the
## autoloads and so every script touching BridgeClient fails to compile.
const DRIVERS := {
	"--integration-test": preload("res://tests/integration_driver.gd"),
	"--chamber-test": preload("res://tests/test_chambers.gd"),
	"--blink-test": preload("res://tests/blink_driver.gd"),
	"--hud-test": preload("res://tests/hud_driver.gd"),
	"--rules-test": preload("res://tests/rules_driver.gd"),
	"--stats-test": preload("res://tests/stats_driver.gd"),
	"--lab-test": preload("res://tests/lab_driver.gd"),
	"--affordance-test": preload("res://tests/affordance_driver.gd"),
	"--verbs-test": preload("res://tests/verbs_driver.gd"),
	"--boot-test": preload("res://tests/boot_driver.gd"),
	"--legibility-test": preload("res://tests/legibility_driver.gd"),
	"--content-test": preload("res://tests/content_driver.gd"),
	"--activity-test": preload("res://tests/activity_driver.gd"),
	"--zone-audit": preload("res://tests/zone_audit_driver.gd"),
	"--zone-shots": preload("res://tests/zone_shot_driver.gd"),
}

func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	for flag: String in DRIVERS:
		if flag in user_args:
			headless_test = true
			add_child((DRIVERS[flag] as GDScript).new())
			return
	boot()

## Everything the real game needs, extracted so a test can call it.
##
## It used to be the tail of `_ready`, which meant NO suite ran it: every
## driver takes the branch above and returns first. That is how ba0a804
## deleted the world and the sound bank and nine green suites plus two CI
## tiers said nothing for a day, while the game could not enter the Hub
## at all. `--boot-test` calls this directly.
func boot() -> void:
	# The world every Hub and Zone is parented to, and the sound bank.
	#
	# These were lost in ba0a804, which replaced the block of per-driver
	# `if` statements above with the `DRIVERS` loop and took the five
	# lines that happened to sit underneath it. The game could not enter
	# the Hub from that commit until this one: `_clear_world()` is the
	# first thing every transition calls, and it dereferenced null.
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	tones = Tones.new()
	add_child(tones)

	menu = MainMenu.new()
	add_child(menu)
	resource_pool = ResourcePool.new()
	resource_pool.name = "ResourcePool"
	add_child(resource_pool)
	rule_runtime = RuleRuntime.new()
	rule_runtime.name = "RuleRuntime"
	rule_runtime.pool = resource_pool
	add_child(rule_runtime)
	# The fold owns which rules exist; every snapshot may change them.
	BridgeClient.snapshot_received.connect(func(_s: Dictionary) -> void:
		rule_runtime.refresh_rules())
	BridgeClient.notification_received.connect(func(n: Dictionary) -> void:
		if str(n.get("kind", "")) in ["reveal", "check_confirmed"]:
			rule_runtime.notify("check_claimed"))
	hud = Hud.new()
	add_child(hud)
	hud.meters.pool = resource_pool
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

func _on_snapshot(_snapshot: Dictionary) -> void:
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
		_equip_all_slots(zone.player)

## S7: four slots, four runtimes, each fed the Action the fold says is in
## it. An empty slot is legal and stays empty — the Static Pulse is what
## you always have, and it is on its own button.
func _equip_all_slots(target: Player) -> void:
	for slot: String in Constants.SLOT_NAMES:
		var runtime: EchoRuntime = target.runtimes.get(slot)
		if runtime != null:
			runtime.set_equipped(BridgeClient.slotted_action(slot))

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
	if rule_runtime != null:
		rule_runtime.player = null
		rule_runtime.echo_runtime = null
		rule_runtime.zone_root = null

## Wire one freshly created player's gameplay signals into the rule engine,
## and the two places a source world's identity package is heard.
## A new player instance arrives with every Hub/Zone entry, so these are
## fresh connects, never duplicates. The engine only interprets folded rule
## components; this is the one place the game's own events reach it.
func _bind_rule_runtime(target: Player, zone_ctl: ZoneController) -> void:
	rule_runtime.player = target
	# The rule engine's `reset_action_cooldown` and `grant_shield` act on
	# the slot the player is looking at, which is what "your Echo" means
	# from inside a rule.
	rule_runtime.echo_runtime = target.echo_runtime
	rule_runtime.zone_root = zone_ctl
	rule_runtime.refresh_rules()
	# The stat stack and the action runner both read live fractions; the
	# pool is main's.
	target.stat_stack.pool = resource_pool
	for runtime: EchoRuntime in target.runtimes.values():
		runtime.pool = resource_pool
	target.jumped.connect(func() -> void: rule_runtime.notify("jump"))
	target.footstep.connect(func(kind: String) -> void:
		if kind == "land":
			rule_runtime.notify("land"))
	target.hit_confirmed.connect(func(killed: bool) -> void:
		rule_runtime.notify("damage_dealt")
		if killed:
			rule_runtime.notify("kill"))
	target.damaged_from.connect(func(_source: Vector3) -> void:
		rule_runtime.notify("damage_taken"))
	# Every slot reports, not just the highlighted one: a rule watching
	# `action_used` means "you used an Echo", and a dash on Shift is as
	# much an Echo as a shot on RMB.
	for runtime: EchoRuntime in target.runtimes.values():
		var fired: EchoRuntime = runtime
		fired.parried.connect(func() -> void:
			rule_runtime.notify("parry_success"))
		fired.action_used.connect(func() -> void:
			rule_runtime.notify("action_used")
			# ECHOES §12: an Echo sounds like the world it came from. Same
			# procedural bank, pitched by that world's sound family —
			# which is what keeps a campaign of borrowed parts sounding
			# like a place rather than like one instrument.
			tones.play("echo", fired.source_pitch()))
		fired.action_ready.connect(func() -> void:
			rule_runtime.notify("action_ready"))
		fired.dash_ended.connect(func() -> void:
			rule_runtime.notify("dash_end"))
	if zone_ctl != null:
		zone_ctl.chamber_entered.connect(func(_index: int) -> void:
			rule_runtime.notify("chamber_enter"))

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
	# Epsilon speaks in the Hub too now. Handed the HUD rather than
	# reaching for it: the Hub is built by this file, so this file is
	# where the wiring belongs.
	hub.hud = hud
	hub.refresh()
	hud.bind_player(hub.player)
	hub.player.fired_pulse.connect(func() -> void: tones.play("pulse"))
	hub.player.footstep.connect(func(kind: String) -> void: tones.play(kind))
	_equip_all_slots(hub.player)
	_bind_rule_runtime(hub.player, null)
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
	# Before setup, so a Zone whose first frame already spends something
	# sees full channels rather than last Zone's leftovers. The rule
	# engine resets with it: its latches, cooldowns and watched values are
	# derived from exactly the state I9 is clearing, so a latch left armed
	# fired on the next Zone's first tick against a threshold that no
	# longer existed.
	resource_pool.reset_for_zone()
	rule_runtime.reset_for_zone()
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
	_bind_rule_runtime(zone.player, zone)
	rule_runtime.notify("zone_enter")
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
		var echo := BridgeClient.echo_by_id(str(featured[0]))
		if not echo.is_empty():
			note = "Built with your %s in mind. %s" % [
					echo.get("display_name", "Echo"), note]
	hud.show_zone_title(index_text, str(zone_dict.get("display_name", "")),
			note.strip_edges(),
			Color(ThemeMaterials.spec(theme)["accent_color"]).lightened(0.25))
	_sync_equipped()
	zone.refresh()
	_update_modal()

func _on_exit_zone() -> void:
	_send_zone_timing(true)
	BridgeClient.send_intent({"type": "exit_zone", "zone_id": zone.zone_id})
	_to_hub()

## What the Zone cost, sent once as the player leaves (CAMPAIGN_SCALE.md
## 13). The bridge writes it to a local file and nothing else -- it is
## not campaign state, no snapshot carries it, and it goes nowhere near
## the network beyond the bridge already running on this machine.
##
## `completed` separates a Zone finished from one bailed out of: an
## abandoned Zone's elapsed time is not a Zone length.
func _send_zone_timing(completed: bool) -> void:
	if zone == null:
		return
	var intent: Dictionary = zone.playtime.to_intent(zone.zone_id, completed)
	if not intent.is_empty():
		BridgeClient.send_intent(intent)

func _on_return_to_hub() -> void:
	pause_menu.close()
	if view == View.ZONE:
		_send_zone_timing(false)
		BridgeClient.send_intent({"type": "leave_zone",
				"zone_id": zone.zone_id})
		_to_hub()

func _on_abandon() -> void:
	pause_menu.close()
	if view == View.ZONE:
		_abandoning = true
		_send_zone_timing(false)
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
		_cycle_echo(1, _highlighted_slot())
	elif event.is_action_pressed("cycle_echo_back"):
		_cycle_echo(-1, _highlighted_slot())

## `step` is +1 or -1. By the end of a campaign the archive holds 26
## Echoes, and a forward-only cycle means overshooting one costs 25 more
## presses -- which is why the wheel scrolls it both ways.
func _cycle_echo(step: int, slot := "echo_a") -> void:
	# Only Actions declared for THIS slot are candidates. A mobility Echo is
	# not a thing RMB can hold, and offering it would produce an intent the
	# bridge is obliged to refuse.
	var ids: Array = []
	for entry: Dictionary in BridgeClient.owned_components("action"):
		var component: Dictionary = entry.get("component", {})
		if component.get("slot", "") == slot:
			ids.append(str(component.get("component_id", "")))
	if ids.is_empty():
		return
	# S7: favourites narrow the wheel, if the player marked at least two
	# in this slot. One favourite would cycle to itself, which is a wheel
	# that appears to be broken, so that case keeps the full list.
	ids = Favourites.cycle_set(ids)
	var current: Variant = BridgeClient.slots().get(slot)
	var index := ids.find(str(current)) if current != null else -1
	# posmod, not %: GDScript's % keeps the sign, so stepping back from the
	# first Action would index -1 and slot nothing.
	var next: String = ids[posmod(index + step, ids.size())]
	BridgeClient.send_intent({"type": "slot_action", "slot": slot,
			"component_id": next})

## The wheel cycles within whichever slot you last fired (ECHOES §9:
## "favourites within the highlighted slot"), so one wheel serves four
## slots without a modifier key.
func _highlighted_slot() -> String:
	if zone != null and zone.player != null:
		return zone.player.highlighted_slot
	if hub != null and hub.player != null:
		return hub.player.highlighted_slot
	return "echo_a"

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
