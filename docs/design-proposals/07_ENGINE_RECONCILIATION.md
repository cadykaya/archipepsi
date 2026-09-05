# ENGINE RECONCILIATION — the six proposals against the code that exists

**Status:** Findings. Not a proposal and not canon.
**Checked against:** `claude/archipepsi-echoes-continuation-b1adno` at `df2bb58`, the live development branch — 617 files, 93 GDScript, 136 Python.
**Checked on:** 2026-09-04.

## Why this document exists

Designs 1 through 6 were written against `docs/authorities/PLAYER_DESIGN_AUTHORITY_v1.0.md` and `docs/authorities/DUNGEON_ENVIRONMENT_AUTHORITY_v0.1.md`, audited against the Zero-Guesswork Standard, and traced against 142 authority acceptance tests. **None of them was ever checked against the engine.**

They were also written on a branch that contains no code. The engine lives on a different branch, and the six proposals and the running game have never been in the same working tree until now.

This document is that check. It is deliberately one-directional: it reports what the engine says, what the proposals say, and where they disagree. It does not decide who is right — several disagreements are the proposals correctly describing a target the engine has not reached, which is what a design proposal is for.

**The headline: every proposal overstates its "reuse of current repo foundations", and Design 6 overstates it most.** Design 6's profile claims `3 / 5`. The honest figure is `1 / 5`.

---

## 1. What the engine already has, and what the proposals got right

Real convergence, worth stating before the disagreements.

| Engine | Proposal |
|---|---|
| `docs/design-packet-v0.8/AUTHORED_CONTENT.md` (normative): *"developers author the alphabet, Godot enforces the grammar, Epsilon writes sentences"* | Player Authority §26.2 verbatim; Design 6 §3.3 and §11.7 build on it |
| `CapabilityGuarantee` with four proof cases — `permanent_baseline`, `already_possessed`, `established_in_zone`, `forge_constructible` (`mechanics.py:394`) | Law 34 `NO REQUIREMENT BEFORE GUARANTEE`; Design 6 §30.6 property 5 |
| Case C `established_in_zone`: *"Nothing produces that set yet, and it is deliberately a parameter rather than a lookup so that when a capability-establishment construct exists it plugs in here"* | **This is the socket Design 6 §30.6 was designed to fill.** The engine left the hole on purpose |
| Case D `forge_constructible`: *"not implemented… the day the Forge lands the shape of the answer does not have to change"* | Design 6 §18 ships Forge. Same shape |
| `abandon_zone` returns unclaimed locations to the pool (`transitions.py:175`) | Mitigates the stranding risk `SOLUTIONS_CATALOGUE.md` §0 raises. Already handled; no proposal needs to solve it |
| Godot 4.5.1 stable, stock, *"do not fork"* (`project.godot:2`) | Design 6's stated target |
| Epsilon composes, never generates assets | Design 4 and Design 6 §30.1: Epsilon touches no Zone composition |

The architectural spine agrees. What follows is everything else.

---

## 2. BLOCKING — the engine refuses Design 6's fifth capability, by name

`bridge/archipepsi_bridge/schemas/mechanics.py:271` defines the complete semantic capability vocabulary:

```python
ACTIVITY_CAPABILITIES = {
    "ranged_hit":     {...},   # satisfied by the permanent baseline
    "cross_long_gap": {...},
    "grapple":        {...},
    "blink":          {...},
}
```

Four. And the comment immediately above (`mechanics.py:269`) anticipates exactly the proposal that was written:

> *"The physics and construction capabilities an owner brief might name — **MOVE_OBJECT_\*, TETHER_OBJECT, APPLY_UPWARD_FORCE, PLACE_CONSTRUCT — are not here because nothing can satisfy them yet: they wait on the v9 physics tool, and a capability nothing can satisfy is a gate nothing opens.**"*

Design 6 §29.1 adds `capability:core:manipulate`, satisfied by a `PUSH`, `PULL`, or `HOLD` Ability. That is `MOVE_OBJECT_*` under another name.

