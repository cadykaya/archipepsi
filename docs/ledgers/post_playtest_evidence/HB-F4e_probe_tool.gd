extends Node
## HB-F4e probe: lay out one Zone file exactly as the layout walk does,
## then replay ONE room's powered_door chain the way `ChainCertificate
## .certify` does, printing what the crate meets on its way to the plate.
##   godot --headless --path godot res://probe_tmp.tscn -- IN ROOM_ID

func _ready() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(args[0]))
	var rid := str(args[1])
	var build: Dictionary = ZoneBuilder.build(zone, "",
			ZoneController.PLACEMENT_BUDGET_MS, {})
	if build.has("failed"):
		print("PROBE build failed: ", build["failed"])
		get_tree().quit()
		return
	add_child(build["root"] as Node3D)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var node: Node3D = null
	for raw: Variant in build.get("chambers", []):
		var entry: Dictionary = raw
		if str((entry["chamber"] as Dictionary).get("id", "")) == rid:
			node = entry["node"]
	if node == null:
		print("PROBE no room ", rid)
		get_tree().quit()
		return
	var chains := ChainCertificate.chains_in(node)
	print("PROBE room %s at %s, %d chain(s)" % [rid,
			str(node.global_transform.origin), chains.size()])
	for chain: Dictionary in chains:
		await _probe(chain, node)
	get_tree().quit()


func _probe(chain: Dictionary, room: Node3D) -> void:
	var link: PoweredLink = chain["link"]
	var crate: ManipulableBody = chain["crate"]
	var rig := link.get_parent() as Node3D
	print("PROBE rig global %s basis-z %s" % [str(rig.global_position),
			str(rig.global_basis.z)])
	print("PROBE crate spawned at %s (room-local %s)" % [
			str(crate.global_position),
			str(room.to_local(crate.global_position))])
	crate.contact_monitor = true
	crate.max_contacts_reported = 16
	# SETTLE, as `certify` does, but watched.
	for i in int(ChainCertificate.SETTLE_TIMEOUT_S
			* Engine.physics_ticks_per_second):
		if crate.at_rest():
			print("PROBE at rest after %d frame(s)" % i)
			break
		await get_tree().physics_frame
	print("PROBE crate settled at %s v=%s touching %s" % [
			str(crate.global_position), str(crate.linear_velocity),
			_names(crate.get_colliding_bodies())])
	var home := crate.global_transform
	var plate := ChainCertificate.plate_region(link)
	print("PROBE plate region %s (centre %s); link.plate_position %s" % [
			str(plate), str(plate.get_center()),
			str(link.plate_position())])
	print("PROBE threshold %.1f kg, crate %.1f kg" % [link.threshold_kg,
			crate.mass])
	var toward := link.plate_position() - home.origin
	toward.y = 0.0
	var gap := toward.length()
	var dir := toward / gap
	var seconds := ChainCertificate._push_seconds(crate.mass, gap)
	print("PROBE gap %.3f m, dir %s, push %.2f s" % [gap, str(dir), seconds])
	# What stands between the crate and the plate, at crate height.
	var space := get_viewport().world_3d.direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.6, gap + 0.7)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	var mid := home.origin + toward * 0.5 + Vector3(0, 0.1, 0)
	q.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), mid)
	q.exclude = [crate.get_rid()]
	q.collide_with_areas = false
	var hits := space.intersect_shape(q, 32)
	var named := []
	for h: Dictionary in hits:
		var c: Object = h["collider"]
		named.append("%s(%s)" % [_path(c), c.get_class()])
	print("PROBE solids in the lane crate->plate: %s" % str(named))
	for h: Dictionary in hits:
		_describe(h["collider"], room)
	for run in 3:
		ChainCertificate._reset(crate, home)
		var envelope := Manipulation.Envelope.at_the_envelope()
		var frames := maxi(1, int(round(seconds
				* Engine.physics_ticks_per_second)))
		var entered := false
		var touched := {}
		var refused := {}
		for f in frames:
			var host := crate.global_position - Vector3(dir.x, -0.6,
					dir.z) * 2.0
			var r := Manipulation.push(crate, host,
					crate.global_position + dir * 10.0, envelope)
			if str(r.get("refused", "")) != "":
				refused[str(r["refused"])] = true
			await get_tree().physics_frame
			for b: Node in crate.get_colliding_bodies():
				touched[_path(b)] = true
			if plate.has_point(crate.global_position):
				entered = true
			if f % 6 == 0 or f == frames - 1:
				print("PROBE run %d f%02d pos %s v %s in_plate %s" % [run, f,
						str(crate.global_position),
						str(crate.linear_velocity),
						plate.has_point(crate.global_position)])
		for f in int(ChainCertificate.SETTLE_TIMEOUT_S
				* Engine.physics_ticks_per_second):
			await get_tree().physics_frame
			for b: Node in crate.get_colliding_bodies():
				touched[_path(b)] = true
			if plate.has_point(crate.global_position):
				entered = true
			if crate.at_rest():
				break
		print("PROBE run %d END pos %s entered %s refused %s touched %s" % [
				run, str(crate.global_position), entered,
				str(refused.keys()), str(touched.keys())])


func _names(bodies: Array) -> String:
	var out := []
	for b: Node in bodies:
		out.append(_path(b))
	return str(out)


func _path(o: Object) -> String:
	var n := o as Node
	if n == null:
		return str(o)
	var parts := []
	var at := n
	for _i in 4:
		if at == null or at == self:
			break
		parts.push_front(str(at.name))
		at = at.get_parent()
	return "/".join(parts)


func _describe(o: Object, room: Node3D) -> void:
	var body := o as CollisionObject3D
	if body == null:
		return
	var parent := body.get_parent()
	var mesh := ""
	if parent is MeshInstance3D:
		var mi := parent as MeshInstance3D
		mesh = "%s %s aabb %s" % [mi.mesh.get_class() if mi.mesh else "-",
				str(mi.mesh.get_aabb().size) if mi.mesh else "-",
				str(mi.get_aabb())]
	var shapes := []
	for c: Node in body.get_children():
		if c is CollisionShape3D:
			var cs := c as CollisionShape3D
			var sh := cs.shape
			var dims := ""
			if sh is BoxShape3D:
				dims = str((sh as BoxShape3D).size)
			elif sh is CylinderShape3D:
				dims = "r %.2f h %.2f" % [(sh as CylinderShape3D).radius,
						(sh as CylinderShape3D).height]
			shapes.append("%s %s at %s" % [sh.get_class(), dims,
					str(cs.global_position)])
	var metas := {}
	for at: Node in [body, parent, parent.get_parent() if parent else null]:
		if at == null:
			continue
		for m: StringName in at.get_meta_list():
			metas["%s.%s" % [at.name, m]] = str(at.get_meta(m))
	print("PROBE  solid %s: global %s room-local %s; parent %s (%s) %s; shapes %s; groups %s; metas %s" % [
			body.name, str(body.global_position),
			str(room.to_local(body.global_position)),
			str(parent.name) if parent else "-",
			parent.get_class() if parent else "-", mesh, str(shapes),
			str(body.get_groups() + (parent.get_groups() if parent else [])),
			str(metas)])
