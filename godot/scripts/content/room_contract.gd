class_name RoomContract
extends RefCounted
## What a room OUTPUT is, whoever produced it (P1).
##
## THE ASYMMETRY THIS CLOSES. `ChamberBuilders` and `_from_authored_scene`
## both answer the same question -- "build me this chamber" -- and until
## now they answered it with different amounts of truth. A procedural
## arena vouched for its walkable surfaces, its no-build regions, its
## cover points and its elevated stances; an authored shell returned no
## `sockets` key at all, so `Activities` flat-solved against bounds. That
## is the same bug class `552469d` closed for `platform_path`, waiting in
## the one path no Zone takes yet. Fixing it AFTER the first authored
## shell ships would mean fixing it in a Zone the player is standing in.
##
## So the contract is not a new language. It is the dictionary both
## producers already return, written down, with every key named and every
## socket kind tied to a consumer that exists TODAY. Nothing speculative
## lives here: a kind with no consumer is a kind nobody can be held to.
##
## THIS FILE IS STRUCTURE ONLY. It answers "is this shaped like a room" --
## keys, types, closed vocabularies, finite numbers, things inside the
## bounds they claim. Whether the geometry is REALLY there is
## `room_audit.gd`, which measures it with physics. Both halves are
## needed and neither substitutes for the other: a socket can be
## perfectly well-formed and sit inside a wall.

## Keys every room output carries, and what reads them.
##
##   root             Node3D    the chamber, unparented
##   bounds           AABB      room-local envelope, floor slab included
##   exit_offset      Vector3   where the next room's entry attaches
##   room_height      float     ceiling height above the walking plane
##   enemy_spawns     Array     [{archetype, position}]
##   reward_position  Vector3   where the Check pedestal goes
##
## `goal_area_position` and `features` are OPTIONAL and stay optional:
## only some rooms end a Zone and only corridors host affordances.
const REQUIRED := {
	"root": TYPE_OBJECT,
	"bounds": TYPE_AABB,
	"exit_offset": TYPE_VECTOR3,
	"room_height": TYPE_FLOAT,
	"enemy_spawns": TYPE_ARRAY,
	"reward_position": TYPE_VECTOR3,
}

## The physical truths a producer may vouch for, and the consumer of each.
##
## CLOSED, and closed on purpose. Every kind here is read by something
## that runs today; the study's speculative kinds (machinery, container,
## hazard, reward pocket, vista, presentation) are deliberately absent and
## arrive with the systems that would consume them, not before.
##
##   stand      a walkable top face          Activities._best_surface
##   reserved   a volume nothing may occupy  ContentInstantiator occupancy
##   cover      ground point for a crate     _build_environment
##   reactive   ground point for a barrel    _build_environment
##   enemy_high an elevated ranged stance    arena enemy placement
##   access     the walkable way onto a band audits, band reachability
const SOCKET_KINDS := ["stand", "reserved", "cover", "reactive",
		"enemy_high", "access"]

## Kinds whose `extent` is load bearing: a claim about an AREA or a
## VOLUME is meaningless without one, and a zero extent reserves nothing
## and offers nowhere to stand.
const SIZED_KINDS := ["stand", "reserved"]

## Kinds that are a single point on the ground for one object.
const POINT_KINDS := ["cover", "reactive", "enemy_high"]

## How far outside its own bounds a socket may sit. A `stand` surface's
## rect can touch the wall it abuts, and the floor slab reaches
## `FLOOR_ALLOWANCE` below the walking plane.
const BOUNDS_SLACK := 0.35

## An OPTIONAL declaration, in the same shape `TraversalSegment` uses in
## `content.py`: {name, kind: gap|rise|drop|walk, mandatory, start, end}.
##
## Optional because most rooms have nothing to say here -- an arena's
## route is "walk" and saying so buys nobody anything. A room with a
## MANDATORY jump on the only way through has a great deal to say, and
## `platform_path` is the procedural producer that has always had it and
## never said it out loud. Authored shells declare theirs in the
## manifest. Both are measured by the same audit against the same
## `max_safe_gap`, which is the whole point of writing one contract.
const TRAVERSAL_KINDS := ["gap", "rise", "drop", "walk"]

