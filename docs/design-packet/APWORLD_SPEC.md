# Archipepsi — Archipelago / APWorld Specification


This is the authority for the Archipepsi APWorld, Archipelago-facing state, location/item semantics, scouting/checking behavior, currency delivery, shop interactions with real AP locations, and reconnection truth.

When this file says Archipelago owns a piece of truth, local generated content must not override it.


> **Authority note:** See `README.md` for conflict/precedence rules.


# 9. Archipepsi APWorld — POC specification

## 9.1 Game name

Exact game name:

`Archipepsi`

Internal package name:

`archipepsi`

No custom Archipepsi generation options are required for the first POC. Use Archipelago’s standard per-game common options.

`epsilon_creativity` is a **runtime Archipepsi game setting**, not an AP generation option.

---

## 9.2 Addressed locations

Exactly **30 addressed locations**.

Names and IDs:

```text
Archipepsi Check 001 -> 89_100_001
Archipepsi Check 002 -> 89_100_002
...
Archipepsi Check 030 -> 89_100_030
```

Python integer literals may use underscores.

Serialized JSON values are ordinary integers such as `89100001`.

---

## 9.3 AP regions and logic tiers

Create three logical Regions.

### `Start`

Contains Checks `001–010`.

Reachable immediately.

### `Tier 1`

Contains Checks `011–020`.

Entrance rule:

`state.has("Pepsi Key", player, 1)`

### `Tier 2`

Contains Checks `021–030`.

Entrance rule:

`state.has("Pepsi Key", player, 2)`

The Godot runtime mirrors this tier structure for deciding which unchecked locations are eligible to become generated content.

---

## 9.4 Native item definitions

Use exactly three addressed item names.

```text
Pepsi Key      -> 89_200_001
Epsilon Coin   -> 89_200_002
Epsilon Static -> 89_200_003
```

### Pepsi Key ×2

Classification:

`progression`

Behavior:

- 0 keys: Tier 0 / Start checks eligible
- 1 key: Start + Tier 1 eligible
- 2 keys: all 30 addressed checks eligible

Keys are monotonic and never spent.

### Epsilon Coin ×10

Classification:

`filler` for AP logic.

Behavior:

- delivered through normal `ReceivedItems`
- contributes to lifetime coins received
- can be spent only in Archipepsi’s local Hub shop
- spending is local persisted state
- coins are never removed from AP’s inventory history

### Epsilon Static ×18

Classification:

`filler`

POC gameplay effect:

none beyond a small receipt/notification if desired.

Total addressed pool:

`2 + 10 + 18 = 30`

---

## 9.5 Completion event

Create one **unaddressed** event location:

`Archipepsi Victory Event`

Place a locked event item:

`Victory`

with address/code `None`.

Put the Victory Event in Tier 2.

Set:

```python
multiworld.completion_condition[player] = lambda state: state.has("Victory", player)
```

This is the generator-side completion condition.

Runtime behavior remains:

- when **Archipepsi Check 030** is confirmed checked, the client sends goal status (`CLIENT_GOAL` / current equivalent)
- Check 030 is therefore the player-facing finish trigger

The POC does not require Checks 001–029 to all be completed first.

---

## 9.6 Slot data

Send only small client-required seed information.

Exact v0.2 shape:

```json
{
  "schema_version": 2,
  "location_ids": [
    89100001,
    89100002
  ],
  "tiers": {
    "0": [89100001],
    "1": [89100011],
    "2": [89100021]
  },
  "goal_location_id": 89100030,
  "item_names": {
    "pepsi_key": "Pepsi Key",
    "epsilon_coin": "Epsilon Coin"
  }
}
```

Actual arrays contain all appropriate IDs.

Do NOT put location→item placements in slot data.

The bridge obtains them with `LocationScouts`.

---

## 9.7 Recommended POC player YAML

Use a YAML equivalent to:

```yaml
name: Skyiah
game: Archipepsi

Archipepsi:
  accessibility: full
  progression_balancing: 50

  # The POC is specifically meant to demonstrate other players
  # finding our spendable currency.
  non_local_items:
    - Epsilon Coin
```

