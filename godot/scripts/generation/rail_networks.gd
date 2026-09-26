class_name RailNetworks
extends RefCounted
## THE ENGINE HALF OF `Zone.rail_networks` (D-4).
##
## The bridge lane's schema (`schemas/zone.py`, landed `704f379`) lets a
## Zone declare rail content first class -- docks in named rooms, spans
## between them, one alignment control per span, a latch per span --
## because a span on the mandatory path could never be a `feature`:
## §13.2 forbids a feature from lying on the mandatory path, and an
## optional span is not a railway.
##
## This is what reads that declaration and builds it. Nothing here
## invents a Zone's intent and nothing there invents a coordinate:
## Epsilon names WHICH rooms and WHICH spans, and the engine owns every
## metre, exactly as `ZoneBuilder` owns where a room goes.
##
## **What a declaration turns into.** One `RailPath` through the declared
## docks' rooms, a `RailCarrier` parked at the first, a `RailJunction`
## whose `package_id` is the network id, and one `RailSpan` per declared
## span carrying that span's `latch_id` -- which is the handle the
## commissioned link persists under, and the reason the schema refuses
## two spans sharing one.
##
## **A span with no control ships commissioned.** `control_room_id` is
## nullable and the schema says what that means: the span needs no
## control. So that link starts `true` and no lever is built.
##
## **A span whose control is on a gantry** (`control_placement: gantry`,
## D-6 and D-9) gets the development scenario's measured gantry in its
## control room instead of a lever at the arrival -- out of the base
## kit's reach, as the AP logic's `grapple` says. `gantry_frame` places
## it; a room that cannot hold one refuses the whole network, as below.
##
## **WHAT THIS REFUSES, AND WHAT THAT REFUSAL DOES AND DOES NOT MEAN.**
##
## `RailCarrier` runs ONE ordered route: docks along a path, and a link
## between each consecutive pair. So a span between non-adjacent docks
## has no link on that route and no meaning THIS IMPLEMENTATION can
## honour. Inventing one -- routing the carrier through the dock in
## between, say -- would be the engine deciding what a Zone meant, which
## is the boundary this file exists to keep. It is refused by name, the
## network builds nothing, and the Zone still builds.
##
## **THIS IS A STATEMENT ABOUT THE CURRENT IMPLEMENTATION, NOT ABOUT THE
## DESIGN** (owner correction, 2026-09-22). Branching and switchable
## railway configurations are NOT retired from the accepted design by
## this restriction; they are unbuilt. The schema now refuses a
## non-adjacent span (F-24) precisely so an unbuildable Zone cannot be
## composed in the meantime, and Dess's own note says the answer is the
## one that can be taken back: relaxing it later invalidates no Zone that
## ever satisfied it.
##
## **What a branching railway would need, so the scope is visible rather
## than implied:** a carrier whose route is a graph rather than an
## ordered list (`dock_offsets` and `commissioned` are both indexed by
## position along one path), a switch actuator at the branching dock and
## a rule for which way it is set, and a reachability search that can
## tell the two branches apart. That is real engine work to be scoped,
## which is why it is named here instead of being half-started.

## How far above a room's arrival the rail runs. The deck rides on the
## path, so the path is one deck-height up and a player steps ON rather
## than INTO it.
const RAIL_LIFT := 0.6
const DECK := Vector3(3.4, 0.35, 5.0)
## Where the alignment control stands in its room, relative to arrival.
const CONTROL_OFFSET := Vector3(2.2, 0.0, 0.0)

