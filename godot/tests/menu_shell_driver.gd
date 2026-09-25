extends Node
## H-3D-SHELL (CP3, V-18) — THE PAUSE INTERFACE IN REAL 3D (`--menu-shell`).
##
##     make godot-menu-shell      headless: the box, the order, the input
##     make menu-shell-shots      xvfb + OpenGL: what it actually draws
##
## The packet's bar is "scene transforms plus actual interacted render; not
## flat tab squeeze". So this asks, of a real `MenuShell` with probes on
## its pages:
##   the box        four walls in the box's own `World3D`, each the same
##                  distance from the camera and facing it, the camera at
##                  the centre;
##   the order      turning left visits Settings, Equipment, Map, Journal
##                  and Settings again; right reverses it; by the on-screen
##                  arrows and by the bound keys;
##   a turn         the camera's yaw moves monotonically through the
##                  quarter turn, no wall moves or scales, and midway two
##                  walls are in view;
##   at rest        the front wall faces the camera squarely and fills the
##                  share of the view it is meant to;
##   the pointer    a click where a page's button is drawn presses THAT
##                  button: on the front wall only, never mid-turn;
##   the keys       a focused text field keeps Q and E; Tab turns to
##                  Equipment and closes from it; Escape closes;
##   reduced motion a cut, the same walls in the same order.
##   the world stops (H-PAUSE)  a pausable node, a falling body and a
##                  pause-aware timer all stand still while it is open,
##                  and run on when it closes; it still turns meanwhile;
##                  and closing it releases only its own claim.
##
## Every click and key here is an `InputEvent` parsed into the engine the
## way a device's is; nothing calls a button's handler directly.

const SHOTS_FLAG := "--shots="

var _failures := 0
var _checks := 0
var _notes := 0
var shell: MenuShell = null
var pressed := {}
## Set by a pause-aware timer's timeout. On the node, not in a closure: a
## lambda captures a local by value.
var _timer_fired := false


## A node that counts the frames it is given.
class Ticker extends Node:
	var ticks := 0

	func _process(_delta: float) -> void:
		ticks += 1


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
	_run()


func _shots_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SHOTS_FLAG):
			return arg.substr(SHOTS_FLAG.length())
	return ""


func _run() -> void:
	await get_tree().process_frame
	# THE SCREEN THE GAME ASKS FOR. A headless window is 64 x 64 whatever
	# `project.godot` says, and at that size the arrows cover the page.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	shell = MenuShell.new()
	add_child(shell)
	await get_tree().process_frame
	_probes()
	var shots := _shots_dir()
	if shots != "":
		await _shoot(shots)
		_finish("MENU SHELL SHOTS")
		return
	await _the_box()
	await _the_order()
	await _a_turn_is_a_turn()
	await _at_rest()
	await _the_pointer()
	await _the_keys()
	await _reduced_motion()
	await _the_world_stops()
	_finish("GODOT MENU SHELL")


func _finish(what: String) -> void:
	print("")
	if _failures == 0:
		print("%s OK (%d checks, %d notes)" % [what, _checks, _notes])
		get_tree().quit(0)
		return
	print("%s TESTS: %d failures in %d checks" % [what, _failures, _checks])
	get_tree().quit(1)


## A button in the middle of the first two pages, and a text field on
## the journal, each in the same place on its page -- so the same screen
## point lands on a different one depending only on which wall is in
## front.
func _probes() -> void:
	for page: String in ["settings", "equipment", "map"]:
		pressed[page] = 0
		var probe := Button.new()
		probe.name = "Probe"
		probe.text = "PROBE -- %s" % page.to_upper()
		probe.position = Vector2(520, 300)
		probe.size = Vector2(240, 90)
		probe.pressed.connect(func() -> void: pressed[page] += 1)
		shell.page_root(page).add_child(probe)
	var field := LineEdit.new()
	field.name = "Field"
	field.position = Vector2(440, 300)
	field.size = Vector2(400, 60)
	shell.page_root("journal").add_child(field)


# ---------------------------------------------------------------------------
# The box
# ---------------------------------------------------------------------------

