class_name RailNetworkCarrier
extends RailCarrier
## A carrier that runs a railway with POINTS in it: lines joined at
## turnouts, rather than one ordered route (H-RAIL-BREADTH; DESS-01 items
## 1 and 2, the engine half).
##
## **WHY A SUBCLASS.** `RailCarrier` runs ONE ordered route -- a link
## between each consecutive pair of docks -- and everything built so far
## rides on exactly that: Blindside's three docks, EX50-011's shuttle, the
## declared railways D-4 builds. It stays byte-for-byte what it was. This
## class is the general case, and a chain of docks is one of its cases
## too (`godot-rail-network` runs one against the ordered carrier and
## compares them), so the ordered route is a special case of this rather
## than a second design.
##
## **LINES, POINTS, DOCKS.** A network is laid as LINES -- one `RailPath`
## each, the longest runs of track with no turnout in them -- meeting at
## POINTS (`RailPoints`). The carrier is always on one line, at an offset
## along it, and `path` is always that line's path, so `pose()` and
## everything that reads a carrier's place is unchanged. It changes line
## only AT a points node, where the lines share a position and a tangent
## (every leg leaves the points along the heel, as a turnout's do, and
## parts from the others from there), so a change of line is never a
## jump: not in place, and not in facing.
##
## **WHERE THE POINTS STAND.** A switch is declared AT a dock, and its
## points are laid `POINTS_LEAD` beyond it, on the legs' side. Two
## reasons, both measured rather than chosen for looks:
##   * §21.6 queues a throw while the rail within `RAIL_SWITCH_CLEARANCE_M`
##     of the junction is occupied. Points AT a dock would be held by
##     every carrier parked there, and a player standing at the fork could
##     never choose a branch. So no dock may stand inside the clearance of
##     any points, and the layout refuses one that would.
##   * A throw from the fork dock applies at once; the tongue then takes
##     the actuator's `travel_time` to cross, and nothing leaves until it
##     has arrived.
##
## **COMMISSIONING IS STILL A PROPERTY OF THE LINK.** `commissioned[e]` is
## edge `e`'s, and an edge's own stretch of track is where its span would
## stand -- on a leg that is the leg beyond the points, never the shared
## approach, so aligning one leg can never lay the other. A journey that
## would cross a stretch that is not commissioned is refused at the dock,
## with the span's name, and nothing moves. The graph cannot imply motion
## the rail does not support.
##
## **ROUTE LOCKING (RB-F1).** §21.6 on its own measures DISTANCE. A
## carrier dispatched toward points from farther out than the clearance
## is not within it yet, and a throw applied in that moment is one it then
## meets at speed. So a journey locks every set of points it will pass
## from the moment it departs until it is `RAIL_SWITCH_CLEARANCE_M` beyond
## them (`Actuator.lock_route`); a throw meanwhile is QUEUED and applies
## once the carrier is clear.
##
## **RECALL.** `call_to(dock)` brings the carrier to a dock over
## commissioned track, including from another branch: it plans the route
## over the network, sets each turnout it needs (visibly -- the tongue
## moves), waits for it to lock, and travels, reversing at a dock where
## the route turns back through a turnout. Its state is always one of
## `refused`, `queued` (waiting on points), `executing`, `completed` or
## `cancelled` (P15.3), and a route that crosses missing track is refused
## before anything moves, naming the span.

## Which end of a line. A points node sits at one or both.
const START := 0
const END := 1
## How far beyond its fork dock a switch's points are laid: the clearance,
## and a metre so a carrier AT the dock is outside it by more than a
## rounding error.
const POINTS_LEAD := Constants.RAIL_SWITCH_CLEARANCE_M + 1.0

## A call's progress. `detail` is the reason a player can act on.
signal call_changed(dock_id: String, state: String, detail: String)

## `lines[l]`: `{"path": RailPath, "docks": PackedInt32Array (in order
## along it), "ends": [points at START, points at END] (-1 for none),
## "owned": [[from, to, edge], ...] (each edge's own stretch)}`.
var lines: Array[Dictionary] = []
var points: Array[RailPoints] = []
## `edges[e]`: `{"a": dock, "b": dock, "points": k or -1, "leg": j or -1,
## "span_id": String}`. `a` is the heel side of a points edge.
var edges: Array[Dictionary] = []
## Which line each dock is on. `dock_offsets[i]` (the base field) is its
## offset along THAT line, so the offsets are not one ascending list here.
var dock_line: PackedInt32Array = PackedInt32Array()
## Every refusal the layout made, reported as this carrier's own.
var layout_refusals: Array[String] = []
## The line the carrier is on now; `path` is always `lines[line].path`.
var line := 0
## RB-F1's lock. Off only to reproduce the defect it answers.
var route_lock := true
## +1 while the deck faces the way its line runs, -1 while it faces
## against it. Two lines can meet at a set of points head to head -- a
## line that is a leg at both ends, or two heels -- and then their own
## directions are opposite; a deck that faced its line would turn half a
## circle in one frame there, and `sync_to_physics` would hand that turn
## to everyone standing on it. So the facing carries across the change.
var _facing := 1.0

## The journey being travelled: pieces of line end to end.
var _pieces: Array[Dictionary] = []
var _s := 0.0
var _total := 0.0
## Points this journey has still to pass, which it holds locked.
var _ahead: Array[int] = []
## The dock the current journey left, for "back to where it came from".
var _left := -1

var _call := -1
var _call_state := "idle"
var _call_detail := ""
var _call_hops: Array[Dictionary] = []
## Settings the call is waiting for: `[[k, leg], ...]`.
var _call_needs: Array = []


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

