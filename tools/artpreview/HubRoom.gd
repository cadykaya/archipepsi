extends SceneTree
## Batch 003 -- the Hub, built out of authored assets.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s HubRoom.gd -- <assets_root> <out_dir>
##
## `ComposedRoom.gd` answers "does the kit make a place". This answers a
## harder and more specific question: **does the kit make THE HUB** -- the
## one room the player sees more than any other, at its real 22 x 16 x 5 m,
## with every fixture where `hub/hub.gd` actually puts it.
##
## The room itself comes from `hub_scene.gd`, which both this and the shot
## runner build from -- a second copy of the Hub would be a second Hub to
## keep in step with `hub.gd`. Every dimension and position in it is read
## out of that file. Nothing is a composition choice:
##
##   room            22 x 16 x 5 m
##   spawn           (0, 0.8, 3.0) facing -Z, so the camera is the player's
##   shop            (-W/2 + 1.6, 0, D * 0.45), yaw -90
##   archive         (W/2 - 1.6, 0, D * 0.45), yaw +90
##   abandon         (-W/2 + 2.4, 0, D - 2.4)
##   campaign board  (-W/2 + 0.35, 2.3, D * 0.62)
##   controls board  (W/2 - 0.35, 2.2, D * 0.62)
##   lab doorway     -X wall at z 6.0, a 3.0 x 3.2 m opening
##   lights          two, at (+/-W/4, H - 0.4, D/2), theme energy, range 16
##
## The Epsilon installation is placed here too, and its position is the ONE
## thing in this scene that is a proposal rather than a reading: `hub.gd`
## has no fixture for it. See the caption on the shot and interface item 4
## in `ART_FRONTIER.md`.

const SHOT := Vector2i(1440, 810)
const W := 22.0
const D := 16.0
const H := 5.0
const MODULE := 4.0

var _assets := ""
var _out := ""
var _tris := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: HubRoom.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)

	# Ambient 0.10, as ComposedRoom uses. The Hub's own env sets 0.4, but
	# that is on top of a room with no authored surfaces in it; summing the
	# two omnis at theme energy 3.0 with 0.4 ambient clips every wall, which
	# is the "flat is not bright" failure this bench already paid for once.
	var vp := ArtBench.make_viewport(self, SHOT, 0.10)
	var root := Node3D.new()
	vp.add_child(root)
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.current = true
	vp.add_child(cam)

	_tris = HubScene.build(root, _assets)
	print("[hub] authored triangles: %d" % _tris)

	# 1. From the spawn. hub.gd spawns the player at (0, 0.8, 3.0) facing
	#    -Z... and then the room is built toward +Z, so the first thing a
	#    player does is turn around. This is that view.
	cam.look_at_from_position(Vector3(0.0, 1.6, 3.0),
			Vector3(0.0, 1.5, D), Vector3.UP)
	var spawn: Image = await _grab(vp)
	ArtBench.label(spawn, "THE HUB FROM SPAWN - 22 X 16 X 5 M",
			Vector2i(12, 12), Color(1.0, 0.83, 0.36))
	ArtBench.label(spawn, "EVERY FIXTURE WHERE HUB.GD PUTS IT",
			Vector2i(12, 34), Color(0.72, 0.76, 0.80))
	spawn.save_png(_out + "/I_hub_from_spawn.png")

	var grey := Image.create(spawn.get_width(), spawn.get_height(), false,
			Image.FORMAT_RGB8)
	for y in spawn.get_height():
		for x in spawn.get_width():
			var c := spawn.get_pixel(x, y)
			var v: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			grey.set_pixel(x, y, Color(v, v, v))
	ArtBench.label(grey, "GREYSCALE - DOES THE ROOM COMPOSE WITHOUT COLOUR?",
			Vector2i(12, 12), Color(1, 1, 1))
	grey.save_png(_out + "/I_hub_greyscale.png")

	# 2. The shop wall, from where you would walk up to it.
	cam.look_at_from_position(Vector3(-6.0, 1.6, 6.2),
			Vector3(-W / 2.0, 1.4, D * 0.45), Vector3.UP)
	var shop: Image = await _grab(vp)
	ArtBench.label(shop, "THE SHOP WALL - COUNTER, LAB DOORWAY, CAMPAIGN BOARD",
			Vector2i(12, 12), Color(1.0, 0.83, 0.36))
	shop.save_png(_out + "/I_hub_shop_wall.png")

	# 3. The back wall, where the portal and the Epsilon installation are.
	cam.look_at_from_position(Vector3(3.4, 1.6, 8.0),
			Vector3(-3.0, 1.6, D - 1.0), Vector3.UP)
	var back: Image = await _grab(vp)
	ArtBench.label(back, "THE BACK WALL - EPSILON PROPOSED AT X -5.5, Z 14.2",
			Vector2i(12, 12), Color(1.0, 0.83, 0.36))
	ArtBench.label(back, "PLACEMENT IS AN ART PROPOSAL. HUB.GD HAS NO FIXTURE FOR IT.",
			Vector2i(12, 34), Color(0.42, 0.95, 0.30))
	back.save_png(_out + "/I_hub_back_wall.png")

	print("[hub] 4 captures -> %s" % _out)
	quit()

func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img
