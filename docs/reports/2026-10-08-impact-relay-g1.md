# G1: the Impact Relay — one enemy-free room on the G0 machine

*Prod — 2026-10-08. The second gate of the post-D crew plan. It builds
Dess's approved brief, D-18 v2 (`docs/D18_IMPACT_RELAY_ROOM_BRIEF.md`,
`21cc00a4` on `claude/chatgpt-share-link-review-77kk2l`), on the G0 lab.*

- **Branch:** `review/impact-relay-g1`, from G0 (`c45086e1`).
- **Build:** ``a3b59c46``.
- **References, untouched:** G0 (`review/impact-lab-g0`, build
  `3337769d`) and readable D (`review/crossing-d-readability`, build
  `bb683ce0`).
- **Not merged.**

## What a player gets

One freight hall and the rooms around it, with no enemies. You arrive on
a glass-fronted gallery 4.5 m up. Across the hall:
- an orange-banded steel shutter seals a doorway in the north wall;
- beside it, a window shows the Check (a stand-in) on a low dais;
- halfway down, a blue-trimmed floor plate faces the shutter with a
  light plastic tote on it;
- a dark green line runs from the plate to a lever at the stair's foot;
- off to the right, a squat steel weight with a handle stands on its
  stand.

Pull the lever and the plate wakes. It hums, ticks up for 0.6 s and
throws the tote into the shutter. The tote bounces off: a dull knock and
"NEEDS A HEAVIER HIT". Carry the weight over, set it down and step back.
The plate throws it, the shutter breaks into slabs, and the vault's light
floods the hall.

Beyond the shutter:
- the dais and the Check;
- the onward door;
- a latch that opens a corridor outside the hall, which climbs back up
  to the gallery. From the gallery side, that door stays shut and says
  "OPENS FROM THE OTHER SIDE".

A ledge high in the north-west corner holds a second stand-in that only
the swing tether reaches. The tether is equipped from the start and works
on any surface, everywhere.

**Second launch mode, heavy-hit.** The same room, plus the Braided Lash
on F. It is an Echo that already exists in the game's test campaign
(`act_lash`, 14 per hit), copied verbatim, not invented. Three lashes
wear the shutter open (40 → 26 → 12 → broken), with the plate never
powered. This is the skip the rated rule allows. D-18 v2 §7.5 asked for
this mode only if such an Echo existed, and one does.

## How the design was settled

1. **I started G1 from D-18 v1 while v2 was being written.** At v1's
   numbers (17 m, 45 kg, a 12 kg crate) I measured two things that agree
   with v2's own reasoning:
   - the long throw works, 40 of 40;
   - energy alone could not keep v1's crate from breaking the shutter.
     At 13 m/s the 12 kg crate brought 1,026 J, a 41-point blow.
2. **When v2 was approved, I rebuilt to it.** v2 sets the 11 m throw,
   the 36 kg weight, the 4 kg crate and the cumulative 40 HP shutter, as
   the owner directed. None of v1's room survives in the build; only
   these measurements are kept.
3. **Every v2 number is G0's own:**
   - the plate (2.0 m, 0.6 s arming, 1.0 s re-arm, one throw per arrival);
   - the flight (1.0 s, 11 m);
   - the shutter (40 HP, 12 per blow, 25 J per HP).

   `ImpactLabParts` is unchanged, and so is the G0 lab: its own check
   still passes 33 of 33 on this branch.

## Measured (`godot/tests/impact_relay_check.gd`)

