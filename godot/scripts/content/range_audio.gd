class_name RangeAudio
extends Node
## THE FIVE-WEAPON RANGE'S SOUND, played from Condi's SigmAudio handoff.
##
## **The handoff is the contract.** `res://audio/sigmaudio/five_weapons/`
## holds her WAVs and `events.json` unchanged (copied and hash-checked by
## `tools/five_weapons/import_sigmaudio.py` from `handoff/five_weapon_audio/`,
## imported as uncompressed PCM). This reads `events.json` for every event
## name, its file(s), its voice count and the charge loop's points, so a
## new delivery that keeps those names drops in without code changes.
##
## **Her level contract.** The files arrive level-matched (every gun's
## main fire event at -21 LUFS, impacts 4 dB under). They all play at ONE
## `volume_db`, `trim_db`, the range's single bus-level trim; nothing is
## re-normalised per file. The only per-event offsets are the ones her
## `impact_rules` ask for: Switchback's impacts and Bulkhead's extra
## pellet impacts sit lower (`IMPACT_RULE_DB`).
##
## The gun's own sounds are non-positional; impacts play at the hit
## (her `player_hint`).

const DIR := "res://audio/sigmaudio/five_weapons"
## The one trim every handoff sound plays at (dB). Her suggested start
## is 0; the range sits a little under it so that a shot and its impact
## together keep headroom.
const TRIM_DB := -2.0
## Her impact rules, as offsets from the trim (dB).
const IMPACT_RULE_DB := {"switchback": -5.5, "bulkhead_extra": -12.0}
## Her fade for the charge and its loop when the Mass Driver is released.
const RELEASE_FADE := 0.025
## Her crossfade from the rising charge into the held loop.
const HOLD_CROSSFADE := 0.05

## event -> {"streams": Array, "files": Array, "voices": int, "loop": Dict}
var events := {}
var trim_db := TRIM_DB
var muted := false
## Every event started: [event, process frame, file, volume_db].
var played: Array = []
var _voices := {}
var _next := {}
var _rng := RandomNumberGenerator.new()
var _fades := {}


func setup(dir := DIR) -> void:
	_rng.seed = 808
	events.clear()
	var text := FileAccess.get_file_as_string(dir + "/events.json")
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("RangeAudio: no events.json in " + dir)
		return
	for entry: Dictionary in parsed["events"]:
		var files: Array = entry["file"] if entry["file"] is Array \
				else [entry["file"]]
		var streams: Array = []
		for file: String in files:
			var stream := load(dir + "/" + file) as AudioStream
			if stream != null:
				streams.append(stream)
		events[String(entry["event"])] = {"streams": streams, "files": files,
				"voices": int(entry.get("voices", 1)),
				"loop": entry.get("loop", {})}


## How many of `events.json`'s events loaded, of all of them.
func loaded() -> Vector2i:
	var count := 0
	for name: String in events:
		var streams: Array = events[name]["streams"]
		if streams.size() == (events[name]["files"] as Array).size():
			count += 1
	return Vector2i(count, events.size())


func has(event: String) -> bool:
	return not (events.get(event, {}).get("streams", []) as Array).is_empty()


## The gun's own sound, non-positional. A list of files plays in turn
## (Switchback's A, B, A, B). `offset_db` is only ever one of her rules.
func play(event: String, pitch := 1.0, offset_db := 0.0) -> AudioStreamPlayer:
	var stream: AudioStream = _pick(event)
	if stream == null:
		played.append([event, Engine.get_process_frames(), "missing", 0.0])
		return null
	var voice := _voice(event)
	_fades.erase(voice)
	voice.stream = stream
	voice.volume_db = trim_db + offset_db
	voice.pitch_scale = pitch
	if not muted:
		voice.play()
	played.append([event, Engine.get_process_frames(),
			stream.resource_path.get_file(), voice.volume_db])
	return voice


## An impact at the hit, positional.
func play_at(event: String, at: Vector3, world: Node, offset_db := 0.0,
		delay := 0.0) -> void:
	var stream: AudioStream = _pick(event)
	if stream == null:
		played.append([event, Engine.get_process_frames(), "missing", 0.0])
		return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.volume_db = trim_db + offset_db
	# Distance only ever takes away (her "3D attenuation on top"): close
	# to the hit Godot's inverse-distance curve would otherwise lift an
	# impact ABOVE its level, by 6 dB at 4 m.
	sound.max_db = sound.volume_db
	sound.unit_size = 8.0
	sound.max_polyphony = 1
	world.add_child(sound)
	sound.global_position = at
	if not muted:
		if delay > 0.0:
			get_tree().create_timer(delay, false).timeout.connect(sound.play)
		else:
			sound.play()
	sound.finished.connect(sound.queue_free)
	get_tree().create_timer(4.0, false).timeout.connect(sound.queue_free)
	played.append([event, Engine.get_process_frames(),
			stream.resource_path.get_file(), sound.volume_db])


func playing(event: String) -> bool:
	for voice: AudioStreamPlayer in _voices.get(event, []):
		if voice.playing and not _fades.has(voice):
			return true
	return false


## Stops an event, over `fade` seconds (her 20-30 ms on a release).
func stop(event: String, fade := 0.0) -> void:
	for voice: AudioStreamPlayer in _voices.get(event, []):
		if not voice.playing:
			continue
		if fade <= 0.0:
			voice.stop()
			continue
		_fades[voice] = true
		var tween := voice.create_tween()
		tween.tween_property(voice, "volume_db", -60.0, fade)
		tween.tween_callback(_faded.bind(voice))


func _faded(voice: AudioStreamPlayer) -> void:
	if _fades.has(voice):
		_fades.erase(voice)
		voice.stop()


## The rising charge hands over to the held loop with her 50 ms
## crossfade.
func crossfade(from: String, to: String) -> void:
	stop(from, HOLD_CROSSFADE)
	var voice := play(to)
	if voice != null:
		voice.volume_db = -40.0
		voice.create_tween().tween_property(voice, "volume_db", trim_db,
				HOLD_CROSSFADE)


func stop_all() -> void:
	for event: String in _voices:
		for voice: AudioStreamPlayer in _voices[event]:
			voice.stop()
	_fades.clear()


func _pick(event: String) -> AudioStream:
	var streams: Array = events.get(event, {}).get("streams", [])
	if streams.is_empty():
		return null
	var index := int(_next.get(event, 0)) % streams.size()
	_next[event] = index + 1
	return streams[index]


## Her voice count per event: a new shot steals the oldest voice.
func _voice(event: String) -> AudioStreamPlayer:
	if not _voices.has(event):
		var pool: Array = []
		for i in maxi(1, int(events[event]["voices"])):
			var voice := AudioStreamPlayer.new()
			voice.name = "Voice_%s_%d" % [event.replace(".", "_"), i]
			add_child(voice)
			pool.append(voice)
		_voices[event] = pool
		_next[event + "#voice"] = 0
	var pool: Array = _voices[event]
	for voice: AudioStreamPlayer in pool:
		if not voice.playing:
			return voice
	var index := int(_next[event + "#voice"]) % pool.size()
	_next[event + "#voice"] = index + 1
	return pool[index]


## Peak of a 16-bit WAV (dBFS), for the check.
static func peak_db_of(stream: AudioStream) -> float:
	var wav := stream as AudioStreamWAV
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return 0.0
	var peak := 0
	for i in int(wav.data.size() / 2.0):
		peak = maxi(peak, absi(wav.data.decode_s16(i * 2)))
	return linear_to_db(maxf(peak, 1) / 32768.0)
