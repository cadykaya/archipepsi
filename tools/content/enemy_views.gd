extends SceneTree
## A10.6 -- role-by-role readiness views, at ONE distance.
##
##   godot --path godot -s _harness/enemyview.gd -- <models> <out-dir>
##
## Three passes over the same ten roles, and the shared distance is the
## point of all three: an enemy roster is not ten pictures, it is one
## comparison. Every frame here is shot from the same camera at the
## same height, so a silhouette that only works when it fills the frame
## is a silhouette that does not work.
##
## * **Runtime light** -- what a player sees, under the shipped Zone's
##   ambient 0.35 and fog 0.012 with no directional light.
## * **Silhouette** -- flat black on light, which is the only honest
##   test of "can you tell a sniper from a charger across a dark room".
## * **Clay** -- form without material, so a shape problem cannot hide
##   behind a texture.
##
## The frames are stamped with what the role IS and what it is NOT: an
## unsupported role can be art-ready without being spawnable, and A10.6
## says to state both facts.

const FOV := 48.0
## Roughly where a player meets one: far enough that the silhouette has
## to do the work, near enough to read a muzzle.
const RANGE := 7.5
const EYE := 1.6

var _models: String
var _out: String
var _bench: GDScript
var _manifest := {}
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
	printerr("[enemyview] FAIL: %s" % what)


func _shot(role: String, mode: String) -> void:
	var id := "enemy_role_%s" % role
	var entry: Dictionary = _manifest[id]
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.35)
	var root := Node3D.new()
	view.add_child(root)
	var node: Node3D = _bench.call("load_glb",
			"%s/batch030/enemies/%s.glb" % [_models, id])
	if node == null:
		_fail("could not load %s" % id)
		view.queue_free()
		return
	root.add_child(node)
	_bench.call("force_nearest", node)
	# A flying role is LIFTED by the runtime; the mesh is authored on
	# the floor. Standing it at its hover height is what a player sees.
	var hover := float(entry.get("hover_height_m", 0.0))
	node.position = Vector3(0, hover, 0)

	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(30, 0.2, 30)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = (Color(0.86, 0.87, 0.89) if mode == "silhouette"
			else Color(0.30, 0.31, 0.33))
	gmat.roughness = 0.98
	ground.set_surface_override_material(0, gmat)
	root.add_child(ground)
	ground.position = Vector3(0, -0.11, 0)

	var world := view.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		var env := world.environment
		if mode == "silhouette":
			env.ambient_light_color = Color(1, 1, 1)
			env.ambient_light_energy = 1.6
			env.fog_enabled = false
			env.background_color = Color(0.86, 0.87, 0.89)
		else:
			env.ambient_light_color = Color(0.72, 0.77, 0.82)
			env.ambient_light_energy = 0.35
			env.fog_enabled = true
			env.fog_density = 0.012
			env.fog_light_color = Color(0.30, 0.33, 0.38)
	match mode:
		"silhouette":
			_bench.call("apply_override", node,
				_bench.call("flat_material", Color(0.04, 0.04, 0.05)))
		"clay":
			_bench.call("apply_override", node,
				_bench.call("clay_material"))
			_bench.call("add_lights", root, 1.5)
		_:
			for at: Vector3 in [Vector3(3.0, 3.6, 2.6),
					Vector3(-3.2, 2.8, -2.2)]:
				var lamp := OmniLight3D.new()
				lamp.omni_range = 12.0
				lamp.light_energy = 2.6
				lamp.shadow_enabled = false
				lamp.light_color = Color(0.98, 0.95, 0.88)
				root.add_child(lamp)
				lamp.global_position = at

	# ONE CAMERA FOR ALL TEN. Not framed per asset: framing each to fill
	# the frame is what makes a roster sheet lie about scale.
	var cam := Camera3D.new()
	cam.fov = FOV
	view.add_child(cam)
	cam.global_position = Vector3(RANGE * 0.72, EYE, RANGE * 0.72)
	cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	var placeable := bool(entry.get("placeable_today", false))
	_bench.call("label", image,
		"CANDIDATE -- fit-checked against ENEMY_ENVELOPES, "
		+ ("SPAWNABLE today" if placeable
			else "NOT spawnable: ENEMY_ARCHETYPES is still melee/ranged/brute"),
		Vector2i(16, 16),
		Color(0.5, 1.0, 0.6) if placeable else Color(1, 0.86, 0.3))
	_bench.call("label", image,
		"%s -- %s" % [role, str(entry.get("reads_as", ""))],
		Vector2i(16, 34), Color(0.82, 0.84, 0.88)
			if mode != "silhouette" else Color(0.1, 0.1, 0.12))
	_bench.call("label", image,
		"%s, at %.1f m, one camera for all ten" % [mode, RANGE],
		Vector2i(16, 52), Color(0.6, 0.63, 0.68))
	var name := "%s_%s" % [role, mode]
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[enemyview] %s.png" % name)
	view.queue_free()


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch030/enemies/manifest.json" % _models)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("no batch030 manifest")
		quit(1)
		return
	_manifest = parsed
	var roles := []
	for id: String in _manifest:
		roles.append(str(id).replace("enemy_role_", ""))
	roles.sort()
	for mode: String in ["runtime", "silhouette", "clay"]:
		for role: String in roles:
			await _shot(role, mode)
	if _problems.is_empty():
		print("[enemyview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
