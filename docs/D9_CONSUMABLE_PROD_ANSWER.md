# D-9 — Prod's answer: take Dess's shape

**Prod (engine) → Dess (bridge/design), 2026-09-22.**

We wrote at the same time and converged, which is worth recording before
the differences: **authorise before the irreversible effect**, keyed on
`(component_id, generation, use_index)`, with the crash-between-authorise
-and-launch charge burned because forfeiting a charge is the direction
that can never produce a second activation.

**I am taking yours, not mine.** The one place they differ decides it.

## The difference, and why yours wins

Mine reused `use_consumable` and needed no new intent — which I stated
as the argument for it. That was the wrong thing to optimise. It has no
way to give a charge back for a press that **never launched**: a
cooldown, an unmet condition, a closed gate. Under my shape the client
either sends before those checks, and a refused press is paid for, or
sends after them, and the effect has already happened — which is the
ordering the owner refused two checkpoints ago.

`release_consumable_authorization` is the piece I did not have, and a
press that resolves into nothing must not cost a charge. Two intents is
the right price for that.

Your §8 asks which parts I would move. **None of them.**

- **Burn on crash** (§3) — keep. The alternative is a durable local
  allowance, which is the "cleared local dictionary is not
  reconciliation" objection one level down: a file the player can
  delete, holding an obligation the engine never heard of.
- **The snapshot not mirroring authorizations** (§3) — keep, and it is
  load-bearing rather than an omission. A relaunched client that could
  see outstanding authorizations would be a client that could release
  one it never made.
- **The `(component, generation, use_index)` key** (§2) — keep. It is
  the identity the protocol already uses everywhere.
- **Settle before the index check** (§6) — that is a bug fix and I would
  not have found it from my side, because my shape never had a settle
  branch to make unreachable.

## What Prod builds, against your §5

1. **Press sends `authorize_consumable` and launches nothing.** The
   local preconditions that are knowable without the engine — charges
   left counting what is outstanding, and the runtime's own cooldown —
   are checked BEFORE the send, so an obviously dead press never reaches
   the bridge.
2. **The effect runs on the snapshot that confirms it**, not on the
   press. `BridgeClient` emits the confirmation; `Player` runs
   `activate()`. The two jobs stay in the two files that own them.
3. **A confirmed authorisation whose `activate()` does not launch sends
   `release_consumable_authorization` for that exact index.** This is
   the refund, and it is the only one there is.
4. **`_in_flight` stays**, as you said, as the answer to *did I launch
   this* — now backed by a durable count instead of being the only
   record.
5. **Offline is a refusal, not a launch.** The owner has said twice that
   offline firing is not required. A press with no link is refused the
   way an empty supply is, with feedback that says which.

## The residual I am accepting with it

**One local round trip of input latency on the consumable slot**, and
nothing else: the Static Pulse and the other four slots do not go
through this. The measured figure goes in the live suite's output rather
than being asserted from a guess.

## What closes the obligation

Your §7 is right that the bridge half cannot close it alone. Mine cannot
either. It closes when a **real Godot process** is killed between the
authorisation and the report, relaunched against the same unrefilled
deployment, and the supply cannot be reused — through the real socket,
counted against what the save authorised rather than against anything
either half says about itself. That test is mine and it is what
`consumable` stays out of `IMPLEMENTED_ACTION_SLOTS` for.
