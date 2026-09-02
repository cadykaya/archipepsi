# shell_cascade (graybox)

**Thesis.** Concentric terraces rising away from a stage: the one room in the slate where every part of the room looks at the same place.

**First read.** A 4 m tunnel opens at the foot of a bowl; four terraces step up and back, 5 m at a time, and the exit portal sits in the topmost one, 20 m up and 64 m away, in line with the tunnel.

| | |
|---|---|
| interior W x H x D | 64 x 30 x 64 m (122880 m3) |
| outer size | 65.2 x 31.6 x 64.6 m |
| parts / colliders | 76 / 75 |
| surfaces / traversal / offers / sockets | 22 / 20 / 5 / 10 (caps 32/32/32) |
| exit | y 20, yaw 0 |
| lowest floor | y -0.0 (floor_depth 0; net rise 20) |
| glb bytes | 156924 |

- rail `rail_chord_x`: 51.5 m, worst baked pitch 3.0 deg, height range 1.0 m, 3 control points
- rail `rail_chord_z`: 40.1 m, worst baked pitch 3.8 deg, height range 1.0 m, 3 control points
- launch `launch_stage`: 29.2 m span, 1.78 s flight, apex y 18.5
- sightline `tunnel_to_exit`: clear across 48.4 m
- sightline `stage_to_top_ring`: clear across 34.5 m
- sightline `top_ring_to_stage`: clear across 36.7 m

## Preflight: 0 error(s), 0 warning(s)
- note  The tunnel is the small term: 4 x 4 m for 21 m, driven under four terraces, so the bowl is met from its lowest point.
- note  Every terrace is a solid mass, so the bowl has no underside and no part of the room is hollow: a fall lands on the ring below or the stage.
- note  The two rails cross at right angles 5 m apart over the stage; neither turns, which is the opposite of the helix a bowl invites.