## D-6 STEP 3 (Dess's note D-9): A GANTRY CONTROL, for a span whose
## `control_placement` is `gantry`. The development scenario's gantry
## (`railway_scenario.gd`), measured there and carried here RELATIVE TO
## THE FLOOR THE PLAYER GRAPPLES FROM, because that relation is what was
## proven: from its platform the deck's top stood 2.9 m up and the plate
## 6.2 m up, over the deck's near lip, 1.5 m out from where the player
## stood. A standing jump tops out at 1.33 m and there is no mantle, so
## the deck is out of the base kit's reach; a 14 m/s pull tops out
## 4.45 m above where it started, so the proven grapple
## (`FEATURED_REQUIREMENTS["grapple"]`) carries a body onto it.
##
## **NO STAIRS.** The owner's rule, not a placeholder: a walking bypass to
## the control is a loop the player can skip.
const GANTRY_DECK := Vector3(4.0, 0.4, 4.0)
const GANTRY_DECK_TOP := 2.9
const GANTRY_PLATE_UP := 6.2
## From the approach mark to the point under the plate (the near lip).
const GANTRY_APPROACH := 1.5
## From the room's arrival to the approach mark.
const GANTRY_INSET := 2.0
## Clearance the deck and the approach keep from the room's walls and
## from the carrier.
const GANTRY_MARGIN := 0.5
## The spacing of the approach marks the placement tries.
const GANTRY_STEP := 1.0
## The height field the base kit's reach is measured on: one downward
## ray per cell, and up to this many standable surfaces stacked in one
## (a gallery over its floor, a crate on the floor).
const REACH_CELL := 0.5
const REACH_LAYERS := 4
## A surface exactly at the jump's apex is one a capsule can catch the
## edge of, so a tie counts as reached -- decided here, not by float noise
## in a ray's hit height.
const CLIMB_TOLERANCE := 0.02
## Steepest surface a body stands on: CharacterBody3D's default
## `floor_max_angle`, which `player.gd` does not change.
const STANDABLE_ANGLE := deg_to_rad(45.0)

## Build every network a Zone declares.
##
## `places` is `ZoneController.room_places` -- position, yaw and arrival
## per room id, off the committed layout. Reading it rather than
## re-deriving a transform is the same rule the controller already keeps:
## two answers to "where is c014" is one answer too many.
##
## Returns `{"junctions": [...], "carriers": [...], "refused": [...]}`.
## `refused` is a list of human-readable reasons, and a network that
## appears there built nothing at all.
static func build(root: Node3D, networks: Array, places: Dictionary,
		theme := "concrete_facility", bounds := {}) -> Dictionary:
	var junctions: Array[RailJunction] = []
	var carriers: Array[RailCarrier] = []
	var refused: Array[String] = []
	for raw: Variant in networks:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var net: Dictionary = raw
		var made := _one(root, net, places, theme, bounds)
		var why := str(made.get("refused", ""))
		if why != "":
			refused.append(why)
			continue
		junctions.append(made["junction"] as RailJunction)
		carriers.append(made["carrier"] as RailCarrier)
	return {"junctions": junctions, "carriers": carriers,
			"refused": refused}


