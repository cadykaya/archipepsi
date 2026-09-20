# PROD — Wave-1 Final Promotion Integration

**Archipepsi Production lane · 2026-09-04**

Head before: `7e13f44`. Art promotion: `ab74f5e`. Art head synced: `7ecd3fe`.
Independent audit: `f97545f`.

**Wave 1 is complete. All twelve authored room shells are `review: pass`.**

---

## 1. Sync

Mirrored from `7ecd3fe`; no Art branch history merged.

| path | delta |
| --- | --- |
| `godot/content/registry/authored_art.json` | 4 lines |
| `godot/content/SCENE_PLAN.json` | 4 lines |

Both files are byte-identical between `ab74f5e` and `7ecd3fe` — the
documentation commits in between changed no generated content, so the bytes
integrated here are the promotion bytes produced at `ab74f5e`.

## 2. The exact eight-field delta

A recursive field-by-field walk of both JSON trees against `7e13f44`, not a
line count:

```
authored_art.json    /entries[11]/review              pending -> pass   (shell_hall_transit)
                     /entries[12]/review              pending -> pass   (shell_plenum_helix)
                     /entries[13]/review              pending -> pass   (shell_span_basin)
                     /entries[20]/review              pending -> pass   (shell_yard_gantry)
SCENE_PLAN.json      /provenance[11]/runtime_substitution  pending -> pass
                     /provenance[12]/runtime_substitution  pending -> pass
                     /provenance[13]/runtime_substitution  pending -> pass
                     /provenance[20]/runtime_substitution  pending -> pass
```

**Total changed leaves: 8. Distinct field names touched: 2** (`review`,
`runtime_substitution`). Checked explicitly against a forbidden-field list —
geometry, collision, scene, traversal, surfaces, sockets, volumes, offers,
connectors, size, semantic tags, fallback, camera, provenance asset and batch
review: **0 changes**. No key added, removed or reordered.

## 3. Review-state census

| category | pass | pending |
| --- | --- | --- |
| `room_shell` | **12** | 0 |
| `fixture` | **6** | 0 |
| `projectile_visual` | 0 | **3** |
| **total** | **18** | **3** |

21 entries validate against `ContentEntry` (pydantic v2, strict,
`extra="forbid"`). The three pending projectile substitutions are untouched —
they remain the standing proof that per-entry review is a kill switch in both
directions.

## 4. The approved catalog — twelve ids

| chamber type | count | ids |
| --- | --- | --- |
| `arena` | 3 | `shell_hall_transit`, `shell_span_basin`, `shell_yard_gantry` |
| `tower` | 4 | `shell_plenum_helix`, `shell_tower_collapsed`, `shell_tower_gantry`, `shell_tower_spiral` |
| `corridor` | 2 | `shell_corner_left`, `shell_corner_right` |
| `treasure_room` | 3 | `shell_treasure_cache`, `shell_treasure_coffer`, `shell_treasure_vault` |

**Wave-1 additions, exactly as expected:** `arena` +3 (the whole row is new);
`tower` +1 (`shell_plenum_helix`). Corridor, treasure-room and the three P2
towers are unchanged.

**No procedural fallback appears as an authored catalog choice** — the
authored manifest contains zero `procedural_fallback` entries; the procedural
set lives in Production's own `registry/legacy_procedural.json`.

**No pending entry is offerable** — `VisualOwnership.is_shippable` refuses a
`pending` entry and `ContentInstantiator` falls back to a real procedural
room. Proven by sabotage in §8.

## 5. The four promoted rooms

| room | structural | measured | surf | trav | sock | doors | hull |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `shell_hall_transit` | **0** | **0** | 12 | 12 | 21 | 2 | 73 |
| `shell_plenum_helix` | **0** | **0** | 20 | 15 | 28 | 2 | 152 |
| `shell_span_basin` | **0** | **0** | 6 | 5 | 15 | 2 | 57 |
| `shell_yard_gantry` | **0** | **0** | 6 | 5 | 16 | 2 | 43 |

All twelve approved shells measure `structural=0 measured=0`.

**Promotion strengthened the gate rather than relaxing it.** These four now
print `PASS` in the offer census, which means they are held to the *approved*
branch of `_test_every_declared_offer_is_true_against_real_geometry` — where a
declared offer that is false against its own geometry is a broken build, not
evidence for a review. They survive it with `declined=0`.

## 6. Offers, and the validation/construction boundary

```
shell_hall_transit    declared=6 accepted=5 built=2 declined=0
shell_plenum_helix    declared=6 accepted=5 built=2 declined=0
shell_span_basin      declared=6 accepted=5 built=2 declined=0
shell_yard_gantry     declared=6 accepted=5 built=2 declined=0
offer census: declared=24 judged=20 constructed=8 declined=0
```

| | count |
| --- | --- |
| offers DECLARED | **24** |
| JUDGMENTS returned by pure validation | **20** |
| DECLINED | **0** |
| offer nodes built by shipped gameplay | **0** |

The `7e13f44` ruling is intact and re-measured:

