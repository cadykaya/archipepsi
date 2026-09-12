extends SceneTree
## Walk a player-shaped body through each repaired doorway. Twice.
##
##   godot --path godot -s _harness/crossing.gd -- <models> <out>
##
## ## What this is
##
## The three repaired shells declared an `exit` two metres past their own
## back wall, so `ZoneBuilder` joined the next corridor over a hole and the
## playtest said so in its first sentence. Moving the socket is a number;
## whether a player can now WALK the join is a physical question, and a
## static render cannot answer it.
##
## So: load the shipped `.glb` with its exported colliders, stand a capsule
## of Production's own dimensions inside the room, attach a corridor stub AT
## THE SOCKET the way ZoneBuilder does, and walk forward under Production's
## own gravity until the body is through or has fallen.
##
## Each join is crossed TWICE -- once with the shell at the origin, and once
## with it translated and yawed, with the corridor placed by transforming
## the socket rather than by re-deriving it. A join that only works at the
## origin is a join that works in the preview and not in a Zone.
##
## ## What it does NOT prove
##
## This is not `player.gd`. It uses Production's capsule, gravity, walk
## speed and floor angle, and the engine's own `move_and_slide` -- the facts
## that decide whether a floor carries a body across a threshold. It does
## not carry weapons, the HUD, movement packages, volumes or step
## assistance, so it is evidence about the GEOMETRY of the join and nothing
## about how the crossing feels. Production's own playtest is still the
## thing that closes this out.

const GRAVITY := 24.0            # Constants.GRAVITY
const WALK_SPEED := 7.0          # Constants.WALK_SPEED
const PLAYER_HEIGHT := 1.8       # Constants.PLAYER_HEIGHT
const PLAYER_RADIUS := 0.4       # Constants.PLAYER_RADIUS
const FLOOR_MAX_ANGLE := deg_to_rad(46.0)

const STEP := 1.0 / 60.0
const CORRIDOR := 6.0            # m of stub beyond the socket
const START_BACK := 3.0          # m inside the room the walk starts
const FELL := 2.5                # m below the doorway floor = fell

## Each repaired join: the shell, its exit socket in runtime metres, and
## the yaw the doorway faces. Read from the manifest at run time rather
## than typed here, so a socket that moves again cannot pass by being stale.
var _models: String
var _out: String
var _bench: GDScript
var _log := {}
var _problems: Array[String] = []


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <models-dir> <out-dir>")
	else:
		_models = a[0]
		_out = a[1]
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[crossing] FAIL: %s" % what)


func _socket_of(rel_manifest: String, shell: String) -> Dictionary:
	var path := "%s/%s" % [_models, rel_manifest]
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		_fail("no manifest at %s" % path)
		return {}
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_fail("%s is not JSON" % path)
		return {}
	var entries: Dictionary = (data as Dictionary).get("assets", data)
	var entry: Dictionary = entries.get(shell, {})
	for raw: Variant in entry.get("sockets", []):
		var s: Dictionary = raw
		if s.get("name") == "exit":
			return s
	_fail("%s declares no exit socket" % shell)
	return {}


## The room, its collision, and a corridor stub attached at the socket --
## which is the whole point: ZoneBuilder attaches AT THE SOCKET, so the
## stub is placed by transforming the socket, never by re-deriving it.
func _stage(glb: String, socket: Dictionary, place: Transform3D) -> Node3D:
	var root := Node3D.new()
	get_root().add_child(root)

	var shell: Node3D = _bench.call("load_glb", glb)
	if shell == null:
		_fail("could not load %s" % glb)
		root.queue_free()
		return null
	shell.transform = place
	root.add_child(shell)
	_collide(shell)

	var at: Vector3 = place * (Vector3(socket["position"][0],
			socket["position"][1], socket["position"][2]))
	var out_dir: Vector3 = (place.basis * Vector3(0, 0, 1)).normalized()

	var floor_body := StaticBody3D.new()
	floor_body.name = "corridor_stub"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.4, CORRIDOR)
	shape.shape = box
	floor_body.add_child(shape)
	# POSITIONED BEFORE IT IS ADDED, and this is not a style choice.
	#
	# A Node3D moved AFTER it is already in the tree defers its transform
	# to the physics server until the end of the frame. Everything here
	# happens inside one frame, so a stub positioned after `add_child` sits
	# in the space AT THE WORLD ORIGIN while its node draws in the right
	# place -- and the first version of this file did exactly that. The
	# player walked out of the hall and fell, and the number was identical
	# for all three shells and both placements, which is what gave it away:
	# three different rooms cannot fail at the same 3.53 m. `root` is
	# identity, so the local transform is the global one.
	floor_body.transform = Transform3D(place.basis,
			at + out_dir * (CORRIDOR / 2.0) + Vector3(0, -0.2, 0))
	root.add_child(floor_body)
	return root


