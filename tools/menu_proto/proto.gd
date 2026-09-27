extends Node3D
## THE REVIEW PROTOTYPE'S MAIN: builds the box, loads the sample, and routes
## every input the way Production's MenuShell does.
##
##   .tools/godot --path tools/menu_proto                 hands-on
##   ... -- --reduced --save=progressed --equipment=base  start states
##   ... --write-movie f.png --fixed-fps 30 -- --tape=res://tapes/x.json --cursor
##   ... --headless -- --test=res://tapes/x.json          assertions
##
## Input, as MenuShell (Production CK9) routes it:
## * `pause` (Esc / Start) closes the menu from any wall; closed, it opens
##   on Settings. `inventory` (Tab / Back) turns to Equipment, and closes
##   when already there; closed, it opens on Equipment.
## * `menu_page_left` / `menu_page_right` (Q / E, LB / RB) turn, and a turn
##   may be retargeted mid-way.
## * While the eye is turning, every other input is dropped (MenuShell does
##   the same). The Map face's own keys are MapFace's own.
##
## A TAPE is the same input, scripted: real InputEvents pushed through
## `Input.parse_input_event`, so a capture or a test drives the very code a
## hand does. It is NOT hands-on verification, and the review says so.

const SAMPLE := "res://sample/sample.json"

var kit: Kit
var shell: Shell
var overlay: Overlay
var faces := {}
var sample: Dictionary
var open := true
var args := {}
var save := "walked"
var equipment_variant := "stress"
var pointer := Vector2(-1, -1)
var _stick := {}
var _stick_repeat := 0.0
var _drag_button := 0
var _tape: Array = []
var _tape_t := 0.0
var _tape_i := 0
var _testing := false
var _failures: Array = []
var _checks := 0
var _marks: Array = []
var _frame := 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Kit.BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#5c6570")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	kit = Kit.new(_asset_dir())
	kit.reduced = args.has("reduced")
	shell = Shell.new()
	add_child(shell)
	shell.setup(kit)
	overlay = Overlay.new()
	add_child(overlay)
	overlay.setup(kit)
	overlay.cursor_on = args.has("cursor")
	overlay.text_prompts = args.has("text-prompts")
	sample = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
	save = str(args.get("save", "walked"))
	equipment_variant = str(args.get("equipment", "stress"))
	faces["equipment"] = FaceEquipment.new()
	faces["map"] = FaceMap.new()
	faces["journal"] = FaceJournal.new()
	faces["settings"] = FaceSettings.new()
	for page: String in faces:
		faces[page].setup(kit, shell)
	(faces["journal"] as FaceJournal).bind(faces["map"])
	(faces["settings"] as FaceSettings).bind(self)
	load_sample()
	shell.face(str(args.get("page", "equipment")))
	shell.turned.connect(func(_p: String) -> void: _refresh())
	_refresh()
	if args.has("tape"):
		_load_tape(str(args["tape"]))
	elif args.has("test"):
		_testing = true
		_load_tape(str(args["test"]))


## The Glyph assets: the committed `assets/ui` of this checkout, or a copy
## beside the project when the prototype travels alone (the review zip).
func _asset_dir() -> String:
	var here := ProjectSettings.globalize_path("res://")
	for d: String in [here.path_join("ui"), here.path_join("../../assets/ui")]:
		if FileAccess.file_exists(d.path_join("ui_text.fnt")):
			return d.simplify_path()
	push_error("proto: no Glyph assets beside the project or in assets/ui")
	return here


## (Re)load the faces from the sample: the save for Map and Journal (the
## SAME save for both), the equipment variant for Equipment.
func load_sample() -> void:
	(faces["equipment"] as FaceEquipment).load_data(
			sample["equipment"][equipment_variant])
	var s: Dictionary = sample["saves"][save]
	(faces["map"] as FaceMap).load_data(s["map"], sample)
	(faces["journal"] as FaceJournal).load_data(s["journal"], s["map"], save)
	(faces["settings"] as FaceSettings).load_data()
	_refresh()


