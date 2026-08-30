class_name ActivityRuntime
extends Node3D
## What makes an activity a thing the player DOES.
##
## Before this existed, `Activities.build()` placed a row of glowing
## `StaticBody3D` boxes and returned a dictionary nobody read. Nothing in
## the client referenced the four activity kinds. 531 of the played Zone's
## 921 points of content value — 57.7% — were those boxes.
##
## ONE runtime, four configurations. The activity vocabulary is four
## composable FAMILIES rather than fifteen bespoke minigames
## (CAMPAIGN_SCALE.md 9), and four bespoke runtimes would have thrown that
## away at the only layer where it costs anything. What differs per family
## is in `RULES` below and nowhere else.
##
## WHAT AN ACTIVITY IS NOT, and may not become without an explicit
## contract that does not exist yet: an AP Check, a Zone-exit condition,
## or any progression requirement. Completion grants a LOCAL reward
## through the one validated route (§14.2), which is worth exactly zero to
## Archipelago.

## Idle: built, never started. Active: the clock, if any, is running.
## Complete: done, and it stays done. Not-yet: the player cannot currently
## do what it asks (see `_missing_capabilities`).
enum State { NOT_YET, IDLE, ACTIVE, COMPLETE }

## Everything that differs between the four families.
##
##   trigger      how an element is set
##   simultaneous success needs every element set AT ONCE, so an element
##                releasing is a failure rather than nothing
##   roles        the family uses start/goal elements rather than a row
const RULES := {
	"switch_sequence": {
		"trigger": ActivityElement.TOUCH,
		"simultaneous": false, "roles": false,
		"size": ActivityElement.SWITCH_SIZE, "height": 1.0,
	},
	"target_challenge": {
		"trigger": ActivityElement.SHOT,
		"simultaneous": false, "roles": false,
		"size": ActivityElement.TARGET_SIZE, "height": 2.2,
	},
	"pressure_routing": {
		"trigger": ActivityElement.STAND,
		"simultaneous": true, "roles": false,
		"size": ActivityElement.PLATE_SIZE, "height": 0.08,
	},
	"timed_run": {
		"trigger": ActivityElement.TOUCH,
		"simultaneous": false, "roles": true,
		"size": ActivityElement.SWITCH_SIZE, "height": 1.0,
	},
}

## Playtest labelling: every activity says what it IS and what to do,
## before you touch it.
##
## A crutch, deliberately, and one with a switch. The graybox forms are
## supposed to carry family identity on their own -- that is what the
## silhouette work was for -- so a label that could not be turned off
## would make the question "can you tell these apart" permanently
## unanswerable. F4 toggles it; it starts ON because a playtester who
## cannot tell a plate from a floor tile is not testing the mechanics.
static var labels_visible := true

## Every live activity, so the toggle can reach them without a search.
const GROUP := "activities"

## What each family is, and what you do to it. Two lines: the name, then
## the verb, because "SWITCH SEQUENCE" alone does not say to walk into it.
const IDENTITY := {
	"switch_sequence": ["SWITCH SEQUENCE", "walk into all %d"],
	"target_challenge": ["TARGET CHALLENGE", "shoot all %d"],
	"pressure_routing": ["PRESSURE ROUTING", "hold all %d pads at once"],
	"timed_run": ["TIMED RUN", "start, then reach the goal"],
}

signal completed(activity_id: String, seconds: float, attempts: int)
signal failed(activity_id: String, reason: String)
signal state_changed(state: State)

var activity_id := "activity"
var kind := "switch_sequence"
var room_id := ""
## The chamber index this activity sits in, so the playtime log can
## mark it noticed when the player walks into the room. Written by
## `ZoneController`, which is the only thing that knows chamber order --
## the builder is handed one room at a time and cannot.
var room_index := -1
var element_count := 1
var time_limit := 0.0
var ordered := false
## Semantic capabilities this activity asks for. Names from
## `mechanics.ACTIVITY_CAPABILITIES`; the bridge has already refused any
## the campaign is not guaranteed to be able to satisfy, so what remains
## here is only ever "owned but not currently equipped".
var requires: PackedStringArray = PackedStringArray()

var state := State.IDLE
var attempts := 0
var elements: Array[ActivityElement] = []

var _set_order: Array[int] = []
var _clock := 0.0
var _active_seconds := 0.0
var _result_left := 0.0
var _label: Label3D
var _entered := false

