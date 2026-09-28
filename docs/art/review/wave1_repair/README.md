# Wave 1 — the eight Art-owned findings, repaired

Production measured **2 findings on the plenum, 5 on the yard, 4 on the
span** before its own correction pass. All eleven were reproduced here by
running Production's unmodified `RoomAudit` in a detached read-only
worktree at `fc2cc41`. They split cleanly by cause.

## Three are the entry-at-origin assumption — left untouched

| room | finding | why it is superseded |
| --- | --- | --- |
| plenum | `the entry at (0,0,0) is sealed` | its entry doorway is at **y = 68** — the top of a 72 m shaft you descend |
| yard | `the entry at (0,0,0) is sealed` | its entry doorway is at **x = −43** — the west end of an 84 m field |
| span | `the entry at (0,0,0) is sealed` | its entry doorway is at **y = 14** — on the deck, not in the basin |

Under the owner's authored-entry ruling a room's local origin has no
semantic meaning, and none of these rooms claims an entrance there.
"Fixing" the plenum's would mean moving its entrance to the bottom of the
shaft, which is the one thing its approved form exists to do differently.
**Production owns these.** Nothing was moved, added or translated for
them.

## Eight are Art's, and all eight were the same mistake

**A declared point carrying the CENTRE of the thing it names.**

| room | finding | was | now |
| --- | --- | --- | --- |
| yard | `cover_0` inside solid geometry | `−26.0, 0.3, 16.0` | `−26.0, 0.3, 13.4` |
| yard | `cover_1` inside solid geometry | `−9.0, 0.3, 34.0` | `−9.0, 0.3, 37.1` |
| yard | `cover_2` inside solid geometry | `11.0, 0.3, 15.0` | `11.0, 0.3, 12.4` |
| yard | `cover_3` inside solid geometry | `27.0, 0.3, 33.0` | `27.0, 0.3, 36.6` |
| span | `cover_0` inside solid geometry | `−9.0, 0.3, 22.0` | `−12.1, 0.3, 22.0` |
| span | `cover_1` inside solid geometry | `8.0, 0.3, 44.0` | `10.6, 0.3, 44.0` |
| span | `cover_2` inside solid geometry | `−7.0, 0.3, 66.0` | `−10.6, 0.3, 66.0` |
| plenum | `reward` inside solid geometry | `0.0, 29.333, 10.0` | `5.25, 29.333, 10.0` |

Seven `cover` sockets were declared at the centre of their own cover
block, buried in 1.9 m of concrete. A cover socket is an **offer of
somewhere to be**, and the middle of a crate is not somewhere to be. They
now sit beside the block, on the far side from the room's centre line, so
the block is between the player and the open middle — which is what cover
is for.

The plenum's `reward` volume was declared at the centre of the collar,
which is the centre of **eight metres of solid machine**. It now sits on
the collar band at radius 5.25, opposite the bridge, so reaching the
objective means walking the collar.

**Both stances are derived** — `roomkit.cover_stance` from the block's
own centre and size, `build_plenum._reward_spot` from the collar and the
bridge — because the cause was two lists carrying the same numbers and
drifting apart.

## Nothing moved that you approved

| | plenum | yard | span |
| --- | --- | --- | --- |
| triangles | 1656 | 516 | 672 |
| collision pieces | 117 | 39 | 54 |
| surfaces / traversal / size / offers | unchanged | unchanged | unchanged |

The top-entry/bottom-exit shaft, the ~16 m yard, the one-way mid-span
drop and every authored entry elevation are exactly as they were. All
three remain `review: "pending"`.

## Result

Production's own audit, re-run against the repaired pack in the same
worktree:

```
BEFORE  plenum structural=0 measured=2   yard 0/5   span 0/4
AFTER   plenum structural=0 measured=1   yard 0/1   span 0/1
```

The one remaining finding in each room is the entry-at-origin one.
Every other shell — the hall and all eight P2 rooms — reports
`structural=0 measured=0` before and after.

## The views

The repair moved declared points and no geometry, so a matched
before/after render would be two identical pictures. These compose a
derived figure over the real shell: **red where the point was, green
where it is**, grey for the block or ring it belongs to.

| | |
| --- | --- |
| `W1_yard_cover` | one cluster close up — the red pin is swallowed by the block |
| `W1_yard_wide` | all four yard clusters from the crane |
| `W1_span_cover` | the same defect and the same repair, in the span |
| `W1_plenum_reward` | the collar band, with the red pin behind the machine |

---

## One observation, not a repair

Each plenum collar is modelled as an annulus — its collider mesh measures
radius **4.00 to 6.75**, with a real hole. Godot imports these as
`ConvexPolygonShape3D`, and **the convex hull of an annulus is a disc**,
so in the engine each collar's collision fills its own hole out to 6.75.

The three `landing_N_to_collar_K` traversal segments end on the machine's
central axis, which is inside that filled hull — and, for two of the
three, inside the machine's own collider as well.

**This was not among the reported findings and nothing was changed for
it.** It is the same cause as the eight above — a declaration carrying
the centre of the thing it names — but it is currently failing no check,
it sits in exactly the area Production's parallel composition work
touches, and changing traversal declarations underneath that is how two
correct repairs turn into one conflict. Raised here for Production and
the owner to decide.
