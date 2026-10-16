extends SceneTree
func _init() -> void:
	var audio := preload("res://scripts/range_audio.gd").new()
	root.add_child(audio)
	audio.setup("res://audio/sigmaudio/shunter")
	print("LOADED ", audio.loaded())
	for name: String in audio.events:
		var s: AudioStreamWAV = audio.events[name]["streams"][0]
		print(name, " len=", snappedf(s.get_length(), 0.001), " rate=", s.mix_rate, " stereo=", s.stereo, " fmt=", s.format, " loop=", s.loop_mode)
	quit()
