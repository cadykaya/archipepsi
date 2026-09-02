# ART LESSONS — what building Archipepsi's art has taught us

**This is a living document. Add to it the moment something is learned, not
at the end of a pass.** The value is in being read before a build, and a
lesson written up three sessions later has already cost its price a second
time.

Everything here was paid for with a rebuild, a wrong render, a hung command
or a check that lied. Nothing here is theory.

---

## Environment and tooling

### L-01 · `--headless` cannot render, and it does not say so
`godot --headless` selects the **dummy** rendering driver, which never
presents a frame. An awaited `SubViewport` capture therefore hangs forever
with **no output at all** — not an error, not a warning, nothing. Two
minutes of a wall-clock timeout looked like a slow render.

Use `xvfb-run -a godot --rendering-driver opengl3`. And per mario-3: a probe
that can hang is a probe whose silence you cannot interpret. Every render
command here runs under an explicit `timeout`.

### L-02 · A `class_name` script is invisible until an import pass
`-s Script.gd` does **not** rescan for `class_name` declarations, so every
reference to a helper class fails with *"Identifier not declared in the
current scope"* for a file that is plainly there. Only `--import` rewrites
`.godot/global_script_class_cache.cfg`. Both review entry points run it once
and cache the result.

### L-03 · Only the Compatibility renderer initialises in this sandbox
Vulkan will not start. **Every capture produced here is a lower bound** on
the owner's Forward+ build, which gets glow and proper shadow filtering.
When something looks flatter than `ART_BIBLE.md` promises, that is a
candidate explanation and never the first one to reach for.

### L-04 · A code-created node does not get its class's name
`WorldEnvironment.new()` is named `@WorldEnvironment@2`, so
`get_node("WorldEnvironment")` silently fails. Name nodes explicitly when
anything will look them up.

### L-04b · `curl` against the GitHub API is unauthenticated here, and silent
`GITHUB_TOKEN` is the literal string `proxy-injected`, so a `curl` to
`/check-runs` returns an empty list rather than a 401. A poll loop built on
it reports silence forever — which is indistinguishable from "still
running", and is the same failure as a filter that cannot express failure.
Use the `mcp__github__*` tools, and note that a scheduled heartbeat session
does not have them.

---

## Painting

### L-05 · The paint module committed its own named failure, twice
`paintkit.py`'s docstring warns that **a hash on a broad surface is digital
camouflage**. The module then did it, on its first render and again on its
second.

- **First:** one `value_grain` call did both broad patches and fine speckle
  at a 2-texel cell. Every material sheet came out with an even dark pepper
  across the whole tile — television static, not concrete.
- **Second:** the fix split them, and `broad_patches` laid its cells on a
  fixed lattice with a hard `set`. The patches were fine individually and
  the *wall* read as a tiled grid, because every cell boundary in a column
  agreed with every other.

The fixes, in order of how much they mattered:

1. **`speckle()` now REQUIRES a zone function and has no default.** A
   function that takes only a density has no way to be anything but noise.
   A caller that genuinely wants it everywhere must write
   `lambda x, y: 1.0`, which is at least a decision somebody made.
2. **Patches `mix` at low strength, they do not `set`.** A patch is a shift
   in value, not a different material. The first version used steps two
   apart on the ramp and read as pasted rectangles.
3. **Each row of cells is jittered sideways** and the cell edges are ragged.
4. **`streak()` requires an origin point.** There is no "add some streaks"
   call. Every streak on the rusted wall starts at a bolt that is actually
   drawn, and that is the entire difference between a rusted wall and a wall
   with orange noise on it.

> **A painter handed only (x, y) has one tool left, and that tool is a
> hash.** Give it the structure instead.

### L-06 · Trim is a strip, not a picture
The first trim texture painted one safety band at one height on a 4 × 4 m
tile. A 0.4 m trim piece samples a **13-texel window of a 128-texel map**,
so 90 % of the paint was never seen — and *which* window depended on where
in the world the piece stood. A 1998 trim texture was a strip that tiled,
and so is this one: the design repeats every 0.5 m vertically, so any window
a trim piece samples shows a complete trim.

### L-07 · A ramp table can delete a theme's identity
The palette solver's first version took absolute L\* targets per role.
`void_glitch`'s trim anchor is `#00ffbf`, a deliberately loud neon, and the
trim table's 0.12–0.36 targets solved it into three dark teals. The
arithmetic was right and the ramp no longer contained the colour the engine
actually paints with.

Ramps are now built **around** the anchor's own L\*, and `palette.verify()`
asserts that every ramp contains its anchor byte for byte.

### L-08 · Enemies must not wear the room's colours
All three melee concepts were first painted with `painted_metal`, which
builds from the **theme** accent — so in `concrete_facility` they came out
institutional steel blue, the same family as the wall panels behind them. At
18 m and 46 px that is camouflage, and `ENEMY_AGGRO_RADIUS` is exactly where
the player must see one.

Enemies are now built from the shared `grime` family plus one narrow marking
band. The rule generalises: **anything the player must find is painted from
the universal families, never from the theme's.**

### L-09 · A lit surface must survive being lit
Godot adds `emission × emission_strength` on top of albedo. Bright albedo
plus bright emission at strength > 1 clips every channel and renders
**white**. Every lit cue in Batch 001 did this on its first render,
including the enemy's eye — the one cue on the figure, the thing that says
which way it is facing, and it had lost its colour entirely.

The first fix — dark albedo, bright emission, a strength picked by hand —
was better and **still wrong.** Epsilon's core is a much larger surface than
an eye slit, and it clipped again at the strength the eye was happy with,
because a hand-picked strength is a guess about a sum nobody computed.

`common.make_signal_material()` now takes a `saturation` and **solves** for
the strength at which the brightest channel of `albedo + strength × emission`
reaches 1.0. The same call is then correct for a 5 cm eye slit and a
half-metre core, and there are no magic numbers left to be wrong. The
fixture lens asks for `saturation=1.0` deliberately: a lamp is the one place
in the batch where clipping the brightest channel is the intent.

> A constant you tuned by eye on one asset is a constant that will be wrong
> on the next one. Solve for it.

---

### L-29 · The solve was right and the surface still rendered orange
`make_signal_material` (L-09) solves the strength so that
`albedo + strength × emission` lands just under 1.0. The Epsilon
installation's veins rendered as **yellow-white bars**, measured at
`(255, 255, 147)` — red and green both clipped, blue not.

That sum is the **unlit** sum. The surface is also lit, and
`albedo × irradiance` is the term the solve left out. `identity[0]` is
`#23660c`, whose green channel alone clips under a facility light, so green
had nowhere left to go, every additional photon went into red, and the hue
walked from Epsilon's green to the **telegraph orange**. Green says whose
this is; orange says what is about to happen. A green cue that renders
orange inverts the one rule the colour language has.

The fix is not a bigger number or a smaller one. The solve now reads
`engine_truth.lighting()` — the brightest `light_energy` in
`THEME_MATERIALS` plus the brightest `ambient_light_energy` on the engine's
environments — scales the albedo down until its lit contribution is at most
half that budget, and solves the strength against what is left.

> A material that must keep its hue has to be solved against the light it
> will be under, and the light is not a number art gets to choose.

### L-30 · A solve in the authored space is not a solve in the rendered one
With L-29 fixed, five bars at saturations 0.94 / 0.60 / 0.40 / 0.25 / 0.12
still put the green channel at 255 for the top two. The solve guarantees the
**authored** sum stays under 1.0; the renderer then tonemaps and
sRGB-encodes on top of that, and both lift.

That lift is a property of the pipeline, not of the palette, so it was
**measured** rather than modelled: the sweep is one build, one render and a
pixel count, and it put the clip point between 0.40 and 0.60. Every emissive
call site now passes 0.45 with the measurement written beside it.

> When a prediction and a render disagree, instrument the render. Five bars
> in one frame cost less than one more guess.

