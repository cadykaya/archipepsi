extends Node
const ENTRY := preload("res://music/freight_bay_stingers/freight_bay_entry_stinger.wav")
const VICTORY := preload("res://music/freight_bay_stingers/freight_bay_victory_stinger.wav")
var t0 := 0.0
var log: Array = []
var stinger := AudioStreamPlayer.new()
func _ready() -> void:
	stinger.bus = &"Music"; add_child(stinger)
	for s in [ENTRY, VICTORY, load("res://music/shunter_horn/shunter-horn-tuned.wav")]:
		print("WAV len=", snappedf(s.get_length(), 0.001), " loop_mode=", s.loop_mode, " format=", s.format, " rate=", s.mix_rate)
	StationMusic._player.bus = &"Music"; FreightBayMusic._player.bus = &"Music"
	FreightBayMusic.state_changed.connect(_on_fb_state)
	print("station play=", StationMusic.play(), " state=", StationMusic.get_state_name(), " bus=", StationMusic._player.bus)
	await get_tree().create_timer(2.0).timeout
	print("station playing=", StationMusic._player.playing, " pos=", snappedf(StationMusic._player.get_playback_position(), 0.01))
	StationMusic.stop()
	print("freight play=", FreightBayMusic.play(), " state=", FreightBayMusic.get_state_name())
	t0 = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(1.0).timeout
	print("engage at ", snappedf(_now(), 0.01), " ->", FreightBayMusic.trigger_event("engage"))
	await get_tree().create_timer(9.0).timeout
	print("victory at ", snappedf(_now(), 0.01), " ->", FreightBayMusic.trigger_event("victory"))
	await get_tree().create_timer(5.0).timeout
	FreightBayMusic.stop(); print("RESTART: play ->", FreightBayMusic.play(), " state=", FreightBayMusic.get_state_name())
	for l in log: print("LOG ", l)
	get_tree().quit()
func _on_fb_state(id: String, at: float) -> void:
	var n: String = FreightBayMusic.get_state_name()
	if n == "Entry": stinger.stream = ENTRY; stinger.play()
	elif n == "Victory": stinger.stream = VICTORY; stinger.play()
	log.append([n, snappedf(at, 0.001), snappedf(_now(), 0.01), "stinger playing=%s" % stinger.playing])
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0 - t0
