extends SceneTree
## Batch 022 -- PROPOSAL: the navigation language, in room contexts.
##
##   godot --rendering-driver opengl3 --path tools/artpreview \
##       -s NavLanguage.gd -- <assets_root> <out_dir>
##
## Four shots, each answering one question the owner asked:
##
##   A junction    which way from here, at eye height, at walking distance
##   B threshold   what IS this place, on a row of doors
##   C hue         does it collide with anything already spoken for
##   D themes      does it survive the themes that are authored
##
## Every distance is read from art_budgets.json, never typed here.

const SHOT := Vector2i(1500, 940)
const MODELS := "batch022/navigation"

var _assets := ""
var _out := ""
var _dim := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: NavLanguage.gd -- <assets_root> <out_dir>")
		quit(2)
		return
	_assets = args[0]
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var f := FileAccess.open("%s/art_budgets.json" % _assets, FileAccess.READ)
	if f == null:
		push_error("NavLanguage: no assets/art_budgets.json")
		quit(2)
		return
	_dim = JSON.parse_string(f.get_as_text()).get("dimensions", {})

	await _junction()
	await _threshold()
	await _hue()
	await _themes()
	await _family()
	_swatches()
	print("[nav] 7 shots -> %s" % _out)
	quit()

func _num(key: String, fallback: float) -> float:
	return float(_dim.get(key, fallback))

func _glb(name: String) -> Node3D:
	var n: Node3D = ArtBench.load_glb(
			"%s/models/%s/%s.glb" % [_assets, MODELS, name])
	if n == null:
		push_error("NavLanguage: missing %s" % name)
		return null
	ArtBench.force_nearest(n)
	return n

## The runtime text. Every face in this family is a blank field and the
## wording arrives from the game, exactly as `chamber_builders` already
## does for the transit sign and `hub.gd` for the campaign board.
func _text(root: Node3D, body: String, at: Vector3, yaw: float,
		size: int = 44) -> void:
	var l := Label3D.new()
	l.text = body
	l.font_size = size
	l.pixel_size = 0.0032
	# Near-black on the pale field: contrast by VALUE, which is the whole
	# argument. Give it a hue and it starts competing with the HUD.
	l.modulate = Color(0.09, 0.10, 0.12)
	l.position = at
	l.rotation_degrees.y = yaw
	root.add_child(l)

