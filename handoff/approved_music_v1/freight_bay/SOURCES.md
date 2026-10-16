# Freight Bay: sample sources and licences

Every recording below was checked on its own Freesound page on 2026-10-13. Each page shows **CC0 1.0** (public domain dedication: https://creativecommons.org/publicdomain/zero/1.0/). CC0 needs no attribution, but every creator is credited here anyway.

The audio came from Freesound's public high-quality MP3 preview of each sound. The original uploads need a Freesound login, so I didn't use them.

No YouTube audio and nothing under CC BY was used, so no attribution lines are owed.

## Used

| Recording | Creator | Became | What was done to it |
|---|---|---|---|
| [freight train horn and approach pass near.flac](https://freesound.org/people/kyles/sounds/454025/) | kyles | `sfx-shunter-horn.wav` (sound-effect reference (not in SigmAudio)) | first 2.45 s (the horn chord, before the train passes); 10 ms fade-in, 0.3 s fade-out. Not imported: the game would play it as a sound effect |
| 〃 |  | `sfx-shunter-horn-tuned.wav` (sound-effect reference (not in SigmAudio)) | the three horn tones separated with harmonic masks and tuned to D#4, F#4 and B4 (the original F# is 35 cents sharp), then summed with the untouched breath noise; 2.5 s |
| [scissor lifts machines up down hydraulic movements2.flac](https://freesound.org/people/kyles/sounds/637811/) | kyles | `hydraulic-F4.wav` (bayHydraulic) | hydraulic hum 28.5-36.0 s; tuned +21 cents to F4 |
| [machine hydraulic metal cutter close crunch1.flac](https://freesound.org/people/kyles/sounds/453303/) | kyles | `snare-cutter-crunch.wav` (bayMachine) | one crunch from 2.403 s, 0.32 s |
| [Schnellläuferpresse 01.WAV](https://freesound.org/people/mark646/sounds/209219/) | mark646 | `kick-press-stroke.wav` (bayMachine) | one press stroke from 50.066 s, 0.30 s, 80 ms fade-out |
| [Schnellläuferpresse 03.WAV](https://freesound.org/people/mark646/sounds/209217/) | mark646 | `closed-hat-press-clank.wav` (bayMachine) | one die clank from 4.671 s, 0.14 s |
| 〃 |  | `ride-press-clank-2.wav` (bayHeavy) | a second clank from 2.060 s |
| [Industrial Conveyor Belt](https://freesound.org/people/Kinoton/sounds/519027/) | Kinoton | `conveyor-loop.wav` (bayConveyor) | 60-77 s, with the last second crossfaded into the first so it loops without a seam (16 s loop) |
| [Valve_1(air, release).wav](https://freesound.org/people/o_ciz/sounds/475427/) | o_ciz | `open-hat-valve-hiss.wav` (bayMachine) | 0.6 s of valve hiss from 0.267 s |
| [Air release](https://freesound.org/people/davidlay1/sounds/416080/) | davidlay1 | `open-hat-pressure-release.wav` (bayHeavy) | whole release, 3.6 s |
| [Slips air release v1](https://freesound.org/people/mcpable/sounds/131934/) | mcpable | `clap-air-puff.wav` (bayMachine) | first 0.30 s of the release from 0.444 s, shortened with a 0.12 s decay |
| [Electric Motor Whir.aif](https://freesound.org/people/jasonLON/sounds/125401/) | jasonLON | `motor-B2.wav` (bayMotor) | steady whir 14.5-22.1 s; tuned +52 cents to exactly B2 (123.5 Hz) |
| [Pneumatic hammer - Deprag zn231 - Forging 1](https://freesound.org/people/ldezem/sounds/386302/) | ldezem | `clap-hammer-rattle.wav` (bayHeavy) | the hammer burst, 0.74 s |
| [Heavy Metal Impact](https://freesound.org/people/magnuswaker/sounds/614062/) | magnuswaker | `snare-heavy-clang.wav` (bayHeavy) | whole impact, first 1.3 s |
| [Heavy Metal Impact 2](https://freesound.org/people/magnuswaker/sounds/614063/) | magnuswaker | `kick-heavy-boom.wav` (bayHeavy) | whole impact, 1.4 s |
| [Hard metal impact](https://freesound.org/people/ronnyver/sounds/488589/) | ronnyver | `ride-metal-ping.wav` (bayMachine) | the impact from 0.128 s, 1.2 s |
| [Industrial Air Horn](https://freesound.org/people/mcpable/sounds/131930/) | mcpable | `horn-D#4.wav` (bayHorn) | steady part and release, 0.33-2.28 s; the 385.5 Hz second horn removed with a harmonic mask so one tone remains; tuned -34 cents to exactly D#4 (311.1 Hz) |

## Downloaded and checked, but not used

| Recording | Creator | Why not |
|---|---|---|
| [Train horn](https://freesound.org/people/L83/sounds/455157/) | L83 | A two-tone horn a tritone apart, with a train passing. The freight horn says "dominant" more clearly. |
| [scissor lifts machines up down hydraulic movements1.flac](https://freesound.org/people/kyles/sounds/637810/) | kyles | The second lift recording had the steadier hum. |
| [metal rollers conveyor belt with no belt to bring boxes to store basement normal and slow prickly gritty movement.flac](https://freesound.org/people/kyles/sounds/454082/) | kyles | Too quiet and noisy to carry a rhythm. |
| [Rotating tank turret planetary electric motor](https://freesound.org/people/lorefold/sounds/607310/) | lorefold | Its pitch wanders (125 to 134 Hz), so it can't be tuned. |
| [Factory machine 04](https://freesound.org/people/jmbphilmes/sounds/194489/) | jmbphilmes |  |

`factory-machine-04` (jmbphilmes) failed to download and was never used.

`manifest.json` holds the same information as data, including each preview's download URL.

## Also used: the recorded guitars

The combat parts reuse the four guitar kits from Overclock round 2:
- **Library:** *Black And Green Guitars* v1.000 by Karoryfer Samples, recorded by Brian Wood.
- **Licence:** CC0 1.0. Karoryfer's licence page is https://karoryfer-samples.myshopify.com/pages/free-samples.
- **Details:** `../combat-piece/round-2/NOTES.md` and its `guitar-samples/` folder.

Everything else in the music is SigmAudio's built-in synthesis, plus its bundled public-domain `rockKit`.