static func _one(root: Node3D, net: Dictionary, places: Dictionary,
		theme: String, bounds := {}) -> Dictionary:
	var network_id := str(net.get("network_id", "rail"))
	var docks: Array = net.get("docks", []) as Array
	var spans: Array = net.get("spans", []) as Array
	if docks.size() < 2:
		return {"refused": "network '%s' declares %d dock(s)"
				% [network_id, docks.size()]}
	# WHERE EACH DOCK IS, off the committed layout and nowhere else. A
	# dock in a room the Zone does not have is the schema's own refusal
	# (`_rail_networks_name_rooms_this_zone_has`), but a Zone that
	# reached the engine with one anyway must not be built half way.
	var ids := PackedStringArray()
	var points := PackedVector3Array()
	var order := {}
	for entry: Variant in docks:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dock: Dictionary = entry
		var rid := str(dock.get("room_id", ""))
		if not places.has(rid):
			return {"refused": "network '%s' docks in room '%s', which "
					% [network_id, rid] + "this Zone did not build"}
		var place: Dictionary = places[rid]
		var arrival: Vector3 = place.get("arrival", Vector3.ZERO)
		order[str(dock.get("dock_id", ""))] = ids.size()
		ids.append(str(dock.get("dock_id", "")))
		points.append(arrival + Vector3(0.0, RAIL_LIFT, 0.0))
	if ids.size() < 2:
		return {"refused": "network '%s' resolved %d dock(s)"
				% [network_id, ids.size()]}

	# THE LINKS, one per consecutive pair, and every one of them starts
	# CONNECTED unless a declared span says otherwise. A link nothing
	# declares is ordinary track.
	var links: Array[bool] = []
	for _i in range(ids.size() - 1):
		links.append(true)
	var placed: Array = []
	for entry: Variant in spans:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var span: Dictionary = entry
		var from_id := str(span.get("from_dock", ""))
		var to_id := str(span.get("to_dock", ""))
		if not order.has(from_id) or not order.has(to_id):
			return {"refused": "span '%s' names a dock network '%s' "
					% [str(span.get("span_id", "")), network_id]
					+ "does not declare"}
		var a: int = order[from_id]
		var b: int = order[to_id]
		# THE REFUSAL. See this file's header: a carrier runs one ordered
		# route, so only a consecutive pair has a link to commission.
		if absi(a - b) != 1:
			return {"refused": ("span '%s' joins docks %d and %d of "
					% [str(span.get("span_id", "")), a, b])
					+ ("network '%s', which are not consecutive; a "
						% network_id)
					+ "carrier runs one ordered route and has no link "
					+ "between them. Either spans join neighbouring "
					+ "docks or the carrier must become graph-capable "
					+ "-- a decision, not a gap to guess at"}
		var link := mini(a, b)
		var control_room := str(span.get("control_room_id", ""))
		if control_room != "" and control_room != "<null>":
			# NOT COMMISSIONED YET: this is the link a player has to
			# earn, so the carrier starts refusing it.
			links[link] = false
		placed.append({"span": span, "link": link,
				"control_room": control_room})

	var rail := RailPath.from_points(points)
	if rail == null:
		return {"refused": "network '%s' could not lay a path through "
				% network_id + "%d dock(s)" % points.size()}
	# A GANTRY IS MEASURED BEFORE ANYTHING IS BUILT. One that does not fit
	# refuses the whole network, like every refusal above: half a railway
	# -- a span with no way to its control -- is worse than none.
	var gantries: Dictionary = {}
	var track := rail.polyline(REACH_CELL)
	for made: Variant in placed:
		var one: Dictionary = made
		var span_dict: Dictionary = one["span"]
		if str(span_dict.get("control_placement", "ground")) != "gantry":
			continue
		var room := str(one["control_room"])
		for other: String in gantries:
			if str((gantries[other] as Dictionary)["room"]) == room:
				return {"refused": "span '%s' puts its gantry in room '%s', "
						% [str(span_dict.get("span_id", "")), room]
						+ "which already holds span '%s''s; the measured "
						% other + "gantry stands one to a room"}
		var frame := gantry_frame(root, places.get(room, {}),
				bounds.get(room, AABB()), track)
		if frame.has("refused"):
			return {"refused": "span '%s' puts its gantry in room '%s': %s"
					% [str(span_dict.get("span_id", "")), room,
						frame["refused"]]}
		frame["room"] = room
		gantries[str(span_dict.get("span_id", ""))] = frame

	# WHERE EACH DOCK SITS ALONG THE PATH. `from_points` bakes a curve
	# through the control points, so a dock's offset is the arc length to
	# its own point rather than the straight-line distance -- a bowed
	# route would otherwise park the carrier short of every dock after
	# the first.
	var offsets := PackedFloat32Array()
	for i in points.size():
		offsets.append(_offset_of(rail, points[i]))

	var carrier := RailCarrier.create(rail, offsets, ids, links, DECK,
			theme)
	carrier.name = "RailCarrier_%s" % network_id
	root.add_child(carrier)
	var controls := RailControls.create(carrier)
	root.add_child(controls)
	var junction := RailJunction.create(carrier, network_id)
	root.add_child(junction)

	for made: Variant in placed:
		var one: Dictionary = made
		var span_dict: Dictionary = one["span"]
		var link: int = one["link"]
		var pivot := Node3D.new()
		pivot.name = "SpanPivot_%s" % str(span_dict.get("span_id", ""))
		root.add_child(pivot)
		pivot.global_position = rail.at(offsets[link])
		pivot.basis = Basis.looking_at(-rail.tangent(offsets[link]),
				Vector3.UP)
		var span := RailSpan.create(str(span_dict.get("latch_id", "")),
				link, offsets[link + 1] - offsets[link], theme)
		pivot.add_child(span)
		var control: AlignmentControl = null
		var control_room := str(one["control_room"])
		if control_room != "" and places.has(control_room):
			control = AlignmentControl.create(
					"ALIGN %s" % str(span_dict.get("span_id", "")).to_upper(),
					theme)
			root.add_child(control)
			var span_id := str(span_dict.get("span_id", ""))
			if gantries.has(span_id):
				_build_gantry(root, gantries[span_id], control, span_id, theme)
			else:
				var place: Dictionary = places[control_room]
				control.global_position = (place.get("arrival",
						Vector3.ZERO) as Vector3) + CONTROL_OFFSET
			control.operated.connect(
					func(_c: AlignmentControl) -> void: span.begin())
		junction.add(span, control)

	# PARKED WHERE THE ZONE SAYS, which it can say now.
	#
	# This read `park(0)` with a note that the contract had no
	# `home_dock` and the engine was assuming one. F-22 raised it; F-24
	# answered it: `home_dock` names a declared dock, and `null` means
	# the first -- the same default, so nothing built before this changes
	# and what was an engine assumption is now a declaration.
	var home := str(net.get("home_dock", ""))
	junction.home_dock = int(order.get(home, 0)) \
			if home != "" and home != "<null>" else 0
	junction.park()
	return {"junction": junction, "carrier": carrier}


