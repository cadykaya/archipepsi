# The Freight Bay: four parts for the Shunter fight

*2026-10-13. A compositional prototype for Skyiah to hear first. It was made with SigmAudio, using its own states, transitions and stingers. Archipepsi wasn't touched, and no SigmAudio code was changed. Nothing was committed or pushed. One Note Apart, Tango and both Overclock rounds are untouched.*

**I can't listen.** Everything below is either a measurement or a composer reading the score.

## Listen

1. **`00-full-sequence-preview`** (1:32). This is the whole sequence:

   | Time | What happens |
   |---|---|
   | 0:00 | The bay at work: exploration |
   | 0:24 | The Shunter notices you and sounds its horn |
   | 0:26.7 | The entry stinger |
   | 0:30 | Combat |
   | 0:47 | The horn again as it charges, to show it cutting through the fight |
   | 1:04 | It goes down |
   | 1:06.7 | The victory stinger |
   | 1:10 | The bay fades back in under the stinger's tail |

   The horn here is the real freight-horn recording standing in for the game's sound effect. `00-full-sequence-preview-music-only` is the same sequence without it.
2. **`parts/`**: the four parts on their own.
   - `01-exploration-loop`
   - `02-combat-entry-stinger`
   - `03-combat-loop`
   - `04-victory-stinger`

   Both loops are seamless at 26.7 s.

All files share one gain. Exploration sits at −29.8 LUFS, within a dB of the Crossing prototype's and Overclock's exploration, so it's meant to sound quiet.

## The idea

**The room sets the tempo.**
- The stamping press in the recording strikes every 0.31 s. That's a dotted eighth at **144 BPM**, so 144 is the tempo.
- The press's 3+3+3+3+4 stroke pattern is the groove in exploration.
- In combat, the riff's power chords land on those same strokes. The fight takes over the machine's rhythm.

**The Shunter's horn is the dominant.**
- The freight horn sounds a **B major chord** (D♯, F♯, B). B major is the dominant of **E minor**, the key of everything here.
- So the horn never sounds out of place. It always sounds like it wants to go somewhere, and the combat riff is where it goes.

**The motif is the horn's signal: long, long, short, long.**
- **Exploration:** a far-off bell plants it, slowly, twice per loop: B, B, D♯, E.
- **Entry stinger:** the full band plays it on the horn's own chord.
- **Combat:**
  - the lead guitar plays it on C, D and F;
  - on the B bars, the lead guitar and the whole band play it together on the horn's chord;
  - a tuned industrial air horn doubles the lead, so the machines sing the theme too.
- **Victory:** the same signal finally lands on **E**, in E major.

| Part | Length | Loudness | What it is |
|---|---|---|---|
| Exploration loop | 16 bars, 26.7 s | −29.8 LUFS | The bay at work. Press strokes (3+3+3+3+4), die clanks, valve puffs, a struck plate every phrase, the conveyor, the electric motor tuned to E, a hydraulic lift sighing E to F and back, a soft pulse, and the bell. |
| Combat-entry stinger | 2 bars, 3.3 s, plus tail | −19.2 LUFS | **Bar 1:** the machines speed up. Press strokes go from quarters to sixteenths, the motor spins up chromatically from E to B, and muted chugs crescendo. **Bar 2:** the horn's signal as band hits on B major, with impacts, a pneumatic-hammer roll and a snare roll into combat's first E. |
| Combat loop | 16 bars, 26.7 s | −20.6 LUFS | The riff on the press strokes: E, E, F (the Phrygian grind), E, G. The two recorded hollowbodies from Overclock round 2 are double-tracked. A rock kit carries the punch with the machine kit layered on the same hits (press stroke on the kick, hydraulic cutter on the snare, die clanks and air puffs). Drive bass, a synth arpeggio and the hook. |
| Victory stinger | 4 bars, 6.7 s, plus tail | −21.1 LUFS | An E major chord with a heavy boom and a big pressure-release sigh. The signal lands on E, then G♯, then E. In bars 3 and 4 the press and motor restart softly, and exploration fades back in under them. |

