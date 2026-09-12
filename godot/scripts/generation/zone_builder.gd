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

## The first pair of committed rooms that overlap by the BRIDGE's rule:
## a positive extent on all three axes past a millimetre. `layout.py`
## `_overlaps` is the same arithmetic, and this exists so the two sides
## cannot disagree about what "overlap" means.
static func _rooms_that_overlap(rooms: Dictionary) -> Array:
	var ids: Array = rooms.keys()
	ids.sort()
	for i in ids.size():
		var a: AABB = (rooms[ids[i]] as Dictionary).get("bounds", AABB())
		for j in range(i + 1, ids.size()):
			var b: AABB = (rooms[ids[j]] as Dictionary).get(
					"bounds", AABB())
			var hit := a.intersection(b)
			if hit.size.x > BRIDGE_EPSILON and hit.size.y > BRIDGE_EPSILON \
					and hit.size.z > BRIDGE_EPSILON:
				return [str(ids[i]), str(ids[j])]
	return []

## `EPSILON_JOIN` in `bridge/archipepsi_bridge/layout.py`.
const BRIDGE_EPSILON := 0.001

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
## One entry of a built room's own door plan, by socket id, or empty.
static func _planned_door(result: Dictionary, socket_id: String) -> Dictionary:
	if socket_id == "":
		return {}
	for raw: Variant in result.get("doors", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var plan: Dictionary = raw
		if str(plan.get("socket_id", "")) == socket_id:
			return plan
	return {}

static func _furnish_room(root: Node3D, theme: String,
		chamber: Dictionary, result: Dictionary, origin: Vector3,
		yaw: float, anchors: Dictionary, room_transforms: Dictionary,
		keys: Array, locks: Array, stations: Array,
		dropped: Array = [], door_world: Dictionary = {}) -> float:
	var rid := str(chamber.get("id", "?"))
	# WHERE EACH DECLARED DOOR ACTUALLY IS, from the producer's own plan
	# rather than re-derived. Both producers emit `doors` with a position,
	# a usage and the polarity the audit expects; this is the same list,
	# carried into world space once, so `joins` and the aperture report
	# cannot disagree about where a socket is.
	for raw_door: Variant in result.get("doors", []):
		if typeof(raw_door) != TYPE_DICTIONARY:
			continue
		var plan: Dictionary = raw_door
		door_world["%s/%s" % [rid, str(plan.get("socket_id", ""))]] = \
				origin + _rot(yaw, plan.get("position", Vector3.ZERO))
	# A DECLARED KEY THAT NO PRODUCER PLACED IS A DROPPED KEY.
	#
	# Not a warning: the bridge's `R ⊆ E` proves a key is obtainable
	# before its lock, and that proof is about a key that EXISTS. A Zone
	# whose key was silently not built has a lock nothing opens, and that
	# is a Zone the player cannot finish. Collected here and refused by
	# the caller, so the reason names the room.
	var wanted := (chamber.get("keys", []) as Array).size()
	var got := (result.get("key_spots", []) as Array).size()
	if wanted > got:
		dropped.append("%s wanted %d key(s) and its producer reserved %d"
				% [rid, wanted, got])
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
	#
	# READ OFF THE ROOM'S OWN PLAN, which is the same list `door_world`
	# and the aperture report read. This used to re-derive the socket
	# from `chamber.width`/`chamber.depth` -- fields a `platform_path`
	# does not carry at all, so the derivation fell to a 16 x 16 default
	# and put the slab in a room that is 8 m wide. `socket_placed` says
	# out loud that a second derivation is how the two come to disagree;
	# this was the second derivation.
	for raw_door: Variant in chamber.get("doors", []):
		if typeof(raw_door) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw_door
		if str(door.get("usage", "")) != "LOCKED":
			continue
		var socket := _planned_door(result,
				str(door.get("socket_id", "")))
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

## WHERE THE ROOMS GO, READ OFF THE GRAPH THE BRIDGE SENT.
##
## The bridge composes a real branching topology -- `topology.py`
## `compose_with_branch` moves one room off the spine onto a junction's
## `side_left` behind a lock, and says so in `edges` and in each
## chamber's `doors`. Until this existed the engine walked
## `zone.chambers` in list order and the branch room was built IN LINE:
## the graph said "off to one side", the geometry said "next in the
## corridor", and nothing could tell.
##
## Nothing here invents an assignment. A door's `socket_id` is the
## socket, an edge's `realization` says whether it binds geometry, and
## the two sockets an edge names are read from the two rooms' own door
## lists. The engine's only contribution is knowing that `entry` and
## `exit` are the chain's sockets and the sides are not.
##
## Returns `{spine, branches, refused}`:
##   `spine`    room ids in chain order
##   `branches` parent id -> [{socket_id, chamber, edge_id}]
##   `refused`  non-empty when the graph cannot be placed, saying why
##
## A Zone with no `edges` returns its chamber list as the spine and no
## branches, which is exactly the chain that shipped before -- the
## additive promise `schema_version` 7 rests on.
static func placement_plan(zone: Dictionary) -> Dictionary:
	var order: Array = []
	var by_id := {}
	for raw: Variant in zone.get("chambers", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var chamber: Dictionary = raw
		var rid := str(chamber.get("id", ""))
		if rid == "":
			continue
		order.append(rid)
		by_id[rid] = chamber
	var edges: Array = zone.get("edges", [])
	if edges.is_empty():
		return {"spine": order, "branches": {}, "refused": ""}

	# Which socket each room assigns to each edge. A room that names no
	# door for an edge it is an endpoint of is a refusal and not a
	# default: the bridge's rule 1 is that every joining socket is
	# mentioned, so an absent one means the two lanes disagree.
	var socket_of := {}
	for rid: String in by_id:
		for raw_door: Variant in (by_id[rid] as Dictionary).get("doors", []):
			if typeof(raw_door) != TYPE_DICTIONARY:
				continue
			var door: Dictionary = raw_door
			var eid := str(door.get("edge_id", ""))
			if eid == "" or str(door.get("usage", "")) == "SEALED":
				continue
			socket_of["%s|%s" % [rid, eid]] = str(door.get("socket_id", ""))

	var next_on_spine := {}
	var has_parent := {}
	var branches := {}
	for raw_edge: Variant in edges:
		if typeof(raw_edge) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = raw_edge
		# A TRAVERSAL_ONLY edge binds no geometry. It is as real as any
		# other to reachability and has nothing for a placer to do.
		if str(edge.get("realization", "JOINED")) != "JOINED":
			continue
		var a := str(edge.get("room_a", ""))
		var b := str(edge.get("room_b", ""))
		var eid := str(edge.get("edge_id", ""))
		if not by_id.has(a) or not by_id.has(b):
			return {"spine": order, "branches": {},
					"refused": "edge '%s' joins '%s' and '%s' and this "
					% [eid, a, b] + "Zone has no such chamber"}
		var sa := str(socket_of.get("%s|%s" % [a, eid], ""))
		var sb := str(socket_of.get("%s|%s" % [b, eid], ""))
		if sa == "" or sb == "":
			return {"spine": order, "branches": {},
					"refused": "edge '%s' is JOINED and room '%s' "
					% [eid, a if sa == "" else b]
					+ "assigns it no door; every joining socket a room "
					+ "declares is supposed to be mentioned"}
		var a_side := not CHAIN_SOCKETS.has(sa)
		var b_side := not CHAIN_SOCKETS.has(sb)
		if a_side and b_side:
			return {"spine": order, "branches": {},
					"refused": "edge '%s' joins two side sockets ('%s' "
					% [eid, sa] + "and '%s'); one end has to be a room's "
					% sb + "entry for the other to hang off it"}
		if not a_side and not b_side:
			# The spine: one room's exit meeting the next room's entry.
			var frm := a if sa == "exit" else b
			var to := b if sa == "exit" else a
			next_on_spine[frm] = to
			has_parent[to] = true
			continue
		var parent := a if a_side else b
		var child := b if a_side else a
		var hook: Array = branches.get(parent, [])
		hook.append({"socket_id": sa if a_side else sb,
				"chamber": by_id[child], "edge_id": eid})
		branches[parent] = hook
		has_parent[child] = true

	# The spine starts at the room nothing leads into, walked forward.
	var head := ""
	for rid: String in order:
		if not has_parent.has(rid):
			head = rid
			break
	if head == "":
		return {"spine": order, "branches": {},
				"refused": "every room has something joining into it, so "
				+ "the chain has no head; a cycle is refused separately"}
	var spine: Array = []
	var at := head
	var guard := 0
	while at != "" and guard <= order.size():
		spine.append(at)
		at = str(next_on_spine.get(at, ""))
		guard += 1

	# EVERY CHAMBER IS PLACED SOMEWHERE, or the plan is refused.
	#
	# A Zone whose `edges` reach only some of its rooms would otherwise
	# lose the rest in silence: the spine walk stops where the edges stop,
	# the remaining chambers are never iterated, and a Zone comes back
	# short with a LAYOUT_OK on it. Dropping a room is exactly the class
	# of failure a placement result must never report success for.
	var seen := {}
	for rid: Variant in spine:
		seen[str(rid)] = true
	for parent: Variant in branches:
		for raw_hook: Variant in branches[parent] as Array:
			seen[str(((raw_hook as Dictionary)["chamber"] as Dictionary)
					.get("id", ""))] = true
	var orphans: Array = []
	for rid: String in order:
		if not seen.has(rid):
			orphans.append(rid)
	if not orphans.is_empty():
		return {"spine": order, "branches": {},
				"refused": "%d chamber(s) are in no spine and on no "
				% orphans.size() + "branch, so the graph would place "
				+ "fewer rooms than the Zone declares: %s" % str(orphans)}
	return {"spine": spine, "branches": branches, "refused": ""}

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
	# EVERY ROOM THAT BRANCHES, at every depth. A branch is a room and
	# may branch again, so checking only the chain's chambers would leave
	# the deeper ones unchecked -- and an unreachable room is exactly as
	# invisible at depth two as at depth one.
	var queue: Array = (zone.get("chambers", []) as Array).duplicate()
	while not queue.is_empty():
		var raw_chamber: Variant = queue.pop_front()
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
			queue.append(branch.get("chamber", {}))
			var socket := str(branch.get("socket_id", ""))
			var how := str(usage.get(socket, "UNASSIGNED"))
			if how == "USED" or how == "LOCKED":
				continue
			var rid := str(chamber.get("id", "?"))
			var hit: Array = out.get(rid, [])
			hit.append("%s is %s" % [socket, how])
			out[rid] = hit
	return out

## The committed approach to this room, out of the edge-keyed manifest.
##
## A room is reached through the edge its `entry` door names -- which is
## true of a branch room as well as a spine room, because a branch hangs
## off its parent's SIDE and arrives at its own entry. A Zone with no
## graph has no edges to name, so its rooms fall back to the room-keyed
## form the engine also keeps.
static func committed_chain(layout: Dictionary,
		chamber: Dictionary) -> Array:
	var joins: Dictionary = layout.get("joins", {})
	for raw_door: Variant in chamber.get("doors", []):
		if typeof(raw_door) != TYPE_DICTIONARY:
			continue
		var door: Dictionary = raw_door
		if str(door.get("socket_id", "")) != "entry":
			continue
		var eid := str(door.get("edge_id", ""))
		if joins.has(eid):
			return ((joins[eid] as Dictionary).get("chain", []) as Array) \
					.duplicate()
	var by_room := "%s%s" % [ROOM_EDGE_PREFIX,
			str(chamber.get("id", "?"))]
	if joins.has(by_room):
		return ((joins[by_room] as Dictionary).get("chain", []) as Array) \
				.duplicate()
	return ((layout.get("links", {}) as Dictionary)
			.get(str(chamber.get("id", "?")), []) as Array).duplicate()

## Why this committed chain cannot be laid down, or "".
##
## A piece missing its pose is not a piece, and a CORNER that does not
## say which way it bends is a guess that sends everything after it off
## in the wrong direction. Named rather than skipped: a replay that
## quietly drops a corridor rebuilds a Zone the player has walked before
## and finds it changed.
static func malformed_pieces(chain: Array) -> String:
	for index in chain.size():
		if typeof(chain[index]) != TYPE_DICTIONARY:
			return "piece %d is not a record" % index
		var piece: Dictionary = chain[index]
		var kind := str(piece.get("kind", ""))
		if kind != "CONNECTOR" and kind != "CORNER":
			return "piece %d has kind '%s'" % [index, kind]
		if not piece.has("position") or not piece.has("yaw"):
			return "piece %d commits no pose" % index
		if typeof(piece["position"]) != TYPE_VECTOR3:
			return "piece %d's position is not a point" % index
		if kind == "CORNER" and int(piece.get("turn", 0)) == 0:
			return "corner at piece %d records no turn" % index
	return ""

## THE MANIFEST ON THE WIRE, and the manifest back off it.
##
## Law 47c commits a layout once and replays it forever, and "forever"
## goes through JSON and a save file. `Vector3` and `AABB` do not survive
## that, so the two conversions are written here, next to each other,
## where a field added to one and forgotten in the other is visible.
##
## `rooms`, `joins`, `anchors` and the two measured verdicts are what
## crosses. `links` does not: it is the same corridors keyed by room
## instead of by edge, and two spellings of one fact on one wire is how
## the lanes come to disagree about a corridor.
static func layout_to_json(result: Dictionary) -> Dictionary:
	var rooms := {}
	for rid: String in result.get("rooms", {}):
		var t: Dictionary = (result["rooms"] as Dictionary)[rid]
		rooms[rid] = {"position": _v3_out(t.get("position", Vector3.ZERO)),
				"yaw": float(t.get("yaw", 0.0)),
				"bounds": _box_out(t.get("bounds", AABB())),
				"arrival": _v3_out(t.get("arrival", Vector3.ZERO))}
	var joins := {}
	for eid: String in result.get("joins", {}):
		var j: Dictionary = (result["joins"] as Dictionary)[eid]
		var chain: Array = []
		for raw: Variant in j.get("chain", []):
			var piece: Dictionary = raw
			chain.append({"kind": str(piece.get("kind", "CONNECTOR")),
					"position": _v3_out(piece.get("position", Vector3.ZERO)),
					"yaw": float(piece.get("yaw", 0.0)),
					"turn": int(piece.get("turn", 0)),
					"entry": _v3_out(piece.get("entry", Vector3.ZERO)),
					"exit": _v3_out(piece.get("exit", Vector3.ZERO)),
					"bounds": _box_out(piece.get("bounds", AABB()))})
		joins[eid] = {"room_a": str(j.get("room_a", "")),
				"room_b": str(j.get("room_b", "")),
				"socket_a": _v3_out(j.get("socket_a", Vector3.ZERO)),
				"socket_b": _v3_out(j.get("socket_b", Vector3.ZERO)),
				"synthetic": bool(j.get("synthetic", false)),
				"chain": chain}
	var anchors := {}
	for name: String in result.get("anchors", {}):
		anchors[name] = _v3_out((result["anchors"] as Dictionary)[name])
	# `arrival_ok` and not `arrival`: the validator's name for it, and the
	# name says what it is. A MEASURED VERDICT, not a coordinate -- the
	# points are already in `anchors`, and a point is where a body would
	# arrive rather than evidence that one fits.
	return {"status": str(result.get("status", "")),
			"rooms": rooms, "joins": joins, "anchors": anchors,
			"arrival_ok": result.get("arrival_ok", {}),
			"apertures": result.get("apertures", {}),
			# The chains the engine built and replayed, as
			# `PlacedPackage` records bound to this Zone, the room and
			# the declared content they realize. Passed through rather
			# than re-shaped: the entries are already the contract's own
			# models, and a second spelling here would be a second
			# truth. `AMALGAM_BRIDGE.md` §5.6, option 2.
			"packages": result.get("packages", []),
			# WHICH BUILD'S CONTROLLER MEASURED ANY OF THIS.
			# `AP_CAPABILITY_LOGIC.md` §8b-ANSWERED: a movement
			# measurement is about what this executable does when you
			# press dash, and the physics package's `scene_digest`
			# cannot say that -- it describes the platform, not the
			# controller. Sent on every Zone entry because slot data is
			# fixed at seed generation and would certify a build the
			# player may not be running.
			"controller_digest": ControllerDigest.digest(),
			"stations": _station_ids(result)}

## The station ids the layout placed, which the manifest records so a
## revisited Zone offers the same travel it did before.
static func _station_ids(result: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in result.get("stations", []):
		if raw is WarpStation:
			out.append((raw as WarpStation).station_id)
	out.sort()
	return out

static func _box_out(v: Variant) -> Dictionary:
	var box: AABB = v if typeof(v) == TYPE_AABB else AABB()
	return {"position": _v3_out(box.position), "size": _v3_out(box.size)}

## DECODING NEVER INVENTS A COORDINATE.
##
## The first version filled a missing `position` with the origin, a
## missing `yaw` with zero and a missing `kind` with `CONNECTOR` -- so a
## piece that committed no pose arrived at `malformed_pieces` wearing a
## perfectly valid one, and the check that exists to catch exactly that
## could not see it. A default is an answer, and this has no business
## answering: the manifest either says where a thing is or it does not.
##
## Returns the decoded layout with `malformed` naming the first things
## that were missing, and `build()` refuses on it rather than searching.
## An EMPTY chain is not missing data -- it is direct abutment, and it
## stays valid.
static func layout_from_json(payload: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var rooms := {}
	for rid: String in payload.get("rooms", {}):
		var raw_room: Variant = (payload["rooms"] as Dictionary)[rid]
		if typeof(raw_room) != TYPE_DICTIONARY:
			errors.append("room '%s' is not a record" % rid)
			continue
		var t: Dictionary = raw_room
		rooms[rid] = {
			"position": _v3_req(t, "position",
					"room '%s'" % rid, errors),
			"yaw": _float_req(t, "yaw", "room '%s'" % rid, errors),
			"bounds": _box_req(t, "bounds", "room '%s'" % rid, errors),
			"arrival": _v3_req(t, "arrival", "room '%s'" % rid, errors),
		}
	var joins := {}
	for eid: String in payload.get("joins", {}):
		var raw_join: Variant = (payload["joins"] as Dictionary)[eid]
		if typeof(raw_join) != TYPE_DICTIONARY:
			errors.append("join '%s' is not a record" % eid)
			continue
		var j: Dictionary = raw_join
		var chain: Array = []
		var index := 0
		for raw: Variant in j.get("chain", []):
			var where := "join '%s' piece %d" % [eid, index]
			index += 1
			if typeof(raw) != TYPE_DICTIONARY:
				errors.append("%s is not a record" % where)
				continue
			var piece: Dictionary = raw
			var kind := str(piece.get("kind", ""))
			if kind != "CONNECTOR" and kind != "CORNER":
				errors.append("%s has kind '%s'" % [where, kind])
			var built := {
				"kind": kind,
				"position": _v3_req(piece, "position", where, errors),
				"yaw": _float_req(piece, "yaw", where, errors),
				"entry": _v3_req(piece, "entry", where, errors),
				"exit": _v3_req(piece, "exit", where, errors),
				"bounds": _box_req(piece, "bounds", where, errors),
			}
			# A CONNECTOR has no turn and a CORNER must have one. Reading
			# the field for both would let a cornerless zero look like a
			# corner that bends nowhere.
			if kind == "CORNER":
				built["turn"] = int(piece.get("turn", 0))
				if int(built["turn"]) == 0:
					errors.append("%s is a corner that records no turn"
							% where)
			else:
				built["turn"] = 0
			chain.append(built)
		joins[eid] = {"room_a": str(j.get("room_a", "")),
				"room_b": str(j.get("room_b", "")),
				"socket_a": _v3_req(j, "socket_a", "join '%s'" % eid,
						errors),
				"socket_b": _v3_req(j, "socket_b", "join '%s'" % eid,
						errors),
				"synthetic": bool(j.get("synthetic", false)),
				"chain": chain}
	var anchors := {}
	for name: String in payload.get("anchors", {}):
		anchors[name] = _v3_req(payload["anchors"] as Dictionary, name,
				"anchor '%s'" % name, errors)
	return {"rooms": rooms, "joins": joins, "anchors": anchors,
			"malformed": "; ".join(errors.slice(0, 4))}

## A vector the manifest must actually carry. Absent, short or
## non-numeric is an error and NOT a zero.
static func _v3_req(from: Dictionary, field: String, where: String,
		errors: Array[String]) -> Vector3:
	if not from.has(field):
		errors.append("%s carries no %s" % [where, field])
		return Vector3.ZERO
	var v: Variant = from[field]
	if typeof(v) == TYPE_VECTOR3:
		return v
	if typeof(v) != TYPE_ARRAY or (v as Array).size() < 3:
		errors.append("%s's %s is not a point" % [where, field])
		return Vector3.ZERO
	var a: Array = v
	for n: Variant in a.slice(0, 3):
		if typeof(n) != TYPE_FLOAT and typeof(n) != TYPE_INT:
			errors.append("%s's %s is not numeric" % [where, field])
			return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func _float_req(from: Dictionary, field: String, where: String,
		errors: Array[String]) -> float:
	if not from.has(field):
		errors.append("%s carries no %s" % [where, field])
		return 0.0
	var v: Variant = from[field]
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		errors.append("%s's %s is not a number" % [where, field])
		return 0.0
	return float(v)

static func _box_req(from: Dictionary, field: String, where: String,
		errors: Array[String]) -> AABB:
	if not from.has(field):
		errors.append("%s carries no %s" % [where, field])
		return AABB()
	var v: Variant = from[field]
	if typeof(v) == TYPE_AABB:
		return v
	if typeof(v) != TYPE_DICTIONARY:
		errors.append("%s's %s is not a box" % [where, field])
		return AABB()
	var d: Dictionary = v
	return AABB(_v3_req(d, "position", "%s %s" % [where, field], errors),
			_v3_req(d, "size", "%s %s" % [where, field], errors))

static func _v3_out(v: Variant) -> Array:
	var at: Vector3 = v if typeof(v) == TYPE_VECTOR3 else Vector3.ZERO
	return [at.x, at.y, at.z]

## THE LAYOUT AS THE BRIDGE HAS TO READ IT: keyed by edge.
##
## `links` is keyed by the room a chain reaches, which is what a replay
## needs -- it walks rooms. The validator needs the other question
## answered: are the two sockets THIS EDGE assigns actually connected?
## Absolute room transforms make that free and prove nothing, so the
## bridge walks socket -> first entry, each exit -> the next entry, last
## exit -> socket, and an empty chain means direct abutment and is still
## walked.
##
## ONE PAYLOAD, not two. The pieces carry `position`/`yaw`/`turn` for the
## replay and `entry`/`exit` for the walk, so both lanes read the same
## corridor and cannot come to different conclusions about it. `links`
## stays an in-engine convenience and is not what goes on the wire.
static func _joins(zone: Dictionary, links: Dictionary,
		door_world: Dictionary, rooms: Dictionary,
		spine_tail: String) -> Dictionary:
	var out := {}
	for raw_edge: Variant in zone.get("edges", []):
		if typeof(raw_edge) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = raw_edge
		if str(edge.get("realization", "JOINED")) != "JOINED":
			continue
		var a := str(edge.get("room_a", ""))
		var b := str(edge.get("room_b", ""))
		var eid := str(edge.get("edge_id", ""))
		# The chain recorded against a room is the one that REACHED it,
		# so the edge's chain is whichever end was placed second.
		var reached := b if links.has(b) and rooms.has(b) else a
		out[eid] = {
			"room_a": a, "room_b": b,
			"socket_a": _socket_for(door_world, a, eid, zone),
			"socket_b": _socket_for(door_world, b, eid, zone),
			"chain": links.get(reached, []),
		}
	# EVERY ROOM WITH A CHAIN GETS A JOIN, even when no edge names it.
	#
	# A Zone that carries no graph has no edge ids at all, and a branch
	# declared in the nested fixture form has none either -- so their
	# corridors existed only in the room-keyed `links`, which is not what
	# goes on the wire. A manifest that cannot rebuild those rooms is not
	# a manifest; it is most of one.
	for rid: String in links:
		if rid == EXIT_ROOM_ID or not rooms.has(rid):
			continue
		var already := false
		for eid: String in out:
			if str((out[eid] as Dictionary).get("room_b", "")) == rid:
				already = true
				break
		if already:
			continue
		# DOORWAY ENDPOINTS, answering AMALGAM_BRIDGE.md 5.4a: yes.
		#
		# This filed `socket_a` as the room's own POSITION and `socket_b`
		# as its ARRIVAL — a point several metres inside — so the two
		# declared ends were not the two ends of the chain, and the
		# bridge had to check this one join by "does the chain arrive"
		# rather than by walking it. That made the first room's approach
		# the one corridor checked more loosely than every other.
		#
		# It has doorway endpoints available and always did: the chain's
		# own first piece is where the corridor starts, and
		# `door_world["<room>/entry"]` is the doorway it arrives at. So
		# it is filed the way `e:__exit__` is and walks like any JOINED
		# edge.
		var chain: Array = links[rid]
		var mouth: Vector3 = (rooms[rid] as Dictionary).get(
				"position", Vector3.ZERO)
		if door_world.has("%s/entry" % rid):
			mouth = door_world["%s/entry" % rid]
		var from: Vector3 = mouth
		if not chain.is_empty() \
				and typeof(chain[0]) == TYPE_DICTIONARY:
			from = (chain[0] as Dictionary).get("entry", mouth)
		out["%s%s" % [ROOM_EDGE_PREFIX, rid]] = {
			"room_a": "", "room_b": rid,
			"socket_a": from, "socket_b": mouth,
			"chain": chain, "synthetic": true}
	# THE EXIT ROOM'S APPROACH IS A JOIN TOO, under the reserved id, so a
	# manifest carries the last leg instead of leaving it to be re-solved.
	if rooms.has(EXIT_ROOM_ID):
		out[EXIT_EDGE_ID] = {
			"room_a": spine_tail, "room_b": EXIT_ROOM_ID,
			"socket_a": door_world.get("%s/exit" % spine_tail,
					(rooms.get(spine_tail, {}) as Dictionary)
						.get("arrival", Vector3.ZERO)),
			"socket_b": (rooms[EXIT_ROOM_ID] as Dictionary)["position"],
			"chain": links.get(EXIT_ROOM_ID, []),
			"synthetic": true,
		}
	return out

## Where a room's door for this edge is, or its arrival if it declares
## none. Never a guess at geometry: the fallback is a point the room
## already committed.
static func _socket_for(door_world: Dictionary, room: String,
		edge_id: String, zone: Dictionary) -> Vector3:
	for raw_chamber: Variant in zone.get("chambers", []):
		if typeof(raw_chamber) != TYPE_DICTIONARY:
			continue
		var chamber: Dictionary = raw_chamber
		if str(chamber.get("id", "")) != room:
			continue
		for raw_door: Variant in chamber.get("doors", []):
			if typeof(raw_door) != TYPE_DICTIONARY:
				continue
			var door: Dictionary = raw_door
			if str(door.get("edge_id", "")) != edge_id:
				continue
			return door_world.get("%s/%s"
					% [room, str(door.get("socket_id", ""))], Vector3.ZERO)
	return Vector3.ZERO

## THE EXIT ROOM IS THE ENGINE'S, and it is named so both lanes agree.
##
## `ChamberBuilders.treasure_room` is appended after the last chamber and
## is declared by nobody: it has no `TopologyEdge`, no `DoorAssignment`
## and no entry in `zone.chambers`. It was still routed by the same
## search as every other room and committed a transform, so a manifest
## that left it out could rebuild the whole Zone and then have to
## re-solve the last leg.
##
## So it is a room with a reserved id and its approach is a join under a
## reserved edge id. Reserved means reserved: a Zone that declares either
## is refused, because two different rooms answering to `exit` is a
## manifest that cannot say which one it committed.
const EXIT_ROOM_ID := "exit"
const EXIT_EDGE_ID := "e:__exit__"

## The key a room's approach is filed under when no edge names it. Also
## reserved: an `edge_id` starting with this is refused for the same
## reason `exit` is.
const ROOM_EDGE_PREFIX := "r:"

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
## HOW MANY TIMES THE PLACEMENT SEARCH HAS BEEN ENTERED.
##
## Law 47c says a replay does not re-solve, and "it produced the same
## transforms" is not that claim -- a solver that redid the work and
## happened to agree would satisfy it. This counts the thing the law
## forbids, so a test can assert the search was never entered at all.
static var searches := 0
static var poses := 0
static var turns_taken := 0
## Candidate poses this plan must step OVER before it accepts one.
## Static because `_search` recurses and a route's candidates are one
## sequence however many frames it is spread across.
static var skip_left := 0

## WHERE A BRANCH LEAVES ITS JUNCTION, and which way it faces.
##
## **The room's own door plan, not the procedural socket table.** Both
## producers emit `doors` in the same shape -- `ChamberBuilders
## .door_plan` from `procedural_sockets`, `ContentInstantiator
## .authored_door_plan` from the shell's declared doorways -- and the
## two disagree for exactly the rooms that matter. This read
## `socket_placed(socket_id, chamber.width, chamber.depth)`, which is
## the procedural table, and an authored shell that answers a 17.9 m
## chamber with a 41 m envelope then puts the branch mouth INSIDE
## itself: the first connector overlapped the junction that was meant
## to be serving it, every route failed at push 0, and the Zone came
## back LAYOUT_INFEASIBLE naming the branch. `09_ROOM_CONTRACT.md`
## §11.4 is where this was written down as a restriction; this lifts it.
##
## **OUTWARD IS DERIVED, NOT READ.** A socket declares a `yaw` and the
## two procedural side sockets declare inward-facing ones, so trusting
## that field would send every branch back through the room it came
## from. The direction from the room's own envelope centre to the
## opening cannot be ambiguous -- and unlike `side_left` / `side_right`
## it is right for a shell whose doorway is somewhere else entirely.
##
## Returns `{"position": room-local Vector3, "turn": radians}`, or empty
## when the room declares no such opening.
static func branch_mouth(build: Dictionary, chamber: Dictionary,
		socket_id: String) -> Dictionary:
	var at := Vector3.INF
	for raw: Variant in build.get("doors", []):
		var door: Dictionary = raw
		if str(door.get("socket_id", "")) == socket_id:
			at = door.get("position", Vector3.ZERO)
			break
	if at == Vector3.INF:
		# A room built before door plans, or one whose build result did
		# not reach here. The table is the old answer and stays the
		# fallback rather than a refusal.
		var table := ChamberBuilders.socket_placed(socket_id,
				float(chamber.get("width", 16.0)),
				float(chamber.get("depth", 16.0)))
		if table.is_empty():
			return {}
		at = table["position"]
	var box: AABB = build.get("bounds", AABB())
	var away := at - (box.position + box.size / 2.0)
	var turn := 0.0
	if absf(away.x) >= absf(away.z):
		turn = -PI / 2.0 if away.x < 0.0 else PI / 2.0
	else:
		turn = PI if away.z < 0.0 else 0.0
	return {"position": at, "turn": turn}

## How much corridor a room's UNROUTED BRANCH DOORS keep for themselves.
##
## A room is placed by asking whether its own envelope clears. That
## question is too small for a room that still owes the graph a branch:
## the envelope cleared, the room was committed, and the space its side
## door opens onto was already a room someone else had placed. Measured,
## not reasoned about -- in three of the four recorded infeasible Zones
## the FIRST connector out of the junction's branch mouth started inside
## a standing room, so the branch search broke at push zero with open
## space two to eleven connectors further on that it could never reach.
## `zone_02` missed by 0.37 m of lateral clip; `zone_03` by 92 cubic
## metres.
##
## Two is the whole reservation: enough corridor to clear the immediate
## neighbourhood and give the branch search a position it can turn from,
## and small enough that it does not become a second, invisible room.
const RESERVED_CONNECTORS := 2

## The corridor a room's declared branch doors will need, in the room's
## OWN frame, so it travels with the room as the search moves it.
##
## Every yaw in this router is a multiple of 90 degrees, so composing the
## socket's turn with the room's placement yaw rotates these boxes
## exactly; nothing is inflated to stay axis-aligned.
static func _socket_reservations(build: Dictionary, chamber: Dictionary,
		sockets: Array, shape: Dictionary) -> Array:
	var out: Array = []
	for _k in RESERVED_CONNECTORS:
		out.append([])
	for raw: Variant in sockets:
		var mouth := branch_mouth(build, chamber, str(raw))
		if mouth.is_empty():
			continue
		var turn := float(mouth["turn"])
		var at: Vector3 = mouth["position"]
		for k in RESERVED_CONNECTORS:
			(out[k] as Array).append(
					_world_aabb(shape["bounds"] as AABB, at, turn))
			at += _rot(turn, shape["exit_offset"] as Vector3)
	return out

## The same promise, made forward along the spine: the corridor the NEXT
## room will arrive down. A room whose envelope clears but whose exit
## opens onto a standing wall has not been placed, it has been wedged --
## and the chain only finds out several rooms later, when there is no
## candidate left anywhere in the bounded space. Reserving the exit stub
## refuses the wedge at the moment it is made, which is the only moment
## the search still has somewhere else to put the room.
static func _exit_reservation(build: Dictionary,
		shape: Dictionary) -> Array:
	var out: Array = []
	var at: Vector3 = build.get("exit_offset", Vector3.ZERO)
	# `exit_yaw` IS DEGREES. The chain reads it through `deg_to_rad`
	# three hundred lines further down; a reservation that forgot to
	# pointed its corridor 90 RADIANS off and reserved empty sky.
	var declared := float(build.get("exit_yaw", 0.0))
	var turn := deg_to_rad(declared) \
			if RoomContract.EXIT_YAWS.has(declared) else 0.0
	for _k in RESERVED_CONNECTORS:
		out.append([_world_aabb(shape["bounds"] as AABB, at, turn)])
		at += _rot(turn, shape["exit_offset"] as Vector3)
	return out

## Two reservation ladders, rung by rung, into one.
##
## MEASURED AND REJECTED: A THIRD RUNG HOLDING THE BRANCH ROOM'S OWN
## ENVELOPE. Reserving where a declared branch shell would stand, rather
## than only the corridor to its door, is the obvious next reservation
## and it is worse. A branch shell can be 39 m deep and 50 m tall in a
## Zone 51 m tall; demanding that much empty space in front of every
## junction that owes a branch pushed the whole spine around to find it.
## The wider sample went from sixteen of twenty to FIFTEEN, and two of
## the five preserved controls stopped laying out. The graded ladder did
## its job -- nothing crashed, the rung was simply dropped -- and the
## Zones it cost were ones whose parents had been placed somewhere
## worse to satisfy a rung that was then dropped anyway.
static func _both_reservations(a: Array, b: Array) -> Array:
	var out: Array = []
	for k in RESERVED_CONNECTORS:
		var rung: Array = []
		if k < a.size():
			rung.append_array(a[k] as Array)
		if k < b.size():
			rung.append_array(b[k] as Array)
		out.append(rung)
	return out

static func _declared_branch_sockets(graph_branches: Dictionary,
		chamber: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in graph_branches.get(
			str(chamber.get("id", "?")), []):
		if typeof(raw) == TYPE_DICTIONARY:
			out.append(str((raw as Dictionary).get("socket_id",
					"side_left")))
	for raw: Variant in chamber.get("branches", []):
		if typeof(raw) == TYPE_DICTIONARY:
			out.append(str((raw as Dictionary).get("socket_id",
					"side_left")))
	return out

## Whether a candidate pose leaves every reserved corridor standing.
## Judged against what was ALREADY THERE, never against the route being
## planned: a reservation is a promise to later rooms, and grazing the
## approach corridor this room arrived down is not a broken one.
static func _reserved_clear(placed: Array, reserve: Array,
		origin: Vector3, yaw: float) -> bool:
	for raw: Variant in reserve:
		if _overlaps(placed, _world_aabb(raw as AABB, origin, yaw)):
			return false
	return true

## PLACEMENT IS TRIED TWICE AND NO MORE. Once demanding that the room's
## unrouted branch doors keep their corridor, and -- only if no pose in
## the whole bounded candidate space satisfies that -- once without.
##
## The second pass is what keeps this a repair rather than a new refusal:
## a reservation that cannot be honoured must not turn a Zone that used
## to lay out into one that does not. Both passes are the same bounded
## search over the same candidates in the same order, so the cost is
## twice a bounded number and the outcome is still decided by geometry.
static func _plan_route(shape: Dictionary, corners: Dictionary,
		room: AABB, entry_at: Vector3, cursor: Vector3, yaw: float,
		placed: Array, prefer: int, reserve: Array = [],
		skip := 0) -> Dictionary:
	poses = 0
	turns_taken = 0
	for depth in range(mini(reserve.size(), RESERVED_CONNECTORS), 0, -1):
		var want: Array = []
		for k in depth:
			want.append_array(reserve[k] as Array)
		if want.is_empty():
			continue
		var kept := _route_once(shape, corners, room, entry_at, cursor,
				yaw, placed, prefer, want, skip)
		if bool(kept["ok"]):
			return kept
	return _route_once(shape, corners, room, entry_at, cursor, yaw,
			placed, prefer, [], skip)

static func _route_once(shape: Dictionary, corners: Dictionary,
		room: AABB, entry_at: Vector3, cursor: Vector3, yaw: float,
		placed: Array, prefer: int, reserve: Array,
		skip: int) -> Dictionary:
	searches += 1
	skip_left = skip
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
					turns_allowed - 1, prefer, budget, reserve,
					[_world_aabb(corner["bounds"], cursor, yaw)])
			if bool(bent["ok"]):
				var route: Array = [{"turn": prefer, "connectors": 0}]
				route.append_array(bent["route"] as Array)
				return {"ok": true, "route": route}
	return _search(shape, corners, room, entry_at, cursor, yaw, placed,
			turns_allowed, prefer, budget, reserve)

static func _search(shape: Dictionary, corners: Dictionary, room: AABB,
		entry_at: Vector3, cursor: Vector3, yaw: float, placed: Array,
		turns_left: int, prefer: int, budget: int, reserve: Array = [],
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
		poses += 1
		var pose := origin_for(at, yaw, entry_at)
		var here := _world_aabb(room, pose, yaw)
		if not _overlaps(_all_but_last(chain), here) \
				and _reserved_clear(placed, reserve, pose, yaw):
			if skip_left <= 0:
				return {"ok": true, "route": [{"turn": 0, "connectors": i}]}
			# A POSE STEPPED OVER, NOT A POSE REFUSED. The search keeps
			# going from here, so the candidate order is the one it
			# always had and the nudge is only ever "take the next one".
			skip_left -= 1
		if turns_left > 0:
			var first := prefer if prefer != 0 else 1
			for turn: int in [first, -first]:
				var corner: Dictionary = corners[turn]
				var corner_box := _world_aabb(corner["bounds"], at, yaw)
				if _overlaps(_all_but_last(chain), corner_box):
					continue
				turns_taken += 1
				var beyond := laid.duplicate()
				beyond.append(corner_box)
				var sub := _search(shape, corners, room, entry_at,
						at + _rot(yaw, corner["exit_offset"] as Vector3),
						yaw + float(turn) * PI / 2.0, placed,
						turns_left - 1, prefer,
						budget if turns_left == 1 else EXPLORE_CONNECTORS,
						reserve, beyond)
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
			# THE TURN, not just the pose. A corner's geometry depends
			# on which way it bends, and a piece recorded without it
			# cannot be rebuilt -- which is how far "the chain is
			# committed" actually went until a replay was written.
			var corner_out := at + _rot(facing,
					corner["exit_offset"] as Vector3)
			# POSE AND ENDPOINTS, in one record.
			#
			# The two lanes needed different things from the same
			# pieces: the engine replays from `position`/`yaw`/`turn`,
			# and the bridge walks socket -> entry, exit -> next entry,
			# last exit -> socket to prove two assigned sockets are
			# actually connected. Absolute transforms make that walk
			# free and prove nothing. One record carries both rather
			# than two payloads disagreeing about the same corridor.
			chain.append({"kind": "CORNER", "position": at,
					"yaw": facing, "bounds": world,
					"turn": int(step["turn"]),
					"entry": at, "exit": corner_out})
			at = corner_out
			facing += float(step["turn"]) * PI / 2.0
			turns += 1
		for _i in int(step["connectors"]):
			var was := at
			at = _emit_connector(root, theme, at, facing, placed,
					bounds_list)
			chain.append({"kind": "CONNECTOR", "position": was,
					"yaw": facing,
					"bounds": bounds_list[bounds_list.size() - 1],
					"entry": was, "exit": at})
	return {"cursor": at, "yaw": facing, "turns": turns}

## LAYS A COMMITTED CHAIN DOWN, without searching for it.
##
## Law 47c: "the layout is solved once and committed... every later load
## replays the committed transforms and does not re-solve." This is the
## replay half, and it is deliberately the only thing in this file that
## can place a piece without asking whether it fits: the question was
## answered when the layout was solved, and asking it again is the
## re-solve the law forbids.
##
## Returns `{cursor, yaw}` like `_emit_route`, read off the last piece so
## a caller that mixes the two cannot tell them apart.
static func _replay_route(root: Node3D, theme: String, chain: Array,
		cursor: Vector3, yaw: float, placed: Array,
		bounds_list: Array) -> Dictionary:
	var at := cursor
	var facing := yaw
	for raw: Variant in chain:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var piece: Dictionary = raw
		at = piece["position"]
		facing = float(piece["yaw"])
		if str(piece.get("kind", "")) == "CORNER":
			var corner := ChamberBuilders.corner(
					int(piece.get("turn", 1)), theme)
			var node: Node3D = corner["root"]
			node.name = "Corner"
			node.position = at
			node.rotation.y = facing
			root.add_child(node)
			placed.append(piece["bounds"])
			bounds_list.append(piece["bounds"])
			at += _rot(facing, corner["exit_offset"] as Vector3)
			facing += float(int(piece.get("turn", 1))) * PI / 2.0
		else:
			var connector := ChamberBuilders.corridor(
					{"id": "conn_%d" % bounds_list.size(),
					"length": CONNECTOR_LENGTH,
					"width": CONNECTOR_WIDTH}, theme)
			var node: Node3D = connector["root"]
			node.name = "Connector"
			node.position = at
			node.rotation.y = facing
			root.add_child(node)
			placed.append(piece["bounds"])
			bounds_list.append(piece["bounds"])
			at += _rot(facing, connector["exit_offset"] as Vector3)
	return {"cursor": at, "yaw": facing, "turns": 0}

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
## `layout` REPLAYS instead of solving. Pass a previous result's `rooms`
## and `links` and the search is never entered: every room goes where the
## manifest says and every connector and corner is laid rather than
## rediscovered. A room the manifest does not mention is still solved, so
## a partial manifest degrades rather than lies.
## How many times a wedged layout may be re-solved with one earlier room
## nudged onto its next candidate pose.
##
## FOUR, AND FOUR IS THE WHOLE LADDER. Each attempt is the same search
## over the same candidates in the same order, with the same seed, the
## same graph and the same shells; the only difference is that one named
## room takes the next pose its own search already offered. That is
## backtracking with the stack written down rather than unwound, and it
## terminates because the ladder is counted, not because it runs out of
## luck.
const MAX_PLACEMENT_NUDGES := 6

## How far ONE room may be nudged before the ladder walks further back.
##
## Nudging the same room over and over is a shallow backtrack, and the
## wider sample showed exactly where it runs out: four Zones wedged on a
## branch, spent all four rungs moving the junction that branch hangs
## off, and failed the same way each time. Past this many, the junction
## is not the room with the choice left in it -- the one before it is.
const PER_ROOM_NUDGES := 2

## The ladder. `_build_once` is one greedy solve; this is the bounded
## retry around it.
##
## A GREEDY ROUTER'S REFUSAL IS NOT A PROOF. `_search` walks forward from
## the cursor and stops at the first connector it cannot lay, so a room
## whose approach is blocked at push zero exhausts a candidate space of
## THREE poses out of a seventy-one connector budget and then reports the
## Zone infeasible. Measured on `zone_02`: `poses tested=3, corners
## entered=0`. What is actually wrong is a room placed several steps
## earlier, and the only honest answer is to go back and put it
## somewhere else.
static func build(zone: Dictionary, theme_override := "",
		budget_ms := 0.0, layout := {}) -> Dictionary:
	var started := Time.get_ticks_msec()
	var nudge := {}
	var attempts := 1
	var out := _build_once(zone, theme_override, budget_ms, layout, nudge)
	# A REPLAY IS NEVER RE-SOLVED. The manifest already says where every
	# room went; nudging one would produce a Zone the player has never
	# been in, with a committed layout's name on it.
	if (layout.get("rooms", {}) as Dictionary).is_empty():
		while attempts <= MAX_PLACEMENT_NUDGES \
				and bool(out.get("wedge", false)):
			var who := _wedged_after(zone, out, nudge)
			if who == "":
				break
			var spent := float(Time.get_ticks_msec() - started)
			if budget_ms > 0.0 and spent >= budget_ms:
				break
			nudge[who] = int(nudge.get(who, 0)) + 1
			attempts += 1
			out = _build_once(zone, theme_override,
					maxf(budget_ms - spent, 1.0) if budget_ms > 0.0
					else 0.0, layout, nudge)
	out["placement_attempts"] = attempts
	out["placement_nudges"] = nudge
	out["placement_ms"] = float(Time.get_ticks_msec() - started)
	return out

## The room whose pose to nudge: the one the wedged room was joined to,
## and then, once that room has had its turns, the one before IT.
##
## For a spine room the join is its predecessor on the spine; for a
## branch it is the junction the branch hangs off, because that is where
## the mouth is and moving the branch means moving the mouth. From there
## the ladder walks backwards along the spine past every room that has
## already spent its `PER_ROOM_NUDGES`, which is what makes this a
## backtrack rather than four tries at the same room.
static func _wedged_after(zone: Dictionary, out: Dictionary,
		nudge: Dictionary) -> String:
	var blocking: Array = out.get("blocking_rooms", [])
	if blocking.is_empty():
		return ""
	var stuck := str(blocking[0])
	var graph := placement_plan(zone)
	var spine: Array = graph.get("spine", [])
	var at := -1
	for i in spine.size():
		if str(spine[i]) == stuck:
			at = i - 1
			break
	if at < 0 and not spine.has(stuck):
		var branches: Dictionary = graph.get("branches", {})
		for parent_id: Variant in branches:
			for raw: Variant in (branches[parent_id] as Array):
				if typeof(raw) != TYPE_DICTIONARY:
					continue
				var kid: Dictionary = (raw as Dictionary).get(
						"chamber", {})
				if str(kid.get("id", "")) != stuck:
					continue
				for i in spine.size():
					if str(spine[i]) == str(parent_id):
						at = i
	while at >= 0:
		var who := str(spine[at])
		if int(nudge.get(who, 0)) < PER_ROOM_NUDGES:
			return who
		at -= 1
	return ""

static func _build_once(zone: Dictionary, theme_override := "",
		budget_ms := 0.0, layout := {}, nudge := {}) -> Dictionary:
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
	for raw_chamber: Variant in zone.get("chambers", []):
		if typeof(raw_chamber) == TYPE_DICTIONARY \
				and str((raw_chamber as Dictionary).get("id", "")) \
					== EXIT_ROOM_ID:
			return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
					"policy": routing_policy([], policy_override),
					"blocking_rooms": [EXIT_ROOM_ID],
					"blocking_pairs": [],
					"failed": "a chamber is named '%s', which is "
					% EXIT_ROOM_ID + "reserved for the engine's appended "
					+ "exit room; two rooms answering to it makes a "
					+ "manifest that cannot say which one it committed"}
	for raw_edge: Variant in zone.get("edges", []):
		if typeof(raw_edge) == TYPE_DICTIONARY \
				and (str((raw_edge as Dictionary).get("edge_id", ""))
					== EXIT_EDGE_ID
					or str((raw_edge as Dictionary).get("edge_id", ""))
						.begins_with(ROOM_EDGE_PREFIX)):
			return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
					"policy": routing_policy([], policy_override),
					"blocking_rooms": [], "blocking_pairs": [],
					"failed": "an edge is named '%s', which is reserved "
					% EXIT_EDGE_ID + "for the approach to the engine's "
					+ "appended exit room"}
	# A MANIFEST THAT DID NOT DECODE IS NOT A MANIFEST.
	#
	# Refused here, before a room is produced and before the replay path
	# can fall back to searching: the alternative is rebuilding part of a
	# Zone from data that was missing and part of it from a fresh solve,
	# which is a place the player has never been with a LAYOUT_OK on it.
	if str(layout.get("malformed", "")) != "":
		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy([], policy_override),
				"blocking_rooms": [], "blocking_pairs": [],
				"failed": "the committed manifest did not decode: %s"
				% str(layout["malformed"])}
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
	## "room/socket" -> where that declared door is, in world space.
	var door_world := {}
	## Rooms whose declared keys no producer reserved space for.
	var dropped_keys: Array = []
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

	# THE GRAPH DECIDES THE ORDER, when the Zone carries one.
	#
	# `placement_plan` reads `edges` and each chamber's `doors` and says
	# which rooms are the spine and which hang off a side socket. A Zone
	# with no edges gets its chamber list back unchanged, which is the
	# chain that shipped before.
	var graph := placement_plan(zone)
	if str(graph.get("refused", "")) != "":
		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy([], policy_override),
				"blocking_rooms": [], "blocking_pairs": [],
				"failed": str(graph["refused"])}
	var chamber_by_id := {}
	for raw_chamber: Variant in zone.get("chambers", []):
		if typeof(raw_chamber) == TYPE_DICTIONARY:
			chamber_by_id[str((raw_chamber as Dictionary).get("id", ""))] \
					= raw_chamber
	var graph_branches: Dictionary = graph.get("branches", {})
	for spine_id: Variant in graph.get("spine", []):
		var chamber: Dictionary = chamber_by_id.get(str(spine_id), {})
		if chamber.is_empty():
			continue
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
		var committed: Dictionary = (layout.get("rooms", {}) as Dictionary) \
				.get(str(chamber.get("id", "?")), {})
		# A MANIFEST THAT IS PRESENT MUST BE COMPLETE.
		#
		# Falling back to the search for a room the manifest does not
		# mention is the silent failure: a revisited Zone would be part
		# replayed and part re-solved, and the part that was re-solved is
		# a different place than the player remembers -- with a
		# LAYOUT_OK on it. A manifest is either what this Zone is, or it
		# is refused by name.
		var replaying := not committed.is_empty()
		if not replaying and not (layout.get("rooms", {}) as Dictionary) \
				.is_empty():
			(result["root"] as Node3D).free()
			root.free()
			return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
					"policy": routing_policy(placed, policy_override),
					"blocking_rooms": [str(chamber.get("id", "?"))],
					"blocking_pairs": [],
					"failed": "the committed manifest has no transform "
					+ "for room '%s'; a partial manifest would replay "
					% str(chamber.get("id", "?"))
					+ "part of the Zone and re-solve the rest"}
		var plan := {"ok": true} if replaying \
				else _plan_route(shape, corners, result["bounds"] as AABB,
						entry_at, cursor, yaw, placed, prefer,
						_both_reservations(
								_socket_reservations(result, chamber,
										_declared_branch_sockets(
												graph_branches, chamber),
										shape),
								_exit_reservation(result, shape)),
						int(nudge.get(str(chamber.get("id", "?")), 0)))
		# NO ROOM IS EVER ATTACHED ON TOP OF ANOTHER. Straight ahead and
		# both corners were tried, connectors included, and none of them
		# clears. A Zone with a room inside another room is a Check in a
		# wall and an enemy inside the floor; there is no version of that
		# worth returning, so the build FAILS and the caller decides.
		if not bool(plan["ok"]):
			if OS.get_cmdline_user_args().has("--router-diag"):
				print("  DIAG spine %s: cursor=%v yaw=%.0f room=%v entry=%v"
						% [str(chamber.get("id", "?")), cursor,
							rad_to_deg(yaw),
							(result["bounds"] as AABB).size, entry_at])
				print("       budget=%d poses tested=%d corners entered=%d"
						% [int(routing_policy(placed,
								policy_override)["clearance_budget"]),
							poses, turns_taken])
				var _seen: Array = _all_but_last(placed)
				var _at := cursor
				for _i in 14:
					var _pose := origin_for(_at, yaw, entry_at)
					var _here := _world_aabb(
							result["bounds"] as AABB, _pose, yaw)
					var _link := _world_aabb(
							shape["bounds"] as AABB, _at, yaw)
					print("       step %d room_fits=%s link_fits=%s"
							% [_i, str(not _overlaps(_seen, _here)),
								str(not _overlaps(_seen, _link))])
					if not _overlaps(_seen, _here):
						break
					_seen.append(_link)
					_at += _rot(yaw, shape["exit_offset"] as Vector3)
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
					"wedge": true,
					"failed": "room '%s' could not be placed clear of "
					% str(chamber.get("id", "?"))
					+ "the %d room(s) before it" % placed.size()}
		# A REPLAY HAS NO SEARCH TO TIME OUT. The budget bounds the
		# placement SOLVE; a Zone being laid down from a manifest has
		# already been solved, and reporting LAYOUT_TIMEOUT for it would
		# say the search space was not exhausted when no search ran.
		if not replaying and budget_ms > 0.0 \
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
		var walked: Dictionary
		if replaying:
			# The whole chain comes from the manifest, the carried piece
			# included -- it was recorded INTO this room's chain when the
			# layout was committed, so replaying it twice would double it.
			link = committed_chain(layout, chamber)
			var bad := malformed_pieces(link)
			if bad != "":
				(result["root"] as Node3D).free()
				root.free()
				return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
						"policy": routing_policy(placed, policy_override),
						"blocking_rooms": [str(chamber.get("id", "?"))],
						"blocking_pairs": [],
						"failed": "the committed approach to room '%s' "
						% str(chamber.get("id", "?")) + "cannot be "
						+ "rebuilt: %s" % bad}
			walked = _replay_route(root, theme, link, cursor, yaw,
					placed, bounds_list)
		else:
			walked = _emit_route(root, theme, plan, cursor, yaw, placed,
					bounds_list, link)
		links[str(chamber.get("id", "?"))] = link
		cursor = walked["cursor"]
		yaw = float(walked["yaw"])
		if int(walked["turns"]) % 2 == 1:
			next_turn = -next_turn

		var origin: Vector3 = committed["position"] if replaying \
				else origin_for(cursor, yaw, entry_at)
		if replaying:
			yaw = float(committed["yaw"])
		var node: Node3D = result["root"]
		node.name = "Chamber_%s" % chamber.get("id", "c")
		node.position = origin
		node.rotation.y = yaw
		var rid := str(chamber.get("id", "?"))
		var footprint := _furnish_room(root, theme, chamber, result,
				origin, yaw, anchors, room_transforms, keys, locks,
				stations, dropped_keys, door_world)
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
		#
		# A QUEUE, NOT A LOOP OVER ONE LIST. A branch is a room, and a
		# room may branch -- a gated dead end whose far end holds the key
		# to a second gated dead end is the owner's own shape, and a flat
		# loop over `chamber.branches` could not build it: the branch's
		# own `branches` were read by nothing. Each placed branch pushes
		# its children on, so depth is whatever the Zone declares.
		var pending: Array = []
		# TWO SOURCES, ONE QUEUE. `edges` + `doors` is what the bridge
		# sends; the nested `branches` form is what a fixture can write
		# without a graph. Neither is special-cased downstream.
		for raw_branch: Variant in graph_branches.get(rid, []):
			pending.append({"from": chamber, "at": origin, "yaw": yaw,
					"build": result, "branch": raw_branch})
		for raw_branch: Variant in chamber.get("branches", []):
			if typeof(raw_branch) == TYPE_DICTIONARY:
				pending.append({"from": chamber, "at": origin,
						"yaw": yaw, "build": result,
						"branch": raw_branch})
		while not pending.is_empty():
			var job: Dictionary = pending.pop_front()
			var parent: Dictionary = job["from"]
			var p_origin: Vector3 = job["at"]
			var p_yaw: float = float(job["yaw"])
			var branch: Dictionary = job["branch"]
			var b_chamber: Dictionary = branch.get("chamber", {})
			if b_chamber.is_empty():
				continue
			var socket_id := str(branch.get("socket_id", "side_left"))
			var mouth := branch_mouth(job.get("build", {}), parent,
					socket_id)
			if mouth.is_empty():
				push_warning("zone: branch on unknown socket '%s'"
						% socket_id)
				continue
			var b_yaw := p_yaw + float(mouth["turn"])
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
			var b_id_early := str(b_chamber.get("id", "branch"))
			var b_committed: Dictionary = \
					(layout.get("rooms", {}) as Dictionary) \
					.get(b_id_early, {})
			var b_replaying := not b_committed.is_empty()
			if not b_replaying and not (layout.get("rooms", {})
					as Dictionary).is_empty():
				(b_result["root"] as Node3D).free()
				(result["root"] as Node3D).free()
				root.free()
				return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
						"policy": routing_policy(placed, policy_override),
						"blocking_rooms": [b_id_early],
						"blocking_pairs": [],
						"failed": "the committed manifest has no "
						+ "transform for branch room '%s'" % b_id_early}
			var b_link: Array = []
			var mouth_at: Vector3 = p_origin \
					+ _rot(p_yaw, mouth["position"] as Vector3)
			var b_cursor := mouth_at
			# A REPLAYED BRANCH LAYS ITS CHAIN DOWN, bridging connector
			# and all. The bridging connector is part of the committed
			# chain -- it was recorded there when the layout was solved --
			# so emitting one here as well would lay it twice.
			if not b_replaying:
				b_cursor = _emit_connector(root, theme, mouth_at,
						b_yaw, placed, bounds_list)
				b_link.append({"kind": "CONNECTOR", "position": mouth_at,
						"yaw": b_yaw, "bounds": _world_aabb(
								shape["bounds"] as AABB, mouth_at, b_yaw),
						"entry": mouth_at, "exit": b_cursor})
			var b_plan := {"ok": true} if b_replaying \
					else _plan_route(shape, corners,
							b_result["bounds"] as AABB, b_entry, b_cursor,
							b_yaw, placed, 0,
							_socket_reservations(b_result, b_chamber,
									_declared_branch_sockets(
											graph_branches, b_chamber),
									shape))
			if not bool(b_plan["ok"]):
				if OS.get_cmdline_user_args().has("--router-diag"):
					var _span: AABB = placed[0]
					for _b: AABB in placed:
						_span = _span.merge(_b)
					print("  DIAG %s off %s: mouth=%v yaw=%.0f room=%v"
							% [str(b_chamber.get("id", "?")),
								str(parent.get("id", "?")), b_cursor,
								rad_to_deg(b_yaw),
								(b_result["bounds"] as AABB).size])
					print("       placed=%d span=%v..%v"
							% [placed.size(), _span.position,
								_span.position + _span.size])
					var _seen: Array = _all_but_last(placed)
					var _at := b_cursor
					for _i in 12:
						var _here := _world_aabb(
								b_result["bounds"] as AABB,
								origin_for(_at, b_yaw, b_entry), b_yaw)
						var _link := _world_aabb(
								shape["bounds"] as AABB, _at, b_yaw)
						print("       step %d room_fits=%s link_fits=%s"
								% [_i,
									str(not _overlaps(_seen, _here)),
									str(not _overlaps(_seen, _link))])
						if not _overlaps(_seen, _here):
							break
						_seen.append(_link)
						_at += _rot(b_yaw, shape["exit_offset"] as Vector3)
				(b_result["root"] as Node3D).free()
				(result["root"] as Node3D).free()
				root.free()
				return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
						"policy": routing_policy(placed, policy_override),
						"blocking_rooms": [str(b_chamber.get("id", "?"))],
						"blocking_pairs": [],
						"wedge": true,
						"failed": "branch room '%s' off '%s' could not "
						% [str(b_chamber.get("id", "?")),
							str(parent.get("id", "?"))]
						+ "be placed clear of the %d room(s) already "
						% placed.size() + "standing"}
			var b_walked: Dictionary
			if b_replaying:
				b_link = committed_chain(layout, b_chamber)
				var b_bad := malformed_pieces(b_link)
				if b_bad != "":
					(b_result["root"] as Node3D).free()
					(result["root"] as Node3D).free()
					root.free()
					return {"status": "LAYOUT_INFEASIBLE",
							"exhausted": true,
							"policy": routing_policy(placed,
									policy_override),
							"blocking_rooms": [b_id_early],
							"blocking_pairs": [],
							"failed": "the committed approach to branch "
							+ "room '%s' cannot be rebuilt: %s"
							% [b_id_early, b_bad]}
				b_walked = _replay_route(root, theme, b_link, b_cursor,
						b_yaw, placed, bounds_list)
			else:
				b_walked = _emit_route(root, theme, b_plan, b_cursor,
						b_yaw, placed, bounds_list, b_link)
			var b_origin: Vector3 = b_committed["position"] \
					if b_replaying \
					else origin_for(b_walked["cursor"],
							float(b_walked["yaw"]), b_entry)
			if b_replaying:
				b_walked["yaw"] = float(b_committed["yaw"])
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
					keys, locks, stations, dropped_keys, door_world)
			# ITS OWN BRANCHES, from the transform it was just given,
			# from either source.
			for raw_deeper: Variant in graph_branches.get(
					str(b_chamber.get("id", "")), []):
				pending.append({"from": b_chamber, "at": b_origin,
						"yaw": float(b_walked["yaw"]),
						"build": b_result, "branch": raw_deeper})
			for raw_deeper: Variant in b_chamber.get("branches", []):
				if typeof(raw_deeper) == TYPE_DICTIONARY:
					pending.append({"from": b_chamber, "at": b_origin,
							"yaw": float(b_walked["yaw"]),
							"build": b_result, "branch": raw_deeper})
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
		# NOT WHILE REPLAYING. This connector was recorded into the NEXT
		# room's chain when the layout was committed, so emitting it here
		# as well would lay it twice -- once from the manifest and once
		# from this arithmetic.
		if not replaying and not _overlaps(placed,
				_world_aabb(shape["bounds"], cursor, yaw)):
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
					"bounds": bounds_list[bounds_list.size() - 1],
					"entry": was, "exit": cursor})
		first = false

	# Exit room with the appended portal — routed like every other
	# placement, not trusted to clear by arithmetic coincidence. A Zone
	# whose exit sits inside another room is one a player cannot finish,
	# so this fails the build for the same reason a chamber does.
	if not dropped_keys.is_empty():
		root.free()
		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy(placed, policy_override),
				"blocking_rooms": [], "blocking_pairs": [],
				"failed": "%d room(s) declare a key their producer does "
				% dropped_keys.size() + "not build, so a lock in this "
				+ "Zone has no key: %s" % str(dropped_keys)}
	# The last room on the spine, which is what the exit room hangs off.
	var spine_tail := ""
	for spine_id: Variant in graph.get("spine", []):
		if chamber_by_id.has(str(spine_id)):
			spine_tail = str(spine_id)
	var exit_room := ChamberBuilders.treasure_room(
			{"id": EXIT_ROOM_ID}, theme)
	var exit_committed: Dictionary = \
			(layout.get("rooms", {}) as Dictionary).get(EXIT_ROOM_ID, {})
	var exit_replaying := not exit_committed.is_empty()
	var exit_plan := {"ok": true} if exit_replaying \
			else _plan_route(shape, corners,
					exit_room["bounds"] as AABB,
					RoomContract.LEGACY_ENTRY, cursor, yaw, placed, 0)
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
	var exit_walk: Dictionary
	if exit_replaying:
		exit_link = (((layout.get("joins", {}) as Dictionary)
				.get(EXIT_EDGE_ID, {}) as Dictionary)
				.get("chain", []) as Array).duplicate()
		var exit_bad := malformed_pieces(exit_link)
		if exit_bad != "":
			root.free()
			return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
					"policy": routing_policy(placed, policy_override),
					"blocking_rooms": [EXIT_ROOM_ID], "blocking_pairs": [],
					"failed": "the committed approach to the exit room "
					+ "cannot be rebuilt: %s" % exit_bad}
		exit_walk = _replay_route(root, theme, exit_link, cursor, yaw,
				placed, bounds_list)
	else:
		exit_walk = _emit_route(root, theme, exit_plan, cursor, yaw,
				placed, bounds_list, exit_link)
	links[EXIT_ROOM_ID] = exit_link
	cursor = exit_committed["position"] if exit_replaying \
			else exit_walk["cursor"]
	yaw = float(exit_committed["yaw"]) if exit_replaying \
			else float(exit_walk["yaw"])
	var exit_node: Node3D = exit_room["root"]
	exit_node.name = "ExitRoom"
	exit_node.position = cursor
	exit_node.rotation.y = yaw
	root.add_child(exit_node)
	var exit_world: AABB = _world_aabb(exit_room["bounds"], cursor, yaw)
	placed.append(exit_world)
	bounds_list.append(exit_world)
	room_transforms[EXIT_ROOM_ID] = {"position": cursor, "yaw": yaw,
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
	# THE VALIDATOR'S OWN OVERLAP RULE, ASKED BEFORE THE LAYOUT IS
	# CLAIMED. `_overlaps` above tolerates half a cubic metre so a room's
	# inset entry socket can swallow a little of the connector it joins;
	# `layout.py` tolerates a MILLIMETRE on every axis and refuses the
	# whole manifest. A thin, wide intersection sits inside the first
	# tolerance and outside the second, and the router then returns
	# LAYOUT_OK for a proposal the bridge will not take -- measured on
	# the declared sample: `zone_10`'s c008/c018 and `zone_12`'s
	# c005/c006. Reported as a wedge so the placement ladder re-solves
	# it, which is the machinery that already exists for "this room is
	# in the wrong place".
	var touching := _rooms_that_overlap(room_transforms)
	if not touching.is_empty() \
			and (layout.get("rooms", {}) as Dictionary).is_empty():
		root.free()
		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy(placed, policy_override),
				"blocking_rooms": [str(touching[1])],
				"blocking_pairs": [touching], "wedge": true,
				"failed": "rooms '%s' and '%s' overlap by more than the "
				% [str(touching[0]), str(touching[1])]
				+ "bridge will accept, so this layout would be refused"}
	return {"root": root, "spawn_transform": spawn,
			"chambers": built_chambers, "exit_portal": portal,
			"bounds_list": bounds_list,
			# THE WHOLE LAYOUT, not just where the rooms are. `links`
			# holds the connector and corner chain that reaches each
			# room, in build order, so a committed Zone replays by
			# laying pieces down rather than by searching again.
			"status": "LAYOUT_OK", "rooms": room_transforms,
			"links": links,
			"joins": _joins(zone, links, door_world, room_transforms,
					spine_tail),
			"doors": door_world,
			"anchors": anchors, "plugs": plugs,
			"keys": keys, "locks": locks, "stations": stations}
