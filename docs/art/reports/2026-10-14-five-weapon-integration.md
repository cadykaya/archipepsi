# The five weapons, ready for your in-game review

*Arty — 2026-10-14*

**Status: INTEGRATION CANDIDATE. Stopped for your in-game review.**
- All five weapons are built and run on Prod's runtime with the layered Glyph effects. Each sits in his five-weapon range against his placeholder, and is captured and measured there.
- Nothing is merged, and nothing touches the campaign. I worked only in the isolated art lane.
- Prod's branch was only ever run, from a read-only checkout of `review/five-weapons-v3` (runtime `ef157061`).
- How to integrate is written down for Prod in `docs/art-requests/2026-10-14-five-weapon-integration-note.md`. It is a note, not a message to his session.

**Your decisions (Skyiah, 2026-10-14):**
- **Bulkhead:** "D — Fan is my choice!" Develop it to the same fidelity, keep its four-barrel arrangement and mechanical personality, and keep both variants. Any gameplay change is a proposal only.
- **Sightline, Switchback, Mass Driver:** the directions are approved for this stage. The Foundry remains the benchmark.
- **The assignment:** prepare the five weapons and the layered Glyph effects for playable integration. Check first-person clearance, animation timing, impacts and bullet marks.
- **Performance:** record triangles, materials, draw calls and texture memory. Investigate the 96 MB, and cut unnecessary memory without losing the detail you like. No global quality cut and no new rendering system.
- **Delivery:** the art package, integration instructions and comparison captures. Coordinate with Prod, merge nothing, and stop for your in-game review.

## What to look at first

1. `IW0_lineup.jpg`: the five together from the player's eye, at rest and on the shot.
2. `IW2_bulkhead_d.jpg`: the Fan, developed.
3. `IW1_<weapon>.jpg`: each weapon against Prod's placeholder. Each sheet shows it at rest, aimed and on the shot, then the hit on metal, stone, wood and gel, then the mark each hit leaves.
4. `<weapon>_clip.gif`: placeholder and art side by side, through a burst.
5. `IW6_memory.jpg` and `IW7_costs.png`: the memory, before and after, and what each weapon costs.
6. `IW8_timing.png`: the art moves when the runtime says, tick for tick.

## 1. Bulkhead D, the Fan

It is developed from your pick through the same pipeline as the other four: modelled in Blender, worn by construction and use, and painted and held in Glyph.

**What was added, and why:**
- Tie collars and a strap bolted across the four bores at the front, so the splay is held rather than floating.
- Four outlet terminals on the distributor that feeds the bores.
- Hinge knuckles on the breech block.
- A shell clip with two spare shells on the block's left side, where the off hand reloads.

**Its history:**
- Heat-straw along each bore, darkest at the mouth, with soot there.
- The distributor line is scorched.
- A crack on the receiver's left flank, welded, ground flat and touched up from the wrong tin.
- A clamp bolt at the bores' roots, chewed by a spanner.
- BH-6 stencilled and stamped.
- Service tallies, tape on the pump grip, and mill scale left on the strap.

**Both variants on one model.** Prod's runtime already drives both: the Breacher works the **Pump**, and the Sweeper shows the cassette **Feed**. No second model was needed. Four effect points, `Bore0` to `Bore3`, sit at the mouths, so the flash comes from each barrel. The gameplay muzzle stays one point.

Gameplay ideas, as proposals only, for you and Prod:
- Breacher: all four bores discharge together.
- Sweeper: alternate pairs, or a wider horizontal spread that matches the fan.

3,200 triangles, one material, 1280² maps at 1,458 texels/m.

## 2. The five in Prod's range

Each model was swapped in for his placeholder in the capturing process's memory, and his runtime drove it. That covers his recoil, readiness, ADS, muzzle, parts and effects, all unchanged. On top of his effects run the authored Glyph layers from Batch 068 (`tools/crossing_capture/glyph_fx_layer.gd`, a reference adapter for Prod).

**First-person clearance.** For each weapon I measured the model's nearest point to the eye against the camera's 0.05 m near plane, at rest, aimed, and over the whole recoil. Nothing clips. At rest each model covers 1.2–1.8% of the screen and leaves the crosshair clear. Aimed, the sights sit over it, as they should.

The closest moments come on the kick. At the top of the Breacher's kick, its rear sits 0.096 m from the eye; the Foundry's comes to 0.142 m. Both rear ends sit further back than Prod's placeholder blocks, which come to 0.152 m and 0.200 m. That is still about twice the near plane, but it is one to feel in play.

**Animation timing.** One burst through the real fire input was logged every tick (`IW8_timing.png`). For every weapon, the art's shots, readiness, return to rest and every moving part match the placeholder's tick for tick:
- **Foundry:** the hammer falls on the shot, the carousel indexes at 317–483 ms, and the hammer re-cocks at 617–683 ms. All of that is before ready at 717 ms, which is Prod's corrected order.
- **Switchback:** the bolt runs back each round.
- **Breacher:** the pump runs at 717–950 ms.
- The Glyph flash starts on the shot's own tick, every shot.

**Impacts and bullet marks.** Every weapon was fired at the four tagged surfaces. The Bulkhead fired from 3 m, where a scattergun is used; from the range line its spread put the pattern on whatever was nearby. A second eye 1.8 m off each target, rendered in the same frame, shows the hit. A close camera shows the mark 1.7 s later, after the metal's hot rim has cooled. The authored marks replace Prod's mark textures and keep his sizes, roll and cap. For the Bulkhead, its one central mark gets the pattern and the stray chips get small pocks, as the Batch 068 handoff asked.

