# ASSET INVENTORY — the living ledger

Every authored asset Archipepsi needs, what it replaces, and what state it
is in. **This list is derived from a code audit, not from imagination** —
every "current procedural source" column names a real file and a real
builder on `claude/archipepsi-build-inzshp`. It is not assumed exhaustive;
the code decides exhaustiveness and this file is updated when the code
moves.

## How to read it

| Column | Meaning |
| --- | --- |
| **ID** | Stable asset ID. Never changes once the owner marks it PASS. |
| **L** | Authoring level, `AUTHORED_CONTENT.md` §3. L0 props · L1 modules · L2 alcoves/stations · L3 room shells · L4 landmarks/set pieces |
| **Scope** | `U` universal (all six themes, one asset, theme paint) · `T` theme-specific (six variants) · `H` hero/one-off |
| **Pri** | `A` alpha-blocking · `B` needed for a complete build · `C` polish |
| **Model / Tex / Integ / Rev** | `—` not started · `WIP` · `B1` built in Batch 001 · `PEND` awaiting owner · `PASS` owner-approved |

**Mechanical constraints are Godot's.** Where a row names a dimension, that
dimension is read from the engine and the asset is asserted against it at
build time. Art never changes one to make an asset prettier.

**Nothing below is approved.** Everything built in Batch 001 is `PEND`.
Everything else is `—` and stays `—` until the Style Lock gate opens.

---

## 0. Built and approved — the Style Lock set

**Style Lock passed 2026-08-28.** Every asset below carries the owner's
`PASS`; the locked DNA they establish is at the top of `ART_REVIEW.md`.
These are the vocabulary everything after them inherits.

<!-- GENERATED TABLE: regenerate with tools/blender/sync_inventory.py.
     Hand-editing it is how the two 10 mm transcription errors got in. -->

