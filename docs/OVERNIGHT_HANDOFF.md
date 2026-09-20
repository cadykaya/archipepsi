# OVERNIGHT HANDOFF — the 0.3 diagnostic playtest candidate

**Disposition: READY FOR DIAGNOSTIC PLAYTEST.**
This is not a claim that Playable 0.3 is complete. It is a claim that the
build can be launched, played and audited, and that the failure which
prevented a diagnostic from starting safely is repaired, reproduced and
guarded.

The evidence log is `docs/OVERNIGHT_0_3_LEDGER.md`; the raw runs are under
`docs/evidence/overnight-0-3/`.

---

## 1. Revisions

| | |
|---|---|
| **Starting** | `9ea1743` — the brief's reference checkpoint. The tree was clean and already at it. |
| **Tested** | see §4; the full frontier was run on a fixed tree with no source edits during it. |
| **Final pushed** | see §4. |

The differences are, in order: the engine NO-LAYOUT handoff and its
coverage; the ordinary default-scale replay harness and the census
provenance; the anchor comparison across a cold restart; and documentation.
No save was migrated, no committed-manifest policy changed, no validator
weakened, no router broadened, no gameplay family added or retired, no
content-budget or lower-budget default changed, and no 0.4 work started.

---

## 2. What was broken, and what now happens instead

**A Zone the engine cannot build used to take the run down with it.**
`ZoneController.setup()` returns when `ZoneBuilder` cannot route the rooms —
correctly — but `Main._to_zone()` carried straight on into
`hud.bind_player(zone.player)` and four signal connects **against a null**.
The run died halfway through a handoff, with the Hub already torn down and
the unbuildable Zone still in the tree. Reproduced, with the crash in the
log: `Invalid access to property or key 'hp_changed' on a base object of
type 'Nil'`.

**And nothing told the bridge.** No `layout_result` is sent for a build that
did not happen, so the record stayed ACTIVE waiting for a verdict that was
never coming: the Hub stayed `ZONE_ACTIVE`, offered a way back into a Zone
that cannot be built, and the campaign could not move.

Now: the client reports `build_failed` with the proposal and attempt it
captured **before** the build started, and the bridge applies the existing
`refuse_layout` transition — charge the attempt, compose a fresh proposal
again inside `MAX_LAYOUT_REFUSALS`, park a **committed** Zone with its
manifest and progress intact, and past the budget go DORMANT so the Hub
reports `ZONE_FAILED` and offers ABANDON with every Check still reserved.
Nothing synthesises a layout to get through the validator: there is no
geometry, and an empty one would have the validator report a geometry error
for geometry that was never laid down.

**Both halves are demonstrated live**, under the case's own placement seed:

* failure → attempt charged → **replacement built, certified and ACCEPTED**
  on attempt 2, 15 of 15 Checks, Hub `ZONE_ACTIVE`;
* failure → three entry attempts → **exhaustion**, Hub `ZONE_FAILED`, the
  Zone named as the discard target and a new Zone refused over it.

**Remaining blockers: none for launching a diagnostic.** The open items in
§5 are milestone items and recorded limits, not startup blockers.

---

## 3. All twenty sample outcomes, with honest denominators

`make zone-sample` (stale output cleared first). Full table with identities,
proposal digests, manifest digests and the engine revision:
`docs/evidence/overnight-0-3/sample-census.json`.

| denominator | result |
|---|---|
| source cases | **20** |
| physically laid out (a manifest emitted) | **19** |
| of those, ACCEPTED by `layout.validate` | **19** |
| of those, refused | **0** |
| no layout at all | **1** — `zone_08` / `zone_008` |

**19 of 19 submitted is not 20 of 20 overall.** `zone_08` produces no
manifest within the bounded search and was not tuned toward fitting.

Every case is reported with the inputs that decide its placement — the
`zone_id` and the theme **are** the seed — because the same rooms under a
different id are a different experiment.

### Live timelines

| run | identity | first result | end |
|---|---|---|---|
| `godot-named-case CASE=zone_01 AT=1` | seed preserved, `zone_001` | ACCEPTED, first attempt | entered, 15/15 Checks |
| `godot-named-case CASE=zone_05 AT=5` | seed preserved, `zone_005` | ACCEPTED, first attempt | entered, 15/15 Checks |
| `godot-named-case CASE=zone_08 AT=8` | seed preserved, `zone_008` | **BUILD FAILED** — no layout submitted | exhausted; Hub `ZONE_FAILED`, discard offered, Checks reserved |
| `godot-named-case CASE=zone_08 AT=8 THEN=zone_01` | seed preserved | **BUILD FAILED** | **replacement ACCEPTED** on attempt 2 |
| `godot-ordinary-live` | ordinary composition, `zone_001` | ACCEPTED | Check claimed on foot; station panel; left and re-entered |

