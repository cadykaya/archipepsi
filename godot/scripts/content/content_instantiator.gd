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
## WHICH BUILDER ANSWERED. Two values, and no third: a room is either
## the authored scene or the procedural builder's.
const BUILD_AUTHORED := "authored"
const BUILD_PROCEDURAL := "procedural"

## WHY THE PROCEDURAL BUILDER ANSWERED. A closed list, so a consumer can
## branch on it, and distinct values because the causes are different
## kinds of thing: a chamber type with no authored shell is the designed
## outcome, an unknown id is a downgraded registry, an incompatible one
## is a composition mistake, and a pending one is the art gate holding.
##
## "not offered" is deliberately ABSENT. The offer is the request's
## catalog, which lives on the Python side and never crosses to the
## runtime; `validate_zone` refuses an unoffered id before a Zone is
## ever stored. Inventing a runtime offer check here would mean a second
## opinion about a fact this process does not have.
## How far a declared dimension may sit from a shell's, in metres.
## Mirrors `shells.SPAN_TOLERANCE`: manifests carry two decimals and
## floats round, and this is that rounding allowance and nothing else.
const SPAN_TOLERANCE := 0.005

const REASON_NO_SHELL := "no_authored_shell_for_type"

## The meta key an adopted shell's root carries, naming which shell it
## is. Read by `SceneDigest`, which cannot ask the builder after the
## fact.
const SHELL_META := "authored_shell"
const REASON_UNKNOWN := "unknown_shell_id"
const REASON_MALFORMED := "malformed_shell_id"
const REASON_INCOMPATIBLE := "incompatible_shell"
const REASON_UNRESOLVABLE := "unresolvable_chain"
const REASON_PENDING := "pending_art_review"

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

## HOW FAR THIS SHELL'S DOORWAYS SIT OUTSIDE ITS OWN ENVELOPE.
##
## A joining socket declares where a corridor meets this shell. A socket
## outside the shell's `size` is a doorway in mid-air: the router joins a
## corridor to the socket, the room's wall is somewhere else, and between
## them is a gap with no floor. It is the playtest's first sentence --
## "oof the connecter isnt connected at all haha" -- measured.
##
## Nothing caught it because every other compatibility rule is about a
## SPAN and this is about a POINT. Found when the layout began crossing
## to the bridge and the validator said the route and the room disagreed
## about where the doorway was.
##
## Returns `socket name -> metres outside`, empty when every doorway is
## on the room. **Reports; changes nothing.** Authored geometry is Art's,
## and a manifest coordinate is authored geometry.
static func doorways_outside_envelope(entry: Dictionary) -> Dictionary:
	var out := {}
	var size: Variant = entry.get("size", [])
	if typeof(size) != TYPE_ARRAY or (size as Array).size() < 3:
		return out
	var envelope := AABB(
			Vector3(-float((size as Array)[0]) / 2.0, 0.0, 0.0),
			Vector3(float((size as Array)[0]), float((size as Array)[1]),
				float((size as Array)[2])))
	# A SHELL'S `size` IS ITS OUTER FACE, so the allowance is the
	# manifests' two-decimal rounding and nothing more.
	#
	# This grew by a whole `WALL_THICKNESS` at first, by analogy with
	# `ChamberBuilders.corner` stepping its exit past its own bounds --
	# but a producer's `bounds` span its walls' centre planes and a
	# manifest's `size` is the outer face already. Arty measured the
	# repaired shells' walls running to exactly the declared depth, and
	# measured `shell_yard_gantry` putting both doorways 0.40 m past an
	# envelope of -42.60..42.60. A 0.405 allowance passed it by five
	# millimetres. `layout.SOCKET_PROUD` is where a wall thickness
	# belongs, because that one compares against reported bounds.
	var slack := envelope.grow(SPAN_TOLERANCE)
	for raw: Variant in entry.get("sockets", []) as Array:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var socket: Dictionary = raw
		if str(socket.get("kind", "")) != "doorway":
			continue
		var at := _vector(socket.get("position", []), Vector3.ZERO)
		if slack.has_point(at):
			continue
		var worst := 0.0
		for axis in 3:
			worst = maxf(worst, slack.position[axis] - at[axis])
			worst = maxf(worst,
					at[axis] - (slack.position[axis] + slack.size[axis]))
		out[str(socket.get("name", "?"))] = worst
	return out

## Builds one chamber. Signature-compatible with `ChamberBuilders.build`,
## which is what it falls back to, so `ZoneBuilder` did not have to learn
## anything new.
##
## Two steps, and the split is the whole point. `_shell` decides WHICH
## ROOM to build -- authored scene, or procedural -- and has four early
## returns. Then the chamber's own content goes in, on whichever room came
## back.
##
## The activity loop used to live at the bottom of `_from_authored_scene`,
## which is one of the routes `_shell` can take and not the one anything
## takes: every shell in the registry is `procedural_fallback`, so
## `build_chamber` returned before that loop EVERY TIME. Activities were
## never built in a single room of a single Zone. Not inert -- absent.
## `godot/tests/activity_driver.gd` never caught it because every test in
## it called `Activities.build` itself, so the suite proved the runtime
## works and proved nothing about whether the game reaches it.
static func build_chamber(chamber: Dictionary, theme: String,
		registry: ContentRegistry = null) -> Dictionary:
	var result := _shell(chamber, theme, registry)
	# WHAT IS ALREADY IN THE ROOM, computed once and then added to as
	# things go in.
	#
	# ACTIVITIES FIRST, and that is a precedence rule rather than a
	# measurement: an activity carries a room's local reward and is the
	# structure the campaign describes, a crate is composition. Whichever
	# goes LAST is the one that can be squeezed, because
	# `Activities._free_spot` deliberately accepts a crowded spot rather
	# than dropping an element -- a missing puzzle element is worse than
	# a tight one. So the thing that yields should be the crate.
	#
	# Measured honestly: on the played Zone, swapping this order changes
	# nothing (8 placement notes either way). What DID cause the five
	# buried elements the audit found was two builders that could not see
	# their own geometry -- see `ChamberBuilders.solid_boxes` and the
	# ramp's `reserved` socket.
	var occupied := _room_occupancy(result, chamber)
	result["activities"] = _build_activities(result, chamber, theme, occupied)
	result["environment"] = _build_environment(result, theme, occupied)
	# ONLY WHEN THE PRODUCER RESERVED NONE.
	#
	# The procedural arena reserves a key's space beside the Check's
	# pedestal, chosen by `_clear_spot` so it does not land inside the
	# room's own crates -- a defect this branch already fixed once.
	# Overwriting that with an arrival-relative guess would put the key
	# back in the furniture. This fills the gap the AUTHORED producer
	# leaves and nothing else.
	if (result.get("key_spots", []) as Array).is_empty():
		result["key_spots"] = _key_spots(result, chamber)
	# EVERY PRODUCER THAT CAN CARRY DOORS REPORTS THEM.
	#
	# Only the ARENA builder emitted a door plan. A procedural corridor
	# emitted none and an authored shell emitted none, so two thirds of a
	# real Zone reported no doorways at all -- their apertures were never
	# measured, their sockets had no world position, and the layout the
	# bridge received put every one of them at the origin. It refused the
	# Zone for it, which is the correct failure and is how this was found.
	if (result.get("doors", []) as Array).is_empty():
		result["doors"] = _doors_from_bounds(result, chamber)
	return result

