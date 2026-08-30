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
##
## PRESENTATION, added 2026-08-30. Provisional graybox, not final art.
## Every element used to be one box, so `switch_sequence` and `timed_run`
## were pixel-identical and a `timed_run`'s START, GOAL and waypoints were
## the same object three times. The grammar here is the art lane's:
##
##   SILHOUETTE tells you which family this is
##   INTERACTION HARDWARE tells you it is operable at all
##   STATE TREATMENT tells you what it is doing now
##
## and colour is never the only cue for any of the three. The hardware --
## the dark mount every element stands on -- is what separates an activity
## from a theme prop, because props are saturated accent boxes sitting
## directly on the floor with no hardware at all.
##
## The added structure is VISUAL ONLY: no new colliders. The sensing
## volume and the shot body are exactly what they were, so nothing here
## can change what the player can walk through, stand on or hit.

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

## Interaction hardware: dark, matte, unlit. Deliberately the opposite of
## a theme prop, which is a saturated emissive accent box. A player
## scanning a room should be able to find the operable things by looking
## for the dark mounts, without knowing any colour code.
const HARDWARE := Color(0.13, 0.14, 0.17)

## How much brighter a set element reads than an idle one. State is a
## VALUE step, not a hue change: a colourblind player and a player under
## bloom both get the same information.
const SET_ENERGY := 3.2
const IDLE_ENERGY := 0.9

signal triggered(element: ActivityElement)
signal released(element: ActivityElement)

var trigger := TOUCH
var role := ROLE_ELEMENT
var index := 0
## 1-based order position, or 0 when the activity is unordered.
var ordinal := 0
## Latched for `touch` and `shot`; true only while occupied (plus the
## hold window) for `stand`.
var is_set := false

var _mesh: MeshInstance3D
var _tint := Color(0.55, 0.85, 1.0)
var _hold_left := 0.0
var _occupied := 0

## `ordinal` is the 1-based position this element occupies in an ORDERED
## activity, or 0 when order does not matter. It becomes countable lugs,
## and only then: an unordered row that grew a counter would be telling
## the player about a rule the puzzle does not have.
static func create(trigger_in: String, index_in: int, size: Vector3,
		tint: Color, role_in := ROLE_ELEMENT,
		ordinal := 0) -> ActivityElement:
	var element := ActivityElement.new()
	element.trigger = trigger_in if trigger_in in TRIGGERS else TOUCH
	element.role = role_in
	element.index = index_in
	element.ordinal = ordinal
	element._tint = tint
	element._build(size)
	return element

func _build(size: Vector3) -> void:
	name = "ActivityElement_%d" % index
	# The signal face: the part that changes with state. Kept as `_mesh`
	# so `_apply_set` still has exactly one thing to brighten.
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	_mesh.material_override = ThemeMaterials.glow_material(
			_tint, IDLE_ENERGY)
	add_child(_mesh)

	match trigger:
		SHOT:
			_build_target(size)
		STAND:
			_build_plate(size)
		_:
			if role == ROLE_START:
				_build_start_gate(size)
			elif role == ROLE_GOAL:
				_build_goal_pillar(size)
			else:
				_build_switch(size)

	_build_sensor(size)

## A ring around a face. Reads "aim at the middle" without a single
## breakage cue: no cracks, no debris, no hazard colour. A target that
## looked breakable would promise it disappears when hit, and it does not
## -- it stays, lit, as the record that you got it.
func _build_target(size: Vector3) -> void:
	var bar := 0.14
	var reach := size.x / 2.0 + bar / 2.0
	for offset: Vector3 in [
			Vector3(0.0, reach, 0.0), Vector3(0.0, -reach, 0.0),
			Vector3(reach, 0.0, 0.0), Vector3(-reach, 0.0, 0.0)]:
		var horizontal := absf(offset.y) > 0.0
		_hardware(Vector3(
				size.x + bar * 2.0 if horizontal else bar,
				bar if horizontal else size.y,
				size.z + 0.06), offset)
	# The stalk that holds it off the wall, so it reads as MOUNTED
	# equipment rather than as a decal painted on the plaster.
	_hardware(Vector3(0.12, 0.12, 0.5), Vector3(0.0, 0.0, -0.3))

