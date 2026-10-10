# Archipepsi v0.4 — Independent Audit, Pass 3

**Date:** 2026-08-26
**Subject:** `docs/design-packet-v0.4/` frozen at commit `a681446` — 9 documents, a 5-module Pydantic package (37 tests), `bootstrap.py`, and 4 generated artifacts
**Reviewers:** four independent agents, none of which participated in v0.4's design

---

## 0. Verdict

**v0.4 is not ready for the unattended build pass.** Four reviewers working blind returned **62 findings**, including **five criticals**, of which three can render a valid Archipelago seed permanently unwinnable and one silently destroys the player's currency.

This is a materially worse result than pass 2 reported, and the gap between them is the finding. Pass 2 was written by v0.4's author. It concluded "v0.4 is buildable" and flagged scope as the residual risk. Independent review found the campaign state machine has a hole that softlocks the run, the shop can be charged three times for one item, and the packet's headline traversal guarantee is false in two separate ways. None of that was visible from the inside.

The concept and the architecture are not in question — see §5 for what survived deliberate attack, which is substantial. The failures cluster in three places: **the seams between the schema and the prose**, **the states nobody wrote down because they felt like plumbing**, and **Archipelago client behavior that is real but undocumented in the packet**.

Recommended: one more spec-and-schema pass (§7), then re-audit the deltas only. That is hours of work, not a redesign.

---

## 1. Method and independence

Each reviewer received the packet path, a lane, and a method. None received: this conversation, the pass-1 or pass-2 audits, any hint about suspected problems, or the other reviewers' output. `docs/audit/` and the v0.3 packet were explicitly off-limits to all four.

| Lane | Focus |
|---|---|
| **A** | Campaign state machine, reachability, five-system interaction, seed unwinnability |
| **B** | Archipelago protocol correctness verified against source, persistence, duplication/loss |
| **C** | The executable artifacts — adversarial attack on the models, mutation-testing the suite |
| **D** | Cold read for implementability, as the unattended agent would experience it |

Reviewers B and C executed code; B verified every Archipelago claim against the 0.6.7 tag with file-and-line citations, and C mutation-tested the test suite by deliberately breaking the models to see which tests noticed.

**Every finding reproduced below was independently re-verified by me before inclusion.** Nothing is reported on a reviewer's word alone. Where I could not verify a claim, it is marked. No finding was dropped for being inconvenient.

---

## 2. Convergence — the strongest signal

Findings that multiple blind reviewers reached independently. Convergence is evidence: three strangers hitting the same defect from three different lanes is not coincidence.

| Finding | Reviewers |
|---|---|
| **The `GENERATED` Zone state is a hole that orphans AP locations** | **A, B, D** |
| `TIER_BOUNDS` referenced but never defined | B, C, D |
| `test_schemas.py` breaks under the copy the plan mandates | C, D |
| Prose claims ≤8 enemies per chamber; schema permits 14 | C, D |
| `validate_zone()` missing the corridor rule `EPSILON_SPEC` §7 lists | C, D |
| `ClaimCheck` docstring contradicts `TECHNICAL_ARCHITECTURE` §2 | A, D |
| Objective latching specified three incompatible ways | A, D |
| Test J names a `HubMode` that does not exist | C, D |
| `coins_spent` formula not computable from the save | B, D |
| Track cursor advanced in two places | A, B |
| `__pycache__` committed inside the "copy verbatim" directory | C, D |

---

## 3. Critical

### C1 — The `GENERATED` Zone state orphans Archipelago locations and can make a valid seed unwinnable
**Found independently by A, B and D.**

`ZoneState` is `PENDING_GENERATION → GENERATED → ACTIVE → COMPLETE`. The literal `GENERATED` appears **once** in the entire packet outside the enum — one clause in `DESIGN.md` §10.5 step 11. Nothing else in 9 documents references it.

Consequently:

- `HubMode` has no value for it. `ZONE_ACTIVE` is defined as "a Zone is `ACTIVE`".
- No intent enters it. There is no `enter_zone` in `ClientMessage`.
- `CampaignSnapshot.active_zone` derives from `active_zone_id`, which the packet only ever specifies *clearing* (§14.3 step 4), never setting.
- `TECHNICAL_ARCHITECTURE.md` §8 reconciliation covers `PENDING_GENERATION` and `ACTIVE`. Not this.
- §10.4 makes its locations ineligible for allocation, and §11.3 for shop stock — "any Zone whose state is not `COMPLETE`".

