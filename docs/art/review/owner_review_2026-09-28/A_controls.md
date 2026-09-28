# A · Controls and machinery feedback (028, 043, 049)

*Arty — 2026-09-28*

**Three generations of controls, kept apart:**
- **028:** the older primitive kit, revised in place at 035-R.
- **043:** addressable machinery. Its wall switch has a real hinge.
- **049:** the connect kit. It *extends* 043 and does not replace it.

The review asks what tells the player they are holding something, setting
it, or changing it for good. It doesn't invent any runtime support.

## Look at

1. [`sheets/A1_controls_commitments.jpg`](sheets/A1_controls_commitments.jpg):
   - Production's current lever, pressure pads and switch posts, as its own
     drivers photograph them;
   - the 049 paddle, dial and seal;
   - the 043 switch, off and on;
   - the older 028 switch post and weight plate (a new render: their only
     other images predate 035-R).
2. [`sheets/A2_machine_state_language.jpg`](sheets/A2_machine_state_language.jpg):
   the 043 conduit band's five states, the 049 fittings that carry it, the
   destination powered and unpowered, and the relationship plaque.

The connect frames were re-rendered tonight. Their textures were re-baked
on 24 September, and their geometry is unchanged (checked).

## Decide

1. **One silhouette per commitment** (momentary, reversible, permanent),
   starting with the **permanent** control that D-07 already asks for:
   > "Pressure plates are held sensors [...] use a visibly different
   > permanent control such as a lever, locking bolt [...] The existing
   > latch machinery can absolutely be reused underneath."
   > (owner, 24 Sept; `prod@c12a72f:godot/scripts/generation/room_graphs.gd:250-255`)
   - *Recommend:* yes, permanent first. Use a lever that visibly locks, or
     the 049 seal.
   - *Risk:* the 049 tells (spring, teeth, tabs) are hand-scale. 035-R
     ruled that a distinction has to live in the object's silhouette.
2. **"Held" means plates.** Production has no hand control you hold down.
   - *Recommend:* recaption the 049 paddle as a **momentary** control,
     matching Production's lever, which springs back in 0.35 s.
   - Keep "held" for plates: the 028 weight plate plus a sign.
   - Plate sizes differ: 0.96 m in art, 1.4 m and 2.4 m in Production.
3. **Machine state as one family:** the 043 band plus the 049 fittings.
   - *Recommend:* approve it as a candidate vocabulary.
   - Use 043's node contract (a hinge, and `how_to_drive` in its manifest)
     as the baseline.
4. **Cross-room identity:** a world plaque, the map's circuit colour
   (H-CIRCUITS), or both?
   - *Recommend:* settle H-CIRCUITS first.

## Older versus revised

| Function | Older (028) | Revised (043) | Extension (049) |
|---|---|---|---|
| a switch or setter | `int_wall_switch`, a floor post; recolour only | `mach_wall_switch`, a wall lever on a hinge (not declared as superseding 028) | `conn_set_dial` (overlaps; not declared) |
| a held sensor | `int_weight_button` (0.96 m) | — | `conn_hold_paddle` (a hand paddle) |
| a receiver or result | `int_logic_indicator` | `mach_receiver_lamp`: agree / disagree | `conn_reader_panel` (4 state nodes, no "refused"), `conn_flag_ack`, `conn_breaker`, `conn_gauge` (one pose each) |
| routing | — | `mach_conduit_run`: the five states | `conn_run_elbow`, `conn_run_tee`, `conn_junction_box`, `conn_wall_pass` |
| permanent repair | — | — | `conn_repair_seal` (tabs to hide) |
| identity and context | — | — | `conn_id_plaque` (blank field), `conn_relay_cabinet`, `conn_service_stack` |

**Paths:** `assets/models/batch028/interaction/`,
`assets/models/batch043/machinery/`, `assets/models/batch049/connect/`.

## Status, kept apart

- **Visual approval:** none.
  - 028: PENDING (`docs/art/ART_REVIEW.md:3412`).
  - 043: the pending band (`ART_FRONTIER.md:1299`).
  - 049: PENDING, 22 Sept (`ART_REVIEW.md:4562`).
- **Technical compatibility:**
  - 043 can be driven (a hinge and `how_to_drive`).
  - 049 has named parts but no pivots, poses or colliders.
  - 028 can only be recoloured.
- **Runtime binding:** none.
- **Normal gameplay:**
  - Held plates and the warp-station repair are in play, as code-built
    placeholders.
  - The permanent lever and the reversible setter exist only in the opt-in
    candidate profile (`prod@c12a72f:bridge/archipepsi_bridge/candidate.py`,
    off by default).

## Engineering after (not the art judgement)

- Pivots and declared poses for the 049 moving parts.
- Colliders.
- A placement contract: Production's levers stand on the floor, and this art
  mounts on walls.
- A visual driver on the signal graph.
- Something that fills the plaque's id field.
- Audio for the delayed state.

## Found tonight (nothing repaired)

- **The 049 moving parts have no pivots.** `paddle_arm`, `seal_lever`,
  `dial_pointer` and `gauge_needle` sit off their origin with identity
  transforms, so rotating one swings it about the floor or wall point. The
  "two declared positions" exist only in the builder's docstrings.
  - *Smallest repair:* apply 043's `_hinge` to the six moving parts,
    declare their poses in the manifest, and render the second pose.
- **A reserved colour in the evidence.** `MACH_switch_disagreeing.png` lights
  the receiver lens in hazard orange `#e8541f`
  (`tools/content/machinery_preview.gd:314-315`), although the README says no
  reserved colour is used.
  - *Repair:* re-shoot with a non-reserved value. It is left out of the
    sheets.
- **The 028 records disagree.** The table in `batch028/README.md` still has
  the numbers from before 035-R, and its two sheets were never re-rendered.
- **Pack levers.** Four theme-pack levers cite 043's wall-switch contract but
  have no hinge node. This is outside this group, and only flagged.