## OPTIONAL, and in DEGREES: how far the room turns the chain on its way
## out (P2-B). Absent or 0 is straight through, which is what every
## producer has always done.
##
## The closed set is not fussiness. `ZoneBuilder` walks a cursor and a
## yaw, and its overlap guard, its connector grammar and its
## never-revisit proof are all written for quarter turns; an arbitrary
## angle is the topology slice's problem, not a corner shell's.
const EXIT_YAWS := [-90.0, 0.0, 90.0]

## WHAT A LARGE ROOM OFFERS A MOVEMENT PACKAGE (P3.0).
##
## `sockets` answers "where may a thing be PUT" -- a point or a rect, for
## a composer placing one object. A large open volume has a different
## thing to say: here is a ROUTE, or a region a traversal mechanic may be
## built from. A rail is an ordered path, and no socket has ever carried
## one.
##
## AN OFFER IS NOT AN ORDER, and that is the whole seam. A shell that
## declares a rail route has not built a rail; it has said a rail could
## go here. A package may consume the offers it understands, must
## validate whatever it builds, and may decline every one of them -- the
## same room has to work as ordinary combat space with no traversal
## mechanic in it at all. Nothing about the mechanic is baked into the
## shell.
##
## CLOSED, AND SHORT, for the reason `SOCKET_KINDS` is: a kind with no
## consumer is a kind nobody can be held to. Three kinds ship here
## because three consumers ship here.
##
##   rail_route     an ordered 3D path a rail may be built along
##   launch_source  a place a directed launch may fire FROM
##   launch_target  a landing region a launch may be aimed AT
##   grapple_point  a place where reaching UP and ACROSS is spatially
##                  appropriate (P3.5)
##
## `platform_route` and `wind_column` are the named next arrivals and
## are deliberately ABSENT: they arrive with the packages that read
## them, through this same key, needing no new grammar. That is what
## makes this a seam rather than a taxonomy.
##
## WHY `grapple_point` IS A PLACE AND NOT A MECHANIC. The shell says
## "somebody could get up there from down here"; it does not say
## hookshot, or tether, or swing, or grapple, because it does not know
## what game it is in. The same anchor is a Zelda hookshot target, a
## swing point, a pull-to anchor, or nothing at all -- and Epsilon
## decides that from the vocabulary the generated game actually has.
## What the contract owes in exchange is enough geometry to prove the
## opportunity is REAL: an anchor in clear air, room under it to hang or
## swing, and ground within reach to leave from or arrive at. A place
## nobody could use is not an opportunity, whatever it is called.
const OFFER_KINDS := ["rail_route", "launch_source", "launch_target",
		"grapple_point"]

## Offers that are a ROUTE: an ordered `points` array, two or more.
const ROUTE_OFFERS := ["rail_route"]

## Offers that are a REGION: a `position` and a `radius` the consumer
## must fit inside.
const REGION_OFFERS := ["launch_source", "launch_target",
		"grapple_point"]

## THE ROOM ENVELOPE: how far outside its declared bounds a room's own
## geometry may physically reach.
##
## ONE WALL THICKNESS, and it is a measurement rather than a courtesy.
## A room's boundary wall belongs to the room, and where a producer puts
## that wall's centreline relative to its declared box is that producer's
## own convention -- both of the ones in this project differ:
##
##   * `ChamberBuilders._perimeter` CENTRES its walls on the boundary, so
##     every procedural room overhangs by WALL_THICKNESS / 2 = 0.20 m on
##     all four sides. Measured, not assumed: corridor, arena,
##     platform_path, tower and treasure room all do it.
##   * the authored shells put their walls entirely INSIDE the box on
##     three sides and entirely BEHIND the origin on the fourth, so their
##     entry wall occupies z in [-0.40, 0] -- a full WALL_THICKNESS.
##
## Both are self-consistent and both chain correctly. What must never
## happen is geometry a whole wall PAST the boundary, because that is
## inside the neighbour's interior rather than inside the shared wall
## plane.
##
## THIS WAS A REAL DEFECT. `ShellValidator._check_envelope` allowed
## 0.15 m and ran on the AUTHORED PATH ALONE, so it refused all eight P2
## shells while every procedural room broke the same rule by 0.05 m and
## was never asked. A convention that describes neither producer is not
## a convention; a check that only one producer takes is not a contract.
const WALL_ALLOWANCE := ChamberBuilders.WALL_THICKNESS + 0.15

