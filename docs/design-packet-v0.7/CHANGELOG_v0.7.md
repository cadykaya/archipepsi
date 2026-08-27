# Archipepsi — v0.6 → v0.7

Pass 5 put three unanchored reviewers on the frozen v0.6 packet and confirmed
one blocker and eleven majors. This revision closes them, and it does so by
**removing machinery rather than adding it** — the implementation contract had
started generating its own complexity, and roughly half the confirmed findings
were caused by a validator that existed.

Net: five `HubStatus` fields became derivations, six validator branches went
away, two invariants merged into one, `dict` and `list` left the campaign
models entirely, and the suite grew from 91 to 110 tests.

---

# 1. The blocker, and the architectural change it forced

**B1 — `validate_assignment=True` never reached nested models or lists.**

It re-validates top-level assignment only. These ran no validators at all:

```python
save.zones["z1"].state = "COMPLETE"      # nested model
save.pending_checks.append(...)          # list
save.shop.stock.append(...)              # list
```

Each produced a campaign that serialized cleanly and then failed to load, so
the bridge fell back to `.bak` and silently rolled back a completed Zone or
re-enabled a spent purchase. The duplicate-pending rule that exists to stop
the shop double-charge was bypassable with one `append`.

Worse, v0.6 shipped a test — `test_the_new_invariants_survive_post_parse_mutation`
— asserting the invariants held under post-parse mutation, which checked only
the half that worked. A test that manufactures false assurance about a guard
is worse than no test at all.

**The fix is not another validator.** Pydantic models are now what they always
should have been here: **frozen value objects**. Every model is
`frozen=True`, every collection is a tuple, and persistent change goes through
`schemas/transitions.py` — thirteen functions, each of which builds the
complete next `CampaignSave` and validates it in one step.

An invariant checked at construction is now checked at every point the
campaign ever reaches, because construction is the only moment there is.

Two things this removed rather than added:

- `dict[str, ZoneRecord]` and `dict[str, Echo]` are gone. They were keyed by
  an id that nothing tied to the id inside the value, so
  `{"totally_bogus": echo_89100002}` validated and defeated the dedupe key the
  Echo design is built on. Tuples plus `zone_by_id()` / `echo_by_id()`: one
  representation, no key to disagree.
- `ShopStockItem.status` is gone. It was a second opinion about the same fact
  as `pending_checks` and could disagree in both directions. Stock now means
  *purchasable*; buying removes the item and creates the pending record in one
  transition, and the ledger is the only source of truth.

---

# 2. Findings resolved

| # | Was | Now |
|---|---|---|
| **B1** | Nested/list mutation bypassed every cross-model invariant | Frozen value objects + `transitions.py` |
| **M1** | Completion and abandon documented as two assignments; both orders raise | `complete_zone()` / `abandon_zone()`, atomic |
| **M2** | `CampaignSnapshot` lacked the invariants `CampaignSave` enforced | Shared module-level checks, called by both |
| **M3** | `coins_spent` unlinked from pending purchases; documented rollback raised | `_reject_underfunded_ledger`; `rollback_shop_purchase()` |
| **M4** | A `PendingCheck` needed no allocation behind it; reconcile re-sent 29 free items | Every `zone` claim must be held by a live Zone |
| **M5** | The finale gate was decorative — `FINALE_ONLY` at 0/24 validated | `finale_unlocked` computed from the counters |
| **M6** | `finale_available` meant two things; `DESIGN.md` stated the opposite of the schema | `finale_unlocked` (threshold) vs `finale_offered` (offerable now) |
| **M7** | One stuck location could only be released by abandoning its Zone | Allocation may shrink; `release_location()` |
| **M8** | A restock evicted an in-flight purchase, whose cost was already spent | Pending purchases leave `stock` and do not count against the cap |
| **M9** | "Archipelago is down" had no representable Hub state | `ap_online`; `portal_enabled` derived from both axes |
| **M10** | `extra="ignore"` could not do what it claimed, and zeroed a renamed ledger key | `extra="forbid"`; a bad save falls to `.bak`, honestly |
| **M11** | The v0.6 gate fix reintroduced the defect on its own new row | 60/63/66 split out as shop-dependent |
| **M12** | `bootstrap.py` omitted `SKIP_REQUIREMENTS_UPDATE`, the packet's own #1 gotcha | Set, with `stdin=DEVNULL` |

Minors closed: the dangling `CHANGELOG_v0.4_to_v0.5.md` references (and the
`check_packet.py` gap that let them through — it skipped every file reference
instead of checking it); stale `v0.5` module headers and `world_version`;
duplicate step 22 and missing step 35; the WebSocket port now in
`constants.py` as `BRIDGE_HOST`/`BRIDGE_PORT`; `shop_stock_seed()` for the
restock shuffle the packet called deterministic without supplying a seed; the
Hub-side Abandon control specified; a wrong `§12` cross-reference.

---

# 3. What simplification actually looked like

`HubStatus` is the clearest case. v0.6 had eleven settable fields and six
validator branches keeping them consistent. v0.7 has the same information with
five fields **derived**:

| Field | v0.6 | v0.7 |
|---|---|---|
| `portal_enabled` | set by the bridge, tied to `mode` by a validator | computed from `mode` **and** `ap_online` |
| `generation_in_progress` | set by the bridge, tied to `mode` by a validator | computed |
| `finale_available` | set by the bridge, constrained four ways | split into computed `finale_unlocked` + `finale_offered` |
| `accepts_zone_request` | a plain property Godot could not see | computed and exported |
| `coins_available` | a free integer on the snapshot | computed |

Every one of those validators existed to stop a field disagreeing with a fact
it was derived from. A field that cannot be set cannot disagree, so the
validators went with them. The rules that remain describe genuinely
independent facts.

Same pattern in the invariants: v0.6's special-case "a pending goal claim
needs a finale Zone" is gone, subsumed by the general rule that every pending
Zone claim must be backed by a Zone still holding that location — because the
only Zone allowed to hold Check 030 is the finale. One stronger rule, two
fewer places to drift.

**Direction of travel:** the goal reservation from v0.6 is untouched and still
holds. Three reviewers attacked it independently and none got through, in the
models or in the exported JSON Schema. That fix was right; it was just applied
to the acquisition paths and not the mutation paths.

---

# 4. Export mode — a bug this change would have introduced

Deriving half of `HubStatus` nearly handed Godot a contract without it.
`TypeAdapter.json_schema()` defaults to validation mode, which **omits
computed fields**, so `protocol.schema.json` would have described a snapshot
with no `portal_enabled`, `finale_offered` or `coins_available` — and the
engine would have had to re-derive the rules, which is exactly the drift
`constants.gd` exists to prevent.

`export.py` now picks the mode by direction: serialization for bridge→Godot
messages, validation for Godot→bridge intents and for the provider's Zone and
Echo contracts. Pinned by test.

---

# 5. Still open, by choice

`DECISIONS_TO_REVIEW.md` carries these. None can corrupt campaign or AP state
and none blocks Phases 0–2:

- Godot's `--script` mode as the headless harness is unverifiable without a
  Godot binary; the plan already tells the agent to say so rather than install
  one.
- `export.py`'s default outdir is cwd-relative; the Makefile target passes a
  path.
- Enemy navigation quality, texture-generator specifics, reveal timing and
  shop copy remain implementation choices.
- Snapshot counters other than `coins_available` (`static_glitch_units`,
  `completed_zone_count`) are still free integers. They are display-only and
  cannot strand a location or spend a coin; linking them would add validators
  in a revision whose point was removing them.
