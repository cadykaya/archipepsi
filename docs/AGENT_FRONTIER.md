# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

## Current frontier
- Branch: `claude/archipepsi-build-inzshp`
- v0.7 POC: complete
- Echoes 2.0 S1 + S1.1 + S2 + S3: complete
- S4: complete — the ECHOES §5 rule interpreter (`rule_runtime.gd`,
  `make godot-rules`, I5 proven: edge latches, deferral, cooldown-bounded
  oscillation, per-tick cap, cost atomicity, alias resolution); fold
  validates rule resource references (I11 treatment); capability gate
  opened `rule` with per-piece §5 allowlist gates; game-event wiring
  (incl. new chamber tracking); fallback grants a FLASK (low_health
  auto-heal rule) and a kill-fed CELL (self-discharging shield rule); I8
  proven and the fallback is budget-aware; integration asserts the
  campaign ends owning folded resources AND rules.
- S5: **complete** — the nine-stat derived stack with I3's floors
  (`stat_stack.gd`, `make godot-stats`), per-target statuses
  (`status_effects.gd`), all four link kinds walking in the runner, the
  last six verbs (`beam_sustained`/`hover`/`block`/`restore_resource`/
  `scan_mark`/`cleanse`), I7 enforced by the trait model, and the
  §5 status rule vocabulary. Both S3 tripwires discharged.
- **Next: S6 dispositions** (IMPLEMENTATION_PLAN §2.5): `UPGRADE` /
  `MODIFY` / `LINK` / `MERGE` as things a PROVIDER may emit (the fold has
  always folded them; the capability gate still refuses upgrade, modify
  and merge), families and Mk levels, source identity packages. This is
  the stage that makes the archive's provenance chains reachable from
  real play rather than only from fixtures.

## Stage dependency trap
`pull_pickup` is the ONLY verb still deferred: it collects local rewards, which are S9. `DEFERRED_PRIMITIVES` must name the last required stage, not the first.

## Standing tripwires (deliberate, will fire on stage advance)
- `test_stage_tripwires.py` now guards the S9 boundary (affordances and
  Info readouts); its docstring names the work due when it fires. The two
  S3-era tripwires fired at S5 and were paid — that test is their receipt.
- Cross-language pins: glyph indices, palette names, channel count
  (`test_hud_contract.py` ↔ `hud_driver.gd`), theme rule
  (`test_theme_agreement.py` ↔ `integration_driver.gd`), runner arms
  (`test_runner_coverage.py`).

## Resolved at S5 (was the standing unresolved decision)
Traits apply because they are OWNED — unchanged, and now deliberate
rather than inherited. S5 added the escape hatch the contract always
intended: `requires_equipped` makes a trait conditional on a slot, and
I7 now *requires* it for any severe downside (enforced by the trait
model, not merely described). Ownership is the default; equipping is the
modifier. Recorded in `docs/IMPLEMENTATION_DECISIONS.md` (S5).

## Last full green verification
At S5 completion (this commit):
- `make test`: 265 passed
- `check_packet.py`: green, 10 docs
- `make godot-test`: GODOT CHAMBER TESTS OK
- `make godot-blink`: 5125 resolved / 17825 refused; GODOT BLINK TESTS OK
- `make godot-hud`: GODOT HUD TESTS OK
- `make godot-rules`: GODOT RULES TESTS OK
- `make godot-stats`: GODOT STATS TESTS OK (I3, 300-round seeded sweep)
- `make godot-integration`: GODOT INTEGRATION OK, full 12-zone campaign,
  asserting folded resources, rules AND a powers link at campaign end

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->
