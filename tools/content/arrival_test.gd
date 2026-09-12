extends SceneTree
## EVERY OPENING'S OWN ARRIVAL REGION, MEASURED AGAINST THE IMPORTED SHELL.
##
##   godot --path godot -s _harness/arrival.gd -- <models> <out.json>
##
## ## The contract this checks Art's half of
##
## `ContentInstantiator._player_entry` resolves the arrival region by NAME
## against the socket the chain arrives through -- `socket_for_edge(entry,
## chamber, "arrive_edge")`, the same lookup `_entry_offset` uses. A shell
## that declares one unnamed region gets the pre-rule behaviour: ONE
## arrival however many openings it has, so a four-door junction entered
## from the side vouches for the space in front of its front door.
##
## So Art's half is exactly: one `player_entry` volume per joinable
## socket, named the socket's name. This asserts that, and then measures
## each one.
##
## ## What is measured, and whose rule it is
##
## Production's, not a second one. `RoomAudit.arrival_is_supported` rays
## DOWN from the region's centre by `0.5 + MAX_VERTICAL_STEP` and requires
## ground, then requires a standing capsule at that ground to be
## unblocked. Both halves, because they were once split and an anchor over
## a hole in the floor passed the empty-space half on its own.
##
## ## And then a body walks IN FROM IT
##
## **A default-entry-to-side-door walk is not a side-door-arrival test.**
## The body is placed AT the region it is testing -- not at the front door
## -- and walks the declared leg into the room. A side door whose region
## is over a hole, inside a wall, or behind the machine fails here and
## cannot be rescued by the fact that the front door works.

const GRAVITY := 24.0
const WALK_SPEED := 7.0
const JUMP_VELOCITY := 8.0
const PLAYER_HEIGHT := 1.8
const PLAYER_RADIUS := 0.4
const MAX_VERTICAL_STEP := 1.0
const FLOOR_MAX_ANGLE := 0.8028514559173916  # 46 degrees, Production's
const STEP := 1.0 / 60.0
const ARRIVED := 0.6
const STALL_FRAMES := 24

## Where a body that arrived at each opening is asked to walk. Spelled out
## per room and per socket rather than derived: an inward offset lands
## inside the cross's own machine, and a target that moves with the
## geometry would stop asking the question when the geometry changed.
const LEGS := {
	"shell_junction_cross": {
		"entry": [[0.0, 8.0], [-5.0, 12.0]],
		"exit": [[0.0, 26.0], [-5.0, 22.0]],
		"branch_east": [[10.0, 15.0], [7.7, 19.0]],
		"branch_west": [[-10.0, 15.0], [-5.0, 12.0]],
	},
	"shell_junction_triad": {
		"entry": [[0.0, 8.0]],
		"exit": [[0.0, 20.0], [0.0, 14.0]],
		"branch_east": [[9.0, 13.0], [7.0, 13.0]],
	},
	"shell_bay_terminus": {
		"entry": [[0.0, 9.0], [0.0, 14.0]],
		"branch_east": [[4.0, 16.0], [0.0, 15.0]],
		"branch_west": [[-4.0, 16.0], [0.0, 15.0]],
	},
}

var _models: String
var _out: String
var _bench: GDScript
var _problems: Array[String] = []
var _log := {}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		_fail("usage: -- <models-dir> <out.json>")
	else:
		_models = a[0]
		_out = a[1]
	_bench = load("res://_harness/artbench.gd") as GDScript
	if _bench == null:
		_fail("the bench script did not load")
	_run.call_deferred()


func _fail(what: String) -> void:
	_problems.append(what)
	printerr("[arrival] FAIL: %s" % what)


