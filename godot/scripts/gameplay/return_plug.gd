class_name ReturnPlug
extends Area3D
## A dead end's way back: the player walks in and arrives somewhere else.
##
## The owner's ruling (2026-09-11) is that a branch may dead-end provided
## it carries a return, chosen by the composer from an authored
## catalogue, landing the player at the Zone start or the last large
## room. This is the engine half of that: the device, its trigger, and
## the arrival.
##
## **It is not a door.** A `TRAVERSAL_ONLY` edge assigns no joining
## socket, meets no collar and closes no spatial loop, so a room's
## joining-socket budget is untouched by how many plugs it holds and the
## placement solver is never handed a closure constraint for one. The
## contract review states the schema consequence: a plug is carried by a
## `PlugAssignment` and never by a `DoorAssignment`.
##
## **Both ends are anchors, never coordinates.** The composer says WHICH
## anchor; this file's caller says where that anchor is. `zone_builder`'s
## opening line -- Epsilon never chooses world coordinates -- holds for
## the return device exactly as it holds for a room.

signal traversed(edge_id: String, destination: String)

const RADIUS := 1.4
const HEIGHT := 3.0
## HOW LONG YOU MUST STAND IN IT, and the whole point of the device
## having a cast at all.
##
## It used to fire on contact. A 1.4 m radius volume that teleports on
## touch is a trap you can fall into while backing away from something:
## the owner, in combat, brushed one and was standing at the Zone start
## before the fight resolved. A return you did not mean to take is worse
## than no return, because the branch you were in is now a walk away.
##
## Two seconds is long enough to be a decision and short enough not to
## be a chore, and walking out cancels it with nothing spent.
const HOLD_SECONDS := 2.0
## Idle glow, and what it climbs to while charging.
const IDLE_ENERGY := 0.9
const CHARGED_ENERGY := 7.0

var edge_id := ""
var destination := ""
var device := "threshold"
var _spent := false
## Seconds of unbroken contact so far. Reset the moment the player
## leaves, so a cancelled return costs nothing and leaves no state.
var _held := 0.0
var _inside := false
var _face: MeshInstance3D
var _ring: MeshInstance3D
var _label: Label3D

## The catalogue. Each entry is a LOOK, not a rule: every device moves
## the player the same way, and which one a Zone gets is the composer's
## choice from this closed set.
const DEVICES := ["threshold", "pad", "tube"]

static func create(edge: String, to_anchor: String, kind: String,
		theme: String) -> ReturnPlug:
	var plug := ReturnPlug.new()
	plug.name = "ReturnPlug_%s" % edge
	plug.edge_id = edge
	plug.destination = to_anchor
	plug.device = kind if kind in DEVICES else "threshold"
	plug.monitoring = true
	plug._build(theme)
	return plug

func _build(theme: String) -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position = Vector3(0, HEIGHT / 2.0, 0)
	add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "Face"
	match device:
		"pad":
			var disc := CylinderMesh.new()
			disc.top_radius = RADIUS
			disc.bottom_radius = RADIUS
			disc.height = 0.3
			mesh.mesh = disc
			mesh.position = Vector3(0, 0.15, 0)
		"tube":
			var tube := CylinderMesh.new()
			tube.top_radius = RADIUS * 0.8
			tube.bottom_radius = RADIUS * 0.8
			tube.height = HEIGHT
			mesh.mesh = tube
			mesh.position = Vector3(0, HEIGHT / 2.0, 0)
		_:
			var frame := BoxMesh.new()
			frame.size = Vector3(RADIUS * 2.0, HEIGHT, 0.25)
			mesh.mesh = frame
			mesh.position = Vector3(0, HEIGHT / 2.0, 0)
	# The reserved interactive language: a flat saturated colour, and
	# never the orange that means "this hurts you" (2026-08-28 ruling).
	mesh.material_override = ThemeMaterials.glow_material(
			Color(0.42, 0.85, 1.0), IDLE_ENERGY)
	add_child(mesh)
	_face = mesh

	# THE CHARGE, MADE VISIBLE. A cast the player cannot see is a delay,
	# not a decision: the ring climbs the device over `HOLD_SECONDS` so
	# what is about to happen, and how long is left to walk out of it,
	# are one thing you read rather than two you are told.
	var ring := MeshInstance3D.new()
	ring.name = "Charge"
	var band := TorusMesh.new()
	band.inner_radius = RADIUS * 0.82
	band.outer_radius = RADIUS * 1.02
	ring.mesh = band
	ring.material_override = ThemeMaterials.glow_material(
			Color(0.55, 0.95, 1.0), CHARGED_ENERGY)
	ring.visible = false
	add_child(ring)
	_ring = ring

	var label := Label3D.new()
	label.name = "PlugLabel"
	label.text = "RETURN"
	label.position = Vector3(0, HEIGHT + 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.006
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_label = label

	body_entered.connect(_on_body_entered)

## ENTERING ARMS IT; STANDING IN IT FIRES IT.
##
## `_spent` is still one traversal per entry -- without it a player
## standing in the volume fires every frame, which reads as being unable
## to move. What is new is that entering is no longer enough: the charge
## in `_process` is, and leaving cancels it.
func _on_body_entered(body: Node3D) -> void:
	if _spent or not body.is_in_group("player"):
		return
	_inside = true
	_held = 0.0

## LEAVING CANCELS, AND COSTS NOTHING. The device goes straight back to
## idle rather than holding a partial charge, because a return that
## remembers how nearly you took it is a return that fires on a brush
## you already thought better of.
func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_inside = false
	_held = 0.0
	_spent = false
	_idle()

## CHARGED IN PHYSICS TIME, because that is the clock the contact it
## depends on is measured on. `body_entered` and `body_exited` are
## physics callbacks; charging on idle frames meant the hold and the
## thing being held were counted against two different clocks.
func _physics_process(delta: float) -> void:
	if not _inside or _spent:
		return
	_held += delta
	var t := clampf(_held / HOLD_SECONDS, 0.0, 1.0)
	_charging(t)
	if _held < HOLD_SECONDS:
		return
	_spent = true
	_inside = false
	_idle()
	traversed.emit(edge_id, destination)

## The ring climbs, the device brightens, and the label counts down.
func _charging(t: float) -> void:
	if _ring != null:
		_ring.visible = true
		_ring.position = Vector3(0.0, HEIGHT * t, 0.0)
		_ring.rotation.y = TAU * t * 2.0
	if _face != null and _face.material_override != null:
		_face.material_override.set(
				"emission_energy_multiplier",
				lerpf(IDLE_ENERGY, CHARGED_ENERGY, t))
	if _label != null:
		_label.text = "RETURNING  %.1f" % maxf(
				HOLD_SECONDS - _held, 0.0)

func _idle() -> void:
	if _ring != null:
		_ring.visible = false
	if _face != null and _face.material_override != null:
		_face.material_override.set(
				"emission_energy_multiplier", IDLE_ENERGY)
	if _label != null:
		_label.text = "RETURN"

func _ready() -> void:
	body_exited.connect(_on_body_exited)
