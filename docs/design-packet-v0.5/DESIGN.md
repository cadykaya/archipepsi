# Archipepsi — Game Design (v0.5)

Primary product authority. Defines the fantasy, scope, terminology, player loop, campaign allocation, shop, controls, Hub, pacing, and what is deliberately deferred.

A coding agent must not substitute a different roguelike/metroidvania structure because it seems more conventional.

> **Authority:** see `README.md` for the precedence order. Every *number* in this document is illustrative — `schemas/constants.py` is binding.

---

# 1. Pitch

**Archipepsi is an Archipelago game whose campaign is constructed during the multiworld by an AI dungeon master called Epsilon, using the actual randomized items in the player's Archipelago locations as inspiration for levels, rewards, shops, and permanent local "Echo" abilities.**

---

# 2. The fantasy

Six players start a multiworld: Super Mario 64, Ocarina of Time, Bomb Rush Cyberfunk, Dark Souls III, Borderlands 2, and Archipepsi.

The Archipepsi player starts with no prebuilt campaign. They enter a server, slot name, optional password. Archipepsi connects and scouts its own 30 locations.

Epsilon learns things like:

- Check 001 contains a Borderlands 2 item for BL2Player
- Check 002 contains an Ocarina of Time item for Sage
- Check 006 contains an Archipepsi Coin for the Archipepsi player

and builds a playable blocky first-person campaign from that.

When the player clears a Check containing `Conference Call → BL2Player`:

1. Archipepsi reports the location check to Archipelago.
2. Archipelago gives the real Conference Call to BL2Player.
3. Archipepsi creates a local **Echo** of it for the Archipepsi player.
4. Epsilon decides what that Echo does, using only supported mechanics.
5. Future Zones know the player owns it and design around it.

> **Every Archipelago seed creates a different game, and everyone else's randomized item pool becomes Archipepsi's mechanics and level-design vocabulary.**

---

# 3. Product principles

## 3.1 Archipelago owns the multiworld

Archipelago owns item placement, location completion, item delivery, slot identity, reconnection truth, and native progression. Archipepsi never edits a generated seed. Epsilon never invents real AP items or locations at runtime.

## 3.2 Epsilon is a designer, not a programmer

At runtime Epsilon outputs **data**, never executable code.

Epsilon **may**: choose themes, chamber templates and bounded parameters, enemy archetypes, objectives, which supplied Check sits in which chamber, names, descriptions, Echo effect combinations, and may account for owned Echoes.

Epsilon **may not**: emit or execute code, load libraries, shell out, write files, choose network destinations, invent effect names, or alter Archipelago placement or logic.

All output is parsed, validated against `schemas/`, and rejected if invalid. **v0.4 rejects and repairs; it does not silently clamp.** An accepted Zone is always something Epsilon actually chose, which keeps the saved generation logs honest as future training data.

## 3.3 The game stays playable when Epsilon misbehaves

Schema validation, semantic validation, one repair attempt, deterministic fallback Zone and Echo generators, safe load/reconnect. A bad response never corrupts a save or blocks a run.

## 3.4 Ugly on purpose — 1998, not Minecraft

The target is a **late-1990s PC FPS**: GoldSrc/Quake-era brushwork, not voxels.

Chunky low-poly geometry assembled from prisms, wedges and ramps. Boxy industrial rooms, vents, catwalks, pipes, tunnels, concrete chambers. Deliberately crude doors, buttons and consoles. Low-resolution grimy textures, generated in code. Harsh simple lighting. Simple low-poly enemies. Per-source-game material sets.

Explicitly **not** the target: giant cubes, obvious 16x16 tiles, voxel-looking architecture, everything snapped to a visible grid. Minecraft readability was a v0.3 idea that came from trying to make life easy for a local model — but Epsilon never paints a texture, our code does, so the constraint bought nothing and cost the look.

Nothing architectural changes. The generator already assembles chambers from primitives; only the visual grammar moves, from Minecraft blocks to 1998 level-editor brushwork. Which is a very funny thing for an AI-generated game to be made of.

No AI-generated art, models, shaders or audio.

> "A local AI was handed a 1998 level editor and told to make a game."

## 3.5 Echoes are permanent and monotonic

Once obtained, an Echo stays obtained for the seed. Effects may have cooldowns or durations. No consumables, no ammunition, no losing Echoes.

---

# 4. POC definition of success

End-to-end, against a real Archipelago server:

1. Launch Archipepsi; enter server, slot, optional password.
2. Connect; receive slot info; scout all 30 locations.
3. Resolve a scouted location to item name, recipient player, recipient game, flags.
4. Send allocated locations to Epsilon; receive valid Zone JSON.
5. Instantiate a playable 3D Zone; walk it in first person.
6. Complete a chamber objective and claim a Check.
7. Send `LocationChecks`; the real recipient gets the real item.
8. Generate a local Echo for a foreign-recipient check.
9. Equip and use the Echo.
10. Generate a later Zone whose request includes that Echo.
11. Receive an Epsilon Coin from another player.
12. Spend Coins in the Hub shop; the purchase completes a real AP location.
13. Quit, reload, reconnect — no duplicated coins, Echoes, checks or purchases.
14. Continue from saved campaign state.
15. Reach the finale Zone and confirm Check 030; goal is reported.

If all 15 work the central hypothesis is proven. Echo-gated traversal is **not** required.

---

# 5. Scope

## 5.1 In

Stock Godot 4.5.1 + GDScript; Python bridge owning campaign state; Archipelago `CommonContext` from a pinned checkout; first-person movement, jump, interact, health, simple combat; 3 enemy archetypes; runtime scene construction from 5 chamber templates; 30 AP locations; 2 Signal Keys; Epsilon Coins; Epsilon Static; 3 logic tiers; real AP connection; scouting with `create_as_hint = 0`; `items_handling = 0b111`; reconnect reconciliation; persisted pending transactions; Epsilon provider abstraction with Claude / mock / fallback; Echo generation; one-equipped-Echo inventory; generated Zones; a reserved finale Zone; fixed-Hub shop; save/load; debug overlay; `.apworld` build; README; example YAML.

## 5.2 Out

AI-generated art/models/music/voice; runtime code generation; free-placement geometry; voxel terrain; open world; multiplayer inside Archipepsi; NPC quest systems; perfect pathfinding; advanced animation; cloud saves; mobile; local Epsilon; fine-tuning; Steam; mods; final polish; 250 checks; multiple Archipepsi slots per seed; a Godot fork; GDExtension; Echo-gated mandatory traversal; shops inside Zones; race-mode rooms; background generation; **Epsilon-generated shop flavor text** (cut in v0.4 — see §11).

---

# 6. Terminology

**Campaign** — the whole Archipepsi experience for one seed + slot. Ends when the slot reaches its goal.

**Track** — a thematic grouping of Archipepsi locations by the *game receiving* their items. Organizational only; not an AP Region.

**Zone** — one loaded playable map. Normally 2–3 Checks. The **finale Zone** holds exactly one (Check 030).

**Chamber** — a spatial component inside a Zone: corridor, arena, platform_path, tower, treasure_room.

**Check** — a real Archipelago location belonging to Archipepsi. Complete only once the server confirms it.

**Native Item** — a real Archipepsi AP item: Signal Key, Epsilon Coin, Epsilon Static.

**Echo** — a permanent local-only interpretation of a real item the Archipepsi player sent to another player. Not an AP item. Keyed by `source_location_id`.

**Epsilon** — the runtime generation role. Claude-backed for the POC; replaceable without changing game semantics.

---

# 7. Controls

| Input | Action |
|---|---|
| WASD | move |
| Mouse | look |
| Space | jump |
| **LMB** | **Static Pulse — always, never replaced** |
| **RMB** | activate equipped Echo (passive Echoes: nothing happens) |
| E | interact / claim reward |
| Q | cycle equipped Echo |
| Tab | Echo inventory |
| Esc | pause (contains **Return to Hub**) |
| F3 | debug overlay |

**Decision.** v0.3 bound the equipped Echo to left mouse while also promising every mandatory encounter was beatable with Static Pulse. Those cannot both be true: equipping an active Echo removed the weapon the guarantee rested on, so the promise silently became "beatable, provided the player realises they should unequip" — and a 25-damage/15-second-cooldown Echo is legal under the bounds and strictly worse than Static Pulse in a `kill_all` room.

Splitting the bindings makes the guarantee unconditional and needs no player understanding. It is also less code: no conditional rebinding on equip. And it is the only version where you can fire the Conference Call, get launched backwards, and keep pulsing away on the way down.

---

# 8. Base player capability

Without any Echo the player can walk, jump, interact, and attack with **Static Pulse**: simple hitscan, low damage, short cooldown, unlimited ammo, no generated data. Every mandatory encounter is beatable with it.

The name is not decoration. Epsilon Static is the noise the transmission leaves behind, it accumulates as visible Hub corruption, and your fallback weapon fires it. The weakest thing in the game is made of the garbage Epsilon leaves lying around.

Movement and combat constants are in `schemas/constants.py` and are **binding**. The traversal bounds are *derived*, and derived pessimistically:

```
max_safe_gap(step) = jump_reach(step, worst legal loadout) × 0.64, floored
SAFE_BASE_JUMP_GAP = max_safe_gap(0.0)          = 2.6 m
max gap at the maximum 1.0 m step                = 2.0 m
```

Three things v0.4 got wrong here, all fixed:

- **Gap and step were bounded independently**, so both could be maxed. The real margin at a maxed step was 1.17×, not the 1.56× the flat-jump derivation advertised — about 10 cm of slack after player radius. `PlatformPathChamber` now bounds them **jointly**: the reachable gap shrinks as the landing rises.
- **Equipped passives were ignored.** `jump_reach()` defaults to the worst legal loadout, and the passive multipliers themselves are now derived *from* the traversal bounds (see §15.3).
- **The safety floor rounded up.** `2.9867` became `3.0`. It floors now.

Retune movement and all of it recomputes. That is what makes "every mandatory path is completable with base movement" a checkable claim rather than a hope.

Enemy stats are chosen so the worst legal Zone (14 enemies including one brute) is ~25 seconds of sustained Static Pulse fire. Asserted in `test_schemas.py`.

Epsilon should prefer making Echo weapons much more satisfying than Static Pulse; the bounds allow roughly 2.6× its DPS.

---

# 9. Health and death

100 HP. Enemies deal fixed damage. Death respawns at Zone start after a short delay. Completed AP locations stay completed, Echoes stay owned, coins spent stay spent.

**Objective latching.** A chamber objective, once satisfied, stays satisfied for the lifetime of the Zone. Enemies may respawn on player death for simplicity, but a `kill_all` chamber that has already been cleared does **not** re-lock its reward. (v0.3 left this undefined.)

---

# 10. Campaign allocation

**Ownership rule:** deterministic Archipepsi code allocates AP locations. Epsilon does not. Epsilon receives already-selected locations and designs around them.

## 10.1 Scout first, reveal selectively

The allocator sees the full scouted pool. Epsilon receives only the current Zone's locations, owned Echo summaries, prior Zone summaries, and target-game context.

Items become visible to the player when their Check is confirmed, or when the location is current shop stock (you are being asked to pay for it).

Before revelation Epsilon may use recipient-game identity strongly for theme, but must never put an unrevealed exact item name in player-facing text.

**Known and intended:** because themes derive from recipient game, the player learns *which game* each location's item belongs to before playing it. That is the premise, not a leak to be fixed.

## 10.2 Tracks

Group eligible unchecked locations by `recipient_game`. Locations whose recipient is the Archipepsi slot belong to `Archipepsi / Glitch Track`.

## 10.3 Deterministic Track order

At campaign creation: collect recipient-game names across the 30 scouted locations, sort lexically, shuffle deterministically with `deterministic_shuffle(games, seed_name, team, slot_id, "track_order")`, save the result.

The exact seeding and shuffle are defined in `constants.py` and pinned by test. v0.3 said "deterministically shuffle" without defining the string→int step, which meant no two implementations would agree.

Zone generation round-robins the saved order, skipping Tracks with no eligible locations.

## 10.4 What is eligible

A location is an eligible **normal Zone candidate** when all hold:

- it is in an unlocked tier (tier N requires N Signal Keys)
- the server reports it missing
- **it is not Check 030** — the goal is fully reserved
- it is not held by any Zone whose state is not `COMPLETE` (including `PENDING_GENERATION`)
- it is not currently reserved as shop stock

## 10.5 Selecting a normal Zone

1. Compute unlocked tiers from received Signal Keys.
2. Build the eligible set per §10.4.
3. If it is empty, do not generate — enter `WAITING_FOR_AP` (§13).
4. Advance the Track cursor to the next Track with eligible locations.
5. Shuffle that Track's eligible IDs with `(seed_name, slot_id, generation_counter, target_game)`.
6. Take up to 3.
7. If fewer than 2 and other Tracks have eligible locations, fill to 2 from subsequent Tracks.
8. A **1-Check Zone is allowed only when exactly one eligible location remains in total.**
9. Create the `ZoneRecord` in state `PENDING_GENERATION` with its `allocated_location_ids`, and **save**.
10. Build the request, call Epsilon, validate, one repair, else fallback.
11. Save the accepted Zone, move to `GENERATED`, then `ACTIVE` on entry.

`target_game` is **the Track that initiated selection** (step 4), even when steps 7 pulled in locations from other Tracks. Per-location recipient games are still passed so Epsilon can theme individual chambers.

