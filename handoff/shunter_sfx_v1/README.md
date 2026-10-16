# Shunter sounds v1: handoff for Prod

The eight sounds D-20 §7.4 lists for the Shunter, built for the Freight Bay build.

| | Status |
|---|---|
| **Horn** | **Approved by Skyiah** (2026-10-16). It's the tuned freight horn from `approved_music_v1`, copied byte for byte (sha256 `3c706618…`). It hasn't changed. |
| **The other seven** | Candidates. Nobody has heard them in Archipepsi. Skyiah approves sounds by ear, so they stay unapproved until she has listened (preview below) and played against them. |

Your placeholders can stay until you're ready. When you swap, it's files and one folder, no code: `events.json` has the same shape as the five-weapon set, and `RangeAudio` loads it unchanged (see `verify/godot_check/`).

## Drop-in

1. Copy `wav/*.wav`, `wav/*.wav.import` and `events.json` into **`godot/audio/sigmaudio/shunter/`**, unchanged. Don't re-normalize, trim, resample or re-encode them. The sidecars import them as uncompressed PCM, with no trim, no normalize and no loop.
2. Load them with a second `RangeAudio` (`setup("res://audio/sigmaudio/shunter")`), or with your own loader that reads `events.json`. If your placeholder keys use other names, map them once:

   | D-20 name | Event | File | When it plays |
   |---|---|---|---|
   | horn | `shunter.horn` | `shunter_horn.wav` | entering **HORN** |
   | plough scrape | `shunter.plough_scrape` | `shunter_plough_scrape.wav` | entering **BRACE** |
   | rush | `shunter.rush` | `shunter_rush.wav` | entering **RUSH** |
   | crumple clang | `shunter.crumple_clang` | `shunter_crumple_clang.wav` | the rush ends on a pillar, wall or closed gate |
   | skid | `shunter.skid` | `shunter_skid.wav` | the rush ends on open floor or a crate; also at **DOWN** if it was rushing |
   | vent gust | `shunter.vent_gust` | `shunter_vent_gust.wav` | a heavy hit jolts it in **RECOVER** |
   | plume hiss | `shunter.plume_hiss` | `shunter_plume_hiss.wav` | entering **RECOVER** |
   | power-down | `shunter.power_down` | `shunter_power_down.wav` | entering **DOWN** |

3. **Play them at the Shunter.** Use `AudioStreamPlayer3D` so the player hears where it is. `RangeAudio.play_at()` already caps distance gain the right way.
4. **Two sounds need a handle, because the game stops them:**
   - `shunter.rush`: when the rush ends, for any reason, fade it over 25 ms on that frame, then play the end sound. A full 1.1 s rush tails off by itself.
   - `shunter.plume_hiss`: fade it over the **last 0.2 s of the recovery window**, the same moment the plume fades. The player hears the window closing. The file is 2.4 s long, so the 1.8 s window never runs out.

   On **DOWN**, stop both with a 25 ms fade on the same frame as `shunter.power_down`.

   `play_at()` doesn't return its player, so for these two keep an `AudioStreamPlayer3D` on the Shunter and fade its `volume_db` with a tween. That's the same 25 ms fade the Mass Driver charge uses.

### The timing each sound is built around (D-20 rev 2)

- **Horn:** it rings for 2.5 s, past the 0.6 s pose and into CLOSE. That's what Skyiah approved. It plays on the same frame as `FreightBayMusic.trigger_event("engage")`.
- **Plough scrape** (BRACE, 0.7 s): a hydraulic drop, then the lip touches the deck at +0.20 s (the plough reaches it at 0.25 s). Then a grind swells and rises to its loudest at +0.6 to 0.8 s, which is when RUSH starts. Let it run out under the rush. A broken brace may cut it with a 25 ms fade.
- **Rush:** the motors spool up in 0.3 s. Paired footfalls come every 0.27 s, and the lip skims the deck.
- **Crumple clang:** the plough hits steel. There's a crunch, the rebound at +0.16 s, and the steam burst D-20 lists (from +0.12 s). Then the plume starts with RECOVER.
- **Skid:** the nose digs in, then a grind that **falls** in pitch. The scrape **rises**, so the warning and the miss never sound alike.
- **Vent gust:** the flaps bang and a short, bright gust comes out. If you want one sound for every heavy jolt, it works for WORK and CLOSE jolts too.
- **Power-down:** a relay clunk, then the hydraulics sigh. The pump and drive spin down over about 2.2 s, and the body settles onto the deck at +2.25 s. It plays on the same frame as `FreightBayMusic.trigger_event("victory")`.

