# Five weapons: sound handoff (Condi, 2026-10-10)

Candidate audio for the five-weapon range, made in SigmAudio. **Not approved.** Nobody
has listened to these yet: I can't hear, so everything below was judged by measurement
and by looking at waveforms and spectrograms. Skyiah's ears decide.

## Listen first

1. `preview/five-weapons-in-context-demo.m4a` (22 s). Each weapon firing at its
   candidate cadence into metal, stone and organic targets, in this order: Foundry (3
   shots), Sightline (6), Switchback (a 2-second burst and release), Bulkhead (2 shots
   with pumps), Mass Driver (full charge, hold, release into metal, power-down; then an
   early release into stone). Exact times are in `five-weapons-in-context-demo.cues.json`.
2. `preview/five-weapons-level-matched.m4a`. Each weapon's main fire event, one after
   another, at matched loudness, so no gun wins by being louder.
3. The single files in `wav/` for anything you want to hear alone.

The demo and comparison are assembled from the delivered WAVs by `source/context.py`:
placement and fixed gains only, no extra processing. Impacts sit 30 ms after the shot.

## The five sounds

Each fire event has three kinds of layer, as the brief asked: **attack** (the crack),
**body** (the weight), **tail** (mechanism and room). They're built differently, not
pitch-shifted copies of one shot. Grey-scale test for the ear: they differ in length,
spectrum and rhythm, not only pitch.

| Weapon | Attack | Body | Tail / mechanism | Character (measured) |
|---|---|---|---|---|
| **Foundry** hand cannon | Driven snare crack with a slap-back echo, a 75 ms muzzle-blast noise burst, a snap | Short sine sub thump, low thud, a punch, and a filter-swept "discharge" for the sci-fi edge | Slide clack, ratchet settle, faint coil ring, concrete-hall air | Balanced weight and crack: centroid 1.0 kHz, decays to −40 dB in 0.36 s |
| **Sightline** scout rifle | Supersonic snap (very short bright noise), high-passed snare crack, tight 808 snare | Small punch and sub, deliberately lighter | Bolt back at +0.13 s, bolt home and a steel tick at +0.18 s, short dry room | Brightest gun: centroid 3.3 kHz, least low end of the five |
| **Switchback** carbine | 808 snare crack, short burst noise | Small sine punch | Bolt tick and knock on every round; room and bolt settle only on release | Two round-robin rounds (A/B) so a burst doesn't machine-gun one sample; 0.37 s per round |
| **Bulkhead** scattergun | Snare crack, clap spread, two pellet-blast noise bursts panned left and right 2.5 ms apart, a thick mid "water noise" blast | Deep sub, punch and low thud, heavier than Foundry | Wide 1.9 s hall; the pump is its own event | Thickest gun: centroid 0.6 kHz; its blast is split left and right |
| **Mass Driver** | Charge: latch click, capacitor ratchet, pulsing hum, a rising whine, crackle that gets denser. Release: snare crack, blast, an electric snap | Sub slam and a resonant discharge sweep | Brake-drum slug ring, rail scrape, 2.2 s hall; separate power-down (falling whine, vent hiss, seat clunk) | Slowest and heaviest: full release decays to −40 dB in 0.71 s |

Impacts are different acoustic worlds:

- **Metal:** anvil and brake-drum ring, a hard tick, a punch, a scatter of spark crackles.
- **Stone:** concert-snare chip, claves knock, small click, a dull thud, debris patter, dust puff. No ring.
- **Organic:** a muffled slap, a body thud and a punch, all low-passed. No ring, no sparkle, no gore.
- **Mass Driver impacts:** the same three made heavier, plus a residual tone that depends on the surface (plate buzz on metal, rubble rumble on stone, a low thrum on organic).

No optional kill/recovery cue: the brief said only if it helps, and nothing yet needs it.

## Levels

All in `MEASUREMENTS.md`. The short version:

- Every weapon's main fire event reads **−21 LUFS** (the loudest 400 ms, which is the
  fair measure for a 0.3 s sound). Switchback is matched as a held 7.5-per-second burst,
  so one round alone is quieter (−25.7) on purpose.
- Impacts sit 4 dB under the guns (−25 LUFS); Mass Driver impacts 2 dB under (−23).
  Charge −24, held-charge loop −26, power-down −27, pump −28, carbine release tail −30.
- **No file clips.** True peak is −1.0 dBTP at worst (Sightline), and every other file is lower.
- Firing six shots at the brief's candidate cadence adds **no peak build-up** for any
  gun (0.0 to 0.1 dB); the previous shot's tail is 36 to 83 dB down when the next one fires.
