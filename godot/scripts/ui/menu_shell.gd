class_name MenuShell
extends CanvasLayer
## H-3D-SHELL, AS THE APPROVED HYBRID (MENU-INT): THE PAUSE INTERFACE IS A
## REAL 3D DEVICE -- the inside of a box, its four walls the old station's
## enamel enclosure, one laced harness round all four walls and every
## corner post, and each wall's own hardware standing off it: Equipment's
## cabinet and rack, the Map's riveted port onto a live miniature, the
## Journal's runs and tags, and the salvaged Settings boards.
##
## Four walls, a camera at the box's centre, and a turn between walls that
## is the camera actually turning. Turning LEFT proceeds Settings ->
## Equipment -> Map -> Journal -> Settings; turning right reverses it.
## (`post_playtest_v1.0/04_3D_MENU_MAP_AND_GLYPH.md` §1, §3; the art
## lane's prototype `tools/menu_proto`, `5b03f6d`, and its handoff.)
##
## **ITS OWN WORLD.** The box renders in a SubViewport with its own
## `World3D`, so nothing of the dungeon -- walls, lights, physics, field of
## view -- is in it, and nothing of it is in the dungeon. It renders with
## the game's own renderer; its viewport takes MSAA of its own.
##
## **REAL PARTS, NOT PICTURES.** Every wall's hardware is 3D in the box's
## world, placed so its front is SEEN at its page pixels, and keeps its
## depth: its sides, its shadow, the parallax of a turn. Words are Glyph
## text on the parts. Nothing is a flat picture of a wall.
##
## **WHAT IS UNDER THE POINTER IS WHAT A CLICK HITS.** The pointer's ray is
## cast into the box and met with the parts' own boxes (`MenuKit.pick`),
## so a raised part is hit where it is seen -- a pulled module, a knob, a
## keycap's side -- at any window size. No physics query: a paused world
## must not need its physics server to make a menu clickable.
##
## **THE WORLD STOPS BEHIND IT (H-PAUSE).** Open, it holds a `PauseClaims`
## claim named "menu": the dungeon, its physics and its timers stop, and
## this node and the bridge client keep running. Closing releases only its
## own claim.
##
## **THE WAY OUT (the owner's second ruling).**
## - Escape and the pad's B back out of the deeper view first -- the
##   Map's detail, its shown view, its pick; Equipment's rack; a search
##   being typed -- and close the menu when there is nothing deeper. The
##   prompt says what the next press does.
## - The pad's Start is a direct close from any depth, and RESUME on the
##   Settings wall is one too. Tab turns to Equipment, and closes from it.
##
## **INPUT DURING A TURN IS NOT LOST.** A direction pressed while the box
## turns is delivered to the wall being turned to once it faces the eye (a
## few presses at most, in order). A confirmation -- ENTER, A, a click --
## is never carried into a wall the player has not yet seen: it is
## dropped, and so is a click on a wall still moving.
##
## **WHAT FILLS THE WALLS.** `Main` mounts each wall's controller
## (`mount`): SettingsFace with PauseMenu's switches, EquipmentFace,
## MapFace and JournalFace. Each builds its hardware under its wall's
## frame (`face_node`) and answers the routed input.

signal opened(page: String)
signal closed
## The front page changed, once a turn has come to rest.
signal page_changed(page: String)

## The walls, in the order turning LEFT visits them.
const PAGES: Array[String] = ["settings", "equipment", "map", "journal"]
const TITLES := MenuKit.TITLES
## Each wall's own pixels: every part is placed in them.
const PAGE_PIXELS := Vector2i(1280, 720)
## From the box's centre to each wall, and the camera's vertical field of
## view: together they decide how much of the screen the front wall fills
## at rest (`FILL`).
const DISTANCE := MenuKit.DISTANCE
const FOV := MenuKit.FOV
const FILL := MenuKit.FILL
## One quarter turn. A reduced-motion turn is a cut to the next wall,
## the same four walls in the same order.
const TURN_SECONDS := MenuKit.TURN_SECONDS
## The claim this interface holds on the world while it is open.
const PAUSE_CLAIM := "menu"
## The box's own antialiasing: the harness, the knobs and the cables are
## round, and their edges are the box's. Text is drawn at whole pixels
## with a nearest filter and needs none.
const MSAA := Viewport.MSAA_4X
## A direction pressed during a turn waits for the wall turned to; this
## many at most, so a key held through a turn does not run on after it.
const HELD_MAX := 4
## The Compatibility renderer lets the Map miniature's light fall on the
## Map's wall and, glancing, the Journal's; the prototype toned pale
## surfaces there to match (its `Shell.SHADE`). Forward+ honours the
## light's cull mask, so the tone applies only where the leak exists.
const SHADE_COMPATIBILITY := {"map": 0.74, "journal": 0.86}
## THE HARNESS on each wall: the trunk's clamps, and the spans its lacing
## keeps clear of (what a wall hangs from it). The prototype's numbers.
const HARNESS := {
	"settings": {"clamps": [560.0, 1000.0], "clear": [Vector2(1166, 1214)]},
	"equipment": {"clamps": [520.0, 1110.0], "clear": [Vector2(1186, 1214)]},
	"map": {"clamps": [640.0, 800.0], "clear": [Vector2(932, 960),
		Vector2(1174, 1202)]},
	"journal": {"clamps": [880.0], "clear": [Vector2(32, 60),
		Vector2(586, 614), Vector2(1190, 1230)]},
}

