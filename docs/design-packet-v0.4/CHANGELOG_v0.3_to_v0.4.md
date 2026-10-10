# v0.3 → v0.4 — every finding and its resolution

Traceability for the 50 findings in `../audit/PASS_1_AUDIT.md`, which merged Skyiah + ChatGPT's 24-item list with a parallel Opus audit.

Status: **Fixed** · **Decided** (was an open question) · **Documented** (correct behavior, now written down) · **Open** (deferred, see `DECISIONS_TO_REVIEW.md`).

---

## The five decisions

| # | Decision | Resolution |
|---|---|---|
| **D1** (B1) | Archipelago dependency | Pinned source checkout at tag `0.6.7`, obtained by `bridge/bootstrap.py`, overridable with `ARCHIPELAGO_ROOT`. Not a hand-rolled client: a project that just demonstrated it misreads the protocol should not own a second implementation of it. `TECHNICAL_ARCHITECTURE.md` §4 |
| **D2** (B2) | Campaign state location | Moved to Python. The bridge owns persistent campaign truth; Godot owns the frame-to-frame videogame. Ownership table in `TECHNICAL_ARCHITECTURE.md` §2 |
| **D3** (G12) | Finale unlock | 2 Pepsi Keys **and** 24 of the other 29 Checks. Check 030 fully reserved; dedicated single-Check finale Zone. `DESIGN.md` §10.6 |
| **D4** (B4) | Gameplay constants | Appendix A adopted as binding, in `schemas/constants.py`, with `SAFE_BASE_JUMP_GAP` derived from the jump arc and asserted by test |
| **D5** (G1/G2) | Starvation and Zone exit | `WAITING_FOR_AP` Hub mode with reservation release; auto-appended exit portal, pause-menu Return to Hub, transient-only reset. `DESIGN.md` §13.1, §14 |

---

## Blockers

| ID | Finding | Status | Where |
|---|---|---|---|
| B1 | `CommonContext` not obtainable | **Decided** | `TECHNICAL_ARCHITECTURE.md` §4 |
| B2 | Critical logic in the untestable half | **Decided** | `TECHNICAL_ARCHITECTURE.md` §2 |
| B3 | Scope exceeds one session | **Fixed** | Success criterion reframed as "advance the slice, never break it"; T−60 rule; resequenced order. `IMPLEMENTATION_PLAN.md` §1 |
| B4 | No gameplay numbers | **Decided** | `schemas/constants.py` |
| B5 | Goal check purchasable / buriable | **Fixed** | Check 030 excluded from shop eligibility (`DESIGN.md` §11.3) and normal allocation (§10.4); reserved for the finale Zone (§10.6). Asserted by acceptance tests 22–23 |

---

## Correctness

| ID | Finding | Status | Resolution |
|---|---|---|---|
| C1 | Resent checks never confirm | **Fixed** | Finalization is reconciliation against `checked_locations`, never an event wait. Bridge answers `claim_check` from current state, plus a reconcile timer. `TECHNICAL_ARCHITECTURE.md` §5 — given its own section because it is the most misread mechanism in the design |
| C2 | Shop rollback keys on a non-existent packet | **Fixed** | Real trigger: the location is absent from `missing ∪ checked` after a full snapshot. `DESIGN.md` §11.7 |
| C3 | `!collect` Echo storm | **Fixed** | Bulk-confirmation guard: auto-generate only for claimed locations; lazy generation otherwise; ≤1 concurrent, ≤3 per load. `DESIGN.md` §15.1 |
| C4 | Origin region named `Start` | **Fixed** | `origin_region_name` made explicit, called out as a hard generation failure. `APWORLD_SPEC.md` §3, test 40 |
| C5 | `archipelago.json` unspecified; hand-rolled build | **Fixed** | Literal manifest given; AP's own Build APWorlds component used; hand-writing `version`/`compatible_version` explicitly forbidden. `APWORLD_SPEC.md` §8 |
| C6 | Recipient game leaks before play | **Documented** | Stated as intended. `DESIGN.md` §10.1 |
| C7 | AP strings are untrusted prompt input | **Fixed** | Clamp, strip, delimited data block with explicit framing. `EPSILON_SPEC.md` §11.5, `TECHNICAL_ARCHITECTURE.md` §14 |
| C8 | PRNG recipe undefined | **Fixed** | `prng_seed()` = SHA-256 → first 8 bytes → big-endian int; written-out Fisher–Yates. Pinned by test with a literal expected seed |

---

## Contradictions

| ID | Finding | Status | Resolution |
|---|---|---|---|
| X1 | Input double-booked | **Fixed** | LMB always Pepsi Pop, RMB the Echo. Rationale recorded in `DESIGN.md` §7 |
| X2 | "`arena` is not a separate chamber type" | **Fixed** | Corrected to `boss_arena`. `EPSILON_SPEC.md` §3 |
| X3 | Validator checks a field the request lacks | **Fixed** | `zone_id` added to the request; validator matches it. `EPSILON_SPEC.md` §9 |
| X4 | Test A asserts on the wrong Check | **Fixed** | Uses Check 001 throughout, from the canonical fixture |
| X5 | Four inconsistent example fixtures | **Fixed** | One canonical table, `IMPLEMENTATION_PLAN.md` §3.1, used everywhere |
| X6 | Mixed-Track Zones have no `target_game` | **Fixed** | Defined as the Track that initiated selection; per-location recipient games also passed. `DESIGN.md` §10.5 |
| X7 | `save_version: 2` on a greenfield project | **Fixed** | Starts at 1; `schema_version` tracks the packet separately |
| X8 | `epsilon_creativity` absent from the save | **Fixed** | Field on `CampaignSave` |
| X9 | Stale embedded handoff | **Fixed** | Rewritten to point at the precedence order; the "one file is the authority" line is gone |
| X10 | Shop flavor has no provider method | **Fixed** | Cut. Shop copy is fixed and authored. `DESIGN.md` §11.6 |

