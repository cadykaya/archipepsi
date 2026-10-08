# Bloom as connective tissue, selective quieting, and the Impact Relay G1 kit

*Arty — 2026-10-08*

**Status: STUDIES AND A G1 CANDIDATE KIT, for review; STOP.**
- Nothing here is integrated or merged, and no production palette or texture changed.
- I edited none of Production's or Dess's files.
- It's on `claude/archipepsi-art-bloom-g1-2026-10-08`, from `463ef2f9` (PR #23).

**This answers the owner's 2026-10-08 direction:**
1. Bloom as the transition language.
2. Selective noise correction.
3. Blue and orange to green's standard.
4. Support for Impact Relay G1.
5. Wait on the enemy.

All views come from the engine. A read-only copy of each Production review build is photographed by `tools/crossing_capture/dcap.gd`. Study changes happen in that process's memory only.

## 1. Bloom: the transition, in five stages

[The strip](../review/bloom_g1_2026-10-08/B_strip_five_stages.png) shows all five stages from **one camera** at Crossing D's Central Hall entry, on the quieted station from part 2. Each stage is also a full frame:
- [S0 station](../review/bloom_g1_2026-10-08/B0_station.png)
- [S1 first intrusion](../review/bloom_g1_2026-10-08/B1_first_intrusion.png)
- [S2 contamination](../review/bloom_g1_2026-10-08/B2_contamination.png)
- [S3 the visited world](../review/bloom_g1_2026-10-08/B3_the_visited_world.png)
- [S4 the way back](../review/bloom_g1_2026-10-08/B4_the_way_back.png)

| Stage | What changes | What is still station |
|---|---|---|
| **S0 Station** | nothing | everything |
| **S1 First intrusion** | **one seed at the way on** (the Courtyard opening); three panels pushed off the jamb wall; light leaking from the joints it has reached | the whole room; you notice it at the exit |
| **S2 Contamination** | veins run the wall courses; panels peel in a band above the stair; **the first foreign structure grows out of a Bloom mass**: a patch of stone and a stepped arch, high on the wall where it doesn't belong; a second seed through the floor | the room's shape, the lift, the floor, most walls |
| **S3 The visited world** | east of one seam, the hall *is* the other world: stone courses, two arches, coffered beams, a tiled floor, warm light. **Bloom is only on the seam** between the realities | the lift tower and the west wall: the anchor you came from |
| **S4 The way back** | all foreign, except **round the exit**, where Bloom peels the foreign skin back off station panels: S1 in reverse | the lift (the exit), re-emerging |

**The grammar, in order of contact.** This is why it reads as transformation and not as decoration:
1. A station panel is **pushed off its wall** along its own normal.
2. **Light leaks from the joints** behind it; Bloom fills the seams first.
3. A **crystal mass** grows where the seams cross.
4. **The foreign architecture grows out of that mass**, in its own language and at its own scale.

So Bloom always sits *between* two architectures. It is never the room itself.

**TEMP-WORLD is a placeholder.** It is cream stone with dark plum-brown banding, stepped arches and coffered beams, labelled on every frame. No source game has been chosen, so it is not a look for any game. It stays clear of every gameplay colour, and the lit station's blue rail and plates stay visible on top of it in S3 and S4. Bloom keeps the magenta, pink and plum of the earlier studies.

**What a production version would need** (not started):
- a small Bloom transition kit: a seed, a vein strip, a heaved panel and a peel;
- one skin per visited game.

**Risks:**
- **S1 and S2 are quiet by design.** From 20 m the first seed is a small mark. If the owner wants the first intrusion noticed sooner, give it a sound or a light flicker rather than more mass.
- **Cost.** S3 and S4 re-dress whole surfaces, which costs the same as building a themed room.

**Source:** `tools/blender/study_bloom_transition.py` (review-only).

## 2. Selective noise: ceilings and the dead-end stair only

**What changed** ([three variants](../review/bloom_g1_2026-10-08/N1_targeted_noise_A_T_T2.png), [the Machine Hall](../review/bloom_g1_2026-10-08/N2_targeted_noise_machine_hall.png)):
- **Ceilings** (`HallCeiling`, `ArrivalCeiling`, `CourtCeiling`, `MachineCeiling`, `YardCeiling`): painted with the theme's **ceiling** role instead of the kick rail's trim strip.
- **The hall stair** (`YardStair`, which climbs to a gate that opens only from the yard, and `StairLanding`): painted as concrete, the floor role, instead of trim.

