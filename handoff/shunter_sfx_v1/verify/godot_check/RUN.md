# Headless Godot check

What was run on 2026-10-16 with the official Godot 4.5.1 Linux build:

1. a scratch project with `project.godot` and `check.gd` from here;
2. `scripts/range_audio.gd` copied unchanged from `integration/unified-1` (86f26f11);
3. `../../wav/*` and `../../events.json` copied into `res://audio/sigmaudio/shunter/`;
4. `godot --headless --import --path .`, then `godot --headless --path . --script res://check.gd`.

Output:

```
LOADED (8, 8)
shunter.horn len=2.5 rate=44100 stereo=false fmt=1 loop=0
shunter.plough_scrape len=1.1 rate=48000 stereo=true fmt=1 loop=0
shunter.rush len=1.3 rate=48000 stereo=true fmt=1 loop=0
shunter.crumple_clang len=2.4 rate=48000 stereo=true fmt=1 loop=0
shunter.skid len=1.25 rate=48000 stereo=true fmt=1 loop=0
shunter.vent_gust len=0.75 rate=48000 stereo=true fmt=1 loop=0
shunter.plume_hiss len=2.4 rate=48000 stereo=true fmt=1 loop=0
shunter.power_down len=3.4 rate=48000 stereo=true fmt=1 loop=0
```

So RangeAudio loads all eight events from this folder with no code change, as uncompressed 16-bit PCM with no loop. This proves import and loading only. Nobody has heard these in Archipepsi.
