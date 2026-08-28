class_name ContentInstantiator
extends RefCounted
## The S13 pipeline: where a chamber's geometry actually comes from.
##
##     AUTHORED SCENE IF AVAILABLE
##             -> VALIDATED PLACEHOLDER / FALLBACK OTHERWISE
##
## Every chamber the game builds now goes through here. Today every route
## ends at `ChamberBuilders`, because every registry entry is still
## `procedural_fallback: true` — that is the point. The procedural
## generator is not being replaced, it is being made into the documented
## last resort, so an authored scene can take its place one asset at a
## time without a flag day.
##
## **The build contract is the load-bearing part.** `ZoneBuilder` chains
## rooms using `exit_offset` and checks placement using `bounds`; the
## mandatory path is that chain. An authored scene therefore has to answer
## the same questions a builder does, and it answers them from its
## registry metadata — which is why sockets, `size` and volumes are
## validated in both languages before anything is instantiated. A scene
## that could not answer them would produce a zone whose rooms overlap or
## whose exit is inside a wall, and it would do it at generation time, in
## a zone the player is standing in.

## Chamber type -> the content id that provides it. The indirection S15
## needs: a themed or authored shell registers a new id and points its
## `fallback` at the procedural one, and nothing here changes.
const SHELL_FOR_TYPE := {
	"corridor": "shell_corridor_proc",
	"arena": "shell_arena_proc",
	"platform_path": "shell_platform_path_proc",
	"tower": "shell_tower_proc",
	"treasure_room": "shell_treasure_room_proc",
}

## Y floor of a room's local bounds. The procedural builders all reserve a
## metre below the walkable plane for the floor slab; an authored shell
## sits in the same envelope so `ZoneBuilder`'s overlap test compares like
## with like.
const FLOOR_ALLOWANCE := 1.0

## Builds one chamber. Signature-compatible with `ChamberBuilders.build`,
## which is what it falls back to, so `ZoneBuilder` did not have to learn
## anything new.
static func build_chamber(chamber: Dictionary, theme: String,
		registry: ContentRegistry = null) -> Dictionary:
	var reg := registry if registry != null else ContentRegistry.shared()
	var type := str(chamber.get("type", ""))

	# What EPSILON chose, if it chose. `shell_id` has been on the chamber
	# schema since D1 and `validate_zone` has refused an id that was not
	# offered -- but nothing read it here, so a Zone that named a shell
	# got the procedural one anyway and no test could tell.
	#
	# The id is a key into the registry and never a path: an Epsilon that
	# could name a path could name any file, which is why the catalog it
	# is offered carries ids alone.
	var chosen_by_epsilon := str(chamber.get("shell_id", ""))
	var wanted: String = SHELL_FOR_TYPE.get(type, "")
	if not chosen_by_epsilon.is_empty():
		if reg.has(chosen_by_epsilon):
			wanted = chosen_by_epsilon
		else:
			# Not a reason to fail to build a room. A registry that no
			# longer carries a shell a saved Zone names is a downgrade,
			# not a corruption, and the procedural route still plays.
			push_warning("content: zone names shell '%s', which this "
					% chosen_by_epsilon + "registry does not carry; "
					+ "falling back")

	# An unregistered chamber type is not a reason to fail to build a
	# room. The generator has always had a default arm and still does;
	# the registry is a routing table, not a gate on generation.
	if wanted.is_empty() or not reg.has(wanted):
		return ChamberBuilders.build(chamber, theme)

	var chosen := reg.resolve(wanted)
	if chosen.is_empty():
		# Nothing in the chain could be instantiated. The validator makes
		# this nearly unreachable (a chain ending in a procedural entry
		# always terminates), but "nearly" is not a thing to bet a zone
		# on.
		push_warning("content: nothing in the fallback chain for '%s' "
				% wanted + "is available; using the procedural builder")
		return ChamberBuilders.build(chamber, theme)

	var entry := reg.get_entry(chosen)
	if bool(entry.get("procedural_fallback", false)):
		return ChamberBuilders.build(chamber, theme)
	# The art-lane gate. A PENDING asset is one somebody is still
	# deciding about; putting it in a zone decides for them, and the
	# decision was explicit that files existing is not approval.
	if not VisualOwnership.is_shippable(entry):
		push_warning("content: '%s' is pending art review; using the "
				% chosen + "placeholder until it passes")
		return ChamberBuilders.build(chamber, theme)
	return _from_authored_scene(entry, chamber, theme)

## The HOUSING for a light, per theme (art requirement 3a).
##
## Owner ruling: theme-specific authored fixture housings are allowed, and
## runtime / gameplay illumination stays ENGINE-OWNED. Six themes were
## sharing one `concrete_facility` slab because the builder had one
## hardcoded `BoxMesh` and no way to ask for anything else.
##
## Returns an instantiated housing, or `null` for "build the procedural
## slab". It never returns a light: the `OmniLight3D` is built by
## `ChamberBuilders._light` and an authored housing that carried its own
## would be art deciding how bright a room is.
static func light_housing(theme: String,
		registry: ContentRegistry = null) -> Node3D:
	var reg := registry if registry != null else ContentRegistry.shared()
	var wanted := "fixture_light_%s" % theme
	if not reg.has(wanted):
		return null
	var chosen := reg.resolve(wanted)
	if chosen.is_empty():
		return null
	var entry := reg.get_entry(chosen)
	if bool(entry.get("procedural_fallback", false)):
		return null
	# The art-lane gate, same as every other authored asset: a PENDING
	# housing is one somebody is still deciding about.
	if not VisualOwnership.is_shippable(entry):
		push_warning("content: '%s' is pending art review; using the "
				% chosen + "procedural light fixture until it passes")
		return null
	var scene: PackedScene = load(str(entry.get("scene", "")))
	if scene == null:
		return null
	var instance := scene.instantiate()
	if not (instance is Node3D):
		instance.free()
		return null
	# Illumination is engine-owned, and this is where that is ENFORCED
	# rather than asked for. A housing that ships its own light would
	# change how bright a room is by being installed.
	if _carries_a_light(instance):
		push_warning("content: '%s' carries its own light; illumination "
				% chosen + "is engine-owned, so the housing is refused")
		instance.free()
		return null
	return instance as Node3D

