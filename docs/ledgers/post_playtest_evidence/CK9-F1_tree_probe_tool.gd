extends Node
## CK9-F1 probe: build one Zone file with ZoneBuilder.build, put it in the
## tree, and print every Node3D under it with its global position, in tree
## order -- so two revisions' builds can be diffed node for node.
##   godot --headless --path godot res://ck9_probe_tmp.tscn -- ZONE.json

func _ready() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(args[0]))
	var build: Dictionary = ZoneBuilder.build(zone, "",
			ZoneController.PLACEMENT_BUDGET_MS, {})
	if build.has("failed"):
		print("TREE failed ", build["failed"])
		get_tree().quit()
		return
	var root: Node3D = build["root"]
	add_child(root)
	await get_tree().physics_frame
	var n := 0
	for node: Node in root.find_children("*", "Node3D", true, false):
		var at := (node as Node3D).global_position.snapped(Vector3.ONE * 0.001)
		print("TREE %s %s %s" % [str(root.get_path_to(node)), node.get_class(), str(at)])
		n += 1
	print("TREE nodes %d" % n)
	get_tree().quit()
