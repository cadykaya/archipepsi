# D-9 — One charge, one activation, across a process boundary

**Prod (engine) → Dess (bridge/design), 2026-09-22.**

Owner, this checkpoint: *"Retaining/retransmitting the in-memory list
closes socket reconnect, not automatically a fresh client process. Close
that boundary through the chosen bounded accounting mechanism. Offline
firing is not required."* And, to Dess: *"Agree one approach rather than
independently building competing halves."*

So this names **one** approach, says exactly what it needs from the
bridge, and says what it costs. It is not a schema proposal and it does
not ask for one.

---

## §0 Ownership

| | |
|---|---|
| **Prod** | `godot/scripts/autoload/bridge_client.gd`, `godot/scripts/gameplay/player.gd`, the Godot suites, the termination/relaunch test |
| **Dess** | `schemas/transitions.py`, `schemas/protocol.py`, `campaign.py`, the Python suites |
| **Shared obligation** | the bridge's authoritative expenditure and the client's pending operations are one mechanism with two files |

---

## §1 The hole, stated exactly

`spend_charge` is a compare-and-swap on `(generation, use_index)`. That
is sound and nothing here changes it. What is not closed is an
expenditure the **engine never heard about**, in a client that then
dies:

1. The player presses. The effect runs.
2. `use_consumable` is sent and does not arrive — the socket dropped
   mid-write, or the process was killed between the launch and the send.
3. Godot is terminated. `_in_flight` was in memory; it goes with it.
4. Godot is relaunched against the **same, unrefilled** deployment. The
   engine's `spent` is still 0, so the client mints use 1 again.

**One charge has bought two activations.** Retransmission on reconnect
closes step 2 for a socket that comes back inside one process; it cannot
close step 3, because there is no process left to retransmit from.

---

## §2 The approach: authorise before the irreversible effect

The press does not launch. It **asks**, and launches on the answer.

```
press  ->  reserve locally (bounds a second press on the same charge)
       ->  send use_consumable(component, generation, index)
       ->  the engine applies the CAS and broadcasts a snapshot
       ->  the client sees spent >= index under the same generation
       ->  THE EFFECT RUNS
```

and the three ways it does not run:

- **refused** — a `BridgeError` whose `about` is the exact
  `use_consumable:<c>:<g>:<i>` triple. No effect, no cooldown, the
  reservation is released, and the player is told.
- **offline, or the send fails** — the same refusal, locally. *Offline
  firing is not a requirement*, twice stated by the owner, and that is
  the permission this whole approach rests on.
- **no answer at all** — the reservation stays held, so the charge is
  not spendable again in this process, and **no effect has run**. The
  next snapshot resolves it either way, and a fresh process resolves it
  from the save.

### Why this closes §1

Step 1 and step 2 swap places. An expenditure the engine never heard
about is now an expenditure that **never happened**, so there is nothing
for step 3 to lose and nothing for step 4 to double. The only durable
record needed is the save's, and the save already survives termination,
relaunch and a fresh interpreter — which is the lifecycle P04 proves.

### What it costs, said plainly

- **One round trip of input latency on the consumable slot.** The bridge
  is on `127.0.0.1`; the measured figure goes in the live suite's output
  rather than being asserted from a guess.
- **A crash between the engine applying the spend and the client running
  the effect loses a charge.** That is the conservative direction: it can
  refuse an activation the player paid for, and it can never produce a
  second activation from one charge. The reverse trade is the defect.
- **The shot uses the aim at the instant it resolves**, not at the
  instant of the press. At local-socket latency this is under a frame,
  and it is the same property any wind-up already has.
- **Nothing else changes.** The Static Pulse and the other four slots do
  not go through this. "Do not redesign all combat networking" — this is
  the consumable slot and nothing else.

---

## §3 What this needs from the bridge: **nothing**

Stated as a finding rather than a request, because the answer is the
argument for the approach:

| needed | already there |
|---|---|
| a spend the engine accepts at most once | `transitions.spend_charge`, CAS on `(generation, use_index)` |
| the client learning it was accepted | `CampaignSnapshot.consumable_uses[…].spent`, broadcast after every apply |
| the client learning it was refused, and which one | `BridgeError.about`, the domain key |
| the supply's identity surviving a refill | `CampaignSave.consumable_generation`, mirrored on the snapshot |
| the expenditure surviving termination | `store.write_save`, before the in-memory assignment |

**No new intent, no new field, no save migration.** If the combined
suites turn up something this table is wrong about, that is the moment
to ask for bridge work — and it should be asked for with the failing
case attached rather than in advance.

## §4 What Prod builds

1. `press_slot` reordered: reserve, send, and launch only on
   confirmation. The reservation list stays — it is what stops a second
   press spending the same charge inside one round trip — but nothing in
   it is ever `launched` before the engine has counted it.
2. Zero-charge feedback, the equipped item at `0 / max`, and the current
   UI work all preserved; a press that cannot be authorised is refused
   the way an empty supply is, and says which.
3. The termination/relaunch case, end to end, with a **real** Godot
   process killed between the launch and the report: relaunch against the
   same unrefilled deployment and verify the supply cannot be reused.
4. `godot-consumable-live` keeps its disclosed limitation: it cannot
   reach the launch-then-lose-the-socket window, and
   `consumable_driver.gd` is where that property is held.

## §5 What stays staged

`IMPLEMENTED_ACTION_SLOTS` still does not advertise `consumable`, and the
baseline stays at four slots, until the combined path holds across the
process boundary. Promotion is its own commit with its own deliberate
regeneration.
