# Archipepsi — Build Packet v0.8

The implementation contract for Archipepsi.

v0.3 was a design packet. v0.4 made it an implementation contract. v0.5 is the version that survived four independent hostile reviewers who had not designed it. v0.6 closes the defects a fifth review found, and — more importantly — closes them across *every* path that can reach each invariant rather than only the one the reviewer reproduced. v0.7 was the contract the POC was actually built from, and it was built: Phases 0–7 are complete and green.

**v0.8 is a deliberate widening of one system, not a new packet.** The POC proved the loop works and then showed what the loop could not express: a foreign item could only ever become one ability, so twenty-six of them read as one thing with twenty-six names and no build ever developed. `ECHOES.md` replaces that contract. Everything else is rolled forward unchanged — same Archipelago side, same allocation, same transaction layer, same Zone and chamber schema, same Hub, shop and finale.

This is explicitly **not** a reopened design review. Files this change does not touch are the v0.7 text, version-stamped and otherwise verbatim.

*Archipepsi* is the project codename. The game's terminology is not soda-based; a real title comes once we know what it feels like.

---

## Read in this order

1. `CLAUDE_HANDOFF.md` — mission and non-negotiables
2. `DESIGN.md` — what the game is
3. `TECHNICAL_ARCHITECTURE.md` — process boundaries, protocol, persistence
4. `APWORLD_SPEC.md` — the Archipelago side *(unchanged in v0.8)*
5. `EPSILON_SPEC.md` — what Epsilon may receive, decide, and emit
6. **`ECHOES.md`** — **what an Echo is.** Normative for the v8 Echo contract; supersedes DESIGN §15/§19 and EPSILON_SPEC §8/§10/§12.2/§13 as they stood in v0.7
7. `schemas/` — **the binding contract. Copy verbatim; run its tests first.**
8. `IMPLEMENTATION_PLAN.md` — build order and stopping rules (§2.5 is the Echoes 2.0 staging)
9. `ACCEPTANCE_TESTS.md` — observable pass/fail (§5.7 is the invariant matrix)
10. `DECISIONS_TO_REVIEW.md` — only what is still genuinely open

`check_packet.py` validates this prose against `schemas/` — every JSON example, every named constant and enum member, the retired terminology, and the quoted test count. Run it after editing any document; a green schema suite does not prove the prose still describes it.

`CHANGELOG_v0.8.md` maps every Echoes 2.0 change to its resolution; `CHANGELOG_v0.7.md` maps every pass-5 finding to its; `CHANGELOG_v0.6.md` and `CHANGELOG_v0.5.md` do the same for passes 4 and 3. `../design-packet/` (v0.3), `../design-packet-v0.4/`, `../design-packet-v0.7/` and `../audit/` are history, not authority — do not implement from them.

---

## Authority order

If two files disagree:

1. **`schemas/`** — executable, tested, and therefore unambiguous. Beats all prose.
2. **`DESIGN.md`** — what the game is and how it should feel.
3. **`APWORLD_SPEC.md`** — Archipelago generation, network and logic rules.
4. **`ECHOES.md`** — what an Echo is. Beats DESIGN and EPSILON_SPEC on Echoes specifically, and nothing else.
5. **`EPSILON_SPEC.md`** — what Epsilon may receive, decide and emit.
6. **`TECHNICAL_ARCHITECTURE.md`** — implementation boundaries, persistence, security.
7. **`ACCEPTANCE_TESTS.md`** — observable behavior.
8. **`IMPLEMENTATION_PLAN.md`** — build order, not product truth.

No exceptions. `schemas/` is the v8 contract — `echo.py`, `mechanics.py` and `migration.py` included — and it outranks every document here, `ECHOES.md` among them.

There was a temporary exception while this packet was revised ahead of implementation: `ECHOES.md` was normative for the Echo contract until S1 landed the executable version. **S1 landed it, and the exception is gone.** `check_packet.py` now derives the action primitive count from `ACTION_PRIMITIVES` rather than trusting the prose, so the catalog cannot drift from the enum again.

`schemas/` sits at the top because a Pydantic model that runs cannot be misread, and every number in it is asserted by a test. Where this document set says something a schema contradicts, the schema is right and the prose is a bug — report it in `docs/IMPLEMENTATION_DECISIONS.md`.