## A door plan for a producer that emitted none, from the room's own
## measured envelope rather than from the chamber dictionary.
##
## The envelope is what the geometry actually is: a corridor declares a
## `length` and no `depth`, and re-deriving a socket from a field the
## chamber may not carry is how the plan and the room come to disagree
## about where a doorway is.
##
## And the EXIT comes from the producer's own `exit_offset` rather than
## from the envelope's far face, for the same reason: the envelope says
## how far the room reaches and the producer says where it lets the
## player out, and for `platform_path` and `tower` those are different
## heights.
static func _doors_from_bounds(result: Dictionary,
		chamber: Dictionary) -> Array:
	if (chamber.get("doors", []) as Array).is_empty():
		return []
	var box: AABB = result.get("bounds", AABB())
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return []
	var way_out: Vector3 = result.get("exit_offset", Vector3.INF)
	return ChamberBuilders.door_plan(chamber, box.size.x, box.size.z,
			way_out)

## WHERE AN AUTHORED ROOM PUTS A KEY IT WAS ASKED TO HOLD.
##
## The procedural arena has reserved a spot for a declared key since the
## branching slice landed; the authored producer emitted none, so a key
## the bridge placed in an authored room WAS SIMPLY NOT BUILT. The
## generated Zone puts the branch's red key in `c007`, which is
## `shell_corner_left` -- so the lock on `c014`'s side door had no key
## anywhere in the Zone and the branch was unopenable. The same shape as
## the door plan the authored producer also lacked: proved on one
## producer, absent on the other.
##
## THE ARRIVAL IS THE ONE PLACE AN AUTHORED SHELL GUARANTEES.
## `RoomAudit._arrival_is_safe` measures that a standing capsule fits at
## `player_entry` and that it has floor under it, on every shell, every
## build. Anywhere else in an L-shaped corridor is a guess about geometry
## this file cannot see. A key on the floor beside the way in is also
## where a player looks first, which is not a coincidence -- both follow
## from it being the part of the room the contract knows.
static func _key_spots(result: Dictionary, chamber: Dictionary) -> Array:
	var out: Array = []
	var declared: Array = chamber.get("keys", [])
	if declared.is_empty():
		return out
	var entry: Dictionary = result.get("player_entry", {})
	var at: Vector3 = entry.get("position", Vector3.ZERO) \
			if typeof(entry) == TYPE_DICTIONARY and not entry.is_empty() \
			else Vector3.ZERO
	var index := 0
	for raw: Variant in declared:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = raw
		# Fanned out, so two keys in one room are two pickups rather
		# than one pickup wearing two colours.
		out.append({"key_id": str(spec.get("key_id", "")),
				"colour": str(spec.get("colour", "gold")),
				"position": at + Vector3(
						1.1 * float(index % 2) - 0.55, 0.0,
						1.4 + 1.1 * floor(float(index) / 2.0))})
		index += 1
	return out

## Everything the built shell already occupies, in the room's own space.
static func _room_occupancy(result: Dictionary,
		chamber: Dictionary = {}) -> Array[AABB]:
	var occupied: Array[AABB] = []
	var root := result.get("root") as Node3D
	if root == null:
		return occupied
	occupied.append_array(ChamberBuilders.solid_boxes(root))
	# WHERE THE CHECK WILL STAND. `ChamberBuilders.reward_clearance` has
	# always been honoured -- by the crate placer, in a local array that
	# never left the builder. So the builder knew where the pedestal goes
	# and the composer did not, and an activity element was free to be
	# placed inside it. That is the same "the builder knows a physical
	# fact the composer does not" shape this project has now paid for
	# five times; the fix is to PUBLISH the one derivation rather than
	# make a second one.
	#
	# The pedestal is not built yet -- `ZoneController` places it when
	# the campaign says which Check this is -- so nothing in the scene
	# could answer this by measurement.
	if not chamber.is_empty():
		var box := ChamberBuilders.reward_clearance(chamber,
				result.get("reward_position", Vector3.ZERO) as Vector3)
		if box.size != Vector3.ZERO:
			occupied.append(box)
	# Regions the BUILDER reserved, which occupancy-by-mesh cannot see: a
	# band's deck is room-scale, so it is skipped as architecture, and
	# the space under it then looked free to anything placed at floor
	# level.
	for socket: Variant in result.get("sockets", []) as Array:
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = socket
		if str(entry.get("kind", "")) != "reserved":
			continue
		var at: Vector3 = entry.get("position", Vector3.ZERO)
		var extent: Vector3 = entry.get("extent", Vector3.ONE)
		occupied.append(AABB(at - extent * 0.5, extent))
	return occupied

## Things the room offers that answer when you hit them.
##
## Placed ONLY into sockets the builder vouched for. That is the whole
## contract: a socket is a point on a real surface, clear of the walking
## lane, so an environmental object cannot land in a void, inside a prop
## or on top of another one. Every placement bug this project has paid
## for came from a composer guessing where it was safe to put something.
static func _build_environment(result: Dictionary, theme: String,
		occupied: Array[AABB]) -> Array:
	var root := result.get("root") as Node3D
	if root == null:
		return []
	var built: Array = []
	for socket: Variant in result.get("sockets", []) as Array:
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = socket
		var at: Vector3 = entry.get("position", Vector3.ZERO)
		var size := Vector3.ZERO
		var node: Node3D = null
		match str(entry.get("kind", "")):
			"cover":
				node = DestructibleCover.create(theme)
				size = DestructibleCover.SIZE
			"reactive":
				node = ReactiveBarrel.create(theme)
				size = ReactiveBarrel.SIZE
			_:
				continue
		at.y += size.y / 2.0
		# A SOCKET IS AN OFFER, NOT AN ORDER. The builder vouches that
		# the point is on real, clear geometry; it cannot know what the
		# activity solver did afterwards. So an object whose box now
		# lands on something is dropped rather than placed on top of it:
		# one fewer crate is a room that is slightly plainer, and a crate
		# sitting on a Check is a room the player cannot finish.
		var box := AABB(at - size * 0.5, size)
		if ChamberBuilders.box_hits(box, occupied):
			node.free()
			continue
		root.add_child(node)
		node.position = at
		occupied.append(box)
		built.append(node)
	return built

