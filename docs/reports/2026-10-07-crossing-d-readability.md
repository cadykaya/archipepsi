# Crossing D: the readability pass

*Prod — 2026-10-07. A presentation pass on the delivered Crossing D. Arty's
candidate floor lever and power-line pieces replace D's own, and their
visible states are tied to the real mechanisms.*
- **Branch:** `review/crossing-d-readability`, from the delivered D
  (`4462be29`). D stays unchanged on `wip/crossing-d-review` as the
  reference.
- **Fit:** her mapping for D (2026-10-07).
- **Build:** `bb683ce0`.

## How to play it (Windows)

1. Unzip **both** zips (`...-windows-part1of2.zip` and
   `...-windows-part2of2.zip`) into one **new, empty folder**.
   - The single zip (39.7 MB) is over the chat's upload limit.
   - The engine alone compresses to about 32 MB, so this build cannot
     travel there as one zip.
2. **First, double-click `1 - START HERE - Crossing D, NO ENEMIES
   (Windows).bat`.**
   - On its first run it joins the two parts into the game and checks
     the joined size.
   - It then starts the Crossing with the Upper Yard empty.
3. Then, for the fight, run `2 - Crossing D, with enemies (Windows).bat`.

The README in the folder has the controls and a short change and
limitation note. There is nothing to install. Windows may warn about an
unsigned program: choose "More info", then "Run anyway".

## What changed: the look only

**Both levers are Arty's floor lever** (`ck_floor_lever`).
- It shows:
  - stencilled ON / OFF on the head;
  - a neutral handle that rests at OFF (right) or ON (left);
  - a pilot on the pedestal, flat and dim until the lever has latched,
    then upright and lit.
- It is her 2026-10-07 repair, drawn over D's three colliders volume for
  volume. The foot, pedestal and head are D's boxes, and its hinge is
  D's arm pin. The colliders themselves stay D's, and the kit's own
  collision twins are dropped on load.
- **The gate lever turns to face the yard**, where the player pulls it
  from. D's faced the wall across a 0.75 m gap, too narrow to stand in.
  Its colliders are square and centred, so nothing it blocks or is
  reached by moves. The check asserts this as world boxes.

**The five power lines are Arty's raceway.**
- **The fittings** (turn, inside corner, terminal) are taken from her
  kit.
- **The straights** between them are built in code to the kit's own
  profile: carrier, square pipe, a 4 cm state stripe, and saddles at most
  a metre apart. Her mapping asks for this, because D's runs are any
  length.
- **The placements are hers**, worked out from D's own constants; the
  builder here reproduces them piece for piece:

| Line | From | To |
|---|---|---|
| plate | the plate's side | into the bridge's near housing |
| lock | the lock lever's rear gland, round behind it | into the far housing |
| power | the socket, to the wall and up it | along it at 4 m, to a terminal beside the glass door's jamb |
| power_hall | through the wall, back to back with it; down and across the pocket by the shaft | up the shaft's west block, to a lamp facing the door |
| gate | the gate lever's rear gland, straight back to the wall and up it | along it, to a terminal beside the gate's jamb |

## The look follows the mechanism

| What you see | What drives it |
|---|---|
| A lever's handle | The lever's own arm. The kit's hinge copies it every frame, so the throw animation, a pause mid-throw and a restart all show. |
| A lever's pilot (upright, lit) | The lever has latched what it controls (`locked`). |
| The plate's line | The plate is held (`plate.satisfied()`). It goes dark again when the cell is lifted. |
| The lock's line | The bridge is locked down (`bridge_locked`). |
| The socket's line and the door's lamp | The cell is installed (`powered`). |
| The hall's line, its wall box and the lift's lamp | Power is restored (`powered`). |
| The gate's line and its lamp | The gate lever is thrown, and the gate opens. |

Every state mesh (a stripe, a fitting's core, a terminal's lens, a pilot)
wears one of two materials: D's idle green, faint, or its live green,
emitting. Nothing is lit by anything but its own source.

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
- Every check D had appears verbatim in this build's logs.
- **Empty yard:** apart from the 9 new checks below, D's log and this
  one match line for line.
- **Populated yard:**
  - the fight's notes (enemy positions, telegraph and hit counts) vary;
  - they vary in the same way two runs of D vary from each other: D
    twice gave melee hits 5 then 8, and charger charges 5 then 4.

## Verification (exact scope)

**The existing live check** (`godot/tests/crossing_d_check.gd`), extended
rather than replaced: 148 checks populated (D: 137) and 114 empty
(D: 105). The new checks read back what the pass shows:
- **The kit is on every lever and line, and adds no collision:**
  - the kit on both levers and all five lines (34 lit-able pieces);
  - no kit piece collides;
  - each lever's colliders are D's three boxes where D had them.
