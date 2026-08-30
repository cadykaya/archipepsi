extends Node
## The real-Zone activity audit (`make godot-zone-audit`).
##
## WHY THIS EXISTS. `activity_driver.gd` calls `Activities.build` itself.
## That suite was green while the game built ZERO activities in ZERO
## rooms, because `build_chamber` returned before the loop on every route
## the registry actually takes. It proved the runtime works and nothing
## about whether anything reaches it.
##
## So nothing here constructs an activity. It loads the JSON of the Zone
## a baseline playtest actually walks -- written by
## `python -m archipepsi_bridge.playtest dump`, so it is the same Zone
## with the same digest, not a fixture that resembles one -- hands it to
## `ZoneBuilder.build`, and then measures what came out with physics.
##
## AUDIT, not gameplay. It changes nothing and asserts only about the
## assembled scene.

const ZONE_JSON := "res://tests/fixtures/played_zone.json"
const AUDIT_OUT := "user://zone_activity_audit.json"

## Where a player's chest is ABOVE THE WALKABLE PLANE.
##
## Not above the AABB. A chamber's bounds start `FLOOR_ALLOWANCE` BELOW
## the floor, to hold the slab -- so `bounds.position.y + EYE` is 20 cm
## off the ground, and for a `platform_path` (whose bounds reach 40 m
## down) it is deep underground. The first version of this probe did
## exactly that and reported most of the Zone unreachable, which is the
## same mistake a wall probe in this project made once before: measuring
## from the bottom of the box instead of from the floor.
const EYE := 1.2
const FLOOR_ALLOWANCE := 1.0
## How far outside a chamber's own AABB an element may sit before it is
## in another room's geometry rather than this one's.
const BOUNDS_SLACK := 0.05

var failures := 0
## Placement findings. Recorded and printed, but they do not fail the
## run: they are KNOWN OPEN DEFECTS as of this audit
## (`docs/ZONE_ACTIVITY_AUDIT.md`), and a target that goes red on a
## defect somebody has already written down and decided not to fix
## tonight is a target people learn to ignore.
##
## What DOES fail: structure. A declared activity with no runtime, a
## runtime with the wrong element count, a kind that cannot be completed
## in the assembled Zone. Those are the claims this batch exists to make,
## and none of them may quietly stop being true.
var notes := 0
var audited := 0
var rows: Array = []
## Every collider belonging to any activity in the Zone, so a
## reachability ray can be asked about the LEVEL alone.
var _all_activity_rids: Array[RID] = []

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)

## A placement finding: printed, counted, and not fatal.
func _note(condition: bool, message: String) -> void:
	if not condition:
		notes += 1
		print("  NOTE: " + message)

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

	var zone := _load_zone()
	if zone.is_empty():
		_check(false, "could not load %s -- run `playtest dump` first"
				% ZONE_JSON)
		_finish()
		return

	var declared := _declared_activities(zone)
	print("  Zone %s: %d chambers, %d activities declared"
			% [zone.get("zone_id", "?"), (zone["chambers"] as Array).size(),
			declared.size()])

	var build := ZoneBuilder.build(zone)
	var root: Node3D = build["root"]
	add_child(root)
	# Two physics frames so every Area3D has registered its overlaps and
	# every static body is in the space before anything is queried.
	await get_tree().physics_frame
	await get_tree().physics_frame

	_audit(build, declared)
	await _drive_one_of_every_kind(build)

	root.queue_free()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	_write_audit()
	print("  %d activities audited, %d structural failures, %d placement "
			% [audited, failures, notes] + "notes")
	if failures == 0:
		print("GODOT ZONE AUDIT OK")
		get_tree().quit(0)
	else:
		print("GODOT ZONE AUDIT: %d failures" % failures)
		get_tree().quit(1)

# --- inputs --------------------------------------------------------------

func _load_zone() -> Dictionary:
	if not ResourceLoader.exists(ZONE_JSON) \
			and not FileAccess.file_exists(ZONE_JSON):
		return {}
	var text := FileAccess.get_file_as_string(ZONE_JSON)
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

