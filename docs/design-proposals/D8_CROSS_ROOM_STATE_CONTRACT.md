# D-8 — the cross-room relationship and state contract

**Dess, 2026-09-22.** For Prod's counter-signature, before either lane
writes an implementation of it.

The owner's 0.4 scope clarification says room boundaries must stop being
the default limit on puzzle scope, and names the two things to build on:
Amalgam **§19.7**'s local-mechanism / Zone-state split, and the
**`RailNetwork`** contract already delivered. It also says, twice over,
what not to do: no second railway system, and no unrestricted global
signal bus.

This document is the shared half. It proposes no new mechanism. §19.7
already draws the split, §5.1 already assigns every lifetime a category,
and §5.6 already fixes the restore order. **What is missing is the
bridge's ability to declare any of it** — and that absence is the whole
finding.

---

## 1. Measured first, five facts

Per the plan's own P0 rule, here is the seam as it actually is at
`96b6fdd`, not as I assumed it was.

**1. The bridge budgets a thing it cannot name.**
`physics.state_vector_product(macro_variables=(...))` takes a tuple of
*state counts per variable* and multiplies them against
`STATE_VECTOR_BOUND`. It is arithmetic over integers. No variable has a
name, a room, a reader or a writer anywhere in `archipepsi_bridge`. A
grep for `macro` across the package returns eight hits, all of them in
`physics.py`, all of them budget arithmetic.

**2. The edge has no predicate.**
`TopologyEdge` carries `capability` and nothing else. Amalgam §5.6 step
6a says: *"Evaluate every `TopologyEdge` predicate against the restored
macro state, latches, and agency consequences."* The bridge's edge has
no such predicate to evaluate. The design describes a check the code
cannot express.

**3. The search state is two components short.**
`topology._explore` carries `(room, held_keys)`. §4.10's state vector is
macro variables, latches, encounter flags, shortcut flags, visited flags
and local keys. The search sees one of six.

This is *not* the project's recurring "two spellings of one fact" —
it is the quieter failure underneath it. There is no second spelling to
disagree with, so nothing is inconsistent and nothing is checked. A
measurement that exists, is correct, and is never handed the case that
fails it, one step earlier: a measurement that exists and is never
handed a case at all.

**4. `RailNetwork` is already a cross-room relationship.**
This matters more than the three gaps above, because it means the shape
is proven rather than proposed:

| `RailSpan` field | What it already is |
|---|---|
| `control_room_id` | the room holding the alignment control — **where the player interacts** |
| `from_dock` / `to_dock` | docks resolved to rooms that are **not** the control room |
| `latch_id` | **the persistence handle** the commissioned span survives under |
| `mandatory` | whether the mandatory path crosses it |

A player throws a lever in one room and a span between two other rooms
becomes crossable, and the repair survives leaving. That is the whole
cross-room pattern, specialised to rails, with no general form behind
it. The general form below is that shape with the rail nouns removed.

**5. The existing demonstration is the one the clarification excludes.**
`railway_scenario.gd`'s own docstring says it plainly:

> *"This is not a Zone. It is not composed, it carries no Checks, no exit
> and no Archipelago logic."*

S1, S2 and S3 are labelled areas of one standalone scene. The
clarification rules that insufficient by name — *"not one large
standalone scenario divided into labelled areas"* — and the scenario
agrees with it. Nothing here proposes discarding it: it is working
development scaffolding and it stays. It is simply not the acceptance
case, and it never claimed to be.

---

## 2. The split, quoted rather than invented

Amalgam §19.7, in full force:

- **Room graphs read macro state and never write it.**
- The machine graph has no logic nodes and is evaluated on macro change
  only.
- Macro effects are **idempotent** (rule 5), which is what makes §5.6's
  replay safe rather than merely conventional.
- **Latches are room-layer, not machine-layer.** A latch lives in its
  package's room graph, is read by the verifier as a state-vector
  component (§4.10), is never a machine-graph variable, has no
  predicate, and drives no macro effect.
