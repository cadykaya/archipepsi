extends SceneTree
## Batch 030 -- the ten approved enemy roles, at their published envelopes.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s EnemyRoles.gd -- <assets_root> <out_dir>
##
## This batch is not a proposal in the way 023-029 were: `ENEMY_ENVELOPES`
## exists for all ten roles and Production builds the collider from the same
## numbers. So the evidence has to prove the thing that matters about it:
##
## A. THE LINE-UP. All ten together at player eye height with a 1.8 m rod,
##    because ten roles that are individually fine and collectively
##    indistinguishable is the actual risk in an enemy family.
## B. THE ENVELOPE. Each role inside its own declared box, drawn. If a model
##    pokes out of its collider the sheet says so, and flyers are shown at
##    their published `hover_height` rather than standing on the floor.

const MODELS := "batch030/enemies"
const ORDER := ["melee", "ranged", "brute", "charger", "bulwark",
		"scuttler", "artillery", "beacon", "diver", "drifter"]

var _assets := ""
var _out := ""
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: EnemyRoles.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var mf := FileAccess.open("%s/models/%s/manifest.json" % [_assets, MODELS],
			FileAccess.READ)
	if mf != null:
		_mf = JSON.parse_string(mf.get_as_text())
	await _lineup_sheet()
	await _envelope_sheet()
	print("[enemies030] 2 sheets -> %s" % _out)
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
			[Vector3(span, 7.0, 0.3), Vector3(0, 3.5, -3.4)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.20, 0.21, 0.23)
		mat.roughness = 0.93
		m.material_override = mat
		root.add_child(m)

## The declared collider, drawn as twelve thin edges. A translucent solid
## would hide the model inside it; edges say "this is the limit" and let the
## thing being tested stay visible.
func _envelope(root: Node3D, at: Vector3, w: float, h: float, dp: float,
		centre_y: float) -> void:
	var t := 0.018
	var c := Color(0.27, 0.84, 0.78)
	var hx: float = w * 0.5
	var hy: float = h * 0.5
	var hz: float = dp * 0.5
	var edges := [
		[Vector3(w, t, t), Vector3(0, -hy, -hz)], [Vector3(w, t, t), Vector3(0, -hy, hz)],
		[Vector3(w, t, t), Vector3(0, hy, -hz)], [Vector3(w, t, t), Vector3(0, hy, hz)],
		[Vector3(t, h, t), Vector3(-hx, 0, -hz)], [Vector3(t, h, t), Vector3(hx, 0, -hz)],
		[Vector3(t, h, t), Vector3(-hx, 0, hz)], [Vector3(t, h, t), Vector3(hx, 0, hz)],
		[Vector3(t, t, dp), Vector3(-hx, -hy, 0)], [Vector3(t, t, dp), Vector3(hx, -hy, 0)],
		[Vector3(t, t, dp), Vector3(-hx, hy, 0)], [Vector3(t, t, dp), Vector3(hx, hy, 0)],
	]
	for e in edges:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = e[0]
		m.mesh = b
		m.position = at + Vector3(0, centre_y, 0) + (e[1] as Vector3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		root.add_child(m)

func _shoot(size: Vector2i, eye: Vector3, look: Vector3, fov: float,
		build: Callable) -> Image:
	var vp := ArtBench.make_viewport(self, size, 0.24)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 0.72)
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

func _load(root: Node3D, role: String, at: Vector3) -> void:
	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/enemy_role_%s.glb" % [_assets, MODELS, role])
	if node == null:
		push_error("enemies030: missing %s" % role)
		return
	ArtBench.force_nearest(node)
	# A flyer's model is authored around its collider CENTRE, so it is lifted
	# to hover_height minus half its own height -- exactly what the contract
	# means by "the collider's centre above the floor".
	var e: Dictionary = _mf.get("enemy_role_%s" % role, {})
	var hover := float(e.get("hover_height_m", 0.0))
	var sz: Array = e.get("size", [1.0, 1.0, 1.0])
	var lift: float = 0.0 if hover == 0.0 else hover - float(sz[2]) * 0.5
	node.position = at + Vector3(0, lift, 0)
	root.add_child(node)

