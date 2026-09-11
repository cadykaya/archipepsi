# Complete Design Proposals

Six complete resolutions of the Archipepsi player and dungeon authorities. **None of them is canon.** Exactly one is expected to be selected and promoted to `docs/authorities/` before implementation begins.

Proposals 1 through 5 are mutually exclusive. Proposal 6 is their union — it takes everything from all five and cuts one clause of one Status, which it names in its first two hundred words.

## Read in this order

| File | What it is |
|---|---|
| [`00_ZERO_GUESSWORK_STANDARD.md`](00_ZERO_GUESSWORK_STANDARD.md) | v1.1. The bar all six must clear, and the six-pass audit that proves it. Read this first — it defines what "complete" means here. |
| `01_RELIABLE_CORE.md` | Design 1. Finite typed catalogs, expensive systems deferred, minimum migration risk. The conservative baseline. |
| `02_PHYSICS_IS_THE_GAME.md` | Design 2. Object manipulation as the central verb; combat, traversal, and puzzles all resolve through it. |
| `03_THE_DUNGEON_IS_ONE_MACHINE.md` | Design 3. Macro-state and cross-room signal routing as the headline. Bets on the system Design 1 cuts. |
| `04_EPSILON_IS_THE_CONTENT.md` | Design 4. Generated Weapons, Abilities, Gear, and Mods are the game; everything else is a substrate for showing them off. |
| `05_STATUS_AS_GRAMMAR.md` | Design 5. Status is a rule-changing language rather than a damage tax, and the whole combat system is built on it. |
| `06_THE_AMALGAM.md` | Design 6. The union of all five, forced to work together. Design 3's model check at the centre, extended to prove physics and Status safe. The most expensive of the six by a wide margin. |
| [`06_THE_AMALGAM_AUDIT.md`](06_THE_AMALGAM_AUDIT.md) | The repair and rebase audit for Design 6. Read it to see what changed and why, including which external findings were stale-packet artifacts. |
| [`08_PLAYTEST_RECONCILIATION.md`](08_PLAYTEST_RECONCILIATION.md) | **Findings, not a proposal.** Design 6 against Production `96c450e` and the 2026-09-11 owner decisions, after the first human playthrough. Verifies the playtest's diagnoses, says which decisions the design already carries, and proposes the first branching slice. |
| [`09_ROOM_CONTRACT.md`](09_ROOM_CONTRACT.md) | **Draft for interface review.** The bridge/engine seam for multi-door rooms: shell capacity, room-instance assignment, persistent progress, how the sides talk, how they report failure, and the first slice's acceptance checks. |
| [`_checkers/`](_checkers/) | The scripts the audit's §9 cites. `run_all.sh` runs them all; a green run is evidence about the classes they check and nothing else. |
| [`07_ENGINE_RECONCILIATION.md`](07_ENGINE_RECONCILIATION.md) | **Findings, not a proposal.** All six checked against the live engine branch. Read it before treating any proposal as buildable — three of Design 6's systems are blocked at the substrate, and one finding applies to all six. |

## Source material

The proposals resolve two authority documents, both in [`../authorities/`](../authorities/):

- **`PLAYER_DESIGN_AUTHORITY_v1.0.md`** — canonical player target. Body, controls, the Epsilon device, Echoes, interaction, combat resources, damage, crit, Status, Gear, Mods, loadout, capability progression, HUD, presentation, migration.
- **`DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`** — canonical environmental target. Room verbs, machinery, physical systems, signals, puzzle composition, dungeon state, procedural composition.

Where those two documents state an architectural law, every proposal inherits it unchanged. The proposals differ in how they resolve what the authorities left open — and they leave nothing open themselves.

## Choosing between them

| If you want | Read |
|---|---|
| The shortest road to a playable build | 01 |
| Object manipulation as the thing the game is about | 02 |
| A dungeon that reconfigures and a verifier that proves it safe | 03 |
| Generated items as the content, with Forge | 04 |
| Status as a language the player speaks | 05 |
| All of it, and the build time that costs | 06 |
| To know what any of them would actually cost against the code that exists | **07 first** |

## Reference

[`_reference/gpt5_reliable_core_INCOMPLETE.md`](_reference/) is a salvaged third-party draft, kept for structural reference only. It is not canon, is not complete, and should not be implemented from. See the banner at the top of that file.

## Status

| Proposal | State |
|---|---|
| 00 — Standard | Complete — ~3.5k words |
| 01 — Reliable Core | **Complete** — ~34.0k words, audited, 142/142 authority tests traced |
| 02 — Physics Is The Game | **Complete** — ~23.4k words, audited, 142/142 authority tests traced |
| 03 — The Dungeon Is One Machine | **Complete** — ~16.6k words, audited, 142/142 authority tests traced |
| 04 — Epsilon Is The Content | **Complete** — ~15.5k words, audited, 142/142 authority tests traced |
| 05 — Status As Grammar | **Complete** — ~13.8k words, audited, 142/142 authority tests traced |
| 06 — The Amalgam | **Repaired, rebased, promotable** — ~49.2k words, re-audited across five passes, 142/142 traced, rebased on the 2026-09-04 `shell_id` ruling and carrying the four owner rulings of 2026-09-05. Its first line still reads *not canon*; promotion is the owner's action |
| 06 — Repair audit | **Complete** — `06_THE_AMALGAM_AUDIT.md`, ~8.8k words, five passes, every repair with old/new behaviour and regenerated counts |
| 09 — Room Contract | **Draft** — awaiting Prod's interface review. Three separated layers, typed failure reporting, 15 acceptance checks |
| 08 — Playtest Reconciliation | **Complete** — the seven owner decisions against Design 6, two playtest findings falsified, and a bounded first slice |
| 07 — Engine Reconciliation | **Complete** — ~3.5k words, the six checked against `claude/archipepsi-echoes-continuation-b1adno` at `df2bb58`, plus four update sections (§8a–§8d) recording later rulings and one correction |
