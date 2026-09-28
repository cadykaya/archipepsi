# Batch 018 — the tower family

**Open the three `*_entry.png` frames first** — from the door, looking up,
which is the question a tower asks — then the three `*_over.png`, which are
the only frames where the whole route reads at once.

`TowerChamber` gives art exactly one number: `floors`, 2 to 5. That moves
the rise between 6 and 15 m inside a 12 m square, so these three sit at the
bottom, middle and top of the range and answer the climb differently.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 018*.

| Shell | Floors | Rise | Worst jump | Bound |
| --- | --- | --- | --- | --- |
| `shell_tower_collapsed` | 2 | 6 m | 0.800 | 2.00 |
| `shell_tower_spiral` | 3 | 9 m | 1.700 | 2.00 |
| `shell_tower_gantry` | 5 | 15 m | 0.100 | 2.00 |

## Two things worth knowing

**The route check refused a shell, and was right.** `shell_tower_collapsed`
first alternated its surviving half-floors left and right, which put a
3.60 m crossing between them against a 2.00 m bound — an unfinishable level
that no render would have shown, because from every camera it looks like
two floors with a gap. Alternating in *depth* instead keeps each climb on
the slab below it.

**A scary number that was measuring the wrong thing.** All three first
reported ~1.93 m against the 2.00 m bound. The route was measured from the
doorway, but a tower's ground floor is a full 12 × 12 slab — you walk under
the first platform and step up. Measured from where the player actually
stands, the same geometry reads 0.800 / 1.700 / 0.100.

`routecheck` is now one shared module for towers and platform paths, so the
two families cannot disagree about what a legal climb is. Batch 017's
shells rebuild byte-identical after the extraction.

Status: **PENDING**. Not self-marked.
