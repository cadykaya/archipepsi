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

### L-24 · Read your own render before writing down what it shows
Every fix in L-05, L-08, L-09, L-11, L-13 and L-14 came from **looking at
the image**, not from the build log. The logs were green throughout: correct
triangle counts, exact texel densities, every assertion passing. The
concrete wall was static, the enemies were camouflaged, the ceiling beams
were behind the ceiling and the room was blown out, and not one number said
so.

> Technical validity is not the same as the thing being right.
