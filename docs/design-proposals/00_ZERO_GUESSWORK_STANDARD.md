# ARCHIPEPSI — THE ZERO-GUESSWORK STANDARD

**Status:** Process authority for `docs/design-proposals/`
**Version:** 1.0
**Applies to:** All five Complete Design proposals, and any document that claims to be implementable without further design input.

---

# 0. WHY THIS DOCUMENT EXISTS

The two source authorities in `docs/authorities/` decide **what Archipepsi is**. They deliberately stop short of deciding **exactly how every system behaves**, and they say so: they separate architectural law from tuning from deferred systems.

That gap is correct for an authority document and fatal for an implementation prompt.

A design proposal handed to an implementing agent has a specific failure mode. The document looks complete. Every system is named. Every section has content. And then, buried in ordinary prose, are sentences like:

- "the mechanism may reset";
- "author-defined";
- "an appropriate duration";
- "tune later";
- "handled sensibly";
- "the usual behavior applies".

Each one silently transfers a design decision to whoever implements it. The implementer is not a designer, is not asking permission, and will pick something plausible. Fifty plausible picks later, the shipped game is not the designed game, and nobody can point at the moment it diverged.

This document defines the bar that prevents that, and the audit that proves a proposal clears it.

---

# 1. WHAT "ZERO GUESSWORK" MEANS

## 1.1 The rule

> **For every player-visible behavior, every piece of saved state, every input to procedural validity, and every failure case, the document mandates exactly one outcome.**

"Exactly one" is the operative phrase. Not a recommended default. Not a range with a suggested midpoint. Not two options with a note that either is fine. One.

## 1.2 What this does NOT mean

This standard constrains **design**, not **engineering**. An implementing agent retains full freedom over:

- class and file organization;
- node hierarchy and scene composition;
- data structure choice, so long as the serialized shape matches;
- algorithm selection, so long as the result matches;
- naming of internal symbols;
- refactoring, optimization, and abstraction;
- test structure and framework use;
- when to introduce a helper, a base class, or a service.

A design proposal that specifies a Godot node tree or a Python class layout has overstepped. It is telling the engineer how to engineer, which is both rude and wrong — and it crowds out the decisions the document actually owes.

The line is:

| The document owns | The implementer owns |
|---|---|
| What the player sees and feels | How it is rendered and structured |
| What is written to a save file | How the writer is implemented |
| What makes a generated Zone valid or invalid | How the validator is organized |
| What happens when something fails | Which exception type carries it |
| Every number the player can perceive the effect of | Every number that only affects performance |

## 1.3 The four mandated categories

A proposal must close all four. They are listed in the order they cause damage when left open.

### 1.3.1 Player-visible behavior

Anything the player can perceive, directly or by inference. Includes:

- what an input does, in every state the player can be in when they press it;
- what an action costs, and when the cost is committed;
- what happens when an action cannot be performed;
- every number the player can feel the effect of — damage, duration, range, capacity, rate, threshold, chance;
- what the HUD shows and when it changes;
- what feedback accompanies success, failure, and rejection.

"Tuning value" is not an escape hatch here. The source authorities correctly mark many numbers as playtest-owned. A proposal must still **name a starting value**, because an implementer cannot ship a blank. The proposal says `12.0`; the tuning pass may later say `14.5`. What the proposal may not say is "an appropriate value".

### 1.3.2 Saved state

Everything that survives a boundary. For each piece of state, the proposal must answer:

- which persistence category it belongs to;
- its exact serialized shape, including types, defaults, and nullability;
- what happens to it on death, room unload, Zone exit, save/load, and later revisit;
- how it is reconstructed when a load encounters it mid-transition;
- what happens when a load encounters a version that predates it.

An unanswered persistence question does not fail loudly. It fails as a corrupted save three months later.

### 1.3.3 Procedural validity

Everything the generator consults to decide whether a Zone is legal. Includes:

- what the generator may choose, from an explicitly closed set;
- what it may never choose;
- every constraint a candidate must satisfy;
- search order, retry limits, and what happens when the search exhausts;
- the certified fallback used when generation cannot succeed;
- what makes composition reproducible from a seed.

This category is where "plausible" is most dangerous. An implementer who invents a fallback will invent one that terminates, not one that is correct, and the failure surfaces as an unwinnable seed in someone's multiworld.

### 1.3.4 Failure cases

Every path where the expected thing does not happen. For each:

- the exact observable outcome;
- whether state changes;
- what the player is told;
- whether it is recoverable, and by what mechanism.

A proposal that specifies only the happy path has specified roughly a third of the game.

