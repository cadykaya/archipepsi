class_name ShuttleDeck
extends AnimatableBody3D
## A LEVEL deck that runs between ordered stops on a straight axis.
##
## **Why this is not a `RailCarrier`.** That one runs an offset along a
## curved `RailPath` and turns its deck to face the way it is going,
## which is right for a skiff on a railway and wrong for a lift: on a
## vertical path the same arithmetic stands the deck on end and the
## passenger falls off it. `RailPath` refuses a path past 75 degrees for
## a related reason, and that refusal is correct — a lift is a different
## machine, not a rail with a steeper rail.
##
## What the two DO share is how either gets from one stop to the next,
## and that is `StopTravel`, so there is one authoring of it rather than
## two schedules that happen to agree today (EX50-011 §9's "shared
## machinery contract").
##
## **An authored intermediate dwell is the point of the class.** EX50-011
## §2 asks for a lift whose control visits y=4 before y=8 and pauses
## there for a declared interval that is "visible as a docking slowdown,
## not a hidden grace period". So the dwell is a property of the STOP,
## declared with the stops, and the machine announces entering it.
##
## **One destination, one motion state** (§8). Repeated calls cannot
## create multiple scheduled arrivals: a second call replaces the
## destination, it does not queue behind the first. And a stopped deck
## does not resume because somebody stood on it — §4 requires a visible
## command — so `resume` is the only way out of `stop`.

## Arrived at the stop it was sent to.
signal arrived(stop: int)
## Paused at an intermediate stop, for the declared interval. Emitted so
## a readout can show a docking slowdown rather than the player guessing.
signal dwelling(stop: int, seconds: float)
## A command that could not be honoured, with a reason a player can act on.
signal refused(reason: String, detail: String)

## Service speed. EX50-011 §2 proposes 1.5 m/s for both carriers and says
## in the same breath that it is not final movement tuning.
const SPEED := 1.5
const ACCEL := 2.0
const STOP_EPSILON := 0.03

var axis := Vector3.UP
## Where the deck's TOP sits at offset 0, so a stop is given as the
## height (or position) a passenger actually stands at.
var origin := Vector3.ZERO
var stops: PackedFloat32Array = PackedFloat32Array()
var stop_ids: PackedStringArray = PackedStringArray()
## Seconds held on the way THROUGH stop `i`. Zero for a stop that is
## only ever a destination.
var dwells: PackedFloat32Array = PackedFloat32Array()
var deck := Vector3(4.0, 0.4, 4.0)

var offset := 0.0
var speed := 0.0
## The stop it is going to. Always a valid index: a parked deck's
## destination is where it is parked.
var destination := 0
var held := false

var _dwell_left := 0.0
var _dwell_at := -1
var _theme := "concrete_facility"
var _malformed: Array[String] = []


static func create(axis_in: Vector3, origin_in: Vector3,
		stops_in: PackedFloat32Array, ids: PackedStringArray,
		dwells_in: PackedFloat32Array, deck_size: Vector3,
		theme := "concrete_facility") -> ShuttleDeck:
	var made := ShuttleDeck.new()
	made.axis = axis_in.normalized() if axis_in.length() > 0.001 \
			else Vector3.UP
	made.origin = origin_in
	made.stops = stops_in
	made.stop_ids = ids
	made.dwells = dwells_in
	made.deck = deck_size
	made._theme = theme
	made.offset = stops_in[0] if not stops_in.is_empty() else 0.0
	made.name = "ShuttleDeck"
	return made


func _ready() -> void:
	# A MALFORMED MACHINE DOES NOT MOVE, in the idiom `RailCarrier` set:
	# it is still built, because an invisible lift is a harder defect to
	# see than a stationary one, and it refuses every command by name.
	_malformed = violations()
	if not _malformed.is_empty():
		push_warning("shuttle deck refused: %s" % "; ".join(_malformed))
	# The property the measured carry depends on. Without it the deck
	# moves without the physics server knowing and the rider is left.
	sync_to_physics = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = deck
	shape.shape = box
	add_child(shape)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Deck"
	var mesh := BoxMesh.new()
	mesh.size = deck
	mesh_node.mesh = mesh
	mesh_node.material_override = ThemeMaterials.trim_mat(_theme)
	add_child(mesh_node)
	_place()


