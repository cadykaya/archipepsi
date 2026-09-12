extends SceneTree
## One room, furnished the way the RUNTIME would furnish it. Preview only.
##
##   godot --path godot -s _harness/furnish.gd -- <models> <out> <shell>
##
## ## What this is, and what it is not
##
## **STAGED. NOT GENERATED CONTENT.** Every image it writes is stamped so,
## because a staged arrangement presented as ordinary output is the most
## expensive kind of wrong picture: it gets believed, and then the real
## Zone looks nothing like it.
##
## What makes it honest is that it places nothing of its own invention.
## Every prop stands at a point the SHELL DECLARES -- a `cover` socket, a
## `reactive` socket, an `enemy_high` socket, an `objective` volume, an
## `enemy_spawn` volume -- and each of those names a consumer that runs
## today: DestructibleCover, ReactiveBarrel, the ranged-enemy placement
## loop, the composer's reward and its enemy budget. Nothing is scattered
## to fill space. If the room looks empty here, the room IS empty to the
## runtime, and that is the finding rather than a lighting problem.
##
## The lighting is the shipped Zone's: `ZoneBuilder`'s ambient 0.35 and
## fog 0.012, one shadowless `OmniLight3D` per fixture at `omni_range`
## 12.0 from `ChamberBuilders`, and no `DirectionalLight3D`, because a
## built Zone has none.
##
## It proves FRAMING, LEGIBILITY AND OCCUPANCY. It does not prove combat
## visibility, it does not prove flicker-free motion, and it is not a
## playtest.

const EYE := 1.60
const FOV := 75.0

var _models: String
var _out: String
var _shell: String
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		_fail("usage: -- <models-dir> <out-dir> <shell-id>")
	else:
		_models = a[0]
		_out = a[1]
		_shell = a[2]
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[furnish] FAIL: %s" % what)


func _entry() -> Dictionary:
	var text := FileAccess.get_file_as_string(
			"%s/batch044/shells/manifest.json" % _models)
	if text == "":
		_fail("no batch044 manifest")
		return {}
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return (data as Dictionary).get(_shell, {})


func _prop(root: Node3D, rel: String, at: Vector3, yaw: float) -> bool:
	var node: Node3D = _bench.call("load_glb", "%s/%s" % [_models, rel])
	if node == null:
		_fail("missing prop %s" % rel)
		return false
	root.add_child(node)
	node.global_position = at
	node.rotate_y(deg_to_rad(yaw))
	return true


## A body-sized stand-in. Enemies are not art this lane ships, so they are
## drawn as what they are rather than dressed up as something else.
func _standin(root: Node3D, at: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mesh.set_surface_override_material(0, mat)
	root.add_child(mesh)
	mesh.global_position = at + Vector3(0, 0.9, 0)


func _v3(raw: Variant) -> Vector3:
	var a: Array = raw
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _furnish(root: Node3D, entry: Dictionary) -> Dictionary:
	var counted := {"cover": 0, "reactive": 0, "enemy_high": 0,
			"objective": 0, "enemy_spawn": 0, "fixture": 0}
	for raw: Variant in entry.get("sockets", []):
		var socket: Dictionary = raw
		var kind := str(socket.get("kind", ""))
		var at := _v3(socket["position"])
		match kind:
			"cover":
				if _prop(root, "batch043/physics/phys_movable_cover.glb",
						at, 0.0):
					counted["cover"] += 1
			"reactive":
				if _prop(root, "batch043/physics/phys_drum.glb", at, 0.0):
					counted["reactive"] += 1
			"enemy_high":
				_standin(root, at, Color(0.62, 0.20, 0.16))
				counted["enemy_high"] += 1
	for raw: Variant in entry.get("volumes", []):
		var volume: Dictionary = raw
		var kind := str(volume.get("kind", ""))
		var centre := _v3(volume["center"])
		var size := _v3(volume["size"])
		if kind == "objective":
			# The reward the composer would choose, standing where the
			# room says rewards stand. WHICH reward is the campaign's.
			if _prop(root, "batch043/physics/phys_key_component.glb",
					centre - Vector3(0, size.y / 2.0, 0), 20.0):
				counted["objective"] += 1
		elif kind == "enemy_spawn":
			for i in 3:
				var t := (i + 1) / 4.0
				var spot := centre + Vector3(
						(t - 0.5) * size.x * 0.7, -size.y / 2.0,
						(0.5 - t) * size.z * 0.7)
				_standin(root, spot, Color(0.55, 0.17, 0.14))
				counted["enemy_spawn"] += 1
	return counted


func _lit(view: SubViewport, root: Node3D, lamps: Array,
		counted: Dictionary) -> void:
	var world := view.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null:
		_fail("the bench viewport has no WorldEnvironment")
		return
	var env := world.environment
	env.ambient_light_color = Color(0.72, 0.77, 0.82)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.30, 0.33, 0.38)
	for raw: Variant in lamps:
		var at: Vector3 = raw
		# The housing the concrete-facility theme ships, and a lamp in it.
		if _prop(root, "batch001/architecture/arch_light_fixture.glb",
				at, 0.0):
			counted["fixture"] += 1
		var lamp := OmniLight3D.new()
		lamp.omni_range = 12.0
		lamp.light_energy = 2.6
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at - Vector3(0, 0.5, 0)


