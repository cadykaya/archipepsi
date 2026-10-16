class_name FreightBay
extends Node3D
## THE FREIGHT BAY: the Shunter's arena, an optional annex off Station 1
## (D-20 rev 2 §6; owner, 2026-10-16: "an optional annex off Station 1 for
## this integration playtest. No Checks or campaign progression changes").
##
##                                  N (local -z)
##   +------------------------------------------------------+
##   | [stack + tote]  ==== tend lane ====  [DOCK]           |  z -12
##   |      [P1]                                 [P2]        |  z -3
##   |                     [ GATE ]  (a lever on each face)  |  z  1
##   |   [C1]                                                |  z  3
##   |      [P3]                                 [P4]        |  z  7
##   |                                  [C2]                 |  z  9
##   |                         [ramp]<door|  BOOTH (glass)   |  z 11-14
##   +-----------------------------------------[corridor]----+  to Station 1
##     bay x -10..10, z -14..14, 7 m high, flat, closed roof
##
## Built from existing parts only: steel pillars, `DestructibleCover`
## crates, a `ServiceShutter` freight gate with kit `CallLever`s on both
## faces, a `ServiceShutter` booth door, a `ManipulableBody` tote, and the
## G0 glass that stops shots. Nothing here sends anything to the bridge or
## is saved: RESTART puts it all back.
##
## The music hooks are signals (Condi's handoff, `events.json`):
## `annex_entered` / `annex_left` (station <-> Freight Bay music), the
## Shunter's `horned` (`engage`) and `powered_down` (`victory`), and
## `restarted` (stop, play).

signal annex_entered
signal annex_left
signal restarted

const THEME := "rusted_industrial"
const W := 20.0
const D := 28.0
const H := 7.0
## Where Station 1's front door leads: the arena's origin in the Hub.
const OFFSET := Vector3(-7.0, 0.0, -20.0)
const BOOTH_FLOOR := 1.5
const GATE_HELD := 6.0                  # D-20: one pull closes it for 6 s
const STACK := Vector3(-6.0, 0.0, -12.0)
const DOCK := Vector3(6.0, 0.0, -12.2)
const PILLARS := [Vector3(-5, 0, -3), Vector3(5, 0, -3), Vector3(-5, 0, 7),
		Vector3(5, 0, 7)]
const CRATES := [Vector3(-7.0, 0.0, 3.0), Vector3(2.0, 0.0, 9.0)]
const GATE_AT := Vector3(0.0, 0.0, 1.0)

var shunter: Shunter
var gate: ServiceShutter
var gate_levers: Array[CallLever] = []
var booth_door: ServiceShutter
var restart_lever: CallLever
var crates: Array[DestructibleCover] = []
var tote: ManipulableBody
var in_annex := false
var on_bay_floor := false
## Telemetry: gate close timings, kills, restarts.
var gate_log: Array = []
var kills := 0
var restarts := 0

var _gate_closing_since := -1.0
var _watching: Player = null
var _gate_reopen := 0.0
var _steel: StandardMaterial3D
var _wall: Material
var _floor: Material


func _ready() -> void:
	name = "FreightBay"
	position = OFFSET
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.32, 0.34, 0.37)
	_steel.metallic = 0.7
	_steel.roughness = 0.45
	_wall = ThemeMaterials.wall_mat(THEME)
	_floor = ThemeMaterials.floor_mat(THEME)
	_build_shell()
	_build_booth()
	_build_corridor()
	_build_floor_parts()
	_build_gate()
	_build_restart()
	_spawn()


func _physics_process(delta: float) -> void:
	var player := _player()
	if player != null and player != _watching:
		# Death in the bay restarts it (Condi: "RESTART, or the player dies").
		_watching = player
		player.died.connect(func() -> void:
			if in_annex:
				restart.call_deferred())
	if player != null:
		var now := player.global_position.z < -0.4
		if now != in_annex:
			in_annex = now
			if now:
				annex_entered.emit()
			else:
				annex_left.emit()
		var local := to_local(player.global_position)
		var floor_now := local.x < -0.6 and local.y < 0.6 \
				and absf(local.z) < D / 2.0
		if floor_now and not on_bay_floor:
			# One way: the booth door closes behind you (D-20 §6).
			booth_door.command(false)
		on_bay_floor = floor_now
	if _gate_reopen > 0.0:
		_gate_reopen -= delta
		if _gate_reopen <= 0.0:
			gate.command(true)
			for lever in gate_levers:
				lever.locked = false
				lever.label = "CLOSE THE GATE"


# ============================================================ the shell

