# Weapon development: three approved directions toward the Foundry standard, and the Bulkhead revisited

*Arty — 2026-10-13*

**Status: DEVELOPMENT MODELS AND CONCEPT FORMS, for your review. Stop for review.**
- Sightline A, Switchback A and Mass Driver A are developed as approved *concept directions*. They are not finished weapons: nothing is registered or merged, and nothing touches the campaign.
- The Bulkhead's form is **not** treated as approved. Three new concepts wait on you.
- I worked only in the isolated art lane. Prod's branch was only ever run, from a read-only checkout of `review/five-weapons-v3` (`ef157061`).
- No new weapon families and no inventory systems.

**Your decisions (Skyiah, 2026-10-13):**
- **Sightline A** (Accelerator): approved direction. Develop it toward the Foundry's believable construction and texture detail.
- **Switchback A** (Jacketed): approved direction. Switchback B is kept as a possible future weapon in the same archetype. Several guns per archetype is post-release scope.
- **Bulkhead A:** provisional only. It is too blocky and generic. Revisit its proportions, silhouette and mechanism presentation, keep the Breacher and the Sweeper, and show it to you before its form counts as approved.
- **Mass Driver A** (exposed rotor): approved direction. The charge should be visually expressive without overwhelming the view.
- **The Foundry's study** is the benchmark: high model detail, a great deal of effort in the textures, and no low-poly look, decorative glow or toy proportions.
- **Triangle counts** are provisional. Record triangles, materials, textures and draw calls; profile in the game after approval; don't reduce detail preemptively.
- **Fit and animation** requirements are coordinated with Prod.

All of this is recorded, dated, in `docs/AGENT_FRONTIER.md` and `docs/art/ART_FRONTIER.md`. The forms report carries a dated correction where your ruling superseded my recommendations (Switchback B, and trimming the Sightline).

## What to look at first

| | |
|---|---|
| [WB1: Bulkhead silhouettes](../review/weapon_development_2026-10-13/WB1_bulkhead_silhouettes.png) | from above and from the side, at one scale: A (provisional) against the three new directions |
| [WB2: Bulkhead in use](../review/weapon_development_2026-10-13/WB2_bulkhead_in_use.png) | each concept in three-quarter, then as Breacher and as Sweeper from the eye in Prod's range |
| [WD1: Sightline](../review/weapon_development_2026-10-13/WD1_sightline.png) | the developed Accelerator: painted, close up, in the range, and what it costs |
| [WD2: Switchback](../review/weapon_development_2026-10-13/WD2_switchback.png) | the developed Jacketed carbine |
| [WD3: Mass Driver](../review/weapon_development_2026-10-13/WD3_mass_driver.png) | the developed Rotor driver, at rest and mid-charge |
| [WD0: What each costs](../review/weapon_development_2026-10-13/WD0_metrics.png) | triangles, materials, textures, density, and draw calls and texture memory measured in the range, beside the Foundry |
| the clips | `sightline_clip.gif`, `switchback_clip.gif` and `driver_clip.gif`: each weapon in use in Prod's range, through his input action and timings |

## 1. Bulkhead, revisited

A's problem wasn't its detail. It was the plan: a receiver box with tubes on the front, which is every shotgun. Each new concept starts from a piece of station equipment whose job is to open a bulkhead, and the gun is what a crew made of it. Every concept keeps one body for both variants:
- the Breacher works Prod's `pump`;
- the Sweeper shows Prod's `feed`.

| | The mechanism, as the player sees it | Breacher / Sweeper | Triangles |
|---|---|---|---|
| **C Spreader** | A hydraulic rescue spreader. A flanged ram cylinder with a bolted end cap faces the eye. Two forged jaws splay 9° with a bore in each, so the spread is *in the shape*, and teeth on the tips brace against a door. The Epsilon ram sits between the jaws on links. | the pump re-pressurises the ram / a shell box clamps to the left, shell heads showing in its window | 3,528 |
| **D Fan** | A debris-clearing manifold. One cast block widens forward, with four short bores fanned 15° out of its face, like a duck's-foot pistol: from the eye, a spread hand. An Epsilon distributor sends one charge down four cables, and the breech block hinges to load from behind. | a slide hung under the fan / a flat four-shell cassette, one shell per bore | 2,584 |
| **E Hatch Ram** | A powder-actuated stud driver grown into a breaching gun. A short, very thick ram sleeve ends in a crown with four standoff claws. Disc charges stack in a slotted tower over the breech, and Epsilon kick-coils ring the ram's root. | the pump *is* the sleeve's collar / a belt of discs from a box on the left | 3,108 |

