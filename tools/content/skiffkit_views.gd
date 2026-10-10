extends SceneTree
## Batch 047 -- the fitted skiff, from outside AND from a rider's eye.
##
##   godot --path godot -s _harness/skiffview.gd -- <models> <out-dir>
##
## A03.2 says to inspect from player eye level, not only from outside
## the vehicle, and it is right to insist: a shield looks fine from a
## three-quarter view and can still be a wall in front of your face.
##
## A03.6 asks for the isolated state strip, and that needs a warning
## attached to it, which is the second half of this file's job.

const FOV := 48.0
const EYE := 1.6
const DECK_CENTRE_Y := 0.8

## THE STATE STRIP IS A PREVIEW TINT AND NOTHING ELSE.
##
## `ContentInstantiator._from_authored_scene` calls `scene.instantiate()`
## and performs no material replacement; an authored asset keeps the
## materials it was exported with. So these frames are NOT a claim about
## what the game does. They are a demonstration that each state region
## arrived as a NODE a script can fetch by name -- which is the only
## thing Art can deliver here, because what lights a lamp and when is
## Production's.
##
## Stated this loudly because a preview that forcibly swaps materials has
## been mistaken for engine behaviour in this lane before, and the frame
## was the evidence for a repair request that should never have been
## made.
const STATES := [
	["accepted", ["lamp_fore"], Color(0.4, 1.0, 0.6),
		"ACCEPTED -- RailCarrier emits departed(from, FORWARD)"],
	["refused", ["console_readout"], Color(1.0, 0.45, 0.35),
		"REFUSED -- refused(reason, detail) has somewhere to say why"],
	["moving", ["lamp_fore", "lamp_aft"], Color(1.0, 0.8, 0.4),
		"MOVING -- both ends lit; direction is the fore lamp's job"],
	["held", ["beacon_hold"], Color(0.5, 0.75, 1.0),
		"HELD -- HOLD is a real state in the carrier, not 'no input'"],
	["interrupted", ["beacon_hold", "console_readout"],
		Color(1.0, 0.6, 0.2),
		"INTERRUPTED -- the beacon and the reason, together"],
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
	printerr("[skiffview] FAIL: %s" % what)


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
	for at: Vector3 in [Vector3(3.6, 4.4, 3.2), Vector3(-3.8, 3.6, -2.8)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 14.0
		lamp.light_energy = 2.8
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at
	return [view, root]


func _put(root: Node3D, rel: String, at: Vector3, yaw := 0.0,
		mirror := false) -> Node3D:
	var node: Node3D = _bench.call("load_glb", "%s/%s" % [_models, rel])
	if node == null:
		_fail("could not load %s" % rel)
		return null
	root.add_child(node)
	_bench.call("force_nearest", node)
	node.position = at
	node.rotation.y = yaw
	if mirror:
		node.scale = Vector3(-1, 1, 1)
	return node


## The loaded carrier, with the rail beam under it in Production's grey.
func _loaded(root: Node3D) -> void:
	# The BARE hull. `sp_skiff_deck` carries its own end guards and
	# stacking `sp_skiff_rail` on it doubles the rail -- which is
	# exactly what the first loaded frame showed, and why the bare
	# variant exists.
	_put(root, "batch045/setpieces/sp_skiff_deck_bare.glb",
		Vector3.ZERO)
	_put(root, "batch047/skiffkit/sp_skiff_shield.glb", Vector3.ZERO)
	_put(root, "batch047/skiffkit/sp_skiff_rail.glb", Vector3.ZERO)
	_put(root, "batch047/skiffkit/sp_skiff_rail.glb", Vector3.ZERO, PI)
	_put(root, "batch047/skiffkit/sp_skiff_bogie.glb",
		Vector3(0.45, 0, 0))
	_put(root, "batch047/skiffkit/sp_skiff_bogie.glb",
		Vector3(-0.45, 0, 0), 0.0, true)
	# Their beam, in their grey: 0.5 x 0.35 centred on the rail, which is
	# 0.2 below the node origin -- so it really does come up INTO the
	# deck, and the frame should show that rather than hide it.
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.35, 14.0)
	beam.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.44, 0.47)
	mat.roughness = 1.0
	beam.set_surface_override_material(0, mat)
	root.add_child(beam)
	beam.position = Vector3(0, -DECK_CENTRE_Y + 0.6, 0)


