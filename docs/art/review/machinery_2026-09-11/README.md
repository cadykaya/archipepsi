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

| state | brightness (measured L\*) | pattern | motion |
| --- | --- | --- | --- |
| `inactive` | **22.0** — lowest in the kit | unbroken hairline | none |
| `pulse_travelling` | 34.5 | one block, constant length | scrolls +X, 4.0 m/s |
| `blocked` | **41.0** | tall broken blocks, bright cut ends, one severance | none |
| `delayed` | 27.1 track + a lit fill | graduated track between two fixed end stops | the `fill_band` node grows; the track never moves |
| `active` | 47.3 | chevrons cut out of the bar | scrolls +X, 0.6 m/s |

Brightness is the mean CIE L\* of the conduit trough, computed from the
composited pixels by `author_conduit_states.mjs` and written into
`conduit_states.json`. It is measured rather than claimed, for the reason in
the next section.

### The two distinctions the brief asked for

**A travelling pulse against a mechanical delay.** A pulse is a short band of
*constant length* that moves end to end. A delay is a band of *growing
length* whose leading edge advances and whose tail stays at the source. They
differ in pattern, in motion, and in what the edge does — three channels.
`room/MACHSEQ_motion.gif` runs both at once so the difference is the thing
you see rather than the thing you are told.

**`blocked` against `inactive`, and the rule this pair nearly broke.**

§19.5's own table gives `inactive` *"dim, static, no audio"* and `blocked`
*"dim with a broken-segment pattern, no audio"*. Read literally, those two
differ in **pattern alone** — and the same section requires every state to
differ in at least two of brightness, pattern, motion and audio. The
section's table does not satisfy the section's rule for this one pair.

A first pass of this kit reproduced that, and then reached for `hazard`
orange on the break mark to make up the difference. **That was wrong twice.**
It leaned on hue, which §50 forbids; and `hazard` means *this will hurt you*.
A blocked conduit is inert — a signal that is not arriving, not a thing that
burns you — and teaching a player otherwise costs more than a dull-looking
conduit ever would. The reuse is gone and no reserved colour appears in this
kit at all.

A second pass made `blocked` *dimmer* than `inactive` and measured **25.0
against 23.9** — one L\* apart, which is nothing. It also had the semantics
backwards. `inactive` is scenery: a conduit with no signal in it and nothing
for the player to do. `blocked` is a **puzzle state**: something is trying to
get through and cannot, and the player is meant to notice it from across the
room.

So:

| | |
| --- | --- |
| `inactive` | a thin continuous hairline, **L\* 22.0**. Whole, calm, almost not there |
| `blocked` | tall segments at **L\* 41.0**, each capped by a bright cut end, with one wide severance |

**A 19.0 L\* gap, and the build asserts it.**
`author_conduit_states.mjs` reduces each composited state to CIE L\* and
fails if the pair falls under an 8.0 L\* floor. A comment claiming two states
differ in brightness is worth nothing — the first version carried exactly
that comment while the two states measured 1.1 apart.

`room/MACH_close_inactive_vs_blocked.png` is the frame that settles it, and
it now contains **only those two conduits**. The first version framed two
rows of a five-row stack and put the two labels beside `active`'s chevrons
and the travelling pulse — captions that were right about the states and
wrong about the conduits under them.

## Audio does not exist — and it is not the timing channel

§19.5 names a low hum for `active`, a click on arrival for
`pulse_travelling`, and a rising pitch for `delayed`. **None of the three
exists**, and each is an integration requirement.

**A correction to this package's own earlier claim.** It said the rising
pitch was the only channel that tells the player *how long*. That is not what
§19.5 says. Its row for `delayed` reads *"filling-band animation showing
remaining time, rising pitch"* — **the filling band carries the remaining
time and is required to**, and the pitch is the second channel beside it.

So the visual half is not a consolation for missing audio; it is the primary
timing display, and this kit owes it a real one:

- `band_delayed` is a **static graduated track** with a start stop at the
  source, an end stop at arrival, and quarter marks between them. Full
  length, every frame.
- the fill is **separate geometry** — the `fill_band` node — which grows
  across that track.

