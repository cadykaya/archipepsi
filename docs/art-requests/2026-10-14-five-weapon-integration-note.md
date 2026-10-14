# The five weapons, ready for integration: instructions for Prod

*Arty — 2026-10-14*

**Status:** an integration candidate, waiting on the owner's in-game review. Nothing here is merged, and nothing asks to be merged until she has played it. On 2026-10-14 the owner chose Bulkhead D (Fan), approved Sightline, Switchback and Mass Driver for this stage, and kept the Foundry as the benchmark. Her words: "prepare the five weapons for playable integration … coordinate with Prod, but don't merge anything into the campaign". This note is the coordination. It is written down here rather than sent to your session.

**Read-only throughout.** Everything was captured from a read-only checkout of `review/five-weapons-v3`. The runtime is at `ef157061`, and the branch head `8002d457` adds only a CLAUDE.md line.
- The art lane's capture script swapped each model in, in the capturing process's memory only.
- It pointed your `_parts` at the art's nodes by the names your rig already uses.
- Your own input actions drove everything.
- Nothing of yours was edited, and none of your timings, recoil, readiness, ADS, muzzles or effects were changed.

Report: `docs/art/reports/2026-10-14-five-weapon-integration.md`.
Package: `docs/art/review/weapon_integration_2026-10-14/`.

## 1. What to take, per weapon

Each weapon is one **geometry GLB** plus five **maps**. The GLB carries no textures (one empty material slot), so no RGBA copy ever loads; the maps are the only copies that reach the GPU.

    models/<weapon>/<weapon>_geo.glb   the model: Body, its moving nodes, Muzzle
    models/<weapon>/lean/albedo.png     RGB   colour
    models/<weapon>/lean/normal.png     RGB   tangent-space normals (OpenGL, +Y)
    models/<weapon>/lean/roughness.png  L     grey
    models/<weapon>/lean/metallic.png   L     grey
    models/<weapon>/lean/emission.png   L     the lamp's intensity mask
    models/<weapon>/lean/lean.json      the material recipe and the lamp colour

How they are made: `tools/weapon_model.sh` builds Sightline, Switchback, Bulkhead and Driver. For the Foundry, `tools/blender/foundry_geometry.py` exports the approved study's geometry and refuses unless its UVs match the approved maps' fingerprint. `tools/blender/lean_maps.py` then repacks the Glyph-painted maps, and it refuses if a single texel would change meaning. These are generated artifacts: regenerate them, never edit them by hand.

### Import (the Godot import dock)

| Map | Compress mode | Mipmaps | Other |
|---|---|---|---|
| albedo, roughness, metallic, emission | **Lossless** | on | — |
| normal | **Lossless** | on | Normal Map: **Enable** |

Lossless keeps RGB8 as RGB8 and L8 as L8. VRAM compression would change the texels the owner reviewed, so it is not used here. If you want VRAM compression later, that is a separate measured decision, taken with her.

### The material (one per weapon; every surface uses it)

    StandardMaterial3D
      texture_filter            = NEAREST_WITH_MIPMAPS   (the art bible)
      albedo_texture            = albedo.png
      normal_enabled            = true;  normal_texture = normal.png
      roughness = 1.0;  roughness_texture = roughness.png
      roughness_texture_channel = GRAYSCALE
      metallic  = 1.0;  metallic_texture  = metallic.png
      metallic_texture_channel  = GRAYSCALE
      emission_enabled          = true;  emission_texture = emission.png
      emission                  = lean.json "emission_colour_srgb"
      emission_operator         = MULTIPLY      <- not the default
      emission_energy_multiplier = 1.0

**`emission_operator` must be MULTIPLY.** With the default ADD, the lamp colour is added to the whole model, which renders solid green. With MULTIPLY, the mask lights only the lamp. `tools/crossing_capture/five_integration.gd`, `_apply_lean()` is the reference.

## 2. What your runtime drives, and what the models give it

The node names are the ones your rig already looks up. Swap the model in under your `models[w]` node and **keep your runtime-owned children** (`Muzzle`, and on the driver `ChargeOrb` and `ChargeLight`). Freeing them breaks `show_charge` and your muzzle anchoring. `_swap()` in the capture script is the reference.

PARTS_TABLE

**The Foundry's carousel adapter.** Your `_index_drum` writes `Basis(RIGHT, PI/2) * Basis(UP, a)` for a Y-up drum, but the art's carousel turns on its own Z. The capture inserts a `CarouselDrive` node between the two, unchanged from the study, and your index then reads correctly. You could do the same, or write the carousel's Z rotation directly. Either is yours to choose.

