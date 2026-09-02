# shell_stack (graybox)

**Thesis.** Three full floor plates 12 m apart, each with a 14 x 14 well cut in a different place: the room shows its own section from anywhere inside it, and the mandatory route is two drops through the offset wells.

**First read.** A low hood over the door, then a 6 m strip of floor ending at a 14 m hole; through it the middle plate with its own hole further back, and through that the far wall of the bottom level 24 m down. Two holes and a far wall.

| | |
|---|---|
| interior W x H x D | 36 x 14 x 44 m (22176 m3) |
| outer size | 37.2 x 39.6 x 44.6 m |
| parts / colliders | 76 / 76 |
| surfaces / traversal / offers / sockets | 16 / 10 / 5 / 10 (caps 32/32/32) |
| exit | y -24, yaw 0 |
| lowest floor | y -24.0 (floor_depth 24; net rise -24) |
| glb bytes | 158268 |

- rail `rail_wells`: 55.2 m, worst baked pitch 59.9 deg, height range 24.7 m, 6 control points
- launch `launch_up`: 15.6 m span, 1.68 s flight, apex y -8.5
- sightline `entry_through_well_a`: clear across 42.5 m
- sightline `lip_through_both_wells`: clear across 42.9 m
- sightline `plate_1_down_well_b`: clear across 19.2 m

## Preflight: 0 error(s), 1 warning(s)
- warn  descends: geometry reaches 25.0 m below the entry plane and is inside the envelope only through `floor_depth` 24.0, a field Production does not read at 301374d (content_instantiator.gd _from_authored_scene bounds; shell_validator.gd _check_envelope, which measures the VISIBLE mesh only); at import ShellValidator refuses any visible mesh below -1.55 until that field exists
- note  CONTRACT DEPENDENCY: Room('shell_stack', 36, 14, 44, floor_depth=24.0); entry plane y 0 (top plate), plates at y 0, -12, -24, roof 14 m above the top plate. Under Production 301374d the traversal law (drop) and ZoneBuilder (exit_offset.y = -24) accept this room, but the authored-shell envelope (_from_authored_scene bounds; _check_envelope) is built from `size` alone with the floor 1 m below the entry plane, so the shell is refused at import until a `floor_depth` field exists. The preflight keeps exactly ONE warning saying so; that warning is expected.
- note  FALL_KILL_Y is WORLD y -30 (player.gd). This room's floor is at -25 relative to its own entry, so the chain must bring the entry in at world y > -5 for plate 2 to be survivable; a 24 m descent needs ~24 m of prior rise in the chain to be safe.
- note  A drop from plate 0 straight to plate 2 through both wells is NOT possible: well A (z 6..20) and well B (z 24..38) are offset, so every fall from plate 0 lands on plate 1.
- note  Sightlines: from the door (z 2) the well-A window spans slopes -0.13..-0.40, so well B is not visible until the player reaches the strip's end (z 4.5); the through-both-wells line is asserted from there, aimed at the bottom level's far wall (-16.5, the portal head), because from z 2 the brief's (0,-15,43.4) grazes plate 0's lip at z 6 within 4 mm.
- note  Plate 1's east enemy_high sits at (8.5, -11.7, 30) on the 3 m rim strip between well B and the flight_lower headroom hole; the brief's x 10 is that hole's edge.
- note  Headroom holes: plate 0 is cut x 14..18 z 8..17 over flight_upper (treads within 2.4 m of its underside end at z 15; body evidence pinches to z 14), plate 1 is cut x 10..14 z 22..32 over flight_lower (pinch at z 25/26); both carry 2-3 m of margin.
