class_name RoomGraphs
extends RefCounted
## P14 — BUILD THE SIGNAL GRAPHS A ZONE DECLARES.
##
## `Zone.room_graphs` names a chain; this puts it in the room and wires
## it. The same move `RailNetworks` made for the railway: the Zone says
## WHAT, the engine decides WHERE, and a declaration the engine cannot
## honour is reported rather than half-built.
##
## **TWO KINDS OF ACTUATOR, and the Zone's edges say which.** An actuator
## that no `TopologyEdge.opened_by` names is a machine in the room: it is
## placed beside its plate and gates nothing. An actuator an edge DOES
## name stands ACROSS that edge's doorway, oriented from the committed
## socket frame, and it is the only thing between the two rooms. The
## bridge has already decided the second kind is legal (D-10 §5): the
## plate accepts the player, the chain is open once the plate has been
## stepped on and left, and the trigger is not behind the route it opens
## -- so no capability is asked of the edge, because the guaranteed base
## kit is enough.
##
## **AN UNBUILT GRAPH IS A COMPOSITION FINDING, NOT A CRASH.** Same
## posture as `RailNetworks`: refusals come back in a list, the Zone
## plays without that chain, and whoever authored it hears about it. For
## a route graph that means the doorway is simply open -- a gate that was
## not built strands nobody, which is the safe direction.
##
## **BUILT, NOT STARTED.** `build` returns graphs that have not evaluated
## anything. The controller restores the campaign's accepted latches and
## only then calls `start()`, so a route the save says is open is open on
## the first tick -- never commanded shut and then reopened in front of
## the player.

## A free-standing chain goes against the far wall (measured from where
## the player arrives), which is reliably emptier than the middle.
const CHAIN_CLEARANCE := 3.0
const CHAIN_SPREAD := 3.0

const PLATE_SIZE := Vector3(2.4, 0.12, 2.4)
const PANEL_SIZE := Vector3(2.0, 2.2, 0.3)
const PANEL_RISE := 2.4

## A ROUTE SHUTTER IS THE DOORWAY'S OWN SIZE. It is sized from the socket
## frame rather than from a constant, so a shell whose opening is not the
## procedural 2.4 x 3.2 is still closed. Thinner than the wall it stands
## in (0.4 m), so it sits inside the carved hole; it rises the opening's
## full height plus this much, so a standing capsule clears it.
## A SHUTTER THAT `TopologyEdge.opened_by` DECLARES, standing in its
## doorway. The layout probes ask whether an opening is a hole, and this
## one is: the gate in it is content, as a lock's slab is
## (`SpaceProbe.is_placed_content`). Only a declared gate joins the group.
## A shutter nobody declared, standing in a doorway, still measures solid,
## because that is the physical gate the route logic would not know about.
const ROUTE_GATE := "declared_route_gate"
const ROUTE_PANEL_DEPTH := 0.3
const ROUTE_PANEL_CLEARANCE := 0.4

## WHERE A ROUTE'S PLATE MAY GO: on this room's side of the doorway it
## opens, close enough that the player standing on it sees the door, and
## to one side of the door rather than in front of it -- so the door can
## be walked up to and found shut without the plate being crossed on the
## way. Candidates are tried in this order; the first one clear of the
## room's declared occupants and inside its walls wins.
const ROUTE_PLATE_INSETS := [3.0, 4.0, 5.0, 2.4]
const ROUTE_PLATE_SIDES := [3.2, -3.2, 4.4, -4.4, 5.6, -5.6]
## How far a plate's centre must be from anything the room already put
## down: an enemy spawn, the reward, a key, a doorway, the arrival, an
## activity element. A plate under a turret is a plate nobody can stand
## on, and c002's five artillery sit exactly where a blind rule put it.
const OCCUPANT_CLEARANCE := 2.6
## And from the walls, so the plate is walkable round.
const WALL_MARGIN := 0.8

#: §19.2's eleven, §20's eighteen and what each is narrowed to are all
#: GENERATED from `schemas/signal_graph.py`. Transcribing them here
#: would be a second vocabulary that could drift from the one the Zone
#: was validated against, which is the whole reason `export.py` exists.

const CLASS_OF := {"LIGHT": MassClass.LIGHT, "MEDIUM": MassClass.MEDIUM,
		"HEAVY": MassClass.HEAVY}