func _the_box() -> void:
	print("  -- the box")
	shell.open("settings")
	await _frames(2)
	var own := shell.stage().find_world_3d()
	_check(own != null and own != get_viewport().find_world_3d()
			and shell.stage().own_world_3d,
			"the box renders in its own World3D, not the dungeon's")
	_note("screen %v, stage container %v, stage viewport %v" % [
			get_viewport().get_visible_rect().size,
			(shell.stage().get_parent() as Control).size, shell.stage().size])
	var eye := shell.camera().global_position
	var wrong: Array = []
	for page: String in MenuShell.PAGES:
		var wall := shell.wall(page)
		var at := wall.global_position
		var normal := wall.global_basis.z.normalized()
		var toward := (eye - at).normalized()
		var off := absf(at.distance_to(eye) - MenuShell.DISTANCE)
		if normal.dot(toward) < 0.9999 or off > 0.0001 \
				or not wall.scale.is_equal_approx(Vector3.ONE):
			wrong.append("%s at %v facing %v" % [page, at, normal])
	_check(wrong.is_empty() and eye.length() < 0.0001,
			"four walls, each %.1f m from the camera at the centre and "
			% MenuShell.DISTANCE + "facing it squarely (wrong: %s)" % [wrong])
	var visible_pages := MenuShell.PAGES.map(func(page: String) -> Vector3:
		return shell.wall(page).global_position.snapped(Vector3.ONE * 0.01))
	_note("wall centres, in page order: %s" % [visible_pages])


# ---------------------------------------------------------------------------
# The order
# ---------------------------------------------------------------------------

func _the_order() -> void:
	print("  -- the order")
	shell.open("settings")
	await _frames(2)
	var left: Array = [shell.front()]
	for _i in 4:
		await _key(KEY_Q)
		await _rest()
		left.append(shell.front())
	_check(left == ["settings", "equipment", "map", "journal", "settings"],
			"turning LEFT (Q) visits %s" % [left])
	var right: Array = [shell.front()]
	for _i in 4:
		await _key(KEY_E)
		await _rest()
		right.append(shell.front())
	_check(right == ["settings", "journal", "map", "equipment", "settings"],
			"turning right (E) reverses it: %s" % [right])
	var by_arrow: Array = [shell.front()]
	await _click_control(shell.arrows()[0])
	await _rest()
	by_arrow.append(shell.front())
	await _click_control(shell.arrows()[1])
	await _rest()
	by_arrow.append(shell.front())
	_check(by_arrow == ["settings", "equipment", "settings"],
			"and by the large on-screen arrows, clicked: %s" % [by_arrow])


# ---------------------------------------------------------------------------
# A turn is a turn
# ---------------------------------------------------------------------------

func _a_turn_is_a_turn() -> void:
	print("  -- a turn is the camera turning, not a squeeze")
	shell.open("settings")
	await _frames(2)
	var before := {}
	for page: String in MenuShell.PAGES:
		before[page] = shell.wall(page).global_transform
	var yaws: Array = [shell.camera().rotation.y]
	var both_in_view := false
	shell.turn(1)
	# BY THE CLOCK, not by frames: a headless loop is not held to 60 Hz.
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var yaw := shell.camera().rotation.y
		yaws.append(yaw)
		if absf(yaw - PI * 0.25) < 0.2:
			both_in_view = both_in_view or (_in_view("settings")
					and _in_view("equipment"))
		if not shell.is_turning():
			break
	var monotonic := true
	for i in range(1, yaws.size()):
		if float(yaws[i]) < float(yaws[i - 1]) - 0.00001:
			monotonic = false
	var moved: Array = []
	for page: String in MenuShell.PAGES:
		if not (shell.wall(page).global_transform as Transform3D) \
				.is_equal_approx(before[page]):
			moved.append(page)
	_check(monotonic and absf(float(yaws[-1]) - PI * 0.5) < 0.0001
			and yaws.size() > 10,
			"the camera's yaw runs monotonically from 0 to 90 degrees over "
			+ "%d frames (%.2f s)" % [yaws.size() - 1,
				MenuShell.TURN_SECONDS])
	_check(moved.is_empty(),
			"no wall moved, turned or scaled while it did (moved: %s)"
			% [moved])
	_check(both_in_view,
			"and halfway round, Settings and Equipment are both in view")


func _in_view(page: String) -> bool:
	var wall := shell.wall(page)
	var cam := shell.camera()
	if cam.is_position_behind(wall.global_position):
		return false
	var at := cam.unproject_position(wall.global_position)
	var size := Vector2(shell.stage().size)
	return at.x > -size.x * 0.5 and at.x < size.x * 1.5


# ---------------------------------------------------------------------------
# At rest
# ---------------------------------------------------------------------------

func _at_rest() -> void:
	print("  -- at rest, the front wall is square and readable")
	shell.open("equipment")
	await _frames(2)
	var cam := shell.camera()
	var wall := shell.wall("equipment")
	var facing := (-cam.global_basis.z).dot(wall.global_basis.z)
	var size := shell.wall_size()
	var top := cam.unproject_position(wall.global_position
			+ Vector3.UP * size.y * 0.5)
	var bottom := cam.unproject_position(wall.global_position
			- Vector3.UP * size.y * 0.5)
	var share := absf(bottom.y - top.y) / float(shell.stage().size.y)
	_check(absf(facing + 1.0) < 0.0001
			and absf(share - MenuShell.FILL) < 0.01,
			"the front wall faces the camera squarely (%.5f) and fills "
			% facing + "%.2f of the view's height (meant: %.2f)"
			% [share, MenuShell.FILL])


