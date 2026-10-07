# Crossing D: the readability pass

*Prod — 2026-10-07. A presentation pass on the delivered Crossing D: Arty's
candidate floor lever and power-line pieces in place of D's own, their
visible states tied to the real mechanisms. On the branch
`review/crossing-d-readability`, from the delivered D (`4462be29`), which
stays unchanged on `wip/crossing-d-review` as the reference. The build is
`903bfa49`.*

## How to play it (Windows)

1. Unzip **both** zips (`...-windows-part1of2.zip` and
   `...-windows-part2of2.zip`) into one **new, empty folder**. The single
   zip (39.7 MB) is over the chat's upload limit; the engine alone
   compresses to about 32 MB, so this build cannot ship as one zip there.
2. **First, double-click `1 - START HERE - Crossing D, NO ENEMIES
   (Windows).bat`.** On its first run it joins the two parts into the
   game, checks the joined size, and starts the Crossing with the Upper
   Yard empty.
3. Then, for the fight: `2 - Crossing D, with enemies (Windows).bat`.

The README in the folder has the controls and a short change and
limitation note. Nothing to install; Windows may warn about an unsigned
program ("More info", then "Run anyway").

## What changed: the look only

- **Both levers are Arty's floor lever** (`ck_floor_lever`):
  - stencilled ON / OFF on the head;
  - a neutral handle that rests at OFF (right) or ON (left);
  - a pilot on the pedestal, flat and dark until the lever has latched,
    then upright and lit.
  The model stands inside D's three colliders (BASE, pedestal, foot),
  which stay as they were. The kit's own collision twins are dropped on
  load.
- **The gate lever turns to face the yard**, where the player pulls it
  from: D's faced the wall. Its colliders are square and centred, so
  nothing it blocks or is reached by moves. The check asserts this as
  world boxes.
- **The five power lines are Arty's raceway** (run, turn, inside corner,
  terminal):
  - laid on the room's own floors and walls;
  - a saddle each metre and a fitting at each corner;
  - each line ends in a terminal whose lens is the lamp of what it powers.
  The routes:

  | Line | From | To |
  |---|---|---|
  | plate | the plate's side | a terminal at the bridge's near housing |
  | lock | the lock lever's rear gland, round behind it | the far housing |
  | power | the socket | along the floor, up the wall beside the glass door, to a terminal under its DOOR label |
  | power_hall | a terminal on the hall side of the same wall | down, and across the floor to the lift tower |
  | gate | the gate lever's rear gland | straight back to the wall and up it, to a terminal beside the GATE label |

## The look follows the mechanism

| What you see | What drives it |
|---|---|
| A lever's handle | the lever's own arm. The kit's hinge copies it every frame, so the throw animation, a pause mid-throw and a restart all show. |
| A lever's pilot (upright, lit) | the lever has latched what it controls (`locked`) |
| The plate's raceway and its lens | the plate is held (`plate.satisfied()`), and goes dark again when the cell is lifted |
| The lock's raceway and lens | the bridge is locked down (`bridge_locked`) |
| The socket's raceway and the door's lens | the cell is installed (`powered`) |
| The hall's raceway, its wall box and the lift's lens | power is restored (`powered`) |
| The gate's raceway and lens | the gate lever is thrown, and the gate opens |

Each piece's `power_` nodes keep the kit's idle green until their source
is live, then take the live green and emit it, as the kit's manifest
specifies. Nothing is lit by anything but its own source.

## What did not change

- **Gameplay:**
  - the rooms, every collider, every position and every reach;
  - the puzzle and its order;
  - the enemies and where they are, HP and damage;
  - movement.
- **The Courtyard-only swing is untouched.** It remains an open review
  question, not an approved rule.
- **No new objects or activities.** The terminals are the lines' own
  ends.
- **Isolation:** the same guard as D, before any connection exists.

**The evidence is the existing Crossing D check, run on D and on this
build in both yards.**
- Every check D had passes here unchanged.
- **Empty yard:** apart from the 9 new checks below, the two logs match
  line for line.
- **Populated yard:**
  - every pass/fail line matches;
  - the fight's notes (enemy positions, telegraph and hit counts) differ
    in the same way two runs of D differ from each other: D twice gave
    melee hits 5 then 8 and charger charges 5 then 4;
  - the graze notes name the same places.

## Verification (exact scope)

