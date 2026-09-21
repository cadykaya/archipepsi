class_name ServiceShutter
extends AnimatableBody3D
## A shutter that opens for a while and closes itself, and will not close
## on somebody.
##
## **The timer is the machine's, not the player's.** EX50-021 §3: the
## interval "refreshes on another valid receiver hit", and §9: the timer
## is ephemeral while what lies beyond it is not. So this owns exactly
## two things — how far the panel has slid, and how long is left — and
## the room owns what opened it and what it leads to.
##
## **The interlock is physical.** §8: "A player already in the doorway is
## not crushed." The doorway holds a real sensing volume and a closing
## shutter that finds a body in it stops and waits rather than continuing
## and relying on the body being pushed somewhere survivable. The panel
## also carries `sync_to_physics`, so a body standing ON it while it
## moves is carried rather than left — the same property the lift and the
## skiff depend on.
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
## §2's "proposed eight-second interval".
var open_seconds := 8.0

var offset := 0.0
var speed := 0.0
var goal := 0.0
var left := 0.0

var _theme := "concrete_facility"
var _doorway: Area3D = null
var _inside := 0
var _overrun := 0.0


static func create(shut_centre: Vector3, panel_size: Vector3,
		rise: float, seconds := 8.0,
		theme := "concrete_facility") -> ServiceShutter:
	var made := ServiceShutter.new()
	made.name = "ServiceShutter"
	made.shut_at = shut_centre
	made.panel = panel_size
	made.travel = rise
	made.open_seconds = seconds
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
	mesh_node.material_override = ThemeMaterials.accent_mat(_theme)
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
	_doorway.global_position = shut_at


## Open it, or refresh the interval if it is already open. §3: the timer
## "refreshes on another valid receiver hit".
func trip() -> void:
	left = open_seconds
	goal = travel


## DRIVEN BY A LIVE SIGNAL rather than by an interval.
##
## `trip` is the timed door EX50-021 needs: opened by an impact, closing
## itself after a declared window. EX50-033's is the other kind -- a
## safety lockout wired through a NOT to a plate, open exactly while the
## plate is clear, with no window of its own. Both are this panel; what
## differs is who decides when it shuts, so the interval is cleared here
## rather than fought with.
func command(open: bool) -> void:
	left = 0.0
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
	return _overrun


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if left > 0.0:
		left = maxf(left - delta, 0.0)
		if left <= 0.0:
			goal = 0.0
	# THE INTERLOCK. A closing shutter that finds somebody in the doorway
	# does not close, and does not silently forget that it wanted to: it
	# waits, says how long it has been waiting, and shuts the moment the
	# doorway is clear.
	if goal <= 0.0 and _inside > 0:
		_overrun += delta
		held_open.emit(_overrun)
		speed = 0.0
		return
	if goal > 0.0:
		_overrun = 0.0
	var was_open := is_open()
	var was_shut := is_shut()
	var moved := StopTravel.step(offset, goal, speed, delta,
			ACCEL, SPEED, EPSILON)
	offset = moved.x
	speed = moved.y
	_place()
	if is_open() and not was_open:
		opened.emit()
	elif is_shut() and not was_shut:
		closed.emit()


func _place() -> void:
	global_position = shut_at + Vector3(0.0, offset, 0.0)


func _on_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_inside += 1


func _on_left(body: Node3D) -> void:
	if body.is_in_group("player"):
		_inside = maxi(0, _inside - 1)
