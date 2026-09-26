extends RefCounted
## Track A2 -- the shared kit for the three spatial-interaction studies.
##
## **THE BOX IS PRODUCTION'S.** Four inward walls at `DISTANCE`, a camera
## at the centre with `FOV`, the front wall filling `FILL` of the screen's
## height at rest, and a quarter turn of `TURN_SECONDS`, cubic in-out --
## the numbers are `MenuShell`'s at the revision the sample data names,
## so the three studies differ ONLY in what happens on, in front of and
## behind the walls. A reduced-motion turn is a cut, as it is there.
##
## **TIME IS VIRTUAL.** Nothing here reads the frame clock: every animation
## is a function of `t`, stepped by the harness one captured frame at a
## time. The captures are therefore exact and repeatable, and an
## interrupted animation really does start from wherever it had got to.
##
## Review scenes only. Nothing in this kit decides what an item does, where
## a room is or whether a door is shut: the studies draw Production's own
## answers (`tools/menu_studies/sample/`), and this is not a second
## implementation of the menu.

const DISTANCE := 1.0
const FOV := 60.0
const FILL := 0.86
const PAGE := Vector2(1280, 720)
const TURN_SECONDS := 0.42
const PAGES: Array[String] = ["settings", "equipment", "map", "journal"]
const TITLES := {"settings": "SETTINGS", "equipment": "EQUIPMENT",
	"map": "MAP", "journal": "JOURNAL"}

## The box's own neutrals: darker than anything a page draws, so the page
## is what the eye lands on. `ink` is the Glyph text ink (fontkit.TEXT_INK).
const BG := Color("#0d0f12")
const WALL := Color("#1a1d22")
const EDGE := Color("#2a2e35")
const POST := Color("#101216")
const INK := Color("#e8eef6")
const INK_DIM := Color("#9ba5b6")
const INK_FAINT := Color("#717985")
const SIGNAL := Color("#39d7c8")      # "you can use this" -- focus, prompts
const SIGNAL_DEEP := Color("#228178")
const DEAD := Color("#4a4f57")        # empty key, spent, not for you now
const SHEET := Color("#262a31")
const SHEET_HI := Color("#30353d")

var t := 0.0
var reduced := false
var root: Node3D
var camera: Camera3D
var faces: Array[Node3D] = []
var walls: Array[MeshInstance3D] = []
var text_font: FontFile
var num_font: FontFile
var icons := {}
var heading := 0          # quarter turns, unwrapped
var front := 0

var _tracks: Array = []
var _materials := {}
## Called with `t` on every step, after the tracks: continuous effects that
## are a function of time (a blocker's pulse, a label that follows a room).
var tickers: Array[Callable] = []
var _later: Array = []


## Run `call` once, `seconds` from now (at once in reduced motion, where
## nothing travels and so nothing has to finish first).
func later(seconds: float, call: Callable) -> void:
	if reduced or seconds <= 0.0:
		call.call()
		return
	_later.append([t + seconds, call])


## World units per page pixel on the wall plane.
static func px() -> float:
	return wall_size().y / PAGE.y


static func wall_size() -> Vector2:
	var h := 2.0 * DISTANCE * tan(deg_to_rad(FOV * 0.5)) * FILL
	return Vector2(h * PAGE.x / PAGE.y, h)


func _init(world_root: Node3D, harness_dir: String) -> void:
	root = world_root
	text_font = load(harness_dir + "/ui_text.fnt") as FontFile
	num_font = load(harness_dir + "/ui_numerals.fnt") as FontFile
	for name: String in ["arrow_left", "arrow_right", "arrow_up",
			"arrow_down", "blocked", "circuit", "control", "exit"]:
		icons[name] = load("%s/icon_%s.png" % [harness_dir, name])
	_build_box()


# ------------------------------------------------------------ the box

