# Pass 5 — Delta Audit of v0.6

**Artifact audited:** `docs/design-packet-v0.6/` at commit `a24b8ba08b1e2c597dcd0b3a572b545a25f99d7e`.

**Reviewers:** three independent agents, none shown `docs/audit/`, any `CHANGELOG_*`, or any earlier packet revision. None was told what v0.6 changed or why. Lenses: campaign/Archipelago state integrity; state machines and their agreement; unattended buildability.

**Author's re-verification:** every finding below was reproduced by the author against the shipped models before being recorded here. Reviewer claims that did not reproduce, or that turned out to be design decisions rather than defects, are in §5.

**Verdict: NO-GO.** One blocker and eleven majors confirmed. Details in §6.

---

# 1. What held

Worth stating first, because it is the part v0.6 was for.

**The goal reservation is genuinely closed.** All three reviewers attacked it independently and all three failed. `BuyShopStock(89100030)`, `ShopStockItem(location_id=89100030)`, `PendingCheck(source="shop", location_id=89100030)`, a non-finale `ZoneRecord` holding the goal, and a `CampaignSave` with a pending goal check and no finale record are all rejected. The `6 coins → buy Check 030 → win` sequence is dead. Reviewer 1 additionally confirmed the bound survives export: `generated/protocol.schema.json` carries `maximum: 89100029` on the shop paths and `89100030` on the finale paths, and `constants.gd` carries the range constants.

**The Zone-state ↔ Hub-mode agreement holds** at the parse boundary. Reviewer 2 swept every mode and every state and could not construct a top-level disagreement: not a terminal Zone presented as active, not `generation_in_progress` outside `GENERATING`, not the finale offered while a Zone is held, not a playable mode with the portal off. Reviewer 2's category 4 — transitions, reachability, dead-end states — yielded **nothing**: every arrow in both lifecycle diagrams is representable, and no state is enterable-but-not-leavable.

**Verification claims are true.** 91 tests pass standalone, from the packet root, and in the nested package layout Phase 0 mandates. `check_packet.py` is clean. `export.py` reproduces `generated/` byte-identically. Reviewer 3 independently re-verified every Archipelago 0.6.7 claim against the real sources — `check_locations` filtering, `on_package` being synchronous, `reset_server_state` clearing `items_received`, `origin_region_name` defaulting to `"Menu"` at `AutoWorld.py:319` — and found all of them stated correctly.

**Traversal held again.** 2.6 m flat, 2.0 m at a 1.0 m step; `jump_reach`'s defaults really are the worst legal loadout; no legal `vertical_step` empties the `gap_size` range.

---

# 2. BLOCKER

## B1 — `validate_assignment` does not reach nested models or lists, and the packet asserts that it does

**Introduced by:** v0.5 (the mechanism); **made worse by v0.6**, which added cross-model validators that depend on it and a test that appears to prove it.

`validate_assignment=True` re-runs model validators on **top-level field assignment only**. Mutating a nested model, or appending to a list, runs nothing. Every cross-model invariant in `CampaignSave` and `CampaignSnapshot` is therefore bypassable by exactly the mutations a bridge naturally performs:

```python
s.zones["z1"].state = "COMPLETE"        # accepted; active_zone_id still "z1"
s.model_dump()                          # writes fine
CampaignSave.model_validate(...)        # -> active_zone_id must be cleared...
```

The save on disk cannot be read back. Per `TECHNICAL_ARCHITECTURE.md:206` the bridge falls to `.bak`, which still holds the pre-completion state — so the campaign silently rolls back a completed Zone. Reproduced identically for `ABANDONED`.

List mutation hits the anti-double-charge ledger directly:

```python
s.pending_checks.append(PendingCheck(..., location_id=L, source="shop", shop_cost=6))
# accepted: two pending checks for one location — the exact shape DESIGN.md §11.7
# says the uniqueness rule prevents. Reload rejects it.
```

Same for `s.shop.stock.append(...)`. And on the wire:

```python
sn.active_zone.state = "COMPLETE"
sn.model_dump()   # emits hub.mode="ZONE_ACTIVE" with a COMPLETE active_zone
```

`protocol.py:548-550` claims a divergence "fails at the boundary rather than showing up as a portal that offers a second Zone." It fails only if the bridge re-parses its own outgoing frame, which nothing specifies.

**Why this is the author's defect and not Pydantic's.** The behaviour is documented Pydantic. The defect is that v0.6 added `test_the_new_invariants_survive_post_parse_mutation`, which asserts the guard covers post-parse mutation — and tests only top-level assignment, the half that works. A test that produces false assurance about a guard is worse than no test. The paired path named in v0.6's own process rule was "parse-time validation vs post-parse mutation"; the sweep covered one side of it and reported the pair closed.

