# Overnight 0.3 candidate — working ledger

**Lane:** engine (Prod). **Branch:** `claude/archipepsi-echoes-continuation-b1adno`.
**Starting revision:** `9ea1743` (the brief's reference checkpoint; the working
tree was clean and at that commit when this assignment arrived).

This is the engineering evidence log for one finite session. It records what
was observed, what was only hypothesised, what was repaired and what control
fails when the repair is removed. The final disposition is in
`docs/OVERNIGHT_HANDOFF.md`. Raw logs are named per entry; every runtime claim
below names the command that produced it.

Where a claim has been superseded it is corrected **here**, in place, with the
old form kept only under an explicit *superseded* label.

---

## Block 1 — the engine NO-LAYOUT handoff

### 1.1 Symptom and requirement

A proposal the provider-side validator accepted can still fail to be
**constructed**: `ZoneBuilder` routes rooms in real space and its search is
bounded. At the starting revision, `ZoneController.setup()` handled that by
recording `layout_failed` and returning — **before creating a player**.

Two consequences were predicted from source and then measured:

1. `Main._to_zone()` continues after `setup()` into
   `hud.bind_player(zone.player)` and four `zone.player.<signal>.connect`
   calls. With no player those are calls on a null.
2. Nothing tells the bridge. No `layout_result` is sent for a build that did
   not happen, so the record stays ACTIVE waiting for a verdict that is not
   coming.

### 1.2 Reproduction — a real routing failure, not an injection

**Case identity matters here and is the thing most easily got wrong.**
`ZoneBuilder` seeds placement with `hash("<zone_id>|<theme>|layout")`, and a
campaign gives every proposal *its own* `zone_id`. Serving `zone_08`'s content
to a fresh campaign makes it `zone_001` — a different pose sequence. Measured:

    make godot-named-case CASE=zone_08        # served as zone_001
    → FIRST RESULT: ACCEPTED, 0 refusals

That is a fact about the seed and **not** a repair of the case. The sample
fixtures carry the ids of the campaign they were dumped from (`zone_08.json`
holds `zone_id: "zone_008"`), so the harness gained `AT=N`: the disposable
campaign generates and abandons N−1 Zones so the proposal is minted under the
id it failed with. Abandoning returns allocated locations, so the Zone under
test is allocated from a full pool.

    make godot-named-case CASE=zone_08 AT=8
    → IDENTITY: SEED PRESERVED — dumped as 'zone_008', served as 'zone_008'
    → BUILD: branch room 'c015' off 'c013' could not be placed clear of the
      36 room(s) already standing

That is the real router, the real bounded search, and the same content the
offline census has reported no manifest for. No fault is injected at the
builder boundary anywhere in this work.

*Evidence:* `logs/02-named-case-zone08-at8`, `logs/06-named-case-recovery`.

### 1.3 Observation versus hypothesis

**Observed.** Before the repair, with the guard disabled, the run raises
`SCRIPT ERROR: Invalid access to property or key 'hp_changed' on a base object
of type 'Nil'` and then `'fired_pulse'` — `hud.bind_player(null)` followed by
the signal connects, exactly the two predicted sites.

**Observed.** With the bridge not consuming the new message, the client reports
the failure correctly and the Zone sits at `ZONE_ACTIVE`, 0 refusals charged,
one entry attempt, ending `STILL PENDING after the watch window`.

**Hypothesis, now measured and true.** That the deterministic fallback would
recompose *identical* content after a failure — see 1.6.

### 1.4 The repair, and why it sits where it does

* **`ZoneController.setup`** — on `build.has("failed")` it now also calls
  `send_build_failed(layout_failed)` before returning. The controller is the
  only place that holds `proposal_id` and `attempt`, both captured at the top
  of `setup` before the build starts, so the report is about the build that
  failed and not about whatever the bridge is holding when it arrives.
* **`Main._to_zone`** — checks `zone.layout_failed` immediately after `setup`
  and takes `_on_build_failed()` instead of touching `zone.player`. A
  **synchronous** failure cannot be delivered by a signal connected after
  `setup` returns, so the result is read from the controller's own field
  rather than emitted; no second authority is introduced.
