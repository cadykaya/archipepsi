# Batch 006 — the ways out

The two remaining Pri-A rows in `ASSET_INVENTORY.md` §2 that do not need a
new visual language: the portal's two core states, and the standard door.
Both are openings the player walks through; both are still procedural in
the engine.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 006*.

| Image | What it answers |
| --- | --- |
| `P_portal_states.png` | **start here** — sealed, then open, in the approved frame. `_grey`, `_silhouette` |
| `P_portal_locked.png` · `P_portal_unlocked.png` | each one on its own, same orbit |
| `P_portal_walkup.png` | at the engine's lens — is there a way through? |
| `P_portal_cores.png` · `_silhouette` | the two cores alone, 108 tris each |
| `P_door_standard.png` · `_grey` | the lining, three-quarter |
| `P_door_through.png` | walking at it — the reveal is what you look straight at |

## The three things worth your eye

1. **Sealed is not a new colour.** The engine paints the sealed core a dark
   red and the palette has no red family; borrowing `hazard`, `dead` or
   `send` would each say something false. Both states stay in `identity` —
   the family the approved concept already uses here — and the difference
   is form: grown over, against torn open.
2. **The door wears theme trim, not a universal family.** A lining in
   `signal` teal would promise an interaction, and a corridor of doorways
   would promise seven that do not exist.
3. **The portal frame is untouched.** `portal_b2_wound` is yours and stays
   built; only `exit_portal.gd`'s `Core` changes at runtime, so only the
   core needed producing.

## The question this batch surfaces rather than answers

`objective_marker` and `signage_module` are the other two unbuilt §2 rows.
Both are a **language** rather than a fixture — a sign system that has to
mean one thing across all six themes is new visual DNA — so they are
flagged here and the work went elsewhere.

Nothing here is approved. `PASS` is yours.