func _shot(entry: Dictionary, lamps: Array, eye: Vector3, look: Vector3,
		out_name: String) -> void:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.35)
	var root := Node3D.new()
	view.add_child(root)
	var shell: Node3D = _bench.call("load_glb",
			"%s/batch044/shells/%s.glb" % [_models, _shell])
	if shell == null:
		_fail("could not load %s" % _shell)
		view.queue_free()
		return
	root.add_child(shell)
	_bench.call("force_nearest", shell)
	var counted := _furnish(root, entry)
	_lit(view, root, lamps, counted)

	var cam := Camera3D.new()
	cam.fov = FOV
	view.add_child(cam)
	cam.global_position = eye
	cam.look_at(look, Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	# THE STAMP IS NOT OPTIONAL.
	_bench.call("label", image, "PREVIEW ONLY - STAGED, NOT GENERATED",
			Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image,
			"props stand only at points the shell declares", Vector2i(16, 34),
			Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, out_name]) != OK:
		_fail("could not write %s" % out_name)
	else:
		_made += 1
		print("[furnish] %s.png  %s" % [out_name, JSON.stringify(counted)])
	view.queue_free()


func _run() -> void:
	var entry := _entry()
	if entry.is_empty():
		quit(1)
		return
	var lamps: Array = []
	var shots: Array = []
	if _shell == "shell_junction_cross":
		# Over the bay, over the working face, and one in the passage.
		lamps = [Vector3(-5.0, 6.4, 9.0), Vector3(-5.0, 6.4, 18.0),
				Vector3(2.0, 6.4, 9.5), Vector3(-3.2, 6.4, 15.5),
				Vector3(7.7, 6.4, 17.5), Vector3(0, 6.4, 3.0),
				Vector3(0, 6.4, 27.0), Vector3(-12.0, 6.4, 15.0)]
		shots = [
			[Vector3(0, EYE, 2.0), Vector3(0, EYE, 20.0), "1_the_approach"],
			# THE DECISION POINT IS WHERE YOU DECIDE, looking the way you
			# are walking. Aimed west into the bay it only ever showed one
			# of the two answers, which made the frame agree with itself.
			# Head-on at the plant's face, 4.5 m out, the wide FOV carries
			# the bay opening on the left and the way round on the right.
			# 6 m out, not 4.5: at 4.5 m a 5.4 m mass fills the frame and
			# the picture stops being about a choice.
			# Aimed at the machine's EAST corner, because that is the edge
			# the decision turns on: straight down the entry line the bay
			# fills the frame and the passage mouth is clipped off it, so
			# the picture answered half the question.
			[Vector3(0, EYE, 8.5), Vector3(4.0, EYE, 14.2),
				"2_the_decision_point"],
			[Vector3(-7.8, EYE, 7.2), Vector3(-1.0, EYE - 0.05, 17.5),
				"3_the_working_bay"],
			# ... and the passage shot has to stand IN the passage. From
			# (4, 10) it was still in the bay looking at the machine's
			# south face, which is a good picture of the wrong thing.
			[Vector3(7.7, EYE, 14.0), Vector3(7.7, EYE, 23.0),
				"4_the_service_passage"],
			# The west branch's own arrival, and the only angle the trunk
			# lines read from: at 5.6 m they need distance to come down
			# into frame, and 12 m down the arm they run at the machine.
			[Vector3(-12.5, EYE, 15.0), Vector3(0.0, EYE + 1.0, 16.5),
				"5_the_west_branch"],
		]
	elif _shell == "shell_junction_triad":
		lamps = [Vector3(0, 5.4, 13), Vector3(0, 5.4, 4),
				Vector3(0, 5.4, 22), Vector3(9, 5.4, 13),
				Vector3(-9, 5.4, 13)]
		shots = [
			[Vector3(0, EYE, 2.0), Vector3(0, EYE, 20.0), "1_the_approach"],
			[Vector3(0, EYE, 11.0), Vector3(-12.0, EYE - 0.1, 13.5),
				"2_the_decision_point"],
		]
	else:
		_fail("no shot list for %s" % _shell)
		quit(1)
		return
	for raw: Variant in shots:
		var shot: Array = raw
		await _shot(entry, lamps, shot[0], shot[1],
				"%s_%s" % [_shell.replace("shell_", "").to_upper(), shot[2]])

	if _made != shots.size():
		_fail("%d of %d views were made" % [_made, shots.size()])
	if _problems.is_empty():
		print("[furnish] %d furnished view(s) of %s" % [_made, _shell])
		quit(0)
		return
	quit(1)
