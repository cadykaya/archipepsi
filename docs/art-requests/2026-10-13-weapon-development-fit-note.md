# Developed weapons and the Bulkhead concepts: fit and animation note for Prod

*Arty — 2026-10-13*

**Status:** development models and concept forms, for the owner's review. None of it is for integration yet. The owner approved three concept directions on 2026-10-13: Sightline A, Switchback A and Mass Driver A. The Bulkhead's form is not approved; three new concepts are waiting on the owner. Approved concept directions are not finished weapons, and nothing here asks to be merged. It is written down here rather than sent to your session.

**Read-only throughout:** everything was captured from a read-only checkout of `review/five-weapons-v3` (`ef157061`).
- `tools/crossing_capture/weapon_forms.gd` swaps each GLB in for your placeholder, in the capturing process's memory only.
- It points your `_parts` at the model's nodes by the names your rig already uses.
- Your input actions drive everything. Nothing of yours was edited.

Report: `docs/art/reports/2026-10-13-weapon-development-pass.md`.

## 1. What your runtime drives, and what the models give it

| Your part | Model node | Pivot (model space) | Your motion | Checked in your range |
|---|---|---|---|---|
| `sightline/handle` | `Handle` | (0, 0.021, −0.080) | `_stroke` 0.022 m back at 0.13 s | by geometry, the knob travels inside its left raceway; ring sights on your ADS line y 0.075 |
| `switchback/bolt` | `Bolt` | (−0.032, 0.021, −0.112) | 0.035 m back each round | by geometry, the lug stays inside the open left port (z −0.150 to −0.050) at full stroke |
| `driver/coils` | `Coils` (the rotor) | (0, 0, −0.150) | `rotation.z` spins with the charge | the rotor clears its cage; a painted index stripe makes the spin read |
| `driver/core` | `Core` (the accumulator) | (0, −0.062, −0.055) | glow through `material_override` | see question 1 |
| `bulkhead/pump` | `Pump` | per concept | 0.1 m back at 0.72 s (Breacher) | C, D and E each give a pump that travels clear |
| `bulkhead/feed` | `Feed` | per concept | shown for the Sweeper only | your `set_variant` showed and hid it on all three concepts |

Every model keeps `Muzzle` at your `MUZZLES[w].at`, and the driver keeps your `ChargeOrb` and `ChargeLight`. These are runtime-owned children: a model swap must leave them where you put them, or `show_charge` writes to freed nodes. The capture keeps them, and so must any production import.

Your runtime has no casing ejection, so the Switchback's left-side open port and its new deflector clash with nothing.

During the Mass Driver's charge, the brightest thing in view is your `ChargeLight` raking the rails. The model itself adds no glow beyond the accumulator. If the owner finds the charge too loud, that is the light's energy, not the model.

## 2. Cost, measured in your range

Each weapon uses one material and five maps: albedo, normal, roughness, metallic and emission. The draw calls equal the meshes: `Body` plus the moving nodes. The "measured" column is the change with the weapon shown versus hidden, the median of twelve frames each way.

The measured numbers are in `docs/art/review/weapon_development_2026-10-13/WD0_metrics.png` and in each `*_metrics.json`. They are provisional by the owner's rule: recorded now, profiled in the game once the designs are approved, and reduced only where a measurement justifies it.

The 2048² maps (Sightline, Mass Driver) are what keep their density at or above the Foundry's ~1,150 texels/m. That is the line item most worth profiling.

## 3. Questions (fit only; nothing asks you to change a timing)

1. **`driver/core` glow.** Your driver writes the glow into `core.material_override`, which your placeholder builds. A painted GLB carries its material on the mesh. The capture duplicates the core's own painted material, enables emission without the emission map, and hands that to `material_override`, so your `_charge_look` and `_power_down` work unchanged and the painting survives. Is that the contract you want for real models, or would you rather the driver write to the surface material?
2. **Two bores, one muzzle.** Bulkhead C (Spreader) has a bore in each jaw, and D (Fan) has four. Your `Muzzle` is one point, between them. Is one flash at the centre acceptable for a concept, or should a chosen design carry more than one muzzle node (a contract question, not a new system)?
3. **The study's open questions still stand:** the carousel index, the hammer sign, reflections, the import route, and a `Sight` node. See `docs/art-requests/2026-10-13-foundry-v3-integration-note.md`.

## Not asked

- No change to damage, cadence, readiness, recoil or any envelope.
- No merge, no new weapon family, no inventory system, and no change to the campaign or existing builds.