Combat is within about 1 dB of Overclock round 2's combat, so the two can share a mix.

## How the parts connect in SigmAudio

Everything is one SigmAudio cue with four states:

| State | What plays |
|---|---|
| Exploration | Bay + Exploration layers |
| Entry | Bay layer only |
| Combat | Bay + Combat layers |
| Victory | Bay layer only |

The two stingers are SigmAudio stingers fired by two game events, `engage` and `victory`.

| When | Waits for | What happens |
|---|---|---|
| The game fires `engage` (as the horn sounds) | the next two-bar line | The entry stinger starts. At the same moment the state cuts to Entry, so the exploration groove stops dead under it. |
| 3.0 s into Entry | the next two-bar line, which is exactly where the stinger ends | Combat starts with no fade. |
| The game fires `victory` | the next two-bar line | The victory stinger starts, and the state cuts to Victory. |
| 3.0 s into Victory | the next two-bar line | Exploration fades back in over one bar, under the stinger's second half. |

**Why two-bar lines.** All states share one timeline, so combat starts wherever the loop happens to be. I made a phrase two bars long and wrote combat so that **every odd bar is E**. Entry starts on a two-bar line and lasts two bars, so combat always starts on an odd bar, and the horn's B always resolves to E.

The cost is the wait: the entry waits **0 to 3.3 s** after `engage`. In the preview it's 2.7 s, which is about how long the horn itself lasts. So the horn plays during the wait, and the music answers it.

## The horn stays clear

I mixed the horn into the music at a fixed level and measured how much of its energy sits above the music, frequency by frequency:

| Where the horn sounds | Horn's energy above the music | Median margin |
|---|---|---|
| Over exploration | 100% | +24 dB |
| Over combat, horn about as loud as the music | 98% | +14 dB |
| Over combat, horn **5 dB quieter** than the music | 93% | +8 dB |
| Landing on the entry stinger's first bar (the worst case: the horn fires right on a two-bar line) | 97% | +15 dB |

The horn's tones are steady, and the music around them isn't, which is why it reads so clearly. Three things in the writing keep it that way:

1. **Nothing in the music is that horn.** The musical horn is a different recording, an industrial air horn split to one tone and tuned. It always doubles the lead guitar, 13 dB under the combat mix.
2. **The entry stinger keeps the horn's range open in bar 1.** Its motor is low-passed at 500 Hz, and its first chord hit waits for bar 2.
3. **The horn is in the key,** so it never clashes with the music.

The original freight horn's F♯ is 35 cents sharp. `sfx-reference/shunter-horn-tuned.wav` is the same recording with each of its three tones tuned to D♯, F♯ and B; the preview uses it. `shunter-horn-original.wav` is untouched. If the game has its own horn, tuning it to B major, or at least to B, keeps the connection.

## Machinery as music

20 recordings were downloaded and checked. 14 of them became 15 instrument sounds, and the freight horn became the sound-effect reference. All are CC0, and **`SOURCES.md`** lists each one with its link, creator, licence and exactly what was done to it. `sample-manifest.json` has the same as data.

- **`bayMachine` kit:**
  - kick = one stroke of a stamping press;
  - snare = a hydraulic metal cutter's crunch;
  - clap = an air puff;
  - closed hat = the press's die clank;
  - open hat = a valve hiss;
  - ride = a struck metal plate.
- **`bayHeavy` kit:** heavy metal impacts, a pneumatic-hammer burst and a 3.6 s pressure release.
- **`bayHorn`:** an industrial air horn with its second tone removed, tuned to exactly D♯4. It's playable across about an octave.
- **`bayMotor`:** an electric motor's whir, tuned to exactly B2. It plays the drones and the entry's spin-up.
- **`bayHydraulic`:** a scissor lift's hum, tuned to F4.
- **`bayConveyor`:** an industrial conveyor, looped seamlessly.

The transforming is done in SigmAudio:
- the samplers pitch the horn, motor and hydraulics to the notes in the score;
- the score sets the rhythm;
- track filters and amp EQ do the filtering;
- the layering is real kit plus machine kit on the same hits.