func _build_shell() -> void:
	var b := ChamberBuilders
	b._box(self, Vector3(W, 0.5, D), Vector3(0, -0.25, 0), _floor)
	b._box(self, Vector3(W, 0.4, D), Vector3(0, H + 0.2, 0),
			ThemeMaterials.trim_mat(THEME))
	b._box(self, Vector3(0.4, H, D), Vector3(-W / 2.0, H / 2.0, 0), _wall)
	b._box(self, Vector3(0.4, H, D), Vector3(W / 2.0, H / 2.0, 0), _wall)
	b._box(self, Vector3(W, H, 0.4), Vector3(0, H / 2.0, -D / 2.0), _wall)
	# The south wall (z +14) carries the corridor's opening at x 5.8..8.2,
	# y 1.5..3.7, into the booth.
	b._box(self, Vector3(15.8, H, 0.4), Vector3(-2.1, H / 2.0, D / 2.0), _wall)
	b._box(self, Vector3(1.8, H, 0.4), Vector3(9.1, H / 2.0, D / 2.0), _wall)
	b._box(self, Vector3(2.4, H - 3.7, 0.4),
			Vector3(7.0, 3.7 + (H - 3.7) / 2.0, D / 2.0), _wall)
	for at in [Vector3(-5, H - 0.5, -8), Vector3(5, H - 0.5, -8),
			Vector3(-5, H - 0.5, 4), Vector3(5, H - 0.5, 4)]:
		b._light(self, at, THEME, 14.0)
	var sign_plate := Label3D.new()
	sign_plate.text = "FREIGHT BAY"
	sign_plate.font_size = 64
	sign_plate.pixel_size = 0.01
	sign_plate.position = Vector3(0, 5.6, -D / 2.0 + 0.25)
	sign_plate.modulate = Color(1.0, 0.75, 0.35)
	add_child(sign_plate)


## The booth: a raised, glazed room over the bay's south-east corner. Glass
## that stops shots both ways (G0): for watching, not hiding.
func _build_booth() -> void:
	var b := ChamberBuilders
	var glass := ThemeMaterials.glass_material(Color(0.62, 0.8, 0.9, 0.24))
	b._box(self, Vector3(6, BOOTH_FLOOR, 3), Vector3(7, BOOTH_FLOOR / 2.0, 12.5),
			_floor)
	b._box(self, Vector3(6, 0.3, 3), Vector3(7, 4.15, 12.5),
			ThemeMaterials.trim_mat(THEME))
	b._box(self, Vector3(6, 2.5, 0.1), Vector3(7, BOOTH_FLOOR + 1.25, 11.0),
			glass)
	b._box(self, Vector3(0.1, 2.5, 1.0), Vector3(4.0, BOOTH_FLOOR + 1.25, 11.5),
			glass)
	_lamp(Vector3(7, 3.85, 12.5), 6.0)
	# The ramp down to the bay door, in a glazed channel along the wall.
	var ramp_len := sqrt(3.5 * 3.5 + BOOTH_FLOOR * BOOTH_FLOOR)
	var ramp := b._box(self, Vector3(ramp_len, 0.3, 2.0),
			Vector3(2.25, BOOTH_FLOOR / 2.0 - 0.15, 13.0), _floor)
	ramp.rotation.z = atan2(BOOTH_FLOOR, 3.5)
	b._box(self, Vector3(4.0, 4.0, 0.1), Vector3(2.0, 2.0, 12.0), glass)
	b._box(self, Vector3(4.0, 0.3, 2.0), Vector3(2.0, 4.15, 13.0),
			ThemeMaterials.trim_mat(THEME))
	b._box(self, Vector3(0.3, 0.8, 2.0), Vector3(0.0, 3.6, 13.0), _wall)
	booth_door = ServiceShutter.create(Vector3(0.0, 1.6, 13.0),
			Vector3(2.0, 3.2, 0.3), 3.4, THEME)
	booth_door.rotation.y = PI / 2.0
	add_child(booth_door)
	booth_door.settle(true)


