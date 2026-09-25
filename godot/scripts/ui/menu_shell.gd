class_name MenuShell
extends CanvasLayer
## H-3D-SHELL (CP3): THE PAUSE INTERFACE IN REAL 3D -- the owner's inside
## of a box (`post_playtest_v1.0/04_3D_MENU_MAP_AND_GLYPH.md` §1, §3).
##
## Four pages on the inward faces of a box's walls, a camera at its centre,
## and a turn between pages that is the camera actually turning: not a
## picture on a rectangle, not a cube seen from outside, not a flat tab
## strip squeezed to nothing. Turning LEFT proceeds Settings -> Equipment
## -> Map -> Journal -> Settings; turning right reverses it.
##
## **ITS OWN WORLD.** The box renders in a SubViewport with its own
## `World3D`, so nothing of the dungeon -- walls, lights, physics, field of
## view -- is in it, and nothing of it is in the dungeon.
##
## **LIVE PAGES, NOT PICTURES.** Each page is an ordinary Control tree in
## its own SubViewport, shown on its wall as that viewport's texture, so
## what a page says and what it answers to stay live. The pointer is
## carried to the front page by geometry: the ray from this camera through
## the pointer, met with the front wall's plane, names the page pixel the
## event is pushed to. There is no physics query in it -- a paused world
## must not need its physics server to make a menu clickable (§4).
##
## **THE WORLD STOPS BEHIND IT (H-PAUSE).** Open, it holds a `PauseClaims`
## claim named "menu": the dungeon, its physics and its timers stop, and
## this node and the bridge client keep running. Closing releases only its
## own claim.
##
## **WHAT IS NOT HERE YET.** The equipment face on Glyph assets is
## H-INVENTORY's; the map and the journal are H-3D-MAP's and H-JOURNAL's. A page nobody has filled says so, rather
## than pretending to be finished (§5 of the delivery plan: "the blank
## other faces are an explicitly incomplete slice").

signal opened(page: String)
signal closed
## The front page changed, once a turn has come to rest.
signal page_changed(page: String)

## The walls, in the order turning LEFT visits them.
const PAGES: Array[String] = ["settings", "equipment", "map", "journal"]
const TITLES := {
	"settings": "SETTINGS",
	"equipment": "EQUIPMENT",
	"map": "MAP",
	"journal": "JOURNAL",
}
## What an unfilled wall says, so that it reads as unfinished rather than
## as an empty page of a finished menu. A filler removes it ("Incomplete").
const INCOMPLETE := {
	"map": "The map is not built yet (H-3D-MAP). This wall holds its place.",
	"journal": "The journal is not built yet (H-JOURNAL). This wall holds "
			+ "its place.",
}
## Each page's own pixels. The wall shows them at this aspect.
const PAGE_PIXELS := Vector2i(1280, 720)
## From the box's centre to each wall, and the camera's vertical field of
## view: together they decide how much of the screen the front page fills
## at rest (`FILL`).
const DISTANCE := 1.0
const FOV := 60.0
const FILL := 0.86
## One quarter turn. A reduced-motion turn is a cut to the next wall,
## the same four walls in the same order.
const TURN_SECONDS := 0.42

## The claim this interface holds on the world while it is open.
const PAUSE_CLAIM := "menu"

## A reduced-motion turn is a cut (§3). It follows the accessibility
## setting that already exists for exactly this: `motion_intensity` at 0
## "disables view bob and landing dip entirely".
var reduced_motion := false

var _stage: SubViewportContainer = null
var _world: SubViewport = null
var _camera: Camera3D = null
var _walls: Array[MeshInstance3D] = []
var _pages: Array[SubViewport] = []
var _roots: Array[Control] = []
var _arrows: Array[Button] = []
var _front := 0
var _turning: Tween = null
## The yaw the camera is headed for, in quarter turns (unwrapped, so a
## turn is always the short way round and never a spin).
var _heading := 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
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
	_world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stage.add_child(_world)
	_build_box()
	for i in PAGES.size():
		_build_page(i)
	_build_arrows()
	_face(_front, true)


# ------------------------------------------------------------ the API

func open(page := "settings") -> void:
	reduced_motion = PlayerSettings.shared().value("motion_intensity") <= 0.0
	var index := PAGES.find(page)
	_front = index if index >= 0 else 0
	_heading = _front
	_face(_front, true)
	visible = true
	_set_rendering(true)
	PauseClaims.claim(get_tree(), PAUSE_CLAIM)
	opened.emit(PAGES[_front])
	page_changed.emit(PAGES[_front])