## A network laid from its declaration, and everything that makes it a
## place: the carrier, the points, and the track between them.
##
## `docks`: `[{"dock_id", "at": Vector3}]` in declaration order.
## `spans`: `[{"span_id", "from_dock", "to_dock", "commissioned": bool}]`.
## `switches`: `[{"switch_id", "dock_id", "legs": [dock_id, ...],
## "leg": initial leg index}]`. The shape `Zone.rail_networks` would carry
## once it can declare a switch (H-RAIL-BREADTH note to Dess), with the
## rooms already resolved to places.
##
## `levers`: a CALL lever at every dock and a POINTS lever at every fork,
## worked with the game's own `interact` verb (`CallLever`, the EX50-011
## call control, reused rather than a second one).
##
## Returns `{"carrier", "points", "track", "calls", "throws", "refused"}`.
## A refused layout still returns a carrier -- malformed, so it refuses
## every command and says why -- and builds no track, the base class's
## rule for a railway that is not one.
static func build(root: Node3D, docks: Array, spans: Array,
		switches: Array, deck_size: Vector3,
		theme := "concrete_facility", home := 0, levers := false) -> Dictionary:
	var laid := lay_out(docks, spans, switches)
	var made := RailNetworkCarrier.new()
	made.deck = deck_size
	made._theme = theme
	made.layout_refusals = laid.get("refused", [] as Array[String]) \
			as Array[String]
	var built_points: Array[RailPoints] = []
	var track: Array[Node3D] = []
	if made.layout_refusals.is_empty():
		made.lines = laid["lines"] as Array[Dictionary]
		made.edges = laid["edges"] as Array[Dictionary]
		made.dock_ids = laid["dock_ids"] as PackedStringArray
		made.dock_offsets = laid["dock_offsets"] as PackedFloat32Array
		made.dock_line = laid["dock_line"] as PackedInt32Array
		var links: Array[bool] = []
		for edge: Dictionary in made.edges:
			links.append(bool(edge.get("commissioned", true)))
		made.commissioned = links
		for spec: Dictionary in laid["points"] as Array[Dictionary]:
			var one := RailPoints.create(str(spec["id"]),
					spec["at"] as Vector3, spec["poses"] as Array[Transform3D],
					spec["heel"] as Vector2i, spec["legs"] as Array[Vector2i],
					spec["labels"] as PackedStringArray, int(spec["leg"]),
					theme)
			one.dock_index = int(spec["dock"])
			root.add_child(one)
			built_points.append(one)
		made.points = built_points
		var start := clampi(home, 0, made.dock_ids.size() - 1)
		made.line = made.dock_line[start]
		made.path = (made.lines[made.line]["path"] as RailPath)
		made.offset = made.dock_offsets[start]
		track = made._lay_track(root)
	made.name = "RailNetworkCarrier"
	root.add_child(made)
	var calls: Array[CallLever] = []
	var throws: Array[CallLever] = []
	if levers and made.layout_refusals.is_empty():
		for i in made.dock_ids.size():
			var caller := CallLever.make("CALL %s" % made.dock_ids[i],
					Color(0.55, 0.9, 0.7), theme)
			root.add_child(caller)
			caller.global_position = made._beside(i, 1.0)
			var dock := i
			caller.pulled.connect(func(_lever: CallLever) -> void:
				made.call_to(dock))
			calls.append(caller)
		for pt: RailPoints in built_points:
			var thrower := CallLever.make("POINTS %s"
					% pt.points_id.to_upper(), Color(1.0, 0.72, 0.45), theme)
			root.add_child(thrower)
			thrower.global_position = made._beside(pt.dock_index, -1.0)
			var which := pt
			thrower.pulled.connect(func(_lever: CallLever) -> void:
				which.cycle())
			throws.append(thrower)
	return {"carrier": made, "points": built_points, "track": track,
			"calls": calls, "throws": throws,
			"refused": made.layout_refusals}


## A lever's place beside dock `i`: clear of the deck, on the given side
## of the track, level with the rail.
func _beside(i: int, side: float) -> Vector3:
	var rail: RailPath = lines[dock_line[i]]["path"]
	var along := rail.tangent(dock_offsets[i])
	var across := Vector3.UP.cross(along).normalized()
	return rail.at(dock_offsets[i]) + across * side * (deck.x * 0.5 + 1.6)


