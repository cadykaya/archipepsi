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
const START_BACK := 3.0          # m back from the socket the walk starts
## THROUGH the doorway and still standing -- that is the whole question.
##
## This used to ask for a fixed distance past the socket, which grades a
## doorway on what the room keeps near it: all three treasure rooms
## "failed" by walking in 1.2-2.1 m and stopping against their own
## plinths, which is furniture, not a join. So a crossing succeeds when the
## player gets a body's width past the socket and never falls, and the walk
## runs its whole length so a fall AFTER the threshold still counts -- the
## yard's entry drops at 1.22 m, well past any threshold.
const THROUGH := 0.8             # m past the socket = through it
const LIMIT_OUT := 4.0           # m of the 6 m stub to walk
const LIMIT_IN := 3.0            # m into the room before stopping
const FELL := 2.5                # m below the doorway floor = fell

## EVERY doorway of every shell, both ways.
##
## An `exit` is walked from inside the room out onto the stub; an `entry`
## is walked from the stub into the room, because that is the direction a
## player meets it. Both are read from the manifests at run time rather
## than typed here, so a socket that moves again cannot pass by being
## stale -- and so that adding a shell adds its crossings.
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


## Every (manifest, shell, socket) triple the shipped manifests declare.
func _joins() -> Array:
	var out := []
	for rel: String in ["batch015/shells/manifest.json",
			"batch016/shells/manifest.json",
			"batch017/shells/manifest.json",
			"batch018/shells/manifest.json",
			"batch019/shells/manifest.json",
			"batch039/shells/manifest.json",
			"batch040/shells/manifest.json",
			"batch044/shells/manifest.json"]:
		var path := "%s/%s" % [_models, rel]
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			continue
		var data: Variant = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			_fail("%s is not JSON" % path)
			continue
		var entries: Dictionary = (data as Dictionary).get("assets", data)
		for shell: String in entries:
			var entry: Variant = entries[shell]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			for raw: Variant in (entry as Dictionary).get("sockets", []):
				var socket: Dictionary = raw
				if socket.get("kind") != "doorway":
					continue
				out.append({"glb": "%s/%s.glb" % [rel.get_base_dir(), shell],
						"shell": shell, "socket": socket})
	return out


## The direction a doorway faces, out of the room, in world space.
##
## This was `place.basis * Vector3(0, 0, 1)` -- the shell's own +Z,
## whatever the socket said. It is right for the six doorways this harness
## first carried, all of them yaw 0 or 180, and wrong for every one that
## faces along X: the corner pair and the yard both had their corridor
## stub built out of the side of the room instead of out of the doorway,
## so three joins "fell" into a gap that was not there and the yard's
## entry "crossed" a stub it never touched. Read the yaw.
func _facing(socket: Dictionary, place: Transform3D) -> Vector3:
	var yaw := deg_to_rad(float(socket.get("yaw", 0.0)))
	return (place.basis * (Basis(Vector3.UP, yaw) * Vector3(0, 0, 1))).normalized()


## The slab the engine lays over a SEALED door, built to the same rule:
## `ContentInstantiator._place_closures` uses the aperture plus 0.6 m, 0.5 m
## deep, at the socket. An authored opening has to ACCEPT one -- a collar
## that does not clear the aperture by 0.30 m on each side leaves a closure
## hanging in the hole, and a room whose unused doors do not close is a room
## the composer cannot use as a dead end.
func _closure(root: Node3D, socket: Dictionary, place: Transform3D) -> void:
	var at: Vector3 = place * (Vector3(socket["position"][0],
			socket["position"][1], socket["position"][2]))
	var yaw := deg_to_rad(float(socket.get("yaw", 0.0)))
	var body := StaticBody3D.new()
	body.name = "closure"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var w: float = float(socket.get("width", 2.4)) + 0.6
	var h: float = float(socket.get("height", 3.2)) + 0.6
	box.size = Vector3(w, h, 0.5)
	shape.shape = box
	shape.position = Vector3(0, h / 2.0, 0)
	body.add_child(shape)
	body.transform = Transform3D(place.basis * Basis(Vector3.UP, yaw), at)
	root.add_child(body)


## The room, its collision, and a corridor stub attached at the socket --
## which is the whole point: ZoneBuilder attaches AT THE SOCKET, so the
## stub is placed by transforming the socket, never by re-deriving it.
func _stage(glb: String, socket: Dictionary, place: Transform3D,
		sealed: bool = false) -> Node3D:
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
	var out_dir := _facing(socket, place)

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
	# Oriented to the doorway, not to the shell: the stub's length has to
	# run the way the player walks.
	var yaw := deg_to_rad(float(socket.get("yaw", 0.0)))
	floor_body.transform = Transform3D(place.basis * Basis(Vector3.UP, yaw),
			at + out_dir * (CORRIDOR / 2.0) + Vector3(0, -0.2, 0))
	root.add_child(floor_body)
	if sealed:
		_closure(root, socket, place)
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


