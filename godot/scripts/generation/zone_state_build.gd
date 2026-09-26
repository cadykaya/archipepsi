class_name ZoneStateBuild
extends RefCounted
## WHAT A DECLARED CROSS-ROOM RELATIONSHIP IS MADE OF.
##
## `Zone.zone_state` (D-8) names a variable, one setter room and one or
## more reader rooms. This builds the physical half: a control the
## player walks to and operates, and a mechanism somewhere else that
## follows the value.
##
## **THE READER BINDS TO THE VARIABLE, NEVER TO THE SETTER'S NODE.**
## That is the stale reference the owner warned about, and the contract
## already makes it unwritable -- `ZoneStateReader` carries a
## `variable_id` and has no field that could hold a node. This file
## keeps the same property at runtime: a reader connects to
## `ZoneState.changed` and looks its own variable up by id. Rebuild the
## setter's room, or never build it at all, and every reader still
## works, because none of them has ever held a reference to anything in
## it.
##
## **THE MECHANISM VOCABULARY IS CLOSED**, for the reason every other
## vocabulary here is closed: a `mechanism` the engine does not
## implement would be a declaration that reads as satisfied and drives
## nothing, which is the inert-component failure the staged gates exist
## to prevent. An unknown mechanism is refused BY NAME and the variable
## builds nothing.

## A panel that blocks a route in one state and clears it in another.
## The remote consequence a cross-room relationship is FOR: something a
## player has to get past, whose state was decided in another room.
const BARRIER := "barrier"
## A light. Legibility rather than mechanics, and the mechanism a reader
## in the SETTER'S OWN ROOM is usually for -- see the owner's correction
## of 2026-09-22: a control that also shows you something where you are
## standing is ordinary content, not a violation.
const LAMP := "lamp"

const MECHANISMS := [BARRIER, LAMP]

const BARRIER_SIZE := Vector3(3.6, 2.8, 0.4)
## How far the barrier slides to clear its opening.
const BARRIER_TRAVEL := 3.0
const LAMP_SIZE := Vector3(0.4, 0.4, 0.4)
## Where the setter's control stands, relative to its room's arrival.
##
## ALONG THE ROOM, NOT ACROSS IT, and clamped into the room's committed
## bounds before it is used. The first cut offset 2.6 m SIDEWAYS and put
## the control through a corridor's wall: the player walked up to a
## lever they could not see, the interact ray hit the wall at x -2.3
## instead, and `_interact_target` stayed null. A room's width is not a
## constant this file gets to assume -- `room_bounds` is the committed
## answer and `_inside` is where it is asked.
##
## THE LIFT IS NOT DECORATION EITHER. A `CallLever`'s origin is the
## centre of its base, so placing one AT arrival height buries half of
## it in the floor. `railway_scenario` and `unweighted_switch` both lift
## theirs by the same half-base.
const SETTER_OFFSET := Vector3(0.0, CallLever.BASE.y * 0.5, 2.2)
## Where a reader's mechanism stands, relative to its room's arrival.
const BARRIER_OFFSET := Vector3(0.0, 0.0, 4.5)
const LAMP_OFFSET := Vector3(0.0, 1.8, 2.2)
## How far inside a room's own walls anything placed here must stay.
const WALL_MARGIN := 1.2


## Build every relationship a Zone declares.
##
## `state` is the live `ZoneState`; `places` is `room_places` off the
## committed layout. Returns
## `{"setters": [...], "readers": [...], "refused": [...]}`.
##
## `consumer_owned` names the variables an `ObjectConsumer` sets (P16).
## Their setter IS the installation -- the socket the object is carried
## to -- so no lever is built for them: a lever would let the player
## select the consequence without making the delivery, which is exactly
## what the bridge refuses a raw `zone_state_selected` for. Their readers
## are built as usual. `built` lists every variable that has something a
## player can operate, lever or consumer, for the doorway gates to check.
static func build(root: Node3D, variables: Array, state: ZoneState,
		places: Dictionary, bounds: Dictionary = {},
		theme := "concrete_facility",
		consumer_owned: Array = []) -> Dictionary:
	var setters: Array = []
	var readers: Array = []
	var built: Array = []
	var refused: Array[String] = []
	for raw: Variant in variables:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = raw
		var made := _one(root, one, state, places, bounds, theme,
				str(one.get("variable_id", "")) in consumer_owned)
		var why := str(made.get("refused", ""))
		if why != "":
			refused.append(why)
			continue
		built.append(str(one.get("variable_id", "")))
		if made["setter"] != null:
			setters.append(made["setter"])
		for reader: Variant in made["readers"] as Array:
			readers.append(reader)
	return {"setters": setters, "readers": readers, "built": built,
			"refused": refused}


