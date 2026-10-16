# Approved music for the first unified build, v1

*2026-10-16. From Condi, for Prod. Handoff only: this folder is never merged, and nothing in `godot/` was changed.*

This is the music Skyiah has approved, packed so you can drop it into the unified build. There's no new music in here and nothing was re-rendered. Every composition is the file Skyiah heard.

**What's been checked, and what hasn't.** Both cues and the stingers were imported into a throwaway Godot 4.5.1 project (not Archipepsi) and driven headless through a whole Shunter fight. `verify/godot_check/` re-runs that. It shows that the files import, play, and change state on the authored beats. **Nobody has heard any of this inside Archipepsi.** That's the next step, and it's yours and Skyiah's.

## What's in here

| Folder | What it is | Approved |
|---|---|---|
| `station/sigmaudio_pack/` | **Station music.** The Explore state of *One Note Apart: Crossing*. A SigmAudio Godot pack: 7 stems, the main loop, `manifest.json`, the runtime script and the WAV import sidecars. | Skyiah loved it on 2026-10-10 and placed it on the station on 2026-10-14. **Only the Explore state is approved for the station.** |
| `freight_bay/sigmaudio_pack/` | **Freight Bay music** for the Shunter encounter. Exploration and combat loops as 4 stems, plus the states and transitions in `manifest.json` and the runtime. | "its good!" (Skyiah, 2026-10-13) |
| `freight_bay/stingers/` | The **combat-entry** and **victory** stingers, the mixed versions the game plays. | Same approval |
| `freight_bay/stingers/per_track/` | The same stingers as SigmAudio rendered them, one track per file (15 files), with their manifest. These are for re-mixing only, so the game doesn't need them. | |
| `freight_bay/machinery_kits/` | The six machinery sample kits (`bay*`) the Freight Bay music is built from, with their import records. They're for rebuilding the music in SigmAudio, so the game doesn't need them. | |
| `freight_bay/shunter_horn_reference/` | The freight-horn recording used as the Shunter's horn in the preview Skyiah approved, untouched and tuned. See "The Shunter's horn". | It's in the approved preview, but it isn't approved as a game sound effect. |
| `freight_bay/SOURCES.md`, `sample-manifest.json` | Source and licence for every recording. | |
| `*/editable/` | The editable SigmAudio projects and the source that generates them. | |
| `*/reference/` | Listening references (m4a), the composer's notes and the preview tools. Don't ship them. | |
| `events.json` | The hooks below, as data. | |
| `CHECKSUMS.sha256` | A hash of every file in this folder, as committed. | |
| `verify/godot_check/` | The headless Godot check. | |

## Install

Copy these **before Godot opens the project**, so that the `.wav.import` sidecars are used. Keep each pack's inner folders as they are. The pack folder itself can be renamed or moved.

| From this handoff | To the game (suggested paths) |
|---|---|
| `station/sigmaudio_pack/*` | `res://audio/music/station/` |
| `freight_bay/sigmaudio_pack/*` | `res://audio/music/freight_bay/` |
| `freight_bay/stingers/*.wav` and `*.wav.import` (the top level only) | `res://audio/music/freight_bay_stingers/` |

Then:

1. **Two autoloads**, one per cue:
   ```
   StationMusic="*res://audio/music/station/godot/sigmaudio_cue.gd"
   FreightBayMusic="*res://audio/music/freight_bay/godot/sigmaudio_cue.gd"
   ```
   The pack READMEs say to name the autoload `SigmAudioCue`. With two cues, you need two names. The scripts have no `class_name` and find their WAVs relative to themselves, so the two coexist. The check loads both side by side.
2. **A Music bus.** The game has no `default_bus_layout.tres` yet. Each runtime makes its own `AudioStreamPlayer` on Master, so after the autoloads are ready, route them:
   ```gdscript
   StationMusic._player.bus = &"Music"
   FreightBayMusic._player.bus = &"Music"
   ```
   The stinger player goes on Music too. The Shunter's horn and everything else in gameplay stay off it (see "Mixing").
3. **Don't touch the pack WAVs.** Don't re-render, normalize, trim, resample or re-encode them. The runtime refuses a stem whose frame count, bit depth or rate differs from `manifest.json`. If Godot already imported them with other settings, reimport using the sidecars: 16-bit PCM, Forward loop, no trim, no normalize.

Nothing plays by itself. You start it.

## Station

```gdscript
StationMusic.play()   # the player is in the station
StationMusic.stop()   # they leave for somewhere with its own music
```

That's the whole station integration. `play()` starts in **Explore**, the approved calm exploration music: a 25.6 s seamless loop at 150 BPM. The main loop file is that state's mix (it matches the Floor and Echoes stems to −59.7 dB, which is 16-bit rounding).