### L-31 · A texture authored at the wrong metre is authored at the wrong size
`alien_shell` was built against `surface()`, whose metre is the **prop**
metre (64 texels/m), and projected by every caller at `HERO_DENSITY`
(96 texels/m). Every pitch in it therefore came out at ⅔ of its stated size:
a 0.16 m plate became 0.107 m, which at the 8 m the installation is read
from is under half a pixel. The eruption rendered as a cloud of tan and
green confetti with no shape in it — the exact "digital camouflage" failure
`paintkit` exists to prevent, arrived at from the opposite direction.

> The surface a canvas is authored against and the density it is projected
> at are the same fact stated twice. If they disagree, nothing in the
> texture is the size it says.

### L-32 · "Cold, dead, institutional" is a VALUE, and it was read as a hue
The machine bank was painted from the theme's **base** ramp, first at
`base[1]` and then at `base[0]`, on the reasoning that base is what the
facility is made of. Both rendered the bank as the palest thing in the
frame — paler than the wall behind it, and far paler than the green erupting
through it, which inverts the whole point of the object.

The base ramp is what the BUILDING is made of. A machine installed into that
building and abandoned for decades is darker than its own room, and the
theme already keeps its dark cold greys in the **trim** ramp. Repainting the
bank from trim and grime, with nothing on it above `trim[2]`, made the
intrusion the brightest thing in the room without touching the intrusion.

> Before reaching for a colour, ask which ramp the object belongs to. A
> value problem solved with a hue is still a value problem.

### L-42 · The palette's brightest step is not where an emitter starts
`make_signal_material(dark, bright)` was called with step 0 and step **3**
everywhere, because step 3 is the family's brightest colour and the emitter
should obviously be brightest. For `identity` (`#57ff1f`) and `send`
(`#ffd45c`) that is fine — both are saturated at step 3. For `signal` it is
not: step 3 is `#85fff3`, R 0.52 against G 1.00 and B 0.95, which is a mint
so pale that emitting it renders a **white** hexagon with no teal in it.

The concept got away with it on a core the size of a fist inside a cage. At
the size the Check's state channel needs, the available state — the one
state that must be unmistakable — was the least saturated thing on the
object. `signal` now emits step **2** (`#39d7c8`).

> A ramp's brightest step is the brightest a TEXTURE may go. An emitter
> starts from the most SATURATED step, and those are not the same index.

### L-43 · The channel that is not carrying the message must not be loudest
The Check's destination ring, built as the engine's plain octagonal tube and
lit at the same saturation as the item, came out the brightest object in the
frame: a gold mat with a Check standing on it. `hero_shell`'s own docstring
states the rule it broke — *if two things compete for the eye at 35 px,
neither wins* — and the ring is the **destination** channel, not the state
one.

Turning it down was only half a fix. The engine overrides that material per
recipient world and can turn it straight back up, so brightness is not a
property this lane controls. What survives an override is **form**: eight
pads with floor showing between them read as a marker ring at any tint,
where a solid band reads as a slab at most of them.

> When the engine owns the paint, the composition has to be in the mesh.


### L-46 · A "dead" state is dead metal, not a dim lamp
The Check's locked and confirmed items were built with
`make_signal_material` at low saturations — 0.22 and 0.14 — on the
reasoning that `reward.gd` runs them at 0.4 and 0.2 emission energy, so
they should be dim rather than dark.

Measured against the mast they sit on:

| | rendered | luminance |
| --- | --- | --- |
| confirmed husk | (102, 109, 121) | 94 |
| locked cradle | (114, 120, 131) | 83 |
| mast head | (68, 82, 101) | 80 |
| cage upright | (60, 72, 91) | 71 |

**The deadest things on the object were the brightest.** That function's
entire job is to make a glow survive being lit, and it does that job at
every saturation — turning the number down scales the emission and leaves a
self-lit surface that no unlit paint nearby can compete with.

Dead states get albedo and nothing else. The "but it must be visible at
range" worry belongs to a different part: `hero_shell` paints a lit band on
the mast that is on in all four states. The band says *there is a Check
here*; the item says *which state*.

> If a material is meant to be the darkest thing in the frame, do not build
> it with the function whose purpose is to stop things being dark.


## Geometry

### L-10 · `rotation_euler` on a positioned part rotates about the WORLD origin
Every primitive in `brushkit` builds its geometry at absolute coordinates
with the object left at the origin, so setting `rotation_euler` rotates
about the world origin — and `join` then bakes it in. A pipe built 2.55 m up
and tipped 90° does not lie down, it swings 2.55 m sideways.

This shipped **three times in one session**: a 4 m corridor module that
measured 5.95 m, a pipe cluster 1.55 m deep, and a machinery unit 2.48 m
tall. None looked wrong in a render. All three were obvious in one line of
`measure()`.

`brushkit.spin(obj, axis, degrees)` rotates about the part's own centre and
is the only sanctioned way. **Arithmetic beats staring.**

### L-11 · One origin rule for every asset is wrong, and invisibly so
Every Batch 001 asset first went through a single `set_origin_floor_centre`,
which puts the origin at the geometry's own lowest point. For a crate that
is right. For a pipe run built at 2.55 m it dropped the pipes to ankle
height. For a ceiling bay it moved the downstand beams **above** the ceiling
plane, where they were invisible from inside the room — so the composed room
rendered with a flat white lid, and the one piece of structure that exists
to stop a ceiling reading as a lid was hidden behind it.

**Nothing failed. Every review sheet still passed**, because a turntable
shot of a ceiling bay looks identical whichever way its origin faces.

`common.set_origin(obj, anchor)` now takes `floor` / `ceiling` / `wall` /
`module_floor` / `centre`, and the anchor is recorded in the manifest so a
placer never has to guess.

### L-12 · Do not move one part's origin before joining it to another
Setting the light fixture body's origin before joining the lens pulled them
180 mm apart, and the export reported the asset as 0.44 m tall when it is
0.26 m. Set the origin **once**, on the joined object.

### L-13 · A railing needs an edge, or it is a rail in mid-air
The first composed room placed the guard rail at 1.0 m with no deck under
it. A railing is a piece that only means anything in relation to an edge,
and a kit shot that omits the edge is testing the wrong thing.

---

### L-50 · A `centre`-anchored asset at floor level is half a different asset
The three projectiles are anchored `centre`, because a projectile's origin
is its middle. Placed in a shot at `y 0`, half of each one is under the
floor slab — and what is left above it is not "half a spindle", it is a
**cone**. Three spindles rendered as three traffic cones, and the first
reading of that sheet was that the geometry was wrong: an hour went into
rebuilding frusta that were correct all along.

The tell was there and was missed: all three were the same wrong shape, and
a modelling mistake repeated identically across three independent builders
is not a modelling mistake.

L-11 said one origin rule for every asset is wrong and invisibly so. This
is its other half: **the anchor a thing was authored to is part of how it
must be placed**, and a placement that ignores it fails by looking like a
different object rather than a misplaced one.


### L-64 · Blender −Y is Godot +Z, so an inset face lands on the BACK
Batch 022's four signage modules each had a pale recessed field for runtime
text, and the arrowhead sat proud of one. All of them were authored at
negative Blender Y — the intuitive "toward the viewer" in the Blender
viewport. The glTF export maps Blender +Y to Godot **−Z**, so every field
and the glyph on it came out facing the wall the sign is bolted to.

Nothing failed. Triangle counts, texel density and the flat-shading
assertion all passed, and the turntable-style detail sheet looked plausible
because the modules were small. In the room shots the chevrons read as
plain trim blocks: their ground and their arrow were both on the far side.

> An asset with a FRONT has to declare which way that is, and the axis
> flip belongs in the builder, not in the reader's head.

### L-65 · A glyph needs margin as much as it needs contrast
The same batch's arrowhead was first painted in its own plate's trim
material — same value, same texture — and read as a dark lump. Repainting
it in the text ink fixed the contrast and it *still* read as a solid block,
for a duller reason: a 0.20 m arrow on a 0.22 m field leaves a 10 mm pale
margin, and at any real distance the margin disappears and the glyph
becomes its own bounding box.

