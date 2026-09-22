extends SceneTree
## Batch 054 IN CONTEXT -- the Forest Temple kit assembled, in the engine.
##
##   godot --path godot -s _harness/ftview.gd -- <models> <out-dir>
##
## ## Why this frame and not six solos
##
## Six assets on six turntables prove six assets exist. They do not show
## whether the pack reads as ONE PLACE, which is the only question a
## theme pack is for. So this is a chamber: Production-grey shell, a 2.4
## x 3.2 opening in it, and the six pieces dressing that shell.
##
## THE GREY IS THE POINT. Every surface the player walks on, collides
## with or shoots through is drawn in flat grey here, because none of it
## is art's. The pack is what sits ON that: a door surround around an
## opening art did not cut, columns that stand clear of it, a relief on
## a wall art did not build, a torch, a switch housing on Batch 043's
## contract, and roots on a floor that was already there.
##
## ## The opening is re-checked HERE, on the imported result
##
## `build_forest_temple.py` gates the source geometry in Blender. That
## is not the same artefact as the `.glb` Godot loads, and an export or
## import that moved something would pass the Blender gate and still
## block the door. So the surround's imported AABB is measured against
## the engine's own `door_width` and `door_height` and the run FAILS if
## it intrudes. A check that only runs upstream of the export is a check
## with a gap in it exactly where the pipeline is.

const FOV := 52.0
## `assets/art_budgets.json` -> dimensions. Not art's numbers.
const DOOR_W := 2.4
const DOOR_H := 3.2
## The graze the Blender gate allows, for the same float reason: a
## lintel tangent at exactly 3.2 lands on 3.1999999999999997.
const GRAZE := 0.001

var _models: String
var _out: String
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <models-dir> <out-dir>")
	else:
		_models = a[0]
		_out = a[1]
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[ftview] FAIL: %s" % what)


func _stage() -> Array:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.30)
	var root := Node3D.new()
	view.add_child(root)
	var world := view.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		var env := world.environment
		# Cold overall, warm where the torch is. A temple that is warm
		# everywhere has no torch in it, only an orange filter.
		env.ambient_light_color = Color(0.58, 0.66, 0.70)
		env.ambient_light_energy = 0.30
		env.fog_enabled = true
		env.fog_density = 0.016
		env.fog_light_color = Color(0.20, 0.26, 0.24)
	# The torch pool, at the alcove, warm and short-range.
	var torch := OmniLight3D.new()
	torch.omni_range = 7.0
	torch.light_energy = 3.4
	torch.shadow_enabled = false
	torch.light_color = Color(1.0, 0.76, 0.46)
	root.add_child(torch)
	torch.global_position = Vector3(4.2, 1.9, -1.0)
	# Daylight down the shaft the opening leads to, cool and opposite.
	var shaft := OmniLight3D.new()
	shaft.omni_range = 16.0
	shaft.light_energy = 2.2
	shaft.shadow_enabled = false
	shaft.light_color = Color(0.74, 0.86, 0.80)
	root.add_child(shaft)
	shaft.global_position = Vector3(0.0, 3.0, -7.0)
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
	var node: Node3D = _bench.call("load_glb",
			"%s/batch054/forest_temple/%s.glb" % [_models, id])
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
	## 12 deep, opening centred at x = 0 in the z = -5 wall.
	_grey(root, Vector3(10.4, 0.2, 12.4), Vector3(0, -0.1, -0.2),
			Color(0.34, 0.35, 0.36))
	_grey(root, Vector3(10.4, 0.2, 12.4), Vector3(0, 3.7, -0.2),
			Color(0.30, 0.31, 0.33))
	_grey(root, Vector3(0.4, 3.6, 12.4), Vector3(-5.0, 1.8, -0.2))
	_grey(root, Vector3(0.4, 3.6, 12.4), Vector3(5.0, 1.8, -0.2))
	# The back wall, in three pieces, leaving DOOR_W x DOOR_H clear.
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
	## The six, placed where each one's own reason puts it.
	var surround := _put(root, "tp_ft_door_surround", Vector3(0, 0, -4.78))
	# Columns stand OFF the opening, clear of the approach: the pack
	# dresses the room, it does not narrow the route through it.
	_put(root, "tp_ft_column", Vector3(-2.7, 0, -3.4))
	_put(root, "tp_ft_column", Vector3(2.7, 0, -3.4))
	# The relief is a wall piece, so it goes on a wall, facing in.
	_put(root, "tp_ft_wall_relief", Vector3(-4.72, 0, -1.2), PI / 2.0)
	# The torch sits at reading height on the opposite wall, which is
	# what makes the room lit from one side rather than from nowhere.
	_put(root, "tp_ft_alcove_torch", Vector3(4.72, 1.5, -1.0), -PI / 2.0)
	# Batch 043's wall-switch contract: beside the door, at hand height.
	_put(root, "tp_ft_switch_housing", Vector3(1.82, 1.15, -4.74))
	# Roots have won the floor away from the walked line, not across it.
	_put(root, "tp_ft_root_mass", Vector3(-3.5, 0, 0.6), 0.4)
	_put(root, "tp_ft_root_mass", Vector3(3.6, 0, 1.8), -0.9)
	_put(root, "tp_ft_root_mass", Vector3(-1.4, 0, 2.9), 2.2)
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
	print("[ftview] surround: %d vertices measured against a %.2f x %.2f "
			% [counted, DOOR_W, DOOR_H] + "opening")
	if counted == 0:
		_fail("the imported surround carried no vertices to measure, so "
			+ "this check measured nothing and is not a PASS")
		return
	if depth > 0.0:
		_fail(("the imported surround reaches %.3f m into the opening at "
			+ "(%.3f, %.3f, %.3f)") % [depth, worst.x, worst.y, worst.z])
	else:
		print("[ftview] no vertex inside the opening -- clear by %.3f m"
				% GRAZE)


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
		print("[ftview] sabotage refused as it must: %s" % planted)


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
			+ "NOT runtime-bound, NOT owner-approved. Material treatment "
			+ "MISSING: painted in temple_ruin, which is not the pack's own.",
			Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, caption, Vector2i(16, 34),
			Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[ftview] %s.png" % name)


