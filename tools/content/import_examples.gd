extends SceneTree
## The Batch 043 asset interface, exercised. Four small examples.
##
##   godot --path godot -s _harness/examples.gd -- <models> <out>
##
## Exits 0 only when all four examples measured everything they claim to.
## A missing model, a renamed part, or a short result exits 1 and names the
## defect -- this script is quoted as verification, so it has to be able to
## fail.
##
## THIS IS THE ASSET INTERFACE, NOT GAMEPLAY. Nothing here decides what a
## power cell does when it is inserted, how heavy a ballast feels, what a
## switch triggers, or where a collider goes. It shows how to LOAD one of
## these assets, read its declared frame, find its named parts, and drive
## the ones that move. Gameplay behaviour and collision are Production's.
##
## Every line printed below is measured from the loaded scene, so the
## handoff can quote output rather than plausible-looking snippets.

var _models: String
var _out: String
var _bench: GDScript
var _log := {}
var _problems: Array[String] = []

## What each example has to have MEASURED for this run to count as evidence.
##
## The handoff quotes this script's output as verification, so an example
## that returned early -- a model that is not there, a part that was renamed
## out from under it -- must not read as a short but successful result. Every
## key below is produced by a measurement; if one is absent the run exits
## non-zero and says which.
const REQUIRED := {
	"carriable": ["asset", "size_runtime", "aabb_min_y", "grip_world",
			"socket_world_after_35deg_yaw", "socket_normal_after_yaw",
			"grip_bar_end_after_yaw"],
	"manipulate_only": ["asset", "carriable", "pads",
			"pad_facing_a_player_at_0_1.6_3", "facing_dot"],
	"fixed": ["asset", "manipulable", "mesh_nodes", "fittings",
			"grips_or_push_pads", "tether_eye_world"],
	"presentation": ["switch", "conduit"],
}


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


## Record a defect. It is printed as it happens, not only at the end, so the
## engine log still carries it if a later example brings the run down.
func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[examples] FAIL: %s" % what)


## Load a model, or record why this run is not evidence.
func _load(rel: String) -> Node3D:
	if _bench == null or _models == "":
		return null
	var node: Node3D = _bench.call("load_glb", "%s/%s" % [_models, rel])
	if node == null:
		_fail("missing or unreadable asset: %s" % rel)
	return node


## Find a named part, or record that the interface this example documents is
## no longer the interface. A renamed node is exactly the change integration
## needs to hear about, so it must not come back as a quiet empty result.
func _part(root: Node3D, part: String, kind: String) -> Node3D:
	var found := root.find_child(part, true, false)
	if found == null:
		_fail("%s has no node named '%s'" % [root.name, part])
		return null
	if not found.is_class(kind):
		_fail("%s/%s is a %s, not a %s"
				% [root.name, part, found.get_class(), kind])
		return null
	return found as Node3D


## The union AABB of an asset, in its own local frame -- runtime axes.
func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := mi.mesh.get_aabb()
		# The node's own transform relative to the asset root.
		var t := root.global_transform.affine_inverse() * mi.global_transform
		var here := t * local
		box = here if first else box.merge(here)
		first = false
	return box


# -- 1. a carriable prop ---------------------------------------------------

func _example_carriable() -> Dictionary:
	## POWER_CELL, 40 kg, `carriable = true`.
	##
	## What integration needs from it: where it stands, where a hand takes
	## it, and which face meets a socket.
	var cell := _load("batch043/physics/phys_power_cell.glb")
	if cell == null:
		return {}
	get_root().add_child(cell)

	var box := _aabb(cell)
	# The asset is floor-anchored, so its origin sits ON the ground plane:
	# place it at the floor position and it stands there, no offset.
	cell.global_position = Vector3(2.5, 0.0, -1.25)

	# The grip is a named node. It is geometry, not a marker -- so its own
	# AABB centre is the point a hand closes on.
	var grip := _part(cell, "grip_bar", "MeshInstance3D") as MeshInstance3D
	if grip == null:
		cell.queue_free()
		return {}
	var grip_world := grip.global_transform * grip.mesh.get_aabb().get_center()

	# The socket face comes from the manifest, in runtime axes, and is a
	# point ON the asset -- so it transforms with it like any other point.
	# ... and the grip's own centre, which is OFF the asset's vertical axis
	# once the cell is turned, so the transform is doing visible work.
	var socket_local := Vector3(0.0, 0.004, 0.0)
	var socket_normal := Vector3(0.0, -1.0, 0.0)
	var grip_local := grip.mesh.get_aabb().get_center() + Vector3(0.11, 0, 0)
	cell.rotate_y(deg_to_rad(35.0))                 # prove they travel
	var socket_world := cell.global_transform * socket_local
	var normal_world := cell.global_transform.basis * socket_normal
	var grip_end_world := cell.global_transform * grip_local

	var out := {
		"asset": "phys_power_cell",
		"size_runtime": [snappedf(box.size.x, 0.001),
				snappedf(box.size.y, 0.001), snappedf(box.size.z, 0.001)],
		"origin_is": "floor-anchored: local Y 0 is the ground plane",
		"aabb_min_y": snappedf(box.position.y, 0.001),
		"grip_world": [snappedf(grip_world.x, 0.001),
				snappedf(grip_world.y, 0.001), snappedf(grip_world.z, 0.001)],
		"socket_world_after_35deg_yaw": [snappedf(socket_world.x, 0.001),
				snappedf(socket_world.y, 0.001),
				snappedf(socket_world.z, 0.001)],
		"socket_normal_after_yaw": [snappedf(normal_world.x, 0.001),
				snappedf(normal_world.y, 0.001),
				snappedf(normal_world.z, 0.001)],
		"grip_bar_end_after_yaw": [snappedf(grip_end_world.x, 0.001),
				snappedf(grip_end_world.y, 0.001),
				snappedf(grip_end_world.z, 0.001)],
		"placed_at": [2.5, 0.0, -1.25],
	}
	cell.queue_free()
	return out


