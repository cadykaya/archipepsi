# E · Source-game packs T01–T07

*Arty — 2026-09-28*

There are seven candidate packs, one per game.
- **Props:** six for each of the seven packs, all proposals.
- **Textures of their own:** T01 and T05 only.

Nothing here changes a status, continues to T08+, or changes which pack
goes with which game.

## Look at

1. [`sheets/E1_T01_T05_textures_same_room.jpg`](sheets/E1_T01_T05_textures_same_room.jpg):
   T01 and T05 against the house family, in the same room, from the same
   camera, under the same light.
2. [`sheets/E2_seven_prop_packs_one_light.jpg`](sheets/E2_seven_prop_packs_one_light.jpg):
   **re-rendered tonight.** The house room alone, then each pack's props,
   with one shell, one camera and one fixed light. The 22 September frames
   each had their own light, so they could not be compared. The eight
   frames are also loose in `evidence/E/`.
3. [`sheets/E3_pack_signature_frames.jpg`](sheets/E3_pack_signature_frames.jpg):
   each pack's one idea close up, reused as it was rendered. Its lights
   differ on purpose.

## Decide

1. **Is each identity right?** The pack's stated subtheme, judged by its
   silhouettes (E2).
   - *Recommend:* rule the principle once ("one stated architectural
     subtheme per game"), then give each pack a yes or no.
   - A yes records "identity accepted"; the status stays **candidate**.
2. **What counts as evidence for T02, T03, T04, T06 and T07.** Their props
   are painted in the house family, so only their **shape** differs.
   - *Recommend:* accept silhouettes now.
   - Hold "differs from the house family" until a pack has pixels of its
     own. That would be new work, and only if you ask for it.
3. **T01 and T05's textures (E1):**
   - (a) Which id does a Zone name? Either `forest_temple` /
     `twilight_town` (the texture rows), or `tp_ocarina_of_time` /
     `tp_kingdom_hearts_2` (the catalogue and the props).
   - (b) Rule temple_ruin's course treatment first? Both packs inherit it.
   - *Recommend:* use the `tp_*` ids, and keep both packs at candidate
     until temple_ruin's course is ruled.
4. **T05's accent says MARKET.** The word is baked into the accent texture,
   so every accent surface would carry it. Is that acceptable?

## Status, kept apart

| | Visual approval | Technical compatibility | Runtime binding | In normal play |
|---|---|---|---|---|
| T01 textures | candidate (accepted 25 Sept) | rows passed Production's pack-table check and resolver on 24–25 Sept (not re-run tonight) | none | no |
| T05 textures | accent accepted, floor calmed (25 Sept); no candidate sentence recorded | as T01 | none | no |
| Props T01–T07 | none; 054 PENDING, 056–061 PROPOSAL | loaded in the review scene; tonight's doorway check passes for all seven | none: no seam for pack props | no |

## Engineering after (not the art judgement)

- **A way to select a pack.** A Zone may carry `theme_pack`, but nothing
  sets it (`prod@c12a72f:bridge/archipepsi_bridge/schemas/zone.py:1518`).
  `THEME_PACK_STATUS` is `{}` (`godot/scripts/autoload/constants.gd:203`).
- **A runtime seam for pack props.** None exists: `ThemePack` answers
  textures only (`godot/scripts/generation/theme_pack.gd:7-10`).
- **Family matching.** Pack rows are keyed by the Zone's family. Under
  Production's fallback (`epsilon/fallback.py _theme_for`, run tonight at
  the pin):
  - *Super Mario 64* gets concrete_facility, and T02 was built on
    rusted_industrial.
  - *Super Metroid* gets neon_transit, and T04 was built on
    rusted_industrial.
  - *Kingdom Hearts* and *DOOM* depend on how the name is spelled.

  A pack whose family doesn't match binds nothing. No mapping change is
  proposed.

## Assets (for later consumption)

| Pack | Game · subtheme | House family | Props | Own textures |
|---|---|---|---|---|
| T01 | Ocarina of Time · Forest Temple | temple_ruin | `assets/models/batch054/forest_temple/tp_ft_{column,wall_relief,alcove_torch,switch_housing,root_mass,door_surround}.glb` | `assets/textures/theme/pack_forest_temple_temple_ruin_{wall,floor,accent}.png` |
| T02 | Super Mario 64 · Tick Tock Clock | rusted_industrial | `batch056/clockwork/tp_ck_{gear_column,wall_movement,door_bezel,fallen_hand,pendulum_lamp,key_escutcheon}.glb` | none |
| T03 | Bomb Rush Cyberfunk · Brink Terminal | neon_transit | `batch057/…/tp_br_{concourse_pillar,board_panel,shutter_head,torn_rail,strip_light,validator_plate}.glb` | none |
| T04 | Super Metroid · Wrecked Ship | rusted_industrial | `batch058/…/tp_ws_{stanchion,bulkhead_panel,pressure_door,debris_fan,lamp_cage,dogging_lever}.glb` | none |
| T05 | Kingdom Hearts 2 · Twilight Town | temple_ruin | `batch059/…/tp_tw_{alley_buttress,hoarding,awning_gate,tram_track,street_lantern,tram_call}.glb` | `assets/textures/theme/pack_twilight_town_temple_ruin_{wall,floor,accent}.png` |
| T06 | DOOM (1993) · UAC techbase | concrete_facility | `batch060/foundry/tp_dm_{bank_column,screen_wall,blast_frame,spill_trough,light_recess,keycard_reader}.glb` | none |
| T07 | Dark Souls III · High Wall of Lothric | gothic_stone | `batch061/…/tp_ds_{buttress_pier,aqueduct_wall,iron_door_arch,fallen_voussoir,brazier,lever_stone}.glb` | none |

The layouts are `tools/content/packlayouts/tp_*.json`. The texture rows are
in `godot/content/theme/THEME_PACK.json`, under `pack_textures`.

## Found tonight (nothing repaired)

- **Course slivers.** T01 and T05 inherit temple_ruin's unsnapped course
  pitch (0.95 m and 1.30 m on a 4 m tile). That leaves a 2–8 px sliver at
  each tile edge (`tools/blender/packmaterials.py:91`, `:115`). The pending
  temple_ruin ruling (055) settles it for all three.
  - *Smallest repair:* snap the pitch together with the family.
- **A repeating worn band.** T01's floor has a paler worn band baked into
  the tile, so it repeats every 4 m (`:120-127`).
  - *Smallest repair:* move the wear into a non-repeating decal, or drop
    it.
- **Stale records:**
  - `docs/art/theme-packs/COVERAGE.md` predates the 24–25 September rows
    and rulings (lines 57, 224, 231).
  - The review frames say "imported and fit-checked", but only into the
    review scene, not into Production.
- **A correction to my audit.** `docs/art/reports/2026-09-28-art-vs-game.md`
  says T01 and T05's textures were "accepted as candidates" on
  25 September. That is true of T01 only. For T05, the ruling accepted the
  accent and calmed the floor.
