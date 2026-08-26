# Archipepsi Design Packet v0.3 — Audit, Pass 1

**Auditor:** Claude (Claude Code)
**Date:** 2026-08-26
**Subject:** `Archipepsi_Design_Packet_v0.3.zip` (12 files, ~9,000 lines), unpacked to `docs/design-packet/`
**Purpose:** Determine whether this packet can be handed to a single unattended 4–5 hour coding pass and produce a working POC.

---

## 0. Verdict

**The concept is sound and the packet is unusually good.** The hard conceptual problem — how do you let a model author a game without letting it corrupt a multiworld — is genuinely solved here. The ownership boundary (Archipelago owns randomized truth → deterministic code owns allocation → Epsilon owns presentation) is the right boundary, it's stated consistently, and almost every rule in the packet follows from it correctly.

**It is not yet ready for a one-shot autonomous build.** Not because the design is wrong, but because the packet is a *design* document wearing an *implementation contract's* clothes. It says "remove every excuse the coding agent has to make a product decision," and it does that for product decisions — but a coding agent doesn't get stuck on product decisions. It gets stuck on missing numbers, unimplementable branches, and dependencies that don't exist. There are four of those.

Findings: **5 blockers, 8 correctness bugs, 10 contradictions, 17 gaps, 5 feel risks, 3 scope issues, 2 known limitations.**

The correctness bugs matter most because they're invisible from inside the document. Three of them (C1, C2, C4) are places where the spec describes Archipelago behavior that Archipelago does not have. I verified those against the Archipelago source and protocol docs rather than from memory; citations are inline.

**Recommended path:** one more spec pass fixing B1–B5 and C1–C5, then hand off. That's a few hours of writing, not a redesign.

This document merges two independent audits — mine, and Skyiah + ChatGPT's 24-item list produced in parallel without either side seeing the other. See §0.5 for the reconciliation.

---

## 0.5 Cross-check: two independent audits

Both audits were produced without seeing the other. That makes the overlap meaningful and the non-overlap more so.

**Found by both (12):**

| Their # | My ID | Finding |
|---|---|---|
| 1 | X4 | Test A stale check number (001 vs 004) |
| 2 | X2 | `arena` / `boss_arena` typo |
| 7 | G1 | No "waiting on Archipelago" state |
| 9 | C8 | PRNG seeding recipe undefined |
| 10 | X1 | Pepsi Pop / Echo input conflict |
| 11 | G9 | Schemas are examples, not schemas |
| 15 | X6 | Mixed-Track Zones have no defined `target_game` |
| 16 | B4 | Movement feel is prose, not numbers |
| 17 | B4/F2 | Enemy tuning unspecified |
| 19 | B1 | Bridge ↔ Archipelago dependency arrangement |
| 20 | G7 | No pinned versions |
| 22 | X5 | Fixtures not synchronized across docs |

**Found only by Skyiah + ChatGPT (9)** — now incorporated below with their numbers noted:

| Their # | Merged as | Finding |
|---|---|---|
| 3 | X9 | Stale embedded handoff contradicts the packet's authority split |
| 4, 5 | **B5** | Check 030 can be bought in the shop, or buried mid-Zone |
| 6 | G12 | Finale unlock condition undecided |
| 8 | G13 | `PENDING_GENERATION` state absent from the save schema |
| 12 | G14 | Echo effect compatibility undefined |
| 13 | G15 | Passive Echoes carry a meaningless cooldown |
| 14 | X10 | Shop flavor has no provider method |
| 18 | G16 | Art sourcing policy undefined |
| 21 | G17 | Runtime Claude API access is an unlisted prerequisite |
| 23 | L1 | Deleting the save restores spent coins |
| 24 | L2 | Duplicate Echoes need conscious confirmation |

**B5 is the best single find across both audits.** Six coins buys Check 030 and wins the game. I read the shop eligibility rules and the goal rules in separate sittings and never crossed them.

**Found only by this audit (21):** C1–C7 (AP protocol reality, verified against source), B2 (testability of the architecture), G2–G6, G8, G10, X3, X7, X8, S1–S3, F1, F3, and the derived constants in Appendix A.

The split is legible: the parallel audit is stronger on **game-state machine gaps** — the things you notice by asking "what happens next?" of the design. This one is stronger on **Archipelago protocol reality and build logistics** — the things you notice by reading `MultiServer.py`. Neither would have been sufficient alone. C1 in particular would have survived any number of readings of the packet, because the packet's claim about it is stated as a *verified assumption* and reads as authoritative.

---

## 1. What genuinely works

Calling these out specifically, because pass 2 should not accidentally "fix" them.

**The ownership boundary is correct and load-bearing.** "Deterministic code allocates AP location IDs; Epsilon designs presentation around locations it was handed" is the single decision that makes this project possible. Everything dangerous about AI-authored content — desync, unwinnable seeds, phantom items — is prevented by that one rule. It is stated in `DESIGN.md §3.1`, `§13`, `EPSILON_SPEC §32`, and the handoff prompt, and it never wavers.

**The shop deadlock analysis is the best thing in the packet.** `§27.2` — "Archipelago does not know Archipepsi's `coins_spent` state, therefore no location can remain permanently shop-only" — is a subtle failure mode that most designs would ship and only discover when someone's seed became unbeatable. Catching it on paper is a real result. The return-to-pool mechanic that follows from it is correct.

**"Persist the pending transaction before the network send" is right,** and having Zone rewards and shop purchases share one `pending_checks` ledger is exactly the right simplification. Most indie multiworld clients get this wrong and duplicate or lose checks.

**Removing Echo-gated traversal from the POC (`§54`) was the correct call, for the correct stated reason** — you can validate *ownership* of an Echo but not *solvability* of generated geometry with it. That is precisely the distinction, and the doc knows it.

**`create_as_hint = 0` is correct and important.** Verified: a non-zero value "will _always_ create a **persistent** hint … even if the location was already found." Bulk-scouting 30 locations with hints on would spam every player's hint tab and wreck the seed's hint economy. Catching this pre-implementation is a genuine save.

**`items_handling = 0b111` is correct.** Verified bit meanings: `0b001` remote items, `0b010` own-world items (requires 001), `0b100` starting inventory (requires 001).

**"Recompute coins from the reconstructed authoritative list; never increment from a callback"** is correct and is the standard way AP clients duplicate currency. Same for treating `ReceivedItems.index == 0` as a full replace.

**Refusing race-mode rooms** is a defensible, conservative call. Verified: `_read_race_mode` is the correct data-storage key and returns 0/1.