That split is the whole point. A first version drew the fill into the texture
and scaled the whole band to grow it, which squashed the track's own end
stops along with it: at 0% the arrival stop sat 12% of the way along the run.
**The span the fill was a fraction of moved with the fill**, and a player
cannot read a fraction off a ruler that shrinks. Endpoints that move are not
endpoints.

`room/MACH_delay_0.png` … `_100.png` is a labelled **4.0 s** delay sampled at
five known fractions, with both endpoints marked and the remaining time
stated in each frame. No audio is used and none is needed to read it.

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
| scroll `active` / `pulse_travelling` | set `uv1_offset.x` on the band material. `state_band` is never scaled |
| grow `delayed` | scale the **`fill_band`** node on X and leave `state_band` alone. Derive the fixed end from the node's own AABB — see below |
| hide the fill | `fill_band.visible = false` for every state except `delayed` |
| move a lever | rotate the **`hinge_lever`** node about its X axis |
| light an indicator | `state_lens`, `state_lens_0`, `state_lens_1` — one material slot each |

**Derive the fixed end; do not assume −1…+1.** A point at local `x` maps to
`position.x + scale.x · x`, so holding the −X end still means
`position.x = base + x₀·(1 − s)` where `x₀` is the node's own AABB minimum.
The preview does exactly that. It matters: the conduit's fifth clamp was
authored at x = +1.25, 25 cm past the end of a 2.00 m run, which moved the
asset's centre when `set_origin_group` centred it — and the band exported
spanning **−1.14 … +0.86** instead of −1.00 … +1.00. Every frame of the delay
was drawn in the wrong place. The clamp is fixed and the band is symmetric
again, and the preview no longer cares either way.

The names are in `assets/models/batch043/machinery/manifest.json` under
`parts` and `how_to_drive`, so integration reads a contract instead of
opening the `.glb`.

**Batch 028 is not modified.** It is PENDING owner review and it stays
exactly as you last saw it.

## The setter and the receiver

`room/MACH_switch_off.png`, `_on.png`, `_disagreeing.png`.

Design 3 §33.8 asks for *"the physical position of the lever, plus a legible
indicator naming the current target"* — so the lever is turned, not
recoloured. The receiver carries **two** lenses rather than one, because a
single lamp can only say on or off, and §33.8's "impassable predicated edge"
needs a third reading: agreeing with its input, or not.

### The lever has a real hinge now, and it is measured

The previous export gave `lever_arm` an **identity transform with vertices
running from Y 0.27 to Y 0.53**. Rotating that node rotates it about the
*asset* origin, half a metre below the arm — so the lever swept through the
wall instead of turning on its pintle, while the manifest promised *"the
pivot sits at the arm's base"*. The preview looked plausible because a big
enough swing hides a wrong centre.

`hinge_lever` is now an **Empty at the pintle**, exported as a node carrying
that translation, with `lever_arm` as its child at identity and its vertices
re-based so the pivot is its local origin. The arm reaches below the pin as
well as above it, so the pivot is *inside* the geometry rather than at its
tip — checked at build time, not assumed.

Measured across a 75° sweep, in `room/machinery_log.json`:

| | |
| --- | --- |
| pivot inside the arm's own geometry | **true** (local Y −0.10 … +0.20) |
| attachment point movement | **0.000000000 m** |
| the same point, without a hinge node | **0.4465 m** |

`room/MACH_hinge_00.png` … `_05.png` and `MACH_hinge_sweep.gif` show it: the
white pip is the pintle, the arm turns around it, and the pip does not move.

## Scale and pitch

The band tile is 64 × 16 px = **2.00 m × 0.50 m at 32 texels/m**, the
architecture budget, so a conduit tiles at the same pitch as the wall behind
it. `build_machinery.py` asserts that on both axes rather than trusting it.
Clamps sit at 0.50 m, the shell's own bolt pitch.

## Files

| | |
| --- | --- |
| `author_conduit_states.mjs` | authors the channel and the five bands in Glyph, and asserts the measured brightness gap |
| `glyph/`, `png/` | editable projects and exports, native, 6× and 3×3 |
| `conduit_states.json` | per state: texture, measured trough L\*, pattern, motion, and the audio still required |
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