func _build_box() -> void:
	camera = Camera3D.new()
	camera.name = "Eye"
	camera.fov = FOV
	camera.near = 0.02
	camera.far = 40.0
	camera.current = true
	root.add_child(camera)
	var size := wall_size()
	for i in PAGES.size():
		var face := Node3D.new()
		face.name = "Face_%s" % PAGES[i]
		face.rotation.y = yaw_of(i)
		root.add_child(face)
		faces.append(face)
		var wall := MeshInstance3D.new()
		wall.name = "Wall"
		var quad := QuadMesh.new()
		quad.size = size
		wall.mesh = quad
		wall.material_override = flat(WALL)
		wall.position = Vector3(0, 0, -DISTANCE)
		face.add_child(wall)
		walls.append(wall)
	var span := DISTANCE * 2.0
	for y: float in [-size.y * 0.5 - 0.02, size.y * 0.5 + 0.02]:
		block(root, Vector3(span, 0.02, span), Vector3(0, y, 0), EDGE)
	var pillar := 2.0 * (DISTANCE - size.x * 0.5) + 0.02
	for x: float in [-DISTANCE, DISTANCE]:
		for z: float in [-DISTANCE, DISTANCE]:
			block(root, Vector3(pillar, size.y + 0.08, pillar),
					Vector3(x, 0, z), POST)


## Wall `i` stands a quarter turn LEFT of wall `i - 1` (MenuShell._yaw_of).
static func yaw_of(quarter: int) -> float:
	return float(quarter) * PI * 0.5


func face_of(page: String) -> Node3D:
	return faces[PAGES.find(page)]


func face_title(page: String, colour := INK_FAINT) -> void:
	label(face_of(page), TITLES[page], Vector2(48, 30), 3, colour, 0.004)


## Page pixels as an OFFSET inside something already placed: +x right,
## +y down, as on the page.
static func rel(v: Vector2, depth := 0.0) -> Vector3:
	var s := px()
	return Vector3(v.x * s, -v.y * s, depth)


## Page pixels (0..1280, 0..720 from the wall's top-left) to a face's
## local space, `depth` world units in front of the wall.
static func at(page_px: Vector2, depth := 0.0) -> Vector3:
	var s := px()
	return Vector3((page_px.x - PAGE.x * 0.5) * s,
			(PAGE.y * 0.5 - page_px.y) * s, -DISTANCE + depth)


# ------------------------------------------------------------ primitives

