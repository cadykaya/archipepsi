# The approved Foundry on your v3 runtime: integration note for Prod and Condi

*Arty — 2026-10-13*

**Status:** the owner APPROVED the Foundry's visual direction on 2026-10-13, and wants to see it firing, recovering, moving and aiming in a playable build with Condi's sounds before the weapon is called finished. That build is yours to make. This note says what the art side has checked, and what is still open.

**How it was written:** as a file, not a message to your session. Nothing of yours was edited. Captures used a read-only checkout of `review/five-weapons-v3` (`ef157061`, "readiness correction"), and the model was swapped in that process's memory only. I did not touch your gameplay, timings or recoil.

## 1. The study GLB works unchanged on v3

The same GLB from the study (`docs/art/review/foundry_study_2026-10-13/model/foundry_study.glb`) was captured in your v3 range. These times were logged from your own clocks and from the parts your runtime drives:

| Event (v3) | Time | What the model does |
|---|---|---|
| fire | 0 | `Hammer` falls to 0 (your snap) |
| gun home | 0.517 s | — |
| `foundry/cylinder` index | 0.30–0.48 s | `Carousel` turns 60° about the bore |
| hammer drawn | from 0.60 s | `Hammer` rises |
| hammer cocked | 0.683 s | `Hammer` at −38° (your `HAMMER_COCKED`) |
| ready | 0.733 s | about 0.19° of climb still owed |
| aim home | about 1.05 s | — |

- **Firing:** three shots through `fire_pulse` landed 44 frames apart.
- **Moving:** strafing with `move_left` / `move_right` while firing, two shots landed and the carousel and hammer kept your times.

Sheets: FS5 (firing on v3) and FS6 (moving on v3), in `docs/art/review/weapon_forms_2026-10-13/foundry_v3/`.

## 2. What integration needs, unchanged from the study

- **Node names:** the root is `FoundryStudy`, with `Body`, `Hammer` (origin at the pivot), `Carousel` (origin at the axis centre) and `Muzzle` at your (0, 0.03, −0.47). It is laid out in RangeRig model space.
- **The carousel adapter:** your `_index_drum` writes `Basis(RIGHT, PI/2) * Basis(UP, a)`. The study puts a `CarouselDrive` node between that write and its Z-axis carousel (see `tools/crossing_capture/foundry_study.gd`, `_swap`).
- **Textures:** NEAREST filtering with mipmaps, generated at load because a runtime-read glTF image carries none. A project import would give them for free.
- **Runtime-owned children:** keep `Muzzle` (and, on the driver, `ChargeOrb` and `ChargeLight`). A model swap that frees them breaks your rig: the form pass hit this on the driver and fixed it in its own capture script.

## 3. For Condi

If a separate `foundry.ready` cue is rendered, the visible event to land it on on v3 is the hammer **cocking at about 0.68–0.70 s**, just before ready at 0.733 s. In the v2 note this was the cock at 0.65 s; v3 moved it, and this note supersedes that line for v3.

## 4. Still open from the study (no answers yet)

1. **The carousel index:** rotate about the part's own Z, or keep the adapter and name it in the contract?
2. **The hammer sign:** keep −38° as the convention for real models?
3. **Reflections:** metal renders black in the Compatibility range with nothing to reflect. Is a reflection source planned, or should art keep metallic about 0.35?
4. **The import route:** a project asset, or the runtime GLTFDocument load the study used?
5. **A `Sight` node:** the Foundry has no ADS in your range. Does the owner's "aiming" mean hip aim only?

## 5. New, from the four-weapon form pass (same checkout, same method)

- **`driver/core`:** your driver writes the glow through `core.material_override`, which your placeholder builds. A GLB mesh carries its material on the mesh, so the form pass's capture hands `Core` a StandardMaterial3D override. Should real models ship with that override set at load, or should the driver write to the mesh's surface material?
- **The other moving parts by name:** `Handle`, `Bolt`, `Pump`, `Feed`, `Coils` and `Core` all dropped straight into `_parts`. Your strokes, the pump, the feed visibility and the coil spin moved them, with no other adapter.

## Not asked

- No change to damage, cadence, readiness, recoil or any envelope.
- No merge, and no change to the campaign or to existing builds.
