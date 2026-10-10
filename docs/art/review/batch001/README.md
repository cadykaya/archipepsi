# Style Lock Batch 001 — review images

**37 images. Nothing here is approved.** The ledger is
[`../../ART_REVIEW.md`](../../ART_REVIEW.md) and every entry in it is
`PENDING`. Only the owner turns `PENDING` into `PASS`.

## Start here — two images

| | |
| --- | --- |
| **[`I_room_wide.png`](I_room_wide.png)** | The composed room, from the doorway, in the game's own camera: 90° FOV at 1.6 m eye height. Built from Batch 001 pieces only. **This is the shot that decides whether the kit makes a place**, which none of the other 31 sheets can answer. |
| **[`I_room_greyscale.png`](I_room_greyscale.png)** | The same shot desaturated. The quickest honest test of a palette there is: if the composition falls apart with colour removed, the palette is not working. |

## Then the concepts — no winner is picked in any of these

| Sheets | Ask | Judged at |
| --- | --- | --- |
| `A_epsilon_a_lectern` · `b_core` · `c_aperture` | Is Epsilon furniture, an installation, or architecture? | 6 m |
| `B_check_a_pedestal` · `b_vault` · `c_mast` | Which reads as the same important object from across a room? Also `I_room_check_*`, each in the same spot in the same room. | 30 m |
| `C_portal_a_blast` · `b_collar` | Is the exit equipment, or a wound in the architecture? | 30 m |
| `D_enemy_melee_a_stooped` · `b_tripod` · `c_squat` | Which reads as hostile and melee at **48 px**? And with it: are enemies machines, creatures, or the fabricated-organic family in between? | **18 m = `ENEMY_AGGRO_RADIUS`** |
| `E_anchor_a_soffit` · `b_jib` | Which is quicker to read while moving at 7 m/s? | 5 m |

## The kits and the materials

| Sheets | What |
| --- | --- |
| `F_arch_*` (8) | The architecture mini-kit. Every module measures exactly 4.00 m on its long axis at exactly 32.0 texels/m, so one module is one texture tile. |
| `G_prop_*` (7) | The universal prop kit. All inside `PROP_FOOTPRINT` (1.4 m). |
| `H_material_*` (3) | `concrete_facility`, `rusted_industrial`, `void_glitch` — four roles each, at 4× nearest-neighbour zoom. **`void_glitch` is the commonality test**: it carries the same courses, joints and fixing pitch as the other two, so it should read as *this game's* broken room rather than a different game's texture. |

## How to read a sheet

Eight shots, identical for every asset, deliberately never growing. Judge in
this order and stop at the first failure:

1. **silhouette** — flat black on a light field. Can you name it? If not,
   nothing else matters.
2. **clay** — untextured. Paint hides form.
3. **front / 34 / side / rear** — the front is the one view that lies,
   because the front is what everything gets tuned in.
4. **scale 1.8m** — beside a rod the height of the player, banded every
   0.5 m.
5. **play Nm** — the game's 90° lens at 1.6 m eye height, at the distance
   this object is genuinely first seen from, with the **measured** screen
   height printed on it.

## Two caveats about these captures

- **Compatibility renderer only.** This sandbox will not initialise Vulkan,
  so every image is a *lower bound* on the owner's Forward+ build, which
  gets glow and proper shadow filtering.
- **Only `concrete_facility` has a room shot.** It is a bright, light theme
  by engine truth (base `#b9bcb6`, light energy 3.0). The other two probes
  exist as texture sheets only and will land very differently.

## Regenerating

```sh
tools/batch001_sheets.sh   # ~12 min: the 28 asset sheets
tools/composed_room.sh     # ~1 min: the 6 room captures
```
