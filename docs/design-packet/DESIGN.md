# Archipepsi — Game Design


This is the primary product authority. It defines the POC fantasy, scope, terminology, player loop, campaign allocation behavior, shop/economy, controls, Hub, pacing, visual target, and deliberately deferred features.

A coding agent should not substitute a different roguelike/metroidvania structure merely because it seems more conventional.


> **Authority note:** See `README.md` for conflict/precedence rules.


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
