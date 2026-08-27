class_name ResourceMeters
extends VBoxContainer
## The fifteen pre-laid HUD channels (ECHOES.md §7).
##
## **Godot owns every pixel.** Epsilon activates a channel, names it,
## colours it from the safe palette, picks bar / pips / counter, sets max
## and regen. It never sees a coordinate, and it never chooses which
## channel it gets: assignment is creation order, decided by the fold, so
## the same campaign lays out the same dashboard every time.
##
## All fifteen rows are built once, up front, and stay in the tree. Building
## them on demand would let the dashboard reflow as Echoes arrive, and a bar
## that moves is a bar you have to find again mid-fight.
##
## ## The pressure valve
##
## Fifteen channels available does not mean fifteen bars in your face. A row
## renders full-size when it is *relevant* — changed recently, or not full —
## and otherwise collapses to a thin idle strip, animating back up when it
## becomes relevant again. Fifteen full-size bars is the failure mode this
## exists to prevent.

const CHANNELS := 15
const _FULL_HEIGHT := 15.0
const _IDLE_HEIGHT := 3.0
#: How long after a change a channel stays expanded. Long enough to read the
#: number that changed, short enough that a regenerating meter does not hold
#: the dashboard open for its whole refill.
const _RELEVANT_SECONDS := 2.5

var pool: ResourcePool = null

var _rows: Array[Dictionary] = []
var _recent: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 3)
	for index in CHANNELS:
		_rows.append(_build_row())

func _build_row() -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.visible = false
	add_child(row)

	# Source identity: which world contributed this. Separate from the fill
	# colour on purpose (§7.1) — one economy built by two games shows the
	# second world's glyph without the bar changing hue.
	var glyph := Label.new()
	glyph.custom_minimum_size = Vector2(14, 0)
	glyph.add_theme_font_size_override("font_size", 13)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(glyph)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(86, 0)
	name_label.add_theme_font_size_override("font_size", 12)
	row.add_child(name_label)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(120, _FULL_HEIGHT)
	track.color = Color(0.10, 0.11, 0.13, 0.85)
	row.add_child(track)

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

	# Pips are drawn as gaps cut into the fill rather than as separate
	# nodes: the count changes when the definition is upgraded, and
	# rebuilding child nodes mid-fight is how a bar flickers.
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(pips)

	var value := Label.new()
	value.custom_minimum_size = Vector2(52, 0)
	value.add_theme_font_size_override("font_size", 12)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	return {"row": row, "glyph": glyph, "name": name_label, "track": track,
			"fill": fill, "pips": pips, "value": value, "id": "",
			"height": _IDLE_HEIGHT}

func _process(delta: float) -> void:
	var channels: Array = BridgeClient.resource_channels()
	for index in CHANNELS:
		var entry: Dictionary = _rows[index]
		if index >= channels.size():
			entry["row"].visible = false
			entry["id"] = ""
			continue
		_refresh_row(entry, str(channels[index]), delta)

