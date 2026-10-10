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

**CLARIFIED, later on 2026-10-08 (owner: keep the two versions clearly separate).** Step 1 alone is now its own option, **R**: roles only, shipped textures. It was not measured before; it is now. R gives lift 30.2, stair 22.1, ceiling 29.9, a lift ÷ ceiling ratio of 1.01, against T2's 1.39. "B showed that this step alone removes most of the ceiling noise" was an inference from the earlier whole-station study, B. On this view R does about two-thirds of what T2 does on the ceiling, and all of it on the stair.

Two other points in step 1 above are not as simple as written:
- "Ceilings take the ceiling role" has **no public accessor** in `ThemeMaterials`. The cache key also leaves out `role`, so `_material(THEME, "ceiling")` is the safe call.
- Exact T2's two textures are **local** variants, never a change to the pack's rows.

See `docs/art-requests/2026-10-08-station-noise-handoff.md` and the [N3 sheet](../review/bloom_g1_2026-10-08/N3_noise_roles_only_R_vs_T2.png). The text above is kept as written.

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

## 5. The Shunter (D-19): disposable concept exploration only

Dess's D-19 (`21cc00a4`) gives the charger an identity, approved by the owner: **a station freight Shunter whose routing the Crossing scrambled.** As asked, this is exploration and not the enemy model. Nothing is built until its behaviour has been tested at G3.

- **[The concept sketch](../review/bloom_g1_2026-10-08/E1_shunter_concept_sketch_DISPOSABLE.png).** Six states, side view, inside the unchanged 1.90 × 1.05 m envelope:
  - silhouettes;
  - livery and lamps on all six.

  The shape explains its three jobs:
  - **its freight work:** a broad hinged plough that butts crates into bays, and four short piston legs for decks full of thresholds;
  - **its charge:** the plough drops, and its position *is* the state;
  - **its recovery:** an open rear frame whose power pack glows white-hot while it is helpless.

  **Colour,** per D-19:
  - red only on its lamps, and on the plough edge when committed;
  - pale freight livery with a stencilled lane number;
  - Bloom veins for the scramble;
  - no orange, green or yellow-and-black on the body.

  These are authored polygons. I have no image-generation tool here, so there are no AI sketches.
