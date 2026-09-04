extends Node
## Deterministic screenshots of activities in a REAL generated Zone
## (`make zone-shots`).
##
## The Art lane's `docs/art/CAMERA_BENCH.md` names this gap precisely:
## its bench photographs art harnesses, not the game, so no automated
## process here had ever photographed a generated Zone. This is the
## smallest thing that closes it -- one camera, framing solved from the
## subject's AABB rather than typed by eye, and `save_png`. It is NOT a
## port of the bench: no shot lists, no variant passes, no camera rig.
##
## THE TRAP, from that document and confirmed here: `--headless` selects
## the dummy renderer and an awaited viewport capture hangs forever with
## no output. This runs under xvfb with the GL driver, and the Makefile
## target is the only supported way in.
##
## Diagnostic. Nothing in the game reads it, and it asserts nothing --
## `zone_audit_driver.gd` is what makes claims. This is for looking.

const ZONE_JSON := "res://tests/fixtures/played_zone.json"
const OUT_DIR := "user://zone_shots"
const SHOT := Vector2i(1280, 800)
## Vertical FOV in degrees, and how much of the frame the subject fills.
const FOV := 55.0
const FILL := 0.55
## How far inside the room's own walls the camera must stay.
const CAMERA_MARGIN := 0.6

func _ready() -> void:
	await _run()

func _run() -> void:
	await get_tree().process_frame
	BridgeClient.snapshot = {
		"type": "campaign_snapshot",
		"mechanics": {"owned": [], "aliases": [], "links": [],
				"statuses": [], "resources": []},
		"slots": {}, "local_rewards": [],
		"available_capabilities": ["ranged_hit"],
		"coins_received": 0, "coins_spent": 0, "hub": {"state": "IDLE"},
	}
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(OUT_DIR))

	var text := FileAccess.get_file_as_string(ZONE_JSON)
	var zone: Variant = JSON.parse_string(text)
	if typeof(zone) != TYPE_DICTIONARY:
		print("SHOTS: could not read %s" % ZONE_JSON)
		get_tree().quit(1)
		return

	var build := ZoneBuilder.build(zone as Dictionary)
	var root: Node3D = build["root"]
	add_child(root)

	var camera := Camera3D.new()
	camera.fov = FOV
	camera.current = true
	camera.far = 400.0
	add_child(camera)
	# The generated Zone carries no lights of its own until the chamber
	# builders' fixtures warm up, and a shot of a black room proves
	# nothing. One neutral key, declared here as SHOT LIGHTING and never
	# as the room's own: this file must not become a second opinion about
	# how bright the game is.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	add_child(fill)

	await get_tree().process_frame
	await get_tree().process_frame

	var runtimes: Array[ActivityRuntime] = []
	_runtimes_under(root, runtimes)
	print("  %d activity runtimes in the assembled Zone" % runtimes.size())

	# Each activity's own room, so the camera can be kept INSIDE it.
	var room_bounds := {}
	# A chamber is placed with a yaw, so "the band is on the left" is a
	# statement in ROOM space and the camera works in world space.
	var entry_rotation := {}
	var band_centre := {}
	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var xform: Transform3D = entry["xform"]
		var local: AABB = (entry["build"] as Dictionary).get("bounds", AABB())
		room_bounds[str(chamber.get("id", ""))] = ZoneBuilder._world_aabb(
				local, xform.origin, xform.basis.get_euler().y)
		entry_rotation[str(chamber.get("id", ""))] = \
				xform.basis.get_euler().y
		# WHERE THE BAND IS, asked of the builder rather than recomputed
		# from `side` and `coverage`. The builder emits the deck as a
		# `reserved` socket; deriving the same rectangle a second time
		# here is how the photograph ends up aimed at a different place
		# than the one the room actually built.
		var deck: Variant = null
		for socket: Variant in (entry["build"] as Dictionary).get(
				"sockets", []) as Array:
			if typeof(socket) == TYPE_DICTIONARY \
					and str((socket as Dictionary).get("name", "")) \
						== "band_deck":
				deck = (socket as Dictionary)["position"]
		if deck != null:
			band_centre[str(chamber.get("id", ""))] = xform * (
					deck as Vector3)

	# ROOMS FIRST (ROOM_GRAMMAR v0). The batch's claim is about the
	# rooms, so the rooms are what has to be photographed -- and the
	# subjects are chosen by ASKING THE ZONE which chambers declare an
	# elevation band, never by naming one that looked good. A hand-picked
	# showcase id is how a generator gets judged on its best output.
	var shot := 0
	var banded: Array = []
	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		if typeof(chamber.get("elevation")) != TYPE_DICTIONARY:
			continue
		banded.append(chamber)
	print("  %d of %d chambers declare an elevation band"
			% [banded.size(), (build["chambers"] as Array).size()])
	for chamber: Dictionary in banded:
		var id := str(chamber.get("id", ""))
		var band: Dictionary = chamber["elevation"]
		var room: AABB = room_bounds.get(id, AABB())
		var aim: Vector3 = band_centre.get(id, room.get_center())
		await _shoot_room(camera, "%02d_room_%s_%s_%s" % [shot, id,
				str(band.get("kind", "")), str(band.get("side", ""))],
				room, str(band.get("side", "left")),
				float(entry_rotation.get(id, 0.0)), aim)
		shot += 1

	var seen := {}
	for runtime in runtimes:
		# One clean example of each kind, plus every activity the audit
		# currently notes. Not all thirty: the point is evidence a person
		# can look at, and thirty near-identical frames is not that.
		var flagged := runtime.activity_id in [
			"c003_0", "c008_0", "c012_0", "c015_0", "c017_0", "c021_0"]
		if seen.has(runtime.kind) and not flagged:
			continue
		seen[runtime.kind] = true
		var name := "%02d_%s_%s%s" % [shot, runtime.kind,
				runtime.activity_id, "_FLAGGED" if flagged else ""]
		await _shoot(camera, runtime, name,
				room_bounds.get(runtime.room_id, AABB()))
		shot += 1

	# CLOSE-UPS of one element per family, plus a run's START and GOAL
	# side by side. A wide shot of a 14 m activity is the wrong tool for
	# judging a silhouette -- the question "are these two the same
	# object" needs them big enough to answer.
	var closed := {}
	for runtime in runtimes:
		for element in runtime.elements:
			var label := runtime.kind
			if element.role != ActivityElement.ROLE_ELEMENT:
				label = "%s_%s" % [runtime.kind, element.role]
			elif runtime.kind == "timed_run":
				label = "timed_run_waypoint"
			if closed.has(label):
				continue
			closed[label] = true
			await _close_up(camera, element, "close_%s" % label,
					room_bounds.get(runtime.room_id, AABB()))
			shot += 1

	print("  wrote %d shots to %s"
			% [shot, ProjectSettings.globalize_path(OUT_DIR)])
	print("GODOT ZONE SHOTS OK")
	get_tree().quit(0)

