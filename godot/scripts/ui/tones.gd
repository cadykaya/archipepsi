class_name Tones
extends Node
## Procedurally generated audio: simple synthesized blips, no files shipped.

var _players: Dictionary = {}

func _ready() -> void:
	_players["pulse"] = _make_player(_square_burst(220.0, 0.05, 0.25))
	_players["hit"] = _make_player(_square_burst(520.0, 0.05, 0.2))
	_players["reward"] = _make_player(_arp([392.0, 494.0, 587.0], 0.07, 0.3))
	_players["echo"] = _make_player(_arp([262.0, 330.0, 392.0, 523.0],
			0.09, 0.35))
	_players["purchase"] = _make_player(_arp([440.0, 554.0], 0.08, 0.3))
	_players["denied"] = _make_player(_square_burst(110.0, 0.15, 0.3))
	_players["goal"] = _make_player(_arp(
			[262.0, 330.0, 392.0, 523.0, 659.0, 784.0], 0.11, 0.4))

func play(kind: String) -> void:
	var player: AudioStreamPlayer = _players.get(kind)
	if player != null:
		player.play()

func _make_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	return player

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
