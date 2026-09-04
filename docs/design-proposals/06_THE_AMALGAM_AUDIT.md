# DESIGN 06 — REPAIR AND REBASE AUDIT

**Scope:** repair and rebase of `06_THE_AMALGAM.md`. Not a redesign; the architecture is owner-selected and preserved.
**Rebased onto:** `ARCHIPEPSI_CONTINUITY_2026-09-04` (owner rulings + runtime findings), and the exact current copies of `00`–`05`.
**Verdict:** **PASS.** See §7.

---

## 1. The most important finding: the external audit ran against a stale packet

An independent adversarial audit supplied 32 findings. Its five reference-integrity BLOCKERs (A03–A07) were checked mechanically against the live repository first, and **four are false against the current files**:

| Claim | Mechanically checked | Reality |
|---|---|---|
| A03 — `00` is v1.0 while `06` claims v1.1 | `00_ZERO_GUESSWORK_STANDARD.md:4` | **False.** The file says `**Version:** 1.1`. No skew, no reconciliation needed. **Required Repair 2 is a no-op and the standard was not touched** |
| A04 — Design 1 §21.1.1 does not exist | `01_RELIABLE_CORE.md:2292` | **False.** `### 21.1.1 Power loss` exists |
| A05 — D1's vectors end at V81; `06` cites 54 nonexistent ones | Parsed D1 §38 | **False.** D1 has **141** vectors. All 145 source-vector citations in `06` resolve. **Broken vector references before repair: 0** |
| A07 — power loss is a silent change from D1's "everything holds" | `01_RELIABLE_CORE.md:2292` | **False as stated.** D1 §21.1.1 already carries the per-kind table, and `06` already declared it as a modifier |
| A06 — the pin/modifier ledger is incomplete | Read §0.5 vs the document | **TRUE.** Repaired |

**Why this matters beyond bookkeeping.** The stale packet predates repairs made in the authoring session — D1's §21.1.1 table, the v1.1 bump, and D1's full vector set. An auditor working from an export cannot see them. The lesson is recorded rather than scored: **audit against the branch, not against an export.**

**What this does not do is discredit the audit.** Its substantive findings — arithmetic, ordering, determinism, budget conflicts — were checked individually and **most were real**, including two the authoring session had itself introduced or missed. They are repaired below.

---

## 2. Repairs, with old and new behaviour

### 2.1 The rebase — Epsilon, `shell_id`, and the committed manifest

| | |
|---|---|
| **Was** | §30.1: *"Pinned: identical to Design 1 §30.1. **Nothing in Zone composition.**"* `shell_id` appeared **zero times** in the document |
| **Now** | §30.1 rebased; **§30.11 added** (nine subsections): required non-nullable `shell_id`; bridge-filtered `offered_shells`; type/purpose compatibility table; runtime instantiates exactly that id; `SHELL_FOR_TYPE` never consulted for a room record; six-row failure table; deterministic offline selector; committed `ZoneManifest` with digest and provenance; committed replay verdicts |
| **Why** | The 2026-09-04 runtime finding: every played chamber carried `shell_id: null`, all 23 chambers were procedural, no authored room had ever reached a player. 3B is reserved to close it. A final design that keeps Epsilon out of Zone composition specifies a seam the project has already decided to close |
| **Source intent** | **Deliberately modified.** Design 1 §30.1 and Design 3 §30.1 are superseded by a newer owner ruling, per the continuity archive's authority hierarchy. Recorded in §0.5's ledger |
| **Authority not widened** | §30.11.9: Epsilon emits no transform, distance, node graph, completion condition, callback, or balance number. It picks one name from a bridge-proved list, and §30.5 check 19 re-proves the choice |

### 2.2 Determinism — the conflict the rebase creates, and its closure

| | |
|---|---|
| **Problem** | Model output is not reproducible on a future call. "Re-ask Epsilon on load" is not determinism. Separately, Godot's solver is not guaranteed identical across machines, so a client-side replay verdict could differ and two clients would compose different Zones from one seed |
| **Now** | §30.11.7: composition commits an immutable manifest; save, load, and replay reconstruct **from the manifest**, never from the model. §30.11.8: replays run **once**, in the canonical bridge environment, and each verdict is committed as data covered by `manifest_digest`. The client never re-runs a replay |
| **Consequence** | §35.4's `7.2 s` is a one-time composition cost, not a per-load one |

### 2.3 Arithmetic

