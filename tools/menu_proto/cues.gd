class_name Cues
extends Node
## WHAT THE DEVICE SOUNDS LIKE: short synthesised cues, no files shipped --
## Production's own recipe (Tones: square bursts, arpeggios, thuds, made at
## 22 050 Hz), in the prototype's own bank. It is not Production's bank and
## changes nothing there.
##
## Sound is information, not decoration, so it is NOT motion: reduced
## visual motion leaves every cue exactly as it is. What sets them is the
## Settings wall's MASTER VOLUME (0 mutes them).
##
## * tick     -- the selection moved in a list (rack, Journal, Settings)
## * detent   -- the key selector moved one position
## * edge     -- a move asked past the end of a list: nothing moved
## * scroll   -- a list scrolled by hand, one row
## * page     -- a page turn
## * preview  -- a preview set (NOT SENT)
## * restore  -- back to the save
## * refuse   -- the action is refused (its words say why)
## * value    -- a setting's value changed; its pitch follows the value
## * toggle   -- a switch thrown
## * follow   -- SHOW ON THE MAP
## * return   -- back to your view
## * open / close -- the menu
##
## Every cue played is logged, so a test can hear what a hand would.

var volume := 1.0
var heard: Array = []                # the last cues, newest last
var counts := {}                     # kind -> how many
var total := 0
var _players := {}
const BASE_DB := {"tick": -17.0, "detent": -12.0, "edge": -15.0, "scroll": -21.0,
	"page": -16.0, "preview": -12.0, "restore": -12.0, "refuse": -14.0,
	"value": -16.0, "toggle": -13.0, "follow": -13.0, "return": -14.0,
	"open": -16.0, "close": -16.0}


func _ready() -> void:
	_add("tick", _blip(1560.0, 0.022, 0.45))
	_add("detent", _click(170.0, 0.06))
	_add("edge", _blip(260.0, 0.05, 0.5))
	_add("scroll", _blip(1900.0, 0.014, 0.35))
	_add("page", _thud(88.0, 0.11))
	_add("preview", _arp([523.0, 784.0], 0.05, 0.32))
	_add("restore", _arp([784.0, 523.0], 0.05, 0.32))
	_add("refuse", _square(110.0, 0.12, 0.26))
	_add("value", _blip(900.0, 0.024, 0.45))
	_add("toggle", _click(420.0, 0.05))
	_add("follow", _arp([392.0, 523.0, 659.0], 0.05, 0.3))
	_add("return", _arp([659.0, 523.0], 0.05, 0.3))
	_add("open", _arp([330.0, 440.0], 0.04, 0.26))
	_add("close", _arp([440.0, 330.0], 0.04, 0.26))


func _add(kind: String, stream: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.max_polyphony = 4
	add_child(p)
	_players[kind] = p
	_apply(kind)


## Play a cue. `pitch` shifts it (a value's position; a key's place).
func play(kind: String, pitch := 1.0) -> void:
	total += 1
	counts[kind] = int(counts.get(kind, 0)) + 1
	heard.append(kind)
	if heard.size() > 32:
		heard.remove_at(0)
	var p: AudioStreamPlayer = _players.get(kind)
	if p == null or volume <= 0.0:
		return
	p.pitch_scale = pitch
	p.play()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	for kind: String in _players:
		_apply(kind)


func _apply(kind: String) -> void:
	var p: AudioStreamPlayer = _players[kind]
	p.volume_db = float(BASE_DB.get(kind, -14.0)) + (linear_to_db(volume)
			if volume > 0.0 else -80.0)


func state() -> Dictionary:
	return {"total": total, "counts": counts.duplicate(), "last": heard[-1]
			if not heard.is_empty() else "", "recent": heard.duplicate(),
		"volume": volume}


# ------------------------------------------------------------ synthesis

## A short sine tick with a fast decay.
static func _blip(freq: float, duration: float, gain: float) -> AudioStreamWAV:
	return _synth(func(t: float) -> float:
		return sin(t * freq * TAU) * gain * pow(1.0 - t / duration, 3.0), duration)


## A mechanical detent: a sharp noise transient on a short low body.
static func _click(freq: float, duration: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 10.0)
	return _synth(func(t: float) -> float:
		var body := sin(t * freq * TAU) * 0.42 * pow(1.0 - t / duration, 2.0)
		var snap := rng.randf_range(-1.0, 1.0) * 0.5 * exp(-t * 900.0)
		return body + snap, duration)


static func _thud(freq: float, duration: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 100.0)
	return _synth(func(t: float) -> float:
		var envelope := pow(1.0 - t / duration, 2.5)
		var body := sin(t * freq * TAU) * 0.5
		var grit := rng.randf_range(-1.0, 1.0) * 0.16 * pow(1.0 - t / duration, 8.0)
		return (body + grit) * envelope, duration)


static func _square(freq: float, duration: float, gain: float) -> AudioStreamWAV:
	return _synth(func(t: float) -> float:
		var phase := fmod(t * freq, 1.0)
		return (1.0 if phase < 0.5 else -1.0) * gain * (1.0 - t / duration), duration)


static func _arp(freqs: Array, note: float, gain: float) -> AudioStreamWAV:
	var total_s := note * freqs.size()
	return _synth(func(t: float) -> float:
		var i := mini(int(t / note), freqs.size() - 1)
		var local := fmod(t, note)
		return sin(t * float(freqs[i]) * TAU) * gain * (1.0 - local / note), total_s)


static func _synth(fn: Callable, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var v: float = fn.call(float(i) / rate)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s