## Turn every exported mesh into a collider. The shells ship
## `-convcolonly` parts, which is what the game imports; here the trimesh
## of each part is used directly so no import setting can flatter it.
func _collide(node: Node3D) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mi.mesh.create_trimesh_shape()
		body.add_child(shape)
		mi.add_child(body)


func _walk(root: Node3D, socket: Dictionary, place: Transform3D) -> Dictionary:
	var at: Vector3 = place * (Vector3(socket["position"][0],
			socket["position"][1], socket["position"][2]))
	var out_dir: Vector3 = (place.basis * Vector3(0, 0, 1)).normalized()

	# One room in the world, checked rather than assumed.
	var staged := 0
	for child in get_root().get_children():
		if child is Node3D:
			staged += 1
	if staged != 1:
		_fail("%d stages are in the world at once; a crossing can be "
				% staged + "rescued by another room's floor")

	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = PLAYER_HEIGHT
	capsule.radius = PLAYER_RADIUS
	shape.shape = capsule
	body.add_child(shape)
	body.floor_max_angle = FLOOR_MAX_ANGLE
	root.add_child(body)
	# Feet on the doorway floor, START_BACK metres inside the room.
	body.global_position = at - out_dir * START_BACK \
			+ Vector3(0, PLAYER_HEIGHT / 2.0 + 0.05, 0)

	var floor_y := at.y
	var lowest := body.global_position.y
	var crossed := false
	var fell := false
	var space := 0.0
	for _i in range(int(12.0 / STEP)):
		var v := body.velocity
		if body.is_on_floor():
			v.y = 0.0
		else:
			v.y -= GRAVITY * STEP
		var flat := out_dir * WALK_SPEED
		v.x = flat.x
		v.z = flat.z
		body.velocity = v
		body.move_and_slide()
		lowest = minf(lowest, body.global_position.y - PLAYER_HEIGHT / 2.0)
		var travelled := (body.global_position - at).dot(out_dir)
		if body.global_position.y - PLAYER_HEIGHT / 2.0 < floor_y - FELL:
			fell = true
			space = travelled
			break
		if travelled > CORRIDOR - 1.0:
			crossed = true
			space = travelled
			break
	var drop := floor_y - lowest
	body.queue_free()
	return {"crossed": crossed, "fell": fell,
			"reached_m_past_socket": snappedf(space, 0.01),
			"max_drop_below_threshold_m": snappedf(maxf(drop, 0.0), 0.001)}


func _cross(shell: String, manifest: String, place: Transform3D,
		label: String) -> void:
	var socket := _socket_of(manifest, shell)
	if socket.is_empty():
		return
	var glb := "%s/%s" % [_models, manifest.get_base_dir() + "/" + shell + ".glb"]
	var root := _stage(glb, socket, place)
	if root == null:
		return
	var result := _walk(root, socket, place)
	result["socket"] = socket["position"]
	result["placed"] = [snappedf(place.origin.x, 0.01),
			snappedf(place.origin.y, 0.01), snappedf(place.origin.z, 0.01)]
	_log["%s %s" % [shell, label]] = result
	if not result["crossed"] or result["fell"]:
		_fail("%s %s: the player did not cross -- %s"
				% [shell, label, JSON.stringify(result)])
	# `free`, not `queue_free`. A queued free happens at the END of the
	# frame and all six crossings run inside one frame, so queuing left
	# every previous room standing in the same world. The plenum's walk
	# "passed" across the HALL's basin floor, 3 m below and 20 m away,
	# because that geometry was still there. A crossing that is rescued by
	# another room's floor is worse than a failing one: it reports success.
	root.free()


func _run() -> void:
	var joins := [
		["shell_hall_transit", "batch039/shells/manifest.json"],
		["shell_plenum_helix", "batch040/shells/manifest.json"],
		["shell_span_basin", "batch040/shells/manifest.json"],
	]
	for raw: Variant in joins:
		var pair: Array = raw
		_cross(pair[0], pair[1], Transform3D.IDENTITY, "at the origin")
	# The placed and yawed case. A join that only works at the origin is a
	# join that works in the preview and not in a Zone.
	for raw: Variant in joins:
		var pair: Array = raw
		var placed := Transform3D(
				Basis(Vector3.UP, deg_to_rad(37.0)),
				Vector3(-18.5, 0.0, 46.25))
		_cross(pair[0], pair[1], placed, "placed and yawed 37 deg")

	if _log.size() != 6:
		_fail(("%d of 6 crossings ran; a crossing that did not happen is "
				+ "not evidence that it works") % _log.size())
	for key: String in _log:
		print("[crossing] %s: %s" % [key, JSON.stringify(_log[key])])

	if _out != "":
		var f := FileAccess.open("%s/crossings.json" % _out, FileAccess.WRITE)
		if f == null:
			_fail("could not write crossings.json under %s" % _out)
		else:
			f.store_string(JSON.stringify(_log, "  "))
			f.close()

	if _problems.is_empty():
		print("[crossing] 6 crossings, 0 problem(s)")
		quit(0)
		return
	printerr("[crossing] %d problem(s)" % _problems.size())
	quit(1)
