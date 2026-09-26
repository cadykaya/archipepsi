extends Node
## HB-F4e observation: where zone_012 c001's rail and powered door stand.
func _ready() -> void:
	var zone: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var chamber: Dictionary = {}
	for c: Dictionary in zone["chambers"]:
		if str(c["id"]) == "c001":
			chamber = c.duplicate(true)
	chamber["zone_id"] = "zone_012"
	var built := ChamberBuilders.build(chamber, "temple_ruin")
	var root: Node3D = built["root"]
	for f: Node in built["features"]:
		var n := f as Node3D
		print("RAIL feature %s node %s at %s" % [str(n.get_meta("affordance_tag", "?")), n.get_class(), str(n.position)])
		if n.get_meta("affordance_tag", "") == "powered_door":
			for child: Node in n.get_children():
				if child is StaticBody3D:
					var cs := child.get_child(0) as CollisionShape3D
					if cs and cs.shape is BoxShape3D:
						print("RAIL  alcove solid at %s size %s" % [str(n.position + (child as Node3D).position), str((cs.shape as BoxShape3D).size)])
				if child is PoweredLink:
					print("RAIL  link (plate) at %s" % str(n.position + (child as Node3D).position))
	for child: Node in root.get_children():
		if child is LocalRewardPickup:
			print("RAIL reward %s at %s" % [str(child.name), str((child as Node3D).position)])
	root.free()
	get_tree().quit()
