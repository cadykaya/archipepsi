# Evidence index — overnight 0.3 candidate

Captured output from the runs `docs/OVERNIGHT_0_3_LEDGER.md` and
`docs/OVERNIGHT_HANDOFF.md` cite. Each file is the run's own output with
Godot's `WARNING`/`ERROR` lines, GDScript backtrace frames and the bridge's
timestamped log lines stripped, and the tail kept. **`SCRIPT ERROR` lines are
deliberately NOT stripped** — a run that printed its report and then died must
stay visible here. The unfiltered originals lived in this session's scratch
directory, which does not survive the container.

**Tested code revision: `0c5b4d9`.** Everything below except `03` and `05` was
produced on it, on a tree whose only modification was one provenance line
(`source_commit` in `godot/tests/fixtures/placement/captures.json`, rewritten
by that same revision's `make godot-zone-audit`) — which is why the census
stamps itself `0c5b4d9-dirty`.

Every run used a disposable save directory. None touched `.diagnostic-582e954`
or `bridge/saves`; neither exists in the container this was run in.

| file | command | what it shows |
|---|---|---|
| `frontier.status` | the whole frontier | **31 targets, all rc=0**, with their times |
| `frontier-test.log` | `make test` | 1602 passed, 627 subtests |
| `01-sample-census.log`, `sample-census.json` | `make zone-sample` | all twenty declared cases with their identities, seed inputs, proposal and manifest digests |
| `02-named-case-zone08-at8.log` | `make godot-named-case CASE=zone_08 AT=8` | a real engine build failure under the dumped id → **bounded exhaustion** |
| `06-named-case-recovery.log` | `… AT=8 THEN=zone_01` | the same failure → **replacement built, certified and ACCEPTED** |
| `08-live-zone01.log`, `09-live-zone05.log` | `… CASE=zone_01 AT=1`, `CASE=zone_05 AT=5` | two ordinary cases, seeds preserved, accepted on the first attempt |
| `frontier-godot-ordinary-live.log` | `make godot-ordinary-live` | one ordinary default-scale Zone played: goal area on foot, Check claimed through `Reward.interact`, Echo equipped, station panel, leave and re-enter |
| `frontier-godot-reload.log` | `make godot-reload` | a two-process cold restart; 48 anchors compared, worst gap 0.000 m |
| `frontier-godot-integration.log` | `make godot-integration` | the whole campaign loop, prototype scale |
| `frontier-godot-build-failure.log` | `make godot-build-failure` | the offline `Main` handoff gate |
| `12-zone-shots.log`, `captures/` | `make zone-shots` | four inspected renders out of the twenty-three produced |

## Two files from earlier in the session, kept on purpose

* `03-build-failure-gate.log` — the **negative control** for the client half:
  with `Main`'s `layout_failed` guard disabled, the gate fails 3 of 6 checks
  and the log carries `SCRIPT ERROR … 'hp_changed' … Nil`. The guard was
  restored immediately and was not absent during any verification run.
* `07-negative-control-bridge.log` — the **negative control** for the bridge
  half: with `build_failed` not consumed, the client reports correctly and the
  Zone ends `STILL PENDING after the watch window` with 0 refusals charged.
* `05-named-case-zone08-at8-once.log` — the measurement behind "the
  deterministic provider recomposes identical content": the sample served
  once, the fallback composing the retries, and **three identical failures**.
  Produced before the identity line was made exact, so its `IDENTITY:` wording
  is the older, hedged form; the `sample:` lines are what it is kept for.
