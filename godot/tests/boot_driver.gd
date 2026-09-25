extends Node
## Does the game actually start? (`make godot-boot`)
##
## The suite that should have existed. On 2026-08-27 a refactor deleted
## the five lines of `main.gd` that create the world and the sound bank,
## and Archipepsi could not enter the Hub for a day: `_clear_world()` is
## the first thing every view transition calls, and it dereferenced null.
##
## Nine headless suites, a whole-campaign integration run and two CI
## tiers were green throughout. All of them are DRIVERS, and every driver
## takes the dispatch branch in `_ready` and returns before the real
## setup — then builds its own world. So the one thing nothing checked
## was the thing a player does first.
##
## This calls `Main.boot()`, the real function, and then drives the
## transition that crashed.

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var main := get_parent()
	_check(main != null and main.has_method("boot"),
			"main.gd has no boot(); the real startup path is gone again")
	if main == null or not main.has_method("boot"):
		_finish()
		return

	main.call("boot")
	await get_tree().process_frame

	# Everything a view transition dereferences without checking.
	for field: String in ["world", "tones", "menu", "hud", "resource_pool",
			"rule_runtime", "reveal", "inventory", "shop", "pause_menu",
			"menu_shell", "debug", "station_panel", "nav"]:
		_check(main.get(field) != null,
				"boot() left '%s' null; anything that touches it crashes "
				% field + "on the first transition")

	# EVERYTHING below dereferences the world, so it is all behind one
	# guard. Without it this driver HANGS instead of failing: the error
	# is raised in here, `_finish` is never reached, and Godot never
	# quits. A CI job that times out tells you far less than one that
	# names the field that was null -- and the first version of this
	# file made exactly that mistake, two lines after asserting the
	# world exists. The sabotage run found it.
	if main.get("world") == null:
		_check(false, "no world, so the transition below cannot even be "
				+ "attempted -- this IS the crash the suite exists for")
		_finish()
		return

	_check((main.get("world") as Node3D).name == "World",
			"the world node lost its name")

	# The exact call that crashed: `_clear_world` runs before every Hub
	# and Zone entry, so a null world is not a latent bug, it is the
	# first thing the player hits.
	main.call("_clear_world")
	_check(true, "_clear_world survived a boot")

	await _the_menu_is_actually_on_screen(main)
	await _every_panel_opens_in_the_middle()
	await _the_real_consumer_handles_an_exit(main)
	await _the_travel_panel_reaches_the_real_consumers(main)
	_finish()

## THE EXIT, HANDLED BY THE CONSUMER THAT ACTUALLY HANDLES IT.
##
## `integration_driver` takes the real portal and proves the player
## survives the teardown, which is where the playtest crash lived. What
## it cannot do is run `main.gd::_on_exit_zone`: a driver is added as a
## child of `Main` and `Main` returns BEFORE `boot()`, so `menu`, `hud`
## and `world` are null and `_to_hub()` would dereference all three.
##
## This file is the one that boots for real, so this is where the
## consumer half belongs -- wired the way `main.gd` wires it, fired the
## way the portal fires it, and asked what the player is left holding.
func _the_real_consumer_handles_an_exit(main: Node) -> void:
	var zone := ZoneController.new()
	zone.zone_id = "zone_boot_probe"
	(main.get("world") as Node3D).add_child(zone)
	main.set("zone", zone)
	main.set("view", 2)                     # View.ZONE
	# EXACTLY main.gd's wiring, not a call to the handler.
	zone.exit_requested.connect(Callable(main, "_on_exit_zone"))
	await get_tree().process_frame
	zone.exit_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	_check(int(main.get("view")) == 1,
			"taking the exit leaves the player in the HUB view (view %d)"
			% int(main.get("view")))
	var hub: Variant = main.get("hub")
	_check(hub != null and is_instance_valid(hub as Object),
			"and a Hub exists to have arrived in")
	_check((main.get("hud") as CanvasLayer).visible,
			"and the HUD is on")
	# CONTINUED USABILITY: the Hub the player landed in can start the
	# next Zone. A transition that arrives somewhere inert is not an
	# arrival.
	if hub != null and is_instance_valid(hub as Object):
		_check((hub as Node).has_signal("enter_zone_requested")
				and (hub as Node).is_connected("enter_zone_requested",
					Callable(main, "_on_enter_zone")),
				"and asking that Hub for another Zone reaches main.gd, "
				+ "so the campaign can continue")
	_check(not is_instance_valid(zone)
			or not (zone as Node).is_inside_tree(),
			"and the Zone that was exited is gone from the world")