func flat(colour: Color, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s/%.3f" % [colour.to_html(), alpha]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(colour, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m


## A material of its own, for a node whose colour is animated.
func own(colour: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(colour, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func block(parent: Node3D, size: Vector3, pos: Vector3,
		colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = flat(colour)
	node.position = pos
	parent.add_child(node)
	return node


## A flat card `size_px` page pixels, its TOP-LEFT at `page_px`.
func card(parent: Node3D, page_px: Vector2, size_px: Vector2, depth: float,
		colour: Color, alpha := 1.0, animated := false,
		relative := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size_px * px()
	node.mesh = quad
	node.material_override = own(colour, alpha) if animated \
			else flat(colour, alpha)
	node.position = rel(page_px + size_px * 0.5, depth) if relative \
			else at(page_px + size_px * 0.5, depth)
	parent.add_child(node)
	return node


## Glyph text, its top-left at `page_px`, at an integer multiple `k` of
## the face's 8 px design. Unsupported characters get a visible stand-in
## (`sanitize`), never a blank.
func label(parent: Node3D, text: String, page_px: Vector2, k: int,
		colour: Color, depth := 0.003, wrap_px := 0.0,
		numerals := false, relative := false) -> Label3D:
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
	if wrap_px > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = wrap_px / float(k)
	l.text = sanitize(text)
	# LEFT + TOP alignment already anchors the block's top-left on the
	# node's origin (measured: a centring offset moved every label right by
	# exactly half its width), which is how everything else is placed.
	l.position = rel(page_px, depth) if relative else at(page_px, depth)
	parent.add_child(l)
	return l


## How wide `text` is, in page pixels, at scale `k`.
func measure(text: String, k: int) -> float:
	var widest := 0.0
	for line in sanitize(text).split("\n"):
		widest = maxf(widest, text_font.get_string_size(line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	return widest * float(k)


## The face is one uppercase design: map lower case up, and give the
## characters Production's strings and bindings use and the face lacks --
## `;` `—` `→` `[` `]` -- a visible stand-in. (A Glyph requirement, not a
## design choice: see the report.)
static func sanitize(text: String) -> String:
	return text.to_upper().replace("→", ">").replace("—", "-") \
			.replace(";", ",").replace("_", " ").replace("[", "(") \
			.replace("]", ")")


func sprite(parent: Node3D, icon: String, page_px: Vector2, k: int,
		colour: Color, depth := 0.004, relative := false) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = icons[icon]
	s.pixel_size = px() * float(k)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.modulate = colour
	s.centered = true
	s.position = rel(page_px, depth) if relative else at(page_px, depth)
	parent.add_child(s)
	return s


## A flat ribbon through `points` (face-local), `width` world units wide,
## facing +z (toward the camera from the wall).
func ribbon(parent: Node3D, points: Array, width: float, colour: Color,
		alpha := 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var along := (b - a)
		if along.length() < 0.00001:
			continue
		var side := along.cross(Vector3(0, 0, 1)).normalized() * width * 0.5
		st.add_vertex(a - side); st.add_vertex(a + side); st.add_vertex(b + side)
		st.add_vertex(a - side); st.add_vertex(b + side); st.add_vertex(b - side)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = own(colour, alpha)
	parent.add_child(node)
	return node


# ------------------------------------------------------------ time

## Animate `node`'s property to `to` over `seconds`, from wherever it is
## NOW. A second call on the same property replaces the first mid-flight:
## that is what makes every transition interruptible. Reduced motion sets
## the value at once -- same state, no travel.
func go(node: Object, prop: String, to: Variant, seconds: float,
		ease := "cubic", delay := 0.0) -> void:
	for i in range(_tracks.size() - 1, -1, -1):
		var tr: Dictionary = _tracks[i]
		if tr["node"] == node and tr["prop"] == prop:
			_tracks.remove_at(i)
	if reduced or seconds <= 0.0:
		node.set_indexed(prop, to)
		return
	_tracks.append({"node": node, "prop": prop,
		"from": node.get_indexed(prop), "to": to, "t0": t + delay,
		"dur": seconds, "ease": ease})


func busy() -> bool:
	return not _tracks.is_empty()


func step(to_t: float) -> void:
	t = to_t
	for i in range(_tracks.size() - 1, -1, -1):
		var tr: Dictionary = _tracks[i]
		if t < float(tr["t0"]):
			continue
		var u := clampf((t - float(tr["t0"])) / float(tr["dur"]), 0.0, 1.0)
		if u >= 1.0:
			# Land exactly on the target -- the value reduced motion sets at
			# once -- not a float's width off it.
			(tr["node"] as Object).set_indexed(str(tr["prop"]), tr["to"])
			_tracks.remove_at(i)
			continue
		var e := _ease(u, str(tr["ease"]))
		(tr["node"] as Object).set_indexed(str(tr["prop"]),
				lerp(tr["from"], tr["to"], e))
	for i in range(_later.size() - 1, -1, -1):
		if t >= float(_later[i][0]):
			var call: Callable = _later[i][1]
			_later.remove_at(i)
			call.call()
	for tick: Callable in tickers:
		tick.call(t)


static func _ease(u: float, kind: String) -> float:
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


# ------------------------------------------------------------ turning

## Face a page at once (open).
func face(page: String) -> void:
	front = PAGES.find(page)
	heading = front
	camera.rotation.y = yaw_of(heading)


## One quarter turn: +1 is LEFT (Settings -> Equipment), -1 is right --
## MenuShell.turn, the short way round, cubic, or a cut.
func turn(step_dir: int) -> void:
	heading += signi(step_dir)
	front = posmod(heading, PAGES.size())
	go(camera, "rotation:y", yaw_of(heading), TURN_SECONDS)


func front_page() -> String:
	return PAGES[front]
