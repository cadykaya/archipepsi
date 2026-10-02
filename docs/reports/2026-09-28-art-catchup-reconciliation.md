# Art catch-up: the reconciliation table

*Prod — 2026-09-28. Brief: `docs/ledgers/assignments/PROD_ART_CATCHUP_ASSIGNMENT.txt`.*

**Baselines:**
- Frozen art source: `claude/archipepsi-art` at
  **`a1584c8`** (Arty's owner-review package). The pack-free theme
  descriptor comes from `3e73a2ca`. Every asset below is read from that
  source; her moving head is not used.
- Production: `wip/0.4-art-catchup`, branched from the finished menu
  (`e708c5fa` + docs), which is now the 0.4 development head
  (`claude/archipepsi-0-4-blindside` = `e0421aaa`).

**How to read it:**
- **Art** is the art verdict.
- **Runtime** is permission to substitute it in play. The two are kept
  apart.
- **Where** is the consumer that places it, the place a player meets it.
- `AR` is `docs/art/ART_REVIEW.md`, `AF` is `ART_FRONTIER.md`, and `OR`
  is the 2026-09-28 owner-review package, all at `a1584c8`.

**Integrated models load from `godot/content/<family>/`.** The import
scripts that put them there:
- `tools/import_enemy_models.sh`
- `tools/import_hub_fixtures.sh`
- `tools/import_play_fixtures.sh`

Each copies byte for byte from `assets/models/`. If a model is missing,
its consumer keeps its code shape, and a test fails for every family
below.

## Integrated in this catch-up (visible in normal play)

| Family | Source | Art · runtime | Where a player meets it | Commit · test |
|---|---|---|---|---|
| Theme textures (course ruling) | 8 textures, `3e73a2ca` descriptor | 055 accepted for concrete_facility and neon_transit (AR:4997) · the refresh was named Prod's catch-up (audit) | every procedural room in those two themes | `d6e52502` · `godot-theme-pack`, `godot-content` |
| Room shells (re-baked walls) | 11 of the 12 shipped shells | P2/P3/Wave 1 PASS · already offered | every Zone request that selects a shell | `d6e52502` · `godot-content` |
| Enemy family, 10 roles × 2 value bands | batch030 (037-R surfaces, re-cut ranged and bulwark), `enemy_value_bands.json` | 037-R PASS with a caveat; Tier 1 ruled and Tier 2 accepted 26 Sept · "not active until Production loads the models" | every enemy in every Zone (the band is by theme) | `314cf7b0`, `e0a5aaba` · `godot-enemy-art` (eye, wound, muzzle, facing, collider, per-enemy tint, muzzle inside collider) |
| The Epsilon installation | batch002 | Style Lock, PASS 28 Aug | the Hub's back-wall bay, beside the portal | `04e78375` · `godot-lab` (the bay measures the model) |
| Hub campaign and controls boards | batch003 | PASS 28 Aug | behind the two live Hub boards (labels unchanged) | `04e78375` · Hub suites |
| Exit portal: wound frame + sealed / open cores | batch002 frame, batch006 cores | PASS (002 "portal DNA"; 006 portal states) | the exit of every Zone | `84d453a4` · `godot-exit-reach`, `godot-integration` |
| Echo Lab: dummy, hazard crate, height strip, runway measure | batch004 | PASS 28 Aug | the Echo Lab | `84d453a4` · `godot-lab` (marks on JUMP_FLAT_REACH, MAX_VERTICAL_STEP, JUMP_APEX_HEIGHT; sabotage-proven) |
| Affordances: breakable panel, bounce pad, wind rings | batch009 | PASS 28 Aug, "one family, seven promises" (signal) | rooms that carry those features | `ea49da82` · `godot-affordance` (art reaches the consumer; collider unchanged; per-panel damage glow) |
| Theme dressing: sconce + flame, drum, valve, transit sign, root, stump, warning plate | batch010, batch013 | 010 PASS as assets, 013 PASS | every procedural room of its theme | `ac7c206f` · `godot-affordance` (every theme places it; colliders unchanged) |
| Already in the game before this catch-up, unchanged: the hanging light housings (001's `arch_light_fixture`, 014's five), 012's base materials, and the shipped shells' selection | — | PASS | every lit room | — |

## Integrated, but conditional

- **Value bands** follow the room's theme: rusted_industrial and
  void_glitch are `deep`, the rest `standard`, from the art's own map. A
  theme the map does not name keeps the code-built enemy body.
- **The approved flame's glow** (requirement 21) is seen in the real
  renderer (Forward+). Scene glow/bloom is whatever the room's
  environment enables; nothing was added for it.
- **The breakable panel, bounce pad and wind rings** appear only in
  rooms Epsilon gives those features.
- **The newly visible wall dressing:** the code versions of the warning
  plate, valve and most of the sconce were built inside the wall, 0.2 m
  in from its face, and could not be seen. On the face, the approved
  ones now are.
  - Prop counts and positions are unchanged, and the rng stream is
    untouched.
  - It is most noticeable for the concrete warning plate (orange,
    warning-only). This is reversible; see decision 7.

## Blocked or held, and why

| Family | Art | Why it is not in play | Category | Lane |
|---|---|---|---|---|
| The Check in four states (005/005-R) | PASS (AR:1100; the 005-R heading "PENDING" is stale) | The approved item forms fail Production's `forms_read_apart` legibility rule: available vs confirmed tops 2.01 vs 2.08 m, heights 0.28 vs 0.35 m. The rule is not weakened. The art's own open question (AF:552) is the same kind. | compatibility conflict · **decision 1** | owner |
| The standard door lining (006) | PASS | Doorways often meet back to back at a seam, so lining each wall puts two linings with coplanar reveals in one opening, which would flicker. Lining once per seam is a room-generation change, outside this brief. | compatibility repair · **decision 2** | owner, then Prod |
| Hub shop counter, archive terminal, abandon station (003) | PASS | 2.45 m cabinets against the 1.1 m interactive counters players use. That is a fit question (does the counter grow, or does the art gain a counter-height version?). | fit · **decision 3** (still open) | owner + Arty |
| `hub_lab_doorway` (003) | PASS | refreshed as source only; the Lab doorway is still code-built | eligible later (not a fit problem) | Prod |
| Echo Lab moving target, reset pad (004) | PASS | shorter than their colliders (1.41 against 1.6 m; 0.36 against 0.6 m) | fit | owner + Arty |
| Echo Lab notice board (004) | PASS | there is no wall where the Lab's notice appears; placing one adds an object | no placement | Prod, if wanted |
| Moving-platform deck, wind perch (009) | PASS | taller than their colliders (0.72 against 0.4 m; 0.64 against 0.3 m) | fit | owner + Arty |
| Rail beam (009), curved rails (011) | PASS | sized differently from the code rail (0.46 × 1.68 × 6.25 against a 0.35 m beam on 1.1 m posts); rises need a legal footprint (req 16) | compatibility repair | Prod |
| Water basin (009) | PASS | a floor lip; the code marks the water's TOP at 2.15 m, so they mark different things | semantics | owner |
| Stairs, ramps, ledges (007) | PASS | the ramp slope differs (about 1:2.7 against the code's 1:3); there is no code stair | compatibility repair | Prod |
| Wall and bracket light housings (014, five) | PASS | no wall-light slot exists; `_light` only hangs from a ceiling point, and adding lights is out of bounds | no placement · **decision 4** | owner |
| Navigation signs (022) | PASS | nothing in the game marks KNOWN routes; the neon "EXIT →" signs are random dressing, and signs must not lie | no consumer | design |
| Melee device, stowed device (032) | PASS | there is no baseline melee; the stowed form could replace the code Static Pulse device, but that is the view a player looks at all game | no consumer · **decision 5** | owner |
| EchoPart forms (032) | PASS "with a boundary", seam proof only | not to be expanded | held | owner |
| Zone keys and receivers (031) | PASS (structural coding, never colour) | the runtime keys are colour-coded ("RED KEY") | compatibility repair · **decision 6** | owner, then Prod |
| Projectiles (008) | PASS as art assets | **held** by the 30 Aug A/B; the registry keeps them `pending`, and the gate is not flipped | held | owner (AF:552) |
| Architecture modules (001's other 8, 020, 021), props (010's rest), decoys (035), secret cues (036-R), hard gates (034) | PASS | no production consumer places them | no consumer | Prod/design |
| Corridor, arena and path shells (015–017) | PASS | withheld on purpose (req 35: fixed-size shells change level ids) | awaiting re-rule | owner |
| Branching rooms (044) | PENDING | — | awaiting review | owner |
| Landmarks (023), Epsilon states (024), Questionable Goods and Forge (025), checkpoint (026), pickups (027), interaction primitives (028) | PENDING | 025's counter and 027's coin and Static pickups are the recommended approvals (APPENDIX); the rest are parked | awaiting review | owner |
| Machinery, physics props (043), connect (049), manipulation (053) | proposals / PENDING | A1, A2, B1, B2; also 049 has no pivots and 053's panels use the grip material | awaiting review + art repair | owner + Arty |
| Setpieces, yard, skiff (045–047) | PENDING | C1; the skiff's fore and aft lamps are swapped | awaiting review | owner + Arty |
| Room kits (048) | PENDING, recommended **hold** | Passing and Unweighted were rejected and repaired; the kits no longer fit | held | owner |
| Enemy jobs (050), telegraphs and impacts (051), status glyphs (052) | PENDING | D1–D5. `fx_bulwark_face` sits on the enemy's BACK (a candidate overlay, not loaded); the ground marks are undersized | awaiting review + art repair | owner + Arty |
| Source-game packs (054–061), T01/T05 textures | proposals / candidates | `THEME_PACK_STATUS` stays empty; no pack is promoted | awaiting review | owner |
| Course treatment: gothic_stone | **not accepted** | — | rejected | Arty |
| Course treatment: rusted, temple, void | pending, no evidence yet | — | awaiting | Arty |
| One shell in two themes (041), deep_space_derelict (042) | proof only | — | not proposed | — |

**For the ordinary-room work later:** the architecture modules (001, 020,
021), the withheld corridor, arena and path shells (015–017), the
branching rooms (044) and the rest of the approved props are already
built. Commissioning them again would duplicate existing work.