So a Zone that generates but is never entered is **invisible to Godot and permanently holds 2–3 real AP locations**. The trigger is mundane: quit at the loading screen, or let the bridge die — which §9.1 explicitly contemplates ("an in-flight generation request is abandoned, not retried").

Reviewer A carried it further than the defect itself. The finale requires 24 of the other 29 Checks. **Two orphaned 3-Check Zones cap the reachable count at 23.** `finale_available` never becomes true, eligibility drains to zero, and the Hub settles into `WAITING_FOR_AP` — telling a player holding both Pepsi Keys that their progression is somewhere in the multiworld, when nothing in the multiworld can ever clear it. Goal never sent; up to six other players' items never released.

**Fix:** set `active_zone_id` when the accepted Zone is saved and treat `GENERATED` as `ZONE_ACTIVE` for both the Hub and the one-Zone-at-a-time guard (preferred — it keeps the model call that was paid for), or release its locations on load. Either way add an `enter_zone` intent and a §8 reconciliation clause.

---

### C2 — The shop can be charged repeatedly for one location, destroying coins
**Found by B. Verified.**

`TECHNICAL_ARCHITECTURE.md` §2 lists the bridge's re-verification for `claim_check` and it includes "no pending transaction exists for it." The shop path, `DESIGN.md` §11.7 step 1, verifies exactly two things: **"the location is still server-missing and the balance suffices."** No pending-transaction check.

Between step 5 (send) and the server's `RoomUpdate`, the location *is* still server-missing. A second `buy_shop_stock` for the same location passes step 1, creates a second `PendingCheck`, and re-runs step 3 — "add the cost to persisted `coins_spent`". At 2 coins with 6 available, three purchases of one location are possible. All three finalize, the Echo dict deduplicates by `echo_id`, and the coins are simply gone.

This cannot be guarded client-side either: `ShopStockItem` has no status field, `ShopState` has no purchased set, §11.5 says purchased stock stays in `stock`, and §2 says Godot is not an authority.

`DESIGN.md` §4 criterion 13 — "no duplicated coins, Echoes, checks or purchases" — is violated by the packet's own procedure.

**Fix:** add "no `PendingCheck` exists for this location, from any source" to §11.7 step 1. Add a `status` field to `ShopStockItem` so the snapshot can express it.

---

### C3 — An unfinishable Zone bricks the campaign, with no way out
**Found by A.**

Three individually-correct rules combine into a trap: §10.7 forbids generating a new Zone while one is `ACTIVE`; §14.2 preserves the Zone as `ACTIVE` on Return to Hub; §14.3 completes it only when every Check is confirmed. There is no `abandon_zone` intent, and `DebugCommand` offers only `force_fallback_zone` (which applies to generation) and `clear_campaign` (which destroys coins, Echoes and history).

§14.3 explicitly reasons about not letting a player "strand themselves with an `ACTIVE` Zone that has nothing left to do" — and closes only the *finished* case. The *unfinishable* case is open.

Reviewer A's trigger is specific and plausible: a schema-legal `tower` with `kill_all` and 3 `melee`; one enemy walks off a floor chasing the player and falls out of the chamber. `constants.py` defines `FALL_KILL_Y` and `DESIGN.md` §9 defines death **for the player only** — enemies have no fall rule anywhere in the packet, and `EPSILON_SPEC.md` §5 explicitly accepts "simplified steering… in awkward generated geometry." The enemy is alive, unreachable, `kill_all` never satisfies, and §14.2 respawns it identically on every re-entry.

`DESIGN.md` §3.3 promises "a bad response never corrupts a save or blocks a run." A *schema-valid* response blocks the run.

**Fix:** add `abandon_zone` (terminal `ABANDONED` state, locations released, confirmed Checks preserved). Separately add an enemy fall-kill rule to `constants.py` — one line that removes the most likely trigger.

---

### C4 — Reaching the goal permanently abandons up to five real AP locations
**Found by A.**

