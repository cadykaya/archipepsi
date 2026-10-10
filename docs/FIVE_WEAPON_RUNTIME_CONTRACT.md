# Five-weapon range: the runtime contract (for Arty and Condi)

*Prod, 2026-10-10. Branch `review/five-weapons`, mode `--five-weapons`.
This is what the range's runtime does now and exactly what it will
consume from your lanes. Nothing in it is approved art or audio.*

## Second pass (2026-10-10, after the owner's playtest)

What changed for your lanes; the rest of this document still holds
unless a line below says otherwise.

**Condi: your set is wired, exactly as `events.json` says.** It now
works like this:
- **Import.** `handoff/five_weapon_audio/` is your folder, byte for byte
  from `63c78a9d`. `tools/five_weapons/import_sigmaudio.py` copies the
  WAVs and `events.json` into `godot/audio/sigmaudio/five_weapons/`
  after checking them against your `SHA256SUMS.txt`. The game reads them
  as uncompressed PCM, with no trim and no normalising, and the loop
  points come from your `events.json`. A new delivery that keeps the
  event names drops in by re-running the script.
- **Levels: one for all.** Every event plays at one `volume_db`, the
  range's trim of −2 dB, which keeps headroom when a shot and its impact
  overlap. Nothing is re-matched per file; the placeholders and the old
  RMS matching are gone.
- **Your rules, as written:**
  - your voice counts;
  - Switchback A/B alternating, with its release tail only after 2 or
    more rounds;
  - the Mass Driver's charge, then the held loop with your 50 ms
    crossfade, then a 25 ms fade into `release_full` or `release_early`,
    and `powerdown` 0.5 s after the release;
  - Switchback's impacts 5.5 dB down;
  - Bulkhead's one blast impact plus at most two pellet impacts 12 dB
    down, 4–13 ms behind;
  - the Mass Driver's own impacts.
- **Where the gun's moving parts meet your sounds:**
  - Sightline's bolt handle is fully back at 0.13 s and home at 0.18 s,
    on your two baked clicks.
  - The Breacher's pump starts at 0.72 s, with its slam on the visible
    forward stroke 0.18 s in.
- **Three choices of mine, open to you:**
  1. **Wood has no file:** the timber crate and the loose crate play
     `impact.stone` (claves and chips), as your unknown-surface rule
     suggests.
  2. **The Bulkhead Sweeper** (the new fast variant: 7 pellets every
     0.5 s, no pump) plays `bulkhead.fire` at pitch 1.1, because no
     lighter file exists.
  3. **Foundry's readiness:** the hammer is drawn back from 0.56 s and
     cocks at 0.66 s, ready at 0.72 s. If the slide clack or ratchet in
     `foundry_fire.wav` sits elsewhere, tell me its time and I will
     move the hammer to it, or render a separate `foundry.ready` and I
     will play it on the cock.
- **Wanted, if you have time:** `impact.wood`, a lighter
  `bulkhead_sweeper.fire`, and that Foundry timing.

**Arty: what changed on the rig.**
- **Recoil.** It is now a timed envelope per weapon
  (`RangeRig.RECOIL`), with springs underneath for texture: an attack, a
  held peak, then an eased return that settles at a fixed time. The gun
  comes home, then the view climb returns, then the mechanism finishes,
  then the weapon is ready:

  | Weapon | Gun home | Aim home | Last mechanical beat | Ready |
  |---|---|---|---|---|
  | Foundry | 0.58 s | 0.65 s | 0.65 s (hammer) | 0.73 s |
  | Sightline | 0.37 s | 0.40 s | 0.17 s (bolt) | 0.48 s |
  | Breacher | 0.70 s | 0.77 s | 0.90 s (pump slam) | 1.00 s |

  Peaks: Foundry 0.28 m and 29°, Sightline 0.10 m and 9°, Breacher
  0.32 m and 24°, Mass Driver 0.13 m and 4°.
- **New moving parts:** `foundry/hammer` (a pivot that falls on the
  shot and cocks at 0.66 s) and `bulkhead/feed` (the Sweeper's feed
  box). The Foundry cylinder now indexes 60° from 0.38 s to 0.58 s.