- **The existing live check** (`godot/tests/crossing_d_check.gd`),
  extended rather than replaced: 148 checks populated (D: 137) and 114
  empty (D: 105). The new ones read back what the pass shows:
  - the kit on both levers and all five lines (39 lit-able pieces);
  - no kit piece collides;
  - each lever's colliders are D's three boxes where D had them;
  - everything dark and at OFF at the start;
  - the plate's line alone lit while the plate is held, and dark again
    when the cell is lifted (the lock's stays lit);
  - **the menu opened mid-throw holds the handle still** (at −29°, for
    30 frames), and once the menu is closed the throw goes on;
  - the lock lever and the gate lever showing ON with their pilots lit;
  - the socket's and the hall's lines lit after the install;
  - **after RESTART every line is dark and both levers are at OFF**;
  - in the quick carry, the never-pulled lock's line stays dark.
- **Where it ran:** the source tree, the exported Linux build, and the
  Windows executable under Wine (`tools/crossing_review_probe.py`,
  `--exported` / `--wine`).
- **Isolation, all three builds** (results: [the evidence below](#evidence)):
  - 0 connection attempts to a stand-in bridge, as launched (15 s) and
    through the whole check;
  - the player's three files byte-identical, no new file;
  - the control connects.
- **Affected suites:**
  - `make godot-import` (the CI gate);
  - the 663 Python tests that scan the Godot scripts and tests, all
    passed.
  - No full frontier: the change touches only Crossing D's own files, the
    candidate folder and the packaging.
- **Renders** of every lever and line, off and lit, and of every joint
  and terminal (a scratch harness, not committed). They show the pieces
  seated on their surfaces, with no gaps or floating runs.
- **Not played by hand, and not run on Windows itself.**

### Evidence

Results, both yards, on build `903bfa49`:

| Build | Live check | Connection attempts | Player files |
|---|---|---|---|
| Source tree | PASS | 0 | byte-identical |
| Exported Linux | PASS | 0 | byte-identical |
| Windows under Wine | PASS | 0 | byte-identical |

The Windows double-click is simulated under Wine 9.0: both zips are
unzipped into a fresh folder whose path has spaces, then the NO-ENEMIES
launcher is started. Result:
- the joined executable is byte-identical to the single build's
  (SHA-256 `460b513f…`), and the parts are removed;
- the Crossing starts in the empty-yard mode and is still running at
  60 s, rendering under Vulkan Forward+;
- then the with-enemies launcher, and the executable itself, start the
  populated yard;
- 0 connection attempts throughout.

**One test change:** `tools/crossing_review_probe.py`'s control (an
ordinary launch must connect, proving the listener hears a client) now
waits 20 s instead of 8.
- **Why:** on this machine an ordinary launch first reaches the bridge
  7.6–10.3 s in. That was measured on D's tree (7.6, 9.2 s) and this
  branch's (10.3, 8.9 s) alike, and it failed the exported probe's
  control once (0 attempts in 8 s).
- **What it does not touch:** the review build's own zero-connection
  windows.

## Limitations and blockers (named, not fixed)

**Nothing needed substantial repair, and no fit changed gameplay**, so
nothing was left at D's look. These remain:

1. **The levers keep D's colliders.** D's BASE box is 0.70 m deep, and
   the kit lever's head is 0.34 m deep.
   - From behind, the player stops about 18 cm short of the visible head.
   - From the front, the hinge and arm fill the gap.
   - Closing it would mean a new collider (gameplay) or a different
     model (Arty's lane).
2. **The floor runs do not collide**, as D's lines did not. Feet pass
   through their 13 cm.
   - Arty's manifest asks for a code-side box, no taller than the run,
     where a run crosses a walking line.
   - Adding one changes collision, so it is left for a decision.
   - The crossings: the lock line on the far side, and the plate line by
     the bridge's near end.
3. **The hall side of the wall uses a terminal as the box the line comes
   out of.** The kit has no wall-penetration fitting. Its lens lights
   with the line.
4. **D's status labels and signs stay:** PLATE / DOOR / LIFT / GATE ON
   or OFF, and the billboard signs. They now sit beside the terminals'
   lenses, saying the same thing in words.
5. **Candidate art.** The kit is Arty's PROPOSAL, still in review and not
   in the content pack. It ships here as candidate art in a candidate
   build only, with no palette migration and no library merge.

## For Arty, through the handoff

Read against `docs/art/reports/2026-10-02-crossing-readability-kit.md`
(her branch, `7e1f9677`). No file of hers is edited.

- **Taken, byte for byte,** from `eb8fceda` (identical at `7e1f9677`):
  - `ck_floor_lever`, `ck_raceway_run`, `ck_raceway_turn`,
    `ck_raceway_inside` and `ck_raceway_terminal`, with `manifest.json`;
  - into the same path, `assets/models/batch063/crossing_kit/`. A later
    merge of her branch therefore meets identical files.
  - `ck_raceway_outside` and the three accents are not taken: no route
    goes over an edge, and the accents were not asked for.
- **Shipped by** `tools/crossing_d/import_kit.sh` into
  `godot/candidate/crossing_kit/` (generated, outside `godot/content/`).
- **Fit notes for her review:**
  - **The lever contract held.** The 0.70 m foot, the ±55° throw about
    +Z and the 0–90° pilot are as stated. The rear gland at
    (0, 0.065, −0.36) is where the line leaves.
  - **The lever's gland is at the rear,** so a lever reached from the
    front needs its line routed round behind it (the lock lever). One
    reached with its back to a wall routes straight back (the gate
    lever).
  - **Corner fittings take 0.5 m of each run they join,** so two corners
    need a metre between them. Every route here keeps to that.
  - **Requests, if she wants them:**
    - a wall-penetration fitting;
    - a lever head as deep as Production's 0.70 m BASE, or Production's
      collider made shallower, which is an owner decision on gameplay.

## Correction to D's notes

D's report (conflict 10) and the frontier said Arty's kit had not arrived.
It had not when I checked, but it was pushed at 06:01 UTC on 2 October
(`eb8fceda`, `7e1f9677`), an hour before D's build commit (`0cf577c6`,
07:00). D's report is left as D's record. This pass is where the kit is
used.

## Not done, by the brief

No campaign merge, no new systems, no palette migration, no watchers or
scheduled check-ins. Still held: HB-F4g, HB-F4f, the CK9-F1 sweep, 0.5.