## From Station 1's front door to the booth: 6 m, the last 4 m a ramp up
## to the booth floor. In the Hub's frame it runs from z 0 to z -6.
func _build_corridor() -> void:
	var b := ChamberBuilders
	var hub_door := to_local(Vector3.ZERO)          # (7, 0, 20) locally
	var x := hub_door.x
	var z0 := hub_door.z                            # the Hub's front wall
	var z1 := D / 2.0                               # the booth's back wall
	var run := z0 - z1                              # 6 m
	b._box(self, Vector3(2.4, 0.5, 2.0), Vector3(x, -0.25, z0 - 1.0), _floor)
	var slope_len := sqrt((run - 2.0) * (run - 2.0) + BOOTH_FLOOR * BOOTH_FLOOR)
	var slope := b._box(self, Vector3(2.4, 0.3, slope_len),
			Vector3(x, BOOTH_FLOOR / 2.0 - 0.15, z1 + (run - 2.0) / 2.0), _floor)
	# Rises toward the booth (-z): +x rotation lifts the -z end.
	slope.rotation.x = atan2(BOOTH_FLOOR, run - 2.0)
	for side: float in [-1.0, 1.0]:
		b._box(self, Vector3(0.3, 4.2, run), Vector3(x + side * 1.35, 2.1,
				z1 + run / 2.0), _wall)
	b._box(self, Vector3(2.4, 0.3, run), Vector3(x, 4.15, z1 + run / 2.0),
			ThemeMaterials.trim_mat(THEME))
	_lamp(Vector3(x, 3.9, z1 + run / 2.0), 7.0)
	var sign_plate := Label3D.new()
	sign_plate.text = "FREIGHT BAY\n(optional — a combat test, nothing is saved)"
	sign_plate.font_size = 28
	sign_plate.pixel_size = 0.006
	sign_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_plate.position = Vector3(x, 3.5, z0 + 0.3)
	sign_plate.modulate = Color(1.0, 0.75, 0.35)
	add_child(sign_plate)