---

# 2. FORBIDDEN CONSTRUCTIONS

These phrasings transfer a decision to the implementer. A proposal containing them has not met the standard, regardless of length.

## 2.1 Permissive modals about behavior

| Forbidden | Why | Required instead |
|---|---|---|
| "may reset" | Two legal implementations | "resets" or "does not reset" |
| "can be configured to" | Configured by whom, to what | State the value |
| "should normally" | Names an exception without defining it | State the rule, then state the exception explicitly |
| "is allowed to" | Permission without a decision | Decide |

**Exception.** `may` is legal when it describes an authored *option within a closed set the document itself enumerates*, and the selection rule is specified. "A Weapon may declare a secondary from the catalog in §11.2; a Weapon with no secondary declares `null` and RMB is inert" is fine — the set is closed, the default is stated, and the behavior of the empty case is defined.

## 2.2 Deferred authorship

| Forbidden | Required instead |
|---|---|
| "author-defined" | Define it, or name the closed set the author picks from and the default |
| "content-dependent" | Same |
| "per-package" | Give the package manifest a required field with a type and a default |
| "TBD", "TODO", "to be tuned" | A value |

## 2.3 Unquantified magnitudes

| Forbidden | Required instead |
|---|---|
| "a short delay" | `0.25 s` |
| "a reasonable range" | `18.0 m` |
| "briefly" | a duration |
| "a small chance" | a probability |
| "large room" | a measurement, or a named size class defined elsewhere in the document |

## 2.4 Silent inheritance

| Forbidden | Required instead |
|---|---|
| "existing behavior is unchanged" | Name the file, symbol, or document section that holds the behavior, and pin what specifically is being inherited |
| "as in the current implementation" | Same, with a commit-stable reference |
| "standard FPS behavior" | Specify it |

Silent inheritance is the subtlest failure because it reads as diligence. It is the reason a proposal can be 17,000 words and still not be implementable: every unpinned inheritance is a decision the implementer must reconstruct from code that may have changed.

---

# 3. THE CLOSURE CHECKLIST

Every proposal must close all twelve areas. A proposal that defers an area must say so in its scope section and explain what the deferral costs — a deferral is a decision, and decisions are in scope; only silence is forbidden.

1. **Content-generation rules** — how Epsilon selects families, parameters, weights, and combinations; how seeds map to output; what duplicate results produce; what the model is and is not permitted to choose.
2. **Machine-readable schemas** — exact serialized shapes with types, defaults, nullability, value ranges, and identifier formats, for every persisted and generated object.
3. **Delivery edge cases** — for every offensive and manipulative action: collision, overlap, bounce, penetration, detonation, sampling cadence, mutual-exclusion locks, and scaling.
4. **Compatibility matrices** — which components may combine with which, stated as a table rather than as prose implication, plus stacking and ordering rules for anything that can apply twice.
5. **Movement and physics details** — ground/air legality, cancellation, interruption, collision recovery, constants, and target-selection rules for every movement and manipulation action.
6. **Machinery transition behavior** — what every actuator does when its signal reverses mid-motion, loses power mid-motion, is reset mid-motion, or receives conflicting simultaneous commands.
7. **Persistence edge cases** — save/load fidelity, reconstruction order, mid-transition state, temporary grants, and active encounters.
8. **Enemy and encounter contract** — minimum stats and interfaces, faction behavior, status-compatible actions, wave structure, respawn, clear conditions, and environmental death credit.
9. **Concrete fixtures** — at least one fully specified, runnable reference instance per puzzle family, with real measurements, plus a certified fallback Zone.
10. **Player-facing flow** — starting state, first-run experience, every menu transition, every invalid-state screen, and exact failure messaging.
11. **External contract pinning** — every system described as existing or unchanged must be referenced precisely enough to implement against without reading it and guessing.
12. **Test vectors** — every named acceptance test must have concrete inputs and expected outputs.

---

# 4. THE ADVERSARIAL AUDIT

Length is not evidence of closure. Before a proposal is marked complete it must survive an audit run against itself, in this order.

## 4.1 Mechanical sweep

Search the document for every construction in §2. Every hit is either fixed or justified under the §2.1 exception. This is fast and catches the majority of leaks.

## 4.2 Contradiction sweep

Two sentences in different sections that permit different behavior is the most damaging defect class, because both readings look authorized. Specifically check:

- any state described as exclusive against every table that lists actions in that state;
- any count or capacity stated in more than one place;
- any ordering rule against every list that implies a different order;
- anything described as "always" or "never" against every exception elsewhere.

