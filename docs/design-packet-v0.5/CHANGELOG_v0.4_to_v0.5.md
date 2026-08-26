# v0.4 → v0.5 — every finding and its resolution

Traceability for the 62 findings in `../audit/PASS_3_INDEPENDENT_AUDIT.md`, produced by four reviewers who did not design v0.4 and could not see each other's work.

Plus two product-direction changes Skyiah made alongside: the visual retarget and the terminology purge.

Status: **Fixed** · **Decided** · **Documented** · **Open**.

---

## Product decisions

| # | Decision | Where |
|---|---|---|
| **P1** | Goaling does not end play. Confirming Check 030 reports goal and shows the victory presentation; the campaign continues in postgame with the portal live until every Check is cleared or the player stops. No unchecked AP location is ever abandoned because the goal fired. | `DESIGN.md` §13.3 |
| **P2** | Visual target is a **late-1990s PC FPS** (GoldSrc/Quake-era brushwork), explicitly not Minecraft. Chunky low-poly prisms and wedges, industrial rooms, harsh lighting, 64×64 procedural textures (bounded 32–128). Same zero-asset pipeline. | `DESIGN.md` §3.4, §20 |
| **P3** | Terminology purge. `Pepsi Key` → **Signal Key**, `Pepsi Pop` → **Static Pulse**. Epsilon Coin and Epsilon Static keep their names. *Archipepsi* remains the project codename only. | `constants.py`, throughout |

**On P3's coherence:** Epsilon transmits, Static is the noise it leaves, your baseline weapon fires that noise, Keys open more signal. Static Pulse and Epsilon Static sharing a word is deliberate — the weakest thing in the game is made of the garbage Epsilon leaves lying around.

**On P3's timing:** item names are Archipelago item names, present in `item_name_to_id`, slot data, every player's YAML and every other client's data package. Renaming after a seed is rolled breaks that seed. v0.5 is the last free moment.

---

## Critical

| ID | Finding | Status | Resolution |
|---|---|---|---|
| C1 | `GENERATED` Zones orphan AP locations; two events make the campaign unwinnable | **Fixed** | `active_zone_id` is set when the Zone is **saved**, not entered. `enter_zone` intent added; `ZONE_READY` Hub mode added; `ZoneRecord.holds_locations` drives eligibility; §8 reconciliation covers every state explicitly. Tests: `test_terminal_states_release_their_locations`, `test_pending_generation_holds_its_allocation_without_a_zone`; acceptance Test L |
| C2 | Shop can be charged repeatedly for one location | **Fixed** | §11.7 step 1 now verifies four conditions including "no `PendingCheck` exists for it, from any source". `ShopStockItem.status` added so the snapshot can express an in-flight purchase and Godot can disable the control. `CampaignSave` rejects two pending checks for one location. Acceptance Test O |
| C3 | No abandon path for an unfinishable Zone | **Fixed** | `abandon_zone` intent and terminal `ABANDONED` state; unclaimed locations return to the pool, confirmed Checks survive. `ENEMY_FALL_KILL_Y` removes the likeliest trigger. Acceptance Test M |
| C4 | Goaling abandons up to five real AP locations | **Fixed** | P1. `CAMPAIGN_COMPLETE` removed from `HubMode`; `goal_sent`/`postgame` are flags, `ALL_CHECKS_CLEARED` is reached only when everything is confirmed. Test `test_goal_does_not_end_play`; acceptance Test N |
| C5 | A legal passive Echo makes mandatory traversal impossible | **Fixed** | `GRAVITY_MULT_MAX = 1.0` (gravity Echoes only ever help) and `SPEED_MULT_MIN = 0.9`, both derived from the traversal bounds. `test_worst_legal_passive_loadout_still_clears_every_mandatory_jump` |

---

## Major