Epsilon may not swap, add, delete or reserve AP location IDs. The validator rejects any Zone whose reward set differs from `allocated_location_ids`.

## 10.6 The finale

Check 030 is **never** normal Zone stock and **never** shop stock.

The finale Zone unlocks when both hold:

- the player has received **2 Signal Keys**, and
- **24 of the other 29 Checks** are server-confirmed

It is a dedicated single-Check Zone containing only Check 030. Confirming it sends goal status.

Five Checks of slack means the ending is not cleanup duty and a single awkward straggler cannot block it, while the player still experiences most of the seed-generated game.

**This is deliberately stricter than the APWorld's own completion condition,** which only requires 2 Signal Keys. A runtime stricter than AP logic is safe — the seed stays beatable and the solver's assumption still holds; it just takes longer. The dangerous direction is the reverse.

## 10.7 Generation timing

Generation happens from the Hub, behind a loading screen. No background generation is required. One Zone at a time: no new Zone can be generated while one is `ACTIVE`.

---

# 11. Hub shop

## 11.1 Purpose

An alternate way to clear some real unchecked Archipepsi locations using Epsilon Coins. Buying stock completes the AP location, sends the real item to its real recipient, and creates a local Echo if the recipient is foreign. The shop never creates new AP items.

## 11.2 Why stock returns to the pool

Archipelago does not know Archipepsi's `coins_spent`. No location may be permanently shop-only, or lack of local currency could make the seed unbeatable. Unsold stock is released back to the normal candidate pool.

## 11.3 Eligibility

Stock must be: in an unlocked tier; server-missing; **not Check 030**; recipient is not the Archipepsi slot; not held by any non-`COMPLETE` Zone; not already reserved.

## 11.4 Price

Deterministic from AP item flags: progression 6, useful 4, trap/filler/other 2. Priority `progression > useful > other`.

## 11.5 Cadence, and never starving the player

- No stock before 2 Zones are `COMPLETE`.
- Then a batch of 2, refreshed every 2 completed Zones.
- Stock persists while the next Zone is played; on that Zone's completion, purchased stock stays checked and unsold reservations are released.
- **Do not create stock if doing so would leave fewer than 3 eligible unreserved Checks for the next normal Zone.**
- **Before declaring `WAITING_FOR_AP`, release unsold reservations.** A shop reservation must never be the reason a Zone cannot be generated.
- One-item shops are allowed. Zero eligible: `OUT OF QUESTIONABLE GOODS`.

## 11.6 Flavor text

**Cut in v0.4.** Shop copy is fixed and authored. v0.3 permitted Epsilon to name the shop and write one sentence per item, but the provider interface had no method for it, no schema, no validation and no fallback — a third model call, a third repair path and a third fallback generator for two sentences. If it returns later it should be a field on an existing call.

## 11.7 Transaction

`AVAILABLE → PENDING → CONFIRMED`, sharing the `pending_checks` ledger with Zone rewards.

1. Verify **all four**: the location is still server-missing; **no `PendingCheck` already exists for it, from any source**; it is in current stock with status `available`; and the balance suffices.

   The pending check is the one that matters. Between the send and the server's `RoomUpdate` the location is *still server-missing*, so a second purchase passed v0.4's two-condition test, created a second `PendingCheck`, and charged again. At 2 coins with 6 available that is three charges for one item, all of which finalize, with the Echo deduplicated by `echo_id` and the coins simply gone. Godot could not guard it either: stock had no status field to grey out.
2. Persist a `PendingCheck` with `source: "shop"` and `shop_cost`; set the stock item's status to `pending`.
3. Add the cost to persisted `coins_spent`.
4. **Save.**
5. Send the location check.
6. On server confirmation: finalize, mark the stock item `purchased`, release the reservation, create the Echo, clear the pending record, save.

If the connection drops after step 4, coins stay spent and the check is re-driven on reconnect.

**Rollback.** Archipelago sends no rejection for a bad location — invalid IDs are silently ignored, and `check_locations()` filters them out before sending. The locally-checkable trigger is: the location ID is absent from `missing_locations ∪ checked_locations`, i.e. it is not this slot's location at all. Roll back once, subtract the cost, release the reservation, log.

**Evaluate this only inside the reconnect reconciliation pass, never on a raw snapshot.** Both sets are empty until `Connected` populates them, and a snapshot is emitted at `bridge_ready` — long before any AP connection. Unguarded, the first snapshot after every bridge start rolls back every legitimately-pending purchase, refunding coins for checks that then confirm seconds later.

---

# 12. Coins and Static

