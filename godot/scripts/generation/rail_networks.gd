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
## **WHAT THIS REFUSES, AND WHY IT REFUSES RATHER THAN GUESSES.**
## `RailCarrier` runs ONE ordered route: docks along a path, and a link
## between each consecutive pair. `RailNetwork.spans` declares a graph --
## `from_dock` and `to_dock` may be any two of up to eight docks -- so a
## span between the first and third dock has no link on that route and no
## meaning the engine can honour. Inventing one (routing the carrier
## through the dock in between, say) would be the engine deciding what a
## Zone meant, which is the boundary this file exists to keep.
##
## So a non-adjacent span is REFUSED BY NAME and the network is not
## built. The refusal is returned rather than pushed as an error, so a
## caller can report it as a composition finding instead of a crash.
## `docs/ledgers/HUGE_BATCH_LEDGER.md` carries it to the bridge lane as
## a concrete, bounded question: either `spans` are required to join
## consecutive docks, or the carrier needs to become graph-capable, and
## that is a decision rather than a gap to paper over.

## How far above a room's arrival the rail runs. The deck rides on the
## path, so the path is one deck-height up and a player steps ON rather
## than INTO it.
const RAIL_LIFT := 0.6
const DECK := Vector3(3.4, 0.35, 5.0)
## Where the alignment control stands in its room, relative to arrival.
const CONTROL_OFFSET := Vector3(2.2, 0.0, 0.0)

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
		theme := "concrete_facility") -> Dictionary:
	var junctions: Array[RailJunction] = []
	var carriers: Array[RailCarrier] = []
	var refused: Array[String] = []
	for raw: Variant in networks:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var net: Dictionary = raw
		var made := _one(root, net, places, theme)
		var why := str(made.get("refused", ""))
		if why != "":
			refused.append(why)
			continue
		junctions.append(made["junction"] as RailJunction)
		carriers.append(made["carrier"] as RailCarrier)
	return {"junctions": junctions, "carriers": carriers,
			"refused": refused}


static func _one(root: Node3D, net: Dictionary, places: Dictionary,
		theme: String) -> Dictionary:
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
			var place: Dictionary = places[control_room]
			control.global_position = (place.get("arrival", Vector3.ZERO)
					as Vector3) + CONTROL_OFFSET
			control.operated.connect(
					func(_c: AlignmentControl) -> void: span.begin())
		junction.add(span, control)

	# PARKED AT THE FIRST DECLARED DOCK. The contract does not say which
	# dock a carrier starts at, and `RailJunction.park` defaults to 0 --
	# so this is an engine assumption, written down here and raised as a
	# `home_dock` question rather than left as behaviour nobody declared.
	junction.park(0)
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
