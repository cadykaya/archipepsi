# Batch 005 — the Check, produced, and its four states

**Start with `K_state_family.png`, then `K_state_family_far_inset.png`.**
The first is the batch; the second is what a player 40 m away actually gets,
at 4× with no filtering, and it is the sheet that changes something.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 005*.

## What this is

Tier 2 opens with core interactables. Batch 001 concepted the Check and you
passed silhouette **A** revised — but that was one joined mesh that stands
still. `reward.gd` drives three of the Check's five children independently,
so the produced Check is seven files split along those node boundaries, with
every dimension read out of that file.

| Image | What it answers |
| --- | --- |
| `K_state_family.png` | **the four states on the mast, one camera, one frame.** Grey and silhouette variants beside it |
| `K_state_family_far.png` | the same four at 39.6 m — the largest arena diagonal — on the engine's 90° lens |
| `K_state_family_far_inset.png` | those pixels at 4×, nearest-neighbour. **The important one** |
| `K_check_assembled.png` | mast + item + ring, 35 mm three-quarter. `_grey`, `_silhouette`, `_clay` |
| `K_check_operator.png` | walk-up at eye height, engine lens — the interaction face |
| `K_check_far_read.png` | one Check at 39.6 m, plus `_grey` |
| `K_check_cage_detail.png` | the caged head at 85 mm |
| `K_item_family.png` | the four items alone. `_grey`, `_silhouette` |
| `K_destination_ring.png` | the ring the engine tints per recipient world |
| `K_send_beam.png` | 40 m of departing item |

## The three questions

1. **The state language.** Empty cradle → bright spindle → stretched column
   → dark husk. Four silhouettes rather than four hues, so a player who
   cannot rely on hue still has the read. Is that the right vocabulary?
2. **Locked against confirmed at distance.** They do not separate at 39.6 m
   — see the inset. In the running game the destination ring separates them,
   because `reward.gd` dims it to 0.35 energy when locked. Is leaning on the
   ring for that acceptable, or should the mast carry a state channel too?
3. **The base collar.** It wore `send` in the concept because it *was* the
   destination ring; the engine's real ring is twice the size and lives on
   the floor, so the collar is now structural. Everything else about the
   approved silhouette is untouched.

Nothing here is approved. `PASS` is yours.
