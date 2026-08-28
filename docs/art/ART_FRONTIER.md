# ART FRONTIER — where the art lane is, right now

**Read this first on every heartbeat.** It is the cheap wake-up state for
the Archipepsi art lane. Everything else in `docs/art/` is reference; this
file is the only one that says what to *do next*.

---

## THE GATE

> ## STYLE LOCK BATCH 001 IS NOT APPROVED.
> ## MASS ASSET PRODUCTION IS BLOCKED.

**Only the owner turns `PENDING` into `PASS` in
[`ART_REVIEW.md`](ART_REVIEW.md).** No entry there may be moved by anyone
else, for any reason, including "it obviously passes".

### Until the owner has reviewed, a heartbeat MAY

- fix objective pipeline failures — a broken build, export or import
- fix defects in the review tooling itself
- re-render evidence that has gone stale
- fill out `ASSET_INVENTORY.md` or the other packet documents
- record a lesson in `ART_LESSONS.md`
- correct something that **objectively** violates a written rule in
  `ART_BIBLE.md` (a budget overrun, a density out of band, an asset outside
  its collider, an enemy wearing the theme's colours)

### Until the owner has reviewed, a heartbeat MAY NOT

- declare any visual concept approved
- silently pick one of three concepts
- extrapolate an unapproved concept into more assets
- delete a rejected alternative
- start theme production — the three unbuilt themes stay unbuilt
- start final Hub or Echo Lab modelling
- expand the asset count for any reason

**If there is nothing objective left to do, say so in one line, leave this
file accurate, and end the turn.** Do not invent work to fill a heartbeat.

---

## Status

| | |
| --- | --- |
| Branch | `claude/archipepsi-art`, based on `claude/archipepsi-build-inzshp` |
| Phase | **A–D complete.** Packet, inventory, toolchain and Style Lock Batch 001 are built and rendered. |
| Owner review | **REQUESTED — not yet received.** |
| Next action | **Wait.** The gate above is the whole of the current instruction. |

### Objective state, last verified

| Check | Result |
| --- | --- |
| `python3 tools/blender/engine_truth.py` | PASS |
| `python3 tools/blender/palette.py` | PASS |
| `tools/sabotage_checks.sh` | PASS — 16/16 |
| `tools/check_art_current.sh` | PASS — every asset byte-identical from source |
| Assets built | 28 models + 12 theme textures + 37 review images |
| Composed room | 2,888 / 12,000 triangles |

---

## Where the review images are

**[`docs/art/review/batch001/`](review/batch001/)**

| Prefix | What |
| --- | --- |
| `A_epsilon_*` | 3 Epsilon presence concepts, judged at 6 m |
| `B_check_*` | 3 Check concepts, judged at 30 m |
| `C_portal_*` | 2 portal frames, judged at 30 m |
| `D_enemy_melee_*` | 3 melee silhouettes, judged at **18 m = aggro range** |
| `E_anchor_*` | 2 grapple anchors, judged at 5 m |
| `F_arch_*` | 8 architecture modules, judged at 4 m |
| `G_prop_*` | 7 universal props, judged at 3 m |
| `H_material_*` | 3 theme material probes, 4 roles each, at 4× zoom |
| `I_room_*` | **the composed room** — wide, near, greyscale, and each Check concept in the same spot |

Start with `I_room_wide.png` and `I_room_greyscale.png`. They answer whether
the pieces make a place, which is the question the other 31 sheets cannot.

---

## Rebuild and re-render, in full

```sh
B=.tools/blender/blender
for s in materials architecture props concept_epsilon concept_check \
         concept_portal concept_enemy concept_anchor; do
  $B -b --python tools/blender/build_$s.py
done
tools/batch001_sheets.sh      # ~12 min: 28 sheets
tools/composed_room.sh        # ~1 min: 6 room captures
tools/check_art_current.sh
tools/sabotage_checks.sh
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
| 3 | **A decision on `TEXTURE_SIZE_MAX` for imported assets.** 128 bounds the runtime generator. Batch 001 stays under it so nothing depends on the answer. | The deferred first-person viewmodel tier needs 256. | `viewmodel_*` |
| 4 | **A footprint contract for the Epsilon presence.** `hub.gd` has a generic 2.0 × 3.0 × 0.8 m terminal and no dedicated fixture. | The three concepts are built inside that envelope on every axis, so whichever contract lands they fit. | `hub_epsilon_presence` |
| 5 | **A larger footprint, or an L2 placement path, for composed clusters.** `PROP_FOOTPRINT` is 1.4 m. | Right for L0, too small for an L2 station or storytelling cluster. | `cluster_*` |
| 6 | **`challenge_marker` world semantics** (`AGENT_FRONTIER.md` still lists this open). | Its visual cannot be specified until its meaning is. | `local_reward_pickup` |

**Do not edit gameplay logic to make an asset convenient. Do not alter a
mechanical dimension to make an asset prettier.** Collision and traversal
truth remain Godot's.

---

## Known gaps, stated plainly

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

1. Fold the owner's notes into `ART_BIBLE.md` and `ART_LESSONS.md`.
2. Take the chosen concept for each of A–E to a finished asset; keep the
   others in the repo, marked.
3. Complete the remaining three theme material families.
4. Complete the architecture kit (§6 of `ASSET_INVENTORY.md`).
5. Room shells (§7) — the level that stops Epsilon obviously repeating one
   room.
6. Remaining enemy archetypes and their telegraphs, which is where rigging
   becomes unavoidable.
7. The remaining six affordance fixtures.
8. Hub and Echo Lab — last, because they are the largest and the least
   forgiving, and because everything else teaches us how to build them.