**Never call `set_parameter` on `StationMusic`.** Its `threat` and `style` parameters drive the same cue's Combat, Climax and Resolution states. Those are *One Note Apart*, which Skyiah reserved for a hacking or technical-puzzle situation, and they aren't approved for the station. If both parameters stay at their default of 0, the cue stays in Explore forever.

## Freight Bay

All of it is one cue with four states (Exploration, Entry, Combat, Victory) and two game events (`engage`, `victory`). The runtime runs the authored rules. The game only fires the two events and plays the two stinger files.

| When | Call |
|---|---|
| The player enters the Freight Bay | `StationMusic.stop(); FreightBayMusic.play()`. This starts **Exploration**. |
| **The Shunter enters HORN** (it noticed the player, and the horn sounds) | `FreightBayMusic.trigger_event("engage")` |
| `state_changed` reports **Entry** | Play `freight_bay_entry_stinger.wav` once. |
| *(automatic)* | Entry becomes **Combat** exactly where the stinger's two bars end. |
| **The Shunter goes DOWN** | `FreightBayMusic.trigger_event("victory")` |
| `state_changed` reports **Victory** | Play `freight_bay_victory_stinger.wav` once. |
| *(automatic)* | Victory goes back to **Exploration**, fading in over 4 beats under the stinger's tail. |
| RESTART, or the player dies | `FreightBayMusic.stop(); FreightBayMusic.play()`. This restarts in Exploration. |
| The player leaves the Freight Bay | `FreightBayMusic.stop(); StationMusic.play()` |

The stinger hookup:

```gdscript
const ENTRY := preload("res://audio/music/freight_bay_stingers/freight_bay_entry_stinger.wav")
const VICTORY := preload("res://audio/music/freight_bay_stingers/freight_bay_victory_stinger.wav")
var stinger := AudioStreamPlayer.new()   # bus = &"Music"; add_child(stinger)

func _ready() -> void:
	FreightBayMusic.state_changed.connect(_on_freight_bay_state)

func _on_freight_bay_state(_id: String, _boundary: float) -> void:
	match FreightBayMusic.get_state_name():
		"Entry":
			stinger.stream = ENTRY
			stinger.play()
		"Victory":
			stinger.stream = VICTORY
			stinger.play()
```

**Timing, which is intentional.** Everything waits for the next two-bar line (3.33 s at 144 BPM), so the music answers the horn **0 to 3.3 s after `engage`**. The Shunter's horn pose is 0.6 s (D-20), so the entry stinger usually lands while it's closing in. That was the design: the horn plays during the wait, and the music answers it. Waiting on the line is also what makes the horn's B resolve onto combat's E. In the headless check, `engage` at 1.0 s became Entry at 3.333 s and Combat at 6.667 s. `victory` fired right at the 10.0 s line, too late to make it, so it became Victory at the next line, 13.333 s. The runtime commits on engine frames, so it's accurate to a frame, not to a sample.

**`stingers` stem.** It's silent on purpose (SigmAudio's pack keeps a layer that only holds stinger tracks). Leave it in. The runtime expects all four stems.

**Every state, transition and fade is in `manifest.json`**, and `events.json` lists them. Please don't change them without asking Skyiah.

## Mixing

All the music files share one gain, so their **relative levels are the mix**. Set the overall level on the Music bus, not per file.

