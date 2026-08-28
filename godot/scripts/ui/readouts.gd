class_name Readouts
extends Control
## The ten Info readouts (ECHOES §14.1).
##
## An Info component is the one component kind that changes nothing. It
## occupies no slot, costs nothing to use, and is persistent once owned —
## all it does is tell you about a world it never touches. This file is
## built so that promise is structural rather than remembered:
##
## * It reads. Everything it shows comes from the tree, the fold and the
##   player; nothing here assigns to an enemy, a pickup, the resource pool,
##   the campaign or the player. The suite asserts exactly that.
## * It sends no intents. A readout that reported to the bridge would be a
##   second path to campaign truth. `BridgeClient.sent_intents` is how the
##   suite proves it stays silent.
## * It draws only what is OWNED. `active` is derived from the fold on
##   every snapshot, so a readout appears the moment its Echo lands and
##   never because a menu was left switched on.
##
## Everything is one `_draw` over a pooled label set rather than ten node
## trees: ten readouts that each brought a scene would cost more to keep
## consistent than the drawing does.

## The §14.1 catalog, in the order the corner stack shows them. Duplicated
## from the schema deliberately — an unknown readout must be visibly
## unhandled here rather than silently absent.
const READOUTS := ["enemy_health", "enemy_radar", "threat_direction",
		"secret_ping", "affordance_highlight", "trajectory_preview",
		"damage_numbers", "resource_forecast", "speedometer",
		"challenge_timer"]

const _RADAR_RADIUS := 118.0
const _DAMAGE_NUMBER_LIFE := 0.9
const _SECRET_PING_RANGE := 18.0

var player: Player = null
## readout id -> owned. Refreshed from the fold; never set by hand.
var active: Dictionary = {}

var _damage_numbers: Array = []
## enemy instance id -> hp last frame, for `_watch_enemy_health`.
var _last_enemy_hp: Dictionary = {}
var _threat_marks: Array = []
var _speed := 0.0
var _challenge_elapsed := 0.0
var _challenge_best := 0.0
var _challenge_running := false
var _font: Font

func _ready() -> void:
	name = "Readouts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	if BridgeClient != null:
		BridgeClient.snapshot_received.connect(_on_snapshot)
		refresh()

func _on_snapshot(_snapshot: Dictionary) -> void:
	refresh()

## Which readouts the campaign owns, straight from the fold. The client
## does not decide this and cannot toggle it: owning the Echo is the only
## way a readout turns on.
func refresh() -> void:
	var owned: Dictionary = {}
	for entry: Dictionary in BridgeClient.owned_components("info"):
		var readout := str(entry.get("component", {}).get("readout", ""))
		if readout in READOUTS:
			owned[readout] = true
		elif readout != "":
			push_error("readout '%s' is owned but has no display" % readout)
	active = owned
	queue_redraw()

func has(readout: String) -> bool:
	return active.get(readout, false)

## Bind to the things a readout reports on. Connections only — a readout
## observing the player must never be able to steer it.
func bind(player_in: Player) -> void:
	player = player_in
	if player == null:
		return
	if not player.damaged_from.is_connected(_on_damaged_from):
		player.damaged_from.connect(_on_damaged_from)

func _on_damaged_from(source_position: Vector3) -> void:
	_threat_marks.append({"at": source_position, "life": 1.6})

## For a damageable thing that is not an `Enemy` — a Lab fixture, a
## breakable panel. Enemies are watched instead (`_watch_enemy_health`);
## nothing has to remember to call this for them.
func report_damage(at: Vector3, amount: float) -> void:
	if not has("damage_numbers") or amount <= 0.0:
		return
	_damage_numbers.append({
		"at": at, "amount": amount, "life": _DAMAGE_NUMBER_LIFE})

## Damage numbers by observation rather than by notification.
##
## The alternative was a signal from `Enemy` into the HUD, and that is the
## wrong direction: an Info component may never alter the world, and the
## cheapest way to keep that true is for the world not to know this exists.
## Watching hp fall is strictly read-only, and it cannot miss a hit that
## some future damage path forgets to announce.
func _watch_enemy_health() -> void:
	var seen: Dictionary = {}
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var enemy := node as Enemy
		var id := enemy.get_instance_id()
		seen[id] = enemy.hp
		if _last_enemy_hp.has(id):
			var lost := float(_last_enemy_hp[id]) - enemy.hp
			if lost > 0.01:
				report_damage(enemy.global_position, lost)
	# Rebuilt rather than pruned: a dead enemy's id must not linger, or a
	# recycled instance id resurrects its old health as a phantom hit.
	_last_enemy_hp = seen

