# ART BIBLE — Archipepsi

**Status: proposed. Nothing here is approved.** Every rule below is written
to be *failable*, and Style Lock Batch 001 exists to test whether these are
the right rules before any of them are used to make fifty assets.

> **DEVELOPERS AUTHOR THE ALPHABET.
> GODOT ENFORCES THE GRAMMAR.
> EPSILON WRITES SENTENCES.**

Every rule in this document answers one question:

> **What visible failure does this prevent?**

If a rule cannot name its failure, it is decoration and does not belong
here. Several rules were deleted while writing this for exactly that reason.

---

## 0. The v0.9 authored-content clarification

`docs/design-packet-v0.8/DESIGN.md` §3.4 ends with the line *"No
AI-generated art, models, shaders or audio."* and §20 adds *"Blender is
installed on the development machine (4.5.9). **Do not use it.**"*

The owner has clarified both, and the clarification is recorded in full at
[`AUTHORED_CONTENT_v0.9.md`](AUTHORED_CONTENT_v0.9.md). In short:

- The prohibition is on **runtime Epsilon-generated assets**, and it is
  absolute and unchanged.
- **Development-time agent-authored assets are permitted**, and become
  ordinary authored game content once they are buildable from source in
  the development toolchain, inspected, **reviewed by the owner**,
  committed, addressed by a stable asset ID, and shipped as known content.
- §20's "do not use Blender" is therefore superseded for the art lane. The
  v0.8 packet is not edited: it is frozen, it said what it said, and the
  clarification lives beside it rather than being backdated into it.

Epsilon may select and combine approved shipped assets. Epsilon may never
manufacture a mesh, texture, shader, sound, arbitrary resource path or
executable asset-generation instruction during play. Nothing in this
document weakens that, and a change that moved any of it into Epsilon's
half would be out of contract.

---

## 1z. THE LOCKED DNA — Style Lock PASSED

Everything in this section is the owner's, recorded from the Batch 002-R
verdict. **It is not reopened by this lane.** Where anything else in this
document appears to disagree with it, this section wins and the other
passage is the one that needs fixing.

### Human facility

Cold grey / white / pale-blue abandoned research facility. Industrial
corridors, pipes, vents, rails, catwalks. Old institutional machinery. Cold
overall lighting, with localized warm-yellow utility pools. **No global
sepia wash.**

### Epsilon

Invasive alien technology. Hostile, uncanny shape language. Neon-green
internal and emissive identity. **Asymmetry.** Machinery that penetrates,
replaces and commandeers human infrastructure.

### Check

Pedestal / beacon **A**. A distinct Archipelago identity, and **not**
Epsilon green.

### Portal

Human architectural hardware plus an alien wound / intrusion. Variants may
get stranger; the split itself does not move.

### Grapple

Both anchors. A soffit overhead; B jib directional / wall-side.

### Enemies

The current family and silhouette language. The expanded role set is
preserved. **Flying enemies are a core combat category** — the grapple makes
vertical combat useful, so flyers are not a novelty tier.

### The Epsilon installation

Preserve the giant human-facing display, the operator desk and control
surface, the wall-scale racks and housings, the cold old research-facility
construction, the asymmetric intrusion, the neon-green alien structures, the
alien components physically intersecting and replacing human hardware, and
the visible contrast between the original machine and the takeover.

> **Do not symmetrize or clean up the alien side.** An intrusion that has
> been tidied is a design; the point is that it is not one.

The display is Epsilon's **presentation surface** — the place the player
looks when interacting with it, while the physical mass is what explains who
owns the machine. Its dormant state (dark glass, dead terminal, a damaged
human interface) is what ships today; the active and generating states are
deferred with the rest of the animation question.

---

## 1a. THE CONTRAST — settled at the Batch 001 review

This is the axis the game leans on, and it governs every decision below it.

| | **Human / facility** | **Epsilon** |
| --- | --- | --- |
| What it is | An abandoned research facility | A foreign intelligence inhabiting it |
| Materials | Cold grey concrete, white and pale-blue paint | Dense near-black plating at a manufacture the building does not use |
| Light | Yellow utility lighting, from fixtures, onto surfaces | Neon green, from **inside**, out through seams |
| Construction | Corridors, vents, pipes, rails, catwalks. Grounded, industrial, human | Uncanny, asymmetric, invasive, glowing, humming |
| Age | Old, institutional, mechanical, abandoned | Active, alive, wrong |

