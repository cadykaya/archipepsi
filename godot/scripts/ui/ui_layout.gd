class_name UILayout
## The one way to put a panel in the middle of the screen.
##
## `set_anchors_preset(PRESET_CENTER)` does NOT centre a control. It moves
## the anchors to the middle and leaves the offsets at zero, so the
## control's TOP-LEFT CORNER lands dead centre and it grows down and
## right. Centring needs the matching `-size / 2` offsets, which the
## preset does not supply.
##
## That reads as a centred panel in code and ships as a panel wedged into
## the bottom-right quadrant. It shipped six times: the title screen,
## the pause menu, the shop, the Echo archive, the reveal card and two
## HUD boxes. Playtest 1 hit every one of them.
##
## A CenterContainer is used rather than the offset form
## (`PRESET_MODE_KEEP_SIZE`) because it re-centres when the window is
## resized; the offset form is computed once, from whatever the size
## happened to be at `_ready`.
## An OPAQUE panel to read text on.
##
## Godot's default `PanelContainer` theme is translucent, so a panel that
## does not say otherwise has the game showing through its own text. It
## reads as a bug on a bright wall and as merely ugly on a dark one,
## which is why it survived: it looks deliberate half the time.
##
## Only `reveal.gd` ever set a background of its own. The Echo archive
## and the shop -- the two panels you actually read, both full of small
## grey text -- did not. Same shape as `centred` above: one wrong default
## copied into every panel that needed the right one.
##
## `reveal.gd` keeps its own style deliberately; its border is tinted per
## recipient game and is doing work this cannot do.
static func reading_panel(minimum: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.06, 0.08, 0.97)
	frame.set_border_width_all(2)
	frame.border_color = Color(0.24, 0.30, 0.36)
	frame.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", frame)
	return panel


## A scroll region that can only scroll DOWN.
##
## A ScrollContainer whose content is wider than itself grows a
## horizontal scrollbar and hands the mouse wheel to it, so the wheel
## pans sideways and the list cannot be scrolled at all. Disabling the
## horizontal axis makes the width a constraint the content has to obey
## rather than a suggestion it can exceed -- which is what makes the
## labels inside wrap.
static func reading_scroll(minimum: Vector2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = minimum
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


static func centred(parent: Node, panel: Control) -> Control:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The wrapper fills the screen, so it must not eat clicks meant for
	# the game or for the panel it holds.
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(centre)
	centre.add_child(panel)
	return centre