**The Driver's core glow.** Your driver writes the glow into `core.material_override`. The capture duplicates the core's own lean material, sets emission to your colour (0.85, 0.85, 1.0) with the ADD operator and no map, starts the energy at 0, and hands it to `material_override`. Your `_charge_look` and `_power_down` then work unchanged, and the painting survives. The 2026-10-13 question still stands: is this the contract you want?

**The Bulkhead: one model for both variants.** The Fan has four bores in a splayed row and a pump under them.
- The **Breacher** works the `Pump`, 0.1 m back at 0.72 s, as your runtime already drives it.
- The **Sweeper** shows the cassette `Feed`, which your `set_variant` already shows and hides.
- No second model and no new node types are needed.
- `Bore0`–`Bore3` are four empties under the `Muzzle`, one at each bore's mouth. Your muzzle stays the single gameplay point. The bores are only for the effects, so the flash can come from each barrel. They are optional: with them absent, the flash plays at the `Muzzle`.

Gameplay proposals only, for you and the owner. Nothing in the art depends on them:
- Breacher: all four bores discharge together.
- Sweeper: alternate pairs per shot, or a wider horizontal spread that matches the fan.

## 3. The layered Glyph effects on your events

`tools/crossing_capture/glyph_fx_layer.gd` is a reference adapter. It is yours to adopt, rewrite or ignore. It plays Batch 068 (`assets/fx/weapons/fx.json`, 37 sheets) on the events your v3 runtime already has, and adds none.

| Your event | What the adapter does |
|---|---|
| `RangeWeapons.shots` goes up | Plays the weapon's flash layers at its `Muzzle`, so they ride your kick. Hides your procedural `rig.flame` petals for that shot, since the authored flash replaces them. Your light, smoke, shock ring and tracer stay. |
| `Impact_<kind>` node appears (`RangeImpacts.impact`) | Plays the authored 2D layers for that material and weapon, on top of your 3D sparks, chips, fibres and light. |
| `Mark_<kind>` Decal appears (`RangeImpacts._mark`) | Sets its `texture_albedo` to a random variant of the matching authored mark. Your size, roll, parenting, hot-rim emission and 160 cap are kept. |

Per weapon:

| Weapon | Flash layers | Impact layers | Mark |
|---|---|---|---|
| Foundry | `foundry_flash_flare`, `foundry_flash_core`; `foundry_afterglow` 34 ms later | per material: `impact_metal_flash` + `impact_metal_smoke`, `impact_stone_dust`, the same dust at ½ scale tinted for wood, `impact_flesh_splash` | `decal_metal_hole`, `decal_stone_crater`, `decal_wood_mark`, `decal_flesh_mark` |
| Sightline | `sightline_flash` | the material layers at ½ scale + `sightline_pop` | `sightline_mark` on metal; else per material |
| Switchback | `switchback_flash_a` and `_b`, alternating | the material layers at 0.45 scale | `switchback_pock` |
| Bulkhead | `bulkhead_flash` at each `Bore`, 0.55 scale | `bulkhead_blast` | `bulkhead_mark`; your small stray decals (under 0.12 m) get `switchback_pock` |
| Mass Driver | `massdriver_release` | `massdriver_impact` | `massdriver_mark` |

How the sheets play:
- Each sheet is one row, frame 0 at the left. Frames advance by `durations_ms`.
- Filtering is NEAREST. Blending is `add` or `mix` per sheet.
- `order` is the render priority.
- They are camera-facing quads, unshaded, with no shadow.

The adapter's numbers (`IMPACT_SCALE`, the ½ and 0.55 scales, the wood tint) are first fits for the owner's review, not a contract.

**Your marks are Decals, and Decals are a Forward+ feature.** The game runs Forward+, so they draw. The art lane's earlier captures ran on Compatibility (OpenGL), which does not draw Decals at all. These captures run Forward+ on software Vulkan so the marks show as they will in the game. If you ever ship a Compatibility build, the marks need a quad fallback, as the station's wall layers already use.

## 4. Measured in your range

COSTS_TABLE

TIMING_TABLE

## 5. Questions (fit only; nothing asks you to change a timing)

1. **The core-glow contract** (§2, still open from 10-13).
2. **The Bulkhead's `Bore` empties.** Are four effect-only points under the `Muzzle` acceptable? The gameplay muzzle stays one point.
3. **The import settings** (§1). Lossless, with the normal map flagged. Does that match how you import the other station art?
4. **The adapter** (§3). Will you adopt it, rewrite it inside your effects code, or want the sheets wired a different way?

## Not asked

- No change to damage, cadence, readiness, recoil, ADS or any envelope.
- No merge into the campaign. No new weapon family, inventory system or rendering system.
- No global change to texture quality: every map keeps the density the owner reviewed.