> **Epsilon is not part of the building style. Epsilon is a foreign
> intelligence inhabiting, infecting and embedding itself into old
> infrastructure.**

Three rules follow, and they are failable:

1. **Epsilon takes nothing from the theme.** `propkit.alien_shell` uses no
   theme ramp at all — it is built from the shared `grime` family with
   `identity` green forced through its seams. Epsilon therefore looks the
   same in all six themes, which is the point: a foreign intelligence that
   colour-matched the building would not be foreign.
2. **Epsilon is embedded, never placed.** Any Epsilon-owned object carries
   visible *facility host* material — ordinary bolted grey plate — that it
   has burst out of or grown through. Without something to intrude into,
   an intrusion is just a dark machine.
3. **Green means Epsilon. Nothing else may be green.** `identity` is neon
   `#57ff1f`, leaning yellow so it can never be confused with `void_glitch`
   cyan or `signal` teal; `palette.verify()` enforces 45° of hue separation
   between those three.

### The green / orange split

> **Green says whose this is. Orange says what is about to happen.**

An enemy's optic is `identity` green — its family membership card, marking it
as Epsilon's ecosystem rather than the facility's machinery. `hazard` orange
is **reserved for telegraphs**, so a windup is the only orange an enemy ever
shows. Orange trim on an enemy body spends the one colour that has to mean
"an attack is coming" on decoration.

---

## 1. The target, stated so it can be failed

> **A local AI was handed a 1998 level editor and told to make a game.**

Late-1990s PC FPS. GoldSrc / Quake-era brushwork. Chunky low-poly forms
assembled from prisms, wedges and ramps. Strong silhouettes. Crude but
intentional industrial construction — vents, catwalks, pipes, tunnels,
concrete chambers. Deliberately simple doors, buttons and consoles.
Low-resolution authored texture work with visible grime and material
history. Simple graphic lighting. Readable gameplay surfaces. Uncanny
AI-composed spaces made from a coherent human-authored vocabulary.

### What it is NOT, with the failure each avoids

| Not this | Because |
| --- | --- |
| Minecraft / voxel / a visible universal cube grid | v0.3 pinned 16×16 textures to make life easy for a hypothetical local model. Epsilon never paints a texture — our code does — so the constraint bought nothing and cost the look. A cube grid also destroys the brush read, which is the whole era. |
| Modern photoreal PBR | Normal, roughness and AO maps are the physical cues the flat 1998 look does not have. A normal-mapped brick wall is unmistakably a 2010s wall at any albedo resolution. |
| Smooth high-poly sci-fi | The faceted read depends on visible facets. Triangles spent rounding a form off are triangles spent destroying the target. |
| Generic asset-pack realism | Every surface equally detailed is every surface equally uninteresting. Detail is a way of pointing. |
| Greeble spam | An added form that neither breaks the silhouette nor catches light differently is noise with a triangle cost. |
| Procedural noise pretending to be detail | See §6. This is the single most likely way this project's art fails, and it has already failed this way twice during Batch 001. |
| "Retro" as *just* lower resolution | A downsampled smooth image is an anti-aliased image at low resolution, which reads as a compression artefact. Structure, wear, seams and edge treatment are painted deliberately, in whole texels. |

---

## 2. The numbers, and where they came from

**Every number below is derived, none is inherited.** `mario-3`'s triangle
ceilings, texture sizes and densities answer questions Archipepsi does not
ask, and none of them were copied. Run the derivation and it prints the
arithmetic and the failure each constraint prevents:

```sh
python3 tools/blender/derive_budgets.py
```

The game dimensions it stands on are read **live** from the engineering
branch (`tools/blender/engine_truth.py` imports `schemas/constants.py` and
re-checks every GDScript value it reads), so these move when the game moves.

### Texel density

| Tier | texels/m | Band | Why this number |
| --- | --- | --- | --- |
| Architecture | **32** | 24–40 | Quake mapped 1 texel to 1 unit at 56 units per 1.78 m (31.5/m); Half-Life at 72 units per 1.83 m (39.3/m). 32 sits inside that band and makes a 128px map cover **exactly 4.0 m**, which is also the module size. |
| Prop / interactable | **64** | 48–80 | A 1 m crate face at 32/m gets 32 texels, which cannot hold a lid seam *and* a stencil *and* wear. It is also era-correct: a 1998 model's skin was sharper than the brush behind it. |
| Hero (Check, Epsilon, portal) | **96** | 80–128 | Read from 1 m *and* from 40 m, and the most-repeated images in the game. |
| First-person viewmodel | 256 | 192–320 | **DEFERRED, not built.** A viewmodel sits ~0.4 m from the eye. 256 exceeds `TEXTURE_SIZE_MAX` (128), which bounds the *runtime* generator — imported assets are not bound by it, but the asset-registry contract does not exist yet. See `ART_FRONTIER.md`. |

