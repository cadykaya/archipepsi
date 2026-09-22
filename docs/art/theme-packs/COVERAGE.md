# Theme-pack coverage — every included Archipelago game

**Arty**

## Two counts, and they are not the same count

The owner asked for these to be reported separately, and they must be,
because one of them is an inventory of a web page and the other is an
inventory of finished art. Conflating them is how "81 rows exist" turns
into "81 packs exist".

| | |
|---|---|
| **CATALOGUE coverage** | **81 of 81.** Every included Archipelago game has a row, a queue id and a reserved pack id. This is a list, and a list is not art. |
| **COMPLETED pack coverage** | **0 of 81.** Nothing has passed the bar in *What counts as a completed pack* below. |
| **IN PROGRESS** | **4** — T01 `tp_ocarina_of_time`, T02 `tp_super_mario_64`, T03 `tp_bomb_rush_cyberfunk`, T04 `tp_super_metroid`: content built and applied in engine, material treatment still missing on all four. |
| **NOT STARTED** | **77.** |

**Catalogue snapshot:** `catalogue.json`, taken 2026-09-22 from
`https://archipelago.gg/games` ("Currently Supported Games").
**Count: 81 included games.** The first wave is the packet's eighteen;
**63 remain.**

**Community-only APWorlds are not in this and are not counted.** The
page itself sends custom worlds to the setup guide's "playing with
custom worlds" section, and this catalogue is the included set only.
Widening that definition would be a different claim and it is not made
here.

---

## The two things a reader should know before the table

### 1. Four rows have assets. Nothing has passed the completion bar.

Archipepsi's six theme families — `concrete_facility`,
`rusted_industrial`, `neon_transit`, `gothic_stone`, `temple_ruin`,
`void_glitch` — are **the house's own**, not game packs.

**T01 `tp_ocarina_of_time` has six assets** (Batch 054) and an in-engine
application (`docs/art/review/forest_temple_2026-09-22/`).
**T02 `tp_super_mario_64` has six** (Batch 056) and its own
(`docs/art/review/clockwork_2026-09-22/`). Neither is **complete**, and
the thing missing from both is the biggest one: their material
treatment, which §3 below explains there is nowhere to file. A pack
painted in a house family is a pack wearing another pack's clothes.

**T03 `tp_bomb_rush_cyberfunk` has six** (Batch 057) and its own
(`docs/art/review/brink_2026-09-22/`). Same shell, same four cameras as
T01 and T02, so the three compare frame for frame.

**THE HINT IS USUALLY RIGHT, AND THAT IS THE PROBLEM.** T01's hint,
material and subject agreed. T03's agreed. **T02's did not** —
`THEME_BY_GAME_HINT` maps Super Mario 64 to `concrete_facility` and a
clock movement's nearest family BY MATERIAL is `rusted_industrial`. The
hint picks a family by GAME; a treatment follows what a pack is MADE OF.
Two questions, one field. A hint that is always wrong gets noticed; one
that is right two times in three does not. Recorded per pack as
`theme_hint_says` / `theme_hint_agrees` in each manifest, so agreement
is data rather than silence.

**AND T04 IS THE FIRST PACK WITH NO HINT AT ALL.**
`THEME_BY_GAME_HINT` holds **six** entries. This table holds **81
games**. So **75 of 81 have no hint** — Super Metroid among them. A
selection mechanism covering 7% of the catalogue is not a mechanism
with an exception in it; **it is a mechanism for six games.** That is
§2 and §3 arriving together, and it is a number rather than an
opinion.

**Every other row is `not started` and says so.**

### 2. There IS a per-game hook, and what it selects is a TINT

`Constants.THEME_BY_GAME_HINT` maps five titles plus Archipepsi onto
those six house themes:

```
"Super Mario 64"      -> concrete_facility
"Ocarina of Time"     -> temple_ruin
"Bomb Rush Cyberfunk" -> neon_transit
"Dark Souls III"      -> gothic_stone
"Borderlands 2"       -> rusted_industrial
"Archipepsi"          -> void_glitch
```

So a per-game selection hook exists — and today the most it can express
is *"this game gets one of our six looks"*. **That is a different tint,
which is explicitly not a completed pack.**

