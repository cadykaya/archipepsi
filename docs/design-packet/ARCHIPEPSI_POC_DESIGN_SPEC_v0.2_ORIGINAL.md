# ARCHIPEPSI — Proof-of-Concept Design & Implementation Specification

**Document version:** 0.2 — Self-Audited Implementation Pass  
**Project codename:** Archipepsi  
**Game name for the POC:** Archipepsi  
**Status:** Ready for Skyiah + ChatGPT review; substantially hardened for autonomous implementation  
**Primary implementation target:** Godot 4.x + Python bridge + Archipelago APWorld  
**Prototype Epsilon backend:** Claude-compatible provider configured at runtime  
**Future backend:** Local model using the same provider contract

---

# 0. Purpose of this document

This document exists so a coding agent can build a complete playable vertical slice of Archipepsi without having to invent product decisions while coding.

The goal is not to describe every possible future feature. The goal is to freeze enough architecture, game rules, data contracts, failure behavior, and acceptance criteria that an implementation agent can work for a long uninterrupted stretch without repeatedly asking:

- What should this feature do?
- What do we call this?
- Is this progression or cosmetic?
- What happens if the model fails?
- What happens on reconnect?
- Can an AI-generated item be required?
- Can a shop item be progression?
- Who owns the truth: Archipelago, the game, or Epsilon?
- What is allowed to be generated?
- What absolutely must not be generated?

When this specification and the code disagree, **this specification wins unless a later decision document explicitly overrides it.**

## 0.1 Changes made by the v0.2 self-audit

The first draft was intentionally expansive. This pass removes several places where an autonomous coding agent could make an expensive or unsafe interpretation.

The major corrections are:

1. **Epsilon no longer allocates Archipelago locations.** Deterministic game code chooses the exact AP locations assigned to a Zone or Hub shop. Epsilon only designs presentation/gameplay around locations it is given.
2. **Shops are Hub-only in the POC.** There is no generated `shop` chamber.
3. **No critical path may hard-require an Echo in the POC.** Echoes can inspire combat, shortcuts, secrets, optional routes, and room shape, but every mandatory route is completable with base movement and the default attack.
4. **The generated layout is linear-template based.** Epsilon does not freely place arbitrary world geometry in v0.2. It chooses chamber templates and bounded parameters; Godot chains them together deterministically.
5. **The AP bridge should subclass/use Archipelago `CommonContext` rather than reimplementing the network protocol from scratch** when the current installed/source Archipelago version permits it.
6. **AP client item handling is explicitly `0b111`.** Archipepsi must receive remote items, own-world items, and starting inventory.
7. **Location scouting always uses `create_as_hint = 0`.** Archipepsi needs placement information but must not silently create player-visible hints.
8. **`ReceivedItems` is treated as an ordered authoritative list, not a set of event callbacks.** If using `CommonContext`, use its reconstructed `items_received`; if implementing raw protocol fallback, honor `ReceivedItems.index`, including the `index == 0` full-inventory reset rule.
9. **Location completion and shop purchases use persisted pending transactions.** This closes crash/reconnect holes that could otherwise create free purchases, lost checks, or duplicate Echoes.
10. **The first Echo vocabulary is smaller.** Fewer mechanics means a dramatically better chance of producing a real vertical slice during an autonomous coding session.
11. **The first enemy and objective catalogs are smaller.** Extra archetypes are deferred until the end-to-end loop works.
12. **Race-mode rooms are unsupported for the POC.** Archipepsi intentionally scouts its own location placements and should refuse to run in a room configured as a race rather than risk violating race expectations.
13. **A concrete player YAML is included.** The recommended POC YAML forces Epsilon Coins non-local so the intended “other players find my currency” loop is actually exercised.
14. **Generation happens behind a Hub/loading screen in the POC.** Background pre-generation is a future optimization, not a prerequisite.
15. **The campaign save key uses seed/team/slot identity, not only a display name.**

# 1. One-sentence pitch

**Archipepsi is an Archipelago game whose campaign is constructed during the multiworld by an AI “dungeon master” called Epsilon, using the actual randomized items in the player’s Archipelago locations as inspiration for levels, rewards, shops, and permanent local “Echo” abilities.**

---

# 2. The fantasy

Six players start an Archipelago multiworld:

1. Super Mario 64
2. Ocarina of Time
3. Bomb Rush Cyberfunk
4. Dark Souls III
5. Borderlands 2
6. Archipepsi

The Archipepsi player starts with no prebuilt campaign.

They enter:

- Archipelago server host/port
- slot name
- optional password

Archipepsi connects.

The Archipelago server already knows what is placed at Archipepsi’s locations. Archipepsi scouts those locations.

Epsilon receives information such as:

- Archipepsi Check 004 contains a Borderlands 2 item for Sage.
- Archipepsi Check 011 contains an Ocarina of Time item for another player.
- Archipepsi Check 019 contains an Archipepsi Coin for the Archipepsi player.
- Archipepsi Check 027 contains a Dark Souls III item.

Epsilon constructs a playable blocky first-person campaign from that information.

If the Archipepsi player completes a check that contains:

> Conference Call → Borderlands 2 player

then:

1. Archipepsi reports the normal location check to Archipelago.
2. Archipelago gives the real Conference Call to the Borderlands 2 player.
3. Archipepsi locally creates an **Echo** of the Conference Call for the Archipepsi player.
4. Epsilon decides what that Echo does using only mechanics supported by Archipepsi.
5. Future generated content knows the player owns that Echo and may incorporate it into level design.

The core fantasy is:

> **Every Archipelago seed creates a different game, and everyone else’s randomized item pool becomes Archipepsi’s mechanics and level-design vocabulary.**

---

# 3. Product principles

These are non-negotiable unless deliberately revised later.

## 3.1 Archipelago remains the authority on the multiworld

Archipelago owns:

- item placement
- location completion
- item delivery
- slot identity
- server reconnection truth
- native Archipepsi progression items

Archipepsi never edits the generated seed after generation.

Epsilon never invents real Archipelago items or real Archipelago locations at runtime.

---

## 3.2 Epsilon is a designer, not an unrestricted programmer

At runtime, Epsilon outputs **data**, never executable code.

Epsilon may:

- choose level themes
- choose supported chamber templates
- choose supported chamber templates and bounded parameters; deterministic Godot code arranges the actual geometry
- choose enemy archetypes
- design gameplay presentation around AP locations that deterministic Archipepsi code has already assigned to the current Zone
- invent names and descriptions
- combine supported item effects into Echoes
- choose parameters within validated limits
- account for permanent Echoes already owned by the player

Epsilon may NOT:

- emit GDScript and execute it
- emit Python and execute it
- load arbitrary DLLs
- shell out
- write arbitrary project files
- invent unsupported effect names and expect the engine to implement them
- alter Archipelago placement
- alter Archipelago logic after generation