# ---------------------------------------------------------------------------
# The pointer
# ---------------------------------------------------------------------------

func _the_pointer() -> void:
	print("  -- the pointer reaches the front page, and only it")
	shell.open("settings")
	await _frames(2)
	var probe := shell.page_root("settings").get_node("Probe") as Button
	var point := _screen_point_of(probe.get_rect().get_center())
	var settings_before := int(pressed["settings"])
	await _click(point)
	_check(int(pressed["settings"]) == settings_before + 1,
			"a click where Settings' button is drawn (%v) presses it"
			% point.snapped(Vector2.ONE))
	await _key(KEY_Q)
	await _rest()
	var equipment_before := int(pressed["equipment"])
	await _click(point)
	_check(int(pressed["settings"]) == settings_before + 1
			and int(pressed["equipment"]) == equipment_before + 1,
			"the same point, with Equipment in front, presses Equipment's "
			+ "button and not Settings'")
	# MID-TURN, ON THE ARRIVING WALL'S BUTTON AS IT IS DRAWN THEN. A click
	# anywhere else would press nothing anyway, and prove nothing.
	await _key(KEY_Q)
	var late := Time.get_ticks_msec() + int(MenuShell.TURN_SECONDS * 700.0)
	while shell.is_turning() and Time.get_ticks_msec() < late:
		await get_tree().process_frame
	var mid_turn := shell.is_turning()
	var map_probe := shell.page_root("map").get_node("Probe") as Button
	var drawn := _screen_point_of(map_probe.get_rect().get_center())
	var on_screen := Rect2(Vector2.ZERO, Vector2(shell.stage().size)) \
			.has_point(drawn)
	await _click(drawn)
	var none := int(pressed["equipment"]) == equipment_before + 1 \
			and int(pressed["settings"]) == settings_before + 1 \
			and int(pressed["map"]) == 0
	_check(mid_turn and on_screen and none,
			"a click in the middle of a turn, where the arriving wall's "
			+ "button is drawn at that moment (%v), presses nothing"
			% drawn.snapped(Vector2.ONE))
	await _rest()
	await _click(_screen_point_of(map_probe.get_rect().get_center()))
	_check(int(pressed["map"]) == 1,
			"and the same button, clicked once the turn has come to rest, "
			+ "is pressed")
	await _rest()
	var off := _screen_point_of(Vector2(-40.0, -40.0))
	_check(shell.page_point(off) == Vector2.INF,
			"a point off the front wall maps to no page pixel")


## Where on the screen a page pixel of the FRONT wall is drawn.
func _screen_point_of(page_pixel: Vector2) -> Vector2:
	var wall := shell.wall(shell.front())
	var size := shell.wall_size()
	var u := page_pixel.x / float(MenuShell.PAGE_PIXELS.x) - 0.5
	var v := 0.5 - page_pixel.y / float(MenuShell.PAGE_PIXELS.y)
	var world := wall.global_transform * Vector3(u * size.x, v * size.y, 0.0)
	return shell.camera().unproject_position(world)


# ---------------------------------------------------------------------------
# The keys
# ---------------------------------------------------------------------------

func _the_keys() -> void:
	print("  -- the keys")
	shell.open("journal")
	await _frames(2)
	var field := shell.page_root("journal").get_node("Field") as LineEdit
	await _click(_screen_point_of(field.get_rect().get_center()))
	var focused := shell.page_viewport("journal").gui_get_focus_owner() == field
	await _key(KEY_Q, "q")
	await _key(KEY_E, "e")
	await _frames(2)
	_check(focused and field.text == "qe" and shell.front() == "journal"
			and not shell.is_turning(),
			"a clicked text field has focus and keeps Q and E: '%s', still "
			% field.text + "on %s" % shell.front())
	field.release_focus()
	await _key(KEY_TAB)
	await _rest()
	var turned_to := shell.front()
	await _key(KEY_TAB)
	await _frames(2)
	_check(turned_to == "equipment" and not shell.is_open(),
			"Tab turns to Equipment (%s), and from Equipment it closes"
			% turned_to)
	shell.open("map")
	await _frames(2)
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check(not shell.is_open(), "Escape closes it from any wall")


# ---------------------------------------------------------------------------
# Reduced motion
# ---------------------------------------------------------------------------

