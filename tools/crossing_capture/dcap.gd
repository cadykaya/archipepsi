extends SceneTree
## CROSSING D, PHOTOGRAPHED FOR THE ART LANE (Arty, 2026-10-08).
##
## A SceneTree script, run against a READ-ONLY checkout of Production's
## Crossing D review build. It edits nothing of Production's: it builds
## Production's own `CrossingD` host in isolation (`--crossing-d`, so
## `BridgeClient` never opens a socket and nothing is saved), lets it
## settle, then photographs it from fixed cameras. Anything it changes
## for a study -- a texture swapped, a candidate model placed, a crate
## hidden -- happens in this process's memory only.
##
##   godot --path <checkout>/godot --resolution 1600x900 \
##       -s res://tests/_arty_dcap.gd -- --crossing-d [--empty-yard] \
##       --dcap=<spec.json> --out=<dir>
##
## or, for the Impact Lab: `-- --impact-lab` with "host" set in the spec.
##
## The spec (JSON):
##   "texture_swap": {"wall": "/abs/x.png", ...}  a theme role -> image;
##       every cached theme material painted from
##       `concrete_facility_<role>.png` takes the replacement.
##   "glbs": [{"path": "/abs/x.glb", "origin": [x, y, z],
##       "basis": [[Xx, Xy, Xz], [Yx, ...], [Zx, ...]] or "yaw_deg": d,
##       "scale": s}]  placed under the room; `-colonly` nodes hidden.
##   "hide": ["NameFragment", ...]  any room node whose name contains one.
##   "hide_boxes_of": ["pads", "covers"]  the BoxMesh visuals of a room list.
##   "retexture": [{"match": "Ceiling", "png": "/abs.png"}]  per-node repaint.
##   "calls": [["method", [args]]]  on the room, before shooting.
##   "shots": [{"name": n, "eye": [x, y, z], "look": [x, y, z],
##       "fov": 90, "gray": false}]
## Every shot is also written in grayscale when "gray" is true.