func _lineup_sheet() -> void:
	var cell := Vector2i(2040, 720)
	var sheet := Image.create(cell.x, cell.y + 116, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	var img: Image = await _shoot(cell, Vector3(0.4, 1.90, 11.4),
			Vector3(0.0, 1.15, 0.0), 44.0,
			func(root: Node3D) -> void:
				_ground(root, 40.0)
				var x := -8.1
				for role in ORDER:
					var e: Dictionary = _mf.get("enemy_role_%s" % role, {})
					var env: Array = e.get("envelope_w_h_d_m", [1, 1, 1])
					x += float(env[0]) * 0.5 + 0.42
					_load(root, role, Vector3(x, 0, 0))
					x += float(env[0]) * 0.5
				_rod(root, Vector3(x + 0.9, 0, 0)))
	if img != null:
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(0, 116))
	ArtBench.label(sheet, "A  THE TEN APPROVED ROLES, IN ORDER",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "MELEE  RANGED  BRUTE  CHARGER  BULWARK  SCUTTLER  "
			+ "ARTILLERY  BEACON  DIVER  DRIFTER. WHITE ROD IS 1.8 M.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "FLYERS SIT AT THEIR PUBLISHED HOVER_HEIGHT. TEN "
			+ "ROLES INDIVIDUALLY FINE AND COLLECTIVELY ALIKE IS THE REAL "
			+ "RISK -- THAT IS WHAT THIS VIEW TESTS.", Vector2i(12, 68),
			Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/A_enemy_lineup.png" % _out)

func _envelope_sheet() -> void:
	var cell := Vector2i(620, 560)
	var sheet := Image.create(cell.x * 5, cell.y * 2 + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in ORDER.size():
		var role: String = ORDER[i]
		var e: Dictionary = _mf.get("enemy_role_%s" % role, {})
		var env: Array = e.get("envelope_w_h_d_m", [1.0, 1.0, 1.0])
		var w := float(env[0])
		var h := float(env[1])
		var dp := float(env[2])
		var hover := float(e.get("hover_height_m", 0.0))
		var centre: float = hover if hover > 0.0 else h * 0.5
		var reach: float = maxf(maxf(w, dp), h) * 2.05 + 1.15
		var img: Image = await _shoot(cell,
				Vector3(reach * 0.56, centre + reach * 0.26, reach * 0.74),
				Vector3(0.0, centre, 0.0), 40.0,
				func(root: Node3D) -> void:
					_ground(root, 20.0)
					_load(root, role, Vector3.ZERO)
					_envelope(root, Vector3.ZERO, w, h, dp, centre))
		if img == null:
			continue
		var at := Vector2i((i % 5) * cell.x, 116 + int(i / 5) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, role.to_upper(), at + Vector2i(10, 10),
				Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, "%.2f x %.2f x %.2f M%s" % [w, h, dp,
				("  HOVER %.2f" % hover) if hover > 0.0 else ""],
				at + Vector2i(10, 32), Color(0.27, 0.84, 0.78))
		ArtBench.label(sheet, str(e.get("reads_as", "")),
				at + Vector2i(10, cell.y - 48), Color(0.72, 0.76, 0.80))
		var placeable: bool = bool(e.get("placeable_today", false))
		ArtBench.label(sheet, ("PLACEABLE TODAY" if placeable
				else "NO WAY TO SPAWN IT -- REQ 31"),
				at + Vector2i(10, cell.y - 24),
				Color(0.45, 0.72, 0.68) if placeable
				else Color(0.91, 0.33, 0.12))
	ArtBench.label(sheet, "B  EVERY MODEL INSIDE ITS DECLARED COLLIDER",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "THE CYAN BOX IS CONSTANTS.ENEMY_ENVELOPES, READ "
			+ "AND NEVER REDEFINED BY ART. THE BUILDER ASSERTS THE FIT.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "REQ 7 AND REQ 14 ARE RESOLVED. SEVEN OF THE TEN "
			+ "STILL HAVE NO WAY TO BE SPAWNED (REQ 31). NO ATTACK, AI, "
			+ "HEALTH OR TIMING IS INVENTED HERE.", Vector2i(12, 68),
			Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/B_enemy_envelopes.png" % _out)
