# shell_bascule (graybox)

**Thesis.** Two lifted leaves: the floor rises away from the door to a crest 12 m up, and only from that crest do you see the second leaf, the pit between them and the exit down the far slope; the room withholds its second half until you earn it.

**First read.** Through a low 8 x 4 m mouth, a full-width stepped slope climbing 12 m to a crest edge 26 m away under a 36 m roof; nothing past the crest is visible, so the room is plainly larger than what it shows.

| | |
|---|---|
| interior W x H x D | 36 x 36 x 68 m (88128 m3) |
| outer size | 37.2 x 37.6 x 68.6 m |
| parts / colliders | 112 / 111 |
| surfaces / traversal / offers / sockets | 11 / 13 / 4 / 9 (caps 32/32/32) |
| exit | y 0, yaw 0 |
| lowest floor | y -0.0 (floor_depth 0; net rise 0) |
| glb bytes | 232640 |

- rail `rail_dive`: 61.8 m, worst baked pitch 60.7 deg, height range 12.8 m, 7 control points
- launch `launch_crest`: 14.0 m span, 1.08 s flight, apex y 15.5
- sightline `entry_to_crest_a`: clear across 27.0 m
- sightline `crest_a_to_crest_b`: clear across 14.5 m
- sightline `crest_a_to_pit`: clear across 14.6 m

## Preflight: 0 error(s), 0 warning(s)
- note  Net rise zero: exit and entry on the same plane, so the chain's cumulative height is unchanged by this room.
- note  The exit is deliberately NOT visible from the entry; crest A at 12 m fills the view and the only asserted entry sightline ends 1 m above its edge.
- note  Both crests are solid from -0.7 to 12 so each leaf is one mass; the pit floor is the enclose slab, so no miss falls more than 12 m and nothing falls forever.
- note  Declared length 70 includes the exit socket 2 m past the back wall; declared height 36.6 is the roof, not the exit door.
