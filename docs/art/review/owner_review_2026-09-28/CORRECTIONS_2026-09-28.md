# Corrections to the owner review, after `a1584c8`

*Arty — 2026-09-28*

The review package as delivered is `a1584c8`, and its pages and sheets
are left as they were. These are the corrections found since, during the
authorised repair pass on `claude/archipepsi-art-repairs-2026-09-28`.

## Wording that blurred two different things

- **"The bulwark face sits on the enemy's back"** (START_HERE, D, the
  appendix) means **`fx_bulwark_face`, a separate candidate effect**. The
  approved bulwark body is not affected and was not touched.
  - The effect's plate is at +Z, and the bulwark's front is -Z
    (`enemy.gd:1262` at `c12a72f`).
  - Its use stays parked until you decide it.

## A number I drew wrong

- **D2 understated the charger's reach.** It drew the rush as the 0.9 m
  art lane stretched to 14.3 m. The runtime hits anywhere within **2.8 m**
  of the charger's path (`reach` 14 × 0.2, `enemy.gd:1018`), so on open
  ground the footprint is a stadium **5.6 m wide and up to 19.9 m long**.
- The corrected to-scale plan is in
  `docs/art/review/repairs_2026-09-28/sheets/4_danger_marks_to_scale.jpg`.

## A proposed repair that would not have worked

- **Group C's "smallest repair" for `sp_crossing_carrier`** was "rotate the
  buffers and lamps 90° to the ends". In Production's Passing room at
  `c12a72f`, the carrier takes riders on at a side and lets them off at
  its fore end. So the ends are no more clear than the sides.
- **Group C's repair for `sp_hoist_car`** ("move the back to the closed
  face") depends on which face that room leaves closed.
- Neither is repaired. Both are held for the Passing room decision.

## Status that the repair pass changed

These are all on the repair branch, and none of them promotes anything.

| Review said | Now |
|---|---|
| 049 "has named parts but no pivots, poses or colliders" | Six real hinges with declared positions in the manifest. Still no colliders. |
| The skiff's fore and aft lamps are swapped | Renamed: `*_fore` is RailCarrier's FORWARD (+Z). Same geometry. |
| The lightened panels use the grip material, and some cover fittings | Their own material slot. The nine panels on or under fittings moved clear. |

## Found during the repair, not repaired

- **Ten more panels are badly seated.** Their placement was never on the
  documented list, so they are reported, not fixed:
  - **six hang off the body:** both on the cart (partly over nothing),
    both on the girder (a 4.5 cm gap) and both on the power cell (2.4–4.2
    cm);
  - **four sit exactly coplanar with the face under them,** which risks
    z-fighting: both of the plate's, one of the key component's, and the
    mechanical part's hub-end panel, whose corners also overhang the hub.
- **`conn_gauge`'s face is invisible.** The face disc lies entirely inside
  the solid bezel box.
- **The bench's `aabb_of`** reads only each mesh's own transform. It
  frames cameras, so no recorded number depends on it.

Details and the smallest repair for each are in
`docs/art/review/repairs_2026-09-28/README.md`.

*Follow-up, 2026-09-28 (owner-authorised):*
- **The panels:** all twelve are now re-seated (`a0f1e769`): these ten,
  plus the ballast's pair, which the stricter test caught.
- **The gauge's face** shows through its bezel, now a frame the same
  size (`9deb2c64`).
- **`aabb_of`** is still open.

Both are in the repair handoff's "Follow-up" section.