Stages are kept apart: provider-side validation · engine placement ladder
(`zone_008` spends **7 internal placement attempts inside one build** — not
7 bridge refusals) · layout verdict · entry attempts and the refusal budget.

---

## 4. Verification

*(filled in by the frozen run — see the table at the end of this file)*

### Decisive negative controls

| control | expected | observed |
|---|---|---|
| `Main`'s `layout_failed` guard disabled | the missing-player crash | `godot-build-failure` fails 3 of 6 checks; log carries `SCRIPT ERROR … 'hp_changed' … Nil` |
| bridge stops consuming `build_failed` | the Zone waits forever | `godot-named-case CASE=zone_08 AT=8` ends `STILL PENDING after the watch window`, 0 refusals charged, Hub still `ZONE_ACTIVE` |

Both were restored immediately and neither was in place during any
verification run.

### Unrun environments and synthetic evidence, labelled

* **Genuine Epsilon: unrun.** No `ANTHROPIC_API_KEY` in this container and no
  authorized access to obtain one. Everything tonight used the
  **deterministic fallback** provider, or `--epsilon=sample` for named cases.
  Neither is model-authored composition.
* **Windows: unrun.** `Diagnostic Campaign (Windows).bat` was **read**, not
  executed — there is no Windows runtime here. The Python it calls
  (`archipepsi_bridge.diagnostic`) **was** executed, with `--dry-run` and
  `--list`, and its output is quoted in §6.
* **The owner's own save: untouched and unreadable.** Neither
  `.diagnostic-582e954` nor `bridge/saves` exists in this container; the
  brief's package carries no raw campaign. The exact-old-save check is
  **UNRUN**.
* **Combat: not exercised on foot.** Satisfying `kill_all` needs
  `enemy.die()`, a test-only helper. `godot-integration` uses it and says so.
* **Full default-scale completion: not demonstrated.** One Check of 15 was
  claimed physically; the whole-campaign loop runs at prototype scale and
  claims through the transaction handler.

---

## 5. A1–A8 readiness, and the human-only questions

Detail and classification are in the ledger's Block 5. In brief:

| | status |
|---|---|
| **A1** authored room in a played Zone | **8 of 23 chambers built approved authored shells** in tonight's ordinary default-scale Zone (freeze: 0 of 23). Open reading: does "real Epsilon" mean the Claude provider specifically? |
| **A2** a Zone composed from approved authored rooms | same run, same evidence; same caveat |
| **A3** activities genuinely work | automated; see the frontier table |
| **A4** a movement package changes navigation | `none` half measured on ordinary composition (6 offers declared, 5 accepted, 0 selected/built); `rail`/`launch` via `godot-playtest3a` and the three `Play 3AB` launchers |
| **A5** one agency chain end to end | the `powered_door` certificate is the gate and it runs; **signal persistence is an unmade owner ruling** and was not invented |
| **A6** the player can complete the Zone | whole campaign at prototype scale; one Check claimed on foot at default scale. **Not claimed for a whole default-scale Zone.** |
| **A7** a coherent short run | **the owner's judgement, after playing** |
| **A8** Playtest 3 and its triage | **not run.** No playtest happened while you slept. |

### Unmade owner decisions (listed once)

1. **Agency-signal persistence** — transient, persisted, or derived.
2. **Does A1's "real Epsilon" mean the Claude provider**, or any provider on
   the real composition→play path?
3. **The return-anchor repair** (`docs/RETURN_ANCHOR_PERSISTENCE.md`) — new
   content digest plus `repaired_from`. Still a proposal.
4. **Should a recompose after a failure vary its content?** The fallback seeds
   on zone index and budget alone, so it does not; the budget spends three
   identical attempts. Passing the attempt ordinal into its existing salt axis
   would change that, and interacts with the attempt-identity contract.

None of these blocked independent work.

---

## 6. Launching it on Windows

**Use a fresh slot.** Your old campaign will still open, but this build
recomputes a replayed Zone's anchors: a manifest carrying
`room:c021:return = [18.99, 1.53, 42.25]` recomputes to
`(24.27, 1.53, 39.65)` — **5.89 m away**. Nothing was migrated and nothing
will be; a fresh slot avoids the question entirely.

1. **Update first, separately.** Double-click **`Update Archipepsi
   (Windows).bat`**. It is the only file that fetches or moves you between
   commits; the launcher never does.
2. **Double-click `Diagnostic Campaign (Windows).bat`.** For a clean
   candidate slot, run it once with `--new` on the command line — the slot is
   then named for the revision.
3. **Check the four lines it prints before anything starts:**

   ```
     build       <sha> on claude/archipepsi-echoes-continuation-b1adno (clean tree)
     campaign    MOCK, default scale (450 locations)
     epsilon     fallback (deterministic)
     slot        <name>
     save folder <...>\.diagnostic-<name>
     state       NEW campaign (this folder is empty)
   ```

   If it says **prototype**, or a save folder ending in `bridge\saves`, you
   are in the wrong run — that is `Start Archipepsi`, a different game.
