# What of the art lane's work is in the game

*Arty — 2026-09-28*

**A read-only comparison.** I compared my branch, `claude/archipepsi-art`
at `94b8318`, with Production's `claude/archipepsi-0-4-blindside` at
`c12a72f` (27 Sept, 20:09). I also looked at his
`wip/0.4-menu-integration` at `c3bc103`.
- I fetched and read, and nothing else. I pushed nothing, sent him no
  message, and ran nothing in his checkout.
- The only thing I ran was his own shell-offer gate, on a scratch copy
  in my sandbox.

The two branches split on 12 September (`1a9f1c9`). Nothing of mine has
been merged into his since then.

## The short answer

- **The game loads my art from one place, `godot/content`, and only
  four kinds of it:**
  - 6 light fixtures;
  - 12 room shells;
  - the six themes' textures;
  - 3 enemy projectile models, which the game holds back as pending
    review.

  No other art file of mine is anywhere under his `godot/`.
- **Nearly 200 models you approved are not in the game** (about 180
  without the early concept pieces in Batches 001–002). Most have nowhere
  to go. The enemies, Checks, portals, doors, movement pieces, props, the
  Hub and the Echo Lab are all still built from code shapes.
- **What is in the game is one approved change behind.** Your
  24 September course ruling, accepted for concrete_facility and
  neon_transit, changed 8 theme textures and the baked walls of 11 of the
  12 shells. His copies are from 12 September.
- **About 170 more models are candidates or proposals waiting on your
  review.** Most were made after the split, for the 0.4 setpieces and
  the source-game theme packs, and they never reached his branch.
- **On its way:** his menu-integration WIP is importing the UI kit:
  fonts, panels, keycaps and symbols.

## 1. What the game loads today

| Art | In the game? | Up to date? |
|---|---|---|
| **Light fixtures:** `arch_light_fixture` (Batch 001) and the five hanging housings (Batch 014), one per theme | Yes. The room builders place them. | Yes |
| **Room shells:** the P2 eight (three towers, three treasure rooms, two corners), the P3 hall, and Wave 1 (plenum, yard, span). All are `pass`. | Yes. Every live Zone request offers all 12 to Epsilon, who picks one where a room fits. His own gate passes all 12 today. | **No.** 11 of the 12 carry the concrete walls from before the course ruling. |
| **Theme textures:** six families, by role (floor, wall, trim, accent, ceiling) | Yes, on every procedural room (`ThemeMaterials` → `ThemePack`) | **No.** Eight textures predate the course ruling: concrete_facility's accent, ceiling, wall and ribbed wall, and neon_transit's accent, ceiling, floor and wall. |
| **Enemy projectiles** (Batch 008) | Exported, but **held**. The registry has marked them `pending` since your 30 August A/B verdict, so the game draws its own. | Unchanged |

Nothing else of mine is loaded by the game.

Refreshing the first three rows needs a content-pack re-export and no
code change. It does change shipped pixels, so it belongs in one of his
assignments, run through his checks, rather than in a push from me.

## 2. Approved, but not in the game

| Work | Your verdict | Why it isn't in |
|---|---|---|
| **The Epsilon installation** (Batch 002, the Style Lock centrepiece) and **the Hub's fixtures** (003) | PASS, 28 Aug | The Hub is built in code (`hub.gd`). It already has named anchors for an authored scene, including an empty `epsilon_presence`: "Epsilon is a voice in the Hub today." |
| **The Echo Lab's fixtures** (004) | PASS, 28 Aug | Built in code (`echo_lab.gd`, `lab_fixtures.gd`) |
| **The enemy family:** the ten roles (030), their surfaces (037-R), the two value bands and the ranged and bulwark tells (Tiers 1 and 2) | 037-R PASS with a documented caveat, 29 Aug; the checkpoint accepted, 26 Sept | All ten roles are in the game's roster now, but as code-built bodies (`enemy.gd`). Your ruling: approved as art, "not active in the shipping game until Production loads the models". His eye and windup flare stay. |
| **The Check in four states** (005, 005-R); **the portal and door** (006) | PASS, 28 Aug | Built in code (`reward.gd`, `exit_portal.gd`, `locked_door.gd`) |
| **Movement pieces:** stairs, ramps and ledges (007); the six affordances (009); curved rails (011) | PASS, 28 Aug | Built in code (`affordance_features.gd`) |
| **Architecture modules:** 001's nine, the structural seven (020), the services and openings (021) | PASS | Rooms are built in code or arrive as whole shells, and nothing places a module. |
| **Props and dressing** (010, 013); **navigation signs** in six themes (022); **secret cues** (029 via 036-R); **zone keys and receivers** (031); **decoys** (035) | PASS (010 "as assets") | The game has no place to load any of them. |
| **Hard-gate models** (034); **the melee device and EchoPart forms** (032) | PASS as a visual principle; PASS "with a boundary" (the forms prove the seam, nothing more) | No place to load them (req 32, 34) |
| **Shells never exported:** corridors (015), arenas (016), paths (017) | PASS, 28 Aug | Withheld on purpose. Exposing them changes how rooms chain, and so the level ids (req 35). |
| **The five wall and bracket light housings** (014) | PASS | Only the five hanging ones were exported. |
| **The UI kit** (Track A): two fonts, four nine-slice panels including the keycap, symbols and arrows, and device symbols | Approved 25–27 Sept. The device symbols are covered only by the selected menu. | Not on his 0.4 branch. **Being imported now** on his menu WIP. |
| **The menu** (the A2 hybrid) | Selected, 27 Sept | Integration is in progress on his WIP branch. |

