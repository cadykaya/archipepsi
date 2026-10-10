# Station noise: two separate handoffs, R and exact T2

*Arty — 2026-10-08*

**For:** Prod (Crossing D's room code), and the owner's choice between the two.
**Owner, 2026-10-08:** keep the role-reassignment-only version and exact T2 clearly separate. **No global texture replacement.**

Both options touch the same seven nodes and nothing else: the five ceilings and the dead-end hall stair. Walls, floors, the lift tower (`Shaft*`, `TowerHead`), cover, interactables, the theme pack and the palette stay as shipped in both.

| Nodes | Today |
|---|---|
| `HallCeiling`, `ArrivalCeiling`, `CourtCeiling`, `MachineCeiling`, `YardCeiling` | painted with the trim strip |
| `YardStair` (to a gate that opens only from the yard) and `StairLanding` | painted with the trim strip |

**FINAL, later on 2026-10-08:** `docs/art-requests/2026-10-08-g1-crossing-d-final-integration.md` holds the final instructions for Prod (tote v2 approved, the quiet-ceiling asset, C2). Where this note differs, that one wins.

## The two options

| | **R: role reassignment only** | **Exact T2** |
|---|---|---|
| What changes | Two material assignments in the room code | R, **plus** two local quiet variants on those same nodes |
| Ceilings | the theme pack's **shipped** `ceiling` role, `content/theme/concrete_facility_ceiling.png` (pack sha `48977fbb859538e5`) | a **local** quiet ceiling (sha256 `dc3836f2d89fd573…`) |
| Stair and landing | the shipped **floor** role (`ThemeMaterials.floor_mat`) | a **local** quiet floor (sha256 `19af6d93aaac8c8b…`) |
| New pixels in the game | **none** | two 128 px textures, used by these seven nodes only |
| Source | the pack, as shipped | `tools/blender/study_station_quiet.py`, a study script today. Re-run on 2026-10-08, it reproduced both PNGs byte for byte |
| Global texture replacement | none | none: the pack's own `ceiling` and `floor` rows stay as they are |

**Measured.** The figures are mean edge strength in three regions of the same hall-stair view, from the same capture driver; the boxes are approximate. I re-captured A, T and T2 on 2026-10-08 with the current driver, and all three reproduced exactly.

| Variant | lift tower | dead-end stair | ceiling | lift ÷ ceiling |
|---|---|---|---|---|
| A as played | 30.2 | 29.5 | **46.7** | 0.65 |
| **R: roles only** | 30.2 | **22.1** | 29.9 | **1.01** |
| **T2: R plus quiet variants** | 30.2 | 22.1 | **21.8** | **1.39** |

[N3: A, R and T2, at the hall stair and in the Machine Hall](../art/review/bloom_g1_2026-10-08/N3_noise_roles_only_R_vs_T2.png)

**What that means:**
- **R does about two-thirds of what T2 does on the ceiling** (46.7 → 29.9, against T2's 21.8) and **all of it on the stair** (29.5 → 22.1), with no new pixels. After R, the ceiling is as busy as the lift (1.01). It no longer outshouts it, but it doesn't defer to it either.
- **T2's extra comes entirely from the quiet ceiling.** On this view the quiet floor changes the stair by 0.02 (22.10 against 22.12). So exact T2 is R plus two local textures, and only the ceiling one does anything you can measure here.
- **Only T2 makes the lift the clear loudest** of the three (1.39), which is what the owner asked for.

## Handing off R (Prod's code only)

1. **Stair and landing:** `ThemeMaterials.floor_mat(THEME)` in place of trim.
2. **Ceilings:** the pack's `ceiling` role. `ThemeMaterials` has no public accessor for it; today only floor, wall, accent, trim and hazard have one. So the stable call is `ThemeMaterials._material(THEME, "ceiling")`, or better, a one-line `ceiling_mat()` beside `floor_mat()` in your file.
   **One trap.** `_material`'s cache key is `pack|theme|kind|noise_override`, and **it leaves out `role`**. So `_material(THEME, "wall", "", "ceiling")` can come back as the cached **wall** material. Pass `"ceiling"` as the **kind**, which also makes it the asked-for role. `hazard_mat` avoids the same trap with its own `noise_override`.
3. **Scale is unchanged:** ceiling, floor and trim all cover 4.0 m a tile in the pack, at the theme's one roughness. So R is a texture change and nothing else.

## Handing off exact T2 (only if the owner picks it)

T2 is R plus two local textures, applied to these seven nodes as their own material. Before it can ship, two things need deciding, and **I won't do either without a yes:**
- **Where the textures live.** Today they're study output in scratch. To ship, `study_station_quiet.py`'s two roles would become a builder that writes them under `assets/`. They'd get their own names (for example `concrete_facility_ceiling_quiet` and `concrete_facility_floor_quiet`), be registered first-party and be checked by the art check like every other generated asset.
- **How the room reaches them.** That's a local material in the room code, never a change to the pack's `ceiling` or `floor` rows. Changing those rows would repaint every ceiling and floor that uses the role, which is the global replacement the owner ruled out.

## The choice

| | What you get |
|---|---|
| **R** | Now, with shipped textures only. Most of the gain; the lift ties with the ceiling. |
| **T2** | The lift clearly loudest. It costs two new local textures and the promotion step above. |

The two can be done in order: R first, then T2's ceiling variant, if the owner wants the last step.

## Update, later on 2026-10-08: the stair, and the owner's preference

**The owner:**
- prefers T2's direction, and for the ceiling, T2's **local** quieter treatment, with no global texture replacement;
- finds that the stair still has too much visual noise;
- wants the lift to attract attention, while the stair stays subordinate on first arrival but still recognisable as a route and a later shortcut.

**Why the stair stays noisy after T2.** Crossing D's `_stair()` builds the yard stair from 36 full-height boxes, one per 0.25 m rise. Its open side (z −9.5, the side the hall sees) is a 12 × 9 m sawtooth of stacked box faces. T2 quiets that face's texture but not its geometry.

**The candidate, C2: T2 plus one visual-only stringer.** It's a single thin plate (0.08 m) on the open side.
- **Its top:** it runs 5 cm above the line through the step nosings and flattens over the last tread, so every step's side corner is hidden behind one calm face.
- **Its material:** the stair's own. After T2 that's the quiet floor role, so the flight reads as one concrete mass.
- **Treads and risers:** they stay in that quiet concrete, which has no stripes, and light alone tells them apart. From the foot of the stair, the treads still read along the top edge.
- **What doesn't change:** no box, collider, step count or traversal number, and nothing about the stair generator. The plate sits outside the 2.5 m walk width, with no collision.

| Variant (hall-stair view, same camera) | lift tower | dead-end stair | ceiling | lift ÷ stair |
|---|---|---|---|---|
| A as played | 30.2 | 29.5 | 46.7 | 1.02 |
| T2 | 30.2 | 22.1 | 21.8 | 1.36 |
| C1: stringer in the wall material (tried, not recommended) | 30.2 | 21.6 | 21.8 | 1.40 |
| **C2: stringer in the stair's quiet concrete** | 30.2 | **13.4** | 21.8 | **2.26** |

[N4: A, T2 and C2 from the hall-stair, first-arrival and stair-foot cameras](../art/review/bloom_g1_2026-10-08/N4_stair_skirt_A_T2_C2.png)

C1 merged the stair into the north wall behind it. The stair lost its mass, and the wall's courses kept the noise.

**For Prod: the stringer, for `_yard_stair()` only.** Add it after the `_stair("YardStair", …)` call, as one visual-only node: a `MeshInstance3D` with a prism mesh, or a `CSGPolygon3D` with `use_collision = false`, which is what the study used. The polygon is in (x, y), extruded over z from `STAIR_Z.y` to `STAIR_Z.y + 0.08`:

```
steps = ceili(YARD_FLOOR / STAIR_RISE)                 # 36
tread = (STAIR_TOP_X - STAIR_FOOT_X) / steps           # 0.3306
cap   = 0.05
points = [(STAIR_FOOT_X, 0), (STAIR_TOP_X, 0),
          (STAIR_TOP_X, YARD_FLOOR + cap),
          (STAIR_FOOT_X + (steps - 1) * tread, YARD_FLOOR + cap),
          (STAIR_FOOT_X, STAIR_RISE + cap)]
material = the stair's own (_mat(kind), after T2's local quiet floor)
```

The study's source is `tools/crossing_capture/stair_skirt_study.py`. It writes the A, T2 and C2 specs, and the capture driver's `profiles` op draws the plate.