func _slab(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	mat.metallic = 0.0
	m.material_override = mat
	m.position = at
	root.add_child(m)

func _flat(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = ArtBench.flat_material(colour)
	m.position = at
	root.add_child(m)

## A 1.8 m stand-in where the player would be, so every shot is read at
## the scale it will actually be seen at.
func _rod(root: Node3D, at: Vector3) -> void:
	var tall := _num("player_height", 1.8)
	_slab(root, Vector3(0.36, tall, 0.36), at + Vector3(0, tall * 0.5, 0),
			Color(0.80, 0.83, 0.88))
	_flat(root, Vector3(0.42, 0.04, 0.42),
			at + Vector3(0, _num("player_eye_height", 1.6), 0),
			Color(0.25, 0.30, 0.36))

func _capture(vp: SubViewport, path: String) -> Image:
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

## Where each sign sits, read from the builder's manifest rather than
## repeated here. The builder exports with `module_floor`, so the authored
## height survives the export and a sign placed at y = 0 lands where it
## was designed to land.
var _mf := {}

func _manifest() -> Dictionary:
	if _mf.is_empty():
		var f := FileAccess.open(
				"%s/models/%s/manifest.json" % [_assets, MODELS],
				FileAccess.READ)
		if f != null:
			_mf = JSON.parse_string(f.get_as_text())
	return _mf

func _top(name: String, fallback: float) -> float:
	return float(_manifest().get(name, {}).get("authored_top_m", fallback))

## Mount a wall sign so its bracket end sits ON the wall plane rather than
## inside it. Measured, not guessed: the first pass placed a 1.30 m blade
## by eye and buried 0.45 m of it in the wall.
##
## `side` is -1 for the left wall and +1 for the right. The asset is
## authored with its bracket on -X, so the right wall yaws 180 and the
## measured extents swap with it.
func _mount(node: Node3D, wall_x: float, side: float, z: float) -> void:
	node.rotation_degrees.y = 0.0 if side < 0.0 else 180.0
	var box: AABB = ArtBench.aabb_of(node)
	var half := box.size.x * 0.5
	# Into the corridor, away from the wall it is bolted to.
	node.position = Vector3(wall_x - side * half, 0, z)

## A -- THE JUNCTION. Which way from here.
##
## A T at `corridor_width_min`, shot from a standing player's eye at the
## distance a sign is actually read from.
##
## The blade turns PERPENDICULAR to the wall on purpose: a flush plate is
## edge-on and invisible to someone walking toward it, and walking toward
## it is the only time a junction sign matters.
func _junction() -> void:
	var w := _num("corridor_width_min", 4.0)
	var h := _num("corridor_height", 3.6)
	var eye := _num("player_eye_height", 1.6)
	var vp := ArtBench.make_viewport(self, SHOT, 0.30)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.25)

	var junc := 5.4
	_slab(root, Vector3(w, 0.2, 20), Vector3(0, -0.1, 1), Color(0.44, 0.45, 0.48))
	_slab(root, Vector3(w, 0.3, 20), Vector3(0, h + 0.15, 1), Color(0.50, 0.51, 0.54))
	for side in [-1.0, 1.0]:
		_slab(root, Vector3(0.4, h, 16), Vector3(side * w * 0.5, h * 0.5, -0.8),
				Color(0.54, 0.55, 0.59))
	# The wall you hit at the top of the T, and the cross corridor behind it.
	_slab(root, Vector3(w, h, 0.4), Vector3(0, h * 0.5, junc + 1.9),
			Color(0.47, 0.48, 0.52))
	_slab(root, Vector3(15, 0.2, w), Vector3(0, -0.1, junc + 4.1), Color(0.44, 0.45, 0.48))
	_slab(root, Vector3(15, 0.3, w), Vector3(0, h + 0.15, junc + 4.1), Color(0.50, 0.51, 0.54))
	_slab(root, Vector3(15, h, 0.4), Vector3(0, h * 0.5, junc + 6.3), Color(0.54, 0.55, 0.59))

	# A blade on each side wall at the junction. Its bracket mounts on -X,
	# so the left-hand one needs no yaw and the right-hand one turns 180.
	# Its FACE lies in the X-Z plane, which means it presents to someone
	# coming up the corridor -- the whole reason for the configuration.
	# A blade names the branch; a chevron beside it says which way. They
	# are separate on purpose: which way "PUMP HALL" lies is a fact about
	# where this junction is, not a fact about the sign, so the direction
	# is placed and yawed here rather than baked into the mesh.
	var bx := {}
	for side in [-1.0, 1.0]:
		var blade := _glb("nav_blade")
		if blade == null:
			return
		root.add_child(blade)
		_mount(blade, side * w * 0.5, side, junc)
		# Butted against the blade's outboard end, so the pair reads as one
		# sign: [WEST WING][<] on the left, [PUMP HALL][>] on the right.
		var arrow := _glb("nav_chevron")
		if arrow != null:
			root.add_child(arrow)
			var ab: AABB = ArtBench.aabb_of(arrow)
			# On the side the branch runs toward, which is the reading
			# convention: [<- WEST WING] and [PUMP HALL ->]. Measured from
			# the face end, since the bracket skews the mesh centre.
			arrow.position = Vector3(
					blade.position.x + side * (0.585 + ab.size.x * 0.5),
					_top("nav_blade", 2.72) - 0.28, junc)
			# The arrowhead is authored pointing +X, so a branch running
			# left needs it turned over.
			arrow.rotation_degrees.y = 180.0 if side < 0.0 else 0.0
		bx[side] = blade.position.x
	var bt := _top("nav_blade", 2.72) - 0.28
	_text(root, "WEST WING", Vector3(bx[-1.0] + 0.06, bt, junc - 0.10), 180.0, 20)
	_text(root, "PUMP HALL", Vector3(bx[1.0] - 0.06, bt, junc - 0.10), 180.0, 20)

	# A hanger further back, where the wall blades are still edge-on.
	var hang := _glb("nav_hanger")
	if hang != null:
		hang.position = Vector3(0, 0, 2.4)
		root.add_child(hang)
		_text(root, "SECTOR 4", Vector3(0.0, _top("nav_hanger", 3.55) - 0.83,
				2.30), 180.0, 26)

	_rod(root, Vector3(-1.35, 0, 0.9))

	var cam := Camera3D.new()
	cam.fov = _num("camera_fov_deg", 90.0)
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.45, eye, 0.2),
			Vector3(0.10, eye + 0.50, junc), Vector3.UP)

	var img: Image = await _capture(vp, "")
	var gold := Color(1.0, 0.83, 0.36)
	var pale := Color(0.72, 0.76, 0.80)
	ArtBench.label(img, "A  JUNCTION - WHICH WAY FROM HERE", Vector2i(12, 12), gold)
	ArtBench.label(img, "BLADES TURN PERPENDICULAR: A FLUSH PLATE IS EDGE-ON TO SOMEONE WALKING AT IT",
			Vector2i(12, 34), pale)
	ArtBench.label(img, "SHOT FROM %.1f M EYE AT %.0f FOV - GAMEPLAY DISTANCE, NOT A PRODUCT SHOT"
			% [eye, _num("camera_fov_deg", 90.0)],
			Vector2i(12, img.get_height() - 46), pale)
	ArtBench.label(img, "NO HUE. DIRECTION IS THE CHEVRON FOLD; IDENTITY IS RUNTIME TEXT.",
			Vector2i(12, img.get_height() - 24), Color(0.45, 0.72, 0.68))
	img.save_png("%s/A_junction.png" % _out)
	vp.queue_free()
	await process_frame

