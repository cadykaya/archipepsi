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
var station_panel: StationPanel
var pause_menu: PauseMenu
var debug: DebugOverlay
## F5, review-only. See `nav_schematic.gd`: not a map feature, and
## nothing in the game reads it.
var nav: NavSchematic
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
	"--room-test": preload("res://tests/room_driver.gd"),
	"--return-placement": preload("res://tests/return_placement_driver.gd"),
	"--room-contract": preload("res://tests/room_contract_driver.gd"),
	"--graphs": preload("res://tests/graph_driver.gd"),
	"--movement-test": preload("res://tests/movement_driver.gd"),
	"--playtest3a-test": preload("res://tests/playtest3a_driver.gd"),
	"--physics-test": preload("res://tests/physics_driver.gd"),
	"--traverse-test": preload("res://tests/traverse_driver.gd"),
	"--target-facing": preload("res://tests/target_facing_driver.gd"),
	"--exit-reach": preload("res://tests/exit_reach_driver.gd"),
	"--passenger-carry": preload("res://tests/passenger_carry_driver.gd"),
	"--rail-carrier": preload("res://tests/rail_carrier_driver.gd"),
	"--rail-junction": preload("res://tests/rail_junction_driver.gd"),
	"--passing-platforms-test": preload(
		"res://tests/passing_platforms_driver.gd"),
	"--counterfire-test": preload("res://tests/counterfire_driver.gd"),
	"--unweighted-test": preload("res://tests/unweighted_driver.gd"),
	"--rail-zone": preload("res://tests/rail_zone_driver.gd"),
	"--zone-state": preload("res://tests/zone_state_driver.gd"),
	"--roster": preload("res://tests/roster_driver.gd"),
	"--actuator": preload("res://tests/actuator_driver.gd"),
	"--constraints": preload("res://tests/constraint_driver.gd"),
	"--archive": preload("res://tests/archive_driver.gd"),
	"--consumable": preload("res://tests/consumable_driver.gd"),
	"--consumable-live": preload("res://tests/consumable_live_driver.gd"),
	"--encounter": preload("res://tests/encounter_driver.gd"),
	"--mass-class": preload("res://tests/mass_class_driver.gd"),
	"--railway-shots": preload("res://tests/railway_shot_driver.gd"),
}