If a real technical constraint makes an authoritative requirement impossible, preserve the closest working behavior and record the deviation. Do not silently redesign the product.

---

## Mental model

```
ARCHIPELAGO                    owns randomized truth
        |
        v
PYTHON BRIDGE                  owns the Archipepsi campaign
  ├─ AP client (CommonContext, pinned checkout)
  ├─ deterministic allocator   chooses AP location IDs
  ├─ campaign state + save     coins, shop, pending tx, echoes
  └─ Epsilon providers         designs presentation only
        |
        v  campaign_snapshot / zone_ready
      GODOT                    renders, simulates, sends intents
        |
        v
   PLAYER CLAIMS CHECK ──> AP CONFIRMS ──> REAL ITEM SENT
                                  |
                                  └──────> LOCAL ECHO ──> FUTURE DESIGN
```

> **Archipelago decides the randomized truth. Archipepsi's deterministic code decides which truth is currently presented. Epsilon decides what that presentation feels like.**

---

## POC shape

30 Checks · 2 Signal Keys · 3 AP tiers · 10 Epsilon Coins · 18 Epsilon Static · fixed Hub · 2–3 Checks per Zone · a reserved single-Check finale · postgame · 5 chamber templates · 3 enemy archetypes · 3 objectives · 6 late-90s material sets · one equipped Echo · 10 composable Echo effects · Hub-only shop · Claude-compatible Epsilon with mock and deterministic fallback providers · stock Godot 4.5.1 · Python 3.11 bridge on a pinned Archipelago 0.6.7 checkout.

Visual target is **GoldSrc-era PC FPS**, not Minecraft. No Godot fork. No model-generated executable code. No Echo-gated mandatory traversal — in either direction.

---

## What changed in v0.5

Five criticals from the independent audit, plus a visual retarget and a terminology purge.

- **The `GENERATED` Zone state is real now.** `active_zone_id` is set when a Zone is saved, not entered; `enter_zone` exists; the Hub has `ZONE_READY`; reconciliation handles every state. In v0.4 a Zone abandoned at the loading screen orphaned its AP locations permanently, and twice made the campaign unwinnable.
- **The shop cannot double-charge.** A purchase now checks for an existing pending transaction, and stock carries a status the snapshot can express.
- **An unfinishable Zone can be abandoned**, and enemies have a fall-kill rule so the likeliest cause never happens.
- **Sending the goal no longer ends play.** Postgame keeps the portal live; up to five real AP locations are no longer abandoned along with other players' items.
- **Passive Echoes cannot break traversal.** Their multipliers are derived *from* the traversal bounds, and gap and step are bounded jointly.
- **Three real `CommonContext` behaviours** are documented rather than assumed: pip-at-import, the disconnect wipe, and `on_package` being synchronous.
- **The look is late-90s PC FPS**, not Minecraft. Same zero-asset pipeline, 64×64 procedural textures.
- **No soda in the game.** Signal Key and Static Pulse; *Archipepsi* stays as the codename.

Full traceability: `CHANGELOG_v0.7.md`.

### What v0.8 changes

- **An Echo contributes components, not one ability.** Action, Trait, Resource, Rule, Status, Affordance, Info. Only Actions occupy a slot, so a Check keeps mattering whether or not you ever equip it.
- **Items can answer each other.** `CREATE` / `UPGRADE` / `MODIFY` / `LINK` / `MERGE`, which is why *Longshot* after *Hookshot* is one grapple at Mk II rather than a second grapple.
- **The campaign is an append-only log, folded.** Live mechanics are a pure fold over interpretations in grant order — which is what makes provenance, determinism, save safety, Mk levels and cross-item modification the same mechanism rather than five.
- **Rules cannot cascade.** Effects never emit events; threshold events are edge-derived at end of tick and deferred by at least one tick.
- **Twenty-eight action primitives**, closed and validated, so the verbs widen alongside the systems.
- **The floor got blunter, not softer.** Derived movement stats have a hard floor at base, so `max_safe_gap` and every generated jump stay valid unmodified.

Full traceability: `CHANGELOG_v0.8.md`.