**Failure at the top of the band:** above ~40 texels/m a wall stops reading
as 1998 and starts reading as a low-res modern texture — the difference
between "deliberately coarse" and "the artist ran out of budget".
**Failure at the bottom:** below ~24 texels/m the panel lines and grime that
carry all the detail fall under one texel and the surface goes flat and
Minecraft-ish.

**Measured, never estimated.** `common.uv_texel_density()` reads the real
unwrap against the real world area and `assert_texel_density()` fails the
build outside the band. mario-3's estimate here was wrong by a factor of
six, which made every painted cluster smaller than a texel.

### Texture size

32 / 64 / 128 only, and **128 is the ceiling for everything in Batch 001**.
Not because 256 would look bad, but because the runtime's own procedural
textures are bounded at `TEXTURE_SIZE_MAX` = 128, and authored content
standing beside procedural content at twice the density would make the seam
between them the most visible thing in the room. Raising it is an
engineering conversation, not an art decision taken quietly.

A size is a density times a world extent, never a number picked first.

### Triangles — limiters, not targets

Godot 4 in 2026 is not the constraint. These are **aesthetic** limiters.
Anchored to what the era shipped: a Quake monster was ~300–500 triangles, a
Half-Life grunt ~600–700, a world crate 12–40, a whole scene 3,000–5,000.

| Category | Ceiling | The failure it prevents |
| --- | --- | --- |
| `architecture_module` | 250 | Above this a wall is being rounded or greebled. A 1998 wall is a brush face with a trim strip on it. |
| `prop` | 300 | A prop competing with the architecture for the eye, which "readable gameplay surfaces" cannot survive. |
| `interactable` | 900 | Must be identified instantly and is looked at deliberately, so it gets more. |
| `hero` | 1200 | The Check and Epsilon. `AUTHORED_CONTENT.md` calls these identity. |
| `enemy` | 700 | Sits exactly on a Half-Life grunt. Above this an enemy stops reading as an era silhouette and starts reading as a modern model with a retro texture, which is the commonest way this aesthetic is faked badly. |
| `landmark` | 2500 | One per room at most, seen from across it. |
| **composed room** | 12,000 | 2–3× a Half-Life scene, because 2026 hardware buys density without buying smoothness. Checked on the composed-room render, the only place the number can be wrong in a way anyone sees. |

**Over budget means delete geometry and paint it instead.** Never optimise
the mesh, and never raise a ceiling to fit one asset.

### Radial segments — where the era actually lives

The segment cap does more work than the triangle cap.

| | Cap | Why |
| --- | --- | --- |
| Hard-surface cylinder, r ≤ 1.5 m | **8** | An 8-sided pipe is a 1998 pipe. The same pipe at 24 sides is a modern pipe that happens to be cheap, and no texture rescues it. |
| Hard-surface cylinder, r > 1.5 m | 12 | A tunnel bore at 8 sides reads as an octagonal room. |
| Enemy / anything organic-leaning | 10 | Enough for curvature, not enough to lose the facet. |

### Bevels — none on architecture

**This is the deliberate inversion of `mario-3`'s rule and it is era-driven.**
A Quake brush edge is razor sharp; edge definition came from the *texture*
(a painted highlight and shadow at the seam) plus a physically separate trim
piece.

- **Failure a bevel would cause:** a bevelled doorway reads as extruded
  modern geometry, and — worse — bevelled modules cannot butt flush, so two
  wall sections meet in a visible groove at every seam.
- **Failure going unbevelled might cause:** an edge vanishing when both
  faces catch the same light. Prevented by the trim piece and by painted
  edge treatment, not by geometry.
- **The one exception:** a 1-segment micro-bevel at 1.5–3 % of the smallest
  dimension, on a hand-scale **prop** above 0.5 m that the player walks up
  to. Never on a floor, never on a module edge.

### Value separation, and the hierarchy it is not enough for

**A room needs a value HIERARCHY, not just legal separation between
neighbours.** Batch 001's concrete_facility passed every separation check
and the review still found it "too uniformly pale and clinical" — because
floor sat at L\* 0.59, wall at 0.76, and the ceiling *borrowed the wall
texture*, so the three surfaces filling most of the frame spanned 0.17
between them. 0.17 clears the 0.10 floor comfortably. The check was right
and the room was wrong.

