extends Node
## Can the player READ the writing on the walls? (`make godot-legible`)
##
## Playtest 1 reached the Hub and found every wall sign mirrored --
## "THE MULTIWORLD" rendered as its own reflection, the control list
## unreadable, the portal sign backwards. Nine suites were green. Not one
## of them had ever asked which WAY a piece of text faced, because every
## assertion in this project was about state, geometry or protocol, and a
## sign is correct in all three of those while being backwards.
##
## A Label3D draws on its local XY plane and reads correctly only from
## its local +Z side. Mounted flat on a wall it therefore has a right
## answer and a wrong one that differ by a sign, which is exactly the
## kind of detail that survives review by looking plausible.
##
## So: build the Hub, walk every Label3D, and check the text faces the
## room the player stands in. Billboarded labels are exempt -- they turn
## to the camera by construction.

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub := HubController.new()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var labels: Array[Label3D] = []
	_collect(hub, labels)
	_check(labels.size() >= 6,
			"found only %d Label3D in the Hub; this suite would pass "
			% labels.size() + "vacuously on an empty room")

	# The player spawns here (hub.gd), so this is the side every sign has
	# to be legible from.
	var eye := Vector3(0.0, 1.6, 3.0)
	var checked := 0
	for label: Label3D in labels:
		if label.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			continue                      # turns to face the camera anyway
		if label.text.strip_edges() == "":
			continue
		checked += 1
		# A Label3D reads correctly from its local +Z side.
		var facing := label.global_transform.basis.z.normalized()
		var to_player := (eye - label.global_position)
		to_player.y = 0.0
		if to_player.length() < 0.01:
			continue
		to_player = to_player.normalized()
		var alignment := facing.dot(to_player)
		_check(alignment > 0.0,
				"\"%s\" faces away from the player and renders MIRRORED "
				% label.text.split("\n")[0].substr(0, 34)
				+ "(facing %.2v, player is %.2v away, dot %.2f)"
				% [facing, to_player, alignment])

	_check(checked >= 4,
			"only %d fixed-rotation labels were checked; if the Hub went "
			% checked + "all-billboard this suite stopped proving anything")
	print("legibility: checked %d fixed labels of %d total"
			% [checked, labels.size()])
	_the_lab_doorway_is_a_hole_not_a_picture_of_one(hub)
	_finish()

## Playtest 1 could not reach the Echo Lab. `_cut_lab_doorway` added a
## dark box IN FRONT OF the perimeter wall and called it an opening --
## the wall behind kept its collider, so the doorway was a picture of a
## doorway. It looked right from across the room, which is exactly how it
## survived: nothing renders differently, and no suite had ever tried to
## walk through anything.
func _the_lab_doorway_is_a_hole_not_a_picture_of_one(hub: Node) -> void:
	var space: PhysicsDirectSpaceState3D = \
			hub.get_world_3d().direct_space_state
	var door_z: float = HubAnchors.LAB_DOOR_Z
	var eye_y: float = 1.2

	# Straight at the doorway from inside the room, and out the far side.
	# Sweep the doorway's whole width. One ray down the middle would pass
	# a door with a station parked across half of it.
	var half := HubAnchors.LAB_DOOR_WIDTH / 2.0
	for offset: float in [-half + 0.4, 0.0, half - 0.4]:
		var probe := PhysicsRayQueryParameters3D.create(
				Vector3(-4.0, eye_y, door_z + offset),
				Vector3(-HubAnchors.W / 2.0 - 2.5, eye_y, door_z + offset))
		var blocked: Dictionary = space.intersect_ray(probe)
		var by: String = ""
		if not blocked.is_empty():
			var who: Node = blocked.get("collider") as Node
			by = who.get_path() if who != null else "?"
		_check(blocked.is_empty(),
				"the Echo Lab doorway is blocked at z=%.1f (%s) by %s"
				% [door_z + offset, blocked.get("position", Vector3.ZERO), by])

	var from := Vector3(-4.0, eye_y, door_z)
	var to := Vector3(-HubAnchors.W / 2.0 - 2.5, eye_y, door_z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = space.intersect_ray(query)
	var blocker: String = ""
	if not hit.is_empty():
		var node: Node = hit.get("collider") as Node
		blocker = node.get_path() if node != null else "?"
	_check(hit.is_empty(),
			"the Echo Lab doorway is blocked at %s by %s -- the player "
			% [hit.get("position", Vector3.ZERO), blocker]
			+ "walks into a wall with a picture of a door on it")

	# And the wall either side must still be solid, or the "fix" was to
	# delete the wall.
	for probe_z: float in [door_z - HubAnchors.LAB_DOOR_WIDTH - 1.5,
			door_z + HubAnchors.LAB_DOOR_WIDTH + 1.5]:
		var wall_query := PhysicsRayQueryParameters3D.create(
				Vector3(-4.0, eye_y, probe_z),
				Vector3(-HubAnchors.W / 2.0 - 2.5, eye_y, probe_z))
		_check(not space.intersect_ray(wall_query).is_empty(),
				"the wall at z=%.1f is missing; the doorway was widened "
				% probe_z + "into an open side of the room")

func _collect(node: Node, out: Array[Label3D]) -> void:
	if node is Label3D:
		out.append(node as Label3D)
	for child in node.get_children():
		_collect(child, out)

func _finish() -> void:
	if failures == 0:
		print("GODOT LEGIBILITY TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT LEGIBILITY TESTS: %d failures" % failures)
		get_tree().quit(1)
