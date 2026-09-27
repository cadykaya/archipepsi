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
##
## THE HYBRID (the owner's rulings of 2026-09-27): the walls are the old
## station enclosure's graphite enamel, and one laced HARNESS runs round
## all four of them and every corner, held by the same saddle clamps
## everywhere. Every wall's title is a warm flag label on it. What a wall
## hangs from the harness is that wall's own.

signal turned(page: String)

var kit: Kit
var camera: Camera3D
var faces := {}          # page -> Node3D (the face's local frame)
var walls := {}          # page -> MeshInstance3D
var heading := 0         # quarter turns, unwrapped
var front := 0
var light: OmniLight3D
## The hybrid's harness round the walls. The direction studies (frozen
## checkpoints) draw their own, and set this false before setup.
var harness := true


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
		wall.material_override = kit.wall_material()
		wall.position = Vector3(0, 0, -Kit.DISTANCE)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.add_child(wall)
		walls[page] = wall
		if harness:
			_harness(page, i)
		else:
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
	light.omni_range = 2.9
	light.omni_attenuation = 1.1
	light.light_energy = 1.9
	light.light_color = Color("#f1ece4")
	light.shadow_enabled = true
	light.shadow_bias = 0.02
	light.shadow_normal_bias = 0.5
	add_child(light)
	if harness:
		_corners()


func _block(size: Vector3, pos: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = kit.lit(colour)
	node.position = pos
	add_child(node)


## THE HARNESS on each wall: the trunk's run, its clamps, and the wall's
## title as a flag label on it -- Production's name and the wall's number,
## where you are in the box. Lacing keeps off the spans a wall hangs
## something from (`clear`).
const HARNESS := {
	"settings": {"clamps": [560.0, 1000.0], "clear": [Vector2(1166, 1214)]},
	"equipment": {"clamps": [520.0, 1110.0], "clear": [Vector2(1186, 1214)]},
	"map": {"clamps": [640.0, 800.0], "clear": [Vector2(932, 960), Vector2(1174, 1202)]},
	"journal": {"clamps": [880.0], "clear": [Vector2(32, 60), Vector2(586, 614),
		Vector2(1190, 1230)]},
}
## The miniature's light also falls on the Map's wall and, glancing, the
## Journal's (the renderer ignores a light's cull mask): a PALE surface on
## them is toned by this much, so one flag reads the same on every wall.
const SHADE := {"map": 0.74, "journal": 0.86}
var title_flags := {}    # page -> the flag's page rect


func _harness(page: String, index: int) -> void:
	var face: Node3D = faces[page]
	var shade: float = SHADE.get(page, 1.0)
	var r := Parts.flag(kit, face, 40, Kit.TITLES[page], 4, "0%d" % (index + 1), shade)
	title_flags[page] = r
	var clear: Array = (HARNESS[page]["clear"] as Array).duplicate()
	clear.append(Vector2(r.position.x, r.end.x))
	Parts.trunk(face, HARNESS[page]["clamps"], clear)


## The pre-hybrid title (the direction studies remove it and set their own).
func _title(page: String, index: int) -> void:
	var face: Node3D = faces[page]
	kit.label(face, Kit.TITLES[page], Vector2(48, 30), 4, Kit.INK, 0.003)
	var num := "0%d" % (index + 1)
	var w := kit.measure(num, 9, true)
	kit.label(face, num, Vector2(Kit.PAGE.x - 44 - w, 8), 9, Color("#2a3039"), 0.0015, true)


## The trunk round the four corner posts: one harness, not four.
func _corners() -> void:
	var loom := Parts.mat(Parts.LOOM, 0.1, 0.45)
	for i in Kit.PAGES.size():
		var left: String = Kit.PAGES[i]
		var right: String = Kit.PAGES[posmod(i - 1, Kit.PAGES.size())]
		Parts.corner(self, faces[left], faces[right], Parts.TRUNK_Y, Parts.TRUNK_R,
				loom, Parts.TRUNK_Z)


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
	kit.cue("page", 1.0 if step > 0 else 0.9)
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
	kit.cue("page")
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
