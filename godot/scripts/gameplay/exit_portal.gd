class_name ExitPortal
extends StaticBody3D
## The appended exit portal after the final chamber. Locked until every
## assigned Check confirms (the bridge auto-completes the Zone; the client
## just reads the result). Interacting on a finished Zone is pure travel.

signal exit_requested

var unlocked := false
var remaining := 0            # unconfirmed Checks still holding it shut
## D-22 slice (`docs/D22_SLICE_BRIEF.md` §2 step 4): SECURE = LEAVE. The
## portal is always usable and its label tells the truth -- "LEAVE — n
## transfers remain", or "RETURN" once the bridge has untethered the
## Crossing. Off unless `set_slice` is called, which only a slice run does.
var slice_leave := false
var untethered := false
var _tether: Node3D = null
var _tether_beam: MeshInstance3D = null
var _tether_cap: MeshInstance3D = null
var _tether_label: Label3D = null
var _release_t := -1.0
## The release waits to be SEEN: it plays once the player is within
## `SEEN_WITHIN` of the anchor, so the untether is a moment the player
## watches rather than one that finished while a reveal card was up, or
## three rooms away. The released state itself (cap, label, RETURN) is
## immediate. Proximity, not "on screen": a frustum test ignores walls,
## and the rendered check caught it playing to a player 118 m away.
const SEEN_WITHIN := 14.0
var _release_pending := false
var _watcher: Node3D = null
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

## The slice's portal: usable whatever is outstanding. `checks_remaining`
## is the Crossing's unconfirmed Checks; `is_untethered` is the bridge
## saying the Crossing is COMPLETE. Both are read, neither is decided here.
func set_slice(checks_remaining: int, is_untethered: bool) -> void:
	slice_leave = true
	unlocked = true
	remaining = checks_remaining
	untethered = is_untethered
	_ensure_tether()
	_refresh()

## THE UNTETHER MOMENT, in the Crossing: the destination anchor beside the
## exit lets go of its tether. Presentation only -- it plays because the
## bridge said COMPLETE, and `settle` puts it straight in the released pose
## for a Crossing loaded already untethered.
func release_tether(animate := true, watcher: Node3D = null) -> void:
	_ensure_tether()
	if animate:
		_release_pending = true
		_watcher = watcher
	else:
		_release_t = -1.0
		_tether_beam.visible = false
	_tether_cap.material_override = ThemeMaterials.glow_material(
			Color(0.4, 1.0, 0.6), 0.9)
	_tether_label.text = "UNTETHERED"
	_tether_label.modulate = Color(0.6, 1.0, 0.7)

func tether_released() -> bool:
	return _tether != null and not _tether_beam.visible

func tether_release_pending() -> bool:
	return _release_pending

func _process(delta: float) -> void:
	if _release_pending:
		var near := _watcher != null and is_instance_valid(_watcher) \
				and _watcher.global_position.distance_to(
						_tether.global_position) <= SEEN_WITHIN
		if near:
			_release_pending = false
			_release_t = 0.0
	if _release_t < 0.0 or _tether_beam == null:
		return
	# The tether reels up and away over 1.4 s: it rises, thins and goes.
	_release_t += delta
	var k := clampf(_release_t / 1.4, 0.0, 1.0)
	_tether_beam.position.y = 2.6 + 6.0 + k * 14.0
	_tether_beam.scale = Vector3(1.0 - 0.8 * k, 1.0, 1.0 - 0.8 * k)
	if k >= 1.0:
		_tether_beam.visible = false
		_release_t = -1.0

func _ensure_tether() -> void:
	if _tether != null:
		return
	# A pylon beside the portal with a glowing cable running up out of the
	# Crossing: the line that still binds this place to the station.
	_tether = Node3D.new()
	_tether.name = "TetherAnchor"
	_tether.position = Vector3(2.4, 0, 0)
	add_child(_tether)
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.45, 2.4, 0.45)
	post.mesh = post_mesh
	post.position = Vector3(0, 1.2, 0)
	post.material_override = _frame.material_override if _frame != null \
			else null
	_tether.add_child(post)
	_tether_cap = MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.6, 0.25, 0.6)
	_tether_cap.mesh = cap_mesh
	_tether_cap.position = Vector3(0, 2.5, 0)
	_tether_cap.material_override = ThemeMaterials.glow_material(
			Color(1.0, 0.7, 0.25), 0.9)
	_tether.add_child(_tether_cap)
	_tether_beam = MeshInstance3D.new()
	_tether_beam.name = "Tether"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.12, 12.0, 0.12)
	_tether_beam.mesh = beam_mesh
	_tether_beam.position = Vector3(0, 2.6 + 6.0, 0)
	_tether_beam.material_override = ThemeMaterials.glow_material(
			Color(1.0, 0.75, 0.3), 1.2)
	_tether.add_child(_tether_beam)
	_tether_label = Label3D.new()
	_tether_label.position = Vector3(0, 3.1, 0)
	_tether_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tether_label.font_size = 30
	_tether_label.pixel_size = 0.006
	_tether_label.text = "TETHERED"
	_tether_label.modulate = Color(1.0, 0.8, 0.45)
	_tether.add_child(_tether_label)

func _refresh() -> void:
	if _core == null:
		return
	if slice_leave:
		# D-22 slice: amber "leave" on the plain core while tethered; once
		# untethered, the art pass's open core where it exists.
		var opened := art_mesh("portal_core_unlocked") if untethered else null
		if opened != null:
			_core.mesh = opened
			_core.material_override = null
		else:
			_core.material_override = ThemeMaterials.glow_material(
					Color(0.5, 1.0, 0.6) if untethered else Color(1.0, 0.72, 0.3),
					2.0)
		if _label != null:
			_label.text = slice_label()
			_label.modulate = Color(0.6, 1.0, 0.7) if untethered \
					else Color(1.0, 0.82, 0.5)
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

## "LEAVE — n transfers remain", or "RETURN" once untethered.
func slice_label() -> String:
	if untethered:
		return "RETURN"
	return "LEAVE — %d transfer%s remain%s" % [remaining,
			"" if remaining == 1 else "s", "s" if remaining == 1 else ""]

func interact_prompt() -> String:
	if slice_leave:
		return "[E] " + slice_label()
	if unlocked:
		return "[E] RETURN TO HUB"
	if remaining <= 0:
		return "SEALED"
	return "SEALED — %d CHECK%s STILL OUT THERE" % [
			remaining, "" if remaining == 1 else "S"]

func interact(_player: Node) -> void:
	if unlocked:
		exit_requested.emit()
