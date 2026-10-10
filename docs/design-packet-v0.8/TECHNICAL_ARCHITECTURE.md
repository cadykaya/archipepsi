# Archipepsi — Technical Architecture (v0.8)

Process boundaries, the Archipelago dependency, the Godot↔bridge protocol, campaign state ownership, persistence, transactions, failure behavior, security, and logging.

> **Authority:** see `README.md`. `schemas/` is binding over any prose here.

---

# 1. What changed in v0.5

v0.4 reshaped this document around two decisions; v0.5 keeps both and hardens what an independent audit found wrong with them.

**The campaign brain moved to Python.** In v0.3, Godot owned allocation, tier gating, the PRNG, the coin ledger, the pending-check state machine, shop reservations, the save file, and reconnect reconciliation. That is the correctness-critical half of the project, and it sat in the half that cannot be unit-tested, cannot be run headlessly, and has no test framework. Every bug class this design most fears — duplicated coins, lost checks, corrupted campaigns, reconnect desync — lived where nobody could exercise it.

In v0.4 the bridge owns persistent campaign truth and Godot owns the videogame.

**The Archipelago dependency is pinned and scripted.** It is not pip-installable, and importing it pulls in the whole `worlds` package — and runs pip (§4.3).

**v0.5 additions**, all from the pass-3 independent audit: the `GENERATED` Zone state now has real semantics (§8) instead of being an unreachable hole that orphaned AP locations; three genuine `CommonContext` behaviours are documented rather than assumed (§4.3, §4.6, §5); Zone-source pending checks got the terminal failure state only the shop path had (§5); the shop rollback got a connection guard (`DESIGN.md` §11.7); and §8.5 finally explains how to install the world, generate a seed and host a server — without which the Phase 1 and Phase 2 milestones are unverifiable.

---

# 2. Ownership split

| Owned by the **Python bridge** | Owned by **Godot** |
|---|---|
| AP connection, reconnect, scouting | Rendering, scene construction |
| Normalized AP state | First-person controller, physics |
| Campaign save file (atomic) | Player HP, respawn |
| Track order, cursor, generation counter | Living enemies, their HP, their AI |
| Location allocation and tier gating | Projectiles, hitscan, Echo effect execution |
| Deterministic PRNG | Objective progress in the current room |
| Coin ledger | UI, input, camera |
| Shop stock, pricing, reservations, cadence | Notifications and the reveal sequence |
| Pending check transactions | Transient Zone state |
| Echo registry and dedupe | |
| Epsilon providers, validation, repair, fallback | |
| Finale gating and goal reporting | |

The line is **persistent campaign truth vs. this frame of the videogame**. Nothing Godot owns survives leaving a Zone anyway, which is exactly why it does not need to be persisted or reconciled.

Consequence worth stating plainly: the entire cursed machinery — allocate, generate, validate, claim, confirm, echo, spend, reconnect — is testable in pytest before Godot is opened once.

**Godot is not an authority.** When Godot says "the player claimed the reward for location X in zone Y", the bridge re-verifies what it actually can: that a campaign is loaded, that the Zone is `ACTIVE`, that the location is in that Zone's `allocated_location_ids`, that it is not already confirmed, and that no pending transaction exists for it.

Be honest about the limit: the bridge **cannot** verify that the chamber's objective was really satisfied — it does not simulate enemies. Objective gating is enforced client-side, so a modified client could claim early. That is acceptable for a single-player POC; the check that matters is that a claim can never invent, duplicate, or misroute an AP location, and that one is enforced server-side by the allocation record.

---

# 3. Technology

**Godot 4.5.1 stable** (official build `f62fdbde1`), stock, GDScript. **Verify it is on PATH in Phase 0**; if it is not, everything from Phase 3 on is unverifiable and the plan's fallback (§`IMPLEMENTATION_PLAN.md` Phase 0) applies. Pin it in `project.godot`. Do not fork. No C# or GDExtension without a demonstrated hard blocker recorded in `docs/IMPLEMENTATION_DECISIONS.md`.

**Python 3.11.15** — the developer's system Python. Archipelago 0.6.7 requires ≥3.11.9 and <3.14, so this is in range.

These are the versions actually installed on the development machine, not a guess. Nothing Archipepsi uses changed between Godot 4.4 and 4.5: the only GDScript-incompatible breaks in that migration are `JSONRPC.set_scope` → `set_method`, two removed `RenderingServer` physics-interpolation methods, and a new `oversampling` parameter on `TextServerExtension`. None are in our surface — `WebSocketPeer`, `CharacterBody3D`, `BaseMaterial3D.texture_filter`, `Image.create` and `RandomNumberGenerator` are all unaffected.

