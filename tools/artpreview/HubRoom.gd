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
## Every dimension and position below is read out of `hub.gd`. Nothing here
## is a composition choice:
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

	_build_shell(root)
	_place_fixtures(root)
	_place_lights(root)
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

## The shell, on the module grid, with pilasters absorbing the remainder.
func _build_shell(root: Node3D) -> void:
	# Floor and ceiling: whole 4 m slabs, plus a part row, because 22 is not
	# a multiple of 4 and the floor has to reach the wall either way.
	var nx: int = int(ceil(W / MODULE))
	var nz: int = int(ceil(D / MODULE))
	for ix in nx:
		for iz in nz:
			var x: float = -W / 2.0 + MODULE * 0.5 + ix * MODULE
			var z: float = MODULE * 0.5 + iz * MODULE
			_add(root, "batch001/architecture/arch_floor_slab.glb",
					Vector3(x, 0, z))
			_add(root, "batch001/architecture/arch_ceiling_beam.glb",
					Vector3(x, H, z))

	# The four walls. Each run is whole modules; the leftover goes into the
	# pilasters, which is what they are for.
	for iz in nz:
		var z: float = MODULE * 0.5 + iz * MODULE
		for side in [-1.0, 1.0]:
			var x: float = side * W / 2.0
			# The Lab doorway takes the -X wall's bay at z 6.
			if side < 0.0 and absf(z - 6.0) < MODULE * 0.5:
				_add(root, "batch003/architecture/hub_lab_doorway.glb",
						Vector3(x, 0, 6.0), 90.0)
				continue
			_add(root, "batch001/architecture/arch_wall_panel.glb",
					Vector3(x, 0, z), 90.0 * side)
			_add(root, "batch003/architecture/arch_wall_upper.glb",
					Vector3(x, MODULE, z), 90.0 * side)
	for ix in nx:
		var x: float = -W / 2.0 + MODULE * 0.5 + ix * MODULE
		for spec in [[0.0, 0.0], [D, 180.0]]:
			_add(root, "batch001/architecture/arch_wall_panel.glb",
					Vector3(x, 0, float(spec[0])), float(spec[1]))
			_add(root, "batch003/architecture/arch_wall_upper.glb",
					Vector3(x, MODULE, float(spec[0])), float(spec[1]))
		# A pilaster on every module joint, and the corners get one too.
		_add(root, "batch003/architecture/arch_pilaster.glb",
				Vector3(x - MODULE * 0.5, 0, 0.25))
		_add(root, "batch003/architecture/arch_pilaster.glb",
				Vector3(x - MODULE * 0.5, 0, D - 0.25), 180.0)

	# Trim rail along the base of the long walls, and a pipe run overhead.
	for iz in nz:
		var z: float = MODULE * 0.5 + iz * MODULE
		for side in [-1.0, 1.0]:
			_add(root, "batch001/architecture/arch_trim_rail.glb",
					Vector3(side * (W / 2.0 - 0.24), 0, z), 90.0 * side)
	for ix in nx:
		var x: float = -W / 2.0 + MODULE * 0.5 + ix * MODULE
		_add(root, "batch001/architecture/arch_pipe_run.glb",
				Vector3(x, 0, D - 0.55), 180.0)

func _place_fixtures(root: Node3D) -> void:
	# Positions straight out of hub.gd. The yaws are hub.gd's too, converted
	# from radians: shop -PI/2, archive +PI/2.
	_add(root, "batch003/hub/hub_shop_counter.glb",
			Vector3(-W / 2.0 + 1.6, 0, D * 0.45), -90.0)
	_add(root, "batch003/hub/hub_archive_terminal.glb",
			Vector3(W / 2.0 - 1.6, 0, D * 0.45), 90.0)
	_add(root, "batch003/hub/hub_abandon_station.glb",
			Vector3(-W / 2.0 + 2.4, 0, D - 2.4))
	# The boards are centre-anchored, so their hub.gd Y is their centre.
	_add(root, "batch003/hub/hub_campaign_board.glb",
			Vector3(-W / 2.0 + 0.35, 2.3, D * 0.62), -90.0)
	_add(root, "batch003/hub/hub_controls_board.glb",
			Vector3(W / 2.0 - 0.35, 2.2, D * 0.62), 90.0)

	# The portal, at hub.gd's (0, 0, D - 1.2).
	_add(root, "batch002/portal/portal_b2_wound.glb",
			Vector3(0, 0, D - 1.2), 180.0)

	# EPSILON. This position is a PROPOSAL, and the only one in the scene.
	#
	# hub.gd has no fixture for the installation and the generic terminal
	# envelope it does have is 2.0 x 3.0 x 0.8 m -- the installation is
	# 9.02 x 3.48 x 3.55. It needs a reserved bay. The back wall left of the
	# portal is the only 9 m of wall in the room that is not already spoken
	# for, and it puts Epsilon in the player's eyeline on the turn from
	# spawn, which is where the thing that talks to you belongs.
	#
	# It does clash with the abandon console at (-8.6, 0, 13.6), and that
	# clash is the interface item, not something art resolves quietly.
	_add(root, "batch002/epsilon/epsilon_installation.glb",
			Vector3(-5.5, 0, D - 1.8), 180.0)

func _place_lights(root: Node3D) -> void:
	# hub.gd: two omnis at (+/-W/4, H - 0.4, D/2), theme energy, range 16.
	# Its own _light helper sets shadows off, and so does this.
	for side in [-1.0, 1.0]:
		var at: Vector3 = Vector3(side * W / 4.0, H - 0.4, D / 2.0)
		_add(root, "batch001/architecture/arch_light_fixture.glb",
				at + Vector3(0, 0.4, 0))
		var lamp := OmniLight3D.new()
		lamp.position = at - Vector3(0, 0.35, 0)
		lamp.light_energy = 3.0
		lamp.light_color = Color(0.918, 0.949, 1.0)
		lamp.omni_range = 16.0
		lamp.shadow_enabled = false
		root.add_child(lamp)

	# And the locked lighting rule: the room stays cold, and the warmth is
	# local. Three utility lamps on the long walls, dimmer than the ceiling
	# and on a range that falls off inside the room.
	for at in [Vector3(-W / 2.0, 2.1, 3.2), Vector3(W / 2.0, 2.1, 9.0),
			Vector3(-W / 2.0, 2.1, 12.4)]:
		var yaw: float = 90.0 if at.x < 0.0 else -90.0
		_add(root, "batch002/architecture/arch_utility_lamp.glb", at, yaw)
		var pool := OmniLight3D.new()
		pool.position = at + Vector3(0.45 if at.x < 0.0 else -0.45, -0.12, 0)
		pool.light_energy = 1.4
		pool.light_color = Color(1.0, 0.784, 0.451)
		pool.omni_range = 2.6
		pool.shadow_enabled = false
		root.add_child(pool)

func _add(root: Node3D, relative: String, at: Vector3,
		yaw: float = 0.0) -> Node3D:
	var node: Node3D = ArtBench.load_glb("%s/models/%s" % [_assets, relative])
	if node == null:
		push_error("HubRoom: missing %s" % relative)
		return null
	ArtBench.force_nearest(node)
	node.position = at
	node.rotation_degrees = Vector3(0, yaw, 0)
	root.add_child(node)
	_tris += _count(node)
	return node

func _count(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			for s in child.mesh.get_surface_count():
				total += child.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
		total += _count(child)
	return total

func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img
