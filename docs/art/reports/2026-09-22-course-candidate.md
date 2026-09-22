# The tile-edge course break: three live paths, and a candidate for all three

**Arty**

Batch 055. 2026-09-22. Branch `claude/archipepsi-art`, PR #5.

---

## The short version

A 128 px theme texture covers 4 m. Anything drawn with
`for y in range(0, surface.size, step)` repeats at `step` inside the tile
and at `size % step` across the tile's own edge. At a 38 px pitch that is
38, 38, 38 and then **14**. The rhythm is even for 3.5 m of wall and then
stumbles, once every 4 m, for as long as the wall goes on.

**Three live paths compute such a pitch, not one.** I said it was one,
twice, and was wrong both times. A candidate correcting all three now
sits beside the shipped set. **Nothing is applied.** `assets/textures/theme/`
is untouched and rebuilds byte-identical.

---

## I got the mechanism wrong twice, and both wrong turns are on the record

They are recorded in the files that made them — `check_theme_courses.py`
and `build_theme_candidate.py` both carry the correction in their own
docstrings — because each looked complete at the time and the next person
to touch this will reason the same way.

**First account:** "the courses come from `materials.surface_for()`, which
computes `seams = tuple(range(0, size, 38))`." The owner's response was
that changing the metadata does not prove any painted course changed, and
that the drawing functions had to be traced.

**Second account, over-correcting:** "`surface.seams` paints *nothing* —
`panel_seams`, the only function that draws it, is called zero times — the
mechanism is `paintkit.panel_grid`." I shimmed `panel_grid` and rebuilt.