## Arc length along `rail` to the control point nearest `at`.
##
## `RailPath` bakes its curve, so the offset a carrier parks at is an arc
## length and the control points are Cartesian. Sampling the baked curve
## for the closest point is the path's own answer to "how far along is
## this", rather than a second one computed from the raw points.
static func _offset_of(rail: RailPath, at: Vector3) -> float:
	var curve := rail.curve()
	if curve == null:
		return 0.0
	return curve.get_closest_offset(at)


# ---------------------------------------------------------------------------
# D-6 step 3: the gantry
# ---------------------------------------------------------------------------

## WHERE A GANTRY STANDS IN A ROOM, or why it cannot.
##
## **SEARCHED, NEAREST THE ARRIVAL FIRST.** The scenario's order is the
## design's: the gantry is seen on arriving, the branch supplies the
## tool, and the player comes back to open what they had already seen.
## So candidate positions -- an approach mark every `GANTRY_STEP` over
## the room's floor, the gantry running along each of the room's four
## axes from it -- are tried by the deck's distance from the arrival,
## and the first that passes every test below is the gantry. The order
## is total, so a room gives the same gantry on every build.
##
## **MEASURED, NOT ASSUMED** (Dess's D-9: clear floor for the deck and
## the approach is the engine's refusal). A candidate passes when:
##   - its footprint -- from where the player stands behind the mark to
##     the deck's far edge, `GANTRY_MARGIN` to spare -- is inside the
##     room;
##   - no track passes within the carrier's half-width and a rider's
##     radius of it: a control room is usually a dock room, and a deck
##     across the track is a carrier that cannot pass;
##   - the approach and the post stand on floor at the arrival's height,
##     which the measured pull is relative to;
##   - the column the pull climbs, the space over the deck and the post
##     hold no collider (`_frame_at`);
##   - and the base kit cannot reach the deck (`deck_reached`).
## Returns `{"approach", "under_plate", "deck_centre", "plate", "away"}`,
## or `{"refused": why}` with how many candidates failed each test.
static func gantry_frame(root: Node3D, place: Dictionary, box: AABB,
		track := PackedVector3Array()) -> Dictionary:
	if place.is_empty() or box.size == Vector3.ZERO:
		return {"refused": "the room has no committed place"}
	var arrival: Vector3 = place.get("arrival", Vector3.ZERO)
	var floor_y := arrival.y
	if floor_y + GANTRY_PLATE_UP + 0.6 > box.end.y:
		return {"refused": "the plate needs %.1f m of height and the room "
				% (GANTRY_PLATE_UP + 0.6) + "has %.1f m"
				% (box.end.y - floor_y)}
	var turn := Basis(Vector3.UP, float(place.get("yaw", 0.0)))
	var axes: Array[Vector3] = []
	for axis: Vector3 in [turn.z, -turn.z, turn.x, -turn.x]:
		axes.append(Vector3(axis.x, 0.0, axis.z).normalized())
	var candidates: Array = []
	var inset := ChamberBuilders.WALL_THICKNESS
	var lead := GANTRY_APPROACH + GANTRY_DECK.z * 0.5
	var x0 := box.position.x + inset
	var z0 := box.position.z + inset
	var ix := 0
	while x0 + (ix + 0.5) * GANTRY_STEP < box.end.x - inset:
		var iz := 0
		while z0 + (iz + 0.5) * GANTRY_STEP < box.end.z - inset:
			var at := Vector3(x0 + (ix + 0.5) * GANTRY_STEP, floor_y,
					z0 + (iz + 0.5) * GANTRY_STEP)
			for a in axes.size():
				var deck := at + axes[a] * lead
				candidates.append([snappedf(Vector2(deck.x - arrival.x,
						deck.z - arrival.z).length(), 0.001), ix, iz, a, at])
			iz += 1
		ix += 1
	candidates.sort_custom(func(p: Array, q: Array) -> bool:
		for k in 4:
			if p[k] != q[k]:
				return p[k] < q[k]
		return false)
	var space := root.get_world_3d().direct_space_state
	var field: Dictionary = {}
	var failed := {"outside the room": 0, "on the track": 0,
			"off the floor": 0, "not clear": 0, "within the base kit's reach": 0}
	var first_reach := ""
	for candidate: Array in candidates:
		var frame := _frame_at(space, box, track, candidate[4],
				axes[candidate[3]], field)
		if not frame.has("refused"):
			return frame
		failed[frame["refused"]] += 1
		if frame["refused"] == "within the base kit's reach" \
				and first_reach == "":
			first_reach = str(frame.get("why", ""))
	var parts: Array[String] = []
	for test: String in failed:
		if int(failed[test]) > 0:
			parts.append("%d %s" % [failed[test], test])
	return {"refused": "no position in the room takes the measured gantry "
			+ "(%d tried: %s)" % [candidates.size(), ", ".join(parts)]
			+ ("; nearest the arrival, %s" % first_reach
				if first_reach != "" else "")}


