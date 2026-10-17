# Unified 1: pre-playtest review (Vera, 2026-10-17)

Read-only. Nothing was run in Godot: there is no engine binary in this container, so every finding below comes from reading code, checks and CI configuration. Nobody's work was modified, and no PR comments, watchers or schedules were made.

Three passes:

1. Readiness re-review: v3 `ef157061` and its use in `integration/unified-1`.
2. Pre-playtest pass on `349ef77f` (PR #46).
3. Prod's overnight commits `349ef77f..72f0cc43`.

**No blockers in any of them.**

## 1. Readiness re-review (v3, unified armory)

- **Foundry: ready before the aim settles. Holds.**
  - The gun is home at 0.5 s; the recovery is no longer stretched.
  - The hammer cocks at 0.70 s and the gun is ready at 0.72 s, with about 0.17° of climb still owed. It is fully home near 1.0 s.
  - `five_weapon_check.gd` asserts `owed_at_ready >= 0.08` and `settled > ready`.
- **Sightline and Breacher settle before they are ready.** The check now asserts this per weapon (`AIM_VS_READY`). It is a design choice for the owner, not a defect.
- **Recovery returns only the climb still owed. Holds.**
  - `RangeRig._look` subtracts the player's own opposite mouse movement from what is owed.
  - Movement past the owed amount, or upward, is kept. The next shot fires along the current look.
- **F and middle mouse go through the range trigger. Holds.** While a weapon is out, `fire_echo_b`'s keys move onto `range_fire_alt`, and they are restored on holster or `_exit_tree`.
  - Minor, latent: the keys are restored from `ProjectSettings` defaults, not from `PlayerSettings.bindings`. A custom binding for that slot would be lost, but no UI calls `rebind()` today.
- **Unified armory. Intact by code, but untested there.**
  - `armory.gd` reuses `RangeWeapons` and `RangeRig` unchanged. The only changes since v3 are `bind(host: Node)` and the deferred `_slug_end`.
  - `unified_check.gd` does not assert readiness, the owed climb or F/middle mouse on the game's real player.
- **The campaign aim button is still open.** `ads_binding` is `"rmb"`, and RMB yields to the first Echo slot whenever it holds an Echo. Prod's unified report does not list this as an open question.

## 2. `349ef77f`

- **Mass Driver cap is gone.** `DRIVER_CAP` and `driver_firing` were deleted.
  - Note: frontal armour takes 25% (`ARMOUR_TAKEN`), so a full charge into the plough does 15.
  - "A full charge downs it" holds from the side or back, which is how `_driver_full` tests it.
- **Heavy hits start at 14.** `HEAVY_AT = 14.0`. Sightline's 12 is refused and Foundry's 15 is accepted.
- **No way to be trapped in the bay.** `_drive_booth_door`:
  - The door is shut and the lever locked only while the Shunter is alive and within 5 m of the door.
  - Otherwise the lever opens the door for 4 s, extended while the doorway is occupied. The shutter's own interlock never closes it on the player.
  - The door is open once the Shunter is down, and open whenever the player is off the floor.
  - The Shunter's work positions are about 25 m from the door.
  - Dying restarts the bay and returns the player to Station 1.
- **A11 passes for everything the check exercises.** `shunter_check.gd` counts `BridgeClient.sent_intents` across the whole fight and expects 0. The bay writes nothing to disk; telemetry goes only to the board and the console.
  - **Gap:** a consumable used in the bay goes `Player` → `BridgeClient.authorize_consumable` → `send_intent`. That is a real intent and a real charge spent. Nothing in the annex prevents it, and the check never presses it.
- **Without `--unified`, the campaign is unchanged.** Only `main.gd`, `hub.gd` and `range_weapons.gd` outside `scripts/unified/` changed since `3bf3549d`. Every change is behind `Unified.active()` (a command-line flag) or `armory != null`, which stays null without the flag.
- **Defect (docs only):** the report `docs/reports/2026-10-17-unified-integration-1.md` at `349ef77f` still said "capped at 30", "heavy 13" and "seven placeholder sounds". **Resolved in `299981ad`**, which rewrites the report for this build.

## 3. Overnight commits `349ef77f..72f0cc43`

- **`349ef77f`'s content is untouched.**
  - The only game-side file changed is `godot/tests/affordance_driver.gd`.
  - Everything else is CI (`integration.yml`, `tools/ci/`, `bridge/tests/`) and documents.
- **No suite was dropped.**
  - The old serial job ran 81 `godot-*` targets. `tools/ci/godot_shards.txt` holds the same 81, each exactly once, with no extras and no duplicates (compared mechanically).
  - The non-Godot steps (`doctor`, `setup`, `smoke`, `test`, `version`, `world-install`) remain in the workflow.
  - `fail-fast: false`, so every shard reports. The 30-minute cap is kept per shard.
  - `run_shard.sh` runs every target in its shard and fails the shard if any one failed.
- **No assertion was weakened.**
  - `test_ci_coverage.py` now also reads the shard lists. `NOT_A_SUITE` is unchanged.
  - `test_ci_shards.py` is new and pins the list of 81.
  - The flaky-test fix in `affordance_driver.gd` only positions the player, enemy and pickup before they enter the tree. The pickup used to spawn inside the player and was sometimes collected. No check was changed.
- **Gap (existed before, not caused by these commits):** the unified build's own checks are not in the gate, and no Makefile target runs them. Without a target the coverage guard can't notice they're missing. Those checks are `unified_check`, `shunter_check` and `music_check`. Several older targets (`godot-five-weapons`, `godot-d22-slice`, `godot-weapon-feel` and others) are also outside CI.

## Questions for Skyiah (★ = my pick)

1. Consumables in the Freight Bay: ★ block them in the annex (keeps A11 strict) / allow them as a real spend.
2. Foundry's 0.17° of settling at readiness: ★ play it before tuning / ask for more now.
3. Sightline and Breacher: ★ keep "settle, then ready" / make them ready before settled too.
4. Campaign aim button: ★ V aims, RMB stays the grapple / something else.
5. The unified checks in CI: ★ add Makefile targets and a shard for them after the playtest / leave them as manual checks.