## An active challenge marker's clock (§14.2). The marker owns the
## challenge; this only shows the time.
##
## **Nothing calls this yet, and that is deliberate.** §14.2 says a
## `challenge_marker` is "an optional timed or scored challenge; records a
## personal best" and §14.1 says the readout shows "elapsed time and best
## on an active challenge marker" — but neither says what the challenge
## IS: where it starts, what ends it, or what counts as a run. Picking one
## would be inventing a mechanic the contract does not describe, so the
## clock is wired and waiting rather than guessed at. `test_stage_tripwires
## .py::test_the_challenge_marker_still_has_no_challenge` is the reminder,
## and names the decision that has to be made first.
##
## The rest of §14.2 works today: a `challenge_marker` reward can be
## granted, is recorded, and `best_seconds` improves monotonically — the
## bridge half is complete and tested. What is missing is the world half.
func set_challenge(running: bool, elapsed: float, best: float) -> void:
	_challenge_running = running
	_challenge_elapsed = elapsed
	_challenge_best = best

func _process(delta: float) -> void:
	if active.is_empty():
		return
	if has("damage_numbers"):
		_watch_enemy_health()
	for entry: Dictionary in _damage_numbers:
		entry["life"] = float(entry["life"]) - delta
	_damage_numbers = _damage_numbers.filter(
			func(e: Dictionary) -> bool: return float(e["life"]) > 0.0)
	for entry: Dictionary in _threat_marks:
		entry["life"] = float(entry["life"]) - delta
	_threat_marks = _threat_marks.filter(
			func(e: Dictionary) -> bool: return float(e["life"]) > 0.0)
	if player != null:
		var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
		_speed = flat.length()
	if _challenge_running:
		_challenge_elapsed += delta
	queue_redraw()

func _draw() -> void:
	if player == null or player.camera == null or active.is_empty():
		return
	var camera := player.camera
	if has("enemy_health"):
		_draw_enemy_health(camera)
	if has("enemy_radar"):
		_draw_enemy_radar(camera)
	if has("threat_direction"):
		_draw_threat_direction(camera)
	if has("secret_ping"):
		_draw_secret_ping()
	if has("affordance_highlight"):
		_draw_affordance_highlight(camera)
	if has("trajectory_preview"):
		_draw_trajectory(camera)
	if has("damage_numbers"):
		_draw_damage_numbers(camera)
	_draw_corner_stack()

## Screen position, and whether the point is in front of the camera at
## all. `unproject_position` happily returns a plausible point for
## something behind you, which put enemy bars on the wrong side of the
## screen until this was split out.
func _project(camera: Camera3D, at: Vector3) -> Dictionary:
	var forward := -camera.global_transform.basis.z
	var to := at - camera.global_position
	if forward.dot(to) <= 0.05:
		return {"ok": false, "at": Vector2.ZERO}
	return {"ok": true, "at": camera.unproject_position(at)}

func _draw_enemy_health(camera: Camera3D) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var enemy := node as Enemy
		# "Over DAMAGED enemies" (§14.1): a bar over a full-health enemy is
		# a wallhack, and this readout is information, not an advantage.
		if enemy.hp >= enemy.max_hp or enemy.max_hp <= 0.0:
			continue
		var projected := _project(camera,
				enemy.global_position + Vector3.UP * 2.1)
		if not projected["ok"]:
			continue
		var at: Vector2 = projected["at"]
		var fraction := clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)
		var box := Rect2(at - Vector2(26, 4), Vector2(52, 5))
		draw_rect(box, Color(0.05, 0.05, 0.08, 0.7))
		draw_rect(Rect2(box.position, Vector2(52.0 * fraction, 5)),
				Color(1.0, 0.45, 0.4).lerp(Color(0.5, 1.0, 0.6), fraction))

func _draw_enemy_radar(camera: Camera3D) -> void:
	var center := size / 2.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Enemy:
			continue
		var enemy := node as Enemy
		var projected := _project(camera, enemy.global_position)
		var on_screen: bool = projected["ok"] \
				and Rect2(Vector2.ZERO, size).has_point(projected["at"])
		# Off-screen only: on-screen enemies are already visible, and a
		# blip over a visible enemy is clutter.
		if on_screen:
			continue
		var to := enemy.global_position - player.global_position
		var angle := _bearing(to)
		var blip := center + Vector2(sin(angle), -cos(angle)) * _RADAR_RADIUS
		draw_circle(blip, 4.0, Color(1.0, 0.55, 0.45, 0.85))

func _draw_threat_direction(_camera: Camera3D) -> void:
	var center := size / 2.0
	for mark: Dictionary in _threat_marks:
		var life := float(mark["life"]) / 1.6
		var angle := _bearing(mark["at"] - player.global_position)
		var at := center + Vector2(sin(angle), -cos(angle)) * (_RADAR_RADIUS + 22.0)
		var away := (at - center).normalized()
		draw_line(at, at + away * 16.0,
				Color(1.0, 0.35, 0.3, clampf(life, 0.0, 1.0)), 3.0)