| Case (D-18 v2 §4 and §7.4) | Result |
|---|---|
| Lever first: the crate | Thrown 0.55 s after the pull. **Refused:** 11.0 m/s, 242 J, a 9.7-point blow against the 12 needed. Shutter at 40/40. |
| The weight | **One blow breaks it:** 11.0 m/s, 2,178 J (2.2× the 1,000 J break). 40 of 40 seeded set-downs, ±0.6 m and any yaw. Strikes land −0.51…+0.59 m across and −0.16…+0.24 m up from the centre. 0 double throws. 0 weights out of reach. |
| **Crate and weight on the plate together** | Thrown one at a time, oldest first: the crate, then the weight 1.0 s later. The weight still arrives at 2,178 J. 11 of 12 seeded pairs broke the shutter. In the 12th, both bodies ended reachable for a retry, which is the outcome v2 accepts. |
| Weight first, then the lever | On the unpowered plate: a dud, and it stays. The lever arms it and it is thrown. |
| **A `lightened` weight** | Overshoots, misses, and settles by the shutter's foot (z ≈ −11.6), reachable, in 3 of 3 placements. v2 calls this legal; it is not patched. |
| **A player in the arc** | Within about 2 m of the plate the weight hits the player's chest (0.64 m centre to centre). It falls short, does **no damage**, and lands reachable. Further out, the arc passes over a standing player's head. |
| The menu mid-flight | The weight holds in the air (0.000 m moved), then flies on and breaks the shutter. |
| **Sightlines** | Gallery eye (0, 6.1, 7) to the Check: the line crosses **only the window's glass**. At the window, E reaches nothing and a shot stops on the glass, so the Check can't be claimed through it. |
| The loop | The gallery-side door does not open from the gallery. The latch, inside the vault, opens both ends. The corridor is walked back up to the gallery. |
| RESTART | Everything comes back: unpowered, line dark, lever OFF, shutter whole, weight on its stand, crate on the plate, loop latched, the Check unclaimed. |
| **The ledge** (base kit) | Unreachable. The weight and crate stacked plus a jump is 2.29 m, against the ledge's 5.0 m. The nearest stair tread high enough is 12.5 m from it; a running jump covers under 4.7 m. |
| The ledge (tether) | Reached: hook the roof in front of it, let go above it. Its stand-in is found, and stepping off lands unhurt. |
| **Swing everywhere** | 480 swings: 10 spots (floor, gallery, stair, vault, dais, corridor low and high, ledge, arrival, NW floor) × 16 headings × 3 elevations, with the loop open. All 480 caught; **all end inside the room**. The highest point reached is 6.0 m. |
| Recovery | Out of the hall and the vault, or under the floor, the weight comes home to its stand and the crate to the plate. A weight in the vault stays there. |
| Jittered throws | 30 throws at ±10 % speed: all broke the shutter, and every rest point was reachable. |
| Pulse | Refused (6 per shot, three tested), at no cost to the shutter. |
| Isolation | The bridge client is isolated, no enemies, and the stand-ins send nothing. |

**The probe** (`make godot-impact-relay`) runs both modes with a stand-in
bridge listening:

| | Source tree | Exported Linux | Windows `.exe` under Wine |
|---|---|---|---|
| Default mode, live check | **80 ok, PASS** | **80 ok, PASS** | **80 ok, PASS** |
| Heavy-hit mode, live check | **4 ok, PASS** | **4 ok, PASS** | **4 ok, PASS** |
| Bridge connections (15 s as launched, plus the whole check) | 0 | 0 | 0 |
| The player's three files | byte-identical | byte-identical | byte-identical |
| Control (an ordinary launch connects) | yes | yes | yes |

## Feedback and sound (D-18 v2 §6)

Everything comes from the existing procedural bank; there are no new
audio assets. G0's wiring of the shot, footsteps and hit tick to the
game's sound, the correction to Crossing D's silence, is kept.

| Moment | Sound | Look |
|---|---|---|
| Lever on | clunk, then a rising cue | The line lights end to end; the sign flips POWER OFF → POWER ON. |
| Plate powered | **positional hum** from the plate | Chevrons lit. |
| Arming (0.6 s) | four rising ticks | The chevrons ramp up. |
| Throw | thump | Flash. |
| Unpowered (dud) | denied click | Flicker. |
| Refused blow (failed impact) | dull knock | Seam flash; "NEEDS A HEAVIER HIT". |
| Accepted blow (wear) | heavier clang | The seams stay brighter. |
| Break | crash and a rising cue | Slabs fall; the vault's light floods the hall. |