`DESIGN.md` §13 argues at length that the finale must not displace `ZONE_AVAILABLE`, "because those Checks would become permanently unreachable content." The fix applied was to *offer* both. But the terminal state was left unchanged: taking the offer sets `CAMPAIGN_COMPLETE` and disables the portal, and the same Checks become permanently unreachable.

At 24 of 29 required, that is **up to five real Archipelago locations — up to five other players' items — never sent.** In a room without auto-release, a stranded progression item can block another player's completion. Nothing warns the player before they take the door.

This is the pass-2 fix being half a fix: the author protected the player from being *forced* through the door and then left the door one-way and unlabelled.

**Fix:** follow Archipelago convention — goaling does not end play. `CAMPAIGN_COMPLETE` becomes a banner; the portal stays enabled while eligible Checks remain. Minimum viable: a confirmation naming the exact cost ("5 Checks will be abandoned; 5 items will never reach their players").

---

### C5 — A legal passive Echo makes mandatory traversal impossible
**Found by D. Verified by direct computation.**

`DESIGN.md` §19 and `schemas/README.md` claim the no-Echo-gate guarantee is *structural* — the Zone schema has no field that can require an Echo. True, for **positive** gates. Nothing prevents a **negative** one.

`modify_gravity` is bounded `[0.35, 1.5]` and `modify_speed` `[0.65, 1.6]`. The hostile ends are legal, and both may sit in one `PassiveEcho`:

| Equipped (all legal) | reach | vs 3.0 m gap | apex | vs 1.0 m step |
|---|---|---|---|---|
| none | 4.67 m | ok | 1.33 m | ok |
| `modify_speed 0.65` | 3.03 m | ok (1.01×) | 1.33 m | ok |
| `modify_gravity 1.5` | 3.11 m | ok | **0.89 m** | **FAILS** |
| both | **2.02 m** | **FAILS** | **0.89 m** | **FAILS** |

A player who equips a legal Echo can be unable to cross a mandatory gap, with no in-game indication that unequipping is the answer. `test_safe_gap_leaves_real_margin` checks only the unmodified arc.

**Fix:** derive the passive bounds from the traversal constants, or suppress passives on mandatory platforming. Assert it in the suite.

---

## 4. Major

### M1 — The traversal margin is 1.17×, not the 1.56× the packet certifies
**C. Verified.** `SAFE_BASE_JUMP_GAP` is derived from `JUMP_FLAT_REACH` — the reach of a jump *returning to its starting height*. `gap_size ≤ 3.0` and `vertical_step ≤ 1.0` are independent fields and may be maxed together.

```
landing +0.0m -> reach 4.667m | margin 1.56x | slack after player radius +1.267m
landing +1.0m -> reach 3.500m | margin 1.17x | slack after player radius +0.100m
```

Ten centimetres in the worst legal chamber. The test certifies the flat case only. Also: `round()` rounds a *safety floor* upward (2.9867 → 3.0), and `MIN_PLATFORM_SIZE` is referenced by no model, no field and no test.

**Fix:** make the bound joint — validate `gap_size ≤ reach(vertical_step) × SAFE_GAP_MARGIN`. Use `math.floor` for safety floors.

### M2 — Post-parse mutation bypasses every bound in every model
**C. Verified.**

```python
z.chambers[0].gap_size = 500.0
z.theme = "lava_maze"
z.chambers[0].reward_location_id = 89100030   # the reserved goal Check
# all three succeed; model_dump_json() serializes them without complaint
```

No model sets `validate_assignment`. Bounds are parse-time only. Since the bridge constructs and mutates these objects (fallback generators, snapshot assembly), "the schema is the contract" holds only at the boundary.

Relatedly, `echo.py` claims three rules are enforced "by the type system rather than by a validator that has to remember them." Only one is — `PassiveEcho` genuinely lacks `cooldown`. The other two are `model_validator` code, and appending to `effects` post-parse restores both v0.3 holes in two lines.

**Fix:** `validate_assignment=True` on the three `Strict` bases; restructure `PrimaryEcho` as `initiator` + `modifiers` fields so the rule is genuinely structural (and expressible in the exported JSON Schema).

