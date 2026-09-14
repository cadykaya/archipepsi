# P2 owner review — the eight certified shells

**Nothing here is approved and nothing here changes a review state.** All
eight shells export `review: "pending"` and stay that way until the owner
says otherwise. Prior F3 passes, Production's physical certification and
older screenshots are all *not* approval of the form being shown here.

| | |
| --- | --- |
| Art source | `1d22cef` |
| Production certification | `6640d86` — all eight satisfy the room contract, **zero physical findings** |
| Shot lists | `tools/shots/p2_owner_review.json`, `tools/shots/p2_repair_{before,after}.json` |
| Regenerate | `tools/shoot.sh tools/shots/p2_owner_review.json docs/art/review/p2_owner` |

Technical validity is settled. **This package is for the other question:**
does each room read as somewhere a person designed on purpose, at a scale
and shape worth composing with?

---

## How to read the frames

Three views per shell, the same three everywhere:

| suffix | what it answers |
| --- | --- |
| `_entry` | what the player sees arriving |
| `_over` (towers) / `_interior` (rooms) / `_turn` (corners) | the primary spatial read |
| `_exit` / `_back` | what the room is like looking out, or looking back |

Towers get one extra — `_climb` — because a vertical route cannot be
judged from a plan and a doorway alone.

Cameras are the F3 review's own wherever F3 had one, so a frame here can
be held directly against the frame the owner passed. Every new camera is a
manifest anchor with x and z negated (L-52), with yaw and pitch
**computed** from two such points rather than eyeballed.

**A bench caveat that is not the art's fault (L-03):** these are
Compatibility-renderer captures with no glow and a three-light rig built
for a subject on a backdrop. They are a lower bound on the owner's
Forward+ build, and tower interiors in particular read brighter and
flatter here than in engine.

---

## The two shells with intentional visible P2 repairs

Only `shell_tower_collapsed` and `shell_tower_spiral` changed shape. Both
changed for the same reason and by the same helper.

The deck was a 0.50 m slab at summit height across the back 4 m of every
tower, and it sat directly over the last rungs of both climbs — 1.50 m and
0.50 m of headroom on collapsed, 1.50 m on spiral, against the 2.40 m a
standing player needs. `_deck_well` cuts the deck out of the column the
climb comes up.

Neither climb could move instead: the spiral's `inset`, `margin` and
`spacing` are `tower()`'s own numbers so an authored spiral climbs where a
procedural one does, and the collapsed tower's alternating half-floors
were already the answer to a `routecheck` refusal.

| shell | deck before | deck after |
| --- | --- | --- |
| `shell_tower_collapsed` | 12.0 × 4.0 | **7.4 × 4.0**, opening on −x |
| `shell_tower_spiral` | 12.0 × 4.0 | **8.6 × 4.0**, opening on +x |

**The comparison frames.** Identical cameras either side; `BEFORE` renders
`a798b2c`, `AFTER` renders `1d22cef`. Nothing is restaged, relit or
reframed to flatter the repair.

| | plan | at the climb's arrival |
| --- | --- | --- |
| collapsed | `X_collapsed_over_before` / `_after` | `X_collapsed_arrive_before` / `_after` |
| spiral | `X_spiral_over_before` / `_after` | `X_spiral_arrive_before` / `_after` |

**What to judge, in the owner's words:** does the opening look like
designed architecture rather than a hole cut to satisfy a validator; does
it preserve the room's identity; and does the climb now visually
communicate where it arrives.

---

## Gantry required no spatial repair

`shell_tower_gantry` was **not** changed, and was deliberately not changed
to make the three tower variants look equally edited. Its climb runs up
the front half of the shaft and nothing of it was ever under the deck, so
the same derivation that cut the other two decks left this one alone.

Its visible mesh is byte-identical to the F3 build, proven at the glTF
accessor level.

*One observation, not a change:* `T_gantry_over` differs from the F3
capture by 1.3 % of pixels. That is draw-order z-fighting on a
**pre-existing** coplanar overlap — `landing_4` and the deck both have
their top face at y = 15.0 — which shifted when the deck object was
renamed. It is worth the owner knowing about; it is not something P2
introduced and it was not touched here.

