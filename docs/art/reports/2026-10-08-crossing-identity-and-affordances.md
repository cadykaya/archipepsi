# Crossing identity, station noise, and blue and orange brought up to green's bar

*Arty — 2026-10-08*

**Status: STUDIES AND A CANDIDATE KIT for review; STOP.**
- Nothing here is approved, integrated or merged.
- No production colour changed. No Production file was edited.
- All of it is on `claude/archipepsi-art-crossing-identity-2026-10-08`, based on the Batch 063 kit at `9ae04155`, which is left untouched.

## The short version

1. **The station's noise is mostly two mistakes, not too much detail.**
   - **The ceilings use the wrong texture.** D paints its ceilings with the trim texture: a kick rail's 0.5 m stripe, tiled across about 600 m². That is the "ribbing".
   - **A floor detail repeats up the walls.** The wall texture bakes in a dark 0.85 m base course. Because the 4 m tile repeats, a 16 m wall shows it four times, as stacked dark speckled bands.
   - **The fix.** Fixing the ceiling is a one-line material choice for Prod. Quieter textures then do the rest, with the same colours and landmarks.
2. **Three Crossing directions, on the same camera in D's Central Hall:**
   - **Bloom:** growths break in through the walls, floor and ceiling.
   - **Cabinet:** another game's rules are drawn over the room.
   - **Splice:** one clean cut through the room, with the far side built in another game's language.

   I recommend a hybrid:
   - the Splice's structure, which keeps the station whole on one side;
   - the Bloom's growths only along the seam;
   - the Cabinet's marquee only on the objective.
3. **Blue and orange now work like green:**
   - **The launch cradle** fits the existing `LaunchPad`. It has a kick tray, blue fins that fold flat when it isn't fed, a boom that drops when it's blocked, and a green-fed housing.
   - **The breakable brace** fits `DestructibleCover`. It has orange break-away clamps, panels that lean and drop as it takes damage, and a wreck.
4. **The green stripe vanishes at a distance because of its angle, not its colour.** From standing height, the top of a floor run is seen almost edge-on. The smallest fix is to wrap the stripe over the pipe's top edges. I measured that change and haven't applied it.
5. **The enemies' "dark boxes with eyes" look is in the assets themselves.** The library's roles are riveted box stacks. In D they render near-black, about 32 px tall at first contact, and nothing animates except a flinch scale. The charger proposal is a drawing only, as the plan asks.

## How I looked at D

D's readability build was played by the owner. Its runtime is `bb683ce0`, on `review/crossing-d-readability` (now `0e54caab`, which changed only docs). I checked out a **read-only, detached copy in my own scratch space**. My own capture driver, `tools/crossing_capture/dcap.gd`, builds Production's `CrossingD` host in isolation, so there is no bridge socket and nothing is saved. It then photographs D from fixed cameras.
- **Changes stay in memory.** Every change a study makes, whether a texture swapped, a candidate placed or an old crate hidden, happens in that process's memory only.
- **Nothing pushed.** I edited none of Prod's files and pushed nothing to his branches.
- **The lens.** All shots use the game's 90° lens, from eye height (1.6 m), at 1600 × 900 unless a sheet says otherwise.

[The audit, as played](../review/crossing_identity_2026-10-08/A1_audit_as_played.png):
- **Pads** are flat glowing slabs.
- **Crates** are orange boxes with a band.
- **The lever's line** is lost by about 12 m.

## A1 — three Crossing directions and one recommendation

**The rules of the comparison:**
- Every frame uses the same camera, at the hall entry the owner called "awesome".
- The overlays are review-only geometry from `tools/blender/study_crossing_overlays.py`, placed at D's room origin.
- **One foreign palette for all three, so it is the grammar that differs:**
  - the palette is magenta, plum, cream and ink;
  - it is clear of movement blue, power green, destructible orange, hazard yellow and enemy red;
  - it never goes on anything the player interacts with.
- These frames sit on D's unchanged textures, so the comparison is honest. The last frame shows the hybrid on the quieter station.