---

## Gaps

| ID | Finding | Status | Resolution |
|---|---|---|---|
| G1 | No starved-pool state | **Decided** | `WAITING_FOR_AP` with the reservation-release rule and the never-starve stocking rule |
| G2 | No way out of a Zone | **Decided** | Auto-appended exit portal, pause-menu Return to Hub, transient-only reset, resume semantics |
| G3 | `kill_all` vs respawn | **Fixed** | Objective completion latches for the Zone's lifetime. `DESIGN.md` §9 |
| G4 | Saves not atomic | **Fixed** | temp → fsync → rename, one `.bak`, parse-failure recovery |
| G5 | Godot needs Python even for Mock | **Documented** | Accepted. The bridge is authoritative in v0.4, so Godot depending on it is now structural rather than incidental |
| G6 | No bridge reconnect/heartbeat | **Fixed** | Backoff policy, `BRIDGE OFFLINE` display, in-flight requests abandoned not retried. `TECHNICAL_ARCHITECTURE.md` §9.1 |
| G7 | Versions unpinned | **Fixed** | Godot 4.5.1 stable (`f62fdbde1`), Python 3.11.15, Archipelago 0.6.7 — the versions actually installed, confirmed by the developer |
| G8 | No Godot test runner | **Decided** | No addon. Headless `--script` tests limited to what they can genuinely assert; the rest listed as manual. `ACCEPTANCE_TESTS.md` §5, §7 |
| G9 | Schemas promised, not written | **Fixed** | `schemas/` ships as runnable, tested Pydantic; JSON Schema and `constants.gd` are generated from it |
| G10 | Epsilon Static does nothing | **Fixed** | Cosmetic Hub corruption + a counter Epsilon can reference. Explicitly non-logic |
| G11 | No LICENSE / `.gitignore` / CI | **Partly fixed** | `.gitignore` contents specified. LICENSE still **Open** |
| G12 | Finale unlock undecided | **Decided** | D3 |
| G13 | Save can't hold an allocated-ungenerated Zone | **Fixed** | `ZoneRecord` lifecycle with `allocated_location_ids` at `PENDING_GENERATION`; those locations excluded from shop eligibility. Tests 18–19 |
| G14 | Echo effect compatibility undefined | **Fixed** | Initiators / modifiers / passives with three rules, enforced structurally in `echo.py` |
| G15 | Passive Echoes carry a cooldown | **Fixed** | Discriminated union; `PassiveEcho` has no `cooldown` field at all |
| G16 | Art sourcing undefined | **Fixed** | Explicit "do not go asset shopping" rule; procedural textures. `DESIGN.md` §20 |
| G17 | Claude API access is an unlisted prerequisite | **Documented** | Stated in `TECHNICAL_ARCHITECTURE.md` §10.2, with the fallback degradation |

---

## Feel, scope, limits

| ID | Finding | Status | Resolution |
|---|---|---|---|
| F1 | Fun rests on the reveal | **Documented** | `DESIGN.md` §16 makes it core, not polish; called out again in the handoff |
| F2 | Combat pacing unbounded | **Fixed** | Enemy stats bound the worst legal Zone to ~25s; asserted by test |
| F3 | Shop may not appear live | **Documented** | Test C must pass under `--ap=mock` |
| F4 | Goal gated on other players | **Fixed** | Solo testing YAML added. `APWORLD_SPEC.md` §7.1 |
| F5 | Session length unestimated | **Open** | Target ~40 min recorded as a manual check |
| S1 | Riskiest work scheduled third | **Fixed** | Resequenced: APWorld → bridge/AP → Godot → catalogs → Epsilon → shop |
| S2 | Two mock axes blended | **Fixed** | `--ap` and `--epsilon` independent |
| S3 | No stopping rule | **Fixed** | T−60 rule |
| L1 | Save deletion restores coins | **Documented** | `DESIGN.md` §18 |
| L2 | Duplicate Echoes | **Decided** | Confirmed intentional; inventory shows source location so duplicates read as distinct |

---

## What v0.4 added that no finding asked for

- **Reject-never-clamp.** v0.3 allowed clamping "otherwise semantically valid" numbers. A clamped Zone is one nobody designed, and it poisons the generation archive meant to become the local-model benchmark.
- **`extra="forbid"` everywhere.** An invented field now fails loudly instead of being silently dropped, so a hallucinated mechanic can never quietly do nothing.
- **Godot is not an authority.** A `claim_check` is a request the bridge re-verifies, not a fact.
- **Fallback output goes through the same validator as model output.** No exceptions, which makes the fallback a genuine test oracle.
- **`constants.gd` is generated.** The engine cannot drift from the numbers the validator enforces.
- **Echo inventory shows the source location**, so two Hookshot Echoes read as distinct rather than duplicated.
- **Debug grant commands are mock-AP only** and rejected in live mode.

---

## Counted

50 findings: **31 fixed**, **9 decided**, **8 documented**, **2 open** (`G11` LICENSE, `F5` session length). Neither open item blocks the build.
