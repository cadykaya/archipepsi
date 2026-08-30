class_name ActivityElement
extends Area3D
## One thing an activity is made of: a switch, a target, a plate, a marker.
##
## ONE class for all of them, with a trigger mode, rather than four. The
## activity vocabulary is four composable FAMILIES precisely so that the
## engine does not grow four bespoke minigames, and an element class per
## family would have been the first of them.
##
## The three trigger modes are the three ways a player can say "this one":
##
##   `touch`  walk into it. Latching -- a pressed switch stays pressed.
##   `shot`   hit it with anything. See `take_damage` for why ANYTHING.
##   `stand`  stand on it. Momentary -- it releases after a hold window.
##
## What it never does is decide anything. An element reports that it was
## triggered and `ActivityRuntime` decides what that means, because the
## rules that make a puzzle (order, clock, simultaneity) are properties of
## the puzzle and not of a switch.

const TOUCH := "touch"
const SHOT := "shot"
const STAND := "stand"
const TRIGGERS := [TOUCH, SHOT, STAND]

## Element roles. `timed_run` is the only family that needs them: its
## start and goal are the same object with different jobs.
const ROLE_ELEMENT := "element"
const ROLE_START := "start"
const ROLE_GOAL := "goal"

const SWITCH_SIZE := Vector3(0.6, 1.2, 0.3)
const TARGET_SIZE := Vector3(0.9, 0.9, 0.2)
const PLATE_SIZE := Vector3(1.4, 0.15, 1.4)

signal triggered(element: ActivityElement)
signal released(element: ActivityElement)

var trigger := TOUCH
var role := ROLE_ELEMENT
var index := 0
## Latched for `touch` and `shot`; true only while occupied (plus the
## hold window) for `stand`.
var is_set := false

var _mesh: MeshInstance3D
var _tint := Color(0.55, 0.85, 1.0)
var _hold_left := 0.0
var _occupied := 0

static func create(trigger_in: String, index_in: int, size: Vector3,
		tint: Color, role_in := ROLE_ELEMENT) -> ActivityElement:
	var element := ActivityElement.new()
	element.trigger = trigger_in if trigger_in in TRIGGERS else TOUCH
	element.role = role_in
	element.index = index_in
	element._tint = tint
	element._build(size)
	return element

func _build(size: Vector3) -> void:
	name = "ActivityElement_%d" % index
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	_mesh.material_override = ThemeMaterials.glow_material(_tint, 1.0)
	add_child(_mesh)

	if trigger == SHOT:
		# A shot element is AIMED AT, and `Player.camera_ray` is an
		# ordinary ray query -- which does not collide with areas. An
		# Area3D target would have been invisible to every weapon in the
		# game while looking perfectly correct in the scene tree, which
		# is precisely the failure `BreakablePanel` shipped with once.
		# So the sensing organ here is a BODY, and it forwards.
		monitoring = false
		var body := TargetBody.new()
		body.element = self
		body.name = "TargetBody"
		var body_shape := CollisionShape3D.new()
		var body_box := BoxShape3D.new()
		# Exactly the silhouette: a target that eats shots which visibly
		# missed is worse than one that is slightly small.
		body_box.size = size
		body_shape.shape = body_box
		body.add_child(body_shape)
		body.add_to_group(Damageable.GROUP)
		add_child(body)
		return

	# Touch and stand are ENTERED rather than aimed at, so the sensing
	# volume is wider than the silhouette: a switch is pressed by walking
	# into it, not by pixel-hunting.
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size + Vector3.ONE * Constants.ACTIVITY_TOUCH_RADIUS
	shape.shape = collider
	add_child(shape)
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## The collider a weapon actually hits, for a `shot` element.
##
## Split out rather than folded into `ActivityElement` because the two
## cannot be the same node: entering needs an `Area3D` and being shot
## needs a `PhysicsBody3D`, and a ray query reaches only the second.
class TargetBody extends StaticBody3D:
	var element: ActivityElement

	## `Enemy`'s signature, so every damage call site in the game reaches
	## it without knowing what it hit.
	func take_damage(amount: float, direction: Vector3 = Vector3.ZERO,
			knockback: float = 0.0) -> bool:
		if element == null or not is_instance_valid(element):
			return false
		return element.take_damage(amount, direction, knockback)

## Any hit counts, whatever it dealt.
##
## Deliberately NOT a damage threshold. `BreakablePanel` has one and is
## right to: its affordance contract is stated in impact. An activity is
## progression-shaped content, and the owner ruling of 2026-08-30 is that
## raw damage is BALANCE and never LOGIC — so a target that needed 50
## damage would be a Zone quietly saying "only if your build hits hard
## enough", which is the one thing a requirement may never mean.
##
## `Enemy`'s signature, so every existing damage call site reaches it
## without knowing what it hit: Static Pulse, an Echo hitscan, a
## projectile, a melee swing.
func take_damage(_amount: float, _direction: Vector3 = Vector3.ZERO,
		_knockback: float = 0.0) -> bool:
	if trigger != SHOT or is_set:
		return false
	_apply_set(true)
	return true

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_occupied += 1
	if trigger == TOUCH and is_set:
		return
	_apply_set(true)

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_occupied = maxi(0, _occupied - 1)
	# A latching element does not care that you left.
	if trigger != STAND or _occupied > 0:
		return
	_hold_left = Constants.PLATE_HOLD_SECONDS

func _process(delta: float) -> void:
	if trigger != STAND or not is_set or _occupied > 0:
		return
	if _hold_left <= 0.0:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		_apply_set(false)

func _apply_set(value: bool) -> void:
	if is_set == value:
		return
	is_set = value
	if _mesh != null:
		_mesh.material_override = ThemeMaterials.glow_material(
				_tint, 3.2 if value else 1.0)
	if value:
		triggered.emit(self)
	else:
		released.emit(self)

## Back to untouched. The runtime resets its elements together, so this
## never decides on its own that an attempt is over.
func reset() -> void:
	_hold_left = 0.0
	_occupied = 0
	_apply_set(false)
