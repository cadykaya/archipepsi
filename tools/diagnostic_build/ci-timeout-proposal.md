# The Integration job's 30-minute cap — for Prod to agree or correct

Condi, 2026-10-08. **Nothing in `.github/workflows/` has been changed.**
The workflow is Prod's file; this is a proposal with the measurements
behind it, for Skyiah to pass to him.

## What is happening

`.github/workflows/integration.yml` sets `timeout-minutes: 30` on its
single job. The job has not finished on the game line since 2026-09-27.
Measured on run **37787426625** (#28, 2026-10-08), job 113345669011, from
the step timings GitHub records:

| Steps | Wall time |
|---|---|
| Set-up through Preflight (checkout, Python, Archipelago, `make test`, `make smoke`, Godot, import, doctor) | **4m 08s** (13:49:33 → 13:53:41) |
| `Headless Godot suites` | cut off at **26m 07s** by the cap |
| The 13 steps after it, including `godot-integration` (the whole campaign) and `godot-integration-quiet` | **never ran** — all skipped |

The job log shows the suites step was mid-list when it was cancelled: its
last line is `GODOT RAIL ZONE OK`, i.e. `make godot-rail-zone`, which is
**target 33 of the 65** the step runs. So the step was a little over half
done at 26 minutes.

That means the whole-campaign test — the one that proves the game still
plays end to end — has not run on GitHub for eleven days, on any
game-line branch. The art-lane branches pass in about three minutes
because their history carries no `godot/` tree to test.

## How much time it actually needs

Scaling from that run: 65 targets at the runner's observed ~47s average
is **≈51 minutes** for the suites step alone. Add 4 minutes of set-up and
the 13 live/campaign steps after it (two of which play a whole campaign),
and the job wants **roughly 70–90 minutes** as it stands.

For shape rather than for the runner's numbers, the per-target times on a
4-core container (shared with other work, so read them as relative):
`godot-room-contract` 195s, `godot-graphs` 146s, `godot-physics` 136s,
`godot-traverse` 63s, and most of the rest 22–30s. A handful of targets
carry a large share of the time, which is what makes splitting work.

## The smallest safe correction

**One line, today:** on the `full` job,

```yaml
    timeout-minutes: 30      # ->  timeout-minutes: 90
```

It drops no coverage, reorders nothing, and makes the campaign test run
remotely again on the next push. GitHub-hosted jobs may run for six
hours, so 90 is well inside the limit, and `concurrency:
cancel-in-progress: true` already stops a superseded run from holding a
runner.

The cost is honest: a PR waits over an hour for its green tick, on one
serial job.

## The follow-up worth doing after it, if Prod agrees

Split the one job into three that share the existing caches, moving the
step lists **verbatim** so no target can be dropped in the edit:

1. `python` — the current steps up to `make smoke` (~4 min).
2. `godot-suites` — set-up, then today's `Headless Godot suites` list
   unchanged (~50 min).
3. `godot-live` — set-up, then today's 13 live/campaign steps (~15 min,
   unmeasured).

Each Godot job repeats about 4 minutes of set-up (both Godot and the
Archipelago checkout are already cached by key, so the repeat is cheap),
and wall clock becomes the longest job rather than the sum. A failure
then names which group broke, instead of "the suites step".

If he would rather keep one job, raising the cap is enough and the split
can wait.

## What I am not proposing

- No reduction in what runs, no target dropped, no threshold moved.
- No change to `pr.yml` or `nightly.yml`.
- Nothing applied to his file by me. If the one-line change is what he
  wants, it is his to make — or mine to make with his word on it, in a
  commit of its own that touches nothing else.