- **Aiming down the sights.** Sightline, Switchback and the Mass Driver
  have open ring sights on the line of sight. When aiming, the rig moves
  so that line is the camera's:

  | Weapon | Rig pose (rig space) | Field of view |
  |---|---|---|
  | Sightline | (0, −0.075, −0.30) | 48° |
  | Switchback | (0, −0.065, −0.30) | 60° |
  | Mass Driver | (0, −0.13, −0.38) | 55° |

  Any real model needs a sight line at those heights, or a `Sight` node
  I can read the pose from.
- **Muzzle extras:** a short pale pressure ring on Foundry, Sightline,
  Bulkhead and the Mass Driver. Batch 068 has not been wired: the
  owner asked to test the feel first, and its guns were read as
  real-world firearms (your design exploration is the answer to that).

## The range in one paragraph

**Weapons and keys:**
- Keys 1–5: Foundry, Sightline, Switchback, Bulkhead, Mass Driver.
- Key 6: Heavy Report on the Static Pulse, as the owner played it.
- Key 0: the Static Pulse as it ships.

**How a shot works.** Each weapon is an Echo action fired through
`EchoRuntime`; the engine decides hits and damage. The range draws the
presentation: a camera-mounted gun, springs, the muzzle, a tracer from
the visible muzzle to the engine's resolved hit, material impacts and
persistent marks.

**One field of view, and level-matched sound.** The same FOV is used for
all five, and every sound plays level-matched (RMS).

## Events: what happens, and when

These names are what Condi's cues and Arty's flipbooks attach to.

| Event | When | Weapons |
|---|---|---|
| `fire` | The shot's own physics frame (the engine accepted the action) | Foundry, Sightline, Switchback (each round), Bulkhead |
| `fire_tail` | Switchback: once, when the held trigger is let go (never per round) | Switchback; optional for others |
| `mech` | Foundry: 0.5 s after the shot (cylinder/hammer). Sightline: 0.12 s (bolt reset). Bulkhead: 0.30 s (the pump stroke, 0.13 s each way). | Foundry, Sightline, Bulkhead |
| `charge` | A loop from the press until release, its pitch rising 0.8 → 1.4 with the charge (full at 1.1 s) | Mass Driver |
| `release` | The release frame; the slug launches | Mass Driver |
| `impact_<material>` | The frame the hit resolves (hitscan: the shot's frame; Mass Driver: when the slug lands, 10 frames at 10 m) | All, positional at the hit |

## For Condi: audio files

- **Weapon cues:** `godot/audio/sigmaudio/weapons/<weapon>/<cue>.wav`
  - weapons: `foundry`, `sightline`, `switchback`, `bulkhead`, `driver`;
  - cues: `fire`, `fire_tail`, `mech`, `charge`, `release`.
- **Impact cues:** `godot/audio/sigmaudio/impacts/impact_<material>.wav`
  - materials: `metal`, `stone`, `organic`, `wood`.
- **Variants:** number them (`fire_01.wav`, `fire_02.wav`, ...); each
  play picks one at random.
- **Format:** 16-bit PCM WAV, mono or stereo, 44.1 or 48 kHz. `.ogg` also
  loads, but only WAVs are level-matched.
- **Levels:** master to peak at −1 dBFS. The game measures each file's
  RMS over its first 250 ms and plays it at −20 dB RMS, so the five
  weapons arrive level-matched. That is RMS, not LUFS. If a sound needs
  to sit hotter or softer than that on purpose, say so in your manifest.
- **The Mass Driver's `charge`** must loop cleanly (set the loop points
  in the WAV, or tell Prod the sample range).
- **Switchback's `fire`** restarts on its own voice every round, at about
  7 a second. Keep its tail short; the long tail belongs in `fire_tail`.

