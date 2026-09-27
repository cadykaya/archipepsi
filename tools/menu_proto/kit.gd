class_name Kit
extends RefCounted
## THE PROTOTYPE'S KIT: the box's measurements, the Glyph assets, the
## drawing primitives every face uses, and the one animation system.
##
## The box is Production's `MenuShell` as built (Production CK9, a2b9df6):
## four inward walls at DISTANCE 1.0, FOV 60, FILL 0.86, 1280 x 720 pages,
## a 0.42 s cubic in-out turn that reduced motion makes a cut.
##
## **One animation system, and it is always interruptible.** `go()` moves a
## property from wherever it is NOW; a second `go()` on the same property
## replaces the first mid-flight. Reduced motion sets the value at once.
## Anything that moves on its own (a gate's pulse, a hover's fade) asks
## `still()` first, so reduced motion covers secondary motion too.

const DISTANCE := 1.0
const FOV := 60.0
const FILL := 0.86
const PAGE := Vector2(1280, 720)
const TURN_SECONDS := 0.42
const PAGES: Array[String] = ["settings", "equipment", "map", "journal"]
## Production's face titles (MenuShell); the owner's names in brackets in
## the review, never on the wall.
const TITLES := {"settings": "SETTINGS", "equipment": "EQUIPMENT",
	"map": "MAP", "journal": "JOURNAL"}

# ---- palette. Text and marks are unshaded so they land on these exactly;
# walls and plates are lit, so the box has a light in it.
const BG := Color("#0b0d10")
const WALL := Color("#1b1f25")
const POST := Color("#0e1013")
const SLAB := Color("#15181c")
const PLATE := Color("#262b33")
const PLATE_HI := Color("#323843")
const INK := Color("#e8eef6")        # the text face's ink
const INK_DIM := Color("#9ba5b6")
const INK_FAINT := Color("#6f7885")
const SIGNAL := Color("#39d7c8")     # focus and "you can act on this" -- nothing else
const DEAD := Color("#4a4f57")        # marks only, never text: 2:1 on the wall
## Headings on a RAISED PLATE: the plate is lighter than the wall, so the
## wall's faint ink (3.7:1 there) drops to 2.6:1 on it; a heading steps up
## to this and keeps ~3.8:1. Text never goes below 3:1 on its ground.
const HEAD := Color("#8a94a3")
const SHADE := Color("#0b0d10")

var reduced := false                 # Production's motion_intensity <= 0
var device := "kbm"                  # the device last used: kbm | pad
var text_font: FontFile
var num_font: FontFile
var icons := {}                      # name -> Texture2D
var icon_text := {}                  # name -> readable fallback
var keycap: Texture2D                # the Glyph keycap nine-slice (2/2/1/3)
var missing := {}                    # characters asked for that the face lacks
var missing_where := {}              # ... and the first text that asked

var _tracks: Array = []
var _later: Array = []
var _materials := {}
var _chars := {}


func _init(asset_dir: String) -> void:
	text_font = _font(asset_dir.path_join("ui_text.fnt"))
	num_font = _font(asset_dir.path_join("ui_numerals.fnt"))
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			asset_dir.path_join("icons.json")))
	for name: String in meta:
		if name.begins_with("_"):
			continue
		var img := Image.load_from_file(asset_dir.path_join(
				str(meta[name]["file"])))
		icons[name] = ImageTexture.create_from_image(img)
		icon_text[name] = str(meta[name].get("text", name.to_upper()))
	keycap = ImageTexture.create_from_image(Image.load_from_file(
			asset_dir.path_join("panel_keycap.png")))
	# The characters the face HAS, read from its own .fnt.
	for line in FileAccess.get_file_as_string(
			asset_dir.path_join("ui_text.fnt")).split("\n"):
		if line.begins_with("char id="):
			_chars[int(line.split(" ")[1].trim_prefix("id="))] = true


## A bitmap font loaded at RUN time from the committed Glyph output, so the
## prototype always shows what `assets/ui` holds and nothing is copied.
## `fixed_size_scale_mode` ENABLED is what Godot's importer sets
## (measured by tools/content/run_font_import.sh: "imported 2, runtime
## parse 0"); a runtime parse needs it said.
static func _font(path: String) -> FontFile:
	var f := FontFile.new()
	var err := f.load_bitmap_font(path)
	if err != OK:
		push_error("kit: could not load %s (%d)" % [path, err])
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	return f


# ------------------------------------------------------------ geometry

static func wall_size() -> Vector2:
	var h := 2.0 * DISTANCE * tan(deg_to_rad(FOV * 0.5)) * FILL
	return Vector2(h * PAGE.x / PAGE.y, h)


## World units per page pixel on the wall plane.
static func px() -> float:
	return wall_size().y / PAGE.y


## Page pixels (from the wall's top-left) to a face's local space, `depth`
## world units in front of the wall.
static func at(page: Vector2, depth := 0.0) -> Vector3:
	var s := px()
	return Vector3((page.x - PAGE.x * 0.5) * s, (PAGE.y * 0.5 - page.y) * s,
			-DISTANCE + depth)