## A bare light for the low booth and corridor: `ChamberBuilders._light`
## hangs an authored housing that reaches eye level under a 2.5 m ceiling.
func _lamp(at: Vector3, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.omni_range = reach
	light.light_energy = 1.6
	light.light_color = ThemeMaterials.light_color(THEME)
	add_child(light)


func _build_floor_parts() -> void:
	var b := ChamberBuilders
	for at: Vector3 in PILLARS:
		b._box(self, Vector3(1.2, H, 1.2), at + Vector3(0, H / 2.0, 0), _steel)
	# The crate stack and the dock, at the lane's two declared ends.
	for i in 3:
		b._box(self, Vector3(1.2, 1.2, 1.2),
				STACK + Vector3(-1.9 + i * 0.1, 0.6 + i * 1.2, -1.0),
				ThemeMaterials.accent_mat(THEME))
	var dock := b._box(self, Vector3(2.0, 1.2, 0.8),
			DOCK + Vector3(0, 0.6, -1.4), _steel)
	dock.name = "Dock"
	var socket := MeshInstance3D.new()
	var socket_mesh := BoxMesh.new()
	socket_mesh.size = Vector3(0.35, 0.35, 0.08)
	socket.mesh = socket_mesh
	socket.material_override = ThemeMaterials.glow_material(
			Color(0.3, 1.0, 0.45), 2.0)
	socket.position = DOCK + Vector3(0, 0.9, -0.98)
	add_child(socket)
	# The green line: the dock's power feeds the gate.
	var feed := ThemeMaterials.glow_material(Color(0.3, 1.0, 0.45), 0.8)
	b._box(self, Vector3(DOCK.x - GATE_AT.x, 0.02, 0.12),
			Vector3((DOCK.x + GATE_AT.x) / 2.0, 0.01, DOCK.z + 0.2), feed, false)
	b._box(self, Vector3(0.12, 0.02, GATE_AT.z - DOCK.z - 0.6),
			Vector3(GATE_AT.x + 0.4, 0.01, (DOCK.z + GATE_AT.z) / 2.0), feed,
			false)


func _build_gate() -> void:
	var b := ChamberBuilders
	for side: float in [-1.0, 1.0]:
		b._box(self, Vector3(1.5, 4.6, 0.4),
				GATE_AT + Vector3(side * 2.25, 2.3, 0), _steel)
	b._box(self, Vector3(3.0, 1.2, 0.4), GATE_AT + Vector3(0, 4.0, 0), _steel)
	gate = ServiceShutter.create(GATE_AT + Vector3(0, 1.7, 0),
			Vector3(3.0, 3.4, 0.3), 3.6, THEME)
	add_child(gate)
	gate.settle(true)
	gate.closed.connect(_on_gate_closed)
	# A kit lever on each face (D-20 §6): north and south of the frame.
	for face: float in [-1.0, 1.0]:
		var lever := CallLever.make("CLOSE THE GATE", Color(1.0, 0.75, 0.3),
				THEME)
		add_child(lever)
		lever.position = GATE_AT + Vector3(2.25 * -face, CallLever.BASE.y / 2.0,
				face * 0.85)
		lever.pulled.connect(_on_gate_lever)
		gate_levers.append(lever)


func _build_restart() -> void:
	restart_lever = CallLever.make("RESTART THE BAY", Color(0.5, 0.8, 1.0),
			THEME)
	add_child(restart_lever)
	restart_lever.position = Vector3(9.0, BOOTH_FLOOR + CallLever.BASE.y / 2.0,
			13.3)
	restart_lever.pulled.connect(func(_l: CallLever) -> void: restart())
	var label := Label3D.new()
	label.text = "RESTART: Shunter, crates, gate, door"
	label.font_size = 26
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = restart_lever.position + Vector3(0, 1.4, 0)
	add_child(label)


# ============================================================ the encounter

## Shunter at the dock, crates whole, gate open, booth door open, marks
## cleared (D-20 §6, RESTART).
func _spawn() -> void:
	if shunter != null and is_instance_valid(shunter):
		shunter.queue_free()
	for crate in crates:
		if is_instance_valid(crate):
			crate.queue_free()
	crates.clear()
	if tote != null and is_instance_valid(tote):
		tote.queue_free()
	for at: Vector3 in CRATES:
		var crate := DestructibleCover.create(THEME)
		crate._tint = Color(0.95, 0.45, 0.12)       # D-20: orange crates
		crate._mesh.material_override = crate._material(0.0)
		add_child(crate)
		crate.position = at + Vector3(0, DestructibleCover.SIZE.y / 2.0, 0)
		crates.append(crate)
	tote = ManipulableBody.create("freight_tote", 20.0, Vector3(0.8, 0.6, 0.6))
	var tote_mesh := MeshInstance3D.new()
	var tote_box := BoxMesh.new()
	tote_box.size = Vector3(0.8, 0.6, 0.6)
	tote_mesh.mesh = tote_box
	tote_mesh.material_override = ThemeMaterials.accent_mat(THEME)
	tote.add_child(tote_mesh)
	add_child(tote)
	tote.position = STACK + Vector3(-0.6, 0.31, 0.9)
	shunter = Shunter.make()
	add_child(shunter)
	shunter.global_position = to_global(DOCK)
	shunter.rotation.y = 0.0                        # facing the wall: back to the booth
	shunter.set_lane(to_global(STACK), to_global(DOCK), tote)
	shunter.charge_source = _charge_source
	shunter.driver_firing = _driver_out
	shunter.powered_down.connect(_on_shunter_down)
	gate.settle(true)
	_gate_reopen = 0.0
	for lever in gate_levers:
		lever.locked = false
		lever.label = "CLOSE THE GATE"
	booth_door.settle(true)


func restart() -> void:
	restarts += 1
	_clear_marks()
	_spawn()
	on_bay_floor = false
	restarted.emit()


func _on_shunter_down() -> void:
	kills += 1
	booth_door.command(true)


## Your marks on the bay's walls go with a restart (the weapons' own list).
func _clear_marks() -> void:
	var armory := _armory()
	if armory == null:
		return
	for mark: Variant in armory.weapons.impacts.marks:
		if mark is Node and is_instance_valid(mark) \
				and is_ancestor_of(mark as Node):
			(mark as Node).queue_free()


func _on_gate_lever(_lever: CallLever) -> void:
	if not gate.is_open() or _gate_reopen > 0.0 or _gate_closing_since >= 0.0:
		return
	_gate_closing_since = Time.get_ticks_msec() / 1000.0
	gate.command(false)
	for lever in gate_levers:
		lever.lock("GATE CLOSING")


func _on_gate_closed() -> void:
	if _gate_closing_since >= 0.0:
		var took := Time.get_ticks_msec() / 1000.0 - _gate_closing_since
		gate_log.append({"closed_in": took})
		_gate_closing_since = -1.0
	_gate_reopen = GATE_HELD
	for lever in gate_levers:
		lever.label = "GATE CLOSED"


func _armory() -> UnifiedArmory:
	var main_node := get_tree().current_scene
	var a: Variant = main_node.get("armory") if main_node != null else null
	return a as UnifiedArmory if a is UnifiedArmory and is_instance_valid(a) \
			else null


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Where a Mass Driver charge can be heard from: the player, while one is
## charging; nowhere otherwise.
func _charge_source() -> Vector3:
	var armory := _armory()
	if armory == null or armory.out() != "driver" or not armory.weapons.charging:
		return Vector3.INF
	return armory.player.global_position


## The Mass Driver's cap applies while it is the weapon out (its slug is
## the only projectile among the five).
func _driver_out() -> bool:
	var armory := _armory()
	return armory != null and armory.out() == "driver"
