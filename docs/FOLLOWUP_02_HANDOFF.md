# Owner-away follow-up 02 — engine lane

**Branch:** `claude/archipepsi-echoes-continuation-b1adno`
**Started from:** `eb14a38` (runtime verification at `b3d583d`)
**Tested revision:** _§6, after the run_

Worked from `ARCHIPEPSI_OWNER_AWAY_FOLLOWUP_02.md`, items **A**, **B**
and **C**. **D belongs to Dess** and is untouched here — see §3.

The ten-minute route for your return is a separate page:
**`docs/REVIEW_ROUTE_0_3.md`**.

---

## 1. Implemented repairs

### A1 — the lower Check was a destination. The walker was in a secret alcove.

`Reward_89100126` is in **c021**, a `platform_path`. It sits at that
producer's own `reward_position` — the **end ledge**, the highest flat
ground in the chamber and the last thing the mandatory route touches —
with solid floor **0.00 m** under it.

What was 2.6 m above it was the walker. `_standable_start` cast down
from three metres above the doorway and took the first surface it
found, which at `c021/exit` is the **secret alcove** that
`_secret_alcove` puts over that ledge precisely so a base kit cannot
reach it.

The start rule now takes the floor the **doorway opens onto**: the cast
begins one step above the door's own height and a surface further than
`MAX_VERTICAL_STEP` away is refused. The same sample goes from 5 of 6
Checks reached to **6 of 6**, and from 1 `OFF_LEVEL` to none.

**Classification: not a defect.** The finding is retracted and replaced
by four controls that would catch the real thing:

| | |
|---|---|
| ground under it | 0.00 m — "floating" is a measurement, not an impression |
| the interaction position | a base kit reaches it, and the game's own interact ray finds it there |
| the real interaction | runs from that position and offers `[E] CLAIM CHECK 126` |
| **can the room be left** | `platform_path`'s exit is SEALED, so the way back is the way in: the gap behind the ledge measures **2.00 m against a 2.60 m jump** |

That last one is the one worth keeping. A dead-end room whose reward
sits beyond a gap nothing can jump back across is a softlock.

### A2 — the side door was never a leak

`c001/side_left` was flagged on a **proxy** — "no other room's doorway
within 6 m". The Zone says plainly what it is:

```
{"socket_id": "side_left", "usage": "SEALED", "edge_id": null}
```

Not a join that went missing: a socket the graph never used. Measured
on the assembled Zone, **all 22 SEALED sockets are solid**, that one
included. **The leak candidate is retracted.**

The proxy is gone. Join lines now carry the declared usage and edge id
— `[SEALED]`, `[USED e:c001:c002]` — so a walk that does not get
through a sealed socket reads as the sealed socket working.

In its place: every declared door measured against its own usage across
the whole assembly, with a deliberately broken counterpart that mutates
the **declaration** rather than the geometry (`c001/exit` relabelled
SEALED while still an opening; the sweep must report it).

`RoomAudit._assigned_doors_match_their_usage` already asked this of a
room, from its own transform, in the room-contract suite. Nothing asked
it of the **assembled** Zone, where a cap is placed by the layout — and
that gap is why a proxy was reaching for the answer at all.

### B — mounting now needs a wall that is there

*"An envelope-side coordinate or an empty-space test does not alone
establish a wall behind the stalk."* Correct, and worse than it sounds:
measured on the real Zone, the mount as shipped put **27 of 27** SHOT
elements on walls it had never looked for.

**Two** things are asked, and only two, both of the same real geometry:

1. **a real wall behind the stalk** — every wall is built by `_box`,
   which gives it a collision hull, and `all_solid_boxes` reads hulls
   without the architecture filter it applies to meshes, so the wall
   really is in `solids`;
2. **somewhere a body can stand and shoot it from** — sampled out into
   the room, each sample needing floor *and* standing headroom. That is
   the case the brief named by hand: a real wall over a **kill pit** is
   a target nobody can address.

**Not floor under the mount.** A first cut required it and that was
wrong: nobody stands beneath a wall target, and the requirement refuses
a perfectly ordinary one hanging over a walkway recess. It is the
question a *floor-placed* element is owed.