- And the sentence this whole contract turns on:

> *"A puzzle that should change the Zone drives a setter package's
> interaction, which the player then performs — the latch does not reach
> across rooms on its own."*

**The consequence, which is the contract's spine.** A cross-room
relationship is always exactly three things in a fixed order:

1. a **player-performed interaction** in the source room, that
2. writes a **declared Zone-state handle**, which
3. a destination room's graph **reads**.

There is no room-to-room channel anywhere in that sequence. **The global
signal bus the clarification forbids is not forbidden by a new rule — it
is unrepresentable**, because rooms do not address each other at all.
They address handles. That is why §19.7 is the right foundation rather
than a convenient citation: it rules the bus out structurally, and
§30.6's tractability argument depends on it holding.

---

## 3. The five lifetimes, each mapped to a category that already exists

The approved plan carried four persistence lifetimes. The clarification
names five. None of the five is new; each already has a home in §5.1,
§5.4a or §10.5, and the fifth is the one the plan's four did not cover.

| # | The owner's words | Amalgam category | Handle | Survives |
|---:|---|---|---|---|
| 1 | permanent accepted changes | `AgencyRecord` §5.4a.1 (`MACRO_SET`, `LATCH_SET`, …) and latches §5.5 | `latch_id` | save, load, **death, reset**, room unload |
| 2 | reversible Zone configuration | `ZoneState.macro`, `ZONE_PERSISTENT` §5.1 | `variable_id` + state | save, load, death — and is **settable back** |
| 3 | temporary timers/Statuses | `EPHEMERAL` §5.1 (all `ActiveStatus`); `TIMER`/`DELAY` node state §19.6 | none | nothing; rebuilt at §5.6 step 14 with zero Statuses |
| 4 | held inputs | live signal values — **never serialized**, §5.4a | none | nothing; recomputed at §5.6 step 6a |
| 5 | transported-object state | `PUZZLE_LOCAL` when `required` or constrained, else `EPHEMERAL`; a **multi-room carryable is `ZONE_PERSISTENT`** with `allowed_volume`, §10.5 | object id + `allowed_volume` | per category |

Lifetime 5 is the one worth pausing on, because the union already
promises it and nothing has collected: §10.5's `allowed_volume` is *a
list of rooms*, and the Amalgam's own example sentence is

> *"A `BURNING` power cell carried three rooms to a generator is a
> sentence this union can write and none of the five could."*

A carried object crossing rooms is a cross-room relationship whose
handle is the object itself. It needs no new category — it needs
`allowed_volume` to be declarable, and today it is not.

### 3.1 The rule the clarification asks for by name

> *"Do not silently replace a live requirement with a permanent latch."*

This is lifetime 4 → lifetime 1, and it is a **change of meaning, not an
optimisation**. A held lever that must stay held is a live requirement;
latching it makes it a different puzzle, and makes the verifier's answer
wrong in the player's favour — the worst direction, because nothing ever
fails.

The design licenses **exactly one** such conversion, §20.7:

> *"a Status … may reach a mandatory route only through a latch. … the
> Status sets the latch, the latch is permanent, and the Status is free
> to expire two seconds later. The verifier sees a monotone Boolean and
> never learns that `updraft` exists."*

That licence is narrow and it is earned: Statuses are `EPHEMERAL` by
§5.1, so without the latch a mandatory route would rest on state that
does not survive a save. **It does not generalise to held inputs.**

So the contract's rule is: **a relationship declares its lifetime, and
the lifetime is validated against what the relationship does — never
inferred from what is convenient to persist.** Where a design genuinely
needs the §20.7 conversion, it is declared and visible, which is the
opposite of silent.

---

## 4. The declaration — the bridge half, and what I am asking Prod to agree

Shaped after `RailNetwork`, which works, rather than after a new idea.

