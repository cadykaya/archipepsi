# Impact Relay G1: Batch 065 handoff to Prod

*Arty — 2026-10-08*

**For:** Prod, for the G1 candidate integration in `impact_relay_room.gd`.
**Owner's ruling, 2026-10-08:** Batch 065 goes to Prod for G1, as is. **There is no new launcher or barrier design round before the room is played.** The art lane supports any specific fit or state issue Prod finds. It doesn't redesign.

**FINAL, later on 2026-10-08:** `docs/art-requests/2026-10-08-g1-crossing-d-final-integration.md` holds the final instructions for Prod (tote v2 approved, the quiet-ceiling asset, C2). Where this note differs, that one wins.

## Update, later on 2026-10-08: approved for integration

**The owner approved all five Batch 065 pieces as candidate art for G1's playable**: the launcher, the impact seal, the permanent frame, the teaching tote and the heavy weight. **G1's mechanics stay exactly as tested.** The owner wants to compare the placeholder version with the art-integrated one, so:
- **Keep both versions buildable from one branch.** A launch flag or a review-menu toggle would do; how is your call. The art only ever goes in as visual children, with your code boxes hidden while it's on. Nothing else differs between the two.
- **Leave the launcher's three convex colliders OFF.** They would change how a dropped weight settles, and that's a mechanics change. Your plate box stays the only collider.
- **The tote is now v2** (below). It has the same file name, box, origin and node names, so if you've already mounted v1, swapping the GLB is all it takes.
- [G7: your placeholders against Batch 065 integrated, from the same cameras, in the unpowered start state](../art/review/bloom_g1_2026-10-08/G7_g1_placeholders_vs_batch065.png)

**What I'll do if you hit something:** a node, a pivot, a state or a fit that doesn't land in the running room gets fixed in the builder and re-exported. There's no new design. The raceway's end (below) is still the one fit issue I know of.

Everything here was read against `review/impact-relay-g1` at `21b5fb2f` (build `a3b59c46`). Nothing in that branch, Prod's registry or his runtime was edited. The renders come from a detached, read-only checkout in the art lane's scratch.

## What to integrate

All five are in `assets/models/batch065/impact_relay/`. The builder is `tools/blender/build_impact_relay.py`. Rebuilding is byte-identical, and the manifest holds every contract below in machine-readable form.

| GLB | Replaces | Mount | Tris |
|---|---|---|---|
| `ir_object_launcher` | `ObjectPlate`'s code boxes `Slab`, `Chevron`, `Lip` and `PowerLamp` | a child of the `ObjectPlate` at identity; keep its `Sensor` | 476 |
| `ir_impact_seal` | `ImpactShutter`'s `Casing`, `Band` and `Seam` | a child of the `ImpactShutter` at identity | 744 |
| `ir_seal_jamb` | nothing (new) | on the wall at the shutter's origin, **not** under the shutter, so it stays when the seal breaks | 108 |
| `ir_teaching_tote` | `relay_crate`'s `Base`, `Side` and `End` | a child of the `ManipulableBody` at identity | 282 (v2) |
| `ir_relay_weight` | `relay_weight`'s `Look`, `Band`, `HandlePost` and `Handle` | a child of the `ManipulableBody` at identity | 108 |

**No physics changes.** No body's mass, size, damping or collider changes. The tote and the weight ship **no** collider: they fill your `CRATE_SIZE` and `WEIGHT_SIZE` boxes exactly, with the origin at the box centre where `ManipulableBody.create` centres its `BoxShape3D`. The exported bounds are ±0.25 / ±0.18 / ±0.25 and ±0.225 / ±0.30 / ±0.225. The seal and jamb ship none either.

The launcher ships three convex colliders: the two side lips and the rear housing. They would funnel a weight dropped near an edge, which **is** a physics change. Leave them out unless you and Dess want them; the plate's own 2.0 × 0.25 × 2.0 box is unchanged, and the deck's top is at 0.25 m.

## Fit against G1 (`a3b59c46`)

| Check | Result |
|---|---|
| `ObjectPlate` and `ImpactShutter` | `impact_lab_parts.gd` is unchanged from G0, so the launcher and seal fit exactly as measured on G0 |
| The shutter at (0, 1.5, −12.25), 3.0 × 3.0 × 0.4, `normal` BACK | The seal fits inside the box. The jamb sits 0.25–0.33 m in front of the shutter's centre, flush on the hall wall's face (z −12.0) |
| The crate, 0.5 × 0.36 × 0.5, 4 kg | `ir_teaching_tote` fills it exactly |
| The weight, 0.45 × 0.6 × 0.45, 36 kg | `ir_relay_weight` fills it exactly. The handle lies **inside** the box, unlike the placeholder's, which rises 0.12 m above it |
| **The raceway into the plate** | **One fit issue, below** |
| A body resting on the plate | It covers the middle chevron (`move_chevron_2`). Chevrons 1 and 3 and the rails still carry the arming ramp from the lever. This is noted, not changed |

**The raceway.** G1 runs the plate line as `[gland, (gland.x, 0, PLATE_AT.z), (PLATE_AT.x − 1.0, 0, PLATE_AT.z)]`. That ends at the middle of the plate's **west face**, under the launcher's west lip, and misses its power inlet. The inlet is on the **rear face** of the housing, at local (−0.90, 0.065, +1.26), which is world **(−0.90, 0.065, +0.26)**, facing +Z.

The smallest fix is to change the last waypoints, with one more segment normal:

```
[gland,
 Vector3(gland.x, 0, PLATE_AT.z + 1.5),
 Vector3(PLATE_AT.x - 0.90, 0, PLATE_AT.z + 1.5),
 Vector3(PLATE_AT.x - 0.90, 0, PLATE_AT.z + 1.26)]
```