So a theme declares four separated large-surface values spanning roughly
half the range, and a ceiling is its own role:

| | target L\* | |
| --- | --- | --- |
| trim | ~0.20 | structural, the darkest thing in the room |
| floor | ~0.42 | walked on, dirtiest, never the mid value |
| ceiling | ~0.59 | its own texture, ribbed one way — a grid reads as a floor seen from underneath |
| wall | ~0.76 | the brightest surface, with a dark base course along the bottom |

**The accent is a marking colour, not a fill.** Batch 001 filled every
painted prop and the whole trim rail with the theme accent, and the review
found it "carrying too much of the scene". A colour that marks everything
marks nothing. Props take a *tone* from the base ramp; the accent survives
as a band on the minority of objects that earn one.

**And a second rhythm beats less structure.** "Every surface exposes the
same exact 4 m panel rhythm" is fixed by alternating a ribbed bay against a
plain one — geometry, standing proud, so it shades itself — not by removing
the panels.

| Rule | Threshold | The failure |
| --- | --- | --- |
| Floor / wall / trim within one theme | ΔL\* ≥ **0.10** | Greyscale mush. Desaturate a screenshot and you cannot tell where the floor stops. A 1998 game with harsh simple lighting has nothing else to separate them with. |
| Any interactable against a wall or trim colour | ΔL\* ≥ **0.18** | The Check disappears into the wall it stands against in one theme out of six. `AUTHORED_CONTENT.md`: "Can I use this?" must never be a guess. |

**L\*, not luminance:** four of six themes sit in the dark half of the
range, where a threshold on linear luminance would demand enormous gaps in
shadow and force the whole palette pale to satisfy a number.

**Max 4 palette families per asset.** Running out of colours is the
constraint doing its job; an asset reaching for a fifth is usually painting
detail that should have been value.

### Readability at range — checked, not hoped for

| Object | Seen first at | Screen height (1080p) |
| --- | --- | --- |
| Melee enemy (1.6 m) | 18 m (`ENEMY_AGGRO_RADIUS`) | **48 px** |
| Melee enemy | 40 m (`STATIC_PULSE_RANGE`) | 22 px |
| Check (2.6 m box) | 39.6 m (largest arena diagonal) | **35 px** |
| Check | 30 m (longest corridor) | 47 px |

Forty-eight pixels is the enemy design problem, and 35 is the Check's.
**Every review shot is taken at these distances**, never only at a
flattering portrait range — the bench mario-3 built, believed, and sent to
its owner as proof that a design worked at a size nobody plays at.

The measured bench numbers and the derived arithmetic agree independently:
the melee concepts measure 41–46 px at 18 m against a derived 48, and the
Check concepts 39–41 px at 30 m against a derived 47 for a full-height 2.6 m
object (the built concepts are 2.16–2.23 m, which scales to 39–40). Two
instruments built from different inputs landing on the same number is the
only reason either is trusted.

**Minimum meaningful geometry:** at least 8 % of the object's height, **or**
at least 2 screen pixels at the distance it is judged at — whichever is
larger. At 18 m, 2 px is 67 mm of real form. Below that it is texture.

---

## 3. Silhouette language

1. **Every object must be identifiable as a solid black shape.** If it is
   not, the silhouette is wrong and no amount of texture fixes it. Shot 5 of
   the review sheet is this test and it is the exam.
2. **No two faces of a form are the same width.** Parallel-sided boxes are
   what make a build read as "squares in Blender". Taper, shear or wedge
   every mass that can take it.
3. **Exaggerate the load-bearing masses.** Thin, realistically-proportioned
   objects vanish at 35 px.
4. **Asymmetry.** A perfectly repeated symmetric object reads as cheap at
   any triangle count.
5. **One dominant cue per object, and nothing competes with it.** If every
   edge is lit, none of them is the one to look at. Epsilon has one
   aperture. An enemy has one eye. A Check has one lit band.

---

## 4. Geometry language: three families

Archipepsi has three, not two, and the third is the one that needs
deciding.

### 4a. Hard-surface — architecture, props, machinery

- **Flat shading, always.** Checked at build time by `common.assert_flat()`,
  because a builder can silently stop calling `shade_flat` and nothing else
  notices: the export succeeds, the count is unchanged, and the asset goes
  soft.
