extends SceneTree
## A THEME PACK in context -- the kit assembled, in the engine.
##
##   godot --path godot -s _harness/packview.gd -- <models> <out> <layout.json>
##
## ## Why this frame and not six solos
##
## Six assets on six turntables prove six assets exist. They do not show
## whether the pack reads as ONE PLACE, which is the only question a
## theme pack is for. So this is a chamber: Production-grey shell, a 2.4
## x 3.2 opening in it, and the pieces dressing that shell.
##
## THE GREY IS THE POINT. Every surface the player walks on, collides
## with or shoots through is drawn in flat grey here, because none of it
## is art's. The pack is what sits ON that.
##
## ## The shell is shared; the layout is not
##
## The shell, the gates, the captions and the opening check are the same
## for every pack, so they live here. WHERE THE PIECES GO IS ART and
## differs per pack, so it lives in `tools/content/packlayouts/<pack>.json`
## and this file reads it. There are eighteen packs in the first wave and
## sixty-three behind them; the alternative is eighty-one copies of one
## harness, which is eighty-one places for the next correction to miss.
##
## ## The opening is re-checked HERE, on the imported result
##
## The pack builders gate their source geometry in Blender through
## `packgates`. That is not the same artefact as the `.glb` Godot loads,
## and an export or import that moved something would pass the Blender
## gate and still block the door. So the surround's imported VERTICES are
## measured against the engine's own `door_width` and `door_height` and
## the run FAILS if any is inside the opening. A check that only runs
## upstream of the export is a check with a gap in it exactly where the
## pipeline is.

const FOV := 52.0
## `assets/art_budgets.json` -> dimensions. Not art's numbers.
const DOOR_W := 2.4
const DOOR_H := 3.2
## The graze the Blender gate allows, for the same float reason: a
## lintel tangent at exactly 3.2 lands on 3.1999999999999997.
const GRAZE := 0.001

var _models: String
var _out: String
var _layout: Dictionary
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		_fail("usage: -- <models-dir> <out-dir> <layout.json>")
	else:
		_models = a[0]
		_out = a[1]
		var text := FileAccess.get_file_as_string(a[2])
		if text == "":
			_fail("could not read the layout at %s" % a[2])
		else:
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				_layout = parsed
			else:
				_fail("%s is not a JSON object" % a[2])
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[packview] FAIL: %s" % what)


func _colour(from: Variant, fallback: Color) -> Color:
	if not (from is Array) or (from as Array).size() < 3:
		return fallback
	var a: Array = from
	return Color(a[0], a[1], a[2])


func _vec(from: Variant) -> Vector3:
	var a: Array = from
	return Vector3(a[0], a[1], a[2])


func _stage() -> Array:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.30)
	var root := Node3D.new()
	view.add_child(root)
	var light: Dictionary = _layout.get("light", {})
	var world := view.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		var env := world.environment
		env.ambient_light_color = _colour(light.get("ambient"),
				Color(0.62, 0.68, 0.72))
		env.ambient_light_energy = float(light.get("ambient_energy", 0.30))
		env.fog_enabled = true
		env.fog_density = float(light.get("fog", 0.016))
		env.fog_light_color = _colour(light.get("fog_color"),
				Color(0.20, 0.24, 0.26))
	# Lamps are the pack's, because how a place is lit is part of what it
	# is: a temple has one warm torch and a clock room has none.
	for entry: Dictionary in light.get("lamps", []):
		var lamp := OmniLight3D.new()
		lamp.omni_range = float(entry.get("range", 10.0))
		lamp.light_energy = float(entry.get("energy", 2.4))
		lamp.shadow_enabled = false
		lamp.light_color = _colour(entry.get("color"), Color(1, 1, 1))
		root.add_child(lamp)
		lamp.global_position = _vec(entry["at"])
	return [view, root]


