extends SceneTree
## Batch 002 D -- the WHOLE roster in one frame at aggro range.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s EnemyFamily.gd -- <assets_root> <out_dir>
##
## `EnemyLineup.gd` answers "can you tell the three archetypes apart". This
## answers the harder question the 001-R review actually asked: ten roles
## presented AS A FAMILY -- do they read as one ecosystem, and can you still
## tell any two of them apart at the distance you meet them?
##
## Two ranks of five rather than one rank of ten, because ten figures across
## a 90-degree lens puts the outer ones so far off-axis that the projection
## itself distorts the silhouette, and a bench that distorts what it is
## measuring is not a bench. Both ranks stand at the same 18 m, so a pixel in
## the top strip and a pixel in the bottom strip mean the same thing.
##
## The two flyers are the reason the ranks are split the way they are: they
## are placed at their PROPOSED hover heights, which is the only way to see
## whether "look up" reads at all.

const SHOT := Vector2i(1600, 1080)
const BAND := 380
const ZOOM := 2
const AGGRO := 18.0

## [model, batch, label, x, hover]. X is left on screen for a camera looking
## down +Z, so the lists are ordered so each rank reads LEFT TO RIGHT on the
## sheet -- the mistake EnemyLineup.gd made first was labelling in list order
## and captioning every figure wrong.
const RANK_A := [
	["enemy_melee_stooped", "batch001", "MELEE", 6.0, 0.0],
	["enemy_ranged_tripod", "batch001", "RANGED", 3.0, 0.0],
	["enemy_brute_squat", "batch001", "BRUTE", 0.0, 0.0],
	["enemy_charger", "batch002", "CHARGER", -3.2, 0.0],
	["enemy_bulwark", "batch002", "BULWARK", -6.2, 0.0],
]
const RANK_B := [
	["enemy_scuttler", "batch002", "SCUTTLER", 6.0, 0.0],
	["enemy_artillery", "batch002", "ARTILLERY", 3.0, 0.0],
	["enemy_beacon", "batch002", "BEACON", 0.0, 0.0],
	["enemy_diver", "batch002", "DIVER (FLYER)", -3.2, 1.90],
	["enemy_drifter", "batch002", "DRIFTER (FLYER)", -6.2, 2.55],
]

var _assets := ""
var _out := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: EnemyFamily.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)

	var lit_a: Image = await _rank(RANK_A, false)
	var lit_b: Image = await _rank(RANK_B, false)
	_compose(lit_a, lit_b, "LIT").save_png(_out + "/D_enemy_family_18m.png")

	var sil_a: Image = await _rank(RANK_A, true)
	var sil_b: Image = await _rank(RANK_B, true)
	_compose(sil_a, sil_b, "SILHOUETTE").save_png(
			_out + "/D_enemy_family_silhouette.png")

	print("[family] 10 roles at %.0f m -> %s" % [AGGRO, _out])
	quit()

## One rank, built from scratch each time. Rebuilding rather than restyling
## keeps the silhouette pass from inheriting a material override that the lit
## pass left behind -- which is exactly how a "silhouette" ends up being the
## lit render with the lights turned down.
func _rank(rank: Array, silhouette: bool) -> Image:
	var vp := ArtBench.make_viewport(self, SHOT, 0.0 if silhouette else 0.34)
	var root := Node3D.new()
	vp.add_child(root)
	if not silhouette:
		ArtBench.add_lights(root, 1.35)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		# A STRIP, not a field. The content crop below measures what is not
		# background, and a ground plane filling the frame would make that
		# measurement say "everything".
		plane.size = Vector2(26, 9)
		ground.mesh = plane
		ground.material_override = ArtBench.flat_material(
				Color(0.10, 0.105, 0.12))
		ground.position = Vector3(0.0, 0.0, AGGRO)
		root.add_child(ground)
	else:
		var env: Environment = (vp.get_node("WorldEnvironment")
				as WorldEnvironment).environment
		env.background_color = Color(0.78, 0.79, 0.82)

	for k in rank:
		var n: Node3D = ArtBench.load_glb("%s/models/%s/enemy/%s.glb"
				% [_assets, str(k[1]), str(k[0])])
		if n == null:
			push_error("EnemyFamily: missing %s" % str(k[0]))
			continue
		ArtBench.force_nearest(n)
		# A flyer's glb is anchored at its own centre, so its hover height is
		# applied HERE and stated in the manifest, never baked into the mesh.
		n.position = Vector3(float(k[3]), float(k[4]), AGGRO)
		n.rotation_degrees = Vector3(0, 198, 0)
		if silhouette:
			ArtBench.apply_override(n, ArtBench.flat_material(Color.BLACK))
		root.add_child(n)

	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 0), Vector3(0, 1.3, AGGRO),
			Vector3.UP)
	var img: Image = await _grab(vp)
	vp.queue_free()
	await process_frame
	return img

