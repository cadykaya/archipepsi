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
			"debug"]:
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
	_finish()

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
