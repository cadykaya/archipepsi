class_name ZoneBuilder
extends RefCounted
## Chains chamber builds from the origin, inserts connectors and 90° corner
## pieces, and appends the exit portal after the final chamber. Epsilon
## never chooses world coordinates; this file owns them.
##
## Layouts may bend. Safety is layered: turns alternate direction (no
## U-shapes by construction), every placement is checked against all prior
## world-space bounds, and a chamber that would clip an earlier arm is
## pushed forward with extra connectors until clear. The mandatory path is
## still one walkable chain — only its shape varies.

const CONNECTOR_LENGTH := 5.0
const CONNECTOR_WIDTH := 4.0
const TURN_CHANCE := 0.45

static func _rot(yaw: float, v: Vector3) -> Vector3:
	return Basis(Vector3.UP, yaw) * v

## WHERE A ROOM'S ORIGIN GOES so that its entry connector lands on
## `join` (owner ruling, 2026-09-03).
##
## Public, and public deliberately: the alternative is a test that
## reimplements this subtraction and then agrees with itself. The two
## halves of the seam -- where a room is put, and where the next one is
## joined -- are the two functions below and nothing else computes them.
static func origin_for(join: Vector3, yaw: float,
		entry_offset: Vector3) -> Vector3:
	return join - _rot(yaw, entry_offset)

## Where the NEXT room's entry connector must land, given this one's
## placed origin. Vertical offset and yaw come along for free: both
## connectors are room-local vectors turned by the room's own yaw, so a
## room that leaves 28 m up leaves the next one 28 m up.
static func exit_cursor(origin: Vector3, yaw: float,
		exit_offset: Vector3) -> Vector3:
	return origin + _rot(yaw, exit_offset)

static func _world_aabb(local: AABB, position: Vector3, yaw: float) -> AABB:
	var out: AABB
	for i in 8:
		var corner := position + _rot(yaw, local.get_endpoint(i))
		out = AABB(corner, Vector3.ZERO) if i == 0 else out.expand(corner)
	return out

## The hard ceiling on how far a room may be pushed forward, so a
## pathological Zone fails loudly instead of hanging. The working budget
## is `_clearance_budget`, derived from the geometry actually placed.
const MAX_CLEARANCE_CONNECTORS := 96

## How big a room has to be to earn a warp station.
##
## §30.12.4 says "large rooms" and leaves the number to the engine, which
## is this lane's to pick: below this a station is furniture in the way,
## and a Zone where every room has one is a Zone where warping replaces
## walking.
const STATION_ROOM_AREA := 260.0

## HOW MANY CONNECTORS IT COULD EVER TAKE to push clear, derived rather
## than guessed.
##
## This was a literal 6 -- about 48 m, enough for the builder's own rooms
## and not for a 90 m authored one -- and when it ran out the room was
## placed ANYWAY. Deriving it was unsafe while a connector was never
## itself overlap-checked, because a long push just marched a corridor
## THROUGH whatever was in the way. `_search` now stops at the first
## connector that would overlap, so distance costs nothing but
## arithmetic and the bound can be what the geometry needs.
static func _clearance_budget(placed: Array) -> int:
	if placed.is_empty():
		return 1
	var span: AABB = placed[0]
	for box: AABB in placed:
		span = span.merge(box)
	var reach := span.size.x + span.size.z
	return mini(int(ceil(reach / maxf(CONNECTOR_LENGTH, 1.0))) + 2,
			MAX_CLEARANCE_CONNECTORS)

## Everything a route has laid except the piece a new one joins onto.
static func _all_but_last(laid: Array) -> Array:
	return [] if laid.size() < 2 else laid.slice(0, laid.size() - 1)

static func _overlaps(placed: Array, candidate: AABB) -> bool:
	for existing: AABB in placed:
		if existing.intersection(candidate).get_volume() > 0.5:
			return true
	return false

## Places one connector at (cursor, yaw) and returns the advanced cursor.
## A helper rather than a lambda: GDScript lambdas capture Vector3 locals
## by value, which silently pinned every connector to the origin.
## The local geometry of a connector and of a corner, measured from the
## real builders and then thrown away.
##
## PLAN BEFORE BUILDING. Placement used to decide by emitting: it added a
## connector, asked whether the room fitted now, and added another --
## so a connector was never itself overlap-checked and a long push
## marched a corridor straight THROUGH the rooms in the way. Reading the
## shapes once lets the whole route be judged as arithmetic, and only the
## route that clears is built.
static func _shape_of(built: Dictionary) -> Dictionary:
	var out := {"bounds": built["bounds"],
			"exit_offset": built["exit_offset"]}
	(built["root"] as Node3D).free()
	return out

static func _connector_shape(theme: String) -> Dictionary:
	return _shape_of(ChamberBuilders.corridor(
			{"id": "probe", "length": CONNECTOR_LENGTH,
			"width": CONNECTOR_WIDTH}, theme))

## How many corners a route may take to reach a spot for the next room.
##
## One was not enough. A 90 m authored arena in a 23-room chain boxes the
## route in, and with a single turn available `c017` of Zone 1 had
## nowhere to go after 37 pieces -- reported as a routing failure, which
## was honest and still left the Zone unbuildable. Two turns is "go
## around it", which is what a level does.
const MAX_ROUTE_TURNS := 2

## How far a route may push between turns while it is still exploring.
## The FINAL leg gets the full `_clearance_budget`; the legs before it
## are bounded tighter, because the search is a product of them.
##
## MEASURED AGAINST THE ROOMS. At 16 this is 80 m of sidestep, and
## `shell_span_basin` is 90 m deep -- so a route could never get far
## enough around one, and Zone 1's `c017` had nowhere to go after 36
## pieces. A sidestep has to be able to clear the largest room there is.
const EXPLORE_CONNECTORS := 40