* `OfferBinding.validate` is pure — validating a live room once, then twice,
  changes node count, collider count and offer-node count by **0**.
* `validate_zone`, in the exact shape `ZoneController._validate_offers` hands
  it, builds **0** pad or rail nodes into a live chamber.
* The explicit `OfferBinding.construct` path still builds 8 nodes (4 rails +
  4 pads) and refuses a second construction into the same root.
* Mandatory routes work with zero offer geometry.
* **Promotion activated no movement offer.** Selectability and construction
  are different facts, and nothing in this integration touched the second.

## 7. Baseline — delta reported, then authorized

`make baseline` is deterministic: two consecutive runs are byte-identical.

**Complete delta, 12 differences, all in one path family:**

```
zones[0,1,2]/request/catalog/room_shells/arena   ADDED  ['shell_hall_transit',
                                                        'shell_span_basin',
                                                        'shell_yard_gantry']
zones[0,1,2]/request/catalog/room_shells/tower   3 -> 4  +['shell_plenum_helix']
```

**Differences outside a `catalog` path: 0.** Proven positively rather than by
absence: with `request.catalog` stripped, the whole document hashes
`5d3a4d90dac82d98` on both sides. Every recorded Zone output, Check
allocation, room result, score, level id, `measured` block and gameplay digest
is identical. Within `catalog`, `chamber_types`, `enemy_archetypes`,
`objectives` and `themes` are identical in all three zones.

The delta is restricted to the expected additions under
`zones[*].request.catalog.room_shells` and no output or gameplay value moved,
so the authorization condition is met and **the baseline is updated**.

## 8. Regression

| gate | result |
| --- | --- |
| Godot suites | **17 / 17 exit 0** |
| Python | **1140 passed, 0 failed, 0 skipped, 627 subtests** |
| Python environment | Python 3.11.15, pytest 9.1.1, `anthropic` 1.1.0, `.archipelago` checkout present, apworld built (`make setup` complete). Without the checkout: 1103 collected / 1098 passed / 5 skipped. Without `anthropic` as well: 1100 / 1094 / 6. Zero failures in every configuration. |
| Packet / schema gate | clean — 11 documents, 949 identifiers, 263 enum members |
| Authored registry validation | **PASS** — 21 entries against `ContentEntry` |
| Twelve shells, structural / measured | **0 / 0** each |
| Pure offer validation | 24 declared, 20 judged, 0 declined, 0 built by shipped gameplay |
| Pending-entry refusal sabotage | **bites** — disabling `VisualOwnership.is_shippable` turns the gate red on 8 shells ("`…` is pending and its authored scene was built anyway"); restored byte-identical |
| Catalog exactness | 12 / 6 / 3, 18 pass / 3 pending — exact |
| Baseline | delta confined to `catalog.room_shells`; deterministic; accepted |
| Played Zone | `6e8d83d0f3ec088b` — 23 rooms, 15 Checks, 922 points, 35 enemies, **unchanged and not regenerated** |

The pending-refusal test constructs its own pending shells rather than
borrowing whatever happens to be unapproved, which is why it still tests
something on the day everything is approved — the day it matters most.

## 9. Stale documentation corrected

* `docs/reports/2026-09-03-wave1-pre-promotion-guards.md` claimed the Plenum's
  annular collar convex disc was unresolved. It was stale when written.
  Corrected in place with the current truth: three collars, twelve convex ring
  sectors each, holes physically open, mesh volume equal to the sum of the
  sector hulls and to the analytic annulus within 0.0001 m³, and **zero
  non-convex collider nodes** across all twelve shells.
* `docs/AGENT_FRONTIER.md` carried two historical passages listing the collar
  and the absent canonical `supported` caller as open. Both are now **visibly
  marked superseded in place**, with what closed them. They are kept because a
  record of what a pass did not look at is worth more than a tidy history.
* A new current-state section — **WAVE 1 COMPLETE, 2026-09-04** — records the
  twelve-shell catalog, that promotion made the four selectable and nothing
  else, that the collar / canonical-query / launch-source-radius questions are
  resolved, that Wave 2 is unstarted, and that player-facing movement-package
  consumption is the next gameplay blocker.

No current-state section anywhere lists the collar, requirement 40, or
launch-source radius semantics as unresolved. (There is no "requirement 40"
text in the Production docs at all.)

## 10. Final state

**Wave 1: complete.** Twelve authored room shells, all `pass`, all measuring
true against their own geometry, all selectable.

**Wave 2: unstarted.** No Wave-2 room exists, is authored, or is planned in
code.

**Remaining gameplay blocker: player-facing movement-package consumption.** No
shipped consumer builds an authored rail or launch pad in a played Zone, so no
player has ridden one. That is a Playtest-3 milestone and it is the only thing
standing between the offer vocabulary and a player meeting it. It blocks no
room shell.

Not done, by instruction: the gameplay movement-package consumer, Wave 2,
Theme Packs, projectile promotion. No room geometry or offer data changed, the
played Zone was not regenerated, and owner form review was not reopened.

*No heartbeat is armed. Wave 1 is closed and CI is green, so the next task
should start by turning the trigger back on.*