| ID | L | Category | Tris | Size (m) | Anchor | Model | Tex | Rev |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `epsilon_a_lectern` | L4 | hero | 140 | 1.18 × 0.86 × 2.62 | floor | B1R | B1R | PASS |
| `epsilon_b_core` | L4 | hero | 284 | 1.40 × 1.28 × 2.63 | floor | B1R | B1R | PASS |
| `epsilon_c_aperture` | L4 | hero | 188 | 1.34 × 0.50 × 2.77 | floor | B1R | B1R | PASS |
| `epsilon_installation` | L4 | hero | 1644 | 9.02 × 3.48 × 3.55 | floor | B2 | B2 | PASS |
| `check_a_pedestal` | L2 | hero | 300 | 0.96 × 1.04 × 2.22 | floor | B1R | B1R | PASS |
| `check_b_vault` | L2 | hero | 232 | 1.38 × 1.37 × 2.16 | floor | B1R | B1R | PASS |
| `check_c_mast` | L2 | hero | 268 | 1.11 × 1.14 × 2.22 | floor | B1R | B1R | PASS |
| `portal_a_blast` | L2 | interactable | 252 | 3.54 × 1.02 × 4.60 | floor | B1R | B1R | PASS |
| `portal_b_collar` | L2 | interactable | 412 | 3.50 × 1.26 × 4.36 | floor | B1R | B1R | PASS |
| `portal_b2_wound` | L2 | interactable | 512 | 3.59 × 1.29 × 4.45 | floor | B2 | B2 | PASS |
| `enemy_melee_stooped` | L0 | enemy | 460 | 0.77 × 0.57 × 1.57 | floor | B1R | B1R | PASS |
| `enemy_ranged_tripod` | L0 | enemy | 368 | 0.57 × 0.59 × 1.38 | floor | B1R | B1R | PASS |
| `enemy_brute_squat` | L0 | enemy | 424 | 1.70 × 1.54 × 2.50 | floor | B1R | B1R | PASS |
| `enemy_scuttler` | L0 | enemy | 212 | 1.19 × 0.59 × 0.54 | floor | B2 | B2 | PASS |
| `enemy_charger` | L0 | enemy | 176 | 0.86 × 1.62 × 1.03 | floor | B2 | B2 | PASS |
| `enemy_bulwark` | L0 | enemy | 280 | 1.45 × 0.83 × 1.92 | floor | B2 | B2 | PASS |
| `enemy_artillery` | L0 | enemy | 144 | 0.63 × 0.75 × 1.52 | floor | B2 | B2 | PASS |
| `enemy_beacon` | L0 | enemy | 152 | 0.57 × 0.61 × 2.12 | floor | B2 | B2 | PASS |
| `enemy_drifter` | L0 | enemy | 208 | 1.25 × 1.24 × 0.84 | floor | B2 | B2 | PASS |
| `enemy_diver` | L0 | enemy | 84 | 0.61 × 1.05 × 0.35 | floor | B2 | B2 | PASS |
| `anchor_a_soffit` | L2 | interactable | 160 | 1.10 × 1.10 × 1.00 | ceiling | B1R | B1R | PASS |
| `anchor_b_jib` | L2 | interactable | 168 | 1.15 × 0.60 × 1.02 | ceiling | B1R | B1R | PASS |
| `anchor_b_wall_jib` | L2 | interactable | 168 | 0.62 × 1.25 × 0.72 | wall | B2 | B2 | PASS |
| `arch_wall_panel` | L1 | module | 12 | 4.00 × 0.40 × 4.00 | floor | B1R | B1R | PASS |
| `arch_wall_ribbed` | L1 | module | 108 | 4.00 × 0.68 × 4.00 | floor | B1R | B1R | PASS |
| `arch_floor_slab` | L1 | module | 12 | 4.00 × 4.00 × 0.40 | floor | B1R | B1R | PASS |
| `arch_ceiling_beam` | L1 | module | 40 | 4.00 × 4.00 × 0.85 | ceiling | B1R | B1R | PASS |
| `arch_doorway` | L1 | module | 96 | 4.00 × 0.55 × 4.00 | floor | B1R | B1R | PASS |
| `arch_trim_rail` | L1 | module | 20 | 4.00 × 0.12 × 0.48 | floor | B1R | B1R | PASS |
| `arch_railing` | L1 | module | 96 | 4.00 × 0.11 × 1.05 | floor | B1R | B1R | PASS |
| `arch_pipe_run` | L1 | module | 172 | 4.00 × 0.40 × 0.62 | module_floor | B1R | B1R | PASS |
| `arch_light_fixture` | L1 | module | 144 | 1.50 × 0.39 × 0.26 | ceiling | B1R | B1R | PASS |
| `arch_utility_lamp` | L1 | module | 96 | 0.34 × 0.44 × 0.28 | wall | B2 | B2 | PASS |
| `prop_crate` | L0 | prop | 72 | 1.04 × 1.04 × 1.01 | floor | B1R | B1R | PASS |
| `prop_utility_box` | L0 | prop | 76 | 0.52 × 0.33 × 1.01 | floor | B1R | B1R | PASS |
| `prop_terminal` | L0 | prop | 68 | 0.86 × 0.62 × 1.41 | floor | B1R | B1R | PASS |
| `prop_pipe_cluster` | L0 | prop | 284 | 0.77 × 0.52 × 2.20 | floor | B1R | B1R | PASS |
| `prop_machinery_unit` | L0 | prop | 180 | 1.30 × 0.99 × 1.90 | floor | B1R | B1R | PASS |
| `prop_debris` | L0 | prop | 96 | 1.23 × 1.24 × 0.58 | floor | B1R | B1R | PASS |
| `prop_warning_sign` | L0 | prop | 48 | 0.65 × 0.17 × 0.44 | wall | B1R | B1R | PASS |
| `arch_wall_upper` | L1 | module | 172 | 4.00 × 0.80 × 1.00 | floor | B3 | B3 | PASS |
| `arch_pilaster` | L1 | module | 60 | 0.60 × 0.35 × 5.00 | floor | B3 | B3 | PASS |
| `hub_lab_doorway` | L2 | fixture | 84 | 3.94 × 0.74 × 3.66 | floor | B3 | B3 | PASS |
| `hub_shop_counter` | L2 | fixture | 332 | 2.60 × 1.00 × 2.45 | floor | B3 | B3 | PASS |
| `hub_archive_terminal` | L2 | fixture | 460 | 2.54 × 1.00 × 2.45 | floor | B3 | B3 | PASS |
| `hub_abandon_station` | L2 | fixture | 92 | 1.12 × 1.00 × 1.27 | floor | B3 | B3 | PASS |
| `hub_campaign_board` | L2 | fixture | 104 | 5.48 × 0.37 × 3.18 | centre | B3 | B3 | PASS |
| `hub_controls_board` | L2 | fixture | 104 | 4.28 × 0.37 × 2.98 | centre | B3 | B3 | PASS |
| `lab_dummy` | L1 | fixture | 320 | 0.90 × 0.79 × 1.78 | floor | B4 | B4 | PASS |
| `lab_height_markers` | L1 | fixture | 132 | 0.46 × 7.10 × 6.00 | floor | B4 | B4 | PASS |
| `lab_runway_measure` | L1 | fixture | 96 | 3.12 × 4.05 × 0.09 | module_floor | B4 | B4 | PASS |
| `lab_hazard` | L1 | fixture | 132 | 1.54 × 1.54 × 1.60 | floor | B4 | B4 | PASS |
| `lab_moving_target` | L1 | fixture | 232 | 0.90 × 0.63 × 1.41 | floor | B4 | B4 | PASS |
| `lab_reset_pad` | L1 | fixture | 156 | 1.60 × 1.60 × 0.36 | floor | B4 | B4 | PASS |
| `lab_notice_board` | L1 | fixture | 104 | 3.54 × 0.40 × 1.39 | centre | B4 | B4 | PASS |
| `check_mast` | L2 | hero | 288 | 0.96 × 1.04 × 2.22 | floor | B5 | B5 | PASS |
| `check_item_locked` | L2 | hero | 28 | 0.26 × 0.26 × 0.04 | module_floor | B5 | B5 | PASS |
| `check_item_available` | L2 | hero | 84 | 0.28 × 0.28 × 0.28 | module_floor | B5 | B5 | PASS |
| `check_item_sending` | L2 | hero | 112 | 0.26 × 0.26 × 0.31 | module_floor | B5 | B5 | PASS |
| `check_item_confirmed` | L2 | hero | 112 | 0.78 × 0.78 × 0.35 | module_floor | B5 | B5 | PASS |
| `check_destination_ring` | L2 | hero | 160 | 1.90 × 1.90 × 0.12 | module_floor | B5 | B5 | PASS |
| `check_send_beam` | L2 | hero | 28 | 0.74 × 0.74 × 40.00 | module_floor | B5 | B5 | PASS |
| `portal_core_locked` | L2 | interactable | 108 | 2.38 × 0.20 × 3.31 | module_floor | B6 | B6 | PASS |
| `portal_core_unlocked` | L2 | interactable | 108 | 2.38 × 0.17 × 3.29 | module_floor | B6 | B6 | PASS |
| `door_standard` | L1 | module | 144 | 2.72 × 0.62 × 3.38 | floor | B6 | B6 | PASS |
| `arch_stair` | L1 | module | 112 | 3.04 × 4.00 × 2.00 | floor | B7 | B7 | PASS |
| `arch_ramp` | L1 | module | 36 | 2.96 × 4.00 × 1.49 | floor | B7 | B7 | PASS |
| `arch_ledge` | L1 | module | 48 | 4.00 × 2.50 × 0.87 | ceiling | B7 | B7 | PASS |
| `arch_connector_straight` | L1 | module | 108 | 4.00 × 4.80 × 4.40 | floor | B7 | B7 | PASS |
| `arch_corner_left` | L1 | module | 84 | 4.80 × 4.80 × 4.40 | floor | B7 | B7 | PASS |
| `arch_corner_right` | L1 | module | 84 | 4.80 × 4.80 × 4.40 | floor | B7 | B7 | PASS |
| `enemy_projectile_straight` | L0 | enemy | 104 | 0.44 × 0.44 × 0.30 | centre | B8 | B8 | PASS |
| `enemy_projectile_falling` | L0 | enemy | 152 | 0.44 × 0.44 × 0.29 | centre | B8 | B8 | PASS |
| `enemy_projectile_lobbed` | L0 | enemy | 192 | 0.63 × 0.61 × 0.47 | centre | B8 | B8 | PASS |
| `breakwall_panel` | L2 | interactable | 112 | 0.40 × 2.42 × 2.60 | floor | B9 | B9 | PASS |
| `water_basin` | L2 | interactable | 124 | 1.64 × 1.64 × 0.23 | floor | B9 | B9 | PASS |
| `rail_beam` | L2 | interactable | 132 | 0.46 × 6.25 × 1.68 | floor | B9 | B9 | PASS |
| `wind_ring` | L2 | interactable | 160 | 1.64 × 1.64 × 0.17 | centre | B9 | B9 | PASS |
| `wind_perch` | L2 | interactable | 80 | 1.50 × 1.50 × 0.64 | ceiling | B9 | B9 | PASS |
| `bounce_pad` | L2 | interactable | 160 | 2.03 × 2.03 × 0.42 | floor | B9 | B9 | PASS |
| `movplat_deck` | L2 | interactable | 144 | 2.40 × 2.40 × 0.72 | floor | B9 | B9 | PASS |
| `prop_wall_plate` | L0 | prop | 84 | 0.90 × 0.10 × 0.62 | wall | B10 | B10 | PASS |
| `prop_oil_drum` | L0 | prop | 184 | 0.78 × 0.78 × 0.95 | floor | B10 | B10 | PASS |
| `prop_valve_wheel` | L0 | prop | 176 | 0.62 × 0.23 × 0.62 | wall | B10 | B10 | PASS |
| `rail_arc_rise` | L2 | interactable | 408 | 0.42 × 6.36 × 2.74 | floor | B11 | B11 | PASS |
| `rail_arc_launch` | L2 | interactable | 480 | 0.42 × 6.36 × 2.84 | floor | B11 | B11 | PASS |
| `rail_arc_weave` | L2 | interactable | 480 | 0.89 × 6.36 × 1.54 | floor | B11 | B11 | PASS |
| `prop_sconce` | L0 | prop | 84 | 0.24 × 0.38 × 0.49 | wall | B13 | B13 | PASS |
| `prop_sconce_flame` | L0 | prop | 112 | 0.22 × 0.19 × 0.22 | centre | B13 | B13 | PASS |
| `prop_transit_sign` | L0 | prop | 96 | 1.62 × 0.16 × 0.69 | ceiling | B13 | B13 | PASS |
| `prop_root_fall` | L0 | prop | 112 | 0.26 × 0.26 × 1.04 | ceiling | B13 | B13 | PASS |
| `prop_column_stump` | L0 | prop | 140 | 1.15 × 1.15 × 1.20 | floor | B13 | B13 | PASS |
| `light_rusted_cage` | L0 | prop | 240 | 0.46 × 0.37 × 0.72 | ceiling | B14 | B14 | PASS |
| `light_rusted_clamp` | L0 | prop | 104 | 0.31 × 0.42 × 0.38 | wall | B14 | B14 | PASS |
| `light_neon_channel` | L0 | prop | 72 | 1.62 × 0.28 × 0.15 | ceiling | B14 | B14 | PASS |
| `light_neon_edge` | L0 | prop | 60 | 1.25 × 0.14 × 0.20 | wall | B14 | B14 | PASS |
| `light_gothic_corona` | L0 | prop | 256 | 0.67 × 0.73 × 0.52 | ceiling | B14 | B14 | PASS |
| `light_gothic_lantern` | L0 | prop | 184 | 0.30 × 0.34 × 0.44 | wall | B14 | B14 | PASS |
| `light_temple_bowl` | L0 | prop | 212 | 0.54 × 0.54 × 0.62 | ceiling | B14 | B14 | PASS |
| `light_temple_niche` | L0 | prop | 140 | 0.52 × 0.30 × 0.68 | wall | B14 | B14 | PASS |
| `light_void_absent` | L0 | prop | 84 | 0.65 × 0.16 × 0.51 | ceiling | B14 | B14 | PASS |
| `light_void_debug` | L0 | prop | 60 | 0.63 × 0.62 × 0.49 | ceiling | B14 | B14 | PASS |
| `shell_corridor_narrow` | L3 | room | 132 | 4.80 × 14.00 × 4.50 | entrance | B15 | B15 | PASS |
| `shell_corridor_bays` | L3 | room | 408 | 9.60 × 16.00 × 4.50 | entrance | B15 | B15 | PASS |
| `shell_corridor_stepped` | L3 | room | 132 | 5.80 × 16.00 × 5.50 | entrance | B15 | B15 | PASS |
| `shell_corridor_gallery` | L3 | room | 240 | 8.80 × 20.00 × 5.90 | entrance | B15 | B15 | PASS |
| `shell_arena_pit` | L3 | room | 312 | 18.80 × 18.80 × 7.90 | entrance | B16 | B16 | PASS |
| `shell_arena_pillars` | L3 | room | 744 | 22.80 × 22.80 × 5.90 | entrance | B16 | B16 | PASS |
| `shell_arena_balcony` | L3 | room | 480 | 26.80 × 24.80 × 8.90 | entrance | B16 | B16 | PASS |
| `shell_arena_split` | L3 | room | 288 | 20.80 × 20.80 × 5.90 | entrance | B16 | B16 | PASS |
| `shell_path_ascent` | L3 | room | 300 | 8.80 × 31.30 × 19.00 | entrance | B17 | B17 | PASS |
| `shell_path_stagger` | L3 | room | 312 | 8.80 × 38.40 × 17.00 | entrance | B17 | B17 | PASS |
| `shell_path_spans` | L3 | room | 216 | 8.80 × 25.10 × 14.00 | entrance | B17 | B17 | PASS |
| `shell_tower_collapsed` | L3 | room | 528 | 12.80 × 14.60 × 11.50 | entrance | B18 | B18 | PASS |
| `shell_tower_spiral` | L3 | room | 636 | 12.80 × 14.60 × 14.50 | entrance | B18 | B18 | PASS |
| `shell_tower_gantry` | L3 | room | 852 | 12.80 × 14.60 × 20.50 | entrance | B18 | B18 | PASS |
| `shell_treasure_vault` | L3 | room | 360 | 8.80 × 8.80 × 5.40 | entrance | B19 | B19 | PASS |
| `shell_treasure_cache` | L3 | room | 456 | 8.80 × 8.80 × 5.40 | entrance | B19 | B19 | PASS |
| `shell_treasure_coffer` | L3 | room | 384 | 8.80 × 8.80 × 6.30 | entrance | B19 | B19 | PASS |
| `shell_corner_left` | L3 | room | 216 | 6.80 × 6.80 × 4.50 | entrance | B19 | B19 | PASS |
| `shell_corner_right` | L3 | room | 216 | 6.80 × 6.80 × 4.50 | entrance | B19 | B19 | PASS |
| `arch_wall_variant_a` | L1 | module | 72 | 4.00 × 0.66 × 4.00 | wall | B20 | B20 | PEND |
| `arch_wall_variant_b` | L1 | module | 60 | 4.00 × 0.67 × 4.00 | wall | B20 | B20 | PEND |
| `arch_ceiling_plain` | L1 | module | 60 | 4.00 × 4.00 × 0.41 | ceiling | B20 | B20 | PEND |
| `arch_trim_ceiling` | L1 | module | 48 | 4.00 × 0.49 × 0.87 | ceiling | B20 | B20 | PEND |
| `arch_floor_grate` | L1 | module | 204 | 4.00 × 4.00 × 0.36 | module_floor | B20 | B20 | PEND |
| `arch_column` | L1 | module | 60 | 0.76 × 0.76 × 4.00 | floor | B20 | B20 | PEND |
| `arch_beam_span` | L1 | module | 76 | 4.00 × 0.44 × 0.80 | ceiling | B20 | B20 | PEND |
| `arch_vent` | L1 | module | 116 | 0.70 × 0.15 × 1.10 | wall | B21 | B21 | PEND |
| `arch_duct` | L1 | module | 96 | 0.74 × 4.00 × 0.75 | ceiling | B21 | B21 | PEND |
| `arch_catwalk` | L1 | module | 220 | 1.60 × 4.00 × 1.64 | floor | B21 | B21 | PEND |
| `arch_tunnel_bore` | L1 | module | 156 | 4.68 × 4.00 × 4.03 | module_floor | B21 | B21 | PEND |
| `arch_secret_alcove` | L1 | module | 68 | 1.80 × 2.40 × 1.54 | module_floor | B21 | B21 | PEND |
| `arch_window` | L1 | module | 108 | 4.00 × 0.62 × 4.00 | wall | B21 | B21 | PEND |