## A reduced-motion turn is a cut (§3). It follows the accessibility
## setting that already exists for exactly this: `motion_intensity` at 0
## "disables view bob and landing dip entirely" -- read at once, whenever
## it changes (`sync_motion`), not only on open.
var reduced_motion := false
## The kit every wall draws with.
var kit: MenuKit
## The device last used: "kbm" or "pad". The prompts follow it.
var device := "kbm"
## How each pale surface on a wall is toned for this renderer (1.0: not).
var shade := {}
## What the last pointer event hit, for a suite (target, page, screen).
var last_pick := {}
## Input dropped or held during turns, for a suite.
var dropped_in_turn := 0

var _stage: SubViewportContainer = null
var _world: SubViewport = null
var _camera: Camera3D = null
var _box: Node3D = null
var _faces := {}                     # page -> Node3D, the wall's frame
var _walls := {}                     # page -> MeshInstance3D
var _controllers := {}               # page -> the mounted wall's controller
var _light: OmniLight3D = null
var _arrows: Array[Button] = []
var _glass: Control = null
var _prompt_row: HBoxContainer = null
var _prompts_shown: Array = []
var _front := 0
## The yaw the camera is headed for, in quarter turns (unwrapped, so a
## turn is always the short way round and never a spin).
var _heading := 0
var _was_turning := false
var _held: Array = []
var _stick := {}
var _stick_repeat := 0.0
var _drag_button := 0
var _pointer := Vector2(-1, -1)
var _hover_target := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	kit = MenuKit.new()
	_stage = SubViewportContainer.new()
	_stage.name = "Stage"
	_stage.stretch = true
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.gui_input.connect(_on_stage_input)
	add_child(_stage)
	_world = SubViewport.new()
	_world.name = "Box"
	_world.own_world_3d = true
	_world.handle_input_locally = false
	_world.msaa_3d = MSAA
	_world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stage.add_child(_world)
	var method := RenderingServer.get_current_rendering_method()
	for page: String in PAGES:
		shade[page] = float(SHADE_COMPATIBILITY.get(page, 1.0)) \
				if method == "gl_compatibility" else 1.0
	_build_box()
	_build_glass()
	_face(_front, true)


# ------------------------------------------------------------ the API

func open(page := "settings") -> void:
	sync_motion()
	_read_keycaps()
	var index := PAGES.find(page)
	_front = index if index >= 0 else 0
	_heading = _front
	_held.clear()
	_stick.clear()
	_drag_button = 0
	_face(_front, true)
	visible = true
	_set_rendering(true)
	PauseClaims.claim(get_tree(), PAUSE_CLAIM)
	kit.cue("open")
	for p: String in _controllers:
		_call(p, "on_open", [p == PAGES[_front]])
	_refresh_glass()
	opened.emit(PAGES[_front])
	page_changed.emit(PAGES[_front])


func close() -> void:
	if not visible:
		return
	_camera.rotation.y = MenuKit.yaw_of(_heading)
	kit.finish()
	_held.clear()
	_stick.clear()
	_pad_held.clear()
	_drag_button = 0
	_was_turning = false
	visible = false
	_set_rendering(false)
	PauseClaims.release(get_tree(), PAUSE_CLAIM)
	kit.cue("close")
	for p: String in _controllers:
		_call(p, "on_close", [])
	closed.emit()


## Freed while open -- a scene change, a test tearing down -- it must not
## leave the world held still.
func _exit_tree() -> void:
	if visible and PauseClaims.held_by(PAUSE_CLAIM):
		PauseClaims.release(get_tree(), PAUSE_CLAIM)


func is_open() -> bool:
	return visible


## The page facing the camera, or the one a turn in progress is headed
## for.
func front() -> String:
	return PAGES[_front]


func is_turning() -> bool:
	return _camera != null and kit.moving(_camera, "rotation:y")


## One quarter turn: +1 is LEFT (Settings -> Equipment), -1 is right.
func turn(step: int) -> void:
	if not visible or step == 0:
		return
	_turn_by(signi(step))
	kit.cue("page", 1.0 if step > 0 else 0.9)


## Straight to a page, the short way round: a quarter turn either way, or
## a half turn to the wall behind.
func show_page(page: String) -> void:
	var index := PAGES.find(page)
	if not visible or index < 0 or index == _front:
		return
	var delta := posmod(index - _front, PAGES.size())
	_turn_by(delta if delta <= 2 else delta - PAGES.size())
	kit.cue("page")