## What the GENERATION DATA promises, before anything is built. The audit
## is a comparison against this, so "the game built what the Zone said"
## is a claim with two sides rather than a count of whatever appeared.
func _declared_activities(zone: Dictionary) -> Array:
	var out: Array = []
	var chambers: Array = zone["chambers"]
	for index in chambers.size():
		var chamber: Dictionary = chambers[index]
		var list: Array = chamber.get("activities", []) as Array
		for j in list.size():
			var activity: Dictionary = list[j]
			out.append({
				"room_index": index,
				"room_id": str(chamber.get("id", "")),
				"room_type": str(chamber.get("type", "")),
				"activity_id": "%s_%d" % [str(chamber.get("id", "")), j],
				"kind": str(activity.get("kind", "")),
				"element_count": int(activity.get("element_count", 1)),
				"time_limit": float(activity.get("time_limit", 0.0)),
				"ordered": bool(activity.get("ordered", false)),
				"requires": activity.get("requires", []),
			})
	return out

func _runtimes_under(node: Node, out: Array[ActivityRuntime]) -> void:
	if node is ActivityRuntime:
		out.append(node as ActivityRuntime)
	for child in node.get_children():
		_runtimes_under(child, out)

# --- the audit -----------------------------------------------------------

func _audit(build: Dictionary, declared: Array) -> void:
	var root: Node3D = build["root"]
	var found: Array[ActivityRuntime] = []
	_runtimes_under(root, found)

	_check(found.size() == declared.size(),
			"the Zone declares %d activities and the assembled scene "
			% declared.size() + "holds %d runtimes" % found.size())

	var by_id := {}
	for runtime in found:
		by_id[runtime.activity_id] = runtime

	# Chamber world bounds, so an element can be checked against the room
	# it belongs to rather than against the Zone.
	var room_bounds := {}
	for entry: Dictionary in build["chambers"]:
		var chamber: Dictionary = entry["chamber"]
		var xform: Transform3D = entry["xform"]
		var local: AABB = (entry["build"] as Dictionary).get("bounds", AABB())
		room_bounds[str(chamber.get("id", ""))] = ZoneBuilder._world_aabb(
				local, xform.origin, xform.basis.get_euler().y)

	_all_activity_rids = []
	for runtime in found:
		for element in runtime.elements:
			_collect_rids(element, _all_activity_rids)

	var space := get_viewport().world_3d.direct_space_state
	for row: Dictionary in declared:
		var id: String = row["activity_id"]
		var runtime: ActivityRuntime = by_id.get(id)
		var record := row.duplicate()
		record["runtime_exists"] = runtime != null
		if runtime == null:
			_check(false, "activity '%s' (%s in room %s) is in the Zone "
					% [id, row["kind"], row["room_id"]]
					+ "data and has no runtime in the scene")
			rows.append(record)
			continue

		var expected: int = runtime.placed_count()
		record["elements_expected"] = expected
		record["elements_built"] = runtime.elements.size()
		_check(runtime.elements.size() == expected,
				"activity '%s' built %d of %d elements"
				% [id, runtime.elements.size(), expected])

		var bounds: AABB = room_bounds.get(row["room_id"], AABB())
		# Every activity element in the WHOLE Zone, so an overlap can be
		# attributed: sharing space with the level is one defect and
		# sharing it with another puzzle is a different one.
		var positions: Array = []
		var outside := 0
		var in_level := 0
		var in_other_activity := 0
		var unreachable := 0
		var blockers: Array = []
		for element in runtime.elements:
			var p := element.global_position
			positions.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01),
					snappedf(p.z, 0.01)])
			if not _inside(bounds, element):
				outside += 1
			var own: Array[RID] = []
			_collect_rids(element, own)
			for hit: Dictionary in _overlaps(space, element, own):
				if _is_activity_part(hit.get("collider")):
					in_other_activity += 1
				else:
					in_level += 1
			if not _is_reachable(space, element, bounds, runtime):
				unreachable += 1
				var who := _blocker(space, element, bounds, runtime)
				if who != "" and not blockers.has(who):
					blockers.append(who)
		record["positions"] = positions
		record["outside_bounds"] = outside
		record["embedded_in_level"] = in_level
		record["overlapping_another_activity"] = in_other_activity
		record["unreachable"] = unreachable
		record["blocked_by"] = blockers
		record["state"] = runtime.state

		_check(outside == 0,
				"activity '%s': %d element(s) sit outside the bounds of "
				% [id, outside] + "room '%s'" % row["room_id"])
		_note(in_level == 0,
				"activity '%s': %d element overlap(s) with wall, floor, "
				% [id, in_level] + "ceiling or prop geometry")
		_note(in_other_activity == 0,
				"activity '%s': %d element overlap(s) with ANOTHER "
				% [id, in_other_activity] + "activity's elements")
		_note(unreachable == 0,
				"activity '%s': %d element(s) cannot be seen from the "
				% [id, unreachable] + "room's walking space (blocked by %s)"
				% ", ".join(PackedStringArray(blockers)))
		rows.append(record)
		audited += 1

	_check(audited > 0, "the audit examined nothing")

