extends SceneTree
## Batch 027 -- PROPOSAL: pickups, loot and resource readability.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s Pickups.gd -- <assets_root> <out_dir>
##
## The claim is that five pickups are identified by SILHOUETTE, because two
## of them are allowed no hue at all. So the load-bearing sheet is B, not A:
##
## A. the five at hand distance, lit, so the surfaces can be judged
## B. the same five at 12 m, the distance a player actually first sees one
##    from -- AND as flat black silhouettes on a light ground, which is the
##    only honest test of a shape claim
##
## If a pickup is not identifiable in row B it does not work, however well
## it photographs in row A.

const MODELS := "batch027/pickups"
const ORDER := ["pickup_coin", "pickup_health", "pickup_resource",
		"pickup_special", "pickup_cache"]

var _assets := ""
var _out := ""
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: Pickups.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())
	await _close_sheet()
	await _silhouette_sheet()
	print("[pickups027] 2 sheets -> %s" % _out)
	quit()

func _ground(root: Node3D, tint: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(24, 0.3, 24)
	m.mesh = b
	m.position = Vector3(0, -0.15, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.94
	m.material_override = mat
	root.add_child(m)

func _shoot(size: Vector2i, eye: Vector3, look: Vector3, fov: float,
		ambient: float, key: float, build: Callable) -> Image:
	var vp := ArtBench.make_viewport(self, size, ambient)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, key)
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

func _load(root: Node3D, name: String, at: Vector3, flat: bool) -> Node3D:
	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if node == null:
		push_error("pickups027: missing %s" % name)
		return null
	ArtBench.force_nearest(node)
	node.position = at
	if flat:
		_blacken(node)
	root.add_child(node)
	return node

## Flat black, unlit. A silhouette test that leaves any shading in it is a
## test of the lighting, not of the shape.
func _blacken(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.03, 0.035, 0.045)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_blacken(child)

func _close_sheet() -> void:
	var cell := Vector2i(560, 520)
	var sheet := Image.create(cell.x * 5, cell.y + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in ORDER.size():
		var name: String = ORDER[i]
		# 1.4 m out, a bit above: the distance you look at one from when
		# you are standing over it deciding whether to take it.
		var img: Image = await _shoot(cell, Vector3(0.72, 0.78, 1.02),
				Vector3(0.0, 0.24, 0.0), 42.0, 0.24, 0.75,
				func(root: Node3D) -> void:
					_ground(root, Color(0.21, 0.22, 0.24))
					_load(root, name, Vector3.ZERO, false))
		if img == null:
			continue
		var at := Vector2i(i * cell.x, 116)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		var e: Dictionary = _mf.get(name, {})
		ArtBench.label(sheet, str(e.get("represents", "")).to_upper(),
				at + Vector2i(10, 10), Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(e.get("silhouette", "")),
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
		ArtBench.label(sheet, "PALETTE: %s" % str(e.get("palette_family", "")),
				at + Vector2i(10, cell.y - 52), Color(0.60, 0.64, 0.68))
		var real: bool = bool(e.get("backed_by_production_item", false))
		ArtBench.label(sheet, ("BACKED BY A REAL ITEM" if real
				else "NO ITEM EXISTS -- REQ 28"),
				at + Vector2i(10, cell.y - 28),
				Color(0.45, 0.72, 0.68) if real else Color(0.91, 0.33, 0.12))
	ArtBench.label(sheet, "A  FIVE PICKUPS, AT HAND DISTANCE",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "EVERY ONE SITS ON THE SAME MAT -- LEARNED ONCE, "
			+ "IT MEANS 'YOU CAN TAKE THIS'. THE OBJECT ABOVE IT IS FREE "
			+ "TO BE ONLY ABOUT WHICH THING.", Vector2i(12, 42),
			Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "PROPOSAL. NO RESOURCE MECHANIC OR DENOMINATION "
			+ "IS DECIDED. HEALTH AND AMMO HAVE NO ITEM IN PRODUCTION AT "
			+ "ALL.", Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/A_pickups.png" % _out)

func _silhouette_sheet() -> void:
	var cell := Vector2i(560, 420)
	var sheet := Image.create(cell.x * 5, cell.y * 2 + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in ORDER.size():
		var name: String = ORDER[i]
		# 12 m: about where a player first sees a pickup across a room.
		var far: Image = await _shoot(cell, Vector3(7.4, 4.3, 8.6),
				Vector3(0.0, 0.20, 0.0), 12.0, 0.22, 0.70,
				func(root: Node3D) -> void:
					_ground(root, Color(0.21, 0.22, 0.24))
					_load(root, name, Vector3.ZERO, false))
		var sil: Image = await _shoot(cell, Vector3(0.0, 0.30, 1.95),
				Vector3(0.0, 0.26, 0.0), 34.0, 1.0, 0.0,
				func(root: Node3D) -> void:
					_ground(root, Color(0.86, 0.87, 0.89))
					_load(root, name, Vector3.ZERO, true))
		var at := Vector2i(i * cell.x, 116)
		if far != null:
			sheet.blit_rect(far, Rect2i(Vector2i.ZERO, cell), at)
		if sil != null:
			sheet.blit_rect(sil, Rect2i(Vector2i.ZERO, cell),
					at + Vector2i(0, cell.y))
		var e: Dictionary = _mf.get(name, {})
		ArtBench.label(sheet, str(e.get("represents", "")).to_upper(),
				at + Vector2i(10, 10), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "B  THE TEST THAT MATTERS", Vector2i(12, 16),
			Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "TOP: AT 12 M, WHERE YOU FIRST SEE ONE. "
			+ "BOTTOM: FLAT BLACK, UNLIT, SIDE ON.", Vector2i(12, 42),
			Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "TWO OF THE FIVE ARE ALLOWED NO HUE AT ALL, SO "
			+ "SHAPE IS NOT A NICETY HERE -- IT IS THE WHOLE CHANNEL.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/B_pickup_silhouettes.png" % _out)
