# Playtest 2.5 — the pre-art baseline

**If you are the one playing: double-click `Playtest 2.5 (Windows).bat`,
play Zone 1, close the window.** That is the whole protocol. Everything
below is why.

---

## What you actually have to do

| | |
| --- | --- |
| **Required** | Baseline **Zone 1**, played to the end |
| **Optional** | Zone 2, only if Zone 1 looked anomalous, or you want a second structural sample, or we need a human eye on whether Zones differ from each other |
| **Not required** | Zone 3. It stays frozen in the corpus for replay and testing |

The before-and-after art comparison uses **the same Zone 1** both times.
One Zone, twice, is the measurement; three Zones once is not.

"Played to the end" means walking back through the portal. Closing the
game instead leaves the Zone with no end, and a Zone with no end has no
duration — the record is written when the Zone finishes.

## What the launcher does that the ordinary one does not

`Start Archipepsi (Windows).bat` and `Update Archipepsi (Windows).bat`
are unchanged and still what you use for ordinary play.

`Playtest 2.5 (Windows).bat` adds three things:

1. **It checks the baseline and refuses if it has drifted.** It never
   repairs it. A launcher that quietly re-recorded the baseline would
   erase the drift it exists to report, and the run after authored art
   would be compared against a baseline nobody walked.
2. **It starts the campaign at the right scale.** MOCK CAMPAIGN on its
   own is the prototype's thirty locations, and Zone 1 of a
   thirty-location campaign is a different level. The launcher passes
   `--mock-scale=default`.
3. **It keeps the run apart and shows you the numbers.** Records go to
   `playtest-2.5\`, not your ordinary saves, so a baseline run can never
   overwrite a campaign you care about. When you close the bridge the
   summary prints, gets written to `playtest-2.5\REPORT.txt`, and the
   folder opens.

You never have to run pytest, and you never have to find a JSON file.

## Afterwards

Say **"I'm done with Playtest 2.5"** and paste `REPORT.txt`. It already
contains everything the analysis needs: elapsed time, room count,
per-room dwell, Checks claimed, deaths, encounter durations, computed
content value, seconds per budget point, and anything structurally odd.

To print it again later, from the repo root:

```
cd bridge
python -m archipepsi_bridge.playtest report --save-dir ..\playtest-2.5
```

## The one instruction that matters

**Change nothing to make the numbers better.** Not the zone budget, not
the content-value weights, not the location count, not the Checks per
Zone, not the enemy budgets, not the finale fraction, not the expected
Zone duration. Human measurements come first.

Every one of those is a tripwire in
`bridge/tests/test_playtest_baseline.py`, and the launcher refuses to
start on any of them. Moving one does not make a number better; it makes
the two playtests measure different games.

---

# For whoever maintains this

## Two artifacts, and they are not the same Zone

This is the part that is easy to get wrong, and a launcher that got it
wrong would print a confident, false claim on screen.

**`docs/baselines/playtest_2_5.json` is a GENERATOR FINGERPRINT.** Three
Zones built from three fixed synthetic requests, recorded verbatim with
the campaign scale they were taken at. Its job is to fail when the
engine stops building the Zones it recorded. **Nobody plays it.**

**The played Zone is the mock campaign's Zone 1** at the default scale.
Its request comes from the mock seed's own item placements, so its
theme, its corridor widths and its affordance features differ from the
corpus. Measured: the same 23 rooms in the same order with the same
enemy counts, dressed for a different source world.

The A/B rests on the *played* Zone being identical before and after art,
which it is — the mock seed and the scale are both fixed, and two
independent engines build a byte-identical Zone. The corpus is what says
the generator underneath has not moved in between. Both are needed and
neither substitutes for the other; `test_playtest_baseline.py` pins each
separately, and refuses to let one quietly become the other.

Every playtime record carries a **level id**, sixteen characters of the
Zone's own hash. Two records with the same id walked the same generated
level. That is how the post-art run is *proved* to be the same level
rather than assumed to be.

## As recorded

```
corpus    450 locations, 15 Checks per Zone, 1000 budget,
          finale at 0.8 (360 Checks = 24 Zones), CHECK_VALUE 0
  zone 1  23 chambers, 910 points, 41 enemies, 15 Checks, 8 rooms with none
  zone 2  23 chambers, 911 points, 34 enemies, 15 Checks, 8 rooms with none
  zone 3  23 chambers, 912 points, 32 enemies, 15 Checks, 8 rooms with none

played    23 rooms, 15 Checks, 41 enemies, 921 points
          neon_transit, for Bomb Rush Cyberfunk
```

Three corpus Zones rather than one because the thing playtest 2 reported
was that four Zones in a row played identically; a one-Zone fingerprint
cannot show that they no longer do. That is a reason to *record* three,
not a reason to make a person play three.

The fallback provider is the source deliberately: it is what a player
with no API key plays, it is what the integration run plays, and it is
deterministic. A Claude-generated Zone is a different Zone every time and
cannot be a baseline for anything.

## The commands

| | |
| --- | --- |
| `make baseline` | Regenerates the corpus from source. Generated artifact, never hand-edited |
| `make playtest-check` | The launcher's own guard, from a terminal |
| `make playtest-report` | The summary, from a terminal |
| `bridge/tests/test_playtest_baseline.py` | The tripwires, and the proof the guard is as strong as they are |

## What the run is measuring

None of these is proven, and the run is what would prove them:

- **Zone duration.** The design target is ~40 minutes. That is
  arithmetic, not a measurement, and must not be described as proven.
- **Where the time goes.** Per-room dwell against each room's computed
  `value`. A room worth 60 points that takes fifteen seconds means the
  content-value weights are wrong — a finding, not a licence to change
  them mid-baseline.
- **`seconds_per_budget_point`.** The single number the budget rests on.
- **Deaths and encounter durations**, for whether the combat scale is
  survivable at 1000 points.

## The open pacing decision, restated because this run informs it

The finale becomes available at 80% — 360 of 449 Checks, exactly 24
Zones at 15 per Zone, against 30 for a full clear. At the unmeasured
40-minute target that is 16 hours to the goal and 20 to a clear. **Do not
quote "~20 hours" as the campaign length**: that is the clear, not the
ending, and the two are four hours apart.

Recorded as OPEN in `AGENT_FRONTIER.md` and
`design-packet-v0.9/CAMPAIGN_SCALE.md` §3, and not to be acted on before
this run produces evidence.

## THE A/B FREEZE

**From the moment the pre-art baseline is captured until the post-art
run of the same Zone 1 is complete, no unrelated runtime, gameplay or
protocol optimization lands.** The authored-art integration is the
variable. Anything else changing at the same time makes the comparison
measure two things at once and neither cleanly.

Known and deliberately frozen:

- **The `mechanics` websocket payload.** It is ~97% of a late snapshot
  (~268 KB at 449 Echoes) and it is re-sent on every state change. It
  could be elided on exactly the key the Echo log already uses. It is
  **not** being elided during the A/B window. `TestTheFoldIsStillSentWhole`
  in `bridge/tests/test_snapshot_size.py` records the cost and says so.

Once the A/B is complete, that returns to the engineering frontier.

## Retaking the baseline

If the corpus genuinely has to be retaken — a generation change that was
meant to happen — regenerate it with `make baseline` **in its own
commit**, and say in that commit that the earlier playtest's numbers stop
applying. That is a decision, and it should look like one.
