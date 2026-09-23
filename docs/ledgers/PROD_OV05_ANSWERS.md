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

## What is proved, and how (evidence classes kept apart)

- **Real input and world effect.** The drivers press `interact`,
  `move_forward` and `fire_pulse` on the real `Player`, through real
  collision.
- **Declared harness steps.** A shielded Bulwark is removed through the
  damage path from behind when the base-kit flank does not land (P5-7).
  A second, wrong crate is placed to test refusal. The destroyed case
  frees the body. The LIGHTENED applicator is placed in the home room.
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
- **The three minors (O05-06).** Each needs a space no composed room
  offers without shrinking it. They remain standalone launchers.

## Where to look

- `docs/ledgers/PROD_OV05.md`: every row, finding and shared-seam edit.
- `docs/AGENT_FRONTIER.md`: the frontier head.
- `<save folder>/candidate/<zone>.json`: what the profile did to each
  Zone, and whether it was re-certified.