| File | Integrated loudness | Peak |
|---|---|---|
| Station loop (Explore) | −29.8 LUFS | −16.5 dBFS |
| Freight Bay exploration | −29.8 LUFS | −15.4 dBFS |
| Freight Bay combat (composer's measurement) | −20.6 LUFS | |
| Entry stinger | −19.2 LUFS | −5.2 dBFS |
| Victory stinger | −21.1 LUFS | −6.8 dBFS |

- **The exploration music is meant to sound quiet.** It sits about 9 dB under combat on purpose, to leave room for puzzles and thinking.
- **Music bus headroom: about +4 dB.** SigmAudio exports are quiet, so you'll probably want to raise the Music bus. Past about +4 dB, the entry stinger's peak clips. If it needs more than that, put a Limiter on the Music bus rather than raising files.
- **Weapons.** Freight Bay combat has about 2 dB more energy at 2 to 5 kHz than Overclock round 2, which is where gunfire lives. If the guns get masked, duck the Music bus under weapon fire. Godot's Compressor on Music, with its sidechain set to the SFX bus, does that. This is optional and your call.

### The Shunter's warning horn stays clear

- **Keep the horn on the SFX bus**, never on Music, with no music effects on it, and never ducked by the music.
- **Don't let the music duck under it either. It doesn't need it.** The composer mixed the horn recording against this music and measured how much of the horn's energy sits above it:
  - over exploration: 100%;
  - over combat at an equal level: 98%;
  - over combat with the horn **5 dB quieter**: 93%;
  - in the worst case, the horn firing right on the entry stinger's first bar: 97%.

  Set the horn at least as loud as the combat music, and it stays well clear.
- **The music was written to leave it room.** Nothing in the music is that horn. The musical "air horn" is a different recording and always doubles the guitar. The entry stinger keeps the horn's range open in its first bar. The music is in E minor, and the horn's chord (B major) is that key's dominant, so it never clashes.

### The Shunter's horn

The game has no horn sound yet (D-20 lists it as a labelled placeholder). `freight_bay/shunter_horn_reference/` holds the CC0 freight-train horn that stood in for it in the preview Skyiah approved:
- `shunter-horn-original.wav` is the recording, untouched;
- `shunter-horn-tuned.wav` has each of its tones tuned to D♯, F♯ and B, which is what the preview used.

Its tones sit in B major, which ties the horn to the theme. **Whether it becomes the Shunter's sound is your and Skyiah's call. It isn't approved as a game sound.** If you use it:
- it's 2.5 s, longer than the 0.6 s pose, so it rings into CLOSE;
- if the game uses some other horn, tuning it to B major, or at least to B, keeps the link.

Skyiah's idea that the Shunter *itself* makes the stinger sound as the music turns to combat is recorded, but it **wasn't commissioned**. Please don't build it unless she asks.

## Open points for Prod

1. **The Shunter losing interest.** If the player is more than 18 m away for 4 s, the Shunter goes back to work. The music has no authored path from Combat back to Exploration except `victory`. **Default: leave the music in Combat.** The Shunter is still dangerous, and it's quick to notice again. If that feels wrong in play, tell Skyiah. `set_state("Exploration", "phrase")` would do it with the existing API, but that's a new transition, so it's her decision.
2. **Where "entering the Freight Bay" is.** That's the hook for `play()`, and only you know the trigger.
3. **The paths, autoload names and bus names** above are suggestions. Rename them freely, and keep `events.json` in step if you do.
4. **Overlap with other music.** Only these two cues exist. Crossings, Forge, combat elsewhere and menus have no approved music yet, so leave them silent rather than reusing these pieces there.

## Files and checksums

- **Git is the canonical copy.** `CHECKSUMS.sha256` covers every file here as committed. Check it with `sha256sum -c CHECKSUMS.sha256` from this folder.
- **The WAVs carry a C2PA provenance chunk** after the audio. It was added by the project's shared file storage. Godot ignores it, and it imported cleanly in the check. For the 28 files SigmAudio hashed at export (both packs' loops and stems, and the 15 per-track stinger renders), the audio as SigmAudio wrote it, with that one trailing chunk left out of the hash, **matches SigmAudio's recorded hash in every case**. The script is `verify/audio_hashes.py`.
- **Found broken, and fixed:** the two mixed stingers were written as WAVE_FORMAT_EXTENSIBLE. Godot 4.5.1 refuses that ("Format not supported for WAVE file (not PCM)"). The files in `stingers/` are plain-PCM copies, still 24-bit at 48 kHz. Their sample data is **byte-for-byte the original** (checked by hashing the decoded frames). The originals are kept in `stingers/original_24bit_extensible/`. The new sidecars import them as uncompressed PCM with no loop. Godot's default would have been QOA compression.

## Licences

| What | Licence |
|---|---|
| Station music | SigmAudio's built-in synthesis and bundled instruments. No recorded samples (`manifest.json` `userSamples` is empty). |
| Freight Bay machinery | 14 Freesound recordings, each **CC0 1.0**, checked on its own page on 2026-10-13. `freight_bay/SOURCES.md` and `sample-manifest.json` list each one's link, creator and edits. |
| Freight Bay guitars | *Black And Green Guitars* by Karoryfer Samples, **CC0 1.0** (the Overclock round-2 kits). |
| Freight Bay drums | SigmAudio's bundled public-domain `rockKit`. |
| Shunter horn reference | kyles, "freight train horn and approach pass near" (Freesound 454025), **CC0 1.0** |

No CC BY material and no YouTube audio is used, so no attribution is owed. Every creator is credited in `SOURCES.md` anyway. The raw Freesound downloads behind the kits stay in the project's shared folder (`music-audition/freight-bay/sample-kits/prep/raw-downloads/`), and `machinery_kits/IMPORT.md` explains how to rebuild.

## Not in this handoff

- Overclock, Tango, Night Shift, Maintenance Hours and *One Note Apart*'s other states. They aren't part of this build, and none of them was touched.
- The five weapon sounds. They're still in draft PR #34, awaiting Skyiah's hands-on test in the range.
- Any change to gameplay, to the Shunter, or to an audio engine.
