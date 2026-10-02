class_name AlignmentControl
extends StaticBody3D
## The lever a player pulls to send a span home.
##
## **A `StaticBody3D` with `interact`, because that is the verb this
## game already has.** `Player._update_interact_target` ray-probes 3 m
## ahead for a collider carrying an `interact` method and offers its
## `interact_prompt()`; a bespoke "use" here would have been a second
## interaction system, and the first thing a second one gets wrong is
## the prompt.
##
## **THE PLAYER PERFORMS IT, and §19.7 is why that matters.** A latch is
## room-layer and never reaches across rooms on its own. Nothing here
## fires because a timer expired, because a carrier arrived somewhere
## else, or because a Check was claimed in another room: a person stands
## at this lever and pulls it.
##
## **Once, and then it says so.** The span it sends is monotone, so a
## second pull cannot mean anything; the prompt stops offering rather
## than accepting a command that would do nothing.

signal operated(control: AlignmentControl)

const BASE := Vector3(0.7, 0.35, 0.7)
const LEVER := Vector3(0.12, 0.85, 0.12)
## How far the lever falls when it is thrown, in degrees.
const THROW_DEGREES := 62.0
const THROW_SECONDS := 0.4

var label := "ALIGN THE SPAN"
var done := false
## WHERE IT IS WORKED FROM, when that is part of the gate: the body a
## player must be standing on to pull it. Null -- every ground lever --
## means from wherever the interact probe reaches it.
##
## **A gantry's lever has one (D-9).** The measured deck's top is 2.9 m
## up and a standing jump puts the eye at 3.00 m: from beside the deck,
## at the top of a jump, the 3 m interact probe grazes over the lip to a
## lever two metres in, and a timed press pulled it without the grapple
## the AP logic says it needs. From a passing carrier's deck the eye
## clears the lip outright. Raising the deck would need the pull
## re-measured; and this is what a floor lever means anyway -- you stand
## at it to pull it.
var worked_from: StaticBody3D = null
## What the prompt says to a player who can see the lever and is not on
## the body it is worked from: why, rather than an offer that does
## nothing.
const WORKED_FROM_PROMPT := "REACHED FROM THE GANTRY"

var _lever: Node3D = null
var _thrown := 0.0


static func create(label_in := "ALIGN THE SPAN",
		theme := "concrete_facility") -> AlignmentControl:
	var made := AlignmentControl.new()
	made.label = label_in
	made.name = "AlignmentControl"
	made._build(theme)
	return made


func _build(theme: String) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# The BASE is the collider, and it is what the interact probe finds.
	# The lever moves; a collider that moved with it would change what
	# the player can aim at depending on whether they had already used
	# it, which is the sort of thing that reads as a bug.
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
	_lever = Node3D.new()
	_lever.name = "Lever"
	_lever.position = Vector3(0.0, BASE.y * 0.5, 0.0)
	add_child(_lever)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = LEVER
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, LEVER.y * 0.5, 0.0)
	arm.material_override = ThemeMaterials.trim_mat(theme)
	_lever.add_child(arm)


## The prompt the player reads. Empty once it has been thrown, because
## an offer that does nothing is worse than no offer.
func interact_prompt() -> String:
	if done:
		return ""
	if worked_from != null and is_inside_tree():
		var on_it := false
		for who: Node in get_tree().get_nodes_in_group("player"):
			on_it = on_it or stands_on_it(who)
		if not on_it:
			return WORKED_FROM_PROMPT
	return "[E] %s" % label


func interact(player: Node) -> void:
	if done or not stands_on_it(player):
		return
	done = true
	_thrown = 1.0
	operated.emit(self)


func _process(delta: float) -> void:
	advance(delta)


## The lever falling. Split out for the same reason everything else in
## this railway is: a suite should not have to wait on wall-clock frames
## to know that a machine moved.
func advance(delta: float) -> void:
	if _lever == null or _thrown <= 0.0:
		return
	_thrown = maxf(_thrown - delta / THROW_SECONDS, 0.0)
	_lever.rotation.x = deg_to_rad(THROW_DEGREES * (1.0 - _thrown))


## Whether `who` stands on `worked_from`: on the floor, feet over its
## top face. True of anyone for a lever worked from anywhere.
func stands_on_it(who: Node) -> bool:
	if worked_from == null:
		return true
	if not (who is CharacterBody3D) \
			or not (who as CharacterBody3D).is_on_floor():
		return false
	var half := Vector3.ZERO
	for child: Node in worked_from.get_children():
		if child is CollisionShape3D \
				and (child as CollisionShape3D).shape is BoxShape3D:
			half = ((child as CollisionShape3D).shape as BoxShape3D).size \
					* 0.5
			break
	var feet := worked_from.global_transform.affine_inverse() \
			* (who as Node3D).global_position
	return absf(feet.x) <= half.x + 0.3 and absf(feet.z) <= half.z + 0.3 \
			and feet.y >= half.y - 0.1 and feet.y <= half.y + 0.5


## How far the lever has fallen, 0 at rest and 1 fully thrown.
func thrown() -> float:
	return 0.0 if not done else 1.0 - _thrown
