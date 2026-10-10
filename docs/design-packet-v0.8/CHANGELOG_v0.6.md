# Archipepsi — v0.5 → v0.6

What changed, why, and — for every invariant touched — which *other* paths to
the same invariant were closed at the same time.

v0.5's own changelog claimed fixes had landed everywhere when several had
landed in code and in one document. That is the same defect shape as the
blocker below, applied to prose, so this changelog states the paired-path
sweep explicitly and `check_packet.py` now enforces the prose half
mechanically.

---

# 1. The governing rule for this revision

> For every invariant changed, enumerate every path that can reach or mutate
> it and close the invariant across all of them.

Every finding in this packet's history has the same shape: an invariant
enforced thoroughly on one path and left open on its neighbour. The Check 030
shop exploit (below) is the clearest instance — the rule was stated in five
documents and enforced on one of six paths.

So each fix below lists its neighbours, and the regression tests are written
as **censuses** rather than reproductions: a new field or a new mode fails the
test until somebody classifies it. Reproducing the reported bug proves the
report is fixed; a census is what stops the next one.

---

# 2. Findings resolved

| # | Severity | Finding | Where |
|---|---|---|---|
| **D1** | Blocker | Check 030 was reachable through the shop. `ShopStockItem`, `BuyShopStock` and `PendingCheck` all accepted the goal, and `unlocked_location_ids()` — the helper the packet *mandated* allocators derive from — documented itself as "legal to allocate, goal included". Six coins bought the goal. | `constants.py`, `protocol.py`, `DESIGN.md` §10.4/§10.6/§11.3, `APWORLD_SPEC.md` §3 |
| **D2** | Major | The T−60 gate table keyed on phase ranges, so the plan's own expected stopping point (Phases 0–2) was gated on shop and finale tests that are Phase 6. | `IMPLEMENTATION_PLAN.md` §1.1 |
| **D3** | Major | `PENDING_GENERATION` had no Hub mode. The Hub had to report something else for the whole generation window; `ZONE_AVAILABLE` left the portal live and invited a second Zone request, and the finale guard did not cover the window either. | `protocol.py`, `DESIGN.md` §10.7/§13, `TECHNICAL_ARCHITECTURE.md` §7.1/§8 |
| **D4** | Minor | `ABANDONED` required an accepted Zone, so a generation that failed outright could not be abandoned — inside the state added to break exactly that deadlock. | `protocol.py`, `TECHNICAL_ARCHITECTURE.md` §7.1 |
| **D6** | Minor | The runtime Epsilon system prompt still asked for a "blocky" Zone, three revisions after the visual target became late-90s PC FPS. | `EPSILON_SPEC.md` §11, `DESIGN.md` §2/§21 |
| **D7** | Minor | Six themes were named and described only in prose, leaving ~40 material values to be invented — and six themes likely to render identically. | `constants.py`, `EPSILON_SPEC.md` §4 |
| **D8** | Trivial | Five places quoted a stale schema-test count. | packet-wide |
| **D9** | Trivial | The gate header said "Phase 0–3" where §1 says the expected result is Phases 0–2. | `IMPLEMENTATION_PLAN.md` §1.1 |

D5 and D10 remain open by choice; see §5.

---

# 3. D1 — the goal reservation, path by path

