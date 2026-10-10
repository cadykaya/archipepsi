extends SceneTree
## Track D -- the two packs' materials on the SAME ROOM.
##
## Flat textures side by side answer "are these different pixels". The
## question the owner is actually deciding is "are these different
## PLACES", and that is only visible on geometry, at room scale, under
## one light, with everything else held still. So: one shell, three
## renders -- the family, then each pack -- through Production's own
## `ThemeMaterials`, which is what will bind them in the game.
##
## The renders are produced under `use_pack_status`, the resolver's own
## review hook, because these packs are CANDIDATES and a candidate does
## not bind. `run_pack_resolution.sh` is the harness that proves that
## refusal; this one is the review screen the refusal makes room for.

const REVIEW_STATE := "selectable"
const THEME := "temple_ruin"
const ROLES := ["floor", "wall", "accent", "trim"]

var _bench: GDScript
var _pack: GDScript
var _mats: GDScript
var _out := ""
var _models := ""
var _shell := ""
var _faults: Array[String] = []
var _shots := {}


func _bad(what: String) -> void:
	_faults.append(what)
	print("[packview] FAULT: %s" % what)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("[packview] need <out dir> <models dir> <shell>")
		quit(1)
		return
	_out = a[0]
	_models = a[1]
	_shell = a[2]
	_bench = load("res://_harness/artbench.gd") as GDScript
	_pack = load("res://_harness/prod_theme_pack.gd") as GDScript
	_mats = load("res://_harness/prod_theme_materials.gd") as GDScript
	if _bench == null or _pack == null or _mats == null:
		push_error("[packview] the harness is not staged")
		quit(1)
		return
	await _run()


func _skin(pack: String) -> void:
	if pack == "":
		return
	_pack.call("use_pack_status", {pack: REVIEW_STATE})
	_mats.call("bind_pack", pack, self)
	if str(_mats.call("bound_pack")) != pack:
		_bad("ThemeMaterials did not bind '%s'; it reports '%s'"
			 % [pack, _mats.call("bound_pack")])


func _unskin(pack: String) -> void:
	if pack == "":
		return
	_mats.call("release_pack", self)
	_pack.call("clear_pack_status")
	if _pack.call("pack_binds", pack):
		_bad("'%s' still binds after the review override was cleared"
			 % pack)


func _shoot(pack: String, label: String) -> void:
	_mats.call("reset_cache")
	_pack.call("reset")
	_skin(pack)
	var view: SubViewport = _bench.call("make_viewport", self,
			Vector2i(960, 600), 0.35)
	var holder := Node3D.new()
	view.add_child(holder)
	var shell: Node3D = _bench.call("load_glb",
			"%s/%s.glb" % [_models, _shell])
	if shell == null:
		_bad("could not load %s/%s.glb" % [_models, _shell])
		return
	holder.add_child(shell)

	# The shell's baked surfaces carry their role in `resource_name`,
	# which is what makes a re-skin possible without a mapping table
	# this lane would have to keep in step.
	var swapped := 0
	for child in shell.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var had: Material = mi.mesh.surface_get_material(i)
			var role := "wall" if had == null else str(had.resource_name)
			if not (role in ROLES):
				continue
			var built: Variant = _mats.call("%s_mat" % role, THEME)
			if built != null:
				mi.set_surface_override_material(i, built)
				swapped += 1
	if swapped == 0:
		_bad("%s re-materialled nothing, so this frame is the .glb's own "
			 % label + "baked materials wearing somebody else's caption")

	var env := (view.get_node_or_null("WorldEnvironment") as WorldEnvironment)
	if env != null:
		env.environment.ambient_light_color = Color(0.74, 0.76, 0.80)
		env.environment.ambient_light_energy = 0.85
	var lamp := OmniLight3D.new()
	lamp.omni_range = 24.0
	lamp.light_energy = 3.2
	lamp.position = Vector3(0.0, 3.0, 0.0)
	holder.add_child(lamp)
	var box: AABB = _bench.call("aabb_of", shell)
	# INSIDE the room, at eye height. `frame_camera` frames a whole AABB
	# from outside it, which for a shell means looking at the roof -- and
	# a wall material is judged by somebody standing in front of the
	# wall, not by somebody on top of the building.
	var cam := Camera3D.new()
	cam.fov = 70.0
	view.add_child(cam)
	var centre := box.get_center()
	var eye := Vector3(centre.x - box.size.x * 0.30,
			box.position.y + 1.6,
			centre.z - box.size.z * 0.30)
	cam.position = eye
	cam.look_at_from_position(eye, Vector3(centre.x + box.size.x * 0.22,
			box.position.y + 1.35, centre.z + box.size.z * 0.22),
			Vector3.UP)
	lamp.position = eye + Vector3(0.0, 1.1, 0.0)

	await process_frame
	await process_frame
	var image := view.get_texture().get_image()
	_bench.call("label", image, "PROPOSAL -- CANDIDATE PACK, NOT SELECTED, "
			+ "NOT OWNER-APPROVED", Vector2i(14, 14), Color(1, 0.86, 0.3))
	_bench.call("label", image, label, Vector2i(14, 34),
			Color(0.84, 0.86, 0.90))
	_bench.call("label", image, "%s, %s, %d surface(s) re-skinned "
			% [THEME, _shell, swapped]
			+ "(floor wall accent trim)", Vector2i(14, 52),
			Color(0.66, 0.70, 0.76))
	# Said out loud rather than quietly cropped out: no `ceiling_mat`
	# exists, so the ceiling in every one of these frames is the shell's
	# own baked material and is NOT evidence about any pack.
	_bench.call("label", image, "ceiling is the shell's baked material, "
			+ "not the pack's", Vector2i(14, 70), Color(0.60, 0.62, 0.66))
	var name := "PACK_%s" % (pack if pack != "" else "family_backstop")
	if image.save_png("%s/%s.png" % [_out, name]) != OK:
		_bad("could not write %s" % name)
	_shots[name] = image
	print("[packview] %s: %d surface(s) re-skinned" % [name, swapped])
	_unskin(pack)
	view.queue_free()


func _differ(a: Image, b: Image) -> int:
	var moved := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				moved += 1
	return moved


func _run() -> void:
	await _shoot("", "the family alone -- what a Zone gets today")
	await _shoot("forest_temple", "T01 forest_temple -- Ocarina of Time")
	await _shoot("twilight_town", "T05 twilight_town -- Kingdom Hearts 2")

	# THREE IDENTICAL RENDERS WOULD ALSO PRINT THREE SUCCESSES. If the
	# pack never reached the material, every frame here is the family
	# and the sheet is a lie told in triplicate -- so the frames are
	# required to differ from each other, and from the family.
	var names := _shots.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var moved := _differ(_shots[names[i]], _shots[names[j]])
			if moved == 0:
				_bad("%s and %s are the same image; the pack did not reach "
					 % [names[i], names[j]] + "the material")
			else:
				print("[packview] %s vs %s: %d sampled pixel(s) differ"
					  % [names[i], names[j], moved])

	if _faults.is_empty():
		print("[packview] PASS -- one shell, three skins, all different")
	else:
		push_error("[packview] %d fault(s)" % _faults.size())
	quit(0 if _faults.is_empty() else 1)