```
coins_received  = count of "Epsilon Coin" in the reconstructed authoritative items_received
coins_spent     = persisted monotonic accumulator (already includes pending)
coins_available = max(0, coins_received - coins_spent)
```

`coins_spent` is a **stored accumulator**, incremented at purchase time and decremented only by the §11.7 rollback. It is not derived. v0.4 described it as "the sum of confirmed + pending shop costs", which is not computable from the save — confirmed purchases leave no record, since the `PendingCheck` is deleted on finalize — and read literally would refund every purchase the moment it confirmed.

Never store `coins_available`. Never increment `coins_received` from a callback. Always recount it from the reconstructed list.

**But only when AP state is current.** `CommonContext` clears `items_received` on every disconnect, so a recount mid-outage returns zero for coins, Signal Keys and Static alike. The bridge keeps its last-known normalized values and flags `ap_state_is_current: false`; it does not recount into zeros and it does not fire a sync warning. Without this, a five-second dropout regresses `unlocked_tier` to 0, collapses eligibility, and flaps the Hub into `WAITING_FOR_AP`.

If a reconnect reports fewer coins than local spending history: keep the history, clamp available to zero, log a sync warning, never erase purchases.

**Epsilon Static.** 18 of the 30 items the player receives are Epsilon Static. In v0.3 they did nothing, which made most of the campaign's "you got an item" moments empty. In v0.4 each one adds a permanent unit of cosmetic Hub corruption — creeping static on the status board, screen fuzz, the Hub slowly degrading — and increments a counter Epsilon may reference in Zone flavor text.

Purely cosmetic. It is AP `filler` and must never affect logic, difficulty, or reachability.

---

# 13. The Hub

Authored, not generated. Contains the Zone portal, Echo inventory terminal, fixed shop counter, AP status board, and generation status display. The only place that initiates Zone generation.

The portal's behavior is driven by `HubStatus.mode`:

| Mode | Portal | Meaning |
|---|---|---|
| `NO_CAMPAIGN` | disabled | not connected |
| `ZONE_READY` | **enter** | a Zone is `GENERATED` and waiting to be entered |
| `ZONE_ACTIVE` | **resume** | a Zone is `ACTIVE`; re-enter it |
| `ZONE_AVAILABLE` | **generate** | eligible ordinary locations exist |
| `FINALE_ONLY` | **generate finale** | the finale is unlocked and nothing ordinary remains |
| `WAITING_FOR_AP` | disabled | nothing eligible, real Checks still outstanding |
| `ALL_CHECKS_CLEARED` | disabled | every Check confirmed; nothing left to play |

`HubStatus.finale_available` is a **separate boolean**, independent of `mode`.

The finale unlocks at 24 of 29, so up to 5 ordinary Checks normally remain when it appears. If the finale were a mode that displaced `ZONE_AVAILABLE`, those Checks would become unreachable — the player forced to end the campaign the moment they qualified. So when both are possible the Hub offers **both**, and `RequestNextZone.finale` carries the choice.

Two guards the schema enforces:

- `WAITING_FOR_AP` and an available finale are mutually exclusive. If you can start the finale you are not waiting on anyone.
- The finale is **not offered while a Zone is held** (`ZONE_READY` or `ZONE_ACTIVE`). Taking it mid-Zone would strand that Zone's unclaimed Checks. Finish or abandon first.

## 13.1 `WAITING_FOR_AP`

```
WAITING FOR ARCHIPELAGO
Your next progression is somewhere in the multiworld.
```

Reached when there are zero eligible non-goal Checks, the finale is not unlocked, and real Checks remain — after unsold shop reservations have been released.

Hub, inventory and shop stay usable. The portal is disabled, not broken. The state clears automatically when AP state changes.

This is the most likely state a real six-player run will hit, and it must read as intentional. The status board should say plainly that other players hold your progression — that is normal Archipelago interdependence, and the moment the game is most obviously *part of a multiworld*.

The shop will normally be empty here, because shop-eligible is a subset of Zone-eligible. Say so in the copy rather than implying stock might appear: `NOTHING LEFT TO SELL YOU`.

## 13.2 Generation is a visible state

Generation can take up to 120 seconds (one call plus one repair). `HubStatus.generation_in_progress` carries it, so the loading state survives a Godot restart and a bridge reconnect. Godot must not track this locally — a locally-tracked flag is lost exactly when it matters, producing the permanent-loading-screen failure the abandon-not-retry rule exists to prevent.

## 13.3 Postgame

Sending the Archipelago goal **does not end play.**

When Check 030 is confirmed: report goal to Archipelago, show the finale/victory presentation, and set `goal_sent`. Then return the player to the Hub with the portal still working. Remaining real Checks stay accessible until cleared, or until the player simply stops.