---

## Treasure: the `step_low` removal was metadata only

Measured rather than asserted. Re-rendering the **F3 shot list** against
today's assets reproduces all eight `batch019` captures **byte-identical**
to the images committed at F3 — the three treasure rooms and both corners
included. The visible form the owner passed is the visible form on offer.

What changed is a claim, not a mesh: the plinth's lower step is no longer
declared a place a player can stand, because its 3.0 m square carries the
2.2 m upper step and what is left is a 0.40 m ring against a 0.80 m
player. The riser still exists and still collides.

---

## Corners: connectors, not sculptures

Their role is **corridor-compatible authored turn**, `exit_yaw` +90 / −90.
There is no `corner` chamber type and none is proposed — `zone.py` has
`corridor`, `arena`, `tower`, `treasure_room`, and the corners are offered
as corridors with `corner` kept beside it as a shape tag.

`C_chain_context` puts one behind a corridor so the turn is judged as a
link in a chain. **The corridor in that frame is Batch 015 — approved, not
exported, and present for context only.**

---

## Review cards

Each shell: `PASS`, `KEEP PENDING`, or `REVISE`.

### Corners

| | `shell_corner_left` | `shell_corner_right` |
| --- | --- | --- |
| Family | corridor (shape tag `corner`) | corridor (shape tag `corner`) |
| Size class | small | small |
| Spatial role | authored turn between corridors | the same, mirrored |
| `exit_yaw` | **+90** | **−90** |
| P2 physical audit | PASS — 0 findings | PASS — 0 findings |
| Visible repair since F3 | **NO** — byte-identical | **NO** — byte-identical |
| Triangles | 216 | 216 |
| Frames | `C_left_entry`, `C_left_turn`, `C_left_back`, `C_chain_context` | `C_right_entry`, `C_right_turn`, `C_right_back` |

### Treasure

| | `shell_treasure_vault` | `shell_treasure_cache` | `shell_treasure_coffer` |
| --- | --- | --- | --- |
| Family | treasure_room | treasure_room | treasure_room |
| Size class | small | small | small |
| Spatial role | the reward room, protected | the same, stored | the same, displayed |
| P2 physical audit | PASS — 0 findings | PASS — 0 findings | PASS — 0 findings |
| Visible repair since F3 | **NO** — byte-identical | **NO** — byte-identical | **NO** — byte-identical |
| Triangles | 360 | 456 | 384 |
| Frames | `R_vault_entry`, `_interior`, `_exit` | `R_cache_entry`, `_interior`, `_exit` | `R_coffer_entry`, `_interior`, `_exit` |

All three are the same 8.0 m box with the same plinth at the same reward
position. Everything that differs between them is the answer.

### Towers

| | `shell_tower_collapsed` | `shell_tower_spiral` | `shell_tower_gantry` |
| --- | --- | --- | --- |
| Family | tower | tower | tower |
| Size class | medium | medium | medium |
| Spatial role | a room twice, at two heights | the canonical square helix | a landing every 3.0 m |
| Floors / rise | **2** / 6 m | **3** / 9 m | **5** / 15 m |
| P2 physical audit | PASS — 0 findings | PASS — 0 findings | PASS — 0 findings |
| Visible repair since F3 | **YES** — deck well | **YES** — deck well | **NO** — byte-identical |
| Triangles | 528 | 636 | 852 |
| Frames | `T_collapsed_entry`, `_over`, `_exit`, `_climb` | `T_spiral_entry`, `_over`, `_exit`, `_climb` | `T_gantry_entry`, `_over`, `_exit`, `_climb` |

---

## Inventory

36 images. 28 in the main package, 8 in the repair comparison.

| group | count | files |
| --- | ---: | --- |
| Towers | 12 | `T_{collapsed,spiral,gantry}_{entry,over,exit,climb}.png` |
| Treasure | 9 | `R_{vault,cache,coffer}_{entry,interior,exit}.png` |
| Corners | 6 | `C_{left,right}_{entry,turn,back}.png` |
| Connector context | 1 | `C_chain_context.png` |
| Repair comparison | 8 | `X_{collapsed,spiral}_{over,arrive}_{before,after}.png` |