**The authority/precedence order in `README.md`** is a genuinely good idea for a multi-document packet and I'd keep it.

**The self-audit worked.** Comparing v0.1's failures (listed in `CHAT_TRANSCRIPT.md`) against v0.2/v0.3: Epsilon's AP bookkeeping removed, Echo gating removed, shop unified into the Hub, arbitrary geometry replaced with a template DSL. Every one of those was the right correction. The v0.1→v0.2 pass was more valuable than most human design reviews.

---

## 2. Blockers

These will stop or badly damage a single unattended pass.

### B1 — The bridge's core dependency cannot be installed

`TECHNICAL_ARCHITECTURE §7.4` mandates `CommonContext`, and `§70` lists "current Archipelago `CommonContext` … should be reused where compatible" as a *verified assumption*. The repo layout gives `bridge/requirements.txt` and `bridge/pyproject.toml`. Nothing anywhere says how the dependency is obtained.

There is no pip-installable Archipelago. (`pypi.org/project/archipelago` exists but is an unrelated CGRA place-and-route tool. `ArchipelagoMW` is not published.) Worse, `CommonClient.py` imports `MultiServer`, `NetUtils`, `Utils`, **and `worlds` (`AutoWorldRegister`, `network_data_package`) at module import time** — so importing it doesn't just need a file, it needs a full Archipelago source tree on `sys.path`, and it will load every apworld installed there.

An unattended agent hits this within the first hour and does one of two things: burns time discovering it, or quietly writes its own AP socket client — which the packet explicitly discourages, so it'll do it apologetically and half-heartedly.

**Decide now, and write the exact commands into the packet.** Two honest options:

- **(a) Run inside a checkout.** The bridge is launched from an Archipelago clone (`ARCHIPELAGO_ROOT` env var + `sys.path.insert`), documented with literal setup commands and a pinned AP version. Keeps `CommonContext` and all its reconnect/data-package handling for free. Cost: a heavyweight, awkward dev environment.
- **(b) Hand-roll the client.** The protocol subset Archipepsi actually needs is small — `Connect`, `Connected`, `ConnectionRefused`, `ReceivedItems`, `RoomUpdate`, `LocationChecks`, `LocationScouts`/`LocationInfo`, `StatusUpdate`, `Get`/`Retrieved`, `DataPackage`. That's roughly 200–300 lines over `websockets`, pip-installable, trivially unit-testable, and it removes the environment problem entirely. Cost: you re-implement reconnect and data-package caching, and you own the protocol drift.

I lean **(b) for the POC** and would revisit for release, because the whole point of the bridge is isolation and (b) is the version that a fresh machine can actually run. But this is your call — (a) is the more conservative, more "correct AP citizen" answer.

### B2 — The correctness-critical logic lives in the least verifiable place

Campaign allocation, tier gating, the deterministic PRNG, the coin ledger, the pending-check state machine, shop reservations, save/load, and reconnect reconciliation are all specified as **Godot/GDScript** responsibilities.

In an unattended pass this is write-only code. Godot is a GUI engine; the agent very likely cannot launch it, there is no test framework specified for it (see G9), and none of the above can be exercised without one. Meanwhile the Python bridge — which is mandatory anyway, since Godot cannot function without it — is trivially testable with pytest.

Every bug class this design is most afraid of (duplicated coins, lost checks, corrupted campaigns, desync after reconnect) lives in the half nobody can run.

**Recommendation:** move campaign state and rules into the bridge. Godot renders a `campaign_snapshot` and sends intents (`claim_check`, `buy_stock`, `request_zone`, `equip_echo`); it keeps only presentation state. That change buys: unit-tested economy and reconciliation, no GDScript reimplementation of SHA-256 and seeded shuffles, one language for everything subtle, and a headless end-to-end test of the entire acceptance path with no engine at all.

The cost is real: the save file moves out of `user://`, and Godot becomes genuinely useless without the bridge (it already nearly is). This is an architecture change, so it's a decision for you, not something a build pass should assume.

### B3 — The scope does not fit 4–5 hours

The full surface: 5 chamber builders, 3 enemy archetypes with AI, 11 Echo effect types, a first-person controller, 5 UI screens (menu / Hub / shop / Echo inventory / debug overlay), save + reconcile, a WebSocket protocol, an AP client, an APWorld with regions and events, 3 Epsilon providers, schema validation + repair + 2 deterministic fallback generators, 58 enumerated tests, an `.apworld` build path, and 4 docs.

That's multi-day work for a person. A strong single pass realistically lands Phase 1–2 plus the APWorld.

`§66` already ranks the milestones, which is good, but it doesn't give a **cut line**. Add explicit instructions: "at T-60 minutes, stop adding features; make the highest completed milestone run, write `NEXT_STEPS.md`, commit." Without that, the failure mode is six subsystems at 70%.

See S1 for a resequencing that materially improves what fits.

### B5 — The goal check is purchasable, and the finale can be buried mid-Zone

