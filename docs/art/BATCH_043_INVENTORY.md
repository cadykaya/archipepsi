# Batch 043 — what already existed, before anything new was made

**Arty**

Art revision at the start of this batch: `327c089`.
Design read: Dess's Design 6 (`06_THE_AMALGAM.md`) at reported revision
`a20bf55`, §10's Design 2 pin, §15, §19–21, §33, and the Design 1, 2 and 5
sections those pin.

The brief asked for this before replacements, and it is worth its own file:
**existing does not mean approved, and missing runtime support does not mean
missing art.** Those are four different states and they were kept apart.

| state | meaning |
| --- | --- |
| **APPROVED USABLE** | an asset exists, the owner has passed it, it fits the requirement as it stands |
| **PENDING / ADAPT** | an asset exists and is a genuine candidate, but it is unreviewed or needs work to fit |
| **RUNTIME MISSING** | the art exists and is fine; what is absent is the engine-side connection |
| **NO ASSET** | nothing in the catalogue addresses this |

---

## 1. The status graphic kit (Design 6 §15, Design 5 §33.7–33.9)

| requirement | state | evidence |
| --- | --- | --- |
| 13 status glyphs | **NO ASSET** | `ASSET_INVENTORY.md` has no status, marker or icon row. The only glyph-like rows are `source_identity_frame` (Epsilon's sha256 derivation, a different thing entirely) and `signage_module` (navigation) |
| 8 compound glyphs | **NO ASSET** | as above |
| 4 family frames | **NO ASSET** | as above |
| duration indicator | **NO ASSET** | — |
| player-applied tick | **NO ASSET** | — |
| a world-space marker convention | **NO ASSET** | nothing in the catalogue is drawn in screen-fixed world space |

Nothing was replaced here, because there was nothing to replace. Everything
in `review/status_2026-09-11/` is newly authored.

## 2. Machinery feedback (Design 1 §19.5, Design 3 §33.8)

| requirement | state | evidence |
| --- | --- | --- |
| a conduit, any conduit | **NO ASSET** | no row in the inventory is a conduit, a wire run or a signal channel |
| five conduit states | **NO ASSET** | — |
| a setter whose lever position reads | **PENDING / ADAPT** | Batch 028's `int_wall_switch` is the right idea and is in the 023–030 PENDING band |
| a receiver reporting its own state | **RUNTIME MISSING, AND ART-LIMITED** | Batch 028 gave all nine primitives a `state_visual` region — but see below |
| `int_*` primitives generally | **PENDING / ADAPT** | nine of them, all PENDING owner review since 2026-08-29 |

### The Batch 028 finding, measured rather than recalled

The owner asked whether the previous interaction kit's state region survived
export as a material slot rather than an addressable node. It did.
`tools/content/inspect_glb_nodes.py`, written for this batch, reports:

```
== assets/models/batch028/interaction/int_wall_switch.glb
   nodes 1  meshes 1  materials 3
   node int_wall_switch   mesh int_wall_switch   3 surface(s):
        int_wall_switch_body, int_wall_switch_accent, int_wall_switch_cores
   -> 1 mesh node(s) a script can fetch by name; 3 material slot(s) in total
```

All nine are shaped the same way. So the only handle a runtime has on a
Batch 028 state region is `set_surface_override_material(2, mat)`. That can
recolour it. It cannot hide it, move it, scale it, rotate it, or give it its
own shader — and four of the five conduit states and the lever's own
position need one of those.

This is an **art-side limit**, not a runtime gap, and Batch 043's machinery
pieces fix it by exporting state regions as separate named nodes. The Batch
028 kit is not modified: it is PENDING owner review and stays exactly as the
owner last saw it.

## 3. The physics-prop family (Design 2 §10.1, twelve classes)

| class | mass | state | nearest existing candidate |
| --- | ---: | --- | --- |
| `GENERIC` | 15 kg | **APPROVED USABLE** | `prop_crate` (PASS, B1R) is 15 kg-shaped and 1.0 m, exactly `MAX_VERTICAL_STEP` |
| `WEIGHTED` | 140 kg | **PENDING / ADAPT** | none is right; `prop_crate` at 140 kg would lie about its mass |
| `POWER_CELL` | 40 kg | **NO ASSET → BUILT** | — |
| `KEY_COMPONENT` | 8 kg | **NO ASSET** | — |
| `MECHANICAL_PART` | 55 kg | **NO ASSET → BUILT** | — |
| `MOVABLE_COVER` | 220 kg | **NO ASSET** | `breakwall_panel` is a destructible, not a cover |
| `CART` | 180 kg | **NO ASSET** | — |
| `GIRDER` | 95 kg | **NO ASSET → BUILT** | — |
| `BALLAST` | 320 kg | **NO ASSET → BUILT** | — |
| `PLATE` | 60 kg | **PENDING / ADAPT** | `prop_wall_plate` (PASS, B10) is 0.90 × 0.10 × 0.62 — a wall dressing at a tenth of the mass, so the name matches and the object does not |
| `DRUM` | 70 kg | **APPROVED USABLE, WITH A CAVEAT** | `prop_oil_drum` (PASS, B10) is 0.78 × 0.78 × 0.95 and rolls. It has no handling features, so it reads as decoration — adaptation is one pass of fittings, not a rebuild |
| `ANCHOR_BLOCK` | 500 kg | **PENDING / ADAPT** | `anchor_a_soffit` / `anchor_b_jib` (PASS, B1R/B2) are grapple anchors — the same *word*, a different mechanic. Do not reuse on the name alone |

Two of the twelve are covered by approved assets, two more have a candidate
worth adapting, four were built here, and **four have nothing at all**:
`KEY_COMPONENT`, `MOVABLE_COVER`, `CART` and — in the class's own sense —
`ANCHOR_BLOCK`.

## 4. Target candidates for the status preview (Design 5 §15.1, five kinds)

| target kind | state | used in the preview |
| --- | --- | --- |
| `OBJECT` | **APPROVED USABLE** | `prop_crate`, `prop_oil_drum`, `prop_utility_box`, `prop_debris`, `prop_terminal`, `prop_machinery_unit` |
| `SURFACE` | **APPROVED USABLE** | the shipped `shell_corner_left` faces |
| `ACTOR` | **PENDING, AND BLOCKED DOWNSTREAM** | Batch 030's ten enemy roles exist and are `PASS`, but req 31 leaves seven unspawnable. No actor appears in this preview and no still here claims one |
| `PLAYER` | **NO ASSET** | the player's own status display is a HUD element, and no HUD exists |
| `VOLUME` | **NO ASSET** | nothing in the catalogue renders an authored region |

The preview shows statuses **only on `OBJECT` targets**, because that is the
only kind with an approved candidate. §15.2's target column was honoured:
nothing actor-only or surface-only is shown on a crate.

---

*Every row above was read from `ASSET_INVENTORY.md`, `ART_REVIEW.md` and the
exported `.glb` files at revision `327c089`, not from memory.*