* **`_on_build_failed`** does not call `_remember_zone_progress()`. That
  function copies the controller's *runtime* dictionaries over the in-memory
  ones, and on a failed setup those are empty — calling it would overwrite a
  revisited Zone's stations, keys and opened locks with nothing.
* **`build_failed` (new client→bridge message)** carries `zone_id`, `reason`
  (bounded by `MAX_TEXT_LEN` and trimmed on both sides), `proposal_id` and
  `attempt`. It is a new message rather than a reused `layout_result` because
  there is no geometry: an empty or part-built layout would make the validator
  report a geometry error for geometry that was never laid down. Nothing
  invents anchors, packages or a manifest.
* **`Campaign.handle_build_failed`** applies the *existing* `refuse_layout`
  transition, with `handle_layout_result`'s guards: a report for a replaced
  proposal, for an attempt the Zone has moved past, or for a Zone that already
  gave up is ignored. Reusing the transition is what keeps fresh-proposal
  recovery and committed-save failure from drifting apart — `refuse_layout`
  already parks a committed Zone DORMANT with its manifest, content and
  progress intact and recomposes only a fresh one.

Documented in `docs/AMALGAM_BRIDGE.md` §2.3b.

### 1.5 Both outcomes, demonstrated live

| run | outcome |
|---|---|
| `CASE=zone_08 AT=8 THEN=zone_01` | build failed → attempt 1 charged → replacement entered on attempt 2 → **ACCEPTED**, 15 of 15 Checks, hub `ZONE_ACTIVE`, `entered=true` |
| `CASE=zone_08 AT=8` | build failed → three entry attempts → **EXHAUSTED**, hub `ZONE_FAILED`, names this Zone as the discard target and refuses a new Zone over it |

Both print an ordered TIMELINE separating: proposal offered and accepted by the
provider-side validator · engine build started · engine build failed · client
sent `build_failed` · bridge charged the attempt · replacement accepted and
entered **or** exhaustion · final Hub state.

**Exhaustion is not generation.** The second row is correct handling of a Zone
that cannot be built, not a Zone that was built.

**A parked Zone's Check count is not on the wire.** `CampaignSnapshot` carries
`active_zone` and no list of the others, and parking a Zone clears
`active_zone_id` — so the record of the Zone whose outcome is being watched is
the one thing the client cannot read. What *is* observable, and is what the
harness now asserts, is the consequence: the Hub names it as the discard
target and refuses to start a new Zone over it, which it could only do while
those 15 locations are still reserved. The reservation itself is asserted
bridge-side in `bridge/tests/test_build_failure.py`.

*Superseded:* an earlier version of the harness read the outcome from
`active_zone()` and reported "0 of 15 Check(s)" and "STILL PENDING" for a Zone
the Hub was already reporting as `ZONE_FAILED`. That was a report about where
it looked, not about what happened, and it is corrected above.

### 1.6 Finding: the deterministic provider cannot recover a build failure

`refuse_layout` sends a fresh proposal back to be composed again. The fallback
provider seeds composition on `zone_index` and `zone_budget` alone
(`fallback.py`: `random.Random(f"archipepsi/fallback/zone/{n}/{budget}")`), so
the recompose returns **byte-identical content**. Measured directly: with the
sample served once and the fallback composing the retries, `zone_008` failed
three times on the same rooms with the same message, twice from ordinary
composition.

Consequences, stated plainly:

* The refusal budget cannot rescue a Zone the engine cannot build **when the
  provider is deterministic**. It spends three attempts on one Zone and parks.
* The player-facing recovery still works: the Hub offers ABANDON, discarding
  returns the Checks, and the next request mints a different `zone_id` and
  therefore a different placement seed.
* `zone_08.json` is not a sample artefact. It is what ordinary fallback
  composition produces for the 8th Zone of a default-scale campaign. **A
  fallback diagnostic that reaches Zone 8 will meet this**, and will now meet
  it as a clean park-and-discard rather than a crash or a hang.

