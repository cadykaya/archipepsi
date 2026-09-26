extends SceneTree
## A09.6 -- the three-view evidence strip, and two more.
##
##   godot --path godot -s _harness/connview.gd -- <models> <out-dir>
##
## A09.6 asks for source, connecting route and destination carrying the
## SAME relationship ID, plus an unpowered/deferred state and a reverse
## traversal view -- and it adds the condition that matters:
##
##   "no private lighting or geometry change to make the connection
##    look obvious"
##
## So every frame in this file uses the SAME lighting rig, the same
## shipped-Zone ambient 0.35 and fog 0.012, and the same geometry. The
## unpowered frame differs from the powered one ONLY in which nodes are
## tinted. Nothing is moved, added or relit to make a point.
##
## The relationship ID is written by the CAPTION, not by the asset:
## `plaque_id_field` and `label_field` are blank plates for a runtime to
## populate, and a baked identifier would be the thing A09.3 warns
## against. The caption is this harness talking, and says so.

const FOV := 52.0
const EYE := 1.6
const RELATIONSHIP := "R-14"

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
	printerr("[connview] FAIL: %s" % what)


## ONE RIG, every frame. A09.6's condition, held structurally: there is
## no per-shot lighting argument because there is only one function.
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
	for at: Vector3 in [Vector3(3.2, 3.6, 2.4), Vector3(-3.4, 3.0, -2.0)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 18.0
		lamp.light_energy = 3.4
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at
	return [view, root]


func _wall(root: Node3D, size: Vector3, at: Vector3) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.38, 0.41)
	mat.roughness = 1.0
	node.set_surface_override_material(0, mat)
	root.add_child(node)
	node.position = at


func _put(root: Node3D, id: String, at: Vector3, yaw := 0.0) -> Node3D:
	var node: Node3D = _bench.call("load_glb",
			"%s/batch049/connect/%s.glb" % [_models, id])
	if node == null:
		_fail("could not load %s" % id)
		return null
	root.add_child(node)
	_bench.call("force_nearest", node)
	node.position = at
	node.rotation.y = yaw
	return node


func _run_of(root: Node3D, at: Vector3, count: int, yaw := 0.0) -> void:
	for i in count:
		var node: Node3D = _bench.call("load_glb",
			"%s/batch043/machinery/mach_conduit_run.glb" % _models)
		if node == null:
			_fail("could not load mach_conduit_run")
			return
		root.add_child(node)
		_bench.call("force_nearest", node)
		node.position = at + Vector3(cos(yaw), 0, -sin(yaw)) * (2.0 * i)
		node.rotation.y = yaw


## Tint the state bands, and ONLY the state bands. This is a preview
## tint: `ContentInstantiator` performs no material replacement, so it
## is a demonstration that the bands are addressable, not a claim about
## runtime behaviour. Every frame says so.
var _tinted := 0


func _energise(node: Node, lit: bool) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (
				str(child.name).to_lower().contains("band")
				or str(child.name).begins_with("state_")):
			_tinted += 1
			var mat := StandardMaterial3D.new()
			if lit:
				# A LIT BAND, not a light box. At emission 2.2 the
				# first strip blew every band to flat white and the
				# channel behind it disappeared -- which is the
				# opposite of showing that the state registers with
				# the run.
				mat.albedo_color = Color(0.22, 0.48, 0.33)
				mat.emission_enabled = true
				mat.emission = Color(0.40, 0.92, 0.60)
				mat.emission_energy_multiplier = 0.75
			else:
				mat.albedo_color = Color(0.22, 0.24, 0.26)
			(child as MeshInstance3D).material_override = mat
		_energise(child, lit)


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
	_bench.call("label", image,
		"CANDIDATE -- band tint is a PREVIEW of addressability, not "
		+ "runtime behaviour. Same rig in every frame.",
		Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, caption, Vector2i(16, 34),
		Color(0.82, 0.84, 0.88))
	_bench.call("label", image,
		"relationship " + RELATIONSHIP + " -- written by this harness; "
		+ "the plaque's own field is blank for a runtime to populate",
		Vector2i(16, 52), Color(0.6, 0.63, 0.68))
	print("[connview] %s: %d band node(s) tinted" % [name, _tinted])
	_tinted = 0
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[connview] %s.png" % name)
	view.queue_free()


