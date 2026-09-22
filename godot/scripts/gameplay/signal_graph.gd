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


## §19.2's node semantics. `NOT` alone today, and an unknown kind
## returns false rather than guessing -- a node nothing implements
## should have been refused at build, and a silent default that looked
## like OR would be worse than a dead output.
func _resolve(node: Dictionary) -> bool:
	var inputs: Array = node.get("inputs", []) as Array
	if inputs.is_empty():
		return false
	match str(node.get("kind", "")):
		"NOT":
			return not bool(values.get(str(inputs[0]), false))
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
