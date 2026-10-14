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
    models/<weapon>/lean/normal.png     RGB   tangent-space normals (OpenGL, +Y); load as RG8
    models/<weapon>/lean/roughness.png  L     grey
    models/<weapon>/lean/metallic.png   L     grey
    models/<weapon>/lean/emission.png   L     the lamp's intensity mask
    models/<weapon>/lean/lean.json      the material recipe and the lamp colour

How they are made: `tools/weapon_model.sh` builds Sightline, Switchback, Bulkhead and Driver. For the Foundry, `tools/blender/foundry_geometry.py` exports the approved study's geometry and refuses unless its UVs match the approved maps' fingerprint. `tools/blender/lean_maps.py` then repacks the Glyph-painted maps, and it refuses if a single texel would change meaning. These are generated artifacts: regenerate them, never edit them by hand.

### Import (the Godot import dock)

All five maps: **Compress Mode: Lossless, Mipmaps: on**, which is how your project already imports 239 of its 241 PNGs. Lossless keeps a grey PNG as L8 (one byte a texel). VRAM compression would change the texels the owner reviewed, so it is not used here. If you want it later, that is a separate measured decision, taken with her.

**Load the normal map as RG8.** Godot's shader reads a normal map's X and Y and rebuilds Z. In your range, all five weapons render pixel-identical with the normal as RG8 and as RGB8: zero pixels differ in the rest frames. RG8 takes 2 bytes a texel. An RGB8 texture is padded to RGBA8 on the GPU, which takes 4. Godot's Lossless import keeps a normal map RGB8 whether or not "Normal Map" is set and whichever channel pack is chosen; both were tested. So the conversion happens at load:

    var img := (load("res://…/normal.png") as Texture2D).get_image()
    img.convert(Image.FORMAT_RG8)
    if not img.has_mipmaps():
        img.generate_mipmaps()
    material.normal_texture = ImageTexture.create_from_image(img)

`_tex(file, rg)` in `tools/crossing_capture/five_integration.gd` is the reference. That route saves 18% of each weapon's texture memory (see §4).

### The material (one per weapon; every surface uses it)

    StandardMaterial3D
      texture_filter            = NEAREST_WITH_MIPMAPS   (the art bible)
      albedo_texture            = albedo.png
      normal_enabled            = true;  normal_texture = normal.png as RG8
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

| Your part | Model node | Pivot (model space, m) | Your motion | In your range |
|---|---|---|---|---|
| `foundry/hammer` | `Hammer` | (0, 0.052, −0.022), turns on X | cocked −38°, falls to 0 on the shot, re-cocks before ready | falls on the shot's tick, re-cocks 617–683 ms, ready at 717 ms: identical to your placeholder |
| `foundry/cylinder` | `Carousel` via `CarouselDrive` | (0, 0.006, −0.061), turns on Z, 60° a chamber | your `_index_drum` | indexes 317–483 ms: identical |
| `sightline/handle` | `Handle` | (0, 0.021, −0.080) | `_stroke` 0.022 m back | see the timing sheet |
| `switchback/bolt` | `Bolt` | (−0.032, 0.021, −0.112) | 0.035 m back each round | 0–33 ms each round, 13 rounds: identical |
| `bulkhead/pump` | `Pump` | (0, −0.050, −0.303) | 0.1 m back at 0.72 s (Breacher) | 717–950 ms: identical |
| `bulkhead/feed` | `Feed` | (0, −0.052, −0.120) | shown for the Sweeper only | hidden on the Breacher, shown on the Sweeper |
| `driver/coils` | `Coils` (the rotor) | (0, 0, −0.150) | `rotation.z` spins with the charge | see the timing sheet |
| `driver/core` | `Core` (the accumulator) | (0, −0.062, −0.055) | glow through `material_override` | see below |

