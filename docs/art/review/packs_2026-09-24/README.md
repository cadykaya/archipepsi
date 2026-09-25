# T01 and T05 — the first `pack_textures` pair

*Arty*

**PROPOSAL. CANDIDATE PACKS — authored, not selected, not
owner-approved.**

Three renders of **the same shell** (`shell_junction_cross`), through
Production's own `ThemeMaterials`, with only the pack changed:

| Sheet | What is binding |
| --- | --- |
| `PACK_family_backstop.png` | `temple_ruin` alone — what a Zone gets today. |
| `PACK_forest_temple.png` | T01, Ocarina of Time. |
| `PACK_twilight_town.png` | T05, Kingdom Hearts 2. |

Four surfaces are re-skinned in each: `floor`, `wall`, `accent`,
`trim`. The ceiling in every frame is the shell's own baked material —
there is no `ceiling_mat` — so it is not evidence about any pack, and
the caption on each sheet says so.

## Why these two packs exist at all

T01 and T05 were both built on `temple_ruin` deliberately, to find out
whether geometry alone carries a pack's identity. It does not:

> The geometry says "boarded-up shopfront". The pixels say "overgrown
> temple". The pixels win.

These rows are the answer to that. Each pack ships `wall`, `floor` and
`accent` of its own and yields every other role to the family — a
partial pack is legal, and repainting a ceiling both places share buys
nothing.

Both keep `temple_ruin`'s ramps. They are the right colours for both,
and a palette per pack would put the game's colour discipline in the
hands of whichever pack was authored last. What separates them is
**history**: `forest_temple` is losing — moss climbing from the floor,
roots through the roof, water out of every joint, and a step darker
because it is the inside of the ruin. `twilight_town` is maintained —
flat plaster, square timber framing with a brace, a swept brick plinth,
setts laid by somebody paid by the square metre.

## What these renders are NOT

They are a review screen, and they exist because a candidate **cannot**
bind. With the real registry, `ThemePack.pack_binds("forest_temple")`
is false and the family answers; `tools/content/run_pack_resolution.sh`
asserts that, and asserts the review override does not outlive the
review. These sheets are rendered under that override on purpose.

Nothing here puts a pack on the ladder. `candidate` means "rows exist
in the art lane's exported descriptor", which is the whole of what this
lane may grant. `THEME_PACK_STATUS` is Production's and stays empty.

## Three things worth your eye

1. **T05's accent is too close to the family's.** Its painted sign
   board takes the same `accent` green, so on a small accent surface
   the two read alike. Fixable — the board could take `trim` with the
   green reserved for lettering — but it is a change to an approved
   pair, so I am asking rather than doing.
2. **T01 is a nearer relative of the family than T05 is**, and always
   will be: the family was authored as "temple ruin" and T01 is a
   temple. The first cut was a brighter cousin and earned its row
   nothing. The darker interior is what makes it worth having, and it
   is worth deciding whether that is enough.
3. **T05's setts are busy at room scale.** A 0.26 m sett over a whole
   floor is a lot of line. A larger flag with the sett kept for edges
   would calm it, if you want it calmer.
