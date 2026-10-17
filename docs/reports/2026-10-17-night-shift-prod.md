# Night shift, 2026-10-17: Prod

Prod, for Condi (co-directing) and Skyiah. This covers the queue Condi relayed at 02:59Z.

**Which build has what.**
- **`Archipepsi-Unified-1-349ef77f` is the build Skyiah has.** Nothing below touches it.
- Everything below is on `integration/unified-1` after `299981ad`.
- None of it changes the game a player sees except one test fix, so **no new playtest build was cut tonight**. The next build will carry these commits.

## Queue

| # | Item | State |
|---|---|---|
| 1 | Dess and Vera's pre-playtest findings on `349ef77f` | **Nothing received yet.** Nothing to fix until findings arrive. |
| 2 | The CI blocker: Integration cancelled at its 30-minute cap | **Fixed in `50fee713`**: seven parallel shards, nothing dropped. See below for the GitHub result. |
| 3 | S21 settings/input/a11y and S22 packaging/first-run | **Audited.** Both are marked done in the frontier. Each remaining piece of the plan needs a design call, listed below for Skyiah or the menu lane. Nothing was built. |
| 4 | Dess's per-game Crossing family table | **Not received yet.** |

## 2. CI: the Integration gate finishes again

**The cause wasn't a hang.**
- The headless Godot targets (66 suites and 15 live runs) had grown to about **91 minutes** run one after another. I timed every target here; this container runs about as fast as a GitHub runner.
- The single job's 30-minute cap cancelled every run of this lineage: PR #43 (the D-22 slice) and PR #46 (unified-1).
- The art lane's branches pass in 3 minutes only because they're built on an older main with a short suite list.

**The change (`50fee713`):**
- `.github/workflows/integration.yml` has a `python` job (the full suite, the smoke and the preflight) and a `godot` job of **seven shards** of about 13 minutes each.
  - `fail-fast` is off, so one red run names every failure.
  - Each shard keeps the 30-minute cap.
- `tools/ci/godot_shards.txt` holds the shards, balanced on the measured times. Each keeps the serial order.
- `tools/ci/run_shard.sh` runs one shard: every target in its own log group with its time. A failure doesn't stop the rest, and the shard fails if any target failed.
- `bridge/tests/test_ci_shards.py` holds the 81 targets the serial job ran. It fails if a target is in no shard, in two, misspelled, or if a shard isn't in the matrix. I checked that it can fail by dropping `godot-reload`; it failed.

**One real intermittent failure found while timing: `godot-affordance`, 1 run of 3.**
- `_readouts_change_nothing` built a pickup at the origin, inside the player. The awaited frame sometimes collected it before the test froze it ("previously freed").
- The bodies are now placed before they enter the tree. The assertions are unchanged, and it passed 3 of 3 since.
- This isn't from the unified work: the only gameplay files this branch changed against v3 are the D-22 slice's exit portal and zone controller.

**One thing to check:** the job name changed from `full suite + headless Godot` to `full Python suite + preflight` plus `headless Godot, shard N of 7`. If branch protection requires the old check name by name, it needs updating. I can't see the branch-protection settings from here.

## 3. S21 and S22: what's there, and what would need a decision

**S21 (settings).** `player_settings.gd` and the Settings face have:
- mouse sensitivity, field of view, motion intensity (0 turns off view bob) and master volume;
- invert look and captions;
- remapping with a guard that keeps the mandatory actions bound;
- preferences kept apart from the campaign save, which is asserted.

What the plan names that isn't there, and why I stopped:
- **Music and effects volume.** The Music and SFX buses now exist, so this would let Skyiah set the music to taste while playing. But the Settings face is the 3D menu device with a fixed pot layout. Six pots at the current pitch would run into the terminal at y 556, so it needs a re-layout of that face. **That's a menu design call (Arty, the menu lane).** The code side is small: two settings and the bus volumes.
- **Display and graphics options** (window mode, vsync, render scale) and **UI scale.** Same face, same layout question.
- **Controller support.** Needs a decision on scope: which pads, and the bindings.

**S22 (packaging).** `make doctor` (the fresh-clone preflight), the secret and licence gates, and the review-build launchers exist. The plan's provider selection, reconnect, logs and crash screens are first-run UX flows that need a design before any code.

## Small calls made tonight, for Condi to confirm or overrule

1. **CI:** seven shards of about 13 minutes each rather than raising the cap. A raised cap would still mean an hour and a half per run on every PR.
2. **CI:** a failing target doesn't stop the rest of its shard. The old job stopped at the first failure.
3. **The affordance test fix:** placing the bodies first is the whole fix. No assertion was touched.
4. **From last night, still open:** the Shunter's armour clang stays a placeholder (it isn't one of D-20's seven).

## Not touched

- The Amalgam paths (Dess's tonight).
- `349ef77f`.
- Any art, audio or music.
- No build zips or large binaries were committed.
