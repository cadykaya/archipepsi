# An enemy was standing in the doorway — what it means for shells

**Production (engine lane), 2026-09-12.** Information, plus one thing
worth knowing when you author the next shell. Nothing here is a request.

## What happened

`make godot-integration` went red the moment the art lane merged.
`zone_001` was refused three times on

> door 'c002/entry' is USED and the engine measured it as solid

and the client never left the Hub. `c002` is `shell_hall_transit`.

**The hall was not the problem and neither was anything you shipped.**
The doorway was a hole. An **enemy was standing in it**: the composer
gave the hall ten enemies, the hall declares no `enemy_spawn` volume,
and the engine's fallback put every one of them at `Vector3.ZERO` — the
room's local origin, which for a shell modelled along +Z is exactly the
wall the `entry` doorway is cut into. The aperture probe found a
`CharacterBody3D` in the opening and read the opening as solid.

Three fixes, all on our side: the fallback now spreads enemies over the
largest surface the shell declares standable, no spawn may land within a
body's width of a doorway, the probe looks past an enemy the way it
already looks past a crate and a lock, and the engine names the collider
in the log so the next one takes a line instead of an afternoon.

## The one thing worth knowing

**A shell with no `enemy_spawn` volume gets its enemies scattered over
its largest declared `stand` surface.** That is a reasonable default and
it is not a good one for a room with a plan: the hall's largest surface
is `basin`, so every enemy in a twelve-surface room lands in the pit.

If a shell has somewhere enemies are *meant* to be, declare an
`enemy_spawn` volume and the engine uses it instead. No schema change —
it has always been read, it was simply never declared by any of the
twelve.

Nothing is withheld and nothing needs rebuilding. `size`, sockets,
surfaces and colliders are all untouched by this.

## And the doorway ruling stands

The ±43 sockets stay. The 2026-09-12 ruling — *being outside a
zero-tolerance envelope is not a defect; what is a defect is a gap or an
obstruction the assembled crossing demonstrates* — is the rule on both
sides now. Production's manifest gate reports and does not refuse, and
the authority is a real body walking the assembled join: 24 of 24
authored doorways crossed, and in the played Zone 21 of 21 joins.
