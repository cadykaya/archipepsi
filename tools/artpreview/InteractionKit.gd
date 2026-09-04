extends SceneTree
## Batch 028 -- PROPOSAL: the interaction primitive kit.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s InteractionKit.gd -- <assets_root> <out_dir>
##
## The claim is a GRAMMAR, not nine objects, so the sheet has to test the
## grammar:
##
## A. nine primitives, one per panel, each captioned with the verb its shape
##    is supposed to say. The reader should be able to cover the caption and
##    still get the verb.
## B. the whole kit in one frame at eye height, which is the only view that
##    shows whether the shared state plate reads as ONE thing across nine
##    unrelated objects -- and whether nine silhouettes in a row stay
##    distinct.

const MODELS := "batch028/interaction"
const ORDER := ["int_carryable", "int_weight_button", "int_wall_switch",
		"int_door_mechanism", "int_logic_indicator", "int_launcher",
		"int_breakable", "int_key_receiver", "int_machinery"]

var _assets := ""
var _out := ""
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: InteractionKit.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())
	await _grid_sheet()
	await _line_sheet()
	print("[interaction028] 2 sheets -> %s" % _out)
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
			[Vector3(span, 4.0, 0.3), Vector3(0, 2.0, -2.0)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.21, 0.22, 0.24)
		mat.roughness = 0.93
		m.material_override = mat
		root.add_child(m)

func _shoot(size: Vector2i, eye: Vector3, look: Vector3, fov: float,
		build: Callable) -> Image:
	var vp := ArtBench.make_viewport(self, size, 0.22)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 0.68)
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
		push_error("interaction028: missing %s" % name)
		return
	ArtBench.force_nearest(node)
	node.position = at
	root.add_child(node)

func _grid_sheet() -> void:
	var cell := Vector2i(620, 520)
	var sheet := Image.create(cell.x * 3, cell.y * 3 + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in ORDER.size():
		var name: String = ORDER[i]
		var e: Dictionary = _mf.get(name, {})
		var sz: Array = e.get("size", [1.0, 1.0, 1.0])
		# Framed from the asset's own extents, so a 2.3 m door mechanism and
		# a 0.23 m floor pad are both shot at a useful size instead of one
		# camera being wrong for both.
		var tall := float(sz[2])
		var wide: float = maxf(float(sz[0]), float(sz[1]))
		var reach: float = maxf(tall, wide) * 1.5 + 0.9
		var img: Image = await _shoot(cell,
				Vector3(reach * 0.62, tall * 0.72 + 0.55, reach * 0.80),
				Vector3(0.0, tall * 0.45, 0.0), 42.0,
				func(root: Node3D) -> void:
					_ground(root, 12.0)
					_load(root, name, Vector3.ZERO))
		if img == null:
			continue
		var at := Vector2i((i % 3) * cell.x, 116 + int(i / 3) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, str(e.get("verb_the_shape_says", "")),
				at + Vector2i(10, 10), Color(0.22, 0.84, 0.78))
		ArtBench.label(sheet, str(e.get("represents", "")).to_upper(),
				at + Vector2i(10, 32), Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(e.get("affordance", "")),
				at + Vector2i(10, cell.y - 26), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "A  NINE PRIMITIVES, NINE VERBS",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "COVER THE CAPTION. THE SHAPE SHOULD STILL SAY "
			+ "THE VERB -- THAT IS THE WHOLE TEST OF AN AFFORDANCE.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "PROPOSAL. INTERACTABLECONTRACT.STATES IS THE AP "
			+ "CHECK'S VOCABULARY AND FITS NONE OF THESE (REQ 29). "
			+ "MECHANICS ARE PRODUCTION'S.", Vector2i(12, 68),
			Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/A_interaction_kit.png" % _out)

func _line_sheet() -> void:
	var cell := Vector2i(2040, 660)
	var sheet := Image.create(cell.x, cell.y + 116, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	var img: Image = await _shoot(cell, Vector3(0.0, 1.60, 8.60),
			Vector3(0.0, 0.85, 0.0), 46.0,
			func(root: Node3D) -> void:
				_ground(root, 30.0)
				for i in ORDER.size():
					_load(root, ORDER[i],
							Vector3(-6.4 + i * 1.6, 0, 0))
				_rod(root, Vector3(8.0, 0.0, 0.0)))
	if img != null:
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(0, 116))
	ArtBench.label(sheet, "B  THE WHOLE KIT, AT EYE HEIGHT",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "THE CLAIM IS A GRAMMAR: ONE STATE PLATE, IN "
			+ "SIGNAL CYAN, IN THE SAME RELATION TO EACH OBJECT'S OWN "
			+ "AFFORDANCE. LEARN IT ONCE.", Vector2i(12, 42),
			Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "NINE UNRELATED SILHOUETTES, ONE SHARED ANSWER "
			+ "TO 'WHAT IS THIS DOING RIGHT NOW'. WHITE ROD IS 1.8 M.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/B_interaction_grammar.png" % _out)
