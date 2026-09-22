class_name RoomGraphs
extends RefCounted
## P14 — BUILD THE SIGNAL GRAPHS A ZONE DECLARES.
##
## `Zone.room_graphs` names a chain; this puts it in the room and wires
## it. The same move `RailNetworks` made for the railway: the Zone says
## WHAT, the engine decides WHERE, and a declaration the engine cannot
## honour is reported rather than half-built.
##
## **THE FIRST SLICE IS ONE REAL CHAIN.** `PRESSURE_PLATE -> NOT ->
## command`, which is what `unweighted_switch.gd` already runs and what
## `SUPPORTED_NODE_KINDS` and `SUPPORTED_SENSOR_KINDS` are deliberately
## narrowed to. Everything else the schema names is refused here too,
## with the same distinction it draws: a kind §19.2 does not define is a
## typo, a kind it defines that nothing implements is a gap.
##
## **WHAT THIS SLICE DOES NOT DO: GATE A ROUTE.** The shutter it builds
## is a machine in the room, not a door on the way out. A physical gate
## the matching AP location logic does not declare is the one thing that
## may never happen (`SOLUTIONS_CATALOGUE` §0-bis), and nothing in
## `RoomGraph` declares a capability gate — so a chain that could seal
## the exit would be a Zone the logic thinks is open and the player
## finds shut. Putting a graph on the route needs the declaration to
## carry the gate, and that is a schema change with Dess's half in it.
##
## **AN UNBUILT GRAPH IS A COMPOSITION FINDING, NOT A CRASH.** Same
## posture as `RailNetworks`: refusals come back in a list, the Zone
## plays without that chain, and whoever authored it hears about it.

## THE CHAIN GOES AGAINST THE FAR WALL, and not near the middle.
##
## **The engine places it blind.** Nothing tells `RoomGraphs` what else
## the chamber put in this room -- there is no room-wide occupancy
## register -- so the first version dropped the plate two metres from
## the room's centre and landed it under the reward pedestal: a crate
## dropped on the plate came to rest 1.9 m up, on the pedestal, and the
## plate read an empty room. The middle of a room is where furniture
## goes. The far wall, measured from the point the player arrives at, is
## the part of a room that is reliably empty, and it is also where a
## machine reads as a machine rather than as an obstacle.
##
## A register would be better than a heuristic and does not exist; when
## one does, this is the function that should read it.
const CHAIN_CLEARANCE := 3.0
const CHAIN_SPREAD := 3.0

const PLATE_SIZE := Vector3(2.4, 0.12, 2.4)
const PANEL_SIZE := Vector3(2.0, 2.2, 0.3)
const PANEL_RISE := 2.4
## A freestanding machine, not a bulkhead. `unweighted_switch` gives its
## shutter the default eight seconds because it is a door the player
## waits at; this one is a readout of a chain, and eight seconds of
## travel would make every question about the chain a question about
## the travel.
const PANEL_SECONDS := 3.0

#: §19.2's eleven, §20's eighteen and what each is narrowed to are all
#: GENERATED from `schemas/signal_graph.py`. Transcribing them here
#: would be a second vocabulary that could drift from the one the Zone
#: was validated against, which is the whole reason `export.py` exists.

const CLASS_OF := {"LIGHT": MassClass.LIGHT, "MEDIUM": MassClass.MEDIUM,
		"HEAVY": MassClass.HEAVY}


## Build every declared graph. Returns
## `{"graphs": Array[SignalGraph], "refused": Array[String]}`.
static func build(root: Node3D, graphs: Array, places: Dictionary,
		bounds: Dictionary, theme := "concrete_facility") -> Dictionary:
	var made: Array[SignalGraph] = []
	var refused: Array[String] = []
	for raw: Variant in graphs:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var out := _one(root, raw as Dictionary, places, bounds, theme)
		var why := str(out.get("refused", ""))
		if why != "":
			refused.append(why)
			continue
		made.append(out["graph"] as SignalGraph)
	return {"graphs": made, "refused": refused}


static func _one(root: Node3D, declared: Dictionary, places: Dictionary,
		bounds: Dictionary, theme: String) -> Dictionary:
	var room_id := str(declared.get("room_id", ""))
	if not places.has(room_id):
		return {"refused": "a signal graph names room '%s', which this "
				% room_id + "Zone did not build"}
	var box: AABB = bounds.get(room_id, AABB())
	var place: Dictionary = places[room_id]
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
	# How far the room reaches in the direction being walked. Rooms are
	# boxes and `away` is built from two of their points, so the extent
	# is the box's own half-size projected onto it.
	var reach := absf(away.x) * box.size.x * 0.5 \
			+ absf(away.z) * box.size.z * 0.5
	var base := anchor + away * maxf(reach - CHAIN_CLEARANCE, 0.0)

	# BUILT DETACHED, ADOPTED ONLY IF IT IS WHOLE. The machines are the
	# graph's children, so a refusal half way through frees every one of
	# them with it and leaves no orphan plate in the room.
	var graph := SignalGraph.new()
	graph.name = "SignalGraph_%s" % room_id
	graph.room_id = room_id

	var seen: Dictionary = {}
	var lane := 0
	for entry: Variant in declared.get("sensors", []) as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var sensor: Dictionary = entry
		var kind := str(sensor.get("kind", ""))
		var why := _refuse_sensor(kind)
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
		var plate := ClassPlate.create(PLATE_SIZE, CLASS_OF[wants], theme)
		plate.name = "Plate_%s" % node_id
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
		var operation := str(binding.get("operation", "command"))
		if not Constants.SIGNAL_ACTUATOR_OPS_IMPLEMENTED.has(operation):
			graph.free()
			return {"refused": "room '%s': actuator '%s' is driven by "
					% [room_id, str(binding.get("actuator_id", ""))]
					+ "'%s', which no runtime implements" % operation}
		var driven := str(binding.get("driven_by", ""))
		if not seen.has(driven):
			graph.free()
			return {"refused": "room '%s': actuator '%s' is driven by "
					% [room_id, str(binding.get("actuator_id", ""))]
					+ "'%s', which this room's graph does not declare"
					% driven}
		# BESIDE THE PLATES, not across the room from them: a chain whose
		# two ends are twenty metres apart is a chain nobody can watch
		# work.
		var centre := base - across * (float(shutters + 1) * CHAIN_SPREAD)
		centre.y = floor_y + PANEL_SIZE.y * 0.5
		var shutter := ServiceShutter.create(centre, PANEL_SIZE,
				PANEL_RISE, PANEL_SECONDS, theme)
		shutter.name = "Shutter_%s" % str(binding.get("actuator_id", ""))
		graph.add_child(shutter)
		graph.actuators[str(binding.get("actuator_id", ""))] = {
			"node": shutter, "driven_by": driven, "operation": operation}
		shutters += 1

	root.add_child(graph)
	graph.start()
	return {"graph": graph}


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
