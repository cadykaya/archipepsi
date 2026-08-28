extends SceneTree
## Batch 001 I -- one room, assembled from Batch 001 pieces only.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s ComposedRoom.gd -- <assets_root> <out_dir>
##
## ## What this shot is for, and it is not a turntable
##
## Every other sheet in the batch judges one object from angles chosen to
## show that object. This one asks the only question those cannot: do the
## pieces make a PLACE? A kit can pass eight review shots each and still
## assemble into something that reads as a showroom of props rather than as
## a room somebody built and then left.
##
## So the camera is the game's: 90 degree FOV, 1.6 m eye height, standing on
## the floor. No flattering lens, no elevated three-quarter, no rig the
## player never occupies.
##
## ## Four captures, and the fourth is the honest one
##
##   room_wide     the room, from the doorway
##   room_near     the same room from inside it, at working distance
##   room_grey     room_wide desaturated. If the composition falls apart in
##                 greyscale the palette is not working -- this is the
##                 quickest honest test there is
##   room_check_*  the same camera, same room, with each Check concept
##                 standing in the same place. Judging three concepts in
##                 context, without choosing between them
##
## Also prints the room's authored triangle count against the 12,000 budget
## in art_budgets.json, because "does a room fit its budget" is a number and
## a screenshot cannot show it.

const SHOT := Vector2i(1280, 720)
const MODULE := 4.0
const ROOM_W := 12.0
const ROOM_D := 12.0
const WALL_H := 4.0

var _assets := ""
var _out := ""
var _tris := 0
var _theme := "concrete_facility"

