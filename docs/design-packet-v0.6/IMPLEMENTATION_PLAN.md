# Archipepsi — Implementation Plan (v0.6)

How to sequence the build while always preserving a running vertical slice. This file is *not* product truth; it never overrides the authorities.

---

# 1. Success criterion for the autonomous pass

**Get as far down the ordered plan below as possible while always leaving a working, runnable milestone.**

That is the criterion. It is deliberately not "finish the POC."

The full surface — 5 chamber builders, 3 enemy archetypes, 10 Echo effects, a first-person controller, 5 UI screens, save and reconcile, a WebSocket protocol, an AP client, an APWorld, 3 providers, validation and repair and 2 fallback generators, tests, docs — is multi-day work for a person. Structuring the session as "finish everything" produces six subsystems at 70% and nothing that runs. Structuring it as "advance the slice, never break it" produces something playable at every hour mark.

If the whole thing finishes, excellent. The plan is ordered so that stopping anywhere still leaves something real.

**Expected outcome, stated honestly: Phases 0–2.** The phase estimates sum to roughly 400 minutes against 180–240 minutes of feature time once T−60 is reserved — the plan overruns its own window before any debugging. Phase 0–2 is a working, tested APWorld and bridge with the entire campaign machine provable headlessly, which is exactly what "build the risky half first" was aiming at. Phase 3 is the stretch goal, and in an environment without a Godot binary it is unverifiable regardless.

Plan for 0–2. Be pleased by 3.

## 1.1 The T−60 rule — binding

**T−60 minutes is a feature freeze. No new subsystems after that point.** No exceptions, no "just one more subsystem."

From T−60 onward the only permitted code changes are **regression fixes** to what is already implemented. Not new features, not "finishing" a phase that is half-built, not starting the next one. If a subsystem is incomplete at T−60 it stays incomplete and is described in `NEXT_STEPS.md`.

**The goal is to leave the highest completed vertical slice fully running — not six later systems half-finished.**

### The T−60 gate

Run **every automated test applicable to the systems actually implemented**, then fix regressions only.

Each row below names a *system*, not a phase range. v0.5's table gated on phases and lumped whole numeric ranges together — "campaign / allocation tests 21–35, Phase 2 onward" — but 27, 28 and 31–33 in that range need the shop and the finale, which are **Phase 6**. So the plan's own expected stopping point, Phase 0–2, could not pass its own gate. Read every row as "run this if and only if the system named on the right exists."

All test numbers refer to `ACCEPTANCE_TESTS.md`.

| Gate item | Run it when |
|---|---|
| Schema tests (`schemas/test_schemas.py`, 91) | **Always.** They ship green, so any failure is a regression you introduced |
| APWorld tests **36–47** | the APWorld generates a seed |
| APWorld test **48** | `.apworld` packaging is implemented |
| Bridge tests **1–18**, **20** | the bridge connects and holds campaign state |
| Provider tests **13–15** | any Epsilon provider and the fallback exist |
| Campaign tests **21, 22, 24, 25, 26, 29, 30, 34, 35** | allocation, tiers and coin accounting exist |
| Regression tests **60–66** | the bridge holds campaign state (they are the v0.6 campaign-integrity tests) |
| Shop tests **19, 23, 27, 28** | the shop exists |
| Finale tests **31, 32, 33** | the finale exists |
| Godot tests **49–52, 56–59** | the corridor/arena builders and the claim flow exist |
| Godot tests **53, 54, 55** | the platform_path / tower / treasure_room builders exist |
| End-to-end **A, D, I, L, M, P** | the Godot slice runs against the bridge |
| End-to-end **B, H, K** | real or mock AP drives received items |
| End-to-end **E, F** | provider failure and repair paths exist |
| End-to-end **G** | the race-mode guard exists |
| End-to-end **C, O** | the shop exists |
| End-to-end **J, N** | the finale exists |

**The expected Phase 0–2 stop therefore gates on exactly:** schema tests (91), APWorld 36–47, bridge 1–18 and 20, provider 13–15, campaign 21/22/24/25/26/29/30/34/35, and regression 60–66. Everything else is absent by design at that point. Their absence is expected, is not a failure, and is recorded in `NEXT_STEPS.md` rather than chased.