`ALL_CHECKS_CLEARED` is reached only when every Check is actually confirmed. There is no mode that disables play because the goal fired.

This matters beyond tidiness: at 24 of 29 required, ending on goal would abandon up to **five real Archipelago locations — up to five other players' items, never sent.** In a room without auto-release those items simply never arrive, and a stranded progression item can block someone else's completion. Archipepsi does not get to decide that other players' seeds are finished.

# 14. Zones: entering, leaving, finishing

## 14.1 Structure

Chambers chain linearly from the origin along +Z. The engine inserts connectors as needed and **automatically appends an exit portal after the final chamber**. Epsilon never places the exit and never chooses world coordinates.

## 14.2 Lifecycle

```
PENDING_GENERATION -> GENERATED -> ACTIVE -> COMPLETE
                                          \-> ABANDONED
```

`allocated_location_ids` is written at `PENDING_GENERATION`, **before** the provider is called.

`active_zone_id` is set the moment an accepted Zone is saved — i.e. at `GENERATED`, not at entry. This is load-bearing. In v0.4 it was only ever set on entry, so a Zone that generated and was then abandoned at the loading screen became invisible to the Hub while still holding its 2–3 AP locations against every eligibility check. Two such events put the reachable Check count below the finale threshold and made the campaign unwinnable.

`enter_zone` moves `GENERATED -> ACTIVE`. A Zone in either state shows on the portal and is always resumable.

## 14.3 Leaving early

The pause menu always offers **Return to Hub**. Leaving:

- **preserves** the Zone record and every server-confirmed Check in it
- **resets** transient state: living and dead enemies, partial enemy HP, all objective progress, player HP

Objective latching is scoped to the **loaded scene instance**, not the Zone record. Clear an arena, walk back to the Hub, return — you fight it again. The bridge holds no per-chamber objective state and does not need to; nothing Godot owns survives leaving. (v0.4 said "lifetime of the Zone" in one place, "unsatisfied progress resets" in another, and "objectives unsatisfied" in the acceptance test.)

## 14.4 Abandoning

`abandon_zone` gives up on a Zone that cannot be finished. Its unclaimed locations return to the eligible pool; Checks already confirmed inside it stay confirmed; the record moves to `ABANDONED`.

This exists because a schema-valid Zone can still be unfinishable. An enemy steered off a tower floor leaves `kill_all` permanently unsatisfied, and with no new Zone generatable while one is `ACTIVE`, the campaign stops. `ENEMY_FALL_KILL_Y` removes the most likely trigger — an enemy below it counts as dead — but the escape hatch has to exist regardless, or the promise that "a bad response never blocks a run" is false for valid responses.

Offer it from the pause menu, behind a confirmation naming what is lost.

## 14.5 Finishing

**A Zone with every assigned Check confirmed completes automatically, wherever the player is.** Completion is one idempotent procedure keyed on the record's state, triggered by Check confirmation:

1. move the record to `COMPLETE`, clear `active_zone_id`
2. append the summary to campaign history
3. advance the Track cursor
4. increment the completed-Zone count
5. apply shop cadence
6. save

The Track cursor advances **here and nowhere else**. (v0.4 also advanced it during selection; with six Tracks, double-advancing meant three never initiated a Zone all campaign.)

`exit_zone` is **pure travel**: it shows the summary and returns the player to the Hub. It is a no-op-plus-snapshot on an already-complete Zone, so a player standing on the portal of a finished Zone is never rejected.

Never auto-generate the next Zone while the player is still inside a completed one.

# 15. Echoes

## 15.1 Grant rule

When a source location becomes server-confirmed and its scouted recipient is **not** the Archipepsi slot: check for an existing Echo with that `source_location_id`; if none, request generation; validate once, repair once, fallback if needed; persist; add to inventory.

If the recipient **is** Archipepsi, no Echo is generated — normal `ReceivedItems` handles the native item.

`source_location_id` is the dedupe key. Two locations holding identically-named items therefore produce two independent Echoes. **This is intentional** (§18).

**Bulk-confirmation guard.** Do **not** auto-generate Echoes for locations the player never claimed. `!collect`, a release, or an admin action can flip up to 29 locations at once; generating for all of them would fire dozens of model calls at 60-second timeouts. Auto-generate only for locations present in `pending_checks` or belonging to a Zone or shop batch the player interacted with. Everything else generates lazily on first inventory view, at most one at a time and at most 3 per load.

## 15.2 Equipment

Exactly one Echo equipped at a time. Its effects are active or passive per its type. No global stacking of passives. No slots, rarity, weight, or fusion.