- Boxes, wedges, ramps, clipped prisms, low-segment cylinders. Everything in
  `tools/blender/brushkit.py` is something you could have dragged out and
  clipped in Worldcraft.
- **Wedges matter as much as boxes.** A room built only from axis-aligned
  cubes reads as Minecraft; a wedge is the cheapest thing that breaks the
  cube read, and it is why a Quake room and a Minecraft room do not look
  alike despite both being made of straight lines.
- **More distinct parts, not smoother parts.** A broken slat, a bent rail, a
  dented panel — anything that changes the outline.
- **No booleans anywhere in the toolchain.** A boolean leaves n-gons and
  stray vertices, which makes the triangle count unpredictable, and an
  unpredictable count is a budget you cannot enforce. `wall_with_opening`
  and `frame` are built from four blocks each for exactly this reason.

### 4b. Enemies — FABRICATED ORGANIC (proposed, unsettled)

Archipepsi's enemies are neither creatures nor machines. The proposal is a
third family: **built like machinery that was told to be a creature.**
Tapered volumes and animal posture, assembled from plates, drums and
housings, with no smooth shading and no organic curvature for its own sake.

This is **not settled**, and Batch 001 D exists to settle it: concept A is
nearly a machine, C is nearly a creature, B sits between. The owner decides.

What is already settled, because it has a named failure:

- **Segment cap 10.** Enough for curvature, not enough to lose the facet.
- **Taper is the silhouette.** A limb that is the same width at both ends
  reads as a pipe. A limb built by interpolating between two radii is four
  cones.
- **An enemy never wears its room's colours.** The first enemy pass painted
  all three concepts from the *theme* accent, so in `concrete_facility` they
  came out institutional steel blue — the same family as the wall panels
  behind them. At 18 m and 46 px that is camouflage, and `ENEMY_AGGRO_RADIUS`
  is precisely where the player must see one. Enemies are built from the
  shared `grime` family, which sits below every theme's wall in value, plus
  a single narrow marking band.

### 4c. Emissive cues

**A lit surface must survive being lit.** Godot adds
`emission × emission_strength` on top of albedo, so bright albedo plus
bright emission clips every channel and renders white. Every lit cue in
Batch 001 did this on its first render — including the enemy's eye, which is
the one cue on the figure and the thing that says which way it is facing.

And one that is not about emission at all: **a specular highlight can break
this rule as completely as a glow.** At roughness 0.25 the Epsilon console's
dead screen caught a bloom off the key light that read as a picture. Glass
that must read as OFF runs rougher than glass would be. See L-36.

The rule: **albedo is the family's dark step, emission is its bright step,
and the strength is SOLVED, never chosen.**
`common.make_signal_material()` is the only sanctioned way to build one.

Two corrections Batch 002 paid for, both worth stating as rules:

**Solve against the light, not against nothing.** The first solve balanced
`albedo + strength × emission` — the *unlit* sum. A lit surface also carries
`albedo × irradiance`, and `identity[0]` is a green whose albedo alone clips
its green channel under a facility light. The Epsilon installation's veins
came out at `(255, 255, 147)`: green pinned, red climbing, the hue walking
from Epsilon's colour to the **telegraph's**. The solve now reads
`engine_truth.lighting()` — the brightest `light_energy` in
`THEME_MATERIALS` plus the brightest `ambient_light_energy` on the engine's
environments — scales the albedo until its lit share is at most half that
budget, and solves the strength against the remainder.

**Then measure, because the renderer is not the authored space.** The solve
bounds what the material *says*; tonemapping and sRGB encoding lift what the
screen *shows*. A five-bar sweep on the review bench put the clip point
between saturation 0.40 and 0.60, so cues ship at **0.45**. Fixture lenses
are the deliberate exception at 1.0: a lamp is allowed to be the brightest
thing in its own pool.

> A green cue that renders orange inverts the one rule the colour language
> has. Green says whose this is; orange says what is about to happen.

---

### 4d. The interaction face — settled at the Batch 002 review

A machine the player is meant to believe **people used** needs a face built
at the heights a person works at. Scale alone does not do it: a wall of
racks says *this facility had computers*; it does not say *somebody used
this one*.

So any authored machine that is meant to read as operated carries:

