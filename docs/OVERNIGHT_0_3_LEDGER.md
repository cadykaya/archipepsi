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
