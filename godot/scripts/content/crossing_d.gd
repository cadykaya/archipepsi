class_name CrossingD
extends Node3D
## CROSSING D, PLAYABLE: the review build's host (`--crossing-d`, or the
## exported build's `crossing_review` feature).
## **A comparison build for review, not a Zone and not the campaign.**
##
## It owns what only a launcher has -- the player, the HUD, a pause menu,
## checkpoints and a session tally -- around one `CrossingDRoom`. Like the
## other named scenarios (`--counterfire`, `--railway`) it is entered
## before `Main.boot()` and instead of it; unlike them it is isolated
## before any connection exists (`ReviewIsolation`): no bridge socket, no
## campaign, no save, none of the player's three client files written.
##
## **THE KIT.** The base kit, plus Wisp's study A swing tether (28 m range,
## force 28, 4 s) -- and the tether only inside the Courtyard. The swing
## catches ANY solid surface (`EchoRuntime._grapple_swing` asks only for a
## `StaticBody3D`), not just the swing plates, so equipped everywhere it
## would carry a player over the Machine Hall's gap or straight up the
## tower: the very routes Dess's brief rules out (a route that needs none
## of the room's activity is a defect). No dash anywhere.

const FLAG := ReviewIsolation.CROSSING_FLAG
const EMPTY_FLAG := "--empty-yard"
const FEATURE := ReviewIsolation.CROSSING_FEATURE
const MENU_HOLD := "crossing_menu"
const TETHER := {"kind": "action", "component_id": "crossing_swing",
		"display_name": "Swing tether", "slot": "echo_a",
		"description": "Jump, then hold RMB; release to let go.",
		"cooldown": 0.35, "primitive": {"type": "grapple_swing",
			"range": 28.0, "tether_force": 28.0, "max_duration": 4.0},
		"modifiers": []}
## Where R and a death bring you back to: the last of these you stood in.
const CHECKPOINTS := [
	{"id": "arrival", "box": AABB(Vector3(-12, -1, -12), Vector3(24, 4, 32)),
		"at": Vector3(-7.0, 1.1, 18.5), "yaw": 0.0},
	{"id": "courtyard", "box": AABB(Vector3(12, -1, -16), Vector3(32, 4, 28)),
		"at": Vector3(15.0, 1.1, 1.0), "yaw": -PI * 0.5},
	{"id": "balcony", "box": AABB(Vector3(37, 9, -12), Vector3(7, 3, 11)),
		"at": Vector3(41.0, 10.6, -4.0), "yaw": 0.0},
	{"id": "machine", "box": AABB(Vector3(-34, -1, 4), Vector3(21.5, 4, 10)),
		"at": Vector3(-14.5, 1.1, 7.0), "yaw": PI * 0.5},
	{"id": "machine_far", "box": AABB(Vector3(-34, -1, -18), Vector3(21.5, 4, 14)),
		"at": Vector3(-17.0, 1.1, -8.5), "yaw": PI * 0.5},
	{"id": "alcove", "box": AABB(Vector3(-9.6, 9, -16.4), Vector3(5.2, 3, 3.9)),
		"at": Vector3(-7.0, 10.1, -14.0), "yaw": 0.0},
]

var room: CrossingDRoom
var player: Player
var hud: Hud
var populated := true
var checkpoint := "arrival"
var found := {}
var elapsed := 0.0
var completed := false
var tether_on := false

var _overlay: CanvasLayer
var _objective: Label
var _tally: Label
var _tether: Label
var _note: Label
var _note_left := 0.0
var _menu: Control = null


static func requested() -> bool:
	return ReviewIsolation.crossing()


static func empty_requested() -> bool:
	return EMPTY_FLAG in OS.get_cmdline_user_args()


func _ready() -> void:
	name = "CrossingDReview"
	process_mode = Node.PROCESS_MODE_ALWAYS
	populated = not empty_requested()
	_environment()
	room = CrossingDRoom.new()
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	room.populated = populated
	add_child(room)
	room.build()
	room.said.connect(_say)
	room.stand_in_found.connect(_on_found)
	room.exit_used.connect(_on_exit)
	room.power_restored.connect(_refresh_objective)
	_spawn_player()
	_hud()
	_overlay_build()
	_refresh_objective()
	print("crossing-d: review build, %s yard; isolated (no bridge, no save)"
			% ("populated" if populated else "empty"))


func _environment() -> void:
	var holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ThemeMaterials.void_color(CrossingDRoom.THEME)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ThemeMaterials.light_color(CrossingDRoom.THEME)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	holder.environment = env
	add_child(holder)


func _spawn_player() -> void:
	player = Player.create()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	var first: Dictionary = CHECKPOINTS[0]
	player.set_spawn(Transform3D(Basis(Vector3.UP, float(first["yaw"])),
			first["at"]))
	player.velocity = Vector3.ZERO
	if player.camera != null:
		player.camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _hud() -> void:
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.bind_player(player)
	hud.visible = true


func _overlay_build() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	_objective = _label(Vector2(24, 18), 22)
	_tally = _label(Vector2(24, 50), 17)
	_tether = _label(Vector2(24, 76), 17)
	_note = _label(Vector2(24, 104), 18)
	var keys := _label(Vector2(24, 642), 15)
	keys.text = ("WASD move · Space jump · Mouse look · LMB pulse · "
			+ "E use / carry / install\nRMB swing tether (Courtyard only) · "
			+ "R last checkpoint · Esc menu")


func _label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_overlay.add_child(label)
	return label


func _say(text: String) -> void:
	_note.text = text
	_note_left = 6.0
	_refresh_objective()


