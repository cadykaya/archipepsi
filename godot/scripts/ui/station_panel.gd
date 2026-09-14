class_name StationPanel
extends CanvasLayer
## THE STATION ASKS WHERE YOU WANT TO GO.
##
## §30.12.4's travel is unchanged: a player may warp between stations
## **already reached within the same Zone**, and nothing here reaches,
## repairs or reveals one. What changed is the interaction. Pressing E
## on a working station used to warp you instantly to whichever reached
## station came next in build order -- so travel was a cycle you had to
## learn by riding it, and the owner's note after the playtest was that
## the stations "should really have a menu popup instead of just warping
## me instantly".
##
## WHAT IT WILL NOT DO.
##
## It never lists a station the player has not reached: an unreached
## station is not a destination and naming one would hand out the shape
## of a Zone they have not walked. The station they are standing at IS
## listed, because a menu that silently omits where you are reads as a
## bug -- but it is not selectable, and choosing nothing is the default.
##
## SAVE IS NOT A BUTTON HERE, and that is a finding rather than an
## omission. The owner asked for a save option; the path was traced, and
## the campaign is ALREADY written to disk when a station is reached --
## `station_reached` goes to `CampaignEngine.handle_progress`, which
## commits through `store.write_save`. There is no second, distinct
## "save now" operation to wire, and inventing one would mean inventing
## a save slot. So the panel SAYS what is true instead: progress is
## already saved. A button that did nothing would be worse than no
## button.

signal warp_chosen(from_id: String, to_id: String)
signal return_to_hub_chosen
signal closed

var _list: VBoxContainer
var _title: Label
var _here := ""
## Latched the moment a choice is made, so a double click, a queued
## input and a stale button press cannot send two warps.
var _decided := false

func _ready() -> void:
	layer = 8
	visible = false
	var panel := UILayout.reading_panel(Vector2(560, 420))
	UILayout.centred(self, panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.modulate = Color(0.45, 1.0, 0.8)
	box.add_child(_title)
	var scroll := UILayout.reading_scroll(Vector2(520, 250))
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var hint := Label.new()
	hint.text = ("Your progress is already saved -- reaching a station "
			+ "writes it.\n[Esc] leave without travelling")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.6, 0.65, 0.7)
	box.add_child(hint)

## `destinations` is a list of `{id, label, here}` from the controller,
## which is the only thing that knows which stations are reached. This
## renders what it is given and decides nothing about eligibility.
func open(from_id: String, from_label: String,
		destinations: Array) -> void:
	_here = from_id
	_decided = false
	_title.text = "STATION %s" % from_label.to_upper()
	for child in _list.get_children():
		child.queue_free()
	var elsewhere := 0
	for raw: Variant in destinations:
		var entry: Dictionary = raw
		var id := str(entry.get("id", ""))
		var label := str(entry.get("label", id))
		var button := Button.new()
		if id == from_id:
			button.text = "%s   (you are here)" % label.to_upper()
			button.disabled = true
		else:
			elsewhere += 1
			button.text = "WARP TO %s" % label.to_upper()
			button.pressed.connect(_choose.bind(id))
		_list.add_child(button)
	if elsewhere == 0:
		var alone := Label.new()
		alone.text = ("No other station in this Zone has been reached "
				+ "yet.\nWalk into one and it becomes a destination.")
		alone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alone.modulate = Color(0.7, 0.72, 0.75)
		_list.add_child(alone)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_list.add_child(spacer)
	# THE ONE OPTION WITH REAL SEMANTICS BEHIND IT. `Main._on_return_to_hub`
	# sends `leave_zone` after remembering the resume anchor, the keys,
	# the opened locks and the reached stations -- the Zone goes DORMANT
	# and the Hub portal offers it back. It is not `abandon_zone`, which
	# is a different intent and throws the Zone away.
	var home := Button.new()
	home.text = "RETURN TO HUB   (this Zone stays where it is)"
	home.pressed.connect(_go_home)
	_list.add_child(home)
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _choose(to_id: String) -> void:
	if _decided or to_id == _here:
		return
	_decided = true
	visible = false
	warp_chosen.emit(_here, to_id)
	closed.emit()

func _go_home() -> void:
	if _decided:
		return
	_decided = true
	visible = false
	return_to_hub_chosen.emit()
	closed.emit()

## ESC LEAVES WITHOUT TRAVELLING, and the event is consumed so it does
## not also reach the pause menu behind it.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
