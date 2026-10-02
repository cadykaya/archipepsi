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
## **IT RUNS THE ROOMS' OWN CHAINS TOO (O05-07).** A Zone asks for a
## chain through `room_graphs` and `RoomGraphs` builds it. A minor room
## that owns its machines -- EX50-033's plate, bolt and shutter,
## EX50-021's receiver, release and shutter -- has its chain declared in
## its occurrence contract instead, and binds its own machines to it
## through `bind_declared`. Either way this is what evaluates it; the
## rooms keep only what is presentation.

## The room this graph belongs to. Room-local by construction.
var room_id := ""

## How many times the graph has been evaluated. A graph that never ran
## and a graph that ran and did nothing are different findings.
var ticks := 0

## `node_id -> ClassPlate | CallLever | ImpactReceiver | null`. The
## sources. A plate is a Boolean. A lever is a PULSE_BUTTON and a
## receiver a SHOOTABLE_TARGET in PULSE mode (O05-07): a pull, or a valid
## hit, is a pulse that lives exactly one tick (§19.3). A source declared
## and left null is UNBOUND and reads OFF -- EX50-033's §11 control, the
## plate's link cut.
var sensors: Dictionary = {}

## Running TIMERs: `node_id -> seconds left`. §19.6 makes a TIMER
## EPHEMERAL: it is never saved and never restored, so a rebuilt room
## starts every TIMER OFF. The only state here that the clock changes.
var timers: Dictionary = {}

## Pulses raised on the tick being evaluated, by sensor id. Cleared the
## moment that tick is done, so a pulse is never read twice.
var _pulses: Dictionary = {}
## Pulse sources already wired, so `start` twice does not pulse twice.
var _wired: Dictionary = {}

## Logic nodes in DECLARATION order: `[{id, kind, inputs}]`, and a
## TIMER's `duration`.
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

## What a thrown permanent lever says, once its change is made.
const PERMANENT_LEVER_DONE := "BOLT THROWN -- THE WAY IS OPEN"

## H-GRAPHS: DESIGN 3 §14's SIGNAL VERBS, the player's interface to the
## machine. RUNTIME-ONLY until an Echo delivers them (note N-15): no
## Echo primitive carries one yet, so nothing in play calls `apply_verb`.
##
## Each is temporary, lasting `magnitude` seconds, and §19.7 applies it at
## evaluation step 1, as an override on a node's output: INVERT,
## HOLD_SIGNAL and CUT replace what the node computed; BRIDGE adds an
## edge, which ORs its source into the destination's input. PROBE changes
## nothing and reveals the node (`probe`).
##
## **A VERB NEVER SETS A LATCH** (N-15, §14.4). A LATCH here is a decision
## the campaign records, so it is set from the VERIFIED values -- the
## graph evaluated with no verb applied (`verified`) -- and nothing else.
## A verb can hold a door open long enough to slip through, and the door
## shuts when it expires; it cannot open a route for good. CUT on a
## latch reports it OFF for the duration and leaves the record alone.
##
## **There is no macro setter in a room graph.** The header's rule 2: a
## room graph reads macro state and never writes it. So §14.3's last row
## has nothing to guard here, and the persistent decision a verb could
## reach -- a recorded latch -- is guarded above.
const VERBS := ["PROBE", "BRIDGE", "INVERT", "HOLD_SIGNAL", "CUT"]
## §14.3, by what the target is, for the kinds this runtime evaluates.
## "BRIDGE_FROM" and "BRIDGE_TO" are its "source only" and "destination
## only". A kind with no row takes no verb at all: DIRECT, AND, SEQUENCE
## and the rest have no consumer yet (N-15), and each row lands with its
## node, not before it (O05-07: no unused catalogue).
const VERB_LEGALITY := {
	"SENSOR": ["PROBE", "BRIDGE_FROM", "INVERT", "HOLD_SIGNAL", "CUT"],
	"NOT": ["PROBE", "BRIDGE_FROM", "BRIDGE_TO", "INVERT", "HOLD_SIGNAL",
			"CUT"],
	"OR": ["PROBE", "BRIDGE_FROM", "BRIDGE_TO", "INVERT", "HOLD_SIGNAL",
			"CUT"],
	"TIMER": ["PROBE", "BRIDGE_FROM", "BRIDGE_TO", "HOLD_SIGNAL", "CUT"],
	"LATCH": ["PROBE", "BRIDGE_FROM", "CUT"],
	"ACTUATOR": ["PROBE", "BRIDGE_TO", "INVERT", "HOLD_SIGNAL", "CUT"],
}

