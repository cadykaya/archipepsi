# shell_lemniscate (graybox)

**Thesis.** A rail-first void: the figure-of-eight through open air is the room's signature, and the two island towers exist to be crossed between.

**First read.** A 10 m vestibule opens onto a 44 x 72 m basin 40 m tall; the exit portal is visible dead ahead 72 m away and 14 m up, framed between the two towers.

| | |
|---|---|
| interior W x H x D | 44 x 40 x 72 m (126720 m3) |
| outer size | 45.2 x 41.6 x 72.6 m |
| parts / colliders | 73 / 70 |
| surfaces / traversal / offers / sockets | 12 / 12 / 7 / 12 (caps 32/32/32) |
| exit | y 14, yaw 0 |
| lowest floor | y -0.0 (floor_depth 0; net rise 14) |
| glb bytes | 148080 |

- rail `rail_lemniscate`: 162.9 m, worst baked pitch 22.6 deg, height range 18.5 m, 13 control points
- launch `launch_island_a`: 29.3 m span, 1.48 s flight, apex y 17.5
- launch `launch_basin`: 17.3 m span, 1.48 s flight, apex y 10.5
- sightline `entry_to_exit_portal`: clear across 70.3 m
- sightline `island_a_to_island_b`: clear across 28.8 m

## Preflight: 0 error(s), 0 warning(s)
- note  Rail crosses itself in plan near (1, z 37): first pass y 19.0, second y 12.5 -> 6.5 m of air between.