func _grey(root: Node3D, size: Vector3, at: Vector3,
		tint := Color(0.40, 0.42, 0.43)) -> void:
	## PRODUCTION geometry. Flat, untextured, unmistakably not art's.
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1.0
	node.set_surface_override_material(0, mat)
	root.add_child(node)
	node.position = at


func _put(root: Node3D, id: String, at: Vector3, yaw := 0.0) -> Node3D:
	var node: Node3D = _bench.call("load_glb", "%s/%s/%s.glb"
			% [_models, _layout.get("models", ""), id])
	if node == null:
		_fail("could not load %s" % id)
		return null
	root.add_child(node)
	_bench.call("force_nearest", node)
	node.position = at
	node.rotation.y = yaw
	return node


func _shell(root: Node3D) -> void:
	## A chamber with a doorway in its back wall. 10 wide, 3.6 high,
	## 12 deep, opening centred at x = 0 in the z = -5 wall. THE SAME
	## SHELL FOR EVERY PACK -- it is Production's, and a pack that needs
	## its own room to look good does not read as a pack.
	_grey(root, Vector3(10.4, 0.2, 12.4), Vector3(0, -0.1, -0.2),
			Color(0.34, 0.35, 0.36))
	_grey(root, Vector3(10.4, 0.2, 12.4), Vector3(0, 3.7, -0.2),
			Color(0.30, 0.31, 0.33))
	_grey(root, Vector3(0.4, 3.6, 12.4), Vector3(-5.0, 1.8, -0.2))
	_grey(root, Vector3(0.4, 3.6, 12.4), Vector3(5.0, 1.8, -0.2))
	var jamb := (10.4 - DOOR_W) / 2.0
	_grey(root, Vector3(jamb, 3.6, 0.4),
			Vector3(-(DOOR_W / 2.0 + jamb / 2.0), 1.8, -5.0))
	_grey(root, Vector3(jamb, 3.6, 0.4),
			Vector3(DOOR_W / 2.0 + jamb / 2.0, 1.8, -5.0))
	_grey(root, Vector3(DOOR_W, 3.6 - DOOR_H, 0.4),
			Vector3(0.0, DOOR_H + (3.6 - DOOR_H) / 2.0, -5.0))
	# What the opening leads to, so it reads as a way through rather
	# than as a black rectangle painted on a wall.
	_grey(root, Vector3(DOOR_W + 1.2, 0.2, 5.0), Vector3(0, -0.1, -7.6),
			Color(0.30, 0.32, 0.31))
	_grey(root, Vector3(0.4, 3.6, 5.0), Vector3(-(DOOR_W / 2.0 + 0.8),
			1.8, -7.6))
	_grey(root, Vector3(0.4, 3.6, 5.0), Vector3(DOOR_W / 2.0 + 0.8,
			1.8, -7.6))
	# And the chamber's far end is a wall, not fog. A room left open to
	# the background reads as a set, and a bright rectangle where a wall
	# should be pulls the eye off everything the frame is about.
	_grey(root, Vector3(10.4, 3.6, 0.4), Vector3(0, 1.8, 6.0),
			Color(0.36, 0.37, 0.38))


func _dress(root: Node3D) -> Node3D:
	var surround: Node3D = null
	var want: String = _layout.get("surround", "")
	for entry: Dictionary in _layout.get("place", []):
		var node := _put(root, entry["id"], _vec(entry["at"]),
				deg_to_rad(float(entry.get("yaw", 0.0))))
		if node != null and entry["id"] == want:
			surround = node
	if surround == null:
		_fail("the layout names %s as its surround and nothing placed it"
				% want)
	return surround


