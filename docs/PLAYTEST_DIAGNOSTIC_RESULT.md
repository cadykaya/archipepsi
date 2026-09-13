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

### 1. Activity elements are mounted to nothing

Seen in two rooms (7 targets, then 3), so systematic.

This is NOT a height bug. `activities.gd` searches for a real surface
(`_best_surface`) and parks the element above it — "`height` is how far
above the surface the rules park this element" — so a target sits an
honest 2.2 m above a genuine floor. What is missing is the WALL.
`ActivityElement._build_target` adds a 0.5 m stalk whose stated purpose
is

> The stalk that holds it off the wall, so it reads as MOUNTED
> equipment rather than as a decal painted on the plaster.

and nothing in placement requires a wall behind it. So the element is
correctly grounded and still visually claims to be bolted to something
that is not there. The fix is a wall-adjacency requirement in the
element search, or dropping the stalk from the geometry.

### 1-bis. Nothing casts a shadow, so "is it on the floor" is unanswerable

**The cause of the retraction below, and the more important finding.**

Every room light is an `OmniLight3D` built by `chamber_builders._light`
with `light.shadow_enabled = false`, and the player's flashlight
(`player.gd`) is the same. Unlike nearly everything else in this
codebase the line carries no comment, so there is no recorded reason —
plausibly cost, since these are omni lights several to a room and omni
shadows are the expensive kind, but nobody wrote it down.

With no contact shadow, no form shading and flat single-colour prop
materials, a grounded object and a floating one are visually identical.
The owner's words: *"nothing does, and theyre so smooth and single
textured that it was hard to tell."*

**The consequence is what matters: placement defects of this class are
undetectable by eye in this build.** The activity targets were only
catchable because the stalk gives them away. Anything without a
giveaway silhouette can sit a metre off the floor and no playtest will
ever find it. That makes shadowing a DIAGNOSTIC PREREQUISITE rather
than a polish item — the engine lane cannot ask a human to eyeball
grounding until it exists.

Not necessarily full shadow maps. A contact/blob decal under grounded
props, or shadows on a chosen subset of lights, may buy the whole
diagnostic value. Costed design is the art lane's with the engine, and
is not decided here.

#### Retracted: the hazard drums

An earlier revision of this page reported the reactive barrels as
floating too, and generalised both into "physical validation covers
where the player lands and not what the room puts in front of them."
**The owner retracted the observation on a closer look: the drums are
not floating.** The generalisation went with it.

Recorded because the mistake is instructive. The code reading that
prompted it was real — `chamber_builders`'s ground-socket foot is the
constant `Vector3(side * width * 0.32, 0.0, depth * t)`, and the socket
asks whether a spot is occupied without ever asking what height the
floor is at that `(x, z)`. But if a room's walkable surface IS at local
y = 0, that constant is the right answer and there is no defect. A code
smell was promoted to a confirmed bug on one screenshot.

**Left as an unverified assumption, not a finding.** Whether any
built room puts its walkable surface somewhere other than local y = 0
is answerable by probe and has not been probed. Do that before touching
the socket.

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

### 4-bis. Branch depth: the dial is at its cap, and the ask is variance

Owner, in session: *"the game's branches are a little too small, one
junction with a warp point led to a small hallway and then the dead end
room. it's ok if this happens but i don't want that to be the norm."*

`topology.MAX_SIDE_DEPTH = 2` — "how far off the spine a side path may
run, counted in rooms." Hallway-then-dead-end IS depth 2, so the
session met the cap rather than found a bug. The constant's own note
asks for exactly this input:

> Provisional tuning, and nothing more. Not a design law and not a
> physical cost. [...] So this stays at 2 for now because it produces a
> distribution worth reading, and it is a dial rather than a verdict.
> Raise it, remove it, or keep it on play evidence — not to avoid a
> shape.

**The ask is a DISTRIBUTION, not a larger number.** "I don't want that
to be the norm" is not answered by raising the cap to 4, which could
produce uniformly-four-deep branches — the same complaint with a bigger
number. Some short spurs, some real side paths.

`topology.py` is the bridge lane's file. Recorded for Dess; the engine
lane is not changing it.

### 4-ter. Activity density is capped by count, never by room size

Owner, in session, on a small L-shaped corridor: *"there is so much
bullshit goin on in this room lol, we got the touch a popsicles game
and two races in this tiny L hallway."*

Three activities: one `switch_sequence` (its elements are
0.6 x 1.2 x 0.3 blocks -- "popsicles" is a fair reading) and two
`timed_run`. That is the schema maximum, in the smallest room allowed
to hold it:

```python
activities: tuple[ActivityPrimitive, ...] = Field(default=(), max_length=3)
```

**A flat count with no relationship to floor area.** A corridor is
allowed exactly what a large arena is allowed.

Ten lines above it in the same file, the Checks cap carries the thought
this one is missing:

> Bounded low on purpose. Two or three Checks in a GENUINELY LARGE ROOM
> correspond to distinct activities; fifteen in one room is the
> warehouse of pedestals CAMPAIGN_SCALE.md 5 forbids, and this is the
> cheap structural half of preventing it.

So the schema already knows size ought to bound density, states it in
prose for Checks, and does not apply it to activities.

**A second defect underneath the first, and not an area problem.**
`timed_run` is the one family with `roles: true` -- start and goal
elements. Two of them in one space puts two `START` gates in view with
nothing saying which goal belongs to which start. That reads as noise in
a room of any size.

Split across lanes: the `max_length=3` cap is the bridge lane's
(`schemas/zone.py`). Whether the engine should REFUSE to place three
activities in a corridor-sized room, and whether two role-using
activities may share a space at all, is the engine lane's
(`generation/activities.gd`).

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
