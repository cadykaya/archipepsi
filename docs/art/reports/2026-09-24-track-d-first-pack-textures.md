# Track D — the first `pack_textures` pair

*Arty*

**Branch `claude/archipepsi-art`, PR #5.**

The owner approved T01 (Ocarina of Time, Forest Temple) and T05
(Kingdom Hearts 2, Twilight Town) as the first pair. They now have
their own pixels and their own rows, and both are **candidates** —
authored, not selected.

---

## 1. What the rows are, and what putting them there means

Six rows, keyed `<pack>/<theme>/<role>`, in
`assets/textures/theme/THEME_PACK.json`:

```
forest_temple/temple_ruin/{wall,floor,accent}
twilight_town/temple_ruin/{wall,floor,accent}
```

Each pack ships three roles and **yields every other role to the
family**. A partial pack is legal by the contract and is the right
shape: repainting a ceiling that both places share buys nothing.

Emitting the rows is the whole of what this lane may grant, and that is
not my reading of the contract — it is Production's own words:

> `candidate` — AUTHORED. Rows for the pack exist in the art lane's
> exported descriptor. Authored is not selected: a candidate is
> viewable in an isolated review scene and nameable by no Zone.

`THEME_PACK_STATUS` lives in their constants, stays `{}`, and a pack
not listed there is a candidate at most whatever the descriptor holds.
No status is written on this side and none is implied.

---

## 2. The two gates, and why neither is my opinion of D-11

**`tools/content/check_pack_table.py`** fetches `theme_packs.py` and
their constants read-only from Production's branch and runs
`pack_table_problems` on the real descriptor. Retyping its rules here
would have produced a check that agrees with my reading of D-11, which
is the thing that needed testing.

It also asserts the rows are **there**. That one matters more than it
looks: a descriptor with no pack table is legal and returns no
problems, so a gate that only ran the contract would have passed
loudest at the exact moment the pack art went missing. Three planted
faults — a universal `hazard` row, a house family's name as a pack id,
a row missing a schema key — must each be refused or the gate fails
itself.

**`tools/content/run_pack_resolution.sh`** resolves every row through
Production's own `ThemePack` in Godot, and asserts the refusal:

```
[packres] PASS -- 6 row(s) resolve through Production's own ThemePack:
refused as candidates, the family answering, and painting only under a
review override that does not outlive it
```

That harness cannot be satisfied by a constant answer. It requires the
pack **not** to bind with the real registry, and to bind under the
resolver's own review override — a resolver stuck on either answer
fails one of the two. It also checks a role neither pack ships still
yields the whole role to the family, that declared `size_px` and
`covers_m` match the loaded texture, and that the override does not
leak past `clear_pack_status()`.

---

## 3. The art: the difference is history, not hue

Both packs keep `temple_ruin`'s ramps. Inventing a palette per pack
would put the game's colour discipline in the hands of whichever pack
was authored last.

* **`forest_temple` is LOSING.** A step down the ramp from the family —
  this is the inside of the ruin, not the daylit outside — with moss
  climbing from the floor, roots through the roof, water out of every
  joint, and blocks big enough to have needed dragging.
* **`twilight_town` is MAINTAINED.** Flat plaster because somebody
  flattened it, timber framing with a diagonal brace because somebody
  braced it, a swept brick plinth, setts laid by somebody paid by the
  square metre.

The structure is the family's: `packmaterials.paint` takes its
`Surface` from `materials.surface_for`, so course pitch, floor edge and
seam positions match. A pack that invented its own pitch would stop
tiling at the join, and the join is exactly where a pack meets the rest
of the game. The bond helpers are public in `materials.py` now rather
than copied — the day the bond changes, a pack cannot keep the old one.

**The first cut of T01's wall was wrong and the sheet showed it.** It
was a brighter cousin of the family's and earned its row nothing. That
pair starts closer than any other will: the family was authored as
"temple ruin" and T01 *is* a temple. The darker interior is what makes
the row worth having, and whether that is enough is a fair question to
put back.

---

## 4. Evidence

`docs/art/review/packs_2026-09-24/` — the same shell three times, only
the pack changed, through Production's `ThemeMaterials`. The harness
refuses a run where the three frames come out identical, because three
identical renders would also print three successes.

Three things I want your eye on are in that README: T05's accent sits
too close to the family's, T01's whole delta is smaller than T05's by
nature, and T05's setts are busy at room scale.

---

## 5. Two things found on the way

**`godot/content/` is what ships and nothing was checking it.** The
course ruling rebuilt 126 baked models and committed them;
`godot/content/shells/` kept the pre-ruling geometry and pixels for six
days — 49 files. `check_art_current.sh` compares `PATHS`, and `PATHS`
stops at `assets/`. Found by accident, when an export for this work
rewrote them. Closed in section 7: the suite runs the export and the
import and fails on any diff under `godot/content/`. Verified
byte-deterministic first, because a gate that cries wolf gets switched
off.

**The pack textures ride the family's export path.** They sit in
`assets/textures/theme/` under a `pack_` prefix rather than in a
directory of their own. A second directory would have meant a second
export path, a second import path and a second place to go stale, in
exchange for a tidier listing. The prefix cannot collide: a family file
is `<one of six known theme names>_<role>.png`.

---

## 6. Next

**Track B** — the distance-readable enemy lineup, judged without audio,
captions, collider overlays or studio lighting. C stays blocked on the
revised machinery/puzzle bounds; E stays reserve.

Still open in Track A: body text, headings and keycaps, the shared
circuit / blocked-exit / control symbols, and page arrows. Item and
state art still waits on Production's real slot vocabulary.