## Does the element's whole box sit inside the room it belongs to?
func _inside(bounds: AABB, element: ActivityElement) -> bool:
	if bounds.size == Vector3.ZERO:
		return true
	var box := _world_box(element)
	var grown := bounds.grow(BOUNDS_SLACK)
	return grown.encloses(box)

func _world_box(element: ActivityElement) -> AABB:
	for child in element.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			return mesh.global_transform * mesh.get_aabb()
	return AABB(element.global_position, Vector3.ZERO)

## Is any ROOM geometry sharing space with the element?
##
## A shape query rather than a raycast: an element fully inside a wall is
## something no ray from outside ever reaches, so asking "does anything
## overlap me" is the question, and asking "can I see it" is not.
func _overlaps(space: PhysicsDirectSpaceState3D,
		element: ActivityElement, exclude: Array[RID]) -> Array:
	var box := _world_box(element)
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	# Shrunk a little: a plate RESTS on the floor and a switch may touch a
	# wall it is mounted on. Touching is mounting; overlapping is being
	# buried, and only the second is a defect.
	shape.size = box.size * 0.8
	query.shape = shape
	query.transform = Transform3D(Basis(), box.get_center())
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	return space.intersect_shape(query, 8)

## Is this collider part of an activity, rather than part of the level?
func _is_activity_part(collider: Variant) -> bool:
	var node := collider as Node
	while node != null:
		if node is ActivityElement:
			return true
		node = node.get_parent()
	return false

func _collect_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_rids(child, out)

## What stopped the CLOSEST probe ray, for the report. Diagnostic only:
## "an element is blocked" is a finding nobody can act on, and "blocked by
## the floor" and "blocked by a prop" have different answers.
func _blocker(space: PhysicsDirectSpaceState3D, element: ActivityElement,
		bounds: AABB, runtime: ActivityRuntime) -> String:
	var target := _world_box(element).get_center()
	var from := Vector3(bounds.get_center().x,
			_floor_under(element, runtime) + EYE, target.z)
	var query := PhysicsRayQueryParameters3D.create(from, target)
	query.collide_with_areas = false
	query.exclude = _all_activity_rids
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return ""
	var node := hit["collider"] as Node
	if node == null:
		return "?"
	# Anonymous StaticBody3Ds are most of a procedural room, so the name
	# alone says nothing. The parent is what was actually built.
	var parent := node.get_parent()
	return "%s/%s" % [parent.name if parent != null else "?", node.name]

## The walkable plane under this element, from the element itself.
##
## NOT from the chamber bounds. That convention was got wrong twice here:
## bounds start `FLOOR_ALLOWANCE` below the floor, and a `platform_path`
## reaches forty metres down, so "bounds bottom plus chest height" put
## the probe underground and reported most of the Zone blocked by the
## platforms above it.
##
## `RULES[kind].height` is what the builder RAISED the element by, so
## subtracting it lands exactly on the plane the builder measured from.
## No convention, no allowance, nothing to get wrong.
func _floor_under(element: ActivityElement,
		runtime: ActivityRuntime) -> float:
	return element.global_position.y - float(runtime.rules()["height"])

