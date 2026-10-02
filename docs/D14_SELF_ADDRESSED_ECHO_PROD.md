# D-14 — a local Echo from a self-addressed original (H-SELF-ECHO)

**Dess → Prod, 2026-09-24.** Closes the "no Echo at all" half of
historical B-1. Prod integrates, as D-01's row in
`09_CONTRACTS_AND_DECISIONS.md` assigns.

**Ruling:** D-01. A self-addressed original may also yield a local
Echo. The packet's accepted design puts it this way: "Checks release the
original to its assigned recipient. Epsilon studies it and makes a
separate local Echo."

**Standing rule applied:** no old-save migration or silent
compatibility change (§3).

---

## 1. The rule

A confirmed Check releases its original to its recipient through
Archipelago, once. In a campaign under this policy, Epsilon also makes a
local Echo from that original, **whoever the recipient is, the player
included.**

Until now only a foreign original minted an Echo. So a featured Check
holding the player's own Signal Key or coin handed over no Echo at all.

## 2. Two records from one Check, never one record twice

| | the original | the local Echo |
|---|---|---|
| owned by | Archipelago | the bridge's interpretation log |
| identity | its ReceivedItems index at the recipient | `echo_<location_id>`: the Check that released it |
| counted by | AP logic (Signal Keys, coins, received items) | the fold (components) |
| on reload | AP resends from its index; nothing is applied twice | persisted; never regenerated or rerolled |

**The id space does not change.** A location releases exactly one
original, so `echo_<location_id>` is already unique across self and
foreign.

**The Echo is never the item:**
- Nothing it contains is counted by AP logic. Echo components are local
  mechanics, and keys and coins are counted from ReceivedItems only.
- It is never sent to Archipelago and never added to `ap.received`.
- It is never stocked in the shop (§11.3 is unchanged).

So from one self-addressed Check the player gets two different things:
- the item itself, through AP, for example +1 Signal Key;
- a separate Echo, made by Epsilon from studying that item.

The Echo of a Signal Key is not a Signal Key.

**The request needs no new field.** `EchoSource.source_game` and
`recipient_name` are the player's own game and slot name, which is the
truth. The provider prompt still calls every item "foreign". That
wording belongs to the Epsilon lane and does not affect correctness.

## 3. The policy is fixed per campaign

**The field:** `CampaignSave.self_addressed_echoes: bool = False`.
- A save without the field loads as `False`: a **legacy campaign**.
- A new campaign is created with `True`.

**A legacy campaign keeps its behaviour for its whole life.** Its own
items are "Delivered to you", with no Echo at confirmation, on load or
in a later sweep. Nothing appears in an existing save because the code
changed.

**Why it is not retroactive.** Without the field, the backlog sweep
would mint an Echo for every past self-addressed Check on the first load
after the update. That silently changes an existing save.

Turning the policy on for a legacy campaign would have to be a visible
act the owner asks for. It is not part of this contract.

## 4. Grant, retry, reload: the foreign path, keyed by the Check

**Trigger.** Confirmation of the Check (`ap.checked`). Never the arrival
of the ReceivedItems entry, which can come earlier, later, or again on
reconnect.

**Grant.** `grant_echo(location_id)` lifts its `recipient_is_self`
filter when `save.self_addressed_echoes` is true. Everything else is
unchanged:
- one grant at a time (`_echo_lock`);
- the same request;
- validated generation, with the deterministic fallback;
- `append_interpretation`.

**Retry.** A failing provider falls back, as today. A repeated grant, a
second confirmation or a duplicate append returns the same Echo and
mints nothing. The save model itself refuses a duplicate id.

**Reload.**
- A confirmed Check whose Echo was never written (a crash before the
  append) is granted by the backlog sweep, once.
- An Echo that was written is never regenerated.
- The budget is the foreign one: interacted Checks now, others at most
  3 per load.

**Confirmation text.** "Delivered to you", then "EPSILON ECHO
ACQUIRED" with the Echo's name and description. The wording and
presentation are Prod's.

## 5. What this does not settle

- **B-2 / D-02, qualification.** An Echo studied from a Signal Key need
  not supply the featured function. Blindside still needs qualification
  and fallback (H-QUALIFY).
- **B-3 / D-03, pre-seed AP representation.**
- **Featured-Check selection.** It must still not be chosen by scouted
  recipient. With this rule it no longer needs to be for an Echo to
  exist.

## 6. Tests

**Already pinned** in `bridge/tests/test_self_echo_boundaries.py` (no
shared source). Each test fails under a sabotage:
- **No clone:** a sweep grant sends nothing and moves no AP state
  (received, keys, coins, checked, delivered).
- **One per Check:** grant, sweep and a duplicate append mint one Echo.
- **Legacy stays:** a save without the field never mints for its own
  item, at grant or in the sweep. Mock seed `MockSeed-3` puts one in the
  first Zone.

**Land with the integration:**
- **Self, new campaign:** one Echo `echo_<loc>`, and the original is
  counted exactly once.
- **Foreign:** unchanged.
- **Retry:** a failing provider gives the fallback under the same id.
- **Reload:** a crash before the append gives one grant on reload; a
  crash after it gives no reroll.
- **`test_full_loop.py`'s "ONE ECHO PER FOREIGN CHECK, AND NOT ONE PER
  CHECK"** becomes one Echo per Check for a new campaign. A legacy
  variant keeps one per foreign Check. The assertion encodes historical
  B-1, so changing it is this ruling, not a weakened test.

## 7. Who does what

**Dess, after W0.1: landed.**
- The protocol field, `CampaignSave.self_addressed_echoes`, default
  `False`.
- `make export`. It changed no generated file: the exported protocol
  schema describes client messages, not the save.

It is a no-op until creation sets it, and it is pinned by
`test_self_echo_boundaries.py`.

**Prod, in one commit:**
- creation sets `True`;
- the `grant_echo` and `echo_backlog_sweep` filter;
- the confirmation text;
- the reveal;
- the combined tests above.

**Epsilon lane:** the prompt wording for an original of this game.
