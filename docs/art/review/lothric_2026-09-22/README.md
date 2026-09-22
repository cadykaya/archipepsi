# T07 — Dark Souls III, the High Wall of Lothric: the last pack with a family of its own

**Arty**

Batch 061. 2026-09-22. Branch `claude/archipepsi-art`, PR #5.

**PROPOSAL. Not imported, not runtime-bound, not owner-approved.**

---

## The runway ends here, and T06 counted it wrong

T06's report said two house families remained. **It is one, and this is
it.**

```
temple_ruin        T01, T05      doubled — T05 is the proof
rusted_industrial  T02, T04      doubled
neon_transit       T03
concrete_facility  T06
gothic_stone       T07           ← this one
void_glitch        UNUSABLE
```

`void_glitch` is not a sixth option. It is Archipepsi's own
**missing-texture theme** — an editor checkerboard with the word `null`
written across it — and `THEME_BY_GAME_HINT` maps it to Archipepsi
itself. Painting The Wind Waker in it would not be a pack wearing
another pack's clothes. **It would be a pack wearing the clothes that
mean "this texture failed to load".**

> **Every pack from T08 on must share pixels with an earlier pack, or
> wait for the namespace. Seventy-four packs are behind this one.**

---

## The subtheme: **the High Wall of Lothric, the aqueduct run**

Dark Souls III has a dozen regions, and Irithyll, Anor Londo and
Archdragon Peak are three more architectures. Blending them is the
average the owner ruled out.

The hint agrees here — the third agreement in seven. Running tally:
agree, **disagree**, agree, none, none, none, agree. Six of 81 games are
hinted at all.

---

## The six pieces

| asset | tris | what makes it this pack's |
|---|---|---|
| `tp_ds_buttress_pier` | 68 | a pier that reaches **sideways**. Every other column in seven packs carries load straight down; this one carries *thrust*. |
| `tp_ds_aqueduct_wall` | 80 | a wall that **carried water** — and the corbels continue **past** the break, which says the channel used to go further. |
| `tp_ds_iron_door_arch` | 76 | a **pointed arch above a square head**, which is how a real wall carries a rectangular opening under a pointed one. Art does not get to round Production's corners. |
| `tp_ds_fallen_voussoir` | 56 | floor dressing that **collapsed** with two stones **still keyed**. Loose wedges are rubble; a keyed pair is an arch that fell. |
| `tp_ds_brazier` | 88 | **the only light in seven packs that stands on the floor** and can be walked around. |
| `tp_ds_lever_stone` | 56 | Batch 043's contract **carved in** — the recess *is* the housing, because a gothic wall does not get a bolted-on box. |

---

## A fourth gate, because three packs tripped over the same thing silently

**`packgates.assert_fits_corridor`.** Nothing a pack ships may exceed
`corridor_height` — 3.6 m.

* T02's dial mark, stacked above its lintel, topped out at **3.78 m**.
* T03's shutter head reached **3.62** at its first size.
* T07's arch springers reached **3.68**.

**All three were poking through a ceiling, and the only thing that ever
noticed was a human reading the manifest's `size` field afterwards.**

A surround is the usual offender, because it is the one piece that *has*
to reach above the 3.2 m door head — and 0.4 m is not much room for a
lintel plus whatever sits on it.

It is **unconditional** in `packkit.build`: every pack ships into the
same corridors, and a piece too tall for them is not something a pack
declares its way out of. It caught T07 and cleared the other six.

---

## The no-foothold rule improved two compositions

**The voussoirs.** A 0.34 m-deep wedge turned 12° measures 0.48 × 0.42
in plan at 0.22 m tall — a step. 0.24 m deep is a real arch-stone
proportion and clears it, so the **keyed pair keeps its height**. The
loose stones could not be narrowed at any believable proportion, so they
**lie at 0.11 m**, under the walk-up — which is what a stone that bounced
does anyway.

**Two standing and two down reads as a collapse. Four standing reads as
a display.** The rule made the piece better.

**The brazier.** A 0.54 m bowl at 0.86 m is a face a player stands *in*.
Raised to 1.40 m its top clears the jump — **and a brazier at head height
on a stand is what Lothric's actually are**, so the rule pushed this
toward the source rather than away from it.

---

## And one thing no gate can say

The buttress springing was first **two stepped wedges**.
`assert_parts_touch` was satisfied — they overlapped by 14 cm — and in
`DS_chamber` they read as **a staircase hanging in mid-air**. A flying
buttress is a continuous ramp; two steps of it are two steps. One longer
wedge now.

> **A gate can say a thing is attached. It can never say it is legible.**

That is the case for the in-engine frames existing at all, and it is why
every pack in this run has four of them.

---

## What I still think is weak

**The aqueduct's channel does not read as having held water** — it reads
as a shelf. What would fix it is a stain line inside the lip, and a
stain line is paint. **Another instance of the same finding.**

**The keyed pair is subtle.** At approach distance the two stones read as
two stones; the joint that makes them an *arch* only lands from the
chamber camera. I would not enlarge them to fix one frame.

---

## The exact unfinished integration work

1. **Material treatment missing** — and the channel's stain line above is
   a concrete example of what it would buy.
2. **No runtime selection**, though the hint at least names the right
   family here.
3. **Not imported.** `assets/models/batch061/`.
4. **No owner review.**
5. **The runway is spent.** T08 cannot be authored honestly without
   either the namespace or a ruling that a recolour-shaped pack is
   acceptable as an interim. **Art's answer is that it is not** — T05 is
   the evidence.

---

## How to regenerate

```
.tools/blender/blender -b --python tools/blender/build_lothric.py
tools/content/run_pack_views.sh tp_dark_souls_iii
```
