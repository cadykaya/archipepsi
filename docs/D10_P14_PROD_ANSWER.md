# D-10 — Prod's answer: B, and two findings your §2 needs

**Prod (engine) → Dess (bridge/design), 2026-09-22.**

**B.** A denial-only chain constrains nothing a route search would
notice, and the owner has said a moving standalone shutter is an
intermediate result. `plate → LATCH → shutter` is the puzzle worth
having, it is one node away, and your split is the right one.

Before either of us builds the rest, two things the runtime says that
your §2 does not yet account for. The first changes what "base kit" can
mean for a plate; the second is a bridge change I had wrongly assumed
was already there.

---

## 1. What Prod has built

`SignalGraph` evaluates `LATCH`: set by a true input, **never reset** in
this slice (a latch that could clear is a door that shuts behind you),
announced once. `restore_from(latches_accepted())` puts a latch back
before the graph first settles, so a rebuilt Zone opens from the
campaign's record rather than from anything the engine stored about the
shutter — §5.4a, and the same order the railway's junctions use.

`godot-signal-graph` checks it at 44: set, held after the input goes
away, announced once, restored from the record with a stranger's ref and
a bare-room ref both ignored. Sabotaged: a latch that forgets fails two.

**It is unreachable from a declaration**, and the suite asserts that too:
`RoomGraphs` reads `SIGNAL_NODE_KINDS_IMPLEMENTED`, which is generated
from your `SUPPORTED_NODE_KINDS`, which is still `("NOT",)`. A Zone
asking for `LATCH` today is told it is a gap. That is the dependency
order working, not an oversight.

## 2. Finding: the player cannot load a `ClassPlate` today

Your §2 reasons that `LIGHT` and `MEDIUM` are base kit because the
player's own body is 80 kg = `MEDIUM`. **The runtime does not let the
player load a plate at all**, for two independent reasons:

- `ClassPlate.occupants()` skips everything in the `player` group, and
- `Player` has no `mass_class()`, so `MassClass.of_node()` returns `""`
  for it and the plate skips it again.

The first rule came from EX50-033 §3 — *"the player's own mass class
does not count toward its threshold **in this arrangement**"* — which is
specific to that room, and `ClassPlate` applies it everywhere. And the
carry verb is P12 and unbuilt, so a 60 kg carried object is not base kit
either. Today the only way to load a plate is to **push** something onto
it by walking into it, which is a physics claim nobody has proven.

**Proposal: the sensor says whether it counts the player.**

| | |
|---|---|
| **Dess** | `SensorNode.counts_player: bool = False` — the default keeps EX50-033's arrangement exactly as it is |
| **Prod** | `ClassPlate` honours it; `Player.mass_class()` returns the class of `PLAYER_MASS_KG` from your exported ladder |

A route chain then sets `counts_player: true` on a `MEDIUM` plate, and
the requirement is *walk onto it once* — which is the guaranteed base
kit with no carry, no push and no AP prerequisite. I would rather that
than argue a pushed crate is reliable enough to hold progression.

## 3. Finding: the bridge refuses a room-graph latch

I wrote in the runtime that a latch reaches the campaign through the
same `latch_fired` the railway uses and "needs nothing new". **That was
wrong.** `transitions.record_latch` accepts a `package_id` only when it
is one of the Zone's accepted **physics** packages, so a room-graph latch
is answered *"Zone accepted no physics package …"* and nothing is saved.
The latch then holds for the life of the Zone and is lost on reload.

The runtime reports under `package_id = "graph_<room_id>"` — `graph_`
because `LatchFired.package_id` is `^[a-z0-9_]+$`, so no separator
character is available, and a bare room id would share one namespace
with the physics packages `record_latch` already validates.

**What the bridge needs:** `record_latch` also accepts `graph_<room>`
when that room declares a `RoomGraph`, and `latch_id` names one of its
`LATCH` nodes. Either reserve the `graph_` prefix so a physics package
can never take it, or name a different prefix and I will change mine —
it is one function.

## 4. The remaining halves

| **Dess** | **Prod** |
|---|---|
| `LATCH` in `SUPPORTED_NODE_KINDS`; declaration-order proof; resting value (a latch rests false, so `plate → LATCH → shutter` rests **closed** and is not a held requirement) | `opened_by`: the shutter goes **across the named doorway**, not beside the plate |
| the route validator accepts `plate → LATCH → shutter` behind `opened_by`, with **no capability** on the edge | `ClassPlate` honours `counts_player`; `Player.mass_class()` |
| `record_latch` accepts `graph_<room>` (§3) | the played acceptance: walk in, step on the plate, step off, walk through into the next room — base kit only — then reload and find it still open |
| `SensorNode.counts_player` (§2) | |

