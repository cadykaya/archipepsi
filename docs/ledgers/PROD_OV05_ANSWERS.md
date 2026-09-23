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
| c025, through c020's side doorway (c002 → c018 → c020) | **Counterfire Arcade (EX50-021)**, with c020's Check moved onto its upper flank | A gunner covers the lane from the gallery; it is the Zone's own enemy. Stand in the lane, let it fire, and step into the alcove: its shot carries on and trips the hooded receiver, which opens the service shutter for eight seconds. Run the route to the flank and pull the SERVICE RELEASE, and the shortcut stays open for good. Claim the Check. With the gunner dead, the west stair and a Static Pulse at the receiver's face still work | `godot-candidate-live` phases `minor` and `minor_restore`; `godot-counterfire` 44 (the development room) |
| c024, through c015's side doorway (c005 → locked door → c014 → locked door → c015) | **Unweighted Switch (EX50-033)**, the minor room itself, with c015's Check moved onto its gallery | The sill is out of reach. The SERVICE DRIVE puts the crate in the recess as a step, and that shuts the crossing, because the recess floor is a HEAVY plate. Shoot the applicator: the crate goes LIGHTENED (lighter by class, never by kilograms), the plate lets go, and the crossing opens. Climb, cross, pull the HOLD-OPEN BOLT, claim the Check. After a restart the bolt still holds the crossing, even with the crate back on the plate | `godot-candidate-live` phases `minor` and `minor_restore`; `godot-unweighted` 62 (the development room) |
| **zone_002** (abandon zone_001 from the pause menu, then take the portal twice): c025, through c015's side doorway | **Passing Platforms (EX50-011)**, with c015's Check moved onto its goal gallery G | A lift (V) rises from arrival A to a shelf and pauses at the transfer height; a shuttle (H) crosses at that height to G. Neither reaches G alone. Fast: call H east at A, board V, LAUNCH, and step across during V's pause as H passes. Patient: call H, STOP it beside the lift from A, ride V up and step onto the stopped H, then H ON EAST from its own deck. Walking onto G releases a service stair down to A for good. RESET at A (or on the shelf) calls both home, by motion. Quit with H stopped halfway and restart: it is exactly where you left it, still stopped | `godot-candidate-live` phases `next`, `next_restore` and `next_final`; `godot-passing-platforms` 70 (the development room) |

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
- **In the arcade: pull the release, then quit and restart.** The
  shutter is open before you get there and stays open; the gunner is
  back, because enemies are the encounter's, not the room's.
- **In the minor: claim the Check, then quit and restart.** The Check is
  still claimed. The crate is back in parking and LIGHTENED is gone,
  because both are deliberately forgotten. The bolt is not forgotten:
  drive the crate back onto the plate and the crossing stays open.
- **In Passing Platforms: stop the shuttle halfway, then quit and
  restart.** It is where you stopped it, still stopped, and it does not
  move until you tell it to. A lift you quit in the middle of its pause
  comes back held at the transfer height; LAUNCH sends it on to the
  shelf. A carrier you quit while it was moving comes back where it
  last stood still.
- **In Passing Platforms: die before reaching G.** Both carriers go
  home, moving normally. After G, they stay where you left them, and
  the service stair means you do not need them.

## What is proved, and how (evidence classes kept apart)

- **Real input and world effect.** The drivers press `interact`,
  `move_forward` and `fire_pulse` on the real `Player`, through real
  collision.
- **Declared harness steps.** A shielded Bulwark is removed through the
  damage path from behind when the base-kit flank does not land (P5-7).
  A second, wrong crate is placed to test refusal. The destroyed case
  frees the body. The LIGHTENED applicator is placed in the home room.
  In the minor phases, the player is placed at the arrival of the
  room each minor stands behind (c015, c020; c015 again in zone_002)
  instead of walking there past P14's plate and locked doors, and
  c020's own fight is walked past (its ranged enemies are on a gallery
  the scripted fighter cannot reach). In `next`, the player is killed
  once through the damage path, to exercise EX50-011 §9's death rule.
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
- **Nothing of O05-06 is blocked any more.** All three minors are in
  candidate Zones: Passing Platforms in the second, because each Zone
  has room for two and the offer turns (a selection rule of this lane,
  recorded for Dess in `PROD_OV05.md`).

## Where to look

- `docs/ledgers/PROD_OV05.md`: every row, finding and shared-seam edit.
- `docs/AGENT_FRONTIER.md`: the frontier head.
- `<save folder>/candidate/<zone>.json`: what the profile did to each
  Zone, and whether it was re-certified.