Model output is always parsed, validated, clamped, and rejected if invalid.

---

## 3.3 The game must remain playable when Epsilon misbehaves

The runtime must have:

- schema validation
- parameter bounds
- generation retries
- a deterministic fallback zone generator
- a fallback Echo generator
- safe load/reconnect behavior

A bad AI response is not allowed to corrupt the save or permanently block the run.

---

## 3.4 Ugly is a feature for the POC

The POC deliberately uses:

- low-resolution textures
- primitive/block geometry
- flat/simple materials
- simple lighting
- simple enemy meshes
- minimal animation
- intentionally Minecraft-like readability

The POC does NOT attempt AI-generated 3D models, skeletal animation, generated shaders, or generated art pipelines.

The desired feeling is:

> “A local AI was handed a box of videogame Legos and told to make a game.”

---

## 3.5 Generated abilities are permanent and monotonic

Once an Echo is obtained, it stays obtained for the rest of that seed.

Echo abilities may have cooldowns or temporary duration.

The POC does not implement permanent consumables or persistent ammunition.

Echoes must not be permanently consumed or lost.

This is important because future generated content may account for owned Echoes.

---

# 4. POC definition of success

The POC is successful when the following end-to-end sequence works with a real Archipelago server:

1. Launch Archipepsi.
2. Enter AP server, slot name, and optional password.
3. Connect successfully.
4. Receive slot information.
5. Scout Archipepsi locations.
6. Resolve at least one scouted location to:
   - item name
   - recipient player
   - recipient game
   - item flags/classification where available
7. Send a small set of currently available location data to Epsilon.
8. Receive valid Zone JSON.
9. Instantiate a playable 3D zone in Godot.
10. Walk through the zone with a first-person controller.
11. Complete a challenge/check.
12. Send the Archipelago `LocationChecks` equivalent for that location.
13. The real recipient receives the real item.
14. If the recipient is another player, generate a local Echo of that item.
15. Equip/use the Echo in Archipepsi.
16. Generate a later zone whose design context includes that Echo.
17. Receive at least one Epsilon Coin from another player through normal Archipelago item delivery.
18. Spend Epsilon Coins in an Archipepsi shop.
19. Buying an eligible shop item:
    - completes its AP location
    - gives the real item to its AP recipient
    - grants an Echo locally if the recipient is another player
20. Quit and reload.
21. Reconnect without duplicating coins, Echoes, checks, or purchases.
22. Continue from saved campaign state.

If all 22 work, the central technical hypothesis is proven. The POC does **not** need Echo-gated mandatory traversal to prove the concept.

---

# 5. Explicit POC scope

## 5.1 Included

- stock Godot 4.x project
- GDScript
- small Python bridge
- Archipelago `CommonContext`-based client integration where compatible
- first-person movement
- mouse look
- jump
- interaction
- health
- simple combat
- **3** basic enemy archetypes
- simple respawn
- runtime scene construction from chamber templates
- 30 Archipepsi AP locations
- 2 native progression keys
- Epsilon Coins
- filler item
- 3 Archipepsi AP logic tiers
- real AP connection
- location scouting with `create_as_hint = 0`
- received items with `items_handling = 0b111`
- location checks
- AP reconnect handling
- persisted pending-check transactions
- Epsilon provider abstraction
- Claude-compatible prototype provider
- mock provider
- fallback generator
- Echo generation
- one-equipped-Echo inventory
- generated Zones
- fixed-Hub shop
- save/load
- debug overlay/logging
- one completion goal
- one packaged `.apworld` build path
- README with setup and run instructions
- example Archipepsi player YAML

## 5.2 Explicitly NOT included in POC

Do not spend core implementation time on:

- AI-generated textures
- AI-generated models
- AI-generated music
- AI-generated voice acting
- arbitrary runtime code generation
- arbitrary free-placement geometry from the model
- destructible voxel terrain
- seamless open world
- multiplayer inside Archipepsi
- networking Archipepsi players to each other
- elaborate NPC quest systems
- procedural story continuity beyond short text summaries
- perfect navigation/pathfinding
- advanced animation
- save cloud sync
- mobile support
- local Epsilon model
- model fine-tuning
- voice input
- Steam integration
- mod workshop
- final visual polish
- 250 checks
- more than one Archipepsi slot in the same test seed
- custom Godot fork
- GDExtension unless an unexpected hard blocker is found
- Echo-gated mandatory traversal
- generated shops inside Zones
- race-mode Archipelago rooms
- background/preemptive generation as a requirement

# 6. Terminology

Use these terms consistently in code and docs.

## Campaign

The entire Archipepsi experience for one Archipelago seed + Archipepsi slot.

A Campaign ends when that Archipepsi slot reaches its goal.

---

## Track

A thematic grouping of Archipepsi locations based primarily on the **game receiving the items** at those locations.

Examples:

- Super Mario 64 Track
- Ocarina of Time Track
- Borderlands 2 Track

Tracks are organizational/theme concepts. They are not Archipelago Regions.

---

## Zone

One loaded playable Archipepsi map.

POC target: normally 2–3 AP checks per Zone, target 3.

A Zone can contain:

- chambers
- enemies
- hazards
- challenge objectives
- rewards
- optional Echo-specific shortcut or challenge

---

## Chamber

A discrete spatial component inside a Zone.

Examples:

- arena
- corridor
- platform path
- tower
- treasure room

---

## Check

A real Archipelago location belonging to Archipepsi.

A Check is complete only after Archipepsi reports that location ID to the AP server.

---

## Native Item

A real item belonging to the Archipepsi APWorld.

Examples:

- Pepsi Key
- Epsilon Coin
- Epsilon Static

---

## Echo

A permanent **local-only Archipepsi interpretation** of a real item that the Archipepsi player sends to another Archipelago player.

An Echo is not a new AP item.

---

## Epsilon

The runtime generation role.

For the POC, Epsilon is provided by a Claude-compatible API backend.

Later it can be replaced by a local model without changing game semantics.

---

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

# 13. Campaign allocation policy

**Important ownership rule:** deterministic Archipepsi code allocates AP locations. Epsilon does not.

Epsilon receives a list of already-selected locations and designs a Zone around them.

## 13.1 Scout first, reveal selectively

The deterministic allocator has access to the full scouted location pool.

Epsilon receives only:

- the selected locations for the current Zone
- owned Echo summaries
- prior Zone summaries
- target-game/theme context

The player UI does not automatically expose every scouted item.

Items become explicitly visible to the player when:

- their Check is confirmed complete, or
- their location becomes current Hub shop stock

Before revelation, Epsilon may use recipient-game identity strongly for theme, but must not put exact unrevealed item names into display text.

---

## 13.2 Tracks

Group eligible unchecked locations by:

`recipient_game`

Examples:

- Borderlands 2 Track
- Ocarina of Time Track
- Dark Souls III Track

Locations whose recipient is the Archipepsi slot belong to:

`Archipepsi / Glitch Track`

Tracks are not AP Regions.

---

## 13.3 Deterministic Track order

At Campaign creation:

1. collect recipient-game names represented by the 30 scouted locations
2. sort them lexically
3. deterministically shuffle that list using a PRNG seeded from:
   `seed_name | team | slot_id | "track_order"`
4. save the resulting `track_order`

Zone generation round-robins through this saved order, skipping Tracks with no currently eligible locations.

This gives variety while remaining stable across reloads.

---

## 13.4 Zone location selection

Normal Zone size:

- target 3 checks
- minimum 2 if at least 2 eligible locations remain
- maximum 3 in v0.2
- a final Zone may contain 1 if only 1 eligible location remains

Selection algorithm:

1. Compute currently unlocked AP tiers from received Pepsi Keys.
2. Start with server-missing locations only.
3. Remove locations already assigned to the active saved Zone.
4. Remove locations reserved by current Hub shop stock.
5. Select next nonempty Track in round-robin order.
6. Deterministically shuffle that Track’s eligible IDs using:
   `seed_name | slot_id | generation_counter | target_game`
7. Take up to 3.
8. If the selected Track has only one location and at least one other eligible location exists, fill to at least 2 using the next Tracks in round-robin order.
9. Save the chosen location IDs **before** calling Epsilon.
10. Build `ZoneGenerationRequest`.
11. Call Epsilon.
12. Validate.
13. One repair attempt.
14. Fallback if still invalid.
15. Save accepted Zone JSON.
16. Load it.

Do not let Epsilon swap, add, delete, or reserve AP location IDs.

---

## 13.5 Generation timing

Generation occurs from the fixed Hub.

When the player requests the next Zone:

1. fade/show generation screen
2. allocate locations
3. ask Epsilon
4. validate/fallback
5. instantiate Zone
6. enter Zone

No background generation is required in the POC.

# 14. Generated Zone philosophy and layout contract

Epsilon should feel creative, but the engine should remain simple.

The POC uses a **linear chamber-template DSL**.

Epsilon chooses:

- target theme
- display name
- chamber sequence
- chamber parameters
- supported enemy archetypes
- supported objectives
- which already-supplied Check belongs to which chamber
- flavor text
- which owned Echoes it was inspired by

Epsilon does **not** choose world-space coordinates.

## 14.1 Chamber chaining

Every chamber constructor returns:

- an entrance transform
- an exit transform
- its generated collision/geometry bounds

The `ZoneBuilder` starts the first chamber at the origin and chains every later chamber to the prior exit, oriented generally along +Z.

The engine inserts a short connector doorway/corridor between chambers when needed.

The builder must guarantee:

- spawn is on walkable ground
- exits connect
- mandatory critical path never needs an Echo
- platform gaps stay within base jump limits
- no chamber intentionally overlaps another chamber
- Check reward objects are reachable after their objective is satisfied

This deliberately limits Epsilon’s freedom in exchange for a POC that can actually be validated.

# 15. POC chamber catalog

Only these chamber types are valid model output in v0.2.

## 15.1 `corridor`

Simple connector/traversal room.

Parameters:

- `length`: 6–30
- `width`: 4–10
- optional enemy list

No Check reward by default, though one may be placed at the exit if required by the selected location count.

---

## 15.2 `arena`

Rectangular combat room.

Parameters:

- `width`: 10–28
- `depth`: 10–28
- `wall_height`: 4–8
- enemy list
- objective: normally `kill_all`
- optional `reward_location_id`

A boss-like room is simply an `arena` containing one `brute`.

---

## 15.3 `platform_path`

Base-movement platforming room.

Parameters:

- `segment_count`: 3–8
- `gap_size`: clamped to safe base-jump range
- `vertical_step`: clamped to safe base-jump range
- optional enemy list
- objective: `platform_to_goal`
- optional `reward_location_id`

Owned mobility Echoes may make it easier or sillier, but are never mandatory.

---

## 15.4 `tower`

Vertical traversal chamber built from stairs/ramps/platforms.

Parameters:

- `floors`: 2–5
- optional enemy list
- objective: `reach_reward` or `kill_all`
- optional `reward_location_id`

The template itself guarantees a base-movement route.

---

## 15.5 `treasure_room`

Small safe reward room.

Parameters:

- optional flavor text
- exactly one `reward_location_id`

No enemies required.

---

## 15.6 Shop placement

`shop` is **not** a valid Zone chamber type in the POC.

All shop behavior occurs in the fixed Hub.

---

## 15.7 Boss placement

`arena` is **not** a separate chamber type in the POC.

Use an `arena` containing a single `brute`.

# 16. POC theme catalog

A theme is a validated palette, not generated art.

Implement at least:

- `grass_block`
- `stone_dungeon`
- `neon_city`
- `gothic_castle`
- `desert_scrap`
- `void_glitch`

Each theme defines:

- floor material
- wall material
- accent material
- sky/background
- light color/energy defaults if desired
- optional prop list

Target-game suggestions:

- Mario → `grass_block`
- Ocarina → `stone_dungeon`
- Bomb Rush Cyberfunk → `neon_city`
- Dark Souls → `gothic_castle`
- Borderlands → `desert_scrap`
- Archipepsi-native → `void_glitch`

Epsilon can deviate.

Use nearest-neighbor / pixel-friendly filtering for low-resolution texture assets.

---

# 17. Enemy catalog

Only three archetypes are required for the first autonomous implementation pass.

## 17.1 `melee`

- moves directly toward player
- short-range attack
- moderate speed
- low/moderate health

## 17.2 `ranged`

- stays still or uses extremely simple spacing behavior
- periodically fires a slow visible projectile
- low health

## 17.3 `brute`

- larger mesh/scale
- slow
- high health
- stronger melee attack
- used as POC boss

Do not block the POC on navmesh sophistication.

Direct steering plus collision recovery is acceptable.

If a generated room causes navigation problems, enemies may use simplified steering rather than requiring a perfect navigation bake.

# 18. Objective catalog

Only these mandatory objective types are required:

- `reach_reward`
- `kill_all`
- `platform_to_goal`

Rules:

### `reach_reward`

Reward becomes interactable immediately when reached.

### `kill_all`

Reward remains locked until all enemies registered to that chamber are dead.

### `platform_to_goal`

Reward becomes interactable when the player enters the goal/reward area.

Every Check must have one deterministic completion trigger.

No timed survival or switch puzzle is required in the first autonomous pass.

# 19. Zone JSON contract

This is model-facing normalized output.

The implementation must define an equivalent Pydantic model and JSON Schema.

Example:

