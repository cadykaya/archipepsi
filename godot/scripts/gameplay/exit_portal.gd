class_name ExitPortal
extends StaticBody3D
## The appended exit portal after the final chamber. Locked until every
## assigned Check confirms (the bridge auto-completes the Zone; the client
## just reads the result). Interacting on a finished Zone is pure travel.

signal exit_requested

var unlocked := false
var remaining := 0            # unconfirmed Checks still holding it shut
var _frame: MeshInstance3D
var _core: MeshInstance3D
var _label: Label3D

## The approved art (ART-CATCHUP): the wound frame (batch 002) and the two
## cores (batch 006), sealed and torn open. The states differ by FORM, in
## the identity family, so the authored cores keep their own paint rather
## than wearing the code's red/green. Missing art falls back to the boxes.
const ART := "res://content/ways_out/%s.glb"

static func art_mesh(model: String) -> Mesh:
	return ArtModels.mesh(ART % model)

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
	var wound := art_mesh("portal_b2_wound")
	if wound != null:
		frame.mesh = wound
	else:
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
	# The authored cores stand on the floor at true height (art req 12).
	if art_mesh("portal_core_locked") != null:
		core.position = Vector3.ZERO
	portal.add_child(core)

	var label := Label3D.new()
	label.name = "StateLabel"
	label.position = Vector3(0, 4.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.006
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal.add_child(label)
	return portal

func _ready() -> void:
	_frame = get_node("Frame")
	_core = get_node("Core")
	_label = get_node("StateLabel")
	_refresh()

func set_unlocked(value: bool, checks_remaining: int = 0) -> void:
	unlocked = value
	remaining = checks_remaining
	_refresh()

func _refresh() -> void:
	if _core == null:
		return
	var authored := art_mesh(
			"portal_core_unlocked" if unlocked else "portal_core_locked")
	if authored != null:
		_core.mesh = authored
		_core.material_override = null
	else:
		_core.material_override = ThemeMaterials.glow_material(
				Color(0.5, 1.0, 0.6) if unlocked else Color(0.4, 0.2, 0.2),
				2.0 if unlocked else 0.5)
	if _label != null:
		if unlocked:
			_label.text = "EXIT"
			_label.modulate = Color(0.6, 1.0, 0.7)
		else:
			_label.text = "SEALED\n%d CHECK%s REMAIN%s" % [remaining,
					"" if remaining == 1 else "S",
					"S" if remaining == 1 else ""]
			_label.modulate = Color(0.95, 0.5, 0.45)

func interact_prompt() -> String:
	if unlocked:
		return "[E] RETURN TO HUB"
	if remaining <= 0:
		return "SEALED"
	return "SEALED — %d CHECK%s STILL OUT THERE" % [
			remaining, "" if remaining == 1 else "S"]

func interact(_player: Node) -> void:
	if unlocked:
		exit_requested.emit()