| Theme material | Roles built |
| --- | --- |
| `concrete_facility` | wall, wall_ribbed, floor, **ceiling**, trim, accent |
| `rusted_industrial` | wall, floor, ceiling, trim, accent |
| `void_glitch` | wall, floor, ceiling, trim, accent |

Every figure above is read from the `manifest.json` the build writes, and
`tools/blender/check_docs_metrics.py` fails if this table and the build ever
disagree.

## 1. Permanent / hero spaces

The spaces `AUTHORED_CONTENT.md` §2 lists first, because they are seen more
than any Zone and their whole value is being the same every time.

| ID | L | Scope | Replaces | Pri | Constraint art MUST NOT change | Model |
| --- | --- | --- | --- | --- | --- | --- |
| `hub_shell` | L4 | H | `hub/hub.gd` `_build_room` | A | 22 × 16 × 5 m; spawn at (0, 0.8, 3.0) facing −Z | — |
| `hub_portal_assembly` | L4 | H | `hub/hub.gd` `_Terminal` "main" | A | 3.0 × 4.0 × 0.8 box at (0, 0, D−1.2); a second finale portal at (W/2−3, 0, D−1.2) | — |
| `hub_epsilon_presence` | L4 | H | none — Epsilon has no fixture today | A | **no contract yet, and the gap is now large.** `epsilon_installation` is 9.02 × 3.48 × 3.55 m against hub.gd's generic 2.0 × 3.0 × 0.8 terminal envelope. It needs a reserved bay; see `ART_FRONTIER.md` interface item 4 | **B2 · PASS** |
| `hub_shop_counter` | L2 | H | `hub/hub.gd` shop `SimpleStation` | A | at (−W/2+1.6, 0, D×0.45) | — |
| `hub_archive_terminal` | L2 | H | `hub/hub.gd` inventory `SimpleStation` | A | at (W/2−1.6, 0, D×0.45) | — |
| `hub_campaign_board` | L2 | H | `hub/hub.gd` `_build_campaign_board` | A | 30 cells in 3 tiers on a 0.12 × 2.6 × 5.2 panel; cell tint is `SourceIdentity`'s and is **derived, not chosen** | — |
| `hub_controls_board` | L2 | H | `hub/hub.gd` `_build_controls_board` | B | 0.12 × 2.4 × 4.0 panel | — |
| `hub_abandon_station` | L0 | H | `hub/hub.gd` `_abandon` | B | at (−W/2+2.4, 0, D−2.4) | — |
| `hub_static_glitch` | L0 | H | `hub/hub.gd` `_refresh_static` | B | up to `STATIC_GLITCH_VISUAL_CAP` (18) units. **Cosmetic only** — must never read as a mechanic | — |
| `hub_lab_doorway` | L1 | H | `hub/hub.gd` `_cut_lab_doorway` | B | opening in the −X wall; link deck at −W/2−1.6 | — |
| `lab_shell` | L4 | H | `hub/echo_lab.gd` `_build_room` | A | 16 × 26 × 6 m at offset (−13, 0, 6), yaw −90° | — |
| `lab_dummy` | L1 | H | `hub/lab_fixtures.gd` `LabDummy` | A | at (W/4, 0, 7). Health is transient by construction | — |
| `lab_height_markers` | L1 | H | `hub/echo_lab.gd` wall markers | A | must read the jump apex (1.33 m) and step (1.0 m) **exactly** | — |
| `lab_runway_measure` | L1 | H | `hub/echo_lab.gd` | A | graduated in metres against `JUMP_FLAT_REACH` (4.67 m) | — |
| `lab_gap` | L2 | H | `hub/echo_lab.gd` `_carve_gap` | A | the pit and its return. Gap width is Godot's | — |
| `lab_hazard` | L1 | H | `hub/lab_fixtures.gd` hazard | A | — | — |
| `lab_moving_target` | L1 | H | `hub/lab_fixtures.gd` moving target | A | on a track; announced by `VOCABULARY_FIXTURES` | — |
| `lab_reset_pad` | L1 | H | `hub/lab_fixtures.gd` reset pad | A | — | — |
| `lab_notice_board` | L0 | H | `hub/echo_lab.gd` `_notice` | B | carries the "NEW MECHANIC DETECTED" line | — |
| `onboarding_*` | L3 | H | first-run Zone | A | the most constrained space in the game; everything the player later reads, they learn to read here | — |
| `finale_spine` | L4 | H | finale Zone | B | arrival has to land | — |
| `postgame_hub_state` | L2 | H | Hub after `goal_sent` | C | progression is legible only against an unchanged frame | — |