## Every way this is not a shuttle. Empty is the contract.
func violations(who := "shuttle") -> Array[String]:
	var out: Array[String] = []
	if stops.size() < 2:
		out.append("%s: needs at least two stops, got %d"
				% [who, stops.size()])
		return out
	if stop_ids.size() != stops.size():
		out.append("%s: %d stops but %d names"
				% [who, stops.size(), stop_ids.size()])
	if dwells.size() != stops.size():
		out.append("%s: %d stops need %d dwell times, got %d"
				% [who, stops.size(), stops.size(), dwells.size()])
	for i in stops.size():
		if i == 0:
			continue
		if stops[i] - stops[i - 1] <= STOP_EPSILON * 2.0:
			out.append("%s: stops %d and %d are %.3f apart, which is not "
					% [who, i - 1, i, stops[i] - stops[i - 1]]
					+ "two stops")
	if deck.x <= 0.0 or deck.y <= 0.0 or deck.z <= 0.0:
		out.append("%s: the deck %v has no volume" % [who, deck])
	return out


## Which stop the deck is standing at, or -1 while travelling.
func at_stop() -> int:
	for i in stops.size():
		if absf(offset - stops[i]) <= STOP_EPSILON:
			return i
	return -1


func stop_id(index: int) -> String:
	return stop_ids[index] if index >= 0 and index < stop_ids.size() \
			else ""


## Is the deck holding at an intermediate stop right now?
func dwelling_at() -> int:
	return _dwell_at if _dwell_left > 0.0 else -1


func dwell_left() -> float:
	return _dwell_left


## Send it to a stop.
##
## ONE DESTINATION, ONE MOTION STATE (§8). A second call replaces the
## first rather than queueing behind it, and calling the stop it is
## already parked at is not an error -- it is a player checking.
func go_to(index: int) -> bool:
	if not _malformed.is_empty():
		refused.emit("not_a_shuttle", "; ".join(_malformed))
		return false
	if index < 0 or index >= stops.size():
		refused.emit("no_such_stop", "there is no stop %d" % index)
		return false
	if held:
		# The saved destination still changes: §4 says resume follows the
		# SAVED destination, so a call while stopped is how a player
		# chooses where it goes when they release it.
		destination = index
		refused.emit("held", "the deck is stopped; it will go to %s when "
				% stop_id(index) + "it is released")
		return false
	destination = index
	return true


## A visible STOP. Holds the deck where it is, dwell included.
##
## §9: a deck caught in a dwell stays safely held until the player
## resumes, rather than counting down behind a closed application and
## leaving from under them.
func stop_here() -> void:
	held = true
	speed = 0.0


## The only way out of `stop_here`. §4: a stopped carrier does not resume
## because the player landed on it; the first version requires a visible
## command.
func resume() -> void:
	held = false


func _physics_process(delta: float) -> void:
	advance(delta)


## One step. Split out so a suite can step the machine by hand: a dwell
## measured against wall-clock frames is a test that passes on a fast
## machine.
func advance(delta: float) -> void:
	if held or not _malformed.is_empty():
		return
	if _dwell_left > 0.0:
		_dwell_left = maxf(_dwell_left - delta, 0.0)
		return
	var here := at_stop()
	if here == destination:
		speed = 0.0
		return
	# THE NEXT STOP, not the destination: the lift visits the stops
	# between, which is what makes an authored intermediate pause
	# possible at all.
	var next := _next_toward(destination)
	if next < 0:
		return
	var goal: float = stops[next]
	var moved := StopTravel.step(offset, goal, speed, delta,
			ACCEL, SPEED, STOP_EPSILON)
	offset = moved.x
	speed = moved.y
	_place()
	if absf(goal - offset) > STOP_EPSILON:
		return
	offset = goal
	speed = 0.0
	_place()
	if next == destination:
		arrived.emit(next)
		return
	# PASSING THROUGH. A declared dwell is held here, visibly.
	if next < dwells.size() and dwells[next] > 0.0:
		_dwell_left = dwells[next]
		_dwell_at = next
		dwelling.emit(next, dwells[next])


## The next stop on the way to `goal`, or -1 when there is none.
func _next_toward(goal: int) -> int:
	var here := at_stop()
	if here >= 0:
		if goal > here:
			return here + 1
		if goal < here:
			return here - 1
		return here
	# BETWEEN STOPS, which is where a resumed STOP leaves the deck: the
	# first stop beyond it in the direction of travel. `stops` ascends,
	# so that is the lowest stop above the deck going up and the highest
	# below it going down.
	if stops[goal] > offset:
		for i in stops.size():
			if stops[i] > offset + STOP_EPSILON:
				return i
	else:
		for i in range(stops.size() - 1, -1, -1):
			if stops[i] < offset - STOP_EPSILON:
				return i
	return goal


func _place() -> void:
	# The deck's TOP is what a passenger stands on, so the body sits half
	# a deck below the offset the stops are named in.
	global_position = origin + axis * offset \
			- Vector3(0.0, deck.y * 0.5, 0.0)
