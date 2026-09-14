extends SceneTree
## What names GODOT exposes for each shipped shell's surfaces.
##
##   godot --headless --path godot -s _harness/imported.gd -- <out.json>
##
## INSPECTION ONLY. The glTF file says one thing; the imported resource is
## what a binder would actually walk, and the two are not required to
## agree. Blender writes `cl_floor.003`; Godot's importer may keep it,
## rename it, or leave `resource_name` empty and leave only the surface
## INDEX to bind by. Which of those is true decides whether a role can be
## recovered at runtime at all, so it is measured rather than assumed.

const SHELLS := [
	"shell_corner_left", "shell_corner_right", "shell_hall_transit",
	"shell_plenum_helix", "shell_span_basin", "shell_tower_collapsed",
	"shell_tower_gantry", "shell_tower_spiral", "shell_treasure_cache",
	"shell_treasure_coffer", "shell_treasure_vault", "shell_yard_gantry",
]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/imported.json"
	var report := {}
	for id in SHELLS:
		report[id] = _walk(id)
	var fh := FileAccess.open(out, FileAccess.WRITE)
	fh.store_string(JSON.stringify(report, "  ", true))
	fh.close()
	print("[imported] wrote %s" % out)
	quit(0)

func _walk(id: String) -> Dictionary:
	var path := "res://content/shells/%s.tscn" % id
	if not ResourceLoader.exists(path):
		return {"error": "missing %s" % path}
	var packed := load(path) as PackedScene
	var root := packed.instantiate()
	var meshes: Array = []
	_collect(root, root, meshes)
	root.free()
	var names: Array = []
	var blank := 0
	var surfaces := 0
	for m in meshes:
		for s in m["materials"]:
			surfaces += 1
			if s == "":
				blank += 1
			else:
				names.append(s)
	return {
		"mesh_instances": meshes.size(),
		"surfaces": surfaces,
		"named_surfaces": names.size(),
		"blank_names": blank,
		"names": names,
		"detail": meshes,
	}

func _collect(node: Node, root: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mats: Array = []
		var mesh := mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				mats.append("" if mat == null else mat.resource_name)
		out.append({
			"path": String(root.get_path_to(mi)),
			"surface_count": mats.size(),
			"materials": mats,
			"mesh_resource_path": "" if mesh == null else mesh.resource_path,
		})
	for child in node.get_children():
		_collect(child, root, out)