```
ZoneStateVariable:
  variable_id    : Id                     # the HANDLE. Zone-scoped.
  states         : tuple[str, ...]        # 2..4, §4.10's per-variable range
  default        : str                    # one of `states`
  setter_room_id : Id                     # where the player performs it
  lifetime       : enum { ZONE_CONFIGURATION, PERMANENT }
```

and, on the thing that reads it:

```
StateCondition:
  variable_id    : Id
  state          : str
```

carried by `TopologyEdge` (and, when D-3 lands, by `DoorAssignment`), so
that §5.6 step 6a finally has a predicate to evaluate.

`lifetime` admits only the two **persistent** lifetimes, deliberately.
Lifetimes 3 and 4 are `EPHEMERAL` and never serialized, so a declaration
of them would be a declaration of something the save must not contain;
lifetime 5's handle is the object, not a variable. Declaring only what
persists is what keeps the vocabulary from being a second spelling of
the Status system.

### 4.1 Why the destination names the handle and never the source node

The clarification requires: *"a rebuilt destination must not depend on a
stale reference to a source node."* The declaration makes that
**structural rather than a discipline**, and §5.6's fixed order is the
reason:

| step | what is restored |
|---:|---|
| 4 | `ZoneState.macro` — **the handle** |
| 5 | latched conditions |
| 6 | the `AgencyRecord` log, replayed in `accepted_at` order |
| 6a | every `TopologyEdge` predicate evaluated; **live values computed, never loaded** |
| 9 | per-room `PUZZLE_LOCAL` state |
| 10 | physical configurations — place, attach, constrain |

The handle is restored at step 4. The source node is a room-local object
rebuilt at steps 9–10, and after a reload it may be **a different
object**: `M1-visible` already asserts exactly that, that the span, the
lever and the carrier are different objects after a return. A
destination that named the source node would name something that no
longer exists, five steps before it exists.

**So the handle is the only thing that survives step 4, and therefore
the only thing a destination may name.** The stale-reference failure the
clarification warns about is not defended against; it is made
impossible to write down.

### 4.2 The compatibility test this contract must pass

A general form that cannot express the specific one already delivered is
the wrong general form. So, falsifiably:

> **`RailNetwork` must be describable in this vocabulary without being
> replaced by it.**

It is: `control_room_id` is `setter_room_id`; `latch_id` is a handle at
`lifetime: PERMANENT`; a span's crossability is a `StateCondition` on
the edge joining its docks' rooms. `RailNetwork` **stays exactly as it
is** — it is not migrated, deprecated or re-expressed in code. The test
is that the general form *could* say what it says. If Prod finds a rail
behaviour this vocabulary cannot describe, the vocabulary is wrong and I
would rather hear it now than after two implementations exist.

This is also the answer to "no second railway system": there is no
second one because there is no first one here. This layer describes
relationships; the railway remains the only thing that moves carriers.

---

## 5. Generation constraints — mine

1. **Distinct rooms, enforced.** `setter_room_id` must differ from every
   room reading the handle. A relationship whose source and destination
   are one room is not cross-room, and a declaration that says otherwise
   is a lie the acceptance case would then be built on.
2. **Bounded, through the budget that already exists.** Declared
   variables feed `state_vector_product` — the function that has been
   waiting for real arguments since it was written. Latches and macro
   variables compete for one `STATE_VECTOR_BOUND`, which is already
   true and will now actually be checked.
3. **Epsilon keeps a real choice.** Which rooms hold the setter and the
   destination, and which relationships exist at all, are Epsilon's
   within the declared constraints — not one hardcoded scenario with
   the composition path bolted on afterwards.
4. **§13.2 keeps its force.** A relationship on the mandatory path is
   first-class Zone data, never a `feature:` tag — the same argument
   that made `RailNetwork` first-class, unchanged.

## 6. Progression validation — mine

The search state grows from `(room, held_keys)` to
`(room, held_keys, macro)`, and only for Zones that declare variables,
so every Zone composed before this is untouched and
`schema_version` does not move.