## THE STATION PANEL, THROUGH main.gd's OWN WIRING.
##
## `godot-hud` drives the panel itself; this is the other half, and the
## half a panel actually breaks in: does the changed interface still
## reach the consumers that were already there. Nothing here calls a
## handler by name that `main.gd` does not connect -- the signals are
## connected exactly as `_to_zone` connects them, so a rename or a
## dropped connection fails here rather than in somebody's session.
func _the_travel_panel_reaches_the_real_consumers(main: Node) -> void:
	var panel: CanvasLayer = main.get("station_panel")
	if panel == null:
		return
	var zone := ZoneController.new()
	zone.zone_id = "zone_panel_probe"
	(main.get("world") as Node3D).add_child(zone)
	main.set("zone", zone)
	main.set("view", 2)                     # View.ZONE
	zone.travel_panel_requested.connect(
			Callable(main, "_on_travel_panel_requested"))
	panel.warp_chosen.connect(Callable(main, "_on_station_warp_chosen"))
	panel.return_to_hub_chosen.connect(Callable(main, "_on_return_to_hub"))
	panel.closed.connect(Callable(main, "_update_modal"))
	await get_tree().process_frame

	# 1. A STATION ASKING REACHES THE SCREEN, and moves nobody.
	zone.travel_panel_requested.emit("st:entrance", "ENTRANCE", [
		{"id": "st:entrance", "label": "ENTRANCE", "here": true},
		{"id": "st:hall", "label": "HALL", "here": false}])
	await get_tree().process_frame
	_check(panel.visible,
			"a station asking for a destination opens the panel through "
			+ "main.gd's own wiring")
	_check(int(main.get("view")) == 2,
			"and opening it does not leave the Zone (view %d)"
			% int(main.get("view")))

	# 2. IT HOLDS THE PLAYER, through the same named modal claim every
	#    other panel uses -- so it cannot release somebody else's.
	var body: Player = zone.player
	if body != null:
		_check(body.input_frozen,
				"and the open panel holds the player (holds %s)"
				% str(body.holds()))
		body.hold("probe")
		panel.close()
		await get_tree().process_frame
		_check(body.holds().has("probe"),
				"and closing it releases only its OWN claim: another "
				+ "holder's claim survives (holds %s)" % str(body.holds()))
		body.release("probe")
		await get_tree().process_frame

	# 3. A CHOICE REACHES THE ZONE, once.
	var moved: Array[String] = []
	zone.station_warped.connect(
			func(f: String, t: String) -> void: moved.append(f + "->" + t))
	panel.open("st:entrance", "ENTRANCE", [
		{"id": "st:entrance", "label": "ENTRANCE", "here": true},
		{"id": "st:hall", "label": "HALL", "here": false}])
	panel._choose("st:hall")
	await get_tree().process_frame
	_check(moved.size() == 1,
			"a destination chosen on the panel reaches the Zone's warp "
			+ "once (%s)" % str(moved))

	# 4. AND A CHOICE AFTER THE ZONE IS GONE REACHES NOTHING. A panel
	#    that outlived its Zone would hand a stale warp to a freed
	#    controller.
	moved.clear()
	main.set("view", 1)                     # View.HUB
	panel.open("st:entrance", "ENTRANCE", [
		{"id": "st:hall", "label": "HALL", "here": false}])
	panel._choose("st:hall")
	await get_tree().process_frame
	_check(moved.is_empty(),
			"and a choice made after the Zone is left warps nobody (%s)"
			% str(moved))

	# 5. RETURN TO HUB IS THE PAUSE MENU'S OWN HANDLER. Same function,
	#    so the resume path it already had is the resume path this has:
	#    `leave_zone`, never `abandon_zone`.
	main.set("view", 2)
	BridgeClient.sent_intents.clear()
	panel.open("st:entrance", "ENTRANCE", [
		{"id": "st:entrance", "label": "ENTRANCE", "here": true}])
	panel._go_home()
	await get_tree().process_frame
	await get_tree().process_frame
	var kinds: Array[String] = []
	for raw: Variant in BridgeClient.sent_intents:
		kinds.append(str((raw as Dictionary).get("type", "")))
	_check(kinds.has("leave_zone"),
			"Return to Hub sends `leave_zone`, which is what keeps the "
			+ "Zone where it is (%s)" % str(kinds))
	_check(not kinds.has("abandon_zone"),
			"and never `abandon_zone`, which would throw it away (%s)"
			% str(kinds))
	_check(int(main.get("view")) == 1,
			"and it arrives in the Hub (view %d)" % int(main.get("view")))
	_check(not panel.visible,
			"and the panel is closed behind it")
	if is_instance_valid(zone):
		zone.queue_free()
	await get_tree().process_frame