**This is not a gap the proposal can close by being more specific.** The engine's position is a reasoned refusal with a stated unblocking condition — the v9 physics tool — and §3 below shows that tool does not exist in any form.

Design 6 §0.3 calls fork 6 *"the one fork that required new machinery… and it is why the verifier is load-bearing for the whole union."* The reconciliation is that **fork 6 is resolved against a substrate the engine has deliberately withheld**, and no amount of verifier work changes that.

---

## 3. BLOCKING — there is no rigid-body physics

| Query | Result |
|---|---|
| `RigidBody3D` across the whole Godot project | **0 occurrences** |
| `Joint3D`, `Generic6DOF`, `PhysicalBone` | **0 occurrences** |
| Body classes actually used | `StaticBody3D` ×80, `Area3D` ×22, `CharacterBody3D` ×9, `AnimatableBody3D` ×3 |
| Physics settings in `project.godot` | `common/physics_ticks_per_second=60`, and nothing else |
| Solver iteration count, Jolt configuration | Not configured; stock defaults |
| Object-manipulation verbs in the 28-primitive catalog (`echo.py:350`) | **None.** `pull_pickup` exists and is scoped to local rewards only |

Design 6 ships, against that:

- `40` rigid bodies per room, `90` across loaded rooms, `24` non-sleeping (§35.1)
- Eight constraint kinds *"genuinely simulated"* (§26)
- `WINCH`, `BRAKE`, `DRIVER` as solver-driven actuators (§21)
- A headless three-run physics replay in the composer (§23.5 check 20)
- `4.0 ms` of a `16.67 ms` frame budgeted to a physics solver (§35.0)

**None of that substrate exists.** The engine is a kinematic game: static geometry, areas, and character bodies.

This also retires a risk Design 6 §41.2 called its largest: *"Godot 4.5's solver determinism across platforms is an assumption rather than a proof."* That risk cannot be evaluated, because there is no solver in the project to be deterministic. The real risk is one order more basic — the entire physical layer is unbuilt, and Design 6's §40 waves 15 through 24 are ten waves of building it before any of Design 2's content appears.

---

## 4. BLOCKING — §29.3's numeric floor is exactly what the engine forbids

This one is mine, added yesterday, and it is wrong in a way the engine had already ruled out.

`schemas/zone.py:132`, on `ActivityPrimitive.requires`:

> *"What may NOT go here, and cannot, because the vocabulary has no word for it: raw damage, DPS, a health threshold, a crit figure. **Numeric combat power is BALANCE. It is never LOGIC**, so a Zone can never mean 'enter only if your build does 400 DPS'."*

Design 6 §29.3 mandates:

> *"Every composition that grants `capability:core:manipulate` delivers at least `700 N`, `20.0 m` of range, and a `120 kg` verb mass limit."*

Newtons are not DPS, but the principle is identical and the engine's model has no place to put either. A capability there is **set membership over action primitives** — *"owns an action whose primitive is in the grapple family"* — with no magnitude axis at all, deliberately, so that an Echo the player built themselves satisfies a requirement identically to the canonical one.

**The defect §29.3 fixes is real** — a composed manipulation Ability can be weaker than the profile a puzzle was authored against. **The fix is the wrong shape.** Under the engine's model the problem dissolves rather than needing a floor: if capability satisfaction is set membership, there is no weak-versus-strong axis for a puzzle to be authored across. It is Design 2's `700 N / 20.0 m / 120 kg` contract itself — pinned unchanged into Design 6 §29.2 — that the engine's model rejects.

A further bound Design 6 has no equivalent of: `requires` is `max_length=2` (`zone.py:137`). At most two capabilities per activity.

---

## 5. HIGH — the model check has no relationship to Archipelago's logic

`apworld/archipepsi/__init__.py:109` is the **complete** access-rule set for the game:

```python
menu.connect(tiers[0])
tiers[0].connect(tiers[1], rule=lambda state: state.has(SIGNAL_KEY, player, 1))
tiers[1].connect(tiers[2], rule=lambda state: state.has(SIGNAL_KEY, player, 2))
```