func _refresh_row(entry: Dictionary, component_id: String,
		delta: float) -> void:
	var owned := BridgeClient.owned_component(component_id)
	var component: Dictionary = owned.get("component", {})
	if component.is_empty():
		entry["row"].visible = false
		return
	entry["row"].visible = true

	if entry["id"] != component_id:
		entry["id"] = component_id
		# A channel that just became someone's is relevant by definition.
		_recent[component_id] = _RELEVANT_SECONDS

	var maximum := float(component.get("max_value", 0.0))
	var current := maximum
	if pool != null:
		current = pool.value_of(component_id)
	var fraction := 0.0 if maximum <= 0.0 \
			else clampf(current / maximum, 0.0, 1.0)

	var previous := float(entry.get("last_fraction", -1.0))
	if previous >= 0.0 and not is_equal_approx(previous, fraction):
		_recent[component_id] = _RELEVANT_SECONDS
	entry["last_fraction"] = fraction

	# Relevance, in the order §7 gives it: recently changed, a cost of a
	# slotted action, or not full. HP is elsewhere and always full-size.
	if _recent.has(component_id):
		_recent[component_id] = float(_recent[component_id]) - delta
		if float(_recent[component_id]) <= 0.0:
			_recent.erase(component_id)
	var relevant := _recent.has(component_id) or fraction < 0.999 \
			or _is_cost_of_slotted_action(component_id)

	# Animated rather than snapped, so a channel becoming relevant reads as
	# the dashboard opening up instead of as a layout glitch.
	var target := _FULL_HEIGHT if relevant else _IDLE_HEIGHT
	entry["height"] = move_toward(float(entry["height"]), target,
			delta * 60.0)
	var height := float(entry["height"])
	entry["track"].custom_minimum_size = Vector2(120, height)
	entry["track"].size.y = height

	var expanded := height > (_IDLE_HEIGHT + _FULL_HEIGHT) / 2.0
	entry["name"].visible = expanded
	entry["value"].visible = expanded
	entry["glyph"].visible = expanded

	var palette := str(component.get("palette_color", "bone"))
	entry["fill"].color = ResourcePalette.fill(palette)
	entry["track"].color = Color(ResourcePalette.dim(palette), 0.55)
	entry["fill"].position = Vector2.ZERO
	entry["fill"].size = Vector2(entry["track"].size.x * fraction, height)

	var game := BridgeClient.component_source_game(component_id)
	entry["glyph"].text = ResourcePalette.source_glyph(game)
	entry["glyph"].modulate = ThemeMaterials.color_for_game(game) \
			if not game.is_empty() else Color(0.7, 0.7, 0.7)

	var mk := int(owned.get("mk", 1))
	var label := str(component.get("display_name", "?"))
	entry["name"].text = "%s  Mk %d" % [label, mk] if mk > 1 else label
	entry["name"].modulate = ResourcePalette.fill(palette)

	_draw_presentation(entry, component, fraction, height)

func _draw_presentation(entry: Dictionary, component: Dictionary,
		fraction: float, height: float) -> void:
	var presentation := str(component.get("presentation", "bar"))
	var maximum := float(component.get("max_value", 0.0))
	var pips: HBoxContainer = entry["pips"]
	match presentation:
		"counter":
			pips.visible = false
			# A counter is a number, so the bar behind it would be a second
			# reading of the same fact competing with it.
			entry["fill"].size = Vector2(0, 0)
			entry["value"].text = "%d" % roundi(maximum * fraction)
		"pips":
			pips.visible = true
			pips.size = entry["track"].size
			var count := maxi(1, int(component.get("pip_count", 1)))
			_ensure_pips(pips, count, height)
			var lit := fraction * float(count)
			for i in count:
				var pip: ColorRect = pips.get_child(i)
				# Partial credit on the leading pip: a pips meter that only
				# ever showed whole units would look stuck while it filled.
				var share := clampf(lit - float(i), 0.0, 1.0)
				pip.color = Color(ResourcePalette.fill(
						str(component.get("palette_color", "bone"))),
						0.25 + 0.75 * share)
			entry["fill"].size = Vector2(0, 0)
			entry["value"].text = "%d/%d" % [floori(lit), count]
		_:
			pips.visible = false
			entry["value"].text = "%d" % roundi(maximum * fraction)

func _ensure_pips(pips: HBoxContainer, count: int, height: float) -> void:
	while pips.get_child_count() < count:
		var pip := ColorRect.new()
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.add_child(pip)
	for i in pips.get_child_count():
		var pip: ColorRect = pips.get_child(i)
		pip.visible = i < count
		pip.custom_minimum_size = Vector2(0, height)

## Whether a slotted Action pays this resource. Nothing answers yes in S3 —
## costs are rules (S4) and `powers`/`fills` links are S5 — so this reads
## the links the fold already carries and will start answering on its own
## once they exist, rather than needing to be remembered later.
func _is_cost_of_slotted_action(component_id: String) -> bool:
	var slotted: Array = []
	for slot: String in ["echo_a", "echo_b", "mobility", "utility"]:
		var id: Variant = BridgeClient.slots().get(slot)
		if id != null:
			slotted.append(str(id))
	if slotted.is_empty():
		return false
	for link: Dictionary in BridgeClient.mechanics().get("links", []):
		if str(link.get("kind", "")) not in ["powers", "fills"]:
			continue
		if str(link.get("source", "")) in slotted \
				and str(link.get("target", "")) == component_id:
			return true
	return false