**My read:**
- **C** is the most distinctive, and its mechanism is the most legible: you see *why* it spreads.
- **D** has the strongest silhouette from the eye, but the one most at risk of reading as a novelty.
- **E** is the most believable as station equipment, but the least changed in outline from a heavy shotgun.

**I'd develop C.** These are still clay forms. Once you choose, the chosen one gets the same pass the three below got.

## 2. The three approved directions, developed

Each runs through the Foundry study's pipeline, step for step, now generalised: `tools/weapon_model.sh` runs the scripts below in order.

1. **Geometry:** the approved form (`build_weapon_forms.py`) plus only additions with a job (`build_weapon_model.py`).
2. **Bakes:** one atlas unwrap, then ID, position, normal, edge and AO bakes.
3. **Painting:** `weapon_paint.py`. These are the Foundry painter's own material rules: chips by exposure, polish where hands go, temper and soot where heat and gas go, oil at slides, dirt in recesses, raised and texture-only welds. Every placed mark comes from a per-weapon **wear spec** written beside the geometry: where it is hot, where it is handled, which welds and grinds are repairs, what is stencilled and stamped.
4. **Glyph:** holds the maps, derives the normal map itself and passes `check_material` clean (`author_weapon_maps.py`).
5. **Export:** the GLB, then Cycles looks at the painted model.

**The density.** The atlas is the smallest that holds the Foundry's density (~1,150 texels/m). The Switchback fits in 1024² at 1,319 texels/m. The Sightline and the Mass Driver are long guns, so they need 2048² and come out at ~1,900 texels/m: richer than the Foundry, as you asked, and the main thing to profile (see §4).

### Sightline A: the Accelerator

- **Added:**
  - a recoil buffer at the back, the face nearest the eye;
  - a lead and a terminal post for each stator pack, off the bus;
  - a cut plate bolted over a cracked trunnion.
- **History:**
  - a crack beside the bolt raceway, welded, ground flat and touched up from the wrong tin;
  - heat-straw at the breech and the brake;
  - soot at the brake and the raceway;
  - the serial stamped on the barrel and *SL-7* stencilled on the side plate;
  - service tallies in grease pencil on the core well;
  - torque stripes on two stator saddles, and a spanner slip on the third.
- **The bolt handle** works in its left raceway at Prod's 22 mm, and the ring sights sit on his ADS line.

### Switchback A: the Jacketed carbine

- **Added:**
  - a square replacement plate on the round buffer, its four bolts mismatched;
  - a deflector bent from strip and welded behind the open port, so cases don't come back at the eye;
  - a fire selector.
- **History:** the dirtiest of the three, because it's the one used most:
  - the jacket and the compensator heat-blued;
  - soot round the port;
  - the carry handle polished by hands;
  - a ground and touched-up repair on the rear-left;
  - a welded repair on the magazine well;
  - *SB-4* stencilled and stamped.
- **The bolt** races in the open left port at Prod's 35 mm a round; in the clip, it's the motion.

### Mass Driver A: the exposed Rotor

- **Added:**
  - a rear plate with a hand-crank socket: with the core out, the rotor is spun up or run down by hand;
  - the pickup lead from the accumulator to a terminal on the cage.
- **The charge, expressive but not loud:**
  - The rotor carries lathe rings and a painted index stripe, so Prod's `coils` spin *reads* through the cage as the charge builds, with no glow on it.
  - Only the accumulator lights, through Prod's own `core` glow.
- **A fix:** the form's balance weights cut through the cage bars (radius 0.0587 m against the bars' inner face at 0.0565 m). They would have clipped while spinning. In the developed model they're lowered, and set between the bars at rest. The forms pass's committed Driver is unchanged, as a record.

## 3. In Prod's range

