extends SceneTree
## The three enemy archetypes in ONE frame at aggro range.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s EnemyLineup.gd -- <assets_root> <out_dir>
##
## The Batch 001 review asked to see melee, ranged and brute together at real
## play distance before detailed production. That is a different question
## from the one the per-asset sheets answer: three silhouettes that each work
## alone can still be indistinguishable side by side, and side by side is how
## a player meets them.
##
## Camera is the game's -- 90 degree lens, 1.6 m eye height -- standing
## `ENEMY_AGGRO_RADIUS` away, which is where the player first sees any of
## them. Three captures: lit, flat-black silhouette, and untextured clay.

## Rendered at the real screen height so a pixel count means something: at
## 1080 the 48 px an aggro-range melee occupies IS 48 px. The sheet then
## shows that strip twice -- once at true scale, once enlarged 3x with
## nearest-neighbour -- because a review image that is honest about the size
## and a review image you can actually judge shapes in are two different
## images, and quietly substituting the second for the first is how a bench
## starts lying.
const SHOT := Vector2i(1600, 1080)
const BAND := 300          ## the horizontal strip the figures occupy
const ZOOM := 3
const AGGRO := 18.0
const KINDS := [
	# X is left on screen for a camera looking down +Z, so these are ordered
	# so the sheet reads melee / ranged / brute LEFT TO RIGHT. The first
	# version labelled them in list order and captioned every figure wrong.
	["enemy_melee_stooped", "MELEE 0.8x1.6", 1.7],
	["enemy_ranged_tripod", "RANGED 0.7x1.4", 0.0],
	["enemy_brute_squat", "BRUTE 1.8x2.6", -2.0],
]

var _assets := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: EnemyLineup.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)

	var vp := ArtBench.make_viewport(self, SHOT, 0.34)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.35)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	ground.mesh = plane
	ground.material_override = ArtBench.flat_material(Color(0.10, 0.105, 0.12))
	root.add_child(ground)

	var figures: Array = []
	for k in KINDS:
		var n: Node3D = ArtBench.load_glb(
				"%s/models/batch001/enemy/%s.glb" % [_assets, k[0]])
		if n == null:
			continue
		ArtBench.force_nearest(n)
		n.position = Vector3(float(k[2]), 0.0, AGGRO)
		# Turned slightly toward the camera: a player never meets one
		# perfectly square on, and a three-quarter read is the honest test.
		n.rotation_degrees = Vector3(0, 198, 0)
		root.add_child(n)
		figures.append(n)

	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 0), Vector3(0, 1.0, AGGRO),
			Vector3.UP)

	var lit: Image = await _grab(vp)
	_where(lit)
	_sheet(lit, "LIT").save_png(out + "/D_enemy_lineup_18m.png")

	ground.visible = false
	var env: Environment = (vp.get_node("WorldEnvironment")
			as WorldEnvironment).environment
	env.background_color = Color(0.78, 0.79, 0.82)
	env.ambient_light_energy = 0.0
	for f in figures:
		ArtBench.apply_override(f, ArtBench.flat_material(Color.BLACK))
	var sil: Image = await _grab(vp)
	_sheet(sil, "SILHOUETTE").save_png(out + "/D_enemy_lineup_silhouette.png")

	env.background_color = ArtBench.BG
	env.ambient_light_energy = 0.34
	ground.visible = true
	for f in figures:
		ArtBench.apply_override(f, ArtBench.clay_material())
	var clay: Image = await _grab(vp)
	_sheet(clay, "CLAY").save_png(out + "/D_enemy_lineup_clay.png")

	print("[lineup] 3 archetypes at %.0f m -> %s" % [AGGRO, out])
	quit()

## True-scale band on top, 3x enlargement below, labelled.
func _sheet(full: Image, mode: String) -> Image:
	# Image.blit_rect requires the SOURCE and DESTINATION formats to match
	# and does nothing at all when they differ -- no error, no warning, just
	# an empty destination. A SubViewport hands back RGBA8, every canvas
	# built here is RGB8, and the first three versions of this sheet came out
	# entirely black for that reason while the render behind them was fine.
	full.convert(Image.FORMAT_RGB8)
	var top := int(SHOT.y * 0.52) - BAND / 2
	var band := Image.create(SHOT.x, BAND, false, full.get_format())
	band.blit_rect(full, Rect2i(0, top, SHOT.x, BAND), Vector2i.ZERO)

	var zw := SHOT.x
	var zh := BAND * ZOOM
	var big := Image.create(zw, zh, false, full.get_format())
	# Nearest-neighbour by hand: these are pixel renders and a smooth
	# upscale would show shapes the game never draws.
	var src_w := int(zw / float(ZOOM))
	var x0 := (SHOT.x - src_w) / 2
	for y in zh:
		for x in zw:
			big.set_pixel(x, y, band.get_pixel(
					x0 + int(x / float(ZOOM)), int(y / float(ZOOM))))

	var head := 30
	var gap := 10
	var out := Image.create(SHOT.x, head + BAND + gap + zh + head, false,
			full.get_format())
	out.fill(Color(0.035, 0.035, 0.042))
	out.blit_rect(band, Rect2i(Vector2i.ZERO, Vector2i(SHOT.x, BAND)),
			Vector2i(0, head))
	out.blit_rect(big, Rect2i(Vector2i.ZERO, Vector2i(zw, zh)),
			Vector2i(0, head + BAND + gap))
	var gold := Color(1.0, 0.83, 0.36)
	ArtBench.label(out, "%s - ALL THREE AT %d M, TRUE 1080P SCALE"
			% [mode, int(AGGRO)], Vector2i(12, 8), gold)
	ArtBench.label(out, "SAME STRIP, %dX NEAREST - SHAPES ONLY, NOT SCALE"
			% ZOOM, Vector2i(12, head + BAND + gap - 22),
			Color(0.45, 0.72, 0.68))
	var x := 150
	for k in KINDS:
		ArtBench.label(out, str(k[1]), Vector2i(x, out.get_height() - 22),
				Color(0.72, 0.76, 0.80))
		x += 470
	return out

## Print the bounding box of everything that is not the background, so a
## crop is aimed at measured content rather than at an assumption about
## where the horizon is.
func _where(img: Image) -> void:
	var x0 := img.get_width()
	var x1 := -1
	var y0 := img.get_height()
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if absf(c.r - ArtBench.BG.r) > 0.02 or absf(c.g - ArtBench.BG.g) > 0.02 \
					or absf(c.b - ArtBench.BG.b) > 0.02:
				x0 = mini(x0, x); x1 = maxi(x1, x)
				y0 = mini(y0, y); y1 = maxi(y1, y)
	print("[lineup] viewport %dx%d, content x %d..%d  y %d..%d"
			% [img.get_width(), img.get_height(), x0, x1, y0, y1])

func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await process_frame
	return vp.get_texture().get_image()