## Somewhere to look. A rider's-eye frame with nothing beyond the
## shield is a picture of the sky: the first cut of
## `rider_eye_over_shield` proved only that the shield is below the
## horizon, which was never in doubt. What the frame has to show is
## whether a rider can SEE and SHOOT over the cover, so there are
## things at a target's height out there to see.
func _world_beyond(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(60, 0.2, 60)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.30, 0.31, 0.33)
	gmat.roughness = 0.95
	ground.set_surface_override_material(0, gmat)
	root.add_child(ground)
	ground.position = Vector3(0, -DECK_CENTRE_Y - 0.1, 0)
	# Three markers at a standing target's height, out past the shield,
	# in Production's grey: 1.8 m tall, on the ground.
	for i in 3:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 1.8, 0.5)
		post.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.46, 0.47, 0.5)
		mat.roughness = 1.0
		post.set_surface_override_material(0, mat)
		root.add_child(post)
		post.position = Vector3(-6.0 - float(i) * 2.5,
			-DECK_CENTRE_Y + 0.9, -3.0 + float(i) * 3.0)


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
		print("[skiffview] %s.png" % name)
	view.queue_free()


func _solo(id: String, eye: Vector3, look: Vector3,
		caption: String) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	if _put(root, "batch047/skiffkit/%s.glb" % id, Vector3.ZERO) == null:
		view.queue_free()
		return
	await _capture(view, eye, look, id, caption)


## Tint the named nodes, and only in this frame.
func _tint(node: Node, names: Array, colour: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and names.has(str(child.name)):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = colour
			mat.emission_enabled = true
			mat.emission = colour
			mat.emission_energy_multiplier = 2.4
			(child as MeshInstance3D).material_override = mat
		_tint(child, names, colour)


func _state(tag: String, names: Array, colour: Color,
		caption: String) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_loaded(root)
	_tint(root, names, colour)
	await _capture(view, Vector3(4.4, 2.3, 4.6), Vector3(0, 0.45, 0),
		"state_%s" % tag, caption,
		"PREVIEW TINT ONLY -- Art declares the NODE; what lights it and "
			+ "when is Production's. Not runtime behaviour.")


func _run() -> void:
	await _solo("sp_skiff_shield", Vector3(3.0, 1.9, 3.2),
		Vector3(-1.2, 0.6, 0),
		"Shield -- cap and kick eat INTO the 1.25 m cover, never above it")
	await _solo("sp_skiff_rail", Vector3(2.8, 1.8, 2.6),
		Vector3(0, 0.6, 1.6),
		"End guard -- tops at 1.05 over the deck, under the shield")
	await _solo("sp_skiff_bogie", Vector3(1.5, 0.9, 1.6),
		Vector3(0, -0.35, 0),
		"Traction truck -- rollers are NODES; nothing here is animated")

	# The whole vehicle, from outside.
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_loaded(root)
	await _capture(view, Vector3(5.6, 2.8, 5.2), Vector3(0, 0.4, 0),
		"loaded_outside",
		"Loaded skiff -- their rail beam in grey, coming UP into the "
		+ "bottom 0.175 m of the deck")

	# A03.2's actual requirement: from a rider's eye, behind the cover.
	staged = _stage()
	view = staged[0]
	root = staged[1]
	_loaded(root)
	_world_beyond(root)
	var eye_z := -DECK_CENTRE_Y + 1.0 + EYE
	await _capture(view, Vector3(-1.2, eye_z, 0.4),
		Vector3(-7.5, eye_z - 1.0, -1.2),
		"rider_eye_over_shield",
		"From a standing rider's eye behind the cover -- three 1.8 m "
		+ "markers beyond it, over a 1.25 m shield")

	# And from the boarding side, which is the other thing a rider does.
	staged = _stage()
	view = staged[0]
	root = staged[1]
	_loaded(root)
	_world_beyond(root)
	await _capture(view, Vector3(3.4, eye_z, 0.0),
		Vector3(-1.0, eye_z - 0.35, 0.0),
		"rider_eye_boarding",
		"From the dock side at eye height -- the boarding face stays open")

	# And crouched, because cover that only works standing is not cover.
	staged = _stage()
	view = staged[0]
	root = staged[1]
	_loaded(root)
	_world_beyond(root)
	var crouch := -DECK_CENTRE_Y + 1.0 + 1.0
	# Back off the panel: pressed against it the frame is a texture
	# swatch, and what it has to show is the PANEL BETWEEN the eye and
	# the markers, with sky over it.
	await _capture(view, Vector3(0.5, crouch, 0.5),
		Vector3(-7.5, crouch + 0.25, -1.0),
		"rider_eye_crouched",
		"Crouched at 1.00 m -- the same markers, now behind the cover")

	for raw: Variant in STATES:
		var s: Array = raw
		await _state(str(s[0]), s[1], s[2], str(s[3]))

	if _problems.is_empty():
		print("[skiffview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
