# Archipepsi — Still Open After v0.4

v0.3's version of this file listed nine product questions. All of them are now decided and live in the authority documents; see `CHANGELOG_v0.3_to_v0.4.md`.

What remains is genuinely small. **None of it blocks the autonomous build pass.** If the coding agent reaches any of these, the stated default applies and it should keep going.

---

## Open

### 1. LICENSE

No license file. Pick one before the repo is shared. Not a build blocker.

**Default until decided:** no license file; treat the repo as private.

### 2. Session length

`ACCEPTANCE_TESTS.md` §7 records a target of ~40 minutes for a full 30-check campaign, which assumes roughly 4 minutes per Zone. Nobody has measured a Zone, because none exist yet.

This matters because it drives chamber size limits and enemy counts. It cannot be answered before there is something to play, which is exactly why it is not a blocker.

**Default until measured:** current limits stand.

---

## Deliberately settled, recorded so they are not relitigated

These were open in v0.3. They are now decided and the reasoning is in the authority documents — listed here only so nobody reopens them by accident.

| Question | Decision | Where |
|---|---|---|
| Is 30 the right Check count? | Yes | `DESIGN.md` §5 |
| Is 3 Checks per Zone right? | Yes, target 3, max 3, min 2 | `DESIGN.md` §10.5 |
| Is the goal exactly Check 030? | Yes, but reserved and reached through a dedicated finale Zone | §10.6 |
| When does the finale unlock? | 2 Pepsi Keys + 24 of the other 29 Checks | §10.6 |
| Should Coins be forced non-local? | Yes in the demo YAML; a solo variant exists | `APWORLD_SPEC.md` §7 |
| How literal are Echoes by default? | `Playful` (creativity 1) | `DESIGN.md` §22 |
| Do duplicate source items make different Echoes? | Yes, intentionally | `DESIGN.md` §18 |
| When do hard Echo gates return? | Only after a reachability validator exists | `DESIGN.md` §19 |
| Shop stock size and cost? | 2 items, 6/4/2 by flag | `DESIGN.md` §11 |
| Movement and combat constants? | Adopted as binding, tunable after first play | `schemas/constants.py` |
| Enemy tuning? | Same | Same |
| Which button fires the Echo? | RMB; LMB is always Pepsi Pop | `DESIGN.md` §7 |
| Epsilon shop flavor text? | Cut | `DESIGN.md` §11.6 |
| Art sourcing? | Procedural only, no asset shopping | `DESIGN.md` §20 |
| Archipelago dependency? | Pinned checkout, `bootstrap.py` | `TECHNICAL_ARCHITECTURE.md` §4 |
| Where does campaign state live? | Python bridge | §2 |
| Godot test framework? | None; headless scripts plus manual checks | `ACCEPTANCE_TESTS.md` §5 |

---

## After the first playable build

Not decisions — a tuning list for when there is something to hold.

- Movement feel: is 7 m/s walking and a 3.0 m safe gap right? Retune `constants.py`; the derived gap recomputes and the guarantee holds.
- Zone length: does 3 Checks across 3–5 chambers take about 4 minutes?
- Combat: is Pepsi Pop satisfying enough to be a floor rather than a chore?
- Echo power: does a mid-bounds Echo weapon feel like a real upgrade at ~2.6× Pepsi Pop DPS?
- Epsilon tone: creative, playful, internally coherent, occasionally funny, never pure "lol random." Needs real outputs to judge.
- Finale threshold: is 24 of 29 the right amount of campaign before the ending?
- `WAITING_FOR_AP`: does it read as intentional, or as the game being broken?
- Epsilon Static: is the accumulating Hub corruption satisfying, or just noise?
- The reveal: does it land?