## `id -> {"verb": String, "left": float}`: INVERT, HOLD_SIGNAL or CUT on
## a sensor, a node or an actuator's input. A second verb on the same
## target replaces the first.
var overrides: Dictionary = {}
## BRIDGE's temporary edges: `[{"from": id, "to": id, "left": float}]`.
var bridges: Array = []
## What PROBE has revealed, and for how much longer: `id -> seconds`.
var probes: Dictionary = {}
## THE VERIFIED CONFIGURATION: every value with no verb applied. A
## recorded LATCH is set from these (N-15), and the machine returns to
## them when the last verb expires.
var verified: Dictionary = {}
## The TIMERs under the verbs, beside `timers` (the verified ones). A
## bridged or held pulse restarts only these.
var _live_timers: Dictionary = {}
## Evaluation order while a BRIDGE stands; declaration order otherwise.
var _bridged_order: Array = []


## BIND A DECLARED GRAPH TO A ROOM'S OWN MACHINES (O05-07).
##
## `declared` is one of `Constants.MINOR_SIGNAL_GRAPHS`: the chain a
## minor's occurrence contract declares, already validated by the
## bridge. `machines` maps the declaration's ids to what the room built.
## A declared id the room has no machine for, or a machine of the wrong
## kind -- a lever where the declaration says a target -- is drift
## between the contract and the room. It is said loudly and left
## unbound, so it reads OFF rather than run as something it is not. A
## machine the room leaves null on purpose is UNBOUND (EX50-033's §11
## control).
##
## Returned unstarted and outside the tree: the room adds it, connects
## `fired`, restores, and then calls `start`.
static func bind_declared(declared: Dictionary, machines: Dictionary,
		owner: String) -> SignalGraph:
	var graph := SignalGraph.new()
	graph.name = "Graph"
	graph.room_id = str(declared.get("room_id", "minor"))
	for raw: Variant in declared.get("sensors", []) as Array:
		var sensor: Dictionary = raw
		var id := str(sensor.get("node_id", ""))
		var kind := str(sensor.get("kind", ""))
		if not machines.has(id):
			push_error("%s: the declared sensor '%s' has no machine in the "
					% [owner, id] + "room")
		var machine: Variant = machines.get(id)
		if machine != null and not source_is(kind, machine):
			push_error("%s: the declared %s '%s' is bound to %s; left "
					% [owner, kind, id, machine] + "unbound")
			machine = null
		graph.sensors[id] = machine
	for raw: Variant in declared.get("nodes", []) as Array:
		var node: Dictionary = raw
		var made := {"id": str(node.get("node_id", "")),
				"kind": str(node.get("kind", "")),
				"inputs": node.get("inputs", [])}
		if node.has("duration"):
			made["duration"] = float(node["duration"])
		graph.nodes.append(made)
	for raw: Variant in declared.get("actuators", []) as Array:
		var bind: Dictionary = raw
		var id := str(bind.get("actuator_id", ""))
		if not machines.has(id):
			push_error("%s: the declared actuator '%s' has no machine in "
					% [owner, id] + "the room")
		graph.actuators[id] = {"node": machines.get(id),
				"driven_by": str(bind.get("driven_by", "")),
				"operation": str(bind.get("operation", "command"))}
	return graph


## Whether `machine` is the thing a declared sensor of `kind` is.
static func source_is(kind: String, machine: Variant) -> bool:
	match kind:
		"PRESSURE_PLATE":
			return machine is ClassPlate
		"PULSE_BUTTON":
			return machine is CallLever
		"SHOOTABLE_TARGET":
			return machine is ImpactReceiver
	return false


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
			# A room that restores after `start` (a hosted minor) shows its
			# lever thrown from this moment, as a Zone route does at start.
			lock_permanent_levers()
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
		elif _pulses_from(source) and not _wired.has(str(key)):
			_wired[str(key)] = true
			var pulse: Signal = (source as CallLever).pulled \
					if source is CallLever else (source as ImpactReceiver).struck
			pulse.connect(_on_pulse.bind(str(key)))
	evaluate(true)
	# A latch restored from the save is already set before anything
	# evaluates, and restoring does not announce -- so the lever that set
	# it is shown thrown here, before the player sees the room.
	lock_permanent_levers()


## D-07: every lever whose latch is set stays thrown, and says so. A
## lever is permanent only because the builder said which latch it sets
## (`CallLever.locks_with`); a call control names none and is never
## locked.
func lock_permanent_levers() -> void:
	for key: Variant in sensors.keys():
		var lever := sensors[key] as CallLever
		if lever == null or not is_instance_valid(lever) \
				or lever.locks_with == "" or lever.locked:
			continue
		if latched.has(lever.locks_with):
			lever.lock(lever.done_label if lever.done_label != ""
					else PERMANENT_LEVER_DONE)


