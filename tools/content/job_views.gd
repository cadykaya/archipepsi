extends SceneTree
## A11.5/A11.6 -- the job props, and the idle-to-alert comparison.
##
##   godot --path godot -s _harness/jobview.gd -- <models> <out-dir>
##
## **A11.5 asks for an idle-to-alert comparison and this delivers it in
## the only truthful form available.** The ten role bodies are single
## joined meshes: there is no pose to change and no articulation to
## change it with. So what these frames compare is the POST -- one
## ground role, one planted role and one flyer, at their stations,
## idle and alerted -- through the `anchor_warn` node Batch 030 now
## carries and through the props' own state nodes.
##
## That is less than A11.5 would get from a rigged roster and the
## report says so. It is not nothing: whether a player can tell an
## alerted sentry from an incurious one at gameplay distance is a
## question these frames can actually answer, and the answer does not
## depend on a rig that does not exist.
##
## Same rig in every frame, shipped-Zone values, no per-shot lighting.

const FOV := 50.0
const EYE := 1.6
## Where a player first sees a sentry, not where a reviewer inspects one.
const RANGE := 7.0

var _models: String
var _out: String
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0

const SOLO := [
	["job_watch_post", Vector3(3.4, 2.4, 3.4), Vector3(0.6, 0.7, 0),
		"Watch post -- the column stands OUTSIDE the brute's turning circle"],
	["job_tend_pedestal", Vector3(2.4, 1.8, 2.4), Vector3(0.5, 0.7, 0),
		"Tend pedestal -- what a beacon sweeps at half rate for"],
	["job_drift_perch", Vector3(2.4, 1.2, 2.4), Vector3(0, 0.1, 0),
		"Drift perch -- hung, because a flyer that came down would stop owning the ceiling"],
	["job_charge_socket", Vector3(1.3, 0.9, 1.3), Vector3(0, 0.25, 0),
		"Charge socket -- 0.5 m, role-agnostic: the honest alternative to a universal dock"],
	["job_inspect_panel", Vector3(1.8, 1.4, 1.8), Vector3(0, 0.5, 0),
		"Inspection panel -- a door with two positions and something behind it"],
	["job_tool_rack", Vector3(1.8, 1.4, 1.8), Vector3(0, 0.6, 0),
		"Tool rack -- three slots, so a taken tool has somewhere to not be"],
	["job_post_plate", Vector3(3.6, 2.8, 3.6), Vector3(0, 0, 0),
		"Post plate -- 3 m, which is ENEMY_POST_TOLERANCE doubled"],
	["job_beat_cue", Vector3(2.2, 1.7, 2.2), Vector3(0, 0, 0),
		"Beat cue -- a scuff, not a path: _patrol picks a RANDOM point on the circle"],
]

## (role, job prop, hover, caption fragment)
const STATIONS := [
	["melee", "job_post_plate", 0.0, "GROUND (patrol)"],
	["ranged", "job_watch_post", 0.0, "PLANTED (watch)"],
	["drifter", "job_drift_perch", 2.55, "FLYER (drift)"],
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
	printerr("[jobview] FAIL: %s" % what)


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
	for at: Vector3 in [Vector3(4.0, 4.6, 3.2), Vector3(-4.2, 3.6, -2.8)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 18.0
		lamp.light_energy = 3.2
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(40, 0.2, 40)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.31, 0.33)
	mat.roughness = 0.95
	ground.set_surface_override_material(0, mat)
	root.add_child(ground)
	ground.position = Vector3(0, -0.11, 0)
	return [view, root]


func _put(root: Node3D, rel: String, at: Vector3, yaw := 0.0) -> Node3D:
	var node: Node3D = _bench.call("load_glb", "%s/%s" % [_models, rel])
	if node == null:
		_fail("could not load %s" % rel)
		return null
	root.add_child(node)
	_bench.call("force_nearest", node)
	node.position = at
	node.rotation.y = yaw
	return node


## ATTACH something at the anchor, rather than tinting the anchor.
##
## The first cut lit `anchor_warn` itself and nothing appeared, which
## is correct and was worth finding: Batch 030's anchors are 40 mm
## markers EMBEDDED INSIDE the body -- `enemy_readiness.gd` refuses one
## that stands proud, because a bump on an enemy that has none is a
## modelling error. An anchor is an attachment POINT, not a display
## surface: a runtime hangs a flash or a glyph on it and the attached
## thing is what is seen.
##
## So this does what a runtime would: reads the anchor's transform and
## puts a marker there. Preview only -- Production replaces no
## materials on an authored scene and attaches nothing today.
func _attach_at(node: Node, names: Array, colour: Color,
		root: Node3D) -> int:
	var found := 0
	for child in node.get_children():
		if child is MeshInstance3D and names.has(str(child.name)):
			var mark := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.22, 0.22, 0.22)
			mark.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = colour * 0.5
			mat.emission_enabled = true
			mat.emission = colour
			mat.emission_energy_multiplier = 1.4
			mark.set_surface_override_material(0, mat)
			root.add_child(mark)
			# THE MESH'S CENTRE, NOT THE NODE'S ORIGIN. The builder
			# writes anchor geometry at world coordinates and leaves
			# the object at the origin, so every anchor's node sits at
			# (0,0,0) under the body -- and a marker placed at
			# `global_position` lands on the floor between the role's
			# feet, which is where the first attempt put it.
			var mi := child as MeshInstance3D
			var at := mi.global_transform * (mi.mesh.get_aabb().get_center()
				if mi.mesh != null else Vector3.ZERO)
			mark.global_position = at
			found += 1
		found += _attach_at(child, names, colour, root)
	return found