Record every result honestly, **including failures**. A truthful "Test A fails at reconnect, cause unknown" is worth far more than a green summary that was never run.

### The rest of the hour

1. Make the highest completed milestone actually run, end to end, from documented commands.
2. Run the gate above. Fix regressions only.
3. Update `README.md` with exact setup and run commands, and the known limitations from `DESIGN.md` §18.
4. Update `docs/IMPLEMENTATION_DECISIONS.md` with every deviation and assumption.
5. Write `docs/NEXT_STEPS.md` naming the exact next blocker.
6. Commit.

**Never sacrifice a working earlier milestone to leave a later subsystem half-integrated.** A working Phase 3 beats a broken Phase 5 every time.

---

# 2. Build order

v0.3 ran mock-bridge → generation engine → real Archipelago → real Epsilon → shop. v0.4 reorders it, because the Archipelago integration is the part that is genuinely novel, headlessly provable in minutes, and fatal to the concept if it does not work — while the Godot side degrades gracefully. An ugly room is still a room; a broken AP client is not a game.

Running out of time at Phase 3 below leaves a real, connected, provable slice. Running out of time under the old order left a mock game that had never spoken to Archipelago.

### Phase 0 — Foundation (~45 min)

0. **Verify the toolchain before anything else.** `git`; `python --version` in [3.11.9, 3.14); `godot --version` matching `4.5.1.stable`; network reachability to github.com.
   **If Godot is absent:** do not install it and do not go looking. Build Phases 0–2 (all Python, all verifiable), write the Phase 3 GDScript unverified, and say so plainly in `NEXT_STEPS.md` and at the T−60 gate. An honest "engine layer written but never run" is worth more than a silent one.
1. Repo skeleton, `Makefile` (including the §8.5 targets), `.gitignore` (`.archipelago/`, `.env`, `.godot/`, `__pycache__/`, `.pytest_cache/`, `*.tmp`, `*.bak`).
2. Copy `schemas/` from the packet into `bridge/archipepsi_bridge/schemas/` **verbatim**. Do not retype them.
3. `python -m pytest` on the packet's schema tests — 91 tests, all green, before anything else is written. They pass both standalone and from the repo root; if they do not, you copied them wrong.
3b. `python docs/design-packet-v0.6/check_packet.py` — proves the packet's prose still matches the schemas you just copied. It is also the guard to re-run if you ever edit the packet.
4. `bootstrap.py`: clone Archipelago at `0.6.7`, run `ModuleUpdate.py --yes`, verify `import CommonClient` with `SKIP_REQUIREMENTS_UPDATE=1`.

**Milestone: `make setup && make test` works on a clean machine.**

### Phase 1 — APWorld (~45 min)

5. `apworld/archipepsi/` — items, locations, 3 regions + origin, Victory event, slot data.
6. **Set `origin_region_name` correctly** or name the origin region `Menu`. This is a hard generation failure if wrong.
7. `archipelago.json` manifest.
8. Both example YAMLs.
9. `make world-install && make seed` — a real solo seed. Then a multiworld seed with a partner world of ≥10 locations and `non_local_items: Epsilon Coin`.
10. APWorld self-checks from `APWORLD_SPEC.md` §9.

**Milestone: `make seed` produces a zip. Fully verifiable, no engine involved.**

Generation is the only thing that catches a bad `origin_region_name` — module-level unit tests will not. Do not declare this phase done on tests alone.

### Phase 2 — Bridge and real Archipelago (~75 min)

11. WebSocket server, intent dispatch, `campaign_snapshot` emission.
12. `CommonContext` subclass: connect, auth, `items_handling = 0b111`, slot data.
13. Race-mode guard via `_read_race_mode`.
14. Bulk scout all 30 with `create_as_hint = 0`; normalize `NetworkItem` in recipient-game context.
15. Reconstruct `items_received`; derive Signal Keys, Coins, Static.
16. `campaign.py`: track order, allocation, tier gating, finale gating, eligibility, starvation handling.
17. `store.py`: atomic save/load with `.bak` recovery.
18. `transactions.py`: pending checks, **reconciliation-based finalization** (never event-waiting — see `TECHNICAL_ARCHITECTURE.md` §5).
19. `mock_ap.py` with the canonical fixture.
20. **Fallback Zone and Echo generators** (`EPSILON_SPEC.md` §12), plus `MockEpsilonProvider`. Moved here from Phase 4: without a provider there is nothing to generate, and step 21's milestone is unreachable. Fallback output goes through the same validator as model output, which is what makes it a test oracle rather than a bypass.
21. A **CLI smoke test** that drives the whole loop with no Godot: connect → scout → allocate → fallback-generate → claim → confirm → echo → snapshot.