func _check_opening(surround: Node3D, nudge := Vector3.ZERO) -> void:
	## The imported surround's VERTICES, measured against the opening.
	##
	## The Blender gate checked the source. This checks what came back
	## out of the exporter and through Godot's importer, which is a
	## different object, and it is the one the player meets.
	##
	## AN AABB CANNOT ANSWER THIS and the first version of this function
	## tried. A door surround's bounding box necessarily encloses the
	## doorway -- that is what a surround is -- so "the box covers the
	## opening" is true of a correct surround and of a solid slab alike.
	## The question is whether any GEOMETRY is inside the opening, and
	## only the vertices know.
	if surround == null:
		return
	var half := DOOR_W / 2.0
	var inv := surround.global_transform.affine_inverse()
	var worst := Vector3.ZERO
	var depth := 0.0
	var counted := 0
	for node in surround.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var to_local := inv * mi.global_transform
		for i in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p: Vector3 = to_local * v + nudge
				counted += 1
				if abs(p.x) >= half - GRAZE or p.y >= DOOR_H - GRAZE:
					continue
				if p.y <= GRAZE:
					continue   # the floor line is not an obstruction
				# How far INTO the opening this vertex reaches, from the
				# nearer jamb. The deepest one is the one worth naming.
				var into: float = half - abs(p.x)
				if into > depth:
					depth = into
					worst = p
	print("[packview] surround: %d vertices measured against a %.2f x %.2f "
			% [counted, DOOR_W, DOOR_H] + "opening")
	if counted == 0:
		_fail("the imported surround carried no vertices to measure, so "
			+ "this check measured nothing and is not a PASS")
		return
	if depth > 0.0:
		_fail(("the imported surround reaches %.3f m into the opening at "
			+ "(%.3f, %.3f, %.3f)") % [depth, worst.x, worst.y, worst.z])
	else:
		print("[packview] no vertex inside the opening -- clear by %.3f m"
				% GRAZE)


func _capture(view: SubViewport, eye: Vector3, look: Vector3,
		name: String, caption: String) -> void:
	var cam := Camera3D.new()
	cam.fov = FOV
	view.add_child(cam)
	cam.global_position = eye
	cam.look_at(look, Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	_bench.call("label", image, "PROPOSAL -- imported and fit-checked, "
			+ "NOT runtime-bound, NOT owner-approved. "
			+ String(_layout.get("caption_note", "")),
			Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, caption, Vector2i(16, 34),
			Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[packview] %s.png" % name)


func _frame(entry: Dictionary) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_shell(root)
	var surround := _dress(root)
	if bool(entry.get("check_opening", false)):
		_check_opening(surround)
		# SABOTAGE. A check nobody has seen fail is a decoration. Shift
		# the surround 0.5 m sideways, which walks its jamb into the
		# opening, and require the check to say so.
		_sabotage(surround)
	await _capture(view, _vec(entry["eye"]), _vec(entry["look"]),
			entry["name"], entry.get("caption", ""))
	view.queue_free()
	await process_frame


func _sabotage(surround: Node3D) -> void:
	var before := _problems.size()
	_check_opening(surround, Vector3(0.5, 0.0, 0.0))
	if _problems.size() == before:
		_fail("the opening check did not notice a surround shifted 0.5 m "
			+ "into the doorway, so it cannot notice a real one")
	else:
		# The planted failure is not this run's failure. Take it back out
		# and say what it proved.
		var planted: String = _problems.pop_back()
		print("[packview] sabotage refused as it must: %s" % planted)


func _run() -> void:
	if not _problems.is_empty():
		for p in _problems:
			printerr("[packview] %s" % p)
		push_error("packview: %d problem(s)" % _problems.size())
		quit(1)
		return
	var checked := false
	for entry: Dictionary in _layout.get("shots", []):
		checked = checked or bool(entry.get("check_opening", false))
		await _frame(entry)
	if not checked:
		_fail("no shot asked for the opening check, so the imported "
			+ "geometry was never measured and this run proves nothing "
			+ "about the doorway")
	if _problems.is_empty():
		print("[packview] PASS -- %d frame(s), opening clear on the "
			% _made + "IMPORTED geometry")
		quit(0)
	else:
		for p in _problems:
			printerr("[packview] %s" % p)
		push_error("packview: %d problem(s)" % _problems.size())
		quit(1)
