extends SceneTree
## Batch 046, photographed in the engine that will show it.
##
##   godot --path godot -s _harness/yardview.gd -- <models> <out-dir>
##
## Shipped-Zone lighting, not a studio: ambient 0.35, fog 0.012,
## shadowless omnis at range 12.0, and no `DirectionalLight3D`, because
## a built Zone has none.
##
## Three kinds of frame, because a yard kit is not nine objects on a
## backdrop:
##
## * **Each asset alone**, to be looked at.
## * **ASSEMBLIES with Production's own greybox in the frame** -- their
##   slabs drawn from `yard_fit.json` at the sizes and heights they
##   really are, in a flat grey, with the authored art on top. A04.6
##   asks for the equivalent view with the base greybox for fit
##   comparison, and this is the only honest way to show a fit: both, in
##   one picture, at the same scale.
## * **The span's three states**, at the angles `RailSpan` really uses:
##   stowed at 62 degrees, mid-travel, and aligned at 0.
##
## Every frame is stamped. These are CANDIDATES.

const FOV := 48.0
var _models: String
var _out: String
var _fit := {}
var _bench: GDScript
var _problems: Array[String] = []
var _made := 0

#: (id, camera, target, caption)
const SOLO := [
	["yk_track_module", Vector3(1.4, 1.0, 1.6), Vector3(0, 0, 0),
		"Track module -- one metre, laid end to end; heads meet flush"],
	["yk_track_end", Vector3(1.6, 1.1, 1.8), Vector3(0, 0.1, 0),
		"Track end -- a stop, not a taper: the gap must read as a gap"],
	["yk_track_pier", Vector3(1.3, 0.9, 1.4), Vector3(0, 0.2, 0),
		"Track pier -- their track floats 0.425 m over the yard floor"],
	["yk_dock_edge", Vector3(3.0, 2.4, 4.4), Vector3(0.5, 0, 0),
		"Dock edge -- 7 m of it, nothing over 0.09 m; boarding crosses this"],
	["yk_dock_buffer", Vector3(1.7, 1.4, 1.7), Vector3(0, 0.45, 0),
		"Dock buffer -- stands OUTSIDE the receiver posts at lateral 2.6"],
	["yk_dock_locker", Vector3(2.2, 1.7, 2.2), Vector3(0, 0.45, 0),
		"Dock locker -- the limited service furniture A04.2 allows"],
	["yk_switch_stand", Vector3(1.9, 1.4, 2.1), Vector3(0, 0.3, 0),
		"Switch stand -- CANDIDATE: the carrier has no switchable routing"],
	["yk_gantry_head", Vector3(3.4, 1.6, 3.4), Vector3(0, 0, 0),
		"Gantry head -- closes the 0.40 m between their column and platform"],
	["yk_gantry_winch", Vector3(2.4, 1.8, 2.4), Vector3(0, 0.5, 0),
		"Gantry winch -- its own asset; the platform separates it from the head"],
	["yk_gantry_anchor", Vector3(3.6, 1.6, 3.2), Vector3(0.6, 0.2, 0),
		"Grapple anchor mount -- adapts the MOUNTING, never the target"],
	["yk_lever_housing", Vector3(1.9, 1.5, 1.9), Vector3(0, 0.4, 0),
		"Alignment lever -- arm, lamp and service panel each addressable"],
	["yk_branch_mast", Vector3(2.6, 1.8, 2.6), Vector3(0, 0.9, 0),
		"Branch landmark -- 1.62 m because the sight corridor said so"],
	["yk_branch_conduit", Vector3(1.9, 1.3, 2.2), Vector3(0, 0.1, 0),
		"Branch conduit -- 2 m, tiling; the continuity back to the junction"],
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
	printerr("[yardview] FAIL: %s" % what)


func _stage(size := Vector2i(1280, 720)) -> Array:
	var view: SubViewport = _bench.call("make_viewport", self, size, 0.35)
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
	for at: Vector3 in [Vector3(4.4, 5.2, 3.6), Vector3(-4.6, 4.0, -3.2)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = 16.0
		lamp.light_energy = 3.0
		lamp.shadow_enabled = false
		lamp.light_color = Color(0.98, 0.95, 0.88)
		root.add_child(lamp)
		lamp.global_position = at
	return [view, root]


func _ground(root: Node3D, at: Vector3, size := Vector3(40, 0.2, 40)) -> void:
	var node := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = size
	node.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.31, 0.33)
	mat.roughness = 0.95
	node.set_surface_override_material(0, mat)
	root.add_child(node)
	node.global_position = at


## PRODUCTION'S GREYBOX, in Production's grey. Flat and untextured on
## purpose: in an assembly frame the eye has to be able to tell at a
## glance which volume is theirs and which is Art's.
func _grey(root: Node3D, size: Vector3, at: Vector3,
		tint := Color(0.42, 0.44, 0.47)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1.0
	node.set_surface_override_material(0, mat)
	root.add_child(node)
	node.global_position = at
	return node


func _art(root: Node3D, id: String, at: Vector3,
		yaw := 0.0) -> Node3D:
	var node: Node3D = _bench.call("load_glb",
			"%s/batch046/yardkit/%s.glb" % [_models, id])
	if node == null:
		_fail("could not load %s" % id)
		return null
	root.add_child(node)
	_bench.call("force_nearest", node)
	node.global_position = at
	node.rotation.y = yaw
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
			+ "NOT runtime-bound, NOT owner-approved",
			Vector2i(16, 16), Color(1, 0.86, 0.3))
	_bench.call("label", image, caption, Vector2i(16, 34),
			Color(0.82, 0.84, 0.88))
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_fail("could not write %s" % name)
	else:
		_made += 1
		print("[yardview] %s.png" % name)
	view.queue_free()


func _solo(id: String, eye: Vector3, look: Vector3,
		caption: String) -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_ground(root, Vector3(0, -0.11, 0), Vector3(24, 0.2, 24))
	if _art(root, id, Vector3.ZERO) == null:
		view.queue_free()
		return
	await _capture(view, eye, look, id, caption)


## The dock, with their slab under it. Local frame: x is lateral out
## from the rail, z is along the track, y is world height.
func _dock_assembly() -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_ground(root, Vector3(3, -0.1, 0))
	var dock: Dictionary = _fit["docks"][0]
	var pad: Array = dock["pad_size_local"]
	var out: float = float(_fit["constants"]["DOCK_OUT"])
	var top: float = float(dock["pad_top_y"])
	# Their pad, their deck.
	_grey(root, Vector3(float(pad[0]), float(pad[1]), float(pad[2])),
			Vector3(out, top - float(pad[1]) * 0.5, 0))
	# The carrier's deck box in a DIFFERENT grey from the pad. They abut
	# exactly -- the pad's inner edge is the deck's outer edge -- so in
	# one flat grey they merged into a single slab and the frame said
	# nothing about the seam it exists to show.
	var deck: Array = _fit["constants"]["DECK"]
	_grey(root, Vector3(float(deck[0]), float(deck[1]), float(deck[2])),
			Vector3(0, top - float(deck[1]) * 0.5, 0),
			Color(0.26, 0.28, 0.33))
	# Their receiver post, so the buffer can be seen standing clear of it.
	_grey(root, Vector3(0.16, float(dock["receiver_head_y"]), 0.16),
			Vector3(float(dock["receiver_lateral"]),
				float(dock["receiver_head_y"]) * 0.5,
				float(dock["receiver_along"])))
	# Art on top.
	_art(root, "yk_dock_edge", Vector3(float(dock["lateral_inner"]), top, 0))
	_art(root, "yk_dock_buffer", Vector3(4.6, top, -2.6))
	_art(root, "yk_dock_locker", Vector3(5.0, top, 2.2))
	# TRACK BEYOND THE DECK BOX, not under it. The first cut laid the
	# modules at the dock's own z and they vanished inside the carrier's
	# volume -- a frame that shows a track running through a vehicle.
	# The carrier occupies the rail here; the track is what it came in
	# on, so it runs away from the dock.
	var rail_y: float = float(_fit["rail"]["y"])
	for i in 6:
		_art(root, "yk_track_module", Vector3(0, rail_y, 2.6 + float(i)))
		if i % 2 == 0:
			_art(root, "yk_track_pier", Vector3(0, 0, 2.6 + float(i)))
	_art(root, "yk_track_end", Vector3(0, rail_y, 9.4))
	await _capture(view, Vector3(11.0, 4.0, 11.0), Vector3(2.4, 0.8, 1.6),
		"dock_assembly",
		"Dock, with Production's greybox in plain grey -- pad, deck box "
		+ "and receiver post are theirs")


## The gantry stack, which is the one place the fit is a finding.
func _gantry_assembly() -> void:
	var staged := _stage()
	var view: SubViewport = staged[0]
	var root: Node3D = staged[1]
	_ground(root, Vector3(6, -0.1, 0))
	var g: Dictionary = _fit["gantry"]
	var deck_y: float = float(g["deck_centre"][1])
	var deck_size: Array = g["deck_size"]
	var col: Array = g["column_size"]
	var lat: float = float(g["lateral_deck"])
	_grey(root, Vector3(float(deck_size[0]), float(deck_size[1]),
			float(deck_size[2])), Vector3(lat, deck_y, 0))
	_grey(root, Vector3(float(col[0]), float(col[1]), float(col[2])),
			Vector3(lat, float(col[1]) * 0.5, 0))
	var plate: Array = g["plate_size"]
	_grey(root, Vector3(float(plate[0]), float(plate[1]),
			float(plate[2])),
			Vector3(float(g["lateral_plate"]),
				float(g["plate_centre"][1]), 0))
	_art(root, "yk_gantry_head", Vector3(lat, deck_y, 0))
	_art(root, "yk_gantry_winch",
		Vector3(lat + 1.05, deck_y + float(deck_size[1]) * 0.5, 0))
	_art(root, "yk_lever_housing",
		Vector3(lat, deck_y + float(deck_size[1]) * 0.5, 0))
	_art(root, "yk_gantry_anchor",
		Vector3(float(g["lateral_plate"]), float(g["plate_centre"][1]), 0))
	# A SOFFIT TO HANG FROM. The anchor mount is a ceiling fixture and
	# the scenario's own ceiling is not in this frame, so without a
	# reference plane it reads as floating debris rather than as
	# something bolted to a building. Grey, like everything that is not
	# this batch's.
	_grey(root, Vector3(9.0, 0.4, 7.0),
			Vector3(float(g["lateral_plate"]) + 2.4, 8.0, 0))
	# LOW, looking up under the platform's edge. From above, the head
	# casting -- the whole reason this frame exists -- is behind the
	# slab it holds.
	await _capture(view, Vector3(14.2, 2.1, 7.6), Vector3(lat - 0.4, 3.5, 0),
		"gantry_assembly",
		"Gantry -- their column tops at 3.10, their platform starts at "
		+ "3.50; the head casting is that 0.40 m")


## The span, at the three angles `RailSpan` really uses.
func _span_states() -> void:
	var stow: float = float(_fit["span"]["stowed_degrees"])
	var gap: float = float(_fit["span"]["gap"])
	for state: Array in [[1.0, "stowed", "STOWED at %.0f deg -- a "
				% stow + "drawbridge, and steeper than the 46 deg a "
				+ "player can walk"],
			[0.5, "travelling", "MID-TRAVEL -- not 'nearly commissioned'"],
			[0.0, "aligned", "ALIGNED -- %.2f m, meeting both track ends"
				% gap]]:
		var staged := _stage()
		var view: SubViewport = staged[0]
		var root: Node3D = staged[1]
		_ground(root, Vector3(0, -0.1, 0), Vector3(60, 0.2, 60))
		var rail_y: float = float(_fit["rail"]["y"])
		# Their two rail ends, so "meets both" is something the frame
		# shows rather than something this caption claims.
		for z: float in [0.0, gap]:
			_grey(root, Vector3(0.5, 0.35, 1.0), Vector3(0, rail_y, z))
		var pivot := Node3D.new()
		root.add_child(pivot)
		pivot.global_position = Vector3(0, rail_y, 0)
		pivot.rotation.x = -deg_to_rad(stow * float(state[0]))
		var beam: Node3D = _bench.call("load_glb",
			"%s/batch046/yardkit/yk_span_beam.glb" % _models)
		if beam == null:
			_fail("could not load yk_span_beam")
			view.queue_free()
			return
		pivot.add_child(beam)
		_bench.call("force_nearest", beam)
		beam.position = Vector3(0, 0, gap * 0.5)
		await _capture(view, Vector3(23.0, 9.0, -13.0),
			Vector3(0, 6.0, gap * 0.45),
			"span_%s" % str(state[1]), str(state[2]))


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch046/yard_fit.json" % _models)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("no measured yard; the assembly frames would be a guess")
		quit(1)
		return
	_fit = parsed
	for raw: Variant in SOLO:
		var s: Array = raw
		await _solo(str(s[0]), s[1], s[2], str(s[3]))
	await _dock_assembly()
	await _gantry_assembly()
	await _span_states()
	if _problems.is_empty():
		print("[yardview] %d view(s)" % _made)
		quit(0)
	else:
		quit(1)