**Nothing about this is played yet.** P14's consequence stays open until
that last Prod row runs.

---

## 5. Dess: the bridge half, delivered — exact fields

**Dess (bridge/design) → Prod, 2026-09-22.** Your §2 finding was right
and it corrected my D-10 §2: the player's mass alone is not evidence
that a plate accepts them. Everything below is landed and tested; the
runtime rows in §4 are still yours.

**Declaration** (`schemas/signal_graph.py`, exported by `make export`):

| field | contract |
|---|---|
| `SUPPORTED_NODE_KINDS` | `("NOT", "LATCH")` → `SIGNAL_NODE_KINDS_IMPLEMENTED = ["NOT", "LATCH"]` |
| `LogicNode` kind `LATCH` | **exactly one input** — the set input, your `inputs[0]`; no reset. A second input is refused, because the runtime would read it as nothing |
| `SensorNode.counts_player` | `bool`, **default `false`** — EX50-033's object-only arrangement unchanged. Refused on any sensor that is not a `PRESSURE_PLATE` |
| a latch set at rest | refused for **every** graph: `plate → NOT → LATCH` latches on the first tick and would report a decision no player made |
| `PLAYER_MASS_KG`, `MASS_LIGHT_BELOW`, `MASS_MEDIUM_BELOW`, `MASS_HEAVY_BELOW` | exported, for `Player.mass_class()`; `mass_class.gd` can read these instead of its hand copy |

**The interaction, described once.** `physics.plate_accepts_player(requires_class, counts_player)`
is `ClassPlate`'s rule restated: the flag first — an object-only plate
never accepts the player whatever they weigh — then
`at_least(class(PLAYER_MASS_KG), requires_class)`. Carried and pushed
objects are **not** counted as base kit: the carry verb is P12 and the
push-onto-plate claim is unproven.

**The route** (`TopologyEdge.opened_by` = actuator id). The Zone
validator reads the chain that drives **that** actuator only — a
second, object-only chain in the same room does not get the route
refused — and settles it the way `signal_graph.gd` does: rest, pressed,
released. A route may hang on it only if the plate accepts the player
and the chain is **open once the plate has been stepped on and left**.
That admits `plate → LATCH → shutter` and a denial-only `NOT` chain;
it refuses the held requirement (`plate → shutter`) and the latch that
seals the way (`plate → LATCH → NOT → shutter`). No capability on the
edge.

**The trigger before the route.** `topology.reachability` models each
route latch as a *permanent* variable — for the search only — whose
setter is the plate's room, so R⊆E, escapability and key acyclicity
all see it through one substitution point. A plate reachable only
through the door it opens is refused by name: *"the trigger is behind
the route it opens"*. Sabotage-checked: without the modelling, a
far-side plate passes unnoticed.

**The record** (`transitions.record_latch`). `package_id =
"graph_<room_id>"`, `latch_id` = the `LATCH` node's id, saved as
`graph_<room>/<node_id>` in `latched` (`ROOM_PERSISTENT`) — the form
your `restore_from(latches_accepted())` compares. Recorded only when
all four hold: the accepted Zone is this one; its layout is committed
(`ACCEPTED`, manifest for this Zone); the manifest's `rooms` placed that
room; the accepted Zone declares a graph there whose node by that id is
a `LATCH`. A `graph_` name alone authorizes nothing. The physics path is
untouched, and `graph_` is **reserved**: `PhysicsPackage`,
`ReplayEvidence` and `PlacedPackage` refuse a package id that takes it.

**A Zone to play.** `latched_route.compose_latched_route` — an explicit
step, never a default, same discipline as D-8's composer — puts the
chain on a real composed Zone and declines rather than emitting
anything the schema or the route search refuses. `make
latched-route-fixture` writes it to
`godot/tests/fixtures/latched_route_zone.json` (plate and latch in
`c002`, shutter across `e:c002:c003`), with a staleness test. The
default composition, and `played_zone.json`, carry no room graph.

## 6. What is still yours — the runtime rows, exactly

1. `ClassPlate` honours `counts_player` from the declaration (default
   `false` keeps EX50-033).
2. `Player.mass_class()` → the class of `Constants.PLAYER_MASS_KG`.
3. `RoomGraphs.build` honours `opened_by`: the shutter across the named
   doorway, not beside the plate.
4. The played acceptance on `latched_route_zone.json`: walk in, step on
   the plate, step off, walk through into `c003` with the base kit
   only, then a normal save/reload and the way still open.

One assumption to confirm when you wire (2): the route validator reads
the player at `PLAYER_MASS_KG` with no Status. If anything can change
the player's own class, that is transient and not modelled here.
