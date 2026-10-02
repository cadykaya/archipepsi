# D-10 — the signal chain on a route, and what it may ask of a player

**Dess → Prod.** You named this half in `5124695`: *"Putting a graph on
the route needs the declaration to carry the gate, and that is a schema
change with Dess's half in it."* Here it is, with a finding that decides
which gameplay consequence the implemented chain can actually have.

Bridge files only — `schemas/graph.py`, `schemas/signal_graph.py`,
`schemas/zone.py`, `schemas/physics.py`. Nothing under `godot/` is
touched, and the regenerated `played_zone.json` gained one field
(`"opened_by": null`, thirty times) and changed nothing else.

---

## 1. The gate is on the EDGE

`TopologyEdge.opened_by` names the room-graph actuator that opens it.
Not the other way round: reachability reads edges, and an actuator that
claimed an edge the edge did not know about would be a physical gate the
AP logic never declared — `SOLUTIONS_CATALOGUE` §0-bis's one
prohibition — invisible to every route search. The Zone validator ties
the two ends so neither can exist alone.

**It is not a third kind of gate for reachability to learn.** A machine
in a room is operable from inside that room, so it imposes no ordering
on the multiworld — *unless operating it needs something*, and then that
something is the edge's ordinary `capability` and the search already
knows how to read it.

## 2. What the plate may ask of the player

A `PRESSURE_PLATE` reads a semantic class (§20.6), so whether the base
kit can load one is arithmetic:

- The player's own body is **80 kg = MEDIUM** (Design 2 §6.1, §10.2).
- §10.3 caps ordinary pickup at **60 kg**, which is also `MEDIUM`.

So a carried object reaches no further up the ladder than the player
standing on the plate already does. `LIGHT` and `MEDIUM` are base kit.
**`HEAVY` starts at 120 kg**: it needs a pushed object, which needs a
qualified manipulation provider — and `graph.Capability` deliberately
cannot name `manipulate`.

The chain as declared today uses a **HEAVY** plate, so **it may not gate
a route**, and the refusal says exactly that rather than inventing a
prerequisite to write it down. The same chain remains perfectly legal as
a machine in a room; it is the route that is refused, not the machine.

The ladder and `PLAYER_MASS_KG` now live in `physics.py` and are
exported. `mass_class.gd` still transcribes §10.2 by hand — **your
file**, and pointing it at `Constants` would remove the last hand copy.

## 3. The finding that decides the consequence

With the supported vocabulary — `PRESSURE_PLATE` and `NOT` — every
sensor rests FALSE, so an actuator's resting value is decided by how
many inversions stand between them. `resting_output()` counts them.

- **`plate → NOT → shutter`** rests **OPEN**. Loading the plate CLOSES
  the shutter.
- **`plate → shutter`** rests **CLOSED**. The player must stand on the
  plate to open the door and then walk through it, which is not one
  action — that is D-8 §11.2's **held cross-room requirement** wearing a
  room graph, and it is UNSUPPORTED. The validator refuses it and says
  so.

**Therefore: the implemented chain can only DENY a route, never open
one.** Denying one strands nobody — the player can simply not load the
plate — so it is safe, and it is also a weak puzzle: it imposes no
constraint a route search would ever notice.

Opening a route needs a value that **stays** after the player steps off,
and §19.2 already names it: **`LATCH`**. Nothing implements it.

## 4. So, the selected consequence — two candidates

**A. Denial, shippable today.** A `MEDIUM` plate whose `NOT` chain
closes a shutter across a side route. Base kit, no new node, no
reachability consequence. Honest, small, and it does not make the chain
part of progression.

**B. A real key, and it needs `LATCH`.** `plate → LATCH → shutter`: step
on it once, the latch holds, the shutter stays open, the player walks
through. This is the puzzle worth having, and it is one node away. §19.7
already puts latches in the room layer, and §5.6 step 5 already restores
them, so the persistence question is answered before we start.

I would rather build B than ship A and call P14 done. If you agree, the
bounded next slice is `LATCH` in `SUPPORTED_NODE_KINDS` plus its
evaluation and its save/restore — my half is the node's semantics,
declaration-order proof and the resting-value rule; yours is the runtime
and the restore. Say which you want and I will do my half of it.

## 5. What is not done

Nothing here is played. The gate is declarable and validated; no room
has one, no route depends on one, and `RoomGraphs.build` has not been
asked to honour `opened_by`. **A moving standalone shutter is still
where the runtime is**, which is what the owner said it was.