## The other thing nine green suites never checked: WHERE a control
## lands. The title screen shipped with its panel anchored so that its
## top-left corner sat at the screen centre -- it grew down and right and
## pushed QUIT off the bottom edge. Every test passed, because no test
## had ever looked at a rect.
func _the_menu_is_actually_on_screen(main: Node) -> void:
	var menu: CanvasLayer = main.get("menu")
	_check(menu != null, "there is no menu to look at")
	if menu == null:
		return
	# Headless defaults to a 64x64 viewport, on which nothing fits and
	# the check would be meaningless. Ask for a real window first.
	get_window().size = Vector2i(1280, 720)
	menu.visible = true
	await get_tree().process_frame
	await get_tree().process_frame

	var screen := Vector2(get_viewport().get_visible_rect().size)
	var panel: Control = null
	for node in menu.find_children("*", "PanelContainer", true, false):
		panel = node
		break
	_check(panel != null, "the menu has no panel")
	if panel == null:
		return

	var rect := Rect2(panel.global_position, panel.size)
	_check(rect.position.x >= -1.0 and rect.position.y >= -1.0,
			"the menu starts off-screen at %s" % rect.position)
	_check(rect.end.x <= screen.x + 1.0 and rect.end.y <= screen.y + 1.0,
			"the menu runs off the screen: it ends at %s on a %s viewport "
			% [rect.end, screen] + "-- the bottom buttons are unreachable")

	# And it must be CENTRED, not merely on-screen. The bug put the panel
	# entirely inside the viewport on a big enough window while still
	# being visibly wrong, so "fits" is not the property that matters.
	var centre_offset := (rect.position + rect.size / 2.0) - screen / 2.0
	_check(absf(centre_offset.x) < 2.0 and absf(centre_offset.y) < 2.0,
			"the menu is %s away from the centre of the screen"
			% centre_offset)

func _finish() -> void:
	if failures == 0:
		print("GODOT BOOT TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT BOOT TESTS: %d failures" % failures)
		get_tree().quit(1)

## Playtest 1, twice. `PRESET_CENTER` puts a control's TOP-LEFT CORNER at
## the screen centre and lets it grow down and right, so six panels
## shipped wedged into the bottom-right quadrant: the title screen, the
## pause menu, the shop, the Echo archive, the reveal card and the death
## label. Fixing the title screen alone left five, because the bug is a
## misreading of an engine preset rather than a mistake in one file.
##
## Each is opened for real and measured. A panel is not centred because
## the code says CENTER; it is centred when its rect is.
func _every_panel_opens_in_the_middle() -> void:
	get_window().size = Vector2i(1280, 720)
	var screen := Vector2(get_window().size)
	var panels := {
		"pause menu": PauseMenu.new(),
		"shop": ShopUI.new(),
		"Echo archive": InventoryLayer.new(),
	}
	for label: String in panels:
		var ui: CanvasLayer = panels[label]
		add_child(ui)
		await get_tree().process_frame
		ui.visible = true
		await get_tree().process_frame
		await get_tree().process_frame
		var panel := _first_panel(ui)
		if panel == null:
			_check(false, "%s has no panel to measure" % label)
			continue
		var rect := panel.get_global_rect()
		_check(rect.size.x > 1.0 and rect.size.y > 1.0,
				"%s laid out to nothing (%s), so the centring check "
				% [label, rect.size] + "below would pass vacuously")
		var offset := (rect.position + rect.size / 2.0) - screen / 2.0
		_check(absf(offset.x) < 2.0 and absf(offset.y) < 2.0,
				"the %s opens %s off centre -- rect %s on a %s screen"
				% [label, offset, rect, screen])

		# A panel you READ has to be opaque. Godot's default
		# PanelContainer theme is translucent, so a panel that does not
		# say otherwise has the game showing through its own small grey
		# text. Only the reveal card ever set a background; the two
		# panels full of text did not. Same shape as the centring bug --
		# one wrong default, copied everywhere it mattered.
		var style := panel.get_theme_stylebox("panel")
		var flat := style as StyleBoxFlat
		_check(flat != null,
				"the %s has no StyleBoxFlat, so it is on Godot's " % label
				+ "translucent default and the world shows through it")
		if flat != null:
			_check(flat.bg_color.a > 0.9,
					"the %s is %.2f opaque; its text is unreadable "
					% [label, flat.bg_color.a] + "against a bright wall")

		# And nothing inside may be wider than the panel. A
		# ScrollContainer with horizontal overflow hands the mouse wheel
		# to the horizontal bar, so the wheel pans sideways and the list
		# cannot be scrolled down at all.
		for scroll in _scrolls_under(ui):
			_check(scroll.horizontal_scroll_mode
					== ScrollContainer.SCROLL_MODE_DISABLED,
					("the %s can scroll sideways; content wider than "
					+ "the panel takes the mouse wheel and the list "
					+ "stops scrolling down") % label)
		ui.queue_free()

func _scrolls_under(node: Node) -> Array[ScrollContainer]:
	var out: Array[ScrollContainer] = []
	if node is ScrollContainer:
		out.append(node as ScrollContainer)
	for child in node.get_children():
		out.append_array(_scrolls_under(child))
	return out

func _first_panel(node: Node) -> Control:
	if node is PanelContainer:
		return node as Control
	for child in node.get_children():
		var found := _first_panel(child)
		if found != null:
			return found
	return null
