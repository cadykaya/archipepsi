extends SceneTree
## Batch 002-R — the Epsilon installation, in the five views the review asked
## for.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s EpsilonViews.gd -- <assets_root> <out_dir>
##
## The 002 review named the shots:
##
##   1. wide in-room view          -- ComposedRoom.gd renders this one
##   2. frontal operator view      -- here
##   3. oblique view               -- here
##   4. close detail of the fusion -- here
##   5. silhouette / value read    -- here
##
## The frontal view is the one this revision exists for, and it is the one
## shot in the project taken from a place a PERSON would stand: eye height,
## a pace back from the desk, looking at the screen. Everything about the
## console was built to that camera, so this is where it either works or
## does not.
##
## The value read is a greyscale of the same frame rather than a black
## silhouette. A silhouette answers "can you tell this shape from another";
## the question here is different — does the human machine still read as
## human, and the intrusion as an intrusion, once the green is gone? If the
## split only exists in hue it will not survive a dark room.

const SHOT := Vector2i(1400, 900)
const MODEL := "batch002/epsilon/epsilon_installation.glb"

var _assets := ""
var _out := ""
var _eye := 1.6

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: EpsilonViews.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	# Eye height comes from the engine, through the budgets file. A console
	# judged from the wrong height is a console judged for somebody else.
	var f := FileAccess.open("%s/art_budgets.json" % _assets, FileAccess.READ)
	if f != null:
		var d: Dictionary = JSON.parse_string(f.get_as_text())
		_eye = float(d.get("dimensions", {}).get("player_eye_height", 1.6))

	var vp := ArtBench.make_viewport(self, SHOT, 0.24)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.25)
	# The background matches the backdrop wall.
	#
	# Chasing the void out of the oblique frame by enlarging the floor and
	# wall was the wrong fix twice: a 9 m object shot from three angles at
	# eye height will always find an edge somewhere, and each enlargement
	# just moved it. Painting the environment the same value as the wall
	# means an edge, when a camera finds one, is invisible instead of being
	# a black wedge across a third of the review image.
	var env: Environment = (vp.get_node("WorldEnvironment")
			as WorldEnvironment).environment
	env.background_color = Color(0.56, 0.57, 0.60)

	# A floor and a back wall, so the object has something to stand on and
	# against. Shaded, not flat: an unshaded ground gives the model nothing
	# to cast onto and nothing to sit in.
	_slab(root, Vector3(60, 0.2, 40), Vector3(0, -0.1, -14.0),
			Color(0.42, 0.43, 0.46))
	# Wide and tall enough that no camera below sees past its edge. The
	# fusion shot framed the wall's corner and half the frame was void.
	_slab(root, Vector3(60, 24, 0.3), Vector3(0, 12, 1.55),
			Color(0.56, 0.57, 0.60))

	var node: Node3D = ArtBench.load_glb("%s/models/%s" % [_assets, MODEL])
	if node == null:
		push_error("EpsilonViews: missing %s" % MODEL)
		quit(1)
		return
	ArtBench.force_nearest(node)
	# Floor anchored, backed up to the wall, and YAWED.
	#
	# glTF maps Blender +Y to -Z, so the console face -- authored along
	# Blender -Y -- leaves the exporter pointing at +Z. Without this yaw
	# every camera below looks at the back of the bank: the first render of
	# this sheet was four views of a flat wall of racks with the eruption
	# mirrored onto the wrong end, and nothing in it said so.
	node.position = Vector3(0, 0, 0)
	node.rotation_degrees = Vector3(0, 180, 0)
	root.add_child(node)

	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.current = true
	vp.add_child(cam)

	# 2. FRONTAL OPERATOR VIEW. Eye height, one pace back from the desk,
	#    looking at the screen. This is the shot the revision is for.
	# Aimed LEVEL, not up at the screen. Angled up, the desk top went
	# edge-on and the one surface that says "you work here" disappeared --
	# an operator view that cannot see the desk is a view of a television.
	cam.look_at_from_position(Vector3(0.0, _eye, -3.05),
			Vector3(0.10, 1.62, 0.2), Vector3.UP)
	var front: Image = await _grab(vp)

	# 5. VALUE READ, from the same camera -- derived BEFORE the labels go on.
	#    Desaturating the labelled frame stamped the value caption on top of
	#    the operator caption and both became unreadable. A caption is not
	#    part of the render and must never be measured as if it were.
	var grey := Image.create(front.get_width(), front.get_height(), false,
			Image.FORMAT_RGB8)
	for y in front.get_height():
		for x in front.get_width():
			var c := front.get_pixel(x, y)
			var v: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			grey.set_pixel(x, y, Color(v, v, v))
	ArtBench.label(grey, "VALUE READ - DOES THE SPLIT SURVIVE LOSING THE GREEN?",
			Vector2i(12, 12), Color(1, 1, 1))
	ArtBench.label(grey, "HUMAN MACHINE MID GREY. INTRUSION DARKER AND CANTED.",
			Vector2i(12, 34), Color(0.80, 0.80, 0.80))
	grey.save_png(_out + "/A_epsilon_value.png")

	ArtBench.label(front, "OPERATOR VIEW - EYE HEIGHT %.2f M, ONE PACE BACK"
			% _eye, Vector2i(12, 12), Color(1.0, 0.83, 0.36))
	ArtBench.label(front, "DESK AT 0.95 M. SCREEN AT EYE + 0.45 M.",
			Vector2i(12, 34), Color(0.72, 0.76, 0.80))
	front.save_png(_out + "/A_epsilon_operator.png")

	# 3. OBLIQUE. From the ALIEN end, looking back across the console.
	#    Shot from the human end the mass sat furthest from the camera and
	#    the console's own body hid it -- an oblique of a takeover has to
	#    have the takeover in the foreground.
	cam.look_at_from_position(Vector3(-4.3, 1.95, -3.5),
			Vector3(0.7, 1.60, 0.3), Vector3.UP)
	var oblique: Image = await _grab(vp)
	ArtBench.label(oblique, "OBLIQUE - ALIEN END, LOOKING BACK ACROSS THE CONSOLE",
			Vector2i(12, 12), Color(1.0, 0.83, 0.36))
	oblique.save_png(_out + "/A_epsilon_oblique.png")

	# 4. THE FUSION, close. Where the mass comes over the desk and through
	#    the right-hand side of the monitor.
	cam.look_at_from_position(Vector3(-1.3, 1.80, -2.45),
			Vector3(-2.7, 1.90, -0.1), Vector3.UP)
	var fusion: Image = await _grab(vp)
	ArtBench.label(fusion, "THE FUSION - MASS OVER THE DESK, THROUGH THE SCREEN",
			Vector2i(12, 12), Color(1.0, 0.83, 0.36))
	ArtBench.label(fusion, "NOTHING HUMAN GLOWS. THE LIGHT IS ARRIVING FROM INSIDE.",
			Vector2i(12, 34), Color(0.42, 0.95, 0.30))
	fusion.save_png(_out + "/A_epsilon_fusion.png")

	print("[epsilon] 4 views -> %s" % _out)
	quit()

func _slab(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	mat.metallic = 0.0
	m.material_override = mat
	m.position = at
	root.add_child(m)

func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img
