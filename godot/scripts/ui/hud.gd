class_name Hud
extends CanvasLayer
## Crosshair, HP/shield, equipped Echo + cooldown, interact prompt, toasts.

var _hp_label: Label
var _echo_label: Label
## The fifteen pre-laid resource channels (ECHOES.md 7).
var meters: ResourceMeters
var _prompt_label: Label
var _toast_box: VBoxContainer
var _crosshair: Label

var _damage_flash: ColorRect
var _last_hp := -1.0
var _bound_player: Player = null
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
var _hit_source := Vector3.INF
const _HIT_FADE_TIME := 1.1
const _HIT_RADIUS := 96.0

## Hit confirmation. Everything else on screen tells you what the world is
## doing to you; this is the one that tells you your shot landed. A connect
## tints and punches the crosshair; a kill also stamps an X over it.
var _confirm_mark: Label
var _kill_fade := 0.0
var _connect_fade := 0.0
const _CONFIRM_TIME := 0.20
#: Both aim-point marks share one box, so both centre on the same pixel.
const _MARK_SIZE := Vector2(44, 44)
const _KILL_TIME := 0.45

## Epsilon talking over your shoulder. Its own line, below the interact
## prompt, so a bark never displaces a "HOLD E" the player needs to read.
var _voice_label: Label
var _voice: EpsilonVoice = EpsilonVoice.new()
var _voice_fade := 0.0
## HP fraction that counts as being in trouble, and the fraction you have
## to climb back above before it counts again — without the gap, hovering
## on the threshold makes Epsilon comment on every stray pellet.
const _HURT_AT := 0.35
const _HURT_CLEAR := 0.6
var _hurt_spoken := false

## Echo cooldown, as a bar rather than a number.
var _cooldown_track: ColorRect
var _cooldown_fill: ColorRect

## Zone title card: Epsilon presenting the thing it just built for you.
## Unlike the reveal it never freezes input — you can walk while it fades.
var _title_box: VBoxContainer
var _title_index: Label
var _title_name: Label
var _title_note: Label

func _ready() -> void:
	layer = 5
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.1, 0.05, 0.0)
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)
	# Positioned by hand, not by PRESET_CENTER: that preset is applied when
	# the label still has zero size, so its offsets stay 0 and the label's
	# top-left CORNER lands on the aim point rather than its centre. The
	# cross sat half a glyph off the thing it points at, and scaling it
	# grew about a pivot that was off by the same amount.
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override("font_size", 22)
	_crosshair.custom_minimum_size = _MARK_SIZE
	_crosshair.size = _MARK_SIZE
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.pivot_offset = _MARK_SIZE / 2.0
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	# Positioned by hand each frame like the damage wedge, rather than by an
	# anchor preset, so swapping its glyph can never nudge the crosshair the
	# player is aiming with.
	_confirm_mark = Label.new()
	_confirm_mark.text = "✕"
	_confirm_mark.add_theme_font_size_override("font_size", 30)
	_confirm_mark.custom_minimum_size = _MARK_SIZE
	_confirm_mark.size = _MARK_SIZE
	_confirm_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_mark.pivot_offset = _MARK_SIZE / 2.0
	_confirm_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_mark.visible = false
	add_child(_confirm_mark)

	var bottom_left := VBoxContainer.new()
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.position = Vector2(18, -90)
	bottom_left.offset_top = -100.0
	bottom_left.offset_left = 18.0
	add_child(bottom_left)

	# The fifteen channels sit ABOVE hp and the Echo label, in their own
	# container, and grow upward. Putting them below would let a newly
	# granted Resource push the two readings you actually need under
	# pressure -- health and which Echo is bound -- to a different place on
	# the screen mid-fight.
	meters = ResourceMeters.new()
	meters.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	meters.offset_left = 18.0
	meters.offset_top = -420.0
	meters.offset_bottom = -104.0
	meters.alignment = BoxContainer.ALIGNMENT_END
	add_child(meters)

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

	_voice_label = Label.new()
	_voice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_voice_label.offset_top = -108.0
	_voice_label.offset_left = -420.0
	_voice_label.offset_right = 420.0
	_voice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voice_label.add_theme_font_size_override("font_size", 19)
	_voice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_label.modulate = Color(0.62, 0.95, 0.88, 0.0)
	add_child(_voice_label)

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

	_title_box = VBoxContainer.new()
	_title_box.set_anchors_preset(Control.PRESET_CENTER)
	_title_box.offset_left = -420.0
	_title_box.offset_right = 420.0
	_title_box.offset_top = -60.0
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.modulate.a = 0.0
	add_child(_title_box)
	_title_index = Label.new()
	_title_index.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_index.add_theme_font_size_override("font_size", 17)
	_title_index.modulate = Color(0.6, 0.68, 0.75)
	_title_box.add_child(_title_index)
	_title_name = Label.new()
	_title_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_name.add_theme_font_size_override("font_size", 34)
	_title_box.add_child(_title_name)
	_title_note = Label.new()
	_title_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_note.add_theme_font_size_override("font_size", 16)
	_title_note.modulate = Color(0.68, 0.72, 0.66)
	_title_box.add_child(_title_note)

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

