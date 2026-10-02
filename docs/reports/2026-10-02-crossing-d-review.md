# Crossing D: the review build

*Prod — 2026-10-02. The playable side of one combined Crossing, built to
Dess's room brief D-17 (`docs/D17_CROSSING_D_ROOM_BRIEF.md` on the 0.4
head, `a266d5da`),
on the branch `wip/crossing-d-review`. The branch starts from the
concourse-pier branch (`6e357390`), which sits on CK14 `17b76098`.*

## How to play it (Windows)

The build comes in **two parts**, because the one zip (37.8 MiB) is over
the chat's upload limit; Wisp's studies were delivered the same way.

1. Download `...-windows-part1of2.zip` and `...-windows-part2of2.zip`.
   Unzip **both** into the same **new, empty folder**.
2. Double-click **`1 - Join the game, run once (Windows).bat`** once.
   - It joins the two parts into `Archipepsi-Crossing-D.exe`, checks its
     exact size, and starts the game.
   - From then on, double-click **`Archipepsi-Crossing-D.exe`**. That is
     the whole Crossing, with the Upper Yard's fight.
   - `Play Crossing D - no enemies (Windows).bat` runs the same four
     rooms with the Upper Yard empty. This is the first step of Dess's
     two-step order.
3. Nothing to install: no Godot, no Python and no first-run import. The
   executable carries the game inside it.
   - Windows may warn about an unsigned program: choose "More info",
     then "Run anyway".
   - `Archipepsi-Crossing-D.console.exe` is the same game with a console
     window that shows the log.

**Controls:**

| Key | Action |
|---|---|
| WASD, mouse | Move, look |
| Space | Jump |
| Left click | Static Pulse |
| E | Use, pick up, put down, install |
| Right mouse | The swing tether, in the Courtyard only (see below) |
| R | Back to your last checkpoint |
| Esc | Menu: resume, restart the Crossing, quit |

To use the swing tether, jump, then hold right mouse. Hold W toward where
you are swinging, and let go to drop.

**The route:**
1. You arrive in the **Central Hall**. The exit is at the top of the lift
   tower, and the lift has no power.
2. The **Courtyard** is on the right: launch pads and a spring up to a
   balcony and its Check, and the rail back down into the hall.
3. The **Machine Hall** is on the left: restore the power. That opens the
   glass door back into the hall and runs the lift.
4. Take the lift up to the **Upper Yard**. The exit is across it. You may
   fight, or run.
5. A gate in the Yard, opened from the Yard side, leads to a stair down to
   the hall.

The Checks are stand-ins. They mark where allocated Checks would go, and
they send nothing.

## The fresh-folder Windows check

**What was done.**
1. The Windows build was exported with Godot 4.5.1's own release
   template, the engine's free template file, so this cost nothing. The
   build is one executable with the game inside it. It was zipped as
   delivered.
2. The zip was unzipped into a **new folder whose path has a space in
   it**.