## The box a room's geometry must fit inside, from the box it declares.
static func envelope(bounds: AABB) -> AABB:
	return bounds.grow(WALL_ALLOWANCE)

## Every way this room output is malformed. Empty is the contract.
##
## Structure only, and it says so twice because the temptation is to let
## a structural pass stand in for a physical one. It cannot: this
## function would accept a `stand` socket in the middle of the sky.
static func violations(result: Variant, who := "room") -> Array[String]:
	var out: Array[String] = []
	if typeof(result) != TYPE_DICTIONARY:
		out.append("%s: produced no room dictionary at all" % who)
		return out
	var room: Dictionary = result

	for key: String in REQUIRED:
		if not room.has(key):
			out.append("%s: no '%s'; every room output carries one"
					% [who, key])
			continue
		var want: int = REQUIRED[key]
		var got := typeof(room[key])
		# Godot narrows a whole-number float to int on the way through a
		# Dictionary, so a room height of exactly 6 arrives as an int.
		if want == TYPE_FLOAT and got == TYPE_INT:
			continue
		if got != want:
			out.append("%s: '%s' is %d, not %d"
					% [who, key, got, want])
	if not out.is_empty():
		return out

	if not (room["root"] is Node3D):
		out.append("%s: 'root' is not a Node3D" % who)
	var bounds: AABB = room["bounds"]
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		out.append("%s: bounds %v have no volume" % [who, bounds.size])
	if not _finite(room["exit_offset"]):
		out.append("%s: exit_offset is not a finite position" % who)
	if not _finite(room["reward_position"]):
		out.append("%s: reward_position is not a finite position" % who)

	for spawn: Variant in room["enemy_spawns"] as Array:
		if typeof(spawn) != TYPE_DICTIONARY:
			out.append("%s: an enemy spawn is not a dictionary" % who)
			continue
		var s: Dictionary = spawn
		if not s.has("archetype") or not s.has("position"):
			out.append("%s: an enemy spawn is missing archetype or "
					% who + "position")
		elif not _finite(s["position"]):
			out.append("%s: enemy spawn '%s' has no finite position"
					% [who, str(s["archetype"])])

	if room.has("exit_yaw"):
		var yaw := float(room["exit_yaw"])
		if not EXIT_YAWS.has(yaw):
			out.append("%s: exit_yaw %.1f is not a quarter turn (%s)"
					% [who, yaw, ", ".join(EXIT_YAWS.map(
						func(y: float) -> String: return "%.0f" % y))])

	out.append_array(_socket_violations(room, bounds, who))
	out.append_array(_traversal_violations(room, who))
	out.append_array(_offer_violations(room, who))
	return out

static func _socket_violations(room: Dictionary, bounds: AABB,
		who: String) -> Array[String]:
	var out: Array[String] = []
	var sockets: Variant = room.get("sockets", [])
	if typeof(sockets) != TYPE_ARRAY:
		out.append("%s: 'sockets' is present and is not an Array" % who)
		return out
	var roomy := bounds.grow(BOUNDS_SLACK)
	for socket: Variant in sockets as Array:
		if typeof(socket) != TYPE_DICTIONARY:
			out.append("%s: a socket is not a dictionary" % who)
			continue
		var s: Dictionary = socket
		var kind := str(s.get("kind", ""))
		if not SOCKET_KINDS.has(kind):
			out.append("%s: socket kind '%s' is not in the contract (%s)"
					% [who, kind, ", ".join(SOCKET_KINDS)])
			continue
		if not s.has("position") or not _finite(s.get("position")):
			out.append("%s: a '%s' socket has no finite position"
					% [who, kind])
			continue
		var at: Vector3 = s["position"]
		if not roomy.has_point(at):
			out.append("%s: a '%s' socket at %v is outside the room's "
					% [who, kind, at] + "own bounds")
		if SIZED_KINDS.has(kind):
			var extent: Variant = s.get("extent")
			if typeof(extent) != TYPE_VECTOR3:
				out.append("%s: a '%s' socket declares no extent; the "
						% [who, kind] + "claim is about an area")
			elif kind == "stand" and ((extent as Vector3).x <= 0.0
					or (extent as Vector3).z <= 0.0):
				out.append("%s: a 'stand' socket at %v has no walkable "
						% [who, at] + "area (%v)" % extent)
			elif kind == "reserved" and ((extent as Vector3).x <= 0.0
					or (extent as Vector3).y <= 0.0
					or (extent as Vector3).z <= 0.0):
				out.append("%s: a 'reserved' socket at %v reserves no "
						% [who, at] + "volume (%v)" % extent)
		if kind == "access":
			if not ["x", "z"].has(str(s.get("along", ""))):
				out.append("%s: an 'access' socket must say which axis "
						% who + "it runs along")
			if float(s.get("length", 0.0)) <= 0.0:
				out.append("%s: an 'access' socket has no length" % who)
	return out