## One candidate: the approach mark at `approach`, the gantry running
## `away` from it. `field` is the room's reach field, measured on first
## need and kept for the next candidate.
##
## **What must be clear is what the player uses:** the column the pull
## climbs, from behind the approach mark to past the plate; the space
## over the deck, a standing body high; and the post. The floor under
## the deck is not a path -- the deck stands on a post -- so a crate
## there is a crate under a gantry; whether it could be a step onto the
## deck is the reach field's question, not this one's.
static func _frame_at(space: PhysicsDirectSpaceState3D, box: AABB,
		track: PackedVector3Array, approach: Vector3, away: Vector3,
		field: Dictionary) -> Dictionary:
	var across := Vector3(-away.z, 0.0, away.x)
	var under_plate := approach + away * GANTRY_APPROACH
	var deck_centre := under_plate + away * (GANTRY_DECK.z * 0.5) \
			+ Vector3.UP * (GANTRY_DECK_TOP - GANTRY_DECK.y * 0.5)
	var plate := under_plate + Vector3.UP * GANTRY_PLATE_UP
	# THE FOOTPRINT: from where the player stands behind the mark to the
	# deck's far edge, the deck's width.
	var back := Constants.PLAYER_RADIUS + GANTRY_MARGIN
	var half_len := (back + GANTRY_APPROACH + GANTRY_DECK.z) * 0.5
	var half_wid := GANTRY_DECK.x * 0.5
	var mid := approach + away * (half_len - back)
	for corner: Vector3 in [
			mid + away * (half_len + GANTRY_MARGIN)
				+ across * (half_wid + GANTRY_MARGIN),
			mid + away * (half_len + GANTRY_MARGIN)
				- across * (half_wid + GANTRY_MARGIN),
			mid - away * (half_len + GANTRY_MARGIN)
				+ across * (half_wid + GANTRY_MARGIN),
			mid - away * (half_len + GANTRY_MARGIN)
				- across * (half_wid + GANTRY_MARGIN)]:
		if corner.x < box.position.x or corner.x > box.end.x \
				or corner.z < box.position.z or corner.z > box.end.z:
			return {"refused": "outside the room"}
	# OFF THE TRACK: the carrier's half-width and a rider's radius, so
	# nobody riding past passes under the deck or through the column.
	var clear := DECK.x * 0.5 + Constants.PLAYER_RADIUS
	for point: Vector3 in track:
		if point.y < box.position.y or point.y > box.end.y:
			continue
		var rel := Vector3(point.x - mid.x, 0.0, point.z - mid.z)
		if Vector2(maxf(absf(rel.dot(away)) - half_len, 0.0),
				maxf(absf(rel.dot(across)) - half_wid, 0.0)).length() < clear:
			return {"refused": "on the track"}
	if field.is_empty():
		field.merge(reach_field(space, box, approach.y))
	if not _is_floor(field, approach) \
			or not _is_floor(field, deck_centre):
		return {"refused": "off the floor"}
	var body := Constants.PLAYER_RADIUS + 0.2
	var column_len := back + GANTRY_APPROACH + 0.6
	var over_deck := Constants.PLAYER_HEIGHT + 0.2 + GANTRY_DECK.y
	for volume: Array in [
			# The column the pull climbs: the plate's width and a body
			# either side, from knee height to over the plate.
			[Vector3(1.2 + 2.0 * body, GANTRY_PLATE_UP + 0.05, column_len),
				approach + away * (column_len * 0.5 - back)
				+ Vector3.UP * (0.4 + (GANTRY_PLATE_UP + 0.05) * 0.5)],
			# Over the deck: its footprint, from its underside to a
			# standing body's head.
			[Vector3(GANTRY_DECK.x, over_deck, GANTRY_DECK.z),
				Vector3(deck_centre.x, deck_centre.y - GANTRY_DECK.y * 0.5
					+ over_deck * 0.5, deck_centre.z)],
			# The post.
			[Vector3(0.6, GANTRY_DECK_TOP - GANTRY_DECK.y - 0.1, 0.6),
				Vector3(deck_centre.x, approach.y + 0.05
					+ (GANTRY_DECK_TOP - GANTRY_DECK.y - 0.1) * 0.5,
					deck_centre.z)]]:
		var shape := BoxShape3D.new()
		shape.size = volume[0]
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.looking_at(away, Vector3.UP),
				volume[1])
		if not space.intersect_shape(query, 1).is_empty():
			return {"refused": "not clear"}
	var frame := {"approach": approach, "under_plate": under_plate,
			"deck_centre": deck_centre, "plate": plate, "away": away}
	var why := deck_reached(field, frame)
	if why != "":
		return {"refused": "within the base kit's reach", "why": why}
	return frame


