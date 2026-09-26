# Batch 043 / 052 — decisions: four settled, six still open

**Arty**

Updated after the owner's rulings of 2026-09-11, and again on 2026-09-22
when Batch 052 drew the eleven statuses the runtime can raise and the kit
had never drawn. Items 1–4 are yours and settled; item 5 onward are open,
and items 5–9 are new.

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

---

# Batch 052 — five more, opened by drawing the other eleven

Batch 043 drew Design 6 §15.2's thirteen statuses. The runtime implements a
different thirteen — `lightened` plus ECHOES §8's twelve — and the overlap
between the two sets is **two**. Batch 052 draws the eleven that were
missing, so the kit now covers the whole closed vocabulary `apply()` will
admit. Drawing them raised five questions I could not answer without
deciding something that is yours.

---

## 5. Four of the twenty-four are statuses the player WANTS, and the kit has no channel for that

The four family frames were designed for a vocabulary of things done **to**
a target. `haste`, `empowered`, `regenerating` and `low_profile` are things
the player wants — and `turncoat`, from the original thirteen, already was.

The kit has three channels and none of them is free:

- **frame shape** carries family, by §33.7
- **the double ring** carries compound, by this kit's own proposal
- **the tick** carries *the player caused this*, which is not the same claim

Nothing says *this one is good for whoever is wearing it*. I have **not**
invented a fifth channel, for the same reason Batch 043 did not invent a
fifth colour: it would be a taxonomy decision taken by the art lane in the
one place §15.2 explicitly settled the count ("keeps the family count at
four and the compound table unchanged").

**What the drawings do instead**, because that part is Art's: the four
benefits are drawn as gain — a double chevron rising, a wedge driving
forward, a cross, a slab that covers — and the nineteen detriments as loss,
denial or damage. That is a silhouette decision and it is made. Whether the
distinction deserves a channel of its own is not.

**If you want one**, the cheapest thing that does not collide with anything
is a second tick position — the existing tick sits proud of the frame's
lower right, and the mirror position is empty. One word from you and it
exists; it does not exist on my say-so.

---

## 6. `exposed` and `vulnerable` are near-synonyms in two vocabularies

`exposed` (§15.2, COGNITIVE, *"Nothing is covering it."*) sets the target's
Defense **stat** to `0.0` and is actor-only — §15.3's rule 3, the union's
single named exception to the no-damage-modification rule.

`vulnerable` (ECHOES §8, implemented) multiplies damage taken by 1.5 and
applies to `self` and `enemy` both.

They are genuinely different mechanics and they will read as the same
sentence to a player. The kit does what it can: they are 0.656 apart under
the new gate — a shield still standing but notched and pierced, against two
parted halves with no shield at all — and `MUST_READ_APART` now holds that
distance open against future redraws.

**What I cannot do is decide whether both should exist.** If the destination
keeps `exposed`, a player will one day carry both at once and the HUD will
show two markers meaning something very close. That is a design call.

---

## 7. `empowered` is in COGNITIVE, and it is the weakest of the eleven

ECHOES §8 gives the eleven no family, so Art proposed one for each from what
the runtime measurably does. Ten of them argue cleanly:

| | goes to | because the runtime |
| --- | --- | --- |
| `slowed`, `frozen` | KINETIC | move `ground_friction`, 0.4 and 0.6 — the same channel as `slippery` |
| `haste` | KINETIC | is the one status on `move_speed` itself |
| `marked`, `low_profile` | COGNITIVE | change what notices the target; `enemy.gd` reads both |
| `vulnerable` | COGNITIVE | drops the guard, the axis §15.2 chose for `exposed` |
| `stunned` | PERMISSION | denies attack AND move — `silenced` and `rooted` at once |
| `shocked` | MATERIAL | is `conductive`'s other half |
| `poisoned` | MATERIAL | is half of `dot_per_second()`; `burning` is the other half |
| `regenerating` | MATERIAL | is the same channel as those two, opposite sign |

`empowered` does not. `damage_dealt` × 1.5 is not kinetic, not a permission
and not a material property. It sits in COGNITIVE on §15.2's "what it can
do" clause, which is the thinnest reading in the set, and I would rather
name it than argue it into looking solid.

**If you read it otherwise, the frame changes and the drawing does not** —
that is the whole point of carrying family in the frame.

---

## 8. Three implemented statuses have nowhere on screen to go

`haste`, `low_profile` and `regenerating` are implemented on `self` and
nothing else. This kit's entire presentation model is *a marker anchored to
a target*, and **the player is the camera**.

The runtime-legality gate found this by refusing to render them: two of the
three had been placed on enemy stand-ins in the first pass of
`STATUS_runtime_*.png`, and the assertion caught both. That shot now places
**ten of thirteen** and its caption says so.

They are drawn and they are on every sheet. What they have no answer for is
*where*. The answer is almost certainly the persistent HUD tier, which the
preview mocks with rectangles and deliberately does not design — **so this
is an integration question for whoever owns the HUD, not a gap in the kit.**
Name the owner and I will fit the markers to whatever tier they specify.

---

## 9. Three fields on the eleven are Art's, not a design's

ECHOES §8 names the eleven and stops: no family, no target list, no
duration, no sentence. Each of the eleven therefore carries a `*_source`
field in `status_kit.json` saying where its values came from:

- **family** — Art's proposal, argued above, per glyph.
- **targets** — the runtime's own `ECHO_STATUS_SUPPORTED_TARGETS`,
  translated into §15.2's words. The design is silent and inventing a wider
  list would have been Art writing design.
- **sentence** — Art's, in §15.2's voice.
- **duration** — `5.0 s` throughout, which is what Production's own drivers
  (`lab_driver.gd`, `stats_driver.gd`) apply. It is not a tuned figure and
  `chance` is omitted entirely, because nothing publishes one.

**None of these needs a decision from you unless you disagree with one.**
They are marked so that a later reader can tell what was quoted from what
was proposed, which is the part that goes wrong silently.

---

## One thing fixed rather than asked about

`status_kit.json` recorded the player tick as `#ffd45c (send)` — for as long
as the kit has existed, and for the whole time `DECISIONS_FOR_OWNER.md` has
said your ruling 2 (*the tick is neutral*) was **applied**. The art was
right; the manifest was wrong, in the one field a reader would trust it for.

The colour block is now derived from the palette the pixels are painted
from, so it cannot say one thing while the art says another again. The tick
reads `#f6f9fb`.
