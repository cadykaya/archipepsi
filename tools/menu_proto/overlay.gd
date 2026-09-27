class_name Overlay
extends CanvasLayer
## WHAT IS DRAWN ON THE GLASS, not on a wall: the review caption, the turn
## cues at the screen edges (MenuShell's arrows, clickable), the prompt
## line, and -- for a capture only -- a drawn pointer.
##
## **Prompts follow the device last used.** A control is written once, per
## device, in CONTROLS; a face asks for an action by name. A device symbol
## is drawn from the Glyph set, and its readable TEXT fallback (icons.json)
## is what shows where the symbol does not -- or everywhere, when the
## review's PROMPTS setting is TEXT.

const SCALE := 3.0
const INK := Color("#e8eef6")
const INK_DIM := Color("#9ba5b6")
const INK_FAINT := Color("#6f7885")
const SIGNAL := Color("#39d7c8")
const CAP_INK := Color("#26292d")

## Every control the prototype prompts for, per device. A token is:
##   "@icon"      a bare device symbol (pad buttons, mouse)
##   "#icon"      a keycap with a symbol in it (the arrow keys)
##   "WORD"       a keycap with that text (the keyboard)
## The bindings are Production's (project.godot, MapFace._on_key /
## _on_pad_button); the words are the prototype's.
const CONTROLS := {
	"turn_left": {"kbm": ["Q"], "pad": ["@pad_lb"]},
	"turn_right": {"kbm": ["E"], "pad": ["@pad_rb"]},
	"close": {"kbm": ["ESC"], "pad": ["@pad_start"]},
	"equipment": {"kbm": ["TAB"], "pad": ["@pad_back"]},
	"move": {"kbm": ["#arrow_up", "#arrow_down"], "pad": ["@pad_dpad"]},
	"move_h": {"kbm": ["#arrow_left", "#arrow_right"], "pad": ["@pad_dpad"]},
	"into": {"kbm": ["#arrow_right"], "pad": ["@pad_dpad_right"]},
	"out": {"kbm": ["#arrow_left"], "pad": ["@pad_dpad_left"]},
	"accept": {"kbm": ["ENTER"], "pad": ["@pad_face_south"]},
	"back": {"kbm": ["#arrow_left"], "pad": ["@pad_face_east"]},
	"click": {"kbm": ["@mouse_left"], "pad": []},
	"wheel": {"kbm": ["@mouse_wheel"], "pad": ["@pad_rstick"]},
	"place": {"kbm": ["[", "]"], "pad": ["@pad_dpad_left", "@pad_dpad_right"]},
	"overview": {"kbm": ["C"], "pad": ["@pad_face_north"]},
	"zoom": {"kbm": ["+", "-"], "pad": ["@pad_lt", "@pad_rt"]},
	"orbit": {"kbm": ["#arrow_left", "#arrow_right"], "pad": ["@pad_rstick"]},
	"pan": {"kbm": ["W", "A", "S", "D"], "pad": ["@pad_lstick"]},
	"drag": {"kbm": ["@mouse_left"], "pad": []},
	"detail": {"kbm": ["ENTER"], "pad": ["@pad_face_south"]},
	"closer": {"kbm": ["ENTER"], "pad": ["@pad_face_east"]},
	"follow": {"kbm": ["E"], "pad": ["@pad_rb"]},
	"back_view": {"kbm": ["BACKSPACE"], "pad": ["@pad_face_east"]},
	"change": {"kbm": ["#arrow_left", "#arrow_right"], "pad": ["@pad_dpad"]},
}

var kit: Kit
var device := "kbm"        # the device last used: kbm | pad
var text_prompts := false  # the review's PROMPTS: TEXT setting
var cursor_on := false
var edge_rects := {}       # "left"/"right" -> Rect2 (screen), clickable

var _root: Control
var _prompt_row: HBoxContainer
var _edges := {}
var _status: Label
var _closed: Control
var _cursor: TextureRect
var _ring: TextureRect
var _last_prompts: Array = []
var _say: Label
var shown: Array = []       # the prompt line as drawn: [{action, shows, words}]


