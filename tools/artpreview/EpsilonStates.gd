extends SceneTree
## Batch 024 -- PROPOSAL: Epsilon presentation states and the presentation arc.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s EpsilonStates.gd -- <assets_root> <out_dir>
##
## Two things this has to prove, and the rig is built for them rather than
## for looking good:
##
## A. THE SIX STATES ARE TELLABLE APART WITHOUT A SECOND COLOUR. All six are
##    `identity` green and nothing else, so the sheet has to show that value,
##    aperture, extent and orientation carry the difference. The camera is
##    IDENTICAL in all six panels and the geometry is identical except for
##    the intrusion -- if a state only reads because its panel was framed
##    more flatteringly, the language does not work.
##
## B. THE ARC IS EXTENT, NOT BRIGHTNESS. All three stages emit at the same
##    0.24. A sheet that let the late stage also be brighter would prove
##    nothing about whether extent alone reads.
##
## Ambient is deliberately LOW. The whole batch is about light coming out of
## a dark machine in a dark room, and a bench lit for a product shot would
## wash out exactly the differences under review.

const MODELS := "batch024/epsilon"
const STATES := ["dormant", "thinking", "speaking",
		"interpreted", "refusal", "focus"]
const ARC := ["early", "middle", "late"]

var _assets := ""
var _out := ""
var _mf := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: EpsilonStates.gd -- <assets_root> <out_dir>")
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
	await _arc_sheet()
	print("[epsilon024] 2 sheets -> %s" % _out)
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