**Archipelago 0.6.7**, pinned by tag.

---

# 4. The Archipelago dependency

## 4.1 Decision

Use `CommonContext` from a **pinned Archipelago source checkout** obtained by a bootstrap script. Do not write a second AP networking stack.

The reasoning is deliberate: the v0.3 audit found several places where this project had misunderstood subtle Archipelago behavior — how `check_locations()` filters, when `RoomUpdate` is broadcast, what `create_as_hint` really does. A project that has just demonstrated it misreads the protocol should not go on to own a second implementation of it. Correctness beats dependency elegance for the POC.

## 4.2 What the setup script does

`bridge/bootstrap.py` (or `make setup`) must be idempotent and:

1. Clone `https://github.com/ArchipelagoMW/Archipelago` at tag `0.6.7` into `.archipelago/` (gitignored), or reuse an existing checkout given by `ARCHIPELAGO_ROOT`.
2. Run `python ModuleUpdate.py --yes` inside it to install AP's own requirements.
3. Install the bridge's requirements.
4. Verify by importing `CommonClient` and printing the AP version.

`ARCHIPELAGO_ROOT` overrides the clone for developers who already run AP from source.

## 4.3 How the bridge imports it

At startup, before importing anything from Archipelago:

```python
import os, sys
os.environ["SKIP_REQUIREMENTS_UPDATE"] = "1"        # see below - not optional
ap_root = os.environ.get("ARCHIPELAGO_ROOT", ".archipelago")
sys.path.insert(0, os.path.abspath(ap_root))
```

**`SKIP_REQUIREMENTS_UPDATE` is mandatory, not hygiene.** `CommonClient.py` lines 12–13 are `import ModuleUpdate` / `ModuleUpdate.update()`, executed at import time. `update()` defaults `yes=False` and, on the first unmet requirement, calls `confirm()` — a bare `input()` that catches only `KeyboardInterrupt`. A bridge launched without a TTY (a service, a supervisor, CI) therefore dies during `import` with an `EOFError` about requirements. Its skip conditions are frozen builds, multiprocessing children, or exactly this environment variable.

It also protects the bridge's own dependencies: AP 0.6.7 pins `websockets==13.1`, and without the skip every import runs `pip install -r requirements.txt --upgrade` and can silently revert a different pin mid-startup. Pin the bridge's `websockets` to AP's, or serve the local WebSocket with a library AP does not pin.

Note also that importing `CommonClient` imports `worlds`, which loads every apworld in that checkout. Keep it clean apart from Archipepsi; expect the first import to take a few seconds.

## 4.4 Configuration

```python
game = "Archipepsi"
items_handling = 0b111      # remote + own-world + starting inventory
want_slot_data = True
tags = {"AP"}
```

Use `CommonContext` for connection/auth, automatic reconnect, data-package cache, name lookup, `items_received`, `missing_locations`, `checked_locations`, `locations_info`, and sending checks.

## 4.5 Scouting

```json
{"cmd": "LocationScouts", "locations": [/* all 30 */], "create_as_hint": 0}
```

`create_as_hint` **must** remain 0. A non-zero value always creates a *persistent* hint, even for already-found locations — bulk-scouting 30 locations with hints on would flood every player's hint tab and damage the seed's hint economy.

Re-scout all 30 on **every** successful connection and reconnection. Re-scouting is safe and avoids depending on undocumented assumptions about whether a given `CommonContext` version re-sends custom scouts.

Resolve each scouted `NetworkItem` as: `.location` → the Archipepsi location; `.player` → the **recipient slot**; `slot_info[recipient].game` → recipient game; data-package lookup in that game's context → item name; `.flags` → classification bits. Never interpret item IDs without recipient-game context.

## 4.6 Received items

Derive the full normalized list from `ctx.items_received`. If raw handling is ever needed: `index == 0` means replace the inventory with the supplied list; otherwise the packet begins at the stated index. Assign each item a synthetic `ordinal` equal to its position in the reconstructed list.

Never increment coins because "an item event happened." Always recount from the reconstructed inventory.

**But `CommonContext` wipes that inventory on every disconnect.** `reset_server_state()` sets `items_received = []` and `locations_info = {}` (it does *not* clear `checked_locations`/`missing_locations`). So a recount during an outage yields zero Coins, zero Signal Keys, zero Static and an empty scout table.