## Page pixels as an offset inside something already placed.
static func rel(v: Vector2, depth := 0.0) -> Vector3:
	var s := px()
	return Vector3(v.x * s, -v.y * s, depth)


## Wall `i` stands a quarter turn LEFT of wall `i - 1` (MenuShell._yaw_of).
static func yaw_of(quarter: int) -> float:
	return float(quarter) * PI * 0.5


# ------------------------------------------------------------ materials

func flat(colour: Color, alpha := 1.0) -> StandardMaterial3D:
	var key := "f%s/%.3f" % [colour.to_html(), alpha]
	if not _materials.has(key):
		_materials[key] = _unshaded(colour, alpha)
	return _materials[key]


## A material of its own, for a node whose colour is animated.
func own(colour: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := _unshaded(colour, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## A painted surface, not a screen: structureless grain, +/- 4 %, fixed
## seed. No seams, no panels, no bolts -- the facility texture has all
## three, which is why it is not used here.
var _grain: ImageTexture


func grain() -> ImageTexture:
	if _grain == null:
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260927
		for y in 256:
			for x in 256:
				var v := 1.0 + rng.randf_range(-0.04, 0.04)
				img.set_pixel(x, y, Color(v * 0.96, v * 0.96, v * 0.96))
		_grain = ImageTexture.create_from_image(img)
	return _grain


func wall_material() -> StandardMaterial3D:
	var key := "wall"
	if _materials.has(key):
		return _materials[key]
	var m := lit(WALL, true)
	m.albedo_texture = grain()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(5.0, 3.0, 1.0)
	_materials[key] = m
	return m


## Lit: walls, plates and the miniature. The box has a light in it, and a
## raised plate shades the wall behind it -- that is where the focus's
## depth comes from, not from a glow.
func lit(colour: Color, animated := false) -> StandardMaterial3D:
	var key := "l%s" % colour.to_html()
	if not animated and _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 1.0
	m.metallic_specular = 0.2
	# Ribbons are built with either winding: light both sides.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if animated:
		return m
	_materials[key] = m
	return m


static func _unshaded(colour: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(colour, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ------------------------------------------------------------ primitives

## A flat card `size` page px, its TOP-LEFT at `page`, `depth` off the wall.
func card(parent: Node3D, page: Vector2, size: Vector2, depth: float,
		material: Material, relative := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size * px()
	node.mesh = quad
	node.material_override = material
	node.position = rel(page + size * 0.5, depth) if relative \
			else at(page + size * 0.5, depth)
	parent.add_child(node)
	return node


## A raised plate: a thin box, lit, that shades the wall behind it.
func plate(parent: Node3D, page: Vector2, size: Vector2, depth: float,
		material: Material, thickness := 0.006) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x * px(), size.y * px(), thickness)
	node.mesh = box
	node.material_override = material
	node.position = at(page + size * 0.5, depth + thickness * 0.5)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


## The shadow a raised plate throws on the wall: two soft dark layers, down
## and to the right of it, ON the wall. The lift is read from this -- the
## focus is a thing standing off the wall, not a thing glowing on it.
func shadow(parent: Node3D, page: Vector2, size: Vector2, lift := 1.0,
		relative := false) -> void:
	for layer: Array in [[Vector2(12, 18), 14.0, 0.30], [Vector2(6, 9), 5.0, 0.45]]:
		var off: Vector2 = layer[0] * lift
		var grow: float = layer[1] * lift
		card(parent, page + off - Vector2(grow, grow) * 0.5,
				size + Vector2(grow, grow), 0.0006, flat(SHADE, layer[2]),
				relative)


## Glyph text, its top-left at `page`, at an integer multiple `k` of the
## face's 8 px design. The face is capitals only, so text is upper-cased
## for display -- the one change made to a Production string. A character
## the face does not have is shown as `?` and REPORTED (`missing`), never
## dropped and never swapped for a look-alike.
func label(parent: Node3D, text: String, page: Vector2, k: int,
		colour: Color, depth := 0.003, numerals := false,
		relative := false) -> Label3D:
	var l := Label3D.new()
	l.font = num_font if numerals else text_font
	l.font_size = 8
	l.pixel_size = px() * float(k)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.double_sided = true
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.modulate = colour
	l.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.line_spacing = 2.0
	l.text = text if numerals else display(text)
	l.position = rel(page, depth) if relative else at(page, depth)
	parent.add_child(l)
	return l


## What the face can print: upper case, and `?` (reported) for anything it
## lacks.
func display(text: String) -> String:
	var up := text.to_upper()
	var out := ""
	for i in up.length():
		var c := up.unicode_at(i)
		if c == 10 or c == 32 or _chars.has(c):
			out += up[i]
		else:
			missing[up[i]] = int(missing.get(up[i], 0)) + 1
			if not missing_where.has(up[i]):
				missing_where[up[i]] = text
			out += "?"
	return out


## How wide `text` is, in page px, at scale `k`.
func measure(text: String, k: int, numerals := false) -> float:
	var f := num_font if numerals else text_font
	var widest := 0.0
	for line in (text if numerals else display(text)).split("\n"):
		widest = maxf(widest, f.get_string_size(line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	return widest * float(k)


## Greedy word wrap to `width` page px at scale `k`, done HERE rather than
## by Label3D so a face knows exactly how many lines it drew. A word wider
## than the line is cut, never allowed to run off the plate.
func wrap(text: String, k: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	for para in display(text).split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var trial := word if line == "" else line + " " + word
			if measure(trial, k) <= width:
				line = trial
				continue
			if line != "":
				out.append(line)
			line = word
			while measure(line, k) > width and line.length() > 1:
				var cut := line.length() - 1
				while cut > 1 and measure(line.substr(0, cut), k) > width:
					cut -= 1
				out.append(line.substr(0, cut))
				line = line.substr(cut)
		out.append(line)
	return out


## A truncated single line: the text itself if it fits, else as much as
## fits and `...` -- the full text is always one step away (the detail).
func fit(text: String, k: int, width: float) -> String:
	var t := display(text)
	if measure(t, k) <= width:
		return t
	while t.length() > 1 and measure(t + "...", k) > width:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "..."


func sprite(parent: Node3D, icon: String, page: Vector2, k: int,
		colour: Color, depth := 0.004, relative := false) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = icons.get(icon)
	s.pixel_size = px() * float(k)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.modulate = colour
	s.centered = true
	s.position = rel(page, depth) if relative else at(page, depth)
	parent.add_child(s)
	return s


## A flat ribbon through `points` (in the parent's space), `width` world
## units wide, lying in the plane whose normal is `normal`.
func ribbon(parent: Node3D, points: Array, width: float,
		material: Material, normal := Vector3(0, 0, 1)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = strip(points, width, normal)
	node.material_override = material
	parent.add_child(node)
	return node


static func strip(points: Array, width: float,
		normal := Vector3(0, 0, 1)) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		if a.distance_to(b) < 0.00001:
			continue
		var side := (b - a).cross(normal).normalized() * width * 0.5
		st.add_vertex(a - side); st.add_vertex(a + side); st.add_vertex(b + side)
		st.add_vertex(a - side); st.add_vertex(b + side); st.add_vertex(b - side)
	return st.commit()


# ------------------------------------------------------------ time

## Animate `obj`'s property to `to` over `seconds`, from wherever it is NOW.
## A second call on the same property replaces the first mid-flight: that
## is what makes every transition interruptible. Reduced motion: at once.
func go(obj: Object, prop: String, to: Variant, seconds: float,
		ease := "cubic", delay := 0.0) -> void:
	for i in range(_tracks.size() - 1, -1, -1):
		var tr: Dictionary = _tracks[i]
		if tr["obj"] == obj and tr["prop"] == prop:
			_tracks.remove_at(i)
	if reduced or seconds <= 0.0:
		obj.set_indexed(prop, to)
		return
	_tracks.append({"obj": obj, "prop": prop,
		"from": obj.get_indexed(prop), "to": to, "t": -delay,
		"dur": seconds, "ease": ease})


## Run `call` once, `seconds` from now -- at once when motion is reduced,
## where nothing travels and so nothing has to finish first.
func later(seconds: float, call: Callable) -> void:
	if reduced or seconds <= 0.0:
		call.call()
		return
	_later.append([seconds, call])


## Whether anything is still travelling (a test waits on this).
func busy() -> bool:
	return not _tracks.is_empty() or not _later.is_empty()


func moving(obj: Object, prop: String) -> bool:
	for tr: Dictionary in _tracks:
		if tr["obj"] == obj and tr["prop"] == prop:
			return true
	return false


## Secondary motion -- a pulse, a shimmer -- holds still when motion is
## reduced. Everything that moves on its own asks this.
func still() -> bool:
	return reduced


func step(delta: float) -> void:
	for i in range(_later.size() - 1, -1, -1):
		_later[i][0] = float(_later[i][0]) - delta
		if float(_later[i][0]) <= 0.0:
			var call: Callable = _later[i][1]
			_later.remove_at(i)
			call.call()
	for i in range(_tracks.size() - 1, -1, -1):
		var tr: Dictionary = _tracks[i]
		if not is_instance_valid(tr["obj"]):
			_tracks.remove_at(i)
			continue
		tr["t"] = float(tr["t"]) + delta
		if float(tr["t"]) < 0.0:
			continue
		var u := clampf(float(tr["t"]) / float(tr["dur"]), 0.0, 1.0)
		if u >= 1.0:
			(tr["obj"] as Object).set_indexed(str(tr["prop"]), tr["to"])
			_tracks.remove_at(i)
			continue
		(tr["obj"] as Object).set_indexed(str(tr["prop"]),
				lerp(tr["from"], tr["to"], ease_of(u, str(tr["ease"]))))


static func ease_of(u: float, kind: String) -> float:
	match kind:
		"linear":
			return u
		"out":
			return 1.0 - pow(1.0 - u, 3.0)
		"in":
			return u * u * u
		_:
			return 4.0 * u * u * u if u < 0.5 \
					else 1.0 - pow(-2.0 * u + 2.0, 3.0) * 0.5