And `ThemePack` loads **one** descriptor from a fixed path,
`res://content/theme/THEME_PACK.json`. A library of 81 packs needs a
keyed lookup; a single descriptor cannot hold them.

**Both of those are integration dependencies for Prod and Dess, not
permission for Art to build a second loader.** The smallest seam, for
them to accept, amend or refuse:

> `ThemePack.descriptor()` takes an optional pack id and resolves
> `res://content/theme/<pack>/THEME_PACK.json`, falling back to today's
> path when unset. `THEME_BY_GAME_HINT` grows a second field — or a
> sibling map — that names a pack id rather than a house theme, and
> keeps naming a house theme as the fallback for any game with no pack.

Art continues authoring packs as content while that is pending. A pack
with no selection hook is an integration task, not a reason to stop
producing.

---

### 3. And there is nowhere to PUT a pack's pixels

Found 2026-09-22, while scoping the first pack. It is sharper than the
hook problem above and it is a different problem.

`assets/textures/theme/THEME_PACK.json` — the descriptor the whole set is
built and verified against — has this shape:

```json
"themes":   ["concrete_facility", "gothic_stone", "neon_transit",
             "rusted_industrial", "temple_ruin", "void_glitch"],
"textures": { "concrete_facility/accent": …, "concrete_facility/ceiling": … }
```

A flat list of themes, and textures keyed `"<theme>/<role>"`. **There is no
pack namespace.** A game pack's textures can enter that structure in exactly
one way: by becoming a seventh entry in `themes` — at which point it is
indistinguishable from a house family, because the only thing that could tell
them apart is `Constants.THEME_BY_GAME_HINT`, which is Production's and which
maps six titles onto the six house looks.

Eleven shells hard-code a house theme name, and **39 files in this repository
name `temple_ruin`** — navigation, lights, landmarks, dressing, secrets, the
content export and four verifiers among them. So a seventh name is not a small
addition; and **eighty-one packs cannot be seventy-five more entries in a flat
list that the rest of the codebase treats as the house set.**

**What this means for the queue.** Art can author a pack's *content* — meshes,
motifs, dressing, control housings — into the existing batch pipeline today,
and that work is not blocked. What cannot happen yet is a pack's **material
set**, because there is no key it can be filed under that does not claim to be
a seventh house family.

**What Prod/Dess would need to decide**, and it is one decision, not three:
does a game pack become a theme (the `themes` list grows, and something other
than `THEME_BY_GAME_HINT` distinguishes pack from house), or a separate
artefact (`THEME_PACK.json` grows a `packs` namespace beside `themes`, and
`ThemePack` learns to resolve one)? **Art has not picked**, because picking it
by writing files is how a second loader gets built by the back door, and the
owner's note forbids that in as many words.

## What counts as a completed pack

Recorded here because the owner's wording is the specification and it is
easy to drift from:

* an **intentional, recognizable visual identity** — shared
  architectural families, base meshes, materials and machinery are
  **encouraged**, and reuse is not a defect;
* a useful visual variant is **not** a duplicate merely because its
  construction is shared;
* but **a generic fallback, a different tint, or a new folder name does
  not count**;
* each pack needs **distinctive material treatment, shapes/motifs,
  useful dressing and an in-engine application**;
* for a game with many environments, **one coherent initial subtheme,
  chosen and STATED** — not everything blended into an average;
* **original game-inspired assets in Archipepsi's established style**;
* universal gameplay cues, collision and clearance contracts preserved,
  and the visual/gameplay distinction kept;
* related games may share a family, but each keeps **its own row here
  and an explanation of what makes its treatment distinct**.

---

## Completed pack coverage

The criteria above, one column each, for every pack with any work on it.
A pack absent from this table has nothing built. **A row here is not a
completion: the verdict column is.**