3. The game was started exactly as the instructions say. Under Wine 9.0
   (Ubuntu's own package, also free), on a 1280×720 virtual display, the
   file was opened as a double-click opens it: through ShellExecute, with
   no arguments.
4. A stand-in bridge listened on the bridge's own address the whole
   time.

**What happened:**

| Launch | Result |
|---|---|
| `Archipepsi-Crossing-D.exe` (double-click) | Started with no import step and was still running at 50 s. The engine chose Vulkan Forward+ (on software Vulkan here). The log shows the Crossing's start-up line ("populated yard; isolated"). It rendered the arrival with the HUD and the objective line, and the play timer advanced (screenshots at 20, 35 and 50 s). **0 connection attempts.** |
| `Play Crossing D - no enemies (Windows).bat` (double-click) | Same, with the start-up line "empty yard". **0 connection attempts.** |
| **The two-part delivery, as sent** | Both zips were unzipped into one new folder whose path has spaces, and the join script was double-clicked. The joined executable is byte-identical to the one tested above (SHA-256 `b0f7f4e7…`). The parts were removed and the game started. A second double-click of the executable, and the no-enemies launcher, each started it again. **0 connection attempts.** |
| The live checks, under Wine | The Windows executable itself, from a fresh unzip, ran headless under Wine with the scripted run (`tools/crossing_review_probe.py --wine`). It played the whole route by real input: **137 checks** with the fight and **105** with the Yard empty, all passing. The Yard's three enemies were put down at baseline numbers in 18 s of play. **0 connection attempts.** The player's three files were byte-identical afterwards. |

The only engine errors in these logs are two lines saying Windows audio
(WASAPI) found no output device. The virtual machine has no sound card;
a real PC has one.

**What this does not cover:**
- a real Windows PC and its graphics driver;
- Windows SmartScreen on an unsigned download;
- antivirus;
- sound.

On those, only your run will tell.

## Owned: the Concourse ZIP's first launch

The Concourse ZIP's launchers ran the source project, with no import
cache, through a Godot it found on the machine. On a fresh Windows unpack
that gave you a grey window with missing-class errors. My "clean unpack"
check had run the import first, so it never tested the launch as
written.

This build ships an exported executable instead, with the game inside
it. It was checked from a fresh folder exactly as the instructions say
(above). The Concourse ZIP itself is not rebuilt here; that was
not asked.

## What changed

**New: the Crossing.** None of this is a Zone, and no campaign ever
builds it.

| File | What it is |
|---|---|
| `godot/scripts/content/crossing_d_room.gd` | The four rooms, their mechanisms and the encounter. |
| `godot/scripts/content/crossing_d.gd` | The host: the player, HUD, menu, checkpoints, the tally, and the swing tether's Courtyard rule. |
| `godot/scripts/content/crossing_d_parts.gd` | The small parts, ported from Wisp's studies after review. |
| `godot/scripts/content/review_isolation.gd` | Names both isolated review builds in one place. |
| `godot/tests/crossing_d_check.gd` | The live check: plays the Crossing by real input. |
| `tools/crossing_review_probe.py` | Isolation and live checks, through the real startup path. |
| `godot/export_presets.cfg` | Two presets, Windows and Linux. Each sets the `crossing_review` feature, so the exported executable starts straight into the Crossing. |
| `tools/crossing_d/` | The packaging script, the two launchers and the in-zip README. |

**Shared code, touched small:**
- **The isolation guard.** `bridge_client.gd`, `player_settings.gd`,
  `favourites.gd` and `equipment_seen.gd` asked whether the concourse
  playtest was running. They now ask `ReviewIsolation.active()`: the
  concourse playtest **or** Crossing D. Both builds keep the same
  promise, through the same four lines:
  - no socket is opened before any connection exists;
  - none of the player's three files is written.
- **`main.gd`.** A `--crossing-d` branch before `boot()`, like
  `--counterfire` and `--railway`. The exported feature takes the same
  branch.
- **Makefile and CI coverage.** The target `godot-crossing-d`, and a
  NOT_A_SUITE entry for it, like `godot-concourse-pier`.

**Not touched:**
- the generator, schemas, the bridge and AP;
- saves, HP and damage;
- enemy AI, movement constants and the dash;
- Forge and the economy.

The Upper Yard's enemies are roster enemies at baseline numbers, with
their roster jobs.

## Known issues

- **Not played by hand yet.** Every run here is scripted, real input
  (steer, walk, jump, aim, fire, use), in the real game. Nobody has
  played it.
- **Windows was not run.** The Windows build was checked under Wine on
  Linux (above). That is good evidence that it starts from a fresh
  folder, and no evidence about real drivers or SmartScreen.
- **Visuals are functional, not Arty's.** Plain billboard signs and
  restrained lighting. No room identity work.
- **The ranged role notices you from 40 m, through walls**, because
  notice is a distance. It only fires with a line of sight.
- **Grazes.** In some places in the Yard, the ranged role sees you by its
  thin sight ray but its 0.2 m shot meets the edge of the cover you
  stand behind. All of them are at cover edges and the post's own foot;
  none is on bare structure. They are listed under Evidence. That is the
  cover working, but such a shot is still committed and spent.
- **The melee does not climb stairs** (unchanged roster behaviour). The
  post is reached by a ramp, as D-17 asks.
- **The swing tether works in the Courtyard only** (conflict 2).
  Elsewhere, right mouse does nothing.
- **No fall damage in this revision.** The overlook's 14 m drop and the
  Machine Hall's pit cost nothing.
- **Godot's own files.** The engine's log and shader caches still go to
  Godot's user folder, as with the Concourse build. None of your game
  files is written.
- **No audio work**, as the handoff says.

## What to test

1. **Launch** from a new folder exactly as written above. Tell me about
   anything that happens before the first room.
2. **Central Hall.** Without reading every word, can you tell where to
   go? Is the dark lift, and the green line to the Machine Hall, enough
   to say "power comes from over there"?
3. **Courtyard.**
   - Pad, spring, pad to the balcony, then the rail down.
   - Then the swing: jump, hold right mouse, hold W.
   - Is the overlook worth it?
   - Does the route have room to breathe, unlike the Concourse
     movement space?
4. **Machine Hall.**
   - Can you work out plate, then lock, then socket from the lines and
     the plain signs alone?
   - Try the quick carry: lift the cell off the plate and ride the
     rising bridge across.
5. **Upper Yard.**
   - Read the fight from the alcove first.
   - Fight it once, and run past it once.
   - At the same HP and damage as the Concourse pier, how do the
     charger's telegraphed rush, the ranged role on its post, and the
     cover change the pacing?
6. **The way back.** Do the gate and stair, the rail, and the glass door
   feel like shortcuts?
7. **Colour.** Did blue, green and orange teach you anything without
   the legend?

## Conflicts and decisions, flagged rather than silently redesigned

1. **Build order.** D-17 asks for rooms 1–3 first and the Yard later.
   This assignment asks for the first combat comparison now, so all four
   are built. The no-enemies launcher is D-17's first step.
2. **The swing catches any solid surface, not only swing plates.**
   - `EchoRuntime._grapple_swing` asks only for a `StaticBody3D`. D-17
     assumes plates.
   - Equipped everywhere, the swing would carry a player over the
     Machine Hall's gap and up the tower.
   - **In this build the tether works in the Courtyard only.** It goes
     on and off at the Courtyard's doorways, and a swing aimed out at the
     tower ends at the opening. The live check proves both.
   - To decide: plates-only anchors (a runtime change), or accept the
     skips.
3. **Swing feel.**
   - The tether's pull (28) only just beats gravity (24).
   - The walk solve's air control damps sideways speed toward the stick.
   - So a swing carries you when you hold W toward where you are going,
     as study A's players did, and stalls when you do not.
   - Measured, not changed.
4. **The Yard is 24 × 30 m, not about 24 × 22.**
   - The roster's own job for melee and charger is a 4.5 m patrol
     around their posts.
   - Keeping those beats outside the walkers' 18 m notice from the
     lift's alcove needed the depth, because D-17 asks for an overlook
     out of the enemies' detection.
   - The ranged role notices at its 40 m reach by design (notice is the
     greater of 18 m and reach). Its line into the alcove is glass, so it
     never fires there.
5. **No levers in the Central Hall** (D-17 keeps them out). The lift
   answers to presence instead:
   - step into the powered cage and it rides after a second;
   - wait at a landing and it comes for you.

   Both doors shut before it moves, and nothing moves without power.
6. **The locked colours, against approved production art.** They are
   applied to this build's own instances only, with no shared material
   or constant changed:
   - the spring's approved drum keeps signal teal in its emitter;
   - the rail sweeps `AFFORDANCE_SIGNAL` teal;
   - the production plate lamp is cyan, and red-orange when held, which
     would teach orange;
   - the base socket's ring is orange while empty;
   - `DestructibleCover` is grey.

   A production-wide colour decision is Arty's and yours.
7. **"The window from the hall shows the socket across a gap."** The
   glass door shows the far side directly: the socket, its line and the
   Check. The gap is seen from the Machine Hall's own near side.
8. **The overlook is a solid block.** This tether cannot lift a player
   onto a thin deck from below, but it does ride them up a face and over
   its top.
9. **Cut, per D-17's own cut order:** the swing gap from the overlook to
   the Yard's side ledge.
10. **Arty's bounded visual kit had not arrived.** The remote had no push
    from her when this was built. The build uses existing production art
    and materials only: plain billboard signs, restrained lighting, and
    no new assets.
11. **The base is unmerged work.** The branch reuses the concourse
    playtest's isolation guard, so it sits on #16 and #18 (the art
    catch-up and the concourse branch). Merge order matters if any of it
    ever lands. Nothing here is merged or released.