**Boundary recorded, not crossed.** Passing the attempt ordinal into the
fallback's existing salt axis would make the recompose vary and the budget
mean something. That changes what a retry composes and interacts with the
attempt-identity contract (`test_attempt_identity.py` is written on the
deterministic provider returning the same content). It is a provider/recovery
policy decision and is left for the owner.

### 1.7 Controls

| control | expected | observed |
|---|---|---|
| `Main`'s `layout_failed` guard disabled | the missing-player crash | `godot-build-failure` fails 3 of 6 checks, log carries `SCRIPT ERROR ... 'hp_changed' ... Nil` |
| bridge stops consuming `build_failed` | the Zone waits forever | `godot-named-case CASE=zone_08 AT=8` ends `STILL PENDING after the watch window`, 0 refusals, hub still `ZONE_ACTIVE` |

Both were run in the working tree and restored immediately; neither was in
place during any verification run. *Evidence:*
`logs/03-build-failure-gate`, `logs/07-negative-control-bridge`.

### 1.8 Coverage added

* `bridge/tests/test_build_failure.py` — 11 tests: the message is what moves
  the record; fresh-proposal recovery keeps every Check; the Hub stays usable;
  safe exhaustion (DORMANT, `ZONE_FAILED`, discard offered, Checks held); a
  repeat past the budget changes nothing; a committed Zone keeps its manifest
  and is not recomposed; stale proposal and stale attempt are ignored; an
  absent identity behaves as before; an over-long reason is refused at the
  door; a report for an unknown Zone is an `IntentError`.
* `make godot-build-failure` — offline, no bridge, ~10 s, in CI. Hands the
  real `Main` a Zone the router genuinely cannot place and checks the handoff.
  **If `zone_08` ever starts routing this gate fails loudly** rather than
  passing on a build that succeeded; it guards the handoff, not the routing,
  and the fixture would have to be replaced with another engine-failure case.
* `make godot-named-case` gained `AT=N` (serve under the dumped id),
  `THEN=<case>` (a second proposal from the second request onward), an exact
  dumped-versus-served identity line, a `SCRIPT ERROR` guard, and the TIMELINE.

---

## Block 2 — the twenty declared cases, and a small live comparison

### 2.1 The census, with identities

`make zone-sample` empties `layouts/` first, so no file on disk survives
from an earlier run. Each case is now reported with the inputs that decide
its placement — **the `zone_id` and the theme ARE the seed**
(`hash("<zone_id>|<theme>|layout")`) — together with its proposal digest, the
manifest digest the validator accepted, and the engine revision. A machine
readable copy is `docs/evidence/overnight-0-3/sample-census.json`.

| denominator | result |
|---|---|
| source cases | **20** |
| physically laid out (a manifest was emitted) | **19** |
| of those, ACCEPTED by `layout.validate` on this single pass | **19** |
| of those, refused | **0** |
| no layout at all | **1** — `zone_08` / `zone_008`, proposal `d6b5eb7b1fcc7cd7` |

`zone_08` stays visible and is not tuned toward fitting. It is the Block 1
case, and it is what ordinary fallback composition produces for the 8th Zone
of a default-scale campaign.

**This is one offline validation pass over manifests built without a client.**
It is not the live acceptance loop: retries, acceptance after recomposition,
and exhaustion of the refusal budget belong to the live runs.

### 2.2 Three named cases, live, with their seeds preserved

`AT=N` makes the disposable campaign mint the id each case was dumped
under, so all three are that case under its own placement seed.

| case | served as | first result | end |
|---|---|---|---|
| `zone_01 AT=1` | `zone_001` | ACCEPTED on the first attempt | entered, 15 of 15 Checks, hub `ZONE_ACTIVE` |
| `zone_05 AT=5` (the overlap repair) | `zone_005` | ACCEPTED on the first attempt | entered, 15 of 15 Checks |
| `zone_08 AT=8` | `zone_008` | **BUILD FAILED** — no layout submitted, so there is no verdict | exhausted after 3 entry attempts; hub `ZONE_FAILED`, discard offered |
| `zone_08 AT=8 THEN=zone_01` | `zone_008` | **BUILD FAILED** | replacement entered on attempt 2 and **ACCEPTED** |