Muzzles sit at your `MUZZLES[w].at`: Foundry (0, 0.03, −0.47), Sightline (0, 0.025, −0.74), Switchback (0, 0.02, −0.42), Bulkhead (0, 0.02, −0.50), Mass Driver (0, 0, −0.62).

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
| an impact root joins `impacts.effects` (`RangeImpacts.impact`) | Plays the authored 2D layers for that material and weapon, on top of your 3D sparks, chips, fibres and light. |
| a Decal joins `impacts.marks` (`RangeImpacts._mark`) | Sets its `texture_albedo` to a random variant of the matching authored mark. Your size, roll, parenting, hot-rim emission and 160 cap are kept. |

Per weapon:

| Weapon | Flash layers | Impact layers | Mark |
|---|---|---|---|
| Foundry | `foundry_flash_flare`, `foundry_flash_core`; `foundry_afterglow` 34 ms later | per material: `impact_metal_flash` + `impact_metal_smoke`, `impact_stone_dust`, the same dust at ½ scale tinted for wood, `impact_flesh_splash` | `decal_metal_hole`, `decal_stone_crater`, `decal_wood_mark`, `decal_flesh_mark` |
| Sightline | `sightline_flash` | the material layers at ½ scale + `sightline_pop` | `sightline_mark` on metal; else per material |
| Switchback | `switchback_flash_a` and `_b`, alternating | the material layers at 0.45 scale | `switchback_pock` |
| Bulkhead | `bulkhead_flash` at each `Bore`, 0.55 scale | `bulkhead_blast`, once a shot (your `_scatter` makes one impact at the pattern's centre) | `bulkhead_mark` on the centre mark; your `chip()` strays get `switchback_pock` |
| Mass Driver | `massdriver_release` | `massdriver_impact` (from the mark, while §5 stands) | `massdriver_mark` |

How the sheets play:
- Each sheet is one row, frame 0 at the left. Frames advance by `durations_ms`.
- Filtering is NEAREST. Blending is `add` or `mix` per sheet.
- `order` is the render priority.
- They are camera-facing quads, unshaded, with no shadow.

The adapter's numbers (`IMPACT_SCALE`, the ½ and 0.55 scales, the wood tint) are first fits for the owner's review, not a contract.

**Your marks are Decals, and Decals are a Forward+ feature.** The game runs Forward+, so they draw. The art lane's earlier captures ran on Compatibility (OpenGL), which does not draw Decals at all. These captures run Forward+ on software Vulkan so the marks show as they will in the game. If you ever ship a Compatibility build, the marks need a quad fallback, as the station's wall layers already use.

## 4. Measured in your range

Measured in your range, Forward+ on software Vulkan. The counters are read with the weapon in view. Texture memory is the counter's rise when the model loads. PL = your placeholder.

| Weapon | Triangles | Materials | Draw calls (PL) | Texture memory | Maps | Texels/m | Nearest point: rest / ADS / over the recoil |
|---|---|---|---|---|---|---|---|
| Foundry | 2,748 | 1 | 3 (8) | 12.0 MB | 1024² | 1,154 | 0.464 / – / 0.142 m |
| Sightline | 4,992 | 1 | 2 (10) | 42.3 MB | 1920² | 1,967 | 0.453 / 0.208 / 0.335 m |
| Switchback | 2,520 | 1 | 2 (9) | 12.0 MB | 1024² | 1,402 | 0.473 / 0.231 / 0.447 m |
| Bulkhead, Breacher | 2,952 | 1 | 2 (5) | 18.8 MB | 1280² | 1,458 | 0.460 / – / 0.096 m |
| Bulkhead, Sweeper | 3,200 | 1 | 3 (6) | 18.8 MB | 1280² | 1,458 | 0.460 / – / 0.252 m |
| Mass Driver | 3,312 | 2 | 3 (11) | 42.3 MB | 1920² | 1,951 | 0.447 / 0.284 / 0.302 m |

Notes on the table:
- The Driver's second material is the core-glow override.
- Texture memory is with the normal map loaded as RG8. Imported as RGB8, it would be 51.6 / 23.0 / 14.7 MB.
- The 10-13 development GLBs measured 64.0 MB (Sightline, Mass Driver) and 16.0 MB (Foundry, Switchback) in the same run. That is without mipmaps, which a runtime-loaded GLB lacks; with them, about 85 and 21 MB.
- Every nearest point is clear of the 0.05 m near plane.
- The art comes nearer than your placeholder on two weapons, both on the kick. Their rear ends sit further back than your blocks:
  - the Foundry: 0.142 m, against 0.200 m for the placeholder;
  - the Breacher: 0.096 m, against 0.152 m.
  - Nothing clips. It is for the owner to judge in play.

**Timing.** One burst per weapon, logged every tick, through `fire_pulse`. The art's shots, readiness, return to rest and every part's motion match your placeholder's tick for tick on all six configurations. Times are in ms from the first shot:

| Weapon | Shots | Ready | At rest | Parts |
|---|---|---|---|---|
| Foundry | 0, 1167 | 717, 1883 | 483, 1683 | hammer falls at 0, re-cocks 617–683; carousel 317–483 |
| Sightline | 0, 1167 | 483, 1650 | 350, 1517 | handle 83–183 |
| Switchback | 13, 150–167 apart | 133, 300 … | 67, 233 … | bolt 0–33 each round |
| Bulkhead, Breacher | 0, 1333 | 983, 2317 | 683, 2217 | pump 717–950; feed hidden |
| Bulkhead, Sweeper | 0, 1333 | 483, 1817 | 417, 1750 | feed shown, still; pump still |
| Mass Driver | release at 0 | 133 | 600 | coils spin through the 1.65 s charge, stop at the release; core glow peaks at energy 5.0 through the override |

The Glyph flash starts on the shot's own tick, every shot. With the adapter reading your lists, every impact and every mark gets its layer: 13 rounds of the Switchback give 13 impacts and 13 marks. From 3 m, each Bulkhead shot gives one blast and four marks (the centre and three chips).

## 5. Found in your runtime (reported, not patched)

**The Mass Driver's impact effects never play.**
- What happens: `range_weapons.gd` connects `slug.tree_exiting` to `_slug_end()`, and `_slug_end()` calls `impacts.impact()`. That runs while Main is removing the slug, and Main refuses new children then. Godot logs: `Parent node is busy setting up children, add_child() failed`.
- What is lost: the impact root never enters the tree, so your sparks, light, smoke and shock never show. `play_at` fails too ("Playback can only happen when a node is inside the scene tree"), so the impact sound is lost as well.
- What survives: the mark, because it is parented to the target body.
- Where it shows: every Driver hit in the captures, on your placeholder as much as on the art (`IW1_driver.jpg`, the hit row).
- A one-line fix, for you to judge: `slug.tree_exiting.connect(_slug_end.bind(record), CONNECT_DEFERRED)`. `_slug_end` reads only the record, so it works the same one frame later. Alternatively, defer the `add_child` inside `impact()`.
- The art lane's adapter does not depend on it. It plays the authored Driver impact from the mark event, at the same point, and logs that it did so.

**Renamed nodes.** When a second `Impact_metal` is added while the first is still alive, Godot names it `@Node3D@N`, and the same happens to a second `Mark_metal` on the same body. Anything that recognises your effects by name therefore misses repeat hits. The adapter's first version did, and logged 4 impacts for a 13-round burst. It now goes by your own lists (`impacts.effects`, `impacts.marks`) and the `mark_kind` meta. Nothing to change on your side; it is noted in case your own checks look nodes up by name.

## 6. Questions (fit only; nothing asks you to change a timing)

1. **The core-glow contract** (§2, still open from 10-13).
2. **The Bulkhead's `Bore` empties.** Are four effect-only points under the `Muzzle` acceptable? The gameplay muzzle stays one point.
3. **The import settings** (§1). Lossless, with the normal map flagged. Does that match how you import the other station art?
4. **The adapter** (§3). Will you adopt it, rewrite it inside your effects code, or want the sheets wired a different way?

## Not asked

- No change to damage, cadence, readiness, recoil, ADS or any envelope.
- No merge into the campaign. No new weapon family, inventory system or rendering system.
- No global change to texture quality: every map keeps the density the owner reviewed.
