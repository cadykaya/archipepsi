# The combined Crossing's readability kit (Batch 063)

*Arty — 2026-10-02*

This is a small kit, built through the art pipeline: a floor lever, a power raceway and three accent strips. Its status is **PROPOSAL** and its review is pending. It is not in the content pack, not integrated and not merged; Prod decides how it enters the Crossing.

## Checked before building

- **Dess's brief.** I couldn't find it. It isn't in either uploaded archive or on any remote branch. All I had was the handoff's proposed four-room outline, so I built **no bespoke pieces**: no landmark and no room dressing.
- **Prod's needs.** The one I could verify is Production's lever contract (`call_lever.gd` at `17b76098`): a 0.70 × 0.70 m base and a 55° throw. The kit lever keeps both, so the existing collider still fits it.
- **Reuse.** The library already has three candidates in this area. Each is the wrong tool for the Crossing's power lines:
  - the 043/049 conduit family is a 0.50 m wall-plane band for signal *state*, still open as decision A2;
  - the 046 yard lever has no pivot and is authored for one platform's height;
  - the 043 switch is hand-scale and wall-mounted.

  The only approved piece in this area is `fixture_light_concrete_facility`. Use it for lighting.

## Wisp's three repairs, reviewed

| Fault the owner caught | Wisp's repair | Verdict, and what this kit carries forward |
|---|---|---|
| Floating diagonal power lines | Orthogonal runs on floors and walls, with clips | **Fixed.** Corners were still bare pipe joins with small clips. Here, every turn is an elbow fitting and a saddle straps each metre. |
| Floating levers with no visible state | Floor pedestal, bolts, pivot, OFF-right / ON-left throw, a pilot that turns as it lights | **Fixed.** The handle was solid green, so green coloured a part that never changes state. Here the handle is neutral; green is only the pilot, the ON word and the line's core. |
| Stair sides not matching the walls | Wall texture at 32 px/m, mapped world-planar | **Fixed in Wisp's build, but stale for ours.** Her "approved" wall texture is the version from Production baseline `e0421aaa`, from before the 24 September course ruling. It differs from the current shipped wall (`17b76098` and every art branch) in 4,045 of 16,384 pixels. On a current baseline the stairs would mismatch the walls again. Rebuild them from the current texture through `tools/blender` rather than copying textures. |

## The kit

| Asset | What it does | Moves / state | Collision |
|---|---|---|---|
| `ck_floor_lever` | A permanent lever standing on the floor, labelled with stencilled ON/OFF. A rear gland is where its power line starts. | `lever_hinge`: off −55°, upright 0° (as built), on +55° about Godot +Z (toward the player). `pilot_hinge`: 0° (flat) to 90° (upright). | Convex twins on the foot, pedestal and head. The moving parts carry none. |
| `ck_raceway_run` | A 1.00 m straight that tiles end to end. | `power_core` | none |
| `ck_raceway_inside` | A concave corner, floor to wall or wall to wall. | `power_core_a`, `_b` | none |
| `ck_raceway_outside` | A convex corner, over an edge. | `power_core_a`, `_b` | none |
| `ck_raceway_turn` | A 90° turn on one surface, such as up a wall and then along it. | `power_core_a`, `_b` | none |
| `ck_raceway_terminal` | Where a line ends at the thing it powers. | `power_lens` is the destination's badge. | none |
| `ck_accent_movement` / `_destructible` / `_hazard` | Flush 1.00 × 0.125 m strips: blue chevrons, orange scoring, yellow-and-black stripes. | none | none |

**Using the pieces:**
- **Mounting.** Each raceway piece lies on its surface with Godot +Y out of it. On a wall, turn +Y to the wall's normal.
- **Power state.** Pieces ship in the idle colour, a dark green that still reads as a power line. When live, the runtime sets the `power_` nodes to `#55e078` and makes them emit.
- **Swatches.** The five meaning textures are also saved in `assets/textures/batch063/`, for meshes Production builds in code.
- **Collision on floors.** Lay floor runs along wall bases. A run that crosses a walking line needs a code-side box no taller than the run, which is 0.13 m.