## EVERY METRE OF A NETWORK, from its declaration, or why it cannot be one.
##
## Pure: no node is made, so a refusal costs nothing and a suite can ask
## about a shape without building it.
static func lay_out(docks: Array, spans: Array, switches: Array) \
		-> Dictionary:
	var refused: Array[String] = []
	var ids := PackedStringArray()
	var at: Array[Vector3] = []
	var index := {}
	for raw: Variant in docks:
		var dock: Dictionary = raw
		var id := str(dock.get("dock_id", ""))
		if index.has(id):
			refused.append("dock '%s' is declared twice" % id)
			continue
		index[id] = ids.size()
		ids.append(id)
		at.append(dock.get("at", Vector3.ZERO) as Vector3)
	if ids.size() < 2:
		refused.append("a railway needs at least two docks, got %d"
				% ids.size())
		return {"refused": refused}

	# THE DOCK GRAPH, from the spans.
	# PLAIN ARRAYS, not packed ones: a packed array read out of a
	# container is a copy, and appending to the copy changes nothing.
	var near: Array = []
	for _i in ids.size():
		near.append([])
	var span_at := {}
	for raw: Variant in spans:
		var span: Dictionary = raw
		var a := int(index.get(str(span.get("from_dock", "")), -1))
		var b := int(index.get(str(span.get("to_dock", "")), -1))
		if a < 0 or b < 0:
			refused.append("span '%s' names a dock the network does not "
					% str(span.get("span_id", "")) + "declare")
			continue
		if a == b:
			refused.append("span '%s' leaves and arrives at '%s'"
					% [str(span.get("span_id", "")), ids[a]])
			continue
		var key := _pair(a, b)
		if span_at.has(key):
			refused.append("two spans join '%s' and '%s'" % [ids[a], ids[b]])
			continue
		span_at[key] = span
		(near[a] as Array).append(b)
		(near[b] as Array).append(a)
	if not refused.is_empty():
		return {"refused": refused}
	# ONE TREE. A loop would give a carrier two ways between two docks and
	# a network with a detached dock is two railways; neither is a shape
	# this carrier runs, and it says so rather than choosing a route.
	if span_at.size() != ids.size() - 1 or not _connected(near):
		refused.append(("%d docks joined by %d spans: a network is one tree "
				% [ids.size(), span_at.size()]) + "(docks - 1 spans, all "
				+ "joined); a loop or a detached dock is not a railway this "
				+ "carrier can run")
		return {"refused": refused}

	# THE SWITCHES.
	var switch_at := {}
	for raw: Variant in switches:
		var sw: Dictionary = raw
		var sid := str(sw.get("switch_id", "points"))
		var fork := int(index.get(str(sw.get("dock_id", "")), -1))
		if fork < 0:
			refused.append("switch '%s' stands at a dock the network does "
					% sid + "not declare")
			continue
		if switch_at.has(fork):
			refused.append("two switches stand at dock '%s'" % ids[fork])
			continue
		var legs := PackedInt32Array()
		for leg_raw: Variant in sw.get("legs", []) as Array:
			var leg := int(index.get(str(leg_raw), -1))
			if leg < 0 or not (near[fork] as Array).has(leg):
				refused.append(("switch '%s' names leg '%s', which no span "
						% [sid, str(leg_raw)]) + "joins to '%s'" % ids[fork])
				continue
			legs.append(leg)
		if legs.size() < 2:
			refused.append(("switch '%s' has %d leg(s); a turnout chooses "
					% [sid, legs.size()]) + "between at least two")
			continue
		var heel := -1
		for other: int in near[fork] as Array:
			if legs.has(other):
				continue
			if heel >= 0:
				refused.append(("dock '%s' joins '%s' and '%s' besides its "
						% [ids[fork], ids[heel], ids[other]])
						+ "switch's legs; a turnout has one heel")
			heel = other
		switch_at[fork] = {"id": sid, "legs": legs, "heel": heel,
				"leg": clampi(int(sw.get("leg", 0)), 0, legs.size() - 1)}
	for i in ids.size():
		var degree := (near[i] as Array).size()
		if degree > 2 and not switch_at.has(i):
			refused.append(("dock '%s' joins %d tracks and declares no "
					% [ids[i], degree]) + "switch; where track "
					+ "divides, something has to choose")
	if not refused.is_empty():
		return {"refused": refused}

	# WHERE EACH SET OF POINTS STANDS: `POINTS_LEAD` beyond its fork dock,
	# toward its legs, level with the dock.
	var forks: Array = switch_at.keys()
	forks.sort()
	var specs: Array[Dictionary] = []
	var points_of := {}
	for fork_raw: Variant in forks:
		var fork: int = fork_raw
		var sw: Dictionary = switch_at[fork]
		var legs: PackedInt32Array = sw["legs"]
		var toward := Vector3.ZERO
		for leg: int in legs:
			toward += at[leg] - at[fork]
		toward.y = 0.0
		var heel: int = sw["heel"]
		if toward.length() < 0.5 and heel >= 0:
			toward = at[fork] - at[heel]
			toward.y = 0.0
		if toward.length() < 0.001:
			refused.append("switch '%s': its legs give it no direction"
					% str(sw["id"]))
			continue
		var dir := toward.normalized()
		if heel >= 0:
			var inward := at[fork] - at[heel]
			inward.y = 0.0
			if inward.length() > 0.001 and inward.normalized().dot(dir) < 0.0:
				refused.append(("switch '%s': its heel from '%s' arrives "
						% [str(sw["id"]), ids[heel]]) + "heading away from "
						+ "its legs, so the track would double back through "
						+ "the points")
				continue
		points_of[fork] = specs.size()
		specs.append({"id": str(sw["id"]), "dock": fork,
				"at": at[fork] + dir * POINTS_LEAD, "dir": dir, "legs": legs,
				"heel": heel, "leg": int(sw["leg"])})
	if not refused.is_empty():
		return {"refused": refused}

	# THE TRACK GRAPH: docks, then one node per set of points. A leg span
	# runs through its switch's points; everything else joins its docks.
	var n := ids.size()
	var graph: Array = []
	for _i in n + specs.size():
		graph.append([])
	for k in specs.size():
		_join(graph, int(specs[k]["dock"]), n + k)
	for key_raw: Variant in span_at.keys():
		var key: String = key_raw
		var parts := key.split("|")
		var a := int(parts[0])
		var b := int(parts[1])
		_join(graph, _side(a, b, switch_at, points_of, n),
				_side(b, a, switch_at, points_of, n))

	# THE LINES: every longest run of track with no turnout in it.
	var raw_lines: Array[PackedInt32Array] = []
	var walked := {}
	var ends: Array[int] = []
	for node in graph.size():
		if (graph[node] as Array).size() != 2:
			ends.append(node)
	for from: int in ends:
		var steps: Array = (graph[from] as Array).duplicate()
		steps.sort()
		for first_raw: Variant in steps:
			var first: int = first_raw
			if walked.has(_pair(from, first)):
				continue
			var seq := PackedInt32Array([from, first])
			walked[_pair(from, first)] = true
			var here := first
			var came := from
			while (graph[here] as Array).size() == 2:
				var pair: Array = graph[here]
				var next: int = pair[0] if int(pair[1]) == came else pair[1]
				walked[_pair(here, next)] = true
				seq.append(next)
				came = here
				here = next
			raw_lines.append(_oriented(seq, n, specs))

	# Geometry, docks along each line, and every line's reason to exist.
	var lines_out: Array[Dictionary] = []
	var docks_line := PackedInt32Array()
	docks_line.resize(n)
	docks_line.fill(-1)
	var offsets := PackedFloat32Array()
	offsets.resize(n)
	for seq: PackedInt32Array in raw_lines:
		# A LEG LEAVES ITS POINTS ALONG THE HEEL, the way a turnout's legs
		# do: its end tangent at the points is the heel's direction, so a
		# change of line there is neither a jump nor a turn. (A shared lead
		# point on the heel's line tried first made an S-bend: uniform
		# Catmull-Rom over a 2 m span beside a 19 m one overshoots, and
		# `godot-rail-network` measured a 61 degree turn in the first
		# 0.2 m of each leg.) A heel needs nothing: its last span runs from
		# the fork dock to the points, which is the direction itself.
		var pts := PackedVector3Array()
		var start_dir := Vector3.ZERO
		var end_dir := Vector3.ZERO
		for i in seq.size():
			var node := seq[i]
			if node < n:
				pts.append(at[node])
				continue
			var spec: Dictionary = specs[node - n]
			pts.append(spec["at"] as Vector3)
			var dir: Vector3 = spec["dir"]
			if i == 0 and seq[1] != int(spec["dock"]):
				start_dir = dir
			elif i == seq.size() - 1 and seq[i - 1] != int(spec["dock"]):
				end_dir = -dir
		var rail := RailPath.from_points(pts, start_dir, end_dir)
		var where := lines_out.size()
		var line_docks := PackedInt32Array()
		var last := -INF
		for node in seq:
			if node >= n:
				continue
			var along := rail.curve().get_closest_offset(at[node])
			if along <= last + DOCK_EPSILON * 2.0:
				refused.append("line %d: dock '%s' is not beyond the dock "
						% [where, ids[node]] + "before it along the track")
			last = along
			line_docks.append(node)
			docks_line[node] = where
			offsets[node] = along
		for why: String in rail.violations("line %d" % where):
			refused.append(why)
		var start_k := seq[0] - n if seq[0] >= n else -1
		var end_k := seq[seq.size() - 1] - n \
				if seq[seq.size() - 1] >= n else -1
		if line_docks.is_empty():
			refused.append(("the track between points '%s' and '%s' has no "
					% [str(specs[start_k]["id"]) if start_k >= 0 else "?",
						str(specs[end_k]["id"]) if end_k >= 0 else "?"])
					+ "dock on it, so nothing could stop there to throw either")
		lines_out.append({"path": rail, "docks": line_docks,
				"ends": [start_k, end_k], "owned": []})
	if not refused.is_empty():
		return {"refused": refused}

	# CLEARANCE: no dock inside any points' §21.6 radius, or a carrier
	# parked there would hold them forever.
	for k in specs.size():
		var p: Vector3 = specs[k]["at"]
		for i in n:
			var gap := at[i].distance_to(p)
			if gap < Constants.RAIL_SWITCH_CLEARANCE_M:
				refused.append(("dock '%s' stands %.1f m from points '%s', "
						% [ids[i], gap, str(specs[k]["id"])])
						+ "inside the %.1f m clearance: a carrier parked "
						% Constants.RAIL_SWITCH_CLEARANCE_M
						+ "there would hold the points and nobody could throw them")
	if not refused.is_empty():
		return {"refused": refused}

	# THE EDGES, and each one's own stretch of track.
	var edges_out: Array[Dictionary] = []
	for l in lines_out.size():
		var line_docks: PackedInt32Array = lines_out[l]["docks"]
		for i in range(1, line_docks.size()):
			var a := line_docks[i - 1]
			var b := line_docks[i]
			_edge(edges_out, lines_out, l, offsets[a], offsets[b], a, b, -1,
					-1, span_at.get(_pair(a, b), {}) as Dictionary)
	var point_specs: Array[Dictionary] = []
	for k in specs.size():
		var spec: Dictionary = specs[k]
		var fork: int = spec["dock"]
		var legs: PackedInt32Array = spec["legs"]
		var heel_end := Vector2i(-1, -1)
		var leg_ends: Array[Vector2i] = []
		leg_ends.resize(legs.size())
		var poses: Array[Transform3D] = []
		poses.resize(legs.size())
		var labels := PackedStringArray()
		labels.resize(legs.size())
		for l in lines_out.size():
			var line_ends: Array = lines_out[l]["ends"]
			for end: int in [START, END]:
				if int(line_ends[end]) != k:
					continue
				var line_docks: PackedInt32Array = lines_out[l]["docks"]
				var rail: RailPath = lines_out[l]["path"]
				var near_dock := line_docks[0] if end == START \
						else line_docks[line_docks.size() - 1]
				if near_dock == fork:
					heel_end = Vector2i(l, end)
					continue
				var j := legs.find(near_dock)
				if j < 0:
					refused.append("points '%s': a leg reaches dock '%s', "
							% [str(spec["id"]), ids[near_dock]]
							+ "which the switch does not name")
					continue
				leg_ends[j] = Vector2i(l, end)
				labels[j] = ids[near_dock]
				var from := 0.0 if end == START else rail.length()
				var aim := rail.at(clampf(from + (RailPoints.TONGUE_AIM
						if end == START else -RailPoints.TONGUE_AIM),
						0.0, rail.length()))
				var origin: Vector3 = spec["at"]
				poses[j] = Transform3D(Basis.looking_at(aim - origin,
						Vector3.UP), origin)
				_edge(edges_out, lines_out, l, from, offsets[near_dock], fork,
						near_dock, k, j,
						span_at.get(_pair(fork, near_dock), {}) as Dictionary)
		if heel_end.x < 0:
			refused.append("points '%s' have no heel track" % str(spec["id"]))
		point_specs.append({"id": str(spec["id"]), "at": spec["at"],
				"poses": poses, "heel": heel_end, "legs": leg_ends,
				"labels": labels, "leg": int(spec["leg"]), "dock": fork})
	if edges_out.size() != span_at.size():
		refused.append("%d spans but %d stretches of track between docks"
				% [span_at.size(), edges_out.size()])
	if not refused.is_empty():
		return {"refused": refused}
	return {"lines": lines_out, "edges": edges_out, "points": point_specs,
			"dock_ids": ids, "dock_offsets": offsets, "dock_line": docks_line,
			"refused": refused}


