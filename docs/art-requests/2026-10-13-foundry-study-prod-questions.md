# The Foundry fidelity study: fit and state questions for Prod

*Arty — 2026-10-13*

**Status:** this is a NON-PRODUCTION study, and none of it is for integration. It is written down here rather than sent to your session.

**Read-only throughout:** your branch, files and range were only ever run, never edited.
- Captures used a read-only checkout of `review/five-weapons-v2` (`257fb75d`).
- Everything the study changed happened in the capturing process's memory: `tools/crossing_capture/foundry_study.gd`, run as a SceneTree script beside your own `main.tscn` with `--five-weapons`.

Report: `docs/art/reports/2026-10-13-foundry-fidelity-study.md`.

## What the study does with your runtime (unchanged)

These are your numbers, unchanged, and the study's parts follow them:

| Your state | Time | What the study shows |
|---|---|---|
| `fire` (the action's frame) | 0 | `Hammer` falls (your snap to `rotation_degrees.x = 0`) |
| `foundry/cylinder` index | 0.38–0.58 s | `Carousel` turns 60° about the bore |
| hammer drawn, then cocked | 0.56–0.66 s | `Hammer` rises to −38° |
| ready (cooldown 0.72) | 0.733 s on the 60 Hz tick | — (cocked has been the cue for 80 ms, inside your 0.15 s buffer) |

The clocks were logged from your own `clocks` dictionary in the captured run:

| Clock | Time |
|---|---|
| gun | 0.583 s |
| aim | 0.65 s |
| mech | 0.65 s |
| ready | 0.733 s |

Three shots fired through `fire_pulse` landed 44 frames apart.

## Questions (fit and state only; nothing asks you to change a timing)

### 1. The carousel's index
`_index_drum` writes `Basis(RIGHT, PI/2) * Basis(UP, a)` to the drum. That is right for your placeholder, a Y-up cylinder turned onto Z. It would be wrong for any model whose part is authored with its axis already on Z.

The study handles it by putting its `Carousel` inside a `CarouselDrive` node. The drive takes your basis, and the carousel inside it is turned back by −90° about X.

**Question:** would you rather rotate the part about its own Z (`basis = Basis(Vector3.BACK, a)`)? Or keep the adapter and name it in the contract?

### 2. The hammer's sign
Your cocked angle is −38° about X. In your frame a negative X rotation lifts geometry that lies *behind* the pivot (+Z). So the study's hammer pivots forward and its head lies back toward the eye, and −38° raises it. Hammer fallen is 0°, matching your snap.

**Question:** is −38° the convention you want kept for real models? A conventional revolver hammer, pivoting below and tilting back to cock, would need +38°.

### 3. Metal renders black in the range
The range renders through the Compatibility renderer with nothing for a metal to reflect. A fully metallic surface goes nearly black, including your own `HandCannon._metal` placeholders. The study keeps metallic low (about 0.35) and carries the steel in the albedo, as a GoldSrc skin did.

**Question:** is a reflection source (a sky, or a ReflectionProbe in the range) planned, or should art keep assuming none?

### 4. Normal, roughness and metallic maps
The owner asked for roughness and normal detail for this study. The art bible (§5) still says albedo only, and it was not changed. Your rig took the maps without a problem through `GLTFDocument` at runtime. The study loaded the GLB that way, gave the material the bible's NEAREST filter, and generated the mipmaps a runtime-read glTF image lacks.

**Question:** if this goes further, should the model be imported as a project asset (mipmaps from the importer) or loaded the way the study did?

### 5. Node names
The GLB root is `FoundryStudy`, with:
- `Body`;
- `Hammer` (origin = pivot);
- `Carousel` (origin = axis centre);
- `Muzzle`, at exactly your `MUZZLES.foundry.at` (0, 0.03, −0.47).

It is laid out in your RangeRig model space, so it drops where `Gun_foundry` sits.

**Question:** do you want a `Sight` node too? The Foundry has no ADS in your range, so the study has none.

### 6. A ready sound (Condi's)
If Condi renders a separate `foundry.ready` as you offered, the visible cue it should land on is the cock at 0.65 s.

## Not asked

- No change to damage, the 0.72 s cadence, recoil or any envelope.
- Batch 068 stays unwired.
- Nothing in the campaign or existing builds.