func _on_sensor(_satisfied: bool) -> void:
	evaluate()


## Whether a source's output is a PULSE: a PULSE_BUTTON's lever, or a
## SHOOTABLE_TARGET's receiver, which "emits one pulse per valid hit"
## (EX50-021 §3) and debounces a burst of impacts into one.
static func _pulses_from(source: Variant) -> bool:
	return source is CallLever or source is ImpactReceiver


## A PULSE_BUTTON pulled, or a target struck: one tick with its pulse
## raised, then gone. What the signal carried -- the lever, or where the
## shot came from -- is not an input (§9: the last hit source "is not the
## progression authority").
func _on_pulse(_payload: Variant, sensor_id: String) -> void:
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
	if _pulses_from(source):
		return _pulses.has(sensor_id)
	return false


func _physics_process(delta: float) -> void:
	advance(delta)


## RUN THE TIMERS DOWN. A TIMER running out is its output falling, so the
## graph evaluates on that tick -- the one change here that no sensor
## announces. Nothing runs, nothing is evaluated. Split out so a suite
## can step it by hand, in the idiom every machine here uses.
func advance(delta: float) -> void:
	if timers.is_empty() and _live_timers.is_empty() and overrides.is_empty() \
			and bridges.is_empty() and probes.is_empty():
		return
	var lapsed := _run_down(timers, delta)
	lapsed = _run_down(_live_timers, delta) or lapsed
	# A VERB EXPIRING is a change no sensor announces, like a TIMER's.
	for id: Variant in overrides.keys():
		var entry: Dictionary = overrides[id]
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) <= 0.0:
			overrides.erase(id)
			lapsed = true
	var standing: Array = []
	for raw: Variant in bridges:
		var edge: Dictionary = raw
		edge["left"] = float(edge["left"]) - delta
		if float(edge["left"]) > 0.0:
			standing.append(edge)
	if standing.size() != bridges.size():
		bridges = standing
		_bridged_order = _topological(bridges)
		lapsed = true
	_run_down(probes, delta)
	if lapsed and not verbs_standing() and not is_same(verified, values):
		# THE LAST VERB IS GONE: the verified track is the machine again,
		# and what the verbs did to the live one is dropped with them.
		# (Split only; an ordinary TIMER lapse has one track already.)
		_live_timers.clear()
		values = verified.duplicate()
	if lapsed:
		evaluate()


## Count every entry down by `delta`; true when one ran out.
static func _run_down(clock: Dictionary, delta: float) -> bool:
	var lapsed := false
	for id: Variant in clock.keys():
		var left := float(clock[id]) - delta
		if left <= 0.0:
			clock.erase(id)
			lapsed = true
		else:
			clock[id] = left
	return lapsed


## Seconds a TIMER has left; 0 when it is OFF.
func timer_left(node_id: String) -> float:
	return float(timers.get(node_id, 0.0))


