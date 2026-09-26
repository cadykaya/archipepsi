extends RefCounted
## Track A2 -- what sits over the box on the screen, the same for every
## study: the shell's two large turn arrows at the screen's edges (as in
## `MenuShell._build_arrows`, in the approved Glyph arrow and keycap art),
## a prompt line of real bindings, a pointer that TRAVELS to what it
## clicks (the player's hand, not the interface, is what moves), and a
## caption that says this is a study on sample data.
##
## Screen space, 1920 x 1080, Glyph pixels at integer scale.

const SCALE := 3
const INK := Color("#e8eef6")
const INK_DIM := Color("#9ba5b6")
const CAPTION := Color("#ffd45c")

var layer: CanvasLayer
var pointer: TextureRect
var ring: TextureRect
var _kit: RefCounted
var _text: FontFile
var _keycap: Texture2D
var _prompts: HBoxContainer
var _turn_keys: Array = []


func _init(parent: Node, kit: RefCounted, harness_dir: String) -> void:
	_kit = kit
	_text = load(harness_dir + "/ui_text.fnt") as FontFile
	_keycap = load(harness_dir + "/panel_keycap.png")
	layer = CanvasLayer.new()
	layer.layer = 10
	parent.add_child(layer)
	_arrows(harness_dir)
	_prompts = HBoxContainer.new()
	_prompts.add_theme_constant_override("separation", 36)
	_prompts.position = Vector2(150, 1080 - 58)
	layer.add_child(_prompts)
	pointer = TextureRect.new()
	pointer.texture = ImageTexture.create_from_image(_arrow_cursor())
	pointer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pointer.scale = Vector2(3, 3)
	pointer.visible = false
	ring = TextureRect.new()
	ring.texture = ImageTexture.create_from_image(_ring_image())
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.pivot_offset = Vector2(16, 16)
	ring.modulate = Color(1, 1, 1, 0)
	layer.add_child(ring)
	layer.add_child(pointer)


func text(parent: Node, s: String, pos: Vector2, colour: Color,
		k := SCALE) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _text)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", colour)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.text = s.to_upper()
	l.scale = Vector2(k, k)
	l.position = pos
	parent.add_child(l)
	return l


func keycap(parent: Node, key: String, pos := Vector2.ZERO) -> Control:
	var box := Control.new()
	box.position = pos
	var patch := NinePatchRect.new()
	patch.texture = _keycap
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.patch_margin_left = 2
	patch.patch_margin_top = 2
	patch.patch_margin_right = 1
	patch.patch_margin_bottom = 3
	var w := maxi(12, int(_text.get_string_size(key.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 6)
	patch.size = Vector2(w, 12)
	patch.scale = Vector2(SCALE, SCALE)
	box.add_child(patch)
	var l := text(box, key, Vector2(3 * SCALE, 2 * SCALE), INK)
	l.add_theme_color_override("font_color", Color("#26292d"))
	box.custom_minimum_size = Vector2(w * SCALE, 12 * SCALE)
	parent.add_child(box)
	return box


func _arrows(harness_dir: String) -> void:
	for side: int in [1, -1]:
		var icon := TextureRect.new()
		icon.texture = load("%s/icon_arrow_%s.png" % [harness_dir,
				"left" if side == 1 else "right"])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.scale = Vector2(6, 6)
		icon.modulate = INK_DIM
		var x := 34.0 if side == 1 else 1920.0 - 34.0 - 72.0
		icon.position = Vector2(x, 540 - 36)
		layer.add_child(icon)
		_turn_keys.append(keycap(layer, "Q" if side == 1 else "E",
				Vector2(x + 18, 540 + 52)))


## The prompts follow the device last used: the turn keys at the edges
## become the pad's shoulders (Production's menu_page_left/right: Q/LB,
## E/RB). The words in the prompt line are the caller's.
func device(pad: bool) -> void:
	for i in _turn_keys.size():
		var old: Control = _turn_keys[i]
		var pos := old.position
		old.queue_free()
		layer.remove_child(old)
		var key := ("LB" if i == 0 else "RB") if pad else ("Q" if i == 0 else "E")
		var w := maxf(12.0, _text.get_string_size(key,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0) * SCALE
		# Centred where the one-letter cap stood.
		_turn_keys[i] = keycap(layer, key, pos + Vector2((36.0 - w) * 0.5, 0))


## The prompt line: `pairs` of [key, words].
func prompts(pairs: Array) -> void:
	for child in _prompts.get_children():
		child.queue_free()
		_prompts.remove_child(child)
	for pair: Array in pairs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		keycap(row, str(pair[0]))
		var words := Control.new()
		var l := text(words, str(pair[1]), Vector2(0, 2 * SCALE), INK_DIM)
		words.custom_minimum_size = Vector2(
				_text.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 8).x * SCALE, 12 * SCALE)
		row.add_child(words)
		_prompts.add_child(row)


func caption(lines: Array) -> void:
	for i in lines.size():
		text(layer, str(lines[i]), Vector2(24, 18 + i * 30),
				CAPTION if i == 0 else INK_DIM, 3 if i == 0 else 2)


## The hand: to a screen point over `seconds` (it is the player moving,
## so it animates in reduced motion too -- instantly there).
func point_at(screen: Vector2, seconds := 0.35) -> void:
	pointer.visible = true
	_kit.go(pointer, "position", screen - Vector2(2, 2), seconds, "out")


func show_pointer(screen: Vector2) -> void:
	pointer.visible = true
	pointer.position = screen - Vector2(2, 2)


func click() -> void:
	ring.position = pointer.position + Vector2(2, 2) - Vector2(16, 16)
	ring.scale = Vector2(0.4, 0.4)
	ring.modulate = Color(1, 1, 1, 0.9)
	_kit.go(ring, "scale", Vector2(1.2, 1.2), 0.25, "out")
	_kit.go(ring, "modulate", Color(1, 1, 1, 0.0), 0.3, "out")


static func _arrow_cursor() -> Image:
	var rows := [
		"X...........",
		"XX..........",
		"XWX.........",
		"XWWX........",
		"XWWWX.......",
		"XWWWWX......",
		"XWWWWWX.....",
		"XWWWWWWX....",
		"XWWWWWWWX...",
		"XWWWWWWWWX..",
		"XWWWWWXXXXX.",
		"XWWXWWX.....",
		"XWX.XWWX....",
		"XX..XWWX....",
		"X....XWWX...",
		".....XXX....",
	]
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 12:
			var ch := str(rows[y])[x]
			img.set_pixel(x, y, Color(0.05, 0.06, 0.08) if ch == "X"
					else Color.WHITE if ch == "W" else Color(0, 0, 0, 0))
	return img


static func _ring_image() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			img.set_pixel(x, y, Color(0.22, 0.84, 0.78, 1.0)
					if d > 12.0 and d < 14.5 else Color(0, 0, 0, 0))
	return img