The bridge therefore keeps its own last-known normalized copy in memory — not on disk, AP still owns the truth — and emits it with `ap_state_is_current: false` rather than emitting zeros. Without this, a five-second dropout regresses `unlocked_tier` to 0, collapses eligibility, flaps the Hub into `WAITING_FOR_AP`, and fires a spurious sync warning. The `DESIGN.md` §12 low-coin warning fires only after a *completed* post-`Connected` reconciliation.

**Self-recipient detection uses `ctx.slot_concerns_self(item.player)`**, never `player == ctx.slot`. Its own docstring says so: it abstracts player groups. If the Archipepsi player joins an item link, a scout's `player` can be the group slot id, and a naive comparison classifies a self-destined item as foreign — generating an Echo for an item the player physically receives, and making that location shop-eligible in violation of §11.3.

If a recipient's game is absent from the room's data package, fall back to `item_name = f"Unknown item {id}"` and `recipient_game = "Unknown"` rather than letting a `KeyError` escape the normalizer.

## 4.7 Race mode

Read `_read_race_mode` from data storage after connecting. If 1:

```
Archipepsi POC does not support race-mode rooms because it scouts its own location placements.
```

Refuse to start gameplay. Do not bulk scout.

---

# 5. Confirming a check — read this before implementing anything

This is the single most misunderstood mechanism in v0.3 and it is worth being explicit.

**Two verified facts:**

1. `CommonContext.check_locations()` filters its argument against `ctx.missing_locations`. An already-checked location is dropped **client-side** — no packet is sent.
2. `MultiServer.register_location_checks` computes `new_locations = set(locations) - already_checked` and only broadcasts `RoomUpdate` inside `if new_locations:`. If everything submitted was already checked, **the server sends nothing at all.**

So the v0.3 statement "duplicate `LocationChecks` are safe, so resending a persisted pending purchase is expected behavior" is true about safety and misleading about mechanism. Duplicates are harmless, but they are **not a confirmation mechanism**. Code that sends and then waits for an event will hang in `SENDING…` forever.

**A third, about where you hook it:** `CommonContext.on_package` is **`def`, not `async def`**, and is invoked as a plain call. Everything the bridge needs to do there is async — atomic save, snapshot emission, Echo generation. Writing `async def on_package` produces a coroutine that is never awaited: Python emits a `RuntimeWarning` easily lost in AP's logging, and the reconciliation simply never runs. That is the "hang in `SENDING…` forever" failure this section exists to prevent, reintroduced one layer down.

Use a plain `def` that schedules via `asyncio.create_task` (or `Utils.async_start`) and **holds a reference to the task** so it is not garbage-collected. `on_package` is called after the built-in `RoomUpdate` handling, so `ctx.checked_locations` is already current when the hook runs.

**The rule:**

> Finalization is **reconciliation against `checked_locations`**, never an event wait.

Concretely:

- The bridge emits a fresh `campaign_snapshot` on connect, on every `RoomUpdate`, and after every state change.
- On receiving `claim_check`, the bridge checks `checked_locations` **first**. If the location is already there, it finalizes immediately and never sends anything.
- After sending a check, a reconcile timer (5s, then 15s, then on every snapshot) re-examines `checked_locations` rather than waiting.
- On reconnect, every `PendingCheck` is reconciled: already checked → finalize; still missing → re-send.

**Every pending check needs a terminal failure state, not just the shop's.** `check_locations()` **returns the set it actually sent**, and returns an empty set when the location is in neither `missing_locations` nor `checked_locations`. Capture that return. An empty return with the location still unchecked means AP does not recognise it as this slot's: log loudly, emit a `sync_warning`, drop the pending record, release the location — **and for a `shop`-source record, subtract its `shop_cost` from `coins_spent`**, exactly as `DESIGN.md` §11.7's rollback does. This is one code path; dropping a shop record without the refund destroys coins.

Without this a Zone-source check reconciles forever — and because the exit portal needs every Check confirmed and no new Zone may generate while one is `ACTIVE`, **one stuck check permanently blocks the campaign.** v0.4 gave the shop path a rollback trigger and left the Zone path with none.

---

# 6. Check transaction

`UNCLAIMED → PENDING → CONFIRMED`. A reward object is interactable only once its chamber objective is satisfied.

1. Bridge verifies the location belongs to the active Zone and is not already confirmed.
2. Persist a `PendingCheck` (transaction id, location id, `source`, `shop_cost`).
3. **Save before the network send.**
4. Send the location check.
5. Godot shows `SENDING…`.
6. On reconciliation showing the location in `checked_locations`: finalize, drop the pending record, reveal the real item and recipient, generate the Echo if the recipient is foreign and none exists, disable the reward, save, emit a `check_confirmed` notification.