## A plate in a recessed kerb. The kerb is what makes a pad read as a
## fitting rather than as one more floor tile -- the failure the audit
## found, where pads at 0.08 m were indistinguishable from the tiling
## they sat on.
func _build_plate(size: Vector3) -> void:
	var lip := 0.18
	for offset: Vector3 in [
			Vector3(0.0, 0.0, size.z / 2.0 + lip / 2.0),
			Vector3(0.0, 0.0, -size.z / 2.0 - lip / 2.0),
			Vector3(size.x / 2.0 + lip / 2.0, 0.0, 0.0),
			Vector3(-size.x / 2.0 - lip / 2.0, 0.0, 0.0)]:
		var along_x := absf(offset.z) > 0.0
		_hardware(Vector3(
				size.x + lip * 2.0 if along_x else lip,
				size.y * 1.6,
				lip if along_x else size.z), offset)

## A head on a post, with countable lugs when the order matters.
##
## The lugs are the ordinal cue and they are STRUCTURAL: you can count
## them, in silhouette, in the dark, before you have failed once. A hue
## ramp was the obvious alternative and is refused -- it needs a legend,
## it dies under bloom, and it is invisible to a colourblind player.
func _build_switch(size: Vector3) -> void:
	_hardware(Vector3(0.16, 1.0, 0.16), Vector3(0.0, -size.y / 2.0 - 0.5, 0.0))
	_hardware(Vector3(size.x + 0.16, 0.1, size.z + 0.16),
			Vector3(0.0, -size.y / 2.0 - 0.05, 0.0))
	if ordinal <= 0:
		return
	for lug in mini(ordinal, 8):
		_hardware(Vector3(0.1, 0.1, 0.1), Vector3(
				size.x / 2.0 + 0.09, size.y / 2.0 - 0.16 - 0.17 * lug, 0.0),
				_tint)

## A gate you run THROUGH. Two uprights and a lintel: the widest, most
## open silhouette in the vocabulary, and the only one with a hole in it.
func _build_start_gate(size: Vector3) -> void:
	var span := 1.5
	var post := 2.1
	for side: float in [-1.0, 1.0]:
		_hardware(Vector3(0.18, post, 0.18),
				Vector3(side * span, post / 2.0 - size.y / 2.0, 0.0))
	_hardware(Vector3(span * 2.0 + 0.18, 0.2, 0.18),
			Vector3(0.0, post - size.y / 2.0, 0.0))

## A pillar you arrive AT. Tall, capped, and closed where the gate is
## open -- the two are opposites in outline, which is the point.
##
## The CAP carries the signal, not the column. A first pass made the
## whole 2.4 m pillar out of mounting hardware and it read as a black
## void punched in a pale wall rather than as a destination: hardware
## value that works at the scale of a bracket does not work at the scale
## of a monument. So the column is a slim dark stem and the light sits on
## top, where a beacon's light belongs.
func _build_goal_pillar(size: Vector3) -> void:
	var column := 2.6
	_hardware(Vector3(0.26, column, 0.26),
			Vector3(0.0, column / 2.0 - size.y / 2.0, 0.0))
	_hardware(Vector3(0.7, 0.14, 0.7), Vector3(0.0, -size.y / 2.0, 0.0))
	# A wide lit head on a slim stem. The width is what keeps the goal's
	# outline clear of a waypoint's -- the suite caught a first pass where
	# slimming the column to stop it reading as a void brought the two
	# silhouettes back within a hand's breadth of each other.
	_hardware(Vector3(1.0, 0.42, 1.0),
			Vector3(0.0, column - size.y / 2.0, 0.0), _tint)

## One piece of dark, unlit mounting hardware. Visual only.
func _hardware(size: Vector3, offset: Vector3,
		color := HARDWARE) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	piece.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color != HARDWARE:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
	else:
		material.roughness = 1.0
	piece.material_override = material
	piece.position = offset
	add_child(piece)
	return piece

## The collider, unchanged by any of the above.
func _build_sensor(size: Vector3) -> void:
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
				_tint, SET_ENERGY if value else IDLE_ENERGY)
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