- **[A throwaway maquette in D's yard](../review/bloom_g1_2026-10-08/E2_shunter_maquette_read_DISPOSABLE.png),** working, braced and recovering, at 8 and 15 m, beside today's enemies. It is blocks and colours from `tools/blender/study_shunter_maquette.py`, writing outside `assets/`. **What it taught:**
  1. **The pale livery works.** It separates from D's dark floor and from the black melee and ranged bodies, so the class reads before the eyes do.
  2. **D-19's 15–20 cm plough drop is too small to read at the 15–18 m first contact.** With the game's lens it is about 5 px, and the red lamps and edge carry the brace more than the shape does. For Dess: make the plough's travel the big change. It should rise high like a visor when working, and slam flat to the deck when braced, a 0.3–0.4 m swing.
  3. **The rear pack is invisible from the side.** It should vent *upward* through a hatch that opens in recovery, so "punish now" reads from any angle.
  4. **In the sketch, the braced plough pokes about 5 cm past the envelope.** A real model must fit it.

**Next, after G3:** one Shunter model through the authored pipeline, sized to the tested behaviour.

## D-18 v2 (also in `21cc00a4`): what it changes for the kit

**Already matching what Batch 065 built:**
- Prod's 2.0 × 0.25 × 2.0 m plate;
- the 0.6 s arming and the 1.0 s re-arm;
- blue on the chevrons and leading lip, not the slab.

**One fit note.** The lever moves to the plate's west, at about (−7, 0, −1). The launcher's inlet is at the west end of its rear face, plate-local (−0.90, 0.065, +1.26). The raceway needs **one floor turn** to reach it, or Prod can mirror the inlet to the front-west corner.

**Read against Prod's G1 build, later on 2026-10-08** (`review/impact-relay-g1`, `a3b59c46`). The lever is at (−7, 1, 0), and the line ends at the middle of the plate's **west face**: under the launcher's west lip, and short of the inlet. The handoff gives the waypoint change, one more floor segment ending at world (−0.90, 0, +0.26).

## Files, revision and checks

**Branch:** `claude/archipepsi-art-bloom-g1-2026-10-08`, from `463ef2f9`.

**Source:**
- `tools/blender/build_impact_relay.py`: Batch 065;
- `tools/blender/study_bloom_transition.py`: review-only;
- `tools/crossing_capture/dcap.gd`: now also hosts the Impact Lab, resizes boxes and makes materials emit, for studies;
- `tools/crossing_capture/shunter_sketch.py` and `tools/blender/study_shunter_maquette.py`: disposable concept tools, outside `assets/`.

**Views:** `docs/art/review/bloom_g1_2026-10-08/`, 13 images (16 after the addendum's G4, G5 and N3); the two `E*` images are labelled DISPOSABLE.

**Checks:**
- **The pipeline's own checks on each part:** 32.0 texels/m, flat shading, every part connected, within the `interactable` and `prop` budgets.
- **Rebuild:** the Batch 065 rebuild is byte-identical; Batches 063 and 064 are unchanged.
- **`check_docs_metrics.py`:** passes.
- **`check_art_current.sh`:** **PASS**, "every generated asset matches its source". The run included a rebuild of every builder and took 12 m 45 s.

**Not checked:**
- any runtime driver or the pieces in motion;
- the pinned-Production run (FU-1);
- Windows;
- audio, which is Wisp's and Prod's.

## Next owner questions

1. **Bloom.** Does the S0→S4 grammar, push → leak → mass → foreign growth, read as one reality turning into another? Should S1's first intrusion be louder?
2. **Noise.** T2 for the station: Prod's two material changes now, and the quiet ceiling and concrete stair textures as well?
3. **Shunter.** Does the sketch's identity land? Should Dess take the larger plough swing and the upward vent into D-19?
4. **G1.** Does the launcher read as "this throws things there", and the seal as "this breaks if hit hard enough"? Should the funnel lips collide?

## Addendum, later on 2026-10-08: the owner's rulings, and what followed

**The rulings:**
- **G1.** Batch 065 goes to Prod for the G1 candidate integration. **There is no new launcher or barrier design round before the room is played.** Arty supports specific fit and state issues only.
- **The tote and the weight** must look materially different, at the tested dimensions and with physics unchanged. Check the library first.
- **Noise.** Keep the roles-only version separate from exact T2. No global texture replacement.
- **Bloom's staged transition, and the Shunter's larger plough and upward vent**, stay **review proposals**. No final enemy model and no further broad studies yet.

**What followed:**
1. **The Prod handoff:** `docs/art-requests/2026-10-08-impact-relay-g1-batch065-handoff.md`. It is read against G1 `a3b59c46`:
   - the plate and shutter are unchanged from G0, so the launcher, seal and jamb fit as built;
   - one fit issue, the raceway's end (above), with the waypoint change;
   - every state in Prod's names;
   - the art-side answer to his packaging note: the candidate files are first-party. I didn't touch his registry.
2. **The tote and the weight, Batch 065 additions.** The library search found nothing at the tested sizes. The manifest's `library_check` records the search, and the handoff lists the near misses.
   - **`ir_teaching_tote`:** 228 tris, exactly 0.50 × 0.36 × 0.50 m, 4 kg. Open on every side, pale plastic; the only dark parts are its two hand slots.
   - **`ir_relay_weight`:** 108 tris, exactly 0.45 × 0.60 × 0.45 m, 36 kg. A squat cast-steel block on a foot, with a strap, a worn-bright cap, a bare bail handle and two `lightened` panels.
   - Both use Batch 043's family rule, put the origin at the box centre and ship no collider. Prod's mass, size and physics are untouched.
   - In Prod's own G1 room they read apart at 2.5 m, at 6–7 m and from the gallery, in colour and in grey:
     - [G4: 2.5 m](../review/bloom_g1_2026-10-08/G4_tote_weight_2m5_before_after.png)
     - [G5: distance](../review/bloom_g1_2026-10-08/G5_tote_weight_distance_before_after.png)
   - The rebuild is byte-identical. The three earlier GLBs are unchanged.
   - The manifest's state labels now say which names are D-18 v1's: v2 adopts Prod's states and timings. A dated correction in metadata only.
3. **Noise:** `docs/art-requests/2026-10-08-station-noise-handoff.md`, with R and exact T2 side by side, measured. The clarification is in section 2.
4. **Bloom and the Shunter:** unchanged. Both stay review proposals. Nothing new was built for either.

**Checks for this pass:**
- `check_docs_metrics.py`: passes, 396 of 396 built assets.
- `check_art_current.sh`: **PASS**, "every generated asset matches its source", including the Batch 065 rebuild; 13 m 16 s.
- Not checked: the pieces in motion in the running room, which is Prod's integration; the pinned-Production run (FU-1); Windows.

**Questions now open:**
1. **Noise:** R alone, or R and then T2's ceiling variant? The quiet floor measured no gain.
2. **G1:** only what Prod finds in the running room.

**STOP.** No watchers, subscriptions or merges.
