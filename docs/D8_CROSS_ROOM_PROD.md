# D-8 — Cross-room puzzle state: the engine lane's half

**Prod (engine) → Dess (bridge/design), 2026-09-22.**
Owner scope clarification, 2026-09-22: puzzles must support branch- and
Zone-spanning relationships; room boundaries must not be the default limit on
puzzle scope. **This is 0.4 completion, not a post-0.4 extension.**

Nothing here is an implementation. The owner's instruction is explicit —
*"Agree the shared contract before competing implementations are written"* — so
this states what the runtime needs declared, what it already has, and the two
places where the required design **exceeds the pinned rules**, with the exact
rule and the proposed amendment named rather than worked around.

---

## §0 Ownership, as the owner set it

| | |
|---|---|
| **Dess** | shared relationship/state contracts, generation constraints, progression validation, save representation |
| **Prod** | runtime binding, machinery behaviour, cross-room feedback, physical acceptance tests |

So this document does **not** propose a schema. Where it names a field it is
naming *what the runtime must be told*, not how to spell it.

---

## §1 What is already settled, and must not be reinvented

**Amalgam §19.7 pins the whole architecture**, and it is not a signal bus:

> Room graphs read macro state and never write it; the machine graph has no
> logic nodes and is evaluated on macro change only; macro effects are
> idempotent.
>
> **One addition: latches are room-layer, not machine-layer.** […] **A puzzle
> that should change the Zone drives a setter package's interaction, which the
> player then performs — the latch does not reach across rooms on its own.**

That single sentence is the owner's *"do not silently replace a live
requirement with a permanent latch"* and *"no unrestricted global signal bus"*,
already written down. The shape of every cross-room puzzle follows from it:

```
room A          the player performs an interaction on a MACRO SETTER
   |            (room-layer input; the player is the bridge, not a wire)
   v
MACRO STATE     one Zone-scope variable, 2..4 states, reversible
   |            (machine-layer; no logic nodes; idempotent effects)
   v
room B          its room graph READS that state (§20 types 13/14) and its
                machinery responds (§21's macro effect types)
```

The read side is **`MACRO_STATE`** (Boolean) and **`MACRO_SELECTOR`**
(value `[0,15]`) — §20 types 13 and 14, pinned from Design 3 §20.5. The
actuator side is Design 3 §21.10's ten macro effect types, pinned at §21. The
budget rule is §4.10, and it already has teeth: `physics.py` says *"latches
compete with macro variables for that budget"*.

**None of this needs inventing. All of it needs building.**

---

## §2 What the engine actually has today — measured, not assumed

| capability | state |
|---|---|
| `MACRO_STATE` / `MACRO_SELECTOR` sensors | **absent.** `grep -rn macro godot/scripts/` returns nothing |
| macro effect types (§21, Design 3 §21.10) | **absent** |
| any Zone-scope variable a room reads | **absent** |
| re-evaluating a room when Zone state changes | **absent.** Rooms are built once in `ZoneController.setup` and nothing revisits them |
| state-vector budget accounting | **present, bridge side.** `physics.state_vector_product(macro_variables=…)` and `check_physics_content` already count them |
| a macro declaration in the Zone schema | **absent.** `zone.py` has no macro anything |
| room-local signal → actuator | **present but deliberately local.** `PoweredLink`: live signal, recomputed every physics frame, *"nothing here writes to a save, and there is deliberately no field it could write to"* |
| cross-room persistent consequence | **present but monotone only.** `report_latch` / `progress.latched` |

### F-23 — every piece of Zone-scope state the engine has is monotone

Latches, keys, station reached-ness: all one-way, all deliberately so, each
with a comment explaining why progress is monotone. **There is no reversible
Zone-scope state in the engine at all.**

That matters because the owner's five state classes are not one thing, and
exactly one of them has no home:

| class | today | where it belongs |
|---|---|---|
| permanent accepted change | `report_latch`, monotone, idempotent by `package_id/latch_id` | room layer (§19.7), already built |
| **reversible Zone configuration** | **nothing** | **machine layer — the gap** |
| temporary timer / Status | `StatusEffects`, `ServiceShutter.left`, live only per §5.4a | room layer, already built |
| held input | `PoweredLink.powered`, recomputed per frame, never saved | room layer, already built |
| transported-object state | `ManipulableBody` position, replayed from the manifest | **unclear — see §4 question 1** |

So a cross-room puzzle built on today's engine would have exactly one way to
express itself: a latch. Which is the shortcut the owner forbids, and §19.7
forbids it too. **The reversible macro layer is the missing piece, and it is
the whole of D-8.**

---

## §3 What the runtime needs declared

Stated as questions the runtime must be able to answer, not as fields.