> A mark is legible because of the ground around it, not only the value
> against it. Widen the plate before shrinking the mark.

### L-66 · A form that must mean "left" cannot be symmetrical
The first directional element was two wedges meeting in a shallow V, on the
theory that the shadow in the fold would carry the direction. At eye height
in a corridor it read as a peak — a mountain, or the letter A.

> A shape can only encode an axis it is not symmetrical about. "It will
> read because of the lighting" is a bet on the one thing a theme, a
> render mode and a dark room are each free to take away.

## Lighting

### L-14 · Flat is not bright — sum the energies first
The first composed room stacked three omni lights at the theme's own energy
(3.0), an ambient of 0.30 and a directional fill. Every wall clipped to pure
white. The fix was **not** to darken the palette: it was to sum the light
energies before touching anything else, drop the ambient to 0.10, delete the
directional entirely, and use the light count the game would actually place.

The bench now uses the game's own rig — `chamber_builders._light`: one
`OmniLight3D` at the theme's energy and colour, range 12, shadows off — plus
an ambient that exists only so shadows show which palette family they belong
to. **A bench that adds a fill the game does not have is a camera that
lies.**

---

### L-26 · `Image.blit_rect` does nothing at all when formats differ
A `SubViewport` hands back RGBA8; every canvas composed by hand here is RGB8.
`blit_rect` between them copies **nothing** — no error, no warning, an empty
destination. Three versions of the enemy line-up sheet came out entirely
black while the render behind them was fine, and two of those versions were
spent guessing at other causes (the crop position, then an xvfb clamp).

The fix was not the guess, it was measuring: printing the bounding box of
non-background content proved the render was correct and moved the search
into the compositor. **When two guesses in a row are wrong, stop guessing and
instrument.**

### L-27 · A relative output path silently writes somewhere else
Godot's working directory is not the repo root, so `save_png("docs/art/...")`
wrote the void_glitch probe into a directory nobody looks in — and reported
success, because `save_png` returns nothing useful and the script's own
"wrote 2 captures" line had already been printed. Every render script now
absolutises its out-dir before passing it in.

### L-28 · The obvious way to make a glowing mass is a lampshade
The Batch 001 review rejected Epsilon's core as "lamp/cone energy". The
first revision rebuilt it as a prism with a smaller top radius — which is a
truncated cone, which is a lampshade. The named failure was reproduced
immediately, because a taper is the obvious way to make a glowing form and
the obvious way was the thing being rejected.

It is now hard-edged blocks at unrelated angles, none of them tapering.
**When a review names a shape as wrong, check the fix against the name, not
against your intent.**

### L-35 · A box that swallows what it frames is invisible in the worst way
The console's monitor was three parts: a housing box, a bezel frame, and the
glass. Their depths were written as *centres and sizes*, and the arithmetic
put the bezel 10 mm in front of the housing's front face and the glass
entirely **inside** the housing. From eight metres the whole console rendered
as one flat pale panel — there was no screen in it to see, and nothing said
so. A build log cannot report "this box is eating that one".

Rewriting the three depths as **faces** rather than centres made the mistake
impossible to write:

    bezel_face   = front - 1.38     # the ring, front-most
    glass_face   = front - 1.30     # recessed 80 mm behind the ring
    housing_face = front - 1.26     # and the box behind that

> When parts nest, name the surfaces, not the centres. A centre-and-size
> pair is a claim about where a face is, made indirectly, and indirection is
> where the sign error lives.

### L-36 · A specular highlight can break a "nothing glows" rule
The installation's single hardest rule is that nothing on the human half
emits — the moment a console has a lit readout, the machine reads as
powered and the intrusion stops being the only living thing in the room.
Every emissive was accounted for and the rule still broke: at roughness 0.25
the 2.7 m console screen caught a broad specular off the key light and
rendered with a bright bloom across its lower corner. It looked exactly like
a monitor that was on.

The fix is roughness 0.50 — still glass, no longer a picture.

> A rule about emission is really a rule about what the surface LOOKS like.
> Enumerating the emissive materials proves nothing on its own.

### L-37 · Geometry said console, surface said cabinet, and surface won
The operator console was built as its own form — hood, bezel, desk,
footwell, floor grating — and then painted with the same `machine_bank`
cabinet map as the racks either side. At a pace back it read as a
differently shaped piece of the same wall.

Giving the desk, apron, housing, hood, auxiliaries and raked panel the
**console** skin — switch banks and patch rows — separated them instantly.
Nothing about the geometry changed.

> When an object needs to read as a different KIND of thing, the surface has
> to say so too. At any real distance the map is louder than the silhouette.

### L-40 · The docstring said no orange. The code painted orange on all ten.
`build_concept_enemy.py` says it in bold:

> **Hazard orange is deliberately absent, and that is a rule rather than an
> omission.** Green says *whose this is*; orange says *what is about to
> happen*.

`ART_BIBLE.md` says it. The owner locked it. And `propkit.enemy_skin`'s
signature was `marking="hazard"`, so every enemy in the roster carried a
full-width band of `#9f3a15` across its chest.

It survived four review batches because of where it is: at 18 m the band is
two pixels, and every enemy shot in this project is taken at 18 m on
purpose. It took a **50 mm lens at 3 m** -- a shot nobody had a reason to
compose before the camera rig made composing one free -- for it to be the
second thing in the frame.

> A rule written in three places and implemented in none is the normal
> case, not the surprising one. The thing that finds it is a view you had
> no reason to take.

## Checks and benches

### L-15 · A check that passes on a clean tree has proved nothing
`tools/sabotage_checks.sh` reintroduces the exact bug each guard was written
to catch and confirms it fires. Sixteen cases, all of them behaving. Run it
before trusting a new guard.

### L-16 · A check can be too lenient AND unsatisfiable, in that order
The interactable-separation check first asked *does SOME pairing of a signal
colour and a wall colour separate?* — which passes on any palette containing
a light and a dark, and reported a comfortable 0.48 against a 0.18 floor.

Rewriting it as *does some step separate from EVERY surface?* made it fire
everywhere — and that was also wrong, because a base ramp spans L\* 0.18–0.93
and **no single value can be far from all of it.** The check was
unsatisfiable, which is as useless as a permissive one.

The finding was an art rule, not a palette fix: **value alone cannot carry
an interactable across six themes.** An interactable is painted as a
sandwich — dark surround, bright signal face — so whichever way a theme
goes, one half of the pair separates. The check now asks the satisfiable
version and, on its first honest run, immediately caught `send` gold
vanishing into `temple_ruin` sandstone (0.174 against a 0.18 floor).

### L-17 · A bench measures what is in the frame, not what you meant
The review sheet's play-distance shot measured a 1 m crate as **694 px**. It
was measuring the ground plane, which fills the frame whatever the subject
does. The fix renders twice: once with the ground hidden, to measure; once
with it, for the picture, because contact with the floor is part of what the
shot is for.

Corrected, the bench and the arithmetic agree independently — melee
concepts measure 41–46 px at 18 m against a derived 48; Check concepts 39–41
px at 30 m against a derived 47 for a full-height 2.6 m object, which scales
to 39–40 for the 2.16–2.23 m builds. **Two instruments built from different
inputs landing on the same number is the only reason either is trusted.**

### L-18 · A filter that cannot express failure only reports success
The bench reported *"materials forced to NEAREST: 0"* — which reads as a
pass and is identical to what a walk that found **no materials at all**
would print. It now prints the full filter histogram and says loudly when it
found nothing.

The runtime result, once it could be trusted: the GLTF runtime loader
**does** honour the NEAREST sampler written by Blender's `Closest`
interpolation. The **editor** import path is a different code path and
remains untested — see `ART_FRONTIER.md`.