Three regions, gated on Signal Key counts. **No capability prerequisite is declared anywhere.** Archipelago's model of this game is that every Check in a tier is reachable once you hold that tier's keys.

`SOLUTIONS_CATALOGUE.md` §0 states the consequence:

> *"Archipelago's `Accessibility` defaults to `full`… It does **not** know about Zones… Archipelago proves Check 037 is reachable. The runtime then puts Check 037 in a Zone the player leaves and can never return to. **Archipelago cannot see this and will never fail on it.**"*

§0-bis then permits a capability-gated Check, key, or exit under **five** conditions, of which the first three are:

1. the matching AP location logic declares the same prerequisite;
2. Archipelago proves the capability progression is obtainable;
3. the physical Zone graph agrees with that AP logic.

**Design 6 satisfies none of 1, 2, or 3, and has no mechanism that could.** §30.6 proves `R ⊆ E` inside one composed Zone, over a capability set treated as a **constant search parameter** (§29.5). It never consults the apworld, never constrains what the apworld declares, and never emits anything the apworld could consume. Two independent solvability models, neither aware of the other, and the AP one is the one that decides whether a seed is winnable.

This is the finding with the widest blast radius, because it is not about physics. It applies to **every capability gate in every proposal**, including Design 1's three non-baseline capabilities on a tree topology.

---

## 6. HIGH — the repo holds three different positions on capability gating

Not a proposal defect. Flagged because it made §5 hard to check and will do the same to the next reader.

| Where | Position | Dated |
|---|---|---|
| `zone.py:592`, in `Zone._zone_wide_limits` | *"Optional capabilities may shortcut, flank and decorate. They may never be REQUIRED for a Check, an objective or the exit."* Enforced three ways: geometric, ownership, and `godot-legible` walking the built room | — |
| `zone.py:83`, above `ActivityKind` | *"SUPERSEDED 2026-08-30 (owner ruling)… Activities MAY now require an Echo capability… the restriction that replaces it is narrower and stronger: no requirement before guarantee"* | 2026-08-30 |
| `SOLUTIONS_CATALOGUE.md` §0-bis | *"Superseded, 2026-08-29, by owner direction."* A Check, local key, or the Zone exit may be capability-gated under five conditions | 2026-08-29, **paper only, not authorised** |

`zone.py:544` also carries a structural claim: *"no `required_echo_ids`, and no field anywhere in this schema can express a mandatory Echo requirement. Structural, not a rule."*

Whichever position is current, at least two of these comments are stale, and the schema-level claim at `:544` and the owner ruling at `:83` cannot both be describing the same system. Worth settling before any proposal is promoted, because **Design 6 contradicts all three positions differently** and it is impossible to state its status against "the engine's rule" while three exist.

---

## 7. MEDIUM — scale and vocabulary

None of these is a contradiction; all are places a proposal invented a vocabulary beside one that exists.

| Concern | Design 6 | Engine |
|---|---|---|
| Rooms per Zone | `8`–`12` (§30.2) | `ZONE_MIN_CHAMBERS=1`, `ZONE_MAX_CHAMBERS=40`, derived from content budget (`constants.py:629`) |
| Room kinds | 24 offer types, purposes from a rotation | `CHAMBER_TYPES` = corridor, arena, platform_path, tower, treasure_room (`constants.py:1155`) |
| Puzzle families | **34** (§24) | **4** `ActivityKind`s: switch_sequence, timed_run, target_challenge, pressure_routing (`zone.py:83`) |
| Sensors / actuators | 18 sensors, 12 actuator kinds (§20, §21) | 7 `AffordanceTag`s: grapple_anchor, breakable_wall, water_volume, rail, wind_volume, bounce_pad, moving_platform (`zone.py:53`) |
| Statuses | **13**, own names (§15.2) | **12**, different names (`echo.py:487`): burning, slowed, frozen, shocked, poisoned, marked, stunned, vulnerable, empowered, low_profile, haste, regenerating |
| Active enemies | `10` (§35.1) | `MAX_ENEMIES_PER_CHAMBER=12`, `MAX_ENEMIES_SPAWNED_CAP=240` per Zone |
| Capability naming | `capability:core:long_gap` | `cross_long_gap` |
| Capabilities per requirement | unbounded | `max_length=2` |
| Macro state, latches, signal graph, constraint kinds, Forge | all shipped | **none exist** |