The single rule that makes it safe is §19.7's own: **a variable changes
only in its setter room.** Reaching the setter room is therefore a
precondition of every state it unlocks, which turns the whole class of
self-locking Zones into one question the search can ask — the same shape
as D-1's circularity guard, generalised:

- **No self-locking configuration.** A `PERMANENT` relationship may not
  make its own setter room, or a required Check, exit or objective,
  unreachable. (A `ZONE_CONFIGURATION` variable cannot strand the player
  by itself, since it can be set back — but only if the setter room is
  still reachable in the state it was just put into, which is the case
  that must be searched rather than argued.)
- **No undeclared mandatory gate.** If a required Check or the Zone exit
  is reachable only under some state, that state's setter room must be
  reachable without it. This is the load-bearing boundary restated: a
  physical gate that AP's location logic does not declare is the thing
  that may never happen.
- **Prerequisite guarantees carry.** A relationship gated on a
  capability carries that capability through the existing
  `capability_guarantee` cases, including case C now that
  `established_in_zone` has a producer. No new guarantee path.

## 7. Save representation — mine, and D-6's first real content

§5.6's order is fixed and not negotiable. What the bridge's save must
carry, in that order: macro at step 4, latches at step 5, `AgencyRecord`s
at step 6. **Live signal values, never** — a save that stored voltages
would be a save that could disagree with the graph that produced them.

The three reload requirements land on that order directly:

| Requirement | What it is, in §5.6 terms |
|---|---|
| **Partial-progress reload** | steps 4–6 restore a handle mid-relationship; step 6a recomputes the destination from it |
| **Completed-progress reload** | a `PERMANENT` handle restored at step 5; the consequence holds |
| **Local reset without losing unrelated progress** | steps 9–10 rebuild room-local state to defaults while steps 4–6 are untouched |

The third is the one that proves the split is worth having. **Local
reset is cheap and safe precisely because nothing cross-room lives in
the room.** If a destination held its own copy of the relationship's
state, a reset would either destroy Zone progress or have to be taught
which of its state is secretly global — and that teaching is exactly the
bug the handle rule prevents.

---

## 8. Ownership, and the one thing that must be agreed first

| Mine (Dess) | Prod's |
|---|---|
| the shared relationship/state contract | runtime binding |
| generation constraints | machinery behaviour |
| progression validation | cross-room feedback to the player |
| save representation | physical acceptance tests |

**The one thing that must be agreed before either of us writes code is
the handle vocabulary** — `variable_id`, its states, and the two
persistent lifetimes. If your runtime names a handle one way and my
schema another, that is two spellings of one fact for the fourth time in
this project, and F-21 cost us a merge already over a map we had both
exported under different names in the same week.

Everything else in here can be argued after implementation starts.
That cannot.

## 9. What I am asking you to counter-sign

1. §19.7's three-step crossing (interaction → handle → read) is **the**
   cross-room mechanism, and rooms never address each other.
2. The five lifetimes map as §3's table says, and §3.1's
   no-silent-latching rule binds both lanes.
3. `ZoneStateVariable` / `StateCondition` as the handle vocabulary —
   names and shape, argued now rather than merged later.
4. Destinations name handles, never source nodes (§4.1).
5. `RailNetwork` is described by this vocabulary and **not** replaced by
   it (§4.2) — and you tell me if any rail behaviour escapes it.

## 10. Scope kept

No second railway. No global signal bus — unrepresentable, per §2. No
new persistence category: all five lifetimes were already in §5.1,
§5.4a and §10.5. `schema_version` stays 7 and every existing Zone stays
valid, because the declaration is optional and a Zone that declares
nothing means exactly what it meant before. The minor scenarios
(EX50-011, EX50-021, EX50-033) are untouched and stay in scope, and
`railway_scenario.gd` remains the development scaffolding it says it is.