The stages are reported apart, because they are routinely collapsed:

* **provider-side validation** — the bridge only offers a proposal
  `generate_zone_validated` accepted. None of these four had a generation-stage
  refusal (`last_generation_error` empty).
* **engine placement ladder** — `zone_008` spends **7 internal placement
  attempts** inside one build. Those are not bridge refusals.
* **layout verdict** — one per submitted layout.
* **entry attempts / refusal budget** — `zone_008` spent 3 entries and its
  whole budget.

---

## Block 3 — one ordinary Zone, at default scale, through the real application

`make godot-ordinary-live` — a new target. Every other live harness serves a
NAMED proposal; this asks the campaign for whatever it would ordinarily
compose, at the scale the diagnostic runs at.

**Runtime, printed before anything is played:** `epsilon=fallback`,
`ap=mock`, save directory `<repo>/.ordinary-live-saves` (the bridge prints
the resolved absolute path and the scale at startup — *MOCK, default scale,
450 locations, 15 Checks per Zone*).

| stage | result | what kind of evidence it is |
|---|---|---|
| boot → Hub → ordinary Zone | `zone_001`, 23 rooms, 30 edges, 15 Checks, theme `neon_transit` | live fallback composition, not a fixture |
| build + verdict | ACCEPTED at 5.4 s | the real `Main`, the real controller, the real bridge |
| objective | **walked into a goal area on foot** → a Check unlocked | physical. `platform_to_goal` is satisfied by arriving; nothing called the handler |
| Check `89100126` | placed 2.2 m out, **walked** to 1.6 m, the game's own interact ray found it, prompt read `[E] CLAIM CHECK 126`, `Reward.interact` called, **bridge confirmed** | walked last leg · addressed by the ray · claimed through the real path · confirmed |
| Echo | the claim delivered an item; `act_l89100126` equipped into `mobility` via `_cycle_echo` | the same function the wheel and the inventory screen end at |
| station | `st:exit` came online **by walking onto its pad**, the interact ray found it, pressing it opened the travel panel through `Main`'s wiring | physical + the real consumer |
| leave / re-enter | `leave_zone` (not `abandon_zone`), Hub, back in; allocation unchanged at 15 of 15 | |

**What this does NOT claim.** The walk is the **last leg only**: the body is
placed on standable ground near the target and then walks and turns under the
real controller with the real input actions. Whether a straight-line route
*across* the Zone reaches every Check is `godot-traverse`'s measurement, with
its own BLOCKED and UNRESOLVED outcomes, and is reported there.

**Combat was not exercised.** Ten of the 15 pedestals sit behind `kill_all`.
Satisfying that needs `enemy.die()`, a test-only helper, and calling it here
would make the route a claim about the helper. `godot-integration` exercises
it and labels it.

### 3.1 A latent race this found

`active_zone` is populated at `PENDING_GENERATION` — before the provider has
composed anything — so a wait on "a record exists" fires while `zone` is still
null, and the `enter_zone` that follows is sent at a Zone with no content.
Invisible with the sample provider, which answers instantly; the fallback at
default scale takes long enough to expose it, and did. All three waits now
wait for `ZONE_READY`.

### 3.2 Captures

Rendered under xvfb with the GL driver (`make zone-shots`), inspected, not
merely written. Four are kept in `docs/evidence/overnight-0-3/captures/`; the
other nineteen regenerate from that command.

* `01-ordinary-room.png` — a `neon_transit` gallery room with its floor,
  ceiling, wall panels and a platform.
* `02-wall-mounted-targets-at-eye-height.png` — targets flush on real walls at
  eye height (the mounting repair).
* `03-station-travel-panel.png` — STATION ENTRANCE, "(you are here)", two warp
  destinations, RETURN TO HUB, and the line saying progress is already saved.
* `04-navigation-schematic-F5.png` — the in-game F5 schematic: rooms walked,
  green "you are here", stations reached.

---