Two notes worth more than the table row.

**`vulnerable` already exists** and is very close to Design 6's `exposed`. §0.4 spends its one cut deciding `exposed` ships without its crit clause; the engine already has a Status in that slot, and the reconciliation question is whether `exposed` is a rename of `vulnerable` rather than a thirteenth Status.

**`water_volume` is an affordance tag that ships today.** Every one of the six proposals defers water (§2.2), calling it *"the most-missed system in the repository"* and *"the first thing to add after this ships."* It is not missing from the engine — it is a declared tag whose requirement is `hover`/`glide` primitives plus the `gravity` stat. The proposals deferred something that partially exists.

---

## 8. What this means for each proposal

| # | Verdict |
|---|---|
| **1 — Reliable Core** | **Closest to buildable.** Its three non-baseline capabilities map onto `grapple`, `blink`, `cross_long_gap` almost exactly, and its tree topology with forward-only flags is the shape `validate_zone` already reasons about. Still hits §5 — its capability gates are undeclared in AP logic — and still ships a signal graph, 18 puzzle families and 9 actuators that do not exist |
| **2 — Physics Is The Game** | **Blocked at the substrate.** §3 and §2 apply in full. Waits on the v9 physics tool by the engine's own account |
| **3 — The Dungeon Is One Machine** | **Blocked on §5, buildable otherwise.** Its model check is the `established_in_zone` socket the engine left open, which is the single best fit of any proposal to any hole in the engine — but it must be reconciled with AP logic first, or it proves a property Archipelago does not consume |
| **4 — Epsilon Is The Content** | **Best aligned.** Compositional generation over an authored alphabet is what the engine already does, and §17.7's append-only catalog rule matches the engine's staged `IMPLEMENTED_PRIMITIVES` discipline. Forge fills guarantee case D |
| **5 — Status As Grammar** | **Partly present.** 12 Statuses exist with a closed vocabulary and a client-side runtime (S5). The names and the compound system differ; the substrate does not |
| **6 — The Amalgam** | **Furthest from the engine of the six**, because it is the union of all of them and inherits every blocker. §2, §3, §4 and §5 all apply. Its `3 / 5` repo-reuse rating is wrong |

---

## 8a. Update — the AP fork is now a decided contract

**2026-09-05.** §5's finding is unchanged as a statement about the code. What has changed is its status: it was an open design question and it no longer is.

The owner ruled that Design 6 adopts the conservative contract, now §29.5a of that document:

> An allocated AP Check, a local key relevant to AP reachability, or a Zone exit may sit behind a capability gate **only when** the matching Archipelago access rule declares the same prerequisite and Archipelago proves it obtainable. **Until that AP integration exists, Zone composition rejects such placement.**

**The current engine does not satisfy the first clause**, and cannot: `apworld/archipepsi/__init__.py:109`'s complete rule set is three regions gated on Signal Key counts, declaring no capability prerequisite at all. Design 6's structural check 23 therefore reduces, against today's apworld, to *"no capability gate on any AP-relevant mandatory route"* — which is the intended and safe behaviour until the integration lands.

**This is an implementation blocker, not an unresolved design choice.** The distinction matters for how it gets tracked: there is nothing left to decide, and the work is either extending the apworld to declare capability prerequisites, or accepting that AP-relevant routes stay ungated. Optional content — shortcuts, secrets, flanks, optional rewards and traversal — is unaffected and may be gated freely.

§5's recommendation 6 is closed by this ruling. Recommendations 5 and 7 remain open repository work.

## 8b. Update — connector vocabulary reconciled to the live contract

**2026-09-05.** A pass-4 addition to Design 6 (§4.9a) proposed a connector enum invented rather than read from the engine. Checking it against `connector_grammar.gd` and `traversal_law.gd` found the engine already draws the exact distinction the design needed, with different names — and the design has been corrected to the engine's, not the reverse.