**Offline.** The player may finish an objective while AP is down. The reward interaction shows:

```
ARCHIPELAGO OFFLINE — RECONNECT TO SEND THIS CHECK
```

Do not create a pending transaction until connected. If the connection drops after one was persisted, keep it pending and recover on reconnect.

---

# 7. Save system

Path: `<save_dir>/<campaign_key>__<sanitized_slot>.json`, where `campaign_key = sha256(seed_name|team|slot_id)[:16]`.

Shape: `CampaignSave` in `schemas/protocol.py`.

**Writes must be atomic.** Write to `<file>.tmp`, `flush()`, `os.fsync()`, then `os.replace()`. Keep one previous generation as `<file>.bak`. If the primary fails to parse on load, fall back to `.bak` and log loudly.

v0.3 was organized entirely around "a crash must never corrupt the campaign" and then specified plain JSON writes at the exact moment it was protecting — the save-before-send step.

## 7.0 Campaign state is replaced, never edited

**`schemas/` models are frozen value objects. Every persistent change goes through `schemas/transitions.py`, which builds the complete next `CampaignSave` and validates it in one step.**

This is the single most important implementation rule in the packet, because the alternative was tried and it failed silently. v0.6 relied on Pydantic's `validate_assignment=True`, which re-validates **top-level assignment only**. These ran no validators at all:

```python
save.zones["z1"].state = "COMPLETE"      # nested model
save.pending_checks.append(...)          # list
save.shop.stock.append(...)              # list
```

Each produced a campaign that serialized cleanly and then **failed to load**, so the bridge fell back to `.bak` and silently rolled back a completed Zone or re-enabled a purchase. The duplicate-pending rule that exists to stop the shop double-charge was bypassable with one `append`.

So: every model is `frozen=True`, every collection is a tuple, and there is no supported way to edit a campaign in place. An invariant checked at construction is therefore checked at every point the campaign ever reaches.

Two corollaries the implementer must not work around:

- **Never `model_copy(update=...)`.** It skips validation entirely and reintroduces the whole problem.
- **A multi-field change is one transition, not two assignments.** Completion changes `zones` *and* `active_zone_id`; both orders of assignment raise, because the intermediate state is illegal by design. That is correct, and it is why `transitions.complete_zone()` exists.

The transitions are: `start_generation`, `accept_zone`, `enter_zone`, `complete_zone`, `abandon_zone`, `release_location`, `claim_zone_check`, `buy_shop_stock`, `confirm_check`, `rollback_shop_purchase`, `restock_shop`, `add_echo`, `equip_echo`. Each takes the save first, returns a new one, and raises `ValueError` for an illegal request — which the bridge answers with a recoverable `error`.

**v0.8 adds two, and renames one.** `append_interpretation` replaces `add_echo`: it assigns the next `interpretation_seq`, validates every operation target against the mechanics as they stand, and appends. `slot_action` replaces `equip_echo`. Both obey the same rule as everything else — a new save, validated in one step, never an edit.

**The save owns:** generated Zones and their lifecycle, the **interpretation log** and its `next_interpretation_seq` counter, the slot assignment, local spending, pending transactions, deterministic allocation state, shop reservations, creativity setting, and earned local rewards.

**The AP server owns:** checked locations, missing locations, delivered items. Never persist a second copy of these and trust it over the server.

## 7.0.1 Derived mechanics are never persisted

The live mechanical state — components, resources, links, aliases, traits, rules — is a **pure fold over the interpretation log**, recomputed on load and after every grant (`ECHOES.md` §2.1). It is never written to disk, and there is deliberately no transition that edits it.

Three consequences the implementer must not work around:

- **Fold order is `interpretation_seq`, never `source_location_id`.** The sequence is assigned once at grant time and is immutable. Sorting a complete log by location id can replay a later-received, lower-numbered interpretation before the component it targets exists — which is reachable by ordinary play, not a corner case. Location id is the tie-break for *assigning* sequence within one reconciliation batch, and nothing else.
- **A dangling target fails loudly.** If an operation resolves to a component that does not exist at its sequence position, the fold raises. It must never be skipped: a silently skipped operation is a build that quietly differs from the one the player earned, and it will differ again differently on the next load.
- **Caching is allowed; a second source of truth is not.** The fold may be memoised against the log length and the last sequence number. It may not be mutated in place and then saved.

Aliases from `MERGE` are part of the derived state and are rebuilt by the fold like everything else. They resolve permanently: a rule written against an absorbed resource keeps resolving to the survivor for the rest of the campaign, and is never rewritten in the log.