## Present a Zone on entry: index, name, and Epsilon's note about it.
## Fades in, holds, fades out; never takes input away from the player.
func show_zone_title(index_text: String, zone_name: String,
		note: String, accent: Color) -> void:
	_title_index.text = index_text
	_title_name.text = zone_name
	_title_name.modulate = accent
	_title_note.text = "“%s”" % note if note != "" else ""
	_title_box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_title_box, "modulate:a", 1.0, 0.45)
	tween.tween_interval(2.6)
	tween.tween_property(_title_box, "modulate:a", 0.0, 0.9)

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

## Tracks the charge across frames so the bar can be handed BACK to the
## cooldown on the frame a charge ends. Without the edge, releasing early
## leaves the bar frozen at whatever the charge reached.
var _was_charging := false

func _process(delta: float) -> void:
	_centre_aim_marks()
	# A charge advances every frame, but `cooldown_changed` stops firing the
	# moment the cooldown itself is spent — and charge_time can outlast it.
	# So the charge bar needs a tick of its own.
	var charging := _bound_player != null \
			and _bound_player.echo_runtime.charge_ratio() > 0.0
	if charging or _was_charging:
		refresh_echo()
	_was_charging = charging
	_animate_confirmation(delta)
	_animate_voice(delta)
	if _hit_fade > 0.0:
		_hit_fade = maxf(0.0, _hit_fade - delta)
		var strength := _hit_fade / _HIT_FADE_TIME
		_hit_marker.modulate = Color(1.0, 0.35, 0.3, strength)
		if _hit_fade > 0.0:
			_place_hit_marker()      # track as the player turns
		else:
			_hit_marker.visible = false
			_hit_source = Vector3.INF
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
	# The pin must clear half the LAID-OUT label, not a fixed 46px, or a
	# long string like "◀ CHECK 003 · SENDING  27m" hangs off the edge —
	# which is exactly the case the edge indicator exists for.
	var half_label := _waypoint.size / 2.0
	var margin := Vector2(maxf(_EDGE_MARGIN, half_label.x + 8.0),
			maxf(_EDGE_MARGIN, half_label.y + 8.0))
	margin = margin.min(size / 2.0 - Vector2.ONE)
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

## Ask Epsilon to remark on something. It decides whether the moment is
## worth a line — callers name the event and never carry their own throttle.
func say_line(kind: String) -> void:
	var line := _voice.line_for(kind)
	if line.is_empty():
		return
	_voice_label.text = "EPSILON:  " + line
	_voice_fade = EpsilonVoice.DWELL

## Between Zones: drop the throttle so the next Zone's first line is not
## swallowed by the tail of the last one's cooldown, and clear the label so
## a stale remark never hangs over a loading screen.
func reset_voice() -> void:
	_voice.reset()
	_voice_fade = 0.0
	_voice_label.modulate.a = 0.0
	_hurt_spoken = false