func set_save(name: String) -> void:
	save = name
	load_sample()


func set_equipment(variant: String) -> void:
	equipment_variant = variant
	(faces["equipment"] as FaceEquipment).load_data(
			sample["equipment"][equipment_variant])
	_refresh()


func set_reduced(on: bool) -> void:
	kit.reduced = on
	_refresh()


func _refresh() -> void:
	var front := shell.front_page()
	overlay.edges(Kit.TITLES[shell.neighbour(1)], Kit.TITLES[shell.neighbour(-1)])
	overlay.prompts(faces[front].prompts() if open else [])
	overlay.status("INPUT: %s    MOTION: %s" % [
			"PAD" if overlay.device == "pad" else "KEYBOARD AND MOUSE",
			"REDUCED" if kit.reduced else "FULL"])
	overlay.show_closed(not open)
	shell.visible = open


# ------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	_note_device(event)
	if event is InputEventMouseMotion:
		pointer = (event as InputEventMouseMotion).position
		overlay.pointer(pointer)
	if not open:
		if event.is_action_pressed("inventory"):
			_open("equipment")
		elif event.is_action_pressed("pause"):
			_open("settings")
		return
	if event.is_action_pressed("pause"):
		_close()
		return
	if event.is_action_pressed("inventory"):
		if shell.front_page() == "equipment":
			_close()
		else:
			shell.show_page("equipment")
		return
	if event.is_action_pressed("menu_page_left"):
		shell.turn(1)
		return
	if event.is_action_pressed("menu_page_right"):
		shell.turn(-1)
		return
	if shell.is_turning():
		return                          # MenuShell drops it too
	var front := shell.front_page()
	var f: Object = faces[front]
	if event is InputEventMouse:
		_mouse(event as InputEventMouse, f, front)
		_refresh_prompts()
		return
	if f.has_method("raw_input") and f.call("raw_input", event):
		_refresh_prompts()
		return
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		_stick[m.axis] = m.axis_value
		return
	if event.is_action_pressed("ui_up", true):
		f.call("nav", Vector2i(0, -1))
	elif event.is_action_pressed("ui_down", true):
		f.call("nav", Vector2i(0, 1))
	elif event.is_action_pressed("ui_left", true):
		f.call("nav", Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right", true):
		f.call("nav", Vector2i(1, 0))
	elif event.is_action_pressed("ui_accept"):
		f.call("accept")
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		f.call("back")
	else:
		return
	_refresh_prompts()


func _mouse(event: InputEventMouse, f: Object, front: String) -> void:
	var hit := shell.page_hit(event.position)
	var on_front: bool = not hit.is_empty() and str(hit["page"]) == front
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _drag_button != 0 and f.has_method("drag"):
			f.call("drag", motion.relative, _drag_button)
			return
		if on_front:
			f.call("hover_at", hit["at"])
		if f.has_method("pointer_ray"):
			f.call("pointer_ray", hit)
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	if not button.pressed:
		if button.button_index == _drag_button:
			_drag_button = 0
		# A release that did not drag is a pick, on the Map (MapFace turns
		# the view on a drag; the prototype picks on a still release).
		if f.has_method("release"):
			f.call("release", hit, button.button_index)
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
			if button.button_index == MOUSE_BUTTON_LEFT:
				overlay.click_ring(event.position)
				var edge := overlay.edge_at(event.position)
				if edge != "":
					shell.turn(1 if edge == "left" else -1)
					return
			var used := false
			if on_front and button.button_index == MOUSE_BUTTON_LEFT:
				used = f.call("click", hit["at"])
			if not used and f.has_method("drag") and on_front:
				_drag_button = button.button_index
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if on_front:
				f.call("wheel", hit["at"],
						-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)


func _note_device(event: InputEvent) -> void:
	var was := overlay.device
	if event is InputEventJoypadButton:
		overlay.device = "pad"
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.4:
			overlay.device = "pad"
	elif event is InputEventKey or event is InputEventMouseButton:
		overlay.device = "kbm"
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 2.0:
			overlay.device = "kbm"
	if overlay.device != was:
		_refresh()


func _refresh_prompts() -> void:
	if open:
		overlay.prompts(faces[shell.front_page()].prompts())


func _open(page: String) -> void:
	open = true
	shell.face(page)
	_refresh()


func _close() -> void:
	open = false
	_drag_button = 0
	_refresh()


# ------------------------------------------------------------ frame

var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	# --shot=<png> [--shot-at=<s>]: one frame, then quit (development).
	if args.has("shot") and _clock >= float(args.get("shot-at", "0.6")):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(str(args["shot"]))
		args.erase("shot")
		if _tape.is_empty():
			get_tree().quit(0)
	_run_tape(delta)
	kit.step(delta)
	for page: String in faces:
		faces[page].tick(delta)
	_sticks(delta)
	_frame += 1


## The left stick moves focus on the list faces, with a repeat; the Map
## face reads both sticks itself (MapFace._apply_sticks).
func _sticks(delta: float) -> void:
	if not open or shell.is_turning():
		return
	var f: Object = faces[shell.front_page()]
	if f.has_method("sticks"):
		f.call("sticks", _stick, delta)
		return
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
		f.call("nav", Vector2i(0, signi(int(signf(y)))))
	else:
		f.call("nav", Vector2i(signi(int(signf(x))), 0))
	_refresh_prompts()


# ------------------------------------------------------------ state

## Everything a test asserts on, and nothing it could not see.
func snapshot() -> Dictionary:
	var out := {"open": open, "front": shell.front_page(),
		"turning": shell.is_turning(), "yaw": shell.camera.rotation.y,
		"heading": shell.heading, "reduced": kit.reduced,
		"device": overlay.device, "save": save,
		"equipment_variant": equipment_variant,
		"missing_glyphs": kit.missing.duplicate(),
		"missing_where": kit.missing_where.duplicate(), "busy": kit.busy()}
	for page: String in faces:
		out[page] = faces[page].state()
	return out


# ------------------------------------------------------------ tapes

func _load_tape(path: String) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if raw == null:
		push_error("proto: could not read tape %s" % path)
		get_tree().quit(2)
		return
	var steps: Array = (raw as Dictionary).get("steps", [])
	var t := 0.0
	for step: Dictionary in steps:
		if step.has("at"):
			t = float(step["at"])
		elif step.has("after"):
			t += float(step["after"])
		step["t"] = t
		_tape.append(step)
		if step.has("mouse_to") or step.has("drag"):
			t += float(step.get("dur", 0.3))


func _run_tape(delta: float) -> void:
	if _tape.is_empty():
		return
	_tape_t += delta
	while _tape_i < _tape.size() and float(_tape[_tape_i]["t"]) <= _tape_t + 0.0001:
		_do(_tape[_tape_i])
		_tape_i += 1
	for glide: Dictionary in _glides.duplicate():
		_glide_step(glide)


var _glides: Array = []


func _do(step: Dictionary) -> void:
	if step.has("key"):
		_key(str(step["key"]), true)
		_key(str(step["key"]), false)
	if step.has("key_down"):
		_key(str(step["key_down"]), true)
	if step.has("key_up"):
		_key(str(step["key_up"]), false)
	if step.has("pad"):
		_pad(str(step["pad"]), true)
		_pad(str(step["pad"]), false)
	if step.has("pad_axis"):
		var ev := InputEventJoypadMotion.new()
		ev.axis = int(step["pad_axis"][0])
		ev.axis_value = float(step["pad_axis"][1])
		Input.parse_input_event(ev)
	if step.has("mouse"):
		_move(Vector2(step["mouse"][0], step["mouse"][1]))
	if step.has("mouse_to"):
		_glides.append({"from": pointer if pointer.x >= 0 else Vector2(960, 900),
			"to": Vector2(step["mouse_to"][0], step["mouse_to"][1]),
			"t0": _tape_t, "dur": float(step.get("dur", 0.3)), "button": 0})
	# Page-relative and room-relative pointer steps: the tape names WHAT it
	# points at, and the box says where that is on the screen right now.
	if step.has("mouse_page"):
		_move(_page_screen(step["mouse_page"]))
	if step.has("mouse_to_page"):
		_glides.append({"from": pointer if pointer.x >= 0 else Vector2(960, 900),
			"to": _page_screen(step["mouse_to_page"]), "t0": _tape_t,
			"dur": float(step.get("dur", 0.3)), "button": 0})
	if step.has("click_page"):
		var at := _page_screen(step["click_page"])
		_move(at)
		_button(at, MOUSE_BUTTON_LEFT, true)
		_button(at, MOUSE_BUTTON_LEFT, false)
	if step.has("click_room"):
		var at := _room_screen(str(step["click_room"]))
		_move(at)
		_button(at, MOUSE_BUTTON_LEFT, true)
		_button(at, MOUSE_BUTTON_LEFT, false)
	if step.has("wheel_page"):
		var at := _page_screen(step["wheel_page"])
		_move(at)
		var b := MOUSE_BUTTON_WHEEL_DOWN if int(step["wheel_page"][2]) > 0 \
				else MOUSE_BUTTON_WHEEL_UP
		_button(at, b, true)
		_button(at, b, false)
	if step.has("click"):
		var at := Vector2(step["click"][0], step["click"][1])
		_move(at)
		_button(at, MOUSE_BUTTON_LEFT, true)
		_button(at, MOUSE_BUTTON_LEFT, false)
	if step.has("wheel"):
		var at := Vector2(step["wheel"][0], step["wheel"][1])
		_move(at)
		var b := MOUSE_BUTTON_WHEEL_DOWN if int(step["wheel"][2]) > 0 \
				else MOUSE_BUTTON_WHEEL_UP
		_button(at, b, true)
		_button(at, b, false)
	if step.has("drag"):
		var d: Array = step["drag"]
		var from := Vector2(d[0], d[1])
		var button := MOUSE_BUTTON_RIGHT if d.size() > 4 and str(d[4]) == "right" \
				else MOUSE_BUTTON_LEFT
		_move(from)
		_button(from, button, true)
		_glides.append({"from": from, "to": Vector2(d[2], d[3]), "t0": _tape_t,
			"dur": float(step.get("dur", 0.4)), "button": button})
	if step.has("set"):
		var s: Dictionary = step["set"]
		if s.has("reduced"):
			set_reduced(bool(s["reduced"]))
		if s.has("save"):
			set_save(str(s["save"]))
		if s.has("equipment"):
			set_equipment(str(s["equipment"]))
		if s.has("text_prompts"):
			overlay.text_prompts = bool(s["text_prompts"])
			_refresh()
	if step.has("mark"):
		_marks.append({"label": str(step["mark"]), "frame": _frame,
			"t": _tape_t})
	if step.has("check"):
		_check(step["check"])
	if step.has("quit"):
		_finish()


func _glide_step(g: Dictionary) -> void:
	var u := clampf((_tape_t - float(g["t0"])) / maxf(float(g["dur"]), 0.001),
			0.0, 1.0)
	var at: Vector2 = (g["from"] as Vector2).lerp(g["to"], Kit.ease_of(u, "out"))
	_move(at, int(g["button"]))
	if u >= 1.0:
		if int(g["button"]) != 0:
			_button(at, int(g["button"]), false)
		_glides.erase(g)


func _page_screen(v: Array) -> Vector2:
	return shell.screen_of(shell.front_page(), Vector2(float(v[0]), float(v[1])))


func _room_screen(id: String) -> Vector2:
	var mf: FaceMap = faces["map"]
	var c: Vector3 = mf._rooms[id]["centre"]
	return shell.camera.unproject_position(mf.face.global_transform
			* mf.face_pos(c))


func _key(name: String, down: bool) -> void:
	var ev := InputEventKey.new()
	var code := OS.find_keycode_from_string(name)
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


const PAD := {"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "x": JOY_BUTTON_X,
	"y": JOY_BUTTON_Y, "lb": JOY_BUTTON_LEFT_SHOULDER,
	"rb": JOY_BUTTON_RIGHT_SHOULDER, "start": JOY_BUTTON_START,
	"back": JOY_BUTTON_BACK, "up": JOY_BUTTON_DPAD_UP,
	"down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT,
	"right": JOY_BUTTON_DPAD_RIGHT}


func _pad(name: String, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = PAD[name]
	ev.pressed = down
	ev.pressure = 1.0 if down else 0.0
	Input.parse_input_event(ev)


## An injected event arrives as if from the OS: in WINDOW pixels, which the
## root viewport then stretches into its own 1920 x 1080. So a tape's point
## (viewport pixels) is carried back through the stretch first.
func _win(at: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * at


func _move(at: Vector2, held := 0) -> void:
	var ev := InputEventMouseMotion.new()
	var from := _win(pointer) if pointer.x >= 0 else _win(at)
	ev.position = _win(at)
	ev.global_position = ev.position
	ev.relative = ev.position - from
	if held == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	elif held == MOUSE_BUTTON_RIGHT:
		ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(ev)


func _button(at: Vector2, index: int, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = _win(at)
	ev.global_position = ev.position
	ev.button_index = index
	ev.pressed = down
	Input.parse_input_event(ev)


## A check: `path` into snapshot() (dots), and one of eq / ne / gt / lt /
## true / false / changed_from (a value remembered under `remember`).
var _remembered := {}


func _check(c: Dictionary) -> void:
	_checks += 1
	var value: Variant = _dig(snapshot(), str(c["path"]))
	if c.has("remember"):
		_remembered[str(c["remember"])] = value
		return
	var ok := true
	var want: Variant = null
	if c.has("eq"):
		want = c["eq"]
		if (value is int or value is float) and (want is int or want is float):
			ok = absf(float(value) - float(want)) < 0.000001
		else:
			ok = str(value) == str(want)
	elif c.has("same_path"):
		want = _dig(snapshot(), str(c["same_path"]))
		ok = absf(float(value) - float(want)) < 0.0001 if (value is float or value is int) \
				else str(value) == str(want)
	elif c.has("ne"):
		want = c["ne"]
		ok = str(value) != str(want)
	elif c.has("gt"):
		want = c["gt"]
		ok = float(value) > float(want)
	elif c.has("lt"):
		want = c["lt"]
		ok = float(value) < float(want)
	elif c.has("empty"):
		want = "empty"
		var n := (value as Dictionary).size() if value is Dictionary else (
				(value as Array).size() if value is Array else str(value).length())
		ok = (n == 0) == bool(c["empty"])
	elif c.has("near"):
		want = c["near"]
		ok = absf(float(value) - float(want)) <= float(c.get("tol", 0.01))
	elif c.has("same_as"):
		want = _remembered.get(str(c["same_as"]))
		ok = str(value) == str(want)
	elif c.has("differs_from"):
		want = _remembered.get(str(c["differs_from"]))
		ok = str(value) != str(want)
	var why := str(c.get("why", c["path"]))
	if ok:
		print("[test] ok   %s" % why)
	else:
		_failures.append(why)
		print("[test] FAIL %s: got %s, wanted %s %s" % [why, str(value),
			"eq" if c.has("eq") else "cmp", str(want)])


func _dig(d: Variant, path: String) -> Variant:
	var at: Variant = d
	for part in path.split("."):
		if at is Dictionary and (at as Dictionary).has(part):
			at = at[part]
		elif at is Array and part.is_valid_int() and int(part) < (at as Array).size():
			at = at[int(part)]
		else:
			return null
	return at


func _finish() -> void:
	if not kit.missing.is_empty():
		print("[proto] characters the face lacks were asked for: %s"
				% str(kit.missing))
	var out := str(args.get("marks", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"marks": _marks, "frames": _frame,
			"missing_glyphs": kit.missing}, " "))
		f.close()
	if _testing:
		print("[test] %d check(s), %d failure(s)" % [_checks, _failures.size()])
		get_tree().quit(1 if not _failures.is_empty() else 0)
	else:
		get_tree().quit(0)
