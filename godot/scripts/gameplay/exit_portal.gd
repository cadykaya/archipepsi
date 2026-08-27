class_name ExitPortal
extends StaticBody3D
## The appended exit portal after the final chamber. Locked until every
## assigned Check confirms (the bridge auto-completes the Zone; the client
## just reads the result). Interacting on a finished Zone is pure travel.

signal exit_requested

var unlocked := false
var _frame: MeshInstance3D
var _core: MeshInstance3D

static func create(theme: String) -> ExitPortal:
	var portal := StaticBody3D.new()
	portal.set_script(load("res://scripts/gameplay/exit_portal.gd"))
	portal.name = "ExitPortal"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 4.0, 1.0)
	shape.shape = box
	shape.position = Vector3(0, 2.0, 0)
	portal.add_child(shape)

	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(3.2, 4.2, 0.6)
	frame.mesh = frame_mesh
	frame.position = Vector3(0, 2.1, 0)
	frame.material_override = ThemeMaterials.trim_mat(theme)
	portal.add_child(frame)

	var core := MeshInstance3D.new()
	core.name = "Core"
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(2.4, 3.4, 0.2)
	core.mesh = core_mesh
	core.position = Vector3(0, 1.9, 0)
	portal.add_child(core)
	return portal

func _ready() -> void:
	_frame = get_node("Frame")
	_core = get_node("Core")
	_refresh()

func set_unlocked(value: bool) -> void:
	unlocked = value
	_refresh()

func _refresh() -> void:
	if _core == null:
		return
	_core.material_override = ThemeMaterials.glow_material(
			Color(0.5, 1.0, 0.6) if unlocked else Color(0.4, 0.2, 0.2),
			2.0 if unlocked else 0.5)

func interact_prompt() -> String:
	return "[E] RETURN TO HUB" if unlocked \
			else "SEALED — CLEAR EVERY CHECK"

func interact(_player: Node) -> void:
	if unlocked:
		exit_requested.emit()