## An offer that is malformed is an offer no package can act on.
##
## STRUCTURE ONLY, like everything else here. That a declared rail route
## is a shape a rider can hold is `RailPath.violations`, and that its
## geometry is really there is `RoomAudit` -- three checks, because a
## route can be well formed, legal AND hanging in a wall.
static func _offer_violations(room: Dictionary,
		who: String) -> Array[String]:
	var out: Array[String] = []
	var declared: Variant = room.get("offers", [])
	if typeof(declared) != TYPE_ARRAY:
		out.append("%s: 'offers' is present and is not an Array" % who)
		return out
	for entry: Variant in declared as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			out.append("%s: an offer is not a dictionary" % who)
			continue
		var offer: Dictionary = entry
		var kind := str(offer.get("kind", ""))
		if not OFFER_KINDS.has(kind):
			out.append("%s: offer kind '%s' is not in the contract (%s)"
					% [who, kind, ", ".join(OFFER_KINDS)])
			continue
		if ROUTE_OFFERS.has(kind):
			var points: Variant = offer.get("points")
			if typeof(points) != TYPE_PACKED_VECTOR3_ARRAY \
					and typeof(points) != TYPE_ARRAY:
				out.append("%s: a '%s' offer carries no points; a route "
						% [who, kind] + "is an ordered path")
				continue
			if (points as Array).size() < 2:
				out.append("%s: a '%s' offer has %d point(s); a route "
						% [who, kind, (points as Array).size()]
						+ "needs at least two")
		if REGION_OFFERS.has(kind):
			if not _finite(offer.get("position")):
				out.append("%s: a '%s' offer has no finite position"
						% [who, kind])
			if float(offer.get("radius", 0.0)) <= 0.0:
				out.append("%s: a '%s' offer reserves no region"
						% [who, kind])
	return out

static func _traversal_violations(room: Dictionary,
		who: String) -> Array[String]:
	var out: Array[String] = []
	var declared: Variant = room.get("traversal", [])
	if typeof(declared) != TYPE_ARRAY:
		out.append("%s: 'traversal' is present and is not an Array" % who)
		return out
	for entry: Variant in declared as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			out.append("%s: a traversal segment is not a dictionary" % who)
			continue
		var t: Dictionary = entry
		if not TRAVERSAL_KINDS.has(str(t.get("kind", ""))):
			out.append("%s: traversal kind '%s' is not in the contract"
					% [who, str(t.get("kind", ""))])
		if not _finite(t.get("start")) or not _finite(t.get("end")):
			out.append("%s: traversal '%s' has no finite endpoints"
					% [who, str(t.get("name", "?"))])
	return out

static func _finite(raw: Variant) -> bool:
	if typeof(raw) != TYPE_VECTOR3:
		return false
	var v: Vector3 = raw
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

## The offers of one kind, for the package that consumes that kind.
##
## A package asks for what it understands and ignores the rest, which is
## how one shell serves rails, launches and neither.
static func offers_of(result: Dictionary, kind: String) -> Array:
	var out: Array = []
	for offer: Variant in result.get("offers", []) as Array:
		if typeof(offer) == TYPE_DICTIONARY \
				and str((offer as Dictionary).get("kind", "")) == kind:
			out.append(offer)
	return out

## The sockets of one kind, for a consumer that wants only its own.
static func sockets_of(result: Dictionary, kind: String) -> Array:
	var out: Array = []
	for socket: Variant in result.get("sockets", []) as Array:
		if typeof(socket) == TYPE_DICTIONARY \
				and str((socket as Dictionary).get("kind", "")) == kind:
			out.append(socket)
	return out