**Milestone: the entire campaign machine works headlessly, against a real server and against mock AP. This is the riskiest part of the project and it is now done.**

### Phase 3 — Godot vertical slice (~150 min)

22. `bridge_client.gd` autoload: WebSocket, reconnect with backoff, snapshot handling.
22. Generated `constants.gd` (`python schemas/export.py`).
23. Main menu → connect / Mock Campaign.
24. Hub scene with the portal, status board, and all eight `HubStatus` modes including `GENERATING`, `ZONE_READY` and `WAITING_FOR_AP`. Drive the portal from `mode` alone; do not track a local generating flag.
25. First-person controller using the binding constants. LMB Static Pulse, RMB Echo.
26. `corridor` and `arena` builders; linear chaining; the appended exit portal.
27. `melee` enemy; objective latching; reward objects and the claim flow.
28. **The reveal sequence** (`DESIGN.md` §16). Treat as core, not polish.
29. Echo runtime for `hitscan_damage` + `recoil_self` + `knockback_target` — enough for Conference Call.
30. Echo inventory; equip and cycle.
31. `enter_zone`, `leave_zone`, `exit_zone`, `abandon_zone` — including the Hub-side Abandon control (see below).

**Milestone: launch, connect, enter a generated Zone, clear a Check, watch the reveal, equip and fire the Echo, return to Hub, quit, reload, same state. This is the demo.**

### Phase 4 — Complete the catalogs (~45 min)

32. `platform_path`, `tower`, `treasure_room` builders.
33. `ranged` and `brute` enemies.
34. Remaining Echo effects: `projectile_damage`, `dash`, `grapple_to_surface`, `heal_self`, `shield`, `modify_gravity`, `modify_speed`.

**Milestone: every catalog entry works with `--epsilon=fallback`, no API needed.**

### Phase 5 — Real Epsilon (~30 min)

36. `ClaudeEpsilonProvider` with structured output against the exported JSON Schema.
37. Zone and Echo prompts; untrusted-input wrapping.
38. One repair attempt with verbatim validator errors; timeout → fallback.
39. Generation archive.

**Milestone: live Epsilon designs a real Zone, and disabling the key degrades cleanly.**

### Phase 6 — Shop and finale (~30 min)

40. Deterministic stock selection, pricing, cadence, the never-starve rule.
41. Purchase transaction sharing the pending ledger; rollback on the real trigger.
42. Reservation release and return-to-pool.
43. Finale gating and goal reporting.

**Milestone: full POC.**

### Phase 7 — Acceptance

44. Run `ACCEPTANCE_TESTS.md` end to end.
45. Build the `.apworld`.
46. README, `IMPLEMENTATION_DECISIONS.md`, `NEXT_STEPS.md`.

---

# 3. Mock development mode

Two **independent** axes: `--ap=mock|real` × `--epsilon=mock|claude|fallback`. v0.3 blended them into one "Mock Campaign" concept; keeping them orthogonal matters because **real AP + fallback Epsilon** is the most valuable configuration in the project — the whole loop, no API cost, no nondeterminism.

`mock_ap.py` provides a fake seed/team/slot, 30 fake locations, deterministic recipient games, fake received Keys and Coins, and can simulate connecting, scouting, confirming checks, receiving another Coin, and reconnecting with identical state.

## 3.1 Canonical fixture

**Use this table everywhere** — mock AP, acceptance tests, doc examples, prompt examples. v0.3 had four mutually inconsistent versions of it scattered across documents, and a literal-minded agent builds its fixtures from whichever it reads first.

