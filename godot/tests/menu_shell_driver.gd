extends Node
## H-3D-SHELL, AS THE APPROVED HYBRID (MENU-INT) -- THE PAUSE INTERFACE IS A
## REAL 3D DEVICE (`--menu-shell`).
##
##     make godot-menu-shell      headless: the box, the order, the input
##     make menu-shell-shots      xvfb + the game's renderer: what it draws
##
## The shell's own guarantees, asked of a real `MenuShell` with a PROBE
## controller mounted on each wall (the walls' own guarantees are their
## suites'):
##   the box        four walls in the box's own `World3D`, each the same
##                  distance from the camera and facing it, the camera at
##                  the centre; one harness round all four walls and every
##                  corner post, in 3D;
##   the order      turning left visits Settings, Equipment, Map, Journal
##                  and Settings again; right reverses it; by the keys and
##                  by the edge cues;
##   a turn         the camera's yaw moves monotonically through the
##                  quarter turn, no wall moves, and midway two walls are
##                  in view;
##   the pointer    a click lands on the part VISIBLY under the pointer: a
##                  raised part's front, and its side where the wall's own
##                  plane would have put the click elsewhere; the same after
##                  the window is resized; never mid-turn;
##   the way out    Escape and the pad's B back out of the deeper view
##                  first, then close; Start closes at once; the prompt says
##                  what the next press does; Tab turns to Equipment and
##                  closes from it; a search being typed keeps Q, E and Tab;
##   in a turn      a direction pressed mid-turn reaches the wall turned to
##                  once it faces the eye -- a few at most, the final wall
##                  of an interrupted turn -- and ENTER and a click do not;
##   motion         reduced: a cut; switched off mid-turn: the turn and
##                  everything moving arrive at once;
##   focus loss     nothing stays held;
##   the world stops (H-PAUSE)  a pausable node, a falling body and a
##                  pause-aware timer all stand still while it is open, and
##                  closing releases only its own claim;
##   the glass      the edge cues name the neighbours; the prompts follow
##                  the device; the cues are heard.
##
## Every click and key here is an `InputEvent` parsed into the engine the
## way a device's is; nothing calls a handler directly.

const SHOTS_FLAG := "--shots="

var _failures := 0
var _checks := 0
var _notes := 0
var shell: MenuShell = null
var probes := {}
## Set by a pause-aware timer's timeout. On the node, not in a closure: a
## lambda captures a local by value.
var _timer_fired := false


## A node that counts the frames it is given.
class Ticker extends Node:
	var ticks := 0

	func _process(_delta: float) -> void:
		ticks += 1


## A wall's stand-in: a RAISED part (8 cm off the wall, left of centre, so
## the eye sees its inner side), a FLAT part on the wall beside it, and a
## record of everything the shell routed to it.
class Probe extends Node:
	var page := ""
	var kit: MenuKit
	var shell: MenuShell
	var raised: MeshInstance3D
	var flat: Node3D
	var clicks: Array = []
	var navs: Array = []
	var repeats_seen := 0
	var accepts := 0
	var deeper := 0
	var typing := false
	var typed := ""
	var drags := 0
	var lost := 0
	var released_count := 0
	const RAISED := Rect2(150, 280, 140, 90)
	const FLAT := Rect2(760, 300, 160, 90)

	func setup(k: MenuKit, s: MenuShell) -> void:
		kit = k
		shell = s
		var face := shell.face_node(page)
		raised = MenuParts.block(face, RAISED, 0.0, 0.08,
				MenuParts.mat(Color("#8a7a60"), 0.2, 0.6))
		kit.pickable(page, raised, "raised")
		flat = kit.pick_rect(page, face, FLAT, 0.0, 0.001, "flat")

	func click(hit: Dictionary, _button := MOUSE_BUTTON_LEFT) -> bool:
		clicks.append(str(hit.get("target", "")))
		return str(hit.get("target", "")) != ""

	func drag(_rel: Vector2, _button: int, _hit := {}) -> void:
		drags += 1

	func nav(dir: Vector2i, repeat := false) -> void:
		navs.append(dir)
		if repeat:
			repeats_seen += 1

	func accept() -> void:
		accepts += 1

	func back() -> bool:
		if typing:
			typing = false
			return true
		if deeper > 0:
			deeper -= 1
			return true
		return false

	func back_words() -> String:
		return "stop typing" if typing else ("less" if deeper > 0 else "close")

	func typing_active() -> bool:
		return typing

	func raw_input(event: InputEvent) -> bool:
		if typing and event is InputEventKey:
			var key := event as InputEventKey
			if key.pressed and key.unicode >= 32:
				typed += char(key.unicode)
			return true
		return false

	func released(_event: InputEvent) -> void:
		released_count += 1

	func focus_lost() -> void:
		lost += 1

	func repeats() -> bool:
		return true

	func prompts() -> Array:
		return [["move", "probe"]]


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
	# `project.godot` says.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	shell = MenuShell.new()
	add_child(shell)
	for page: String in MenuShell.PAGES:
		var probe := Probe.new()
		probe.page = page
		probe.name = "Probe_%s" % page
		probes[page] = probe
		shell.mount(page, probe)
	await get_tree().process_frame
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
	await _the_way_out()
	await _input_in_a_turn()
	await _reduced_motion()
	await _motion_at_once()
	await _focus_loss()
	await _the_world_stops()
	await _the_glass()
	_finish("GODOT MENU SHELL")


