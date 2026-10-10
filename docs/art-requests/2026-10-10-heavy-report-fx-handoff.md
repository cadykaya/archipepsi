# Heavy Report effects: integration handoff (Batch 067, candidate)

*Arty — 2026-10-10*

> **Dated correction, 2026-10-10 (Arty).** The owner's ruling, in the
> five-weapon brief: this kit is **NOT APPROVED** as the final look. It is
> "flat, single-layer, one-colour, pixel-sprite-like". It is superseded by
> Batch 068, the layered five-weapon kit
> (`docs/art/reports/2026-10-10-five-weapons.md`). The files stay as
> history; nothing below is rewritten.

**For:** Prod. **Owner, 2026-10-10:** Mode 2, Heavy Report, is the winning hand-cannon feel. Effects are authored in GLYPH rather than generic debug geometry. Metal impacts spark; organic and stone get their own distinct responses. No gun redesign.

I read this against `review/weapon-feel` at `6fe82e6c` (build `b8295b6a`), treatment `"a"` in `weapon_feel_treatments.gd`. Your branch, `SPEC`, the gun and the viewmodel are unchanged; the photographs come from a read-only checkout of your range.

## What it replaces, event by event

| Your event | What it does today | What the kit gives it (`assets/fx/heavy_report/`) |
|---|---|---|
| `fired_pulse` → `_muzzle` | a `SphereMesh` fireball at `MUZZLE`, 0.34 m, shrinking over 0.05 s | **`fx_heavy_muzzle`**: 3 frames (17 / 33 / 100 ms), a star bloom that turns to smoke. A billboard at the same `MUZZLE`, 0.34 m, additive. **Keep your flash light** (5.0, warm, 0.14 s) |
| `fired_pulse` → `Player._spawn_tracer` | a glowing `BoxMesh`, 3 cm, 0.06 s | **`fx_heavy_tracer`**: 2 frames (17 / 33 ms), a quad stretched muzzle → hit, 0.08 m wide, its head at +X (the hit end) |
| `fired_pulse` → `_impact(at, normal, collider)` on the same ray | 18 `BoxMesh` grains, a warm `OmniLight`, the same for every surface | **one flipbook per surface** (below), and spark-streak particles on metal |
| `hit_confirmed(killed)` | your marker and knock | **unchanged** |

The tracer sheet is **white and grey on purpose**. `_spawn_tracer` tints the beam from pale blue toward magenta as Static builds up; that's a game signal, so your colour stays the tint.

**One mismatch to settle (yours):** the tracer starts at camera-local (0.15, −0.12, −0.3), but the bloom sits at the viewmodel muzzle, (0.34, −0.28, −0.92). For Heavy Report I'd start the tracer at `MUZZLE`, so the beam leaves the barrel. I photographed it that way.

## Per surface (`_impact`)

| Surface | Flipbook | Particles | Light | Mark |
|---|---|---|---|---|
| **Metal** | `fx_impact_metal`, 4 frames (17 / 33 / 67 / 100 ms): a white-hot star, then radial sparks, then embers. A billboard, additive, 0.6 m | 10–14 `fx_spark_streak` quads, velocity-aligned (`particle_flag_align_y`), 2.5–6 m/s, 40° spread, gravity. Your emitter settings already fit | your warm splash (2.5) | none |
| **Stone / concrete** | `fx_impact_stone`, 4 frames (17 / 50 / 83 / 117 ms): a small first-frame flash, then a lobed dust puff, pale fragments, and a fade. A billboard, **alpha** blend (dust isn't light), 0.7 m | 6–8 pale fragments (a 2 px quad in `chip_l`), gravity, 1.5–3 m/s | none, or under 0.6 for the first 17 ms | `fx_decal_chip`, 0.28 m |
| **Organic** | `fx_impact_organic`, 4 frames (17 / 50 / 83 / 117 ms): a dark wound with pale ichor droplets and strands. A billboard, alpha blend, 0.55 m | 4–6 droplets (`ichor_m`), gravity, 1–2.5 m/s | **none** | `fx_decal_sap`, 0.24 m |

Every flipbook ends inside the time your treatment already gives it. The muzzle's frames total 150 ms, against your flash fading at 140 ms; the impacts take 217–267 ms, inside your `impact_time` of 300. **Decals** fade over the last second of three. Cap how many there are, oldest first.

**Telling the surface: your call, with my suggestion.**
1. **An explicit tag wins.** A collider in group `surface_metal`, `surface_stone` or `surface_organic`, or with meta `impact_surface`.
2. **Otherwise, enemies by archetype.** The Shunter, a station machine, is metal; that matches D-19's "spark and clang" off its plough.
3. **Otherwise, room geometry by its theme role.** Trim and machinery are metal; wall, floor and ceiling are stone.
4. **Default: stone.**

**The range's dummy:** which surface it is is yours and the owner's to decide. It sits unchanged in all the photographs.

## What the art guarantees (and the author script checks)

- **Told apart without hue.** Metal's ink is the brightest (mean luminance 240), stone mid (187), organic the darkest (84). No two impacts share their first frames' silhouette (overlap under 50 %). This is A12.4's rule, applied to surfaces.
- **No red on organic** (red is the enemy cue) and **no orange bands**. Warm colours appear only in the flash and the sparks, for a fraction of a second.
- **No frame touches its cell's edge**, so nothing bleeds in an atlas. The beam and the streak run edge to edge by design.
- **A12.5:** the bloom at `MUZZLE` stays clear of the crosshair (screen offset about 0.48, radius about 0.18, both in half-heights).

## Files

- `assets/fx/heavy_report/`: 8 sheets (one row each, frame 0 at the left, nearest filtering, no mipmaps), and `fx.json`, which holds every frame's duration, the event, blend, size, particles and light.
- **Source:** `tools/glyphui/author_heavy_report_fx.py`, through ECMS Glyph 87db9e2. Rebuilding is byte-identical, and the art check now rebuilds and compares the kit.
- **The study:** `tools/crossing_capture/heavy_report_fx_study.py`, plus the capture driver's new `sprites`, `room_var`, `show_player` and `player_eye` options.

## If you hit something

Name the sheet and the frame or field. I'll change it in the author script and re-export; I won't redesign anything.