## Build every declared graph. Returns
## `{"graphs": Array[SignalGraph], "refused": Array[String]}`.
##
## `edges` is `Zone.edges`, read for `opened_by`; `chambers` is the
## builder's `build["chambers"]` (`{chamber, xform, build}`), read for
## each room's door plan and its declared occupants; `door_frames` is
## `build["door_frames"]`, the committed world frame of every doorway.
static func build(root: Node3D, graphs: Array, places: Dictionary,
		bounds: Dictionary, theme := "concrete_facility",
		edges: Array = [], chambers: Array = [],
		door_frames: Dictionary = {}) -> Dictionary:
	var made: Array[SignalGraph] = []
	var refused: Array[String] = []
	for raw: Variant in graphs:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var out := _one(root, raw as Dictionary, places, bounds, theme,
				edges, chambers, door_frames)
		var why := str(out.get("refused", ""))
		if why != "":
			refused.append(why)
			continue
		made.append(out["graph"] as SignalGraph)
	return {"graphs": made, "refused": refused}


static func _one(root: Node3D, declared: Dictionary, places: Dictionary,
		bounds: Dictionary, theme: String, edges: Array, chambers: Array,
		door_frames: Dictionary) -> Dictionary:
	var room_id := str(declared.get("room_id", ""))
	if not places.has(room_id):
		return {"refused": "a signal graph names room '%s', which this "
				% room_id + "Zone did not build"}
	var box: AABB = bounds.get(room_id, AABB())
	var place: Dictionary = place_of(places, room_id)
	var anchor: Vector3 = box.get_center() if box.size != Vector3.ZERO \
			else place.get("position", Vector3.ZERO) as Vector3
	# AWAY FROM WHERE THE PLAYER ARRIVES. A plate underfoot at the door
	# is a chain the player trips before they have seen it, and the
	# arrival point is the one position in the room that is certainly
	# occupied.
	var arrival: Vector3 = place.get("arrival", Vector3.ZERO)
	# **THE FLOOR IS WHERE THE PLAYER STANDS, not the bottom of the room
	# box.** `room_bounds` reaches about a metre BELOW the walkable
	# surface, so a plate placed at `box.position.y` sits under the floor
	# with nothing resting on it -- a crate dropped on it fell straight
	# past and was still falling a second later. The arrival point is a
	# foot contact point, which is exactly the height wanted.
	var floor_y := arrival.y
	var away := Vector3(anchor.x - arrival.x, 0.0, anchor.z - arrival.z)
	if away.length() < 0.5:
		away = Vector3.RIGHT
	away = away.normalized()
	var across := Vector3(-away.z, 0.0, away.x)
	var reach := absf(away.x) * box.size.x * 0.5 \
			+ absf(away.z) * box.size.z * 0.5
	var base := anchor + away * maxf(reach - CHAIN_CLEARANCE, 0.0)

	# WHICH DOORWAY EACH ACTUATOR STANDS IN, if any, resolved before
	# anything is built: a route actuator whose doorway cannot be found
	# refuses the whole graph rather than landing beside the plate, where
	# it would gate nothing while the edge still said it did.
	var doorway_of: Dictionary = {}
	for entry: Variant in declared.get("actuators", []) as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var actuator_id := str((entry as Dictionary).get("actuator_id", ""))
		var named: Array = []
		for raw_edge: Variant in edges:
			if typeof(raw_edge) != TYPE_DICTIONARY:
				continue
			if str((raw_edge as Dictionary).get("opened_by", "")) \
					== actuator_id and actuator_id != "":
				named.append(raw_edge)
		if named.is_empty():
			continue
		if named.size() > 1:
			return {"refused": "room '%s': actuator '%s' is named by %d "
					% [room_id, actuator_id, named.size()]
					+ "edges' opened_by; a shutter stands in one doorway"}
		var edge: Dictionary = named[0]
		var frame := doorway_frame(room_id, edge, chambers, door_frames)
		if frame.is_empty():
			return {"refused": "room '%s': actuator '%s' opens edge '%s', "
					% [room_id, actuator_id, str(edge.get("edge_id", ""))]
					+ "and this room built no doorway for that edge -- a "
					+ "shutter beside the plate would gate nothing"}
		doorway_of[actuator_id] = frame

	# THE ROOM'S DECLARED OCCUPANTS, in world space, for placing a route's
	# plate somewhere a body can actually stand.
	var occupied := occupants_of(room_id, chambers, door_frames, arrival)

	# BUILT DETACHED, ADOPTED ONLY IF IT IS WHOLE. The machines are the
	# graph's children, so a refusal half way through frees every one of
	# them with it and leaves no orphan plate in the room.
	var graph := SignalGraph.new()
	graph.name = "SignalGraph_%s" % room_id
	graph.room_id = room_id

	# A ROUTE'S PLATE IS PLACED FROM ITS DOORWAY; a machine's from the
	# far wall. One route doorway per graph is what the bridge admits.
	var route_frame: Dictionary = {}
	for key: Variant in doorway_of.keys():
		route_frame = doorway_of[key]
		break

	var seen: Dictionary = {}
	var lane := 0
	for entry: Variant in declared.get("sensors", []) as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var sensor: Dictionary = entry
		var kind := str(sensor.get("kind", ""))
		var why := _refuse_sensor(kind)
		# THE BUILDER PLACES PLATES (O05-07). A button is run by the same
		# runtime but placed only by a room that owns its machine; asked
		# for one here, the builder would otherwise put a plate down.
		if why == "" and not Constants.SIGNAL_ZONE_PLACEABLE_SENSORS.has(
				kind):
			why = ("'%s' is run by the signal graph but the Zone builder "
					% kind + "places only %s"
					% [Constants.SIGNAL_ZONE_PLACEABLE_SENSORS])
		if why != "":
			graph.free()
			return {"refused": "room '%s': %s" % [room_id, why]}
		var node_id := str(sensor.get("node_id", ""))
		var wants := str(sensor.get("requires_class", ""))
		if not CLASS_OF.has(wants):
			graph.free()
			return {"refused": "room '%s': sensor '%s' demands class "
					% [room_id, node_id] + "'%s', which is not one of "
					% wants + "%s" % [CLASS_OF.keys()]}
		# THE DECLARATION DECIDES WHETHER THE PLAYER COUNTS. Default
		# false, which is EX50-033's object-only plate exactly.
		var plate := ClassPlate.create(PLATE_SIZE, CLASS_OF[wants], theme,
				bool(sensor.get("counts_player", false)))
		plate.name = "Plate_%s" % node_id
		if not route_frame.is_empty():
			var spot := route_plate_spot(route_frame, box, floor_y,
					occupied)
			if spot == Vector3.INF:
				graph.free()
				return {"refused": "room '%s': no clear floor for sensor "
						% room_id + "'%s' on this side of the doorway it "
						% node_id + "opens -- every candidate is inside a "
						+ "wall margin or within %.1f m of something the "
						% OCCUPANT_CLEARANCE + "room already placed"}
			plate.position = spot
			# The next sensor must not land on this one.
			occupied.append(spot)
		else:
			plate.position = base + across * (float(lane) * CHAIN_SPREAD)
			plate.position.y = floor_y + PLATE_SIZE.y * 0.5
		graph.add_child(plate)
		graph.sensors[node_id] = plate
		seen[node_id] = true
		lane += 1

	for entry: Variant in declared.get("nodes", []) as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = entry
		var kind := str(node.get("kind", ""))
		var why := _refuse_node(kind)
		if why != "":
			graph.free()
			return {"refused": "room '%s': %s" % [room_id, why]}
		var inputs: Array = node.get("inputs", []) as Array
		for input: Variant in inputs:
			if not seen.has(str(input)):
				graph.free()
				return {"refused": "room '%s': node '%s' takes input "
						% [room_id, str(node.get("node_id", ""))]
						+ "from '%s', which is not declared before it"
						% str(input)}
		graph.nodes.append({"id": str(node.get("node_id", "")),
				"kind": kind, "inputs": inputs})
		seen[str(node.get("node_id", ""))] = true

	var shutters := 0
	for entry: Variant in declared.get("actuators", []) as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var binding: Dictionary = entry
		var actuator_id := str(binding.get("actuator_id", ""))
		var operation := str(binding.get("operation", "command"))
		if not Constants.SIGNAL_ACTUATOR_OPS_IMPLEMENTED.has(operation):
			graph.free()
			return {"refused": "room '%s': actuator '%s' is driven by "
					% [room_id, actuator_id]
					+ "'%s', which no runtime implements" % operation}
		var driven := str(binding.get("driven_by", ""))
		if not seen.has(driven):
			graph.free()
			return {"refused": "room '%s': actuator '%s' is driven by "
					% [room_id, actuator_id]
					+ "'%s', which this room's graph does not declare"
					% driven}
		var shutter: ServiceShutter
		var gates := ""
		if doorway_of.has(actuator_id):
			shutter = route_shutter(doorway_of[actuator_id], theme)
			gates = str((doorway_of[actuator_id] as Dictionary).get(
					"edge_id", ""))
		else:
			# BESIDE THE PLATES, not across the room from them: a chain
			# whose two ends are twenty metres apart is a chain nobody
			# can watch work.
			var centre := base - across * (float(shutters + 1) * CHAIN_SPREAD)
			centre.y = floor_y + PANEL_SIZE.y * 0.5
			shutter = ServiceShutter.create(centre, PANEL_SIZE,
					PANEL_RISE, theme)
		shutter.name = "Shutter_%s" % actuator_id
		graph.add_child(shutter)
		graph.actuators[actuator_id] = {
			"node": shutter, "driven_by": driven, "operation": operation,
			"gates": gates}
		shutters += 1

	root.add_child(graph)
	return {"graph": graph}