| Part | Height | Why |
| --- | --- | --- |
| Work surface | ~0.95 m | Standing desk height. Below it, a shelf; above it, a counter. |
| Footwell under it | clear to ~0.45 m | Feet go here. Without it the desk is a cabinet with a flat top. |
| Raked control panel | just above the desk | Hands go here, angled toward the operator. |
| Main display | eye height + ~0.4 m | You look slightly UP. Institutional, oversized. |
| Instrument row | between them | What you read while your hands are busy. |
| Floor plate or grating | at the feet | Somebody stood here. This is the part that is about a person. |

Eye height and player height come from `engine_truth`, never from taste.

Two rules the first attempt paid for:

**Build it OUT in layers.** Every part of a machine like this is the same
value, so DEPTH is the only thing separating one from another. Bezel, hood,
panel, desk and floor plate each project further than the part behind them,
and the whole face self-shades.

**Give it a different surface.** Geometry that says "console" under a map
that says "cabinet" reads as cabinet. At any real distance the map is louder
than the silhouette. See `ART_LESSONS.md` L-37.

---

## 5. Texture language

- **Albedo only.** No normal, roughness or AO maps, anywhere, ever. See §1.
- **NEAREST filtering with mipmaps.** Not a preference:
  `generation/textures.gd` renders the procedural half of the game at
  `texture_filter = NEAREST`, so an authored asset importing with linear
  filtering makes the authored/procedural seam the most visible thing in the
  room. Mipmaps stay **on** — without them a 128px texture on a distant wall
  shimmers as you walk, which reads as a bug rather than as a style.
- **Painted in Python, pixel by pixel, from the palette.** Art-as-code, same
  as the geometry.
- **Snap every decision to a texel before choosing its colour.** Density
  alone does not make a pixel look; a smooth rule sampled at any resolution
  is still an anti-aliased edge. Shapes are drawn *in* pixels, never
  downsampled *to* pixels.
- **Know the texel size before designing a detail.** At 32 texels/m a
  feature under ~2 texels does not survive the render. `Surface.texels()`
  converts metres to whole texels and the honest response to "it is 0.6
  texels" is to make it bigger or leave it out.

### UV convention — world-planar, and this is the important one

**Every asset in Batch 001, props included, is projected from world axes at
a fixed density.** Not `smart_project`.

A 1998 editor projected the texture onto each brush face along that face's
dominant axis at a fixed world scale, and that is most of what the era looks
like. It also means **modules butt together without a texture
discontinuity**, which `smart_project` cannot promise: two independently
unwrapped wall sections show a break in the grain at every seam, exactly
where a 1998 level would have had none.

Corollary, and it bit during Batch 001: **UVs are projected from local
coordinates, so the origin must be final first.** Projecting before setting
the origin bakes the build position into the texture, and two modules built
at different heights then tile with the grain offset.

---

## 6. Grime, wear and the rule that matters most

> **A hash on a broad surface is digital camouflage.**

Every cluster placed by a random number sits where a random number put it,
so no cluster means anything, and the result reads as *generated* rather
than as painted. For a game whose premise is "a local AI was handed a 1998
level editor", that is the single worst thing the art could accidentally
say — and Epsilon must never manufacture a texture, so development-time art
must never look as though it did.

**This project has already failed this way twice**, both times inside the
module whose docstring warns about it. See `ART_LESSONS.md` L-05 and L-06.

The structural fix, enforced by API shape rather than by good intentions:

- `paintkit.speckle()` **requires a zone function** and has no default. A
  caller must say *where* grit gathers — near a seam, along the floor, at a
  worn rim. A caller that genuinely wants it everywhere must write
  `lambda x, y: 1.0`, which is at least a decision somebody made.
- `paintkit.streak()` **requires an origin point.** There is no "add some
  streaks" call. A streak that comes from nothing is the failure; a streak
  from a bolt that is actually drawn is a history.
- `paintkit.Hash` takes a **zone label** as its first argument and offers no
  way to ask for a random position. Randomness survives only as a *breaker*
  inside a zone structure already chose.
- **A rim is a fixed width in the world, never a fraction of the surface.**
  Expressed as a fraction, every texel on a small plate becomes an "edge".
- **Dirt gathers where dirt gathers:** the floor line and the horizontal
  ledge every seam creates. Not at random points.

**Grime is shared across all six themes.** A theme-tinted grime reads as a
coloured gel over a clean surface rather than as a surface with a history.

---

## 7. Palette and value strategy

Single source of truth: [`assets/art_palette.json`](../../assets/art_palette.json),
generated by `tools/blender/palette_build.py`. **Nothing in
`tools/blender/` writes a hex literal.**