func _walk(root: Node3D, socket: Dictionary, place: Transform3D,
		going_in: bool) -> Dictionary:
	var at: Vector3 = place * (Vector3(socket["position"][0],
			socket["position"][1], socket["position"][2]))
	var out_dir := _facing(socket, place)

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
	# An exit is walked out of the room; an entry is walked into it, off
	# the corridor the router attached. `travel` is the way the player
	# faces either way, so everything below reads the same.
	var travel := -out_dir if going_in else out_dir
	body.global_position = at - travel * START_BACK \
			+ Vector3(0, PLAYER_HEIGHT / 2.0 + 0.05, 0)

	var floor_y := at.y
	var lowest := body.global_position.y
	var fell := false
	var space := 0.0
	var limit := LIMIT_IN if going_in else LIMIT_OUT
	for _i in range(int(6.0 / STEP)):
		var v := body.velocity
		if body.is_on_floor():
			v.y = 0.0
		else:
			v.y -= GRAVITY * STEP
		var flat := travel * WALK_SPEED
		v.x = flat.x
		v.z = flat.z
		body.velocity = v
		body.move_and_slide()
		lowest = minf(lowest, body.global_position.y - PLAYER_HEIGHT / 2.0)
		# The FURTHEST it got, not where it ended: a player blocked by a
		# plinth slides back a little and the question is whether it ever
		# made it through.
		space = maxf(space, (body.global_position - at).dot(travel))
		if body.global_position.y - PLAYER_HEIGHT / 2.0 < floor_y - FELL:
			fell = true
			break
		if space > limit:
			break
	var drop := floor_y - lowest
	body.queue_free()
	return {"crossed": not fell and space >= THROUGH, "fell": fell,
			"blocked_before_the_threshold": not fell and space < THROUGH,
			"reached_m_past_socket": snappedf(space, 0.01),
			"max_drop_below_threshold_m": snappedf(maxf(drop, 0.0), 0.001)}


func _cross(join: Dictionary, place: Transform3D, label: String,
		sealed: bool = false) -> void:
	var socket: Dictionary = join["socket"]
	var shell: String = join["shell"]
	var going_in: bool = str(socket.get("name", "")) == "entry"
	var root := _stage("%s/%s" % [_models, join["glb"]], socket, place,
			sealed)
	if root == null:
		return
	var result := _walk(root, socket, place, going_in)
	result["socket"] = socket["position"]
	result["direction"] = "in" if going_in else "out"
	result["placed"] = [snappedf(place.origin.x, 0.01),
			snappedf(place.origin.y, 0.01), snappedf(place.origin.z, 0.01)]
	var key := "%s/%s %s" % [shell, socket.get("name", "?"), label]
	_log[key] = result
	if sealed:
		# A closed assignment must STOP the player. A doorway that stays
		# crossable when the engine has sealed it is a hole in the Zone.
		if result["crossed"]:
			_fail("%s: the closure did not stop the player -- %s"
					% [key, JSON.stringify(result)])
		root.free()
		return
	if not result["crossed"] or result["fell"]:
		_fail("%s: the player did not cross -- %s"
				% [key, JSON.stringify(result)])
	# `free`, not `queue_free`. A queued free happens at the END of the
	# frame and all six crossings run inside one frame, so queuing left
	# every previous room standing in the same world. The plenum's walk
	# "passed" across the HALL's basin floor, 3 m below and 20 m away,
	# because that geometry was still there. A crossing that is rescued by
	# another room's floor is worse than a failing one: it reports success.
	root.free()


## Doorways known to stand over nothing, with no repair yet authorized.
## Matched by "<shell>/<socket>", mirroring measure_doorways.KNOWN, and
## enforced the same way in both directions: an entry here that CROSSES
## fails, so a repair retires its exception instead of leaving a skip.
const KNOWN_UNCROSSABLE := {}


func _run() -> void:
	var joins := _joins()
	if joins.size() < 24:
		_fail("only %d doorways were found; a crossing that did not happen "
				% joins.size() + "is not evidence that it works")
	var placed := Transform3D(Basis(Vector3.UP, deg_to_rad(37.0)),
			Vector3(-18.5, 0.0, 46.25))
	for raw: Variant in joins:
		_cross(raw, Transform3D.IDENTITY, "at the origin")
	# A join that only works at the origin is a join that works in the
	# preview and not in a Zone.
	for raw: Variant in joins:
		_cross(raw, placed, "placed and yawed 37 deg")
	# And every one of them CLOSED, which is what an unused authored
	# opening becomes.
	for raw: Variant in joins:
		_cross(raw, Transform3D.IDENTITY, "closed", true)

	for key: String in _log:
		print("[crossing] %s: %s" % [key, JSON.stringify(_log[key])])

	if _out != "":
		var f := FileAccess.open("%s/crossings.json" % _out, FileAccess.WRITE)
		if f == null:
			_fail("could not write crossings.json under %s" % _out)
		else:
			f.store_string(JSON.stringify(_log, "  "))
			f.close()

	# Known failures are expected; an unknown one, or a known one that
	# quietly started working, is not.
	var fresh: Array[String] = []
	var matched := {}
	for problem: String in _problems:
		var door := problem.split(" ")[0]
		if KNOWN_UNCROSSABLE.has(door):
			matched[door] = true
			continue
		fresh.append(problem)
	for door: String in KNOWN_UNCROSSABLE:
		if not matched.has(door):
			fresh.append("%s is listed as a known uncrossable join and "
					% door + "crossed anyway. If it was repaired, delete "
					+ "its line from KNOWN_UNCROSSABLE.")
	if fresh.is_empty():
		print("[crossing] %d crossings, %d known-uncrossable, 0 new problems"
				% [_log.size(), KNOWN_UNCROSSABLE.size() * 2])
		quit(0)
		return
	for problem: String in fresh:
		printerr("[crossing] UNEXPECTED: %s" % problem)
	quit(1)