## **THE ROOM'S REACH FIELD: what the base kit can stand on.**
##
## "A standing jump tops out at 1.33 m and there is no mantle" is true of
## the floor under a deck, and says nothing about a gallery two metres
## up and four across. A deck the base kit can jump onto from one is a
## stair by another name: the loop the owner ruled out, and a gate the AP
## logic declares (`grapple`) that the room does not hold.
##
## So the room's standable surfaces are sampled -- one ray down per
## `REACH_CELL`, up to `REACH_LAYERS` deep -- and filled from the floor
## with what the base kit does (`stepped_apex`, `jump_reach`):
## climbing to the eight neighbouring cells, then jumping across gaps
## (`jump_reach`), until nothing new is reached.
##
## **IT ERRS ONE WAY.** Walls are not in the field, a jump is not blocked
## by what stands between, a surface counts as far as its cell reaches,
## and floor inside a solid counts as floor. Each can only add reach: a
## room this refuses might have been safe; a room it passes is not one
## the base kit climbs out of. What it cannot see is anything built
## after the railways (a room graph's devices) and objects a player
## moves.
static func reach_field(space: PhysicsDirectSpaceState3D, box: AABB,
		floor_y: float) -> Dictionary:
	var inset := ChamberBuilders.WALL_THICKNESS
	var x0 := box.position.x + inset
	var z0 := box.position.z + inset
	var nx := maxi(int(floor((box.size.x - 2.0 * inset) / REACH_CELL)), 0)
	var nz := maxi(int(floor((box.size.z - 2.0 * inset) / REACH_CELL)), 0)
	var top := box.end.y - 0.05
	var bottom := box.position.y - 0.1
	var min_up := cos(STANDABLE_ANGLE)
	# Node i: a standable surface `heights[i]` above the floor, in cell
	# (`xs[i]`, `zs[i]`).
	var heights := PackedFloat32Array()
	var xs := PackedInt32Array()
	var zs := PackedInt32Array()
	var in_cell: Array = []
	in_cell.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var here: Array[int] = []
			var x := x0 + (ix + 0.5) * REACH_CELL
			var z := z0 + (iz + 0.5) * REACH_CELL
			var from := Vector3(x, top, z)
			for _layer in REACH_LAYERS:
				if from.y <= bottom:
					break
				var hit := space.intersect_ray(
						PhysicsRayQueryParameters3D.create(from,
							Vector3(x, bottom, z)))
				if hit.is_empty():
					break
				var at: Vector3 = hit["position"]
				if (hit["normal"] as Vector3).y >= min_up:
					here.append(heights.size())
					heights.append(at.y - floor_y)
					xs.append(ix)
					zs.append(iz)
				# Just under what was hit: a ray that starts inside a
				# solid does not see it, so the next is the next surface.
				from = Vector3(x, at.y - 0.05, z)
			in_cell[iz * nx + ix] = here
	var n := heights.size()
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-2)
	var queue: Array[int] = []
	for i in n:
		if absf(heights[i]) <= 0.25:
			came[i] = -1
			queue.append(i)
	var apex := stepped_apex() + CLIMB_TOLERANCE
	while true:
		# CLIMBING, to the eight neighbours.
		while not queue.is_empty():
			var i: int = queue.pop_back()
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var ex: int = xs[i] + dx
					var ez: int = zs[i] + dz
					if ex < 0 or ez < 0 or ex >= nx or ez >= nz:
						continue
					for j: int in in_cell[ez * nx + ex] as Array:
						if came[j] == -2 and heights[j] <= heights[i] + apex:
							came[j] = i
							queue.append(j)
		# JUMPING ACROSS, from anything reached to anything not.
		var sources: Array[int] = []
		for i in n:
			if came[i] != -2:
				sources.append(i)
		for j in n:
			if came[j] != -2:
				continue
			for i: int in sources:
				if heights[j] > heights[i] + apex:
					continue
				var d := Vector2(xs[j] - xs[i], zs[j] - zs[i]).length() \
						* REACH_CELL
				if d <= jump_reach(heights[i], heights[j]):
					came[j] = i
					queue.append(j)
					break
		if queue.is_empty():
			break
	# THE HIGH GROUND: what reached surface a jump could take onto a deck.
	var high: Array[int] = []
	for i in n:
		if came[i] != -2 and heights[i] + apex >= GANTRY_DECK_TOP:
			high.append(i)
	return {"x0": x0, "z0": z0, "nx": nx, "nz": nz, "heights": heights,
			"xs": xs, "zs": zs, "in_cell": in_cell, "came": came,
			"high": high}