Before import, the preparation was only cutting, fading, tuning by resampling and the horn's tone split. Every step is in `sample-kits/slice.py` and `hornfix.py`.

These six kits were imported into my local SigmAudio checkout with its own `samples-import` tool, which accepts only CC0 or self-recorded audio. That added the kit folders, `kits.json` and the generated `sampleKitData.ts`. None of it is committed. To rebuild elsewhere, import the six folders in `sample-kits/` (the commands are in `sample-kits/IMPORT.md`) and the four Overclock round-2 guitar kits.

## Limitations, plainly

1. **A SigmAudio stinger plays one track.** Each stinger is therefore a set of single-track stingers on the same event: 8 for entry and 7 for victory. SigmAudio plays them together on the same boundary, and its `export-stinger-assets` renders each part to its own WAV, which is in `stinger-assets/`. I also mixed each set into one file, in `parts/`.
2. **Godot's standard pack doesn't play stingers.** `sigmaudio-export/` has the layer stems, the states and the event transitions, and its own warning says so: *"Authored stingers have no rendered files in this pack. Godot stinger playback and ducking are not exported."* SigmAudio does have a fuller Godot stinger path, but it needs a native Windows build I can't make here. So in Godot the game plays the two stinger files itself, on the runtime's `state_changed` signal (see "Using it").
3. **SigmAudio can't render a sequence of state changes headlessly,** the same as before. `preview-tool/preview2.py` simulates the runtime from the rendered parts and the stinger WAVs. It follows the authored rules: quantize points, dwell times, fades and which states allow which stinger.
4. **I balanced the mix from one render per track.** A first export with one layer per track hit SigmAudio's 30-minute limit, so I rendered each track alone instead. The final export, with its four real layers, took 4 minutes. Its stems match the per-track sums to within −50 dB. The preview and the loops in `parts/` use SigmAudio's own stems. SigmAudio measures the loop seam's continuation error at −96 dB.
5. **Escalation and recovery aren't in this delivery.** The first, five-state sketch (with escalation, recovery and the flinch) is still in the source as `V=1`, so nothing is lost if you want them back.
6. **More gunfire-band energy.** Combat has about 2 dB more energy at 2 to 5 kHz than Overclock round 2. The die clanks and the arpeggio live up there. Ducking the music under weapon fire would cover it, as before.

## Using it

- **To edit:**
  1. Change `editable-project/source/freightbay.mjs`.
  2. From a SigmAudio checkout that has the kits imported, run `V=3 node build.mjs freightbay.mjs starter.json out.json`. `V=3` is this delivery. `V=2` is the same before balancing, and `V=1` is the five-state sketch.
  3. Copy the project out of this shared folder before opening it in SigmAudio, because the CLI refuses symlinked folders.

  `freight-bay.sigmaudio.json` passed `validate-project`.
- **In Godot (not tested by me; nothing in Archipepsi was touched):**
  1. Use `sigmaudio-export/` as usual.
  2. The game fires `engage` as the Shunter sounds its horn, and `victory` when it goes down.
  3. Connect the runtime's `state_changed(state, time)` signal. When it reports **Entry**, play `parts/02-combat-entry-stinger.wav`. When it reports **Victory**, play `parts/04-victory-stinger.wav`.

  The state change lands on the two-bar line, so the stinger starts with it. The runtime commits on engine frames, so it's accurate to a frame, not to a sample.
- **To try other timings:**
  1. Edit `preview-tool/preview.json` (event times, horn times and level).
  2. Run `python3 preview2.py ../editable-project/freight-bay.sigmaudio.json ../sigmaudio-export/audio/stems ../stinger-assets preview.json out.wav log.json`.

  `clarity.py` measures the horn against any result.

## About checksums

This shared folder adds provenance metadata to audio files as they're stored. So the WAV hashes in `stinger-assets/manifest.json` and `sigmaudio-export/` won't match the copies here, even though the audio is identical. I decoded all 64 audio files here and compared them with my originals: every one is bit-identical.