```json
{
  "schema_version": 2,
  "zone_id": "zone_003",
  "display_name": "Cathedral of Excessive Firepower",
  "target_game": "Dark Souls III",
  "theme": "gothic_castle",
  "designer_note": "The wide arenas and vertical drops make the player's recoil-heavy shotgun fun without requiring it.",
  "featured_echo_ids": ["echo_89100004"],

  "chambers": [
    {
      "id": "c1",
      "type": "corridor",
      "length": 12.0,
      "width": 5.0,
      "enemies": []
    },
    {
      "id": "c2",
      "type": "arena",
      "width": 18.0,
      "depth": 18.0,
      "wall_height": 6.0,
      "objective": "kill_all",
      "enemies": [
        {
          "archetype": "melee",
          "count": 3
        }
      ],
      "reward_location_id": 89100012
    },
    {
      "id": "c3",
      "type": "tower",
      "floors": 3,
      "objective": "reach_reward",
      "enemies": [
        {
          "archetype": "ranged",
          "count": 2
        }
      ],
      "reward_location_id": 89100013
    }
  ]
}
```

There is intentionally **no `required_echo_ids` field in v0.2**.

# 20. Zone validation rules

Reject invalid output. Clamp only numeric values that are otherwise semantically valid.

## General

- `schema_version == 2`
- `zone_id` must exactly match request
- 1–6 chambers
- every requested AP location appears exactly once as `reward_location_id`
- no unrequested AP location appears
- no duplicate reward location IDs
- theme is allowlisted
- chamber type is allowlisted
- enemy archetype is allowlisted
- objective is allowlisted
- every `featured_echo_id` is already owned
- **no generated field can express a mandatory Echo requirement**

## Size / count limits

- corridor length: 6–30
- corridor width: 4–10
- arena width/depth: 10–28
- wall height: 4–8
- platform segments: 3–8
- platform gap: <= measured safe base-jump maximum
- tower floors: 2–5
- total enemies per Zone: <= 14
- total enemies in one chamber: <= 8
- brute count per Zone: <= 1
- text field length: <= 160 characters except `designer_note` <= 300

## Critical-path safety

The validator and template builders enforce:

- all mandatory platform gaps are base-jumpable
- tower template always has stairs/ramps/base platforms
- no Check is placed behind an Echo-only door
- no objective uses an unsupported puzzle state
- no shop or coin balance is part of Zone completion

If a model response implies otherwise in prose, prose is ignored; only validated structured fields affect gameplay.

# 21. Echo system

## 21.1 Grant rule

An Echo belongs to an **Archipepsi source location**, not merely an item name.

When a source location transitions to server-confirmed checked:

If its scouted recipient slot is **not** the Archipepsi slot:

1. AP has already/now sends the real item to the real recipient through normal server behavior.
2. Archipepsi checks for existing Echo with `source_location_id`.
3. If none exists, request Echo generation.
4. Validate once, repair once, fallback if needed.
5. Persist accepted Echo.
6. Add it to inventory.

If recipient slot **is** Archipepsi:

- no Echo is generated
- normal `ReceivedItems` handles the native Archipepsi item

Every Echo has:

`source_location_id`

This is the deduplication key.

Two different source locations containing identically named items can therefore produce two different Echoes.

---

## 21.2 Equipment rule

POC rule:

**Exactly one Echo is equipped at a time.**

All effects belonging to that Echo are active/usable according to its activation type.

There is no global stacking of passive effects from every collected Echo in v0.2.

This keeps balance and implementation understandable while still allowing unlimited Echo collection.

---

## 21.3 Echo identity

Example:

```json
{
  "schema_version": 2,
  "echo_id": "echo_89100004",
  "source_location_id": 89100004,
  "source_item_name": "Conference Call",
  "source_game": "Borderlands 2",
  "source_recipient_name": "Sage",

  "display_name": "Conference Call",
  "description": "A ridiculous shotgun interpretation with enough kick to double as movement.",

  "archetype": "weapon",
  "activation": "primary",

  "effects": [
    {
      "type": "hitscan_damage",
      "damage": 8.0,
      "pellets": 12,
      "spread_degrees": 10.0,
      "range": 35.0
    },
    {
      "type": "recoil_self",
      "force": 8.0
    },
    {
      "type": "knockback_target",
      "force": 5.0
    }
  ],

  "cooldown": 0.8,
  "tags": ["weapon", "shotgun", "recoil", "combat", "mobility"]
}
```

Accepted Echo JSON is canonical for that Campaign.

# 22. Echo archetypes and activation

POC archetypes:

- `weapon`
- `tool`
- `mobility`
- `passive`

POC activation values:

- `primary`
- `passive`

Rules:

- `primary`: pressing the primary Echo input attempts activation, subject to cooldown.
- `passive`: effects apply continuously while that Echo is the equipped Echo.
- an Echo may contain multiple compatible effects
- cooldown is defined at the Echo level
- no permanently consumable Echo exists

# 23. POC Echo effect vocabulary

Only these effect types are required in the first autonomous implementation pass.

## Active attack effects

### `hitscan_damage`

On activation:

- cast `pellets` ray(s) from camera aim
- random spread within `spread_degrees`
- damage first valid enemy hit per ray
- max distance `range`

Fields:

- `damage`
- `pellets`
- `spread_degrees`
- `range`

### `projectile_damage`

On activation:

- spawn a simple projectile from the player/camera
- travel forward
- damage first enemy hit
- despawn on hit or lifetime expiry

Fields:

- `damage`
- `speed`
- `lifetime`

---

## Active modifiers / motion

### `recoil_self`

On the same activation as an attack/tool:

- apply impulse to player opposite aim direction

Field:

- `force`

### `knockback_target`

Modifier for targets damaged by the same activation:

- apply force away from attack source

Field:

- `force`

### `dash`

On activation:

- impulse player mostly along view-forward direction
- no stamina

Field:

- `force`

### `grapple_to_surface`

On activation:

- raycast to static world geometry within range
- if hit, apply a strong pull/impulse toward hit point
- no rope simulation required

Fields:

- `range`
- `pull_force`

### `heal_self`

On activation:

- restore HP up to max

Field:

- `amount`

### `shield`

On activation:

- grant temporary absorbable shield HP

Fields:

- `amount`
- `duration`

---

## Passive effects

### `modify_gravity`

While equipped:

- multiply player gravity by `multiplier`

Field:

- `multiplier`

### `modify_speed`

While equipped:

- multiply walking speed by `multiplier`

Field:

- `multiplier`

---

## Compatibility rule

At least one of these must be true:

- Echo contains an active effect appropriate to `activation = primary`
- Echo contains a passive effect appropriate to `activation = passive`

For v0.2, do not combine passive-only effects with `activation = primary`, and do not combine attack effects with `activation = passive`.

# 24. Echo validation bounds

Use these POC bounds.

