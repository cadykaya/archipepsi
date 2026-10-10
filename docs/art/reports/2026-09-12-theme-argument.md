# The theme is a build argument now

**Arty**

*2026-09-12. Theme-pack gap 4, from
`docs/art/reports/2026-09-10-theme-pack-preparation.md` §6: "the theme is a
build-time constant per builder." It is not any more.*

---

## What changed

Forty-five builders each held `THEME = "concrete_facility"` as a module
constant, so a second theme of an existing room meant editing forty-five
files, or waiting for a runtime binder nobody has written yet.

```
blender -b --python tools/blender/build_rooms.py -- --theme temple_ruin
ART_THEME=temple_ruin blender -b --python tools/blender/build_rooms.py
```

Thirty-six builders now read `common.THEME`. Two were deliberately left with
their own semantics, and the file says why in both:

- **`build_plenum`** is rusted industrial by *authorial choice*, not by
  inheriting the default. `common.theme_for("rusted_industrial")` keeps that
  on an ordinary build — the shipped shell's byte-identity depends on it —
  while a `--theme` run still reaches it.
- **`build_navigation`** writes every module once per theme in a single run,
  so "which theme is this build" is not a question it has. Narrowing it to
  one would break the completeness that is its whole point.

## The feature is the easy half

The half worth checking is the blast radius. **One `--theme` typo could
otherwise replace twelve approved shells with differently-painted ones**,
`git diff` would show binary churn across the whole pack, and the only thing
standing between the repository and that would be somebody remembering.

So a non-default theme redirects its output under `assets/themed/<theme>/`,
`export_glb` and the texture writer both refuse an absolute path into the
shipped tree, and `assets/themed/` is gitignored. **Scratch by construction:
nothing exports from there, nothing is reviewed there, and no manifest names
it.**

An unknown name refuses rather than building. `--theme temple_ruins` would
otherwise paint every surface from a silently empty table and export an asset
nobody could tell from a real one by looking at it:

```
theme 'temple_ruins' is not one the palette knows. It has:
concrete_facility, gothic_stone, neon_transit, rusted_industrial,
temple_ruin, void_glitch
```

`palette.theme_names()` is the authority, so the list cannot drift from the
palette that defines it.

## Evidence

**The default is unchanged.** `tools/check_art_current.sh` rebuilds all 52
builders and compares against git: **PASS, every generated asset matches its
source.** That is the condition of the change, not a hope.

**A second theme is genuinely a different asset from the same source.**
`build_rooms.py -- --theme temple_ruin`, with the shipped pack untouched
throughout (`git status -- assets/models assets/textures` empty):

| from one source | shipped, bytes | temple_ruin, bytes |
| --- | ---: | ---: |
| `shell_treasure_cache.glb` | 98,632 | 95,440 |
| `shell_treasure_coffer.glb` | 93,496 | 90,308 |
| `shell_corner_right.glb` | 61,584 | 58,412 |

This is a different proof from Batch 041's, and deliberately so. That one
showed one *shipped* mesh wearing two themes by per-instance surface
override — the runtime path. This shows the *build* path: the same source,
run twice, producing two assets.

## What is checked

`tools/content/verify_theme_argument.py`, in
`tools/check_art_current.sh` with every other standing check. Three
questions, each run in its own Blender subprocess because `common.py`
imports `bpy`:

| | |
| --- | --- |
| no argument | resolves to `assets/models` and `assets/textures`, exactly, and `theme_for` keeps a builder's house theme |
| `--theme` / `ART_THEME` | resolves only under `assets/themed/<theme>/`, and reaches a house-themed builder |
| an unknown theme | refuses, **and says why** — a failure with no message is a typo nobody finds |

Both sabotage tests were confirmed failing before it was trusted: removing
the redirect is caught by both spellings of the argument, and removing the
refusal is caught by name. `check_art_current.sh` also refuses to run at all
with a non-default `ART_THEME` set, because the byte-identity it compares
only means something against the default.

## What this does not do

**No binder, no runtime retheme, no ThemePack schema.** Gap 5 is still
Production's, and gap 3 — where the six-theme texture set actually lands — is
still open. This unblocks exactly what the preparation report said it would:
a second theme of an existing room, without a binder at all.

**No asset changed**, and no second theme is committed.

## Queue after this

| # | gap | owner |
| --- | --- | --- |
| 1 | no authored shell reachable in a generated Zone | Production |
| ~~2~~ | ~~role convention undeclared~~ | **done 2026-09-11** |
| **3** | **the six-theme texture set ships nowhere** | **Art** to ship, Production to decide where it lands |
| ~~4~~ | ~~theme is a build-time constant~~ | **done here** |
| 5 | no runtime retheme path | Production |

**Gap 3 is the next Art-owned item**, and it is the one that needs a
Production decision before the shipping half can start: a binder cannot bind
textures the game does not have, and where they land is not Art's call.