**Reading without colour:**
- **Lever:** the arm rests left (ON) or right (OFF) under the stencilled word, and the pilot is flat for OFF and upright for ON.
- **Accents:** each has its own shape — chevrons, scoring or stripes.

**Landmark, lighting and views** wait for the Crossing's brief. Until then: light the destinations and each machine's two ends with the approved fixture, and keep the power line visible from the lever to the thing it opens.

## Conflicts and decisions for the owner

1. **The colour meanings overlap the locked palette.** The table is in `ART_BIBLE.md`, under the green/orange split.
   - **Overlaps.** Power green sits 30° from Epsilon's `identity` green, destructible orange 11° from `hazard`, and hazard yellow 3° from the Check's `send` beam.
   - **Shipped art built on the old meanings:**
     - enemy optics (identity green);
     - the library's hazard stripes (the orange ramp);
     - the Check beam (yellow);
     - interact prompts (`signal` teal).
   - **What I changed.** Nothing in the library (FU-4). This kit is kit-local. Recolouring the library is your decision, not one I took.
2. **The library now has two conduit scales.** I recommend this kit's raceway for power routing, and keeping the 043/049 band for A2's signal-state question.
3. **Wisp's stairs** sit outside the pipeline, as hand-saved `.blend` files with copied textures, and they use the stale wall texture. If Crossing D needs those stairs, the art lane rebuilds them through `tools/blender`.
4. **Naming.** Don't name a kit material `hazard`. Production's theme binding re-skins that name with the orange ramp.
5. **A1, the permanent control.** This lever doesn't *visibly lock*. Its two stops are physical. If you want a latch tell, it's a small addition.

## Files, revision and rebuilding

- **Branch:** `claude/archipepsi-art-crossing-kit-2026-10-02`, based on the repairs branch (`1ee9e97f`).
- **Kit commit:** `eb8fceda`.
- **Editable source:** `tools/blender/build_crossing_kit.py`. Every dimension is a named constant. There's no hand-saved `.blend` by design, because a hand-saved file plus copied textures is exactly how the stair texture went stale.
- **Review-only scenes:** `tools/blender/crossing_kit_review.py`.
- **Exports:**
  - `assets/models/batch063/crossing_kit/*.glb` and `manifest.json`, which records the hinges, states, mounting and collision;
  - `assets/textures/batch063/*.png`.
- **Shot list:** `tools/shots/batch063_crossing_kit.json`.
- **Rebuild:**

      .tools/blender/blender -b --python tools/blender/build_crossing_kit.py [-- <dir>/models/review063]

- **Review views:** run `tools/artpreview/shoot.gd` with an assets root that holds `models/batch063` and `models/review063`. The views are in `docs/art/review/crossing_kit_2026-10-02/`.

## What I checked

- **The pipeline's own checks** on every part:
  - exactly 32.0 texels/m;
  - flat shading;
  - every part connected;
  - within the triangle budget (the largest piece, the lever, is 168 tris).
- **The build:** a rebuild is byte-identical across all 15 outputs.
- **The art checks:**
  - `check_docs_metrics.py`: 388 of 388;
  - `check_art_current.sh`: the static rules and gates; its rebuild of every builder was skipped on purpose.
- **In Godot 4.5.1:** the engine's own import, photographed by the shot runner. It shows the lever at both positions and the power route unpowered and live.

**Not checked:**
- the kit inside a Production room;
- a runtime driver for the hinges or the live state;
- Windows;
- audio, which is Wisp's.

## Pictures

All are from the engine's own import (Godot 4.5.1), photographed on the art bench by `tools/shoot.sh`'s runner:

- [The kit as exported](../review/crossing_kit_2026-10-02/K1_kit.png) and [its silhouette](../review/crossing_kit_2026-10-02/K1_kit_silhouette.png)
- [The lever: OFF, then ON](../review/crossing_kit_2026-10-02/K2_lever_states.png)
- [The power line unpowered](../review/crossing_kit_2026-10-02/K3_route_off.png), then [live](../review/crossing_kit_2026-10-02/K4_route_on.png), from the player's eye at 1.6 m