| Check | Item | Recipient | Game |
|---|---|---|---|
| 001 | Conference Call | BL2Player | Borderlands 2 |
| 002 | Hookshot | Sage | Ocarina of Time |
| 003 | Wing Cap | Mario | Super Mario 64 |
| 004 | Estus Shard | Ashen | Dark Souls III |
| 005 | REP | Faux | Bomb Rush Cyberfunk |
| 006 | Epsilon Coin | **Skyiah (self)** | Archipepsi |

Check 006 exercises the self-recipient path: no Echo is generated, normal `ReceivedItems` handles it.

Fill 007–030 deterministically with a mix of foreign items and the native pool, ensuring at least 2 Signal Keys and several Coins arrive.

---

# 4. Rules for the coding agent

## 4.1 Do not redesign

Implement this specification. If a detail is missing, choose the smallest implementation consistent with playability, data safety, future local-model replacement, and the product principles. Record the choice in `docs/IMPLEMENTATION_DECISIONS.md`. Do not stop for minor aesthetic decisions.

## 4.2 No fake critical path

A POC feature can be ugly. It cannot be fake if it is on the acceptance path. These must genuinely work: AP connection, scouting, location checking, received-item reconstruction, Echo use, coin spending, save/load, reconnect.

## 4.3 Prefer fallback over blocking

Provider unavailable → fallback. Theme asset missing → default material. Chamber type unfinished → arena or corridor. Enemy navigation failing → simple steering. Never let polish block the core loop.

## 4.4 Never weaken validation

Repair or fall back. No `eval`. No dynamically loading scripts from model output. No turning arbitrary strings into class names. Never relax a bound to accept a bad response — and never clamp instead of rejecting.

## 4.5 Provider-independent state

No saved Zone or Echo may contain provider-specific response objects. Persist only normalized validated Archipepsi schemas.

## 4.6 Do not go asset shopping

Do not search for, download, browse, or evaluate external asset packs, texture packs, or model libraries. Materials and 64×64 procedural textures written in code. No Blender. See `DESIGN.md` §20.

## 4.7 Schemas are copied, not rewritten

`schemas/` ships with this packet, runs, and is tested. Copy it verbatim. Regenerate JSON Schema and `constants.gd` with `export.py`. Do not retype the models from the prose — the prose describes them, the code *is* them.

---

# 5. Definition of done, by milestone

**Core** — repo starts from documented commands; the APWorld generates; the bridge connects to a real server; all 30 locations scout; the Hub loads; the player moves, jumps, and fires Static Pulse; corridor and arena build; a Check can be claimed and confirmed; pending-check and save logic work; a Conference Call Echo can be acquired, equipped and fired; reload preserves Zone and Echo.

**Integration** — real checked/missing/received state reaches Godot; one foreign check creates one Echo; a Coin arrives without duplication; reconnect recovers; `WAITING_FOR_AP` displays correctly.

**Full POC** — Claude provider produces validated Zones and Echoes; fallback survives provider failure; the shop spends Coins transactionally against a real location; the finale unlocks at 2 Keys + 24 Checks; Check 030 reports goal; README documents setup and known limitations.

---

# 6. Handoff prompt

> Build the Archipepsi proof of concept described in this packet. Read `README.md` first for the authority order — no single document is the sole authority. Work autonomously and preserve a running vertical slice at all times; your goal is to get as far down `IMPLEMENTATION_PLAN.md` §2 as possible while never leaving the build broken, not to finish everything. Copy `schemas/` verbatim and run its tests before writing anything else; those models are the binding contract and `constants.py` is the binding source of every gameplay number. Do not redesign core rules. Do not execute model-generated code. Deterministic Python code owns AP location allocation and all persistent campaign state; Godot renders and simulates. Epsilon only designs presentation around already-selected locations. Mandatory routes must remain completable with base movement and Static Pulse. Use `CommonContext` from the pinned Archipelago checkout that `bootstrap.py` creates. Persist pending transactions before network send, and finalize checks by reconciling against `checked_locations` — never by waiting for a server event. Validate all Epsilon output, make exactly one repair attempt, then fall back. Do not go asset shopping. Record deviations in `docs/IMPLEMENTATION_DECISIONS.md`. **At T−60 minutes, stop feature work**, make the highest completed milestone run, update the docs, and commit.