**Confirmed by:** reviewer 2 (found it), author (reproduced all four cases).

---

# 3. MAJOR

## M1 — The documented completion and abandon procedures are rejected in both orders

`DESIGN.md:449-451` (abandon) and `:465` (complete) are written as ordered steps that mutate `zones` and `active_zone_id` separately. Both orders raise:

```
s.zones = {...terminal...}; s.active_zone_id = None  -> active_zone_id must be cleared...
s.active_zone_id = None; s.zones = {...terminal...}  -> active_zone_id must name the held Zone 'z1'
CampaignSave(**{**s.model_dump(), "zones": ..., "active_zone_id": None})   -> ACCEPTED
```

The atomic rebuild works, so this is a footgun rather than an impossibility — but `ZoneRecord` documents its equivalent requirement in the model and in `TECHNICAL_ARCHITECTURE.md:229-232`, and its neighbour `CampaignSave` documents nothing. An implementer following the numbered steps hits a `ValidationError` mid-completion, and the obvious escape is B1.

*Same defect shape as D1: a rule closed on one model and left unstated on the model beside it.*

## M2 — `CampaignSnapshot` does not carry the invariants `CampaignSave` enforces

The v0.6 goal-reservation sweep closed the save path and skipped the snapshot:

```
CampaignSave(pending_checks=[goal check], zones={})       -> REJECTED (no finale Zone)
CampaignSnapshot(pending_checks=[goal check], ...)        -> ACCEPTED
CampaignSnapshot(pending_checks=[two for one location])   -> ACCEPTED (save: rejected)
CampaignSnapshot(equipped_echo_id=..., echoes=[])         -> ACCEPTED (save: rejected)
```

The snapshot is the message Godot renders and, by `protocol.py:548-550`'s own argument, the one the bridge tests assert on. **This is an incomplete paired-path sweep in the fix that the paired-path rule was written for.**

## M3 — Coin accounting is unlinked from pending purchases, and the documented rollback raises

```python
CampaignSave(coins_spent=0, pending_checks=[PendingCheck(source="shop", shop_cost=6)])  # ACCEPTED
s.coins_spent -= 6      # DESIGN.md §11.7 rollback, TECHNICAL_ARCHITECTURE.md §5
                        # -> ValidationError: Input should be >= 0
```

`coins_spent` is documented as "already inclusive of pending purchases" and nothing enforces it, so a free 6-coin purchase validates; and `ge=0` plus `validate_assignment` make the documented decrement an unhandled crash. Also accepted: 29 simultaneous 6-coin purchases (174 coins) against an item pool containing 10.

v0.6 tightened `shop_cost` per source and did not link either field to the ledger they feed.

## M4 — A `PendingCheck` need not be backed by any allocation, and reconcile then sends it

Nothing ties a `PendingCheck` to a Zone allocation or a stock entry. A save with 29 pending `source="zone"` checks, `zones={}`, empty shop and `coins_spent=0` validates. `TECHNICAL_ARCHITECTURE.md:171`/`:244` say "still missing → re-send", and all 29 are missing, so §5's terminal-failure rule never fires: the bridge sends 29 `LocationChecks`. That is 29 other players' items delivered from one hand-edited file. The mirror case strands instead — a stale pending check for an unowned location makes it permanently ineligible under `DESIGN.md:230`.

## M5 — The finale gate is enforced by no model at all

`FINALE_REQUIRED_SIGNAL_KEYS` and `FINALE_REQUIRED_OTHER_CHECKS` appear in the models only as decorative defaults. Verified accepted:

```
HubStatus(mode="FINALE_ONLY", finale_available=True, finale_progress=0/24)
  -> accepts_zone_request == True
```

`finale_progress`, `finale_required`, `signal_keys_required` and `CampaignSnapshot.signal_keys` sit in adjacent fields and are never cross-checked. v0.6 moved the goal *reservation* out of prose into typed bounds across five paths; the goal *gate* got none of that treatment on the same model.

## M6 — `finale_available` has no defined meaning, and `DESIGN.md` states the opposite of the schema

Found independently by two reviewers. `DESIGN.md:375` and `protocol.py:400`: "`mode` and `finale_available` are **INDEPENDENT**." They are not — the field is rejected in 4 of 8 modes (`GENERATING`, `ZONE_READY`, `ZONE_ACTIVE`, `WAITING_FOR_AP`).

