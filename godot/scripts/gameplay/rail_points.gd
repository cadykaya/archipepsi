class_name RailPoints
extends Node3D
## A turnout: where one track becomes two or more, and the tongue that
## decides which (H-RAIL-BREADTH, DESS-01 item 2's engine half).
##
## **THE SWITCH IS §21.6's `RAIL_SWITCH`, not a second one.** OV04 P15
## built that actuator and proved its clearance rule on a dummy rider;
## this is the first thing that runs a carrier over it. Its `path` is the
## tongue's pose for each leg, so throwing the points MOVES TRACK: the
## tongue swings from one leg to the other over the actuator's
## `travel_time`, and a leg is joined to the heel only once the tongue
## has arrived there (`Actuator.settled_branch`). P17.2: "a route string
## changing while the model and carrier keep following the old path is
## not switching." Here the carrier reads the tongue, and the tongue is
## the thing that moved.
##
## **HEEL AND LEGS.** A turnout joins its heel to exactly one leg. A
## carrier arriving on the heel leaves on whichever leg is set; one
## arriving on a leg continues onto the heel only if that leg is the one
## set. Otherwise the track it is on ends at the tongue, and it is
## refused -- never routed onto the other leg, and never across.
##
## **WHO MAY THROW IT, AND WHEN** is §21.6's, unchanged: at once if the
## rail is clear, QUEUED if not, never dropped. What this slice adds to
## "clear" is the route lock (RB-F1, `Actuator.lock_route`): a carrier
## already committed to passing these points holds them as surely as one
## standing on them.

## The tongue: a length of real track that swings between the legs.
const TONGUE_LENGTH := 3.2
const TONGUE := Vector3(0.55, 0.3, TONGUE_LENGTH)
## How far along a leg the tongue AIMS when it is set for that leg. Every
## leg leaves the points tangent to the heel (a turnout's legs do), so
## aimed at its first metre each leg looks the same; aimed this far out,
## the tongue visibly swings toward the leg it has chosen.
const TONGUE_AIM := 7.0

## Which network line and end make up the heel and each leg:
## `Vector2i(line, end)`, `end` being `RailNetworkCarrier.START` or `END`.
var points_id := "points"
var heel := Vector2i(-1, -1)
var legs: Array[Vector2i] = []
## What each leg is called where a player reads it: the dock it leads to.
var leg_labels: PackedStringArray = PackedStringArray()
## The heel-side dock, whose track runs through these points.
var dock_index := -1
var actuator: Actuator = null

var _tongue: MeshInstance3D = null
var _sign: Label3D = null
var _theme := "concrete_facility"
var _poses: Array[Transform3D] = []
var _initial := 0
var _at := Vector3.ZERO


## `poses[j]` is the tongue's world pose when set for leg `j`: its origin
## at the points, looking along the leg.
static func create(id: String, where: Vector3, poses: Array[Transform3D],
		heel_end: Vector2i, leg_ends: Array[Vector2i],
		labels: PackedStringArray, initial_leg: int,
		theme := "concrete_facility") -> RailPoints:
	var made := RailPoints.new()
	made.name = "RailPoints_%s" % id
	made.points_id = id
	made._at = where
	made.heel = heel_end
	made.legs = leg_ends
	made.leg_labels = labels
	made._poses = poses
	made._initial = clampi(initial_leg, 0, maxi(leg_ends.size() - 1, 0))
	made._theme = theme
	return made


func _ready() -> void:
	# IN WORLD SPACE, FIRST: the tongue's poses are world transforms, and a
	# node moved after they were applied would carry the tongue with it.
	global_position = _at
	var pivot := Node3D.new()
	pivot.name = "Tongue"
	add_child(pivot)
	_tongue = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = TONGUE
	_tongue.mesh = mesh
	# THE TONGUE HANGS FORWARD OF ITS PIVOT. `Basis.looking_at` faces -Z,
	# so the beam's centre sits half its length down -Z and its heel end
	# stays on the points.
	_tongue.position = Vector3(0.0, 0.0, -TONGUE_LENGTH * 0.5)
	_tongue.material_override = ThemeMaterials.trim_mat(_theme)
	pivot.add_child(_tongue)
	actuator = Actuator.create("RAIL_SWITCH", _poses)
	actuator.name = "Switch"
	actuator.driven = pivot
	add_child(actuator)
	# THE INITIAL LEG IS A FACT, NOT A THROW: nothing moved to get there,
	# so nothing is reported.
	actuator.restore_branch(_initial)
	_sign = Label3D.new()
	_sign.name = "Setting"
	_sign.pixel_size = 0.01
	_sign.font_size = 64
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = Vector3(0.0, 3.4, 0.0)
	add_child(_sign)
	_refresh()


## The leg whose track the tongue joins to the heel right now, or -1 while
## it joins nothing (mid-throw, or stopped there by a power loss).
func live_leg() -> int:
	return actuator.settled_branch() if actuator != null else -1


## The leg the points are set for or travelling toward.
func set_leg() -> int:
	return actuator.branch() if actuator != null else -1


## The leg a throw is waiting to apply, -1 when none is.
func queued_leg() -> int:
	return actuator.queued_branch() if actuator != null else -1


## Ask for leg `index`. "set" when the tongue has started for it (or is
## already there), "queued" when §21.6 or a route lock is holding the
## points and the change will apply when they clear.
func throw_to(index: int) -> String:
	if actuator == null or index < 0 or index >= legs.size():
		return "refused"
	actuator.switch_to(index)
	_refresh()
	return "queued" if actuator.queued_branch() == index else "set"


## The next leg round, from wherever the points are going. What a lever
## beside a two-way turnout does: each pull is the other leg.
func cycle() -> String:
	var from := queued_leg() if queued_leg() >= 0 else set_leg()
	return throw_to((from + 1) % maxi(legs.size(), 1))


## Put the tongue on `index` with nothing reported (the save said so).
func restore(index: int) -> void:
	if actuator == null:
		_initial = clampi(index, 0, maxi(legs.size() - 1, 0))
		return
	actuator.restore_branch(index)
	_refresh()


## `j` when `(line, end)` is leg `j`, -1 when it is the heel or not here.
func leg_of(line_end: Vector2i) -> int:
	return legs.find(line_end)


func is_heel(line_end: Vector2i) -> bool:
	return line_end == heel


## What the sign says: where the points send a carrier, or why nowhere.
func setting_text() -> String:
	var live := live_leg()
	if live >= 0 and queued_leg() < 0:
		return "POINTS %s  >  %s" % [points_id.to_upper(), _label(live)]
	if live >= 0:
		return "POINTS %s  >  %s  (then %s when clear)" % [
				points_id.to_upper(), _label(live), _label(queued_leg())]
	if actuator != null and not actuator.powered:
		return "POINTS %s  NO POWER" % points_id.to_upper()
	return "POINTS %s  MOVING  >  %s" % [points_id.to_upper(),
			_label(set_leg())]


func _label(index: int) -> String:
	return leg_labels[index] if index >= 0 and index < leg_labels.size() \
			else "?"


## One step of the switch, for a suite that steps the railway by hand.
func advance(delta: float) -> void:
	if actuator != null:
		actuator.advance(delta)
	_refresh()


func _physics_process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _sign != null:
		_sign.text = setting_text()