## Art (Arty)

**Nothing of Arty's new work is integrated.** Batch 064 is a candidate
under review, and I fit-checked it from its GLBs:

| Piece | Fit-check |
|---|---|
| `ca_launch_cradle` | Built for the player's `LaunchPad`, at 2.4 × 2.4 m. The approved plate is 2.0 × 2.0 m, so it **doesn't fit as is**. Its grammar matches the plate's states: fins for power, rails, a tray kick on the throw. Its rear power housing matches the raceway. It has no arming pose. |
| `ca_breakable_brace` | Cover height, 1.5 × 1.4 × 0.9 m. The shutter is 3.0 × 3.0 × 0.4 m, so it **doesn't fit**. Arty asked whether a full-height variant is wanted; for this room, yes. |

The plate, shutter, weight and crate are placeholders. The weight has a
carry handle and the crate is an open-sided tote, so each looks its mass,
as v2 §6 asks. The lever and raceway are her kit, as in D.

**Footprints and states for her, unchanged from G0:**
- **Plate:**
  - 2.0 × 0.25 × 2.0 m, aimed by its chevrons;
  - states: dark, powered, arming (0.6 s), throw, dud;
  - power arrives at its west face.
- **Shutter:**
  - 3.0 × 3.0 × 0.4 m, struck face south;
  - states: intact, wear (`hp`), refused flash, break (slabs that
    collide with the world only).
- **Weight:** 0.45 × 0.6 × 0.45 m, 36 kg.
- **Crate:** 0.5 × 0.36 × 0.5 m, 4 kg.

## Proof, and what was not proved

**Unchanged and re-run on this branch:**
- G0's lab check, 33 of 33;
- `make godot-boot` and `make godot-import`;
- the Python suites: 2,142 pass.

**One Python test fails here, and fails identically on G0's head:**
`test_packaging.py::test_every_bundled_binary_is_first_party_or_licensed`.
The candidate kit's tracked binaries (`godot/candidate/crossing_kit/`,
since the readability pass) are not in its registry. It is not G1's, and
I left it alone; registering Arty's candidate files is a decision about
her candidates.

**The delivery** is
`Archipepsi-Impact-Relay-a3b59c46-windows-part1of2.zip` and `part2of2`
(19.5 and 20.0 MB). It is the same format as G0's.

**Condi's tools:**
- Stamped with an `archipepsi-build.json` from
  `tools/impact_relay/build-spec.json`, using his
  `archipepsi_build.py` (run from his branch, not merged).
- His `validate --strict` passes all three packages: Windows, Windows in
  two parts, and Linux.
- His launcher library installs the two parts as one build. It joins
  them, checks the executable's sha256 and lists both modes, with "Impact
  Relay" recommended.

**Fresh-folder Windows test, under Wine:**
- both zips are unzipped into a new folder whose path has spaces;
- double-clicking "1 - START HERE" joins the game; its sha256 is
  `66c9fabb…`, matching;
- it starts the room, which is still running at 60 s;
- "2 - … heavy-hit mode" starts the heavy-hit banner;
- 0 connections.

**Pictures and a clip, in the review zip (not in the repository):**
- `shots/`: 15 views in real states, from the gallery's first view to
  the ledge;
- `contact-sheet.png`: all 15 on one page;
- `Impact-Relay-run.mp4`: 22 s of a first-person run by real input,
  recorded by the engine, with its sound.

**Not proven:** whether it is fun, and native Windows. Nobody has played
it by hand.

## Next owner question

Play it with the sound on, then answer D-18 v2's card (§9). The three
that matter most for G2:
1. When the crate bounced off, did you know what to try next?
2. Did the lever, the plate and the shutter feel like one machine?
3. Did coming back by the loop feel like the room had changed?

## Stopped here

- No merge.
- No Shunter or other enemy.
- No campaign, generator or schema change.
- No change to G0's parts.
- No watchers, subscriptions or check-ins.
- Still held: HB-F4g, HB-F4f, the CK9-F1 sweep, and 0.5.
