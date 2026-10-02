extends Node
## CK9 flyer-room probe: lay one Zone file out as ZoneBuilder.build does
## and print every room's pose, and which rooms are joined to which.
##   godot --headless --path godot res://ck9_probe_tmp.tscn -- ZONE.json

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(args[0]))
	var build: Dictionary = ZoneBuilder.build(zone, "",
			ZoneController.PLACEMENT_BUDGET_MS, {})
	if build.has("failed"):
		print("PROBE failed ", build["failed"])
		get_tree().quit()
		return
	print("PROBE attempts %d nudges %s" % [
			int(build.get("placement_attempts", 1)),
			str(build.get("placement_nudges", {}))])
	var rooms: Dictionary = build.get("rooms", {})
	var ids: Array = rooms.keys()
	ids.sort()
	for rid: Variant in ids:
		var p: Dictionary = rooms[rid]
		print("PROBE room %s at %s yaw %s bounds %s" % [rid,
				str(p.get("position")), str(p.get("yaw")),
				str(p.get("bounds"))])
	var joins: Dictionary = build.get("joins", {})
	var eids: Array = joins.keys()
	eids.sort()
	for eid: Variant in eids:
		var j: Dictionary = joins[eid]
		print("PROBE join %s %s/%s -> %s/%s pieces %d" % [eid,
				str(j.get("room_a")), str(j.get("socket_a")),
				str(j.get("room_b")), str(j.get("socket_b")),
				(j.get("chain", []) as Array).size()])
	(build["root"] as Node).free()
	get_tree().quit()