---

## 2. Core interactables

| ID | L | Scope | Replaces | Pri | Constraint | Model |
| --- | --- | --- | --- | --- | --- | --- |
| `check_*` | L2 | U | `gameplay/reward.gd` | A | 1.4 × 2.6 × 1.4 m box, centre at 1.3 m; four states locked→available→sending→confirmed | **B5** — `check_mast` plus four `check_item_*` meshes, one per state |
| `check_destination_ring` | L0 | U | `reward.gd` `DestinationRing` | A | torus, inner 0.86 / outer 1.02. Says *which world receives it*, in `SourceIdentity`'s derived tint — a **different question** from the item's state, so a different channel. Eight pads and a curb, so it reads as a ring under any tint the engine gives it | **B5** |
| `check_send_beam` | L0 | U | `reward.gd` `SendBeam` | A | node name is asserted by tests; a resumed Zone must fire none. 40 m, tapered 0.40 → 0.18, untextured — a beam is a light, not a surface | **B5** |
| `portal_*` | L2 | U | `gameplay/exit_portal.gd` | A | 3.0 × 4.0 × 1.0 box; ≤ 3.6 m wide (narrowest corridor) | B1 |
| `portal_core_states` | L0 | U | `exit_portal.gd` `Core` | A | locked / unlocked. The COUNT stays engineering's `StateLabel`: it is an unbounded integer, and a pip row that saturated at eight would lie at nine | **B6** — `portal_core_locked`, `portal_core_unlocked` |
| `shop_terminal` | L2 | U | `hub/hub.gd` | A | — | B3 as `hub_shop_counter` |
| `archive_terminal` | L2 | U | `hub/hub.gd` | A | — | B3 as `hub_archive_terminal` |
| `epsilon_terminal` | L2 | H | none | A | see §1 | B1 |
| `local_reward_pickup` | L0 | U | `gameplay/local_reward.gd` | B | **six kinds**, and the client must not be able to invent a seventh: `epsilon_note`, `challenge_marker`, `cosmetic_grant`, `hub_decoration`, `lab_fixture`, `flavor_log`. Never confusable with a Check | — |
| `objective_marker` | L0 | U | `gameplay/zone_controller.gd` | B | three objectives: `reach_reward`, `kill_all`, `platform_to_goal`. **Blocked on an owner decision**: a marker set that means one thing in all six themes is a navigation language, which is new visual DNA | — |
| `door_standard` | L1 | U | `chamber_builders.gd` door gaps | A | 2.4 × 3.2 m in a 0.4 m wall, all three read from the engine. Theme trim, not a universal family — a lining is not an interactable | **B6** |
| `transition_frame` | L1 | U | connectors | B | — | — |
| `signage_module` | L0 | U | `chamber_builders.gd` `GRAFFITI` | B | navigation vocabulary; must read the same in all six themes. **Blocked on the same owner decision as `objective_marker`** | — |
| `generation_presentation` | L2 | H | `ui/` | B | `GENERATING` is a real mode for up to 120 s and must not read as a hang | — |
| `provider_failure_state` | L2 | H | `ui/` | B | **the moment the player most needs to trust what they see** | — |