| | [Station as played](../review/crossing_identity_2026-10-08/S1_station_as_played.png) | [1 Bloom: invasion](../review/crossing_identity_2026-10-08/S2_bloom.png) | [2 Cabinet: arcade remix](../review/crossing_identity_2026-10-08/S3_cabinet.png) | [3 Splice: reality splice](../review/crossing_identity_2026-10-08/S4_splice.png) |
|---|---|---|---|---|
| **Thumbnail read** ([sheet](../review/crossing_identity_2026-10-08/S7_thumbnail_read.png)) | a pale box, a tower | one great spire through the floor | the lift framed as a game cabinet, with bars overhead | the room cut in two, plum and cream past a bright line |
| **Station kept** | all of it | all of it, broken in three places | all the architecture; graphics drawn on top | everything on the near side, and the stair, lift and swing line on both |
| **Traversal vs objective** | blue rail, pads and plates; the lift has a green badge | unchanged; the spire risks pulling the eye off the objective | the marquee makes the lift (the objective) the loudest thing in the room | the seam sets up "go over there"; the foreign half is a destination |
| **Memorable because** | — | silhouette: something broke in | rhythm and play: the room is a machine | a boundary you cross |
| **Risks** | — | **noise:** spikes at every scale would compete with gameplay. **Cost:** low, a few dozen props | **colour:** a chequer and bars could start to read as interactive. **Noise** if overdone. **Cost:** low | **cost:** whole surfaces to re-dress per room. **Sightlines:** fine here. **Colour:** the seam must never be blue |

**Recommendation: [the hybrid](../review/crossing_identity_2026-10-08/S5_hybrid.png)**, shown [on the quiet station](../review/crossing_identity_2026-10-08/S6_hybrid_on_quiet_station.png):
- **Splice as the structure.** One readable boundary per room, and the station stays intact and quiet on its side.
- **Bloom only at the seam.** One memorable silhouette, marking where the worlds touch.
- **Cabinet graphics only on the objective.** The marquee says "this is the goal" and nothing else gets it.

That gives each layer one job. It is also the cheapest of the three to generate: a cut plane, a dressing set and a seam prop.

**What these are not:** a palette for any real game, final art, or a commitment to magenta. The foreign palette is a placeholder that shows the separation from the affordance colours.

## A1.1 — station noise, measured

**[A, B and C from one camera](../review/crossing_identity_2026-10-08/N1_noise_hall_A_B_C.png), in the hall and the yard:**
- **A** is as played.
- **B** paints only the ceilings with the theme's own `ceiling` role, through a per-node repaint. It answers the owner's open question, "noisy tiling vs material choices": most of the ceiling noise is a material choice.
- **C** is B plus quiet textures for the wall, trim, floor and ceiling.

**Provenance.**
- **The source.** `tools/blender/study_station_quiet.py` paints `current_*` with the shipped painters, and checks that each one is **pixel-identical to `assets/textures/theme/`**. All five match.
- **The quiet variant.** It changes only these numbers, keeping the same ramps, seams, panel grid, bolts, plates and ribs:

| painter setting | current → quiet |
|---|---|
| wall: base-course mix (the stacked bands) | 0.80 → **0** (make it a skirting block in geometry) |
| wall: speckle density / grime / edge wear | 0.10 → 0.02 / 0.50 → 0.20 / 0.70 → 0.30 |
| wall: broad patches strength, cell size | 0.26 → 0.10, 0.55 → 1.10 m |
| wall: weep streaks; tonal drift | 0.40 → 0.12; 0.05 → 0.03 |
| ceiling: rib pitch; rib highlight line | 0.6 → 1.2 m; on → off |
| ceiling: patches / speckle / edge wear | 0.28 → 0.12 / 0.22 → 0.04 / 0.70 → 0.30 |
| floor: patches / joint speckle | 0.25 → 0.12 / 0.30 → 0.08 |
| trim: stripe cycle; speckle; edge wear | 0.5 → 1.0 m; 0.07 → 0; 0.85 → 0.35 |

**[Readability at distance, A against C](../review/crossing_identity_2026-10-08/N2_noise_readability_A_vs_C.png):**
- **What C changes.** The pad at 20 m, a crate at 12 m and the lever at 12 m stand out from calmer surroundings in C. Nothing interactive got lost.
- **What C doesn't fix.** The lever's line at 12 m is still weak in both. That is the stripe problem (G below), not the walls.