- **Each line and lever shows its mechanism:**
  - everything dark and at OFF at the start;
  - the plate's line alone is lit while the plate is held, and goes dark
    when the cell is lifted (the lock's stays lit);
  - the lock lever and the gate lever show ON with their pilots lit;
  - the socket's and the hall's lines are lit after the install;
  - in the quick carry, the never-pulled lock's line stays dark.
- **Pause and restart:**
  - **the menu opened mid-throw holds the handle still** (−29°, for 30
    frames), and the throw goes on once the menu is closed;
  - **after RESTART every line is dark and both levers are at OFF.**

**Where it ran:** the source tree, the exported Linux build, and the
Windows executable under Wine (`tools/crossing_review_probe.py`, with
`--exported` and `--wine`).

**Isolation, all three builds** ([the evidence below](#evidence)):
- 0 connection attempts to a stand-in bridge, both as launched (15 s)
  and through the whole check;
- the player's three files byte-identical, and no new file;
- the control connects.

**Affected suites:**
- `make godot-import` (the CI gate);
- the 663 Python tests that scan the Godot scripts and tests: all
  passed.
- No full frontier: the change touches only Crossing D's own files, the
  candidate folder and the packaging.

**Renders** (a scratch harness, not committed):
- every lever and line, off and lit, at player height;
- every joint and terminal close up;
- long views across the Machine Hall and the Central Hall.
They show every piece seated on its surface, with no gaps and no
floating runs.

**Not played by hand, and not run on Windows itself.**

### Evidence

On build `bb683ce0`, both yards:

| Build | Live check | Connection attempts | Player files |
|---|---|---|---|
| Source tree | PASS, 148 / 114 | 0 | byte-identical |
| Exported Linux | PASS, 148 / 114 | 0 | byte-identical |
| Windows under Wine | PASS, 148 / 114 | 0 | byte-identical |

The Windows double-click is simulated under Wine 9.0: both zips are
unzipped into a fresh folder whose path has spaces, then the NO-ENEMIES
launcher is started. Result:
- the joined executable is byte-identical to the single build's
  (SHA-256 `f070ed5c…`), and the parts are removed;
- the Crossing starts in the empty-yard mode and is still running at
  60 s, rendering the arrival under Vulkan Forward+;
- then the with-enemies launcher, and the executable itself, start the
  populated yard;
- 0 connection attempts throughout.

**One test change.** The control in `tools/crossing_review_probe.py` (an
ordinary launch must connect, proving the listener hears a client) now
waits 20 s instead of 8.
- On this machine an ordinary launch first reaches the bridge 7.6–10.3 s
  in. That holds for D's tree (7.6 and 9.2 s) and for this branch's (10.3
  and 8.9 s) alike.
- At 8 s it failed the exported probe's control once.
- The review build's own zero-connection windows are unchanged.

## Limitations (named, not fixed)

**Nothing needed substantial repair, and no fit changed gameplay**, so
no part stayed at D's look. Arty's lever repair removed the one fit
problem the first trial had: 18 cm of invisible collider round a
shallower head. These remain:

1. **The raceway does not collide**, as D's lines did not, so feet pass
   through its 13 cm.
   - Two legs cross a walking line: the plate's, by the bridge's near
     end, and the lock's x −19.4 leg, by the far end.
   - Arty's manifest offers a code-side box no taller than the run, which
     the player would step over.
   - That changes collision, so it is left for a decision.
2. **The 4 cm stripe is faint at distance.** It reads clearly at 5–10 m.
   From the Machine Hall's entrance, about 20 m from the far side, the
   lock's line is barely a pixel lit or not. This confirms Arty's own
   flag 1; the fix is her source constant, not changed here.
3. **The hall side of the wall uses a terminal as the box the line comes
   out of**, as her mapping places it. The kit has no wall-penetration
   fitting.
4. **D's status labels and signs stay:** PLATE / DOOR / LIFT / GATE ON
   or OFF, and the billboard signs, beside the terminals' lamps.
5. **Candidate art.** The kit is Arty's PROPOSAL, still in review and not
   in the content pack. It ships as candidate art in a candidate build
   only, with no palette migration and no library merge.

## With Arty, through the handoff

**Her handoffs:** `docs/art/reports/2026-10-02-crossing-readability-kit.md`
and `2026-10-07-crossing-d-kit-mapping.md`, on her branch at `9ae04155`.
Her mapping arrived at 19:33 UTC, while the first fit (`903bfa49`, my own
placements and the old lever) was being verified. The pass was then
refitted to her mapping. No file of hers is edited.

**Taken, byte for byte, from `9ae04155`:** `ck_floor_lever` (repaired),
`ck_raceway_turn`, `ck_raceway_inside` and `ck_raceway_terminal`, with
`manifest.json`.
- They sit at the same path, `assets/models/batch063/crossing_kit/`, so a
  later merge of her branch meets identical files.
- They ship through `tools/crossing_d/import_kit.sh` into
  `godot/candidate/crossing_kit/`. That folder is generated and sits
  outside `godot/content/`.
- **Not taken:** `ck_raceway_run` (the straights are code, per her
  mapping), `ck_raceway_outside` (no route goes over an edge), and the
  accents (not asked for).

**Her flags, answered:**
1. The stripe at distance: confirmed thin across the Machine Hall
   (above). Her call.
2. The gate lever faces the wall: turned.
3. D's lift line ended on open floor: fixed by her placements.
4. D's gate line ran up the gate opening: fixed by her placements.
5. D's lock line ran under the player's feet: fixed by her placements.
6. No conduit collides: left as it is; named above.
7. The pale-green EXIT signs and beacon: unchanged. This pass is no
   palette migration.
8. The green lever handles: gone, since the kit's handle is neutral.
9. The accent-blue lift deck and bridge: unchanged. This pass is no
   palette migration.
10. The fixed green ON stencil: as built.

**One wiring difference from her table:** the lever's pilot uses the
lines' idle material (glow 0.08) rather than 0.06, so every state mesh
shares one pair of materials. The difference cannot be seen.

## Correction to D's notes

D's report (conflict 10) and the frontier said Arty's kit had not
arrived.
- That was true when I checked, but the kit was pushed at 06:01 UTC on
  2 October (`eb8fceda`, `7e1f9677`), an hour before D's build commit
  (`0cf577c6`, 07:00).
- D's report is left as D's record. This pass is where the kit is used.

## Not done, by the brief

- No campaign merge, no new systems, no palette migration, and no
  watchers or scheduled check-ins.
- Still held: HB-F4g, HB-F4f, the CK9-F1 sweep, and 0.5.