*First pass, superseded by the section above: the per-weapon folders
below were the proposal; Condi's delivered names and `events.json` are
what the range now reads.* Until a file is there, the slot plays a
**labelled placeholder** (the range's old `Tones` sounds, which the
owner has ruled out as final). The
screen says "PLACEHOLDER — not SigmAudio", and **N** mutes the
placeholders. Prod imports your folder, re-runs the check (it proves a
dropped-in folder loads, variants included), and repackages.

## For Arty: what the runtime draws, and where your layers go

**Prod's runtime draws:**
- the 3D muzzle: a star core, flame tongues, a light, smoke and
  afterglow;
- tracers;
- the impact debris (sparks, chips, fibres, splinters, dust), its lights
  and the marks.

These are placeholders for shape, and the Glyph layers sit on top of
them, not instead of them.

**The rig:** a `RangeRig` node, a child of the player's camera, at
`(0.30, −0.27, −0.55)`, rotated `(0°, 6°, −3°)`. Each gun is a child of
the rig, with −Z down the barrel.

**Muzzle points** (in rig space; where a muzzle flipbook is anchored and
where every tracer starts):

| Weapon | Muzzle | Moving part (node, motion) |
|---|---|---|
| Foundry | (0, 0.03, −0.47) | none yet (a `mech` beat at 0.5 s) |
| Sightline | (0, 0.025, −0.74) | `handle`: +0.02 m back at 0.10 s, home in 0.06 s |
| Switchback | (0, 0.02, −0.42) | `bolt`: +0.035 m back and home in 0.07 s, every round |
| Bulkhead | (0, 0.02, −0.50) | `pump`: +0.10 m at 0.30 s, home by 0.59 s; the gun rolls 6° |
| Mass Driver | (0, 0.00, −0.62) | `coils` spin with the charge; `core` glows 0 → 4, flares to 7, dims in 0.7 s; a charge orb at (0, 0, −0.40) |

**Recoil, measured in the range:**

| Weapon | Peak shove | Peak rise | Back at rest |
|---|---|---|---|
| Foundry | 0.19 m | 19° | 283 ms |
| Sightline | 0.05 m | 4° | 67 ms |
| Switchback | 0.025 m per round, buzzing under held fire | 1.4° | — |
| Bulkhead | 0.24 m, then the pump | 12° | 517 ms |
| Mass Driver | 0.31 m | 6° | 300 ms |

**Flipbook slot, proposed** (not yet wired; Prod wires it when a set
lands):

- **Folder:** `godot/art/weapon_fx/<weapon>/muzzle/`.
- **Layers:** one subfolder per layer, `NN_<name>/frame_###.png`, drawn
  in `NN` order. For example `10_core`, `20_flare`, `30_tongues`,
  `40_haze`.
- **`manifest.json`:** `{"fps": 60, "size_m": 0.4, "layers":
  {"10_core": {"blend": "add"}, "40_haze": {"blend": "mix"}}}`.
- **Placement:** each layer plays once from the `fire` frame, at the
  muzzle point, facing the camera, under a random roll.
- **Impacts** use `godot/art/weapon_fx/impacts/<material>/...`, the same
  way.

**Marks.** The runtime places them at the hit position and normal,
parented to the body that was hit. A mark rides a moving target or a
pushed crate, goes when its owner resets, and persists until RESTART; the
oldest is recycled past 160.

The mark textures are Prod's placeholders:
- **metal:** a dark hole in a ring of chipped bright finish, with a hot
  rim that cools in 1.5 s;
- **stone:** a crater;
- **wood:** a split;
- **organic:** a soft dull dent, no red.

A mark texture set can replace them: 64–256 px RGBA, the mark centred,
alpha for its edge, one file per material at
`godot/art/weapon_fx/marks/<material>.png`.

## Surface tags (for anyone adding targets)

- **The tag:** `impact_material` meta on the collider or any ancestor:
  `metal`, `stone`, `organic` or `wood`.
- **Defaults:** an enemy counts as organic. H's older `flesh` reads as
  organic.
- **Untagged surfaces** report `unknown`. The check counts them and
  expects zero.
- **Where this came from:** the brief's `surface_*` names were a
  candidate convention. The range already used `impact_material`, so it
  kept that rather than adding a second taxonomy.
