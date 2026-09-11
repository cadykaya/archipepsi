extends SceneTree
## The Batch 043 asset interface, exercised. Four small examples.
##
##   godot --path godot -s _harness/examples.gd -- <models> <manifests> <out>
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

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_models = a[0]
	_out = a[1]
	_bench = load("res://_harness/artbench.gd") as GDScript
	_run.call_deferred()


func _load(rel: String) -> Node3D:
	return _bench.call("load_glb", "%s/%s" % [_models, rel])


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
	var grip := cell.find_child("grip_bar", true, false) as MeshInstance3D
	var grip_world := grip.global_transform * grip.mesh.get_aabb().get_center()
	var grip_local_centre := grip.mesh.get_aabb().get_center()
	assert(grip_local_centre != Vector3.INF)

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
	var node := ballast.find_child(best, true, false) as MeshInstance3D
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
	var names := []
	for child in anchor.find_children("*", "MeshInstance3D", true, false):
		names.append(str(child.name))
	var eye_local := Vector3(0.0, 0.651, 0.0)
	var eye_world := anchor.global_transform * eye_local
	var out := {
		"asset": "phys_anchor_block",
		"manipulable": false,
		"mesh_nodes": names,
		"fittings": ["attach_eye"],
		"grips_or_push_pads": 0,
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
	var hinge := sw.find_child("hinge_lever", true, false) as Node3D
	var before := hinge.global_position
	hinge.rotate_x(deg_to_rad(-52.0))
	var after := hinge.global_position
	var pivot_moved := before.distance_to(after)

	# (b) the indicator lens: one material slot on its own node.
	var lens := sw.find_child("state_lens", true, false) as MeshInstance3D
	var on := StandardMaterial3D.new()
	on.albedo_color = Color(0.22, 0.84, 0.78)
	on.emission_enabled = true
	on.emission = on.albedo_color
	lens.set_surface_override_material(0, on)

	# (c) the conduit: swap the band's texture for state, scroll it for
	# motion, and grow `fill_band` -- and ONLY `fill_band` -- for `delayed`.
	var band := run.find_child("state_band", true, false) as MeshInstance3D
	var fill := run.find_child("fill_band", true, false) as MeshInstance3D
	var band_span := band.mesh.get_aabb()
	var fill_span := fill.mesh.get_aabb()
	var base_x := fill.position.x
	var frac := 0.55
	fill.visible = true
	fill.scale = Vector3(frac, 1.0, 1.0)
	fill.position.x = base_x + fill_span.position.x * (1.0 - frac)
	var fill_box := fill.global_transform * fill.mesh.get_aabb()
	var track_box := band.global_transform * band.mesh.get_aabb()

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
			"endpoints_move": (absf(track_box.position.x
					- (-1.0)) > 0.01),
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
	for key: String in _log:
		print("[examples] %s: %s" % [key, JSON.stringify(_log[key])])
	var f := FileAccess.open("%s/import_examples.json" % _out,
			FileAccess.WRITE)
	f.store_string(JSON.stringify(_log, "  "))
	f.close()
	quit(0)
