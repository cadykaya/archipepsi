# ART FRONTIER — where the art lane is, right now

**Read this first on every heartbeat.** It is the cheap wake-up state for
the Archipepsi art lane. Everything else in `docs/art/` is reference; this
file is the only one that says what to *do next*.

---

## THE GATE

> ## STYLE LOCK IS PASSED. PRODUCTION IS UNLOCKED.

The owner's Batch 002-R verdict passed the revised Epsilon installation and
locked the whole visual language. `ART_REVIEW.md` opens with the locked DNA;
`ART_BIBLE.md` §1z carries the same text as a build rule. **Neither is
reopened by this lane.**

### What is now allowed

- Produce assets in coherent **batches**, in the priority order below.
- Re-skin approved geometry into approved themes.
- Extend an approved module family with more instances of the same kind.
- Build the six theme kits, room shells, and the enemy production family.

### What still needs a review sheet

| Needs review | Can move faster |
| --- | --- |
| Major hero assets | Routine variations that clearly inherit locked DNA |
| New enemy families or roles | More instances of an approved module family |
| New theme landmarks | Re-skins of approved geometry into an approved theme |
| **Anything establishing new visual DNA** | Fixes to something already approved |

### What is still forbidden, and always was

- Declaring a visual concept approved. `PASS` is still the owner's word
  alone, and Style Lock passing did not delegate it.
- Deleting a rejected or superseded alternative.
- Symmetrizing or tidying the Epsilon intrusion.
- Redesigning the locked installation, unless an **integration problem**
  proves it necessary — and then the conflict is surfaced, not resolved
  quietly.
- Changing gameplay truth or an engineering contract to make an asset
  convenient. Surface the conflict and work elsewhere.
- Inventing a subjective owner decision. If a genuinely new style question
  appears: **state it, and continue on something else.**

### The production order

Assets that let the game replace its procedural / debug-looking presentation
with the approved authored vocabulary come first.

| # | Tier | State |
| --- | --- | --- |
| 1 | Hub / permanent spaces, and the Epsilon installation | **done for now** — installation locked, Batch 003 built the Hub's eight fixtures and modules, Batch 004 the Lab's seven. Shells themselves remain `hub.gd` / `echo_lab.gd` geometry |
| 2 | Core interactables | **nearly done** — Batch 005/005-R produced the Check and its four states, Batch 006 the portal's two core states and `door_standard`. What remains is `objective_marker` and `signage_module`, and both are a navigation **language** rather than a fixture — surfaced, not chosen |
| 3 | Common architecture | **in progress** — Batch 007 built the five remaining Pri-A modules (stair, ramp, ledge, straight connector, both corners). 15 of 29; what is left is all Pri B/C |
| 4 | The enemy production family | **mostly blocked** — Batch 008 built the three projectiles, the one Pri-A row with nothing in its way. Seven of the ten roles wait on colliders (req 7) and the telegraph on a node that does not exist (req 14) |
| 5 | Movement affordances | **done** — Batch 009 built the six remaining fixtures, all in the `signal` family the approved anchors wear |
| 6 | Universal props | **done as far as it can go** — **corrected** — §8's 22-prop library is placed by nothing. Batch 010 built the three the generator actually places whose theme family exists; three more wait on their theme kits |
| 7 | Room-shell vocabulary | none |
| 8 | The six theme kits | 3 of 6 material families |
| 9 | Presentation / polish | none |

**Tooling:** `tools/shoot.sh` runs a JSON shot list through
`camera_rig.gd` — lenses in millimetres, `frame` solving its own distance,
grey / silhouette / clay / guides variants, several models per scene with
`@x,y,z` offsets and a `#yaw`, a `backdrop` of `full` / `floor` / `none`
so a composed scene is not sliced by the bench's own wall, and
`hub + model:<...>` to stand an asset in the real room. Prefer it over writing a new
bench script; the six that exist are each a camera nobody could afford to
move. `docs/art/proposals/photo_mode.gd` is the in-game half, delivered as
a proposal because it belongs in `godot/`.

**Heartbeats now do production work** in this order, one coherent batch at a
time, and stop for review only where the table above says a review sheet is
needed. A heartbeat with nothing productive available still says so in one
line rather than inventing work.

---

## Status