**The four anchor colours per theme are READ from the engine**
(`THEME_MATERIALS` in `schemas/constants.py`), never chosen. The engine
paints the whole procedural game from them today, and an art palette that
invented its own would not be a palette, it would be a second opinion — and
the disagreement becomes visible the moment authored and procedural content
share a room. `palette.verify()` fails if any anchor drifts.

What the art lane adds is a **solved value ramp** around each anchor, so a
painter has dark / mid / light steps instead of one value and a
`darkened()` call. Ramps are solved in HSV against a target CIE L\*, never
blended toward white — that spends saturation first and produces pastel.

**Every ramp contains its own anchor, verbatim.** The first version of the
solver used absolute L\* targets per role and turned `void_glitch`'s
`#00ffbf` neon trim into three dark teals: correct arithmetic that deleted
the theme's identity.

### The universal families — the game's grammar words

Six colours do **not** vary by theme. This is the most important decision in
the palette:

| Family | Means | Never used for |
| --- | --- | --- |
| `signal` | You can use this. Every interactable prompt, rim and reveal face. | Anything decorative |
| `hazard` | This will hurt you. | Anything decorative, in any theme, for any reason |
| `identity` | Epsilon. Its presence, terminal and voice surfaces. | Anything else in the game |
| `dead` | Unpowered, locked, spent, offline. | — |
| `send` | This leaves for the multiworld. The Check's beam and destination ring. | — |
| `glitch` | Epsilon Static and the missing-world checker. **Cosmetic only, never a mechanic.** | Any mechanical state |

A Check tinted to match its theme is a Check that vanishes in one theme out
of six.

### The value sandwich

**Value alone cannot carry an interactable across six themes**, and finding
that out was worth the check that found it. A base ramp spans L\* 0.18–0.93,
so no single value can be far from all of it, and the first version of the
interactable-separation check was therefore unsatisfiable.

The rule that replaces it: **an interactable is painted as a sandwich — a
dark surround and a bright signal face from the same family, adjacent — so
whichever way a theme goes, one half of the pair separates from it.** The
check now asks the satisfiable version: for every surface a room is actually
painted with, some step of every signalling family clears ΔL\* 0.18.

---

## 8. Lighting

Simple and graphic, not physical. The game's own rig is the reference:
`chamber_builders._light` uses one `OmniLight3D` per span at the theme's own
`light_energy` and `light_color`, range 12, **shadows off**.

- **SSAO off.** Contact darkening is exactly the physical cue the flat look
  rejects.
- **Glow: only on genuinely emissive things** — a fixture lens, a signal
  face, a Check core.
- **Ambient exists only so shadows show which palette family they belong
  to.** A surface in shadow that cannot be identified is too dark.
- **Flat is not bright.** The first composed room summed three omni lights
  at energy 3.0, an ambient of 0.30 and a directional fill, and every wall
  clipped to pure white. The fix was not to darken the palette — it was to
  **sum the light energies before touching anything else.**

### Cold room, warm pools — settled at the Batch 001-R review

The facility direction asks for yellow utility lighting. The 001-R revision
read that as a colour and turned every ceiling lamp warm; the owner's answer
was exact:

> Do NOT turn the whole room warm. Warm yellow light should appear as
> **localized utility pools / fixtures** within a still-cold environment.

So warmth is a **fixture**, not a temperature:

| | General light | Utility pool |
| --- | --- | --- |
| Colour | the theme's own `light_color` — cold here | warm amber |
| Energy | the theme's own — 3.0 in `concrete_facility` | **lower**, ~1.4 |
| Range | 12, the engine's own — covers the room | **~2.6**, falls off inside it |
| Height | ceiling | ~2.1 m, at working height |
| Placement | on the chamber's spacing | wherever somebody needed to see something |

**Range is what makes a pool a pool.** Anything on a range comparable to the
general light is a second general light no matter what colour it is. And a
pool must be *dimmer* than the room's own light: a warm pool that out-reads
the general light inverts the hierarchy, and the room becomes a warm room
with cold corners — the thing being avoided.

A pool also needs a visible source. `arch_utility_lamp` is that fixture; a
warm patch with nothing making it is a stain on a wall.

**Standing constraint:** this sandbox can only initialise Godot's
**Compatibility** renderer. Every screenshot produced here is a *lower
bound*; the owner's build is Forward+ and gets better glow and proper shadow
filtering. When a capture looks flatter than this document promises, that is
a candidate explanation and never the first one to reach for.

---

## 9. Theme differentiation, and theme commonality