## Whether the field has reached floor, at the arrival's height, under
## `at`.
static func _is_floor(field: Dictionary, at: Vector3) -> bool:
	var ix := int(floor((at.x - float(field["x0"])) / REACH_CELL))
	var iz := int(floor((at.z - float(field["z0"])) / REACH_CELL))
	if ix < 0 or iz < 0 or ix >= int(field["nx"]) or iz >= int(field["nz"]):
		return false
	var heights: PackedFloat32Array = field["heights"]
	var came: PackedInt32Array = field["came"]
	for i: int in (field["in_cell"] as Array)[iz * int(field["nx"]) + ix] \
			as Array:
		if absf(heights[i]) <= 0.15 and came[i] != -2:
			return true
	return false


## Whether the base kit reaches a deck at `frame`: "" or from where. A
## deck is reached when a surface the field reached is within a jump of
## any of its cells.
static func deck_reached(field: Dictionary, frame: Dictionary) -> String:
	var high: Array[int] = field["high"]
	if high.is_empty():
		return ""
	var away: Vector3 = frame["away"]
	var across := Vector3(-away.z, 0.0, away.x)
	var deck: Vector3 = frame["deck_centre"]
	var heights: PackedFloat32Array = field["heights"]
	var xs: PackedInt32Array = field["xs"]
	var zs: PackedInt32Array = field["zs"]
	var x0 := float(field["x0"])
	var z0 := float(field["z0"])
	for iz in int(field["nz"]):
		for ix in int(field["nx"]):
			var at := Vector3(x0 + (ix + 0.5) * REACH_CELL, 0.0,
					z0 + (iz + 0.5) * REACH_CELL)
			var rel := at - Vector3(deck.x, 0.0, deck.z)
			if absf(rel.dot(away)) > GANTRY_DECK.z * 0.5 \
					or absf(rel.dot(across)) > GANTRY_DECK.x * 0.5:
				continue
			for i: int in high:
				var d := Vector2(ix - xs[i], iz - zs[i]).length() * REACH_CELL
				if d <= jump_reach(heights[i], GANTRY_DECK_TOP):
					return ("a jump from a surface %.1f m up, %.1f m from "
							% [heights[i], d]
							+ "the deck, lands on it %.1f m up"
							% GANTRY_DECK_TOP)
	return ""


