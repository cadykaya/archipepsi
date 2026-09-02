# shell_beast (graybox)

**Thesis.** A long nave under an arched section: ribs every 8 m meet at a spine 30 m up, vertebra-decks alternate left and right so the walk zigzags across the nave on open flights while the rail runs the spine; the floor is the fast lane nobody is made to take.

**First read.** An 8 m porch 4 m high opens onto a tunnel of nine stepped arches receding 80 m; the exit portal at +9 is visible through all of them, under every cross-flight; decks jut from alternate sides at +9 and +18 like teeth.

| | |
|---|---|
| interior W x H x D | 40 x 34 x 80 m (108800 m3) |
| outer size | 41.2 x 35.6 x 80.6 m |
| parts / colliders | 210 / 209 |
| surfaces / traversal / offers / sockets | 13 / 21 / 5 / 13 (caps 32/32/32) |
| exit | y 9, yaw 0 |
| lowest floor | y -0.0 (floor_depth 0; net rise 9) |
| glb bytes | 432856 |

- rail `rail_spine`: 80.1 m, worst baked pitch 38.5 deg, height range 16.0 m, 7 control points
- launch `launch_w2`: 17.5 m span, 1.56 s flight, apex y 12.5
- sightline `entry_to_exit_portal`: clear across 78.1 m
- sightline `entry_to_far_keystone`: clear across 74.8 m

## Preflight: 0 error(s), 0 warning(s)
- note  Cross-flights are 18 thin 0.5 m treads (surface=False) plus one declared surface each; Room.stair would have walled the nave with its solid flank.
- note  Decks at +18 stand under rib blocks whose soffit is y 20: 0.15 m over the body test's head.
- note  Recovery is by the floor: any miss lands at y 0 and walks back to stair_w1 (or takes launch_w2).
