# Batch 015 — the corridor shell family

**Open `S_narrow_entry.png` and `S_gallery_entry.png` side by side first.**

Those are the two ends of the family: 4.0 m of nowhere-to-go, and 8.0 m
with a second storey. If those two frames are obviously two different
rooms, the tier works. If they are two corridors, it does not.

§7 is L3 and was empty. It replaces `chamber_builders.build`'s five
procedural chamber types — the level you named as the point of the tier:
stop Epsilon from visibly repeating one room.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 015*.

| Image | What it answers |
| --- | --- |
| `S_narrow_entry.png` | the pressure corridor — `CORRIDOR_WIDTH_MIN`, full sightline, no cover |
| `S_bays_entry.png` | recesses every 4 m, alternating. The lane still runs clear all 16 m |
| `S_bays_approach.png` | the pocket as a pocket, from where a player meets it |
| `S_stepped_entry.png` | a 1.00 m step — exactly `MAX_VERTICAL_STEP` — and the far floor it hides |
| `S_stepped_from_high.png` | the same corridor from the high half: nothing hidden the other way |
| `S_gallery_entry.png` | two routes, the stair, a deck at 2.60 m out of jump reach |
| `S_gallery_high.png` | standing on that deck, looking down the run |

All seven use the engine's own lens at eye height, unlit by any fixture:
these are envelopes, and Batches 009–014 are what dresses them.

## Two things to know before you judge

**A claim was withdrawn, not fixed.** `shell_corridor_bays` first shipped a
`sightline` of 6.4 m on the argument that alternating recesses make you
weave. `S_bays_entry.png` disproves it — the floor is visible the whole
16 m. Recesses beside a straight lane are cover, not occlusion. The number
is now 16.0, `sightline` is redefined as something a render can be checked
against, and bays justify themselves on routing, encounter and Check
placement instead. The geometry did not change; the claim did.

**The bays are the weak read.** 1.6 m deep at 16 m away is a dark band, and
the head over the opening does most of the work. If that is not enough, a
fixture inside each bay is a likelier fix than a deeper recess — depth
costs lane width this corridor does not have.

Status: **PENDING**. Whether four corridors read as four rooms is a
judgement, and this lane does not self-mark it.