## THE CANDIDATE SPACE THIS SOLVER ACTUALLY SEARCHES.
##
## `LAYOUT_INFEASIBLE` may only ever mean "this policy's candidate space
## is empty" -- never "no geometric layout exists". The search bends at
## most `MAX_ROUTE_TURNS` times and pushes at most this many connectors;
## a layout needing three turns is outside the space and its absence
## here says nothing about it. A result carries the policy so a catalog
## review can see that widening it is an available answer.
static func routing_policy(placed: Array,
		override := {}) -> Dictionary:
	var out := {"max_route_turns": MAX_ROUTE_TURNS,
			"explore_connectors": EXPLORE_CONNECTORS,
			"max_clearance_connectors": MAX_CLEARANCE_CONNECTORS,
			# THIS ROUTER BUILDS CHAINS. §30.11.2e constraint 3 requires
			# every cycle in the physically realized subgraph to compose
			# to the identity, and a chain walk cannot satisfy that: it
			# places each room from the previous one and never returns
			# to a transform it has already fixed.
			#
			# Declared rather than assumed, because the alternative is
			# the silent one -- building the chain, ignoring the closing
			# edge, and shipping a Zone whose graph says there is a loop
			# and whose geometry has none. A reviewer reading an
			# infeasible result can see exactly which bound to widen.
			"closes_cycles": false,
			"clearance_budget": _clearance_budget(placed)}
	for field: String in override:
		out[field] = override[field]
	return out