---

## 3. Player / first person

| ID | L | Scope | Replaces | Pri | Constraint | Model |
| --- | --- | --- | --- | --- | --- | --- |
| `viewmodel_static_pulse` | L0 | H | `gameplay/player.gd` `Viewmodel` | A | 40 m range, 0.35 s cooldown. **Needs the 256 texel tier — deferred** pending the `TEXTURE_SIZE_MAX` decision | — |
| `viewmodel_hands` | L0 | H | none | B | twenty hours of looking at them | — |
| `viewmodel_echo_emitter` | L0 | U | `gameplay/echo_runtime.gd` | B | must serve 28 action primitives without one model per verb | — |
| `viewmodel_grapple_device` | L0 | U | `grapple_to_surface` / `_pull_target` / `_swing` | B | — | — |
| `fp_bob_support` | — | H | `player.gd` `camera_feel_offset` | C | only the camera position moves, never rotation | — |

---

## 4. Enemies

| ID | L | Scope | Replaces | Pri | Constraint | Model |
| --- | --- | --- | --- | --- | --- | --- |
| `enemy_melee_*` | L0 | U | `enemies/enemy.gd` `_build_melee` | A | 0.8 × 1.6 × 0.8 m; 24 hp, reach 2.0 m, speed 4.0 | B1 |
| `enemy_ranged_*` | L0 | U | `_build_ranged` | A | 0.7 × 1.4 × 0.7 m; **stationary**, reach 40 m. Silhouette must say "does not close" | B1 |
| `enemy_brute_*` | L0 | U | `_build_brute` | A | 1.8 × 2.6 × 1.8 m; max **one per Zone**; needs `BRUTE_LANE` 2.6 m | B1 |
| `enemy_telegraph_*` | L0 | U | `enemy.gd` attack windup | A | **a telegraph is a promise.** One per archetype, readable at 18 m. **Blocked**: `enemy.gd` has one windup, on the brute, and it is a scale pulse on the whole body — there is no node an authored telegraph could be. See interface requirement 14 | — |
| `enemy_projectile` | L0 | U | `gameplay/echo_projectile.gd` | A | 14 m/s; must be trackable against six theme backgrounds. Three kinds the engine already distinguishes by data and not by form: straight, falling, lobbed | **B8** |
| `enemy_hit_death` | L0 | U | `gameplay/damageable.gd` | B | — | — |
| `enemy_shared_parts` | L0 | U | — | B | the joints, plates and drums all three archetypes are assembled from | — |