| Design 6 proposed | Engine has | Resolution |
|---|---|---|
| `ConnectorKind = {DOORWAY, DROP, RAIL_MOUTH, VERTICAL_SHAFT}` | `JOINABLE = {doorway, corridor_end}` (`connector_grammar.gd:23`) | **Adopt the engine's two.** `RAIL_MOUTH` and `VERTICAL_SHAFT` do not exist; `DROP` was a traversal kind misfiled as a socket kind |
| A ten-value `CrossingMethod` | `KINDS = [gap, rise, drop, walk]` (`traversal_law.gd:76`) plus offer sockets `launch_source`, `rail_route`, `grapple_point` | **Adopt four base kinds plus three offer-mediated plus `ACTUATOR_RIDE`** |
| "Standardized attachment collar", asserted as already satisfied | `SIDE_CLEARANCE = 0.4`, `HEAD_CLEARANCE = 0.2`, engine-wide constants; `content.py` refuses a `room_shell` with no joining socket | **The claim was right and is now cited.** Joinability genuinely is a socket-pair property |

Across the twelve `review: pass` shells the joining sockets are **32 `doorway` and 4 `corridor_end`**, so the reconciled vocabulary is what the authored rooms already declare.

Two further places still enumerated the invented kinds after the enum was replaced — the signature space and the connector-satisfiability rule — and were caught by a new `semcheck` class rather than by reference lint, which passed while both were live. A stale enumeration in prose resolves fine; only a check that knows the vocabulary catches it.

**This is the good direction for a finding to run.** The design moved toward the engine, no authored room needs rework, and one invented enum is gone. It also closes the pass-4 instruction to use *"the exact equivalent ids already present in the live authored-room contract if those names differ"* — they did differ, and they now match.

## 8c. Does Design 6 replace any authored room?

**No.** Design 6 is a *consumer* of the shell catalog and never an author of it:

| Design 6 does | Design 6 does not |
|---|---|
| Require every room record to name a `shell_id` (§30.11.1) | Author, generate, modify, or delete any shell |
| Filter the catalog into `offered_shells` per room (§30.11.2) | Change a shell's geometry, sockets, or review state |
| Require the runtime instantiate exactly the named shell (§30.11.4) | Replace an authored shell with a procedural one — it forbids exactly that |
| Read `review: pass`, type, sockets, and clearance | Write any of them |

Wave 2 shells, the 20–30-room proof library, and Theme Packs are explicitly **off** its critical path (§40.1). The authored-room pipeline and Design 6 meet at one seam — `shell_id` — and the design's whole contribution there is to stop that seam silently discarding the rooms.

## 9. Recommended changes## 9. Recommended changes## 9. Recommended changes

**To Design 6, now** — these are corrections of provably false statements, not redesign:

1. Reuse rating `3 / 5` → `1 / 5`, with §41.2 saying why.
2. §41.2's "largest technical risk" replaced: solver determinism is not the risk, the absent physical layer is.
3. §29.3's numeric floor withdrawn and restated in the engine's set-membership shape.
4. A new closure subsection recording §2, §3 and §5 as engine-blocking, so no reader takes the document as buildable-as-written.

**To the repository, for the owner:**

5. Settle §6's three positions on capability gating. Two of the three comments are stale and the schema claim at `zone.py:544` cannot coexist with the owner ruling at `zone.py:83`.
6. Decide §5 before any proposal is promoted. Either the apworld learns to declare capability prerequisites, or Zone composition is forbidden from placing an allocated Check behind one. **A model check in the bridge cannot substitute for a rule Archipelago can see**, and `Accessibility: full` is the default.
7. Add the test `SOLUTIONS_CATALOGUE.md` §0 asks for and notes nothing currently looks for: *no location may be allocated to a Zone that the player can put permanently out of reach.* `abandon_zone` returning locations covers the abandon path; it does not cover a Zone left in a state that holds its allocation.

**Not recommended:** rewriting Designs 1 through 5 against the engine. They are proposals for a target, the target is legitimately ahead of the code, and §1 shows the architecture agrees. What was missing was this document.
