# Archipepsi — Still Open After v0.8

v0.3 listed nine product questions; v0.4 closed them. v0.5 closed the pass-3 findings and three more product decisions (postgame, visual target, terminology). See `CHANGELOG_v0.7.md`.

What remains is genuinely small. **None of it blocks the autonomous build pass.** If the coding agent reaches any of these, the stated default applies and it should keep going.

---

## Open

### 0. Six tooling leftovers from pass 3

`bootstrap.py` interrupted-clone recovery and probe quoting (m21, m22); `ARCHIPELAGO_ROOT` bypassing the version pin (M18); Pydantic models for `ZoneGenerationRequest`/`EchoGenerationRequest` (m25); one export command and destination (m27); who launches the bridge process (m33).

None can break a campaign. Fold them into the first build pass rather than another spec pass.

### 1. LICENSE

No license file. Pick one before the repo is shared. Not a build blocker.

**Default until decided:** no license file; treat the repo as private.

### 2. Session length

`ACCEPTANCE_TESTS.md` §7 records a target of ~40 minutes for a full 30-check campaign, which assumes roughly 4 minutes per Zone. Nobody has measured a Zone, because none exist yet.

This matters because it drives chamber size limits and enemy counts. It cannot be answered before there is something to play, which is exactly why it is not a blocker.

**Default until measured:** current limits stand.

---

### 3. Deployables

Turret, decoy, temporary platform, field. Real value, and the most expensive
thing on the Echoes 2.0 list: lifetimes, their own AI, and a placement rule
so nothing can be dropped outside Zone bounds.

**Default until decided:** deferred past S10, not in the closed catalog.

### 4. Geometry-changing forms

`tiny` and `huge` are a second movement contract, because every doorway,
gap, lane budget and enemy-fit invariant is derived from a fixed player size.

**Settled for now:** deferred past S10 (`ECHOES.md` §22).

---

## Deliberately settled, recorded so they are not relitigated

These were open in v0.3. They are now decided and the reasoning is in the authority documents — listed here only so nobody reopens them by accident.

**Settled with v0.8** (`ECHOES.md` §22): resource current values reset on Zone entry while definitions, maxima and upgrades persist; permanent severe curses never exist, so severity always implies something removable; geometry-changing forms are deferred; and the packet rolls forward to a complete v0.8 authority rather than an addendum, changing only what Echoes 2.0 touches.

| Question | Decision | Where |
|---|---|---|
| Is 30 the right Check count? | Yes | `DESIGN.md` §5 |
| Is 3 Checks per Zone right? | Yes, target 3, max 3, min 2 | `DESIGN.md` §10.5 |
| Is the goal exactly Check 030? | Yes, but reserved and reached through a dedicated finale Zone | §10.6 |
| When does the finale unlock? | 2 Signal Keys + 24 of the other 29 Checks | §10.6 |
| Should Coins be forced non-local? | Yes in the demo YAML; a solo variant exists | `APWORLD_SPEC.md` §7 |
| How literal are Echoes by default? | `Playful` (creativity 1) | `DESIGN.md` §22 |
| Do duplicate source items make different Echoes? | Yes, intentionally | `DESIGN.md` §18 |
| When do hard Echo gates return? | Only after a reachability validator exists | `DESIGN.md` §19 |
| Shop stock size and cost? | 2 items, 6/4/2 by flag | `DESIGN.md` §11 |
| Movement and combat constants? | Adopted as binding, tunable after first play | `schemas/constants.py` |
| Enemy tuning? | Same | Same |
| Which button fires the Echo? | RMB; LMB is always Static Pulse | `DESIGN.md` §7 |
| Does goaling end the campaign? | No — postgame keeps the portal live | `DESIGN.md` §13.5 |
| Minecraft or late-90s FPS? | Late-90s PC FPS, GoldSrc-era brushwork | `DESIGN.md` §3.4, §20 |
| Is the terminology soda-based? | No. Signal Key, Static Pulse; Archipepsi is the codename | `constants.py` |
| Epsilon shop flavor text? | Cut | `DESIGN.md` §11.6 |
| Art sourcing? | Procedural only, no asset shopping | `DESIGN.md` §20 |
| Archipelago dependency? | Pinned checkout, `bootstrap.py` | `TECHNICAL_ARCHITECTURE.md` §4 |
| Where does campaign state live? | Python bridge | §2 |
| Godot test framework? | None; headless scripts plus manual checks | `ACCEPTANCE_TESTS.md` §5 |

---

## After the first playable build

Not decisions — a tuning list for when there is something to hold.

- Movement feel: is 7 m/s walking and a 2.6 m safe gap right? Retune `constants.py`; the derived gap recomputes and the guarantee holds.
- Zone length: does 3 Checks across 3–5 chambers take about 4 minutes?
- Combat: is Static Pulse satisfying enough to be a floor rather than a chore?
- Echo power: does a mid-bounds Echo weapon feel like a real upgrade at ~2.6× Static Pulse DPS?
- Epsilon tone: creative, playful, internally coherent, occasionally funny, never pure "lol random." Needs real outputs to judge.
- Does a GoldSrc room built from generated primitives actually read as 1998, or just as untextured boxes? The theme material sets are the lever.
- Is 2.6 m the right flat gap now that the bound is honest? It is smaller than v0.4 advertised because v0.4 was wrong, not because the jump changed.
- A real title for the game.
- Finale threshold: is 24 of 29 the right amount of campaign before the ending?
- `WAITING_FOR_AP`: does it read as intentional, or as the game being broken?
- Epsilon Static: is the accumulating Hub corruption satisfying, or just noise?
- The reveal: does it land?
