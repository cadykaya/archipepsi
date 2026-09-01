class_name ShellValidator
extends RefCounted
## Does the shell actually do what its manifest says? (v0.9 D1)
##
## The owner decision draws the authority line:
##
##     EPSILON CHOOSES INTENT.
##     AUTHORED CONTENT OWNS GEOMETRY.
##     GODOT VALIDATES PHYSICAL TRUTH.
##
## The third line is this file, and the important word in it is
## **validates**. `schemas/content.py` already refuses a manifest whose
## DECLARED traversal exceeds the base kit -- but a manifest is a claim
## an artist typed, and the scene is what the player walks through. An
## asset is not trusted because its metadata says it is safe.
##
## So this instantiates the shell and measures it: the sockets and
## traversal markers that are really in the scene, against the numbers
## the manifest promised, against `Constants.max_safe_gap`. It is the
## same move the S16 tower fix made -- read the built positions rather
## than the source that produced them -- applied to content nobody on
## this team wrote.
##
## Marker convention (`ART_ASSET_SPEC.md`): a traversal segment named
## `hop` is measured from `Marker3D` nodes `hop_start` and `hop_end`.
## A shell that declares a segment and ships no markers for it cannot be
## checked, and an unverifiable mandatory route is refused rather than
## assumed good.

## How far a measured position may differ from its declared one before
## the manifest counts as wrong. Generous enough for float error and an
## artist nudging a marker; far tighter than the difference between a
## jump that works and one that does not.
const POSITION_TOLERANCE := 0.15

## Every reason this shell may not be used. Empty is the contract.
##
## `entry` is the registry entry; `instance` is the already-instantiated
## scene. Instantiation stays the caller's job so a validator cannot be
## the thing that loads content into a live tree.
static func refusals(entry: Dictionary, instance: Node3D) -> Array[String]:
	var out: Array[String] = []
	var id := str(entry.get("id", "?"))

	for segment: Variant in entry.get("traversal", []):
		if typeof(segment) != TYPE_DICTIONARY:
			out.append("%s: a traversal entry is not an object" % id)
			continue
		out.append_array(_check_segment(id, segment, instance))

	out.append_array(_check_sockets(id, entry, instance))
	out.append_array(_check_envelope(id, entry, instance))
	return out

static func _check_segment(id: String, segment: Dictionary,
		instance: Node3D) -> Array[String]:
	var out: Array[String] = []
	var name := str(segment.get("name", "?"))
	var mandatory: bool = bool(segment.get("mandatory", true))

	var declared_start := _vector(segment.get("start", []))
	var declared_end := _vector(segment.get("end", []))

	var start_node := instance.find_child("%s_start" % name, true, false)
	var end_node := instance.find_child("%s_end" % name, true, false)
	if not (start_node is Marker3D) or not (end_node is Marker3D):
		# Only mandatory routes are refused for being unmeasurable. An
		# optional perch nobody has to reach is allowed to be described
		# without being marked up.
		if mandatory:
			out.append(("%s: mandatory traversal '%s' has no %s_start / "
					% [id, name, name])
					+ "%s_end markers, so its safety cannot be measured "
					% name + "-- and an unverifiable mandatory route is "
					+ "refused, not assumed good")
		return out

	var measured_start: Vector3 = (start_node as Marker3D).position
	var measured_end: Vector3 = (end_node as Marker3D).position

	# 1. Does the scene match the claim?
	for pair: Array in [["start", declared_start, measured_start],
			["end", declared_end, measured_end]]:
		var drift: float = (pair[1] as Vector3).distance_to(pair[2])
		if drift > POSITION_TOLERANCE:
			out.append("%s: traversal '%s' declares its %s at %s but the "
					% [id, name, pair[0], pair[1]]
					+ "scene puts it at %s (%.2f m out)" % [pair[2], drift])

	if not mandatory:
		return out

	# 2. Is the MEASURED movement inside the base kit? Measured, not
	#    declared -- a manifest that lies in a direction the drift check
	#    tolerates must still not produce an impossible jump.
	var rise: float = measured_end.y - measured_start.y
	var span := Vector2(measured_end.x - measured_start.x,
			measured_end.z - measured_start.z).length()
	if rise > Constants.MAX_VERTICAL_STEP + 0.001:
		out.append("%s: mandatory traversal '%s' rises %.2f m as built; "
				% [id, name, rise]
				+ "the base kit tops out at %.2f m"
				% Constants.MAX_VERTICAL_STEP)
	var allowed := Constants.max_safe_gap(maxf(rise, 0.0))
	if span > allowed + 0.001:
		out.append("%s: mandatory traversal '%s' spans %.2f m at a %.2f m "
				% [id, name, span, rise]
				+ "rise as built; the base kit's safe reach there is "
				+ "%.2f m" % allowed)
	return out