## MOTION, applied at once: read `motion_intensity` now; switched to
## reduced, a turn in flight arrives and everything moving on any wall
## stops where it was going.
func sync_motion() -> void:
	var reduced := PlayerSettings.shared().value("motion_intensity") <= 0.0
	reduced_motion = reduced
	if kit != null and kit.reduced != reduced:
		kit.set_reduced(reduced)


## Put a wall's controller on its wall: it is parented here (so it runs
## while the world is paused) and builds its hardware under `face_node`.
func mount(page: String, controller: Node) -> void:
	if not PAGES.has(page):
		push_error("menu shell: no wall named %s" % page)
		return
	_controllers[page] = controller
	if controller.get_parent() == null:
		add_child(controller)
	if controller.has_method("setup"):
		controller.call("setup", kit, self)
	_refresh_glass()


func controller(page: String) -> Node:
	return _controllers.get(page)


## A wall's own frame in the box: its hardware is built under it, in page
## coordinates (`MenuKit.at`).
func face_node(page: String) -> Node3D:
	return _faces.get(page)


func wall(page: String) -> MeshInstance3D:
	return _walls.get(page)


func camera() -> Camera3D:
	return _camera


func stage() -> SubViewport:
	return _world


func box() -> Node3D:
	return _box


func light() -> OmniLight3D:
	return _light


func arrows() -> Array[Button]:
	return _arrows


## The wall's width and height in the box's units.
func wall_size() -> Vector2:
	return MenuKit.wall_size()


## Where on the front wall's plane a point of the stage lands, in page
## pixels, or `Vector2.INF` when it misses the wall. For what is ON the
## wall plane only: a raised part is found by `pick_at`.
func page_point(stage_point: Vector2) -> Vector2:
	if _camera == null:
		return Vector2.INF
	return _page_hit(_front, _camera.project_ray_origin(stage_point),
			_camera.project_ray_normal(stage_point))


## What the pointer at `stage_point` is over on the front wall:
## {target, node, t, point, page, at, origin, along} -- `target` "" when
## it is over the wall and nothing on it answers.
func pick_at(stage_point: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	var origin := _camera.project_ray_origin(stage_point)
	var along := _camera.project_ray_normal(stage_point)
	var page := PAGES[_front]
	var hit := kit.pick(page, origin, along)
	if hit.is_empty():
		hit = {"target": ""}
	hit["page"] = page
	hit["origin"] = origin
	hit["along"] = along
	hit["at"] = _page_hit(_front, origin, along)
	hit["screen"] = stage_point
	return hit


## Where a point `depth` off wall `page`'s page pixel `at` is on the
## screen (a suite aims with it, the way a hand would).
func screen_of(page: String, at: Vector2, depth := 0.0) -> Vector2:
	var face: Node3D = _faces[page]
	return _camera.unproject_position(face.global_transform
			* MenuKit.at(at, depth))


## Where a pickable part's centre is on the screen.
func screen_of_node(node: Node3D) -> Vector2:
	return _camera.unproject_position(MenuKit.centre_of(node))


## The prompt line as drawn: [{action, shows, words}].
func prompts_shown() -> Array:
	return _prompts_shown.duplicate(true)


## The words the next Escape (or B) says it will do on the front wall.
func back_words() -> String:
	var said: Variant = _call(PAGES[_front], "back_words", [])
	return str(said) if said is String and str(said) != "" else "close"


# ------------------------------------------------------------ input

## Page turns and the way out; everything else a key does belongs to the
## front wall. A search being typed keeps its letters: Q, E and Tab type
## there (or do nothing), and do not turn.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	_note_device(event)
	if event is InputEventMouse:
		return                         # the stage's gui_input takes the pointer
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		_stick[motion.axis] = motion.axis_value
		get_viewport().set_input_as_handled()
		return
	var typing := _typing()
	# THE WAY OUT. Start: a direct close. Escape: back, then close.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if event is InputEventJoypadButton:
			close()
		elif not _back():
			close()
		return
	if event is InputEventJoypadButton and event.is_pressed() \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		if not _back():
			close()
		return
	if not typing and event.is_action_pressed("inventory"):
		if PAGES[_front] == "equipment":
			close()
		else:
			show_page("equipment")
		get_viewport().set_input_as_handled()
		return
	if not typing and event.is_action_pressed("menu_page_left"):
		turn(1)
		get_viewport().set_input_as_handled()
		return
	if not typing and event.is_action_pressed("menu_page_right"):
		turn(-1)
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	_track_pad_hold(event)
	if is_turning():
		_hold(event)
		return
	_route(event)


## Back out of the front wall's deeper view. Whether there was one.
func _back() -> bool:
	var backed := _yes(_call(PAGES[_front], "back", []))
	if backed:
		_refresh_glass()
	return backed


## A key or button for the front wall: its own keys first (the Map's, a
## search being typed), then the ordinary moves and ENTER / A.
func _route(event: InputEvent) -> void:
	var page := PAGES[_front]
	var ctl: Node = _controllers.get(page)
	if ctl == null:
		return
	if ctl.has_method("raw_input") and _yes(ctl.call("raw_input", event)):
		_refresh_glass()
		return
	var echo := event.is_echo()
	if event.is_action_pressed("ui_up", true):
		_call(page, "nav", [Vector2i(0, -1), echo])
	elif event.is_action_pressed("ui_down", true):
		_call(page, "nav", [Vector2i(0, 1), echo])
	elif event.is_action_pressed("ui_left", true):
		_call(page, "nav", [Vector2i(-1, 0), echo])
	elif event.is_action_pressed("ui_right", true):
		_call(page, "nav", [Vector2i(1, 0), echo])
	elif event.is_action_pressed("ui_accept"):
		_call(page, "accept", [])
	elif event.is_released() and ctl.has_method("released"):
		ctl.call("released", event)
	else:
		return
	_refresh_glass()


## During a turn: a press that moves something waits for the wall turned
## to; a confirmation never does. A release always goes on (a slider's
## held run must end even across a turn).
func _hold(event: InputEvent) -> void:
	if event.is_released():
		var ctl: Node = _controllers.get(PAGES[_front])
		if ctl != null and ctl.has_method("released"):
			ctl.call("released", event)
		return
	if not event.is_pressed():
		return
	if event.is_action_pressed("ui_accept") \
			or (event is InputEventKey and _is_confirm_key(event as InputEventKey)):
		dropped_in_turn += 1
		return
	if event.is_echo() and not _held.is_empty():
		return                          # a held key: one press is enough
	if _held.size() >= HELD_MAX:
		dropped_in_turn += 1
		return
	_held.append(event)


static func _is_confirm_key(key: InputEventKey) -> bool:
	return key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] \
			or key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]


