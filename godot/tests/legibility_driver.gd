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
	_finish()

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
