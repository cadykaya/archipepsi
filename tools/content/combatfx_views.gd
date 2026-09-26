extends SceneTree
## A12.5/A12.6 -- the combat reads, and whether they survive a backdrop.
##
##   godot --path godot -s _harness/fxview.gd -- <models> <out-dir>
##
## A12.5 asks for legibility "against at least a pale, dark and busy
## proposed pack", and that is the one test in A12 a still image can
## actually answer. So the telegraph ring and all three of Art's
## projectiles are shot against exactly those three, with the SAME rig
## and the same camera each time -- the backdrop is the only variable,
## which is what makes it a test rather than three pictures.
##
## The busy backdrop is a chequer at the scale a wall texture reads at,
## not noise: what breaks a read is competing STRUCTURE, and a pack
## whose walls are panelled is the realistic hard case.

const FOV := 50.0

var _models: String
var _out: String
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0

const SOLO := [
	["fx_telegraph_ring", Vector3(2.0, 1.7, 2.0), Vector3(0, 0, 0),
		"Telegraph ring -- twelve ticks, a CLOSED ending and a BROKEN one"],
	["fx_charger_lane", Vector3(4.0, 3.4, 4.6), Vector3(0, 0, 2.6),
		"Charger lane -- a lane, not an arrow: the rush cannot turn"],
	["fx_bulwark_face", Vector3(2.2, 1.7, 2.2), Vector3(0, 0.7, 0),
		"Bulwark face -- to the published envelope, so it claims no extra coverage"],
	["fx_warned_ground", Vector3(3.2, 2.6, 3.2), Vector3(0, 0, 0),
		"Warned ground -- OPEN, so the landing edge stays visible"],
	["fx_beacon_range", Vector3(4.2, 3.2, 4.2), Vector3(0, 0, 0),
		"Beacon range -- how far the thing that makes it worse reaches"],
	["fx_diver_trail", Vector3(2.6, 2.0, 2.6), Vector3(0, 1.3, 0),
		"Diver trail -- narrowing down, so the eye follows it to the ground"],
	["fx_hit_wall", Vector3(0.9, 0.6, 0.9), Vector3(0, 0, 0),
		"Wall hit -- it stopped, and the surface took it"],
	["fx_hit_shield", Vector3(1.3, 0.8, 1.3), Vector3(0, 0, 0),
		"Shield hit -- REFUSED: convex, sliding off, no penetration"],
	["fx_hit_body", Vector3(1.2, 0.8, 1.2), Vector3(0, 0, 0),
		"Body hit -- DAMAGING: narrow and going IN. Not the dome."],
	["fx_hit_miss", Vector3(1.3, 0.8, 1.3), Vector3(0, 0, 0),
		"Miss -- the quietest of the five, deliberately"],
	["fx_hit_interrupt", Vector3(1.2, 0.8, 1.2), Vector3(0, 0, 0),
		"Interrupt -- shares ring_cancel's BROKEN language and nothing else's"],
]

## (name, backdrop colour, chequer?)
const BACKDROPS := [
	["pale", Color(0.84, 0.85, 0.87), false],
	["dark", Color(0.10, 0.11, 0.13), false],
	["busy", Color(0.46, 0.48, 0.52), true],
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
	printerr("[fxview] FAIL: %s" % what)


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
	for at: Vector3 in [Vector3(2.6, 3.2, 2.2), Vector3(-2.8, 2.4, -1.8)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 14.0
		lamp.light_energy = 2.8
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at
	return [view, root]


func _slab(root: Node3D, size: Vector3, at: Vector3, tint: Color) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.98
	node.set_surface_override_material(0, mat)
	root.add_child(node)
	node.position = at


## A wall at a pack's value, optionally panelled. Structure is what
## actually breaks a read -- flat noise does not.
func _backdrop(root: Node3D, tint: Color, chequer: bool) -> void:
	_slab(root, Vector3(20, 0.3, 20), Vector3(0, -0.16, 0), tint)
	_slab(root, Vector3(20, 10, 0.3), Vector3(0, 5, 3.4), tint)
	if not chequer:
		return
	for i in 7:
		for j in 4:
			if (i + j) % 2 != 0:
				continue
			_slab(root, Vector3(1.2, 1.2, 0.08),
				Vector3(-3.6 + float(i) * 1.25, 0.7 + float(j) * 1.25,
					3.22), tint.darkened(0.28))


func _put(root: Node3D, rel: String, at: Vector3) -> Node3D:
	var node: Node3D = _bench.call("load_glb", "%s/%s" % [_models, rel])
	if node == null:
		_fail("could not load %s" % rel)
		return null
	root.add_child(node)
	_bench.call("force_nearest", node)
	node.position = at
	return node


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
			+ "NOT runtime-bound, NOT owner-approved. No timing encoded.",
			Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, caption, Vector2i(16, 34),
			Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[fxview] %s.png" % name)
	view.queue_free()


func _run() -> void:
	for raw: Variant in SOLO:
		var sdata: Array = raw
		var staged := _stage()
		_slab(staged[1], Vector3(24, 0.2, 24), Vector3(0, -0.11, 0),
			Color(0.30, 0.31, 0.33))
		_put(staged[1], "batch051/combatfx/%s.glb" % str(sdata[0]),
			Vector3.ZERO)
		await _capture(staged[0], sdata[1], sdata[2], str(sdata[0]),
			str(sdata[3]))

	# A12.5. ONE camera, one rig, three backdrops.
	for raw: Variant in BACKDROPS:
		var b: Array = raw
		var staged := _stage()
		var root: Node3D = staged[1]
		_backdrop(root, b[1], bool(b[2]))
		_put(root, "batch051/combatfx/fx_telegraph_ring.glb",
			Vector3(-1.9, 1.3, 0))
		_put(root, "batch008/enemy/enemy_projectile_straight.glb",
			Vector3(0.4, 1.3, 0))
		_put(root, "batch008/enemy/enemy_projectile_falling.glb",
			Vector3(1.3, 1.3, 0))
		_put(root, "batch008/enemy/enemy_projectile_lobbed.glb",
			Vector3(2.3, 1.3, 0))
		_put(root, "batch051/combatfx/fx_hit_shield.glb",
			Vector3(3.4, 1.3, 0))
		_put(root, "batch051/combatfx/fx_hit_body.glb",
			Vector3(4.2, 1.3, 0))
		await _capture(staged[0], Vector3(0.6, 1.7, -5.4),
			Vector3(0.6, 1.3, 0), "backdrop_%s" % str(b[0]),
			"A12.5 %s backdrop -- ring, the three projectiles, refused "
				% str(b[0])
			+ "and damaging. Same rig, same camera, backdrop is the "
			+ "only variable.")

	if _problems.is_empty():
		print("[fxview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
