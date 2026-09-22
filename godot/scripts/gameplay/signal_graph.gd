class_name SignalGraph
extends Node3D
## P14 — ONE ROOM'S SIGNAL GRAPH, EVALUATED.
##
## Design 1 §19: an acyclic typed graph, evaluated in topological order
## within one tick. `schemas/signal_graph.py` declares it; this runs it.
##
## **DECLARATION ORDER IS TOPOLOGICAL ORDER.** The schema refuses a node
## whose input is not already declared, so a cycle cannot be written
## down and the order the nodes arrive in is an order that resolves. No
## sort here, and no visited set: walking the list once IS the
## topological walk, and a second ordering in this file could disagree
## with the one the schema enforced.
##
## **IT READS THE ROOM AND WRITES THE ROOM.** Amalgam §19.7 rule 2:
## room graphs read macro state and never write it, and no graph can
## address another room. That holds structurally -- every input names a
## node of THIS graph, and the only things bound in are sensors and
## actuators this room built.
##
## **A `Node3D` HOLDING ITS OWN MACHINES.** The plates and the shutter
## are its children, so a graph that is refused half way through
## building frees everything it made by freeing itself -- there is no
## partially wired chain left standing in the room. It sits at the
## origin of the Zone's space, so a child's `position` means the same
## thing whether it hangs here or off the controller.
##
## **IT IS NOT A NEW WIRE.** `unweighted_switch.gd` already runs this
## exact chain, hand-wired in `_on_plate`: a HEAVY class plate, a NOT,
## and a shutter. What is new is that a Zone can ASK for it. The
## scenario keeps its own wiring -- it is scaffolding for a room that
## predates the declaration, and rewriting it to go through here would
## change a working room to prove a point about a different one.

## The room this graph belongs to. Room-local by construction.
var room_id := ""

## How many times the graph has been evaluated. A graph that never ran
## and a graph that ran and did nothing are different findings.
var ticks := 0

## `node_id -> ClassPlate`. The sources.
var sensors: Dictionary = {}

## Logic nodes in DECLARATION order: `[{id, kind, inputs}]`.
var nodes: Array = []

## `actuator_id -> {"node": Node, "driven_by": String,
##                  "operation": String}`.
var actuators: Dictionary = {}

## Last computed value of every node, sensors included. Diagnostic: a
## chain that did not drive what it should is answered by which node
## stopped carrying the value.
var values: Dictionary = {}

## Latch node ids that have fired, and stay fired.
##
## **This is the only state in the graph**, and it is why a latch needs
## restoring while a `NOT` does not: everything else is recomputed from
## the sensors every tick, so a rebuilt Zone arrives at the same answer
## on its own. A latch is a decision the player made, and §5.4a is
## explicit that the decision persists and the machine is rebuilt from
## it -- the engine is never told the state of the machine.
var latched: Dictionary = {}

## A latch has just gone true for the first time. The Zone reports it
## through the same `report_latch` the railway's spans use, so there is
## one way a room-local decision reaches the campaign and not two.
##
## **THE BRIDGE REFUSES THESE TODAY, and that is not yet closed.**
## `transitions.record_latch` accepts a `package_id` only when it is one
## of the Zone's accepted PHYSICS packages, so `graph_c001/held` is
## answered "Zone accepted no physics package 'graph_c001'" and nothing
## is saved. The runtime half is here and tested; the record half is a
## bridge change, named in `docs/D10_P14_PROD_ANSWER.md` rather than
## assumed. Until it lands a latch holds for the life of the Zone and
## is lost on reload -- which is why a LATCH chain stays undeclarable.
signal fired(package: String, node_id: String)


## The package this graph's latches are recorded under.
##
## `graph_` + the room, because `LatchFired.package_id` is
## `^[a-z0-9_]+$` (no separator character is available) and a bare room
## id would share one namespace with the physics packages the bridge
## already validates against.
func package_id() -> String:
	return "graph_%s" % room_id


