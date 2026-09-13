# Diagnostic playtest — owner session, 2026-09-13

Tree: `582e954` (`claude/archipepsi-echoes-continuation-b1adno`).
Bridge: `--ap=mock --epsilon=fallback`, default scale. Player: Skyah.
Recorded by the engine lane from a live session, not reconstructed.

This was the diagnostic the integrated checkpoint asked for: a human
walking the routes the automated harness cannot. It answered the open
question and found five things the harness had no way to see.

## The question it was run to answer

**The return pad repair is confirmed by a human.** The player found a
branch destination, read the `RETURN` sign before reaching it, crossed
the room to its content and its station, and took the device home
deliberately. It never fired by accident.

That closes the finding the checkpoint opened. The measurement said
0.41 m → 2.50 m of clearance off the arrival-to-content line; the walk
says that clearance is enough.

Also confirmed working in the same session: the ramp to a second floor
and the enemies on it; warp-station repair through a room's activity;
the multiworld attribution on a Check (`CHECK 076 (Bomb Rush
Cyberfunk)`); local keys present and readable.

## Defects

### 1. What a room puts in front of you is not physically validated

Confirmed in the session on two different families, and they are two
different bugs with one shared cause.

**Ground props sit at an ASSUMED floor height.** In
`chamber_builders.gd` the ground-socket foot is

```gdscript
var foot := Vector3(side * width * 0.32, 0.0, depth * t)
```

That `0.0` is hardcoded, and `content_instantiator` only lifts the
object by half its own height on top of it. The socket asks whether the
spot is OCCUPIED (`box_hits` against solids and reserved regions) and
never asks what height the floor is at that `(x, z)`. Any room whose
walkable surface is not a flat plane at local y = 0 gets props hanging
in the air. The owner found an orange reactive barrel with nothing
under it and confirmed it by walking around it.

**Activity elements are grounded but unmounted.** This one is NOT a
height bug: `activities.gd` searches for a real surface (`_best_surface`)
and parks the element above it — "`height` is how far above the surface
the rules park this element". So a target is honestly 2.2 m above a
genuine floor. What is missing is the WALL.
`ActivityElement._build_target` adds a 0.5 m stalk whose stated purpose
is

> The stalk that holds it off the wall, so it reads as MOUNTED
> equipment rather than as a decal painted on the plaster.

and nothing in placement requires a wall behind it. The geometry
promises a mount the placement never provides. Seen in two rooms
(7 targets, then 3), so systematic.

**The shared cause is the useful statement.** This engine already owns
the rule "is there really a surface here, and room to stand on it" —
`RoomAudit.arrival_is_supported` and `Placement.clearance` — and applies
it to arrivals and return anchors. It is not applied to props or to
activity elements. That asymmetry is exactly why the return pad was
repaired this batch and these were not: **physical validation covers
where the player lands and not what the room puts in front of them.**

Fixing the drums means giving a ground socket a surface query instead of
a constant. Fixing the targets means adding a wall-adjacency requirement
to the element search, or dropping the stalk from the geometry. They are
separate changes.

### 2. An activity gives no feedback of any kind

`scripts/ui/tones.gd` already synthesizes a tone bank — `confirm`,
`denied`, `goal`, `reward`, `secret`, `hit`, no audio files shipped —
and `activity_element.gd` and `activity_runtime.gd` call **none of it**.

So: no cue on a correct hit, none on completion, none on failure, none
on a wrong element. The player shot seven targets in one room and could
not tell whether anything had happened. Their words: *"the game told me
nothing."*

The wiring is four call sites into a bank that already exists. This is
the cheapest item on this page and probably the largest felt difference.

### 3. A timed activity has no visible clock

`time_limit` is real and enforced — expiry calls `_reset_attempt()` and
silently resets every element. But the only place the limit appears is
the static sign, baked into the label at build time. Nothing counts
down. Once the player stops reading signage, a timed activity is
indistinguishable from an untimed one until it silently resets.

Nor is a sequence requirement legible: nothing says whether order
matters.

## Design gaps recorded, not implemented

### 4. Activities gate the save point but nothing else

`zone_builder` gives a room with activities a station that starts
BROKEN; `zone_controller` repairs it when that room's activity is
solved. That contract exists and is wired.

Nothing else has an equivalent. `activity_runtime` states the boundary
plainly — an activity "may not become an AP Check, a Zone-exit
condition, or any progression requirement" without a contract that does
not exist — and grants only a local reward, *"worth exactly zero to
Archipelago."*

The session produced the argument for closing the asymmetry, from one
player in one Zone: the 3-target room repaired `C018` and felt earned;
the 7-target room gated nothing and was abandoned mid-solve. Same
mechanic, opposite lesson. Owner's words:

> there should never be ones that do nothing, it will tell the player
> that sometimes puzzles are meaningless

The obvious candidate is the local key, which is currently placed in
the open beside the activity that ought to earn it.

**This is an owner decision, not an engine defect.** Recorded here so
the argument is not lost.

### 5. The warp station warps instead of offering a choice

`WarpStation.interact()` marks the station reached on first touch;
every touch after calls `_next()`, which cycles to the next station in
order and fires immediately. No menu, no destination choice, no save,
no route to the Hub — the Hub is reachable only through the exit
portal, which ends the Zone.

Expected by the owner: a panel offering save, return to Hub, and a
choice of reached stations. That is a strictly larger feature than what
exists.

### 6. Capability proposal: `fit_low_gap` (crouch / slide / prone)

Noticed as "the player cannot fit under the second-floor platform."
Nothing required can hide there — `room_audit` enforces
`HEADROOM = PLAYER_HEIGHT + 0.6` on every content spot and reports a
roofed spot as offering nowhere to stand — so this is dead space, not a
blocked route.

A fifth semantic capability beside `ranged_hit`, `cross_long_gap`,
`grapple` and `blink` would make it live. Declared capability gates are
already legal (`SOLUTIONS_CATALOGUE` §0-bis).

**The cost is not the animation.** The moment a crawlspace can hide a
Check, every low gap becomes a logic-bearing edge: the composer must
place them deliberately and the apworld must declare the requirement on
that location. A gap this game forgets to declare can deadlock a whole
multiworld, because Archipelago may have put another player's
progression item behind it. And a capability unlocks only when its LAST
dependency exists — primitive, collider, capability entry, composer
placement and AP logic, or none of it.

## Standing note

The owner also observed that the game as it stands is too hard for a
new player. Recorded; no batch attached.