Resource *definitions*, maxima and upgrades live in the log and therefore persist. Resource *current values* and active statuses are runtime state and reset on Zone entry, exactly like HP — which keeps the entire class of "my mana desynced across a reconnect" bugs unreachable.

## 7.1 Zone lifecycle

```
PENDING_GENERATION → GENERATED → ACTIVE → COMPLETE
        \                     \        \→ ABANDONED
         \                     \→ ABANDONED
          \→ ABANDONED   (generation failed past repair and fallback)
```

A record is `PENDING_GENERATION` **iff** it has no accepted `zone` yet, and
`ABANDONED` is the one other state allowed to have none. v0.5 required content
in every non-pending state, which made the leftmost arrow above
unrepresentable — a Zone whose generation failed outright could not be
abandoned, inside the state added to break exactly that deadlock.

Accepting a Zone is one atomic transition: build a fresh `ZoneRecord` with the
new `state` and `zone` together. Assigning them one at a time is rejected
(`validate_assignment=True`), and `model_copy(update=...)` skips validation
entirely — do not use it here.

`allocated_location_ids` is populated at `PENDING_GENERATION`, **before** the provider is called, and saved. This closes the v0.3 crash window: a Zone recorded as allocated-but-ungenerated re-runs generation against its committed IDs on load and never re-allocates. It also means those locations are visible to the shop's eligibility check, which in v0.3 excluded only locations "assigned to current saved Zone" — a Zone that did not exist yet.

---

# 8. Reconciliation on load

After connect and a full scout:

**Identity** — verify seed name, team, slot id. If any differ, do not load that save as the current run.

**Pending checks** — already checked → `confirm_check`; still missing → resend. Shop pending costs are already in `coins_spent`, and the save now enforces that: a pending purchase whose cost was never debited is rejected on load.

A pending check that can neither finalize nor re-send is released with `release_location`, which drops that one location from its Zone and keeps the rest of the Zone playable. v0.6 pinned a Zone's allocation equal to the accepted Zone's rewards for the record's whole life, so the only escape was abandoning the Zone and discarding its other unclaimed Checks — the deadlock `ABANDONED` was added to break.

**Every pending check must be backed by something that reserved it.** A `zone` claim is backed by a Zone still holding that location; a `shop` purchase is backed by its own debited cost. A save carrying pending claims with no Zone behind them is rejected rather than loaded, because reconcile would re-send every one of them — handing other players their items for free.

**Confirmed checks** — for a foreign-recipient location that is checked with no Echo, generate one *subject to the bulk-confirmation guard*: only for locations in `pending_checks` or in a Zone or shop batch the player interacted with. Everything else waits for lazy generation. `!collect` and release can flip up to 29 locations at once; without this guard that is dozens of model calls at 60-second timeouts on a loading screen.

**Received items** — recompute Signal Key count, Coin count, Static count from the reconstructed list. No callback increments.

**Shop** — reserved location checked → release and finalize; still missing and unlocked → keep; not valid for this seed → release and log.

**Zones** — never regenerate an accepted Zone because Epsilon would answer differently today.

Handle every state explicitly:

| On load | Action |
|---|---|
| `PENDING_GENERATION` | the Hub shows `GENERATING` with the portal disabled. Re-run generation against its **already-committed** ids; never re-allocate. If generation fails past repair *and* fallback, move it to `ABANDONED` — allowed with no `zone` — which returns its locations to the pool |
| `GENERATED` | resumable. `active_zone_id` points at it, the Hub shows `ZONE_READY`. **Never silently orphan it** |
| `ACTIVE` | resume; if every Check is confirmed, run the completion procedure |
| `COMPLETE` / `ABANDONED` | terminal; its locations are back in the pool |

The `GENERATED` row is the one that was missing. In v0.4 the state had no Hub mode, no entering intent, no snapshot field and no reconciliation clause, while §10.4 still excluded its locations from every pool — so quitting at a loading screen orphaned 2–3 real AP locations permanently, and doing it twice put the reachable Check count below the finale threshold and made the campaign unwinnable.

Accepted Zone and Echo JSON is canonical for the campaign. Model nondeterminism after the first accepted response is irrelevant.

---

# 8.5 Installing the world, generating a seed, hosting a server

Phase 1's milestone is "generates real seeds" and Phase 2's is "against a real server." Neither is reachable without these steps, and v0.4 described none of them. Provide them as Makefile targets so they are executable, not prose.