### M3 — `import CommonClient` runs pip at import time and can hang the bridge
**B. Verified against source.** `CommonClient.py` lines 12–13 are `import ModuleUpdate` / `ModuleUpdate.update()`. `update()` defaults `yes=False` and calls `confirm()`, which is bare `input()` catching only `KeyboardInterrupt`. Skip conditions are frozen builds, multiprocessing children, or `SKIP_REQUIREMENTS_UPDATE`.

A bridge launched without a TTY dies during import with `EOFError`. And AP pins `websockets==13.1`; if the bridge's own pin differs, every import silently reverts it via `pip install --upgrade`. `update_command` ignores pip's exit code, so `bootstrap.py --yes` can exit 0 with requirements unmet.

**Fix:** set `SKIP_REQUIREMENTS_UPDATE=1` before the import, add it to §15, and have `bootstrap.py` verify the modules it needs rather than trusting the exit code.

### M4 — All AP-derived counters read zero while disconnected
**B. Verified against source.** `CommonContext.reset_server_state()` sets `items_received = []` and `locations_info = {}` on every disconnect. `checked_locations`/`missing_locations` are *not* cleared.

The packet's "always recount from the reconstructed inventory" rule is right, but during any outage the recount yields `coins_received = 0`, `pepsi_keys = 0`, `scouted = {}`. Snapshot fields all default to `0` with no rule that they are meaningful only when `ap_connected`. So: the §12 sync-warning fires on every disconnect, `unlocked_tier` regresses to 0, eligibility collapses, and `HubStatus.mode` can flap to `WAITING_FOR_AP` because the player was offline for five seconds.

**Fix:** the bridge retains its own last-known normalized copy in memory; the sync-warning fires only after a completed post-`Connected` reconciliation.

### M5 — `CommonContext.on_package` is synchronous, and the entire reconciliation design hangs off it
**B. Verified against source.** It is `def`, not `async def`, and is called as a plain call. Everything the bridge must do there is async: atomic save, snapshot emission, Echo generation. The natural implementation — `async def on_package` — produces a coroutine that is never awaited, emitting a `RuntimeWarning` easily lost in AP's logging and **silently never reconciling**. That is exactly the "hang in `SENDING…` forever" failure §5 exists to prevent, reintroduced one layer down.

**Fix:** add to §15; require a plain `def` that schedules via `asyncio.create_task` and holds a reference.

### M6 — Zone-source pending checks have no terminal failure state
**B.** The shop path got a rollback trigger; the Zone path did not. `check_locations()` returns the set it actually sent — empty when the location is in neither `missing` nor `checked` — and the packet never says to inspect the return. A location AP does not recognise produces no packet, no response, no error, and a `PendingCheck` that reconciles forever. Because §14.3 gates the exit portal on all Checks confirmed and §10.7 forbids a new Zone while one is `ACTIVE`, **one stuck check permanently blocks the campaign.**

### M7 — The shop rollback trigger has no connection guard and fires at every bridge start
**B.** "After a full snapshot, the location is absent from `missing ∪ checked`" — but both sets are empty until `Connected` populates them, and a snapshot is emitted at `bridge_ready`. Read literally, the first snapshot after startup rolls back **every** persisted pending purchase: coins refunded, and then §8 finalizes the purchase anyway. Free checks.

### M8 — The recommended solo-testing seed produces zero Echoes and a permanently empty shop
**A.** `APWORLD_SPEC.md` §7.1 offers a solo YAML "for a demo that must not depend on other players' pace." In a solo generation all 30 items are placed on the 30 Archipepsi locations, so the recipient is the Archipepsi slot for **30 of 30**. §15.1 generates no Echo for self-recipient locations; §11.3 excludes them from shop stock. Result: **0 Echoes for the entire campaign, `OUT OF QUESTIONABLE GOODS` forever, 10 unspendable coins** — and `DESIGN.md` §4 makes Echo generation, equipping and shop purchase steps 8–12 of the definition of success. The configuration recommended for demos removes every one of them.

### M9 — The finale can be started while an ordinary Zone is `ACTIVE`
**A. Verified** — `HubStatus(mode="ZONE_ACTIVE", finale_available=True)` constructs fine. The only stated guard is `finale_available`. A player who hits 24 mid-Zone, returns to the Hub, and takes the finale strands that Zone's unclaimed Checks permanently, in a state §10.7 says cannot exist.