## Two true-scale bands, then both enlarged, then the role labels.
##
## The bands are CROPPED to the content, and that is not cosmetic. The
## camera is the game's -- a 90 degree VERTICAL fov on a 16:9 viewport, so
## 1600 px covers 53 m of world at 18 m -- and five figures standing 3 m
## apart occupy about a third of it. The first sheet was three quarters
## empty floor with the roster huddled in the middle, which is a picture of
## the lens rather than of the enemies. Cropping changes the framing and
## changes nothing about scale: a pixel is still a pixel, and the 2x
## enlargement below still says so.
func _compose(a: Image, b: Image, mode: String) -> Image:
	# blit_rect silently does NOTHING when the formats differ, and a
	# SubViewport hands back RGBA8 while every canvas built here is RGB8.
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var bg := Color(0.78, 0.79, 0.82) if mode == "SILHOUETTE" else ArtBench.BG
	var box_a := _content(a, bg)
	var box_b := _content(b, bg)
	# One crop for both ranks. Two different crops would put the two strips
	# at two different framings and invite a comparison that is not true.
	var x0 := maxi(0, mini(box_a.position.x, box_b.position.x) - 24)
	var x1 := mini(SHOT.x, maxi(box_a.end.x, box_b.end.x) + 24)
	var y0 := maxi(0, mini(box_a.position.y, box_b.position.y) - 16)
	var y1 := mini(SHOT.y, maxi(box_a.end.y, box_b.end.y) + 16)
	var cw := x1 - x0
	var ch := y1 - y0

	var head := 30
	var gap := 12
	var zh := ch * ZOOM
	var width: int = maxi(cw * ZOOM, 640)
	var out := Image.create(width, head + (ch + zh + head + gap * 2) * 2
			+ head, false, Image.FORMAT_RGB8)
	out.fill(Color(0.035, 0.035, 0.042))
	var gold := Color(1.0, 0.83, 0.36)
	var teal := Color(0.45, 0.72, 0.68)
	var pale := Color(0.72, 0.76, 0.80)

	var y := head
	for pair in [[a, RANK_A], [b, RANK_B]]:
		var src: Image = pair[0]
		var rank: Array = pair[1]
		var band := Image.create(cw, ch, false, Image.FORMAT_RGB8)
		band.blit_rect(src, Rect2i(x0, y0, cw, ch), Vector2i.ZERO)
		out.blit_rect(band, Rect2i(Vector2i.ZERO, Vector2i(cw, ch)),
				Vector2i((width - cw) / 2, y))
		y += ch + gap
		# Nearest-neighbour by hand: these are pixel renders, and a smooth
		# upscale would show shapes the game never draws.
		var ox := (width - cw * ZOOM) / 2
		for yy in zh:
			for xx in cw * ZOOM:
				out.set_pixel(ox + xx, y + yy, band.get_pixel(
						int(xx / float(ZOOM)), int(yy / float(ZOOM))))
		y += zh
		# Labels under the enlargement, placed by the SAME projection the
		# camera used rather than by even spacing -- the ranks are not
		# evenly spaced, and a label under the wrong figure is worse than
		# no label.
		for k in rank:
			var px := ox + (_screen_x(float(k[3])) - x0) * ZOOM
			var text := str(k[2])
			px = clampi(px - ArtBench.text_width(text) / 2, 2,
					width - ArtBench.text_width(text) - 2)
			ArtBench.label(out, text, Vector2i(px, y + 6), pale)
		y += head + gap

	ArtBench.label(out, "%s - TEN ROLES AT %d M. TRUE 1080P SCALE, THEN %dX"
			% [mode, int(AGGRO), ZOOM], Vector2i(12, 8), gold)
	ArtBench.label(out, "NO REVIEW STATUS IS PASS. THESE ARE PROPOSALS.",
			Vector2i(12, out.get_height() - 22), teal)
	return out

## Where a figure standing at world X lands, in viewport pixels.
##
## Godot keeps HEIGHT by default, so `fov` is the VERTICAL angle and the
## horizontal extent is that times the aspect. Getting this backwards is
## what put every label a third of a frame away from its figure.
func _screen_x(world_x: float) -> int:
	var half_m := AGGRO * tan(deg_to_rad(45.0)) * (float(SHOT.x) / SHOT.y)
	return int(SHOT.x * 0.5 * (1.0 - world_x / half_m))

## The bounding box of everything that is not the background, so the crop is
## aimed at measured content instead of at an assumption about the horizon.
func _content(img: Image, bg: Color) -> Rect2i:
	var x0 := img.get_width()
	var x1 := -1
	var y0 := img.get_height()
	var y1 := -1
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			if absf(c.r - bg.r) > 0.03 or absf(c.g - bg.g) > 0.03 \
					or absf(c.b - bg.b) > 0.03:
				x0 = mini(x0, xx); x1 = maxi(x1, xx)
				y0 = mini(y0, yy); y1 = maxi(y1, yy)
	if x1 < 0:
		return Rect2i(0, 0, img.get_width(), img.get_height())
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func _grab(vp: SubViewport) -> Image:
	for i in 4:
		await process_frame
	return vp.get_texture().get_image()
