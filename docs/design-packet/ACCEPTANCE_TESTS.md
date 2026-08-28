# Archipepsi — Acceptance Tests


These tests define observable proof that the central idea works. Unit tests are useful, but a technically elegant codebase that cannot pass the end-to-end paths here is not a successful POC.


> **Authority note:** See `README.md` for conflict/precedence rules.


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