func close() -> void:
	if not visible:
		return
	if _turning != null and _turning.is_valid():
		_turning.kill()
	_turning = null
	visible = false
	_set_rendering(false)
	PauseClaims.release(get_tree(), PAUSE_CLAIM)
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
	return _turning != null and _turning.is_valid() and _turning.is_running()


## One quarter turn: +1 is LEFT (Settings -> Equipment), -1 is right.
func turn(step: int) -> void:
	if not visible or step == 0:
		return
	_turn_by(signi(step))


## Straight to a page, the short way round: a quarter turn either way, or
## a half turn to the wall behind.
func show_page(page: String) -> void:
	var index := PAGES.find(page)
	if not visible or index < 0 or index == _front:
		return
	var delta := posmod(index - _front, PAGES.size())
	_turn_by(delta if delta <= 2 else delta - PAGES.size())


func _turn_by(step: int) -> void:
	_heading += step
	_front = posmod(_heading, PAGES.size())
	if _turning != null and _turning.is_valid():
		_turning.kill()
	var yaw := _yaw_of(_heading)
	if reduced_motion:
		_camera.rotation.y = yaw
		_turning = null
		page_changed.emit(PAGES[_front])
		return
	_turning = create_tween()
	_turning.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_turning.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_turning.tween_property(_camera, "rotation:y", yaw, TURN_SECONDS)
	_turning.tween_callback(func() -> void:
		page_changed.emit(PAGES[_front]))


## The root a page's content goes under. It fills the page.
func page_root(page: String) -> Control:
	var index := PAGES.find(page)
	return _roots[index] if index >= 0 else null


## The viewport a page is drawn in (for a test to read or capture).
func page_viewport(page: String) -> SubViewport:
	var index := PAGES.find(page)
	return _pages[index] if index >= 0 else null


func wall(page: String) -> MeshInstance3D:
	var index := PAGES.find(page)
	return _walls[index] if index >= 0 else null


func camera() -> Camera3D:
	return _camera


func stage() -> SubViewport:
	return _world


func arrows() -> Array[Button]:
	return _arrows


## The wall's width and height in the box's units.
func wall_size() -> Vector2:
	var height := 2.0 * DISTANCE * tan(deg_to_rad(FOV * 0.5)) * FILL
	return Vector2(height * float(PAGE_PIXELS.x) / float(PAGE_PIXELS.y),
			height)


## Where on the front page a point of the stage lands, in page pixels,
## or `Vector2.INF` when it misses the page. The whole of the pointer's
## journey, from screen to page, is this function.
func page_point(stage_point: Vector2) -> Vector2:
	if _camera == null:
		return Vector2.INF
	var origin := _camera.project_ray_origin(stage_point)
	var along := _camera.project_ray_normal(stage_point)
	return _page_hit(_front, origin, along)


# ------------------------------------------------------------ input

## Page turns and the way out; everything else a key does belongs to the
## front page, which gets it pushed to its own viewport. A LineEdit that
## has focus keeps its letters: Q and E type there, and do not turn.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouse:
		return
	# THE WAY OUT, and the equipment shortcut: Escape closes from any
	# wall; Tab turns to Equipment, and closes when it is already there.
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	var typing := _typing()
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
	if is_turning():
		get_viewport().set_input_as_handled()
		return
	_pages[_front].push_input(event)
	get_viewport().set_input_as_handled()


func _on_stage_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouse):
		return
	_stage.accept_event()
	if is_turning():
		return
	var mouse := event as InputEventMouse
	var at := page_point(mouse.position)
	if at == Vector2.INF:
		return
	var moved := mouse.duplicate() as InputEventMouse
	moved.position = at
	moved.global_position = at
	_pages[_front].push_input(moved, true)


func _typing() -> bool:
	var focus := _pages[_front].gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


# ------------------------------------------------------------ building

## Wall `i` stands a quarter turn LEFT of wall `i - 1`. A quarter turn
## left is +90 degrees of yaw.
func _yaw_of(quarter: int) -> float:
	return float(quarter) * PI * 0.5


## The wall's centre and the unit vectors of its plane: `normal` points
## back at the camera, `right` and `up` are the page's own axes as seen
## from inside the box.
func _frame(index: int) -> Dictionary:
	var yaw := _yaw_of(index)
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