```make
AP := $(or $(ARCHIPELAGO_ROOT),.archipelago)

world-install:                 # symlink so edits are live, no copy step
	ln -sfn $(CURDIR)/apworld/archipepsi $(AP)/worlds/archipepsi

seed: world-install            # writes to $(AP)/output/
	mkdir -p $(AP)/players
	cp apworld/yaml/*.yaml $(AP)/players/
	cd $(AP) && python Generate.py --player_files_path players --outputpath output

host:                          # serves the newest generated seed on 38281
	cd $(AP) && python MultiServer.py --port 38281 \
	  $$(ls -t output/*.zip | head -1)

apworld:                       # official packaging; never hand-roll the zip
	cd $(AP) && python Launcher.py "Build APWorlds"
```

**Partner world for the multiworld test.** `non_local_items: Epsilon Coin` forces 10 Coins out of Archipepsi, so the other world must have at least 10 locations to absorb them — a one-location world like Clique fails generation. Use a second Archipepsi slot with the solo YAML, or any world with a comfortable location count. State which one you used in `IMPLEMENTATION_DECISIONS.md`.

Generation is also the **only** way to catch a bad `origin_region_name`: unit tests over the world module will not. Phase 1 is not done until `make seed` produces a zip.

---

# 9. Godot ↔ bridge protocol

Local WebSocket, `ws://127.0.0.1:38290`, bound to loopback only. Godot is the client, the bridge is the server. JSON text frames (`WebSocketPeer.send_text`). Every message has a `type`. Full definitions: `schemas/protocol.py`.

This is **not** the Archipelago protocol. The bridge translates.

**Godot → bridge (intents):** `hello`, `ap_connect`, `ap_disconnect`, `start_mock_campaign`, `request_next_zone`, **`enter_zone`**, `leave_zone`, `exit_zone`, **`abandon_zone`**, `claim_check`, `buy_shop_stock`, `equip_echo`, `set_creativity`, `debug_command`. (`ClientMessage` in `schemas/protocol.py` is authoritative; there is no `resume_zone`.)

**Bridge → Godot:** `bridge_ready`, `campaign_snapshot`, `zone_ready`, `notification`, `error`.

Every state-changing intent is answered with a fresh full `campaign_snapshot`. With 30 locations a delta protocol would be complexity for nothing. `notification` carries one-shot UI events only — the snapshot is the state.

## 9.1 Bridge liveness

Godot reconnects to the bridge with backoff (0.5s, 1s, 2s, 4s, capped 5s) and shows `BRIDGE OFFLINE` in the Hub while disconnected. An in-flight generation request is **abandoned, not retried**, on bridge reconnect — the bridge is authoritative and will report the Zone's real state in the next snapshot. A dead bridge is the most likely way to hit "permanently stuck waiting", so this path must exist.

## 9.2 Malformed input

Unparseable or unknown-`type` messages return `error` with `scope: "protocol"`, `recoverable: true`. Never crash the bridge on client input.

---

# 10. Epsilon providers

```python
class EpsilonProvider(Protocol):
    async def generate_zone(self, request: ZoneGenerationRequest) -> dict: ...
    async def generate_echo(self, request: EchoGenerationRequest) -> dict: ...
```