static func create(activity: Dictionary, room_id_in: String,
		activity_id_in: String) -> ActivityRuntime:
	var runtime := ActivityRuntime.new()
	runtime.activity_id = activity_id_in
	runtime.room_id = room_id_in
	runtime.kind = str(activity.get("kind", "switch_sequence"))
	runtime.element_count = int(activity.get("element_count", 1))
	runtime.time_limit = float(activity.get("time_limit", 0.0))
	runtime.ordered = bool(activity.get("ordered", false))
	for capability: Variant in activity.get("requires", []) as Array:
		runtime.requires.append(str(capability))
	runtime.name = "Activity_" + activity_id_in
	runtime.add_to_group(GROUP)
	return runtime

func rules() -> Dictionary:
	return RULES.get(kind, RULES["switch_sequence"]) as Dictionary

## How many elements this family actually places.
##
## `timed_run` is the one that differs: a run needs somewhere to start and
## somewhere to end, so it is at least two whatever the count says. That
## was true of the old geometry-only builder too, and the number of things
## the player touches has to match the number the success rule counts —
## otherwise a run of one is complete before it begins.
func placed_count() -> int:
	if bool(rules()["roles"]):
		return maxi(2, element_count)
	return maxi(1, element_count)

func adopt(built: Array[ActivityElement]) -> void:
	elements = built
	for element in elements:
		element.triggered.connect(_on_triggered)
		element.released.connect(_on_released)
	_build_label()
	_tag_elements()
	_refresh_capability_state()

## The clock and the progress count get a HOME, on the activity itself.
##
## It used to sit 2.6 m above the runtime's own origin, which for a
## `timed_run` spread across a whole room is a point in mid-air belonging
## to nothing. It now rides the element the run STARTS from -- the gate
## for a roles family, the first element otherwise -- so the reading and
## the thing being read are in the same place.
func _build_label() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.012
	_label.modulate = Color(0.85, 0.88, 0.92)
	_label.outline_size = 16
	_label.visible = false
	var home := _label_home()
	_label.position = home + Vector3(0.0, 3.1, 0.0)
	add_child(_label)
	_show_identity()

## The idle line: what this is and what to do with it.
func _show_identity() -> void:
	var entry: Array = IDENTITY.get(kind, ["ACTIVITY", "%d parts"])
	var verb: String = str(entry[1])
	if verb.contains("%d"):
		verb = verb % placed_count()
	if ordered:
		verb += " IN ORDER"
	if time_limit > 0.0:
		verb += "   %.0fs" % time_limit
	_say("%s\n%s" % [entry[0], verb])

## Per-element tags, for the one family whose parts have different jobs.
## `timed_run` is it: a start, a goal and waypoints look different now,
## but "different" and "which is which" are not the same question.
func _tag_elements() -> void:
	for element in elements:
		var text := ""
		if element.role == ActivityElement.ROLE_START:
			text = "START"
		elif element.role == ActivityElement.ROLE_GOAL:
			text = "GOAL"
		if text == "":
			continue
		var tag := Label3D.new()
		tag.text = text
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.pixel_size = 0.016
		tag.outline_size = 18
		tag.modulate = Color(0.9, 0.93, 0.97)
		tag.position = element.position + Vector3(0.0, 2.0, 0.0)
		tag.visible = labels_visible
		tag.name = "Tag_%s" % text
		add_child(tag)

func _label_home() -> Vector3:
	for element in elements:
		if element.role == ActivityElement.ROLE_START:
			return element.position
	if not elements.is_empty():
		return elements[0].position
	return Vector3.ZERO

## A NOT YET is deliberate, legible and honest.
##
## It is never a broken switch and never a fake interaction, and the
## activity is never quietly downgraded to something the base kit can do
## instead — the owner ruling of 2026-08-30 is explicit that silently
## substituting a generic version is worse than saying no.
##
## Reachable rather than theoretical: the bridge generates a Zone against
## what the campaign OWNS, and the player walks into it with whatever they
## have SLOTTED. Owning the grapple and not having it equipped is an
## ordinary Tuesday, and this is what it looks like.
func _refresh_capability_state() -> void:
	var missing := _missing_capabilities()
	if missing.is_empty():
		if state == State.NOT_YET:
			_go(State.IDLE)
		return
	if state == State.COMPLETE:
		return
	_go(State.NOT_YET)
	_say("NOT YET — needs %s" % ", ".join(missing))

func _missing_capabilities() -> PackedStringArray:
	var available: Variant = BridgeClient.snapshot.get(
			"available_capabilities", [])
	var have := {}
	if typeof(available) == TYPE_ARRAY:
		for capability: Variant in available as Array:
			have[str(capability)] = true
	var missing := PackedStringArray()
	for capability in requires:
		if not have.has(capability):
			missing.append(capability)
	return missing

