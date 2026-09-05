# DESIGN 06 — REPAIR AND REBASE AUDIT

**Scope:** repair and rebase of `06_THE_AMALGAM.md`. Not a redesign; the architecture is owner-selected and preserved.
**Rebased onto:** `ARCHIPEPSI_CONTINUITY_2026-09-04` (owner rulings + runtime findings), and the exact current copies of `00`–`05`.
**Verdict:** **Design PASS. Zero-Guesswork PASS — PROMOTABLE.** See §10. Four repair passes; §9 records the audited revision.

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

## 7. Second repair pass — the live-branch diff review

A live-branch review of `9e56d51` found **fourteen further defects**, all real. Every one is repaired below. The first pass's PASS was **false**, and item 14 is why.

### 7.1 The falsifying defect

**§41.6 said `28` seconds and thirty-four waves while the body said `50.0 s` and 35 waves.** The first pass regenerated §41.5 and did not regenerate §41.6's claim paragraph. A document whose closure statement contradicts its own body cannot be Zero-Guesswork, and no other finding was needed to invalidate the verdict.

**Repair:** §41.6 regenerated last, from the repaired body, with an eleven-row table binding every duplicated figure to its authoritative section. A new mechanical duplicate-number checker now runs before any PASS is claimed; it is what would have caught this.

### 7.2 Soundness