## ONE TICK. Sensors, then logic in declaration order, then the
## actuators -- so every node reads values from this tick and none from
## the last one.
##
## **TWO TRACKS ONLY WHILE A VERB STANDS** (H-GRAPHS). With none, there is
## one track, exactly as before the verbs: `values` and `timers` are the
## machine, and `verified` is `values`. While one stands, `verified` is
## the graph with no verb applied -- it sets the latches and keeps the
## verified TIMERs -- and `values` is the graph as the verbs leave it,
## which drives the actuators.
func evaluate(settle := false) -> void:
	ticks += 1
	var split := verbs_standing()
	if not split:
		verified = values
	for key: Variant in sensors.keys():
		var id := str(key)
		var read := _read(id)
		verified[id] = read
		values[id] = _overridden(id, read)
	for raw: Variant in (_bridged_order if not bridges.is_empty() else nodes):
		var node: Dictionary = raw
		var id := str(node["id"])
		if not split:
			values[id] = _resolve(node, values, timers, true)
			continue
		verified[id] = _resolve(node, verified, timers, true)
		values[id] = _overridden(id, _resolve(node, values, _live_timers,
				false))
	for key: Variant in actuators.keys():
		var binding: Dictionary = actuators[key]
		var driven := str(binding.get("driven_by", ""))
		if not values.has(driven):
			continue
		var value := bool(values[driven]) or _bridged_into(str(key), values)
		_drive(binding, _overridden(str(key), value), settle)


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
##
## `vals` and `clock` are one track's values and TIMERs. On the live track
## a standing BRIDGE ORs its source into this node's input.
func _resolve(node: Dictionary, vals: Dictionary, clock: Dictionary,
		is_verified: bool) -> bool:
	var inputs: Array = node.get("inputs", []) as Array
	if inputs.is_empty():
		return false
	var id := str(node.get("id", ""))
	var bridged := false if is_verified else _bridged_into(id, vals)
	match str(node.get("kind", "")):
		"NOT":
			return not (bool(vals.get(str(inputs[0]), false)) or bridged)
		"OR":
			# §19.2: ON when any input is ON. Two to four Booleans, which
			# the schema checked; a pulse cannot reach here (§19.1).
			for feed: Variant in inputs:
				if bool(vals.get(str(feed), false)):
					return true
			return bridged
		"TIMER":
			# §19.2: ON for `duration` after a pulse; "a new pulse restarts
			# it". The schema proved the input is a pulse and the duration
			# is there. `advance` runs it down.
			if bool(vals.get(str(inputs[0]), false)) or bridged:
				clock[id] = float(node.get("duration", 0.0))
			return float(clock.get(id, 0.0)) > 0.0
		"LATCH":
			# SET BY A TRUE INPUT AND NEVER RESET. §19.2's latch has no
			# clear in this slice, because the puzzle it is here for is
			# "open it once and walk through", and a latch that could
			# clear is a door that can shut behind you.
			#
			# SET ON THE VERIFIED TRACK ONLY (N-15): the live track reads
			# the record, so no verb upstream can make the decision.
			if latched.has(id):
				return true
			if is_verified and bool(vals.get(str(inputs[0]), false)):
				latched[id] = true
				fired.emit(package_id(), id)
				lock_permanent_levers()
				return true
			return false
		_:
			return false


## Whether a standing BRIDGE into `id` carries an ON source this tick.
func _bridged_into(id: String, vals: Dictionary) -> bool:
	for raw: Variant in bridges:
		var edge: Dictionary = raw
		if str(edge["to"]) == id and bool(vals.get(str(edge["from"]), false)):
			return true
	return false


## A node's value as the verbs leave it (§19.7 step 1).
func _overridden(id: String, computed: bool) -> bool:
	match str((overrides.get(id, {}) as Dictionary).get("verb", "")):
		"INVERT":
			return not computed
		"HOLD_SIGNAL":
			return true
		"CUT":
			return false
	return computed


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
	for id: Variant in overrides.keys():
		parts.append("%s under %s" % [id,
				(overrides[id] as Dictionary)["verb"]])
	for raw: Variant in bridges:
		parts.append("BRIDGE %s->%s" % [(raw as Dictionary)["from"],
				(raw as Dictionary)["to"]])
	return "%s: %s" % [room_id, ", ".join(parts)]


# ---------------------------------------------------------------------------
# H-GRAPHS: the signal verbs (Design 3 §14, §19.7). Runtime-only.
# ---------------------------------------------------------------------------

## Whether any INVERT, HOLD_SIGNAL, CUT or BRIDGE is standing. PROBE
## changes nothing, so it does not count.
func verbs_standing() -> bool:
	return not overrides.is_empty() or not bridges.is_empty()


## The first verb splits the machine in two: both tracks start from where
## it stands now, TIMERs included, so the verified one carries on exactly
## as if no verb had come.
func _split() -> void:
	if verbs_standing():
		return
	verified = values.duplicate()
	_live_timers = timers.duplicate()


## What `id` is for §14.3: "SENSOR", a logic node's kind, or "ACTUATOR"
## (its input); "" when this graph has no such thing.
func target_kind(id: String) -> String:
	if sensors.has(id):
		return "SENSOR"
	for raw: Variant in nodes:
		if str((raw as Dictionary)["id"]) == id:
			return str((raw as Dictionary).get("kind", ""))
	if actuators.has(id):
		return "ACTUATOR"
	return ""