| ID | Finding | Status | Resolution |
|---|---|---|---|
| M1 | Real traversal margin was 1.17×, not 1.56× | **Fixed** | `max_safe_gap(step)` is a joint bound enforced by `PlatformPathChamber`; `jump_reach()` defaults to the worst legal loadout; `_floor1` replaces `round` so a safety floor cannot round up. `SAFE_BASE_JUMP_GAP` is now 2.6 (2.0 at max step) — the honest number |
| M2 | Post-parse mutation bypassed every bound | **Fixed** | `validate_assignment=True` on all three `Strict` bases. `PrimaryEcho` restructured to `initiator` + `modifiers`, so "exactly one initiator" is arity rather than a count check — and the exported JSON Schema now carries it |
| M3 | `import CommonClient` runs pip and can block on `input()` | **Fixed** | `SKIP_REQUIREMENTS_UPDATE=1` before import, in §4.3, §15 and the handoff |
| M4 | AP counters read zero while disconnected | **Fixed** | Bridge retains last-known normalized state; `ap_state_is_current` flag added; sync warning only after a completed reconciliation. §4.6, §12, acceptance Test P |
| M5 | `on_package` is synchronous | **Fixed** | §5 and §15: plain `def`, schedule via `create_task`, hold the reference |
| M6 | Zone-source pending checks had no terminal failure state | **Fixed** | Capture `check_locations()`'s return; empty-and-unchecked is terminal. §5 |
| M7 | Shop rollback fired at every bridge start | **Fixed** | Evaluated only inside the reconnect reconciliation pass, never on a raw snapshot. §11.7 |
| M8 | Solo seed produces zero Echoes and no shop | **Documented** | Prominent warning in `APWORLD_SPEC.md` §7.1 and `DESIGN.md` §18 |
| M9 | Finale startable while a Zone is `ACTIVE` | **Fixed** | `HubStatus` rejects `finale_available` while a Zone is held. `test_finale_is_not_offered_while_a_zone_is_held` |
| M10 | Zone completion ran its steps twice or zero times | **Fixed** | One idempotent procedure keyed on record state, triggered by Check confirmation. `exit_zone` demoted to pure travel and is a no-op on a complete Zone. Track cursor advances only here |
| M11 | Phase 2's milestone depended on Phase 4 | **Fixed** | Fallback generators and `MockEpsilonProvider` moved into Phase 2, before the smoke test |
| M12 | No way to install the world, generate a seed, or host | **Fixed** | `TECHNICAL_ARCHITECTURE.md` §8.5: literal Makefile targets, plus the partner-world requirement (≥10 locations to absorb 10 non-local Coins) |
| M13 | `test_schemas.py` broke under the mandated copy | **Fixed** | Same relative-with-fallback shim as the modules; verified standalone and nested. `__pycache__`/`.pytest_cache` untracked and gitignored |
| M14 | Prose claimed two rules the schema did not implement | **Fixed** | Per-chamber enemy cap enforced in `_WithEnemies`; corridor-reward rule enforced in `CorridorChamber` |
| M15 | Every unrevealed item name shipped to the client | **Fixed** | `ScoutedLocation.revealed`; identity fields omitted until revealed, enforced by validator. Recipient game stays early-revealed by design |
| M16 | Estimates overran the window by 1.4–1.9× | **Fixed** | Phase 3 re-estimated to 150 min; expected outcome stated plainly as **Phases 0–2** |
| M17 | Nothing verified the toolchain | **Fixed** | Phase 0 step 0, with an explicit fallback when Godot is absent: build 0–2, write Phase 3 unverified, say so |
| M18 | `ARCHIPELAGO_ROOT` bypassed the version pin | **Open** | Noted for the bootstrap pass; `verify()` should compare `Utils.version_tuple` against the tag and skip `ModuleUpdate` on that path |

---

## Minor

Fixed: m1 (`TIER_BOUNDS`, `tier_of`, `locations_in_tier`, `unlocked_location_ids` — with the APWorld and slot data told to derive from them), m2 (`ClaimCheck` docstring aligned to §2), m3 (objective latching scoped to the loaded scene instance in all three places), m4 (Test J reworded to `finale_available`), m5 (`coins_spent` restated as a monotonic accumulator), m6 (Track cursor advances only at completion), m7 (`zone_selection_seed` includes `team`), m8 (shuffle output pinned, not just the seed), m9 (reference-Echo test asserts real fields; prose corrected), m10 (jump-arc test asserts relationships; one marked literal pin), m11 (`ZoneRecord`/`CampaignSave` constrained; dangling references rejected), m12 (AP display strings bounded, `cost` non-negative), m13 (`featured_echo_ids` pattern-constrained), m14 (single `reveal` notification, `lines` raised to 12), m15 (`generation_in_progress` on `HubStatus`), m16 (provider line documented as read-only status), m17 (`ctx.finished_game`; "at least once" is the right invariant), m18 (`slot_concerns_self`, plus data-package fallback), m19 (`WAITING_FOR_AP` shop copy), m20 (shop cadence — release and restock in the same step), m23 (`export.py` fails loudly instead of dropping constants), m24 (`ServerMessage` exported), m26 (theme catalog agreement asserted by test), m28 (force units defined as m/s velocity change), m31 (Track key is `"Archipepsi"`; "Glitch Track" is display text), m32 (coverage added for both previously-unconstructed chamber types, JSON round-trips, and the protocol models), m34 (`is not None` filtering).