static func _pair(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


static func _join(graph: Array, a: int, b: int) -> void:
	if not (graph[a] as Array).has(b):
		(graph[a] as Array).append(b)
	if not (graph[b] as Array).has(a):
		(graph[b] as Array).append(a)


## The track node dock `a`'s span to `b` leaves from: `a` itself, or its
## switch's points when `b` is one of that switch's legs.
static func _side(a: int, b: int, switch_at: Dictionary, points_of: Dictionary,
		n: int) -> int:
	if switch_at.has(a) and ((switch_at[a] as Dictionary)["legs"]
			as PackedInt32Array).has(b):
		return n + int(points_of[a])
	return a


static func _connected(near: Array) -> bool:
	var seen := {0: true}
	var frontier: Array[int] = [0]
	while not frontier.is_empty():
		var here: int = frontier.pop_back()
		for next: int in near[here] as Array:
			if not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size() == near.size()


## A line's direction, chosen so a carrier heading FORWARD through a
## turnout's heel carries on FORWARD down its leg: heel lines END at their
## points and leg lines START at theirs. A line that is a heel at both
## ends (or a leg at both) cannot have both; the first end wins, and the
## call levers -- which name a dock, not a direction -- read the same
## either way.
static func _oriented(seq: PackedInt32Array, n: int,
		specs: Array[Dictionary]) -> PackedInt32Array:
	var score_as_is := _ends_right(seq, n, specs)
	var flipped := seq.duplicate()
	flipped.reverse()
	var score_flipped := _ends_right(flipped, n, specs)
	if score_flipped > score_as_is:
		return flipped
	if score_flipped == score_as_is and _first_dock(flipped, n) \
			< _first_dock(seq, n):
		return flipped
	return seq


static func _ends_right(seq: PackedInt32Array, n: int,
		specs: Array[Dictionary]) -> int:
	var score := 0
	var first := seq[0]
	var last := seq[seq.size() - 1]
	if first >= n and seq[1] != int(specs[first - n]["dock"]):
		score += 1
	if last >= n and seq[seq.size() - 2] == int(specs[last - n]["dock"]):
		score += 1
	return score


static func _first_dock(seq: PackedInt32Array, n: int) -> int:
	for node in seq:
		if node < n:
			return node
	return n


static func _edge(out: Array[Dictionary], lines_in: Array[Dictionary],
		l: int, from: float, to: float, a: int, b: int, k: int, j: int,
		span: Dictionary) -> void:
	var e := out.size()
	out.append({"a": a, "b": b, "points": k, "leg": j,
			"span_id": str(span.get("span_id", "")),
			"commissioned": bool(span.get("commissioned", true))})
	(lines_in[l]["owned"] as Array).append([minf(from, to), maxf(from, to), e])


# ---------------------------------------------------------------------------
# Where things are
# ---------------------------------------------------------------------------

func at_dock() -> int:
	for i in dock_ids.size():
		if dock_line[i] == line \
				and absf(offset - dock_offsets[i]) <= DOCK_EPSILON:
			return i
	return -1


## Is there a way out of dock `from` heading `direction` along its line,
## over commissioned track and through points that are set for it?
func link_open(from: int, direction: int) -> bool:
	if from < 0 or from >= dock_ids.size():
		return false
	var run := _walk(dock_line[from], dock_offsets[from], direction, -1)
	return not run.has("reason")


## The edge joining docks `a` and `b`, -1 when none does.
func edge_between(a: int, b: int) -> int:
	for e in edges.size():
		var edge: Dictionary = edges[e]
		if (int(edge["a"]) == a and int(edge["b"]) == b) \
				or (int(edge["a"]) == b and int(edge["b"]) == a):
			return e
	return -1


func dock_index(id: String) -> int:
	return Array(dock_ids).find(id)


func call_state() -> String:
	return _call_state


func call_detail() -> String:
	return _call_detail


## The points a journey still holds locked, for a suite to read.
func holding() -> Array[int]:
	return _ahead.duplicate()


func travelling() -> bool:
	return target_dock >= 0 and not _pieces.is_empty()


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

## A direction command, as a shot receiver delivers it: along the line the
## carrier is on, through whatever the points ahead are set for, to the
## next dock. The base class's rules, read for a network: repeated
## commands the same way are one request; the opposite way while moving
## goes back to the dock just left -- re-checked, because points behind
## it may have been thrown once it was clear of them; a held or unpowered
## carrier honours nothing.
func request(direction: int) -> bool:
	if not _malformed.is_empty():
		refused.emit("not_a_railway", "; ".join(_malformed))
		return false
	if direction != FORWARD and direction != BACK:
		refused.emit("bad_direction", "a command must be FORWARD or BACK")
		return false
	if held:
		refused.emit("held", "the carrier is holding under a fail-safe "
				+ "stop and will not accept travel commands")
		return false
	if _unpowered:
		refused.emit("unpowered", "the carrier has no power and holds "
				+ "where it stands")
		return false
	if travelling() and direction == heading:
		refused.emit("already_moving", "already travelling that way")
		return false
	# A DIRECTION COMMAND TAKES OVER from a call that has not started
	# moving: the player has said something newer.
	if _call >= 0:
		_end_call("cancelled", "a direction command took over")
	var reversing := travelling()
	var run := _walk(line, offset, direction, -1)
	if run.has("reason"):
		refused.emit(str(run["reason"]), str(run["detail"]))
		return false
	var from := at_dock()
	# REVERSING keeps the dock it left: the carrier is going back to it,
	# not departing from anywhere new, and says so no more than the base
	# class does.
	_start(run, _left if reversing or from < 0 else from)
	if not reversing:
		departed.emit(dock_id(from if from >= 0 else _left), direction)
	return true


## Bring the carrier to dock `index`. See the class comment.
func call_to(index: int) -> bool:
	var target := dock_id(index)
	if not _malformed.is_empty():
		return _call_refused(target, "not_a_railway", "; ".join(_malformed))
	if index < 0 or index >= dock_ids.size():
		return _call_refused(target, "no_dock", "there is no dock %d" % index)
	if held:
		return _call_refused(target, "held", "the carrier is holding under "
				+ "a fail-safe stop")
	if _unpowered:
		return _call_refused(target, "unpowered", "the carrier has no power")
	if travelling():
		# EX50-011 §8: one destination, one motion state, no queued
		# arrivals. A call while the carrier moves is refused, and says
		# where it is going instead.
		return _call_refused(target, "already_moving",
				"the carrier is travelling to %s; call again when it stops"
				% dock_id(target_dock))
	if _call >= 0:
		_end_call("cancelled", "a newer call took over")
	var from := at_dock()
	if from == index:
		_call = index
		_end_call("completed", "the carrier is already at %s" % target)
		return true
	var route := _route_from_here(index, false)
	if route.is_empty():
		var blocked := _route_from_here(index, true)
		var why := "no track joins the carrier to %s" % target
		for hop: Dictionary in blocked:
			var e: int = hop["edge"]
			if e >= 0 and not commissioned[e]:
				why = ("the track between %s and %s is not commissioned"
						% [dock_id(int(edges[e]["a"])),
							dock_id(int(edges[e]["b"]))])
				if str(edges[e]["span_id"]) != "":
					why += " (span %s)" % str(edges[e]["span_id"])
				break
		return _call_refused(target, "no_route", why)
	_call = index
	_call_hops = route
	_next_run()
	return true


## §21.1.1 for a network: power loss HOLDS, and remembers the journey --
## including the points it still has to pass, which stay locked through
## the outage, so power comes back to the route it left on.
func power(on: bool) -> void:
	super.power(on)
	_update_locks()


## The fail-safe stop. As in the base class it ends the journey, so it
## ends any call too; the carrier stands where it stopped, and a command
## after release starts from there.
func hold(on: bool) -> void:
	super.hold(on)
	if on:
		_pieces.clear()
		_ahead.clear()
		_s = 0.0
		_total = 0.0
		if _call >= 0:
			_end_call("cancelled", "the carrier is holding under a "
					+ "fail-safe stop")
		_update_locks()


## Rest at dock `index`, on its own line.
func park_at(index: int) -> void:
	if dock_ids.is_empty():
		return
	var where := clampi(index, 0, dock_ids.size() - 1)
	super.hold(false)
	_pieces.clear()
	_ahead.clear()
	_s = 0.0
	_total = 0.0
	_left = -1
	if _call >= 0:
		_end_call("cancelled", "the railway was re-parked")
	heading = HOLD
	speed = 0.0
	target_dock = -1
	# A re-park is a new start: an errand kept through a power loss
	# (`power`) would otherwise come back on restore to a journey that no
	# longer exists.
	_errand = -1
	_bearing = HOLD
	_set_line(dock_line[where])
	offset = dock_offsets[where]
	_facing = 1.0
	_place()
	_update_locks()


## THE REBUILD, for the switch settings: each named set of points straight
## onto its saved leg, with nothing reported (`RailPoints.restore`).
## `settings` maps a switch id to a leg index or a leg's dock id.
func restore_points(settings: Dictionary) -> int:
	var count := 0
	for pt: RailPoints in points:
		if not settings.has(pt.points_id):
			continue
		var want: Variant = settings[pt.points_id]
		var leg := int(want) if typeof(want) == TYPE_INT \
				else Array(pt.leg_labels).find(str(want))
		if leg < 0:
			continue
		pt.restore(leg)
		count += 1
	return count


# ---------------------------------------------------------------------------
# Travel
# ---------------------------------------------------------------------------

func advance(delta: float) -> void:
	if not _malformed.is_empty():
		return
	_update_call()
	if heading == HOLD or target_dock < 0 or _pieces.is_empty():
		_update_locks()
		return
	var moved := StopTravel.step(_s, _total, speed, delta, accel, top_speed,
			DOCK_EPSILON)
	var reach := moved.x
	# NOTHING CROSSES POINTS THAT DO NOT JOIN IT. Locked, they cannot have
	# moved; this is the check that says so rather than trusting it, and
	# if it ever fails the carrier stops AT the points instead of being
	# carried onto track it is not on.
	var start := 0.0
	for i in _pieces.size():
		var piece: Dictionary = _pieces[i]
		var length := absf(float(piece["to"]) - float(piece["from"]))
		var boundary := start + length
		if i + 1 < _pieces.size() and _s < boundary - 0.0001 \
				and reach >= boundary - 0.0001:
			var k := int(piece["points_after"])
			if k >= 0 and not _joins(k, piece, _pieces[i + 1]):
				_s = boundary
				_locate()
				_place()
				var who := points[k].points_id
				super.hold(true)
				_pieces.clear()
				_ahead.clear()
				if _call >= 0:
					_end_call("cancelled", "stopped at points %s" % who)
				refused.emit("points_moved", "the points at %s no longer "
						% who + "join this track; the carrier has stopped")
				_update_locks()
				return
		start = boundary
	_s = reach
	speed = moved.y
	_locate()
	_place()
	_update_locks()
	if absf(_total - _s) <= DOCK_EPSILON:
		var landed := target_dock
		_s = _total
		_locate()
		speed = 0.0
		heading = HOLD
		target_dock = -1
		_pieces.clear()
		_ahead.clear()
		_left = landed
		_place()
		_update_locks()
		arrived.emit(dock_id(landed))
		if _call >= 0:
			_arrived_on_call(landed)


## The base class's pose, facing as the deck has faced (`_facing`).
func pose() -> Transform3D:
	if path == null:
		return global_transform
	var here := to_world * path.at(offset)
	var along := (to_world.basis * path.tangent(offset)).normalized() \
			* _facing
	var up := Vector3.UP
	if absf(along.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var basis := Basis()
	var side := up.cross(along).normalized()
	basis.x = side
	basis.y = along.cross(side).normalized()
	basis.z = along
	return Transform3D(basis, here + basis.y * (deck.y * 0.5))


## Each network is valid or says why, like the base class.
func violations(who := "carrier") -> Array[String]:
	var out: Array[String] = []
	for why: String in layout_refusals:
		out.append("%s: %s" % [who, why])
	if not out.is_empty():
		return out
	if lines.is_empty():
		out.append("%s: no lines" % who)
		return out
	if commissioned.size() != edges.size():
		out.append("%s: %d edges need %d links, got %d" % [who, edges.size(),
				edges.size(), commissioned.size()])
	if dock_ids.size() != dock_offsets.size() \
			or dock_ids.size() != dock_line.size():
		out.append("%s: %d docks, %d offsets and %d line entries" % [who,
				dock_ids.size(), dock_offsets.size(), dock_line.size()])
	if deck.x <= 0.0 or deck.y <= 0.0 or deck.z <= 0.0:
		out.append("%s: the deck %v has no volume" % [who, deck])
	return out


# ---------------------------------------------------------------------------
# Inside
# ---------------------------------------------------------------------------

func _set_line(l: int) -> void:
	line = l
	path = lines[l]["path"] as RailPath


## From `(l, o)` heading `h` to the next dock -- or on to dock `until`,
## passing any on the way -- through the points as they are set now.
##
## `{"pieces", "dock", "passes"}` or `{"reason", "detail"}`. Every refusal
## is the physical fact that stops the carrier: the track ends, the points
## are moving, the points are set for the other leg, a stretch is not
## commissioned.
func _walk(l: int, o: float, h: int, until: int) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var passes: Array[int] = []
	var docks_seen: Array[int] = []
	var here_line := l
	var here := o
	var way := h
	for _guard in lines.size() * 2 + dock_ids.size() + 2:
		var line_docks: PackedInt32Array = lines[here_line]["docks"]
		var next := -1
		if way == FORWARD:
			for d in line_docks:
				if dock_offsets[d] > here + DOCK_EPSILON:
					next = d
					break
		else:
			for i in range(line_docks.size() - 1, -1, -1):
				if dock_offsets[line_docks[i]] < here - DOCK_EPSILON:
					next = line_docks[i]
					break
		if next >= 0:
			var gap := _first_gap(here_line, here, dock_offsets[next])
			if gap >= 0:
				return _no_link(gap)
			pieces.append({"line": here_line, "from": here,
					"to": dock_offsets[next], "points_after": -1})
			docks_seen.append(next)
			if until < 0 or next == until:
				return {"pieces": pieces, "dock": next, "passes": passes,
						"docks": docks_seen}
			here = dock_offsets[next]
			continue
		var rail: RailPath = lines[here_line]["path"]
		var end := END if way == FORWARD else START
		var end_at := rail.length() if end == END else 0.0
		var line_ends: Array = lines[here_line]["ends"]
		var k := int(line_ends[end])
		if k < 0:
			return {"reason": "end_of_track", "detail": "there is no track "
					+ "beyond %s" % dock_id(_nearest_dock(here_line, here))}
		var gap_end := _first_gap(here_line, here, end_at)
		if gap_end >= 0:
			return _no_link(gap_end)
		var pt := points[k]
		var arriving := Vector2i(here_line, end)
		var live := pt.live_leg()
		var onward := Vector2i(-1, -1)
		if pt.is_heel(arriving):
			if live < 0:
				return {"reason": "points_moving", "detail": "the points at "
						+ "%s are between legs; wait for them to lock"
						% pt.points_id}
			onward = pt.legs[live]
		else:
			var mine := pt.leg_of(arriving)
			if live < 0:
				return {"reason": "points_moving", "detail": "the points at "
						+ "%s are between legs; wait for them to lock"
						% pt.points_id}
			if live != mine:
				return {"reason": "points_against", "detail": ("the points "
						+ "at %s are set for %s, not for this track")
						% [pt.points_id, pt.leg_labels[live]]}
			onward = pt.heel
		pieces.append({"line": here_line, "from": here, "to": end_at,
				"points_after": k})
		passes.append(k)
		here_line = onward.x
		var onward_rail: RailPath = lines[here_line]["path"]
		here = 0.0 if onward.y == START else onward_rail.length()
		way = FORWARD if onward.y == START else BACK
	return {"reason": "not_a_railway", "detail": "the walk from line %d "
			% l + "did not reach a dock"}


func _no_link(e: int) -> Dictionary:
	var edge: Dictionary = edges[e]
	var detail := "no commissioned track between %s and %s" % [
			dock_id(int(edge["a"])), dock_id(int(edge["b"]))]
	if str(edge["span_id"]) != "":
		detail += " (span %s)" % str(edge["span_id"])
	return {"reason": "no_link", "detail": detail}


## The first edge whose own stretch of line `l` between `a` and `b` is not
## commissioned, -1 when every metre of it is track.
func _first_gap(l: int, a: float, b: float) -> int:
	var lo := minf(a, b)
	var hi := maxf(a, b)
	for owned_raw: Variant in lines[l]["owned"] as Array:
		var owned: Array = owned_raw
		var e: int = owned[2]
		if commissioned[e]:
			continue
		if minf(hi, float(owned[1])) - maxf(lo, float(owned[0])) \
				> DOCK_EPSILON:
			return e
	return -1


## The uncommissioned edge whose own stretch of line `l` holds `along`.
func _gap_at(l: int, along: float) -> int:
	for owned_raw: Variant in lines[l]["owned"] as Array:
		var owned: Array = owned_raw
		var e: int = owned[2]
		if not commissioned[e] and along > float(owned[0]) \
				and along < float(owned[1]):
			return e
	return -1


func _nearest_dock(l: int, o: float) -> int:
	var best := -1
	var gap := INF
	for d in lines[l]["docks"] as PackedInt32Array:
		if absf(dock_offsets[d] - o) < gap:
			gap = absf(dock_offsets[d] - o)
			best = d
	return best


func _joins(k: int, before: Dictionary, after: Dictionary) -> bool:
	var pt := points[k]
	var live := pt.live_leg()
	if live < 0:
		return false
	var rail_before: RailPath = lines[int(before["line"])]["path"]
	var arriving := Vector2i(int(before["line"]),
			END if absf(float(before["to"]) - rail_before.length()) < 0.001
			else START)
	var leaving := Vector2i(int(after["line"]),
			START if absf(float(after["from"])) < 0.001 else END)
	if pt.is_heel(arriving):
		return pt.legs[live] == leaving
	return pt.leg_of(arriving) == live and pt.is_heel(leaving)


func _start(run: Dictionary, left: int) -> void:
	_pieces = run["pieces"] as Array[Dictionary]
	_ahead = (run["passes"] as Array[int]).duplicate()
	_total = 0.0
	for piece: Dictionary in _pieces:
		_total += absf(float(piece["to"]) - float(piece["from"]))
	_s = 0.0
	_left = left
	target_dock = int(run["dock"])
	var first: Dictionary = _pieces[0]
	heading = FORWARD if float(first["to"]) > float(first["from"]) else BACK
	_update_locks()


## Put the carrier where `_s` is along the journey.
func _locate() -> void:
	var start := 0.0
	for i in _pieces.size():
		var piece: Dictionary = _pieces[i]
		var from := float(piece["from"])
		var to := float(piece["to"])
		var length := absf(to - from)
		if _s <= start + length + 0.00001 or i == _pieces.size() - 1:
			var into := clampf(_s - start, 0.0, length)
			if int(piece["line"]) != line:
				# THE FACING CARRIES OVER: the way the deck faced at the end
				# of the line it leaves, read against the direction the new
				# line runs at the same point.
				var was := path.tangent(offset) * _facing
				_set_line(int(piece["line"]))
				_facing = 1.0 if path.tangent(from).dot(was) >= 0.0 else -1.0
			offset = from + into * signf(to - from)
			heading = FORWARD if to > from else BACK
			# PASSED A SET OF POINTS: it no longer holds them by the route,
			# only by distance until it is clear (§21.6).
			for j in range(0, i):
				var k := int((_pieces[j] as Dictionary)["points_after"])
				if k >= 0:
					_ahead.erase(k)
			return
		start += length


## RB-F1 and §21.6, from what the carrier knows: each set of points is
## held while this journey has still to pass it, or while the carrier is
## within the clearance of it.
func _update_locks() -> void:
	var here := pose().origin
	for k in points.size():
		var pt := points[k]
		if pt.actuator == null:
			continue
		var near_it := here.distance_to(pt.global_position) \
				< Constants.RAIL_SWITCH_CLEARANCE_M
		var committed := route_lock and _ahead.has(k)
		pt.actuator.lock_route(self, near_it or committed)


# ---------------------------------------------------------------------------
# Recall
# ---------------------------------------------------------------------------

func _call_refused(target: String, reason: String, detail: String) -> bool:
	_call_state = "refused"
	_call_detail = detail
	call_changed.emit(target, "refused", detail)
	refused.emit(reason, detail)
	return false


func _end_call(state: String, detail: String) -> void:
	var target := dock_id(_call)
	_call = -1
	_call_hops.clear()
	_call_needs.clear()
	_call_state = state
	_call_detail = detail
	call_changed.emit(target, state, detail)


## The hops from where the carrier stands to dock `goal`, over commissioned
## track (or over any track when `any`, to name what is missing).
## `[{"edge", "to"}]`.
func _route_from_here(goal: int, any: bool) -> Array[Dictionary]:
	var from := at_dock()
	var starts: Array[Dictionary] = []
	if from >= 0:
		starts.append({"dock": from, "hops": [] as Array[Dictionary]})
	else:
		# STRANDED BETWEEN DOCKS: the first hop is to one end of the track
		# it stands on, through the points as they are.
		for way: int in [FORWARD, BACK]:
			var run := _walk(line, offset, way, -1)
			if run.has("reason"):
				continue
			var reached := int(run["dock"])
			starts.append({"dock": reached, "hops": [{"edge": -1,
					"to": reached}] as Array[Dictionary]})
	var best: Array[Dictionary] = []
	var found := false
	for start: Dictionary in starts:
		var tail := _bfs(int(start["dock"]), goal, any)
		if tail.is_empty() and int(start["dock"]) != goal:
			continue
		var hops: Array[Dictionary] = (start["hops"] as Array[Dictionary]) \
				.duplicate()
		hops.append_array(tail)
		if not found or hops.size() < best.size():
			best = hops
			found = true
	return best


func _bfs(from: int, goal: int, any: bool) -> Array[Dictionary]:
	if from == goal:
		return []
	var came := {from: -1}
	var via := {}
	var frontier: Array[int] = [from]
	while not frontier.is_empty():
		var here: int = frontier.pop_front()
		for e in edges.size():
			if not any and not commissioned[e]:
				continue
			var edge: Dictionary = edges[e]
			var other := -1
			if int(edge["a"]) == here:
				other = int(edge["b"])
			elif int(edge["b"]) == here:
				other = int(edge["a"])
			if other < 0 or came.has(other):
				continue
			came[other] = here
			via[other] = e
			if other == goal:
				var out: Array[Dictionary] = []
				var at_node := goal
				while at_node != from:
					out.push_front({"edge": int(via[at_node]), "to": at_node})
					at_node = int(came[at_node])
				return out
			frontier.append(other)
	return []


## Which way along its own line a carrier leaves dock `d` to take edge `e`.
func _departure(d: int, e: int) -> int:
	var edge: Dictionary = edges[e]
	var other := int(edge["b"]) if int(edge["a"]) == d else int(edge["a"])
	var k := int(edge["points"])
	var l := dock_line[d]
	if k < 0:
		return FORWARD if dock_offsets[other] > dock_offsets[d] else BACK
	var line_ends: Array = lines[l]["ends"]
	return FORWARD if int(line_ends[END]) == k else BACK


## Which way along ITS line a carrier is heading when it arrives at dock
## `d` by edge `e`.
func _arrival(d: int, e: int) -> int:
	var edge: Dictionary = edges[e]
	var other := int(edge["b"]) if int(edge["a"]) == d else int(edge["a"])
	var k := int(edge["points"])
	var l := dock_line[d]
	if k < 0:
		return FORWARD if dock_offsets[d] > dock_offsets[other] else BACK
	var line_ends: Array = lines[l]["ends"]
	# Arriving from the points means heading away from them.
	return BACK if int(line_ends[END]) == k else FORWARD


## Start the next run of the call: as many hops as continue the same way
## without needing any set of points two ways, with those points set.
func _next_run() -> void:
	if _call_hops.is_empty():
		_end_call("completed", "the carrier is at %s" % dock_id(_call))
		return
	var here := at_dock()
	var first: Dictionary = _call_hops[0]
	# A stranded start: the first hop is "to the end of this track".
	if int(first["edge"]) < 0:
		var run := _walk(line, offset, FORWARD, int(first["to"]))
		if run.has("reason"):
			run = _walk(line, offset, BACK, int(first["to"]))
		if run.has("reason"):
			_end_call("refused", str(run["detail"]))
			return
		_call_hops.pop_front()
		_call_needs.clear()
		_dispatch_call(run, 1)
		return
	var count := 0
	var needs: Array = []
	var way := _departure(here, int(first["edge"]))
	var at_node := here
	for hop: Dictionary in _call_hops:
		var e := int(hop["edge"])
		if count > 0 and _departure(at_node, e) != way:
			break
		var edge: Dictionary = edges[e]
		var k := int(edge["points"])
		if k >= 0:
			var clash := false
			for need: Array in needs:
				if int(need[0]) == k and int(need[1]) != int(edge["leg"]):
					clash = true
			if clash:
				break
			needs.append([k, int(edge["leg"])])
		count += 1
		at_node = int(hop["to"])
		way = _arrival(at_node, e)
	_call_needs = needs
	var waiting := false
	for need: Array in needs:
		var pt := points[int(need[0])]
		if pt.set_leg() != int(need[1]) or pt.queued_leg() >= 0:
			pt.throw_to(int(need[1]))
		if pt.live_leg() != int(need[1]):
			waiting = true
	if not waiting:
		_try_run(count)
		return
	# QUEUED: the tongue is on its way. `_update_call` sends the run the
	# frame the last of these points locks.
	_call_state = "queued"
	_call_detail = "setting the points"
	call_changed.emit(dock_id(_call), "queued", _call_detail)


## Waiting on points: go once every one the run needs has locked.
func _update_call() -> void:
	if _call < 0 or _call_state != "queued" or travelling():
		return
	for need: Array in _call_needs:
		var pt := points[int(need[0])]
		var want := int(need[1])
		if pt.set_leg() != want and pt.queued_leg() != want:
			# SOMEBODY ELSE THREW THEM. The call does not fight a lever:
			# it stops and says what happened.
			_end_call("cancelled", "the points at %s were thrown to %s "
					% [pt.points_id, pt.leg_labels[pt.set_leg()]]
					+ "while the call waited")
			return
	_try_run(_run_length())


func _run_length() -> int:
	if at_dock() < 0 or _call_hops.is_empty():
		return 0
	var count := 0
	var way := _departure(at_dock(), int((_call_hops[0] as Dictionary)["edge"]))
	var at_node := at_dock()
	var used := {}
	for hop: Dictionary in _call_hops:
		var e := int(hop["edge"])
		if count > 0 and _departure(at_node, e) != way:
			break
		var edge: Dictionary = edges[e]
		var k := int(edge["points"])
		if k >= 0:
			if used.has(k) and int(used[k]) != int(edge["leg"]):
				break
			used[k] = int(edge["leg"])
		count += 1
		at_node = int(hop["to"])
		way = _arrival(at_node, e)
	return count


func _try_run(count: int) -> void:
	if count <= 0 or at_dock() < 0:
		return
	for need: Array in _call_needs:
		if points[int(need[0])].live_leg() != int(need[1]):
			if not points[int(need[0])].actuator.powered:
				_call_detail = "waiting for the points at %s (no power)" \
						% points[int(need[0])].points_id
			return
	var here := at_dock()
	var last := int((_call_hops[count - 1] as Dictionary)["to"])
	var way := _departure(here, int((_call_hops[0] as Dictionary)["edge"]))
	var run := _walk(line, offset, way, last)
	if run.has("reason"):
		_end_call("refused", str(run["detail"]))
		return
	# THE WALK MUST BE THE PLAN. Points set by the call and locked are
	# what it walks through, so this can only fail if something else
	# changed the network; if it does, the call stops rather than going
	# somewhere it was not asked to.
	var planned: Array[int] = []
	for i in count:
		planned.append(int((_call_hops[i] as Dictionary)["to"]))
	if (run["docks"] as Array[int]) != planned:
		_end_call("refused", "the track no longer runs the planned way")
		return
	for _i in count:
		_call_hops.pop_front()
	_call_needs.clear()
	_dispatch_call(run, count)


func _dispatch_call(run: Dictionary, _hops: int) -> void:
	var from := at_dock()
	_start(run, from if from >= 0 else _left)
	_call_state = "executing"
	_call_detail = "travelling to %s" % dock_id(_call)
	call_changed.emit(dock_id(_call), "executing", _call_detail)
	departed.emit(dock_id(from if from >= 0 else _left), heading)


func _arrived_on_call(_landed: int) -> void:
	if _call_hops.is_empty():
		_end_call("completed", "the carrier is at %s" % dock_id(_call))
		return
	_next_run()


# ---------------------------------------------------------------------------
# Track
# ---------------------------------------------------------------------------

## The rails a player sees: every line swept as beams, except where a
## stretch is not commissioned (the gap is real, as the scenario's is)
## and the first metres of each leg, where the tongue is the track.
func _lay_track(root: Node3D) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var beam := ThemeMaterials.trim_mat(_theme)
	for l in lines.size():
		var rail: RailPath = lines[l]["path"]
		var line_ends: Array = lines[l]["ends"]
		var sweep := AffordanceFeatures.rail_sweep_points(rail)
		for i in sweep.size() - 1:
			var a: Vector3 = sweep[i]
			var b: Vector3 = sweep[i + 1]
			var mid := rail.nearest_offset((a + b) * 0.5)
			if _gap_at(l, mid) >= 0:
				continue
			if _under_tongue(l, mid, line_ends, rail):
				continue
			var slab := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.5, 0.3, a.distance_to(b))
			slab.mesh = mesh
			slab.material_override = beam
			root.add_child(slab)
			slab.global_position = (a + b) * 0.5
			if (b - a).length() > 0.001:
				slab.basis = Basis.looking_at(-(b - a).normalized(),
						Vector3.UP)
			made.append(slab)
	return made


func _under_tongue(l: int, along: float, line_ends: Array,
		rail: RailPath) -> bool:
	for end: int in [START, END]:
		var k := int(line_ends[end])
		if k < 0 or points[k].is_heel(Vector2i(l, end)):
			continue
		var from := 0.0 if end == START else rail.length()
		if absf(along - from) < RailPoints.TONGUE_LENGTH:
			return true
	return false
