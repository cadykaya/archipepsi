class_name Hud
extends CanvasLayer
## Crosshair, HP/shield, equipped Echo + cooldown, interact prompt, toasts.

var _hp_label: Label
var _echo_label: Label
var _prompt_label: Label
var _toast_box: VBoxContainer
var _crosshair: Label

var _damage_flash: ColorRect
var _last_hp := -1.0
var _banner: Label
var _death_overlay: ColorRect
var _death_label: Label

## Objective navigation. Zones bend, so "forward" is not a direction the
## player can assume any more — the waypoint is what replaces that.
var _objective_label: Label
var _waypoint: Label
var _waypoint_target := Vector3.ZERO
var _waypoint_text := ""
var _waypoint_active := false
var _waypoint_color := Color(0.45, 1.0, 0.9)

const _EDGE_MARGIN := 46.0
#: Chevrons by octant, starting east and going clockwise on screen.
const _ARROWS := ["▶", "◢", "▼", "◣", "◀", "◤", "▲", "◥"]

## Damage direction wedge: which way to turn to see what just hit you.
var _hit_marker: Label
var _hit_fade := 0.0
const _HIT_FADE_TIME := 1.1
const _HIT_RADIUS := 96.0

## Echo cooldown, as a bar rather than a number.
var _cooldown_track: ColorRect
var _cooldown_fill: ColorRect

func _ready() -> void:
	layer = 5
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.1, 0.05, 0.0)
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override("font_size", 22)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_crosshair)

	var bottom_left := VBoxContainer.new()
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.position = Vector2(18, -90)
	bottom_left.offset_top = -100.0
	bottom_left.offset_left = 18.0
	add_child(bottom_left)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 26)
	bottom_left.add_child(_hp_label)
	_echo_label = Label.new()
	_echo_label.add_theme_font_size_override("font_size", 18)
	_echo_label.modulate = Color(0.7, 0.95, 0.9)
	bottom_left.add_child(_echo_label)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_top = -140.0
	_prompt_label.offset_left = -300.0
	_prompt_label.offset_right = 300.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.modulate = Color(1.0, 0.95, 0.7)
	add_child(_prompt_label)

	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_box.offset_left = -420.0
	_toast_box.offset_top = 14.0
	_toast_box.offset_right = -14.0
	add_child(_toast_box)

	# Zone progress, top centre, above the waypoint.
	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_label.offset_top = 44.0
	_objective_label.offset_left = -320.0
	_objective_label.offset_right = 320.0
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.modulate = Color(0.62, 0.72, 0.78)
	add_child(_objective_label)

	# The waypoint marker itself: floats over the target when it is on
	# screen, pins to the screen edge as a chevron when it is not.
	_waypoint = Label.new()
	_waypoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waypoint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_waypoint.add_theme_font_size_override("font_size", 20)
	_waypoint.custom_minimum_size = Vector2(160, 28)
	_waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waypoint.visible = false
	add_child(_waypoint)

	_hit_marker = Label.new()
	_hit_marker.text = "▲"
	_hit_marker.add_theme_font_size_override("font_size", 34)
	_hit_marker.custom_minimum_size = Vector2(40, 40)
	_hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hit_marker.pivot_offset = Vector2(20, 20)
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_marker.visible = false
	add_child(_hit_marker)

	# Cooldown bar, tucked under the Echo line.
	_cooldown_track = ColorRect.new()
	_cooldown_track.color = Color(0.12, 0.15, 0.17, 0.85)
	_cooldown_track.custom_minimum_size = Vector2(190, 6)
	_cooldown_track.size = Vector2(190, 6)
	_cooldown_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_track.visible = false
	bottom_left.add_child(_cooldown_track)
	_cooldown_fill = ColorRect.new()
	_cooldown_fill.color = Color(0.45, 0.95, 0.9)
	_cooldown_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_track.add_child(_cooldown_fill)

	# Persistent connectivity banner (§9.1): shown while the bridge or
	# Archipelago is down, distinct from one-shot toasts.
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 10.0
	_banner.offset_left = -320.0
	_banner.offset_right = 320.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.modulate = Color(1.0, 0.45, 0.4)
	add_child(_banner)

	# Death overlay: SIGNAL LOST while waiting to respawn.
	_death_overlay = ColorRect.new()
	_death_overlay.color = Color(0.02, 0.0, 0.04, 0.0)
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.visible = false
	add_child(_death_overlay)
	_death_label = Label.new()
	_death_label.text = "SIGNAL LOST"
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 52)
	_death_label.modulate = Color(1.0, 0.3, 0.5)
	_death_label.visible = false
	add_child(_death_label)

func set_banner(text: String) -> void:
	_banner.text = text

## Zone progress line, e.g. "CHECKS 1/3 CLAIMED". Empty clears it.
func set_objective_text(text: String) -> void:
	_objective_label.text = text

## Point the waypoint at a world position. `clear_waypoint()` hides it.
func set_waypoint(target: Vector3, text: String, color: Color) -> void:
	_waypoint_target = target
	_waypoint_text = text
	_waypoint_color = color
	_waypoint_active = true

func clear_waypoint() -> void:
	_waypoint_active = false
	_waypoint.visible = false