### M10 — Zone completion runs its seven steps twice, or zero times
**A.** §14.3 attributes the same seven steps to both the exit portal and to automatic completion. If both run, `completed_zone_count` double-increments (shop restocks every Zone instead of every second) and `track_cursor` double-advances (with 6 Tracks, three never initiate a Zone all campaign — halving the variety the premise rests on). If only step 4 runs, a player who confirms their last Check and leaves via pause never increments at all. Worse, after auto-completion §2's re-verification ("the Zone is `ACTIVE`") **rejects the player's `ExitZone`** — they are standing on the portal of a finished Zone and get a `BridgeError`.

### M11 — Phase 2's milestone depends on Phase 4
**D.** Phase 2 item 20 is a CLI smoke test that must "fallback-generate" a Zone and an Echo. The fallback generators are Phase 4 item 35, and `MockEpsilonProvider` is scheduled in no phase at all. At Phase 2 there is **no provider of any kind**, so the milestone the plan calls "the riskiest part of the project and it is now done" is unreachable in the order given. Same for the handoff's "`--epsilon=fallback` is your best test configuration."

### M12 — Nothing explains how to install the world, generate a seed, or host a server
**D.** Phase 1's milestone is "generates real seeds"; Phase 2's is "against a real server." The strings `Generate.py`, `host.yaml`, `players/` and `worlds/` appear **nowhere in the packet**. The world lives at `apworld/archipepsi/` and the checkout at `.archipelago/` with no step connecting them. The agent must invent: the world-install step, YAML placement, generator invocation, output location, server launch, and a partner world for test 47 with enough locations to absorb 10 non-local Coins. Most likely outcome: 30–60 minutes lost in the phase with the smallest budget, or Phase 1 declared done on unit tests that never run AP's generator — which is exactly how the `origin_region_name` class of bug survives.

### M13 — `test_schemas.py` breaks under the copy the plan mandates
**C, D. Verified.** The four modules use relative-with-fallback imports; the test file does not.

```
$ cp -r schemas bridge/archipepsi_bridge/schemas && cd bridge && python -m pytest -q
E   ModuleNotFoundError: No module named 'constants'
Interrupted: 1 error during collection
```

This is the first instruction the agent is given and the T−60 gate's only "Always" item. `__pycache__` (7 files) and `.pytest_cache` are also tracked, so "copy verbatim" copies stale bytecode.

### M14 — Prose claims two validation rules the schema does not implement
**C, D. Verified.** `EPSILON_SPEC.md` §3 lists "≤8 enemies per chamber" under "rules the schema enforces" and ships `max_enemies_per_chamber: 8` to Epsilon. The schema bounds each *group* at 8 and allows 4 groups: a chamber with **14 enemies** passes both structural and semantic validation. Separately §7 lists a corridor-reward rule `validate_zone()` does not implement.

### M15 — The whole scouted table ships to Godot in every snapshot
**C.** `CampaignSnapshot.scouted` carries `item_name`, `recipient_name`, `recipient_game` for all 30 locations, with no `revealed` flag anywhere in the schema. `DESIGN.md` §10.1 promises "scout first, reveal selectively," and §16 calls the reveal "the only genuinely novel moment in the loop" — while the client already holds the answer for every Check before the player enters a Zone. The debug overlay renders from the snapshot. The protocol offers no way to withhold it.

### M16 — Effort estimates overrun the session by 1.4–1.9×
**D.** Phases sum to **345 minutes** plus an unestimated Phase 7, against 240–300 minutes with the last 60 frozen — so 180–240 minutes of feature time. Even the packet's own expected Phase 0–3 outcome is 240 minutes, the entire window at the five-hour end with zero slack, and excludes the AP clone and `ModuleUpdate` reality, the missing generation harness (M12), and a Phase 3 that bundles a controller, a six-mode Hub, two builders, an enemy, the claim flow, the reveal, three Echo effects, inventory and leave/exit into 90 minutes.

### M17 — Nothing verifies the toolchain exists
**D. Verified** — neither `godot` nor `blender` is on PATH in this environment. `bootstrap.py` checks only Python. Everything from Phase 3 on, plus all of `ACCEPTANCE_TESTS.md` §5, is unbuildable and unverifiable without a Godot binary, and no document says what to do if there isn't one.