| Finding | Was | Now |
|---|---|---|
| **Replay wall clock** | `1.8 s` — which requires `160×` throughput while the same sentence assumed `40×` | **`7.2 s`.** `36 × 8.0 s = 288 s` simulated ÷ `40×` = `7.2 s`, serial, single-environment, with the execution model contracted in §35.4 |
| **Total composition** | `28.0 s`, derived from the wrong replay figure | **`50.0 s`** = `5` attempts × (`7.2` + `2.0` + `0.8`). A first-pass attempt is `10.0 s` |
| **Weapon space** | `175,155,080`, asserted "unchanged because no Weapon dimension gained an atom" | **`179,326,745`.** The claim was false: §11.7 adds `payload_impulse` and `payload_anchor_point`. Enumerated exhaustively over the real catalog with two new mask rows |
| **Atom catalog** | `110` | **`121`.** The earlier figure counted only the `effect` delta and missed `+2` payload and `+9` Gear domain |
| **Frame budget** | rows summing to `16.7 ms` against a `16.667 ms` frame | Rows sum to **`16.5 ms`** with `0.167 ms` unallocated |
| **Package density** | `2`–`4` per room → `16`–`48` per Zone | **`PACKAGE_DENSITY` by purpose** (§24.1.1) → exactly `11`/`13`/`16` for `8`/`10`/`12` rooms |
| **Variety claim** | `38%` / `51%` duplicate reduction, computed over a population the composer never generates | **`42%` / `58%`**, recomputed over the real population. The correction moved *in the flattering direction*, which is why it had to be recomputed rather than left |

Ability space is unchanged at **`16,586,524`** — the `effect` dimension was already enumerated correctly.

### 2.4 Ordering and proof defects

| Finding | Was | Now |
|---|---|---|
| **State-vector allocation** | Step 8 allocated latch headroom from "variables and the key count" while encounter, shortcut, and visit flags were still being decided. Check 12 **discovered** overflow | §30.3 steps 8–9: **freeze every non-latch dimension, compute the exact product, then allocate**. An explicit freeze rule makes a package that would add a dimension unselectable. Check 12 is now a proof; a failure is a composer bug |
| **Property 4** | *"home room is in `{c.room : c ∈ R}` for every `v`"* — asks whether the room appears **somewhere**, not whether the player can still reach it | §30.6.1: quantified per configuration via `REQ(o)` and `HOME(o)`, one reverse BFS per required object, ≤ `8` extra searches. Fixture **U10** must fail composition and does not under D3's wording |
| **Checkpoints** | *"initial state is conservative because opening the machine only shortens distances"* — false for a reversible machine, and disproved by the document's own U1 fixture | §30.7.1: validated over the verified reachable configuration set, reusing §30.6's BFS layers |
| **"All latches false is conservative"** | Asserted | §30.7.2 + **structural check 18**: no negated vector-latch term in any edge predicate or mandatory gating expression. Monotonicity is now enforced, not claimed |
| **Replay context** | One replay in one physical configuration proved a Latch transition the verifier permits from many macro states | §23.5.1 **check 22a**: physical invariance under every `MacroEffect` reaching the package's room, with the harmless set enumerated. Fixture **U11** |

### 2.5 Runtime-versus-verifier disagreements

| Finding | Was | Now |
|---|---|---|
| **Status budget vs Latch transition** | The runtime could refuse the very Status application the verifier assumed settable — the verifier proving a transition the runtime can decline | §35.2.1 **reserved capacity**: mandatory packages reserve exact entries and body slots at composition; ordinary applications may consume only unreserved capacity; **check 20** bounds the sum. Fixture **U9** saturates every unreserved slot and the mandatory latch still solves |
| **Status staggering** | `frame_index mod 60` — renderer-rate dependent. At `120 fps` this is `2 Hz`, at `30 fps` `0.5 Hz` | §35.3: `sim_tick mod SIM_HZ` on the fixed `60 Hz` gameplay tick. Fixture **U12** replays at four render rates for byte-identical state |
| **Deferred `POWER_OFF`** | *"cannot deadlock because movement-removing Statuses expire"* — wrong twice: a player may simply stand there, and base movement existing does not prove egress geometry exists | §21.11.1: full persistence contract (shape, category, save/load order, unload, Zone exit, conflict policy **latest-wins**), plus **check 21** requiring base-movement-safe egress under every reachable macro state |

### 2.6 Contradictions