func _runtimes_under(node: Node, out: Array[ActivityRuntime]) -> void:
	if node is ActivityRuntime:
		out.append(node as ActivityRuntime)
	for child in node.get_children():
		_runtimes_under(child, out)

## The whole room, from the high corner FURTHEST FROM THE BAND.
##
## Not a solved distance. `_shoot` frames a subject by backing the camera
## off until it fits, which for a subject the size of the room itself
## puts the camera outside it -- and the clamp that pulls it back in
## lands it in the middle of the furniture, which is what the first
## version of this produced: five photographs of the inside of a row of
## targets. A room shot is a corner shot, and the corner is chosen by
## where the band ISN'T so the deck and its ramp are both in frame.
##
## The side is named in ROOM space; the chamber is placed with a yaw, so
## the direction is rotated into the world before it is used.
func _shoot_room(camera: Camera3D, name: String, room: AABB,
		side: String, yaw: float, aim: Vector3) -> void:
	if room.size == Vector3.ZERO:
		return
	# AIMED AT THE BAND, which is the subject, and at head height above
	# the room's floor rather than at the middle of its bounds: the slab
	# allowance sits below the floor and a pit's bounds reach further
	# down still, so the bounds' centre points the camera at concrete.
	var centre := Vector3(aim.x, room.position.y
			+ minf(room.size.y * 0.4, 1.6), aim.z)
	# Away from the band: a gallery on the left is photographed from the
	# right, and a band across the back from the front.
	var away := Vector3(1.0, 0.0, 0.0)
	match side:
		"left":
			away = Vector3(1.0, 0.0, -0.55)
		"right":
			away = Vector3(-1.0, 0.0, -0.55)
		_:
			away = Vector3(0.35, 0.0, -1.0)
	away = Vector3(Vector2(away.x, away.z).rotated(yaw).x, 0.0,
			Vector2(away.x, away.z).rotated(yaw).y).normalized()
	var inner := room.grow(-CAMERA_MARGIN)
	if inner.size.x <= 0.0 or inner.size.z <= 0.0:
		inner = room
	var eye := room.get_center() \
			+ away * Vector2(room.size.x, room.size.z).length()
	eye = Vector3(
		clampf(eye.x, inner.position.x, inner.end.x),
		# High: at eye level a room is a wall of furniture, and the thing
		# being judged is the FLOOR PLAN -- where the deck is, where the
		# ramp lands, whether the crates are anywhere useful.
		room.position.y + room.size.y * 0.78,
		clampf(eye.z, inner.position.z, inner.end.z))
	camera.global_position = eye
	camera.look_at(centre, Vector3.UP)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(
			"%s/%s.png" % [OUT_DIR, name]))
	print("    %s  (room %.1f x %.1f m, band on the %s)"
			% [name, room.size.x, room.size.z, side])