## Keep a point inside the room it is meant to be in.
##
## A generated room's width is whatever the composer gave it, so an
## offset that fits one corridor puts the next one's control in the
## plaster. The bounds are the committed layout's, read rather than
## guessed, and a room with no recorded bounds is left alone rather than
## clamped to nothing.
static func _inside(at: Vector3, box: AABB) -> Vector3:
	if box.size == Vector3.ZERO:
		return at
	var lo := box.position + Vector3(WALL_MARGIN, 0.0, WALL_MARGIN)
	var hi := box.position + box.size - Vector3(WALL_MARGIN, 0.0,
			WALL_MARGIN)
	return Vector3(
			clampf(at.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)),
			at.y,
			clampf(at.z, minf(lo.z, hi.z), maxf(lo.z, hi.z)))


static func _one(root: Node3D, one: Dictionary, state: ZoneState,
		places: Dictionary, bounds: Dictionary, theme: String,
		by_consumer := false) -> Dictionary:
	var id := str(one.get("variable_id", ""))
	if not state.declares(id):
		return {"refused": "variable '%s' was not declared" % id}
	var setter: Dictionary = one.get("setter", {}) as Dictionary
	var setter_room := str(setter.get("room_id", ""))
	if not places.has(setter_room):
		return {"refused": "variable '%s' sets in room '%s', which this "
				% [id, setter_room] + "Zone did not build"}
	var reader_list: Array = one.get("readers", []) as Array
	if reader_list.is_empty():
		return {"refused": "variable '%s' declares no reader" % id}
	# EVERY MECHANISM CHECKED BEFORE ANYTHING IS BUILT, so a variable
	# with one good reader and one unknown one builds neither half
	# rather than a working setter driving nothing.
	for raw: Variant in reader_list:
		var reader: Dictionary = raw
		var mechanism := str(reader.get("mechanism", ""))
		if not mechanism in MECHANISMS:
			return {"refused": ("variable '%s' drives mechanism '%s', "
					% [id, mechanism])
					+ "which the engine does not implement; it has %s"
					% [MECHANISMS]}
		if not places.has(str(reader.get("room_id", ""))):
			return {"refused": "variable '%s' reads in room '%s', which "
					% [id, str(reader.get("room_id", ""))]
					+ "this Zone did not build"}

	var control: ZoneStateSetterControl = null
	if not by_consumer:
		control = ZoneStateSetterControl.create(id, state.selectable(id),
				theme)
		root.add_child(control)
		control.global_position = _inside(
				(places[setter_room] as Dictionary).get(
					"arrival", Vector3.ZERO) as Vector3 + SETTER_OFFSET,
				bounds.get(setter_room, AABB()) as AABB)
		control.bind(state)

	var built: Array = []
	for raw: Variant in reader_list:
		var reader: Dictionary = raw
		var mechanism := str(reader.get("mechanism", ""))
		var room := str(reader.get("room_id", ""))
		var when: Array = reader.get("when", []) as Array
		var at: Vector3 = (places[room] as Dictionary).get(
				"arrival", Vector3.ZERO)
		var node := ZoneStateMechanism.create(id, mechanism, when, theme)
		root.add_child(node)
		node.global_position = _inside(
				at + (BARRIER_OFFSET if mechanism == BARRIER
					else LAMP_OFFSET),
				bounds.get(room, AABB()) as AABB)
		# BOUND BY ID, through the state object. The mechanism never sees
		# the control and could not hold a reference to it if it wanted
		# one.
		node.bind(state)
		built.append(node)
	return {"setter": control, "readers": built}


