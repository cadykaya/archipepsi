class_name EchoLab
extends Node3D
## The Echo Lab (ECHOES §17): a permanent Hub annexe where a new mechanic
## can be understood by touching it, instead of waiting for a Zone that
## happens to suit it.
##
## **It owns no campaign truth.** Not a Zone, not a Check, not an
## allocation. Nothing here sends an AP intent, mutates checked locations,
## or writes a save. The fixtures give the *production* runtime things to
## hit, cross, climb and survive — the same folded Mechanics and the same
## four S7 runtimes the player uses in a real Zone. There is deliberately
## no Lab-side copy of the combat code: if a fixture needed one, that
## would be evidence the production interface was missing something.
##
## **It is a room, not a mode.** The player walks in through a doorway in
## the Hub's west wall and walks out the same way. That is what makes
## "base movement is always enough to leave" structural rather than a rule
## somebody has to remember: there is no transition to be stranded inside.
##
## Everything the Lab touches is transient by construction — dummy health,
## statuses, the moving target's phase, the hazard's armed state. `reset()`
## returns those to baseline and touches nothing else; the interpretation
## log, provenance, Mk levels, slots and favourites are not the Lab's to
## alter.

const THEME := "concrete_facility"
const W := 16.0
const D := 26.0
const H := 6.0
#: Placed so the Lab's own doorway (its local z=0 face, which
#: `_perimeter` opens) sits at the far end of the Hub's west corridor.
#: Rotated a quarter turn: the room's depth runs away from the Hub, so
#: walking through the door walks you down the runway.
## The gap, and why its width is not a free number.
##
## `GAP_WIDTH` is MECHANICALLY MEANINGFUL and regression-tested
## (`lab_driver.gd`). It sits deliberately between two movement
## constants:
##
##   - INSIDE `JUMP_FLAT_REACH` (4.667 m), so the base kit can clear it.
##     The Lab must never require an Echo to cross, or it stops being
##     somewhere a player can learn the base kit.
##   - well OUTSIDE `SAFE_BASE_JUMP_GAP` (2.6 m), the widest a MANDATORY
##     path may ask for (I3/I4). So it demonstrates that a mobility Echo
##     makes a real difference, without ever being something progression
##     depends on.
##
## Widen it past the reach and the Lab becomes unpassable without an
## Echo. Narrow it under the safe gap and it stops demonstrating
## anything. Both failures are silent, which is why they are tested.
const GAP_WIDTH := 4.5
const GAP_START := 14.0

const OFFSET := Vector3(-13.0, 0.0, 6.0)
const YAW := -90.0

var dummy: LabFixtures.LabDummy
var moving_target: LabFixtures.LabMovingTarget
var hazard: LabFixtures.LabHazard
var _fixtures: Dictionary = {}
var _recovery := Vector3(0, 1.0, 3.0)
var _announced: Dictionary = {}
var _notice: Label3D

func _ready() -> void:
	position = OFFSET
	rotation_degrees = Vector3(0, YAW, 0)
	_build_room()
	_build_fixtures()
	refresh_fixture_visibility()