func _finish(what: String) -> void:
	shell.close()
	print("")
	if _failures == 0:
		print("%s OK (%d checks, %d notes)" % [what, _checks, _notes])
		get_tree().quit(0)
		return
	print("%s TESTS: %d failures in %d checks" % [what, _failures, _checks])
	get_tree().quit(1)


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
	_check(shell.stage().msaa_3d == MenuShell.MSAA,
			"with antialiasing of its own (MSAA %d), the game's unchanged"
			% shell.stage().msaa_3d)
	var eye := shell.camera().global_position
	var wrong: Array = []
	for page: String in MenuShell.PAGES:
		var wall := shell.wall(page)
		var at := wall.global_position
		var normal := wall.global_basis.z.normalized()
		var toward := (eye - at).normalized()
		var off := absf(at.distance_to(eye) - MenuShell.DISTANCE)
		if normal.dot(toward) < 0.9999 or off > 0.0001:
			wrong.append("%s at %v facing %v" % [page, at, normal])
	_check(wrong.is_empty() and eye.length() < 0.0001,
			"four walls, each %.1f m from the camera at the centre and "
			% MenuShell.DISTANCE + "facing it squarely (wrong: %s)" % [wrong])
	# ONE HARNESS: a trunk on every wall, and a run round every corner post
	# joining the end of one wall's trunk to the start of the next's -- in
	# the box's space, round the post, not painted on either wall.
	var corners := 0
	var round_posts := 0
	for i in MenuShell.PAGES.size():
		var left: String = MenuShell.PAGES[i]
		var right: String = MenuShell.PAGES[posmod(i - 1, MenuShell.PAGES.size())]
		var node := shell.box().get_node_or_null("Corner_%s_%s" % [left, right]) \
				as MeshInstance3D
		if node == null:
			continue
		corners += 1
		var box := node.global_transform * node.mesh.get_aabb()
		var post_x := signf(box.get_center().x) * MenuShell.DISTANCE
		var post_z := signf(box.get_center().z) * MenuShell.DISTANCE
		var near_post := absf(absf(box.get_center().x) - MenuParts.POST) < 0.2 \
				and absf(absf(box.get_center().z) - MenuParts.POST) < 0.2
		# It leaves one wall and arrives on the other: its box spans both
		# walls' planes near the corner.
		if near_post and absf(post_x) > 0.0 and absf(post_z) > 0.0 \
				and box.size.x > 0.05 and box.size.z > 0.05:
			round_posts += 1
	_check(corners == 4 and round_posts == 4,
			"one harness: a trunk run round each of the four corner posts, "
			+ "from wall to wall in 3D (%d runs, %d round a post)"
			% [corners, round_posts])
	var titles := 0
	for page: String in MenuShell.PAGES:
		for n: Node in shell.face_node(page).find_children("*", "Label3D", true, false):
			if (n as Label3D).text == str(MenuShell.TITLES[page]):
				titles += 1
	_check(titles == 4, "every wall's title is a flag label on the harness "
			+ "(%d of 4)" % titles)
	shell.close()


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
	await _click(shell.arrows()[0].get_global_rect().get_center())
	await _rest()
	by_arrow.append(shell.front())
	await _click(shell.arrows()[1].get_global_rect().get_center())
	await _rest()
	by_arrow.append(shell.front())
	_check(by_arrow == ["settings", "equipment", "settings"],
			"and by the edge cues on the glass, clicked: %s" % [by_arrow])
	shell.close()


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
			+ "%d frames (%.2f s)" % [yaws.size() - 1, MenuShell.TURN_SECONDS])
	_check(moved.is_empty(),
			"no wall moved, turned or scaled while it did (moved: %s)" % [moved])
	_check(both_in_view,
			"and halfway round, Settings and Equipment are both in view")
	shell.close()


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
	_check(absf(facing + 1.0) < 0.0001 and absf(share - MenuShell.FILL) < 0.01,
			"the front wall faces the camera squarely (%.5f) and fills " % facing
			+ "%.2f of the view's height (meant: %.2f)" % [share, MenuShell.FILL])
	shell.close()