## The turn came to rest: the wall facing the eye has it now.
func _arrive() -> void:
	var page := PAGES[_front]
	for p: String in _controllers:
		_call(p, "on_front", [p == page])
	var held := _held.duplicate()
	_held.clear()
	for event: InputEvent in held:
		_route(event)
	# The pointer has not moved, but what is under it has.
	if _pointer.x >= 0.0:
		_hover(pick_at(_pointer))
	_refresh_glass()
	page_changed.emit(page)


func _on_stage_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouse):
		return
	_stage.accept_event()
	var mouse := event as InputEventMouse
	_pointer = mouse.position
	var page := PAGES[_front]
	var ctl: Node = _controllers.get(page)
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _drag_button != 0:
			if ctl != null and ctl.has_method("drag"):
				ctl.call("drag", motion.relative, _drag_button, pick_at(mouse.position))
			return
		if not is_turning():
			_hover(pick_at(mouse.position))
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	if not button.pressed:
		if button.button_index == _drag_button:
			_drag_button = 0
			if ctl != null and ctl.has_method("release") and not is_turning():
				ctl.call("release", pick_at(mouse.position), button.button_index)
		return
	if is_turning():
		# A click on a wall still moving is never replayed onto it.
		dropped_in_turn += 1
		return
	var hit := pick_at(mouse.position)
	hit["double"] = button.double_click
	last_pick = hit
	match button.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			var used := false
			if ctl != null and ctl.has_method("click"):
				used = _yes(ctl.call("click", hit, button.button_index))
			if not used and ctl != null and ctl.has_method("drag"):
				_drag_button = button.button_index
			_refresh_glass()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if ctl != null and ctl.has_method("wheel"):
				ctl.call("wheel", hit,
						-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
				_refresh_glass()


## A pad sends no repeats for a held d-pad, as a keyboard does for a held
## key: the shell makes them, for the walls whose lists and pots want them
## (`repeats`), after PAD_REPEAT_DELAY and every PAD_REPEAT_EVERY.
const PAD_REPEAT_DELAY := 0.35
const PAD_REPEAT_EVERY := 0.07
const _PAD_DIRS := {JOY_BUTTON_DPAD_UP: Vector2i(0, -1),
	JOY_BUTTON_DPAD_DOWN: Vector2i(0, 1), JOY_BUTTON_DPAD_LEFT: Vector2i(-1, 0),
	JOY_BUTTON_DPAD_RIGHT: Vector2i(1, 0)}
var _pad_held := {}                  # button -> seconds until its next repeat


func _track_pad_hold(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var b := (event as InputEventJoypadButton).button_index
	if not _PAD_DIRS.has(b):
		return
	if event.is_pressed():
		_pad_held.clear()               # one direction held at a time
		_pad_held[b] = PAD_REPEAT_DELAY
	else:
		_pad_held.erase(b)


func _pad_repeats(delta: float) -> void:
	if _pad_held.is_empty() or is_turning():
		return
	var page := PAGES[_front]
	if not _yes(_call(page, "repeats", [])):
		return
	for b: int in _pad_held.keys():
		_pad_held[b] = float(_pad_held[b]) - delta
		while float(_pad_held[b]) <= 0.0:
			_pad_held[b] = float(_pad_held[b]) + PAD_REPEAT_EVERY
			_call(page, "nav", [_PAD_DIRS[b], true])
			_refresh_glass()


func _hover(hit: Dictionary) -> void:
	last_pick = hit
	var target := str(hit.get("target", ""))
	var ctl: Node = _controllers.get(PAGES[_front])
	if ctl != null and ctl.has_method("hover"):
		ctl.call("hover", hit)
	_hover_target = target


func _typing() -> bool:
	return _yes(_call(PAGES[_front], "typing_active", []))


func _note_device(event: InputEvent) -> void:
	var was := device
	if event is InputEventJoypadButton:
		device = "pad"
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.4:
			device = "pad"
	elif event is InputEventKey or event is InputEventMouseButton:
		device = "kbm"
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 2.0:
			device = "kbm"
	if device != was:
		kit.device = device
		for page: String in _controllers:
			_call(page, "on_device", [])
		_refresh_glass()


## Window focus lost: nothing stays held -- a drag, a stick, a key being
## repeated, a slider's run.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_drag_button = 0
		_stick.clear()
		_held.clear()
		_pad_held.clear()
		for page: String in _controllers:
			_call(page, "focus_lost", [])


## A wall's answer as a yes: `true` only when it said `true` (a wall
## without the method says nothing).
static func _yes(answer: Variant) -> bool:
	return answer is bool and answer


func _call(page: String, method: String, args: Array) -> Variant:
	var ctl: Node = _controllers.get(page)
	if ctl == null or not is_instance_valid(ctl) or not ctl.has_method(method):
		return null
	return ctl.callv(method, args)


# ------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if not visible:
		return
	kit.step(delta)
	var turning := is_turning()
	if _was_turning and not turning:
		_arrive()
	_was_turning = turning
	for page: String in _controllers:
		_call(page, "tick", [delta])
	_sticks(delta)
	_pad_repeats(delta)


## The left stick moves focus with a repeat; a wall that reads the sticks
## itself (the Map) is handed them; the right stick scrolls by hand where
## a wall offers it.
func _sticks(delta: float) -> void:
	if is_turning():
		return
	var page := PAGES[_front]
	var ctl: Node = _controllers.get(page)
	if ctl == null:
		return
	if ctl.has_method("sticks"):
		ctl.call("sticks", _stick, delta)
		return
	var ry := float(_stick.get(JOY_AXIS_RIGHT_Y, 0.0))
	if absf(ry) > 0.3 and ctl.has_method("scroll_by"):
		ctl.call("scroll_by", ry * 900.0 * delta)
	var y := float(_stick.get(JOY_AXIS_LEFT_Y, 0.0))
	var x := float(_stick.get(JOY_AXIS_LEFT_X, 0.0))
	if absf(y) < 0.5 and absf(x) < 0.5:
		_stick_repeat = 0.0
		return
	_stick_repeat -= delta
	if _stick_repeat > 0.0:
		return
	_stick_repeat = 0.22
	if absf(y) >= absf(x):
		_call(page, "nav", [Vector2i(0, signi(int(signf(y))))])
	else:
		_call(page, "nav", [Vector2i(signi(int(signf(x))), 0)])
	_refresh_glass()


# ------------------------------------------------------------ turning

func _turn_by(step: int) -> void:
	# A turn away from a wall ends what was being typed there.
	_call(PAGES[_front], "stop_typing", [])
	_heading += step
	_front = posmod(_heading, PAGES.size())
	var yaw := MenuKit.yaw_of(_heading)
	kit.go(_camera, "rotation:y", yaw, TURN_SECONDS)
	if not is_turning():
		# A cut (reduced motion): there is no turn to come to rest.
		_was_turning = false
		_arrive()
	else:
		_was_turning = true
		_refresh_glass()


## Wall `i` stands a quarter turn LEFT of wall `i - 1`. A quarter turn
## left is +90 degrees of yaw.
func _yaw_of(quarter: int) -> float:
	return MenuKit.yaw_of(quarter)


func _face(index: int, at_once: bool) -> void:
	if _camera == null:
		return
	if at_once:
		_camera.rotation.y = MenuKit.yaw_of(_heading)
	_front = posmod(index, PAGES.size())


## The wall's centre and the unit vectors of its plane: `normal` points
## back at the camera, `right` and `up` are the page's own axes as seen
## from inside the box.
func _frame(index: int) -> Dictionary:
	var yaw := MenuKit.yaw_of(index)
	var normal := Vector3(sin(yaw), 0.0, cos(yaw))
	return {"centre": -normal * DISTANCE, "normal": normal,
		"right": Vector3(cos(yaw), 0.0, -sin(yaw)), "up": Vector3.UP}


func _page_hit(index: int, origin: Vector3, along: Vector3) -> Vector2:
	var frame := _frame(index)
	var normal: Vector3 = frame["normal"]
	var facing := along.dot(normal)
	if facing > -0.0001:
		return Vector2.INF         # parallel, or looking away from it
	var centre: Vector3 = frame["centre"]
	var t := (centre - origin).dot(normal) / facing
	if t <= 0.0:
		return Vector2.INF
	var local := origin + along * t - centre
	var size := wall_size()
	var u := local.dot(frame["right"]) / size.x + 0.5
	var v := 0.5 - local.dot(frame["up"]) / size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2.INF
	return Vector2(u * float(PAGE_PIXELS.x), v * float(PAGE_PIXELS.y))


# ------------------------------------------------------------ building

func _build_box() -> void:
	var environment := WorldEnvironment.new()
	var look := Environment.new()
	look.background_mode = Environment.BG_COLOR
	look.background_color = MenuKit.BG
	look.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	look.ambient_light_color = Color("#5c6570")
	look.ambient_light_energy = 0.38
	look.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = look
	_world.add_child(environment)
	_camera = Camera3D.new()
	_camera.name = "Eye"
	_camera.fov = FOV
	_camera.near = 0.02
	_camera.far = 50.0
	_camera.current = true
	_world.add_child(_camera)
	_box = Node3D.new()
	_box.name = "Enclosure"
	_world.add_child(_box)
	var size := wall_size()
	for i in PAGES.size():
		var page: String = PAGES[i]
		var face := Node3D.new()
		face.name = "Face_%s" % page
		face.rotation.y = MenuKit.yaw_of(i)
		_box.add_child(face)
		_faces[page] = face
		var wall_node := MeshInstance3D.new()
		wall_node.name = "Wall_%s" % page
		var quad := QuadMesh.new()
		quad.size = size
		wall_node.mesh = quad
		wall_node.material_override = kit.wall_material()
		wall_node.position = Vector3(0, 0, -DISTANCE)
		wall_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.add_child(wall_node)
		_walls[page] = wall_node
		_harness(page, i)
	# THE BOX ITSELF: floor, ceiling and the four corner posts, so the
	# walls read as the inside of one room and a turn reads as a turn.
	var span := DISTANCE * 2.0
	for y: float in [-size.y * 0.5 - 0.02, size.y * 0.5 + 0.02]:
		_block(Vector3(span, 0.02, span), Vector3(0, y, 0), MenuKit.SLAB)
	# THE CORNERS ARE PILLARS wide enough to meet both walls' edges: a
	# wall is narrower than the box's side, and a thin post left a gap
	# at every corner that showed through mid-turn.
	var post := 2.0 * (DISTANCE - size.x * 0.5) + 0.02
	for x: float in [-DISTANCE, DISTANCE]:
		for z: float in [-DISTANCE, DISTANCE]:
			_block(Vector3(post, size.y + 0.08, post), Vector3(x, 0, z),
					MenuKit.POST)
	# One light, near the ceiling: every wall is brightest at its top
	# middle and falls away to its corners and its foot. It lights the box
	# only (layer 1); the Map's miniature has a light of its own.
	_light = OmniLight3D.new()
	_light.name = "Lamp"
	_light.position = Vector3(0, size.y * 0.42, 0)
	_light.omni_range = 2.9
	_light.omni_attenuation = 1.1
	_light.light_energy = 1.9
	_light.light_color = Color("#f1ece4")
	_light.light_cull_mask = 1
	_light.shadow_enabled = true
	_light.shadow_bias = 0.02
	_light.shadow_normal_bias = 0.5
	_box.add_child(_light)
	_corners()


func _block(size: Vector3, pos: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	node.mesh = box_mesh
	node.material_override = kit.lit(colour)
	node.position = pos
	_box.add_child(node)


## The harness on each wall: the trunk's run, its clamps, and the wall's
## title as a flag label on it -- the wall's name and its number, where
## you are in the box.
func _harness(page: String, index: int) -> void:
	var face: Node3D = _faces[page]
	var r := MenuParts.flag(kit, face, 40, str(TITLES[page]), 4,
			"0%d" % (index + 1), float(shade.get(page, 1.0)))
	var clear: Array = (HARNESS[page]["clear"] as Array).duplicate()
	clear.append(Vector2(r.position.x, r.end.x))
	MenuParts.trunk(face, HARNESS[page]["clamps"], clear)


## The trunk round the four corner posts: one harness, not four.
func _corners() -> void:
	var loom := MenuParts.mat(MenuParts.LOOM, 0.1, 0.45)
	for i in PAGES.size():
		var left: String = PAGES[i]
		var right: String = PAGES[posmod(i - 1, PAGES.size())]
		var node := MenuParts.corner(_box, _faces[left], _faces[right],
				MenuParts.TRUNK_Y, MenuParts.TRUNK_R, loom, MenuParts.TRUNK_Z)
		node.name = "Corner_%s_%s" % [left, right]


## The glass in front of the box: the turn cues at the screen's edges
## (clickable, with the wall each turns to and its key) and the prompt
## line. Words, symbols and keycaps from the Glyph kit.
func _build_glass() -> void:
	_glass = Control.new()
	_glass.name = "Glass"
	_glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glass)
	for side: int in [1, -1]:
		var arrow := Button.new()
		arrow.name = "TurnLeft" if side == 1 else "TurnRight"
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.tooltip_text = "Turn left" if side == 1 else "Turn right"
		for state: String in ["normal", "hover", "pressed", "focus",
				"disabled", "hover_pressed"]:
			arrow.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		arrow.pressed.connect(func() -> void: turn(side))
		arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT if side == 1
				else Control.PRESET_CENTER_RIGHT)
		_glass.add_child(arrow)
		_arrows.append(arrow)
	_prompt_row = HBoxContainer.new()
	_prompt_row.name = "Prompts"
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.add_child(_prompt_row)
	get_viewport().size_changed.connect(_refresh_glass)
	_refresh_glass()


## The keys the shell's own actions are bound to, by name, as the player
## has them (`SlotKeycaps`, the real binding) -- read on open, so a
## rebinding shows from the next time the menu opens.
var _keycaps := {}


func _read_keycaps() -> void:
	_keycaps = {"menu_page_left": SlotKeycaps.of_action("menu_page_left", "Q"),
		"menu_page_right": SlotKeycaps.of_action("menu_page_right", "E"),
		"inventory": SlotKeycaps.of_action("inventory", "TAB")}
	for key: String in _keycaps:
		_keycaps[key] = str(_keycaps[key]).to_upper()


## What each control is, per device. A token is "@icon" (a bare device
## symbol), "#icon" (a symbol in a keycap) or "WORD" (a keycap). The
## keyboard's are Production's own bindings, read through SlotKeycaps
## where they are actions.
func _controls(action: String) -> Array:
	if _keycaps.is_empty():
		_read_keycaps()
	var kbm := {
		"turn_left": [_keycaps["menu_page_left"]],
		"turn_right": [_keycaps["menu_page_right"]],
		"back": ["ESC"],
		"close": ["ESC"],
		"equipment": [_keycaps["inventory"]],
		"move": ["#arrow_up", "#arrow_down"],
		"move_h": ["#arrow_left", "#arrow_right"],
		"into": ["#arrow_right"],
		"out": ["#arrow_left"],
		"accept": ["ENTER"],
		"click": ["@mouse_left"],
		"wheel": ["@mouse_wheel"],
		"place": ["[", "]"],
		"overview": ["C"],
		"zoom": ["+", "-"],
		"orbit": ["#arrow_left", "#arrow_right"],
		"pan": ["W", "A", "S", "D"],
		"floors": ["PGUP", "PGDN"],
		"change": ["#arrow_left", "#arrow_right"],
		"search": ["/"],
		"sort": ["S"],
		"history": ["H"],
		"favourite": ["F"],
		"clear": ["DEL"],
		"back_view": ["BACKSPACE"],
	}
	var pad := {
		"turn_left": ["@pad_lb"], "turn_right": ["@pad_rb"],
		"back": ["@pad_face_east"], "close": ["@pad_start"],
		"equipment": ["@pad_back"], "move": ["@pad_dpad"],
		"move_h": ["@pad_dpad"], "into": ["@pad_dpad_right"],
		"out": ["@pad_dpad_left"], "accept": ["@pad_face_south"],
		"click": [], "wheel": ["@pad_rstick"],
		"place": ["@pad_dpad_left", "@pad_dpad_right"],
		"overview": ["@pad_face_north"], "zoom": ["@pad_lt", "@pad_rt"],
		"orbit": ["@pad_rstick"], "pan": ["@pad_lstick"],
		"floors": ["@pad_dpad_up", "@pad_dpad_down"],
		"change": ["@pad_dpad"], "search": [], "sort": ["@pad_face_west"],
		"history": ["@pad_face_north"], "favourite": [],
		"clear": [], "back_view": ["@pad_face_east"],
	}
	return (pad if device == "pad" else kbm).get(action, [])


## The prompt line for the front wall's state, the turn cues, and the
## way out, sized for the window (a whole-pixel scale of the Glyph face).
func _refresh_glass() -> void:
	if _glass == null or kit == null or kit.text_font == null:
		return
	var view := get_viewport().get_visible_rect().size \
			if is_inside_tree() else Vector2(1280, 720)
	var s := maxf(1.0, floorf(view.y / 360.0))
	for child: Node in _prompt_row.get_children():
		_prompt_row.remove_child(child)
		child.queue_free()
	_prompts_shown = []
	var pairs: Array = []
	var own: Variant = _call(PAGES[_front], "prompts", [])
	if own is Array:
		pairs = (own as Array).duplicate()
	var back := back_words()
	pairs.append(["back" if back != "close" else "close", back])
	if device == "pad" and back != "close":
		pairs.append(["close", "close"])
	_prompt_row.add_theme_constant_override("separation", int(14.0 * s))
	for pair: Array in pairs:
		var tokens: Array = _controls(str(pair[0]))
		if tokens.is_empty():
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", int(3.0 * s))
		var shows := []
		for token: String in tokens:
			shows.append(_control_token(row, token, s))
		_glass_text(row, str(pair[1]), s, _INK_DIM)
		_prompts_shown.append({"action": str(pair[0]), "shows": shows,
			"words": kit.display(str(pair[1]))})
		_prompt_row.add_child(row)
	_prompt_row.position = Vector2(40.0 * s, view.y - 22.0 * s)
	# The turn cues: the arrow, the wall it turns to, and its key.
	for i in _arrows.size():
		var arrow: Button = _arrows[i]
		var side := 1 if i == 0 else -1
		for child: Node in arrow.get_children():
			arrow.remove_child(child)
			child.queue_free()
		var to := PAGES[posmod(_front + side, PAGES.size())]
		var name_w := kit.measure(str(TITLES[to]), 1) * s
		var w := maxf(22.0 * s, name_w)
		var icon := TextureRect.new()
		icon.texture = kit.icons.get("arrow_left" if side == 1 else "arrow_right")
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.scale = Vector2(s * 2.0, s * 2.0)
		icon.modulate = _INK_DIM
		icon.position = Vector2(0.0 if side == 1 else w - 24.0 * s, 0)
		arrow.add_child(icon)
		var title := _glass_text(arrow, str(TITLES[to]), s, _INK_FAINT)
		title.position = Vector2(0.0 if side == 1 else w - name_w, 28.0 * s)
		var tokens: Array = _controls("turn_left" if side == 1 else "turn_right")
		if not tokens.is_empty():
			var cap := _control_token(arrow, str(tokens[0]), s)
			var cap_node: Control = arrow.get_child(arrow.get_child_count() - 1)
			cap_node.position = Vector2(0.0 if side == 1
					else w - cap_node.custom_minimum_size.x, 40.0 * s)
			arrow.set_meta("shows", cap)
		arrow.custom_minimum_size = Vector2(w, 56.0 * s)
		arrow.size = arrow.custom_minimum_size
		var inner := 8.0 * s
		arrow.offset_left = inner if side == 1 else -inner - w
		arrow.offset_right = arrow.offset_left + w
		arrow.offset_top = -28.0 * s
		arrow.offset_bottom = 28.0 * s


const _INK_DIM := Color("#9ba5b6")
const _INK_FAINT := Color("#6f7885")
const _CAP_INK := Color("#26292d")


func _glass_text(parent: Control, text: String, s: float, colour: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", kit.text_font)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", colour)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = kit.display(text).replace(char(MenuKit.NBSP), " ")
	l.scale = Vector2(s, s)
	# A scaled Label reserves its unscaled size: the row is told the rest.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(kit.measure(text, 1) * s + 4.0 * s,
			12.0 * s)
	l.position = Vector2(0, 2.0 * s)
	holder.add_child(l)
	parent.add_child(holder)
	return l