func _build_room() -> void:
	var b := ChamberBuilders
	var root := Node3D.new()
	add_child(root)
	b._box(root, Vector3(W, 0.5, D), Vector3(0, -0.25, D / 2.0),
			ThemeMaterials.floor_mat(THEME))
	# Door on the near wall only: one way in, one way out, both on foot.
	b._perimeter(root, W, D, H, THEME, true, false)
	b._box(root, Vector3(W, 0.4, D), Vector3(0, H, D / 2.0),
			ThemeMaterials.trim_mat(THEME))
	for z in [4.0, 12.0, 20.0]:
		b._light(root, Vector3(0, H - 0.5, z), THEME, 14.0)

	# The tall wall: a broad vertical face for wall kicks, blink clearance,
	# grapple geometry and "how high did that send me". Height bands make
	# the answer readable without the debug overlay.
	var wall := Node3D.new()
	add_child(wall)
	b._box(wall, Vector3(0.6, H, 7.0), Vector3(W / 2.0 - 0.4, H / 2.0, 8.0),
			ThemeMaterials.wall_mat(THEME))
	for band in range(1, int(H)):
		var mark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.06, 6.6)
		mark.mesh = mesh
		mark.position = Vector3(W / 2.0 - 0.72, float(band), 8.0)
		mark.material_override = ThemeMaterials.glow_material(
				Color(0.45, 0.85, 0.95) if band % 2 == 0
				else Color(0.3, 0.45, 0.55), 0.9)
		wall.add_child(mark)
		var label := Label3D.new()
		label.text = "%dm" % band
		label.font_size = 28
		label.pixel_size = 0.006
		label.position = Vector3(W / 2.0 - 0.85, float(band), 4.6)
		label.rotation_degrees = Vector3(0, -90, 0)
		wall.add_child(label)

	# The runway: a clear lane with distance ticks, for dashes, speed
	# traits, recoil travel and glide carry.
	for tick in range(2, 22, 2):
		var mark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.0, 0.04, 0.12)
		mark.mesh = mesh
		mark.position = Vector3(-W / 4.0, 0.02, float(tick))
		mark.material_override = ThemeMaterials.glow_material(
				Color(0.9, 0.75, 0.35), 0.7)
		add_child(mark)
		var label := Label3D.new()
		label.text = "%dm" % tick
		label.font_size = 24
		label.pixel_size = 0.005
		label.position = Vector3(-W / 4.0 + 1.8, 0.06, float(tick))
		label.rotation_degrees = Vector3(-90, 0, 0)
		add_child(label)

	# The gap, and the pit under it. Falling in is cheap and obvious: a
	# sensing plane returns you to the recovery point. It is NOT a kill —
	# dying in the Hub to test a double jump would be absurd.
	_carve_gap(b)

func _carve_gap(b) -> void:
	# The floor above is one slab, so the gap is a hole cut by building the
	# pit's own walls and a return trigger rather than by subtracting
	# geometry the builders cannot subtract.
	var pit := Node3D.new()
	add_child(pit)
	var hole_start := GAP_START
	var hole_width := GAP_WIDTH
	# Two floor strips either side of the hole, laid over the base slab at
	# a hair's height so the hole reads as a hole.
	for strip in [[-W / 2.0, -W / 4.0 + 1.0], [W / 4.0 - 1.0, W / 2.0]]:
		var size := Vector3(strip[1] - strip[0], 0.6, hole_width)
		b._box(pit, size,
				Vector3((strip[0] + strip[1]) / 2.0, -0.3,
						hole_start + hole_width / 2.0),
				ThemeMaterials.trim_mat(THEME))
	# The actual hole: remove the slab under it by sinking a void box and
	# fencing it with a sensing area.
	var void_marker := MeshInstance3D.new()
	var void_mesh := BoxMesh.new()
	void_mesh.size = Vector3(W / 2.0 - 1.0, 0.05, hole_width)
	void_marker.mesh = void_mesh
	void_marker.position = Vector3(0, -0.8, hole_start + hole_width / 2.0)
	void_marker.material_override = ThemeMaterials.glow_material(
			Color(0.15, 0.05, 0.2), 0.4)
	pit.add_child(void_marker)

	var recovery := Area3D.new()
	recovery.name = "GapRecovery"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W - 1.0, 1.2, hole_width)
	shape.shape = box
	recovery.add_child(shape)
	recovery.position = Vector3(0, -1.6, hole_start + hole_width / 2.0)
	recovery.body_entered.connect(_on_gap_entered)
	add_child(recovery)
	_recovery = Vector3(0, 1.2, hole_start - 3.0)

## Falling in the gap returns you to the near lip. No damage, no death, no
## campaign state: the failure case for "can I clear this?" should cost a
## second, not a respawn.
func _on_gap_entered(body: Node3D) -> void:
	if body is Player:
		var player := body as Player
		# `global_transform * point`, not `global_position + offset`: the
		# Lab is rotated a quarter turn, so a local offset added to a
		# global point lands somewhere else entirely.
		player.global_position = global_transform * _recovery
		player.velocity = Vector3.ZERO