func _process(delta: float) -> void:
	if _hit_fade > 0.0:
		_hit_fade = maxf(0.0, _hit_fade - delta)
		var strength := _hit_fade / _HIT_FADE_TIME
		_hit_marker.modulate = Color(1.0, 0.35, 0.3, strength)
		_hit_marker.visible = _hit_fade > 0.0 and _crosshair.visible
	if not _waypoint_active or not _crosshair.visible:
		_waypoint.visible = false
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_waypoint.visible = false
		return

	var size := Vector2(get_viewport().get_visible_rect().size)
	var centre := size / 2.0
	var behind := camera.is_position_behind(_waypoint_target)
	var point := camera.unproject_position(_waypoint_target)
	if behind:
		# unproject mirrors points behind the camera; flip them back so the
		# chevron points the way the player must actually turn.
		point = centre - (point - centre)

	var distance := camera.global_position.distance_to(_waypoint_target)
	var margin := Vector2(_EDGE_MARGIN, _EDGE_MARGIN)
	var clamped := point.clamp(margin, size - margin)
	var off_screen := behind or not clamped.is_equal_approx(point)

	if off_screen:
		# Pin to the screen edge along the direction of travel.
		var direction := (point - centre)
		if direction.length() < 0.001:
			direction = Vector2.DOWN
		direction = direction.normalized()
		var half := size / 2.0 - margin
		var scale_x := half.x / absf(direction.x) if absf(direction.x) > 0.001 \
				else INF
		var scale_y := half.y / absf(direction.y) if absf(direction.y) > 0.001 \
				else INF
		clamped = centre + direction * minf(scale_x, scale_y)
		var octant := int(round(direction.angle() / (PI / 4.0))) & 7
		_waypoint.text = "%s %s  %dm" % [_ARROWS[octant], _waypoint_text,
				int(distance)]
	else:
		_waypoint.text = "◆ %s  %dm" % [_waypoint_text, int(distance)]

	_waypoint.position = clamped - _waypoint.size / 2.0
	_waypoint.modulate = _waypoint_color
	_waypoint.visible = true

func _on_player_died() -> void:
	_death_overlay.visible = true
	_death_label.visible = true
	_death_overlay.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_death_overlay, "color:a", 0.75,
			Constants.RESPAWN_DELAY * 0.6)

func bind_player(player: Player) -> void:
	player.hp_changed.connect(_on_hp_changed)
	player.interact_prompt_changed.connect(_on_prompt)
	player.echo_runtime.cooldown_changed.connect(_on_cooldown)
	player.died.connect(_on_player_died)
	player.damaged_from.connect(_on_damaged_from)
	_hit_fade = 0.0
	_hit_marker.visible = false
	_last_hp = -1.0
	_death_overlay.visible = false
	_death_label.visible = false
	_on_hp_changed(player.hp, player.echo_runtime.shield_hp)
	refresh_echo()

func _on_hp_changed(hp: float, shield: float) -> void:
	var text := "HP %d" % int(hp)
	if shield > 0.0:
		text += "  +%d SHIELD" % int(shield)
	_hp_label.text = text
	if _last_hp >= 0.0 and hp < _last_hp:
		_damage_flash.color.a = 0.35
		var tween := create_tween()
		tween.tween_property(_damage_flash, "color:a", 0.0, 0.35)
	if hp > 0.0 and _death_overlay.visible:
		_death_overlay.visible = false      # respawned
		_death_label.visible = false
	_last_hp = hp

func _on_prompt(text: String) -> void:
	_prompt_label.text = text

func _on_cooldown(remaining: float, total: float) -> void:
	refresh_echo(remaining, total)

## Which way to turn: a wedge in a ring around the crosshair, pointing at
## whatever just hit you.
func _on_damaged_from(source_position: Vector3) -> void:
	if source_position == Vector3.INF:
		return                       # a fall, a pit — no direction to give
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var basis := camera.global_transform.basis
	var to_source := source_position - camera.global_position
	# Project into the camera's own plane: x right, y "ahead" on screen.
	var right := basis.x.dot(to_source)
	var ahead := -basis.z.dot(to_source)
	if absf(right) < 0.001 and absf(ahead) < 0.001:
		return
	# Screen angle measured from straight up, clockwise.
	var angle := atan2(right, ahead)
	var size := Vector2(get_viewport().get_visible_rect().size)
	_hit_marker.position = size / 2.0 - _hit_marker.pivot_offset \
			+ Vector2(sin(angle), -cos(angle)) * _HIT_RADIUS
	_hit_marker.rotation = angle
	_hit_fade = _HIT_FADE_TIME
	_hit_marker.visible = true

func refresh_echo(cooldown := 0.0, total := 0.0) -> void:
	var echo := BridgeClient.equipped_echo()
	if echo.is_empty():
		_echo_label.text = "RMB: no Echo equipped"
		_cooldown_track.visible = false
		return
	var suffix := ""
	if echo.get("activation") == "passive":
		suffix = "  (passive)"
	_echo_label.text = "RMB: %s%s" % [echo.get("display_name", "?"), suffix]

	# The bar fills back up as the Echo comes off cooldown; full and green
	# means "ready", which reads at a glance where a number did not.
	var window: float = total if total > 0.0 \
			else float(echo.get("cooldown", 0.0))
	if echo.get("activation") == "passive" or window <= 0.0:
		_cooldown_track.visible = false
		return
	_cooldown_track.visible = true
	var ready := 1.0 - clampf(cooldown / window, 0.0, 1.0)
	_cooldown_fill.size = Vector2(_cooldown_track.size.x * ready,
			_cooldown_track.size.y)
	_cooldown_fill.color = Color(0.45, 0.95, 0.9) if ready >= 1.0 \
			else Color(0.85, 0.7, 0.3)

func toast(text: String, color := Color.WHITE, seconds := 3.5) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 17)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_box.add_child(label)
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(label.queue_free)

func set_crosshair_visible(value: bool) -> void:
	_crosshair.visible = value
	_prompt_label.visible = value