func _refresh_objective() -> void:
	if _objective == null:
		return
	if completed:
		_objective.text = "CROSSING COMPLETE"
	elif not room.powered:
		_objective.text = "Reach the exit at the top of the tower. The lift has no power."
	elif room.yard_box().has_point(player.global_position):
		_objective.text = "The exit is across the Upper Yard. Fight, or run for it."
	else:
		_objective.text = "The lift has power: take it up. The exit is across the Upper Yard."
	var checks := 0
	for id: String in found:
		if (room.stand_ins[id] as CrossingDParts.StandIn).kind == "check":
			checks += 1
	_tally.text = "CHECKS (STAND-INS) %d / 3   ·   LOCAL REWARD %d / 1   ·   %02d:%02d" \
			% [checks, found.size() - checks, int(elapsed) / 60,
				int(elapsed) % 60]


func _on_found(id: String) -> void:
	found[id] = true
	var stand_in: CrossingDParts.StandIn = room.stand_ins[id]
	_say("%s found — a stand-in: nothing is sent, nothing is saved."
			% stand_in.title().capitalize())


func _on_exit() -> void:
	if completed:
		return
	completed = true
	_refresh_objective()
	_open_menu(true)


func _physics_process(delta: float) -> void:
	if player == null or get_tree().paused:
		return
	if not completed:
		elapsed += delta
	_gate_tether()
	_track_checkpoint()
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_note.text = ""
	_refresh_objective()


## THE TETHER, COURTYARD ONLY: equipped while the player is inside the
## Courtyard's volume, and taken away -- mid-swing included -- the moment
## they leave it. A swing begun in the Courtyard toward the tower ends at
## the opening.
func _gate_tether() -> void:
	var inside := room.courtyard_box().has_point(player.global_position)
	if inside == tether_on:
		return
	tether_on = inside
	var runtime: EchoRuntime = player.runtimes["echo_a"]
	if inside:
		runtime.set_equipped(TETHER)
	else:
		player.end_swing("echo_a")
		runtime.set_equipped({})
	_tether.text = "SWING TETHER: ON — jump, then hold RMB" if inside \
			else "SWING TETHER: Courtyard only"


func _track_checkpoint() -> void:
	if not player.is_on_floor():
		return
	for spec: Dictionary in CHECKPOINTS:
		if spec["id"] == checkpoint:
			continue
		if (spec["box"] as AABB).has_point(player.global_position):
			checkpoint = spec["id"]
			# The spawn moves; the player does not. `Player._respawn` reads
			# it after a death, and R below reads it on purpose.
			player._spawn_transform = Transform3D(
					Basis(Vector3.UP, float(spec["yaw"])), spec["at"])
			return


func recover() -> void:
	if player._rider != null:
		player._leave_rail()
	player.cancel_transient_effects()
	player.velocity = Vector3.ZERO
	player.set_spawn(player._spawn_transform)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _menu != null and not completed:
			_close_menu()
		elif _menu == null:
			_open_menu(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_R \
			and _menu == null and not completed:
		recover()
		get_viewport().set_input_as_handled()


## PAUSED IN PLACE, through the game's named pause claims (H-PAUSE): the
## world keeps its physics state, so nothing resting on a plate loses its
## overlap while the menu is up.
func _open_menu(finished: bool) -> void:
	if _menu != null:
		_menu.queue_free()
	PauseClaims.claim(get_tree(), MENU_HOLD)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := Panel.new()
	panel.name = "CrossingMenu"
	panel.position = Vector2(300, 140)
	panel.size = Vector2(680, 420)
	_overlay.add_child(panel)
	_menu = panel
	var title := Label.new()
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 26)
	if finished:
		var checks := 0
		for id: String in found:
			if (room.stand_ins[id] as CrossingDParts.StandIn).kind == "check":
				checks += 1
		title.text = "CROSSING COMPLETE   %02d:%02d\nChecks (stand-ins) %d / 3 · local reward %d / 1" \
				% [int(elapsed) / 60, int(elapsed) % 60, checks,
					found.size() - checks]
	else:
		title.text = "CROSSING D — REVIEW BUILD\nPaused"
	panel.add_child(title)
	var legend := Label.new()
	legend.position = Vector2(28, 118)
	legend.add_theme_font_size_override("font_size", 17)
	legend.text = ("Blue: movement · Green: power · Orange: things that break, "
			+ "enemies included\nOffline review build: no bridge, no campaign, "
			+ "nothing saved. Checks are stand-ins.\n"
			+ ("Yard: populated (ranged, melee, charger at baseline numbers)."
				if populated else "Yard: empty (no enemies)."))
	panel.add_child(legend)
	var row := 0
	if not finished:
		_button(panel, "RESUME", row, _close_menu)
		row += 1
	_button(panel, "RESTART THE CROSSING", row, restart)
	row += 1
	_button(panel, "QUIT", row, func() -> void: get_tree().quit())


func _button(panel: Control, text: String, row: int, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = Vector2(28, 232 + row * 58)
	button.size = Vector2(624, 48)
	button.pressed.connect(action)
	panel.add_child(button)


func _close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	PauseClaims.release(get_tree(), MENU_HOLD)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func menu_open() -> bool:
	return _menu != null


## FROM THE TOP: the whole scene again, so nothing of the last run --
## a latched lever, an installed cell, a defeated enemy -- survives it.
func restart() -> void:
	PauseClaims.release(get_tree(), MENU_HOLD)
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	PauseClaims.release(get_tree(), MENU_HOLD)