## APPLY ONE SIGNAL VERB (§14.1) to `target` for `magnitude` seconds; a
## BRIDGE runs from `target` to `destination`.
##
## Returns `{"ok": true}` -- and for PROBE, `"probe"`, what it reveals --
## or `{"ok": false, "reason": ...}` with NOTHING CHANGED: a refused verb
## is refused before it touches the graph, so it costs nothing (§19.7).
## Applied at once, as the next tick's step 1.
func apply_verb(verb: String, target: String, magnitude: float,
		destination := "") -> Dictionary:
	if not verb in VERBS:
		return _refused("'%s' is not a signal verb" % verb)
	if magnitude <= 0.0:
		return _refused("a signal verb lasts a positive number of seconds")
	var kind := target_kind(target)
	if kind == "":
		return _refused("'%s' is not part of %s's machine" % [target, room_id])
	var legal: Array = VERB_LEGALITY.get(kind, [])
	match verb:
		"PROBE":
			probes[target] = magnitude
			return {"ok": true, "probe": probe(target)}
		"BRIDGE":
			if not "BRIDGE_FROM" in legal:
				return _refused("%s (%s) cannot be a BRIDGE's source (§14.3)"
						% [target, kind])
			var to_kind := target_kind(destination)
			if to_kind == "":
				return _refused("'%s' is not part of %s's machine"
						% [destination, room_id])
			if not "BRIDGE_TO" in (VERB_LEGALITY.get(to_kind, []) as Array):
				return _refused("%s (%s) cannot be a BRIDGE's destination "
						% [destination, to_kind] + "(§14.3)")
			var trial: Array = bridges.duplicate(true)
			trial.append({"from": target, "to": destination,
					"left": magnitude})
			var order := _topological(trial)
			if order.size() != nodes.size():
				return _refused("a BRIDGE from %s to %s would close a cycle "
						% [target, destination] + "(§19.7)")
			_split()
			bridges = trial
			_bridged_order = order
		_:
			if not verb in legal:
				return _refused("%s (%s) cannot take %s (§14.3)"
						% [target, kind, verb])
			_split()
			overrides[target] = {"verb": verb, "left": magnitude}
	evaluate()
	return {"ok": true}


## §14.1's PROBE: "a node's current value, its inputs, and its governing
## predicate". `value` is what the machine does now; `verified` is what it
## would do with no verb standing; `verb` is the one on it, if any.
func probe(id: String) -> Dictionary:
	var kind := target_kind(id)
	var out := {"id": id, "kind": kind,
			"value": bool(values.get(id, false)),
			"verified": bool(verified.get(id, false)),
			"verb": str((overrides.get(id, {}) as Dictionary).get("verb", "")),
			"inputs": [], "predicate": kind}
	var feeds: Array = []
	if kind == "ACTUATOR":
		feeds = [str((actuators[id] as Dictionary).get("driven_by", ""))]
		out["value"] = bool(values.get(feeds[0], false))
	for raw: Variant in nodes:
		var node: Dictionary = raw
		if str(node["id"]) != id:
			continue
		feeds = (node.get("inputs", []) as Array).duplicate()
		match kind:
			"TIMER":
				out["predicate"] = "TIMER %.1fs, %.1fs left" % [
						float(node.get("duration", 0.0)),
						float(_live_timers.get(id, 0.0))]
			"LATCH":
				out["predicate"] = "LATCH, %s" % (
						"set" if latched.has(id) else "not set")
	for raw: Variant in bridges:
		if str((raw as Dictionary)["to"]) == id:
			feeds.append(str((raw as Dictionary)["from"]))
	for feed: Variant in feeds:
		(out["inputs"] as Array).append({"id": str(feed),
				"value": bool(values.get(str(feed), false))})
	return out


## Declaration order, with `edges` (BRIDGEs) honoured: a node comes after
## every node it reads. Fewer nodes than declared means a cycle. Sensors
## are evaluated first and actuators last, so only a node-to-node edge
## can move anything.
func _topological(edges: Array) -> Array:
	var ids := {}
	for raw: Variant in nodes:
		ids[str((raw as Dictionary)["id"])] = true
	var reads := {}
	for raw: Variant in nodes:
		var node: Dictionary = raw
		var id := str(node["id"])
		var from: Array = []
		for feed: Variant in node.get("inputs", []) as Array:
			if ids.has(str(feed)):
				from.append(str(feed))
		for edge: Variant in edges:
			if str((edge as Dictionary)["to"]) == id \
					and ids.has(str((edge as Dictionary)["from"])):
				from.append(str((edge as Dictionary)["from"]))
		reads[id] = from
	var placed := {}
	var order: Array = []
	var moved := true
	while moved and order.size() < nodes.size():
		moved = false
		for raw: Variant in nodes:
			var id := str((raw as Dictionary)["id"])
			if placed.has(id):
				continue
			var ready := true
			for need: Variant in reads[id]:
				if not placed.has(need):
					ready = false
					break
			if ready:
				placed[id] = true
				order.append(raw)
				moved = true
	return order


static func _refused(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
