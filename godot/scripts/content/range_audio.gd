class_name RangeAudio
extends Node
## THE FIVE-WEAPON RANGE'S SOUND SLOTS. Condi's SigmAudio renders fill
## them; nothing here is a finished sound.
##
## - **Weapon cues:** `res://audio/sigmaudio/weapons/<weapon>/<cue>.wav`
##   (`.ogg` also loads), with numbered variants `<cue>_01`, `<cue>_02`...
##   picked at random. Cues: `fire`, `fire_tail`, `mech` (pump, bolt,
##   reset), `charge` (Mass Driver's loop) and `release` (its shot).
## - **Impact cues:** `res://audio/sigmaudio/impacts/impact_<material>.wav`
##   for metal, stone, organic and wood.
##
## Until a slot is filled it plays a **labelled placeholder**: the range's
## older `Tones` sounds, which the owner has ruled are not firearm audio.
## `N` silences the placeholders. The screen always says which is which.
##
## **Level matching.** Every WAV, SigmAudio's or placeholder, is measured
## on load (RMS over its first 250 ms, where the attack and body are) and
## played at a gain that brings it to `TARGET_RMS_DB`, so no weapon wins
## by being louder. RMS is a stand-in for perceived loudness, not LUFS;
## the report says so.

const ROOT := "res://audio/sigmaudio"
const WEAPON_CUES: Array[String] = ["fire", "fire_tail", "mech", "charge",
		"release"]
const IMPACT_CUES: Array[String] = ["impact_metal", "impact_stone",
		"impact_organic", "impact_wood"]
const TARGET_RMS_DB := -20.0
const MAX_GAIN_DB := 12.0

## weapon -> cue -> {"streams": Array, "gains": Array, "source": String,
## "pitch": float}
var slots := {}
var placeholders_on := true
## Every cue started: [weapon, cue, process frame, source].
var played: Array = []
var _players := {}
var _rng := RandomNumberGenerator.new()


## `fallback` maps "<weapon>/<cue>" to [AudioStream, pitch] placeholders.
func setup(weapons: Array, fallback: Dictionary, root := ROOT) -> void:
	_rng.seed = 808
	slots.clear()
	for weapon in weapons:
		slots[weapon] = {}
		for cue in WEAPON_CUES:
			slots[weapon][cue] = _slot(root + "/weapons/" + weapon, cue,
					fallback.get(weapon + "/" + cue, []))
	slots["impacts"] = {}
	for cue in IMPACT_CUES:
		slots["impacts"][cue] = _slot(root + "/impacts", cue,
				fallback.get("impacts/" + cue, []))


func _slot(dir: String, cue: String, fallback: Array) -> Dictionary:
	var found: Array = []
	if DirAccess.dir_exists_absolute(dir):
		for file in ResourceLoader.list_directory(dir):
			var base := file.get_basename()
			if not file.get_extension().to_lower() in ["wav", "ogg"]:
				continue
			if base == cue or (base.begins_with(cue + "_")
					and base.substr(cue.length() + 1).is_valid_int()):
				var stream := load(dir + "/" + file) as AudioStream
				if stream != null:
					found.append(stream)
	if not found.is_empty():
		return {"streams": found, "gains": found.map(gain_for),
				"source": "sigmaudio", "pitch": 1.0}
	if fallback.size() == 2 and fallback[0] != null:
		return {"streams": [fallback[0]], "gains": [gain_for(fallback[0])],
				"source": "placeholder", "pitch": float(fallback[1])}
	return {"streams": [], "gains": [], "source": "missing", "pitch": 1.0}


## The gain (dB) that brings a WAV's opening RMS to the target.
static func gain_for(stream: AudioStream) -> float:
	var rms_db := rms_db_of(stream)
	if rms_db <= -90.0:
		return 0.0
	return clampf(TARGET_RMS_DB - rms_db, -24.0, MAX_GAIN_DB)


static func rms_db_of(stream: AudioStream) -> float:
	var wav := stream as AudioStreamWAV
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return -100.0
	var channels := 2 if wav.stereo else 1
	var frames := mini(int(wav.data.size() / (2.0 * channels)),
			int(0.25 * wav.mix_rate))
	if frames <= 0:
		return -100.0
	var total := 0.0
	for i in frames:
		var sample := wav.data.decode_s16(i * 2 * channels) / 32768.0
		total += sample * sample
	return linear_to_db(sqrt(total / frames))


func source(weapon: String, cue: String) -> String:
	return String(slots.get(weapon, {}).get(cue, {}).get("source", "missing"))


## How many slots SigmAudio has filled, of all of them.
func filled() -> Vector2i:
	var count := 0
	var total := 0
	for group in slots:
		for cue in slots[group]:
			total += 1
			if slots[group][cue]["source"] == "sigmaudio":
				count += 1
	return Vector2i(count, total)


## Plays a cue on the weapon's own voice for it: a carbine's next round
## cuts its last one off instead of stacking on it.
func play(weapon: String, cue: String, pitch_jitter := 0.0) -> void:
	var slot: Dictionary = slots.get(weapon, {}).get(cue, {})
	var streams: Array = slot.get("streams", [])
	var src := String(slot.get("source", "missing"))
	if streams.is_empty() or (src == "placeholder" and not placeholders_on):
		played.append([weapon, cue, Engine.get_process_frames(),
				"silent" if not streams.is_empty() else "missing"])
		return
	var key := weapon + "/" + cue
	var voice: AudioStreamPlayer = _players.get(key)
	if voice == null:
		voice = AudioStreamPlayer.new()
		voice.name = "Voice_" + key.replace("/", "_")
		add_child(voice)
		_players[key] = voice
	var pick := _rng.randi() % streams.size()
	voice.stream = streams[pick]
	voice.volume_db = float(slot["gains"][pick])
	voice.pitch_scale = float(slot["pitch"]) * (1.0 + _rng.randf_range(
			-pitch_jitter, pitch_jitter))
	voice.play()
	played.append([weapon, cue, Engine.get_process_frames(), src])


## A playing cue's pitch, live (the Mass Driver's charge rising).
func set_pitch(weapon: String, cue: String, pitch: float) -> void:
	var voice: AudioStreamPlayer = _players.get(weapon + "/" + cue)
	if voice != null and voice.playing:
		voice.pitch_scale = float(slots[weapon][cue]["pitch"]) * pitch


func stop(weapon: String, cue: String) -> void:
	var voice: AudioStreamPlayer = _players.get(weapon + "/" + cue)
	if voice != null:
		voice.stop()


## An impact, positional at the hit.
func play_at(cue: String, at: Vector3, world: Node) -> void:
	var slot: Dictionary = slots.get("impacts", {}).get(cue, {})
	var streams: Array = slot.get("streams", [])
	var src := String(slot.get("source", "missing"))
	if streams.is_empty() or (src == "placeholder" and not placeholders_on):
		played.append(["impacts", cue, Engine.get_process_frames(),
				"silent" if not streams.is_empty() else "missing"])
		return
	var pick := _rng.randi() % streams.size()
	var sound := AudioStreamPlayer3D.new()
	sound.stream = streams[pick]
	sound.volume_db = float(slot["gains"][pick])
	sound.pitch_scale = float(slot["pitch"])
	sound.unit_size = 6.0
	world.add_child(sound)
	sound.global_position = at
	sound.play()
	sound.finished.connect(sound.queue_free)
	played.append(["impacts", cue, Engine.get_process_frames(), src])
