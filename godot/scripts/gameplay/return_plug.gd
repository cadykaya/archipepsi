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

var edge_id := ""
var destination := ""
var device := "threshold"
var _spent := false

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
			Color(0.42, 0.85, 1.0), 0.9)
	add_child(mesh)

	var label := Label3D.new()
	label.name = "PlugLabel"
	label.text = "RETURN"
	label.position = Vector3(0, HEIGHT + 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.006
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	body_entered.connect(_on_body_entered)

## ONE TRAVERSAL PER ENTRY, and re-armed when the player leaves.
##
## Without the latch a player standing in the volume fires it every
## physics frame, which reads as being unable to move and is how a
## return device becomes a trap. `_spent` clears on exit rather than on a
## timer so the device is never briefly dead where the player is
## standing.
func _on_body_entered(body: Node3D) -> void:
	if _spent or not body.is_in_group("player"):
		return
	_spent = true
	traversed.emit(edge_id, destination)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_spent = false

func _ready() -> void:
	body_exited.connect(_on_body_exited)
