# The course ruling, applied — two treatments accepted, four not

**Arty**

2026-09-24. Branch `claude/archipepsi-art`.
Regenerate: `tools/content/run_course_ruling.sh`.

---

## The ruling

The Batch 055 candidate snapped every wrapping course pitch in every
house family at once. **The owner ruled on it per treatment**, not
wholesale, and did not flip a global default:

| family | ruling | state |
|---|---|---|
| `concrete_facility` | **accept the snapped candidate** | **shipping** |
| `neon_transit` | **accept the snapped candidate** | **shipping** |
| `gothic_stone` | **do not accept** — investigate a 0.5 m / 1.5 m bond instead | unchanged |
| `rusted_industrial` | pending — no owner-facing visual evidence yet | unchanged |
| `temple_ruin` | pending | unchanged |
| `void_glitch` | pending | unchanged |

**Not inferred from the arithmetic.** The numbers say every unsnapped
pitch breaks at the tile edge; they do not say whether the repair looks
better, and only three treatments have been looked at.

**Props are excluded structurally, not by remembering to.** Only
`materials.surface_for` gives a `Surface` a `theme`, and `propkit`'s two
constructors pass none — so a prop surface can never match a snapped
family however `SNAP_COURSE_THEMES` is later edited.

---

## What moved

Exactly eight textures, in exactly the two accepted families:

```
concrete_facility/accent   concrete_facility/ceiling
concrete_facility/wall     concrete_facility/wall_ribbed
neon_transit/accent        neon_transit/ceiling
neon_transit/floor         neon_transit/wall
```

Checked against the descriptor rather than asserted: the 8 rows whose
`sha256_16` changed in `THEME_PACK.json` are those 8, and **no row
outside the two accepted families moved.**

## What it did to the measurement

| texture | before | now |
|---|---|---|
| `concrete_facility_wall` | `v 38 wrap 14` **BREAKS** | no uneven wrap |
| `concrete_facility_wall_ribbed` | `v 38 wrap 14` **BREAKS** | `h 32 wrap 33` — even |
| `neon_transit_wall` | not read | `h 8 wrap 1` — even |
| `neon_transit_accent` | not read | `v 16 wrap 1` — even |
| `gothic_stone_accent` | `v 18 wrap 2` **BREAKS** | **unchanged — refused** |
| `rusted_industrial_wall` | `h 7 wrap 9` **BREAKS** | **unchanged — pending** |

**Two `BREAKS` remain in the shipped set and both are on treatments the
owner did not accept.** That is the ruling working, not a regression.

---

## The frames

Four strips, 24 m of wall each — six repeats of a 4 m tile — **before the
ruling above, shipping now below**, same scale, same flat light.
`STRIP_neon_transit_wall.png` is the clearest: a half-tile row of station
tiles at every tile edge in the upper strip, an even grid in the lower.

`ROOM_A_before.png` / `ROOM_B_now.png` are the shipped
`shell_corner_left` twice from the same camera offset, `concrete_facility`
on both — the realistic case, where the tile repeats one and a half times
and the break landed once.

**"Before" is not a candidate directory.** It is what shipped at
`4093ded`, reconstructed from git into a scratch set that the runner
deletes again. A second copy of shipped textures in the tree would be a
second thing to keep in step.

---

## Still open, and deliberately not blocking anything

* **`gothic_stone` needs the 0.5 m / 1.5 m bond comparison** the owner
  named. Queued, not started.
* **`rusted_industrial`, `temple_ruin` and `void_glitch` stay pending**
  and will be packaged into one compact same-scale review later.
  `build_theme_candidate.py` still renders them through
  `paintkit.SNAP_ALL_COURSES`, which is the review override and is not a
  way to ship an unruled treatment.

The owner's instruction was explicit that this old review must not block
the active tracks. It does not: the accepted half is shipped and the rest
is a queued review package.