## Block 5 — A1–A8 readiness, as the checklist is written

`docs/ROAD_TO_PLAYABLE_0_3.md` §5 is used verbatim. Its §8 "Evidence at
freeze" table is **history at `e344e2c`** and is not reported here as a current
measurement; where tonight's number differs, both are shown.

Each row separates: **implemented behaviour** · **executed automated
coverage** · **historical human observation** · **judgement still owed by the
owner**.

### A1 — an authored room appears in an actually played Zone

**Moved since freeze.** In tonight's ordinary default-scale Zone `zone_001`
(live fallback composition, not a fixture), **8 of 23 chambers actually built
an approved authored shell**: `shell_corner_left` ×3, `shell_corner_right` ×4,
`shell_hall_transit` ×1. All three are `review: pass` in
`godot/content/registry/authored_art.json` with real scenes on disk. The
`shell_id` in that report is *the shell that actually built*, not the one the
composer requested — `telemetry.gd` says so in as many words. The Zone was
built, its layout ACCEPTED, and a player entered it and claimed Check
`89100126`. Freeze recorded **0 of 23**.

**The gap is a reading, not a measurement.** A1 says "through the real Epsilon
→ played Zone path". The provider here was the **deterministic fallback**.
Whether "real Epsilon" means any provider on the real composition→play path or
specifically the Claude provider is the owner's reading. Genuine-Epsilon
evidence is **unavailable in this container** — there is no
`ANTHROPIC_API_KEY`, and obtaining one is outside this brief. *Classification:
(b) affects milestone completion, does not prevent the diagnostic.*

### A2 — a real Zone is composed from approved authored rooms

Same run, same evidence: eight authored shells chained into one playable Zone
whose layout the bridge accepted, with the connector grammar and entry contract
enforced by the validator that accepted it. *Same Epsilon-reading caveat as A1.*

### A3 — activities genuinely work

Measured by `make godot-activity` in tonight's frontier (result in the
verification table). Freeze recorded 29 audited activities, 0 structural
failures. *Automated coverage; no judgement owed.*

### A4 — at least one real movement package changes navigation

Tonight's ordinary Zone **declared 6 movement offers, judged 5, accepted 5**,
and with the package set to `none`, **selected 0 and built 0** — which is the
`none` half of the criterion, measured on ordinary composition. The
`rail`/`launch` half is `make godot-playtest3a` (result in the verification
table) and the three `Play 3AB - <mode> (Windows).bat` launchers.
*Implemented and covered; the "the route differs" comparison is one the owner
sees by playing the same Zone in two modes, which those launchers exist for.*

### A5 — one environmental-agency chain works end to end

A `powered_door` chain is the one tag the bridge requires a certificate for
(`CERTIFIED_TAGS = {"powered_door"}`): the engine builds the package, replays
it three times at exactly the manipulation envelope, and sends the evidence;
`make godot-physics` is its suite. **What stays unresolved is not the chain but
its persistence**: `ROAD_TO_PLAYABLE_0_3.md` §6 records that whether an agency
signal is transient within a visit, persisted across re-entry, or derived is
*an owner design decision that has not been made*. Nothing tonight invented
those semantics. *Classification: (c) explicitly deferred to the named owner
gate.*

### A6 — the current player can complete the Zone

`make godot-integration` plays a whole campaign to `ALL_CHECKS_CLEARED`,
**at prototype scale**, with Checks claimed through the transaction handler
rather than by a body pressing E. Tonight's default-scale run claimed **1 of
15** Checks, and that one physically: walked into a goal area, walked the last
leg, addressed by the game's own interact ray, `Reward.interact`, bridge
confirmed. **A whole default-scale Zone completed on foot is not demonstrated
and is not claimed.** *Classification: (b) — the diagnostic is what answers it,
which is the point of running one.*

### A7 — a coherent short run

**The owner's judgement, made after playing.** Nothing automated can move this
row, and nothing tonight tried to.

### A8 — Playtest 3 happens, and its findings are triaged

