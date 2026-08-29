extends SceneTree
## Batch 023 -- PROPOSAL: theme landmark language, at player scale.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s Landmarks.gd -- <assets_root> <out_dir>
##
## The shot runner covers the silhouettes. This covers the three things it
## cannot: a 1.8 m human reference identical in all six panels, a room
## around each landmark so its relationship to ordinary architecture is
## visible, and one camera held constant so the six are comparable rather
## than six flattering angles.
##
## NOTHING HERE IS INTEGRATION-READY. The audit in build_landmarks.py found
## no landmark placement contract and no engine seam at all -- godot/scripts
## reads no .glb and no manifest. The footprints printed on each panel are
## MEASURED, not reserved: they say how big the proposal is, not what it is
## allowed to own. See interface requirement 24.

const MODELS := "batch023/landmarks"
const ORDER := ["lm_freight_shaft", "lm_pour_ladle", "lm_escalator_bank",
		"lm_bell_frame", "lm_stepped_cistern", "lm_unfinished_room"]

var _assets := ""
var _out := ""
var _dim := {}
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: Landmarks.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var f := FileAccess.open("%s/art_budgets.json" % _assets, FileAccess.READ)
	if f != null:
		_dim = JSON.parse_string(f.get_as_text()).get("dimensions", {})
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())

	await _sheet()
	print("[landmarks] 1 comparative sheet -> %s" % _out)
	quit()

func _num(key: String, fallback: float) -> float:
	return float(_dim.get(key, fallback))

func _slab(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	m.material_override = mat
	m.position = at
	root.add_child(m)

## The human reference, identical in every panel. 1.8 m, banded at the
## 1.6 m eye line, because "is this big" is a question about a person.
func _rod(root: Node3D, at: Vector3) -> void:
	var tall := _num("player_height", 1.8)
	_slab(root, Vector3(0.4, tall, 0.4), at + Vector3(0, tall * 0.5, 0),
			Color(0.88, 0.90, 0.94))
	var band := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.46, 0.05, 0.46)
	band.mesh = b
	band.material_override = ArtBench.flat_material(Color(0.22, 0.26, 0.32))
	band.position = at + Vector3(0, _num("player_eye_height", 1.6), 0)
	root.add_child(band)

## One panel: a landmark standing in ordinary room architecture, with the
## human reference beside it and the camera in the same place every time.
func _panel(name: String, size: Vector2i) -> Image:
	var entry: Dictionary = _mf.get(name, {})
	var vp := ArtBench.make_viewport(self, size, 0.17)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.15)

	# Ordinary architecture, identical in all six: a floor, a back wall and
	# two returns. The point of the panel is the landmark's RELATIONSHIP to
	# plain building, so the plain building has to be in frame.
	# The floor, built AROUND the landmark's footprint when the landmark is
	# a hole. The first sheet laid one 30 m slab over everything and the
	# cistern -- the only proposal whose whole idea is that it descends --
	# rendered as a flat frame lying on a floor, its four terraces sealed
	# underneath. A void needs the ground opened for it or it is not a void.
	var cut: float = float(_mf.get(name, {}).get("cuts_floor", 0.0))
	if cut > 0.0:
		var arm := (30.0 - cut) / 2.0
		for sx in [-1.0, 1.0]:
			_slab(root, Vector3(arm, 0.3, 30),
					Vector3(sx * (cut + arm) / 2.0, -0.15, 1.0),
					Color(0.34, 0.35, 0.38))
			_slab(root, Vector3(cut, 0.3, arm),
					Vector3(0, -0.15, 1.0 + sx * (cut + arm) / 2.0),
					Color(0.34, 0.35, 0.38))
	else:
		_slab(root, Vector3(30, 0.3, 30), Vector3(0, -0.15, 0),
				Color(0.34, 0.35, 0.38))
	_slab(root, Vector3(30, 9, 0.4), Vector3(0, 4.5, 11.0), Color(0.44, 0.45, 0.48))
	for side in [-1.0, 1.0]:
		_slab(root, Vector3(0.4, 9, 22), Vector3(side * 11.0, 4.5, 0.5),
				Color(0.40, 0.41, 0.44))
	# A 3.6 m corridor-height datum on the back wall, so the landmark's
	# height is read against the building rather than against nothing.
	_slab(root, Vector3(30, 0.08, 0.1),
			Vector3(0, _num("corridor_height", 3.6), 10.78),
			Color(0.56, 0.58, 0.62))

	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if node == null:
		push_error("Landmarks: missing %s" % name)
		vp.queue_free()
		return null
	ArtBench.force_nearest(node)
	root.add_child(node)
	node.position = Vector3(0, 0, 1.0)

	_rod(root, Vector3(-4.6, 0, -3.4))

	var cam := Camera3D.new()
	cam.fov = _num("camera_fov_deg", 90.0) * 0.62
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(-6.4, 2.9, -13.5),
			Vector3(0.2, 3.1, 1.2), Vector3.UP)

	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)

	var sz: Array = entry.get("size", [0, 0, 0])
	ArtBench.label(img, name.to_upper().replace("LM_", ""),
			Vector2i(10, 10), Color(1.0, 0.86, 0.42))
	ArtBench.label(img, str(entry.get("theme", "")).to_upper(),
			Vector2i(10, 32), Color(0.72, 0.76, 0.80))
	ArtBench.label(img, str(entry.get("spatial_job", "")).to_upper(),
			Vector2i(10, 54), Color(0.45, 0.72, 0.68))
	ArtBench.label(img, "MEASURED %.1f x %.1f x %.1f M - NOT A RESERVED FOOTPRINT"
			% [float(sz[0]), float(sz[1]), float(sz[2])],
			Vector2i(10, img.get_height() - 24), Color(0.62, 0.66, 0.70))
	vp.queue_free()
	await process_frame
	return img

func _sheet() -> void:
	var cell := Vector2i(720, 470)
	var sheet := Image.create(cell.x * 3, cell.y * 2 + 104, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in ORDER.size():
		var img: Image = await _panel(ORDER[i], cell)
		if img == null:
			return
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell),
				Vector2i((i % 3) * cell.x, 104 + int(i / 3) * cell.y))
	ArtBench.label(sheet, "BATCH 023 PROPOSAL - THEME LANDMARK LANGUAGE, AT PLAYER SCALE",
			Vector2i(12, 16), Color(1.0, 0.83, 0.36))
	ArtBench.label(sheet, "SAME CAMERA, SAME ROOM, SAME 1.8 M HUMAN REFERENCE IN EVERY PANEL. PALE LINE ON THE BACK WALL IS CORRIDOR_HEIGHT 3.6 M.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "NO PLACEMENT CONTRACT EXISTS - godot/scripts READS NO .glb AND NO MANIFEST. NOTHING HERE IS INTEGRATION-READY. SEE INTERFACE REQ 24.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/A_landmarks_player_scale.png" % _out)