## 15.3 Shape

Defined by `schemas/echo.py`. Two variants, discriminated on `activation`:

- **`primary`** — `initiator` (exactly one, as a *field*) plus `modifiers` (0–2); `cooldown` required; fired with RMB.
- **`passive`** — 1–2 passive effects; no `cooldown` field exists; RMB does nothing.

"Exactly one initiator" is arity, not a count check. v0.4 used a flat `effects` list and enforced it in a validator, so appending a second initiator after parse restored the hole in one line. It is now a field, which also means the exported JSON Schema carries the rule and a provider driven by structured output cannot emit two.

Modifiers (`recoil_self`, `knockback_target`) still need a damage initiator in the same Echo — that one is a genuine validator, and `validate_assignment` re-runs it on mutation.

**Passive multipliers are bounded by the traversal guarantee, not independently.** `modify_gravity` caps at 1.0, so a gravity Echo may only ever make you lighter; `modify_speed` has a floor tight enough that the worst legal loadout still clears every mandatory gap.

v0.4 bounded them by feel: gravity up to 1.5 dropped jump apex to 0.89 m against a 1.0 m mandatory step, and both hostile multipliers together gave 2.02 m of reach against a 3.0 m gap. The schema forbade Zones from *requiring* an Echo and cheerfully permitted an Echo that made a Zone impossible — a negative gate, with no in-game hint that unequipping was the answer.

## 15.4 Inventory UI

A scrollable list showing name, source game, source item recipient, **source location**, description, active/passive, and a concise effect summary. Showing the source location matters because two Hookshot Echoes must read as *Check 002's* and *Check 026's* rather than as a confusing duplicate.

Player can select one equipped Echo, cycle it from gameplay, or unequip.

---

# 16. The reveal

When a foreign-recipient Check confirms:

```
SENT TO BL2PLAYER
Conference Call
Borderlands 2

EPSILON ECHO ACQUIRED
Conference Call

12 pellets
Huge recoil
Knocks enemies backward
```

This is the payoff moment and structurally it is the *only* genuinely novel moment in the loop — the rest of the POC is plumbing that exists to make it happen. Build it properly: freeze input, show the card, play a sound, hold ~2 seconds. It must be unmistakable that **the other player got the real thing and you got Epsilon's local reinterpretation.**

Treat this as core, not polish. It should not be what gets cut at T-30.

**One card, one notification.** A foreign-recipient confirmation emits a single `reveal` notification carrying `location_id` and `echo_id`; Godot composes the card from it plus the snapshot. Do not emit `check_confirmed` and `echo_acquired` as two sequential cards — two freezes and two holds back to back read as a bug. Those kinds remain for the cases where only one half applies: a self-recipient check confirms with no Echo, and a lazily-generated Echo arrives with no fresh check.

The third block ("12 pellets / Huge recoil / Knocks enemies backward") is rendered from the Echo's initiator and modifiers by a shared effect-summary formatter — the same one §15.4's inventory uses.

---

# 17. Progression

**Native AP progression** — Signal Keys, understood by AP logic, determine tiers. 0 keys: Checks 001–010. 1 key: +011–020. 2 keys: +021–030.

**Emergent Echo progression** — generated from foreign items, not AP items, understood only by the Archipepsi runtime, influences future generated content, never retroactively changes AP logic.

Both coexist. Keys may land anywhere in the multiworld, so other players' progress directly expands Archipepsi's available campaign. That interdependence is the point, and `WAITING_FOR_AP` is its visible face.

---

# 18. Known limitations

Documented deliberately so they are not later mistaken for bugs.

**Deleting the save restores spent coins.** AP remembers every delivered Coin; spending is intentionally local. Deleting the campaign file resets `coins_spent` while `coins_received` recomputes at full value. Unavoidable given the correct AP/local split, and self-limiting: purchased locations stay checked server-side, so the coins come back but the purchases do not.

**Duplicate source items produce independent Echoes.** Two separately-sent Hookshots become two unrelated Hookshot Echoes. This is the intended reading of the design: the Echo is Epsilon's *interpretation* of an item, not the item, and the same word read twice giving two answers is exactly what "a local AI handed a box of videogame Legos" would produce.

**The shop may not appear in a short live session.** It needs 2 completed Zones and Coins that other players must find first.

**A solo seed produces no Echoes and no shop at all.** With one world, all 30 items are placed on the 30 Archipepsi locations, so the recipient is the Archipepsi slot for every one of them. No foreign recipients means no Echoes generated for the entire campaign, no shop-eligible stock ever, and 10 permanently unspendable Coins. Since Echo acquisition and shop purchase are steps 8–12 of §4, a solo seed cannot demonstrate the POC. Use Mock Campaign, or generate against at least one other world. See `APWORLD_SPEC.md` §7.1.