Exactly two methods. (v0.3's shop flavor text is cut — see `DESIGN.md` §11.6.)

Required: `MockEpsilonProvider`, `ClaudeEpsilonProvider`, `FallbackEpsilonProvider`. Future: `LocalEpsilonProvider`.

The game never depends on a model name. The model ID is configuration.

## 10.1 Failure handling

1. Call the provider (timeout 60s).
2. Parse into the Pydantic model.
3. Run semantic validation against the request.
4. If invalid: **one** repair request carrying the concise validation errors.
5. Re-validate.
6. Still invalid → deterministic fallback.
7. Persist only normalized accepted data.
8. Log raw invalid output to development logs only.
9. Never crash gameplay on malformed output.

On provider error or timeout: skip repair, use fallback, show `EPSILON OFFLINE — FALLBACK USED`.

**Reject and repair; never silently clamp.** A clamped Zone is one nobody designed, and it poisons the saved generation logs that are meant to become the local-model benchmark.

## 10.2 Configuration

```
EPSILON_PROVIDER=claude|mock|fallback
EPSILON_MODEL=<model id>
ANTHROPIC_API_KEY=<secret>
ARCHIPELAGO_ROOT=<path>            # optional
ARCHIPEPSI_SAVE_DIR=<path>         # optional
```

**Runtime Claude access is a real prerequisite** and separate from having Claude help build the project: Archipepsi making live API calls needs its own key and credits. Say so in the README.

If the key is absent the bridge still starts, AP features work fully, and live campaigns use the deterministic fallback provider. Log the downgrade clearly. Mock Epsilon is used only when Mock Campaign was explicitly chosen.

**Never** commit keys or store them in Godot project files. `.env` is gitignored.

## 10.3 Two independent axes

`--ap=mock|real` × `--epsilon=mock|claude|fallback`. Six combinations, all useful.

v0.3 blended "Mock Campaign" and "Mock Epsilon" into one concept. Keeping them orthogonal matters because **real AP + fallback Epsilon** is the most valuable configuration in the project: it exercises the entire loop with no API cost and no nondeterminism, which makes it the right default for automated end-to-end tests.

---

# 11. Repository layout

```
archipepsi/
├─ README.md
├─ Makefile                      setup / bridge / test / apworld
├─ .gitignore                    .archipelago/  .env  .godot/  __pycache__/  *.tmp
│
├─ godot/
│  ├─ project.godot              Godot 4.5.1 stable pinned
│  ├─ scenes/                    main/ ui/ player/ enemies/ zone/ props/ hub/
│  ├─ scripts/
│  │  ├─ autoload/               bridge_client.gd, constants.gd (GENERATED)
│  │  ├─ generation/             zone_builder.gd + chamber builders
│  │  ├─ gameplay/               player, static_pulse, echo_runtime, objectives
│  │  ├─ enemies/
│  │  └─ ui/
│  └─ tests/                     headless --script tests
│
├─ bridge/
│  ├─ pyproject.toml
│  ├─ bootstrap.py               clones + pins Archipelago
│  ├─ archipepsi_bridge/
│  │  ├─ __main__.py
│  │  ├─ server.py               WebSocket, intent dispatch
│  │  ├─ ap_client.py            CommonContext subclass
│  │  ├─ campaign.py             THE BRAIN: allocation, tiers, finale, shop, coins
│  │  ├─ transactions.py         pending checks, reconciliation
│  │  ├─ store.py                atomic save/load
│  │  ├─ mock_ap.py              fake AP with the canonical fixture
│  │  ├─ schemas/                copied verbatim from the packet's schemas/
│  │  └─ epsilon/                base, mock, claude, fallback, prompts/
│  └─ tests/                     pytest
│
├─ apworld/
│  ├─ archipepsi/                __init__.py items locations options regions
│  │  └─ archipelago.json
│  └─ build.md                   uses AP's Build APWorlds component
│
└─ docs/
```

The agent may consolidate files, but the ownership boundaries must survive.

**`godot/scripts/autoload/constants.gd` is generated** by `schemas/export.py`. Never hand-edit it; the engine must not drift from the numbers the validator enforces.

---

# 12. Debug tooling

Overlay (F3): bridge connected, AP connected, race mode, seed/team/slot, checked count /30, Signal Keys, unlocked tier, coins received/spent/available, Static count, pending checks, active Zone id and state, its AP location ids, Track cursor, Echo count, equipped Echo, Hub mode, Epsilon provider, last generation error, finale progress.

Development commands: resync, print snapshot, force fallback Zone, grant mock Coin, grant mock Signal Key, respawn, return to Hub, clear campaign (explicit confirmation).

`grant_mock_coin` and `grant_mock_signal_key` are **mock-AP only** and must be rejected with an `error` in real mode. Never expose a command that marks arbitrary real AP locations checked in live mode.

---

# 13. Logging

**Bridge:** connection events, AP packets at debug level, normalization, scout resolution, received-item index handling, allocation decisions, location checks and reconciliation outcomes, provider request ids, validation failures, repair attempts, fallback activation, save writes.

**Godot:** bridge events, snapshot receipt, Zone instantiation, objective completion, reward interaction, Echo equip/use, UI errors.

## 13.2 Reporting the goal

On confirming Check 030: send `StatusUpdate` with `ClientStatus.CLIENT_GOAL` (30), persist `goal_sent`, **and set `ctx.finished_game = True`**.

That last part matters. AP's own reconnect path re-sends the goal only when `finished_game` is set. A bridge that tracks its own flag and not AP's will never re-send, so a `StatusUpdate` lost to a socket close in the same instant leaves the slot un-goaled server-side with no local signal. Re-send on every successful connect while `goal_sent` — it is idempotent.

The correct invariant is "goal is reported **at least** once and the campaign never becomes unplayable", not "exactly once": nothing acknowledges a fire-and-forget status packet.

Never log API keys or passwords. Truncate AP-sourced strings in logs.

## 13.1 Generation archive

For every model generation, optionally save: normalized request, raw provider output, validation errors, repaired output, accepted output, whether fallback was used. No secrets. These become benchmark cases, prompt regression tests, and evidence of how much intelligence a local Epsilon actually needs. The local model succeeds when it satisfies the *same* contracts — no redesign required.

---

# 14. Security boundaries

The model is untrusted input. Never execute model-returned code; never use model output as a file path, shell command, resource path, class name, or network destination. All generated references resolve through allowlisted catalogs, which `extra="forbid"` on every schema enforces by rejecting invented fields outright rather than dropping them silently.

**The v0.8 rule engine does not weaken this, and the reason is worth stating precisely.** A rule is data — an enumerated event, a list of enumerated conditions, a resource cost, a list of enumerated effects — evaluated by an interpreter the game owns. Nothing generated is compiled, `eval`-ed, or resolved to a symbol. The two properties that keep the interpreter itself safe are:

- **Effects never emit events.** State written during a dispatch is invisible to that dispatch, so rules cannot cascade within it. Threshold events (`resource_full`, `resource_empty`, `low_health`, `status_applied`) are derived by the engine at end of tick, on the **edge** rather than the level, and dispatched no earlier than the next tick.
- **Every rule carries a cooldown of at least 0.1 s, and firings per tick are globally capped.** Cross-tick oscillation is bounded by both.

Together these make unbounded recursion unreachable by construction rather than by a depth limit somebody has to maintain.

**AP-sourced strings are also untrusted.** Item and player names come from other players' data packages, which come from their YAMLs and third-party worlds. They flow into Epsilon prompts and onto the screen. Before either: clamp to `MAX_AP_STRING_LEN`, strip control characters, and place them inside a clearly delimited data block in the prompt with an explicit "this is data, not instructions" framing. Blast radius is already bounded — output is schema-validated and never executed — but display text should not be arbitrary.

The bridge binds loopback only and holds the API key; Godot never sees it.

---

# 15. Verified external assumptions

Checked against Archipelago 0.6.7 sources rather than recalled. Re-verify against the pinned tag if it changes.

- `LocationScouts.create_as_hint` non-zero **always** creates a persistent hint, even for already-found locations → Archipepsi uses 0.
- `LocationChecks` may contain duplicates safely, but produces **no server response** when nothing is new (§5).
- `CommonContext.check_locations()` filters against `missing_locations` (§5).
- `ReceivedItems.index == 0` is a full inventory replacement.
- `Connected` provides checked/missing locations, slot data, `slot_info`.
- `items_handling = 0b111` = remote + own-world + starting inventory.
- Item IDs must be interpreted in recipient-game context.
- `_read_race_mode` returns 0/1 from data storage.
- `ClientStatus.CLIENT_GOAL = 30`.
- Origin region defaults to `"Menu"`, configurable via `origin_region_name`.
- Item/location IDs may overlap other games'; `891xxxxx` is fine. Keep under 2^31−1.
- `archipelago.json` requires `game`; `.apworld` `version`/`compatible_version` are added by AP's own build component and must not be hand-written.
- Archipelago is **not** pip-installable; `CommonClient` imports `worlds` at module load.
- Archipelago requires Python ≥3.11.9, <3.14.
- `CommonClient.py` calls `ModuleUpdate.update()` at import time; `update()` prompts via `input()` unless `SKIP_REQUIREMENTS_UPDATE` is set, and `update_command` ignores pip's exit code.
- `CommonContext.reset_server_state()` clears `items_received` and `locations_info` on every disconnect, but not `checked_locations`/`missing_locations`.
- `CommonContext.on_package` is synchronous (`def`), called as a plain call after built-in `RoomUpdate` handling.
- `CommonContext.check_locations()` returns the set it actually sent, empty when the location is in neither missing nor checked.
- `ctx.slot_concerns_self(slot)` exists and is the documented way to test recipient identity; `slot == ctx.slot` is wrong under item links.
- `ctx.finished_game` gates AP's own re-send of `StatusUpdate CLIENT_GOAL` on reconnect, so the bridge must set it alongside its own `goal_sent`.
- Godot 4 `WebSocketPeer.send_text` is correct for JSON text frames; unchanged in 4.5.
- The Godot 4.4 → 4.5 migration touches nothing Archipepsi uses (see §3).

**References:** [Network Protocol](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md) · [World API](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/world%20api.md) · [apworld Specification](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/apworld%20specification.md) · [CommonClient.py](https://github.com/ArchipelagoMW/Archipelago/blob/main/CommonClient.py) · [MultiServer.py](https://github.com/ArchipelagoMW/Archipelago/blob/main/MultiServer.py) · [Running from source](https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/running%20from%20source.md) · [Godot WebSocket](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html)
