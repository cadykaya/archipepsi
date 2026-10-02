extends "res://tests/reversible_driver.gd"
## REVIEW FRAMES OF THE CANDIDATE ZONE (`make candidate-shots`),
## O05-15.4.
##
## The owner asked for "a few useful in-engine frames with the correct
## camera, not only debug labels". This builds `candidate_zone.json` --
## the whole candidate profile on the played Zone, what the candidate
## launcher composes -- through the same `ZoneController` a player enters,
## walks the real player to each relationship, and saves what its own
## camera sees, before and after.
##
## **DIAGNOSTIC, AND IT SAYS SO.** It asserts nothing: the claims are made
## by `godot-transport`, `godot-reversible` and `godot-candidate-live`.
## The lever is pulled with the interact ray; the cell is seated through
## the socket's own `install` -- a direct call, for a picture, never
## counted as evidence of the delivery. Enemies are removed.
##
## Runs under xvfb with the GL driver (`zone_shot_driver.gd`'s trap: the
## headless dummy renderer hangs an awaited capture). Output:
## `user://candidate_shots`, outside the repository.

const OUT_DIR := "user://candidate_shots"
const CANDIDATE_FIXTURE := "res://tests/fixtures/candidate_zone.json"
const FOV := 70.0

var _controller: ZoneController = null


func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(OUT_DIR))
	for name: String in DirAccess.get_files_at(OUT_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
				OUT_DIR.path_join(name)))
	var zone_data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(CANDIDATE_FIXTURE))
	var controller := await _enter(zone_data)
	_controller = controller
	var player := controller.player
	# NOBODY TO FIGHT IN A PHOTOGRAPH. Enemies are removed; nothing about
	# the relationships depends on them. THE CAMERA IS THE PLAYER'S: the
	# real player walks to each subject (`_advance_to`, `_approach`) and
	# the frame is what it sees.
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _settle(10)

	var lever := _lever(controller)
	var span_edge := _edge_for(SPAN)
	var socket := _socket(controller)
	var cell := controller.objects.body_of(CELL)
	var cell_edge := _edge_for(VARIABLE)
	var lever_room := str(span_edge.get("room_a", ""))

	# ---- the reversible lever ------------------------------------------
	if lever != null:
		var door := _door(controller, lever_room, span_edge)
		await _advance_to(controller, lever_room, false)
		await _approach(controller, lever, 3.0, lever.global_position
				+ Vector3(0.0, CallLever.BASE.y, 0.0))
		_look_at(player, (lever.global_position + door) * 0.5)
		await _capture("01_lever_and_its_doorway_shut")
		await _pull(controller)
		await _wait_for(func() -> bool:
			var gate := _gate_on(controller, str(span_edge["edge_id"]))
			return gate != null and gate.shutter.is_open(), 600)
		_look_at(player, door)
		await _capture("02_lever_pulled_doorway_open")
		await _walk_into(controller, str(span_edge.get("room_b", "")))
		for lamp: Variant in _span_lamps(controller):
			_look_at(player, (lamp as Node3D).global_position)
			await _capture("03_the_lamp_past_the_doorway_lit")
			break

	# ---- the power cell and its socket ---------------------------------
	if cell != null:
		await _advance_to(controller, controller.objects.room_of(CELL), false)
		await _approach(controller, cell, 2.6)
		await _capture("04_the_power_cell_at_home")
	if socket != null:
		var socket_room := _consumer_room(zone_data)
		var door := _door(controller, socket_room, cell_edge)
		await _advance_to(controller, socket_room, false)
		await _approach(controller, socket, 3.2, socket.global_position
				+ Vector3(0.0, ObjectSocket.BASE.y * 0.6, 0.0))
		_look_at(player, (socket.global_position + door) * 0.5)
		await _capture("05_the_socket_and_the_shut_doorway")
		if cell != null:
			# FOR THE PICTURE ONLY: the socket's own `install`, not the
			# played delivery `godot-transport` asserts.
			socket.install(cell)
			await _wait_for(func() -> bool:
				var gate := _gate_on(controller, str(cell_edge["edge_id"]))
				return gate != null and gate.shutter.is_open(), 600)
			await _settle(30)
			await _capture("06_the_cell_seated_and_the_doorway_open")
	print("CANDIDATE SHOTS: written to %s"
			% ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _capture(name: String) -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(
			"%s/%s.png" % [OUT_DIR, name]))
	print("    %s" % name)


func _consumer_room(zone_data: Dictionary) -> String:
	var volume: Array = ((zone_data["transported_objects"] as Array)[0]
			as Dictionary)["allowed_volume"]
	return str(volume[volume.size() - 1])


func _edge_for(variable: String) -> Dictionary:
	for raw: Variant in _zone_data.get("edges", []) as Array:
		for cond: Variant in (raw as Dictionary).get("requires_state", []) \
				as Array:
			if str((cond as Dictionary).get("variable_id", "")) == variable:
				return raw
	return {}


func _gate_on(controller: ZoneController, edge_id: String) \
		-> StateGates.StateGate:
	for raw: Variant in controller.state_gates:
		var gate: StateGates.StateGate = raw
		if gate.edge_id == edge_id:
			return gate
	return null


## The doorway's floor point, on `room`'s side.
func _door(controller: ZoneController, room: String,
		edge: Dictionary) -> Vector3:
	var frame := RoomGraphs.doorway_frame(room, edge,
			_zone_data.get("chambers", []) as Array, controller.door_frames)
	if frame.is_empty():
		var other := str(edge.get("room_b", "")) \
				if str(edge.get("room_a", "")) == room \
				else str(edge.get("room_a", ""))
		frame = RoomGraphs.doorway_frame(other, edge,
				_zone_data.get("chambers", []) as Array,
				controller.door_frames)
	return frame.get("position", Vector3.ZERO) + Vector3(0.0, 1.2, 0.0)
