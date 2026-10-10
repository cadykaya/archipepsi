extends SceneTree
## The three branching rooms, photographed from a standing player's eye.
##
##   godot --path godot -s _harness/views.gd -- <models> <out>
##
## An overhead diagram of a junction shows that three ways leave it. It
## does not show whether you can TELL, standing in the door, that three
## ways leave it -- which is the thing being claimed. So every view here is
## taken at `PLAYER_HEIGHT - 0.2` (1.60 m), level, with the lens the game
## uses, from somewhere a body has actually walked to in
## `run_route_walk.sh`.
##
## Lighting is the shipped Zone's: ambient 0.35 and fog 0.012 from
## `ZoneBuilder`, one shadowless `OmniLight3D` per fixture at `omni_range`
## 12.0 from `ChamberBuilders`, and NO `DirectionalLight3D` -- a built Zone
## has none, and lighting these rooms with one would flatter them with
## light the game never casts.
##
## These prove FRAMING and LEGIBILITY. They are stills: they do not prove
## combat visibility, they do not prove flicker-free motion, and they are
## not a substitute for a playtest.

const EYE := 1.60
const FOV := 75.0

var _models: String
var _out: String
var _bench: GDScript
var _problems: Array[String] = []
var _made: Array[String] = []


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
	printerr("[views] FAIL: %s" % what)


## The bench's viewport already carries a WorldEnvironment; this sets the
## Zone's own numbers on it rather than adding a second one, and hangs the
## fixtures. No DirectionalLight3D -- `add_lights` would give three, and a
## built Zone has none.
func _lit(view: SubViewport, root: Node3D, lamps: Array) -> void:
	var world := view.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null:
		_fail("the bench viewport has no WorldEnvironment to light")
		return
	var env := world.environment
	env.ambient_light_color = Color(0.72, 0.77, 0.82)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.30, 0.33, 0.38)
	for raw: Variant in lamps:
		var at: Vector3 = raw
		var lamp := OmniLight3D.new()
		lamp.omni_range = 12.0
		lamp.light_energy = 2.4
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at


func _shot(glb: String, lamps: Array, eye: Vector3, look: Vector3,
		out_name: String) -> void:
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(1280, 720), 0.35)
	var root := Node3D.new()
	view.add_child(root)
	var shell: Node3D = _bench.call("load_glb", glb)
	if shell == null:
		_fail("could not load %s" % glb)
		view.queue_free()
		return
	root.add_child(shell)
	_bench.call("force_nearest", shell)
	_lit(view, root, lamps)

	var cam := Camera3D.new()
	cam.fov = FOV
	view.add_child(cam)
	cam.global_position = eye
	cam.look_at(look, Vector3.UP)
	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	var path := "%s/%s.png" % [_out, out_name]
	if image.save_png(path) != OK:
		_fail("could not write %s" % path)
	else:
		_made.append(out_name)
		print("[views] %s.png" % out_name)
	view.queue_free()


func _run() -> void:
	if _out == "":
		quit(1)
		return
	# Lamps where a chamber builder would hang them: over the open middle
	# and over each approach.
	var tri := "%s/batch044/shells/shell_junction_triad.glb" % _models
	var tri_lamps := [Vector3(0, 5.5, 13), Vector3(0, 5.5, 4),
			Vector3(0, 5.5, 22), Vector3(9, 5.5, 13), Vector3(-9, 5.5, 13)]
	# Standing in the entry, looking in: can you see that it branches?
	await _shot(tri, tri_lamps, Vector3(0, EYE, 2.0), Vector3(0, EYE, 20.0),
			"TRIAD_1_from_the_entry")
	# On the sorting floor, facing the east branch.
	await _shot(tri, tri_lamps, Vector3(0, EYE, 13.0),
			Vector3(13.0, EYE - 0.1, 13.0), "TRIAD_2_the_east_branch")
	# From the sorting floor into the west bay.
	await _shot(tri, tri_lamps, Vector3(-2.0, EYE, 13.0),
			Vector3(-12.0, EYE - 0.2, 13.0), "TRIAD_3_the_west_bay")

	var crs := "%s/batch044/shells/shell_junction_cross.glb" % _models
	var crs_lamps := [Vector3(-9, 6.5, 8), Vector3(9, 6.5, 8),
			Vector3(-9, 6.5, 22), Vector3(9, 6.5, 22),
			Vector3(0, 6.5, 3), Vector3(0, 6.5, 27)]
	await _shot(crs, crs_lamps, Vector3(0, EYE, 2.0),
			Vector3(0, EYE, 20.0), "CROSS_1_from_the_entry")
	await _shot(crs, crs_lamps, Vector3(-9.5, EYE, 8.0),
			Vector3(-9.5, EYE, 26.0), "CROSS_2_the_west_ambulatory")
	await _shot(crs, crs_lamps, Vector3(-9.5, EYE, 22.0),
			Vector3(9.0, EYE - 0.1, 26.0), "CROSS_3_the_north_bay")

	var bay := "%s/batch044/shells/shell_bay_terminus.glb" % _models
	var bay_lamps := [Vector3(0, 4.5, 5), Vector3(0, 4.5, 14),
			Vector3(-5.0, 4.2, 19.0), Vector3(5.0, 4.2, 19.0)]
	await _shot(bay, bay_lamps, Vector3(0, EYE, 2.0),
			Vector3(0, EYE, 20.0), "TERMINUS_1_from_the_entry")
	await _shot(bay, bay_lamps, Vector3(0, EYE, 13.0),
			Vector3(0, EYE - 0.15, 21.0), "TERMINUS_2_the_end_wall")

	if _made.size() != 8:
		_fail("%d of 8 views were made; a view that did not render is not "
				% _made.size() + "evidence of anything")
	if _problems.is_empty():
		print("[views] 8 interior views at eye height")
		quit(0)
		return
	quit(1)
