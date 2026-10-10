# Archipepsi — Autonomous Implementation Plan


This file tells the coding agent how to sequence the build while preserving a running vertical slice. It does not override product/network requirements in the authority files.


> **Authority note:** See `README.md` for conflict/precedence rules.


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


# 71. Handoff prompt for the autonomous coding agent

Use this as the top-level coding instruction:

> Build the Archipepsi proof of concept described in DESIGN.md. Treat DESIGN.md v0.2 as the product and architecture authority. Work autonomously and preserve a running vertical slice at all times. Start in Mock Campaign and implement in the order given by Section 64. Do not redesign core rules. Do not execute model-generated code. Deterministic Archipepsi code owns allocation of AP locations; Epsilon only designs presentation around already-selected locations. Mandatory generated routes must remain completable with base movement and Pepsi Pop. Use the current Archipelago `CommonContext` infrastructure for the bridge where compatible, with `game="Archipepsi"`, `items_handling=0b111`, slot data enabled, and automatic scouting using `create_as_hint=0`. Persist pending location/shop transactions before network send. Validate all Epsilon output and make exactly one repair attempt before deterministic fallback. Record unavoidable deviations in `docs/IMPLEMENTATION_DECISIONS.md`. Do not stop for minor unspecified aesthetic decisions; choose the smallest implementation consistent with the spec. Before ending the coding session, run the highest available integrated acceptance path, leave the executable in a working state, and document the exact next blocker.