## Frame the activity from its own extent.
##
## The one idea worth taking from `camera_rig.gd`: solve the distance
## from the subject's AABB and the camera's real FOV rather than guessing
## a vector. A hardcoded offset frames one room and misses the next.
func _shoot(camera: Camera3D, runtime: ActivityRuntime, name: String,
		room: AABB) -> void:
	var box := _extent(runtime)
	if box.size == Vector3.ZERO:
		return
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 1.0)
	var distance := radius / maxf(tan(deg_to_rad(FOV * 0.5)) * FILL, 0.01)
	# Slightly above and to one side: a dead-on shot of a row of boxes
	# hides how far apart they are, which is half of what a reader of
	# these is trying to see.
	var direction := Vector3(0.45, 0.42, 1.0).normalized()
	var eye := centre + direction * distance

	# KEPT INSIDE THE ROOM. The subject is interior, so the ideal
	# framing distance puts the camera through a wall and the frame
	# comes back as the OUTSIDE of a box -- which is what the first
	# version of this produced, eight shots of chamber exteriors that
	# looked like renders until you looked for the switches.
	if room.size != Vector3.ZERO:
		var inner := room.grow(-CAMERA_MARGIN)
		if inner.size.x > 0.0 and inner.size.y > 0.0 and inner.size.z > 0.0:
			# The FLOOR of the clamp is the subject, not the room. A
			# `platform_path`'s bounds reach forty metres down, so
			# clamping y into them dropped the camera under the platforms
			# and photographed the underside of the level.
			var lowest := minf(centre.y - 1.0, inner.end.y)
			eye = Vector3(
				clampf(eye.x, inner.position.x, inner.end.x),
				clampf(eye.y, maxf(inner.position.y, lowest), inner.end.y),
				clampf(eye.z, inner.position.z, inner.end.z))
	camera.global_position = eye
	camera.look_at(centre, Vector3.UP)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	image.save_png(ProjectSettings.globalize_path(path))
	print("    %s  (%d elements, subject %.1fm, camera %.1fm out)"
			% [name, runtime.elements.size(), radius * 2.0,
			camera.global_position.distance_to(centre)])

## One element, close enough to judge its outline.
func _close_up(camera: Camera3D, element: ActivityElement, name: String,
		room: AABB) -> void:
	var box := AABB()
	var started := false
	for child in element.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh := child as MeshInstance3D
		var world: AABB = mesh.global_transform * mesh.get_aabb()
		if not started:
			box = world
			started = true
		else:
			box = box.merge(world)
	if not started:
		return
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.6)
	var distance := radius / maxf(tan(deg_to_rad(FOV * 0.5)) * 0.4, 0.01)
	var direction := Vector3(0.5, 0.22, 1.0).normalized()
	var eye := centre + direction * distance
	if room.size != Vector3.ZERO:
		var inner := room.grow(-CAMERA_MARGIN)
		if inner.size.x > 0.0 and inner.size.z > 0.0:
			var lowest := minf(centre.y - 0.5, inner.end.y)
			eye = Vector3(
				clampf(eye.x, inner.position.x, inner.end.x),
				clampf(eye.y, maxf(inner.position.y, lowest), inner.end.y),
				clampf(eye.z, inner.position.z, inner.end.z))
	camera.global_position = eye
	camera.look_at(centre, Vector3.UP)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(
			"%s/%s.png" % [OUT_DIR, name]))
	print("    %s  (%.1fm tall)" % [name, box.size.y])

## The activity's own extent: every element's mesh, unioned.
func _extent(runtime: ActivityRuntime) -> AABB:
	var box := AABB()
	var started := false
	for element in runtime.elements:
		for child in element.get_children():
			if not (child is MeshInstance3D):
				continue
			var mesh := child as MeshInstance3D
			var world: AABB = mesh.global_transform * mesh.get_aabb()
			if not started:
				box = world
				started = true
			else:
				box = box.merge(world)
	return box
