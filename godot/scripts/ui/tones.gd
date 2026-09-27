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
	# Hit confirmation: deliberately tiny. It fires as often as you pull the
	# trigger, so it has to read as a tick, not as an event.
	_players["confirm"] = _make_player(_square_burst(1180.0, 0.03, 0.16))
	_players["confirm"].volume_db = -16.0
	# Reaching a secret. Small and rising, deliberately unlike "reward":
	# nothing was granted, so it must not sound like a Check confirming.
	_players["secret"] = _make_player(_arp([587.0, 880.0, 1175.0], 0.06, 0.24))
	_players["secret"].volume_db = -11.0

## THE MENU'S CUES (MENU-INT; the approved hybrid's vocabulary): the same
## recipe as everything above, in this one bank. Sound is information, not
## decoration, so reduced motion never silences them; the Master bus --
## Settings' MASTER VOLUME -- sets them, and 0 is silent. Each level is
## tunable here, per cue.
##
## * tick     -- the selection moved in a list (rack, Journal, Settings)
## * detent   -- the key selector moved one position
## * edge     -- a move asked past the end of a list: nothing moved
## * scroll   -- a list scrolled by hand, one row
## * page     -- a page turn
## * preview  -- an equip request sent
## * restore  -- an undo or a clear sent
## * refuse   -- refused (its words say why)
## * value    -- a setting's value changed; its pitch follows the value
## * toggle   -- a switch thrown, or a request answered
## * follow   -- SHOW ON THE MAP
## * return   -- back to your view
## * open / close -- the menu
const MENU_DB := {"tick": -17.0, "detent": -12.0, "edge": -15.0,
	"scroll": -21.0, "page": -16.0, "preview": -12.0, "restore": -12.0,
	"refuse": -14.0, "value": -16.0, "toggle": -13.0, "follow": -13.0,
	"return": -14.0, "open": -16.0, "close": -16.0}
var _menu: Dictionary = {}


## Play a menu cue. `pitch` shifts it (a value's position; a key's place).
func menu_cue(kind: String, pitch := 1.0) -> void:
	if _menu.is_empty():
		_build_menu_cues()
	var player: AudioStreamPlayer = _menu.get(kind)
	if player == null:
		return
	player.pitch_scale = pitch
	player.play()


func _build_menu_cues() -> void:
	var streams := {
		"tick": _blip(1560.0, 0.022, 0.45),
		"detent": _click(170.0, 0.06),
		"edge": _blip(260.0, 0.05, 0.5),
		"scroll": _blip(1900.0, 0.014, 0.35),
		"page": _thud(88.0, 0.11),
		"preview": _arp([523.0, 784.0], 0.05, 0.32),
		"restore": _arp([784.0, 523.0], 0.05, 0.32),
		"refuse": _square_burst(110.0, 0.12, 0.26),
		"value": _blip(900.0, 0.024, 0.45),
		"toggle": _click(420.0, 0.05),
		"follow": _arp([392.0, 523.0, 659.0], 0.05, 0.3),
		"return": _arp([659.0, 523.0], 0.05, 0.3),
		"open": _arp([330.0, 440.0], 0.04, 0.26),
		"close": _arp([440.0, 330.0], 0.04, 0.26),
	}
	for kind: String in streams:
		var player := AudioStreamPlayer.new()
		player.stream = streams[kind]
		player.max_polyphony = 4
		player.volume_db = float(MENU_DB.get(kind, -14.0))
		# The menu plays while the world is paused behind it.
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_menu[kind] = player


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


func play(kind: String, pitch := 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(kind)
	if player != null:
		# ECHOES §12: a source game's sound family is a pitch shift of the
		# shared procedural bank, not a second sample. Set per play and
		# left set — the next caller states its own pitch, and the default
		# is the bank's own voice.
		player.pitch_scale = pitch
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
	# 16-bit samples: two bytes each, so the frame count is half the
	# byte count. `@warning_ignore` rather than a float cast because
	# truncation is the CORRECT behaviour here, not a tolerated one.
	@warning_ignore("integer_division")
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

## Streams for positional enemy audio. Enemies own their own 3D players
## (so you can hear WHERE a shot came from), but the waveforms are
## generated here and cached, not re-synthesized per enemy.
static var _enemy_cache: Dictionary = {}

static func enemy_stream(kind: String) -> AudioStreamWAV:
	if _enemy_cache.has(kind):
		return _enemy_cache[kind]
	var stream: AudioStreamWAV
	match kind:
		"aggro":                    # it has noticed you
			stream = _arp([180.0, 300.0], 0.05, 0.3)
		"shot":                     # ranged fires
			stream = _square_burst(340.0, 0.09, 0.32)
		"windup":                   # the brute commits
			stream = _synth(func(t: float) -> float:
				# A rising growl over the half-second telegraph.
				var freq := 60.0 + 90.0 * (t / 0.5)
				return sin(t * freq * TAU) * 0.42 * (0.4 + t / 0.5), 0.5)
		"slam":
			stream = _thud(44.0, 0.3)
		"melee_hit":
			stream = _square_burst(150.0, 0.07, 0.3)
		_:
			stream = _square_burst(220.0, 0.06, 0.25)
	_enemy_cache[kind] = stream
	return stream

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
