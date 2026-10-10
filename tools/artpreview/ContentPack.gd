extends SceneTree
## The A/B delta at the light-housing seam, rendered.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s ContentPack.gd -- <assets_root> <out_dir>
##
## Row A is what Playtest 2.5 walked: `ChamberBuilders._light` builds an
## `OmniLight3D` and hangs a hardcoded `BoxMesh` of 0.8 x 0.1 x 0.4 under it,
## tinted by the theme's `light_color`. SIX THEMES, ONE SLAB -- which is the
## finding art requirement 3a was raised for, and it is visible here as six
## identical rectangles in six different tints.
##
## Row B is what the exported pack makes reachable: the approved per-theme
## housing. The LIGHT IS IDENTICAL IN BOTH ROWS and is built by the engine in
## both -- same colour, same energy, same position. That is the whole claim of
## this seam: the housing is what the lamp hangs in, and illumination never
## moves.
##
## The numbers here are read from Production, not invented: the slab's size and
## offset from `chamber_builders.gd`, the colours and energies from
## `Constants.THEME_MATERIALS`.

const THEMES := [
	["concrete_facility", "#eaf2ff", 3.0, "arch_light_fixture"],
	["rusted_industrial", "#ffd9a0", 2.2, "light_rusted_cage"],
	["neon_transit",      "#7cf2ff", 4.0, "light_neon_channel"],
	["gothic_stone",      "#ffb45e", 2.0, "light_gothic_corona"],
	["temple_ruin",       "#ffe9b8", 2.6, "light_temple_bowl"],
	["void_glitch",       "#ffffff", 3.5, "light_void_absent"],
]
const PROJECTILES := ["straight", "falling", "lobbed"]

## Verbatim from `ChamberBuilders._light`.
const SLAB := Vector3(0.8, 0.1, 0.4)
const HANG := Vector3(0.0, -0.05, 0.0)

var _assets := ""
var _out := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: ContentPack.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	await _sheet()
	print("[contentpack] 1 sheet -> %s" % _out)
	quit()

func _shoot(size: Vector2i, build: Callable) -> Image:
	var vp := ArtBench.make_viewport(self, size, 0.10)
	var root := Node3D.new()
	vp.add_child(root)
	build.call(root)
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 34.0
	vp.add_child(cam)
	# One camera for every cell. A seam comparison shot from two distances
	# is not a comparison (L-77).
	# Backed off until the LONGEST approved housing fits: the neon channel is
	# 1.62 m and the facility fixture 1.50 m, and the first pass ran both off
	# the edge of their own cells. One distance for every cell, sized by the
	# widest subject -- the same rule sheet C of 037-R had to learn.
	cam.look_at_from_position(Vector3(1.45, 2.30, 2.95),
			Vector3(0.0, 2.82, 0.0), Vector3.UP)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	await process_frame
	return img

## The ceiling the fixture hangs from, and the lamp itself. Identical in both
## rows, because the engine owns it in both.
func _room(root: Node3D, tint: Color, energy: float) -> void:
	for spec in [[Vector3(6.0, 0.3, 6.0), Vector3(0, 3.15, 0)],
			[Vector3(6.0, 0.3, 6.0), Vector3(0, -0.15, 0)],
			[Vector3(6.0, 3.6, 0.3), Vector3(0, 1.8, -2.4)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.24, 0.25, 0.27)
		mat.roughness = 0.94
		m.material_override = mat
		root.add_child(m)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.0, 0)
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = 12.0
	light.shadow_enabled = false
	root.add_child(light)

func _slab(root: Node3D, tint: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = SLAB
	m.mesh = b
	m.position = Vector3(0, 3.0, 0) + HANG
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.4
	m.material_override = mat
	root.add_child(m)

func _authored(root: Node3D, dir: String, asset: String) -> void:
	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, dir, asset])
	if node == null:
		push_error("contentpack: missing %s" % asset)
		return
	ArtBench.force_nearest(node)
	node.position = Vector3(0, 3.0, 0) + HANG
	root.add_child(node)

func _sheet() -> void:
	var cell := Vector2i(400, 300)
	var sheet := Image.create(cell.x * 6, cell.y * 3 + 150, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in THEMES.size():
		var row: Array = THEMES[i]
		var theme: String = row[0]
		var tint := Color(str(row[1]))
		var energy: float = row[2]
		var asset: String = row[3]
		var dir := "batch001/architecture" if theme == "concrete_facility" \
				else "batch014/lights"

		var a: Image = await _shoot(cell, func(root: Node3D) -> void:
				_room(root, tint, energy)
				_slab(root, tint))
		var b: Image = await _shoot(cell, func(root: Node3D) -> void:
				_room(root, tint, energy)
				_authored(root, dir, asset))
		if a == null or b == null:
			continue
		var at_a := Vector2i(i * cell.x, 150)
		var at_b := Vector2i(i * cell.x, 150 + cell.y)
		sheet.blit_rect(a, Rect2i(Vector2i.ZERO, cell), at_a)
		sheet.blit_rect(b, Rect2i(Vector2i.ZERO, cell), at_b)
		ArtBench.label(sheet, theme.to_upper().replace("_", " "),
				at_a + Vector2i(8, 8), Color(0.72, 0.76, 0.80))
		ArtBench.label(sheet, asset, at_b + Vector2i(8, cell.y - 22),
				Color(1.0, 0.86, 0.42))

	for i in PROJECTILES.size():
		var p: Image = await _shoot(cell, func(root: Node3D) -> void:
				_room(root, Color("#7cf2ff"), 4.0)
				_authored(root, "batch008/enemy",
						"enemy_projectile_%s" % PROJECTILES[i]))
		if p == null:
			continue
		var at := Vector2i(i * cell.x, 150 + cell.y * 2)
		sheet.blit_rect(p, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, "projectile_%s" % PROJECTILES[i],
				at + Vector2i(8, cell.y - 22), Color(1.0, 0.86, 0.42))

	ArtBench.label(sheet, "THE POST-ART DELTA AT THE TWO SEAMS THAT CANNOT "
			+ "MOVE GAMEPLAY", Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "ROW A  WHAT PLAYTEST 2.5 WALKED: ONE HARDCODED "
			+ "0.8 x 0.1 x 0.4 BOX, SIX THEMES, SIX TINTS OF THE SAME SLAB.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "ROW B  THE APPROVED HOUSING THE EXPORTED PACK "
			+ "MAKES REACHABLE. ROW C  THE THREE AUTHORED PROJECTILE "
			+ "SILHOUETTES.", Vector2i(12, 68), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "THE LAMP IS IDENTICAL IN BOTH ROWS AND IS BUILT "
			+ "BY THE ENGINE IN BOTH -- SAME COLOUR, SAME ENERGY, SAME "
			+ "POSITION. ONLY THE HOUSING CHANGES.", Vector2i(12, 94),
			Color(0.94, 0.62, 0.42))
	ArtBench.label(sheet, "NO COLLISION, NO LIGHT, NO DIMENSION AND NO "
			+ "SOCKET IS AUTHORED HERE. ROOM SHELLS ARE DELIBERATELY NOT "
			+ "EXPORTED -- SEE THE HANDOFF.", Vector2i(12, 120),
			Color(0.60, 0.64, 0.68))
	sheet.save_png("%s/A_content_pack_delta.png" % _out)
