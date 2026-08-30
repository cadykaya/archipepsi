extends SceneTree
## The Godot half of `tools/export_content_pack.sh`: wrap each exported .glb
## in the Node3D root the registry names, and let GODOT write the .tscn so the
## header, the format version and the ext_resource reference are correct by
## construction rather than by hand-authoring a file format.
##
## The instanced .glb keeps its own ownership. Re-owning its children makes
## Godot serialise the whole mesh INTO the .tscn -- a 40 KB scene carrying a
## duplicate of geometry that is already in the .glb next to it, and a second
## copy to keep in sync. An instance is a reference; that is the point of one.
func _initialize() -> void:
	var text := FileAccess.get_file_as_string("res://content/SCENE_PLAN.json")
	# SCENE_PLAN.json carries two things now: the `scenes` this step builds,
	# and the art-side `provenance` that used to ride illegally in the
	# registry manifest. Read the half that is ours.
	var doc: Dictionary = JSON.parse_string(text)
	var plan: Array = doc.get("scenes", [])
	var made := 0
	for raw in plan:
		var row: Dictionary = raw
		var glb: String = str(row["glb"])
		var out := "res://content/%s/%s.tscn" % [
				str(row["kind"]), str(row["content_id"])]
		var src: PackedScene = load(glb)
		if src == null:
			push_error("wrap: cannot load %s" % glb)
			continue
		var inner: Node = src.instantiate()
		inner.name = "Mesh"
		var root := Node3D.new()
		root.name = str(row["content_id"])
		root.add_child(inner)
		inner.owner = root
		var packed := PackedScene.new()
		if packed.pack(root) != OK:
			push_error("wrap: cannot pack %s" % out)
			root.free()
			continue
		if ResourceSaver.save(packed, out) != OK:
			push_error("wrap: cannot save %s" % out)
		else:
			made += 1
		root.free()
	print("[wrap] %d scenes" % made)
	quit()
