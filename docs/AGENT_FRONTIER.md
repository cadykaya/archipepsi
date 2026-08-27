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
- S10: **complete** — §15's chain (`item -> concepts -> supported systems
  -> validated recipe`) is real. `epsilon/concepts.py` is the
  deterministic reader; it reproduces §15's own three worked examples
  (*Water Tunic*, *BLJ*, *Master Sword*) and a test asserts the prose
  still uses them. The fallback reads every item and labels itself with a
  mode **derived from what its operations did**, so the archive cannot
  misdescribe an Echo; mock Epsilon says the reading out loud. The mode is
  a fact, never a preference — creativity steers via `preferred_modes` in
  the request rather than capping the label. `reading_errors` refuses an
  empty reading and one sharing no vocabulary with the item, and nothing
  else: taste is the provider's job. §16 is now counted in the units the
  prose states (affordances in **distinct tags**), the request carries
  `budget_headroom` and `relevance_hint`, and the Claude prompt states the
  pipeline, the four modes and the budgets instead of leaving them to be
  inferred. The archive shows the mode.
- **Adversarial review of S6–S10: done, all findings fixed.** Two passes
  (client and bridge). The deepest: the affordance geometry was designed
  and tested in an 18×20 arena, which the schema refuses for features —
  **a corridor is the only chamber that can ever host one**, and four of
  seven rewards sat above its 3.6 m ceiling. Reworked around per-tag
  footprints, extent-based lane clearance, and corridors built to the
  height their features declare. Also: an advertised upgrade bound the
  model would not honour (a `FoldError` no retry could pass, the one
  save-integrity bug), a `Damageable` concept that was missing so the
  breakable wall could not be hit by anything, a concept validator wrong
  in both directions, a mode that called self-contained Echoes "systemic",
  a tag dropped from every Zone forever, and claimed rewards respawning.
  All sabotage-proven. See `docs/IMPLEMENTATION_DECISIONS.md`.
- **Next: the plan is exhausted.** IMPLEMENTATION_PLAN §2.5 ends at S10
  ("Deployables come after S10, if at all"). Per the standing handoff, do
  not stop here — continue developing the game, and stop only where
  continuing would require inventing an architecture decision the contract
  does not answer (document that decision instead of guessing).

## Open decision, deliberately not guessed
`challenge_marker` (§14.2) and its `challenge_timer` readout (§14.1) have a complete bridge half — grantable, recorded, `best_seconds` improves — and no world half, because neither section says where a run starts, what ends it, or what counts as one. `test_stage_tripwires.py::test_the_challenge_marker_still_has_no_challenge` names the decision and comes due when it is made.

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
- `make test`: 343 passed
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
  affordance features offered and built, a local reward earned and
  recorded without touching a single AP location, and all 26
  interpretations reading their item in four different modes

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->
