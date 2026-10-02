class_name ImpactReceiver
extends Node3D
## An emergency impact trip that does not care who shot it.
##
## **A wrapper, for the reason `RailReceiver` is one.** `ActivityElement`
## with `trigger = SHOT` is already the generic "hit this with anything"
## organ: it builds the `TargetBody` a ray query and an `Area3D` can both
## reach, puts it in `Damageable.GROUP` so every existing damage path
## finds it, and refuses to decide what a hit MEANS. A second shot sensor
## here would be a second one of those.
##
## **What this adds is that a HOSTILE shot counts, and that the reason it
## counts is physical.** EX50-021 §3: "This is physical directionality,
## not an owner-ID exception." So the plate faces the lane, a real hood
## shells its reverse angle, and a shot from the arrival side stops on
## the hood — not because the receiver checked who fired it, but because
## there is steel in the way. Walk round to the far side and your own
## shot operates the same plate, with the same result (§9: "A player
## projectile and hostile projectile operating the same surface lead to
## the same machine state").
##
## **And the acceptance is declared, not assumed.** The target body joins
## `Damageable.HOSTILE_INPUT`, which nothing else in the game is in. An
## enemy's shot can operate this and cannot operate a breakable panel,
## a rail receiver, or an enemy's own cover.
##
## **Repeatable, because the timer it drives refreshes** (§3). Like
## `RailReceiver` it re-arms, and the re-arm window is also the debounce:
## several impacts inside it are one pulse.

## Somebody's shot landed on the active face. `from` is where it came
## from, for diagnostics; §9 is explicit that the last hit source "is not
## the progression authority".
signal struck(from: Vector3)

const PLATE := Vector3(1.3, 1.3, 0.22)
const REARM_SECONDS := 0.4
## The hood: a shell round everything but the active face.
const HOOD_THICK := 0.22
const HOOD_DEPTH := 0.7

## The organ that is actually hit.
var element: ActivityElement = null
## How many pulses this has emitted. A test counts them; so does the
## no-double-counting rule.
var hits := 0
var hood: Node3D = null

var _rearm := 0.0
var _theme := "concrete_facility"


## `face_yaw` turns the whole fitting. Local -Z is the ACTIVE FACE, so a
## receiver built with `face_yaw = 0` is addressable from -Z and hooded
## from +Z.
static func create(face_yaw := 0.0, tint := Color(1.0, 0.55, 0.3),
		theme := "concrete_facility") -> ImpactReceiver:
	var made := ImpactReceiver.new()
	made.name = "ImpactReceiver"
	made._theme = theme
	made.element = ActivityElement.create(ActivityElement.SHOT, 0,
			PLATE, tint)
	made.add_child(made.element)
	made.element.triggered.connect(made._on_hit)
	made._build_hood()
	made.rotation.y = face_yaw
	return made


func _ready() -> void:
	# DECLARED, not assumed. Done here rather than in `create` because
	# `ActivityElement` builds its `TargetBody` in its own `_ready`, and
	# `create` runs before either node is in the tree.
	var body := element.get_node_or_null("TargetBody")
	if body != null:
		(body as Node).add_to_group(Damageable.HOSTILE_INPUT)
	else:
		push_warning("impact receiver has no target body to declare")


## The shell. Sides, back and top, and nothing across the front.
##
## THE SHOT IS STOPPED BY STEEL rather than by a rule, so the hood is
## real collision geometry and a suite can fire a real projectile at it
## from the wrong side and watch the projectile stop. A hood that were a
## filter on the receiver would pass that test by not being tested.
func _build_hood() -> void:
	hood = Node3D.new()
	hood.name = "Hood"
	add_child(hood)
	var material := ThemeMaterials.wall_mat(_theme)
	var half := PLATE.x * 0.5 + HOOD_THICK
	var tall := PLATE.y * 0.5 + HOOD_THICK
	# Back, behind the plate.
	_panel(Vector3(half * 2.0, tall * 2.0, HOOD_THICK),
			Vector3(0.0, 0.0, HOOD_DEPTH * 0.5), material)
	# Two cheeks and a brow, reaching forward to the plate's own face.
	for side: float in [-1.0, 1.0]:
		_panel(Vector3(HOOD_THICK, tall * 2.0, HOOD_DEPTH),
				Vector3(half * side, 0.0, 0.0), material)
	_panel(Vector3(half * 2.0, HOOD_THICK, HOOD_DEPTH),
			Vector3(0.0, tall, 0.0), material)
	_panel(Vector3(half * 2.0, HOOD_THICK, HOOD_DEPTH),
			Vector3(0.0, -tall, 0.0), material)


func _panel(size: Vector3, at: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "HoodPanel"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	body.add_child(mesh_node)
	body.position = at
	hood.add_child(body)


## The direction the active face looks, in world space.
func facing() -> Vector3:
	return -global_transform.basis.z


func _process(delta: float) -> void:
	advance(delta)


## Split out so a suite can step the debounce by hand.
func advance(delta: float) -> void:
	if _rearm <= 0.0:
		return
	_rearm = maxf(_rearm - delta, 0.0)
	if _rearm <= 0.0 and element != null:
		element.reset()


func armed() -> bool:
	return _rearm <= 0.0


func _on_hit(_which: ActivityElement) -> void:
	if _rearm > 0.0:
		return
	_rearm = REARM_SECONDS
	hits += 1
	struck.emit(global_position)