## B -- THE THRESHOLD. What IS this place.
##
## Doors down one wall, each with a panel beside the jamb at eye height.
## This shot argues the panel and the blade must stay different objects:
## a blade at every door would be a forest of fins, and a run of panels
## reads as a level line without adding a single colour.
func _threshold() -> void:
	var w := _num("corridor_width_min", 4.0) + 1.4
	var h := _num("corridor_height", 3.6)
	var dw := _num("door_width", 2.4)
	var dh := _num("door_height", 3.2)
	var eye := _num("player_eye_height", 1.6)
	var vp := ArtBench.make_viewport(self, SHOT, 0.30)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.25)

	_slab(root, Vector3(w, 0.2, 22), Vector3(0, -0.1, 5), Color(0.44, 0.45, 0.48))
	_slab(root, Vector3(w, 0.3, 22), Vector3(0, h + 0.15, 5), Color(0.50, 0.51, 0.54))
	_slab(root, Vector3(0.4, h, 22), Vector3(w * 0.5, h * 0.5, 5), Color(0.54, 0.55, 0.59))
	_slab(root, Vector3(0.4, h, 22), Vector3(-w * 0.5, h * 0.5, 5), Color(0.52, 0.53, 0.57))
	_slab(root, Vector3(w, h, 0.4), Vector3(0, h * 0.5, 15.6), Color(0.47, 0.48, 0.52))

	# Panels mount flush on -Y, so a sign on the left wall yaws +90 to
	# present its face into the corridor.
	var names := ["COOLANT", "STORES 2", "STAIR C"]
	var pz := _top("nav_panel", 2.05) - 0.36
	for i in 3:
		var z := 1.6 + i * 4.5
		_slab(root, Vector3(0.5, dh, dw), Vector3(-w * 0.5 + 0.05, dh * 0.5, z),
				Color(0.17, 0.18, 0.21))
		var panel := _glb("nav_panel")
		if panel == null:
			return
		panel.position = Vector3(-w * 0.5 + 0.21, 0, z - dw * 0.5 - 0.62)
		panel.rotation_degrees.y = 90.0
		root.add_child(panel)
		_text(root, names[i], Vector3(-w * 0.5 + 0.38, pz, z - dw * 0.5 - 0.62),
				90.0, 26)

	_rod(root, Vector3(1.5, 0, 0.2))

	var cam := Camera3D.new()
	cam.fov = _num("camera_fov_deg", 90.0)
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(2.0, eye, -2.0),
			Vector3(-1.6, eye + 0.05, 5.4), Vector3.UP)

	var img: Image = await _capture(vp, "")
	var gold := Color(1.0, 0.83, 0.36)
	var pale := Color(0.72, 0.76, 0.80)
	ArtBench.label(img, "B  THRESHOLD - WHAT IS THIS PLACE", Vector2i(12, 12), gold)
	ArtBench.label(img, "BESIDE THE JAMB AT EYE HEIGHT. OVER THE DOOR DOES NOT FIT: 3.2 M DOOR UNDER A 3.6 M CEILING",
			Vector2i(12, 34), pale)
	ArtBench.label(img, "OVERHEAD MEANS THAT WAY. EYE HEIGHT MEANS THIS IS HERE.",
			Vector2i(12, img.get_height() - 46), pale)
	ArtBench.label(img, "THE HUD NAMES THE CHECK. IT NEVER NAMES THE ROOM. THIS DOES.",
			Vector2i(12, img.get_height() - 24), Color(0.45, 0.72, 0.68))
	img.save_png("%s/B_threshold.png" % _out)
	vp.queue_free()
	await process_frame