Correcting it moved the count from 11 to **15 of 27**, all in arenas.
Every decline is printed by chamber type and room — `c002`, `c006`
(arena) and `c007`, `c022` (6.8 m corridors, where the along-wall
window left after the threshold clearances lies entirely inside the
side doorway's keep-out). **Unmounted is a documented limitation, not
a silent fallback, and there is no quota.**

**The other consumer was corrected in the same pass**, which is the
part that would otherwise have been left answering the wrong question.
`godot-zone-audit` required ground beneath every element. It still does
for floor-placed ones; a **mounted** element is instead required to
have a standable position with clear line of sight inside weapon range,
using `RoomAudit.player_stands_here` so there is no second notion of
"a body fits". That is strictly more than the floor test ever asked.

Four controls, each verified decisive:

| control | what it proves |
|---|---|
| a target over a real gap | mounted, and hit with the real Static Pulse from a supported position 9 m away |
| a room with no walls | declines, and still builds all 3 elements |
| a wall with nowhere to stand in front of it | declines, and still builds both elements |
| a shot through a 4 m slab | misses |

Preserved through the change: player clearance (`RoomAudit.HEADROOM`),
shot range, the door keep-out, the element count in every decline case,
and the rotated footprint each element claims.

The surface-vouched exclusion is gone with it: rooms are no longer
skipped by category, they are asked the two questions.

### C — the panel reaches the real consumers

Driven through `main.gd`'s own wiring in `godot-boot`, not by calling
handlers by name:

- a station asking opens the panel, and opening it does not leave the
  Zone;
- it holds the player through the same **named** modal claim every
  other panel uses, and closing it releases **only its own** — another
  holder's claim survives;
- a destination chosen reaches the Zone's warp **once**;
- a choice made after the Zone is left **warps nobody**;
- Return to Hub sends `leave_zone` and **never** `abandon_zone`, and
  arrives in the Hub with the panel closed behind it.

Persistence is exercised by `godot-reload`, which restarts a campaign
in a second process against a throwaway save directory the Makefile
wipes first.

---

## 2. Screenshots

| | |
|---|---|
| mounted, player height | `evidence/away-batch-0.3/eye_mounted_target_challenge_c002_0.png` |
| mounted, second room | `evidence/away-batch-0.3/eye_mounted_target_challenge_c018_0.png` |
| **the limitation** | `evidence/away-batch-0.3/eye_unmounted_target_challenge_c007_0.png` |
| the travel panel, open | `evidence/away-batch-0.3/station_travel_panel.png` |
| the F5 schematic | `evidence/away-batch-0.3/nav_schematic_prototype.png` |

The unmounted shot is there on purpose. A review that only ever sees
the rooms that said yes is a review of half the feature.

---

## 3. The opt-in quieter-generation comparison — Dess's, and not started here

**Not implemented, deliberately.** The brief assigns D to Dess and says
plainly that Prod does not also implement it independently. Nothing in
this batch touches the composer's family list, the budget, or normal
generation.

`origin/claude/archipepsi-amalgam-bridge` is at **`afbdb7d`** — the same
head the follow-up inspected — so the experiment has not landed yet.

**What is ready for it on this side**, so integration is a merge rather
than a negotiation:

- `fallback.ACTIVITY_KINDS` is a module constant (a pure hoist, no
  behaviour change), which is the one place a family list has to change;
- the compatibility conditions are already pinned in
  `bridge/tests/test_activity_family_retirement.py` — the schema keeps
  both retired identifiers whatever the composer does, a committed Zone
  carrying either still validates, no kind is translated into another
  on the way in, and the held plate is a constant the engine reads
  rather than a property of the family that generates it;
- `tools/family_retirement.py` measures a family list against the real
  composer, if she wants the before/after in the same shape.

**Station consequences are the part to watch on integration.** A
station's repair is attached to a room that has an activity in it, so
removing a room's only activity removes its repair route. That is
engine-visible, and `_repair_station_for` is where it would show.

---

## 4. Unresolved, with the reason

- **Your diagnostic save.** `.diagnostic-582e954` is on your machine.
  The exact Whistle crossing and the original exit seam stay unresolved
  until a **private copy** of the slot JSON exists. Nothing here claims
  any fixture reproduces them.
- **12 of 27 targets do not mount** in the diagnostic Zone. Every one is
  named. Whether the unmounted look is an acceptable fallback or wants
  a floor stand is an art and design call.
- **`c001/side_left`'s walk still reports LOST.** The sweep says that
  socket is solid, so the walk is the straight-line walker failing to
  get through a wall — which is the wall working. Not chased further.
- **Windows.** No `cmd.exe` here. The `.bat` files have never been
  executed; their decisions live in Python where they are tested.

---

## 5. Awaiting your judgement

- **Comfort of the repaired stairs.** Mechanically the fall is gone.
- **The unmounted target look** — fallback, or floor stand?
- **Whether the F5 schematic is the map** or a sketch a map replaces.
- **Which budget shape** the family retirement takes, once Dess's
  comparison is playable.
- **Whether two puzzles in a room should be alternatives** or
  independent activities with separate payoffs. The truthful feedback
  landed last batch; the design did not.

---

## 6. Verification