### M18 — `ARCHIPELAGO_ROOT` silently bypasses the version pin
**C.** When set, `ensure_checkout` returns immediately, `--tag` is ignored, and `verify()` prints the AP version without comparing it. The entire D1 "pinned by tag" decision evaporates for exactly the developer the flag exists for, with all of §15's "verified against 0.6.7" assumptions unverified. `bootstrap.py` also runs `ModuleUpdate.py --yes` inside the user's personal checkout, installing into their environment, unwarned.

---

## 5. What held under deliberate attack

Stated plainly, because it is a real result and pass 4 should not re-litigate it.

**Archipelago claims — all verified against the 0.6.7 tag with citations.** `create_as_hint` persisting hints even for found locations; `check_locations()` filtering client-side; the server broadcasting nothing when nothing is new; invalid IDs dropped silently; `ReceivedItems index==0` as replacement; `CLIENT_GOAL = 30`; `origin_region_name` defaulting to `Menu`; `_read_race_mode`; `CommonClient` importing `worlds` at load; manifest rules; the ID-overlap rule. **The APWorld as described will generate,** and `non_local_items: Epsilon Coin` is genuinely enforced for filler via `Fill.remaining_fill`.

**The pass-2 C1 conclusion was right.** "Reconcile, never event-wait" is the correct reading of the source, confirmed independently at the line level.

**Schema guarantees that survived attack:** `extra="forbid"` holds at every nesting level; NaN and ±Infinity are rejected by every bounded float, including via raw JSON literals; discriminated unions hold, and `PassiveEcho` genuinely has no `cooldown`; `echo_id` derivation cannot be forged; JSON round-trips are lossless including `dict[str, Echo]`; the generated artifacts are byte-identical on regeneration and the staleness guard genuinely fires; the models import correctly when nested; `bootstrap.py`'s healthy re-run paths are idempotent.

**Allocation arithmetic is sound.** Reviewer A traced the full 29-Check consumption and confirmed normal allocation cannot starve or deadlock on its own; shop reservations cannot starve Zone allocation (`SHOP_MIN_REMAINING_AFTER_STOCK` holds); there is no double-claim path between shop and Zones; and the runtime is never *looser* than AP logic.

---

## 6. Minor

Condensed. Each was verified or is a direct reading of the text.