## The chamber's own content, added to whatever room `_shell` produced.
##
## CAMPAIGN_SCALE.md 9. Built, not described: a Zone that names a puzzle
## and produces an empty room is the exact thing the vocabulary-to-builder
## pin exists to prevent, and building them HERE -- on every route rather
## than on one of them -- is the other half of that.
static func _build_activities(result: Dictionary, chamber: Dictionary,
		theme: String, occupied: Array[AABB]) -> Array:
	var root := result.get("root") as Node3D
	if root == null:
		return []
	var bounds: AABB = result.get("bounds", AABB())
	var width := maxf(bounds.size.x, 1.0)
	var depth := maxf(bounds.size.z, 1.0)
	var room_id := str(chamber.get("id", ""))
	var activities: Array = []
	var index := 0
	for activity: Variant in chamber.get("activities", []) as Array:
		if typeof(activity) == TYPE_DICTIONARY:
			# The id is the room plus the position in the room's own list,
			# so it is stable across a rebuild after a reconnect and the
			# local reward a solved activity grants is the same note.
			var built := Activities.build(
					root, activity, theme, width, depth, room_id,
					"%s_%d" % [room_id, index], occupied,
					result.get("sockets", []) as Array)
			# Each activity claims its space before the next is placed,
			# which is what stops two of the same kind and size landing
			# on top of each other.
			# The footprints the SOLVER claimed, not ones re-derived
			# from the scene: it computed them in room space already,
			# and two derivations of one fact is how they disagree.
			for claimed: Variant in (built as Dictionary).get(
					"footprints", []) as Array:
				occupied.append(claimed as AABB)
			activities.append(built)
			index += 1
	# AND NOW THAT EVERY ELEMENT IN THE ROOM EXISTS, which way each shot
	# target looks. Positions are already settled and none of them move;
	# an unmounted target claims a square precisely so this turn cannot
	# invalidate the avoid-lists above.
	Activities.aim_shot_targets(root)
	return activities