static func _carries_a_light(node: Node) -> bool:
	if node is Light3D:
		return true
	for child in node.get_children():
		if _carries_a_light(child):
			return true
	return false

## Instantiates an authored shell and derives the build contract from its
## validated metadata.
##
## Nothing here reads the scene's geometry to decide anything. The
## metadata is the contract: it is what both languages validated, what a
## test can check without a renderer, and what an artist declared on
## purpose. Measuring the mesh instead would mean a stray decorative
## overhang could silently move a room's exit.
static func _from_authored_scene(entry: Dictionary, chamber: Dictionary,
		theme: String) -> Dictionary:
	var scene: PackedScene = load(str(entry.get("scene", "")))
	if scene == null:
		# `resolve` already asked whether the resource exists; this is the
		# narrower case of a file that exists and does not load.
		push_warning("content: '%s' did not load; using the procedural "
				% str(entry.get("id", "")) + "builder")
		return ChamberBuilders.build(chamber, theme)
	var root: Node3D = scene.instantiate()

	# D1: the shell declared its geometry; this is where Godot checks it.
	# Refusing here rather than at load is deliberate -- the claim can
	# only be measured against an instantiated scene, and a shell whose
	# markers contradict its manifest must not become a zone the player
	# is standing in. Degrade, warn loudly, keep playing.
	var refusals := ShellValidator.refusals(entry, root)
	if not refusals.is_empty():
		push_error("content: refusing authored shell '%s':\n  %s"
				% [str(entry.get("id", "?")), "\n  ".join(refusals)])
		root.free()
		return ChamberBuilders.build(chamber, theme)

	var size := _vector(entry.get("size", []), Vector3(4.0, 3.6, 8.0))
	var result := {
		"root": root,
		"exit_offset": _exit_offset(entry, size),
		"bounds": AABB(
			Vector3(-size.x / 2.0, -FLOOR_ALLOWANCE, 0.0),
			Vector3(size.x, size.y + FLOOR_ALLOWANCE, size.z)),
		"enemy_spawns": _enemy_spawns(entry, chamber),
		"room_height": size.y,
		"reward_position": _objective(entry, size),
	}
	result["features"] = AffordanceFeatures.place_all(
			root, chamber, theme, size.x, size.z, size.y)
	# CAMPAIGN_SCALE.md 9. Built, not described: a Zone that names a
	# puzzle and produces an empty room is the exact thing the
	# vocabulary-to-builder pin exists to prevent, and building them here
	# is the other half of that.
	var activities: Array = []
	for activity: Variant in chamber.get("activities", []) as Array:
		if typeof(activity) == TYPE_DICTIONARY:
			activities.append(Activities.build(
					root, activity, theme, size.x, size.z))
	result["activities"] = activities
	return result

## Where the next room's entry goes, taken from the socket the artist
## declared. Falls back to the room's own depth: a shell with no exit
## socket cannot have reached here (the validator refuses one with no
## joining socket at all), but a shell whose only socket is named `entry`
## can, and it should chain rather than stack every room at the origin.
static func _exit_offset(entry: Dictionary, size: Vector3) -> Vector3:
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = socket
		if str(s.get("name", "")) in ["exit", "end_b"]:
			return _vector(s.get("position", []), Vector3(0, 0, size.z))
	return Vector3(0, 0, size.z)

## Enemy placement stays the generator's decision; the shell only says
## WHERE it is safe to put one. An authored shell with no `enemy_spawn`
## volume gets its enemies at the room's centre, which is what a
## builder-provided room would have done.
static func _enemy_spawns(entry: Dictionary, chamber: Dictionary) -> Array:
	var zones: Array = []
	for volume: Variant in entry.get("volumes", []):
		if typeof(volume) != TYPE_DICTIONARY:
			continue
		if str((volume as Dictionary).get("kind", "")) == "enemy_spawn":
			zones.append(volume)

	var spawns: Array = []
	var index := 0
	for group: Dictionary in chamber.get("enemies", []):
		for i in int(group.get("count", 0)):
			var at := Vector3.ZERO
			if not zones.is_empty():
				var zone: Dictionary = zones[index % zones.size()]
				var centre := _vector(zone.get("center", []), Vector3.ZERO)
				var extent := _vector(zone.get("size", []), Vector3.ZERO)
				# Spread deterministically inside the declared volume: the
				# same seed must lay out the same room on every machine.
				at = centre + Vector3(
					fposmod(float(index) * 1.7, maxf(extent.x, 0.01))
							- extent.x / 2.0,
					0.0,
					fposmod(float(index) * 2.3, maxf(extent.z, 0.01))
							- extent.z / 2.0)
			spawns.append({"archetype": group["archetype"], "position": at})
			index += 1
	return spawns

static func _objective(entry: Dictionary, size: Vector3) -> Vector3:
	for volume: Variant in entry.get("volumes", []):
		if typeof(volume) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = volume
		if str(v.get("kind", "")) == "objective":
			return _vector(v.get("center", []), Vector3(0, 0, size.z / 2.0))
	return Vector3(0, 0, size.z / 2.0)

static func _vector(raw: Variant, fallback: Vector3) -> Vector3:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 3:
		return fallback
	var a: Array = raw
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