## The angle to something, relative to where the player is facing. Yaw
## only: a radar that tilted with the camera would spin when you looked up.
func _bearing(to: Vector3) -> float:
	var facing := -player.global_transform.basis.z
	var flat_to := Vector2(to.x, to.z)
	var flat_facing := Vector2(facing.x, facing.z)
	if flat_to.length() < 0.001 or flat_facing.length() < 0.001:
		return 0.0
	return flat_facing.angle_to(flat_to)

func _draw_secret_ping() -> void:
	# "A faint cue near an unfound secret in the CURRENT chamber" — so
	# range-limited, and deliberately directionless. It tells you there is
	# something here, not where; finding it is still the game.
	var nearest := INF
	for node in get_tree().get_nodes_in_group(ChamberBuilders.SECRET_GROUP):
		if node is Node3D:
			nearest = minf(nearest,
					(node as Node3D).global_position.distance_to(
							player.global_position))
	for node in get_tree().get_nodes_in_group(LocalRewardPickup.GROUP):
		if node is Node3D:
			nearest = minf(nearest,
					(node as Node3D).global_position.distance_to(
							player.global_position))
	if nearest > _SECRET_PING_RANGE:
		return
	var strength := 1.0 - nearest / _SECRET_PING_RANGE
	var center := size / 2.0
	draw_arc(center, 150.0, 0.0, TAU, 64,
			Color(0.6, 1.0, 0.85, 0.10 + 0.22 * strength), 2.0)

func _draw_affordance_highlight(camera: Camera3D) -> void:
	for node in get_tree().get_nodes_in_group(AffordanceFeatures.GROUP):
		if not node is Node3D:
			continue
		var projected := _project(camera, (node as Node3D).global_position)
		if not projected["ok"]:
			continue
		var at: Vector2 = projected["at"]
		draw_arc(at, 22.0, 0.0, TAU, 24, Color(0.75, 0.9, 1.0, 0.6), 2.0)
		var tag := str(node.get_meta("affordance_tag", ""))
		if tag != "":
			draw_string(_font, at + Vector2(-30, 38), tag.replace("_", " "),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.75, 0.9, 1.0, 0.7))

func _draw_trajectory(camera: Camera3D) -> void:
	# Only for verbs that actually arc: a straight-line "preview" over a
	# hitscan is a crosshair with extra steps.
	var runtime: EchoRuntime = player.echo_runtime
	if runtime == null:
		return
	var primitive: Dictionary = runtime.primitive()
	var type := str(primitive.get("type", ""))
	if type != "arc_lob" and type != "charge_shot":
		return
	var speed := float(primitive.get("speed", 16.0))
	var gravity_scale := float(primitive.get("gravity_scale", 1.0))
	var at := camera.global_position
	var velocity := -camera.global_transform.basis.z * speed
	var previous := Vector2.ZERO
	var have_previous := false
	for step in 26:
		at += velocity * 0.06
		velocity.y -= Constants.GRAVITY * gravity_scale * 0.06
		var projected := _project(camera, at)
		if not projected["ok"]:
			have_previous = false
			continue
		var point: Vector2 = projected["at"]
		if have_previous:
			draw_line(previous, point,
					Color(0.9, 0.85, 0.5, 0.55 - 0.015 * step), 1.5)
		previous = point
		have_previous = true

func _draw_damage_numbers(camera: Camera3D) -> void:
	for entry: Dictionary in _damage_numbers:
		var life := float(entry["life"]) / _DAMAGE_NUMBER_LIFE
		var rise := (1.0 - life) * 0.9
		var projected := _project(camera,
				(entry["at"] as Vector3) + Vector3.UP * (1.4 + rise))
		if not projected["ok"]:
			continue
		draw_string(_font, projected["at"],
				"%d" % int(round(float(entry["amount"]))),
				HORIZONTAL_ALIGNMENT_CENTER, -1, 18,
				Color(1.0, 0.9, 0.55, clampf(life, 0.0, 1.0)))

## The text readouts, stacked in one corner so they cannot overlap each
## other however many are owned.
func _draw_corner_stack() -> void:
	var lines: Array[String] = []
	if has("speedometer"):
		lines.append("%.1f m/s" % _speed)
	if has("resource_forecast"):
		lines.append(_forecast_line())
	if has("challenge_timer") and _challenge_running:
		var best := "  best %.1fs" % _challenge_best if _challenge_best > 0.0 \
				else ""
		lines.append("%.1fs%s" % [_challenge_elapsed, best])
	var at := Vector2(24.0, size.y - 130.0)
	for line in lines:
		draw_string(_font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color(0.7, 0.9, 1.0, 0.85))
		at.y += 20.0

## Whether the highlighted slot's Action is affordable right now. Reads the
## pool; never spends from it.
func _forecast_line() -> String:
	var runtime: EchoRuntime = player.echo_runtime
	if runtime == null:
		return "-- ready"
	if not runtime.has_action():
		return "-- empty"
	if runtime.cooldown_remaining > 0.0:
		return "%.1fs cooldown" % runtime.cooldown_remaining
	return "ready" if runtime.can_activate() else "cannot afford"