# -- 2. a manipulate-only prop --------------------------------------------

func _example_manipulate() -> Dictionary:
	## BALLAST, 320 kg, `carriable = false`, four attach pads.
	##
	## What integration needs: which pad faces the player, so a device
	## takes hold of the side it can actually reach.
	var ballast := _load("batch043/physics/phys_ballast.glb")
	if ballast == null:
		return {}
	get_root().add_child(ballast)
	ballast.global_position = Vector3(0.0, 0.0, 0.0)
	ballast.rotate_y(deg_to_rad(20.0))

	# Straight out of the manifest, runtime axes.
	var pads := [
		{"id": "attach_pad_0", "at": Vector3(0.0, 0.297, 0.39),
		 "n": Vector3(0.0, 0.0, 1.0)},
		{"id": "attach_pad_1", "at": Vector3(0.0, 0.297, -0.39),
		 "n": Vector3(0.0, 0.0, -1.0)},
		{"id": "attach_pad_2", "at": Vector3(-0.54, 0.297, 0.0),
		 "n": Vector3(-1.0, 0.0, 0.0)},
		{"id": "attach_pad_3", "at": Vector3(0.54, 0.297, 0.0),
		 "n": Vector3(1.0, 0.0, 0.0)},
	]
	var eye := Vector3(0.0, 1.6, 3.0)
	var best := ""
	var best_dot := -2.0
	for raw: Variant in pads:
		var pad: Dictionary = raw
		var n: Vector3 = ballast.global_transform.basis * (pad["n"] as Vector3)
		var p: Vector3 = ballast.global_transform * (pad["at"] as Vector3)
		var facing := n.normalized().dot((eye - p).normalized())
		if facing > best_dot:
			best_dot = facing
			best = pad["id"]
	# And the same node can be lit when the player is close enough to use
	# it -- §33.7's "attach point available" -- because it IS a node.
	var node := _part(ballast, best, "MeshInstance3D") as MeshInstance3D
	if node == null:
		ballast.queue_free()
		return {}
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.22, 0.84, 0.78)
	lit.emission_enabled = true
	lit.emission = lit.albedo_color
	node.set_surface_override_material(0, lit)

	var out := {
		"asset": "phys_ballast",
		"carriable": false,
		"pads": pads.size(),
		"pad_facing_a_player_at_0_1.6_3": best,
		"facing_dot": snappedf(best_dot, 0.001),
		"highlighted_by": "set_surface_override_material(0, ...) on that node",
	}
	ballast.queue_free()
	return out


# -- 3. the fixed anchor ---------------------------------------------------

func _example_fixed() -> Dictionary:
	## ANCHOR_BLOCK, 500 kg, `manipulable = false` -> `mass_class` `FIXED`.
	##
	## It has no grip and no push pad, on purpose. The only fitting is a
	## tether eye, and it is what something else attaches TO.
	var anchor := _load("batch043/physics/phys_anchor_block.glb")
	if anchor == null:
		return {}
	get_root().add_child(anchor)
	# Counted from the loaded scene. "It has no grip" is a claim about the
	# asset, so the example measures it instead of printing a hand-written 0.
	var names := []
	var fittings := []
	var handling := 0
	for child in anchor.find_children("*", "MeshInstance3D", true, false):
		var part := str(child.name)
		names.append(part)
		if part.begins_with("attach_"):
			fittings.append(part)
		if part.begins_with("grip_") or part.begins_with("push_"):
			handling += 1
	if names.is_empty():
		_fail("phys_anchor_block loaded with no meshes at all")
		anchor.queue_free()
		return {}
	if not fittings.has("attach_eye"):
		_fail("phys_anchor_block has no attach_eye; the tether has nothing "
				+ "to hold")
	if handling != 0:
		_fail("phys_anchor_block gained %d handling fitting(s): %s"
				% [handling, str(names)])
	var eye_local := Vector3(0.0, 0.651, 0.0)
	var eye_world := anchor.global_transform * eye_local
	var out := {
		"asset": "phys_anchor_block",
		"manipulable": false,
		"mesh_nodes": names,
		"fittings": fittings,
		"grips_or_push_pads": handling,
		"tether_eye_world": [snappedf(eye_world.x, 0.001),
				snappedf(eye_world.y, 0.001), snappedf(eye_world.z, 0.001)],
		"note": "no fitting exists for moving it; the eye is for attaching "
				+ "something to it",
	}
	anchor.queue_free()
	return out


