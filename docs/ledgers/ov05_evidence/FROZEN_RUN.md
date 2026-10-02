# O05-17 — the frozen full run

**Revision:** `46bf0230af3b,`, the tree frozen for the whole run
(rev 46bf0230af3b, 64 steps, start 16:50:12; end 17:55:17 UTC).
**Environment:** Godot 4.5.1.stable.official.f62fdbde1; Python 3.11.15; Linux 6.18.44-fc-v37; 4 cores.
These are **local results**. Remote CI was not polled.

**64 of 64 steps passed, 0 failed**, in 65 min 4 s of step time. Every step's raw log is in the
handoff ZIP (`logs/`), named by its index.

| # | step | result | s |
|---:|---|---|---:|
| 1 | `make test` | 2103 passed, 6 wa | 202 |
| 2 | `make smoke` | SMOKE OK — b | 0 |
| 3 | `python3 docs/design-packet-v0.8/check_packet.py` | prose matches the models ac | 2 |
| 4 | `make export && git diff --exit-code -- bridge/archipepsi_bridge/schemas/generated godot/scripts/autoload/constants.gd apworld/archipepsi/constants.py` | exit 0 | 1 |
| 5 | `make godot-import` | exit 0 | 12 |
| 6 | `make doctor` | exit 0 | 4 |
| 7 | `make godot-boot` | GODOT BOOT TESTS OK | 19 |
| 8 | `make godot-test` | GODOT CHAMBER TESTS OK | 26 |
| 9 | `make godot-hud` | GODOT HUD TESTS OK | 19 |
| 10 | `make godot-rules` | GODOT RULES TESTS OK | 20 |
| 11 | `make godot-stats` | GODOT STATS TESTS OK | 18 |
| 12 | `make godot-lab` | GODOT LAB TESTS OK | 19 |
| 13 | `make godot-affordance` | GODOT AFFORDANCE TESTS OK | 20 |
| 14 | `make godot-verbs` | GODOT VERBS TESTS OK | 21 |
| 15 | `make godot-blink` | GODOT BLINK TESTS OK | 23 |
| 16 | `make godot-content` | GODOT CONTENT TESTS OK | 19 |
| 17 | `make godot-activity` | GODOT ACTIVITY TESTS OK | 38 |
| 18 | `make godot-room` | GODOT ROOM TESTS OK | 19 |
| 19 | `make godot-room-contract` | GODOT ROOM CONTRACT TESTS OK | 142 |
| 20 | `make godot-graphs` | GODOT GRAPH TESTS OK | 132 |
| 21 | `make godot-movement` | GODOT MOVEMENT TESTS OK | 21 |
| 22 | `make godot-zone-audit` | GODOT ZONE AUDIT OK | 22 |
| 23 | `make godot-legible` | GODOT LEGIBILITY TESTS OK | 19 |
| 24 | `make godot-physics` | GODOT PHYSICS TESTS OK (68 checks) | 132 |
| 25 | `make godot-traverse` | GODOT TRAVERSE TESTS OK (37 checks) | 60 |
| 26 | `make godot-return-placement` | GODOT RETURN PLACEMENT OK | 18 |
| 27 | `make godot-build-failure` | GODOT RELOAD TESTS OK (6 checks) | 21 |
| 28 | `make godot-exit-reach` | GODOT EXIT REACH OK (81 checks) | 33 |
| 29 | `make godot-passenger-carry` | GODOT PASSENGER CARRY OK (4 checks) | 41 |
| 30 | `make godot-rail-carrier` | GODOT RAIL CARRIER OK (73 checks) | 24 |
| 31 | `make godot-rail-junction` | GODOT RAIL JUNCTION OK (140 checks) | 116 |
| 32 | `make godot-passing-platforms` | GODOT PASSING PLATFORMS OK (70 checks, 7  | 87 |
| 33 | `make godot-counterfire` | GODOT COUNTERFIRE OK (59 checks, 2  | 80 |
| 34 | `make godot-mass-class` | GODOT MASS CLASS OK (59 checks, 1  | 35 |
| 35 | `make godot-unweighted` | GODOT UNWEIGHTED OK (70 checks, 2  | 175 |
| 36 | `make godot-target-facing` | GODOT TARGET FACING OK (2 checks) | 19 |
| 37 | `make godot-rail-zone` | GODOT RAIL ZONE OK (25 checks, 2  | 20 |
| 38 | `make godot-zone-state` | GODOT ZONE STATE OK (60 checks, 3  | 26 |
| 39 | `make godot-roster` | GODOT ROSTER OK (52 checks, 5  | 57 |
| 40 | `make godot-actuator` | GODOT ACTUATOR OK (93 checks, 1  | 34 |
| 41 | `make godot-constraints` | GODOT CONSTRAINTS OK (67 checks, 2  | 100 |
| 42 | `make godot-archive` | GODOT ARCHIVE OK (23 checks, 0  | 19 |
| 43 | `make godot-consumable` | GODOT CONSUMABLE TESTS OK (91 checks) | 21 |
| 44 | `make godot-encounter` | GODOT ENCOUNTER TESTS OK (51 checks, 2  | 85 |
| 45 | `make godot-signal-graph` | GODOT SIGNAL GRAPH TESTS OK (59 checks, 0  | 36 |
| 46 | `make godot-latched-route` | GODOT LATCHED ROUTE TESTS OK (38 checks, 2  | 93 |
| 47 | `make godot-theme-pack` | GODOT THEME PACK TESTS OK (30 checks, 0  | 20 |
| 48 | `make godot-carry` | GODOT CARRY TESTS OK (32 checks, 1  | 42 |
| 49 | `make godot-transport` | GODOT TRANSPORT TESTS OK (106 checks, 6  | 394 |
| 50 | `make godot-reversible` | GODOT REVERSIBLE TESTS OK (32 checks, 0  | 105 |
| 51 | `make godot-verb-runtime` | GODOT VERB RUNTIME OK (95 checks, 1  | 76 |
| 52 | `make godot-status-family` | GODOT STATUS FAMILY OK (15 checks, 1  | 42 |
| 53 | `make godot-consumable-live` | GODOT CONSUMABLE LIVE TESTS OK (1  | 35 |
| 54 | `make godot-consumable-restart` | GODOT CONSUMABLE LIVE TESTS OK (1  | 36 |
| 55 | `make godot-latched-route-live` | GODOT LATCHED LIVE RESTORE OK (12 checks, 1  | 89 |
| 56 | `make godot-transport-live` | GODOT TRANSPORT LIVE RESTORE OK (12 checks, 1  | 181 |
| 57 | `make godot-reversible-live` | GODOT REVERSIBLE LIVE RESTORE OK (6 checks, 0  | 88 |
| 58 | `make godot-candidate-live` | FINAL OK (7 checks, 1  | 317 |
| 59 | `make godot-ordinary-live` | GODOT RELOAD TESTS OK (10 checks) | 31 |
| 60 | `make godot-integration` | GODOT INTEGRATION OK | 107 |
| 61 | `make godot-integration-quiet` | GODOT INTEGRATION OK | 109 |
| 62 | `make godot-integration-variant-live` | GODOT INTEGRATION OK | 28 |
| 63 | `make godot-reload` | GODOT RELOAD TESTS OK (20 checks) | 54 |
| 64 | `make version` | exit 0 | 0 |

## The tree during the run

The tree was clean until step 22 (`make godot-zone-audit`). From then on it held one modified file, `godot/tests/fixtures/placement/captures.json`: the zone audit writes its own provenance stamp (`source_commit`) on every run, by design (`zone_audit_driver.gd`). It is committed with the handoff. Nothing else changed.