---

# 19. Echo safety rule

Mandatory routes use base movement only. Mandatory combat is always completable with Static Pulse. Owned Echoes strongly influence design and may provide optional shortcuts, combat advantages, faster traversal, and secrets.

There are **no** Echo-gated mandatory gates in the POC. The validator can verify Echo *ownership* but cannot prove generated geometry is *solvable* with a grapple or a gravity modifier — and that distinction is why the rule exists. The Zone schema has no field capable of expressing a mandatory Echo requirement, so this is structural rather than a rule someone has to remember.

Hard gates return only after a mechanical reachability validator or much more constrained gate templates exist.

---

# 20. Visual style and art sourcing

Late-90s PC FPS. Chunky low-poly brushwork, boxy industrial architecture, harsh lighting, deliberately crude props. See §3.4 for what this is and is not.

Geometry is `BoxMesh`, `CylinderMesh`, `PrismMesh` and `PlaneMesh` assembled in code — the "brushes" of a 1998 level editor. Wedges and ramps are as important as boxes; a room built only from axis-aligned cubes reads as Minecraft, which is the thing to avoid.

Each theme is a material set: floor, wall, accent, trim, sky/void colour, light colour and energy. Themes and their per-game mapping are in `schemas/constants.py`.

**Art sourcing is a hard rule:**

> **Do not search for, download, browse, or evaluate external asset packs, texture packs, or model libraries.** Textures are generated procedurally at runtime with `Image.create()` at `TEXTURE_SIZE_DEFAULT` (64x64, bounded 32-128), using `texture_filter = NEAREST`. Simple noise, grime, panel lines, tile grids and stripes — written in code. No image files ship in the first pass.

v0.4 pinned 16x16 to make things easy for a hypothetical local model. That was a mistake: Epsilon never produces a texture, so the bound constrained nobody and just made everything look like Minecraft. 64x64 procedural grime is the same amount of code and lands the era.

**Blender is installed on the development machine (4.5.9). Do not use it.** No modelling, no `.blend` files, no glTF pipeline, no import step. "The developer happens to have Blender" is not a reason to build an asset pipeline the design defers. Custom models are roadmap material (§23).

# 21. Audio

Optional. If included: footsteps, Static Pulse, hit, reward, **Echo acquired**, shop purchase. Generate simple tones procedurally rather than sourcing files. Never block core completion on audio — except that the Echo acquired sound materially improves §16 and is worth the five minutes.

---

# 22. Main menu

```
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

`epsilon_creativity` (0 Conservative / 1 Playful / 2 Unhinged, default 1) is persisted in the campaign save, so a reloaded campaign remembers it was Unhinged. It changes model instructions only — never schemas, bounds, or validation. It is set by the `set_creativity` intent.

**The `Epsilon:` line is a read-only status display**, sourced from `CampaignSnapshot.epsilon_provider`. The provider is chosen by the bridge's launch flag or environment, not by the client, and there is deliberately no intent to change it. Render it as text, not a dropdown.

---

# 23. Roadmap — not POC commitments

250+ checks, more tiers, more chamber templates, freeform primitive placement, richer enemy behavior, theme packs, richer Echo vocabulary, secrets, NPCs, generated quests and narrative callbacks, local Epsilon, a fine-tuned model, a benchmark suite from saved outputs, Epsilon personality, Echo combinations, boss modifiers, shop personalities, per-seed lore, run history, better textures, custom block models, user packs, Archipepsi YAML options, a spectator/debug seed viewer, and Echo-gated traversal once reachability can be proven.

---

# 24. Mental model

```
ARCHIPELAGO                    owns randomized truth
        |
        v
PYTHON BRIDGE                  owns the Archipepsi campaign
  ├─ AP client (CommonContext)
  ├─ deterministic allocator   chooses AP location IDs
  ├─ campaign state + save     coins, shop, pending tx, echoes
  └─ Epsilon providers         designs presentation only
        |
        v  campaign_snapshot / zone_ready
      GODOT                    renders, simulates, sends intents
        |
        v
   PLAYER CLAIMS CHECK
        |
        v
   AP CONFIRMS ──> REAL ITEM SENT
        |
        └───────> LOCAL ECHO ──> FUTURE DESIGN
```

> **Archipelago decides the randomized truth. Archipepsi's deterministic code decides which truth is currently presented. Epsilon decides what that presentation feels like.**
