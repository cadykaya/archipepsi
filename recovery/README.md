# Recovery backup — NOT an integration checkpoint

Branch `recovery/0.4-blindside-wip`, authorised by the owner (2026-09-27)
for preserving real work and its verification status across container
loss. Nothing here is accepted, tested or ready to merge. Full-frontier
acceptance happens only on `claude/archipepsi-0-4-blindside`.

Base: `152d777` (the published 0.4 head at the time of the backup).

| Commit / path | What it is | Verification status |
|---|---|---|
| HB-F4g candidate (`zone_builder.gd`, fixtures `candidate_zone_019/022.json`) | owe the way on `OWED_WAY_ON_ROOMS` (2) spine rooms ahead | **never built or run** |
| HB-F4f candidate (`affordance_features.gd`, `room_contract_driver.gd`) | move a feature off another's floor; pair census + zone_012 c001 test | **never built or run** |
| `recovery/evidence/HB-F4g_diag_*.log` | `--router-diag` of the three failing Zones on `97a4e70` | real runs, regenerated evidence (new container) |
| `recovery/tools/frontier.sh`, `frontier_steps.txt`, `ck10.sh` | the full-frontier runner rebuilt after the loss; steps = CK8's 92, from `CK8_frontier_on_adfb76c.tsv` | used for CK10 |
| `recovery/tools/HB-F4g_*` | variant switcher (1/2/3/junction), quick five-composition check, census + 30-Zone walk queue | written, not yet run |
| `recovery/tools/HB-F4f_runner.py` | 3 sabotage rows + 1 control | anchors dry-checked only |
| `recovery/tools/CK9-F1_sweep.sh`, `CK9-F1_drift_offset_patch.py` | phase sweep of the flyers' wall-clock circle (diagnostic patch, never to be committed to the product) | written, not yet run |

The scripts carry the session's scratch paths; they are records of what
will be run, not portable tools.