**What I recommend, in order:**
1. Prod gives ceilings the ceiling role. It's one material choice in `crossing_d_room.gd`.
2. The base course becomes a skirting block at the floor.
3. The quiet textures go to the owner as a candidate.

I changed no shipped or candidate texture.

## A2 — the kit (Batch 064, `tools/blender/build_crossing_affordances.py`)

Both pieces are fitted to **Production's existing source contracts**, read at `bb683ce0`:
- `LaunchPad`: an `Area3D` with `PAD_SIZE` 2.4 × 0.5 × 2.4 m that throws the player along a solved arc;
- `DestructibleCover`: a `StaticBody3D` with `SIZE` 1.5 × 1.4 × 0.9 m and HP 40.

When I built them, there was no selected room from Dess and no feasibility result from Prod on pads launching RigidBodies. So neither piece is room-specific. If the room moves to a purpose-built impact machine, these keep their grammar and only the footprint changes.

### Blue: `ca_launch_cradle`

384 triangles. It fits inside the pad's 2.4 × 2.4 m plan.

| | |
|---|---|
| **What it is** | A neutral steel cradle: a kick tray with blue chevrons and two **blue wedge fins** rising toward the launch heading. Blue emitter rails run along the frame, a boom stands at the side, and a rear housing with two accumulator drums is **fed by the green raceway**. |
| **Mount** | A child of the `LaunchPad` at identity. Turn it so **Godot −Z faces the target** in plan: `look_at(Vector3(target.x, pad.y, target.z))`. Hide the pad's `BoxMesh` slab, and **keep its arc pips**: they are the solved trajectory, so they tell the truth. |
| **Collision** | Convex twins on the frame (0.12 m) and the rear housing only. The trigger is still Prod's `Area3D`. The tray, fins and boom move and carry none. |
| **Power** | A rear gland at the raceway's pipe height. A `ck_raceway_run` butts straight into it at runtime (0, 0.065, +1.20). `power_core` and `power_lens` follow the Batch 063 power state. |

**States** (all declared in `manifest.json`):

| state | `fin_hinge_l` / `_r` | `boom_hinge` | `move_rail_*` | `power_*` |
|---|---|---|---|---|
| unpowered | −90 / +90: folded flat into the cradle | 0, up | idle `#2a4ea8` | idle |
| ready | 0 / 0: raised | 0, up | live `#3266ee`, emitting | live |
| blocked (powered, refusing) | 0 / 0 | −90, down across the tray | idle | live |
| fired | `tray_hinge` +24° for 0.15 s, then back over 0.4 s, **only on `LaunchPad.fired`** | | | |

**Reading without colour:**
- fins up and boom up means go;
- fins flat means no feed;
- boom across means held.

The fins and tray rise toward the heading, so direction reads in grey.

**Views:**
- [In D: ready, unpowered, blocked](../review/crossing_identity_2026-10-08/K1_cradle_states_in_D.png);
- [the cradle at 4, 12 and 20 m, against the pad as played](../review/crossing_identity_2026-10-08/K2_cradle_distance.png);
- [on the bench, with grey](../review/crossing_identity_2026-10-08/K5_bench_cradle_brace.png).