# ---------------------------------------------------------------------------
# The pointer
# ---------------------------------------------------------------------------

func _the_pointer() -> void:
	print("  -- the pointer lands on what is visibly under it")
	shell.open("settings")
	await _frames(2)
	var probe: Probe = probes["settings"]
	probe.clicks.clear()
	await _click(shell.screen_of_node(probe.raised))
	_check(probe.clicks == ["raised"],
			"a click on a raised part's front lands on it: %s" % [probe.clicks])
	# ITS SIDE: the face toward the centre of the view, 8 cm deep. Where
	# the pointer is on that side, the wall's own plane is somewhere else
	# entirely -- a click read in wall-plane pixels would miss the part.
	var side := _side_point(probe.raised)
	var page_there := shell.page_point(side)
	var plane_misses := page_there == Vector2.INF \
			or not Probe.RAISED.has_point(page_there)
	probe.clicks.clear()
	await _click(side)
	_check(plane_misses and probe.clicks == ["raised"],
			"a click on its SIDE lands on it too (%v), though the wall's "
			% side.snapped(Vector2.ONE) + "plane there is page %v, off the part"
			% page_there.snapped(Vector2.ONE))
	probe.clicks.clear()
	await _click(shell.screen_of_node(probe.flat))
	_check(probe.clicks == ["flat"], "and a flat part on the wall is hit where "
			+ "it is drawn: %s" % [probe.clicks])
	# ANOTHER WALL IN FRONT: the same screen point is its part, not this one.
	await _key(KEY_Q)
	await _rest()
	var there: Probe = probes["equipment"]
	there.clicks.clear()
	probe.clicks.clear()
	await _click(shell.screen_of_node(there.raised))
	_check(there.clicks == ["raised"] and probe.clicks.is_empty(),
			"with Equipment in front, its raised part answers and Settings' "
			+ "does not")
	# MID-TURN: a click on the arriving wall's part, where it is drawn at
	# that moment, is dropped -- never replayed onto it.
	await _key(KEY_Q)
	var late := Time.get_ticks_msec() + int(MenuShell.TURN_SECONDS * 600.0)
	while shell.is_turning() and Time.get_ticks_msec() < late:
		await get_tree().process_frame
	var map: Probe = probes["map"]
	map.clicks.clear()
	var dropped := shell.dropped_in_turn
	var mid_turn := shell.is_turning()
	var drawn := shell.screen_of_node(map.flat)
	var on_screen := Rect2(Vector2.ZERO, Vector2(shell.stage().size)).has_point(drawn)
	await _click(drawn)
	await _rest()
	_check(mid_turn and on_screen and map.clicks.is_empty()
			and shell.dropped_in_turn > dropped,
			"a click in the middle of a turn, on the arriving wall's part as "
			+ "it is drawn then (%v), presses nothing and is not replayed"
			% drawn.snapped(Vector2.ONE))
	await _click(shell.screen_of_node(map.raised))
	_check(map.clicks == ["raised"],
			"and the same part, clicked once the turn has come to rest, is")
	# RESIZED: the window at 1920 x 1080; the part is where it is drawn now.
	get_window().size = Vector2i(1920, 1080)
	await _frames(4)
	map.clicks.clear()
	await _click(shell.screen_of_node(map.raised))
	var side_big := _side_point(map.raised)
	await _click(side_big)
	_check(map.clicks == ["raised", "raised"],
			"resized to %v, a click on the part's front and on its side "
			% Vector2(shell.stage().size) + "still land on it: %s" % [map.clicks])
	get_window().size = Vector2i(1280, 720)
	await _frames(4)
	var off := shell.camera().unproject_position(shell.face_node("map")
			.global_transform * MenuKit.at(Vector2(-60, -60), 0.0))
	_check(shell.page_point(off) == Vector2.INF,
			"a point off the front wall maps to no page pixel")
	shell.close()


## A point on the screen on the raised part's side facing the view's
## centre (its +x face, since it stands left of centre).
func _side_point(node: MeshInstance3D) -> Vector2:
	var box := node.mesh.get_aabb()
	var local := Vector3(box.end.x, box.get_center().y, box.get_center().z)
	return shell.camera().unproject_position(node.global_transform * local)


