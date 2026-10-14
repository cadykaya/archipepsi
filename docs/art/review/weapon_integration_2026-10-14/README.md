# The five weapons, integration candidate: the review package

*Arty — 2026-10-14*

This package holds all five weapons, built for integration and run on Prod's runtime in his five-weapon range with the layered Glyph effects. They are captured against his placeholders and measured. Nothing is merged; it waits on your in-game review.
- The report: `docs/art/reports/2026-10-14-five-weapon-integration.md`.
- Prod's instructions: `docs/art-requests/2026-10-14-five-weapon-integration-note.md`.

| Path | What it is |
|---|---|
| `IW0_lineup.jpg` | the five together, from the player's eye: at rest, and one frame after the shot |
| `IW2_bulkhead_d.jpg` | Bulkhead D (Fan), developed: Cycles looks and close-ups, then Breacher and Sweeper in the range |
| `IW1_foundry.jpg`, `IW1_sightline.jpg`, `IW1_switchback.jpg`, `IW1_bulkhead_breacher.jpg`, `IW1_bulkhead_sweeper.jpg`, `IW1_driver.jpg` | each against Prod's placeholder: at rest, aimed, charged (the Driver) and on the shot, with clearance figures; the hit on metal, stone, wood and gel from a second eye in the same frame; the mark 1.7 s later |
| `IW6_memory.jpg` | the 10-13 Sightline and Mass Driver beside the repacked ones, under the same Cycles cameras |
| `IW7_costs.png` | triangles, materials, draw calls, texture memory before and after, density, and clearance |
| `IW8_timing.png` | every moving part, the readiness and the Glyph flash against the shot, placeholder against art |
| `<weapon>_clip.gif` | placeholder (left) and art (right) through one burst, 15 fps, silent, the gun's part of the frame |
| `integration_summary.json` | every number on the sheets |
| `models/<weapon>/` | what integration takes: `<weapon>_geo.glb` (geometry only), `lean/` (five maps and `lean.json`, the material recipe) and the model record |
| `range/` | the range runs' own records: stills, impacts and per-tick clip logs, for placeholder and art. It also holds the 10-13 "before" stills, and the RGB-normal stills of the pixel-identity check. |

The JPEG sheets are q92 without chroma subsampling. At 1:1 they cannot be told from PNG, at a third of the size; the delivery has a 30 MiB limit.

The captures run Forward+, the game's renderer, on software Vulkan. Frame times there mean nothing, so none are reported.

Everything here is regenerated from source:
- `tools/weapon_model.sh` builds the models: bake, paint, Glyph, lean maps and geometry GLBs.
- For the Foundry, `tools/blender/foundry_geometry.py` and `tools/blender/lean_maps.py` do the same.
- `tools/five_integration.sh` makes the range captures, using a read-only checkout of `review/five-weapons-v3`.
- `tools/five_integration_package.sh` assembles this folder and its sheets.

Nothing is retouched.