## Mixing

- **Everything here goes on the SFX bus, never on Music.** No music effects on it, and the music never ducks it, as `approved_music_v1` says for the horn.
- **The files are level-matched to the approved horn.** Play them all at one `volume_db` and trim the bus. The horn is the loudest thing the Shunter says. The brace scrape is its other warning, so it sits only 2 LU under it.

| Sound | Momentary max (LUFS) | vs horn | Peak (dBFS) | Length (s) | Energy above combat music* |
|---|---|---|---|---|---|
| horn (approved) | −12.4 | 0 | −1.0 | 2.5 | 81 % |
| plough scrape | −14.4 | −2 | −1.7 | 1.1 | 76 % |
| crumple clang | −13.4 | −1 | −7.8 | 2.4 | 83 % |
| rush | −15.4 | −3 | −6.0 | 1.3 | 61 % |
| power-down | −15.4 | −3 | −2.1 | 3.4 | 66 % |
| skid | −16.4 | −4 | −2.3 | 1.25 | 67 % |
| vent gust | −19.4 | −7 | −7.6 | 0.75 | 80 % |
| plume hiss | −20.4 | −8 | −12.3 | 2.4 | 56 % |

\* The share of each sound's spectrogram energy that lies in bins where it's louder than the Freight Bay combat loop. That's with the music as loud as the horn, the floor `approved_music_v1` sets, taking the worst of eight starting points (`source/clarity.py`). It's a stricter window than the music handoff used for its 98 % horn figure, so compare these numbers with the horn's 81 % here, not with that one. The two warnings, horn and scrape, are the clearest of the gameplay-critical sounds. The plume is the quietest on purpose, because the visible plume carries most of that cue.

No limiting was needed: every file reaches its level with its peaks under −1 dBFS.

**Telling attacks apart.** The Shunter's warnings are a recorded freight horn and a metal grind centred near 5 kHz. The only other enemy wind-up in the game today is the brute's synthesized sine growl at 60–150 Hz (`tones.gd`, `windup`), which shares neither the timbre nor the range. Every new family's warning should be checked against these two.

## Listening preview

`reference/shunter-sounds-preview.m4a` (48 s) comes in two parts, with timestamps in `reference/shunter-sounds-preview.cues.json`:
1. **0:00, each sound alone:** horn, scrape, rush, clang, skid, gust, plume (faded as the game would) and power-down.
2. **0:24, a fight sketch over the Freight Bay combat loop**, with the music as loud as the horn. A horn, then a rush into a pillar, a heavy hit during recovery, a rush that misses, and a rush cut short by the power-down. It follows D-20's timings, but it's a sketch, not the game.

Don't ship it.

## Rebuilding

`source/build.py` makes all seven from the recordings in `source/raw/`. Copy `wav/shunter_horn.wav` into an empty output folder first, because the levels are measured against it. Then run `python3 -I build.py raw OUT`. You need Python 3 with numpy and scipy, plus ffmpeg. The rebuild is byte-identical: it was checked against these files. `preview.py`, `clarity.py` and `check.py` make the preview and the measurements. Each sound is one function in `build.py`, with comments, so a v2 can change one sound and leave the rest alone.

## Sources

All 14 recordings are **CC0 1.0** from Freesound. They're the same recordings and licence checks as the Freight Bay music. See `SOURCES.md` and `sample-manifest.json`, which give the cut and edit for every use. No game audio, no YouTube audio and no CC BY material, so no attribution is owed. The creators are credited anyway.

## Files

| Path | What it is |
|---|---|
| `wav/` | The eight game files plus Godot import sidecars. Only these and `events.json` go in the game. |
| `events.json` | Events, files, triggers and voices, as data. |
| `measurements.json` | Loudness and peaks, as `build.py` measured them. |
| `SOURCES.md`, `sample-manifest.json` | The source and licence of every recording, and what was cut from it. |
| `source/` | The build, preview, measurement and check scripts, plus the raw recordings. |
| `reference/` | The listening preview, its cue list and the clarity output. Don't ship them. |
| `verify/godot_check/` | The headless Godot 4.5.1 load check, and what it printed. |
| `CHECKSUMS.sha256` | A hash of every file in this folder, as committed. Git is the canonical copy: the shared project folder adds metadata to WAVs. |