func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	for flag: String in DRIVERS:
		if flag in user_args:
			headless_test = true
			add_child((DRIVERS[flag] as GDScript).new())
			return
	# THE RAILWAY, for an operator who asks for it by name (0.4, M1).
	#
	# BEFORE `boot()` AND INSTEAD OF IT: the scenario is not a Zone, has
	# no campaign and opens no bridge connection, so there is nothing for
	# the menu, the snapshot or the save to be about. Like the Stage 3A
	# showcase it is scaffolding, and like that one it cannot be reached
	# without the flag.
	if "--railway" in user_args:
		var yard := RailwayScenario.new()
		# `--bracing` selects the SECOND binding instead of the
		# first: the span is held by a clamp the base kit can shoot
		# rather than by a control the hookshot has to reach. They
		# are alternatives, never both -- a yard with both would be
		# a yard where the acquisition branch is optional.
		yard.binding = RailwayScenario.BRACING_BINDING \
				if "--bracing" in user_args \
				else RailwayScenario.GANTRY_BINDING
		add_child(yard)
		return
	# EX50-011 PASSING PLATFORMS (0.4, M3), by name and only by name, for
	# the reasons above: a minor situation, not a Zone, no campaign, no
	# bridge connection.
	if "--passing-platforms" in user_args:
		var room := PassingPlatforms.new()
		# `--parted` is the specification's own counterexample: the same
		# room with `H`'s track shifted so no overlap exists. A commanded
		# timing that reports success in BOTH was measuring its own
		# commands rather than the world.
		room.parted = "--parted" in user_args
		add_child(room)
		return
	# EX50-021 COUNTERFIRE ARCADE (0.4, M3), by name and only by name.
	if "--counterfire" in user_args:
		var arcade := CounterfireArcade.new()
		# `--blocked` is the specification's counterpart: a real blocker
		# between the muzzle and the receiver. The shutter must not open.
		arcade.blocked = "--blocked" in user_args
		add_child(arcade)
		return
	# EX50-033 UNWEIGHTED SWITCH (0.4, M3), by name and only by name.
	if "--unweighted" in user_args:
		var switch := UnweightedSwitch.new()
		# `--disconnected` is §11's control: the plate's output is not
		# wired to the shutter. A suite that only ever watched the
		# shutter open would pass on a room where the plate did nothing,
		# so the expected response has to be shown FAILING when the one
		# link is cut.
		switch.disconnected = "--disconnected" in user_args
		add_child(switch)
		return
	boot()
	# THE STAGE 3A SHOWCASE, and only when an operator asks for it by
	# name. Without `--playtest3a` this branch does nothing at all and
	# startup is byte-for-byte what it was: the menu, the bridge, the
	# ordinary campaign. The showcase is scaffolding (Road to Playable
	# 0.3, R2) and must never be something a player arrives in by
	# accident.
	var asked := MovementSelection.from_cmdline()
	# THE OPERATOR'S MOVEMENT PACKAGE, for EVERY Zone this run enters
	# (Stage 3B). In 3A this was held for the showcase alone and
	# deliberately not inherited by an ordinary Zone, which made the
	# movement work provable only against four hand-picked rooms. A
	# normally generated Zone now honours the same flag, so what the
	# suite exercises is the shipping composition path.
	#
	# A REFUSED VALUE IS NEVER APPLIED and never quietly becomes `none`:
	# it is reported and the package stays at the default, so an
	# operator who mistyped `--movement-package=rial` learns that from
	# the log rather than from a green run that built nothing.
	if bool(asked["refused"]):
		Telemetry.refused_selection(str(asked["why"]))
	else:
		_movement_package = str(asked["mode"])
	# THE AMALGAM'S FIRST SLICE, and only when an operator asks. Without
	# `--slice1` nothing below runs and an ordinary campaign is
	# untouched; with it, the composed Zone is decorated with one valid
	# multi-door assignment so the slice can be walked rather than only
	# asserted.
	_slice1 = Slice1Fixture.FLAG in user_args
	if _slice1:
		print("slice1: the composed Zone will be decorated with a "
				+ "three-door junction, a red lock and a return plug")
	if bool(asked["showcase"]):
		_enter_showcase(asked)
	# THE TWO-PROCESS RELOAD PROOF, and only when an operator asks.
	#
	# Unlike every other driver, this one runs AFTER `boot()` and beside
	# the real `Main` rather than instead of it -- because what it is
	# testing is `Main`. A driver that replaced the boot could not have
	# caught the thing this exists for: `_to_zone` reading in-memory
	# dictionaries that a new process cannot have.
	var phase := ReloadDriver.phase_from_cmdline()
	if phase != "":
		var reload_driver := ReloadDriver.new()
		reload_driver.main = self
		add_child(reload_driver)

## Enter the curated Stage 3A showcase.
##
## A REFUSED SELECTION STOPS HERE. An unknown `--movement-package` value
## is not a reason to pick one: it is reported and the showcase does not
## open, because a typo that quietly became `none` would produce a green
## run that proved nothing about movement at all.
##
## Everything past the refusal is the REAL path -- the same
## `ZoneController` and the same `_to_zone` an ordinary Zone takes, so
## what this proves is the runtime rather than a harness beside it.
func _enter_showcase(asked: Dictionary) -> void:
	if bool(asked["refused"]):
		# Already reported by the caller. The showcase additionally does
		# not OPEN, because a showcase that proved nothing about
		# movement is worse than no showcase.
		return
	Telemetry.showcase(ShowcaseZone.ZONE_ID, _movement_package,
			ShowcaseZone.shell_ids())
	_to_zone(ShowcaseZone.build())

