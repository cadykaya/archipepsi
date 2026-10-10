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

### The second case says the same thing, and settles it

`concrete_facility_wall` is the one that matters most — `concrete_facility` is
`common.DEFAULT_THEME` and eleven shells wear it, so it is the most-seen wall
surface in the game. Tiled 3×3 it shows strong dark horizontal bands at what
looked like every repeat, and `check_tiling` flags it with 17 horizontal and
26 vertical mismatches.

**Measured, it has no seam at all.** Row-mean luminance across the join —
bottom row against top row — steps by **2.2** out of 255. The biggest step
*inside* the texture is **178.6**, at rows 101→102, with more dark courses at
y≈38 and y≈76. The bands are three authored courses in a concrete panel wall,
evenly spaced, and they are what the tiled sheet shows. The join is continuous.

So on **both** cases examined closely — the most severe by the tool's own
number, and the most consequential by usage — the flagged boundary is authored
structure. That is a property of the criterion: `wrap_join` asks whether there
is a harsh transition near the edge, and a texture with authored detail near
its edge trips it whether or not it tiles.

### CORRECTION, same day — the theme set is NOT entirely fine

The paragraph that stood here said *"on this evidence Archipepsi's theme set
is fine."* **Struck.** It was written before I read `materials.py`, and
reading it found a real artifact that two rounds of measurement had walked
past.

`surface_for()` gives every `wall`, `accent` and `wall_ribbed` its panel
courses like this:

```python
pitch = int(round(size * 1.2 / metres))     # 1.2 m of a 4 m tile = 38 px
seams = tuple(range(0, size, pitch))        # -> (0, 38, 76, 114)
```

**`size` is not a multiple of `pitch`.** 128 / 38 is 3.37, so the courses run
0, 38, 76, 114 and then the tile wraps — putting the next course 14 px after
the last one instead of 38. Measured on the shipped PNGs:

| texture | gaps inside the tile | gap across the wrap |
|---|---|---|
| `concrete_facility_wall` | 38, 38, 38 | **14** |
| `temple_ruin_wall` | 19 × 6 | **14** |
| `gothic_stone_wall` | 13 × 9 | **4** |

So on a tall wall the panel rhythm is even for 3.6 m and then breaks, once
every 4 m, for as long as the wall goes on. **That is a visible artifact, it
is in every wall and accent texture in all six themes, and it has been there
since Batch 001** — because nothing had ever looked at a repeat.

It is also why `check_tiling` flags every wall: there is an authored hard
course at **row 0**, sitting exactly on the join, by construction.

**I have not fixed it.** The repair is one line — make the courses divide the
tile evenly, or start them at `pitch // 2` — and it regenerates every wall and
accent in all six themes. The owner's note says not to mass-regenerate or
silently replace reviewed assets, and a rhythm change across the whole theme
set is a look decision, not a defect fix. It is stated here with the line, the
numbers and the proposed repair, and it is the owner's call.

**What still stands:** the two boundaries I examined closely are authored, no
texture was changed, and `check_tiling` earns its place as a reporting step.
What changed is that it was right about something after all, and it took
reading the generator to see what.

The sheet is the reason anyone can say any of this. `docs/art/review/theme_tiling_2026-09-22/` holds it:
eighteen textures, each tiled 3×3 at native scale, labelled with the verdict,
so the numbers and the picture sit together. It is regenerated by
`tools/content/theme_tiling_sheet.py` and reads nothing but the shipped PNGs.

**Fourteen of the eighteen were never examined at all before today**, and now
they have been. That is the trial's real yield: not a repair, a look.

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

---

## 5 · Addendum: the candidate advanced to `87db9e2`, and what one real cycle showed

**Arty**, 2026-09-22, at the first safe checkpoint after Batch 055 was
committed and pushed.

The owner's addendum replaced the `ebe949b` pin with
`87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de` on
`claude/feature-planning-roadmap-5oibiu`, and asked for the updated
**external** interface to be verified — *"An in-process helper test alone
would miss the external-interface bugs this update repairs"* — not for the
whole trial to be rerun. It was not rerun.

### What moved, and what did not

* `/home/user/glyph-trial` fetched and checked out `87db9e2`. Clean.
* `/home/user/ecms-glyph` is still at **`6c80b63`**, clean. Batches 043 and
  052 record that SHA beside every asset; **the authoring build did not
  move and this addendum does not move it.**
* `npm ci` + `npm run build` clean. `glyph doctor`: every package compiled,
  chromium found, **23 extensions** served.

### One thing I broke by reading, and put back

`art-trial/*.glyph` are the repository's own committed fixtures, and they
are SQLite containers. Running `glyph verify` on five of them checkpointed
their WAL into the main file and deleted the tracked `-shm`/`-wal`
siblings on close — so **six tracked files were modified by an operation
that only read**. Restored with `git checkout -- art-trial/`; the checkout
is clean. Worth knowing before anyone opens a shared `.glyph` casually: in
this container format, opening is a write.

### The cycle, through the interface I will actually use