The known example from the salvaged draft: one section said Gear has exactly one intrinsic while another correctly gave high-tier Gear two. Both sentences read as authoritative. An implementer picks one and moves on.

## 4.3 Implementer simulation

For a sample of at least ten behaviors spanning all four mandated categories, read only what the document says and ask: **could two competent engineers build this differently and both be following the document?** If yes, the passage is not closed.

Sample deliberately from the boring parts. The exciting systems get written carefully; the leaks are in the third paragraph of the persistence section.

## 4.4 Fallback trace

Follow every failure path to a terminal state. A failure path that ends in an unspecified state, or loops back to a condition that can fail the same way, is not closed. Pay particular attention to generation: a search that can exhaust must name what happens when it does, and that outcome must itself be certified valid.

## 4.5 The completeness question

Not "did I cover every system?" but: **is there any moment of play where the player does something and this document does not say what happens?**

Answering it requires walking the actual experience — launch, first Zone, first receipt, first death, first save, first revisit, first invalid loadout, first exhausted generation — rather than walking the table of contents.

---

# 5. SHARED DOCUMENT STRUCTURE

All five proposals use the same top-level structure so they can be compared section against section, and so that combining pieces from several is a merge rather than a rewrite.

```
0.  Purpose, thesis, and proposal profile
1.  Inherited laws            (what this design does not reopen)
2.  Scope                     (ships / deferred / removed, each with cost)
3.  Authority and data ownership
4.  Schemas                   (the machine-readable core)
5.  Lifecycle and persistence
6.  Base player
7.  Input
8.  Damage
9.  Interaction
10. Carryables and sockets
11. Weapons
12. Abilities, readiness, and cost
13. Mobility
14. Physics
15. Status
16. Gear, Mods, and rules
17. Foreign items, Archive, and migration
18. Economy
19. Signal graph
20. Inputs and sensors
21. Actuators and machinery
22. Hacking
23. Puzzle-package contract
24. Puzzle families
25. Hazards and destruction
26. Routing, forces, and constraints
27. Media
28. Room and Zone topology
29. Capability progression
30. Procedural composition
31. Cross-system compatibility
32. Enemies and encounters
33. HUD and presentation
34. Player-facing flow
35. Performance budgets
36. Debugging and inspection
37. Reference fixtures
38. Test vectors
39. Implementation waves
40. Closure statement
```

Section 40 is mandatory and is the proposal's own claim about itself: what it decided, what it sacrificed, what it deferred, and an explicit statement that no behavioral decision inside it is intentionally left open. A proposal that cannot honestly write §40 is not finished.

## 5.1 The proposal profile

Each proposal opens with the same axes, rated 1–5, so the five can be compared at a glance:

| Axis | Meaning |
|---|---|
| Novelty | How far it departs from conventional FPS/dungeon design |
| Player-build variety | How many meaningfully different builds it supports |
| Environmental breadth | How much of the Dungeon Authority's vocabulary it implements |
| System interaction depth | How much emergence comes from systems colliding |
| Implementation risk | How likely it is to go wrong in production (higher = riskier) |
| Procedural validation difficulty | How hard it is to prove a generated Zone is valid |
| Reuse of current repo foundations | How much existing work survives |

---

# 6. RELATIONSHIP TO THE SOURCE AUTHORITIES

A proposal **resolves** the authorities. It does not amend them.

- Where an authority states an architectural law, the proposal inherits it verbatim and lists it in §1 without re-deciding it.
- Where an authority marks something as tuning, the proposal picks a starting value.
- Where an authority defers a system, the proposal either implements it (and says so) or confirms the deferral (and says what that costs).
- Where an authority is silent, the proposal decides — and flags the decision in §40 as a proposal-level choice rather than inherited law, so the owner can see what they are actually picking between.

If a proposal believes an authority is wrong, it says so explicitly in §40 and proposes the change as a change. It does not quietly contradict it. A contradiction that is not flagged is indistinguishable from an error, and the implementer resolves it by guessing which document is newer.

---

# 7. WHAT SELECTION MEANS

These five proposals are alternatives, not drafts. Exactly one outcome is expected:

The owner reads them, selects one as the base, and optionally names specific sections from others to merge in. The result is promoted to `docs/authorities/` as the Complete Design Authority, and only then does implementation begin against it.

Until that promotion, no proposal is canon, and no proposal should be implemented from — including the one that seems obviously best. A proposal that is half-implemented before selection recreates exactly the condition these documents exist to end: a codebase built from a design nobody formally chose.

---

**End of the Zero-Guesswork Standard**