**Honest distance result:**
- At 4–6 m, all three states are distinct.
- At 12 m the blue fins still point the way.
- At 20 m the fins are a small mark, about 18 px tall at 900 px. The old slab was a bigger blue dash there.
- The arc pips (Prod's, unchanged) still carry the route at range.

**"Blocked"** needs Prod to expose the pad's existing refusal: today `origin_is_clear()` failing just declines to fire, silently.

### Orange: `ca_breakable_brace` and `ca_breakable_brace_wreck`

The brace is 372 triangles and measures exactly the cover's 1.5 × 0.9 × 1.4 m. The wreck is 168 triangles.

| | |
|---|---|
| **What it is** | A shoring frame: neutral steel posts and skids holding pale station panels in **orange break-away clamps**, with **orange scored top rails and end straps**. The orange reads from the front, the back, both ends and above, and it is never a solid orange block. The gaps show a dark core. |
| **Mount** | A child of the `DestructibleCover` at identity; the origin is the box centre, as its own mesh. Hide its `BoxMesh` and D's `BreakBand`. The `BoxShape3D` collider is unchanged. |
| **Damage, driven by `hp` after each `take_damage`** | above 26.7: **intact** · above 13.3: **dented** (top panels lean out 18°, top clamps gone) · above 0: **breaching** (top panels hang at 75°, middle at 32°, all clamps gone) · at 0: the cover frees itself as now, and Prod places **`ca_breakable_brace_wreck`** at the same transform, with no collision. |

**Views:**
- [Intact, dented, breaching and the wreck, in D's yard](../review/crossing_identity_2026-10-08/K4_brace_intact_dented_breaching_wreck.png);
- [against the crates as played, at 5 m and on the return angle at 12 m, with grey](../review/crossing_identity_2026-10-08/K3_brace_distance.png).

**Two things I didn't decide:**
- **Height.** I kept the cover's 1.4 m. The owner noticed it is low cover, and a full-height variant is Dess's and Prod's call.
- **Impact versus bullets.** The look works for either. Which one breaks it is runtime.

## G — the green stripe at a distance (a proposal, not applied)

**What I measured.** I resized D's own `PowerStripe` meshes in memory and photographed the socket's line at 4, 11 and 18 m, idle and live:
- [the sheet](../review/crossing_identity_2026-10-08/G2_power_stripe_4_11_18m.png);
- [the 11 m crop](../review/crossing_identity_2026-10-08/G1_power_stripe_11m_now_vs_cap.png).

**The cause.** From 1.6 m, the top of a floor run is seen at about 8° at 11 m. A 4 cm stripe on top projects to under 1 px. Its sides are what survive.

**The smallest source fix.** Make the stripe a **cap**, 0.096 m across and 0.03 m tall, centred 0.110 m off the surface, so it wraps the pipe's top edges.
- **Where it changes.** It is one constant in `build_crossing_kit.py` (`CORE`) and the matching numbers in Prod's `_straight`.
- **What it buys.** Green pixels at 11 m go up about 10%, and the side band is about 1.2 px instead of a sliver.
- **What it doesn't change.** Live against idle is what really separates at range: 378 bright-green pixels live against 0 idle, with or without the cap.

This is a modest gain, so it's the owner's call. **I haven't changed Batch 063** or PR #19.

## A3 — enemies: what D actually shows

**Facts from the source and the capture**, with [the in-engine sheet](../review/crossing_identity_2026-10-08/E1_enemies_in_D.png):
- **D uses the art lane's own enemies.** `Enemy._authored_body` loads `content/enemies/standard/enemy_role_<kind>.glb`, because `concrete_facility` is in the standard value band. These are Batch 030: [riveted box stacks](../review/batch030/A_enemy_lineup.png).
- **The eye is all that's left of the face.** The eye is Production's emissive strip, 0.12–0.34 m by 0.07 m.
- **Small at first contact.** The 90° lens at the 18 m aggro radius gives about 32 px for the charger (1.05 m tall), about 42 px for the ranged (1.4 m) and 48 px for the melee (1.6 m) on 1080p. Against D's pale walls all three render near-black (judged by eye, not measured).
- **No locomotion animation.** The only visual motion is a flinch to 88% scale, the windup scale and a tip-over death.

**What's at fault:**
- **Mainly the assets.** Their silhouettes are boxes: in grey, the charger is a low box, the melee and ranged two small upright boxes.
- **Then the missing animation.**
- **Then scale and lighting**, which make it worse.

Integration is not the problem: the authored bodies *are* integrated.

**The library has no better candidate to swap in.** The other Batch 030 roles share the box grammar.

**[The charger proposal, deferred](../review/crossing_identity_2026-10-08/E2_charger_proposal_deferred.png)** is a drawing, not a model:
- **The shape.** A low ram-sled with a shovel prow, splayed legs, three dorsal vanes and a rear vent, inside the unchanged 1.9 × 1.05 m collider.
- **Four beats, each shape-led:**
  - prowl;
  - **wind-up**: rear up and vanes flared;
  - **commit**: stretched and unturnable;
  - **recover**: nose down, with a hot vent that says punish now.
- **The vent's orange.** It is a timed glow on the body, kept apart by placement and timing from the brace's matte orange paint.
- **When to build it.** Not until Prod and Dess agree the charger's commit and recovery.

## Art acceptance tests (run so far)

| test | result |
|---|---|
| Grayscale: silhouette signals class and function | **cradle yes** (fins and tray point; states differ in shape) · **brace yes** (an open frame of panels; damage changes the outline) · **enemies no** today |
| 12–20 m: blue direction, orange breakability, green state | orange yes at 12 m, front and return · blue yes at 12 m, weak at 20 m · green: live against idle reads, the line's shape is weak (G) |
| Player height: physically mounted, nothing floating | yes: the cradle sits on the floor inside the pad; the brace sits on skids; no floating markers |
| In motion: the indicator changes with real state | **not tested.** The states are declared poses; the drivers are Prod's |
| Station still utilitarian; the Crossing playful and distinct | studies S1–S6 |
| Quiet station doesn't swallow interactive objects | N2: objects stand out more in C, not less |

## For Prod and Dess

**For Prod.** These are contracts, not edits:
- the two `look_at` and child-at-identity mounts above;
- the state tables, with nodes `*_hinge`, `move_rail_*` and `power_*`;
- hiding the old `BoxMesh` visuals;
- placing the wreck on `broken`;
- the ceiling-role change;
- the stripe cap, if wanted;
- exposing a pad's refusal so "blocked" can show.

The cradle's power exit matches the Batch 063 raceway.

**For Dess.**
- **Height.** The brace is at cover height. Say if the room wants a full-height barrier variant.
- **Footprint.** The cradle assumes a standing 2.4 m pad. A purpose-built impact machine would reuse the fins, boom and green-fed housing.

**Confirmed:** the green kit is not duplicated. Batch 064 reuses its builder, hinges, materials and power state.

## Files, revision and checks

**Branch:** `claude/archipepsi-art-crossing-identity-2026-10-08`, from `9ae04155`.

**Source:**
- `tools/blender/build_crossing_affordances.py`: the builder, in the art check's rebuild list;
- `tools/blender/study_station_quiet.py` and `tools/blender/study_crossing_overlays.py`: review-only, writing outside `assets/`;
- `tools/crossing_capture/`: `dcap.gd` (the D capture driver), `sheet.py` (contact sheets) and `charger_proposal.py` (the drawing);
- `tools/shots/batch064_crossing_affordances.json`: the bench shot list.

**Exports:** `assets/models/batch064/crossing_affordances/`: three GLBs and `manifest.json`.

**Views:** `docs/art/review/crossing_identity_2026-10-08/`, 19 images.

**Checks:**
- the pipeline's own checks on each part: 32.0 texels/m, flat shading, every part connected, within the `interactable` and `prop` budgets;
- the Batch 064 rebuild is byte-identical (4 files), and Batch 063 is unchanged;
- `check_docs_metrics.py`: 391 of 391;
- `check_art_current.sh` in the usual configuration: **PASS**, with "every generated asset matches its source". Because the new files were untracked, this run also rebuilt every builder; it took 9 m 34 s;
- the quiet painters reproduce the shipped textures pixel for pixel.

**Not checked:**
- the pinned-Production run, where FU-1 is still open;
- any runtime driver;
- the pieces in motion;
- Windows;
- audio, which is Wisp's.

## What changed, what remains, next question

**What changed.** A player who reached a pad would see a machine: fins that point the way, rails that light, and a boom when it won't fire. A crate becomes a braced barrier whose panels give way as it's hit and leave a wreck. And there are four pictures of how a Crossing could take the station over.

**What remains:**
- every runtime driver, which is Prod's;
- the room mechanism, which is Dess's;
- the owner's choice of direction;
- the stripe cap and the quiet textures, both owner decisions;
- the charger, deferred.

**Next owner question.** Which direction do you want to see in a playable room: the hybrid, or one of the three? Should the quiet station go forward with it?

**STOP.** No watchers, subscriptions or merges.
