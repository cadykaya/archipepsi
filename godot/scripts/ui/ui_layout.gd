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
static func centred(parent: Node, panel: Control) -> Control:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The wrapper fills the screen, so it must not eat clicks meant for
	# the game or for the panel it holds.
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(centre)
	centre.add_child(panel)
	return centre