## C -- THE HUE TEST. Does it collide with anything already spoken for.
##
## One corridor holding every colour the project has committed: hazard
## orange, signal teal, Epsilon green, send amber, and the HUD's own EXIT
## green. The signage is the only thing in frame with no hue at all, which
## is exactly why it cannot be confused with any of them.
##
## Then the same frame desaturated. That is the owner's rule turned into a
## test: EXIT green and Epsilon green collapse onto each other, READY cyan
## and affordance teal collapse onto each other, and the signage does not
## move -- it never carried hue to lose.
func _hue() -> void:
	var w := _num("corridor_width_min", 4.0) + 1.0
	var h := _num("corridor_height", 3.6)
	var eye := _num("player_eye_height", 1.6)
	var vp := ArtBench.make_viewport(self, SHOT, 0.30)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.15)

	_slab(root, Vector3(w, 0.2, 20), Vector3(0, -0.1, 4), Color(0.42, 0.43, 0.46))
	_slab(root, Vector3(w, 0.3, 20), Vector3(0, h + 0.15, 4), Color(0.48, 0.49, 0.52))
	_slab(root, Vector3(0.4, h, 20), Vector3(w * 0.5, h * 0.5, 4), Color(0.52, 0.53, 0.57))
	_slab(root, Vector3(0.4, h, 20), Vector3(-w * 0.5, h * 0.5, 4), Color(0.50, 0.51, 0.55))
	_slab(root, Vector3(w, h, 0.4), Vector3(0, h * 0.5, 12.2), Color(0.46, 0.47, 0.51))

	var lx := -w * 0.5 + 0.24
	var rx := w * 0.5 - 0.24
	# hazard #e8541f -- this will hurt you
	_flat(root, Vector3(0.08, 0.70, 1.20), Vector3(lx, 1.70, 2.2),
			Color(0.91, 0.33, 0.12))
	# signal #39d7c8 -- this is a capability
	_flat(root, Vector3(0.08, 0.50, 1.00), Vector3(rx, 2.05, 4.0),
			Color(0.22, 0.84, 0.78))
	# identity #57ff1f -- Epsilon, and nothing else in the game
	_flat(root, Vector3(0.08, 1.40, 0.85), Vector3(lx, 1.55, 6.4),
			Color(0.34, 1.00, 0.12))
	# send #ffd45c -- this leaves for the multiworld
	_flat(root, Vector3(0.78, 0.78, 0.08), Vector3(0.7, 1.55, 11.9),
			Color(1.00, 0.83, 0.36))
	# the HUD's own EXIT green, on the far wall where an exit would be
	_flat(root, Vector3(1.40, 0.12, 0.08), Vector3(-0.9, 2.45, 11.95),
			Color(0.50, 1.00, 0.60))

	# And the navigation family, carrying none of them.
	var blade := _glb("nav_blade")
	if blade != null:
		blade.position = Vector3(rx - 0.02, 0, 7.4)
		blade.rotation_degrees.y = 180.0
		root.add_child(blade)
		_text(root, "STAIR C", Vector3(rx - 0.62, _top("nav_blade", 2.76) - 0.36,
				7.30), 180.0, 24)
	var chev := _glb("nav_chevron")
	if chev != null:
		chev.position = Vector3(lx + 0.04, 2.05, 9.3)
		chev.rotation_degrees.y = -90.0
		root.add_child(chev)

	_rod(root, Vector3(-1.4, 0, -0.4))

	var cam := Camera3D.new()
	cam.fov = _num("camera_fov_deg", 90.0)
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.3, eye, -2.6),
			Vector3(0.0, eye + 0.35, 8.0), Vector3.UP)

	var img: Image = await _capture(vp, "")
	var gold := Color(1.0, 0.83, 0.36)
	var pale := Color(0.72, 0.76, 0.80)

	# Desaturate BEFORE labelling. The first pass built the grey copy from
	# the already-captioned frame and then captioned it again, so both
	# sheets carried two overlapping headers.
	var grey := Image.create(img.get_width(), img.get_height(), false,
			Image.FORMAT_RGB8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			grey.set_pixel(x, y, Color(v, v, v))

	ArtBench.label(img, "C  HUE TEST - EVERY COMMITTED COLOUR, PLUS THE SIGNAGE",
			Vector2i(12, 12), gold)
	ArtBench.label(img, "HAZARD / SIGNAL / EPSILON / SEND / HUD EXIT ALL IN FRAME. THE SIGNS TAKE NONE OF THEM.",
			Vector2i(12, 34), pale)
	img.save_png("%s/C_hue.png" % _out)
	ArtBench.label(grey, "C2  THE SAME FRAME, DESATURATED", Vector2i(12, 12),
			Color(1, 1, 1))
	ArtBench.label(grey, "EXIT GREEN AND EPSILON GREEN COLLAPSE. READY CYAN AND SIGNAL TEAL COLLAPSE.",
			Vector2i(12, 34), Color(0.86, 0.86, 0.86))
	ArtBench.label(grey, "THE SIGNAGE DOES NOT MOVE - IT NEVER CARRIED HUE TO LOSE.",
			Vector2i(12, grey.get_height() - 24), Color(1, 1, 1))
	grey.save_png("%s/C2_hue_desaturated.png" % _out)
	vp.queue_free()
	await process_frame

## D -- THEME SURVIVAL.
##
## The blade against each authored theme wall. Three themes are painted
## (Batch 001); the other three are behind the Style Lock gate and are not
## faked here.
##
## The claim under test is narrow: because the sign is made of the theme's
## own trim and carries one neutral field, it changes MATERIAL with the
## room and never changes MEANING. Nothing in the read depends on a colour
## a theme is free to redefine.
func _themes() -> void:
	var themes := ["CONCRETE FACILITY", "RUSTED INDUSTRIAL", "VOID GLITCH"]
	var walls := [Color(0.50, 0.51, 0.55), Color(0.44, 0.32, 0.25),
			Color(0.18, 0.15, 0.29)]
	var vp := ArtBench.make_viewport(self, Vector2i(1500, 600), 0.30)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.3)

	var bt := _top("nav_blade", 2.72) - 0.28
	for i in 3:
		var x := (i - 1) * 4.2
		_slab(root, Vector3(3.9, 0.2, 4), Vector3(x, -0.1, 0), walls[i].darkened(0.3))
		_slab(root, Vector3(3.9, 3.6, 0.4), Vector3(x, 1.8, 1.4), walls[i])
		var blade := _glb("nav_blade")
		if blade == null:
			return
		blade.position = Vector3(x - 1.55, 0, 1.05)
		root.add_child(blade)
		_text(root, "STAIR C", Vector3(x - 1.02, bt, 0.95), 180.0, 20)

	var cam := Camera3D.new()
	cam.fov = 58.0
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 2.55, -7.4),
			Vector3(0.0, 2.42, 1.2), Vector3.UP)

	var img: Image = await _capture(vp, "")
	var gold := Color(1.0, 0.83, 0.36)
	var pale := Color(0.72, 0.76, 0.80)
	ArtBench.label(img, "D  THEME SURVIVAL - %s" % " / ".join(themes),
			Vector2i(12, 12), gold)
	ArtBench.label(img, "THE THEME'S OWN TRIM PLUS ONE NEUTRAL FIELD: THE MATERIAL CHANGES, THE MEANING DOES NOT",
			Vector2i(12, 34), pale)
	ArtBench.label(img, "THE OTHER THREE THEMES ARE UNPAINTED, BEHIND THE STYLE LOCK GATE - NOT FAKED HERE",
			Vector2i(12, img.get_height() - 24), Color(0.45, 0.72, 0.68))
	img.save_png("%s/D_themes.png" % _out)
	vp.queue_free()
	await process_frame