## The movement package every Zone this run builds (Stage 3B, R6/R7).
##
## An operator control and nothing more: not an Archipelago item, not
## progression, not saved, not part of the Zone schema. Default `none`,
## so a run started without the flag constructs no movement geometry and
## behaves exactly as it did before Stage 3A.
var _movement_package := MovementSelection.DEFAULT_MODE
## `--slice1` decorates the composed Zone with one multi-door
## assignment so the Amalgam's first slice can be WALKED. Off unless an
## operator asks, so an ordinary run is untouched.
var _slice1 := false
## WHAT A ZONE RESUMES TO, kept per Zone for the life of the session.
##
## §30.12.4 says a player may SAVE at a warp station, and §30.12.2 makes
## reached-ness progress that survives a Hub return. The bridge owns that
## persistence -- `ZoneProgress` on the Zone record -- and does not carry
## it yet, so this holds the same two facts in memory: which station a
## Zone resumes at, and which of its stations are already online.
##
## **In memory only, and deliberately.** It survives a Hub return and a
## re-entry, which is what the feature is for; it does not survive
## quitting, and nothing here pretends it does. When `ZoneProgress`
## lands, this is what it replaces.
var _zone_resume := {}
var _zone_stations := {}
var _zone_keys := {}
var _zone_locks_open := {}
var _zone_latches := {}

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
	station_panel = StationPanel.new()
	add_child(station_panel)
	debug = DebugOverlay.new()
	add_child(debug)
	nav = NavSchematic.new()
	add_child(nav)

	menu.connect_pressed.connect(_on_menu_connect)
	menu.mock_pressed.connect(_on_menu_mock)
	reveal.reveal_started.connect(_update_modal)
	reveal.reveal_finished.connect(_update_modal)
	inventory.closed.connect(_update_modal)
	shop.closed.connect(_update_modal)
	station_panel.closed.connect(_update_modal)
	station_panel.warp_chosen.connect(_on_station_warp_chosen)
	# THE ONE OPTION WITH SEMANTICS ALREADY BEHIND IT. The pause menu's
	# own Return to Hub is this same handler: `leave_zone` after the
	# resume anchor, keys, locks and reached stations are remembered, so
	# the Zone goes DORMANT and the portal offers it back. Nothing new
	# is invented here and `abandon_zone` is not reachable from a
	# station.
	station_panel.return_to_hub_chosen.connect(_on_return_to_hub)
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
	_refresh_nav()
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
	# A PANEL CANNOT OUTLIVE THE ZONE IT BELONGS TO. A travel panel left
	# open across a teardown would sit over the Hub offering warps into a
	# controller that no longer exists, and its Return to Hub would send
	# a second `leave_zone`.
	if station_panel != null:
		station_panel.close()
	for child in world.get_children():
		# OUT OF THE TREE NOW, not at the end of the frame.
		#
		# `queue_free` is deferred: the old world's colliders stay
		# registered with the physics server until the frame ends, and
		# the new one is built AND MEASURED before that. Both worlds are
		# built around the origin, so the Hub's floor stood in the hall's
		# entry doorway and `_measure_layout_evidence` reported
		# `c002/entry` solid -- the bridge refused the layout, three
		# times over, and the Zone never opened.
		#
		# `remove_child` is immediate and unregisters the colliders;
		# `queue_free` still runs, so nothing leaks.
		world.remove_child(child)
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
	# WHICH ZONE, from the Hub rather than from `active_zone`.
	#
	# A DORMANT Zone is not the active one -- `active_zone_id` is cleared
	# when the player walks out -- so reading `active_zone()` returned
	# nothing and this returned early, which is why there was no way back
	# into a Zone you had left. `resume_zone_id` is the bridge saying
	# which Zone the portal leads to, in every mode that has one.
	var zid := str(BridgeClient.hub().get("resume_zone_id", ""))
	if zid == "":
		zid = str(BridgeClient.active_zone().get("zone_id", ""))
	if zid == "":
		return
	# AND NOT BACK INTO THE ONE THAT CANNOT BE BUILT.
	#
	# `AMALGAM_BRIDGE.md` §5.7a defect 1. The Hub's portal already
	# refuses to offer this, and this is the second lock: an
	# `enter_zone` that arrives from anywhere else -- a stale prompt, a
	# queued input, a driver -- must not restart the refusal loop the
	# owner's decision closes.
	if BridgeClient.hub_mode() == "ZONE_FAILED" \
			or zid == HubController.discard_target():
		hud.toast("That Zone cannot be built. Discard it at the console.",
				Color(0.9, 0.5, 0.3))
		return
	_entering_zone = true
	BridgeClient.send_intent({"type": "enter_zone", "zone_id": zid})

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
	# BEFORE `setup`, because the offer stage is deferred from inside it.
	# `none` unless an operator asked for a package on the command line,
	# so a run started without the flag constructs no movement geometry
	# and behaves exactly as it did before Stage 3A.
	zone.movement_package = _movement_package
	world.add_child(zone)
	# Before setup, so a Zone whose first frame already spends something
	# sees full channels rather than last Zone's leftovers. The rule
	# engine resets with it: its latches, cooldowns and watched values are
	# derived from exactly the state I9 is clearing, so a latch left armed
	# fired on the next Zone's first tick against a threshold that no
	# longer existed.
	resource_pool.reset_for_zone()
	rule_runtime.reset_for_zone()
	# The slice's assignment goes on HERE, at the last moment before the
	# Zone is built, so nothing upstream -- the bridge, the save, the
	# manifest -- ever sees a decorated Zone.
	# WHERE THIS ZONE RESUMES, if it has been left and re-entered.
	# Empty on a first entry, which is every Zone before a station is
	# reached, so nothing changes for a Zone nobody has left.
	var zid := str(record.get("zone_id", ""))
	# FROM THE BRIDGE FIRST, because the bridge is what survives quitting.
	#
	# These four came only from the in-memory dictionaries below, which
	# is why the docstring on `_zone_resume` says "it does not survive
	# quitting, and nothing here pretends it does". `ZoneProgress` landed
	# and has been persisted on every `key_collected`, `lock_opened` and
	# `station_reached` since -- the save held the progress and the game
	# read past it, so relaunching put the player back in front of a lock
	# they had already opened with a key that was no longer there to
	# collect.
	#
	# UNION, not replacement. The dictionaries stay as the in-flight
	# half: an intent sent in the same breath as leaving may not be in
	# the snapshot yet, and both sides are monotone sets, so taking both
	# cannot lose progress and cannot invent it.
	var progress: Dictionary = record.get("progress", {}) \
			if typeof(record.get("progress")) == TYPE_DICTIONARY else {}
	var saved_resume := str(progress.get("resume_anchor", "")) \
			if progress.get("resume_anchor") != null else ""
	zone.resume_anchor = str(_zone_resume.get(zid, saved_resume))
	zone.stations_online = _union_progress(
			progress.get("reached_stations", []), _zone_stations.get(zid, {}))
	zone.keys_carried = _union_progress(
			progress.get("collected_keys", []), _zone_keys.get(zid, {}))
	zone.locks_carried = _union_progress(
			progress.get("opened_locks", []), _zone_locks_open.get(zid, {}))
	# LATCHES, read back the same way. What persists is the accepted
	# consequence; a machine recomputes what it implies when it is built
	# and nothing about the mechanism's own state is saved (§5.4a).
	zone.latches_carried = _union_progress(
			progress.get("latched", []), _zone_latches.get(zid, {}))
	# THE COMMITTED LAYOUT, when this Zone has one. `ZoneReady` carries
	# the manifest the bridge accepted on the first visit, and replaying
	# it is what makes the Zone the player walks back into the Zone they
	# walked out of rather than a second one that happens to be similar.
	var committed: Variant = record.get("manifest")
	zone.committed_manifest = committed \
			if typeof(committed) == TYPE_DICTIONARY else {}
	zone.setup(Slice1Fixture.decorate(zone_dict) if _slice1 else zone_dict)
	# A ZONE THAT COULD NOT BE BUILT HAS NO PLAYER, and every line below
	# this one assumes there is one.
	#
	# `ZoneController.setup` returns early when `ZoneBuilder` cannot
	# route the rooms -- correctly, because entering a level whose Check
	# is inside a wall is worse than not entering it -- and this
	# function carried straight on into `hud.bind_player(zone.player)`
	# and four `zone.player.<signal>.connect` calls against a null. The
	# first of those is where the run died, halfway through a handoff,
	# with the Hub already torn down by `_clear_world` and the failed
	# Zone still in the tree.
	#
	# `layout_failed` is the controller's own report and is set before
	# it returns, so this is the same fact the suites read rather than a
	# second flag that could disagree with it.
	if zone.layout_failed != "":
		# `zone.zone_id` AND NOT `zid`: the controller took its id from
		# the content it was handed, which is the Zone that actually
		# failed, while `zid` comes off the bridge record and is empty
		# on any path that builds a Zone without one.
		_on_build_failed(zone.zone_id, zone.layout_failed)
		return
	zone.exit_requested.connect(_on_exit_zone)
	zone.layout_refused.connect(_on_layout_refused)
	zone.travel_panel_requested.connect(_on_travel_panel_requested)
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

