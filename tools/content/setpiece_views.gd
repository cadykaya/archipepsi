extends SceneTree
## Batch 045, photographed in the engine that will show it.
##
##   godot --path godot -s _harness/setview.gd -- <models> <out-dir>
##
## Shipped-Zone lighting, not a studio: `ZoneBuilder`'s ambient 0.35 and
## fog 0.012, shadowless omnis at range 12.0, and no `DirectionalLight3D`,
## because a built Zone has none. A setpiece that only reads under a key
## light is a setpiece that does not read.
##
## Each frame is stamped with what it is. These are CANDIDATES: imported
## and fit-checked, not runtime-bound and not owner-approved.

const EYE := 1.60
const FOV := 48.0
#: (id, camera, target, caption)
const SHOTS := [
	["sp_skiff_deck", Vector3(5.2, 2.6, 5.6), Vector3(0, 0.35, 0),
		"Blindside skiff -- open on the dock sides, guarded at the ends"],
	["sp_skiff_deck_bare", Vector3(5.2, 2.6, 5.6), Vector3(0, 0.35, 0),
		"Bare hull -- the same deck with no end guards, for the fitted ones"],
	["sp_hoist_car", Vector3(5.0, 2.8, 5.0), Vector3(0, 0.35, 0),
		"Passing Platforms hoist -- the structure runs UP"],
	["sp_crossing_carrier", Vector3(5.0, 2.4, 5.0), Vector3(0, 0.2, 0),
		"Passing Platforms crossing carrier -- a flatbed, not a cage"],
	["sp_receiver_hood", Vector3(2.8, 2.0, 3.4), Vector3(0, 0.9, 0),
		"Counterfire receiver -- the hood narrows toward its mouth"],
	["sp_shutter_leaf", Vector3(2.6, 1.4, 2.4), Vector3(0, 0, 0),
		"Counterfire shutter leaf -- 0.4 x 2.6 x 2.4, ribbed"],
	["sp_lane_screen", Vector3(2.6, 1.8, 2.6), Vector3(0, 0.7, 0),
		"Counterfire lane screen -- chest high, with a sight slot"],
	["sp_weight_plate", Vector3(3.0, 2.2, 3.0), Vector3(0, 0.1, 0),
		"Unweighted sensor plate -- 2.4 x 0.12 x 2.4"],
	["sp_ballast_crate", Vector3(3.2, 2.2, 3.2), Vector3(0, 0.5, 0),
		"Unweighted crate -- 1.0 m tall in EVERY state"],
	["sp_dock_stand", Vector3(2.0, 1.7, 2.0), Vector3(0, 0.6, 0),
		"Blindside dock stand -- both directions, with a reason panel"],
]

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
	printerr("[setview] FAIL: %s" % what)


func _shot(id: String, eye: Vector3, look: Vector3, caption: String) -> void:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.35)
	var root := Node3D.new()
	view.add_child(root)
	var node: Node3D = _bench.call("load_glb",
			"%s/batch045/setpieces/%s.glb" % [_models, id])
	if node == null:
		_fail("could not load %s" % id)
		return
	root.add_child(node)
	_bench.call("force_nearest", node)

	# A ground plane, so nothing floats in a void and the eye has a scale.
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(24, 0.2, 24)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.30, 0.31, 0.33)
	gmat.roughness = 0.95
	ground.set_surface_override_material(0, gmat)
	root.add_child(ground)
	ground.global_position = Vector3(0, -0.11, 0)

	var world := view.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		var env := world.environment
		env.ambient_light_color = Color(0.72, 0.77, 0.82)
		env.ambient_light_energy = 0.35
		env.fog_enabled = true
		env.fog_density = 0.012
		env.fog_light_color = Color(0.30, 0.33, 0.38)
	for at: Vector3 in [Vector3(3.4, 4.2, 3.0), Vector3(-3.6, 3.4, -2.6)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 12.0
		lamp.light_energy = 2.6
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at

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
	if image.save_png("%s/%s.png" % [_out, id]) != OK:
		_fail("could not write %s" % id)
	else:
		_made += 1
		print("[setview] %s.png" % id)
	view.queue_free()


func _run() -> void:
	for raw: Variant in SHOTS:
		var s: Array = raw
		await _shot(str(s[0]), s[1], s[2], str(s[3]))
	if _problems.is_empty():
		print("[setview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
