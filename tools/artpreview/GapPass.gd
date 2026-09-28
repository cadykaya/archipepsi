extends SceneTree
## The post-030 gap pass: batches 031, 032, 034 and 035.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s GapPass.gd -- <assets_root> <out_dir_root>
##
## Four batches share one renderer because they share one question: does the
## thing read WITHOUT being told what it is? Every sheet here is built as a
## test rather than a showcase, and 035's is a blind one.

var _assets := ""
var _root := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: GapPass.gd -- <assets_root> <out_dir_root>")
		quit(2)
		return
	_assets = args[0]
	_root = args[1]
	await _keys_sheet()
	await _viewmodel_sheet()
	await _gates_sheet()
	await _recognition_sheet()
	print("[gappass] 5 sheets -> %s" % _root)
	quit()

# --- shared rig ------------------------------------------------------------

func _manifest(dir: String) -> Dictionary:
	var f := FileAccess.open("%s/models/%s/manifest.json" % [_assets, dir],
			FileAccess.READ)
	return {} if f == null else JSON.parse_string(f.get_as_text())

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

func _ground(root: Node3D, span: float, wall: bool) -> void:
	var specs := [[Vector3(span, 0.3, span), Vector3(0, -0.15, 0)]]
	if wall:
		specs.append([Vector3(span, 7.0, 0.3), Vector3(0, 3.5, -3.0)])
	for spec in specs:
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

func _load(root: Node3D, dir: String, name: String, at: Vector3) -> Node3D:
	var node: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, dir, name])
	if node == null:
		push_error("gappass: missing %s/%s" % [dir, name])
		return null
	ArtBench.force_nearest(node)
	node.position = at
	root.add_child(node)
	return node