| Finding | Was | Now |
|---|---|---|
| **Mobility schema** | §12.8 *"not composed"*; §36.1 *"Mobility hosts are composed"*; Forge eligibility undefined | §12.8 gains a five-row total-exemption table: no `composition` field, not Epsilon-composed, **not Forgeable**, absent from §12.7's space, Gear may still scale it. §36.1's two rows corrected |
| **`exposed`** | *"No Status modifies a damage number"* + `exposed` sets Defense to `0.0` = *"a rule change rather than a multiplier"*. Defense is read by the resolver on every hit; this is a word game | §15.3 restated as three rules: (1) no Status deals or schedules Health damage, absolute; (2) no actor Status modifies raw damage, crit chance, or crit multiplier; (3) **`exposed` is the one declared exception to rule 2**. Also restricted to **actor only** — objects have no Defense stat, and the prior "actor, object" silently invented one |
| **66-pair map** | `Mobility—composition`, `Status—composition`, `Status—Forge` misclassified as orthogonal against other sections | All four rows corrected; `Status—Forge` moved to INTERACTS; `Status—composition` split into Zone composition (orthogonal) and item composition (interacts) |
| **Pin ledger** | §0.5 claimed completeness, omitted §19.3, §21.1.1, §23.4, §32.1.1 and more | Ledger extended to **12 rows** with an explicit completeness claim tested by vector 3 |

### 2.7 Procedural determinism

| Finding | Was | Now |
|---|---|---|
| **RNG semantics** | `rng.int(a,b)` used for inclusive counts *and* for list indexing — opposite bounds | §30.3.1: `rng.range(a,b)` inclusive for counts, `rng.index(n)` half-open for indexing. `rng.index(0)` is an error, not a draw |
| **`~40%` unconditional** | A weight, not a rule | §30.3.2: iterate edges in ascending `(room_a, room_b)`; edge is unconditional when `rng.range(0,99) < 40`. One draw per edge, fixed order |
| **"drawing from the families"** | Undefined ordering | §30.3.2: candidate set defined, sorted by §24 index, drawn without replacement, attempt limit `12` |
| **Package exhaustion** | *"families 1–18 always provide a substitute"* — purpose compatibility does not prove a free offer exists | §30.3's `CERTIFIED_FALLBACK[purpose]`: a checked-in `(family, shell_id)` pair per purpose, using only `review: pass` authored shells, re-proved by §37.2's fallback Zone |

### 2.8 Stale internal references

Five corrected: `§5.9`→`§5.5` (latching), `step 6`→`step 9` (latch allocation), `check 25`→`check 29` (Status→latch guard), `§30.7`→`§23.5 check 20` (replay), `step 9`→`step 11` (package/shell matching). §11.9 and §12.7 previously pointed composition counts at §37.4, the adversarial Zone fixture set; both now carry the enumerations directly.

### 2.9 Implementation waves

Rebuilt as **35 waves** with a new §40.0 that keeps two sequences strictly separate: **Playable 0.3** (owned by `docs/ROAD_TO_PLAYABLE_0_3.md`, not this document) and the Amalgam waves. Wave 13's step-10 skip is gone. **Wave 9 is the `shell_id` contract and is the only wave on the live critical path** — §41.5.1 shows it depends on none of the engine blockers.

---

## 3. Fixtures

Eight union fixtures became **fifteen**. New: **U9** reserved-capacity saturation, **U10** stranded required object, **U11** replay macro-invariance, **U12** render-rate independence, **U13** authored shell in a played Zone, **U14** the four-row shell refusal matrix, **U15** manifest reconstruction with Epsilon unavailable. U2 (`conductive` `8.0 s`→`10.0 s`, trait added), U6 (entries 48→61 sequence made complete), U7 (`eff_manipulate`→`effect_physics_master`), and U8 (two budgets, not one `40`-target budget) corrected.

---

## 4. Mechanical results

| Check | Before | After |
|---|---:|---:|
| Broken cross-document section references | `0` | **`0`** |
| Broken source test-vector references | `0` | **`0`** |
| Broken internal `§` references | `5` | **`0`** |
| Total source-vector citations | `145` | **`145`** |
| Pipes breaking GFM table cells | `0` | **`0`** |
| Forbidden constructions (Standard §2.1–2.5) | `0` | **`0`** |
| Test vectors, contiguous | `88` | **`98`** |
| Structural checks | `17` | **`21`** |
| Package validation checks | `29` | **`30`** |
| Model-check properties | `8` | **`8`** |
| Union fixtures / adversarial fixtures | `8` / `11` | **`15` / `11`** |
| Word count | `27,292` | **`35,090`** |

**Note on "broken references before repair":** zero, against the live repository. The external audit's counts of 2 broken sections and 54 broken vectors are artifacts of the stale packet (§1).

---

## 5. Regenerated counts