| # | Defect | Repair |
|---:|---|---|
| 1 | **`manipulate` was physically unsound.** Verb-set membership was declared sufficient, concluding no composed Ability "can be too weak". Two `PUSH` providers with different force/range/mass both satisfy the Boolean while only one moves the crate | §29.3.1 splits **capability identity** (Boolean, unchanged, what the verifier sees) from **provider qualification** (the `700 N` / `20.0 m` / `120 kg` envelope, read only by §29.4's entry check). §23.5 check 30 replays every mandatory package at exactly the envelope, so a passing package is solvable by *every* qualifying provider. Sub-envelope hosts stay real content for optional routes |
| 2 | **Mandatory Status latches could fail forever.** Reservation stops budget refusal; it does nothing about the roll. `FLAME_JET` is `0.50`, `ELECTRIC_FIELD` `0.45`, `COOLANT_VENT` `0.60`, `PHASE_EMITTER` `0.55` | §35.2.2's guaranteed puzzle-source path: a `status_source` **declared by a mandatory package** applies its declared Status to its declared target without a roll, after legality and trait checks. Scoped to that triple only — the same hazard stays probabilistic everywhere else. Structural check 22 enforces the declaration; fixture U16 tests both halves in one room |
| 7 | **Property 4 asked questions `(v, r)` cannot answer** — whether an object is consumed or carried | Per-object proof augmentation `(v, room, object_state)` over a closed four-value enum. Validation state only: never in the vector, never saved. Cost `4×` per object, ≤ 8 objects, under `1.6M` configurations |

### 7.3 Composition order and graph safety

| # | Defect | Repair |
|---:|---|---|
| 3 | **`offered_shells` required "every offer the room's already-selected packages require" at step 5, when packages are selected at step 11.** Unsatisfiable as written | §30.11.2a: rule 4 now depends only on the room's **purpose**, via a minimum offer vocabulary table. And the honest consequence is stated rather than hidden — the previous claim that legal shell answers are "all equivalent to the composer" is **withdrawn**: shell choice genuinely narrows later package availability |
| 4 | **Connector compatibility assumed two neighbours** on a graph with degree up to 4 | §30.11.2b: incident-edge signature computed at step 3; a shell is offered only if an **injective assignment** from every incident edge to a compatible socket exists (kind, direction, transform, clearance). Assignment is deterministic (lexicographically smallest), committed, and re-proved by check 19b. Fixture U18 |
| 10 | **Two shipped purposes could never generate.** The rotation was truncated to twelve entries; `vertical_ascent` and `boss_arena` are entries 13 and 14 | §30.3.0: full fourteen-entry rotation read cyclically from a seeded offset, with three deterministic corrections. Coverage computed over all `5 × 14` pairs — every purpose generatable, `boss_arena` in `49/70` and always the exit room. Fixture U19 |
| 11 | **Fallback could swap a room's shell after binding**, invalidating connector assignments, neighbour geometry, bound offers, and Epsilon's committed choice | Policy: **the shell is chosen once at step 5 and never changes.** `CERTIFIED_FALLBACK` is indexed by purpose **and connector degree**, and its shell must be in `offered_shells` at step 5 or the attempt fails immediately — before Epsilon is asked |
| 8 | **"Nearest preceding checkpoint" is undefined on a cyclic graph**, and placement ran at step 15 while `R` appears at step 17 | §30.7.1 defines coverage as multi-source BFS distance from the checkpoint set: `∀ x ∈ R, d(x) ≤ 2`. §30.7.3 puts the real two-pass process into §30.3 as steps 15–20, monotone and bounded at 3 additions |

### 7.4 Determinism and persistence

| # | Defect | Repair |
|---:|---|---|
| 5 | **Fresh-generation determinism and committed reconstruction were conflated.** §30.3 claimed byte-identical composition from the seed while §30.11 said re-asking may return a different legal shell | §30.5.1 defines **P1 structural reproducibility** (everything bridge-owned, from declared inputs) and **P2 committed reconstruction** (from the manifest, forever, with Epsilon unreachable). Byte-identical fresh generation is **explicitly not claimed**. Zone identity includes `epsilon_provenance.response_digest` |
| 6 | **§5.6 step 3 still said "recompose deterministically; assert byte-identical"** — contradicting §30.11 | §5.6.1: load the manifest, verify version and digests, instantiate exactly what is recorded, read committed replay verdicts, never contact Epsilon. §5.6.2 adds `schema_version` with a four-row migration table including Zone **retirement** rather than a stranded campaign. §5.6.3 closes the `ReplayVerdict` and `EpsilonProvenance` schemas, which were prose |
| 12 | **Theme, display name, and designer note were cited as "pinned: Design 1 §30.1"**, which says the opposite — *"Nothing in Zone composition"* | Declared an **Amalgam extension** with a bounded `ZonePresentation` schema and structural check 19a. No system reads the strings |

### 7.5 Arithmetic, again

| # | Defect | Repair |
|---:|---|---|
| 9 | **The replay budget used `settle_timeout` (`8.0 s`), which bounds check 22's settle test, not check 20's replay.** The replay bound is `ReferenceSolution.max_duration`, unbounded in Design 2's schema | §35.4.1 bounds it: `MAX_REPLAY_DURATION = 12.0 s`, enforced by new package check 23. Replay recomputed: `36 × 12.0 / 40 = ` **`10.8 s`** |
| 13 | **Total wall clock omitted Epsilon's shell request entirely** | §35.4.2: **one batched Zone-level request**, `10.0 s` timeout, `1` repair attempt, offline selector on second failure, **not re-asked on Zone retry**. Worst case `20.0 s`. §35.4.3: total = `20.0 + 5 × 13.6` = **`88.0 s`**, first-pass **`13.6 s`** |

Package density was also re-derived over the corrected purpose distribution: range **`8`–`16`**, mean **`12.11`**. The `42%` / `58%` variety reductions are unchanged, which confirms they were not an artifact of the truncated rotation.

### 7.6 Second-pass mechanical results

| Check | Pass 1 result | Pass 2 result |
|---|---:|---:|
| Broken cross-document section references | `0` | **`0`** |
| Broken source test-vector references | `0` | **`0`** |
| Broken internal `§` references | `0` | **`0`** |
| Broken `check N` references | not checked | **`0`** |
| **Stale duplicated figures** | **not checked — this is what failed** | **`0`** |
| Structural checks | `21` | **`24`** (13 pinned + 11 union, including 19a and 19b) |
| Package validation checks | `30` | **`31`** (18 pinned + 12 added + 22a) |
| Test vectors | `98` | **`102`** |
| Union fixtures | `15` | **`19`** |

## 8. Third pass — the closure review

A closure review of `70bc8a4` found **fifteen further items**. All were real. The second pass's PASS was **premature**: it declared PASS and then listed two unresolved owner-level behavioural forks, which is a contradiction on its face.

### 8.1 Contradictions the repairs themselves created

The second pass added correct new sections without deleting the prose they superseded. Four cases:

| Was | Now |
|---|---|
| §29.3 still argued the numeric floor was withdrawn and magnitudes cannot participate — immediately before §29.3.1 explains why that was unsound | Stale prose deleted. §0.5's ledger and §41.1 corrected: the envelope governs **provider qualification**, never composition legality |
| §0.4 called Defense-to-zero "a rule change" as a distinction from damage modification; §41.1 answered "may one modify damage? None" | Both restated to §15.3's honest three-rule form with `exposed` as the one declared exception |
| §36.1 claimed fifteen orthogonal pairs in a fifteen-row table containing two INTERACTS rows, and named a system "Zone composition" that is not in the twelve-system inventory | All 66 pairs **generated mechanically**, each classified exactly once. Totals derived from the table: `51` / `15` |
| Two package checks both numbered `23` | The union's duration check renumbered `31`; every citation updated |

### 8.2 Fields that did not exist in any schema

Five repaired rules referenced fields their schemas could not represent. **A validator may not test a field the schema cannot express.**

| Field | Resolution |
|---|---|
| `qualifies_manipulate` on `HostDefinition` | **Derived, never serialized.** Computed from the resolved committed Loadout at §29.4's entry check. Caching would let it go stale when Gear changes |
| `HostDefinition.profile` vs `composition` | §4.2 now names Mobility as the explicit exception rather than saying composition replaces `profile` "everywhere" and being contradicted in §12.8. Structural check 19c |
| `StatusSolution` on `PackageManifest` | Added with five fields. `guaranteed_application` is **derived** from the triple, not stored |
| `RoomRecord.connector_assignment` | Added, typed `dict[EdgeId, SocketId]`, total over incident edges |
| `ZoneManifest.schema_version` | Added. `ReplayVerdict` and `EpsilonProvenance` now referenced **by name** rather than one being inlined as an anonymous shape beside its named definition |

`ChamberType`'s `# arena \| tower \| corridor \| treasure_room \| ...` is now the closed four-value enum. An ellipsis in a generated-record schema is a guess an implementer has to make.

### 8.3 Semantics

| # | Defect | Repair |
|---:|---|---|
| 3 | `EpsilonProvenance` fixed `request_count = 1` while permitting a repair attempt — but **a repair is another request** | `request_count = 1 + repair_attempts`, plus a six-row table defining `model_id`, `response_digest`, `selected_offline`, `elapsed_ms` and a new `outcome` enum in **every** failure case, including the retry case where no request is issued at all |
| 5 | Property 4's `PLACED` was not room-indexed, justified by a recovery contract Design 2 §10.5 does not state. **And the augmented Move ignored carry legality** — the proof could route a required object across a grapple gap the player cannot cross while holding it | `PLACED(room_id)` bounded to `allowed_volume`; every augmented transition tabulated; a **carry-legal Move rule** requiring the edge be traversable while carrying, with a derived `carry_legal` per edge. Cost recomputed from the real state count: `2 + \|allowed_volume\|` states, worst case `14`, `5,505,024` configurations across `8` objects — not a universal `4×` |
| 6 | `CERTIFIED_FALLBACK` was keyed on **degree**, not signature — two degree-`2` rooms can need different socket kinds. And step 5 proved the *certified* shell was offered, then step 11 claimed the *selected* shell could host the fallback, which does not follow | Keyed on the normalized `ConnectorSignature`. And **every shell in `offered_shells` must be proven able to host the fallback family** — so the guarantee holds for whatever Epsilon selects, because it held for every candidate before the question was asked |
| 8 | Wave 14 said "steps 1–10, 13–18", omitting **step 11, package placement**, against a twenty-step algorithm | Rebuilt as steps 1–14 and 16–20, with the wave-17 boundary claim justified explicitly |
| 9 | §11.8 claimed Design 1 has 14 Weapon profiles | Regenerated from live D1: **`18` primary, `6` secondary, `8` feed, `14` Ability, `9` Mobility**. The unit being counted is now named |
| 10 | Vector 65 said an attempt "completes within `13.6 s`" including Epsilon selection — false whenever latency is nonzero | Three separate values: first-attempt **compute** `13.6 s`; first-attempt **total** `13.6 s` + actual latency; **bounded** first attempt `33.6 s`; worst-case Zone `88.0 s` |

### 8.4 An owner decision that had been made silently

**The four `HIGH` master atoms are new game content**, introduced during an audit to close a real defect — with Design 4's catalog alone, no high-tier physics, Status, signal, or mass-field Ability is composable, and §29.1 makes `manipulate` a gate granted by a physics Ability. **The defect is real; adding four atoms is the owner's call.** §11.7.2 now carries an ⚠ OWNER DECISION REQUIRED block with both outcomes enumerated:

| Retain | Remove |
|---|---|
| Catalog `121`, Abilities `16,586,524`, `HIGH` in-band bases `138` | Catalog `117`, Abilities `6,133,474`, `HIGH` in-band bases `48` |

Both figures are enumerated, not estimated. The removal figures were themselves asserted before being computed in a draft of this pass and corrected — `6,133,474` and `48`, not `5,997,594` and `49`.

### 8.5 The verdict

A PASS that is immediately followed by a list of unresolved behavioural decisions is not a PASS. §41.6 now states:

> **Design verdict: PASS. Zero-Guesswork verdict: CONDITIONAL — NOT YET PROMOTABLE.**

with three open decisions tabulated by what each changes — saved state, procedural validity, content — and a drafted resolution for the Archipelago fork presented **for approval and not enacted**.

### 8.6 A semantic contradiction checker

Reference lint passed while every one of §8.1's contradictions was live, because each reference resolved. A twelve-check semantic pass now runs alongside it, testing for **claims that contradict each other** rather than references that fail to resolve — floor-withdrawn versus floor-required, orthogonal-versus-INTERACTS, schema-uses-field versus schema-lacks-field, PASS-versus-open-forks. It also excludes narrated historical corrections, so a document that says "a previous revision said X, which was wrong" does not trip on X.

### 8.7 Third-pass mechanical results

| Check | Pass 2 | Pass 3 |
|---|---:|---:|
| Broken cross-document section references | `0` | **`0`** |
| Broken source test-vector references | `0` | **`0`** |
| Broken internal `§` references | `0` | **`0`** |
| Broken `check N` references | `0` | **`0`** |
| Stale duplicated figures | `0` | **`0`** |
| **Semantic contradictions** | **not checked — 12 were live** | **`0`** |
| **Duplicate check ids** | **1 (`23` twice)** | **`0`** |
| Structural checks | `24` | **`25`** |
| Package validation checks | `31` | **`32`** unique ids (18 pinned + 14 added, `22a` now indexed in the table) |
| System-map rows | `15` of 66 | **`66` of 66** |

## 9. Audited live revision

| | |
|---|---|
| **Pull request** | `cadykaya/archipepsi` **#9** |
| **Branch** | `claude/chatgpt-share-link-review-77kk2l` |
| **Audited commit SHA** | **`e7e6c7d5e8762eb4d2a7f9b8243966483087219f`** (pass 4, re-audited after the connector reconciliation) |
| **Date** | 2026-09-05 |
| **Prior audited revisions** | `487a644` (pass 3), `950a561` (pass 4 before the connector reconciliation) |
| **Prior head reviewed** | `4004f0184aa97ae4a3cec34a3e3f792dcbebb416` |

**On the recorded SHA.** `e7e6c7d` is the commit whose *content* every checker below was run against. It supersedes `950a561`: a later commit changed §4.9a's connector vocabulary, so the earlier SHA no longer covered the document and re-recording it without re-auditing would have been exactly the stale-reference failure this audit exists to prevent, from a clean worktree checked out at that revision — not from an export and not from the editing tree. The commit that adds this line necessarily comes after it, so the branch head is one commit ahead; that following commit touches this table and nothing else. Recording the audited content's SHA rather than the head's is the only way for the two to be the same thing.

**Checkers run against that SHA**, all from the repository worktree at that revision and not from any export:

| Checker | Result |
|---|---|
| `refcheck` — cross-document, source-vector, internal references | `0` / `0` / `0` broken, `145` source-vector citations |
| `pipecheck` — GFM table integrity across all nine files | `0` broken cells |
| `dupcheck` — duplicated figures against their authorities | `0` stale |
| `closurecheck` — every §41.6 figure against its authoritative section | `0` mismatched, `16` figures |
| `semcheck` — semantic contradictions | **`0` of `23` checks** |
| Check-id uniqueness — structural and package | `0` duplicates; `28` structural, `32` package |
| System-map derivation | `66` rows, `51` / `15`, totals derived |
| Broken `check N` references | `0` |
| **Open owner decisions** | **`0`** |
| **Targeted promotion assertions** | **`15` of `15` pass** |

The fifteen targeted assertions test the specific pairs this pass repaired: Law 47's narrowing agreeing with §30.5.1; exactly one live `CERTIFIED_FALLBACK` schema; Property 4's arithmetic recomputed rather than copied; `carry_legal` derived from a declared field; `connector_kind` and `B_TO_A` present on the edge schema; the model-check hard budget; one Epsilon repair policy; `INVALID_SELECTION` representable; six failure classes; the three first-attempt figures distinct; agency persistence and the AP contract decided; no reference to the nonexistent §30.9a; and the catalog and Ability counts on the retained branch.

**Two `dupcheck` lines are known false positives**, verified by inspection in passes 3 and 4: the four `10.0 s` occurrences are Epsilon request timeouts rather than a composition figure, and the single `1.8 s` is the narrated history of the replay-budget error in §35.4.1's opening.

## 9a. Fourth pass — promotion closure

The owner ruled on all four open decisions, and a closure review of `4004f018` found ten further defects. **Pass 3's checker reported zero semantic contradictions while every one of these was live**, which is the finding that matters most here: a checker that misses a class is not evidence the class is absent.

### 9a.1 The owner rulings, applied

| # | Ruling | Where |
|---:|---|---|
| **O1** | Environmental agency is **persistent**, split: accepted consequences become `AgencyRecord`s in the fold and survive unload, save, death, reconstruction; raw signal values, timers, momentary inputs and verb durations stay transient and are recomputed at §5.6 step 6a | New §5.4a, §5.6 steps 6/6a |
| **O2** | The **conservative AP rule** is the contract, with structural check 23. Optional content — shortcuts, secrets, flanks, optional rewards and traversal — stays gate-able | New §29.5a |
| **O3** | The four `HIGH` master atoms are **retained**. OWNER DECISION REQUIRED language removed | §11.7.2, §41.3 |
| **O4** | Queued macro conflict is **latest-wins**, approved | §21.11.1, §41.3 |

### 9a.2 Law 47 — the largest remaining contradiction

§1 claimed all 48 inherited laws held unchanged. **Law 47 requires composition deterministic from a seed**, and §30.5.1 correctly says fresh generation is not seed-deterministic while Epsilon chooses shells. Both could not be true, and the document had been asserting both since pass 1.

New §1.4 narrows the law into three properties rather than hiding the conflict: **47a** bridge structural determinism (everything before the model is consulted, byte-identical); **47b** the model choice, explicitly *not* claimed seed-determined, folded into Zone identity via `response_digest`; **47c** committed determinism from the manifest, forever, on any machine. Law 47's second sentence — decorative randomness never alters solvability — is untouched. §30.3's opening, D73's traceability row, §41.4's "nowhere" claim, and the pin ledger all updated. **This is a supersession by a newer owner ruling, and §41.4 now says so instead of claiming no disagreement exists.**

### 9a.3 The other eight

| # | Defect | Repair |
|---:|---|---|
| 2 | Two live `CERTIFIED_FALLBACK` schemas — the superseded `[purpose] -> (family, shell_id)` form and its six-row table were still stated in the present tense | Deleted. One live schema: `[purpose][ConnectorSignature] -> family` |
| 3 | `ConnectorSignature` read a `socket_kind` and a `B_TO_A` direction the pinned `TopologyEdge` does not have, and `carry_legal` was called "committed" while no schema declared it | New §4.9a extends `TopologyEdge` with `connector_kind` (closed four-value), `crossing` (closed **ten**-value), and `B_TO_A`. `carry_legal` is **derived** from `crossing` by a stated rule and re-checked at load by check 24 |
| 4 | Property 4's state count omitted `CARRIED`: `2 + \|allowed_volume\|` instead of `3 +` | `15` states worst case, `737,280` per object, **`5,898,240`** across `8`. Typical: `6` states, `294,912` per object, `2,359,296` across all — figures a previous revision conflated |
| 5 | "Tens of milliseconds" was an invented benchmark for a six-million-configuration search | New §30.6.3: the model-check phase has a **hard `2.0 s` budget**; exceeding it is `MODEL_CHECK_TIMEOUT` and `FAIL_ZONE`. Algorithmic bounds and wall-clock behaviour are now separate claims |
| 6 | Three sections disagreed on Epsilon failure handling; the provenance enum could not represent a twice-invalid selection; the table was called six-row and had seven | One policy: any unusable first result gets **exactly one** repair. `INVALID_SELECTION` added with a precedence rule for mixed failures. **Six** failure classes, missing and invalid selection merged |
| 7 | §0.5's completeness statement preceded a table row; §11.8 said every profile is composed while Mobility is not; §35.4.3 called `13.6 s` the actual first-attempt cost; §41 claimed the standard was met while conditional; `ReplayVerdict` cited a nonexistent §30.9a | All five corrected |
| 8 | Local connector filtering was called sufficient without establishing that the **combination** of independently chosen shells is spatially valid | New §30.11.2d: standardized attachment collars make joinability a property of the socket pair, so local filtering is sufficient **by construction**, enforced on the catalog by check 19d. The CSP alternative is stated for the day a bespoke collar is needed |
| 10 | `semcheck` reported clean while all of the above were live | **Ten classes added**, one per defect above, plus the meets-standard-versus-verdict pair rewritten to compare the two claims rather than pattern-match one |

### 9a.4 Fourth-pass mechanical results

| Check | Pass 3 | Pass 4 |
|---|---:|---:|
| Broken cross-document / vector / internal / check references | `0` | **`0`** |
| Stale duplicated figures | `0` | **`0`** |
| GFM table integrity | `0` | **`0`** |
| **Semantic contradictions** | **`0` reported, `10` live** | **`0` of `22` checks** |
| Duplicate check ids | `0` | **`0`** |
| Structural checks | `25` | **`28`** |
| Package validation checks | `32` | **`32`** |
| System-map rows | `66` | **`66`** |
| **Open owner decisions** | **`3`** | **`0`** |

## 10. Verdict and what remains open



**Design verdict: PASS.** **Zero-Guesswork verdict: PASS — PROMOTABLE**, against the commit recorded in §9 and not against any earlier revision.

Three earlier verdicts are superseded. Pass 1's PASS was false — §41.6 contradicted the body. Pass 2's was premature — it declared PASS and then listed open owner forks. Pass 3's CONDITIONAL was correct at the time and is now discharged: the owner ruled on all four decisions on 2026-09-05, and §41.3 records them.

**Zero owner decisions remain open.** `07_ENGINE_RECONCILIATION.md` still reports that production code cannot yet implement several parts of this design; those are implementation blockers against a decided design.

The architecture was never the problem and is unchanged: latches as the boundary between continuous physics and discrete progression proof; Design 3's verifier at the centre; Status excluded from the search but able to gate through a latch; compositional items over an authored alphabet. Every repair above is integration, arithmetic, ordering, or honesty.

**Two genuine owner-level forks remain, and neither is this document's to close:**

1. **Environmental-agency signal persistence** — transient per visit, or persistent through validated transitions and the interpretation-log fold. The continuity archive marks it an explicit unresolved owner gate. §19 and §5.2 are written to accept either; the choice changes which persistence category signal state takes, and it should be made before agency implementation begins.

2. **Capability gating versus Archipelago logic** — carried forward from `07_ENGINE_RECONCILIATION.md` §5 and unchanged by this repair. The apworld declares no capability prerequisites and defaults to `Accessibility: full`; §30.6 proves a property Archipelago never consumes. The 2026-09-04 ruling that *"making an offer load-bearing requires a separate owner ruling and matching AP logic"* is the same fork seen from the roadmap side. **This must be decided before any capability-gated mandatory route ships**, and no amount of verifier work substitutes for it.

**One decision this repair made that an owner may wish to revisit:** §21.11.1's conflict policy is **latest-wins** for a queued macro change. First-wins is defensible and would let a stale intention lock a variable; the choice is recorded in §41.3.