---

## 5. Affordances — all seven

Footprints and clearances are **Godot's**, from
`generation/affordance_features.gd`, and are asserted at build time. Every
one is optional (I4) and every one pays for itself with a capability (I12).

| ID | L | Tag | Footprint (half-w × half-d × h) | Min chamber width | Model |
| --- | --- | --- | --- | --- | --- |
| `anchor_*` | L2 | `grapple_anchor` | 0.7 × 0.7 × 5.6 | 7.5 m | B1 |
| `breakwall_*` | L2 | `breakable_wall` | 0.7 × 1.3 × 3.6 | 7.5 m | **B9** |
| `water_*` | L2 | `water_volume` | 0.8 × 0.8 × 3.6 | 7.9 m | **B9** |
| `rail_*` | L2 | `rail` | 0.5 × 3.5 × 3.6 | 6.7 m | **B9** |
| `wind_*` | L2 | `wind_volume` | 0.8 × 0.8 × 6.0 | 7.9 m | **B9** |
| `bounce_*` | L2 | `bounce_pad` | 0.6 × 0.6 × 7.0 | 7.1 m | **B9** |
| `movplat_*` | L2 | `moving_platform` | 0.8 × 0.8 × 5.2 | 7.9 m | **B9** |

Shared: `THRESHOLD_CLEARANCE` 2.0 m, `CEILING_GAP` 0.5 m,
`OUT_OF_JUMP_REACH` 2.1 m, lane half-width 2.0 m, wall margin 0.35 m.

> The seven look the same everywhere or they teach nothing.

Batch 009 built the six, all in the `signal` family the approved grapple
anchors wear, with FORM carrying what each one promises.
`affordance_features.gd` currently tints them six different ways, four of
which are not in `art_palette.json` and two of which vary per theme —
so the family does not currently look the same everywhere. Interface
requirement 15.

---

## 6. Common architecture

Replaces `generation/chamber_builders.gd`, which builds all of this from
primitives today. Module grid **4.0 m**; wall thickness **0.40 m**; door
**2.4 × 3.2 m**; corridor height **3.6 m**.

| ID | L | Pri | Model | | ID | L | Pri | Model |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `arch_wall_panel` | L1 | A | B1 | | `arch_catwalk` | L1 | B | **B21** |
| `arch_wall_variant_a/b` | L1 | B | **B20** | | `arch_railing` | L1 | A | B1 |
| `arch_floor_slab` | L1 | A | B1 | | `arch_vent` | L1 | B | **B21** |
| `arch_floor_grate` | L1 | B | **B20** | | `arch_duct` | L1 | B | **B21** |
| `arch_ceiling_beam` | L1 | A | B1 | | `arch_pipe_run` | L1 | A | B1 |
| `arch_ceiling_plain` | L1 | B | **B20** | | `arch_tunnel_bore` | L1 | B | **B21** |
| `arch_doorway` | L1 | A | B1 | | `arch_window` | L1 | C | **B21** |
| `arch_connector_straight` | L1 | A | **B7** | | `arch_trim_rail` | L1 | A | B1 |
| `arch_corner_left/right` | L1 | A | **B7** | | `arch_trim_ceiling` | L1 | B | **B20** |
| `arch_column` | L1 | B | **B20** | | `arch_light_fixture` | L1 | A | B1 |
| `arch_beam_span` | L1 | B | **B20** | | `arch_signage_mount` | L0 | B | **blocked with the navigation language** |
| `arch_stair` | L1 | A | **B7** | | `arch_objective_socket` | L1 | B | **blocked with the navigation language** |
| `arch_ramp` | L1 | A | **B7** | | `arch_affordance_socket` | L1 | B | — |
| `arch_ledge` | L1 | A | **B7** | | `arch_secret_alcove` | L2 | B | **B21** |
| | | | | | `arch_vista_socket` | L2 | C | **no engine contract to build against** |

