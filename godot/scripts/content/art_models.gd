class_name ArtModels
extends RefCounted
## The approved art models the game loads as plain meshes (ART-CATCHUP):
## single-mesh glbs whose one node carries no transform, so the mesh IS
## the model. Returns null when the model is not shipped, and every caller
## keeps its code-built fallback for that case.

static var _cache := {}

static func mesh(path: String) -> Mesh:
	if _cache.has(path):
		return _cache[path]
	var found: Mesh = null
	if ResourceLoader.exists(path):
		var scene := (load(path) as PackedScene).instantiate()
		for m: Node in scene.find_children("*", "MeshInstance3D", true, false):
			found = (m as MeshInstance3D).mesh
			break
		scene.free()
	_cache[path] = found
	return found


## The index of the surface whose material is named `*<suffix>`, or -1.
static func surface(m: Mesh, suffix: String) -> int:
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		if mat != null and mat.resource_name.ends_with(suffix):
			return i
	return -1