**Renderer.** These captures run on Forward+, the game's own renderer, on software Vulkan. Earlier art-lane captures ran on Compatibility, which does not draw Decals at all, so the bullet marks only show properly from this pass on.

**Two things found in Prod's runtime.** Both are reported in his note and neither is patched:
1. The Mass Driver's impact sparks, light and impact sound never play. The slug lands inside a moment when the scene refuses new children. His placeholder shows the same thing. A one-line fix is proposed.
2. Godot renames a second impact node that arrives while the first is still alive. My adapter's first version matched by name and missed repeat hits. It now goes by his own lists. Nothing needs to change on his side.

The adapter plays the Driver's authored impact from the mark, so you see it in the captures.

## 3. Memory: the 96 MB, investigated

I measured in the game's renderer. Each figure is texture memory added when the weapon loads.

| | Triangles | Materials | Draw calls (placeholder) | 10-13 → now | Maps |
|---|---|---|---|---|---|
| Foundry | 2,748 | 1 | 3 (8) | 16.0 → **12.0 MB** | 1024² |
| Sightline | 4,992 | 1 | 2 (10) | 64.0 → **42.3 MB** | 2048² → 1920² |
| Switchback | 2,520 | 1 | 2 (9) | 16.0 → **12.0 MB** | 1024² |
| Bulkhead D | 2,952 / 3,200 | 1 | 2 / 3 (5 / 6) | new → **18.8 MB** | 1280² |
| Mass Driver | 3,312 | 2 | 3 (11) | 64.0 → **42.3 MB** | 2048² → 1920² |

For the Bulkhead, the first figure is the Breacher and the second the Sweeper, whose Feed is shown. The Driver's second material is the core-glow override Prod's runtime writes.

**Where the 96 MB came from:**
- It was the 2048² maps counted by the Compatibility renderer.
- In the game's renderer the same GLB measures 64 MB, but only because its embedded maps load without mipmaps.
- With mipmaps, the way Prod imports the rest of his art, those maps would be about 85 MB.
- Today's figures include mipmaps.

**What was unnecessary, and is gone.** Every map keeps the density you reviewed, and no texel was resampled below it or compressed:
- **Four bytes a texel for maps that need fewer.** Roughness and metallic are grey, so they are now one byte each. Emission was a full-colour map that is 99.9% black; it is now a one-byte lamp mask, with the colour on the material.
- **The normal map's third channel.** Godot's shader rebuilds it. Loaded as two channels, all five render **pixel-identical** in the range (zero pixels differ), at half the bytes.
- **A second, RGBA copy of every map** inside the GLB. The models now ship geometry-only.
- **Empty atlas.** The islands were packed at 45°, so only about 40% of the map was used. Packed square to the axes, the same density fits in a 1920² map instead of 2048².

`IW6_memory.jpg` sets the 10-13 Sightline and Mass Driver beside the repacked ones, under the same Cycles cameras.

There was no global quality cut and no new rendering system. VRAM compression would save more, but it would change the texels you reviewed, so I left it as a separate decision for you and Prod, to be measured if wanted.

## 4. What I need from you

1. **Your in-game review** of the five with their effects, once Prod has them in a playable build. That build is his to make from the note. Is anything wrong in the hand, in motion, or on the shot?
2. **Bulkhead D** as developed: does it keep the personality you chose it for?
3. **The effect scales** (the impact layers' sizes per weapon) are first fits, chosen from the captures. Which ones are too big or too small in play?

## How it was made (reproducible)

```
# the models: bake, paint, Glyph, lean maps, geometry GLBs, Cycles looks
tools/weapon_model.sh ART bulkhead switchback sightline driver
blender -b --python tools/blender/foundry_geometry.py -- ART/foundry
python3 tools/blender/lean_maps.py ART/foundry foundry
# Prod's range, read-only v3 checkout, Forward+ on software Vulkan
tools/five_integration.sh ART PROD_CHECKOUT CAP
tools/five_integration.sh ART PROD_CHECKOUT CAP before=sightline=<10-13 glb> ...
# the package and its sheets
tools/five_integration_package.sh ART CAP docs/art/review/weapon_integration_2026-10-14 PREV_DEV
```

**Found and fixed on the way:**
- The 10-13 captures ran on Compatibility, which does not draw Decals. Captures now run on Forward+, so the bullet marks show.
- The adapter told a scattergun's stray chips from its centre mark by size, but Prod's chips on stone and gel are 0.135 m. It now tells them apart by position.
- The adapter matched impact nodes by name, which Godot changes on repeat hits. It now goes by Prod's own lists.
- A duplicate declaration once left the adapter unparsed, and a whole batch ran without effects. That batch was discarded and re-run, and the capture now refuses to start unless both scripts parse.
- The Bulkhead's impacts were first fired from the range line, where the spread landed the pattern on neighbours. They are now fired from 3 m, and the sheet labels any surface that differs from the one aimed at.
- A first draft of the Bulkhead's notes said its inner bores ran hotter, and placed the crack beside the breech. Neither matched its wear spec, and both were corrected before anything was drawn from them.
- A first memory projection (85 → 48 MB) assumed three-byte colour on the GPU, but Forward+ pads it to four. The figures above are measured, not projected.