*(Skyiah + ChatGPT #4 and #5. I missed this entirely and it's the sharpest finding in either audit.)*

`DESIGN §52` and `APWORLD_SPEC §9.5` make **Check 030** the player-facing finish trigger: confirming it sends `CLIENT_GOAL`. Nothing anywhere excludes Check 030 from the two systems that hand out locations.

**Shop path.** `§28`'s eligibility test is: unlocked tier, server-missing, foreign recipient, not in the active Zone, not already reserved. Check 030 passes all five once Tier 2 unlocks. And if its scouted item is trap/filler-flagged, `§28`'s pricing makes it the *cheapest* tier:

> 2 coins → buy Check 030 → **WIN ARCHIPEPSI**

**Allocation path.** `§13.4` selects up to 3 locations per Zone by Track round-robin with no reservation for 030. So Check 030 can land as reward #1 of an ordinary three-check Zone: you touch the first reward object, the campaign ends, and two more checks sit unclaimed deeper in the level you're standing in.

Both paths produce a POC whose ending is an accident. The fix is the same for both, and it has a knock-on:

1. **Exclude 030 from shop eligibility** — add "is not the goal location" to `§28`.
2. **Exclude 030 from normal Zone allocation** — add it to `§13.4`'s exclusion list alongside shop reservations.
3. **Reserve it for a dedicated finale Zone**, which is naturally a 1-check Zone — a case `§13.4` already contemplates ("a final Zone may contain 1"). That rule stops being an edge case and becomes the finale's definition.

The knock-on is pool arithmetic: 29 allocatable checks at 3 per Zone is 9 Zones plus a 2-check Zone, then the finale. That's fine, and it makes the finale a real destination rather than a location that happened to come up in the shuffle.

This also interacts with G13 — allocated-but-not-yet-generated locations must be excluded from shop eligibility too, or a crash during generation lets the shop sell a location already committed to a pending Zone.

### B4 — There are no gameplay numbers, anywhere

Not one movement, combat, or timing constant exists in the packet. No walk speed, jump velocity, gravity, `SAFE_BASE_JUMP_GAP`, Pepsi Pop damage/cooldown/range, enemy HP, enemy damage, enemy speed, brute stats, or respawn timing.

This isn't a polish gap — it undermines the packet's central safety claims. "Every mandatory path is completable with base movement" is only true relative to a jump arc that doesn't exist yet. "Every mandatory fight is beatable with Pepsi Pop" is only true relative to damage numbers that don't exist yet. The `platform_path` validator's entire job is clamping gaps to `SAFE_BASE_JUMP_GAP`, and that constant is currently defined as "the game must measure/store" it (`§34`) — an unattended agent will not build a measurement rig. It will invent a number, and the guarantee becomes a guess.

`DECISIONS_TO_REVIEW.md` already flags this ("exact movement constants after a 5-minute in-engine feel test"). That test needs to happen, or the numbers need to be pinned analytically, **before** handoff. A proposed starting table is in Appendix A — derived so the jump arc and the gap clamp are consistent with each other, and so worst-case combat time is bounded.

---

## 3. Correctness bugs

Places where the spec describes behavior Archipelago does not have. All verified against the Archipelago protocol docs and `MultiServer.py` / `CommonClient.py` source.

### C1 — "Duplicate `LocationChecks` are safe, so resending is expected behavior" will never confirm

The packet leans on this in four places (`§37 Reconnect`, `§27.3`, `§41.2`, `§70`). It's true that duplicates are *harmless*. It is not true that they *do anything*, and the difference is a hang.

Two verified facts:

1. `CommonContext.check_locations()` filters its input against `ctx.missing_locations` — an already-checked location is dropped **client-side** and no packet is sent at all.
2. `MultiServer.register_location_checks` computes `new_locations = set(locations) - ctx.location_checks[team, slot]` and only broadcasts inside `if new_locations:`. All-already-checked → **no `RoomUpdate`, no response of any kind.**

So a resent pending check for an already-confirmed location produces silence. Any code that sends and then waits for an event sits in `SENDING…` forever.

The reconnect path in `§41.2` happens to be written correctly ("if server says checked: finalize"), because it reconciles against a snapshot. The in-session path in `§37` step 6 is written as an event wait, and the "duplicates are safe" framing will lead an implementer to build the retry loop the wrong way.

**Fix:** state the rule as *finalization is reconciliation against `checked_locations`, never an event wait*. The bridge emits a snapshot on connect, on every `RoomUpdate`, and immediately in response to `ap_check_location` (echoing current checked state, so an already-checked location confirms instantly). Add a client-side timeout that forces a reconcile rather than hanging.

### C2 — The shop's coin-refund path can never trigger

`§27.3`: "If the server permanently rejects the location because it does not belong to this slot/current seed: rollback the pending Check once, subtract its `shop_cost`…"

Archipelago has no rejection packet for `LocationChecks`. Invalid or foreign location IDs are silently ignored server-side — and per C1, `check_locations()` filters them out before they're even sent, since they aren't in `missing_locations`. The described trigger does not exist, so the rollback is dead code and the failure it guards against (permanently spent coins against a location that can never confirm) is unhandled.

**Fix:** define the real, locally-checkable trigger — after a full snapshot, the location ID is absent from `missing_locations ∪ checked_locations` for this slot, i.e. it is not our location at all. Roll back on that.

### C3 — `!collect` / `!release` will fire a mass Echo-generation storm

`§41.3`: "If server says a foreign-recipient location is checked and no Echo exists → generate/fallback Echo, save it."

When the Archipepsi player runs `!collect`, or an admin releases the seed, or the player goals — up to 29 locations flip to checked simultaneously. On the next load, that rule fires up to 29 Epsilon generation requests, each with a 60-second timeout. Best case it's an enormous API bill and a multi-minute freeze on a loading screen. Worst case the player's client appears hung and they kill it mid-write.

**Fix:** only auto-generate Echoes for locations the player actually *claimed* — present in `pending_checks`, or belonging to a Zone or shop batch the player interacted with. For bulk-checked locations, either skip Echo creation entirely or generate lazily on first inventory view. Cap concurrency at 1 and total per load at ~3.

### C4 — Naming the origin region `Start` will fail generation

`APWORLD_SPEC §9.3` creates three regions: `Start`, `Tier 1`, `Tier 2`, with `Start` "reachable immediately."

Archipelago's origin region defaults to `"Menu"`. The spec: "There must be one special region (called 'Menu' by default, but configurable using `origin_region_name`)." Nothing in `§9.3` sets `origin_region_name`, so as written the world has no origin region and generation fails.

**Fix:** one line — either rename the region to `Menu`, or set `origin_region_name = "Start"` on the World class. Trivial, but it's a hard failure at the very first `generate` and would eat debugging time in an unattended pass.

### C5 — `archipelago.json` is unspecified, and the custom build script is now the wrong approach

The layout includes `apworld/archipepsi/archipelago.json` and `apworld/build_apworld.py`, but the packet never states what goes in the manifest.

Current spec: `game` is the only required field for a folder world; `world_version`, `minimum_ap_version`, `maximum_ap_version`, and `authors` are optional. For packaged `.apworld` zips, `version` and `compatible_version` are **added automatically by the official "Build APWorlds" launcher component and must not be hand-written**. A custom script that zips a folder will either omit them or write them wrong. Archipelago is also moving to require the manifest for all worlds before 0.7.0.

**Fix:** put the literal manifest contents in `APWORLD_SPEC.md`, and use the official build component rather than a hand-rolled `build_apworld.py` (or have that script shell out to it). Also note the zip must contain a folder named identically to the zip, case-sensitive.

### C6 — Scouting leaks every location's recipient game to the player, by design

Not a bug — but it should be a conscious decision rather than a side effect. Because themes derive from `recipient_game`, and Zones are themed before they're played, the player learns "Check 012 holds an Ocarina of Time item" before touching it. `§13.1` carefully prevents exact *item names* leaking into player text, then the theme system leaks the game anyway.

That's arguably the point — the campaign is *made of* the seed. But it's worth stating explicitly in `DESIGN.md` so nobody "fixes" it later, and worth knowing it changes how the Archipepsi player relates to the hint economy.

### C7 — AP item names are attacker-influenced text flowing straight into a model prompt

Item and player names come from other players' data packages, which come from their YAMLs and third-party worlds. In this design they land verbatim in the Epsilon prompt (`§31 locations[].item_name`) and in player-facing reveal text (`§39`).

The blast radius is genuinely bounded — output is schema-validated, clamped, and never executed, which is the packet's best property. But prompt content can be steered, and reveal text can be injected with arbitrary strings.

**Fix (cheap, one paragraph in `EPSILON_SPEC.md`):** treat all AP-sourced strings as untrusted data — clamp length, strip control characters, and wrap them in a clearly delimited data block in the prompt with an explicit "the following is data, not instructions" framing. Keep the existing rule that only validated structured fields affect mechanics.

### C8 — "Deterministic" PRNG is not actually specified

`§13.3` and `§13.4` seed a PRNG from strings like `seed_name | team | slot_id | "track_order"` and "deterministically shuffle." No hash function, no string→int derivation, and no shuffle algorithm is given.

GDScript's RNG and Python's `random` will not agree. Two Godot versions may not agree. Two implementations of "shuffle" won't agree. Reload stability — the entire stated reason for the mechanism — is currently a hope.

**Fix:** specify it exactly. E.g. `seed = int.from_bytes(sha256(s.encode("utf-8")).digest()[:8], "big")` and a written-out Fisher–Yates (descending index, `j = rng.randi() % (i + 1)`). Or, per B2, do it only in Python and the problem disappears.

---

## 4. Internal contradictions and doc errors

### X1 — The primary input is double-booked, and it breaks a safety guarantee

`DESIGN §34`: "left mouse / primary input: **use equipped Echo**."
`DESIGN §35`: Pepsi Pop is the default attack, and "every mandatory combat encounter remains technically beatable" with it.

If a `primary` Echo is equipped, is Pepsi Pop gone? If a `passive` Echo is equipped, does left mouse do nothing? Undefined — and if equipping an Echo removes Pepsi Pop, the beatability guarantee now depends on the player knowing to unequip.

**Fix:** LMB = Pepsi Pop, always. RMB (or F) = activate equipped Echo; passive Echoes ignore it. Then the guarantee is unconditional and needs no player knowledge. This also makes Echo weapons feel like an *addition* rather than a mode switch.

### X2 — `§15.7` says the wrong word

"`arena` is **not** a separate chamber type in the POC. Use an `arena` containing a single `brute`."

It means **`boss`**. As written it directly contradicts `§15.2`, which defines `arena` as a chamber type. (`§15.6` does the same thing correctly for `shop`.)

### X3 — The Zone validator checks a field the request doesn't have

`EPSILON_SPEC §20`: "`zone_id` must exactly match request."
`EPSILON_SPEC §31`: the `ZoneGenerationRequest` has `generation_id`, not `zone_id`.

Add `zone_id` to the request, or validate against `generation_id`.

### X4 — Acceptance Test A contradicts itself

`ACCEPTANCE_TESTS §63 Test A` sets up `Archipepsi Check 001 -> Conference Call` and then expects "**Check 004** objective completes."

### X5 — The example data disagrees about who "Sage" is

`DESIGN §2` and `EPSILON_SPEC §21.3` make Sage the Borderlands 2 recipient. `TECHNICAL_ARCHITECTURE §10` makes location 89100004's recipient `BL2Player`. `EPSILON_SPEC §31` makes Sage the Ocarina of Time recipient.

Cosmetic — except a literal-minded agent builds its mock fixtures from these examples, and `§47`'s fixture table is a fourth version.

### X6 — A Zone can span Tracks but the request can only name one `target_game`

`§13.4` step 8: "If the selected Track has only one location … fill to at least 2 using the next Tracks in round-robin order." So a Zone can contain locations from 2–3 different recipient games. But `ZoneGenerationRequest.campaign.target_game` (`§31`) is a single string, and the theme catalog maps one game to one theme.

Say what `target_game` means for a mixed Zone (dominant track? the track the round-robin cursor landed on?), and consider passing per-location recipient games so Epsilon can theme individual chambers.

### X7 — `save_version: 2` on a greenfield project

Both `§40` examples start at 2 with no migration path defined, presumably mirroring "v0.2 spec." Either start at 1 or state the convention, otherwise the first implementer wonders what version 1 was and whether they need to read it.

### X9 — The embedded handoff prompt contradicts the packet's own authority order

*(Skyiah + ChatGPT #3.)*

`IMPLEMENTATION_PLAN §71` — the literal top-level instruction the coding agent is told to use — says "Treat **DESIGN.md v0.2** as the product **and architecture** authority."

But `README.md`'s precedence order deliberately splits authority five ways: DESIGN → APWORLD_SPEC → EPSILON_SPEC → TECHNICAL_ARCHITECTURE → ACCEPTANCE_TESTS. The whole reason the packet was split was that one document trying to be six was causing long-context failures.

So the first instruction the agent reads tells it to collapse the structure the packet exists to create. It also references "v0.2" from inside a v0.3 packet. `CLAUDE_HANDOFF.md` gets this right; `§71` is a fossil of the pre-split monolith and should be rewritten to point at the precedence order rather than at one file.

### X10 — Shop flavor text has no provider method

*(Skyiah + ChatGPT #14.)*

`DESIGN §28` and `§49` permit Epsilon to generate a shop display name and one flavor sentence per stock item. `TECHNICAL_ARCHITECTURE §7.5` defines the provider interface as exactly two methods: `generate_zone()` and `generate_echo()`. There is no `generate_shop()`, no request schema, no validation rules, and no fallback for it.

**Agreed with your call: cut it.** A third model call, a third schema, a third repair path, and a third fallback generator — for two sentences of text nobody will read twice. Fixed shop copy costs nothing and removes an entire provider surface from the build. If it comes back later it should be a field on an existing call, not a new one.

### X8 — `epsilon_creativity` is a campaign setting that isn't in the campaign save

`DESIGN §33` defines it, `§48` puts it in the main menu, `APWORLD_SPEC §9.1` clarifies it's a runtime setting rather than a YAML option — and `§40`'s save schema has no field for it. Reload behavior is undefined: does a campaign remember it was Unhinged?

---

## 5. Gaps — decisions that must exist before an unattended pass

### G1 — The starved-pool state is undefined, and it *will* happen

With 0 Pepsi Keys, only Checks 001–010 are eligible: 10 locations, minus up to 2 reserved by the shop, at 3 per Zone. That is three Zones and change. Then the player has **nothing to do** until another player finds a Pepsi Key.

`§13.4`'s selection algorithm has no empty-pool branch. `§49`'s Hub portal has no "nothing available" state. `§52` treats this as a feature ("other-player progress can directly expand Archipepsi's available campaign") — which it is! — but never specifies what the game looks like while you wait.

This is the most likely thing to happen in the actual six-player demo, and it's currently undefined behavior at the Hub portal.

**Needs:** portal disabled with an explicit `WAITING FOR A PEPSI KEY` Hub state; a status board line explaining that other players hold your progression; a decision about whether the shop still stocks while starved (it draws from the same pool, so stocking makes starvation worse); and a decision about whether a 1-check Zone is allowed as a stopgap (`§13.4` currently permits 1 only as a *final* Zone).

### G2 — There is no way out of a Zone

`§50` says "return/open route to Hub." No chamber type provides an exit, and `§14.1`'s chaining contract ends at the last chamber's exit transform. Also undefined: can the player leave a Zone before completing it? (`active_zone_id` persisting implies yes.) Can they re-enter? What happens to objective progress?

**Needs:** an engine-appended exit portal after the final chamber, plus a pause-menu "Return to Hub," plus a stated rule for partial progress on re-entry.

### G3 — `kill_all` latching versus enemy respawn

`§36` permits enemies to respawn when the player dies. If a chamber's `kill_all` was already satisfied and the player then dies elsewhere in the Zone, does the reward re-lock?

**Needs:** one sentence — objective completion latches per chamber for the Zone's lifetime and is not undone by respawn.

### G4 — Save writes are not atomic

The entire design is organized around "a crash or disconnect must never corrupt the campaign," and then `§40` specifies plain JSON writes at every transaction. A crash mid-write during the save-before-send step — the *exact* moment the design is protecting — truncates the campaign file.

**Needs:** write-temp-then-rename, and a stated recovery behavior if the primary file fails to parse (keep one backup generation).

### G5 — Godot cannot run at all without Python, including Mock Campaign

`§47` puts Mock Campaign in the **bridge**. So there is no way to exercise the engine slice — the part most likely to need iteration and visual checking — without the Python process running. That's an unnecessary coupling for the first milestone.

**Needs:** either a small Godot-side offline fixture (a static JSON snapshot loaded when no bridge is present), or an explicit acknowledgement that Python is always required.

### G6 — No bridge reconnect or heartbeat behavior

If the bridge process dies, Godot's WebSocket drops. Undefined: retry policy and backoff, what the UI shows, and whether an in-flight `epsilon_generate_zone` request is retried or abandoned. Note that `§43`'s "the player must never become permanently stuck waiting" depends on this, and a dead bridge is the most likely way to get stuck.

Related: the protocol has no `request_id` on AP operations and no ack for `ap_goal`.

### G7 — Godot version is unpinned

`§7.1`: "Use the already-installed compatible Godot version on the development machine." An unattended agent has no such machine. Pin an exact 4.x version and state the `project.godot` feature tags.

### G8 — No test runner exists for the 25 Godot tests

`§62` enumerates 25 Godot tests. Godot ships no test framework. GUT and gdUnit4 are addons with real setup cost; the alternative is plain `--headless --script` test scenes.

**Needs:** pick one, or cut the list to what a headless script can assert (builder geometry, validation, save round-trip) and explicitly mark the rest as manual.

### G9 — The Pydantic models and JSON Schemas are promised but not written

`§19` says "the implementation must define an equivalent Pydantic model and JSON Schema," and the layout lists three `schemas/*.json` files. Hand-deriving those from prose is exactly where drift enters — and then there are *three* validators (Pydantic, JSON Schema, and whatever Godot does defensively) that must agree.

**Strong recommendation:** ship the actual Pydantic model source *in the packet*. It removes an hour of work, removes a decision, and makes one artifact the single source of truth — export the JSON Schema from Pydantic rather than maintaining both. Godot then does only defensive allowlist checks before instantiating anything.

### G10 — Epsilon Static is 60% of the item feed and does nothing

The Archipepsi player receives their own world's 30 items back: 2 Pepsi Keys, 10 Epsilon Coins, and **18 Epsilon Static** — which `§9.4` defines as "none beyond a small receipt/notification if desired."

So most of the "you got an item!" moments in the entire campaign are nothing. That's a flavor problem in a game whose whole thesis is that receiving items should feel good.

It's AP-`filler`, so it can't touch logic — but a tiny non-logic effect is free and safe: +1 max HP, a cosmetic Hub glitch that accumulates, a static-y screen effect, a counter Epsilon can reference in Zone flavor text. Cheap, on-theme, and it makes the feed feel alive.

### G12 — When does the finale unlock? (open decision)

*(Skyiah + ChatGPT #6.)* Follows directly from B5: once 030 is reserved for a finale Zone, something has to say when that Zone is offered.

Currently the only gate is Tier 2, i.e. the second Pepsi Key. If that's the whole condition, a lucky seed that delivers both Keys early lets you finish having cleared maybe 8 of 30 checks — and the campaign's entire premise (the seed's item pool becomes your game) never gets to happen. The opposite extreme, requiring all 29, makes you hostage to whichever straggler is sitting unreserved in a shop batch you can't afford.

**My recommendation: 2 Pepsi Keys AND ≥24 of the other 29 checks confirmed** (~80%), with the finale portal showing its own progress (`FINAL CORE — 19 / 24`).

Why 24 rather than 29: it leaves five checks of slack, so you're never blocked by one awkward location, and it survives the starved-pool state in G1. Why a count at all: it's one integer, trivially tunable after the first real playthrough, and it makes the finale feel earned rather than stumbled into.

**One Archipelago note that makes this safe:** the AP-side completion condition is `state.has("Victory")` with the Victory event in Tier 2, so Archipelago's generator believes goaling requires only 2 Keys. A runtime that is *stricter* than AP logic is harmless — it only means you take longer than the solver assumed, and the seed stays beatable. (The dangerous direction is the reverse, a runtime looser than logic, and this isn't that.) So you can pick any threshold up to 29 without touching the APWorld.

### G13 — The save schema can't represent an allocated-but-ungenerated Zone

*(Skyiah + ChatGPT #8.)*

`DESIGN §13.4` step 9 is emphatic and correct: "Save the chosen location IDs **before** calling Epsilon." That's the right ordering — it's what stops a crash mid-generation from orphaning locations or double-allocating them.

But `§40`'s save schema has nowhere to put them. It has `zones` (accepted Zone JSON), `active_zone_id`, `generation_counter`, and `shop.reserved_location_ids`. There is no field holding "locations 12/13/14 are committed to a Zone that doesn't exist yet."

So the crash window the rule exists to protect is unrepresentable, and an implementer has to invent the recovery behavior. Worse, those locations are invisible to the shop's eligibility check (`§28` excludes locations "assigned to current saved Zone" — a Zone that hasn't been saved yet), so they can be double-sold. See B5.

**Fix:** give Zones an explicit lifecycle in the save, as you proposed:

```
PENDING_GENERATION -> GENERATED -> ACTIVE -> COMPLETE
```

with `allocated_location_ids` populated at `PENDING_GENERATION`. On load, a Zone found in `PENDING_GENERATION` re-runs generation against its already-committed IDs (never re-allocates), and every allocation-eligibility check excludes locations held by any Zone not yet `COMPLETE`.

### G14 — Echo effect compatibility is undefined

*(Skyiah + ChatGPT #12.)*

`§23`'s compatibility rule only says a `primary` Echo needs an active effect and a `passive` Echo needs a passive one. Nothing rejects `knockback_target` alone (knock back *what*, with what?), or `recoil_self` + `heal_self` (recoil from drinking a potion), or `dash` + `modify_gravity` on the same Echo.

Given `§24` allows 1–3 effects from a 10-name vocabulary, that's a lot of legal nonsense the validator will pass straight into gameplay code that isn't expecting it.

**Proposed taxonomy — three classes, two dependency rules:**

| Class | Effects |
|---|---|
| **Initiators** (do something on activation) | `hitscan_damage`, `projectile_damage`, `dash`, `grapple_to_surface`, `heal_self`, `shield` |
| **Modifiers** (change what an initiator did) | `recoil_self`, `knockback_target` |
| **Passives** (apply while equipped) | `modify_gravity`, `modify_speed` |

Rules:

1. `activation: primary` → exactly 1 initiator, plus 0–2 modifiers. No passives.
2. `activation: passive` → 1–2 passives. Nothing else.
3. Both modifiers require a damage initiator (`hitscan_damage` or `projectile_damage`) in the same Echo. `knockback_target` has no meaning without something that hits; `recoil_self` on a heal is incoherent.

That's three lines in the validator and it eliminates the whole class. It also preserves everything the packet actually wants — the Conference Call example (`hitscan_damage` + `recoil_self` + `knockback_target`) is exactly rule 1 plus rule 3.

### G15 — Passive Echoes carry a cooldown that means nothing

*(Skyiah + ChatGPT #13.)*

`§22` puts `cooldown` at the Echo level and `§24` bounds it at 0.15–15s, but a `passive` Echo never activates, so its cooldown is dead data the model still has to emit and the validator still has to bound.

You're right that the shape is the real answer: the Echo schema should be a **discriminated union on `activation`**, not one flat object with fields that are conditionally meaningless.

```
PrimaryEcho: activation="primary",  cooldown: float (required),  effects: [1 initiator + 0-2 modifiers]
PassiveEcho: activation="passive",  (no cooldown field),          effects: [1-2 passives]
```

Pydantic models this natively (`Field(discriminator="activation")`), it makes G14's rules structural rather than imperative, and it gives the model a much clearer target — which measurably reduces repair attempts. Same treatment is worth considering for chambers, where `corridor` and `treasure_room` currently share a field bag with `arena` and `tower`.

### G16 — Art sourcing is undefined, and that's a half-hour trap

*(Skyiah + ChatGPT #18.)*

`§55` specifies the look (16×16 / 32×32, nearest-neighbour, flat materials) but never says where a single texture file comes from. An unattended agent facing "make it look like Minecraft" and having no assets will plausibly go looking for a CC0 texture pack, evaluate licenses, and lose 30–45 minutes of a 5-hour budget on art archaeology.

**Strongly agree with your instinct — say it explicitly and imperatively in the packet:**

> Do not search for, download, or evaluate external asset packs. Themes are `StandardMaterial3D` with flat colours and `texture_filter = NEAREST`. If a texture is wanted, generate it procedurally at runtime with `Image.create()` — a 16×16 two-tone checker or noise pattern per theme, written in code, is the entire art budget. No image files ship in the first pass.

Six theme palettes as six colour triplets is maybe 20 lines of GDScript, looks appropriately terrible in the way `§3.4` wants, and costs zero minutes of browsing.

### G17 — Runtime Claude API access is an unlisted prerequisite

*(Skyiah + ChatGPT #21.)*

`§46` assumes `ANTHROPIC_API_KEY` and a configured model ID. Worth stating plainly in the README's setup section, because it's a genuinely separate thing from having Claude help build the project: **Archipepsi making runtime API calls needs its own API access and credits.** Having Opus in an editor doesn't provide that.

The architecture already handles the absence correctly — `§46` says the bridge starts, AP works, and live campaigns use the deterministic fallback provider. That's the right degradation. It just needs to be visible up front, and it reinforces S2's point that **real AP + fallback Epsilon** is the most valuable test configuration in the project: the entire loop, no API cost, no nondeterminism.

### G11 — No LICENSE, `.gitignore` contents, or CI

Minor, but the layout lists `.gitignore` without contents (Godot's `.godot/`, `*.import`, Python's `__pycache__`, `.env` — and `.env` matters, given `§46` holds an API key).

---

## 6. Fun and feel risks

### F1 — The fun hypothesis rests almost entirely on ~10 Echo reveals

Structurally, the POC is ~10 Zones of "corridor → arena → touch the reward," built from 5 templates, 3 enemy archetypes, and 6 palettes. Epsilon's actual expressive range is: which template order, which palette, what things are named, and what the Echoes do.

That's *fine* for a technical POC — and the packet is honest that proving the pipeline is the goal. But `DECISIONS_TO_REVIEW §I` asks whether it's fun, and this build won't answer that, because the only genuinely novel-feeling moment in the loop is the reveal in `§39`.

**Implication for the build:** that reveal is the highest-leverage 30 minutes in the entire session. Freeze input, show the card, play a sound, hold for ~2 seconds, make it unmistakable that *the other player got the real thing and you got Epsilon's cursed reinterpretation*. Everything else in the POC is plumbing that proves the reveal can happen. Budget for it explicitly rather than treating it as polish that gets cut at T-30.

### F2 — Combat pacing is unbounded

`§20` allows 8 enemies in a chamber and 14 in a Zone, with `kill_all` objectives, against a Pepsi Pop described only as "low damage, short/moderate cooldown." Without numbers (B4) there is nothing preventing a chamber that takes four minutes of plinking. Appendix A bounds this deliberately.

### F3 — The shop may never appear in a live session

It requires 2 completed Zones **and** ≥2 Epsilon Coins delivered by other players. In a slow six-player seed the shop is decorative for hours. That's correct Archipelago behavior, but it means the acceptance demo cannot depend on live coin luck — Mock must fully exercise Test C, and the debug overlay's "simulate one Coin" needs a sibling "simulate one Pepsi Key."

### F4 — The goal is gated on other players

Check 030 is Tier 2, so finishing requires two Pepsi Keys, which normal fill may place anywhere in the multiworld. Great Archipelago citizenship; bad demo determinism. Consider a documented testing YAML variant with local keys, separate from the recommended six-player YAML.

### F5 — Nobody has estimated session length

`DECISIONS_TO_REVIEW` flags "how long should a normal Zone take." It matters for B3 and for whether 30 checks is right: at ~4 minutes per Zone, the POC is a ~40-minute game, which sounds correct. At 10 minutes it's a slog nobody will finish in a demo. Worth deciding, because it drives chamber size limits and enemy counts.

---

## 7. Scope and sequencing

### S1 — The riskiest work is scheduled third

`§64` runs: Phase 1 mock bridge + Godot slice → Phase 2 generation engine → **Phase 3 real Archipelago** → Phase 4 real Epsilon → Phase 5 shop.

But the AP integration is the part that is (a) genuinely novel and risky, (b) headlessly testable in minutes with no engine and no art, and (c) fatal to the concept if it doesn't work. The Godot side degrades gracefully — an ugly room is still a room. The AP side does not.

Phase 1 also builds a whole mock bridge whose AP surface gets replaced in Phase 3.

**Recommended resequence:**

1. **APWorld + generate a real seed** (~45 min, fully verifiable — `generate` either succeeds or doesn't). This also flushes out C4 immediately.
2. **Bridge + real AP connection + scout + check, driven from a CLI smoke test** (no Godot). Proves the entire scary half, testable in pytest.
3. **Godot slice against the real bridge** — Hub, player, one fallback-generated Zone, one reward, save/load.
4. **Fallback generators + validation** (deterministic, testable, and they're the test oracle for the builders).
5. **Claude provider.** Last, because everything works without it.
6. **Shop.** Genuinely last — it's an alternate path to an already-working transaction.

Under this order, a pass that runs out of time at step 3 still leaves a real, connected, provable vertical slice. Under the current order, running out of time at Phase 2 leaves a mock game that has never talked to Archipelago.

### S2 — Two mock axes are blended into one concept

"Mock Campaign" (fake AP) and "Mock Epsilon" (fake model) are orthogonal but the packet treats them as one mode. Keep them independent: `--ap=mock|real` × `--epsilon=mock|claude|fallback`. Six combinations, all useful, and "real AP + fallback Epsilon" is the most valuable test configuration in the project — it exercises the entire loop with no API cost and no nondeterminism.

### S3 — `§66` ranks milestones but gives no stopping rule

Add: at T-60 minutes, stop adding features. Make the highest completed milestone run. Write `docs/NEXT_STEPS.md`. Commit. The instruction "do not sacrifice a completed earlier milestone" exists but has no trigger attached to it.

---

## 7.5 Known limitations — document, don't fix

Both of these are correct consequences of decisions the packet made deliberately. They belong in the README's "known limitations" section so nobody later mistakes them for bugs.

### L1 — Deleting the save restores spent coins

*(Skyiah + ChatGPT #23.)* Archipelago remembers every `Epsilon Coin` it delivered; spending is intentionally local (`§30`, `§40`). So deleting or moving the campaign save resets `coins_spent` to zero while `coins_received` is recomputed from the server at full value — free coins.

This is unavoidable given the design's own (correct) split: AP owns delivery, the local save owns spending. AP has no concept of `coins_spent` and shouldn't. The only fix would be pushing the ledger into AP data storage, which is a real option later but not POC work.

Worth noting the exploit is also self-limiting — the locations you bought stay checked server-side, so you get the coins back but not the purchases.

### L2 — Duplicate source items produce independent Echoes

*(Skyiah + ChatGPT #24; already flagged in `DECISIONS_TO_REVIEW §F`.)* Echo identity is `source_location_id`, so two separately-sent Hookshots become two unrelated Hookshot Echoes with different mechanics.

Agreed this needs a conscious "yes" rather than being inherited by default — and my read is that it's the right yes. It's the most on-theme consequence of the entire design: the Echo is Epsilon's *reading* of an item, not the item, and the same word read twice giving two answers is exactly what a "local AI handed a box of videogame Legos" would produce. It also costs nothing to implement, because it's what falls out of the dedup key you already need.

The one thing worth adding if you keep it: show the source location in the inventory (`§38` already lists source game and recipient), so two Hookshots are visibly *Check 012's Hookshot* and *Check 026's Hookshot* rather than a confusing duplicate.

---

## 7.6 One disagreement: the input binding (X1 / your #10)

Your proposed rule:

> Active Echo equipped → left-click Echo. Passive Echo or none → left-click Pepsi Pop.

This resolves the contradiction, and it's clearly better than what's in the packet. I'd still push back on it, for two reasons:

**It makes the safety guarantee conditional on player knowledge.** `§35` and `§54` both promise that every mandatory encounter is beatable with Pepsi Pop. Under this rule, equipping an active Echo *removes* Pepsi Pop — so the promise becomes "beatable with Pepsi Pop, provided the player realises they should unequip." That's a real trap: the player who just got a shiny new Echo is the least likely to unequip it, and a bad Echo roll (25 damage but a 15-second cooldown, both legal under `§24`) is strictly worse than Pepsi Pop in a `kill_all` room.

**Modality costs more than a second button.** "Equipping changes what my main attack is" means every Echo pickup silently rebinds the player's primary verb.

**Alternative: LMB = Pepsi Pop always. RMB = activate equipped Echo (passives ignore it).**

The guarantee becomes unconditional and needs no player understanding. Echoes read as pure addition rather than a trade. The genuinely fun case — fire the Conference Call, get launched backwards, keep plinking with Pepsi Pop on the way down — only exists with two buttons. And it's *less* code: no conditional rebinding, no "does this Echo replace my attack" branch.

The cost is one more binding to teach, which a line in the Hub handles.

Not a blocker either way — but the guarantee-without-caveats property is worth the button.

---

## 8. What I'd do in pass 2

In priority order.

**Needs a decision from you first — everything else is downstream:**

1. **B1** — bridge dependency strategy: AP source checkout, or hand-rolled client?
2. **B2** — does campaign state move into Python, or stay in GDScript?
3. **G12** — finale unlock condition (my proposal: 2 Keys + 24/29 checks).
4. **B4** — pin the movement and combat numbers (Appendix A, or your own after a feel test).
5. **G1 + G2** — the starved-pool state and the Zone exit. These are missing *game*, not missing detail.

**Mechanical once those are settled:**

6. **Fix B5.** Exclude Check 030 from shop and normal allocation; make the finale a reserved 1-check Zone.
7. **Fix C1–C5.** Small edits, large consequences. C4 is literally one line and prevents a hard generation failure.
8. **Add the Zone lifecycle to the save schema (G13)** — `PENDING_GENERATION → GENERATED → ACTIVE → COMPLETE` with `allocated_location_ids`. Interlocks with B5 and C2.
9. **Fix X1** (input binding) — see §7.6 for the disagreement.
10. **Ship the actual Pydantic models in the packet (G9, G14, G15).** Discriminated unions on `activation` and chamber `type`; the compatibility rules become structural. This is the single highest-value hour of pass 2 — it converts prose into the artifact that is simultaneously the validator, the JSON Schema, and the spec.
11. **Cut Epsilon shop flavor (X10).** Removes a provider surface.
12. **Write the art policy (G16)** as an imperative "do not browse" instruction.
13. **Sweep the doc errors** (X2–X9) and unify all fixture data onto `§47`'s canonical table.
14. **Resequence the build order (S1)** and add the cut line (S3).
15. **Cheap and worth it:** G10 (make Epsilon Static do something), C7 (untrusted-string paragraph), G4 (atomic saves), G17 + L1 + L2 (README limitations section).

A realistic pass 2 is items 6–15 as a single editing session, gated on answers to 1–5.

---

## Appendix A — Proposed constants (for B4)

Offered as a *starting table*, derived so the pieces are consistent with each other. These want a feel test — but they are self-consistent, which is the property that matters most for the validator, and they beat letting an unattended agent invent them.

### Movement (Godot 4, `CharacterBody3D`, units = meters)

| Constant | Value | Note |
|---|---|---|
| `GRAVITY` | `24.0 m/s²` | Godot's 9.8 is too floaty for a snappy FPS |
| `WALK_SPEED` | `7.0 m/s` | "medium-fast walk," no sprint (`§34`) |
| `JUMP_VELOCITY` | `8.0 m/s` | |
| `COYOTE_TIME` | `0.12 s` | `§34` asks for a small window |
| `JUMP_BUFFER` | `0.10 s` | forgiving, per `§34` |
| `AIR_CONTROL` | `0.4` | fraction of ground acceleration |
| `PLAYER_HEIGHT` / `RADIUS` | `1.8` / `0.4` | |
| `EYE_HEIGHT` | `1.6` | |
| `FALL_KILL_Y` | `-30.0` | respawn at Zone start (`§34`) |

**Derived, and this is the point:**

- Apex height = `v²/2g` = `64/48` = **1.33 m**
- Airtime = `2v/g` = **0.67 s**
- Theoretical flat gap = `7.0 × 0.67` = **4.67 m**

| Validator constant | Value | Rationale |
|---|---|---|
| `SAFE_BASE_JUMP_GAP` | **`3.0 m`** | ~64% of theoretical — survives imperfect timing, imperfect approach speed, and air control |
| `MAX_VERTICAL_STEP` | **`1.0 m`** | comfortably under the 1.33 m apex |
| `MIN_PLATFORM_SIZE` | **`2.5 × 2.5 m`** | forgiving landings |

This replaces `§34`'s "the game must measure/store one constant" with a value that is *derived* from the movement constants and can be asserted in a unit test — no in-engine measurement rig required. If you retune movement, recompute the gap from the same formula and the guarantee holds.

### Combat

| Entity | HP | Damage | Cooldown | Speed | Pepsi Pop TTK |
|---|---|---|---|---|---|
| Player | 100 | — | — | 7.0 | — |
| Pepsi Pop | — | 6 (hitscan, 40 m) | 0.35 s | — | 17 DPS |
| `melee` | 24 | 6 (2.0 m reach) | 1.0 s | 4.0 | ~1.4 s |
| `ranged` | 16 | 8 (projectile, 14 m/s) | 2.0 s | 0 (static) | ~1.0 s |
| `brute` | 120 | 18 (2.5 m reach) | 1.6 s | 2.2 | ~7 s |

**Bounds this produces:** worst legal chamber (8 `melee`) ≈ 11 s of sustained fire. Worst legal Zone (14 enemies incl. 1 `brute`) ≈ 25 s of total shooting. That's bounded and non-slog — which is the property F2 needs.

It also preserves the packet's intent in `§35` ("Epsilon should prefer making Echo weapons much more satisfying than Pepsi Pop"): a mid-range Echo at the `§24` bounds — say 12 damage × 3 pellets on a 0.8 s cooldown — is roughly **2.6× Pepsi Pop's DPS**. Base attack stays viable, Echo weapons feel like a real upgrade.

| Other | Value |
|---|---|
| Respawn delay | `1.5 s` (fade at Zone start) |
| Fall damage | none (fall-out respawns instead) |
| Enemy aggro radius | `18 m` |
| `brute` per Zone | 1 (already in `§20`) |

---

## Appendix B — Verification sources

Claims about Archipelago behavior in this audit were checked against primary sources rather than recalled:

- [Archipelago Network Protocol](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md) — `create_as_hint` semantics, `items_handling` bits, `RoomUpdate.checked_locations` as a *partial* update, `_read_race_mode`, `ClientStatus.CLIENT_GOAL = 30`
- [`MultiServer.py`](https://github.com/ArchipelagoMW/Archipelago/blob/main/MultiServer.py) — `register_location_checks`: `new_locations = set(locations) - already_checked`, broadcast guarded by `if new_locations:` (C1)
- [`CommonClient.py`](https://github.com/ArchipelagoMW/Archipelago/blob/main/CommonClient.py) — import-time dependency on `MultiServer`, `NetUtils`, `Utils`, `worlds` (B1); `check_locations()` filters against `missing_locations` (C1)
- [Archipelago World API](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/world%20api.md) — `origin_region_name` (C4), ID range rules (IDs may overlap other games', so `891xxxxx` is fine), event/locked-item creation, `completion_condition`
- [apworld Specification](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/apworld%20specification.md) — `archipelago.json` fields, official "Build APWorlds" packaging (C5)
- [Godot `WebSocketPeer`](https://github.com/godotengine/godot-docs/blob/master/tutorials/networking/websocket.rst) — client usage; `send_text` is the correct call for JSON text frames
- PyPI — no Archipelago multiworld package published; `archipelago` on PyPI is an unrelated CGRA tool (B1)