func setup(k: Kit) -> void:
	kit = k
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_caption()
	_status = text(_root, "", Vector2(0, 18), INK_DIM, 2)
	_prompt_row = HBoxContainer.new()
	_prompt_row.add_theme_constant_override("separation", 40)
	_prompt_row.position = Vector2(120, 1080 - 62)
	_root.add_child(_prompt_row)
	for side in ["left", "right"]:
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(box)
		_edges[side] = box
	_closed = Control.new()
	_closed.visible = false
	_root.add_child(_closed)
	_ring = TextureRect.new()
	_ring.texture = ImageTexture.create_from_image(_ring_image())
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ring.pivot_offset = Vector2(16, 16)
	_ring.modulate = Color(1, 1, 1, 0)
	_root.add_child(_ring)
	_cursor = TextureRect.new()
	_cursor.texture = ImageTexture.create_from_image(_arrow_cursor())
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.scale = Vector2(3, 3)
	_cursor.visible = false
	_root.add_child(_cursor)


func _caption() -> void:
	text(_root, "ARCHIPEPSI MENU -- ART-LANE REVIEW PROTOTYPE, NOT THE GAME'S MENU",
			Vector2(24, 16), Color("#ffd84d"), 2)
	text(_root, "SAMPLE DATA: PRODUCTION A2B9DF6 FIXTURES, + LAYOUT-STRESS "
			+ "ECHOES TAGGED AUTHORED. EQUIPPING IS A LOCAL PREVIEW.",
			Vector2(24, 38), INK_DIM, 2)


func text(parent: Node, s: String, pos: Vector2, colour: Color,
		k := SCALE) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", kit.text_font)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", colour)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.text = kit.display(s)
	l.scale = Vector2(k, k)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## One control as drawn: a keycap (text or symbol inside) or a bare symbol.
func control(parent: Node, token: String) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bare := token.begins_with("@")
	var icon := token.substr(1) if (bare or token.begins_with("#")) else ""
	if text_prompts and icon != "":
		# The readable fallback, in a keycap: what shows where the symbol
		# does not.
		token = str(kit.icon_text.get(icon, icon.to_upper()))
		bare = false
		icon = ""
	# What this control shows, for the tapes: a bare symbol, a symbol in a
	# keycap, or text in a keycap.
	box.set_meta("shows", ("sym:" if bare else "cap:") + icon if icon != ""
			else "key:" + token)
	if bare:
		var t := TextureRect.new()
		t.texture = kit.icons.get(icon)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.scale = Vector2(SCALE, SCALE)
		t.modulate = INK
		box.add_child(t)
		box.custom_minimum_size = Vector2(12, 12) * SCALE
	else:
		var patch := NinePatchRect.new()
		patch.texture = kit.keycap
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patch.patch_margin_left = 2
		patch.patch_margin_top = 2
		patch.patch_margin_right = 1
		patch.patch_margin_bottom = 3
		var w := 14.0
		if icon == "":
			w = maxf(12.0, kit.measure(token, 1) + 6.0)
		patch.size = Vector2(w, 12)
		patch.scale = Vector2(SCALE, SCALE)
		box.add_child(patch)
		if icon != "":
			var t := TextureRect.new()
			t.texture = kit.icons.get(icon)
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.scale = Vector2(SCALE, SCALE) * 0.75
			t.position = Vector2(2.5, 0.5) * SCALE
			t.modulate = CAP_INK
			box.add_child(t)
		else:
			var l := text(box, token, Vector2(3, 2) * SCALE, CAP_INK, SCALE)
			l.add_theme_color_override("font_color", CAP_INK)
		box.custom_minimum_size = Vector2(w, 12) * SCALE
	parent.add_child(box)
	return box


## The prompt line: [[action, words], ...] for the front face's state.
func prompts(pairs: Array) -> void:
	_last_prompts = pairs
	shown = []
	for child in _prompt_row.get_children():
		_prompt_row.remove_child(child)
		child.queue_free()
	for pair: Array in pairs:
		# The turns are at the screen's edges already, with their walls'
		# names; the line keeps to what THIS wall does.
		if str(pair[0]) in ["turn_left", "turn_right"]:
			continue
		var tokens: Array = (CONTROLS.get(str(pair[0]), {}) as Dictionary).get(
				device, [])
		if tokens.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shows := []
		for token: String in tokens:
			shows.append(str(control(row, token).get_meta("shows")))
		shown.append({"action": str(pair[0]), "shows": shows,
			"words": str(pair[1])})
		var words := Control.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := text(words, str(pair[1]), Vector2(4, 2 * SCALE), INK_DIM)
		words.custom_minimum_size = Vector2(
				kit.measure(l.text, 1) * SCALE + 8, 12 * SCALE)
		row.add_child(words)
		_prompt_row.add_child(row)


