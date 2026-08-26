# Archipepsi — Acceptance Tests (v0.5)

Observable proof that the idea works. A technically elegant codebase that cannot pass the end-to-end paths here is not a successful POC.

All examples use the canonical fixture in `IMPLEMENTATION_PLAN.md` §3.1. v0.3 scattered four inconsistent versions of it across documents; there is now one.

---

# 1. Schema tests — ship with the packet

`schemas/test_schemas.py` — 67 tests at time of writing, all passing. Run them first, before writing anything else. The count will grow; what matters is that they are green on arrival, so any red one is a regression you introduced.

They pin: the derived jump gap and its margin; the worst-case Zone clear time; the PRNG recipe (with a pinned seed value); Zone structural and semantic rules; the impossibility of expressing an Echo gate; Echo composition rules; rejection of invented fields and unsupported effects; save round-tripping; and that a `PENDING_GENERATION` Zone retains its allocation.

---

# 2. Bridge tests — pytest, no engine

1. `CommonContext` is configured with game `Archipepsi`.
2. `items_handling == 0b111`.
3. The scout packet uses `create_as_hint == 0` and covers all 30 locations.
4. A scouted item name resolves in **recipient-game** context, not sender context.
5. The normalized snapshot contains all 30 scout results.
6. Reconstructed `items_received` produces stable ordinals.
7. Reconnect does not duplicate Epsilon Coins.
8. A pending check still missing on the server is resent.
9. **A pending check already in `checked_locations` finalizes without waiting for any server event.** (The v0.3 hang: `check_locations()` filters it out and the server broadcasts nothing.)
10. A `claim_check` for an already-checked location finalizes immediately.
11. Race mode refuses campaign start *before* bulk scouting.
12. A malformed client message returns a recoverable `error`, and the bridge survives.
13. Invalid model JSON falls back.
14. An unsupported Echo effect triggers exactly one repair, then falls back.
15. Provider timeout falls back without a repair attempt.
16. Auth failure surfaces a readable status.
17. Save writes are atomic: a simulated crash mid-write leaves the previous save loadable.
18. A `PENDING_GENERATION` Zone found on load regenerates against its committed IDs and does **not** re-allocate.
19. Locations held by a `PENDING_GENERATION` Zone are excluded from shop eligibility.
20. Bulk confirmation of 25 locations generates **at most 3** Echoes on load.

---

# 3. Allocation and campaign tests — pytest

21. Track order is stable across runs for the same seed, and differs for a different slot.
22. Check 030 never appears in normal Zone allocation.
23. Check 030 never appears in shop stock.
24. A 1-Check Zone is produced only when exactly one eligible location remains.
25. With 0 Signal Keys, only Checks 001–010 are eligible.
26. Receiving one Signal Key makes 011–020 eligible.
27. Stock is not created when doing so would leave fewer than 3 eligible unreserved Checks.
28. Unsold reservations are released before `WAITING_FOR_AP` is declared.
29. With zero eligible non-goal Checks and no finale, `HubStatus.mode == "WAITING_FOR_AP"` and `portal_enabled is False`.
30. `WAITING_FOR_AP` clears automatically when a Signal Key arrives.
31. The finale unlocks at exactly 2 Keys **and** 24 confirmed non-goal Checks; not at 23.
32. The finale Zone contains exactly Check 030.
33. Confirming Check 030 sends goal status exactly once.
34. `coins_available == max(0, received - spent)`, never stored.
35. A reconnect reporting fewer coins than spending history clamps to zero and preserves purchases.

---

# 4. APWorld tests

36. Exactly 30 addressed locations, IDs 89100001–89100030.
37. Item codes 89200001 / 89200002 / 89200003.
38. Pool contains 2 Signal Keys, 10 Epsilon Coins, 18 Epsilon Static.
39. Item count equals location count.
40. **An origin region exists and matches `origin_region_name`.** (v0.3 named it `Start` without setting the attribute — a hard generation failure.)
41. Tier 0 reachable from start; Tier 1 needs 1 key; Tier 2 needs 2.
42. The Victory event exists, is unaddressed, and is in Tier 2.
43. `completion_condition` uses the Victory item.
44. Check 030 is in Tier 2.
45. Slot data is schema version 5 and contains no location→item placements.
46. Solo generation succeeds.
47. Multiworld generation with `non_local_items: Epsilon Coin` succeeds alongside another world.
48. `.apworld` packaging succeeds via AP's build component and the manifest validates.

---

# 5. Godot tests — headless `--script`

Godot ships no test framework. Rather than adopt an addon, assert what a headless script can: builder geometry, constants, and data round-trips. Anything requiring a rendered frame or human judgement is listed in §7 as manual.

49. `constants.gd` matches `constants.py` (regenerate and diff).
50. The corridor builder returns connected entrance/exit transforms.
51. The arena builder returns connected transforms and non-overlapping bounds.
52. Linear chaining produces no overlapping chamber bounds for a 6-chamber Zone.
53. **The platform-path builder never emits a gap exceeding `SAFE_BASE_JUMP_GAP` or a step exceeding `MAX_VERTICAL_STEP`**, across every legal parameter combination.
54. The tower builder always emits a base-movement route.
55. The treasure-room builder places exactly one reward.
56. An exit portal is appended after the final chamber of every generated Zone.
57. Zone JSON round-trips into scene construction without loss.
58. The reward state machine refuses interaction before its objective is satisfied.
59. Objective completion latches: satisfying `kill_all`, then dying, leaves the reward unlocked.

---

# 6. End-to-end

