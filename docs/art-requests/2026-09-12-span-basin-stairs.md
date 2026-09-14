# Art repair request — `shell_span_basin`, both basin stairs

**To:** Arty (art lane)
**From:** Prod
**Raised by:** Zone 1 playtest, 2026-09-11 — *"the ugly stairs that don't
work, they are just square pegs and the catwalk on top is above the
stairs"*
**Measured at:** `96c450e`, against the built scene, by dropping rays
along each declared traversal line.
**Scope:** geometry only. No manifest change is needed — the manifest is
correct and the scene does not match it.

---

## The defect

Both basin-to-deck stairs stop three risers short of the deck they serve.

Rays dropped at **x = 11.9**, along the declared route lines:

| route | runs from | climbs to | deck | **final step** |
|---|---|---|---|---|
| `basin_south_to_deck` | 0.88 m at z 2.6 | **11.37 m** at z ≈ 14.5 | 14.00 m | **2.63 m** at z ≈ 14.62 |
| `basin_north_to_deck` | 1.75 m at z 87.4 | **11.38 m** at z ≈ 75.5 | 14.00 m | **2.62 m** at z ≈ 75.40 |

Everything below that point is correct and consistent: **uniform 0.875 m
risers on roughly 0.9 m treads**, all the way up. The stair is not
malformed — it is *short*.

`MAX_VERTICAL_STEP` is 1.0 m and the base-kit jump apex is 1.333 m, so a
2.63 m step cannot be walked **or** jumped. Both stairs are dead ends for
a player without an Echo, which is what the playtest hit.

## The repair

Extend each flight by **three risers of ~0.877 m** (3 × 0.877 = 2.63) so
the top tread meets the deck surface at **y = 14.00**, keeping the
existing 0.875 m riser and ~0.9 m tread. That adds roughly **2.7 m of
run in Z** per flight:

- south: top tread lands at y = 14.00 around z ≈ 17.3
- north: top tread lands at y = 14.00 around z ≈ 72.7

If the run cannot grow — the landings at `landing_0` / `landing_1` sit at
z 16.1 and 73.9 — then re-space the whole flight to more, shallower
risers over the run available, so long as no single riser exceeds 1.0 m.
Either is fine; what matters is that no step in the flight exceeds
`MAX_VERTICAL_STEP`.

## What must not change

- **The one-way drop stays.** `deck_to_basin` (`kind: drop`, start
  `[2.0, 14.0, 45.0]` → end `[6.0, 0.0, 45.0]`) is approved as a one-way
  route and is not part of this repair.
- The declared traversal endpoints stay where they are: `[11.9, 0.0, 2.6]
  → [11.9, 14.0, 16.6]` and `[11.9, 0.0, 87.4] → [11.9, 14.0, 73.4]`.
  The manifest already describes the stair that *should* exist.
- The mandatory deck routes (`entry_to_deck`, `deck_to_exit`) are
  unaffected.

## Why no test caught it

Both routes are `mandatory: false`. `shell_validator.gd:110` is
`if not mandatory: return out` — a non-mandatory route is checked for
endpoint drift and then returns, before the step where `TraversalLaw`
proves a declared `walk` has ground along its whole length.
`room_audit.gd:455` skips non-mandatory segments as well. So the two
endpoints were verified, the 14 m of stair between them never was.

**Sequencing.** Promoting that check so a declared `walk` is proven along
its length whatever its `mandatory` flag is the right follow-up, and is
deliberately *not* being landed before this repair — it would turn the
suite red on this defect. Once the stairs land, the check should follow,
and it will hold every non-mandatory walk in the pack to the same rule.

## Separately, and not yours

The 0.875 m risers are inside the declared walkable step, and a player
still has to jump every one of them, because there is no step-up anywhere
in `player.gd` — `move_and_slide` does not climb. That is a movement
question for the engine lane, not a geometry defect, and this request does
not ask you to change the riser height for it.