This deliberately forces Epsilon Coins outside the Archipepsi world when legal placement exists.

If testing Archipepsi alone with no other world, remove `non_local_items: Epsilon Coin` or use Mock Campaign instead.

Pepsi Keys are **not** forced non-local in v0.2; normal AP fill decides where they go.

---

## 9.8 Packaging

Support development as a normal world folder.

Support building:

`archipepsi.apworld`

The package should follow the current Archipelago `.apworld` conventions in the version used for development.


# 10. Archipelago runtime state

The bridge emits a **normalized snapshot** approximately equivalent to:

```json
{
  "connected": true,
  "race_mode": false,
  "seed_name": "ExampleSeed",
  "slot_name": "Skyiah",
  "slot_id": 6,
  "team": 0,
  "slot_game": "Archipepsi",

  "checked_locations": [],
  "missing_locations": [],

  "received_items": [
    {
      "ordinal": 0,
      "item_id": 89200001,
      "item_name": "Pepsi Key",
      "sender_player": 2,
      "sender_name": "Sage",
      "sender_game": "Ocarina of Time",
      "flags": 1
    }
  ],

  "scouted_locations": {
    "89100004": {
      "location_id": 89100004,
      "location_name": "Archipepsi Check 004",
      "item_id": 12345,
      "item_name": "Conference Call",
      "recipient_player": 1,
      "recipient_name": "BL2Player",
      "recipient_game": "Borderlands 2",
      "flags": 1
    }
  },

  "slot_data": {}
}
```

`ordinal` is the item’s position in the reconstructed `items_received` list. It is not a field received inside each `NetworkItem`.

The full normalized snapshot is preferred over a clever delta protocol for the POC. With only 30 locations/items, simplicity wins.


# 11. AP connection flow

Use this exact logical sequence.

1. User enters:
   - server
   - slot name
   - optional password
2. Godot sends `ap_connect_request` to bridge.
3. Bridge sets its `CommonContext` authentication fields and opens the AP connection.
4. Bridge uses:
   - `game = "Archipepsi"`
   - `items_handling = 0b111`
   - `want_slot_data = True`
5. AP handshake completes.
6. Bridge receives/maintains:
   - seed name
   - team
   - slot
   - slot info
   - slot data
   - checked locations
   - missing locations
   - received items
   - data-package lookups
7. Bridge determines race mode.
8. If race mode is true, abort Archipepsi gameplay with a clear unsupported message.
9. Bridge scouts all 30 Archipepsi locations with `create_as_hint = 0`.
   - Do this on **every successful AP connection/reconnection**.
   - Re-scouting the same 30 locations is intentional and safe.
   - This avoids depending on undocumented assumptions about whether a particular `CommonContext` version automatically re-sends custom scout requests.
10. Wait until all requested scout results are available.
11. Bridge normalizes current state.
12. Bridge emits `ap_state_snapshot`.
13. Godot derives Campaign identity from:
   - seed name
   - team
   - slot ID
14. Godot loads or creates the matching Campaign save.
15. Godot reconciles local transactions/generated content against server truth.
16. Game enters the Hub.

On reconnect:

- re-scout all 30 locations with `create_as_hint = 0`
- server `checked_locations` is authoritative
- bridge’s reconstructed `items_received` is authoritative
- pending local check transactions are resent if their locations are still missing
- local coin spending remains authoritative local history
- saved accepted Echo definitions remain canonical
- saved accepted Zone definitions remain canonical
- a confirmed foreign-item check missing its Echo definition is repaired by generating/falling back an Echo once


# 12. Godot ↔ bridge protocol

Every message is JSON.

All messages contain:

```json
{
  "type": "message_type"
}
```

## 12.1 Godot → bridge

### `ap_connect_request`

```json
{
  "type": "ap_connect_request",
  "server": "localhost:38281",
  "slot_name": "Skyiah",
  "password": ""
}
```

### `ap_disconnect_request`

```json
{
  "type": "ap_disconnect_request"
}
```

