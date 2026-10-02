extends Node
## Lay out one Zone file with this revision's `ZoneBuilder`, exactly as
## `ZoneController.setup` does on a first visit, MEASURE it as a played
## Zone is measured -- standing in the tree, settled, `RoomAudit
## .measure_layout` for apertures and arrivals, `ChainCertificate.of_build`
## for the chains (the path `graph_driver --sample` takes) -- and write
## what the client would send: {"layout": ZoneBuilder.layout_to_json(build)}
## for a `layout_result`, or {"failed": reason} for a `build_failed`.
##   godot --headless --path godot res://layout_walk_tmp.tscn -- IN OUT

func _ready() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(args[0]))
	var started := Time.get_ticks_msec()
	var build: Dictionary = ZoneBuilder.build(zone, "",
			ZoneController.PLACEMENT_BUDGET_MS, {})
	var out := {"ms": Time.get_ticks_msec() - started}
	if build.has("failed"):
		out["failed"] = str(build["failed"])
	else:
		add_child(build["root"] as Node3D)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var evidence := RoomAudit.measure_layout(build,
				get_viewport().world_3d.direct_space_state)
		build["apertures"] = evidence["apertures"]
		build["arrival_ok"] = evidence["arrival_ok"]
		build["plug_clear"] = evidence["plug_clear"]
		build["plug_placement"] = evidence["plug_placement"]
		build["packages"] = await ChainCertificate.of_build(get_tree(),
				str(zone.get("zone_id", "")), build)
		out["layout"] = ZoneBuilder.layout_to_json(build)
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	get_tree().quit()
