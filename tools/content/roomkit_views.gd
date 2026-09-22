extends SceneTree
## Batch 048, photographed in the engine that will show it.
##
##   godot --path godot -s _harness/roomview.gd -- <models> <out-dir>
##
## Shipped-Zone lighting: ambient 0.35, fog 0.012, shadowless omnis at
## range 14, no directional light.
##
## Fourteen solos plus three ROOM frames -- one per room, with the
## Production geometry each kit fits against drawn in plain grey, so a
## fit is something the picture shows rather than something the handoff
## claims. A06.6 asks for the moving art checked at its closest
## approach, and that is what the Passing Platforms frame is: both
## decks at the rendezvous, 0.2 m apart, with the transfer edges on
## them.

const FOV := 48.0
var _models: String
var _out: String
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0

const SOLO := [
	["pp_lift_guide", Vector3(2.2, 1.9, 2.4), Vector3(0.4, 1.0, 0),
		"Lift guide -- masts, ties, rope and a counterweight in its channel"],
	["pp_shuttle_guide", Vector3(1.9, 1.3, 2.1), Vector3(0, 0.1, 0),
		"Shuttle guide -- a SCREW, not a rope: the two drives differ"],
	["pp_transfer_edge", Vector3(3.6, 2.3, 3.2), Vector3(0, 0.5, -0.3),
		"Transfer edge -- rail at Production's 1.10; nothing crosses the edge"],
	["pp_call_post", Vector3(1.8, 1.6, 1.8), Vector3(0, 0.9, 0),
		"Call post -- call, stop and direction, each its own node"],
	["pp_recovery_mark", Vector3(3.4, 2.6, 3.4), Vector3(0, 0, 0),
		"Recovery floor -- a landing pad, not a hazard border"],
	["cf_gunner_mount", Vector3(3.0, 2.0, 3.2), Vector3(0, 0.5, 0),
		"Gunner emplacement -- on the ranged envelope, open at the back"],
	["cf_lane_mark", Vector3(1.9, 1.3, 2.1), Vector3(0.3, 0, 0),
		"Lane marking -- RIBBED, so it reads without colour; 0.04 m tall"],
	["cf_alcove_frame", Vector3(4.0, 2.4, 4.0), Vector3(0, 1.2, 0),
		"Safe alcove -- a deep reveal is what says 'in here, not there'"],
	["cf_shutter_track", Vector3(3.4, 2.2, 3.4), Vector3(0, 0.6, 0),
		"Shutter track -- eight named pips, one per OPEN_SECOND. No clock."],
	["cf_release_bolt", Vector3(1.7, 1.2, 1.8), Vector3(0, 0.25, 0),
		"Release bolt -- a mechanical commitment, unreadable as a countdown"],
	["uw_plate_frame", Vector3(4.0, 2.6, 4.0), Vector3(0, 0.3, 0),
		"HEAVY plate -- three discrete class marks; no dial anywhere"],
	["uw_drive_housing", Vector3(3.6, 2.4, 3.8), Vector3(0.6, 0.4, 1.6),
		"Guided drive -- lever and rail, both OUTSIDE the crate's corridor"],
	["uw_applicator", Vector3(1.9, 1.5, 2.0), Vector3(0, 0.65, 0),
		"Applicator -- the housing; LIGHTENED itself is Production's hook"],
	["uw_return_rail", Vector3(3.6, 2.2, 3.4), Vector3(0, 0.8, 0),
		"Return gate -- a drop bar, and deliberately not a stair"],
]


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
	printerr("[roomview] FAIL: %s" % what)


func _stage() -> Array:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.35)
	var root := Node3D.new()
	view.add_child(root)
	var world := view.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		var env := world.environment
		env.ambient_light_color = Color(0.72, 0.77, 0.82)
		env.ambient_light_energy = 0.35
		env.fog_enabled = true
		env.fog_density = 0.012
		env.fog_light_color = Color(0.30, 0.33, 0.38)
	for at: Vector3 in [Vector3(4.0, 4.8, 3.4), Vector3(-4.2, 3.6, -3.0)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 14.0
		lamp.light_energy = 2.8
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at
	return [view, root]


func _ground(root: Node3D, at := Vector3(0, -0.11, 0),
		size := Vector3(30, 0.2, 30)) -> void:
	var node := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = size
	node.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.31, 0.33)
	mat.roughness = 0.95
	node.set_surface_override_material(0, mat)
	root.add_child(node)
	node.position = at


func _grey(root: Node3D, size: Vector3, at: Vector3,
		tint := Color(0.42, 0.44, 0.47)) -> void:
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


