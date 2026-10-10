# Five weapons: layered effects, five guns and the numbers for Prod

*Arty — 2026-10-10*

**Status: a CANDIDATE (Batch 068). Not integrated, not merged. STOP.**
- The campaign, the Static Pulse, Prod's branch and the existing playtests are unchanged.
- So are Bloom, the stair, the Shunter, G1's art, the enemy library, the global palette, the UI and the theme pack.
- No loot or inventory system.

**The owner's ask (Skyiah, 2026-10-10):** five distinct playable weapons: Foundry (hand cannon), Sightline (scout rifle), Switchback (automatic carbine), Bulkhead (scattergun) and Mass Driver (charged kinetic).
- Heavy Report mode 2 is the hand-cannon baseline.
- Batch 067's flat, single-layer Glyph effects are **not approved**. That is now recorded, with a date, on 067's report, handoff, review entry and `fx.json`.

**My part (`AGENTS/ARTY.md`):**
- Foundry's layered effects first;
- persistent marks by material;
- five gun silhouettes with their motion;
- the other four's effect sets;
- a precise handoff to Prod, who owns the 3D simulation, lights, decal placement and wiring.

## What's in it

**1. The effects: 37 ECMS Glyph sheets (87db9e2) in `assets/fx/weapons/`.**
- Painted procedurally in `tools/glyphui/weaponfx_paint.py` (value noise, ramps, irregular shapes), snapped to small palettes, and authored through the Glyph CLI by `author_weapon_fx.py`.
- `fx.json` records every frame time, event, anchor node, draw order, blend and size.

**Foundry, in five layers** (the multi-stage flash the brief asks for):

| Order | Layer | What it is |
|---|---|---|
| 1 | smoke | world-anchored, rising over 0.8 s |
| 2 | brake tongues ×2 | side jets out of the muzzle brake's ports |
| 3 | flare | an irregular orange flare, rolled at random each shot |
| 4 | core | white-hot |
| 5 | afterglow | the bore's ember |

The round is a hot slug with a smoke trail behind it.