1. **Which macro variables does this Zone have?** An id, a state count
   (2–4, per §4.10's product), an initial state, and whether it is reversible.
   The engine needs the id to bind by — see §5's stale-reference rule.
2. **Where is each setter, and what does operating it do?** A room id and the
   variable it sets, plus which state(s) it can select. §19.7 requires the
   player to perform this; the engine builds the interactable and refuses to
   let anything else write.
3. **Which rooms read which variable, and what responds?** A room id, the
   variable, the predicate (`MACRO_STATE` Boolean, or `MACRO_SELECTOR` value),
   and which local mechanism it drives.
4. **Is the relationship on the mandatory path?** Exactly the question
   `RailSpan.mandatory` already answers for a span, and for the same reason:
   §13.2 forbids a feature from lying on the mandatory path, so a mandatory
   cross-room relationship cannot be a `feature` either. **Reuse the
   `rail:<network_id>` precedent rather than inventing a second kind of
   content ref.**
5. **What does the save carry?** Dess's call. The engine's constraint is only
   this: a reversible variable's *current state* is not a monotone fact, so it
   cannot ride `progress.latched` without lying about what it is.

---

## §4 Where the required design exceeds the pinned rules

The owner asked for *"the exact rule and proposed amendment rather than hiding
the mismatch"*. There are two, and only two.

### Question 1 — §19.7 does not cover transported objects

§19.7 splits the world into a room layer and a machine layer. An object the
player **carries from room A to room B** is neither: it is not macro state
(rooms may not write it), and it is not a latch (it is not monotone — you can
carry it back). Today `ManipulableBody` positions are replayed from the
manifest, which is a room-local answer to a question that has just stopped
being room-local.

**Proposed amendment:** state explicitly that a transported object is
**room-layer state whose owning room is its current room**, and that crossing a
boundary is a transfer rather than a write to the machine layer. This keeps
§19.7 rule 2 intact. If instead an object's *location* should be readable by
another room's graph, that is a macro variable being set by the transfer, and
the transfer needs to be a setter interaction like any other — which the player
performs by carrying it, satisfying §19.7's "the player is the bridge".

### Question 2 — §19.7 makes a cross-room HELD requirement impossible

This is the sharp one, and it is the one the owner's *"do not silently replace a
live requirement with a permanent latch"* is pointing at.

§19.7 rule 2: **room graphs read macro state and never write it.** A held input
— a lever held down, a crate held on a plate — is room-layer live state. So
"hold this down in room A and the door in room B stays open *while you hold
it*" **cannot be expressed**: room A's graph would have to write macro state,
which rule 2 forbids, and the only legal alternative today is to make it a
latch, which converts a live requirement into a permanent one.

**Recommended resolution, no amendment needed:** express it as **reversible
Zone configuration**, not as a held requirement. The player performs a setter
interaction that selects a state; the state persists until something sets it
back; the door in room B follows the state. This is a different puzzle from a
held one — the player is not pinned in room A — and it is the one the pinned
rules already support. It is also the honest one: a cross-room *held*
requirement means a player holding a lever in one room while watching a door in
another they cannot see.

**If a genuinely held cross-room requirement is wanted anyway**, the amendment
is specific: §19.7 rule 2 would need a bounded exception permitting a room
graph to write **one** designated macro variable, restricted to non-mandatory
relationships, with §30.6's tractability argument re-checked — because a
writable machine-graph variable is exactly what rule 2 exists to prevent.
**Not recommended, and named here so the choice is visible.**

---

## §5 The acceptance case

Per the owner: **Blindside's existing major and acquisition branch**, distinct
room IDs, through the **actual Zone composition/build/state path**. Not one
large standalone scenario divided into labelled areas — *"a reference fixture
is an intermediate test, not the final composition claim"*.

- **The central junction keeps its alignment control.** Preserved as-is; the
  railway is not replaced and D-4's contract is reused, not duplicated.
- **Elsewhere in the acquisition branch, one meaningful world interaction
  changes a mechanism or route in another room.** A macro setter in room X; a
  mechanism in room Y — a distinct room id — whose behaviour or the branch's
  route changes with it.
- **Finding the featured Echo in another room is necessary but not
  sufficient.** `Zone.featured_acquisition` (Dess, `96b6fdd`) gives the major
  its acquisition; it proves the *acquisition* binding and says nothing about
  shared puzzle state. The cross-room relationship is a separate claim with
  separate evidence.
- **Epsilon's choices stay meaningful:** which rooms hold the setter and the
  consumer, and how the declared relationship affects the branch. A single
  hardcoded arrangement is not cross-room composition and will not be reported
  as one.

### What Prod will prove, physically

Each of these is a different way of being wrong, so each is its own case:

1. **The source interaction is player-performed** — walked to, operated, not
   called into a handler.
2. **The remote physical consequence is real** — the mechanism in the other
   room moves, or the route through it changes, measured in that room.
3. **Safe return** — the player can get back; no interaction strands them.
4. **Partial-progress reload** — set the variable, leave, come back: the
   configuration is what it was, and the *unfinished* half is still unfinished.
5. **Completed-progress reload** — the finished relationship survives, and the
   permanent half stays permanent while the reversible half stays reversible.
6. **Local reset loses nothing unrelated** — resetting the consumer's room
   does not clear the setter's state or any other room's progress.
7. **No stale reference.** A rebuilt destination binds to the **variable id**,
   never to the setter's node. This is the concrete failure the owner named and
   it is an engine requirement: the consumer resolves its input by id at build
   time, so a source node that no longer exists cannot be held onto.

### And through the existing protections

Prerequisite guarantees and affected route conditions go through the AP /
progression machinery that already exists — `capability_guarantee`,
`reachability`, the declared-capability gates. **No self-locking acquisition
and no undeclared mandatory gate**: a mandatory cross-room relationship whose
setter sits behind its own consequence is the same defect `reachability` already
refuses for a featured acquisition, and it must be refused the same way.

---

## §6 What Prod is *not* doing until the contract is agreed

No macro schema, no field names, no generation constraints, no save
representation. Those are Dess's, and writing a parallel version is precisely
the "competing implementation" the owner ruled out.

What Prod *can* do without pre-empting anything, and is doing: this measurement
(§2), the two rule questions (§4), the acceptance-case design (§5), and keeping
the completion matrix honest about the fact that **cross-room puzzle support is
0.4 completion and is not started**.
