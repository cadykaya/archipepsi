class_name UnifiedMusic
extends Node
## CONDI'S APPROVED MUSIC, ON HER HOOKS (unified integration 1).
##
## From her handoff `handoff/approved_music_v1/` (PR #44, 124d9467): the
## two SigmAudio Godot packs and the two mixed stingers, installed byte for
## byte under `res://audio/music/` with her import sidecars (checked against
## her `CHECKSUMS.sha256`). Every call below is a row of her README's
## tables (`events.json` holds the same rows):
##
## * Station 1 (both areas): `StationMusic.play()` -- Explore only; this
##   never calls `set_parameter` or `set_state` on it.
## * A Crossing, the title menu: silence (no approved music there).
## * Into the Freight Bay: station stop, Freight Bay `play()` (Exploration).
## * The Shunter's HORN: `trigger_event("engage")`. DOWN: `"victory"`.
## * `state_changed` to Entry / Victory: that stinger, once, on Music.
## * RESTART, or a death in the bay: `stop(); play()`.
## * Out of the Freight Bay: Freight Bay stop, station `play()`.
## * The Shunter losing interest: nothing (her default: stay in Combat).
##
## THE ONE DEPARTURE: her README suggests two autoloads. Here the two cues
## are children of this node, made only in the unified build, so the
## campaign and every other build stay exactly as silent as before. The
## scripts are hers, unchanged; they find their WAVs relative to their own
## path either way, and nothing else about them differs.
##
## The mix: both cues and the stinger player on the Music bus; the Music
## bus is the only level set (`default_bus_layout.tres`, inside her +4 dB
## headroom). The Shunter's horn is on SFX and nothing here ducks it.

const STATION := "res://audio/music/station/godot/sigmaudio_cue.gd"
const FREIGHT := "res://audio/music/freight_bay/godot/sigmaudio_cue.gd"
const ENTRY := "res://audio/music/freight_bay_stingers/freight_bay_entry_stinger.wav"
const VICTORY := "res://audio/music/freight_bay_stingers/freight_bay_victory_stinger.wav"
const BUS := &"Music"

var station: Node
var freight: Node
var stinger: AudioStreamPlayer
## What is meant to be playing: "", "station" or "freight".
var where := ""
## Every call made, in order, for the check: [time, call].
var calls: Array = []
## Every stinger played: [time, "entry" | "victory"].
var stingers: Array = []

var _bay: FreightBay
var _shunter: Shunter


func _ready() -> void:
	station = _cue(STATION, "StationMusic")
	freight = _cue(FREIGHT, "FreightBayMusic")
	stinger = AudioStreamPlayer.new()
	stinger.name = "Stinger"
	stinger.bus = BUS
	add_child(stinger)
	if freight != null:
		freight.state_changed.connect(_on_freight_state)


func _cue(path: String, cue_name: String) -> Node:
	var script := load(path) as Script
	if script == null:
		push_error("music: %s is missing" % path)
		return null
	var cue := script.new() as Node
	cue.name = cue_name
	add_child(cue)
	var player: AudioStreamPlayer = cue.get("_player")
	if player != null:
		player.bus = BUS
	return cue


## Station 1 (the Hub, either area). Binds its Freight Bay, if it has one.
func enter_station(hub: HubController) -> void:
	_bind_bay(hub.freight_bay if hub != null else null)
	if _bay != null and _bay.in_annex:
		_to_freight()
	else:
		_to_station()


## A Crossing or the title: no approved music.
func silence() -> void:
	_bind_bay(null)
	_call("station.stop")
	if station != null:
		station.stop()
	_call("freight.stop")
	if freight != null:
		freight.stop()
	where = ""


func _to_station() -> void:
	if where == "station":
		return
	if where == "freight" and freight != null:
		_call("freight.stop")
		freight.stop()
	where = "station"
	_call("station.play")
	if station != null:
		station.play()


func _to_freight() -> void:
	if where == "freight":
		return
	if station != null:
		_call("station.stop")
		station.stop()
	where = "freight"
	_call("freight.play")
	if freight != null:
		freight.play()


func _bind_bay(bay: FreightBay) -> void:
	if bay == _bay:
		return
	if _bay != null and is_instance_valid(_bay):
		_bay.annex_entered.disconnect(_to_freight)
		_bay.annex_left.disconnect(_to_station)
		_bay.restarted.disconnect(_on_restarted)
	_bay = bay
	_bind_shunter(null)
	if bay == null:
		return
	bay.annex_entered.connect(_to_freight)
	bay.annex_left.connect(_to_station)
	bay.restarted.connect(_on_restarted)
	_bind_shunter(bay.shunter)


func _bind_shunter(sh: Shunter) -> void:
	_shunter = sh
	if sh == null:
		return
	sh.horned.connect(_on_horn.bind(sh))
	sh.powered_down.connect(_on_down.bind(sh))


func _on_horn(sh: Shunter) -> void:
	if sh == _shunter and where == "freight":
		_call("freight.engage")
		freight.trigger_event("engage")


func _on_down(sh: Shunter) -> void:
	if sh == _shunter and where == "freight":
		_call("freight.victory")
		freight.trigger_event("victory")


## RESTART or a death in the bay. The bay makes a new Shunter.
func _on_restarted() -> void:
	_bind_shunter(_bay.shunter)
	if where == "freight" and freight != null:
		_call("freight.restart")
		freight.stop()
		freight.play()


func _on_freight_state(_id: String, _boundary: float) -> void:
	match String(freight.get_state_name()):
		"Entry":
			_sting("entry", ENTRY)
		"Victory":
			_sting("victory", VICTORY)


func _sting(kind: String, path: String) -> void:
	stinger.stream = load(path)
	stinger.play()
	stingers.append([_now(), kind])


func _call(what: String) -> void:
	calls.append([_now(), what])


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