| Quantity | Value | Method |
|---|---:|---|
| Atom catalog | `121` | `38+2` Weapon, `32+8` Ability, `19+9` Gear, `13` Mod |
| `effect` / `payload` / `domain` dimensions | `17` / `11` / `25` | Enumerated |
| Legal Weapons, `USEFUL` / `HIGH` | `579,590` / `178,747,155` | Exhaustive enumeration |
| **Legal Weapons, total** | **`179,326,745`** | vs Design 4's `175,155,080` (`1.024×`) |
| Legal Abilities, `USEFUL` / `HIGH` | `558,514` / `16,028,010` | Exhaustive enumeration |
| **Legal Abilities, total** | **`16,586,524`** | vs Design 4's `5,941,874` (`2.79×`) |
| In-band `HIGH` Ability bases | `138` | physics `9`, Status `41`, signal `31`, mass field `9`, `transform*` `47`, heal `1` |
| Packages per Zone | `11` / `13` / `16` | `PACKAGE_DENSITY` × `PURPOSE_ROTATION`, `8`/`10`/`12` rooms |
| Duplicate-placement reduction | `42%` vs D1, `58%` vs D4 | 60,000-trial simulation at `k=13`, `F ∈ {12,18,34}` |
| Model-check configurations | `≤ 49,152` | `4096 × 12` |
| Search edge traversals | `≤ 5.9M` | `49,152 × 60 × 2` |
| Replay wall clock | `7.2 s` | `36 × 8.0 ÷ 40`, serial |
| Composition budget | `50.0 s` worst, `10.0 s` first-pass | `5 × (7.2 + 2.0 + 0.8)` |

---

## 6. Twelve-area Zero-Guesswork checklist

| # | Area | Verdict | Evidence |
|---:|---|---|---|
| 1 | Player-visible behaviour has one outcome | **PASS** | §6–§15; §33.10's tiers; §34.15's refusal table |
| 2 | Saved state has one reconstruction rule | **PASS** | §5.6; §21.11.1 for queued macro changes; §30.11.7's manifest |
| 3 | Procedural validity is decidable | **PASS** | §30.5's 21 checks; §30.6's 8 properties; §23.5's 30 checks |
| 4 | Every failure terminates in one known outcome | **PASS** | §30.8; §30.11.5's six rows; `CERTIFIED_FALLBACK`; §37.2 |
| 5 | Schemas are machine-readable | **PASS** | §4; §23.1's manifest; §30.11.1 and §30.11.7 |
| 6 | Numbers are stated, not implied | **PASS** | §35.0–§35.5; every count in §5 regenerated |
| 7 | Determinism is provable | **PASS** | §30.3.1's RNG primitives; §30.3.2's ordering; §30.11.7's manifest; §30.11.8's committed verdicts |
| 8 | Cross-system interactions are resolved | **PASS** | §31.1's 11 union rows; §36.1's 66-pair map |
| 9 | Pins name real sections | **PASS** | §4's mechanical result: `0` broken |
| 10 | Test vectors are outcomes, not methods | **PASS** | 98 vectors; forbidden-construction sweep clean |
| 11 | Traceability is complete | **PASS** | 142/142; 133 applicable; 0 uncovered |
| 12 | The document survives its own vectors | **PASS** | Vector 3's ledger claim now true; vector 66's map now consistent |

**Zero-Guesswork verdict: PASS.**

---

## 7. Verdict and what remains open

**Design verdict: PASS.** **Zero-Guesswork verdict: PASS.**

The architecture was never the problem and is unchanged: latches as the boundary between continuous physics and discrete progression proof; Design 3's verifier at the centre; Status excluded from the search but able to gate through a latch; compositional items over an authored alphabet. Every repair above is integration, arithmetic, ordering, or honesty.

**Two genuine owner-level forks remain, and neither is this document's to close:**

1. **Environmental-agency signal persistence** — transient per visit, or persistent through validated transitions and the interpretation-log fold. The continuity archive marks it an explicit unresolved owner gate. §19 and §5.2 are written to accept either; the choice changes which persistence category signal state takes, and it should be made before agency implementation begins.

2. **Capability gating versus Archipelago logic** — carried forward from `07_ENGINE_RECONCILIATION.md` §5 and unchanged by this repair. The apworld declares no capability prerequisites and defaults to `Accessibility: full`; §30.6 proves a property Archipelago never consumes. The 2026-09-04 ruling that *"making an offer load-bearing requires a separate owner ruling and matching AP logic"* is the same fork seen from the roadmap side. **This must be decided before any capability-gated mandatory route ships**, and no amount of verifier work substitutes for it.

**One decision this repair made that an owner may wish to revisit:** §21.11.1's conflict policy is **latest-wins** for a queued macro change. First-wins is defensible and would let a stale intention lock a variable; the choice is recorded in §41.3.