func _build_fixtures() -> void:
	dummy = LabFixtures.LabDummy.new()
	dummy.position = Vector3(W / 4.0, 0, 7.0)
	add_child(dummy)
	_fixtures["dummy"] = dummy

	moving_target = LabFixtures.LabMovingTarget.new()
	moving_target.position = Vector3(0, 1.2, 21.0)
	add_child(moving_target)
	_fixtures["moving_target"] = moving_target

	hazard = LabFixtures.LabHazard.new()
	hazard.position = Vector3(-W / 4.0, 0, 5.0)
	add_child(hazard)
	_fixtures["hazard"] = hazard

	var pad := LabFixtures.LabResetPad.new()
	pad.position = Vector3(0, 0, 2.0)
	pad.reset_requested.connect(reset)
	add_child(pad)
	_fixtures["reset_pad"] = pad

	_notice = Label3D.new()
	_notice.font_size = 30
	_notice.pixel_size = 0.007
	_notice.position = Vector3(0, 3.4, 2.4)
	_notice.modulate = Color(0.6, 1.0, 0.85)
	_notice.visible = false
	add_child(_notice)

func fixture(fixture_name: String) -> Node:
	return _fixtures.get(fixture_name)

## The Lab grows with the vocabulary (§17). A fixture appears because the
## campaign OWNS the capability, never because a provider decided Hub
## geometry — so this reads the fold and nothing else.
##
## S8 ships the six core fixtures, which are always present; the registry
## is the seam S9's water volumes, rails and anchors attach to without a
## rewrite.
const VOCABULARY_FIXTURES := {
	"moving_target": ["hitscan_damage", "projectile_damage", "arc_lob",
			"burst_fire", "charge_shot", "beam_sustained", "scan_mark",
			"grapple_pull_target"],
}

func refresh_fixture_visibility() -> void:
	var verbs: Dictionary = {}
	for entry: Dictionary in BridgeClient.owned_components("action"):
		var primitive: Dictionary = entry.get("component", {}).get(
				"primitive", {})
		verbs[str(primitive.get("type", ""))] = true
	for fixture_name: String in VOCABULARY_FIXTURES:
		var node: Node = _fixtures.get(fixture_name)
		if node == null:
			continue
		var wanted := false
		for verb: String in VOCABULARY_FIXTURES[fixture_name]:
			if verbs.has(verb):
				wanted = true
				break
		# Core fixtures stay present with an empty campaign; what the
		# vocabulary changes is whether they are ANNOUNCED, so a base-kit
		# player still has a full room to learn the base kit in.
		if wanted and not _announced.has(fixture_name):
			_announced[fixture_name] = true
			_announce()

## Session-local, deliberately: the joke is worth one line, not a new
## column in the save.
func _announce() -> void:
	if _notice == null:
		return
	_notice.text = "NEW MECHANIC DETECTED — TEST CHAMBER UPDATED\n" \
			+ "EPSILON: YOU ASKED WHAT IT DOES. THE WALL IS RIGHT THERE."
	_notice.visible = true

## Transient test state to baseline. Explicitly NOT: the interpretation
## log, folded ownership, provenance, Mk levels, slot choices, favourites,
## AP state or Hub progression. Those are earned; this is a workbench.
func reset(player: Player = null) -> void:
	dummy.reset_fixture()
	moving_target.reset_fixture()
	hazard.reset_fixture()
	if player != null:
		player.hp = Constants.PLAYER_MAX_HP
		player.statuses.clear()
		# `global_transform * point`, not `global_position + offset`: the
		# Lab is rotated a quarter turn, so a local offset added to a
		# global point lands somewhere else entirely.
		player.global_position = global_transform * _recovery
		player.velocity = Vector3.ZERO
		player.hp_changed.emit(player.hp, player.total_shield())