### L-19 · …and the same mistake, inverted
`tools/sabotage_checks.sh` reported *NOT CAUGHT* for the `speckle` guard.
The guard was working perfectly: it enforces its structural zone by
**requiring the argument**, so it raises `TypeError` — and the harness only
caught `AssertionError` and `ValueError`. A harness that cannot recognise a
guard firing is the same class of mistake as a filter that cannot express
failure.

### L-20 · The owner's ledger is the one place a wrong number is invisible
`ART_REVIEW.md` and `ASSET_INVENTORY.md` quote a triangle count and a
measured size for all twenty-eight assets, both transcribed by hand. A wrong
figure there is worse than a wrong asset: everything else has a build that
would notice, and the ledger has only the person reading it.

`tools/blender/check_docs_metrics.py` parses the tables and compares every
number against the manifests. On its first run it caught two —
`prop_terminal` at 1.40 m against a built 1.41, `prop_debris` at 0.59
against 0.58. Small, and exactly the class of thing that never gets caught
by looking.

> *Do not narrate a result you have not read* has a mechanical form: have a
> machine read it and compare.

### L-21 · A restore-with-`git checkout` script eats uncommitted work
`tools/sabotage_checks.sh` restores every file it sabotages with
`git checkout --`, which reverts to **HEAD** — so it silently discarded a
two-line correction to `ASSET_INVENTORY.md` that had been made and not yet
committed. The next run then failed its own clean-tree baseline on numbers
the author had already fixed, which reads as the check being broken rather
than as the check having eaten the fix.

It now refuses to run against a dirty tree, the same way
`check_art_current.sh` does. **A tool that restores state must say what
state it will destroy.**

### L-22 · Generated assets go stale in silence
A model is built by one command and its review sheet by another. A pass that
runs only the first leaves every sheet describing an object that no longer
exists, and **nothing fails**: the build is deterministic, the checks are
green, and the assets are simply older than their source.

`tools/check_art_current.sh` rebuilds everything and fails on any
difference. On its first run it caught four manifests that predated the
`anchor` field — and confirmed, in the same pass, that every `.glb` rebuilds
byte-identical.

### L-23 · Guards find real bugs, not just hypothetical ones
`assert_fits` was written on the principle that collision truth is Godot's.
Within one session it caught **four** real overruns: a debris pile 256 mm
past `PROP_FOOTPRINT`, a blast-door portal 220 mm wider than the narrowest
corridor `zone.py` permits, and two enemies outside their collision box. All
four would have clipped through walls the character body never touches.

---

### L-33 · A verifier scoped to today's directory agrees with tomorrow's mistake
`check_docs_metrics.py` walked `assets/models/batch001` only. The first
batch002 asset it met was reported as *"quotes metrics for an asset no
manifest contains"* — eleven failures, all of them the checker saying the
document was wrong when the checker was the thing that had not moved.

The danger is not the false alarm. It is the obvious way to silence one: add
the row to an ignore list, and the check quietly stops covering a whole
batch. `sync_inventory.py` had the same shape and the same fix — both walk
every batch now.

> A verifier that has to be edited whenever the work grows is a verifier
> that will one day be edited into agreeing.

### L-34 · A bench that frames by assumption labels the wrong figure
The family sheet placed its role labels from each figure's world X using
`half_extent = distance × tan(fov/2)`. Godot's `Camera3D.fov` is the
**vertical** angle when `keep_aspect` is KEEP_HEIGHT, which is the default,
so the horizontal extent is that times the aspect — and every label landed a
third of a frame from the figure it named. The style board made the same
mistake in the other axis, putting all six names in a straight line well
below objects of six different heights.

Both are fixed by asking the camera: `unproject_position` is the only thing
in the scene that actually knows where something drew.

> A label under the wrong figure is worse than no label. Derive positions
> from the camera, never from a formula about the camera.

### L-38 · Do not measure a frame you have already written on
The Epsilon value read is the operator frame desaturated. It was derived
*after* the operator captions were drawn, so the value caption landed on top
of them and both became unreadable — and, worse, the caption pixels went
through the luma conversion as if they were part of the render.

Capture, then derive, then caption. A caption is not part of the render and
must never be measured as if it were.

### L-41 · A bench that is hard to aim is a bench that gets aimed once
Six review scripts, every camera written into GDScript as a pair of raw
`Vector3`s and a 90 degree fov. Moving one camera 40 cm meant editing a
source file and re-running a render, so in practice cameras got placed once
and lived with. Batch 002 spent more wall-clock on `look_at_from_position`
arithmetic than on modelling, two benches computed screen positions from a
formula about the camera instead of asking it (L-34), and the one lens
anybody ever used was the game's.

`camera_rig.gd` and a JSON shot list fixed the cost, and the first thing
that happened afterwards was L-40: a shot nobody had bothered to take,
because taking it had been expensive.

> Cheap iteration is not a convenience. It changes which pictures get
> looked at, and the pictures nobody takes are where the bugs live.

### L-44 · Do not caption a pixel count you have not counted
The far-read sheet went out captioned `MAST 35 PX`. 35 is the number in
`art_budgets.json`, and it is correct — for the 2.6 m **collision box** the
budget derives from. The mast as built is 2.22 m, which at 39.6 m on a 90°
vertical fov and 1080 lines is **30 px**. The ring was captioned 30 and is
26. Both numbers were quoted from the right document about the wrong object.

The arithmetic is four characters wide — `1080 * h / (2 * d * tan(fov/2))` —
and it took longer to write this entry than to run it.

> A number copied from a budget is a claim about the budget. A number about
> the render has to come from the render, or from the render's own geometry.

### L-45 · An offset in a frame the renderer flips reverses the caption
`shoot.gd` yaws every loaded model 180° so an authored front faces the
camera. The new multi-model offsets were applied in world space, so
`@-1.2,0,0` — "1.2 m to the left" to anyone writing a shot list — put the
model 1.2 m to the viewer's **right**. The four Check states rendered in
reverse under a caption naming them left to right, and the picture looked
entirely plausible: four states, four positions, nothing missing.

The offset now goes through the same yaw as the model, so the shot list
means what a person arranging four models on a shelf means.

> A convention that is right for the geometry and wrong for the caption is
> the kind of bug a render cannot show you, because both halves look fine.


### L-47 · `global_position` is zero for a node added this frame
`shoot.gd` sized a multi-model scene with
`AABB(node.global_position + box.position, box.size)`. For the FIRST scene
of a run, every model after the first reported a box at the origin: the
root had just been created and never processed, so the global transform had
not propagated and `global_position` was still `(0, 0, 0)`.

The union came out one Check wide instead of four, `frame()` solved a
distance for that, and the sheet was a perfectly well-composed photograph of
**two** of the four states it was captioned as showing. Nothing errored.
Nothing looked broken. The second scene in the same run was fine, because by
then a frame had passed — so the bug was invisible in exactly the shot that
mattered and absent from the one next to it.

`node.transform * aabb` is the fix, and it is the better call anyway: the
runner yaws every model 180°, so a local box's corner is not its world
corner until the transform is applied.

> A value that is correct on the second frame and wrong on the first will
> be wrong exactly once per run, in whatever you built first.

### L-48 · Measure the channel before designing into it
Batch 005-R needed one non-hue cue separating the Check's locked state from
its confirmed one at 39.6 m. The obvious place was inside the mast's caged
head, so that is where the first attempt went: a shutter descending the
cage uprights onto the spent husk. Good object, wrong place —

> at 39.6 m the cage interior is **5 pixels tall**.

Filling all five moved the cage box from 58% background to 48%. The second
attempt put the cue outside the cage, where there is width instead of
height, and the same measurement gave 43% against 16%.

The whole difference between the two attempts is that the second one asked
how big the canvas was first. Counting the pixels took one script; building
the wrong shutter took an hour.

> Before designing a cue, measure the region it has to live in. A channel
> five pixels tall is not a channel.


