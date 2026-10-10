# Five weapons: art handoff for Prod (Batch 068, candidate)

*Arty — 2026-10-10*

**For:** Prod. **Owner, 2026-10-10 (Skyiah):** five distinct playable weapons: Foundry, Sightline, Switchback, Bulkhead and Mass Driver. Heavy Report mode 2 is the hand-cannon baseline. Batch 067's flat, single-layer Glyph effects are **not approved**. The owner wants layered 2D + 3D feedback, dynamic light, sparks, smoke, convincing recoil, material-specific impacts and persistent marks.

**The split (the brief's `02_EFFECTS_AND_IMPACT_CONTRACT.md`):**
- **Prod:** event timing, 3D particles, lights, decal placement, state and cleanup.
- **Me:** the authored 2D frames, the gun geometry, and the numbers below.

**What I read it against:** your `review/hand-cannon` at `da0a859e`, mode H in `hand_cannon.gd` and the range in `weapon_feel.gd`. Your branch is unchanged. Every photograph comes from a read-only checkout of it.

## What there is

| | Where | Source |
|---|---|---|
| 37 Glyph sheets and `fx.json` | `assets/fx/weapons/<weapon>/`, `impacts/`, `marks/` | `tools/glyphui/author_weapon_fx.py` (painters in `weaponfx_paint.py`), ECMS Glyph 87db9e2 |
| Five viewmodels and `manifest.json` | `assets/models/weapons_five/` | `tools/blender/build_weapon_viewmodels.py` |
| The photographs | `docs/art/review/five_weapons_2026-10-10/` | `tools/crossing_capture/five_weapon_study.py`, `five_weapon_sheets.py` and `dcap.gd` |

Both kits rebuild byte-identically, and `check_art_current.sh` rebuilds and compares them.

## Events: yours, unchanged

**No new events.** Everything hangs off your existing ones:

| `fx.json` event | Your hook |
|---|---|
| `fired` | `fired_pulse` → the muzzle layers at the `muzzle` node, and the light |
| `projectile` | your streak (`_streak(from, to)`), from `_muzzle.global_position` to the resolved hit |
| `impact:<material>`, `mark:<material>` | `_impact(at, normal, collider)` on the same ray, reading the collider's `impact_material` meta |
| `charging`, `released` (Mass Driver) | the charge primitive you choose (`EchoRuntime`'s charge shot is the brief's suggestion) |

**Material tags:** I used your `impact_material` meta (`metal | stone | wood | flesh`) rather than inventing `surface_*` groups. The brief says to inspect what exists first, and yours exists. Untagged surfaces fall back to `stone`; please log the fallback in the check, as the brief asks.

## Layers: what plays, where, when, in what order

`order` is the draw order, 1 at the back. Set it with `sorting_offset` or `render_priority`. Every sheet is one row, frame 0 at the left, nearest filtering, no mipmaps. `fx.json` holds the complete table.

**Foundry, on `fired_pulse`:**

| Order | Sheet | At | Frames (ms) | Size | Blend | Notes |
|---|---|---|---|---|---|---|
| 1 | `foundry_smoke` | **world-anchored**, 0.25 m ahead of where the shot left the barrel, from 17 ms | 60/80/100/140/180/240 | 0.4 m | mix | rises about 0.3 m over 0.8 s |
| 2 | `foundry_brake_tongue` ×2 | `brake_port_l` and `brake_port_r` | 17/17/33 | 0.36 × 0.12 m | add | a quad from the port, 0.36 m outward (∓X), turned to face the camera about its own axis |
| 3 | `foundry_flash_flare` | `muzzle` | 17/17/33 | 0.5 m | add | **a random roll each shot** |
| 4 | `foundry_flash_core` | `muzzle` | 17/17 | 0.18 m | add | white-hot, on top |
| 5 | `foundry_afterglow` | `muzzle`, from 34 ms | 50/80/120/200 | 0.05 m | add | the bore's ember |

The flash layers follow the gun as it kicks. The smoke stays in the world.

**Every weapon's muzzle and projectile:**

| | Flash (at `muzzle`) | Round in flight | Muzzle light (proposal) |
|---|---|---|---|
| **Foundry** | the five layers above | `foundry_slug` (hot head) plus `foundry_trail` (smoke behind) | **your 7.0**, `#ffb86b`, shadows on, dark in about 117 ms (as H) |
| **Sightline** | `sightline_flash`, cold white, 2 × 17 ms, 0.22 m | `sightline_tracer`, a thin cold line | 3.0, `#dfe8ff`, no shadows, τ ≈ 20 ms |
| **Switchback** | `switchback_flash_a` and `_b`, **alternating round to round**, 0.24 m | `switchback_tracer`, a short speck | 2.5, `#ffb86b`, no shadows, τ ≈ 15 ms; one light, re-triggered, never stacked |
| **Bulkhead** | `bulkhead_flash`, a flat wide pellet spray, 0.7 m | `bulkhead_pellet` × pellets, thin, 25 ms | 8.0, `#ffb86b`, shadows on, τ ≈ 40 ms |
| **Mass Driver** | `massdriver_release`, pressure lines, 0.5 m | `massdriver_slug` plus `massdriver_trail` (pulsed segments) | charge: 0 → 1.2 at `accumulator`, `#e4e0ff`; release: 3.0, `#e4e0ff`, τ ≈ 30 ms |

The Mass Driver light is pale on purpose. A strong violet washed the range toward the blue "movement" signal on the first pass.

**Stretch the round along its travel.** At 320 m/s a round moves about 5 m a frame, so a sheet drawn at its own size is invisible in flight. I photographed the slug stretched to 0.9 m and the trail to 3 m behind the head, at their authored widths. That's in line with your 1.2 m streak cap. Start both at `muzzle`; H already does.

## Impacts and marks, by material

The shared material sheets are scaled per weapon:
- Foundry ×1.0;
- Sightline ×0.6 (its `sightline_pop` instead of the metal flash);
- Switchback ×0.45.

Bulkhead and Mass Driver have their own blast, shock ring and mark (the last section below).

| Material | 2D (`impacts/`) | 3D, yours (proposal) | Light | Mark (`marks/`) |
|---|---|---|---|---|
| **metal** | `impact_metal_flash` (17/17/33, add), then `impact_metal_smoke` from 34 ms | **sparks:** 14–20 velocity-aligned streaks (length = speed × 0.02 s); 4–9 m/s in a 55° cone about the reflected ray, biased to the normal; gravity, drag 1.5; life 0.25–0.5 s; colour white `#fff4d8` → orange `#ffa040` → dull red `#802010`; two or three bounce once | 1.4, `#ffc890`, 0.45 m off the face, τ ≈ 40 ms, no shadows | `decal_metal_hole` (two variants, random roll) with `impact_metal_heat` on top, cooling over about 2 s |
| **stone** | `impact_stone_dust` (33/50/83/117/167, mix) | **chips:** 6–10 quads from `impact_stone_chips` (three variants), 3 cm, 2–4 m/s in a 70° cone on the normal, gravity, life 0.6–0.9 s. **No sparks** | none (at most 0.6 for 17 ms) | `decal_stone_crater` (two variants, random roll) |
| **flesh** (gel, organic) | `impact_flesh_splash` (mix): a muted, wet, soft burst, no glow | **droplets:** 4–6 quads `#6a3436`, 1–2.5 m/s, gravity, life 0.4 s. The target reacts (your gel jiggle). **No sparks, no light, no gore** | none | `decal_flesh_mark` |
| **wood** | `impact_stone_dust` tinted `#d8c8a8`, at 0.5 × scale | 4–6 pale splinters, 4 × 1 cm, `#c8a878`, 2–4 m/s | none | `decal_wood_mark`, +X along the grain |

**Bulkhead:**
- **One** `bulkhead_blast` at the pattern's centre, per surface hit, not one per pellet;
- **one** `bulkhead_mark` (a centre and its pocks) at the centre;
- at most three extra `switchback_pock` marks for strays;
- sparks capped at 24 a shot, in total.

**Mass Driver:**
- `massdriver_impact`, a dust **shock ring** thrown outward (hollow, where Bulkhead's blast is a filled cloud);
- `massdriver_mark`, a broad flattened dish with stress fractures;
- on metal, 20 sparks;
- on stone, twice the chips.

### Persistent marks (the brief's rule 5)

- **Place them with your `Decal` node,** as `_mark` does: projected, so they cannot z-fight or float. Use the albedo from the sheet's frame (pick a variant at random), random roll, size = `size_m`.
- **Sizes are game scale, not real scale.** A real 7 cm hole is 2–4 px at the range's 9 m (FW3 proved it on the first pass), so each mark cell is 0.16–0.45 m, soot and scrape included. That's in line with your 0.22–0.4 m. The bore stays small inside it.
- **No time fade.** Keep them until the room resets. Cap them at about 64 a room and recycle the oldest with a 0.3 s fade. Today's `MAX_MARKS 32` with an 8 s fade contradicts the brief's "not a three-second fade"; the numbers are yours to choose.
- **Parent each mark to the collider it hit, not `_world()`,** so it goes when a destructible goes (the brief: "must not persist after their owning destructible surface is gone").

## The viewmodels (`assets/models/weapons_five/`)

Each GLB is in the **Viewmodel's own space**: origin = your `Viewmodel` node, −Z forward, +Y up. Foundry's `muzzle` is exactly your `MUZZLE` (0, 0.03, −0.47), so it drops in where the placeholder revolver is.

**Named nodes, positions in that frame:**

| Gun | Tris | Size (x, y, z) m | Points (empties) | Moving parts (origin = pivot) |
|---|---|---|---|---|
| `foundry` | 212 | 0.094 × 0.254 × 0.572 | `muzzle` (0, 0.03, −0.47); `brake_port_l` / `brake_port_r` (∓0.034, 0.03, −0.43) | `cylinder`: rolls −60° about z per shot, over 90 ms. `hammer`: falls +38° about x on the shot, re-cocks over the cadence's last 120 ms |
| `sightline` | 256 | 0.099 × 0.236 × 1.0 | `muzzle` (0, 0.012, −0.75); `ejection` | `bolt_handle`: lifts 60° about z (80 ms), back 0.05 m (90 ms), returns (170 ms) |
| `switchback` | 220 | 0.087 × 0.244 × 0.606 | `muzzle` (0, 0.006, −0.445); `ejection` | `bolt`: slides +0.035 m on z and back inside each round's interval |
| `bulkhead` | 212 | 0.14 × 0.226 × 0.485 | `muzzle`, `muzzle_l` / `muzzle_r` (∓0.031, 0.02, −0.39); `ejection` | `pump`: back +0.07 m (110 ms) after the recoil peak, forward (130 ms); a hull drops from `ejection` |
| `massdriver` | 312 | 0.11 × 0.227 × 0.615 | `muzzle` (0, 0.01, −0.52); `accumulator` (0, 0.01, −0.30) | `accumulator_ring_1/2/3`: slide 0.025 m toward the muzzle as the charge rises (staggered by thirds, ring 3 first) and spin 0 → 720°/s; on release, snap back in 60 ms with a 6° counter-spin |

**The meshes:**
- flat-shaded, neutral gunmetal, steel, polymer and a dark grip;
- no blue, green, orange or red;
- no collision (viewmodels).

`manifest.json` repeats all of this, with each gun's rest pose and recoil.

**Rest pose per gun (camera-local, proposal).** Foundry is your `REST_POS` / `REST_ROT`. The long Sightline sits closer, so its muzzle stays right of centre.

| | Position | Rotation (°) |
|---|---|---|
| Foundry | (0.34, −0.30, −0.62) | (0, 8, −4) |
| Sightline | (0.30, −0.27, −0.42) | (0, 4, −2) |
| Switchback | (0.32, −0.29, −0.56) | (0, 6, −3) |
| Bulkhead | (0.36, −0.32, −0.58) | (0, 9, −5) |
| Mass Driver | (0.34, −0.31, −0.55) | (0, 7, −3) |

### Recoil signatures, in your `SPRINGS` format

The values are `[jump, kick, freq, zeta]`, the same channels as `hand_cannon.gd`:
- **Foundry** is H's numbers exactly. Through your integrator (60 fps, two half steps) it gives 0.196 m and 19.0° at peak, matching your measured 0.196 m and 19.1°. The builder refuses if that ever drifts.
- **The other four are proposals** shaped to read differently. Nobody has played them.

| Gun | back | pitch | roll | fov | What it reads as |
|---|---|---|---|---|---|
| Foundry | 0.19 / 4.5 / 6.0 / 0.45 | 16 / 620 / 5.5 / 0.42 | 2.5 / 40 / 6.5 / 0.5 | 3.0 | a heavy flip that overshoots past rest and settles (H) |
| Sightline | 0.07 / 1.2 / 10 / 0.75 | 4 / 90 / 9 / 0.7 | 0.4 / 4 / 10 / 0.8 | 1.2 | a crisp straight jolt, critically damped, back on target in about 55 ms |
| Switchback | 0.028 / 0.5 / 14 / 0.55 | 1.8 / 40 / 12 / 0.5 | 0.8 / 18 / 13 / 0.4 | 0.4 | small high-frequency buzz with alternating roll. **Add a held-fire climb:** +0.5° pitch rest offset a round, capped at 4°, recovering at 10°/s on release |
| Bulkhead | 0.24 / 5.5 / 4.5 / 0.5 | 12 / 420 / 4.2 / 0.48 | 4 / 60 / 5 / 0.45 | 4.5 | the biggest shove and roll, slow, a body-blow; the pump follows the peak |
| Mass Driver | 0.30 / 3.0 / 3.6 / 0.7 | 5 / 120 / 3.8 / 0.7 | 0 | **−4.0** | a long straight push with little flip; the FOV **dips**. While charging: pull in 0.02 m and a tremble that grows with the charge (0 → 0.3°, 22 Hz) |

`lift`, `cam_lift` and `cam_roll` are in the manifest. FW6 plots back and pitch for all five over 500 ms.

## The reticle and the field of view

- **FOV 90**, as the game's default, plus your FOV spring.
- **The reticle:** FW4 marks the screen centre on every first-person frame (an overlay, since the capture hides the HUD). At each gun's peak frame, the flash sits at the muzzle, right of and below centre. Foundry's 0.5 m flare at the top of its flip comes closest. If it ever covers the crosshair in play, shrink the flare first (0.4 m), not the core.

## Not mine, so not done

- The 3D sparks, chips, droplets, splinters, lights, decal placement, cap and cleanup are your code. The numbers above are proposals.
- Damage, cadence, pellet count, spread, charge time, falloff and object impulse (Dess's and yours).
- The audio (Condi's).
- Wiring any of it: these are candidates, not integrated.

If you hit something, name the sheet and the frame or field, or the node. I'll change it in the source and re-export.
