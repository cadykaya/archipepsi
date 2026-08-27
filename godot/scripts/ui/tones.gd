class_name Tones
extends Node
## Procedurally generated audio: simple synthesized blips, no files shipped.

var _players: Dictionary = {}
var _ambience: AudioStreamPlayer

func _ready() -> void:
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = _hum_loop()
	_ambience.volume_db = -20.0
	add_child(_ambience)
	_players["pulse"] = _make_player(_square_burst(220.0, 0.05, 0.25))
	_players["hit"] = _make_player(_square_burst(520.0, 0.05, 0.2))
	_players["reward"] = _make_player(_arp([392.0, 494.0, 587.0], 0.07, 0.3))
	_players["echo"] = _make_player(_arp([262.0, 330.0, 392.0, 523.0],
			0.09, 0.35))
	_players["purchase"] = _make_player(_arp([440.0, 554.0], 0.08, 0.3))
	_players["denied"] = _make_player(_square_burst(110.0, 0.15, 0.3))
	_players["goal"] = _make_player(_arp(
			[262.0, 330.0, 392.0, 523.0, 659.0, 784.0], 0.11, 0.4))
	# Two footstep variants, alternated, so walking is not one ticking tone.
	_players["step_a"] = _make_player(_thud(78.0, 0.09))
	_players["step_b"] = _make_player(_thud(64.0, 0.10))
	_players["step_a"].volume_db = -22.0
	_players["step_b"].volume_db = -22.0
	_players["land"] = _make_player(_thud(52.0, 0.16))
	_players["land"].volume_db = -15.0

func play(kind: String) -> void:
	var player: AudioStreamPlayer = _players.get(kind)
	if player != null:
		player.play()

## The room tone. Pitch varies by place: the Hub hums at 1.0, each theme a
## little differently — the same machine heard through different walls.
func play_ambience(pitch: float = 1.0) -> void:
	_ambience.pitch_scale = pitch
	if not _ambience.playing:
		_ambience.play()

func stop_ambience() -> void:
	_ambience.stop()

static func _hum_loop() -> AudioStreamWAV:
	# A seamless 1s loop: low drone plus a faint slow shimmer. Every
	# partial (55/110/220 Hz carriers, 3 Hz modulator) completes whole
	# cycles in the window, so the seam is silent.
	var stream := _synth(func(t: float) -> float:
		var drone := sin(t * 55.0 * TAU) * 0.22 + sin(t * 110.0 * TAU) * 0.08
		var shimmer := sin(t * 220.0 * TAU + sin(t * 3.0 * TAU) * 1.5) * 0.04
		return drone + shimmer, 1.0)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Derived from the buffer, never a second copy of the sample rate.
	stream.loop_end = stream.data.size() / 2
	return stream

func _make_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	return player

## A footfall: a low thump with a short noise transient on top.
static func _thud(freq: float, duration: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 100.0)
	return _synth(func(t: float) -> float:
		var envelope := pow(1.0 - t / duration, 2.5)
		var body := sin(t * freq * TAU) * 0.5
		var grit := rng.randf_range(-1.0, 1.0) * 0.22 \
				* pow(1.0 - t / duration, 8.0)
		return (body + grit) * envelope, duration)

static func _square_burst(freq: float, duration: float,
		volume: float) -> AudioStreamWAV:
	return _synth(func(t: float) -> float:
		var phase := fmod(t * freq, 1.0)
		var envelope := 1.0 - t / duration
		return (1.0 if phase < 0.5 else -1.0) * volume * envelope, duration)

static func _arp(freqs: Array, note_length: float,
		volume: float) -> AudioStreamWAV:
	var total := note_length * freqs.size()
	return _synth(func(t: float) -> float:
		var index := mini(int(t / note_length), freqs.size() - 1)
		var freq: float = freqs[index]
		var local := fmod(t, note_length)
		var envelope := 1.0 - local / note_length
		return sin(t * freq * TAU) * volume * envelope, total)

static func _synth(sample_fn: Callable, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var value: float = sample_fn.call(float(i) / rate)
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
