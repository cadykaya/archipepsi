# Archipepsi — Build Packet v0.4

The implementation contract for the Archipepsi proof of concept.

v0.3 was a design packet. v0.4 is an implementation contract: every product decision is made, every gameplay number is pinned, and the generation contract is executable code rather than prose plus an example.

---

## Read in this order

1. `CLAUDE_HANDOFF.md` — mission and non-negotiables
2. `DESIGN.md` — what the game is
3. `TECHNICAL_ARCHITECTURE.md` — process boundaries, protocol, persistence
4. `APWORLD_SPEC.md` — the Archipelago side
5. `EPSILON_SPEC.md` — what Epsilon may receive, decide, and emit
6. `schemas/` — **the binding contract. Copy verbatim; run its tests first.**
7. `IMPLEMENTATION_PLAN.md` — build order and stopping rules
8. `ACCEPTANCE_TESTS.md` — observable pass/fail
9. `DECISIONS_TO_REVIEW.md` — only what is still genuinely open

`CHANGELOG_v0.3_to_v0.4.md` maps every audit finding to its resolution. `../design-packet/` preserves v0.3 and `../audit/PASS_1_AUDIT.md` the review that produced this version — history, not authority.

---

## Authority order

If two files disagree:

1. **`schemas/`** — executable, tested, and therefore unambiguous. Beats all prose.
2. **`DESIGN.md`** — what the game is and how it should feel.
3. **`APWORLD_SPEC.md`** — Archipelago generation, network and logic rules.
4. **`EPSILON_SPEC.md`** — what Epsilon may receive, decide and emit.
5. **`TECHNICAL_ARCHITECTURE.md`** — implementation boundaries, persistence, security.
6. **`ACCEPTANCE_TESTS.md`** — observable behavior.
7. **`IMPLEMENTATION_PLAN.md`** — build order, not product truth.

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

30 Checks · 2 Pepsi Keys · 3 AP tiers · 10 Epsilon Coins · 18 Epsilon Static · fixed Hub · 2–3 Checks per Zone · a reserved single-Check finale · 5 chamber templates · 3 enemy archetypes · 3 objectives · 6 themes · one equipped Echo · 10 composable Echo effects · Hub-only shop · Claude-compatible Epsilon with mock and deterministic fallback providers · stock Godot 4.5.1 · Python 3.11 bridge on a pinned Archipelago 0.6.7 checkout.

No Godot fork. No model-generated executable code. No Echo-gated mandatory traversal.

---

## What changed from v0.3

Five decisions and roughly fifty fixes. In brief:

- **The campaign brain moved from GDScript to Python.** Allocation, tiers, coins, shop, pending transactions, saves and reconciliation are now unit-testable without an engine.
- **The Archipelago dependency is pinned and scripted.** `bootstrap.py` clones AP 0.6.7; there is no pip package and `CommonClient` imports the whole `worlds` package.
- **Check 030 is fully reserved** and reached through a dedicated finale Zone that unlocks at 2 Keys + 24 of the other 29 Checks. In v0.3 the goal could be bought from the shop for 2 coins.
- **Every gameplay number exists**, in `schemas/constants.py`, with `SAFE_BASE_JUMP_GAP` *derived* from the jump arc rather than measured in-engine.
- **The Hub has a `WAITING_FOR_AP` state** and Zones have an exit portal. Neither existed.
- **Check finalization reconciles against `checked_locations`** rather than waiting for a server event that Archipelago does not send.
- **The schemas are real code**, with discriminated unions that make Echo composition rules and the no-Echo-gates guarantee structural.
- **LMB is always Pepsi Pop; RMB is the Echo.**

Full traceability: `CHANGELOG_v0.3_to_v0.4.md`.