| Pack | Subtheme stated | Shapes / motifs | Dressing | Material treatment | In-engine application | Contracts preserved | Owner review | **Verdict** |
|---|---|---|---|---|---|---|---|---|
| `tp_ocarina_of_time` | yes — Forest Temple, chosen over an average of Ocarina's environments | yes — 6 assets, Batch 054 | yes — floor root mass, timber-hooded torch alcove | **NO** — painted in `temple_ruin`; §3, no pack namespace to file its own set in | yes — 4 frames, `forest_temple_2026-09-22/`, opening re-checked on the IMPORTED geometry | yes — 2.4 × 3.2 opening clear, no collider, no light, no foothold added | not started | **IN PROGRESS** |
| `tp_super_mario_64` | yes — Tick Tock Clock, the clockwork half of the packet's "Clockwork Garden"; the courtyard is the stated second subtheme and is not built | yes — 6 assets, Batch 056 | yes — fallen clock hand, pendulum fitting | **NO** — painted in `rusted_industrial`, the nearest family by MATERIAL, which is not the family the hint names either; §2 and §3 | yes — 4 frames, `clockwork_2026-09-22/`, same shell and same four camera positions as T01 | yes — same three Blender gates via `packgates`, plus the imported-geometry check | not started | **IN PROGRESS** |

| `tp_bomb_rush_cyberfunk` | yes — Brink Terminal after hours: the architecture half of the game, not its terrain | yes — 6 assets, Batch 057 | yes — torn grind rail, strip light with one tube out | **NO** — painted in `neon_transit`, which IS the family the hint names and is still a house family, not this pack's own; §3 | yes — 4 frames, `brink_2026-09-22/`, same shell and cameras as T01 and T02 | yes — `packgates` plus the imported-geometry check, which this pack's shutter guide made stricter in two ways | not started | **IN PROGRESS** |

| `tp_super_metroid` | yes — the Wrecked Ship, the one region of six that is architecture rather than cave | yes — 6 assets, Batch 058 | yes — debris fan, caged lamp hanging off true | **NO** — painted in `rusted_industrial`; this game has NO hint to agree or disagree with, and 74 others are in the same position | yes — 4 frames, `wreck_2026-09-22/`, same shell and cameras as T01–T03 | yes — `packgates` plus the imported-geometry check; the pressure door's coaming was REFUSED and is Production's to place | not started | **IN PROGRESS** |

**0 of 81 complete. 4 in progress. 77 not started.**

---

## Coverage

This is the CATALOGUE ledger: one row per included game, so that the
list cannot silently lose a row. It is not a progress report. The
completion ledger is the table above.

`reused family` and `distinctive assets` stay empty until a pack is
authored — filling them in advance would be planning dressed as
progress.