var _spec: Dictionary = {}
var _out := ""
var _host: Node = null


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dcap="):
			var text := FileAccess.get_file_as_string(arg.trim_prefix("--dcap="))
			_spec = JSON.parse_string(text)
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _run() -> void:
	# The review host to build: Crossing D by default; the Impact Lab
	# (`res://scripts/content/impact_lab.gd`, flag `--impact-lab`) works
	# the same way -- `room` and `player` members, isolated by its flag.
	_host = load(str(_spec.get("host",
			"res://scripts/content/crossing_d.gd"))).new()
	root.add_child(_host)
	for _i in int(_spec.get("settle_frames", 90)):
		await physics_frame
	var room: Node3D = _host.get("room")
	# The player stays where the host put it, switched off: these are
	# framed shots, not a walk.
	var player: Node3D = _host.get("player")
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
	for layer in _all(root, "CanvasLayer"):
		(layer as CanvasLayer).visible = false
	_swap_textures(_spec.get("texture_swap", {}))
	# Per-node repaint: every mesh under a room node whose name contains
	# "match" gets its own copy of its material with "png" as the albedo
	# (same triplanar scale and filtering). Used to show a ceiling painted
	# with the theme's ceiling role instead of the shared trim material.
	for item: Dictionary in _spec.get("retexture", []):
		var texture := ImageTexture.create_from_image(
				Image.load_from_file(str(item["png"])))
		for node in _all(room, "Node3D"):
			if not str(item["match"]) in str(node.name):
				continue
			var meshes: Array[Node] = _all(node, "MeshInstance3D")
			if node is MeshInstance3D:
				meshes.append(node)
			for mesh in meshes:
				var part := mesh as MeshInstance3D
				var was := part.material_override as StandardMaterial3D
				if was == null and part.mesh != null:
					was = part.mesh.surface_get_material(0) as StandardMaterial3D
				if was == null:
					continue
				var copy := was.duplicate() as StandardMaterial3D
				copy.albedo_texture = texture
				part.material_override = copy
				print("[dcap] retextured ", part.get_path())
	for fragment: String in _spec.get("hide", []):
		for node in _all(room, "Node3D"):
			if fragment in str(node.name):
				(node as Node3D).visible = false
	# Hide the code-built BOX meshes of the room's own lists ("pads",
	# "covers": a LaunchPad's slab, a DestructibleCover's block and its
	# band) and nothing else: a pad's arc pips are spheres and stay,
	# because they are the solved trajectory. By list, not by name: Godot
	# renames a duplicate sibling after its type.
	for list_name: String in _spec.get("hide_boxes_of", []):
		var owners: Variant = room.get(list_name)
		if owners is Node:
			owners = [owners]
		for owner_node in owners:
			for mesh in _all(owner_node, "MeshInstance3D"):
				if (mesh as MeshInstance3D).mesh is BoxMesh:
					(mesh as Node3D).visible = false
	# Resize code-built boxes by name, in their own frame (D's straights
	# are `_profile` boxes: x along the run, y out of the surface, z
	# across), with an optional shift along their own y. For the power
	# stripe width study.
	for item: Dictionary in _spec.get("resize_boxes", []):
		for node in _all(room, "MeshInstance3D"):
			var part := node as MeshInstance3D
			if not str(item["match"]) in str(part.name) \
					or not part.mesh is BoxMesh:
				continue
			var box := (part.mesh as BoxMesh).duplicate() as BoxMesh
			box.size = Vector3(box.size.x, float(item.get("y", box.size.y)),
					float(item.get("z", box.size.z)))
			part.mesh = box
			part.position += part.transform.basis.y.normalized() \
					* float(item.get("shift_y", 0.0))
	for call: Array in _spec.get("calls", []):
		room.callv(str(call[0]), call[1] if call.size() > 1 else [])
	for item: Dictionary in _spec.get("glbs", []):
		_place(room, item)
	# A material made to emit, by its name in the placed GLBs:
	# {"ca_orange": {"color": "#f48a36", "energy": 2.0}} -- for a state
	# that lives on a shared material (a seal's seam collars).
	var emits: Dictionary = _spec.get("material_emit", {})
	if not emits.is_empty():
		for node in _all(room, "MeshInstance3D"):
			var part := node as MeshInstance3D
			if part.mesh == null:
				continue
			for i in part.mesh.get_surface_count():
				var m := part.mesh.surface_get_material(i) as StandardMaterial3D
				if m == null or not emits.has(m.resource_name):
					continue
				var want: Dictionary = emits[m.resource_name]
				var lit := m.duplicate() as StandardMaterial3D
				lit.emission_enabled = true
				lit.emission = Color(str(want["color"]))
				lit.emission_energy_multiplier = float(want["energy"])
				part.set_surface_override_material(i, lit)
	# Study lights: [{"at": [x, y, z], "color": "#rrggbb", "energy": e,
	# "range": r}], omni, no shadows -- the overlay's own light.
	for item: Dictionary in _spec.get("lights", []):
		var lamp := OmniLight3D.new()
		lamp.position = _vec(item["at"])
		lamp.light_color = Color(str(item.get("color", "#ffffff")))
		lamp.light_energy = float(item.get("energy", 1.0))
		lamp.omni_range = float(item.get("range", 10.0))
		room.add_child(lamp)
	for _i in 10:
		await physics_frame
	if bool(_spec.get("freeze_enemies", true)) and room.get("enemies") != null:
		for enemy in room.get("enemies"):
			(enemy as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	for enemy in (room.get("enemies") if room.get("enemies") != null else []):
		print("[dcap] enemy %s at %s" % [enemy.get("archetype"),
				(enemy as Node3D).global_position])
	for shot: Dictionary in _spec.get("shots", []):
		var eye := Vector3.ZERO
		var look := Vector3.ZERO
		if shot.has("enemy"):
			# Framed on where the enemy actually stands now: `dist` metres
			# away along `from` (plan), at the player's eye height.
			var who: Node3D = null
			for enemy in room.get("enemies"):
				if str(enemy.get("archetype")) == str(shot["enemy"]):
					who = enemy
			var away := Vector3(float(shot["from"][0]), 0.0,
					float(shot["from"][1])).normalized()
			eye = who.global_position + away * float(shot["dist"]) \
					+ Vector3(0, 1.6, 0)
			look = who.global_position + Vector3(0, float(shot.get("aim_y", 0.6)), 0)
		else:
			eye = _vec(shot["eye"])
			look = _vec(shot["look"])
		camera.fov = float(shot.get("fov", 90.0))
		camera.near = 0.05
		camera.far = 400.0
		camera.position = eye
		camera.look_at(look, Vector3.UP)
		for _i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(_out.path_join(str(shot["name"]) + ".png"))
		if bool(shot.get("gray", false)):
			image.adjust_bcs(1.0, 1.0, 0.0)
			image.save_png(_out.path_join(str(shot["name"]) + "_gray.png"))
		print("[dcap] ", shot["name"])
	quit(0)


func _swap_textures(swaps: Dictionary) -> void:
	if swaps.is_empty():
		return
	var cache: Dictionary = ThemeMaterials._cache
	for key in cache:
		var material := cache[key] as StandardMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var path := str(material.albedo_texture.resource_path)
		for role: String in swaps:
			if path.ends_with("concrete_facility_%s.png" % role):
				var image := Image.load_from_file(str(swaps[role]))
				material.albedo_texture = ImageTexture.create_from_image(image)
				print("[dcap] swapped ", path)


func _place(room: Node3D, item: Dictionary) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(str(item["path"]), state)
	assert(err == OK, "could not read " + str(item["path"]))
	var scene := document.generate_scene(state) as Node3D
	var basis := Basis.IDENTITY
	if item.has("basis"):
		var b: Array = item["basis"]
		basis = Basis(_vec(b[0]), _vec(b[1]), _vec(b[2]))
	elif item.has("yaw_deg"):
		basis = Basis(Vector3.UP, deg_to_rad(float(item["yaw_deg"])))
	basis = basis.scaled(Vector3.ONE * float(item.get("scale", 1.0)))
	scene.transform = Transform3D(basis, _vec(item["origin"]))
	room.add_child(scene)
	for node in _all(scene, "Node3D"):
		if "colonly" in str(node.name):
			(node as Node3D).visible = false
	# A state for the study: name -> {"rotation_deg": [x, y, z],
	# "position": [..], "visible": bool, "emit": "#rrggbb"}.
	var poses: Dictionary = item.get("pose", {})
	for node in _all(scene, "Node3D"):
		if poses.has(str(node.name)):
			var pose: Dictionary = poses[str(node.name)]
			if pose.has("rotation_deg"):
				var r := _vec(pose["rotation_deg"])
				(node as Node3D).rotation_degrees = r
			if pose.has("position"):
				(node as Node3D).position = _vec(pose["position"])
			if pose.has("visible"):
				(node as Node3D).visible = bool(pose["visible"])
			if pose.has("emit") and node is MeshInstance3D:
				var lit := StandardMaterial3D.new()
				var colour := Color(str(pose["emit"]))
				lit.albedo_color = colour
				lit.emission_enabled = true
				lit.emission = colour
				lit.emission_energy_multiplier = float(pose.get("energy", 0.6))
				(node as MeshInstance3D).material_override = lit


func _all(from: Node, type: String) -> Array[Node]:
	var found: Array[Node] = []
	if from == null:
		return found
	for node in from.find_children("*", type, true, false):
		found.append(node)
	return found


func _vec(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