## WHICH ROOM to build. Every return here is a room; none of them is a
## finished chamber, because the chamber's content is added by the caller.
static func _shell(chamber: Dictionary, theme: String,
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
	# NOT `str(chamber.get("shell_id", ""))`. `shell_id` is nullable in
	# the schema and arrives over the wire as JSON null, and `str(null)`
	# in GDScript is the six-character string "<null>" -- which is not
	# empty, so every chamber in every Zone took the "Epsilon chose a
	# shell" branch with garbage in hand and fell out of it with a
	# warning. A default only applies to a MISSING key, never to a
	# present null.
	var declared: Variant = chamber.get("shell_id")
	var requested := ""
	var malformed := false
	if declared is String:
		requested = str(declared)
	elif declared != null:
		# A number, an array, a dictionary. Not a downgrade and not a
		# choice: it is a malformed selection, and it says so rather
		# than being quietly read as "chose nothing" (3B).
		malformed = true

	var wanted: String = SHELL_FOR_TYPE.get(type, "")
	if malformed:
		return _procedural(chamber, theme, "", REASON_MALFORMED,
				"content: chamber '%s' names a %s where a shell id was "
				% [str(chamber.get("id", "")),
					type_string(typeof(declared))]
				+ "expected; using the procedural builder")
	if not requested.is_empty():
		if reg.has(requested):
			wanted = requested
		else:
			# Not a reason to fail to build a room. A registry that no
			# longer carries a shell a saved Zone names is a downgrade,
			# not a corruption, and the procedural route still plays.
			return _procedural(chamber, theme, requested, REASON_UNKNOWN,
					"content: zone names shell '%s', which this "
					% requested + "registry does not carry; falling back")

	# An unregistered chamber type is not a reason to fail to build a
	# room. The generator has always had a default arm and still does;
	# the registry is a routing table, not a gate on generation.
	if wanted.is_empty() or not reg.has(wanted):
		return _procedural(chamber, theme, requested, REASON_NO_SHELL, "")

	var chosen := reg.resolve(wanted)
	if chosen.is_empty():
		# Nothing in the chain could be instantiated. The validator makes
		# this nearly unreachable (a chain ending in a procedural entry
		# always terminates), but "nearly" is not a thing to bet a zone
		# on.
		return _procedural(chamber, theme, requested, REASON_UNRESOLVABLE,
				"content: nothing in the fallback chain for '%s' "
				% wanted + "is available; using the procedural builder")

	var entry := reg.get_entry(chosen)
	if bool(entry.get("procedural_fallback", false)):
		# Reached either because the chamber named nothing and
		# `SHELL_FOR_TYPE` routes here, or because a resolve chain ended
		# on the permanent procedural entry. Both are "no authored shell
		# built", which is what the reason says.
		return _procedural(chamber, theme, requested, REASON_NO_SHELL, "")
	# P2-C: DOES THIS SHELL FIT THIS ROOM?
	#
	# An authored shell has fixed geometry. The art lane's towers are 2,
	# 3 and 5 floors and the generator may ask for 4, so something has
	# to answer "there is no shell for that" -- and the answer is the
	# permanent procedural builder, not a 3-floor tower pretending. That
	# is the fallback working as designed, which is why it is a warning
	# and not an error.
	var misfit := _misfit(entry, chamber)
	if not misfit.is_empty():
		return _procedural(chamber, theme, requested, REASON_INCOMPATIBLE,
				"content: '%s' %s; using the procedural builder"
				% [chosen, misfit])
	# The art-lane gate. A PENDING asset is one somebody is still
	# deciding about; putting it in a zone decides for them, and the
	# decision was explicit that files existing is not approval.
	if not VisualOwnership.is_shippable(entry):
		return _procedural(chamber, theme, requested, REASON_PENDING,
				"content: '%s' is pending art review; using the "
				% chosen + "placeholder until it passes")
	var room := _from_authored_scene(entry, chamber, theme)
	room["shell_resolution"] = {
		"requested": requested,
		"resolved": chosen,
		"build": BUILD_AUTHORED,
		"reason": "",
	}
	return room

## THE PROCEDURAL OUTCOME, SAID OUT LOUD.
##
## Every fallback arm above used to `push_warning` and return an
## unmarked room, and a warning is not a result: `shell_id` survived in
## the chamber DATA whether or not the shell built, so a consumer
## reading the input called the room authored and was wrong. A fallback
## room does not count as an authored room merely because its input
## still contains an authored shell id.
##
## So the room carries what happened -- what was asked for, what
## answered, which builder ran, and why -- and `build` is the field that
## settles "was this authored", not the presence of a requested id.
static func _procedural(chamber: Dictionary, theme: String,
		requested: String, reason: String, warning: String) -> Dictionary:
	if not warning.is_empty():
		push_warning(warning)
	var room := ChamberBuilders.build(chamber, theme)
	room["shell_resolution"] = {
		"requested": requested,
		"resolved": "",
		"build": BUILD_PROCEDURAL,
		"reason": reason,
	}
	return room

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

## The VISUAL for a projectile silhouette (art requirement 13).
##
## Same shape as `light_housing` and for the same reason: the engine
## decides WHICH silhouette from the shot's own flight fields, art
## decides what that silhouette looks like, and neither can reach into
## the other. Always returns something -- a projectile with no visual is
## an invisible shot, so the placeholder is the floor rather than a
## warning.
##
## An authored mesh that carries collision is REFUSED. A projectile's
## hitbox is one 0.25 m sphere on the body for all three silhouettes; a
## mesh shipping its own would make the lobbed shot a different weapon
## from the straight one by being installed.
static func projectile_visual(silhouette: String, tint: Color,
		registry: ContentRegistry = null) -> Node3D:
	var authored := _authored_projectile(silhouette, registry)
	if authored != null:
		return authored
	return ProjectileSilhouette.build(silhouette, tint)

static func _authored_projectile(silhouette: String,
		registry: ContentRegistry) -> Node3D:
	var reg := registry if registry != null else ContentRegistry.shared()
	var wanted := ProjectileSilhouette.content_id(silhouette)
	if not reg.has(wanted):
		return null
	var chosen := reg.resolve(wanted)
	if chosen.is_empty():
		return null
	var entry := reg.get_entry(chosen)
	if bool(entry.get("procedural_fallback", false)):
		return null
	if not VisualOwnership.is_shippable(entry):
		push_warning("content: '%s' is pending art review; using the "
				% chosen + "placeholder projectile silhouette")
		return null
	var scene: PackedScene = load(str(entry.get("scene", "")))
	if scene == null:
		return null
	var instance := scene.instantiate()
	if not (instance is Node3D):
		instance.free()
		return null
	var carried := VisualInterface.collision_profile(instance as Node3D)
	if not carried.is_empty():
		push_warning("content: '%s' carries collision; a projectile's "
				% chosen + "hitbox is engine-owned, so the mesh is refused")
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
## Nothing here reads the scene's geometry to DECIDE anything. The
## metadata is the contract: it is what both languages validated, what a
## test can check without a renderer, and what an artist declared on
## purpose. Measuring the mesh instead would mean a stray decorative
## overhang could silently move a room's exit.
##
## That is not the same as trusting it. `ShellValidator` refuses a shell
## whose scene contradicts its manifest before any of this runs, and
## `RoomAudit` measures the emitted contract against the instantiated
## geometry with real probes. Declared decides; measured vetoes.
##
## P1: THIS PATH USED TO RETURN NO `sockets` KEY AT ALL. An authored room
## therefore got no cover, no barrels, no reserved regions and no
## walkable surfaces, and `Activities` flat-solved against its bounds --
## the exact defect `552469d` closed for `platform_path`, sitting in the
## one path no Zone takes yet. Producing it here means an authored room
## and a procedural room are the same kind of thing to everything
## downstream, which is what makes the room grammar a contract rather
## than a description of one producer.
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
	# CLOSURES BEFORE THE RESULT IS HANDED OUT, so the room a caller
	# receives is already the room the audit will measure. An authored
	# `SEALED` door is a slab over an aperture that exists; placing it
	# later would leave a window in which the shell is a hole.
	var doors := authored_door_plan(entry, chamber)
	_place_closures(root, doors, size)
	# AND STAMPED ON THE SCENE, not only in the answer.
	#
	# `authored_shell` below tells the CALLER which shell answered, which
	# is no use to anything holding the node afterwards -- `SceneDigest`
	# has to say which authored geometry a replay ran against and had
	# nothing in the tree to read. A procedural room has sockets, meshes
	# and hulls like any other, so nothing about the SHAPE distinguishes
	# one; a consumer that wants to know has to be told.
	root.set_meta(SHELL_META, str(entry.get("id", "")))
	var result := {
		"root": root,
		# WHICH SHELL ACTUALLY ANSWERED, stamped by the only code that
		# knows. Every `return ChamberBuilders.build(...)` above is a
		# refusal or a degrade, and the procedural room it returns is a
		# perfectly ordinary room -- it has sockets, meshes and hulls,
		# so nothing about its SHAPE distinguishes it from an authored
		# one. A consumer that wants to know whether the authored scene
		# was used has to be told; inferring it from the answer is how
		# `room_contract_driver` came to print a clean audit sheet for a
		# shell that never built.
		"authored_shell": str(entry.get("id", "")),
		# WHERE THIS ROOM ATTACHES, both ends, declared rather than
		# assumed (owner ruling, 2026-09-03). `exit_offset` has read the
		# declared exit socket since S15; the entry had no equivalent and
		# was taken to be the origin by everything downstream.
		"doors": doors,
		"entry_offset": _entry_offset(entry, chamber),
		# WHERE THE PLAYER'S BODY ARRIVES, which is a different question
		# from where the rooms join. The connector is a transform on the
		# envelope and may sit outside it; this is the interior region
		# the arrival has to be safe in.
		"player_entry": _player_entry(entry, chamber),
		"exit_offset": _exit_offset(entry, size, chamber),
		# DOES THIS ROOM HAVE A DEPARTURE AT ALL?
		#
		# `_exit_offset` answers "where", and for a shell with no way
		# onward it answers with the far face of the envelope -- a
		# fictional departure through a back wall. That is fine as a
		# number and wrong as a fact: a DESTINATION shell (the Terminus
		# has `entry`, `branch_east` and `branch_west` and no `exit`) is
		# a room the chain must stop at, not a room the chain walks
		# through into solid geometry. So the fact travels separately,
		# and `zone_builder` refuses a Zone that asks a destination to
		# be a through-room rather than inventing the door.
		"has_departure": _has_departure(entry, chamber),
		"bounds": AABB(
			Vector3(-size.x / 2.0, -FLOOR_ALLOWANCE, 0.0),
			Vector3(size.x, size.y + FLOOR_ALLOWANCE, size.z)),
		"enemy_spawns": _enemy_spawns(entry, chamber),
		"room_height": size.y,
		"reward_position": _objective(entry, size),
		"sockets": _authored_sockets(entry),
		"traversal": _authored_traversal(entry),
		# WHAT THE ROOM OFFERS a movement package (P3.5). The seam was
		# built in P3.0 and the authored path never emitted the key, so
		# a shell could declare a rail route and `MovementPackage` would
		# find nothing -- the offers were dropped between the manifest
		# and the room. `shell_hall_transit` is the first shell that
		# declares any, and is where that showed.
		"offers": _authored_offers(entry),
		# P2-B. Degrees, matching `Socket.yaw` and the manifest; the
		# chain converts once. A shell that does not declare one goes
		# straight through, which is what every room has always done.
		"exit_yaw": float(entry.get("exit_yaw", 0.0)),
	}
	result["features"] = AffordanceFeatures.place_all(
			root, chamber, theme, size.x, size.z, size.y)
	return result

## The authored shell's physical truths, in the one vocabulary every
## consumer already reads (`room_contract.gd`).
##
## A straight translation, deliberately: a `surface` becomes the `stand`
## socket `Activities` solves against, a `no_build` volume becomes the
## `reserved` region occupancy already understands, and the gameplay
## sockets keep their names. Nothing is invented and nothing is inferred
## -- an authored room offers exactly what its author declared, and the
## audit decides whether the author was right.
static func _authored_sockets(entry: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in entry.get("surfaces", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var surface: Dictionary = raw
		var extent := _pair(surface.get("extent", []))
		out.append({
			"kind": "stand",
			"name": str(surface.get("name", "")),
			"position": _vector(surface.get("center", []), Vector3.ZERO),
			# Surfaces are top faces, so the contract's extent is flat:
			# the y a consumer needs is the position's, not a thickness.
			"extent": Vector3(extent.x, 0.0, extent.y),
		})
	for raw: Variant in entry.get("sockets", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var socket: Dictionary = raw
		var kind := str(socket.get("kind", ""))
		if not RoomContract.POINT_KINDS.has(kind):
			continue
		out.append({
			"kind": kind,
			"name": str(socket.get("name", "")),
			"position": _vector(socket.get("position", []), Vector3.ZERO),
			"surface_id": str(socket.get("surface_id", "")),
		})
	for raw: Variant in entry.get("volumes", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var volume: Dictionary = raw
		if str(volume.get("kind", "")) != "no_build":
			continue
		out.append({
			"kind": "reserved",
			"name": str(volume.get("name", "")),
			"position": _vector(volume.get("center", []), Vector3.ZERO),
			"extent": _vector(volume.get("size", []), Vector3.ONE),
		})
	return out

## What the shell says the player does inside it, carried through in the
## contract's shape so the audit measures an authored jump and a
## `platform_path` jump with the same code and the same `max_safe_gap`.
static func _authored_traversal(entry: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in entry.get("traversal", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = raw
		out.append({
			"name": str(segment.get("name", "")),
			"kind": str(segment.get("kind", "walk")),
			"mandatory": bool(segment.get("mandatory", true)),
			"start": _vector(segment.get("start", []), Vector3.ZERO),
			"end": _vector(segment.get("end", []), Vector3.ZERO),
		})
	return out

## The shell's offers, in the room-output vocabulary.
##
## The manifest is JSON, so a route's points arrive as ARRAYS of numbers
## and every consumer downstream wants `Vector3`. Converted once, here,
## for the same reason `_authored_traversal` converts once: a consumer
## that has to remember to cast is a consumer that one day does not.
static func _authored_offers(entry: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in entry.get("offers", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = raw
		var made := {
			"kind": str(offer.get("kind", "")),
			"name": str(offer.get("name", "")),
		}
		var points := PackedVector3Array()
		for point: Variant in offer.get("points", []):
			points.append(_vector(point, Vector3.ZERO))
		if not points.is_empty():
			made["points"] = points
		if offer.has("position"):
			made["position"] = _vector(offer.get("position", []),
					Vector3.ZERO)
		if offer.has("radius"):
			made["radius"] = float(offer.get("radius", 0.0))
		if offer.has("target"):
			made["target"] = str(offer.get("target", ""))
		out.append(made)
	return out

## Where the next room's entry goes, taken from the socket the artist
## declared. Falls back to the room's own depth: a shell with no exit
## socket cannot have reached here (the validator refuses one with no
## joining socket at all), but a shell whose only socket is named `entry`
## can, and it should chain rather than stack every room at the origin.
## WHERE THE PREVIOUS ROOM'S EXIT MEETS THIS ONE (owner ruling).
## An authored shell's assigned doors, resolved and given an expected
## answer — the authored counterpart of `ChamberBuilders.door_plan`.
##
## The procedural producer DECLARES its four openings and carves the ones
## the assignment names. An authored shell is the other way round: every
## opening it has is already modelled, so a `USED` door needs nothing
## done to it and a `SEALED` one needs a CLOSURE PLACED OVER IT.
##
## That asymmetry is the reason this exists rather than reusing the
## procedural plan. "No aperture; wall" is achievable for a room that has
## not been built yet and is not achievable for a mesh that already has
## the hole in it, and pretending otherwise would make an authored
## `SEALED` door indistinguishable from a missing one.
## The names one opening answers to. `connector_grammar` calls a
## connector's two ends `end_a` and `end_b`; a `DoorAssignment` calls the
## same two openings `entry` and `exit`.
const ALIASES := {"entry": ["end_a"], "exit": ["end_b"]}

static func authored_door_plan(entry: Dictionary,
		chamber: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in chamber.get("doors", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw
		var declared := str(door.get("socket_id", ""))
		# THE ALIASES ARE THE SAME ONES PLACEMENT USES. A connector
		# grammar that calls its two ends `end_a` and `end_b` is naming
		# the same openings a door assignment calls `entry` and `exit`,
		# and `_entry_offset` has resolved through that pair since the
		# first shell composed. Resolving it in one place and not the
		# other is how a shell came to be joined correctly and then
		# report no doorway where it was joined.
		var socket := socket_by_id(entry, declared)
		if socket.is_empty():
			for alias: String in ALIASES.get(declared, []):
				socket = socket_by_id(entry, alias)
				if not socket.is_empty():
					break
		if socket.is_empty():
			push_warning("%s: door names socket '%s', which this shell "
					% [str(entry.get("id", "?")), declared]
					+ "does not declare")
			continue
		if str(socket.get("kind", "")) != "doorway":
			push_warning("%s: door names '%s', which is a %s and not a "
					% [str(entry.get("id", "?")),
						str(socket.get("name", "?")),
						str(socket.get("kind", "?"))] + "doorway")
			continue
		var usage := str(door.get("usage", "USED"))
		out.append({
			# THE NAME THE ASSIGNMENT USED, not the shell's own. The
			# bridge asks about `c001/entry` because that is the door it
			# assigned; answering about `c001/end_a` is answering a
			# question nobody asked, and reads as a door that carries no
			# measurement.
			"socket_id": declared,
			"usage": usage,
			"position": _vector(socket.get("position", []), Vector3.ZERO),
			"width": float(socket.get("width", 2.4)),
			"height": float(socket.get("height", 3.2)),
			"passable": usage != "SEALED",
		})
	return out

## The slab that makes an authored `SEALED` door solid.
##
## Placed rather than omitted, because the hole is already in the mesh.
## It is the shell's own aperture dimensions plus a margin, so a closure
## cannot be narrower than what it closes.
static func _place_closures(root: Node3D, plan: Array,
		size: Vector3) -> void:
	for raw: Variant in plan:
		var door: Dictionary = raw
		if bool(door["passable"]):
			continue
		var body := StaticBody3D.new()
		body.name = "Closure_%s" % str(door["socket_id"])
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var w: float = float(door["width"]) + 0.6
		var h: float = float(door["height"]) + 0.6
		box.size = Vector3(w, h, 0.5)
		shape.shape = box
		shape.position = Vector3(0, h / 2.0, 0)
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = box.size
		mesh.mesh = slab
		mesh.position = shape.position
		body.add_child(mesh)
		var at: Vector3 = door["position"]
		body.position = at
		# WHICH WALL, decided against the ENVELOPE and not against the
		# raw coordinates. A doorway at `(-6, 0, 8)` is in the left wall
		# of a 12 x 16 room, and comparing |x| with |z| says otherwise
		# because z is measured from the room's front rather than from
		# its middle. Getting it wrong lays the slab flat across the
		# opening's face and hangs it a metre outside the room.
		if absf(at.x) >= size.x / 2.0 - 0.5:
			body.rotation.y = PI / 2.0
		root.add_child(body)

## ONE OPENING, BY ITS ID. The resolver every joining question goes
## through.
##
## `socket_id` is an OPAQUE STABLE IDENTIFIER, not an ordinal. Production
## has always treated it that way: `entry` was resolved through a
## two-name alias set alongside `end_a`, and `exit` alongside `end_b`, so
## neither has ever meant "the first door" or "the last". A shell gaining
## a third opening therefore takes a third id and the existing two keep
## pointing at the openings they always pointed at. Nothing renames.
static func socket_by_id(entry: Dictionary, socket_id: String) -> Dictionary:
	if socket_id == "":
		return {}
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = socket
		if str(s.get("name", "")) == socket_id:
			return s
	return {}

## The socket this room joins a named edge through, or empty.
##
## WHICH OPENING JOINS WHICH EDGE IS THE COMPOSER'S DECISION, carried in
## `chamber.doors` as the contract's `DoorAssignment` list. Resolving it
## by NAME instead was the real defect behind "positional names cannot
## survive a third door": the names were fine, and the builder had no way
## to be told which of N openings the chain was walking through.
##
## `key` is `arrive_edge` or `depart_edge` -- the edge the chain enters
## and leaves by. **An empty answer is the legacy path**, which is what
## keeps every two-door shell composing exactly as it does today: a
## chamber carrying no assignment falls through to the alias sets below.
static func socket_for_edge(entry: Dictionary, chamber: Dictionary,
		key: String) -> Dictionary:
	var want := str(chamber.get(key, ""))
	if want == "":
		return {}
	for raw: Variant in chamber.get("doors", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw
		if str(door.get("edge_id", "")) != want:
			continue
		if str(door.get("usage", "USED")) == "SEALED":
			continue
		return socket_by_id(entry, str(door.get("socket_id", "")))
	return {}

##
## The mirror of `_exit_offset`, and named `end_a` for the same reason
## `exit` accepts `end_b`: a connector grammar that calls its two ends
## `a` and `b` should not have to learn a second vocabulary here.
##
## A room that declares no entry connector attaches at
## `RoomContract.LEGACY_ENTRY`, which is the origin and is what every
## procedural builder and every pre-ruling shell does.
static func _entry_offset(entry: Dictionary,
		chamber: Dictionary = {}) -> Vector3:
	var assigned := socket_for_edge(entry, chamber, "arrive_edge")
	if not assigned.is_empty():
		return _vector(assigned.get("position", []),
				RoomContract.LEGACY_ENTRY)
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = socket
		if str(s.get("name", "")) in ["entry", "end_a"]:
			return _vector(s.get("position", []),
					RoomContract.LEGACY_ENTRY)
	return RoomContract.LEGACY_ENTRY

## The interior region the player arrives into, or empty if none.
##
## `player_entry` has been a legal volume kind in `schemas/content.py`
## since S12 and was read by NOTHING -- a vocabulary word with no
## consumer, which is how three rooms came to declare an arrival region
## that no probe ever looked at.
## **RESOLVED PER ARRIVING SOCKET** (`09_ROOM_CONTRACT.md` §11.3).
## The restriction this lifts was real and was the engine's: a room had
## ONE arrival region however many openings it had, so a four-door
## junction entered from the side vouched for the space in front of its
## front door. A shell names a region after the socket it belongs to and
## that one is used; a shell with a single unnamed region is every shell
## that exists today and is unchanged.
##
## Which socket the chain arrives by is the composer's answer, carried
## on `arrive_edge` and resolved through `socket_for_edge` -- the same
## lookup `_entry_offset` uses, so the region and the attachment point
## cannot come from different doors.
static func _player_entry(entry: Dictionary,
		chamber: Dictionary = {}) -> Dictionary:
	var arriving := ""
	var assigned := socket_for_edge(entry, chamber, "arrive_edge")
	if not assigned.is_empty():
		arriving = str(assigned.get("name", ""))
	var fallback := {}
	for volume: Variant in entry.get("volumes", []):
		if typeof(volume) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = volume
		if str(v.get("kind", "")) != "player_entry":
			continue
		var region := {
			"position": _vector(v.get("center", []), Vector3.ZERO),
			"extent": _vector(v.get("size", []), Vector3.ONE),
		}
		var named := str(v.get("name", ""))
		if named != "" and arriving != "" and named == arriving:
			return region
		if fallback.is_empty():
			fallback = region
	return fallback

## Whether this shell offers a way onward at all: an ASSIGNED departure
## through the door the composer named, or a declared `exit`/`end_b`
## socket. Neither is not a shell to walk through.
##
## A shell that declares NO sockets is the pre-ruling case and keeps the
## old answer: the whole authored-shell contract post-dates it, every
## procedural builder is in it, and a room that never declared a
## doorway cannot be said to have withheld one.
static func _has_departure(entry: Dictionary,
		chamber: Dictionary = {}) -> bool:
	if not socket_for_edge(entry, chamber, "depart_edge").is_empty():
		return true
	var declared := false
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		declared = true
		if str((socket as Dictionary).get("name", "")) in ["exit", "end_b"]:
			return true
	return not declared

static func _exit_offset(entry: Dictionary, size: Vector3,
		chamber: Dictionary = {}) -> Vector3:
	var assigned := socket_for_edge(entry, chamber, "depart_edge")
	if not assigned.is_empty():
		return _vector(assigned.get("position", []), Vector3(0, 0, size.z))
	for socket: Variant in entry.get("sockets", []):
		if typeof(socket) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = socket
		if str(s.get("name", "")) in ["exit", "end_b"]:
			return _vector(s.get("position", []), Vector3(0, 0, size.z))
	return Vector3(0, 0, size.z)

## Why this shell cannot build this chamber, or "" when it can.
##
## One rule today, and deliberately only one: a shell that names the
## tower floor counts it was BUILT for may not be used for another. The
## general form -- every chamber parameter an authored shell fixes --
## arrives with the shells that need it; inventing the whole taxonomy
## now would be inventing rules with no content to hold them.
##
## NOT A STRETCH POINT. There is no arm here that scales, retimes or
## reinterprets a shell to make it fit; the only outcomes are "use it"
## and "use the builder".
static func _misfit(entry: Dictionary, chamber: Dictionary) -> String:
	return str(misfit_problem(entry, chamber).get("why", ""))

## WHICH COMPARISON FAILED, and why -- `{clause, why}`, empty `clause`
## when the shell fits.
##
## PUBLIC, and it is the Godot half of the shared rule.
## `godot/tests/fixtures/shell_rule_cases.json` is executed against this
## and against `shells.rule_problems` in Python, case for case. The test
## it replaces compared FIELD NAMES between the two files and passed
## while the two sides compared those fields differently, which is the
## one thing it existed to catch.
##
## The clause vocabulary is `type`, `footprint`, `height`, `feature`,
## `floors`, `elevation` -- the same six names Python returns.
static func misfit_problem(entry: Dictionary,
		chamber: Dictionary) -> Dictionary:
	# TYPE. A shell says what it is through `semantic_tags`; a chamber
	# says what it needs through `type`. An entry declaring NO tags
	# constrains nothing -- the same early return every other clause
	# takes on an empty declaration, and the same one
	# `shells.rule_problems` takes on an empty `types`.
	var wanted := str(chamber.get("type", ""))
	var tags: Variant = entry.get("semantic_tags", [])
	if typeof(tags) == TYPE_ARRAY and not (tags as Array).is_empty() \
			and not wanted.is_empty() and not (tags as Array).has(wanted):
		return {"clause": "type",
			"why": "is tagged %s and this chamber is a '%s'" % [
				", ".join((tags as Array).map(
					func(t: Variant) -> String: return str(t))), wanted]}

	# IS THE SHELL THE ROOM? An equality since the owner ruling of
	# 2026-09-11: the generator DERIVES a chamber's dimensions from the
	# shell it picked, so a declared size that disagrees with the shell
	# is a Zone describing a room it is not going to build. The shell's
	# `size` is its envelope, walls included; width and depth are the
	# interior. Corridors say `length` where other rooms say `depth`.
	var size: Variant = entry.get("size", [])
	var has_size := typeof(size) == TYPE_ARRAY \
			and (size as Array).size() >= 3
	var along: Variant = chamber.get("depth", chamber.get("length"))
	if has_size and chamber.has("width") and along != null:
		var outer := 2.0 * ChamberBuilders.WALL_THICKNESS
		for pair: Array in [["width", 0, float(chamber["width"]) + outer],
				["depth", 2, float(along) + outer]]:
			var got := float((size as Array)[int(pair[1])])
			if absf(got - float(pair[2])) > SPAN_TOLERANCE:
				return {"clause": "footprint",
					"why": "has a %s of %.2f and this chamber declares %.2f including walls"
						% [str(pair[0]), got, float(pair[2])]}
	if has_size and chamber.has("wall_height"):
		var tall := float((size as Array)[1])
		if absf(tall - float(chamber["wall_height"])) > SPAN_TOLERANCE:
			return {"clause": "height",
				"why": "is %.2f tall and this chamber declares %.2f"
					% [tall, float(chamber["wall_height"])]}

	# CAN IT HOLD WHAT THE ROOM CARRIES? A feature needs somewhere to sit
	# that is neither in the masonry nor across the walking lane.
	if has_size:
		var interior := float((size as Array)[0]) \
				- 2.0 * ChamberBuilders.WALL_THICKNESS
		for raw: Variant in chamber.get("features", []) as Array:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var tag := str((raw as Dictionary).get("tag", ""))
			var needed := float(Constants.FEATURE_MIN_WIDTH.get(
					tag, Constants.MIN_FEATURE_CHAMBER_WIDTH))
			if interior + SPAN_TOLERANCE < needed:
				return {"clause": "feature",
					"why": "has a %.2fm interior and cannot hold a '%s', which needs %.1fm"
						% [interior, tag, needed]}

	# FIXED AUTHORED CONSTRAINTS. An empty `fits_floors`, or a chamber
	# with no `floors`, declares no constraint.
	var fits: Variant = entry.get("fits_floors", [])
	if typeof(fits) == TYPE_ARRAY and not (fits as Array).is_empty() \
			and chamber.has("floors"):
		var floors := int(chamber["floors"])
		var ok := false
		for allowed: Variant in fits as Array:
			if int(allowed) == floors:
				ok = true
		if not ok:
			return {"clause": "floors",
				"why": "is built for %s floors and this chamber has %d" % [
					", ".join((fits as Array).map(
						func(f: Variant) -> String: return str(int(f)))),
					floors]}

	var band := _band_misfit(entry, chamber)
	if not band.is_empty():
		return {"clause": "elevation", "why": band}
	return {"clause": "", "why": ""}

## Does this shell provide the elevation band the chamber declares?
static func _band_misfit(entry: Dictionary, chamber: Dictionary) -> String:
	var band: Variant = chamber.get("elevation")
	if typeof(band) != TYPE_DICTIONARY:
		return ""
	var kind := str((band as Dictionary).get("kind", ""))
	if kind.is_empty():
		return ""
	var provides: Variant = entry.get("provides_elevation", [])
	if typeof(provides) == TYPE_ARRAY and (provides as Array).has(kind):
		return ""
	var named := "no" if typeof(provides) != TYPE_ARRAY \
			or (provides as Array).is_empty() \
			else ", ".join((provides as Array).map(
				func(v: Variant) -> String: return str(v)))
	return "provides %s elevation band(s) and this chamber declares a '%s'" \
			% [named, kind]

## How close to a doorway's centre counts as standing IN it: half the
## 2.4 m opening plus a body's radius. A capsule nearer than this is in
## the gap or across its edge.
const IN_THE_DOORWAY := ChamberBuilders.DOOR_WIDTH / 2.0 \
		+ Constants.PLAYER_RADIUS

## Enemy placement stays the generator's decision; the shell only says
## WHERE it is safe to put one.
##
## THE FALLBACK WAS THE DOORWAY, AND IT SAID IT WAS THE CENTRE. This
## used to read "an authored shell with no `enemy_spawn` volume gets its
## enemies at the room's centre, which is what a builder-provided room
## would have done" -- and then wrote `Vector3.ZERO`. A shell's local
## origin is not its centre: it is the z = 0 wall, which is the wall the
## ENTRY DOORWAY is cut into.
##
## So the hall, given ten enemies and no `enemy_spawn` volume, stood
## every one of them in its own 2.4 m entry. `aperture_polarity` read
## the doorway as solid, the bridge refused the layout on "door
## 'c002/entry' is USED and the engine measured it as solid", and
## `zone_001` was recomposed three times and never opened.
##
## The centre this always meant is `_objective`'s, and the better answer
## is the largest surface the shell itself declares standable. Either
## way nobody is left in an opening: a spawn inside one is pushed toward
## the middle of the room until it is out, because a player body-blocked
## in the only door is a defect whether or not a probe trips over it.
static func _enemy_spawns(entry: Dictionary, chamber: Dictionary) -> Array:
	var zones: Array = []
	for volume: Variant in entry.get("volumes", []):
		if typeof(volume) != TYPE_DICTIONARY:
			continue
		if str((volume as Dictionary).get("kind", "")) == "enemy_spawn":
			zones.append(volume)
	var middle := _room_middle(entry)
	if zones.is_empty():
		zones.append(_fallback_spawn_zone(entry, middle))
	var doorways: Array[Vector3] = []
	for raw: Variant in entry.get("sockets", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var socket: Dictionary = raw
		if str((socket as Dictionary).get("kind", "")) != "doorway":
			continue
		doorways.append(_vector((socket as Dictionary).get("position", []),
				Vector3.ZERO))

	var spawns: Array = []
	var index := 0
	for group: Dictionary in chamber.get("enemies", []):
		for i in int(group.get("count", 0)):
			var zone: Dictionary = zones[index % zones.size()]
			var centre := _vector(zone.get("center", []), middle)
			var extent := _vector(zone.get("size", []), Vector3.ZERO)
			# Spread deterministically inside the declared volume: the
			# same seed must lay out the same room on every machine.
			var at := centre + Vector3(
				fposmod(float(index) * 1.7, maxf(extent.x, 0.01))
						- extent.x / 2.0,
				0.0,
				fposmod(float(index) * 2.3, maxf(extent.z, 0.01))
						- extent.z / 2.0)
			spawns.append({"archetype": group["archetype"],
					"position": out_of_any_doorway(at, doorways, middle)})
			index += 1
	return spawns

## The middle of the room, by the one convention this file already uses
## for "somewhere in the room and not at its wall".
static func _room_middle(entry: Dictionary) -> Vector3:
	var size := _vector(entry.get("size", []), Vector3(10.0, 4.0, 10.0))
	return Vector3(0.0, 0.0, size.z / 2.0)

## Where enemies go in a shell that declares no `enemy_spawn` volume:
## spread over the largest surface it says a body can stand on, inset by
## a body's radius so the spread cannot hang one over the lip. A shell
## with no surfaces at all gets the middle of its envelope.
static func _fallback_spawn_zone(entry: Dictionary,
		middle: Vector3) -> Dictionary:
	var size := _vector(entry.get("size", []), Vector3(10.0, 4.0, 10.0))
	var best := {"center": [middle.x, middle.y, middle.z],
			"size": [size.x / 2.0, 0.0, size.z / 2.0]}
	var widest := 0.0
	for raw: Variant in entry.get("surfaces", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var surface: Dictionary = raw
		var extent := _pair(surface.get("extent", []))
		var area := extent.x * extent.y
		if area <= widest:
			continue
		widest = area
		var centre := _vector(surface.get("center", []), middle)
		best = {"center": [centre.x, centre.y, centre.z],
				"size": [maxf(extent.x - 2.0 * Constants.PLAYER_RADIUS,
						0.5), 0.0,
					maxf(extent.y - 2.0 * Constants.PLAYER_RADIUS, 0.5)]}
	return best

## NOBODY SPAWNS IN A DOORWAY.
##
## The opening is the only way through the room, so a body standing in
## it is a player stuck in a door. Pushed from the doorway toward the
## middle of the room, which is a direction that always exists because a
## doorway is cut into a wall. Bounded, because two doorways close
## together could otherwise pass a body back and forth.
static func out_of_any_doorway(at: Vector3, doorways: Array,
		middle: Vector3) -> Vector3:
	var here := at
	for _tries in 8:
		var worst := -1.0
		var mouth := Vector3.ZERO
		for raw: Variant in doorways:
			var door: Vector3 = raw
			var apart := Vector2(here.x - door.x, here.z - door.z).length()
			if apart < IN_THE_DOORWAY and (worst < 0.0 or apart < worst):
				worst = apart
				mouth = door
		if worst < 0.0:
			return here
		var away := Vector3(middle.x - mouth.x, 0.0, middle.z - mouth.z)
		if away.length() < 0.01:
			away = Vector3(0.0, 0.0, 1.0)
		here += away.normalized() * (IN_THE_DOORWAY - worst + 0.1)
	return here

static func _objective(entry: Dictionary, size: Vector3) -> Vector3:
	for volume: Variant in entry.get("volumes", []):
		if typeof(volume) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = volume
		if str(v.get("kind", "")) == "objective":
			return _vector(v.get("center", []), Vector3(0, 0, size.z / 2.0))
	return Vector3(0, 0, size.z / 2.0)

## A surface's extent is its FLOOR footprint, so the manifest declares
## two numbers and not three: a top face has no thickness, and a third
## number here would be a thickness somebody would eventually believe.
static func _pair(raw: Variant) -> Vector2:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 2:
		return Vector2.ZERO
	var a: Array = raw
	return Vector2(float(a[0]), float(a[1]))

static func _vector(raw: Variant, fallback: Vector3) -> Vector3:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 3:
		return fallback
	var a: Array = raw
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
