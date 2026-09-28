# Batch 028 — PROPOSAL: the interaction primitive kit

**Status: PENDING. Visual language only.** Mechanics are Production's:
nothing here decides what a button triggers, how long a timer runs, what a
launcher's arc is, how much damage breaks an obstruction, or what a key
opens.

## The audit

Read-only against `claude/archipepsi-echoes-continuation-b1adno`.

`godot/scripts/content/interactable_contract.gd` exists — and it is about the
**AP Check specifically**, not interaction in general:

```
const STATES := ["locked", "available", "sending", "confirmed"]
const IDENTITY_VISIBLE_IN := "confirmed"
const REQUIRED_PARTS := { "state_visual": "MeshInstance3D",
                          "state_label":  "Label3D" }
```

That vocabulary fits **none** of the nine primitives. A weight button is not
`locked / available / sending / confirmed`; neither is a door ram, a fuse
indicator or a breakable panel. The nine have no runtime state vocabulary
today — **interface requirement 29**.

**But `REQUIRED_PARTS` is real, and this kit is authored to it.** Every
primitive carries one identifiable `state_visual` region and reserves a place
for a `state_label`. That is a contract art can honour today without
inventing anything, and it is where the grammar comes from.

## The grammar

> **The plate is the state. Everything else is the verb.**

Every primitive carries the same recessed plate, in `signal` cyan, in the
same relation to its own affordance. Learn it once and all nine answer *what
is this doing right now* in the same place — which frees the rest of each
object to be entirely about what it **does**, and is why the nine share
nothing else.

`signal` is the licensed family and this is the case it was written for:
*"the only colour an interactable prompt, rim or reveal face is allowed to
be."* Batch 026's checkpoint deliberately does **not** take it, because a
checkpoint is walked onto rather than operated. The line between the two is
exactly that verb.

**Cause and effect without drawing a wire:** a switch and the thing it drives
carry the same plate. When one changes, the other does — no cable, no
colour-coded pair, no HUD line. And it composes: one plate on three doors
says one switch drives three doors.

## Nine verbs

| asset | verb the shape must say | tris | size (m) |
|---|---|---|---|
| `int_carryable` | GRIP HERE | 120 | 0.64 × 0.47 × 0.45 |
| `int_weight_button` | THIS GOES DOWN | 96 | 0.96 × 1.04 × 0.23 |
| `int_wall_switch` | THROW THIS | 104 | 0.39 × 0.55 × 1.54 |
| `int_door_mechanism` | THIS DRIVES THAT | 180 | 1.20 × 0.54 × 2.30 |
| `int_logic_indicator` | THIS IS COUNTING | 144 | 0.30 × 0.23 × 1.73 |
| `int_launcher` | IT THROWS YOU, THAT WAY | 140 | 0.90 × 0.95 × 0.62 |
| `int_breakable` | THIS ONE FAILS | 204 | 1.14 × 0.23 × 1.90 |
| `int_key_receiver` | SOMETHING GOES IN HERE | 96 | 0.42 × 0.30 × 1.48 |
| `int_machinery` | IT IS PART WAY | 196 | 1.16 × 0.78 × 1.25 |

## Not Portal, and not by accident

The two that would drift there are built away from it deliberately. The
carryable is a **handled industrial crate** — rectangular, grip-first — not a
cube with a symbol on each face. The button is a **rectangular floor pad with
a skirt**, not a round dish with a beam over it. Nothing in the kit is
round-and-glowing, nothing is a companion, and no primitive is coloured as a
pair.

## Sheets

| | |
|---|---|
| `A_interaction_kit.png` | nine primitives, each framed from its own extents, captioned with its verb |
| `B_interaction_grammar.png` | the whole kit at eye height — the only view that shows whether one plate reads across nine unrelated objects |

## Read the sheet with the captions covered

That is the actual test, and by it two verbs failed the first render and were
rebuilt:

- **`int_wall_switch` did not say THROW THIS.** The lever was 0.07 m and
  disappeared into its own housing; the object read as a post with a box on
  top. It is now a hand-sized throw handle, angled and proud of the guard.
- **`int_machinery` did not say IT IS PART WAY.** A 0.16 m carriage was lost
  among the rotor, housing and bed — the travel indicator was a detail *on*
  the machine when it needed to be the loudest thing on it. The rail is
  lifted clear on posts, the carriage is doubled, and the notches are now a
  legible scale.

Both were failures of the same kind: an object whose verb was present in the
design and absent in the silhouette.
