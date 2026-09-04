# Batch 035 / 035-R — interactable vs decorative, decided at object scale

**Status: PASS** (owner, 2026-08-29). Two things are locked: **if a
distinction must survive gameplay distance, the distinguishing feature must
affect object-scale silhouette**, and the three-channel redundancy below —
silhouette says *what kind of thing*, interaction hardware says *yes this one
is operable*, state treatment says *what it is doing now*. The plate / bezel
may remain as standardized physical hardware **provided it is not the sole
source of truth and does not rely on hue alone**. The pure-silhouette sheet is
accepted evidence. Breakable vs blind is the weakest pair and is acceptable.

Visual grammar only. Nothing here invents an
interaction, a cost, a cooldown or a rule about what may be used when.

## The question

A player at gameplay distance must be able to tell *"I can use that"* from
*"that is scenery"* **before** walking up to it. The test is twelve objects at
4.5 m: six real interaction primitives from Batch 028 and six decoys built as
their nearest plausible non-functional twins. Numbered only. Sort them, then
read the key.

A decoy that is easy to reject proves nothing, so every decoy is one feature
away from a real one and built from the same kit at the same scale.

## What the first pass found, and why it was the right finding

Sheet A showed every interactable wearing a cyan state plate and every decoy
wearing none. **It was solvable by spotting cyan**, which proves nothing about
structure — and the builder's own docstring had named that risk before the
render happened. Sheet B suppressed the plate's emission, and that was the
real result: three pairs read, one was weak, and **two failed outright** —
carryable vs fixed crate, and key receiver vs welded hatch.

The failures had one cause. Both pairs differed only by a **hand-scale**
feature: 6 cm grips against 3 cm mouldings, a 9 cm keyway against a scribed
outline. Both of those are *legal* under the derived floor —
`min_feature_fraction` 0.08 of a 0.42 m crate is 3.4 cm, and 6 cm is about
seven screen pixels at 4.5 m — and both still failed.

> **That is the lesson.** The derived floor answers *can you see that a form
> exists*. It does not answer *can you tell which form it is*. Two screen
> pixels is enough for the first and nowhere near enough for the second.

## The rule 035-R adopts

> **A tell that has to survive gameplay distance must change the object's
> SILHOUETTE, not its surface.**

Surface is what distance takes away first. An outline is the last thing to go.

## What changed

| pair | was | is |
|---|---|---|
| `int_carryable` vs `dec_crate_fixed` | 6 cm grips vs 3 cm mouldings | a **bail arch** with a hole through it over **feet** with daylight under them, against a **solid lifting boss** on a crate sitting flush in a welded fillet |
| `int_key_receiver` vs `dec_hatch_welded` | a 9 cm keyway vs a scribed outline | an **open throat** — two cheeks with the top open between them, a fork in the outline — against a **flush slab** with the beads run over the seam |
| `int_breakable` vs `dec_panel_blind` | a coplanar fracture grid | shards at **their own depths**, centre proud and edges pulled back, so the panel is broken in relief and throws its own shadow lines, against one flat coursed field |

The hand-scale detail is all still there. Object scale says **where to look**;
hand scale says **which one it is**. On the key receiver specifically, the
shaped keyway inside the throat is unchanged — it is the same
shank/shoulder/keyway relationship Batch 031 locked, at the size a hand works
at.

## The state plate is now redundant hardware, not a colour

The owner's ruling: the plate must be kept as a learned cue, must **not** be
the sole source of truth, and must **not** require colour vision.

Emissive cyan fails the last two on its own. So the plate is now a piece of
identifiable **hardware**: a recess, a raised **bezel** around it, and the lit
face inset behind the bezel. Desaturate the whole image and it still reads as
a fitted device rather than as a moulding, because a bezel casts a shadow and
a moulding does not.

That leaves three independent channels, which is what the owner asked for:

| channel | question it answers |
|---|---|
| silhouette and construction | **what kind of thing** is this |
| interaction hardware (bezel + recess) | **yes, this one is operable** |
| state treatment (the lit face) | **what it is doing now** |

## Three sheets, and why there are three

`A_recognition.png` — the plate lit. **Not a valid test**, kept because the
failure is part of the record.

`B_recognition_no_plate.png` — the plate's emission suppressed. Better, and
still leaky: 035-R gave the plate a bezel, the bezel is *body* geometry so it
cannot be suppressed at render time, and no decoy has one. A reader who sorts
by "find the bezel" scores 12/12 and learns nothing about the grammar — the
same shape of defect as sheet A, in greyscale.

`C_recognition_silhouette.png` — **the sheet that decides it.** Flat black
against a lit backdrop: no material, no emission, no bezel, no colour. If the
pairs separate here the tell is object-scale; if they do not, it is not,
whatever the other two appear to show.

### The silhouette sheet caught one more failure

The first 035-R receiver closed the top of its throat with a lintel. Sheet C
showed immediately that this changes nothing: **a cavity in a front face does
not break an outline**, so from any angle where you cannot see into it the
receiver and the welded hatch were the same dark slab. Opening the top turned
the head into a fork — a notch in the outline itself, which is the only kind
of hole a silhouette can carry.

## Result

**All six pairs now separate in pure silhouette.** Honest ranking, strongest
first:

| pair | separates on |
|---|---|
| `int_door_mechanism` / `dec_bulkhead` | an articulated edge of brackets and rack against a plain slab |
| `int_carryable` / `dec_crate_fixed` | a hole through the bail, and a gap under the body |
| `int_key_receiver` / `dec_hatch_welded` | a fork against a slab |
| `int_machinery` / `dec_pipe_fixed` | a carriage on a rail against a fixed mass |
| `int_wall_switch` / `dec_console_dead` | a stepped lever head against a plain block |
| `int_breakable` / `dec_panel_blind` | **weakest.** The relief reads as thin gaps between courses rather than as an outline change. It passes, but it is the one to watch |

## Metrics

Everything is far inside the 900-triangle `interactable` tier; the object-scale
revision cost triangles the budget had spare.

| asset | tris | built size (m) |
|---|---|---|
| `int_breakable` | 252 | 1.14 × 0.24 × 1.90 |
| `int_carryable` | 252 | 0.64 × 0.48 × 0.66 |
| `int_door_mechanism` | 228 | 1.20 × 0.55 × 2.30 |
| `int_key_receiver` | 168 | 0.48 × 0.34 × 1.56 |
| `int_launcher` | 188 | 0.90 × 0.96 × 0.62 |
| `int_logic_indicator` | 192 | 0.30 × 0.23 × 1.73 |
| `int_machinery` | 244 | 1.16 × 0.78 × 1.25 |
| `int_wall_switch` | 152 | 0.39 × 0.55 × 1.54 |
| `int_weight_button` | 144 | 0.96 × 1.05 × 0.23 |
| `dec_bulkhead` | 72 | 1.30 × 0.33 × 2.30 |
| `dec_console_dead` | 108 | 0.39 × 0.27 × 1.51 |
| `dec_crate_fixed` | 120 | 0.58 × 0.50 × 0.51 |
| `dec_hatch_welded` | 68 | 0.48 × 0.34 × 1.58 |
| `dec_panel_blind` | 84 | 1.14 × 0.20 × 1.90 |
| `dec_pipe_fixed` | 88 | 1.11 × 0.68 × 0.97 |

No decoy carries a state plate. That is the one thing the decoys and the
primitives may never share.