# ---------------------------------------------------------------------------
# The way out
# ---------------------------------------------------------------------------

func _the_way_out() -> void:
	print("  -- the way out")
	shell.open("map")
	await _frames(2)
	var probe: Probe = probes["map"]
	probe.deeper = 2
	shell._refresh_glass()
	var said: Array = [_back_prompt()]
	await _key(KEY_ESCAPE)
	said.append(_back_prompt())
	var one_deep := probe.deeper == 1 and shell.is_open()
	await _key(KEY_ESCAPE)
	said.append(_back_prompt())
	var none_deep := probe.deeper == 0 and shell.is_open()
	await _key(KEY_ESCAPE)
	_check(one_deep and none_deep and not shell.is_open(),
			"Escape backs out of each deeper view first, and closes only from "
			+ "the top")
	_check(said == ["LESS", "LESS", "CLOSE"],
			"and the prompt says what the next Escape does: %s" % [said])
	shell.open("map")
	await _frames(2)
	probe.deeper = 1
	await _pad(JOY_BUTTON_B)
	var b_backed := probe.deeper == 0 and shell.is_open()
	await _pad(JOY_BUTTON_B)
	_check(b_backed and not shell.is_open(),
			"the pad's B does the same: back, then close")
	shell.open("map")
	await _frames(2)
	probe.deeper = 3
	await _pad(JOY_BUTTON_START)
	_check(not shell.is_open() and probe.deeper == 3,
			"the pad's Start closes at once, from any depth")
	# TYPING: a search being typed keeps its letters; Q, E and Tab do not
	# turn; Escape stops the typing first.
	shell.open("equipment")
	await _frames(2)
	var eq: Probe = probes["equipment"]
	eq.typing = true
	eq.typed = ""
	await _key(KEY_Q, "q")
	await _key(KEY_E, "e")
	await _key(KEY_TAB)
	_check(eq.typed == "qe" and shell.front() == "equipment"
			and not shell.is_turning() and shell.is_open(),
			"a search being typed keeps Q and E ('%s'); nothing turned, and " % eq.typed
			+ "Tab did not close it")
	await _key(KEY_ESCAPE)
	_check(not eq.typing and shell.is_open(), "Escape ends the typing first")
	await _key(KEY_TAB)
	await _frames(2)
	_check(not shell.is_open(), "then Tab, from Equipment, closes it")
	shell.open("journal")
	await _frames(2)
	await _key(KEY_TAB)
	await _rest()
	_check(shell.front() == "equipment" and shell.is_open(),
			"from any other wall, Tab turns to Equipment")
	shell.close()


func _back_prompt() -> String:
	for p: Dictionary in shell.prompts_shown():
		if str(p["action"]) in ["back", "close"] and "key:ESC" in p["shows"]:
			return str(p["words"])
	return ""


# ---------------------------------------------------------------------------
# Input during a turn
# ---------------------------------------------------------------------------

func _input_in_a_turn() -> void:
	print("  -- input during a turn")
	shell.open("settings")
	await _frames(2)
	var eq: Probe = probes["equipment"]
	eq.navs.clear()
	eq.accepts = 0
	eq.clicks.clear()
	await _key(KEY_Q)
	var turning := shell.is_turning()
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	var before_arrival := eq.navs.size()
	await _rest()
	_check(turning and before_arrival == 0 and eq.navs == [Vector2i(0, 1),
			Vector2i(0, 1)] and eq.accepts == 0,
			"two DOWNs pressed mid-turn reach Equipment once it faces the eye "
			+ "(%s); the ENTER pressed with them does not" % [eq.navs])
	# A HELD KEY THROUGH A TURN does not run on after it: a few presses at
	# most.
	eq.navs.clear()
	await _key(KEY_E)
	var st: Probe = probes["settings"]
	st.navs.clear()
	for _i in 10:
		await _key(KEY_DOWN)
	await _rest()
	_check(st.navs.size() <= MenuShell.HELD_MAX and st.navs.size() > 0,
			"ten DOWNs in one turn: %d delivered, at most %d"
			% [st.navs.size(), MenuShell.HELD_MAX])
	# AN INTERRUPTED TURN: Q, then E back before it arrives -- the presses
	# go to the wall finally faced, not the one passed.
	st.navs.clear()
	eq.navs.clear()
	await _key(KEY_Q)
	await _key(KEY_DOWN)
	await _key(KEY_E)
	await _key(KEY_UP)
	await _rest()
	_check(shell.front() == "settings" and eq.navs.is_empty()
			and st.navs == [Vector2i(0, 1), Vector2i(0, -1)],
			"a turn turned back mid-way: both presses reach Settings, the "
			+ "wall faced at the end (%s), none the wall passed" % [st.navs])
	shell.close()


