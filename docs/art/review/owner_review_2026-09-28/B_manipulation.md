# B · Manipulation objects (043, with the 053 refinements)

*Arty — 2026-09-28*

**What this covers.** Twelve physics props, read against Production's own
rules at the pin. The class comes from the object's `carriable` flag and its
kilograms. Nothing here infers a permission from a handle or a painted mass
label.

## Look at

1. [`sheets/B1_manipulation_classes.jpg`](sheets/B1_manipulation_classes.jpg):
   - the twelve props, grouped by class;
   - one close-up per class;
   - fixed against heavy;
   - decoration against candidate;
   - Production's carriable cell, as the game draws it.
2. [`sheets/B2_lightened_panels.jpg`](sheets/B2_lightened_panels.jpg): the
   053 status panels, and their defect.

The prop renders were regenerated with 053, and every model is unchanged
since (checked).

## The rule in Production (at the pin)

| Class | Rule (Production) | These props |
|---|---|---|
| **Ordinary pickup** | `carriable` AND ≤ 60 kg. It is a property of the object, and no gear widens it (`godot/scripts/autoload/constants.gd:228-233`). | key component (8 kg), generic (15), power cell (40), mechanical part (55) |
| **Qualified manipulation** | What a *host* with the 120 kg envelope may push, pull or hold (`constants.gd:224-226`). No Echo delivers it yet (`gameplay/manipulation.gd:244`). | plate (60, not carriable), drum (70), girder (95), weighted (140, push only), cart (180, at the limit) |
| **Beyond the minimum envelope** | A stronger host might qualify. | movable cover (220), ballast (320) |
| **Fixed** | Not manipulable, or 400 kg and up (`gameplay/mass_class.gd:47-51`). | anchor block (500) |
| **Decoration** | No interaction. | the approved `prop_crate` and `prop_oil_drum` (no loader) |

**In normal play today:**
- There is a body-shoved 60 kg code crate, and code-built dressing.
- Pickup exists only in candidate or fixture rooms, drawn as a glowing box.
- Qualified PUSH/PULL/HOLD is not delivered by anything.

## Decide

1. **Give the four carriables an object-scale silhouette tell**, for example
   035-R's bail arch, so "you can pick this up" reads at room distance.
   - *Recommend:* yes.
   - *Why:* grips and push pads share one handling material and differ only
     at hand scale. In the lineup, the 15 kg grip reads like the 140 kg pad.
2. **Should objects beyond the minimum envelope look anchored?**
   - *Recommend:* not yet. Defer any fitting keyed to the envelope until an
     Echo actually delivers PUSH/PULL/HOLD.
   - The 053 handoff itself says `attach_*` "does not track the envelope".
3. **Do `prop_crate` and `prop_oil_drum` stay decoration?**
   - *Recommend:* yes.
4. **Keep the lightened panels,** after the repair below.

## Status, kept apart

- **Visual approval:** none.
  - 043 is in the pending band.
  - 053 is PENDING, 22 Sept (`docs/art/ART_REVIEW.md:4287`).
  - The owner's 053 correction was about meaning: "nothing needs
    redesigning" (`:4303-4311`).
- **Technical compatibility:** checked against Production's constants (no
  problems). Sizes match to 0.5 mm. No collision is shipped.
- **Runtime binding:** none.
- **Normal gameplay:** only the shove and the dressing, as above.

## Engineering after (not the art judgement)

- A loader for these props.
- The `carriable` flag, set per object.
- A verb that delivers qualified PUSH/PULL/HOLD.

Permissions stay the object's flag and kilograms.

## Assets

`assets/models/batch043/physics/phys_{key_component,generic,power_cell,mechanical_part,plate,drum,girder,weighted,cart,movable_cover,ballast,anchor_block}.glb`;
053's table is `docs/art/review/manipulation_2026-09-22/manipulation.json`.

The older parallel piece, 028's `int_carryable` (a bail-arch crate),
overlaps `phys_generic`. No document declares how the two relate.

## Found tonight (nothing repaired)

- **The lightened panels use the grip material.** All 22 `lightened_panel_*`
  nodes use `<asset>_grip`, the material the family keeps for "the surfaces
  the player's device touches". On `phys_generic` a panel covers the hand
  grip on the same face.
  - *Smallest repair:* give the panels their own material slot, and move
    them off the fitting faces.
- **A caption contradicts 053.** The fixed-vs-movable frame says the ballast
  is "meant to move", but `manipulation.json` says ballast `push: no`.
- **Stale records.** `docs/art/BATCH_043_INTEGRATION.md` still says the diff
  since the pin is empty, and lists `grip_bar` on the cart, which is now
  `push_bar`.
- **A question for Production.** `manipulation.json` gives the fixed anchor
  block the lightened class "heavy". Can `lightened` apply to a
  non-manipulable object?
