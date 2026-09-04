extends Node
## ROOM GRAMMAR v0 (`make godot-room`).
##
## Everything here goes through `ZoneBuilder.build` or
## `ContentInstantiator.build_chamber` -- the paths the game takes. The
## project has been burned three times by a subsystem passing its own
## tests while the real composition path never reached it, most recently
## by an activity builder nothing called, so a suite that constructed its
## own rooms would be worth nothing.
##
## What is being defended:
##
## * a band the generator DESCRIBES exists as geometry you can stand on
## * ranged enemies are actually up there
## * sockets correspond to real surfaces, so nothing placed on one floats
## * environmental objects take damage and their consequence is real
## * a room feature cannot be described and silently dropped
## * neither shell route can strand room content

const DT := 1.0 / 60.0

var failures := 0
## Vacuity guards. Every "nothing bad happened" assertion is worthless if
## the suite built no bands and broke nothing.
var bands_built := 0
var objects_damaged := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

func _ready() -> void:
	await _run()

func _run() -> void:
	await get_tree().process_frame
	BridgeClient.snapshot = _snapshot()

	await _test_a_described_band_becomes_geometry()
	await _test_you_can_stand_on_a_gallery()
	await _test_a_pit_is_a_hole_not_a_painted_floor()
	await _test_the_band_is_reachable_by_walking()
	await _test_ranged_enemies_take_the_high_ground()
	await _test_every_socket_is_on_something_solid()
	await _test_environment_objects_land_on_sockets_only()
	await _test_nothing_is_placed_inside_anything_else()
	await _test_cover_breaks_and_stops_blocking()
	await _test_a_barrel_hurts_what_is_near_it()
	await _test_a_barrel_is_never_required()
	await _test_neither_shell_route_drops_room_content()
	await _test_a_platform_path_activity_stands_on_something()
	await _test_a_room_feature_cannot_be_silently_dropped()

	_check(bands_built >= 4,
			"the suite built %d bands; it is not exercising the grammar"
			% bands_built)
	_check(objects_damaged >= 2,
			"only %d environmental objects were driven; the damage path "
			% objects_damaged + "is untested")

	if failures == 0:
		print("GODOT ROOM TESTS OK")
		get_tree().quit(0)
	else:
		print("GODOT ROOM TESTS: %d failures" % failures)
		get_tree().quit(1)

# --- fixtures ------------------------------------------------------------

func _arena(band: Variant = null, enemies: Array = []) -> Dictionary:
	var chamber := {
		"id": "c1", "type": "arena", "width": 22.0, "depth": 20.0,
		"wall_height": 6.5, "objective": "kill_all",
		"enemies": enemies if not enemies.is_empty()
			else [{"archetype": "ranged", "count": 3}]}
	if band != null:
		chamber["elevation"] = band
	return chamber

func _gallery(side := "left") -> Dictionary:
	return {"kind": "gallery", "rise": 2.2, "coverage": 0.35,
			"side": side, "access": "ramp"}

func _pit() -> Dictionary:
	return {"kind": "pit", "rise": 1.6, "coverage": 0.35,
			"side": "back", "access": "ramp"}

func _built(chamber: Dictionary) -> Dictionary:
	var result := ContentInstantiator.build_chamber(
			chamber, "concrete_facility")
	if result.get("root") != null:
		add_child(result["root"] as Node3D)
	return result

func _drop(space: PhysicsDirectSpaceState3D, at: Vector3,
		reach := 3.0) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * 0.4, at - Vector3.UP * reach)
	query.collide_with_areas = false
	return space.intersect_ray(query)

func _space() -> PhysicsDirectSpaceState3D:
	return get_viewport().world_3d.direct_space_state

# --- the band is real ----------------------------------------------------

