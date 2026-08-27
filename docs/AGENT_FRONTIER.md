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
- S5: complete — the nine-stat derived stack with I3's floors
  (`stat_stack.gd`, `make godot-stats`), per-target statuses
  (`status_effects.gd`), all four link kinds walking in the runner, the
  last six verbs (`beam_sustained`/`hover`/`block`/`restore_resource`/
  `scan_mark`/`cleanse`), I7 enforced by the trait model, and the
  §5 status rule vocabulary. Both S3 tripwires discharged.
- S6: complete — the operation vocabulary is whole. The capability
  gate admits `upgrade`/`modify`/`merge`; `target_errors` checks a
  disposition can land at GENERATION (repair loop) as well as at fold
  (I11); the request carries the owned component graph with per-field
  upgrade headroom; the fallback evolves families (ECHOES §11's own
  Hookshot→Longshot→Clawshot example is reachable from
  `--epsilon=fallback`); I10 alias soundness proven; §12 identity
  packages complete (sound family, particle style) and pinned from both
  sides.
- S7: complete — four slots, four runtimes, four keys (RMB / MMB+F /
  Shift / C). `IMPLEMENTED_ACTION_SLOTS` is the whole contract;
  `SLOT_NAMES` shared through `constants.py`; the S1.1 `ARCHETYPE_SLOT`
  collapse retired (migrated mobility Echoes go back to Shift); the HUD
  shows all four slots with Mk levels; the archive names the key each
  button lands on, compares against what it would replace, and marks
  favourites (client preference, `user://loadout.cfg`, never campaign
  state); the wheel cycles favourites within the highlighted slot.
- S8: **complete** — the Echo Lab, a walk-in Hub annexe (never a Zone,
  never a Check): dummy that cannot die or farm `kill` events, tall wall
  with height bands, measured runway, gap with a safe return, armed
  hazard through the production damage path, deterministic moving target,
  reset pad that clears transient state only. `make godot-lab` proves it
  and proves the negative: a full session sends no intent and moves no
  campaign truth. ChatGPT/GPT-5.6 Sol's build brief is cherry-picked at
  `docs/proposals/S8_ECHO_LAB_BUILD_BRIEF.md`.
- S9: **complete** — the seven world affordances build as real geometry
  (`affordance_features.gd`, `affordance_nodes.gd`), each paid for by an
  owned capability (I12, `owned_affordance_tags` over OWNED mechanics);
  features never touch the mandatory path (I4 — the schema keeps them out
  of reward chambers and gating objectives, the builder keeps them out of
  the walking lane, and a room too narrow to have a "beside the path" gets
  none); every feature holds a `LocalRewardPickup` and never an AP reward
  (I13); movement volumes write into a player environment layer that
  cannot trap you (`MIN_VOLUME_SPEED_SCALE`, upward-only lift); the ten
  §14.1 readouts draw from the fold in `readouts.gd`, observing only —
  proven by a frozen-world frame that moves nothing and sends no intent.
  `pull_pickup` is implemented, so **nothing is gated any more**:
  `DEFERRED_PRIMITIVES` is empty and every registry equals its contract.
  `make godot-affordance` is the suite.
- **Next: S10 interpretation pipeline** (IMPLEMENTATION_PLAN §2.5):
  concepts, modes and budgets in the Claude provider, and a mock provider
  rich enough to keep the integration run meaningful.

## Stage dependency trap
A live one: a chamber carrying an affordance feature must be at least `MIN_FEATURE_CHAMBER_WIDTH` (5.2 m) wide, and only a corridor can carry one at all — every other chamber type has a Check or a gating objective. A generator that hangs a feature on a default-width connector gets its Zone refused. The fallback widens its own connectors; anything else must too.

Retired at S9: every verb in the catalog runs, and `DEFERRED_PRIMITIVES` is empty (deliberately, so the partition test in `test_schemas.py` stays true rather than vacuous). The rule it encoded still applies to whatever is deferred next — name the LAST required stage, not the first.

## Standing tripwires (deliberate, will fire on stage advance)
- `test_stage_tripwires.py` is now all receipts: the S3 pair fired at S5,
  the S9 pair fired at S9, and each is recorded as discharged. Nothing is
  gated, so `test_the_registry_still_runs_even_though_it_gates_nothing`
  is what keeps the mechanism from being refactored away — it narrows the
  registry by hand and watches it refuse. The same trick keeps the
  primitive gate visible in `test_schemas.py` and `test_s1_review_fixes.py`
  (both pass a narrowed `implemented_primitives` through the seam the
  signature already provides).
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
At S9 completion (this commit):
- `make test`: 307 passed
- `check_packet.py`: green, 10 docs
- `make godot-test`: GODOT CHAMBER TESTS OK
- `make godot-blink`: 5125 resolved / 17825 refused; GODOT BLINK TESTS OK
- `make godot-hud`: GODOT HUD TESTS OK
- `make godot-rules`: GODOT RULES TESTS OK
- `make godot-stats`: GODOT STATS TESTS OK (I3 sweep, links, S7 slots)
- `make godot-lab`: GODOT LAB TESTS OK (fixtures, and no campaign mutation)
- `make godot-affordance`: GODOT AFFORDANCE TESTS OK (I4 lane sweep, the
  seven built, volumes that cannot trap, readouts that only read)
- `make godot-integration`: GODOT INTEGRATION OK, full 12-zone campaign;
  every interpretation credited in some provenance chain, components at
  Mk II+, Actions reaching several slots, the Hub's Lab present and inert,
  affordance features offered and built, and a local reward earned and
  recorded without touching a single AP location

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->
