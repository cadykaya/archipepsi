# T01 — Ocarina of Time, Forest Temple: the first game pack, in context

**Arty**

Batch 054 content, photographed in the engine that will show it.
2026-09-22. Branch `claude/archipepsi-art`, PR #5.

**PROPOSAL. Not runtime-bound, not owner-approved, not a production
default.** Nothing in `godot/content/` changed and no room, roster or
placement moved.

---

## What you are looking at

Four frames of one chamber. **Every grey surface is Production's** —
floor, walls, ceiling, and a 2.4 × 3.2 m opening cut in the back wall.
Art built none of it and it is drawn flat and untextured so that the
line between the two lanes is visible rather than asserted.

Everything else is the pack: six pieces, dressing a shell they did not
make, around an opening they did not cut.

| frame | what it answers |
|---|---|
| `FT_approach.png` | Does it read as **one place** from where a player stands? |
| `FT_relief.png` | Do the split panel and the rooted column hold up **in passing**, which is how they will actually be seen? |
| `FT_threshold.png` | Is the 2.4 × 3.2 opening **clear**, seen from the far side with both jambs and the lintel in frame? |
| `FT_chamber.png` | The whole arrangement, the roots on the floor, and the walked line between them. |

---

## The six pieces

| asset | tris | what makes it the Forest Temple and not `temple_ruin` |
|---|---|---|
| `tp_ft_column` | 84 | a root has climbed it. The house column is clean; this one has lost. |
| `tp_ft_wall_relief` | 84 | the panel is **split**, and the split is the subject rather than a weathering detail. |
| `tp_ft_alcove_torch` | 72 | a timber hood over a stone bowl. Not a metal sconce — the house family's light fittings are all metal. |
| `tp_ft_switch_housing` | 60 | Batch 043's wall-switch contract, in timber. Same contract, different material culture. |
| `tp_ft_root_mass` | 96 | floor dressing the house family has none of. It swells, kinks and forks, and nothing in it meets anything square. |
| `tp_ft_door_surround` | 60 | bossed jambs, dressing a fixed opening. |

**The subtheme is a choice and it is stated:** Ocarina of Time has many
environments and this pack is the **Forest Temple**, not an average of
them. The owner's scope addition asks for exactly that.

---

## The opening is re-checked here, on the imported geometry

`build_forest_temple.py` gates the source in Blender. That is not the
same artefact as the `.glb` Godot loads — an export or import that moved
something would pass the Blender gate and still block the door. **A
check that only runs upstream of the export has a gap in it exactly
where the pipeline is.**

So `pack_views.gd` walks the imported surround's **120
vertices** in its own local frame and fails the run if any of them lands
inside the 2.4 × 3.2 rectangle.

```
[ftview] surround: 120 vertices measured against a 2.40 x 3.20 opening
[ftview] no vertex inside the opening -- clear by 0.001 m
```

**The first version of that check used the AABB and was worthless.** A
door surround's bounding box necessarily encloses the doorway — that is
what a surround *is* — so "the box covers the opening" is equally true
of a correct surround and of a solid slab. Only the vertices know.

It is **sabotage-tested in the same run**: the surround is shifted 0.5 m
sideways, the check is required to notice, and the planted failure is
then withdrawn.

```
[ftview] FAIL: the imported surround reaches 0.500 m into the opening at (-0.700, 3.000, 0.230)
[ftview] sabotage refused as it must
```

A check nobody has seen fail is a decoration.

---

## What I think is wrong with it, since nobody else has looked yet

**1. `tp_ft_root_mass` did not read as a root, and has been rebuilt.**
The first version was a 1.60 × 0.34 × 0.10 slab with three thin boxes
crossing it at right angles. In the room it read as two fallen timber
beams: every edge straight, every crossing square, and at 0.10 m tall
the silhouette was all it had. A root that has won a floor is not a
lumber pile.

It is now five segments swelling from 0.22 m at the anchored end down to
0.05 at the tip, each with its own yaw so the run bends twice, a knuckle
taller than either segment it joins where it turns, and a fork that
leaves **at** the knuckle at a shallow angle rather than crossing the
spine square. 48 → 96 triangles, and worth it: the foreground root in
`FT_chamber` is now the piece I would show someone first.

`assert_parts_touch` caught the rebuild's real defect on the way, and
not the one it names. `brushkit.block`'s `rotation_z` is **degrees** —
it calls `math.radians()` on what it is given — and I handed it radians,
so a 54° fork became a 0.95° one, the run stayed straight and the fork
tip landed 0.19 m from anything. The check said "not connected"; the
defect was "not bent". A gate that fires for the wrong stated reason is
still a gate that fired.

The `route` check is now **declared for this asset**, which it was not
before. A piece that sits on the floor is the likeliest one in the set
to invent a step, and it was the only one of the six with no route check
at all. Nothing in it is 0.35 m in both plan axes above the 0.12 m
walk-up — a root that is 0.35 m across *and* 0.22 m tall is a bench, and
the rule is right about benches.

**2. The two columns are lit very differently** — cool on the left, warm
on the right. That is the single torch doing its job and I left it,
because a temple lit evenly from nowhere has no torch in it, only an
orange filter. But it does mean `FT_approach` flatters the right-hand
column and hides the left one's root.

**3. The surround is barely visible from the far side.** `FT_threshold`
shows a thin inner edge, because the dressing faces into the chamber,
which is correct. It answers the clearance question and it is not a
flattering picture of the piece. `FT_approach` is.

---

## The exact unfinished integration work

This is the part that matters more than the pictures.

**1. THE MATERIAL TREATMENT IS MISSING, and it is the biggest missing
thing.** Every one of the six is painted in `temple_ruin` — a house
family, not this pack's own. The completion bar the owner set says a
different tint does not count, and this is a different tint.

It is missing because there is **nowhere to file it**.
`THEME_PACK.json` is:

```json
"themes":   ["concrete_facility", "gothic_stone", "neon_transit",
             "rusted_industrial", "temple_ruin", "void_glitch"],
"textures": { "temple_ruin/wall": …, "temple_ruin/accent": … }
```

A flat theme list and `"<theme>/<role>"` keys. **No pack namespace.** A
pack's own material set can only enter that structure by becoming a
seventh house theme, which is the wrong claim about what it is.

**Prod/Dess own the fix and Art must not build a second loader.** The
smallest backward-compatible seam, for them to accept, amend or refuse,
is written up in `docs/art/theme-packs/COVERAGE.md` §2–§3:
`ThemePack.descriptor()` takes an optional pack id and resolves
`res://content/theme/<pack>/THEME_PACK.json`, falling back to today's
path when unset.

**2. No runtime selection.** `Constants.THEME_BY_GAME_HINT` maps
`"Ocarina of Time" -> temple_ruin` — a house theme, not a pack. Until it
can name a pack id, nothing selects this at runtime and the frames here
are the only way to see it.

**3. Not imported.** The `.glb`s are in `assets/models/batch054/`, not
`godot/content/`. Deliberate: importing is how a proposal turns into
something a room can place, and that is the owner's call.

**4. No owner review.** Recorded as `not started` in the completion
ledger, which is the point of having one.

Art keeps authoring packs as content while all four are pending. **A
pack with no selection hook is an integration task, not a reason to stop
producing.**

---

## How to regenerate

```
.tools/blender/blender -b --python tools/blender/build_forest_temple.py
tools/content/run_pack_views.sh tp_ocarina_of_time
```

The build is in `tools/check_art_current.sh`'s rebuild list, so the
`.glb`s are proven to come from their source on every suite run.
