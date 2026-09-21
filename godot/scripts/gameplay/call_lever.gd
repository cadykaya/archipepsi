class_name CallLever
extends StaticBody3D
## A lever a player can pull as often as they like.
##
## **Why this is not `AlignmentControl`.** That one is deliberately
## one-shot: the span it sends home is monotone, so a second pull cannot
## mean anything and the prompt stops offering rather than accepting a
## command that would do nothing. A call button is the opposite — EX50-011
## turns on being able to send a carrier back and try the rendezvous
## again — so the two stay separate rather than one growing a flag that
## changes what it is.
##
## It decides nothing. It reports that somebody pulled it, and whatever
## owns the machine decides what that means; the schedule rules in
## EX50-011 §8 (one destination, one motion state, no queued arrivals)
## are the machine's to keep, not a button's.

signal pulled(lever: CallLever)

const BASE := Vector3(0.7, 0.35, 0.7)
const ARM := Vector3(0.12, 0.8, 0.12)
const THROW_DEGREES := 55.0
const THROW_SECONDS := 0.35

## What the prompt offers. A call control's label is the destination it
## selects, because EX50-011 §7 warns that a room whose carriers look
## alike and whose endpoints are hidden is a room about reading labels.
var label := "CALL"
var pulls := 0

var _arm: Node3D = null
var _thrown := 0.0


static func make(label_in: String, tint: Color,
		theme := "concrete_facility") -> CallLever:
	var made := CallLever.new()
	made.label = label_in
	made.name = "CallLever_%s" % label_in.to_lower().replace(" ", "_")
	made._build(tint, theme)
	return made


func _build(tint: Color, theme: String) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# The BASE is the collider and what the interact probe finds. The arm
	# moves; a collider that moved with it would change what the player
	# can aim at depending on how recently they used it.
	box.size = BASE
	shape.shape = box
	add_child(shape)
	var plinth := MeshInstance3D.new()
	var plinth_mesh := BoxMesh.new()
	plinth_mesh.size = BASE
	plinth.mesh = plinth_mesh
	plinth.material_override = ThemeMaterials.glow_material(
			ActivityElement.HARDWARE, 0.0)
	add_child(plinth)
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(0.0, BASE.y * 0.5, 0.0)
	add_child(_arm)
	var stick := MeshInstance3D.new()
	var stick_mesh := BoxMesh.new()
	stick_mesh.size = ARM
	stick.mesh = stick_mesh
	stick.position = Vector3(0.0, ARM.y * 0.5, 0.0)
	stick.material_override = ThemeMaterials.glow_material(tint, 1.4)
	_arm.add_child(stick)
	var _unused := theme


func interact_prompt() -> String:
	return "[E] %s" % label


func interact(_who: Node) -> void:
	pulls += 1
	_thrown = 1.0
	pulled.emit(self)


func _process(delta: float) -> void:
	advance(delta)


## The arm falling and springing back. Split out so a suite can step it
## by hand, in the idiom every other machine here uses.
func advance(delta: float) -> void:
	if _arm == null or _thrown <= 0.0:
		return
	_thrown = maxf(_thrown - delta / THROW_SECONDS, 0.0)
	_arm.rotation.x = deg_to_rad(THROW_DEGREES * _thrown)


## How far through its swing the arm is, 1 at the instant of the pull.
func swing() -> float:
	return _thrown
