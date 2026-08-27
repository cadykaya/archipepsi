# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

## Current frontier
- Branch: `claude/archipepsi-build-inzshp`
- v0.7 POC: complete
- Echoes 2.0 S1 + S1.1 + S2 + S3: complete
- S4: **complete** — the ECHOES §5 rule interpreter (`rule_runtime.gd`,
  `make godot-rules`, I5 proven: edge latches, deferral, cooldown-bounded
  oscillation, per-tick cap, cost atomicity, alias resolution); fold
  validates rule resource references (I11 treatment); capability gate
  opened `rule` with per-piece §5 allowlist gates; game-event wiring
  (incl. new chamber tracking); fallback grants a FLASK (low_health
  auto-heal rule) and a kill-fed CELL (self-discharging shield rule); I8
  proven and the fallback is budget-aware; integration asserts the
  campaign ends owning folded resources AND rules.
- **Next: S5 traits/links/statuses** (IMPLEMENTATION_PLAN §2.5): derived
  stat stack with clamps, the four link kinds, player and enemy statuses.
  S5 un-gates `beam_sustained`/`hover`/`block`/`restore_resource` and
  FIRES BOTH STAGE TRIPWIRES (see below) plus parts of the §5 rule
  vocabulary (`status_applied`, `status_active`, `apply_status`,
  `trait_pulse`) and the S1.1 test's status gate assertion.

## Stage dependency trap
Rules landed (S4) but the four powered/filled verbs need `powers`/`fills` LINKS — S5, their LAST dependency. `DEFERRED_PRIMITIVES` must name the last required stage, not the first.

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
At S4 completion (this commit):
- `make test`: 263 passed
- `check_packet.py`: green, 10 docs
- `make godot-test`: GODOT CHAMBER TESTS OK
- `make godot-blink`: 5125 resolved / 17825 refused; GODOT BLINK TESTS OK
- `make godot-hud`: GODOT HUD TESTS OK
- `make godot-rules`: GODOT RULES TESTS OK
- `make godot-integration`: GODOT INTEGRATION OK, full 12-zone campaign,
  now asserting folded resources + rules exist at campaign end

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->