func refresh_prompts() -> void:
	prompts(_last_prompts)


## The turn cues at the screen edges: the arrow, the wall it turns to, and
## the control. Clickable, like MenuShell's arrows.
func edges(left_name: String, right_name: String) -> void:
	for side: String in ["left", "right"]:
		var box: Control = _edges[side]
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		var arrow := TextureRect.new()
		arrow.texture = kit.icons.get("arrow_%s" % side)
		arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arrow.scale = Vector2(5, 5)
		arrow.modulate = INK_DIM
		box.add_child(arrow)
		var name := left_name if side == "left" else right_name
		var action := "turn_left" if side == "left" else "turn_right"
		var label := text(box, name, Vector2(0, 66), INK_FAINT, 2)
		var tokens: Array = CONTROLS[action][device]
		var cap := control(box, tokens[0])
		cap.position = Vector2(0, 88)
		var w := maxf(60.0, kit.measure(name, 2))
		if side == "left":
			box.position = Vector2(18, 470)
		else:
			box.position = Vector2(1920 - 18 - w, 470)
			arrow.position.x = w - 60
			label.position.x = w - kit.measure(name, 2)
			cap.position.x = w - cap.custom_minimum_size.x
		edge_rects[side] = Rect2(box.position - Vector2(8, 8),
				Vector2(w + 16, 140))


## A capture's caption: what scripted input is being made, in the review's
## own colour so it is never mistaken for the interface.
func say(line: String) -> void:
	if _say == null:
		_say = text(_root, "", Vector2(24, 60), Color("#ffd84d"), 2)
	_say.text = kit.display(line)


func status(line: String) -> void:
	_status.text = kit.display(line)
	_status.position.x = 1920 - 24 - kit.measure(line, 2)


func show_closed(on: bool) -> void:
	_closed.visible = on
	for child in _closed.get_children():
		_closed.remove_child(child)
		child.queue_free()
	if not on:
		return
	var y := 470.0
	text(_closed, "THE MENU IS CLOSED -- THE GAME WOULD BE HERE", Vector2(560, y),
			INK_DIM, 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.position = Vector2(560, y + 60)
	_closed.add_child(row)
	for pair: Array in [["equipment", "EQUIPMENT"], ["close", "PAUSE -- SETTINGS"]]:
		for token: String in CONTROLS[pair[0]][device]:
			control(row, token)
		var words := Control.new()
		var l := text(words, str(pair[1]), Vector2(4, 6), INK_DIM)
		words.custom_minimum_size = Vector2(kit.measure(l.text, 1) * SCALE + 30, 36)
		row.add_child(words)


func edge_at(screen: Vector2) -> String:
	for side: String in edge_rects:
		if (edge_rects[side] as Rect2).has_point(screen):
			return side
	return ""


# ------------------------------------------------------------ the pointer

func pointer(screen: Vector2) -> void:
	_cursor.visible = cursor_on
	_cursor.position = screen - Vector2(2, 2)


func click_ring(screen: Vector2) -> void:
	if not cursor_on:
		return
	_ring.position = screen - Vector2(16, 16)
	_ring.scale = Vector2(0.4, 0.4)
	_ring.modulate = Color(1, 1, 1, 0.9)
	kit.go(_ring, "scale", Vector2(1.2, 1.2), 0.25, "out")
	kit.go(_ring, "modulate", Color(1, 1, 1, 0.0), 0.3, "out")


static func _arrow_cursor() -> Image:
	var rows := [
		"#.........",
		"##........",
		"#o#.......",
		"#oo#......",
		"#ooo#.....",
		"#oooo#....",
		"#ooooo#...",
		"#oooooo#..",
		"#ooooooo#.",
		"#oooo####.",
		"#o#oo#....",
		"##.#oo#...",
		"#..#oo#...",
		"....#oo#..",
		"....####..",
	]
	var img := Image.create(10, 15, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in (rows[y] as String).length():
			match (rows[y] as String)[x]:
				"#":
					img.set_pixel(x, y, Color("#0b0d10"))
				"o":
					img.set_pixel(x, y, Color("#f4f6fa"))
	return img


static func _ring_image() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			if absf(d - 13.0) < 1.2:
				img.set_pixel(x, y, Color("#f4f6fa"))
	return img