## The closing edges this Zone asks for and this router cannot build.
##
## §30.11.2e scopes its join and closure constraints to the PHYSICALLY
## REALIZED subgraph, and that scoping is the whole point: a return plug
## makes a graph cyclic and creates no spatial cycle, so a solver must
## never be handed a loop to close through a teleport. Only `JOINED`
## edges are counted here.
##
## Returns the edges that would close a cycle, or empty. A Zone with no
## `edges` at all is the chain every Zone has always been and answers
## empty immediately.
static func unclosable_cycles(zone: Dictionary) -> Array:
	var seen := {}
	var closing: Array = []
	for raw: Variant in zone.get("edges", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = raw
		if str(edge.get("realization", "JOINED")) != "JOINED":
			continue
		var a := str(edge.get("room_a", ""))
		var b := str(edge.get("room_b", ""))
		if a == "" or b == "":
			continue
		# Union-find over the JOINED subgraph: an edge whose endpoints
		# already share a component closes a cycle.
		var ra := _root(seen, a)
		var rb := _root(seen, b)
		if ra == rb:
			closing.append(edge)
		else:
			seen[ra] = rb
	return closing

## MEASURING A COMMITTED LAYOUT, WITHOUT RE-SOLVING IT.
##
## §30.11.2e names four constraints and insists they are measured on the
## committed transforms rather than recomputed by re-running the search:
## "the bridge does not check the engine's arithmetic by redoing it".
## Two of the four are answerable from the manifest alone and are
## answered here:
##
##   2. **Body.** No two room envelopes intersect, less the collar
##      tolerance at a shared aperture.
##   4. **Arrival.** Every committed arrival point lies inside the room
##      whose arrival it is.
##
## Constraint 1 (Join) needs the socket assignment, which is the bridge
## column. Constraint 4's PHYSICAL half -- that the standing capsule
## actually fits there -- needs a live scene, and `RoomAudit` sweeps it;
## this is the geometric half, which catches an arrival committed outside
## its own room before any physics runs.
##
## THIS IS NOT THE PLACEMENT CHECK. `_overlaps` refuses an overlapping
## candidate DURING the search, over a `placed` array that deliberately
## omits pieces (`_all_but_last`) and tolerates half a cubic metre. This
## measures what was actually committed, afterwards, over every pair. A
## builder whose incremental check has a blind spot passes the first and
## fails this one, which is the entire reason the design asks for two
## different computations.
##
## Returns a list of human-readable findings; empty means the committed
## layout satisfies what can be measured from it.
static func layout_findings(result: Dictionary) -> Array:
	var out: Array = []
	if str(result.get("status", "")) != "LAYOUT_OK":
		return out
	var rooms: Dictionary = result.get("rooms", {})
	var ids: Array = rooms.keys()
	ids.sort()
	for a in ids.size():
		var room_a: Dictionary = rooms[ids[a]]
		if not room_a.has("bounds"):
			out.append("room '%s' committed no envelope, so Body cannot "
					% str(ids[a]) + "be measured without re-solving")
			continue
		var box_a: AABB = room_a["bounds"]
		# ARRIVAL, geometrically: the point a body appears at has to be
		# in the room that claims it. An arrival outside its own envelope
		# is a spawn in the void and no physics probe is needed to say so.
		if room_a.has("arrival"):
			var at: Vector3 = room_a["arrival"]
			if not box_a.grow(0.01).has_point(at):
				out.append("room '%s' commits an arrival at %v that is "
						% [str(ids[a]), at] + "outside its own envelope "
						+ "%v" % box_a)
		for b in range(a + 1, ids.size()):
			var room_b: Dictionary = rooms[ids[b]]
			if not room_b.has("bounds"):
				continue
			var shared := box_a.intersection(room_b["bounds"] as AABB)
			if not shared.has_volume():
				continue
			if not _is_a_collar(shared.size):
				out.append("rooms '%s' and '%s' interpenetrate over "
						% [str(ids[a]), str(ids[b])]
						+ "%v (%.2f m3), which is larger than the one "
						% [shared.size, shared.get_volume()]
						+ "aperture a shared collar may be")
	return out

## Is this overlap the SHAPE of a collar, rather than merely its size?
##
## A volume bound cannot tell the two apart, and the difference matters:
## a 0.05 m sliver spread across two rooms' whole shared face is 3.6 m3,
## more than a doorway of wall, and it is interpenetration rather than a
## collar. A real collar is ONE APERTURE -- thin through the wall, and no
## wider or taller than a door.
##
## So the rule is a shape: the thinnest extent is wall-thickness or less,
## and the other two are a doorway or less. Not tuned numbers -- they are
## the doorway constants, and they move only if a doorway does.
static func _is_a_collar(size: Vector3) -> bool:
	var extents := [size.x, size.y, size.z]
	extents.sort()
	return float(extents[0]) <= ChamberBuilders.WALL_THICKNESS + COLLAR_SLACK \
			and float(extents[1]) <= ChamberBuilders.DOOR_WIDTH + COLLAR_SLACK \
			and float(extents[2]) <= ChamberBuilders.DOOR_HEIGHT + COLLAR_SLACK

## Float slop, not a design allowance. `EPSILON_JOIN` is 0.001 m; this is
## two orders looser so a collar built to spec is never reported.
const COLLAR_SLACK := 0.1

## EVERYTHING A PLACED ROOM GETS, wherever it was placed from.
##
## Extracted because a BRANCH is a room and was not being treated as one:
## keys, locked doors and the warp station were written inline in the
## chain loop and ran only over `zone.chambers`, so a branch could hold a
## Check and an activity and could not hold its own key, its own locked
## door or its own station. A second copy for branches would have been
## two places to forget the same thing.
##
## Appends into `keys`, `locks` and `stations` and writes into `anchors`
## and `room_transforms`; returns the room's footprint, which is the only
## thing the caller still has a use for.
static func _furnish_room(root: Node3D, theme: String,
		chamber: Dictionary, result: Dictionary, origin: Vector3,
		yaw: float, anchors: Dictionary, room_transforms: Dictionary,
		keys: Array, locks: Array, stations: Array) -> float:
	var rid := str(chamber.get("id", "?"))
	# Where a body arriving in this room stands: the room's own
	# declared arrival, carried into world space.
	var arrive: Vector3 = result.get("player_entry", {}).get(
			"position", Vector3(0, 0, 3.0)) \
			if typeof(result.get("player_entry")) == TYPE_DICTIONARY \
				and not (result["player_entry"] as Dictionary).is_empty() \
			else Vector3(0, 0, 3.0)
	anchors["room:%s:arrival" % rid] = origin + _rot(yaw, arrive)
	# THE ENVELOPE TRAVELS WITH THE TRANSFORM.
	#
	# §30.11.2e constraint 2 is measured on the COMMITTED layout and
	# the measurer must not re-solve. A transform without its
	# envelope cannot be checked for Body without re-running the
	# builders, which is exactly the second computation the design
	# forbids. So the layout carries both the envelope and the
	# arrival point, and Body and Arrival are answerable from the
	# manifest alone.
	room_transforms[rid] = {"position": origin, "yaw": yaw,
			"bounds": _world_aabb(result["bounds"], origin, yaw),
			"arrival": origin + _rot(yaw, arrive)}
	# The room reserved a place for each key it declares, so this
	# only carries it into world space.
	for raw_spot: Variant in result.get("key_spots", []):
		var spot: Dictionary = raw_spot
		var key := ZoneKey.create(str(spot["key_id"]),
				str(spot["colour"]))
		key.position = origin + _rot(yaw, spot["position"] as Vector3)
		root.add_child(key)
		keys.append(key)
	# A LOCKED door's slab, standing in an aperture that IS carved.
	# The audit still sweeps the capsule through the opening and
	# still requires it to be a hole; this is what stands in it.
	for raw_door: Variant in chamber.get("doors", []):
		if typeof(raw_door) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw_door
		if str(door.get("usage", "")) != "LOCKED":
			continue
		var socket := ChamberBuilders.socket_placed(
				str(door.get("socket_id", "")),
				float(chamber.get("width", 16.0)),
				float(chamber.get("depth", 16.0)))
		if socket.is_empty():
			continue
		var slab := LockedDoor.create(rid,
				str(door.get("socket_id", "")),
				str(door.get("key_id", "")),
				str(door.get("colour", "gold")),
				ChamberBuilders.DOOR_WIDTH,
				ChamberBuilders.DOOR_HEIGHT,
				str(door.get("requires", "")))
		slab.position = origin + _rot(yaw, socket["position"] as Vector3)
		slab.rotation.y = yaw
		root.add_child(slab)
		locks.append(slab)
	# A STATION IN EVERY LARGE ROOM (§30.12.4). The entrance and the
	# exit get one below; this is the third of the three places the
	# design names.
	var footprint: float = float(chamber.get("width", 0.0)) \
			* float(chamber.get("depth", 0.0))
	if footprint >= STATION_ROOM_AREA:
		# A STATION IN A ROOM WITH A PUZZLE STARTS BROKEN.
		#
		# The owner ruling is that a station may start off and be
		# repaired by "a small puzzle (since we already have puzzles
		# they just do nothing)". This lane spends no new schema
		# field on the choice: Epsilon already decides whether a room
		# carries an activity, so Epsilon already decides this, and
		# the rule is one the builder can state.
		#
		# ENTRANCE AND EXIT ARE NEVER BROKEN -- they are appended
		# below, outside this loop, so the Zone always has a working
		# save point at the door and one at the goal.
		var puzzled := not (chamber.get("activities", []) as Array) \
				.is_empty()
		var here := WarpStation.create("st:%s" % rid,
				str(chamber.get("id", "room")).to_upper(), theme,
				rid if puzzled else "")
		here.position = origin + _rot(yaw, Vector3(
				float(chamber.get("width", 16.0)) * 0.3, 0.0,
				float(chamber.get("depth", 16.0)) * 0.5))
		root.add_child(here)
		stations.append(here)
	return footprint

## Branches declared behind a door that is not a way through.
##
## A branch room is reached through ONE side socket and no other, so a
## socket the door plan leaves `SEALED` -- or does not assign at all --
## makes the branch unreachable. Nothing downstream can tell: the room
## composes, its Checks are placed, and the player simply never sees it.
## Refused before anything is allocated, like every other contradiction.
##
## `LOCKED` is fine and is the point: the owner's Missile door and the
## Zone-local key both gate a branch rather than sealing it.
static func unreachable_branches(zone: Dictionary) -> Dictionary:
	var out := {}
	for raw_chamber: Variant in zone.get("chambers", []):
		if typeof(raw_chamber) != TYPE_DICTIONARY:
			continue
		var chamber: Dictionary = raw_chamber
		if (chamber.get("branches", []) as Array).is_empty():
			continue
		var usage := {}
		for raw_door: Variant in chamber.get("doors", []):
			if typeof(raw_door) == TYPE_DICTIONARY:
				usage[str((raw_door as Dictionary).get("socket_id", ""))] \
						= str((raw_door as Dictionary).get("usage", ""))
		for raw_branch: Variant in chamber.get("branches", []):
			if typeof(raw_branch) != TYPE_DICTIONARY:
				continue
			var branch: Dictionary = raw_branch
			var socket := str(branch.get("socket_id", ""))
			var how := str(usage.get(socket, "UNASSIGNED"))
			if how == "USED" or how == "LOCKED":
				continue
			var rid := str(chamber.get("id", "?"))
			var hit: Array = out.get(rid, [])
			hit.append("%s is %s" % [socket, how])
			out[rid] = hit
	return out

## The sockets the chain itself walks through. A door on one of these is
## on the route from the entrance to the exit; anything else is a branch.
const CHAIN_SOCKETS := ["entry", "exit"]

## Capability gates standing on a chain socket, as room id -> socket ids.
##
## Empty for every Zone that has no `requires` on any door, which is
## every Zone built before capability gates existed.
static func gates_on_the_route(zone: Dictionary) -> Dictionary:
	var out := {}
	for raw_chamber: Variant in zone.get("chambers", []):
		if typeof(raw_chamber) != TYPE_DICTIONARY:
			continue
		var chamber: Dictionary = raw_chamber
		for raw_door: Variant in chamber.get("doors", []):
			if typeof(raw_door) != TYPE_DICTIONARY:
				continue
			var door: Dictionary = raw_door
			if str(door.get("requires", "")) == "":
				continue
			var socket := str(door.get("socket_id", ""))
			if not CHAIN_SOCKETS.has(socket):
				continue
			var rid := str(chamber.get("id", "?"))
			var hit: Array = out.get(rid, [])
			hit.append(socket)
			out[rid] = hit
	return out

static func _root(parent: Dictionary, id: String) -> String:
	var at := id
	while parent.has(at) and str(parent[at]) != at:
		at = str(parent[at])
	if not parent.has(id):
		parent[id] = at
	return at

## A TIGHTER POLICY, so exhaustion can be exercised without contriving
## geometry that pretends to be impossible.
##
## `LAYOUT_INFEASIBLE` means "the candidate space defined by the declared
## routing policy is empty", and the only honest way to reach it in a
## test is to declare a smaller space and exhaust THAT. Contriving a Zone
## the shipping policy cannot route would prove something narrower and
## read as "no layout exists", which is the claim this result may never
## make.
static var policy_override := {}

## Where this room can go: straight ahead, or around one or two corners.
##
## Returns `{ok, route}` where `route` is the steps to walk, in order:
## `{turn, connectors}` entries, `turn` being 0, -1 or +1. `prefer` is
## the aesthetic roll -- the layout's way of not running in a straight
## line -- and it only reorders the candidates. What decides is whether
## the geometry clears.
##
## A direction is exhausted the moment the NEXT CONNECTOR would itself
## overlap something. Pushing past that point is how a corridor ends up
## inside a room, and it is exactly what the old unchecked push did.
static func _plan_route(shape: Dictionary, corners: Dictionary,
		room: AABB, entry_at: Vector3, cursor: Vector3, yaw: float,
		placed: Array, prefer: int) -> Dictionary:
	var budget := int(routing_policy(placed,
			policy_override)["clearance_budget"])
	var turns_allowed := int(routing_policy(placed,
			policy_override)["max_route_turns"])
	# THE PREFERRED TURN IS TRIED FIRST, and that is not a detail: the
	# search below always fits a room straight ahead when it can, so a
	# Zone whose rooms all fit straight ahead is a Zone that never bends.
	# `_test_bent_layouts_never_overlap` caught exactly that.
	if prefer != 0:
		var corner: Dictionary = corners[prefer]
		if not _overlaps(placed, _world_aabb(corner["bounds"], cursor, yaw)):
			var bent := _search(shape, corners, room, entry_at,
					cursor + _rot(yaw, corner["exit_offset"] as Vector3),
					yaw + float(prefer) * PI / 2.0, placed,
					turns_allowed - 1, prefer, budget,
					[_world_aabb(corner["bounds"], cursor, yaw)])
			if bool(bent["ok"]):
				var route: Array = [{"turn": prefer, "connectors": 0}]
				route.append_array(bent["route"] as Array)
				return {"ok": true, "route": route}
	return _search(shape, corners, room, entry_at, cursor, yaw, placed,
			turns_allowed, prefer, budget)

static func _search(shape: Dictionary, corners: Dictionary, room: AABB,
		entry_at: Vector3, cursor: Vector3, yaw: float, placed: Array,
		turns_left: int, prefer: int, budget: int,
		mine: Array = []) -> Dictionary:
	# A ROUTE MUST CLEAR ITSELF, not only what was already there. Without
	# `mine` -- the pieces this route has planned so far -- a room was
	# judged against `placed` alone, and a room whose declared entry
	# socket sits inside its envelope extends BACKWARDS over the
	# connectors just planned to reach it. Fourteen large authored rooms
	# routed successfully and overlapped.
	#
	# EXCEPT THE PIECE IT JOINS ONTO. A room meets its approach connector
	# at a shared face and an inset entry socket swallows a little of it:
	# that is the join, not a collision. `_all_but_last` drops exactly
	# the piece most recently laid, which is always the one the next
	# piece attaches to -- so adjacency is free and everything else is
	# refused. Treating the join as a collision refused every large
	# authored room outright.
	var chain: Array = placed.duplicate()
	chain.append_array(mine)
	var at := cursor
	var laid: Array = mine.duplicate()
	for i in budget + 1:
		var here := _world_aabb(room, origin_for(at, yaw, entry_at), yaw)
		if not _overlaps(_all_but_last(chain), here):
			return {"ok": true, "route": [{"turn": 0, "connectors": i}]}
		if turns_left > 0:
			var first := prefer if prefer != 0 else 1
			for turn: int in [first, -first]:
				var corner: Dictionary = corners[turn]
				var corner_box := _world_aabb(corner["bounds"], at, yaw)
				if _overlaps(_all_but_last(chain), corner_box):
					continue
				var beyond := laid.duplicate()
				beyond.append(corner_box)
				var sub := _search(shape, corners, room, entry_at,
						at + _rot(yaw, corner["exit_offset"] as Vector3),
						yaw + float(turn) * PI / 2.0, placed,
						turns_left - 1, prefer,
						budget if turns_left == 1 else EXPLORE_CONNECTORS,
						beyond)
				if bool(sub["ok"]):
					var route: Array = [{"turn": 0, "connectors": i},
							{"turn": turn, "connectors": 0}]
					route.append_array(sub["route"] as Array)
					return {"ok": true, "route": route}
		var link := _world_aabb(shape["bounds"], at, yaw)
		if _overlaps(_all_but_last(chain), link):
			break
		chain.append(link)
		laid.append(link)
		at += _rot(yaw, shape["exit_offset"] as Vector3)
	return {"ok": false, "route": []}

## Builds the route `_plan_route` chose. Returns `{cursor, yaw}`.
## THE PIECES ARE THE LAYOUT TOO, so they are recorded as they are laid.
##
## `LAYOUT_OK` used to be room transforms alone, and room transforms
## cannot rebuild a Zone: this function also places corner pieces and
## connector segments, chosen by a search, and a manifest without them
## can only be replayed by running that search again -- which is the one
## thing a committed layout promises never to do. `chain` collects each
## piece as it is built, in build order, so a replay lays them down
## rather than rediscovering them.
static func _emit_route(root: Node3D, theme: String, plan: Dictionary,
		cursor: Vector3, yaw: float, placed: Array,
		bounds_list: Array, chain: Array = []) -> Dictionary:
	var at := cursor
	var facing := yaw
	var turns := 0
	for raw: Variant in plan["route"] as Array:
		var step: Dictionary = raw
		if int(step["turn"]) != 0:
			var corner := ChamberBuilders.corner(int(step["turn"]), theme)
			var world: AABB = _world_aabb(corner["bounds"], at, facing)
			var node: Node3D = corner["root"]
			node.name = "Corner"
			node.position = at
			node.rotation.y = facing
			root.add_child(node)
			placed.append(world)
			bounds_list.append(world)
			chain.append({"kind": "CORNER", "position": at,
					"yaw": facing, "bounds": world})
			at += _rot(facing, corner["exit_offset"] as Vector3)
			facing += float(step["turn"]) * PI / 2.0
			turns += 1
		for _i in int(step["connectors"]):
			var was := at
			at = _emit_connector(root, theme, at, facing, placed,
					bounds_list)
			chain.append({"kind": "CONNECTOR", "position": was,
					"yaw": facing,
					"bounds": bounds_list[bounds_list.size() - 1]})
	return {"cursor": at, "yaw": facing, "turns": turns}

static func _emit_connector(root: Node3D, theme: String, cursor: Vector3,
		yaw: float, placed: Array, bounds_list: Array) -> Vector3:
	# A distinct id per connector: greebles and theme props seed from it,
	# and every connector sharing one id made them visibly copy-pasted.
	var connector := ChamberBuilders.corridor(
			{"id": "conn_%d" % bounds_list.size(),
			"length": CONNECTOR_LENGTH, "width": CONNECTOR_WIDTH}, theme)
	var node: Node3D = connector["root"]
	node.name = "Connector"
	node.position = cursor
	node.rotation.y = yaw
	root.add_child(node)
	var world: AABB = _world_aabb(connector["bounds"], cursor, yaw)
	placed.append(world)
	bounds_list.append(world)
	return cursor + _rot(yaw, connector["exit_offset"])

## Returns { root, spawn_transform, chambers: [{chamber, node, build,
##           xform}], exit_portal, bounds_list }
static func build(zone: Dictionary, theme_override := "",
		budget_ms := 0.0) -> Dictionary:
	var theme: String = theme_override if theme_override != "" \
			else zone.get("theme", "void_glitch")
	# THE BUDGET IS WHAT A TIMEOUT MEASURES, and it is the caller's.
	# A timeout must never be inferred from difficulty: a constrained
	# Zone fails FAST and exhausts, which is infeasibility. Only a clock
	# running out is a timeout.
	var began := Time.get_ticks_msec()
	# A CLOSING EDGE IS REFUSED BEFORE ANYTHING IS BUILT.
	#
	# Ignoring it and building the chain anyway is the failure mode this
	# check exists to prevent: the graph would say two rooms are joined
	# both ways and the geometry would join them once, and nothing
	# downstream could tell.
	var closing := unclosable_cycles(zone)
	if not closing.is_empty():
		var pairs: Array = []
		for raw: Variant in closing:
			var edge: Dictionary = raw
			pairs.append([str(edge.get("room_a", "")),
					str(edge.get("room_b", ""))])
		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy([], policy_override),
				"blocking_rooms": [],
				"blocking_pairs": pairs,
				"failed": "%d JOINED edge(s) close a spatial cycle and "
				% closing.size() + "this router builds chains; see "
				+ "policy.closes_cycles"}
	# A CAPABILITY GATE MAY NOT STAND ON THE ROUTE OUT.
	#
	# SOLUTIONS_CATALOGUE §0-bis makes a hard capability gate legal and
	# conditions 4 and 5 on it: the player must be able to leave the
	# blocked Zone and to come back. A KEY lock on the chain is fine --
	# its key is in this Zone by construction, and the suite proves the
	# key is reachable before the lock. A CAPABILITY gate is not: the
	# owner's own example puts the capability in Zone 2, so a gate on the
	# chain would stand between the player and the exit with nothing in
	# this Zone able to open it. That is a dead run, not hard
	# progression.
	#
	# The chain walks `entry` and `exit`; `side_left` and `side_right`
	# are branch sockets. So the rule is exactly: gates go on branches.
	var stranding := gates_on_the_route(zone)
	if not stranding.is_empty():
		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy([], policy_override),
				"blocking_rooms": stranding.keys(),
				"blocking_pairs": [],
				"failed": "%d capability gate(s) stand on a chain "
				% stranding.size() + "socket, which puts them between "
				+ "the player and the Zone exit: %s" % str(stranding)}
	var orphaned := unreachable_branches(zone)
	if not orphaned.is_empty():
		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy([], policy_override),
				"blocking_rooms": orphaned.keys(),
				"blocking_pairs": [],
				"failed": "%d room(s) declare a branch behind a socket "
				% orphaned.size() + "that is not a way through: %s"
				% str(orphaned)}
	var links := {}
	var room_transforms := {}
	# ANCHORS ARE THE COMPOSER'S VOCABULARY FOR PLACES. A plug names one
	# and this file resolves it; nothing outside ever says a coordinate.
	var anchors := {}
	var plugs: Array = []
	var keys: Array = []
	var locks: Array = []
	var stations: Array = []
	var largest := {"area": 0.0, "id": ""}
	var root := Node3D.new()
	root.name = "Zone_%s" % zone.get("zone_id", "unknown")

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(theme)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(theme)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = ThemeMaterials.void_color(theme).lightened(0.1)
	env.fog_density = 0.012
	environment.environment = env
	root.add_child(environment)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|layout" % [zone.get("zone_id", ""), theme])

	var cursor := Vector3.ZERO
	var yaw := 0.0
	## Pieces laid after a room, belonging to the next room's approach.
	var carried: Array = []
	var next_turn := 1 if rng.randf() < 0.5 else -1
	var placed: Array = []
	var built_chambers: Array = []
	var bounds_list: Array = []
	var first := true
	## Set when the room just placed bent the route itself, so the corner
	## roll below is skipped exactly once rather than compounding.
	var straight_after_turn := false
	# The shapes routing reasons about, measured once from the real
	# builders so the plan and the emission cannot describe different
	# geometry.
	var shape := _connector_shape(theme)
	var corners := {
		1: _shape_of(ChamberBuilders.corner(1, theme)),
		-1: _shape_of(ChamberBuilders.corner(-1, theme)),
	}

	for chamber: Dictionary in zone.get("chambers", []):
		# S13: every chamber's geometry is chosen here, not assumed.
		# Today every route ends at ChamberBuilders because every registry
		# entry is still a declared placeholder; the routing is what lets an
		# authored shell replace one without touching this file.
		var result := ContentInstantiator.build_chamber(chamber, theme)
		# THE CURSOR IS WHERE THE ROOMS MEET, NOT WHERE THIS ONE STARTS
		# (owner ruling, 2026-09-03). A room is placed so that its
		# declared ENTRY CONNECTOR lands on the previous room's exit;
		# where its origin ends up is then arithmetic rather than an
		# assumption. Every pre-ruling room declares `LEGACY_ENTRY`, so
		# `origin` and `cursor` coincide and nothing about the played
		# Zone moves.
		var entry_at: Vector3 = result.get("entry_offset",
				RoomContract.LEGACY_ENTRY)

		# WHERE THIS ROOM CAN GO -- decided before anything is built.
		# The random roll is the layout's way of not running in a
		# straight line and it only REORDERS the candidates; what
		# decides is whether the geometry clears. A room that turned the
		# chain itself has already turned it, so the roll is skipped
		# exactly once rather than compounding into a U-turn back into
		# the arm just left.
		# ...AND A ROOM THAT WILL TURN THE CHAIN DOES NOT NEED A CORNER
		# IN FRONT OF IT EITHER. The roll was suppressed only AFTER such
		# a room, so a corner shell could still get one immediately
		# before it -- two 90 degree turns with a 6 m room between them,
		# repeated six times in a Zone, and the route folds into itself.
		# `exit_yaw` is known here because the room is already built, so
		# this is read rather than guessed.
		var turns_itself := RoomContract.EXIT_YAWS.has(
				float(result.get("exit_yaw", 0.0))) \
				and float(result.get("exit_yaw", 0.0)) != 0.0
		var prefer := 0
		if not first and not straight_after_turn and not turns_itself \
				and rng.randf() < TURN_CHANCE:
			prefer = next_turn
		straight_after_turn = false
		var plan := _plan_route(shape, corners, result["bounds"] as AABB,
				entry_at, cursor, yaw, placed, prefer)
		# NO ROOM IS EVER ATTACHED ON TOP OF ANOTHER. Straight ahead and
		# both corners were tried, connectors included, and none of them
		# clears. A Zone with a room inside another room is a Check in a
		# wall and an enemy inside the floor; there is no version of that
		# worth returning, so the build FAILS and the caller decides.
		if not bool(plan["ok"]):
			# EXHAUSTED, not expired. `_search` returns false only after
			# it has walked its whole candidate space, so this is
			# infeasibility UNDER THE DECLARED POLICY and says nothing
			# about a layout outside it.
			(result["root"] as Node3D).free()
			root.free()
			return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
					"policy": routing_policy(placed, policy_override),
					"blocking_rooms": [str(chamber.get("id", "?"))],
					"blocking_pairs": [],
					"failed": "room '%s' could not be placed clear of "
					% str(chamber.get("id", "?"))
					+ "the %d room(s) before it" % placed.size()}
		if budget_ms > 0.0 \
				and float(Time.get_ticks_msec() - began) > budget_ms:
			# The clock ran out with rooms still unplaced. Candidates
			# remain by construction, which is what separates this from
			# the branch above.
			(result["root"] as Node3D).free()
			root.free()
			return {"status": "LAYOUT_TIMEOUT",
					"elapsed_ms": float(Time.get_ticks_msec() - began),
					"nodes_explored": placed.size(),
					"candidates_remaining":
						maxi(1, (zone.get("chambers", []) as Array).size()
							- built_chambers.size()),
					"failed": "the placement budget of %.0f ms was spent "
					% budget_ms + "with rooms still unplaced"}
		# THE LINKING CONNECTOR BELONGS TO THE ROOM IT LEADS TO.
		#
		# It is emitted at the END of the previous room's turn, after
		# that room's chain was already recorded, so recording it there
		# would replay it BEFORE the room it follows. Carrying it into
		# the next room's chain puts it in build order, which is the
		# order a replay lays pieces down.
		var link: Array = carried.duplicate()
		carried.clear()
		var walked := _emit_route(root, theme, plan, cursor, yaw, placed,
				bounds_list, link)
		links[str(chamber.get("id", "?"))] = link
		cursor = walked["cursor"]
		yaw = float(walked["yaw"])
		if int(walked["turns"]) % 2 == 1:
			next_turn = -next_turn

		var origin := origin_for(cursor, yaw, entry_at)
		var node: Node3D = result["root"]
		node.name = "Chamber_%s" % chamber.get("id", "c")
		node.position = origin
		node.rotation.y = yaw
		var rid := str(chamber.get("id", "?"))
		var footprint := _furnish_room(root, theme, chamber, result,
				origin, yaw, anchors, room_transforms, keys, locks,
				stations)
		if footprint > float(largest["area"]):
			largest = {"area": footprint, "id": rid}
		root.add_child(node)
		var world_bounds: AABB = _world_aabb(result["bounds"], origin, yaw)
		placed.append(world_bounds)
		bounds_list.append(world_bounds)
		built_chambers.append({
			"chamber": chamber, "node": node, "build": result,
			"xform": Transform3D(Basis(Vector3.UP, yaw), origin),
		})
		# BRANCHES: ROOMS THE CHAIN DOES NOT PASS THROUGH.
		#
		# Placed from the parent's SIDE socket, outward, using the same
		# route search the chain uses -- a branch is not a special kind
		# of geometry, it is the same placement problem started from a
		# different door. It is placed BEFORE the chain continues, so
		# every later room routes around it rather than through it.
		#
		# The chain's own `cursor`, `yaw` and turn state are untouched:
		# a branch must not steer the Zone.
		for raw_branch: Variant in chamber.get("branches", []):
			if typeof(raw_branch) != TYPE_DICTIONARY:
				continue
			var branch: Dictionary = raw_branch
			var b_chamber: Dictionary = branch.get("chamber", {})
			if b_chamber.is_empty():
				continue
			var socket_id := str(branch.get("socket_id", "side_left"))
			var mouth := ChamberBuilders.socket_placed(socket_id,
					float(chamber.get("width", 16.0)),
					float(chamber.get("depth", 16.0)))
			if mouth.is_empty():
				push_warning("zone: branch on unknown socket '%s'"
						% socket_id)
				continue
			# OUTWARD IS DERIVED, NOT READ. A socket declares a `yaw`
			# and the two side sockets declare inward-facing ones, so
			# trusting that field would have sent every branch back
			# through the room it came from. The direction from the
			# room's centre line to the socket cannot be ambiguous.
			var out_dir := -1.0 if socket_id == "side_left" else 1.0
			var b_yaw := yaw + out_dir * PI / 2.0
			var b_result := ContentInstantiator.build_chamber(
					b_chamber, theme)
			var b_entry: Vector3 = b_result.get("entry_offset",
					RoomContract.LEGACY_ENTRY)
			# ONE CONNECTOR ALWAYS, and it is not decoration.
			#
			# Without it the search happily placed the branch flush
			# against the junction and returned a route of zero pieces:
			# the two envelopes abutted, each room's floor stopped at its
			# own wall, and the half-metre of wall between them had NO
			# FLOOR AT ALL. The aperture was carved, the lock opened, the
			# audit passed, and a player walking through the door fell
			# into the gap. Measured, not reasoned about -- the flood
			# reported no standable column at z=66.75 or z=66.50 with
			# standable floor on both sides of it.
			#
			# The chain never hit this because it lays a linking
			# connector between every pair of rooms. A branch is a join
			# like any other and gets one too.
			var b_link: Array = []
			var mouth_at: Vector3 = origin \
					+ _rot(yaw, mouth["position"] as Vector3)
			b_link.append({"kind": "CONNECTOR", "position": mouth_at,
					"yaw": b_yaw, "bounds": _world_aabb(
							shape["bounds"] as AABB, mouth_at, b_yaw)})
			var b_cursor := _emit_connector(root, theme, mouth_at,
					b_yaw, placed, bounds_list)
			var b_plan := _plan_route(shape, corners,
					b_result["bounds"] as AABB, b_entry, b_cursor,
					b_yaw, placed, 0)
			if not bool(b_plan["ok"]):
				(b_result["root"] as Node3D).free()
				(result["root"] as Node3D).free()
				root.free()
				return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
						"policy": routing_policy(placed, policy_override),
						"blocking_rooms": [str(b_chamber.get("id", "?"))],
						"blocking_pairs": [],
						"failed": "branch room '%s' off '%s' could not "
						% [str(b_chamber.get("id", "?")), rid]
						+ "be placed clear of the %d room(s) already "
						% placed.size() + "standing"}
			var b_walked := _emit_route(root, theme, b_plan, b_cursor,
					b_yaw, placed, bounds_list, b_link)
			var b_origin := origin_for(b_walked["cursor"],
					float(b_walked["yaw"]), b_entry)
			var b_node: Node3D = b_result["root"]
			var b_id := str(b_chamber.get("id", "branch"))
			b_node.name = "Chamber_%s" % b_id
			b_node.position = b_origin
			b_node.rotation.y = float(b_walked["yaw"])
			root.add_child(b_node)
			var b_world := _world_aabb(b_result["bounds"], b_origin,
					float(b_walked["yaw"]))
			placed.append(b_world)
			bounds_list.append(b_world)
			links[b_id] = b_link
			# A BRANCH IS FURNISHED LIKE ANY OTHER ROOM. Its keys,
			# its locked doors and its warp station come from the same
			# function the chain's do, so a gated dead end can hold the
			# key to the next one.
			_furnish_room(root, theme, b_chamber, b_result, b_origin,
					float(b_walked["yaw"]), anchors, room_transforms,
					keys, locks, stations)
			# ON `built_chambers`, so a branch is a room to everything
			# downstream: its Checks, activities and enemies are wired by
			# the same controller code that wires the chain's.
			built_chambers.append({
				"chamber": b_chamber, "node": b_node, "build": b_result,
				"xform": Transform3D(
						Basis(Vector3.UP, float(b_walked["yaw"])),
						b_origin),
			})
		cursor = exit_cursor(origin, yaw, result["exit_offset"])
		# P2-B: A ROOM MAY TURN THE CHAIN. Applied after the room is
		# placed and its cursor advanced, so the room itself is still
		# measured and overlap-guarded at the yaw it was built for, and
		# the turn only steers what comes next. Absent or zero is
		# straight through -- what every room did before this existed.
		#
		# The connector after the turn is emitted at the NEW yaw, which
		# is what makes the corner a corner rather than a room with a
		# rotated doorway.
		var turn := float(result.get("exit_yaw", 0.0))
		if RoomContract.EXIT_YAWS.has(turn):
			yaw += deg_to_rad(turn)
			# A ROOM THAT TURNED THE CHAIN HAS TURNED IT. The random
			# corner below is the layout's way of not running in a
			# straight line, and it rolled independently of whether the
			# room just placed had already bent the route -- so a corner
			# shell's 90 degrees plus a corner piece's 90 degrees sent
			# the next room straight back into the arm it had just left.
			# Nothing noticed while no room turned: `exit_yaw` was zero
			# on every procedural builder, so the second turn never had
			# a first one to compound. With eight authored corners in a
			# Zone it folded the chain onto itself, and Zone 1's `c020`
			# came to hold its Check inside `c023`.
			if turn != 0.0:
				straight_after_turn = true
		else:
			push_warning("zone: chamber '%s' asks to turn %.1f degrees; "
					% [str(chamber.get("id", "?")), turn]
					+ "the chain turns by quarters, so it goes straight")
		# The linking connector between rooms, and it is CHECKED like
		# everything else now. It was emitted unconditionally, so on a
		# folded chain it could be laid inside a room that was already
		# there -- geometry attached without anything having asked
		# whether it fitted. Where it does not fit, the next room simply
		# starts at this room's exit, which is where it would have
		# started anyway.
		if not _overlaps(placed, _world_aabb(shape["bounds"], cursor, yaw)):
			var was := cursor
			cursor = _emit_connector(root, theme, cursor, yaw, placed,
					bounds_list)
			# RECORDED, like every other piece. It was emitted and never
			# written down, so a manifest replayed the Zone one
			# connector short at every room boundary -- and the test that
			# checks the chain is complete only ever asked about the
			# pieces `_emit_route` laid, so it could not see this.
			carried.append({"kind": "CONNECTOR", "position": was,
					"yaw": yaw,
					"bounds": bounds_list[bounds_list.size() - 1]})
		first = false

	# Exit room with the appended portal — routed like every other
	# placement, not trusted to clear by arithmetic coincidence. A Zone
	# whose exit sits inside another room is one a player cannot finish,
	# so this fails the build for the same reason a chamber does.
	var exit_room := ChamberBuilders.treasure_room({"id": "exit"}, theme)
	var exit_plan := _plan_route(shape, corners,
			exit_room["bounds"] as AABB, RoomContract.LEGACY_ENTRY,
			cursor, yaw, placed, 0)
	if not bool(exit_plan["ok"]):
		(exit_room["root"] as Node3D).free()
		root.free()
		return {"failed": "the exit room could not be placed clear of "
				+ "the %d room(s) before it" % placed.size()}
	# THE EXIT ROOM IS A ROOM. Its approach was searched exactly like
	# every other and was the one route never written down, so a
	# manifest could rebuild the whole Zone and then have to re-solve
	# the last leg -- which is the one thing a committed layout promises
	# never to do.
	var exit_link: Array = carried.duplicate()
	carried.clear()
	var exit_walk := _emit_route(root, theme, exit_plan, cursor, yaw,
			placed, bounds_list, exit_link)
	links["exit"] = exit_link
	cursor = exit_walk["cursor"]
	yaw = float(exit_walk["yaw"])
	var exit_node: Node3D = exit_room["root"]
	exit_node.name = "ExitRoom"
	exit_node.position = cursor
	exit_node.rotation.y = yaw
	root.add_child(exit_node)
	var exit_world: AABB = _world_aabb(exit_room["bounds"], cursor, yaw)
	placed.append(exit_world)
	bounds_list.append(exit_world)
	room_transforms["exit"] = {"position": cursor, "yaw": yaw,
			"bounds": exit_world,
			"arrival": cursor + _rot(yaw, RoomContract.LEGACY_ENTRY)}
	var portal := ExitPortal.create(theme)
	portal.position = cursor + _rot(yaw, Vector3(0, 0, 6.5))
	# AND THE EXIT STATION, beside the portal rather than in its doorway
	# -- nothing may stand in front of a portal.
	var by_exit := WarpStation.create("st:exit", "EXIT", theme)
	by_exit.position = portal.position + _rot(yaw, Vector3(3.0, 0, -1.5))
	root.add_child(by_exit)
	stations.append(by_exit)
	portal.rotation.y = yaw
	root.add_child(portal)

	# Face +Z, where the level actually is (identity looks down -Z).
	var spawn := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.8, 1.2))
	anchors["zone_start"] = spawn.origin
	# THE ENTRANCE STATION, off to one side of the spawn so a player
	# does not begin standing inside it.
	var entrance := WarpStation.create("st:entrance", "ENTRANCE", theme)
	entrance.position = spawn.origin + Vector3(2.4, -0.8, 0.0)
	root.add_child(entrance)
	stations.append(entrance)
	if str(largest["id"]) != "":
		anchors["last_large_room"] = anchors.get(
				"room:%s:arrival" % str(largest["id"]), spawn.origin)
	# THE ZONE'S KEYS. Not items: no location id, never scouted, never
	# sent, gone when the Zone is. Placed at anchors like everything
	# else a composer positions.
	for raw: Variant in zone.get("keys", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = raw
		var at := str(spec.get("anchor", ""))
		if not anchors.has(at):
			push_warning("zone: key '%s' names unknown anchor '%s'"
					% [str(spec.get("key_id", "?")), at])
			continue
		var key := ZoneKey.create(str(spec.get("key_id", "")),
				str(spec.get("colour", "gold")))
		key.position = anchors[at]
		root.add_child(key)
		keys.append(key)
	# THE RETURN DEVICES, placed where the composer put them.
	#
	# A plug is not a door: it takes no joining socket, so nothing here
	# consults the door plan, and the placement search was never handed a
	# closure constraint for it. Both its ends are anchors.
	for raw: Variant in zone.get("plugs", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = raw
		var source := str(spec.get("source_anchor", ""))
		if not anchors.has(source):
			push_warning("zone: plug '%s' names unknown anchor '%s'"
					% [str(spec.get("edge_id", "?")), source])
			continue
		var plug := ReturnPlug.create(str(spec.get("edge_id", "")),
				str(spec.get("destination", "zone_start")),
				str(spec.get("device", "threshold")), theme)
		plug.position = anchors[source]
		root.add_child(plug)
		plugs.append(plug)
	return {"root": root, "spawn_transform": spawn,
			"chambers": built_chambers, "exit_portal": portal,
			"bounds_list": bounds_list,
			# THE WHOLE LAYOUT, not just where the rooms are. `links`
			# holds the connector and corner chain that reaches each
			# room, in build order, so a committed Zone replays by
			# laying pieces down rather than by searching again.
			"status": "LAYOUT_OK", "rooms": room_transforms,
			"links": links, "anchors": anchors, "plugs": plugs,
			"keys": keys, "locks": locks, "stations": stations}