4. **Leave that window open.** It is the bridge, and it is also your log:
   every refusal, verdict and error scrolls there.
5. **Start the game** and press **MOCK CAMPAIGN** on the title screen. The
   bridge window will show the client connecting.
6. **Afterwards:** the bridge window's scrollback is the run log, and
   `playtime.jsonl` beside the save records each Zone's elapsed time, per-room
   dwell, deaths and encounter durations. Both are local; nothing is uploaded.

**Movement packages** are the three `Play 3AB - <mode> (Windows).bat` files
(`none`, `rail`, `launch`). They share one save folder on purpose, so the
three modes are three visits to the *same* level.

No admin rights are needed, nothing is deleted, no branch is switched, and
your ordinary `bridge\saves` campaign is never written to.

**No exported executable is offered.** The local export pipeline was not run
tonight, and an invented `.exe` would be worse than the honest repository
launch above.

---

## 7. A 15–20 minute replay

Player-facing first. **Developer answers are in §8** — read those after, or
you will be told what you were meant to notice.

1. **The Hub.** Look around before taking the portal. The board, the shop and
   the archive are all reachable. Take the portal into Zone 1.
2. **Where you arrive.** You start standing on a station. Press **E** on it
   and read the panel. Close it with **Esc**.
3. **Two rooms in.** There is an arena with a ramp to a second floor. Try
   shooting a target from where you are standing rather than from underneath
   it.
4. **Find one Check and claim it.** The prompt tells you when you can. Notice
   what has to happen first.
5. **Press F5.** A navigation schematic shows the rooms you have walked, where
   you are, and which stations you have reached.
6. **Reach a second station**, then come back to the first and open its panel
   again. Warp once.
7. **Return to Hub** from the pause menu — not Abandon — and then take the
   portal back in. You should land in the same Zone, with your key, your
   opened lock and your reached stations where you left them.
8. **Claim one more Check, then stop.** Twenty minutes is enough.

**Two known limits, so a surprise is not mistaken for a regression:**

* Most Checks are behind an objective. A pedestal that says OBJECTIVE
  INCOMPLETE is working correctly.
* Enemy behaviour and art are not what 0.3 is for. Combat that feels thin is
  a known, named limitation, not a new finding.

---

## 8. Developer notes for the same route (read after playing)

* **Step 2** — the panel must list `ENTRANCE (you are here)` greyed out and
  **RETURN TO HUB**, and must **not** warp you. A second destination appears
  only after you reach a second station. Captured:
  `docs/evidence/overnight-0-3/captures/03-station-travel-panel.png`.
* **Step 3** — targets are wall-mounted at roughly head height, stalks into
  the plaster. Captured:
  `captures/02-wall-mounted-targets-at-eye-height.png`.
* **Step 4** — the gate is the chamber's objective. `platform_to_goal` is
  satisfied by walking into the goal area; `kill_all` needs the room cleared.
  The automated run took the first, physically, and claimed Check
  `89100126`.
* **Step 5** — `captures/04-navigation-schematic-F5.png`.
* **Step 7** — this is `leave_zone`, not `abandon_zone`. The cold-restart
  suite asserts the same thing across two processes: key, lock and station
  survive, and the Zone is **replayed from its manifest** with 0 route
  searches.
* **If a Zone ever fails to build** (it should not in Zone 1): you will be
  returned to the Hub with `ZONE COULD NOT BE BUILT — RETURNING TO HUB`, the
  Zone will be offered again, and after three attempts the Hub will offer to
  discard it. That is the repair working, not a crash.

---

## 9. Saves, privacy, and this session's scheduler state

* Every run used its own disposable save directory, deleted at the start of
  its own target and `.gitignore`d: `.named-case-saves`,
  `.ordinary-live-saves`, `.reload-saves`, `.integration-saves`.
* **No owner save was read or written.** Neither `.diagnostic-582e954` nor
  `bridge/saves` exists in this container.
* No raw campaign, backup, private log or personal path was committed. The
  brief package was extracted **outside** the repository.
* `playtime.jsonl` is local-only; a test reads the module's imports and
  refuses anything that could reach a network.
* **Scheduler: this session's heartbeat trigger is disabled and was not
  re-armed.** No watcher, subscription, recurring check-in or self-scheduled
  continuation was created. Other sessions' triggers were left alone.
* Every child process started tonight was waited for and cleaned up; no
  bridge or Godot process is left running.

---

## 10. Replay route for the engine

```
make godot-build-failure                              # offline, ~10 s
make godot-ordinary-live                              # one ordinary Zone, default scale
make godot-named-case CASE=zone_08 AT=8               # a real build failure -> exhaustion
make godot-named-case CASE=zone_08 AT=8 THEN=zone_01  # ... -> accepted replacement
make zone-sample                                      # the twenty cases + census JSON
make godot-reload                                     # two-process cold restart
```
