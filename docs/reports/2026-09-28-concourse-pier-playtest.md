# Concourse-pier playtest: empty and populated

*Prod — 2026-09-28. Arty's pending room `shell_concourse_pier` (art
`697fd8af`, handoff `f38b525c`), in a short route of the real game. Built
on CK14 `17b76098`, on the branch `review/concourse-pier-playtest`.*

## How to play it

Unpack the ZIP into a **new folder**. Then run one of these:

- **Windows:**
  - `Play Concourse Pier - empty (Windows).bat`: architecture and
    lighting only.
  - `Play Concourse Pier - populated (Windows).bat`: the same route and
    lights, with one small encounter.
- **Linux/macOS:** `./play-concourse-pier.sh` or
  `./play-concourse-pier.sh populated`.

The launchers find Godot 4.5.1 the way the other launchers do. No bridge
and no Python are needed.

**Controls:** WASD and space to move and jump, the mouse to look, left
click for the Static Pulse, and Esc for the menu.

**The route:**
1. Start in the Zone's arrival.
2. Take a procedural corridor and its connector.
3. Enter the concourse pier.
4. Leave by the Zone's exit portal.

**Starting again and stopping:**
- The exit portal, and the menu's RETURN TO HUB and ABANDON, all start
  the route again from the beginning, with enemies back in populated
  mode.
- Esc, then QUIT GAME, stops.

## What is the same in both modes, and what differs

**The same in both:**
- the route;
- the room;
- the three lights: the procedural arena's own arrangement, through the
  existing hanging fixture;
- the objective: `reach_reward`, the arena default;
- the exit.

**The only difference:** the populated room has a **ranged** enemy on
the pier top and a **melee** enemy on the floor behind the pier. You
never have to kill them to leave; the exit portal is open from the start.

## Isolation

- The game checks the playtest flag in its bridge client before any
  connection exists. Under that flag it opens no socket and never
  retries.
- It writes none of your three client files: settings, favourites and
  seen items. It reads your settings, so your controls and FOV apply,
  but a change made during the playtest lasts only for that session.
- The room is loaded under an in-memory exception for this launch only.
  The catalogue still says `pending`, and ordinary campaigns never
  choose it.

**Measured through the real startup path** (`make
godot-concourse-pier`):
- **Both modes:** a stand-in bridge listened on the bridge's address
  (127.0.0.1:38290) while the game ran:
  - as launched, for 15 s;
  - through the whole live check.

  It received **0 connection attempts** in both modes.
- **Control:** an ordinary launch against the same listener **did**
  connect.
- **Your files:** seeded copies of the three files were
  **byte-identical** afterwards, although the check changed a setting
  and called every save path. A deliberately broken build, with the
  settings guard removed, changes them.
- **Not covered:** the engine's own log and shader caches still go to
  Godot's user folder.

## What was tested

These are scripted runs in the real game, not human play.
- **The room:**
  - The actual `shell_concourse_pier` scene is built, not the
    procedural substitute.
  - The three lights stand at the planned places, identically in both
    modes.
- **Empty mode:**
  - The approach walks into the room.
  - The floor route walks to the exit doorway.
  - Walking into the pier stops at its face (the collision control).
  - The upper loop walks: stair A, the gallery, the bridge, the pier and
    stair B, standing at 3.50 m on the decks.
- **Exits:** the exit portal, RESUME, RETURN TO HUB and ABANDON through
  the real pause menu. Each reset builds a fresh route.
- **Populated mode**, measured:
  - **The melee** comes round the pier by the exit-side lane, reaches
    the player on the floor, and its strikes land.
  - **The ranged** sees only the **entrance** (under and just past the
    gallery) and the **bridge**. The pier's own mass and parapets hide
    it from both floor lanes, the landing and the gallery.
    - It fires on a player standing past the gallery and hits: 3 of 3
      from standing.
    - The player can answer it from the entrance, from just past the
      gallery and from the bridge.
  - **The Static Pulse** kills both.
  - **Leaving with both alive:** a second pass walks the upper loop over
    the pier, past the live ranged enemy, and out.
- **Affected suites:**
  - `make test`: 2313 passed.
  - Also green: `godot-boot`, `godot-content`, `godot-room-contract`,
    `godot-integration` (a real bridge still connects),
    `godot-reload`, `godot-playtest3a`, `godot-menu-shell`,
    `godot-equipment-face`, `godot-map-face`, `godot-lab` and
    `godot-test`.
- **From a clean unpack of the ZIP:**
  - the Godot import;
  - `make godot-concourse-pier`'s probe run against the unpacked tree:
    both modes, 0 connection attempts, the player's files byte-identical,
    and the control connects;
  - both modes through `play-concourse-pier.sh`.

  No shipped file changed.

## Limitations

- **The melee does not follow up the stairs.** Enemies steer directly,
  with no navmesh, so the upper loop is out of its reach; it waits below.
  I kept this role because it does use its intended route, round the
  pier on the floor. The stairs make the loop a refuge from it. Chasing
  a player upstairs would be AI work.
- **The ranged enemy's spot was measured, not guessed.** Set back 1.2 m
  from the pier's front edge, every shot clipped that edge, so it stands
  0.6 m back.
- **The game's own large-room warp station** stands in the exit lane
  beside the pier. This is the ordinary rule for large rooms, and it was
  kept. Offline its SAVE does nothing; its warp works.
- **No fall damage.** The pier's 3.5 m edges are safe only because this
  revision has none (Arty's note).
- **Enemies notice by distance** (18 m, not sight) and are not leashed
  to their room. That is the game's general behaviour. In these tests
  the melee stayed in the room.
- **Offline:** no Hub, no Checks, no campaign progress. That is why
  every exit starts the route again.
- **Not yet played:** nobody has played it by hand, and the Windows
  launchers were not run on Windows. It was tested on Linux.
- **Found on the way, not fixed (outside this brief):** the older "no
  bridge" scenario launchers do still open a bridge connection. These
  are the railway, Passing Platforms, Counterfire and Unweighted. The
  bridge client connects in every launch, and only this playtest's flag
  now stops it.