`arch_stair` and `arch_ledge` are **A** because `MAX_VERTICAL_STEP` (1.0 m)
and `SAFE_BASE_JUMP_GAP` (2.6 m) are the numbers the player's muscle memory
is built on. Batch 007 built both to those numbers: the stair climbs 2.0 m,
twice a step and above `JUMP_APEX`, so it is the first height that is
neither walkable nor jumpable; the ramp climbs exactly `JUMP_APEX`; the
ledge projects `MIN_PLATFORM_SIZE`. `arch_secret_alcove` must respect `SECRET_UNDERSIDE_MIN`
(2.75 m) and `SECRET_LIP_MAX` (4.2 m).

---

## 7. Room shells (L3)

Replaces `chamber_builders.build`'s five procedural chamber types. Enough
variants eventually that Epsilon is composing a vocabulary rather than
obviously repeating one room — **but not before Style Lock.**

| ID | Type | Bounds (from `zone.py`) | Target variants | Pri | Model |
| --- | --- | --- | --- | --- | --- |
| `shell_corridor_*` | `corridor` | 6–30 m long, 4–10 m wide, 3.6 m high | 4 | A | **B15** — `shell_corridor_narrow` / `_bays` / `_stepped` / `_gallery`, four discrete sizes, not one stretched box |
| `shell_arena_*` | `arena` | 10–28 m square, walls 4–8 m | 4 | A | **B16** — `shell_arena_pit` / `_pillars` / `_balcony` / `_split`: one subtraction, one addition, one storey, one division |
| `shell_platform_path_*` | `platform_path` | 3–8 segments, gap ≤ 2.6 m, step ≤ 1.0 m | 3 | A | **B17** — `shell_path_ascent` / `_stagger` / `_spans`. Gap and step are bounded **jointly**, so no gap in these is a literal: each is checked against `max_safe_gap(step)` before export |
| `shell_tower_*` | `tower` | 2–5 floors | 3 | A | **B18** — `shell_tower_collapsed` / `_spiral` / `_gantry` at 2, 3 and 5 floors. `floors` is the only number `TowerChamber` gives art, so the three sit at the bottom, middle and top of it and answer the climb differently |
| `shell_treasure_*` | `treasure_room` | carries a `reward_location_id` | 3 | A | **B19** — `shell_treasure_vault` / `_cache` / `_coffer`. The schema has **no** dimensional parameters (8.0 × 8.0 × 4.5 are literals) and `reward_position` is the room's centre, so the three differ only in what the room says about why the reward is there |
| `shell_corner_*` | connector | `chamber_builders.corner` | 2 | A | **B19** — `shell_corner_left` (`turn` +1, out through +X) and `shell_corner_right` (`turn` −1). One design and its reflection. Neither carries `hazard_mat`: see interface requirement 20 |

A Zone is 1–6 chambers chaining linearly along +Z, with the exit portal
appended automatically. **Epsilon never places the exit and never chooses
world coordinates.**

A shell is **one glb at one discrete size**. `corridor()` is parametric, so
no single mesh fits every case, and the owner ruled out stretching one:
*prefer authored discrete forms / size classes where gameplay geometry
matters.* Each shell's manifest entry therefore carries the semantics the
runtime needs in order to place it without opening the file:

| Key | What it is |
| --- | --- |
| `exit_offset` | where the next chamber attaches, in Godot metres |
| `bounds` | the AABB, so `zone.py` can place it without loading it |
| `interior` | the clear volume inside the walls |
| `check_anchor` | where a Check stands, if this chamber carries one |
| `enemy_anchors` | where a fight starts from |
| `affordance_anchor` | corridors are the only chamber that may carry a feature, so only corridors declare this |
| `sightline` | how far down the run the **floor** stays visible from the entrance at eye height — measured off the review render |
| `open_floor` | *(arenas)* fraction of the floor plate with nothing standing on it. `chamber_builders` hugs its crates to the walls so *the arena floor stays fightable*; this is that rule, measured |
| `cover_reach` | *(arenas)* fraction of the plate within `brute_reach` of something to hide behind. `open_floor` says how much plate a shell gives back; this says whether standing on it is worth anything |
| `worst_jump` · `max_safe_gap_at_step` | *(paths)* the longest mandatory jump in the shell, measured **edge to edge** between platform footprints, and the joint bound at that shell's `vertical_step`. A path whose first number exceeds its second is a level nobody can finish, and no render would show it |
| `objective` | *(arenas)* which of `zone.py`'s two objectives the shape actually supports. `shell_arena_balcony` lists only `kill_all`: it is the boss room, and its Check anchor is on an open plate with nothing to reach it past |

`sightline` is a claim that is easy to make falsely, so it is defined as
something a render can be checked against. `shell_corridor_bays` says 16.0,
the full run: recesses cut into the side of a straight lane are cover, not
occlusion. It earns its place in the family on routing, encounter and Check
placement instead.

---

## 8. Universal props / dressing

`PROP_FOOTPRINT` is **1.4 m** — the spacing `chamber_builders.gd` reserves.
Asserted at build time.

| ID | Pri | Model | | ID | Pri | Model |
| --- | --- | --- | --- | --- | --- | --- |
| `prop_crate` | A | B1 | | `prop_locker` | B | — |
| `prop_crate_variant_b/c` | B | — | | `prop_bench` | C | — |
| `prop_container_large` | B | — | | `prop_debris` | A | B1 |
| `prop_barrel` | B | — | | `prop_broken_machinery` | B | — |
| `prop_canister` | B | — | | `prop_structural_brace` | B | — |
| `prop_cable_bundle` | B | — | | `prop_warning_sign` | A | B1 |
| `prop_pipe_cluster` | A | B1 | | `prop_placard` | B | — |
| `prop_terminal_bank` | B | — | | `prop_utility_box` | A | B1 |
| `prop_terminal` | A | B1 | | `prop_fan` | B | — |
| `prop_machinery_unit` | A | B1 | | `prop_grate` | B | — |
| `prop_drain` | C | — | | `prop_rubble` | B | — |
| `cluster_workstation` | L2 · B | — | | `cluster_abandoned_camp` | L2 · C | — |
| `cluster_breach` | L2 · B | — | | `cluster_storage_run` | L2 · B | — |