### L-49 · The bench's own backdrop can be inside the thing you are shooting
Every model shot stands on a floor slab with a wall behind it at z 1.55.
That is right for a single object and wrong the moment a scene is
**composed**: a six-module corridor run reaches past 1.55 in Z, so the
bench's wall stood in the middle of the junction, two storeys tall and
painted the same institutional grey as everything else.

It did not read as a bug. It read as a wall the module was supposed to
have, and three camera moves were spent trying to find an angle where the
junction "opened up".

`backdrop` is now `"full"` / `"floor"` / `"none"` per scene group.

> A prop the bench provides is invisible as an error, because it looks
> exactly like a prop the asset provides.


### L-51 · A number the render contradicts is worse than no number
`shell_corridor_bays` shipped with `sightline: 6.4` because the docstring
argued that alternating recesses make a corridor you weave down. The entry
render shows all 16 m of floor: a recess in the side of a straight lane is
**cover, not occlusion**, and the reasoning had never been checked against a
frame.

The damage was not aesthetic. `sightline` is one of the semantic keys the
shell manifests exist to give `zone.py`, so a wrong one is a lie the runtime
would have consumed silently — worse than the empty §7 it replaced, because
an absent key is obviously absent.

The fix was to redefine the key as something checkable — *how far down the
run the floor stays visible from the entrance at eye height* — and let the
asset's justification move to the axes it actually serves. Every shell
number is now verifiable against its own review image.

> If a manifest key cannot be checked against a render, it is a mood word
> with a colon after it.

### L-52 · The camera lives in world space; the model does not
L-45 caught this for model *offsets*. It came back for camera *positions*,
because the shot runner yaws every loaded model 180° and leaves the camera
alone: an `eye` copied straight out of a manifest anchor lands mirrored
through the origin.

Two shells were photographed from out in the void, looking at the corridor
through its own entrance, under the captions "ON THE GALLERY" and "FROM THE
HIGH HALF". Both frames were plausible — a small, well-lit corridor in the
middle of grey — and neither was where it said it was. Any `eye` meant to
stand *inside* a shell must negate the anchor's x and z.

> The same coordinate flip will keep coming back until every frame that
> quotes a manifest position does the conversion in one place.

### L-53 · A pocket 1.6 m deep has no interior camera
Three attempts were spent trying to photograph "standing in a bay, looking
back down the lane". Every one hit a wall, because the geometry says so: a
bay 1.6 m deep by 2.8 wide has a view cone out of it barely wider than the
opening, and a game lens cannot widen it.

That is not a camera failure, it is the shape being true. The shot was
reframed to the approach — where the pocket reads as a pocket — and the
narrowness went into the write-up as the family's weakest read instead of
being hidden behind a fourth camera move.

> When three camera moves fail on the same object, stop moving the camera
> and write down what the geometry is telling you.


### L-54 · A measurable number can still be the wrong measurement
L-51 replaced an asserted `sightline` with one a render could be checked
against. The arenas got the same treatment and it still was not enough:
`open_floor` -- how much of the plate has nothing standing on it -- is
honest, cheap, sampled off the real footprints, and reads 0.92 to 1.00
across four rooms that play completely differently. Sixteen columns eat 8%
of a 22 m arena and change every fight in it.

The fix was not a better number for the same question. It was noticing the
question was wrong: what matters is not how much plate a shell gives back
but **how much of it has cover within reach**, at the distance a brute
closes. That reads 0.000 / 0.338 / 0.521 / 0.786.

`open_floor` stayed, because it is the engine's own rule (*crates hug the
walls so the arena floor stays fightable*) made checkable, and a number
that proves a constraint is held is worth keeping even when it does not
discriminate. It just is not the one that describes the family.

> Verifiable is a floor, not a ceiling. Ask what the number is FOR before
> being pleased that it is measured.

### L-55 · Build a trim to the surface it trims
Every column in the arena grid got a base collar centred on 0.30 and a
capital centred on `height - 0.30`, which left both floating 0.15 m clear
of the floor and the ceiling. In flat grey at this value range that does
not read as a gap; it reads as a collar hovering in its own shadow, and
sixteen of them read as the whole grid being wrong somehow.

The same slip put the pit's rim a step ABOVE grade instead of the pit a
step below it -- which would have raised both doorways one metre over the
corridor chaining into them. A chamber that does not meet its neighbour's
floor is not a chamber.

> A part defined by its centre is defined relative to nothing. Anything
> that touches a surface should be positioned from that surface.


### L-56 · The bench rig is built for an object, not for a room
Every review render for fifteen batches used one three-light setup: key
well above fill, rim carrying the silhouette, subject standing on a
backdrop. It works because the key clears the model and dies on the floor.

A room the size of the rig's own scale does not behave that way. Corridors
survived it -- their ceilings occlude the key -- but an open-topped shell
does not: the first platform-path render put the key square onto the
right-hand wall and returned pure white across a third of the frame, with
the route a dark smear in the middle of it.

The fix was a knob, not a workaround: `key_energy` is a scene-group option
alongside `ambient`, defaulting to the value everything already used so no
existing sheet moves. Arenas and paths shoot at 0.70.

> A tool that has been right fifteen times is not thereby right. Ask what
> it assumes, and whether this subject still meets the assumption.

### L-57 · At a 90 degree lens the frame starts 1.6 m in front of you
Three platform-path shots were composed from the lip of the start ledge,
looking down the route -- the natural place to stand. Every one rendered
the ledge as empty grey: at the engine's fov the bottom of the frame is
about 1.6 m ahead of the camera, and the ledge ended 0.6 m ahead.

It read as a camera floating in a void, which is a very different picture
from a player standing somewhere about to jump. Moving 2 m back put the
ground under the viewer and the gap where it belongs.

> A frame that shows no ground shows no scale. If a shot is meant to say
> "you are standing here", the standing has to be in it.


### L-58 · Measure the route from where the player stands
`routecheck` reported a worst mandatory jump of 1.93 m against a 2.00 m
bound for all three tower shells -- alarming, and false. It measured from
the entrance DOORWAY, and a tower's ground floor is a full 12 x 12 slab:
the player walks under the first platform and steps up. From the ground the
same geometry reads 0.800, 1.700 and 0.100.

Nothing about the shells changed. What was wrong was the check's idea of
where a route begins, and the failure mode is the nastier direction of the
two: a number that cries "nearly illegal" about a step nobody has to make
trains you to ignore it, and the run where it means something looks the
same as the runs where it did not.

> A guard that is wrong in the safe direction still costs you the guard.

### L-59 · A check earns its keep the first time it refuses something
The same module refused `shell_tower_collapsed` outright: the surviving
half-floors alternated left and right, which put a 3.60 m crossing between
them. Unfinishable with the base kit, and invisible -- from every camera it
looks like two floors with a gap, and a gap is what a tower is supposed to
have.

That is the whole argument for a rule expressed as executable geometry
rather than as a paragraph in a design document. The paragraph would have
been read, agreed with, and not applied.

It is also why the module is now shared rather than copied into each
builder. Two authored families disagreeing about how far a jump reaches
would be worse than not checking at all: it would look checked.

### L-60 · Any oblique from outside a walled room photographs the outside
Three tower overview shots were placed 7 m in front of the shaft at 16 m
up, pitched down 48 degrees -- a natural three-quarter view. Every one
returned the OUTSIDE of the box, because a tower's walls are as tall as the
tower: the sight line met the entrance wall four metres below its top.

An open-topped room only opens upward. The camera has to be over the hole,
not beside it -- these are at pitch -72 above the shaft centre.

> "Above and in front" is a view of a model on a table. A room is not on a
> table; it is the table.


### L-61 · When the render disagrees with the caption, suspect the caption
`shell_corner_left` rendered with its exit on the RIGHT of frame. The
obvious explanation was the runner's 180 degree model yaw -- it mirrors
everything, it has caused this before (L-45, L-52), and the fix looked like
a camera change.

