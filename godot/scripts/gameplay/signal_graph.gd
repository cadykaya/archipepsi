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

## `node_id -> ClassPlate | CallLever | null`. The sources. A plate is a
## Boolean; a lever is a PULSE_BUTTON (O05-07), whose pull is a pulse
## that lives exactly one tick (§19.3). A source declared and left null
## is UNBOUND and reads OFF -- EX50-033's §11 control, the plate's link
## cut.
var sensors: Dictionary = {}

## Pulses raised on the tick being evaluated, by sensor id. Cleared the
## moment that tick is done, so a pulse is never read twice.
var _pulses: Dictionary = {}
## Levers already wired, so `start` twice does not pull twice.
var _wired: Dictionary = {}

## Logic nodes in DECLARATION order: `[{id, kind, inputs}]`.
var nodes: Array = []

## `actuator_id -> {"node": Node, "driven_by": String,
##                  "operation": String}`.
var actuators: Dictionary = {}

## Last computed value of every node, sensors included. Diagnostic: a
## chain that did not drive what it should is answered by which node
## stopped carrying the value.
var values: Dictionary = {}

## How many latches the last `restore_from` put back from the record.
## A restored latch is not a new player action, and a suite checking
## "no announcement on reload" needs to tell the two apart.
var restored := 0

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
## **THE BRIDGE RECORDS IT UNDER FOUR CONDITIONS, and a prefix is not one
## of them** (D-10 §5): the accepted Zone is this one, its layout is
## committed, the manifest placed this room, and the accepted Zone
## declares a graph here whose node by that id is a `LATCH`. A
## `graph_` name alone authorizes nothing, and physics packages may not
## take the prefix.
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
##
## **RECORDS, AND DOES NOT EVALUATE.** It runs BEFORE the graph's first
## tick, so the first thing the machine ever does is already the restored
## answer. It used to evaluate here -- after `start()` had evaluated once
## with the latch unset -- which commanded the route SHUT on every reload
## and then opened it a frame later, in front of the player. And it never
## announces: a latch put back from the record is not a new decision, so
## `fired` is not emitted and nothing is reported to the bridge twice.
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
	restored = count
	return count


## Put ONE latch back by id, silently: for a room that owns its graph and
## reports its latches under its own package (a hosted minor's
## `minor_<room>/<latch>`), where `restore_from`'s `graph_` refs do not
## apply. Like `restore_from`, it records and does not evaluate or
## announce; the owner settles afterwards.
func restore_latch(node_id: String) -> bool:
	for node: Variant in nodes:
		var id := str((node as Dictionary).get("id", ""))
		if id == node_id and str((node as Dictionary).get("kind", "")) \
				== "LATCH" and not latched.has(id):
			latched[id] = true
			restored += 1
			return true
	return false


## Wire every sensor's change to a re-evaluation, and SETTLE once so the
## actuators start in the state the graph says rather than the state
## whoever built them left them in. Call it after `restore_from`.
func start() -> void:
	for key: Variant in sensors.keys():
		var source: Variant = sensors[key]
		if not is_instance_valid(source):
			continue
		if source is ClassPlate:
			var plate: ClassPlate = source
			if not plate.occupancy_changed.is_connected(_on_sensor):
				plate.occupancy_changed.connect(_on_sensor)
		elif source is CallLever and not _wired.has(str(key)):
			_wired[str(key)] = true
			(source as CallLever).pulled.connect(_on_pulse.bind(str(key)))
	evaluate(true)


func _on_sensor(_satisfied: bool) -> void:
	evaluate()


## A PULSE_BUTTON pulled: one tick with its pulse raised, then gone.
func _on_pulse(_lever: CallLever, sensor_id: String) -> void:
	_pulses[sensor_id] = true
	evaluate()
	_pulses.erase(sensor_id)


## What a source reads this tick. An unbound or freed source reads OFF.
func _read(sensor_id: String) -> bool:
	var source: Variant = sensors.get(sensor_id)
	if not is_instance_valid(source):
		return false
	if source is ClassPlate:
		return (source as ClassPlate).satisfied()
	if source is CallLever:
		return _pulses.has(sensor_id)
	return false


## ONE TICK. Sensors, then logic in declaration order, then the
## actuators -- so every node reads values from this tick and none from
## the last one.
func evaluate(settle := false) -> void:
	ticks += 1
	for key: Variant in sensors.keys():
		values[key] = _read(str(key))
	for raw: Variant in nodes:
		var node: Dictionary = raw
		values[str(node["id"])] = _resolve(node)
	for key: Variant in actuators.keys():
		var binding: Dictionary = actuators[key]
		var driven := str(binding.get("driven_by", ""))
		if not values.has(driven):
			continue
		_drive(binding, bool(values[driven]), settle)


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
		"OR":
			# §19.2: ON when any input is ON. Two to four Booleans, which
			# the schema checked; a pulse cannot reach here (§19.1).
			for feed: Variant in inputs:
				if bool(values.get(str(feed), false)):
					return true
			return false
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


func _drive(binding: Dictionary, value: bool, settle := false) -> void:
	var target: Node = binding.get("node")
	if target == null or not is_instance_valid(target):
		return
	match str(binding.get("operation", "")):
		"command":
			if settle and target.has_method("settle"):
				target.call("settle", value)
			else:
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
