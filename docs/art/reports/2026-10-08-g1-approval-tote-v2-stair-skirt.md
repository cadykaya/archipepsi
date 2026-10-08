# G1 approved for integration; tote v2; one stair-noise comparison

*Arty — 2026-10-08*

**Status: done; STOP.** It's on `claude/archipepsi-art-bloom-g1-2026-10-08`.
- Nothing was merged into the campaign, and there was no new batch.
- I edited none of Prod's or Dess's files, and touched no shipped texture.

**The owner's scope for this pass:**
1. support Prod's G1 art integration;
2. one small material and form pass on the tote;
3. one controlled stair-noise comparison.

The rest is approved direction or deferred work (end of report).

## 1. G1: approved, and the handoff is updated

The owner approved all of Batch 065 as candidate art for Prod's G1 playable: the launcher, the impact seal, the permanent frame, the tote and the weight. **G1's mechanics stay unchanged**, so the placeholder and art-integrated versions can be compared.

`docs/art-requests/2026-10-08-impact-relay-g1-batch065-handoff.md` now opens with the approval. It asks for three things:
- **one branch, both versions.** The art goes in only as visual children; your code boxes are hidden while it's on;
- **the launcher's optional convex colliders stay off**, because they would change how a dropped weight settles;
- **tote v2 drops in** with the same file name, box, origin and nodes.

The one known fit issue, where the raceway ends, is still listed there with its fix.

[G7: G1's placeholders against Batch 065 integrated, same cameras, unpowered start](../review/bloom_g1_2026-10-08/G7_g1_placeholders_vs_batch065.png)

## 2. The teaching tote, v2

The owner's verdict on v1: "still looks too much like a gray developer placeholder."

**v2 is a moulded plastic container:**
- thin walls with a slight draft;
- rounded corners;
- **round-ended vents**, three a side;
- a **thick rolled rim**, a shade lighter;
- **satin ivory plastic** (roughness 0.40, never metallic), with a soft flow mottle so it isn't one flat value and isn't the station's cold grey;
- dark moulded **hand recesses** on the end walls, in Batch 043's handling colour.

| | v1 | v2 |
|---|---|---|
| Triangles | 228 | 282, within the 300 prop budget |
| Box | 0.50 × 0.36 × 0.50 m | **unchanged**: the exported bounds are ±0.25 / ±0.18 / ±0.25 |
| Mass, collider, behaviour | Prod's | **unchanged**: no collider in the GLB |

One defect was found and fixed during the pass: a floor at the box's own bottom z-fights with the deck it rests on, so the floor now sits 1 cm up on the walls' foot.

- [G6: v1 against v2 at 2.5 m, at 6–7 m and from the gallery, in grey too](../review/bloom_g1_2026-10-08/G6_tote_v1_v2.png)
- [G8: v2, close](../review/bloom_g1_2026-10-08/G8_tote_v2_close.png)

The weight is unchanged, as the owner asked.

## 3. The stair: one visual-only candidate

The owner's brief: the stair should be subordinate on first arrival but still a recognisable route, while the lift leads.

**The cause:** Crossing D's `_stair()` stacks 36 full-height boxes, one per 0.25 m rise, so the hall sees a 12 × 9 m sawtooth. T2 quieted its texture, not its geometry.

**The candidate, C2: T2 plus one closed stringer.** It's a thin plate on the open side, with its top 5 cm over the nosing line, in the stair's own quiet concrete.
- It has no collider, sits outside the walk width and changes no step.
- Treads and risers keep T2's quiet concrete, with no stripes; light separates them, and from the foot the treads still read.

| Hall-stair view | lift | stair | ceiling | lift ÷ stair |
|---|---|---|---|---|
| A as played | 30.2 | 29.5 | 46.7 | 1.02 |
| T2 | 30.2 | 22.1 | 21.8 | 1.36 |
| **C2** | 30.2 | **13.4** | 21.8 | **2.26** |

I also tried a stringer in the wall material (C1). It hid the stair into the wall behind it and measured 21.6, so I'm not recommending it.

[N4: A, T2 and C2 from the hall-stair, first-arrival and stair-foot cameras](../review/bloom_g1_2026-10-08/N4_stair_skirt_A_T2_C2.png)

The code sketch for Prod is in `docs/art-requests/2026-10-08-station-noise-handoff.md`: one node in `_yard_stair()`, with the exact profile. The study's source is `tools/crossing_capture/stair_skirt_study.py`. The capture driver gained a `profiles` op, which draws visual-only extruded polygons with no collision.

**The ceiling.** The owner prefers T2's local quieter treatment, never a global replacement. Before it ships, the quiet ceiling texture has to be promoted from the study script into a builder under `assets/`, with its own name. That step is in the noise handoff, and I haven't taken it yet.

## Recorded, not assigned

- **Bloom:** the direction is approved and kept for future use. The study script's header records what is approved and what is not:
  - panels physically displaced, and the foreign architecture entering through the affected surfaces;
  - no universal crystal decoration, no global Crossing reskin, and no procedural transformation system.

  The hand-over into the visited world waits for a real Multiworld identity to test.
- **Shunter:** the identity and the pale livery are approved. The larger plough movement and the upward-visible recovery vent are **candidates for gameplay testing**. There's no final model until its combat is proven fun.

## Checks

- `check_docs_metrics.py`: passes, 396 of 396.
- The Batch 065 rebuild is deterministic: only `ir_teaching_tote.glb` and the manifest changed, and the other four GLBs are byte-identical.
- `check_art_current.sh`: **PASS**, "every generated asset matches its source", including the Batch 065 rebuild; 14 m 6 s.

Not checked: Prod's integration in motion, the pinned-Production run (FU-1), and Windows.

## Addendum, later on 2026-10-08: final instructions

**The owner approved** tote v2 for G1 and C2 as a candidate for integration. They asked for T2's quieter ceiling as a proper, reproducible pipeline asset, restricted to its ceilings, and for **no more art studies or model redesigns until G1 has been played**.

**What I did:**
- **Batch 066:** `tools/blender/build_station_quiet_ceiling.py` writes `assets/textures/station_local/concrete_facility_ceiling_quiet.png` and `STATION_LOCAL.json`.
  - It is byte-identical to the texture T2 was measured with.
  - It is deterministic, and it's in `check_art_current.sh`.
  - It checks first that its painter still reproduces the shipped ceiling.
  - It's no theme-pack row, and the shipped ceiling is unchanged.
- **The final configuration, photographed:** the asset on the five ceilings, the **shipped** floor role on the stair and landing (so there's no second local texture), and the C2 stringer. It gives stair 13.5, ceiling 21.8 and lift ÷ stair 2.23, against C2's 13.4 and 2.26. [N5](../review/bloom_g1_2026-10-08/N5_final_crossing_d_config.png)
- **For Prod:** `docs/art-requests/2026-10-08-g1-crossing-d-final-integration.md`, one note for the tote, the ceiling and C2.
- **Recorded as a deferred tooling idea, not an assignment:** procedural stair meshes along paths or splines, with variable heights, widths and curves at a consistent UV density. It's in `docs/art/ART_FRONTIER.md`.

**Checks:** `check_art_current.sh` is listed below once run.

**STOP.** No watchers, subscriptions or merges.