It was not. `corner(+1)` exits through the +X wall; `zone_builder._rot`
maps +Z to +X under a +90 degree yaw; and in Godot a node facing +Z has
been yawed 180 degrees so its right is world -X, which makes +X the
player's LEFT. `corner(+1)` turns left, `corner(-1)` turns right, and the
two shells had been named the other way round. The mirrored render was
telling the truth about geometry that was wrong.

Three previous lessons about the same 180 degree yaw made the wrong answer
the easy one to reach for. A known failure mode is a hypothesis, not a
diagnosis.

> The camera had been guilty three times. That is exactly why it was worth
> checking whether it was guilty a fourth.


### L-62 · `frame` cannot miss the subject; a hand-placed camera can
One review shot took five attempts. A four-model row 17 m wide, framed at
0.72, came back with every part small and far -- `frame` fits an AABB and a
long flat subject makes it pick the wrong axis. Staggering the row into two
rows of two fixed the size and hid the column behind a wall. A hand-computed
`look` then missed the subject almost entirely and returned a picture of the
horizon.

What finally worked was two shots of two parts each: small AABBs, nothing
occluding anything, and a solver with an easy job.

The general rule is about which camera to reach for. `frame` and `orbit`
solve their own distance from the subject, so the subject is in shot by
construction; `eye` and `look` are positions someone worked out, and an
arithmetic slip in either produces a plausible photograph of nothing. Use
the solving cameras for objects and the placed cameras only when the point
of the shot IS where the viewer stands.

> Prefer the camera that cannot be wrong to the camera you can reason about.

### L-63 · A part that is a hole cannot be photographed standing on a floor
`arch_floor_grate` is a recess: bars over a 0.30 m void, anchored
`module_floor`. Every model shot stands its subject on the bench's floor
slab, so the recess sank into the slab and three separate sheets showed a
rim and a few dark scratches. Nothing was wrong with the asset.

`backdrop: "none"` fixed it in one attempt, and the grate is now legible
enough to count the bars.

> The bench provides a floor. An asset that IS the floor has to be given
> nothing to stand on.


### L-67 · Put the mount height in the manifest, and the fit failure shows up
Batch 022's panel was authored above its doorway. `common.measure` says
nothing about where an asset sits, so the builder was changed to record
`authored_top_m` and `authored_bottom_m` — and the manifest immediately
read 4.03 m for a module that has to live under `corridor_height` 3.60.
`door_height` is 3.20, which leaves 0.40 m of wall above a doorway: not
enough for any legible plate. The panel moved beside the jamb.

The related trap in the same batch: exporting those signs with the `wall`
anchor silently re-bases Z to the geometry's lowest point, so an authored
2.60 m head became 0.00 and the whole family rendered on the floor. That is
L-19's ceiling-bay failure again in a new costume, and the fix is the same
one `set_origin` already documents — `module_floor` for anything whose
height is part of what it is.

> A number an asset is designed AROUND belongs in its manifest. A
> dimension nobody records is a dimension nobody can check.

### L-68 · A content field's centre is not the object's centre
`nav_blade` carries its bracket on -X, so `set_origin(module_floor)` centres
the whole mesh and leaves the pale text field 0.155 m to the +X side of the
origin. Every review sheet placed the runtime `Label3D` at the object
position, which put the word 0.155 m left of the field it was supposed to
sit inside -- overrunning the frame at one end.

It survived several passes because it never looked like a bug. It looked
like the text was slightly too big for the sign, which sent the first
instinct after font size instead of after position.

The builder now measures the vertices carrying the face material and
records `face_centre_x_m`, `face_width_m`, `text_usable_width_m` and a
character budget.

> An asset that hosts CONTENT owes the content a frame of reference. Where
> the field is, how wide it is, and how much fits are facts about the mesh,
> and a renderer that has to infer them will infer them wrong.

### L-69 · Shoot an asset from the side the player meets it from
The first `R_duct_run` was aimed at +10 degrees elevation and rendered the
TOP of two ceiling bays, with the ducts hidden underneath. Every number was
right: the models loaded, the grid lined up, the camera framed its subject.
It was a photograph of the one side of a ceiling nobody will ever stand on.

L-63 is the neighbouring rule -- do not give a floor to a thing that is not
on a floor -- and this is the other half of it. Getting the backdrop right
does not save a camera that is on the wrong side.

> Before framing, ask where the player is standing. A ceiling service is
> seen from below, a floor grate from above, a doorway from the approach.

### L-70 · The builder knows where to stand; say so in the manifest
Batch 023's six landmarks are places -- a hall, an interchange, an
undercroft. The review sheet framed each from outside, solving a camera from
the asset's bounding box, and rendered six boxes with a wall facing camera.
Every one was correct: right model, right scale, right lens. The place was
behind the wall.

A bounding box cannot say where the hero feature is or which way a player
would face when they met it. The builder can, because it just placed it. It
now records `eye_from` and `eye_at` per landmark, converted to Godot axes,
and the sheets read them.

This is L-67 and L-68 again at a larger scale -- the mount height, then the
text field centre, now the viewpoint. The pattern is worth naming:

> Anything a renderer would otherwise have to GUESS about an asset is a fact
> the builder already knew and threw away. Put it in the manifest.

### L-71 · A landmark you walk around is a prop at landmark scale
The first Batch 023 pass built six large objects, each standing alone on a
floor: a ladle, a bell frame, a shaft. They were reasonable objects, they
passed every check, and they were the wrong deliverable. The brief was
"the Zone with the giant ___", and that sentence is a memory of a PLACE.

What was missing was not size. It was the architecture around the object --
a route at ground level, a route above it, somewhere to look down from, and
something visible you cannot reach. The second pass kept most of the hero
shapes and built the place around them, and the difference is not subtle:
the first sheet reads as a product catalogue, the second as somewhere you
have been.

### L-72 · An audit is only as current as the branch it ran against
Batch 023's contract audit was the most rigorous thing in the batch. It
searched before modelling, published its `grep`, refused to invent a
contract, and reached a confident conclusion: *"`godot/scripts/` references
no `.glb` and reads no manifest; the entire authored pipeline is unwired."*

Every clause was false. The search ran against `claude/archipepsi-build-inzshp`
-- the art lane's BASE -- which was 73 commits behind Production. Production
had already built `ContentRegistry`, `ContentInstantiator`, the shape
authority in `schemas/content.py`, and a registered L4 `landmark` category.
The audit was reproducible, honest, well-documented and pointed at the past.

Worse than being wrong, it was wrong in the direction that costs most: it
told Production to build something it had already built, and it flattened a
real, narrow, actionable gap (no `.glb`->`res://content/` step, no
`landmark_id`, no landmark envelope) into a vague large one.

> The art lane's base branch is not the project. Before publishing any
> finding about what the engine does or does not have, audit the CURRENT
> Production head by name, and say in the finding which ref you read.

### L-73 · Two systems can use the same word for different things
`grep -rn "landmark"` over Production returns 26 hits. Nineteen of them are
`composition.LANDMARK_RATIO` and `epsilon/fallback.py`, where "landmark"
means **the biggest ROOM in a Zone by content value** -- `landmark["width"]
= 26.0`. That has nothing to do with the L4 asset category of the same name.

Counting hits made the asset category look better-supported than it is, and
would equally have hidden it among noise. A word is not a contract; the
declaration is.

### L-74 · An id is the ledger's key, so reusing one redefines approved work
Batch 030 built ten enemy roles and named them `enemy_charger`,
`enemy_bulwark`, `enemy_scuttler` and so on -- the obvious names. Seven of
those ids were already owned by Batch 002, and Batch 002 is `PASS`.

Nothing overwrote anything on disk: the files went to
`batch030/enemies/` and Batch 002's are in `batch002/enemy/`. But
`check_docs_metrics` matches on the ID, not the path, so it read the new
build's numbers against the approved rows and reported the approved assets
as wrong. A silent version of that would have been worse: the ledger would
have quietly started describing a different object under a name the owner
had already signed off.

> Before naming an asset, check whether the id exists. Directories do not
> namespace a ledger keyed on ids, and an approved id is not a free name.

