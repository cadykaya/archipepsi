class_name StateGates
extends RefCounted
## THE DOORWAY A DECLARED ZONE-STATE CONDITION CLOSES (O05-02 / O05-04).
##
## `TopologyEdge.requires_state` says a route is passable only while a
## Zone-state variable holds a state, and `topology.reachability` has
## honoured that since D-8. Until this file, nothing in the engine did:
## the edge was shut in logic and open in the world. That direction never
## strands anybody, but it is not the declaration either -- a delivery
## that "opens the way on" opened nothing a player could see.
##
## **One shutter per declared condition, in that edge's own doorway,**
## sized from the committed door frame the same way P14's latch shutter
## is (`RoomGraphs.route_shutter`), and in the same `ROUTE_GATE` group, so
## the aperture audit reads it as declared content rather than as a wall
## where a door should be. It is open exactly while every condition on
## its edge holds, bound to the variable BY ID -- never to the control or
## consumer that sets it.
##
## **It refuses rather than guess**, and a refused gate is left OPEN:
## - a condition on a variable the Zone did not build a setter for
##   (refused by `ZoneStateBuild`, or never declared) would be a door no
##   player can open, which is exactly the physical gate the route logic
##   must never be surprised by;
## - an edge that ALSO carries `opened_by` already has P14's shutter in
##   that doorway, and two panels in one opening would fight. That
##   stacking is finding P5-1 (the D-8 composer puts `requires_state` on
##   P14's edge), recorded, not resolved here;
## - an edge whose doorway this layout did not build.
## A refused gate leaves logic STRICTER than the world, which can only
## ever under-promise a route, never trap anyone behind one.

## `{"gates": [StateGate...], "refused": [String...]}`.
static func build(root: Node3D, edges: Array, chambers: Array,
		door_frames: Dictionary, state: ZoneState, operable: Array,
		theme := "concrete_facility") -> Dictionary:
	var gates: Array = []
	var refused: Array[String] = []
	for raw: Variant in edges:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = raw
		var conditions: Array = edge.get("requires_state", []) as Array
		if conditions.is_empty():
			continue
		var edge_id := str(edge.get("edge_id", ""))
		var latch: Variant = edge.get("opened_by")
		if latch != null and str(latch) != "":
			refused.append(("edge '%s' is shut by latch '%s' and by Zone "
					% [edge_id, str(latch)])
					+ "state; one doorway takes one shutter (P5-1)")
			continue
		var why := ""
		var wanted: Dictionary = {}
		for c: Variant in conditions:
			var cond: Dictionary = c
			var id := str(cond.get("variable_id", ""))
			if not state.declares(id):
				why = "variable '%s' is not declared" % id
				break
			if not id in operable:
				why = ("variable '%s' has no control or consumer the "
						% id) + "engine built, so nothing could open it"
				break
			wanted[id] = str(cond.get("state", ""))
		if why != "":
			refused.append("edge '%s': %s" % [edge_id, why])
			continue
		var frame := RoomGraphs.doorway_frame(str(edge.get("room_a", "")),
				edge, chambers, door_frames)
		if frame.is_empty():
			frame = RoomGraphs.doorway_frame(str(edge.get("room_b", "")),
					edge, chambers, door_frames)
		if frame.is_empty():
			refused.append("edge '%s': this layout built no doorway for it"
					% edge_id)
			continue
		var shutter := RoomGraphs.route_shutter(frame, theme)
		shutter.name = "StateGate_%s" % edge_id.replace(":", "_")
		root.add_child(shutter)
		var gate := StateGate.new(edge_id, wanted, shutter, state)
		gates.append(gate)
	return {"gates": gates, "refused": refused}


## One gated doorway, bound to its conditions by variable id.
class StateGate extends RefCounted:
	var edge_id := ""
	## `{variable_id: state}`: open while every one holds.
	var wanted: Dictionary = {}
	var shutter: ServiceShutter = null
	var _state: ZoneState = null

	func _init(edge: String, conditions: Dictionary, panel: ServiceShutter,
			state: ZoneState) -> void:
		edge_id = edge
		wanted = conditions
		shutter = panel
		_state = state
		state.changed.connect(_on_changed)
		# THE RESTORED VALUE, settled rather than animated: a route the
		# save says is open is open when the Zone loads.
		shutter.settle(holds())

	func holds() -> bool:
		for id: Variant in wanted:
			if _state.value_of(str(id)) != str(wanted[id]):
				return false
		return true

	## QUEUED, NOT APPLIED (O05-04.4): the conditions say shut and the
	## panel is still open, because §21.2's interlock is holding it for
	## somebody in the doorway. It closes by itself once they are out.
	func closing_is_queued() -> bool:
		return not holds() and not shutter.is_shut()

	## What the doorway is doing, in words a toast can carry.
	func describe() -> String:
		if holds():
			return "OPEN" if shutter.is_open() else "OPENING"
		if shutter.is_shut():
			return "SHUT"
		if shutter.doorway_occupied() or shutter.reversing():
			return "CLOSING QUEUED · DOORWAY OCCUPIED"
		return "CLOSING"

	func _on_changed(id: String, _value: String) -> void:
		if not wanted.has(id):
			return
		shutter.command(holds())