## Override every emissive surface with the dull body value, so the shared
## `signal` state plate stops being visible.
##
## This exists because the first recognition sheet FAILED AS A TEST: every
## interactable showed a cyan plate and every decoy did not, so the sheet
## was solvable by spotting cyan and proved nothing about the structural
## grammar it was built to test. The builder's own docstring had already
## named that risk. Sheet B is the real result.
func _suppress_plates(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled:
				var dull := StandardMaterial3D.new()
				dull.albedo_color = Color(0.30, 0.31, 0.33)
				dull.roughness = 0.9
				mi.set_surface_override_material(i, dull)
	for child in node.get_children():
		_suppress_plates(child)

## Sheet F. The strictest form of the test, and the one that answers the
## owner's "must NOT require colour vision to identify interactivity"
## without asking the reader to take anything on trust.
##
## Sheet E suppresses the plate's EMISSION, but 035-R gave the plate a bezel
## -- body geometry, deliberately, so the cue survives greyscale -- and body
## geometry cannot be suppressed at render time. That leaves sheet E with the
## same shape of defect it was built to fix: every decoy carries no plate at
## all, so a reader who sorts by "has a bezel" scores 12/12 and learns
## nothing about the structural grammar.
##
## A silhouette has no bezel, no emission, no material and no colour. If the
## pairs separate here, the tell is object-scale. If they do not, it is not,
## whatever the other two sheets appear to show.
func _silhouette(node: Node) -> void:
	if node is MeshInstance3D:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color(0.04, 0.04, 0.05)
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(node as MeshInstance3D).material_override = flat
	for child in node.get_children():
		_silhouette(child)

## A lit backdrop for the silhouette sheet: the subject must be the dark
## thing, so the ground and wall have to be the bright ones.
func _backdrop(root: Node3D, span: float) -> void:
	for spec in [[Vector3(span, 0.3, span), Vector3(0, -0.15, 0)],
			[Vector3(span, 9.0, 0.3), Vector3(0, 4.5, -3.0)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.74, 0.76, 0.79)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.mesh = b
		m.position = spec[1]
		m.material_override = mat
		root.add_child(m)

func _out(batch: String) -> String:
	var d := "%s/batch%s" % [_root, batch]
	DirAccess.make_dir_recursive_absolute(d)
	return d

# --- 031: the local Zone key family ---------------------------------------

func _keys_sheet() -> void:
	const DIR := "batch031/keys"
	var mf := _manifest(DIR)
	var cell := Vector2i(640, 520)
	var sheet := Image.create(cell.x * 3, cell.y * 3 + 140, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))

	# Row 1 -- the three channels, at the distance you decide to take one.
	# Row 2 -- the same channel in three themes: the shank never changes.
	# Row 3 -- each channel beside the receiver it mates with.
	var rows := [
		["zkey_ch1", "zkey_ch2", "zkey_ch3"],
		["zkey_ch1", "zkey_ch1_rusted_industrial", "zkey_ch1_void_glitch"],
	]
	for r in rows.size():
		for c in 3:
			var name: String = rows[r][c]
			var img: Image = await _shoot(cell,
					Vector3(0.50, 0.60, 0.74), Vector3(0.0, 0.14, -0.02),
					40.0, 0.24, 0.78,
					func(root: Node3D) -> void:
						_ground(root, 12.0, false)
						_load(root, DIR, name, Vector3.ZERO))
			if img == null:
				continue
			var at := Vector2i(c * cell.x, 140 + r * cell.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
			var e: Dictionary = mf.get(name, {})
			ArtBench.label(sheet, "CHANNEL %d" % int(e.get("channel", 0)),
					at + Vector2i(10, 10), Color(1.0, 0.86, 0.42))
			ArtBench.label(sheet, str(e.get("theme", "")).to_upper(),
					at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
			ArtBench.label(sheet, str(e.get("code_is", "")),
					at + Vector2i(10, cell.y - 26), Color(0.27, 0.84, 0.78))
	for c in 3:
		var ch := c + 1
		var img: Image = await _shoot(cell,
				Vector3(1.20, 1.35, 1.55), Vector3(0.05, 0.95, -0.05),
				44.0, 0.24, 0.78,
				func(root: Node3D) -> void:
					_ground(root, 12.0, true)
					_load(root, DIR, "zkey_receiver_ch%d" % ch, Vector3.ZERO)
					_load(root, DIR, "zkey_ch%d" % ch,
							Vector3(0.62, 0.0, 0.30)))
		if img == null:
			continue
		var at := Vector2i(c * cell.x, 140 + 2 * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, "CHANNEL %d  KEY AND ITS RECEIVER" % ch,
				at + Vector2i(10, 10), Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, "THE KEYWAY IS THE KEY, DRAWN IN NEGATIVE",
				at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "A  THE LOCAL ZONE KEY FAMILY", Vector2i(12, 16),
			Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "ROW 1  THREE CHANNELS.  ROW 2  ONE CHANNEL IN "
			+ "THREE THEMES -- THE SHANK NEVER CHANGES.  ROW 3  EACH KEY "
			+ "WITH ITS RECEIVER.", Vector2i(12, 42),
			Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "CHANNEL IS COUNTED, NEVER COLOURED: N LUGS PLUS "
			+ "THE SHOULDER NOTCH ROTATED N STEPS. PROPOSAL -- PENDING.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	ArtBench.label(sheet, "NOT A KEYCARD, NOT A FANTASY KEY: A MACHINED "
			+ "INTERLOCK BLANK.", Vector2i(12, 94), Color(0.60, 0.64, 0.68))
	sheet.save_png("%s/A_zone_keys.png" % _out("031"))

# --- 032: the viewmodel ----------------------------------------------------

func _viewmodel_sheet() -> void:
	const DIR := "batch032/viewmodel"
	var mf := _manifest(DIR)
	var cell := Vector2i(700, 560)
	var sheet := Image.create(cell.x * 3, cell.y * 2 + 140, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	var shots := [
		["vm_device_stowed", "STOWED", "THE FORK FOLDED ALONG THE SHELL"],
		["vm_device_melee", "DEPLOYED",
			"A GROUNDING PRONG, SWUNG BECAUSE IT IS WHAT IS IN YOUR HAND"],
		["", "", ""],
		["vm_echopart_ranged", "ECHOPART  RANGED", "A CLOSED BARREL"],
		["vm_echopart_melee", "ECHOPART  MELEE", "A FLAT BLADE PLANE"],
		["vm_echopart_grapple", "ECHOPART  GRAPPLE",
			"AN OPEN CLAW -- THE ONLY ONE WITH A HOLE IN ITS OUTLINE"],
	]
	for i in shots.size():
		var s: Array = shots[i]
		if str(s[0]).is_empty():
			continue
		var img: Image = await _shoot(cell,
				Vector3(0.36, 0.30, 0.46), Vector3(0.0, 0.14, 0.0),
				38.0, 0.26, 0.80,
				func(root: Node3D) -> void:
					_ground(root, 6.0, false)
					_load(root, DIR, str(s[0]), Vector3.ZERO))
		if img == null:
			continue
		var at := Vector2i((i % 3) * cell.x, 140 + int(i / 3) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		ArtBench.label(sheet, str(s[1]), at + Vector2i(10, 10),
				Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, str(s[2]), at + Vector2i(10, 32),
				Color(0.72, 0.76, 0.80))
		var e: Dictionary = mf.get(str(s[0]), {})
		ArtBench.label(sheet, "BINDS TO %s" % str(e.get("binds_to", "")),
				at + Vector2i(10, cell.y - 26), Color(0.27, 0.84, 0.78))
	ArtBench.label(sheet, "B  THE VIEWMODEL: BASELINE MELEE, AND THE FORGE SEAM",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "BUILT TO PLAYER.GD'S OWN NODE DIMENSIONS. TOP: "
			+ "THE STATIC PULSE DEVICE, FORK STOWED AND DEPLOYED.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "BOTTOM: THREE OF SEVEN ECHOPART FAMILY FORMS. "
			+ "A REFORGE CURRENTLY CHANGES NOTHING ON THE VIEWMODEL -- "
			+ "REQ 32.", Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	ArtBench.label(sheet, "FORM = FAMILY.  COLOUR = SOURCE (UNCHANGED).  "
			+ "TIP = SLOT (UNCHANGED).", Vector2i(12, 94),
			Color(0.60, 0.64, 0.68))
	sheet.save_png("%s/A_viewmodel.png" % _out("032"))

# --- 034: hard gates -------------------------------------------------------

func _gates_sheet() -> void:
	const DIR := "batch034/gates"
	var mf := _manifest(DIR)
	var cell := Vector2i(880, 620)
	var sheet := Image.create(cell.x * 2, cell.y * 4 + 140, false,
			Image.FORMAT_RGB8)
	sheet.fill(Color(0.07, 0.08, 0.10))
	var gates := ["gate_grapple", "gate_break", "gate_launch",
			"gate_blink_proposal"]
	for i in gates.size():
		for c in 2:
			var name: String = gates[i] if c == 0 else "%s_ragged" % gates[i]
			# A player's eye, well back: a gate is judged on approach.
			var img: Image = await _shoot(cell,
					Vector3(3.30, 1.60, 7.60), Vector3(0.0, 1.90, 0.0),
					62.0, 0.26, 0.72,
					func(root: Node3D) -> void:
						_ground(root, 26.0, false)
						_load(root, DIR, name, Vector3.ZERO)
						_rod(root, Vector3(-2.90, 0.0, 1.40)))
			if img == null:
				continue
			var at := Vector2i(c * cell.x, 140 + i * cell.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
			var e: Dictionary = mf.get(name, {})
			var finished: bool = bool(e.get("finished", false))
			ArtBench.label(sheet,
					("INTENTIONAL" if finished else "BROKEN") + "  --  "
					+ str(e.get("capability_family", "no contract")).to_upper(),
					at + Vector2i(10, 10),
					Color(0.27, 0.84, 0.78) if finished
					else Color(0.91, 0.33, 0.12))
			ArtBench.label(sheet, str(e.get("reads_as", "")),
					at + Vector2i(10, 32), Color(0.72, 0.76, 0.80))
			if not bool(e.get("has_mechanical_contract", true)):
				ArtBench.label(sheet, "NO MECHANICAL CONTRACT -- PROPOSAL "
						+ "ONLY, NOT A PRODUCTION ASSET",
						at + Vector2i(10, cell.y - 26),
						Color(0.94, 0.62, 0.42))
	ArtBench.label(sheet, "C  HARD GATES: 'NOT YET' MUST LOOK INTENTIONAL",
			Vector2i(12, 16), Color(1.0, 0.86, 0.42))
	ArtBench.label(sheet, "LEFT  THE FINISHED GATE.  RIGHT  THE SAME ROUTE "
			+ "UNFINISHED -- THE READING IT MUST NOT BE CONFUSED WITH.",
			Vector2i(12, 42), Color(0.72, 0.76, 0.80))
	ArtBench.label(sheet, "THE TELL IS FINISH QUALITY, NOT SIGNAGE. BROKEN "
			+ "IS RAGGED; INSTALLED IS NEAT. NO COLOUR CARRIES THIS READ.",
			Vector2i(12, 68), Color(0.94, 0.62, 0.42))
	ArtBench.label(sheet, "WHITE ROD IS 1.8 M. HAZARD IS USED NOWHERE.",
			Vector2i(12, 94), Color(0.60, 0.64, 0.68))
	sheet.save_png("%s/A_hard_gates.png" % _out("034"))

# --- 035: the blind recognition test ---------------------------------------

## Twelve objects in a row: six interactables from Batch 028 and six decoys
## from 035, INTERLEAVED and captioned only by number. The reader sorts them
## before turning to the key. That is the whole test, and a sheet that
## labelled them would not be one.
func _recognition_sheet() -> void:
	var order := [
		["batch028/interaction", "int_carryable", true],
		["batch035/decoys", "dec_panel_blind", false],
		["batch028/interaction", "int_wall_switch", true],
		["batch035/decoys", "dec_pipe_fixed", false],
		["batch028/interaction", "int_breakable", true],
		["batch035/decoys", "dec_crate_fixed", false],
		["batch028/interaction", "int_key_receiver", true],
		["batch035/decoys", "dec_bulkhead", false],
		["batch028/interaction", "int_machinery", true],
		["batch035/decoys", "dec_console_dead", false],
		["batch028/interaction", "int_door_mechanism", true],
		["batch035/decoys", "dec_hatch_welded", false],
	]
	# 0 = plate lit, 1 = plate emission suppressed, 2 = pure silhouette.
	for mode in [0, 1, 2]:
		var suppressed: bool = mode == 1
		var solid: bool = mode == 2
		var cell := Vector2i(520, 560)
		var sheet := Image.create(cell.x * 6, cell.y * 2 + 168, false,
				Image.FORMAT_RGB8)
		sheet.fill(Color(0.07, 0.08, 0.10))
		for i in order.size():
			var row: Array = order[i]
			# 4.5 m: representative gameplay distance, not inspection.
			var img: Image = await _shoot(cell,
					Vector3(2.30, 1.60, 3.60), Vector3(0.0, 0.95, 0.0),
					48.0, 0.24 if not solid else 1.0, 0.70 if not solid else 0.0,
					func(root: Node3D) -> void:
						if solid:
							_backdrop(root, 16.0)
						else:
							_ground(root, 16.0, true)
						var n := _load(root, str(row[0]), str(row[1]),
								Vector3.ZERO)
						if n == null:
							return
						if suppressed:
							_suppress_plates(n)
						elif solid:
							_silhouette(n))
			if img == null:
				continue
			var at := Vector2i((i % 6) * cell.x, 168 + int(i / 6) * cell.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
			# NUMBER ONLY. No name, no verdict.
			ArtBench.label(sheet, "%d" % (i + 1), at + Vector2i(12, 12),
					Color(1.0, 0.86, 0.42) if not solid
					else Color(0.20, 0.16, 0.06))
		var letter: String = ["D", "E", "F"][mode]
		ArtBench.label(sheet, "%s  INTERACTIVE OR DECORATIVE? SORT THEM FIRST"
				% letter, Vector2i(12, 16), Color(1.0, 0.86, 0.42))
		ArtBench.label(sheet, "TWELVE OBJECTS AT 4.5 M -- REPRESENTATIVE "
				+ "GAMEPLAY DISTANCE, NOT INSPECTION DISTANCE. SIX CAN BE "
				+ "USED AND SIX CANNOT.", Vector2i(12, 42),
				Color(0.72, 0.76, 0.80))
		if solid:
			ArtBench.label(sheet, "SILHOUETTE ONLY. NO MATERIAL, NO "
					+ "EMISSION, NO BEZEL, NO COLOUR -- THE STRICTEST FORM "
					+ "OF THE TEST AND THE ONE THAT DECIDES 035.",
					Vector2i(12, 68), Color(0.91, 0.33, 0.12))
			ArtBench.label(sheet, "SHEET E STILL LEAKED: THE PLATE'S BEZEL "
					+ "IS BODY GEOMETRY AND NO DECOY HAS ONE, SO 'FIND THE "
					+ "BEZEL' SOLVED IT WITHOUT USING THE GRAMMAR.",
					Vector2i(12, 94), Color(0.94, 0.62, 0.42))
			ArtBench.label(sheet, "1 vs 6: A GAP UNDER IT AND A HOLE THROUGH "
					+ "THE BAIL.   7 vs 12: A MOUTH IN IT.   5 vs 2: BROKEN "
					+ "IN RELIEF. OBJECT SCALE, NOT HAND SCALE.",
					Vector2i(12, 120), Color(0.60, 0.64, 0.68))
		elif suppressed:
			ArtBench.label(sheet, "THE STATE PLATE IS SUPPRESSED IN THIS "
					+ "SHEET. THIS IS THE REAL TEST: SHEET D WAS SOLVABLE "
					+ "BY SPOTTING CYAN, WHICH PROVES NOTHING.",
					Vector2i(12, 68), Color(0.91, 0.33, 0.12))
			ArtBench.label(sheet, "WHAT IS LEFT IS THE STRUCTURAL GRAMMAR: "
					+ "GRIP, MOUNTING HARDWARE, A MECHANICAL JOINT, AND "
					+ "SOMEWHERE FOR THE THING TO GO.", Vector2i(12, 94),
					Color(0.94, 0.62, 0.42))
		else:
			ArtBench.label(sheet, "EVERY DECOY IS A NEAR-MISS OF A REAL ONE, "
					+ "BUILT FROM THE SAME KIT AT THE SAME SCALE. A DECOY "
					+ "THAT IS EASY TO REJECT PROVES NOTHING.",
					Vector2i(12, 68), Color(0.94, 0.62, 0.42))
			ArtBench.label(sheet, "THIS SHEET STILL SHOWS THE STATE PLATE. "
					+ "SEE SHEET E, WHERE IT IS SUPPRESSED.",
					Vector2i(12, 94), Color(0.60, 0.64, 0.68))
		ArtBench.label(sheet, "ANSWER KEY, READ LAST: ODD NUMBERS ARE "
				+ "INTERACTIVE, EVEN ARE DECORATIVE.",
				Vector2i(12, cell.y * 2 + 148), Color(0.40, 0.44, 0.50))
		sheet.save_png("%s/%s.png" % [_out("035"),
				["A_recognition", "B_recognition_no_plate",
				"C_recognition_silhouette"][mode]])
