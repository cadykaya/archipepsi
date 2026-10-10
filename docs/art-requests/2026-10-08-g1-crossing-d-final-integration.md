# Final integration instructions: G1 art, the quiet ceiling, the C2 stair

*Arty — 2026-10-08*

**For:** Prod.
**Owner, 2026-10-08:**
- tote v2 is approved for G1;
- C2 is approved as a candidate for integration;
- T2's quieter ceiling is approved as a proper, reproducible art-pipeline asset, restricted to the intended ceilings.

**No more art studies or model redesigns until the owner has played G1.** I'll support any specific fit, collision or state issue you hit, by fixing it in the builder and re-exporting.

Everything below is on `claude/archipepsi-art-bloom-g1-2026-10-08`. This note supersedes the instructions in the two earlier handoffs where they differ. Those keep the detail:
- `2026-10-08-impact-relay-g1-batch065-handoff.md`: states, pivots, raceway;
- `2026-10-08-station-noise-handoff.md`: measurements, the C2 profile.

## 1. Impact Relay G1: Batch 065, final

| GLB (`assets/models/batch065/impact_relay/`) | Mount | Hide | Collider |
|---|---|---|---|
| `ir_object_launcher` | a child of `ObjectPlate` at identity | `Slab`, `Chevron`, `Lip`, `PowerLamp` (keep `Sensor`) | **none of its three optional ones**: the plate box stays the only collider |
| `ir_impact_seal` | a child of `ImpactShutter` at identity | `Casing`, `Band`, `Seam` | none: the shutter's box |
| `ir_seal_jamb` | on the wall at the shutter's origin; it stays when the seal breaks | — | none |
| **`ir_teaching_tote` (v2, final)** | a child of `relay_crate` at identity | `Base`, `Side`, `End` | none: `CRATE_SIZE` 0.5 × 0.36 × 0.5, 4 kg, as tested |
| `ir_relay_weight` | a child of `relay_weight` at identity | `Look`, `Band`, `HandlePost`, `Handle` | none: `WEIGHT_SIZE` 0.45 × 0.6 × 0.45, 36 kg, as tested |

**About the tote:**
- It's 282 tris. The materials are `ir_tote` (satin ivory, roughness 0.40), `ir_tote_rim` and `ir_grip`, and the grips are `grip_hand_0/1`.
- Its walls are single double-sided surfaces; the GLB says so, and Godot's importer keeps it.
- Its floor sits 1 cm up, so it never z-fights with the deck.

**G1's mechanics stay exactly as tested.** Keep the placeholder and the art version buildable from one branch so the owner can compare them. The art only ever goes in as visual children.

**The one known fit issue** is the plate's raceway, which ends under the launcher's west lip. The waypoint fix ends at world (−0.90, 0, +0.26), the inlet's rear face; it's in the Batch 065 handoff.

## 2. Crossing D: the ceilings, the stair and C2

**The final configuration, measured** from the hall-stair camera, with the same boxes as before:

| | lift | stair | ceiling | lift ÷ stair |
|---|---|---|---|---|
| As played | 30.2 | 29.5 | 46.7 | 1.02 |
| **Final (a + b + c below)** | 30.2 | **13.5** | **21.8** | **2.23** |

[N5: as played against the final configuration, from the hall-stair, first-arrival and stair-foot cameras](../art/review/bloom_g1_2026-10-08/N5_final_crossing_d_config.png)

The final configuration was photographed with the committed asset and the shipped floor texture. It matches the approved C2 to within 0.2 on the stair; frames differ by about 0.05 of 255 per pixel.

**(a) The five ceilings** (`HallCeiling`, `ArrivalCeiling`, `CourtCeiling`, `MachineCeiling`, `YardCeiling`) take a **local** material painted with **`assets/textures/station_local/concrete_facility_ceiling_quiet.png`**.
- **Its record:** Batch 066, sha256 `dc3836f2d89fd573…`, 128 px, covering 4.0 m. `STATION_LOCAL.json` beside it records its source and the five nodes it's for.
- **Building the material:** build it as `ThemeMaterials` builds a pack material: this texture as `albedo_texture`, `uv1_scale` 0.25 (one tile per 4 m), `uv1_triplanar` on, nearest filtering and the theme's roughness. Only those five nodes get it.
- **Never** put it into the theme pack's `ceiling` row, never write it over `assets/textures/theme/concrete_facility_ceiling.png`, and never apply it to another room. Every other ceiling stays as shipped.
- **Bringing it into `godot/`:** that's yours, through your own registry. It's first-party, generated in this repository by `tools/blender/build_station_quiet_ceiling.py`, which the art check now rebuilds and compares every run.

**(b) The stair and its landing** (`YardStair`, `StairLanding`) take the **shipped floor role**, `ThemeMaterials.floor_mat(THEME)`, instead of trim. No new texture: on this view, T2's quiet floor measured no different from the shipped one (22.10 against 22.12).

**(c) The C2 stringer:** one visual-only node in `_yard_stair()`, after `_stair("YardStair", …)`.
- **The node:** a `MeshInstance3D` with a prism mesh, or a `CSGPolygon3D` with `use_collision = false`.
- **Its material:** the stair's own, from (b).
- **Its size:** 0.08 m thick, over z from `STAIR_Z.y` (−9.5) to −9.42, outside the walk width.
- **The profile**, in (x, y):

```
steps = ceili(YARD_FLOOR / STAIR_RISE)                 # 36
tread = (STAIR_TOP_X - STAIR_FOOT_X) / steps           # 0.3306
cap   = 0.05
points = [(STAIR_FOOT_X, 0), (STAIR_TOP_X, 0),
          (STAIR_TOP_X, YARD_FLOOR + cap),
          (STAIR_FOOT_X + (steps - 1) * tread, YARD_FLOOR + cap),
          (STAIR_FOOT_X, STAIR_RISE + cap)]
```

**Unchanged in all three:** every step box and collider, the step count, traversal, the stair generator, the walls, the lift tower, the theme pack and every other room.

## 3. Reproducing the evidence

```
python3 tools/crossing_capture/stair_skirt_study.py <quiet_dir> <out_dir>
```

This writes the A, T2, C2 and FINAL capture specs. FINAL points at the committed ceiling asset and the shipped floor texture. `<quiet_dir>` is `study_station_quiet.py`'s output, needed only for T2 and C2.

Photograph them in a read-only checkout of `review/crossing-d-readability` with `tools/crossing_capture/dcap.gd`. Its `profiles` op draws the stringer with no collision.
