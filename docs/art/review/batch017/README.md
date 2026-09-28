# Batch 017 — the platform-path family

**Open the three `*_over.png` frames first.** They are the only ones where
the route reads as a route: at the engine's 90° lens, standing on the start
ledge of a 31 m shaft shows you two walls and a receding line of tiles,
which is honest but is not how you judge a layout.

This is the family where a number slightly wrong makes the game
unfinishable, so the numbers come first.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 017*.

| Shell | Segments | Step | Gap | Worst jump | Bound |
| --- | --- | --- | --- | --- | --- |
| `shell_path_ascent` | 5 | 1.00 | 1.80 | **1.800** | 2.00 |
| `shell_path_stagger` | 6 | 0.50 | 2.20 | **2.309** | 2.40 |
| `shell_path_spans` | 3 | 0.00 | 2.40 | **2.400** | 2.60 |

`gap_size` and `vertical_step` are bounded **jointly** — v0.4 bounded them
independently and a legal chamber could be unfinishable — so no gap in this
batch is a literal. `engine_truth` carries `max_safe_gap` as a *function*,
and every consecutive pair is measured **edge to edge** and checked before
export.

| Image | What it answers |
| --- | --- |
| `P_ascent_over.png` | the whole climb: 5 segments, 31.3 m, exiting 5.0 m up |
| `P_stagger_over.png` | the alternation, which is the design |
| `P_spans_over.png` | the crossing: 3 beams, flat, 25.1 m |
| `P_*_start.png` | what the start ledge actually shows the player |
| `P_ascent_mid.png` · `P_stagger_mid.png` | mid-route |
| `P_spans_back.png` | the end ledge, where the enemies wait |

## Three things to know before you judge

**The stagger's 2.309 m is priced, not guessed.** A 1.6 m offset either
side means neighbours differ by 3.2 m laterally — 0.7 m more than a
platform's own 2.5 m width — and that 0.7 costs `sqrt(2.20² + 0.70²)`. A
lateral offset is free up to the platform width and priced past it.

**`exit_offset` grew a Y.** These chambers exit at the top of what you
climbed, unlike every shell in Batches 015 and 016. Writing `(0, 0, total)`
out of habit would stack the next chamber five metres below its own door.

**The bench needed a knob, and got one.** Its three-light rig assumes a
subject on a backdrop; an open-topped shaft let the key hit one wall
square-on and blew it white. `key_energy` is now a scene-group option
defaulting to the old value, so nothing already shot has moved.

Status: **PENDING**. Not self-marked.
