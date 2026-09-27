class_name Shell
extends Node3D
## THE BOX: four inward walls, the eye at the centre, and the turn between
## them -- Production's MenuShell, at its own numbers and with its own
## rules, except where a note below says the prototype proposes otherwise.
##
## * Turning LEFT (+1): Settings -> Equipment -> Map -> Journal -> Settings.
## * A turn retargets from wherever the eye is: a second press mid-turn
##   reverses or continues it (MenuShell._turn_by kills its tween and
##   starts from the current angle -- the same).
## * Reduced motion: the turn is a cut.
##
## Unlike MenuShell, the walls are LIT: a light near the ceiling gives each
## wall a fall-off from top to bottom, and a raised plate shades the wall
## behind it. That is the depth the focus uses, instead of a glow.

signal turned(page: String)

var kit: Kit
var camera: Camera3D
var faces := {}          # page -> Node3D (the face's local frame)
var walls := {}          # page -> MeshInstance3D
var heading := 0         # quarter turns, unwrapped
var front := 0
var light: OmniLight3D


func setup(k: Kit) -> void:
	kit = k
	camera = Camera3D.new()
	camera.name = "Eye"
	camera.fov = Kit.FOV
	camera.near = 0.02
	camera.far = 50.0
	camera.current = true
	add_child(camera)
	var size := Kit.wall_size()
	for i in Kit.PAGES.size():
		var page: String = Kit.PAGES[i]
		var face := Node3D.new()
		face.name = "Face_%s" % page
		face.rotation.y = Kit.yaw_of(i)
		add_child(face)
		faces[page] = face
		var wall := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = size
		wall.mesh = quad
		wall.material_override = kit.lit(Kit.WALL)
		wall.position = Vector3(0, 0, -Kit.DISTANCE)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.add_child(wall)
		walls[page] = wall
		_title(page, i)
	var span := Kit.DISTANCE * 2.0
	for y: float in [-size.y * 0.5 - 0.02, size.y * 0.5 + 0.02]:
		_block(Vector3(span, 0.02, span), Vector3(0, y, 0), Kit.SLAB)
	var post := 2.0 * (Kit.DISTANCE - size.x * 0.5) + 0.02
	for x: float in [-Kit.DISTANCE, Kit.DISTANCE]:
		for z: float in [-Kit.DISTANCE, Kit.DISTANCE]:
			_block(Vector3(post, size.y + 0.08, post), Vector3(x, 0, z),
					Kit.POST)
	# One light, near the ceiling: every wall is brightest at its top
	# middle and falls away to its corners and its foot.
	light = OmniLight3D.new()
	light.position = Vector3(0, size.y * 0.42, 0)
	light.omni_range = 2.6
	light.omni_attenuation = 0.9
	light.light_energy = 1.35
	light.light_color = Color("#f1ece4")
	light.shadow_enabled = true
	light.shadow_bias = 0.02
	light.shadow_normal_bias = 0.5
	add_child(light)


func _block(size: Vector3, pos: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = kit.lit(colour)
	node.position = pos
	add_child(node)


## Every wall's heading: its number and Production's name for it. The
## number is where you are in the box -- the one thing a turn changes.
func _title(page: String, index: int) -> void:
	var face: Node3D = faces[page]
	var num := "0%d" % (index + 1)
	kit.label(face, num, Vector2(48, 30), 4, Kit.INK_FAINT, 0.003, true)
	var x := 48.0 + kit.measure(num, 4, true) + 18.0
	kit.label(face, Kit.TITLES[page], Vector2(x, 30), 4, Kit.INK, 0.003)


func face_of(page: String) -> Node3D:
	return faces[page]


func front_page() -> String:
	return Kit.PAGES[front]


func neighbour(step: int) -> String:
	return Kit.PAGES[posmod(front + step, Kit.PAGES.size())]


## Face a page at once (opening the menu on it).
func face(page: String) -> void:
	front = Kit.PAGES.find(page)
	heading = front
	camera.rotation.y = Kit.yaw_of(heading)
	turned.emit(page)


## One quarter turn: +1 is LEFT, -1 is right. Interruptible.
func turn(step: int) -> void:
	heading += signi(step)
	front = posmod(heading, Kit.PAGES.size())
	kit.go(camera, "rotation:y", Kit.yaw_of(heading), Kit.TURN_SECONDS)
	turned.emit(front_page())


## Straight to a page, the short way round (MenuShell.show_page).
func show_page(page: String) -> void:
	var index := Kit.PAGES.find(page)
	if index < 0 or index == front:
		return
	var delta := posmod(index - front, Kit.PAGES.size())
	var step := delta if delta <= 2 else delta - Kit.PAGES.size()
	heading += step
	front = index
	kit.go(camera, "rotation:y", Kit.yaw_of(heading), Kit.TURN_SECONDS)
	turned.emit(page)


func is_turning() -> bool:
	return kit.moving(camera, "rotation:y")


## Where a screen point lands on a wall: {page, at (page px)}, or {} if it
## lands on none (a post, the floor). MenuShell._page_hit's arithmetic.
func page_hit(screen: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	var along := camera.project_ray_normal(screen)
	var best := {}
	var nearest := INF
	for page: String in faces:
		var face: Node3D = faces[page]
		var inv := face.global_transform.affine_inverse()
		var o := inv * origin
		var d := inv.basis * along
		if absf(d.z) < 0.00001:
			continue
		var t := (-Kit.DISTANCE - o.z) / d.z
		if t <= 0.0 or t >= nearest:
			continue
		var hit := o + d * t
		var s := Kit.px()
		var p := Vector2(hit.x / s + Kit.PAGE.x * 0.5,
				Kit.PAGE.y * 0.5 - hit.y / s)
		if p.x < 0 or p.y < 0 or p.x > Kit.PAGE.x or p.y > Kit.PAGE.y:
			continue
		nearest = t
		best = {"page": page, "at": p, "origin": origin, "along": along}
	return best


## A page point on a face, as a screen point (for the overlay and tests).
func screen_of(page: String, at: Vector2, depth := 0.0) -> Vector2:
	var face: Node3D = faces[page]
	return camera.unproject_position(face.global_transform * Kit.at(at, depth))