## The rooms, as built against D-17

| Room | Main activity, as built | Departures from D-17 (see Conflicts) |
|---|---|---|
| **Central Hall** (24 × 24 m) | Arrive and orient. Every way out is visible from the floor: the dark lift tower with EXIT at its head, the wide Courtyard opening and its rail, the Machine Hall's open way and its closed glass door, and the Yard's gated stair. The lights brighten when the power comes back. | No levers: the lift answers to presence. The gate and the glass door show their state by badge, not by sign. |
| **Courtyard** (32 × 28 m, balcony 9.5 m) | A launch pad, a spring and a second pad up to the balcony and its Check, with a wide recovery floor. Two swing plates give the faster line across the middle. An overlook 14 m up holds a local reward and a window onto the Yard, and only the swing reaches it. The rail takes you from the balcony back down into the hall. | The overlook is a solid block, swung up its face. The swing gap to the Yard is cut (first in D-17's cut order). |
| **Machine Hall** (22 × 32 m) | The cell is in a low hatch, taken with E. A plate holds the lift-bridge over an 8 m gap. A far lever locks the bridge down. The socket powers the glass door and the lift. Every line lights when live. A missed step falls into a pit whose stair returns to the near side only. | None. |
| **Upper Yard** (24 × 30 m) | One fight: a ranged role on a raised post reached by a ramp, plus a melee and a charger on the floor, all at baseline numbers. Cover comes at two heights: 4.5 m full cover and 1.1 m walls, plus three orange crates that break. The Check sits in a glass case that opens once the Yard is clear (kill-all). The exit is across the Yard, and running is legal. A lever on the Yard side opens the gate to the stair down. Sills at every way out keep the walkers in. | 30 m deep, not about 22 (conflict 4). |

**Checks and rewards.** The three Check stand-ins and the local-reward
stand-in hold no item. They name no location, recipient or AP id, and
talk to nobody. Finding one updates this session's tally and nothing
else.

## Wisp's study source: what came across, what did not

Wisp's study is the lean source zip, revision `33cc9385` on baseline
`e0421aaa`. It changes nothing outside its own folder except
`project.godot` and its export presets, so nothing in it replaced a
production file.

**Her repairs, checked against production:**
- **Pause in place.** The loaded-plate pause loss was the study's own:
  it disabled the world subtree. Production pauses through
  `PauseClaims`, and so does this build's menu.
- **The upright lever handle.** Also the study's own: it set `locked`
  by hand. Here the mounted lever latches through `lock(note)` and owns
  its handle's pose. The live check measures the handle at ON (55°)
  after the pull.
- **The `hand_carry.gd:208` slerp normalisation.** This is a real,
  non-fatal production diagnostic. It did not fire in these runs. It
  is recorded and not fixed, because it is outside this brief.

**Taken, after review:**
- the palette;
- the surface-mounted power lines;
- the mounted lever, fixed as above;
- study A's tether numbers (28 m range, force 28, 4 s);
- study B's hatch, plate, bridge and latch idea, rebuilt to D-17's
  three steps.

**Not taken:**
- the offline-bridge autoload swap and the custom user folder. This
  build uses the concourse playtest's guard instead.
- her identity props and stair models. They belong to Arty's lane, the
  bounded visual kit.
- her audio.
- the A/B/C tree as a whole.

## Evidence

Everything below is on the build `0cf577c6` unless a line says
otherwise.

**The live check** (`godot/tests/crossing_d_check.gd`) plays the
Crossing by real input in the real game.
- 137 checks pass with the fight, and 105 with the Yard empty.
- It ran in three builds: the source tree, the exported Linux build and
  the Windows executable under Wine. The two exported builds were each
  unpacked from their zip into a fresh folder.

What it measured:
- **Reach** (the gantry's D-9 measurement: what the base kit stands on,
  plus the played 1.40 m jump):
  - The balcony's Check is 7.0 m from the nearest eye the base kit stands
    or jumps to, and the overlook's reward is 11.5 m away. A hand reaches
    3 m.
  - The ledges cannot be climbed from the floor.
  - The Machine Hall's gap is 8.0 m. From everything the near side and
    its pit reach, the far side lies beyond the longest base-kit jump.
    The measurement's own jump, with radii and cell included, carries
    7.13 m.
- **Courtyard:**
  - pad, spring and pad to the balcony, and its Check;
  - the rail, caught on the balcony and left in the hall;
  - the swing from the floor up the overlook's face, 14 m, and its
    reward;
  - a swing aimed at the tower, ended where it crossed into the hall
    (x = 11.96).
- **Machine Hall:**
  - the player alone on the plate holds nothing;
  - the cell taken from the hatch with E;
  - the bridge comes down under the cell;
  - the lock lever's handle stands at ON (55.0°), and the lock holds
    with the plate empty;
  - the cell installed: the glass door opens and the lift has power;
  - the far ledge's Check.
- **The quick carry, which is legal:**
  - the player is at the bridge's near end 0.38 s after lifting the cell,
    with the bridge 0.61 m up;
  - across on the rising bridge;
  - power restored, with the lock never pulled.
- **Lift:** nothing moves without power. It rides up by presence, and
  waiting at the hall's landing brings it down.
- **Upper Yard:**
  - From the alcove, the walkers (about 22 m away) had not noticed the
    player, and nothing was fired at it.
  - All three were put down at baseline numbers in 18 s of play, with no
    player death.
  - The charger's rush and the ranged role's aim were seen telegraphed,
    and their attacks landed.
  - Every enemy stayed inside the Yard.
  - A run across the Yard to the exit, past all three, ended at hp 94
    (source) and 100 (Windows).
- **The shot sweep**, the real 0.2 m shot against the thin sight ray:
  - The ranged role can see 474 standing places in the Yard. 35–36 of
    them (7.4–7.6%) are grazes.
  - All the grazes are at cover or the post's foot: full-height cover 16,
    crates 9, the Check's case 2–3, within 3 m of the post's foot 6, the
    alcove's corner 1 and a low wall 1.
  - None is on bare structure.
  - The post's own edge spends no shot aimed at the floor beyond 3 m of
    its foot. That is the concourse pier's defect, and it is absent here.
- **Shortcuts and exit:**
  - the gate opens from the Yard side;
  - the stair goes down, and back up from its foot;
  - the exit;
  - the completion screen;
  - RESTART is a fresh Crossing;
  - Esc pauses the game and opens the menu.

**Isolation** (`tools/crossing_review_probe.py`). A stand-in bridge held
127.0.0.1:38290 throughout. "Plain launch" means the build started as a
tester would and left running for 15 s, in both Yards.

| Build | Plain launch, 15 s | Live checks (fight / empty) | Connection attempts | Player's three files | Ordinary launch (control) |
|---|---|---|---|---|---|
| Source tree (`make godot-crossing-d`) | started | 137 / 105 pass | 0 | byte-identical | connects |
| Exported Linux, fresh folder | started | 137 / 105 pass | 0 | byte-identical | connects |
| Windows executable under Wine, fresh folder | started | 137 / 105 pass | 0 | byte-identical | connects |

**Affected suites**, run at `433c83a1`. Later commits touch only the
Crossing's own host, rooms, check and export presets.
- `make test`: 2313 passed.
- Green: `godot-boot`, `godot-test` (chambers), `godot-integration` (a
  real bridge still connects), `godot-menu-shell` (45), `godot-reload`
  (20) and `godot-concourse-pier` (that playtest's isolation, now through
  the shared guard). `godot-crossing-d` passes.

**Not run:**
- the full frontier: this is a review branch, not a stage boundary;
- a real Windows PC;
- a hand-played session.

**How to rebuild it:** `tools/crossing_d/package.sh <output folder>`.
It writes the one Windows zip, the same build in two parts, and the
Linux zip. It needs Godot 4.5.1's free export templates in the template
folder.

The parts sent are the tested `0cf577c6` executable, cut in two. Only
the README and the no-enemies launcher were refreshed, so the launcher
now says "join first" if the game is not joined yet.