So `finale_available` means "offerable right now", not "unlocked" — which the packet never says, while `finale_progress`/`finale_required` sit beside it reporting the unlock. An agent that implements `DESIGN.md` literally and emits `finale_available = (keys >= 2 and confirmed >= 24)` raises `ValidationError` on **every snapshot** from the moment the 24th Check confirms while a Zone is held. `ACCEPTANCE_TESTS.md` test 66 — added in v0.6 — states an unconstructible premise for the same reason.

## M7 — A single stuck location cannot be released from a multi-Check Zone

`TECHNICAL_ARCHITECTURE.md:173` specifies "drop the pending record, release the location." `_state_implies_content` pins `allocated_location_ids` to the accepted Zone's rewards for the record's whole life, and `ZoneRecord` has no per-location status:

```
ZoneRecord(**{**rec.model_dump(), "allocated_location_ids": [a, b]})   # from [a, b, c]
  -> REJECTED: the accepted Zone's rewards must be exactly its allocated_location_ids
```

The only exit is abandoning the whole Zone, discarding its other unclaimed Checks — the deadlock the section exists to break.

## M8 — Shop restock cannot coexist with an in-flight purchase

`SHOP_STOCK_SIZE = 2` caps `ShopState.stock`. Completion is triggered by check confirmation and step 5 applies the shop cadence, so a shop check bought moments earlier is still `pending` when the batch refreshes:

```
ShopState(stock=[pending, fresh, fresh])   -> REJECTED: at most 2 items
ShopState(stock=[fresh, fresh])            -> the only representable outcome
```

Which drops the pending entry — for a purchase whose cost is already in `coins_spent`.

## M9 — "Archipelago is down, so the portal must not start a Zone" is unrepresentable

`portal_enabled` is forced equal to `mode in (ZONE_READY, ZONE_ACTIVE, ZONE_AVAILABLE, FINALE_ONLY)`. `ZONE_AVAILABLE` with the portal off is rejected. Both escapes are closed by prose: `ACCEPTANCE_TESTS.md` Test P requires `hub.mode` be **unchanged** across an AP drop, and `DESIGN.md:348` forbids flapping into `WAITING_FOR_AP` during a dropout. So during an outage the Hub must show a live "generate" portal — while `reset_server_state()` has cleared the `locations_info` that Track grouping needs.

*This is the "unrepresentable legitimate state" direction, and it is the one v0.6 tightened toward without checking.*

## M10 — `extra="ignore"` on `CampaignSave` cannot do what it says, and silently zeroes the ledger

`protocol.py:227-232` justifies `extra="ignore"` so "a save written by a newer build must remain loadable by an older one." `save_version: Literal[1]` and `schema_version: Literal[6]` reject any newer save first — verified: both rejected. The rationale buys nothing while the setting costs real safety:

```
renamed coins_spent -> coins_spend : loads, coins_spent == 0 (was 18)   # all spending refunded
goal_sent key dropped              : loads, goal_sent == False
```

`test_campaign_save_tolerates_unknown_fields_for_downgrade` proves the mechanism on an invented field, never on the downgrade scenario the comment claims.

## M11 — The v0.6 T−60 gate fix reintroduces the defect it fixes, on the row v0.6 added

`IMPLEMENTATION_PLAN.md:45` gates regression tests **60–66** on "the bridge holds campaign state" (Phase 2), and `:57` states the Phase 0–2 stop "gates on exactly … regression 60–66." But test 60 requires "shop stock, a `buy_shop_stock` intent, a `PendingCheck` with `source="shop"`" and test 63 requires "stock cannot be priced at zero" — **the shop is Phase 6**.

This is the identical defect D2 opens by claiming to have fixed, reintroduced by the fix, in the same table, on the row v0.6 wrote. At T−60 the agent is told these are mandatory and simultaneously told "no new subsystems." It either builds shop code during the feature freeze or reports red on tests that were never buildable.

Related, same table: `IMPLEMENTATION_PLAN.md:112` puts finale gating in Phase 2 while `:158` puts it in Phase 6, and both halves are inside one document, so `README.md`'s authority order has nothing to arbitrate.

## M12 — `bootstrap.py` violates the packet's own #1 Archipelago non-negotiable

`bootstrap.py:85-97` spawns `python -c "import CommonClient, Utils"` with **no `SKIP_REQUIREMENTS_UPDATE`** anywhere in the file. `IMPLEMENTATION_PLAN.md:88` instructs "verify `import CommonClient` **with `SKIP_REQUIREMENTS_UPDATE=1`**"; `CLAUDE_HANDOFF.md:36` and `TECHNICAL_ARCHITECTURE.md:92` call it "mandatory, not hygiene."

