extends SceneTree
## Batch 026 -- PROPOSAL: the checkpoint / re-entry station.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s Checkpoint.gd -- <assets_root> <out_dir>
##
## Two claims, and the second is the one that matters:
##
## A. THE THREE STATES READ FROM POSTURE. Same camera, same distance. If
##    folded / raised / raised-with-canopy are not three different shapes at
##    a glance, the whole approach fails and no surface detail will save it.
##
## B. IT SURVIVES BEING NEXT TO THE THINGS IT MUST NOT BE CONFUSED WITH.
##    The brief names Check cyan, Epsilon green and hazard orange. Sheet B
##    stands the station beside all three, and then repeats the row in GREY
##    SCALE -- because a language that only works in colour is not a language
##    that works for a player who cannot separate those hues.

const MODELS := "batch026/checkpoint"
const STATES := ["inactive", "activated", "anchor"]

var _assets := ""
var _out := ""
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: Checkpoint.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())
	await _state_sheet()
	await _neighbour_sheet()
	print("[checkpoint026] 2 sheets -> %s" % _out)
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

func _ground(root: Node3D, tint: Color) -> void:
	for spec in [[Vector3(20, 0.3, 20), Vector3(0, -0.15, 0)],
			[Vector3(20, 5.0, 0.3), Vector3(0, 2.5, -3.4)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.92
		m.material_override = mat
		root.add_child(m)

## A stand-in for one of the three families the station must not be confused
## with. Deliberately crude: the question is whether the CHANNEL collides,
## and a lit box in the right hue answers that as well as a finished asset.
func _neighbour(root: Node3D, at: Vector3, colour: Color, tall: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, tall, 0.5)
	m.mesh = b
	m.position = at + Vector3(0, tall * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour * 0.35
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 0.9
	m.material_override = mat
	root.add_child(m)

func _greyscale(img: Image) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false,
			Image.FORMAT_RGB8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			# Rec. 709 luma, which is what a value comparison has to use.
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			out.set_pixel(x, y, Color(l, l, l))
	return out

func _shoot(size: Vector2i, eye: Vector3, look: Vector3, fov: float,
		build: Callable) -> Image:
	var vp := ArtBench.make_viewport(self, size, 0.16)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 0.62)
	build.call(root)
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

func _load(root: Node3D, name: String, at: Vector3) -> void:
	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if node == null:
		push_error("checkpoint026: missing %s" % name)
		return
	ArtBench.force_nearest(node)
	node.position = at
	root.add_child(node)

func _state_sheet() -> void:
	# 700 x 640 -> aspect 1.09; 40 deg vertical is ~43 deg horizontal. The
	# station is 2.5 m wide and 3.1 m tall, so height is the binding
	# dimension: 3.9 / (2 * tan 20) = 5.36 m of standoff.
	var cell := Vector2i(700, 640)
	var sheet := Image.create(cell.x * 3, cell.y + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in STATES.size():
		var state: String = STATES[i]
		var name := "checkpoint_%s" % state
		var img: Image = await _shoot(cell, Vector3(3.30, 2.30, 4.05),
				Vector3(0.0, 1.25, 0.0), 40.0,
				func(root: Node3D) -> void:
					_ground(root, Color(0.20, 0.21, 0.23))
					_load(root, name, Vector3.ZERO)
					_rod(root, Vector3(-1.95, 0.0, 0.60)))
		if img == null:
			continue
		var at := Vector2i(i * cell.x, 116)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		var e: Dictionary = _mf.get(name, {})
		ArtBench.label(sheet, state.to_upper(), at + Vector2i(10, 10),
				Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(e.get("means", "")),
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
		ArtBench.label(sheet, "EMITS: %s" % (
				"ONE ACHROMATIC LAMP" if bool(e.get("emits", false))
				else "NOTHING"),
				at + Vector2i(10, cell.y - 30), Color(0.60, 0.64, 0.68))
	ArtBench.label(sheet, "A  THE RE-ENTRY STATION, IN THREE STATES",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "READ BY POSTURE FIRST, THEN VALUE. NEVER BY HUE. "
			+ "IDENTICAL CAMERA. WHITE ROD IS 1.8 M.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "PROPOSAL. NO CHECKPOINT ENTITY OR STATE EXISTS "
			+ "IN PRODUCTION (REQ 27). NO SPAWN, HEALING, TRAVEL OR SAVE "
			+ "RULE IS DECIDED HERE.", Vector2i(12, 68),
			Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/A_checkpoint_states.png" % _out)

func _neighbour_sheet() -> void:
	var cell := Vector2i(1180, 560)
	var sheet := Image.create(cell.x, cell.y * 2 + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	var lit: Image = await _shoot(cell, Vector3(1.10, 2.60, 7.40),
			Vector3(0.30, 1.10, 0.0), 42.0,
			func(root: Node3D) -> void:
				_ground(root, Color(0.20, 0.21, 0.23))
				_load(root, "checkpoint_anchor", Vector3(-2.60, 0, 0))
				# The three the brief says it must not be confused with.
				_neighbour(root, Vector3(-0.30, 0, 0),
						Color(0.27, 0.84, 0.78), 1.5)   # signal / Check cyan
				_neighbour(root, Vector3(1.30, 0, 0),
						Color(0.34, 1.00, 0.12), 1.5)   # Epsilon green
				_neighbour(root, Vector3(2.90, 0, 0),
						Color(0.91, 0.33, 0.12), 1.5)   # hazard orange
				_rod(root, Vector3(4.55, 0.0, 0.0)))
	if lit != null:
		sheet.blit_rect(lit, Rect2i(Vector2i.ZERO, cell), Vector2i(0, 116))
		sheet.blit_rect(_greyscale(lit), Rect2i(Vector2i.ZERO, cell),
				Vector2i(0, 116 + cell.y))
	ArtBench.label(sheet, "B  BESIDE THE THREE IT MUST NOT BE CONFUSED WITH",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "LEFT TO RIGHT: THE STATION, CHECK CYAN, "
			+ "EPSILON GREEN, HAZARD ORANGE. WHITE ROD IS 1.8 M.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "THE LOWER ROW IS THE SAME FRAME IN LUMA. A "
			+ "LANGUAGE THAT ONLY WORKS IN COLOUR IS NOT A LANGUAGE.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	ArtBench.label(sheet, "AS RENDERED", Vector2i(12, 126),
			Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "REC. 709 LUMA", Vector2i(12, 126 + cell.y),
			Color(0.72, 0.76, 0.80))
	sheet.save_png("%s/B_checkpoint_neighbours.png" % _out)