## THE LAYOUT WAS REFUSED, SO THE ZONE IS NOT PLAYABLE.
##
## The bridge has already moved it to DORMANT and stopped it being the
## active Zone, so nothing the player does in it can reach the campaign.
## Standing in it is the only thing left, and standing in a Zone whose
## geometry the validator just rejected is how a player ends up inside a
## wall. Back to the Hub, with the Checks still allocated to that Zone.
func _on_layout_refused(refused_id: String) -> void:
	if view != View.ZONE or zone == null or zone.zone_id != refused_id:
		return
	push_warning("main: leaving '%s'; its layout was refused"
			% refused_id)
	if hud != null:
		hud.toast("LAYOUT REFUSED — RETURNING TO HUB",
				Color(0.95, 0.5, 0.45), 4.0)
	_remember_zone_progress()
	_to_hub()

## THE ENGINE COULD NOT BUILD IT. Back to a Hub that still works.
##
## Distinct from `_on_layout_refused`, which is the bridge rejecting
## geometry the engine DID build, and distinct again from a
## generation-stage rejection, which never reaches a client at all. Here
## there is no level and no player: the only thing to do is say so and
## put the player somewhere they can act.
##
## `ZoneController.setup` has already told the bridge (`build_failed`),
## so the recovery -- compose this proposal again inside its budget, or
## park it and offer ABANDON once the budget is spent -- is running
## while this returns to the Hub. Nothing is sent from here; two reports
## of one failure would charge the attempt twice.
##
## AND NOTHING IS REMEMBERED. `_remember_zone_progress` copies the
## controller's RUNTIME dictionaries over the in-memory ones, and on a
## failed setup those are empty -- so calling it here would overwrite a
## revisited Zone's stations, keys and opened locks with nothing. The
## save is the truth for a Zone that was never entered.
func _on_build_failed(failed_id: String, reason: String) -> void:
	push_warning("main: '%s' could not be built -- %s" % [failed_id, reason])
	if hud != null:
		hud.toast("ZONE COULD NOT BE BUILT — RETURNING TO HUB",
				Color(0.95, 0.5, 0.45), 4.0)
	# The entry that was in flight is over, however it ended. The
	# snapshot path already clears this before it calls `_to_zone`, so
	# this is belt and braces for the other callers rather than a fix --
	# what matters is that the flag cannot be left set by a path that
	# ends here, because the recomposed Zone arrives as another
	# ZONE_ACTIVE and that branch is what would walk the player back in
	# without asking.
	_entering_zone = false
	_to_hub()

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