**Each of the other four has its own shape and its own palette, not a recolour:**
- **Sightline:** a cold-white cross flick, a thin cold tracer, a "pop" on the target.
- **Switchback:** two small flashes that alternate round to round, and short specks.
- **Bulkhead:** a flat, wide pellet spray; one central blast per surface, not one per pellet; a clustered mark.
- **Mass Driver:** charge bolts in four levels; a release of pressure lines; a dense slug with a pulsed trail; a dust **shock ring** on impact (hollow, where Bulkhead's blast is a filled cloud); a fractured dish mark.

**Material impacts:**

| Material | Impact | Mark |
|---|---|---|
| **Metal** | a white-hot star breaking into streaks, then smoke | a bullet hole with a bright scraped rim, chipped paint, soot, and a hot rim that cools; also a dent |
| **Stone** | a dust burst and chips, **no sparks** | a crater with cracks |
| **Organic** | a soft, muted, wet burst: no glow, no sparks, no gore, no enemy red | a puncture and bruise |
| **Wood** | tinted dust | a splintered hole along the grain |

**2. Five viewmodels in `assets/models/weapons_five/`,** built by `tools/blender/build_weapon_viewmodels.py`:
- in the Viewmodel's own space, flat-shaded, neutral metals, 188–312 triangles;
- named `muzzle`, brake-port, ejection and accumulator nodes;
- each moving part (Foundry's cylinder and hammer, Sightline's bolt handle, Switchback's bolt, Bulkhead's pump, Mass Driver's three accumulator rings) is its own node, with its origin at its pivot;
- Foundry's muzzle sits **exactly** on Prod's `MUZZLE`.

**3. Recoil signatures in Prod's own spring format.**
- Foundry is mode H, unchanged. Through his integrator it gives 0.196 m and 19.0° at peak, against his measured 0.196 m and 19.1°. The builder refuses if that drifts.
- The other four are shaped to differ: a crisp jolt, a fast buzz with a held-fire climb, a slow body-blow, and a long straight push whose field of view dips.

**4. The handoff:** `docs/art-requests/2026-10-10-five-weapon-fx-handoff.md`. It covers:
- events (his existing `fired_pulse` and `_impact`; no new ones);
- the `impact_material` tags he already has;
- FOV 90, nodes and pivots, layer order and frame timings;
- the 3D choreography for sparks, chips, droplets and splinters, as numbers;
- lights per weapon (intensity, colour, decay);
- decal shapes and sizes, with persistence: no fade, a cap, oldest recycled, parented to the hit collider.

## The evidence: frozen in Prod's own range

**How it was photographed:**
- A read-only checkout of `review/hand-cannon` at `da0a859e`.
- The player's Pulse device was hidden and each candidate gun placed where a Viewmodel child sits.
- The range has Prod's steel plate, gel block, timber crate, and stone floor and walls.
- Every moment is a time after the trigger, computed from the source:
  - the gun's pose from its springs (Prod's integrator);
  - each layer's frame from `fx.json`;
  - the round at 320 m/s;
  - the light decaying from 7.0.

**It is a time-lapse, not a playtest.** Moving it is Prod's runtime.

| | |
|---|---|
| [FW1: Foundry, one shot at ten times, from the eye, beside the line and at the plate](../review/five_weapons_2026-10-10/FW1_foundry_timelapse.png) | [the eye, in real time (GIF)](../review/five_weapons_2026-10-10/FW1_foundry_fp_realtime.gif) · [slowed](../review/five_weapons_2026-10-10/FW1_foundry_fp_slow.gif) · [beside, slowed](../review/five_weapons_2026-10-10/FW1_foundry_side_slow.gif) |
| [FW2: Foundry's layers in draw order, with their times](../review/five_weapons_2026-10-10/FW2_foundry_layers.png) | [FW3: one hit on every material, then only the marks, and in grey](../review/five_weapons_2026-10-10/FW3_materials.png) |
| [FW4: the five guns, beside the head, at rest, the shot's frame and 50 ms](../review/five_weapons_2026-10-10/FW4_five_guns.png) | [FW5: the five in grey](../review/five_weapons_2026-10-10/FW5_five_guns_gray.png) |
| [FW6: the recoil signatures, back and muzzle rise over 500 ms](../review/five_weapons_2026-10-10/FW6_recoil_signatures.png) | [FW7: Mass Driver's rings through the charge, and the release](../review/five_weapons_2026-10-10/FW7_massdriver_charge.png) |
| [FW8: the other four sets, and the shared impacts and marks](../review/five_weapons_2026-10-10/FW8_effect_sets.png) | [FW3b: the close-ups at native pixels, hit and mark](../review/five_weapons_2026-10-10/FW3b_marks_native.png) |

## Findings, including what the first passes got wrong (all fixed the same night)

1. **The five read as five guns,** in colour and in grey:
   - short and heavy, with a brake;
   - long, with a scope;
   - square, with a magazine and a stock;
   - broad, with two bores and a pump;
   - an open frame with rings.

   The builder checks it: no two guns' side-plus-top profiles overlap by more than 60 %; the worst pair is 0.55. Side-only, Foundry and Bulkhead first overlapped 0.67. That was a real finding: Bulkhead wasn't broad. It's now 0.14 m wide with splayed bores.
2. **Bulkhead's first flash was Foundry's shape stretched** (silhouette overlap 0.67), and the author script refused it. It's now a flat spray with pellet spikes.
3. **The grips raked the wrong way:** my pitch sign was the opposite of Godot's (Prod's grip is −16°). It was caught in the first render and fixed at the source.
4. **Foundry's layers read in motion:**
   - core and flare and tongues for 0–67 ms;
   - the room lit warm and fading by about 117 ms, with the gun's shadow thrown by the muzzle light;
   - the plate flashing when the round lands at about 31 ms;
   - the smoke left hanging where the shot left the barrel as the gun recovers beneath it.
5. **The round was invisible at its drawn size:** at 320 m/s it crosses about 5 m a frame. The handoff now says to stretch it along the travel (slug 0.9 m, trail 3 m). From the eye it still mostly hides behind the flash, flying straight away, which is right. Beside the line it reads as a streak with a hot head.
6. **The marks were invisible at real scale** (a 7 cm hole is 2–3 px at 9 m). They're now game scale (0.16–0.45 m a cell, in line with Prod's own 0.22–0.4 m) and redrawn with a larger bore, a chipped ring and stronger soot or bruise.
7. **Mass Driver's violet light washed the range toward the blue "movement" signal.** It's now a pale cold white at 3.0, and the release sheet is 0.5 m, off the reticle.
8. **The first smoke hung in front of the gun.** It's now smaller and 0.25 m ahead of the muzzle.
9. **The hot rim outlived the shot:** its sheet was set to hold its last frame, so a "cold" hole still glowed at 5 s. It now plays once and is gone after about 2 s; the hole stays.
10. **Reticle:** at each gun's peak the flash sits right of and below centre. Foundry's flare at the top of its flip comes closest. If it ever crosses the crosshair in play, shrink the flare first.

## Checks

- **`author_weapon_fx.py`** refuses the kit if:
  - a frame is empty;
  - the impacts' value order collapses (metal > stone > organic);
  - any two muzzle flashes share a silhouette (IoU over 0.6).

  Two runs gave byte-identical files.
- **`build_weapon_viewmodels.py`** refuses the guns if:
  - Foundry's muzzle leaves `MUZZLE`;
  - its springs stop reproducing Prod's H;
  - two profiles converge.

  Every mesh is asserted flat and in budget ("hero", 1200).
- **`check_art_current.sh`** now lists the new builder and rebuilds both Glyph kits behind the same gate as the interface family. Result: ART_CHECK_RESULT.

Not checked:
- **Motion as played:** these are computed frozen frames.
- **Prod's 3D sparks, chips and lights:** proposed as numbers and not drawn, except the lights.
- **Sound**, which is Condi's.
- **Windows.**
- **The pinned-Production run (FU-1):** that remains a pinned-Production failure, not a compatibility pass.

## Candid limitations

- **The guns are deliberately low-poly maquettes:** boxes and prisms, flat colour, no texture. They are silhouettes and motion concepts, not finished models.
- **Four of the five recoil signatures are proposals nobody has played,** as is everything except Foundry's.
- **Wood borrows stone's dust, tinted.**
- **"Organic" is judged on Prod's gel block,** the only organic surface in the range.
- **Stone's first dust frame has grey radial streaks.** They're not sparks, but at a glance in colour they echo a star.

## Owner questions

1. **Are these five silhouettes the right start for the five roles?** Which one most needs a second pass?
2. **Are game-scale marks right,** visible from the firing line, or should they be smaller and more realistic?
3. **Mass Driver's accent:** pale cold white (as delivered), or a stronger violet, kept clear of movement blue?

**STOP.** No watchers, subscriptions or merges.
