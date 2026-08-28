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
| 1 | Hub / permanent spaces, and the Epsilon installation | **in progress** — installation locked; Batch 003 built the Hub's eight fixtures and modules. Echo Lab next |
| 2 | Core interactables | Check A and the portal DNA are locked; instances to build |
| 3 | Common architecture | 9 modules exist; the kit is not complete |
| 4 | The enemy production family | 10 roles concepted; production versions to build |
| 5 | Movement affordances | 2 of 7 fixtures exist |
| 6 | Universal props | 7 exist |
| 7 | Room-shell vocabulary | none |
| 8 | The six theme kits | 3 of 6 material families |
| 9 | Presentation / polish | none |

**Tooling:** `tools/shoot.sh` runs a JSON shot list through
`camera_rig.gd` — lenses in millimetres, `frame` solving its own distance,
grey / silhouette / clay / guides variants. Prefer it over writing a new
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
| Phase | **STYLE LOCK PASSED — production.** Every style batch is reviewed and every verdict recorded in `ART_REVIEW.md`; there are no open `PENDING` entries. |
| Owner review | Style Lock passed 2026-08-28. Draft PR [#5](https://github.com/cadykaya/archipepsi/pull/5). |
| Next action | **Tier 1, continued: the Echo Lab.** Its shell, dummy, height markers, runway measure, gap and fixtures are all still `hub/echo_lab.gd` primitives. |

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
| `tools/check_art_current.sh` | PASS — every asset byte-identical from source |
| Assets built | 48 models + 16 theme textures + 7 prop skins + review images in `review/batch001`, `batch002`, `batch003` |
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

**[`docs/art/review/batch002/`](review/batch002/)** — the current batch

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
         batch002_enemies epsilon_installation hub; do
  $B -b --python tools/blender/build_$s.py
done
tools/batch001_sheets.sh      # ~12 min: 28 sheets
tools/composed_room.sh        # ~2 min: 12 room captures, incl. Epsilon in context
tools/shoot.sh <list.json>    # ANY shot, from a JSON list. Start here.
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