## One control as drawn on the glass: a keycap (text or symbol inside) or
## a bare symbol. Returns what it shows ("sym:", "cap:" or "key:").
func _control_token(parent: Control, token: String, s: float) -> String:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bare := token.begins_with("@")
	var icon := token.substr(1) if (bare or token.begins_with("#")) else ""
	var shows := (("sym:" if bare else "cap:") + icon) if icon != "" \
			else "key:" + token
	if bare:
		var t := TextureRect.new()
		t.texture = kit.icons.get(icon)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.scale = Vector2(s, s)
		t.modulate = MenuKit.INK
		box.add_child(t)
		box.custom_minimum_size = Vector2(12, 12) * s
	else:
		var patch := NinePatchRect.new()
		patch.texture = kit.keycap
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patch.patch_margin_left = 2
		patch.patch_margin_top = 2
		patch.patch_margin_right = 1
		patch.patch_margin_bottom = 3
		var w := 14.0
		if icon == "":
			w = maxf(12.0, kit.measure(token, 1) + 6.0)
		patch.size = Vector2(w, 12)
		patch.scale = Vector2(s, s)
		box.add_child(patch)
		if icon != "":
			var t := TextureRect.new()
			t.texture = kit.icons.get(icon)
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.scale = Vector2(s, s) * 0.75
			t.position = Vector2(2.5, 0.5) * s
			t.modulate = _CAP_INK
			box.add_child(t)
		else:
			var l := Label.new()
			l.add_theme_font_override("font", kit.text_font)
			l.add_theme_font_size_override("font_size", 8)
			l.add_theme_color_override("font_color", _CAP_INK)
			l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.text = kit.display(token)
			l.scale = Vector2(s, s)
			l.position = Vector2(3, 2) * s
			box.add_child(l)
		box.custom_minimum_size = Vector2(w, 12) * s
	parent.add_child(box)
	return shows


func _set_rendering(on: bool) -> void:
	if _world != null:
		_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on \
				else SubViewport.UPDATE_DISABLED
