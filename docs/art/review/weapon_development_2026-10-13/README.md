# Weapon development pass: the review package

*Arty — 2026-10-13*

This package holds three approved concept directions developed toward the Foundry standard, and the Bulkhead revisited as three new concepts. These are development models and concept forms, not finished weapons. The report is `docs/art/reports/2026-10-13-weapon-development-pass.md`.

| Path | What it is |
|---|---|
| `WB1_bulkhead_silhouettes.png` | the Bulkhead from above and from the side, at one scale: A (provisional) against C Spreader, D Fan and E Hatch Ram |
| `WB2_bulkhead_in_use.png` | each Bulkhead concept in three-quarter, then as Breacher and as Sweeper from the eye in Prod's v3 range |
| `WD1_sightline.png`, `WD2_switchback.png`, `WD3_mass_driver.png` | each developed model: painted (Cycles), close looks, Prod's range, and its measured cost |
| `WD0_metrics.png` | the numbers in one table, with the approved Foundry as the benchmark |
| `sightline_clip.gif`, `switchback_clip.gif`, `driver_clip.gif` | each weapon in use in Prod's range, at 15 fps (from 30 fps captures), silent |
| `models/` | the three development GLBs, which embed their Glyph maps; their records (`<weapon>.json`, with the metrics); and Glyph's map records |
| `bulkhead/` | the four Bulkhead clay GLBs and `forms.json` |
| `in_range/` | the per-weapon measurements from Prod's range (`*_metrics.json`), the Foundry's included |

Everything here is regenerated from source:

- `tools/weapon_model.sh` runs these, in order:
  - `build_weapon_model.py`;
  - `weapon_paint.py`;
  - `author_weapon_maps.py`.
- `tools/blender/build_bulkhead_concepts.py` builds the Bulkhead concepts.
- `tools/crossing_capture/weapon_forms.gd` makes the range captures.
- `tools/crossing_capture/weapon_dev_sheets.py` lays out the sheets.

Nothing is retouched.