| Queue | Source reference | Pack ID | Packet concept | Reused family | Distinctive assets | Exported/imported | Runtime-selected | Owner review |
|---|---|---|---|---|---|---|---|---|
| T01 | Ocarina of Time | `tp_ocarina_of_time` | Grove Relay Temple — **Forest Temple** subtheme, stated | `temple_ruin` construction | 6: column with a climbing root, split wall relief, timber-hooded torch alcove, timber switch housing, floor root mass, bossed door surround | **content yes** (batch054), **materials no** (§3) | no | not started — in engine, see the completion ledger |
| T02 | Super Mario 64 | `tp_super_mario_64` | Clockwork Garden — **Tick Tock Clock** subtheme, stated | `rusted_industrial` construction | 6: gear column with an upright wheel and pinion, parted wall movement, dial door bezel, bent fallen clock hand, pendulum fitting, winding-key escutcheon | **content yes** (batch056), **materials no** (§3) | no | not started — in engine, see the completion ledger |
| T03 | Bomb Rush Cyberfunk | `tp_bomb_rush_cyberfunk` | Afterhours Municipal Transit — **Brink Terminal, after hours** subtheme, stated | `neon_transit` construction | 6: tagged concourse pillar, departure board mid-flip, shuttered gate head, torn grind rail, batten with one tube out, ticket-validator plate | **content yes** (batch057), **materials no** (§3) | no | not started — in engine, see the completion ledger |
| T04 | Super Metroid | `tp_super_metroid` | Pressureworks Derelict — **the Wrecked Ship** subtheme, stated | `rusted_industrial` construction | 6: burst frame stanchion, hull panel with hatch on one hinge, pressure-door frame with dogging lugs, blown debris fan, caged lamp off true, dogging lever | **content yes** (batch058), **materials no** (§3) | no | not started — in engine, see the completion ledger |
| T05 | Kingdom Hearts 2 | `tp_kingdom_hearts_2` | Twilight Service District | — | — | no | no | not started |
| T06 | DOOM 1993 | `tp_doom_1993` | Foundry Containment | — | — | no | no | not started |
| T07 | Dark Souls III | `tp_dark_souls_iii` | Cinder Aqueduct | — | — | no | no | not started |
| T08 | The Wind Waker | `tp_the_wind_waker` | Harbour Windworks | — | — | no | no | not started |
| T09 | Hollow Knight | `tp_hollow_knight` | Lamplight Conservatory | — | — | no | no | not started |
| T10 | Terraria | `tp_terraria` | Layered Mineworks | — | — | no | no | not started |
| T11 | TUNIC | `tp_tunic` | Moss Archive | — | — | no | no | not started |
| T12 | Sonic Adventure 2 Battle | `tp_sonic_adventure_2_battle` | Gravity Transit | — | — | no | no | not started |
| T13 | A Link to the Past | `tp_a_link_to_the_past` | Mosaic Waterworks | — | — | no | no | not started |
| T14 | Factorio | `tp_factorio` | Assembly Annex | — | — | no | no | not started |
| T15 | Subnautica | `tp_subnautica` | Pressure-Garden Station | — | — | no | no | not started |
| T16 | Blasphemous | `tp_blasphemous` | Processional Foundry | — | — | no | no | not started |
| T17 | A Hat in Time | `tp_a_hat_in_time` | Clockwork Station Quarter | — | — | no | no | not started |
| T18 | Risk of Rain 2 | `tp_risk_of_rain_2` | Basalt Relay Outpost | — | — | no | no | not started |
| T19 | Adventure | `tp_adventure` | — | — | — | no | no | not started |
| T20 | APQuest | `tp_apquest` | — | — | — | no | no | not started |
| T21 | Aquaria | `tp_aquaria` | — | — | — | no | no | not started |
| T22 | Bumper Stickers | `tp_bumper_stickers` | — | — | — | no | no | not started |
| T23 | Castlevania - Circle of the Moon | `tp_castlevania_circle_of_the_moon` | — | — | — | no | no | not started |
| T24 | Castlevania 64 | `tp_castlevania_64` | — | — | — | no | no | not started |
| T25 | Celeste (Open World) | `tp_celeste_open_world` | — | — | — | no | no | not started |
| T26 | Celeste 64 | `tp_celeste_64` | — | — | — | no | no | not started |
| T27 | ChecksFinder | `tp_checksfinder` | — | — | — | no | no | not started |
| T28 | Choo-Choo Charles | `tp_choo_choo_charles` | — | — | — | no | no | not started |
| T29 | Civilization VI | `tp_civilization_vi` | — | — | — | no | no | not started |
| T30 | DLCQuest | `tp_dlcquest` | — | — | — | no | no | not started |
| T31 | Donkey Kong Country 3 | `tp_donkey_kong_country_3` | — | — | — | no | no | not started |
| T32 | DOOM II | `tp_doom_ii` | — | — | — | no | no | not started |
| T33 | EarthBound | `tp_earthbound` | — | — | — | no | no | not started |
| T34 | Faxanadu | `tp_faxanadu` | — | — | — | no | no | not started |
| T35 | Final Fantasy | `tp_final_fantasy` | — | — | — | no | no | not started |
| T36 | Final Fantasy Mystic Quest | `tp_final_fantasy_mystic_quest` | — | — | — | no | no | not started |
| T37 | Heretic | `tp_heretic` | — | — | — | no | no | not started |
| T38 | Hylics 2 | `tp_hylics_2` | — | — | — | no | no | not started |
| T39 | Inscryption | `tp_inscryption` | — | — | — | no | no | not started |
| T40 | Jak and Daxter: The Precursor Legacy | `tp_jak_and_daxter_the_precursor_legacy` | — | — | — | no | no | not started |
| T41 | Kingdom Hearts | `tp_kingdom_hearts` | — | — | — | no | no | not started |
| T42 | Kirby's Dream Land 3 | `tp_kirby_s_dream_land_3` | — | — | — | no | no | not started |
| T43 | Landstalker - The Treasures of King Nole | `tp_landstalker_the_treasures_of_king_nole` | — | — | — | no | no | not started |
| T44 | The Legend of Zelda | `tp_the_legend_of_zelda` | — | — | — | no | no | not started |
| T45 | Lingo | `tp_lingo` | — | — | — | no | no | not started |
| T46 | Links Awakening DX | `tp_links_awakening_dx` | — | — | — | no | no | not started |
| T47 | Lufia II Ancient Cave | `tp_lufia_ii_ancient_cave` | — | — | — | no | no | not started |
| T48 | Mario & Luigi Superstar Saga | `tp_mario_luigi_superstar_saga` | — | — | — | no | no | not started |
| T49 | Mega Man 2 | `tp_mega_man_2` | — | — | — | no | no | not started |
| T50 | Mega Man 3 | `tp_mega_man_3` | — | — | — | no | no | not started |
| T51 | MegaMan Battle Network 3 | `tp_megaman_battle_network_3` | — | — | — | no | no | not started |
| T52 | Meritous | `tp_meritous` | — | — | — | no | no | not started |
| T53 | The Messenger | `tp_the_messenger` | — | — | — | no | no | not started |
| T54 | Muse Dash | `tp_muse_dash` | — | — | — | no | no | not started |
| T55 | Noita | `tp_noita` | — | — | — | no | no | not started |
| T56 | Old School Runescape | `tp_old_school_runescape` | — | — | — | no | no | not started |
| T57 | Overcooked! 2 | `tp_overcooked_2` | — | — | — | no | no | not started |
| T58 | Paint | `tp_paint` | — | — | — | no | no | not started |
| T59 | Pokemon Emerald | `tp_pokemon_emerald` | — | — | — | no | no | not started |
| T60 | Pokemon Red and Blue | `tp_pokemon_red_and_blue` | — | — | — | no | no | not started |
| T61 | Raft | `tp_raft` | — | — | — | no | no | not started |
| T62 | Satisfactory | `tp_satisfactory` | — | — | — | no | no | not started |
| T63 | Saving Princess | `tp_saving_princess` | — | — | — | no | no | not started |
| T64 | Secret of Evermore | `tp_secret_of_evermore` | — | — | — | no | no | not started |
| T65 | shapez | `tp_shapez` | — | — | — | no | no | not started |
| T66 | Shivers | `tp_shivers` | — | — | — | no | no | not started |
| T67 | A Short Hike | `tp_a_short_hike` | — | — | — | no | no | not started |
| T68 | SMZ3 | `tp_smz3` | — | — | — | no | no | not started |
| T69 | Starcraft 2 | `tp_starcraft_2` | — | — | — | no | no | not started |
| T70 | Stardew Valley | `tp_stardew_valley` | — | — | — | no | no | not started |
| T71 | Super Mario Land 2 | `tp_super_mario_land_2` | — | — | — | no | no | not started |
| T72 | Super Mario World | `tp_super_mario_world` | — | — | — | no | no | not started |
| T73 | Timespinner | `tp_timespinner` | — | — | — | no | no | not started |
| T74 | Undertale | `tp_undertale` | — | — | — | no | no | not started |
| T75 | VVVVVV | `tp_vvvvvv` | — | — | — | no | no | not started |
| T76 | Wargroove | `tp_wargroove` | — | — | — | no | no | not started |
| T77 | The Witness | `tp_the_witness` | — | — | — | no | no | not started |
| T78 | Yacht Dice | `tp_yacht_dice` | — | — | — | no | no | not started |
| T79 | Yoshi's Island | `tp_yoshi_s_island` | — | — | — | no | no | not started |
| T80 | Yu-Gi-Oh! 2006 | `tp_yu_gi_oh_2006` | — | — | — | no | no | not started |
| T81 | Zillion | `tp_zillion` | — | — | — | no | no | not started |

---

## Order

The owner's priority is unchanged and this table does not reorder it:
**finish useful setpiece / character / machinery deliveries first, then
continue coherent theme packs.** Packs are finished one at a time as
coherent deliveries; starting all of them is the failure mode this
table exists to make visible rather than to encourage.

`tools/content/check_pack_coverage.py` keeps this table and
`catalogue.json` in agreement, so the count cannot drift silently and a
row cannot be quietly dropped.
