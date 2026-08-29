# Playtest 2.5 — the pre-art baseline

**What this is for.** Authored art is about to land. When it does, the
question will be "is the game better", and the only honest way to answer
it is to compare a run before to a run after. That comparison is about
art *only if everything else held still* — otherwise it measures
whichever thing moved.

So this baseline exists to hold everything else still, and to make it
loud when something does not.

**The one instruction that matters: change nothing to make the numbers
better.** Not the zone budget, not the content-value weights, not the
location count, not the Checks per Zone, not the enemy budgets, not the
finale fraction, not the expected Zone duration. Human measurements come
first. Every one of those is a tripwire in
`bridge/tests/test_playtest_baseline.py` and moving one fails the suite
with a message saying the two playtests are no longer measuring the same
game.

## What is recorded, and where

| | |
| --- | --- |
| `docs/baselines/playtest_2_5.json` | The baseline itself: three consecutive Zones, request and accepted output verbatim, four Echoes, and the campaign scale it was taken at |
| `make baseline` | Regenerates it from source. Generated artifact — never hand-edited |
| `bridge/tests/test_playtest_baseline.py` | The tripwires |
| `<save dir>/playtime.jsonl` | What the human run produces. One line per Zone, local only, no upload path |

The baseline uses the **fallback** provider, deliberately. It is what a
player with no API key plays, it is what the integration run plays, and
it is deterministic — a Claude-generated Zone is a different Zone every
time and cannot be a baseline for anything.

### As recorded

```
scale     450 locations, 15 Checks per Zone, 1000 budget,
          finale at 0.8 (360 Checks = 24 Zones), CHECK_VALUE 0
zone 1    23 chambers, 910 points, 41 enemies, 15 Checks, 8 rooms with none
zone 2    23 chambers, 911 points, 34 enemies, 15 Checks, 8 rooms with none
zone 3    23 chambers, 912 points, 32 enemies, 15 Checks, 8 rooms with none
```

Three Zones rather than one because the thing playtest 2 reported was
that four Zones in a row played identically; a one-Zone baseline cannot
show that they no longer do.

## Running it

1. `make doctor` — confirm the checkout is playable. No API key is fine;
   that is the configuration this baseline is taken in.
2. `make baseline` and check `git status` is clean. **If the file
   changed, stop.** Something moved under the baseline, and the run you
   are about to do is not comparable to the one after art.
3. `cd bridge && python -m pytest tests/test_playtest_baseline.py` —
   green means the recorded Zones still validate and nothing was retuned.
4. Play. Zones, in order, no editor, no debug teleports through rooms.
5. `playtime.jsonl` accumulates beside the saves. Read it with
   `instrumentation.read_records()` / `summarise()`.

Each line stamps the **build** it was played on (commit, branch, whether
the tree was clean). That stamp is what says which side of authored art a
measurement is on, so a run from a dirty tree is a run whose numbers
cannot be placed.

## What the run is measuring

The numbers the redesign is a bet on, and none of them is proven:

- **Zone duration.** The design target is ~40 minutes. That figure is
  arithmetic, not a measurement, and must not be described as proven.
  `elapsed_seconds` per Zone is the answer.
- **Where the time goes.** Per-room dwell against each room's computed
  `value`. A room worth 60 points that takes fifteen seconds means the
  content-value weights are wrong — which is a finding, not a licence to
  change them mid-baseline.
- **`seconds_per_budget_point`.** The single number the budget rests on.
- **Deaths and encounter durations**, for whether the combat scale is
  survivable at 1000 points.

## The open pacing decision, restated because this run informs it

The finale becomes available at 80% — 360 of 449 Checks, exactly 24
Zones at 15 per Zone, against 30 for a full clear. At the unmeasured
40-minute target that is 16 hours to the goal and 20 to a clear. **Do not
quote "~20 hours" as the campaign length**: that is the clear, not the
ending, and the two are four hours apart.

It is recorded as OPEN in `AGENT_FRONTIER.md` and
`design-packet-v0.9/CAMPAIGN_SCALE.md` §3, and it is not to be acted on
before this run produces evidence. Both figures are the same unmeasured
40 minutes multiplied out, and retuning a real gate to satisfy a guess is
the mistake the decision was recorded to avoid.

## Afterwards

Keep `playtime.jsonl` from this run. When art lands, take the second run
against the SAME baseline file — the tripwires will have refused any
drift in between — and the difference is art.

If the baseline genuinely has to be retaken (a generation change that was
meant to happen), regenerate it with `make baseline` **in its own
commit**, and note in that commit that the earlier playtest's numbers
stop applying. That is a decision, and it should look like one.