Documented: m30 (canonical fixture's self-recipient row is mock-only).

Open: m21, m22 (`bootstrap.py` interrupted-clone recovery and probe quoting), m25 (`ZoneGenerationRequest`/`EchoGenerationRequest` still have no Pydantic model), m27 (one export command, one destination), m33 (who launches the bridge).

---

## Delta re-audit (two fresh reviewers, v0.4 vs v0.5)

Verdicts on the five criticals: **shop double-charge** and **goal-ends-play** VERIFIED FIXED; **orphaned Zones**, **unfinishable Zone** and **passive-Echo traversal** confirmed correct *in the schemas* but PARTIALLY FIXED, because the prose still described v0.4. One reviewer brute-forced every legal `(gap_size, vertical_step)` pair at 1 cm resolution against the worst legal loadout: zero failures, tightest margin 1.563×.

The structural criticism was fair and is the lesson of this revision: **each fix landed in the code and in one prose location, and the other locations stayed at v0.4** — while this changelog asserted the fix landed everywhere. Prose is now swept *mechanically* against the schemas, with a checker that validates every JSON example and every named intent, theme and Hub mode against the models.

Fixed in the sweep: Track cursor still advanced in §10.5 (the exact double-advance M10 claimed to fix); `zone_selection_seed` missing `team` in prose; eligibility still keyed on "not `COMPLETE`" so `ABANDONED` held its locations forever; `abandon_zone` never clearing `active_zone_id`, leaving the escape hatch with no exit; a released location re-allocatable while its own check was in flight; four JSON examples at `schema_version: 4`; `safe_base_jump_gap: 3.0` in the payload Epsilon actually receives; the independent gap/step formulation in two more places; the intent list naming a nonexistent `resume_zone`; objective latching still saying "lifetime of the Zone" in two documents; the 2.6× DPS claim; `world_version 0.4.0`; the T−60 excusal list missing L–P.

Schema hardening the re-audit prompted: `ScoutedLocation` withholds `item_id` and the recipient fields, not just `item_name`; `CampaignSave` permits at most one Zone holding locations and requires `active_zone_id` to name it; `ZoneRecord` must describe the Zone it wraps; `ShopState` rejects duplicate stock; `HubStatus.portal_enabled` must agree with `mode`; the finale guard exempts the finale Zone itself.

**Still open, needing a decision:** `validate_assignment` re-validates assignment but not in-place list mutation (`chambers.append` bypasses the Zone-wide caps) — either narrow the claim or freeze the models. And `extra="ignore"` on `CampaignSave` does not buy the forward-compatibility its docstring claims, because `schema_version` is `Literal[5]`; it costs typo detection instead.

## Counted

62 findings: **52 fixed**, **1 decided**, **3 documented**, **6 open**. Plus 17 from the delta re-audit: **14 fixed**, **2 open** (above), **1 documented**.

Schema suite: **37 → 73 tests**, green in both the standalone and nested layouts.

---

## What v0.5 added that no finding asked for

- **`unlocked_location_ids()`** so the APWorld regions, the bridge allocator and slot data derive tiers from one function instead of four hand-written ranges.
- **`ZoneRecord` invariants**: a non-`PENDING_GENERATION` state requires an accepted Zone; a finale record holds exactly the goal Check; a non-finale record may never hold it. The B5 reservation is now structural rather than a rule someone remembers.
- **`CampaignSave` uses `extra="ignore"`** specifically, so a save from a newer build stays loadable rather than hard-failing — and the `.bak` does not inherit the same problem.
- **A theme-agreement test**, because `constants.py` and `zone.py` both declare the catalog and `constants.gd` exports one while the validator uses the other.
- **`export.py` raises** on a constant it cannot express, instead of silently dropping it inside the mechanism whose whole purpose is preventing drift.