## The measurement on its own, for a suite: whether the base kit reaches
## a deck at `frame` in this room.
static func base_kit_bypass(space: PhysicsDirectSpaceState3D, box: AABB,
		floor_y: float, frame: Dictionary) -> String:
	return deck_reached(reach_field(space, box, floor_y), frame)


## THE BASE KIT'S JUMP AS THE PHYSICS STEPS IT. `JUMP_APEX_HEIGHT` is
## v^2/2g, the continuous figure; `player.gd` integrates explicitly at
## `physics_ticks_per_second`, which peaks half a step higher -- 1.40 m
## at 60 Hz, and `godot-rail-gantry` measures the played jump against
## it. The field uses the higher, since it errs toward reach.
static func stepped_apex() -> float:
	return Constants.JUMP_APEX_HEIGHT + Constants.JUMP_VELOCITY \
			/ (2.0 * float(Engine.physics_ticks_per_second))


## How far, horizontally, the base kit carries a body from a surface at
## `from_h` onto one at `to_h` -- or -1 when a jump never gets there.
## The time aloft until it comes down through `to_h`, plus coyote time,
## at walking speed; plus both capsule radii and a cell's diagonal, since
## the field knows a surface only to its cell.
static func jump_reach(from_h: float, to_h: float) -> float:
	var g := Constants.GRAVITY
	var v := sqrt(2.0 * g * stepped_apex())
	var disc := v * v - 2.0 * g * (to_h - from_h)
	if disc < 0.0:
		return -1.0
	var aloft := (v + sqrt(disc)) / g
	return Constants.WALK_SPEED * (aloft + Constants.COYOTE_TIME) \
			+ 2.0 * Constants.PLAYER_RADIUS + REACH_CELL * sqrt(2.0)


## The deck, its post, the plate the hookshot bites, and the control on
## the deck facing the approach. No stairs.
static func _build_gantry(root: Node3D, frame: Dictionary,
		control: AlignmentControl, span_id: String, theme: String) -> void:
	var away: Vector3 = frame["away"]
	var deck_centre: Vector3 = frame["deck_centre"]
	var gantry := Node3D.new()
	gantry.name = "Gantry_%s" % span_id
	root.add_child(gantry)
	var deck := _slab(gantry, "Deck", GANTRY_DECK, deck_centre,
			ThemeMaterials.wall_mat(theme))
	deck.basis = Basis.looking_at(away, Vector3.UP)
	var post_height := deck_centre.y - GANTRY_DECK.y * 0.5 \
			- (frame["approach"] as Vector3).y
	_slab(gantry, "Post", Vector3(0.6, post_height, 0.6),
			Vector3(deck_centre.x, (frame["approach"] as Vector3).y
				+ post_height * 0.5, deck_centre.z),
			ThemeMaterials.trim_mat(theme))
	var plate: Vector3 = frame["plate"]
	_slab(gantry, "Plate", Vector3(1.2, 0.3, 1.2), plate,
			ThemeMaterials.trim_mat(theme))
	# THE RING: what a player reads from below. The deck hides the
	# control; the hook is what says "up there".
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.material_override = ThemeMaterials.glow_material(
			Constants.AFFORDANCE_SIGNAL, 1.8)
	gantry.add_child(ring)
	ring.global_position = plate - Vector3(0.0, 0.32, 0.0)
	control.global_position = deck_centre + Vector3.UP \
			* (GANTRY_DECK.y * 0.5 + AlignmentControl.BASE.y * 0.5)
	control.look_at(Vector3((frame["approach"] as Vector3).x,
			control.global_position.y, (frame["approach"] as Vector3).z),
			Vector3.UP)
	# WORKED FROM THE DECK, and only from it: see `worked_from`.
	control.worked_from = deck


static func _slab(parent: Node3D, node_name: String, size: Vector3,
		centre: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	body.add_child(mesh_node)
	parent.add_child(body)
	body.global_position = centre
	return body