Each developed GLB was swapped in for Prod's placeholder in memory, and his rig drives it:
- the Sightline and Switchback ADS lines up;
- the handle and bolt strokes stay inside their ports (clearance checked against the geometry: at hip distance the strokes are a few pixels);
- the rotor spins with the charge;
- the accumulator lights, and the painted core keeps its maps under his glow override.

The clips are each weapon in use through `fire_pulse`, at his timings:
- the Sightline: two shots;
- the Switchback: a two-second burst;
- the Mass Driver: a 1.7 s charge, then the release.

They are silent captures. The playable build with Condi's sounds is Prod's.

One thing to judge in the Mass Driver clip: during the charge, the brightest thing in view is Prod's `ChargeLight` raking the rails. The model adds no glow beyond the accumulator, so if the charge reads too loud, that is his light's energy, not the art.

## 4. What each costs (measured, provisional)

| | Triangles | Materials | Maps | Map size | Texels/m | Draw calls (range) | Texture memory added (range) |
|---|---|---|---|---|---|---|---|
| Foundry (approved) | 2,748 | 1 | 5 | 1024² | 1,154 | 3 | 24.0 MB |
| Sightline A | 4,992 | 1 | 5 | 2048² | 1,911 | 2 | 96.0 MB |
| Switchback A | 2,520 | 1 | 5 | 1024² | 1,319 | 2 | 24.0 MB |
| Mass Driver A | 3,312 | 1 | 5 | 2048² | 1,936 | 3 | 96.0 MB |

How these were measured:
- **Draw calls** are the median change with the weapon shown versus hidden, over twelve frames each way, in Prod's range (Compatibility renderer). They equal the meshes: `Body` plus the moving nodes.
- **Texture memory** is what the GLB's maps added once loaded with mipmaps. That is uncompressed RGBA. A project import with VRAM compression would cut it, which is Prod's import question.
- **No frame times:** the capture ran on software GL, where frame times mean nothing.

By your rule, nothing is reduced ahead of profiling. The line to watch is the two 2048² atlases: 96 MB each uncompressed, four times the Foundry's.

## 5. Coordination with Prod

`docs/art-requests/2026-10-13-weapon-development-fit-note.md`, written down and not sent to his session, covers:
- which of his parts each model drives;
- the runtime-owned children a model must keep (`Muzzle`, `ChargeOrb`, `ChargeLight`);
- the measured costs;
- two fit questions:
  - the `driver/core` glow contract;
  - one muzzle point for the Bulkhead concepts that have two or four bores.

The Foundry's v3 note and its questions still stand.

## 6. What I need from you

1. **The Bulkhead:** C, D or E (or a named mix), before its form counts as approved. I'd suggest C.
2. **The three developed models:** is the texture and detail level right for the approved directions? Anything to push further, or anything that reads as too much?
3. **The Mass Driver's charge:** expressive enough without overwhelming the view? (See the clip.)

## How it was made (reproducible)

```
# the Bulkhead concepts (A re-rendered beside them), renders + GLBs
blender -b --python tools/blender/build_bulkhead_concepts.py -- OUT bulkhead_a bulkhead_c bulkhead_d bulkhead_e
# the developed models: bake, paint, Glyph, GLB, Cycles looks
tools/weapon_model.sh DEV sightline switchback driver
# Prod's range (read-only v3 checkout; the script is copied into its tests/)
godot ... -s res://tests/_arty_weapon_forms.gd -- --five-weapons --weapon=<id> \
    [--variant=breacher|sweeper] --glb=<glb> --out=<dir> --tag=<tag> [--mode=clip]
python3 tools/crossing_capture/weapon_dev_sheets.py bulkhead OUT SHEETS
python3 tools/crossing_capture/weapon_dev_sheets.py dev DEV SHEETS
```

Found and fixed on the way:
- **Glyph's batch runner** reads a patch row beginning with `$` and a digit as a citation of an earlier result. `$` is now out of the weapon wrapper's patch alphabet; the exported pixels are unchanged. The Foundry's run never drew such a row, so its maps are untouched.
- **The pipeline script** had hidden a Glyph failure behind `|| true`. It now stops on one.

**Stop.** No final Bulkhead form, and no "finished" weapons, until you've reviewed these.