## Which theme texture each module wears. The modules bake concrete_facility
## in at build time, so re-theming them here means overriding the albedo with
## the theme sheet for that role -- which is exactly the model the runtime
## should eventually use: ONE authored mesh, six theme materials, selected by
## Godot. Proving it works in the bench is worth as much as the probe itself.
const MODULE_ROLE := {
	"arch_wall_panel": "wall", "arch_wall_ribbed": "wall_ribbed",
	"arch_doorway": "wall", "arch_floor_slab": "floor",
	"arch_ceiling_beam": "ceiling", "arch_trim_rail": "trim",
	"arch_railing": "trim", "arch_pipe_run": "accent",
	"prop_crate": "accent", "prop_utility_box": "trim",
	"prop_machinery_unit": "accent", "prop_pipe_cluster": "trim",
	"prop_debris": "floor", "prop_terminal": "accent",
	"prop_warning_sign": "accent",
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: ComposedRoom.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	if args.size() > 2:
		_theme = args[2]
	DirAccess.make_dir_recursive_absolute(_out)

	# Ambient 0.10, not 0.30. The first room render summed three omni lights
	# at the theme's own energy (3.0), an ambient of 0.30 and a directional
	# fill, and every wall clipped to pure white -- ARTSTYLE's "flat is not
	# bright" failure exactly. The fix was not to darken the palette: it was
	# to sum the light energies before touching anything else. The omnis are
	# the game's own (theme energy, range 12, shadows off, per
	# chamber_builders._light); the ambient exists only so shadows show
	# which palette family they belong to.
	var vp := ArtBench.make_viewport(self, SHOT, 0.10)
	var root := Node3D.new()
	vp.add_child(root)
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.current = true
	vp.add_child(cam)

	_build_room(root)
	_place_props(root)
	_place_lights(root)
	print("[room] theme %s, authored triangles: %d (budget 12000)"
			% [_theme, _tris])

	if _theme != "concrete_facility":
		# A theme probe answers one question -- does this material family
		# survive being a room rather than a texture sheet -- so it is one
		# shot from the doorway plus its greyscale, and nothing else.
		cam.look_at_from_position(Vector3(0.0, 1.6, -ROOM_D * 0.5 + 1.2),
				Vector3(0.6, 1.5, ROOM_D * 0.5 - 2.0), Vector3.UP)
		var probe: Image = await _grab(vp)
		ArtBench.label(probe, "%s - IN ENGINE" % _theme.to_upper().replace("_", " "),
				Vector2i(12, 12), Color(1.0, 0.83, 0.36))
		probe.save_png("%s/H_probe_%s_room.png" % [_out, _theme])
		var g := Image.create(probe.get_width(), probe.get_height(), false,
				probe.get_format())
		for y in probe.get_height():
			for x in probe.get_width():
				var c := probe.get_pixel(x, y)
				var v: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				g.set_pixel(x, y, Color(v, v, v))
		ArtBench.label(g, "%s - GREYSCALE" % _theme.to_upper().replace("_", " "),
				Vector2i(12, 12), Color(1, 1, 1))
		g.save_png("%s/H_probe_%s_greyscale.png" % [_out, _theme])
		print("[room] wrote 2 probe captures for %s" % _theme)
		quit()
		return

	# From the doorway, looking down the room. This is how a player enters.
	cam.look_at_from_position(Vector3(0.0, 1.6, -ROOM_D * 0.5 + 1.2),
			Vector3(0.6, 1.5, ROOM_D * 0.5 - 2.0), Vector3.UP)
	var wide: Image = await _grab(vp)
	wide.save_png(_out + "/I_room_wide.png")

	# Desaturated. The quickest honest test of a palette there is.
	var grey := Image.create(wide.get_width(), wide.get_height(), false,
			Image.FORMAT_RGB8)
	for y in wide.get_height():
		for x in wide.get_width():
			var c := wide.get_pixel(x, y)
			# Rec.709 luma, so the greyscale matches what value separation
			# was computed against rather than a flat channel average.
			var v: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			grey.set_pixel(x, y, Color(v, v, v))
	ArtBench.label(grey, "GREYSCALE TEST", Vector2i(12, 12),
			Color(1.0, 1.0, 1.0))
	grey.save_png(_out + "/I_room_greyscale.png")

	# Inside the room, at the distance you actually work at.
	cam.look_at_from_position(Vector3(-2.4, 1.6, 0.4),
			Vector3(3.2, 1.2, 4.2), Vector3.UP)
	var near: Image = await _grab(vp)
	near.save_png(_out + "/I_room_near.png")

	# The three Check concepts, same room, same camera, same spot. No winner
	# is picked here and none may be: that is the owner's call.
	cam.look_at_from_position(Vector3(0.0, 1.6, -ROOM_D * 0.5 + 1.2),
			Vector3(0.0, 1.4, 3.4), Vector3.UP)
	for concept in ["check_a_pedestal", "check_b_vault", "check_c_mast"]:
		var node: Node3D = ArtBench.load_glb(
				"%s/models/batch001/check/%s.glb" % [_assets, concept])
		if node == null:
			continue
		ArtBench.force_nearest(node)
		node.position = Vector3(0.0, 0.0, 3.4)
		root.add_child(node)
		var shot: Image = await _grab(vp)
		ArtBench.label(shot, concept.replace("_", " "), Vector2i(12, 12),
				Color(1.0, 0.83, 0.36))
		shot.save_png("%s/I_room_%s.png" % [_out, concept])
		root.remove_child(node)
		node.queue_free()
		await process_frame

	# The warm-light proposal, same room, same camera, relit.
	warm = true
	for child in root.get_children():
		if child is OmniLight3D:
			child.light_color = _light_colour()
	cam.look_at_from_position(Vector3(0.0, 1.6, -ROOM_D * 0.5 + 1.2),
			Vector3(0.6, 1.5, ROOM_D * 0.5 - 2.0), Vector3.UP)
	var warm_shot: Image = await _grab(vp)
	ArtBench.label(warm_shot, "PROPOSED WARM LIGHT - NOT ENGINE TRUTH",
			Vector2i(12, 12), Color(1.0, 0.83, 0.36))
	warm_shot.save_png(_out + "/I_room_warmlight_proposal.png")
	warm = false

	print("[room] wrote 7 captures to %s" % _out)
	quit()

func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await process_frame
	return vp.get_texture().get_image()

func _add(root: Node3D, relative: String, at: Vector3,
		yaw: float = 0.0) -> Node3D:
	var node: Node3D = ArtBench.load_glb("%s/models/%s" % [_assets, relative])
	if node == null:
		return null
	ArtBench.force_nearest(node)
	if _theme != "concrete_facility":
		_retheme(node, relative.get_file().get_basename())
	node.position = at
	node.rotation_degrees = Vector3(0, yaw, 0)
	root.add_child(node)
	_tris += _count(node)
	return node

## Swap a module's baked albedo for the same role in another theme.
func _retheme(node: Node, module: String) -> void:
	var role: String = MODULE_ROLE.get(module, "wall")
	var path := "%s/textures/theme/%s_%s.png" % [_assets, _theme, role]
	if not FileAccess.file_exists(path):
		path = "%s/textures/theme/%s_wall.png" % [_assets, _theme]
	var img := Image.load_from_file(path)
	if img == null:
		push_error("[room] no theme texture: %s" % path)
		return
	var tex := ImageTexture.create_from_image(img)
	for mat in ArtBench.materials(node):
		if mat is BaseMaterial3D and mat.albedo_texture != null:
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

func _count(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			for i in child.mesh.get_surface_count():
				total += child.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size() / 3
		total += _count(child)
	return total

func _build_room(root: Node3D) -> void:
	var half_w := ROOM_W * 0.5
	var half_d := ROOM_D * 0.5
	# Floor: nine 4 m slabs, laid on the module grid the kit is built to.
	for ix in 3:
		for iz in 3:
			_add(root, "batch001/architecture/arch_floor_slab.glb",
					Vector3(-half_w + MODULE * (ix + 0.5), -0.4,
							-half_d + MODULE * (iz + 0.5)))
	# Walls. The far wall carries the doorway, because a room with no way
	# out is a diorama.
	for i in 3:
		var x := -half_w + MODULE * (i + 0.5)
		var z := -half_d + MODULE * (i + 0.5)
		# Alternate plain and ribbed bays. The review found the room read
		# as "every surface exposes the same exact 4 m panel rhythm" -- the
		# answer is a second rhythm, not the removal of the first. The
		# ribbed bay also stands 0.22 m proud, so it shades itself even
		# though the game's own lights cast no shadows.
		var plain := "batch001/architecture/arch_wall_panel.glb"
		var ribbed := "batch001/architecture/arch_wall_ribbed.glb"
		var far := "batch001/architecture/arch_doorway.glb" if i == 1 else plain
		_add(root, far, Vector3(x, 0, half_d), 0.0)
		_add(root, ribbed if i == 1 else plain, Vector3(x, 0, -half_d), 180.0)
		_add(root, plain if i == 1 else ribbed, Vector3(-half_w, 0, z), 90.0)
		_add(root, ribbed if i == 0 else plain, Vector3(half_w, 0, z), -90.0)
		# Kick rail everywhere the wall meets the floor. Trim is what does
		# the job a bevel does elsewhere in this project.
		_add(root, "batch001/architecture/arch_trim_rail.glb",
				Vector3(x, 0, half_d - 0.26), 0.0)
		_add(root, "batch001/architecture/arch_trim_rail.glb",
				Vector3(x, 0, -half_d + 0.26), 180.0)
		_add(root, "batch001/architecture/arch_trim_rail.glb",
				Vector3(-half_w + 0.26, 0, z), 90.0)
		_add(root, "batch001/architecture/arch_trim_rail.glb",
				Vector3(half_w - 0.26, 0, z), -90.0)
	# Ceiling bays, placed at the ceiling PLANE. The .glb is anchored
	# "ceiling", so its deck is at Z 0 and the downstand hangs into the room
	# -- which is the entire point of it and was invisible while every asset
	# went through one floor-anchoring path.
	for ix in 3:
		for iz in 3:
			_add(root, "batch001/architecture/arch_ceiling_beam.glb",
					Vector3(-half_w + MODULE * (ix + 0.5), WALL_H + 0.25,
							-half_d + MODULE * (iz + 0.5)))
	# A pipe run at high level down one side.
	for i in 3:
		_add(root, "batch001/architecture/arch_pipe_run.glb",
				Vector3(-half_w + 0.55, 0, -half_d + MODULE * (i + 0.5)), 90.0)
	# A railed platform: the one piece of vertical interest, at a height the
	# player can actually reach (MAX_VERTICAL_STEP is 1.0 m and the crate is
	# exactly that, so the platform is climbable via the crate).
	#
	# The DECK comes first. The first render placed the railing at 1.0 m with
	# nothing under it -- a guard rail floating in mid-air, guarding nothing.
	# A railing is a piece that only means anything in relation to an edge,
	# and a kit shot that omits the edge is testing the wrong thing.
	_add(root, "batch001/architecture/arch_floor_slab.glb",
			Vector3(half_w - MODULE * 0.5, 1.0, 2.0))
	_add(root, "batch001/architecture/arch_railing.glb",
			Vector3(half_w - MODULE, 1.0, 2.0), 90.0)
	# Crates against the deck edge: the way up. A platform with no route on
	# to it is scenery.
	_add(root, "batch001/props/prop_crate.glb",
			Vector3(half_w - MODULE - 0.7, 0, 2.6), -14.0)

func _place_props(root: Node3D) -> void:
	# Dressing placed as CLUSTERS with a reason, never scattered evenly. A
	# prop every two metres reads as decoration; three things against one
	# wall reads as somewhere people worked.
	_add(root, "batch001/props/prop_machinery_unit.glb",
			Vector3(-4.2, 0, 4.6), 12.0)
	_add(root, "batch001/props/prop_pipe_cluster.glb",
			Vector3(-5.3, 0, 3.0), -8.0)
	_add(root, "batch001/props/prop_utility_box.glb",
			Vector3(-5.6, 1.2, 1.2), 90.0)
	# Anchored "wall": its back face is at Y 0, so it sits flush on the wall
	# plane rather than floating in front of it.
	_add(root, "batch001/props/prop_warning_sign.glb",
			Vector3(-half_w_prop(), 1.9, 4.6), 90.0)

	_add(root, "batch001/props/prop_crate.glb", Vector3(3.6, 0, -3.4), 8.0)
	_add(root, "batch001/props/prop_crate.glb", Vector3(4.7, 0, -3.0), -22.0)
	_add(root, "batch001/props/prop_crate.glb", Vector3(3.9, 1.01, -3.3), 31.0)
	_add(root, "batch001/props/prop_terminal.glb", Vector3(5.0, 0, 0.4), -80.0)
	_add(root, "batch001/props/prop_debris.glb", Vector3(1.4, 0, -4.6), 44.0)


## The engine's own light colour for concrete_facility, or the warm one the
## Batch 001 review asked for.
##
## THEME_MATERIALS says `light_color: #eaf2ff` -- a cool white. The owner's
## facility direction says "yellow utility lighting". Those disagree, and the
## anchor is ENGINEERING's file, not the art lane's. So the room is rendered
## in the engine's truth by default and once more in the proposed warm light,
## and the owner decides whether to ask for the anchor to change. Art does not
## change an engine colour by rendering as though it already had.
static var warm := false

func _light_colour() -> Color:
	if warm:
		return Color(1.0, 0.855, 0.60)
	# THEME_MATERIALS light_color, per theme.
	match _theme:
		"void_glitch": return Color(1.0, 1.0, 1.0)
		"rusted_industrial": return Color(1.0, 0.851, 0.627)
		_: return Color(0.918, 0.949, 1.0)

func half_w_prop() -> float:
	## The inside face of the left wall: half the room minus the wall's own
	## thickness, read from the module rather than guessed.
	return ROOM_W * 0.5 - 0.2

func _place_lights(root: Node3D) -> void:
	# The fixtures say where the light comes from; the lights themselves are
	# separate, because a fixture bright enough to light a room is a fixture
	# you cannot look at.
	# TWO fixtures, not three. chamber_builders._light spaces them by
	# chamber length, and three at the theme's own energy of 3.0 in a 12 m
	# room is more light than the game would ever put here.
	for i in 2:
		var z := -3.0 + i * 6.0
		# Anchored "ceiling": hangs below the plane it is placed on.
		_add(root, "batch001/architecture/arch_light_fixture.glb",
				Vector3(0.0, WALL_H - 0.72, z))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, WALL_H - 1.15, z)
		# chamber_builders._light: theme energy, range 12, shadows OFF.
		lamp.light_energy = 3.0
		lamp.light_color = _light_colour()
		lamp.omni_range = 12.0
		# chamber_builders._light sets shadow_enabled = false, and so does
		# this. A bench that switched shadows on would be showing depth the
		# game does not render. The extra depth in this revision comes from
		# geometry that shades ITSELF -- a 0.22 m pilaster and a 0.60 m
		# downstand present faces at different angles to the light, which
		# reads with or without shadow casting.
		lamp.shadow_enabled = false
		lamp.name = "Lamp%d" % i
		root.add_child(lamp)
	# No directional fill. The game does not have one, and adding one here
	# would make the bench flatter and prettier than the thing it is
	# reviewing -- which is the definition of a camera that lies.