**The pixels refused it.** `concrete_facility_wall_ribbed` came out
**byte-identical**. Its branch takes no `panel_grid` call at all; there is
a comment saying so ("No horizontal courses: the ribs ARE the rhythm
here"). And it still measures a 38 px rhythm in the exported PNG.

38 px is `surface_for`'s seam pitch. `panel_seams` is dead, but the tuple
is not: `paintkit.near_seams()` reads it to aim speckle at **thirteen**
call sites, `paintkit.bolts()` puts a bolt row on **every** seam, and two
treatments run weep streaks down from them. **The seams paint grime, bolts
and streaks. They just do not paint lines.**

That byte-identical texture is the whole reason this account is the third
one and not the second. A one-path shim looked right and measured wrong.

---

## The full census

| # | path | what it draws | status |
|---|---|---|---|
| 1 | `materials.surface_for()` seams, 1.2 m = 38 px | speckle zones (13 sites), every bolt row, 2 weep-streak loops | **live** |
| 2 | `paintkit.panel_grid`, per-treatment `pitch_metres` | horizontal + vertical seam lines | **live** |
| 3 | inline loops in the treatments | ribs 1.0 m, floor plates 2.0 m, soffit ribs 0.6 m, chequer 0.14 m, masonry course/block pairs, station tile 0.30 m, mortar joint 0.42 m, editor cell 0.5 m, 7 bolt pitches 0.18–0.5 m | **live** |
| 4 | `paintkit.panel_seams` | would draw `surface.seams` as lines | **dead — called zero times** |

Twenty-one call sites in `materials.py` and two in `paintkit.py` now route
through one function, which is what makes the fourth account unlikely to
be needed.

---

## What the candidate does

`paintkit.SNAP_COURSES` is a module flag, **off by default**.
`Surface.course(metres, minimum=2)` replaces `texels()` at every wrapping
pitch. With the flag off it returns exactly what those call sites computed
before it existed.

**That is proven, not asserted.** `tools/check_art_current.sh` rebuilds
every generated asset in the repository and diffs it against the tree:

```
check-art: PASS -- every generated asset matches its source.
```

The shipped theme set, every prop, every shell, every kit: unchanged.

With the flag on, `snap_to_tile()` returns the divisor of the tile nearest
the designed pitch, preferring the larger on a tie.
`tools/blender/build_theme_candidate.py` turns the flag on and writes 37
textures to `assets/textures/theme_candidate/`, plus `CANDIDATE.json`.

**The pitches are recorded by watching `Surface.course`, not by listing
call sites from memory** — listing them from memory is exactly what
produced two incomplete corrections.

---

## What moves, and by how much

**The divisors of 128 are the powers of two.** That is coarse, and the
coarseness is the cost of the correction rather than an implementation
detail.

| designed | was (px) | now (px) | |
|---|---|---|---|
| 2.0 m | 64 | 64 | unchanged |
| 1.5 m | 48 | 64 | **moved** |
| 1.35 m | 43 | 32 | **moved** |
| 1.2 m | 38 | 32 | **moved** |
| 1.2 m (`surface_for` seams) | 38 | 32 | **moved** |
| 1.1 m | 35 | 32 | **moved** |
| 1.0 m | 32 | 32 | unchanged |
| 0.9 m | 29 | 32 | **moved** |
| 0.86 m | 28 | 32 | **moved** |
| 0.75 m | 24 | 32 | **moved** |
| 0.6 m | 19 | 16 | **moved** |
| 0.55 m | 18 | 16 | **moved** |
| 0.5 m | 16 | 16 | unchanged |
| 0.42 m | 13 | 16 | **moved** |
| 0.4 m | 13 | 16 | **moved** |
| 0.35 m | 11 | 8 | **moved** |
| 0.3 m | 10 | 8 | **moved** |
| 0.28 m | 9 | 8 | **moved** |
| 0.22 m | 7 | 8 | **moved** |
| 0.2 m | 6 | 8 | **moved** |
| 0.18 m | 6 | 8 | **moved** |
| 0.14 m | 4 | 4 | unchanged |

**18 of 22 move.** The worst are 1.5 m → 2.0 m and 0.75 m → 1.0 m, both a
third; 1.35 m → 1.0 m is a quarter.

**`pitch // 2` does not fix this and I am not proposing it.** The owner
said so directly: moving where the run starts relocates the odd interval
without removing it. Only a pitch the tile is a whole multiple of removes
it.

---

## The measurement

`tools/content/check_theme_courses.py` reads the **exported PNGs**, finds
the rows and columns that read as a course, and takes the gaps including
the one across the wrap.

**The verdict is now exact, not a heuristic.** For a lattice of step `s`
in a tile of `n`, the observed wrap gap is `(n % s) + m·s` when the
detector misses `m` lines. So

> `wrap % pitch == 0` ⟺ `n % s == 0` ⟺ the pitch divides the tile

for *any* number of missed lines, because `n % s` is strictly less than
`s` and therefore never a positive multiple of it. This matters: the
detector misses the course at row 0 whenever the tile's parity makes that
row bright, which inflates the wrap by a whole pitch — **and two versions
of this file called that a break.** A ±1 tolerance carries the run-centroid
rounding on both the inside gaps and the wrap.

It also now needs **four** lines before it will speak. Three lines is the
shape that edge wear at both tile edges plus one mark in the middle makes.
`void_glitch_accent` is exactly that shape — a flat field with the word
"null" written across it and no course anywhere — detected as
`[0, 63, 126]` and **reported as a 63 px course breaking at the wrap for
two versions of this file.** It was never a course.

| set | broken axis/texture pairs |
|---|---|
| shipped `godot/content/theme/` | **4** — `concrete_facility_wall/v` (38, wrap 14), `concrete_facility_wall_ribbed/v` (38, wrap 14), `gothic_stone_accent/v` (18, wrap 2), `rusted_industrial_wall/h` (7, wrap 9) |
| candidate `assets/textures/theme_candidate/` | **0** — 6 pairs read, every one even |

Nine to ten textures per run are `not read`: the detector finds dark rows,
which is a proxy, and a course drawn faintly or over a busy motif does not
clear the bar. **Those neither confirm nor deny a break.** The arithmetic
in `CANDIDATE.json` covers them; the pixels do not, and the tool says so
rather than filling the gap with a guess. `--lines` prints the detected
positions, which is what it took to see that the detector had read the
wrong thing — twice.

---

## Same-scale evidence

`docs/art/review/course_candidate_2026-09-22/`, from
`tools/content/run_course_candidate.sh`.

**Four strips.** 24 m of wall — six repeats of a 4 m tile — shipped above,
candidate below, one camera, one flat light, one frame. Flat light on
purpose: a raking light is how you sell a surface and also how you hide
where the courses land.

* `STRIP_concrete_facility_wall.png` — panel courses 1.2 → 1.0 m. The
  shipped strip's top band is visibly shorter than the ones below it, six
  times across the frame.
* `STRIP_neon_transit_wall.png` — the clearest of the four. A half-width
  row of station tiles at every tile edge in the shipped strip; an even
  grid in the candidate.
* `STRIP_gothic_stone_accent.png` — masonry course 0.55 → 0.5 m, block
  1.1 → 1.0 m.
* `STRIP_rusted_industrial_wall.png` — corrugation 0.22 → 0.25 m.

**Two rooms.** `ROOM_A_shipped.png` and `ROOM_B_candidate.png`: the shipped
`shell_corner_left`, instantiated twice, `concrete_facility` on both, one
texture set each, bound with per-surface overrides so the shared mesh is
never touched — 18 surfaces per instance, and the harness fails if the two
counts differ. Same camera offset from each instance, so the framing is
the comparison and not a variable in it. This is the realistic case: a 6 m
room where the tile repeats one and a half times and the break lands once.

This is an **isolated review scene**. Not a runtime binder, not Theme Pack
infrastructure, not a selection. `ThemeMaterials` is Production's consumer
and stays Production's. The candidate textures are read from disk at run
time, never imported, never runtime-bound, never approved.

---

## My own read, which is not the decision

The owner asked for a judgement, so: **the neon_transit and
concrete_facility strips convince me and the gothic one does not.**

On `neon_transit_wall` the shipped break is a half-tile of station tiling
at a regular interval, and that is a mistake in any century. On
`concrete_facility_wall` the short top course is visible and slightly
cheapening. Both improve.

On `gothic_stone_accent` the correction costs something real. `_coursed()`
exists to draw a wall that was *laid* — its docstring says a grid of
squares is tiling and the eye names it as tiling instantly. Snapping puts
the course at 0.5 m and the block at 1.0 m, an exact 2:1, and the stagger
plus hash jitter is now the only thing between it and the grid it was
written to avoid. It reads more mechanical. **That is a downgrade bought
with an upgrade, and I would not apply it to gothic without looking at a
0.5 / 1.5 m bond first.**

The flag is all-or-nothing today. Making it per-treatment is a small
change and I have not made it, because which treatments want it is the
question being asked, not the answer.

---

## Judgements deliberately kept apart

* **Authored does not mean good and a numerical flag does not mean bad.**
  Nothing here was changed because a number was flagged.
* **`void_glitch`'s border is a separate judgement** and is not touched.
  The detector's false positive on `void_glitch_accent` has been removed
  because it was measuring text and edge wear, not because the texture
  needed defending.
* **Intentional irregularity is a real choice.** The tool reports; a human
  looks.

---

## The exact unfinished work

1. **The owner's ruling**, per treatment or wholesale. Nothing proceeds
   without it.
2. **A per-treatment flag** if the ruling is mixed. Small; not written.
3. **`propkit.py` shares the defect, is NOT in this candidate, and WOULD
   change if the default were flipped.** Seven sites set
   `surf.seams = tuple(range(0, PROP_SIZE, surf.texels(m)))` at 0.22,
   0.34, 0.46, 0.5 m and one caller-supplied `seam_metres`, and two call
   `paintkit.panel_grid` — which now routes through `Surface.course()`
   like everything else. So `build_theme_candidate.py` sets the flag for
   its own process only and paints themes only; props are untouched in
   this candidate. **But "accept the candidate" and "flip the default"
   are not the same decision:** flipping the default repaints every prop
   in `batch043` and the kits as well. I have deliberately not checked
   whether a prop face wraps its texture or samples a sub-rect of it — if
   it samples, there is no wrap to break and the change is pure churn.
   **Do not assume the theme ruling carries to props.**
4. **`paintkit.panel_seams` is dead code.** Not deleted; deleting it is not
   what was asked and its docstring is load-bearing for `panel_grid`'s.
5. **If the candidate is accepted**, the shipped set regenerates by
   flipping one default, and then `verify_theme_set.py --write` →
   `THEME_PACK.json` → `import_godot_content.sh`. The existing 0.3
   comparison, review snapshots and original saves stay untouched.
6. **Pack identity is still Prod/Dess's.** `THEME_PACK.json` has a flat
   `themes` list and `"<theme>/<role>"` keys with no pack namespace, so
   ordinary production selection of a game pack is still blocked. That
   blocks *selection*, not candidate authoring, and this candidate is
   authoring.

---

## Files

| | |
|---|---|
| `tools/blender/paintkit.py` | `SNAP_COURSES`, `snap_to_tile()`, `Surface.course()` |
| `tools/blender/materials.py` | 21 wrapping pitches routed through `course()`; `surface_for` snaps its seam pitch |
| `tools/blender/build_theme_candidate.py` | the candidate build, on the flag |
| `tools/content/check_theme_courses.py` | the measurement; `--dir`, `--lines`, `--strict` |
| `tools/content/course_candidate_view.gd` | the in-engine before/after |
| `tools/content/run_course_candidate.sh` | its runner |
| `assets/textures/theme_candidate/` | 37 textures + `CANDIDATE.json` |
| `docs/art/review/course_candidate_2026-09-22/` | 4 strips + 2 rooms |