func _v3(raw: Variant) -> Vector3:
	var a: Array = raw
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## THE SHELL'S OWN DECLARED COLLIDERS, CONVEX, the way the importer
## builds them -- not a trimesh over the visible meshes.
##
## `artbench.load_glb` DROPS every `-convcolonly` node, because it exists
## to photograph rooms and those nodes are untextured duplicates sitting
## on top of the geometry. So this loads the file itself and keeps them.
##
## The difference is not cosmetic and it was measured: a trimesh box is a
## SURFACE, so a capsule fully inside one reports no intersection at all,
## and the sabotage that buried an arrival region in the middle of the
## cross's machine passed the support half. It failed the walk-in half
## instead, which is the pair doing its job -- but a support check that
## cannot see the inside of a solid is not the check Production runs, and
## `RoomAudit` runs against real convex bodies.
func _load_shell(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.base_path = path.get_base_dir()
	if doc.append_from_file(path, state) != OK:
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		return null
	_harden(scene)
	return scene


func _harden(node: Node) -> int:
	var made := 0
	for child in node.get_children():
		made += _harden(child)
		var name := str(child.name)
		if name.ends_with("-convcolonly") or name.ends_with("-colonly"):
			var mi := child as MeshInstance3D
			if mi != null and mi.mesh != null:
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				shape.shape = mi.mesh.create_convex_shape()
				body.add_child(shape)
				mi.add_sibling(body)
				body.global_transform = mi.global_transform
				made += 1
			child.get_parent().remove_child(child)
			child.queue_free()
		elif name.ends_with("-navmesh") or name.ends_with("-occonly") \
				or name.ends_with("-noimp"):
			child.get_parent().remove_child(child)
			child.queue_free()
	return made


## `RoomAudit.arrival_is_supported`, and nothing else. Ground within a
## step, then a standing capsule that is not blocked.
func _supported(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
	var ground := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(
				at + Vector3.UP * 0.5,
				at + Vector3.DOWN * (0.5 + MAX_VERTICAL_STEP)))
	if ground.is_empty():
		return {"ok": false,
				"why": "no ground within %.2f m below the region's centre"
						% (0.5 + MAX_VERTICAL_STEP)}
	var floor_y: float = (ground["position"] as Vector3).y
	var stance := Vector3(at.x, floor_y, at.z) \
			+ Vector3.UP * (PLAYER_HEIGHT / 2.0 + 0.05)
	var shape := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = PLAYER_HEIGHT
	capsule.radius = PLAYER_RADIUS
	shape.shape = capsule
	shape.transform = Transform3D(Basis(), stance)
	if not space.intersect_shape(shape, 1).is_empty():
		return {"ok": false, "floor_y": snappedf(floor_y, 0.01),
				"why": "a standing capsule does not fit at the region"}
	return {"ok": true, "floor_y": snappedf(floor_y, 0.01)}


## The body starts AT the region under test and walks the declared leg.
func _walk_from(root: Node3D, start: Vector3, legs: Array) -> Dictionary:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = PLAYER_HEIGHT
	capsule.radius = PLAYER_RADIUS
	shape.shape = capsule
	body.add_child(shape)
	body.floor_max_angle = FLOOR_MAX_ANGLE
	root.add_child(body)
	body.global_position = start + Vector3(0, PLAYER_HEIGHT / 2.0 + 0.05, 0)

	var leg := 0
	var jumps := 0
	var stalled := 0
	var lowest := start.y
	var last := start
	for _i in range(int(30.0 / STEP)):
		if leg >= legs.size():
			break
		var raw: Array = legs[leg]
		var goal := Vector3(float(raw[0]), 0.0, float(raw[1]))
		var here := body.global_position - Vector3(0, PLAYER_HEIGHT / 2.0, 0)
		lowest = minf(lowest, here.y)
		var flat := Vector3(goal.x - here.x, 0.0, goal.z - here.z)
		if flat.length() < ARRIVED:
			leg += 1
			continue
		var v := body.velocity
		if body.is_on_floor():
			v.y = 0.0
			if stalled > STALL_FRAMES:
				v.y = JUMP_VELOCITY
				jumps += 1
				stalled = 0
		else:
			v.y -= GRAVITY * STEP
		var dir := flat.normalized() * WALK_SPEED
		v.x = dir.x
		v.z = dir.z
		body.velocity = v
		body.move_and_slide()
		var after := body.global_position - Vector3(0, PLAYER_HEIGHT / 2.0, 0)
		var gained := Vector3(last.x - goal.x, 0.0, last.z - goal.z).length() \
				- Vector3(after.x - goal.x, 0.0, after.z - goal.z).length()
		if gained < WALK_SPEED * STEP * 0.25:
			stalled += 1
		else:
			stalled = 0
		last = after
	var end := body.global_position - Vector3(0, PLAYER_HEIGHT / 2.0, 0)
	body.queue_free()
	return {"walked_in": leg >= legs.size(), "jumps": jumps,
			"lowest_y": snappedf(lowest, 0.02),
			"ended_at": [snappedf(end.x, 0.1), snappedf(end.y, 0.1),
					snappedf(end.z, 0.1)]}


func _check(shell: String, entry: Dictionary) -> void:
	var doors: Array[String] = []
	for raw: Variant in entry.get("sockets", []):
		var s: Dictionary = raw
		if str(s.get("kind", "")) in ["doorway", "corridor_end"]:
			doors.append(str(s.get("name", "")))
	var regions := {}
	var unnamed := 0
	for raw: Variant in entry.get("volumes", []):
		var v: Dictionary = raw
		if str(v.get("kind", "")) != "player_entry":
			continue
		var named := str(v.get("name", ""))
		if named == "":
			unnamed += 1
			continue
		regions[named] = _v3(v["center"])

	var note := {"doorways": doors, "regions": {}, "walk": {}}
	_log[shell] = note
	if unnamed > 0:
		_fail("%s declares %d unnamed player_entry region(s); "
				% [shell, unnamed]
				+ "_player_entry matches on NAME and an unnamed one is only "
				+ "ever the fallback")
	for door: String in doors:
		if not regions.has(door):
			_fail("%s/%s has no arrival region named after it, so a chain "
					% [shell, door]
					+ "arriving there gets the FALLBACK region -- the space "
					+ "in front of a different door")
	for named: String in regions:
		if not doors.has(named):
			_fail("%s declares an arrival region '%s' and no joinable "
					% [shell, named] + "socket of that name")

	var root := Node3D.new()
	get_root().add_child(root)
	var node := _load_shell("%s/batch044/shells/%s.glb" % [_models, shell])
	if node == null:
		_fail("could not load %s" % shell)
		root.free()
		return
	root.add_child(node)
	var bodies := node.find_children("*", "StaticBody3D", true, false).size()
	note["colliders"] = bodies
	if bodies == 0:
		_fail("%s produced no colliders, so every probe below would pass "
				% shell + "against empty space")
	var space := root.get_world_3d().direct_space_state

	for door: String in doors:
		if not regions.has(door):
			continue
		var at: Vector3 = regions[door]
		var verdict := _supported(space, at)
		note["regions"][door] = verdict
		if not bool(verdict["ok"]):
			_fail("%s/%s: %s" % [shell, door, verdict["why"]])
			continue
		var legs: Array = LEGS.get(shell, {}).get(door, [])
		if legs.is_empty():
			_fail("%s/%s has no declared leg, so nothing walks in from it"
					% [shell, door])
			continue
		var walked := _walk_from(root, Vector3(
				at.x, float(verdict["floor_y"]), at.z), legs)
		note["walk"][door] = walked
		if not bool(walked["walked_in"]):
			_fail("%s/%s: a body placed AT this arrival could not walk into "
					% [shell, door] + "the room -- %s" % JSON.stringify(walked))
		elif float(walked["lowest_y"]) < -1.0:
			_fail("%s/%s: the body fell to %.2f on the way in"
					% [shell, door, walked["lowest_y"]])
	root.free()


func _run() -> void:
	var text := FileAccess.get_file_as_string(
			"%s/batch044/shells/manifest.json" % _models)
	if text == "":
		_fail("no batch044 manifest")
		_finish()
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_fail("the manifest did not parse")
		_finish()
		return
	for shell: String in (data as Dictionary):
		_check(shell, (data as Dictionary)[shell])
	_finish()


func _finish() -> void:
	_log["problems"] = _problems
	var handle := FileAccess.open(_out, FileAccess.WRITE)
	if handle != null:
		handle.store_string(JSON.stringify(_log, "  ", true, true))
		handle.close()
	var n := 0
	for shell: String in _log:
		if shell != "problems":
			n += (_log[shell] as Dictionary)["doorways"].size()
	if _problems.is_empty():
		print("[arrival] PASS -- %d opening(s), each with its own named "
				% n + "region, supported, clear, and walked in from")
		quit(0)
	else:
		printerr("[arrival] %d problem(s)" % _problems.size())
		quit(1)