- damage: 1–25
- pellets: 1–16
- spread: 0–30 degrees
- hitscan range: 5–60
- projectile speed: 5–45
- projectile lifetime: 0.5–6 seconds
- recoil force: 0–16
- knockback force: 0–16
- dash force: 4–20
- grapple range: 5–35
- grapple pull force: 4–25
- gravity multiplier: 0.35–1.5
- speed multiplier: 0.65–1.6
- heal amount: 5–60
- shield amount: 5–80
- shield duration: 1–15 seconds
- Echo cooldown: 0.15–15 seconds
- effects per Echo: 1–3

If Epsilon requests an unsupported/invalid effect:

1. reject the whole Echo response
2. send exactly one repair request containing concise validation errors
3. if repaired response is still invalid, use fallback Echo

# 25. Echo generation request and exact model instruction

Epsilon receives:

```json
{
  "schema_version": 2,

  "source": {
    "location_id": 89100004,
    "item_name": "Conference Call",
    "source_game": "Borderlands 2",
    "recipient_name": "Sage",
    "item_flags": 1
  },

  "player_state": {
    "existing_echoes": [],
    "pepsi_keys": 0,
    "coins_available": 2
  },

  "allowed_archetypes": ["weapon", "tool", "mobility", "passive"],
  "allowed_effects": {},
  "balance_limits": {}
}
```

Use a provider prompt equivalent to:

> You are Epsilon, the procedural designer inside Archipepsi. Interpret one foreign Archipelago item as a recognizable but playful local Archipepsi Echo. You are producing data, not code. Use only the supplied archetypes, activation modes, effect names, fields, and numeric bounds. Prefer 1–3 effects. Preserve some semantic relationship to the item name and source game. It is good for an Echo to create surprising movement or combat possibilities, but it must remain understandable from its description. Do not invent APIs or mechanics. Return only one object matching the supplied schema.

Creativity modifies “how literal” the semantic interpretation is. It never changes the schema or safety bounds.

# 26. Future Zones account for owned Echoes

Every Zone request includes concise summaries of owned Echoes.

Epsilon is encouraged to:

- feature a recent Echo
- choose room shapes where that Echo is fun
- choose enemies that interact interestingly with it
- create optional easier routes for movement Echoes
- create optional secrets that become convenient with movement Echoes
- make weapon recoil useful for messing around
- vary design based on the current inventory rather than ignoring it

However, in the POC:

**Every mandatory path and mandatory objective must remain completable using base movement + the default attack.**

There are no Echo-only mandatory gates.

`featured_echo_ids` is descriptive/design metadata only.

This restriction should be reconsidered only after a traversal/reachability validator exists.

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

# 31. Zone generation request

Exact conceptual shape:

```json
{
  "schema_version": 2,
  "generation_id": "ExampleSeed-0-6-zone-003",

  "campaign": {
    "seed_name": "ExampleSeed",
    "slot_name": "Skyiah",
    "team": 0,
    "slot_id": 6,
    "zone_index": 3,
    "target_game": "Dark Souls III",
    "completed_zone_summaries": [
      {
        "name": "Neon Drain",
        "theme": "neon_city",
        "target_game": "Bomb Rush Cyberfunk"
      }
    ]
  },

  "player": {
    "pepsi_keys": 1,
    "coins_available": 4,
    "echoes": [
      {
        "echo_id": "echo_89100004",
        "display_name": "Conference Call",
        "archetype": "weapon",
        "activation": "primary",
        "tags": ["shotgun", "recoil", "mobility"],
        "description": "A ridiculous shotgun with severe backwards recoil."
      }
    ]
  },

  "locations": [
    {
      "location_id": 89100012,
      "location_name": "Archipepsi Check 012",
      "item_name": "Hookshot",
      "recipient_name": "Sage",
      "recipient_game": "Ocarina of Time",
      "item_flags": 1,
      "item_name_may_appear_in_player_text": false
    }
  ],

  "catalog": {
    "themes": [
      "grass_block",
      "stone_dungeon",
      "neon_city",
      "gothic_castle",
      "desert_scrap",
      "void_glitch"
    ],
    "chamber_types": [
      "corridor",
      "arena",
      "platform_path",
      "tower",
      "treasure_room"
    ],
    "enemy_archetypes": ["melee", "ranged", "brute"],
    "objectives": ["reach_reward", "kill_all", "platform_to_goal"]
  },

  "constraints": {
    "max_chambers": 6,
    "max_enemies_total": 14,
    "all_locations_must_appear_once": true,
    "critical_path_requires_echo": false
  }
}
```

# 32. Exact Epsilon Zone behavior

Use a provider system instruction equivalent to:

> You are Epsilon, the procedural level designer inside Archipepsi. You are given a small fixed set of Archipelago locations that MUST all appear exactly once in the Zone. Those location IDs were selected by deterministic game code; you may not add, remove, replace, reserve, or renumber them. Design a short blocky first-person Zone using only the supplied themes, chamber templates, enemies, objectives, and numeric fields. You are producing structured data, not executable code. Use the recipient game as strong thematic inspiration. You may use unrevealed item identity privately as design inspiration, but never place an unrevealed exact item name in player-facing text. Account for the player’s owned Echoes and make them fun to use, but every mandatory path must remain completable with base walking, base jumping, and the default attack. Prefer a coherent little videogame idea over random nonsense. Return only one schema-valid Zone object.

Quality preferences:

1. 2–5 chambers is usually enough.
2. Avoid repeating the exact same chamber type three times in a row.
3. Put at most one brute in a Zone.
4. Give each supplied Check a meaningful payoff moment.
5. If an Echo is featured, design opportunities for it without requiring it.
6. Use humor sparingly and coherently.
7. Do not explain your reasoning in the output.

# 33. Epsilon creativity setting

Add a Campaign configuration:

`epsilon_creativity`

POC values:

- `0` Conservative
- `1` Playful
- `2` Unhinged

Default:

`1`

Behavior guidance:

## Conservative

Item meaning stays recognizable.

## Playful

Item meaning stays connected but can reinterpret mechanics.

## Unhinged

Names and source concepts may be treated as semantic suggestions, but output still uses only supported game primitives.

This setting changes model instructions, not validation.

---

# 34. First-person player specification

Inputs:

- WASD movement
- mouse look
- Space jump
- E interact
- left mouse / primary input: use equipped Echo
- mouse wheel or Q: cycle Echo
- Escape pause
- F3 debug overlay

Base movement:

- medium-fast walk
- no sprint required
- no crouch
- forgiving jump
- small coyote-time window recommended
- falling out of world respawns

The game must measure/store one constant:

`SAFE_BASE_JUMP_GAP`

The `platform_path` generator clamps every mandatory gap at or below that proven distance.

Do not guess a larger value in model output.

# 35. Base player capability

Without any Echo, the player can:

- walk
- jump
- interact
- use a weak unlimited default attack

