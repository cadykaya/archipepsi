# D-9 — consumable expenditure across two different boundaries

**Dess → Prod.** A proposal, not a landed contract. The bridge half is
written and tested; the client half is yours and unwritten. The owner's
instruction is *"agree one approach rather than independently building
competing halves"*, so this says exactly what I built, why, what it
asks of the client, and which parts I will move if you prefer a
different shape.

Everything named here lives in files this lane owns —
`schemas/protocol.py`, `schemas/transitions.py`, `campaign.py`,
`server.py`. Nothing in `godot/` has been touched.

---

## 1. The two boundaries are not the same boundary

A dropped socket and a dead process fail differently, and a mechanism
that closes one can look like it closes both.

| | what survives | what the client still holds |
| --- | --- | --- |
| **socket reconnect** | the client process, and its in-memory pending list | everything: it knows which effects it launched |
| **fresh client process** | only the save file | nothing — the list is gone with the process |

Retaining and retransmitting `_in_flight` closes the first completely.
It cannot close the second, because after a relaunch there is no list to
retransmit and no way for the new process to learn what the old one did.

The owner's case is the second one: *launch, lose the expenditure
report, terminate Godot, relaunch the same unrefilled deployment, and
verify the supply cannot be reused.* A bridge that learns about
expenditure only from a report still believes that charge is there.

## 2. The proposal: authorize before the irreversible effect

The charge moves **at authorize time**, before anything irreversible
happens, and reaches the disk there.

```
client                          bridge
  press ───── authorize_consumable ──▶  spent += 1, authorization recorded, SAVED
        ◀──── snapshot (charges_left already reduced)
  launch the effect
        ───── use_consumable ───────▶  settles the authorization; spends nothing more
```

Cancelling a press that never launched:

```
  press ───── authorize_consumable ──▶  spent += 1
  (cooldown; player releases / weapon swap / no launch)
        ───── release_consumable_authorization ──▶  spent -= 1
```

**The record is keyed by `(component_id, generation, use_index)`** —
the same compare-and-swap trio `use_consumable` already checks. No new
convention, no opaque id to mint or lose, and two presses inside one
cooldown are two records rather than one overwritten one.

`ConsumableAuthorization` does **not** subtract a second time. An
authorization has already moved `spent`; the record exists only so an
unlaunched attempt can be cancelled.

## 3. What this costs, stated rather than discovered

**A crash between authorize and launch burns the charge.** That is the
conservative direction — a lost report can forfeit a charge and can
never duplicate one — and it is the price of authorizing first. If you
would rather not pay it, the alternative is a durable
allowance/reconciliation scheme, and that is a different proposal we
should agree before either of us builds it.

**A release is a claim only the launching process can make.** Whether
the effect launched is known to that process and nowhere else, so the
bridge takes the claim at its word. What it enforces is that the
attempt being cancelled is the **newest** one, which is also what makes
a release from a just-relaunched client harmless: by the time such a
client has pressed anything, the index it could name is no longer the
newest.

**The snapshot deliberately does not mirror the authorizations.** A
fresh client is handed the reduced `charges_left` and nothing it could
release, because it cannot know what the dead process did. That is a
decision, not an omission, and there is a test on it.

## 4. What the bridge now offers

| | |
| --- | --- |
| `authorize_consumable` intent | `component_id`, `use_index`, `generation` |
| `release_consumable_authorization` intent | same trio |
| `CampaignSave.consumable_authorizations` | persisted, cleared by a refill |
| `spend_charge` | settles a matching authorization instead of charging again |

Both intents carry `about` on refusal, the same key as a spend, so an
authorization you cannot attribute is never one you can never release.

## 5. What it asks of the client

1. On press: send `authorize_consumable` and **wait for the snapshot**
   before launching anything irreversible.
2. On a launch that does not happen: send
   `release_consumable_authorization` for that exact index.
3. On launch: `use_consumable` as today, unchanged.
4. Keep `_in_flight` — it is still the right place for *did I launch
   this*, and it is now backed by a durable count rather than being the
   only record. This composes with what you built; it does not replace
   it.

## 6. Ordering bug found while writing it

`spend_charge` checks generation, then count, then "is this the next
index due". An authorization has already moved `spent` past its own
index, so the index check refused the very report it was waiting for and
the settle branch was unreachable. The settle now runs after the
generation check and before the index check — stale is still reported as
stale, and a report for an authorized use is still settled. There is a
test asserting that order.

## 7. What is NOT proven

The process-lifetime property is proven **for the bridge**, across a
real process boundary: authorize, write the save, let the interpreter
exit, and a new `python3` that has never held any of those objects finds
the charge already gone and spends the *next* one instead of reusing it.

It is **not** proven end to end. The client does not call `authorize`
yet, so today's live path still launches first and reports after. Until
your half lands, the boundary is open in the running game whatever this
file's tests say. One obligation, two owners.

## 8. If you want a different shape

Say so and I will move the bridge half. The parts I would expect to
change are the choice to burn on crash (§3), and whether the snapshot
mirrors outstanding authorizations (§3). The parts I would argue to
keep are the `(component, generation, use_index)` key (§2), because it
is the identity the design already uses and it is what makes two
presses in one cooldown two records, and the settle-before-index
ordering (§6), because that one is a bug fix rather than a preference.