**What didn't change:** walls, floors, the lift tower (`Shaft*`, `TowerHead`), cover, every interactable, and the palette. The cold industrial station is as it was.

**Measured.** This is the mean edge strength in three regions of the hall-stair view; the boxes are approximate.

| | lift tower | dead-end stair | ceiling | lift ÷ ceiling |
|---|---|---|---|---|
| A as played | 30.2 | 29.5 | **46.7** | 0.65 |
| T: stair in quiet trim | 30.2 | 24.6 | 21.8 | 1.39 |
| **T2: stair in quiet concrete** | 30.2 | **22.1** | 21.8 | **1.39** |

As played, the ceiling was the busiest thing in the hall, half as busy again as the lift. In T2 the **lift is the busiest of the three**, and it is the only striped structure left, which matches the owner's wish for the lift to draw the eye. I recommend T2.

**For Prod, in two steps:**
1. **Change two material assignments in the room code.** Ceilings take the ceiling role; non-critical stairs and landings take the floor role. These are shipped textures. On 2026-10-08, B showed that this step alone removes most of the ceiling noise.
2. **The owner's decision:** T2 also uses the quiet versions of just those two roles, from `study_station_quiet.py`. The wall, trim and floor textures used elsewhere stay as shipped.

## 3 and 4. The Impact Relay G1 kit (Batch 065)

The kit is fitted to **Prod's G0 mechanism**, read at `review/impact-lab-g0`, `3337769d` (`impact_lab_parts.gd`), and to **Dess's D-18 Concept A** room. Every view is in Prod's own Impact Lab, at gameplay distances.

**Where Dess's brief and Prod's measured plate differ.** I followed Prod's physics and kept Dess's look:

| | D-18 (Dess) | G0 as built (Prod) | This kit |
|---|---|---|---|
| Footprint | 2.4 × 2.4 m tray, 0.3 m lips that funnel | a 2.0 × 0.25 × 2.0 m plate | **Prod's plate box exactly** (the deck's top at 0.25 m), with lips and housing round it inside 2.4 m |
| Funnel lips | yes | no (off-centre objects fly the same arc from where they sit) | the lips are drawn and carry **optional** convex twins. Using them is a physics change, for Prod and Dess to decide |
| Wind-up | 1.0 s, the tray tilts | a 0.6 s arming ramp | the chevrons fill over the ramp, whatever its length. **No tilt before the throw:** the deck kicks only on `fired`, so the motion tells the truth |
| Re-arm | 2 s | 1.0 s | a fade over whatever they choose |

### `ir_object_launcher`

476 tris, 32 texels/m. Views:
- [states at 3 m](../review/bloom_g1_2026-10-08/G1_launcher_states_3m.png);
- [at gameplay distances, against G0 as built](../review/bloom_g1_2026-10-08/G3_gameplay_distances.png).

| | |
|---|---|
| **Construction** | A station-steel plinth and lips. A dark deck with **three blue chevrons** pointing the throw. **Blue emitter rails** run on top of and outside each lip. A rising front lip with **two blue fins**. A rear **accumulator housing** with two drums, each with a blue band. A **green inlet and pilot** where the raceway arrives. The blue modules bolt on with neutral brackets, a cue for "fabricated or adapted by Epsilon" (a direction, not lore). |
| **Mount** | A child of the `ObjectPlate` at identity, yawed as the plate yaws its own deck (Godot −Z along the throw). Hide the plate's code boxes (`Slab`, `Chevron`, `Lip`, `PowerLamp`). Keep its `Sensor` and its collider. |
| **Power** | The inlet is at runtime (−0.90, 0.065, +1.26): west end, rear face, at raceway pipe height. Mirror x for a feed from the east. `power_lens` and `power_core` use the Batch 063 power state. |

**States** (Prod's name, with Dess's in brackets; all in `manifest.json`):

