# Overnight 05 — answers to the route (spoilers)

Companion to `PROD_OV05_ROUTE.md`. Room ids are the played Zone's
(`zone_001` of a fresh candidate slot, mock multiworld, default scale,
deterministic Epsilon). Another seed composes other rooms. The
relationships are the same, or a step declines and says so in
`candidate/<zone>.json`.

## What each thing is

| where | what you meet | what it does | evidence |
|---|---|---|---|
| c002 (the first arena) | a lever, `SPAN_ALIGNMENT` | Pulling it with `E` shows `PENDING` at once. `ACCEPTED` follows when the bridge's snapshot carries the new value. The doorway into c003 opens, and the lamp **in c003** lights. Pull it again and the doorway closes. If you stand in that doorway while it closes, it says `CLOSING QUEUED · DOORWAY OCCUPIED` and waits for you to step out | `godot-reversible` 32/32; `godot-reversible-live` (restart) OK |
| c004 (the corner past the platform path) | a glowing 40 kg **power cell** | Pick it up with `E`. It is MEDIUM, so you walk at 0.85 speed. While you hold it you cannot fire the Static Pulse or use the mobility slot | `godot-carry` 32; `godot-transport` 106/106 |
| c005 (the arena after it) | a socket | `E` while aiming at it installs the cell. Being in the room with the cell does nothing. The doorway into c006 opens and both lamps light. The install is recorded as the delivery; a message saying the same thing is refused | `godot-transport`; the live suite repeats every refusal against the real bridge |
| c009 | P14's plate (the last batch) | Standing on it latches the shutter across `e:c009:c010` open, permanently | P14's own suites; built and shut in `godot-candidate-live` |
| c024, through c015's side doorway (c005 → locked door → c014 → locked door → c015) | **Unweighted Switch (EX50-033)**, the minor room itself, with c015's Check moved onto its gallery | The sill is out of reach. The SERVICE DRIVE puts the crate in the recess as a step, and that shuts the crossing, because the recess floor is a HEAVY plate. Shoot the applicator: the crate goes LIGHTENED (lighter by class, never by kilograms), the plate lets go, and the crossing opens. Climb, cross, pull the HOLD-OPEN BOLT, claim the Check. After a restart the bolt still holds the crossing, even with the crate back on the plate | `godot-candidate-live` phases `minor` 16 and `minor_restore` 10; `godot-unweighted` 61 (the development room) |

## Things to try, and what should happen

- **Drop the cell outside where it belongs** (walk it back past its
  home and off the run). It returns home after 1.0 s, not sooner. Carry
  it back within the second and nothing happens.
- **Destroy it or lose it off the map.** Destroyed, it is back after
  2.0 s as the same object. Out of bounds, it is back at once.
- **Die while carrying it.** It falls where you held it and stays there.
  Death is not a recovery.
- **Put it down halfway, then quit and restart both.** It is where you
  left it, and there is exactly one.
- **Install it, then quit and restart.** It is seated, the doorway is
  open before you reach it, and nothing is announced again.
- **Leave the lever lowered, then quit and restart.** The doorway is
  open at load, and you do not have to touch the lever.
- **In the minor: claim the Check, then quit and restart.** The Check is
  still claimed. The crate is back in parking and LIGHTENED is gone,
  because both are deliberately forgotten. The bolt is not forgotten:
  drive the crate back onto the plate and the crossing stays open.

## What is proved, and how (evidence classes kept apart)

- **Real input and world effect.** The drivers press `interact`,
  `move_forward` and `fire_pulse` on the real `Player`, through real
  collision.
- **Declared harness steps.** A shielded Bulwark is removed through the
  damage path from behind when the base-kit flank does not land (P5-7).
  A second, wrong crate is placed to test refusal. The destroyed case
  frees the body. The LIGHTENED applicator is placed in the home room.
  In the two minor phases, the player is placed at c015's arrival
  instead of walking there past P14's plate and two locked doors.
- **Authoritative state.** Python holds the room, the pose, the
  consumption and the lever's value. Every forged intent is refused by
  name, both in bridge tests and live.
- **Restart.** A new bridge process and a new client each time, on a
  disposable save that is read back off the disk.
- **Not claimed.**
  - A live model was never used; the deterministic fallback composed
    everything.
  - A real multiworld was never used; the multiworld is the mock.
  - Nothing was executed on Windows. The `.bat` delegates every decision
    to `archipepsi_bridge.diagnostic`, which is tested.

## Blocked, and why (the one-line version)

- **Blindside / the featured Echo (O05-05).**
  - A featured Check can hold your own item, and that mints no Echo.
  - Nothing makes the Echo actually supply the function.
  - Archipelago has no pre-seed rule for the gate.

  Each of these is a policy, not code. The details are in
  `PROD_OV05.md`.
- **Two of the three minors (O05-06).** Unweighted Switch is now in the
  candidate Zone. Passing Platforms needs its carriers' poses saved
  (EX50-011 §9). Counterfire Arcade needs its gunner to be the Zone's
  own enemy (EX50-021 §9). Both are still standalone launchers; see
  `PROD_OV05.md`.

## Where to look

- `docs/ledgers/PROD_OV05.md`: every row, finding and shared-seam edit.
- `docs/AGENT_FRONTIER.md`: the frontier head.
- `<save folder>/candidate/<zone>.json`: what the profile did to each
  Zone, and whether it was re-certified.