Renamed to `enemy_role_*`, which also says what they are: built to the
published `ENEMY_ENVELOPES` box rather than to a concept sheet.

### L-75 · Verify a blocker before repeating it
`ART_FRONTIER.md` said seven of the ten enemy roles "wait on colliders
(req 7)" and the telegraph waited "on a node that does not exist (req 14)".
Both had been true. Both were false by the time Batch 030 read them:
`ENEMY_ENVELOPES` publishes all ten envelopes, and `enemy.gd` carries
`telegraph_started` / `telegraph_finished` / `telegraph_progress()` and a
`telegraph_origin` marker.

The frontier is the file that exists so a wake-up does not have to re-derive
the state -- which is exactly what makes a stale entry in it expensive. A
blocker recorded once and never re-checked stops being a fact and becomes a
habit. This is L-72 again from the other end: that lesson was about auditing
the wrong branch, this one is about not auditing at all because the answer
was already written down.

> A hero shape plus a floor is an object. A hero shape plus the routes that
> let you be above, below and around it is a place. Only the second is
> remembered as a location.

## Process

### L-39 · Four batches to lock a style, and every one of them was cheap
Style Lock took 001, 001-R, 002 and 002-R. It is worth writing down what
that actually cost, because the instinct at the start was that fewer, bigger
batches would be faster.

Every round was one build and one render away from the previous one. The
expensive thing was never the geometry — the Epsilon installation is 1,644
triangles and rebuilds in eight seconds. The expensive thing would have been
**producing at scale against an unapproved language**, and none of that
happened, because the gate held through four rounds of "not yet".

Each round also moved a rule out of somebody's head and into a file:

| Round | What the owner had to say out loud, once |
| --- | --- |
| 001 | The facility and Epsilon are two civilisations. |
| 001-R | Cold room, warm pools — not a warm room. |
| 002 | Epsilon is an installation, not a shrine. |
| 002-R | And a machine somebody *operated*. |

None of those were guessable, and all four are now `ART_BIBLE.md` §1z.

> A style gate is not a delay before production. It is the thing that makes
> production reusable, and it costs a render each time.

### L-25 · …and that applies to check output, not just renders
At the 05:45 heartbeat this lane reported "working tree clean, in sync, base
branch unchanged, and all three cheap verifiers still pass" — having run
none of them. The state turned out to be exactly that, which is the
dangerous part: a claim that happens to be true is indistinguishable from a
claim that was checked, and the whole reason this lane's numbers are worth
anything is that they were checked.

L-24 was written about renders. It is the same rule for a terminal: **if a
sentence names a result, a tool call has to have produced it in this turn.**
A heartbeat that skips the check and reports the expected answer is a
heartbeat that has stopped being a check.

### L-76 · A visibility floor is not a recognition floor

`min_feature_fraction` (0.08 of the object) and `min_feature_screen_px` (2 px
at the judging distance) are derived, reasoned numbers, and both were
satisfied by the 6 cm grips that made `int_carryable` indistinguishable from
`dec_crate_fixed` at 4.5 m — 6 cm is about **seven** screen pixels there.

> Two pixels is enough to see **that a form exists**. It is nowhere near
> enough to tell **which form it is**.

Those are different questions and they need different floors. The rule that
answers the second one is not a size at all:

> **A tell that has to survive gameplay distance must change the object's
> SILHOUETTE, not its surface.**

Surface is what distance takes away first. An outline is the last thing to
go. A grip on a face is surface; a bail you can see through, and a gap of
light under a crate, are silhouette.

And its corollary, which the silhouette sheet caught within one render of
being written: **a cavity in a front face is not a hole.** The first revised
key receiver had an open throat closed by a lintel, and from any angle where
you could not see *into* it, it and the welded hatch were the same dark slab.
Opening the top turned the head into a fork — a notch in the outline itself,
which is the only kind of hole a silhouette can carry.

### L-77 · The camera is part of the experiment, not part of the plumbing

Sheet C of 037-R clipped a hovering drifter out of frame. The fix — scale the
standoff with the tallest thing in the panel — worked, and silently destroyed
the sheet: **a surface comparison shot from five different distances is not a
comparison**, because distance is the exact variable a surface test measures.

The same mistake is available in any evidence sheet: fixing a framing bug by
changing the thing being controlled for. Fix framing by changing what the
framing is *sized from* (here, one distance derived from the widest pair,
with a vertical pan for the tall ones), never by letting the control vary.

A second, smaller trap in the same fix: **at a three-quarter azimuth an
object's screen width includes its depth.** Sizing the frame from envelope
width alone ran a 1.8 × 1.8 m brute — 2.24 m wide on screen — off its own
left edge.

### L-78 · A suppression test leaks wherever the suppressed cue has geometry

Sheet A of 035 was solvable by spotting cyan. Sheet B suppressed the plate's
emission and was the real test — until 035-R gave the plate a **bezel** so it
would survive greyscale, as the owner required. The bezel is *body* geometry,
it cannot be suppressed at render time, and no decoy has one, so sheet B
became solvable by "find the bezel": the same defect, one layer down.

> Suppressing a channel only tests the remaining channels if the suppressed
> cue leaves **nothing** behind.

The complete suppression is a **silhouette**: flat black on a lit backdrop
has no material, no emission, no bezel and no colour. If a distinction
survives that, it is structural. If it does not, no amount of suppressing
individual channels will prove it was.

### L-79 · A rename travels further than the thing being renamed

L-74 renamed Batch 030's enemy ids to `enemy_role_*` to stop them redefining
Batch 002's approved assets. The rename also swept a table in the **Batch 002**
section, leaving Batch 002's measurements sitting under Batch 030's ids —
seven rows that described one set of assets while naming another.

Nothing caught it for a whole review cycle, because `check_docs_metrics`
accepts a match *anywhere*: the correct Batch 030 ledger satisfied the check,
so the wrong table was never consulted. A verifier that passes on the first
match cannot tell you the second one is a lie.

> After a bulk rename, grep the **old** name and the **new** one, and read
> every section the new one landed in.

### L-80 · Verify every side of a contract that has more than one

The authored-content manifest is policed by two files in two languages, and
they do not police the same things. `content_registry.gd` asks whether a
scene exists and whether a fallback chain terminates. `schemas/content.py` is
a strict pydantic model: `extra="forbid"`, and `MAX_TEXT_LEN` is 160.

The first content pack was checked against the GDScript half, reported as
verified, and handed over. Production's Python gate rejected it on three
counts — a 231-character description, and two fields (`source_asset`,
`source_batch_review`) that `ContentEntry` forbids outright — and the
integration stopped.

> **Verifying one side of a two-sided contract is verifying nothing**, and it
> is worse than not verifying, because it produces the word "verified".

The rule is not "run more checks". It is: **before claiming a generated
artifact conforms, enumerate every consumer that validates it, and run all of
them in one command** — so a future pack cannot be handed over having
satisfied only the convenient half.

The narrower lesson, which cost the same defect twice: **provenance is not
part of a contract.** `source_asset` and `source_batch_review` were useful
art-lane bookkeeping smuggled into a schema that had no field for them. The
schema was right to refuse. Bookkeeping goes in a document beside the
artifact, not inside a contract that something else validates.

And a third, found while fixing the second: **the GDScript check had been
passing for the wrong reason.** It resolved `ContentRegistry` through a stale
`.godot` class cache holding a registration from an earlier harness copy; the
next `--import` rebuilt the cache and it stopped compiling. A green check that
depends on a cache is not evidence. It preloads by path now.

### L-81 · Declare the movement that was measured, not the one that is easy

The P2 retrofit derived each tower's traversal segments from `stones`, the
same list `routecheck.assert_reachable` had already validated. It then wrote
the segment endpoints at the surface **centres**, because that is the number
sitting in the variable.