## THE CONTROL THE PLAYER OPERATES. §19.7's "which the player then
## performs", and the only thing in the engine that calls
## `ZoneState.select`.
##
## A `CallLever` rather than a new interactable: the player already
## knows what a lever is, `interact` already drives one, and a second
## kind of control would be a second thing to learn for no mechanical
## difference. Operating it steps to the next state the declaration says
## it may choose, so a two-state variable is a toggle and a four-state
## one is a selector, without either being a separate class.
class ZoneStateSetterControl extends CallLever:
	var variable_id := ""
	var selects: Array = []
	## What the campaign has said about the last selection: "PENDING"
	## until the snapshot carries it, then "ACCEPTED", or "REFUSED" (and
	## the value put back). Set by the controller; empty before any pull.
	var status := ""
	var _state: ZoneState = null

	## WHAT A PULL WILL DO, what it holds now, and what the campaign said.
	## O05-04.2: "the source feedback identifies what was accepted or
	## pending".
	func interact_prompt() -> String:
		if _state == null or selects.is_empty():
			return "[E] %s" % label
		var here := _state.value_of(variable_id)
		var at := selects.find(here)
		var next := str(selects[(at + 1) % selects.size()])
		return "[E] %s -> %s   (now %s%s)" % [variable_id.to_upper(),
				next.to_upper(), here.to_upper(),
				(" · " + status) if status != "" else ""]

	static func create(id: String, choices: Array,
			theme := "concrete_facility") -> ZoneStateSetterControl:
		var made := ZoneStateSetterControl.new()
		made.variable_id = id
		made.selects = choices.duplicate()
		made.label = "SET %s" % id.to_upper()
		made.name = "ZoneStateSetter_%s" % id
		made._build(Color(0.55, 0.85, 1.0), theme)
		return made

	func bind(state: ZoneState) -> void:
		_state = state
		pulled.connect(_on_pulled)

	## Step to the next selectable state and ask the Zone for it.
	##
	## The order is the declaration's order, so what a second pull does
	## is a property of the Zone rather than of this control.
	func _on_pulled(_who: CallLever) -> void:
		if _state == null or selects.is_empty():
			return
		var here := _state.value_of(variable_id)
		var at := selects.find(here)
		var next: String = str(selects[(at + 1) % selects.size()])
		_state.select(variable_id, next)


## WHAT RESPONDS, IN THE OTHER ROOM.
##
## Binds to the variable by id and to nothing else. `when` is the set of
## states in which the mechanism is DRIVEN -- open, for a barrier; lit,
## for a lamp -- and every other state is its resting position.
class ZoneStateMechanism extends Node3D:
	var variable_id := ""
	var mechanism := ""
	var when: Array = []
	## Whether the mechanism is currently driven. Recomputed from the
	## variable, never stored anywhere that could disagree with it.
	var driven := false

	var _panel: StaticBody3D = null
	var _lamp: MeshInstance3D = null
	var _home := Vector3.ZERO
	var _theme := "concrete_facility"

	static func create(id: String, kind: String, states: Array,
			theme := "concrete_facility") -> ZoneStateMechanism:
		var made := ZoneStateMechanism.new()
		made.variable_id = id
		made.mechanism = kind
		made.when = states.duplicate()
		made._theme = theme
		made.name = "ZoneState_%s_%s" % [kind, id]
		return made

	func _ready() -> void:
		_home = global_position
		if mechanism == ZoneStateBuild.BARRIER:
			_panel = StaticBody3D.new()
			_panel.name = "Barrier"
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = ZoneStateBuild.BARRIER_SIZE
			shape.shape = box
			_panel.add_child(shape)
			var mesh_node := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = ZoneStateBuild.BARRIER_SIZE
			mesh_node.mesh = mesh
			mesh_node.material_override = ThemeMaterials.wall_mat(_theme)
			_panel.add_child(mesh_node)
			add_child(_panel)
			_panel.position = Vector3(0.0,
					ZoneStateBuild.BARRIER_SIZE.y * 0.5, 0.0)
		else:
			_lamp = MeshInstance3D.new()
			_lamp.name = "Lamp"
			var lamp_mesh := BoxMesh.new()
			lamp_mesh.size = ZoneStateBuild.LAMP_SIZE
			_lamp.mesh = lamp_mesh
			add_child(_lamp)

	func bind(state: ZoneState) -> void:
		state.changed.connect(_on_changed)
		# THE CURRENT VALUE, NOT AN ASSUMED ONE. A Zone restored from a
		# snapshot has its variables at their saved values before any
		# `changed` fires, so a mechanism that waited for a signal would
		# come up in the wrong position and stay there until somebody
		# operated the control again -- which on a barrier is a route
		# that is open when the save says it is shut.
		_apply(state.value_of(variable_id))

	func _on_changed(id: String, state: String) -> void:
		if id != variable_id:
			return
		_apply(state)

	func _apply(state: String) -> void:
		driven = state in when
		if _panel != null:
			# Slid clear rather than hidden: a barrier that vanished
			# would leave a route open with nothing to see, and `visible`
			# does not move a collider.
			_panel.position = Vector3(0.0,
					ZoneStateBuild.BARRIER_SIZE.y * 0.5
					+ (ZoneStateBuild.BARRIER_TRAVEL if driven else 0.0),
					0.0)
		if _lamp != null:
			_lamp.material_override = ThemeMaterials.glow_material(
					Color(0.55, 1.0, 0.7) if driven
					else Color(0.35, 0.4, 0.5), 2.4 if driven else 0.6)

	## Is the way through clear right now? Asked of the collider's real
	## position, so a suite cannot be told a route is open by a flag.
	func opening_is_clear() -> bool:
		if _panel == null:
			return true
		return _panel.global_position.y \
				> _home.y + ZoneStateBuild.BARRIER_TRAVEL * 0.5