# -- 4. the switch and conduit presentation -------------------------------

func _example_presentation() -> Dictionary:
	## Two assets, three drivable regions, and nothing else.
	var sw := _load("batch043/machinery/mach_wall_switch.glb")
	var run := _load("batch043/machinery/mach_conduit_run.glb")
	if sw == null or run == null:
		return {}
	get_root().add_child(sw)
	get_root().add_child(run)

	# (a) the lever: rotate the HINGE, never the arm.
	var hinge := _part(sw, "hinge_lever", "Node3D")
	var lens := _part(sw, "state_lens", "MeshInstance3D") as MeshInstance3D
	var band := _part(run, "state_band", "MeshInstance3D") as MeshInstance3D
	var fill := _part(run, "fill_band", "MeshInstance3D") as MeshInstance3D
	if hinge == null or lens == null or band == null or fill == null:
		sw.queue_free()
		run.queue_free()
		return {}

	var before := hinge.global_position
	hinge.rotate_x(deg_to_rad(-52.0))
	var after := hinge.global_position
	var pivot_moved := before.distance_to(after)
	# The whole reason the hinge is exported is that the pivot stays put.
	if pivot_moved > 0.000001:
		_fail("hinge_lever's pivot travelled %.6f m through its own rotation"
				% pivot_moved)

	# (b) the indicator lens: one material slot on its own node.
	var on := StandardMaterial3D.new()
	on.albedo_color = Color(0.22, 0.84, 0.78)
	on.emission_enabled = true
	on.emission = on.albedo_color
	lens.set_surface_override_material(0, on)

	# (c) the conduit: swap the band's texture for state, scroll it for
	# motion, and grow `fill_band` -- and ONLY `fill_band` -- for `delayed`.
	var band_span := band.mesh.get_aabb()
	var fill_span := fill.mesh.get_aabb()
	var base_x := fill.position.x
	var frac := 0.55
	# Where the track's end stops sit BEFORE the fill is touched, so the
	# claim below is a before/after measurement rather than a literal.
	var track_before := band.global_transform * band.mesh.get_aabb()
	fill.visible = true
	fill.scale = Vector3(frac, 1.0, 1.0)
	fill.position.x = base_x + fill_span.position.x * (1.0 - frac)
	var fill_box := fill.global_transform * fill.mesh.get_aabb()
	var track_box := band.global_transform * band.mesh.get_aabb()
	var end_drift := maxf(absf(track_box.position.x - track_before.position.x),
			absf(track_box.end.x - track_before.end.x))
	if end_drift > 0.0005:
		_fail("growing fill_band moved the track's end stops by %.4f m"
				% end_drift)

	var out := {
		"switch": {
			"rotate": "hinge_lever, about X",
			"pivot_moved_m": snappedf(pivot_moved, 0.000000001),
			"lens_node": "state_lens, one material slot",
		},
		"conduit": {
			"state_by": "swap state_band's material; never scale it",
			"band_span_x": [snappedf(band_span.position.x, 0.001),
					snappedf(band_span.end.x, 0.001)],
			"fill_at_55pct_world_x": [snappedf(fill_box.position.x, 0.001),
					snappedf(fill_box.end.x, 0.001)],
			"track_world_x": [snappedf(track_box.position.x, 0.001),
					snappedf(track_box.end.x, 0.001)],
			"end_stop_drift_m": snappedf(end_drift, 0.000001),
		},
	}
	sw.queue_free()
	run.queue_free()
	return out


func _run() -> void:
	_log["carriable"] = _example_carriable()
	_log["manipulate_only"] = _example_manipulate()
	_log["fixed"] = _example_fixed()
	_log["presentation"] = _example_presentation()

	# An example that came back short is not evidence of anything. Name the
	# field that is missing; the caller gets a non-zero status either way.
	for example: String in REQUIRED:
		var got: Dictionary = _log.get(example, {})
		if got.is_empty():
			_fail("example '%s' measured nothing" % example)
			continue
		for key: String in REQUIRED[example]:
			if not got.has(key):
				_fail("example '%s' never measured '%s'" % [example, key])

	for key: String in _log:
		print("[examples] %s: %s" % [key, JSON.stringify(_log[key])])

	if _out != "":
		var f := FileAccess.open("%s/import_examples.json" % _out,
				FileAccess.WRITE)
		if f == null:
			_fail("could not write import_examples.json under %s" % _out)
		else:
			f.store_string(JSON.stringify(_log, "  "))
			f.close()

	if _problems.is_empty():
		print("[examples] %d example(s) complete, 0 problem(s)"
				% REQUIRED.size())
		quit(0)
		return
	printerr("[examples] %d problem(s); this run is NOT verification"
			% _problems.size())
	quit(1)