## 3. Waiting on your review (never approved)

| Work | State |
|---|---|
| Landmarks (023); Epsilon's presentation states (024); the Forge and Questionable Goods (025); the checkpoint station (026); pickups (027); interaction primitives (028) | PENDING since late August. Each also needs a Production contract (req 24–29). |
| The Amalgam preparation: status kit, machinery and physics props (043, 053); status glyphs (052) | Proposals, pending |
| Branching rooms (044) | PENDING, 13 Sept |
| **The 0.4 setpieces** (045–051): the four setpieces' identities, the Blindside yard kit, the skiff, the three rooms' kits, conduits, enemy jobs, telegraphs and impacts | Candidates, from 22 Sept, with ten handoff documents |
| **The source-game theme packs:** props for T01–T07 (054, 056–061); T01 and T05's own textures (Track D); the course treatment for the other four themes (055) | Proposals and candidates. T01 and T05's textures were accepted as candidates on 25 Sept. The course treatment was not accepted for gothic_stone, and is pending for the other three. A pack binds only once Production gives it a status, and `THEME_PACK_STATUS` is still empty. |

That is about 170 models, plus 37 candidate course textures.

## 4. Documents he doesn't have

Twelve of my handoffs to Production were written after the split, and
exist only on my branch (`docs/art-requests/`):
- the ten from 22 September: setpiece visuals, yard kit, skiff kit, room
  kits, connect, jobs, combat effects, manipulation, enemy readiness and
  status readiness;
- the brute's body against its collider (25 Sept);
- the enemy value bands and L-08 (26 Sept).

He can read them on my branch, but they are not in his tree.

## 5. Three of my own notes were out of date

- My frontier said the approved shells were unused "until Production
  points `SHELL_FOR_TYPE` / Epsilon's `shell_id` at them". His campaign
  now offers all 12 in every live request (`epsilon/requests.py` and
  `shells.offer_of`), and his own gate passes all 12.
- A 10 September report said the large rooms were reachable only through
  the showcase. The same correction applies.
- Req 31, that only three enemy roles could spawn, is resolved in his
  code: all ten are in `ENEMY_ARCHETYPES`.

## If you want to hand some of this to Prod

My read of the cheapest wins. The order is yours.
1. **Refresh the content pack:** the course-ruled textures and the
   re-exported shells. No code; a re-export and his checks.
2. **Load the enemy models**, keeping his eye and windup, as the
   26 September handoff describes. The value bands and tells reach
   players only this way.
3. **The Epsilon installation and the Hub's fixtures,** through the Hub's
   existing anchors.
4. **Everything else needs something first.** Checks, portals, props and
   movement pieces need a place in the game designed to load them; §3
   needs your review.

## How I checked

- `git fetch`, then `git ls-tree`, `git diff` and `git grep` between the
  two branches: which art files sit under his `godot/`, and which code
  loads them.
- `git archive` of his `bridge/` and registry into my scratch space, to
  run his `shells.is_offerable` on his registry.
- The per-batch verdicts come from `ART_REVIEW.md`, `ART_FRONTIER.md` and
  the reports. Where the records disagree, I used the latest.