A fresh scratch project, because the addendum's `--collaborator` path is
the one-time authorized grant and a fresh project is where it applies. **I
did not recreate or overwrite an existing working project**, and the owner
and artist identities are distinct: `act_owner_arty` is Lead Owner,
`act_agent_arty` is the artist, and every drawing command below ran as the
artist.

| step | through | result |
|---|---|---|
| grant | `glyph run project.grant --actor act_owner_arty --collaborator act_agent_arty:agent` | `grn_1_act_agent_arty`, scopes `*`, operations edit/comment/review/session_start |
| edit | `glyph batch` — `txn.begin` with explicit `base_revision` and `scope`, then palette, asset, variant, fill and eight `pixels.draw` calls, all citing the one transaction | 14 steps, one process |
| commit | `txn.commit` | `rev_J81NDB7F533AC0CBHJWT1Z` |
| **look** | `glyph view --scale 8 --out probe.png`, **opened as an image** | `docs/art/review/glyph_addendum_2026-09-22/CYCLE_probe_8x.png` |
| reopen | `glyph describe`, `glyph log` | head and seq read back; the log attributes the revision to the **artist**, not the owner |
| export | `glyph project-revision --to <dir>` | `glyph.projection.json`, a palette, a variant and a cel PNG, with six omissions declared by name |

The rendered probe is four dark joints with light lips at rows 0, 8, 16
and 24 of a 32 px tile — a pitch that divides, chosen so the picture is
about today's Batch 055 question and not about nothing. The wrap gap is
the same 8 px as the others, and that is visible in the image rather than
asserted about it.

### The two repairs, verified on the real surface

Driven over **stdio JSON-RPC** against `glyph mcp`, not in process.

* **Ordinary mutations advertise the transaction argument.** 35 tools on
  the default surface; nine of them carry `transaction` and **every one
  lists it in `required`** — `asset_create`, `palette_create`,
  `variant_create`, `pixels_draw`, `pixels_apply_patch`, `candidate_submit`,
  `question_raise`, `txn_commit`, `txn_abort`. The old incomplete
  signatures are gone and nothing was worked around.
* **The five newly-defaulted tools are there:** `memory_query`,
  `candidate_submit`, `comment_list`, `question_raise`, `question_list`,
  all present by name.

### Doctrine, craft, and not approving my own work

* `craftbook_query {topic:"tiling"}` returns `cb_seams`, and it lands on
  today's work: *"A tile seam that matches at the abutting column and
  breaks one pixel in still reads as a seam. Check the depth the eye
  actually notices, not the depth that is easy to check."* The tool says
  of itself that craft **binds no actor and overrides no project
  doctrine**.
* `memory_query {scope:"project"}` is a different question and answers it
  separately, tier by tier, with the note that an empty tier means nothing
  was found there **rather than that it was not searched**.
* `candidate_submit` succeeded as the artist — `cnd_V1EFSZVSPGD4AAZGW2TPRD`,
  `outcome: null`, awaiting the owner.
* `memory.promote` on my own candidate, as the artist, with `scopes:["*"]`:
  **`PERMISSION_DENIED — "promote_doctrine" is reserved to the Lead Owner
  and is not available under any grant.`** A grant of everything is still
  not ownership. That is the property worth having.

### Interface friction found on the way, reported rather than worked around

Five refusals before the cycle ran, all mine to fix, and one of them is a
gap in the tool rather than in me:

1. `palette.create` with `{"name":..,"rgba":"3a4048ff"}` — the documented
   shape is `[{value:{r,g,b,a}, name?}]` and I had not read it. **But the
   response was an internal `TypeError: Cannot read properties of
   undefined (reading 'a')` wrapped as `PRECONDITION_FAILED`, with
   `"internal": true`.** `palette.create_entry` runs its colour through
   `parseRgba`, which says *"must be an {r, g, b, a} colour"*;
   `palette.create` casts `e.value as never` and does not. **A malformed
   entry should get the same sentence from both.** Reported here; not
   patched, because this is the tool's repository and not mine.
2. An `a: 0` entry in an indexed project is refused with a `how_to_allow`.
   Correct, and well said.
3. Coordinates are `[x, y]`, not `{x, y}`.
4. `connectivity` takes the **string** `"4"`. The sentence renders the
   enum unquoted — *must be one of 4, 8* — so an integer looks acceptable;
   only the machine payload's `"values": ["4","8"]` disambiguates.
5. `approval_scope_requested` is an array, not a scope object like
   `txn.begin`'s. Two adjacent fields named "scope" with different shapes
   is a thing to trip on twice.

Every one of these refused with the field named and the accepted values
listed, which is why five wrong inputs cost five minutes rather than an
afternoon.

### Verdict, unchanged

**Adopt `check_tiling` as a REPORTING step. Do not move the authoring
build.** `6c80b63` stays. Nothing here changes that, and nothing in the
Archipepsi repository depends on the trial checkout.

The candidate submitted above lives inside a transaction that was then
aborted, so it is **not** persisted: this was interface verification, not
production work. No Archipepsi asset was authored through Glyph.
