class_name ServiceShutter
extends AnimatableBody3D
## A shutter that opens and shuts on command, and will not close on
## somebody.
##
## **The window is the graph's, not the shutter's (O05-07).** EX50-021
## §3 names the parts: "the eight-second TIMER refreshes on another valid
## receiver hit. Its output opens the service shutter." So the interval
## is a TIMER node in the room's signal graph and this is its actuator,
## commanded like every other. It used to keep a clock of its own, and
## the arcade tripped it directly; a second timer here would be a second
## answer to how long the way stays open. What this owns is how far the
## panel has slid, and the interlock.
##
## **The interlock is physical, and it is §21.2's.** EX50-021 §8 asks
## that "a player already in the doorway is not crushed"; Amalgam §21.2
## says what a door does about it, and this panel used to do only half of
## it. It stopped where it was and waited. §21.2 requires it to **stop,
## reverse to fully open, and retry after 1.0 s, repeating** — because a
## panel parked halfway is still narrowing the doorway it was asked to
## clear, and gives the person standing under it no sign that stepping
## aside is what it is waiting for. The rule now lives in `SafeClosure`,
## shared with `Actuator`, so there is one answer rather than one per
## machine.
##
## The doorway holds a real sensing volume and it watches for §21.2's
## whole protected set: the player, and any object a Zone declared
## `required` (`Constants.REQUIRED_OBJECT_GROUP`). The panel also carries
## `sync_to_physics`, so a body standing ON it while it moves is carried
## rather than left — the same property the lift and the skiff depend
## on.
##
## It shares `StopTravel` with them too: how a machine gets from one stop
## to the next is one question.

signal opened()
signal closed()
## Refused to close because somebody was standing in the doorway.
signal held_open(seconds_over: float)

const SPEED := 2.2
const ACCEL := 4.0
const EPSILON := 0.02

## How far the panel rises to clear the opening.
var travel := 2.6
## Where the panel's centre sits when shut.
var shut_at := Vector3.ZERO
var panel := Vector3(2.4, 2.6, 0.3)

var offset := 0.0
var speed := 0.0
var goal := 0.0

var _theme := "concrete_facility"
## What the panel is made of, when it is not the theme's accent panel --
## a glass gate is still a shutter (H-PASSING).
var panel_material: Material = null
var _doorway: Area3D = null
var _inside := 0
var _interlock := SafeClosure.new()


static func create(shut_centre: Vector3, panel_size: Vector3,
		rise: float, theme := "concrete_facility") -> ServiceShutter:
	var made := ServiceShutter.new()
	made.name = "ServiceShutter"
	made.shut_at = shut_centre
	made.panel = panel_size
	made.travel = rise
	made._theme = theme
	return made


func _ready() -> void:
	sync_to_physics = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = panel
	shape.shape = box
	add_child(shape)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Panel"
	var mesh := BoxMesh.new()
	mesh.size = panel
	mesh_node.mesh = mesh
	mesh_node.material_override = panel_material if panel_material != null \
			else ThemeMaterials.accent_mat(_theme)
	add_child(mesh_node)
	# THE DOORWAY, as a volume rather than as a distance check. A body is
	# in the way when it is in the way.
	_doorway = Area3D.new()
	_doorway.name = "Doorway"
	var sense := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(panel.x, panel.y, panel.z + 1.4)
	sense.shape = volume
	_doorway.add_child(sense)
	_doorway.body_entered.connect(_on_entered)
	_doorway.body_exited.connect(_on_left)
	# A SIBLING, NOT A CHILD, and placed once it is in the tree. The
	# doorway is a fixed volume; a doorway that rode up with the panel
	# would report the opening clear exactly when the panel was above
	# somebody's head.
	_adopt.call_deferred()
	_place()


func _adopt() -> void:
	if _doorway == null or _doorway.is_inside_tree():
		return
	add_sibling(_doorway)
	_doorway.position = shut_at
	# **TURNED WITH THE PANEL.** The volume is `panel.x` wide and
	# `panel.z + 1.4` deep, so it only covers the opening when it faces
	# the way the panel does. Every shutter used to be built unrotated,
	# which hid this; one placed across a doorway takes the doorway's
	# yaw, and an interlock lying crosswise to its own panel would watch
	# the wall beside the door instead of the door.
	_doorway.rotation.y = rotation.y


