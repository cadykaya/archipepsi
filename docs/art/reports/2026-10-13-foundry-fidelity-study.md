# The Foundry fidelity study: one first-person Foundry, in the real renderer

*Arty — 2026-10-13*

**Status: NON-PRODUCTION STUDY, for your review. Stop for review.**
- Not five weapons and not a final model.
- No registry entry, no budget category added, and the art bible is unchanged.
- The campaign, existing builds and Batch 068 are untouched.
- Prod's branch was only ever run, from a read-only checkout.
- The oversized hammer stays a candidate, not an approved silhouette.

**Your direction (Skyiah, 2026-10-13):**
- Keep the hybrid.
- Tone the designs down without making them boring.
- Keep the detail and make the textures carry much more.
- Make it look worn, used and imperfectly assembled.
- Use Glyph and the existing material workflow.
- Make one Foundry study at the provisional 2,500–4,000 triangles, shown in the real renderer:
  - at rest;
  - firing and recovering in real time;
  - close up.
- Keep the firing behaviour and the 0.72 s cadence.
- Make the visual cues agree with Prod's runtime.

## What to look at first

| | |
|---|---|
| [FS1: the gameplay view](../review/foundry_study_2026-10-13/FS1_gameplay_view.png) | Prod's placeholder and the study, same frame, same light; the study in grey |
| [The clip, real time](../review/foundry_study_2026-10-13/foundry_clip_20fps.gif) | three shots in rhythm, 20 fps. The 60 fps original with sound is `foundry_clip.avi` in the delivery zip. |
| [FS2: one shot over the runtime's states](../review/foundry_study_2026-10-13/FS2_firing_timeline.png) | frame by frame, with the logged hammer, carousel, recoil and cooldown |
| [FS3: close up](../review/foundry_study_2026-10-13/FS3_close_up.png) | six close looks inside the running game, each captioned with what the surface records |
| [FS4: the material maps](../review/foundry_study_2026-10-13/FS4_material_maps.png) | the six maps Glyph holds and exported |

**How these were taken.** Everything is a capture from Prod's own game (`review/five-weapons-v2`, `257fb75d`):
- loaded from `main.tscn` with `--five-weapons`;
- Prod's rig, recoil, lights, muzzle flash and sounds;
- the engine's hits.

Only the Foundry's meshes were swapped, and only in the capturing process's memory.

---

## 1. Toned down: the gun

Compared with the concept sheets, there's less novelty machinery and more of a heavy hand cannon someone built and kept working:

- **One heavy octagonal barrel** with a crown, and an open, dark bore.
- **A recoil buffer** under the barrel. **A machined clamp** ties the two together.
- **A six-chamber carousel**: the part Prod's runtime turns 60° per shot. Each chamber holds a plain steel slug blank in a ceramic cup.
- **The breech**, wrapped by the **Epsilon converter collar**: black, precise, almost unworn. It heats the next blank while it waits.
- **The Echo core**: a cartridge pushed radially into the collar's flank. It's held by **a station strap and a wing nut**, because the socket's own latch is long gone.
- **A welded station frame**:
  - rounded at the back;
  - a top strap with a rear-sight notch;
  - a front web under the breech;
  - **a heavy hammer in proportion**, pivoting forward, its head toward the eye, with a knurled thumb spur.
- **A tape-wrapped grip** and a trigger guard, plus an armoured lead from the trigger switch to the collar.

**Owners, kept as a design hypothesis (not new lore):**
- station: frame, barrel, carousel, hammer;
- Epsilon: the collar that turns the core's output into heat and a firing pulse;
- Echo core: the swappable source.

The only green on the gun is one small lamp on the collar, and it means **powered**.

**Numbers:**

| | |
|---|---|
| Triangles | **2,748**, inside your provisional 2,500–4,000 (asserted locally by the builder; no budget category added) |
| Textures | one 1024² atlas, measured at **~1,150 texels/m** (§5) |
| Shading | flat, as the bible asks, with one-segment chamfers on the edges that catch light (the "selective rounded edges") |
| Placement | Prod's rig, untouched. The muzzle sits exactly on Prod's marker (0, 0.03, −0.47). |

## 2. The mechanism agrees with the runtime

The gun makes no motion of its own. Every visible motion is one Prod's runtime already makes:

| Prod's runtime | When | The study shows |
|---|---|---|
| the shot (`fire`) | 0 s | the **hammer falls**. Its head lands on the battered striker and the shot leaves at once (the response is immediate). |
| `foundry/cylinder` indexes | 0.38–0.58 s | the **carousel turns 60°**: the next blank into the collar to heat |
| the hammer is drawn back and cocked | 0.56–0.66 s | the hammer **rises and cocks** (the click) |
| ready (cooldown 0.72 s) | 0.733 s on the 60 Hz tick | — |

**Readiness and settling are kept apart, as you asked.** Measured in the captured run:

| Event | Source | Time |
|---|---|---|
| Gun home | Prod's clock | 0.583 s |
| Aim home | Prod's clock | 0.65 s |
| Hammer cocked | Prod's clock | 0.65 s |
| Ready | Prod's clock | 0.733 s |
| Gun's pitch home | the study's log | 0.57 s |
| Gun's travel within 1 mm | the study's log | 0.70 s |

So:
- **Cocked is the ready cue.** It leads readiness by 80 ms, inside Prod's 0.15 s press buffer: a click on the cock fires the instant the gun may.
- **The gun has visibly settled just before the weapon is ready**, so there's no dead wait and no early snap.

The three clip shots landed 44 frames apart: your 0.72 s cadence, on the frame.

One fit detail needs Prod's word: how the carousel's index is applied to a real model. See the handoff (`docs/art-requests/2026-10-13-foundry-study-prod-questions.md`).

## 3. The textures: what the surfaces record

The rule this pass was written against is yours: *the model explains the construction; the textures explain the materials, use, repairs and history.*

So wear is placed by **construction and use**, never sprinkled:
- Noise only breaks up the edge of a mask something real placed.
- Every pattern is kept coarser than two texels, so nothing aliases into "sugar".

| What you asked for | Where it is on the gun, and why there |
|---|---|
| Worn paint exposing metal | Chips through station grey to red-oxide primer to steel. **Exposure decides where:** the bottom edges it's set down on and the two ends (muzzle, frame back) chip far more than the sheltered top. Where hands hold it, the paint is **polished thin**, not chipped. |
| Mismatched metals and panels | The frame's left access cover is gone. **A cut plate in another area's primer** (the rusted-industrial ramp) replaces it, brushed round in station grey by someone who gave up halfway. The gusset at the top strap is **touched up from a different tin**. |
| Rubbed edges and contact | The hammer's knurled spur is polished by thumbs. The striker is battered bright where the hammer lands. A **turn line** runs round the carousel where the stop drags. The core's cap is handled smooth. The grip tape is darkened and glossed under the palm. |
| Dirt and grease in recesses | Grime follows occlusion with soft gradients. **Oil** sits at the hammer pin, the carousel axle and the buffer's slide, with **a run** down the left cheek from the pin. Dust settles on up-facing recesses. Rust only where water sits: the patch's lower edge, the floor of the carousel window, the buffer cap. |
| Heat discoloration and residue | Temper colours and burnt paint round the breech. **Soot at the crown** and **flame-cutting soot from the gap between carousel and breech** (as on any revolver). The ceramic spacers are crazed and sooted. The core strap is heat-tinted. |
| Scratched coatings | A few long scratches in the places use puts them: the frame side where it's set down, the barrel's underside where it's drawn. |
| Faded markings, maintenance evidence | "HOT" on the top strap and the gun's number "F3", faded and thinned where handled. A **stamped serial and proof mark** (dents, not paint) on the barrel. **Grease-pencil service tallies** and a tick on the patch. A **paint-pen torque stripe** across checked bolts. **A slipped wrench's arc** beside the clamp's pinch bolt. |
| Welded and repaired unprofessionally | **Raised weld beads**: geometry, rippled, painted over and chipped on the ridges. **A cracked front web**, welded along its jagged line, ground roughly, half painted over, its heat halo left. **Mismatched fasteners**: zinc, black oxide and one rusty. The core's **improvised strap**. The collar's **slightly crooked hold-down bracket**, its bolts biting marks into the Epsilon finish. |
| Sophisticated parts contrast | The Epsilon collar is dense black. It carries a fine machined texture you only see close up, crisp edges and almost no wear: it outclasses everything around it. The Echo core is clean and glossy. The battered station work is around them, not on them. |

**What I took out after looking at it in the engine (iterations, not hidden):**
- Uniform bright lines on every edge. The edge mask had covered whole chamfer strips.
- "Camouflage" blotches of dirt and rust.
- Patterns finer than a texel that aliased into speckle.
- A service note set in a font, which read as a decal. It's now hand-drawn tallies.

## 4. Glyph and the material workflow

The painter (`tools/blender/foundry_paint.py`) paints from bakes of the model:
- position;
- normal;
- occlusion;
- edges;
- part IDs.

**Glyph holds the result** (`tools/glyphui/author_foundry_study_maps.py`):
- **One asset, one variant per map**, each declaring its role (`representation`): world texture, height, roughness, metallic, emission, normal.
- **The albedo on a 256-colour palette**: median cut, no dither, a GoldSrc skin. It's written in patches of at most 90 symbols.
- **The normal map is Glyph's own.** `x-glyph.normal_from_height` derives it from the painted height (Sobel, OpenGL-handed, strength 1.0 on a height field written at 4× gain so it uses ~165 levels, not 50).
- **`x-glyph.check_material` passes clean** before anything is exported: sizes agree, single-value maps carry no colour, normals are unit length.
- **Every map leaves through Glyph's export.** The exports were checked against what was painted: the grey maps are identical, and the albedo differs only by its palette (mean 0.6 levels).

**Two things the bible says that this study departs from, deliberately and only here:**
1. **§5, "Albedo only."** You asked for roughness and normal detail where supported. The study uses them, and the bible is unchanged. If you want to keep them, that's a bible change for you to make, not me.
2. **The texel density.** See §5 below.

**A renderer fact that shaped the textures.** Prod's range renders through the Compatibility renderer with **nothing for a metal to reflect**, so a fully metallic surface goes nearly black. Prod's own steel placeholder does (FS1). So the steel is carried in the **albedo**, with a modest metallic share for sheen, as a GoldSrc skin did. Whether a reflection source is coming is a question for Prod.

## 5. The budget numbers this study asks you to judge

| | This study | The art bible today |
|---|---|---|
| Triangles | 2,748 | no viewmodel category (`hero` 1,200) |
| Texture | one 1024² atlas, ~1,150 texels/m | viewmodel tier 256 texels/m, *deferred, not built*; 128² ceiling for Batch 001 |
| Maps | albedo + normal + roughness + metallic + emission | albedo only |
| Filtering | nearest, with mipmaps | nearest, with mipmaps |

**Why ~1,150 texels/m, not 256 or 512.** At 512 texels/m the frame's whole side face is about 50 texels square. That's too few for:
- a weld ripple;
- a chip with a primer ring;
- a stamped serial;
- a tally mark.

At ~1,150 a texel is about 1.3 screen pixels at the rig's distance at 1080p. In play the gun stays crisp and era-looking, and up close the texels show as texels (FS3). A lower density is a real option if you prefer a chunkier read. That's exactly the calibration this study exists for.

## 6. Readable in play

FS1 and the clip:
- At rest, the gun sits where Prod's placeholder did, with **the centre and the targets clear**.
- In grey, the silhouette reads.
- At full heave (Prod's 0.29 m and 30°), the gun rises toward the eye but stays in the right half of the screen, clear of the centre.
- The close detail reads as worn dark steel with one pale patch and a small green lamp. It's there when you look and quiet when you don't.

## 7. The rest of the family: recorded, not built

Your notes, written down here and in the frontier so they aren't lost:

| Weapon | Your note |
|---|---|
| **Sightline** | Substantial and punchy, **slightly faster than Foundry**. Not the low-kick 0.4 s interpretation from pass 2. |
| **Switchback** | **Preserve the firing behaviour you already liked.** |
| **Bulkhead** | **Undecided:** quick scattergun or heavy shotgun. |
| **Mass Driver** | **Less recoil, greater damage, Sightline-class range.** |

**Green** communicates **active power**, not decorative Epsilon branding everywhere. On this study it's one lamp.

## 8. Limits, plainly

- **A study, not a model for shipping.**
  - No LODs and no collision.
  - It's loaded at runtime through `GLTFDocument` rather than imported. The capture generates the mipmaps a runtime-read image lacks.
  - Hands: the range draws none, so the grip is held by no one, as in Prod's placeholder.
- **The Echo core's material is a placeholder.** It's a dense, glossy, banded dark stone-glass, neutral on purpose. The source identity package decides it.
- **The paint is procedural, but placed.** The masks come from the model; the places come from the gun's construction and use, written in the painter as named zones. Moving the gun's parts means moving those zones too.
- **The real-time clip is 60 fps from Godot's movie maker**, at the fixed physics rate, sound included. The GIF is that clip at 20 fps, for convenience.
- **Not tested as play.** This is a look at fidelity, not a feel test. The feel is Prod's, and it is unchanged.

## 9. What I need from you

1. **The fidelity bar.** Is this the right level of construction detail, and of texture richness, for the family? More, less, or different in kind?
2. **The tone.** Imaginative, worn, tangible: closer to what you meant, or still too toy-like anywhere? Point at it.
3. **The hammer.** Proportionate now, pivoting forward with its head toward the eye. Keep it, change it, or try something other than a hammer for the Foundry's readiness cue?
4. **The numbers in §5:** the triangle range, ~1,150 texels/m, and normal and roughness maps. These are bible changes, for you (and Prod, for the renderer).
5. **After this,** the next step I'd suggest is the same treatment for one more family member, Sightline per your note, so the bar is proven on a second, different gun before the other three.

## Rebuilding it

```
tools/foundry_study.sh OUT [PROD_CHECKOUT]
```

1. Model, unwrap, bakes: `tools/blender/build_foundry_study.py -- bake`.
2. Paint: `tools/blender/foundry_paint.py`.
3. Glyph: `tools/glyphui/author_foundry_study_maps.py` (needs `GLYPH_ROOT`).
4. GLB: `build_foundry_study.py -- assemble`.
5. With a read-only checkout of `review/five-weapons-v2`, the capture: `tools/crossing_capture/foundry_study.gd`, run as stills, placeholder and clip.
6. Sheets: `tools/crossing_capture/foundry_study_sheets.py`.

The study's GLB, its json and Glyph's maps are under `docs/art/review/foundry_study_2026-10-13/model/`, for Prod to try. They're not for shipping.

**STOP for review.** No watchers, subscriptions or merges.