## A station asked for a destination. The panel renders what the
## controller says is eligible and decides nothing itself.
func _on_travel_panel_requested(from_id: String, from_label: String,
		options: Array) -> void:
	if view != View.ZONE:
		return
	station_panel.open(from_id, from_label, options)
	_update_modal()

## ONE WARP, and only into the Zone that asked. A panel left open across
## a Zone teardown would otherwise send a choice to a freed controller.
func _on_station_warp_chosen(from_id: String, to_id: String) -> void:
	if view == View.ZONE and zone != null and is_instance_valid(zone):
		zone.warp_to(from_id, to_id)
	_update_modal()

func _on_return_to_hub() -> void:
	station_panel.close()
	pause_menu.close()
	if view == View.ZONE:
		_send_zone_timing(false)
		_remember_zone_progress()
		BridgeClient.send_intent({"type": "leave_zone",
				"zone_id": zone.zone_id})
		_to_hub()

## Carry the resume point and the online stations out of a Zone.
##
## Read from the controller rather than pushed to it, so a Zone plays
## identically whether or not anything is remembering.
## The saved list and the in-flight dictionary, as one set.
##
## `ZoneController` asks these `has()`, so the shape is a set keyed by id
## and the value is only ever `true`.
static func _union_progress(saved: Variant, held: Variant) -> Dictionary:
	var out := {}
	if typeof(saved) == TYPE_ARRAY:
		for entry: Variant in saved as Array:
			out[str(entry)] = true
	if typeof(held) == TYPE_DICTIONARY:
		for entry: Variant in (held as Dictionary):
			out[str(entry)] = true
	return out