## Test A — Foreign item Echo
Placement: `Archipepsi Check 001 → Conference Call → BL2Player`.
Expect: **Check 001's** objective completes; the reward becomes pending; the location is sent; reconciliation finalizes it; in a live multiworld BL2Player receives the real item; exactly one Echo is generated; the reveal sequence plays; the Echo equips and fires on RMB; **Static Pulse still works on LMB**; reload does not duplicate it.

*(v0.3's Test A set up Check 001 and then asserted on Check 004.)*

## Test B — Coin from another world
Another player finds `Epsilon Coin → Archipepsi`.
Expect: the reconstructed list gains exactly one Coin; available balance rises exactly once; reconnect does not duplicate it.

## Test C — Shop
Expect: stock reserves two eligible unchecked locations, never Check 030; stock displays the real item and recipient; insufficient balance blocks purchase; a sufficient purchase persists the cost **before** sending; a crash while pending resends on reconnect; server confirmation finalizes; the recipient gets the real item; a foreign Echo appears exactly once; unsold stock returns to the Zone candidate pool.

Must pass fully under `--ap=mock`, since a live session may never deliver enough Coins.

## Test D — Echoes influence but never gate
Acquire the Conference Call Echo, generate a later Zone.
Expect: the request contains the Echo summary; the accepted Zone may feature it; the Zone schema is structurally incapable of expressing a mandatory Echo requirement; the critical path is walkable and shootable with base kit only.

## Test E — Provider failure
Disable the provider or key.
Expect: the loading screen resolves to a fallback Zone; the Zone is playable; `EPSILON OFFLINE — FALLBACK USED` shows; the save stays healthy.

## Test F — Invalid model mechanic
Return an Echo with an unsupported effect, then a malformed repair.
Expect: validation fails; exactly one repair is attempted; fallback is used; the unsupported mechanic never reaches Godot gameplay code.

## Test G — Race mode
Connect to a race-mode room.
Expect: the game refuses to start **before** location scouting, with a readable unsupported message.

## Test H — Waiting for Archipelago
Clear every eligible Tier-0 Check with no Signal Key delivered.
Expect: unsold shop reservations release; the Hub shows `WAITING FOR ARCHIPELAGO`; the portal is disabled but Hub, inventory and shop remain usable; delivering a Signal Key restores `ZONE_AVAILABLE` without a restart.

## Test I — Leave and resume
Enter a Zone, clear one of three Checks, Return to Hub via pause.
Expect: the Zone stays `ACTIVE`; no new Zone can be generated; the confirmed Check stays confirmed; re-entering restores the Zone with transient state reset (enemies alive, objectives unsatisfied) and the confirmed reward still disabled; the exit portal stays locked until all three confirm.

## Test J — Finale
Reach 2 Keys and 24 confirmed non-goal Checks.
Expect: `hub.finale_available` is true with progress shown (there is no `FINALE_AVAILABLE` mode — collapsing it into `HubMode` is the exact bug §13 exists to prevent); the portal generates a single-Check Zone containing only Check 030; confirming it reports goal, shows the victory presentation, and sets `goal_sent` — **and the portal keeps working**. Any still-unchecked Checks remain playable; the Hub reaches `ALL_CHECKS_CLEARED` only when every Check is actually confirmed.

## Test L — GENERATED Zone survives a crash at the loading screen
Request a Zone; kill the client (or the bridge) after `zone_ready` but before entering.
Expect: on reload the record is `GENERATED`, `active_zone_id` points at it, the Hub shows `ZONE_READY` and the portal enters it. Its locations are **never** silently returned to the pool and **never** orphaned; requesting a new Zone is refused while it is held.

## Test M — Unfinishable Zone can be abandoned
Force a Zone whose `kill_all` cannot complete (drop an enemy below `ENEMY_FALL_KILL_Y` with that rule disabled).
Expect: with the rule enabled the enemy counts as dead and the objective completes. With it disabled, `abandon_zone` moves the record to `ABANDONED`, returns unclaimed locations to the pool, preserves Checks already confirmed inside it, and the Hub returns to `ZONE_AVAILABLE`.

## Test N — Postgame
Confirm Check 030 with ordinary Checks still outstanding.
Expect: goal reported once, victory presentation shown, `goal_sent` and `postgame` true, **portal still enabled**, remaining Checks still allocatable and clearable, and no AP location abandoned.

## Test O — Double purchase charges once
Send two `buy_shop_stock` intents for the same location before the server confirms.
Expect: the second is rejected; `coins_spent` increases by exactly one cost; exactly one `PendingCheck` exists; the stock item reads `pending` then `purchased`.

## Test P — Disconnect does not zero the campaign
Drop the AP connection mid-session.
Expect: `coins_received`, `signal_keys`, `unlocked_tier` and `hub.mode` are unchanged in the emitted snapshot; `ap_state_is_current` is false; no `sync_warning` fires; reconnect restores without a spurious low-coin warning.

## Test K — Bulk confirmation
Run `!collect` mid-campaign.
Expect: no Echo-generation storm; at most 3 Echoes generate on load; the rest generate lazily; the client stays responsive; the save stays valid.

---

# 7. Manual checks

Not automatable, but the POC is not done until a human has confirmed:

- movement feels good enough to jump a 2.6 m gap reliably, and a 2.0 m gap onto a 1.0 m step
- the reveal sequence lands — it is obvious the other player got the real item
- firing the Conference Call Echo and flying backwards is funny
- a fallback Zone is boring but not broken
- `WAITING FOR ARCHIPELAGO` reads as intentional, not as an error
- a full campaign takes a plausible session length (target ~40 minutes)