**One definition.** `GOAL_LOCATION_ID` is the last location id, which is not
an accident: it makes "any location except the goal" a plain closed range,
`FIRST_NON_FINALE_LOCATION_ID..LAST_NON_FINALE_LOCATION_ID`. A range is
expressible in JSON Schema and in GDScript, so the restriction now survives
into `protocol.schema.json` (the provider's structured-output contract) and
`constants.gd` — not just into a Python validator the bridge might forget to
call. An assert fires if the goal ever stops being the last id.

Every path that can reserve, stock, price, sell or claim a location:

| Path | v0.5 | v0.6 |
|---|---|---|
| Ordinary Zone allocation | rejected by `ZoneRecord` validator | unchanged, plus both directions asserted in one named validator |
| Shop stock | **accepted the goal** | `_NON_FINALE_LOC` — cannot express it |
| `buy_shop_stock` intent | **accepted the goal** | `_NON_FINALE_LOC` — an unparseable message, not a refused one |
| `PendingCheck(source="shop")` | **accepted the goal** | rejected; `source="zone"` still accepts it, which is how the finale claims it |
| Allocator helper | `unlocked_location_ids()`, "goal included" | `eligible_location_ids()`, goal-free, and the old helper's docstring now says in terms that it is the APWorld's region-rule function and no allocator may call it |
| Shop restock procedure | prose "not Check 030" | starts from `eligible_location_ids()`, same function as the Zone allocator |
| Fallback provider | prose | structurally impossible: allocation is committed at `PENDING_GENERATION`, before any provider runs, and both providers are checked against the same set by `validate_zone()` |
| Save / reload | unchecked | `CampaignSave` rejects a pending goal claim with no finale `ZoneRecord` |
| Finale Zone | permitted | unchanged — the one model allowed to carry it, and only with `is_finale=True` |

A related leak on the same paired path: `PendingCheck.shop_cost` was
unconstrained, so a Zone claim could debit `coins_spent` and a shop purchase
could cost nothing. It is now 0 for `source="zone"` and ≥1 for
`source="shop"`, with `ShopStockItem.cost` raised to `ge=1` to match — a
divergence the fix would otherwise have introduced.

**Regression tests** (`schemas/test_schemas.py`, v0.6 section 1):
`test_every_location_bearing_field_is_classified` is a census of every
location-bearing field in the protocol against a written classification, so a
new field fails until somebody decides whether the goal belongs on it;
`test_forbidden_paths_exclude_the_goal_in_the_exported_schema` asserts the
bound survives export; `test_no_acquisition_path_accepts_the_goal` walks all
of them at once; plus the allocator, save-file and coin-accounting tests.

---

# 4. D3 — one Zone at a time, including while generating

`GENERATING` is now a real `HubMode` with the portal disabled, and
`generation_in_progress` is *derived* from it rather than tracked beside it —
a boolean that can disagree with the state it describes eventually does.

| Paired path | v0.5 | v0.6 |
|---|---|---|
| `PENDING_GENERATION` vs `GENERATED` vs `ACTIVE` | related only by prose | `CampaignSnapshot` validates the mapping on every snapshot: `GENERATING` / `ZONE_READY` / `ZONE_ACTIVE`, and a terminal Zone is never presented as active |
| Ordinary vs finale generation | the guard listed `ZONE_READY` and `ZONE_ACTIVE` only | `HubStatus.accepts_zone_request` is a property of the mode alone; `RequestNextZone.finale` chooses *which* Zone, never *whether* one may start |
| Finale offered mid-Zone | suppressed during play, not during generation | `ZONE_HELD_MODES` covers all three held states |
| `holding_finale` | tracked separately | validated against `active_zone.is_finale` |
| Parse-time vs post-parse | `validate_assignment=True` already set | asserted for each new rule, so in-place bridge mutation is covered too |

`ZoneRecord` also became exact rather than one-directional:
`PENDING_GENERATION` now means *no content yet*, full stop, so "generating"
and "generated" cannot both be true of one record. Accepting a Zone is one
atomic construction — documented in the model, because
`validate_assignment=True` deliberately rejects the two-step version and
`model_copy(update=...)` would skip validation entirely.

**Regression tests** (v0.6 section 2): `MODE_BUCKETS` is a census of every
`HubMode`, so a new mode fails until classified; the state→mode mapping is
checked exhaustively in both directions; and each test iterates the literal
bucket rather than the constant under test, so a constant that loses an entry
still fails.

---

# 5. Deliberately still open

The six implementation-time items stay open. None can corrupt campaign or AP
state, and none blocks Phases 0–2:

- **D5** — Godot's `--script` mode is the assumed headless test harness; unverifiable here without a Godot binary, and the plan already tells the agent to say so honestly rather than install one.
- **D10** — `export.py`'s default outdir is cwd-relative. Cosmetic; the Makefile target passes a path.
- Enemy navigation quality, texture-generator specifics, exact reveal timing, and shop copy remain implementation choices, as before.

Nothing in this pass proved any of them necessary for correctness, so none
were expanded.

---

# 6. Mechanical guards added

- **`check_packet.py`** — validates the prose against the models: every JSON example parses and validates, every backticked UPPER_SNAKE identifier resolves to a real constant/field/enum member, every enum-shaped quoted string is a real member, retired terminology stays retired, quoted test counts match the suite, and every catalog member defined in code is named somewhere in the prose. The v0.5 drift was found by an ad-hoc script that was never committed; this one is committed and runs in Phase 0.
- **Schema suite: 73 → 91 tests.** All green. The eight fixes above were each mutated back and confirmed to fail the suite.
- Artifacts (`zone.schema.json`, `echo.schema.json`, `protocol.schema.json`, `constants.gd`) regenerated; the staleness test proves they match.
- Protocol and schema versions bumped 5 → 6.
