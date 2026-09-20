# Evidence index — overnight 0.3 candidate

Captured output from the runs the ledger (`docs/OVERNIGHT_0_3_LEDGER.md`)
cites. Each file is the run's own stdout/stderr with Godot's `WARNING`/`ERROR`
lines and GDScript backtrace frames stripped and the tail kept; the unfiltered
originals lived in this session's scratch directory, which does not survive the
container. **`SCRIPT ERROR` lines are deliberately NOT stripped** — a run that
printed its report and then died must remain visible here.

Every run below used a disposable save directory. None touched
`.diagnostic-582e954` or `bridge/saves`.

| file | command | what it shows |
|---|---|---|
| `01-sample-census.log` | `make zone-sample` | all twenty declared cases, composed and judged |
| `02-named-case-zone08-at8.log` | `make godot-named-case CASE=zone_08 AT=8` | a real engine build failure under the dumped id → bounded exhaustion |
| `03-build-failure-gate.log` | `make godot-build-failure` | the offline `Main` handoff gate |
| `04-pytest-after-export.log` | `make test` | the Python suite after regenerating the exported artifacts |
| `05-named-case-zone08-at8-once.log` | `make godot-named-case CASE=zone_08 AT=8` with the sample served once and the fallback composing retries | the fallback recomposes byte-identical content; three identical failures |
| `06-named-case-recovery.log` | `make godot-named-case CASE=zone_08 AT=8 THEN=zone_01` | failure → charged attempt → replacement built, certified and **ACCEPTED** |
| `07-negative-control-bridge.log` | as `02`, with the bridge's `build_failed` dispatch disabled | **negative control**: the Zone waits forever, 0 refusals charged |

`05-raw-*` and `06-raw-*` are the Godot-side logs for those runs; the
non-`raw` file of the same number is the full `make` output, which also carries
the bridge process's stdout.