func _room(root: Node3D, span: float) -> void:
	# A dark host room. The installation stands against its wall, and the
	# point of the batch is light leaving a machine into an unlit space.
	for spec in [[Vector3(span, 0.3, span), Vector3(0, -0.15, 0)],
			[Vector3(span, 6.0, 0.3), Vector3(0, 3.0, -2.2)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		m.position = spec[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.17, 0.19)
		mat.roughness = 0.95
		m.material_override = mat
		root.add_child(m)

func _panel(name: String, size: Vector2i, eye: Vector3, look: Vector3,
		fov: float, span: float, rod_at: Vector3) -> Image:
	# 0.11 ambient / 0.34 key. Two constraints pull against each other and
	# the first pass got both wrong:
	#
	#   too dark  -> the human machine vanishes and every panel is a green
	#                blob in a void, which proves nothing about a state
	#                language that is supposed to live ON a machine;
	#   too bright -> the raked control panel catches the key broadside and
	#                reads as a LIT control surface. That breaks 002-R's one
	#                rule as completely as an emission would, and the first
	#                render did exactly this: the brightest thing in every
	#                panel was the human console.
	#
	# So: ambient carries the machine, the key is dropped until the rake
	# stops flaring, and emission is the only thing that is actually bright.
	var vp := ArtBench.make_viewport(self, size, 0.11)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 0.34)
	_room(root, span)

	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if node == null:
		push_error("epsilon024: missing %s" % name)
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

func _state_sheet() -> void:
	var cell := Vector2i(720, 540)
	var sheet := Image.create(cell.x * 3, cell.y * 2 + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in STATES.size():
		var state: String = STATES[i]
		var name := "eps_state_%s" % state
		# IDENTICAL camera in all six. The intrusion sits at Blender
		# (0.72, ~0, 2.02); Blender -Y is Godot +Z, so the machine faces
		# +Z and the room is on that side.
		#
		# A 3/4 view from the intrusion's side, far enough back to hold the
		# WHOLE bay -- desk, footwell, monitor and mass. The first pass shot
		# from 2.35 m dead in front and cropped to the mass alone, which
		# turned a state language that lives on an operator console into six
		# pictures of a lump.
		var img: Image = await _panel(name, cell,
				Vector3(2.25, 2.00, 3.05), Vector3(0.10, 1.52, 0.0),
				48.0, 14.0, Vector3.INF)
		if img == null:
			continue
		var at := Vector2i((i % 3) * cell.x, 116 + int(i / 3) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		var e: Dictionary = _mf.get(name, {})
		ArtBench.label(sheet, state.to_upper(), at + Vector2i(10, 10),
				Color(0.34, 1.0, 0.12))
		ArtBench.label(sheet, str(e.get("means", "")),
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
		ArtBench.label(sheet, "EMISSIVE %.2f  OF %.2f CEILING" % [
				float(e.get("emissive_saturation", 0.0)),
				float(e.get("emissive_ceiling", 0.4))],
				at + Vector2i(10, cell.y - 44), Color(0.60, 0.64, 0.68))
		ArtBench.label(sheet, "RUNTIME SIGNAL: %s" % (
				"EXISTS" if bool(e.get("runtime_signal_exists", false))
				else "DOES NOT EXIST YET"),
				at + Vector2i(10, cell.y - 22),
				Color(0.45, 0.72, 0.68) if bool(
						e.get("runtime_signal_exists", false))
				else Color(0.91, 0.33, 0.12))
	ArtBench.label(sheet, "A  EPSILON PRESENTATION STATES",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "ONE HUE ONLY. IDENTICAL GEOMETRY, IDENTICAL "
			+ "CAMERA -- VALUE, APERTURE, EXTENT AND ORIENTATION CARRY "
			+ "THE DIFFERENCE.", Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "PROPOSAL. NOTHING ON THE HUMAN HALF GLOWS "
			+ "(002-R). PRESENTATION ONLY -- NO GAMEPLAY EFFECT IS "
			+ "IMPLIED OR INVENTED.", Vector2i(12, 68),
			Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/A_epsilon_states.png" % _out)

func _arc_sheet() -> void:
	var cell := Vector2i(700, 560)
	var sheet := Image.create(cell.x * 3, cell.y + 116, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	for i in ARC.size():
		var stage: String = ARC[i]
		var name := "eps_arc_%s" % stage
		# Shot from the INTRUSION'S side. The first pass shot from the far
		# left, which put the origin mass at the distant end of the bank
		# behind its own cabinet front: EARLY rendered as a plain wall with
		# no intrusion visible at all, so the one sheet whose whole job is
		# to show extent showed a bank of cabinets three times.
		#
		# From +x the origin is the NEAREST thing in every panel and the
		# growth reaches away from camera, which is what "it has spread"
		# actually looks like.
		# The rod goes to the FAR side, not the near one. Placed at +x it
		# stood between the camera and the origin mass and blanked out the
		# only intrusion EARLY has -- a scale reference that hides the
		# subject is worse than no scale reference (L-69's cousin).
		# Solved, not guessed, after three passes of nudging: the cell is
		# 700x560, so a 46 deg vertical fov is ~55.6 deg horizontal, and
		# covering the 4.9 m bank plus its mass needs 3.5 / tan(27.8 deg)
		# = 6.6 m of standoff. On a front-right diagonal that puts the
		# origin mass -- the only intrusion EARLY has -- nearest the
		# camera on a front face, with the growth reaching away to the
		# left. The rod goes front-LEFT, clear of that sightline.
		var img: Image = await _panel(name, cell,
				Vector3(5.15, 2.45, 3.95), Vector3(0.0, 1.40, 0.0),
				46.0, 22.0, Vector3(-3.20, 0.0, 2.20))
		if img == null:
			continue
		var at := Vector2i(i * cell.x, 116)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		var e: Dictionary = _mf.get(name, {})
		ArtBench.label(sheet, stage.to_upper(), at + Vector2i(10, 10),
				Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(e.get("means", "")),
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
		ArtBench.label(sheet, "EMISSIVE %.2f -- HELD CONSTANT" % float(
				e.get("emissive_saturation", 0.0)),
				at + Vector2i(10, cell.y - 34), Color(0.45, 0.72, 0.68))
	ArtBench.label(sheet, "B  THE PRESENTATION ARC",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "LOCALIZED -> ESTABLISHED -> PROPRIETORIAL. "
			+ "WHITE ROD IS 1.8 M. EMISSION IS THE SAME IN ALL THREE: "
			+ "THE READ IS EXTENT.", Vector2i(12, 42),
			Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "PRESENTATION, NOT PROGRESSION. NOTHING HERE "
			+ "SAYS WHEN A STAGE APPLIES OR WHAT ADVANCES IT.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	sheet.save_png("%s/B_epsilon_arc.png" % _out)