This assumes your floor raceway carries its pipe at the kit's `PIPE_Z` (0.065 m). I measured the inlet, not `P.raceway`, so check that once. A feed from the east is the same thing mirrored in x. I won't move the inlet unless you'd rather I did.

## States, in your names

The launcher is driven by `ObjectPlate`'s signals. Dess's v1 names are shown beside Prod's; v2 adopts Prod's states and timings.

| `ObjectPlate` | Launcher |
|---|---|
| unpowered | rails, chevrons and power parts idle; the deck at rest |
| powered idle | `power_*` live; `move_rail_*` live and steady; chevrons idle |
| arming (0.6 s) | chevrons 1 → 3 light one by one, back to front, at 1/3, 2/3 and 3/3 of the ramp; the rails pulse faster as it fills |
| `fired` | `deck_hinge` kicks to 10° in 0.06 s and back in 0.25 s, **on `fired` only**; every `move_*` part flashes to 2.5× live for 0.12 s |
| re-arm (1.0 s) | the chevrons fade to idle |
| dud | one dim chevron flicker; power stays idle |

Two contracts hold throughout:
- **The hinge:** `deck_hinge` turns about its local X, with the pivot at runtime (0, 0.21, 0.95). It carries the deck and the three chevrons.
- **Colours:** the idle emitter is #1b2d66 and the live one is the Batch 064 movement blue.

**The seal is driven by `ImpactShutter`.**

| State | Seal |
|---|---|
| wear | the collar material's emission follows your `_paint(0.4 + 2.0·wear)`. **Cap the energy at about 0.7–0.9:** at 2.4 the orange washes out to yellow |
| glance | show the next scuff (`scuff_1`, then 2, then 3) and spark the collars for 0.15 s |
| refused | flash the collars for 0.25 s |
| broken | each `slab_1..6` node becomes a RigidBody at its own transform, with its origin at the slab centre; roughly 60 kg each, colliding with the world only. `seal_core` goes with it, and the jamb stays |

**The tote (v2, later on 2026-10-08)** is a moulded container in satin ivory plastic:
- thin drafted walls with round-ended vents;
- rounded corners and a thick rolled rim, a shade lighter (`ir_tote_rim`);
- dark moulded hand recesses on the two end walls (`grip_hand_0/1`).

It is 282 tris, up from v1's 228, and still within the 300 budget. Its floor sits 1 cm up on the walls' foot, so it never z-fights with the deck it rests on. v1 was a grey frame of boxes, now replaced.

| State | Tote |
|---|---|
| lands | Dess's **wobble** is code, not a pose: a damped rock of the visual child about the centre of its floor, about 6° and three swings in 0.4 s, on any landing harder than a set-down. D-18 §7 lists it as cuttable polish |
| refused | nothing on the tote; the shutter's flash and knock say it |

**The weight** is a squat block of dark cast steel on a full-width foot, with a strap, a cap worn bright, and a bare bail handle (`grip_handle`).

| State | Weight |
|---|---|
| `lightened` (D-18 v2 names it on this object) | override the `ir_lightened` slot on `lightened_panel_0/1`, as Batch 043 does |
| held | `grip_handle` may light while held, as may the tote's grips. This is optional |

## Tote vs weight: why these two, and what the library had

The owner said the lesson depends on the 4 kg tote and the 36 kg weight looking materially different. **The library had nothing to reuse at these sizes:**
- `phys_generic` is a solid 0.65 m crate;
- `phys_power_cell` is an energy cell;
- `phys_mechanical_part` is a machine part;
- `int_carryable` and `dec_crate_fixed` are heavy-looking by design;
- `prop_crate` is decoration.

Rescaling any of them would change what it is. So these are two minimal new props in Batch 043's family rule: bare dark metal only where a hand takes hold. The manifest's `library_check` records the search.

**How they differ:** open against solid, pale against dark, thin against massive.
- From the gallery and at 6–7 m, the tote shows the floor through it, and the weight reads as a dark, solid block with a handle.
- In grey, the tote stays the brightest loose object and the weight one of the darkest.

Evidence:
- [G4: 2.5 m, before and after, in colour and grey](../art/review/bloom_g1_2026-10-08/G4_tote_weight_2m5_before_after.png)
- [G5: 6–7 m and the gallery view](../art/review/bloom_g1_2026-10-08/G5_tote_weight_distance_before_after.png)
- [G6: tote v1 against v2, at 2.5 m, at 6–7 m and from the gallery](../art/review/bloom_g1_2026-10-08/G6_tote_v1_v2.png). G4 and G5 show v1.
- [G8: tote v2, close](../art/review/bloom_g1_2026-10-08/G8_tote_v2_close.png)

## Your packaging note on my candidate files

Your G1 report says `test_every_bundled_binary_is_first_party_or_licensed` fails because `godot/candidate/crossing_kit/` isn't registered, and that registering it is a decision about my candidates. **From the art side, the answer is that they're first-party.** The directory holds four Batch 063 kit pieces (`ck_floor_lever` and `ck_raceway_inside`, `_terminal` and `_turn`). Each GLB was generated in this repository by `tools/blender/build_crossing_kit.py`, and each PNG beside it is Godot's import extraction of that GLB's own texture. They have the same provenance as `assets/models/`: no third-party pixels or meshes, and no licence record needed.

Whether you list the directory as first-party or stop tracking candidate binaries under `godot/` is your call, in your registry. I haven't touched it. The Batch 065 files are the same kind, when you bring them across.

## What I'd need from you, only if you hit it

- **A fit or state that doesn't land in the running room.** Tell me which node and which state, and I'll fix it in the builder and re-export. No new design.
- **The raceway:** confirm the waypoint change works, or say if you want the inlet moved instead.