Default attack:

`Pepsi Pop`

Implementation:

- simple hitscan
- low damage
- short/moderate cooldown
- unlimited ammo
- no generated data required

Purpose:

Every mandatory combat encounter remains technically beatable even before a useful weapon Echo exists.

Epsilon should prefer making Echo weapons much more satisfying than Pepsi Pop.

# 36. Health / death

POC:

- 100 HP
- enemies deal simple fixed damage
- death respawns at Zone start
- completed AP locations stay completed
- Echoes stay owned
- coins spent stay spent
- killed enemies may respawn on death for simplicity

No souls/corpse recovery.

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

# 38. Echo inventory UI

POC inventory is intentionally small.

Show collected Echoes as a scrollable list.

For each Echo show:

- name
- source game
- source item recipient
- description
- active/passive
- concise effect summary

Player can:

- select exactly one equipped Echo
- cycle equipped Echo from gameplay
- unequip Echo to use no generated ability

Do not implement slots, rarity, equipment weight, fusion, or global passive stacking in the POC.

# 39. Generated item presentation

When a foreign item check completes:

Example:

```text
SENT TO BL2PLAYER
Conference Call
Borderlands 2

EPSILON ECHO ACQUIRED
Conference Call

12 pellets
Huge recoil
Knocks enemies backward
```

This is an important payoff moment.

It should be obvious that:

- the other player got the real item
- Archipepsi got Epsilon’s local interpretation

---

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

# 44. Fallback Zone generator

Must exist.

It receives the same selected location set.

It produces a simple linear Zone:

```text
spawn
→ corridor
→ arena/check
→ corridor
→ platform/check
→ arena(brute)/check
→ exit
```

Theme chosen by hash/target game.

No model required.

This is both:

- failure recovery
- a test oracle for engine-side generation

---

# 45. Fallback Echo generator

Fallback must always emit one schema-valid v0.2 Echo.

Deterministic heuristics:

If lowercase item name contains:

- `conference call` -> shotgun-like hitscan, many pellets, spread, recoil
- `shotgun` -> hitscan, many pellets, spread, recoil
- `gun`, `rifle`, `pistol`, `cannon` -> hitscan or projectile weapon
- `sword`, `blade`, `knife` -> short-range-ish hitscan weapon with low range/high damage
- `hook`, `grapple` -> grapple tool
- `boot`, `shoe`, `skate` -> dash
- `wing`, `feather`, `cape` -> passive gravity modifier
- `shield`, `armor` -> shield
- `estus`, `potion`, `flask`, `food`, `heart` -> heal
- `rep` -> dash or passive speed boost
- `bomb`, `grenade`, `rocket` -> projectile weapon

Otherwise:

Use deterministic hash of:

`source_game | item_name | source_location_id`

to choose one of:

- modest hitscan weapon
- modest dash
- modest passive speed boost

Never emit unsupported effect types.

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

# 47. Mock development mode

The project needs an offline mode so engine work does not require an AP server or model bill.

`MockCampaign` contains:

- fake seed/team/slot
- 30 fake locations
- deterministic recipient games
- fake item names
- fake received Pepsi Keys
- fake received Epsilon Coins

The first six Mock scouted locations are fixed:

```text
Check 001 -> Conference Call -> Borderlands 2 player
Check 002 -> Hookshot -> Ocarina of Time player
Check 003 -> Wing Cap -> Super Mario 64 player
Check 004 -> Estus Shard -> Dark Souls III player
Check 005 -> REP -> Bomb Rush Cyberfunk player
Check 006 -> Epsilon Coin -> Archipepsi
```

Fill Checks 007–030 deterministically with a mixture of foreign items and the native Archipepsi pool.

This fixture guarantees that the engine can test several obviously different Echo interpretations before live AP integration.

Mock bridge mode must be able to simulate:

- connecting
- scouting
- confirming location checks
- receiving another Epsilon Coin
- reconnecting with identical state

Mock Epsilon returns hardcoded schema-valid Zone/Echo objects.

The very first playable engine slice should work entirely in Mock Campaign before live AP integration.

# 48. Main menu UI

POC menu:

```text
ARCHIPEPSI

Server:   [ localhost:38281 ]
Slot:     [ Skyiah          ]
Password: [                 ]

Epsilon:    Claude / Mock / Fallback
Creativity: Playful
Status:     Bridge connected

[ CONNECT ]
[ MOCK CAMPAIGN ]
[ QUIT ]
```

After connect, show:

- AP connection status
- Epsilon provider status
- seed/slot

---

# 49. Fixed Hub

The Hub is authored, not generated.

It contains:

- portal/door to active/next Zone
- Echo inventory terminal/menu access
- fixed shop counter/terminal
- AP connection/status board
- generation status display

Hub shop behavior is deterministic.

Epsilon may provide shop **text flavor only**.

The Hub is the only place that initiates new Zone generation in the POC.

When no Zone is loaded:

- player activates portal
- game allocates locations
- loading screen appears
- Epsilon/fallback generates
- Zone loads

# 50. Zone completion

A Zone is complete when all AP locations assigned to it are server-confirmed checked.

After completion:

1. show short Zone summary
2. return/open route to Hub
3. append Zone summary to Campaign history
4. clear `active_zone_id`
5. advance Track cursor
6. increment completed-Zone count
7. apply Hub shop expiration/creation cadence
8. save

Do not automatically generate the next Zone while the player is still inside the completed Zone.

# 51. Completion edge cases

If a location in the active Zone becomes checked due to reconnect reconciliation:

- mark its reward completed
- update Zone completion count

If all Zone locations are already checked:

- Zone is treated as complete
- player can return to Hub

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

# 54. POC Echo safety rule

The v0.1 draft permitted a newly generated Zone to hard-require an already-owned Echo.

**That is removed from the POC.**

Reason:

The schema validator can verify ownership, but it cannot yet prove that arbitrary generated traversal geometry is genuinely solvable with a grapple, recoil weapon, gravity modifier, etc.

Therefore:

- mandatory Zone routes use base movement only
- mandatory combat can always be completed with Pepsi Pop
- owned Echoes still strongly influence design
- Echoes may provide optional shortcuts, combat advantages, faster traversal, and secrets

Hard Echo gates become a future feature after the project has a mechanical reachability validator or much more constrained gate templates.

# 55. Visual style

POC target:

- low-poly/blocky
- deliberately crude
- readable
- colorful by theme
- 16×16 or 32×32 pixel textures
- flat planes and primitive mesh surfaces
- nearest-neighbor texture filtering
- no expensive material effects required

Use primitive Godot meshes and repeated materials.

Avoid building a voxel engine.

This is not Minecraft terrain. It merely borrows block readability.

---

# 56. Audio

Audio is optional POC polish.

If included:

- simple footsteps
- default shot
- hit sound
- reward sound
- Echo acquired sound
- shop purchase sound

Do not block core completion on audio.

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

# 60. Test plan — bridge

Required tests:

1. `CommonContext` configuration uses game `Archipepsi`.
2. `items_handling == 0b111`.
3. scout packet uses `create_as_hint == 0`.
4. scouted item name is resolved in recipient-game context.
5. full normalized snapshot contains all 30 scout results.
6. reconstructed `items_received` produces stable ordinals.
7. reconnect does not duplicate Epsilon Coins.
8. pending location check resends when still missing.
9. pending location check finalizes when server reports checked.
10. race mode refuses campaign start before bulk scouting.
11. malformed Godot bridge message returns recoverable error.
12. model invalid JSON falls back.
13. model unsupported effect repairs once then falls back.
14. provider timeout falls back.
15. password/auth failure surfaces readable status.

# 61. Test plan — APWorld

Validate:

1. exactly 30 addressed locations exist.
2. location IDs are `89100001–89100030`.
3. `Pepsi Key` item code is `89200001`.
4. `Epsilon Coin` item code is `89200002`.
5. `Epsilon Static` item code is `89200003`.
6. generated pool contains 2 Pepsi Keys.
7. generated pool contains 10 Epsilon Coins.
8. generated pool contains 18 Epsilon Static.
9. Tier 0 checks reachable from start.
10. Tier 1 requires one Pepsi Key.
11. Tier 2 requires two Pepsi Keys.
12. Victory event exists and is unaddressed.
13. completion condition uses Victory event item.
14. Check 030 is in Tier 2.
15. slot data uses schema version 2.
16. world generates successfully.
17. example multiworld YAML with non-local Coins generates when another eligible world is present.
18. `.apworld` packaging succeeds.

# 62. Test plan — Godot

Validate:

1. first-person movement.
2. safe base jump constant is tested.
3. death/respawn.
4. Pepsi Pop default attack.
5. melee enemy.
6. ranged enemy.
7. brute enemy.
8. corridor builder.
9. arena builder.
10. platform-path builder never exceeds base jump limit.
11. tower builder has base route.
12. treasure room builder.
13. linear chamber chaining.
14. reward state machine.
15. pending reward recovery.
16. each v0.2 Echo effect.
17. one-equipped-Echo behavior.
18. saved Zone reload.
19. saved Echo reload.
20. shop reservation.
21. shop pending purchase recovery.
22. insufficient coin behavior.
23. checked reward disables itself.
24. fallback Zone loads.
25. provider timeout returns player to playable state.

# 63. End-to-end acceptance tests

## Test A — Foreign item Echo

Live or mock placement:

`Archipepsi Check 001 -> Conference Call -> Borderlands 2 player`

Expected:

- Check 004 objective completes
- reward transaction becomes pending
- location is sent
- server confirmation finalizes
- other player receives real item in a live multiworld
- one Echo is generated/fallback
- Echo can be equipped and fired
- reload does not duplicate it

---

## Test B — Coin from another world

Another player finds:

`Epsilon Coin -> Archipepsi`

Expected:

- reconstructed received list gains exactly one Coin
- available balance rises exactly once
- reconnect does not duplicate it

---

## Test C — Shop

Hub shop reserves two eligible unchecked locations.

Expected:

- stock displays exact item and recipient
- insufficient balance blocks purchase
- sufficient purchase persists cost before sending check
- crash/reconnect while pending resends check
- server confirmation finalizes
- recipient gets real item
- foreign Echo appears once
- unsold stock later returns to Zone candidate pool

---

## Test D — Echo influences but does not gate later Zone

Acquire Conference Call Echo.

Generate later Zone.

Expected request contains Echo summary.

Accepted Zone may feature it.

Expected validator confirms there is no Echo-required critical path.

---

## Test E — Provider failure

Disable provider/API.

Expected:

- loading screen resolves to fallback
- Zone is playable
- run/save remains healthy

---

## Test F — Invalid model mechanic

Return unsupported Echo effect.

Expected:

- validation fails
- one repair attempted
- fallback used if repair invalid
- unsupported mechanic never reaches Godot gameplay code

---

## Test G — Race mode

Connect to a race-mode test room if convenient.

Expected:

- game refuses to start before location scouting
- readable unsupported message shown

# 64. Build priority

Build a vertical slice, not a framework museum.

Recommended order:

### Phase 1 — zero external services

1. repo skeleton
2. Python local bridge WebSocket with Mock Campaign
3. Godot main menu
4. fixed Hub
5. first-person player
6. Pepsi Pop
7. corridor + arena builders
8. one Mock Zone
9. one reward transaction
10. one hardcoded Conference Call Echo
11. save/load

**Milestone:** launch, walk into ugly room, clear Check, get/use Echo, reload.

### Phase 2 — generation engine

12. remaining v0.2 chamber templates
13. remaining 3 enemy archetypes
14. full v0.2 Echo effect engine
15. schema validation
16. fallback Zone/Echo
17. Mock Epsilon

### Phase 3 — real Archipelago

18. APWorld
19. example YAML
20. `CommonContext` bridge
21. real connection
22. race-mode guard
23. bulk scout `create_as_hint=0`
24. normalized AP snapshot
25. real Check transaction
26. received item reconstruction
27. Pepsi Key tier unlock
28. Epsilon Coin accounting
29. reconnect reconciliation
30. goal status

### Phase 4 — real Epsilon

31. Claude-compatible provider
32. Zone prompt
33. Echo prompt
34. one repair attempt
35. timeout/fallback

### Phase 5 — shop

36. deterministic stock allocation
37. pending purchase transaction
38. stock expiration/return-to-pool

### Phase 6 — acceptance

39. run end-to-end tests
40. package `.apworld`
41. README
42. record deviations

At every phase, keep the integrated executable runnable.

# 65. Implementation rules for the autonomous coding agent

These are instructions, not suggestions.

## 65.1 Do not redesign the project

Implement this specification.

If a detail is missing, choose the smallest implementation consistent with:

1. playability
2. data safety
3. future local-model replacement
4. this document’s product principles

Record the choice in `docs/IMPLEMENTATION_DECISIONS.md`.

Do not stop merely because a minor aesthetic/detail choice is unspecified.

---

## 65.2 Do not leave critical-path TODO stubs

A POC feature can be ugly.

It cannot be fake if it is part of the acceptance path.

Examples that must genuinely work:

- AP connection
- scouting
- location checking
- received-item dedupe
- Echo use
- coin spending
- save/load

---

## 65.3 Prefer fallback behavior over blocking

If the model provider is unavailable:

continue with fallback.

If a theme asset is missing:

use a default material.

If an optional chamber type is unfinished:

use arena/corridor.

If sophisticated enemy navigation fails:

use simple steering.

Do not let polish block the core loop.

---