| State | `move_rail_*` (rails, side strips, drum bands) | `move_chevron_1..3` | `power_*` | `deck_hinge` |
|---|---|---|---|---|
| unpowered (DARK) | idle `#1b2d66` | idle | idle | 0 |
| powered idle (COCKED) | live `#3266ee`, steady | idle | live | 0 |
| arming (WIND-UP) | pulse, faster as it fills | **light 1, then 2, then 3, back to front**, at ⅓, ⅔ and 3/3 of the ramp | live | 0 |
| throw (FIRED) | flash | flash pale blue | live | **kick to 10° in 0.06 s, back in 0.25 s**, on `fired` only |
| dud | one dim flicker | — | **stays idle** (the reason) | 0 |

The fins and the front lip are constant blue. They are what shows the device's category and the direction it throws.

**Reading in grey:** the fins and lip rise toward the throw, the chevrons point it, and the deck kicks only when it throws.

**Distance, honestly:**
- From the gallery's height (D-18's 4.5 m), the rails, chevrons and fins all read.
- From 11 m behind the device, on the lever side, the lit drum bands and side strips now carry COCKED. They are smaller than a flat blue slab would be.

### `ir_impact_seal` and `ir_seal_jamb`

744 and 108 tris. [States at 5 m, with grey](../review/bloom_g1_2026-10-08/G2_seal_states_5m.png).

| | |
|---|---|
| **Construction** | Six armour slabs over a dark core. Each slab is **its own node, with its origin at its centre**, and carries **orange seam collars** on the edges where it gives, plus its rating bolts. Three glance **scuffs**. |
| **Mount** | The seal is a child of the `ImpactShutter` at identity, hall face Godot +Z. Hide `Casing`, `Band` and `Seam`. The **jamb goes on the wall, not under the shutter**, so it is still there when the seal is gone. |
| **Intact** | Hide the scuffs at build. |
| **Wear** | The collars brighten as hp falls (the shutter's own `_paint`, applied to the collar material, `ca_orange`). **Keep the emission at about 0.7–0.9.** Prod's current `0.4 + 2.0 × wear` goes up to 2.4, and orange that bright washes to yellow, which reads as hazard. |
| **Glance** (D-18) | Show the next scuff and flash the collars for 0.15 s: "not enough", not "immune". |
| **Refused** | Flash the collars for 0.25 s. |
| **Broken** | `slab_1..6` each become a RigidBody at its own node transform, colliding with the world only, about 60 kg each. The core goes with the shutter, and the **empty jamb stays**: the destroyed state reads from across the hall. |

**Not made:** the weight, D-18's canisters and the light crate. Prod asked for "a neutral 0.45 × 0.6 × 0.45 m carryable". Say if G1 wants art for it.

**Source:**
- `tools/blender/build_impact_relay.py` (in the art check's rebuild list);
- the exports in `assets/models/batch065/impact_relay/`.

## 5. Enemy design: waiting, as asked

There is no new enemy work: no model, and no concept sketches. This environment has no image-generation tool. Any exploratory sketch would come from outside the pipeline and be labelled exploratory. The deferred charger drawing from the 2026-10-08 report still stands, and nothing is built until Dess's charger design exists.

## Files, revision and checks

**Branch:** `claude/archipepsi-art-bloom-g1-2026-10-08`, from `463ef2f9`.

**Source:**
- `tools/blender/build_impact_relay.py`: Batch 065;
- `tools/blender/study_bloom_transition.py`: review-only;
- `tools/crossing_capture/dcap.gd`: now also hosts the Impact Lab, resizes boxes and makes materials emit, for studies.

**Views:** `docs/art/review/bloom_g1_2026-10-08/`, 11 images.

**Checks:**
- **The pipeline's own checks on each part:** 32.0 texels/m, flat shading, every part connected, within the `interactable` and `prop` budgets.
- **Rebuild:** the Batch 065 rebuild is byte-identical; Batches 063 and 064 are unchanged.
- **`check_docs_metrics.py`:** passes.
- **`check_art_current.sh`:** the result is in the commit.

**Not checked:**
- any runtime driver or the pieces in motion;
- the pinned-Production run (FU-1);
- Windows;
- audio, which is Wisp's and Prod's.

## Next owner questions

1. **Bloom.** Does the S0→S4 grammar, push → leak → mass → foreign growth, read as one reality turning into another? Should S1's first intrusion be louder?
2. **Noise.** T2 for the station: Prod's two material changes now, and the quiet ceiling and concrete stair textures as well?
3. **G1.** Does the launcher read as "this throws things there", and the seal as "this breaks if hit hard enough"? Should the funnel lips collide?

**STOP.** No watchers, subscriptions or merges.