## The source end: a wall, a commitment, a plaque and a run leaving.
func _build_source(root: Node3D, lit: bool) -> void:
	_wall(root, Vector3(10, 3.2, 0.3), Vector3(0, 1.6, 1.2))
	_wall(root, Vector3(12, 0.2, 8), Vector3(0, -0.1, -2))
	var runs: Array[Node3D] = []
	for i in 3:
		var node: Node3D = _bench.call("load_glb",
			"%s/batch043/machinery/mach_conduit_run.glb" % _models)
		if node == null:
			continue
		root.add_child(node)
		_bench.call("force_nearest", node)
		node.rotation.y = PI
		node.position = Vector3(-3.0 + float(i) * 2.0, 1.4, 0.97)
		runs.append(node)
	var dial := _put(root, "conn_set_dial", Vector3(-1.5, 1.05, 0.98))
	var seal := _put(root, "conn_repair_seal", Vector3(-3.0, 1.05, 0.98))
	var paddle := _put(root, "conn_hold_paddle", Vector3(-0.1, 0.35, 0.98))
	var plaque := _put(root, "conn_id_plaque", Vector3(1.9, 2.15, 0.98))
	_put(root, "conn_relay_cabinet", Vector3(3.6, 0, 0.7))
	for n: Node3D in runs:
		_energise(n, lit)
	if plaque != null:
		_energise(plaque, lit)


func _build_route(root: Node3D, lit: bool) -> void:
	_wall(root, Vector3(0.6, 3.2, 10), Vector3(1.6, 1.6, 0))
	_wall(root, Vector3(12, 0.2, 12), Vector3(0, -0.1, 0))
	var pieces: Array[Node3D] = []
	for i in 3:
		var node: Node3D = _bench.call("load_glb",
			"%s/batch043/machinery/mach_conduit_run.glb" % _models)
		if node == null:
			continue
		root.add_child(node)
		_bench.call("force_nearest", node)
		node.rotation.y = -PI * 0.5
		node.position = Vector3(1.21, 1.4, -3.0 + float(i) * 2.0)
		pieces.append(node)
	var elbow := _put(root, "conn_run_elbow", Vector3(1.21, 1.4, 3.2),
		-PI * 0.5)
	var tee := _put(root, "conn_run_tee", Vector3(1.21, 1.4, -4.4),
		-PI * 0.5)
	var wallpass := _put(root, "conn_wall_pass", Vector3(1.6, 1.5, 0.0),
		-PI * 0.5)
	_put(root, "conn_junction_box", Vector3(1.24, 0.9, 1.4), -PI * 0.5)
	for n in [elbow, tee, wallpass]:
		if n != null:
			_energise(n, lit)
	for n: Node3D in pieces:
		_energise(n, lit)


func _build_destination(root: Node3D, lit: bool) -> void:
	_wall(root, Vector3(10, 3.2, 0.3), Vector3(0, 1.6, 1.2))
	_wall(root, Vector3(12, 0.2, 8), Vector3(0, -0.1, -2))
	var runs: Array[Node3D] = []
	for i in 2:
		var node: Node3D = _bench.call("load_glb",
			"%s/batch043/machinery/mach_conduit_run.glb" % _models)
		if node == null:
			continue
		root.add_child(node)
		_bench.call("force_nearest", node)
		node.rotation.y = PI
		node.position = Vector3(-2.6 + float(i) * 2.0, 1.4, 0.97)
		runs.append(node)
	var reader := _put(root, "conn_reader_panel", Vector3(0.4, 1.05, 0.98))
	var plaque := _put(root, "conn_id_plaque", Vector3(-2.2, 2.15, 0.98))
	_put(root, "conn_flag_ack", Vector3(2.0, 0.95, 0.8))
	_put(root, "conn_breaker", Vector3(2.9, 1.05, 0.98))
	_put(root, "conn_gauge", Vector3(-1.0, 1.15, 0.98))
	_put(root, "conn_service_stack", Vector3(3.8, 0, 0.4))
	for n in [reader, plaque]:
		if n != null:
			_energise(n, lit)
	for n: Node3D in runs:
		_energise(n, lit)