## 65.4 Never weaken validation to accept bad AI data

Repair or fallback.

Do not add:

`eval`

Do not dynamically load scripts from model output.

Do not turn arbitrary strings into arbitrary class names.

---

## 65.5 Keep provider-independent state

No saved Zone/Echo format may contain Claude-specific response objects.

Only save normalized validated Archipepsi schemas.

---

# 66. Definition of done for the first autonomous implementation pass

A strong first autonomous pass should reach as far down this list as possible, in order.

### Required core

- repository starts from documented commands
- Mock Campaign works
- Godot Hub loads
- player moves/jumps/shoots Pepsi Pop
- at least corridor + arena generated templates work
- a Mock Check can be completed
- pending-check/save logic works
- Conference Call-like Echo can be acquired/equipped/used
- reload preserves accepted Zone/Echo

### Real integration target

- Archipepsi `.apworld` builds/installs
- bridge connects through current Archipelago client infrastructure
- all 30 locations scout with `create_as_hint=0`
- real checked/missing/received state reaches Godot
- one real location can be checked
- one foreign check creates one Echo
- one Coin can be received without duplication
- reconnect recovers

### Full POC target

- Claude-compatible provider produces validated Zone/Echo data
- fallback survives provider failure
- Hub shop sends a real location and spends Coins transactionally
- Check 030 reports goal
- README explains setup and known limitations

If the autonomous coding window ends before the Full POC target, it must leave the highest completed milestone **running**, tests/logs updated, and `docs/IMPLEMENTATION_DECISIONS.md` describing the exact next blocker. It must not sacrifice a working earlier vertical slice in order to half-build later subsystems.

# 67. Human-review decisions for design pass 0.3

The v0.2 self-audit intentionally removed choices that were dangerous for autonomous implementation. These are the remaining product decisions worth reviewing together.

## A. Is 30 the right POC Check count?

Current:

**30**

Recommendation:

keep 30.

It gives enough multiworld item variety without making the POC campaign enormous.

---

## B. Is 3 Checks per Zone the right density?

Current:

target 3, max 3.

This probably produces roughly 10 Zones for a full 30-check clear.

---

## C. Do we want the POC goal to be exactly Check 030?

Current:

yes.

Alternative later:

generated final boss / explicit Final Core event.

---

## D. Should Coins always be forced non-local?

Current recommended YAML:

yes, for the intended six-player POC.

The APWorld itself does not force it, so solo testing remains possible.

---

## E. How literal should Echoes be by default?

Current:

`Playful`

Conservative and Unhinged remain runtime choices.

---

## F. Should duplicate source items make duplicate/different Echoes?

Current:

yes.

Echo identity is source-location based, so two separately sent Hookshots can become two different interpretations.

This feels appropriately cursed but should be consciously confirmed.

---

## G. When do we reintroduce hard Echo-gated rooms?

Current:

not POC.

Recommendation:

only after implementing explicit gate templates such as `grapple_gate`, `dash_gate`, etc. whose solvability can be mechanically verified.

---

## H. Shop stock size/cost

Current:

2 items, fixed costs 2/4/6.

This is intentionally boring on the economy side so the weirdness stays in Epsilon’s item interpretation.

---

## I. Epsilon tone

Current target:

creative, playful, internally coherent, occasionally funny, never pure “lol random.”

This deserves a later tone pass after we see actual outputs.

# 68. Future roadmap — intentionally not POC commitments

If the POC works, likely expansions include:

- 250+ checks
- more AP logic tiers
- many more chamber templates
- more freeform primitive placement
- more enemy behaviors
- richer target-game theme packs
- richer Echo effect vocabulary
- secrets
- NPCs
- generated quests
- generated narrative callbacks
- local Epsilon
- small fine-tuned model
- model benchmark suite based on saved Claude outputs
- Epsilon personality
- Echo combinations
- generated boss modifiers
- shop personalities
- per-seed lore
- full run history
- better textures
- custom block models
- generated decals
- user-made primitive/effect packs
- Archipepsi options/YAML customization
- “Conservative → Unhinged” creativity slider
- spectator/debug seed viewer

---

# 69. Local Epsilon migration strategy

The POC must collect useful training/evaluation artifacts.

For every model generation, optionally save a development log containing:

- normalized input request
- raw provider output
- validation errors
- repaired output
- accepted normalized output
- whether fallback was required
- player rating later if implemented

Do NOT include secrets.

These records become:

- benchmark cases
- prompt regression tests
- possible future fine-tuning data where legally/contractually appropriate
- evidence for what intelligence the local model actually needs

The local model succeeds when it can satisfy the **same Zone and Echo contracts**.

No redesign of the game should be required.

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

# 71. Handoff prompt for the autonomous coding agent

Use this as the top-level coding instruction:

> Build the Archipepsi proof of concept described in DESIGN.md. Treat DESIGN.md v0.2 as the product and architecture authority. Work autonomously and preserve a running vertical slice at all times. Start in Mock Campaign and implement in the order given by Section 64. Do not redesign core rules. Do not execute model-generated code. Deterministic Archipepsi code owns allocation of AP locations; Epsilon only designs presentation around already-selected locations. Mandatory generated routes must remain completable with base movement and Pepsi Pop. Use the current Archipelago `CommonContext` infrastructure for the bridge where compatible, with `game="Archipepsi"`, `items_handling=0b111`, slot data enabled, and automatic scouting using `create_as_hint=0`. Persist pending location/shop transactions before network send. Validate all Epsilon output and make exactly one repair attempt before deterministic fallback. Record unavoidable deviations in `docs/IMPLEMENTATION_DECISIONS.md`. Do not stop for minor unspecified aesthetic decisions; choose the smallest implementation consistent with the spec. Before ending the coding session, run the highest available integrated acceptance path, leave the executable in a working state, and document the exact next blocker.

# 72. Short mental model

If implementation starts becoming confusing:

```text
ARCHIPELAGO
owns randomized truth
        |
        v
COMMONCONTEXT-BASED PYTHON BRIDGE
normalizes AP state + talks to Epsilon
        |
        +----------------------+
        |                      |
        v                      v
DETERMINISTIC ALLOCATOR      EPSILON
chooses AP location IDs      designs presentation only
        |                      |
        +----------+-----------+
                   v
             VALIDATED JSON
                   |
                   v
                 GODOT
          builds template Zone
                   |
                   v
          PLAYER CLAIMS CHECK
                   |
                   v
          PERSIST PENDING TX
                   |
                   v
              AP CONFIRMS
              /        \
             v          v
      REAL ITEM SENT   LOCAL ECHO
                        |
                        v
                 FUTURE DESIGN
```

The most important boundary is:

> **Archipelago decides the randomized truth. Archipepsi deterministic code decides which truth is currently presented. Epsilon decides what that presentation feels like.**

That loop is Archipepsi.

