# Batch 016 — the arena shell family

**Open the four `*_entry.png` frames together first.** Same lens, same eye
height, same ambient. If they are four different problems, the family
works; if they are one room at four sizes, it does not.

Corridors differ in what you can **see**. Arenas differ in what you can
**do** — so these four are one subtraction (a pit), one addition (columns),
one storey (a balcony) and one division (a barrier).

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 016*.

| Image | What it answers |
| --- | --- |
| `A_pit_entry.png` | 18 × 18, the middle down exactly `MAX_VERTICAL_STEP` |
| `A_pit_rim.png` | the same bowl from the rim, where the shape is obvious |
| `A_pillars_entry.png` | 22 × 22 under a 4 × 4 grid, down the clear centre aisle |
| `A_pillars_aisle.png` | inside the grid: every aisle clears a 1.8 m brute |
| `A_balcony_entry.png` | 26 × 24 × 8, the boss room — one open plate |
| `A_balcony_deck.png` | the walkway at 3.20 m, above a base jump's reach |
| `A_split_entry.png` | a 1.80 m barrier, above `JUMP_APEX`; sightline 10 m |
| `A_split_gap.png` | the gap you have to commit through to reach the Check |

## Three things to know before you judge

**A number that did not discriminate, kept anyway.** `open_floor` reads
0.92–1.00 across all four — sixteen columns eat 8% of a 22 m plate. It
stays because it is the engine's own rule made checkable (*crates hug the
walls so the arena floor stays fightable*), and these shells put cover in
the middle without eating the plate. The number that actually separates the
family is **`cover_reach`**: 0.000 / 0.338 / 0.521 / 0.786.

**A question surfaced, not answered.** Arenas have no ceiling in the engine
— `_perimeter` builds a floor and four walls, and nothing overhead. Corridors
*are* roofed, so a Zone chaining one into the other joins a closed space to
an open one. These shells are roofed at `wall_height` because that is the
only continuous reading, and it is recorded as **interface requirement 19**.
If open-sky arenas are intended for some themes, the ceiling comes out.

**The pit is the weak read.** One metre across twelve is ~5° from the
entrance. `A_pit_rim.png` is where it becomes obvious. Deepening it is not
available: 1.00 m *is* `MAX_VERTICAL_STEP`, and a centimetre more makes it a
trap needing a ramp.

Status: **PENDING**. Not self-marked.