The risk is live: AP 0.6.7's `requirements.txt` pulls `kivy`, `cython`, `orjson` and a git-sourced `kivymd`, and the packet itself documents that `update_command` ignores pip's exit code — so a partially-failed install leaves the probe at `ModuleUpdate.py`'s bare `input()`, inside the step that gates every later phase. The gotcha was found, documented three times, and then not applied in the packet's own script.

---

# 4. MINOR and NIT (confirmed, not itemized in full)

Cross-field links absent throughout: shop stock vs Zone allocation may reserve the same location; `ShopStockItem.status` vs `pending_checks` are two unlinked opinions about one purchase; snapshot counters are free integers (`coins_available=9999` with zero received; `signal_keys=0, unlocked_tier=2`; a location in both `checked_` and `missing_location_ids`); dict keys are unrelated to the ids inside their values (`echoes={"totally_bogus": echo_89100002}` validates, defeating the documented dedupe key); `ShopStockItem.cost` is unrelated to the 6/4/2 price table.

Also confirmed: `README.md:93` and `DECISIONS_TO_REVIEW.md:3` point at `CHANGELOG_v0.4_to_v0.5.md`, which no longer exists — and `check_packet.py` missed it because it skips every `.md` reference instead of checking that the file is there. `schemas/zone.py:1` and `schemas/echo.py:1` still say v0.5; `APWORLD_SPEC.md:176` pins `world_version: "0.5.0"`. Shop stock selection is called "deterministic" with no algorithm or seed, and `DESIGN.md` step 7's Track-fill order is undefined — the exact omission `DESIGN.md:218` names as a v0.3 defect. `IMPLEMENTATION_PLAN.md` has two steps numbered 22 and no step 35. `abandon_zone` has no specified affordance in `GENERATING` or `ZONE_READY`, the two states where it is the only exit. The bridge WebSocket port is prose-only and not in `constants.py`. Running pytest from the repo root collects 182, not the 91 the plan says means "you copied them wrong."

---

# 5. Reviewer claims not upheld

- **"`ZoneRecord` state transitions are unexecutable."** Not upheld. The atomic rebuild works and is documented in the model. Only the `CampaignSave` neighbour lacks the note (M1).
- **"The finale can be generated twice."** Not upheld. At most one Zone of any kind may hold locations, so any earlier finale record is terminal and reserves nothing. The abandon-and-retry shape is accepted, as intended.
- **"Blender is claimed installed but is absent."** Environment drift in this container, not a packet defect; the rule is "do not use it" either way.
- **"`bridge_connected=False` is unobservable."** True but harmless — it is a field Godot defaults, not a claim the bridge makes.

---

# 6. Verdict

**NO-GO for the unattended Fable pass.**

Not because the packet is unsound — reviewer 3, who was looking for exactly this, called the technical substance "unusually solid" and independently confirmed every Archipelago claim. The blocker and the majors are concentrated in two places, and both are places v0.6 touched:

1. **Cross-model invariants are enforced only at parse time**, and the packet says otherwise (B1, M1, M2, M3, M4, M7, M10). The bridge mutates state in place; the guards do not run there; the resulting save does not reload.
2. **The v0.6 fixes were verified against the paths they were written for, not against their neighbours** — M2 is the D1 sweep missing the snapshot, M11 is the D2 fix reintroducing D2, and M6 includes an acceptance test added in v0.6 whose premise the v0.6 schema forbids.

The second point is the one worth sitting with. v0.6's governing rule was "for every invariant you change, enumerate every path that can reach or mutate it." The rule was right and it was applied — the goal reservation survived three hostile reviewers, which no previous revision managed. It was applied to the *acquisition* paths and not to the *mutation* paths, and the test written to prove otherwise checked the half that works.

**These are one editing pass, not a redesign.** Reviewer 3's bottom line — fix the gate row, reconcile the finale phase duplication, fix `bootstrap.py`, define `finale_available` — plus a mutation discipline for the nested-model problem and the snapshot's missing validators, is the shape of v0.7. Three of the twelve majors (M6, M11, and M2) are v0.6's own; the rest were present in v0.5 and missed by passes 1–4.

Two of the findings are genuine product decisions rather than mechanical fixes and should not be decided by the author alone:

- **M9** — what should the Hub show when Archipelago drops while a campaign is loaded? The current rules make every honest answer unrepresentable.
- **M8** — should `SHOP_STOCK_SIZE` rise, or should reserved-but-pending stock move out of `stock` into its own list?

**The packet has not been modified since the freeze at `a24b8ba`.** Nothing in this document has been applied.
