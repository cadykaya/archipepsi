# ECMS Glyph `ebe949b` — trial report

**Arty**

**Against:** the owner's toolchain refresh of 2026-09-22
**Candidate:** `cadykaya/ECMS-GLYPH` `claude/feature-planning-roadmap-5oibiu`
@ `ebe949b613b9426e22320ea87069641149ba46e0` (open draft PR #5, unmerged)
**Baseline, untouched:** `/home/user/ecms-glyph` @ `6c80b63` — the revision
`status_kit.json` records and the Batch 043/052 kit is authored with.

**This is a trial, not an adoption.** Nothing in Archipepsi is built with the
candidate, no asset was regenerated, and the baseline's working tree was not
moved. The trial lives in a **separate git worktree** at
`/home/user/glyph-trial`; the baseline's HEAD and working tree were verified
unchanged after it was created.

---

## 1 · What was actually exercised

The owner asked for actual discovery and one disposable edit/render/reopen/
export test before anything else. All four steps ran, and the image was
opened rather than merely produced.

| step | how | result |
|---|---|---|
| build | `npm install && npm run build` | clean |
| discovery | `glyph doctor` | every package compiled; chromium found; **23 extensions served**, including the four the review named — `check_set`, `check_tiling`, `nine_slice`, `check_material` — plus the Godot sidecars |
| **edit** | `easel.draw(...)` | committed `rev_3BDNNCKJV58SB0TER3T5YG` |
| — | the same strokes again | `changedNothing: true`, `revision: null` — **the guide's claim that a repaint commits nothing holds** |
| **render** | `easel.view({ scale: 8 })` | PNG written, and **opened**: the plate, its ink outline and the lit notch are what was drawn |
| **reopen** | `glyph describe`, fresh process | head revision matches; `lead_owner` intact |
| **export** | `glyph project-revision` | wrote cels, palettes, variants and a projection that **declares exactly what it omits** |

**MCP was not used.** This host does not have the Glyph MCP server connected,
and the owner's note is explicit that MCP only helps when the host really
connects and exposes images. The CLI/easel route was used instead and the
images were opened with the ordinary file reader, which is what "actually open
the generated image" means here.

### Attribution is enforced, and correctly

`glyph log`:

```
1  rev_0D7K…  act_cadykaya  project created
2  rev_MK6A…  act_arty      study: a 32x32 canvas
3  rev_3BDN…  act_arty      a plate with a notch, to prove an edit lands
```

The agent guide records that two earlier art trials were dispatched as the
owner and left fifty-one revisions crediting a person who did not draw them.
Driven as the guide instructs — agent identity, `on_behalf_of` the owner — the
candidate records it right. The CLI also refused a mutation outright with
`PERMISSION_DENIED: actor lacks a grant permitting "edit"`, and refused
another with *"is a mutation and must name an open transaction (GLY-PCL-002)"*.
**The authority model is real, not advisory.**

Its error messages name the field, what they got and what they wanted
(`"import.analyze.bytes" must be an array … got: string`;
`scope.creates has no kind "representation"`, with the accepted list). That is
the difference between an afternoon and a morning.

---

## 2 · The adoption proof, and the finding it produced

The review recommends: *"Repeating wall/floor/trim texture trials: inspect
actual tiled output rather than treating one attractive tile as sufficient."*

**Archipepsi has never checked this.** The six theme families' wall, floor and
trim textures are world-projected at a texel density, so they repeat across
every large surface, and nothing has ever looked at a repeat.

Eighteen textures (6 themes × wall/floor/trim) were copied into scratch,
imported into disposable containers and put through `x-glyph.check_tiling`
(`wrap_join`, depth 1 and 4, both axes). **Read-only on the repository; every
container and every output lives in `/tmp`.**

`wrap_join` calls fifteen of the eighteen **not tiling**. The three it passes
are `concrete_facility_floor`, `void_glitch_trim`, and
`rusted_industrial_wall` at depth 4.

### I did not take that on trust, and I was right not to — twice over

**First I disagreed with it.** An independent check in plain Python — decode
the PNG, compare the abutting columns and rows against the harshest transition
*inside* the texture — said "no seam" on all four samples, including the two
the tool called worst.

**Then I looked, and the tool was right.** `void_glitch_wall` tiled 3×3 shows
an unmistakable bright line at every repeat boundary, top and left. My check
missed it because I used a single global maximum, and that texture contains
255-steps internally, so nothing at the join could ever exceed them.
**My instrument was the bad one.** `check_tiling`'s comparison is local; mine
was not.

The control confirms it from the other side: `concrete_facility_floor`, which
the tool passes, tiles visibly cleanly — its grout grid is evenly spaced with
no stronger line at the 128 px repeat.

### And then the finding dissolved, which is the real lesson

The line at `void_glitch_wall`'s boundary is `(0, 255, 191)`. The theme's own
declared `trim` anchor in `assets/art_palette.json` is **`#00ffbf`** — the same
colour. Row 1 is 126 of 128 pixels of it.

**It is an authored border in the theme's own trim colour, not an accident.**
For a "void glitch" family, a wireframe grid across a wall is a plausible
intent, and it is certainly not something the art lane should quietly remove
because a checker printed `tiles: false`.

**So no texture was changed, and none should be on this evidence.** Fifteen
"does not tile" verdicts are fifteen questions for the owner's eye, not fifteen
repairs. This is exactly the owner's line that *a render or numerical critique
is not a visual approval*, and this lane's own rule that a gate which refuses
correct art is a gate that gets switched off.

---

## 3 · Recommendation

**Adopt `check_tiling` as a REPORTING step, never as a gate.** The same shape
as `run_projectile_legibility.sh` in Batch 051: it runs, it prints, it exits 0,
and a human decides. It found a real, visible, repeating boundary that a naive
numerical check missed entirely — that is worth having. It cannot tell an
authored border from a mistake, and it does not claim to.

**Do not adopt the candidate as the authoring build yet.** Batch 043 and 052
are authored at `6c80b63` and `status_kit.json` records that SHA beside every
asset. Moving the authoring build is a re-render of 32 markers and 5 frames
whose pixels are currently reproducible byte-for-byte, and the owner's note is
explicit that this is not a promoted release. The baseline stays.

**Worth a later look, in this order:** `nine_slice` for equipment panels (the
status kit has no panel work yet), `check_set` for the 32-marker family at
consistent native scales — which `make_sheets.py` does by hand today — and
the palette export, which could replace eyeballing theme colours between
Blender and 2D.

**Not evaluated, deliberately:** the studio UI, MCP transport, animation
tooling, autotile, and every material facility beyond reading a declared
palette. The owner's note forbids a PBR/style overhaul and the certified-scale
performance failure is not cleared; no benchmark was run and no material
authority was touched.

---

## 4 · Housekeeping

- `/home/user/glyph-trial` is a detached worktree at the pinned SHA. It can be
  removed with `git -C /home/user/ecms-glyph worktree remove /home/user/glyph-trial`.
- `/home/user/ecms-glyph` is at `6c80b63`, clean, and gained only fetched
  objects. `docs/art/review/status_2026-09-11/` regenerates byte-identically
  from it, as it did before this trial.
- No repository merge, no installation change, no credential, no subscription,
  no scheduled wake-up.