func _reduced_motion() -> void:
	print("  -- reduced motion")
	var settings := PlayerSettings.shared()
	var was := settings.value("motion_intensity")
	settings.set_value("motion_intensity", 0.0)
	shell.open("settings")
	await _frames(2)
	var seen: Array = [shell.front()]
	var cuts := true
	for _i in 4:
		await _key(KEY_Q)
		cuts = cuts and not shell.is_turning() and absf(shell.camera()
				.rotation.y - float(seen.size()) * PI * 0.5) < 0.0001
		seen.append(shell.front())
	settings.set_value("motion_intensity", was)
	shell.close()
	_check(cuts and seen == ["settings", "equipment", "map", "journal",
			"settings"],
			"with motion_intensity at 0 each turn is a cut, through the same "
			+ "walls in the same order: %s" % [seen])


# ---------------------------------------------------------------------------
# H-PAUSE: the world stops behind it
# ---------------------------------------------------------------------------

func _the_world_stops() -> void:
	print("  -- the world stops behind it (H-PAUSE)")
	var ticker := Ticker.new()
	add_child(ticker)
	var body := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	add_child(body)
	_timer_fired = false
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
		_timer_fired = true)
	await _frames(3)
	shell.open("settings")
	var ticks := ticker.ticks
	var height := body.global_position.y
	var until := Time.get_ticks_msec() + 700
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	_check(get_tree().paused and ticker.ticks == ticks
			and absf(body.global_position.y - height) < 0.000001
			and not _timer_fired,
			"open for 0.7 s: the world is paused -- a node got no frames, a "
			+ "body did not fall, a 0.3 s timer did not fire")
	var bridge_runs := BridgeClient.process_mode == Node.PROCESS_MODE_ALWAYS \
			and BridgeClient.can_process()
	_check(bridge_runs, "the bridge client runs through it: the AP world "
			+ "is not paused")
	await _key(KEY_Q)
	await _rest()
	_check(shell.front() == "equipment",
			"and the interface itself still turns while the world is still")
	PauseClaims.claim(get_tree(), "test_other_owner")
	shell.close()
	await _frames(2)
	_check(get_tree().paused and PauseClaims.owners() == ["test_other_owner"],
			"closing it releases its own claim only: another owner's pause "
			+ "holds (%s)" % [PauseClaims.owners()])
	PauseClaims.release(get_tree(), "test_other_owner")
	var runs := Time.get_ticks_msec() + 700
	while Time.get_ticks_msec() < runs:
		await get_tree().process_frame
	_check(not get_tree().paused and ticker.ticks > ticks
			and body.global_position.y < height - 0.01 and _timer_fired,
			"once nobody holds it the world runs on: %d frames, the body "
			% (ticker.ticks - ticks) + "fell %.2f m, the timer fired"
			% (height - body.global_position.y))
	ticker.queue_free()
	body.queue_free()


# ---------------------------------------------------------------------------
# What it draws (`--shots=<dir>`, under xvfb with a real renderer)
# ---------------------------------------------------------------------------

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for page: String in MenuShell.PAGES:
		shell.open(page)
		await _frames(12)
		_save(get_viewport().get_texture().get_image(),
				dir.path_join("rest_%s.png" % page), page)
	shell.open("settings")
	await _frames(6)
	shell.turn(1)
	var halfway := Time.get_ticks_msec() + int(MenuShell.TURN_SECONDS * 500.0)
	while Time.get_ticks_msec() < halfway:
		await get_tree().process_frame
	_save(get_viewport().get_texture().get_image(),
			dir.path_join("mid_turn_settings_to_equipment.png"), "mid-turn")
	await _rest()
	shell.close()


## Saved, and checked to have drawn something: the share of pixels that
## are not the box's background.
func _save(image: Image, path: String, what: String) -> void:
	image.save_png(path)
	var background := Color(0.03, 0.035, 0.045)
	var drawn := 0
	var total := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			total += 1
			var c := image.get_pixel(x, y)
			if absf(c.r - background.r) + absf(c.g - background.g) \
					+ absf(c.b - background.b) > 0.06:
				drawn += 1
	var share := float(drawn) / float(maxi(total, 1))
	_check(share > 0.4,
			"%s drawn: %.0f%% of the frame is page or box, not background "
			% [what, share * 100.0] + "(%s, %dx%d)" % [path.get_file(),
				image.get_width(), image.get_height()])


# ---------------------------------------------------------------------------
# Devices, as the engine receives them
# ---------------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _rest() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while shell.is_turning() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _frames(2)


func _key(code: Key, text := "") -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		if text != "":
			event.unicode = text.unicode_at(0)
		Input.parse_input_event(event)
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


func _click_control(control: Control) -> void:
	await _click(control.get_global_rect().get_center())