func _frame(eye: Vector3, look: Vector3, name: String,
		caption: String) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_shell(root)
	var surround := _dress(root)
	if name == "FT_approach":
		_check_opening(surround)
		# SABOTAGE. A check nobody has seen fail is a decoration. Shift
		# the surround 0.5 m sideways, which walks its jamb into the
		# opening, and require the check to say so.
		_sabotage(surround)
	await _capture(view, eye, look, name, caption)
	view.queue_free()
	await process_frame


func _run() -> void:
	# Eye height 1.7, standing in the chamber, looking at the way out.
	await _frame(Vector3(0.0, 1.7, 4.4), Vector3(0.0, 1.6, -5.0),
			"FT_approach",
			"Approach -- grey is Production's; the pack is what sits on it")
	# The wall the relief is on, from where a player would actually see
	# it: passing, not standing square to it.
	await _frame(Vector3(1.6, 1.7, 1.4), Vector3(-4.7, 1.5, -1.6),
			"FT_relief",
			"The split panel and a rooted column, seen in passing")
	# Approaching the opening from the far side, far enough back that
	# the JAMBS ARE IN FRAME. The first version stood 0.6 m off the wall
	# with an 82-degree horizontal field, so both jambs fell outside the
	# picture and the frame showed an empty room -- under a caption
	# claiming it showed the dressing clear of the opening. A frame that
	# does not contain the thing its caption is about is worse than no
	# frame.
	await _frame(Vector3(0.0, 1.7, -9.6), Vector3(0.0, 1.6, -2.0),
			"FT_threshold",
			"Through the 2.4 x 3.2 opening -- dressing clear of both jambs")
	# High three-quarter, from INSIDE: the whole arrangement, the roots
	# on the floor, and the walked line between them.
	#
	# The first version put this camera at (6.6, 5.4, 5.2), which is
	# outside the shell -- so the frame was the OUTSIDE of a grey box,
	# lit by nothing, with the whole kit behind it. A camera position is
	# a claim about where the viewer is standing and this one was wrong.
	await _frame(Vector3(3.9, 3.1, 4.4), Vector3(-0.7, 0.7, -2.2),
			"FT_chamber",
			"The chamber -- six pieces, one place, routes unchanged")
	if _problems.is_empty():
		print("[ftview] PASS -- %d frame(s), opening clear on the IMPORTED "
			% _made + "geometry")
		quit(0)
	else:
		for p in _problems:
			printerr("[ftview] %s" % p)
		push_error("ftview: %d problem(s)" % _problems.size())
		quit(1)
