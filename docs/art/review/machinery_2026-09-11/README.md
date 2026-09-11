# Batch 043 / B — the machinery feedback kit

**Arty**

The five conduit states Design 1 §19.5 already specifies, as reusable
presentation assets; three machinery pieces that carry them; and an isolated
demonstration of a setter and a receiver reporting their own states.

**PROPOSAL. Presentation only.** There is no signal graph here — no node
types, no evaluation order, no package validation, and no gameplay state
machine invented so that a preview could move. Conduits are presentation by
§19.5's own words: never destructible, carrying no state.

---

## The five states

`_look_states.png` is the flat comparison; `room/MACH_five_states.png` is the
same five on a wall.

The rule they are all built to is §19.5's, and Dungeon Authority §50's:
**every state differs in at least two of brightness, pattern, motion and
audio, and none is distinguished by hue alone.**

| state | brightness | pattern | motion |
| --- | --- | --- | --- |
| `inactive` | dim | unbroken hairline | none |
| `active` | bright | chevrons cut out of the bar | scrolls +X, 0.6 m/s |
| `pulse_travelling` | bright block on a dim line | one block, constant length | scrolls +X, 4.0 m/s |
| `blocked` | dim | segments, plus a hard break mark | none |
| `delayed` | bright fill on a dim remainder | solid fill behind a hard edge | the edge advances; the tail never leaves the source |

### The two distinctions the brief asked for

**A travelling pulse against a mechanical delay.** A pulse is a short band of
*constant length* that moves end to end. A delay is a band of *growing
length* whose leading edge advances and whose tail stays at the source. They
differ in pattern, in motion, and in what the edge does — three channels.
`room/MACHSEQ_motion.gif` runs both at once so the difference is the thing
you see rather than the thing you are told.

**`blocked` against `inactive`.** Both are dim and both are still, so
brightness and motion carry nothing here — it is pattern alone. `inactive` is
an unbroken hairline: a whole conduit with nothing in it. `blocked` is the
same line cut into segments with a break mark across the trough: a conduit
that is trying and failing. `room/MACH_close_inactive_vs_blocked.png` is the
frame that has to settle it, and it is a still on purpose, because if pattern
cannot separate them when nothing is moving then motion will not save them.

`blocked` is the one place `hazard` appears in this kit, on the break mark,
and it is the engine-owned universal colour used for what it already means.

## Audio does not exist, and silence proves nothing

§19.5 names a low hum for `active`, a click on arrival for
`pulse_travelling`, and a rising pitch for `delayed`. **None of the three
exists.** Four of the five states separate on the visual channels alone,
which is what these pictures show.

`delayed` is the exception and it is worth stating plainly: its rising pitch
is the only channel that tells the player *how long*. A silent `delayed` says
"soon" and never says "two more seconds". That is item 5 in
`../status_2026-09-11/DECISIONS_FOR_OWNER.md`.

## How these can be driven after import

The owner asked exactly this, and it is the reason the three pieces exist in
the shape they do.

**The finding first.** Batch 028's interaction kit declared a `state_visual`
region on all nine primitives and exported each as ONE mesh node with three
material slots. Measured at `327c089` with
`tools/content/inspect_glb_nodes.py`:

```
int_wall_switch   1 mesh node, 3 surfaces:
                  ..._body, ..._accent, ..._cores
```

So the only handle a runtime has on a Batch 028 state region is
`set_surface_override_material(2, mat)`. That recolours it and does nothing
else — it cannot hide the region, move it, scale it, rotate it, or give it
its own shader.

**Batch 043's pieces export every state region as its own named node**, and
the same inspector reports:

```
mach_conduit_run     state_band                    1 surface
mach_wall_switch     lever_arm, state_lens         1 surface each
mach_receiver_lamp   state_lens_0, state_lens_1    1 surface each
```

A runtime gets both handles and picks:

| to do this | do this |
| --- | --- |
| swap a conduit's state texture | `find_child("state_band")`, then `set_surface_override_material(0, m)` on that node |
| scroll `active` / `pulse_travelling` | set `uv1_offset.x` on the band material |
| grow `delayed` | scale the `state_band` node on X from its −X end; the texture holds still |
| move a lever | rotate `lever_arm` about its own X axis |
| light an indicator | `state_lens`, `state_lens_0`, `state_lens_1` — one material slot each |

The names are in `assets/models/batch043/machinery/manifest.json` under
`parts` and `how_to_drive`, so integration reads a contract instead of
opening the `.glb`.

**Batch 028 is not modified.** It is PENDING owner review and it stays
exactly as you last saw it.

## The setter and the receiver

`room/MACH_switch_off.png`, `_on.png`, `_disagreeing.png`.

Design 3 §33.8 asks for *"the physical position of the lever, plus a legible
indicator naming the current target"* — so the lever is turned, not
recoloured, and it could not have been on a merged mesh. The receiver carries
**two** lenses rather than one, because a single lamp can only say on or off,
and §33.8's "impassable predicated edge" needs a third reading: agreeing with
its input, or not.

## Scale and pitch

The band tile is 64 × 16 px = **2.00 m × 0.50 m at 32 texels/m**, the
architecture budget, so a conduit tiles at the same pitch as the wall behind
it. `build_machinery.py` asserts that on both axes rather than trusting it.
Clamps sit at 0.50 m, the shell's own bolt pitch.

## Files

| | |
| --- | --- |
| `author_conduit_states.mjs` | authors the channel and the five bands in Glyph |
| `glyph/`, `png/` | editable projects and exports, native, 6× and 3×3 |
| `conduit_states.json` | per state: texture, brightness, pattern, motion, and the audio still required |
| `tools/blender/build_machinery.py` | the three pieces |
| `tools/content/machinery_preview.gd` | the isolated demonstration |
| `room/` | the rendered frames and `MACHSEQ_motion.gif` |

Rebuild:

```
GLYPH_ROOT=/path/to/ecms-glyph node author_conduit_states.mjs
.tools/blender/blender -b --python tools/blender/build_machinery.py -- \
    docs/art/review/machinery_2026-09-11
tools/content/run_machinery_preview.sh
```
