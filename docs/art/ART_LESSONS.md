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

## Process

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