| | |
| --- | --- |
| Branch | `claude/archipepsi-art`, based on `claude/archipepsi-build-inzshp` |
| Phase | **STYLE LOCK PASSED — production.** Batch 004 is `PASS`. Batch 005 is `PASS IN DIRECTION`, its one required revision delivered as 005-R. Batches 005-R and 006 to 011 are `PENDING`. |
| Owner review | Style Lock passed 2026-08-28. Draft PR [#5](https://github.com/cadykaya/archipepsi/pull/5). |
| Next action | **Tier 8: the three unbuilt theme material families** (`neon_transit`, `gothic_stone`, `temple_ruin`). It is the highest-leverage unblocked work left — it also unblocks three of the six dressing props §9 needs — and it is routine in the sense that `art_palette.json` already carries all six themes' ramps and `materials.paint()` already builds any of them. **But it is the first look at three themes**, so it wants a review sheet the owner can redirect cheaply, and textures are the cheapest thing in the project to rebuild. Everything before it is done to its Pri-A rows or blocked: Tier 4 past the projectiles (reqs 7 and 14), Tier 2's last two rows on a navigation-language decision, Tier 6's §8 library on the fact that nothing places it. |
| Queue depth | **Seven batches are with the owner and none is reviewed**: 005-R, 006, 007, 008, 009, 010, 011. That is worth weighing before starting an eighth — a heartbeat that keeps producing is building on ground nobody has walked on yet. If a heartbeat would rather hold, holding is a legitimate outcome and this line is why. |

### What the Batch 002 review LOCKED

Six things are `PASS` and are not open again:

- **Facility architecture** — the baseline human language.
- **The lighting rule** — cold facility, pale surfaces, localized yellow
  utility pools, never a globally warm room.
- **Check A** — its identity stays separate from Epsilon green.
- **Both grapple anchors** — A common/ceiling, B directional/wall.
- **The portal language** — human architecture + alien intrusion. Future
  variants may get stranger; the split does not.
- **The enemy family** — reads at gameplay distance, role diversity good.
  **This roster is the first production family and must not be reduced back
  to melee / ranged / brute.**

And one thing is recorded for later, so it is not re-derived: the long-term
roster target is a broad classic-FPS ecosystem — common, flyers, flankers,
artillery, support, bruisers, elites, specialist weirdos, miniboss-scale —
**inspired by the ROLE COVERAGE** of the classics and never copying their
designs, roughly ~20 types over time, with **flyers as a core category**
because the grapple gives the game verticality. Not now: the roster does not
grow again until Style Lock passes.

### What the Batch 001-R review settled

- **The facility is approved**, with one clarification: the room stays
  **cold** and warm yellow appears only as **localized utility pools and
  fixtures** within it. Not a globally warm room.
- **Both grapple anchors are kept.** A is the ceiling case, B is the
  wall / side / directional one.
- **Check A is approved.** The three enemy silhouettes are preserved.
- **Epsilon had to get bigger**: a room-scale computer installation with the
  alien core erupting through it, not a pedestal or a shrine.
- **The enemy roster expands as ORIGINAL designs**, studying what a classic
  FPS roster covers rather than any specific game's enemies, and flyers are
  wanted because the grapple creates verticality.

### What the Batch 001 review settled

- **The contrast.** Facility = cold grey abandoned research lab. Epsilon =
  alien intrusion, neon green, embedded into it. `ART_BIBLE.md` §1a.
- **Selections:** Epsilon **B**, Check **A**, Portal **B** as direction,
  Anchor **A** primary with **B** kept, and all three enemy concepts kept
  and reinterpreted as **melee / ranged / brute**.
- **Nothing was deleted.** Unselected concepts are `KEPT`.

### Objective state, last verified

| Check | Result |
| --- | --- |
| `python3 tools/blender/engine_truth.py` | PASS |
| `python3 tools/blender/palette.py` | PASS |
| `python3 tools/blender/check_docs_metrics.py` | PASS — every number in ART_REVIEW.md and ASSET_INVENTORY.md matches the build |
| `tools/sabotage_checks.sh` | see the commit for the run |
| `python3 tools/blender/sync_inventory.py` | 87 assets written |
| `tools/check_art_current.sh` | PASS — every asset byte-identical from source |
| Assets built | 87 models + 16 theme textures + 7 prop skins + review images in `review/batch001` … `batch011` |
| Composed room | 3,272 / 12,000 triangles |

### What a heartbeat cannot see

The hourly routine stores no MCP connectors, so a heartbeat session runs
**without `mcp__github__*` tools** — and `curl` against the GitHub API is
unauthenticated in this sandbox and returns an empty check-run list rather
than an error. A heartbeat therefore **cannot read CI status**, and a poll
loop built on `curl` would report silence forever, which looks exactly like
"still running".

So: a heartbeat does not chase CI. PR events wake the interactive session
directly, and that is where CI is judged. If a heartbeat needs to know, it
should say it cannot rather than guess.

---

## Where the review images are

**[`docs/art/review/batch005r/`](review/batch005r/)** · **[`batch006/`](review/batch006/)** · **[`batch007/`](review/batch007/)** · **[`batch008/`](review/batch008/)** · **[`batch009/`](review/batch009/)** · **[`batch010/`](review/batch010/)** · **[`batch011/`](review/batch011/)** — with the owner now

`batch005r/` is the one required Batch 005 revision: locked against
confirmed at 39.6 m, measured. Start at `R_state_family_far_inset.png`.
`batch006/` is the portal's two core states and the standard door; start at
`P_portal_states.png`. `batch007/` is the five Pri-A traversal modules;
start at `T_corner_turn.png`. `batch008/` is the three projectiles; start at
`X_projectile_family.png`. `batch009/` is the six remaining affordances;
start at `A_affordance_family.png` and its silhouette.

**[`docs/art/review/batch005/`](review/batch005/)** — the Check, in full

| Prefix | What |
| --- | --- |
| `K_state_family` | **start here** — the Check's four states, one camera, one frame |
| `K_state_family_far` · `_far_inset` | the same four at 39.6 m, and those pixels at 4× with no filtering. **The sheet that changes something** |
| `K_check_assembled` | mast + item + ring, with grey / silhouette / clay |
| `K_check_operator` · `_far_read` · `_cage_detail` | walk-up, distance, and the caged head at 85 mm |
| `K_item_family*` | the four items alone — lit, grey, silhouette |
| `K_destination_ring` · `K_send_beam` | the two the engine tints per recipient world |

Its `README.md` carries the three questions the batch is asking.

**[`docs/art/review/batch003/`](review/batch003/)** · **[`batch004/`](review/batch004/)** — the Hub and the Echo Lab.

**[`docs/art/review/batch002/`](review/batch002/)** — the Style Lock batch

| Prefix | What |
| --- | --- |
| `A_epsilon_operator` | **the frontal operator view** — eye height, one pace back. The shot 002-R exists for. |
| `A_epsilon_fusion` · `_oblique` · `_value` | the takeover close up, from the alien end, and with the hue removed |
| `A_epsilon_installation*` | **the room-scale computer installation** — wide sheet, 4 m medium, 2 m close |
| `A_epsilon_in_room*` | the same object standing in a 12 m room, head-on and oblique |
| `I_room_utility_pools*` | **cold room, local warm pools** — lit, greyscale, and standing in one |
| `I_room_warmlight_rejected` | the 001-R globally-warm version, kept and labelled |
| `C_portal_b2_wound` | **the breach, pushed** — the wall is present now |
| `D_enemy_family_*` | **ten roles at 18 m**, lit and silhouette, two ranks of five |
| `E_anchor_{a,b}_use` | **what each anchor is for**, with the jump it has to beat drawn in |
| `F_style_board*` | the two languages in one frame, lit and greyscale |

Start with `A_epsilon_operator.png` and `A_epsilon_in_room.png`.

**[`docs/art/review/batch001/`](review/batch001/)** — the previous batch

| Prefix | What |
| --- | --- |
| `A_epsilon_b_core` | **the revised intrusion** (A and C kept, unrevised) |
| `B_check_a_pedestal` | **the revised signal mast** (B and C kept) |
| `C_portal_b_collar` | **the revised breach** (A kept) |
| `D_enemy_lineup_*` | **all three archetypes in one frame at 18 m** — lit, silhouette, clay |
| `D_enemy_{melee,ranged,brute}_*` | the three individual sheets |
| `E_anchor_a_soffit` | primary; `E_anchor_b_jib` kept as a variant |
| `F_arch_*` | 9 modules, including the new `wall_ribbed` |
| `G_prop_*` | 7 props, re-toned off the base ramp |
| `H_material_*` | 3 theme sheets; `concrete_facility` now has 6 roles |
| `H_probe_*_room` | **in-engine theme probes** — void_glitch (requested) and rusted_industrial |
| `I_room_*` | the revised room — wide, greyscale, near, warm-light proposal, and each Check in the same spot |

Start with `I_room_wide.png` and `I_room_greyscale.png`. They answer whether
the pieces make a place, which is the question the other 31 sheets cannot.

---

## Rebuild and re-render, in full

```sh
B=.tools/blender/blender
for s in materials architecture props concept_epsilon concept_check \
         concept_portal concept_enemy concept_anchor \
         batch002_enemies epsilon_installation hub lab check \
         ways_out traversal projectile affordances dressing \
         rails; do
  $B -b --python tools/blender/build_$s.py
done
tools/batch001_sheets.sh      # ~12 min: 28 sheets
tools/composed_room.sh        # ~2 min: 12 room captures, incl. Epsilon in context
tools/shoot.sh <list.json>    # ANY shot, from a JSON list. Start here.
                              #   tools/shots/batch004_lab.json
                              #   tools/shots/batch005_check.json
                              #   tools/shots/batch005r_check.json
                              #   tools/shots/batch006_ways_out.json
                              #   tools/shots/batch007_traversal.json
                              #   tools/shots/batch008_projectile.json
                              #   tools/shots/batch009_affordances.json
                              #   tools/shots/batch010_dressing.json
                              #   tools/shots/batch011_rails.json
tools/pixel_inset.py          # a region of a render, magnified NEAREST
tools/hub_room.sh             # the Hub, built out of authored assets
tools/epsilon_views.sh        # the operator / oblique / fusion / value views
tools/enemy_family.sh         # the ten-role family sheet
tools/anchor_use.sh           # what each anchor is for
tools/style_board.sh          # the two languages in one frame
tools/check_art_current.sh    # includes the document-metric check
tools/sabotage_checks.sh      # refuses to run against a dirty tree
```

Toolchains are fetched per session into `.tools/` (gitignored) — see
`ASSET_AUTHORING.md` §1. Blender **4.5.9 LTS**, Godot **4.5.1 stable
(f62fdbde1)**.

---

## Open interface requirements — engineering's, not ours

Documented rather than invented. Nothing in Batch 001 depends on any of
them; each is a thing the art lane will need when contracts settle.

| # | Requirement | Why | Blocks |
| --- | --- | --- | --- |
| 1 | **An asset registry keyed by stable asset ID**, mapping ID → resource path + anchor + footprint + category. Epsilon selects an ID; Godot resolves it. **Epsilon never sees a path.** | An Epsilon that can name a resource path can name any file. | All integration |
| 2 | **Editor import settings preserving NEAREST with mipmaps.** The bench proves the *runtime* GLTF path keeps the sampler; the *editor* import path is a different code path and is untested. | An authored asset importing with linear filtering makes the authored/procedural seam the most visible thing in the room. | Integration |
| 3a | **~~A warm `light_color` for `concrete_facility`~~ — WITHDRAWN at 001-R.** The owner's answer was that the room stays cold and the warmth is local, so `THEME_MATERIALS` does not change. What is needed instead is a **second, short-range warm fixture light** the generator can place — energy well under the theme's own and a range around 2.6 m, so its falloff lands inside the room. `I_room_utility_pools.png` is the proposal; `I_room_warmlight_rejected.png` is what it replaces. | A single per-theme light colour cannot express "cold room, warm pools". | placement of `arch_utility_lamp` |
| 3 | **A decision on `TEXTURE_SIZE_MAX` for imported assets.** 128 bounds the runtime generator. Batch 001 stays under it so nothing depends on the answer. | The deferred first-person viewmodel tier needs 256. | `viewmodel_*` |
| 4 | **A footprint contract for the Epsilon presence, and it is now a big one.** `hub.gd` has a generic 2.0 × 3.0 × 0.8 m terminal and no dedicated fixture. Batch 002's installation is **8.80 × 2.61 × 3.55 m** — roughly a third of one 22 m Hub wall. The 001 concepts fit the old envelope; this one does not, on purpose, because the owner asked for an installation rather than a prop. | An object this size needs a reserved bay, a wall to stand against, and a rule about what may not spawn in front of it. | `hub_epsilon_presence` |
| 7 | **Collision boxes for seven proposed enemy roles.** `enemy.gd` defines melee, ranged and brute. Batch 002 proposes scuttler, charger, bulwark, artillery, beacon, drifter and diver, each with a declared box and `"engine_box": false` in its manifest, and the two flyers with a proposed hover height. | Nothing past the trio can be placed until its collider exists, and a model built to a box nobody agreed to is a model that will be rebuilt. | every batch002 enemy |
| 9 | **An in-game photo mode.** `docs/art/proposals/photo_mode.gd` is complete and parses clean: a free camera with scripted `frame()` / `frame_orbit()` / `frame_box()` entry points sharing the art bench's framing maths. It belongs at `godot/scripts/ui/photo_mode.gd` and this lane does not write there. | Every screenshot of the running game is currently whatever the player camera happened to be pointing at. | nothing — it is additive |
| 8 | **A wall-mounted grapple anchor.** `affordance_features.gd` only knows the ceiling case. `anchor_b_wall_jib` proposes a 2.6 m plate height. | The directional variant the 001-R review asked to keep cannot be placed without it. | `anchor_b_wall_jib` |
| 10 | **A decision on how `reward.gd` shows the Check's state, and two small consequences of it.** Batch 005 authors state as four meshes rather than one repainted one, because state is a closed set of four and a `material_override` replaces the authored surface. Either integration works. Whichever is chosen: `ItemVisual.position` becomes `Vector3.ZERO` — the item is authored at its true height inside the mast's cage, so the engine must not re-place it — and the ±0.12 m bob must go, because the cage interior is 0.37 m and the item fills 0.31 of it. The spin is fine: every part is rotationally symmetric on purpose. | A mesh swap keeps the authored surface in all four states and gives state a FORM channel as well as a hue one. An override keeps one mesh and loses both. | nothing — `check_item_available` works either way |
| 11 | **The destination ring is load-bearing for the Check's state read at distance, and nothing said so.** At 39.6 m the item is 4 px and locked and confirmed do not separate — `K_state_family_far_inset.png` is the evidence. They separate in the running game only because `reward.gd` drops the ring to 0.35 emission energy when locked and leaves it at 1.5 otherwise, which is 26 px of channel. Also: the ring is 1.90 m across against a 1.4 m collider, so it overhangs by 240 mm a side and a Check cannot sit flush to a wall. | If the ring's locked dimming is ever removed or repurposed, locked and confirmed become the same object across a room, and no test would catch it. | placement of every Check |
| 12 | **`exit_portal.gd`'s `Core` is placed for a solid box frame, not an authored one.** It is a 2.4 × 3.4 mesh at `y 1.9`, so it spans 0.2 to 3.6 — invisible inside a 4.2 m `BoxMesh` `Frame`, and wrong inside an authored frame whose aperture is a real hole from the floor to a 3.4 m lintel. The authored cores are built at true height and anchored `module_floor`, so `Core.position` becomes `Vector3.ZERO`. Same contract as `check_item_*`. Also: the remaining-Checks count stays engineering's `StateLabel` — it is an unbounded integer, and a pip row that saturated at eight would be lying at nine. | A core placed 200 mm high leaves a gap at the threshold and pokes through the lintel. | `portal_core_*` |
| 13 | **`echo_projectile.gd` picks its visual by nothing.** It builds one `SphereMesh` and scales it 1.5× for a lob, so `gravity_scale` and `blast_radius` — the two facts that decide whether the player steps sideways or runs — are invisible. Batch 008 authors one mesh per kind; selecting between them is a `match` on data the node already holds. | Three reactions, one silhouette. The distinction the engine does draw, size, is the least useful of the three. | `enemy_projectile_*` |
| 14 | **There is no node an authored enemy telegraph could be.** `ASSET_INVENTORY.md` §4 asks for one telegraph per archetype, readable at 18 m. `enemy.gd` has exactly one windup — the brute's — and it is `scale = Vector3.ONE * (1.0 + 0.12 * sin(...))` on the whole body. Melee and ranged have a cooldown and no windup at all. An authored telegraph needs either a child node the engine shows during windup, or a second body mesh it swaps to. | *A telegraph is a promise* (`AUTHORED_CONTENT.md`). Two of the three archetypes currently make none. | `enemy_telegraph_*` |
| 15 | **The six affordance tints are six ad-hoc colours and the family rule says they should be one.** `ASSET_INVENTORY.md` §5 states *the seven look the same everywhere or they teach nothing*, and the approved grapple anchors wear `signal`. `affordance_features.gd` gives the breakable wall the theme hazard, water `(0.35, 0.75, 0.95)`, the rail `(0.9, 0.7, 0.95)`, wind `(0.7, 0.95, 0.9)`, and the bounce pad and moving platform the theme accent and trim. Four are absent from `art_palette.json`; two vary per theme; and the rail's violet sits beside `glitch`, which means *cosmetic corruption, no mechanical meaning*. | An affordance is a promise about the player's own body. A promise that has to be re-learnt per theme is not one, and one wearing the glitch family says the opposite of the truth. | every `batch009` asset |
| 16 | **A rail that turns needs a wider `FOOTPRINT["rail"].half_width`, and every curved rail needs its ride built from `ride_path`.** Two halves of one request. (a) `half_width` is 0.5 and the rail is 0.42 m across, so a lateral swing has 270 mm either side — a weave, never a turn; a banked 90° turn wants roughly 1.6 m of half-width. (b) The lane over a rail is an axis-aligned box `Area3D`, which cannot follow a curve — so each Batch 011 rail is a POLYLINE and its manifest carries `ride_path`, the points the mesh was swept along. One box per segment is implementable with the class that already exists, and building the volume chain from that list keeps the mesh and the ride from drifting apart. | A swept spline is a rail the player falls through. A second, hand-written description of the same curve is a description that goes stale. | `rail_arc_*`, and any turn |
| 5 | **A larger footprint, or an L2 placement path, for composed clusters.** `PROP_FOOTPRINT` is 1.4 m. | Right for L0, too small for an L2 station or storytelling cluster. | `cluster_*` |
| 6 | **`challenge_marker` world semantics** (`AGENT_FRONTIER.md` still lists this open). | Its visual cannot be specified until its meaning is. | `local_reward_pickup` |

**Do not edit gameplay logic to make an asset convenient. Do not alter a
mechanical dimension to make an asset prettier.** Collision and traversal
truth remain Godot's.

---

## Known gaps, stated plainly

- **void_glitch may be too loud.** The in-engine probe is the evidence. My
  read: the floor works, the walls and ceiling at full-saturation magenta do
  not. Flagged in `ART_REVIEW.md` with a proposed fix; the owner decides.
- **Nothing is rigged or animated.** A telegraph is a promise
  (`AUTHORED_CONTENT.md`), and a promise cannot be judged from a static
  model. This is the next large question after style approval — not before.
- **Three themes are unbuilt.** `neon_transit`, `gothic_stone`,
  `temple_ruin` are inventoried and behind this gate.
- **Only `concrete_facility` has a room shot.** The other two probes exist
  as texture sheets only.
- **The review sheets are Compatibility-renderer captures**, so every one is
  a lower bound on the owner's Forward+ build.
- **`prop_*` reads blue in `concrete_facility`**, because props paint from
  the theme accent and that accent is `#4f6f8f` in `THEME_MATERIALS`. A
  faithful consequence of engine truth, flagged in `ART_REVIEW.md` because
  it is the most likely thing to feel wrong on sight.

---

## After approval — the order, when the gate opens

Not before. Written down so the first post-approval heartbeat does not have
to decide it.

1. Fold the owner's 001-R notes into `ART_BIBLE.md` and `ART_LESSONS.md`.
2. Finish the selected concepts; the kept alternatives stay in the repo.
3. Complete the remaining three theme material families.
4. Complete the architecture kit (§6 of `ASSET_INVENTORY.md`).
5. Room shells (§7) — the level that stops Epsilon obviously repeating one
   room.
6. Remaining enemy archetypes and their telegraphs, which is where rigging
   becomes unavoidable.
7. The remaining six affordance fixtures.
8. Hub and Echo Lab — last, because they are the largest and the least
   forgiving, and because everything else teaches us how to build them.
