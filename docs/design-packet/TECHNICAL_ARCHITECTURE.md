# Archipepsi — Technical Architecture


This file defines process boundaries, local bridge transport, Archipelago client integration strategy, save/reconciliation behavior, transactional Check handling, provider failure behavior, security boundaries, logging, and external technical assumptions.


> **Authority note:** See `README.md` for conflict/precedence rules.


# 7. Technology decisions

## 7.1 Godot

Use stock Godot 4.x.

Use the already-installed compatible Godot version on the development machine rather than upgrading the engine merely for this POC.

Use GDScript.

Do not fork Godot.

Do not introduce C# or GDExtension unless a specific hard blocker is demonstrated and recorded.

---

## 7.2 Runtime bridge

**POC decision: use a small Python bridge process.**

Reasons:

- isolates Archipelago protocol handling from gameplay
- lets us reuse Archipelago’s own client infrastructure
- isolates model-provider code from gameplay
- prevents API keys from being embedded into exported Godot content
- makes reconnect/state logging easier
- gives the future local model a clean replacement boundary
- lets Godot remain a pure game client

The POC requires the developer to launch the bridge manually before starting the game.

Automatic bridge launching/bundling is future polish.

---

## 7.3 Godot ↔ bridge transport

Use a local WebSocket connection.

Default:

`ws://127.0.0.1:38290`

Godot is the WebSocket client.

The Python bridge is the local WebSocket server.

All bridge messages are single JSON objects with a required `"type"` field.

This local protocol is **not** the Archipelago protocol. The bridge translates between them.

---

## 7.4 Bridge ↔ Archipelago

**Preferred implementation: subclass/use Archipelago `CommonContext` and its normal server loop.**

Configure the context as:

```python
game = "Archipepsi"
items_handling = 0b111
want_slot_data = True
tags = {"AP"}
```

Do not write a second independent AP networking stack unless `CommonContext` proves genuinely unusable in the target environment.

Use `CommonContext`/current Archipelago helpers for:

- connection/authentication
- automatic reconnect
- data-package preparation/cache
- item/location name lookup
- `items_received`
- `missing_locations`
- `checked_locations`
- `locations_info`
- location check sending

For scouting, send:

```json
{
  "cmd": "LocationScouts",
  "locations": [/* all 30 Archipepsi location IDs */],
  "create_as_hint": 0
}
```

`create_as_hint` MUST remain zero for automatic campaign scouting.

The bridge resolves a scouted `NetworkItem` as follows:

1. `NetworkItem.location` identifies the Archipepsi location.
2. `NetworkItem.player` identifies the **recipient slot**.
3. `slot_info[recipient_slot].game` identifies the recipient game.
4. The data-package lookup for that recipient game resolves `NetworkItem.item` to the item name.
5. `NetworkItem.flags` becomes the normalized item classification bitfield.

Do not assume item IDs are globally meaningful without recipient-game context.

### ReceivedItems rule

The bridge exposes a full normalized item list to Godot.

If using `CommonContext`, derive it from `ctx.items_received`.

If raw packet handling is ever required:

- `ReceivedItems.index == 0` means replace the prior inventory with the supplied list.
- otherwise, the packet begins at the stated list index.
- each normalized item can be assigned a synthetic ordinal equal to its position in the reconstructed inventory list.

Do not increment coins from “an item event happened.” Always derive them from the reconstructed authoritative inventory.

### Race mode

After connection, inspect the current Archipelago race-mode state using the mechanism provided by the current Archipelago client/version (including the `_read_race_mode` data-storage value if that is the current mechanism).

If race mode is true:

- refuse to start Archipepsi gameplay
- show: `Archipepsi POC does not support race-mode rooms because it scouts its own location placements.`
- do not proceed with bulk scouting

---

## 7.5 Bridge ↔ Epsilon provider

Implement an interface conceptually equivalent to:

```python
class EpsilonProvider:
    async def generate_zone(self, request: ZoneGenerationRequest) -> dict:
        ...

    async def generate_echo(self, request: EchoGenerationRequest) -> dict:
        ...
```

Required providers:

1. `MockEpsilonProvider`
2. `ClaudeEpsilonProvider`
3. `FallbackEpsilonProvider`

Future:

4. `LocalEpsilonProvider`

The game never depends directly on a model name.

The Claude model ID is configuration, not architecture.

---

## 7.6 Model-call timing

POC generation is allowed to block behind a Hub loading/generation screen.

Do not implement background generation as a prerequisite.

Recommended behavior:

- show `EPSILON IS MAKING SOMETHING...`
- one primary generation attempt
- one repair attempt if validation fails
- then fallback
- provider timeout target: 60 seconds