## START in a commanded state, rather than travel to it.
##
## A route the campaign's record says is open must BE open when the Zone
## loads -- not slide open in front of the player, as though they had
## just done something. The first evaluation of a room graph settles its
## machines; every later one commands them. `unweighted_switch` has done
## the same by hand since EX50-033 ("ALREADY OPEN, not opening").
func settle(open: bool) -> void:
	command(open)
	offset = goal
	speed = 0.0
	if is_inside_tree():
		_place()


## DRIVEN BY A LIVE SIGNAL. EX50-021's window is a TIMER feeding it;
## EX50-033's safety lockout is a NOT on a plate. Both are this panel,
## commanded by what the graph says.
func command(open: bool) -> void:
	goal = travel if open else 0.0


## How far open, 0 shut and 1 clear.
func openness() -> float:
	return offset / travel if travel > 0.0 else 0.0


func is_open() -> bool:
	return offset >= travel - EPSILON


func is_shut() -> bool:
	return offset <= EPSILON


## Is there a body standing in the opening right now?
func doorway_occupied() -> bool:
	return _inside > 0


## Seconds the interval has run past its expiry because the doorway was
## occupied. Zero whenever nothing has been in the way.
func overrun() -> float:
	return _interlock.overrun


## How many closures §21.2 has refused. A door interrupted once and a
## door being denied over and over read the same from `overrun` alone.
func refusals() -> int:
	return _interlock.refusals


## True while the panel is travelling back up after a refused closure, or
## sitting fully open waiting out the 1.0 s retry.
func reversing() -> bool:
	return _interlock.reversing


## Seconds until it tries to shut again. Zero when it is not holding
## open for anybody.
func retry_left() -> float:
	return _interlock.retry_left


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	# THE INTERLOCK — §21.2, through the shared rule. A closing shutter
	# that finds somebody in the doorway stops, goes back to FULLY OPEN,
	# and tries again a second later, for as long as the doorway is
	# occupied. It says how long it has been waiting each time, and it
	# never forgets that it wanted to shut.
	var commanded := goal
	# A DOOR THAT IS ALREADY SHUT IS NOT WANTING TO SHUT. Reading the
	# goal alone leaves `overrun` frozen at whatever the last refusal
	# reached, for the rest of the Zone's life, because `goal` stays at 0
	# after a successful closure.
	var order := _interlock.order(delta, goal <= 0.0 and not is_shut(),
			_inside > 0, is_open())
	if order != SafeClosure.Order.PROCEED:
		held_open.emit(_interlock.overrun)
		commanded = travel
	if order == SafeClosure.Order.HOLD_OPEN:
		# Fully open and counting down. Holding still is the wait rather
		# than a stall, so the speed is shed instead of being carried
		# into the retry.
		speed = 0.0
	var was_open := is_open()
	var was_shut := is_shut()
	var moved := StopTravel.step(offset, commanded, speed, delta,
			ACCEL, SPEED, EPSILON)
	offset = moved.x
	speed = moved.y
	_place()
	if is_open() and not was_open:
		opened.emit()
	elif is_shut() and not was_shut:
		closed.emit()


## IN THE PARENT'S FRAME, like the doorway volume beside it (P5-15).
## This set `global_position`, so `shut_at` was a WORLD point: right for
## every owner standing at the world origin -- the Zone's gates and
## signal graphs -- and wrong for a room that carries its own shutter
## and is placed somewhere else. EX50-033 hosted in a Zone put its panel
## and its interlock near the world origin, nowhere near its crossing,
## while its state read shut.
func _place() -> void:
	position = shut_at + Vector3(0.0, offset, 0.0)


## §21.2's protected set is "the player or any `required = true`
## object", so the count is of both. A crate a puzzle cannot be finished
## without is not something a door may push through a wall either.
func _watched(body: Node3D) -> bool:
	return body.is_in_group("player") \
			or body.is_in_group(Constants.REQUIRED_OBJECT_GROUP)


func _on_entered(body: Node3D) -> void:
	if _watched(body):
		_inside += 1


func _on_left(body: Node3D) -> void:
	if _watched(body):
		_inside = maxi(0, _inside - 1)
