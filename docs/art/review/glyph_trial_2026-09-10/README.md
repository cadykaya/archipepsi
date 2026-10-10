# Glyph trial — one concrete_facility wall

**Arty** · art lane · `claude/archipepsi-art` · 2026-09-10

The first Archipepsi texture authored through **ECMS Glyph** rather than
through `tools/blender/materials.py`.

**A TRIAL. Nothing here ships.** No approved asset was touched, no manifest
or schema field added, no runtime or review state changed, and this texture
is not a promotion and not a replacement for
`assets/textures/theme/concrete_facility_wall.png`, which is unchanged.

| | |
| --- | --- |
| Glyph revision | `727129e14ade02eee6ee8b21843d4cad6e03ed9b` — the implementation merge, `main` |
| authority frozen at | `0cf872d86d46884785655862788c5f980ae22769` |
| Node | v22.22.2 (`>=22.5.0` required) |
| Lead Owner, who authorises | **Skyiah** — `act_owner_skyiah` |
| agent artist, who draws | **Arty** — `act_agent_arty` |
| project revisions | 6 — one per authoring pass, plus creation |
| whole run | **936 ms** — open, create, four passes, three renders |
| determinism | re-run in a clean directory is **byte-identical** |

`MAKING_ART_WITH_GLYPH.md` is explicit that the owner and the artist are two
identities and that collapsing them has already gone wrong once in Glyph's
own history. Every command here dispatches as the artist and carries
`on_behalf_of` the owner. `glyph log` shows it: revision 1 is the owner's
project creation, revisions 2–6 are all `act_agent_arty`.

## The files

| file | what |
| --- | --- |
| `author_wall_concrete.mjs` | **the authoring script.** Reproducible: `GLYPH_ROOT=… node author_wall_concrete.mjs .` |
| `archipepsi_concrete.glyph` | **the editable project**, with its six-revision history. Reopens without the script |
| `authoring_record.json` | the three-claim look record, the structure, and the timing |
| `concrete_facility_wall.png` | **native, 128 × 128** |
| `concrete_facility_wall_8x.png` | 8× integer enlargement — the one to judge it with |
| `concrete_facility_wall_8x_coords.png` | 8× with native-coordinate grid — for targeting, not for judging |
| `TILED_3x3.png` | 3 × 3 at 2×, tile boundaries marked |
| `GLYPH_vs_SHIPPED.png` | beside the shipped painter's wall, both at 4× |
| `GODOT_wall_glyph.png` / `_shipped.png` | on real room geometry, 960 × 720 |
| `GODOT_comparison.png` | those two side by side |
| `passes/` | the two passes that were wrong, kept |
| `make_sheets.py` | rebuilds the two flat sheets |

The Godot binder is `tools/content/glyph_wall_preview.gd`.

**Everything here survives the Glyph installation being deleted** — the
project, the script, the PNGs and the renders are all in the review area,
and only re-authoring needs Glyph back.

## Where the numbers came from

Not from taste. `assets/art_palette.json` gives `concrete_facility`'s solved
ramps; `tools/blender/materials.py` gives the structure.

| | |
| --- | --- |
| tile | 128 px at 32 texels/m = **4.00 m** of wall |
| panel courses | every **1.2 m** = 38 texels → seams at rows 0, 38, 76, 114 |
| vertical joints | every **2.0 m** = 64 texels |
| bolts | **0.5 m** = 16 texels, ON the seams — a bolt off a seam is a speck |
| base course | bottom **0.85 m** = 27 texels, top edge at row 101 |
| weep | 0.7 m from the bolt line, on about one bolt in five |

The eleven palette entries are the shipped ramps with the painter's own
mixes pre-resolved: the field is the mid base step tinted 10% toward the
accent, because the owner's facility language is "cold gray concrete, white
/ pale blue" and neutral grey is not it.

**No hazard markings.** This is an ordinary corridor wall. Danger markings
stay reserved for danger.

## The two passes that were wrong

Kept in `passes/`, because a trial that only shows the good render has not
reported anything.

**Pass 1 — vertical striping.** Every broad patch came out a column and the
wall read as streaked. The cause was mine, not Glyph's: my seeded
tie-breaker was FNV-1a read out as `h / 2**32`, and since `y` is hashed
last and one `imul` does not carry the low bits up into the high bits that
division reads, the hash was very nearly **constant in y** — measured, 83.2%
of vertical neighbours agreed within 0.02 against 3.3% of horizontal ones.
A murmur3 `fmix32` avalanche after the loop fixed it: 4.5% / 3.6%, both at
the uncorrelated baseline.

**Pass 2 — grit too dark, and everywhere.** Scattered over half the tile at
a flat density, and inside the base course it was `course_under` — a **0.255
value jump per pixel**, larger than the whole `min_interactable_separation`
of 0.18. That is not pitting, it is holes. Grit is now one small step off
its own ground (0.033 in the course), the seam zone is the 0.25 m a seam
actually disturbs, and the density falls off across it instead of stopping
dead.

## What I can see — recorded, unverified

Glyph is careful that `render_created` is checked, `pixels_read` proves only
that bytes were accessed, and a **`visual_assessment` is an attributed
opinion that is never verified**. So this is signed rather than proved, and
I cannot approve it — that is the owner's and is a different act.

**It reads as an Archipepsi corridor wall.** On geometry the panel rhythm is
right, the base course grounds the pale field at the height the eye meets
the floor, and the bolts read as bolts. The tile boundary does not show as a
seam in the 3 × 3.

**It is cleaner than the shipped wall, and that is the interesting part.**
Beside `materials.py`'s own output the difference is consistent: the shipped
wall is grittier, its joints are dithered and its base course reads scuffed;
mine has crisper joints, clearer bolts and a smoother band. Neither is a
rebuild of the other and this is not a defect list — but if the house look
is meant to read *used*, this texture is a step toward *new*, and that is a
judgment for the owner.

The cause is concrete and is in the tooling section of the report: the
shipped painter builds its look from many **low-strength continuous mixes**,
and Glyph's indexed mode has no partial mix — every one of those has to be
pre-resolved into a named palette entry, and eleven entries cannot carry
what a continuous painter spends thousands of colours on.