The six themes are **material and dressing vocabularies inside ONE game**,
not six asset packs. The split is enforced by which module a rule lives in:

**Shared by every theme** (in `paintkit.py`, `palette.py`): the texel
density, the panel-seam grammar (one shadow texel, then one lip texel),
where grime gathers, how edge wear reaches in from a module boundary, the
stencil alphabet, the hazard stripe pitch, the grime family, and every
universal signalling colour.

**Different per theme** (in `materials.py`): what the structure *is* —
poured concrete, steel corrugation, glazed tile, coursed ashlar, cut
sandstone, or a checkerboard that admits it is a checkerboard — and what
kind of history the surface carries.

> **If a player can tell two themes apart by their GRAMMAR rather than by
> their MATERIAL, this has failed and the game has six asset packs.**

`void_glitch` is the test case and it passes: it is the missing-texture
checker at a real editor's cell size, and it still carries the same panel
courses, the same vertical joints and the same fixing pitch as every other
theme — so it reads as *this game's* broken room rather than as a different
game's texture.

**Batch 001 builds three treatments only** — `concrete_facility`,
`rusted_industrial`, `void_glitch`. They are the widest spread the palette
offers: an institutional light surface, a warm corroded one, and the
deliberately broken one. The other three are inventoried and **not built**,
because building all six before a style is approved is theme production, and
theme production is behind the Style Lock gate.

---

## 10. What gets geometry and what gets paint

Ask in this order:

1. **Does it change the outline seen side-on?** → model it.
2. **Is it a load-bearing mass, or something the player stands on or
   collides with?** → model it.
3. **Is it a shape the player must read at play distance?** → model it.
4. **Anything else** → paint it.

**Always painted:** panel lines, bolts, rivets, seams, stencilled text,
hazard striping, rust, dirt, wear, water streaks, cracks, edge highlights,
overlap shadows.

**Always modelled:** primary masses, anything collidable, the *shape* that
is a gameplay tell, and a grate's slats — a grate's whole job is to be a
silhouette you can see through, which is the one case where paint-it-do-not-
model-it loses.

---

## 11. Prop density

- Dressing is placed in **clusters with a reason**, never scattered evenly.
  A prop every two metres reads as decoration; three things against one wall
  reads as somewhere people worked.
- **Not every surface is busy.** Detail is a way of pointing, and a room
  where everything is detailed points at nothing.
- **Debris is made of pieces the player has already seen intact.** Debris
  invented from scratch reads as scenery; a crate that lost a side and a
  length of the pipe run reads as something having *happened* here, which is
  the only reason to spend a prop slot on rubble.
- **A background prop drawing the eye for the wrong reason is a composition
  problem.** Fix the placement before adding geometry.

---

## 12. How to judge pass/fail

**An asset is not good because Blender exported it, Godot loaded it, the
tests passed, it is under budget, the script is clever, or the screenshot
exists.** Those prove technical validity. The owner decides whether it looks
good and belongs in Archipepsi.

Judge in this order, and stop at the first failure:

1. **Silhouette.** Shot 5, flat black on a light field, head-on. Can you
   name the object? If not, nothing else matters.
2. **Form.** Shot 6, untextured clay. Paint hides form; a lathe-turned peg
   survives three review passes when there is a face drawn on it.
3. **Rotation.** Shots 1–4. The front is the one view that lies, because the
   front is the view everything gets tuned in.
4. **Scale.** Shot 7, beside the 1.8 m player rod. An asset judged without
   one is judged against nothing.
5. **Play distance.** Shot 8, the game's lens, the game's eye height, the
   real distance, with the measured pixel height printed on it.
6. **In context.** The composed room. A kit can pass eight shots per object
   and still assemble into a showroom of props rather than a place.
7. **Greyscale.** Desaturate the room shot. If the composition falls apart,
   the palette is not working.

### Two things a check can never tell you

- **A check can only tell you the thing matches its description. It cannot
  tell you the description was worth matching.** When a build passes
  everything and still looks wrong, the *spec* is the suspect — not the
  modelling, and certainly not the eye that flagged it.
- **A new bench is the least trustworthy thing in the repository.** Establish
  what an instrument measures before believing what it says. Batch 001's own
  bench reported a 1 m crate as 694 px because it was measuring the ground
  plane, and reported "0 materials forced to NEAREST" from a walk that could
  not express having found no materials at all.

**Do not defend a weak render with implementation effort. If it looks wrong,
it is wrong.**