`routecheck.jump_distance` measures **edge to edge**. The preflight caught it
at once: a spiral's last platform to its deck came out as a 6.59 m jump
against a 2.60 m base-kit reach, when the two footprints overlap and the
crossing is a step. Every tower would have shipped a mandatory route
declaring a movement no player could make — and `ShellValidator` measures
marker to marker, so it would have refused all three.

> **Deriving a field from the right variable is not the same as deriving it
> the right way.** If a validator already measures the thing, use its measure,
> not a different one over the same data.

The general form, and the reason this was cheap to fix and would have been
expensive to ship: the contract and the checker have to agree on what a
number MEANS, not merely on where it comes from.

### L-82 · A rule written for props was read as a rule about everything

`docs/art/ASSET_AUTHORING.md` §5 opened with **"The art lane does not author
collision."** It was true, and it was about props: the engine already has a
collider for a light housing, and what the art lane owes is an asset that
fits inside it.

Room shells are not placed inside a room. They ARE the room, and there is no
engine collider waiting for them. `ART_ASSET_SPEC.md` §3 had always said so
in the opposite direction — author collision, never auto-trimesh anything a
player touches — and the two sentences sat in two files for the whole of the
F3 shell work without ever being read side by side.

The bill arrived at Production's `eda4fd9`: eight shells integrated, all
eight NOT MEASURABLE, 625 audit findings, every one of the "nothing is there"
class. Zero structural violations — the metadata was immaculate and
describing a room that physically was not present.

> **A rule that names a category ("props") gets applied to the lane.** When
> the lane later builds something from a different category, nobody rereads
> the rule, because it does not feel like a rule that could stop applying.

**It had been written down three times, and fixing two of them was not
enough.** After the doc and the shells themselves came `verify_pack.gd`,
which asserted *"carries N collision object; hitboxes are engine-owned"*
against all seventeen entries and refused the eight shells the moment they
were given the collision they had been missing. Production's own
`ContentInstantiator` had never said that: it refuses a light on a **light
housing** and refuses collision on a **projectile visual**, in two separate
functions with two separate reasons, and says nothing of the kind about
room shells. The art-side check had generalised both into one lane-wide
law. The third site was found by running the checker, not by reading it —
which is the argument for having one.

What made it cheap to fix is the part worth copying. Every piece of all eight
shells is a `brushkit.block` and every piece is already painted with one of
four roles, so the collider is a COPY of the piece and the role decides
whether it gets one. Nothing new had to be declared per shell, and the
answer cannot drift from the geometry because it reads the same argument
that chose the texture.

### L-83 · The engine is the authority even when your own arithmetic is right

The source-side probe mirror in `roomcollision.measure_probe` reproduces
`RoomAudit`'s downward ray as arithmetic on boxes the build script placed.
Twice it disagreed with the real engine, and both disagreements were
instructive rather than embarrassing.

**First it under-reported, silently.** Blender stores coordinates as float32,
so a face built at exactly 0.80 reads back as 0.80000001 — a hair ABOVE the
ray's start point, which emptied the probe window and reported three plinths
clean while Godot was finding all nine samples on them. A tolerance three
orders of magnitude below `HEIGHT_TOLERANCE` fixed it.

**Then it over-reported, honestly.** With the tolerance in, a treasure room's
`floor` centre sample grazes the plinth's lower step — the occluder's top
face exactly level with where the ray begins. Godot does not register that
contact. One tier up, `step_low` against the upper step, the same
relationship, Godot DOES. No arithmetic reproduces that; it is the engine's
own grazing behaviour.

> **When a source-side check and the engine disagree about a coincident
> face, do not tune the check until they match.** Label the case, report it,
> and let the engine decide. Over-reporting a graze is the safe way to be
> wrong; under-reporting is what left eight shells unmeasurable.

### L-84 · Repair the piece that has no external claim on it

Production measured three "geometry defects" across two towers:
`shell_tower_collapsed`'s last two rubble rungs and `shell_tower_spiral`'s
`platform_6`, each offering nowhere a player could stand. Three findings,
two shells, two apparently unrelated climbs.

One cause. The top deck is a 0.50 m slab at `rise` across the back 4 m of
every tower, and both climbs pass under it on their way up. A rung below
it has `rise - 0.50 - h` metres of headroom and no more.

The instinct is to move the climb, because the climb is what failed. The
climb is the one thing that could not move:

* the spiral's `inset`, `margin` and `spacing` are `tower()`'s OWN
  numbers, chosen so an authored spiral climbs the same helix a
  procedural one does and a Check placed against either lands in the same
  place. Art does not own them.
* the collapsed tower's alternating half-floors ARE that shell -- and an
  earlier version that alternated left/right was refused by `routecheck`
  for a 3.60 m crossing, so the current arrangement is already the
  answer to a measured question.

The deck was neither. It was art's own slab, added by a shared helper
without regard to which half of the shaft the top climb used. So the
repair went there: `_deck_well` cuts the deck out of the column the climb
comes up, derived from the same `stones` and `heights` that become the
Surfaces.

> **When two things collide, look for the one with no external claim on
> it.** Engine-mirrored constants, an owner-approved silhouette and a
> `routecheck` verdict are all claims. A helper nobody has ruled on is
> where the give is, and it is usually where the mistake was.

It also turned out to be the better room. A deck that stops short of the
shaft is what a stairwell opening and a collapsed floor both actually
look like; the fix reads as more intentional than what it replaced.

### L-85 · A derived position still has to ask what is already there

`shell_tower_collapsed`'s `high_3` enemy socket was the centre of the
surface it names -- derived from the same variable that placed the
geometry, which is the rule this lane wrote down after the axis trap and
believed it had internalised.

Consecutive rubble stones overlap in plan. The centre of `rubble_0_0` is
0.05 m inside the slab of `rubble_0_1` above it, so the socket was buried
in the next stone up, and no amount of deriving it from the right
variable was going to notice.

> **Deriving a value from the right source is necessary and not
> sufficient.** A POSITION also has to be checked against the geometry
> that is already there, by the same search the consumer will use.

The fix is `stance_spot`, which runs `Placement`'s own candidate search
and returns the clear spot NEAREST THE CENTRE -- so every socket whose
centre is already fine does not move at all, and the ones that move are
exactly the ones that were wrong. Two sockets moved, both by 0.225 m.

### L-86 · The bench is not the importer, and it had been lying for a slice

Every shell frame rendered after P2-C came back blown out and untextured.
The first reading was that the new cameras were wrong — they were pointing
at walls, or the lighting was tuned for the F3 shots and not for
interiors. Two rounds of camera arithmetic went into that reading and none
of it helped.

The cameras were fine. `ArtBench.load_glb` calls
`GLTFDocument.append_from_file`, which is **not** Godot's scene importer.
The importer reads a node named `foo-convcolonly` and turns it into a
`StaticBody3D` with no mesh. A raw glTF load gets a plain, material-less
`MeshInstance3D` sitting exactly on top of the geometry it was copied
from. Measured: `shell_tower_collapsed` loaded as 22 `MeshInstance3D`s —
one real mesh and **twenty-one untextured white duplicates**.

The bench had been photographing the colliders.

> **A pipeline that loads an asset by a different route than the game does
> is a second importer, and it owes the same contract.** Anything the real
> importer strips, renames or converts, the loader has to strip, rename or
> convert too — or the review sheet is of a different object than the one
> that ships.

What made it findable was re-rendering the OLD shot list and diffing
against the committed images. A shot list that has already shipped is a
regression test for the bench, and it cost one command to run. After the
fix, all eight `batch019` captures reproduce **byte-identical** to the
images committed at F3 — which is also, for free, the proof that the
treasure rooms and corners are visually untouched.

### L-24 · Read your own render before writing down what it shows
Every fix in L-05, L-08, L-09, L-11, L-13 and L-14 came from **looking at
the image**, not from the build log. The logs were green throughout: correct
triangle counts, exact texel densities, every assertion passing. The
concrete wall was static, the enemies were camouflaged, the ceiling beams
were behind the ceiling and the room was blown out, and not one number said
so.

> Technical validity is not the same as the thing being right.
