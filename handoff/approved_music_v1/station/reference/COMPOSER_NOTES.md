# One Note Apart: Crossing, an interactive prototype

*2026-10-10. Composed with SigmAudio `main` (a161391) using its own layers, states and transitions. No SigmAudio or Archipepsi code was changed, nothing was pushed, and the round 1 and round 2 pieces are untouched.*

**I can't listen.** Everything below is a measurement or a composer reading the score. Whether the transitions *feel* right is the question only you can answer.

## Listen in this order

1. `00-interactive-preview`, 2:04. A scripted play session with nine state changes (timeline below).
2. `states/01-explore` to `03-climax`. Each state's full 16-bar loop on its own.
3. `states/04-resolution-from-climax-back-to-explore`. The last phrase of a climax, the truce, then the echoes coming back.

All files share **one** gain, so the quiet states are as quiet as they'd be in the game. Explore sits 12 dB under the climax on purpose. On a phone it will sound faint next to the others.

## The idea

One Note Apart was already about two worlds arguing over one note, the synth world's G against the old world's G♯. The states became chapters of that argument:

| State | What you hear | Why |
|---|---|---|
| **Explore** | An E pedal (hurdy-gurdy), a soft machine pulse, and the cell (E B A♯ F♯) in fragments: the synth asks and lands on G, and a distant horn answers a phrase later with G♯ | The worlds are far apart. There's lots of space, every note is written below 500 Hz, and there are long rests for puzzle thinking. The two notes are never written in the same bar. |
| **Combat** | The riff, drums, and the two bands trading phrases, then single bars, then half bars, then a scale run that holds both notes | The argument in the open. Each world's chords sound only under its own phrases. |
| **Climax** | One band: the hook in octaves, the old world's G♯ voiced low and the synth world's G voiced high, at once, over E7♯9. Every phrase starts with a timpani hit | The payoff. It's the only state where both notes are written together. |
| **Resolution** | An open-fifth chord, with no third at all, then the horn and synth play the cell **in unison** | A truce. The argument is set down, and then the echoes return. |

**Making it earned.** Explore teaches the cell slowly, and combat makes the two notes fight. The climax can only be reached *from* combat, and it waits for a phrase boundary, so it always lands on a downbeat with a hit. It never comes from nowhere.

**The engine riff has no third.** The original riff walked through the third, which would have taken a side. Here it walks through the second (F♯), so the same engine sits under both the argument and the union.

## How it works in SigmAudio, exported vs. not

Everything below is SigmAudio's **existing** vertical layering. I didn't build any engine.

- **Seven layers:** Floor, Echoes, Engine, Drums, Argument, Payoff, Truce. Each one is a stem, and all seven are the same 25.6 s (16-bar) loop, phase-locked.
- **Four states**, each a set of layers:
  - Explore = Floor + Echoes.
  - Combat = Floor + Engine + Drums + Argument.
  - Climax = Floor + Engine + Drums + Payoff.
  - Resolution = Floor + Truce.
- **Two game parameters:**
  - `threat` (0–1): are enemies engaging?
  - `style` (0–1): a stand-in for a DMC-like style meter.
- **Seven authored transitions,** which export into `manifest.json` and the Godot runtime:

| From → to | When | Waits for | Fade |
|---|---|---|---|
| Explore → Combat | threat ≥ 0.5 | next bar | 1 beat |
| Combat → Climax | style ≥ 0.8 for 1 s, after 3.2 s of combat | next **phrase** | none (lands on the hit) |
| Climax → Combat | style ≤ 0.5 for 2 s, after 6.4 s of climax | next bar | 2 beats |
| Combat or Climax → Resolution | threat ≤ 0.1 for 1.5 s | next **phrase** | none (cut onto the truce chord) |
| Resolution → Explore | automatically, after 2 bars | next bar | 4 beats |
| Resolution → Combat | threat ≥ 0.5 (a new fight) | next bar | 1 beat |

Why these numbers:
- A fight should start when the player starts it, so it gets a bar's wait and almost no fade.
- The payoff and the ending wait up to one phrase (6.4 s), because landing on a downbeat is what makes them feel like music and not a switch.
- The way out of resolution fades slowly, so the quiet comes back gently.

### The preview's timeline

| Time | Change | Requested at | Why |
|---|---|---|---|
| 0:33.6 | Explore → Combat | 0:33.0 | enemies appear |
| 0:51.2 | Combat → Climax | 0:46.0 | style reaches 0.8 (waits 5.2 s for the phrase) |
| 1:05.6 | Climax → Combat | 1:04.5 | player takes a hit |
| 1:10.4 | Combat → Climax | 1:10.0 | style back up; enters on the phrase that starts with the A–G♯–G line |
| 1:23.2 | Climax → Resolution | 1:23.0 | last enemy dies |
| 1:26.4 | Resolution → Explore | automatic | |
| 1:39.2 | Explore → Combat | 1:39.0 | a second fight, entering on purpose at the worst spot: bar 15, the half-bar argument |
| 1:48.8 | Combat → Resolution | 1:48.0 | fight over, no climax this time |
| 1:52.0 | Resolution → Explore | automatic | |