### `ap_check_location`

```json
{
  "type": "ap_check_location",
  "location_id": 89100004
}
```

### `ap_goal`

```json
{
  "type": "ap_goal"
}
```

### `epsilon_generate_zone`

```json
{
  "type": "epsilon_generate_zone",
  "request_id": "uuid",
  "payload": {}
}
```

### `epsilon_generate_echo`

```json
{
  "type": "epsilon_generate_echo",
  "request_id": "uuid",
  "payload": {}
}
```

---

## 12.2 Bridge → Godot

### `bridge_ready`

```json
{
  "type": "bridge_ready",
  "version": "0.1.0"
}
```

### `ap_connection_status`

```json
{
  "type": "ap_connection_status",
  "status": "connecting|connected|disconnected|error",
  "message": ""
}
```

### `ap_state_snapshot`

Contains normalized AP state.

### `ap_received_items_updated`

Contains either:

- full normalized received-item list, or
- safe delta with indexes

Full list is preferred for POC simplicity.

### `ap_location_checked`

```json
{
  "type": "ap_location_checked",
  "location_id": 89100004
}
```

### `epsilon_zone_result`

```json
{
  "type": "epsilon_zone_result",
  "request_id": "uuid",
  "ok": true,
  "data": {}
}
```

### `epsilon_echo_result`

Same pattern.

### `error`

```json
{
  "type": "error",
  "scope": "ap|epsilon|bridge",
  "recoverable": true,
  "message": "..."
}
```

---


# 27. Hub shop design

## 27.1 Purpose

The Hub shop gives the player an alternate way to clear some real unchecked Archipepsi locations using Epsilon Coins.

Buying stock:

- completes the corresponding AP location
- sends the real item to the real AP recipient
- creates a local Echo if the recipient is foreign

The shop never creates duplicate/new AP items.

---

## 27.2 Why shop locations must return to the normal pool

Archipelago does not know Archipepsi’s `coins_spent` state.

Therefore, no location can remain permanently shop-only.

If the player cannot or does not buy stock:

- the location eventually stops being shop-reserved
- it returns to the normal Zone candidate pool
- it can then be cleared through ordinary gameplay

Lack of local currency can therefore never make the AP seed unbeatable.

---

## 27.3 Shop transaction state machine

Purchases must survive crashes/reconnects and use the same persisted `pending_checks` ledger as Zone rewards.

States:

`AVAILABLE -> PENDING -> CONFIRMED`

When buying:

1. verify location is still server-missing
2. verify balance is sufficient
3. create the normal persisted `pending_check` record containing:
   - transaction ID
   - location ID
   - `source: "shop"`
   - `shop_cost`
4. immediately add `shop_cost` to persisted `coins_spent`
5. save
6. submit/queue the location check
7. once server reports location checked:
   - finalize the normal pending Check
   - remove shop reservation
   - create the foreign Echo
   - clear the pending Check
   - save

If connection drops after step 5:

- spent coins remain spent
- location check is resent on reconnect
- transaction finalizes when server confirms

If the server permanently rejects the location because it does not belong to this slot/current seed:

- rollback the pending Check once
- subtract its `shop_cost` from `coins_spent`
- release reservation
- display/log error

Duplicate `LocationChecks` are safe, so resending a persisted pending purchase is expected behavior.


# 28. Hub shop stock rules

POC stock size:

**2 locations**

Eligible stock must be:

- in an unlocked AP tier
- server-missing
- **recipient slot is not the Archipepsi slot**
- not assigned to current saved Zone
- not already reserved as shop stock

Deterministic price:

- progression-flagged item: **6 coins**
- useful-flagged item: **4 coins**
- trap/filler/other: **2 coins**

If multiple classification bits exist, use priority:

`progression > useful > trap/other`

The engine chooses stock.

Epsilon does not choose location IDs or prices.

Epsilon may generate only:

- a shop display name
- one short flavor sentence for each already-selected stock item

These text fields must never alter mechanics.


# 29. Shop cadence and reservation lifetime

Deterministic POC schedule:

- no shop stock before 2 Zones are completed
- after Zone 2, create 2-item stock if at least 2 eligible locations exist
- that stock remains available while the player plays the next Zone
- on completion of that next Zone:
  - purchased stock stays checked
  - unsold stock reservations are released
- every 2 completed Zones thereafter, create a fresh stock batch if possible

If only one eligible location exists, a one-item shop is allowed.

If zero eligible locations exist, shop displays `OUT OF QUESTIONABLE GOODS`.

Stock selection uses deterministic campaign PRNG and excludes current Zone assignments.


# 30. Coin rules

`Epsilon Coin` is a real Archipepsi AP item.

The recommended POC YAML forces it non-local, so other players find the coins and normal Archipelago delivery sends them back to Archipepsi.

Local economy:

```text
coins_received =
count("Epsilon Coin" in reconstructed authoritative AP items_received)

coins_spent =
persisted sum of confirmed + pending shop purchase costs

coins_available =
max(0, coins_received - coins_spent)
```

Never store `coins_available` as authoritative.

Never increment `coins_received` from a callback counter.

Recompute from the authoritative reconstructed list.

If reconnect temporarily reports fewer coins than local spending history:

- keep spending history
- clamp available balance to zero
- log a synchronization warning
- do not erase purchases


# 37. Check completion transaction

Every Check uses a persisted state machine:

`UNCLAIMED -> PENDING -> CONFIRMED`

A reward object is only interactable after its chamber objective is satisfied.

## Claim flow

1. Verify Check is not already server-confirmed.
2. Persist a `pending_check` record containing:
   - transaction ID
   - location ID
   - source type: `zone` or `shop`
   - shop cost if applicable
3. Save before network send.
4. Ask bridge to send the location check.
5. Reward UI enters `SENDING...`.
6. When bridge snapshot/update shows location in server `checked_locations`:
   - transition to CONFIRMED
   - remove pending check
   - reveal real item + recipient
   - generate/fallback Echo if recipient is foreign and Echo does not exist
   - disable reward
   - save

## Reconnect

On reconnect:

For every persisted pending check:

- if server already says checked: finalize it
- otherwise: resend it

Duplicate `LocationChecks` are expected and safe.

## Offline behavior

The player may finish the chamber objective while AP is disconnected.

The final reward interaction displays:

`ARCHIPELAGO OFFLINE — RECONNECT TO SEND THIS CHECK`

Do not create a new pending transaction until the bridge is connected.

If connection drops after the transaction was persisted, keep it pending and recover on reconnect.

This avoids implementing a broader offline item-sending mode while still handling mid-transaction failure safely.


# 40. Save system

Campaign identity key:

```text
sha256(seed_name + "|" + team + "|" + slot_id)
```

Friendly filename may additionally include sanitized slot name.

Conceptual path:

```text
user://saves/<campaign_hash>__<sanitized_slot>.json
```

Save schema version required.

Example:

```json
{
  "save_version": 2,

  "campaign_identity": {
    "seed_name": "ExampleSeed",
    "team": 0,
    "slot_id": 6,
    "slot_name": "Skyiah"
  },

  "track_order": ["Dark Souls III", "Ocarina of Time"],
  "track_cursor": 0,
  "generation_counter": 3,

  "coins_spent": 6,

  "pending_checks": [
    {
      "transaction_id": "uuid",
      "location_id": 89100018,
      "source": "shop",
      "shop_cost": 6
    }
  ],

  "echoes": {
    "echo_89100004": {}
  },
  "equipped_echo_id": "echo_89100004",

  "zones": {
    "zone_001": {}
  },
  "active_zone_id": "zone_003",
  "zone_history": [],

  "shop": {
    "stock_created_after_zone_count": 2,
    "reserved_location_ids": [89100018, 89100019]
  }
}
```

Do not persist a second “authoritative” copy of AP received items or checked state and trust it over the server.

The save owns:

- generated Zones
- generated Echoes
- equipment choice
- local spending
- pending local transactions
- deterministic campaign allocation state
- shop reservations

The AP server owns:

- checked locations
- missing locations
- delivered items


# 41. Reconciliation on load

After AP connection and full scout/state snapshot:

## 41.1 Identity

Verify save:

- seed name
- team
- slot ID

If any differ, do not load that Campaign save as the current run.

---

## 41.2 Pending checks

For each saved pending check:

- if server says checked: finalize
- if server says missing: resend when connected

For shop pending checks, `coins_spent` already includes their cost.

---

## 41.3 Confirmed server checks

If server says a foreign-recipient location is checked and no Echo exists:

- generate/fallback Echo
- save it

If a saved Zone contains that location:

- its reward appears completed/disabled

---

## 41.4 Received items

Recompute from bridge’s full reconstructed `items_received` list:

- Pepsi Key count
- total Epsilon Coins received

Do not apply callback increments.

---

## 41.5 Shop

For every saved reserved shop location:

- if server checked: remove reservation and finalize any matching pending transaction
- if still missing and unlocked: keep reservation
- if no longer valid for the current seed: release it and log error

---

## 41.6 Zones

Never regenerate an accepted saved Zone merely because Epsilon would answer differently today.

If every Check in a saved active Zone is already server-confirmed, treat the Zone as complete.


# 42. Canonical generated data

Once accepted:

- Zone JSON is saved.
- Echo JSON is saved.

That saved JSON becomes canonical for that Campaign.

Model nondeterminism after the first response does not matter.

Do not regenerate accepted content on every launch.

---


# 52. Game progression pacing

POC pacing is intentionally simple.

- Start with Tier 0 pool.
- Archipelago delivers Pepsi Key(s) from wherever normal fill placed them; they may be local or in another player's world.
- Receiving one Pepsi Key unlocks Tier 1.
- Receiving the second Pepsi Key unlocks Tier 2.
- Check 030 is the goal check.
- Other-player progress can therefore directly expand Archipepsi’s available campaign whenever a Pepsi Key lands remotely.

This demonstrates normal Archipelago interdependence.

---


# 53. Native progression vs Echo progression

There are two systems.

## Native AP progression

- Pepsi Keys
- understood by AP logic
- determines formal location tiers

## Emergent Echo progression

- generated from foreign items
- not real AP items
- understood by Archipepsi runtime
- may influence future generated content
- never retroactively changes AP seed logic

Both systems coexist.

---


# 70. Authoritative external technical assumptions

This design relies on current Archipelago/Godot behavior.

Important verified assumptions for v0.2:

- Archipelago APWorlds are Python integrations.
- `fill_slot_data` should contain only necessary small client data; location placement pairs should be obtained by scouting.
- `LocationScouts` retrieves the item in requested locations.
- `LocationScouts.create_as_hint` can create persistent hints when non-zero, therefore Archipepsi automatic scouting uses **0**.
- `LocationChecks` may safely contain duplicate already-sent checks.
- `ReceivedItems.index == 0` represents a full inventory replacement/resync.
- `Connected` provides checked/missing locations, slot data, and `slot_info`.
- item IDs must be interpreted in the correct game/slot context.
- `items_handling = 0b111` requests remote items, own-world items, and starting inventory.
- current Archipelago `CommonContext` already maintains checked/missing locations, received items, scouted location info, data-package lookups, and reconnect support and should be reused where compatible.
- generic `non_local_items` can force specified player items outside their own world.
- `.apworld` packaging is supported for third-party worlds.
- Godot can connect to a local WebSocket bridge and instantiate normal 3D scenes/primitive meshes at runtime without an engine fork.

Implementation must check concrete APIs against the exact Archipelago/Godot versions installed on the development machine instead of copying stale example signatures blindly.

Primary references:

- Archipelago World API  
  https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/world%20api.md
- Archipelago Options API  
  https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/options%20api.md
- Archipelago Network Protocol  
  https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md
- Archipelago CommonClient  
  https://github.com/ArchipelagoMW/Archipelago/blob/main/CommonClient.py
- Archipelago APWorld Specification  
  https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/apworld%20specification.md
- Godot WebSocket documentation  
  https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html
