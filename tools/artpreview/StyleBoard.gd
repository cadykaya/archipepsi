extends SceneTree
## Batch 002 F -- the family board. Two languages in one frame.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s StyleBoard.gd -- <assets_root> <out_dir>
##
## The 001-R review's optional item:
##
##   > A family / style board showing Epsilon devices, portals and enemies
##   > sharing one alien language, distinct from the human facility.
##
## The claim being tested is that everything Epsilon touches reads as one
## thing and everything the facility built reads as another, and the only
## honest way to test a claim like that is to put both in the SAME frame,
## under the SAME light, at the SAME distance. Anything else compares two
## photographs rather than two languages.
##
## So this is one row of facility objects and one row of Epsilon objects, on
## one floor, and then the same board in greyscale -- because if the split
## only exists in hue it will not survive a dark corridor, and if it only
## exists in value it did not need the green.
##
## No object here is built for the board. Every one of them is the shipped
## .glb another deliverable in this batch produced.

const SHOT := Vector2i(1680, 820)

## [path, x, yaw, hover, label]. Two rows, back and front.
const FACILITY := [
	["batch001/architecture/arch_wall_panel.glb", -5.4, 0.0, 0.0, "WALL"],
	["batch001/props/prop_crate.glb", -2.4, 22.0, 0.0, "CRATE"],
	["batch001/props/prop_machinery_unit.glb", -0.4, -14.0, 0.0, "PLANT"],
	["batch002/architecture/arch_utility_lamp.glb", 1.9, 0.0, 2.1, "LAMP"],
	["batch001/architecture/arch_railing.glb", 4.2, 8.0, 0.0, "RAILING"],
]
const EPSILON := [
	["batch002/portal/portal_b2_wound.glb", -5.0, 12.0, 0.0, "PORTAL B-2"],
	["batch001/epsilon/epsilon_b_core.glb", -1.6, -18.0, 0.0, "EPSILON B"],
	["batch002/enemy/enemy_bulwark.glb", 0.9, 200.0, 0.0, "BULWARK"],
	["batch002/enemy/enemy_scuttler.glb", 2.8, 214.0, 0.0, "SCUTTLER"],
	["batch002/enemy/enemy_drifter.glb", 4.6, 190.0, 2.4, "DRIFTER"],
	["batch001/affordance/anchor_a_soffit.glb", 6.4, 0.0, 3.6, "ANCHOR A"],
]

var _assets := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: StyleBoard.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)

	var vp := ArtBench.make_viewport(self, SHOT, 0.26)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.30)

	var floor_slab := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 16)
	floor_slab.mesh = plane
	var mat := StandardMaterial3D.new()
	# Dark. A pale floor under pale facility objects left the board with no
	# figure-ground at all, and the point of the shot is which things stand
	# out from which.
	mat.albedo_color = Color(0.26, 0.27, 0.30)
	mat.roughness = 0.95
	floor_slab.mesh.surface_set_material(0, mat)
	root.add_child(floor_slab)

	var placed_f := _row(root, FACILITY, 10.4)
	var placed_e := _row(root, EPSILON, 5.4)

	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.2, 2.5, -0.9),
			Vector3(0.1, 1.5, 6.6), Vector3.UP)

	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	_names(img, cam, placed_f, FACILITY, Color(0.72, 0.76, 0.80))
	_names(img, cam, placed_e, EPSILON, Color(0.42, 0.95, 0.30))
	_caption(img, "LIT")
	img.save_png(out + "/F_style_board.png")

	# Greyscale. The two languages have to survive losing their hue: a split
	# that is only green-versus-grey stops existing the moment the room goes
	# dark, and Epsilon is meant to be recognisable in a dark room.
	var grey := Image.create(img.get_width(), img.get_height(), false,
			Image.FORMAT_RGB8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			grey.set_pixel(x, y, Color(v, v, v))
	_caption(grey, "GREYSCALE")
	grey.save_png(out + "/F_style_board_greyscale.png")

	print("[board] %d facility + %d epsilon -> %s"
			% [FACILITY.size(), EPSILON.size(), out])
	quit()

func _row(root: Node3D, row: Array, z: float) -> Array:
	var placed: Array = []
	for k in row:
		var n: Node3D = ArtBench.load_glb("%s/models/%s" % [_assets, str(k[0])])
		if n == null:
			push_error("StyleBoard: missing %s" % str(k[0]))
			placed.append(null)
			continue
		ArtBench.force_nearest(n)
		n.position = Vector3(float(k[1]), float(k[3]), z)
		n.rotation_degrees = Vector3(0, float(k[2]), 0)
		root.add_child(n)
		placed.append(n)
	return placed

## Name each object under itself, using the CAMERA to say where it is.
##
## The first version computed the label position from the row's nominal
## depth and a fraction of the frame height. Every object in a row is a
## different size and sits at a different hover, so the labels landed in one
## straight line well below the things they named -- and a label under the
## wrong figure is worse than no label at all. `unproject_position` asks the
## camera, which is the only thing that actually knows.
func _names(img: Image, cam: Camera3D, placed: Array, row: Array,
		colour: Color) -> void:
	for i in row.size():
		if i >= placed.size() or placed[i] == null:
			continue
		var node: Node3D = placed[i]
		var aabb: AABB = ArtBench.aabb_of(node)
		var foot := node.global_position + Vector3(0, aabb.position.y, 0)
		var at: Vector2 = cam.unproject_position(foot)
		var text := str(row[i][4])
		var px := clampi(int(at.x) - ArtBench.text_width(text) / 2, 4,
				SHOT.x - ArtBench.text_width(text) - 4)
		var py := clampi(int(at.y) + 10, 4, SHOT.y - 16)
		ArtBench.label(img, text, Vector2i(px, py), colour)

func _caption(img: Image, mode: String) -> void:
	var gold := Color(1.0, 0.83, 0.36)
	var green := Color(0.34, 1.0, 0.12)
	var pale := Color(0.72, 0.76, 0.80)
	if mode == "GREYSCALE":
		gold = Color(1, 1, 1)
		green = Color(0.85, 0.85, 0.85)
	ArtBench.label(img, "FAMILY BOARD - %s" % mode, Vector2i(12, 12), gold)
	ArtBench.label(img, "BACK ROW: THE FACILITY BUILT IT", Vector2i(12, 36),
			pale)
	ArtBench.label(img, "FRONT ROW: EPSILON DID", Vector2i(12, 58), green)
	ArtBench.label(img,
			"ONE LIGHT, ONE FLOOR, ONE CAMERA. NO REVIEW STATUS IS PASS.",
			Vector2i(12, img.get_height() - 24), pale)