## PUT THE DECISIONS BACK, then settle.
##
## §5.6 step 5: a Zone rebuilt from a save restores its latches from the
## campaign's own record rather than from anything the engine stored
## about the machine. `refs` is `latches_accepted()`'s form --
## `package_id/latch_id` -- and this graph's package is `package_id()`.
func restore_from(refs: Array) -> int:
	var count := 0
	for raw: Variant in refs:
		var ref := str(raw)
		for node: Variant in nodes:
			var id := str((node as Dictionary).get("id", ""))
			if str((node as Dictionary).get("kind", "")) != "LATCH":
				continue
			if ref == "%s/%s" % [package_id(), id] and not latched.has(id):
				latched[id] = true
				count += 1
	if count > 0:
		evaluate()
	return count


## Wire every sensor's change to a re-evaluation, and settle once so the
## actuators start in the state the graph says rather than the state
## whoever built them left them in.
func start() -> void:
	for raw: Variant in sensors.values():
		var plate: ClassPlate = raw
		if not plate.occupancy_changed.is_connected(_on_sensor):
			plate.occupancy_changed.connect(_on_sensor)
	evaluate()


func _on_sensor(_satisfied: bool) -> void:
	evaluate()


## ONE TICK. Sensors, then logic in declaration order, then the
## actuators -- so every node reads values from this tick and none from
## the last one.
func evaluate() -> void:
	ticks += 1
	for key: Variant in sensors.keys():
		var plate: ClassPlate = sensors[key]
		values[key] = plate.satisfied()
	for raw: Variant in nodes:
		var node: Dictionary = raw
		values[str(node["id"])] = _resolve(node)
	for key: Variant in actuators.keys():
		var binding: Dictionary = actuators[key]
		var driven := str(binding.get("driven_by", ""))
		if not values.has(driven):
			continue
		_drive(binding, bool(values[driven]))


## §19.2's node semantics. An unknown kind returns false rather than
## guessing -- a node nothing implements should have been refused at
## build, and a silent default that looked like OR would be worse than
## a dead output.
##
## **`LATCH` IS THE ONE THAT MAKES A CHAIN ABLE TO OPEN A ROUTE.**
## D-10's finding: with `PRESSURE_PLATE` and `NOT` alone every sensor
## rests false, so a chain can only ever DENY a route -- the player
## loads the plate and something shuts. Denying strands nobody and
## constrains nothing, which is a weak puzzle. A latch holds its value
## after the player steps off, so stepping on the plate once opens the
## way and the player can then walk through it. That is one action, and
## it is the difference between a machine in a room and a route.
func _resolve(node: Dictionary) -> bool:
	var inputs: Array = node.get("inputs", []) as Array
	if inputs.is_empty():
		return false
	var id := str(node.get("id", ""))
	match str(node.get("kind", "")):
		"NOT":
			return not bool(values.get(str(inputs[0]), false))
		"LATCH":
			# SET BY A TRUE INPUT AND NEVER RESET. §19.2's latch has no
			# clear in this slice, because the puzzle it is here for is
			# "open it once and walk through", and a latch that could
			# clear is a door that can shut behind you.
			if latched.has(id):
				return true
			if bool(values.get(str(inputs[0]), false)):
				latched[id] = true
				fired.emit(package_id(), id)
				return true
			return false
		_:
			return false


func _drive(binding: Dictionary, value: bool) -> void:
	var target: Node = binding.get("node")
	if target == null or not is_instance_valid(target):
		return
	match str(binding.get("operation", "")):
		"command":
			target.call("command", value)


## What the graph currently says, for a message. Not the state of the
## machines -- a shutter that refused to move is the shutter's finding.
func reading() -> String:
	var parts: Array[String] = []
	for key: Variant in sensors.keys():
		parts.append("%s=%s" % [key, values.get(key, "?")])
	for raw: Variant in nodes:
		var node: Dictionary = raw
		parts.append("%s=%s" % [node["id"], values.get(node["id"], "?")])
	return "%s: %s" % [room_id, ", ".join(parts)]