# ---------------------------------------------------------------------------
# Reduced motion, and MOTION at once
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


func _motion_at_once() -> void:
	print("  -- MOTION applies at once")
	var settings := PlayerSettings.shared()
	var was := settings.value("motion_intensity")
	settings.set_value("motion_intensity", 1.0)
	shell.open("settings")
	await _frames(2)
	var probe: Probe = probes["settings"]
	# Something else moving on a wall, as a wall's own animation would.
	probe.raised.position.x = 0.0
	shell.kit.go(probe.raised, "position:x", 0.05, 2.0)
	await _key(KEY_Q)
	await _frames(2)
	var mid := shell.is_turning() and shell.kit.moving(probe.raised, "position:x")
	settings.set_value("motion_intensity", 0.0)
	shell.sync_motion()
	_check(mid and not shell.is_turning()
			and absf(shell.camera().rotation.y - PI * 0.5) < 0.0001
			and is_equal_approx(probe.raised.position.x, 0.05)
			and not shell.kit.busy(),
			"switched to reduced mid-turn: the turn arrives at once, and "
			+ "what else was moving arrives with it")
	await _frames(2)
	_check(shell.front() == "equipment", "on the wall it was turning to")
	settings.set_value("motion_intensity", was)
	shell.sync_motion()
	probe.raised.position.x = 0.0
	shell.close()


# ---------------------------------------------------------------------------
# Focus loss
# ---------------------------------------------------------------------------

func _focus_loss() -> void:
	print("  -- focus loss")
	shell.open("journal")
	await _frames(2)
	var probe: Probe = probes["journal"]
	probe.lost = 0
	probe.drags = 0
	var at := shell.screen_of_node(probe.raised) + Vector2(0, 200)
	await _press_mouse(at, true)
	shell._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _move(at + Vector2(40, 0))
	_check(probe.lost == 1 and probe.drags == 0,
			"the window losing focus lets go of a drag in progress, and the "
			+ "wall is told (%d)" % probe.lost)
	await _press_mouse(at + Vector2(40, 0), false)
	shell.close()


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
# The glass: the edge cues, the prompts, the cues heard
# ---------------------------------------------------------------------------

func _the_glass() -> void:
	print("  -- the glass")
	var heard := shell.kit.heard.size()
	shell.open("settings")
	await _frames(2)
	var left := _texts(shell.arrows()[0])
	var right := _texts(shell.arrows()[1])
	_check(left.has("EQUIPMENT") and right.has("JOURNAL"),
			"the edge cues name the walls they turn to: %s | %s" % [left, right])
	await _key(KEY_DOWN)
	var kbm := _shown_tokens(shell.prompts_shown())
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var pad := _shown_tokens(shell.prompts_shown())
	_check(kbm.has("key:ESC") and kbm.has("cap:arrow_up") and pad.has("sym:pad_start")
			and pad.has("sym:pad_dpad") and not pad.has("key:ESC"),
			"the prompts follow the device in hand: %s, then %s" % [kbm, pad])
	var probe: Probe = probes["settings"]
	probe.deeper = 1
	shell._refresh_glass()
	var deeper := _shown_tokens(shell.prompts_shown())
	probe.deeper = 0
	shell._refresh_glass()
	_check(deeper.has("sym:pad_face_east") and deeper.has("sym:pad_start"),
			"with a deeper view open, the pad shows B for back and Start for a "
			+ "direct close: %s" % [deeper])
	await _key(KEY_Q)
	await _rest()
	shell.close()
	var cues: Array = shell.kit.heard.slice(heard)
	_check(cues.has("open") and cues.has("page") and cues.has("close"),
			"and the box is heard: %s" % [cues])


func _texts(root: Node) -> Array:
	var out: Array = []
	for n: Node in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func _shown_tokens(prompts: Array) -> Array:
	var out: Array = []
	for p: Dictionary in prompts:
		for s: Variant in p["shows"]:
			out.append(str(s))
	return out


# ---------------------------------------------------------------------------
# What it draws (`--shots=<dir>`, under xvfb with the game's renderer)
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
	var background := MenuKit.BG
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
			"%s drawn: %.0f%% of the frame is wall or box, not background "
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


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _move(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	move.relative = Vector2(40, 0)
	Input.parse_input_event(move)
	await get_tree().process_frame


func _press_mouse(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = down
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
