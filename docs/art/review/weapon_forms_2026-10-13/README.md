# Four-weapon form pass: the review package

*Arty — 2026-10-13*

Proposed forms in clay, two per weapon, for the owner's choice. These are not final models. The report is `docs/art/reports/2026-10-13-weapon-forms-pass.md`.

| Path | What it is |
|---|---|
| `WF0_family_lineup.png` | the approved Foundry and all eight forms, as left elevations at one scale |
| `WF1_sightline.png` … `WF4_mass_driver.png` | one weapon per sheet: A beside B, with views, in-range stills, notes and a recommendation |
| `WF5_in_range.png` | all eight from the player's eye, in Prod's v3 range |
| `foundry_v3/` | FS5 (firing) and FS6 (moving): the approved Foundry on Prod's v3 runtime, with their logs (`clip.json`, `move.json`) |
| `in_range/` | the range stills at full size: rest, ADS, Bulkhead variants, Mass Driver charge |
| `renders/` | three-quarter views and left elevations for each form and the Foundry reference, reduced to 256 colours |
| `models/` | one clay GLB per form, laid out in RangeRig model space with Prod's part names, plus `forms.json` (triangles, node positions, sight lines) |

Everything here is regenerated from source:
- `tools/blender/build_weapon_forms.py`;
- `tools/crossing_capture/weapon_forms.gd` and `weapon_forms_sheets.py`;
- `tools/crossing_capture/foundry_study.gd` and `foundry_study_sheets.py`.

Nothing is retouched.