func _test_a_described_band_becomes_geometry() -> void:
	"""The Zone can DESCRIBE a band. This is the half that proves the
	client builds one rather than quietly ignoring the field."""
	var flat := _built(_arena())
	var raised := _built(_arena(_gallery()))
	bands_built += 1
	var flat_bounds: AABB = flat["bounds"]
	var raised_bounds: AABB = raised["bounds"]
	_check(_solid_count(raised["root"]) > _solid_count(flat["root"]),
			"a described gallery added no geometry at all")
	_check(flat_bounds.size.is_equal_approx(flat_bounds.size),
			"sanity")
	(flat["root"] as Node3D).queue_free()
	(raised["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _solid_count(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D:
		n += 1
	for child in node.get_children():
		n += _solid_count(child)
	return n

func _test_you_can_stand_on_a_gallery() -> void:
	"""Geometry existing is not the claim. The claim is that the surface
	holds a player up, which is a physics question."""
	for side: String in ["left", "right", "back"]:
		var result := _built(_arena(_gallery(side)))
		bands_built += 1
		await get_tree().physics_frame
		await get_tree().physics_frame
		var supported := 0
		for socket: Variant in result.get("sockets", []) as Array:
			var entry: Dictionary = socket
			if str(entry.get("kind", "")) != "enemy_high":
				continue
			var hit := _drop(_space(), entry["position"] as Vector3)
			if not hit.is_empty():
				supported += 1
		_check(supported >= 2,
				"a '%s' gallery has %d supported high sockets; the deck "
				% [side, supported] + "is not holding anything up")
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame

func _test_a_pit_is_a_hole_not_a_painted_floor() -> void:
	"""`_carve_gap` never removed the base slab and the Echo Lab has no
	gap because of it. A pit whose floor is still there at ground level
	is the same bug wearing a different name."""
	var result := _built(_arena(_pit()))
	bands_built += 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bounds: AABB = result["bounds"]
	_check(bounds.position.y < -1.0,
			"a pit did not lower the room's bounds (%.2f); nothing was "
			% bounds.position.y + "dug")
	var floor_hits := 0
	for socket: Variant in result.get("sockets", []) as Array:
		var entry: Dictionary = socket
		if str(entry.get("kind", "")) != "enemy_high":
			continue
		var at: Vector3 = entry["position"]
		_check(at.y < 0.0, "a pit's socket sits at %.2f, above the floor"
				% at.y)
		var hit := _drop(_space(), at)
		if not hit.is_empty():
			floor_hits += 1
	_check(floor_hits >= 2, "a pit has no floor to stand on")

	# AND THE LID IS OFF. Everything above passed while the arena still
	# laid one slab across the whole room: the recess was dug, the
	# sockets were below zero, a ray from inside the recess found its
	# deck -- and a player walking over the pit walked on the floor. The
	# question the earlier version never asked is what a ray from ABOVE
	# hits first.
	var band: Dictionary = _pit()
	var rect := ChamberBuilders.band_rect(band, 22.0, 20.0)
	var over := Vector3(rect.get_center().x, 3.0, rect.get_center().y)
	var query := PhysicsRayQueryParameters3D.create(
			over, over + Vector3.DOWN * 12.0)
	query.collide_with_areas = false
	var above := _space().intersect_ray(query)
	_check(not above.is_empty(), "nothing at all under the pit")
	if not above.is_empty():
		var y: float = (above["position"] as Vector3).y
		_check(y < -float(band["rise"]) + 0.6,
				"a ray dropped into the pit stops at %.2f m; the floor "
				% y + "slab was never opened and the pit is a basement")
	(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_the_band_is_reachable_by_walking() -> void:
	"""NO REQUIREMENT BEFORE GUARANTEE, applied to geometry.

	A band is reached by a ramp, and a ramp is base-kit traversal. The
	property asserted is that no step along it exceeds what base movement
	clears -- the same `MAX_VERTICAL_STEP` bound the schema already
	enforces on a `platform_path`'s mandatory jumps.
	"""
	var result := _built(_arena(_gallery()))
	bands_built += 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	var access: Dictionary = {}
	for socket: Variant in result.get("sockets", []) as Array:
		if str((socket as Dictionary).get("kind", "")) == "access":
			access = socket
	_check(not access.is_empty(),
			"a band offered no access socket, so nothing can say where "
			+ "the way up is")
	if access.is_empty():
		(result["root"] as Node3D).queue_free()
		return

	# Walk the RAMP, along the axis the builder said it runs. Probing a
	# line "toward the band" instead found the gallery's edge and
	# reported a 2.2 m step, which is a correct measurement of the wrong
	# surface.
	var at: Vector3 = access["position"]
	var length := float(access.get("length", 4.0))
	var along_z := str(access.get("along", "z")) == "z"
	var space := _space()
	var previous := -INF
	var worst := 0.0
	for step in 60:
		var t := (float(step) / 59.0 - 0.5) * (length + 3.0)
		var probe := at + (Vector3(0, 0, t) if along_z else Vector3(t, 0, 0))
		var hit := _drop(space, probe + Vector3.UP * 4.0, 8.0)
		if hit.is_empty():
			continue
		var here: float = (hit["position"] as Vector3).y
		if previous > -INF:
			worst = maxf(worst, absf(here - previous))
		previous = here
	_check(previous > -INF, "the access probe found no surface at all")
	_check(worst <= Constants.MAX_VERTICAL_STEP,
			"the ramp onto the band has a %.2f m step; base movement "
			% worst + "clears %.2f" % Constants.MAX_VERTICAL_STEP)
	(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

# --- combat uses it ------------------------------------------------------

func _test_ranged_enemies_take_the_high_ground() -> void:
	"""The measured problem: 28 of the played Zone's 41 enemies were
	ranged, in flat boxes, with no height to shoot from."""
	var flat := _built(_arena(null, [{"archetype": "ranged", "count": 3}]))
	var raised := _built(_arena(_gallery(),
			[{"archetype": "ranged", "count": 3}]))
	bands_built += 1
	var high := 0
	for spawn: Variant in raised.get("enemy_spawns", []) as Array:
		if (spawn as Dictionary)["position"].y > 1.0:
			high += 1
	_check(high >= 2, "only %d ranged enemies took the band" % high)
	for spawn: Variant in flat.get("enemy_spawns", []) as Array:
		_check((spawn as Dictionary)["position"].y < 1.0,
				"a flat room put an enemy in the air")
	# Melee stay down: the point is a spatial split, not everyone upstairs.
	var mixed := _built(_arena(_gallery(),
			[{"archetype": "melee", "count": 3}]))
	for spawn: Variant in mixed.get("enemy_spawns", []) as Array:
		_check((spawn as Dictionary)["position"].y < 1.0,
				"a melee enemy was put on the gallery")
	for r: Dictionary in [flat, raised, mixed]:
		(r["root"] as Node3D).queue_free()
	await get_tree().process_frame

# --- sockets -------------------------------------------------------------

func _test_every_socket_is_on_something_solid() -> void:
	"""THE POINT OF SOCKETS. A socket is a point the builder vouches for,
	so anything placed on one is supported by construction rather than by
	an audit finding 23 floating elements afterwards."""
	for band: Variant in [null, _gallery(), _gallery("back"), _pit()]:
		var result := _built(_arena(band))
		if band != null:
			bands_built += 1
		await get_tree().physics_frame
		await get_tree().physics_frame
		var sockets: Array = result.get("sockets", []) as Array
		_check(not sockets.is_empty(), "a room offered no sockets at all")
		for socket: Variant in sockets:
			var at: Vector3 = (socket as Dictionary)["position"]
			_check(not _drop(_space(), at, 4.0).is_empty(),
					"socket '%s' at %s has nothing under it"
					% [(socket as Dictionary).get("kind", "?"), at])
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame

func _test_environment_objects_land_on_sockets_only() -> void:
	var result := _built(_arena(_gallery()))
	bands_built += 1
	await get_tree().physics_frame
	var spots: Array[Vector3] = []
	for socket: Variant in result.get("sockets", []) as Array:
		var entry: Dictionary = socket
		if str(entry.get("kind", "")) in ["cover", "reactive"]:
			spots.append(entry["position"] as Vector3)
	var built: Array = result.get("environment", []) as Array
	_check(built.size() == spots.size(),
			"%d sockets offered, %d objects built" % [spots.size(),
				built.size()])
	for node: Variant in built:
		var at: Vector3 = (node as Node3D).position
		var matched := false
		for spot in spots:
			if absf(at.x - spot.x) < 0.01 and absf(at.z - spot.z) < 0.01:
				matched = true
		_check(matched, "an environmental object at %s is on no socket"
				% at)
	(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

func _test_nothing_is_placed_inside_anything_else() -> void:
	"""The socket contract measured on an assembled room, across two
	subsystems at once.

	Every other test here asks about ONE thing -- and that is exactly
	why the batch shipped a room with five activity elements inside
	cover before the real-Zone audit found it. The band built fine, the
	sockets were on solid ground, the objects took damage, and the room
	was still wrong, because nothing asked whether two subsystems that
	both place things had placed them in the same cubic metre.

	The room is the field case at its real size, not a roomy fixture:
	the first version of this test used the suite's 22 by 20 arena and
	every sabotage walked straight through it."""
	# THE FIELD CASE, at its real size. c015 of the played Zone: a 12.5
	# by 10.2 arena whose gallery takes 41% of it, holding a four-plate
	# routing puzzle. A roomy test room proves nothing here -- the first
	# version of this test used the 22 by 20 arena the rest of the suite
	# uses, and the sabotage walked straight through it, because a big
	# room has space for both and the bug only bites when it does not.
	var chamber := {
		"id": "c015", "type": "arena", "width": 12.5, "depth": 10.2,
		"wall_height": 6.2, "objective": "kill_all",
		"enemies": [{"archetype": "ranged", "count": 5}],
		"elevation": {"kind": "gallery", "rise": 2.28, "coverage": 0.41,
			"side": "right", "access": "ramp"},
		"activities": [{"kind": "pressure_routing", "element_count": 4,
			"ordered": false, "requires": []}]}
	var result := _built(chamber)
	bands_built += 1
	await get_tree().physics_frame

	var objects: Array = result.get("environment", []) as Array
	_check(not objects.is_empty(),
			"a crowded arena produced no environmental objects at all; "
			+ "this test would pass vacuously")
	var elements: Array[Node3D] = []
	for activity: Variant in result.get("activities", []) as Array:
		for element: Variant in (activity as Dictionary).get(
				"elements", []) as Array:
			elements.append(element as Node3D)
	_check(elements.size() == 4,
			"expected 4 activity elements, built %d" % elements.size())

	for node: Variant in objects:
		var object := node as Node3D
		var box := _box_of(object)
		for element in elements:
			_check(not box.intersects(_box_of(element)),
					"an environmental object at %v is inside an activity "
					% object.position + "element at %v" % element.position)
		for other: Variant in objects:
			if other == node:
				continue
			_check(not box.intersects(_box_of(other as Node3D)),
					"two environmental objects share space at %v"
					% object.position)
	(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

## The world-space box of the first mesh under `node`, shrunk a little:
## resting on a floor is touching, and only sharing space is a defect.
func _box_of(node: Node3D) -> AABB:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			return AABB(box.position + box.size * 0.1, box.size * 0.8)
	return AABB(node.global_position, Vector3.ZERO)

# --- the objects have verbs ---------------------------------------------

func _test_cover_breaks_and_stops_blocking() -> void:
	"""The consequence IS the removal. There is nothing inside it -- and
	that is deliberate, because Coins are an Archipelago item and a
	flavour log is not loot."""
	var host := Node3D.new()
	add_child(host)
	var cover := DestructibleCover.create("concrete_facility")
	host.add_child(cover)
	cover.global_position = Vector3(0, DestructibleCover.SIZE.y / 2.0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var from := Vector3(0, 0.8, -6)
	var to := Vector3(0, 0.8, 6)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	_check(not _space().intersect_ray(query).is_empty(),
			"the cover was not blocking the line to begin with")

	# Through the shared damage seam, so this exercises the path every
	# weapon in the game uses rather than a method only a test calls.
	var hits := 0
	while is_instance_valid(cover) and hits < 40:
		Damageable.hit(cover, 12.0, Vector3.FORWARD, 0.0)
		hits += 1
	objects_damaged += 1
	_check(hits > 1, "cover fell to a single hit; there is no wearing "
			+ "down to read")
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var after := PhysicsRayQueryParameters3D.create(from, to)
	after.collide_with_areas = false
	_check(_space().intersect_ray(after).is_empty(),
			"the line is still blocked after the cover broke")
	host.queue_free()
	await get_tree().process_frame

func _test_a_barrel_hurts_what_is_near_it() -> void:
	var host := Node3D.new()
	add_child(host)
	var barrel := ReactiveBarrel.create("concrete_facility")
	host.add_child(barrel)
	barrel.global_position = Vector3.ZERO
	var near := DestructibleCover.create("concrete_facility")
	host.add_child(near)
	near.global_position = Vector3(2.0, 0.7, 0.0)
	var far := DestructibleCover.create("concrete_facility")
	host.add_child(far)
	far.global_position = Vector3(0.0, 0.7, 30.0)
	await get_tree().physics_frame

	var near_before := near.hp
	var far_before := far.hp
	Damageable.hit(barrel, ReactiveBarrel.HP + 1.0, Vector3.FORWARD, 0.0)
	objects_damaged += 1
	await get_tree().process_frame
	_check(near.hp < near_before,
			"a barrel went off and hurt nothing beside it")
	_check(is_equal_approx(far.hp, far_before),
			"a barrel reached %.1f m away; its radius is %.1f"
			% [30.0, ReactiveBarrel.RADIUS])
	_check(not is_instance_valid(barrel), "a spent barrel is still there")
	host.queue_free()
	await get_tree().process_frame

func _test_a_barrel_is_never_required() -> void:
	"""Damage is BALANCE, never LOGIC. Nothing may check that a barrel
	was used, and a room must not name one as a prerequisite."""
	# Loaded by path, not via `get_script()` on the class: a `class_name`
	# global IS the GDScript resource, so asking it for its script
	# returns null and the check silently never runs.
	var paths := ["res://scripts/gameplay/destructible_cover.gd",
			"res://scripts/gameplay/reactive_barrel.gd"]
	for path: String in paths:
		var script := load(path) as GDScript
		_check(script != null, "cannot read '%s' to check it" % path)
		if script == null:
			continue
		var text := script.source_code
		for forbidden: String in ["location_id", "reward_location_id",
				"confirm_check", "signal_keys", "coins"]:
			_check(not text.contains(forbidden),
					"an environmental object names '%s'; it is reaching "
					% forbidden + "for Archipelago truth")

func _test_a_platform_path_activity_stands_on_something() -> void:
	"""A `platform_path` has no floor, and content was laid out over the
	void for five rooms of the played Zone.

	The row solver reads the room's WIDTH and DEPTH, which presumes a
	floor across them. True of an arena. False here: the space between
	the islands is a kill pit and the bounds reach forty metres down, so
	twenty-three elements were placed where nothing holds weight.

	Built through `ContentInstantiator.build_chamber` -- the route the
	game takes -- and then measured with a ray, because a coordinate
	that looks reasonable is exactly what the old placement produced."""
	var chamber := {
		"id": "pp1", "type": "platform_path", "segment_count": 4,
		"gap_size": 2.1, "vertical_step": 0.51,
		"enemies": [{"archetype": "melee", "count": 2}],
		"activities": [
			{"kind": "pressure_routing", "element_count": 4,
				"ordered": false, "requires": []},
			{"kind": "switch_sequence", "element_count": 3,
				"ordered": true, "requires": []}]}
	var result := _built(chamber)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var stands := 0
	for socket: Variant in result.get("sockets", []) as Array:
		if str((socket as Dictionary).get("kind", "")) == "stand":
			stands += 1
	_check(stands == 6, "a 4-segment platform path vouched for %d "
			% stands + "standable surfaces; two ledges and four islands "
			+ "is six")

	var elements: Array[Node3D] = []
	for activity: Variant in result.get("activities", []) as Array:
		for element: Variant in (activity as Dictionary).get(
				"elements", []) as Array:
			elements.append(element as Node3D)
	_check(elements.size() == 7,
			"expected 7 activity elements, built %d" % elements.size())

	var space := _space()
	for element in elements:
		var at := element.global_position
		# Straight down from just under the element. `GROUND_REACH` is
		# the audit's own number for "within reach below"; a kill pit
		# floor sits FALL_KILL_Y - 6 down, so nothing here can pass by
		# finding the bottom of the world.
		var query := PhysicsRayQueryParameters3D.create(
				at + Vector3.DOWN * 0.05,
				at + Vector3.DOWN * 1.25)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		_check(not hit.is_empty(),
				"an activity element at %v has nothing under it; a "
				% at + "platform path is islands over a kill pit")
		if hit.is_empty():
			continue
		# And it is standing ON the surface, not embedded in one.
		var drop: float = at.y - (hit["position"] as Vector3).y
		_check(drop >= -0.01,
				"an activity element at %v is INSIDE the surface under "
				% at + "it")

	(result["root"] as Node3D).queue_free()
	await get_tree().process_frame

	# AND THE ROUTE STAYS CLEAR, at the largest room the schema admits:
	# three activities of eight. The ledges hold about six plates each,
	# so twenty-four is past their capacity and the islands are the next
	# thing a placer would reach for -- and an island is 2.5 m of the
	# MANDATORY ROUTE over a kill pit, with no way past a plate on one.
	var packed := chamber.duplicate()
	packed["id"] = "pp2"
	packed["activities"] = [
		{"kind": "pressure_routing", "element_count": 8,
			"ordered": false, "requires": []},
		{"kind": "pressure_routing", "element_count": 8,
			"ordered": false, "requires": []},
		{"kind": "pressure_routing", "element_count": 8,
			"ordered": false, "requires": []}]
	var full := _built(packed)
	await get_tree().physics_frame
	var islands: Array[Rect2] = []
	for socket: Variant in full.get("sockets", []) as Array:
		var entry: Dictionary = socket
		if str(entry.get("kind", "")) != "stand":
			continue
		var extent: Vector3 = entry["extent"]
		if extent.x > Constants.MIN_PLATFORM_SIZE:
			continue
		var at: Vector3 = entry["position"]
		islands.append(Rect2(at.x - extent.x / 2.0, at.z - extent.z / 2.0,
				extent.x, extent.z))
	_check(islands.size() == 4, "expected 4 islands, found %d"
			% islands.size())
	var on_island := 0
	for activity: Variant in full.get("activities", []) as Array:
		for element: Variant in (activity as Dictionary).get(
				"elements", []) as Array:
			var at := (element as Node3D).position
			for island in islands:
				if island.has_point(Vector2(at.x, at.z)):
					on_island += 1
	_check(on_island == 0, "%d activity element(s) sit on a platform "
			% on_island + "path's mandatory islands")
	(full["root"] as Node3D).queue_free()
	await get_tree().process_frame

# --- routing -------------------------------------------------------------

func _test_neither_shell_route_drops_room_content() -> void:
	"""The bug this project shipped: the population step lived at the
	bottom of one of `_shell`'s exits and the game takes a different
	one."""
	var chamber := _arena(_gallery())
	var routes := {
		"registry as shipped": ContentRegistry.shared(),
		"nothing registered": _registry({}),
		"shell present, procedural fallback": _registry({
			"shell_arena_proc": {"id": "shell_arena_proc",
				"category": "room_shell", "procedural_fallback": true}}),
	}
	for label: String in routes:
		var result := ContentInstantiator.build_chamber(
				chamber, "concrete_facility", routes[label])
		bands_built += 1
		_check(not (result.get("sockets", []) as Array).is_empty(),
				"route '%s' produced no sockets" % label)
		_check(not (result.get("environment", []) as Array).is_empty(),
				"route '%s' produced no environmental objects" % label)
		var root := result.get("root") as Node3D
		if root != null:
			root.queue_free()
		await get_tree().process_frame

func _test_a_room_feature_cannot_be_silently_dropped() -> void:
	"""The generator must not be able to describe something the client
	ignores. Every elevation `kind` the schema admits has to build."""
	for kind: String in ["gallery", "pit"]:
		var band := _gallery() if kind == "gallery" else _pit()
		var result := _built(_arena(band))
		bands_built += 1
		var high := 0
		for socket: Variant in result.get("sockets", []) as Array:
			if str((socket as Dictionary).get("kind", "")) == "enemy_high":
				high += 1
		_check(high >= 2,
				"elevation kind '%s' built no high sockets, so the client "
				% kind + "took the description and produced nothing")
		(result["root"] as Node3D).queue_free()
		await get_tree().process_frame

func _registry(entries: Dictionary) -> ContentRegistry:
	var reg := ContentRegistry.new()
	reg.entries = entries
	return reg

func _snapshot() -> Dictionary:
	return {
		"type": "campaign_snapshot",
		"mechanics": {"owned": [], "aliases": [], "links": [],
				"statuses": [], "resources": []},
		"slots": {}, "local_rewards": [],
		"available_capabilities": ["ranged_hit"],
		"coins_received": 0, "coins_spent": 0, "hub": {"state": "IDLE"},
	}
