# Batch 043 — decisions: four settled, one still open

**Arty**

Updated after the owner's rulings of 2026-09-11.

---

## SETTLED, and applied

| | ruling | state |
| --- | --- | --- |
| 1 | the four families stay **neutral** for now | applied; the kit uses ink / lit / dim / spent and nothing else |
| 2 | the player-applied tick is **neutral** | applied, and the `send` argument withdrawn — see below |
| 3 | the **compound double-ring** is kept | unchanged; it identifies a compound, not a fifth mechanical family |
| 4 | **32 px** markers and **16 px** reduced glyphs, subject to gameplay readability | unchanged; still subject to that test, which stills cannot perform |

### On the tick, and why the earlier argument was wrong

The kit proposed `send` #ffd45c for the player-applied tick on the grounds
that `send` means "this one came from you". **It does not.** `send` means
*this leaves for the multiworld* and it belongs to Check transmission — a
narrower thing than player causation, and the distinction is worth keeping.
A gold tick on a `burning` crate would have said an Archipelago event had
occurred.

The tick is neutral, and it moved outside the frame's outer edge so the ink
outlines separate it. Nothing was lost: shape and position were always what
carried it.

---

## STILL OPEN

### `delayed` still has no audio — but it is no longer the only timing channel

**This item is corrected, not closed.**

It previously said the rising pitch was the only channel telling the player
*how long*, and asked whether `delayed` could ship silent. That misread
§19.5, whose row for `delayed` is *"filling-band animation showing remaining
time, rising pitch"* — **the filling band carries remaining time and the
section requires it.**

So the visual half is the primary display and the kit now delivers a real
one: a static graduated track with a source stop and an arrival stop, and a
separate `fill_band` node that grows across it. `room/MACH_delay_*.png` shows
a labelled 4.0 s delay at five known fractions, readable without sound.

What remains for you is only this: **§19.5's hum, arrival click and rising
pitch are an integration requirement with no owner.** They are the second
channel, not the first, and nothing in this batch can supply them.

---

## One finding to note, which needs no decision

§19.5's own table separates `inactive` and `blocked` by **pattern alone**,
while the same section requires two channels of four. This kit adds a
measured brightness difference (22.0 against 41.0 L\*, asserted at authoring
time against an 8.0 floor) so the pair satisfies the rule the section states.
If Design would rather the table were taken literally, that is a design
change and the kit follows it.
