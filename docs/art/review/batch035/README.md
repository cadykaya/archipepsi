# Batch 035 — interactable vs decorative readability

**Status: PENDING. The test returned a mixed result, and the mixed part is
the useful part.**

## What was built

Six **decoys** — the nearest plausible non-functional twin of a Batch 028
primitive, built from the same kit at the same scale. A decoy that is easy to
reject proves nothing, so each differs from its twin in one or two structural
features and nothing else:

| decoy | shadows | the difference |
|---|---|---|
| `dec_crate_fixed` | `int_carryable` | handles are **mouldings** with no gap; filleted to the deck |
| `dec_panel_blind` | `int_breakable` | coursed as one piece; scribed lines, no fracture grid |
| `dec_console_dead` | `int_wall_switch` | blanked bosses where a lever would be |
| `dec_bulkhead` | `int_door_mechanism` | a door-sized recess, no jamb, no rack, no ram |
| `dec_hatch_welded` | `int_key_receiver` | a hatch outline with its fixings welded over |
| `dec_pipe_fixed` | `int_machinery` | plant with no travel, no carriage, no rail |

## The test, and how it initially failed

Twelve objects, interleaved, captioned **by number only**, at 4.5 m —
representative gameplay distance rather than inspection distance.

**Sheet D failed as a test.** Every interactable showed the `signal` state
plate and every decoy did not, so it was solvable by spotting cyan, which
proves nothing about the structural grammar it was built to check. The
builder's own docstring had named that exact risk and the sheet was rendered
without guarding against it.

**Sheet E is the real test:** the same twelve with every emissive surface
suppressed. What is left is grip, mounting hardware, mechanical joints, and
somewhere for the thing to go.

## The result — sorted cold, from sheet E

| pair | verdict |
|---|---|
| **3 vs 10** — wall switch vs dead console | **reads.** A lever proud of a housing is unmistakable against blanked bosses |
| **11 vs 8** — door mechanism vs bulkhead | **reads.** Rack, ram and jamb against a smooth recess |
| **9 vs 4** — machinery vs bulkhead | **reads**, though these two are not really near-twins at this angle |
| **5 vs 2** — breakable vs blind panel | **weak.** The fracture grid is visible but the scribed seams are close |
| **1 vs 6** — carryable vs fixed crate | **FAILS.** Both are small crates. The grips do not survive 4.5 m from this angle |
| **7 vs 12** — key receiver vs welded hatch | **FAILS.** Both are a box on a post; the keyway and the welds are the same size as each other and both are too small |

## The finding, which is not what the batch set out to prove

> **The structural grammar is distance-limited, and the limit is the size of
> the tell.**

Where the difference is **object-scale** — a lever, a rack, a rail, a
carriage, a travel gap — it carries at gameplay distance on its own. Where
the difference is **hand-scale** — a grip on a crate, a keyway on a post —
it does not, and at 4.5 m the two objects are the same object.

That reframes the state plate. Batch 028 presented it as the answer to *what
is this doing right now*, with the structural tells doing the work of *can I
use this at all*. Sheet E says that is only true for large objects. **For
small ones the plate is not a status indicator — it is the only affordance
cue that survives the distance**, and suppressing it makes them genuinely
unsortable.

Two ways forward, and this is an owner decision rather than an art one:

1. **Accept it.** The plate is load-bearing for hand-scale interactables, and
   that is a legitimate design position — but it means a player who cannot
   separate cyan has no fallback on those objects.
2. **Raise the tell to object scale.** A carryable gets a grip that breaks
   its silhouette rather than one recessed into its face; a receiver gets a
   housing whose shape differs from a blank post. That costs a revision of
   two Batch 028 primitives, which are PENDING and not yet approved.

Art recommends **2**, and has not done it: Batch 028 is awaiting review and
changing it now would reopen a concept the owner has not ruled on.

## Sheets

| | |
|---|---|
| `A_recognition.png` | as lit — **not a valid test**, kept to show why |
| `B_recognition_no_plate.png` | the state plate suppressed. This is the result |

Answer key is on both sheets, at the bottom, deliberately last.
