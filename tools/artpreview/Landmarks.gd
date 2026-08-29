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
const ORDER := ["lm_drop_test_hall", "lm_process_tower",
		"lm_stacked_interchange", "lm_bell_breach",
		"lm_collapsed_ziggurat", "lm_reentrant_room"]

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

	await _sheet(true, "A", "SIX PLACES AT PLAYER SCALE",
			"THE GAME'S OWN 90 FOV FROM A 1.6 M EYE, STANDING INSIDE EACH PLACE. WHITE ROD IS 1.8 M.")
	await _sheet(false, "B", "THE SAME SIX, AT DISTANCE",
			"FAR ENOUGH THAT EACH IS A SHAPE. A LANDMARK IS WHAT YOU RECOGNISE BEFORE YOU CAN READ ITS MATERIAL.")
	print("[landmarks] 2 comparative sheets -> %s" % _out)
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

## One panel: a place, framed from its own manifest.
##
## These landmarks supply their own architecture, so the bench room recedes
## to a ground plane and a far backdrop. Framing is solved per landmark from
## its recorded extents rather than fixed, because a 25 m ziggurat and a
## 13 m tower do not share a camera -- and a comparative sheet whose panels
## are cropped differently is not comparative.
func _panel(name: String, size: Vector2i, eye_level: bool) -> Image:
	var e: Dictionary = _mf.get(name, {})
	var sz: Array = e.get("size", [12, 12, 12])
	var down := float(e.get("descends_to_m", 0.0))
	var up := float(e.get("rises_to_m", 10.0))
	var w: float = maxf(float(sz[0]), float(sz[1]))

	# Interiors swallow a rig meant for an object on a backdrop, so the
	# inside views get more ambient and a stronger key. The long views keep
	# the standard rig, because there the place is a silhouette.
	var vp := ArtBench.make_viewport(self, size,
			0.34 if eye_level else 0.17)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.6 if eye_level else 1.15)

	# Ground, opened where the place descends below it. Four slabs round the
	# footprint, so a hall with a 7 m shaft in it is not sealed under the
	# bench floor -- the mistake that hid an entire concept last pass.
	var pad := 60.0
	if down < -0.6:
		var arm := (pad - w) / 2.0
		for sx in [-1.0, 1.0]:
			_slab(root, Vector3(arm, 0.3, pad),
					Vector3(sx * (w + arm) / 2.0, -0.15, 0),
					Color(0.32, 0.33, 0.36))
			_slab(root, Vector3(w, 0.3, arm),
					Vector3(0, -0.15, sx * (w + arm) / 2.0),
					Color(0.32, 0.33, 0.36))
	else:
		_slab(root, Vector3(pad, 0.3, pad), Vector3(0, -0.15, 0),
				Color(0.32, 0.33, 0.36))
	# A far wall carrying the corridor-height datum, so scale is read
	# against the building the game already has.
	_slab(root, Vector3(pad, 26, 0.5), Vector3(0, 13, w * 0.5 + 13.0),
			Color(0.40, 0.41, 0.45))
	_slab(root, Vector3(pad, 0.10, 0.14),
			Vector3(0, _num("corridor_height", 3.6), w * 0.5 + 12.7),
			Color(0.58, 0.60, 0.64))

	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if node == null:
		push_error("Landmarks: missing %s" % name)
		vp.queue_free()
		return null
	ArtBench.force_nearest(node)
	root.add_child(node)

	# The human reference, on the ground at the near corner of the footprint.
	# The human reference stands just inside the frame of the interior view,
	# where it is actually comparable to the architecture around it.
	if eye_level and e.has("eye_from") and e.has("eye_at"):
		# Four metres along the view direction, stepped to one side, so the
		# reference is IN the shot. Offsetting from the camera blindly put
		# it behind the camera in most panels.
		var ef: Array = e["eye_from"]
		var ea: Array = e["eye_at"]
		var from := Vector3(float(ef[0]), 0, float(ef[2]))
		var to := Vector3(float(ea[0]), 0, float(ea[2]))
		var dir := (to - from).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		_rod(root, from + dir * 4.5 + side * 2.4)
	else:
		_rod(root, Vector3(-w * 0.5 - 1.6, 0, -w * 0.5 - 1.2))

	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	var mid := (up + down) * 0.5
	if eye_level:
		# What a player sees, at the game's own lens, standing INSIDE the
		# place. The viewpoint comes from the manifest: the builder knows
		# where the hero feature is, and the first sheet -- shot from
		# outside -- rendered six interiors as boxes with a wall facing
		# camera, with the actual place hidden behind it.
		cam.fov = _num("camera_fov_deg", 90.0)
		var f: Array = e.get("eye_from", [])
		var a: Array = e.get("eye_at", [])
		if f.size() == 3 and a.size() == 3:
			cam.look_at_from_position(
					Vector3(float(f[0]), float(f[1]), float(f[2])),
					Vector3(float(a[0]), float(a[1]), float(a[2])),
					Vector3.UP)
		else:
			var back: float = w * 0.62 + 6.0
			cam.look_at_from_position(
					Vector3(-back * 0.72, _num("player_eye_height", 1.6), -back),
					Vector3(0, mid * 0.55, 0), Vector3.UP)
	else:
		# The long read: far enough that the whole place is a shape.
		cam.fov = 46.0
		var far: float = maxf(w, up - down) * 1.5 + 10.0
		cam.look_at_from_position(Vector3(-far * 0.66, up * 0.78, -far * 0.82),
				Vector3(0, mid, 0), Vector3.UP)

	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	await process_frame
	return img

func _sheet(eye_level: bool, letter: String, title: String,
		sub: String) -> void:
	var cell := Vector2i(720, 480)
	var sheet := Image.create(cell.x * 3, cell.y * 2 + 104, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in ORDER.size():
		var name: String = ORDER[i]
		var img: Image = await _panel(name, cell, eye_level)
		if img == null:
			return
		var at := Vector2i((i % 3) * cell.x, 104 + int(i / 3) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		var e: Dictionary = _mf.get(name, {})
		var sz: Array = e.get("size", [0, 0, 0])
		ArtBench.label(sheet, name.to_upper().replace("LM_", ""),
				at + Vector2i(10, 10), Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(e.get("theme", "")).to_upper(),
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
		ArtBench.label(sheet, str(e.get("spatial_job", "")).to_upper(),
				at + Vector2i(10, 54), Color(0.45, 0.72, 0.68))
		ArtBench.label(sheet, "%.0f x %.0f M, %.1f M TALL - PROPOSAL SCALE"
				% [float(sz[0]), float(sz[1]), float(sz[2])],
				at + Vector2i(10, cell.y - 22), Color(0.60, 0.64, 0.68))
	ArtBench.label(sheet, "%s  %s" % [letter, title], Vector2i(12, 16),
			Color(1.0, 0.83, 0.36))
	ArtBench.label(sheet, sub, Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "PROPOSAL SCALE, NOT RUNTIME TRUTH - NO LANDMARK PLACEMENT CONTRACT EXISTS. godot/scripts READS NO .glb AND NO MANIFEST. INTERFACE REQ 24.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/%s_landmarks_%s.png"
			% [_out, letter, "eye" if eye_level else "long"])
