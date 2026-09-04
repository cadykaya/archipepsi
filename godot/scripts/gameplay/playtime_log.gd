class_name PlaytimeLog
extends RefCounted

## What a Zone actually cost the player, measured (CAMPAIGN_SCALE.md 13).
##
## The forty-minute Zone and the twenty-hour campaign are TARGETS. Only
## the running game knows how long a room held someone, how many times
## they died, or how long a fight really took, so this is where those
## numbers come from. It sends them to the bridge once, at the end of the
## Zone, and the bridge joins them to the content values it computed for
## the same rooms.
##
## LOCAL ONLY. The bridge appends the joined record to a file in the
## player's save directory. There is no analytics service, nothing is
## uploaded, and this class has no network of its own -- it hands a
## dictionary to the bridge the player is already connected to.
##
## It measures and nothing else. Nothing in the Zone reads it, no gameplay
## depends on it, and a Zone plays identically with it removed.

## Time spent paused does not count: a Zone someone walked away from in
## the middle of is not a forty-minute Zone.
var _elapsed := 0.0
var _deaths := 0
var _dwell: Dictionary = {}          # chamber index -> seconds
var _current := -1
var _encounters: PackedFloat32Array = PackedFloat32Array()
var _encounter_start := -1.0
var _live_enemies := 0
var _checks := 0
var _chamber_count := 0
## Every activity the Zone built, in build order. Held as references
## rather than as snapshots so a Zone that ends mid-attempt reports the
## attempt honestly instead of reporting the last state anybody polled.
var _activities: Array[ActivityRuntime] = []


func begin(chamber_count: int) -> void:
	_elapsed = 0.0
	_deaths = 0
	_dwell.clear()
	_current = -1
	_encounters = PackedFloat32Array()
	_encounter_start = -1.0
	_live_enemies = 0
	_checks = 0
	_chamber_count = chamber_count
	_activities.clear()


## Register an activity the Zone built. Measurement only: nothing here
## reaches back into the runtime, and a Zone plays identically with the
## whole log removed.
func watch_activity(runtime: ActivityRuntime) -> void:
	if runtime != null:
		_activities.append(runtime)


func enter_chamber_activities(index: int) -> void:
	"""Mark every activity in the room the player just walked into.

	"Did they notice it" and "did they try it" are different findings,
	and only the room they are standing in can answer the first.
	"""
	for runtime in _activities:
		if is_instance_valid(runtime) and runtime.room_index == index:
			runtime.mark_entered()


func tick(delta: float) -> void:
	_elapsed += delta
	if _current >= 0:
		_dwell[_current] = float(_dwell.get(_current, 0.0)) + delta


func enter_chamber(index: int) -> void:
	_current = index


func note_death() -> void:
	_deaths += 1
	# A death ends the fight as far as the clock is concerned: the time
	# from here to the respawn kill is not how long the encounter took.
	_encounter_start = -1.0
	_live_enemies = 0


func note_check_confirmed() -> void:
	_checks += 1


## An encounter is the stretch between the first enemy engaged and the
## last one dying. Started by damage rather than by walking into a room,
## because a room you sprint through is not a fight.
func note_engagement(live_enemies: int) -> void:
	_live_enemies = live_enemies
	if _encounter_start < 0.0 and live_enemies > 0:
		_encounter_start = _elapsed


func note_enemy_died(live_enemies: int) -> void:
	_live_enemies = live_enemies
	if live_enemies > 0 or _encounter_start < 0.0:
		return
	if _encounters.size() < 64:
		_encounters.append(_elapsed - _encounter_start)
	_encounter_start = -1.0


## The intent, or an empty dictionary when there is nothing worth saying.
func to_intent(zone_id: String, completed: bool) -> Dictionary:
	if zone_id.is_empty() or _elapsed <= 0.0:
		return {}
	var dwell: Array = []
	for index in range(min(_chamber_count, Constants.ZONE_MAX_CHAMBERS)):
		dwell.append({"chamber_index": index,
				"seconds": snappedf(float(_dwell.get(index, 0.0)), 0.01)})
	var encounters: Array = []
	for seconds in _encounters:
		encounters.append(snappedf(float(seconds), 0.01))
	return {
		"type": "zone_timing",
		"zone_id": zone_id,
		"elapsed_seconds": snappedf(min(_elapsed, 36000.0), 0.01),
		"deaths": _deaths,
		"checks_completed": _checks,
		"dwell": dwell,
		"encounter_seconds": encounters,
		"completed": completed,
		"activities": _activity_reports(),
	}


func _activity_reports() -> Array:
	var out: Array = []
	for runtime in _activities:
		if is_instance_valid(runtime):
			out.append(runtime.report())
	return out