## How many points along the walking lane the reachability probe tries.
const PROBE_STEPS := 9

## Can the element be seen from ANYWHERE a player can stand?
##
## Sampled along the room's centre line -- the walking lane every builder
## keeps clear -- rather than from one point. A player walks; an element
## one probe cannot see past a prop is not unreachable, it is behind
## something you step around.
##
## Every activity element is excluded, not just this one's. A ray stopped
## by another puzzle piece is not an element buried in the level, and the
## overlap check above already reports co-location as its own defect.
func _is_reachable(space: PhysicsDirectSpaceState3D,
		element: ActivityElement, bounds: AABB,
		runtime: ActivityRuntime) -> bool:
	if bounds.size == Vector3.ZERO:
		return true
	var target := _world_box(element).get_center()
	var centre := bounds.get_center()
	var floor_y := _floor_under(element, runtime)
	var near := bounds.position.z
	var span := bounds.size.z
	for step in PROBE_STEPS:
		var t := float(step) / float(PROBE_STEPS - 1)
		var z := near + span * t
		for height: float in [EYE, 0.6]:
			var from := Vector3(centre.x, floor_y + height, z)
			var query := PhysicsRayQueryParameters3D.create(from, target)
			query.collide_with_areas = false
			query.exclude = _all_activity_rids
			if space.intersect_ray(query).is_empty():
				return true
	return false

# --- driving what the Zone built ----------------------------------------

func _drive_one_of_every_kind(build: Dictionary) -> void:
	"""One REAL instance of each kind, taken to completion in the
	assembled Zone. Not a fresh activity built for the test."""
	var found: Array[ActivityRuntime] = []
	_runtimes_under(build["root"], found)
	var seen := {}
	for runtime in found:
		if seen.has(runtime.kind):
			continue
		seen[runtime.kind] = true
		await _drive_to_completion(runtime)
	for kind: String in ActivityRuntime.RULES:
		_check(seen.has(kind),
				"Zone 1 holds no '%s' to drive; the kind is unproven in a "
				% kind + "real Zone")

func _drive_to_completion(runtime: ActivityRuntime) -> void:
	_check(runtime.state == ActivityRuntime.State.IDLE,
			"'%s' (%s) did not start IDLE in the assembled Zone (state %d)"
			% [runtime.activity_id, runtime.kind, runtime.state])
	var total := runtime.elements.size()
	for i in total:
		await _touch(runtime.elements[i])
		if i == 0:
			_check(runtime.state == ActivityRuntime.State.ACTIVE,
					"'%s' did not go ACTIVE after its first element"
					% runtime.activity_id)
		elif i < total - 1:
			_check(runtime.state != ActivityRuntime.State.COMPLETE,
					"'%s' completed at element %d of %d"
					% [runtime.activity_id, i + 1, total])
	_check(runtime.state == ActivityRuntime.State.COMPLETE,
			"'%s' (%s) could not be completed in the assembled Zone "
			% [runtime.activity_id, runtime.kind] + "(state %d)"
			% runtime.state)
	print("    drove %s '%s' to %s" % [runtime.kind, runtime.activity_id,
			"COMPLETE" if runtime.state == ActivityRuntime.State.COMPLETE
			else "state %d" % runtime.state])

func _touch(element: ActivityElement) -> void:
	if element.trigger == ActivityElement.SHOT:
		Damageable.hit(element.get_node("TargetBody"), 1.0, Vector3.FORWARD)
		return
	var body := CharacterBody3D.new()
	body.add_to_group("player")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.6, 0.6)
	shape.shape = box
	body.add_child(shape)
	element.add_child(body)
	body.global_position = element.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	body.queue_free()
	await get_tree().process_frame

# --- the record ----------------------------------------------------------

func _write_audit() -> void:
	var payload := {
		"activities": rows,
		"audited": audited,
		"failures": failures,
		"placement_notes": notes,
	}
	var file := FileAccess.open(AUDIT_OUT, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	print("  audit written to %s" % ProjectSettings.globalize_path(AUDIT_OUT))