## What I measured

| State | Loudness | True peak | Share of energy at 2–5 kHz |
|---|---|---|---|
| Explore | −29.8 LUFS | −16.5 dBTP | −21.0 dB |
| Resolution | −24.7 LUFS | −1.6 dBTP | −16.1 dB |
| Combat | −20.8 LUFS | −4.7 dBTP | −18.3 dB |
| Climax | −17.5 LUFS | −1.9 dBTP | −15.3 dB |

- **Room for weapons and enemies.** 2–5 kHz is where gunfire, enemy calls and alarms live, and where your ear is most sensitive. Combat puts 5.6 dB less of its energy there than round 2's One Note Apart (−12.7 dB), and 9 dB less than round 1's (−9.3 dB). There are no cymbals or open hats in combat. The leads are EQ'd at 3.2 kHz.
- **The argument is real in the audio, not just the score.** Per-bar pitch analysis of the Argument stem shows G dominant in the synth's bars (0.71–0.79 against G♯ 0.16–0.19) and G♯ dominant in the horn's (G♯ 1.0, G 0.10). The Payoff stem shows both together in every E bar (G 0.45–0.85, G♯ 0.40–0.63).
  - One honest catch: the distorted engine bass produces a faint G♯ as an overtone of its low E (about 0.25 relative), so in the full combat mix both notes register weakly. That's physics, not a written note.
- **The preview simulation matches SigmAudio exactly.** SigmAudio's own Explore render and my sum of the Floor and Echoes stems differ by −91.6 dB.
- **No dropouts.** I checked every file for a 20 ms window more than 12 dB below its surroundings and found none.

## Limitations, which I'm not hiding

1. **SigmAudio can't render a sequence of state changes to audio.** Its scenario replay plays only inside its editor or in Windows Godot with a native extension, and neither exists in this container. The docs say so plainly (`docs/SCENARIO_AUDIO_REPLAY.md`). So `preview-tool/preview.py` is a short offline simulation of the exported runtime: it plays SigmAudio's own stems on one clock, waits for each authored quantize point and fades linearly over the authored beats. Two things it doesn't do:
   - It doesn't evaluate parameters. Each request time in the scenario files is the moment the game condition would be met, holds included.
   - It isn't the Godot runtime. Godot fades on engine frames, not sample-accurately, so the real thing can differ by a frame or so.
2. **Horizontal resequencing isn't exported.** SigmAudio has intro/loop/outro sections, bridges and exit points, but they are editor-only and "not enacted" in the Godot pack. That's why Resolution is a *state* holding a 4-bar cadence repeated four times, so it lands correctly from whichever phrase it starts on, and not a true one-shot ending. Stingers would be the other route, but in Godot they play immediately (no quantize), which would put the ending off the beat.
3. **Nothing can sustain across the loop seam.** SigmAudio cuts every note at the cue end (`src/model/events.ts:36`). I measured held notes falling silent about 0.7 s before the cue end (about 0.3 s before their end mid-cue). Round 1's pauses had the same family of cause. My first render had a 0.7 s hole in the pedal at every loop. The fix is musical: the pedal lets go halfway through bar 16, and the pulse winds up in 16ths into the downbeat, so the seam is a written breath and not a gap.
4. **State changes can't alter the tempo,** so all four states share 150 BPM. Explore's calm comes from space and register, not a slower beat.
5. **The climax can wait up to 6.4 s** after the style meter tips over, because it waits for a phrase boundary. I think the downbeat is worth it, but it's a design choice you might reverse: set its quantize to `bar`.

## Using it

- **In Godot (not tested by me, and nothing in Archipepsi was touched):** the `sigmaudio-export/` folder is SigmAudio's standard pack, with seven stems, `manifest.json` and `godot/sigmaudio_cue.gd`. Its README covers setup. The game calls:
  - `SigmAudioCue.set_parameter("prm_00000001nkxz0sydtp7w11", threat)`
  - `SigmAudioCue.set_parameter("prm_00000001nm8t1yfwcaqfbk", style)`

  The authored rules then do the rest.
- **To edit:** change `editable-project/source/crossing.mjs` and rebuild with `node build.mjs crossing.mjs starter.json out.json` from the SigmAudio folder (`V=1` gives the first draft). The project opens in SigmAudio and passed `validate-project`. Copy it out of this shared folder first, because the CLI refuses symlinked folders.
- **To try other play sessions:** edit `preview-tool/scenarios/preview.json` and run `python3 preview.py <project.json> <stems folder> <scenario.json> out.wav`.

## Draft history

1. **Draft 1:**
   - Explore measured −40 LUFS, 19 dB under combat: restrained to the point of absent. Draft 2 lifts the floor by 9 dB, the echoes by 12 and the truce by 3.
   - A single 25.6 s pedal note died at 22.5 s. Draft 2 uses two alternating drone tracks that overlap by a bar.
2. **Draft 2:** the seam hole above, fixed by writing the wind-up.