| # | Finding | Where |
|---|---|---|
| m1 | `TIER_BOUNDS` referenced but never defined; the "tier mirror" `APWORLD_SPEC` §3 points at does not exist, so the mapping gets re-derived in 3–4 places | `constants.py:49` |
| m2 | `ClaimCheck` docstring asserts objective verification §2 says is impossible — and the docstring is top authority | `protocol.py` |
| m3 | Objective latching specified three incompatible ways (§9 "lifetime of the Zone" / §14.2 "unsatisfied" / Test I "objectives unsatisfied") with no schema field to hold it | §9, §14.2, Test I |
| m4 | Test J names `FINALE_AVAILABLE`, which is not a `HubMode` — an implementer adding it reintroduces the exact collapse pass 2 fixed | `ACCEPTANCE_TESTS.md` |
| m5 | `coins_spent` formula in §12 is not computable from `CampaignSave`; read literally it refunds every confirmed purchase | §12 |
| m6 | Track cursor advanced in both §10.5 step 4 and §14.3 step 5 | §10.5, §14.3 |
| m7 | The two deterministic shuffles use different seed tuples — `team` is dropped from Zone allocation | §10.3 vs §10.5 |
| m8 | `test_prng_is_stable_across_processes` pins the seed but **not** the shuffle; C reversed the Fisher–Yates direction and the test still passed | `test_schemas.py:70` |
| m9 | `test_a_good_echo_meaningfully_beats_pepsi_pop` is tautological — three literals, no field reference; C crushed the bounds to 1–2 damage and it still passed. The prose claim is also wrong: bounds allow 156×, not "roughly 2.6×" | `test_schemas.py:44` |
| m10 | `test_safe_gap_is_derived_from_the_jump_arc` hard-pins the pre-retune answers, so the retune `constants.py` invites turns the suite red | `test_schemas.py:23` |
| m11 | `ZoneRecord`/`CampaignSave` almost unconstrained: negative `coins_spent`, out-of-range location ids, `COMPLETE` with no Zone, dangling `active_zone_id`. An out-of-range allocated id produces an **unsatisfiable repair loop** — fallback cannot fix it either | `protocol.py:49,89` |
| m12 | AP-sourced strings on the display path have no length bound (`ShopStockItem`, `ScoutedLocation`, `ReceivedItem`, `Notification`, `HubStatus`), while the Echo path does; negative `cost` accepted | `protocol.py` |
| m13 | `featured_echo_ids` elements unbounded and unvalidated, and are interpolated verbatim into the repair prompt — a 17 KB model-controlled string re-enters the next prompt | `zone.py:143` |
| m14 | The reveal card is 9 lines; `Notification.lines` is `max_length=6`, and the content spans two notification kinds with no specified sequencing | §16 vs `protocol.py` |
| m15 | No "generation in progress" state exists in the snapshot, though §13 requires the UI to show one and generation can take 120 s | `protocol.py` |
| m16 | Main menu offers an Epsilon provider selector the protocol cannot express; `ClientMessage` is closed and `extra="forbid"` | §22 vs `protocol.py` |
| m17 | `ctx.finished_game` never set, so AP's own reconnect goal-resend never fires; test 33's "exactly once" is the wrong invariant for a fire-and-forget packet | §5, §10.6 |
| m18 | Self-recipient detection should use `ctx.slot_concerns_self()`; `player == slot` misclassifies item-link groups | §15.1, §11.3 |
| m19 | Shop is structurally guaranteed empty during `WAITING_FOR_AP` (shop-eligible ⊆ Zone-eligible), contradicting "the shop remains fully usable" | §13.1 |
| m20 | Shop cadence contradicts stock lifetime: restock every 2 Zones, release after 1 — empty half the campaign | §11.5 |
| m21 | `bootstrap.py` wedges permanently after an interrupted clone (non-empty dir without `CommonClient.py`), despite "idempotent: safe to re-run" | `bootstrap.py:67` |
| m22 | `bootstrap.py verify()` builds its probe by unescaped interpolation; a path with an apostrophe reports "could not import CommonClient" | `bootstrap.py:86` |
| m23 | `export.py` silently drops any constant it cannot express (`except TypeError: continue`) — inside the mechanism whose purpose is preventing drift | `export.py:67` |
| m24 | Exported JSON Schema omits half the bridge→Godot protocol, and `echo.schema.json` contains no trace of the composition rules, so structured output cannot enforce them | `export.py:87` |
| m25 | `ZoneGenerationRequest`/`EchoGenerationRequest` — contracts `EPSILON_SPEC` §5 says "must not change" — have no Pydantic model at all | `EPSILON_SPEC.md` §9–10 |
| m26 | `constants.py` duplicates catalogs that `zone.py` declares as `Literal`s, with nothing asserting agreement; `ZONE_MIN/MAX_CHECKS` and `SHOP_STOCK_SIZE` unused while models hardcode 3 and 2 | `constants.py:181` |
| m27 | Three different export commands across three documents, and `constants.gd`'s destination is never stated | multiple |
| m28 | Effect force units undefined (impulse? velocity delta?) in a file declaring "units: metres, seconds" — decides whether the Conference Call recoil is funny or imperceptible | `echo.py` |
| m29 | `HubStatus` validator raises on the **outbound** path; §9.2 covers inbound only, so a snapshot the bridge cannot serialize means Godot renders nothing | `protocol.py:191` |
| m30 | Canonical fixture's self-recipient Coin (Check 006) cannot occur in a seed from the recommended YAML | `IMPLEMENTATION_PLAN.md` §3.1 |
| m31 | Self-recipient Track key ambiguity breaks the fallback theme lookup (`"Archipepsi / Glitch Track"` vs `THEME_BY_GAME_HINT["Archipepsi"]`) | §10.2 |
| m32 | Test coverage gaps: no valid `TreasureRoomChamber` or `PlatformPathChamber`; no `Zone`/`Echo` JSON round-trip; nothing touches `CampaignSnapshot`, `Notification`, `ShopState`, `PendingCheck`, or any `SHOP_*` constant | `test_schemas.py` |
| m33 | Two contradictory controls for the mock-AP axis (`--ap=mock` flag vs `start_mock_campaign` intent); nobody says who launches the bridge | §10.3 vs §22 |
| m34 | `reward_location_id` filtered by truthiness, not `is not None`; `validate_echo` untyped and its rules are code-only, absent from `EPSILON_SPEC` §8 | `zone.py:170`, `echo.py:216` |