## Does the shell fit in the box it claims? (P1)
##
## `content.py` has always documented `size` as "Godot re-derives this
## from the real scene and refuses a manifest that lies about it", and
## nothing kept that promise. Rooms are chained by butting their declared
## envelopes together, so a shell whose geometry reaches past its own
## `size` reaches into the next room -- and the overlap guard that would
## have caught it is fed the DECLARED bounds, which is exactly the number
## being lied about.
##
## Measured from mesh AABBs, unfiltered: `solid_boxes` skips room-scale
## geometry because a floor slab overlaps everything a composer might
## place, and here the floor slab is the point.
static func _check_envelope(id: String, entry: Dictionary,
		instance: Node3D) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = entry.get("size", [])
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 3:
		return out
	var size := _vector(raw)
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return out
	var envelope := AABB(
			Vector3(-size.x / 2.0, -ContentInstantiator.FLOOR_ALLOWANCE,
					0.0),
			Vector3(size.x, size.y + ContentInstantiator.FLOOR_ALLOWANCE,
					size.z)).grow(POSITION_TOLERANCE)
	var worst := 0.0
	var count := 0
	for box in _mesh_boxes(instance, Transform3D.IDENTITY):
		if envelope.encloses(box):
			continue
		count += 1
		for axis in 3:
			worst = maxf(worst, maxf(
					envelope.position[axis] - box.position[axis],
					box.end[axis] - envelope.end[axis]))
	if count > 0:
		out.append("%s: %d mesh(es) reach up to %.2f m outside the "
				% [id, count, worst] + "%.1f x %.1f x %.1f m envelope "
				% [size.x, size.y, size.z] + "the manifest declares")
	return out

## Every mesh AABB under `node`, in the shell's own space.
##
## The transform is accumulated BY HAND. `global_transform` does not
## accumulate for a node outside the scene tree, and a shell is measured
## before it is added to one -- the mistake that once made every prop in
## a chamber come back stacked near the origin.
static func _mesh_boxes(node: Node, xform: Transform3D) -> Array[AABB]:
	var out: Array[AABB] = []
	var here := xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(here * (node as MeshInstance3D).get_aabb())
	for child in node.get_children():
		out.append_array(_mesh_boxes(child, here))
	return out

## Sockets are the other half of the claim: a doorway the manifest says
## is 2.4 m wide, in a scene where the marker sits somewhere else, joins
## rooms in the wrong place.
static func _check_sockets(id: String, entry: Dictionary,
		instance: Node3D) -> Array[String]:
	var out: Array[String] = []
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = socket
		var name := str(s.get("name", "?"))
		var node := instance.find_child(name, true, false)
		if not (node is Marker3D):
			continue      # markers are encouraged, not yet required
		var drift: float = _vector(s.get("position", [])).distance_to(
				(node as Marker3D).position)
		if drift > POSITION_TOLERANCE:
			out.append("%s: socket '%s' is declared at %s and marked at "
					% [id, name, _vector(s.get("position", []))]
					+ "%s (%.2f m out)"
					% [(node as Marker3D).position, drift])
	return out

static func _vector(raw: Variant) -> Vector3:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 3:
		return Vector3.ZERO
	var a: Array = raw
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

# --- selection -------------------------------------------------------------

## The shells this campaign may offer Epsilon for one chamber type.
##
## Sorted, because the catalog goes into a prompt and a prompt that
## reorders itself between runs is a prompt that regenerates differently
## from the same seed.
static func catalog(registry: ContentRegistry, category: String,
		size_class: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in registry.ids_of_category(category):
		var entry := registry.get_entry(id)
		if bool(entry.get("procedural_fallback", false)):
			continue
		if size_class != "" \
				and str(entry.get("size_class", "")) != size_class:
			continue
		out.append(id)
	out.sort()
	return out

## Picks one shell when Epsilon named intent but no specific id.
##
## Deterministic from `seed_key`: the same seed lays out the same
## campaign on every machine, and "pick a variant" is exactly the kind of
## place a stray `randi()` breaks that quietly.
static func pick(candidates: Array[String], seed_key: String) -> String:
	if candidates.is_empty():
		return ""
	var sorted := candidates.duplicate()
	sorted.sort()
	return sorted[abs(hash(seed_key)) % sorted.size()]