## E -- THE FAMILY AT READING DISTANCE.
##
## The in-context shots are deliberately small, because that is the size
## these signs actually are when a player meets them. This one is the
## other half of the evidence: the four modules close enough to judge as
## objects, on one wall, at one scale, so the shared plate, chamfer and
## bracket language can be checked rather than taken on trust.
func _family() -> void:
	var vp := ArtBench.make_viewport(self, Vector2i(1500, 900), 0.30)
	var root := Node3D.new()
	vp.add_child(root)
	ArtBench.add_lights(root, 1.35)

	_slab(root, Vector3(15, 0.2, 12), Vector3(0, -0.1, -2), Color(0.40, 0.41, 0.44))
	_slab(root, Vector3(15, 4.4, 0.4), Vector3(0, 2.2, 1.5), Color(0.50, 0.51, 0.55))

	# Blade with its chevron, as a junction pair.
	var blade := _glb("nav_blade")
	if blade == null:
		return
	root.add_child(blade)
	blade.position = Vector3(1.95, 0, 1.15)
	_text(root, "STAIR C", Vector3(1.95, _top("nav_blade", 2.72) - 0.28, 1.09),
			180.0, 30)
	var arrow := _glb("nav_chevron")
	if arrow != null:
		root.add_child(arrow)
		# Against the FACE end, not the whole mesh: the blade's bracket
		# hangs off -X, so its mesh centre is not its face centre.
		var ab: AABB = ArtBench.aabb_of(arrow)
		arrow.position = Vector3(1.95 + 0.585 + ab.size.x * 0.5,
				_top("nav_blade", 2.72) - 0.28, 1.15)

	# The hanger, on its rods.
	var hang := _glb("nav_hanger")
	if hang != null:
		root.add_child(hang)
		hang.position = Vector3(0.3, 0, 1.15)
		_text(root, "SECTOR 4", Vector3(0.3, _top("nav_hanger", 3.51) - 0.80,
				1.09), 180.0, 22)

	# The panel, at the height it is actually mounted.
	var panel := _glb("nav_panel")
	if panel != null:
		root.add_child(panel)
		panel.position = Vector3(-1.15, 0, 1.28)
		_text(root, "COOLANT", Vector3(-1.15, _top("nav_panel", 2.03) - 0.32,
				1.12), 180.0, 30)

	# A lone chevron, for a corner that needs only "that way".
	var solo := _glb("nav_chevron")
	if solo != null:
		root.add_child(solo)
		solo.position = Vector3(-2.05, 1.78, 1.28)

	_rod(root, Vector3(-2.85, 0, 0.7))

	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 2.28, -5.0),
			Vector3(0.0, 2.24, 1.3), Vector3.UP)

	var img: Image = await _capture(vp, "")
	var gold := Color(1.0, 0.83, 0.36)
	var pale := Color(0.72, 0.76, 0.80)
	ArtBench.label(img, "E  THE FAMILY AT READING DISTANCE", Vector2i(12, 12), gold)
	ArtBench.label(img, "BLADE + CHEVRON   /   HANGER   /   PANEL   /   CHEVRON ALONE   -   1.8 M ROD AT LEFT",
			Vector2i(12, 34), pale)
	ArtBench.label(img, "ONE PLATE THICKNESS, ONE CAP AND SILL, ONE NEUTRAL FIELD ACROSS ALL FOUR",
			Vector2i(12, img.get_height() - 24), Color(0.45, 0.72, 0.68))
	img.save_png("%s/E_family.png" % _out)
	vp.queue_free()
	await process_frame

