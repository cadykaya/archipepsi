class_name RailReceiver
extends Node3D
## A shootable control that tells the railway which way to go.
##
## **A wrapper, not a second shot sensor.** `ActivityElement` with
## `trigger = SHOT` is already the generic "hit this with anything" organ:
## it builds the `TargetBody` a ray query can actually reach, puts it in
## `Damageable.GROUP` so every existing weapon path finds it, refuses to
## decide what a hit MEANS, and carries the art lane's silhouette /
## hardware / state grammar. A bespoke sensor here would have been a
## second one of those, and the first thing it would have got wrong is
## the thing `BreakablePanel` already shipped wrong once -- an `Area3D`
## target that no weapon in the game can hit, while looking perfectly
## correct in the scene tree.
##
## **What this adds is that a command is MOMENTARY.** An activity element
## LATCHES: a hit switch stays hit until its runtime resets it, which is
## right for a puzzle and would make a direction control a one-shot
## lever. So the receiver re-arms itself, and the window it re-arms over
## is also the debounce -- a shotgun's pellets arrive as several
## `take_damage` calls in one frame and mean ONE command.
##
## **Direction is read from the receiver's own facing, never a colour.**
## Local +Z is the direction of increasing offset along the rail: the
## builder aims the receiver, the arrow points along that axis or against
## it, and the arrow LUNGES the way it sends the carrier when it is hit.
## Shape and motion, so a player who cannot separate the two tints still
## reads the pair.

signal commanded(direction: int)

## One blast is one command. Long enough to swallow a shotgun's pellets
## and a burst weapon's frames; short enough that a player who meant to
## send the carrier twice can.
const REARM_SECONDS := 0.35
## How far the arrow lunges, and how long it takes to ease back.
const KICK := 0.18
const KICK_SECONDS := 0.28
const ARROW := Vector3(0.44, 0.44, 0.5)

## `RailCarrier.FORWARD` or `RailCarrier.BACK`.
var direction := RailCarrier.FORWARD
## The organ that is actually shot.
var element: ActivityElement = null
## The wedge. Public so a suite can measure that it moved, because
## "motion is a legibility cue" is a claim a test should be able to check.
var arrow: MeshInstance3D = null

var _rearm := 0.0
var _kick := 0.0
var _arrow_home := Vector3.ZERO


static func create(direction_in: int, index := 0,
		tint := Color(0.55, 0.85, 1.0)) -> RailReceiver:
	var made := RailReceiver.new()
	made.direction = RailCarrier.FORWARD if direction_in >= 0 \
		else RailCarrier.BACK
	made.name = "RailReceiver_%s" % ("forward" if made.direction \
		== RailCarrier.FORWARD else "back")
	made.element = ActivityElement.create(ActivityElement.SHOT, index,
		ActivityElement.TARGET_SIZE, tint)
	made.add_child(made.element)
	made.element.triggered.connect(made._on_hit)
	made._build_arrow(tint)
	return made


## The wedge that says which way, in front of the target face so a player
## reading the control from any angle sees the shape rather than the tint.
func _build_arrow(tint: Color) -> void:
	arrow = MeshInstance3D.new()
	arrow.name = "Arrow"
	var wedge := PrismMesh.new()
	wedge.size = ARROW
	arrow.mesh = wedge
	arrow.material_override = ThemeMaterials.glow_material(tint, 2.0)
	# A prism's apex points +Y. A quarter turn about X aims it down the
	# local Z axis -- +Z for FORWARD, -Z for BACK -- which is the axis
	# the builder aligns with increasing offset along the rail.
	arrow.rotation.x = PI / 2.0 if direction == RailCarrier.FORWARD \
		else -PI / 2.0
	_arrow_home = Vector3(0.0, 0.0,
		(ActivityElement.TARGET_SIZE.z * 0.5 + ARROW.z * 0.5) \
			* float(direction))
	arrow.position = _arrow_home
	add_child(arrow)


func _process(delta: float) -> void:
	advance(delta)


## One step of re-arming and recoil.
##
## SPLIT OUT so a suite can step the control by hand: a debounce measured
## against wall-clock frames is a test that passes on a fast machine.
func advance(delta: float) -> void:
	if _kick > 0.0:
		_kick = maxf(_kick - delta / KICK_SECONDS, 0.0)
		if arrow != null:
			arrow.position = _arrow_home + Vector3(0.0, 0.0,
				KICK * _kick * float(direction))
	if _rearm <= 0.0:
		return
	_rearm = maxf(_rearm - delta, 0.0)
	if _rearm <= 0.0 and element != null:
		# Re-armed: dim again, and shootable again.
		element.reset()


## How far through its recoil the arrow is, 1 at the instant of the hit.
func kick() -> float:
	return _kick


## Is this control accepting a command right now?
func armed() -> bool:
	return _rearm <= 0.0


func _on_hit(_which: ActivityElement) -> void:
	# BELT AND BRACES. `ActivityElement.take_damage` already refuses a
	# hit while `is_set`, so the pellets after the first never reach
	# here. This also covers a caller that resets the element early.
	if _rearm > 0.0:
		return
	_rearm = REARM_SECONDS
	_kick = 1.0
	commanded.emit(direction)