Environmental-storytelling clusters are **L2** — composed alcoves and
stations Epsilon selects whole, not props it arranges itself.

> **Nothing in this section is placed by the generator.**
> `chamber_builders._theme_props` is the only thing that puts dressing in a
> Zone, and it places exactly one prop per THEME, none of which is listed
> above: a bolted warning plate (concrete_facility), an oil drum or a wall
> valve (rusted_industrial), a torch sconce (gothic_stone), hanging signage
> (neon_transit), root tendrils or a column stump (temple_ruin), and a
> `Label3D` reading `prop_missing.mdl` (void_glitch).
>
> Those six belong in §9's *signature dressing props* row. Batch 010 built
> the three whose theme material family existed and Batch 013 built the
> rest once Batch 012 unblocked them, so **every prop the generator places
> is now authored** except void_glitch's, which is a text label and stays
> one. The rest of this
> section is a library the game does not currently use; it stays inventoried
> because a placement path for it is a reasonable thing to want, but no
> more of it should be built before something places it.

---

## 9. Theme kits — one row per theme

**All six treatments now exist**, and every theme has a light fixture
family (Batch 014). What remains per theme is dressing beyond the one prop
the generator places, larger architectural modules, a landmark, and decals.
Everything else in this section is `—` and stays `—` until the Style Lock
gate opens. Building all six is theme production.

For **each** of `concrete_facility`, `rusted_industrial`, `neon_transit`,
`gothic_stone`, `temple_ruin`, `void_glitch`:

| Slot | Count | Pri | concrete | rusted | void | neon / gothic / temple |
| --- | --- | --- | --- | --- | --- | --- |
| floor material | 1 | A | B1 | B1 | B1 | — |
| wall material | 1 | A | B1 | B1 | B1 | — |
| trim material | 1 | A | B1 | B1 | B1 | — |
| accent material | 1 | A | B1 | B1 | B1 | — |
| hazard / signage treatment | 1 | A | shared | shared | shared | shared |
| light fixture family | 1–2 | A | B1 + B2 | **B14** | **B14** | **B14** |
| signature dressing props | 3–8 | B | **B10** | **B10** | engine text, deliberate | **B13** |
| larger architectural modules | 1–3 | B | — | — | — | — |
| landmark / hero piece | 1 | B | — | — | — | — |
| decals: paint, stains, damage | 4–6 | B | — | — | — | — |
| storytelling clusters | 0–2 | C | — | — | — | — |

The hazard and signage treatment is **shared**, not per-theme, and that is
deliberate: a theme-tinted hazard stripe is one the player has to re-learn
in every theme.

Each theme's identity, for the record:

| Theme | Structure | History it carries |
| --- | --- | --- |
| `concrete_facility` | poured panels, form ties at 0.5 m, courses at 1.2 m | water weeping from the ties, floor grit in the slab joints |
| `rusted_industrial` | corrugation at 0.22 m, lapped sheets, chequer plate | oxide bleeding **down from each fixing**, plate-joint grit |
| `neon_transit` | glazed tile grid, grout, signage band | stains from above, wet floor, ground-in dirt at the grout |
| `gothic_stone` | coursed ashlar, iron banding | soot, chipped arrises, mortar loss |
| `temple_ruin` | cut sandstone, brass mechanism | cracks, root intrusion, wind polish and drift |
| `void_glitch` | the missing-texture checker at 0.5 m — **plus the same courses, joints and fixing pitch as every other theme** | scanline tearing: whole rows displaced by whole texels |

---

## 10. Presentation and support

| ID | L | Pri | Replaces | Constraint | Model |
| --- | --- | --- | --- | --- | --- |
| `source_identity_frame` | L0 | B | `generation/source_identity.gd` | the sha256 glyph / accent / sound / particle derivation is **grammar and stays**; only its rendering is authored | — |
| `echo_acquisition_geometry` | L2 | A | `gameplay/echo_marker.gd` | the payoff beat; must read the same every time to mean anything | — |
| `ap_send_presentation` | L0 | A | `reward.gd` `SendBeam` | **the same object as §2's `check_send_beam`**, which is built and PASSed as part of Batch 005. Two rows named one asset and disagreed about whether it existed; this one is the duplicate | **B5**, as `check_send_beam` |
| `ap_receive_presentation` | L0 | B | `ui/` | — | — |
| `loading_generation_hardware` | L2 | B | `ui/` | up to 120 s; must not read as a hang | — |
| `provider_failure_state` | L2 | B | `ui/` | the moment the player most needs to trust what they see | — |
| `goal_postgame_state` | L2 | C | `hub/hub.gd` | the goal firing does **not** end play | — |
| `hud_*` | — | — | `ui/` | **fifteen pre-laid channels that never reflow.** The rules are grammar; the rendering is authored. Out of scope for the modelling lane | — |

---

## 11. Known gaps in this inventory

Honest list of what an audit could not settle:

- **`challenge_marker` world semantics are open** (`AGENT_FRONTIER.md`), so
  its visual is unspecified. `AUTHORED_CONTENT.md` §7 is explicit that a
  challenge is not an excuse to give Epsilon authored content.
- **No asset registry exists**, so no row here has an integration status.
  See `ASSET_AUTHORING.md` §10 for the interface the art lane needs.
- **Audio is out of this lane's scope** but is on the same boundary. The
  §21 tone bank is procedural and shared.
- **Enemy animation and rigging are not scheduled.** Nothing in Batch 001 is
  rigged, and a telegraph — which `AUTHORED_CONTENT.md` calls a promise —
  cannot be judged from a static model. That is a real gap and it is the
  next big question after style approval, not before it.