---

## 7. Recommended v0.5 work order

**Blocking — the campaign can break without these**

1. **C1** `GENERATED` — set `active_zone_id` at save, add `enter_zone`, add the §8 reconciliation clause, add the acceptance test.
2. **C2** shop double-charge — add the pending-transaction check to §11.7 step 1; add `status` to `ShopStockItem`.
3. **C3** `abandon_zone` intent + enemy fall-kill constant.
4. **C4** goaling does not end play (or, minimum, a confirmation naming the cost).
5. **C5 + M1** make the traversal bounds honest: derive passive bounds from the constants, make gap/step joint, `math.floor` the safety floor.
6. **M6, M7** terminal failure state for Zone-source pending checks; connection guard on the shop rollback.

**Blocking for the build pass to function at all**

7. **M13** fix `test_schemas.py` imports; untrack `__pycache__`/`.pytest_cache`.
8. **M11** move fallback generators to Phase 2; schedule `MockEpsilonProvider`.
9. **M12** write the world-install / generate / host commands as literal Makefile targets; name the partner world.
10. **M3, M4, M5** the three real `CommonContext` behaviors — `SKIP_REQUIREMENTS_UPDATE`, disconnect wiping `items_received`, `on_package` being sync. All three belong in §15.
11. **M17** Phase 0 toolchain check with a stated fallback when Godot is absent.
12. **M16** re-estimate, and state plainly that **Phase 0–2 is the expected outcome**, not Phase 0–3.

**Schema hardening**

13. **M2** `validate_assignment=True`; restructure `PrimaryEcho` into `initiator` + `modifiers`.
14. **M14** implement the two rules the prose already claims.
15. **M15** add `revealed` to `ScoutedLocation` or redact the snapshot.
16. **m11, m12, m13** constrain `ZoneRecord`/`CampaignSave`; bound AP-sourced display strings; validate `featured_echo_ids`.
17. **m8, m9, m10** fix the three tests that pass for the wrong reason.
18. **m1** define `TIER_BOUNDS` and `tier_of()`.

**Prose consistency** — m2–m7, m14, m16, m19, m20, m27–m34, plus M8 (solo YAML warning) and M9, M10 (finale-mid-Zone guard, single idempotent completion).

---

## 8. Note on visual direction

Separate from the audit and not a finding: the product direction is moving from "Minecraft-like/blocky" to a **late-1990s PC FPS / GoldSrc-era aesthetic** — chunky low-poly brushwork, industrial rooms, vents, catwalks, ramps, wedges, ~32–128 px procedural textures, harsh simple lighting, per-source-game material sets.

This is a low-risk change against the findings above. It touches `DESIGN.md` §3.4, §20 and the `EPSILON_SPEC.md` theme catalog only. Nothing architectural depends on cube geometry, the generator already assembles chambers from primitives, and the zero-asset pipeline is unaffected — the texture size bound is a code-side choice, not something Epsilon produces. It should land with the v0.5 edits rather than as a separate pass.

---

## 9. On the value of independence

Pass 2 was written by v0.4's author and concluded "v0.4 is buildable," with scope as the residual risk. It caught three real bugs. Four blind reviewers caught five criticals it did not, three of which can permanently break a campaign.

The author-audit was not lazy — it verified constants by execution, round-tripped the models, and correctly flagged its own reduced standing. It still missed the softlock in the state machine it had just rewritten, one turn after fixing a different softlock in the same system. Self-review reliably finds errors of *execution* and reliably misses errors of *conception*, because the same model of the system generates both the artifact and the review.

The convergence table in §2 is the practical argument: eleven findings were reached by two or more reviewers who could not see each other. That is a defect-density signal no single reviewer, however hostile, can produce alone.

Worth repeating for v0.5: fix, then re-audit the **deltas** with fresh reviewers rather than re-reading the whole packet with the same eyes.