func _put(root: Node3D, id: String, at: Vector3, yaw := 0.0) -> void:
	var node: Node3D = _bench.call("load_glb",
			"%s/batch048/roomkits/%s.glb" % [_models, id])
	if node == null:
		_fail("could not load %s" % id)
		return
	root.add_child(node)
	_bench.call("force_nearest", node)
	node.position = at
	node.rotation.y = yaw


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
	_bench.call("label", image, "CANDIDATE -- imported and fit-checked, "
			+ "NOT runtime-bound, NOT owner-approved",
			Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, caption, Vector2i(16, 34),
			Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[roomview] %s.png" % name)
	view.queue_free()


## A06.6 -- the two decks at their CLOSEST APPROACH, which is the only
## moment the 0.2 m hop is a question.
func _rendezvous() -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_ground(root, Vector3(0, -0.11, 0), Vector3(40, 0.2, 40))
	# Their two decks, 4 x 0.4 x 4, with GAP 0.2 between them. The
	# vertical carrier's top lands at TRANSFER_Y 4.0; the horizontal
	# one rides at H_RAIL_Y 3.6 so its top lands level.
	_grey(root, Vector3(4, 0.4, 4), Vector3(0, 3.8, 0))
	_grey(root, Vector3(4, 0.4, 4), Vector3(0, 3.8, 4.2),
		Color(0.26, 0.28, 0.33))
	_put(root, "pp_transfer_edge", Vector3(0, 4.0, 2.0))
	_put(root, "pp_transfer_edge", Vector3(0, 4.0, 2.2), PI)
	# The call post stands ON the shuttle's deck, where a rider uses it.
	_put(root, "pp_call_post", Vector3(1.4, 4.0, 5.4), PI)
	# The lift's masts run the well BELOW the transfer, which is what
	# they do: a first cut hung a stack of them in mid-air beside the
	# decks and the frame read as scaffolding nobody had finished.
	for i in 2:
		_put(root, "pp_lift_guide", Vector3(-2.9, 1.8 + float(i) * 2.0, 0))
	# CLOSE, and level with the hop. The rendezvous is 0.2 m wide; a
	# frame shot from thirty metres up cannot show it.
	await _capture(view, Vector3(5.6, 5.8, 8.8), Vector3(0, 4.0, 2.1),
		"pp_rendezvous",
		"A06.6 closest approach -- their two decks in grey, 0.2 m apart, "
		+ "with the transfer edges on them")


func _lane() -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_ground(root)
	# The lane, LANE_HALF 1.5 either side, and the receiver at -7.0.
	_grey(root, Vector3(0.5, 2.2, 14.0), Vector3(-1.75, 1.1, 0))
	_grey(root, Vector3(0.5, 2.2, 14.0), Vector3(1.75, 1.1, 0))
	_grey(root, Vector3(1.4, 1.2, 0.6), Vector3(0, 0.85, -7.0),
		Color(0.26, 0.28, 0.33))
	for i in 5:
		_put(root, "cf_lane_mark", Vector3(1.5, 0, -4.0 + float(i) * 2.0))
		_put(root, "cf_lane_mark", Vector3(-1.5, 0, -4.0 + float(i) * 2.0),
			PI)
	_put(root, "cf_gunner_mount", Vector3(0, 1.0, 7.5), PI)
	# The alcove opens ONTO the lane, so its mouth faces +x across it.
	_put(root, "cf_alcove_frame", Vector3(-2.4, 0, -5.0), -PI * 0.5)
	await _capture(view, Vector3(7.6, 6.2, -11.4), Vector3(0, 0.9, 0.5),
		"cf_lane",
		"The bait lane -- their lane walls and receiver in grey, the "
		+ "ribbed edge marking at 0.04 m")


func _switch() -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_ground(root)
	# Their plate at RECESS_Z 5.6, their crate parked at PARK_Z 1.0.
	_grey(root, Vector3(2.4, 0.12, 2.4), Vector3(0, 0.06, 5.6))
	_grey(root, Vector3(2.0, 1.0, 2.0), Vector3(0, 0.5, 1.0),
		Color(0.26, 0.28, 0.33))
	_put(root, "uw_plate_frame", Vector3(0, 0, 5.6))
	_put(root, "uw_drive_housing", Vector3(0, 0, 1.0))
	_put(root, "uw_applicator", Vector3(-2.6, 0, 2.4))
	_put(root, "uw_return_rail", Vector3(4.5, 0, 3.4), PI * 0.5)
	await _capture(view, Vector3(7.2, 4.8, -3.4), Vector3(0.2, 0.7, 3.2),
		"uw_switch",
		"The switch room -- their plate and crate in grey; the drive's "
		+ "rail runs BESIDE the corridor, never through it")


func _run() -> void:
	for raw: Variant in SOLO:
		var sdata: Array = raw
		var staged := _stage()
		var view: SubViewport = staged[0]
		var root: Node3D = staged[1]
		_ground(root, Vector3(0, -0.11, 0), Vector3(24, 0.2, 24))
		_put(root, str(sdata[0]), Vector3.ZERO)
		await _capture(view, sdata[1], sdata[2], str(sdata[0]),
			str(sdata[3]))
	await _rendezvous()
	await _lane()
	await _switch()
	if _problems.is_empty():
		print("[roomview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
