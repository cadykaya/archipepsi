# Complete Design Proposals

Five complete, mutually exclusive resolutions of the Archipepsi player and dungeon authorities. **None of them is canon.** Exactly one is expected to be selected — optionally with named sections merged in from the others — and promoted to `docs/authorities/` before implementation begins.

## Read in this order

| File | What it is |
|---|---|
| [`00_ZERO_GUESSWORK_STANDARD.md`](00_ZERO_GUESSWORK_STANDARD.md) | The bar all five must clear, and the audit that proves it. Read this first — it defines what "complete" means here. |
| `01_RELIABLE_CORE.md` | Design 1. Finite typed catalogs, expensive systems deferred, minimum migration risk. The conservative baseline. |
| `02_PHYSICS_IS_THE_GAME.md` | Design 2. Object manipulation as the central verb; combat, traversal, and puzzles all resolve through it. |
| `03_THE_DUNGEON_IS_ONE_MACHINE.md` | Design 3. Macro-state and cross-room signal routing as the headline. Bets on the system Design 1 cuts. |
| `04_EPSILON_IS_THE_CONTENT.md` | Design 4. Generated Weapons, Abilities, Gear, and Mods are the game; everything else is a substrate for showing them off. |
| `05_STATUS_AS_GRAMMAR.md` | Design 5. Status is a rule-changing language rather than a damage tax, and the whole combat system is built on it. |

## Source material

The proposals resolve two authority documents, both in [`../authorities/`](../authorities/):

- **`PLAYER_DESIGN_AUTHORITY_v1.0.md`** — canonical player target. Body, controls, the Epsilon device, Echoes, interaction, combat resources, damage, crit, Status, Gear, Mods, loadout, capability progression, HUD, presentation, migration.
- **`DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`** — canonical environmental target. Room verbs, machinery, physical systems, signals, puzzle composition, dungeon state, procedural composition.

Where those two documents state an architectural law, every proposal inherits it unchanged. The proposals differ in how they resolve what the authorities left open — and they leave nothing open themselves.

## Reference

[`_reference/gpt5_reliable_core_INCOMPLETE.md`](_reference/) is a salvaged third-party draft, kept for structural reference only. It is not canon, is not complete, and should not be implemented from. See the banner at the top of that file.

## Status

| Proposal | State |
|---|---|
| 00 — Standard | Complete |
| 01 — Reliable Core | Not started |
| 02 — Physics Is The Game | Not started |
| 03 — The Dungeon Is One Machine | Not started |
| 04 — Epsilon Is The Content | Not started |
| 05 — Status As Grammar | Not started |