- Every file's last 20 ms is at or below −56 dBFS except the loop, which isn't meant to end.

Matching loudness by numbers is not the same as matching it by ear. Expect to nudge.

## For Prod

`events.json` has every event name, file, trigger, length, suggested voice count, the
loop points and the impact rules. The two that matter most:

- Play all of them through **one SFX bus at the same `volume_db`** and trim the bus, so
  the comparison stays fair.
- The files start within 1 to 5 ms of the event. Nothing to compensate for.

Mass Driver wants a little state: charge on press, the held loop once charge reaches the
top, a 20 to 30 ms fade on release, then `release_full` or `release_early`, then
`powerdown` at the start of recovery. `massdriver_charge_hold_loop.wav` loops forward
from frame 0 to 76,800.

If sounds aren't wired yet, label the range's placeholders as placeholders. These files
don't need any GLYPH art to work.

## Source and how to regenerate

`source/` holds everything. `sounds.mjs` is the sound design: every layer as notes,
instrument, synth envelope, mix and effects, in milliseconds. `build-sfx.mjs` turns each
sound into an ordinary SigmAudio project (`projects/*.sigmaudio.json`, editable in the
SigmAudio editor, one named track per layer). `make-all.sh` rebuilds every delivered file:

```
cd <SigmAudio checkout, main 66b3f6e>
npm install
node tools/sigmaudio.mjs draft-sfx <(echo '{"version":2,"recipe":"clockwork-impact","seed":"x"}') > starter.sigmaudio.json
bash <this folder>/source/make-all.sh starter.sigmaudio.json <work folder>
```

Renders reproduce to within ±1 least significant bit (SigmAudio's documented float
jitter), so file hashes can differ by run while every measurement matches.

Sources are SigmAudio's built-in synthesis plus its bundled recordings: Salamander drum
kit (public domain, Alexander Holm), TR-808 recordings (CC0, Michael Fischer), VSCO 2
Community Edition percussion (CC0, Versilian Studios) and Kenney interface sounds (CC0).
No recorded firearms. Nothing is a code-only beep.

### Three things done outside SigmAudio, and why

1. **The first second is cut off.** SigmAudio's one-shot renderer doubles some notes
   that start in roughly the first half-second of a render (+6.5 dB on that note; see
   "Defects" below). Every project therefore starts its event 1 s late, and `trim.py`
   removes that silent second. It checks that everything it removes is below −90 dBFS
   and copies the remaining samples unchanged.
2. **The held-charge loop is cut and crossfaded.** SigmAudio's loop export left a
   40 ms dropout before the loop point on held notes, so `loopcut.py` takes 1.6 s from
   the middle of a 3.6 s SigmAudio render and blends the 100 ms after its end into its
   start (equal-power).
3. **Previews are assembled and encoded** (`context.py`, then AAC 256 kbps).

## Defects found (SigmAudio, not fixed here)

My lane was sound production, not DAW work, so I worked around these and am reporting them:

- **Notes double early in a render.** In `render-one-shot`, some notes starting within
  about the first 0.5 s render at +6.5 dB, as if triggered twice. A note at 330, 340,
  350 or 450 ms doubled; 300, 375 and 400 ms didn't. With a 1 s pre-roll, every note
  is identical. The first note of a render is also 0.2 dB quieter. Repro:
  `source/probe-doubling.mjs`.
- **Loop export drops out on held notes.** A note held across the whole loop goes
  silent (−79 dB) for the last ~40 ms before the wrap, although the reported loop join
  is −74 dB. That is an audible gap every loop.
- **`npm ci` fails on main:** `package-lock.json` is out of sync (missing `@emnapi/core`
  and `@emnapi/runtime` 1.11.3). `npm install` works.
- Not a bug, but worth knowing for sound design: the `softHands` kit's kick and snare
  carry a room hum that its +16.6 dB kit gain makes audible, and `stingKit`'s open hat
  is a ~2 kHz tonal chime, not a click. I stopped using both.

## Not done or not checked

- Not heard by anyone. Not played in Godot, not spatialised, not checked on Windows.
- No layered stems. Each layer is a named track in the SigmAudio projects, so any stem
  can be soloed or re-rendered if Prod wants one.
- Damage, cadence and range belong to Prod's range; the cadences here are the brief's
  candidates.
- No SigmAudio or Archipepsi file was changed, and the music-audition folder is untouched. The
  Archipepsi handoff branch only adds this folder, under `handoff/`, outside the Godot project.
