# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

## Current frontier
- Branch: `claude/archipepsi-build-inzshp`
- v0.7 POC: complete
- Echoes 2.0 S1 + S1.1 + S2: complete
- S3: **complete** — resources, 15 HUD channels, safe palette (retuned after
  a real collision), sha256 source glyphs, §7 pressure valve, archive
  provenance chains, stage tripwires. All proven by `make godot-hud` +
  `test_hud_contract.py` + `test_stage_tripwires.py`.
- **Next: S4 rule engine** (IMPLEMENTATION_PLAN §2.5): events, conditions,
  costs, effects, edge derivation, deferred dispatch, cooldowns, per-tick
  cap. S4 is what first SPENDS a resource.

## Stage dependency trap
S3 Resources alone unlocked **no** additional Action verb. Rules/costs/events are S4. Links/traits/statuses are S5. `DEFERRED_PRIMITIVES` must name the **last** required dependency stage, not the first.

`beam_sustained`/`hover`/`block`/`restore_resource` stay gated through S4 as well: they need `powers`/`fills` LINKS (S5), not just rules.

## Standing tripwires (deliberate, will fire on stage advance)
- `test_stage_tripwires.py` fails when LINK ops or any non-CREATE op become
  implementable; each failure's docstring names the work due in that same
  change (hud_driver S5 valve case; `over_soft_budget` onto the request).
- Cross-language pins: glyph indices, palette names, channel count
  (`test_hud_contract.py` ↔ `hud_driver.gd`), theme rule
  (`test_theme_agreement.py` ↔ `integration_driver.gd`), runner arms
  (`test_runner_coverage.py`).

## Unresolved decision
Traits currently apply because they are owned, rather than only while equipped. Do not silently change this. Re-evaluate against the v0.8 contract when S5 makes the decision operational, and record any change in `docs/IMPLEMENTATION_DECISIONS.md`.

## Last full green verification
At S3 completion (this commit):
- `make test`: 247 passed
- `check_packet.py`: green, 10 docs
- `make godot-test`: GODOT CHAMBER TESTS OK
- `make godot-blink`: 5125 resolved / 17825 refused; GODOT BLINK TESTS OK
- `make godot-hud`: GODOT HUD TESTS OK
- `make godot-integration`: GODOT INTEGRATION OK, full 12-zone campaign

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->