#: (id, camera, target, caption). One backdrop, same rig.
const SOLO := [
	["conn_run_elbow", Vector3(1.5, 1.2, 1.5), Vector3(0.2, 0.25, 0.2),
		"Elbow -- the band turns the corner at the run's own face height"],
	["conn_run_tee", Vector3(1.7, 1.3, 1.7), Vector3(0, 0.25, 0.2),
		"Tee -- two declared bands, so a fork can show which way it went"],
	["conn_junction_box", Vector3(1.5, 1.2, 1.5), Vector3(0, 0.4, 0),
		"Junction box -- four ports, a lid and terminals worth opening for"],
	["conn_wall_pass", Vector3(1.4, 1.1, 1.4), Vector3(0, 0.2, 0),
		"Wall penetration -- the piece that makes two rooms one installation"],
	["conn_reader_panel", Vector3(1.3, 0.9, 1.3), Vector3(0, 0.25, 0),
		"Reader -- blank label field, four state nodes, nothing baked"],
	["conn_set_dial", Vector3(0.9, 0.7, 0.9), Vector3(0, 0.17, 0),
		"PERSISTENT -- a detent ring: something that holds a position"],
	["conn_hold_paddle", Vector3(1.4, 1.1, 1.4), Vector3(0, 0.5, 0),
		"HELD -- a visible spring and a stop: it wants to come back"],
	["conn_repair_seal", Vector3(1.5, 0.9, 1.5), Vector3(0, 0.17, 0),
		"PERMANENT -- a lever behind a frangible tab; using it breaks a thing"],
	["conn_id_plaque", Vector3(1.4, 1.0, 1.4), Vector3(0, 0.22, 0),
		"Plaque -- the SAME asset at both ends; nav_blade bolts to blade_seat"],
	["conn_flag_ack", Vector3(1.2, 1.0, 1.2), Vector3(0, 0.4, 0),
		"Flag -- two positions, no third, no animation"],
	["conn_breaker", Vector3(1.1, 0.9, 1.1), Vector3(0, 0.3, 0),
		"Breaker -- handle position IS the state; window shows which"],
	["conn_gauge", Vector3(0.9, 0.6, 0.9), Vector3(0, 0.15, 0),
		"Gauge -- a continuous read, which here is the right instrument"],
	["conn_relay_cabinet", Vector3(2.6, 2.0, 2.6), Vector3(0, 1.0, 0),
		"Relay cabinet -- nonblocking: 0.9 m of floor, nothing to stand on"],
	["conn_service_stack", Vector3(2.8, 2.2, 2.8), Vector3(0, 1.2, 0),
		"Service stack -- the generator end of the same installation"],
]


func _solo(id: String, eye: Vector3, look: Vector3,
		caption: String) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_wall(root, Vector3(12, 0.2, 12), Vector3(0, -0.11, 0))
	var node := _put(root, id, Vector3.ZERO)
	if node == null:
		view.queue_free()
		return
	_energise(node, true)
	await _capture(view, eye, look, id, caption)


func _run() -> void:
	for raw: Variant in SOLO:
		var sdata: Array = raw
		await _solo(str(sdata[0]), sdata[1], sdata[2], str(sdata[3]))

	# 1. SOURCE
	var staged := _stage()
	_build_source(staged[1], true)
	await _capture(staged[0], Vector3(-1.9, EYE, -4.1),
		Vector3(-1.4, 1.15, 1.0), "a_source",
		"SOURCE -- the three commitments, the plaque, and the run leaving")

	# 2. ROUTE
	staged = _stage()
	_build_route(staged[1], true)
	await _capture(staged[0], Vector3(-2.8, EYE, -3.6),
		Vector3(1.1, 1.3, 0.2), "b_route",
		"ROUTE -- elbow, tee and the wall penetration that makes two "
		+ "rooms one installation")

	# 3. DESTINATION
	staged = _stage()
	_build_destination(staged[1], true)
	await _capture(staged[0], Vector3(-0.2, EYE, -4.3),
		Vector3(0.2, 1.15, 1.0), "c_destination",
		"DESTINATION -- reader, the SAME plaque, and the local "
		+ "acknowledgments")

	# 4. UNPOWERED. Identical geometry, identical rig, identical camera.
	staged = _stage()
	_build_destination(staged[1], false)
	await _capture(staged[0], Vector3(-0.2, EYE, -4.3),
		Vector3(0.2, 1.15, 1.0), "d_destination_unpowered",
		"UNPOWERED -- the same frame as (c). Only the band tint differs: "
		+ "nothing moved, nothing relit")

	# 5. REVERSE TRAVERSAL: the route, looked back along.
	staged = _stage()
	_build_route(staged[1], true)
	await _capture(staged[0], Vector3(-2.6, EYE, 4.4),
		Vector3(1.1, 1.3, -0.6), "e_reverse",
		"REVERSE -- the same route from the far end; the branch reads "
		+ "from both directions or it reads from neither")

	if _problems.is_empty():
		print("[connview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
