# Heavy Report effects: a small Glyph-authored candidate kit

*Arty — 2026-10-10*

> **Dated correction, 2026-10-10 (Arty).** The owner's ruling, in the
> five-weapon brief: this kit is **NOT APPROVED** as the final look. It is
> "flat, single-layer, one-colour, pixel-sprite-like". It is superseded by
> Batch 068, the layered five-weapon kit
> (`docs/art/reports/2026-10-10-five-weapons.md`). The files stay as
> history; nothing below is rewritten.

**Status: a CANDIDATE kit (Batch 067), not integrated. STOP.**
- No gun redesign, no big batch, no merge.
- G1's art, the station materials and Prod's branch are unchanged.

**The owner's ask:** a small visual study for Heavy Report's muzzle flash, projectile tracer and material-dependent impacts. Use GLYPH for the authored effects rather than generic debug geometry. Metal sparks; organic and stone respond distinctly. Coordinate with Prod's real events.

## Coordinated with Prod's events

Mode 2 is treatment `"a"` on Prod's `review/weapon-feel` (`6fe82e6c`, build `b8295b6a`), on the Static Pulse.
- **What it answers:** the shot's two existing signals. On `fired_pulse` it plays the muzzle, the tracer, and an impact on the shot's own ray, `_impact(at, normal, collider)`. On `hit_confirmed(killed)` it shows the marker and plays the knock.
- **What it draws with today:** a `SphereMesh` fireball, 18 `BoxMesh` grains, an `OmniLight`, and the player's `BoxMesh` tracer.
- **What the kit replaces:** exactly that geometry, through the same events and inside the same times. Every flipbook ends within the window Prod's treatment already gives it, and none of his numbers change.

The integration table, surface rules and settings are in `docs/art-requests/2026-10-10-heavy-report-fx-handoff.md`.

## The kit (ECMS Glyph 87db9e2)

Eight sheets, drawn with Glyph's own line, rect and ellipse primitives and exported by Glyph's sprite-sheet preset.
- Each animated sheet has a Glyph clip carrying its frame durations.
- They are RGBA rather than indexed. Smoke and dust need partial alpha, and the CLI refuses a part-alpha entry in an indexed palette unless the project declares it, which only the easel API can do. The kit's palette is a named table in the script.

| Sheet | Frames (ms) | For |
|---|---|---|
| `fx_heavy_muzzle` | 17 · 33 · 100 | a star bloom, turning to smoke |
| `fx_heavy_tracer` | 17 · 33 | a neutral streak; the runtime keeps its Static tint |
| `fx_impact_metal` + `fx_spark_streak` | 17 · 33 · 67 · 100 | a white-hot star, radial sparks, embers |
| `fx_impact_stone` + `fx_decal_chip` | 17 · 50 · 83 · 117 | a lobed dust puff with pale fragments, and a chip mark |
| `fx_impact_organic` + `fx_decal_sap` | 17 · 50 · 83 · 117 | a dark wound with pale ichor droplets and strands, no glow, and a mark |

[HR1: every sheet, ×6](../review/heavy_report_fx_2026-10-10/HR1_sheets_x6.png)

## In Prod's range

- **How it was photographed:** each frame frozen in Prod's own range, from the **player's eye at the game's 90° field of view**, with the viewmodel visible.
- **Muzzle:** the bloom sits where Prod's sits (`MUZZLE` on the viewmodel).
- **Surfaces:**
  - **metal:** Batch 065's steel seal, at 0.6 scale;
  - **stone:** the range's own concrete floor;
  - **organic:** a labelled stand-in panel, because no library surface reads as organic at this size.

Evidence:
- [HR2: first person, frames 0–3 and the marks after](../review/heavy_report_fx_2026-10-10/HR2_first_person_frames.png)
- [HR3: side view, muzzle, tracer and the metal hit](../review/heavy_report_fx_2026-10-10/HR3_side_tracer.png)
- [HR4: material close-ups, a 38° inspection lens](../review/heavy_report_fx_2026-10-10/HR4_material_closeups.png)
- [HR5: the three materials in grey](../review/heavy_report_fx_2026-10-10/HR5_materials_in_grey.png)

**Findings, and what the first pass got wrong (fixed the same day):**
1. **Metal read right first time:** a star, sparks flying off, embers falling.
2. **Stone's first puff read as a solid disc,** and its dark chips vanished on the dark floor. It's now lobed, with pale fragments, and the chip mark is bigger with a pale ring.
3. **Organic's dark sap vanished on a dark organic surface.** It's now a dark wound with pale ichor, still no red and no light, and still the darkest of the three overall.
4. **Stone's first frame read like a small spark star.** Sparks are metal's alone, so those fragment lines are now mid-grey.
5. **In grey the three stay distinct** by shape and value: metal 240, stone 187, organic 84 mean ink luminance. The author script refuses the kit if that order or the silhouettes ever collapse.
6. **The bloom clears the crosshair** (A12.5). The one geometric mismatch is Prod's: his tracer starts at a different point from the muzzle. The handoff suggests starting it at `MUZZLE`.

## Checks

- **Author script:** passes its own checks (value order, three silhouettes, cell margins). Two runs gave byte-identical files, and the Glyph revision is recorded in `fx.json`.
- **`check_art_current.sh`:** now rebuilds and compares the kit whenever Glyph is present, with the same gate as the interface family. **PASS**, "every generated asset matches its source", with both Glyph rebuilds run (interface and effects) and none skipped; 10 m 28 s.

Not checked:
- the effects **in motion**: these are frozen frames, and playing them is Prod's integration;
- sound;
- Windows;
- the pinned-Production run (FU-1).

## Owner questions

1. **Which surface is the range dummy?**
2. **Should the muzzle bloom take the Static tint**, like the tracer, or stay Heavy Report's warm white?

**STOP.** No watchers, subscriptions or merges.
