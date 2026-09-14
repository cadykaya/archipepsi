# The owner's own session, read

**Source:** a private copy of the `.diagnostic-582e954` slot JSON, its
`.bak`, and one `playtime.jsonl` record, shared 2026-09-14.
**Not committed.** The saves stay private; only the measurements taken
from them are written down here, and the originals were never modified.

**Build played:** `582e954da8e7`, Windows, `tree: dirty`, Python 3.14.4.

---

## The fixture everything was measured on IS this Zone

`godot/tests/fixtures/played_zone.json` hashes to **`fe2b014761fbb449`**,
and so does the `zone_digest` in the playtime record. The same sixteen
characters.

So the whole of this run's engine work was measured on the level that
was actually played, not a lookalike: the `Reward_89100126` approach in
`c021`, the mounting census, the unmounted-target shot in `c007`, the
sealed-door sweep, the station panel, the F5 schematic.

---

## The two questions the save was waiting to answer

**The Whistle crossing.** The `.bak` and the live save differ in exactly
**one field**:

```
slots.mobility   act_l89100076 (Fresh Rep, dash)
              -> act_l89100019 (Warp Whistle, blink)
```

Everything else — every interpretation, every local reward, the whole
Zone manifest and its progress — is byte-identical. So the `.bak` is the
moment before the Whistle went into the mobility slot.

Resolved after its four upgrades, the equipped Whistle is
`blink, range 20.0 m, cooldown 2.10 s, clearance 0.4` (from 14.0 m /
2.50 s). The dash it replaced was `force 20.0, cooldown 2.0`.

**AND NOTHING IN THAT ZONE NEEDED IT.** Every declared gap is inside the
base kit:

| room | gap | step | base-kit allowance |
|---|---|---|---|
| `c003` | 2.31 m | 0.51 | 2.40 m |
| `c008` | 2.08 m | 0.51 | 2.40 m |
| `c021` | 2.03 m | 0.51 | 2.40 m |
| `c012` | 1.73 m | 0.51 | 2.40 m |
| `c017` | 1.73 m | 0.51 | 2.40 m |

Five rooms declare a gap, **none exceeds the allowance**. The Whistle
was a convenience, not a key, and the Zone stayed base-kit solvable —
which is the property that is not allowed to break.

**`Reward_89100126`.** It is in the save as a collected Echo (Warp
Whistle Mk 2, `+6.0` range). The Check this lane reported as "2.6 m
below the floor" and then retracted was reached by the player. The
retraction was right.

---

## What the session says about the two retired families

79.5 minutes in one Zone. **23.2 of them inside an activity** — 29%.
28 of 29 activities completed, 4 deaths, `zone_value` 911 against a
1000 budget.

| family | n | completed instantly | median | max | needed a retry |
|---|---|---|---|---|---|
| `pressure_routing` | 5 | 1 | 2.72 s | 7.14 s | **2** |
| `switch_sequence` | 7 | 0 | 6.33 s | 792.65 s | 0 |
| `target_challenge` | 8 | 0 | 2.25 s | 257.82 s | 0 |
| `timed_run` | 9 | **5** | **0.00 s** | 9.14 s | 1 |

**`timed_run` was over before it started, five times out of nine.** Its
median active time is zero. A timed run whose timer never accumulates is
not a race; it is a doorway with a label on it.

**`pressure_routing` would not hold.** Of five:

| | |
|---|---|
| `c023_0` | **23 attempts** for 2.72 s of active time |
| `c011_0` | 3 attempts |
| `c015_0` | entered, 0.00 s, **never completed** — the only failure in the Zone |

Three of five misbehaved. And the room holding the 23-attempt plate ate
**1060 seconds — 17.7 minutes, a fifth of the whole session** — for 43
points of content.

**This is the strongest evidence yet for retiring those two families,
and it is not the evidence the variant is built on.** The variant
removes them to reduce content *volume*. The session says they should go
because they *do not work*: one completes itself, the other will not
latch. Those are different problems with different remedies, and cutting
the budget by 28% addresses neither.

---

## Two other things worth seeing

**`c021_0` ran its active timer for 792 seconds** — 13 minutes on a
four-element `switch_sequence`. `c021` is the `platform_path` over a
40 m drop that holds `Reward_89100126`. Whatever happened there, it was
not four switches' worth of time.

**Only 29% of the session was inside an activity.** The other 56 minutes
were spent getting places. The three longest rooms after the arena are
all `platform_path`.

---

## What this does not settle

- **Why** `timed_run` completes at 0.00 s, and **why** the `c023` plate
  needed 23 attempts. Both are reproducible-looking, neither is
  diagnosed, and neither was chased here — that would be new work.
- Whether the 792 s in `c021` is a defect or a player taking their time.
  The record cannot tell the difference.
- Anything about the variant's router blocker, which is unrelated and
  documented in `docs/FOLLOWUP_02_INTEGRATION.md` §6a.
