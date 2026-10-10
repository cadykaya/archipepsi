extends SceneTree
## Batch 025 -- PROPOSAL: the Forge, and Questionable Goods.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s Forge.gd -- <assets_root> <out_dir>
##
## Two claims to prove:
##
## A. THE FORGE READS AS A PROCESS. Four stations in a line, in order, with
##    the third one EMPTY. The sheet has to show that the gap is deliberate
##    geometry and not a modelling failure, so one panel is a detail of it.
##
## B. THE FORGE AND QUESTIONABLE GOODS ARE DIFFERENT KINDS OF OBJECT, not
##    two dressings of one. Same camera, same distance, same rod: if the
##    apparatus/counter distinction needs a caption, it does not work.
##
## Cameras are SOLVED from the panel aspect and the subject width rather
## than nudged -- see Batch 024, where three render passes went into moving
## a camera that was never the actual problem.

const MODELS := "batch025/forge"

var _assets := ""
var _out := ""
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: Forge.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())

	await _forge_sheet()
	await _kind_sheet()
	print("[forge025] 2 sheets -> %s" % _out)
	quit()

func _rod(root: Node3D, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.42, 1.8, 0.42)
	m.mesh = b
	m.position = at + Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.83, 0.88)
	m.material_override = mat
	root.add_child(m)

func _ground(root: Node3D, span: float) -> void:
	for spec in [[Vector3(span, 0.3, span), Vector3(0, -0.15, 0)],
			[Vector3(span, 5.0, 0.3), Vector3(0, 2.5, -2.6)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.19, 0.20, 0.22)
		mat.roughness = 0.95
		m.material_override = mat
		root.add_child(m)

func _panel(name: String, size: Vector2i, eye: Vector3, look: Vector3,
		fov: float, rod_at: Vector3, key: float, ambient: float) -> Image:
	var vp := ArtBench.make_viewport(self, size, ambient)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, key)
	_ground(root, 16.0)

	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if node == null:
		push_error("forge025: missing %s" % name)
		vp.queue_free()
		return null
	ArtBench.force_nearest(node)
	root.add_child(node)
	if rod_at != Vector3.INF:
		_rod(root, rod_at)

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = fov
	vp.add_child(cam)
	cam.look_at_from_position(eye, look, Vector3.UP)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	await process_frame
	return img

func _forge_sheet() -> void:
	# 760 x 520 -> aspect 1.46. At 40 deg vertical that is ~56 deg
	# horizontal, so covering the 3.9 m bench plus margin (4.4 m) wants
	# 2.2 / tan(28 deg) = 4.14 m of standoff.
	var cell := Vector2i(760, 520)
	var sheet := Image.create(cell.x * 2, cell.y * 2 + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))

	# The operator side is Blender -Y, which is Godot +Z.
	var wide_eye := Vector3(1.10, 2.05, 4.15)
	var wide_look := Vector3(0.0, 1.00, 0.0)

	var shots := [
		["forge_bench", wide_eye, wide_look, 40.0, Vector3(-1.70, 0.0, 1.10),
			"IDLE", "FOUR STATIONS, LEFT TO RIGHT"],
		["forge_bench_working", wide_eye, wide_look, 40.0,
			Vector3(-1.70, 0.0, 1.10), "WORKING",
			"AN OBJECT IS IN DESTABILISATION; THE DIAL IS SET"],
		["forge_bench_working", Vector3(1.48, 1.72, 1.30),
			Vector3(0.45, 0.88, 0.0), 40.0, Vector3.INF,
			"STATION 3  REINTERPRETATION",
			"THE BENCH TOP IS ABSENT HERE. THAT IS BUILT, NOT PAINTED."],
		["forge_bench_working", Vector3(-0.72, 1.58, 1.36),
			Vector3(-1.25, 1.02, 0.50), 38.0, Vector3.INF,
			"THE SELECTOR",
			"ONE SEVEN-POSITION DIAL, ONE POINTER, ONE COIN SOCKET"],
	]
	for i in shots.size():
		var s: Array = shots[i]
		var img: Image = await _panel(s[0], cell, s[1], s[2], s[3], s[4],
				0.60, 0.20)
		if img == null:
			continue
		var at := Vector2i((i % 2) * cell.x, 116 + int(i / 2) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, str(s[5]), at + Vector2i(10, 10),
				Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(s[6]), at + Vector2i(10, 32),
				Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "A  THE FORGE", Vector2i(12, 16),
			Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "ANALYSIS  DESTABILISATION  REINTERPRETATION  "
			+ "RECONSTRUCTION -- IN THAT ORDER, ALONG THE BENCH. "
			+ "WHITE ROD IS 1.8 M.", Vector2i(12, 42),
			Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "PROPOSAL. NO FORGE ANCHOR EXISTS IN PRODUCTION "
			+ "(REQ 26). PHYSICAL IDENTITY ONLY -- NO MECHANIC IS "
			+ "DESIGNED HERE.", Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/A_forge.png" % _out)

func _kind_sheet() -> void:
	# Identical camera and rod for both. The claim is that they read as
	# different KINDS of object, and a comparison that reframes between
	# panels cannot show that.
	var cell := Vector2i(820, 620)
	var sheet := Image.create(cell.x * 2, cell.y + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	var eye := Vector3(2.95, 2.05, 4.15)
	var look := Vector3(0.0, 1.05, 0.0)
	var pairs := [
		["forge_bench_working", "THE FORGE", "PROCESS MADE VISIBLE",
			"AN APPARATUS. ALL FOUR STAGES EXPOSED, IN ORDER."],
		["qg_counter", "QUESTIONABLE GOODS", "TRANSACTION MADE OPAQUE",
			"A COUNTER. SHUTTER HALF DOWN, STOCK BEHIND MESH, ONE HATCH."],
	]
	for i in pairs.size():
		var p: Array = pairs[i]
		var img: Image = await _panel(p[0], cell, eye, look, 42.0,
				Vector3(-1.85, 0.0, 1.25), 0.60, 0.18)
		if img == null:
			continue
		var at := Vector2i(i * cell.x, 116)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, str(p[1]), at + Vector2i(10, 10),
				Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(p[2]), at + Vector2i(10, 32),
				Color(0.45, 0.72, 0.68))
		ArtBench.label(sheet, str(p[3]), at + Vector2i(10, 54),
				Color(0.72, 0.76, 0.80))
		var e: Dictionary = _mf.get(str(p[0]), {})
		var anchor: Variant = e.get("hub_anchor")
		ArtBench.label(sheet, "HUB ANCHOR: %s" % (
				"NONE -- REQ 26" if anchor == null else str(anchor).to_upper()),
				at + Vector2i(10, cell.y - 30),
				Color(0.91, 0.33, 0.12) if anchor == null
				else Color(0.45, 0.72, 0.68))
	ArtBench.label(sheet, "B  TWO SERVICES, TWO KINDS OF OBJECT",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "IDENTICAL CAMERA, DISTANCE AND ROD. IF THE "
			+ "DISTINCTION NEEDS THE CAPTION, IT DOES NOT WORK.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "QUESTIONABLE GOODS STANDS ON A REAL HUB ANCHOR "
			+ "AND CLEARS THE LAB DOORWAY BY 0.6 M. THE FORGE HAS NO "
			+ "ANCHOR AT ALL.", Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/B_forge_vs_shop.png" % _out)