The player must never become permanently stuck waiting for a model response.


# 8. Repository layout

Use this unless there is a compelling implementation reason not to.

```text
archipepsi/
├─ README.md
├─ DESIGN.md
├─ .gitignore
│
├─ godot/
│  ├─ project.godot
│  ├─ scenes/
│  │  ├─ main/
│  │  ├─ ui/
│  │  ├─ player/
│  │  ├─ enemies/
│  │  ├─ zone/
│  │  └─ props/
│  ├─ scripts/
│  │  ├─ autoload/
│  │  ├─ networking/
│  │  ├─ generation/
│  │  ├─ gameplay/
│  │  ├─ items/
│  │  ├─ enemies/
│  │  ├─ save/
│  │  └─ debug/
│  ├─ assets/
│  │  ├─ textures/
│  │  ├─ icons/
│  │  └─ audio/
│  └─ tests/
│
├─ bridge/
│  ├─ pyproject.toml
│  ├─ requirements.txt
│  ├─ archipepsi_bridge/
│  │  ├─ main.py
│  │  ├─ protocol.py
│  │  ├─ ap_client.py
│  │  ├─ session.py
│  │  ├─ schemas.py
│  │  ├─ validation.py
│  │  └─ epsilon/
│  │     ├─ base.py
│  │     ├─ mock.py
│  │     ├─ claude.py
│  │     ├─ fallback.py
│  │     └─ prompts/
│  └─ tests/
│
├─ apworld/
│  ├─ archipepsi/
│  │  ├─ __init__.py
│  │  ├─ items.py
│  │  ├─ locations.py
│  │  ├─ options.py
│  │  ├─ regions.py
│  │  └─ archipelago.json
│  └─ build_apworld.py
│
├─ schemas/
│  ├─ bridge_messages.schema.json
│  ├─ zone.schema.json
│  └─ echo.schema.json
│
└─ docs/
   ├─ PROTOCOL.md
   ├─ EPSILON_CONTRACT.md
   └─ TEST_PLAN.md
```

The coding agent may consolidate files for speed, but the logical boundaries must remain.

---


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


# 43. Generation failure handling

For each Zone or Echo request:

1. call configured Epsilon provider
2. parse returned object
3. schema + semantic validation
4. if invalid:
   - issue **one** repair request with concise validation errors
5. validate repaired result
6. if still invalid:
   - use deterministic fallback
7. save only normalized accepted data
8. log raw invalid output only in development logs
9. never crash gameplay due to malformed model output

Provider timeout target:

**60 seconds**

If provider errors/times out:

- skip repair
- use fallback
- show a subtle `EPSILON OFFLINE — FALLBACK USED` notification


# 46. Epsilon provider configuration

Do not hardcode a model ID into game logic.

Bridge environment/config:

```text
EPSILON_PROVIDER=claude
EPSILON_MODEL=<configured model id>
ANTHROPIC_API_KEY=<secret>
```

If the configured Claude/API key is absent:

- bridge starts
- AP features still work
- live Campaigns use the deterministic fallback provider
- Mock Campaign uses Mock Epsilon only when the player explicitly selected Mock Campaign
- log the provider downgrade clearly

Never commit API keys.

Never store API keys in Godot project files.

---


# 57. Debug tooling

Toggleable overlay shows:

- bridge connected?
- AP connected?
- race mode?
- seed / team / slot
- checked count / 30
- Pepsi Keys
- coins received
- coins spent
- coins available
- pending check count
- active Zone ID
- active Zone AP location IDs
- current Track / track cursor
- Echo count
- equipped Echo
- Epsilon provider
- last generation error

Development-only buttons/commands:

- AP resync
- print full normalized snapshot
- force fallback Zone
- simulate one Coin in Mock Campaign
- generate next Zone
- respawn
- return to Hub
- clear current Campaign save with explicit confirmation

Never expose a debug command that silently marks arbitrary real AP locations checked in normal/live mode.


# 58. Logging

Bridge logs:

- connection events
- AP packets at debug level
- normalization results
- scout resolution
- received-item index handling
- location checks
- provider request IDs
- validation failures
- fallback activation

Godot logs:

- bridge events
- save load/save
- Zone instantiation
- reward completion
- Echo creation/equip
- shop transactions

Do not log API keys/passwords.

---


# 59. Security boundaries

The model is untrusted data input.

Never:

- execute model-returned code
- use model output as a file path without sanitization
- use model output as a shell command
- allow arbitrary resource paths
- allow model to choose network destinations
- allow model to set API credentials
- allow arbitrary Godot class instantiation by string

All generated references must resolve through allowlisted catalogs.

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