## `room_places` entries, tolerating a missing one.
static func place_of(places: Dictionary, room_id: String) -> Dictionary:
	var raw: Variant = places.get(room_id, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


## THE COMMITTED FRAME OF THE DOORWAY THIS ROOM BUILT FOR `edge`.
##
## Read, never re-derived: the room's own door plan names which socket
## realises the edge (`edge_id`), and `door_frames` holds that socket's
## world position, its facing (the room's committed yaw plus the
## socket's own) and the opening's size -- the same plan the aperture
## audit and the lock slabs are placed from. Empty when this room has no
## door for the edge, or the builder recorded no frame for it.
static func doorway_frame(room_id: String, edge: Dictionary,
		chambers: Array, door_frames: Dictionary) -> Dictionary:
	var edge_id := str(edge.get("edge_id", ""))
	if room_id != str(edge.get("room_a", "")) \
			and room_id != str(edge.get("room_b", "")):
		return {}
	var socket := ""
	for raw: Variant in chambers:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var chamber: Dictionary = (raw as Dictionary).get("chamber", raw)
		if str(chamber.get("id", "")) != room_id:
			continue
		for door: Variant in chamber.get("doors", []) as Array:
			if typeof(door) == TYPE_DICTIONARY \
					and str((door as Dictionary).get("edge_id", "")) == edge_id:
				socket = str((door as Dictionary).get("socket_id", ""))
				break
	if socket == "":
		return {}
	var frame: Variant = door_frames.get("%s/%s" % [room_id, socket])
	if typeof(frame) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = (frame as Dictionary).duplicate()
	out["room_id"] = room_id
	out["socket_id"] = socket
	out["edge_id"] = edge_id
	return out


## A SHUTTER THAT FILLS THE OPENING: the doorway's own width and height,
## thinner than the wall, turned to the socket's world yaw, its foot on
## the doorway's floor, rising the full opening plus clearance.
static func route_shutter(frame: Dictionary, theme: String) -> ServiceShutter:
	var width := float(frame.get("width", ChamberBuilders.DOOR_WIDTH))
	var height := float(frame.get("height", ChamberBuilders.DOOR_HEIGHT))
	var at: Vector3 = frame.get("position", Vector3.ZERO)
	var centre := at + Vector3(0.0, height * 0.5, 0.0)
	var shutter := ServiceShutter.create(centre,
			Vector3(width, height, ROUTE_PANEL_DEPTH),
			height + ROUTE_PANEL_CLEARANCE, theme)
	shutter.rotation.y = float(frame.get("yaw", 0.0))
	shutter.add_to_group(ROUTE_GATE)
	return shutter


## EVERYTHING THE ROOM HAS ALREADY PUT DOWN, as world points.
##
## From the room's own build result, in the room's committed frame --
## `enemy_spawns`, `reward_position`, `key_spots`, `return_spot`, its
## arrival -- plus every doorway frame it built and every activity
## element standing in it. Nothing here is guessed; each is a position a
## producer declared or a node that exists.
static func occupants_of(room_id: String, chambers: Array,
		door_frames: Dictionary, arrival: Vector3) -> Array:
	var out: Array = [arrival]
	for key: Variant in door_frames.keys():
		if str(key).begins_with(room_id + "/"):
			out.append((door_frames[key] as Dictionary).get(
					"position", Vector3.ZERO))
	for raw: Variant in chambers:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		var chamber: Dictionary = entry.get("chamber", {})
		if str(chamber.get("id", "")) != room_id:
			continue
		var xform: Transform3D = entry.get("xform", Transform3D.IDENTITY)
		var result: Dictionary = entry.get("build", {})
		for spawn: Variant in result.get("enemy_spawns", []) as Array:
			if typeof(spawn) == TYPE_DICTIONARY:
				out.append(xform * ((spawn as Dictionary).get(
						"position", Vector3.ZERO) as Vector3))
		if result.has("reward_position"):
			out.append(xform * (result["reward_position"] as Vector3))
		for spot: Variant in result.get("key_spots", []) as Array:
			if typeof(spot) == TYPE_DICTIONARY:
				out.append(xform * ((spot as Dictionary).get(
						"position", Vector3.ZERO) as Vector3))
		if result.get("return_spot") is Vector3:
			out.append(xform * (result["return_spot"] as Vector3))
		for built: Variant in result.get("activities", []) as Array:
			if typeof(built) != TYPE_DICTIONARY:
				continue
			var runtime: Node = (built as Dictionary).get("runtime")
			if runtime == null or not is_instance_valid(runtime):
				continue
			for element: Node in _elements_under(runtime):
				out.append((element as Node3D).global_position)
	return out


static func _elements_under(node: Node) -> Array:
	var found: Array = []
	for child: Node in node.get_children():
		if child is ActivityElement and child is Node3D:
			found.append(child)
		found.append_array(_elements_under(child))
	return found


## WHERE A ROUTE'S PLATE GOES, or `Vector3.INF` when nowhere is clear.
##
## On this room's side of the doorway (the direction from the door
## toward the room's centre, measured rather than read off the socket
## yaw, whose sign differs between the front and side walls), a few
## metres in, and to one side. The first candidate inside the walls and
## clear of every occupant wins, so the choice is deterministic for a
## given Zone.
static func route_plate_spot(frame: Dictionary, box: AABB, floor_y: float,
		occupied: Array) -> Vector3:
	var door: Vector3 = frame.get("position", Vector3.ZERO)
	var yaw := float(frame.get("yaw", 0.0))
	var normal := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var along := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	var centre := box.get_center()
	var to_centre := Vector3(centre.x - door.x, 0.0, centre.z - door.z)
	var inward := normal if normal.dot(to_centre) >= 0.0 else -normal
	var half := PLATE_SIZE.x * 0.5 + WALL_MARGIN
	for inset: Variant in ROUTE_PLATE_INSETS:
		for side: Variant in ROUTE_PLATE_SIDES:
			var spot := door + inward * float(inset) + along * float(side)
			spot.y = floor_y + PLATE_SIZE.y * 0.5
			if box.size != Vector3.ZERO and (
					spot.x - half < box.position.x
					or spot.x + half > box.end.x
					or spot.z - half < box.position.z
					or spot.z + half > box.end.z):
				continue
			var clear := true
			for raw: Variant in occupied:
				var point: Vector3 = raw
				if Vector2(point.x - spot.x, point.z - spot.z).length() \
						< OCCUPANT_CLEARANCE:
					clear = false
					break
			if clear:
				return spot
	return Vector3.INF


static func _refuse_sensor(kind: String) -> String:
	if not Constants.SIGNAL_SENSOR_KINDS.has(kind):
		return "'%s' is not one of §20's eighteen sensor types" % kind
	if not Constants.SIGNAL_SENSOR_KINDS_IMPLEMENTED.has(kind):
		return ("sensor '%s' is named by §20 and no runtime implements "
				% kind + "it; supported today: %s"
				% [Constants.SIGNAL_SENSOR_KINDS_IMPLEMENTED])
	return ""


static func _refuse_node(kind: String) -> String:
	if not Constants.SIGNAL_NODE_KINDS.has(kind):
		return "'%s' is not one of §19.2's eleven node types" % kind
	if not Constants.SIGNAL_NODE_KINDS_IMPLEMENTED.has(kind):
		return ("node '%s' is named by §19.2 and no runtime implements "
				% kind + "it; supported today: %s"
				% [Constants.SIGNAL_NODE_KINDS_IMPLEMENTED])
	return ""