func _remember_zone_progress() -> void:
	if zone == null or zone.zone_id == "":
		return
	_zone_resume[zone.zone_id] = zone.resume_anchor
	_zone_stations[zone.zone_id] = zone.stations_reached()
	_zone_keys[zone.zone_id] = zone.keys_held()
	_zone_locks_open[zone.zone_id] = zone.locks_opened()
	_zone_latches[zone.zone_id] = zone.latches_fired()

func _on_abandon() -> void:
	pause_menu.close()
	if view == View.ZONE:
		_abandoning = true
		_send_zone_timing(false)
		BridgeClient.send_intent({"type": "abandon_zone",
				"zone_id": zone.zone_id})

## F4: name every activity, or stop naming them.
##
## ON by default. The graybox silhouettes are meant to carry family
## identity by themselves, so a label that could not be turned off would
## make "can you tell these apart" a question nobody could answer again
## -- but a playtester who cannot tell a pressure pad from a floor tile
## is not testing the mechanics, they are testing the placeholder.
func _toggle_activity_labels() -> void:
	ActivityRuntime.labels_visible = not ActivityRuntime.labels_visible
	for runtime in get_tree().get_nodes_in_group(ActivityRuntime.GROUP):
		(runtime as ActivityRuntime).set_labels_visible(
				ActivityRuntime.labels_visible)
	hud.toast("Activity labels %s"
			% ("ON" if ActivityRuntime.labels_visible else "OFF"),
			Color(0.85, 0.88, 0.92))

# -- global input -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		debug.toggle()
	if event.is_action_pressed("activity_labels"):
		_toggle_activity_labels()
	if event.is_action_pressed("nav_schematic"):
		nav.toggle()
		_refresh_nav()
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

## WHILE IT IS OPEN, and only then.
##
## `_on_snapshot` refreshes it too, but a snapshot arrives when the
## BRIDGE has something to say -- so walking from one room to the next
## would not have moved the "you are here" dot until something else
## happened. The panel is a prototype somebody holds open and walks
## around with; it has to keep up with the walking.
func _process(_delta: float) -> void:
	if nav != null and nav.visible:
		_refresh_nav()

## Hand the schematic the facts it draws. Read, never stored: every one
## of these is owned by `ZoneController` and this takes a copy for one
## frame of drawing.
func _refresh_nav() -> void:
	if nav == null or not nav.visible:
		return
	if view != View.ZONE or zone == null or not is_instance_valid(zone):
		nav.show_zone({}, {}, [], {}, {}, "")
		return
	nav.show_zone(zone.rooms_entered(), zone.room_bounds,
			zone.zone.get("edges", []), zone.gates_not_yet_open(),
			zone.stations_reached(), zone.current_room())

func _update_modal() -> void:
	var modal: bool = pause_menu.visible or inventory.visible \
			or shop.visible or reveal.visible or station_panel.visible
	var player: Player = null
	if hub != null:
		player = hub.player
	elif zone != null:
		player = zone.player
	if player != null:
		# A NAMED CLAIM, not the boolean. `player.input_frozen = modal`
		# cleared an acceptance hold every time the inventory closed.
		if modal:
			player.hold("modal")
		else:
			player.release("modal")
	hud.set_crosshair_visible(not modal)
	if view == View.MENU or pause_menu.visible or inventory.visible \
			or shop.visible or station_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