**Not run.** An overnight automated loop is not a playtest, and no playtest
happened while the owner slept. The findings from this session are classified
(a)/(b)/(c) in this ledger and in the handoff; the triage A8 asks for is of
**Playtest 3's** findings, against the corrected playtest record.

### Findings from tonight, classified

| finding | class |
|---|---|
| missing-player crash after a failed build | **(a) prevented the diagnostic** — repaired |
| a failed build never reaching the bridge (campaign stuck, Hub offering a Zone that cannot be built) | **(a)** — repaired |
| `active_zone` populated at `PENDING_GENERATION`, so `enter_zone` could be sent at a Zone with no content | **(a)** — repaired in the harnesses; the shipping client waits on `ZONE_ACTIVE` plus non-empty content and was not affected |
| the deterministic provider recomposes identical content, so the refusal budget cannot rescue an unbuildable Zone | **(b)** — recorded, bounded; the player-facing discard works |
| `zone_08` / `zone_008` does not route within the bounded search | **(b)** — visible, not tuned away |
| anchors are recomputed on replay, so a save from another build moves a return device | **(b)** — measured (5.89 m), proposal only, use a fresh save |
| genuine-Epsilon evidence for A1/A2 | **(b)** — no authorized access in this container |
| agency-signal persistence | **(c)** — named owner gate, untouched |

### Unmade owner decisions, listed once

1. **Agency-signal persistence** (`ROAD_TO_PLAYABLE_0_3.md` §6) — transient,
   persisted or derived.
2. **Does A1's "real Epsilon" mean the Claude provider specifically**, or any
   provider on the real composition→play path?
3. **The return-anchor repair** in `docs/RETURN_ANCHOR_PERSISTENCE.md` — new
   content digest plus `repaired_from`; still a proposal, nothing implemented.
4. **Whether a recompose after a failure should vary its content** (passing the
   attempt ordinal into the fallback's existing salt axis). Interacts with the
   attempt-identity contract; not taken.

None of these blocked any independent work tonight.

---

## Block 6 — freeze and verification

**Tested code revision `0c5b4d9`.** The full frontier ran on a fixed tree —
**31 targets, every one `rc=0`** — with no source edit during it.
`docs/evidence/overnight-0-3/frontier.status` is the raw table and
`frontier-test.log` the Python run (**1602 passed, 627 subtests**).

**One tracked artifact was rewritten by the run.** `make godot-zone-audit`
regenerates `godot/tests/fixtures/placement/captures.json` and stamps it with
the revision that produced it: `"source_commit": "10972f67022d"` →
`"0c5b4d9cae54"`. That one line is the entire diff; every measurement in the
file is byte-identical, and `bridge/tests/test_placement_contract.py`, which
reads it, passed in the same run. The census therefore stamps itself
`0c5b4d9-dirty` rather than pretending to a clean tree.

**The named live cases and the twenty-case census were re-run on that
revision afterwards**, so every figure in the handoff comes from the tested
code. Regenerating the twenty source fixtures from `dump_zones.py` produced
**byte-identical files** — the tree showed no change to them — which is the
determinism the census depends on.

### An observation recorded rather than repaired

`main.gd`'s snapshot branch reads
`BridgeClient.active_zone().get("zone", {}).is_empty()`. `.get`'s default does
**not** apply to a key that exists and is null, and `zone` *is* null at
`PENDING_GENERATION` — the same GDScript trap `bridge_client.gd` already
carries a comment about. It is currently unreachable: GDScript's `and`
short-circuits on `mode == "ZONE_ACTIVE"` first, and a record is only ACTIVE
once it has content. **Not reproduced, so not repaired** — recorded here
because the guard is one state-machine change away from being load-bearing.

### Evidence kept, and what was dropped

`docs/evidence/overnight-0-3/README.md` indexes every file and says which
revision produced it. Superseded duplicates from earlier in the session were
removed rather than left beside their replacements: pre-frontier copies of the
integration, ordinary-live, reload and pytest logs, and two raw logs whose
`IDENTITY:` line predates the exact dumped-versus-served wording. The two
negative controls and the fallback-determinism measurement are kept and
labelled, because nothing else records them.