func _build_box() -> void:
	var environment := WorldEnvironment.new()
	var look := Environment.new()
	look.background_mode = Environment.BG_COLOR
	look.background_color = Color(0.03, 0.035, 0.045)
	look.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	look.ambient_light_color = Color(0.6, 0.62, 0.68)
	environment.environment = look
	_world.add_child(environment)
	_camera = Camera3D.new()
	_camera.name = "Eye"
	_camera.fov = FOV
	_camera.near = 0.05
	_camera.far = 20.0
	_camera.current = true
	_world.add_child(_camera)
	# THE BOX ITSELF: floor, ceiling and the four corner posts, so the
	# walls read as the inside of one room and a turn reads as a turn.
	var size := wall_size()
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = Color(0.16, 0.17, 0.2)
	var span := DISTANCE * 2.0
	for y: float in [-size.y * 0.5 - 0.02, size.y * 0.5 + 0.02]:
		_block(Vector3(span, 0.02, span), Vector3(0.0, y, 0.0), edge)
	# THE CORNERS ARE PILLARS wide enough to meet both walls' edges: a
	# wall is narrower than the box's side, and a thin post left a gap
	# at every corner that showed through mid-turn.
	# Darker than floor and ceiling, so a corner reads as structure and
	# not as a hole through to them.
	var post := StandardMaterial3D.new()
	post.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post.albedo_color = Color(0.07, 0.075, 0.085)
	var pillar := 2.0 * (DISTANCE - size.x * 0.5) + 0.02
	for x: float in [-DISTANCE, DISTANCE]:
		for z: float in [-DISTANCE, DISTANCE]:
			_block(Vector3(pillar, size.y + 0.08, pillar), Vector3(x, 0.0, z),
					post)


func _block(size: Vector3, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	_world.add_child(node)
	node.position = at


func _build_page(index: int) -> void:
	var page := SubViewport.new()
	page.name = "Page_%s" % PAGES[index]
	page.size = PAGE_PIXELS
	page.transparent_bg = false
	page.handle_input_locally = true
	page.gui_disable_input = false
	page.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(page)
	var root := Panel.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(root)
	var title := Label.new()
	title.name = "Title"
	title.text = str(TITLES[PAGES[index]])
	title.add_theme_font_size_override("font_size", 40)
	title.position = Vector2(48, 28)
	root.add_child(title)
	if INCOMPLETE.has(PAGES[index]):
		var note := Label.new()
		note.name = "Incomplete"
		note.text = str(INCOMPLETE[PAGES[index]])
		note.add_theme_font_size_override("font_size", 26)
		note.modulate = Color(0.75, 0.75, 0.7)
		note.position = Vector2(48, 110)
		root.add_child(note)
	_pages.append(page)
	_roots.append(root)
	var wall_node := MeshInstance3D.new()
	wall_node.name = "Wall_%s" % PAGES[index]
	var quad := QuadMesh.new()
	quad.size = wall_size()
	wall_node.mesh = quad
	var face := StandardMaterial3D.new()
	face.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face.albedo_texture = page.get_texture()
	face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	wall_node.material_override = face
	_world.add_child(wall_node)
	var frame := _frame(index)
	wall_node.position = frame["centre"]
	# A QuadMesh faces +z; this turns it to face the box's centre.
	wall_node.rotation.y = _yaw_of(index)
	_walls.append(wall_node)


## The two large arrows, over the stage at its left and right edges. They
## are ordinary buttons, so a mouse, a touch and a focus ring all work;
## their art is Glyph's to supply (H-GLYPH-KIT).
func _build_arrows() -> void:
	for side: int in [1, -1]:
		var arrow := Button.new()
		arrow.name = "TurnLeft" if side == 1 else "TurnRight"
		arrow.text = "<" if side == 1 else ">"
		arrow.tooltip_text = "Turn left" if side == 1 else "Turn right"
		arrow.add_theme_font_size_override("font_size", 64)
		arrow.custom_minimum_size = Vector2(96, 180)
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.pressed.connect(func() -> void: turn(side))
		add_child(arrow)
		# OFFSETS FROM THE ANCHOR, so the arrows stay at the screen's edges
		# at any size. (`position` is from the parent's corner, and put
		# them both above the screen.)
		arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT if side == 1
				else Control.PRESET_CENTER_RIGHT)
		var inner := 24.0 if side == 1 else -120.0
		arrow.offset_left = inner
		arrow.offset_right = inner + 96.0
		arrow.offset_top = -90.0
		arrow.offset_bottom = 90.0
		_arrows.append(arrow)


func _face(index: int, at_once: bool) -> void:
	if _camera == null:
		return
	if at_once:
		_camera.rotation.y = _yaw_of(_heading)
	_front = posmod(index, PAGES.size())


func _set_rendering(on: bool) -> void:
	var mode := SubViewport.UPDATE_ALWAYS if on \
			else SubViewport.UPDATE_DISABLED
	if _world != null:
		_world.render_target_update_mode = mode
	for page: SubViewport in _pages:
		page.render_target_update_mode = mode