func _animate_voice(delta: float) -> void:
	_voice.tick(delta)
	if _voice_fade <= 0.0:
		return
	_voice_fade = maxf(0.0, _voice_fade - delta)
	# Holds solid, then fades over the last second, so a line is never
	# dimming while it is still the newest thing said.
	_voice_label.modulate.a = minf(1.0, _voice_fade)

## One of our shots landed. The two timers are independent on purpose: a
## single shared one that a kill "won" latched, because auto-fire refreshed
## it every 0.35 s with plain connects and it never decayed far enough to
## be re-evaluated — so killing one enemy and then holding the trigger on
## the next left the X stamped for the whole fight.
func _on_hit_confirmed(killed: bool) -> void:
	if killed:
		_kill_fade = _KILL_TIME
	else:
		_connect_fade = _CONFIRM_TIME

func _animate_confirmation(delta: float) -> void:
	if _kill_fade <= 0.0 and _connect_fade <= 0.0:
		return
	_kill_fade = maxf(0.0, _kill_fade - delta)
	_connect_fade = maxf(0.0, _connect_fade - delta)
	# A kill outranks a plain connect while it lasts, but only while it
	# lasts — connects can no longer hold it open.
	var killing := _kill_fade > 0.0
	var strength := _kill_fade / _KILL_TIME if killing \
			else _connect_fade / _CONFIRM_TIME
	if strength <= 0.0 or not _crosshair.visible:
		_reset_confirmation()
		return
	_crosshair.scale = Vector2.ONE * (1.0 + 0.45 * strength)
	_crosshair.modulate = Color.WHITE.lerp(
			Color(1.0, 0.55, 0.25) if killing else Color(0.5, 1.0, 0.8),
			strength)
	_confirm_mark.visible = killing
	if killing:
		_confirm_mark.scale = Vector2.ONE * (1.0 + 0.7 * strength)
		_confirm_mark.modulate = Color(1.0, 0.6, 0.3, minf(1.0, strength * 1.6))

## Both marks sit on the aim point, recomputed each frame so a resolution
## change cannot leave either of them pointing at where the centre was.
func _centre_aim_marks() -> void:
	var centre := Vector2(get_viewport().get_visible_rect().size) / 2.0 \
			- _MARK_SIZE / 2.0
	_crosshair.position = centre
	_confirm_mark.position = centre

func _reset_confirmation() -> void:
	_kill_fade = 0.0
	_connect_fade = 0.0
	_crosshair.scale = Vector2.ONE
	_crosshair.modulate = Color.WHITE
	_confirm_mark.visible = false

func _on_player_died() -> void:
	say_line("died")
	_death_overlay.visible = true
	_death_label.visible = true
	_death_overlay.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_death_overlay, "color:a", 0.75,
			Constants.RESPAWN_DELAY * 0.6)

func bind_player(player: Player) -> void:
	_bound_player = player
	player.hp_changed.connect(_on_hp_changed)
	player.interact_prompt_changed.connect(_on_prompt)
	# Every slot's runtime reports; `_on_cooldown` keeps the bar on the
	# highlighted one. Connecting only the highlighted runtime would go
	# stale the moment the player fired a different slot.
	for runtime: EchoRuntime in player.runtimes.values():
		runtime.cooldown_changed.connect(_on_cooldown)
	player.died.connect(_on_player_died)
	player.damaged_from.connect(_on_damaged_from)
	player.hit_confirmed.connect(_on_hit_confirmed)
	_hit_fade = 0.0
	_hit_marker.visible = false
	_reset_confirmation()
	_last_hp = -1.0
	_death_overlay.visible = false
	_death_label.visible = false
	_on_hp_changed(player.hp, player.total_shield())
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
		say_line("revived")
	var fraction := hp / Constants.PLAYER_MAX_HP
	if fraction >= _HURT_CLEAR:
		_hurt_spoken = false
	elif fraction > 0.0 and fraction < _HURT_AT and not _hurt_spoken:
		_hurt_spoken = true
		say_line("hurt")
	_last_hp = hp