func _on_triggered(element: ActivityElement) -> void:
	if state == State.NOT_YET or state == State.COMPLETE:
		# An element that fires while the activity is refusing is not an
		# attempt. Put it straight back so the geometry never disagrees
		# with what the label says.
		element.reset()
		return
	if state == State.IDLE:
		attempts += 1
		_clock = time_limit
		_set_order.clear()
		_go(State.ACTIVE)
	_set_order.append(element.index)
	if ordered and not _order_is_right():
		_fail("wrong order")
		return
	if _all_set():
		_succeed()
	else:
		_say(_progress_text())

func _on_released(_element: ActivityElement) -> void:
	if state != State.ACTIVE:
		return
	# Only a simultaneous family cares. A latching switch cannot release
	# on its own, and a `pressure_routing` plate popping back up before
	# the circuit is complete is the failure that family is ABOUT.
	if bool(rules()["simultaneous"]):
		_fail("a plate released")

func _order_is_right() -> bool:
	for i in _set_order.size():
		if _set_order[i] != i:
			return false
	return true

func _all_set() -> bool:
	if bool(rules()["simultaneous"]):
		for element in elements:
			if not element.is_set:
				return false
		return true
	if bool(rules()["roles"]):
		# A run is over when the GOAL is reached, not when every marker
		# on the way has been brushed past.
		for element in elements:
			if element.role == ActivityElement.ROLE_GOAL:
				return element.is_set
		return false
	for element in elements:
		if not element.is_set:
			return false
	return true

func _process(delta: float) -> void:
	# The result label lingers so the player can read why. The state and
	# the elements are already back to IDLE; only the text is waiting.
	if _result_left > 0.0:
		_result_left -= delta
		if _result_left <= 0.0 and state == State.IDLE:
			_show_identity()
		return
	if state != State.ACTIVE:
		return
	_active_seconds += delta
	if time_limit <= 0.0:
		return
	_clock -= delta
	if _clock <= 0.0:
		_fail("out of time")
	else:
		_say(_progress_text())

func _progress_text() -> String:
	var done := 0
	for element in elements:
		if element.is_set:
			done += 1
	var text := "%d / %d" % [done, placed_count()]
	if time_limit > 0.0 and state == State.ACTIVE:
		text += "   %.1fs" % maxf(_clock, 0.0)
	return text

func _succeed() -> void:
	_go(State.COMPLETE)
	_say("DONE")
	# The one validated route, and no second reward authority. The
	# `reward_id` is derived from the activity's identity rather than
	# from the moment, so re-completing it is the same note found twice
	# — which `transitions.grant_local_reward` already treats as one.
	# That is what stops an activity from being a farm.
	BridgeClient.send_intent({
		"type": "grant_local_reward",
		"kind": "flavor_log",
		"reward_id": "activity_%s" % activity_id,
		"display_name": "%s solved" % kind.capitalize().replace("_", " "),
		"description": "Solved in %s." % room_id,
	})
	completed.emit(activity_id, _active_seconds, attempts)

func _fail(reason: String) -> void:
	"""A failed attempt clears the geometry IMMEDIATELY.

	The lingering part is the LABEL, not the state. An element left lit
	while the runtime says IDLE is a switch that looks pressed and is
	not, which reads as a bug rather than as a reset -- and it is the
	shape of thing a state-only test never notices.
	"""
	_reset_attempt()
	_go(State.IDLE)
	_say("RESET — %s" % reason)
	_result_left = Constants.ACTIVITY_RESULT_SECONDS
	failed.emit(activity_id, reason)

func _reset_attempt() -> void:
	_set_order.clear()
	_clock = time_limit
	_active_seconds = 0.0
	for element in elements:
		element.reset()

func _go(next: State) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(state)

func _say(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = text != "" and labels_visible

## Show or hide every label this activity owns. Called by `Main` on F4.
func set_labels_visible(shown: bool) -> void:
	if _label != null:
		_label.visible = shown and _label.text != ""
	for child in get_children():
		if child is Label3D and child != _label:
			(child as Label3D).visible = shown

## What the instrumentation records. Read rather than pushed, so a Zone
## that ends mid-attempt still reports the attempt honestly instead of
## reporting nothing.
func report() -> Dictionary:
	return {
		"activity_id": activity_id,
		"kind": kind,
		"room_id": room_id,
		"element_count": placed_count(),
		"time_limit": time_limit,
		"ordered": ordered,
		"requires": Array(requires),
		"entered": _entered,
		"attempts": attempts,
		"completed": state == State.COMPLETE,
		"not_yet": state == State.NOT_YET,
		"active_seconds": roundf(_active_seconds * 100.0) / 100.0,
	}

## The player came within reach of it at all. Distinct from attempting it:
## "did they notice it" and "did they try it" are different questions and
## the next playtest has to be able to tell them apart.
func mark_entered() -> void:
	_entered = true
