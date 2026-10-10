# The repair follow-up: every panel seated, the gauge face, the docs, and a safe verifier

*Arty — 2026-09-28*

**The handoff** is `docs/art/review/repairs_2026-09-28/README.md`, updated
in place with a dated "Follow-up" section. It is on the same separate
branch, `claude/archipepsi-art-repairs-2026-09-28`.

**What it is:** the four follow-ups the owner asked for. The owner
accepted the three repair families as technical progress. That does not
promote their candidate art or authorise Production binding, and nothing
here does either.

## Done

| # | Commit | In one line |
|---|---|---|
| 1 | `a0f1e76` | All 22 lightened panels are checked for seating and clearance, and twelve are re-seated. The verifier now fails the old placements on SEATED alone. |
| 2 | `9deb2c6` | The gauge's solid bezel is now a frame of the same size, so the face shows. The pin and travel are unchanged, and the build refuses a bezel the needle touches. |
| 3 | `e059dd7`, `72dad0c` | The paddle's poses are renamed `level` / `down`. The danger sheet's seam line is scoped to the charger and artillery, and three findings are labelled as code readings. |
| 4 | `3c2f3711` | `verify_content_pack.sh` works in a private copy; the caller's tree is never written or deleted. Tested on passing and failing runs. |

Evidence and the handoff update are in the commit after these. The
families stay separable. Family 1 (with `9deb2c6` and `e059dd7`) and
family 3 (with `a0f1e76`) each cherry-pick alone onto `a1584c8`, and each
then rebuilds byte-identical through its own builder.

## The numbers that matter

- **Panels:** `verify_053_panels.py` fails 22 / 9 / 17 (material /
  clearance / seating) on `a1584c8` and 0 / 0 / 12 on the first repair.
  It passes on this branch. Nothing about the objects changed:
  - bodies, fittings, sizes and attach points (21 verified);
  - masses, mass classes and carriable/manipulable permissions.
- **Gauge:** from the front, the face was 0 cm² visible; it is now
  363 cm². The needle is backed by the face at every degree from −90° to
  +90°. The model is 100 triangles, up from 64.
- **The verifier fix:** run in disposable worktrees of this branch and of
  Production's pin.
  - The old script deleted the planted scratch harness and the manifest,
    tracked or not.
  - The new one deleted, overwrote and added nothing, on a passing run
    (exit 0) and on a failing one (exit 3).

## Found, not changed

- **The plate's nose wedge slopes across the plate's width.** It is built
  with `wedge`'s default `axis="y"`, so it does not chamfer the leading
  edge its docstring promises. The smallest repair is `axis="x"`, turned
  so the low edge is the tip.
- **Colour convention.** Art-lane hex colours are written straight into
  the linear base colour, so the panel exports lighter than `#4a5058`
  would be in sRGB. This is the same for every flat colour here. The
  grey-blue you chose is what exports. A runtime that restores `at_rest`
  as sRGB would draw it darker.
- **Other runners.** 42 other art-lane runners still clear
  `godot/_harness` whoever owns it. My three repair runners now claim that
  folder or stop.
- **The theme-bind gate against the pin.** `tools/check_art_current.sh`
  passes at `3c2f3711` in its usual configuration, which reads
  Production's default local ref, `19c5d8e`. With `PROD_REF` at the pin,
  one gate, `run_theme_bind.sh`, cannot compile Production's newer
  `theme_pack.gd`: its constants are now autoload references. The gate
  is unchanged since `a1584c8`. The smallest repair is to inline those
  two constants.
- **Not reproduced.** Production reported untracked files lost under
  `godot/`. Three sentinels planted elsewhere under `godot/` survived the
  old script, so this could not be confirmed. The new script touches
  nothing in either case.

## Accepted, and what that does not cover

*Added 2026-09-28, after the owner's review.* The technical repair pass
is accepted as complete at this review scope. The repaired versions and
their separate commits stay, and no further panel or gauge redesign is
requested. The owner accepted the technical corrections, not the
candidate families for normal gameplay. The visual choices and
runtime-binding decisions are still pending.

The two art-check results stay distinct:
- the usual configuration passes;
- the pinned-Production run has the theme-bind harness failure.

Neither is a current-Production compatibility pass. The four items
under "Found, not changed" are now named follow-ups FU-1 to FU-4 in the
handoff: the theme-bind harness, the unsafe runners, the plate's wedge
and the colour convention. They are recorded, not started.

## Stopping point

Nothing is promoted, bound or integrated. No Production branch, worktree,
session or file was touched; Production was read only at its pins. There
are no watchers or check-ins.

**I have stopped for your remaining visual decisions.**