func _on_prompt(text: String) -> void:
	_prompt_label.text = text

## Four runtimes report here; the bar belongs to the highlighted slot, so
## a cooldown ticking on an unwatched slot must not repaint it. Passing a
## negative cooldown means "ask the highlighted runtime", which is exactly
## what the loadout rows want anyway.
func _on_cooldown(_remaining: float, _total: float) -> void:
	refresh_echo()

## Which way to turn: a wedge in a ring around the crosshair, pointing at
## whatever just hit you.
func _on_damaged_from(source_position: Vector3) -> void:
	if source_position == Vector3.INF:
		return                       # a fall, a pit — no direction to give
	_hit_source = source_position
	_hit_fade = _HIT_FADE_TIME
	_place_hit_marker()

## Recomputed every frame while visible: an indicator that told you to turn
## left and then kept pointing left as you turned would steer you past the
## thing that shot you.
func _place_hit_marker() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _hit_source == Vector3.INF:
		_hit_marker.visible = false
		return
	var basis := camera.global_transform.basis
	var to_source := _hit_source - camera.global_position
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
	_hit_marker.visible = _crosshair.visible

#: ECHOES §9's control grammar, as the player reads it. Not derived from
#: the input map: this is what the KEYCAP says, and "MMB" is shorter than
#: what Godot calls that button.
const SLOT_KEYCAPS := {"echo_a": "RMB", "echo_b": "MMB", "mobility": "SHIFT",
		"utility": "C"}

## All four slots at once (S7). One line each, the highlighted one marked:
## a loadout you cannot see is a loadout you do not use, and three of the
## four buttons were invisible before this.
func _loadout_text(highlighted: String) -> String:
	var rows: PackedStringArray = []
	for slot: String in Constants.SLOT_NAMES:
		var action := BridgeClient.slotted_action(slot)
		var mark := "▸" if slot == highlighted else " "
		var keycap: String = SLOT_KEYCAPS.get(slot, "?")
		if action.is_empty():
			rows.append("%s %-5s —" % [mark, keycap])
			continue
		# A component upgraded more than once earns its mark. Mk I is the
		# default and says nothing, because everything starts there.
		var mk := int(BridgeClient.owned_component(
				str(action.get("component_id", ""))).get("mk", 1))
		rows.append("%s %-5s %s%s" % [mark, keycap,
				action.get("display_name", "?"),
				"  Mk %d" % mk if mk > 1 else ""])
	return "\n".join(rows)

## `cooldown < 0` means "ask the runtime" — a plain default of 0.0 made
## every snapshot repaint the bar as fully ready mid-cooldown.
func refresh_echo(cooldown := -1.0, total := 0.0) -> void:
	var slot := _bound_player.highlighted_slot if _bound_player != null \
			else "echo_a"
	if cooldown < 0.0:
		cooldown = _bound_player.echo_runtime.cooldown_remaining \
				if _bound_player != null else 0.0
	_echo_label.text = _loadout_text(slot)
	var echo := BridgeClient.slotted_action(slot)
	if echo.is_empty():
		_cooldown_track.visible = false
		return

	# The bar fills back up as the Echo comes off cooldown; full and green
	# means "ready", which reads at a glance where a number did not.
	var window: float = total if total > 0.0 \
			else float(echo.get("cooldown", 0.0))
	if window <= 0.0:
		_cooldown_track.visible = false
		return
	_cooldown_track.visible = true

	# A charge_shot in the middle of charging takes the bar over. The
	# cooldown is not the interesting number while you are holding the key
	# down -- the charge is -- and a charge you cannot see the state of is a
	# charge you cannot time. Full and white means "let go now".
	var charge := 0.0
	if _bound_player != null:
		charge = _bound_player.echo_runtime.charge_ratio()
	if charge > 0.0:
		_cooldown_fill.size = Vector2(_cooldown_track.size.x * charge,
				_cooldown_track.size.y)
		_cooldown_fill.color = Color(1.0, 0.95, 0.75) if charge >= 1.0 \
				else Color(0.6, 0.8, 1.0)
		return

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