func _capture(view: SubViewport, eye: Vector3, look: Vector3,
		name: String, caption: String, stamp := "") -> void:
	var cam := Camera3D.new()
	cam.fov = FOV
	view.add_child(cam)
	cam.global_position = eye
	cam.look_at(look, Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	_bench.call("label", image,
		stamp if stamp != "" else "CANDIDATE -- imported and fit-checked, "
			+ "NOT runtime-bound, NOT owner-approved",
		Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, caption, Vector2i(16, 34),
		Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[jobview] %s.png" % name)
	view.queue_free()


func _station(role: String, prop: String, hover: float, tag: String,
		alert: bool) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	# THE PERCH HANGS. Its origin is where the hanger meets the yoke,
	# and the cradles are 0.49 below that -- so it belongs at the
	# flyer's hover height plus half a metre, not on the floor, which
	# is where the first frame put it.
	_put(root, "batch050/jobs/%s.glb" % prop,
		Vector3(0, hover + 0.5 if hover > 0.0 else 0.0, 0))
	if prop == "job_post_plate":
		# The beat is a point on a 4.5 m circle -- one of them, since
		# `_patrol` picks at random and a drawn path would be a route
		# Art invented.
		_put(root, "batch050/jobs/job_beat_cue.glb",
			Vector3(3.2, 0, 3.2))
	# The enemy models face -Z, as the game's do; turned half round they
	# face this camera the way they always have on these sheets.
	var body := _put(root, "batch030/enemies/enemy_role_%s.glb" % role,
		Vector3(0, hover, 0), PI)
	if body != null and alert:
		var hit := _attach_at(body, ["anchor_warn"],
			Color(1.0, 0.55, 0.3), root)
		if hit == 0:
			_fail("%s has no anchor_warn to attach to" % role)
	await _capture(view,
		Vector3(RANGE * 0.7, EYE + hover * 0.55, RANGE * 0.7),
		Vector3(0, hover * 0.75 + 0.6, 0),
		"%s_%s" % [role, "alert" if alert else "idle"],
		"%s -- %s at its station, %s"
			% [tag, role, "ALERTED (anchor_warn lit)" if alert
				else "idle"],
		"A11.5 -- no articulation on these bodies, so this compares the "
			+ "POST and what a runtime would ATTACH, not a pose")


func _run() -> void:
	for raw: Variant in SOLO:
		var sdata: Array = raw
		var staged := _stage()
		_put(staged[1], "batch050/jobs/%s.glb" % str(sdata[0]),
			Vector3.ZERO)
		await _capture(staged[0], sdata[1], sdata[2], str(sdata[0]),
			str(sdata[3]))
	for raw: Variant in STATIONS:
		var sdata: Array = raw
		await _station(str(sdata[0]), str(sdata[1]), float(sdata[2]),
			str(sdata[3]), false)
		await _station(str(sdata[0]), str(sdata[1]), float(sdata[2]),
			str(sdata[3]), true)
	if _problems.is_empty():
		print("[jobview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