## F -- THE COLLAPSE, WITH NUMBERS.
##
## The corridor shots argue the case in context. This one checks it, by
## putting every committed colour beside its own luminance.
##
## The result is sharper than "they look similar". HUD EXIT green and HUD
## READY cyan sit about two percent apart in luminance: they are separable
## by hue and by essentially nothing else. Epsilon green and affordance
## teal are close behind. Those four already spend the project's entire
## hue budget on distinctions that a desaturated frame cannot make.
##
## Which is the actual argument for an achromatic navigation family. Not
## that grey is prettier, and not that the signage occupies some unused
## value -- it does not, its field sits right up beside EXIT green. It is
## that navigation carries its meaning in GLYPH and PLACEMENT, so it never
## asks the player for a distinction the colour channel is already out of
## room to make.
func _swatches() -> void:
	var w := 1500
	var h := 520
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.09, 0.10, 0.12))

	var rows := [
		["HAZARD  #e8541f", Color(0.91, 0.33, 0.12), "this will hurt you"],
		["SIGNAL  #39d7c8", Color(0.22, 0.84, 0.78), "this is a capability"],
		["EPSILON #57ff1f", Color(0.34, 1.00, 0.12), "Epsilon, nothing else"],
		["SEND    #ffd45c", Color(1.00, 0.83, 0.36), "leaves for the multiworld"],
		["HUD EXIT", Color(0.50, 1.00, 0.60), "zone_controller waypoint"],
		["HUD READY", Color(0.45, 1.00, 0.90), "zone_controller waypoint"],
		["HUD SENDING", Color(1.00, 0.90, 0.40), "zone_controller waypoint"],
		["HUD LOCKED", Color(0.72, 0.78, 0.85), "zone_controller waypoint"],
		["NAV FIELD #c9ced6", Color(0.788, 0.808, 0.839), "this batch"],
	]
	var top := 92
	var rh := 42
	for i in rows.size():
		var row: Array = rows[i]
		var c: Color = row[1]
		var v: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		var y := top + i * rh
		ArtBench.label(img, str(row[0]), Vector2i(14, y + 12),
				Color(0.80, 0.84, 0.88))
		img.fill_rect(Rect2i(300, y, 300, rh - 8), c)
		img.fill_rect(Rect2i(620, y, 300, rh - 8), Color(v, v, v))
		ArtBench.label(img, "LUMA %.3f" % v, Vector2i(940, y + 12),
				Color(0.86, 0.88, 0.92))
		ArtBench.label(img, str(row[2]), Vector2i(1090, y + 12),
				Color(0.52, 0.57, 0.63))

	ArtBench.label(img, "F  WHAT DESATURATION COSTS EACH COMMITTED COLOUR",
			Vector2i(14, 16), Color(1.0, 0.83, 0.36))
	ArtBench.label(img, "LEFT: THE COLOUR.   RIGHT: THE SAME COLOUR WITH HUE REMOVED.",
			Vector2i(14, 40), Color(0.72, 0.76, 0.80))
	ArtBench.label(img, "HUD EXIT 0.805 VS HUD READY 0.824 - TWO PERCENT APART. HUE IS DOING ALL THE WORK.",
			Vector2i(14, 64), Color(0.94, 0.62, 0.42))
	ArtBench.label(img, "THE SIGNAGE FIELD IS NOT A SPARE VALUE EITHER - IT SITS BESIDE EXIT GREEN.",
			Vector2i(14, h - 46), Color(0.72, 0.76, 0.80))
	ArtBench.label(img, "IT DOES NOT NEED ONE: ITS MEANING IS THE GLYPH AND WHERE IT IS BOLTED.",
			Vector2i(14, h - 24), Color(0.45, 0.72, 0.68))
	img.save_png("%s/F_collapse.png" % _out)
