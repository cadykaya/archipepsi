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

func _on_cooldown(remaining: float, _total: float) -> void:
	refresh_echo(remaining)

func refresh_echo(cooldown := 0.0) -> void:
	var echo := BridgeClient.equipped_echo()
	if echo.is_empty():
		_echo_label.text = "RMB: no Echo equipped"
		return
	var suffix := ""
	if cooldown > 0.0:
		suffix = "  [%.1f]" % cooldown
	elif echo.get("activation") == "passive":
		suffix = "  (passive)"
	_echo_label.text = "RMB: %s%s" % [echo.get("display_name", "?"), suffix]

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
